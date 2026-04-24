# IO Uring Implementation Study: liburing (C Reference)

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: DECISION
---
-->

## Context

liburing is the canonical C user-space wrapper for Linux io_uring, written and maintained by io_uring's author Jens Axboe. It lives at https://github.com/axboe/liburing. This study analyzes the reference implementation to extract API design patterns and architectural lessons for a Swift binding (`IO.Uring` in swift-linux-primitives).

liburing is the definitive source for how io_uring should be used from user space. Every serious io_uring consumer (QEMU, RocksDB, Tokio, etc.) either uses liburing directly or replicates its patterns. Understanding what it does and what it deliberately does not do is essential before designing a Swift API.

## Implementation Analysis

### API Layering

liburing has four distinct layers, each progressively thicker:

**Layer 0: Raw syscall wrappers** (~10 lines each, in `syscall.h`)

Three syscalls form the entire kernel interface:
- `__sys_io_uring_setup(entries, params)` -- creates the ring
- `__sys_io_uring_enter(fd, to_submit, min_complete, flags, sig)` -- submits and/or waits
- `__sys_io_uring_register(fd, opcode, arg, nr_args)` -- registers resources

Plus `__sys_io_uring_enter2()` which adds an `arg` + `sz` pair for extended arguments (timeouts, registered wait regions). These are thin `syscall()` calls with no logic.

**Layer 1: Ring management** (~400 lines, in `setup.c`)

Setup and teardown of `struct io_uring`:
- `io_uring_queue_init(entries, ring, flags)` -- the simplest entry point
- `io_uring_queue_init_params(entries, ring, params)` -- with full params control
- `io_uring_queue_init_mem(entries, ring, params, buf, buf_size)` -- app-provided memory (huge pages)
- `io_uring_queue_exit(ring)` -- teardown (munmap + close)
- `io_uring_queue_mmap(fd, params, ring)` -- mmap after manual setup

This layer handles: mmap of SQ/CQ rings and SQE array, pointer setup from kernel-provided offsets, SQ-to-SQE identity mapping, feature detection, internal flags.

**Layer 2: Submission and completion queue operations** (~500 lines, in `queue.c` + inline in `liburing.h`)

SQE acquisition:
- `io_uring_get_sqe(ring)` -- returns next vacant SQE or NULL

Submission:
- `io_uring_submit(ring)` -- flush SQ and enter kernel
- `io_uring_submit_and_wait(ring, wait_nr)` -- submit + wait for completions
- `io_uring_submit_and_wait_timeout(ring, cqe_ptr, wait_nr, ts, sigmask)` -- submit + wait with timeout
- `io_uring_submit_and_wait_min_timeout(...)` -- with minimum wait threshold
- `io_uring_submit_and_wait_reg(ring, cqe_ptr, wait_nr, reg_index)` -- using pre-registered wait params

Completion:
- `io_uring_peek_cqe(ring, cqe_ptr)` -- non-blocking peek
- `io_uring_wait_cqe(ring, cqe_ptr)` -- wait for exactly one
- `io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr)` -- wait for N
- `io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts, sigmask)` -- wait with timeout
- `io_uring_peek_batch_cqe(ring, cqes, count)` -- batch non-blocking peek (fills array of CQE pointers)
- `io_uring_cqe_seen(ring, cqe)` -- mark one CQE consumed
- `io_uring_cq_advance(ring, nr)` -- mark N CQEs consumed
- `io_uring_for_each_cqe(ring, head, cqe)` -- iteration macro

**Layer 3: Prep helpers** (~100 inline functions in `liburing.h`)

103 `io_uring_prep_*` functions covering all 56 unique opcodes plus variants (multishot, direct, zero-copy, bundle, fixed buffer, etc.). These are the highest layer and by far the largest by line count (~1200 lines, over half the header).

### Prep Helpers

The prep helpers follow a strict two-tier pattern:

**Tier A: `io_uring_prep_rw` -- the universal initializer**

```c
IOURINGINLINE void io_uring_prep_rw(int op, struct io_uring_sqe *sqe, int fd,
                                    const void *addr, unsigned len, __u64 offset)
{
    sqe->opcode = (__u8) op;
    sqe->fd = fd;
    sqe->off = offset;
    sqe->addr = (unsigned long) addr;
    sqe->len = len;
}
```

This sets exactly the five fields that every SQE needs: opcode, fd, offset, addr, len. The SQE is pre-zeroed by `io_uring_initialize_sqe()` during `io_uring_get_sqe()`, so `prep_rw` only needs to set the operation-specific fields.

**Tier B: Operation-specific prep functions**

Every prep function follows the same pattern:
1. Call `io_uring_prep_rw(OPCODE, sqe, fd, ...)` with the common fields
2. Set 0-3 additional SQE fields specific to that operation

Example -- read is a one-liner:
```c
void io_uring_prep_read(sqe, fd, buf, nbytes, offset) {
    io_uring_prep_rw(IORING_OP_READ, sqe, fd, buf, nbytes, offset);
}
```

Example -- accept needs one extra field:
```c
void io_uring_prep_accept(sqe, fd, addr, addrlen, flags) {
    io_uring_prep_rw(IORING_OP_ACCEPT, sqe, fd, addr, 0, (u64)addrlen);
    sqe->accept_flags = (u32) flags;
}
```

**Variant layering**: Prep helpers compose on top of each other for variants:
- `io_uring_prep_accept_direct()` calls `io_uring_prep_accept()` then sets `file_index`
- `io_uring_prep_multishot_accept()` calls `io_uring_prep_accept()` then sets `ioprio |= IORING_ACCEPT_MULTISHOT`
- `io_uring_prep_readv2()` calls `io_uring_prep_readv()` then sets `rw_flags`
- `io_uring_prep_sendmsg_zc()` calls `io_uring_prep_sendmsg()` then overwrites `opcode`

This means the variant hierarchy is: base prep --> multishot/direct/zc variant --> combined variant.

**SQE initialization**: `io_uring_initialize_sqe()` zeros exactly 7 fields:
```c
sqe->flags = 0;
sqe->ioprio = 0;
sqe->rw_flags = 0;
sqe->buf_index = 0;
sqe->personality = 0;
sqe->file_index = 0;
sqe->addr3 = 0;
sqe->__pad2[0] = 0;
```

This is called automatically by `io_uring_get_sqe()`. The SQE is *not* fully memset to zero; only the fields that prep helpers do not always set are cleared. This is a deliberate performance optimization -- clearing only the union fields that different opcodes alias.

### Ring Management

`struct io_uring` is liburing's central type. It wraps the kernel shared memory with user-space bookkeeping:

```c
struct io_uring {
    struct io_uring_sq sq;     // Submission queue state
    struct io_uring_cq cq;     // Completion queue state
    unsigned flags;            // Copy of io_uring_params.flags
    int ring_fd;               // Ring file descriptor
    unsigned features;         // Kernel feature flags
    int enter_ring_fd;         // FD used for io_uring_enter (may be registered)
    __u8 int_flags;            // Internal liburing flags
    __u8 pad[3];
    unsigned pad2;
};
```

The SQ and CQ sub-structs each contain:
- **Kernel pointers**: `khead`, `ktail`, `kflags` -- point into the mmap'd shared memory region. These are the actual shared state with the kernel.
- **Cached copies**: `ring_mask`, `ring_entries` -- copied from kernel memory once during setup to avoid indirection on every access.
- **User-space tracking**: `sqe_head`, `sqe_tail` (SQ only) -- liburing's own head/tail for the SQE array. These decouple SQE filling from SQ ring publishing.
- **Memory management**: `ring_ptr`, `ring_sz`, `sqes_sz` -- needed for munmap at teardown.

The critical insight is the **double-ring architecture** of the SQ side:
1. The **SQE array** (`sq->sqes[]`) is where applications write submission entries via `io_uring_get_sqe()`. liburing tracks its own `sqe_head`/`sqe_tail` for this.
2. The **SQ ring** (`sq->khead`/`sq->ktail` + `sq->array[]`) is the shared index ring that tells the kernel which SQEs to process. It used to contain an indirection array mapping ring slots to SQE indices, but `IORING_SETUP_NO_SQARRAY` (which liburing now requests by default) eliminates this and makes the SQ ring a direct index.

At submit time, `__io_uring_flush_sq()` publishes by setting `*sq->ktail = sq->sqe_tail` (with a store-release barrier when SQPOLL is active). This is the single point where user-space work becomes visible to the kernel.

The **int_flags** field tracks internal state:
- `INT_FLAG_REG_RING` -- ring FD is registered with the kernel (avoids fd lookup overhead)
- `INT_FLAG_REG_REG_RING` -- ring was registered at setup time via `IORING_SETUP_REGISTERED_FD_ONLY`
- `INT_FLAG_APP_MEM` -- application provided the memory (don't munmap at exit)
- `INT_FLAG_CQ_ENTER` -- IOPOLL mode without SQPOLL: must enter kernel to reap CQEs

### SQE Acquisition and CQE Consumption

**SQE acquisition (`io_uring_get_sqe`)**:

```c
struct io_uring_sqe *_io_uring_get_sqe(struct io_uring *ring) {
    struct io_uring_sq *sq = &ring->sq;
    unsigned head = io_uring_load_sq_head(ring), tail = sq->sqe_tail;

    if (tail - head >= sq->ring_entries)
        return NULL;

    sqe = &sq->sqes[(tail & sq->ring_mask) << io_uring_sqe_shift(ring)];
    sq->sqe_tail = tail + 1;
    io_uring_initialize_sqe(sqe);
    return sqe;
}
```

Key behaviors:
- Returns NULL when the ring is full (no blocking, no error, no reallocation)
- Uses `io_uring_load_sq_head()` which uses acquire ordering only for SQPOLL (where the kernel concurrently advances the head)
- Immediately initializes the SQE's variant fields to zero
- Advances the local `sqe_tail` but does NOT publish to the kernel ring -- that happens at submit time
- The SQE shift handles 128-byte SQEs (`IORING_SETUP_SQE128`)

There is also `io_uring_get_sqe128()` for mixed-size SQE rings (`IORING_SETUP_SQE_MIXED`), which handles the edge case where a 128-byte SQE would wrap around the ring boundary by inserting a NOP with `IOSQE_CQE_SKIP_SUCCESS`.

**CQE consumption**:

The internal helper `__io_uring_peek_cqe()` is the core CQE reader:
1. Load `ktail` with acquire ordering (ensures CQE data is visible before we read it)
2. Load `khead` with acquire ordering
3. If `tail - head > 0`, there is a CQE at `cqes[(head & mask) << shift]`
4. Check for skip-CQEs (`IORING_CQE_F_SKIP`) and internal timeout markers; auto-advance past them
5. Return the CQE pointer and the number of available entries

The public API builds on this:
- `io_uring_peek_cqe()` -- tries `__io_uring_peek_cqe()` first, falls through to `io_uring_wait_cqe_nr(ring, cqe_ptr, 0)` which may enter the kernel to flush overflow CQEs
- `io_uring_wait_cqe()` -- same peek, falls through to `io_uring_wait_cqe_nr(ring, cqe_ptr, 1)` which blocks until one CQE is available
- `io_uring_peek_batch_cqe()` -- fills an array of CQE pointers. Does NOT use barriers per-CQE; it reads the ready count once, then indexes into the CQE array directly. If nothing is immediately available and there are overflow entries, it calls `io_uring_get_events()` to flush them, then tries again.

**CQE iteration** uses a snapshot iterator:
```c
struct io_uring_cqe_iter {
    .head = *ring->cq.khead,
    .tail = io_uring_smp_load_acquire(ring->cq.ktail),
};
```
The tail is loaded with acquire at iterator creation; iteration then proceeds without further barriers. The `io_uring_for_each_cqe` macro uses this. After iteration, the caller must call `io_uring_cq_advance(ring, nr)` which does a single store-release on `khead`.

The batch API (`io_uring_peek_batch_cqe`) returns an array of CQE *pointers* (not copies). CQEs remain in the shared ring until `io_uring_cq_advance()` is called, so they are borrowed views.

### Memory Barriers

liburing's barrier implementation is in `barrier.h` and is remarkably clean. It uses **only C11/C++20 atomics** -- no platform-specific assembly:

```c
// C version (C11 atomics):
#define io_uring_smp_store_release(p, v)
    atomic_store_explicit((_Atomic typeof(*(p)) *)(p), (v), memory_order_release)

#define io_uring_smp_load_acquire(p)
    atomic_load_explicit((_Atomic typeof(*(p)) *)(p), memory_order_acquire)

#define io_uring_smp_mb()
    atomic_thread_fence(memory_order_seq_cst)

#define IO_URING_WRITE_ONCE(var, val)
    atomic_store_explicit(..., memory_order_relaxed)

#define IO_URING_READ_ONCE(var)
    atomic_load_explicit(..., memory_order_relaxed)
```

There are exactly five barrier operations used throughout liburing:
1. **`io_uring_smp_store_release`** -- used to publish SQ tail (make SQEs visible to kernel) and CQ head (mark CQEs consumed)
2. **`io_uring_smp_load_acquire`** -- used to read CQ tail (see new completions) and SQ head (under SQPOLL, see kernel progress). Also used on CQ khead in `__io_uring_peek_cqe`.
3. **`io_uring_smp_mb`** -- full fence, used only once: in `sq_ring_needs_enter()` before checking `IORING_SQ_NEED_WAKEUP` under SQPOLL
4. **`IO_URING_READ_ONCE`** -- relaxed load for flags polling (e.g., checking `kflags` for overflow/taskrun)
5. **`IO_URING_WRITE_ONCE`** -- relaxed store for flags updates (e.g., toggling eventfd)

Previous versions of liburing used architecture-specific inline assembly (`__smp_store_release`, compiler barriers, etc.). The current implementation abandoned all of that in favor of portable C11 atomics. This is a significant architectural decision -- C11 atomics are sufficient for the acquire/release protocol that io_uring uses.

The barrier protocol is:
- **SQ side (user writes, kernel reads)**: user does relaxed writes to SQE fields, then store-release to `sq->ktail`. Kernel does load-acquire on `sq->ktail` before reading SQEs.
- **CQ side (kernel writes, user reads)**: kernel does relaxed writes to CQE fields, then store-release to `cq->ktail`. User does load-acquire on `cq->ktail` before reading CQEs.
- **Head advancement**: user store-releases `cq->khead` after reading CQEs. Kernel load-acquires `cq->khead` to see freed slots. Symmetric for `sq->khead`.

### Submit Patterns

**`io_uring_submit(ring)`** -- the fundamental operation:
1. `__io_uring_flush_sq(ring)` publishes pending SQEs to the kernel ring (store-release on `sq->ktail`)
2. Determines if a syscall is needed:
   - Without SQPOLL: always needs `io_uring_enter()`
   - With SQPOLL: skips `io_uring_enter()` unless `IORING_SQ_NEED_WAKEUP` is set in `sq->kflags`
   - With IOPOLL (no SQPOLL): adds `IORING_ENTER_GETEVENTS` to also reap
3. Calls `__sys_io_uring_enter(fd, submitted, wait_nr=0, flags, NULL)`
4. Returns number of SQEs submitted (or -errno)

**`io_uring_submit_and_wait(ring, wait_nr)`** -- identical to submit but passes `wait_nr` to the enter syscall, so the kernel won't return until at least `wait_nr` completions are available.

**`io_uring_submit_and_wait_timeout(ring, cqe_ptr, wait_nr, ts, sigmask)`** -- submit + wait with a timeout. The implementation depends on kernel features:
- **With `IORING_FEAT_EXT_ARG`** (kernel 5.11+): packs the timeout into `struct io_uring_getevents_arg` and passes it via `io_uring_enter2()`. This is a single syscall: submit + wait + timeout.
- **Without `IORING_FEAT_EXT_ARG`**: synthesizes a timeout by queueing an internal `IORING_OP_TIMEOUT` SQE with a magic `user_data` value (`LIBURING_UDATA_TIMEOUT = -1`). This uses an SQE slot and produces a CQE that liburing auto-filters.

**`io_uring_submit_and_wait_min_timeout(..., min_wait)`** -- adds a *minimum* wait threshold in microseconds. Requires `IORING_FEAT_MIN_TIMEOUT`. The kernel will wait at least `min_wait` microseconds even if completions arrive sooner, reducing wakeup frequency for batching.

**`io_uring_submit_and_wait_reg(ring, cqe_ptr, wait_nr, reg_index)`** -- uses a pre-registered `io_uring_reg_wait` structure (registered via `io_uring_register_wait_reg()`). The wait parameters live in kernel memory, so the enter syscall only needs an index, avoiding the cost of copying a `getevents_arg` struct on each call.

**`io_uring_submit_and_get_events(ring)`** -- submit + force kernel to flush any overflow CQEs, even if nothing was submitted. Used when the CQ ring has overflowed.

The submit path also handles the `IORING_SETUP_SQ_REWIND` mode, where instead of advancing the SQ tail, the kernel reads SQEs starting from index 0 each time. `__io_uring_flush_sq()` resets `sqe_tail` to 0 in this mode and returns the count.

### Buffer Management

liburing supports two buffer management models:

**Legacy: SQE-based buffer provision** (`IORING_OP_PROVIDE_BUFFERS`/`IORING_OP_REMOVE_BUFFERS`)
- Buffers are provided/removed via SQE submissions
- Requires a round-trip through the kernel for each buffer operation
- `io_uring_prep_provide_buffers()` and `io_uring_prep_remove_buffers()` are the prep helpers

**Modern: Provided buffer rings** (ring-based, zero-syscall buffer management)
- Application allocates a buffer ring via `io_uring_setup_buf_ring(ring, nentries, bgid, flags, &err)`
- Registers it with `io_uring_register_buf_ring(ring, reg, flags)`
- Buffer ring is a shared memory region with a `struct io_uring_buf_ring` header

The buffer ring API has four inline helpers:

```c
// Initialize the ring
io_uring_buf_ring_init(br);            // sets tail = 0

// Add a buffer at the next available slot
io_uring_buf_ring_add(br, addr, len, bid, mask, buf_offset);
// Writes to br->bufs[(br->tail + buf_offset) & mask]

// Make new buffers visible to kernel
io_uring_buf_ring_advance(br, count);  // store-release on br->tail

// Combined: advance buf ring + advance CQ ring (saves one atomic)
io_uring_buf_ring_cq_advance(ring, br, count);

// Query available buffer count
io_uring_buf_ring_available(ring, br, bgid);
```

The buffer ring protocol:
1. Application adds buffers via `io_uring_buf_ring_add()` with incrementing `buf_offset`
2. Application calls `io_uring_buf_ring_advance(count)` to publish -- single store-release on the 16-bit tail
3. Kernel picks buffers from the ring when processing operations with `IOSQE_BUFFER_SELECT`
4. The CQE `flags` field contains the buffer ID (shifted by `IORING_CQE_BUFFER_SHIFT`)

The `io_uring_buf_ring` structure overlays the tail counter with the first buffer entry's reserved field, so the ring header costs zero extra space. The tail wraps naturally as a `__u16`.

With `IOU_PBUF_RING_INC` (incremental consumption), buffers can be partially consumed across multiple operations, useful for large registered buffer regions.

### What liburing Does NOT Do

This is architecturally the most important section. liburing is a deliberately minimal wrapper.

**No thread safety.** `struct io_uring` is not thread-safe. The comment in the wait-with-timeout code explicitly states: "this function isn't safe to use for applications that split SQ and CQ handling between two threads and expect that to work without synchronization." There is no mutex, no atomic reference count, no concurrent access protection. The application is responsible for synchronization.

**No memory allocation for operations.** liburing never allocates memory during normal operation. `io_uring_get_sqe()` returns a pointer into the pre-allocated SQE ring or NULL. CQEs are pointers into the shared ring. The only allocations are during setup (mmap) and probe (malloc for probe struct).

**No SQE overflow handling.** When the SQ ring is full, `io_uring_get_sqe()` returns NULL. There is no automatic flush-and-retry, no growable queue, no backpressure mechanism. The application decides what to do (typically: submit pending SQEs, then retry).

**No CQE lifetime management.** CQE pointers returned by peek/wait point directly into the shared ring. The application must process the CQE and call `io_uring_cqe_seen()` before the ring wraps. liburing does not copy CQEs out. This is a borrowed-pointer model with manual lifetime.

**No error recovery.** Failed submissions return -errno. liburing does not retry, does not re-queue failed SQEs, does not maintain a retry queue. The `cqe->res` field is a raw errno or byte count; liburing provides no interpretation.

**No type safety on user_data.** The `user_data` field is a raw `__u64`. liburing provides `io_uring_sqe_set_data(sqe, ptr)` and `io_uring_cqe_get_data(cqe)` convenience functions, but these are unchecked casts. There is no mechanism to associate SQEs with CQEs beyond the application matching `user_data` values.

**No operation state machine.** Multishot operations (accept, recv, poll) produce multiple CQEs for one SQE. liburing provides no tracking of which SQEs are "active" multishot sources. The `IORING_CQE_F_MORE` flag in the CQE tells the application more CQEs will follow, but liburing does not track this.

**No resource cleanup on ring exit.** `io_uring_queue_exit()` unmaps memory and closes the fd. It does not cancel in-flight operations, does not drain pending CQEs, does not unregister resources. The kernel handles cleanup on fd close.

**No high-level abstractions.** No futures, no callbacks, no completion handlers, no event loop integration, no coroutine support. liburing is a syscall interface library, not a framework.

## Lessons for Swift

1. **The prep helper pattern maps directly to `IO.Uring.Submission.prepare` methods.** Each prep helper is a static method on the submission entry type. The two-tier pattern (`prep_rw` as universal initializer + operation-specific fields) should be preserved. In Swift, this becomes a `prepare(operation:fd:address:length:offset:)` base method with operation-specific `prepare.read(...)`, `prepare.write(...)`, etc.

2. **`io_uring_get_sqe()` returning NULL is the correct API.** The Swift equivalent should return `Optional<Submission.Entry>` (not throw). Queue-full is a normal flow control signal, not an error. The application is expected to submit and retry.

3. **CQEs are borrowed views into shared memory, not owned values.** In Swift, CQE access should be ~Copyable or use `borrowing` semantics to enforce the "read then advance" protocol. `io_uring_cq_advance()` is the deallocation point. A `withCompletions { }` scoped API naturally models this.

4. **Memory barriers map to Swift Atomics.** liburing's barrier.h uses only C11 `memory_order_acquire`, `memory_order_release`, and `memory_order_seq_cst`. Swift Atomics provides the same orderings. The pattern is: acquire-load the tail to see new entries, release-store the head to free entries.

5. **No thread safety is correct for the primitives layer.** Thread safety belongs in the driver layer (L3). The raw ring wrapper should be `~Sendable` and require external synchronization, exactly like liburing.

6. **The submit-and-wait pattern is the high-performance path.** `io_uring_submit_and_wait()` combines submission and completion reaping into a single syscall. The Swift API should make this the primary pattern, not submit-then-wait as separate calls.

7. **Buffer rings are a separate subsystem.** The provided buffer ring API (`io_uring_buf_ring_*`) operates on a different shared memory region with its own protocol. It should be a separate type (`IO.Uring.Buffer.Ring`) rather than methods on the main ring.

8. **liburing does not own the SQE/CQE data.** All data pointed to by SQEs (buffers, iovec arrays, paths, sockaddrs) must be kept alive by the caller until the operation completes. This is the single largest source of io_uring bugs in C. Swift's ownership model can enforce this statically with ~Copyable submission tokens that borrow their data.

9. **The feature detection pattern matters.** liburing checks `ring->features` for capabilities like `IORING_FEAT_EXT_ARG` and `IORING_FEAT_MIN_TIMEOUT` to choose between codepaths. The Swift layer should detect and expose kernel capabilities at init time, not per-operation.

10. **The internal timeout SQE hack for old kernels can be dropped.** The legacy codepath that synthesizes `IORING_OP_TIMEOUT` SQEs and filters `LIBURING_UDATA_TIMEOUT` CQEs exists for kernels older than 5.11. Our minimum kernel version will be 6.1+, so we can require `IORING_FEAT_EXT_ARG` and avoid this entire complexity.

## References

- liburing repository: https://github.com/axboe/liburing
- `src/include/liburing.h` -- main header, inline helpers (2149 lines)
- `src/include/liburing/io_uring.h` -- kernel UAPI types (1117 lines)
- `src/include/liburing/barrier.h` -- memory barrier definitions (87 lines)
- `src/setup.c` -- ring setup and teardown (709 lines)
- `src/queue.c` -- submission/completion queue operations (497 lines)
- Kernel documentation: https://docs.kernel.org/userspace-api/io_uring.html
- Existing local reference: `/Users/coen/Developer/swift-primitives/Research/linux-io-uring-api-reference.md`
