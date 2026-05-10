# Pair / Either / Product Publication Handoff

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: ACTIVE
tier: 2
scope: cross-package
applies_to: [swift-pair-primitives, swift-either-primitives, swift-product-primitives]
---
-->

## Mission

Get `swift-pair-primitives` and `swift-product-primitives` from PRIVATE / brief-authored state to PUBLIC / 0.1.0-tagged. Cross-pollinate any drift between the three sister packages so they read on-par to a fresh consumer encountering all three. `swift-either-primitives` is **already public** (the canonical baseline); the other two need to land alongside it without visible inconsistency.

## Scope

**In scope**:
- Final pre-publication pass on each of the three packages
- Cross-package convention alignment (file layout, conformance shape, README skeleton, DocC catalog skeleton, `.github/metadata.yaml` shape)
- Per-action authorization gates: tag, visibility flip, post-flip metadata sync, post-flip sidebar verification, post-flip CI matrix dispatch
- Optional [RELEASE-013] first-publication clean-history per package

**Out of scope**:
- Launch blog publish (per principal direction in the Pair brief)
- swift-institute.org deploy of launch posts
- Either's already-shipped state (do NOT retag or re-flip)
- Codable existential-throws issue on Product (DEFERRED — stdlib limitation; tracked in `swift-product-primitives/Audits/audit.md`)
- Re-deliberation of any locked decisions enumerated in §Locked Decisions below

## Skills to Load

| Skill | Purpose |
|---|---|
| **release-readiness** | Phase structure, [RELEASE-001a] private-repo substitution, [RELEASE-001b] full-lint baseline, [RELEASE-009] WIP grep, [RELEASE-010] tracked-artifact grep, [RELEASE-011] post-flip metadata sync, [RELEASE-012] sidebar UI checklist, [RELEASE-013] clean-history option |
| **git-operations** | [GIT-001] push policy, [GIT-003] visibility-flip command, [GIT-008] force-push auth, [GIT-009] Actions-enabled pre-check |
| **github-repository** | [GH-REPO-054] sidebar default state, [GH-REPO-060] metadata.yaml schema, [GH-REPO-070+] centralized sync |
| **readme** | [README-009] code-example validity, [README-022] Architecture section, [README-170] composed-example matrix |
| **ci-cd-workflows** | [CI-093] swift-format invocation discipline, [CI-054] developer-contract for lint, [CI-055] swift-format config rules |
| **audit** | [AUDIT-002] tracking policy, [AUDIT-006] empirical-evidence requirement, [AUDIT-027] severity scaling, [AUDIT-033] positive-claim verification |
| **documentation** | [DOC-*] DocC catalog conventions |
| **social-preview** | Per-package README badge / GitHub social-card; verify at flip |
| **swift-package** | Package.swift conventions |
| **swift-package-build** | [PKG-BUILD-007] Embedded source-guard pattern; [PKG-BUILD-008] Embedded build invocation |

## Per-Package State

### 1. swift-either-primitives — ALREADY PUBLIC

**State**: Public on swift-primitives org. 5-commit history. Last commit: `828d87f Either: switch deps to URL form for post-publication CI`.

**Pattern this package establishes** (canonical for the cohort):
- File layout: stdlib conformances + type declaration in `Either.swift`; each institute-protocol conformance in its own per-protocol file (`Equation.Protocol+Either.swift`, `Hash.Protocol+Either.swift`, `Comparison.Protocol+Either.swift`) under `Sources/Either Primitives/`.
- Stdlib `Equatable` / `Hashable` conformance shape in `Either.swift`:
  ```swift
  #if compiler(>=6.4)
      extension Either: Equatable where Left: Equatable & ~Copyable, Right: Equatable & ~Copyable {
          @inlinable
          public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool { /* manual */ }
      }
      extension Either: Hashable where Left: Hashable & ~Copyable, Right: Hashable & ~Copyable {
          @inlinable
          public borrowing func hash(into hasher: inout Hasher) { /* manual */ }
      }
  #else
      extension Either: Equatable where Left: Equatable, Right: Equatable {}
      extension Either: Hashable where Left: Hashable, Right: Hashable {}
  #endif
  ```
- Institute conformance shape per file (one per protocol):
  ```swift
  #if swift(<6.4)
      public import Equation_Primitives
      extension Either: Equation.`Protocol`
      where Left: Equation.`Protocol` & ~Copyable, Right: Equation.`Protocol` & ~Copyable {
          @inlinable
          @_disfavoredOverload
          public static func == (lhs: borrowing Either, rhs: borrowing Either) -> Bool { /* manual */ }
      }
  #endif
  ```

**Why the per-branch shape on stdlib**: enum-derived `==` synthesis matches cases via a `(Self, Self)` tuple which is rejected for `~Copyable` Self, so Either provides a manual `borrowing ==` and `borrowing hash` on the 6.4+ branch.

**Why the institute conformance is `#if swift(<6.4)` only**: on 6.4+, `Equation.Protocol === Swift.Equatable` via SE-0499 typealias; an unconditional institute conformance would be a duplicate-conformance error against the stdlib conformance. Either's commit `df290e3 Either: canary fix for double-conformance pattern across institute-protocol bridges` is the precedent; the canonical guard pattern matches `swift-equation-primitives/Sources/Equation Primitives/Equation.Protocol+Tagged.swift`.

**Action for next agent**: do NOT retag. Verify via `gh repo view` that visibility is still public; verify `gh repo view --json description,homepageUrl,repositoryTopics` matches `.github/metadata.yaml`. Cross-check that any pattern Pair / Product adopt is sourced from Either, not invented.

### 2. swift-pair-primitives — AT GO, AWAITING TAG + FLIP

**State**: Private on swift-primitives org. Single commit history (`ff5903c Initial commit, extracted from swift-algebra-primitives`). Substantial session work in working tree.

**Brief**: `swift-pair-primitives/AUDIT-0.1.0-release-readiness.md` (gitignored, recommendation: GO).

**Audit**: `swift-pair-primitives/Audits/audit.md` (0 CRITICAL/HIGH/MEDIUM, 1 LOW swift-testing macro quirk with workaround).

**Working-tree changes pending commit**:
- `Package.swift` — three new institute deps (`swift-equation-primitives`, `swift-hash-primitives`, `swift-comparison-primitives`)
- `Sources/Pair Primitives/Pair.swift` — major restructure: method renames (`mapFirst` → `map(first:)`, `mapSecond` → `map(second:)`, `bimap` → `map(first:second:)`), `allFirsts` deletion, three institute-protocol conformances, Comparable lexicographic
- `Tests/Pair Primitives Tests/Pair Tests.swift` — call-site renames + 9 new tests for Comparable + ~Copyable Equation/Hash/Comparison.Protocol (30 tests passing)
- `README.md` — updated for new method shape, three deps, `~Copyable` flow paragraph
- `Sources/Pair Primitives/Pair Primitives.docc/Pair Primitives.md` — DocC catalog updated
- `.swift-format` — `AmbiguousTrailingClosureOverload: false` (package-local exception per [API-NAME-008] decision; see §Locked Decisions)
- New `Research/` directory:
  - `property-primitives-api-design.md` (DECISION v1.2.0) — Option C labeled-method shape with experiment-verified Property.View blockers
  - `pair-prior-art-survey.md` (REFERENCE v1.1.0) — Tier 2 prior-art survey
  - `equation-hash-comparison-protocol-adoption.md` (DECISION v1.2.0) — institute-protocol adoption rationale + corrected hybrid shape
  - `_index.json`
- New `Experiments/property-view-pair-attempt/` — 5-variant package empirically refuting Property.View adoption for `Pair`

**⚠️ Pair conformance shape diverges from Either** (next-agent action):

Pair's current shape (different from Either's canonical):
```swift
// Pair (current, non-canonical): institute UNCONDITIONAL, stdlib `#if swift(<6.4)` only
#if swift(<6.4)
    extension Pair: Equatable where First: Equatable, Second: Equatable {}
    extension Pair: Hashable where First: Hashable, Second: Hashable {}
    extension Pair: Comparable where First: Comparable, Second: Comparable { @inlinable static func <(...) }
#endif

extension Pair: Equation.`Protocol` where First: Equation.`Protocol` & ~Copyable, ... { @_disfavoredOverload borrowing == }
extension Pair: Hash.`Protocol` where First: Hash.`Protocol` & ~Copyable, ... { @_disfavoredOverload borrowing hash }
extension Pair: Comparison.`Protocol` where First: Comparison.`Protocol` & ~Copyable, ... { @_disfavoredOverload borrowing < }
```

Both arms work empirically (verified on 6.3.1 + 6.4-dev DEVELOPMENT-SNAPSHOT-2026-03-16-a; 30 tests pass on both, Embedded build clean on 6.4-dev), but the pattern is INVERTED relative to Either / Product. **Recommended next-agent task**: refactor Pair to match Either's canonical pattern:

1. In `Pair.swift`, replace the current shape with:
   ```swift
   #if compiler(>=6.4)
       extension Pair: Equatable where First: Equatable & ~Copyable, Second: Equatable & ~Copyable {
           @inlinable
           public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
               lhs.first == rhs.first && lhs.second == rhs.second
           }
       }
       extension Pair: Hashable where First: Hashable & ~Copyable, Second: Hashable & ~Copyable {
           @inlinable
           public borrowing func hash(into hasher: inout Hasher) {
               first.hash(into: &hasher)
               second.hash(into: &hasher)
           }
       }
       extension Pair: Comparable where First: Comparable & ~Copyable, Second: Comparable & ~Copyable {
           @inlinable
           public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool { /* lexicographic */ }
       }
   #else
       extension Pair: Equatable where First: Equatable, Second: Equatable {}
       extension Pair: Hashable where First: Hashable, Second: Hashable {}
       extension Pair: Comparable where First: Comparable, Second: Comparable {
           @inlinable
           public static func < (lhs: Self, rhs: Self) -> Bool { /* lexicographic */ }
       }
   #endif
   ```

   Note: Pair's `Equatable` / `Hashable` synthesis works for the Copyable case unlike Either (struct vs enum), so the `#else` branch can be empty bodies — Swift synthesizes `==` and `hash(into:)` from the stored properties. Comparable is never synthesized; explicit `<` always.

2. Move the three institute-protocol conformance extensions out of `Pair.swift` into per-protocol files matching Either's layout:
   - `Sources/Pair Primitives/Equation.Protocol+Pair.swift`
   - `Sources/Pair Primitives/Hash.Protocol+Pair.swift`
   - `Sources/Pair Primitives/Comparison.Protocol+Pair.swift`

   Each guarded `#if swift(<6.4) ... public import <Pkg>_Primitives ... extension Pair: <Pkg>.\`Protocol\` ... @_disfavoredOverload borrowing impl ... #endif`.

3. Verify both build paths after refactor:
   - `swift build && swift test` on Swift 6.3.1 macOS — expect 30 tests passing
   - `TOOLCHAINS=org.swift.64202603161a swift build -Xswiftc -enable-experimental-feature -Xswiftc Embedded` — expect clean

4. Update `Research/equation-hash-comparison-protocol-adoption.md` v1.3.0 changelog: align with Either canonical pattern; note refactor reason ("on-par with `swift-either-primitives` per cross-cohort consistency").

5. Re-run swift-format + swiftlint after refactor.

**Stage 1 (tag) preconditions remaining**:
- Working-tree commit (NORMAL ask-first per CLAUDE.md). Suggested commit shape: one composite "Initial publication of swift-pair-primitives — labeled-method API, ~Copyable institute-protocol adoption, Comparable" OR sequenced commits per `git-operations` convention.
- README install snippet `branch: "main"` → `from: "0.1.0"` switch at tag time.

**Stage 2 (visibility flip) preconditions per [RELEASE-004a]**: verify five external repos' visibility before flip:
- `swift-primitives/swift-equation-primitives` (institute dep)
- `swift-primitives/swift-hash-primitives` (institute dep)
- `swift-primitives/swift-comparison-primitives` (institute dep)
- `swift-primitives/.github` (CI reusable: `swift-primitives/.github/.github/workflows/swift-ci.yml@main`)
- `swift-institute/.github` (CI reusable: `swift-institute/.github/.github/workflows/swift-docs.yml@main`)

Each its own per-action authorization; bundling under Pair's flip would conflate decisions across repos.

### 3. swift-product-primitives — AT CONDITIONAL GO, AWAITING TAG + FLIP

**State**: Private on swift-primitives org. Eight-commit history culminating in `b6d5eb7 Fix README Quick Start example to use Comparable elements only.`. Working tree clean.

**Brief**: `swift-product-primitives/AUDIT-0.1.0-release-readiness.md` (recommendation: CONDITIONAL GO — accept-as-known: Codable existential-throws stdlib limitation).

**Audit**: `swift-product-primitives/Audits/audit.md` — 1 MEDIUM finding DEFERRED:
> [API-ERR-006] Codable witnesses use `throws(any Swift.Error)` (explicit existential). Reverting to bare `throws` is also existential and violates [API-ERR-001]; the only fully compliant path is dropping Codable conformance. The polish chose the explicit form to surface the protocol-witness contract at the API. **DEFERRED** — stdlib Codable's protocol contract is `func encode(to:) throws` (untyped); any conforming witness inherits the existential. The package cannot satisfy [API-ERR-006] strictly without dropping Codable. Re-evaluate if stdlib amends Codable to support typed throws (no SE proposal currently in flight).

**Type shape**: `Product<each Element>` — n-ary cartesian product via parameter packs. Copyable-only (Swift 6.3 parameter packs do not admit `~Copyable each T` — confirmed by Stream B prior-art survey on Pair). `@dynamicMemberLookup` for `product.0` / `product.1` access.

**Conformance pattern**: per-protocol-file layout matching Either:
- `Product.swift` — type declaration + Sendable conformance
- `Product+Equatable.swift` — stdlib Equatable (unconditional, no `& ~Copyable` since Product is Copyable-only)
- `Product+Equation.Protocol.swift` — institute Equation.Protocol guarded `#if swift(<6.4)`
- `Product+Comparison.Protocol.swift` — institute Comparison.Protocol guarded `#if swift(<6.4)`
- `Product+Encodable.swift` / `Product+Decodable.swift` — Codable witnesses (with the [API-ERR-006] DEFERRED finding)
- `Product+Map.swift`, `Product+Fold.swift`, `Product+Swap.swift`, `Product+Zip.swift` — operations
- `Product+CustomStringConvertible.swift`

**Action for next agent**:
1. Re-run [RELEASE-001b] full Phase 0 baseline (the brief was authored before the rule was codified; verify swift-format strict + swiftlint strict + 6.3.1 build/test all clean)
2. [RELEASE-007] empirical example-compile gate on README + DocC code blocks
3. CONDITIONAL GO acceptance: confirm with principal that the [API-ERR-006] Codable DEFERRED is acceptable for 0.1.0 publication. The brief already documents the deferral; principal need only acknowledge.
4. Stage 1 + Stage 2 per-action gates (same shape as Pair).

## Locked Decisions (Do NOT Re-Deliberate)

These are final per the originating research / decisions / principal direction. The next agent MUST NOT reopen them; if they appear ambiguous, the citation in the package's `Research/` is the authority.

### Cross-package

| Decision | Source |
|---|---|
| Adopt `Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol` for `~Copyable`-aware equality / hashing / ordering on 6.3 | `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` v1.3.0 |
| Per-branch constraint shape on 6.4+ stdlib conformances (`& ~Copyable`) | `swift-tagged-primitives/Tagged.swift §SE-0499`; cited in Either.swift line 106 |
| `@_disfavoredOverload` on borrowing impls in institute conformances | `swift-equation-primitives/.../Equation.Protocol+Tagged.swift` |
| Institute conformance gated `#if swift(<6.4)` to avoid duplicate-conformance error on 6.4+ | Either canary fix `df290e3` |
| Per-protocol-file layout for institute conformances (separate file per protocol) | Either's file structure |
| `@_exported public import` of three institute-primitives products | Either's Package.swift; Pair / Product follow |
| Each package depends on three: `swift-equation-primitives`, `swift-hash-primitives`, `swift-comparison-primitives` | Established by Either, Pair, Product alike |
| Pre-1.0 development pace (method renames in scope, not breaking) | Principal direction; CLAUDE.md "during development, correctness is sole driver of split/reshape/extraction decisions" |

### Pair-specific

| Decision | Source |
|---|---|
| Option C: labeled-method shape `map(first:)` / `map(second:)` / `map(first:second:)` (NOT Property.View) | `swift-pair-primitives/Research/property-primitives-api-design.md` v1.2.0 (DECISION) |
| `swapped()` consuming, `apply` consuming — unchanged | Same |
| `allFirsts` deleted (compound + redundant with `First.allCases`) | Same |
| Comparable lexicographic over `(first, second)` | `swift-pair-primitives/Research/equation-hash-comparison-protocol-adoption.md` v1.2.0 |
| `Pair` is a binary nominal struct; do NOT generalize to variadic Tuple (variadic Tuple is Product's job) | `swift-pair-primitives/Research/pair-prior-art-survey.md` v1.1.0 (REFERENCE) |
| `.swift-format` package-local: `AmbiguousTrailingClosureOverload: false` with [API-NAME-008] inline rationale | Phase 0 fix; documented in `Pair.swift` doc-comment on `map(first:)` |
| Property.View / Property.Inout / Property.Consume adoption REJECTED — empirically refuted across 5 variants | `swift-pair-primitives/Experiments/property-view-pair-attempt/` 5-variant experiment |
| Either symmetry deferred to a separate dispatch (do NOT bundle Either renames into Pair publication) | Principal direction (this session) |

### Either-specific

| Decision | Source |
|---|---|
| Already public, do NOT re-flip | `gh repo view` confirms `isPrivate: false` |
| Conformance shape: stdlib in Either.swift with `#if compiler(>=6.4)` dual-branch; institute in per-protocol files with `#if swift(<6.4)` | Either source |
| `Either: Swift.Error where Left: Swift.Error, Right: Swift.Error` — Either as typed-throws transport per SE-0413 | Either.swift line 172 |

### Product-specific

| Decision | Source |
|---|---|
| n-ary variadic `Product<each Element>` — Copyable-only on Swift 6.3 | Type declaration in `Product.swift`; constraint of parameter packs in 6.3 |
| `@dynamicMemberLookup` subscript for `product.0` / `product.1` | `Product.swift`; brief commit `be4895b Move dynamic-member-lookup subscript out of Product type body.` |
| Codable existential-throws DEFERRED — stdlib limitation | `swift-product-primitives/Audits/audit.md` finding #2 |
| Per-protocol-file layout matches Either | Source |

## Empirical Findings From Pair Session (Apply to Pair / Product Final Pass)

These are non-obvious gotchas the next agent will encounter. Surfacing pre-emptively to avoid rediscovery cost.

### F1 — swift-format `AmbiguousTrailingClosureOverload` conflicts with [API-NAME-008]

The strict-mode swift-format rule `AmbiguousTrailingClosureOverload` flags `map(first:)` / `map(second:)` overloads as ambiguous (the compiler agrees: `pair.map { ... }` errors with `ambiguous use of 'map'` and points the user at the labels). Per Stream A's resolved Q1 (`Research/property-primitives-api-design.md`), the labeled-method shape with forced labels IS the intended design.

**Resolution applied on Pair**: `.swift-format` package-local override `"AmbiguousTrailingClosureOverload": false`, with inline doc-comment on `map(first:)` explaining the [API-NAME-008] rationale.

**Per-decl `// swift-format-ignore: AmbiguousTrailingClosureOverload` does NOT work** — the rule fires at the overload-set level (across the extension), not per-declaration. The package-local config override is the only mechanism.

**Either is unaffected** — Either's `.left(...) == .right(...)` shape is enum-case constructor, not method-overload, so swift-format doesn't fire this rule.

**Product is unaffected** — Product has only one `==` per branch (variadic `repeat each`), not multiple labeled overloads.

### F2 — swift-testing `#expect(a < b)` macro can't disambiguate Comparison.Protocol

On Swift 6.3.1 with Comparison.Protocol-only conformers (e.g., `Pair<MoveOnlyOrdered, MoveOnlyOrdered>`), the `#expect(a < b)` macro's overload resolution prefers the `BidirectionalCollection` overload of `__checkBinaryOperation`, producing `error: ... requires that '<Type>' conform to 'BidirectionalCollection'`.

**Workaround**: assign to `Bool` first.

```swift
let result: Bool = a < b
#expect(result)
```

Applied in 2 Pair test sites for `~Copyable Pair<MoveOnlyOrdered, ...>`. Not a Pair defect; affects any institute-Comparison.Protocol-only conformer in `#expect(... < ...)` form.

### F3 — DOUBLE-CONFORMANCE error on Swift 6.4-dev for unconditional dual conformances

If a type has BOTH unconditional stdlib `Equatable` AND unconditional institute `Equation.Protocol` extensions with different where-clauses:
```swift
extension Pair: Equatable where First: Equatable, Second: Equatable {}
extension Pair: Equation.`Protocol` where First: Equation.`Protocol` & ~Copyable, Second: Equation.`Protocol` & ~Copyable {}
```

Swift 6.4-dev rejects with:
> `conflicting conformance of 'Pair<First, Second>' to protocol 'Comparable'; there cannot be more than one conformance, even with different conditional bounds`

The user's earlier "guards unneeded" claim does NOT hold for Pair specifically. The empirically-correct fix is one of two patterns:
- **Either / Product canonical**: stdlib unconditional with `#if compiler(>=6.4)/#else` branched where-clauses; institute `#if swift(<6.4)` only.
- **Pair (my work, non-canonical but functional)**: institute unconditional; stdlib `#if swift(<6.4)` only.

Both work; Either's pattern is the cohort baseline. Pair refactor recommended (per §swift-pair-primitives action 1–5).

### F4 — Pair Embedded build requires Swift 6.4-dev nightly per [PKG-BUILD-008]

The L1 Embedded check in [RELEASE-001b] requires Swift 6.4-dev nightly:
```sh
TOOLCHAINS=org.swift.64202603161a swift build -Xswiftc -enable-experimental-feature -Xswiftc Embedded
```

**Toolchain bundle ID resolution**: `defaults read /Users/coen/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a.xctoolchain/Info CFBundleIdentifier` → `org.swift.64202603161a`.

**Critical**: `xcrun --toolchain '<snapshot-name>' swift build` does NOT redirect SwiftPM's stdlib resolution; SwiftPM continues to use the Xcode SDK's stdlib `.swiftinterface`. Use the `TOOLCHAINS` env var with bundle ID to redirect properly. Documented in `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` v1.3.0 footnote.

### F5 — swift-format must come from Xcode toolchain, not Homebrew per [CI-093]

```sh
xcrun swift-format lint --strict --recursive Sources/ Tests/
```

Resolves to `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format` (Apple swift-format 6.3.0 on current Xcode 26.4.1). Homebrew's `--HEAD` build mangles `nonisolated(nonsending)` per [CI-093] memory; institute uses Xcode toolchain.

### F6 — `git ls-files | grep` for tracked-artifact violations per [RELEASE-010]

Run BEFORE Phase 0 baseline:
```sh
git ls-files | grep -E '^Audits/|^AUDIT-.*\.md$|\.swiftpm/.*xcuserdata|\.build/|DerivedData/|\.DS_Store$|/\.DS_Store$'
```

Pair / Product / Either canonical `.gitignore` (synced via `swift-institute/Scripts/sync-gitignore.sh`) blocks new additions of these patterns, but pre-existing tracked files persist. Surface and untrack with `git rm --cached <file>` if any matches.

### F7 — [RELEASE-009] WIP commit grep BEFORE treating HEAD as Phase 0 baseline

```sh
git log --oneline -20 | grep -iE "save progress|wip|tmp|temp|fix later|todo|scratch"
```

If any match: re-run `swift build` + `swift test` + `swift-format lint` + `swiftlint lint` from a clean tree. Pair single-commit history is clean. Product has 8 commits — verify none match. Either has 5 commits (post-publication; matters less).

### F8 — Pair extracted from `swift-algebra-primitives`; original may have residual references

Pair was extracted from `swift-algebra-primitives` (commit message: `Initial commit, extracted from swift-algebra-primitives`). Verify `swift-algebra-primitives` no longer imports the original `Pair` (Pair is now its own package and re-imported via `import Pair_Primitives`). The extraction has already been done; this is a verification step at flip time.

```sh
grep -rn "import Pair" /Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/
```

Should resolve to `import Pair_Primitives` (the new package), not internal Pair references.

### F9 — Pair has 5 consumers in the workspace (algebra/finite/region/symmetry/compass-primitives)

```sh
grep -rln "import Pair_Primitives" /Users/coen/Developer/swift-primitives/swift-{algebra,finite,region,symmetry}-primitives/Sources/
```

Stream A's consumer survey confirmed **zero call sites** invoke any of Pair's transformation methods (`map`, `mapFirst`, `mapSecond`, `bimap`, `swapped`, `apply`, `tuple`, `allFirsts`); consumers use Pair only as a **typealias target** (e.g., `typealias Quadrant = Pair<Vertical, Horizontal>`). Method renames + `allFirsts` deletion are **zero-call-site-affecting**; consumer-package CI will be unaffected by the rename.

## Per-Action Authorization Workflow

Each action below is its own per-action authorization at the moment of execution per [RELEASE-004]. Bundling is forbidden; each `YES DO NOW` covers one specific action.

### Pair sequence

1. **Pre-tag commit** (NORMAL ask-first per CLAUDE.md) — composite or sequenced; recommend sequenced for review-trail discipline:
   - Commit 1: "Pair: rename to labeled-method API; delete allFirsts; update tests + README + DocC"
   - Commit 2: "Pair: adopt Equation.Protocol / Hash.Protocol / Comparison.Protocol; add Comparable lexicographic"
   - Commit 3: "Pair: align conformance file layout with Either canonical (per-protocol files)" *— if next agent does the §1–5 refactor*
   - Commit 4: "Pair: research + experiment artifacts (3 docs, 5-variant experiment)"
   - Commit 5: "Pair: AmbiguousTrailingClosureOverload package-local override"
2. **README install snippet switch**: `branch: "main"` → `from: "0.1.0"` (bundle with the last commit before tag)
3. **`YES DO NOW TAG`**: `git tag 0.1.0 -m "Pair Primitives 0.1.0" && git push --tags origin main`
4. **Verify five prerequisite repos public** per [RELEASE-004a] (each its own auth):
   - `gh repo view swift-primitives/swift-equation-primitives --json visibility`
   - `gh repo view swift-primitives/swift-hash-primitives --json visibility`
   - `gh repo view swift-primitives/swift-comparison-primitives --json visibility`
   - `gh repo view swift-primitives/.github --json visibility`
   - `gh repo view swift-institute/.github --json visibility`
5. **`YES DO NOW PUBLIC`**: `gh repo edit swift-primitives/swift-pair-primitives --visibility public --accept-visibility-change-consequences`
6. **Post-flip metadata sync** per [RELEASE-011] (immediate, not deferred): diff `gh repo view --json description,homepageUrl,repositoryTopics` vs `.github/metadata.yaml`; apply via `gh repo edit ... --description "..." --homepage "..." --add-topic ... --remove-topic ...`
7. **Post-flip sidebar verification** per [RELEASE-012] (manual UI): open `https://github.com/swift-primitives/swift-pair-primitives` → gear icon → Releases ☑ / Packages ☐ / Deployments ☐
8. **Post-flip CI matrix dispatch** per [RELEASE-001a] step (c): after [GIT-009] enabled-check (`gh api /repos/swift-primitives/swift-pair-primitives/actions/permissions` → `enabled: true`), dispatch the deferred Linux Docker + 6.4-dev nightly matrix entries via the next-push-triggered run (no manual dispatch needed)
9. **Optional `YES DO NOW SQUASH`** per [RELEASE-013] for first-publication clean-history (squash to `Initial publication of swift-pair-primitives` + force-push with `--force-with-lease`). Pair's session work is many commits if sequenced per #1; squash optional based on principal preference for image vs transparency.

### Product sequence

Same shape as Pair, with two differences:
- No conformance refactor (Product already canonical)
- CONDITIONAL GO acceptance step: principal acknowledgment of the [API-ERR-006] Codable DEFERRED before Stage 1

### Either sequence

Already shipped. Verify post-publication state holds:
- `gh repo view swift-primitives/swift-either-primitives --json visibility` → `PUBLIC`
- `gh repo view swift-primitives/swift-either-primitives --json description,homepageUrl,repositoryTopics` matches `.github/metadata.yaml`
- Sidebar state per [RELEASE-012]
- No retag, no re-flip, no force-push

## Handoff Communication

The next agent MUST surface inline at each Phase boundary. Do NOT silently progress; the principal needs visibility into:
1. Phase 0 baseline result (each [RELEASE-001b] check passing)
2. Any drift discovered between Pair's working tree and Either's canonical pattern
3. Each `YES DO NOW` request — bare command, what it does, what's after it
4. Any destructive action (force-push, run-deletion, squash) — explicit auth before executing

The next agent MUST NOT:
- Bundle multiple per-action authorizations under one `YES DO NOW`
- Deploy or publish the launch blog (out of scope)
- Re-deliberate locked decisions
- Modify Either's already-public state

## File Inventory (Recently Touched)

### swift-pair-primitives (working tree dirty; uncommitted)

| File | State |
|---|---|
| `Package.swift` | M — three institute deps added |
| `Sources/Pair Primitives/Pair.swift` | M — major restructure |
| `Tests/Pair Primitives Tests/Pair Tests.swift` | M — call-site renames + 9 new tests |
| `README.md` | M — updated for new shape |
| `Sources/Pair Primitives/Pair Primitives.docc/Pair Primitives.md` | M — DocC catalog updated |
| `.swift-format` | M — `AmbiguousTrailingClosureOverload: false` |
| `Research/property-primitives-api-design.md` | NEW (DECISION v1.2.0) |
| `Research/pair-prior-art-survey.md` | NEW (REFERENCE v1.1.0) |
| `Research/equation-hash-comparison-protocol-adoption.md` | NEW (DECISION v1.2.0) |
| `Research/_index.json` | NEW |
| `Experiments/property-view-pair-attempt/` | NEW — 5-variant package |
| `Audits/audit.md` | NEW (gitignored) |
| `AUDIT-0.1.0-release-readiness.md` | NEW (gitignored) |

### swift-product-primitives (working tree clean; 8 commits)

| File | State |
|---|---|
| `AUDIT-0.1.0-release-readiness.md` | Committed (last cycle); recommendation CONDITIONAL GO |
| `Audits/audit.md` | Committed (last cycle); 1 MEDIUM DEFERRED |
| `Research/` | Committed; multiple docs informing API design |
| `Experiments/product-binary-arity-extension-shapes/` | Committed |

### swift-either-primitives (already public; 5 commits)

| File | State |
|---|---|
| `Sources/Either Primitives/Either.swift` | Canonical conformance pattern source |
| `Sources/Either Primitives/{Equation,Hash,Comparison}.Protocol+Either.swift` | Canonical per-protocol file layout |

## References

- `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` v1.3.0 — ecosystem-wide canonical institute-protocol adoption pattern
- `swift-pair-primitives/AUDIT-0.1.0-release-readiness.md` — Pair brief (GO)
- `swift-pair-primitives/Audits/audit.md` — Pair audit findings
- `swift-pair-primitives/Research/property-primitives-api-design.md` v1.2.0 — Pair API design DECISION
- `swift-pair-primitives/Research/pair-prior-art-survey.md` v1.1.0 — Pair prior-art reference
- `swift-pair-primitives/Research/equation-hash-comparison-protocol-adoption.md` v1.2.0 — Pair institute-protocol adoption DECISION
- `swift-pair-primitives/Experiments/property-view-pair-attempt/README.md` — 5-variant Property.View refutation
- `swift-product-primitives/AUDIT-0.1.0-release-readiness.md` — Product brief (CONDITIONAL GO)
- `swift-product-primitives/Audits/audit.md` — Product audit findings (1 MEDIUM DEFERRED)
- `swift-either-primitives/Sources/Either Primitives/Either.swift` — canonical conformance pattern
- `swift-equation-primitives/Sources/Equation Primitives/Equation.Protocol+Tagged.swift` — canonical institute conformance adopter
- Skills: **release-readiness**, **git-operations**, **github-repository**, **readme**, **ci-cd-workflows**, **audit**, **documentation**, **social-preview**, **swift-package**, **swift-package-build**

## Workspace Constraints

- Repos are PRIVATE on swift-primitives org until flipped per [RELEASE-004]; CI on private repos does NOT run on the GitHub Free plan (workspace billing constraint per `feedback_private_repos_no_ci_runs` + `feedback_free_plan_private_ci_unrunnable`). [RELEASE-001a] private-repo substitution applies until flip.
- Workspace toolchain pins per `feedback_toolchain_versions.md`: Swift 6.3.1 (Xcode default) + Swift 6.4-dev nightly. No 6.1, no other versions.
- "Publication" preferred over "release" in consumer-facing prose (commit messages, READMEs, announcement copy) per principal direction.
- Workspace has NO `gh auth refresh -s admin:org` capability; admin-class GitHub ops via web UI only per `feedback_no_gh_cli_admin_scope.md`. Branch-protection / org-settings / repo-settings (issues/discussions/wiki toggles) are manual-UI work.
