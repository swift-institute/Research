# Single-file consumer-manifest extraction — design exploration

**Date**: 2026-05-13
**Phase**: Thread I, Phase I.0 (design only; HALTS for principal sign-off)
**Status**: AWAITING PRINCIPAL SIGN-OFF
**Predecessor**: `HANDOFF-thread-i-lint-singlefile-to-swift-manifests.md`
**Related precedent**: `swift-manifests/Research/2026-05-06-r5-27-hit-extraction.md` (the Manifest.Resolver extraction that established this destination as the home for consumer-manifest mechanics)

---

## Goal restatement

Move generic single-file-consumer-manifest infrastructure from swift-linter
to swift-manifests per `[ARCH-LAYER-011]` (improve the institute foundation,
don't reach for Apple Foundation or third-party libs) and the
`project_linter_maximal_ecosystem_reuse.md` discipline. After Thread I,
swift-linter carries only Lint-domain code; swift-manifests owns the
single-file-manifest pattern primitives.

The decision in this document is **where to draw the seam between
generic-side (swift-manifests) and consumer-side (swift-linter)**.
Four options are presented. The seam moves from *most aggressive
extraction* (Option A, fully generic including magic-comment + extractor)
to *least aggressive* (Option B, only the small IO helpers).

---

## What's already in swift-manifests (pre-extraction state)

swift-manifests today exposes two generic patterns + one Lint-coded
helper:

### `Manifest.Load` (`Manifest Loader` module)

`Manifest.load<Output: JSON.Serializable>(_:configuration:)` materializes
a temporary eval project at `<root>/.swift-manifest/<filename>/` containing:

- A generated `Package.swift` (5 platforms, `name: "swift-manifest-driver"`,
  one `executableTarget("Driver")` with consumer-supplied `.package(path:)`
  deps, `swiftLanguageModes: [.v6]`).
- A generated `Driver.swift` carrying `@main enum __SwiftManifestDriver`
  whose `main()` reads `CommandLine.arguments[1]` for the output path,
  serializes the consumer's typed binding via `\(binding).jsonString()`,
  and writes it atomically.
- A copy of the consumer's manifest file inside the driver target.

The pipeline runs `/usr/bin/env swift run --package-path <eval> Driver
<outputPath>` via `Process.Spawn`, captures the JSON from a known
output path, decodes it into `Output`. Errors flow through
`Manifest.Error` (invalidInput / projectMaterialization /
driverProcess / driverNonZeroStatus / outputCaptureFailed / decoding).

`Configuration` is `(root, filename, binding, dependencies, toolchain?)`
where `dependencies: [Manifest.Dependency]` and
`Manifest.Dependency` is `(path, name, product, imports)` — all
`Swift.String`, **path-form only** (no URL variants).

Internal helpers: `_materialize`, `_createDirectoryRecursive`,
`_writeAtomic`, `_readEntireFile`, `_readCapturedOutput`,
`_renderPackageSwift`, `_renderDriverMain`, `_runDriver` — all
`@usableFromInline internal static`.

### `Manifest.Resolver<M: JSON.Serializable, C>` (`Manifest Resolver` module)

Generic parent-chain walker. `resolve(...)` and `walkParents(...)`
public; `walk`, `fetch` (file:// or curl-spawned http(s)://),
`evalParent` (recursive `Manifest.load`) internal. Errors:
`parentFetchFailed`, `parentChainCycle`, `parentChainTooDeep`.

### `Manifest.NestedPackage` (`Manifest Resolver` module)

`detect(at:) -> Bool` — checks for `<root>/Lint/Package.swift`.
`dispatch(at:arguments:) throws → Int32` — spawns `swift run
--package-path <root>/Lint Lint <args>`. **Both hardcode the
`"Lint"` name and the `"Lint/"` subdirectory.** This is a
pre-existing gap surfaced en passant: `Manifest.NestedPackage`'s
namespace is generic but its code is Lint-specific. Either parametrize
or rename `Lint.NestedPackage`; defer disposition to a follow-up
arc (see §Pre-existing gaps).

### `Manifest_Primitives` (L1)

`Manifest.Parent.scan(in:)` (byte-level `// parent: <URL>` scanner),
`Manifest.Dependency` (path-only string struct), `Manifest.Configuration`.
Foundation-clean per `[PRIM-FOUND-001]`.

---

## What Lint.SingleFile is (today, pre-extraction)

5 files at `swift-foundations/swift-linter/Sources/Linter Core/`:

### `Lint.SingleFile.swift` — namespace + magic-comment + dispatch

- `header: "swift-linter-tools-version:"` — Lint-specific magic-comment
- `canonicalize(consumerRoot:currentWorkingDirectory:)` — CLI boundary
  (resolve `"."` to absolute path)
- `detect(at: File.Path) -> File.Path?` — file existence + magic-comment
  scan (30-line window) + typed `Version.Tools` parse
- `parseMagicCommentToolsVersion(in:) -> Version.Tools?` — typed
  version parser
- `hasMagicComment(in:) -> Bool` — boolean wrapper
- `dispatch(at:arguments:) throws → Int32` — full pipeline:
  1. Read source
  2. Validate magic-comment
  3. `Extractor.dependencies(from:sourcePath:consumerPackageRoot:)`
     → `[Lint.SingleFile.PackageDependency]`
  4. `Materializer.materialize(consumerPackageRoot:consumerLintSwiftPath:dependencies:)`
     → `File.Path` (eval root)
  5. `resolveParentChain(consumerSource:consumerPackageRoot:)` →
     `File.Path?` (writes folded `Lint.Manifest` JSON to temp file)
  6. Build invocation `["swift", "run", "--package-path", evalRoot, "Lint"] + args`
     + optional `SWIFT_LINTER_PARENT_MANIFEST` env var
  7. `Process.Spawn.run` with inherited stdio; return exit code
- `resolveParentChain` — calls
  `Manifest.Resolver<Lint.Manifest, Lint.Manifest>.walkParents`,
  injects swift-json + swift-file-system + swift-linter deps from
  `SWIFT_LINTER_PATH`, JSON-serializes the folded manifest
- `foldParents([Lint.Manifest]) -> Lint.Manifest` — Lint-schema
  fold (enabled / disabled / excluded set-union)
- `configuration(parentOf: [Lint.Rule.ID: Lint.Rule]) -> Lint.Configuration?`
  — dispatched-side env-var reader

### `Lint.SingleFile.Extractor.swift` — SwiftSyntax extraction

- `dependencies(from:sourcePath:consumerPackageRoot:) throws → [PackageDependency]`
- `findRunCall` / `isLintRunCall` — match top-level `Lint.run(...)`
  or `run(...)` call expressions
- `parsePackageCall` — extract `path:` / `url:from:` / `url: "X"..<"Y"`
  / `products:` from each `.package(...)` call. Both the `from:`-form
  and the half-open-range form are recognized (Thread G G.1)
- `extractStringLiteral` / `extractRangeBounds` / `extractStringArray`
- `packageName(at:consumerPackageRoot:)` for paths;
  `packageName(at: url)` for URLs — derive SwiftPM package name from
  basename / trailing-component, with `"."` / `""` self-reference
  shortcut

### `Lint.SingleFile.Materializer.swift` — eval-project rendering

- `materialize(consumerPackageRoot:consumerLintSwiftPath:dependencies:) throws → File.Path`
- Eval root: `<consumerRoot>/.swift-lint/eval/`
- Reads `SWIFT_LINTER_PATH` env var (required; throws if absent)
- `renderPackageSwift(consumerPackageRoot:evalRoot:linterPath:dependencies:) throws → Swift.String`
  emits:
  - `swift-tools-version: 6.3.1` via typed `Version.Tools`
  - `name: "Lint"`
  - **1 platform** (`.macOS(.v26)`) — differs from Manifest.Load's 5
  - `.executable(name: "Lint", targets: ["Lint"])`
  - Always-added `.package(path: <linterPath>)`
  - Per consumer dep: switch over `.path` / `.urlFrom` / `.urlRange`
    — path-form deps prepended with `../..` (eval-relative-to-consumer)
  - Always-added `.product(name: "Linter", package: "swift-linter")`
  - Per consumer dep × per product: `.product(name:, package:)` entries
  - `swiftLanguageModes: [.v6]`
  - **Trailing for-loop adding ecosystem SwiftSettings** — differs
    from Manifest.Load (no settings loop)
- Copies `Lint.swift` → `main.swift` (NOT a JSON-output driver shim)
- `resolve(_:relativeTo:) throws → Swift.String` — path resolution
  with self-reference shortcuts
- Typed-`File.Path` IO helpers: `createDirectoryRecursive`,
  `writeAtomic`, `readFile` — duplicates Manifest.Load's
  `Swift.String`-based equivalents

### `Lint.SingleFile.PackageDependency.swift`

```swift
public struct PackageDependency: Swift.Sendable, Swift.Hashable {
    public enum Source: Swift.Sendable, Swift.Hashable {
        case path(Swift.String)
        case urlFrom(url: Swift.String, from: Swift.String)
        case urlRange(url: Swift.String, lower: Swift.String, upper: Swift.String)
    }
    public let source: Source
    public let name: Package.Name        // ← typed via Package_Primitives
    public let products: [Product.Name]  // ← typed via Package_Primitives
}
```

vs. `Manifest.Dependency`:

```swift
public struct Dependency: Swift.Sendable {
    public let path: Swift.String         // path-form ONLY
    public let name: Swift.String         // untyped
    public let product: Swift.String      // singular, untyped
    public let imports: [Swift.String]    // module-import names for shim
}
```

### `Lint.SingleFile.Error.swift`

7 cases — `readFailed`, `missingToolsVersion`, `parseFailed`,
`dependenciesNotFound`, `malformedPackageCall`, `materializationFailed`,
`spawnFailed`. All payloads use typed `File.Path`.

---

## Structural difference between `Manifest.Load` and `Lint.SingleFile`

The handoff frames this as the I.0 seam. Restating with file:line evidence:

| Concern | `Manifest.Load` | `Lint.SingleFile` |
|---|---|---|
| Materialized binary's identity | `Driver` target, generated `@main` shim that JSON-serializes a consumer binding | `Lint` target whose `main.swift` IS the consumer's `Lint.swift` |
| Spawn argument shape | `Driver <outputPath>` — single positional arg, internal | `Lint <consumer-args>` — pass-through |
| Output channel | Captured JSON file at `.output.json` (`Manifest.Load.swift:62-65`) | Inherited stdio (`Lint.SingleFile.swift:268-272`) — diagnostics stream to terminal |
| Return type | `Output` (decoded JSON value) | `Swift.Int32` (process exit code) |
| Magic-comment | None | `swift-linter-tools-version:` required (`Lint.SingleFile.swift:70`); `Version.Tools` parsed (`Lint.SingleFile.swift:151-172`) |
| Dependency source | Explicit `Configuration.dependencies` (`Manifest.Configuration.swift:38`) | SwiftSyntax-parsed from source's `Lint.run(dependencies:)` (`Lint.SingleFile.Extractor.swift:51-93`) |
| Dependency model | Path-only `Manifest.Dependency` (`Manifest.Dependency.swift:24-56`) | `path` / `urlFrom` / `urlRange` `Source` enum (`Lint.SingleFile.PackageDependency.swift:30-34`) |
| Render: platforms | 5 (`Manifest.Load.swift:221-227`) | 1, macOS only (`Lint.SingleFile.Materializer.swift:127-129`) |
| Render: ecosystem SwiftSettings | None | Trailing for-loop (`Lint.SingleFile.Materializer.swift:176-184`) — strict-memory-safety etc. |
| Path types | `Swift.String` end-to-end (`Manifest.Load.swift:43-57`) | Typed `File.Path` end-to-end since F-A2.3 (`Lint.SingleFile.Materializer.swift:38-42`) |
| Parent chain | Caller's responsibility (use `Manifest.Resolver` separately) | Wired into dispatch via env var (`Lint.SingleFile.swift:289-374`); folds Lint-specific `Lint.Manifest` schema |
| IO helpers | `Swift.String`-keyed | `File.Path`-keyed |
| Engine resolution | Consumer-supplied via `Configuration.dependencies` | `SWIFT_LINTER_PATH` env var read at materialize time (`Lint.SingleFile.Materializer.swift:55-68`) |

The materialize→spawn→passthrough mechanics are **structurally identical**;
the input contract (magic-comment, dep extraction) and the output contract
(JSON value vs. exit code) differ. This is the actual seam.

---

## Option taxonomy

The four options below order from most aggressive extraction (A) to
least (B), with C and D as middle grounds. The seam migrates rightward.

| Concern | A | D | C | B |
|---|---|---|---|---|
| Magic-comment detection | Generic (parametric header) | Lint | Lint | Lint |
| SwiftSyntax dep extraction from source | Partially generic | Lint | Lint | Lint |
| `Package.swift` rendering | Generic | Generic | Generic | Lint |
| Eval-project directory + write | Generic | Generic | Generic | Generic helpers |
| `main.swift` copy from consumer | Generic | Generic | Lint | Lint |
| `swift run` spawn | Generic | Generic | Lint | Lint |
| Stdio passthrough | Generic | Generic | Lint | Lint |
| Exit-code return | Generic | Generic | Lint | Lint |
| Parent-chain integration | Lint | Lint | Lint | Lint |

---

### Option A: `Manifest.Executable` — full generic with magic-comment + extractor

**Shape**: Add `Manifest.Executable` as a third sibling to
`Manifest.Load` and `Manifest.Resolver` in swift-manifests. The
generic captures: magic-comment header detection (parametric on the
header string + an optional version-parser callback), SwiftSyntax
extraction of `.package(...)` calls (parametric on the outer-call
matcher), Package.swift materialization, executableTarget
generation, process spawn with stdio passthrough, exit-code return.

**Generic-side (swift-manifests) additions**:

- New target `Manifest Executable` (Sources/Manifest Executable/):
  - `Manifest.Executable.swift` — namespace + top-level
    `dispatch(configuration:) throws → Int32`
  - `Manifest.Executable.Configuration.swift` — ~12-field struct
    (consumerRoot, consumerFilename, evalSubdirectory, executableName,
    header, headerVersionParser, outerCallMatcher, alwaysAddedDependencies,
    platforms, swiftLanguageModes, ecosystemSwiftSettings, environment,
    arguments, toolsVersion, …)
  - `Manifest.Executable.Detector.swift` — magic-comment detect
    parametric on header + parser
  - `Manifest.Executable.Extractor.swift` — SwiftSyntax extractor
    parametric on outer-call matcher
  - `Manifest.Executable.Materializer.swift` — `Package.swift` +
    `main.swift` rendering + write
  - `Manifest.Executable.PackageDependency.swift` — path / urlFrom /
    urlRange `Source` enum (carries the typed-Package.Name /
    Product.Name model; promotes Lint's typed model to the generic)
  - `Manifest.Executable.Error.swift`
  - `exports.swift`
- New product `Manifest Executable`
- New dep: `swift-syntax` (for SwiftSyntax extractor) — **heavy**
- New dep: `swift-package-primitives` (for typed `Package.Name` /
  `Product.Name`)
- Existing `_writeAtomic` / `_readEntireFile` / `_createDirectoryRecursive`
  re-implemented on `File.Path` (or both implementations carried)

**Lint-specific side (swift-linter) retained**:

- `Lint.SingleFile.header` — supplies `"swift-linter-tools-version:"`
  to the generic
- `Lint.SingleFile.canonicalize(...)` — CLI boundary helper, unchanged
- `Lint.SingleFile.PackageDependency` — could collapse to
  `typealias Lint.SingleFile.PackageDependency = Manifest.Executable.PackageDependency`,
  or stay as a typed wrapper
- `Lint.SingleFile.resolveParentChain` / `foldParents` /
  `configuration(parentOf:)` — Lint-specific parent-chain integration
- `Lint.SingleFile.dispatch(at:arguments:)` — thin adapter that:
  - Calls Manifest.Executable.detect/extract via the configured surface
  - Walks parent chain (Lint.Manifest-specific)
  - Builds `Manifest.Executable.Configuration` with Lint-specific
    header + outer-call + ecosystem-SwiftSettings + linker dep
  - Calls `Manifest.Executable.dispatch(configuration:)`

**Cascade scope**:
- swift-manifests: +7-8 new files in `Sources/Manifest Executable/`,
  +1 product, +2 new deps (swift-syntax + swift-package-primitives)
- swift-linter: 5 files touched
  (`Lint.SingleFile.swift` thinned, `Lint.SingleFile.Materializer.swift`
  deleted or stub, `Lint.SingleFile.Extractor.swift` deleted or
  stub-delegating, `Lint.SingleFile.PackageDependency.swift` reduced
  to a typealias or wrapper, `Lint.SingleFile.Error.swift` may map
  through `Manifest.Executable.Error`)
- External consumers: Lint.SingleFile public surface preserved
  (detect / dispatch / configuration); no external breakage expected
- Estimated commits: 3-4 in swift-manifests + 2-3 in swift-linter

**Pros**:
- Strongest maximal-reuse fit; greatest theoretical reach for future
  consumers (swift-format with `Format.swift`, swift-doc with `Doc.swift`)
- Captures both ends of the consumer-manifest pattern (input
  detection + execution mechanics)

**Cons**:
- swift-syntax becomes a transitive dep of swift-manifests — heavy
  weight added to a previously-light L3 package
- SwiftSyntax extraction is genuinely consumer-domain: the outer-call
  matcher (`Lint.run(dependencies:)`, hypothetical `Format.run(dependencies:)`)
  is a tool-specific call shape that doesn't naturally parametrize
  cleanly (the closure `Lint.run(dependencies: [...]) { ... }` vs.
  a plain call vs. a chained call all have different SwiftSyntax
  patterns); a parametric extractor leaks consumer-vocabulary into
  the generic API
- Magic-comment version-parser callback (`(Swift.String) -> Bool` or
  `(Swift.String) -> SomeVersion?`) is generic but the version type
  itself isn't — Lint's `Version.Tools` is one shape; another tool
  might parse semver, or a tool-pair tuple
- Configuration struct grows to ~12 fields with several callback
  parameters; large surface
- Promoting `Lint.SingleFile.PackageDependency` to the generic requires
  swift-manifests to depend on swift-package-primitives (currently it
  doesn't); not unreasonable but expands footprint
- Cascade is biggest of the four options

**Subordinate recommendation**: NOT recommended. The two "tied to source
content" concerns (magic-comment and SwiftSyntax extraction) are
genuinely consumer-domain — each tool's tools-version header and
each tool's call shape are tool-specific facts. Forcing them through
a generic API surface (parametric header string + callback parser +
parametric outer-call matcher) re-creates the dispatch logic via
configuration injection; the result is "Manifest.Executable.Configuration
is so parametric that it's a state machine encoding the consumer's
dispatch decisions." The maximal-reuse principle is satisfied
without absorbing these concerns (Option D).

---

### Option B: Extract helpers only

**Shape**: Promote a small set of helpers from `Manifest.Load`'s
internals — `_createDirectoryRecursive`, `_writeAtomic`, `_readEntireFile`
— to either `package`-scoped visibility or to a small new
`Manifest IO` target. Lint.SingleFile's `Materializer` routes IO
through these helpers but keeps its rendering, dispatch, magic-comment,
extraction, and parent-chain logic.

**Generic-side (swift-manifests) additions**:

- Either (a) promote three helpers from `@usableFromInline internal`
  to `public` on a new `Manifest IO Helpers` target — but they
  currently key on `Swift.String`, while Lint.SingleFile.Materializer
  keys on `File.Path`; reconciling requires duplicating both forms
  or migrating Manifest.Load to `File.Path` first
- Or (b) make them `package`-scoped within swift-manifests so Lint
  can depend on the same package and import them — **infeasible**:
  swift-linter and swift-manifests are separate packages, `package`
  visibility does not cross the package boundary

**Lint-specific side (swift-linter) retained**:

- Everything else stays in `Lint.SingleFile.*`

**Cascade scope**:
- swift-manifests: 0-3 files touched (visibility promotion +
  possibly a new target/product)
- swift-linter: 1 file touched (Materializer routes IO through
  swift-manifests' helpers — but only the bare-string variants;
  the typed-`File.Path` ones already exist locally)
- Estimated commits: 1 in swift-manifests + 1 in swift-linter

**Pros**:
- Smallest cascade; lowest risk
- No new design work

**Cons**:
- The duplication being saved is ~50 LoC of small file-IO wrappers
- Doesn't satisfy the maximal-reuse principle in spirit — the genuinely
  shared mechanics (`Package.swift` rendering, eval-project
  materialization, `swift run` spawn, stdio passthrough) all stay
  duplicated in Lint
- The `Swift.String` vs. `File.Path` mismatch means the helpers either
  need to be re-keyed on `File.Path` first (a separate workstream) or
  Lint.SingleFile.Materializer carries both representations
- Doesn't position swift-manifests for future single-file-manifest
  consumers — each new consumer re-implements the materialize+spawn
  loop from scratch

**Subordinate recommendation**: NOT recommended. The handoff explicitly
biases toward Option A unless the code reading reveals real friction;
Option B reveals minimal friction but also minimal reuse. It exists
as the conservative anchor; choosing it forfeits the architectural
opportunity Thread I represents.

---

### Option C: `Package.swift` builder generic; dispatch + header in Lint

**Shape**: Extract just the `Package.swift` rendering as a
`package`-scoped (or public, with care) builder type in swift-manifests
that takes a dep-list + target-list and emits the source. Lint.SingleFile
keeps its detect / dispatch / Materializer.materialize / spawn /
parent-chain logic but routes `renderPackageSwift` through the new
builder.

**Generic-side (swift-manifests) additions**:

- New file `Manifest.PackageSwiftBuilder.swift` (or similar — naming
  TBD; needs `[API-NAME-001]` Nest.Name compliance, candidate:
  `Manifest.Render.Package` — extends Manifest namespace with a
  Render nest containing a Package noun)
- Builder API:
  - Input: `Manifest.Render.Package.Configuration` (name, platforms,
    products, dependencies, targets, swiftLanguageModes,
    optionalEcosystemSettings, toolsVersion)
  - Input: dep list as `[Manifest.Render.Package.Dependency]` with
    `.path` / `.urlFrom` / `.urlRange` source variants
  - Output: `Swift.String`
- New product (or hidden in `Manifest Loader`?) — probably its own
  small `Manifest Render` target if other rendering primitives accrue

**Lint-specific side (swift-linter) retained**:

- Everything in `Lint.SingleFile.*` except the inline `renderPackageSwift`
  body, which becomes a builder invocation
- `Materializer.materialize` still calls `createDirectoryRecursive`,
  copies main.swift, writes Package.swift, etc.; only the string-of-
  Package.swift production routes through the builder

**Cascade scope**:
- swift-manifests: +2-3 new files (the builder + config + maybe error)
- swift-linter: 1 file touched (Materializer's renderPackageSwift
  replaced)
- Estimated commits: 1-2 in swift-manifests + 1 in swift-linter

**Pros**:
- Narrow, defensible extraction
- The `Package.swift` builder is a generally useful primitive (could
  serve other tooling — generators, scaffolders)
- Small cascade; reversible
- Carries the typed `Package.Name` / `Product.Name` model into
  swift-manifests via the builder's dep type

**Cons**:
- Most of the duplication-prone code (materialize loop, spawn, stdio,
  exit code) stays in Lint
- The `swift run` spawn + stdio passthrough is the lion's share of
  the value of a `Manifest.Executable` abstraction; Option C leaves
  it in Lint
- A future consumer (swift-format) would still need to re-derive
  the materialize+spawn loop from Lint's pattern

**Subordinate recommendation**: Acceptable as a conservative middle
ground, but inferior to D. The builder alone doesn't capture the
materialize→spawn→passthrough invariant; Option D does without
absorbing the consumer-domain concerns.

---

### Option D: Materialize + spawn + passthrough generic; magic-comment + extractor + parent-chain in Lint

**Shape**: Add `Manifest.Executable` as a third sibling generic in
swift-manifests. The seam is drawn at "the consumer hands the
generic a dep-list + an executable name + a source path; the generic
materializes a Package.swift + copies the source as main.swift +
spawns + passes stdio through + returns exit code." Everything tied
to source-content interpretation — magic-comment header, SwiftSyntax
extraction, parent-chain fold — stays in the consumer.

**Generic-side (swift-manifests) additions** — a new `Manifest Executable`
target:

- `Manifest.Executable.swift` — namespace + top-level
  `dispatch(configuration:) throws → Int32`
- `Manifest.Executable.Configuration.swift` — focused struct (~9 fields):
  - `consumerSourcePath: File.Path` — the file copied as main.swift
  - `evalRoot: File.Path` — where to materialize (consumer chooses
    the directory)
  - `executableName: Swift.String` — eval target name
  - `dependencies: [Manifest.Executable.PackageDependency]` —
    consumer-extracted dep list
  - `platforms: [Manifest.Executable.Platform]` — typed (or a passthrough
    `[Swift.String]` of PackageDescription tokens; favor typed)
  - `swiftLanguageModes: [Manifest.Executable.LanguageMode]`
  - `ecosystemSettings: Manifest.Executable.EcosystemSettings?` —
    optional trailing for-loop block (matches Lint's pattern)
  - `arguments: [Swift.String]` — forwarded to spawned executable
  - `environment: [Swift.String: Swift.String]?` — extra env vars
    (parent-chain envelope etc.)
  - `toolsVersion: Version.Tools` (or `Swift.String` if we don't pull
    swift-version-primitives in)
- `Manifest.Executable.PackageDependency.swift` —
  ```swift
  public struct PackageDependency: Sendable, Hashable {
      public enum Source: Sendable, Hashable {
          case path(Swift.String)
          case urlFrom(url: Swift.String, from: Swift.String)
          case urlRange(url: Swift.String, lower: Swift.String, upper: Swift.String)
      }
      public let source: Source
      public let name: Package.Name        // typed
      public let products: [Product.Name]  // typed
  }
  ```
  (promotes Lint's typed model verbatim; adds swift-package-primitives
  as a dep of swift-manifests)
- `Manifest.Executable.Materializer.swift` — `internal static` rendering
  (Package.swift + main.swift copy) routed through `File.Path`
- `Manifest.Executable.Error.swift` — `readFailed`,
  `materializationFailed`, `spawnFailed` (Lint's `missingToolsVersion`,
  `parseFailed`, `dependenciesNotFound`, `malformedPackageCall` stay in
  Lint — they're tied to magic-comment + extractor which are Lint-side)
- `exports.swift`

**New product**: `Manifest Executable`
**New dep**: `swift-package-primitives` (for typed Package.Name /
Product.Name)

**Lint-specific side (swift-linter) retained**:

- `Lint.SingleFile` namespace shell
- `Lint.SingleFile.header` constant
- `Lint.SingleFile.canonicalize(...)` — CLI boundary
- `Lint.SingleFile.parseMagicCommentToolsVersion` / `hasMagicComment` /
  `detect(at:)` — magic-comment detection (tool-specific header)
- `Lint.SingleFile.Extractor` — SwiftSyntax extraction tied to
  `Lint.run(dependencies:)` call shape (the SwiftSyntax dep
  legitimately belongs at the linter — SwiftSyntax is already a
  swift-linter dep)
- `Lint.SingleFile.PackageDependency` —
  `typealias Lint.SingleFile.PackageDependency = Manifest.Executable.PackageDependency`
  (collapses; or stays as a typed wrapper if Extractor's contract
  needs Lint-specific decoration)
- `Lint.SingleFile.dispatch(at:arguments:)` — orchestrator:
  1. Read source (Lint helper)
  2. Validate magic-comment (Lint helper)
  3. Extract deps via Extractor → `[PackageDependency]` (Lint
     SwiftSyntax)
  4. Resolve parent chain → temp file (Lint, unchanged)
  5. Build `Manifest.Executable.Configuration` with: evalRoot =
     `consumerRoot/.swift-lint/eval`, executableName = `"Lint"`,
     dependencies = extracted + linker-from-`SWIFT_LINTER_PATH`,
     platforms = `[.macOS(.v26)]`, swiftLanguageModes = `[.v6]`,
     ecosystemSettings = the canonical Linter set
     (ExistentialAny / InternalImportsByDefault / MemberImportVisibility
     / NonisolatedNonsendingByDefault),
     environment = `["SWIFT_LINTER_PARENT_MANIFEST": parentPath.string]`
     when present, arguments = consumer args
  6. Call `Manifest.Executable.dispatch(configuration:)` → exit code
- `Lint.SingleFile.resolveParentChain` / `foldParents` /
  `configuration(parentOf:)` — Lint-specific parent-chain logic,
  unchanged
- `Lint.SingleFile.Error` — Lint-specific cases stay; some cases
  may proxy through `Manifest.Executable.Error` (case mapping at the
  adapter boundary)

**Cascade scope**:
- swift-manifests: +6-7 new files (1 new target, 1 new product,
  +1 new dep on swift-package-primitives)
- swift-linter: 4 files touched
  - `Lint.SingleFile.swift` — dispatch becomes thinner; magic-comment
    + parent-chain stay
  - `Lint.SingleFile.Materializer.swift` — DELETED (its work moves
    to Manifest.Executable.Materializer); the SWIFT_LINTER_PATH lookup
    becomes a one-line read inside `dispatch` before building the
    Configuration
  - `Lint.SingleFile.PackageDependency.swift` — DELETED, replaced
    by typealias OR kept as the Extractor's typed return shape
  - `Lint.SingleFile.Error.swift` — cases that referenced
    materialization details may be replaced by proxying
    `Manifest.Executable.Error`
- Workspace cascade per `[HANDOFF-050]`: grep for `Lint.SingleFile.PackageDependency`
  (currently public) and `Lint.SingleFile.Materializer` usage —
  expected to find only in-package callers; external consumers use
  `Lint.SingleFile.detect/dispatch/configuration`
- Estimated commits: 2-3 in swift-manifests + 2-3 in swift-linter

**Pros**:
- Captures the genuinely-generic shape (materialize + spawn +
  stdio passthrough + exit code)
- Keeps consumer-domain concerns (magic-comment / SwiftSyntax
  extraction / parent-chain fold) in the consumer where they belong
- Does NOT pull swift-syntax into swift-manifests (heavy dep avoidance)
- Mirrors the existing sibling pattern: `Manifest.Load` (JSON-decode
  spawn-and-read), `Manifest.Resolver` (parent-chain walker),
  `Manifest.Executable` (consumer-spawn passthrough)
- Future consumers (swift-format with `Format.swift`, swift-doc with
  `Doc.swift`, swift-bench with `Bench.swift`) adopt by supplying
  their own header + extractor + configuration; the materialize+spawn
  is shared
- Promotes the typed-`Package.Name` / `Product.Name` dep model to
  the generic surface (Lint's typed shape becomes the generic shape)
- Aligns with `Manifest.Load`'s existing seam (it too is materialize
  + spawn, but with a different output contract — JSON decode vs.
  stdio passthrough)
- Modest Configuration struct (~9 fields) — focused, not parametric-
  decision-encoding

**Cons**:
- Bigger cascade than B or C (still smaller than A)
- Introduces a new swift-manifests dep on swift-package-primitives
  (typed Package.Name / Product.Name) — necessary but a new edge
- Two materialize-style code paths in swift-manifests
  (`Manifest.Load._materialize` for JSON-decode-spawn; new
  `Manifest.Executable.Materializer` for consumer-spawn). Possible
  future consolidation; out of Thread I scope
- The `ecosystemSettings` configuration field is a leaky abstraction
  (it's a `Swift.String` rendering of `SwiftSetting` entries to
  splice into the trailing for-loop) — but it's an honest leak: the
  ecosystem settings ARE consumer-tunable and ARE the natural
  parameterization point. Modeling them as typed values would
  require lifting the PackageDescription `SwiftSetting` API into
  the generic — out of scope

**Subordinate recommendation**: **RECOMMENDED**. Option D draws the
seam at the cleanest structural boundary:

- The "everything below source-content interpretation" half is
  materialize-spawn-passthrough mechanics — shared, generic-ready,
  matches `Manifest.Load`'s precedent.
- The "everything tied to source-content interpretation" half is
  magic-comment-header parsing + tool-specific call-shape extraction
  + tool-specific manifest-schema folding — consumer-domain, doesn't
  parametrize cleanly, and absorbing it into the generic produces
  Option-A's parametric-state-machine.

Option D matches `[ARCH-LAYER-011]`'s spirit (improve the foundation
where the gap actually is, not where it's superficially convenient)
and the maximal-reuse principle (re-use mechanics, not consumer
vocabulary).

---

## Decision factors summary

| Factor | A | D (rec) | C | B |
|---|---|---|---|---|
| Maximal-reuse fit | strongest | strong | medium | weak |
| Cascade size | biggest | medium | small | smallest |
| New deps in swift-manifests | swift-syntax + swift-package-primitives | swift-package-primitives | swift-package-primitives | none |
| Future-consumer pay-off | highest | high | medium | none |
| Configuration-API depth | ~12 fields + callbacks | ~9 focused fields | ~6 fields | n/a |
| Risk: consumer vocab leaks into generic | yes (header parser, outer-call matcher) | no | no | no |
| Reversibility | hardest | medium | easy | easiest |

---

## Subordinate recommendation: Option D

Reasoning condensed:

1. **The cleanest seam is materialize-vs-source-interpretation.** Everything
   below that seam (Package.swift rendering, main.swift copy, spawn,
   stdio passthrough, exit code) is mechanically the same across any
   tool-specific consumer. Everything above (magic-comment, SwiftSyntax
   extraction, parent-chain schema) is tool-specific by nature.

2. **Option A's parametric extraction leaks consumer vocab into the
   generic.** A SwiftSyntax extractor parametric on "find the outer
   call `Lint.run(dependencies: [...])`" cannot avoid encoding consumer
   call-shape into Manifest.Executable.Configuration. The "everything
   else" parameter list grows to model a state machine of consumer
   dispatch decisions. The generic ceases to be reusable in spirit
   even if it compiles.

3. **swift-syntax doesn't belong at swift-manifests.** swift-manifests
   is a small L3 foundation today (deps: swift-environment, swift-file-system,
   swift-json, swift-process, swift-strings, swift-uri-standard,
   swift-manifest-primitives). Adding swift-syntax (~120k LoC of
   parser/AST code) for a single consumer concern violates the
   "improve the foundation where the gap actually is" discipline.

4. **Manifest.Load's existing shape is the strong precedent.**
   Manifest.Load is a materialize-spawn primitive that does NOT
   handle magic-comments and does NOT extract deps from source —
   it takes the deps explicitly. Manifest.Executable as the sibling
   for "consumer-spawn with stdio passthrough" naturally inherits
   the same shape. Reading Manifest.Load.swift:43-95 next to
   Lint.SingleFile.swift:225-287 makes this convergence obvious.

5. **Parent-chain folding is irreducibly schema-specific.** The
   fold logic (`Lint.SingleFile.swift:381-395`) merges
   `Lint.Manifest.rules.enabled / disabled / excluded` — that's a
   linter-domain concept. A different tool's manifest would have
   different fields. Manifest.Resolver already provides the generic
   walker; the per-consumer fold stays in the consumer.

---

## Pre-existing gaps surfaced en passant

These do NOT block Thread I but are worth recording:

1. **`Manifest.NestedPackage` is Lint-coded under a generic name.**
   `swift-manifests/Sources/Manifest Resolver/Manifest.NestedPackage.swift`
   hardcodes `"<consumerRoot>/Lint"` and `swift run --package-path
   <lintPath> Lint`. Disposition options: parametrize (matches
   Option D's shape) or rename to `Lint.NestedPackage` and relocate
   to swift-linter. Suggest deferring to a follow-up cleanup arc.

2. **`Manifest.Dependency` is path-form only.** Adding Lint's
   `.path` / `.urlFrom` / `.urlRange` `Source` enum to
   `Manifest.Dependency` would unify the dep model, but
   `Manifest.Load` currently only emits `.package(path:)` lines.
   The unification is fair game during Phase I.1+ if Option D is
   chosen; alternative is to carry two dep models
   (`Manifest.Dependency` for Loader; `Manifest.Executable.PackageDependency`
   for Executable). The handoff's `[API-NAME-001]` discipline doesn't
   prohibit two models, but a unification arc would tidy the namespace.

3. **`Lint.SingleFile.Materializer` IO helpers duplicate
   `Manifest.Load`'s IO helpers** at typed-`File.Path` vs.
   bare-`Swift.String` key shapes. Option D collapses one side of
   the duplication; the residual is `Manifest.Load._writeAtomic` etc.
   on `Swift.String`. Migrating Manifest.Load to typed-`File.Path`
   keys is a separate post-D cleanup.

4. **`Manifest.Load`'s generated Package.swift carries 5 platforms;
   `Lint.SingleFile.Materializer` carries 1.** Option D's
   `Configuration.platforms` field makes this consumer-choice
   explicit, which is correct. Worth noting the divergence existed
   pre-D and was implicit.

---

## Cascade-scope estimates per option

| Option | swift-manifests | swift-linter | New deps in swift-manifests | Total commits |
|---|---|---|---|---|
| A | +7-8 files, +1 product, +2 deps | 5 files touched | swift-syntax + swift-package-primitives | 5-7 |
| **D** (rec) | **+6-7 files, +1 product, +1 dep** | **4 files touched** | **swift-package-primitives** | **4-6** |
| C | +2-3 files, ±1 product, +1 dep | 1 file touched | swift-package-primitives | 2-3 |
| B | 0-3 files, ±1 product | 1 file touched | none | 2 |

External-consumer impact: across all four options, the
`Lint.SingleFile.detect` / `dispatch` / `configuration(parentOf:)`
public surface in swift-linter is preserved bit-for-bit. The
materialized eval-project's spawn shape stays
`swift run --package-path <eval> Lint <args>` with the same
`SWIFT_LINTER_PARENT_MANIFEST` env var.

---

## Phase I.0 halt — awaiting principal sign-off

Principal: pick A / B / C / D. Subordinate recommends **D**.

After sign-off, Phase I.1 lands the generic-side surface; Phase I.2
rewires Lint.SingleFile as the adapter; Phase I.3 dogfeeds; Phase I.4
closes per the handoff template. Workspace-wide `[HANDOFF-050]` grep
runs at Phase I.2 end.
