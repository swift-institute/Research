# IO Prior Art and swift-io Design Audit

<!--
---
version: 2.0.0
last_updated: 2026-03-25
status: RECOMMENDATION
---
-->

## How to Use This Document

This document has two independent parts:

- **Part I** (IO Systems Prior Art Survey): A language-agnostic literature survey of 15 IO systems, producing a 4-tier concept necessity spectrum. Useful as a standalone reference when evaluating any IO design decision.
- **Part II** (swift-io Design Audit): Maps every swift-io concept against the Part I taxonomy. Useful when working on swift-io to understand where each concept sits relative to the broader IO landscape.

Read Part I first for context, then Part II for ecosystem-specific conclusions. The per-system reference data is in a companion document: `swift-io/Research/io-prior-art-per-system-reference.md`.

## Context

Swift Institute's `swift-io` (Layer 3 — Foundations) provides the IO infrastructure for the ecosystem. This document combines a literature survey of best-in-class IO systems with a concept-by-concept design audit of swift-io against those findings.

**Trigger**: [RES-012] Discovery — proactive design audit of working implementation against external prior art.

**Scope**: `swift-io` (Layer 3, swift-foundations) + `swift-kernel-primitives` IO types (Layer 1, swift-primitives). 279 source files, 7 targets, ~72 public concepts.

**Method**: Literature survey of 15 IO systems conducted *without* examining swift-io → concept taxonomy with 4-tier necessity spectrum → swift-io concept inventory → mapping each swift-io concept against the taxonomy.

## Question

1. What are the **universal concepts** that every IO system must provide?
2. What are the **common patterns** that most best-in-class IO systems share?
3. What **design decisions** must every IO system make, and what are the trade-offs?
4. For each concept in swift-io: does it map to a recognized concept, at which tier, or is it novel?
5. **Central question**: Does swift-io introduce too many custom concepts, or is everything correct and necessary?

---

## Part I: IO Systems Prior Art Survey

### Systems Surveyed

| System | Language | Layer | Model |
|--------|----------|-------|-------|
| `std::io` | Rust | Standard library | Sync traits (Read/Write/Seek/BufRead) |
| `tokio` | Rust | Async runtime | Async traits (AsyncRead/AsyncWrite) + reactor |
| `mio` | Rust | Event loop | Low-level readiness-based (epoll/kqueue/IOCP) |
| `tokio-uring` / `monoio` | Rust | Async runtime | Completion-based (io_uring) |
| `io` package | Go | Standard library | Minimal interfaces (Reader/Writer) |
| `java.io` / `java.nio` | Java | Standard library | Streams → Channels + Buffers + Selectors |
| `System.IO` / Pipelines | .NET | Standard library | Stream base class → Span/Pipelines |
| `std.io` / `std.Io` | Zig | Standard library | Comptime generics → concrete vtable+buffer |
| Classic IO / Eio | OCaml | Standard library / Eio | Channels → effects-based capabilities |
| `System.IO` / conduit | Haskell | Standard library / streaming | IO monad → pull-based streaming |
| SwiftNIO | Swift | Server networking | Netty-derived pipeline (EventLoop/Channel/Handler) |
| Swift System | Swift | System calls | Thin POSIX wrapper (FileDescriptor/FilePath) |
| epoll / kqueue / IOCP | OS | Kernel | Readiness-based multiplexing |
| io_uring | Linux | Kernel | Completion-based, shared-memory rings |
| libuv | C | Cross-platform | Event loop abstracting epoll/kqueue/IOCP |

Detailed per-system API documentation: `swift-foundations/swift-io/Research/io-prior-art-per-system-reference.md` (6,400 lines covering all 15 systems).

---

### 1. Universal Concepts (present in every IO system)

These nine primitives appear in every system surveyed. They constitute the *irreducible* vocabulary of IO.

#### 1.1 Descriptor / Handle

Every system represents an open IO resource as an opaque token.

| System | Token | Type |
|--------|-------|------|
| POSIX | `fd` | `int` |
| Windows | `HANDLE` | opaque pointer |
| Go | `*os.File` | struct wrapping fd |
| Rust | `OwnedFd` / `File` | newtype wrapping fd |
| Zig | `File` / `Handle` | struct wrapping `fd_t` |
| Java | `FileChannel` / `SocketChannel` | abstract class wrapping fd |
| .NET | `FileStream` / `SafeFileHandle` | class wrapping HANDLE |
| Haskell | `Handle` | abstract, opaque |
| OCaml | `file_descr` / `Unix.file_descr` | abstract |
| SwiftNIO | `Channel` | protocol |
| Swift System | `FileDescriptor` | struct wrapping `CInt` |

**Design axis**: Whether the token is typed (Rust `OwnedFd` vs `BorrowedFd`), whether it encodes capabilities (read-only vs read-write), whether closing is manual or scoped.

#### 1.2 Read

Pull bytes from a descriptor into a caller-provided buffer.

| System | Signature shape | EOF signal |
|--------|----------------|------------|
| POSIX | `read(fd, buf, count) -> ssize_t` | Returns 0 |
| Rust | `fn read(&mut self, buf: &mut [u8]) -> Result<usize>` | Returns `Ok(0)` |
| Go | `Read(p []byte) (n int, err error)` | `n=0, err=io.EOF` |
| Java NIO | `channel.read(ByteBuffer) -> int` | Returns -1 |
| .NET | `stream.Read(Span<byte>) -> int` | Returns 0 |
| Zig | `read([]u8) ReadError!usize` | `error.EndOfStream` |
| Haskell | `hGetLine :: Handle -> IO String` | Raises `End_of_file` |
| Eio | `single_read : _ source -> Cstruct.t -> int` | Raises `End_of_file` |
| Swift System | `read(into: UnsafeMutableRawBufferPointer) throws -> Int` | Returns 0 |

**Universal pattern**: Caller provides buffer, callee fills it partially, returns bytes read. Partial reads are normal; EOF is signaled distinctly.

#### 1.3 Write

Push bytes from a caller-provided buffer to a descriptor. Every system mirrors Read with a Write, always with one asymmetry: Write requires an explicit flush for buffered writers, because output may be deferred. Read has no flush dual because input is always demand-driven.

#### 1.4 Close / Release

Every system requires explicit resource release. The variation is in *how* release is guaranteed:

| Strategy | Systems | Guarantee |
|----------|---------|-----------|
| Manual `close()` | POSIX, Go, Swift System | None — programmer discipline |
| `defer` / `RAII` / `Drop` | Go defer, Rust Drop, C++ RAII | Scope-based, lexical |
| `bracket` / `with*` | Haskell `withFile`, Python `with`, Eio `Switch` | Continuation-based, exception-safe |
| `~Copyable` / linear types | Rust ownership, Swift `~Copyable`, Clean uniqueness | Type-system enforced |
| GC + finalizer | Java, .NET, OCaml | Non-deterministic, safety-net only |

#### 1.5 Error Propagation

| System | Mechanism | Typed? |
|--------|-----------|--------|
| Rust | `io::Error` wrapping `ErrorKind` enum | Semi — `ErrorKind` is `#[non_exhaustive]` |
| Go | `error` interface, `io.EOF` sentinel | No — single `error` interface |
| Java | `IOException` class hierarchy | Yes — via subclass (loose) |
| Zig | Error unions with comptime error sets | Yes — exhaustive at compile time |
| Haskell | `IOError` / `IOException` | Partially — `IOErrorType` enum |
| Eio | `Eio.Io` exception with nested error codes | Yes — extensible, matchable |
| Swift System | `Errno` struct | Yes — maps to POSIX errno |

**Key insight**: Zig is the only system with truly exhaustive typed error handling at compile time.

#### 1.6 Buffer

Intermediate byte storage between application logic and the kernel.

| System | Buffer type | Allocation |
|--------|------------|------------|
| Rust | `&mut [u8]` / `Vec<u8>` / `BorrowedBuf` | Caller-provided or wrapper-allocated |
| Go | `[]byte` | Caller-provided |
| Java | `ByteBuffer` (heap or direct) | Factory method, flip/compact protocol |
| .NET | `Span<byte>` / `Memory<byte>` / `byte[]` | Caller-provided or pool-allocated |
| Zig | `[]u8` / embedded in `Io.Writer` | Passed at construction (0.15.1+) |
| SwiftNIO | `ByteBuffer` (CoW, reader/writer indices) | Allocator pattern |
| io_uring | Caller-provided, kernel-owned during op | Ownership transfer |

#### 1.7 Multiplexing / Event Loop

| System | Multiplexer | Model |
|--------|-------------|-------|
| Go | Runtime netpoller (epoll/kqueue) | Hidden, transparent to goroutines |
| Rust/tokio | mio (epoll/kqueue/IOCP) | Explicit reactor, poll-based futures |
| Java NIO | `Selector` | Explicit reactor pattern |
| .NET | IOCP / epoll (Kestrel) | Hidden behind async/await |
| SwiftNIO | `EventLoop` (epoll/kqueue) | Explicit, Netty-derived |
| libuv | `uv_loop_t` (epoll/kqueue/IOCP) | Explicit event loop |
| Haskell/GHC | IO manager (epoll/kqueue) | Hidden, transparent to green threads |
| Eio | Backend (io_uring/epoll/kqueue) | Hidden behind effects |
| Zig | `Io` interface (blocking/threadpool/io_uring) | Explicit, passed as parameter |

**Design axis**: Whether multiplexing is hidden (Go, GHC, Eio) or exposed (NIO, tokio, Java NIO).

#### 1.8 Seek / Positional Access

Random-access within a seekable resource. Always modeled as three origins: start, current, end. Every system also provides positional read/write (at offset without cursor mutation) as a separate capability, because positional access is concurrency-safe while cursor-based access is not.

#### 1.9 Scoped Lifetime / Resource Safety

Ensuring descriptors are closed even when errors occur.

---

### 2. Common Patterns (present in most systems)

#### 2.1 Read/Write Trait Duality

Most systems define Read and Write as *symmetric dual* abstractions with a single required method each.

| System | Read interface | Write interface | Methods required |
|--------|---------------|-----------------|-----------------|
| Rust | `Read` | `Write` | 1 (read), 2 (write + flush) |
| Go | `io.Reader` | `io.Writer` | 1 each |
| Zig (0.15.1+) | `Io.Reader` | `Io.Writer` | vtable (drain, etc.) |
| Java | `InputStream` | `OutputStream` | 1 each (abstract) |
| .NET | `Stream` (unified) | `Stream` (unified) | `Read`+`Write` on one type |

**Outlier**: .NET's single `Stream` base class with both `Read` and `Write` is widely considered a design mistake.

#### 2.2 The Decorator / Wrapper Pattern

Building IO pipelines by wrapping one abstraction with another:

```
raw source → buffering → decompression → decryption → parsing
```

Present in: Go (wrappers), Rust (generic wrappers), Java (FilterInputStream chain), .NET (Stream wrapping), Haskell (conduit fusion).

#### 2.3 Zero-Copy Optimization via Specialized Dispatch

| System | Detection mechanism | Fast paths |
|--------|-------------------|------------|
| Go | `io.Copy` checks `WriterTo`/`ReaderFrom` | `sendfile`, `splice`, `copy_file_range` |
| Rust | `io::copy` specialization cascade | `copy_file_range`, `sendfile`, `splice` |
| Java | `FileChannel.transferTo` | `sendfile` |
| Zig (0.15.1+) | `sendFile` in vtable | fd-to-fd transfer |

**Key insight**: Zero-copy is always *behind* a generic API. The API never exposes it as a distinct concept.

#### 2.4 Buffered Read as Two-Phase Protocol

| System | API |
|--------|-----|
| Rust `BufRead` | `fill_buf() -> &[u8]` + `consume(n)` |
| Go `bufio.Reader` | `Peek(n)` + implicit consume on `Read` |
| Eio `Buf_read` | `peek`/`ensure` + `consume` |
| Zig (0.15.1+) | Buffer embedded in interface; peek via direct buffer access |

#### 2.5 Vectored IO (Scatter/Gather)

Present in: Rust, Go, Zig, Java NIO, io_uring, libuv.

#### 2.6 Optimization Interfaces (WriterTo / ReaderFrom)

| System | Concept | Purpose |
|--------|---------|---------|
| Go | `io.WriterTo` / `io.ReaderFrom` | Source/destination drives copy for kernel-level optimization |
| Rust | Specialization within `io::copy` | Compile-time dispatch to `sendfile`/`splice` |
| Zig | `sendFile` vtable entry | Direct fd-to-fd transfer capability |

---

### 3. Design Decisions Every IO System Must Make

#### 3.1 Readiness vs. Completion Model

| Model | Systems | API shape | Buffer ownership |
|-------|---------|-----------|-----------------|
| **Readiness** | epoll, kqueue, mio, Go, tokio | "Is the fd ready?" → then read/write | App owns buffer always |
| **Completion** | IOCP, io_uring | "Perform this IO" → results delivered | Kernel owns buffer during operation |

**Implications**: Completion has strictly better performance (fewer syscalls) but strictly harder safety (buffer lifetime, cancellation). Rust's io_uring crates demonstrate the API tension: standard `AsyncRead`/`AsyncWrite` and io_uring produce *incompatible* trait signatures.

#### 3.2 Sync vs. Async vs. Green Threads

| Approach | Systems | Function coloring? |
|----------|---------|-------------------|
| **Synchronous** | Rust `std::io`, Go, Haskell, Zig blocking | No (Go/Haskell/Zig) |
| **Explicit async** | Rust tokio, .NET async/await, Swift async | Yes |
| **Green threads** | Go goroutines, GHC threads, Java Loom, Eio fibers | No (runtime handles it) |
| **Runtime-polymorphic** | Zig `Io` interface | No (same code, different backend) |

#### 3.3 Interface Granularity

| System | Read methods required | Write methods required | Philosophy |
|--------|----------------------|----------------------|------------|
| Go | 1 (`Read`) | 1 (`Write`) | "The bigger the interface, the weaker the abstraction" |
| Rust | 1 (`read`) | 2 (`write` + `flush`) | Minimal required, rich provided methods |
| .NET | 3+ (`Read`+`Write`+`Seek`+`Flush`+`Close`) | Combined | Everything in one class |

**Universal insight**: One method should be sufficient for the core contract.

#### 3.4 Error Model

| System | EOF representation | Error granularity | Exhaustiveness |
|--------|-------------------|------------------|----------------|
| Rust | `Ok(0)` return value | `ErrorKind` enum (non-exhaustive) | Semi |
| Go | `io.EOF` sentinel error | Single `error` interface | None |
| Zig | `error.EndOfStream` error value | Per-operation error sets | Full (compiler-checked) |

#### 3.5 Buffering: Separate Layer vs. Integrated

| Approach | Systems | Trade-off |
|----------|---------|-----------|
| **Separate wrapper** | Rust `BufReader`/`BufWriter`, Go `bufio`, Java `BufferedInputStream` | Composable, opt-in |
| **Integrated in interface** | Zig 0.15.1+ (buffer in `Io.Writer`) | One fewer layer, baked in |

#### 3.6 Capability Passing vs. Ambient Authority

| Approach | Systems | Trade-off |
|----------|---------|-----------|
| **Ambient authority** | Go (`os.Open`), Rust (`File::open`), Java, .NET | Convenient, anything accessible |
| **Explicit capabilities** | Eio (`env` decomposition), Zig (Dir-relative, `Io` parameter) | Testable, auditable, more ceremony |

---

### 4. Concept Necessity Spectrum

Based on the survey, IO concepts ranked by necessity:

#### Tier 1: Irreducible (every system needs these)

1. **Descriptor** — opaque handle to OS resource
2. **Read** — pull bytes from descriptor
3. **Write** — push bytes to descriptor
4. **Close** — release descriptor
5. **Error** — propagate failures
6. **Buffer** — intermediate storage between app and kernel

#### Tier 2: Expected (best-in-class systems have these)

7. **Seek** — random access within seekable resources
8. **Buffered IO** — amortize syscalls
9. **Copy** — transfer between reader and writer with optimization dispatch
10. **Vectored IO** — scatter/gather for multi-buffer operations
11. **Positional IO** — read/write at offset without cursor mutation
12. **Event loop / Selector** — multiplex across descriptors
13. **Flush** — commit buffered writes
14. **Resource scoping** — ensure close even on failure

#### Tier 3: Valuable (present in many, absent in some)

15. **Reader/Writer combinators** — chain, take, limit, tee, multi
16. **Zero-copy dispatch** — sendfile/splice/copy_file_range behind generic API
17. **Two-phase buffered read** — fill_buf + consume for zero-copy inspection
18. **Typed errors** — exhaustive error handling at compile time
19. **Backpressure** — producer/consumer coordination

#### Tier 4: Language/Paradigm-Specific (justified by language context)

20. **Async IO traits** — only if the language has async/await
21. **Green thread integration** — only if the runtime provides green threads
22. **Capability-based IO** — only if the language supports capability discipline
23. **Algebraic effects** — only in effect-typed languages
24. **Buffer ownership transfer** — only for completion-based IO

---

### 5. Design Principles Observed Across All Systems

**P1. One method per concept.** The most successful IO interfaces require exactly one method for the core contract.

**P2. Separate Read from Write.** Every system except .NET separates reading and writing into distinct abstractions.

**P3. EOF is not an error.** EOF signals normal stream termination; error-handling code should not fire on normal completion.

**P4. Buffering is a separate concern.** Most systems add buffering as a wrapper layer, not built into the core interface.

**P5. Zero-copy is an implementation detail, not an API concept.** Users write `Copy(dst, src)` and the implementation selects the optimal kernel mechanism.

**P6. Composability beats capability.** The more requirements an interface imposes, the fewer types can satisfy it.

**P7. The caller owns the buffer (in readiness-based IO).** The simplest ownership model and the one that composes best with language-level ownership tracking.

---

## Part II: swift-io Design Audit

### Critical Realization

swift-io is **not** a Read/Write abstraction layer (like Go's `io` package or Rust's `std::io`). It is **IO infrastructure** — event loop, completion queue, blocking thread pool, and resource executor. The correct comparison targets are:

| swift-io layer | Prior art comparisons |
|---------------|----------------------|
| `Kernel.*` (L1) | Swift System `FileDescriptor`, Rust `OwnedFd`/`BorrowedFd` |
| `IO.Event.Selector` + `Driver` | mio (Rust), Java NIO `Selector`, SwiftNIO `EventLoop` |
| `IO.Completion.*` | tokio-uring, liburing, Windows IOCP |
| `IO.Blocking.Lane` + `Threads` | libuv thread pool, Java `ExecutorService`, tokio `spawn_blocking` |
| `IO.Executor` + `Handle` + `Lane` | tokio runtime, SwiftNIO `EventLoopGroup`, Go runtime scheduler |

Higher-level Read/Write abstractions live in consumers (e.g., `swift-file-system`'s `File.Read`/`File.Write`).

### Methodology

Per [RES-013]: scope definition → concept inventory → evaluation against tier spectrum → synthesis → recommendation.

---

### Layer 1: Kernel Primitives (swift-kernel-primitives)

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `Kernel.Descriptor` | Swift System `FileDescriptor`, Rust `OwnedFd`, Go `os.File` (internal fd) | 1 | **Correct**. Opaque fd wrapper is the universal IO token. |
| `Kernel.Descriptor.Validity.Error` (.invalid, .limit) | Rust `io::Error` with `ErrorKind`, POSIX EBADF/EMFILE/ENFILE | 1 | **Correct**. Descriptor validity checking is universal. |
| `Kernel.IO.Error` (broken, reset, hardware, etc.) | Rust `ErrorKind`, Go sentinel errors, Zig per-operation error sets | 1 | **Correct**. IO error enumeration is universal. |
| `Kernel.Event` (id, interest, flags) | mio `Event`, epoll `epoll_event`, kqueue `kevent` | 2 | **Correct**. Direct mapping to kernel event structures. |
| `Kernel.Event.Interest` (.read, .write, .priority) | mio `Interest`, epoll `EPOLLIN`/`EPOLLOUT`, kqueue `EVFILT_READ`/`EVFILT_WRITE` | 2 | **Correct**. Standard readiness interest flags. |
| `Kernel.Event.Flags` (.error, .hangup, .readHangup, .writeHangup) | epoll `EPOLLERR`/`EPOLLHUP`/`EPOLLRDHUP`, kqueue `EV_EOF`/`EV_ERROR` | 2 | **Correct**. Standard event status flags. |
| `Kernel.Event.ID` (tagged UInt) | mio `Token(usize)`, epoll `user_data`, kqueue `ident`+`udata` | 2 | **Correct**. Tagged wrapping adds type safety. |
| `Kernel.Event.Counter` / `.Descriptor` (eventfd) | Linux eventfd(2) | 2 | **Correct**. Platform-specific, appropriately guarded. |
| `Kernel.Socket.Descriptor` | Rust `OwnedFd`, POSIX socket fd, Winsock `SOCKET` | 1 | **Correct**. Socket descriptor wrapper. |
| `Kernel.Socket.Error` / `.Flags` / `.Backlog` / `.Shutdown` | POSIX socket API (socket, listen, shutdown) | 2 | **Correct**. Standard socket primitives. |
| `Kernel.File.Offset` / `.Delta` / `.Size` | Rust `SeekFrom`, POSIX `off_t`, Java NIO `position()` | 2 | **Correct**. Phantom-typed coordinate arithmetic — more precise than prior art, not novel. |

**Layer 1 verdict**: Every concept maps to Tier 1 or Tier 2. Zero novel concepts. **No unnecessary concepts.**

---

### Layer 3: IO Core

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `IO` (namespace enum) | Rust `std::io` module, Go `io` package, Zig `std.io` | — | Namespace, not a concept. |
| `IO.Lifecycle` (running/shutdownInProgress/shutdownComplete) | libuv `uv_loop_alive`, NIO `EventLoop.shutdownGracefully`, tokio runtime shutdown | 2 | **Correct**. Every IO runtime has lifecycle management. |
| `IO.Lifecycle.Error<E>` | tokio `JoinError`, NIO shutdown errors | 2 | **Correct**. Generic parameter for typed throws is a Swift adaptation. |
| `IO.Closable` (consuming close, ~Copyable) | Rust `Drop` + `OwnedFd`, Clean uniqueness types | 4 | **Correct and well-precedented**. Natural Swift realization of ownership-based resource safety. |
| `IO.Backpressure.Strategy` (.wait, .failFast) | NIO watermarks, reactive streams demand signaling | 3 | **Correct**. Standard binary choice. |

**IO Core verdict**: Five concepts, all Tier 2-4. **No unnecessary concepts.**

---

### Layer 3: IO Events

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `IO.Event.Selector` (actor) | mio `Poll`, Java NIO `Selector`, SwiftNIO `EventLoop`, libuv `uv_loop_t` | 2 | **Correct**. Central event loop. Actor isolation is Swift-specific concurrency model. |
| `IO.Event.Driver` (@Witness) | mio's platform backends, libuv's platform layer | 2 | **Correct**. @Witness instead of protocol is Swift Embedded choice, not new concept. |
| `IO.Event.Driver.Capabilities` | libuv platform detection, mio `Event::is_*` checks | 2 | **Correct**. |
| `IO.Event.Channel` (~Copyable, read/write) | tokio `TcpStream`, mio `TcpStream`, NIO `Channel` | 2 | **Correct**. ~Copyable = Swift equivalent of Rust's `&mut self`. |
| `IO.Event.Channel.Lifecycle` / `.HalfClose` / `.Shutdown` | TCP half-close (POSIX `shutdown(2)`), NIO `Channel.close(mode:)` | 2 | **Correct**. Standard for TCP. |
| `IO.Event.Poll` / `.Loop` | mio `Poll::poll()`, libuv loop phases | 2 | **Correct**. |
| `IO.Event.Registration` / `.Entry` / `.Queue` | mio `Registry`, epoll `epoll_ctl`, kqueue `kevent` changelist | 2 | **Correct**. |
| `IO.Event.Token<State>` (Registering, Armed) | Typestate programming (Strom & Yemini, 1986); Rust session types | 3→4 | **Justified paradigm-specific adaptation**. Technique is known; application to event registration with consuming tokens is more precise than any surveyed prior art, justified by Swift's ~Copyable making it zero-cost. |
| `IO.Event.Waiter` | tokio Waker integration, NIO EventLoopPromise | 2 | **Correct**. |
| `IO.Event.Wakeup` / `.Channel` | mio `Waker`, libuv `uv_async_t`, NIO pipe wakeup | 2 | **Correct**. |
| `IO.Event.Buffer` / `.Pool` | mio `Events` (reusable buffer) | 2 | **Correct**. |
| `IO.Event.Bridge` | tokio cross-runtime bridging, NIO async bridging | 3 | **Correct**. |
| `IO.Event.Backoff.Exponential` | Standard algorithm | 3 | **Correct**. |
| `IO.Event.Deadline` / `.Scheduling` | tokio timer driver, NIO `Scheduled`, libuv `uv_timer_t` | 2 | **Correct**. |
| `IO.Event.Arm` / `.Begin` / two-phase arm | mio `register()` + `poll()`, Java NIO `register()` + `select()`, io_uring SQE+CQE | 2 | **Standard concept with clearer naming**. Not novel. |
| `IO.Event.Batch` | io_uring batch, kqueue changelist | 3 | **Correct**. |

**IO Events verdict**: ~18 concepts, all Tier 2-4. Token type-state and two-phase arm are the most distinctive, both justified. **No unnecessary concepts.**

---

### Layer 3: IO Completions

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `IO.Completion` namespace | io_uring / IOCP | 2 | **Correct**. |
| `IO.Completion.ID` | io_uring `user_data`, IOCP overlapped context | 2 | **Correct**. |
| `IO.Completion.Operation` (~Copyable) | io_uring SQE, IOCP `OVERLAPPED` | 2 | **Correct**. Move-only = single-submission enforcement. Maps to tokio-uring `IoBuf`. |
| `IO.Completion.Event` | io_uring CQE, IOCP completion packet | 2 | **Correct**. |
| `IO.Completion.Outcome` | io_uring `cqe->res`, IOCP `lpNumberOfBytesTransferred` | 2 | **Correct**. |
| `IO.Completion.Kind` / `.Flags` | io_uring `opcode`, `IORING_CQE_F_*` | 2 | **Correct**. |
| `IO.Completion.Driver` (@Witness) | Platform abstraction (same pattern as Event.Driver) | 2 | **Correct**. |
| `IO.Completion.Queue` (actor) | io_uring CQ drain loop, IOCP `GetQueuedCompletionStatus` | 2 | **Correct**. |
| `IO.Completion.Submission` / `.Queue` | io_uring SQ, liburing `io_uring_get_sqe` | 2 | **Correct**. |
| `IO.Completion.Waiter` | tokio-uring future resolution | 2 | **Correct**. |
| `IO.Completion.Read` / `.Write` / `.Accept` / `.Connect` | io_uring `IORING_OP_READ`/`WRITE`/`ACCEPT`/`CONNECT` | 2 | **Correct**. |
| `IO.Completion.IOCP` / `.IOUring` | Platform backends | 2 | **Correct**. |

**IO Completions verdict**: ~15 concepts, all Tier 2. Essentially a typed Swift interface over io_uring and IOCP. **Zero novel concepts.**

---

### Layer 3: IO Blocking

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `IO.Blocking.Lane` (@Witness) | tokio `spawn_blocking`, libuv thread pool, Java `ExecutorService` | 2 | **Correct**. Blocking work offload is standard. |
| `IO.Blocking.Capabilities` | Java `ExecutorService` feature queries, .NET `TaskScheduler` properties | 3 | **Correct**. |
| `IO.Blocking.Deadline` | tokio `timeout`, Go `context.WithTimeout`, libuv timer | 2 | **Correct**. |
| `IO.Blocking.Execution.Semantics` (.bestEffort, .guaranteed) | Java `ExecutorService` rejection policy, .NET `TaskCreationOptions` | 3 | **Reasonable**. Maps to executor rejection policies. |
| `IO.Blocking.Ticket` / `TicketTag` | — | 4 | **Justified**. Standard ecosystem phantom type pattern. |
| `IO.Blocking.Lane.Sharded` / NUMA | tokio multi-threaded runtime | 3 | **Correct**. |
| `IO.Blocking.Lane.Abandoning` (17 files) | Java `ThreadPoolExecutor` with `DiscardPolicy`, tokio `abort()` | 2 | **Standard concept**. File count reflects [API-IMPL-005] convention, not conceptual bloat. |
| `IO.Blocking.Threads` (52 files) | Java `ThreadPoolExecutor`, tokio blocking pool, libuv thread pool | 2 | **Correct concept**. Fine-grained decomposition follows ecosystem conventions. |

**IO Blocking verdict**: All concepts Tier 2-3. **No unnecessary concepts.**

---

### Layer 3: IO Executor

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `IO.Executor` | tokio runtime, NIO `EventLoopGroup`, Go runtime scheduler | 2 | **Correct**. |
| `IO.Handle` / `.ID` / `.Registry` | tokio IO driver, NIO `Channel` registry, mio token-to-resource slab | 2 | **Correct**. |
| `IO.Handle.Waiter` / `.Waiters` | tokio task waker sets, NIO promise lists | 2 | **Correct**. |
| `IO.Lane` (public wrapper) | Public convenience | — | Not a new concept. |
| `IO.Pool` | Connection pooling | 3 | **Correct**. |
| `IO.Backend` (.blocking, .eventDriven, .completionBased) | Zig `Io` (runtime-selected blocking/threadpool/io_uring) | 3 | **Well-precedented** (Zig prior art). |
| `IO.Scope` / `IO.Executor.Transaction` | Eio `Switch`, Rust lifetime scoping, database transactions | 3→4 | **Justified** (Eio prior art). |
| `IO.Executor.Slot` (~Copyable cross-actor transfer) | **No prior art** | Novel | **Justified**. Solves problem unique to Swift's actor + ~Copyable combination. |
| `IO.Executor.Teardown` | Eio switch finalizers, Rust Drop ordering | 3 | **Correct**. |
| `IO.Ready` / `IO.Pending` (marker types) | Rust typestate markers, NIO `Channel.isActive` | 4 | **Justified**. |
| `IO.Error` | Composite error enum | 1 | **Correct**. |
| `IO.Deadline` | Unified deadline type | 2 | **Correct**. |

**IO Executor verdict**: ~12 concepts. `IO.Executor.Slot` is the only truly novel concept, justified by language constraint. **No unnecessary concepts.**

---

### Layer 3: swift-file-system (Read/Write Consumer)

swift-file-system consumes swift-io's infrastructure to provide file-specific operations. It is **not** a generic Reader/Writer trait layer — it is an **operation-oriented file API** with concrete types and methods. This is a deliberate architectural choice that diverges from prior art's composable stream model.

**Architecture**: Two targets — `File System Core` (imports `IO_Core`) and `File System` (imports `IO` for async lane support).

| Concept | Prior art mapping | Tier | Verdict |
|---------|------------------|------|---------|
| `File.Descriptor` (~Copyable, IO.Closable, deinit-closes) | Rust `OwnedFd`, Swift System `FileDescriptor` | 1 | **Correct**. Single-ownership fd wrapper. Deinit safety net matches Rust's Drop. |
| `File.Handle` (~Copyable, read/write/seek/sync/close) | POSIX file handle, Rust `File`, Go `os.File` | 1 | **Correct**. Low-level handle with mutating read/write and consuming close. |
| `File.Handle.Open { handle in ... }` (scoped access) | Haskell `withFile`, Eio `Switch.run`, Python `with open()` | 2 | **Correct**. Generic `Error<ClosureError>` preserving both operation and close errors is better than most prior art which drops close errors. |
| `File.Read.full { span in ... }` (zero-copy callback) | Go `os.ReadFile`, Rust `fs::read`, Zig `readToEndAlloc` | 2 | **Ahead of prior art**. Go/Rust/Zig return owned `[]byte`/`Vec<u8>`/`[]u8` — always copies. swift-file-system borrows via `Span<UInt8>`, data never leaves kernel-mapped memory unless caller explicitly copies. |
| `File.Write.atomic(bytes, options)` (temp + rename + fsync) | Known pattern, rarely first-class | 3 | **Ahead of prior art**. Configurable durability (.barrier vs .full fsync) and strategy (.rename vs .exchange) as a single API call. Most systems leave crash-safe writes to application code. |
| `File.Write.append(bytes)` | POSIX `O_APPEND`, Go `os.OpenFile(O_APPEND)` | 2 | **Correct**. |
| `File.Write.streaming(chunks, options)` with multi-phase open→write→commit | Unusual for file IO; closer to WAL/database commit patterns | 3 | **Distinctive**. Configurable atomicity (temp + rename or direct), durability (fsync granularity), and a reusable-buffer `fill:` API for producer-driven streaming. Production-grade. |
| `File.Write.streaming(chunks)` async variant via `IO.Lane` | tokio `spawn_blocking` + fs operations | 2 | **Correct**. Offloads blocking file writes to IO lane. Typed error: `IO.Failure.Work<IO.Lane.Error, Streaming.Error>`. |
| `File.Directory.Contents.iterate { entry → .continue/.break }` | POSIX `opendir`/`readdir`, Go `os.ReadDir`, Rust `fs::read_dir` | 2 | **Ahead**. Callback-based zero-allocation iteration. Prior art returns owned collections or lazy iterators that still allocate per-entry. |
| `File.Directory.Walk` (recursive, inode-cycle detection) | Go `filepath.Walk`, Rust `walkdir`, Python `os.walk` | 2 | **Correct**. Inode-based cycle detection is production-grade. |
| `Binary.Serializable` integration on write | — | 3 | **Distinctive**. Write a serializable type directly to disk without manual encoding step. |
| Typed throws on every operation | Zig error unions | 3 | **On par with Zig**. Semantic accessors (`.isNotFound`, `.isPermissionDenied`) on error types provide ergonomic matching without losing type information. |
| `Either<FileError, ClosureError>` for dual-error callbacks | — | 3→4 | **Justified**. Natural typed-throws encoding when both infrastructure and user code can fail. |

#### Read/Write Architecture: Layered Concrete Types

The ecosystem provides read/write operations at every layer of the stack:

| Layer | API | Scope |
|-------|-----|-------|
| L1 | `Kernel.IO.Read` / `Kernel.IO.Write` | Namespace + typed error types |
| L2 | `ISO_9945.Kernel.IO.Write.write(fd, from:)` | Raw POSIX syscall |
| L3 | `POSIX.Kernel.IO.Write.write(fd, from:)` | EINTR-safe wrapper + `Span<UInt8>` adapters |
| L3 | `Kernel.IO.Read.read(fd, into:)` / `.pread(fd, into:, at:)` | Callable descriptor API |
| L3 | `File.Handle.read(into:)` / `.write(_:)` / `.pwrite(_:, at:)` | Handle-based methods (~Copyable) |
| L3 | `File.Read.full { span in }` / `File.Write.atomic` / `.append` / `.streaming` | High-level file operations |
| L3 | `IO.Event.Channel.read(into:)` / `.write(_:)` | Async event-driven (epoll/kqueue) |
| L3 | `IO.Completion.Read` / `.Write` | Completion-based (io_uring/IOCP) |

This is a **layered concrete type** approach rather than a **composable trait** approach.

**Why not a generic Reader/Writer trait?**

Most surveyed systems define a composable IO abstraction — Go's `io.Reader`, Rust's `Read`, Java's `InputStream` — enabling pipelines like `BufReader<GzDecoder<File>>`. An initial draft of this audit flagged the absence of an equivalent as a potential gap. On closer examination, it is not.

A hypothetical `IO.Readable` protocol (or `IO.Reader` witness) would need a single `read(into:) -> Int` method. But the types that would conform have fundamentally different semantics:

| Type | Error type | Ownership | Domain-specific capabilities |
|------|-----------|-----------|------------------------------|
| `File.Handle` | `Kernel.IO.Read.Error` | `~Copyable`, `mutating` | seek, sync, pread, metadata |
| `IO.Event.Channel` | `IO.Event.Failure` | `~Copyable`, `async` | half-close, shutdown, arm/suspend |
| `IO.Completion.Read` | `IO.Completion.Error` | `~Copyable`, move-only operation | buffer ownership transfer, kernel-side execution |
| Descriptor-level | `Kernel.IO.Read.Error` | Stateless static function | EINTR retry policy |

A generic trait would need to erase the error type (violating [API-ERR-001] typed throws), ignore ownership differences, and hide domain-specific capabilities behind the lowest common denominator — precisely the .NET `Stream` mistake where a single base class serves all IO domains, and callers discover capabilities at runtime (`CanSeek`, `CanWrite`).

The ecosystem's philosophy — domain-specific types with full type information — is the deliberate alternative. Go gets away with `io.Reader` because Go has no typed errors, no ownership system, and no generics (historically). Rust gets away with `Read` because the trait only requires one method and all the real work happens on the concrete type. But in both ecosystems, the trait adds *less* than it appears: Go's `os.File` has 20+ methods beyond `Read`/`Write`; Rust's `File` has `metadata()`, `sync_all()`, `set_permissions()`, `try_clone()` — none expressible through `Read`.

The layered concrete approach is closer to Zig 0.15.1+ (concrete types with methods at each layer, no Reader trait) and Swift System (`FileDescriptor.read(into:)` as a method, not a protocol conformance) — both of which are modern designs that arrived at the same conclusion independently.

**Verdict**: **Correct architecture, not a gap**. Read/write is present and well-typed at every layer, with domain-appropriate error types and ownership semantics preserved. A generic trait would erase type information that the ecosystem's design philosophy exists to preserve.

**swift-file-system verdict**: ~13 concepts, all Tier 1-3. Zero-copy reads via Span, first-class atomic writes, and callback-based zero-allocation directory iteration are ahead of surveyed prior art. **No unnecessary concepts; several innovations.**

---

## Synthesis

### Quantitative Summary

| Category | Concepts | Tier 1-2 | Tier 3 | Tier 4 / Paradigm | Novel |
|----------|---------|----------|--------|--------------------|-------|
| Kernel (L1) | 12 | 12 | 0 | 0 | 0 |
| IO Core | 5 | 3 | 1 | 1 | 0 |
| IO Events | ~18 | ~13 | ~3 | ~2 | 0 |
| IO Completions | ~15 | ~15 | 0 | 0 | 0 |
| IO Blocking | ~10 | ~6 | ~3 | ~1 | 0 |
| IO Executor | ~12 | ~7 | ~3 | ~1 | 1 |
| File System | ~13 | ~8 | ~4 | ~1 | 0 |
| **Total** | **~85** | **~64 (75%)** | **~14 (16%)** | **~6 (7%)** | **1 (1%)** |

### The File Count vs. Concept Count Question

swift-io has **279 source files** for **~72 concepts** (~4:1 ratio). This reflects three ecosystem conventions, not conceptual bloat:

1. **[API-IMPL-005] One type per file** — each type gets its own file
2. **[API-NAME-001] Namespace-first structure** — `IO.Blocking.Lane.Abandoning.Job.Transition.Error` is 7 levels deep
3. **Error decomposition** — each error type is a separate file

The decomposition is **isomorphic** to prior art — the same concepts, differently organized on disk.

### What the IO Stack Gets Right Relative to Prior Art

**Infrastructure (swift-io):**

1. **Dual-model IO** (events + completions) as first-class peers. Most systems are either readiness-based (mio, NIO) or completion-based (tokio-uring) but not both. Only Zig 0.15.1+ does something similar.

2. **Compile-time resource safety** via `~Copyable`. Where Rust has `OwnedFd`/`BorrowedFd` and Go has documentation-only contracts, swift-io enforces ownership at the type level. This carries through to `File.Descriptor` and `File.Handle` in swift-file-system.

3. **Type-state for event loop registration**. Where mio and NIO use runtime checks, swift-io uses consuming tokens for compile-time enforcement.

4. **Witness structs instead of protocols** for platform abstraction. Avoids existential overhead and Swift Embedded incompatibility. Zig 0.15.1's vtable-in-struct is analogous.

5. **Typed throws throughout the entire stack**. Composite errors (`IO.Lifecycle.Error<Either<Lane.Error, E>>`, `Either<File.System.Read.Full.Error, E>`, `IO.Failure.Work<IO.Lane.Error, Streaming.Error>`). Only Zig achieves comparable error precision.

**File operations (swift-file-system):**

6. **Zero-copy read via `Span<UInt8>` callback**. `file.read.full { span in ... }` borrows file contents without copying. Every other surveyed system returns owned data. Strictly better for large files.

7. **First-class atomic write** with configurable durability. `file.write.atomic(bytes)` does temp-file + rename + optional fsync in a single call. Most systems leave crash-safe writes to application code.

8. **Streaming write with multi-phase lifecycle**. Open → write chunks → commit/cleanup with configurable atomicity and durability. The reusable-buffer `fill:` API enables producer-driven streaming without per-chunk allocation.

9. **Zero-allocation directory iteration**. `File.Directory.Contents.iterate { entry → .continue }` never allocates per-entry. Prior art (Go `os.ReadDir`, Rust `fs::read_dir`) returns owned collections or allocating iterators.

10. **Scoped file access with dual-error preservation**. `File.Handle.Open.read { handle in ... }` returns `Error<ClosureError>` distinguishing open, operation, and close errors. Most prior art drops close errors silently.

### What Warrants Monitoring

1. **IO.Blocking.Threads decomposition (52 files)**. Individually justified but high cognitive load. Complexity is inherent to a production thread pool.

2. **IO.Executor layer is thinnest on prior art**. Handle/Registry/Slot/Transaction/Teardown has limited prior art because it solves Swift-specific problems. Needs design review as it evolves.

3. **No generic Reader/Writer trait — by design**. Initial analysis flagged this as a potential gap; deeper examination concluded it is the correct architecture. A generic trait would erase typed errors ([API-ERR-001]), ignore ownership differences across IO domains, and hide domain-specific capabilities. The layered concrete approach preserves full type information at every layer. See "Read/Write Architecture" analysis in the swift-file-system section for the full reasoning.

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: Correct and Necessary

The IO stack (swift-io + swift-file-system) **does not** introduce too many custom concepts. The audit found:

- **Zero gratuitous abstractions** — every concept maps to recognized prior art or solves a real problem
- **Zero missing Tier 1 concepts** — all universal IO concepts are present (descriptors, read, write, close, error, buffer, seek)
- **Tier 2 completeness** — event loop, completion queue, registration, polling, drivers, wakeup, buffering, deadlines, scoped access, directory iteration
- **1 truly novel concept** (`IO.Executor.Slot`) — justified by Swift's unique actor + ~Copyable combination
- **6 paradigm-specific adaptations** — all justified by Swift's type system (identical patterns exist in Rust)
- **Several areas ahead of prior art** — zero-copy Span reads, first-class atomic writes, zero-allocation directory iteration, dual-error scoped access

The apparent complexity comes from the ecosystem's namespace-first file organization, dual-model IO (events AND completions), and Swift-specific safety features that add types but improve correctness.

### Architectural Layering Assessment

```
Kernel primitives (L1)  →  typed descriptors, events, errors, socket/file primitives
swift-io (L3)           →  event loop, completion queue, thread pool, executor
swift-file-system (L3)  →  file-specific operations: zero-copy read, atomic write,
                            streaming write, scoped access, directory iteration
```

Each layer does its job without overreaching. swift-io provides infrastructure; swift-file-system provides domain-specific operations. The Reader/Writer trait composability layer (if needed for network/compression/TLS) would sit alongside these, not inside them.

### Recommendation for Design Evolution

As the IO stack evolves, apply this prior art test to new concepts: *does it map to a recognized pattern, or is it novel?* Novel is acceptable when justified — `IO.Executor.Slot` demonstrates this. Novel without justification should be challenged.

The absence of a generic Reader/Writer trait is a deliberate design decision, not a gap. Each IO domain has distinct error types, ownership semantics, and capabilities that a generic trait would erase. See the "Read/Write Architecture" analysis for the full reasoning and comparison against Go/Rust/Zig.

## References

### Primary Sources (by system)

**Rust**: `std::io` module documentation; tokio-rs/tokio; tokio-rs/mio; tokio-rs/tokio-uring; bytedance/monoio

**Go**: `io`, `bufio`, `os`, `net` package documentation; Go runtime `netpoll_*.go` source

**Java**: `java.io`/`java.nio`/`java.nio.channels` Javadoc; JEP 444 (Virtual Threads)

**.NET**: `System.IO.Stream`; `System.IO.Pipelines`; `Span<T>` design; Kestrel architecture

**Zig**: `std.io` source (pre-0.15 and 0.15.1+); `std.fs`; `std.net`; Zig 0.15 release notes

**OCaml**: `Pervasives`/`Unix` module documentation; Eio repository; "Retrofitting Effects onto OCaml" (Sivaramakrishnan et al.)

**Haskell**: `System.IO` Hackage; conduit/pipes libraries; GHC IO manager documentation

**Swift**: SwiftNIO repository; Swift System repository and blog post

**OS-level**: Axboe, "Efficient IO with io_uring"; epoll(7), kqueue(2) man pages; Microsoft IOCP documentation; libuv design overview

**Academic**: Plotkin & Pretnar, "Handlers of Algebraic Effects" (2009); Leijen, "Algebraic Effects for Functional Programming"; Bernardy et al., "Linear Haskell" (2018); Strom & Yemini, "Typestate" (1986)

## Update: Apple HTTP API Proposal (2026-04-02)

Apple's `swift-http-api-proposal` is now a concrete reference implementation of the Span-based streaming model this research recommended. Key observations:

- **AsyncReader** uses `@_lifetime(&self)` + `consuming Span<ReadElement>` body — validates the zero-copy borrowed-pointer recommendation from Part I. The caller receives a non-owning view into the reader's internal buffer; no allocation or copy occurs on the read path.
- **AsyncWriter** uses `OutputSpan<WriteElement>` as the write-buffer API — callers append into the span inside a closure (`(inout OutputSpan<WriteElement>) async throws(Failure) -> Result`). The writer manages buffer allocation; the caller only sees a safe, bounded output region.
- **Apple bypasses AsyncSequence/AsyncStream entirely** — custom `AsyncReader` and `AsyncWriter` protocols from scratch, both `~Copyable & ~Escapable`. This aligns with Part I's finding that type-erased async sequences are a poor fit for IO streaming (Tier 1 "Universal" concepts need direct protocol-level support, not adaptation).
- **`EitherError<ReadFailure, Failure>`** for typed throws in streaming confirms the typed-error recommendation. Every read/write method uses typed throws with `EitherError` to separate infrastructure errors from user-closure errors — no existential `any Error` erasure on the fast path.

**Source**: `https://github.com/apple/swift-http-api-proposal/tree/main/Sources/AsyncStreaming/`
