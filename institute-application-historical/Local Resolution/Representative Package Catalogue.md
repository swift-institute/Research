# Representative Package Catalogue

**Gate:** 0A — pre-project repository and capability audit
**Date captured:** 2026-07-24
**Toolchain declared by the workspace inventory:** Swift 6.3.3, Xcode 26.6
**Machine-readable companion:** `Representative Package Catalogue.json` (schema 1, `sort_keys` serialisation, SHA-256 `9c869402d5a4251b4f1b72529b919be516b11a08917b0827ead7ef214e18bdd7` — recomputed 2026-07-26 after path generalisation; the as-captured hash was `c31a96964cf4841a21c3662de86c06f9ed3ae5c3f6d24134c87ad44747907573`)
**Method:** read-only. No build, test, or resolution command was executed.
**Path convention:** this repository is public; machine-specific path prefixes are rendered as `<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

---

## 1. Selection and why each package is representative

Seven packages. Every selection criterion in the audit brief is covered, and every
package is selected from repository evidence rather than by reputation.

| Criterion | Package | Why this one |
|---|---|---|
| Foundations package with an internal primitive dependency | **`swift-color`** | Reaches `swift-dimension-primitives` transitively through `swift-color-standard`. Head of the chain that `Workspace.json` itself declares as the public proof. |
| Standards package | **`swift-color-standard`** | A clean `-standard` convergence: it folds three spec-direct packages from three different authority organizations (`swift-iec-61966`, `swift-iso-9899`, `swift-ecma-48`) behind one stable module. |
| Non-trivial SwiftPM feature | **`swift-witnesses`** (macro target) | Declares the macro target `Witnesses Macros Implementation` — named verbatim in `Internal/XCWORKSPACE-INTEGRATION-EVIDENCE-2026-07-16.md` as the macro whose validation blocks Xcode workspace builds before compilation. Also the only catalogue package with a version-**range** requirement. |
| Non-trivial SwiftPM feature (second axis) | **`swift-html`** (traits) | Declares a `Translating` trait, two trait-conditional product dependencies, and a trait-conditional `.define`. Additionally computes its product and target names through a `String` extension. |
| Two independent roots | **`swift-color`**, **`swift-url-routing`** | Disjoint responsibilities, disjoint declared dependencies, and very different closure sizes (28 versus 172 resolved dependencies). |
| Transitive internal dependency chain | **`swift-color` → `swift-color-standard` → `swift-dimension-primitives`** | Spans all three active layers (Foundations → Standards → Primitives) and is the chain the public `Workspace.json` was built to prove. |
| Inventory-versus-disk divergence | **`swift-http-body`** | Declared in `Workspace.json` but absent from `Workspace/Packages/`. Included deliberately as the catalogue's live divergence case. |

`swift-url-routing` additionally carries the only **external remote dependencies**
in the catalogue (`apple/swift-collections`, `apple/swift-log`) and an opt-in
`URL Routing Foundation Integration` product, so it exercises both the
version-requirement forms and the Foundation-freedom boundary.

---

## 2. Catalogue

All revisions are on `main` with a clean working tree, and all declare
`swift-tools-version: 6.3.3`.

### 2.1 `swift-dimension-primitives`

| Field | Value |
|---|---|
| Organization | `swift-primitives` |
| Repository | `swift-dimension-primitives` |
| Canonical remote | `https://github.com/swift-primitives/swift-dimension-primitives.git` |
| Local path | `<developer-root>/swift-primitives/swift-dimension-primitives` |
| Branch / revision | `main` / `f123b8b8a` |
| Manifest display name | `swift-dimension-primitives` |
| **SwiftPM identity** | `swift-dimension-primitives` — **empirical**: observed as `packageRef.identity` in **five** inspected `.build/workspace-state.json` files, `kind=localSourceControl`, `location=<developer-root>/swift-primitives/swift-dimension-primitives` |
| Products | `Dimension Primitives`, `Dimension Primitives Test Support` |
| Targets | `Dimension Primitives`, `Dimension Primitives Test Support`, `Dimension Primitives Tests` |
| Platforms | macOS/iOS/tvOS/watchOS/visionOS v26 |
| Direct dependencies | 6, all `swift-primitives`, all `branch: "main"` — `swift-axis-primitives`, `swift-direction-primitives`, `swift-finite-primitives`, `swift-numeric-primitives`, `swift-pair-primitives`, `swift-tagged-primitives` |
| Plugins / macros / resources / binary targets / traits | none / none / none / none / none |
| Repository identity vs package identity | identical |

**Notes.** The library product `Dimension Primitives` (spaces) maps to module
`Dimension_Primitives` (underscores) by standing ecosystem convention. That is a
naming transform, not an identity ambiguity, but any tool projecting products to
modules must apply it.

### 2.2 `swift-color-standard`

| Field | Value |
|---|---|
| Organization | `swift-standards` |
| Repository | `swift-color-standard` |
| Canonical remote | `https://github.com/swift-standards/swift-color-standard.git` |
| Local path | `<developer-root>/swift-standards/swift-color-standard` |
| Branch / revision | `main` / `ba61bd79b` |
| Manifest display name | `swift-color-standard` |
| **SwiftPM identity** | `swift-color-standard` — **empirical**: `packageRef.identity` in two inspected state files, `kind=localSourceControl` |
| Products | `Color Standard`, `Theme` |
| Targets | `Color Standard`, `Color Standard Tests`, `Theme`, `Theme Tests` |
| Platforms | macOS/iOS/tvOS/watchOS/visionOS v26 |
| Direct dependencies | 4, all `branch: "main"` — `swift-primitives/swift-dimension-primitives`, `swift-iec/swift-iec-61966`, `swift-iso/swift-iso-9899`, `swift-ecma/swift-ecma-48` |
| Plugins / macros / resources / binary targets / traits | none |
| Repository identity vs package identity | identical |

**Notes — normalization concern.** This package spans **four organizations** in
one manifest. A repository projection that assumes "a `swift-standards` package
depends on `swift-standards` packages" is wrong here, and would be wrong across
the ecosystem: the machine's mirror map contains 122 `swift-standards` → `swift-ietf`
redirections alone.

### 2.3 `swift-color` — independent root #1

| Field | Value |
|---|---|
| Organization | `swift-foundations` |
| Repository | `swift-color` |
| Canonical remote | `https://github.com/swift-foundations/swift-color.git` |
| Local path | `<developer-root>/swift-foundations/swift-color` |
| Branch / revision | `main` / `0799a5711` |
| Manifest display name | `swift-color` |
| **SwiftPM identity** | `swift-color` — **empirical**: `packageRef.identity` in `swift-foundations/swift-html/.build/workspace-state.json`, `kind=localSourceControl` |
| Products | `Color` |
| Targets | `Color`, `Color Tests` |
| Platforms | macOS/iOS/tvOS/watchOS/visionOS v26 |
| Direct dependencies | 1 — `swift-standards/swift-color-standard`, `branch: "main"` |
| Resolved closure | **28 dependencies, all `localSourceControl`** |
| Plugins / macros / resources / binary targets / traits | none |
| Repository identity vs package identity | identical |

**Notes.** One declared dependency, 28 resolved — the ratio that makes local
composition hard to reason about without a graph. Product name `Color` is a common
noun; cross-graph target-name uniqueness is enforced by `[PKG-NAME-014]`, not by
anything in the manifest.

### 2.4 `swift-url-routing` — independent root #2

| Field | Value |
|---|---|
| Organization | `swift-foundations` |
| Repository | `swift-url-routing` |
| Canonical remote | `https://github.com/swift-foundations/swift-url-routing.git` |
| Local path | `<developer-root>/swift-foundations/swift-url-routing` |
| Branch / revision | `main` / `45548aaa5` |
| Manifest display name | `swift-url-routing` |
| **SwiftPM identity** | **UNESTABLISHED.** Root in every inspected build state; never resolved as a dependency, so no `packageRef.identity` was observed. Not asserted from basename or display name. |
| Products | `URLRouting`, `URL Routing Foundation Integration`, `URL Routing Test Support` |
| Targets | `URLRouting`, `URL Routing Foundation Integration`, `URL Routing Test Support`, `URLRoutingTests` |
| Platforms | iOS/macOS/tvOS/watchOS v26 (**no visionOS**) |
| Direct dependencies | 26 — 24 Institute at `branch: "main"`, plus `apple/swift-collections` `from: "1.0.3"` and `apple/swift-log` `from: "1.0.0"` |
| Resolved closure | **172 dependencies — 169 `localSourceControl`, 3 `remoteSourceControl`** |
| Plugins / macros / resources / binary targets / traits | none |
| Repository identity vs package identity | repository name matches directory basename; **package identity unestablished** |

**Notes — three normalization concerns.**

1. `URLRouting` and `URLRoutingTests` carry **no spaces**, unlike every other
   catalogue package. A tool deriving module names from product names by
   space-to-underscore substitution produces a different answer here.
2. **Mixed requirement forms in one manifest** — 24 branch-tracked and 2
   version-ranged. Remote-resolution validation must handle both, and only the
   version-ranged pair can fail on "required version does not exist".
3. It declares `swift-http-body`, which is in `Workspace.json` but has no clone
   under `Workspace/Packages/` — see note N-2.

### 2.5 `swift-http-body`

| Field | Value |
|---|---|
| Organization | `swift-foundations` |
| Repository | `swift-http-body` |
| Canonical remote | `https://github.com/swift-foundations/swift-http-body.git` |
| Local path | `<developer-root>/swift-foundations/swift-http-body` |
| Branch / revision | `main` / `eb62e8c3e` |
| Manifest display name | `swift-http-body` |
| **SwiftPM identity** | `swift-http-body` — **empirical**: `packageRef.identity` in two inspected state files, `kind=localSourceControl` |
| Products | `HTTP Body`, `HTTP Body JSON` |
| Targets | `HTTP Body`, `HTTP Body JSON`, `HTTP Body Tests`, `HTTP Body JSON Tests` |
| Platforms | macOS/iOS/tvOS/watchOS/visionOS v26 |
| Direct dependencies | 7 — `swift-standards/swift-http-standard`, five `swift-primitives`, `swift-foundations/swift-json`; all `branch: "main"` |
| Plugins / macros / resources / binary targets / traits | none |
| Repository identity vs package identity | identical |

### 2.6 `swift-witnesses` — macro target

| Field | Value |
|---|---|
| Organization | `swift-foundations` |
| Repository | `swift-witnesses` |
| Canonical remote | `https://github.com/swift-foundations/swift-witnesses.git` |
| Local path | `<developer-root>/swift-foundations/swift-witnesses` |
| Branch / revision | `main` / `8297968ac` |
| Manifest display name | `swift-witnesses` |
| **SwiftPM identity** | `swift-witnesses` — **empirical**: `packageRef.identity` in two inspected state files, `kind=localSourceControl` |
| Products | `Witnesses`, `Witnesses Macros`, `Witnesses Test Support` |
| Targets | `Witnesses`, `Witnesses Macros`, **`Witnesses Macros Implementation`** (`.macro`), `Witnesses Test Support`, `Witnesses Tests` |
| Platforms | macOS/iOS/tvOS/watchOS/visionOS v26 |
| Direct dependencies | 7 — six `swift-primitives` at `branch: "main"`, plus `swiftlang/swift-syntax` at **`"602.0.0"..<"603.0.0"`** |
| **Macros** | `Witnesses Macros Implementation` |
| Plugins / resources / binary targets / traits | none |
| Repository identity vs package identity | identical |

**Notes — why this package matters to the project.**
`Internal/XCWORKSPACE-INTEGRATION-EVIDENCE-2026-07-16.md` records that without
`-skipMacroValidation`, an Xcode workspace build "fails before compilation because
Xcode requires the `Witnesses Macros Implementation` macro to be enabled". Any
Xcode materialization design must therefore account for macro trust **by name**,
not as an abstract concern. It is also the only catalogue package whose external
dependency uses a version range, so it is the natural probe for remote-resolution
version enforcement.

### 2.7 `swift-html` — traits and computed manifest names

| Field | Value |
|---|---|
| Organization | `swift-foundations` |
| Repository | `swift-html` |
| Canonical remote | `https://github.com/swift-foundations/swift-html.git` |
| Local path | `<developer-root>/swift-foundations/swift-html` |
| Branch / revision | `main` / `d76cb8a99` |
| Manifest display name | `swift-html` |
| **SwiftPM identity** | **UNESTABLISHED.** Root in every inspected build state. |
| Products | `HTML` |
| Targets | `HTML`, `HTML Tests` |
| Platforms | iOS/macOS/tvOS/watchOS v26 (**no visionOS**) |
| Direct dependencies | 10, all `branch: "main"`, across `swift-foundations`, `swift-ietf`, `swift-primitives`, `swift-whatwg` |
| Resolved closure | **134 dependencies — 131 `localSourceControl`, 3 `remoteSourceControl`** |
| **Traits** | `Translating` — *"Include TranslatedString integration for internationalization support"* |
| Plugins / macros / resources / binary targets | none |
| Repository identity vs package identity | repository name matches directory basename; **package identity unestablished** |

**Notes — the strongest methodological finding in the catalogue.**

The manifest declares:

```swift
extension String { static let html: Self = "HTML" }
…
products: [ .library(name: .html, targets: [.html]) ]
```

A literal grep over `Package.swift` extracts `.html`. The real product and target
name is `HTML`. **This package alone proves that the catalogue cannot be built by
static text matching** — it requires `dump-package`, which is exactly what
`<developer-root>/CLAUDE.md` requires ("Parse manifests with the repository's
authoritative probe rather than a comment-blind, single-line grep").

It further declares trait-conditional dependencies:

```swift
.product(name: "Translating", package: "swift-translating",
         condition: .when(traits: ["Translating"]))
…
.define("TRANSLATING", .when(traits: ["Translating"]))
```

so the **effective** dependency set is not a function of the dependency list
alone. Any resolution plan that enumerates a package's dependencies must state
which trait configuration it enumerated under.

---

## 3. Identity methodology

Per the audit brief, package identity is **never** asserted from repository
basename, directory name, display name, lowercasing, or `.git` removal.

**Authoritative basis used.** Where an identity value is given, it is an observed
`packageRef.identity` in a pre-existing `.build/workspace-state.json` that SwiftPM
itself produced on this machine. Where no such observation exists, the value is
`null` in the JSON and the basis records why.

| Package | Identity | Basis | Observations |
|---|---|---|---|
| `swift-dimension-primitives` | `swift-dimension-primitives` | empirical | 5 state files |
| `swift-color-standard` | `swift-color-standard` | empirical | 2 state files |
| `swift-color` | `swift-color` | empirical | 1 state file (`swift-html`) |
| `swift-http-body` | `swift-http-body` | empirical | 2 state files |
| `swift-witnesses` | `swift-witnesses` | empirical | 2 state files |
| `swift-url-routing` | **unestablished** | root only | 0 |
| `swift-html` | **unestablished** | root only | 0 |

**Observation across the wider graph.** Over the 200 dependencies resolved for
`Workspace/Application`, `packageRef.identity == packageRef.name == basename(location)`
in **every** case — zero divergences. That is an observation about the current
graph, not a rule, and it is reported as such.

**Corroborating adjudication.**
`swift-institute/Research/Reflections/2026-07-22-canonical-package-topology-and-workspace-resolve-gate.md`:
*"The local directory basename is part of SwiftPM package identity when a package
is overridden by path. Renaming the physical checkout therefore has to move every
live workspace container path and mirror destination together."*

**Consequence.** Any context design that places a package checkout at a directory
whose basename differs from the canonical one changes that package's identity.

---

## 4. Collisions, ambiguities, and normalization concerns

### N-1 — Identity collisions

**None found** in the catalogue, and none found across the 200 resolved
dependencies of `Workspace/Application`: no identity maps to two locations, and
no two locations claim one identity.

### N-2 — Inventory-versus-disk divergence (live)

`Workspace.json` lists five repositories. `Workspace/Packages/` contains **four**:

| In `Workspace.json` | Present under `Workspace/Packages/` |
|---|---|
| `swift-dimension-primitives` | yes |
| `swift-color-standard` | yes |
| `swift-color` | yes |
| `swift-url-routing` | yes |
| `swift-http-body` | **no** |

`Workspace.Doctor` would report *"swift-http-body: missing or not a Git
repository"* as an **error**, and `Workspace.Xcode.current(…)` would report the
generated workspace as not matching, because `Workspace.Xcode.document(…)` emits a
`group:Packages/swift-http-body` reference for a directory that does not exist.

Recorded as a factual divergence in the current working state. Not remediated —
this audit is read-only.

### N-3 — One identity mapping to multiple URLs

Not observed among *current* manifests. It **is** structurally present in the
machine's mirror map: 1,256 entries spell every original twice (with and without
`.git`), so 628 repositories each have two URL spellings mapping to one local
directory, hence to one identity. Within this catalogue every declared Institute
URL uses the `.git` spelling consistently.

### N-4 — Renamed repositories

18 rename pairs exist in the mirror map, e.g.:

```
swift-github-types        -> swift-github-standard
swift-github-live         -> swift-github-http
swift-domain-type         -> swift-domain-standard
swift-emailaddress-type   -> swift-emailaddress-standard
swift-html-rendering      -> swift-html-render
swift-css-html-rendering  -> swift-css-html-render
```

**Liveness verified:** zero current `Package.swift` files under `swift-primitives`,
`swift-standards`, or `swift-foundations` declare any pre-rename spelling. The
aliases serve historical tags and pins only; they are **dormant** with respect to
HEAD manifests.

The corresponding **post-rename** identities (`swift-github-standard`,
`swift-github-http`, `swift-domain-standard`, `swift-emailaddress-standard`) all
appear as resolved identities in `Workspace/Application`'s state, confirming that
resolution follows the mirror target rather than the declared URL.

### N-5 — Inconsistent naming conventions across packages

| Convention | Followed by | Deviating |
|---|---|---|
| Spaced product/target names | 6 of 7 | `swift-url-routing` (`URLRouting`, `URLRoutingTests`) |
| Literal names in the manifest | 6 of 7 | `swift-html` (computed via `String` extension) |
| visionOS declared | 5 of 7 | `swift-url-routing`, `swift-html` |
| All dependencies branch-tracked | 5 of 7 | `swift-url-routing` (2× `from:`), `swift-witnesses` (1× range) |

### N-6 — Packages that cannot be treated as ordinary local dependencies

| Package | Why | Consequence for materialization |
|---|---|---|
| `swift-witnesses` | Compiler-plugin macro target `Witnesses Macros Implementation` | Xcode requires the macro to be enabled or `-skipMacroValidation` supplied; the failure occurs **before** compilation |
| `swift-html` | Trait-conditional dependencies and compilation defines | Its dependency closure is not determinable without stating the trait configuration |
| `swift-url-routing` | External version-ranged dependencies | Local path substitution bypasses the version constraint that remote validation must still enforce |

### N-7 — Non-package repositories, cycles, unsupported features

- **Non-package repositories:** none among the seven; all have a `Package.swift`.
- **Dependency cycles:** none detectable within the catalogue's declared edges.
  No graph-wide cycle analysis was run — that requires executing
  `swift-package-graph`, which is out of scope for a read-only Gate 0A.
- **Plugins, binary targets, resources:** **none** in any of the seven. If the
  project needs a resources or binary-target case, `swift-foundations/swift-certificates-n5`
  declares `resources:` and would be the candidate; it was not inspected in this
  slice and is therefore **not** claimed as representative.

---

## 5. What this catalogue does not establish

Recorded explicitly so no downstream reader over-reads it:

1. **Two of seven identities are unestablished.** `swift-url-routing` and
   `swift-html` are roots and were never resolved as dependencies. Their identity
   requires resolving a consumer, which requires a build.
2. **Imported modules are partial.** `materiallyRelevantImports` was read from
   manifest target dependencies, not from source `import` statements.
3. **No cycle, closure, or topological analysis was run.**
4. **No resources or binary-target case is covered.** See N-7.
5. **Closure sizes are from pre-existing `.build` state**, which reflects whatever
   the last resolution produced, not necessarily a resolution of the current HEAD
   manifests.
