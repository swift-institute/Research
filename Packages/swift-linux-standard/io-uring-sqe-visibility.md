---
date: 2026-04-10
status: resolved
resolution-date: 2026-04-11
severity: build-blocking
packages:
  - swift-linux-standard
---

# io_uring SQE Entry: @inlinable vs Internal C Type Visibility

## Problem

`Kernel.IO.Uring.Submission.Queue.Entry.Prepare` methods are `@inlinable public` but reference `pointer.pointee.cValue` which is `internal var cValue: io_uring_sqe`. With `InternalImportsByDefault`, the C struct `io_uring_sqe` (from `CLinuxKernelShim`) is internal and cannot be used in `@inlinable` code.

**Error**: `property 'cValue' is internal and cannot be referenced from an '@inlinable' function`

**File**: `Sources/Linux Kernel IO Uring Standard/Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift`

This affects ALL ~60 `Prepare` methods (read, write, send, recv, poll, timeout, cancel, etc.).

## Architecture Context

```
Entry {
    internal var cValue: io_uring_sqe    // C struct, internal
}

extension Entry.Prepare {
    @unsafe @inlinable                    // needs cValue visible to caller
    public func read(...) {
        unsafe (pointer.pointee.cValue = io_uring_sqe())  // ERROR: internal
        unsafe (pointer.pointee.opcode = ...)
    }
}
```

The `Prepare` type is a pointer-wrapper that fills SQE entries in the shared ring buffer. `@inlinable` is used for zero-overhead submission — these are hot-path operations.

## Options

### Option A: Remove @inlinable from Prepare methods
- Simplest fix. No visibility issues.
- **Cost**: Function call overhead on every SQE submission. For io_uring, this is the critical path — each syscall batches dozens of submissions. The overhead may be acceptable since the kernel syscall dominates.
- **Risk**: May need benchmarking to confirm performance is acceptable.

### Option B: Make cValue @usableFromInline
- `@usableFromInline internal var cValue: io_uring_sqe`
- Exposes the storage layout to callers but keeps it nominally internal.
- **Requires**: `io_uring_sqe` itself must be visible — needs `CLinuxKernelShim` imported as `public import` in the Entry's module, OR the SQE type wrapped in a `@frozen public struct`.
- **Risk**: Leaks C ABI through `@usableFromInline`, defeating [PLAT-ARCH-005a].

### Option C: Replace cValue with raw storage
- Replace `internal var cValue: io_uring_sqe` with `public var storage: (UInt64, UInt64, ..., UInt64)` — a fixed-size tuple matching `io_uring_sqe`'s layout.
- Prepare methods write to storage offsets directly.
- **Cost**: Manual offset arithmetic, loss of field names. Error-prone.
- **Benefit**: No C type in any position (public, internal, or @usableFromInline).

### Option D: Use @_spi(Syscall) on Prepare methods
- Gate all Prepare methods behind `@_spi(Syscall)`.
- Consumers use SPI to access low-level SQE filling.
- Higher-level APIs (not yet built) provide the ergonomic interface without SPI.
- **Benefit**: Honest — these ARE syscall-level operations. The SPI boundary communicates that.
- **Cost**: All current consumers need `@_spi(Syscall) import`.

## Recommendation

**Option D** (SPI) as the immediate unblock, with Option A as the long-term direction once higher-level io_uring APIs exist. The Prepare methods ARE raw syscall-level code — SPI is the correct visibility for them.

## Also Note

Three methods had `msghdr`, `__kernel_timespec`, and `futex_waitv` C types in public API parameters. These were changed to `UnsafeRawPointer` as a quick fix, but per user direction: **no Unsafe* or *Pointer types in public API at all**. These need proper ecosystem type wrappers in a follow-up.

## Reproduction

```bash
docker run --rm -v /Users/coen/Developer:/workspace swift:6.3 bash -c \
  "apt-get update -qq && apt-get install -y -qq uuid-dev > /dev/null 2>&1 && \
   find /workspace -name .build -type d -exec rm -rf {} + 2>/dev/null; \
   cd /workspace/swift-linux-foundation/swift-linux-standard && \
   swift build -j 1 2>&1 | grep 'error:' | head -5"
```
