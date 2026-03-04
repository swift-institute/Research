# Next Steps: Witnesses Ecosystem Adoption

<!--
---
version: 2.0.0
last_updated: 2026-03-04
status: COMPLETE
source: adoption-implementation-review.md, witnesses-ecosystem-adoption-audit.md
verified_by: source-level audit 2026-03-04
---
-->

## Status

**All phases COMPLETE.** Verified against source on 2026-03-04.

**Infrastructure (prior session):** 5 macro improvements (let closures, _ prefix stripping, firstName labels, skip-init, non-closure properties), task-local unification into L1 dictionary, Witness.Key refined from Dependency.Key, L3 mode propagation to L1 isTestContext, L1-key subscript on Witness.Context.

**Conformances (verified in source):** All `Witness.Protocol` conformances and `Witness.Key` registrations are present. The research doc v3.0 was correct — the implementation review's concern about missing git commits was a false alarm; the conformances exist in the working tree.

---

## Phase A — Witness.Protocol Conformances (Primitives) ✓

| Package | Type | File | Conformance |
|---------|------|------|-------------|
| swift-optic-primitives | `Optic.Lens` | `Optic.Lens.swift:41` | `: Sendable, Witness.Protocol` |
| swift-optic-primitives | `Optic.Prism` | `Optic.Prism.swift:41` | `: Sendable, Witness.Protocol` |
| swift-clock-primitives | `Clock.Any` | `Clock.Any.swift:28` | `: _Concurrency.Clock, @unchecked Sendable, Witness.Protocol` |
| swift-predicate-primitives | `Predicate` | `Predicate.swift:29` | `: @unchecked Sendable, Witness.Protocol` |
| swift-binary-parser-primitives | `Binary.Coder` | `Binary.Coder.swift:43` | `: Sendable, Witness.Protocol` |
| swift-test-primitives | `Test.Snapshot.Strategy` | `Test.Snapshot.Strategy.swift:63` | `: Sendable, Witness.Protocol` |
| swift-test-primitives | `Test.Snapshot.Diffing` | `Test.Snapshot.Diffing.swift:40` | `: Sendable, Witness.Protocol` |

All have `public import Witness_Primitives` and Package.swift dependencies.

**Deferred:** `Parser.Machine.Compile.Witness` — pending Sendable audit.

## Phase B — Witness.Protocol Conformances (Standards/Foundations) ✓

| Package | Type | File | Conformance |
|---------|------|------|-------------|
| swift-iso-32000 | `ISO_32000.StreamCompression` | `ISO_32000.Writer.swift:943` | `: Sendable, Witness.Protocol` |
| swift-tests | `Test.Trait.ScopeProvider` | `Test.Trait.ScopeProvider.swift:16` | `: Sendable, Witness.Protocol` |
| swift-effects | `Effect.Yield.Handler` | `Effect.Yield.swift:24` | `: __EffectHandler, Sendable, Witness.Protocol` |
| swift-effects | `Effect.Exit.Handler` | `Effect.Exit.swift:32` | `: __EffectHandler, Sendable, Witness.Protocol` |

All have `public import Witness_Primitives` and Package.swift dependencies.

## Phase C — IO Driver Witness.Protocol + Witness.Key ✓

| Driver | Witness.Protocol | Witness.Key | Key Design |
|--------|-----------------|-------------|------------|
| `IO.Event.Driver` | `IO.Event.Driver.swift:40` | `IO.Event.Driver+Witness.Key.swift` | Direct conformance on Driver (not nested enum) |
| `IO.Completion.Driver` | `IO.Completion.Driver.swift:43` | `IO.Completion.Driver+Witness.Key.swift` | Direct conformance on Driver (not nested enum) |

**Design note:** Both drivers conform to `Witness.Key` directly on the `Driver` type itself, rather than through a nested `Key` enum as originally proposed. This is cleaner — the driver *is* its own key. Both import `Witnesses` (L3) for `Witness.Key` support.

**Platform dispatch:**
- `IO.Event.Driver`: Darwin → `.kqueue()`, Linux → `.epoll()`
- `IO.Completion.Driver`: Linux → `.iouring()`, Windows → `.iocp()`
- Both provide `testValue` with fatalError stubs (unimplemented in test context)

**`@Witness` macro:** Not applied to IO drivers. They use `borrowing`/`consuming` parameter conventions and `~Copyable` handles. Manual conformance is correct.

---

## Items NOT in Scope

| Item | Status |
|------|--------|
| `@Witness` macro for algebra types (14 types) | LOW — @frozen, performance-critical, unlabeled closures. No action. |
| `@Witness` macro for IO drivers | Future — manual forwarding already exists, macro adds incremental value only. |
| `Parser.Machine.Compile.Witness` | DEFERRED — pending Sendable audit. |
