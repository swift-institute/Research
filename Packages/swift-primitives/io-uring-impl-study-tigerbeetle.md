# IO Uring Implementation Study: TigerBeetle

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: DECISION
---
-->

## Context

We are designing a Swift io_uring binding at the primitives layer (L1). TigerBeetle is a
high-performance financial transactions database written in Zig that uses io_uring as its
primary I/O backend. It is one of the few production systems that saturates both NVMe
storage and 100GbE networking from a single-threaded userspace event loop. More importantly
for us, TigerBeetle wraps io_uring behind a cross-platform abstraction that also targets
kqueue (Darwin) and IOCP (Windows), making it a direct precedent for the kind of
abstraction boundary we need between `swift-linux-primitives` (io_uring) and
`swift-darwin-primitives` (kqueue). This study extracts the exact design decisions from the
TigerBeetle codebase (`src/io.zig`, `src/io/linux.zig`, `src/io/darwin.zig`,
`src/io/common.zig`, fetched from `github.com/tigerbeetle/tigerbeetle` main branch, April
2026) and their design blog post from November 2022.

This is the companion to `io-uring-impl-study-zig-std.md`, which covers the low-level
io_uring wrapper in Zig's standard library. TigerBeetle builds on that wrapper (using
`std.os.linux.IoUring` directly) and adds the application-level abstraction.

## Implementation Analysis

### Cross-Platform Abstraction

**Compile-time platform dispatch.** The entry point `src/io.zig` is a thin routing file
that selects the platform implementation at compile time:

```zig
pub const IO = switch (builtin.target.os.tag) {
    .linux => @import("io/linux.zig").IO,
    .macos, .ios, ... => @import("io/darwin.zig").IO,
    .windows => @import("io/windows.zig").IO,
    else => @compileError("unsupported"),
};
```

**Identical public API surface.** Both backends export the same set of public methods with
identical signatures:

| Method | Linux mechanism | Darwin mechanism |
|--------|----------------|-----------------|
| `accept()` | `IORING_OP_ACCEPT` via SQE | `kevent(EVFILT_READ)` then `posix.accept()` |
| `connect()` | `IORING_OP_CONNECT` via SQE | `kevent(EVFILT_WRITE)` then `posix.connect()` |
| `read()` | `IORING_OP_READ` via SQE | `kevent(EVFILT_READ)` then `posix.pread()` |
| `write()` | `IORING_OP_WRITE` via SQE | `kevent(EVFILT_WRITE)` then `posix.pwrite()` |
| `recv()` | `IORING_OP_RECV` via SQE | `kevent(EVFILT_READ)` then `posix.recv()` |
| `send()` | `IORING_OP_SEND` via SQE | `kevent(EVFILT_WRITE)` then `posix.sendto()` |
| `close()` | `IORING_OP_CLOSE` via SQE | Synchronous `posix.close()` |
| `fsync()` | `IORING_OP_FSYNC` via SQE | Synchronous `F_FULLFSYNC` via `fcntl` |
| `openat()` | `IORING_OP_OPENAT` via SQE | Synchronous `posix.openat()` |
| `timeout()` | `IORING_OP_TIMEOUT` via SQE | Timer queue with monotonic clock |
| `cancel()` | `IORING_OP_ASYNC_CANCEL` via SQE | **Panics** (not supported on Darwin) |

**What the abstraction hides.** The fundamental semantic gap is that io_uring is
completion-based (kernel performs the I/O) while kqueue is readiness-based (kernel signals
when a descriptor is ready, userspace performs the I/O). TigerBeetle hides this by making
the Darwin backend perform the actual syscall inside the completion callback. When the
syscall returns `EWOULDBLOCK`, the operation is re-queued into `io_pending` to wait for the
next readiness event. This retry loop is invisible to calling code.

**What leaks through.** Three things leak:

1. **Cancellation** is Linux-only. Darwin panics on `cancel()`. `cancel_all()` is a no-op.
2. **`send_now()`** returns `null` on Darwin (no synchronous fast-path).
3. **Direct I/O** uses `O_DIRECT` on Linux but `F_NOCACHE` on Darwin (semantic difference:
   `O_DIRECT` bypasses page cache entirely, `F_NOCACHE` merely hints the cache is
   unnecessary). The `DirectIO` enum in `io.zig` exposes this as a three-way choice:
   `direct_io_on`, `direct_io_off`, `direct_io_disabled`.

### Completion Model

**Caller-owned Completion struct.** The central design decision is that the caller provides
and owns the `Completion` struct. This means zero allocation per I/O operation. The
`Completion` is an intrusive node -- it contains its own linked list links, the operation
data, the callback, and the result.

**Linux Completion struct:**

```zig
pub const Completion = struct {
    io: *IO,
    result: i32 = undefined,
    link: QueueType(Completion).Link = .{},
    operation: Operation,
    context: ?*anyopaque,
    callback: *const fn (
        context: ?*anyopaque,
        completion: *Completion,
        result: *const anyopaque,
    ) void,
    awaiting_back: ?*Completion = null,
    awaiting_next: ?*Completion = null,
};
```

**Darwin Completion struct** is smaller -- no `io` backpointer, no `result` field, no
`awaiting_*` links:

```zig
pub const Completion = struct {
    link: QueueType(Completion).Link = .{},
    context: ?*anyopaque,
    callback: *const fn (*IO, *Completion) void,
    operation: Operation,
};
```

**Callback delivery.** On Linux, the kernel writes a CQE with the original `user_data`
(which TigerBeetle sets to `@intFromPtr(completion)`). The completion handler casts this
back, stores the raw `i32` result, then dispatches through a `complete()` method that
switches on the operation tag, maps the raw errno to a typed error union, and calls the
user's callback. On Darwin, the kqueue `udata` field carries the completion pointer.
When the kevent fires, the Darwin backend calls the completion's callback, which executes
the actual syscall and either delivers the result or re-queues on `EWOULDBLOCK`.

**Type erasure.** On Linux, the callback signature uses `*const anyopaque` for the result
parameter and an `erase_types()` helper to bridge from the typed user callback to the
stored erased callback. On Darwin, the callback receives `(*IO, *Completion)` directly,
and result delivery happens inside an inline `on_complete` closure generated per operation
by the `submit()` function.

**EINTR handling.** Both backends automatically re-enqueue operations that fail with
`EINTR`. This is invisible to the caller. On Linux, the re-enqueue happens in the
`complete()` method. On Darwin, it happens as a `continue` inside the `do_operation`
while loop.

### Ring Management

**Single ring, small depth.** TigerBeetle initializes the io_uring ring with **32 entries**
and **no flags** (`IO.init(32, 0)`). This is notably small -- the Zig standard library
documentation suggests 256-4096 for high-throughput applications. TigerBeetle can use a
small ring because it manages overflow entirely in userspace.

**Minimum kernel version.** The `init()` function checks for Linux kernel >= 5.5 via
`uname()` parsing, required for `IORING_OP_ACCEPT`.

**Three queues in the IO struct:**

| Queue | Type | Purpose |
|-------|------|---------|
| `ring` | `IO_Uring` (std lib) | The actual kernel ring (SQ + CQ) |
| `unqueued` | `QueueType(Completion)` | Overflow: completions that could not fit in the SQ |
| `completed` | `QueueType(Completion)` | Completions waiting for callback invocation |

Plus a doubly-linked list `awaiting` that tracks all operations currently submitted to the
kernel or waiting in the overflow queue.

**Overflow handling.** When `ring.get_sqe()` returns `SubmissionQueueFull`, the completion
is pushed to the `unqueued` overflow queue. On the next `flush()` cycle, the overflow queue
is drained and re-attempted:

```zig
fn enqueue(self: *IO, completion: *Completion) void {
    const sqe = self.ring.get_sqe() catch |err| switch (err) {
        error.SubmissionQueueFull => {
            self.unqueued.push(completion);
            return;
        },
    };
    completion.prep(sqe);
    self.awaiting.push(completion);
    self.ios_queued += 1;
}
```

This means the ring depth is not a hard limit on concurrency -- it is the batch size for
kernel submission. TigerBeetle can have arbitrarily many operations pending, bounded only
by the caller's allocation of `Completion` structs.

**CQE batch draining.** Completions are read in batches of up to 256 CQEs per
`flush_completions()` call:

```zig
fn flush_completions(self: *IO, wait_nr: u32, ...) !void {
    var cqes: [256]io_uring_cqe = undefined;
    // ...
    const completed = self.ring.copy_cqes(&cqes, wait_remaining) catch ...;
}
```

**Darwin equivalent.** Darwin uses `io_pending` instead of `unqueued`, and processes up to
256 kevents per `flush()` call. The kqueue `entries` and `flags` parameters from `IO.init`
are ignored (discarded with `_ = entries; _ = flags;`).

### Operation Encoding

**Tagged union, one variant per operation.** Operations are represented as a Zig tagged
union. The Linux variant:

```zig
const Operation = union(enum) {
    cancel:  struct { target: *Completion },
    accept:  struct { socket: socket_t, address: posix.sockaddr, address_size: posix.socklen_t },
    close:   struct { fd: fd_t },
    connect: struct { socket: socket_t, address: std.net.Address },
    fsync:   struct { fd: fd_t, flags: u32 },
    openat:  struct { dir_fd: fd_t, file_path: [*:0]const u8, flags: posix.O, mode: posix.mode_t },
    read:    struct { fd: fd_t, buffer: []u8, offset: u64 },
    recv:    struct { socket: socket_t, buffer: []u8 },
    send:    struct { socket: socket_t, buffer: []const u8 },
    statx:   struct { dir_fd: fd_t, file_path: [*:0]const u8, flags: u32, mask: u32, statxbuf: *Statx },
    timeout: struct { timespec: os.linux.kernel_timespec },
    write:   struct { fd: fd_t, buffer: []const u8, offset: u64 },
};
```

**12 operations total** (Linux). Darwin has 10 (no `cancel`, no `statx`).

**SQE preparation is centralized** in the `Completion.prep()` method, which switches on the
operation tag and calls the appropriate `sqe.prep_*` method from Zig's standard library:

```zig
fn prep(completion: *Completion, sqe: *io_uring_sqe) void {
    switch (completion.operation) {
        .read => |op| sqe.prep_read(op.fd, op.buffer[0..buffer_limit(op.buffer.len)], op.offset),
        .write => |op| sqe.prep_write(op.fd, op.buffer[0..buffer_limit(op.buffer.len)], op.offset),
        .accept => |*op| sqe.prep_accept(op.socket, &op.address, &op.address_size, posix.SOCK.CLOEXEC),
        // ... etc
    }
    sqe.user_data = @intFromPtr(completion);
}
```

**buffer_limit().** Both backends clamp buffer sizes to platform-safe maximums:
- Linux: `0x7ffff000` (2 GiB minus one page, to avoid signed `int` overflow in kernel)
- Darwin: `0x7fffffff` (2 GiB minus one byte)

**Per-operation public functions** wrap the `enqueue()` call, setting up the Completion
struct and using `erase_types()` to store the typed callback:

```zig
pub fn read(self: *IO, comptime Context: type, context: Context,
    comptime callback: fn (Context, *Completion, ReadError!usize) void,
    completion: *Completion, fd: fd_t, buffer: []u8, offset: u64,
) void {
    completion.* = .{
        .io = self,
        .context = context,
        .callback = erase_types(Context, ReadError!usize, callback),
        .operation = .{ .read = .{ .fd = fd, .buffer = buffer, .offset = offset } },
    };
    self.enqueue(completion);
}
```

### Error Handling

**Per-operation typed error sets.** Each operation defines its own error type as a Zig
error set:

```zig
pub const ReadError = error{
    WouldBlock, NotOpenForReading, ConnectionResetByPeer, Alignment,
    InputOutput, IsDir, SystemResources, Unseekable, ConnectionTimedOut,
} || posix.UnexpectedError;

pub const AcceptError = error{
    WouldBlock, FileDescriptorInvalid, ConnectionAborted, SocketNotListening,
    ProcessFdQuotaExceeded, SystemFdQuotaExceeded, SystemResources,
    FileDescriptorNotASocket, OperationNotSupported, PermissionDenied, ProtocolFailure,
} || posix.UnexpectedError;
```

**Exhaustive errno mapping.** The `complete()` method maps every possible negative `res`
value from the CQE to a specific error variant. Unrecognized errnos go through
`stdx.unexpected_errno()` which is likely a panic or debug trap. There is no catch-all
`error.Unknown` -- every errno is either mapped to a semantic error or declared
`unreachable`.

**Cross-platform error surface mismatch.** The same public error types are declared in both
backends, but the Darwin backend often encounters different errno spaces. For example,
`cancel` on Darwin panics entirely. The Darwin `connect` tracks an `initiated` field to
handle the two-phase connect pattern (first `connect()` returns `EINPROGRESS`, then
`getsockoptError()` checks the result after writability).

**Callback receives typed error union.** The callback signature is generic over the
operation's error type:

```zig
comptime callback: fn (
    context: Context,
    completion: *Completion,
    result: ReadError!usize,    // typed error union
) void,
```

This means the compiler enforces that the callback handles exactly the errors that the
operation can produce. No runtime type checking, no `catch` overhead.

### Timeout and Cancellation

**Timeouts.** On Linux, timeouts use `IORING_OP_TIMEOUT` -- a real io_uring operation that
the kernel manages. The `run_for_ns()` function submits a timeout SQE with an absolute
`kernel_timespec` and waits for either the timeout to expire (`ETIME`) or other completions
to arrive first. Timeout SQEs use `user_data = 0` as a sentinel to distinguish them from
real operation completions.

On Darwin, timeouts are maintained in a separate `timeouts` queue. The `flush_timeouts()`
function iterates the queue, checks each expiry against `time_os.time().monotonic().ns`,
and moves expired timeouts to the `completed` queue. The minimum remaining timeout
determines the `kevent()` block duration.

**Cancellation.** Linux supports cancellation via `IORING_OP_ASYNC_CANCEL`, which targets a
specific completion by its `user_data` pointer. The `cancel_all()` function iterates
the `awaiting` list and cancels each operation one by one, using a state machine:

```zig
cancel_all_status: union(enum) {
    inactive,
    next,                              // ready to cancel next
    queued: struct { target: *Completion },  // cancel SQE submitted
    wait: struct { target: *Completion },    // waiting for target's CQE
    done,
},
```

Each cancel attempt submits a cancel SQE, then spins `run_for_ns()` until either the
target completes or the cancel itself reports `NotRunning` (already completed) or
`NotInterruptable` (cannot cancel). This is a blocking drain -- `cancel_all()` does not
return until the `awaiting` list is empty and `ios_in_kernel == 0`.

Darwin explicitly panics on `cancel()` and has `cancel_all()` as a TODO no-op.

### Event Loop Design

**Single-threaded, cooperative.** The event loop is driven by the caller via `run()` or
`run_for_ns()`. There is no background thread, no epoll, no signal-based notification.

**`run()` -- non-blocking flush:**

```zig
pub fn run(self: *IO) !void {
    try self.flush(0, &timeouts, &etime);         // submit + drain, no wait
    // If SQEs still queued, submit them too
    if (queued > 0) try self.flush_submissions(0, &timeouts, &etime);
}
```

**`run_for_ns(nanoseconds)` -- bounded blocking:**

On Linux, this submits a `TIMEOUT` SQE with an absolute deadline, then calls `flush()`
in a loop until `ETIME` fires. On Darwin, it registers a timeout completion and loops
`flush(true)` (blocking kevent) until the timeout callback fires.

**`flush()` is the core cycle**, executing three phases per iteration:

1. **Submit** -- `flush_submissions()` calls `ring.submit_and_wait()`. On
   `CompletionQueueOvercommitted` or `SystemResources`, it drains one CQE and retries.
2. **Drain** -- `flush_completions()` reads up to 256 CQEs, stores the `res` field on
   each `Completion`, and pushes them to the `completed` queue.
3. **Dispatch** -- Iterates `completed`, removes each from `awaiting`, calls `complete()`
   which maps the errno and invokes the user callback. Then drains the `unqueued` overflow
   and re-attempts `enqueue()` for each.

**How saturation is achieved.** The single-threaded design saturates hardware because:

1. **io_uring does I/O in the kernel.** NVMe reads/writes and network sends/receives
   execute in kernel context or via polled mode, not in userspace. The userspace thread
   only submits and collects completions.
2. **Batching amortizes syscall overhead.** A single `io_uring_enter()` can submit dozens
   of SQEs and retrieve dozens of CQEs. The 32-entry ring and 256-CQE batch size mean
   roughly 8:1 operations-per-syscall ratio.
3. **Zero allocation per operation.** Caller-owned `Completion` structs mean no malloc/free
   in the hot path. TigerBeetle pre-allocates all Completions as part of its subsystem
   structs (journal, grid, etc.).
4. **No context switching.** Single thread means no mutex contention, no cache line
   bouncing, no scheduler overhead. The CPU stays hot on the same data.
5. **IOPS budget is pre-calculated.** TigerBeetle computes `iops_read_max` and
   `iops_write_max` from component budgets (journal: 8R/32W, grid: 32R/32W, superblock:
   1R/1W, client replies: configurable), ensuring the ring never exceeds what the hardware
   can deliver.

### Buffer Management

**Caller-owned buffers, no registration.** TigerBeetle does not use io_uring's registered
buffers (`IORING_OP_READ_FIXED` / `IORING_OP_WRITE_FIXED`) or provided buffers
(`IORING_OP_PROVIDE_BUFFERS`). Buffers are plain slices passed by the caller:

```zig
pub fn read(..., buffer: []u8, offset: u64) void {
    completion.* = .{
        .operation = .{ .read = .{ .fd = fd, .buffer = buffer, .offset = offset } },
    };
}
```

The kernel copies from/to these buffers during the I/O operation. The buffer must remain
valid and stable until the completion callback fires (which is guaranteed by the
single-threaded design -- no concurrent mutation).

**Buffer size clamping.** All operations pass through `buffer_limit()` which caps at
`0x7ffff000` on Linux. This prevents overflow in the kernel's signed `int` return value.

**Direct I/O alignment.** TigerBeetle opens data files with `O_DIRECT` and enforces
`sector_size` (4096 byte) alignment. The `Alignment` error from `read()`/`write()` maps
from `EINVAL`, which the kernel returns when the buffer or offset is not properly aligned
for direct I/O. The caller is responsible for providing aligned buffers.

**Pre-allocated operation budgets.** Rather than managing a generic buffer pool, TigerBeetle
pre-allocates fixed numbers of I/O operations per subsystem via compile-time constants:

```zig
pub const iops_read_max = journal_iops_read_max + client_replies_iops_read_max +
    grid_iops_read_max + superblock_iops_read_max;
pub const iops_write_max = journal_iops_write_max + client_replies_iops_write_max +
    grid_iops_write_max + superblock_iops_write_max;
```

Each subsystem owns its own `Completion` array and buffer array, sized at compile time.
This eliminates runtime allocation and bounds all resource usage statically.

## Lessons for Swift

### 1. Abstraction boundary location

TigerBeetle places the abstraction **above** the ring, not inside it. The io_uring ring
wrapper (Zig's `std.os.linux.IoUring`) remains a thin, platform-specific binding. The
cross-platform API is a separate layer that **consumes** the ring wrapper. This matches our
architecture: `Linux_Kernel_Primitives` exposes raw io_uring types, and a higher-level
`IO` abstraction (likely at L3 Foundations) composes platform backends.

### 2. Completion ownership must be intrusive

The caller-owned `Completion` struct is the linchpin of TigerBeetle's zero-allocation I/O.
In Swift, this translates to a `~Copyable` completion type that the caller allocates
(likely as a stored property of the subsystem struct) and passes by `inout` or pointer.
The completion embeds its own linked-list links, operation payload, and callback -- no
separate allocation per I/O. This is directly compatible with our `~Copyable` intrusive
linked list infrastructure in `swift-primitives`.

### 3. Tagged union for operations is the right encoding

TigerBeetle's `Operation` union maps directly to a Swift enum with associated values:

```swift
enum Operation {
    case read(fd: FileDescriptor, buffer: UnsafeMutableBufferPointer<UInt8>, offset: UInt64)
    case write(fd: FileDescriptor, buffer: UnsafeBufferPointer<UInt8>, offset: UInt64)
    case accept(socket: FileDescriptor)
    // ...
}
```

The `prep()` method that fills the SQE from the operation tag becomes a `switch` in Swift.
This is preferable to generic SQE filling because it constrains the operation surface at
compile time.

### 4. Overflow queue eliminates ring depth as a limit

The 32-entry ring with userspace overflow proves that ring depth is a **batching parameter**,
not a concurrency limit. Our Swift binding should similarly decouple the ring size from the
number of in-flight operations. The ring size controls how many SQEs can be submitted per
`io_uring_enter()` call, while total concurrency is bounded by the caller's allocation of
Completion objects.

### 5. Per-operation typed errors, not generic errno

TigerBeetle's per-operation error sets (e.g., `ReadError`, `AcceptError`) with exhaustive
errno mapping align perfectly with `[API-ERR-001]` typed throws. Our Swift binding should
define per-operation error types (e.g., `IO.Uring.Read.Error`, `IO.Uring.Accept.Error`)
with exhaustive `switch` over `errno` values. No `throws -> Error` -- always
`throws(IO.Uring.Read.Error)`.

### 6. Darwin abstraction is a separate layer

TigerBeetle's Darwin backend performs synchronous syscalls inside completion callbacks with
`EWOULDBLOCK` retry. This is genuinely different code from the Linux backend -- not a thin
adapter. Our architecture should not try to make kqueue "look like" io_uring at L1.
Instead, `Linux_Kernel_Primitives` exposes io_uring natively and
`Darwin_Kernel_Primitives` exposes kqueue natively. The completion-based unification
happens at L3 or L4, following TigerBeetle's pattern.

### 7. Cancellation is inherently platform-specific

TigerBeetle's Darwin backend panics on `cancel()`. This is honest -- kqueue has no
equivalent of `IORING_OP_ASYNC_CANCEL`. The cross-platform abstraction should either make
cancellation optional (protocol with default implementation that returns a "not supported"
error) or restrict it to Linux-only code paths. Do not fake cancellation on Darwin.

### 8. Timeout implementation diverges fundamentally

Linux uses kernel-managed timeouts (`IORING_OP_TIMEOUT`); Darwin uses a userspace timer
queue checked on each flush. The cross-platform abstraction hides this well, but the
performance characteristics differ: Linux timeouts have kernel-level precision; Darwin
timeouts have event-loop-cycle granularity. Document this.

### 9. Small ring, large CQE batch

TigerBeetle's 32-entry SQ ring with 256-CQE batch drain is a deliberate asymmetry: submit
small batches frequently, drain large batches to stay ahead of completions. This prevents
CQ overflow (which would cause `CompletionQueueOvercommitted`). Our Swift binding should
expose ring sizing as a configuration parameter but recommend small SQ depths (32-128) with
aggressive CQE draining.

### 10. `buffer_limit()` is essential

The platform-specific buffer size limits (`0x7ffff000` on Linux, `0x7fffffff` on Darwin)
prevent kernel API overflow. Our Swift binding must enforce these limits internally, not
rely on callers to clamp. This is a safety invariant.

## References

- TigerBeetle source: `github.com/tigerbeetle/tigerbeetle`, `src/io/linux.zig`,
  `src/io/darwin.zig`, `src/io/common.zig`, `src/io.zig`, `src/constants.zig`
- Blog post: "A Friendly Abstraction Over io_uring and kqueue" (November 2022),
  `tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/`
- Companion study: `io-uring-impl-study-zig-std.md` (this repository)
- Zig standard library io_uring wrapper: `lib/std/os/linux/IoUring.zig`
