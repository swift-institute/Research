---
date: 2026-04-26
session_objective: Audit swift-observation-primitives + swift-observations for ecosystem-primitive adoption opportunities, replace hand-rolled patterns where existing primitives fit, and apply the "should this primitive even exist" test to incumbent packages.
packages:
  - swift-foundations/swift-observations
  - swift-primitives/swift-observation-primitives
  - swift-primitives/swift-ownership-primitives
  - swift-primitives/swift-lifetime-primitives
  - swift-iso/swift-iso-9945
  - swift-microsoft/swift-windows-standard
  - swift-foundations/swift-kernel
  - swift-primitives/swift-kernel-primitives
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: modularization
    description: "[MOD-RENT] Three-Criteria Primitive-Package Rent Test — capability + consumer + theoretical-content gate; codifies the swift-lifetime-primitives deletion as worked example. Anti-pattern: defending packages on conceptual-purity grounds."
  - type: skill_update
    target: platform
    description: "[PLAT-ARCH-008f] worked example added — Local → Key / Index L2 spec-literal rename (solution (a)) at swift-iso-9945 and swift-windows-standard freeing L3 namespace for generic Kernel.Thread.Local<Payload>. Second application of the rule."
  - type: package_insight
    target: swift-windows-standard/Research/_Package-Insights.md
    description: "Created insights doc documenting that Kernel.Thread.Local<Payload> lacks per-thread cleanup on Windows because TlsAlloc has no destructor mechanism. Future work: FlsAlloc / FlsSetCallback wiring for symmetric per-thread cleanup."
---

# Ecosystem audit, lifetime-primitives deletion, and typed Kernel.Thread.Local promotion

This reflection captures the second arc of the 2026-04-26 session.
The first arc (`@Observable` macro construction) is covered in the
sibling reflection
`2026-04-26-observable-macro-twin-design-and-validation-gap.md`. After
that arc closed, the user redirected: *"What can we learn from these
two packages, and what do they hand-roll that the ecosystem already
provides?"* The arc that followed surfaced four distinct architectural
lessons.

## What Happened

**Audit**: enumerated every hand-rolled construct in
`swift-observation-primitives` (L1) and `swift-observations` (L3),
mapped each to potential ecosystem primitives, and classified into
swap candidates / genuine gaps / leave-as-is. The Explore agent's
catalog of `swift-tagged-primitives`, `swift-reference-primitives`,
`swift-ownership-primitives`, `swift-lifetime-primitives`,
`swift-async-primitives`, `swift-witness-primitives`, and
`swift-kernel`'s test-support modules was the input.

**Three confirmed swaps landed**:

1. `Observation.Registrar.Extent` (`final class { let state: Mutex<State> }`,
   `@unchecked Sendable`) → `Ownership.Shared<Mutex<State>>`.
   Deleted the bespoke Extent class; dropped the `@unchecked Sendable`
   workaround (`Ownership.Shared` is *checked* Sendable when
   `Value: Sendable`).
2. `Observation.Tracking._OneShot` (Mutex&lt;Bool&gt; + Mutex&lt;list&gt; +
   callback class) → `Ownership.Latch<@Sendable () -> Void>` with
   `takeIfPresent()` for first-wins semantics. ~50 lines deleted.
3. Test `Box<T>` (Mutex-based holder I'd added during the macro arc)
   → `LockedBox<T>` from `Kernel Test Support`. Hand-rolled holder
   deleted.

**One swap deferred**: `Subscription.Token` → `Lifetime.Disposable`
conformance. We landed it (S3a relaxed the protocol to admit
`~Copyable` conformers; S3b added the conformance). Then the user
asked: *do these things even pay rent as primitives?*

That question forced a deeper audit. Result: `swift-lifetime-primitives`
failed the three-criteria test (capability beyond language + existing
primitives, ≥1 real consumer, theoretical content per
`[MOD-DOMAIN]`):

- `Lifetime.Lease<Value>` is structurally identical to
  `Ownership.Unique<Value>` (both `~Copyable`, both
  `UnsafeMutablePointer<Value>` storage, same access pattern; Lease
  has weaker semantics — runtime `_released` trap vs Unique's
  compile-time linear enforcement).
- `Lifetime.Disposable` adds nothing the language doesn't already
  provide — `consuming` methods + `~Copyable` deinit cover the
  pattern; the protocol is symbolic, with no real consumer needing
  generic-over-disposable dispatch.
- `Lifetime.Scoped<Value>` is `defer` in struct form. Same deletion
  argument.

S3 was reverted. The whole `swift-lifetime-primitives` package was
deleted from the workspace; commented-out lifetime-primitives deps
were stripped from five other primitive packages
(`swift-continuation-primitives`, `swift-handle-primitives`,
`swift-cache-primitives`, `swift-state-primitives`,
`swift-loader-primitives`) that had never actually used the package.

**`_FrameLocal` revisited**: the macro arc had created
`Observation.Tracking._FrameLocal` as a private typed wrapper around
the untyped `Kernel.Thread.Local`, encapsulating the
`Unmanaged.passRetained` / `release` dance. The user asked whether it
should be replaceable by ecosystem functionality.

First attempt failed: declaring a generic `Kernel.Thread.Local<T>` at
L3 collided with the untyped L2 `Local` extension (the `ISO_9945.Kernel`
and `Kernel` typealiases unify into the same namespace, so both
declarations end up extending the same `Kernel.Thread`).

User direction: don't rename via `.Raw`; "improve the current
`Kernel.Thread.Local`" in place. The platform skill prescribed the
exact answer: `[PLAT-ARCH-008f]` solution (a) — rename L2 to its
spec-literal form to free the L3 namespace.

**Landed**:
- `ISO_9945.Kernel.Thread.Local` → `ISO_9945.Kernel.Thread.Key`
  (mirrors POSIX `pthread_key_t`).
- `Windows.Kernel.Thread.Local` → `Windows.Kernel.Thread.Index`
  (mirrors Win32 "TLS index" / `DWORD`).
- L3 `Kernel.Thread.Local` typealias → generic class
  `Kernel.Thread.Local<Payload: AnyObject>` wrapping the platform
  `Key` or `Index` via `#if`.
- `_FrameLocal` deleted; observations consumer uses
  `Kernel.Thread.Local<Frame>` directly. Zero `unsafe` markers in
  `Observation.Tracking.Current.swift`.

**POSIX destructor support added** (per the user's follow-up): L2
`ISO_9945.Kernel.Thread.Key` gained `init(destructor:)` accepting a
`@convention(c) (UnsafeMutableRawPointer) -> Void` function pointer;
L3 `Kernel.Thread.Local<Payload>` wires a type-erased
`Unmanaged<AnyObject>.release()` destructor on POSIX so the kernel
auto-releases retained payloads on thread exit. Windows path leaves
the slot uncleaned (TlsAlloc has no destructor; `FlsAlloc` /
`FlsSetCallback` is the future-work hook).

**Cleanup**: the `MemberMacro` deprecation warning from the macro arc
(`expansion(of:providingMembersOf:in:)` — deprecated default
implementation) was fixed by implementing the newer
`conformingTo: [TypeSyntax]` signature.

Final state: 18 tests in 8 suites green across both packages. Zero
`import Foundation` / `import XCTest` anywhere in `Sources/` or
`Tests/`. Zero `unsafe` markers in the observations consumer.

## What Worked and What Didn't

**Worked**:

- **The "is it expressible by what's there" rule, applied
  iteratively.** First pass found four swap candidates; second pass
  (after user pushback) found that two of them depended on a package
  that itself failed the test. Each iteration added rigor without
  adding speculation.
- **The platform skill had the answer pre-codified.** When the L3
  generic class collision surfaced, `[PLAT-ARCH-008f]` enumerated
  exactly four solution families with selection criteria. Solution
  (a) (L2 spec-literal rename) was unambiguously correct here. The
  rule was authored from a previous session's pattern; this session
  consumed that codification. Strong evidence that skill rules pay
  rent.
- **POSIX spec-mirroring as the rename target.** Rather than picking a
  generic name (`Slot`, `Storage`), `[API-NAME-003]` directed us to
  the spec-literal form: POSIX uses "key" (verified against IEEE
  1003.1), Windows uses "TLS index" (verified against MSDN). The
  resulting names diverge per platform — that's *correct*, because
  the underlying abstractions genuinely differ (POSIX has an opaque
  key; Windows has a numeric index into a per-process table).

**Didn't work / had to recover**:

- **Initial Lifetime.Disposable defense.** I argued for keeping
  Disposable + Scoped in `lifetime-primitives` on conceptual-purity
  grounds ("ownership = who, lifetime = when"). User pushed back:
  *"Are these even proper primitives?"* The honest answer was no
  (per `[MOD-DOMAIN]`). I'd been defending packages on the wrong
  axis — vocabulary cleanliness instead of consumer rent.
- **The L3 generic-class collision attempt.** Spent two iterations
  trying to declare `Kernel.Thread.Local<T>` at L3 alongside the
  untyped L2 `Local` before realizing the typealias chain merges
  the namespaces. The platform skill's `[PLAT-ARCH-008f]` rule was
  available the whole time; I rediscovered the constraint
  empirically before consulting the rule. Lesson: when a structural
  problem appears at a layer boundary, check the platform skill
  first.
- **The Token: Lifetime.Disposable round-trip.** Landed S3a + S3b in
  the working tree (uncommitted), then reverted both when the
  package failed the rent test. Net work: cleanup + a clearer
  understanding of what the protocol would need to be useful (a
  real generic-API consumer, which doesn't exist today).
- **Windows code untested.** No Windows host available; the
  `Windows.Kernel.Thread.Index` rename and the L3 destructor wiring
  on Windows were written blind. The L3 Windows path doesn't install
  a destructor (matches existing leak-on-thread-exit behavior), so
  the risk is low, but a Windows CI build is the only real
  verification.

## Patterns and Root Causes

**Pattern 1 — The three-criteria test for primitives.**
`[MOD-DOMAIN]` says targets must represent coherent semantic domains,
not "shared code, convenience, or helpers." But that rule, alone,
doesn't tell you when an existing target *fails* the criterion. This
session converged on a sharper, action-able test:

1. **Capability**: Does this primitive enable something the language
   + existing primitives don't already express?
2. **Consumer**: Is there at least one real consumer today? (Not
   "may be useful later.")
3. **Theoretical content** per `[MOD-DOMAIN]`: Is this a *concept*
   with a definition / law / spec / structural invariant — or just
   code (a convenience wrapper, naming sugar, helper)?

If a thing fails any of the three, it shouldn't be added. If it's
already there and fails *all* three, it should be deleted. Five
packages had commented-out deps on the failing package — strong
evidence that the failure was visible to authors but no one had
applied the test to act on it. Codifying the test as a rule (e.g.
`[MOD-RENT]` in the modularization skill) would let future PRs hit
the gate at the right moment.

**Pattern 2 — `[PLAT-ARCH-008f]` solution (a) as worked example.**
The rule was authored from a previous session's L3 unifier collision;
this session is the first re-application. Specifically: when an L3
unifier wants the canonical name and the L2 raw class has the same
name (because of namespace typealias chains), and L2's name is
*informal* (chosen for L3 convenience, not spec-mirroring), solution
(a) renames L2 to spec-literal. The pattern preserves the canonical
L3 name without sub-namespacing or visibility tricks.

This concrete instance — `Local` (informal) → `Key` (POSIX spec) /
`Index` (Win32 spec) — is a clean exemplar to cite from any future
similar collision. The Research note value here is "see this
session's commit chain across `swift-iso-9945`, `swift-windows-standard`,
`swift-kernel-primitives`, and `swift-kernel`."

**Pattern 3 — Conceptual purity vs consumer rent.** I defended
`Lifetime.Disposable` and `Lifetime.Scoped` on conceptual grounds
("lifetime ≠ ownership"). The defense was *true* but the wrong
axis. Whether two concepts are distinct is upstream of whether each
gets its own primitive package; the primary question is whether the
package earns rent (real consumers, real capability). The user's
challenge — *"are those even proper primitives?"* — cut through to
the right axis. **Recurring failure mode**: justifying existing
infrastructure on conceptual cleanliness before checking whether it
has consumers and unique capability. Apply the rent test first;
conceptual analysis is the tiebreaker when both pass.

**Pattern 4 — Spec-literal divergence is correct, not a bug.** POSIX
"key" and Win32 "index" are different words for related but distinct
abstractions (POSIX's `pthread_key_t` is opaque; Win32's `DWORD` is
explicitly a numeric index). When platforms diverge in
spec-vocabulary, `[API-NAME-003]` strict spec-mirroring at L2 produces
diverging names — and that's correct, because the L2 layer
faithfully encodes what the platform *actually exposes*. The L3
unifier's job is to provide the cross-platform Swift name (`Local`);
the L2 layer's job is to be honest about each platform's terminology.

## Action Items

- [ ] **[skill]** modularization: Codify the three-criteria primitive
  test as `[MOD-RENT]` (or similar). Statement: "A primitive
  package's existence MUST satisfy three criteria — capability
  beyond language + existing primitives, ≥1 real consumer in the
  ecosystem, and theoretical content per `[MOD-DOMAIN]`. A package
  failing any criterion SHOULD be candidates for absorption,
  deprecation, or deletion." Cite this session's
  `swift-lifetime-primitives` deletion as the worked example.
- [ ] **[skill]** platform: Add a worked example to `[PLAT-ARCH-008f]`
  pointing to the `Local` → `Key` / `Index` rename in this session's
  commit chain. The rule existed; this session is the second
  application (first was the rule's provenance commit chain). Two
  applications → the example is reusable for a future third
  occurrence.
- [ ] **[package]** swift-windows-standard: Document that
  `Kernel.Thread.Local<Payload>` does not install per-thread cleanup
  on Windows because `TlsAlloc` lacks a destructor mechanism. Future
  work: wire `FlsAlloc` / `FlsSetCallback` for symmetric per-thread
  cleanup. Real consumer trigger: any short-lived-thread use of
  `Kernel.Thread.Local` on Windows surfaces the leak.
