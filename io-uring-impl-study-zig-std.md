# IO Uring Implementation Study: Zig Standard Library

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: DECISION
---
-->

## Context

We are designing a Swift io_uring binding at the primitives layer (L1). Zig's standard
library is the most mature non-C io_uring implementation, shipping as part of the
compiler's standard library rather than a third-party binding. Zig shares relevant
constraints with our Swift work: no runtime, value semantics, explicit memory management,
and a desire for safety without overhead. This study extracts the exact design decisions
from the Zig codebase (files `lib/std/os/linux/IoUring.zig` at 4631 lines and
`lib/std/os/linux/io_uring_sqe.zig` at 679 lines, fetched from
`github.com/ziglang/zig` master branch, April 2026).

## Implementation Analysis

### Type System

**Struct redefinition, not C header import.** Zig redefines all kernel structs as Zig
`extern struct` types in `lib/std/os/linux.zig` and `io_uring_sqe.zig`. It does not
`@cImport` the kernel headers.

The three core kernel types:

| Kernel C type | Zig type | Size | Location |
|---|---|---|---|
| `struct io_uring_sqe` | `io_uring_sqe` (extern struct, 14 fields) | 64 bytes | `io_uring_sqe.zig` |
| `struct io_uring_cqe` | `io_uring_cqe` (extern struct, 3 fields) | 16 bytes | `linux.zig` |
| `struct io_uring_params` | `io_uring_params` (extern struct) | 120 bytes | `linux.zig` |

**Union flattening.** The kernel's SQE uses C unions for overlapping fields
(`off`/`addr2`, `rw_flags`/`fsync_flags`/etc., `buf_index`/`buf_group`, and
`splice_fd_in`/`file_index`). Zig **flattens all unions into their widest members**:

```zig
pub const io_uring_sqe = extern struct {
    opcode: linux.IORING_OP,
    flags: u8,
    ioprio: u16,
    fd: i32,
    off: u64,          // union: off, addr2
    addr: u64,         // union: addr, splice_off_in
    len: u32,
    rw_flags: u32,     // union: rw_flags, fsync_flags, poll_events, etc.
    user_data: u64,
    buf_index: u16,    // union: buf_index, buf_group
    personality: u16,
    splice_fd_in: i32, // union: splice_fd_in, file_index, optlen
    addr3: u64,
    resv: u64,
};
```

This eliminates union access complexity entirely. Each `prep_*` method knows which
semantic field maps to which physical field and sets it directly. Comments in the
source document the overloading (e.g., `// splice_fd_in is overloaded as
sqe_file_index: u32`).

**Opcode as enum.** `IORING_OP` is a Zig enum, not raw integer constants. Prep methods
use `.READ`, `.WRITE`, `.ACCEPT`, etc.

**CQE has methods.** The `io_uring_cqe` struct has two methods:
- `err()` -- converts negative `res` to a Zig error enum `E`
- `buffer_id()` -- extracts buffer ID from flags upper 16 bits, returning error if
  `IORING_CQE_F_BUFFER` flag is not set

### Safety Model

Zig adds multiple safety layers over raw C:

1. **Error returns instead of null.** `get_sqe()` returns `!*io_uring_sqe` (error union)
   rather than nullable pointer. The comment is explicit about the rationale:
   > "Any situation where the submission queue is full tends more towards a control flow
   > error, and the null return in liburing is more a C idiom than anything else...
   > In Zig, we have first-class error handling... so let's use it."

2. **Typed error sets for every syscall.** `io_uring_enter` maps each errno to a named
   error: `SubmissionQueueFull`, `FileDescriptorInvalid`, `CompletionQueueOvercommitted`,
   `BufferInvalid`, `RingShuttingDown`, `OpcodeNotSupported`, `SignalInterrupt`, etc.
   Similarly for `io_uring_setup` and `io_uring_register`.

3. **Minimum kernel version enforcement.** `init_params` checks for
   `IORING_FEAT_SINGLE_MMAP` and returns `error.SystemOutdated` if absent. This means
   Zig requires kernel 5.4+ and refuses to support the older double-mmap path, keeping
   the init/deinit logic simple.

4. **Assertions on invariants.** The init path has 15+ `assert()` calls verifying
   kernel-returned parameters: sq_entries != 0, cq_entries >= sq_entries, head/tail start
   at 0, mask == entries - 1, dropped == 0, etc.

5. **errdefer for cleanup.** `init_params` uses `errdefer posix.close(fd)` immediately
   after acquiring the fd, and `errdefer sq.deinit()` / `errdefer cq.deinit()` for the
   mmap regions. This guarantees cleanup on any init failure path.

6. **Power-of-two validation.** `init` validates `entries` is non-zero and a power of
   two, returning typed errors `EntriesZero` and `EntriesNotPowerOfTwo`.

7. **Wrapping arithmetic for head/tail.** All head/tail arithmetic uses `+%` and `-%`
   (Zig's wrapping operators) to handle the 32-bit wraparound explicitly. The code
   comments: "Remember that these head and tail offsets wrap around every four billion
   operations. We must therefore use wrapping addition and subtraction to avoid a
   runtime crash."

### Ring Management

The `IoUring` struct holds exactly five fields:

```zig
fd: linux.fd_t = -1,
sq: SubmissionQueue,
cq: CompletionQueue,
flags: u32,
features: u32,
```

**SubmissionQueue** (9 fields):
- `head: *u32` -- pointer into mmap'd ring (kernel writes, userspace reads)
- `tail: *u32` -- pointer into mmap'd ring (userspace writes, kernel reads)
- `mask: u32` -- cached value (entries - 1)
- `flags: *u32` -- pointer into mmap'd ring (kernel flags like NEED_WAKEUP)
- `dropped: *u32` -- pointer into mmap'd ring
- `array: []u32` -- indirection array in mmap'd region
- `sqes: []linux.io_uring_sqe` -- SQE array (separate mmap)
- `mmap: []align(page_size_min) u8` -- the SQ/CQ shared mmap region
- `mmap_sqes: []align(page_size_min) u8` -- the SQEs mmap region
- `sqe_head: u32 = 0` -- local head (not yet flushed to kernel)
- `sqe_tail: u32 = 0` -- local tail (tracks get_sqe allocations)

**CompletionQueue** (5 fields):
- `head: *u32`, `tail: *u32`, `mask: u32`, `overflow: *u32`
- `cqes: []linux.io_uring_cqe`

The CQ does not own its mmap -- it shares the SQ mmap due to `IORING_FEAT_SINGLE_MMAP`.
`CompletionQueue.deinit` is a no-op (documented as being there "for symmetry").

**The sqe_head/sqe_tail split.** This is the key design inherited from liburing:
- `get_sqe()` increments `sqe_tail` but does NOT touch the kernel-visible `tail`.
- `flush_sq()` walks from `sqe_head` to `sqe_tail`, populating the `array[]` indirection,
  then atomically stores the new `tail`.
- This amortizes a single atomic release store across an entire batch of SQE preparations.

### Memory Ordering

Zig uses four atomic operations on the ring head/tail pointers:

| Operation | Ordering | Location | Purpose |
|---|---|---|---|
| `@atomicLoad(u32, self.sq.head, .acquire)` | Acquire | `get_sqe()`, `sq_ready()` | Read kernel's SQ head |
| `@atomicStore(u32, self.sq.tail, tail, .release)` | Release | `flush_sq()` | Publish SQE batch to kernel |
| `@atomicLoad(u32, self.cq.tail, .acquire)` | Acquire | `cq_ready()` | Read kernel's CQ tail |
| `@atomicStore(u32, self.cq.head, ..., .release)` | Release | `cq_advance()` | Advance CQ head after consuming |
| `@atomicLoad(u32, self.sq.flags, .unordered)` | Unordered | `sq_ring_needs_enter()`, `cq_ring_needs_flush()` | Check NEED_WAKEUP / CQ_OVERFLOW flags |
| `@atomicStore(u16, &br.tail, tail, .release)` | Release | `buf_ring_advance()` | Publish buffer ring entries |

Key observations:
- The SQ flags check uses `.unordered` (equivalent to `relaxed`), matching liburing. This
  is safe because the flags are advisory -- a stale read just means an unnecessary
  `io_uring_enter` call, not a correctness issue.
- Acquire/release pairs form the synchronization contract: the kernel's release-store to
  CQ tail synchronizes-with userspace's acquire-load, and vice versa for SQ tail.
- The buffer ring uses the same release-store pattern for its tail.

### SQE Preparation

Zig implements **two layers of prep functions**:

**Layer 1: `io_uring_sqe` methods** (in `io_uring_sqe.zig`). These are low-level
methods on the SQE struct itself. Each `prep_*` method zero-initializes the entire
64-byte SQE by assigning a struct literal, then sets operation-specific fields. The
foundational method is:

```zig
pub fn prep_rw(sqe: *io_uring_sqe, op: IORING_OP, fd: fd_t, addr: u64, len: usize, offset: u64) void {
    sqe.* = .{
        .opcode = op, .flags = 0, .ioprio = 0, .fd = fd,
        .off = offset, .addr = addr, .len = @intCast(len),
        .rw_flags = 0, .user_data = 0, .buf_index = 0,
        .personality = 0, .splice_fd_in = 0, .addr3 = 0, .resv = 0,
    };
}
```

Most prep methods delegate to `prep_rw`, then override specific fields. Some operations
that reuse fields in unusual ways (fsync, close, fallocate, timeout_remove) write the
full struct literal directly instead.

Complete list of `prep_*` methods on `io_uring_sqe` (approximately 40):
`prep_nop`, `prep_fsync`, `prep_rw`, `prep_read`, `prep_write`, `prep_splice`,
`prep_readv`, `prep_writev`, `prep_read_fixed`, `prep_write_fixed`, `prep_accept`,
`prep_accept_direct`, `prep_multishot_accept_direct`, `prep_connect`, `prep_epoll_ctl`,
`prep_recv`, `prep_recv_multishot`, `prep_recvmsg`, `prep_recvmsg_multishot`,
`prep_send`, `prep_send_zc`, `prep_send_zc_fixed`, `prep_sendmsg_zc`, `prep_sendmsg`,
`prep_openat`, `prep_openat_direct`, `prep_close`, `prep_close_direct`, `prep_timeout`,
`prep_timeout_remove`, `prep_link_timeout`, `prep_poll_add`, `prep_poll_remove`,
`prep_poll_update`, `prep_fallocate`, `prep_statx`, `prep_cancel`, `prep_cancel_fd`,
`prep_shutdown`, `prep_renameat`, `prep_unlinkat`, `prep_mkdirat`, `prep_symlinkat`,
`prep_linkat`, `prep_files_update`, `prep_files_update_alloc`, `prep_provide_buffers`,
`prep_remove_buffers`, `prep_multishot_accept`, `prep_socket`, `prep_socket_direct`,
`prep_socket_direct_alloc`, `prep_waitid`, `prep_bind`, `prep_listen`, `prep_cmd_sock`.

Plus helpers: `set_flags`, `link_next`, `__io_uring_set_target_fixed_file`.

**Layer 2: `IoUring` convenience methods** (in `IoUring.zig`). These call `get_sqe()`,
then the appropriate `prep_*`, then set `user_data`. They return `!*io_uring_sqe`,
giving the caller the SQE pointer for further modification (e.g., setting
`IOSQE_IO_LINK` or `IOSQE_FIXED_FILE`). The naming drops the `prep_` prefix:

```zig
pub fn read(self: *IoUring, user_data: u64, fd: fd_t, buffer: ReadBuffer, offset: u64) !*io_uring_sqe
pub fn write(self: *IoUring, user_data: u64, fd: fd_t, buffer: []const u8, offset: u64) !*io_uring_sqe
pub fn accept(self: *IoUring, user_data: u64, fd: fd_t, ...) !*io_uring_sqe
// etc.
```

These are pure convenience -- all they do is `get_sqe() + prep_* + set user_data`.

**Tagged unions for buffer selection.** The `read` method accepts a `ReadBuffer` union:

```zig
pub const ReadBuffer = union(enum) {
    buffer: []u8,                          // direct buffer -> IORING_OP_READ
    iovecs: []const posix.iovec,           // iovec array -> IORING_OP_READV
    buffer_selection: struct {              // provided buffers -> IORING_OP_READ + IOSQE_BUFFER_SELECT
        group_id: u16,
        len: usize,
    },
};
```

Similarly, `RecvBuffer` is a tagged union for recv operations.

### Batch Operations

**`copy_cqes(cqes: []io_uring_cqe, wait_nr: u32) !u32`** is the primary CQE
consumption method. It:
1. Calls `copy_cqes_ready()` which memcpy's up to `min(cqes.len, cq_ready())` CQEs,
   handling ring wraparound with two `@memcpy` calls.
2. If no CQEs were ready and either `cq_ring_needs_flush()` or `wait_nr > 0`, calls
   `enter(0, wait_nr, IORING_ENTER_GETEVENTS)` to block, then retries the copy.
3. Calls `cq_advance(count)` to release the consumed slots with a single atomic store.

The design rationale is documented in a comment citing
`github.com/axboe/liburing/issues/103`:
> "The rationale for copying CQEs rather than copying pointers is that pointers are 8
> bytes whereas CQEs are not much more at only 16 bytes, and this provides a safer
> faster interface. Safer, because you no longer need to call cqe_seen(), avoiding
> idempotency bugs. Faster, because we can now amortize the atomic store release to
> cq.head across the batch."

**`copy_cqe()`** is the single-CQE convenience wrapper -- loops `copy_cqes(&[1], 1)`.

**Submission batching** is implicit: multiple `get_sqe()` calls accumulate SQEs locally
(`sqe_tail` advances but kernel `tail` does not). `submit()` flushes all pending SQEs
to the kernel in one `flush_sq()` + `enter()` call.

### BufferGroup

Zig adds a `BufferGroup` abstraction above the raw buffer ring APIs, using the newer
ring-mapped buffer interface (kernel 5.19+). This is a higher-level abstraction that
liburing does not provide:

```zig
pub const BufferGroup = struct {
    ring: *IoUring,
    br: *align(page_size_min) io_uring_buf_ring,
    buffers: []u8,
    buffer_size: u32,
    buffers_count: u16,
    heads: []u32,           // tracks incremental consumption head per buffer
    group_id: u16,
    // Methods: init, deinit, recv, recv_multishot, get, put
};
```

It handles:
- Allocating the contiguous buffer block and the buffer ring mmap
- Registering/unregistering with the kernel
- Providing buffer metadata to the ring
- `get(cqe)` -- extracts the buffer selected by the kernel from a CQE
- `put(cqe)` -- returns a buffer to the kernel ring, with incremental consumption
  support (tracking partial buffer usage via `IORING_CQE_F_BUF_MORE`)

The incremental consumption feature (kernel 6.12+) has a graceful fallback: if the
kernel returns `EINVAL`, the registration retries without the `inc` flag.

### API Surface

**Complete public API of `IoUring`:**

Ring lifecycle:
- `init(entries: u16, flags: u32) !IoUring`
- `init_params(entries: u16, p: *io_uring_params) !IoUring`
- `deinit(self: *IoUring) void`

SQE acquisition and submission:
- `get_sqe(self: *IoUring) !*io_uring_sqe`
- `submit(self: *IoUring) !u32`
- `submit_and_wait(self: *IoUring, wait_nr: u32) !u32`
- `enter(self: *IoUring, to_submit: u32, min_complete: u32, flags: u32) !u32`
- `flush_sq(self: *IoUring) u32`

CQE consumption:
- `copy_cqes(self: *IoUring, cqes: []io_uring_cqe, wait_nr: u32) !u32`
- `copy_cqe(ring: *IoUring) !io_uring_cqe`
- `cqe_seen(self: *IoUring, cqe: *io_uring_cqe) void`
- `cq_advance(self: *IoUring, count: u32) void`

Ring state queries:
- `sq_ready(self: *IoUring) u32`
- `cq_ready(self: *IoUring) u32`
- `sq_ring_needs_enter(self: *IoUring, flags: *u32) bool`
- `cq_ring_needs_flush(self: *IoUring) bool`

Operation queueing (all return `!*io_uring_sqe`):
- File I/O: `read`, `write`, `writev`, `read_fixed`, `write_fixed`, `splice`, `fsync`
- File ops: `openat`, `openat_direct`, `close`, `close_direct`, `fallocate`, `statx`
- File links: `renameat`, `unlinkat`, `mkdirat`, `symlinkat`, `linkat`
- Networking: `accept`, `accept_multishot`, `accept_direct`, `accept_multishot_direct`,
  `connect`, `send`, `send_zc`, `send_zc_fixed`, `recv`, `recvmsg`, `sendmsg`,
  `sendmsg_zc`, `bind`, `listen`, `socket`, `socket_direct`, `socket_direct_alloc`,
  `cmd_sock`, `setsockopt`, `getsockopt`
- Polling: `poll_add`, `poll_remove`, `poll_update`
- Timeouts: `timeout`, `timeout_remove`, `link_timeout`
- Control: `cancel`, `shutdown`, `nop`, `waitid`
- Buffers: `provide_buffers`, `remove_buffers`

Registration:
- `register_files`, `register_files_update`, `register_files_sparse`,
  `register_file_alloc_range`, `unregister_files`
- `register_buffers`, `unregister_buffers`
- `register_eventfd`, `register_eventfd_async`, `unregister_eventfd`
- `register_napi`, `unregister_napi`
- `get_probe`

Buffer ring (module-level functions):
- `setup_buf_ring`, `free_buf_ring`, `buf_ring_init`, `buf_ring_mask`,
  `buf_ring_add`, `buf_ring_advance`

Tagged union types: `ReadBuffer`, `RecvBuffer`
Nested type: `BufferGroup` (with `init`, `deinit`, `recv`, `recv_multishot`, `get`, `put`)

### Design Choices

**What Zig chose NOT to wrap:**
- No `io_uring_register_ring_fd` / `IORING_REGISTER_RING_FD` (registered ring optimization)
- No `io_uring_prep_msg_ring` (cross-ring messaging)
- No `io_uring_prep_fadvise` / `io_uring_prep_madvise`
- No `io_uring_prep_tee` (pipe tee)
- No CQE32 / SQE128 extended formats (CQE32 padding is mentioned in a comment but
  not handled)
- No `io_uring_prep_fixed_fd_install` (newer kernel feature)
- No multishot recv with provided buffer ring at the convenience level (only through
  the `BufferGroup` abstraction)

**What Zig added beyond liburing:**
1. **Copy-based CQE consumption** (`copy_cqes`) instead of zero-copy peek + `cqe_seen`.
   This eliminates idempotency bugs at the cost of one 16-byte memcpy per CQE.
2. **`BufferGroup`** abstraction with incremental consumption tracking.
3. **Tagged union buffer types** (`ReadBuffer`, `RecvBuffer`) that dispatch to the correct
   opcode based on the buffer variant.
4. **Minimum kernel version gate** (5.4+, via `IORING_FEAT_SINGLE_MMAP` check).
5. **Comprehensive inline test suite** (approximately 2600 lines of tests in the same
   file, with kernel version gating via `skipKernelLessThan`).

## Lessons for Swift

### 1. Flatten the SQE unions

The SQE's C unions should be represented as flat stored properties in Swift, not as
Swift enums or nested union types. Each prep method knows the semantic mapping. This
avoids the complexity of modeling overlapping union layouts in Swift and matches Zig's
proven approach. The 14-field flat struct maps directly.

### 2. Two-layer API: prep methods on SQE, convenience on Ring

Separate the low-level SQE preparation (methods on `IO.Uring.SQE`) from the ring-level
convenience that combines `get_sqe()` + `prep_*` + `user_data`. The SQE prep methods
are useful independently for advanced users who manage SQEs directly.

### 3. Copy-based CQE consumption by default

Adopt the copy_cqes pattern: memcpy 16-byte CQEs into a caller-provided buffer and
advance the CQ head once per batch. This eliminates the cqe_seen() footgun entirely.
The zero-copy path (cq_advance) should exist but be documented as advanced-only.

### 4. Typed errors, not raw errno

Every syscall return site should produce a typed error. `IO.Uring.Error` should be an
enum with cases like `.submissionQueueFull`, `.fileDescriptorInvalid`,
`.completionQueueOvercommitted`, not a raw `CInt`.

### 5. Wrapping arithmetic is essential

All head/tail arithmetic wraps at 32-bit. In Swift, this means using `&+` and `&-`
for all ring pointer arithmetic. The Zig source has explicit comments explaining why
this is necessary.

### 6. Acquire/release only, no SeqCst

The memory ordering contract is acquire-load for reading the other side's pointer and
release-store for publishing our own pointer. The SQ flags check can use relaxed/unordered.
No sequential consistency is needed anywhere. Our `Atomic` primitives must support these
orderings precisely.

### 7. sqe_head/sqe_tail amortization

The split between local sqe_head/sqe_tail and the kernel-visible head/tail is critical
for batch performance. A single release-store to `sq.tail` publishes an entire batch of
SQEs. Our ring type must implement this same pattern.

### 8. Minimum kernel version gate

Requiring `IORING_FEAT_SINGLE_MMAP` (kernel 5.4+) simplifies the init path from two
mmap regions to one shared region. Given that kernel 5.4 is from November 2019, this is
a reasonable minimum for a 2026 library.

### 9. BufferGroup is a separate abstraction

The ring-mapped buffer management (BufferGroup) is distinct from the core ring. It should
live in its own type, not be baked into the ring struct. It has its own lifecycle (init
requires an allocator, deinit frees memory) and its own mmap region.

### 10. Return the SQE for post-modification

All convenience methods should return the SQE pointer (or a borrowing accessor) so the
caller can set flags like `IOSQE_IO_LINK`, `IOSQE_IO_DRAIN`, or `IOSQE_FIXED_FILE`
after preparation. This is how Zig enables SQE chaining and barrier operations without
needing separate API surfaces for every flag combination.

### 11. Probe before using newer ops

Zig's `get_probe()` method wraps `io_uring_register(REGISTER_PROBE)` to query which
opcodes the running kernel supports. Our implementation should expose this for runtime
feature detection.

## References

- Source: `github.com/ziglang/zig/blob/master/lib/std/os/linux/IoUring.zig` (4631 lines)
- Source: `github.com/ziglang/zig/blob/master/lib/std/os/linux/io_uring_sqe.zig` (679 lines)
- Source: `github.com/ziglang/zig/blob/master/lib/std/os/linux.zig` (struct definitions)
- Kernel single-mmap patch: `patchwork.kernel.org/patch/11115257`
- liburing copy_cqes rationale: `github.com/axboe/liburing/issues/103#issuecomment-686665007`
- liburing sq head sync issue: `github.com/axboe/liburing/issues/92`
