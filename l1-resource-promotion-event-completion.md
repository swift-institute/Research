# L1 Resource Promotion for Event and Completion

<!--
---
version: 1.0.0
last_updated: 2026-04-13
status: IN_PROGRESS
tier: 2
related:
  - swift-kernel/Research/completion-architecture-audit.md
  - swift-kernel/Research/unified-completion-api-design.md
  - swift-kernel/Research/kernel-completion-driver-redesign.md
  - swift-kernel/Research/kernel-event-driver-zero-allocation-redesign.md
---
-->

## Context

`Kernel.Event.Source` (reactor) and `Kernel.Completion` (proactor) are both `~Copyable`
resource types that follow the same structural pattern: a witness struct of closures
(Driver), a wakeup channel, and platform-specific backend factories. Both currently
live at L3 (`swift-kernel` in `swift-foundations`).

A prior audit (`completion-architecture-audit.md`) found that L1 `Kernel Completion
Primitives` was vestigial dead code and proposed extracting 7 vocabulary types to L1,
keeping the resource at L3. During review, a stronger position emerged: push
**everything** except the backend factory implementations to L1. This forces
backend-agnosticism as a structural constraint rather than a convention.

The Event pattern is the proven reference — the same question applies to both.

## Question

Should `Kernel.Event.Source`, `Kernel.Completion`, and their full supporting type
trees (Driver, Submission, Notification, Capabilities, etc.) move from L3 to L1,
leaving only the backend factory implementations (+Kqueue, +Epoll, +IOUring, +IOCP)
at L3?

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Backend agnosticism | High | Does the split FORCE types to be backend-agnostic? |
| [PLAT-ARCH-012] compliance | High | "Did WE define this?" → L1. "Composed behavior?" → L3. |
| Dependency validity | High | Can all stored properties and closure signatures be expressed with L1 types only? |
| L3 thinness | Medium | How thin do the L3 targets become? Thinner = cleaner separation. |
| Consumer impact | Medium | Does `import Kernel` still work the same for consumers? |
| Migration cost | Low | How much code moves, how many renames? |

## Analysis

### Option A: Status Quo (vocabulary at L1, resources at L3)

L1 provides data types only. L3 provides resources, drivers, and all supporting types.

**Event**:
- L1: `Event` struct, `Event.ID`, `Interest`, `Options` (4 types, ~307 LOC)
- L3: `Event.Source`, `Event.Driver`, `Registration`, `Error`, +Kqueue, +Epoll (7 files, ~805 LOC)

**Completion** (post vestigial cleanup):
- L1: `Completion` namespace, `Token`, `Event`, `Event.Result`, `Event.Flags`, `Event.Count`, `Error` (7 types, ~150 LOC)
- L3: `Completion` resource, `Driver`, `Submission` tree, `Notification`, `Capabilities`, +IOUring (21 files, ~1,170 LOC)

| Criterion | Assessment |
|-----------|-----------|
| Backend agnosticism | **Weak.** No structural enforcement. L3 types CAN be io_uring-biased — and they are (`Submission.Length` comment: "structurally determined by io_uring SQE layout"). |
| [PLAT-ARCH-012] | **Partial.** Vocabulary types pass. But Driver, Submission, and Completion are "our types, our design" — they're not composed from platform types. |
| Dependency validity | **N/A.** No L1 dependency concern. |
| L3 thinness | **Thick.** L3 holds 14 composition types + 2 backends for Completion. |
| Consumer impact | **None.** Current state. |
| Migration cost | **None.** Current state. |

### Option B: Full Resource Promotion to L1

Move resources, drivers, and all supporting types to L1. L3 retains only backend
factory functions that construct the L1 types by filling in platform-specific closures.

**Event**:
- L1: Everything from Option A, PLUS `Event.Source`, `Event.Driver`, `Registration`, `Error` (~805 LOC → L1)
- L3: `Event.Source+Kqueue.swift` (226 LOC), `Event.Source+Epoll.swift` (251 LOC), `exports.swift`

**Completion**:
- L1: Everything from Option A, PLUS `Completion` resource, `Driver`, `Submission` tree, `Notification`, `Capabilities` (~1,020 LOC → L1)
- L3: `Completion+IOUring.swift` (348 LOC), `Completion+IOCP.swift` (future), `exports.swift`

#### Feasibility: Can Every Type Be L1?

Each stored property and closure signature must reference only L1 types:

**Event.Source**:
```
driver: Event.Driver          → L1 (promoted)
wakeup: Kernel.Wakeup.Channel → L1 (already Kernel Primitives Core)
```
✓ All L1.

**Event.Driver** (closure signatures):
```
_register: (consuming Kernel.Descriptor, Event.Interest) throws(Error) → Event.ID
_modify:   (Event.ID, Event.Interest) throws(Error) → Void
_deregister: (Event.ID) throws(Error) → Void
_arm:      (Event.ID, Event.Interest) throws(Error) → Void
_poll:     (Kernel.Time.Deadline?, inout [Event]) throws(Error) → Int
_close:    () → Void
```
Every type referenced: `Kernel.Descriptor` (L1), `Event.Interest` (L1), `Event.ID` (L1),
`Kernel.Time.Deadline` (L1), `Event` (L1), `Error` (promoted to L1).
✓ All L1.

**Event.Driver init** (non-closure logic):
- ID generation: counter with wrapping increment. No platform types.
- Registry: `Dictionary<Event.ID, Registration>`. Uses `Dictionary_Primitives` (L1).
- Staleness suppression: in-place compaction by registry membership. Pure logic.
✓ All backend-agnostic.

**Completion resource**:
```
driver: Driver                  → L1 (promoted)
wakeup: Kernel.Wakeup.Channel  → L1
notification: Notification?     → L1 (if we remove #if os(Linux))
capabilities: Capabilities      → L1 (Bool flags, no platform imports)
```

**Notification** currently has `#if os(Linux)`. Resolution: wrap `Kernel.Descriptor`
unconditionally. The factory decides what descriptor to store (eventfd on Linux, nil on
IOCP). The `#if` moves from the type definition to the factory.

```swift
// L1 — backend-agnostic
public struct Notification: ~Copyable, Sendable {
    public let descriptor: Kernel.Descriptor
}
```
✓ All L1 after removing the conditional.

**Completion.Driver** (closure signatures):
```
_submit: (Submission, borrowing Kernel.Descriptor) throws(Error) → Void
_flush:  () throws(Error) → Submission.Count
_drain:  ((Completion.Event) → Void) → Event.Count
_close:  () → Void
```
Every type referenced: `Submission` (promoted), `Kernel.Descriptor` (L1), `Error` (L1),
`Submission.Count` (promoted), `Completion.Event` (L1), `Event.Count` (L1).
✓ All L1 after promotion.

**Submission fields**:
```
opcode: Opcode          → L1 (10 universal operations)
token: Token            → L1 (already vocabulary)
address: Address        → L1 (UInt64 buffer pointer, universal)
length: Length          → L1 (UInt32, fits both io_uring and IOCP DWORD)
offset: Offset          → L1 (UInt64, fits both io_uring and OVERLAPPED)
flags: Flags            → L1 shell, L3 adds constants per [PLAT-ARCH-013]
bufferGroup: Buffer.Group → L1 (Tagged UInt16, ignored by IOCP)
```
✓ All L1. The io_uring SQE layout comments in Length/Offset become inaccurate
and should be rewritten as backend-agnostic documentation.

**Submission.Flags** — the [PLAT-ARCH-013] shell + values pattern:
```swift
// L1 — empty shell
extension Kernel.Completion.Submission {
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
    }
}

// L3 — backend adds constants
extension Kernel.Completion.Submission.Flags {
    public static let bufferSelect = Flags(rawValue: 1 << 0)
    public static let linked       = Flags(rawValue: 1 << 1)
    public static let drain        = Flags(rawValue: 1 << 2)
    public static let fixedFile    = Flags(rawValue: 1 << 3)
}
```

**Capabilities**:
```
multishot: Bool       → no platform import
providedBuffers: Bool → no platform import
```
✓ L1. Backends set these to true/false at construction time.

| Criterion | Assessment |
|-----------|-----------|
| Backend agnosticism | **Strong.** Structural enforcement: if a type can't compile at L1 without platform imports, it can't exist. The forcing function catches bias at compile time. |
| [PLAT-ARCH-012] | **Full.** Every promoted type passes "Did WE define this?" — Source, Driver, Submission, Notification, Capabilities are all our abstractions. Backend factories are composed behavior (L3). |
| Dependency validity | **Verified.** Every stored property and closure signature resolves to L1 types. See feasibility analysis above. |
| L3 thinness | **Maximally thin.** L3 Event: 2 files (kqueue + epoll) + exports. L3 Completion: 1 file (io_uring) + exports. Backends are pure factory functions returning L1 types. |
| Consumer impact | **None.** `import Kernel` re-exports both L1 and L3. Consumer code unchanged. |
| Migration cost | **Medium.** ~1,800 LOC moves from L3 to L1 across both targets. Submission.Flags constants split to L3 extension. No type renames needed. |

### Option C: Partial Promotion (Driver shape at L1, Driver logic at L3)

Move only the type definitions (struct declarations, closure type signatures) to L1.
Keep the Driver's init body (ID generation, registry, staleness suppression) at L3.

This is a middle ground: L1 defines the API surface, L3 provides the implementation.

| Criterion | Assessment |
|-----------|-----------|
| Backend agnosticism | **Moderate.** Type shapes are enforced at L1, but implementation logic at L3 has no structural backend constraint. |
| [PLAT-ARCH-012] | **Partial.** Types are "our design" (L1). Logic is "our composition" (L3). Defensible but finer-grained than needed. |
| Dependency validity | **Trivially satisfied.** L1 has only type shells. |
| L3 thinness | **Moderate.** L3 still holds Driver init body + backends. |
| Consumer impact | **None.** Same import story. |
| Migration cost | **Low.** Only struct/enum declarations move. |

## Constraints

1. **L1 MUST NOT import Foundation or platform modules** ([PRIM-FOUND-001]).
   Verified: no promoted type requires platform imports.

2. **L1 MUST be unconditionally cross-platform** ([PLAT-ARCH-008c]).
   Verified: Notification's `#if os(Linux)` is resolved by making the struct
   backend-agnostic. All other types are already unconditional.

3. **Re-export chain MUST preserve consumer imports** ([PLAT-ARCH-006]).
   L3 `Kernel Completion` re-exports the new L1 target. Consumer writes
   `import Kernel` unchanged.

4. **Event.Driver depends on Dictionary_Primitives** (for the registry).
   `Dictionary_Primitives` is L1 (`swift-dictionary-primitives`). The dependency
   is valid at L1.

5. **Submission.Flags constants are io_uring-shaped**.
   Resolved via [PLAT-ARCH-013] shell + values pattern: L1 shell, L3 constants.

## Comparison

| Criterion | A: Status Quo | B: Full Promotion | C: Partial |
|-----------|--------------|-------------------|-----------|
| Backend agnosticism | Convention only | **Compile-time enforced** | Type-level only |
| [PLAT-ARCH-012] | Partial | **Full** | Partial |
| Dependency validity | N/A | **Verified** | Trivial |
| L3 thinness | Thick | **Maximally thin** | Moderate |
| Consumer impact | None | None | None |
| Migration cost | None | Medium | Low |

## Recommendation

**Option B: Full Resource Promotion.**

The architectural insight: these are **our types, our abstractions, our design**.
The Driver is not "composed behavior" in the [PLAT-ARCH-012] sense — it's a
witness pattern we invented. The backends compose the closures; the witness shape
is vocabulary. The Submission struct describes I/O operations in our terminology;
the backends translate to platform opcodes.

The forcing function is the decisive advantage: if `Submission.Length` can't compile
at L1 without `import Linux_Kernel_IO_Uring_Standard`, then it doesn't belong at L1,
and we'll discover the bias at build time. If it CAN compile — which it can — then
it's genuinely cross-platform and should be at L1.

### Post-promotion L3 structure

**Kernel Event** (L3, swift-kernel):
```
Kernel.Event.Source+Kqueue.swift    226 LOC  — Darwin factory
Kernel.Event.Source+Epoll.swift     251 LOC  — Linux factory
exports.swift                                — re-exports L1
```

**Kernel Completion** (L3, swift-kernel):
```
Kernel.Completion+IOUring.swift     348 LOC  — Linux factory
Kernel.Completion.Submission.Flags+Values.swift  — flag constants
exports.swift                                — re-exports L1
```

### Post-promotion L1 structure

**Kernel Event Primitives** (L1, expanded):
```
Existing:  Event, Event.ID, Interest, Options, exports     5 files
Added:     Event.Source, Event.Driver, Registration, Error  4 files
Total:     9 files
```

**Kernel Completion Primitives** (L1, new):
```
Completion, Driver, Notification, Capabilities              4 files
Submission, Opcode, Address, Length, Offset, Flags, Count   7 files
Token, Event, Event.Result, Event.Flags, Event.Count        5 files
Error, Buffer, Buffer.Group                                 3 files
exports                                                     1 file
Total:     20 files
```

### Changes required at L1

| Type | Change for L1 |
|------|---------------|
| `Notification` | Remove `#if os(Linux)`. Store `Kernel.Descriptor` unconditionally. |
| `Submission.Length` | Remove io_uring SQE layout comments. Document as cross-platform. |
| `Submission.Offset` | Remove io_uring SQE layout comments. Document as cross-platform. |
| `Submission.Flags` | Remove constants (→ L3 extension). Keep empty OptionSet shell. |
| `Event.Result` | Change `package` to `@_spi(Syscall)` per L1 convention. |
| `Completion._overflowCount` | Move from resource to Driver. |

### Implementation sequencing

1. **Create L1 Kernel Completion Primitives** — all types from current L3
2. **Expand L1 Kernel Event Primitives** — add Source, Driver, Registration, Error from L3
3. **Thin L3 Kernel Completion** — remove promoted types, import L1, keep +IOUring + flag values
4. **Thin L3 Kernel Event** — remove promoted types, import L1, keep +Kqueue + +Epoll
5. **Verify** — `swift build` from swift-foundations, `swift test`

## Open Questions

**Q1: Event.Driver `Dictionary_Primitives` at L1**

Event.Driver's init uses `Dictionary_Primitives.Dictionary` for the registry. This
is already L1 (`swift-dictionary-primitives`). But `Kernel Event Primitives` doesn't
currently depend on it. Adding the dependency is valid per tier rules (both L1) but
widens the dependency graph.

Alternative: use a simpler data structure (flat array with ID lookup). The registry
is small (tens of entries). But the Dictionary is the proven implementation.

**Recommendation**: Add the dependency. It's valid, proven, and the alternative
saves nothing meaningful.

**Q2: Buffer.Group at L1**

`Buffer.Group` (kernel-managed buffer pools) is an io_uring concept with no IOCP
equivalent. Should it be L1?

Argument for: it's `Tagged<Buffer, UInt16>` — a pure vocabulary type with zero
platform imports. IOCP ignores it (Submission.bufferGroup is `.none`).

Argument against: the concept doesn't exist on IOCP. Having it at L1 implies
universality.

**Recommendation**: Keep at L1. It's a tagged integer — zero cost if unused. If a
future backend supports buffer pools, the vocabulary is ready. If not, `.none` is
the default.

**Q3: Should Submission.Flags constants stay at L3 or promote to L1?**

The flag values (`.bufferSelect`, `.linked`, `.drain`, `.fixedFile`) are OUR raw
values (1 << 0, 1 << 1, etc.), not platform values. The Driver translates them.

Argument for L1: they're our vocabulary, not platform-specific.

Argument against L1: all four currently only make sense for io_uring. IOCP backends
ignore them. Having them at L1 suggests cross-platform availability.

**Recommendation**: L1 shell, L3 constants. Per [PLAT-ARCH-013]. If a flag later
proves cross-platform (e.g., `.linked` for IOCP chained operations), promote it.
The shell + values pattern makes promotion additive.

## References

- `swift-kernel/Research/completion-architecture-audit.md` — vestigial L1 finding, per-type IOCP test
- `swift-kernel/Research/unified-completion-api-design.md` — original L1/L3 design
- `swift-kernel/Research/kernel-completion-driver-redesign.md` — converged Driver design
- `swift-kernel/Research/kernel-event-driver-zero-allocation-redesign.md` — Event Driver design
- [PLAT-ARCH-012] — vocabulary / spec / composition principle
- [PLAT-ARCH-013] — shell + values OptionSet pattern
- [PLAT-ARCH-008c] — platform extensions over primitive conditionals
