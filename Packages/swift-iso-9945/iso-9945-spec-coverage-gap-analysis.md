# ISO 9945 Spec Coverage Gap Analysis

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: RECOMMENDATION
tier: 2
---
-->

## Context

`swift-iso-9945` provides type-safe Swift wrappers for ISO 9945 / IEEE 1003.1 (POSIX)
system interfaces. The package currently has 12 kernel variant targets + 1 loader target
covering ~97 source files across 11 POSIX domains.

This document systematically compares the existing coverage against the full
IEEE Std 1003.1-2024 (POSIX.1-2024 / SUSv5) specification to identify gaps. The goal
is a complete, modern Swift wrapper — not a transliteration of every C function, but a
principled coverage of every POSIX subsystem that has value as a Swift API.

### Scope Boundary: Kernel vs C Library

IEEE 1003.1-2024 spans four volumes. This analysis focuses on **Volume 2: System
Interfaces (XSH)** — the kernel and OS-level APIs. We explicitly exclude:

| Excluded | Reason |
|----------|--------|
| Buffered stdio (fopen, fprintf, fread, etc.) | C library layer; covered by `swift-iso-9899` |
| String/memory functions (strcpy, memcpy, etc.) | C library; Swift has native equivalents |
| Math functions (sin, cos, sqrt, etc.) | C library; Swift imports these automatically |
| Character classification (isalpha, toupper, etc.) | C library; Swift `Character` covers this |
| Wide-character / multibyte (wcs*, mbs*) | C library; Swift `String` is Unicode-native |
| Numeric conversion (atoi, strtol, etc.) | C library; Swift has native parsing |
| Search/sort (qsort, bsearch) | C library; Swift has `sort()`, `Collection` algorithms |
| Nonlocal jumps (setjmp/longjmp) | Unsafe in Swift, no legitimate use case |
| C11 atomics (stdatomic.h) | Swift has `Atomics` package |
| C11 threads (thrd_*, mtx_*, etc.) | Redundant with pthreads; not used in practice |
| Locale / i18n (setlocale, iconv, gettext) | C library; Foundation handles this at L3+ |
| Shell command language (XCU Volume 3) | Not a library concern |
| Standard utilities (XCU Volume 3) | Not a library concern |

The analysis covers: kernel syscalls, POSIX threading, POSIX IPC, sockets/networking,
memory management, signals, process control, terminal I/O, and POSIX-specific extensions
to the C library that operate at kernel level (e.g., `getaddrinfo`, `regex`, `glob`).

---

## Methodology

For each POSIX functional area from IEEE 1003.1-2024:

1. Inventory what the spec defines
2. Inventory what `swift-iso-9945` currently implements
3. Identify the delta
4. Classify each gap by priority and propose target placement

Priority classification:

| Priority | Criteria |
|----------|----------|
| **P0 — Critical** | Core OS functionality with no Swift equivalent; blocks real-world use cases |
| **P1 — High** | Important for completeness; commonly used in systems programming |
| **P2 — Medium** | Useful but less common; has partial Swift alternatives |
| **P3 — Low** | Legacy, rarely used in modern code, or has full Swift alternatives |

---

## Gap Analysis by POSIX Functional Area

### 1. Sockets and Networking — `ISO 9945 Kernel Socket`

**Current coverage**: socketpair, socket options (getsockopt/setsockopt for SO_ERROR),
shutdown, Socket.Pair.create(), Socket.Backlog type.

**This is the largest gap in the package.** The entire core socket lifecycle and
networking stack is missing.

> **Migration note**: Several socket types already exist in `swift-linux-standard`
> (`Linux Kernel Socket Standard`) and need **migration to ISO 9945**, not greenfield
> implementation. See "Migration from swift-linux-standard" section below.

#### 1a. Socket Lifecycle (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `socket()` | Create socket (AF_INET, AF_INET6, AF_UNIX, SOCK_STREAM, SOCK_DGRAM) | **MISSING** |
| `bind()` | Bind address to socket | **MISSING** |
| `listen()` | Mark socket as passive (accepting connections) | **MISSING** |
| `accept()` / `accept4()` | Accept incoming connection | **MISSING** |
| `connect()` | Initiate outgoing connection | **MISSING** |

**Swift API shape** (indicative):
```swift
Socket.create(domain:type:protocol:) throws(Kernel.Error) -> Kernel.Descriptor
Socket.Bind.bind(_:address:) throws(Kernel.Error)
Socket.Listen.listen(_:backlog:) throws(Kernel.Error)
Socket.Accept.accept(_:) throws(Kernel.Error) -> (descriptor: Kernel.Descriptor, address: Socket.Address)
Socket.Connect.connect(_:address:) throws(Kernel.Error)
```

#### 1b. Socket I/O (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `send()` | Send data on connected socket | **MISSING** |
| `sendto()` | Send data to specific address (UDP) | **MISSING** |
| `sendmsg()` | Send with ancillary data (cmsg) | **MISSING** |
| `recv()` | Receive data from connected socket | **MISSING** |
| `recvfrom()` | Receive data with sender address | **MISSING** |
| `recvmsg()` | Receive with ancillary data | **MISSING** |
| `getsockname()` | Get local socket address | **MISSING** |
| `getpeername()` | Get remote socket address | **MISSING** |
| `sockatmark()` | Check out-of-band data position | **MISSING** |

**Message Header types** (needed by sendmsg/recvmsg):

| Type | Purpose | Status |
|------|---------|--------|
| `Socket.Message.Header` | msghdr wrapper (name, vectors, control) | **MIGRATE** from `Linux Kernel Socket Standard` |
| `Socket.Message.Header.Name` | Target address for message | **MIGRATE** |
| `Socket.Message.Header.Vectors` | Scatter/gather I/O vector array | **MIGRATE** |
| `Socket.Message.Header.Control` | Ancillary data (cmsghdr) | **MIGRATE** |

> **Note**: The handoff document lists `Kernel.Socket.Message.Header` as Linux-only,
> but `struct msghdr` is defined in POSIX `<sys/socket.h>`. The `sendmsg()`/`recvmsg()`
> functions and the ancillary data mechanism (`struct cmsghdr`, `CMSG_FIRSTHDR`,
> `CMSG_NXTHDR`, `CMSG_DATA`) are all POSIX. The base type should migrate to ISO 9945;
> Linux-specific ancillary message types (e.g., `SCM_CREDENTIALS`) remain at L2 Linux.

#### 1c. Address Types (P0)

| Type | Purpose | Status |
|------|---------|--------|
| `Socket.Address` | Namespace for address types | **MIGRATE** from `Linux Kernel Socket Standard` |
| `Socket.Address.Family` | Address family (AF_INET, AF_INET6, AF_UNIX, AF_UNSPEC) | **MIGRATE** — RawRepresentable, rawValue: Int32 |
| `Socket.Address.Storage` | Universal address container (sockaddr_storage) | **MIGRATE** — cValue wrapper |
| `Socket.Address.IPv4` | IPv4 address (sockaddr_in) | **MIGRATE** — cValue wrapper, port/address accessors |
| `Socket.Address.IPv6` | IPv6 address (sockaddr_in6) | **MIGRATE** — cValue wrapper, port/flowInfo/scopeId |
| `Socket.Address.Unix` | Unix domain address (sockaddr_un) | **MIGRATE** — cValue wrapper |
| `Socket.Kind` | Socket type enum (SOCK_STREAM, SOCK_DGRAM, SOCK_RAW) | **MISSING** |

> Migration pattern per [PLAT-ARCH-013] shell + values: ISO 9945 defines the types
> with POSIX constants (AF_INET, AF_INET6, AF_UNIX, AF_UNSPEC). Linux Standard extends
> with Linux-specific constants (e.g., AF_NETLINK). Darwin Standard extends with
> Darwin-specific constants if any.

#### 1d. Address Resolution (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `getaddrinfo()` | DNS and service name resolution | **MISSING** |
| `freeaddrinfo()` | Free address info chain | **MISSING** |
| `gai_strerror()` | Address info error string | **MISSING** |
| `getnameinfo()` | Reverse DNS lookup | **MISSING** |
| `inet_ntop()` | Binary address → presentation string | **MISSING** |
| `inet_pton()` | Presentation string → binary address | **MISSING** |

#### 1e. Network Utilities (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `gethostname()` | Get system hostname | **MISSING** |
| `htonl/htons/ntohl/ntohs` | Byte order conversion | **MISSING** |
| `if_nameindex()` | List network interfaces | **MISSING** |
| `if_nametoindex()` / `if_indextoname()` | Interface name ↔ index | **MISSING** |

#### 1f. Full Socket Options (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `getsockopt()` (general) | Get arbitrary socket option | **Partial** — only SO_ERROR |
| `setsockopt()` (general) | Set arbitrary socket option | **MISSING** |
| `SO_REUSEADDR`, `SO_KEEPALIVE`, `TCP_NODELAY`, etc. | Common option constants | **Partial** — Options bitflags exist |

#### 1g. Network Database (P3)

| Function | Purpose | Status |
|----------|---------|--------|
| `gethostent/endhostent/sethostent` | Host database iteration | **MISSING** |
| `getnetbyname/getnetbyaddr/getnetent` | Network database | **MISSING** |
| `getprotobyname/getprotobynumber` | Protocol database | **MISSING** |
| `getservbyname/getservbyport` | Service database | **MISSING** |

> Low priority: `getaddrinfo` supersedes most of these. Legacy APIs.

**Target**: Existing `ISO 9945 Kernel Socket`. Significant expansion required — this
target grows from 6 files to an estimated 25-30 files.

---

### 2. I/O Multiplexing — NEW TARGET: `ISO 9945 Kernel Poll`

**Current coverage**: None.

This is a **critical gap** — I/O multiplexing is fundamental to any event-driven or
concurrent I/O system.

#### 2a. poll (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `poll()` | Wait for events on multiple file descriptors | **MISSING** |
| `struct pollfd` | Descriptor + requested/returned events | **MISSING** |
| `POLLIN`, `POLLOUT`, `POLLERR`, `POLLHUP`, etc. | Event flags | **MISSING** |

**Swift API shape**:
```swift
Poll.poll(_: borrowing [Poll.Entry], timeout: Duration?) throws(Kernel.Error) -> Int
Poll.Entry { descriptor: Kernel.Descriptor; requested: Poll.Events; returned: Poll.Events }
Poll.Events: OptionSet { .input, .output, .error, .hangUp, .invalid }
```

#### 2b. select / pselect (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `select()` | Wait for events on fd_set bitmasks | **MISSING** |
| `pselect()` | select with signal mask and timespec | **MISSING** |
| `FD_ZERO/SET/CLR/ISSET` | fd_set manipulation macros | **MISSING** |

> Medium priority: `poll` is the modern replacement. `select` has the FD_SETSIZE
> limitation (typically 1024). Still needed for legacy compatibility.

**Target**: New target `ISO 9945 Kernel Poll`. Depends on Core only.
Estimated: 4-6 files.

---

### 3. File I/O — Missing Operations in `ISO 9945 Kernel File`

**Current coverage**: open, close, read, write, lseek, stat/fstat/lstat, chmod/fchmod,
chown/fchown, link, symlink, unlink, rename, dup/dup3, fcntl, fsync, pipe, realpath,
device major/minor, file times (utimes), file attributes.

#### 3a. Positional I/O (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `pread()` | Read at offset without seeking | **MISSING** |
| `pwrite()` | Write at offset without seeking | **MISSING** |

> Critical for concurrent file access — multiple threads can read/write different
> offsets without racing on the file offset.

#### 3b. Vector I/O (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `readv()` | Scatter read into multiple buffers | **MISSING** |
| `writev()` | Gather write from multiple buffers | **MISSING** |

> Critical for high-performance I/O — avoids copying data into a contiguous buffer.

#### 3c. File Size (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `truncate()` | Set file size by path | **MISSING** |
| `ftruncate()` | Set file size by descriptor | **MISSING** |

#### 3d. File Sync (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `fdatasync()` | Sync data only (not metadata) | **MISSING** |

> `fsync()` exists; `fdatasync()` is the performance-oriented variant.

#### 3e. File Advisory (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `posix_fadvise()` | Advise kernel on access pattern | **MISSING** |
| `posix_fallocate()` | Preallocate file space | **MISSING** |

#### 3f. Symlink Read (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `readlink()` | Read symlink target | **MISSING** |
| `readlinkat()` | Read symlink target (relative to directory fd) | **MISSING** |

> `Link.Symbolic.create` exists but there is no way to read a symlink's target.

#### 3g. *at() Variants (P1)

The POSIX `*at()` family allows operations relative to a directory file descriptor,
eliminating TOCTOU races. Several are missing:

| Function | Purpose | Status |
|----------|---------|--------|
| `openat()` | Open relative to dirfd | **Partial** — `File.At.Options` exists |
| `fstatat()` | Stat relative to dirfd | **MISSING** |
| `mkdirat()` | Create directory relative to dirfd | **MISSING** |
| `mkfifoat()` | Create FIFO relative to dirfd | **MISSING** |
| `mknodat()` | Create special file relative to dirfd | **MISSING** |
| `linkat()` | Link relative to dirfd | **MISSING** |
| `symlinkat()` | Symlink relative to dirfd | **MISSING** |
| `unlinkat()` | Unlink relative to dirfd | **MISSING** |
| `renameat()` | Rename relative to dirfd | **MISSING** |
| `readlinkat()` | Read symlink relative to dirfd | **MISSING** |
| `utimensat()` | Set timestamps relative to dirfd | **MISSING** |
| `faccessat()` | Check access relative to dirfd | **MISSING** |
| `fchownat()` | Change owner relative to dirfd | **MISSING** |
| `fchmodat()` | Change mode relative to dirfd | **MISSING** |

> The *at() family is the modern, race-free way to do filesystem operations.
> Should be the primary API, with non-at versions as convenience wrappers.

**Target**: Existing `ISO 9945 Kernel File`. Estimated growth: +10-15 files.

---

### 4. File System Operations — Missing in `ISO 9945 Kernel File` / `Directory`

#### 4a. File Accessibility (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `access()` | Check file permissions (R_OK, W_OK, X_OK, F_OK) | **MISSING** |
| `faccessat()` | Check access relative to dirfd | **MISSING** |

#### 4b. File Creation Mask (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `umask()` | Set default permission mask for new files | **MISSING** |

#### 4c. Special Files (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `mkfifo()` / `mkfifoat()` | Create named pipe (FIFO) | **MISSING** |
| `mknod()` / `mknodat()` | Create special device file | **MISSING** |

#### 4d. Temporary Files (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `mkstemp()` / `mkostemp()` | Create unique temporary file (secure) | **MISSING** |
| `mkdtemp()` | Create unique temporary directory | **MISSING** |

> The test support target has `Kernel.Temporary` but the production API is missing.

#### 4e. File Tree Walking (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `nftw()` | Walk file tree with callbacks | **MISSING** |

> `Directory.Stream` provides iteration within one directory. Tree walking is recursive.

#### 4f. Filesystem Info (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `statvfs()` | Get filesystem statistics (total/free/available space, block size) | **MISSING** |
| `fstatvfs()` | Same, by descriptor | **MISSING** |

#### 4g. Configuration Values (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `pathconf()` | Get file/path configuration limits | **MISSING** |
| `fpathconf()` | Same, by descriptor | **MISSING** |
| `confstr()` | Get configuration strings | **MISSING** |

#### 4h. Glob / Fnmatch (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `glob()` | Pathname pattern matching with expansion | **MISSING** |
| `fnmatch()` | Test filename against pattern | **MISSING** |

#### 4i. Path Utilities (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `basename()` | Extract filename component | **MISSING** |
| `dirname()` | Extract directory component | **MISSING** |

> Swift `String` can do this, but POSIX semantics differ in edge cases.

**Target**: Split across `ISO 9945 Kernel File` and `ISO 9945 Kernel Directory`.
Filesystem info could warrant a new target if it grows.

---

### 5. Thread Synchronization — Gaps in `ISO 9945 Kernel Thread`

**Current coverage**: pthread_create, pthread_join, sched_yield, Mutex (lock/unlock/withLock),
Condition (wait/signal/broadcast).

#### 5a. Read-Write Locks — NEW (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_rwlock_init/destroy` | RW lock lifecycle | **MISSING** |
| `pthread_rwlock_rdlock/tryrdlock` | Acquire read lock | **MISSING** |
| `pthread_rwlock_wrlock/trywrlock` | Acquire write lock | **MISSING** |
| `pthread_rwlock_timedrdlock/timedwrlock` | Timed lock acquisition | **MISSING** |
| `pthread_rwlock_unlock` | Release lock | **MISSING** |
| `pthread_rwlockattr_*` | RW lock attributes | **MISSING** |

> Read-write locks are **mandatory in POSIX.1-2024** (_POSIX_READER_WRITER_LOCKS).
> Essential for concurrent read-heavy workloads.

#### 5b. Barriers — NEW (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_barrier_init/destroy` | Barrier lifecycle | **MISSING** |
| `pthread_barrier_wait` | Synchronize at barrier | **MISSING** |
| `pthread_barrierattr_*` | Barrier attributes | **MISSING** |

> Mandatory in POSIX.1-2024. Useful for parallel computation phases.

#### 5c. Spin Locks — NEW (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_spin_init/destroy` | Spin lock lifecycle | **MISSING** |
| `pthread_spin_lock/trylock/unlock` | Spin lock operations | **MISSING** |

> Mandatory in POSIX.1-2024. For short critical sections where blocking is worse
> than spinning.

#### 5d. Thread Lifecycle (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_detach()` | Detach thread (no join needed) | **MISSING** |
| `pthread_self()` | Get current thread handle | **MISSING** |
| `pthread_equal()` | Compare thread IDs | **MISSING** |
| `pthread_cancel()` | Request cancellation | **MISSING** |
| `pthread_setcancelstate/type` | Cancellation control | **MISSING** |
| `pthread_testcancel()` | Cancellation point | **MISSING** |
| `pthread_cleanup_push/pop` | Cleanup handlers | **MISSING** |
| `pthread_atfork()` | Fork handlers | **MISSING** |
| `pthread_once()` | One-time initialization | **MISSING** |

#### 5e. Thread-Specific Data (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_key_create/delete` | TSD key lifecycle | **MISSING** |
| `pthread_getspecific/setspecific` | Get/set TSD value | **MISSING** |

#### 5f. Thread Attributes (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_attr_init/destroy` | Attribute lifecycle | **MISSING** |
| `pthread_attr_get/setdetachstate` | Detach state | **MISSING** |
| `pthread_attr_get/setstacksize` | Stack size | **MISSING** |
| `pthread_attr_get/setstack` | Stack address + size | **MISSING** |
| `pthread_attr_get/setguardsize` | Guard page size | **MISSING** |
| `pthread_attr_get/setschedparam` | Scheduling parameters | **MISSING** |
| `pthread_attr_get/setschedpolicy` | Scheduling policy | **MISSING** |
| `pthread_attr_get/setscope` | Contention scope | **MISSING** |
| `pthread_attr_get/setinheritsched` | Inherit scheduling | **MISSING** |

#### 5g. Mutex Attributes (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_mutexattr_init/destroy` | Attribute lifecycle | **MISSING** |
| `pthread_mutexattr_get/settype` | Mutex type (normal, recursive, errorcheck) | **MISSING** |
| `pthread_mutexattr_get/setpshared` | Process-shared | **MISSING** |
| `pthread_mutexattr_get/setrobust` | Robust mutexes | **MISSING** |
| `pthread_mutexattr_get/setprotocol` | Priority protocol | **MISSING** |
| `pthread_mutexattr_get/setprioceiling` | Priority ceiling | **MISSING** |
| `pthread_mutex_timedlock()` | Timed mutex acquisition | **MISSING** |
| `pthread_mutex_consistent()` | Robust mutex recovery | **MISSING** |

#### 5h. Condition Attributes (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `pthread_condattr_init/destroy` | Attribute lifecycle | **MISSING** |
| `pthread_condattr_get/setclock` | Clock selection | **MISSING** |
| `pthread_condattr_get/setpshared` | Process-shared | **MISSING** |
| `pthread_cond_timedwait()` | Timed condition wait | **MISSING** |

**Target**: Existing `ISO 9945 Kernel Thread`. Major expansion — estimated growth from
5 files to 20-25 files. Consider sub-splitting:
- `ISO 9945 Kernel Thread` — core lifecycle, TSD, attributes
- `ISO 9945 Kernel Lock ReadWrite` — read-write locks (or keep in Thread)
- `ISO 9945 Kernel Barrier` — barriers (or keep in Thread)
- `ISO 9945 Kernel Lock Spin` — spin locks (or keep in Thread)

---

### 6. POSIX Semaphores — NEW TARGET: `ISO 9945 Kernel Semaphore`

**Current coverage**: None.

Semaphores are **mandatory in POSIX.1-2024** (_POSIX_SEMAPHORES). Distinct from
System V semaphores (see §8).

#### 6a. Named Semaphores (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `sem_open()` | Open/create named semaphore | **MISSING** |
| `sem_close()` | Close named semaphore | **MISSING** |
| `sem_unlink()` | Remove named semaphore | **MISSING** |

#### 6b. Unnamed Semaphores (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `sem_init()` | Initialize unnamed semaphore | **MISSING** |
| `sem_destroy()` | Destroy unnamed semaphore | **MISSING** |

#### 6c. Semaphore Operations (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `sem_wait()` | Decrement (block if zero) | **MISSING** |
| `sem_trywait()` | Non-blocking decrement | **MISSING** |
| `sem_timedwait()` | Timed decrement | **MISSING** |
| `sem_post()` | Increment (wake waiters) | **MISSING** |
| `sem_getvalue()` | Get current value | **MISSING** |

**Target**: New target `ISO 9945 Kernel Semaphore`. Depends on Core only.
Estimated: 4-6 files.

---

### 7. POSIX Message Queues — NEW TARGET: `ISO 9945 Kernel Message Queue`

**Current coverage**: None.

Optional feature (`_POSIX_MESSAGE_PASSING`), but widely supported on Linux and macOS.

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `mq_open()` | Open/create message queue | P2 | **MISSING** |
| `mq_close()` | Close message queue | P2 | **MISSING** |
| `mq_unlink()` | Remove message queue | P2 | **MISSING** |
| `mq_send()` / `mq_timedsend()` | Send message | P2 | **MISSING** |
| `mq_receive()` / `mq_timedreceive()` | Receive message | P2 | **MISSING** |
| `mq_getattr()` / `mq_setattr()` | Queue attributes | P2 | **MISSING** |
| `mq_notify()` | Asynchronous notification | P2 | **MISSING** |

**Target**: New target `ISO 9945 Kernel Message Queue`. Depends on Core + Signal
(for `mq_notify` with `SIGEV_SIGNAL`). Estimated: 4-6 files.

---

### 8. System V IPC — NEW TARGET: `ISO 9945 Kernel IPC`

**Current coverage**: None.

XSI extension. Older IPC mechanism but still widely used, especially shared memory.

#### 8a. Shared Memory (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `shmget()` | Create/get shared memory segment | **MISSING** |
| `shmat()` | Attach shared memory | **MISSING** |
| `shmdt()` | Detach shared memory | **MISSING** |
| `shmctl()` | Control shared memory | **MISSING** |

> Note: POSIX shared memory (`shm_open/shm_unlink`) IS implemented in the Memory target.
> System V shared memory is a different, older mechanism.

#### 8b. Message Queues (P3)

| Function | Purpose | Status |
|----------|---------|--------|
| `msgget()` | Create/get message queue | **MISSING** |
| `msgsnd()` | Send message | **MISSING** |
| `msgrcv()` | Receive message | **MISSING** |
| `msgctl()` | Control message queue | **MISSING** |

#### 8c. Semaphores (P3)

| Function | Purpose | Status |
|----------|---------|--------|
| `semget()` | Create/get semaphore set | **MISSING** |
| `semop()` | Semaphore operations | **MISSING** |
| `semctl()` | Control semaphore set | **MISSING** |

#### 8d. Common (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `ftok()` | Generate IPC key from path | **MISSING** |

**Target**: New target `ISO 9945 Kernel IPC`. Depends on Core only.
Estimated: 6-10 files.

---

### 9. Signal — Gaps in `ISO 9945 Kernel Signal`

**Current coverage**: sigaction (full), signal sets (empty/fill/add/del/ismember),
signal masks (set/block/unblock/pending via pthread_sigmask), kill/raise/killpg,
Signal.Number constants, Signal.Action.Configuration with handler/flags/mask.

#### 9a. Synchronous Signal Wait (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `sigwait()` | Wait for signal from set | **MISSING** |
| `sigwaitinfo()` | Wait with signal info | **MISSING** |
| `sigtimedwait()` | Timed wait for signal | **MISSING** |
| `sigsuspend()` | Suspend until signal from mask | **MISSING** |

> Critical for signal-driven designs where a dedicated thread consumes signals.

#### 9b. Realtime Signals (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `sigqueue()` | Send signal with data payload (union sigval) | **MISSING** |
| `SIGRTMIN` / `SIGRTMAX` | Realtime signal range | **MISSING** |

#### 9c. Signal Stack (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `sigaltstack()` | Set alternate signal stack | **MISSING** |

#### 9d. Signal Utilities (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `pause()` | Suspend until any signal | **MISSING** |
| `psiginfo()` / `psignal()` | Print signal description | **MISSING** |
| `sig2str()` / `str2sig()` | Signal name ↔ number conversion | **MISSING** |

**Target**: Existing `ISO 9945 Kernel Signal`. Estimated growth: +4-6 files.

---

### 10. Process — Gaps in `ISO 9945 Kernel Process`

**Current coverage**: fork, execve, posix_spawn, wait/waitpid (via Wait.Selector),
exit, kill, process groups (setpgid/getpgid), sessions (setsid/getsid),
Process.Status decoding (exited/signaled/stopped/continued).

#### 10a. Exec Family (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `execl()` | Execute with arg list | **MISSING** |
| `execle()` | Execute with arg list + environment | **MISSING** |
| `execlp()` | Execute with PATH search + arg list | **MISSING** |
| `execv()` | Execute with arg array | **MISSING** |
| `execvp()` | Execute with PATH search + arg array | **MISSING** |
| `fexecve()` | Execute from file descriptor | **MISSING** |

> `execve` is implemented. The others are convenience wrappers. `fexecve` is the
> security-relevant addition (execute from an already-opened fd, avoiding TOCTOU).

#### 10b. Spawn Attributes (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `posix_spawn_file_actions_addchdir()` | Set cwd for spawned process | **MISSING** |
| `posix_spawn_file_actions_addclose()` | Close fd in spawned process | **MISSING** |
| `posix_spawn_file_actions_adddup2()` | Dup fd in spawned process | **MISSING** |
| `posix_spawn_file_actions_addopen()` | Open file in spawned process | **MISSING** |
| `posix_spawnattr_getflags/setflags` | Spawn attribute flags | **MISSING** |
| `posix_spawnattr_getpgroup/setpgroup` | Spawn process group | **MISSING** |
| `posix_spawnattr_getsigdefault/setsigdefault` | Signal defaults | **MISSING** |
| `posix_spawnattr_getsigmask/setsigmask` | Signal mask for spawn | **MISSING** |
| `posix_spawnattr_getschedparam/setschedparam` | Scheduling params | **MISSING** |
| `posix_spawnattr_getschedpolicy/setschedpolicy` | Scheduling policy | **MISSING** |
| `posix_spawnp()` | Spawn with PATH search | **MISSING** |

> `posix_spawn` is implemented but without file actions or attributes — the most
> important part for real use.

#### 10c. Wait Variants (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `waitid()` | Wait with extended options (P_PID, P_PGID, P_ALL) | **MISSING** |

> `wait/waitpid` covered via `Process.Wait.wait(selector:options:)`. `waitid` adds
> `WNOWAIT` (peek without reaping) and richer `siginfo_t` information.

**Wait types to migrate from swift-linux-standard**:

| Type | Purpose | Status |
|------|---------|--------|
| `Process.Wait.Kind` | idtype_t: P_ALL, P_PID, P_PGID | **MIGRATE** from `Linux Kernel System Standard` |
| `Process.Wait.Options` | WEXITED, WSTOPPED, WCONTINUED, WNOWAIT | **MIGRATE** — OptionSet, rawValue: Int32 |

> These are POSIX `waitid()` types. The existing `Process.Wait.Selector` enum covers
> `waitpid()` semantics; `Wait.Kind` covers the `waitid()` semantics.

#### 10d. Resource Limits (P1) — consider `ISO 9945 Kernel System` or new target

| Function | Purpose | Status |
|----------|---------|--------|
| `getrlimit()` | Get resource limits (RLIMIT_NOFILE, etc.) | **MISSING** |
| `setrlimit()` | Set resource limits | **MISSING** |
| `getrusage()` | Get resource usage | **MISSING** |

#### 10e. Process Scheduling (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `nice()` | Adjust nice value | **MISSING** |
| `getpriority()` / `setpriority()` | Get/set process priority | **MISSING** |
| `sched_setscheduler/getscheduler` | Scheduling policy | **MISSING** |
| `sched_setparam/getparam` | Scheduling parameters | **MISSING** |
| `sched_get_priority_max/min` | Priority range | **MISSING** |
| `sched_rr_get_interval` | Round-robin quantum | **MISSING** |

**Target**: Existing `ISO 9945 Kernel Process`. Estimated growth: +8-12 files.

---

### 11. User and Group Identity — NEW TARGET: `ISO 9945 Kernel Identity`

**Current coverage**: None.

This is a significant gap for any process that needs to manage permissions, switch
users, or query user information.

#### 11a. User/Group IDs (P0)

| Function | Purpose | Status |
|----------|---------|--------|
| `getuid()` | Get real user ID | **MISSING** |
| `geteuid()` | Get effective user ID | **MISSING** |
| `setuid()` | Set user ID | **MISSING** |
| `seteuid()` | Set effective user ID | **MISSING** |
| `getgid()` | Get real group ID | **MISSING** |
| `getegid()` | Get effective group ID | **MISSING** |
| `setgid()` | Set group ID | **MISSING** |
| `setegid()` | Set effective group ID | **MISSING** |
| `getgroups()` | Get supplementary groups | **MISSING** |

#### 11b. User Database (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `getpwnam()` / `getpwnam_r()` | Look up user by name | **MISSING** |
| `getpwuid()` / `getpwuid_r()` | Look up user by UID | **MISSING** |
| `getpwent()` / `setpwent()` / `endpwent()` | Iterate password database | **MISSING** |

#### 11c. Group Database (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `getgrgid()` / `getgrgid_r()` | Look up group by GID | **MISSING** |
| `getgrnam()` / `getgrnam_r()` | Look up group by name | **MISSING** |
| `getgrent()` / `setgrent()` / `endgrent()` | Iterate group database | **MISSING** |

#### 11d. Login / Session (P2)

| Function | Purpose | Status |
|----------|---------|--------|
| `getlogin()` / `getlogin_r()` | Get login name | **MISSING** |
| `ctermid()` | Get controlling terminal path | **MISSING** |

**Target**: New target `ISO 9945 Kernel Identity`. Depends on Core only.
Estimated: 8-12 files.

---

### 12. Terminal — Gaps in `ISO 9945 Kernel Terminal`

**Current coverage**: isatty, ttyname, tcgetattr, tcsetattr, generic ioctl,
Terminal.Stream.Read.

#### 12a. Line Control (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `tcdrain()` | Wait until output transmitted | **MISSING** |
| `tcflush()` | Discard input/output data | **MISSING** |
| `tcflow()` | Suspend/resume transmission | **MISSING** |
| `tcsendbreak()` | Send break signal | **MISSING** |

#### 12b. Baud Rate (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `cfgetispeed()` | Get input baud rate | **MISSING** |
| `cfgetospeed()` | Get output baud rate | **MISSING** |
| `cfsetispeed()` | Set input baud rate | **MISSING** |
| `cfsetospeed()` | Set output baud rate | **MISSING** |

#### 12c. Terminal Control (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `tcgetpgrp()` | Get foreground process group | **MISSING** |
| `tcsetpgrp()` | Set foreground process group | **MISSING** |
| `tcgetsid()` | Get session leader | **MISSING** |

#### 12d. Window Size (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `tcgetwinsize()` | Get terminal window size | **MISSING** |
| `tcsetwinsize()` | Set terminal window size | **MISSING** |

> New in POSIX.1-2024 (replaces the `TIOCGWINSZ` ioctl).

#### 12e. Pseudo-Terminals (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `posix_openpt()` | Open pseudo-terminal master | **MISSING** |
| `grantpt()` | Grant access to slave | **MISSING** |
| `unlockpt()` | Unlock pseudo-terminal pair | **MISSING** |
| `ptsname()` | Get slave device name | **MISSING** |

> Essential for terminal emulators, SSH-like tools, and `expect`-style automation.

**Target**: Existing `ISO 9945 Kernel Terminal`. Estimated growth: +6-10 files.

---

### 13. Timers — Gaps in `ISO 9945 Kernel System`

**Current coverage**: clock_gettime (monotonic, realtime, boot), nanosleep,
ContinuousClock.Instant, time().

#### 13a. POSIX Timers (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `timer_create()` | Create per-process timer | **MISSING** |
| `timer_delete()` | Delete timer | **MISSING** |
| `timer_settime()` | Arm/disarm timer | **MISSING** |
| `timer_gettime()` | Get remaining time | **MISSING** |
| `timer_getoverrun()` | Get overrun count | **MISSING** |

> Mandatory in POSIX.1-2024. Important for periodic tasks and watchdogs.

#### 13b. Clock Selection (P1)

| Function | Purpose | Status |
|----------|---------|--------|
| `clock_nanosleep()` | Sleep against specific clock | **MISSING** |
| `clock_settime()` | Set clock value (realtime) | **MISSING** |
| `clock_getcpuclockid()` | Get process CPU-time clock | **MISSING** |
| `pthread_getcpuclockid()` | Get thread CPU-time clock | **MISSING** |
| `clock_getres()` | Get clock resolution | **MISSING** |

#### 13c. Legacy Timing (P3)

| Function | Purpose | Status |
|----------|---------|--------|
| `alarm()` | Schedule SIGALRM delivery | **MISSING** |
| `sleep()` | Sleep in seconds | **MISSING** |
| `times()` | Process execution times | **MISSING** |

**Target**: Existing `ISO 9945 Kernel System`. Estimated growth: +4-6 files.

---

### 14. Asynchronous I/O — NEW TARGET: `ISO 9945 Kernel IO Async`

**Current coverage**: None.

Mandatory in POSIX.1-2024 (_POSIX_ASYNCHRONOUS_IO).

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `aio_read()` | Async read | P2 | **MISSING** |
| `aio_write()` | Async write | P2 | **MISSING** |
| `aio_error()` | Check async operation status | P2 | **MISSING** |
| `aio_return()` | Get async operation result | P2 | **MISSING** |
| `aio_cancel()` | Cancel async operation | P2 | **MISSING** |
| `aio_suspend()` | Wait for async operations | P2 | **MISSING** |
| `aio_fsync()` | Async file sync | P2 | **MISSING** |
| `lio_listio()` | Batch async I/O submission | P2 | **MISSING** |

> Medium priority despite being mandatory: Swift's structured concurrency (async/await)
> and io_uring/kqueue at the foundation layer provide superior alternatives. Still
> needed for spec completeness.

**Target**: New target `ISO 9945 Kernel IO Async`. Depends on Core only.
Estimated: 4-6 files.

---

### 15. Regular Expressions — NEW TARGET: `ISO 9945 Regex`

**Current coverage**: None.

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `regcomp()` | Compile regular expression | P3 | **MISSING** |
| `regexec()` | Execute compiled regex | P3 | **MISSING** |
| `regerror()` | Get regex error string | P3 | **MISSING** |
| `regfree()` | Free compiled regex | P3 | **MISSING** |

> Low priority: Swift 5.7+ has `Regex` with much richer functionality. POSIX regex
> is BRE/ERE only. Include for spec completeness, but this should not be high priority.

**Target**: New target `ISO 9945 Regex`. Depends on Core only. Estimated: 2-3 files.

---

### 16. System Logging — NEW TARGET: `ISO 9945 Kernel Syslog`

**Current coverage**: None.

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `openlog()` | Open connection to system logger | P2 | **MISSING** |
| `syslog()` | Submit log message | P2 | **MISSING** |
| `closelog()` | Close connection | P2 | **MISSING** |
| `setlogmask()` | Set log priority mask | P2 | **MISSING** |

**Target**: New target `ISO 9945 Kernel Syslog`. Depends on Core only.
Estimated: 2-3 files.

---

### 17. Cryptography (P3 — Legacy)

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `crypt()` | Password hashing | P3 | **MISSING** |

> Legacy. Modern code uses bcrypt/scrypt/argon2. XSI extension, not mandatory.
> Include only for spec completeness.

---

### 18. Database — `ndbm` (P3 — Legacy)

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `dbm_open/close/store/fetch/delete/firstkey/nextkey` | Key-value database | P3 | **MISSING** |

> Legacy. Modern code uses SQLite, LMDB, or application-level storage.
> Include only for spec completeness.

---

### 19. Memory Management — Gaps in `ISO 9945 Kernel Memory`

**Current coverage**: mmap, munmap, msync, madvise (via posix_madvise), mlockall,
munlockall, mlock, munlock, shm_open, shm_unlink, anonymous mapping.

| Function | Purpose | Priority | Status |
|----------|---------|----------|--------|
| `mprotect()` | Change memory protection | P0 | **MISSING** |
| `posix_memalign()` / `aligned_alloc()` | Aligned memory allocation | P2 | **MISSING** |

> `mprotect` is critical — you can `mmap` with one protection and later change it.
> Aligned allocation may be handled by Swift's allocator.

**Target**: Existing `ISO 9945 Kernel Memory`. Minor growth: +1-2 files.

---

## Migration from swift-linux-standard

Commit `fd04244` on `swift-linux-standard/main` created typed wrappers for io_uring
SQE Prepare methods. Several of those types are POSIX concepts that should canonically
live in `swift-iso-9945`. Without migration, Darwin would need duplicates.

### Types to migrate

| Type | Source target | Destination target | POSIX header |
|------|-------------|-------------------|--------------|
| `Kernel.Socket.Address` (namespace) | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket Address` | `<sys/socket.h>` |
| `Kernel.Socket.Address.Family` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket Address` | `<sys/socket.h>` |
| `Kernel.Socket.Address.Storage` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket Address` | `<sys/socket.h>` |
| `Kernel.Socket.Address.IPv4` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket Address` | `<netinet/in.h>` |
| `Kernel.Socket.Address.IPv6` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket Address` | `<netinet/in.h>` |
| `Kernel.Socket.Address.Unix` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket Address` | `<sys/un.h>` |
| `Kernel.Socket.Message.Header` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket IO` | `<sys/socket.h>` |
| `Kernel.Socket.Message.Header.Name` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket IO` | `<sys/socket.h>` |
| `Kernel.Socket.Message.Header.Vectors` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket IO` | `<sys/socket.h>` |
| `Kernel.Socket.Message.Header.Control` | `Linux Kernel Socket Standard` | `ISO 9945 Kernel Socket IO` | `<sys/socket.h>` |
| `Kernel.Process.Wait.Kind` | `Linux Kernel System Standard` | `ISO 9945 Kernel Process` | `<sys/wait.h>` |
| `Kernel.Process.Wait.Options` | `Linux Kernel System Standard` | `ISO 9945 Kernel Process` | `<sys/wait.h>` |

### Migration pattern

Per [PLAT-ARCH-013] shell + values:

1. **ISO 9945** defines the type with POSIX constants (e.g., AF_INET, AF_INET6, AF_UNIX)
2. **Linux Standard** extends with Linux-specific constants (e.g., AF_NETLINK)
3. **Darwin Standard** extends with Darwin-specific constants if any
4. **swift-linux-standard** re-imports from ISO 9945 instead of defining locally

### msghdr note

The handoff document classifies `Kernel.Socket.Message.Header` as Linux-only.
However, `struct msghdr` is defined in POSIX `<sys/socket.h>` — it is the structure
used by `sendmsg()` and `recvmsg()`, which are POSIX functions. The ancillary data
mechanism (`struct cmsghdr`, `CMSG_FIRSTHDR`/`CMSG_NXTHDR`/`CMSG_DATA`) is also POSIX.
The base type should migrate to ISO 9945. Linux-specific ancillary message types
(e.g., `SCM_CREDENTIALS`, `SO_PASSCRED`) and any Linux-specific msghdr field access
patterns remain at L2 Linux.

### Types correctly at L2 Linux (no migration)

| Type | Reason |
|------|--------|
| `Kernel.IO.Uring.Timeout.Specification` | `__kernel_timespec` — Linux kernel ABI |
| `Kernel.Futex.Wait.Entry` | `futex_waitv` — Linux-specific |
| `Kernel.File.Open.How` + `Resolve` | `openat2(2)` — Linux-specific |
| `Kernel.File.Statx` + subtypes | `statx(2)` — Linux-specific |
| `Kernel.Signal.Information` + `Code` | `siginfo_t` — POSIX concept but Linux field access (`_sifields._kill.si_pid`) is platform-specific |

### Remaining io_uring Prepare typing opportunities

Not POSIX-related, but noted from the handoff — these Prepare parameters are still
raw integers:

- `socket(domain: Int32, type: Int32, protocol: Int32)` → `Socket.Address.Family` + `Socket.Kind`
- `openat(mode: UInt32)` → `Kernel.File.Permissions`
- `shutdown(how: Int32)` → typed enum
- `fadvise(advice: UInt32)` / `madvise(advice: UInt32)` → typed enums

After migration, `domain` and `type` can use the ISO 9945 types directly.

---

## Summary: Coverage Heat Map

| POSIX Functional Area | Current | Target Coverage | Gap Size | Priority |
|-----------------------|---------|-----------------|----------|----------|
| **Sockets / Networking** | 15% | Full lifecycle + addresses + resolution | **MASSIVE** | P0 |
| **I/O Multiplexing (poll)** | 0% | poll + select | **LARGE** | P0 |
| **File I/O (pread/pwrite/readv/writev)** | 70% | +positional, vector, truncate, *at() | MEDIUM | P0-P1 |
| **User/Group Identity** | 0% | UIDs, GIDs, user/group database | **LARGE** | P0 |
| **Thread Synchronization** | 30% | +RW locks, barriers, spinlocks, attrs | **LARGE** | P0-P1 |
| **Signals** | 70% | +sigwait, realtime, altstack | SMALL | P1 |
| **Process** | 60% | +exec family, spawn attrs, rlimits | MEDIUM | P1 |
| **Terminal** | 40% | +line control, baud, PTY, window size | MEDIUM | P1 |
| **POSIX Semaphores** | 0% | Named + unnamed | MEDIUM | P1 |
| **Timers** | 30% | +timer_create/set, clock_nanosleep | MEDIUM | P1 |
| **File System (access/umask/mkfifo/statvfs)** | 50% | +accessibility, creation mask, FS info | MEDIUM | P1-P2 |
| **POSIX Message Queues** | 0% | mq_* family | SMALL | P2 |
| **IO.Async** | 0% | aio_* family | MEDIUM | P2 |
| **System V IPC** | 0% | shm/msg/sem | MEDIUM | P2-P3 |
| **System Logging** | 0% | syslog | SMALL | P2 |
| **Memory (mprotect)** | 90% | +mprotect, aligned_alloc | SMALL | P0 |
| **Regular Expressions** | 0% | regcomp/regexec | SMALL | P3 |
| **Cryptography** | 0% | crypt | TRIVIAL | P3 |
| **ndbm Database** | 0% | dbm_* | TRIVIAL | P3 |

---

## Proposed New Targets

The modularization research (`iso-9945-kernel-modularization.md`) proposes 12 kernel
variant targets. For full spec coverage, additional targets are needed:

| # | New Target | POSIX Domain | Est. Files | Dependencies |
|---|-----------|--------------|------------|--------------|
| 1 | `ISO 9945 Kernel Poll` | I/O multiplexing | 4-6 | Core |
| 2 | `ISO 9945 Kernel Semaphore` | POSIX semaphores | 4-6 | Core |
| 3 | `ISO 9945 Kernel Identity` | User/group IDs, databases | 8-12 | Core |
| 4 | `ISO 9945 Kernel Message Queue` | POSIX message queues | 4-6 | Core, Signal |
| 5 | `ISO 9945 Kernel IO Async` | Asynchronous I/O | 4-6 | Core |
| 6 | `ISO 9945 Kernel IPC` | System V shared mem, msg, sem | 6-10 | Core |
| 7 | `ISO 9945 Kernel Syslog` | System logging | 2-3 | Core |
| 8 | `ISO 9945 Regex` | POSIX regular expressions | 2-3 | Core |

**Revised dependency graph** (existing + new targets):

```
                          ISO 9945 Core (internal)
          /   /   /   |    |    |    \    \    \    \    \    \    \    \    \
       File Dir Lock Sock Mem  Sig  Thrd Term  Env  Sys Poll  Sem  Id  IO.Async Syslog
                                |                               |
                             Process                         MsgQ
                                                               |
                                                          IPC  Regex
```

All new targets are leaves except Message Queue (→ Signal). Deeper dependency
chains are acceptable if the domain requires it.

---

## Recommended Implementation Order

### Phase 1 — Core OS Gaps (P0)

These block real-world use of the package:

1. **Socket lifecycle + addresses + resolution** — without `bind/listen/accept/connect`,
   no networking is possible
2. **poll()** — without I/O multiplexing, no event-driven I/O
3. **pread/pwrite + readv/writev** — essential for concurrent and high-performance I/O
4. **mprotect** — completes the memory mapping story
5. **User/group identity** — `getuid/setuid` needed for any privilege management

### Phase 2 — Completeness (P1)

6. **Lock.ReadWrite + Barrier + Lock.Spin** — complete the thread synchronization story
7. **Thread lifecycle + attributes** — detach, cancel, TSD, attributes
8. **Terminal line control + baud + PTY** — complete the terminal story
9. **sigwait/sigsuspend** — signal-driven design patterns
10. **POSIX timers** — timer_create/set for periodic tasks
11. **posix_spawn file actions + attributes** — make spawn actually usable
12. **Exec family** — fexecve and convenience variants
13. **File system: access, umask, mkfifo, mkstemp, readlink, *at() family**
14. **POSIX semaphores** — named and unnamed
15. **Resource limits** — getrlimit/setrlimit
16. **Hostname** — gethostname

### Phase 3 — Extended Coverage (P2-P3)

17. **File system: statvfs, pathconf, glob, fnmatch, nftw**
18. **POSIX message queues**
19. **Asynchronous I/O**
20. **System V IPC**
21. **System logging**
22. **select/pselect** — legacy complement to poll
23. **Process scheduling** — nice, getpriority, sched_*
24. **Mutex/condition attributes** — advanced threading
25. **Signal: realtime, altstack, utilities**
26. **Regular expressions** — spec completeness
27. **Cryptography, ndbm** — spec completeness

---

## Quantitative Summary

| Metric | Current | After Full Coverage |
|--------|---------|-------------------|
| Source files | ~97 | ~200-240 |
| Kernel variant targets | 12 | 20 |
| POSIX function coverage | ~120 functions | ~400+ functions |
| Spec coverage (System Interfaces) | ~30% | ~85%+ |

The remaining ~15% are C library functions (stdio, string, math, locale) that belong
in `swift-iso-9899`, not in the POSIX kernel wrapper.

---

## Prior Art

### Swift System (apple/swift-system)
Covers: open, close, read, write, seek, stat, chmod, mkdir, rmdir, chdir, getcwd,
dup, pipe, fcntl, ioctl, errno. Roughly equivalent to `ISO 9945 Kernel File` subset.
Does not cover: sockets, signals, process management, threads, memory mapping, IPC.

### Swift NIO (apple/swift-nio)
Covers sockets and I/O multiplexing at a higher abstraction level (event loops, channels).
Uses raw syscalls internally. Does not expose POSIX-level types.

### Glibc / Musl module maps
Swift on Linux imports Glibc/Musl directly. All POSIX functions are accessible but
without type safety, error handling, or Swift API conventions.

### Rust libc + nix crate
`nix` provides safe Rust wrappers for POSIX functions with complete coverage across
sockets, signals, ptrace, mount, mqueue, pty, poll, resource limits, sched, termios,
and user/group. Comparable scope to what full `swift-iso-9945` would achieve.

---

## References

- IEEE Std 1003.1-2024 (POSIX.1-2024), The Open Group Base Specifications Issue 8
- The Open Group: https://pubs.opengroup.org/onlinepubs/9799919799/
- `iso-9945-kernel-modularization.md` — companion modularization analysis
- `audit.md` — existing implementation audit
