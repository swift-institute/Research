# IO Uring Implementation Study: Rust io-uring Crate

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: DECISION
---
-->

## Context

We are building a Swift io_uring binding at the primitives layer (L1). The Rust `tokio-rs/io-uring` crate (v0.7.11) is the most mature and widely-deployed userspace io_uring binding outside of C's liburing. It wraps the three Linux syscalls (`io_uring_setup`, `io_uring_enter`, `io_uring_register`) and the shared-memory ring buffer protocol into a Rust API that balances safety with zero overhead. This study extracts architectural patterns and safety decisions relevant to our Swift design.

Repository: `https://github.com/tokio-rs/io-uring`
License: MIT OR Apache-2.0
Minimum Rust: 1.63
Lines of code: ~4,500 (excluding generated bindings)

## Implementation Analysis

### Type System and FFI

**Kernel struct representation.** The crate uses `bindgen`-generated Rust structs that mirror the kernel's C definitions exactly. The central types are:

- `io_uring_sqe` (64 bytes): 8 fixed fields + 6 anonymous unions (`__bindgen_ty_1` through `__bindgen_ty_6`). The unions overlay operation-specific fields onto the same memory. For example, `__bindgen_ty_3` is a union of 24 fields: `rw_flags`, `fsync_flags`, `poll_events`, `msg_flags`, `accept_flags`, `cancel_flags`, `open_flags`, `timeout_flags`, etc. Each opcode interprets the same 4 bytes differently.

- `io_uring_cqe` (16 bytes): Three fields (`user_data: u64`, `res: i32`, `flags: u32`) plus an incomplete array field `big_cqe` for 32-byte CQEs.

- `io_uring_params`: Setup parameters struct returned by `io_uring_setup`, containing `sq_off: io_sqring_offsets` and `cq_off: io_cqring_offsets` that provide byte offsets into the mmap'd memory regions.

**Safe wrappers over FFI unions.** The crate wraps the raw FFI types in newtype structs:

```rust
// squeue.rs
#[repr(C)]
pub struct Entry(pub(crate) sys::io_uring_sqe);

// cqueue.rs
#[repr(C)]
pub struct Entry(pub(crate) sys::io_uring_cqe);
```

Users never touch the union fields directly. Instead, opcode builders produce `squeue::Entry` values with the correct union fields set. The CQE wrapper exposes only `result()`, `user_data()`, and `flags()` -- the three fields that are meaningful regardless of which operation completed.

**Extended entries.** Both SQE and CQE support extended sizes (128-byte SQE, 32-byte CQE) through separate types:

```rust
pub struct Entry128(pub(crate) Entry, pub(crate) [u8; 64]);  // SQE
pub struct Entry32(pub(crate) Entry, pub(crate) [u64; 2]);   // CQE
```

A sealed `EntryMarker` trait unifies them, carrying a `BUILD_FLAGS` constant that informs `io_uring_setup` whether extended entries are needed:

```rust
pub trait EntryMarker: Clone + Debug + From<Entry> + private::Sealed {
    const BUILD_FLAGS: u32;
}
impl EntryMarker for Entry { const BUILD_FLAGS: u32 = 0; }
impl EntryMarker for Entry128 { const BUILD_FLAGS: u32 = sys::IORING_SETUP_SQE128; }
```

**Architecture-specific bindings.** Prebuilt `sys_x86_64.rs`, `sys_aarch64.rs`, `sys_riscv64.rs`, `sys_loongarch64.rs`, and `sys_powerpc64.rs` files contain bindgen output. A `cfg_if` block selects the correct one at compile time. Users on unsupported architectures can enable the `bindgen` feature or supply custom bindings via `IO_URING_OWN_SYS_BINDING`.

### Ownership and Safety

**Ring memory ownership.** The `IoUring` struct owns all ring resources:

```rust
pub struct IoUring<S = squeue::Entry, C = cqueue::Entry> {
    sq: squeue::Inner<S>,
    cq: cqueue::Inner<C>,
    fd: OwnedFd,
    params: Parameters,
    memory: ManuallyDrop<MemoryMap>,
}
```

`MemoryMap` holds three `Mmap` regions (SQ ring, SQE array, optionally separate CQ ring if `IORING_FEAT_SINGLE_MMAP` is not set). `ManuallyDrop` ensures the memory is unmapped before the file descriptor is closed (drop order matters: munmap before close).

The `OwnedFd` wraps the io_uring file descriptor and closes it on drop. A custom implementation is provided for Rust < 1.63 compatibility, while newer versions use `std::os::unix::io::OwnedFd`.

**The `Mmap` wrapper:**

```rust
pub(crate) struct Mmap {
    addr: ptr::NonNull<libc::c_void>,
    len: usize,
}
```

Maps with `PROT_READ | PROT_WRITE` and `MAP_SHARED | MAP_POPULATE`. The `MAP_SHARED` flag is critical: this creates the shared-memory region between userspace and kernel. `MAP_POPULATE` prefaults pages to avoid page faults on first access.

**The aliasing problem.** Both userspace and the kernel write to the same mmap'd memory concurrently. The crate resolves this via:

1. Raw pointers (`*const AtomicU32`, `*mut E`) stored in `Inner`, not references.
2. Atomic operations for all shared indices (head, tail, flags).
3. A borrow-based API that prevents simultaneous mutable access from the Rust side.

**The `Inner` / borrowed view split.** Both `squeue::Inner<E>` and `cqueue::Inner<E>` store raw pointers to the mmap'd memory. They are not directly user-facing. Instead, `SubmissionQueue<'a, E>` and `CompletionQueue<'a, E>` are short-lived borrowed views that cache the head/tail locally:

```rust
pub struct SubmissionQueue<'a, E: EntryMarker = Entry> {
    head: u32,      // local copy, loaded from atomic on creation
    tail: u32,      // local copy, flushed to atomic on sync/drop
    queue: &'a Inner<E>,
}
```

This design means push/pop operations work on local copies (no atomics in the hot path). The atomic store/load happens only at `sync()` or when the borrowed view is dropped.

**Send + Sync.** `IoUring` implements both `Send` and `Sync`, making it safe to share across threads. The `split()` method is the primary multi-access pattern:

```rust
pub fn split(&mut self) -> (Submitter<'_>, SubmissionQueue<'_, S>, CompletionQueue<'_, C>)
```

This borrows `&mut self`, preventing aliasing. For shared access (e.g., submission from one thread while completing on another), `unsafe` methods `submission_shared()` and `completion_shared()` are provided -- the caller must ensure no concurrent mutable access.

### Opcode Builders

**Macro-generated type-safe builders.** Each io_uring operation is a separate struct generated by the `opcode!` macro. The macro takes:

- Required fields (before `;;`)
- Optional fields with defaults (after `;;`)
- An opcode constant
- A `build()` method body

Example (Read operation):

```rust
opcode! {
    pub struct Read {
        fd: { impl sealed::UseFixed },
        buf: { *mut u8 },
        len: { u32 },
        ;;
        offset: u64 = 0,
        ioprio: u16 = 0,
        rw_flags: i32 = 0,
        buf_group: u16 = 0
    }
    pub const CODE = sys::IORING_OP_READ;

    pub fn build(self) -> Entry {
        let Read { fd, buf, len, offset, ioprio, rw_flags, buf_group } = self;
        let mut sqe = sqe_zeroed();
        sqe.opcode = Self::CODE;
        assign_fd!(sqe.fd = fd);
        sqe.ioprio = ioprio;
        sqe.__bindgen_anon_2.addr = buf as _;
        sqe.len = len;
        sqe.__bindgen_anon_1.off = offset;
        sqe.__bindgen_anon_3.rw_flags = rw_flags as _;
        sqe.__bindgen_anon_4.buf_group = buf_group;
        Entry(sqe)
    }
}
```

Key design decisions:

1. **Constructor requires all mandatory fields.** `Read::new(fd, buf, len)` -- you cannot forget the fd or buffer.
2. **Optional fields use consuming builder methods.** `.offset(42).ioprio(1)` -- each returns `Self` by value.
3. **`build()` consumes the builder** and produces an `squeue::Entry`.
4. **`sqe_zeroed()`** starts from a zeroed SQE, ensuring all unused union fields are zero. This is critical because the kernel checks for non-zero fields it does not expect.
5. **File descriptor polymorphism.** The `sealed::UseFixed` trait accepts both `Fd(RawFd)` (unregistered) and `Fixed(u32)` (registered). The `assign_fd!` macro sets the fd field and conditionally sets `FIXED_FILE` flag.

**Operation count.** The crate defines ~60 operations covering: basic I/O (Read, Write, Readv, Writev), file operations (OpenAt, Close, Statx, Ftruncate), socket operations (Accept, Connect, Send, Recv, SendMsg, RecvMsg), splice/tee, polling, timeouts, cancellation, buffer management, futex operations, and zerocopy variants (SendZc, RecvZc).

**Post-build decoration.** After `build()`, the `Entry` supports chaining:

```rust
let entry = opcode::Read::new(types::Fd(fd), buf.as_mut_ptr(), buf.len() as _)
    .offset(0)
    .build()
    .user_data(0x42)
    .flags(squeue::Flags::IO_LINK);
```

`user_data()` and `flags()` are on `Entry`, not on the opcode builder. This separates operation semantics from submission metadata.

### Ring Management

**Three-way split.** The `IoUring` struct provides three access patterns:

1. **`submission(&mut self)`** -- exclusive access to SQ
2. **`completion(&mut self)`** -- exclusive access to CQ
3. **`split(&mut self)`** -- simultaneous access to Submitter + SQ + CQ

The `Submitter` is a separate type that holds raw pointers to the SQ head/tail/flags and the ring fd. It handles the `io_uring_enter` syscall.

**Submission flow:**

```
1. sq = ring.submission()         // borrow SQ, load head atomically, load tail non-atomically
2. sq.push(&entry)                // write entry to sqes[tail & mask], increment local tail
3. sq.sync()                      // store tail atomically (Release), reload head (Acquire)
4. drop(sq)                       // also stores tail atomically on drop
5. ring.submit()                  // calls io_uring_enter syscall
```

The local tail write in step 2 does NOT use atomics -- it writes directly to the SQE array at the masked index. The kernel only reads entries between the last-stored tail and the current tail, and the Release store in step 3/4 ensures ordering.

**Completion flow:**

```
1. cq = ring.completion()         // borrow CQ, load head non-atomically, load tail with Acquire
2. for entry in &mut cq { ... }   // iterate: read CQE at head & mask, increment local head
3. cq.sync()                      // store head atomically (Release), reload tail (Acquire)
4. drop(cq)                       // also stores head atomically on drop
```

**SQE array initialization.** In `squeue::Inner::new()`, the indirection array is initialized to identity mapping:

```rust
for i in 0..ring_entries {
    array.add(i as usize).write_volatile(i);
}
```

This maps SQ index `i` directly to SQE slot `i`, eliminating the indirection. The comment says "To keep it simple, map it directly." This means the crate does not use the SQ indirection array's reordering capability.

### Memory Ordering

**The four ordering patterns used:**

1. **`Release` store** on tail (SQ) and head (CQ) when flushing local changes to the kernel-visible atomic. This ensures all prior SQE/CQE memory writes are visible before the index update.

2. **`Acquire` load** on head (SQ) and tail (CQ) when reading kernel-produced updates. This ensures subsequent reads of SQE/CQE memory see the kernel's writes.

3. **`SeqCst` fence** before reading `IORING_SQ_NEED_WAKEUP` flag. This is the most subtle ordering requirement. The comment in the source explains:

   > The kernel first writes the wake flag, then performs a full barrier (smp_mb), then reads the head. We first write the head and then read the need_wakeup flag. By establishing a point of sequential consistency on both sides, at least one observes the other write.

   Without this fence, a TOCTOU race could cause the kernel thread to sleep permanently: userspace writes SQEs and sees "no wakeup needed", while the kernel sets "need wakeup" and sees "no new SQEs".

4. **`unsync_load`** for reading our own tail/head without atomics:

   ```rust
   pub(crate) unsafe fn unsync_load(u: *const atomic::AtomicU32) -> u32 {
       *u.cast::<u32>()
   }
   ```

   This is a non-atomic read of an atomic location. It is safe because only our thread writes this value; the kernel only reads it. The Acquire load of the other side's counter provides the necessary happens-before.

**SQPOLL mode.** When the kernel polls the SQ autonomously (`IORING_SETUP_SQPOLL`), the submit path must check if the kernel thread is asleep. The `submit_and_wait` method handles this:

```rust
if self.params.is_setup_sqpoll() {
    atomic::fence(atomic::Ordering::SeqCst);
    if self.sq_need_wakeup() {
        flags.insert(EnterFlags::SQ_WAKEUP);
    } else if want == 0 && !need_syscall_for_overflow {
        return Ok(len);  // kernel is polling, skip syscall entirely
    }
}
```

### Lifetime Management

**The buffer-lifetime gap.** io_uring's fundamental challenge: when you submit a read, the buffer must remain valid until the corresponding CQE arrives. The Rust crate does NOT enforce this at the type level. Instead, it marks `push()` as `unsafe`:

```rust
/// # Safety
///
/// Developers must ensure that parameters of the entry (such as buffer) are valid and will
/// be valid for the entire duration of the operation, otherwise it may cause memory problems.
pub unsafe fn push(&mut self, entry: &E) -> Result<(), PushError>
```

The opcode builders accept raw pointers (`*mut u8`, `*const libc::iovec`), not references with lifetimes. This is a deliberate choice: Rust's borrow checker cannot express "this borrow lasts until a CQE with matching user_data appears." The safety burden is on the caller.

**What IS lifetime-checked.** The `SubmitArgs` type uses phantom lifetimes to ensure referenced data outlives the submission:

```rust
pub struct SubmitArgs<'prev: 'now, 'now> {
    pub(crate) args: sys::io_uring_getevents_arg,
    prev: PhantomData<&'prev ()>,
    now: PhantomData<&'now ()>,
}
```

When you chain `.sigmask(&mask).timespec(&ts)`, each step shortens the lifetime, preventing dangling pointers to stack-local sigmasks/timespecs. But this only covers the synchronous `io_uring_enter` arguments, not the asynchronous operation buffers.

**Registered buffers.** The `register_buffers()` method is also `unsafe` for the same reason: the registered iovec pointers must remain valid until unregistered or the ring is destroyed. No lifetime enforcement is possible.

### API Ergonomics

**Typical usage -- submitting a read:**

```rust
let ring = IoUring::new(256)?;
let fd = /* open file */;
let mut buf = vec![0u8; 4096];

// Build the SQE (1 line)
let read_e = opcode::Read::new(types::Fd(fd), buf.as_mut_ptr(), buf.len() as _)
    .build()
    .user_data(0x42);

// Submit (3 lines)
unsafe { ring.submission().push(&read_e)?; }
ring.submit_and_wait(1)?;

// Consume completion (2 lines)
let cqe = ring.completion().next().unwrap();
assert_eq!(cqe.user_data(), 0x42);
let bytes_read = cqe.result();
```

Total: ~7 lines for a complete async read. The builder pattern means the SQE construction is a single expression. The `user_data` is the user's correlation mechanism -- the crate provides no higher-level future/callback abstraction.

**The `split()` pattern for concurrent access:**

```rust
let (submitter, mut sq, mut cq) = ring.split();
unsafe { sq.push(&entry)?; }
sq.sync();
submitter.submit()?;

// Meanwhile, on completion side:
cq.sync();
for cqe in &mut cq {
    // process
}
```

**Builder configurability.** Ring creation supports extensive tuning:

```rust
let ring = IoUring::builder()
    .setup_sqpoll(1000)        // kernel-side SQ polling, 1s idle timeout
    .setup_cqsize(4096)        // separate CQ size
    .setup_single_issuer()     // optimize for single-thread submission
    .setup_coop_taskrun()      // cooperative task running
    .build(256)?;              // 256 SQ entries
```

## Lessons for Swift

### 1. Union handling demands a strategy

The SQE's 6 anonymous unions with 24+ operation-specific fields are the core API design challenge. Rust uses bindgen-generated Rust unions accessed through opcode builder `build()` methods. Swift has no equivalent of Rust unions. Options:

- **C overlay structs** imported via the C shim, with Swift extensions that provide typed access. This is the most direct path.
- **A single `IO.Uring.Submission.Entry` struct** that stores a `Linux.io_uring_sqe` value and exposes no public field access. All population goes through opcode witness types.

The Rust crate's approach -- zero the SQE, set fields through the builder, wrap in newtype -- maps well to Swift witnesses that take the SQE by `inout` reference.

### 2. The safety boundary should be at push, not at build

Rust's `push()` is `unsafe` while opcode `build()` is safe. This is correct: building an SQE is just filling in a struct. The danger is submitting it, because that creates the kernel-side obligation to keep buffers alive. In Swift, the equivalent is making the push method `consuming` or requiring a proof token that the caller has retained the buffer.

Since Swift lacks `unsafe` as a first-class concept, the safety boundary could be expressed as:
- `~Copyable` entry types that must be explicitly consumed by the push operation.
- A `borrowing` parameter on the push method that documents the contract.
- Or simply: clear documentation, since Swift also cannot express "this borrow lasts until a CQE with matching user_data."

### 3. Local-copy-then-flush is the right ring access pattern

The Rust crate's `SubmissionQueue` caches head/tail locally, does non-atomic pushes, then flushes with a single Release store. This avoids atomic operations in the hot loop. The same pattern works in Swift:

- Load head with `atomicLoad(.acquiring)` on creation.
- Load tail with non-atomic read (we are the only writer).
- Push entries without atomics.
- Flush tail with `atomicStore(.releasing)`.

The `unsync_load` trick (casting `AtomicU32*` to `UInt32*` for a non-atomic read) maps to Swift's `UnsafePointer<UInt32>` load from an `UnsafePointer<UInt32.AtomicRepresentation>` reinterpretation.

### 4. The SeqCst fence for SQPOLL wakeup is non-negotiable

The Rust crate's careful treatment of the SQPOLL wakeup race -- with extensive comments citing the kernel's `smp_mb` and the need for bilateral sequential consistency -- is a real correctness requirement, not defensive programming. Our Swift implementation must replicate this exact fence.

### 5. ManuallyDrop ordering maps to Swift's deinit ordering

The Rust crate uses `ManuallyDrop<MemoryMap>` to control drop order: munmap before close(fd). In Swift with `~Copyable` types, we control this in `deinit` by ordering the cleanup operations explicitly. The `Mmap` equivalent should be a `~Copyable` type whose `deinit` calls `munmap`.

### 6. The opcode macro pattern maps to Swift witness types

Each Rust opcode struct (Read, Write, Accept, etc.) with its required/optional fields and `build()` method maps naturally to our witness pattern:

```swift
// Equivalent Swift pattern
extension IO.Uring.Opcode {
    struct Read: ~Copyable {
        // Required at init
        let fd: IO.Uring.FileDescriptor
        let buffer: UnsafeMutableRawBufferPointer
        // Optional with defaults
        var offset: UInt64 = 0
        var priority: UInt16 = 0
        
        consuming func build() -> IO.Uring.Submission.Entry { ... }
    }
}
```

The `sealed::UseFixed` trait that accepts both `Fd` and `Fixed` maps to a protocol or enum: `IO.Uring.FileDescriptor` with `.raw(RawFd)` and `.registered(UInt32)` cases.

### 7. CQE is trivially simple -- do not over-engineer it

The completion entry is just three fields: `result`, `user_data`, `flags`. The Rust crate wraps it in a newtype with three getters. Our Swift equivalent should be equally minimal. The `Entry32` extension (for 32-byte CQEs) can be a separate type with the additional `big_cqe` payload.

### 8. The ring fd + mmap regions form one ownership unit

The Rust crate groups `OwnedFd` + `MemoryMap` + `squeue::Inner` + `cqueue::Inner` + `Parameters` into one `IoUring` struct. This is correct. In Swift:

```
IO.Uring (owns everything)
  ├── fd: OwnedFd (~Copyable)
  ├── memory: MemoryMap (~Copyable, munmap on deinit)
  ├── sq: SubmissionQueue.Storage (raw pointers into mmap'd memory)
  ├── cq: CompletionQueue.Storage (raw pointers into mmap'd memory)
  └── params: Parameters (value type, copyable)
```

### 9. Buffer registration is an unsafe contract with no lifetime solution

Neither Rust nor Swift can express "these buffers must live until unregistered." Both languages must mark this as unsafe / document the contract. Do not attempt to solve this with lifetimes or ~Escapable -- it is fundamentally a dynamic-lifetime problem driven by kernel state.

### 10. Three syscalls, that is the entire FFI surface

The entire kernel interface is three functions: `io_uring_setup`, `io_uring_enter`, `io_uring_register`. The C shim layer for Swift should expose exactly these three, plus the struct definitions. Everything else is userspace logic built on mmap'd shared memory.

## References

- Repository: https://github.com/tokio-rs/io-uring (v0.7.11)
- Kernel documentation: https://www.kernel.org/doc/html/latest/userspace-api/io_uring.html
- Companion study (Zig): `/Users/coen/Developer/swift-primitives/Research/io-uring-impl-study-zig-std.md`
- API reference: `/Users/coen/Developer/swift-primitives/Research/linux-io-uring-api-reference.md`
- Atomic ordering study: `/Users/coen/Developer/swift-primitives/Research/kernel-atomic-memory-ordering.md`
