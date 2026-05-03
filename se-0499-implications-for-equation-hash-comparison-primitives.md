# SE-0499 Implications for swift-equation-primitives, swift-hash-primitives, and swift-comparison-primitives

<!--
---
version: 1.3.0
last_updated: 2026-05-03
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to: [swift-equation-primitives, swift-hash-primitives, swift-comparison-primitives]
supersedes_premise_of: [swift-equation-primitives/Research/Equation Primitives Design.md (v2.1.0, §11.3)]
verification_experiment: swift-institute/Experiments/se-0499-stdlib-noncopyable-protocol-conformance/
changelog:
  - v1.3.0 (2026-05-03): Status DEFERRED → RECOMMENDATION (Option C-refined, restored). v1.2.0's deferral was based on a build-config defect: `xcrun --toolchain 'swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a' swift build` set the compiler binary but did NOT point SwiftPM at the nightly's stdlib `.swiftinterface`; the build resolved Equatable/Hashable/Comparable against the host Xcode SDK's older interface and produced false-negative diagnostics. Re-run with `TOOLCHAINS=org.swift.64202603161a swift build` builds both spike targets (direct stdlib conformance AND `*.\\`Protocol\\`` typealias adoption) clean. Empirical reality confirmed: SE-0499 IS landed in main as of 2025-12-03 via Ben Cohen's split PRs #85746 (Equatable), #85747 (Comparable), #85748 (Hashable) — distinct from the umbrella WIP PR #85079 that is still open. The 2026-03-16 nightly's `Swift.swiftmodule/arm64-apple-macos.swiftinterface` declares `public protocol Equatable : ~Copyable, ~Escapable` (and analogously Comparable/Hashable). v1.2.0 incorrectly inferred from the failed build that SE-0499 was unlanded; the real lesson is to suspect build-config first when an upstream-status check + `.swiftinterface` inspection contradict a build-result. The Option C-refined recommendation stands. Proactive guard application proceeds.
  - v1.2.0 (2026-05-03, RETRACTED): Defer on a false-negative spike. The build was misconfigured (TOOLCHAINS env var unused; compiler-binary toolchain selection alone does not redirect SwiftPM's stdlib resolution). PR #85079 is genuinely WIP, but the SE-0499 work landed in split PRs #85746/#85747/#85748 — checking only the umbrella PR was insufficient. Local swiftlang/swift clone (`/Users/coen/Developer/swiftlang/swift`, branch release/6.3.1, fetched main 2026-05-03) contains the merged commits.
  - v1.1.0 (2026-05-03): Recommendation flipped from B (deprecate-protocol) to C-refined (typealias-to-stdlib) per principal redirect. v1.0.0's Option C analysis underweighted the namespace-adoption-typealias pattern (mistakenly classified as a rename bridge per `feedback_namespace_adoption_typealias.md`). v1.1 corrects that, and surfaces three downstream consequences: bridge-file cascade deletion, equation-primitives reducing to a pure shim, and the refinement chain composing structurally across typealiases.
---
-->

## Context

[`swift-equation-primitives`](../../../swift-primitives/swift-equation-primitives), [`swift-hash-primitives`](../../../swift-primitives/swift-hash-primitives), and [`swift-comparison-primitives`](../../../swift-primitives/swift-comparison-primitives) each fork a stdlib protocol — `Equation.Protocol` mirrors `Swift.Equatable`, `Hash.Protocol` mirrors `Swift.Hashable`, `Comparison.Protocol` mirrors `Swift.Comparable` — for one explicit reason: at the time these packages were authored, the stdlib protocols did not support `~Copyable` types. Each fork uses identical signatures with `borrowing` parameters to allow move-only conformers.

The packages' own design rationale is explicit on this. From `swift-equation-primitives/Research/Equation Primitives Design.md` (v2.1.0, §11.1, last_updated 2026-03-18):

> Traditional equality requires copying values: `func == (lhs: T, rhs: T) -> Bool` // Copies both arguments. For noncopyable types, this is impossible. Solution: `borrowing` parameters.

That document cites SE-0499 as a forward signal but treats the fork as the production-grade workaround. The protocol header comments are blunter: `// An Equatable fork with ~Copyable support.` (`Equation.Protocol.swift:2`), `// A Hashable fork with ~Copyable support.` (`Hash.Protocol.swift:2`), `// A Comparable fork with ~Copyable support.` (`Comparison.Protocol.swift:2`).

**Trigger for this research**: SE-0499 *Support `~Copyable` and `~Escapable` in Standard Library Protocols* is now [Implemented (Swift 6.4)][SE-0499]. The premise that motivated the three forks no longer holds. The user requested an analysis of whether these packages can eventually be deprecated.

Per `feedback_toolchain_versions.md`, the ecosystem ships against Swift 6.3 and 6.4-dev nightly. Swift 6.4 has not yet shipped stable.

## Question

Now that `Swift.Equatable`, `Swift.Hashable`, and `Swift.Comparable` natively support `~Copyable` types in Swift 6.4 (SE-0499), can `swift-equation-primitives`, `swift-hash-primitives`, and `swift-comparison-primitives` be deprecated? If partial — what surface stays, what goes, and on what schedule?

## Analysis

### Step 1: SE-0499 declared scope (per proposal text — empirical reality differs, see Empirical Verification section below)

| Stdlib protocol | Swift 6.4 signature (SE-0499) | Three-package fork signature |
|---|---|---|
| `Equatable.==` | `static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool` | `Equation.Protocol`: identical |
| `Hashable.hash(into:)` | `borrowing func hash(into:)` (via Hasher.combine borrowing overloads) | `Hash.Protocol`: identical |
| `Comparable.<` | `static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool` | `Comparison.Protocol`: identical |

Per the SE-0499 proposal text [verified 2026-05-03 against `swiftlang/swift-evolution/proposals/0499-support-non-copyable-simple-protocols.md`]: *"The design of `~Copyable` and `~Escapable` explicitly allows for source compatibility with retroactive adoption."* Existing `Copyable` conformances continue to work unchanged; types now also gain the option to conform while being `~Copyable`. No source break.

**Declared consequence (per proposal frontmatter)**: under Swift 6.4, the three protocol forks would be byte-for-byte equivalent to the stdlib protocols they fork from, modulo namespace.

**Verified consequence (per the spike)**: SE-0499 has not actually shipped — implementation PR `swiftlang/swift#85079` is OPEN/WIP. See the Empirical Verification section below. The Step 2-4 analysis of options remains valid as the **shape** of the eventual transition; only the trigger condition has moved.

### Step 2: Per-package surface inventory (what the packages contain *beyond* the protocol fork)

| Package | Source files | Non-protocol surface |
|---|---|---|
| `swift-equation-primitives` | `Equation.swift` (namespace `enum`), `Equation.Protocol.swift`, `Equation.Protocol+Identity.Tagged.swift`, ~20 `+Swift.*.swift` stdlib bridges | **None.** Equation is purely the protocol + bridges. |
| `swift-hash-primitives` | `Hash.swift` (namespace `enum`), `Hash.Protocol.swift`, `Hash.Value.swift` (= `Tagged<Hash, Int>`), `Hash.Protocol+Identity.Tagged.swift`, ~20 `+Swift.*.swift` stdlib bridges | **`Hash.Value`** (typed wrapper for hash output, prevents misuse of arbitrary `Int` as hash). |
| `swift-comparison-primitives` | `Comparison.swift` (three-way result `enum` `.less/.equal/.greater`), `Comparison.Protocol.swift`, `Comparison.Compare.swift`, `Comparison.Clamp.swift`, `Comparison.Protocol+Identity.Tagged.swift`, `+Property.View` integrations, ~20 `+Swift.*.swift` stdlib bridges | **`Comparison` enum** (three-way comparison result type with `.then/.reversed/.isLess/...` per `Comparison Primitives Design.md`), **`Comparison.Compare`**, **`Comparison.Clamp`** (Property.View patterns). |

The asymmetry is decisive: equation-primitives is *only* a protocol fork, hash-primitives is *protocol fork + one typed wrapper*, comparison-primitives is *protocol fork + a substantial value-type surface (three-way comparison enum, Compare, Clamp)*.

### Step 3: Options

#### Option A — Full deprecation of all three packages

Deprecate `swift-equation-primitives`, `swift-hash-primitives`, `swift-comparison-primitives` outright; consumers migrate to `Swift.Equatable/Hashable/Comparable`.

| Pro | Con |
|---|---|
| Maximum simplification | Loses `Comparison` (three-way result enum), `Comparison.Compare`, `Comparison.Clamp` — substantive value-type surface, not a protocol fork |
| | Loses `Hash.Value` typed wrapper |
| | Throws out the `Property.View` integrations |
| | The three-way `Comparison` enum has independent justification per its own design doc — not a `Comparable` substitute |

**Verdict**: too aggressive. Conflates "protocol fork is now redundant" with "everything in these packages is redundant." Rejected.

#### Option B — Deprecate `*.Protocol`; retain non-protocol value-type surface

Per-package action:

- **`swift-equation-primitives`**: deprecate `Equation.Protocol` and the `Equation.Protocol+*` bridges. **Nothing else lives in this package.** Deprecation effectively retires the package. The `Equation` namespace `enum` and `Equation.Protocol+Identity.Tagged.swift` go with it.
- **`swift-hash-primitives`**: deprecate `Hash.Protocol` and bridges. Decide whether `Hash.Value` (typed `Tagged<Hash, Int>`) is load-bearing enough to justify a single-type package. If yes, keep `swift-hash-primitives` as a *one-purpose* package (typed hash wrapper). If no, fold `Hash.Value` into `swift-tagged-primitives` or its consumers and retire the package.
- **`swift-comparison-primitives`**: deprecate `Comparison.Protocol` and bridges. **Keep** the `Comparison` three-way result enum (with `.then/.reversed/.isLess/.isEqual/.isGreater/.isLessOrEqual/.isGreaterOrEqual` and the `init<T: Comparable>(_ lhs:_ rhs:)` ctor), `Comparison.Compare`, `Comparison.Clamp`, and the `Property.View` integrations. The package's reason for existing shifts from "Comparable fork" to "three-way comparison value type + clamp/compare combinators" — an independent and unaffected mission per its own design doc (`Comparison Primitives Design.md` v1.0.0 §1.1).

| Pro | Con |
|---|---|
| Removes redundant API surface created by SE-0499 | Asymmetric — equation-primitives gets fully retired, others survive in reduced form |
| Preserves value-type surface that has independent justification | Requires per-consumer migration of `Equation.Protocol`/`Hash.Protocol`/`Comparison.Protocol` conformances and call sites to stdlib protocols |
| Aligns the ecosystem with Swift's canonical equality/hashing/ordering protocols (no per-ecosystem fork) | Asymmetry is real but matches reality — the three packages were never symmetric in non-protocol content |
| Removes the `Equation` vs `Equatable` naming-shadow tension at root, since there is no second protocol to disambiguate from | |

**Verdict**: structurally correct per [RES-022] (structural correctness over diff-size). Recommended.

#### Option C — Replace `*.Protocol` with a `typealias` to the stdlib protocol (recommended)

Replace each `extension Equation { protocol \`Protocol\` ... }` with `extension Equation { typealias \`Protocol\` = Swift.Equatable }` (and analogously `Hash.Protocol = Swift.Hashable`, `Comparison.Protocol = Swift.Comparable`).

**Per `feedback_namespace_adoption_typealias.md`**: namespace adoption typealiases are permitted; rename bridges are forbidden. This is the former, not the latter — `Equation.Protocol` is a namespace path to the canonical `Swift.Equatable`, not a renamed identity. (v1.0.0 of this research mis-classified this as a rename bridge and rejected Option C on that basis. Corrected v1.1.0.)

**Refinement chain**: holds structurally without extra work. `Swift.Hashable: Swift.Equatable` and `Swift.Comparable: Swift.Equatable` already, so `Hash.Protocol (= Swift.Hashable)` correctly refines `Equation.Protocol (= Swift.Equatable)` via the typealiases.

**Cascade consequences** that Option B doesn't surface (and that v1.0.0 missed):

1. **Bridge files (~60 across three packages) become redundant.** `Equation.Protocol+Swift.Array.swift` etc. re-conform stdlib types to the fork protocols. Once `Equation.Protocol === Swift.Equatable`, those re-declarations duplicate stdlib's existing conditional conformances (`Array: Equatable where Element: Equatable`) and produce duplicate-conformance build errors. They MUST be deleted in the same change. Same logic applies to `+Identity.Tagged` files if `Tagged` is already conditionally `Equatable`/`Hashable`/`Comparable` — verify per file.
2. **`swift-equation-primitives` collapses to a namespace shim.** With protocol typealiased and bridges deleted, the entire package reduces to `enum Equation {}` + one `typealias`. Per `feedback_strict_mission_early.md` ("don't defer architectural moves on pragmatic grounds"), that's not enough mission to keep a package. Sub-decision needed: **(a)** retire equation-primitives entirely; consumers and downstream packages drop the `Equation` namespace and use `Swift.Equatable` directly, OR **(b)** keep the shim as a transitional courtesy and retire after one minor cycle. Recommendation: **(a)**. The `Equation` namespace was a fork artifact; without the fork, it has no independent reason to exist. Hash and Comparison can each `typealias \`Protocol\` = Swift.Hashable` / `Swift.Comparable` directly on their own namespaces with no `Equation` dependency.
3. **`swift-hash-primitives` retains `Hash.Value` + the typealias for `Hash.Protocol`.** Mission becomes "typed `Tagged<Hash, Int>` hash output + namespace alias for the canonical hash protocol."
4. **`swift-comparison-primitives` retains `Comparison` (3-way result enum) + `Compare` + `Clamp` + `Property.View` integrations + the typealias for `Comparison.Protocol`.** Mission is the value-type ecosystem per its own design doc, with the namespace alias as additional courtesy.

| Pro | Con |
|---|---|
| Source-compatible — no consumer migration needed | Bridge-file cascade deletion (~60 files); not a drop-in replacement at the file level |
| Honest about what happened: the fork was a workaround; the namespace can survive as alias to canonical | `typealias` to a `protocol` works in all standard generic-constraint positions in Swift 6.x, but [RES-021] verification spike applies (verify against 6.4-dev nightly external target) |
| Removes `Equation` vs `Equatable` naming-shadow tension at the root: `Equation.Protocol` IS `Swift.Equatable` | equation-primitives reduces to nothing meaningful; sub-decision needed on whether to retire entirely (recommended) or keep as shim |
| Refinement chain composes (`Hash.Protocol`/`Comparison.Protocol` typealiases compose with `Equation.Protocol` typealias structurally) | Tagged+Property.View bridges may need per-file audit to confirm which become redundant |

**Verdict**: structurally correct, source-compatible, honest about the workaround's resolution. **Recommended.**

#### Option D — Status quo until Swift 6.4 ships stable

Defer any change until Swift 6.4 GA. Per `feedback_toolchain_versions.md` the workspace already runs 6.4-dev nightly, so SE-0499 can be exercised today, but downstream consumers across the ecosystem may still target 6.3.

| Pro | Con |
|---|---|
| Avoids forcing 6.4-only API on the ecosystem | Postpones a known-redundant fork's removal, accumulating zombie usage in the meantime |
| Aligns with conservative tool-version contract | The window of new conformers being written against `Equation.Protocol` is wasted work |

**Verdict**: this is a *timing* axis, not an alternative to Option B. Combined with B below.

### Step 4: Comparison

| Criterion | A (full deprecate) | B (deprecate protocols, keep value types) | C (typealias to stdlib) | D (status quo) |
|---|---|---|---|---|
| Removes redundant protocol fork | ✓ | ✓ | ✓ (collapses fork into canonical via alias) | ✗ |
| Preserves `Comparison` 3-way enum + `Compare/Clamp` | ✗ | ✓ | ✓ | ✓ |
| Preserves `Hash.Value` typed wrapper | ✗ | ✓ (decide separately) | ✓ | ✓ |
| Eliminates `Equation` vs `Equatable` naming tension | ✓ | ✓ | ✓ (alias makes them identical) | ✗ |
| Source-compatible during transition | ✗ | ✗ (needs consumer migration) | ✓ | ✓ |
| Bridge-file cleanup required | n/a | n/a (deleted with protocol) | ✓ (~60 files; cascade deletion) | ✗ |
| Locks ecosystem to Swift 6.4 minimum | ✓ | ✓ | ✓ | ✗ |
| Structural correctness ([RES-022]) | over-broad | structural but not source-compatible | structural AND source-compatible | preserves known-redundant fork |

## Empirical Verification (2026-05-03)

The [RES-021] verification spike was scaffolded as `swift-institute/Experiments/se-0499-stdlib-noncopyable-protocol-conformance/` — two targets:

- `SE0499Spike`: declares `~Copyable` conformances directly to `Swift.Equatable`/`Hashable`/`Comparable`, plus generic-constraint use sites `<T: Equatable & ~Copyable>` and `<T: Comparable & ~Copyable>`.
- `SE0499SpikeTypealias`: declares the same conformances via the proposed `extension Equation { typealias \`Protocol\` = Swift.Equatable }` adoption shape (and analogously Hash, Comparison).

**Build matrix (re-run with corrected toolchain selection per v1.3.0)**:

| Toolchain | Selection mechanism | Result |
|---|---|---|
| Swift 6.3.1 (Xcode default) | `swift build` | **FAIL** (expected — pre-SE-0499 stdlib) |
| Swift 6.4-dev DEVELOPMENT-SNAPSHOT-2026-03-16-a | `xcrun --toolchain 'swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a' swift build` | **FAIL** (false negative — see footnote) |
| Swift 6.4-dev DEVELOPMENT-SNAPSHOT-2026-03-16-a | `TOOLCHAINS=org.swift.64202603161a swift build` | **PASS** ✓ — both targets build clean |

**Footnote on the false-negative**: `xcrun --toolchain '<snapshot-name>' swift build` selects the nightly compiler binary but does NOT redirect SwiftPM's stdlib resolution; SwiftPM continues to read `Swift.swiftinterface` from the host Xcode SDK, which (on Xcode 26.4.1) still ships the pre-SE-0499 protocol declaration. The nightly's bundled `Swift.swiftmodule/arm64-apple-macos.swiftinterface` (at `/Users/coen/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a.xctoolchain/usr/lib/swift/macosx/`) DOES declare `public protocol Equatable : ~Copyable, ~Escapable` — verified by direct grep. The correct selection mechanism is the `TOOLCHAINS` env var with the bundle identifier (`defaults read .../Info CFBundleIdentifier` → `org.swift.64202603161a`), which makes SwiftPM resolve all stdlib paths against the toolchain. Lesson for future spikes: when `.swiftinterface` inspection and build result disagree, suspect build-config (toolchain-binary vs toolchain-stdlib resolution) before concluding the upstream change is missing.

**Implementation PR landscape (verified against local clone of `swiftlang/swift` main, fetched 2026-05-03)**:

The proposal cites umbrella PR `swiftlang/swift#85079` ("[WIP] Allow various StdLib protocols: ~Copyable, ~Escapable") which IS open/WIP. The actual implementation landed via Ben Cohen's split PR series (commit dates verified against `git log origin/main`):

| PR | Title | Landed |
|---|---|---|
| #85746 | Allow Equatable: ~Copyable | 2025-12-03 |
| #85747 | Allow Comparable: ~Copyable | 2025-12 |
| #85748 | Allow Hashable: ~Copyable | 2025-12 |
| #85854 | Allow Equatable: ~Escapable | 2025-12 |
| #85891 | Allow Comparable: ~Escapable | 2025-12 |
| (merge for nonescapable-hashable) | #86039 | landed |

PR #85746 commit body explicitly states: "Multi-part version of #85079." The umbrella PR remains WIP because the work was split into landed pieces. Checking only #85079 was insufficient for an implementation-status determination — for SE-0499 specifically, the proposal's Implementation field is misleading; the merged-PR truth requires checking the split-PR family.

**Conclusion**: SE-0499 IS landed for Equatable / Hashable / Comparable on Swift 6.4-dev (and `~Escapable` companion lands too). The 2026-03-16 nightly carries the change in its bundled stdlib. Both deployment shapes (direct stdlib conformance, and the namespace-adoption typealias) build clean.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: **Option C-refined** (typealias `*.Protocol` to stdlib counterparts; bridge cascade-deletion; equation-primitives sub-decision pending). Verification spike has cleared the [RES-021] gate.

**Execution plan (proceed proactively per principal direction, with `#if swift(>=6.4)` compiler guards so 6.3 consumers stay green)**:

1. `swift-equation-primitives`: in `Equation.Protocol.swift`, wrap the existing `protocol \`Protocol\`` declaration in `#if swift(<6.4)` and add an `#else` branch with `extension Equation { public typealias \`Protocol\` = Swift.Equatable }`. Wrap each `Equation.Protocol+Swift.*.swift` bridge body in `#if swift(<6.4)` (under 6.4 they would duplicate stdlib's existing conditional conformances). Audit `Equation.Protocol+Identity.Tagged.swift` per actual condition. Build twice (6.3 default + 6.4-dev via TOOLCHAINS) and verify both green. Sub-decision on full retirement deferred to a separate cycle (this commit only adds the typealias under the guard).
2. `swift-hash-primitives`: same pattern with `Swift.Hashable`. Keep `Hash.Value`.
3. `swift-comparison-primitives`: same pattern with `Swift.Comparable`. Keep `Comparison` (3-way result), `Comparison.Compare`, `Comparison.Clamp`, `Property.View` integrations.
4. Update `Equation Primitives Design.md` v2.1.0 with header note marking §11.3 + §17 SUPERSEDED.

**Why pre-execute now (revised from v1.2.0's incorrect "do not pre-execute")**:

- SE-0499 IS landed and IS in the 2026-03-16 nightly. The proactive guard application has both branches that build today.
- The compiler-guard pattern keeps 6.3 consumers untouched (still on the fork) while 6.4 consumers get the canonical stdlib protocol via the typealias path.
- Once Swift 6.4 reaches stable AND the ecosystem's minimum Swift version moves to 6.4, the `#if swift(<6.4)` branches and bridge files become reachable-only-by-deletion; that cleanup is a separate cycle.

**Per `feedback_no_public_or_tag_without_explicit_yes`**: each package modification, deprecation, retirement, and design-doc supersession remains a separate per-action authorization. The verification spike is authorized by this research; per-package guard application requires explicit per-package go-ahead.

Sequence:

1. **Verification spike** (do now): minimal external SwiftPM target that
    - declares `struct T: ~Copyable, Swift.Equatable { static func == (lhs: borrowing T, rhs: borrowing T) -> Bool { ... } }` (and analogously `Swift.Hashable`, `Swift.Comparable`),
    - declares `extension Equation { typealias \`Protocol\` = Swift.Equatable }` and confirms `extension T: Equation.\`Protocol\`` resolves correctly,
    - builds clean against Swift 6.4-dev nightly.
    Per [RES-021], this is mandatory before the recommendation reaches DECISION status. Failure modes (`@_spi` stripping, SDK `.swiftinterface` lag for new protocol availability) are exactly the risks here.
2. **On spike pass + Swift 6.4 stable** (whichever is later): execute Option C. Per-package:
    - `swift-equation-primitives`: replace `protocol \`Protocol\`` with `typealias \`Protocol\` = Swift.Equatable`. Delete all `Equation.Protocol+Swift.*.swift` bridges (now duplicate-conformance errors against stdlib's existing conditional conformances). Audit `Equation.Protocol+Identity.Tagged.swift` per its actual condition. **Then sub-decision**: package's net content is now `enum Equation {}` + one typealias. Recommended **retire entirely** — drop the `Equation` namespace; have hash and comparison primitives use `Swift.Hashable`/`Swift.Comparable` directly without an `Equation` namespace alias. Per `feedback_strict_mission_early.md`, no mission left to defend. Alternative (keep as transitional shim) acceptable but should not become permanent.
    - `swift-hash-primitives`: replace `protocol \`Protocol\`` with `typealias \`Protocol\` = Swift.Hashable`. Delete `Hash.Protocol+Swift.*.swift` bridges (cascade). Audit `Hash.Protocol+Identity.Tagged.swift`. **Keep** `Hash.Value` (= `Tagged<Hash, Int>`). Mission becomes "typed hash output wrapper + namespace alias to the canonical hash protocol." If equation-primitives retires per the sub-decision above, drop the dependency edge.
    - `swift-comparison-primitives`: replace `protocol \`Protocol\`` with `typealias \`Protocol\` = Swift.Comparable`. Delete `Comparison.Protocol+Swift.*.swift` bridges (cascade). Audit `Comparison.Protocol+Identity.Tagged.swift` and `Comparison.Protocol+Property.View.swift`. **Keep** `Comparison` (three-way result), `Comparison.Compare`, `Comparison.Clamp`, `Property.View` integrations. Mission unchanged from `Comparison Primitives Design.md` v1.0.0 §1.1 (three-way comparison value type ecosystem). If equation-primitives retires, drop the dependency edge.
3. **Update `Equation Primitives Design.md` v2.1.0** with a header note marking §11.3 (current Swift 6 status) and §17 (Protocol Design) as SUPERSEDED by SE-0499 / this research. Per [RES-013a]: prior research is leads, not ground truth.

**Why not pre-execute (do nothing now beyond the spike)**:

- Swift 6.4 is dev nightly, not stable. Forcing the typealias today imposes a 6.4-only minimum on every downstream consumer.
- SE-0499's "Implemented (Swift 6.4)" label is the proposal's status; it is not a guarantee that the SDK `.swiftinterface` exposes the relaxed protocol bound on every platform/toolchain build. Spike before trust.
- Per `feedback_no_public_or_tag_without_explicit_yes`: the actions above (typealias swap, bridge deletions, package retirement, design-doc supersession) each require explicit per-action authorization. This research stages the plan; it does not authorize execution.

**Open questions**:

- **Equation-primitives retirement vs shim**: which of (a) drop the `Equation` namespace entirely or (b) keep as transitional shim? Recommended (a); needs principal sign-off.
- **Hash.Value** (`Tagged<Hash, Int>`) — does it survive on its own merit as a single-purpose package, or fold into `swift-tagged-primitives`? Separate sub-investigation, not gated by SE-0499.
- **Comparison.Clamp / Compare and the three-way `Comparison` enum** — second-consumer check per [MOD-RENT] / [RES-018] before defending the package's continued existence post-protocol-typealias.
- **Bridge-file audit boundary**: `+Identity.Tagged` and `+Property.View` integrations need per-file inspection to determine which become duplicate conformances (delete) vs add genuinely new conformance (keep).

## References

### Swift Evolution

- [SE-0499 — Support `~Copyable` and `~Escapable` in Standard Library Protocols][SE-0499] (Implemented, Swift 6.4)
- [SE-0390 — Noncopyable Structs and Enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0427 — Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0437 — Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)

### Internal research (per [RES-019] step-0 grep)

- `swift-equation-primitives/Research/Equation Primitives Design.md` (v2.1.0, status DECISION) — original fork rationale; §11 directly cites SE-0499 as a forward signal. This research supersedes the premise of §11.3.
- `swift-comparison-primitives/Research/Comparison Primitives Design.md` (v1.0.0, status RECOMMENDATION) — independent mission for the three-way `Comparison` enum, unaffected by SE-0499.
- `swift-hash-primitives/Research/hash-value-newtype.md` — `Hash.Value` typed-wrapper rationale, unaffected by SE-0499.

### Internal conventions

- [RES-013a] Synthesis Verification — applies to the carried-forward "stdlib doesn't support ~Copyable" premise.
- [RES-021] Stdlib-Protocol Conformance Verification Spike — mandatory before this RECOMMENDATION reaches DECISION.
- [RES-022] Recommendation-Section Framing Heuristic — structural correctness over diff-size; structural option chosen.
- [RES-023] Empirical-Claim Verification — drives the SE-0499 status check ("Implemented (Swift 6.4)" verified against the proposal text 2026-05-03).
- `feedback_toolchain_versions.md` — workspace targets Swift 6.3 and 6.4-dev nightly only; informs the timing gate.
- `feedback_no_public_or_tag_without_explicit_yes` — none of the deprecation actions are authorized by this research.

[SE-0499]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md
