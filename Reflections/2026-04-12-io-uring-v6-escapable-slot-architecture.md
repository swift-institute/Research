---
date: 2026-04-12
session_objective: Implement V6 ~Escapable coroutine architecture for io_uring SQE preparation, then audit and harden to theoretical perfection
packages:
  - swift-linux-standard
  - swift-iso-9945
status: processed
---

# io_uring V6: ~Copyable ~Escapable Slot Architecture

## What Happened

Implemented the V6 architecture for io_uring SQE preparation — replacing the pointer-backed Prepare type (14 files, 13 view types) with a `~Copyable ~Escapable` Slot yielded via `mutating _read` coroutine. The confirmed experiment pattern: `ring.next.entry.read(...)` where the coroutine scope IS the lifetime boundary.

**Architecture chain**: `Ring.next` (`mutating _read`) yields `~Escapable Slot` → `Slot.entry` (`nonmutating _modify`) yields `inout Entry` → `Entry.read()` (`@inlinable mutating`) accesses `@usableFromInline` typed accessors.

Then spent the second half hardening the implementation through systematic audit:
- Made Entry `~Copyable` (SQE slot has unique-owner semantics)
- Added ~30 typed union field accessors, eliminating 40+ `.rawValue` extractions and all `UInt64(UInt(bitPattern:))` casts from @inlinable bodies
- Removed superseded APIs (Entry.Buffer, Entry.Op, nextEntry)
- Fixed compound identifiers (vectoredFixed → vectored.standard, sendMessage → message.send)
- Removed 230 unused template-copied imports across 59 files
- Added Cancel.Options OptionSet
- Fixed incorrect doc comments, lossy xattr getter, raw public types

**Final state**: 83 source files, 223 tests pass on Docker swift:6.3 (including 4 live io_uring integration tests), zero raw types in public API.

## What Worked and What Didn't

**What worked well**:
- The experiment-first approach (V6 validated before implementation) prevented all design-level dead ends
- The handoff document was precise enough to implement from without re-discovery
- The `@usableFromInline` accessor layer cleanly separates C ABI from Swift intent — every @inlinable body reads as domain operations
- Making Entry ~Copyable required only 2 lines changed (borrowing annotations on legacy accessor inits) — the V6 architecture was already ownership-correct
- The file-by-file audit (83 parallel reports) found real issues: lossy xattr getter, incorrect doc comments, opcode duplication

**What didn't work well**:
- Pre-existing test rot was severe — tests hadn't compiled since the domain-type migration. Each fix revealed the next (stale imports → wrong module names → CLinuxShim rename → missing Test Support → Tagged init patterns → type collision). Five Docker round-trips just to get tests compiling.
- The unused-imports agent was over-aggressive — removed `Linux_Kernel_System_Standard` from Params.Submission.Thread.swift which needed `System.Processor.ID`. The agent treated all non-`Kernel_IO_Primitives` imports as template copies without checking transitive type usage.
- SPM transitive identity unification failure was unexpected — `swift-witness-primitives` and `swift-standard-library-extensions` entered the graph via multiple relative paths without top-level registration. And stale `.build` directories from previous Docker runs caused intermittent "no such module" errors that looked like dependency problems.

## Patterns and Root Causes

**Pattern: The C union accessor bridge is essential complexity, not accidental.**
The io_uring SQE is a 64-byte C struct where `len` means "byte count" for read but "permission mode" for mkdirat and "protocol" for socket. Swift has no union type. The typed accessor layer (`pollOptions`, `socketProtocol`, `waitidKind`) is the thinnest possible bridge: zero-cost computed properties that convert between Swift domain types and C raw fields. The remaining `_rawLength` (19 uses) accessor is irreducible — it covers ~10 different semantic meanings with no shared domain type.

**Pattern: Swift metatype namespaces force `.standard` leaves.**
An identifier cannot simultaneously be an `Opcode` value AND a namespace with members. The Property/callAsFunction pattern solves a different problem (verb namespacing over mutable instances). For static opcode hierarchies like `.read.vectored.standard` / `.read.vectored.fixed`, the metatype-as-namespace pattern is the only Swift-idiomatic solution. The `.standard` suffix is a language constraint, not a design choice.

**Pattern: ~Escapable via coroutine yield works where function return fails.**
The V6 experiment confirmed: `@lifetime(borrow self)` + `mutating func` = "invalid use of borrow dependence with inout ownership". But `_read` coroutine yield works because the coroutine scope IS the lifetime boundary — no `@lifetime` annotation needed. This is the same pattern as Property.View (599 ecosystem sites).

## Action Items

- [ ] **[package]** swift-linux-standard: Audit io_uring for spec completeness — ~15 newer kernel flags (6.4+) absent, Cancel.Options not wired to cancel method, Send/Socket opcode duplication unresolved
- [ ] **[skill]** testing: Add guidance for Tagged typealias collision — when multiple Tagged specializations define `enum Test {}` in the same compilation unit, they collide on `Tagged.Test`. Use parent-namespace enum names (e.g., `LengthTest`, `DataTest`) instead.
- [ ] **[research]** Investigate whether io_uring domain types (Timeout.Specification, Vector, Clock, Poll.Trigger) belong in L2 swift-linux-standard or should be extracted to L1 primitives — they have no Linux-specific implementation, just kernel ABI layout
