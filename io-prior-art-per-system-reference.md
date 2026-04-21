# IO Prior Art: Per-System Reference

<!--
---
version: 1.0.0
last_updated: 2026-03-25
status: DECISION
---
-->

## Purpose

Detailed per-system API documentation for 15 IO systems, serving as reference
data backing the consolidated analysis in
`swift-institute/Research/io-prior-art-and-swift-io-design-audit.md`.

Each section documents public API signatures, design decisions, error models,
and platform details for a specific IO ecosystem. Consult when implementing
a feature and needing to understand how prior art handles the same problem.

## Table of Contents

1. [Rust](#rust-io-ecosystem) — std::io, tokio, mio, io_uring integration
2. [Go](#go-io-ecosystem) — io, bufio, os, net, runtime netpoller
3. [Java & .NET](#java-nio--net-io-ecosystems) — java.io/nio, System.IO, Pipelines
4. [Zig & OCaml](#zig-and-ocaml-io-ecosystems) — std.Io (0.15.1+), Eio (OCaml 5)
5. [OS-Level](#os-level-io-primitives) — io_uring, epoll, kqueue, IOCP, libuv
6. [Haskell, Theory & SwiftNIO](#haskell-theory-and-swiftnio) — IO monad, conduit, effects, capabilities, NIO, Swift System

---


---

## Rust IO Ecosystem


---

## 1. `std::io` — Standard Library IO Traits

### 1.1 The `Read` Trait

The `Read` trait is the fundamental abstraction for byte sources. It requires a single method:

```rust
trait Read {
    // === Required ===
    fn read(&mut self, buf: &mut [u8]) -> Result<usize>;

    // === Provided ===
    fn read_vectored(&mut self, bufs: &mut [IoSliceMut<'_>]) -> Result<usize>;
    fn read_to_end(&mut self, buf: &mut Vec<u8>) -> Result<usize>;
    fn read_to_string(&mut self, buf: &mut String) -> Result<usize>;
    fn read_exact(&mut self, buf: &mut [u8]) -> Result<()>;
    fn read_buf(&mut self, buf: BorrowedCursor<'_>) -> Result<()>;  // nightly
    fn by_ref(&mut self) -> &mut Self;
    fn bytes(self) -> Bytes<Self>;
    fn chain<R: Read>(self, next: R) -> Chain<Self, R>;
    fn take(self, limit: u64) -> Take<Self>;
}
```

**Key design decisions:**

- **One required method.** All provided methods are built on `read()`. This minimizes the implementor burden — you implement one function, you get an entire API surface for free.
- **Caller-owned buffer.** The caller provides `&mut [u8]`; the implementation fills it. The buffer's lifetime is scoped to the call. This is the *readiness-based* pattern: "here is space, fill what you can."
- **Partial reads are normal.** `read()` returns the number of bytes actually read. A return of `Ok(0)` signals EOF. This is the Unix convention mapped directly into the type system.
- **`read_exact()` changes the contract.** Where `read()` allows partial completion, `read_exact()` loops internally until the buffer is completely filled or an error occurs. The return type shifts from `Result<usize>` to `Result<()>` — the count is gone because it is always `buf.len()`.
- **`read_vectored()`** accepts `&mut [IoSliceMut<'_>]`, which is ABI-compatible with POSIX `iovec` / Windows `WSABUF`, enabling scatter-gather IO without copying.
- **`read_buf()` (nightly)** accepts `BorrowedCursor<'_>` instead of `&mut [u8]`, enabling reads into uninitialized memory without UB. `BorrowedCursor` is a write-only view into the unfilled portion of a `BorrowedBuf`. This avoids the cost of zero-initializing buffers.

### 1.2 The `Write` Trait

```rust
trait Write {
    // === Required ===
    fn write(&mut self, buf: &[u8]) -> Result<usize>;
    fn flush(&mut self) -> Result<()>;

    // === Provided ===
    fn write_vectored(&mut self, bufs: &[IoSlice<'_>]) -> Result<usize>;
    fn write_all(&mut self, buf: &[u8]) -> Result<()>;
    fn write_all_vectored(&mut self, bufs: &mut [IoSlice<'_>]) -> Result<()>;
    fn write_fmt(&mut self, fmt: Arguments<'_>) -> Result<()>;
    fn by_ref(&mut self) -> &mut Self;
}
```

**Key design decisions:**

- **Two required methods.** `write()` and `flush()` are both required. `flush()` exists because buffering is an expected pattern — the trait acknowledges that writes may be deferred.
- **Partial writes are normal.** `write()` returns `Ok(n)` where `n` may be less than `buf.len()`. The caller must handle this. `write_all()` loops internally as the convenience wrapper.
- **No `close()`/`shutdown()`.** Closing is handled by `Drop`. The trait is purely about data flow; resource lifecycle is orthogonal.
- **`write_vectored()`** mirrors `read_vectored()` with `IoSlice` (ABI-compatible with OS scatter-gather).

### 1.3 The Read/Write Duality

Read and Write form a deliberate dual pair:

| Read | Write |
|------|-------|
| `read(&mut self, buf: &mut [u8]) -> Result<usize>` | `write(&mut self, buf: &[u8]) -> Result<usize>` |
| `read_vectored(... IoSliceMut ...)` | `write_vectored(... IoSlice ...)` |
| `read_exact(... &mut [u8]) -> Result<()>` | `write_all(... &[u8]) -> Result<()>` |
| `read_to_end(... &mut Vec<u8>) -> Result<usize>` | *(no dual — writes are already "to end")* |
| Buffer is `&mut [u8]` (mutable, filled by callee) | Buffer is `&[u8]` (immutable, consumed by callee) |
| No `flush()` required | `flush()` required |

The asymmetry in `flush()` is fundamental: reading is pull-based (you request data), writing is push-based (you provide data), and push-based operations need explicit completion signals.

### 1.4 The `Seek` Trait

```rust
trait Seek {
    // === Required ===
    fn seek(&mut self, pos: SeekFrom) -> Result<u64>;

    // === Provided ===
    fn rewind(&mut self) -> Result<()>;
    fn stream_len(&mut self) -> Result<u64>;
    fn stream_position(&mut self) -> Result<u64>;
    fn seek_relative(&mut self, offset: i64) -> Result<()>;
}

enum SeekFrom {
    Start(u64),
    End(i64),
    Current(i64),
}
```

**Key design decisions:**

- **`SeekFrom` is an enum, not three methods.** This mirrors POSIX `lseek(fd, offset, whence)` but makes the whence parameter type-safe. `Start` uses `u64` (non-negative), `End` and `Current` use `i64` (may be negative).
- **Returns absolute position.** `seek()` always returns the new absolute position from the start, regardless of which `SeekFrom` variant was used. This makes position tracking trivial.
- **Orthogonal to Read/Write.** Seek is a separate trait, not bundled into Read or Write. A stream can be Read+Write but not Seek (e.g., TCP). A stream can be Read+Seek but not Write (e.g., read-only file). The composability is via trait bounds, not inheritance.

### 1.5 The `BufRead` Trait

```rust
trait BufRead: Read {
    // === Required ===
    fn fill_buf(&mut self) -> Result<&[u8]>;
    fn consume(&mut self, amt: usize);

    // === Provided ===
    fn has_data_left(&mut self) -> Result<bool>;
    fn read_until(&mut self, byte: u8, buf: &mut Vec<u8>) -> Result<usize>;
    fn skip_until(&mut self, byte: u8) -> Result<usize>;
    fn read_line(&mut self, buf: &mut String) -> Result<usize>;
    fn split(self, byte: u8) -> Split<Self>;
    fn lines(self) -> Lines<Self>;
}
```

**Key design decisions:**

- **Two-phase read.** `fill_buf()` returns a borrowed slice of the internal buffer. `consume()` advances the cursor. This split enables zero-copy inspection — you can look at buffered data without copying it, decide how much to consume, then advance.
- **Requires `Read`.** `BufRead` is a supertrait of `Read`. Every `BufRead` is a `Read`, but not vice versa. This models the reality that buffered reading is a *refinement* of reading.
- **Delimiter-oriented methods.** `read_until()`, `read_line()`, `split()`, `lines()` — these are built on the two-phase protocol and provide line-oriented / delimiter-oriented convenience.

### 1.6 `BufReader<R>` and `BufWriter<W>` — Buffering Strategy

```rust
struct BufReader<R: ?Sized + Read> { /* inner: R, buf: Box<[u8]>, pos/cap */ }
struct BufWriter<W: ?Sized + Write> { /* inner: W, buf: Vec<u8> */ }
```

**`BufReader<R>`:**

- Wraps any `R: Read` and adds an in-memory buffer.
- Default buffer size: **8 KiB** (configurable via `with_capacity()`).
- Strategy: performs large, infrequent reads from the underlying reader. Small reads from `BufReader` are served from the buffer.
- Implements `Read` (delegating to buffer then inner) and `BufRead` (exposing the buffer directly).
- **Seek interaction:** seeking always discards the internal buffer. `seek_relative()` can seek within the buffer without discarding.

**`BufWriter<W>`:**

- Wraps any `W: Write` and buffers output.
- Default buffer size: **8 KiB** (configurable via `with_capacity()`).
- Strategy: accumulates small writes in the buffer. Flushes to the underlying writer when the buffer is full or `flush()` is called.
- **Critical Drop behavior:** `Drop` attempts to flush, but **errors are silently ignored**. Callers must call `flush()` explicitly before drop if error handling is needed. This is a known footgun, documented prominently.
- **Large writes bypass the buffer.** If a write is larger than the remaining buffer capacity and the buffer is empty, the data goes directly to the inner writer without copying through the buffer.

**`LineWriter<W>` (variant):** Flushes on every newline. Built on `BufWriter`.

### 1.7 `Cursor<T>` — In-Memory IO

```rust
struct Cursor<T> {
    inner: T,
    pos: u64,
}
```

**Purpose:** Adapts in-memory buffers (`Vec<u8>`, `&[u8]`, `&mut [u8]`, `Box<[u8]>`) to implement `Read`, `Write`, `Seek`, and `BufRead`.

**Key design decisions:**

- **Generic over the buffer type.** `Cursor<Vec<u8>>` is read-write (Vec grows on write). `Cursor<&[u8]>` is read-only. `Cursor<&mut [u8]>` is read-write but fixed-size.
- **Uses `AsRef<[u8]>` for Read.** Any `T: AsRef<[u8]>` gets `Read`.
- **Position is `u64`.** Even for in-memory buffers, position is `u64` for API consistency with file-based `Seek`.
- **Primary use case:** Testing. Code that operates on `impl Read + Seek` can be tested with `Cursor<Vec<u8>>` without touching the filesystem.

### 1.8 Error Handling: `io::Result<T>`, `io::Error`, `ErrorKind`

```rust
type Result<T> = std::result::Result<T, std::io::Error>;

struct Error { /* repr: Repr — either Os(i32), Simple(ErrorKind), or Custom(Box<Custom>) */ }

#[non_exhaustive]
enum ErrorKind {
    NotFound,
    PermissionDenied,
    ConnectionRefused,
    ConnectionReset,
    ConnectionAborted,
    NotConnected,
    AddrInUse,
    AddrNotAvailable,
    BrokenPipe,
    AlreadyExists,
    WouldBlock,
    InvalidInput,
    InvalidData,
    TimedOut,
    WriteZero,
    Interrupted,
    Unsupported,
    UnexpectedEof,
    OutOfMemory,
    Other,
    // ... additional variants; #[non_exhaustive]
}
```

**Key design decisions:**

- **`io::Result<T>` is a type alias.** All IO operations return `Result<T, io::Error>`, aliased as `io::Result<T>` for brevity. This is the single, uniform error type for all of `std::io`.
- **`Error` is a concrete struct, not a trait object.** It has three internal representations:
  - `Os(i32)` — wraps a raw OS error code (errno / GetLastError). Zero-allocation.
  - `Simple(ErrorKind)` — wraps just a kind, no payload. Zero-allocation.
  - `Custom(Box<Custom>)` — wraps a `Box<dyn std::error::Error + Send + Sync>` with an `ErrorKind`. Heap-allocated.
- **`ErrorKind` is `#[non_exhaustive]`.** The enum will grow over time. Callers must use `_` wildcard arms. This is an explicit forward-compatibility decision.
- **Construction methods:**
  - `Error::from(ErrorKind)` — creates a simple error.
  - `Error::new(ErrorKind, error)` — creates a custom error wrapping any `impl Into<Box<dyn Error + Send + Sync>>`.
  - `Error::from_raw_os_error(i32)` — wraps a raw OS error code.
- **Inspection methods:**
  - `error.kind()` — returns `ErrorKind`.
  - `error.raw_os_error()` — returns `Option<i32>`.
  - `error.into_inner()` — extracts the custom boxed error, if any.
  - `error.downcast::<E>()` — attempts to downcast the inner error to a concrete type.
- **`WouldBlock` is an `ErrorKind`, not a separate type.** Non-blocking IO integrates into the same error model. This is a deliberate unification — the caller checks `error.kind() == ErrorKind::WouldBlock` rather than pattern-matching a different result type.

### 1.9 `io::copy()` and Zero-Copy Patterns

```rust
pub fn copy<R: ?Sized + Read, W: ?Sized + Write>(reader: &mut R, writer: &mut W) -> Result<u64>
```

**Surface API:** Simple generic function. Takes a reader and writer by mutable reference, returns total bytes copied.

**Implementation (Linux):** Internally uses a specialization cascade:
1. `copy_file_range(2)` — file-to-file, kernel does the copy without data entering userspace.
2. `sendfile(2)` — file-to-socket, DMA offload possible.
3. `splice(2)` — pipe-to-socket or socket-to-pipe, zero-copy via kernel pipe buffers.
4. **Fallback:** `read()`/`write()` loop through a userspace buffer.

The caller writes `io::copy(&mut reader, &mut writer)` and gets the optimal kernel-level transfer automatically. The zero-copy behavior is invisible at the API level — it is a pure implementation optimization behind the same trait interface.

### 1.10 Composability Combinators

The `Read` trait provides adapter methods that return new types implementing `Read`:

| Combinator | Signature | Effect |
|-----------|-----------|--------|
| `chain(next)` | `fn chain<R: Read>(self, next: R) -> Chain<Self, R>` | Concatenates two readers sequentially. First reader until EOF, then second. |
| `take(limit)` | `fn take(self, limit: u64) -> Take<Self>` | Caps the reader at `limit` bytes total. |
| `bytes()` | `fn bytes(self) -> Bytes<Self>` | Iterator over `Result<u8>`. Byte-at-a-time consumption. |
| `by_ref()` | `fn by_ref(&mut self) -> &mut Self` | Borrows the reader so you can pass it to a function that takes ownership, then continue using the original. |

These compose:
```rust
let first_100_bytes = file.by_ref().take(100).read_to_end(&mut buf)?;
// file is still usable here — by_ref() prevented take() from consuming it
```

`BufRead` adds its own combinators: `split(byte)` and `lines()` return iterators over `Result<Vec<u8>>` and `Result<String>` respectively.

**Design principle:** The combinators consume `self` (by move), producing a new type. This leverages Rust's ownership system — the original reader is no longer accessible, preventing aliased mutation. `by_ref()` is the explicit opt-out.

---

## 2. Tokio — Async IO Runtime

### 2.1 `AsyncRead` Trait

```rust
pub trait AsyncRead {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<io::Result<()>>;
}
```

**Differences from `std::io::Read`:**

| Aspect | `Read` | `AsyncRead` |
|--------|--------|-------------|
| Receiver | `&mut self` | `Pin<&mut Self>` |
| Buffer | `&mut [u8]` | `&mut ReadBuf<'_>` |
| Return | `Result<usize>` | `Poll<Result<()>>` |
| Blocking | Blocks the thread | Returns `Poll::Pending` |
| Bytes read | Returned as `usize` | Tracked in `ReadBuf::filled()` |

**Key design decisions:**

- **`Pin<&mut Self>`** is required because async IO may involve self-referential futures. Pinning guarantees the implementor won't be moved while an operation is in flight.
- **`ReadBuf`** replaces `&mut [u8]`. `ReadBuf` tracks three regions: initialized, filled, and unfilled. This avoids the zero-initialization problem — the reader can write into uninitialized memory safely. The bytes-read count is implicit in `ReadBuf::filled().len()` change, not returned explicitly.
- **`Poll::Pending`** means "not ready, I registered a waker." The runtime will re-poll when the waker fires. This is cooperative multitasking — no thread is blocked.
- **Users do not call `poll_read` directly.** They use `AsyncReadExt` methods (`read()`, `read_to_end()`, `read_exact()`, etc.) which are async functions that internally loop over `poll_read`.

### 2.2 `AsyncWrite` Trait

```rust
pub trait AsyncWrite {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<Result<usize>>;

    fn poll_flush(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
    ) -> Poll<Result<()>>;

    fn poll_shutdown(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
    ) -> Poll<Result<()>>;
}
```

**Differences from `std::io::Write`:**

- **`poll_shutdown()`** replaces reliance on `Drop`. Since async destructors don't exist, explicit async shutdown is needed. `poll_shutdown()` implies `poll_flush()` — callers don't need to flush before shutdown.
- **Three required methods** vs. two in `std::io::Write`. The addition of `poll_shutdown()` is forced by the async context.
- **No `write_vectored` in the trait.** Removed in the trait redesign (tokio-rs/tokio#2716). Vectored writes are available as methods on concrete types (e.g., `TcpStream`) rather than as trait methods.

### 2.3 The Polling Model

Tokio's IO model is *readiness-based* with cooperative scheduling:

1. An IO resource (e.g., `TcpStream`) is registered with the reactor.
2. When user code calls `stream.read(&mut buf).await`, this desugars to repeated `poll_read()` calls.
3. If the OS reports the socket is not readable, `poll_read` returns `Poll::Pending` and registers the task's `Waker` with the reactor.
4. The reactor waits on `epoll_wait` / `kqueue` / IOCP.
5. When the OS signals readiness, the reactor invokes the `Waker`, which schedules the task for re-polling.
6. The scheduler calls `poll_read` again, which now succeeds with `Poll::Ready(Ok(()))`.

**Critical invariant:** `Poll::Pending` *must* register a waker. Returning `Pending` without registering causes the task to be lost (never woken).

### 2.4 `TcpListener` and `TcpStream` — Network IO API

```rust
// TcpListener
impl TcpListener {
    pub async fn bind<A: ToSocketAddrs>(addr: A) -> io::Result<TcpListener>;
    pub async fn accept(&self) -> io::Result<(TcpStream, SocketAddr)>;
    pub fn from_std(listener: std::net::TcpListener) -> io::Result<TcpListener>;
}

// TcpStream
impl TcpStream {
    pub async fn connect<A: ToSocketAddrs>(addr: A) -> io::Result<TcpStream>;
    pub fn from_std(stream: std::net::TcpStream) -> io::Result<TcpStream>;
    pub fn into_split(self) -> (OwnedReadHalf, OwnedWriteHalf);
    pub fn split(&mut self) -> (ReadHalf<'_>, WriteHalf<'_>);
}
```

**Key design decisions:**

- **Mirrors `std::net` API.** `bind`, `accept`, `connect` have the same signatures except they are `async`. This minimizes learning cost.
- **`accept()` takes `&self`, not `&mut self`.** Multiple tasks can concurrently accept from the same listener. Internally synchronized.
- **`split()` vs `into_split()`.** `split()` borrows, returning halves with lifetimes tied to the stream. `into_split()` consumes, returning owned halves that can be sent to different tasks. The owned split uses an `Arc` internally.
- **`from_std()` bridging.** Any `std::net` type can be converted to its Tokio equivalent, enabling gradual migration.

### 2.5 Reactor / Driver Architecture

Tokio's runtime has three major components:

1. **IO Driver (Reactor):** Owns the OS event queue (`epoll` fd on Linux, `kqueue` on macOS/BSD, IOCP on Windows). Implemented via `mio::Poll`. The driver registers interest in file descriptor readiness and maps completion events to `Waker` invocations.

2. **Timer Driver:** Manages `tokio::time::Sleep` and related time-based futures. Uses a hierarchical timing wheel.

3. **Task Scheduler:** Either multi-threaded (work-stealing, default) or current-thread (single-threaded). Manages a queue of tasks and calls `poll()` on them when woken.

**Execution loop (simplified):**
```
loop {
    // 1. Poll all ready tasks
    while let Some(task) = ready_queue.pop() {
        task.poll();
    }
    // 2. Park on the OS event queue
    let timeout = timer_driver.next_deadline();
    io_driver.park(timeout);  // calls epoll_wait / kevent / IOCP
    // 3. Process IO events → wake tasks
    // 4. Process timer expirations → wake tasks
}
```

The IO driver uses **mio** under the hood. Tokio does not directly call `epoll_create`/`epoll_ctl`/`epoll_wait` — it delegates to mio's platform abstraction layer.

**Performance profile with epoll:** A tuned TCP proxy spends 70-80% of CPU cycles outside userspace, performing syscalls and copying data between kernel and userspace. This is the fundamental motivation for io_uring integration.

---

## 3. mio — Low-Level Event-Driven IO

### 3.1 Core Types

```rust
struct Poll { /* owns the OS event queue (epoll fd, kqueue fd, IOCP handle) */ }
struct Registry { /* borrowed handle to Poll's registration side */ }
struct Events { /* reusable buffer for event storage */ }
struct Token(pub usize);

struct Interest { /* bitfield: READABLE, WRITABLE, AIO (on FreeBSD), LIO (on FreeBSD) */ }
```

### 3.2 The Event Loop API

```rust
impl Poll {
    pub fn new() -> io::Result<Poll>;
    pub fn registry(&self) -> &Registry;
    pub fn poll(&mut self, events: &mut Events, timeout: Option<Duration>) -> io::Result<()>;
}

impl Registry {
    pub fn register<S: Source + ?Sized>(
        &self, source: &mut S, token: Token, interests: Interest,
    ) -> io::Result<()>;

    pub fn reregister<S: Source + ?Sized>(
        &self, source: &mut S, token: Token, interests: Interest,
    ) -> io::Result<()>;

    pub fn deregister<S: Source + ?Sized>(&self, source: &mut S) -> io::Result<()>;
}
```

**Typical event loop:**
```rust
let mut poll = Poll::new()?;
let mut events = Events::with_capacity(1024);

// Register a TCP listener
poll.registry().register(&mut listener, Token(0), Interest::READABLE)?;

loop {
    poll.poll(&mut events, None)?;
    for event in events.iter() {
        match event.token() {
            Token(0) => { /* listener is readable — accept new connection */ }
            Token(n) => { /* connection n has an event */ }
        }
    }
}
```

### 3.3 `Token` — Event Source Identity

`Token` is a `usize` wrapper. It is the *only* mechanism for correlating events back to their sources. The caller assigns tokens at registration time and interprets them at event time.

**Design implications:**
- No built-in mapping from tokens to sources. The caller maintains a slab, HashMap, or array.
- Tokens are reusable after deregistration.
- The `usize` type gives maximum flexibility — it can be an index, a packed bitfield, or even a pointer cast.

### 3.4 `Interest` — Readiness Model

```rust
impl Interest {
    pub const READABLE: Interest;
    pub const WRITABLE: Interest;
    // FreeBSD only: AIO, LIO

    pub const fn add(self, other: Interest) -> Interest;
    pub fn is_readable(self) -> bool;
    pub fn is_writable(self) -> bool;
}
```

- `Interest` is a bitfield, combinable via `add()` or `|`.
- The poll will *only* report events matching registered interests.
- `reregister()` fully replaces previous interest — it is not additive.

### 3.5 `event::Source` Trait

```rust
pub trait Source {
    fn register(&mut self, registry: &Registry, token: Token, interests: Interest) -> io::Result<()>;
    fn reregister(&mut self, registry: &Registry, token: Token, interests: Interest) -> io::Result<()>;
    fn deregister(&mut self, registry: &Registry) -> io::Result<()>;
}
```

Any type that wraps a system handle (socket, pipe, etc.) can implement `Source` to participate in the mio event loop. mio provides implementations for `TcpListener`, `TcpStream`, `UdpSocket`, and `unix::pipe`.

### 3.6 Platform Mapping

| Platform | Mechanism | Model |
|----------|-----------|-------|
| Linux | `epoll` | Readiness |
| macOS, iOS, FreeBSD, OpenBSD, NetBSD, DragonFly | `kqueue` | Readiness |
| Windows | IOCP (via wepoll/AFD) | Completion (adapted to readiness) |
| Android | `epoll` | Readiness |

**Windows adaptation:** IOCP is completion-based. mio adapts it to readiness semantics using the Windows AFD (Ancillary Function Driver) system. The adaptation is transparent to the caller — the API remains readiness-based on all platforms.

**Key property:** Zero allocations at runtime. `Events` is pre-allocated. `Token` is inline. No boxing, no heap allocation in the hot path.

---

## 4. io_uring Integration

### 4.1 Completion-Based vs. Readiness-Based IO

| Property | Readiness (epoll/kqueue) | Completion (io_uring/IOCP) |
|----------|--------------------------|----------------------------|
| Question asked | "Is the fd ready?" | "Do this operation; tell me when done." |
| Buffer ownership | Caller owns buffer throughout | Kernel owns buffer during operation |
| System calls | Two per operation (poll + read/write) | One per operation (submit) |
| Batching | Not inherent | Native (submission queue) |
| CPU overhead | Higher (more syscalls) | Lower (fewer transitions) |
| Buffer lifecycle | Scoped to call | Must survive until completion |

This distinction has profound API implications in Rust, because Rust's ownership model makes buffer lifetime tracking explicit.

### 4.2 io_uring Architecture (Linux)

io_uring is a Linux kernel interface (5.1+) built around two ring buffers in shared memory between userspace and kernel:

- **Submission Queue (SQ):** Userspace pushes operations (read, write, accept, etc.) as Submission Queue Entries (SQEs). The kernel consumes them.
- **Completion Queue (CQ):** The kernel pushes results as Completion Queue Entries (CQEs). Userspace consumes them.

Both rings are in memory shared between userspace and the kernel via `mmap`. This means submissions and completions can occur *without system calls* in the steady state (`io_uring_enter` is only needed to wake the kernel or wait for completions).

### 4.3 tokio-uring — Safe io_uring for Tokio

```rust
// File read — buffer ownership transfer
let file = tokio_uring::fs::File::open("hello.txt").await?;
let buf = vec![0u8; 4096];
let (result, buf) = file.read_at(buf, 0).await;  // buf moved in, returned back
let n = result?;

// TcpStream — same ownership pattern
let (result, buf) = stream.read(buf).await;
let (result, buf) = stream.write(buf).await;
```

**Key design decisions:**

- **Buffer ownership transfer.** The caller passes the buffer *by move* to the read/write operation. The buffer is submitted to the kernel. When the operation completes, the buffer is returned to the caller alongside the result. This is expressed as `BufResult<T, B>` = `(io::Result<T>, B)`.
- **`IoBuf` and `IoBufMut` traits.** These traits define the contract for buffers that can be submitted to io_uring:
  ```rust
  unsafe trait IoBuf: Unpin + 'static {
      fn stable_ptr(&self) -> *const u8;
      fn bytes_init(&self) -> usize;
      fn bytes_total(&self) -> usize;
  }

  unsafe trait IoBufMut: IoBuf {
      fn stable_mut_ptr(&mut self) -> *mut u8;
      unsafe fn set_init(&mut self, pos: usize);
  }
  ```
  The `stable_ptr` requirement ensures the buffer cannot be moved or reallocated while the kernel holds a pointer to it. `'static` ensures the buffer outlives any async operation. `Unpin` simplifies the async machinery.
- **Cannot use standard `AsyncRead`/`AsyncWrite`.** The standard traits pass buffers by reference (`&mut [u8]`), which doesn't transfer ownership. io_uring *requires* ownership transfer because the kernel holds the buffer pointer across an await point. This is a fundamental incompatibility.
- **Runs atop Tokio's current-thread runtime.** tokio-uring registers the io_uring completion queue fd with epoll. When completions arrive, `epoll_wait` wakes the runtime, which drains the CQ and resolves futures.

### 4.4 monoio — Thread-Per-Core io_uring Runtime

monoio (ByteDance) is a standalone async runtime, not built on Tokio:

- **Thread-per-core model.** Each thread has its own io_uring instance, event loop, and task queue. No cross-thread work stealing.
- **`!Send` tasks.** Tasks never move between threads, so `Send` bounds are not required. Thread-local storage is safe to use across await points.
- **`AsyncReadRent` / `AsyncWriteRent` traits.** Monoio defines its own IO traits (not compatible with Tokio's `AsyncRead`/`AsyncWrite`) that use buffer ownership transfer, similar to tokio-uring's pattern.
- **Multi-backend.** Falls back to epoll on older Linux kernels and kqueue on macOS/BSD.

### 4.5 compio — Cross-Platform Completion IO

compio (Completion-based IO) is another thread-per-core runtime inspired by monoio:

- Supports io_uring (Linux), IOCP (Windows), and polling (fallback).
- Aims for a unified completion-based API across all platforms.

### 4.6 Buffer Ownership Implications

The shift from readiness-based to completion-based IO creates a fundamental tension:

**Readiness model (std::io, tokio):**
```rust
let mut buf = vec![0u8; 4096];
stream.read(&mut buf)?;  // buf is borrowed, caller retains ownership
// buf is immediately usable here
```

**Completion model (tokio-uring, monoio):**
```rust
let buf = vec![0u8; 4096];
let (result, buf) = stream.read(buf).await;  // buf is MOVED, returned on completion
// buf is only usable after await completes
```

This has cascading effects:
- **No shared references during IO.** The buffer cannot be read or written by anyone while the kernel owns it. Rust's ownership system enforces this at compile time.
- **No cancel-and-reuse.** If you cancel an io_uring operation, the buffer might still be in use by the kernel. Cancellation must wait for the CQE before the buffer is safe to reuse.
- **Vectored IO returns all buffers.** Scatter/gather operations must return the entire buffer array alongside the result.
- **`'static` buffers.** Because the kernel lifetime is unbounded (until CQE), buffers must be `'static`. No stack-allocated buffers for io_uring operations.

---

## 5. Key Design Patterns

### 5.1 The Read/Write Trait Duality

Rust's IO design centers on a dual pair of traits that mirror each other structurally while differing in directionality. Read pulls bytes from a source into a caller-provided buffer. Write pushes bytes from a caller-provided buffer into a sink.

The duality extends to:
- **Vectored IO:** `read_vectored` / `write_vectored`
- **Exact transfer:** `read_exact` / `write_all`
- **Buffered wrappers:** `BufReader` / `BufWriter`
- **Async versions:** `AsyncRead` / `AsyncWrite`

The asymmetries are meaningful:
- Write has `flush()` because output may be deferred; Read has no dual because input is always immediate.
- Write has `shutdown()` (async) because connection teardown is an active operation; Read detects shutdown via `Ok(0)`.

### 5.2 Composability via Ownership

The combinator pattern (`chain`, `take`, `by_ref`, `bytes`) works because Rust's ownership model makes composition safe:

- Combinators consume the inner reader by move, preventing aliased access.
- `by_ref()` explicitly opts into borrowing when continued access is needed.
- Wrapper types (`BufReader<R>`, `Take<R>`, `Chain<A, B>`) form a *type-level pipeline*. The compiler can see the entire chain and optimize across boundaries.

This is a zero-cost abstraction: `BufReader<Take<File>>` has the same runtime representation as a manually-written buffered limited file reader.

### 5.3 Zero-Cost Abstractions in IO

| Abstraction | Cost |
|------------|------|
| Trait dispatch (`impl Read`) | Monomorphized. No vtable. |
| Trait object (`dyn Read`) | One vtable pointer. Single indirect call per operation. |
| `BufReader<R>` | One heap allocation for the buffer (amortized). |
| `io::copy()` specialization | Zero — compiler selects `sendfile`/`splice` at monomorphization. |
| `Cursor<Vec<u8>>` | No IO syscalls. Pure memory operations. |
| `chain()`/`take()` | Zero allocation. Wrapper structs are stack-allocated. |

The trait system enables *static polymorphism* where the concrete type is known at compile time, and *dynamic polymorphism* (`Box<dyn Read>`) where it isn't. The caller chooses the cost model.

### 5.4 Buffer Management Strategies

| Strategy | Used By | Trade-off |
|----------|---------|-----------|
| Caller-provided slice (`&mut [u8]`) | `Read::read`, `AsyncRead::poll_read` | Zero allocation, caller controls size. May under-read. |
| Internal buffer (`BufReader`, `BufWriter`) | Buffered wrappers | 8 KiB allocation. Amortizes syscalls. |
| Growing vector (`read_to_end`) | Convenience methods | Repeated allocation + copy. Simple but unbounded. |
| Uninitialized buffer (`ReadBuf`, `BorrowedBuf`) | Tokio `AsyncRead`, nightly `Read` | Avoids zero-init cost. More complex API. |
| Ownership transfer (`IoBuf`) | tokio-uring, monoio | Required by completion IO. `'static` + `Unpin`. |
| Kernel-managed (`copy_file_range`) | `io::copy` specialization | Zero userspace buffers. Data never enters process memory. |

### 5.5 Rust Ownership and IO Safety

Rust's ownership system provides compile-time guarantees that are directly relevant to IO:

**File descriptor safety (`OwnedFd`, `BorrowedFd`, `AsFd`):**
- `OwnedFd` — owns a file descriptor, closes on drop. Analogous to `Box<T>`.
- `BorrowedFd<'a>` — borrows a file descriptor for lifetime `'a`. Analogous to `&T`.
- `AsFd` — trait for types that can lend a `BorrowedFd`. Analogous to `AsRef<T>`.
- Raw fd values (`RawFd = i32`) are considered `unsafe` to use for IO, analogous to raw pointers.

This maps Rust's memory safety model onto IO resources:

| Memory | IO |
|--------|-----|
| `Box<T>` (owned) | `OwnedFd` (owned) |
| `&T` (borrowed) | `BorrowedFd<'a>` (borrowed) |
| `*const T` (raw) | `RawFd` (raw) |
| `AsRef<T>` (lending) | `AsFd` (lending) |
| Use-after-free | Use-after-close |
| Double-free | Double-close |

**Buffer ownership in completion IO:**
The io_uring buffer ownership model (`IoBuf: 'static + Unpin`) leverages Rust's move semantics to ensure:
- The buffer cannot be accessed while the kernel holds a pointer to it (moved away).
- The buffer is guaranteed to be returned to the caller (returned in the tuple).
- The buffer cannot be deallocated during the operation (`'static` bound).

This is a direct encoding of a kernel-level safety requirement into the type system.

---

## Summary of Architectural Layers

```
                                     ┌─────────────────────┐
                                     │    Application       │
                                     │  (user code)         │
                                     └─────────┬───────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
          ┌────────▼────────┐      ┌──────────▼──────────┐    ┌────────▼────────┐
          │   std::io        │      │   tokio              │    │   tokio-uring   │
          │   Read/Write     │      │   AsyncRead/Write    │    │   monoio        │
          │   (synchronous)  │      │   (readiness-based)  │    │   (completion)  │
          └────────┬────────┘      └──────────┬──────────┘    └────────┬────────┘
                   │                          │                        │
                   │                  ┌───────▼───────┐      ┌────────▼────────┐
                   │                  │   mio           │      │   io-uring      │
                   │                  │   (event loop)  │      │   (ring mgmt)   │
                   │                  └───────┬───────┘      └────────┬────────┘
                   │                          │                        │
          ┌────────▼──────────────────────────▼────────────────────────▼────────┐
          │                        Kernel                                       │
          │   read/write/sendfile    epoll/kqueue/IOCP     io_uring SQ/CQ      │
          └────────────────────────────────────────────────────────────────────┘
```

---

## Go IO Ecosystem


---

## 1. `io` Package -- Core Interfaces

### 1.1 Fundamental Interfaces

#### `io.Reader`

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}
```

The single most important interface in Go's IO ecosystem. Design properties:

- **Caller-allocated buffer**: The caller provides `p`, a byte slice to read into. The implementation writes up to `len(p)` bytes and returns the count.
- **Partial reads are valid**: `Read` may return `n > 0` even when `err != nil`. In particular, `Read` may return `n > 0, io.EOF` when reaching end-of-stream with data still available.
- **Contract**: After `Read` returns, the caller owns `p[:n]`. The implementation must not retain a reference to `p`.
- **Zero-length read**: `Read(p)` where `len(p) == 0` should return `0, nil` (or `0, err` if an error is pending). This is sometimes used as a "peek for error" mechanism.

The single-method design is the cornerstone of Go's IO composability. Any type with a `Read([]byte) (int, error)` method satisfies `io.Reader` via structural typing (duck typing). No explicit conformance declaration is required.

#### `io.Writer`

```go
type Writer interface {
    Write(p []byte) (n int, err error)
}
```

Symmetric to Reader, with one critical asymmetry:

- **Short writes are errors**: If `Write` returns `n < len(p)`, it MUST also return a non-nil error. This differs from `Read`, where short reads are normal.
- **Must not modify the slice**: The implementation must not modify `p`, even temporarily. This enables callers to pass the same buffer to multiple writers without copying.
- **Must not retain `p`**: If the writer needs the data beyond the call, it must copy.

#### Design philosophy behind Reader/Writer

1. **One method = one concept**. Go deliberately avoided `ReadWrite` as a fundamental interface. The fundamental unit is a single capability.
2. **Byte-oriented**: Everything flows through `[]byte`. No generic type parameter, no associated types. Bytes are the universal interchange format.
3. **Synchronous signature**: No callbacks, no futures. The goroutine blocks until data is available. Concurrency is handled at a different layer (goroutines + netpoller), not in the IO interface.
4. **Error in return position**: Errors are values, returned alongside the result. No exceptions, no typed error hierarchies. Just `error`, an interface with a single `Error() string` method.

### 1.2 Resource Lifecycle Interfaces

#### `io.Closer`

```go
type Closer interface {
    Close() error
}
```

- Returns an error because closing a file may flush buffers, and that flush may fail.
- Idempotency is NOT guaranteed by the interface contract. Whether `Close()` can be called twice is implementation-defined. `os.File.Close()` returns an error on double-close.
- Often deferred: `defer f.Close()` is idiomatic, but the returned error is then silently discarded. This is a known ergonomic tension in Go's design.

#### `io.Seeker`

```go
type Seeker interface {
    Seek(offset int64, whence int) (int64, error)
}
```

- `whence` uses constants: `io.SeekStart` (0), `io.SeekCurrent` (1), `io.SeekEnd` (2). These mirror POSIX `lseek` semantics exactly.
- Returns the new absolute offset from the start.
- `Seek(0, io.SeekCurrent)` is the idiomatic "tell" operation (get current position without moving).

#### `io.ReaderAt`

```go
type ReaderAt interface {
    ReadAt(p []byte, off int64) (n int, err error)
}
```

- Reads from an absolute offset. Does NOT affect (and is not affected by) the current seek position.
- Stronger contract than `Read`: when `ReadAt` returns `n < len(p)`, it MUST return a non-nil error. Partial reads at EOF return `n, io.EOF`.
- **Safe for concurrent use**: `ReadAt` must be safe to call from multiple goroutines simultaneously on the same source. This is a stated requirement in the interface documentation.
- This concurrency safety is the key distinction from `Read` + `Seek`. `ReaderAt` enables parallel section reads (critical for formats like PDF, ZIP, database files).

#### `io.WriterAt`

```go
type WriterAt interface {
    WriteAt(p []byte, off int64) (n int, err error)
}
```

- Analogous to `ReaderAt`. Writes at an absolute offset without affecting seek position.
- Also safe for concurrent use, provided the ranges do not overlap.

#### `io.ReaderFrom`

```go
type ReaderFrom interface {
    ReadFrom(r Reader) (n int64, err error)
}
```

- Optimization interface. When a Writer also implements `ReaderFrom`, `io.Copy` calls `ReadFrom` instead of doing the generic read/write loop.
- Enables kernel-level optimizations: `sendfile(2)`, `splice(2)`, zero-copy paths.
- `net.TCPConn` implements `ReaderFrom`, so `io.Copy(tcpConn, file)` can use `sendfile`.

#### `io.WriterTo`

```go
type WriterTo interface {
    WriteTo(w Writer) (n int64, err error)
}
```

- The dual of `ReaderFrom`. When a Reader also implements `WriterTo`, `io.Copy` calls `WriteTo`.
- `bytes.Buffer` and `bytes.Reader` implement `WriterTo` for efficient single-call writes.

### 1.3 Composed Interfaces

Go composes interfaces by embedding. No new methods are added; the composed interface is purely the union of the embedded methods.

```go
type ReadWriter interface {
    Reader
    Writer
}

type ReadCloser interface {
    Reader
    Closer
}

type WriteCloser interface {
    Writer
    Closer
}

type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}

type ReadWriteSeeker interface {
    Reader
    Writer
    Seeker
}

type ReadSeeker interface {
    Reader
    Seeker
}

type WriteSeeker interface {
    Writer
    Seeker
}
```

Key observations:

- **No `ReadWriteCloserSeeker`**: The standard library stops at 3-way compositions and does not provide all possible combinations. Users define their own when needed.
- **Embedding preserves duck typing**: A type that implements `Read`, `Write`, and `Close` automatically satisfies `ReadWriteCloser` without declaring it.
- **These are primarily used as function parameter types**: e.g., `json.NewDecoder(r io.Reader)`, `http.Post(url, contentType, body io.Reader)`. The composed interfaces appear in return types and struct fields to communicate capability bundles.
- **No `ReadWriteCloseSeeker` or `ReadWriteCloserSeeker`**: Notably missing. The standard library avoids combinatorial explosion by stopping at commonly needed combinations.

### 1.4 The Copy Family

#### `io.Copy`

```go
func Copy(dst Writer, src Reader) (written int64, err error)
```

The central data-transfer function. Implementation strategy:

1. Check if `src` implements `WriterTo` -- if so, call `src.WriteTo(dst)`.
2. Check if `dst` implements `ReaderFrom` -- if so, call `dst.ReadFrom(src)`.
3. Otherwise, allocate a 32 KiB buffer and loop: `src.Read(buf)` then `dst.Write(buf[:n])`.

This dispatch is the mechanism for zero-copy optimization. The caller writes `io.Copy(dst, src)` and the implementation figures out the fastest path.

`io.Copy` returns `io.EOF` as `nil` -- it translates the expected end-of-stream into a successful return. Any other error propagates.

#### `io.CopyN`

```go
func CopyN(dst Writer, src Reader, n int64) (written int64, err error)
```

Copies exactly `n` bytes. Returns `io.EOF` if fewer than `n` bytes were available. Implemented as `Copy(dst, LimitReader(src, n))`.

#### `io.CopyBuffer`

```go
func CopyBuffer(dst Writer, src Reader, buf []byte) (written int64, err error)
```

Like `Copy`, but uses a caller-provided buffer instead of allocating one. Enables:
- Buffer reuse across multiple copies (amortized allocation).
- Control over buffer size (the 32 KiB default may not be optimal for all workloads).

Still checks for `WriterTo`/`ReaderFrom` first; the buffer is only used in the fallback path.

### 1.5 `io.Pipe`

```go
func Pipe() (*PipeReader, *PipeWriter)
```

Creates a synchronous, in-memory pipe. Properties:

- **No internal buffering**: A write blocks until a corresponding read consumes the data (or the pipe is closed). This is synchronous rendezvous, not a buffered channel.
- **Thread-safe**: Reads and writes may be called from different goroutines concurrently. This is the intended usage.
- `PipeReader.CloseWithError(err)` / `PipeWriter.CloseWithError(err)` propagate a custom error to the other end.
- Common use: bridging an `io.Writer`-based API with an `io.Reader`-based API. E.g., JSON-encoding directly into an HTTP request body without materializing the entire body in memory.

```go
pr, pw := io.Pipe()
go func() {
    json.NewEncoder(pw).Encode(data)
    pw.Close()
}()
http.Post(url, "application/json", pr)
```

### 1.6 Reader Adapters and Combinators

#### `io.LimitReader`

```go
func LimitReader(r Reader, n int64) Reader
```

Returns a Reader that reads from `r` but stops after `n` bytes. After `n` bytes, further reads return `0, io.EOF`.

The returned type is `*io.LimitedReader`:

```go
type LimitedReader struct {
    R Reader // underlying reader
    N int64  // bytes remaining
}
```

Fields are exported, enabling inspection of remaining count and access to the wrapped reader. This is a deliberate design choice -- Go exposes the concrete type alongside the constructor.

#### `io.SectionReader`

```go
func NewSectionReader(r ReaderAt, off int64, n int64) *SectionReader
```

Provides `Read`, `Seek`, and `ReadAt` over a section `[off, off+n)` of the underlying `ReaderAt`. The SectionReader maintains its own independent position within the section.

Implements: `io.Reader`, `io.Seeker`, `io.ReaderAt`.

Key use case: reading sections of a file without seeking the underlying file descriptor. Multiple `SectionReader`s over the same `ReaderAt` can operate concurrently because `ReadAt` is concurrency-safe.

#### `io.TeeReader`

```go
func TeeReader(r Reader, w Writer) Reader
```

Returns a Reader that writes to `w` everything it reads from `r`. The write must consume all bytes; short writes cause an error. Named after the Unix `tee` command.

Use case: logging, checksumming, or duplicating a stream as it is consumed.

```go
h := sha256.New()
body := io.TeeReader(resp.Body, h)
io.Copy(os.Stdout, body)
checksum := h.Sum(nil)
```

#### `io.MultiReader`

```go
func MultiReader(readers ...Reader) Reader
```

Concatenates multiple readers sequentially. Reads from the first reader until `io.EOF`, then the next, and so on. Returns `io.EOF` after the last reader is exhausted.

The returned Reader consumes each underlying reader exactly once, in order. Once a reader returns EOF, it is never read again.

#### `io.MultiWriter`

```go
func MultiWriter(writers ...Writer) Writer
```

Creates a Writer that duplicates writes to all provided writers, like the Unix `tee` command. Each write is sent to every writer in sequence. If any writer returns an error, the MultiWriter returns that error.

### 1.7 Sentinel Errors and Utilities

#### `io.EOF`

```go
var EOF = errors.New("EOF")
```

A sentinel error value (not a type). This is checked with `==`, not with type assertions:

```go
if err == io.EOF {
    // stream ended normally
}
```

Design implications:
- **EOF is not an error in the exceptional sense**. It signals normal stream termination. This is why `io.Copy` translates `io.EOF` to `nil`.
- **Wrapping breaks sentinel checks**: `fmt.Errorf("reading: %w", io.EOF)` wraps the error. After Go 1.13, `errors.Is(err, io.EOF)` handles wrapped sentinels, but the ecosystem still has friction here.
- Other sentinel errors in `io`: `io.ErrUnexpectedEOF` (stream ended mid-record), `io.ErrClosedPipe`, `io.ErrNoProgress`, `io.ErrShortBuffer`, `io.ErrShortWrite`.

#### `io.NopCloser`

```go
func NopCloser(r Reader) ReadCloser
```

Wraps a Reader with a no-op `Close()` that always returns `nil`. Used when an API requires `ReadCloser` but your reader doesn't need closing (e.g., `bytes.Reader`, `strings.Reader`).

#### `io.ReadAll`

```go
func ReadAll(r Reader) ([]byte, error)
```

Reads from `r` until EOF and returns the accumulated bytes. Internally grows a buffer as needed (starts at 512 bytes). Translates `io.EOF` to `nil` in the returned error.

Moved from `ioutil.ReadAll` in Go 1.16. The `ioutil` package is now deprecated (all functions moved to `io` or `os`).

#### `io.Discard`

```go
var Discard Writer = devNull(0)
```

A Writer that discards all data (like `/dev/null`). Implements `io.ReaderFrom` for maximum efficiency in `io.Copy` -- discards without even copying into a buffer.

---

## 2. `bufio` Package -- Buffered IO

### 2.1 `bufio.Reader`

```go
func NewReader(rd io.Reader) *Reader
func NewReaderSize(rd io.Reader, size int) *Reader
```

Wraps an `io.Reader` with a buffer (default 4096 bytes). The buffer is read-ahead: a single call to the underlying reader fills the buffer, and subsequent reads are served from the buffer.

Key methods beyond `io.Reader`:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `ReadByte` | `() (byte, error)` | Read single byte (no allocation) |
| `UnreadByte` | `() error` | Push back one byte |
| `ReadRune` | `() (rune, int, error)` | Read single UTF-8 rune |
| `UnreadRune` | `() error` | Push back one rune |
| `ReadLine` | `() ([]byte, bool, error)` | Low-level line read (no trailing newline). Returns `isPrefix=true` if line exceeds buffer. |
| `ReadString` | `(delim byte) (string, error)` | Read until delimiter (inclusive). Allocates. |
| `ReadBytes` | `(delim byte) ([]byte, error)` | Read until delimiter (inclusive). Returns byte slice. |
| `ReadSlice` | `(delim byte) ([]byte, error)` | Read until delimiter. Returns slice into buffer (zero-copy, but only valid until next read). |
| `Peek` | `(n int) ([]byte, error)` | Return next n bytes without advancing. Slice into buffer. |
| `Buffered` | `() int` | Number of bytes currently in buffer |
| `Reset` | `(r io.Reader)` | Reuse buffer with new reader |
| `Discard` | `(n int) (int, error)` | Skip n bytes efficiently |
| `WriteTo` | `(w io.Writer) (int64, error)` | Implements `io.WriterTo` for efficient draining |

`ReadSlice` vs `ReadBytes` vs `ReadString`: a deliberate three-tier API offering zero-copy-but-volatile, heap-allocated-bytes, and string respectively.

### 2.2 `bufio.Writer`

```go
func NewWriter(w io.Writer) *Writer
func NewWriterSize(w io.Writer, size int) *Writer
```

Wraps an `io.Writer` with a buffer (default 4096 bytes). Writes accumulate in the buffer until it fills or `Flush()` is called.

Key methods:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `Flush` | `() error` | Write buffered data to underlying writer |
| `Available` | `() int` | Unused bytes in buffer |
| `Buffered` | `() int` | Bytes written to buffer but not yet flushed |
| `WriteByte` | `(c byte) error` | Write single byte |
| `WriteRune` | `(r rune) (int, error)` | Write single UTF-8 rune |
| `WriteString` | `(s string) (int, error)` | Write string (avoids `[]byte` conversion) |
| `ReadFrom` | `(r io.Reader) (int64, error)` | Implements `io.ReaderFrom` |
| `Reset` | `(w io.Writer)` | Reuse buffer with new writer |

**Critical**: Failing to call `Flush()` (or `Close()` on a wrapper) is a common bug. Data remains in the buffer and is never written. This is an explicit design decision -- auto-flushing would mask performance characteristics.

### 2.3 `bufio.Scanner`

```go
func NewScanner(r io.Reader) *Scanner
```

Higher-level abstraction for reading delimited tokens (lines, words, runes, or custom patterns).

**API surface**:

```go
scanner := bufio.NewScanner(reader)
scanner.Split(bufio.ScanLines)  // set the split function
for scanner.Scan() {
    line := scanner.Text()  // or scanner.Bytes()
}
if err := scanner.Err(); err != nil {
    // handle error
}
```

**Split functions**: `func(data []byte, atEOF bool) (advance int, token []byte, err error)`

The split function receives the buffered data and returns:
- `advance`: how many bytes to consume from the buffer.
- `token`: the extracted token (may be a sub-slice of `data`, or nil to request more data).
- `err`: signals a fatal scanning error.

If `token == nil` and `err == nil`, the scanner reads more data and tries again.

Built-in split functions:

| Function | Token type |
|----------|-----------|
| `bufio.ScanLines` | Lines (strips `\n` and `\r\n`) |
| `bufio.ScanWords` | Whitespace-delimited words |
| `bufio.ScanRunes` | UTF-8 runes |
| `bufio.ScanBytes` | Individual bytes |

**Buffer management**:

```go
scanner.Buffer(buf, maxSize)
```

Overrides the default 64 KiB maximum token size. Without this, scanning fails with `bufio.ErrTooLong` if a single token exceeds the buffer.

The scanner design is intentionally **pull-based** (loop with `Scan()`) rather than callback-based. Error checking is deferred to after the loop, simplifying the common case.

---

## 3. `os` Package -- File IO

### 3.1 `os.File`

The concrete type representing an open file descriptor. Implements:

- `io.Reader`
- `io.Writer`
- `io.Closer`
- `io.Seeker`
- `io.ReaderAt`
- `io.WriterAt`
- `io.ReaderFrom` (uses `sendfile`/`copy_file_range` on Linux when possible)
- `io.StringWriter`

This is the primary bridge between the abstract `io` interfaces and the operating system.

`os.File` is a struct wrapping an unexported `*file`:

```go
type File struct {
    *file  // unexported, contains fd, name, dirinfo
}
```

The file descriptor is managed by the runtime. Finalization (GC-triggered close) exists as a safety net but must not be relied upon.

### 3.2 Opening Files

#### `os.Open`

```go
func Open(name string) (*File, error)
```

Opens a file for reading. Equivalent to `OpenFile(name, O_RDONLY, 0)`. The most common file-opening function.

#### `os.Create`

```go
func Create(name string) (*File, error)
```

Creates or truncates a file for writing. Equivalent to `OpenFile(name, O_RDWR|O_CREATE|O_TRUNC, 0666)`. Note: the `0666` is before umask.

#### `os.OpenFile`

```go
func OpenFile(name string, flag int, perm FileMode) (*File, error)
```

The general-purpose opener. Flags mirror POSIX:

| Flag | Constant | Meaning |
|------|----------|---------|
| `os.O_RDONLY` | 0 | Read-only |
| `os.O_WRONLY` | 1 | Write-only |
| `os.O_RDWR` | 2 | Read-write |
| `os.O_APPEND` | | Append on write |
| `os.O_CREATE` | | Create if not exists |
| `os.O_EXCL` | | Error if exists (with O_CREATE) |
| `os.O_SYNC` | | Synchronous IO |
| `os.O_TRUNC` | | Truncate on open |

### 3.3 File Permissions Model

`os.FileMode` is a `uint32` bitmask:

```go
type FileMode uint32

const (
    ModeDir        FileMode = 1 << (32 - 1 - iota)  // directory
    ModeAppend                                        // append-only
    ModeExclusive                                     // exclusive use
    ModeTemporary                                     // temporary file
    ModeSymlink                                       // symbolic link
    ModeDevice                                        // device file
    ModeNamedPipe                                     // named pipe (FIFO)
    ModeSocket                                        // Unix domain socket
    ModeSetuid                                        // setuid
    ModeSetgid                                        // setgid
    ModeCharDevice                                    // char device (with ModeDevice)
    ModeSticky                                        // sticky
    ModeIrregular                                     // non-regular file
    ModeType = ModeDir | ModeSymlink | ModeNamedPipe | ModeSocket | ModeDevice | ModeCharDevice | ModeIrregular
    ModePerm FileMode = 0777  // permission bits
)
```

Lower 9 bits are standard Unix rwxrwxrwx. `Perm()` method extracts them: `mode.Perm()` returns `mode & ModePerm`.

The permission passed to `Create`/`OpenFile` is modified by the process umask. This matches POSIX behavior -- the requested permission is a ceiling, not the actual permission.

### 3.4 Standard Streams

```go
var (
    Stdin  = NewFile(uintptr(syscall.Stdin), "/dev/stdin")
    Stdout = NewFile(uintptr(syscall.Stdout), "/dev/stdout")
    Stderr = NewFile(uintptr(syscall.Stderr), "/dev/stderr")
)
```

Concrete `*os.File` values, satisfying `io.Reader` (Stdin) and `io.Writer` (Stdout, Stderr). These are the bridge between the process and the terminal/pipe.

---

## 4. `net` Package -- Network IO

### 4.1 `net.Conn`

```go
type Conn interface {
    Read(b []byte) (n int, err error)
    Write(b []byte) (n int, err error)
    Close() error
    LocalAddr() Addr
    RemoteAddr() Addr
    SetDeadline(t time.Time) error
    SetReadDeadline(t time.Time) error
    SetWriteDeadline(t time.Time) error
}
```

`net.Conn` embeds `io.Reader`, `io.Writer`, and `io.Closer` semantics (same method signatures) plus deadline management. The concrete types (`TCPConn`, `UDPConn`, `UnixConn`, `IPConn`) implement this interface.

Deadline semantics:
- Deadlines are **absolute times**, not durations. Set with `time.Now().Add(5 * time.Second)`.
- A zero `time.Time` means no deadline.
- After a deadline expires, the Read/Write returns a `net.Error` with `Timeout() == true`.
- Deadlines can be reset or extended at any time, even from another goroutine.

Because `net.Conn` satisfies `io.ReadWriteCloser`, all `io` and `bufio` machinery works transparently with network connections:

```go
conn, _ := net.Dial("tcp", "example.com:80")
reader := bufio.NewReader(conn)
line, _ := reader.ReadString('\n')
io.Copy(os.Stdout, conn)
```

### 4.2 `net.Listener`

```go
type Listener interface {
    Accept() (Conn, error)
    Close() error
    Addr() Addr
}
```

The server-side interface. `Accept()` blocks (or respects deadline set via the concrete type) until a new connection arrives.

### 4.3 Dialing and Listening

#### Client side

```go
func Dial(network, address string) (Conn, error)
func DialTimeout(network, address string, timeout time.Duration) (Conn, error)
```

`network` is one of: `"tcp"`, `"tcp4"`, `"tcp6"`, `"udp"`, `"udp4"`, `"udp6"`, `"unix"`, `"unixpacket"`.

`net.Dialer` struct provides more control:

```go
dialer := &net.Dialer{
    Timeout:   5 * time.Second,
    KeepAlive: 30 * time.Second,
    LocalAddr: localAddr,
}
conn, err := dialer.Dial("tcp", "example.com:443")
```

#### Server side

```go
func Listen(network, address string) (Listener, error)
```

The canonical TCP server pattern:

```go
ln, _ := net.Listen("tcp", ":8080")
for {
    conn, _ := ln.Accept()
    go handleConn(conn)   // goroutine per connection
}
```

### 4.4 Goroutine-Per-Connection Model

Go's network IO model is fundamentally different from event-loop frameworks (Node.js, Netty, Tokio):

1. **Blocking API, non-blocking execution**: `Read()` and `Write()` on a `net.Conn` appear to block the calling goroutine, but the Go runtime internally uses non-blocking file descriptors.
2. **Goroutines are cheap**: A goroutine starts with ~2-8 KiB of stack (dynamically grown). A server can sustain millions of goroutines.
3. **One goroutine per connection**: The idiomatic pattern is to spawn a goroutine for each accepted connection. The goroutine blocks on `Read`, processes the data, blocks on `Write`, loops. There is no callback inversion.
4. **No explicit async/await**: Go has no `async` keyword, no `Future`/`Promise` types, no colored function problem. Every function call is potentially suspending (from the goroutine's perspective), but the syntax is identical to blocking code.
5. **M:N scheduling**: Goroutines are multiplexed onto OS threads by the Go runtime scheduler. When a goroutine blocks on IO, the runtime parks it and runs another goroutine on the same thread.

This design means:
- All existing synchronous code (including `io.Copy`, `bufio.Scanner`, `json.Decoder`) works correctly in concurrent contexts without modification.
- Composition is trivial: `io.Copy(conn1, conn2)` implements a TCP proxy.
- Backpressure is implicit: if the writer is slow, `Write` blocks the goroutine, which stops reading from the source.

---

## 5. `syscall`/`internal/poll` -- Low-Level IO

### 5.1 File Descriptor Management

The `syscall` package provides raw system call wrappers:

```go
func Open(path string, mode int, perm uint32) (fd int, err error)
func Read(fd int, p []byte) (n int, err error)
func Write(fd int, p []byte) (n int, err error)
func Close(fd int) (err error)
func Seek(fd int, offset int64, whence int) (off int64, err error)
```

These are thin wrappers around the kernel system calls. `os.File` wraps these with:
- Automatic non-blocking mode management.
- Integration with the runtime poller (for network and pipe FDs).
- Finalizer registration for GC-triggered cleanup.
- Path tracking for error messages.

### 5.2 The Runtime Netpoller

The netpoller is the hidden engine that makes blocking IO APIs work efficiently. It is implemented in `runtime/netpoll_*.go`:

| Platform | Mechanism |
|----------|-----------|
| Linux | `epoll` (`epoll_create1`, `epoll_ctl`, `epoll_wait`) |
| macOS/BSD | `kqueue` (`kqueue`, `kevent`) |
| Windows | IOCP (`CreateIoCompletionPort`) |
| Solaris | Event ports |

Architecture:

```
     goroutine                      runtime
   +-----------+               +--------------+
   | conn.Read |               |  netpoller   |
   |   blocks  | -- park -->   |  (epoll/     |
   |           |               |   kqueue)    |
   +-----------+               |              |
                               |  FD ready    |
   +-----------+               |  event       |
   | conn.Read | <-- wake --   |              |
   |  returns  |               +--------------+
   +-----------+
```

Step by step:

1. When `os.File` or `net.Conn` is created, the underlying file descriptor is set to **non-blocking** mode (`O_NONBLOCK`).
2. On a `Read` call: the runtime attempts a non-blocking `read(2)`.
3. If `read(2)` returns `EAGAIN`/`EWOULDBLOCK`, the runtime registers the FD with epoll/kqueue for read-readiness and **parks the goroutine** (removes it from the run queue).
4. A dedicated poller thread (or the scheduler's sysmon thread) calls `epoll_wait`/`kevent` to wait for events.
5. When the FD becomes ready, the poller **unparks the goroutine**, which resumes execution.
6. The goroutine retries the `read(2)`, which now succeeds.

This entire mechanism is invisible to application code. From the goroutine's perspective, `Read` simply blocked until data was available.

Key implementation details:
- **`internal/poll.FD`**: The actual struct managing a file descriptor. Contains the fd int, read/write mutexes, and the pollDesc (poller descriptor).
- **`runtime.pollDesc`**: Runtime-internal structure linking an FD to the poller. Contains the goroutine to wake and the deadline timer.
- **Deadline integration**: `SetReadDeadline`/`SetWriteDeadline` register timer events in the netpoller. When the deadline fires, the poller unparks the goroutine with a timeout error, even if the FD is not ready.

### 5.3 Platform-Specific Optimizations

The `internal/poll` package implements several platform-specific fast paths:

| Operation | Linux | macOS |
|-----------|-------|-------|
| File-to-socket copy | `sendfile(2)` | `sendfile(2)` |
| File-to-file copy | `copy_file_range(2)` | `clonefile(2)` / `fcopyfile` |
| Socket-to-socket | `splice(2)` | (fallback to userspace) |
| Scatter/gather IO | `readv(2)` / `writev(2)` | `readv(2)` / `writev(2)` |

These are exposed through the `io.ReaderFrom` / `io.WriterTo` optimization interfaces. `io.Copy(tcpConn, file)` transparently uses `sendfile` without the caller knowing.

---

## 6. Key Design Patterns

### 6.1 The Small Interface Philosophy

Go's IO interfaces are among the smallest possible:

| Interface | Methods | Purpose |
|-----------|---------|---------|
| `Reader` | 1 | Consume bytes |
| `Writer` | 1 | Produce bytes |
| `Closer` | 1 | Release resource |
| `Seeker` | 1 | Reposition |

This is a deliberate design philosophy articulated by Rob Pike and the Go team:

> "The bigger the interface, the weaker the abstraction."

Consequences:
- **Maximum implementability**: Any type can become a Reader by adding one method. The barrier to entry is minimal.
- **Maximum composability**: Functions that accept `io.Reader` work with files, network connections, in-memory buffers, HTTP response bodies, compressed streams, encrypted streams, and user-defined types.
- **No "interface pollution"**: Types don't accumulate large conformance lists. A `bytes.Buffer` doesn't need to declare `implements Reader, Writer, ByteReader, ByteWriter, StringWriter, WriterTo, ReaderFrom`. It just has the methods, and Go's structural typing handles the rest.

### 6.2 Composability via Interface Embedding

Go's interface composition is additive embedding, not inheritance:

```go
// Composition at the interface level
type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}

// Composition at the struct level (adapter pattern)
type readWriteCloser struct {
    io.Reader
    io.Writer
    io.Closer
}

// Factory that composes unrelated objects
func NewReadWriteCloser(r io.Reader, w io.Writer, c io.Closer) io.ReadWriteCloser {
    return &readWriteCloser{r, w, c}
}
```

The struct embedding approach is used extensively in the standard library. For example, `http.Response.Body` is an `io.ReadCloser` that may be composed from different underlying readers depending on the response (chunked, gzip, limit).

### 6.3 The Decorator/Wrapper Pattern

Go's IO ecosystem is built on wrapping:

```
os.File (raw)
  -> bufio.Reader (buffering)
    -> gzip.Reader (decompression)
      -> json.Decoder (parsing)
```

Each layer implements `io.Reader` and wraps another `io.Reader`. This is not inheritance -- it's composition. The pattern works because:

1. Every wrapper accepts `io.Reader` (the minimum interface).
2. Every wrapper produces `io.Reader` (so it can be wrapped further).
3. No wrapper needs to know what it wraps.

Standard library wrappers:

| Wrapper | Input | Added behavior |
|---------|-------|---------------|
| `bufio.NewReader` | `io.Reader` | Buffering, peek, readline |
| `io.LimitReader` | `io.Reader` | Byte count limit |
| `io.TeeReader` | `io.Reader` + `io.Writer` | Tap / mirror |
| `gzip.NewReader` | `io.Reader` | Decompression |
| `cipher.StreamReader` | `io.Reader` + `cipher.Stream` | Decryption |
| `io.NopCloser` | `io.Reader` | Adds no-op Close |
| `bufio.NewWriter` | `io.Writer` | Buffering |
| `gzip.NewWriter` | `io.Writer` | Compression |
| `io.MultiWriter` | `...io.Writer` | Fan-out |
| `csv.NewWriter` | `io.Writer` | CSV formatting |

### 6.4 Error Handling with `io.EOF`

EOF as a sentinel value rather than a type creates a specific error-handling pattern:

```go
for {
    n, err := r.Read(buf)
    if n > 0 {
        // Process buf[:n] -- MUST process data before checking error
    }
    if err == io.EOF {
        break  // Normal termination
    }
    if err != nil {
        return err  // Actual error
    }
}
```

The critical pattern: **process data before checking error**. `Read` can return `n > 0` alongside `io.EOF` (meaning "here's the last chunk and we're done"). Code that checks `err` before processing `buf[:n]` loses the final bytes.

Higher-level abstractions (`bufio.Scanner`, `io.Copy`, `io.ReadAll`) handle this pattern internally, so most application code never writes this loop.

### 6.5 Why Go Does Not Need Async IO

Go's answer to the C10K problem is not async IO -- it is goroutines + netpoller:

| Approach | Mechanism | Code style |
|----------|-----------|------------|
| Node.js / libuv | Event loop + callbacks | Callback/promise chains |
| Rust / Tokio | Polling futures + async/await | Colored functions (async fn) |
| Java / Netty | NIO selectors + event loops | Handler pipelines |
| **Go** | **Goroutines + runtime netpoller** | **Plain synchronous code** |

The advantages:
1. **No function coloring**: `Read()` is `Read()` everywhere. No `async Read()`, no `.await`, no `Future<int>`. The same function works in both concurrent and sequential contexts.
2. **No callback inversion**: Error handling, loops, conditionals all work normally. A goroutine's control flow reads top-to-bottom.
3. **Implicit backpressure**: When a writer is slow, the writing goroutine blocks, which naturally slows down the reading goroutine (since they share a pipeline via `io.Copy` or explicit read/write loops).
4. **Composability preserved**: Every IO wrapper, adapter, and utility from the standard library works without modification in concurrent code. There is no `AsyncReader` vs `Reader` split.
5. **Stack management**: Goroutine stacks grow and shrink dynamically (segmented/contiguous stack, copied on growth). This avoids the fixed stack overhead of OS threads.

The tradeoff: goroutines have overhead (~2-8 KiB minimum memory) and the scheduler adds latency compared to raw epoll. For extreme-throughput scenarios (millions of concurrent connections), this matters. For the vast majority of server applications, it does not.

### 6.6 Duck Typing for IO

Go's interfaces are satisfied implicitly (structural typing):

```go
type MyBuffer struct {
    data []byte
    pos  int
}

func (b *MyBuffer) Read(p []byte) (int, error) {
    n := copy(p, b.data[b.pos:])
    b.pos += n
    if b.pos >= len(b.data) {
        return n, io.EOF
    }
    return n, nil
}

// MyBuffer now satisfies io.Reader without any declaration.
// This compiles and works:
var r io.Reader = &MyBuffer{data: []byte("hello")}
```

Implications for the IO ecosystem:
- Third-party types instantly interoperate with all standard library IO code.
- No dependency on the `io` package is needed to implement `io.Reader` (the method signature is enough), although in practice everyone imports `io` for `io.EOF`.
- Testing is trivial: `strings.NewReader("test data")` creates an `io.Reader` for testing any reader-consuming code.

---

## 7. Cross-Cutting Observations

### 7.1 What Go Gets Right

1. **Universal byte interface**: `[]byte` as the interchange type eliminates generic complexity. Every IO operation speaks the same language.
2. **Optimization via interface detection**: `io.Copy` checking for `WriterTo`/`ReaderFrom` is elegant -- the fast path is discovered at runtime without exposing it in the API.
3. **Goroutine model eliminates async bifurcation**: The entire standard library is "async-capable" without any async syntax. This is arguably Go's single biggest IO design win.
4. **Concrete types alongside interfaces**: `io.LimitedReader` has exported fields. `os.File` is a concrete struct. This enables inspection and composition that pure-interface designs cannot.
5. **Wrappers compose linearly**: `bufio.NewReader(gzip.NewReader(file))` reads like a pipeline. No inheritance trees, no abstract factories.

### 7.2 What Go Gets Wrong (or Trades Off)

1. **No typed errors**: `error` is a single interface. `Read` returns `error`, not a specific IO error type. Callers must use sentinel comparison (`== io.EOF`) or type assertions (`err.(*os.PathError)`). Error handling is stringly-typed in practice.
2. **EOF is a sentinel, not a type**: `io.EOF` as a `var` means it can be wrapped accidentally, breaking `==` checks. Go 1.13's `errors.Is` mitigates this but doesn't eliminate the footgun.
3. **Close error swallowing**: `defer f.Close()` discards the error. The language provides no ergonomic way to defer-and-check. This is a real data-loss vector for writers with buffered data.
4. **No generics in IO (before 1.18)**: Everything is `[]byte`. There is no `Reader[T]` for typed streaming. Even after Go 1.18 added generics, the IO interfaces remain byte-oriented for compatibility.
5. **Partial read contract is subtle**: The rule "process n bytes even if err != nil" trips many programmers. `bufio.Scanner` exists partly to hide this complexity.
6. **No resource-safety at the type level**: There is no `~Copyable`-style mechanism to prevent use-after-close or double-close. Correctness depends on programmer discipline and `defer`.
7. **Buffer ownership is convention, not enforced**: "Must not retain `p`" and "must not modify `p`" are documented contracts, not compiler-enforced invariants.

### 7.3 Interface Census

Complete set of single-capability IO interfaces in the standard `io` package:

| Interface | Method | Notes |
|-----------|--------|-------|
| `Reader` | `Read([]byte) (int, error)` | Fundamental input |
| `Writer` | `Write([]byte) (int, error)` | Fundamental output |
| `Closer` | `Close() error` | Resource release |
| `Seeker` | `Seek(int64, int) (int64, error)` | Repositioning |
| `ReaderAt` | `ReadAt([]byte, int64) (int, error)` | Positional read (concurrent-safe) |
| `WriterAt` | `WriteAt([]byte, int64) (int, error)` | Positional write |
| `ReaderFrom` | `ReadFrom(Reader) (int64, error)` | Optimization hook for Copy |
| `WriterTo` | `WriteTo(Writer) (int64, error)` | Optimization hook for Copy |
| `ByteReader` | `ReadByte() (byte, error)` | Single-byte input |
| `ByteWriter` | `WriteByte(byte) error` | Single-byte output |
| `ByteScanner` | `ReadByte` + `UnreadByte` | Byte with pushback |
| `RuneReader` | `ReadRune() (rune, int, error)` | Rune-level input |
| `RuneScanner` | `ReadRune` + `UnreadRune` | Rune with pushback |
| `StringWriter` | `WriteString(string) (int, error)` | Avoids string->[]byte |

Composed interfaces (all in `io` package): `ReadWriter`, `ReadCloser`, `WriteCloser`, `ReadWriteCloser`, `ReadSeeker`, `WriteSeeker`, `ReadWriteSeeker`.

### 7.4 Packages That Implement `io.Reader` / `io.Writer`

A non-exhaustive map of the standard library's IO fabric:

| Package | Reader types | Writer types |
|---------|-------------|-------------|
| `os` | `*File` | `*File` |
| `net` | `Conn`, `TCPConn`, `UDPConn`, `UnixConn` | (same) |
| `bytes` | `*Buffer`, `*Reader` | `*Buffer` |
| `strings` | `*Reader` | `*Builder` |
| `bufio` | `*Reader` | `*Writer` |
| `compress/gzip` | `*Reader` | `*Writer` |
| `compress/zlib` | `*Reader` | `*Writer` |
| `compress/flate` | `*Reader` | `*Writer` |
| `crypto/tls` | `*Conn` | `*Conn` |
| `crypto/cipher` | `StreamReader` | `StreamWriter` |
| `encoding/base64` | `*decoder` (via `NewDecoder`) | `*encoder` (via `NewEncoder`) |
| `net/http` | `Request.Body`, `Response.Body` | `ResponseWriter` |
| `archive/tar` | `*Reader` | `*Writer` |
| `archive/zip` | `io.ReadCloser` per entry | `io.Writer` per entry |
| `hash` | -- | `Hash` (implements `io.Writer`) |
| `io` | `PipeReader`, `LimitedReader`, `SectionReader` | `PipeWriter` |

This table demonstrates the reach of the one-method interface. Every domain -- compression, encryption, serialization, networking, archival -- plugs into the same `Reader`/`Writer` fabric.

---

## Java NIO & .NET IO Ecosystems


---

## 1. Java Classic IO (`java.io`)

### 1.1 Byte Stream Hierarchy

The original Java IO model (JDK 1.0, 1996) is built on two abstract base classes for byte-oriented IO:

```java
public abstract class InputStream {
    public abstract int read() throws IOException;          // single byte, returns -1 at EOF
    public int read(byte[] b) throws IOException;           // bulk read into array
    public int read(byte[] b, int off, int len) throws IOException;
    public long skip(long n) throws IOException;
    public int available() throws IOException;              // bytes readable without blocking
    public void close() throws IOException;
    public void mark(int readlimit);                        // bookmark position
    public void reset() throws IOException;                 // return to mark
    public boolean markSupported();
}

public abstract class OutputStream {
    public abstract void write(int b) throws IOException;   // single byte (low 8 bits)
    public void write(byte[] b) throws IOException;         // bulk write
    public void write(byte[] b, int off, int len) throws IOException;
    public void flush() throws IOException;
    public void close() throws IOException;
}
```

Key concrete implementations:

| Class | Purpose |
|-------|---------|
| `FileInputStream` / `FileOutputStream` | File IO, wraps OS file descriptor |
| `ByteArrayInputStream` / `ByteArrayOutputStream` | In-memory byte array as stream |
| `PipedInputStream` / `PipedOutputStream` | Inter-thread byte pipe |
| `SequenceInputStream` | Concatenation of multiple input streams |

### 1.2 Character Stream Hierarchy

Added in JDK 1.1 to handle character encoding properly. Mirror the byte streams but operate on `char` (UTF-16 code units):

```java
public abstract class Reader {
    public int read() throws IOException;                   // single char, returns -1 at EOF
    public int read(char[] cbuf) throws IOException;
    public abstract int read(char[] cbuf, int off, int len) throws IOException;
    public long skip(long n) throws IOException;
    public boolean ready() throws IOException;              // can read without blocking
    public void mark(int readAheadLimit) throws IOException;
    public void reset() throws IOException;
    public boolean markSupported();
    public abstract void close() throws IOException;
}

public abstract class Writer {
    public void write(int c) throws IOException;            // single char
    public void write(char[] cbuf) throws IOException;
    public abstract void write(char[] cbuf, int off, int len) throws IOException;
    public void write(String str) throws IOException;
    public void write(String str, int off, int len) throws IOException;
    public Writer append(CharSequence csq) throws IOException;
    public abstract void flush() throws IOException;
    public abstract void close() throws IOException;
}
```

Key concrete implementations:

| Class | Purpose |
|-------|---------|
| `InputStreamReader` / `OutputStreamWriter` | Bridge: bytes to chars using a `Charset` |
| `FileReader` / `FileWriter` | Convenience over `InputStreamReader(FileInputStream(...))` |
| `StringReader` / `StringWriter` | In-memory `String` as character stream |
| `BufferedReader` / `BufferedWriter` | Buffering layer; `BufferedReader` adds `readLine()` |
| `PrintWriter` | Formatted text output with `print()`, `println()`, `printf()` |

### 1.3 The Decorator Pattern

Java classic IO is the textbook example of the Decorator pattern. Functionality is layered by wrapping streams:

```java
// Layer 1: raw file bytes
FileInputStream fis = new FileInputStream("data.bin");

// Layer 2: buffering (8KB default)
BufferedInputStream bis = new BufferedInputStream(fis);

// Layer 3: typed data reading
DataInputStream dis = new DataInputStream(bis);

int value = dis.readInt();     // reads 4 bytes as big-endian int
double d = dis.readDouble();   // reads 8 bytes as IEEE 754 double
String s = dis.readUTF();      // reads modified UTF-8 string
```

The `FilterInputStream` / `FilterOutputStream` abstract classes serve as the base for decorators:

```java
public class FilterInputStream extends InputStream {
    protected volatile InputStream in;   // the wrapped stream

    protected FilterInputStream(InputStream in) {
        this.in = in;
    }

    // All methods delegate to `in` — subclasses override to add behavior
    public int read() throws IOException { return in.read(); }
    // ...
}
```

Key decorator subclasses of `FilterInputStream`:

| Class | Added Behavior |
|-------|---------------|
| `BufferedInputStream` | Read-ahead buffering (reduces syscalls) |
| `DataInputStream` | Primitive type reading (`readInt`, `readLong`, `readUTF`, etc.) |
| `PushbackInputStream` | Unreading bytes (pushback buffer) |
| `CheckedInputStream` (java.util.zip) | Checksum computation during read |
| `DigestInputStream` (java.security) | Message digest computation during read |
| `CipherInputStream` (javax.crypto) | Decryption during read |
| `InflaterInputStream` / `GZIPInputStream` | Decompression during read |

`ObjectInputStream` / `ObjectOutputStream` handle Java serialization but do NOT extend `FilterInputStream` — they extend `InputStream` directly and take an `InputStream` in the constructor.

### 1.4 Why Classic java.io Was Considered Insufficient

1. **One-thread-per-connection scaling**: Every blocking `read()` or `accept()` parks an OS thread. Servers handling thousands of concurrent connections need thousands of threads, each consuming ~1MB stack space.

2. **No non-blocking mode**: The `InputStream`/`OutputStream` API has no mechanism to check readiness or register interest without blocking. `available()` is unreliable — it only reports bytes already buffered, not OS-level readiness.

3. **No scatter/gather IO**: Cannot read into multiple buffers in a single syscall (vectored IO / `readv`/`writev`).

4. **No direct memory access**: All data must transit through Java heap byte arrays. No way to use OS-level zero-copy mechanisms (e.g., `sendfile`, memory-mapped files).

5. **No file system abstraction**: `java.io.File` conflates path representation with file operations, has boolean-return error handling (no exceptions on failure), and lacks symbolic link support, file attributes, or watch services.

6. **Byte-at-a-time base API**: The abstract `read()` method returns a single byte. While bulk `read(byte[], int, int)` exists, the architecture encourages single-byte processing in naive implementations.

7. **No interruptible IO**: Blocking on a stream cannot be interrupted cleanly. `Thread.interrupt()` does not unblock a thread stuck in `FileInputStream.read()` (only `InterruptibleChannel` provides this).

---

## 2. Java NIO (`java.nio`) — JDK 1.4 (2002)

NIO introduced three core abstractions: **Buffers**, **Channels**, and **Selectors**.

### 2.1 Buffer Types

```java
public abstract class Buffer {
    // Four indices: 0 <= mark <= position <= limit <= capacity
    public final int capacity();
    public final int limit();
    public final Buffer limit(int newLimit);
    public final int position();
    public final Buffer position(int newPosition);
    public final Buffer mark();         // mark = position
    public final Buffer reset();        // position = mark
    public final Buffer clear();        // position = 0, limit = capacity (does NOT zero data)
    public final Buffer flip();         // limit = position, position = 0 (switch write->read)
    public final Buffer rewind();       // position = 0, mark discarded
    public final int remaining();       // limit - position
    public final boolean hasRemaining();
    public abstract boolean isReadOnly();
    public abstract boolean isDirect();  // off-heap native memory
}
```

Concrete buffer types (one per primitive):

| Type | Element |
|------|---------|
| `ByteBuffer` | `byte` — the fundamental IO buffer |
| `CharBuffer` | `char` (UTF-16) |
| `ShortBuffer` | `short` |
| `IntBuffer` | `int` |
| `LongBuffer` | `long` |
| `FloatBuffer` | `float` |
| `DoubleBuffer` | `double` |

#### `ByteBuffer` — Central IO Currency Type

```java
public abstract class ByteBuffer extends Buffer implements Comparable<ByteBuffer> {
    // Factory methods
    public static ByteBuffer allocate(int capacity);        // heap buffer
    public static ByteBuffer allocateDirect(int capacity);  // off-heap (native) buffer
    public static ByteBuffer wrap(byte[] array);            // wraps existing array
    public static ByteBuffer wrap(byte[] array, int offset, int length);

    // Relative get/put (advance position)
    public abstract byte get();
    public abstract ByteBuffer put(byte b);
    public ByteBuffer get(byte[] dst, int offset, int length);
    public ByteBuffer put(byte[] src, int offset, int length);
    public ByteBuffer put(ByteBuffer src);                  // bulk transfer from another buffer

    // Absolute get/put (by index, does NOT advance position)
    public abstract byte get(int index);
    public abstract ByteBuffer put(int index, byte b);

    // Typed views (reads multibyte values, respects byte order)
    public abstract char getChar();
    public abstract short getShort();
    public abstract int getInt();
    public abstract long getLong();
    public abstract float getFloat();
    public abstract double getDouble();
    // ... and absolute-index versions of each

    // Byte order
    public final ByteOrder order();
    public final ByteBuffer order(ByteOrder bo);            // BIG_ENDIAN or LITTLE_ENDIAN

    // View buffers (share underlying memory, independent position/limit/mark)
    public abstract CharBuffer asCharBuffer();
    public abstract ShortBuffer asShortBuffer();
    public abstract IntBuffer asIntBuffer();
    public abstract LongBuffer asLongBuffer();
    public abstract FloatBuffer asFloatBuffer();
    public abstract DoubleBuffer asDoubleBuffer();
    public abstract ByteBuffer asReadOnlyBuffer();

    // Slicing
    public abstract ByteBuffer slice();                     // position..limit as new buffer
    public abstract ByteBuffer slice(int index, int length);
    public abstract ByteBuffer duplicate();                 // shares data, independent cursors

    // Compaction
    public abstract ByteBuffer compact();   // copies remaining to front, position after last copied

    // Backing array access (heap buffers only)
    public final boolean hasArray();
    public final byte[] array();
    public final int arrayOffset();

    // Direct buffer address (for JNI / Panama)
    public abstract boolean isDirect();
}
```

#### Buffer State Machine: The flip/compact Protocol

The defining pattern of NIO buffers is the position/limit state machine used for alternating write and read phases:

**Writing into buffer** (filling):
- `position` advances with each `put()`
- `limit` equals `capacity`

**Switching to read mode**: `flip()`
- Sets `limit = position` (end of written data)
- Sets `position = 0` (start reading from beginning)

**Reading from buffer** (draining):
- `position` advances with each `get()`
- Stop when `position == limit`

**Preparing for more writes**: Either:
- `clear()`: position = 0, limit = capacity. Discards any unread data.
- `compact()`: Copies bytes from position..limit to 0..remaining, sets position = remaining, limit = capacity. Preserves unread data.

**mark/reset**: `mark()` saves current position; `reset()` restores it. Mark is invalidated by `flip()`, `clear()`, `rewind()`, or any operation that moves position before mark.

#### Direct vs Heap Buffers

| Aspect | Heap Buffer (`allocate`) | Direct Buffer (`allocateDirect`) |
|--------|------------------------|--------------------------------|
| Memory location | JVM heap (byte[]) | Native/off-heap memory |
| GC interaction | Subject to GC, may be moved | Not moved by GC, but GC tracks the reference |
| Array access | `hasArray() == true`, direct array access | `hasArray() == false`, no array backing |
| Allocation cost | Cheap (array allocation) | Expensive (OS memory mapping, `malloc`/`mmap`) |
| IO performance | Requires temporary direct buffer copy for OS IO | Can be passed directly to OS read/write calls |
| Recommended use | Short-lived, small buffers | Long-lived IO buffers, reused across operations |
| Deallocation | GC collects | GC collects the Java object; native memory freed by `Cleaner` (non-deterministic) or explicit `sun.misc.Unsafe` free |

The JVM internally uses direct buffers for all OS IO operations. When you pass a heap buffer to a channel, the JVM:
1. Allocates (or reuses from a thread-local cache) a temporary direct buffer
2. Copies data from heap buffer to direct buffer
3. Passes the direct buffer address to the OS syscall
4. Copies results back (for reads)

### 2.2 Channel Hierarchy

Channels are bidirectional or unidirectional conduits for IO. They separate the IO target from the buffer:

```java
public interface Channel extends Closeable {
    boolean isOpen();
    void close() throws IOException;
}

public interface ReadableByteChannel extends Channel {
    int read(ByteBuffer dst) throws IOException;    // returns bytes read, -1 at EOF
}

public interface WritableByteChannel extends Channel {
    int write(ByteBuffer src) throws IOException;   // returns bytes written
}

public interface ByteChannel extends ReadableByteChannel, WritableByteChannel {
    // combines read + write
}

public interface ScatteringByteChannel extends ReadableByteChannel {
    long read(ByteBuffer[] dsts) throws IOException;              // vectored read
    long read(ByteBuffer[] dsts, int offset, int length) throws IOException;
}

public interface GatheringByteChannel extends WritableByteChannel {
    long write(ByteBuffer[] srcs) throws IOException;             // vectored write
    long write(ByteBuffer[] srcs, int offset, int length) throws IOException;
}

public interface SeekableByteChannel extends ByteChannel {
    long position() throws IOException;
    SeekableByteChannel position(long newPosition) throws IOException;
    long size() throws IOException;
    SeekableByteChannel truncate(long size) throws IOException;
}
```

#### `FileChannel`

```java
public abstract class FileChannel extends AbstractInterruptibleChannel
    implements SeekableByteChannel, GatheringByteChannel, ScatteringByteChannel {

    // Positioned IO (does not change channel position)
    public abstract int read(ByteBuffer dst, long position) throws IOException;
    public abstract int write(ByteBuffer src, long position) throws IOException;

    // Memory mapping
    public abstract MappedByteBuffer map(MapMode mode, long position, long size) throws IOException;
    // MapMode: READ_ONLY, READ_WRITE, PRIVATE (copy-on-write)

    // Transfer (potential zero-copy via OS sendfile/splice)
    public abstract long transferTo(long position, long count, WritableByteChannel target) throws IOException;
    public abstract long transferFrom(ReadableByteChannel src, long position, long count) throws IOException;

    // File locking
    public abstract FileLock lock(long position, long size, boolean shared) throws IOException;
    public abstract FileLock tryLock(long position, long size, boolean shared) throws IOException;

    // Force to disk
    public abstract void force(boolean metaData) throws IOException;

    // Size
    public abstract long size() throws IOException;
    public abstract FileChannel truncate(long size) throws IOException;
}
```

`MappedByteBuffer` extends `ByteBuffer` with:
```java
public abstract class MappedByteBuffer extends ByteBuffer {
    public final boolean isLoaded();   // are pages in physical memory
    public final MappedByteBuffer load();  // hint to preload
    public final MappedByteBuffer force(); // flush to storage
}
```

#### `SocketChannel` / `ServerSocketChannel`

```java
public abstract class SocketChannel extends AbstractSelectableChannel
    implements ByteChannel, ScatteringByteChannel, GatheringByteChannel, NetworkChannel {

    public static SocketChannel open() throws IOException;
    public static SocketChannel open(SocketAddress remote) throws IOException;

    // Connection
    public abstract boolean connect(SocketAddress remote) throws IOException;
    public abstract boolean finishConnect() throws IOException;  // for non-blocking connect
    public abstract boolean isConnected();
    public abstract boolean isConnectionPending();

    // IO — same as ReadableByteChannel/WritableByteChannel
    public abstract int read(ByteBuffer dst) throws IOException;
    public abstract int write(ByteBuffer src) throws IOException;

    // Non-blocking mode
    public final SelectableChannel configureBlocking(boolean block) throws IOException;
    public final boolean isBlocking();
}

public abstract class ServerSocketChannel extends AbstractSelectableChannel
    implements NetworkChannel {

    public static ServerSocketChannel open() throws IOException;
    public abstract SocketChannel accept() throws IOException;   // blocks or returns null if non-blocking
    public final ServerSocketChannel bind(SocketAddress local) throws IOException;
}
```

### 2.3 Selector — Multiplexed IO

The Selector is Java's abstraction over `epoll` (Linux), `kqueue` (macOS/BSD), and `IOCP` (Windows):

```java
public abstract class Selector implements Closeable {
    public static Selector open() throws IOException;

    // Registration query
    public abstract Set<SelectionKey> keys();           // all registered keys
    public abstract Set<SelectionKey> selectedKeys();   // keys with ready operations

    // Selection (blocks until at least one channel ready, or timeout/interrupt)
    public abstract int select() throws IOException;           // blocks indefinitely
    public abstract int select(long timeout) throws IOException;
    public abstract int selectNow() throws IOException;        // non-blocking poll

    // Wake up a blocking select() from another thread
    public abstract Selector wakeup();

    public abstract void close() throws IOException;
}
```

#### Registration and SelectionKey

```java
// Register a channel with a selector
SelectionKey key = channel.register(selector, SelectionKey.OP_READ);
SelectionKey key = channel.register(selector, SelectionKey.OP_READ | SelectionKey.OP_WRITE, attachment);

public abstract class SelectionKey {
    // Interest operations (what we want to be notified about)
    public static final int OP_READ    = 1 << 0;   // channel has data to read
    public static final int OP_WRITE   = 1 << 2;   // channel can accept writes
    public static final int OP_CONNECT = 1 << 3;   // connection completed (client socket)
    public static final int OP_ACCEPT  = 1 << 4;   // incoming connection (server socket)

    public abstract int interestOps();
    public abstract SelectionKey interestOps(int ops);
    public abstract int readyOps();

    // Convenience readiness tests
    public final boolean isReadable();
    public final boolean isWritable();
    public final boolean isConnectable();
    public final boolean isAcceptable();

    // Associated channel and selector
    public abstract SelectableChannel channel();
    public abstract Selector selector();

    // Attachment — arbitrary object associated with this registration
    public final Object attach(Object ob);
    public final Object attachment();

    // Cancellation
    public abstract void cancel();
    public abstract boolean isValid();
}
```

#### The Selector Loop (Reactor Pattern)

```java
Selector selector = Selector.open();
ServerSocketChannel serverChannel = ServerSocketChannel.open();
serverChannel.bind(new InetSocketAddress(8080));
serverChannel.configureBlocking(false);
serverChannel.register(selector, SelectionKey.OP_ACCEPT);

while (true) {
    int readyCount = selector.select();   // blocks until event(s)
    if (readyCount == 0) continue;

    Set<SelectionKey> selectedKeys = selector.selectedKeys();
    Iterator<SelectionKey> it = selectedKeys.iterator();

    while (it.hasNext()) {
        SelectionKey key = it.next();
        it.remove();   // MUST remove — selector does not clear the set

        if (key.isAcceptable()) {
            SocketChannel client = serverChannel.accept();
            client.configureBlocking(false);
            client.register(selector, SelectionKey.OP_READ);
        } else if (key.isReadable()) {
            SocketChannel client = (SocketChannel) key.channel();
            ByteBuffer buffer = ByteBuffer.allocate(1024);
            int bytesRead = client.read(buffer);
            if (bytesRead == -1) {
                key.cancel();
                client.close();
            } else {
                buffer.flip();
                // process data...
            }
        }
    }
}
```

**Readiness model**: The selector reports *readiness*, not *events*. A channel that was readable and was not fully drained remains in the selected set on the next `select()` call. The application MUST remove processed keys from `selectedKeys()` — the selector only adds, never removes.

### 2.4 `Path` and `Files` — NIO.2 File System Abstraction (JDK 7, 2011)

```java
public interface Path extends Comparable<Path>, Iterable<Path>, Watchable {
    FileSystem getFileSystem();
    boolean isAbsolute();
    Path getRoot();
    Path getFileName();
    Path getParent();
    int getNameCount();
    Path getName(int index);
    Path subpath(int beginIndex, int endIndex);
    boolean startsWith(Path other);
    boolean endsWith(Path other);
    Path normalize();
    Path resolve(Path other);         // append child
    Path resolve(String other);
    Path resolveSibling(Path other);
    Path relativize(Path other);
    URI toUri();
    Path toAbsolutePath();
    Path toRealPath(LinkOption... options) throws IOException;
}

// Factory
Path p = Path.of("/usr/local/bin");
Path p = Path.of("home", "user", "file.txt");
```

`Files` is a utility class with static methods for all file operations:

```java
public final class Files {
    // Read/Write
    public static byte[] readAllBytes(Path path) throws IOException;
    public static List<String> readAllLines(Path path, Charset cs) throws IOException;
    public static Path write(Path path, byte[] bytes, OpenOption... options) throws IOException;

    // Streams (lazy)
    public static Stream<String> lines(Path path, Charset cs) throws IOException;
    public static Stream<Path> list(Path dir) throws IOException;
    public static Stream<Path> walk(Path start, int maxDepth, FileVisitOption... options) throws IOException;
    public static Stream<Path> find(Path start, int maxDepth, BiPredicate<Path, BasicFileAttributes> matcher, ...) throws IOException;

    // Channel/Stream opening
    public static InputStream newInputStream(Path path, OpenOption... options) throws IOException;
    public static OutputStream newOutputStream(Path path, OpenOption... options) throws IOException;
    public static SeekableByteChannel newByteChannel(Path path, OpenOption... options) throws IOException;
    public static BufferedReader newBufferedReader(Path path, Charset cs) throws IOException;
    public static BufferedWriter newBufferedWriter(Path path, Charset cs, OpenOption... options) throws IOException;

    // File operations
    public static Path createFile(Path path, FileAttribute<?>... attrs) throws IOException;
    public static Path createDirectory(Path dir, FileAttribute<?>... attrs) throws IOException;
    public static Path createDirectories(Path dir, FileAttribute<?>... attrs) throws IOException;
    public static Path createTempFile(Path dir, String prefix, String suffix, FileAttribute<?>... attrs) throws IOException;
    public static void delete(Path path) throws IOException;
    public static boolean deleteIfExists(Path path) throws IOException;
    public static Path copy(Path source, Path target, CopyOption... options) throws IOException;
    public static Path move(Path source, Path target, CopyOption... options) throws IOException;

    // Attributes
    public static <A extends BasicFileAttributes> A readAttributes(Path path, Class<A> type, LinkOption... options) throws IOException;
    public static boolean exists(Path path, LinkOption... options);
    public static boolean isDirectory(Path path, LinkOption... options);
    public static boolean isRegularFile(Path path, LinkOption... options);
    public static boolean isSymbolicLink(Path path);
    public static boolean isReadable(Path path);
    public static boolean isWritable(Path path);
    public static boolean isExecutable(Path path);
    public static long size(Path path) throws IOException;
    public static FileTime getLastModifiedTime(Path path, LinkOption... options) throws IOException;
    public static UserPrincipal getOwner(Path path, LinkOption... options) throws IOException;
    public static Set<PosixFilePermission> getPosixFilePermissions(Path path, LinkOption... options) throws IOException;

    // Links
    public static Path createSymbolicLink(Path link, Path target, FileAttribute<?>... attrs) throws IOException;
    public static Path createLink(Path link, Path existing) throws IOException;
    public static Path readSymbolicLink(Path link) throws IOException;

    // Watch
    // WatchService obtained from FileSystem, not Files directly
}
```

`FileSystem` and `FileSystemProvider` enable pluggable file system implementations (zip files as file systems, in-memory file systems for testing, remote file systems).

---

## 3. Java NIO.2 Asynchronous Channels (JDK 7)

### 3.1 Asynchronous Channel Types

```java
public abstract class AsynchronousSocketChannel implements AsynchronousByteChannel, NetworkChannel {
    public static AsynchronousSocketChannel open() throws IOException;
    public static AsynchronousSocketChannel open(AsynchronousChannelGroup group) throws IOException;

    // Future-based
    public abstract Future<Void> connect(SocketAddress remote);
    public abstract Future<Integer> read(ByteBuffer dst);
    public abstract Future<Integer> write(ByteBuffer src);

    // Callback-based
    public abstract <A> void connect(SocketAddress remote, A attachment, CompletionHandler<Void, ? super A> handler);
    public abstract <A> void read(ByteBuffer dst, long timeout, TimeUnit unit, A attachment, CompletionHandler<Integer, ? super A> handler);
    public abstract <A> void write(ByteBuffer src, long timeout, TimeUnit unit, A attachment, CompletionHandler<Integer, ? super A> handler);
}

public abstract class AsynchronousServerSocketChannel implements AsynchronousChannel, NetworkChannel {
    public abstract Future<AsynchronousSocketChannel> accept();
    public abstract <A> void accept(A attachment, CompletionHandler<AsynchronousSocketChannel, ? super A> handler);
}

public abstract class AsynchronousFileChannel implements AsynchronousChannel {
    public static AsynchronousFileChannel open(Path file, OpenOption... options) throws IOException;

    // All operations require explicit position (no internal position cursor)
    public abstract Future<Integer> read(ByteBuffer dst, long position);
    public abstract Future<Integer> write(ByteBuffer src, long position);
    public abstract <A> void read(ByteBuffer dst, long position, A attachment, CompletionHandler<Integer, ? super A> handler);
    public abstract <A> void write(ByteBuffer src, long position, A attachment, CompletionHandler<Integer, ? super A> handler);

    public abstract Future<FileLock> lock(long position, long size, boolean shared);
    public abstract long size() throws IOException;
    public abstract AsynchronousFileChannel truncate(long size) throws IOException;
    public abstract void force(boolean metaData) throws IOException;
}
```

### 3.2 CompletionHandler Callback Model

```java
public interface CompletionHandler<V, A> {
    void completed(V result, A attachment);   // operation succeeded
    void failed(Throwable exc, A attachment); // operation failed
}
```

The attachment parameter (`A`) enables stateful callback chains without closures. This was important before lambdas (JDK 8) made closures convenient:

```java
channel.read(buffer, connectionState, new CompletionHandler<Integer, ConnectionState>() {
    @Override
    public void completed(Integer bytesRead, ConnectionState state) {
        if (bytesRead == -1) {
            state.close();
            return;
        }
        buffer.flip();
        // process data, then read more:
        channel.read(buffer, state, this);   // re-register self
    }

    @Override
    public void failed(Throwable exc, ConnectionState state) {
        state.handleError(exc);
    }
});
```

### 3.3 Future-Based Async IO

```java
AsynchronousSocketChannel channel = AsynchronousSocketChannel.open();
Future<Void> connectFuture = channel.connect(new InetSocketAddress("example.com", 80));
connectFuture.get();  // blocks until connected

ByteBuffer buffer = ByteBuffer.allocate(1024);
Future<Integer> readFuture = channel.read(buffer);
int bytesRead = readFuture.get(30, TimeUnit.SECONDS);  // blocks with timeout
```

The `Future` model was simpler but led to thread-blocking waits (`get()`), negating much of the async benefit. It served as a stepping stone.

### 3.4 `AsynchronousChannelGroup`

Groups bind async channels to a shared thread pool for IO event processing:

```java
AsynchronousChannelGroup group = AsynchronousChannelGroup.withFixedThreadPool(
    Runtime.getRuntime().availableProcessors(),
    Executors.defaultThreadFactory()
);

AsynchronousSocketChannel channel = AsynchronousSocketChannel.open(group);
```

The group manages the lifecycle of IO threads. On Linux, the implementation typically uses `epoll` with a thread pool dispatching completions. On Windows, it maps directly to IOCP (IO Completion Ports).

---

## 4. Project Loom / Virtual Threads (JDK 21+, 2023)

### 4.1 Virtual Threads and Blocking IO

Virtual threads (JEP 444, finalized in JDK 21) are lightweight threads managed by the JVM runtime, not the OS. Key properties:

- **Extremely cheap**: ~1KB initial stack (vs ~1MB for platform threads). Millions can exist simultaneously.
- **Scheduled by the JVM**: A small pool of platform (carrier) threads runs virtual threads. When a virtual thread blocks on IO, the JVM *unmounts* it from the carrier thread and mounts another virtual thread.
- **Blocking IO becomes non-blocking under the hood**: The JVM's implementation of `java.net.Socket`, `java.io.InputStream`, etc. was rewritten to use non-blocking IO internally when running on a virtual thread. The blocking API remains unchanged, but the carrier thread is freed during the wait.

```java
// Create virtual threads — each can block on IO without consuming an OS thread
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (int i = 0; i < 100_000; i++) {
        executor.submit(() -> {
            // This uses classic blocking IO — perfectly fine on virtual threads
            try (var socket = new Socket("example.com", 80)) {
                InputStream in = socket.getInputStream();
                OutputStream out = socket.getOutputStream();
                out.write("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n".getBytes());
                byte[] response = in.readAllBytes();
                // process response
            }
            return null;
        });
    }
}
```

### 4.2 How Virtual Threads Simplify the IO Model

Before Loom, Java developers faced a choice:

| Approach | Throughput | Complexity |
|----------|-----------|------------|
| Blocking IO (`java.io`) | Limited by thread count | Simple, sequential code |
| NIO Selector | Scales to thousands of connections | Complex callback/state machine code |
| NIO.2 Async | Similar to selector | Callback nesting, hard to debug |
| Reactive (RxJava, Reactor) | High throughput | Complex operator chains, different mental model |

Virtual threads eliminate this trade-off:

- **Write blocking-style code** (simple, debuggable, familiar)
- **Get non-blocking scalability** (JVM handles the scheduling)
- **Stack traces work normally** (unlike reactive chains)
- **Exception handling works normally** (try/catch, not error callbacks)
- **Existing code benefits** (Servlet containers, JDBC, etc. scale without rewriting)

### 4.3 Impact on NIO Adoption

Virtual threads have significantly reduced the motivation for new NIO adoption:

1. **Server frameworks** (Tomcat, Jetty, Spring) are migrating to virtual threads for request handling, using blocking IO style.
2. **NIO selectors remain relevant** for cases where you need explicit control over IO event multiplexing (custom protocols, high-frequency trading, etc.).
3. **NIO buffers (`ByteBuffer`) remain relevant** as the currency type for bulk IO operations, especially memory-mapped files and direct IO.
4. **NIO.2 async channels are effectively deprecated in practice** — virtual threads with blocking channels give the same scalability with simpler code.
5. **Reactive frameworks** (Project Reactor, RxJava) are re-evaluating their positioning. The throughput argument is weakened; the composition/operator argument remains for complex stream processing.

### 4.4 Pinning and Limitations

Virtual threads can be "pinned" to their carrier thread in certain cases, preventing other virtual threads from using that carrier:

- **`synchronized` blocks** during IO: The virtual thread stays mounted while blocked inside a `synchronized` block. Mitigation: use `ReentrantLock` instead.
- **Native method frames**: JNI calls pin the virtual thread.
- **File IO on some platforms**: `FileChannel` operations may still use blocking carrier threads depending on OS support.

---

## 5. .NET System.IO

### 5.1 `Stream` — The Universal IO Abstraction

.NET's IO model centers on a single abstract base class:

```csharp
public abstract class Stream : MarshalByRefObject, IDisposable, IAsyncDisposable
{
    // Capabilities (template method pattern — subclasses declare what they support)
    public abstract bool CanRead { get; }
    public abstract bool CanWrite { get; }
    public abstract bool CanSeek { get; }
    public virtual bool CanTimeout { get; }   // false by default

    // Position and length
    public abstract long Length { get; }
    public abstract long Position { get; set; }
    public abstract void SetLength(long value);
    public abstract long Seek(long offset, SeekOrigin origin);  // Begin, Current, End

    // Synchronous read/write
    public abstract int Read(byte[] buffer, int offset, int count);     // returns bytes read, 0 at EOF
    public abstract void Write(byte[] buffer, int offset, int count);

    // Modern Span-based overloads (default implementation copies, subclasses optimize)
    public virtual int Read(Span<byte> buffer);
    public virtual void Write(ReadOnlySpan<byte> buffer);

    // Single byte
    public virtual int ReadByte();      // returns -1 at EOF
    public virtual void WriteByte(byte value);

    // Async read/write (Task-based, see Section 6)
    public virtual Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken);
    public virtual ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default);
    public virtual Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken);
    public virtual ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default);

    // Flushing
    public abstract void Flush();
    public virtual Task FlushAsync(CancellationToken cancellationToken);

    // Copy
    public void CopyTo(Stream destination);
    public void CopyTo(Stream destination, int bufferSize);
    public Task CopyToAsync(Stream destination, int bufferSize, CancellationToken cancellationToken);

    // Lifecycle
    public void Close();
    public void Dispose();              // calls Close()
    public virtual ValueTask DisposeAsync();
    protected virtual void Dispose(bool disposing);

    // Timeouts
    public virtual int ReadTimeout { get; set; }
    public virtual int WriteTimeout { get; set; }

    // Null stream
    public static readonly Stream Null;     // discards writes, returns 0 on reads
}
```

The `CanRead`/`CanWrite`/`CanSeek` properties allow runtime capability querying. Methods throw `NotSupportedException` when the operation is not supported. This is a trade-off versus having separate read/write interfaces — .NET chose a single type for simplicity at the cost of compile-time safety.

### 5.2 Concrete Stream Implementations

#### `FileStream`

```csharp
public class FileStream : Stream
{
    public FileStream(string path, FileMode mode);
    public FileStream(string path, FileMode mode, FileAccess access);
    public FileStream(string path, FileMode mode, FileAccess access, FileShare share);
    public FileStream(string path, FileMode mode, FileAccess access, FileShare share, int bufferSize);
    public FileStream(string path, FileMode mode, FileAccess access, FileShare share, int bufferSize, FileOptions options);
    // FileOptions.Asynchronous — hint for async IO optimization
    // FileOptions.SequentialScan, RandomAccess — access pattern hints
    // FileOptions.WriteThrough — bypass OS write cache

    public FileStream(SafeFileHandle handle, FileAccess access);
    public FileStream(string path, FileStreamOptions options);  // .NET 6+

    public virtual string Name { get; }
    public virtual SafeFileHandle SafeFileHandle { get; }
    public virtual void Lock(long position, long length);
    public virtual void Unlock(long position, long length);

    // Overrides CanRead, CanWrite, CanSeek to return true based on FileAccess
}
```

`FileMode` enum: `Create`, `CreateNew`, `Open`, `OpenOrCreate`, `Truncate`, `Append`
`FileAccess` enum: `Read`, `Write`, `ReadWrite`
`FileShare` enum: `None`, `Read`, `Write`, `ReadWrite`, `Delete`, `Inheritable`

#### `MemoryStream`

```csharp
public class MemoryStream : Stream
{
    public MemoryStream();                              // expandable, starts at 0 capacity
    public MemoryStream(int capacity);                  // expandable, pre-allocated
    public MemoryStream(byte[] buffer);                 // wraps existing array, non-expandable
    public MemoryStream(byte[] buffer, bool writable);  // optionally read-only
    public MemoryStream(byte[] buffer, int index, int count, bool writable, bool publiclyVisible);

    public virtual byte[] GetBuffer();     // returns internal array (only if publiclyVisible)
    public virtual bool TryGetBuffer(out ArraySegment<byte> buffer);
    public virtual byte[] ToArray();       // copies to new array
    public virtual void WriteTo(Stream stream);

    public override bool CanRead => true;
    public override bool CanWrite => !_writable_flag;
    public override bool CanSeek => true;
    // Capacity grows by doubling, like List<T>
}
```

#### `NetworkStream`

```csharp
public class NetworkStream : Stream
{
    public NetworkStream(Socket socket);
    public NetworkStream(Socket socket, bool ownsSocket);
    public NetworkStream(Socket socket, FileAccess access, bool ownsSocket);

    public override bool CanRead { get; }
    public override bool CanWrite { get; }
    public override bool CanSeek => false;  // NOT seekable
    public virtual bool DataAvailable { get; }
    public Socket Socket { get; }

    // Length and Position throw NotSupportedException
}
```

#### `BufferedStream`

```csharp
public sealed class BufferedStream : Stream
{
    public BufferedStream(Stream stream);
    public BufferedStream(Stream stream, int bufferSize);   // default 4096

    public Stream UnderlyingStream { get; }
    public int BufferSize { get; }
    // Delegates all operations to inner stream with buffering
}
```

### 5.3 Text IO: `StreamReader` and `StreamWriter`

```csharp
public class StreamReader : TextReader
{
    public StreamReader(Stream stream);
    public StreamReader(Stream stream, Encoding encoding);
    public StreamReader(Stream stream, Encoding encoding, bool detectEncodingFromByteOrderMarks, int bufferSize, bool leaveOpen);
    public StreamReader(string path);
    public StreamReader(string path, Encoding encoding);

    public virtual Encoding CurrentEncoding { get; }
    public virtual Stream BaseStream { get; }
    public bool EndOfStream { get; }

    public override int Read();                                      // single char
    public override int Read(char[] buffer, int index, int count);
    public override int Read(Span<char> buffer);
    public override string? ReadLine();
    public override string ReadToEnd();
    public override Task<string?> ReadLineAsync();
    public override Task<string> ReadToEndAsync();
    public override ValueTask<int> ReadAsync(Memory<char> buffer, CancellationToken cancellationToken = default);
}

public class StreamWriter : TextWriter
{
    public StreamWriter(Stream stream);
    public StreamWriter(Stream stream, Encoding encoding);
    public StreamWriter(string path);
    public StreamWriter(string path, bool append, Encoding encoding);

    public virtual Stream BaseStream { get; }
    public virtual bool AutoFlush { get; set; }

    public override void Write(char value);
    public override void Write(char[] buffer, int index, int count);
    public override void Write(ReadOnlySpan<char> buffer);
    public override void Write(string? value);
    public override void WriteLine(string? value);
    public override Task WriteAsync(char value);
    public override Task WriteLineAsync(string? value);
}
```

`TextReader` / `TextWriter` are the abstract base classes (analogous to Java's `Reader`/`Writer`). `StreamReader`/`StreamWriter` are the bridge between byte streams and character streams, handling encoding/decoding.

### 5.4 Binary IO: `BinaryReader` and `BinaryWriter`

```csharp
public class BinaryReader : IDisposable
{
    public BinaryReader(Stream input);
    public BinaryReader(Stream input, Encoding encoding);
    public BinaryReader(Stream input, Encoding encoding, bool leaveOpen);

    public virtual Stream BaseStream { get; }

    // Typed reads — little-endian
    public virtual bool ReadBoolean();
    public virtual byte ReadByte();
    public virtual sbyte ReadSByte();
    public virtual char ReadChar();
    public virtual short ReadInt16();
    public virtual ushort ReadUInt16();
    public virtual int ReadInt32();
    public virtual uint ReadUInt32();
    public virtual long ReadInt64();
    public virtual ulong ReadUInt64();
    public virtual Half ReadHalf();
    public virtual float ReadSingle();
    public virtual double ReadDouble();
    public virtual decimal ReadDecimal();
    public virtual string ReadString();   // length-prefixed (7-bit encoded length)
    public virtual byte[] ReadBytes(int count);
    public virtual int Read(byte[] buffer, int index, int count);
    public virtual int Read(Span<byte> buffer);
}

public class BinaryWriter : IDisposable
{
    public BinaryWriter(Stream output);
    public BinaryWriter(Stream output, Encoding encoding, bool leaveOpen);

    public virtual Stream BaseStream { get; }

    public virtual void Write(bool value);
    public virtual void Write(byte value);
    public virtual void Write(sbyte value);
    public virtual void Write(char ch);
    public virtual void Write(short value);
    public virtual void Write(ushort value);
    public virtual void Write(int value);
    public virtual void Write(uint value);
    public virtual void Write(long value);
    public virtual void Write(ulong value);
    public virtual void Write(Half value);
    public virtual void Write(float value);
    public virtual void Write(double value);
    public virtual void Write(decimal value);
    public virtual void Write(string value);   // length-prefixed
    public virtual void Write(byte[] buffer);
    public virtual void Write(byte[] buffer, int index, int count);
    public virtual void Write(ReadOnlySpan<byte> buffer);
}
```

Note the endianness difference from Java: .NET `BinaryReader`/`BinaryWriter` use **little-endian** (matching x86/x64/ARM), while Java `DataInputStream`/`DataOutputStream` use **big-endian** (network byte order). .NET provides `BinaryPrimitives` for explicit endianness control.

### 5.5 `Span<T>` and `Memory<T>` — Zero-Copy Buffer API

Added in .NET Core 2.1 (2018). These are the modern buffer currency types:

```csharp
// Stack-only, cannot be stored in fields, closures, or async state machines
public readonly ref struct Span<T>
{
    public Span(T[]? array);
    public Span(T[]? array, int start, int length);
    public unsafe Span(void* pointer, int length);          // from unmanaged memory

    public ref T this[int index] { get; }                   // indexer with ref return
    public int Length { get; }
    public bool IsEmpty { get; }
    public static Span<T> Empty { get; }

    public Span<T> Slice(int start);
    public Span<T> Slice(int start, int length);
    public T[] ToArray();
    public void CopyTo(Span<T> destination);
    public bool TryCopyTo(Span<T> destination);
    public void Fill(T value);
    public void Clear();

    // Casting (reinterpret bytes as different types)
    // Via MemoryMarshal:
    // MemoryMarshal.Cast<TFrom, TTo>(Span<TFrom> span) -> Span<TTo>
    // MemoryMarshal.AsBytes<T>(Span<T> span) -> Span<byte>

    public static implicit operator Span<T>(T[] array);
    public static implicit operator Span<T>(ArraySegment<T> segment);
    public static implicit operator ReadOnlySpan<T>(Span<T> span);
}

// Heap-safe version that CAN be stored in fields, closures, async state machines
public readonly struct Memory<T>
{
    public Memory(T[]? array);
    public Memory(T[]? array, int start, int length);

    public int Length { get; }
    public bool IsEmpty { get; }
    public static Memory<T> Empty { get; }

    public Memory<T> Slice(int start);
    public Memory<T> Slice(int start, int length);
    public Span<T> Span { get; }           // get Span for synchronous access
    public T[] ToArray();
    public void CopyTo(Memory<T> destination);
    public bool TryCopyTo(Memory<T> destination);
    public MemoryHandle Pin();             // pin for interop with unmanaged code

    public static implicit operator Memory<T>(T[] array);
    public static implicit operator Memory<T>(ArraySegment<T> segment);
    public static implicit operator ReadOnlyMemory<T>(Memory<T> memory);
}
```

**Why two types**: `Span<T>` is a `ref struct` (stack-only) for performance — it can point to stack memory, heap memory, or native memory. It cannot escape the current stack frame. `Memory<T>` is a regular struct that can be stored anywhere but can only point to heap memory (arrays or `IMemoryOwner<T>`). Async methods use `Memory<T>` because the state machine is heap-allocated.

**Relationship to streams**: The modern `Stream` API overloads accept `Span<byte>` (sync) and `Memory<byte>` (async):

```csharp
// Sync — stack-allocated buffer, zero heap allocation
Span<byte> buffer = stackalloc byte[256];
int bytesRead = stream.Read(buffer);

// Async — must use Memory<T> since state machine lives on heap
Memory<byte> buffer = new byte[256];
int bytesRead = await stream.ReadAsync(buffer);
```

**`MemoryPool<T>`** provides pooled `Memory<T>` instances to reduce GC pressure:

```csharp
public abstract class MemoryPool<T> : IDisposable
{
    public static MemoryPool<T> Shared { get; }      // default array pool-backed implementation
    public abstract int MaxBufferSize { get; }
    public abstract IMemoryOwner<T> Rent(int minBufferSize = -1);
}

public interface IMemoryOwner<T> : IDisposable
{
    Memory<T> Memory { get; }
}
```

### 5.6 `System.IO.Pipelines` — High-Performance IO

Introduced in .NET Core 2.1, designed for the Kestrel web server (ASP.NET Core). Pipelines solve fundamental problems with stream-based IO for high-throughput network servers.

#### Why Pipelines Were Created

The `Stream` model has inherent inefficiencies for server workloads:

1. **Buffer ownership ambiguity**: Who allocates the buffer? Who sizes it? If the caller allocates too small, partial reads require complex reassembly. If too large, memory is wasted.

2. **Backpressure is manual**: Nothing prevents a fast producer from overwhelming a slow consumer. The application must implement flow control manually.

3. **Buffer lifecycle mismatch**: `Stream.Read()` returns `int` (bytes read). The caller must copy the data before calling `Read()` again, because the buffer will be overwritten. No way to hold a reference to previously-read data while reading more.

4. **Parse-then-consume coupling**: When parsing a protocol (e.g., HTTP headers), you often need to examine data without consuming it, then consume variable amounts. With streams, this requires buffering and complex position tracking.

5. **Allocation pressure**: Each `ReadAsync` on `NetworkStream` allocates or rents a buffer. Under high load, this creates GC pressure.

Pipelines address all of these by separating writing (producer) from reading (consumer) with a managed buffer pool and backpressure.

#### Core Types

```csharp
public class Pipe
{
    public Pipe();
    public Pipe(PipeOptions options);

    public PipeWriter Writer { get; }
    public PipeReader Reader { get; }

    public void Reset();    // reuse after completion
}

public class PipeOptions
{
    public PipeOptions(
        MemoryPool<byte>? pool = null,
        PipeScheduler? readerScheduler = null,
        PipeScheduler? writerScheduler = null,
        long pauseWriterThreshold = -1,        // backpressure: pause writer when buffered bytes exceed this
        long resumeWriterThreshold = -1,       // backpressure: resume writer when buffered bytes drop below this
        int minimumSegmentSize = -1,           // minimum buffer segment allocation
        bool useSynchronizationContext = true
    );
}
```

#### `PipeWriter` — Producer Side

```csharp
public abstract class PipeWriter : IBufferWriter<byte>, IAsyncDisposable
{
    // Get buffer space to write into (no copy — write directly into pipe's buffer)
    public abstract Memory<byte> GetMemory(int sizeHint = 0);
    public abstract Span<byte> GetSpan(int sizeHint = 0);

    // Tell the pipe how many bytes were written
    public abstract void Advance(int bytes);

    // Make written bytes available to reader (+ apply backpressure)
    public abstract ValueTask<FlushResult> FlushAsync(CancellationToken cancellationToken = default);

    // Signal completion
    public abstract void Complete(Exception? exception = null);
    public abstract ValueTask CompleteAsync(Exception? exception = null);

    // Cancel pending flush
    public abstract void CancelPendingFlush();

    // Convenience: write from ReadOnlySpan/ReadOnlyMemory
    public virtual ValueTask<FlushResult> WriteAsync(ReadOnlyMemory<byte> source, CancellationToken cancellationToken = default);

    // Create from Stream (adapter)
    public static PipeWriter Create(Stream stream, StreamPipeWriterOptions? writerOptions = null);
}

public readonly struct FlushResult
{
    public bool IsCanceled { get; }     // CancelPendingFlush was called
    public bool IsCompleted { get; }    // reader completed (pipe closed from read side)
}
```

#### `PipeReader` — Consumer Side

```csharp
public abstract class PipeReader : IAsyncDisposable
{
    // Wait for data and get a reference to all unread bytes
    public abstract ValueTask<ReadResult> ReadAsync(CancellationToken cancellationToken = default);

    // Try to read without waiting
    public abstract bool TryRead(out ReadResult result);

    // Tell the pipe how much was consumed and examined
    public abstract void AdvanceTo(SequencePosition consumed);
    public abstract void AdvanceTo(SequencePosition consumed, SequencePosition examined);
    // consumed: data that has been fully processed (will be released/recycled)
    // examined: data that has been looked at but not consumed (pipe won't re-notify until more arrives)

    // Signal completion
    public abstract void Complete(Exception? exception = null);
    public abstract ValueTask CompleteAsync(Exception? exception = null);

    // Cancel pending read
    public abstract void CancelPendingRead();

    // Create from Stream (adapter)
    public static PipeReader Create(Stream stream, StreamPipeReaderOptions? readerOptions = null);
}

public readonly struct ReadResult
{
    public ReadOnlySequence<byte> Buffer { get; }   // the available data (possibly multi-segment)
    public bool IsCanceled { get; }
    public bool IsCompleted { get; }                // writer completed (no more data coming)
}
```

#### `ReadOnlySequence<T>` — Multi-Segment Buffer

The key innovation. Data in the pipe is stored as a linked list of buffer segments. `ReadOnlySequence<T>` represents a view over one or more segments without copying:

```csharp
public readonly struct ReadOnlySequence<T>
{
    public ReadOnlySequence(T[] array);
    public ReadOnlySequence(T[] array, int start, int length);
    public ReadOnlySequence(ReadOnlyMemory<T> memory);

    public long Length { get; }
    public bool IsEmpty { get; }
    public bool IsSingleSegment { get; }         // fast path: can get single Span

    public ReadOnlyMemory<T> First { get; }      // first segment
    public ReadOnlySpan<T> FirstSpan { get; }

    public SequencePosition Start { get; }
    public SequencePosition End { get; }

    public ReadOnlySequence<T> Slice(long start);
    public ReadOnlySequence<T> Slice(long start, long length);
    public ReadOnlySequence<T> Slice(SequencePosition start);
    public ReadOnlySequence<T> Slice(SequencePosition start, SequencePosition end);

    public SequencePosition GetPosition(long offset);
    public SequencePosition GetPosition(long offset, SequencePosition origin);
    public long GetOffset(SequencePosition position);

    // Enumerate segments
    public Enumerator GetEnumerator();
    // Each segment: ReadOnlyMemory<T>
}
```

#### Pipeline Usage Pattern

```csharp
var pipe = new Pipe();

// Producer task: read from socket into pipe
async Task FillPipeAsync(Socket socket, PipeWriter writer)
{
    while (true)
    {
        Memory<byte> memory = writer.GetMemory(512);  // get buffer from pool
        int bytesRead = await socket.ReceiveAsync(memory, SocketFlags.None);
        if (bytesRead == 0) break;

        writer.Advance(bytesRead);                     // tell pipe how much was written
        FlushResult result = await writer.FlushAsync(); // make available to reader + backpressure
        if (result.IsCompleted) break;                 // reader is done
    }
    await writer.CompleteAsync();
}

// Consumer task: parse data from pipe
async Task ReadPipeAsync(PipeReader reader)
{
    while (true)
    {
        ReadResult result = await reader.ReadAsync();
        ReadOnlySequence<byte> buffer = result.Buffer;

        // Try to parse a complete message
        while (TryParseMessage(ref buffer, out Message message))
        {
            ProcessMessage(message);
        }

        // Tell the pipe what we consumed and what we examined
        reader.AdvanceTo(buffer.Start, buffer.End);
        // buffer.Start = consumed position (data before this is recycled)
        // buffer.End = examined position (don't wake me until new data beyond this)

        if (result.IsCompleted) break;
    }
    await reader.CompleteAsync();
}
```

#### Why Pipelines Avoid Copies and Allocations

1. **Pool-backed segments**: Buffer memory comes from `MemoryPool<byte>` (backed by `ArrayPool<byte>`). Segments are rented and returned, not allocated and GC'd.

2. **Writer writes directly into pipe buffer**: `GetMemory()`/`GetSpan()` returns a reference to the pipe's internal buffer. No intermediate buffer needed.

3. **Reader gets a view, not a copy**: `ReadResult.Buffer` is a `ReadOnlySequence<byte>` that references the pipe's internal segments. No copy occurs until the consumer calls `AdvanceTo()`.

4. **Examined vs consumed distinction**: The consumer can examine data (look at it for parsing) without consuming it. The pipe retains the data and only recycles segments that have been consumed. This eliminates the need for the consumer to maintain its own buffer of partially-parsed data.

5. **Backpressure is built in**: `FlushAsync()` awaits when the pipe exceeds `PauseWriterThreshold`, preventing unbounded buffering.

---

## 6. Async IO in .NET

### 6.1 Evolution of Async Patterns

.NET has gone through three generations of async IO patterns:

#### APM (Asynchronous Programming Model) — .NET 1.0

```csharp
// Begin/End pattern
IAsyncResult ar = stream.BeginRead(buffer, 0, buffer.Length, callback, state);
// ...
int bytesRead = stream.EndRead(ar);
```

Callback-based, similar to Java NIO.2's `CompletionHandler`. Error-prone: must call `EndXxx` exactly once, complex callback nesting.

#### EAP (Event-based Asynchronous Pattern) — .NET 2.0

```csharp
webClient.DownloadStringCompleted += (sender, e) => { /* handle result */ };
webClient.DownloadStringAsync(uri);
```

Event-driven. Slightly simpler but limited composability.

#### TAP (Task-based Asynchronous Pattern) — .NET 4.0 / C# 5.0 (async/await)

```csharp
int bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, cancellationToken);
await stream.WriteAsync(data, 0, data.Length, cancellationToken);
```

This is the current standard. All new async APIs use TAP.

### 6.2 `Stream` Async API Surface

```csharp
// Array-based (original TAP overloads, .NET 4.5)
public virtual Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken);
public virtual Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken);

// Memory-based (modern overloads, .NET Core 2.1+)
public virtual ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default);
public virtual ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default);

public virtual Task FlushAsync(CancellationToken cancellationToken);
public virtual Task CopyToAsync(Stream destination, int bufferSize, CancellationToken cancellationToken);
```

Key differences between `Task<T>` and `ValueTask<T>`:

| Aspect | `Task<T>` | `ValueTask<T>` |
|--------|----------|----------------|
| Allocation | Always heap-allocated | Stack-allocated when result is available synchronously |
| Await multiple times | Yes | No — can only be awaited once |
| Use case | General-purpose | Hot-path IO where synchronous completion is common |

`ValueTask<int>` is used for the `Memory<byte>` overloads because buffered reads often complete synchronously (data already in buffer), avoiding a heap allocation per call.

### 6.3 `IAsyncEnumerable<T>` for Streaming

```csharp
public interface IAsyncEnumerable<out T>
{
    IAsyncEnumerator<T> GetAsyncEnumerator(CancellationToken cancellationToken = default);
}

public interface IAsyncEnumerator<out T> : IAsyncDisposable
{
    T Current { get; }
    ValueTask<bool> MoveNextAsync();
}
```

Usage with IO:

```csharp
// Read lines asynchronously
await foreach (string line in ReadLinesAsync(stream))
{
    ProcessLine(line);
}

async IAsyncEnumerable<string> ReadLinesAsync(Stream stream,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    using var reader = new StreamReader(stream);
    string? line;
    while ((line = await reader.ReadLineAsync(ct)) != null)
    {
        yield return line;
    }
}
```

`IAsyncEnumerable<T>` composes with LINQ (via `System.Linq.Async`):

```csharp
await foreach (var batch in ReadLinesAsync(stream)
    .Where(line => !string.IsNullOrEmpty(line))
    .Buffer(100)        // batch 100 items
    .WithCancellation(ct))
{
    await ProcessBatchAsync(batch);
}
```

### 6.4 IOCP Integration on Windows

.NET's async IO on Windows is built on **IO Completion Ports (IOCP)**, the OS-level async IO mechanism:

1. When a `FileStream` is opened with `FileOptions.Asynchronous`, the file handle is bound to the .NET thread pool's IOCP.

2. `ReadAsync()`/`WriteAsync()` issue overlapped IO operations to the OS. The calling thread is freed immediately.

3. When the OS completes the IO operation, it posts a completion packet to the IOCP.

4. A .NET thread pool IO thread dequeues the completion and resumes the `async` method's continuation.

This means `await stream.ReadAsync(...)` on Windows:
- Does NOT block any thread during the IO wait
- Uses OS-level async IO (not thread pool simulation)
- The completion runs on a thread pool thread

On Linux (.NET on Linux/macOS), the runtime uses `epoll`/`kqueue` similarly, with the socket layer using non-blocking IO and the managed thread pool handling completions.

For `FileStream` on Linux, true async file IO is more nuanced — Linux historically lacked good async file IO (before `io_uring`). .NET may use thread pool threads for file IO on Linux. .NET 6+ has experimental `io_uring` support.

---

## 7. Key Design Patterns — Comparative Analysis

### 7.1 Stream as Universal Abstraction (.NET) vs Channel/Buffer Split (Java)

**.NET approach**: One abstract class (`Stream`) serves as the universal IO currency type. Everything is a stream — files, network sockets, memory, compression, encryption, HTTP responses. Operations are methods on the stream: `Read`, `Write`, `Seek`, `Flush`. Capabilities are runtime-queryable (`CanRead`, `CanWrite`, `CanSeek`).

**Advantages**:
- Single type to learn. Any method accepting `Stream` works with any IO source.
- Decorators (BufferedStream, CryptoStream, GZipStream) have the same type as their inner stream.
- `CopyTo(Stream)` works generically.

**Disadvantages**:
- Runtime capability checking (`CanSeek`, `CanRead`) instead of compile-time guarantees.
- Calling `Seek` on a `NetworkStream` throws `NotSupportedException` — discovered at runtime.
- All streams carry the full API surface even when most of it is inapplicable.

**Java approach**: IO is decomposed into separate abstractions:
- `Channel` — the IO endpoint (what you read from / write to)
- `Buffer` (`ByteBuffer`) — the data container (what you read into / write from)
- `Selector` — the multiplexer (how you wait for readiness)

**Advantages**:
- Separation of concerns: buffer management is explicit and separate from IO operations.
- Interface hierarchy provides compile-time type safety: `ReadableByteChannel` vs `WritableByteChannel` vs `SeekableByteChannel`.
- Direct buffers enable zero-copy OS IO without going through Stream abstraction.

**Disadvantages**:
- More complex: must understand buffers, their state machine (position/limit/flip/compact), AND channels.
- `ByteBuffer` flip/compact protocol is a notorious source of bugs.
- No universal type like `Stream` — harder to write generic IO utilities.

### 7.2 Decorator Pattern

Both ecosystems use the decorator pattern extensively, but with different mechanics:

**Java**: Uses constructor wrapping. Each decorator is a separate class:
```java
new BufferedInputStream(new GZIPInputStream(new FileInputStream("data.gz")))
```
The decorator chain is explicit in the type: `BufferedInputStream` wraps `InputStream`.

**.NET**: Same pattern, but everything stays as `Stream`:
```csharp
new BufferedStream(new GZipStream(new FileStream("data.gz", FileMode.Open), CompressionMode.Decompress))
```
The chain is the same pattern but the outer type is always `Stream` (or a subclass).

**.NET extension**: `System.IO.Pipelines` breaks from the decorator pattern entirely. Instead of wrapping streams, it provides a producer-consumer pipe with explicit buffer management. This is a recognition that the decorator pattern, while elegant, has performance costs (virtual dispatch per byte/buffer, buffer copies between layers).

### 7.3 Buffer Management Comparison

| Aspect | Java `ByteBuffer` | .NET `Span<T>` / `Memory<T>` |
|--------|-------------------|-------------------------------|
| Position tracking | Internal cursor (position/limit) | No internal state — just pointer + length |
| Mutability | Mutable position, mutable data (unless read-only) | `Span<T>` is mutable; `ReadOnlySpan<T>` is read-only |
| Stack allocation | Not possible (always heap or native) | `Span<T>` can wrap `stackalloc` memory |
| Async compatibility | Can be used in async (it is a heap object) | `Span<T>` cannot (ref struct); `Memory<T>` can |
| Slicing | `slice()` creates new buffer sharing same memory | `Slice()` creates new span/memory, same semantics |
| Multi-segment | Not supported (single contiguous region) | `ReadOnlySequence<T>` represents discontiguous segments |
| Typed access | `getInt()`, `getLong()` etc. with configurable byte order | `BinaryPrimitives.ReadInt32LittleEndian(span)` — static methods |
| Pooling | No built-in pool (frameworks like Netty add this) | `ArrayPool<T>`, `MemoryPool<T>` built into runtime |
| Native interop | Direct buffers via `allocateDirect()` | `Span<T>` from native pointer; `Memory<T>` via `MemoryManager<T>` |
| Casting/reinterpret | View buffers (`asIntBuffer()` etc.) | `MemoryMarshal.Cast<TFrom, TTo>()` |

### 7.4 Evolution from Callbacks to Async/Await to Virtual Threads

The IO programming model evolution in both ecosystems follows a similar arc:

**Stage 1 — Synchronous blocking** (Java `java.io`, .NET `Stream` sync methods):
- Simple, sequential code.
- One thread per IO operation.
- Does not scale to many concurrent connections.

**Stage 2 — Readiness-based multiplexing** (Java NIO `Selector`):
- Single thread handles many connections.
- Complex state machine code.
- Java-specific; .NET skipped this stage for user-facing API (used IOCP internally from the start).

**Stage 3 — Callback-based async** (Java NIO.2 `CompletionHandler`, .NET APM `BeginRead`/`EndRead`):
- Non-blocking, scalable.
- Callback hell, hard to read and debug.
- Error handling is complex (must check in callback).

**Stage 4 — Language-level async/await** (.NET C# 5.0 `async`/`await`, 2012):
- Writes like synchronous code.
- Compiler generates state machine.
- Scales like callbacks.
- .NET arrived here first; Java did not get equivalent language support.

**Stage 5 — Virtual threads** (Java Loom, JDK 21, 2023):
- Write actual blocking code (not compiler-transformed).
- JVM runtime handles the scheduling.
- Even simpler than async/await: no colored function problem, no special syntax.
- Stack traces, debugging, and profiling work normally.
- .NET has not adopted this model — its async/await is deeply embedded in the ecosystem.

**Key divergence**: .NET invested heavily in async/await at the language level and built Pipelines for maximum zero-copy performance. Java invested in virtual threads to make blocking code performant. These represent fundamentally different philosophies:

- .NET: "Make async IO ergonomic at the language level, then optimize the buffer path."
- Java (Loom): "Make blocking IO performant at the runtime level, eliminating the need for async complexity."

Both achieve high concurrency, but with different trade-offs in code complexity, runtime sophistication, and zero-copy capability.

### 7.5 Summary of Approaches

| Concern | Java | .NET |
|---------|------|------|
| **IO abstraction** | `Channel` interfaces (compile-time capability) | `Stream` abstract class (runtime capability) |
| **Buffer type** | `ByteBuffer` (position/limit state machine) | `Span<T>` / `Memory<T>` (stateless view) |
| **Multi-segment buffer** | None built-in | `ReadOnlySequence<T>` (Pipelines) |
| **High-perf IO** | Netty (3rd party framework) | `System.IO.Pipelines` (1st party) |
| **Async model** | `CompletionHandler` / `Future` (NIO.2) | `async`/`await` with `Task`/`ValueTask` |
| **Scaling strategy** | Virtual threads (Loom) | Thread pool + IOCP + async/await |
| **Multiplexing** | `Selector` (epoll/kqueue/IOCP) | Internal to runtime (IOCP/epoll) |
| **Text IO** | `Reader`/`Writer` hierarchy | `StreamReader`/`StreamWriter` over `Stream` |
| **Binary IO** | `DataInputStream`/`DataOutputStream` (big-endian) | `BinaryReader`/`BinaryWriter` (little-endian) |
| **File system** | `Path` + `Files` (NIO.2) | `FileInfo`/`DirectoryInfo` + `File`/`Directory` |
| **Zero-copy file transfer** | `FileChannel.transferTo()` | `SendFile` (in Kestrel), not in base `Stream` |
| **Memory-mapped IO** | `FileChannel.map()` -> `MappedByteBuffer` | `MemoryMappedFile` (separate class, not `Stream`) |
| **Buffer pooling** | Manual or Netty `PooledByteBufAllocator` | `ArrayPool<T>`, `MemoryPool<T>` (built-in) |
| **Backpressure** | Manual (or reactive frameworks) | `Pipe` pause/resume thresholds |
| **Decorator pattern** | `FilterInputStream` -> subclasses | `Stream` wrapping `Stream` |
| **Endianness** | Big-endian default (network order) | Little-endian default (native order) |

---

## Zig and OCaml IO Ecosystems


---

## Part 1: Zig

### 1. std.io — Reader and Writer Interfaces

#### Historical Design (pre-0.15): GenericReader / GenericWriter

Zig's IO system evolved through two major eras. The pre-0.15 design centered on `GenericReader` and `GenericWriter` — comptime-parameterized types that achieved zero-overhead IO through monomorphization.

**GenericWriter** accepted three comptime parameters:

```zig
pub fn GenericWriter(
    comptime Context: type,
    comptime WriteError: type,
    comptime writeFn: fn (context: Context, bytes: []const u8) WriteError!usize,
) type
```

This generated a specialized type per concrete implementation. Each `ArrayList(u8)`, `File`, or `Stream` produced its own distinct writer type carrying the exact error set. The caller never paid for vtable indirection — all calls resolved at compile time.

**GenericReader** mirrored this structure:

```zig
pub fn GenericReader(
    comptime Context: type,
    comptime ReadError: type,
    comptime readFn: fn (context: Context, buffer: []u8) ReadError!usize,
) type
```

**Problem**: These generic types were "infectious." Any function accepting a reader/writer had to use `anytype` parameters, which prevented storing readers/writers in struct fields, bloated binaries through per-type instantiation, and made documentation opaque (the required interface was implicit, not declared).

#### AnyReader / AnyWriter — Type-Erased Variants

To enable runtime polymorphism (storing readers/writers in structs, passing through non-generic interfaces), Zig provided type-erased wrappers:

```zig
// AnyWriter erases context and error types behind function pointers
pub const AnyWriter = struct {
    context: *const anyopaque,
    writeFn: *const fn (context: *const anyopaque, bytes: []const u8) anyerror!usize,
};
```

**Critical limitation**: `AnyWriter` used `anyerror` as its error type — the union of *all* errors in the entire program. This destroyed error type precision. A function receiving `AnyWriter` could not distinguish between a disk-full error and an unrelated parse error. For reliability-critical paths (WAL persistence, TLS handshakes), this was architecturally unacceptable.

**Conversion path**: `GenericWriter` provided an `.any()` method to produce an `AnyWriter`, enabling the practical workflow: obtain a `GenericWriter` from a concrete type, pass it to `anytype` functions for zero-cost paths, convert to `AnyWriter` when struct storage was needed.

#### New Design (0.15.1+): std.Io.Reader / std.Io.Writer

Zig 0.15.1 introduced a ground-up rewrite. The new `std.Io.Writer` is a **concrete, non-generic struct** with integrated buffering:

```zig
pub const Writer = struct {
    vtable: *const VTable,
    buffer: []u8,
    end: usize,  // current buffered data position
};
```

**VTable** contains four function pointers:

| Function | Required | Purpose |
|----------|----------|---------|
| `drain` | Yes | Performs actual write via vectored IO |
| `sendFile` | No | Direct fd-to-fd transfer (OS-level zero-copy) |
| `flush` | No | Writes remaining buffered data; defaults to repeated drain |
| `rebase` | No | Manages buffer capacity and data preservation |

The `drain` signature is notably powerful:

```zig
fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize
```

- `data`: Multiple memory regions for vectored IO (writev-style)
- `splat`: Repetition count for the final slice — enables logical memset through an entire pipeline without copying, converting O(M*N) to O(M)

**Key architectural differences from GenericWriter**:

1. **Buffer is in the interface, not the implementation.** Most writes populate the buffer directly without vtable dispatch. The vtable is only invoked on buffer flush. This gives the optimizer a concrete hot path.

2. **Concrete type replaces generic instantiations.** Functions accept `*std.Io.Writer` directly — no `anytype` infection, no monomorphization bloat.

3. **`@fieldParentPtr` replaces type erasure.** Implementations embed the `Io.Writer` as a struct field. VTable functions recover the parent struct via `@fieldParentPtr`, reversing traditional type erasure.

4. **Peek functionality** built into the reader interface, providing buffer-aware convenience.

5. **File sending** propagates through the entire reader/writer graph — if both endpoints are files, the OS can perform zero-copy transfer.

**Reader** follows the same pattern with analogous structure.

#### BufferedReader / BufferedWriter (Historical)

In the pre-0.15 design, buffering was a separate wrapper layer:

```zig
var buffered = std.io.bufferedWriter(file.writer());
// buffered.writer() returned a GenericWriter that batched writes
// buffered.flush() committed buffered data
```

`BufferedReader` wrapped any reader, adding an internal buffer to batch `read()` syscalls. The only API difference from an unbuffered reader: no explicit `flush()` needed.

In 0.15.1+, **BufferedReader and BufferedWriter were deleted.** Buffering is now part of the interface itself — you pass a buffer at construction time:

```zig
var buffer: [4096]u8 = undefined;
var writer = file.writer(io, &buffer);   // buffered
var writer = file.writer(io, &.{});      // unbuffered (empty slice)
```

#### FixedBufferStream — In-Memory IO

`FixedBufferStream` wraps a `[]u8` or `[]const u8` to provide reader/writer interfaces over in-memory data:

```zig
var fbs = std.io.fixedBufferStream(my_slice);
const reader = fbs.reader();  // reads from the slice
const writer = fbs.writer();  // writes into the slice
```

Primary use case: testing functions that accept readers/writers without actual file IO, and building data in memory.

---

### 2. std.fs — File System

#### File Type

`File` is a thin wrapper around an OS file handle:

```zig
pub const Handle = std.os.fd_t;  // platform-specific: int on POSIX, HANDLE on Windows
handle: Handle,
```

**Standard streams** are file instances:
```zig
pub fn stdout() File
pub fn stderr() File
pub fn stdin() File
```

**Read operations**:

| Method | Signature | Semantics |
|--------|-----------|-----------|
| `read` | `([]u8) ReadError!usize` | Read up to buffer.len bytes |
| `pread` | `([]u8, u64) PReadError!usize` | Positional read at offset |
| `preadAll` | `([]u8, u64) PReadError!usize` | Positional read, retry until full |
| `readv` | `([]iovec) ReadError!usize` | Vectored (scatter) read |
| `reader` | `(io, []u8) Reader` | Buffered reader interface (0.15.1+) |

**Write operations**:

| Method | Signature | Semantics |
|--------|-----------|-----------|
| `write` | `([]const u8) WriteError!usize` | Write up to bytes.len |
| `writeAll` | `([]const u8) WriteError!void` | Retry until all written |
| `pwrite` | `([]const u8, u64) PWriteError!usize` | Positional write |
| `writev` | `([]iovec_const) WriteError!usize` | Vectored (gather) write |
| `writer` | `([]u8) Writer` | Buffered writer interface (0.15.1+) |
| `copyRange` | `(File, u64, File, u64, u64) CopyRangeError!u64` | Direct fd-to-fd copy |

**Seeking**: `seekBy(i64)`, `seekTo(u64)`, `seekFromEnd(i64)`, `getPos()`, `getEndPos()`, `setEndPos(u64)`

**Metadata**: `stat()`, `mode()`, `chmod()`, `chown()`, `setPermissions()`, `updateTimes()`

**Terminal support**: `isTty()`, `supportsAnsiEscapeCodes()`

**Locking**: `lock()`, `unlock()`, `tryLock()`, `downgradeLock()`

**Sync**: `sync()` — fsync equivalent

Each error category is a distinct error set: `ReadError`, `WriteError`, `PReadError`, `SeekError`, `StatError`, etc. These compose precisely via Zig's error union system.

#### Dir Type

`Dir` wraps an OS directory handle (fd on POSIX, HANDLE on Windows). The current working directory is accessed via `Dir.cwd()` (internally `posix.AT.FDCWD`).

**File operations on Dir**:
```zig
pub fn openFile(self: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File
pub fn createFile(self: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File
pub fn deleteFile(self: Dir, sub_path: []const u8) DeleteFileError!void
```

**Directory operations**:
```zig
pub fn openDir(self: Dir, sub_path: []const u8, flags: OpenDirOptions) OpenError!Dir
pub fn makeDir(self: Dir, sub_path: []const u8) MakeDirError!void
pub fn deleteDir(self: Dir, sub_path: []const u8) DeleteDirError!void
pub fn deleteTree(self: Dir, sub_path: []const u8) DeleteTreeError!void
```

**Iteration** requires `.iterate = true` at open time:
```zig
var dir = try fs.cwd().openDir("path", .{ .iterate = true });
var it = dir.iterate();
while (try it.next()) |entry| {
    // entry.name, entry.kind
}
```

**Recursive walking**:
```zig
var walker = try dir.walk(allocator);
while (try walker.next()) |entry| {
    // entry.path, entry.kind, entry.basename
}
```

**Key design**: Dir operations use *relative paths from the Dir handle* (openat-style), not global paths. This enables sandboxed filesystem access — a directory handle constrains the accessible subtree. The `fs` module also provides absolute-path convenience functions (`openFileAbsolute`, `makeDirAbsolute`, etc.) that are thin wrappers.

---

### 3. std.net — Networking

#### Address Type

`std.net.Address` represents a socket address (IPv4/IPv6/Unix domain):

```zig
Address.parseIp4("127.0.0.1", 8080)  // -> Address
Address.parseIp6("::1", 8080)        // -> Address
```

#### Server Type

The pre-0.15 API used `StreamServer`:
```zig
var server = std.net.StreamServer.init(.{
    .reuse_address = true,
});
server.listen(address);
const conn = try server.accept();  // -> Connection
```

The post-0.15 API uses `std.net.Server` (or `std.Io.net.Server`):
```zig
const server = try address.listen(.{ .kernel_backlog = 128 });
const conn = try server.accept(io);  // Connection exposes a Stream
```

#### Stream Type

`std.net.Stream` wraps a connected socket fd, providing `read()` and `writeAll()` methods. It is deliberately thin — as documented, "there's no way to set a timeout on a std.net.Stream." For production networking, many Zig developers drop to `posix.socket()`, `posix.setsockopt()`, etc. directly, citing the higher-level API as "incomplete."

**Timeout control** at the POSIX level:
```zig
posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &timeout);
```

#### Integration with new IO

In 0.15.1+, networking integrates with the `Io` interface: `std.Io.net.IpAddress2` provides `listen()`, returning an `std.Io.net.Server` that accepts through the IO backend, enabling transparent async when the `Io` implementation supports it.

---

### 4. Async IO

#### History

Zig had async/await keywords in early versions (pre-0.11) but they were removed because they "never felt finished." The old async was tightly coupled to a specific event loop implementation and could not be separated from the language runtime.

#### New Design (0.15.1 / 0.16+)

The replacement is the **`Io` interface** — a runtime-polymorphic handle (similar to `Allocator`) that all IO operations pass through:

```zig
// Setup in main()
var threaded: std.Io.Threaded = .init(allocator, .{});
const io = threaded.io();

// Pass io to all functions
try saveFile(io, data, "file.txt");
```

**Available implementations**:

| Implementation | Mechanism |
|----------------|-----------|
| Blocking IO | Traditional synchronous syscalls, zero overhead |
| Thread Pool | Parallelizes blocking syscalls across OS threads |
| Green Threads | io_uring (Linux) with kernel-space multiplexing |
| Stackless Coroutines | Future; requires special calling conventions, targets WASM |

**Asynchrony vs concurrency** — the design distinguishes sharply:

```zig
// Sequential (no concurrency expressed):
try saveFile(io, data, "fileA.txt");
try saveFile(io, data, "fileB.txt");

// Concurrent (operations expressed as independent):
var a = io.async(saveFile, .{ io, data, "fileA.txt" });
var b = io.async(saveFile, .{ io, data, "fileB.txt" });
try a.await(io);
try b.await(io);
```

Both versions are correct regardless of the `Io` implementation. The concurrent version *may* execute in parallel (with thread pool or io_uring) but *must* execute correctly even if blocking.

**Cancellation**: `future.cancel(io)` is idempotent with respect to `await()`. Resource-safe cleanup:
```zig
defer if (task.cancel(io)) |result| gpa.free(result) else |_| {};
```

**Function coloring solved**: Libraries are "colorblind" — they work identically in sync and async contexts. The `Io` interface uses virtual dispatch, but the compiler de-virtualizes when only one implementation exists (even in debug builds). Buffering at the interface level minimizes vtable call frequency.

#### io_uring Integration

Proof-of-concept implementations exist using io_uring combined with stackful coroutines. The design allows the kernel to batch and reorder IO operations through the submission/completion ring buffer pattern. Full integration requires language-level enhancements for coroutine support that are still in development.

---

### 5. Error Handling

#### Error Sets

Zig errors are values, not exceptions. An error set is a named collection of error values:

```zig
const FileError = error{
    NotFound,
    PermissionDenied,
    InvalidPath,
};
```

#### Error Unions

The `!` operator combines an error set with a return type:

```zig
fn read(buffer: []u8) ReadError!usize     // typed error union
fn parse(input: []const u8) !Document      // inferred error set
```

When the error set is omitted (just `!T`), the compiler **infers** the complete error set from all possible error returns in the function body and its callees. This is comptime error set inference.

#### Error Set Composition

Error sets compose via `||`:

```zig
const ProcessError = error{Timeout} || std.fs.File.OpenError || std.fs.File.ReadError;
```

#### IO Error Patterns

Each IO operation declares its specific error set:

| Operation | Error Set |
|-----------|-----------|
| `File.read` | `ReadError` (= POSIX read errors) |
| `File.write` | `WriteError` (= POSIX write errors) |
| `File.pread` | `PReadError` (= ReadError + seek errors) |
| `Dir.openFile` | `File.OpenError` |
| `Dir.makeDir` | `MakeDirError` |

**EOF signal**: `error.EndOfStream` — returned when a read operation reaches end-of-file. This is an error value, not a special return code. Functions that read until EOF use `readAllAlloc` or similar, which internally handle `EndOfStream`.

**Error traces**: Zig maintains error return traces (analogous to stack traces but for error propagation chains) with zero runtime overhead when not used. In debug builds, these trace the exact path an error took through the call stack.

**`try` keyword**: Sugar for "unwrap or return the error":
```zig
const n = try file.read(buffer);
// equivalent to:
const n = file.read(buffer) catch |err| return err;
```

**`catch` keyword**: Enables pattern matching on specific errors:
```zig
file.read(buffer) catch |err| switch (err) {
    error.EndOfStream => break,
    error.ConnectionReset => return reconnect(),
    else => return err,
};
```

---

### 6. Key Design Patterns

#### Comptime Generics Instead of Runtime Polymorphism

Zig's primary generic mechanism is comptime type parameters — duck-typed templates resolved at compile time. For IO, this historically meant `anytype` parameters:

```zig
pub fn format(writer: anytype, fmt: []const u8, args: anytype) !void
```

Each call site monomorphizes a specialized copy. Zero vtable overhead, but O(N) binary growth per distinct type.

The new `std.Io.Writer` provides a third path: a concrete struct with embedded vtable that the optimizer can de-virtualize. This gives the ergonomics of a single type with near-zero overhead in practice.

#### Explicit Allocator Passing

Every function that allocates memory accepts an `Allocator` parameter:

```zig
pub fn readAllAlloc(self: File, allocator: Allocator, max_size: usize) ![]u8
```

No global allocator, no hidden allocations. This makes memory budgets visible, OOM handling a normal code path, and enables per-subsystem allocation strategies (arena, fixed-buffer, page, etc.).

The new `Io` interface follows the same pattern — passed explicitly, never global.

#### No Hidden Allocations

The standard library guarantees: if a function does not accept an `Allocator` parameter, it does not allocate heap memory. This is a cultural invariant, not a compiler check, but it is rigorously maintained in std.

#### Zero-Cost IO Differently from Rust

Rust achieves zero-cost IO through trait monomorphization (`impl Read`, `impl Write`), with `dyn Read`/`dyn Write` as the type-erased (vtable) fallback.

Zig historically used the same split (comptime generics = monomorphized, `AnyReader`/`AnyWriter` = vtable). The 0.15.1+ redesign is distinctive: a single concrete type with embedded buffer where *most operations never touch the vtable at all*. The buffer provides a concrete hot path; only buffer flushes dispatch through the vtable. This is neither pure monomorphization nor pure virtual dispatch — it is a buffered-concrete-with-vtable-flush hybrid.

---

## Part 2: OCaml

### 7. Traditional OCaml IO

#### in_channel / out_channel

OCaml's classic IO model uses two abstract types:

```ocaml
type in_channel    (* input channel *)
type out_channel   (* output channel *)
```

The type system statically prevents mixing input and output at compile time.

**Standard channels** (pre-opened):
```ocaml
val stdin : in_channel
val stdout : out_channel
val stderr : out_channel
```

**Opening files**:
```ocaml
val open_in : string -> in_channel
val open_out : string -> out_channel
val open_in_gen : open_flag list -> int -> string -> in_channel
val open_out_gen : open_flag list -> int -> string -> out_channel
```

`open_out` truncates existing files; `open_out_gen` with appropriate flags provides append, exclusive create, etc.

**Output functions**:

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `output_char` | `out_channel -> char -> unit` | Write single character |
| `output_string` | `out_channel -> string -> unit` | Write string |
| `output` | `out_channel -> bytes -> int -> int -> unit` | Write substring |
| `print_string` | `string -> unit` | Write to stdout |
| `print_endline` | `string -> unit` | Write to stdout + newline |
| `Printf.fprintf` | `out_channel -> format -> ... -> unit` | Formatted output |

**Input functions**:

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `input_char` | `in_channel -> char` | Read single character |
| `input_line` | `in_channel -> string` | Read until newline (strips it) |
| `input` | `in_channel -> bytes -> int -> int -> int` | Read substring |
| `read_line` | `unit -> string` | Read from stdin |

**EOF**: `input_line` and similar raise `End_of_file` exception when the stream ends.

**Buffering**: All channels are buffered by default. `flush : out_channel -> unit` forces write-out. `set_buffered : out_channel -> bool -> unit` toggles buffering (OCaml 4.x+).

**Closing**: `close_in : in_channel -> unit` and `close_out : out_channel -> unit`.

#### Unix Module — POSIX IO

The `Unix` module provides raw POSIX access alongside the buffered channel system:

```ocaml
type file_descr  (* abstract file descriptor *)

val stdin : file_descr
val stdout : file_descr
val stderr : file_descr

val openfile : string -> open_flag list -> file_perm -> file_descr
val close : file_descr -> unit
val read : file_descr -> bytes -> int -> int -> int
val write : file_descr -> bytes -> int -> int -> int
val lseek : file_descr -> int -> seek_command -> int
val fstat : file_descr -> stats
```

**Channel-descriptor bridge**:
```ocaml
val in_channel_of_descr : file_descr -> in_channel
val out_channel_of_descr : file_descr -> out_channel
val descr_of_in_channel : in_channel -> file_descr
val descr_of_out_channel : out_channel -> file_descr
```

**Socket operations**:
```ocaml
val socket : socket_domain -> socket_type -> int -> file_descr
val connect : file_descr -> sockaddr -> unit
val bind : file_descr -> sockaddr -> unit
val listen : file_descr -> int -> unit
val accept : file_descr -> file_descr * sockaddr
val select : file_descr list -> file_descr list -> file_descr list ->
             float -> file_descr list * file_descr list * file_descr list
```

#### Why Traditional OCaml IO Was Problematic for Concurrency

1. **Blocking IO**: All standard library IO functions are synchronous — they block the calling thread until the operation completes. The Unix library's `read`, `write`, `accept` all block.

2. **Single-threaded runtime**: OCaml 4.x had a global runtime lock (GIL equivalent). Even with system threads, only one OCaml thread could execute at a time. Blocking IO in one thread blocked progress for all OCaml computation.

3. **`in_channel_of_descr` / `out_channel_of_descr` double-close bug**: A common pattern for sockets is to create both an `in_channel` and `out_channel` from the same fd. But `close_in` and `close_out` both call the underlying `close()` syscall — closing one channel silently closes the fd under the other, leading to use-after-close or double-close errors.

4. **No composable async**: Before OCaml 5, concurrency required monadic libraries (Lwt, Async) that imposed a "function coloring" problem — all IO code had to return `Lwt.t` or `Async.Deferred.t`, infecting entire call stacks.

5. **`select` limitations**: The multiplexing primitive (`Unix.select`) has well-known scalability problems — O(N) per call, fd set size limits, no support for modern interfaces (epoll, kqueue, io_uring).

---

### 8. Eio — Effects-Based IO for OCaml 5

Eio is the replacement IO stack for OCaml 5, leveraging algebraic effects to provide direct-style concurrent IO without monadic wrappers.

#### Core Mechanism: Algebraic Effects

OCaml 5 introduced *effect handlers* — a language feature that allows a function to *perform* an effect (like "read from network"), and a handler higher in the call stack to *interpret* that effect (by dispatching to io_uring, epoll, blocking IO, or a mock implementation).

**Advantages over monads (Lwt/Async)**:
- No heap allocations for stack simulation — effects use the real call stack
- Concurrent code is syntactically identical to sequential code
- Exception backtraces work correctly through concurrent fibers
- `try ... with ...` works naturally in concurrent contexts
- No function coloring — a function's type does not reveal whether it performs IO

#### Eio.Flow — Core IO Abstractions

Flows represent byte streams. The type hierarchy uses OCaml's polymorphic variant / object system:

```ocaml
type source_ty = [ `R | `Flow ]        (* readable *)
type 'a source = [> source_ty] as 'a   (* any readable flow *)

type sink_ty = [ `W | `Flow ]          (* writable *)
type 'a sink = [> sink_ty] as 'a       (* any writable flow *)

type two_way_ty = [ source_ty | sink_ty | `Shutdown ]
type 'a two_way = [> two_way_ty] as 'a  (* bidirectional *)
```

**Key operations**:

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `single_read` | `_ source -> Cstruct.t -> int` | Read one or more bytes |
| `read_exact` | `_ source -> Cstruct.t -> unit` | Read until buffer full |
| `read_all` | `_ source -> string` | Read entire stream |
| `write` | `_ sink -> Cstruct.t list -> unit` | Write all buffers |
| `single_write` | `_ sink -> Cstruct.t list -> int` | Write at least one byte |
| `copy` | `_ source -> _ sink -> unit` | Copy until EOF |
| `copy_string` | `string -> _ sink -> unit` | Write string to sink |
| `shutdown` | `_ two_way -> shutdown_command -> unit` | Signal end of read/write/both |
| `close` | `_ -> unit` | Release resource |

**In-memory flows** for testing:
```ocaml
val string_source : string -> source_ty r          (* source from string *)
val cstruct_source : Cstruct.t list -> source_ty r  (* source from buffers *)
val buffer_sink : Buffer.t -> sink_ty r             (* sink to OCaml buffer *)
```

#### Eio.Buf_read — Buffered Reading and Parsing

`Buf_read` wraps a source with an internal buffer, enabling efficient streaming parsers:

```ocaml
val of_flow : _ source -> initial_size:int -> max_size:int -> t
```

**Parser type**: `type 'a parser = t -> 'a` — a function consuming bytes and returning parsed values.

**Reading parsers**:

| Parser | Semantics |
|--------|-----------|
| `line` | Read until LF or CRLF |
| `lines` | Lazy sequence of lines |
| `char c` | Match specific character |
| `any_char` | Read single character |
| `peek_char` | Inspect without consuming |
| `string s` | Match exact string prefix |
| `take n` | Read exactly N bytes |
| `take_all` | Read remaining until EOF |
| `take_while p` | Read while predicate holds |
| `uint8` | Parse unsigned byte |
| `at_end_of_input` | Check for EOF |

**Combinators**:

| Combinator | Semantics |
|------------|-----------|
| `pair p1 p2` | Sequential composition |
| `map f p` | Transform result |
| `bind p f` | Monadic chaining |
| `seq ?stop p` | Lazy sequence of parsed values |
| `format_errors p` | Exception-to-result conversion |

**Endianness**: `BE` and `LE` sub-modules provide big/little-endian integer parsers.

**Low-level buffer access**: `peek`, `ensure`, `consume`, `buffered_bytes`, `consumed_bytes`, `eof_seen`.

#### Eio.Buf_write — Buffered Writing

```ocaml
val with_flow : _ sink -> (t -> 'a) -> 'a
```

Creates an auto-flushing writer connected to a flow, managing concurrent data transfer.

**Buffered writes** (copy into internal buffer):

| Function | Semantics |
|----------|-----------|
| `string t s` | Write string |
| `bytes t b` | Write byte array |
| `cstruct t c` | Write Cstruct |
| `char t c` | Write character |
| `uint8 t n` | Write byte |
| `printf t fmt ...` | Formatted write |

**Unbuffered writes**: `schedule_cstruct` enqueues data without copying (caller must not modify until flushed).

**Control**: `flush`, `close`, `pause`/`unpause`, `has_pending_output`, `pending_bytes`.

**Endianness**: `BE` and `LE` sub-modules for numeric serialization.

#### Eio.Net — Networking

**Address types**:
```ocaml
Sockaddr.stream   (* TCP, Unix domain *)
Sockaddr.datagram (* UDP *)
```

**Client operations**:
```ocaml
val connect : sw:Switch.t -> _ t -> Sockaddr.stream -> _ stream_socket
val with_tcp_connect : host:string -> service:string -> _ t -> (_ stream_socket -> 'a) -> 'a
```

**Server operations**:
```ocaml
val listen : sw:Switch.t -> backlog:int -> _ t -> Sockaddr.stream -> _ listening_socket
val accept : sw:Switch.t -> _ listening_socket -> _ stream_socket * Sockaddr.stream
val accept_fork : sw:Switch.t -> _ listening_socket -> on_error:(exn -> unit) ->
                  (_ stream_socket -> Sockaddr.stream -> unit) -> unit
val run_server : ?additional_domains:(Domain_manager.t * int) ->
                 on_error:(exn -> unit) -> _ listening_socket -> connection_handler -> unit
```

`run_server` handles concurrent client connections, optionally distributing across multiple OS domains (true parallelism).

**Datagram operations**:
```ocaml
val datagram_socket : sw:Switch.t -> _ t -> Sockaddr.datagram -> _ datagram_socket
val send : _ datagram_socket -> ?dst:Sockaddr.datagram -> Cstruct.t list -> unit
val recv : _ datagram_socket -> Cstruct.t -> Sockaddr.datagram * int
```

**DNS**:
```ocaml
val getaddrinfo : ?service:string -> _ t -> string -> Sockaddr.t list
val getaddrinfo_stream : ?service:string -> _ t -> string -> Sockaddr.stream list
val getnameinfo : _ t -> Sockaddr.t -> string * string
```

**Error types**: `connection_failure` = `Refused | No_matching_addresses | Timeout`; `error` = `Connection_reset | Connection_failure of connection_failure`.

#### Eio.Path — File System

Paths are capability handles: a directory fd paired with a relative path.

```ocaml
type 'a t  (* directory capability + relative path *)

val (/) : 'a t -> string -> 'a t  (* append path component *)
```

**Reading**:
```ocaml
val load : _ t -> string                              (* read entire file *)
val open_in : sw:Switch.t -> _ t -> _ Flow.source     (* open for reading *)
val with_open_in : _ t -> (_ Flow.source -> 'a) -> 'a (* open, use, close *)
val with_lines : _ t -> (string Seq.t -> 'a) -> 'a    (* stream lines *)
```

**Writing**:
```ocaml
val save : ?append:bool -> create:_ -> _ t -> string -> unit
val open_out : sw:Switch.t -> _ t -> _ Flow.sink
val with_open_out : _ t -> (_ Flow.sink -> 'a) -> 'a
```

**Directory operations**:
```ocaml
val mkdir : perm:int -> _ t -> unit
val mkdirs : ?exists_ok:bool -> perm:int -> _ t -> unit
val open_dir : sw:Switch.t -> _ t -> _ t
val read_dir : _ t -> string list        (* sorted, excludes . and .. *)
```

**Metadata**: `stat`, `kind`, `is_file`, `is_directory`, `read_link`

**Manipulation**: `unlink`, `rmdir`, `rmtree`, `rename`, `symlink`

#### Eio.Switch — Structured Concurrency

A switch groups fibers and resources with a bounded lifetime:

```ocaml
val run : (Switch.t -> 'a) -> 'a
```

**Semantics**: `Switch.run fn` creates a switch, runs `fn` with it, waits for all attached fibers to complete, then releases all attached resources (file handles, sockets, etc.).

```ocaml
Switch.run (fun sw ->
    let socket = Eio.Net.listen ~sw ~backlog:5 net addr in
    Fiber.fork ~sw (fun () -> handle_connections socket);
    (* ... more work ... *)
)
(* All fibers done, socket closed, resources released *)
```

**Key property**: Functions without a switch parameter cannot spawn long-lived fibers or leak resources. The switch is the capability to create concurrent work.

**Failure semantics**: If any fiber raises an exception, sibling fibers are cancelled. `Switch.fail sw exn` explicitly marks a switch as failed.

#### Fiber Operations

```ocaml
val fork : sw:Switch.t -> (unit -> unit) -> unit
val fork_daemon : sw:Switch.t -> (unit -> [`Stop_daemon]) -> unit
val fork_promise : sw:Switch.t -> (unit -> 'a) -> 'a Promise.or_exn
val fork_seq : sw:Switch.t -> (('a -> unit) -> unit) -> 'a Seq.t
```

**Structured concurrency combinators**:

| Combinator | Semantics |
|------------|-----------|
| `both f g` | Run f and g concurrently; wait for both; cancel other on exception |
| `pair f g` | Like `both` but returns `('a * 'b)` |
| `all fs` | Run list of functions concurrently; wait for all |
| `first f g` | Run f and g; return first to finish; cancel the other |
| `any fs` | Run list; return first to finish; cancel rest |
| `n_any fs` | Run list; return all results ordered by completion |

**Control**:
```ocaml
val yield : unit -> unit       (* reschedule to back of queue *)
val check : unit -> unit       (* raise Cancelled if cancelled *)
val is_cancelled : unit -> bool
val await_cancel : unit -> 'a  (* block until cancelled *)
```

**Scheduling determinism**: Within a single domain, fibers are scheduled deterministically. `Fiber.both f g` always starts `f` first, only switching to `g` when `f` yields or performs an effect.

#### How Algebraic Effects Enable Direct-Style Async IO

The mechanism:

1. A fiber calls `Eio.Net.accept socket` (a normal function call, no monadic wrapping).
2. Internally, this *performs* a `Read` effect.
3. The effect propagates up the call stack to the nearest handler — the Eio scheduler.
4. The scheduler suspends the fiber (saving its continuation on the stack, not the heap).
5. The scheduler submits the read to io_uring / epoll / kqueue.
6. When the kernel signals completion, the scheduler *resumes* the fiber's continuation.
7. `accept` returns a value to the fiber as if it were a normal function call.

The fiber's code is straight-line imperative code. No `>>=`, no `let%bind`, no `async`/`await`. The concurrency machinery is invisible.

**Testability consequence**: Because effects are handled by a *handler*, you can substitute the handler:
- Production: `eio_linux` handler dispatches to io_uring
- Test: `Eio_mock.Backend.run` handler provides deterministic, in-memory IO
- Same fiber code, different handlers, different behavior — dependency injection at the effect level

#### Capability-Based Security Model

Eio enforces a capability discipline through OCaml's lexical scoping:

```ocaml
Eio_main.run (fun env ->
    let stdout = Eio.Stdenv.stdout env in
    let fs = Eio.Stdenv.fs env in
    let net = Eio.Stdenv.net env in
    (* Pass only what each function needs *)
    write_report ~out:stdout data;      (* can only write to stdout *)
    save_to_disk ~fs ~path:"out.txt";   (* can access filesystem *)
    serve ~net ~port:8080;              (* can access network *)
)
```

**Properties**:

1. A function can only access resources in its scope. A function receiving only `stdout` cannot touch the filesystem or network.
2. Type signatures document resource requirements. `f : _ Flow.sink -> unit` can only write bytes.
3. No ambient authority. There is no `Eio.get_filesystem()` — the process capabilities come from `env`, which comes from `Eio_main.run`, which is the entry point.
4. Testing substitutes mock capabilities without code changes. Pass a `buffer_sink` instead of `stdout`.

**Enforcement**: Primarily through OCaml's type system and lexical scoping. On FreeBSD, `capsicum` can add OS-level enforcement. The model is analogous to Rust's `cap-std`.

**Community tension**: Some users found the capability model intrusive for simple programs. The explicit passing of `env`, `fs`, `net` through the call stack adds ceremony. This is an active design discussion.

---

### 9. Key Design Patterns in Eio

#### Direct-Style (No Monadic Bind, No Async/Await)

```ocaml
(* Eio: direct style *)
let data = Eio.Flow.read_all source in
Eio.Flow.copy_string data sink

(* Lwt: monadic *)
let%lwt data = Lwt_io.read source in
let%lwt () = Lwt_io.write sink data in
Lwt.return ()

(* Async: monadic *)
let%bind data = Reader.contents source in
let%bind () = Writer.write writer data in
return ()
```

In Eio, every function call is a plain function call. Concurrency is orthogonal to the syntax.

#### Capability Passing Instead of Global Access

| Traditional | Eio |
|-------------|-----|
| `Unix.openfile "/etc/passwd"` | `Eio.Path.load (fs / "etc" / "passwd")` |
| `Unix.socket PF_INET SOCK_STREAM 0` | `Eio.Net.connect ~sw net addr` |
| `print_string "hello"` | `Eio.Flow.copy_string "hello" stdout` |

Every external resource requires an explicit capability argument. This eliminates hidden dependencies.

#### Structured Concurrency via Switches

All concurrent work is scoped:

```ocaml
Switch.run (fun sw ->
    Fiber.fork ~sw (fun () -> download url1);
    Fiber.fork ~sw (fun () -> download url2);
    (* Switch.run blocks until both downloads complete *)
    (* If either fails, the other is cancelled *)
    (* All attached resources (sockets, files) are released *)
)
(* No dangling fibers, no leaked resources *)
```

Contrast with unstructured concurrency (e.g., Go goroutines), where a goroutine can outlive its creator, leak resources, and produce errors that nobody handles.

#### How Effects Enable Testability

```ocaml
(* Production *)
Eio_linux.run (fun env ->
    my_server ~net:(Eio.Stdenv.net env) ~port:8080
)

(* Test *)
Eio_mock.Backend.run (fun () ->
    let mock_net = Eio_mock.Net.make "test-net" in
    my_server ~net:mock_net ~port:8080
)
```

The same `my_server` function runs against real io_uring or against a deterministic mock. Effects provide the inversion-of-control mechanism:

1. `my_server` performs IO effects (connect, read, write)
2. In production, the `eio_linux` handler interprets these as kernel syscalls
3. In tests, the mock handler interprets them as in-memory operations
4. The mock backend detects deadlocks automatically
5. Deterministic scheduling enables reproducible test failures

#### Fiber-Based Concurrency

Fibers are lightweight concurrent units cooperatively scheduled within a domain (OS thread):

- **Creation**: `Fiber.fork ~sw fn` — attach to switch, start running when creator yields
- **Scheduling**: Cooperative, deterministic within a domain. `Fiber.yield()` moves to back of queue
- **Communication**: `Promise` (single value), `Stream` (bounded queue), `Mutex`, `Semaphore`, `Condition`
- **Multicore**: `Domain_manager.run_in_background_domain fn` moves computation to another OS thread. `Executor_pool` distributes CPU work across domains
- **Cost**: No heap allocation for the fiber stack (uses effect handler continuation). Much cheaper than OS threads.

---

## Error Handling Comparison

### Eio Error Model

Eio uses `Eio.Io (err, context)` exceptions with nested, extensible error codes:

```ocaml
try Eio.Buf_read.line reader with
| Eio.Io (Eio.Net.E (Connection_reset (Eio_unix.Unix_error _)), _) ->
    "Unix connection reset"
| Eio.Io (Eio.Net.E (Connection_reset _), _) ->
    "Connection reset (any backend)"
| Eio.Io (Eio.Net.E _, _) ->
    "Some network error"
| Eio.Io _ ->
    "Some IO error"
```

The nesting enables both specific and broad matching in the same handler. Context accumulates through the call stack via `Exn.add_context`.

For portable code, match on Eio-level errors (not backend-specific ones). Backend-specific errors are accessible via `Exn.Backend.t` for low-level diagnostics.

### Zig Error Model

Zig uses error unions with compile-time error sets:

```zig
file.read(buffer) catch |err| switch (err) {
    error.EndOfStream => break,
    error.ConnectionReset => return reconnect(),
    error.WouldBlock => continue,
    // compiler enforces exhaustive handling
};
```

The compiler guarantees exhaustive error handling. Error sets compose algebraically via `||`. No runtime cost for error values (they are small integers internally).

---

## Cross-Cutting Comparison

| Dimension | Zig | OCaml (Eio) |
|-----------|-----|-------------|
| **IO abstraction** | `std.Io.Reader` / `Writer` (concrete struct + vtable) | `Flow.source` / `Flow.sink` (object types) |
| **Buffering** | Integrated in interface (buffer passed at construction) | Separate `Buf_read` / `Buf_write` wrappers |
| **Type erasure** | `@fieldParentPtr` recovers concrete type from embedded interface | OCaml object system; polymorphic variants |
| **Error handling** | Error unions with comptime error sets; exhaustive switch | Exceptions with nested extensible error codes |
| **Concurrency model** | `Io` interface (blocking / thread pool / io_uring) | Algebraic effects (fibers + effect handlers) |
| **Async style** | Explicit `io.async()` / `future.await(io)` | Invisible — direct-style, effects handle suspension |
| **Resource management** | Manual close / defer | Switches scope resource lifetime |
| **Allocator** | Explicit `Allocator` parameter | OCaml GC (no explicit allocation) |
| **Capability model** | `Io` and `Dir` constrain access (fd-relative paths) | Full capability discipline (env, fs, net passed explicitly) |
| **Testing** | `FixedBufferStream` for in-memory IO | `Eio_mock` backend with deterministic scheduling |
| **Platform backends** | Single stdlib; OS differences in `posix` layer | `eio_linux` (io_uring), `eio_posix`, `eio_windows` |
| **Binary size** | Concrete types avoid monomorphization bloat | N/A (bytecode or native, no generics bloat) |
| **Function coloring** | Solved: `Io` interface is runtime-polymorphic | Solved: effects are invisible in function signatures |

---

## OS-Level IO Primitives


---

## Table of Contents

1. [Linux io_uring](#1-linux-io_uring)
   - [1.1 Core Model](#11-core-model)
   - [1.2 Key Operations](#12-key-operations)
   - [1.3 Advanced Features](#13-advanced-features)
   - [1.4 Completion-Based vs Readiness-Based IO](#14-completion-based-vs-readiness-based-io)
2. [epoll (Linux)](#2-epoll-linux)
3. [kqueue (BSD/macOS)](#3-kqueue-bsdmacos)
4. [IOCP (Windows)](#4-iocp-windows)
5. [libuv (Node.js)](#5-libuv-nodejs)
6. [Cross-Cutting Patterns](#6-cross-cutting-patterns)

---

## 1. Linux io_uring

### 1.1 Core Model

#### The Ring Buffer Design

io_uring (introduced in Linux 5.1, 2019) is built on a pair of ring buffers shared between user space and kernel space:

- **Submission Queue (SQ)**: User-space produces entries; kernel consumes them. The application writes submission queue entries (SQEs) to the tail; the kernel reads them from the head.
- **Completion Queue (CQ)**: Kernel produces entries; user-space consumes them. The kernel writes completion queue entries (CQEs) to the tail; the application reads them from the head.

Both rings are mapped into shared memory via `mmap()` after `io_uring_setup()`. This eliminates the need for data copying between user and kernel space for request/completion metadata. The fundamental insight: by making the communication channel a lock-free single-producer/single-consumer ring buffer in shared memory, the majority of IO operations can proceed without any syscall at all.

The SQ ring contains an indirection array of indices into a separate SQE array. This indirection exists so that applications can pre-allocate SQEs and submit them in any order, since the ring itself only needs to be contiguous in terms of indices, not in terms of the SQE memory layout.

The CQ ring directly contains CQE structs inline (no indirection), since the kernel always produces completions sequentially.

Default sizing: CQ is typically 2x the size of SQ (e.g., SQ=128 entries implies CQ=256 entries), though this is configurable via `IORING_SETUP_CQSIZE`.

#### io_uring_sqe (Submission Queue Entry)

An SQE is 64 bytes, aligned for cache efficiency. It describes a single IO operation in a format that maps closely to a syscall:

```c
struct io_uring_sqe {
    __u8    opcode;     // Operation type (IORING_OP_READ, etc.)
    __u8    flags;      // IOSQE_ flags (link, drain, fixed file, etc.)
    __u16   ioprio;     // Request priority or per-op flags
    __s32   fd;         // File descriptor (or fixed file index)
    union {
        __u64   off;            // Offset into file
        __u64   addr2;          // Secondary address (for some ops)
    };
    union {
        __u64   addr;           // Buffer address (or pointer to iovecs)
        __u64   splice_off_in;  // Splice input offset
    };
    __u32   len;        // Buffer length or iovec count
    union {
        __kernel_rwf_t  rw_flags;       // read/write flags
        __u32           fsync_flags;    // fsync flags
        __u16           poll_events;    // poll events mask
        __u32           sync_range_flags;
        __u32           msg_flags;      // send/recv msg flags
        __u32           timeout_flags;
        __u32           accept_flags;
        __u32           cancel_flags;
        __u32           open_flags;
        __u32           statx_flags;
        __u32           fadvise_advice;
        __u32           splice_flags;
        __u32           rename_flags;
        __u32           unlink_flags;
        __u32           hardlink_flags;
    };
    __u64   user_data;  // Opaque value passed through to CQE
    union {
        __u16   buf_index;  // Index into fixed buffer array
        __u16   buf_group;  // For provided buffer selection
    };
    __u16   personality;    // Credentials to use for this op
    union {
        __s32   splice_fd_in;
        __u32   file_index;     // Fixed file slot index
    };
    __u64   __pad2[2];  // Reserved for future use
};
```

Key design observations:
- Unions are used extensively to keep the struct at exactly 64 bytes while supporting 60+ operation types.
- `user_data` is the primary mechanism for correlating submissions with completions. It is completely opaque to the kernel.
- `flags` controls linking, draining, fixed file/buffer usage, and async forcing.

#### io_uring_cqe (Completion Queue Entry)

A CQE is 16 bytes (or 32 bytes with `IORING_SETUP_CQE32`):

```c
struct io_uring_cqe {
    __u64   user_data;  // Copied from corresponding SQE
    __s32   res;        // Result: >= 0 on success, -errno on failure
    __u32   flags;      // IORING_CQE_F_* flags
};
```

The `res` field mirrors the return value of the equivalent syscall. For example, a completed `IORING_OP_READ` returns the number of bytes read (or `-EAGAIN`, `-EINVAL`, etc.).

CQE flags include:
- `IORING_CQE_F_BUFFER` (bit 0): Buffer ID is valid in the upper 16 bits of `flags` (used with provided buffers).
- `IORING_CQE_F_MORE` (bit 1): More completions expected from this SQE (multishot operations).
- `IORING_CQE_F_SOCK_NONEMPTY` (bit 2): Socket still has data after this recv.
- `IORING_CQE_F_NOTIF` (bit 3): Notification-only CQE (zero-copy send).

The 16-byte CQE size is deliberate: it fits two CQEs per cache line, maximizing throughput when draining the completion queue.

#### io_uring_setup

```c
int io_uring_setup(u32 entries, struct io_uring_params *params);
```

Creates a new io_uring instance. Returns a file descriptor used to refer to it. The kernel fills in `params` with the actual ring sizes and feature flags. The caller then `mmap()`s three regions:
1. The SQ ring (header + index array)
2. The CQ ring (header + CQE array)
3. The SQE array

Setup flags control behavior:
- `IORING_SETUP_SQPOLL`: Kernel-side submission polling (no syscall needed to submit).
- `IORING_SETUP_IOPOLL`: Busy-poll for completions on polled IO devices (NVMe).
- `IORING_SETUP_SQ_AFF`: Pin the SQ poll thread to a specific CPU.
- `IORING_SETUP_CQSIZE`: Allow specifying CQ ring size independently.
- `IORING_SETUP_SINGLE_ISSUER`: Optimization hint: only one thread submits.
- `IORING_SETUP_DEFER_TASKRUN`: Defer completion processing to `io_uring_enter()`.

#### io_uring_enter

```c
int io_uring_enter(unsigned int fd, u32 to_submit, u32 min_complete,
                   u32 flags, const void *argp, size_t argsz);
```

The primary syscall for interacting with a running io_uring instance:
- `to_submit`: Number of SQEs to submit from the SQ ring.
- `min_complete`: Block until at least this many CQEs are available.
- `flags`: `IORING_ENTER_GETEVENTS` (wait for completions), `IORING_ENTER_SQ_WAKEUP` (wake SQPOLL thread), `IORING_ENTER_SQ_WAIT` (wait for SQ space), `IORING_ENTER_EXT_ARG` (extended argument for timeouts).

With SQPOLL enabled, `io_uring_enter()` is only needed to wake a sleeping poll thread or to wait for completions. Submission happens automatically as the kernel thread polls the SQ ring.

#### liburing (High-Level C Wrapper)

liburing eliminates the boilerplate of `mmap()` setup and ring pointer arithmetic. Core API pattern:

```c
// Initialization
struct io_uring ring;
io_uring_queue_init(queue_depth, &ring, flags);

// Submit a read
struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
io_uring_prep_read(sqe, fd, buf, len, offset);
io_uring_sqe_set_data(sqe, user_context);  // set user_data
io_uring_submit(&ring);

// Harvest completions
struct io_uring_cqe *cqe;
io_uring_wait_cqe(&ring, &cqe);           // blocking wait
void *ctx = io_uring_cqe_get_data(cqe);   // retrieve user_data
int result = cqe->res;
io_uring_cqe_seen(&ring, cqe);            // advance CQ head

// Cleanup
io_uring_queue_exit(&ring);
```

Key liburing functions:
- `io_uring_queue_init(entries, ring, flags)` / `io_uring_queue_exit(ring)` -- lifecycle.
- `io_uring_get_sqe(ring)` -- get next available SQE slot.
- `io_uring_prep_*(sqe, ...)` -- family of ~60 prep functions, one per operation type.
- `io_uring_submit(ring)` -- submit all pending SQEs (calls `io_uring_enter` internally).
- `io_uring_submit_and_wait(ring, n)` -- submit and wait for `n` completions.
- `io_uring_wait_cqe(ring, cqe)` / `io_uring_peek_cqe(ring, cqe)` -- blocking/non-blocking completion retrieval.
- `io_uring_cqe_seen(ring, cqe)` -- mark CQE as consumed (advances CQ head).
- `io_uring_sqe_set_data(sqe, ptr)` / `io_uring_cqe_get_data(cqe)` -- user_data convenience.

liburing also provides batch APIs:
- `io_uring_submit_and_wait_timeout()` -- submit with a timeout for completions.
- `io_uring_peek_batch_cqe()` -- retrieve multiple CQEs at once.

---

### 1.2 Key Operations

#### File IO

| Operation | Description | Key Fields |
|-----------|-------------|------------|
| `IORING_OP_READ` | Positioned read into buffer | fd, addr (buf), len, off |
| `IORING_OP_WRITE` | Positioned write from buffer | fd, addr (buf), len, off |
| `IORING_OP_READV` | Vectored read (scatter) | fd, addr (iovec array), len (iovec count), off |
| `IORING_OP_WRITEV` | Vectored write (gather) | fd, addr (iovec array), len (iovec count), off |
| `IORING_OP_READ_FIXED` | Read into pre-registered buffer | fd, addr, len, off, buf_index |
| `IORING_OP_WRITE_FIXED` | Write from pre-registered buffer | fd, addr, len, off, buf_index |
| `IORING_OP_FSYNC` | File sync | fd, fsync_flags |
| `IORING_OP_OPENAT` | Open file | dirfd, addr (path), open_flags, len (mode) |
| `IORING_OP_CLOSE` | Close file descriptor | fd |
| `IORING_OP_STATX` | File status | dirfd, addr (path), addr2 (statx buf), statx_flags |

#### Network IO

| Operation | Description | Key Fields |
|-----------|-------------|------------|
| `IORING_OP_ACCEPT` | Accept connection | fd (listen sock), addr (sockaddr), addr2 (addrlen) |
| `IORING_OP_CONNECT` | Initiate connection | fd, addr (sockaddr), off (addrlen) |
| `IORING_OP_SEND` | Send data | fd, addr (buf), len, msg_flags |
| `IORING_OP_RECV` | Receive data | fd, addr (buf), len, msg_flags |
| `IORING_OP_SENDMSG` | Send message (msghdr) | fd, addr (msghdr) |
| `IORING_OP_RECVMSG` | Receive message (msghdr) | fd, addr (msghdr) |
| `IORING_OP_SEND_ZC` | Zero-copy send | fd, addr (buf), len |
| `IORING_OP_SOCKET` | Create socket | fd (domain), off (type), len (protocol) |

#### Linked Operations (SQE Chaining)

SQEs can be chained so that the next SQE only starts after the previous one completes. This is controlled by flags on each SQE:

- **`IOSQE_IO_LINK`**: Soft link. The next SQE in the ring will not start until this one completes. If this SQE fails (error or short read/write), the remaining linked SQEs are cancelled with `-ECANCELED`.
- **`IOSQE_IO_HARDLINK`**: Hard link. Same sequencing guarantee, but the chain is NOT broken on error. The next SQE executes regardless of the previous result.
- **`IOSQE_IO_DRAIN`**: This SQE will not start until all previously submitted SQEs have completed. Acts as a barrier.

Chaining enables compound operations without round-tripping to user space:

```
accept (into fixed file slot 5) -> recv (from fixed file slot 5) -> send (to fixed file slot 5)
```

The chain is formed by setting `IOSQE_IO_LINK` on the first two SQEs. The last SQE in a chain does NOT have the link flag set.

Multiple independent chains can execute in parallel. Only SQEs within the same chain are sequenced.

#### Fixed Buffers and Fixed Files

**Fixed Buffers** (`IORING_REGISTER_BUFFERS`): Pre-register a set of buffers with the kernel. The kernel pins the pages and maps them once. Subsequent `IORING_OP_READ_FIXED` / `IORING_OP_WRITE_FIXED` operations reference these buffers by index (`buf_index`), avoiding per-IO page mapping/unmapping. This is particularly beneficial with O_DIRECT IO where the kernel would otherwise need to `get_user_pages()` for every operation.

**Fixed Files** (`IORING_REGISTER_FILES`): Pre-register file descriptors. The kernel takes a stable reference to each file, so per-operation `fget()` / `fput()` (file reference counting) is eliminated. Fixed files are referenced via `file_index` in the SQE with the `IOSQE_FIXED_FILE` flag. Critical for SQPOLL mode (originally required; optional since kernel 5.11).

The combination of fixed buffers + fixed files + SQPOLL can achieve truly zero-syscall IO: the application writes SQEs to the ring, the kernel poll thread picks them up, performs the IO using pre-registered resources, and posts CQEs -- all without a single syscall or context switch.

---

### 1.3 Advanced Features

#### Buffer Rings (Provided Buffers)

Two generations of provided buffer support exist:

**Generation 1: `IORING_OP_PROVIDE_BUFFERS`** (kernel 5.7)
The application submits an SQE that donates a set of buffers to a buffer group (identified by `buf_group`). Each buffer has a buffer ID (`bid`). When a subsequent recv/read SQE sets `IOSQE_BUFFER_SELECT` and the matching `buf_group`, the kernel picks a buffer from the group at completion time. The selected buffer ID is returned in the CQE flags.

Limitation: Replenishing buffers requires submitting new `IORING_OP_PROVIDE_BUFFERS` SQEs, adding overhead.

**Generation 2: Ring-Mapped Buffer Rings** (kernel 5.19+)
A shared ring buffer between application and kernel dedicated to buffer management:

```c
struct io_uring_buf {
    __u64   addr;   // Buffer address
    __u32   len;    // Buffer length
    __u16   bid;    // Buffer ID (returned in CQE)
    __u16   resv;
};

struct io_uring_buf_ring {
    union {
        struct {
            __u64   resv1;
            __u32   resv2;
            __u16   resv3;
            __u16   tail;   // Application advances this
        };
        struct io_uring_buf bufs[0];
    };
};
```

The application registers a buffer ring via `io_uring_register_buf_ring()`, then adds buffers using `io_uring_buf_ring_add()` and advances the tail with `io_uring_buf_ring_advance()`. The kernel consumes buffers from the head. No SQE submission is needed to replenish -- just add to the ring and advance the tail.

**Incremental Consumption** (kernel 6.12): Large buffers can be partially consumed. Each recv completion consumes only the bytes actually received, and `IORING_CQE_F_BUF_MORE` signals that the same buffer has more space. This dramatically reduces buffer churn for streaming workloads.

#### Multishot Operations

Multishot operations submit a single SQE that generates multiple CQEs over time:

| Operation | Available Since | Description |
|-----------|----------------|-------------|
| `io_uring_prep_multishot_accept` | Kernel 5.19 | Repeatedly accepts connections; each new connection generates a CQE |
| `io_uring_prep_recv_multishot` | Kernel 6.0 | Repeatedly receives data; each data arrival generates a CQE |
| `io_uring_prep_recvmsg_multishot` | Kernel 6.0 | Multishot recvmsg with msghdr support |
| `io_uring_prep_poll_multishot` | Kernel 5.13 | Repeated poll notifications |

The `IORING_CQE_F_MORE` flag in the CQE signals that additional completions are expected from the same SQE. When this flag is absent, the multishot request has been exhausted or cancelled.

Multishot operations are almost always combined with provided buffer rings: the application does not know in advance how many completions will arrive, so it cannot pre-assign buffers. Instead, `IOSQE_BUFFER_SELECT` lets the kernel pick a buffer from the group for each completion.

This is the model for high-performance network servers: one multishot accept SQE + one multishot recv SQE per connection + a shared buffer ring = minimal SQE submission overhead.

#### io_uring_register

`io_uring_register(int fd, unsigned opcode, void *arg, unsigned nr_args)` pre-registers resources with a specific io_uring instance:

| Opcode | Purpose |
|--------|---------|
| `IORING_REGISTER_BUFFERS` | Pin user buffers for fixed read/write |
| `IORING_UNREGISTER_BUFFERS` | Release pinned buffers |
| `IORING_REGISTER_FILES` | Register file descriptors for fixed-file ops |
| `IORING_UNREGISTER_FILES` | Release registered files |
| `IORING_REGISTER_FILES_UPDATE` | Sparse update of the file table |
| `IORING_REGISTER_BUFFERS_UPDATE` | Sparse update of buffer registrations |
| `IORING_REGISTER_EVENTFD` | Associate an eventfd for external wakeup |
| `IORING_REGISTER_PROBE` | Query supported operations |
| `IORING_REGISTER_RING_FD` | Register the ring fd itself (reduces one fd lookup) |
| `IORING_REGISTER_BUF_RING` | Register a ring-mapped buffer ring |

Resource registration amortizes the per-operation cost of kernel lookups (page pinning for buffers, file reference counting for fds). The cost is paid once at registration time rather than on every IO operation.

Important: registered resources may be held alive by in-flight operations even after unregistration returns. The kernel only releases them after all referencing operations complete.

#### Kernel-Side Polling (SQPOLL)

When `IORING_SETUP_SQPOLL` is passed to `io_uring_setup()`, the kernel spawns a dedicated poll thread (`io_sq_thread`) that continuously monitors the SQ ring for new entries.

Operational model:
1. Application writes SQEs to the SQ ring (just memory writes, no syscall).
2. Kernel poll thread detects new entries and submits them.
3. Completions appear on the CQ ring.
4. Application reads CQEs (just memory reads, no syscall).

The poll thread has an idle timeout (configurable via `sq_thread_idle` in `io_uring_params`). When the SQ is idle for this duration, the thread goes to sleep. The application must then call `io_uring_enter()` with `IORING_ENTER_SQ_WAKEUP` to restart it, or use `IORING_SQ_NEED_WAKEUP` flag checking to detect when wakeup is needed.

CPU affinity: `IORING_SETUP_SQ_AFF` + `sq_thread_cpu` pins the poll thread to a specific core, which is essential for latency-sensitive workloads.

SQPOLL is a privileged operation (requires `CAP_SYS_NICE` or root) because it consumes a dedicated CPU thread.

---

### 1.4 Completion-Based vs Readiness-Based IO

#### Fundamental Difference

| Aspect | Readiness-Based (epoll/kqueue) | Completion-Based (io_uring/IOCP) |
|--------|-------------------------------|----------------------------------|
| Notification | "fd is ready for read/write" | "read/write is done" |
| Who does IO | Application (via syscall) | Kernel (on behalf of application) |
| Syscalls per IO | 2+ (wait + read/write) | 1 amortized (submit batch) |
| Buffer provided | At read/write time | At submission time |
| Buffer ownership during IO | Application owns always | Kernel owns until completion |

Readiness-based IO (epoll/kqueue):
1. Register interest in fd events.
2. Wait for readiness notification.
3. Perform the actual read()/write() syscall yourself.
4. The buffer is yours at all times; you pass it to read()/write() and get it back immediately.

Completion-based IO (io_uring/IOCP):
1. Submit an IO request with a buffer.
2. Wait for completion notification.
3. The IO is already done when you get the notification.
4. The buffer is owned by the kernel from submission until completion.

#### Buffer Ownership Implications

This is the critical design constraint for higher-level language bindings:

**Readiness model**: The application can use any buffer, including stack-allocated buffers or buffers from a pool. The buffer is only needed at the moment of the read()/write() call. There is no lifetime entanglement with the kernel.

**Completion model**: Once a buffer is submitted, the application MUST NOT access it until the corresponding CQE arrives. If the application cancels the operation (e.g., drops a Future in Rust), the buffer is still owned by the kernel until the cancellation completes. This means:
- Buffers cannot be stack-allocated (the stack frame may return before completion).
- Buffer pools must track which buffers are in-flight.
- Cancellation must be handled carefully to avoid use-after-free.
- In garbage-collected languages, the buffer must be pinned to prevent the GC from moving or collecting it.

This is why provided buffer rings are so important: they move buffer selection to the kernel, which selects a buffer at completion time rather than submission time. The application provides a pool; the kernel picks from it.

#### Implications for API Design in Higher-Level Languages

**Reactor pattern** (epoll/kqueue): Maps naturally to readiness-based async runtimes. The runtime registers interest, gets notified, borrows a buffer briefly for the syscall, and returns it immediately. Rust's `mio`, Go's `netpoller`, and Python's `selectors` all follow this model.

**Proactor pattern** (io_uring/IOCP): Requires the runtime to manage buffer lifetimes across async boundaries. The buffer must be alive and stable from submit to complete. This creates tension with:
- Move semantics (buffer must not move in memory).
- Cancellation (buffer is still in-flight even if the task is cancelled).
- Memory efficiency (buffers may be idle-but-reserved for long-duration operations).

The "universal" approach taken by Tokio (Rust) and similar runtimes: maintain a readiness-based API surface (`AsyncRead`/`AsyncWrite` with caller-provided buffers) but implement it on top of io_uring by doing an internal copy from kernel-owned buffers to caller-provided buffers. This is safe but sacrifices zero-copy. True zero-copy requires a completion-oriented API surface where the caller relinquishes buffer ownership at submission time.

---

## 2. epoll (Linux)

### Core API

epoll (introduced in Linux 2.5.44, 2002) is a readiness notification mechanism that scales to large numbers of file descriptors.

#### epoll_create

```c
int epoll_create1(int flags);
```

Creates an epoll instance and returns a file descriptor. The `EPOLL_CLOEXEC` flag sets close-on-exec. The original `epoll_create(int size)` is deprecated; `size` was a hint that is now ignored.

The returned fd is itself pollable, enabling epoll-of-epoll composition.

#### epoll_ctl

```c
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
```

Modifies the interest set of an epoll instance:
- `EPOLL_CTL_ADD`: Register a new fd.
- `EPOLL_CTL_MOD`: Change the events monitored for an fd.
- `EPOLL_CTL_DEL`: Remove an fd.

The `epoll_event` structure:

```c
struct epoll_event {
    uint32_t events;    // Bitmask of event types
    epoll_data_t data;  // User data (union of ptr, fd, u32, u64)
};
```

Event flags:

| Flag | Direction | Description |
|------|-----------|-------------|
| `EPOLLIN` | In/Out | Ready for read |
| `EPOLLOUT` | In/Out | Ready for write |
| `EPOLLRDHUP` | In/Out | Peer closed connection (half-close detection) |
| `EPOLLPRI` | In/Out | Exceptional condition (e.g., OOB data) |
| `EPOLLERR` | Out only | Error condition on fd |
| `EPOLLHUP` | Out only | Hang up (always reported even if not requested) |
| `EPOLLET` | In only | Enable edge-triggered mode |
| `EPOLLONESHOT` | In only | Disable fd after one event (must re-arm with `EPOLL_CTL_MOD`) |
| `EPOLLEXCLUSIVE` | In only | Exclusive wakeup (avoids thundering herd) |
| `EPOLLWAKEUP` | In only | Prevent system suspend while event is being processed |

#### epoll_wait

```c
int epoll_wait(int epfd, struct epoll_event *events,
               int maxevents, int timeout);
```

Blocks until events are available or timeout expires. Returns the number of ready fds (up to `maxevents`). The `events` array is filled with the events and associated user data for each ready fd.

`epoll_pwait()` and `epoll_pwait2()` add signal mask and nanosecond-precision timeout support.

### Level-Triggered vs Edge-Triggered

**Level-triggered (LT)** -- the default:
- `epoll_wait` returns as long as the condition is true.
- If there is data in a socket buffer, every call to `epoll_wait` will report `EPOLLIN`.
- Safe with blocking fds. Equivalent semantics to `poll()`.
- Simpler to use: no risk of missing events.

**Edge-triggered (ET)** -- enabled with `EPOLLET`:
- `epoll_wait` returns only when the state *changes* (transitions from not-ready to ready).
- If data arrives and the application reads only part of it, `epoll_wait` will NOT re-report `EPOLLIN` until *new* data arrives.
- Requires non-blocking fds.
- Requires draining the fd completely (read until `EAGAIN`) on each notification.
- Higher performance: fewer spurious wakeups with multiple threads.
- Risk of starvation: if the application forgets to drain, it will never be notified again.

Edge-triggered is the preferred mode for high-performance servers (nginx, etc.) because:
1. One notification per event transition reduces syscall overhead.
2. Combined with `EPOLLONESHOT` or `EPOLLEXCLUSIVE`, it provides clean multi-threaded fd distribution.

### Readiness Model

epoll tells you *when* you can perform IO, not *that* IO has been performed. The flow:

```
1. epoll_ctl(ADD, fd, EPOLLIN)       // register interest
2. epoll_wait(...)                    // block until ready
3. read(fd, buf, len)                 // do the actual IO (separate syscall)
4. goto 2
```

This means:
- The application manages its own buffers and IO calls.
- Buffer lifetime is trivial: you own it before, during, and after the read().
- Each "IO" costs at minimum 2 syscalls: one for `epoll_wait`, one for `read`/`write`.
- Short reads/writes are common and must be handled.
- Multiple events can be batched in a single `epoll_wait` return, but each still requires its own IO syscall.

### Performance Characteristics

- O(1) for `epoll_wait` (returns only ready fds, not the entire set).
- O(1) for `epoll_ctl` add/modify/delete.
- Kernel maintains an internal red-black tree of monitored fds.
- The ready list is maintained via callbacks registered in the fd's wait queue.
- `epoll_wait` simply checks and drains the ready list.

Comparison with predecessors:
- `select`: O(n) scan, limited to `FD_SETSIZE` (typically 1024) fds, copies bitmasks on every call.
- `poll`: O(n) scan, no fd limit, copies `pollfd` array on every call.
- `epoll`: O(1) per event, no fd limit, kernel-maintained state (no per-call copying).

---

## 3. kqueue (BSD/macOS)

### Core API

kqueue (introduced in FreeBSD 4.1, 2000) is BSD's event notification system. Unlike epoll's three-syscall design, kqueue uses just two syscalls.

#### kqueue()

```c
int kqueue(void);
```

Creates a new kernel event queue and returns a descriptor. Like epoll, the returned fd is itself pollable.

#### kevent()

```c
int kevent(int kq,
           const struct kevent *changelist, int nchanges,
           struct kevent *eventlist, int nevents,
           const struct timespec *timeout);
```

A single call that both modifies the interest set AND retrieves events:
- `changelist` / `nchanges`: Array of changes to apply (register/modify/delete).
- `eventlist` / `nevents`: Array to receive triggered events.
- Both can be specified simultaneously: changes are applied before events are retrieved.

This is a fundamental design advantage over epoll: registration and polling are a single atomic syscall, eliminating the TOCTOU window between `epoll_ctl` and `epoll_wait`.

### The kevent Structure

```c
struct kevent {
    uintptr_t  ident;       // Identifier (fd, pid, signal number, etc.)
    int16_t    filter;      // Event filter type
    uint16_t   flags;       // Action flags
    uint32_t   fflags;      // Filter-specific flags
    intptr_t   data;        // Filter-specific data
    void       *udata;      // Opaque user data (passed through unchanged)
};
```

A kevent is uniquely identified by the `(ident, filter)` tuple. There can be only one kevent per `(ident, filter)` pair per kqueue.

### Action Flags

| Flag | Description |
|------|-------------|
| `EV_ADD` | Add event to kqueue (or modify existing) |
| `EV_DELETE` | Remove event from kqueue |
| `EV_ENABLE` | Re-enable a disabled event |
| `EV_DISABLE` | Disable event (do not report, but keep registered) |
| `EV_ONESHOT` | Report only once, then auto-delete |
| `EV_CLEAR` | Reset event state after retrieval (edge-triggered semantics) |
| `EV_EOF` | Indicates end-of-file condition |
| `EV_ERROR` | Error condition on this kevent |
| `EV_DISPATCH` | Disable event after reporting (must re-enable manually) |
| `EV_RECEIPT` | Return receipt for changelist entries (for error checking) |

### Event Filters

kqueue's filters are its most distinctive feature. Where epoll monitors only file descriptors, kqueue can monitor diverse kernel objects through a unified interface:

#### IO Filters

| Filter | ident | data | Description |
|--------|-------|------|-------------|
| `EVFILT_READ` | fd | Bytes available | Ready to read; for listening sockets, reports pending connections |
| `EVFILT_WRITE` | fd | Space available in write buffer | Ready to write without blocking |

#### Process Filters

| Filter | ident | fflags | Description |
|--------|-------|--------|-------------|
| `EVFILT_PROC` | pid | `NOTE_EXIT`, `NOTE_FORK`, `NOTE_EXEC`, `NOTE_TRACK` | Process state changes |

#### File System Filters

| Filter | ident | fflags | Description |
|--------|-------|--------|-------------|
| `EVFILT_VNODE` | fd | `NOTE_DELETE`, `NOTE_WRITE`, `NOTE_EXTEND`, `NOTE_ATTRIB`, `NOTE_LINK`, `NOTE_RENAME`, `NOTE_REVOKE` | File/directory changes (similar to inotify on Linux) |

#### Signal Filters

| Filter | ident | data | Description |
|--------|-------|------|-------------|
| `EVFILT_SIGNAL` | signal number | Times delivered | Signal delivery; coexists with signal()/sigaction() |

#### Timer Filters

| Filter | ident | data | Description |
|--------|-------|------|-------------|
| `EVFILT_TIMER` | arbitrary ID | Timeout value | Timer events; supports nanosecond precision via `NOTE_NSECONDS` |

#### Other Filters

| Filter | ident | Description |
|--------|-------|-------------|
| `EVFILT_AIO` | (aio request) | POSIX AIO completion notification |
| `EVFILT_USER` | arbitrary ID | User-triggered event (for inter-thread signaling) |
| `EVFILT_MACHPORT` | Mach port | macOS-specific: Mach port message arrival |
| `EVFILT_EXCEPT` | fd | macOS-specific: exceptional conditions |

### Comparison with epoll

| Aspect | epoll | kqueue |
|--------|-------|--------|
| Syscalls | 3 (create, ctl, wait) | 2 (kqueue, kevent) |
| Registration + wait | Separate calls | Single atomic call |
| Batch modifications | One fd per `epoll_ctl` | Array of changes per `kevent` |
| Event scope | File descriptors only | FDs, processes, signals, timers, vnodes, user events |
| Triggering | LT (default), ET (`EPOLLET`) | LT (default), ET-like (`EV_CLEAR`) |
| Event identity | fd (single event per fd) | (ident, filter) tuple (multiple filters per fd) |
| Oneshot | `EPOLLONESHOT` (must re-add) | `EV_ONESHOT` (auto-deletes) or `EV_DISPATCH` (disables, re-enable) |
| Thundering herd | `EPOLLEXCLUSIVE` (kernel 4.5+) | `EV_DISPATCH` patterns |
| Portability | Linux only | FreeBSD, macOS, NetBSD, OpenBSD, DragonFlyBSD |
| Availability | Since kernel 2.5.44 (2002) | Since FreeBSD 4.1 (2000) |

kqueue's design is generally considered more elegant:
- Unified event model (not just fds).
- Atomic register-and-wait.
- The (ident, filter) pair allows monitoring the same fd for read and write independently with different udata.
- Batch modification reduces syscall count.

epoll's advantages:
- Dominant Linux ecosystem support.
- `EPOLLEXCLUSIVE` for scalable multi-threaded accept.
- Simpler mental model for fd-only use cases.

Both are fundamentally readiness-based. kqueue has a partial completion-based capability via `EVFILT_AIO`, but this relies on POSIX AIO which has its own limitations.

---

## 4. IOCP (Windows)

### Core API

I/O Completion Ports (IOCP) is Windows' native asynchronous IO mechanism, introduced in Windows NT 3.5 (1994). It is fundamentally completion-based (the Proactor pattern) and was a significant influence on io_uring's design two decades later.

#### CreateIoCompletionPort

```c
HANDLE CreateIoCompletionPort(
    HANDLE    FileHandle,           // Handle to associate (or INVALID_HANDLE_VALUE to create)
    HANDLE    ExistingCompletionPort, // Existing port (or NULL to create new)
    ULONG_PTR CompletionKey,        // Per-handle user data
    DWORD     NumberOfConcurrentThreads // Max runnable threads (0 = CPU count)
);
```

Dual-purpose function:
1. **Create**: Pass `INVALID_HANDLE_VALUE` + `NULL` to create a new port.
2. **Associate**: Pass a file handle + existing port to associate them.

The `CompletionKey` is per-handle (not per-operation). It accompanies every completion for that handle, allowing the application to identify which handle completed without a lookup.

`NumberOfConcurrentThreads` controls how many threads can be simultaneously runnable processing completions. This is a unique IOCP feature: the kernel itself manages thread pool concurrency, blocking excess threads when the limit is reached and unblocking them when active threads block.

#### Overlapped IO Model

All async IO in Windows uses the `OVERLAPPED` structure:

```c
typedef struct _OVERLAPPED {
    ULONG_PTR Internal;      // Status (used by kernel)
    ULONG_PTR InternalHigh;  // Bytes transferred (used by kernel)
    union {
        struct {
            DWORD Offset;       // File offset low
            DWORD OffsetHigh;   // File offset high
        };
        PVOID Pointer;
    };
    HANDLE hEvent;           // Optional event handle
} OVERLAPPED;
```

IO operations (ReadFile, WriteFile, WSARecv, WSASend) take a pointer to an `OVERLAPPED` structure. If the operation completes immediately, data is available immediately. If it would block, the function returns `ERROR_IO_PENDING` and the completion is posted to the IOCP.

The per-IO-data pattern: applications extend `OVERLAPPED` by embedding it as the first member of a larger struct containing per-operation context:

```c
typedef struct {
    OVERLAPPED  overlapped;     // Must be first
    WSABUF      wsa_buf;
    int         operation_type; // Application-specific
    void       *context;        // Application-specific
} PER_IO_DATA;
```

When `GetQueuedCompletionStatus` returns the `OVERLAPPED*`, the application casts it back to `PER_IO_DATA*` to recover the context. This pattern is the direct ancestor of io_uring's `user_data` field.

#### GetQueuedCompletionStatus

```c
BOOL GetQueuedCompletionStatus(
    HANDLE       CompletionPort,
    LPDWORD      lpNumberOfBytes,
    PULONG_PTR   lpCompletionKey,     // Per-handle key
    LPOVERLAPPED *lpOverlapped,       // Per-operation context
    DWORD        dwMilliseconds       // Timeout
);
```

Dequeues one completion packet. The thread blocks until a completion is available or timeout expires.

`GetQueuedCompletionStatusEx` retrieves multiple completions in one call (batching), analogous to `io_uring_peek_batch_cqe`.

Thread ordering: threads waiting on the port form a LIFO stack. When a completion arrives, the most-recently-blocked thread is woken. This improves cache locality (the thread that most recently ran is most likely to have warm caches).

#### Socket Operations

For network IO, Winsock provides overlapped variants:

```c
int WSARecv(SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount,
            LPDWORD lpNumberOfBytesRecvd, LPDWORD lpFlags,
            LPWSAOVERLAPPED lpOverlapped, /* ... */);

int WSASend(SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount,
            LPDWORD lpNumberOfBytesSent, DWORD dwFlags,
            LPWSAOVERLAPPED lpOverlapped, /* ... */);
```

These return immediately. When the operation completes, a packet is posted to the associated IOCP.

`AcceptEx` and `ConnectEx` provide overlapped accept/connect, analogous to io_uring's `IORING_OP_ACCEPT` / `IORING_OP_CONNECT`.

### The Proactor Pattern

IOCP implements the Proactor pattern:
1. **Initiator**: Application starts an async operation (e.g., `WSARecv` with `OVERLAPPED`).
2. **Asynchronous Operation Processor**: The OS kernel performs the IO.
3. **Completion Dispatcher**: The IOCP queues the completion.
4. **Completion Handler**: Application thread retrieves completion via `GetQueuedCompletionStatus`.

Contrast with the Reactor pattern (epoll/kqueue):
1. **Synchronous Event Demultiplexer**: `epoll_wait` blocks until ready.
2. **Event Handler**: Application performs the IO itself.

### How IOCP Influenced io_uring

| IOCP Concept | io_uring Equivalent |
|-------------|---------------------|
| `OVERLAPPED` + per-IO context struct | `user_data` field in SQE/CQE |
| `CompletionKey` (per-handle) | Fixed file index + user_data convention |
| `GetQueuedCompletionStatus` (dequeue completion) | CQ ring consumption |
| `GetQueuedCompletionStatusEx` (batch dequeue) | CQ ring allows draining multiple CQEs |
| `PostQueuedCompletionStatus` (manual post) | `IORING_OP_MSG_RING` |
| Overlapped IO (kernel performs IO) | Completion-based model with kernel doing IO |
| `NumberOfConcurrentThreads` | No direct equivalent (user-space responsibility) |
| `OVERLAPPED.hEvent` for non-IOCP notification | `io_uring_register(IORING_REGISTER_EVENTFD)` |

io_uring improves on IOCP in several ways:
- Shared-memory ring buffers eliminate per-operation syscalls entirely.
- SQPOLL eliminates even submission syscalls.
- Batch submission (not just batch completion).
- Linked operations for compound IO without round-trips.
- Provided buffer rings for kernel-side buffer management.
- Fixed resources for amortized setup costs.

---

## 5. libuv (Node.js)

### Overview

libuv is a cross-platform asynchronous IO library originally developed for Node.js. It provides a unified API over epoll (Linux), kqueue (macOS/BSD), event ports (Solaris), and IOCP (Windows).

### Event Loop (uv_loop_t)

The event loop is the central object. Each loop is single-threaded and drives all IO:

```c
uv_loop_t *loop = uv_default_loop();   // or uv_loop_init() for custom
uv_run(loop, UV_RUN_DEFAULT);           // run until no active handles
uv_loop_close(loop);
```

Run modes:
- `UV_RUN_DEFAULT`: Run until there are no more active handles or requests.
- `UV_RUN_ONCE`: Poll for IO once, execute callbacks for completed IO, return.
- `UV_RUN_NOWAIT`: Poll for IO without blocking, execute callbacks, return.

Each iteration of the event loop follows a specific phase order:
1. **Timers**: Execute expired timer callbacks.
2. **Pending callbacks**: Execute IO callbacks deferred from the previous iteration.
3. **Idle handlers**: `uv_idle_t` callbacks (run every iteration).
4. **Prepare handlers**: `uv_prepare_t` callbacks (run before polling).
5. **IO Poll**: Block on epoll_wait/kevent/GQCS for IO events.
6. **Check handlers**: `uv_check_t` callbacks (run after polling).
7. **Close callbacks**: Execute callbacks for handles closed with `uv_close()`.

### Handle Hierarchy

Handles are long-lived objects. The type hierarchy uses C struct embedding (the "base class" struct is the first member):

```
uv_handle_t (base)
 +-- uv_stream_t (abstract duplex stream)
 |    +-- uv_tcp_t     (TCP socket)
 |    +-- uv_pipe_t    (Unix domain socket / Windows named pipe)
 |    +-- uv_tty_t     (Terminal)
 +-- uv_udp_t          (UDP socket)
 +-- uv_poll_t         (External fd polling)
 +-- uv_timer_t        (Timer)
 +-- uv_prepare_t      (Pre-poll hook)
 +-- uv_check_t        (Post-poll hook)
 +-- uv_idle_t         (Every-iteration hook)
 +-- uv_async_t        (Cross-thread wakeup)
 +-- uv_process_t      (Child process)
 +-- uv_fs_event_t     (File system change notification)
 +-- uv_fs_poll_t      (File system stat polling)
 +-- uv_signal_t       (Signal handler)
```

Any handle can be cast to `uv_handle_t*`. Common operations: `uv_close(handle, callback)`, `uv_is_active(handle)`, `uv_ref(handle)` / `uv_unref(handle)`.

### Request Types (uv_req_t)

Requests are short-lived objects representing a single IO operation:

```
uv_req_t (base)
 +-- uv_write_t        (Stream write)
 +-- uv_connect_t      (TCP/pipe connect)
 +-- uv_shutdown_t     (Stream shutdown)
 +-- uv_udp_send_t     (UDP send)
 +-- uv_fs_t           (File system operation)
 +-- uv_work_t         (Thread pool work)
 +-- uv_getaddrinfo_t  (DNS resolution)
 +-- uv_getnameinfo_t  (Reverse DNS)
```

The handle vs request distinction is fundamental:
- **Handle**: Long-lived, represents an IO resource (socket, timer, process). Has an active/inactive lifecycle.
- **Request**: Short-lived, represents a single operation on a handle. Allocated per-operation, freed after callback.

### Stream Operations

#### uv_read_start / uv_read_stop

```c
int uv_read_start(uv_stream_t *stream,
                  uv_alloc_cb alloc_cb,
                  uv_read_cb read_cb);
```

Starts continuously reading from a stream. The `alloc_cb` is called BEFORE each read to supply a buffer:

```c
void alloc_cb(uv_handle_t *handle, size_t suggested_size, uv_buf_t *buf) {
    buf->base = malloc(suggested_size);
    buf->len = suggested_size;
}

void read_cb(uv_stream_t *stream, ssize_t nread, const uv_buf_t *buf) {
    if (nread > 0) { /* process data */ }
    if (nread < 0) { /* error or EOF */ }
    free(buf->base);
}
```

This callback-based buffer allocation is libuv's answer to the buffer ownership problem: the allocation is deferred until the moment data is actually available (readiness-based underneath), so buffers are not held idle.

#### uv_write

```c
int uv_write(uv_write_t *req, uv_stream_t *handle,
             const uv_buf_t bufs[], unsigned int nbufs,
             uv_write_cb cb);
```

Queues a write. The `uv_write_t` request must remain valid until the callback fires. Multiple writes can be queued; they are serialized in order.

The caller must not modify or free the buffers until the write callback is invoked.

### File System Operations (uv_fs_*)

```c
// Async (callback):
int uv_fs_open(uv_loop_t *loop, uv_fs_t *req, const char *path,
               int flags, int mode, uv_fs_cb cb);
int uv_fs_read(uv_loop_t *loop, uv_fs_t *req, uv_file file,
               const uv_buf_t bufs[], unsigned int nbufs,
               int64_t offset, uv_fs_cb cb);
int uv_fs_write(uv_loop_t *loop, uv_fs_t *req, uv_file file,
                const uv_buf_t bufs[], unsigned int nbufs,
                int64_t offset, uv_fs_cb cb);
int uv_fs_close(uv_loop_t *loop, uv_fs_t *req, uv_file file, uv_fs_cb cb);

// Sync (cb = NULL):
uv_fs_open(loop, &req, path, flags, mode, NULL);  // blocks
int result = req.result;
uv_fs_req_cleanup(&req);
```

Crucially, file system operations are NOT handled by epoll/kqueue/IOCP for the IO poll. Instead, libuv runs them on a **thread pool**:

The rationale: POSIX does not provide usable async file IO primitives. `O_NONBLOCK` on regular files is a no-op (reads block on disk IO regardless). POSIX AIO (`aio_read`, etc.) has severe limitations. Linux's io_uring changes this, but libuv predates it and still uses the thread pool approach.

Thread pool details:
- Default size: 4 threads.
- Configurable via `UV_THREADPOOL_SIZE` environment variable (max 1024).
- Shared across all loops in the process.
- Used for: all `uv_fs_*` operations, DNS resolution (`uv_getaddrinfo`), and custom work (`uv_queue_work`).

### How libuv Abstracts Platform Differences

| Subsystem | Linux | macOS/BSD | Windows |
|-----------|-------|-----------|---------|
| Network IO polling | epoll | kqueue | IOCP |
| File IO | Thread pool | Thread pool | Thread pool (despite IOCP supporting file IO) |
| DNS | Thread pool (getaddrinfo) | Thread pool | Thread pool |
| Child process | fork/exec + SIGCHLD | fork/exec + kqueue EVFILT_PROC | CreateProcess + Job Objects |
| Signals | signalfd or self-pipe | kqueue EVFILT_SIGNAL | Not natively supported (emulated) |
| File watching | inotify | kqueue EVFILT_VNODE | ReadDirectoryChangesW |
| Pipes | Unix domain sockets | Unix domain sockets | Named pipes |
| TTY | termios + VT escape | termios + VT escape | Console API |

The abstraction cost: libuv forces a readiness-based API even on Windows (which natively provides completion-based IOCP). On Windows, libuv uses IOCP internally but exposes it through `uv_read_start` callbacks, effectively converting the proactor into a reactor at the API boundary. Similarly, libuv does not currently use io_uring, maintaining the thread pool for file IO on Linux.

---

## 6. Cross-Cutting Patterns

### 6.1 Event Loop as Central Concept

Every system organizes around a central dispatch loop:

| System | Loop Primitive | Blocking Call |
|--------|---------------|---------------|
| select | User-written loop | `select()` |
| poll | User-written loop | `poll()` |
| epoll | User-written loop | `epoll_wait()` |
| kqueue | User-written loop | `kevent()` |
| IOCP | User-written loop | `GetQueuedCompletionStatus()` |
| io_uring | User-written loop | `io_uring_enter()` (or no call with SQPOLL) |
| libuv | `uv_run()` | Internal (delegates to platform) |

The loop shape is universal: block for events, dispatch callbacks/handlers, repeat. The differences are in what "events" mean (readiness vs completion) and how IO is performed relative to the notification.

### 6.2 Readiness vs Completion Models

```
                      Readiness                    Completion
                   (Reactor Pattern)            (Proactor Pattern)
                   ================            ==================

  Register:      "Tell me when fd            "Here is my buffer;
                  is ready to read"           perform the read for me"

  Notification:  "fd is ready"               "Read is done; here
                                              are the bytes"

  IO Performed:  By application              By kernel
                 (read syscall)              (internally)

  Buffer:        Provided at IO time;        Provided at submission;
                 owned by app always         owned by kernel until done

  Cancellation:  Trivial (just don't read)   Must wait for kernel to
                                              release buffer

  Systems:       select, poll, epoll,        IOCP, io_uring,
                 kqueue                      POSIX AIO

  Syscalls/IO:   2+ (wait + read)            1 amortized (batch submit)
```

The completion model has strictly better performance characteristics (fewer syscalls, kernel can optimize scheduling) but strictly harder safety properties (buffer lifetime management, cancellation). This is the fundamental tension in IO API design.

### 6.3 File Descriptor / Handle as Universal IO Token

Every system represents IO endpoints as an opaque integer token:

| System | Token Type | Scope |
|--------|-----------|-------|
| POSIX | `int fd` | Per-process file descriptor table |
| Windows | `HANDLE` | Per-process handle table |
| io_uring | `int fd` or fixed file index | Per-process or per-ring |
| libuv | `uv_os_fd_t` (typedef to int/HANDLE) | Abstracted |

The token is the unit of registration (what you monitor), operation (what you read/write), and lifecycle (what you close). All cross-platform abstractions must bridge between fd and HANDLE semantics.

io_uring's fixed file indices are notable: they introduce a ring-local "file descriptor table" that decouples the IO namespace from the process fd table, enabling pre-registration and reducing kernel overhead.

### 6.4 Buffer Ownership and Lifetime Management

| System | Buffer Ownership Model |
|--------|----------------------|
| epoll + read() | App owns always. Provides buffer at read() time. |
| kqueue + read() | Same as epoll. |
| IOCP | App provides buffer at submission. Kernel owns until completion. App must not touch buffer until `GetQueuedCompletionStatus` returns. |
| io_uring (regular) | Same as IOCP. Buffer provided in SQE, kernel owns until CQE. |
| io_uring (provided buffers) | App provides buffer pool. Kernel selects buffer at completion time. Selected buffer ID returned in CQE. |
| io_uring (buffer rings) | App maintains shared ring of buffers. Kernel consumes from head. App replenishes at tail. No SQE needed. |
| libuv | App provides buffer via `alloc_cb` at read time (readiness-based). App owns buffer before and after callback. |

The progression from IOCP to io_uring shows an evolution in buffer management:
1. IOCP: One buffer per operation, app manages.
2. io_uring v1: Same as IOCP, but batched submission.
3. io_uring provided buffers: Kernel selects from app-provided pool.
4. io_uring buffer rings: Shared ring for zero-overhead buffer recycling.
5. io_uring incremental consumption: Partial buffer usage for streaming.

### 6.5 Batching and Amortized Syscall Costs

| System | Submission Batching | Completion Batching |
|--------|-------------------|-------------------|
| select/poll | N/A (single call does everything) | Returns all ready fds |
| epoll | One `epoll_ctl` per fd change | `epoll_wait` returns multiple events |
| kqueue | `kevent` changelist array | `kevent` eventlist array |
| IOCP | One overlapped call per IO | `GetQueuedCompletionStatusEx` returns multiple |
| io_uring | Multiple SQEs per `io_uring_enter` (or zero syscalls with SQPOLL) | Multiple CQEs per ring drain |
| libuv | Abstracted | Abstracted |

io_uring represents the theoretical optimum: with SQPOLL + fixed resources, the steady-state syscall count is **zero**. All communication happens through shared memory.

### 6.6 The Progression: select -> poll -> epoll/kqueue -> io_uring

| Generation | System | Year | Model | Scaling | Syscalls/IO | Key Innovation |
|-----------|--------|------|-------|---------|-------------|----------------|
| 1st | select | 1983 (4.2BSD) | Readiness | O(n) scan, FD_SETSIZE limit | 2 | First multiplexer |
| 1st | poll | 1986 (SVR3) | Readiness | O(n) scan, no fd limit | 2 | Removed fd limit |
| 2nd | kqueue | 2000 (FreeBSD 4.1) | Readiness | O(1) per event | 2 (single kevent call) | Unified event model, batch register+wait |
| 2nd | epoll | 2002 (Linux 2.5.44) | Readiness | O(1) per event | 2 (ctl + wait) | Kernel-maintained state |
| 2nd | IOCP | 1994 (NT 3.5) | Completion | O(1) per event | 1 per IO | Completion-based, kernel does IO |
| 3rd | io_uring | 2019 (Linux 5.1) | Completion | O(1) per event | 0-1 amortized | Shared-memory rings, SQPOLL, batching, fixed resources, provided buffers, multishot |

The trajectory:
1. **Reduce scanning**: select/poll scan all fds. epoll/kqueue use callbacks and ready lists.
2. **Reduce syscalls**: kqueue batches registration+wait. io_uring batches submission. SQPOLL eliminates syscalls entirely.
3. **Reduce copies**: io_uring uses shared memory rings. Fixed buffers avoid page pinning per-IO.
4. **Move work to kernel**: Completion-based models (IOCP, io_uring) let the kernel perform IO directly, eliminating the user-space read()/write() step.
5. **Move buffer management to kernel**: Provided buffer rings let the kernel select and manage buffers without any per-IO user-space involvement.

Each generation eliminates a category of overhead while introducing new complexity in buffer and lifetime management. The direction is clear: more kernel autonomy, fewer user-kernel transitions, shared-memory communication.

---

## Sources

### io_uring
- [Efficient IO with io_uring (Jens Axboe)](https://kernel.dk/io_uring.pdf)
- [io_uring(7) Linux man page](https://man7.org/linux/man-pages/man7/io_uring.7.html)
- [io_uring_setup(2) Linux man page](https://man7.org/linux/man-pages/man2/io_uring_setup.2.html)
- [io_uring_enter(2) Linux man page](https://man7.org/linux/man-pages/man2/io_uring_enter.2.html)
- [io_uring_register(2) Linux man page](https://man7.org/linux/man-pages/man2/io_uring_register.2.html)
- [Lord of the io_uring documentation](https://unixism.net/loti/what_is_io_uring.html)
- [io_uring and networking in 2023 (liburing wiki)](https://github.com/axboe/liburing/wiki/io_uring-and-networking-in-2023)
- [What's new with io_uring in 6.11 and 6.12](https://github.com/axboe/liburing/wiki/What's-new-with-io_uring-in-6.11-and-6.12)
- [Linux kernel source: io_uring.h](https://github.com/torvalds/linux/blob/master/include/uapi/linux/io_uring.h)
- [Why you should use io_uring for network I/O (Red Hat)](https://developers.redhat.com/articles/2023/04/12/why-you-should-use-iouring-network-io)
- [Notes on io-uring (boats)](https://boats.gitlab.io/blog/post/io-uring/)
- [A Programmer-Friendly I/O Abstraction Over io_uring and kqueue (TigerBeetle)](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/)
- [Notes on epoll and io_uring (Ian Fisher)](https://iafisher.com/notes/2025/10/epoll-io-uring)
- [io_uring for High-Performance DBMSs (arXiv)](https://arxiv.org/html/2512.04859v2)

### epoll
- [epoll(7) Linux man page](https://man7.org/linux/man-pages/man7/epoll.7.html)
- [epoll_ctl(2) Linux man page](https://man7.org/linux/man-pages/man2/epoll_ctl.2.html)
- [The method to epoll's madness](https://copyconstruct.medium.com/the-method-to-epolls-madness-d9d2d6378642)
- [I/O Multiplexing: select vs poll vs epoll/kqueue](https://nima101.github.io/io_multiplexing)

### kqueue
- [kqueue(2) OpenBSD man page](https://man.openbsd.org/kqueue.2)
- [kqueue(2) FreeBSD man page](https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2)
- [kqueue(2) macOS man page](https://keith.github.io/xcode-man-pages/kqueue.2.html)
- [kqueue tutorial (NetBSD)](https://wiki.netbsd.org/tutorials/kqueue_tutorial/)
- [Kernel Queue: Complete Guide (Habr)](https://habr.com/en/articles/600123/)
- [Scalable Event Multiplexing: epoll vs. kqueue](https://long-zhou.github.io/2012/12/21/epoll-vs-kqueue.html)

### IOCP
- [I/O Completion Ports (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports)
- [CreateIoCompletionPort (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/fileio/createiocompletionport)
- [GetQueuedCompletionStatus (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-getqueuedcompletionstatus)
- [IO Completion Ports (Matt Godbolt)](https://xania.org/200807/iocp)

### libuv
- [libuv Design Overview](https://docs.libuv.org/en/v1.x/design.html)
- [libuv uv_loop_t documentation](https://docs.libuv.org/en/v1.x/loop.html)
- [libuv uv_handle_t documentation](https://docs.libuv.org/en/v1.x/handle.html)
- [libuv uv_stream_t documentation](https://docs.libuv.org/en/v1.x/stream.html)
- [libuv uv_req_t documentation](https://docs.libuv.org/en/v1.x/request.html)
- [libuv File System Operations](https://docs.libuv.org/en/v1.x/fs.html)
- [libuv Thread Pool](https://docs.libuv.org/en/v1.x/threadpool.html)

### Patterns and History
- [Reactor pattern (Wikipedia)](https://en.wikipedia.org/wiki/Reactor_pattern)
- [Proactor pattern (Wikipedia)](https://en.wikipedia.org/wiki/Proactor_pattern)
- [Comparing Two High-Performance I/O Design Patterns (Artima)](https://www.artima.com/articles/io_design_patterns.html)
- [Reactor vs Proactor: Readiness vs Completion Driven I/O](https://www.systemoverflow.com/learn/os-systems-fundamentals/io-models/reactor-vs-proactor-readiness-vs-completion-driven-io)

---

## Haskell, Theory, and SwiftNIO


---

## Part I: Haskell

### 1. The IO Monad

#### `IO a` — How Haskell Models Side Effects

Haskell's `IO a` type represents a computation that, when performed, may interact with the outside world and eventually produces a value of type `a`. The key insight is that `IO` values are *descriptions* of side effects, not the effects themselves. A value of type `IO String` does not contain a string — it describes a recipe for obtaining one.

```haskell
-- IO a is conceptually: RealWorld -> (a, RealWorld)
-- The "world-passing" semantics ensure sequencing
main :: IO ()
main = do
    name <- getLine        -- IO String
    putStrLn ("Hello, " ++ name)  -- IO ()
```

The `IO` monad's bind (`>>=`) chains effects sequentially: the second action cannot begin until the first completes and produces a value. This is the mechanism that imposes ordering on side effects in a language with lazy evaluation.

**Crucial property**: `IO` is a *black box* — there is no `runIO` function in user code. Only `main :: IO ()` gets executed by the runtime. This makes `IO` a coarse-grained effect boundary: once something is `IO`, everything upstream must also be `IO`. There is no escape hatch (except `unsafePerformIO`, which is explicitly unsafe).

#### `Handle` — File Handles

Haskell's `System.IO` provides `Handle` as the type-safe wrapper around operating system file descriptors:

```haskell
data Handle  -- abstract, opaque type

stdin, stdout, stderr :: Handle

-- Opening files produces handles
openFile :: FilePath -> IOMode -> IO Handle
data IOMode = ReadMode | WriteMode | AppendMode | ReadWriteMode

-- Handles must be explicitly closed
hClose :: Handle -> IO ()

-- Safe bracket pattern
withFile :: FilePath -> IOMode -> (Handle -> IO r) -> IO r
```

`Handle` is a mutable reference to an OS resource. It tracks:
- The file descriptor
- The buffering mode (`NoBuffering`, `LineBuffering`, `BlockBuffering`)
- The text encoding (`hSetEncoding`)
- Whether the handle is open or closed (runtime check, not type-level)

**Design observation**: `Handle` is *not* parameterized by its mode. A `Handle` opened in `ReadMode` has the same type as one opened in `WriteMode`. Writing to a read-only handle is a runtime error, not a type error. This is a well-known design limitation.

#### `hGetContents`, `hPutStr` — Lazy IO and Its Problems

```haskell
hGetContents :: Handle -> IO String
hPutStr :: Handle -> String -> IO ()
```

`hGetContents` returns a lazy list representing the *entire* contents of a file. The handle enters a "semi-closed" state: data is read on demand as the list is traversed. This was Haskell's original approach to streaming — leveraging laziness itself as the streaming mechanism.

**The problems with lazy IO are fundamental**:

1. **Unpredictable resource lifetime**: The handle remains open until the entire string is consumed or garbage collected. You cannot close the handle early — if you do, the unconsumed portion is silently truncated.

    ```haskell
    -- BUG: handle closed before contents consumed
    broken :: IO String
    broken = do
        h <- openFile "data.txt" ReadMode
        contents <- hGetContents h
        hClose h          -- closes before contents are forced
        return contents   -- returns truncated/empty string
    ```

2. **Space leaks**: If the consumer retains a reference to the head of the list while traversing, the entire file ends up in memory — defeating the purpose of streaming.

3. **Interleaved effects**: Because reads happen lazily at unpredictable times, they can interleave with writes or other IO actions in surprising ways. The order of side effects becomes dependent on evaluation order.

4. **Exception timing**: IO errors (encoding failures, disk errors) surface wherever the lazy list happens to be forced, not at the `hGetContents` call site. This makes error handling extremely difficult.

5. **No backpressure**: The consumer controls the pace of reading, but there is no mechanism for the consumer to signal the producer to slow down — backpressure flows only via GC pressure, which is unpredictable.

These problems led directly to the development of iteratee/enumerator libraries (circa 2009), which evolved into the modern streaming libraries (conduit, pipes, streaming).

#### `System.IO` Basics

The `System.IO` module provides the fundamental primitives:

| Function | Type | Purpose |
|----------|------|---------|
| `openFile` | `FilePath -> IOMode -> IO Handle` | Open a file |
| `hClose` | `Handle -> IO ()` | Close a handle |
| `hGetLine` | `Handle -> IO String` | Read one line (strict) |
| `hPutStr` | `Handle -> String -> IO ()` | Write a string |
| `hFlush` | `Handle -> IO ()` | Flush buffer |
| `hSetBuffering` | `Handle -> BufferMode -> IO ()` | Set buffer strategy |
| `hSetEncoding` | `Handle -> TextEncoding -> IO ()` | Set text encoding |
| `hIsEOF` | `Handle -> IO Bool` | Check for end-of-file |
| `withFile` | `FilePath -> IOMode -> (Handle -> IO r) -> IO r` | Bracket-managed open |

---

### 2. Conduit / Streaming Libraries

#### Conduit — `ConduitT`

Conduit (by Michael Snoyman) is the most widely deployed Haskell streaming library. It provides deterministic resource management and constant-memory processing.

**Core type** (post-1.3.0, 2018):

```haskell
-- ConduitT i o m r
--   i = input type (what is awaited from upstream)
--   o = output type (what is yielded downstream)
--   m = base monad
--   r = final result
newtype ConduitT i o m r = ...

-- Type synonyms for common patterns:
type Source    m o = ConduitT ()   o    m ()   -- produces output, no input
type Sink      i m r = ConduitT i    Void m r    -- consumes input, no output
type Conduit   i m o = ConduitT i    o    m ()   -- transforms input to output
```

**Primitive operations**:

```haskell
await :: ConduitT i o m (Maybe i)  -- receive from upstream (Nothing = upstream done)
yield :: o -> ConduitT i o m ()    -- send downstream
leftover :: i -> ConduitT i o m () -- push back an unconsumed input element
```

**How conduit provides constant-memory streaming**:

The key mechanism is *pull-based execution*. A conduit pipeline is driven by the downstream consumer: it `await`s, which causes the upstream producer to run until it `yield`s. At any moment, only a bounded amount of data exists in memory — typically one element or one chunk.

```haskell
-- Constant-memory file copy
import Conduit

fileCopy :: FilePath -> FilePath -> IO ()
fileCopy src dst = runConduitRes $
    sourceFile src .| sinkFile dst
    -- At most one chunk (typically 32KB) in memory at a time
```

**Composition** uses the `.|` (fuse) operator:

```haskell
(.|) :: Monad m => ConduitT a b m () -> ConduitT b c m r -> ConduitT a c m r
```

**Resource management**: Conduit integrates tightly with `ResourceT`. The `bracketP` combinator provides exception-safe resource acquisition and release within a conduit pipeline:

```haskell
bracketP :: MonadResource m
         => IO a                    -- acquire
         -> (a -> IO ())            -- release
         -> (a -> ConduitT i o m r) -- use
         -> ConduitT i o m r
```

**Prompt finalization**: When a downstream consumer finishes early (e.g., `take 10`), conduit runs the upstream finalizers immediately — not deferred to the end of the `ResourceT` scope. This is a significant advantage over pipes.

**Internal implementation**: Conduit uses the *codensity transform* internally, which makes left-associated binds (appending) cheap but partially-running-and-capturing-state expensive.

**Leftovers**: A distinctive conduit feature — elements can be "pushed back" onto the input stream. This enables parsing patterns where you read ahead, decide the element belongs to the next stage, and put it back.

#### Pipes — `Producer`, `Consumer`, `Pipe`

Pipes (by Gabriella Gonzalez) emphasizes mathematical elegance and category-theoretic foundations.

**Core type**:

```haskell
data Proxy a' a b' b m r
    = Request a' (a  -> Proxy a' a b' b m r)  -- request from upstream
    | Respond b  (b' -> Proxy a' a b' b m r)  -- respond to downstream
    | M (m (Proxy a' a b' b m r))              -- monadic action
    | Pure r                                    -- done

-- Simplified type synonyms:
type Producer b   m r = Proxy X  () () b m r  -- yields b, no input
type Consumer a   m r = Proxy () a  () X m r  -- awaits a, no output
type Pipe     a b m r = Proxy () a  () b m r  -- transforms a to b
type Effect       m r = Proxy X  () () X m r  -- closed pipeline
```

**Primitive operations**:

```haskell
yield :: b -> Producer b m ()        -- send downstream
await :: Consumer a m a              -- receive from upstream
```

**Composition** forms a `Category`:

```haskell
(>->) :: Monad m => Producer a m r -> Consumer a m r -> Effect m r
-- or more generally for Pipe composition
```

**Key difference from conduit**: Pipes lacks built-in leftovers and has weaker prompt finalization. Finalization in pipes relies on `SafeT`, which defers cleanup to the end of the `SafeT` scope rather than running it immediately when a consumer terminates early.

**Design philosophy**: Pipes prioritizes compositionality and algebraic laws. Every composition operator satisfies the category laws (associativity, identity). This mathematical rigor comes at the cost of practical features like leftovers.

#### `streaming` Library

The `streaming` library (by Michael Thompson) takes a radically different approach:

```haskell
data Stream (f :: * -> *) m r
    = Step !(f (Stream f m r))  -- one layer of the functor
    | Effect (m (Stream f m r)) -- an effectful step
    | Return r                  -- done

-- The common specialization uses Of for element-carrying streams:
data Of a b = !a :> b

type Stream (Of a) m r  -- a stream of 'a' values in monad 'm' yielding 'r'
```

**Key insight**: `streaming` does not define "stream processors" — it defines *streams* directly. A stream transformer is just a function `Stream (Of a) m r -> Stream (Of b) m r'`. This is fundamentally simpler because it reuses ordinary function composition rather than inventing a new composition operator.

**Advantages**:
- No special composition operators needed — ordinary function application works
- Interoperates naturally with existing Haskell abstractions
- `Stream f m` is a monad transformer for any functor `f`

**Disadvantage**: No built-in bidirectionality or leftovers.

#### Comparison: Conduit vs Pipes vs Streaming

| Aspect | Conduit | Pipes | Streaming |
|--------|---------|-------|-----------|
| **Core abstraction** | Stream processors | Stream processors | Streams directly |
| **Composition** | `.\|` (fuse) | `>->` (Category) | Function application |
| **Leftovers** | Yes, built-in | No | No |
| **Prompt finalization** | Yes, built-in | Weak (deferred to `SafeT`) | Via `streaming-bracketed` |
| **Resource management** | `ResourceT` integration | `SafeT` | External via `streaming-with` |
| **Algebraic laws** | Ad hoc | Category laws hold | Functor/monad laws |
| **Ecosystem** | Largest (Yesod, etc.) | Moderate | Small but growing |
| **Complexity** | Moderate (leftovers, finalizers) | Elegant but difficult in practice | Simplest |
| **Performance** | Good | Good | Good |
| **Bidirectional** | No (unidirectional) | Yes (`Proxy` is bidirectional) | No |

**Streamly** deserves mention as a newer entrant: it emphasizes high performance through aggressive concurrency and fusion, benchmarking several orders of magnitude faster than conduit/pipes/streaming in some scenarios.

**Historical trajectory**: Lazy IO -> iteratee/enumerator (2009) -> conduit (2011) / pipes (2012) -> streaming (2015) -> streamly (2017). Each generation addressed limitations of the prior one.

---

### 3. Haskell Network IO

#### `network` Package — `Socket`, `SockAddr`

```haskell
data Socket     -- abstract, wraps a file descriptor
data SockAddr   -- socket address (IPv4, IPv6, Unix domain)
    = SockAddrInet PortNumber HostAddress
    | SockAddrInet6 PortNumber FlowInfo HostAddress6 ScopeID
    | SockAddrUnix String

-- Core operations
socket :: Family -> SocketType -> ProtocolNumber -> IO Socket
bind :: Socket -> SockAddr -> IO ()
listen :: Socket -> Int -> IO ()
accept :: Socket -> IO (Socket, SockAddr)
connect :: Socket -> SockAddr -> IO ()
send :: Socket -> ByteString -> IO Int
recv :: Socket -> Int -> IO ByteString
close :: Socket -> IO ()
```

**Programming model**: One socket per thread. The runtime makes this efficient via the IO manager (below).

#### GHC's IO Manager — epoll/kqueue Integration

GHC's IO manager is the bridge between Haskell's lightweight threading model and the OS kernel's event notification mechanisms.

**Architecture**:

1. When a Haskell thread performs a blocking IO operation (e.g., `recv`), the runtime translates this into a non-blocking call.
2. If the call returns `EAGAIN`/`EWOULDBLOCK`, the thread *registers interest* with the IO manager and suspends.
3. The IO manager runs an event loop using the platform's best multiplexer:
   - **Linux**: `epoll`
   - **macOS/BSD**: `kqueue`
   - **Fallback**: `poll` (poor scaling)
   - **Experimental**: `io_uring` (Linux, under development)
4. When the file descriptor becomes ready, the IO manager wakes the suspended thread.

**The programmer sees none of this**. From the Haskell programmer's perspective, `recv` blocks the green thread. The runtime transparently multiplexes thousands of green threads onto a small number of OS threads (typically one per CPU core), using event-driven IO under the hood.

**MIO** (Multicore IO Manager, 2013): Scaled the IO manager to multicore by partitioning file descriptor interest sets across per-core event loops, eliminating the single-lock bottleneck of the original design.

#### Green Threads

GHC's green threads (created via `forkIO`) are:
- **Lightweight**: ~1KB initial stack, dynamically grown
- **Abundant**: 100K+ concurrent threads are practical if mostly IO-bound
- **M:N scheduled**: Many green threads mapped onto few OS threads (the "capability" scheduler)
- **Preemptively scheduled**: GHC inserts yield points at allocation sites

```haskell
-- Server handling 10,000 concurrent connections
server :: Socket -> IO ()
server sock = forever $ do
    (conn, addr) <- accept sock
    forkIO $ handleClient conn  -- one green thread per client
```

**Key insight**: GHC's approach means Haskell programmers write *synchronous-looking blocking code* while getting *asynchronous non-blocking performance*. This is the same goal that Go's goroutines and Java's Project Loom virtual threads pursue.

---

### 4. Key Haskell Concepts

#### Separating IO Description from IO Execution

The foundational Haskell insight: an `IO a` value is a *description* of an effectful computation, not its execution. This separation enables:

- **Composition before execution**: Build up complex IO plans from simple parts
- **Interpretation**: The same description could theoretically be interpreted differently (though in practice, Haskell's `IO` is always interpreted by the runtime)
- **Reasoning**: Pure functions can manipulate IO descriptions without performing effects

This principle is pushed further by "free monad" encodings, where effects are represented as data structures:

```haskell
data FileOp a
    = ReadFile FilePath (String -> a)
    | WriteFile FilePath String a
    deriving Functor

type FileProgram = Free FileOp

-- Interpret against real filesystem
runReal :: FileProgram a -> IO a

-- Interpret against in-memory map (for testing)
runMock :: Map FilePath String -> FileProgram a -> (a, Map FilePath String)
```

#### Resource Management: `bracket` and `ResourceT`

**`bracket`** is the fundamental exception-safe resource pattern:

```haskell
bracket :: IO a         -- acquire
        -> (a -> IO b)  -- release (always runs, even on exception)
        -> (a -> IO c)  -- use
        -> IO c
```

`bracket` has a structural limitation: resources must be acquired and released in a strictly nested (stack-like) order. You cannot interleave two resources' lifetimes.

**`ResourceT`** generalizes bracket for interleaved and dynamic resource management:

```haskell
type ResourceT m a  -- monad transformer

runResourceT :: MonadUnliftIO m => ResourceT m a -> m a

allocate :: MonadResource m
         => IO a            -- acquire
         -> (a -> IO ())    -- release
         -> m (ReleaseKey, a)

release :: MonadIO m => ReleaseKey -> m ()  -- early release
```

`ResourceT` maintains a mutable map of registered cleanup actions. When `runResourceT` exits (normally or via exception), all registered cleanups run. Resources can also be released early via their `ReleaseKey`.

**Why `ResourceT` exists**: In streaming pipelines, resources must be acquired and released across different stages. `bracket` cannot express "open file A in stage 1, open file B in stage 2, close A when stage 1 is done, close B when stage 2 is done" because the lifetimes interleave. `ResourceT` handles this naturally.

#### The Relationship Between Laziness and Streaming IO

Laziness is both the reason Haskell's original IO story worked and the reason it failed:

**Why it worked initially**: Lazy lists are natural streams. `hGetContents` returns a lazy `String` (list of `Char`), and consuming it element-by-element reads from the file on demand. This is streaming with constant memory — in theory.

**Why it failed in practice**:
1. **No resource bounds**: The handle stays open as long as the lazy list is reachable. GC determines when it closes — nondeterministic.
2. **No error locality**: IO errors are thrown wherever the thunk is forced, not where the IO was "requested."
3. **Space leaks under retention**: If any reference to the head is kept while traversing, the entire file materializes in memory.
4. **Invisible effects**: A pure-looking function `String -> String` might secretly be forcing lazy IO, making the "purity" of non-IO code a lie.

**The fundamental tension**: Laziness lets you express "produce on demand" naturally, but the "demand" is driven by evaluation, which is unpredictable in a lazy language. Streaming libraries replace laziness-driven demand with *explicit protocol-driven demand* (await/yield).

#### Why Haskell Went from Lazy IO to Explicit Streaming

The migration happened because lazy IO violates three principles that production systems require:

1. **Deterministic resource management**: Production code must close file handles and sockets promptly, not when the GC gets around to it.
2. **Predictable memory usage**: Streaming must guarantee bounded memory regardless of input size.
3. **Composable error handling**: Errors must surface at their origin, not at an arbitrary downstream consumption point.

The iteratee pattern (Oleg Kiselyov, 2009) was the first systematic solution. Conduit and pipes refined this into practical libraries. The trend is toward ever-simpler APIs (the `streaming` library) while maintaining the guarantees.

---

## Part II: Academic / Theoretical

### 5. Effect Systems for IO

#### Algebraic Effects (Plotkin & Pretnar)

Algebraic effects, introduced by Plotkin and Power (2003) and extended with *handlers* by Plotkin and Pretnar (2009), provide a modular framework for computational effects.

**Core idea**: An effect is declared as a set of *operations* (abstract interface), and a *handler* provides a concrete interpretation. This separates the description of effects from their implementation — the same principle as Haskell's IO monad, but more fine-grained.

```
-- Pseudocode (Eff-style)
effect State<S> {
    get : () -> S
    put : S -> ()
}

-- A computation using State
program : () -> State<Int> Int
program () =
    let x = get() in
    put(x + 1);
    get()

-- A handler interpreting State via mutation
handler runState<S>(init: S) {
    return x    -> (x, init)
    get()   k   -> k(init)          -- resume with current state
    put(s)  k   -> runState(s)(k()) -- resume with new state
}
```

**Key properties**:

1. **Separation of interface and implementation**: Operations are abstract; handlers give them meaning.
2. **Composability**: Multiple effect interfaces compose without quadratic encoding overhead (unlike monad transformers).
3. **Delimited continuations**: Each operation captures the continuation `k` up to the nearest enclosing handler. The handler decides whether/how to resume.
4. **IO as an effect**: IO operations (read, write, open, close) are just another effect interface. A handler can interpret them against the real filesystem or against an in-memory mock.

**Advantage over monads**: Monad transformers require `O(n^2)` lift instances for `n` effects. Algebraic effects compose directly — adding a new effect does not require modifying existing code.

#### Effect Handlers — How They Compose

Handlers compose by nesting:

```
-- Two independent effects
effect Console { read : () -> String; write : String -> () }
effect FileIO  { open : Path -> Handle; close : Handle -> () }

-- A program using both
program : () -> Console, FileIO ()

-- Handle each independently
result = handleFileIO(handleConsole(program))
-- OR in opposite order:
result = handleConsole(handleFileIO(program))
```

The order of handlers can matter (analogous to monad transformer ordering), but there is no boilerplate to make them compatible.

**Deep vs. shallow handlers**: Deep handlers automatically re-wrap the continuation with the same handler. Shallow handlers handle exactly one operation occurrence and must be explicitly reinstalled. Deep handlers are more common in practice.

#### Frank, Koka, Unison — Languages with First-Class Effects

**Frank** (Lindley, McBride, McLaughlin — "Do Be Do Be Do," 2017):
- Effect types are called "abilities."
- *Ambient ability*: Effects propagate inward rather than accumulating outward. Functions implicitly inherit the ambient ability of their call site.
- Functions are special cases of *operators* — a Frank operator can handle commands from multiple sources simultaneously (multihandlers).
- No separate handler syntax: pattern matching on effect operations is unified with ordinary pattern matching.

**Koka** (Daan Leijen, Microsoft Research):
- Row-polymorphic effect types: Every function's effect signature is inferred and tracked.
- Fine-grained effects: Instead of a monolithic `IO`, Koka distinguishes `console`, `fsys`, `net`, `ndet`, `exn`, `div`, etc.
- Effect handlers as user-defined libraries: Async/await, generators, exceptions — all implemented via handlers, not built into the compiler.
- Perceus reference counting: Koka's backend uses precise reference counting with reuse analysis, enabling functional programming with in-place mutation where possible.

```koka
fun hello() : console ()
    println("Hello, world!")

// The type tells you exactly which effects are used
fun readFile(path : string) : <fsys,exn> string
```

**Unison**:
- Effects are called "abilities."
- Abilities are tracked in type signatures: `{IO, Exception} Nat` means a computation requiring IO and Exception abilities.
- The IO ability is the only one handled by the runtime; all others are handled by user-defined handlers.
- Ability handlers enable mock-based testing: replace real IO with a test handler that supplies predetermined values.
- Content-addressed code: Unison's unique storage model (code is stored by hash, not by name) interacts with abilities to enable distributed computation where effect handlers bridge local and remote execution.

#### How This Relates to Swift's Structured Concurrency

Swift's structured concurrency (`async/await`, `TaskGroup`, actors) addresses a subset of what algebraic effects cover:

| Concept | Algebraic Effects | Swift Structured Concurrency |
|---------|-------------------|------------------------------|
| Async operations | Effect + handler | `async`/`await` keywords |
| Cancellation | Effect operation | `Task.isCancelled`, cooperative |
| Structured lifetime | Handler scope | `TaskGroup` / `withThrowingTaskGroup` |
| Isolation | Effect row tracking | Actor isolation, `Sendable` |
| Testability | Mock handler | Dependency injection (manual) |

**Key difference**: Algebraic effects generalize over *all* effects (IO, state, nondeterminism, etc.) with a single mechanism. Swift has separate mechanisms for different concerns: `async/await` for asynchrony, actors for isolation, `throws` for errors, structured concurrency for lifetime. This is more ad-hoc but more pragmatic — each mechanism is optimized for its specific concern.

**Connection**: Both systems enforce *structured scoping*. In algebraic effects, a handler defines a scope; in Swift, a task group defines a scope. Child effects/tasks cannot outlive their parent scope.

---

### 6. Linear Types and IO

#### Clean's Uniqueness Types for IO

Clean (Nijmegen, 1987-present) solved the "how do we do IO in a pure language" problem *without* monads, using uniqueness types.

**Core idea**: A value with a unique type (`*World`, `*File`) is guaranteed to have exactly one reference. Since no aliasing exists, in-place mutation is safe — the compiler can update the value directly without violating referential transparency.

```clean
// Clean: *World is the unique world value
Start :: *World -> *World
Start world
    # (console, world) = stdio world       // world consumed, new world produced
    # console = fwrites "Hello\n" console   // console consumed, new console produced
    # (_, world) = fclose console world     // console consumed by close
    = world                                 // return final world
```

**Properties**:
- *World-passing style*: The `*World` value is threaded through every IO operation. Each operation consumes the old world and produces a new one.
- *Enforced linearity*: Using `*World` twice is a type error. This prevents "time travel" (branching the world).
- *In-place update guarantee*: Because uniqueness is compiler-verified, the runtime can destructively update unique values.

**Relationship to Haskell's IO monad**: They are *dual approaches to the same problem*. Haskell's `IO` monad sequences effects via monadic bind. Clean's uniqueness types sequence effects via single-use world tokens. Both ensure that side effects happen in a deterministic order.

#### Linear Haskell and Its Implications for Resource Management

Linear Haskell (GHC proposal #111, implemented as `-XLinearTypes`) adds linear function arrows:

```haskell
-- Linear function: must use argument exactly once
f :: a %1 -> b

-- Unrestricted (normal) function
g :: a -> b   -- sugar for a %Many -> b
```

**Implications for resource management**:

1. **Use-after-free prevention**: A linear `Handle` must be consumed exactly once — by closing it. Using a closed handle or forgetting to close an open handle is a type error.

    ```haskell
    openFile :: FilePath -> IOMode -> IO (Handle %1)
    hClose :: Handle %1 -> IO ()
    -- handle MUST be closed exactly once
    ```

2. **Leak prevention**: If a function receives a linear resource, it *must* pass it onward or release it. Dropping it silently is a compile error.

3. **No need for runtime checks**: Instead of checking at runtime whether a handle is open, the type system ensures correct usage statically.

**Current status**: Linear Haskell is available in GHC but the ecosystem adoption is limited. The `linear-base` package provides `System.IO.Resource.Linear` with a linear `RIO` monad for resource-safe IO.

**The `linear-base` approach**:

```haskell
-- From System.IO.Resource.Linear
type RIO = ...  -- a resource-aware IO monad

-- Resources are tracked linearly
withFile :: FilePath -> IOMode -> (Handle %1 -> RIO a) -> RIO a
```

#### Connection to Rust's Ownership and Swift's ~Copyable

| Concept | Clean | Linear Haskell | Rust | Swift (~Copyable) |
|---------|-------|----------------|------|-------------------|
| **Mechanism** | Uniqueness types | Linear arrows (`%1 ->`) | Ownership + borrowing | `~Copyable` conformance |
| **Guarantee** | At most one reference | Used exactly once | Single owner, borrows tracked | Move-only, no implicit copy |
| **Enforced by** | Type checker | Type checker | Borrow checker | Type checker |
| **Escape hatch** | None | `Ur` (unrestricted wrapper) | `unsafe` | `consume` / `discard` |
| **Drop/deinit** | Implicit on uniqueness loss | Via `Consumable` | `Drop` trait | `deinit` |

**Key distinction — uniqueness vs. linearity**:
- *Uniqueness* (Clean, Rust): The *caller* guarantees no aliases exist. The function may use the value however it wants.
- *Linearity* (Linear Haskell): The *function* guarantees it uses the argument exactly once. The caller may have aliases.
- These are **dual**: uniqueness restricts the call site; linearity restricts the callee.

**Swift's `~Copyable`** is closer to Rust's ownership than to Linear Haskell. A `~Copyable` type cannot be implicitly duplicated; it must be explicitly moved or consumed. This provides the same resource-safety guarantees as Rust's ownership model: file handles, locks, and other resources can be made move-only, ensuring exactly-once consumption.

---

### 7. Capability-Based IO

#### Watts' Capability-Based Security Model

The object-capability model (originating with Dennis and Van Horn, 1966, and developed extensively by Mark S. Miller, Jonathan Shapiro, and others) defines a *capability* as an unforgeable, communicable token of authority.

**Principles**:

1. **Capabilities are object references**: In an object-capability language, the only way to interact with an object is to hold a reference to it. References are capabilities.
2. **No ambient authority**: There are no global variables, no static methods that access resources, no "reach out and grab" patterns. Authority is always explicitly passed.
3. **Principle of least authority (POLA)**: Each component should receive only the capabilities it needs — no more.
4. **Capability attenuation**: A holder of a broad capability can create narrower views (e.g., a read-only view of a file capability) and pass those to less-trusted code.

**Application to IO**: Instead of a monolithic `IO` permission, capabilities provide granular authority tokens:

```
-- Instead of: readFile :: FilePath -> IO String  (can do ANYTHING in IO)
-- Capability-based:
readFile :: FileSystem -> FilePath -> String   -- only file access
-- Or even narrower:
readFile :: ReadOnlyDir -> FilePath -> String  -- only reads, only from this directory
```

#### How OCaml Eio Implements Capabilities

Eio (Effects-based IO for OCaml 5) implements capability-based IO pragmatically:

```ocaml
(* The main entry point receives all capabilities *)
let () = Eio_main.run @@ fun env ->
    (* env provides: filesystem, network, clock, etc. *)
    let fs = Eio.Stdenv.fs env in
    let net = Eio.Stdenv.net env in
    (* Pass only what's needed *)
    my_server ~net          (* only network access *)
    my_file_processor ~fs   (* only filesystem access *)
```

**Key design decisions in Eio**:

1. **All authority flows from `env`**: The environment parameter to `Eio_main.run` is the root of all capabilities. Code review need only trace `env` decomposition.
2. **Subtyping for attenuation**: A read-write filesystem capability can be narrowed to read-only via OCaml's object subtyping.
3. **Testability**: Pass a mock filesystem capability to test file operations without touching the real filesystem.
4. **Effect handlers underneath**: Eio uses OCaml 5's effect handlers internally, but the user-facing API is capability-based, not handler-based.

**Limitation**: OCaml is not a true capability language. Code can bypass Eio and use `Unix.open_file` directly. Eio's capabilities are a *convention* enforced by code review, not a language guarantee.

#### "Principle of Least Authority" for IO

POLA applied to IO system design means:

1. **Decompose IO into fine-grained capabilities**: Not one `IO` monad, but separate `FileSystem`, `Network`, `Clock`, `Entropy`, `Process` capabilities.
2. **Thread capabilities through the call graph**: Functions declare exactly which capabilities they need in their signatures.
3. **Attenuate before passing**: Give subcomponents the narrowest capability that suffices. A logging function needs `AppendFile`, not `FileSystem`.
4. **Make creation of new capabilities explicit and auditable**: Only trusted code (the "powerbox") can create new capabilities from raw system access.

**Practical impact**: A function signature like `fetch :: Network -> URL -> IO Response` tells you immediately that this function accesses the network but not the filesystem, clock, or anything else. This is more informative than `fetch :: URL -> IO Response` where `IO` could do anything.

---

## Part III: Swift NIO (Apple's Ecosystem)

### 8. SwiftNIO

#### Heritage: Netty (Java)

SwiftNIO was built by former Netty team members and is explicitly a port/reimagining of Netty's architecture in Swift. The core abstractions — `EventLoop`, `Channel`, `ChannelPipeline`, `ChannelHandler`, `ByteBuffer` — map directly to their Netty counterparts.

| Netty (Java) | SwiftNIO (Swift) |
|--------------|------------------|
| `EventLoopGroup` | `EventLoopGroup` |
| `EventLoop` | `EventLoop` |
| `Channel` | `Channel` |
| `ChannelPipeline` | `ChannelPipeline` |
| `ChannelHandler` | `ChannelHandler` (`ChannelInboundHandler`, `ChannelOutboundHandler`) |
| `ByteBuf` | `ByteBuffer` |
| `ChannelFuture` | `EventLoopFuture` |
| `Promise` | `EventLoopPromise` |

#### `EventLoop`, `EventLoopGroup` — The Event Loop Model

```swift
protocol EventLoop: EventLoopGroup {
    func execute(_ task: @escaping () -> Void)
    func scheduleTask<T>(deadline: NIODeadline, _ task: @escaping () throws -> T) -> Scheduled<T>
    func makePromise<T>(of type: T.Type) -> EventLoopPromise<T>
    var inEventLoop: Bool { get }
}

protocol EventLoopGroup {
    func next() -> EventLoop
    func makeIterator() -> EventLoopIterator
    func shutdownGracefully(queue: DispatchQueue, _ callback: @escaping (Error?) -> Void)
}
```

- An `EventLoop` is a single-threaded execution context that processes IO events and dispatches callbacks. It wraps a `select`/`epoll`/`kqueue` event notification mechanism.
- An `EventLoopGroup` manages multiple `EventLoop` instances — typically one per CPU core.
- **Thread safety rule**: All operations on a `Channel` must happen on its `EventLoop`. This eliminates the need for locks within the pipeline.
- `MultiThreadedEventLoopGroup` (POSIX): Uses `NIOPosix` with `epoll` (Linux) or `kqueue` (macOS).
- `NIOTSEventLoopGroup` (Apple platforms): Uses Network.framework transport services.

#### `Channel`, `ChannelPipeline`, `ChannelHandler` — The Pipeline Model

```swift
protocol Channel {
    var allocator: ByteBufferAllocator { get }
    var pipeline: ChannelPipeline { get }
    var eventLoop: EventLoop { get }
    var isActive: Bool { get }
    func close() -> EventLoopFuture<Void>
    func write(_ data: NIOAny) -> EventLoopFuture<Void>
    func flush()
    func writeAndFlush(_ data: NIOAny) -> EventLoopFuture<Void>
}
```

A `Channel` represents an open connection (TCP socket, UDP socket, Unix domain socket, etc.). Each `Channel` is bound to exactly one `EventLoop` for its lifetime.

The **`ChannelPipeline`** is an ordered chain of `ChannelHandler`s that intercepts and processes events:

```
Inbound (data from network):
    Head -> DecoderHandler -> BusinessLogicHandler -> Tail

Outbound (data to network):
    Tail -> EncoderHandler -> Head
```

Inbound events flow from head to tail; outbound events flow from tail to head. Each handler can:
- Transform and forward the event
- Absorb the event (stop propagation)
- Generate new events

```swift
protocol ChannelInboundHandler: _ChannelInboundHandler {
    associatedtype InboundIn
    associatedtype InboundOut

    func channelRead(context: ChannelHandlerContext, data: NIOAny)
    func channelActive(context: ChannelHandlerContext)
    func errorCaught(context: ChannelHandlerContext, error: Error)
}

protocol ChannelOutboundHandler: _ChannelOutboundHandler {
    associatedtype OutboundIn
    associatedtype OutboundOut

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?)
    func flush(context: ChannelHandlerContext)
}
```

**Type erasure**: NIO uses `NIOAny` to erase handler I/O types, with `unwrapInboundIn`/`wrapOutboundOut` for safe conversion within handlers. This avoids parameterizing `Channel` and `ChannelPipeline` with handler types.

#### `ByteBuffer` — NIO's Buffer Type

```swift
struct ByteBuffer {
    // Copy-on-write storage
    // Maintains readerIndex and writerIndex within a single contiguous allocation

    var readableBytes: Int { writerIndex - readerIndex }
    var writableBytes: Int { capacity - writerIndex }

    mutating func readBytes(length: Int) -> [UInt8]?
    mutating func readInteger<T: FixedWidthInteger>(as: T.Type) -> T?
    mutating func writeBytes(_ bytes: some Sequence<UInt8>) -> Int
    mutating func writeInteger<T: FixedWidthInteger>(_ integer: T) -> Int

    func getBytes(at index: Int, length: Int) -> [UInt8]?
    mutating func setBytes(_ bytes: some Sequence<UInt8>, at index: Int) -> Int

    func slice() -> ByteBuffer          // shares storage
    func readSlice(length: Int) -> ByteBuffer?
}
```

**Design decisions**:
- **Copy-on-write**: `ByteBuffer` is a value type with CoW semantics. Slicing shares the underlying storage; mutation triggers a copy only if the storage is shared.
- **Reader/writer indices**: Unlike `Data`, `ByteBuffer` maintains separate read and write positions, optimized for the common network pattern of "read from front, write to back."
- **No Foundation dependency**: `ByteBuffer` works on Linux without Foundation. `NIOFoundationCompat` provides `Data` interop.
- **Unsafe mode**: Bounds checking can be disabled for performance-critical paths.

#### `EventLoopFuture`, `EventLoopPromise` — Async Model

```swift
struct EventLoopPromise<Value> {
    let futureResult: EventLoopFuture<Value>
    func succeed(_ value: Value)
    func fail(_ error: Error)
}

class EventLoopFuture<Value> {
    func map<NewValue>(_ callback: @escaping (Value) -> NewValue) -> EventLoopFuture<NewValue>
    func flatMap<NewValue>(_ callback: @escaping (Value) -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue>
    func whenComplete(_ callback: @escaping (Result<Value, Error>) -> Void)
    func wait() throws -> Value  // BLOCKS — only for testing/top-level
}
```

- `EventLoopPromise` is the write-side; `EventLoopFuture` is the read-side.
- Callbacks are always dispatched on the future's associated `EventLoop`, ensuring thread safety.
- **Relationship to Swift Concurrency**: Modern NIO provides bridging via `get() async throws -> Value` on `EventLoopFuture` and `makePromise()` patterns that integrate with `async/await`. The long-term direction is toward native structured concurrency, with NIO's event loops conforming to `SerialExecutor`.

#### NIO's Approach to Backpressure

NIO provides **manual** backpressure via channel writability:

```swift
// Write buffer watermarks (defaults: low 32KB, high 64KB)
let options = ChannelOptions.writeBufferWaterMark(
    low: 32 * 1024,
    high: 64 * 1024
)
```

**Mechanism**:
1. When outbound buffered data exceeds the high watermark, the channel is marked non-writable.
2. `channelWritabilityChanged` fires on inbound handlers.
3. A well-behaved handler stops reading (calls `context.channel.setOption(ChannelOptions.autoRead, value: false)`) to propagate backpressure upstream.
4. When buffered data drains below the low watermark, writability is restored, and reading resumes.

**`BackPressureHandler`**: A built-in handler that ties read-side and write-side pressure — stops reading when writing backs up. However, this is noted as limited; production systems typically need custom backpressure logic.

**With Swift Concurrency**: `NIOAsyncChannel` and `AsyncStream` with backpressure (SE-0406) provide more ergonomic backpressure support in the async/await world.

---

### 9. Swift System (Apple)

#### `FileDescriptor` — Type-Safe File Descriptor Wrapper

```swift
struct FileDescriptor: RawRepresentable, Hashable {
    let rawValue: CInt

    static let standardInput: FileDescriptor
    static let standardOutput: FileDescriptor
    static let standardError: FileDescriptor

    static func open(
        _ path: FilePath,
        _ mode: FileDescriptor.AccessMode,
        options: FileDescriptor.OpenOptions = FileDescriptor.OpenOptions(),
        permissions: FilePermissions? = nil,
        retryOnInterrupt: Bool = true
    ) throws -> FileDescriptor

    func close() throws
    func read(into buffer: UnsafeMutableRawBufferPointer, retryOnInterrupt: Bool = true) throws -> Int
    func write(_ buffer: UnsafeRawBufferPointer, retryOnInterrupt: Bool = true) throws -> Int
    func seek(offset: Int64, from whence: FileDescriptor.SeekOrigin) throws -> Int64
}
```

**Design principles**:
- `FileDescriptor` wraps a raw `CInt` file descriptor but provides type-safe operations.
- Distinct enums for `AccessMode` (`.readOnly`, `.writeOnly`, `.readWrite`), `OpenOptions`, and `SeekOrigin`.
- All operations take `retryOnInterrupt: Bool = true` (see below).

#### `FilePath` — Platform-Agnostic Path Type

```swift
struct FilePath: Hashable, ExpressibleByStringLiteral {
    // Null-terminated bag of platform bytes
    // (UTF-8 on Linux, UTF-8 or platform encoding on macOS/Windows)

    init(_ string: String)
    init(_ platformString: UnsafePointer<CInterop.PlatformChar>)

    var string: String { get }
    var root: Root? { get }
    var components: ComponentView { get }

    func appending(_ component: Component) -> FilePath
    func removingLastComponent() -> FilePath
    var lastComponent: Component? { get }
    var extension: String? { get }
}
```

**Design insight**: `FilePath` is *not* a `String`. File paths on POSIX systems are bags of bytes (any byte sequence except NUL and `/`), not necessarily valid Unicode. `FilePath` respects this reality. Conversion to `String` is available but lossy for non-UTF-8 paths.

#### System Call Wrappers with Retry-on-EINTR

Every system call in Swift System that can be interrupted by a signal takes a `retryOnInterrupt` parameter, defaulting to `true`:

```swift
// Conceptual implementation pattern:
func read(
    into buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool = true
) throws -> Int {
    try _read(buffer, retryOnInterrupt: retryOnInterrupt).get()
}

// Internal: retry loop
internal func _read(
    _ buffer: UnsafeMutableRawBufferPointer,
    retryOnInterrupt: Bool
) -> Result<Int, Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt) {
        system_read(self.rawValue, buffer.baseAddress, buffer.count)
    }
}

// The core retry mechanism
internal func valueOrErrno<T: FixedWidthInteger>(
    retryOnInterrupt: Bool,
    _ body: () -> T
) -> Result<T, Errno> {
    repeat {
        let result = body()
        if result == -1 {
            let err = Errno.current
            if err == .interrupted && retryOnInterrupt { continue }
            return .failure(err)
        }
        return .success(result)
    } while true
}
```

**Why this matters**: Signal handling is a pervasive concern in POSIX programming. Any system call that blocks can be interrupted by a signal, returning `EINTR`. In C, every call site must include a retry loop. Swift System eliminates this boilerplate with a single defaulted parameter.

#### How Swift System Relates to POSIX

Swift System is a *thin, idiomatic wrapper* over POSIX (and Windows) system calls:

| POSIX | Swift System |
|-------|-------------|
| `int open(const char*, int, ...)` | `FileDescriptor.open(_:_:options:permissions:retryOnInterrupt:)` |
| `ssize_t read(int, void*, size_t)` | `FileDescriptor.read(into:retryOnInterrupt:)` |
| `ssize_t write(int, const void*, size_t)` | `FileDescriptor.write(_:retryOnInterrupt:)` |
| `int close(int)` | `FileDescriptor.close()` |
| `off_t lseek(int, off_t, int)` | `FileDescriptor.seek(offset:from:)` |
| `int errno` | `Errno` (a proper Swift struct with named constants) |

**Design goals** (from the Swift System blog post):
1. **Low-level**: Not a high-level abstraction — a direct mapping from system calls to Swift methods.
2. **Type-safe**: Replace C integer flags with Swift enums and option sets.
3. **Idiomatic errors**: Errno becomes a thrown error, not a global variable check.
4. **Cross-platform**: Same Swift API across Apple platforms, Linux, and Windows (where applicable, mapping to Win32 equivalents).
5. **No unnecessary differences**: When two platforms share POSIX names, Swift System uses the same Swift name.

---

### 10. Key Observations

#### Universal Concepts Across ALL IO Systems

These concepts appear in every IO system surveyed, regardless of paradigm:

1. **Descriptors / Handles**: Every system has a token representing an open resource — Haskell's `Handle`, POSIX `fd`, NIO's `Channel`, Swift System's `FileDescriptor`. The token is opaque, references kernel state, and must be explicitly released.

2. **Buffering**: All systems buffer data between the application and the kernel. The choices are: no buffering, line buffering, block buffering. Haskell's `Handle`, NIO's `ByteBuffer`, and POSIX all expose this choice.

3. **Resource lifecycle**: Acquire, use, release. The only variation is how release is ensured:
   - Manual (`close()`)
   - Scoped (`bracket`, `withFile`, RAII)
   - Tracked (`ResourceT`, reference counting)
   - Linear (`~Copyable`, uniqueness types)

4. **Error propagation**: IO fails. Every system must convert kernel error codes into application-level errors. The mechanisms vary (errno, typed throws, `IO (Either Error a)`, `Result<T, Errno>`) but the need is universal.

5. **Ordering / sequencing**: Side effects must occur in a predictable order. Achieved via monadic bind (Haskell), imperative sequencing (Swift/C), event loop dispatch (NIO), or capability threading (Clean).

6. **Multiplexing**: High-performance IO requires handling many concurrent connections. The kernel provides `select`/`poll`/`epoll`/`kqueue`/`io_uring`. Every IO system wraps these (GHC IO manager, NIO event loops, Go netpoller, etc.).

7. **Backpressure**: Producers can outpace consumers. Every streaming system must address this, whether via pull-based protocols (conduit), watermarks (NIO), or structured concurrency (async streams with demand signaling).

#### Paradigm-Specific Concepts

| Concept | Where it appears | Not present in |
|---------|-----------------|----------------|
| **IO monad (opaque effect boundary)** | Haskell | Imperative langs (effects are implicit) |
| **Lazy streaming via evaluation** | Haskell lazy IO | Strict languages |
| **Algebraic effect handlers** | Koka, Frank, Unison, Eff, OCaml 5 | Haskell (monads instead), Swift, Rust |
| **Uniqueness / linearity for IO** | Clean, Linear Haskell, Rust, Swift ~Copyable | Languages without linear types |
| **Capability-based IO authority** | Eio, Wasm, seL4 | Most mainstream languages |
| **Channel pipeline (interceptor chain)** | NIO, Netty, gRPC | Haskell streaming (different model) |
| **Green threads + blocking API** | GHC, Go, Java Loom, Erlang | NIO, Rust async (explicit futures) |
| **Row-polymorphic effects** | Koka, Frank | Haskell (no fine-grained effect tracking) |

#### The Minimal Essential Vocabulary for an IO System

Based on this survey, an IO system needs these primitives to be complete:

| Primitive | Purpose | Examples |
|-----------|---------|---------|
| **Descriptor** | Token for an open resource | `Handle`, `FileDescriptor`, `Channel`, `fd` |
| **Open / Acquire** | Obtain a descriptor | `open()`, `socket()`, `connect()` |
| **Read** | Pull bytes from a descriptor | `read()`, `recv()`, `hGetLine` |
| **Write** | Push bytes to a descriptor | `write()`, `send()`, `hPutStr` |
| **Close / Release** | Relinquish a descriptor | `close()`, `hClose` |
| **Error** | Represent failure | `Errno`, `IO.Error`, `IOException` |
| **Buffer** | Intermediate byte storage | `ByteBuffer`, `Data`, `UnsafeMutableRawBufferPointer` |
| **Selector / Poller** | Multiplex across descriptors | `EventLoop`, `IO manager`, `epoll` |
| **Scoped lifetime** | Ensure release even on failure | `bracket`, `withFile`, `~Copyable` deinit, RAII |

Everything else — streaming, pipelines, futures, capabilities, effect tracking — is *composed from* these primitives. The essential question for any IO library design is: **at what level of abstraction do you compose, and what guarantees does the type system enforce about correct composition?**

---

## Sources

### Haskell IO and Streaming
- [System.IO - Hackage](https://hackage.haskell.org/package/base/docs/System-IO.html)
- [Real World Haskell - Chapter 7: I/O](https://book.realworldhaskell.org/read/io.html)
- [IO Inside - HaskellWiki](https://wiki.haskell.org/IO_inside)
- [A Newcomer's Run-in with Lazy I/O](https://ianthehenry.com/posts/lazy-io/)
- [Conduit GitHub Repository](https://github.com/snoyberg/conduit)
- [Conduit Overview - School of Haskell](https://www.schoolofhaskell.com/school/advanced-haskell/conduit-overview)
- [Conduit Hackage Documentation](https://hackage.haskell.org/package/conduit-1.3.1.1/docs/Data-Conduit.html)
- [The Core Flaw of Pipes and Conduit](https://www.yesodweb.com/blog/2013/10/core-flaw-pipes-conduit)
- [Pipes Tutorial - Hackage](https://hackage.haskell.org/package/pipes-4.3.16/docs/Pipes-Tutorial.html)
- [Pipes GitHub Repository](https://github.com/Gabriella439/pipes)
- [Why streaming Is My Favourite Haskell Streaming Library](http://jackkelly.name/blog/archives/2024/04/13/why_streaming_is_my_favourite_haskell_streaming_library/index.html)
- [How to Compose Streaming Programs - Tweag](https://www.tweag.io/blog/2017-10-05-streaming2/)
- [streaming - Hackage](https://hackage.haskell.org/package/streaming)
- [Haskell Streaming Benchmarks](https://github.com/composewell/streaming-benchmarks)
- [Network.Socket - Hackage](https://hackage.haskell.org/package/network/docs/Network-Socket.html)
- [Preliminary Benchmarking Results for io_uring IO Manager](https://wjwh.eu/posts/2020-07-26-haskell-iouring-manager.html)
- [Mio: A High-Performance Multicore IO Manager for GHC](https://dl.acm.org/doi/pdf/10.1145/2503778.2503790)
- [GHC Runtime System Options](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/runtime_control.html)
- [Control.Concurrent - Hackage](https://hackage.haskell.org/package/base/docs/Control-Concurrent.html)
- [ResourceT Overview - School of Haskell](https://www.schoolofhaskell.com/user/snoyberg/library-documentation/resourcet)
- [ResourceT - Hackage](https://hackage.haskell.org/package/resourcet)

### Academic / Theoretical
- [Handlers of Algebraic Effects - Plotkin & Pretnar (2009)](https://homepages.inf.ed.ac.uk/gdp/publications/Effect_Handlers.pdf)
- [An Introduction to Algebraic Effects and Handlers](https://www.eff-lang.org/handlers-tutorial.pdf)
- [Algebraic Effects for Functional Programming - Daan Leijen](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/08/algeff-tr-2016-v2.pdf)
- [Do Be Do Be Do (Frank) - Lindley, McBride, McLaughlin (2017)](https://arxiv.org/pdf/1611.09259)
- [Koka Language Documentation](https://koka-lang.github.io/koka/doc/book.html)
- [Koka: Programming with Row-polymorphic Effect Types](https://arxiv.org/pdf/1406.2061)
- [Koka GitHub Repository](https://github.com/koka-lang/koka)
- [Unison Language - Abilities and Ability Handlers](https://www.unison-lang.org/docs/language-reference/abilities-and-ability-handlers/)
- [Unison Introduction to Abilities](https://www.unison-lang.org/docs/fundamentals/abilities/)
- [Effective Concurrency with Algebraic Effects - Sivaramakrishnan](https://kcsrk.info/ocaml/multicore/2015/05/20/effects-multicore/)
- [Concurrent System Programming with Effect Handlers](https://kcsrk.info/papers/system_effects_feb_18.pdf)
- [Retrofitting Linear Types - Linear Haskell Paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/03/haskell-linear-submitted.pdf)
- [Linear Haskell: Practical Linearity in a Higher-Order Polymorphic Language](https://arxiv.org/pdf/1710.09756)
- [GHC Proposal #111: Linear Types](https://ghc-proposals.readthedocs.io/en/latest/proposals/0111-linear-types.html)
- [Linearity, Uniqueness, and Haskell](http://edsko.net/2017/01/08/linearity-in-haskell/)
- [System.IO.Resource.Linear - linear-base](https://hackage-content.haskell.org/package/linear-base-0.5.0/docs/System-IO-Resource-Linear.html)
- [Linear Types Make Performance More Predictable - Tweag](https://www.tweag.io/blog/2017-03-13-linear-types/)
- [Capability-Based Security - Wikipedia](https://en.wikipedia.org/wiki/Capability-based_security)
- [Object-Capability Model - Wikipedia](https://en.m.wikipedia.org/wiki/Object-capability_model)
- [Objects as Secure Capabilities - Joe Duffy](https://joeduffyblog.com/2015/11/10/objects-as-secure-capabilities/)
- [Lambda Capabilities - Thomas Leonard](https://roscidus.com/blog/blog/2023/04/26/lambda-capabilities/)
- [Eio - Effects-based IO for OCaml](https://github.com/ocaml-multicore/eio)
- [A Capability-Based Module System for Authority Control](https://www.cs.cmu.edu/~aldrich/papers/ecoop17modules.pdf)

### Swift NIO and Swift System
- [SwiftNIO README](https://github.com/apple/swift-nio/blob/main/README.md)
- [SwiftNIO GitHub Repository](https://github.com/apple/swift-nio)
- [Understanding SwiftNIO by Building a Text Modifying Server](https://rderik.com/blog/understanding-swiftnio-by-building-a-text-modifying-server/)
- [Using SwiftNIO Channels - Swift on Server](https://swiftonserver.com/using-swiftnio-channels/)
- [ChannelPipeline Documentation](https://swiftinit.org/docs/swift-nio/niocore/channelpipeline)
- [ByteBuffer Documentation](https://swiftinit.org/docs/swift-nio/niocore/bytebuffer)
- [EventLoopFuture Documentation](https://swiftinit.org/docs/swift-nio/niocore/eventloopfuture)
- [SwiftNIO: Understanding Futures and Promises](https://www.process-one.net/blog/swiftnio-futures-and-promises/)
- [Swift Concurrency Adoption Guidelines](https://www.swift.org/documentation/server/guides/libraries/concurrency-adoption-guidelines.html)
- [SwiftNIO Backpressure Handler Issue #162](https://github.com/apple/swift-nio/issues/162)
- [SE-0406: Async Stream Backpressure](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0406-async-stream-backpressure.md)
- [Swift System GitHub Repository](https://github.com/apple/swift-system)
- [Swift System is Now Open Source - Swift Blog](https://www.swift.org/blog/swift-system/)
- [FileDescriptor.swift Source](https://github.com/apple/swift-system/blob/main/Sources/System/FileDescriptor.swift)
- [FileOperations.swift Source](https://github.com/apple/swift-system/blob/main/Sources/System/FileOperations.swift)
- [Swift System API Roadmap Issue #16](https://github.com/apple/swift-system/issues/16)
