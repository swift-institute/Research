# ~Escapable: Blocked Indefinitely

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 1
scope: package
trigger: cohort ~Escapable adoption push 2026-05-09; siblings swift-pair-primitives + swift-either-primitives extended to admit ~Escapable arms; Product cannot follow.
related:
  - swift-institute/Research/escapable-support-pair-either-product.md
  - swift-institute/Research/nonescapable-ecosystem-state.md
  - swift-pair-primitives/Research/escapable-arm-support.md
  - swift-either-primitives/Research/escapable-arm-support.md
empirical_validation: Experiments/escapable-blocked/
---
-->

## Question

Can Product extend its functor surface (`map`, `fold`, `append`, `prepend`, `zip`, `swapped`) to admit `~Escapable` arms — matching the cohort siblings Pair and Either?

## Verdict

**No.** Blocked by Swift parameter-pack syntax limitations. Defer indefinitely.

## Empirical evidence

`Experiments/escapable-blocked/Sources/EscapableBlocked/EscapableBlocked.swift` records the failure modes verified on Swift 6.3.1 + Swift 6.4-dev nightly 2026-05-07-a.

| Attempt | Result |
|---|---|
| Type-level `Product<each Element: ~Copyable>` | BLOCKED — pack syntax doesn't admit suppressions on `each` requirements |
| Type-level `Product<each Element: ~Escapable>` | BLOCKED — same root cause |
| Free function `swapped<First, Second>(_: consuming Product<First, Second>)` with `First: ~Copyable & ~Escapable` | BLOCKED — Product itself requires First, Second to be Copyable + Escapable; the function-level relaxation is rejected at the call site |
| Existing API on Copyable + Escapable arms | CONFIRMED |

Product remains **Copyable + Escapable on all arms**. The institute conformances (`Product+Equation.Protocol.swift` etc.) use `where repeat each Element: Equation.Protocol` — admitting ~Escapable conformers requires the same upstream compiler progress.

## Tracking

Revisit when ALL of the following land in Swift:

1. `each T: ~Copyable` admitted by parameter-pack syntax
2. `each T: ~Escapable` admitted by parameter-pack syntax
3. Lifetime-annotation propagation through pack-expanded expressions

None have a public Swift Evolution proposal as of 2026-05-09.

## Upstream-filed compiler bugs (2026-05-09)

The cohort's parameter-pack lowering work surfaced two related compiler-pass
assertion failures on Swift 6.4-dev nightly 2026-05-07-a:

- [swiftlang/swift#88985](https://github.com/swiftlang/swift/issues/88985) —
  pack-expand of a member-access on a `consuming` parameter
  (`each product.values`). CSE-pass assertion in release builds.
- [swiftlang/swift#88987](https://github.com/swiftlang/swift/issues/88987) —
  pack-expand of `each values` on `consuming self` (the cohort's *workaround*
  for #88985). Same assertion in CSE on minimal repro; SILCombine on the
  production `map transforms every component preserving arity` test.
  Likely the same underlying lowering bug as #88985.

The cohort's CI surfaced #88987 as the Linux Ubuntu Swift 6.4-dev nightly
Release-mode failure on every push since the consolidation (CI Run ID
`25600877340` on the original Initial publication, persisting through later
amendments). Track until resolution; the failure is non-gating in the cohort's
CI (Ubuntu nightly Release is advisory).

## Cohort context

| Package | ~Escapable adoption today |
|---|---|
| swift-pair-primitives | Type-level upgrade + most functor methods (see `Research/escapable-arm-support.md`) |
| swift-either-primitives | swapped, value(of:), un-transformed-arm map (see `Research/escapable-arm-support.md`) |
| **swift-product-primitives** | **Blocked** — this note |

The cohort asymmetry is honest about Swift compiler current state. When pack syntax catches up, Product unblocks mechanically; until then, consumers needing arity-2 ~Escapable products use `Pair`.

## Cross-references

- Empirical reproduction: `Experiments/escapable-blocked/`
- Ecosystem-wide research: `swift-institute/Research/escapable-support-pair-either-product.md`
- Sibling-package research: `swift-pair-primitives/Research/escapable-arm-support.md`, `swift-either-primitives/Research/escapable-arm-support.md`
