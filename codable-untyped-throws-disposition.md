# Codable + Untyped Throws — Cohort Disposition

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 2
scope: cross-package
applies_to: [swift-pair-primitives, swift-either-primitives, swift-product-primitives]
trigger: forums-review of swift-product-primitives flagged Codable's untyped throws as the #2 angle (error-handling, score 48.16) and named it "the one substantive design decision that may genuinely shift in review" (forums-review-objections-2026-05-09.md). Pre-flip cohort consolidation accepted the [API-ERR-006] violation rather than dropping Codable. The audit (Audits/audit.md CS-2) self-documents the violation; this note formalises the workspace-wide disposition.
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a
preceded_by:
  - escapable-support-pair-either-product.md (DECISION, 2026-05-09)
  - frozen-noncopyable-deinit-tradeoff.md (DECISION, 2026-05-09) — sibling-axis disposition for the same cohort
relates_to:
  - swift-product-primitives/Audits/forums-review/forums-review-objections-2026-05-09.md (item 2, error-handling)
  - swift-product-primitives/Audits/audit.md (CS-2 self-documenting the violation)
---
-->

## Context

The cohort packages each carry a conditional `Codable` conformance:

```
swift-either-primitives/Sources/Either Primitives/Either.swift
    #if !hasFeature(Embedded)
        extension Either: Codable where Left: Codable, Right: Codable {}
    #endif

swift-pair-primitives/Sources/Pair Primitives/Pair.swift
    #if !hasFeature(Embedded)
        extension Pair: Codable where First: Codable, Second: Codable {}
    #endif

swift-product-primitives/Sources/Product Primitives/Product+Encodable.swift:10
    public func encode(to encoder: any Encoder) throws(any Swift.Error) { ... }

swift-product-primitives/Sources/Product Primitives/Product+Decodable.swift:10
    public init(from decoder: any Decoder) throws(any Swift.Error) { ... }
```

Either and Pair use the compiler-synthesized Codable conformance; Product
ships explicit `init(from:)` / `encode(to:)` because parameter packs require
manual encoding. The synthesized form looks "clean" because it doesn't write
the throws clause locally, but it inherits the same untyped-throws shape from
the `Codable` / `Encodable` / `Decodable` protocol contract: `throws` (which
is `throws(any Error)` under typed-throws-by-default).

The institute's [API-ERR-006] forbids untyped throws on public API surface
(`/Users/coen/Developer/swift-foundations/swift-foundations/Skills/code-surface/SKILL.md`):

> All throwing functions MUST use typed throws. Untyped throws (or
> existential `throws(any Error)`) on public API are forbidden.

This is a real conflict between two ecosystem commitments — typed throws
on every public API vs Foundation-Codable interoperability — and it cannot be
resolved without either (a) breaking the institute's own [API-ERR-006],
(b) dropping Codable from the cohort, or (c) adding a `Foundation Integration`
subtarget per the institute's split convention.

The 2026-05-09 cohort consolidation chose (a) and shipped the Codable
conformances with the violation deferred. The user has since excluded
Foundation Integration entirely from the workspace
(per `feedback_improve_ecosystem_over_foundation_or_thirdparty` and
`feedback_ecosystem_no_foundation_in_main_targets`). Option (c) is therefore
foreclosed; the disposition is permanent rather than awaiting a Foundation
Integration subtarget that will never ship.

## Question

Given the workspace's exclusion of Foundation Integration, what is the
formal disposition of the cohort's Codable conformances under [API-ERR-006]?
What does the cohort document, and how does future evolution of stdlib
typed-throws Codable affect the disposition?

## Analysis

### Why [API-ERR-006] applies and the violation is real

The institute defines `Codable` consumption as crossing a public API
boundary. The protocol's requirements (`encode(to:) throws` and
`init(from:) throws`) propagate untyped throws into every conformer's
public surface. For a primitives-tier package that advertises typed throws
as a value-add, this is exactly the surface the rule guards. The violation
is not a notational artifact of Product's manual implementation — Either
and Pair carry it identically through the synthesized form.

### Why dropping Codable is the wrong move

The pre-flip cohort consolidation considered dropping Codable entirely
(per `swift-product-primitives/Audits/audit.md` CS-2: "the only fully
compliant path is dropping Codable conformance"). It was rejected because:

1. **Codable is the de facto serialization protocol** in the broader Swift
   ecosystem. Removing it puts an unjustified barrier in front of
   consumers who serialize / deserialize ecosystem types.

2. **Synthesized Codable is the only general-purpose serialization**
   available without dependencies. The cohort cannot ship a typed-throws
   alternative without either depending on a typed-throws encoder
   protocol that doesn't exist or hand-rolling one per package.

3. **The cohort's role as movement vehicles** (per
   `frozen-noncopyable-deinit-tradeoff.md`) is consistent with carrying
   serialized data as one of their standard uses. A `Pair<UInt32,
   UInt32>` round-tripped through JSON is a natural use case.

The cost of dropping Codable (loss of ecosystem compatibility) outweighs
the cost of accepting the [API-ERR-006] violation (one rule deferred for a
narrow, well-documented reason).

### Why a Foundation Integration subtarget would have been better — but is excluded

The institute's standard pattern for Foundation-coupled API surface is to
move it to a `* Foundation Integration` subtarget per
`feedback_no_unsafe_api_surface.md` precedent. The cohort does NOT take this
path:

| Path | Cost | Status |
|---|---|---|
| Drop Codable from main target; provide it in a `* Foundation Integration` subtarget | Per-package subtarget surface; consumers explicit-import for Codable | **Foreclosed** — user has excluded Foundation Integration ecosystem-wide |
| Drop Codable entirely | Lose stdlib synthesis, ecosystem compatibility | Rejected per above |
| Ship Codable in main target, accept [API-ERR-006] violation | One rule deferred per cohort package | **Accepted disposition** |

The decision is forced: with Foundation Integration off the table, accepting
the violation is the only path that preserves Codable.

### Why the violation is bounded

The violation is structurally narrow:

- It is confined to the `Codable` conformance surface (one protocol's three
  requirements).
- The conformance is `#if !hasFeature(Embedded)`-gated for Either and Pair;
  the Embedded build does not surface the violation.
- Product's manual implementation makes the violation explicit (the
  `throws(any Swift.Error)` annotation is visible in the source); Either
  and Pair's synthesized form makes it implicit but discoverable via
  documentation.

The violation does not propagate. A consumer who wraps the cohort's Codable
methods in their own typed-throws-bearing API can re-typify locally; the
cohort itself is the boundary at which untyped throws stop.

### Future direction: stdlib typed-throws Codable

If a future Swift Evolution proposal extends `Codable` (or a sibling
protocol) with typed throws — analogous to SE-0499's extension of
`Equatable` to `~Copyable` — the cohort's disposition can revisit:

| Future Swift state | Cohort action |
|---|---|
| `Codable` requirements upgrade to `throws(some Error)` | Conformances migrate naturally; synthesized form follows. [API-ERR-006] violation closes. |
| New typed-throws-Codable sibling protocol ships | Cohort conforms to both (the existing untyped one for compatibility; the new typed one for [API-ERR-006] compliance). |
| Neither lands | Disposition holds; violation remains accepted. |

The disposition is not a permanent rule waiver — it is an accepted-trade-off
contingent on the absence of a typed-throws alternative.

### Asymmetry within the cohort

Product's manual implementation is the most-flagged of the three (per
`forums-review-objections-2026-05-09.md` item 2 — "the one substantive
design decision that may genuinely shift in review"). Either and Pair's
synthesized form is identical in [API-ERR-006] terms but is less
syntactically conspicuous, so reviewer attention falls hardest on Product.

The cohort response is uniform: the same disposition applies to all three.
Either and Pair do NOT enjoy a different rule because their violation
is implicit; their conformance shape carries the same contract.

## Outcome

**Status**: DECISION

**The [API-ERR-006] violation is accepted across the cohort.** Codable
conformance remains in the main target of all three packages. Foundation
Integration relocation is foreclosed by the user's ecosystem-wide exclusion
of Foundation Integration. Dropping Codable was considered and rejected.

**Documentation actions (for Item C of the 2026-05-09 punch list)**:

1. **Each package's README** MUST carry a "Codable conformance and typed
   throws" sub-section under the protocol-conformance discussion. The
   subsection states:
   - the conformance exists, conditional on `Codable` constraints
   - the protocol's requirements use untyped throws
   - this is an [API-ERR-006] violation accepted as a trade-off
   - the path that would resolve it (typed-throws Codable in stdlib) is
     not yet available; this disposition is contingent

2. **Each package's DocC catalog** SHOULD reference this research note for
   the rationale; the README pointer above is the consumer-facing summary.

3. **`swift-product-primitives/Audits/audit.md` CS-2** SHOULD be amended to
   cite this disposition note as the formal accept-and-defer record (the
   audit currently says "deferred"; the disposition makes the deferral
   permanent under stated conditions).

**No code changes required.** The shipped Codable conformances are correct
under this disposition. Any future code change to these conformances (e.g.,
to add error wrapping, to gate on a future stdlib feature) MUST cite this
note and the disposition's contingency conditions.

## References

- [SE-0413 — Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md) — typed-throws semantics
- [SE-0499 — Conformance to `Swift.Equatable` of `~Copyable` types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-equatable-noncopyable.md) — pattern of stdlib-protocol upgrades that resolve cohort `[API-ERR-006]`-style violations
- `swift-product-primitives/Audits/forums-review/forums-review-objections-2026-05-09.md` (item 2, error-handling, score 48.16) — origin of the flag
- `swift-product-primitives/Audits/audit.md` (CS-2) — self-documenting audit record of the violation
- Cohort current state:
  - `swift-either-primitives/Sources/Either Primitives/Either.swift` — `extension Either: Codable where Left: Codable, Right: Codable {}` (synthesized)
  - `swift-pair-primitives/Sources/Pair Primitives/Pair.swift` — `extension Pair: Codable where First: Codable, Second: Codable {}` (synthesized)
  - `swift-product-primitives/Sources/Product Primitives/Product+Encodable.swift:10` — manual `throws(any Swift.Error)`
  - `swift-product-primitives/Sources/Product Primitives/Product+Decodable.swift:10` — manual `throws(any Swift.Error)`
- Memory entries:
  - `feedback_improve_ecosystem_over_foundation_or_thirdparty` — Foundation-fallback foreclosed
  - `feedback_ecosystem_no_foundation_in_main_targets` — Foundation Integration subtarget foreclosed
- `swift-institute/Research/frozen-noncopyable-deinit-tradeoff.md` (DECISION, 2026-05-09) — sibling-axis disposition note from the same session
