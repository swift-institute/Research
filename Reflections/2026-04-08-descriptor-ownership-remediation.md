---
date: 2026-04-08
session_objective: Investigate and remediate Kernel.Descriptor(_rawValue:) ownership aliasing across all Swift Institute superrepos
packages:
  - swift-kernel-primitives
  - swift-linux-primitives
  - swift-iso-9945
  - swift-kernel
  - swift-io
status: pending
---

# Descriptor Ownership Remediation — Language Features Over Custom Types

## What Happened

Picked up `HANDOFF-descriptor-ownership-audit.md` from the parent session (which fixed 3 initial anti-patterns in swift-iso-9945). Grepped all Swift Institute superrepos for `Kernel.Descriptor(_rawValue:` and sibling `~Copyable` resource constructors. Found 7 anti-pattern groups (3 CRITICAL, 4 HIGH/MEDIUM) covering 15 call sites across 5 repos, plus 16 legitimate uses and 6 clean sibling types.

Wrote findings and initial recommendations. The initial recommendations proposed `_take()` SPI on Kernel.Descriptor, `Kernel.Descriptor.Raw` Copyable newtype, and raw-Int overloads on consumer APIs (`Poll.ctl(rawFD: Int32, ...)`, `Prepare.read(rawFD: Int32, ...)`). User rejected all three — each was a mechanism leak that bypassed the type system instead of expressing ownership through it.

Corrected approach used only Swift language features. Fixed 6 of 7 groups (2 deferred in swift-io "Do Not Touch" submodule):

| Fix | Language feature | Commit |
|-----|-----------------|--------|
| Epoll driver (4 sites) | Borrow `entry.descriptor` in place inside lock scope via extract-syscall-reinsert | `4e84a38` swift-kernel |
| dup2 wrapper | `to: inout Kernel.Descriptor`, return `Void` | `639dc17` swift-iso-9945 |
| dup3 wrapper | Same `inout` pattern | `f2fc4cc` swift-linux-primitives |
| Terminal.Stream.Read | Typed `Kernel.IO.Read.read(_ stream: Terminal.Stream, into:)` overload — C boundary does raw extraction | `639dc17` swift-iso-9945 |
| SQE.Entry.fd accessor | Deleted (dead code, ownership lie) | `d847277` swift-linux-primitives |
| Event.ID Tests | Pipe-borrowed descriptors + math verification | `639dc17` swift-iso-9945 |

527 tests pass in swift-iso-9945 after all changes. Linux-only changes (epoll, SQE, dup3) are compile-verified by structure but not runtime-tested (macOS host).

## What Worked and What Didn't

**Worked well**: The audit methodology — systematic grep, categorize each match, read surrounding context — found the anti-patterns efficiently. The kqueue driver being already-correct (zero anti-patterns) provided a direct reference architecture for the epoll fix. The `extract → borrow → reinsert` pattern inside `withLock` was the natural solution once the "borrow in place" principle was clear.

**Worked well**: The `inout Kernel.Descriptor` insight for dup2/dup3. The kernel atomically replaces the resource at a slot — `inout` is the exact language primitive for "same binding, mutated content." Zero auxiliary types, zero suppress-close mechanisms.

**Did not work**: Three rounds of incorrect recommendations before arriving at the language-feature-only approach. First proposed `Kernel.Descriptor.Raw` + raw-Int overloads. Then `consuming` + `_take()` SPI. Then process-scoped static `Kernel.Descriptor` singletons. Each was a custom mechanism that the type system's existing features (`borrowing`, `inout`, typed overloads) already handled.

**Root cause of the missteps**: Solving the symptom ("need to pass an fd without closing") instead of the cause ("the code doesn't have the real owned Descriptor available at the call site"). Every proposed workaround accepted the structural defect and patched around it. The correct approach restructured the code so the real owned Descriptor IS available.

## Patterns and Root Causes

**"The fix is structural, not API-additive."** Every anti-pattern had the same shape: code extracted `._rawValue` from an owned Descriptor, crossed an ownership boundary (lock scope, function return, class storage), then reconstructed an owning Descriptor on the other side. The reconstruction is the bug. The fix in every case was restructuring so the borrow flows through the boundary without breaking:

| Boundary crossed | Reconstruction (broken) | Borrow flow (fixed) |
|-----------------|------------------------|---------------------|
| Lock scope (Mutex) | Extract raw inside lock, reconstruct outside | Call syscall inside lock, borrow the stored Descriptor |
| Function return (dup2) | Return `Kernel.Descriptor(_rawValue: result)` | `inout` parameter, return `Void` |
| Class storage (IO.Channel) | Store `rawDescriptor: Int32`, reconstruct at submit | (Deferred) Store Channel reference, borrow at submit |
| Copyable enum (Terminal.Stream) | Construct from `stream.rawValue` | Typed overload at C boundary |
| Computed property (SQE.fd) | Getter fabricates owning Descriptor | Delete the accessor |

The pattern generalizes: when a `~Copyable` resource crosses a boundary via raw value extraction + reconstruction, the fix is to make the owned value accessible on the other side of the boundary, not to create a second owner.

**"Mechanism leaks are recursive."** Each workaround for the original bug (`_rawValue:` reconstruction) generated a new mechanism leak that needed its own workaround. `_take()` needed suppress-close; `Kernel.Descriptor.Raw` needed conversion overloads; raw-Int overloads needed typed wrappers. Language features terminate this recursion because they're already closed under composition.

## Action Items

- [ ] **[skill]** implementation: Add `inout` to the ownership annotations table in [IMPL-067] — it's the correct primitive for atomic replacement semantics on `~Copyable` types, and the current table only lists `consuming`/`borrowing`/`inout` without the replacement-semantics use case.
- [ ] **[package]** swift-io: Remediate the 5 deferred IOCP/IOUring sites (Storage→Channel reference refactor). These are the remaining CRITICAL/HIGH findings from the audit. Requires swift-io submodule to be in a committable state.
- [ ] **[research]** Should `Kernel.Descriptor.init?(_ id: Kernel.Event.ID)` be deprecated? It inherently constructs an aliasing owner from an ID. The only safe callers are event-loop completion handlers that receive a new fd from the kernel (e.g., io_uring accept CQE). All other callers alias an existing owner.
