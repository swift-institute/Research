---
date: 2026-04-12
session_objective: Fix io_uring SQE @inlinable visibility, wrap all C types, discover ~Escapable pointer-elimination architecture
packages:
  - swift-linux-standard
status: processed
---

# io_uring: From C Type Leakage to ~Escapable Coroutine Architecture

## What Happened

Two-day session (2026-04-10 to 2026-04-12). Started with a build-blocking `@inlinable` vs `internal var cValue: io_uring_sqe` issue. Ended with a validated architecture that eliminates the Prepare type, all view types, and all pointers from the public API.

**Phase 1 (build fix):** Removed `@inlinable` from 65 Prepare methods. Created ecosystem wrappers for msghdr, __kernel_timespec, futex_waitv. 3 commits, build clean.

**Phase 2 (full C type wrapping):** Wrapped ALL remaining C types (open_how, epoll_event, statx, siginfo_t, sockaddr family). Refactored `Kernel.Event.Poll.Event` to cValue storage for x86-64 packed layout. Made Target ~Copyable with `case descriptor(Kernel.Descriptor)`. Typed every raw integer parameter. 35 files changed, 28 new type files.

**Phase 3 (architecture discovery):** User challenged "why pointers at all?" Investigated pointer elimination. Discovered via experiment that `~Escapable` via function return FAILS (V3 REFUTED — compiler can't trace lifetime through `UnsafeMutablePointer` indirection) but `~Escapable` via `_read` coroutine yield WORKS (V6 CONFIRMED — coroutine scope IS the lifetime boundary). This matched Property.View's established pattern (599 ecosystem sites).

**Final architecture:** `ring.next` yields `~Copyable ~Escapable` Slot via `mutating _read`. Preparation methods become `@inlinable mutating` on Entry. Call site: `ring.next.entry.read(...)`. Eliminates: Prepare type, 21 view types, all pointers in public API. Creates: 1 Slot type, ~11 @usableFromInline accessors on Entry.

## What Worked and What Didn't

**Worked well:**
- The experiment-driven approach. Six variants (V1-V6) systematically narrowed the design space. V3's failure taught us more than V6's success — it revealed the function-return vs coroutine-yield distinction.
- Searching the existing experiment corpus (20+ ~Escapable experiments) before writing new ones. The Property.View pattern was already validated — we just needed to recognize our problem was the same shape.
- User's pushback at every stage raised the quality: "no thin wrappers" → "no raw types" → "no pointers" → "yes ~Escapable." Each rejection led to a better architecture.

**Didn't work well:**
- Initial assumption that `~Escapable` couldn't work for mmap'd memory was wrong. Only function-return `~Escapable` doesn't work; coroutine-yield `~Escapable` works perfectly.
- Attempted `@lifetime(borrow self)` + `mutating func` before understanding they're fundamentally incompatible (inout = exclusive, borrow = shared). Should have checked the lifetime annotation semantics first.
- Tried to downgrade `Kernel.Descriptor` to `Int32` in Target enum — user correctly caught this as a type-safety regression.

## Patterns and Root Causes

**Yielding vs returning for ~Escapable pointer-backed views:** This is the session's central discovery. `_read`/`_modify` coroutines provide scoped lifetime that the compiler enforces structurally — the yielded value CANNOT escape the coroutine's scope. Function returns require explicit `@lifetime` annotations and the compiler must trace the lifetime chain through pointer indirection, which it cannot do for stored `UnsafeMutablePointer` properties. The ecosystem already knew this (599 yield sites vs 28 return sites), but the io_uring case makes the distinction concrete for mmap'd shared memory.

**@inlinable dissolves when methods live on the domain type.** The entire @inlinable problem existed because methods were on a Prepare WRAPPER that accessed cValue through a pointer. Moving methods to Entry (the domain type itself) eliminates the problem — `self.opcode`, `self.addr` are public accessors. The wrapper WAS the problem, not the solution.

**Progressive architecture improvement through user challenge.** The session went through four architectures: (1) remove @inlinable, (2) view types on Prepare, (3) ~Copyable Slot with methods on Entry, (4) ~Escapable Slot via coroutine. Each was "correct" at its level but insufficient for the user's quality bar. The final architecture is strictly superior on every dimension.

## Action Items

- [ ] **[skill]** platform: Document ~Escapable coroutine yield as the canonical pattern for lifetime-safe views of mmap'd/externally-managed memory — function return doesn't work, _read/_modify yield does [PLAT-new]
- [ ] **[skill]** implementation: Add [IMPL-new] for @inlinable + internal C type wrapping — interpose @usableFromInline computed accessors between @inlinable bodies and internal cValue storage
- [ ] **[package]** swift-linux-standard: Implement V6 architecture — move 65 Prepare methods to Entry, create Slot type, add Ring.next coroutine property
