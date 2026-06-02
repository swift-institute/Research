# Collection.Slice.Protocol / Swift.Collection Subscript Ambiguity

<!--
---
version: 1.0.0
last_updated: 2026-06-02
status: RECOMMENDATION
tier: 2
scope: cross-package
trigger: "A clean build of swift-linter (rm -rf .build + purge-cache + swift package update to fresh main, 2026-06-02) failed in transitive dependency swift-version-primitives with `ambiguous use of subscript(_:)` at Version.Semantic.Parser.swift:158 and Version.Tools.Parser.swift:114. Root cause: the package's generic Parser constrains its input to `Collection.Slice.`Protocol` & Swift.Collection`, and BOTH protocols vend a `subscript(bounds: Range<Index>)` requirement — institute `-> Self`, stdlib `-> SubSequence` — so `input[lo..<hi]` has two equally-valid candidates at the generic call site."
preceded_by:
  - swift-institute/Research/collection-index-escapable-consumer-fallout.md (DECISION v1.3.0, 2026-05-27) — quantified the 43d1fb7 ~Escapable-Index fallout; established the escape-operation migration pattern. Its error classes are Base.Index losing Ordinal/Sendable/Escapable; it does NOT cover the subscript-ambiguity class documented here.
  - swift-institute/Research/parser-collection-protocol-migration.md (DECISION v2.1.0, 2026-02-13) — established Collection.Slice.Protocol + Input.Slice as the canonical parser input; its canonical combinator `While<Input: Collection.Slice.`Protocol`>` constrains the slice protocol ALONE (no `& Swift.Collection`).
  - swift-institute/Research/collection-sequence-protocol-detachment.md (DECISION) — made institute Collection.Protocol orthogonal to (not a refinement of) Swift.Collection; the reason a dual conformer has two independent subscript requirements.
---
-->

## Context

`swift-version-primitives` exposes byte-stream parsers (`Version.Semantic.Parser`, `Version.Tools.Parser`, `Version.Calendar.Parser`) whose generic input is constrained to **both** the institute self-slicing protocol and stdlib `Collection`:

```swift
// Version.Semantic.Parser.swift:47–48  [Verified: 2026-06-02]
public struct Parser<Input: Collection.Slice.`Protocol` & Swift.Collection>: Swift.Sendable
where Input: Swift.Sendable, Input.Element == Byte {
```

A clean build of `swift-linter` (which depends transitively on version-primitives) fails at compile step 4646/4677 — i.e. the whole graph resolves and nearly everything compiles, then version-primitives blocks the remainder:

```
Version.Semantic.Parser.swift:158:58: error: ambiguous use of 'subscript(_:)'
Version.Tools.Parser.swift:114:58:    error: ambiguous use of 'subscript(_:)'
```

Both at `Swift.String(decoding: input[input.startIndex..<i], as: Swift.UTF8.self)`. swift-linter's own sources are never reached; everything downstream is `error: cancelled`.

This is the **subscript-ambiguity class** of fallout. It is *not* the `Base.Index`-loses-Ordinal/Sendable/Escapable class that `collection-index-escapable-consumer-fallout.md` already analyzed and the principal already decided (KEEP `~Escapable`; `43d1fb7` STANDS). That doc's casualty (`Input.Slice`) constrains to institute `Collection.Protocol` *alone*; this doc's casualties additionally require `& Swift.Collection`, and that dual requirement is the entire mechanism here.

## Question

When a parser's generic `Input` is constrained to `Collection.Slice.`Protocol` & Swift.Collection`, a `Range<Index>` subscript is ambiguous between the institute self-slicing requirement (`-> Self`) and stdlib's (`-> SubSequence`). **How should the institute resolve this — at the call site, at the parser's constraint, or in the slice protocol's design — and which option is structurally correct rather than merely the smallest diff?**

## Methodology

- **Toolchain:** Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), `arm64-apple-macosx26.0`, default toolchain (`TOOLCHAINS` unset). `swift --version` verified.
- **Build:** `rm -rf .build` + `swift package purge-cache` + `swift package update` (resolved clean from local mirrors, exit 0) + `swift build`, from `swift-foundations/swift-linter`. `mirrors.json` left intact.
- **Resolution provenance** (per `[feedback_check_package_resolved_before_compiler_bug_claim]`): version-primitives, glob-primitives, collection-primitives reach swift-linter via `.package(path:)` (swift-linter `Package.swift:29–46`); they compile against local working-tree HEADs directly. No stale-mirror confound — the build is against the freshest possible ecosystem state.
- **Attribution:** errors classified by message text. Only 2 `ambiguous subscript` errors surfaced; structurally identical `[Range<Index>]` sites elsewhere are masked by compile-cancellation + Swift's per-context diagnostic batching (see Blast Radius — flagged unverified per `[RES-023]`).
- **Prior art:** `[RES-019]` internal grep of `swift-institute/Research/` + the affected packages' `Research/` performed before analysis (results in Findings §4 and References).

## Findings

### 1. The mechanism — two same-signature requirements, different return type

Institute `Collection.Slice.`Protocol`` (collection-primitives, `Collection.Slice.Protocol.swift:32–40`) `[Verified: 2026-06-02]`:

```swift
public protocol `Protocol`: Collection.`Protocol` & ~Copyable where Index: Swift.Comparable {
    subscript(bounds: Range<Index>) -> Self { get }   // doc: "models SubSequence == Self"
}
```

It refines the institute's `Collection.`Protocol``, which (post the June-1 single-root refactor, `Collection.Protocol.swift:58`) refines `Iterable`, **not** `Swift.Collection` — they are deliberately orthogonal (`collection-sequence-protocol-detachment.md`). So a type that conforms to both protocols carries **two independent** `subscript(bounds: Range<Index>)` requirements:

| Source | Signature | Return |
|--------|-----------|--------|
| `Collection.Slice.`Protocol`` (institute) | `subscript(bounds: Range<Index>)` | `Self` |
| `Swift.Collection` (stdlib) | `subscript(bounds: Range<Index>)` | `SubSequence` |
| `Swift.Collection` (stdlib) | `subscript<R: RangeExpression>(r: R)` | `SubSequence` |

`Index` is unified (the conformer's `Index<Element> = Tagged<Element, Ordinal>` is `Swift.Comparable`, satisfying the slice protocol's `where` clause). All three are applicable to `input[lo..<hi]`; the compiler cannot choose. (The three candidate notes are quoted verbatim in the build log; this is standard Swift overload resolution, not a compiler defect.)

### 2. Why a concrete conformer is immune but a generic consumer is not — the key asymmetry

`input-primitives`' `Input.Slice` conforms to **both** protocols (`Input.Slice+Collection.Slice.Protocol.swift:135` for `Swift.Collection` with `typealias SubSequence = Self`; `:152` for `Collection.Slice.Protocol`) and yet builds clean. The reason: it is a **concrete** type providing a single `subscript(bounds: Range<Index<Element>>) -> Self` (`:156`) that satisfies *both* requirements at once — so a concrete `slice[range]` resolves to one witness. That same file documents the *identical* collision for `formIndex(after:)` and resolves it with one explicit witness (`:140–147`: *"Disambiguates ... between the stdlib `Swift.Collection` default and the institute `Collection.Protocol` default ... a single concrete witness is required"*).

version-primitives' `Parser` is **generic** over `Input: Collection.Slice.`Protocol` & Swift.Collection`. Inside the generic body the compiler sees two *protocol requirements*, not one merged witness, and has no way to know an arbitrary conformer will set `SubSequence == Self`. **The collision is therefore latent in every generic consumer of the dual constraint and invisible in every concrete one.** This is the crux: the fix cannot be the `Input.Slice` "single concrete witness" trick (there is no concrete type to attach it to).

### 3. Blast radius

The dual constraint `Collection.Slice.`Protocol` & Swift.Collection` appears in 5 source files across 3 packages (grep, excluding `.build/`/`Research/`/README/Experiments) `[Verified: 2026-06-02]`:

| Package | File | `[Range<Index>]` call sites | Build status |
|---------|------|-----------------------------|--------------|
| version-primitives | `Version.Semantic.Parser.swift` | `:158` (+ partial-range siblings) | ❌ **:158 confirmed error** |
| version-primitives | `Version.Tools.Parser.swift` | `:45`, `:114` (+ `:55`,`:149` partial-range) | ❌ **:114 confirmed error** |
| version-primitives | `Version.Calendar.Parser.swift` | `:55`, `:175` (+ partial-range) | ⚠️ masked (cancelled before compile) |
| glob-primitives | `Glob.Pattern.Parser.swift` | `:82` | ⚠️ masked — **direct swift-linter dep** (`Package.swift:30`) |
| input-primitives | `Input.Slice+Collection.Slice.Protocol.swift` | provider (concrete `:156`) | ✅ immune (concrete conformer, §2) |

**The 2 surfaced errors undercount the true surface.** Every `input[lo..<hi]` (and likely each `input[i...]` partial-range, which the slice protocol also vends via default extensions) across the three version parsers and glob's parser shares the identical shape. Swift reported only the two sites in `String(decoding:)` context (the strongest disambiguation pressure) before cancellation; the remainder are unverified-but-structurally-identical (`[RES-023]`). glob-primitives is a *direct* swift-linter dependency, so its `:82` is a near-certain second wall.

### 4. Timeline — a fresh-main regression, not the documented 43d1fb7 fallout

| Date | Commit | Event |
|------|--------|-------|
| 2026-05-19 | version-primitives `8fee211` | Parsers migrated to byte streams; **introduces** `Parser<Input: Collection.Slice.`Protocol` & Swift.Collection>` + the `input[range]` → `String(decoding:)` calls |
| 2026-05-26 | collection-primitives `43d1fb7` | `~Escapable`-admitting `Index`; commit message claims *"Verified against ... version-primitives"* (⚠️ **unverified** — the careful `collection-index-escapable-consumer-fallout.md` build matrix did **not** include version-primitives) |
| 2026-05-27 → 06-02 | collection-primitives `c732ebd`, `3cc21cc`, `e141ac3`, `9f48e63`, `ae8efab` | **Hierarchy refactor**: `Collection.Protocol refines Iterable; delete Collection.ForEach` (`3cc21cc`, 06-01); `delete Collection.Indexed` (`9f48e63`, 06-02); `single-root hierarchy` (`ae8efab`, 06-02) |

The dual constraint has existed since **2026-05-19**, yet the `43d1fb7` (05-26) message claims version-primitives built. If that claim holds, the ambiguity was **tipped after 05-26** — the **June-1/06-02 single-root hierarchy refactor** (`3cc21cc`/`9f48e63`/`ae8efab`) is the prime suspect (it restructured `Collection.Protocol`'s refinements and base hierarchy, which governs which subscript requirements are visible at a generic use site). Confirming the exact tipping commit would require building version-primitives against collection-primitives at successive revisions; **not performed** — bisecting an upstream package means checking out historical revisions of another repo's tree, which `[feedback_never_revert_or_checkout]` forbids. The candidate window is named; the precise commit is an unverified hypothesis.

### 5. The canonical-shape deviation

`parser-collection-protocol-migration.md` (DECISION v2.1.0) is the authority on parser inputs: it added `Collection.Slice.Protocol` to collection-primitives and made `Input.Slice` the canonical parser input. Its canonical combinator constrains the slice protocol **alone**:

```swift
// parser-collection-protocol-migration.md:267
public struct While<Input: Collection.Slice.`Protocol`>: Sendable
```

version-primitives' `& Swift.Collection` is therefore a **deviation** from the canonical parser-input shape — added (in `8fee211`) to reach `Swift.String(decoding:as:)`, which requires a stdlib `Collection`. That single added conformance is exactly what drags in the colliding stdlib subscript. The structural question (Option B below) is whether the parser should reach stdlib `String(decoding:)` at all, or stay on the canonical `Collection.Slice.Protocol`-only input and obtain its `String` via an institute byte→text path.

## Analysis

**Criteria:** (1) *structural correctness* — does it align with the canonical parser-input shape and the Collection/stdlib orthogonality decision? (`[RES-022]` makes this primary); (2) *blast radius* — sites touched; (3) *recurrence* — does it prevent the next dual-constrained generic from re-hitting this? (4) *coupling* — does it pull stdlib into the institute parser stack? (5) *risk/diff* — tiebreaker only.

### Option A — Disambiguate at the call sites (tactical)

Annotate the result type to select the institute requirement, e.g. `let s: Input = input[input.startIndex..<i]; String(decoding: s, …)` (or `as Input.SubSequence` to select stdlib). Keeps the dual constraint.

- **Pros:** smallest diff; unblocks the build immediately; no protocol or convention change.
- **Cons:** masks the collision rather than removing it — *every* future generic `[Range]`/`[i...]` call in a dual-constrained context must remember the annotation (pure ceremony, `[RES-018]`-adjacent footgun); ~6–10 sites across 3 version parsers + glob, each easy to miss; leaves the canonical-shape deviation (§5) in place; does **not** resolve the Byte-vs-UInt8 open question (it sits behind the ambiguity, see Open Question).

### Option B — Drop `& Swift.Collection`; obtain `String` via an institute byte→text path (structural)

Constrain parser inputs to `Collection.Slice.`Protocol`` alone (matching canonical `While`). With only one slice subscript, the ambiguity vanishes by construction. Replace `Swift.String(decoding: slice, as: UTF8.self)` with an institute facility that builds a `String`/text value from an `Iterable`/`Collection.Slice.Protocol` of `Byte`.

- **Pros:** removes the collision at the root (no annotation discipline ever needed); realigns with the canonical parser-input shape (`[RES-022]` structural); keeps the institute parser stack off stdlib `Collection` (the orthogonality the detachment decision intends); simultaneously addresses the Byte-vs-UInt8 mismatch (an institute path takes `Byte`, not `UInt8`).
- **Cons:** requires an institute `Byte`-sequence→`String` facility to exist (or be built) — scope depends on whether one is already available; larger diff than A; touches all `String(decoding:)` sites.

### Option C — Make `Collection.Slice.`Protocol`` refine `Swift.Collection` with `SubSequence == Self` (upstream)

Fold the institute slice subscript into stdlib's `SubSequence` slot so there is structurally one requirement.

- **Pros:** any dual conformer would have a single subscript; consumers need no change.
- **Cons:** **contradicts the detachment DECISION** (institute `Collection.Protocol` is deliberately orthogonal to `Swift.Collection`); forces *every* slice conformer to be a stdlib `Collection` (couples the L1 collection lattice to stdlib); a foundational reversal of a standing decision — out of proportion to the problem. Rejected pending a separate Tier-3 reopening of detachment.

### Option D — Pin parser `Input` to the concrete `Input.Slice` / `Index<Element>`

Drop the generic dual constraint; have the parsers consume the concrete `Input.Slice` (the canonical input), which is immune (§2).

- **Pros:** inherits input-primitives' single-witness immunity; concrete codegen.
- **Cons:** narrows the parser's genericity (it was deliberately generic over byte streams to "compose with the institute parser ecosystem", per the type's own doc comment); larger semantic change than the problem warrants; may regress the parser-combinator composition story.

### Comparison

| Criterion | A (call-site) | B (drop `& Swift.Collection`) | C (refine stdlib) | D (concrete input) |
|-----------|:---:|:---:|:---:|:---:|
| Structural correctness (`[RES-022]`) | ✗ masks | ✓ canonical shape | ✗ reverses detachment | ~ narrows genericity |
| Removes collision at root | ✗ | ✓ | ✓ | ✓ |
| Prevents recurrence | ✗ per-site discipline | ✓ | ✓ | ✓ (for these parsers) |
| Keeps parser stack off stdlib | ✗ | ✓ | ✗ couples | ~ |
| Blast radius | 6–10 sites | all `String(decoding:)` sites + maybe 1 new facility | 1 protocol (ecosystem-wide) | 3 packages' parser signatures |
| Addresses Byte-vs-UInt8 | ✗ | ✓ | ✗ | depends |
| Diff / risk (tiebreaker) | smallest | medium | large | medium |

## Open Question (verification gate — `[RES-027]`)

**Does fixing the ambiguity yield a clean compile, or does a Byte-vs-UInt8 mismatch surface next?** The parsers set `Input.Element == Byte` (`Version.Semantic.Parser.swift:48`), but `Swift.String(decoding: _, as: Swift.UTF8.self)` requires `Element == UInt8` (`UTF8.CodeUnit`). `Byte` is a distinct sibling type from `UInt8` (byte-discipline). The element-type check happens *after* overload resolution, so it is **masked** behind the ambiguity error and **unverified**. Two outcomes:

- If `String(decoding:)` over `Byte` already typechecks (an institute overload, or a bridge) → Option A is sufficient to unblock.
- If it does not → version-primitives' byte-stream parsers have **never** cleanly compiled since `8fee211` (consistent with the only "verified" claim being the `43d1fb7` commit message, never independently reproduced), and **Option B is mandatory** (an institute byte→text path is needed regardless).

**Recommended follow-up:** a ≤1-hour spike — apply Option A's annotation to the 2 confirmed sites in a scratch checkout, `swift build --package-path swift-version-primitives`, and read the next error class. This single build decides A-vs-B and confirms/refutes the Byte-vs-UInt8 hypothesis. (Per `[RES-027]`, this loose end is a *premise*, not a direction — it must be resolved empirically before this doc reaches DECISION.)

## Outcome

**Status: RECOMMENDATION.** No source changed by this investigation (the report-not-fix scope was explicit).

Structurally (`[RES-022]`), **Option B** is correct: the `& Swift.Collection` is a deviation from the canonical `Collection.Slice.Protocol`-only parser input (§5), it is the sole source of the colliding stdlib subscript, and removing it both eliminates the ambiguity by construction and keeps the institute parser stack off stdlib `Collection` per the detachment decision. **Option A** is the legitimate tactical unblock if a release window demands it — but it masks an ecosystem-wide footgun (every future dual-constrained generic re-hits it) and does not address Byte-vs-UInt8. **Options C/D are rejected** (C reverses a standing DECISION; D over-narrows the parsers).

The A-vs-B choice is **gated on the verification spike** above: if `String(decoding:)` cannot consume `Byte`, B is forced. Recommended sequence: (1) run the spike; (2) if A suffices and velocity dominates, apply A across all 5 sites *and* file a follow-up to migrate to B; (3) otherwise apply B (build/adopt the institute byte→text path), updating version-primitives' 3 parsers and glob-primitives' parser to `Collection.Slice.`Protocol``-only inputs. Either path is a small, well-scoped change; the principal owns the A-vs-B token after the spike.

This is **independent of** `collection-index-escapable-consumer-fallout.md`'s decided escape-operation migration (that addresses `Base.Index` API loss; this addresses subscript-overload ambiguity from the `& Swift.Collection` dual constraint). The two co-occur in the same parser files but are orthogonal axes.

## References

- **Mechanism:** `swift-collection-primitives/Sources/Collection Slice Primitives/Collection.Slice.Protocol.swift:32–40`; `…/Collection Protocol Primitives/Collection.Protocol.swift:58,64` (refines `Iterable`, `~Escapable` `Index` associatedtype).
- **Casualties:** `swift-version-primitives/Sources/Version Primitives/Version.Semantic.Parser.swift:47–48,158`; `Version.Tools.Parser.swift:45,114`; `Version.Calendar.Parser.swift:55,175`; `swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern.Parser.swift:82`.
- **Immune concrete conformer (the disambiguation precedent):** `swift-input-primitives/Sources/Input Slice Primitives/Input.Slice+Collection.Slice.Protocol.swift:135–148,152–161`.
- **Timeline commits:** version-primitives `8fee211` (2026-05-19); collection-primitives `43d1fb7` (2026-05-26), `3cc21cc`/`9f48e63`/`ae8efab` (2026-06-01/02).
- **Prior art (institute):** `swift-institute/Research/collection-index-escapable-consumer-fallout.md` (DECISION v1.3.0); `parser-collection-protocol-migration.md` (DECISION v2.1.0 — canonical `While<Input: Collection.Slice.`Protocol`>` at `:267`); `collection-sequence-protocol-detachment.md` (DECISION — Collection/stdlib orthogonality).
- **Governing rules:** `[RES-022]` (structural over min-diff), `[RES-027]` (loose-end empirical follow-up), `[RES-023]`/`[RES-013a]` (write-time empirical verification), `[feedback_check_package_resolved_before_compiler_bug_claim]`, `[feedback_never_revert_or_checkout]`.
- **Empirical baseline:** `swift build` of swift-linter, Apple Swift 6.3.2 / macOS 26.2 / arm64, all local deps at working-tree HEAD, 2026-06-02 (this investigation).
