# Typed-Primitive Adoption Audit Addendum — Ambiguous-Finding Triage

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

This addendum disposes the 11 Ambiguous findings the v1.0.0 TRIAGE at
`2026-05-12-typed-primitive-adoption-audit.md` left for principal
review. The v1.0.0 Real Gap findings (22) have been remediated in
Phases 0–3; the v1.0.0 Ambiguous classifications themselves are
preserved unchanged. Each finding receives a disposition — Real-Gap-
promote / Acceptable / Defer — drawn from the handoff brief
`HANDOFF-audit-ambiguous-triage.md` and grounded in the current code
state plus the [ARCH-LAYER-*] layering rules and the available L1
typed primitives. Verification per `[HANDOFF-013a]`: this is a
sibling document to the v1.0.0 TRIAGE; no prior addendum exists; the
findings table below is the new artifact, not a re-derivation.

## Per-finding triage

### F-A2.7 — Extractor boundary parameters

**Disposition**: Acceptable

**Rationale**: The boundary judgement the audit flagged has already
landed in Phase 2. `Lint.SingleFile.Extractor.swift:50–54` and
`:129–132` declare `sourcePath: File.Path` and `consumerPackageRoot:
File.Path`; `extractStringLiteral(_:sourcePath:)` (`:214–217`) and
`packageName(fromPath:consumerPackageRoot:)` (`:273–276`) take typed
`File.Path` for the boundary parameters while keeping `Swift.String`
on parameters whose values originate from `SwiftSyntax` AST
extraction (`source:`, `fromPath path:`). The doc comment at
`:43–49` records the boundary decision explicitly: "the boundary in
this Phase 2 pass moves toward `File.Path` to keep the artery typed
end-to-end; AST-extracted string literals (which genuinely originate
as `Swift.String` from SwiftSyntax) remain `Swift.String` and are not
retyped here." The finding is settled in code; the remaining
`Swift.String` parameters are at the SwiftSyntax boundary and stay.

**Action**: No action — the boundary judgement is recorded in code.

### F-A2.10 — `Lint.Dependency.package(path:…)` factory arguments

**Disposition**: Acceptable → **Superseded by Thread G** (2026-05-13)

**Rationale (original Acceptable disposition)**: `Lint.Dependency`
(`Lint.Dependency.swift:36–84`) is the consumer-facing public API
a user writes in their `Lint.swift`. The factory shapes —
`package(path:products:)`, `package(url:from:products:)`,
`package(url:_:_:products:)` — mirror SwiftPM's own
`PackageDescription.Package.Dependency.package(...)` API verbatim,
and SwiftPM ships those factories with `String`-typed arguments.
The `path:` and `url:` values are code-generation literals: the
audit's brief framing ("code-gen literal vs path-shaped data")
resolves to code-gen — the consumer's literal source text is
parsed from their `Lint.swift` and re-emitted into the generated
eval `Package.swift`. Re-typing the public API surface above the
underlying spec adds friction for consumers (they would have to
opt out of the `.package(path: "...")` literal they already write
everywhere) without buying type-safety the emit-path can use.

**Thread G supersession (2026-05-13)**: the Acceptable disposition
held only as long as the SLI conformance gap held. With Phase G.0
adding `ExpressibleByStringLiteral` conformances on
`Version.Semantic`, `Version.Tools`, `URI` (via
`URI Standard Library Integration`), and confirming `File.Path` +
`Product.Name` already carry their SLI shapes, the consumer-side
friction the original rationale weighed against disappears.
Consumers continue to write
`.package(path: "../foo", from: "1.0.0", products: ["Bar"])` —
the SLI layer reads each literal as the typed primitive at compile
time. Phase G.1 promoted the public DSL to typed primitives:

```swift
public enum Kind: Swift.Sendable {
    case path(File.Path)
    case url(URI, from: Version.Semantic)
    case urlRange(URI, Version.Range<Version.Semantic>)
}
```

The `urlRange` factory collapses the two prior positional version
literals into one `Swift.Range<Version.Semantic>` operand —
consumers write `"602.0.0"..<"603.0.0"` and the typed range
flows through. The Extractor was updated in lockstep to recognise
the `..<` range expression in consumer `Lint.swift` files.

**Action**: F-A2.10 closed at Thread G commit `89c3a1a`
(typed-primitive adoption + Extractor cascade `4115414`).

### F-A2.11 — `Lint.SingleFile.PackageDependency.name`

**Disposition**: Defer

**Rationale**: `PackageDependency.name` (`:38`) and `products`
(`:41`) at `Lint.SingleFile.PackageDependency.swift` are SwiftPM-
identifier-shaped values: `name` is a SwiftPM package identifier
("swift-primitives-linter-rules"); `products` is a list of SwiftPM
product identifiers ("Linter Primitives Rules"). The audit's
"covered by Axis 3 for `name`" annotation routes the disposition
through F-A3.4/F-A3.5 — and those, in turn, await typed primitives
`Tagged<SwiftPM.Package, Swift.String>` and `Tagged<SwiftPM.Product,
Swift.String>` that do not yet exist anywhere in the ecosystem (no
`swift-swiftpm-primitives` package). Until those primitives land,
the raw-`String` shape is the only available form.

**Action**: Surface as design question — see Outcome (Deferred /
primitives-gap).

### F-A2.12 — `Lint.SingleFile.Materializer.resolveConsumerPath`

**Disposition**: Acceptable

**Rationale**: `resolveConsumerPath(_ consumerPath: Swift.String,
relativeRoot: Swift.String) -> Swift.String`
(`Lint.SingleFile.Materializer.swift:203–207`) is a code-gen helper:
its return value is the path-string that gets emitted INTO a
generated `.package(path: "X")` literal in the eval `Package.swift`
source text. The function's body already uses `File.Path` for the
arithmetic (per the audit's "positive baseline; body already typed"
note and the doc-comment block at `:183–202`); the boundary stays
`Swift.String` because the destination is source code, not a
filesystem-resolved path. Typing the boundary would force a
`File.Path → Swift.String` round-trip at emit-time and offer no
end-to-end-typed artery (the artery ends at quoted-string source
text by design).

**Action**: No action — code-gen output; boundary already at the
right line.

### F-A2.13 — already promoted (Real Gap, remediated)

Not in scope for this addendum — listed only for the reader: the
audit classified F-A2.13 (Lint.SingleFile.Error path payloads) as
Real Gap, not Ambiguous; remediation landed in Phases 0–3.

### F-A2.15 — L1 `Lint.Configuration.Error` path payloads

**Disposition**: Acceptable

**Rationale**: See "Architecturally-interesting calls" below for
the full discussion. Short form: the error sits at L1
(`swift-linter-primitives`); `File.Path` lives at L3
(`swift-foundations/swift-paths`) so the natural typed shape
inverts the layer order; the L1 `Path_Primitives.Path` is
`~Copyable` and so cannot back a `Hashable, Sendable` error
payload; a `Tagged<Lint.Configuration, Swift.String>` wrapper adds
nominal type identity without semantic path operations and conflicts
with the within-package precedent of `Diagnostic.Record.identifier:
Swift.String` (the same primitives package already accepts raw
`String` for path-shaped diagnostic data). Keep `Swift.String`.

**Action**: No action — layer-bound and precedent-bound.

### F-A2.17 — Test-fixture UUID-keyed temporary directory

**Disposition**: Defer

**Rationale**: `Lint.Suppression Tests.swift:198–205` writes a UUID-
keyed scaffold via `FileManager.default.temporaryDirectory
.appendingPathComponent("lint-suppression-fixture-\(UUID()
.uuidString)")`. The typed surface
`File.Path.Temporary.deterministic(prefix:key:suffix:)` exists
(`swift-file-system/Sources/File System Core/File.Path.Temporary
.swift:43–59`) but is by design deterministic — same `(prefix, key,
suffix)` triple yields the same `File.Path`, and the internal
`Path.sanitized(from: key)` is built for stable digests, not fresh
UUIDs. Test fixtures need *randomized* scaffolds so concurrent test
runs don't collide on the same path. No `randomized` variant ships
today; adopting `deterministic` here would re-purpose the API
against its documented semantics.

**Action**: Surface as design question — see Outcome (Deferred /
primitives-gap). Proposed primitive: `File.Path.Temporary
.randomized(prefix:suffix:)` (UUID-keyed under the hood) in
`swift-foundations/swift-file-system`.

**Cross-package note (en passant)**: The audit's cross-package
side-note at the end of Axis 2 asserts that
`File.Path.Temporary.deterministic`'s own body raw-concatenates the
path components (`temporaryDirectory + "/" + prefix + sanitizedKey +
suffix`). Verification at addendum-write time
(`File.Path.Temporary.swift:55–58`) shows the body now uses typed
`Path.appending`: `temporaryDirectory.appending(trailing)`. The
note's precondition is resolved; flagging only so the v1.0.0 audit
doc's cross-package side-note does not propagate as a stale claim.

### F-A3.2 — `Lint.Manifest.excludedPaths` JSON wire form

**Disposition**: Acceptable

**Rationale**: The in-memory model is already typed:
`Lint.Manifest.excludedPaths: [File.Path]`
(`Lint.Manifest.swift:76`), set up via the typed initializer
(`:81`). The audit's "ambiguous" framing was about the
deserialization-path local `excludedRaw: [Swift.String]`
(`:116`) — but that binding is transient: the next line
(`:117–126`) immediately lifts each raw string into `File.Path` via
`try File.Path(string)` with explicit `JSON.Error.typeMismatch`
wrapping. The JSON wire format is fixed by the file format
(strings); the in-memory model is typed end-to-end; the local
binding is an unavoidable boundary intermediate that doesn't
survive past the lift.

**Action**: No action — already at the right boundary.

### F-A3.3 — Source-walker include/exclude glob patterns

**Disposition**: **Real-Gap-promote**

**Rationale**: This is the audit-premise-staleness catch. The audit
(2026-05-12 TRIAGE) classified F-A3.3 as Ambiguous on the premise
"no typed `Glob.Pattern` primitive in scope today; `Tagged<Glob,
String>` would carry role." Verification at addendum-write time:
`swift-primitives/swift-glob-primitives/Sources/Glob Primitives/
Glob.Pattern.swift` declares `extension Glob { public struct
Pattern: Sendable, Hashable { ... } }` with `init(_:) throws(Glob
.Error)` and a fully-parsed segment model. The primitive exists at
L1 in the swift-primitives org and predates the audit (file header
`Copyright (c) 2024`). The `includePatterns: [Swift.String]` and
`excludePatterns: [Swift.String]` at `Lint.Source.Walker.swift:30`
and `:38` are static literals that can be parsed once at module
load and lifted to `[Glob.Pattern]`. Adoption cost: Low — declare
the dep `swift-foundations/swift-linter → swift-primitives/swift-
glob-primitives` (layer-clean: L3 → L1) and pivot the two static
lets.

**Action**: Include in the F-A4.3 follow-up dispatch.

**Status update (2026-05-12)**: LANDED. Foundation-first adoption
shape per `[ARCH-LAYER-011]`:
- `swift-glob-primitives@9ba5d4c` — added `Glob Primitives Standard
  Library Integration` target hosting `Glob.Pattern:
  ExpressibleByStringLiteral` so static-let literal sites read as
  `[Glob.Pattern] = ["**/*.swift", ...]` rather than `try!`-laden
  initializers.
- `swift-file-system@4a5206f` — added typed `[Glob.Pattern]`
  overloads to `glob.files` / `glob.directories` / `glob(...)`
  (both sync + async); the existing `[Swift.String]` variants
  retained as parsing conveniences that delegate to the typed form.
- `swift-linter@73fd25e` — `Lint.Source.Walker` static lets pivoted
  to `[Glob.Pattern]`; the call to `directory.glob.files(include:,
  excluding:)` resolves to the typed overload with no string
  round-trip at the match site.

### F-A3.4 — `Lint.Dependency.products: [Swift.String]`

**Disposition**: Defer

**Rationale**: `Lint.Dependency.products` (`Lint.Dependency.swift:
38, 46, 60, 69, 80`) is a list of SwiftPM product identifiers. The
typed shape would be `[Tagged<SwiftPM.Product, Swift.String>]` (or
a dedicated `SwiftPM.Product.ID` typealias mirroring
`Lint.Rule.ID`'s shape) — but no SwiftPM-identifier primitive
exists today in `swift-primitives/`. Forking a one-off
`Tagged<SwiftPM.Product, String>` in this package would (a) duplicate
work the eventual `swift-swiftpm-primitives` package would do, and
(b) carry the layer-discipline cost without delivering the shared
SwiftPM identifier surface that other ecosystem packages would
benefit from. Wait for the primitive.

**Action**: Surface as design question — see Outcome (Deferred /
primitives-gap). Proposed primitive: `SwiftPM.Product.ID =
Tagged<SwiftPM.Product, Swift.String>` in a new `swift-primitives/
swift-swiftpm-primitives` package (or absorption into an existing
package — the package home itself is a design question).

### F-A3.5 — `Lint.SingleFile.PackageDependency` identifier list (duplicate of F-A3.4)

**Disposition**: Defer

**Rationale**: Same shape as F-A3.4 — `name: Swift.String, products:
[Swift.String]` at `Lint.SingleFile.PackageDependency.swift:41, 43`.
This is the resolved-form mirror of `Lint.Dependency`. Adoption
depends on the same `Tagged<SwiftPM.Package, String>` + `Tagged<
SwiftPM.Product, String>` primitives F-A3.4 names.

**Action**: Surface as design question alongside F-A3.4. Both
findings unblock together when the SwiftPM-identifier primitives
land.

### F-A4.2 — `Lint.Visibility.ordinal: Swift.Int`

**Disposition**: Acceptable

**Rationale**: See "Architecturally-interesting calls" below for the
full discussion. Short form: the value's semantic is "rank of access
narrowness" — a 4-case sort-key, neither a position-in-collection
(`Ordinal`) nor a count-of-things (`Cardinal`). The < operator at
`Lint.Visibility.swift:41–43` is the only documented consumer of
`.ordinal`. Adopting `Ordinal` or `Cardinal` for a rank value
over-applies the typed-primitive role and adds dependency surface
without delivering semantic fit. Keep `Swift.Int`. The orthogonal
question — "should `ordinal` be public or internal?" — is API
hygiene, separable from typed-primitive adoption; recorded below.

**Action**: No action on typed-primitive adoption. Optional
follow-up: an API-hygiene pass to tighten `ordinal` to internal
visibility (`<` is the only documented consumer). Not part of the
F-A4.3 dispatch.

## Architecturally-interesting calls

### F-A2.15 — L1 layer-invert vs Tagged-wrapper

**The trade-off**: `Lint.Configuration.Error` (at L1 in
`swift-linter-primitives/Sources/Linter Primitives/Lint
.Configuration.Error.swift`) carries `path: Swift.String` payloads
on three error cases. The audit identified three possible shapes:

1. **`File.Path` payload (layer-invert)** — would invert the L1 → L3
   dependency arrow per `[ARCH-LAYER-001]` because `File.Path` lives
   at L3 in `swift-foundations/swift-paths` (re-exported by
   `swift-file-system`). Rejected on layering grounds.
2. **`Path_Primitives.Path` payload (L1-layer-clean)** — would
   import the L1 `~Copyable` syscall-oriented `Path` from
   `swift-primitives/swift-path-primitives`. Rejected because the
   error type already conforms to `Hashable, Sendable` (line 17);
   `~Copyable` cannot back a `Hashable` payload.
3. **`Tagged<Lint.Configuration, Swift.String>` payload** — would
   add a nominal type wrapper around `Swift.String`. The Tagged
   primitive ships at L1
   (`swift-primitives/swift-tagged-primitives`); the package
   already imports it (`Lint.Rule.ID = Tagged<Lint.Rule,
   Swift.String>` at `Lint.Rule.ID.swift:27`). Layering is clean.
   The concern is semantic: a `Tagged<_, String>` adds compile-time
   discrimination (paths can't be mixed with rule IDs at the type
   system) but no semantic path operations (no `.appending`, no
   `.relative(to:)`, no `.components`). At an error-payload site
   the value is constructed once at the throw site and consumed
   once at the catch site; the type-tag's runtime utility is
   marginal.

**Within-package precedent**: `Diagnostic.Record.identifier:
Swift.String` is documented at the audit's F-A2.16 row as the
precedent for raw `String` at path-shaped diagnostic data within
the primitives layer. The same package already accepts raw `String`
for the equivalent role; F-A2.15 inherits the precedent.

**Recommendation**: Keep `Swift.String` in `Lint.Configuration
.Error`. The `Tagged<Lint.Configuration, Swift.String>` option is
technically available and layer-clean, but the value/cost balance
is marginal at an error-payload site (one throw + one catch per
error); the within-package precedent points at `String`; and the
right long-run answer is an ecosystem `File.Path`-equivalent at L1
that the primitives package can adopt across the diagnostic
surface. The right disposition under
`[ARCH-LAYER-008]` (correctness, not adoption, drives shape) is to
record the trade-off rather than half-adopt a wrapper that doesn't
add semantic value.

### F-A4.2 — `public var ordinal: Swift.Int` vs `internal` + re-typed

**The trade-off**: `Lint.Visibility.swift:48` exposes `public var
ordinal: Swift.Int` returning 0/1/2/3 for `.private / .fileprivate
/ .internal / .public`. The `<` operator at `:41–43` is the only
documented consumer. The audit floats two pivots:

1. **Keep public + `Swift.Int`** — preserves API stability. The
   raw-int return advertises raw-int semantics. Consumers MAY
   compare via `<` (the Comparable conformance) without touching
   `.ordinal` directly.
2. **Make `ordinal` internal + re-type** — API-tightening (since
   `<` is the only consumer) and potentially adopt
   `Ordinal`/`Cardinal`.

**The semantic-fit question (the load-bearing one)**: Is
`Lint.Visibility.ordinal` an *Ordinal* (typed position) or a
*Cardinal* (typed count)? The doc comment at `:45–46` reads:
"Narrower visibilities sort lower so `min`/`max` over a chain of
enclosing modifiers yields the effective access level." The value
is a rank/sort-key over the 4-case access-control enum, used only
inside the package to ground the `Comparable` conformance.

Neither primitive fits cleanly:

- **`Ordinal`** is for positions in a collection (line numbers,
  array indices). A visibility-rank is not a position in a
  collection; the four enum cases aren't traversed.
- **`Cardinal`** is for counts (sizes, magnitudes). The
  visibility-rank could be re-framed as "count of access levels
  strictly broader than this one" (`public` → 0, `private` → 3),
  but the actual returned values (`public` → 3, `private` → 0)
  invert the count semantic; the value is a ranking convention,
  not a count.

The right primitive for "rank/sort-key of an enum case under a
total order" arguably doesn't exist (a hypothetical
`Enum.Rank<E>`). For a 4-case enum's internal sort-key, creating
the primitive is over-investment.

**Recommendation**: Keep `Swift.Int`; do not adopt
`Ordinal`/`Cardinal`. The public/internal question is separable
from typed-primitive adoption — tightening visibility to internal
is a clean API-hygiene pass (the `<` operator continues to work
because it's `@inlinable` and within the same module). Document
this disposition; do not promote to F-A4.3. The optional API-
hygiene pass could land separately from the typed-primitive
adoption track.

## Outcome — Real-Gap promotions

| # | Finding | Site | Promotion rationale |
|---|---------|------|---------------------|
| 1 | F-A3.3 | `Lint.Source.Walker.swift:30, 38` | `Glob.Pattern` exists at L1 (`swift-primitives/swift-glob-primitives`) — audit premise was stale. Adopt `[Glob.Pattern]` for `includePatterns` / `excludePatterns` static lets. Cost: Low. |

**Count**: 1.

**Dispatch instruction**: Add to the F-A4.3 follow-up dispatch
alongside `topLevelCount` (the only Real-Gap-classified Axis-4
adoption left). The F-A3.3 site requires:

1. Declare the dep `swift-foundations/swift-linter →
   swift-primitives/swift-glob-primitives` in `Package.swift`
   (`Glob Primitives` product).
2. Add `public import Glob_Primitives` to the source file.
3. Change `public static let includePatterns: [Swift.String] = [...]`
   to `public static let includePatterns: [Glob.Pattern] = (try!
   [...].map(Glob.Pattern.init))` (or a static-let initializer
   pattern that fails build-time on a malformed literal). Mirror
   for `excludePatterns`.

**Outcome (2026-05-12)**: LANDED via the foundation-first shape
documented under the F-A3.3 status update. The original dispatch
plan above is preserved as the recommendation snapshot at addendum
write-time; the as-executed shape differs from step 3 (literal
construction routes through `ExpressibleByStringLiteral` on the
SLI target rather than `try!.map(Glob.Pattern.init)`) and adds
upstream commits on `swift-glob-primitives` + `swift-file-system`
per `[ARCH-LAYER-011]` (improve the foundation rather than force
the consumer to choose between `try!` and round-trip-to-string).

## Outcome — Acceptable

| # | Finding | Site | One-line rationale |
|---|---------|------|--------------------|
| 1 | F-A2.7 | `Lint.SingleFile.Extractor.swift` (multiple) | Boundary settled in Phase 2; AST-extracted literals stay `Swift.String`, surface parameters typed `File.Path`. |
| 2 | F-A2.10 | `Lint.Dependency.swift:38, 46, 60` | Public API mirrors SwiftPM's `Package.Dependency.package(...)`; values are code-gen literals destined for source emit. |
| 3 | F-A2.12 | `Lint.SingleFile.Materializer.swift:185–188` | Code-gen output; body already typed; boundary intentionally bare strings because destination is source text. |
| 4 | F-A2.15 | `Lint.Configuration.Error.swift:18, 19, 20` | L1 layer-bound (no `File.Path` import); `Tagged<_, String>` adds no semantic value; within-package precedent (`Diagnostic.Record.identifier`) accepts raw `String`. |
| 5 | F-A3.2 | `Lint.Manifest.swift:104` | In-memory model is already `[File.Path]`; `excludedRaw` is a transient JSON-boundary intermediate that immediately lifts. |
| 6 | F-A4.2 | `Lint.Visibility.swift:48` | Semantic is rank/sort-key, neither position nor count; neither `Ordinal` nor `Cardinal` fits; the API-hygiene "make internal" question is separable. |

**Count**: 6.

## Outcome — Deferred (primitives-gap)

| # | Finding | Site | Proposed primitive | Target package | Notes |
|---|---------|------|--------------------|----------------|-------|
| 1 | F-A2.11 | `Lint.SingleFile.PackageDependency.swift:43` | `SwiftPM.Package.ID = Tagged<SwiftPM.Package, Swift.String>` | `swift-primitives/swift-swiftpm-primitives` (or other) — package home is itself a design question | Subsumes the `name` half of F-A3.5. |
| 2 | F-A2.17 | `Lint.Suppression Tests.swift:199–203` | `File.Path.Temporary.randomized(prefix:suffix:)` (UUID-keyed under the hood) | `swift-foundations/swift-file-system` | Sibling to the existing `.deterministic` variant. |
| 3 | F-A3.4 | `Lint.Dependency.swift:38, 46, 60, 69, 80` | `SwiftPM.Product.ID = Tagged<SwiftPM.Product, Swift.String>` | `swift-primitives/swift-swiftpm-primitives` (or other) | Unblocks the `products` half of F-A3.5 too. |
| 4 | F-A3.5 | `Lint.SingleFile.PackageDependency.swift:41, 43` | Both primitives from rows 1 + 3 | (as above) | Mirror of F-A3.4 in the resolved-form value. |

**Count**: 4.

**Note for principal**: the deferrals collapse to two design
questions:

1. **`swift-swiftpm-primitives` (or similar)**: should the
   ecosystem own an L1 package for SwiftPM identifier shapes
   (package name, product name, target name, dependency address)?
   The linter is the first identified consumer; sibling consumers
   would include any tooling that parses or generates SwiftPM
   manifests.
2. **`File.Path.Temporary.randomized`**: should the typed
   primitives surface a randomized companion to
   `.deterministic`? Test fixtures across the ecosystem currently
   fall back to `FileManager.default.temporaryDirectory
   .appendingPathComponent(UUID().uuidString)`; F-A2.17 is the
   linter site that surfaces it.

## Pre-existing-gap observations (en passant)

- The cross-package side-note in the v1.0.0 audit (after Axis 2,
  re: `File.Path.Temporary.swift:53`) asserted raw-concat in the
  typed primitive's own body. The current file (`File.Path
  .Temporary.swift:55–58`) uses
  `temporaryDirectory.appending(trailing)` with typed `Path`
  construction. The note's precondition has been resolved already
  — flagging here so it does not propagate as a stale claim.
- `swift-foundations/swift-linter/Research/_index.json` is present
  per `[RES-003c]` but is stale: three 2026-05-12 docs
  (`2026-05-12-eval-path-self-reference.md`, `2026-05-12-foundation
  -up-dogfeed-triage.md`, the v1.0.0 audit doc itself) and
  `_Package-Insights.md` are absent from the index's `documents[]`
  array. The handoff brief's "MISSING per Open Q3" framing reads
  as if the file is absent — it is present but unmaintained. Per
  the handoff's Verification section, surfacing only; the index
  catch-up is out of scope for this addendum.

## References

- v1.0.0 audit at `2026-05-12-typed-primitive-adoption-audit.md`
  (sibling document)
- Layer architecture: `swift-institute/swift-institute.org/Swift
  Institute.docc/Layers.md`
- Tagged precedent: `swift-primitives/swift-linter-primitives/
  Sources/Linter Primitives/Lint.Rule.ID.swift`
- Glob.Pattern primitive: `swift-primitives/swift-glob-primitives/
  Sources/Glob Primitives/Glob.Pattern.swift`
- File.Path.Temporary.deterministic: `swift-foundations/swift-file-
  system/Sources/File System Core/File.Path.Temporary.swift`
- L1 ownership-shape constraints: `[ARCH-LAYER-001]`,
  `[ARCH-LAYER-006]`, `[ARCH-LAYER-008]`
- L1 `Path_Primitives.Path` (rejected for error payload):
  `swift-primitives/swift-path-primitives`
