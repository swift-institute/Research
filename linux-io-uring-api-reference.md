# Linux IO Uring API Reference

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: DECISION
decision: Comprehensive reference for io_uring API surface, usage patterns, and operational characteristics. Serves as baseline for comparing against swift-linux-primitives IO.Uring implementation.
---
-->

## Context

io_uring is a Linux-specific asynchronous I/O facility introduced in kernel 5.1 (2019). It uses shared ring buffers between user space and kernel space to eliminate per-operation syscall overhead. This document catalogues the complete API surface, memory model, usage patterns, common pitfalls, and best practices — sourced directly from kernel headers, man pages, and authoritative references.

This research serves as input for a future comparison against our IO.Uring implementation in swift-linux-primitives.

## Question

What is the complete API surface, operational model, and known pitfall set for Linux io_uring as documented by kernel sources?

---

## 1. Architectural Model

### 1.1 Core Concept

io_uring replaces the traditional "one syscall per I/O operation" model with a shared-memory producer/consumer ring buffer pair:

| Ring | Producer | Consumer | Entry Type |
|------|----------|----------|------------|
| Submission Queue (SQ) | User space | Kernel | `io_uring_sqe` (64 or 128 bytes) |
| Completion Queue (CQ) | Kernel | User space | `io_uring_cqe` (16 or 32 bytes) |

The user fills SQEs describing operations, the kernel consumes them asynchronously, and posts CQEs with results. The `user_data` field (u64) echoes from SQE to CQE, serving as the sole correlation mechanism since completions are **unordered** relative to submissions.

### 1.2 Request Lifecycle

```
 User space                          Kernel
 ──────────                          ──────
 1. Fill SQE fields
 2. Write SQE index to SQ array
 3. Release-store SQ tail ──────────> 4. Acquire-load SQ tail
                                      5. Read SQE, make private copy
                                      6. Process operation
                                      7. Write CQE (user_data, res, flags)
 9. Acquire-load CQ tail <────────── 8. Release-store CQ tail
10. Read CQE, process result
11. Release-store CQ head ──────────> (kernel reclaims CQ slot)
```

After step 5, the SQE slot is safe to reuse — the kernel makes a private copy. However, **I/O buffer memory** (the data being read/written) must remain valid until the CQE arrives.

### 1.3 SQ Indirection Layer

The submission queue contains an **array of indices** into a separate SQE array, not the SQEs themselves. This indirection allows the application to pre-fill SQEs out of order and submit them in any sequence. With `IORING_SETUP_NO_SQARRAY` (kernel 6.6+), this indirection is eliminated — entries submit in order, wrapping at the end.

### 1.4 Ring Sizing

Both rings must be power-of-two sized. Index calculation uses mask arithmetic:

```
index = tail & ring_mask
```

The CQ is always at least twice the SQ size by default (configurable via `IORING_SETUP_CQSIZE`).

---

## 2. Syscall Interface

io_uring uses exactly three syscalls:

| Syscall | Purpose |
|---------|---------|
| `io_uring_setup(u32 entries, struct io_uring_params *p)` | Create ring, return fd |
| `io_uring_enter(u32 fd, u32 to_submit, u32 min_complete, u32 flags, ...)` | Submit and/or wait |
| `io_uring_register(u32 fd, u32 opcode, void *arg, u32 nr_args)` | Register resources |

After setup, the steady-state hot path uses only `io_uring_enter()` — or no syscalls at all with SQPOLL mode.

### 2.1 io_uring_setup

Creates a new io_uring instance. Returns a file descriptor used for mmap, enter, and register calls. The kernel fills `io_uring_params` with:
- Actual ring sizes (`sq_entries`, `cq_entries`)
- Feature flags indicating kernel capabilities (`features`)
- Offsets for mmap-ing the ring buffers (`sq_off`, `cq_off`)

Closing the fd frees all associated resources (cleanup may be asynchronous).

### 2.2 io_uring_enter

Dual-purpose: submits queued SQEs and optionally waits for completions.

- `to_submit`: how many SQEs to consume from the SQ
- `min_complete`: minimum CQEs to wait for (requires `IORING_ENTER_GETEVENTS`)
- Returns: number of SQEs successfully consumed

With SQPOLL mode, submission happens automatically — `io_uring_enter` is only needed for wakeup (`IORING_ENTER_SQ_WAKEUP`) or waiting (`IORING_ENTER_GETEVENTS`).

### 2.3 io_uring_register

Registers long-lived resources to amortize per-operation overhead:

| Category | Register | Unregister |
|----------|----------|------------|
| Buffers | `IORING_REGISTER_BUFFERS` / `BUFFERS2` | `IORING_UNREGISTER_BUFFERS` |
| Files | `IORING_REGISTER_FILES` / `FILES2` | `IORING_UNREGISTER_FILES` |
| Eventfd | `IORING_REGISTER_EVENTFD` | `IORING_UNREGISTER_EVENTFD` |
| Buffer rings | `IORING_REGISTER_PBUF_RING` | `IORING_UNREGISTER_PBUF_RING` |
| Personality | `IORING_REGISTER_PERSONALITY` | `IORING_UNREGISTER_PERSONALITY` |
| Ring fd | `IORING_REGISTER_RING_FDS` | `IORING_UNREGISTER_RING_FDS` |
| Worker affinity | `IORING_REGISTER_IOWQ_AFF` | `IORING_UNREGISTER_IOWQ_AFF` |
| Worker limits | `IORING_REGISTER_IOWQ_MAX_WORKERS` | — |
| NAPI | `IORING_REGISTER_NAPI` | `IORING_UNREGISTER_NAPI` |
| Clock | `IORING_REGISTER_CLOCK` | — |
| Restrictions | `IORING_REGISTER_RESTRICTIONS` | — |
| Probe | `IORING_REGISTER_PROBE` | — |

Registered buffers are pinned in kernel memory (charged against `RLIMIT_MEMLOCK`). Registered files eliminate per-operation fd lookup. Both support sparse arrays and in-place updates via `*_UPDATE` variants.

---

## 3. Core Data Structures

### 3.1 Submission Queue Entry (io_uring_sqe)

64 bytes (128 with `IORING_SETUP_SQE128`). Heavily unionized — most fields are reused across operations:

```c
struct io_uring_sqe {
    __u8    opcode;         // IORING_OP_*
    __u8    flags;          // IOSQE_* flags
    __u16   ioprio;         // I/O priority
    __s32   fd;             // file descriptor (or fixed-file index)
    union {
        __u64 off;          // file offset
        __u64 addr2;        // secondary address
        struct { __u32 cmd_op; __u32 __pad1; };
    };
    union {
        __u64 addr;         // buffer pointer
        __u64 splice_off_in;
    };
    __u32   len;            // buffer size or iovec count
    union {                 // operation-specific flags
        __kernel_rwf_t rw_flags;
        __u32 fsync_flags;
        __u16 poll_events;
        __u32 poll32_events;
        __u32 sync_range_flags;
        __u32 msg_flags;
        __u32 timeout_flags;
        __u32 accept_flags;
        __u32 cancel_flags;
        __u32 open_flags;
        __u32 statx_flags;
        __u32 fadvise_advice;
        __u32 splice_flags;
        __u32 rename_flags;
        __u32 unlink_flags;
        __u32 hardlink_flags;
        __u32 xattr_flags;
        __u32 msg_ring_flags;
        __u32 uring_cmd_flags;
        __u32 waitid_flags;
        __u32 futex_flags;
        __u32 install_fd_flags;
        __u32 nop_flags;
    };
    __u64   user_data;      // echoed in CQE — sole correlation key
    union {
        __u16 buf_index;    // fixed buffer index
        __u16 buf_group;    // provided buffer group
    };
    __u16   personality;    // registered credential ID
    union {
        __s32 splice_fd_in;
        __u32 file_index;   // fixed-file table index
        __u32 optlen;
        struct { __u16 addr_len; __u16 __pad3[1]; };
    };
    union {
        struct { __u64 addr3; __u64 __pad2[1]; };
        __u64 optval;
        __u8  cmd[0];       // passthrough command data (128-byte mode)
    };
};
```

### 3.2 Completion Queue Entry (io_uring_cqe)

16 bytes (32 with `IORING_SETUP_CQE32`):

```c
struct io_uring_cqe {
    __u64   user_data;  // echoed from SQE
    __s32   res;        // result: success value or -errno
    __u32   flags;      // IORING_CQE_F_* flags
    __u64   big_cqe[];  // extended data (32-byte mode only)
};
```

The `res` field contains what the equivalent syscall would have returned on success, or `-errno` on failure.

### 3.3 io_uring_params

```c
struct io_uring_params {
    __u32 sq_entries;       // [out] actual SQ size
    __u32 cq_entries;       // [in/out] CQ size (with CQSIZE flag)
    __u32 flags;            // [in] IORING_SETUP_* flags
    __u32 sq_thread_cpu;    // [in] SQPOLL CPU affinity
    __u32 sq_thread_idle;   // [in] SQPOLL idle timeout (ms)
    __u32 features;         // [out] IORING_FEAT_* kernel capabilities
    __u32 wq_fd;            // [in] shared worker queue fd
    __u32 resv[3];          // must be zero
    struct io_sqring_offsets sq_off;
    struct io_cqring_offsets cq_off;
};
```

### 3.4 Ring Offset Structures

```c
struct io_sqring_offsets {
    __u32 head, tail, ring_mask, ring_entries;
    __u32 flags;        // IORING_SQ_* flags (kernel → user)
    __u32 dropped;      // count of invalid SQEs
    __u32 array;        // offset to SQ index array
    __u32 resv1;
    __u64 user_addr;    // for NO_MMAP mode
};

struct io_cqring_offsets {
    __u32 head, tail, ring_mask, ring_entries;
    __u32 overflow;     // overflow event count
    __u32 cqes;         // offset to CQE array
    __u32 flags;        // IORING_CQ_* flags
    __u32 resv1;
    __u64 user_addr;    // for NO_MMAP mode
};
```

### 3.5 Provided Buffer Ring

```c
struct io_uring_buf_ring {
    union {
        struct { __u64 resv1; __u32 resv2; __u16 resv3; __u16 tail; };
        struct io_uring_buf bufs[];
    };
};

struct io_uring_buf {
    __u64 addr;
    __u32 len;
    __u16 bid;      // buffer ID
    __u16 resv;
};
```

---

## 4. Flags Reference

### 4.1 Setup Flags (IORING_SETUP_*)

| Flag | Bit | Kernel | Description |
|------|-----|--------|-------------|
| `IOPOLL` | 0 | 5.1 | Busy-poll for completions (requires O_DIRECT, polling-capable device) |
| `SQPOLL` | 1 | 5.1 | Kernel thread polls SQ — zero-syscall submission |
| `SQ_AFF` | 2 | 5.1 | Pin SQPOLL thread to `sq_thread_cpu` |
| `CQSIZE` | 3 | 5.5 | Use `cq_entries` for CQ size (must be power-of-two) |
| `CLAMP` | 4 | 5.6 | Clamp entries to kernel maximum instead of failing |
| `ATTACH_WQ` | 5 | 5.6 | Share worker pool with ring at `wq_fd` |
| `R_DISABLED` | 6 | 5.10 | Ring starts disabled; enable after registering restrictions |
| `SUBMIT_ALL` | 7 | 5.18 | Continue submitting batch on error (don't stop at first failure) |
| `COOP_TASKRUN` | 8 | 5.19 | No forced task interruption for completions |
| `TASKRUN_FLAG` | 9 | 5.19 | Set `IORING_SQ_TASKRUN` when completions pending |
| `SQE128` | 10 | 5.19 | 128-byte SQEs (for NVMe passthrough) |
| `CQE32` | 11 | 5.19 | 32-byte CQEs (for NVMe passthrough) |
| `SINGLE_ISSUER` | 12 | 6.0 | Hint: only one task submits (enforced with `-EEXIST`) |
| `DEFER_TASKRUN` | 13 | 6.1 | Defer completion work to next `io_uring_enter` with GETEVENTS |
| `NO_MMAP` | 14 | 6.5 | User-allocated ring memory instead of kernel mmap |
| `REGISTERED_FD_ONLY` | 15 | 6.5 | Return registered fd index, not raw fd |
| `NO_SQARRAY` | 16 | 6.6 | Eliminate SQ indirection array; sequential submission |
| `HYBRID_IOPOLL` | 17 | — | Delayed polling (use with IOPOLL) |
| `CQE_MIXED` | 18 | 6.18 | Ring supports 16 and 32-byte CQEs simultaneously |
| `SQE_MIXED` | 19 | — | Mixed SQE sizes |
| `SQ_REWIND` | 20 | — | SQ rewind support |

### 4.2 Feature Flags (IORING_FEAT_*)

Reported by kernel in `params.features` — read-only:

| Flag | Bit | Kernel | Description |
|------|-----|--------|-------------|
| `SINGLE_MMAP` | 0 | 5.4 | SQ and CQ rings share one mmap (SQEs still separate) |
| `NODROP` | 1 | 5.5 | Kernel stores overflow CQEs internally; almost never drops |
| `SUBMIT_STABLE` | 2 | 5.5 | SQE data consumed at submit time (safe to free immediately) |
| `RW_CUR_POS` | 3 | 5.6 | `offset == -1` uses current file position |
| `CUR_PERSONALITY` | 4 | 5.6 | Requests use credentials of `io_uring_enter` caller |
| `FAST_POLL` | 5 | 5.7 | Internal poll mechanism for readiness (fewer async workers) |
| `POLL_32BITS` | 6 | 5.9 | Full 32-bit epoll flags in POLL_ADD (incl. EPOLLEXCLUSIVE) |
| `SQPOLL_NONFIXED` | 7 | 5.11 | SQPOLL no longer requires fixed files |
| `EXT_ARG` | 8 | 5.11 | Extended argument struct for `io_uring_enter` |
| `NATIVE_WORKERS` | 9 | 5.12 | Async workers are process-like threads (not kernel threads) |
| `RSRC_TAGS` | 10 | 5.13 | Resource tagging for CQE notification on unregister |
| `CQE_SKIP` | 11 | 5.17 | `IOSQE_CQE_SKIP_SUCCESS` flag supported |
| `LINKED_FILE` | 12 | 5.17 | Linked SQEs defer file assignment until execution |
| `REG_REG_RING` | 13 | 6.3 | `IORING_REGISTER_USE_REGISTERED_RING` supported |
| `RECVSEND_BUNDLE` | 14 | — | Bundled send/recv operations |
| `MIN_TIMEOUT` | 15 | — | Minimum batch wait timeout |
| `RW_ATTR` | 16 | — | Read/write attributes |
| `NO_IOWAIT` | 17 | — | No iowait marking |

### 4.3 SQE Flags (IOSQE_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `FIXED_FILE` | 0 | `fd` is index into registered file table |
| `IO_DRAIN` | 1 | Barrier: don't start until all prior SQEs complete |
| `IO_LINK` | 2 | Link with next SQE — next starts after this completes (soft: error severs chain) |
| `IO_HARDLINK` | 3 | Like IO_LINK but errors don't sever the chain |
| `ASYNC` | 4 | Force async execution (skip non-blocking fast path) |
| `BUFFER_SELECT` | 5 | Select buffer from provided buffer pool |
| `CQE_SKIP_SUCCESS` | 6 | Don't generate CQE on success (errors still generate CQEs) |

### 4.4 CQE Flags (IORING_CQE_F_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `BUFFER` | 0 | Upper 16 bits contain selected buffer ID (shift by `IORING_CQE_BUFFER_SHIFT = 16`) |
| `MORE` | 1 | More CQEs expected from this SQE (multishot operations) |
| `SOCK_NONEMPTY` | 2 | Socket had more data available after this recv |
| `NOTIF` | 3 | Notification event (zero-copy send completion) |
| `BUF_MORE` | 4 | Buffer partially consumed; more completions coming |
| `SKIP` | 5 | Padding CQE in mixed-size ring — ignore |
| `32` | 15 | 32-byte CQE in mixed-size ring; advance by 2x |

### 4.5 SQ Ring Flags (IORING_SQ_*)

Written by kernel, read by user space:

| Flag | Bit | Description |
|------|-----|-------------|
| `NEED_WAKEUP` | 0 | SQPOLL thread sleeping — call `io_uring_enter` with `SQ_WAKEUP` |
| `CQ_OVERFLOW` | 1 | CQ ring has overflowed |
| `TASKRUN` | 2 | Completions pending — call `io_uring_enter` with `GETEVENTS` |

### 4.6 Enter Flags (IORING_ENTER_*)

| Flag | Bit | Kernel | Description |
|------|-----|--------|-------------|
| `GETEVENTS` | 0 | 5.1 | Wait for `min_complete` completions |
| `SQ_WAKEUP` | 1 | 5.1 | Wake sleeping SQPOLL thread |
| `SQ_WAIT` | 2 | — | Wait for free SQ slot (with SQPOLL) |
| `EXT_ARG` | 3 | 5.11 | `arg` is `io_uring_getevents_arg *` (timeout + sigmask) |
| `REGISTERED_RING` | 4 | 5.18 | `fd` is registered ring index, not raw fd |
| `ABS_TIMER` | 5 | 6.12 | Timeout is absolute time, not relative |
| `EXT_ARG_REG` | 6 | 6.13 | `arg` is offset into registered memory region |
| `NO_IOWAIT` | 7 | 6.15 | Don't mark task as in iowait |

---

## 5. Operations (IORING_OP_*)

### 5.1 File I/O

| Opcode | Value | Description |
|--------|-------|-------------|
| `READV` | 1 | Vectored read (`preadv2` equivalent) |
| `WRITEV` | 2 | Vectored write (`pwritev2` equivalent) |
| `READ_FIXED` | 4 | Read into registered buffer |
| `WRITE_FIXED` | 5 | Write from registered buffer |
| `READ` | 22 | Simple read (`pread` equivalent) |
| `WRITE` | 23 | Simple write (`pwrite` equivalent) |
| `READV_FIXED` | 60 | Vectored read into registered buffers |
| `WRITEV_FIXED` | 61 | Vectored write from registered buffers |
| `READ_MULTISHOT` | 49 | Multishot read (multiple CQEs per SQE) |
| `SPLICE` | 30 | Splice data between fds |
| `TEE` | 33 | Duplicate pipe data |
| `FTRUNCATE` | 55 | Truncate file |

### 5.2 File System Operations

| Opcode | Value | Description |
|--------|-------|-------------|
| `OPENAT` | 18 | Open file (relative to dirfd) |
| `OPENAT2` | 28 | Extended open |
| `CLOSE` | 19 | Close file descriptor |
| `STATX` | 21 | Extended stat |
| `RENAMEAT` | 35 | Rename |
| `UNLINKAT` | 36 | Unlink |
| `MKDIRAT` | 37 | Create directory |
| `SYMLINKAT` | 38 | Create symlink |
| `LINKAT` | 39 | Create hard link |
| `FSETXATTR` | 41 | Set extended attribute (fd) |
| `SETXATTR` | 42 | Set extended attribute (path) |
| `FGETXATTR` | 43 | Get extended attribute (fd) |
| `GETXATTR` | 44 | Get extended attribute (path) |
| `FALLOCATE` | 17 | Allocate file space |

### 5.3 Sync Operations

| Opcode | Value | Description |
|--------|-------|-------------|
| `FSYNC` | 3 | Fsync (with optional `IORING_FSYNC_DATASYNC`) |
| `SYNC_FILE_RANGE` | 8 | Sync file range |
| `FADVISE` | 24 | File advisory |
| `MADVISE` | 25 | Memory advisory |

### 5.4 Networking

| Opcode | Value | Description |
|--------|-------|-------------|
| `SOCKET` | 45 | Create socket |
| `BIND` | 56 | Bind socket |
| `LISTEN` | 57 | Listen on socket |
| `ACCEPT` | 13 | Accept connection (supports multishot) |
| `CONNECT` | 16 | Connect to address |
| `SEND` | 26 | Send data |
| `RECV` | 27 | Receive data |
| `SENDMSG` | 9 | Send message (sendmsg equivalent) |
| `RECVMSG` | 10 | Receive message (recvmsg equivalent) |
| `SEND_ZC` | 47 | Zero-copy send |
| `SENDMSG_ZC` | 48 | Zero-copy sendmsg |
| `RECV_ZC` | 58 | Zero-copy receive |
| `SHUTDOWN` | 34 | Shutdown socket |
| `EPOLL_CTL` | 29 | Epoll control (add/mod/del) |
| `EPOLL_WAIT` | 59 | Epoll wait |

### 5.5 Control and Utility

| Opcode | Value | Description |
|--------|-------|-------------|
| `NOP` | 0 | No-op (useful for testing, linked chains) |
| `NOP128` | 63 | 128-byte NOP |
| `TIMEOUT` | 11 | Timer (absolute or relative) |
| `TIMEOUT_REMOVE` | 12 | Cancel pending timeout |
| `LINK_TIMEOUT` | 15 | Timeout for linked operation |
| `ASYNC_CANCEL` | 14 | Cancel pending operation (by user_data, fd, or opcode) |
| `POLL_ADD` | 6 | Add poll monitor (supports multishot) |
| `POLL_REMOVE` | 7 | Remove poll monitor |
| `FILES_UPDATE` | 20 | Update registered file table |
| `PROVIDE_BUFFERS` | 31 | Provide buffers (legacy, pre-ring) |
| `REMOVE_BUFFERS` | 32 | Remove provided buffers |
| `MSG_RING` | 40 | Send message to another ring |
| `URING_CMD` | 46 | Passthrough command (NVMe, etc.) |
| `URING_CMD128` | 64 | 128-byte passthrough command |
| `FIXED_FD_INSTALL` | 54 | Install fixed fd into process fd table |
| `WAITID` | 50 | Wait for process state change |
| `FUTEX_WAIT` | 51 | Futex wait |
| `FUTEX_WAKE` | 52 | Futex wake |
| `FUTEX_WAITV` | 53 | Vectored futex wait |
| `PIPE` | 62 | Create pipe |

### 5.6 Multishot Operations

Several operations support "fire once, complete many" semantics via `IORING_CQE_F_MORE`:

| Operation | Behavior |
|-----------|----------|
| `ACCEPT` (with `IORING_ACCEPT_MULTISHOT`) | CQE per accepted connection |
| `RECV` (multishot prep, requires `IOSQE_BUFFER_SELECT`) | CQE per received chunk |
| `READ_MULTISHOT` | CQE per available read |
| `POLL_ADD` (with `IORING_POLL_ADD_MULTI`) | CQE per poll event |
| `RECVMSG` (multishot) | CQE per message |

When `IORING_CQE_F_MORE` is **no longer set**, the multishot is exhausted and must be resubmitted.

---

## 6. Memory Model

### 6.1 Memory Mapping

After `io_uring_setup`, three regions are mmap'd:

| Region | Offset Constant | Contents |
|--------|----------------|----------|
| SQ Ring | `IORING_OFF_SQ_RING` (0x0) | head, tail, flags, dropped, index array |
| CQ Ring | `IORING_OFF_CQ_RING` (0x8000000) | head, tail, flags, overflow, CQE array |
| SQE Array | `IORING_OFF_SQES` (0x10000000) | Array of `io_uring_sqe` structs |

With `IORING_FEAT_SINGLE_MMAP` (kernel 5.4+), SQ and CQ rings share one mmap, reducing three mappings to two (SQEs still separate).

With `IORING_SETUP_NO_MMAP` (kernel 6.5+), the application provides pre-allocated memory via `user_addr` fields.

### 6.2 Memory Ordering

io_uring shared rings require explicit memory ordering on SMP systems. Both sides must use acquire/release semantics:

**Submission side (user space writes, kernel reads):**

```
// 1. Fill SQE fields (ordinary stores)
sqe->opcode = IORING_OP_READ;
sqe->fd = fd;
sqe->addr = buf;
sqe->len = len;

// 2. Write SQE index to array (ordinary store)
sq_array[tail & ring_mask] = sqe_index;

// 3. Release-store tail (makes SQE visible to kernel)
atomic_store_explicit(&sq->tail, tail + 1, memory_order_release);
```

**Completion side (kernel writes, user space reads):**

```
// 1. Acquire-load tail (sees kernel's CQE writes)
tail = atomic_load_explicit(&cq->tail, memory_order_acquire);

// 2. Read CQE fields (ordinary loads, ordered after acquire)
while (head != tail) {
    cqe = &cqes[head & ring_mask];
    process(cqe->user_data, cqe->res, cqe->flags);
    head++;
}

// 3. Release-store head (reclaims CQ slots for kernel)
atomic_store_explicit(&cq->head, head, memory_order_release);
```

**SQ flags read (checking SQPOLL state):**

```
// Acquire-load to see kernel's flag updates
flags = atomic_load_explicit(&sq->flags, memory_order_acquire);
if (flags & IORING_SQ_NEED_WAKEUP) {
    io_uring_enter(fd, 0, 0, IORING_ENTER_SQ_WAKEUP, NULL);
}
```

The kernel uses `READ_ONCE`/`WRITE_ONCE` internally for all shared-data accesses and pairs `smp_load_acquire`/`smp_store_release` on ring head/tail updates.

### 6.3 Pointer Lifetime Rules

| Memory | Lifetime requirement |
|--------|---------------------|
| SQE struct slots | Safe to reuse after `io_uring_enter` returns |
| SQE command data (addr, iovec ptrs) | Safe to free after `io_uring_enter` returns (with `IORING_FEAT_SUBMIT_STABLE`; otherwise must live until CQE) |
| I/O buffers (actual read/write data) | Must remain valid until CQE arrives |
| With SQPOLL | All pointers must remain valid until CQE (no submit-time copy guarantee) |

---

## 7. Execution Modes

### 7.1 Default Mode

User calls `io_uring_enter()` to submit and wait. Completions delivered via task_work, potentially interrupting the process at any kernel entry point.

### 7.2 COOP_TASKRUN

Completions delivered only at voluntary kernel entry points (not via IPI). Reduces cache disruption. Application must check `IORING_SQ_TASKRUN` flag and enter the kernel when set.

### 7.3 DEFER_TASKRUN

Completions delivered **only** during `io_uring_enter()` with `IORING_ENTER_GETEVENTS`. Gives full control over when completion work runs. Requires `SINGLE_ISSUER`. Recommended baseline for high-performance use.

### 7.4 SQPOLL

Kernel thread continuously polls SQ for new entries. Eliminates submission syscall entirely. The thread idles after `sq_thread_idle` milliseconds and sets `IORING_SQ_NEED_WAKEUP`. Application must check this flag and wake the thread with `IORING_ENTER_SQ_WAKEUP` when needed. Costs a dedicated CPU core.

### 7.5 IOPOLL

Busy-poll for completion events. Requires O_DIRECT file descriptors and polling-capable storage hardware (NVMe with poll queues). Cannot be mixed with non-polled I/O on the same ring. `HYBRID_IOPOLL` adds a delayed-poll variant that reduces CPU waste.

---

## 8. Worker Pool Architecture

### 8.1 Worker Types

| Type | Handles | Default Limit |
|------|---------|---------------|
| Bounded | File/block I/O (predictable duration) | f(SQ size, CPU count) |
| Unbounded | Network/socket I/O (unpredictable duration) | `RLIMIT_NPROC` |

### 8.2 Worker Dispatch

1. io_uring first attempts a non-blocking fast path
2. If that would block, it uses internal poll to wait for readiness
3. If `IOSQE_ASYNC` is set, it skips the fast path and dispatches to a worker immediately
4. Worker threads are named `iou-wrk-<tid>` (tid = owning thread ID)
5. Workers retire with a grace period after queues empty

### 8.3 Worker Limits

Configure explicitly with `IORING_REGISTER_IOWQ_MAX_WORKERS`:

```c
unsigned int limits[2] = { bounded_max, unbounded_max };
io_uring_register(fd, IORING_REGISTER_IOWQ_MAX_WORKERS, &limits, 2);
// limits[] now contains previous values
```

Limits are **per NUMA node**. Multi-node systems: effective max = `limit * num_nodes`.

CPU affinity for workers: `IORING_REGISTER_IOWQ_AFF` with a `cpu_set_t`.

---

## 9. Advanced Patterns

### 9.1 Linked Requests

Chain SQEs for ordered execution:

- `IOSQE_IO_LINK`: Next SQE starts after this completes. **Error severs the chain** — remaining linked SQEs get `-ECANCELED`.
- `IOSQE_IO_HARDLINK`: Same but errors do **not** sever the chain.
- `LINK_TIMEOUT`: Special timeout attached to a linked operation.

Use case: write-then-fsync, connect-then-send, read-then-process.

### 9.2 Provided Buffers

Two mechanisms for kernel-selected buffer allocation:

**Legacy (kernel 5.7+):** `IORING_OP_PROVIDE_BUFFERS` / `IORING_OP_REMOVE_BUFFERS`

**Ring-mapped (kernel 5.19+, preferred):** `IORING_REGISTER_PBUF_RING`

The ring-mapped variant is more efficient — the kernel and user space share a ring buffer of `io_uring_buf` entries. User space adds buffers to the ring; kernel picks one when the operation needs it.

Setup:
1. Allocate page-aligned memory for the buffer ring
2. Register via `IORING_REGISTER_PBUF_RING` with group ID
3. Add buffers (set addr, len, bid) and advance tail
4. Submit operations with `IOSQE_BUFFER_SELECT` and the group ID
5. CQE has `IORING_CQE_F_BUFFER` set; buffer ID in upper 16 bits of flags

On buffer exhaustion: operations fail with `-ENOBUFS`.

With `IOU_PBUF_RING_INC` flag: buffers are consumed incrementally, and `IORING_CQE_F_BUF_MORE` indicates partial consumption.

### 9.3 Zero-Copy Networking

**Send:** `IORING_OP_SEND_ZC` / `IORING_OP_SENDMSG_ZC`

Transmits directly from user memory to NIC without kernel copy. Two CQEs per operation:
1. First CQE: operation accepted (res = bytes queued)
2. Second CQE with `IORING_CQE_F_NOTIF`: buffer safe to reuse

The buffer must remain valid between the two CQEs. `IORING_SEND_ZC_REPORT_USAGE` flag reports whether zero-copy actually occurred (NIC may fall back to copy).

Only beneficial for payloads > ~1KB. Requires NIC support.

**Receive:** `IORING_OP_RECV_ZC` (newer, less widely available).

### 9.4 Ring Messages (MSG_RING)

Send data between io_uring instances (inter-thread communication):

- `IORING_MSG_DATA`: Inject a CQE with arbitrary `user_data` and `res` into target ring
- `IORING_MSG_SEND_FD`: Pass a file descriptor to target ring's fixed-file table

Useful for distributing connections from acceptor thread to worker threads.

### 9.5 Fixed File Descriptors (Direct Descriptors)

Registered files bypass the shared process fd table:

- Register files once via `IORING_REGISTER_FILES`
- Reference by index with `IOSQE_FIXED_FILE`
- `IORING_FILE_INDEX_ALLOC` auto-allocates a slot
- `IORING_OP_FIXED_FD_INSTALL` promotes a direct descriptor to a process fd

Benefit: eliminates per-operation atomic fd table lookup.

### 9.6 Restrictions

Allowlist model for sandboxing a ring:

1. Create ring with `IORING_SETUP_R_DISABLED`
2. Register allowed operations via `IORING_REGISTER_RESTRICTIONS`:
   - `IORING_RESTRICTION_REGISTER_OP`: allow specific register opcodes
   - `IORING_RESTRICTION_SQE_OP`: allow specific SQE opcodes
   - `IORING_RESTRICTION_SQE_FLAGS_ALLOWED`: allow specific SQE flags
   - `IORING_RESTRICTION_SQE_FLAGS_REQUIRED`: require specific SQE flags
3. Enable ring via `IORING_REGISTER_ENABLE_RINGS`

After enabling, disallowed operations return `-EACCES`.

### 9.7 Probing

Discover supported operations at runtime:

```c
struct io_uring_probe *probe = malloc(sizeof(*probe) + nops * sizeof(probe->ops[0]));
io_uring_register(fd, IORING_REGISTER_PROBE, probe, nops);
// Check: probe->ops[opcode].flags & IO_URING_OP_SUPPORTED
```

Essential for forward-compatible code across kernel versions.

---

## 10. Common Gotchas

### 10.1 Memory Ordering Omission

**Problem:** Omitting acquire/release barriers on ring head/tail leads to SMP race conditions — kernel misses SQEs or application reads stale CQEs.

**Fix:** Always use `atomic_store_release` for tail updates, `atomic_load_acquire` for reading the other side's updates.

### 10.2 RLIMIT_NPROC Worker Pool Starvation

**Problem:** Without explicit worker limits, unbounded workers default to `RLIMIT_NPROC`. In multithreaded programs, each thread's worker pool competes for the shared per-UID limit. io_uring burns ~25%+ CPU retrying failed `create_io_thread()` calls.

**Fix:** Always set `IORING_REGISTER_IOWQ_MAX_WORKERS` explicitly. Alternatively, use dedicated UIDs or user namespaces for isolation.

### 10.3 Buffer Lifetime Violation

**Problem:** Freeing I/O buffers after `io_uring_enter` returns but before CQE arrives. The kernel still references the buffer for async operations.

**Fix:** I/O buffers must live until the corresponding CQE is consumed. SQE data (command descriptions) can be freed after submit if `IORING_FEAT_SUBMIT_STABLE` is set.

### 10.4 SQPOLL Pointer Lifetime

**Problem:** With SQPOLL, the kernel reads SQEs asynchronously from a polling thread. Freeing SQE-referenced data after submit but before the SQPOLL thread reads it causes use-after-free.

**Fix:** With SQPOLL, all SQE-referenced data must remain valid until CQE.

### 10.5 Completion Ordering Assumptions

**Problem:** Assuming CQEs arrive in submission order. They don't — the kernel may complete operations in any order.

**Fix:** Always correlate via `user_data`. Never rely on positional ordering.

### 10.6 CQ Overflow

**Problem:** If the CQ fills before the application drains it, the kernel either drops CQEs (pre-5.5) or stores them internally (with `IORING_FEAT_NODROP`), but `io_uring_enter` returns `-EBUSY` (pre-5.19) or `-EBADR` (5.19+).

**Fix:** Size CQ generously (at least 2x SQ). Drain CQEs promptly. Check `IORING_SQ_CQ_OVERFLOW` flag.

### 10.7 Fsync Is Blocking

**Problem:** `IORING_OP_FSYNC` always falls back to async worker threads — it cannot be made non-blocking by the kernel.

**Fix:** For durable writes, prefer `O_SYNC` on the file or hardware-level guarantees. Linking write + fsync offers no improvement over sequential submission. Batch fsync operations.

### 10.8 Worker Thread Fallback for Large I/O

**Problem:** Operations exceeding `max_hw_sectors_kb` (typically 128KB) or `nr_requests` limits trigger fallback to slow async worker threads instead of the fast io_uring path.

**Fix:** Keep individual I/O sizes within device limits. Split large operations into smaller ones.

### 10.9 Multishot Exhaustion

**Problem:** Multishot operations (accept, recv) silently stop producing CQEs when `IORING_CQE_F_MORE` disappears from flags.

**Fix:** Always check `IORING_CQE_F_MORE` on every CQE from a multishot operation. Re-submit when absent.

### 10.10 Provided Buffer Exhaustion

**Problem:** When a buffer group runs empty, pending operations fail with `-ENOBUFS`.

**Fix:** Monitor buffer consumption. Replenish buffers promptly. Consider multiple buffer groups with round-robin.

### 10.11 Seccomp Bypass

**Problem:** io_uring operations execute in kernel context without going through the seccomp syscall filter. Operations that would be blocked by seccomp rules (e.g., `connect`) succeed through io_uring.

**Impact:** Docker blocks `io_uring_setup` in its default seccomp profile. Many container runtimes and sandboxed environments disable io_uring entirely. Google disabled it in ChromeOS and restricts it on Android.

**Consideration:** Code using io_uring must account for environments where the syscalls are blocked.

### 10.12 Cross-Chiplet Latency

**Problem:** On multi-chiplet CPUs (AMD EPYC, etc.), cross-chiplet traffic increases io_uring latency by 14–21%.

**Fix:** Pin io_uring threads and ring usage to the same chiplet as the NIC/device queues.

---

## 11. Best Practices

### 11.1 Configuration

1. **Start with DEFER_TASKRUN + SINGLE_ISSUER** as baseline — gives full control over completion delivery with minimal overhead.
2. **Use NO_SQARRAY** (kernel 6.6+) to eliminate the SQ indirection layer when sequential submission suffices.
3. **Set SUBMIT_ALL** to avoid partial-batch failures halting the pipeline.
4. **Size CQ at 2–4x SQ** to absorb burst completions without overflow.
5. **Probe before use** — call `IORING_REGISTER_PROBE` to discover supported operations at runtime rather than assuming kernel version.

### 11.2 Resource Registration

1. **Register buffers** for repeated I/O to the same memory regions — eliminates per-operation pinning.
2. **Register files** for hot file descriptors — eliminates atomic fd table lookups.
3. **Use direct descriptors** instead of process fd table in multithreaded scenarios.
4. **Use buffer rings** (not legacy PROVIDE_BUFFERS) for kernel-selected buffer allocation.

### 11.3 Submission

1. **Batch submissions** — a batch of 8–16 reduces per-operation CPU cycles by 5–6x. Avoid >128 for latency-sensitive workloads.
2. **One ring per thread** — avoid cross-thread ring sharing and its synchronization overhead.
3. **Use adaptive batching** — adjust batch size based on in-flight I/O count rather than fixed sizes.

### 11.4 Networking

1. **Use multishot accept + multishot recv** for connection-heavy servers.
2. **Combine with provided buffers** — multishot recv requires `IOSQE_BUFFER_SELECT`.
3. **Use MSG_RING** to distribute connections from acceptor to worker threads.
4. **Zero-copy send only for >1KB payloads** — overhead exceeds gains for smaller messages.
5. **Check IORING_CQE_F_SOCK_NONEMPTY** to chain recv operations without poll.

### 11.5 Performance

1. **Don't treat io_uring as a syscall swap** — redesign the I/O path to exploit batching and asynchrony.
2. **Monitor for worker thread activation** — frequent fallback to async workers indicates suboptimal I/O patterns.
3. **Prefer DEFER_TASKRUN over SQPOLL** unless profiling confirms submission overhead dominates and a dedicated core is available.
4. **Benchmark with realistic workloads** — naive benchmarks (single-operation, unbatched) show minimal improvement over synchronous I/O.

---

## 12. Register Opcodes Complete Reference

| Opcode | Value | Description | Since |
|--------|-------|-------------|-------|
| `REGISTER_BUFFERS` | 0 | Register fixed I/O buffers | 5.1 |
| `UNREGISTER_BUFFERS` | 1 | Release fixed buffers | 5.1 |
| `REGISTER_FILES` | 2 | Register fixed file descriptors | 5.1 |
| `UNREGISTER_FILES` | 3 | Release fixed files | 5.1 |
| `REGISTER_EVENTFD` | 4 | Register eventfd for notifications | 5.2 |
| `UNREGISTER_EVENTFD` | 5 | Release eventfd | 5.2 |
| `REGISTER_FILES_UPDATE` | 6 | Update registered file table | 5.5 |
| `REGISTER_EVENTFD_ASYNC` | 7 | Eventfd for async completions only | 5.6 |
| `REGISTER_PROBE` | 8 | Discover supported operations | 5.6 |
| `REGISTER_PERSONALITY` | 9 | Register credentials | 5.6 |
| `UNREGISTER_PERSONALITY` | 10 | Release credentials | 5.6 |
| `REGISTER_RESTRICTIONS` | 11 | Allowlist operations | 5.10 |
| `REGISTER_ENABLE_RINGS` | 12 | Enable disabled ring | 5.10 |
| `REGISTER_FILES2` | 13 | Register files (v2, with tags) | 5.13 |
| `REGISTER_FILES_UPDATE2` | 14 | Update files (v2, with tags) | 5.13 |
| `REGISTER_BUFFERS2` | 15 | Register buffers (v2, with tags) | 5.13 |
| `REGISTER_BUFFERS_UPDATE` | 16 | Update buffers | 5.13 |
| `REGISTER_IOWQ_AFF` | 17 | Set worker CPU affinity | 5.14 |
| `UNREGISTER_IOWQ_AFF` | 18 | Clear worker CPU affinity | 5.14 |
| `REGISTER_IOWQ_MAX_WORKERS` | 19 | Set worker pool limits | 5.15 |
| `REGISTER_RING_FDS` | 20 | Register ring fd itself | 5.18 |
| `UNREGISTER_RING_FDS` | 21 | Release registered ring fd | 5.18 |
| `REGISTER_PBUF_RING` | 22 | Register provided buffer ring | 5.19 |
| `UNREGISTER_PBUF_RING` | 23 | Release provided buffer ring | 5.19 |
| `REGISTER_SYNC_CANCEL` | 24 | Synchronous request cancellation | 6.0 |
| `REGISTER_FILE_ALLOC_RANGE` | 25 | Set fixed-file alloc range | 6.0 |
| `REGISTER_PBUF_STATUS` | 26 | Query buffer ring head | 6.8 |
| `REGISTER_NAPI` | 27 | Register NAPI busy-poll | 6.9 |
| `UNREGISTER_NAPI` | 28 | Release NAPI | 6.9 |
| `REGISTER_CLOCK` | 29 | Set timer clock source | 6.12 |
| `REGISTER_CLONE_BUFFERS` | 30 | Clone buffers between rings | 6.12 |
| `REGISTER_SEND_MSG_RING` | 31 | MSG_RING via register | 6.13 |
| `REGISTER_ZCRX_IFQ` | 32 | Zero-copy RX interface queue | — |
| `REGISTER_RESIZE_RINGS` | 33 | Resize SQ/CQ rings | 6.13 |
| `REGISTER_MEM_REGION` | 34 | Register memory region for wait args | 6.13 |
| `REGISTER_QUERY` | 35 | Query ring capabilities | — |
| `REGISTER_ZCRX_CTRL` | 36 | Zero-copy RX control | — |
| `REGISTER_BPF_FILTER` | 37 | Register BPF filter | — |

---

## 13. Error Handling

### 13.1 Syscall-Level Errors

Returned from `io_uring_setup`, `io_uring_enter`, `io_uring_register`:

| Error | Context | Meaning |
|-------|---------|---------|
| `EAGAIN` | enter | Out of memory/resources for submission |
| `EBADF` | all | Invalid ring fd |
| `EBADFD` | enter | Ring in wrong state (e.g., disabled) |
| `EBADR` | enter | CQE dropped (with NODROP feature, 5.19+) |
| `EBUSY` | enter/register | CQ overflow not flushed; or resources already registered |
| `EEXIST` | enter | Wrong thread (SINGLE_ISSUER + DEFER_TASKRUN) |
| `EINVAL` | all | Invalid flags, parameters, or state |
| `EFAULT` | all | Invalid user space address |
| `EMFILE` | setup | Per-process fd limit |
| `ENFILE` | setup | System-wide fd limit |
| `ENOMEM` | all | Insufficient kernel memory |
| `ENXIO` | enter/register | Ring being torn down |
| `EOPNOTSUPP` | enter | fd is not an io_uring instance |
| `EPERM` | setup | SQPOLL without privileges |
| `EINTR` | enter | Signal interrupted wait |
| `EOWNERDEAD` | enter | SQPOLL kernel thread died |

### 13.2 CQE-Level Errors

Returned in `cqe->res` as negative errno:

| Error | Meaning |
|-------|---------|
| `-EACCES` | Operation blocked by restrictions |
| `-EBADF` | Invalid fd or fixed-file index |
| `-EFAULT` | Inaccessible buffer or fixed-buffer mismatch |
| `-EINVAL` | Invalid opcode, flags, buffer index, or personality |
| `-EOPNOTSUPP` | Unsupported opcode |
| `-ENOBUFS` | Provided buffer group exhausted |
| `-ECANCELED` | Linked operation canceled (predecessor failed) |
| (operation-specific) | Same errno as the equivalent syscall would return |

---

## 14. Timeout and Cancel Flags

### Timeout Flags (IORING_TIMEOUT_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `ABS` | 0 | Absolute timestamp (not relative) |
| `UPDATE` | 1 | Update existing timeout |
| `BOOTTIME` | 2 | Use `CLOCK_BOOTTIME` |
| `REALTIME` | 3 | Use `CLOCK_REALTIME` |
| `LINK_TIMEOUT_UPDATE` | 4 | Update linked timeout |
| `ETIME_SUCCESS` | 5 | Report timeout expiry as success (res=0), not `-ETIME` |
| `MULTISHOT` | 6 | Repeating timeout |

### Async Cancel Flags (IORING_ASYNC_CANCEL_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `ALL` | 0 | Cancel all matching requests (not just first) |
| `FD` | 1 | Match by fd |
| `ANY` | 2 | Cancel any request |
| `FD_FIXED` | 3 | fd is a fixed-file index |
| `USERDATA` | 4 | Match by user_data |
| `OP` | 5 | Match by opcode |

---

## 15. Networking-Specific Flags

### Send/Recv (IORING_RECVSEND_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `POLL_FIRST` | 0 | Poll for readiness before attempting operation |
| `RECV_MULTISHOT` | 1 | Multishot receive (via `IORING_RECV_MULTISHOT`) |
| `FIXED_BUF` | 2 | Use registered buffer |
| `SEND_ZC_REPORT_USAGE` | 3 | Report whether zero-copy was actually used |
| `BUNDLE` | 4 | Bundle multiple send/recv in one operation |
| `SEND_VECTORIZED` | 5 | Vectored send |

### Accept (IORING_ACCEPT_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `MULTISHOT` | 0 | Accept multiple connections from one SQE |
| `DONTWAIT` | 1 | Non-blocking accept |
| `POLL_FIRST` | 2 | Poll before attempting accept |

### Poll (IORING_POLL_*)

| Flag | Bit | Description |
|------|-----|-------------|
| `ADD_MULTI` | 0 | Multishot poll |
| `UPDATE_EVENTS` | 1 | Update poll events |
| `UPDATE_USER_DATA` | 2 | Update user_data |
| `ADD_LEVEL` | 3 | Level-triggered (not edge-triggered) |

---

## 16. Security Considerations

### 16.1 Seccomp Bypass

io_uring operations execute inside kernel context without traversing the seccomp syscall filter. An application can perform operations (connect, bind, open, etc.) that seccomp rules would block, because the actual syscall never occurs — io_uring maps opcodes directly to kernel handlers.

**Container impact:** Docker's default seccomp profile blocks `io_uring_setup`, `io_uring_enter`, and `io_uring_register` entirely. Most container runtimes follow suit.

**Mitigation within io_uring:** Use `IORING_REGISTER_RESTRICTIONS` to create an allowlist of permitted operations before enabling the ring.

### 16.2 Vulnerability History

io_uring accounted for ~60% of kernel exploit submissions to Google's bug bounty in 2022. Common vulnerability classes include improper memory handling (CVE-2021-41073) and out-of-bounds access (CVE-2023-2598).

Google disabled io_uring in ChromeOS and restricts it to trusted system processes on Android. The kernel provides `/proc/sys/kernel/io_uring_disabled` (values: 0=enabled, 1=unprivileged disabled, 2=fully disabled).

### 16.3 Privilege Requirements

- Basic io_uring: unprivileged (since ~5.12)
- SQPOLL: required `CAP_SYS_NICE` before kernel 5.13; unprivileged since 5.13
- IOPOLL: no special privileges but requires O_DIRECT
- `/proc/sys/kernel/io_uring_disabled` can restrict access system-wide
- `io_uring_group` sysctl can limit to specific group membership

---

## Outcome

**Status**: DECISION

This document serves as the authoritative reference for the Linux io_uring API surface as of kernel ~6.18. It captures the complete syscall interface, all 65 operations, all flag sets, memory ordering requirements, execution modes, and 12 documented gotchas with fixes.

Key architectural characteristics for a Swift binding:
- The API is three syscalls + shared memory rings
- Heavy use of unions in SQE (operation-specific field reuse)
- Ring indices are always masked (power-of-two sizing)
- Memory ordering is acquire/release on head/tail — maps to Swift atomics
- Feature detection via probe is essential for cross-kernel-version portability
- CQE correlation is exclusively via user_data (u64)

## References

- [io_uring_setup(2)](https://man7.org/linux/man-pages/man2/io_uring_setup.2.html) — Linux man page
- [io_uring_enter(2)](https://man7.org/linux/man-pages/man2/io_uring_enter.2.html) — Linux man page
- [io_uring_register(2)](https://man7.org/linux/man-pages/man2/io_uring_register.2.html) — Linux man page
- [io_uring(7)](https://man7.org/linux/man-pages/man7/io_uring.7.html) — Linux overview man page
- [include/uapi/linux/io_uring.h](https://github.com/torvalds/linux/blob/master/include/uapi/linux/io_uring.h) — Kernel header (canonical)
- [Efficient IO with io_uring](https://kernel.dk/io_uring.pdf) — Jens Axboe (2019)
- [io_uring and networking in 2023](https://github.com/axboe/liburing/wiki/io_uring-and-networking-in-2023) — liburing wiki
- [Missing Manuals: io_uring worker pool](https://blog.cloudflare.com/missing-manuals-io_uring-worker-pool/) — Cloudflare
- [Lord of the io_uring](https://unixism.net/loti/what_is_io_uring.html) — Tutorial
- [io_uring for High-Performance DBMSs](https://arxiv.org/html/2512.04859v1) — Academic paper (2025)
- [io_uring and seccomp](https://blog.0x74696d.com/posts/iouring-and-seccomp/) — Security analysis
- [Google restricting io_uring](https://www.phoronix.com/news/Google-Restricting-IO_uring) — Security context
