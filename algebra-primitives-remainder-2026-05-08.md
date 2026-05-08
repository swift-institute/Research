# Algebra-Primitives Remainder Split

<!--
---
version: 1.0.0
last_updated: 2026-05-08
status: DECISION
scope: cross-package
tier: 1
audience: orchestrator (algebra-primitives scope finalization)
predecessor: launch-flow-assessment-2026-05-08.md (DECISION v1.1.0); array-bounded-index-revisit-2026-05-08.md §"Bit-Field Witness Home"
---
-->

## TL;DR

After the Pair / Product / Either extraction (commit `2f21a8c` on swift-algebra-primitives + 14 consumer rewires), `swift-algebra-primitives` was left with three concerns mashed together: the algebra namespace + `Algebra.Iso` (genuinely algebraic), nine algebra-flavored small enums (mixed: five algebra-internal carriers; four finite-domain qualifiers), and a `Bool+XOR` operator extension. This doc records the layering decisions that finalize the package's scope:

- **`swift-algebra-primitives` keeps** the `Algebra` namespace, `Algebra.Iso`, and the five algebra-internal carriers (`Sign`, `Parity`, `Polarity`, `Monotonicity`, `Ternary`).
- **`Bound`, `Boundary`, `Endpoint`, `Gradient` move to `swift-finite-primitives`** — they are finite-domain qualifiers; the carrier-home principle from `array-bounded-index-revisit-2026-05-08.md` puts type declarations with their concrete `Finite.Enumerable` and `Algebra.Group` conformances, both of which already live in finite-primitives.
- **`Bool+XOR` moves to `swift-bit-primitives` (`Bit Boolean Primitives` target)** — the operator exists because Bool with XOR forms GF(2); GF(2) lives in bit-primitives via `Algebra.Field<Bit>`. There is no future-stdlib motivation for `^` on Bool (`a != b` covers it), so `swift-standard-library-extensions` is the wrong home.

The result is three coherent packages:

| Package | Spine after this dispatch |
|---|---|
| `swift-algebra-primitives` | Algebra namespace + isomorphism primitive + five algebra-internal carriers |
| `swift-finite-primitives` | Finite domain types (existing) + four finite-domain qualifiers (new home) + their conformances (existing) |
| `swift-bit-primitives` | Bit + GF(2) algebraic structure (existing) + Bool's GF(2) operator (new home) |

## Question — what stays in `swift-algebra-primitives`?

After the Pair / Product / Either extraction, `Sources/Algebra Primitives Core/` contained:

| File | Type | Algebra-flavored? |
|---|---|---|
| `Algebra.swift` | namespace | yes (it IS the namespace) |
| `Algebra.Iso.swift` | isomorphism primitive | yes |
| `Sign.swift` | trichotomy with multiplicative monoid (-1 / 0 / +1) | yes (algebra-internal carrier) |
| `Parity.swift` | even / odd; GF(2) representation | yes (algebra-internal carrier) |
| `Polarity.swift` | positive / negative | yes (algebra-internal carrier) |
| `Monotonicity.swift` | increasing / constant / decreasing | yes (algebra-internal carrier; trichotomy shape) |
| `Ternary.swift` | three-valued (true / false / undefined) | yes (algebra-internal carrier; trichotomy shape) |
| `Bound.swift` | lower / upper | **no** (finite-domain qualifier) |
| `Boundary.swift` | open / closed | **no** (finite-domain qualifier) |
| `Endpoint.swift` | inclusive / exclusive | **no** (finite-domain qualifier) |
| `Gradient.swift` | ascending / descending / level | **no** (finite-domain qualifier; trichotomy shape) |
| `Bool+XOR.swift` | `^` operator on Bool | **no** (algebraic operator on stdlib type) |

The package mixed three concerns: (1) algebra-namespace substrate, (2) algebra-internal carriers, (3) types whose primary use is finite-domain qualification, plus an orphaned operator. Concerns (1) and (2) are coherent; (3) and the operator belong elsewhere.

## Decision 1 — `Bound`, `Boundary`, `Endpoint`, `Gradient` → `swift-finite-primitives`

These four enums are FINITE-DOMAIN QUALIFIERS, not algebra-internal carriers. Evidence:

- Their primary public-API usage is as the `Element` of `Algebra.Group` conformances declared in `swift-finite-primitives/Sources/Finite Primitives/Algebra.Group+{Bound,Boundary,Endpoint,Gradient}.swift`.
- Each also carries a `Finite.Enumerable` conformance in `swift-finite-primitives/Sources/Finite Primitives/{Bound,Boundary,Endpoint,Gradient}+Finite.swift`.
- They have no algebra-internal use (algebra-X-primitives chain doesn't reference them; the algebra-flavored carriers Sign / Parity / Polarity / Monotonicity / Ternary do appear in algebra-X conformances, these four do not).

The carrier-home principle from `array-bounded-index-revisit-2026-05-08.md` §"Bit-Field Witness Home" surveyed 11 ecosystem witness placements and found **0/11** precedents for "concrete witness for non-algebra-internal carrier in the kind's package." Today, the type declarations sit in algebra-primitives (kind side) while the witnesses sit in finite-primitives (carrier side). That's split-ownership — the inverse of the surveyed pattern. Moving the type declarations to finite-primitives unifies ownership: type + Finite conformance + Algebra.Group conformance all co-locate.

`swift-finite-primitives` already depends on `swift-algebra-primitives` (for `Algebra.Group`), `swift-pair-primitives` (for the `Bound.Value<Payload> = Pair<Bound, Payload>` typealiases — added in commit `cdb3f88` during the prior dispatch), and the rest of its dep graph. The relocation adds no new deps; it removes a public-API surface from algebra-primitives.

## Decision 2 — `Bool+XOR` → `swift-bit-primitives` (`Bit Boolean Primitives` target)

Three plausible homes were considered:

| Home | Argument | Verdict |
|---|---|---|
| `swift-standard-library-extensions` | "It's a stdlib extension" | **REJECT.** SLE is reserved for stdlib *missing pieces* — methods / operators / conformances Apple could plausibly ship in a future Swift version. `^` on Bool is **not** a future-stdlib gap: `a != b` already covers the semantics, so stdlib has no incentive to add it. The actual reason `^` exists on Bool is the algebraic GF(2) framing, not a stdlib oversight. |
| `swift-algebra-primitives` (status quo) | "It's algebra-flavored" | **REJECT.** algebra-primitives' coherent spine post-this-dispatch is namespace + Iso + algebra-internal carriers. A Bool extension doesn't fit that spine; it's adding stdlib-type extension surface to a package that otherwise has none. |
| `swift-bit-primitives` (`Bit Boolean Primitives` target) | "GF(2) lives here; Bool ≡ Bit semantically; co-locating preserves the framing" | **ACCEPT.** |

The decision-clinching reason: `Bool+XOR` exists because `Bool` with `^` forms GF(2). The two-element field is already represented in this ecosystem as `Algebra.Field<Bit>` — bit-primitives owns that witness. A future maintainer reading `swift-bit-primitives/Sources/Bit Boolean Primitives/Bool+XOR.swift` sees the GF(2) framing in context. The same reader landing on `swift-standard-library-extensions/Sources/Standard Library Extensions/Bool+XOR.swift` would have no algebraic framing to ground the operator's existence — they'd see a one-line stdlib-gap-fill that doesn't match SLE's narrowed scope.

`Bit Boolean Primitives` target already houses `Bit Boolean Operations.swift`, `Bit Compound Operators.swift`, and `Bitwise Operators.swift` — operations that connect Bit and Boolean concepts. `Bool+XOR.swift` extends the same target with the inverse direction (a Boolean operator with Bit-shaped algebraic meaning).

## Decision 3 — algebra-internal carriers stay bundled

`Sign`, `Parity`, `Polarity`, `Monotonicity`, `Ternary` have genuinely algebraic semantics:

- `Parity` is the canonical GF(2) representation (Algebra.Field<Parity>).
- `Sign` carries the multiplicative trichotomy monoid {-1, 0, +1}.
- `Polarity` is two-valued (positive / negative), distinct from Parity but algebra-internal.
- `Monotonicity` and `Ternary` mirror the trichotomy shape with different semantic axes.

Per-type extraction would be over-fragmentation under `feedback_correctness_sole_driver_during_development` — there is no observed-drift problem (none of these types is mis-bundled in the way Pair / Product / Either were), and no upstream-prune motivation (their consumers all sit downstream of algebra-primitives anyway). The five types share a coherent role ("algebra-internal carriers used by the algebra-X-primitives chain for monoid / group / field witnesses") and bundle cleanly.

Alternative considered: extract as `swift-trichotomy-primitives` or `swift-algebra-carrier-primitives`. Rejected — the bundling is the right grain for these five enums, and the package's spine ("algebra namespace + isomorphism primitive + algebra-internal carriers") is a clear elevator pitch that this split realizes.

## Final shape

| Package | Tier | Carries | Notes |
|---|---|---|---|
| `swift-algebra-primitives` | 1 (post-Pair-rewire) | `Algebra` namespace, `Algebra.Iso`, `Sign`, `Parity`, `Polarity`, `Monotonicity`, `Ternary` | Spine: algebra namespace + isomorphism primitive + algebra-internal carriers |
| `swift-finite-primitives` | 6 (existing) | (existing) + `Bound`, `Boundary`, `Endpoint`, `Gradient` | Type declarations relocate to live with their existing Finite + Group conformances |
| `swift-bit-primitives` | 7 (existing) | (existing) + `Bool+XOR` in `Bit Boolean Primitives` target | GF(2) ecosystem home extends to cover Bool's algebraic operator |
| `swift-standard-library-extensions` | 0 (existing) | unchanged | Reserved for genuine stdlib-missing-piece extensions |

The `swift-standard-library-extensions` framing (per orchestrator clarification 2026-05-08) is now: methods / operators / conformances that *Swift stdlib could plausibly ship in a future version*. This narrows SLE from "any stdlib extension" to "only stdlib-shaped extensions where the stdlib gap is the motivation."

## Cascade plan

Three relocations + a downstream consumer rewire wave, in order:

1. **Wave A — finite-domain qualifiers.** Move the four type files from `swift-algebra-primitives/Sources/Algebra Primitives Core/` to `swift-finite-primitives/Sources/Finite Primitives Core/` (or the path matching that package's existing layout). Remove the `Algebra.Group+{Bound,Boundary,Endpoint,Gradient}.swift` placeholder gap by retaining the witnesses where they are; they now extend types declared in the same package. Verify finite-primitives main-target builds clean.
2. **Wave B — Bool+XOR.** Move `Bool+XOR.swift` from `swift-algebra-primitives/Sources/Algebra Primitives Core/` to `swift-bit-primitives/Sources/Bit Boolean Primitives/`. Verify bit-primitives main-target builds clean.
3. **Wave C — consumer rewiring per [HANDOFF-035] cascade-termination.** Any consumer currently importing `Algebra_Primitives` to use `Bound` / `Boundary` / `Endpoint` / `Gradient` swaps to `Finite_Primitives`. Any consumer using Bool's `^` while only `Algebra_Primitives` is imported (no other source of the operator) needs `import Bit_Primitives` (or its `Bit Boolean Primitives` subtarget). End-of-cascade workspace-wide grep + ecosystem-wide `swift build` gate.
4. **Push** in topological order: algebra-primitives (loses files) → finite-primitives (gains files) → bit-primitives (gains file) → consumer wave → cascade-termination.

## Out-of-scope

- Visibility flips, tags, blog posts (deferred per `feedback_no_public_or_tag_without_explicit_yes`).
- Per-type extraction of the five algebra-internal carriers (`Sign`, `Parity`, etc.). Decision 3 closes that question.
- Further narrowing of `swift-standard-library-extensions` contents (audit of existing SLE files for "is this stdlib-missing-piece-shaped?" is a separate dispatch).
- The async-primitives `typed-throws-audit-2026-04-24.md` historical research markdown (still references `Algebra_Primitives.Either` in prose; document-only drift, queued separately).

## References

- `swift-institute/Research/launch-flow-assessment-2026-05-08.md` (predecessor: cohort-launch decisions)
- `swift-institute/Research/array-bounded-index-revisit-2026-05-08.md` §"Bit-Field Witness Home" (carrier-home principle, 11-site ecosystem survey)
- `swift-primitives/Research/tier-inventory-2026-05-08.md` (current chain shape)
- `swift-institute/Skills/ecosystem-data-structures/SKILL.md` [DS-007] (bit-level types)
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` [CI-093] (toolchain wrapper rule landed in this cycle)
- Memory: `feedback_correctness_sole_driver_during_development.md`, `feedback_split_upstream_not_downstream.md`, `feedback_no_deferral_bundle_ecosystem_fixes.md`, `feedback_subordinate_owns_close_out.md`
- HANDOFF-extract-pair-product-either-primitives.md (predecessor dispatch, closed 2026-05-08)
