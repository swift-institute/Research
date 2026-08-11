# Typed-Primitive Adoption Audit — Linter Ecosystem (5 packages)

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: TRIAGE
tier: 2
scope: cross-package
addendum: 2026-05-12-typed-primitive-adoption-audit-addendum.md
---
-->

> **See also**:
> [`2026-05-12-typed-primitive-adoption-audit-addendum.md`](2026-05-12-typed-primitive-adoption-audit-addendum.md)
> — v1.0.0 RECOMMENDATION disposing the 11 Ambiguous findings
> (Real-Gap-promote / Acceptable / Defer). The v1.0.0 TRIAGE
> classifications below are preserved unchanged; the addendum
> extends rather than rewrites.
>
> **Post-remediation status** (2026-05-12):
> - Real Gap remediations: Phases 0–3 landed (path-math, FS-path
>   boundary, rule-ID typing).
> - F-A4.3 (`topLevelCount: Cardinal`) landed at
>   `swift-linter-rules@d32f8f3` (audit-followup dispatch).
> - F-A3.3 (`includePatterns`/`excludePatterns: [Glob.Pattern]`)
>   landed via:
>   - `swift-glob-primitives@9ba5d4c` — new `Glob Primitives Standard
>     Library Integration` target hosting `Glob.Pattern:
>     ExpressibleByStringLiteral` ([ARCH-LAYER-011]).
>   - `swift-file-system@4a5206f` — typed `[Glob.Pattern]` overloads
>     on `glob.files` / `glob.directories` / `glob(...)`, string
>     variants kept as parsing conveniences ([ARCH-LAYER-011]).
>   - `swift-linter@73fd25e` — `Lint.Source.Walker` static lets
>     pivoted to `[Glob.Pattern]` via SLI literal conformance.
> - Dogfeed residue verified at unchanged counts pre vs post
>   (swift-linter: 135, swift-linter-primitives: 6 — same baseline
>   both sides; Phase 1/2 adoption did not perturb rule firings).

## Context

Sibling-discovery driven inventory: the
`Lint.SingleFile.Materializer.resolveConsumerPath` pivot at commit
`fe2c18e` (raw `+ "/" +` path concat → `File.Path.appending(_:)`) was
the second manually-caught instance of the same pattern in a short
window. The brief at
`/Users/coen/Developer/AUDIT-linter-typed-primitive-adoption.md`
dispatched a systematic enumeration of typed-primitive adoption gaps
across the five linter packages along four axes:

| Axis | Adoption target |
|------|-----------------|
| 1 | Path math — `Path` / `File.Path.appending(_:)` / `Path.Modification` |
| 2 | File-system paths — `File.Path` / `File.Directory` |
| 3 | Identifier sets — `Tagged<_, String>` (e.g. `Lint.Rule.ID = Tagged<Lint.Rule, String>`) |
| 4 | Numeric — `Cardinal` (counts) / `Ordinal` (positions) |

This audit is **investigation only**. Remediation dispatch is a
follow-up the principal will author after triaging the table below.

### Available typed primitives (verified at audit time)

| Type | Defined in | Shape |
|------|------------|-------|
| `Paths.Path` (alias `File.Path`) | `swift-foundations/swift-paths` (re-exported by `swift-foundations/swift-file-system`) | `Copyable, Sendable, Hashable`; `.appending(_:)`, `/` operator, `.hasPrefix(_:)`, `.relative(to:)`, `.parent`, `.components` |
| `Path_Primitives.Path` | `swift-primitives/swift-path-primitives` | `~Copyable` syscall-oriented variant; not the linter's everyday surface |
| `Tagged<Tag, U>` | `swift-primitives/swift-tagged-primitives` | Phantom-type wrapper; carrier of `Lint.Rule.ID = Tagged<Lint.Rule, String>` and `Lint.Source.Path = Tagged<Lint.Source, String>` |
| `Cardinal` | `swift-primitives/swift-cardinal-primitives` | Typed quantity (count / size) |
| `Ordinal` | `swift-primitives/swift-ordinal-primitives` | Typed position (index / line) |
| `Text.Line.Number` | `swift-primitives/swift-source-primitives` (via `Source.Location.position.line`) | `Tagged<Text.Line, _>` — typed 1-based line number |

The linter ecosystem already declares its own typed identifiers
(`Lint.Rule.ID`, `Lint.Source.Path`) — adoption gaps are
asymmetrically distributed: the **engine layer** (`swift-linter`,
`swift-linter-primitives`) carries the bulk of them; the **rule
packages** (`swift-linter-rules`, `swift-institute-linter-rules`,
`swift-primitives-linter-rules`) are essentially clean because their
work is AST identifier text matching that the brief carves out as
legitimately `Swift.String`.

### Prior research consulted (per `[HANDOFF-013]`)

- `swift-foundations/swift-linter/Research/2026-05-12-eval-path-self-reference-unfinished.md` — references the same `fe2c18e` typed-path pivot but addresses an orthogonal defect (the `.`-as-package-name self-reference path).
- `swift-foundations/swift-linter/Research/2026-05-12-foundation-up-dogfeed-triage.md` — dogfeed of *existing* rule firings on the linter packages; adjacent but distinct from typed-primitive adoption gaps that no current rule catches.
- `swift-institute/Research/cardinal-ordinal-vector-enforcement-design.md` — discusses Cardinal/Ordinal enforcement strategy; relevant background but not a duplicate inventory.
- `swift-institute/Research/2026-05-12-swift-linter-unified-consumer-manifest.md` — manifest design for consumer-side `Lint.swift`; orthogonal topic.

No prior audit covers this ground; this doc extends rather than
duplicates.

### Enumeration grep caveat (per `[HANDOFF-031]`)

The brief's Axis-1 grep pattern `+ "/" +` matches only the
**separator-only** path-concat shape. It does NOT match the more
common **whole-segment** shape `root + "/Sources/Lint"` etc. The
broader pattern `\+\s*"/` (any `+` followed by a `"/`-leading literal)
catches both. Findings F-A1.5 through F-A1.13 below come from the
broader pattern; if the audit had executed only the brief's literal
grep, those eight findings would have been false-negatives. The
shape-narrower pattern in the brief is documented here as a
recognizer gap for the follow-up remediation.

The Axis 3 `Set<Swift.String>` grep fires on syntactically identical
shapes whose semantic role splits into two clean buckets:

- **AST-identifier matching tables** — rule-internal data
  (`namingBoxClassFlaggedNames`, `platformCTypeInPublicAPIFlaggedCTypes`,
  …). Out of scope per the brief's AST-text carve-out.
- **Engine-internal collections** — rule-ID lists, source-path lists,
  product names. In scope.

The 30+ Axis-3 sites in rule packages collapse to "Acceptable" in one
batch; engine-layer sites are individually classified below.

---

## Summary — Counts per axis × per package

| Package | A1 Path math | A2 FS paths | A3 Identifier sets | A4 Numeric | Total Real Gap | Ambiguous |
|---------|------------:|------------:|------------------:|-----------:|---------------:|----------:|
| swift-linter (foundations) | 13 | 22 | 3 | 6 | 22 | 11 |
| swift-linter-primitives (primitives) | 0 | 0 | 0 | 1 | 0 | 1 |
| swift-linter-rules (foundations) | 0 | 0 | 0 | 0 | 0 | 0 |
| swift-institute-linter-rules (foundations) | 0 | 0 | 0 | 0 | 0 | 0 |
| swift-primitives-linter-rules (primitives) | 0 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **13** | **22** | **3** | **7** | **22** | **12** |

**Headline**: 22 Real Gap findings, all in `swift-foundations/swift-linter`
or `swift-primitives/swift-linter-primitives`. The three rule
packages are clean on this dimension. The Axis-1 path-math
concentration in the engine layer is the highest-leverage cluster —
half the Real-Gap findings collapse to four to six call sites once
the bare-string boundary at `consumerPackageRoot: Swift.String` is
typed.

---

## Findings — Axis 1: Path math (raw `+ "/..."` concat)

| # | File:line | Current shape | Recommended typed primitive | Classification | Cost estimate |
|---|-----------|---------------|----------------------------|----------------|---------------|
| F-A1.1 | `swift-linter/Sources/Linter Core/Lint.Source.Walker.swift:76` | `let normalizedRoot = rootString.hasSuffix("/") ? rootString : rootString + "/"` followed by `absolute.hasPrefix(normalizedRoot)` + `dropFirst(normalizedRoot.count)` | `file.path.relative(to: root)` on `Paths.Path` (`Path.Navigation.swift:181`) | Real Gap | Low — direct one-call substitution |
| F-A1.2 | `swift-linter/Sources/Linter Core/Lint.Source.Walker.swift:64` | `if rootString.hasSuffix(".swift")` | `Paths.Path.Component.Extension` extraction (`Path.Component.Extension.swift`) | Real Gap | Low |
| F-A1.3 | `swift-linter/Sources/Linter Core/Lint.Run.swift:202–203` | `let separator = rootString.hasSuffix("/") ? "" : "/"` + `absoluteString = rootString + separator + relativePath.underlying` | `root.appending(Path(stringLiteral: relativePath.underlying))` — handles trailing-separator dedup per `Path.Modification.swift` | Real Gap | Low (after typing `relativePath` properly — see F-A2.* and F-A3.1) |
| F-A1.4 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Extractor.swift:295–304` | `basename(of path: Swift.String) -> Swift.String` — manual trailing-slash strip + `lastIndex(of: "/")` | `File.Path(...).components.last?.string` (`Path.Components.swift`) | Real Gap | Low |
| F-A1.5 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:35` | `let evalRoot: Swift.String = consumerPackageRoot + "/.swift-lint/eval"` | `File.Path(consumerPackageRoot).appending(".swift-lint").appending("eval")` (or single `/` operator chain) | Real Gap | Low |
| F-A1.6 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:36` | `let sourcesDirectory: Swift.String = evalRoot + "/Sources/Lint"` | `evalRoot.appending("Sources").appending("Lint")` | Real Gap | Low |
| F-A1.7 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:55` | `writeAtomic(packageSwift, to: evalRoot + "/Package.swift")` | `evalRoot.appending("Package.swift")` | Real Gap | Low |
| F-A1.8 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:58` | `writeAtomic(consumerSource, to: sourcesDirectory + "/main.swift")` | `sourcesDirectory.appending("main.swift")` | Real Gap | Low |
| F-A1.9 | `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:82` | `let candidate = consumerPackageRoot + "/Lint.swift"` | `consumerPackageRoot.appending("Lint.swift")` (post-typing F-A2.*) | Real Gap | Low |
| F-A1.10 | `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:159` | `let consumerLintSwiftPath = consumerPackageRoot + "/Lint.swift"` | Same as F-A1.9 (duplicate site) | Real Gap | Low |
| F-A1.11 | `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:237 + 240 + 246` | `let workspace = linterPath + "/.."` plus `workspace + "/swift-json"` and `workspace + "/swift-file-system"` | `linterPath.parent.appending("swift-json")` etc.; `.parent` accessor in `Path.Navigation.swift` | Real Gap | Low |
| F-A1.12 | `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:277` | `let tempPath = consumerPackageRoot + "/.swift-lint/parent-manifest.json"` | `consumerPackageRoot.appending(".swift-lint").appending("parent-manifest.json")` | Real Gap | Low |
| F-A1.13 | `swift-linter/Sources/Linter Core/Lint.Driver.swift:284 + 287 + 293` | `let workspace = linterPath + "/.."` + `workspace + "/swift-json"` + `workspace + "/swift-file-system"` | Same shape as F-A1.11 (sibling code path) | Real Gap | Low |

**Out-of-scope sample (matched grep but not findings):**

- `Lint.SingleFile.Materializer.swift:177`, `Lint.Run.swift:186`, `Lint.Suppression.swift:107/109/111` — doc-comment text only.
- `Lint.Rule.Structure.TypeTransformPlacement.swift:39`, `Lint.Rule.RawValue.Chain.swift:54` — rule message-string concat where `"/"` is a literal slash character in prose, not a path separator.
- Test fixture string literals (`"/Users/coen/...", "/tmp/..."` in `Lint.SingleFile.Materializer Tests.swift`, `Lint.SingleFile.Extractor Tests.swift`, `Lint.Finding Tests.swift`, `Lint.Reporter Tests.swift`) — Acceptable per brief's "parser input is legitimately Swift.String" carve-out.

---

## Findings — Axis 2: File-system paths (raw `Swift.String` at path-shaped sites)

| # | File:line | Current shape | Recommended typed primitive | Classification | Cost estimate |
|---|-----------|---------------|----------------------------|----------------|---------------|
| F-A2.1 | `swift-linter/Sources/Linter Core/Lint.Driver.swift:106 (and :174)` | `consumerPackageRoot: Swift.String` parameter | `consumerPackageRoot: File.Path` | Real Gap | Medium — touches the public CLI/dispatch boundary |
| F-A2.2 | `swift-linter/Sources/Linter Core/Lint.Driver.swift:126` | `lintSwiftPath(at consumerPackageRoot: Swift.String) -> Swift.String?` | `(at consumerPackageRoot: File.Path) -> File.Path?` | Real Gap | Medium — paired with F-A2.1 |
| F-A2.3 | `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:80, 156, 232` | `at consumerPackageRoot: Swift.String` (three call sites) | `at consumerPackageRoot: File.Path` | Real Gap | Medium |
| F-A2.4 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:31, 76` | `consumerPackageRoot: Swift.String` (two API entry points) | `consumerPackageRoot: File.Path` | Real Gap | Medium |
| F-A2.5 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:32` | `consumerLintSwiftPath: Swift.String` | `consumerLintSwiftPath: File.Path` | Real Gap | Low |
| F-A2.6 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:78` | `linterPath: Swift.String` | `linterPath: File.Path` | Real Gap | Low |
| F-A2.7 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Extractor.swift:44, 45, 123, 124, 208, 232, 278, 279` | `sourcePath: Swift.String, consumerPackageRoot: Swift.String, fromPath path: Swift.String` (eight parameter sites across the extractor surface) | `File.Path` or — where the value comes from AST string-literal extraction — keep `Swift.String` at the boundary and type only the post-extraction internal model | Ambiguous | Medium — boundary judgement |
| F-A2.8 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:41` | `let path: Swift.String = Environment.read("SWIFT_LINTER_PATH")` | Env-read returns `Swift.String?` natively; `File.Path` conversion can happen at first use | Acceptable (env boundary) | — |
| F-A2.9 | `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:191, 331` | `if let path: Swift.String = parentManifestPath` / `Environment.read("SWIFT_LINTER_PARENT_MANIFEST")` | Same env-boundary reasoning as F-A2.8 | Acceptable | — |
| F-A2.10 | `swift-linter/Sources/Linter/Lint.Dependency.swift:38, 46, 60` | `path: Swift.String` parameter for `.package(path: "...")` form | Real Gap *iff* the API treats `path` as path-shaped data; Ambiguous if it is genuinely a code-generation literal | Ambiguous | Medium |
| F-A2.11 | `swift-linter/Sources/Linter Core/Lint.SingleFile.PackageDependency.swift:43` | `name: Swift.String, products: [Swift.String]` | `name` is identifier-shaped (see Axis 3); path is via `.source` enum case | Ambiguous (covered by Axis 3 for `name`) | — |
| F-A2.12 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:185–188` | `resolveConsumerPath(_ consumerPath: Swift.String, relativeRoot: Swift.String) -> Swift.String` — internals use `File.Path` correctly post-`fe2c18e`, but the boundary is still bare strings | `File.Path` boundary across the function | Ambiguous (positive baseline; body already typed) | Low — surface-only change |
| F-A2.13 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Error.swift:16, 22, 26, 32, 37, 46` | `case readFailed(path: Swift.String, description: Swift.String)` + sibling cases | `case readFailed(path: File.Path, description: Swift.String)` | Real Gap | Medium — touches error API surface; propagation cost |
| F-A2.14 | `swift-linter/Sources/Linter Core/Lint.Run.Error.swift:14, 15` | `case fileNotReadable(path: Swift.String), case nonUTF8(path: Swift.String)` | Same pattern as F-A2.13 | Real Gap | Low |
| F-A2.15 | `swift-linter-primitives/Sources/Linter Primitives/Lint.Configuration.Error.swift:18, 19, 20` | `case fileNotReadable(path: Swift.String), .malformed(path: Swift.String, ...), .unknownRuleID(_, path: Swift.String)` | `File.Path` payload | Ambiguous — L1 primitives package; depending on `File.Path` (an L3 type) would invert layering. Use `Tagged<_, String>` or keep `String` per `Diagnostic.Record.identifier: Swift.String` precedent | Out of scope for adoption (layer-bound) |
| F-A2.16 | `swift-linter/Sources/Linter Reporter Text/Lint.Reporter.Text.swift:78` and `swift-linter/Sources/Linter Reporter SARIF/Lint.Reporter.SARIF.swift:86` | `let pathOrID = location.filePath ?? location.fileID` — both fields are `Swift.String?` on `Source.Location` | Inherited from `Source.Location` design; consumers MAY wrap higher up per `Diagnostic.Record.swift:18–25` doc comment | Acceptable (precedent-bound) | — |
| F-A2.17 | `swift-linter/Tests/Linter Core Tests/Lint.Suppression Tests.swift:199–203` | `FileManager.default.temporaryDirectory.appendingPathComponent(...)` for test-fixture scaffolding | `File.Path.Temporary.deterministic(prefix:, key:, suffix:)` exists in `swift-file-system`; no `randomized` variant for UUID-keyed scaffolds yet | Ambiguous — no fully-equivalent typed surface for uuid-keyed temp dirs; fixture works at Foundation boundary | — |

**Cross-package side-note (per brief's "note but don't expand scope"):**

- `swift-foundations/swift-file-system/Sources/File System Core/File.Path.Temporary.swift:53` — the *typed primitive's own* implementation contains `temporaryDirectory + "/" + prefix + sanitizedKey + suffix`. The thing the linter would adopt itself raw-concatenates. Worth surfacing to the principal as a precondition for clean adoption.

---

## Findings — Axis 3: Identifier sets / lists

| # | File:line | Current shape | Recommended typed primitive | Classification | Cost estimate |
|---|-----------|---------------|----------------------------|----------------|---------------|
| F-A3.1 | `swift-linter/Sources/Linter Core/Lint.Manifest.swift:102–103` | `let enabledRaw = try [Swift.String](json: json["enabledRuleIDs"])` + `disabledRaw = ... [Swift.String](json: ...)` | `[Lint.Rule.ID]` — type exists at `swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift` | Real Gap | Low — Tagged is ExpressibleByStringLiteral via `swift-tagged-primitives` stdlib integration |
| F-A3.2 | `swift-linter/Sources/Linter Core/Lint.Manifest.swift:104` | `let excludedRaw = try [Swift.String](json: json["excludedPaths"])` | Path-shaped identifier list; candidate `[Lint.Source.Path]` or `[File.Path]` (with `.hasPrefix(_:)` matching) | Ambiguous — JSON wire form is strings; in-memory model could be typed | Medium |
| F-A3.3 | `swift-linter/Sources/Linter Core/Lint.Source.Walker.swift:30, 38` | `static let includePatterns: [Swift.String] = [...]` and `excludePatterns: [Swift.String] = [...]` (glob patterns) | No typed `Glob.Pattern` primitive in scope today; `Tagged<Glob, String>` would carry role | Ambiguous — no clear typed primitive available | — |
| F-A3.4 | `swift-linter/Sources/Linter/Lint.Dependency.swift:38, 46, 60, 69, 80` | `products: [Swift.String]` in `Lint.Dependency` factory functions | SwiftPM-product identifier shape; candidate `Tagged<SwiftPM.Product, String>` (does not exist in scope yet) | Ambiguous | Medium |
| F-A3.5 | `swift-linter/Sources/Linter Core/Lint.SingleFile.PackageDependency.swift:41, 43` | `name: Swift.String, products: [Swift.String]` mirror of F-A3.4 | Same shape | Ambiguous | Medium |
| F-A3.6 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Extractor.swift:138, 139, 165, 240` | `var rangeBounds: [Swift.String] = []`, `var productsArg: [Swift.String]?`, etc. — extracted from AST string-literal `[String]` expressions | Boundary code; `Swift.String` at extraction is per the brief's AST carve-out | Acceptable | — |
| F-A3.7 | `swift-linter/Sources/Linter/Lint.run.swift:82–83`, `swift-linter/Sources/Linter CLI/Linter CLI.swift:45, 119`, `swift-linter/Sources/Linter Core/Lint.Driver.swift:107`, `swift-linter/Sources/Linter Core/Lint.SingleFile.swift:157, 188` | `[Swift.String]` arguments / argv / invocation | Process argv is unconditionally `[String]`; CLI-boundary validation per `// validate at the CLI boundary` comment | Acceptable | — |
| F-A3.8 | All rule-package `Set<Swift.String>` / `[Swift.String]` constants and locals across `swift-linter-rules`, `swift-institute-linter-rules`, `swift-primitives-linter-rules` (∼45 sites) | AST-identifier matching tables and walker scratch state | AST identifier text per brief's carve-out | Acceptable | — |

Real Gap count for Axis 3: **3** (F-A3.1 enabled IDs, F-A3.1 disabled IDs as separate site; the single `excludedRaw` and the pattern collections are Ambiguous).

---

## Findings — Axis 4: Numeric (positions / counts)

| # | File:line | Current shape | Recommended typed primitive | Classification | Cost estimate |
|---|-----------|---------------|----------------------------|----------------|---------------|
| F-A4.1 | `swift-linter/Sources/Linter Core/Lint.Suppression.swift:62, 75, 89, 99, 162, 273` | `line: Swift.Int` (1-based source line; stored on `Lint.Suppression.Entry` and compared against `record.location.line` at `Lint.Run.swift:166`) | `Text.Line.Number` (typed at L1 via `Source.Location.position.line`) — but the boundary is fixed by `Source.Location.line: Int`'s downcast accessor | Real Gap — though contingent on `Source.Location.line` retaining its `Int` accessor; first-class fix lives at L1 | Medium (chains to upstream) |
| F-A4.2 | `swift-linter-primitives/Sources/Linter Primitives/Lint.Visibility.swift:48` | `public var ordinal: Swift.Int` returning 0/1/2/3 for `private`/`fileprivate`/`internal`/`public` ordering | `Ordinal` (or `Cardinal` — "count of broader scopes"). Trivial 4-case lookup, but the public `ordinal:` name and `Int` return advertise raw-int semantics. | Ambiguous — the `< (lhs, rhs)` operator that consumes this is the only caller; if `<` is the only surface, the property could be made internal and re-typed | Low |
| F-A4.3 | `swift-linter-rules/Sources/Linter Rule Structure/Lint.Rule.Structure.SingleTypePerFile.swift:58, 59` | `var currentDepth: Int = 0` + `var topLevelCount: Int = 0` | `currentDepth` is internal walker depth (Acceptable per "Internal iteration counters"); `topLevelCount` is a Cardinal quantity ("how many top-level types in this file") for which `Cardinal` would carry role | Real Gap (only `topLevelCount`); Acceptable (`currentDepth`) | Low |
| F-A4.4 | `swift-linter-rules/Sources/Linter Rule Closure/Lint.Rule.Closure.ConfigurationPlacement.swift:108`, `swift-linter-rules/Sources/Linter Rule Throws/Lint.Rule.Throws.ClosureAnnotation.swift:131`, `swift-linter-rules/Sources/Linter Rule Throws/Lint.Rule.Throws.RethrowsResultShim.swift:48`, `swift-linter-rules/Sources/Linter Rule Testing/Lint.Rule.Testing.BenchmarkTimedRequired.swift:44`, `swift-linter-rules/Sources/Linter Rule Structure/Lint.Rule.Structure.WrapperBackingExposed.swift:78`, `swift-linter-rules/Sources/Linter Rule Structure/Lint.Rule.Structure.RawValueAccess.swift:51`, `swift-linter-rules/Sources/Linter Rule Platform/Lint.Rule.Platform.NamespaceRoot.swift:76` | Various `var depth: Swift.Int = 0` walker depth counters | Internal `Cardinal` would carry role but is rarely worth the wrapping for a private counter; pre-existing precedent across rules to leave these as `Int` | Acceptable — internal iteration counters | — |
| F-A4.5 | `swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:90` | `var lines: [Swift.String] = [...]` for source-code generation | Generated source text; legitimately `[String]` for `.joined(separator: "\n")` output | Acceptable | — |

Real Gap count for Axis 4: **6** for F-A4.1 (six suppression sites carrying the same `Swift.Int` line shape) + **1** for F-A4.3's `topLevelCount`. Total **7**. F-A4.2 floated as Ambiguous.

---

## Axis 5 — Other typed-primitive opportunities

Grep for `Result<`, `Task`, untyped public `throws`, `async let`,
`withCheckedContinuation` across the five packages returned:

- Zero `Result<T, E>` *usages* in production code (matches found are rule-message strings discussing `Result<T, E>` in `Lint.Rule.Throws.ResultCallback.swift` and `Lint.Rule.Throws.RethrowsResultShim.swift`).
- Zero `Task { … }` / `Task<...>` / `async let` / `withCheckedContinuation` in production code.
- Two untyped public `throws` sites — both at stdlib boundaries (out of scope):
  - `Lint.SingleFile.swift:118` `readFile(at:) throws -> String` (internal, interfaces with stdlib file IO);
  - `Linter CLI.swift:61` `run() throws` (ArgumentParser `ParsableCommand.run` requirement).

Axis 5 yields **zero** in-scope findings. The engine already runs on
typed throws throughout `Lint.SingleFile.Error`, `Lint.Run.Error`,
`Lint.SingleFile.PackageDependency.Error`, `Lint.Configuration.Error`,
etc.

---

## Prioritization Recommendation

Sorted highest-leverage first; each phase narrows the public surface
that subsequent phases depend on.

### Phase 1 — Axis 1 cluster (high leverage, low cost)

Pivot all 13 Axis-1 sites to `Paths.Path`/`File.Path` methods. **No
new typed primitives needed** — `appending(_:)`, `/` operator, `.parent`,
`.components.last`, `.relative(to:)`, and the existing
`Path.Component.Extension` accessor cover every site. Pattern is
already proven at `Lint.SingleFile.Materializer.resolveConsumerPath`
(`fe2c18e`); replicate.

Highest leverage because:

1. The pattern is what triggered this audit (caught twice manually).
2. All sites are local edits — none widen API surface.
3. Replacement code is markedly clearer at each site (less error-prone separator math).

### Phase 2 — Axis 2 boundary typing (medium leverage, medium cost)

Type the `consumerPackageRoot: Swift.String` boundary as `File.Path`
through:

- `Lint.Driver.{generalLint, lintSwiftPath, …}` (F-A2.1, F-A2.2)
- `Lint.SingleFile.{detect, dispatch, resolveParentChain}` (F-A2.3)
- `Lint.SingleFile.Materializer.{materialize, renderPackageSwift}` (F-A2.4)
- `Lint.SingleFile.Materializer.resolveConsumerPath` boundary (F-A2.12)

This eliminates the bare-string artery from CLI entry through to
Materializer. After Phase 2, Phase 1's `+ "/..."` replacements become
single `.appending` calls instead of `File.Path(rawString).appending`
round-trips.

The error-type cases (F-A2.13, F-A2.14) follow naturally — once the
emit sites have `File.Path`, error payloads should too. Cost is
mostly downstream-call-site fixups, mechanical once the surface
changes.

### Phase 3 — Axis 3 rule-ID list typing (low leverage, low cost)

`Lint.Manifest.swift:102–103` pivots `[Swift.String]` →
`[Lint.Rule.ID]` for the `enabledRaw` / `disabledRaw` JSON-derived
lists. Concrete benefit: the rule-ID comparison at
`Lint.Run.swift:166` (`entry.ruleID == ruleID`) currently relies on
`Lint.Rule.ID == Tagged<…, String>` ↔ raw-string comparison via
implicit boundary; making the manifest store the typed form closes
the loop without ceremony.

### Phase 4 — Suppression line typing (medium leverage, contingent)

F-A4.1's six `line: Swift.Int` sites in `Lint.Suppression` are a Real
Gap, but the cleanest fix requires `Source.Location.line` to expose
its underlying `Text.Line.Number` directly (today the public
accessor is `var line: Int { Int(position.line.underlying) }`). This
audit recommends *raising* the typing question at the L1
`swift-source-primitives` layer rather than papering over at L3.

**RESOLVED at Thread H.4** (2026-05-13,
`swift-source-primitives@02da622` + cascade across swift-linter +
swift-parsers): L1 contingency lifted. `Source.Location.line` now
returns `Text.Line.Number` directly (was `Int`); a new typed-line
init overload allows propagation without an `Int` round-trip. The six
sites in `Lint.Suppression.swift` were ALREADY using
`Text.Line.Number` for the `Entry.line` field — the audit's mapping
predated a prior typed-primitive refactor that landed the typed
storage without resolving the upstream accessor. The H.4 cascade
confirms the storage was typed; only the upstream accessor was the
boundary.

**Cascade note**: the consumer-side `Int(.underlying)` boundary
conversions in `swift-parsers/Parsers.Diagnostic.swift` (3 formatter
functions) and `swift-linter/Lint.Source.Parsed+Visibility.swift` /
`Lint.Reporter.SARIF.swift` are pragmatic landings — the principled
typed-arithmetic improvement (Text.Line.Number conforming to
Carrier.`Protocol`) is queued as a separate dispatch per
`HANDOFF-thread-h-followup-typed-arithmetic.md`.

### Out-of-immediate-scope but worth tracking

- F-A4.2 (`Lint.Visibility.ordinal: Swift.Int`) — typify after the use-survey confirms `<` is the only consumer.
- F-A3.3 (glob-pattern lists) — wait for a typed `Glob.Pattern` primitive before adopting; no benefit from `Tagged<Glob, String>` alone. **Resolved**: `Glob.Pattern` SLI added at `swift-glob-primitives/Sources/Glob Primitives Standard Library Integration` (audit-remediation Phase 1+2 follow-up); `Lint.Configuration.Rules.excluded: [Glob.Pattern]` adopted.
- F-A3.4 / F-A3.5 (SwiftPM product-name `[String]`) — wait for a typed SwiftPM identifier surface; the linter shouldn't fork one. **Resolved at Thread G** (2026-05-13): `swift-package-primitives` landed at Thread E Row 23 with `Product.Name = Tagged<Product, Swift.String>` + `Package.Name = Tagged<Package, Swift.String>`. Thread G.1 adopted `Product.Name` on `Lint.Dependency.products` and `Lint.SingleFile.PackageDependency.products`; SwiftPM-identifier shape is now typed end-to-end at the public DSL.
- The cross-package note on `File.Path.Temporary.deterministic` (raw concat in the typed primitive's own body) — flag to the principal as a precondition for the test-fixture conversion track.

---

## Methodology / Audit-time invariants honoured

- Per `[HANDOFF-047]`: every file:line citation in the findings table was sampled from grep output at audit time, not memorized from parent-conversation state.
- Per `[HANDOFF-031]`: the brief's Axis-1 grep pattern's narrow shape (`+ "/" +`) is documented as a recognizer gap; broader pattern `\+\s*"/` returned the 8 additional Axis-1 sites (F-A1.5–F-A1.13). The Axis-3 `Set<String>` grep's false-positive shape (AST-identifier tables) is grouped under F-A3.8 rather than enumerated per-rule-file.
- Per `[HANDOFF-013]`: prior Research consulted and cited; this audit extends rather than duplicates.
- Per the brief: no code changes made; production source untouched; `swift-institute-linter-rules/.gitignore` left as-is.

## Halt point

This audit closes at investigation. The principal authors the
remediation dispatch after reviewing the triage above. Suggested
dispatch shape: separate remediation per phase (Phase 1 as a standalone
unit — it's mechanical and gates Phase 2's cleanliness).
