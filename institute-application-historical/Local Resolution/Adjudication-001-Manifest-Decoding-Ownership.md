# Adjudication 001 — Manifest Decoding Ownership

**Phase:** 0 — focused architectural adjudications
**Date:** 2026-07-24
**Subject:** ownership of SwiftPM `dump-package` wire decoding, and disposition of the in-flight `swift-package-graph` migration
**Method:** read-only source inspection plus coordinator-approved `swift-build package dump-package` observations. No production source was modified. The dirty migration was preserved byte-for-byte (fingerprint verified before and after).
**Path convention:** this repository is public; machine-specific path prefixes are rendered as `<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

> **Terminology correction (2026-07-27):** Workspace is process/application
> tooling above the three realised package layers, not part of a realised fourth
> or fifth package layer. The ownership conclusions in this adjudication are unchanged.

---

## Capability

Converting the JSON emitted by `swift package dump-package` into the typed
`Package.Manifest` domain, and deciding which package owns each of the five
separable responsibilities involved.

## Correct semantic owner

Five responsibilities, deliberately **not** collapsed:

| # | Responsibility | Correct owner | Layer | Status today |
|---|---|---|---|---|
| 1 | The external `dump-package` **wire representation** | `swift-spm-standard` | 2 | Owned, partially modelled |
| 2 | **Decoding** that wire into `Package.Manifest` | `swift-spm-standard` | 2 | Owned **and duplicated twice below it** |
| 3 | **Invoking** the installed SwiftPM command | `swift-package-manager` | 3 | Owned |
| 4 | **Command failure and termination** reporting | `swift-package-manager` | 3 | Owned |
| 5 | **Graph discovery and construction** | `swift-package-graph` | 3 | Owned |

The controlling principle: (1) and (2) are properties of an **externally defined
format**, so they belong at Layer 2 with the representation. (3) and (4) are
properties of an **installed tool**, so they belong at Layer 3. They currently
occur in one function (`Package.Manager+Manifest.swift:8–60`); that is an
implementation accident, not an ownership argument.

## Current implementation or API

**Three decoders exist for one wire format.**

| # | Decoder | Location | Revision | State |
|---|---|---|---|---|
| A | `Package.Manifest.init(from:)` + `_DependencyWire` + `_SourceControlRecord` | `swift-spm-standard`, `Package.Manifest+Codable.swift:54–101` | `56f326cc5` | Committed, 55 passing tests |
| B | `Package.Manager.decode(_:)` — hand-written `JSON` DOM walk | `swift-package-manager`, `Package.Manager+Manifest.swift:66–104` | `d3dd30904` | Committed, **1** passing test |
| C | `Package.Manifest.decode(jsonBytes:)` — hand-written `JSON` DOM walk, 217 lines | `swift-package-graph`, `Package.Manifest.Decode.swift` | `a76186a9b` | **Deleted in the uncommitted migration** |

The migration (diff SHA-256 `3134766944144ab819a5311dc162f79a5fcb36790af4839a4d40159a240a3b84`)
deletes **C**, drops `swift-byte-primitives`, `swift-process` and `swift-json`
from the graph's manifest, adds `swift-package-manager`, and routes
`Package.Workspace.load(…)` through **B**.

### Field-by-field comparison of the three decoders

Established by reading all three sources. `—` means the field is not read at all.

| Wire field | A — `swift-spm-standard` Codable | B — `Package.Manager` | C — deleted graph decoder |
|---|---|---|---|
| `name` → package display name | ✅ decoded | ✅ decoded | ✅ decoded |
| `toolsVersion._version` | ✅ typed `Version.Tools` | ✅ typed `Version.Tools` | ✅ typed `Version.Tools` |
| `dependencies[]` | ✅ decoded | ✅ decoded | ✅ decoded |
| `fileSystem` (path-form) | ✅ → `.path(String)` | ✅ → `.path(String)` | ✅ → `.path(Paths.Path)` **— no longer type-checks, see below** |
| `sourceControl.location.remote[].urlString` | ✅ → typed `URI` | ✅ → typed `URI` | ✅ → typed `URI` |
| **`sourceControl.location.local[]`** | ❌ **throws** `keyNotFound("remote")` | ❌ **silently yields `URI("")`** | ❌ **silently yields `URI("")`** |
| `registry` (SE-0292) | ✅ → `.registry(Identity, Requirement)` | ✅ → `.registry(Identity, Requirement)` | ✅ → `.registry(Identity, Requirement)` |
| `requirement.exact` | ✅ | ✅ | ✅ |
| `requirement.range` | ✅ | ✅ | ✅ |
| `requirement.branch` | ✅ | ✅ | ✅ |
| `requirement.revision` | ✅ | ✅ | ✅ |
| `requirement.from` / `upToNextMajor` / `upToNextMinor` | ✅ (cases exist and round-trip) | ❌ not handled — falls through to `.typeMismatch` | ❌ not handled |
| **`products[]`** | ✅ → `[Manifest.Product]` | — **dropped** | — **dropped** |
| **`targets[]`** | ✅ → `[Manifest.Target]` | — **dropped** | — **dropped** |
| **`platforms[]`** | ✅ → `[SupportedPlatform]?` | — **dropped** (`nil`) | — **dropped** (`nil`) |
| **`Package.Dependency.products` back-fill** | ✅ second pass over `targets[].dependencies[]` | — always `[]` | — always `[]` |
| `traits` (top-level) | — not modelled | — | — |
| `traits` (per-dependency, `[{name:"default"}]`) | — not modelled | — | — |
| `productFilter` | — not modelled | — | — |
| `cLanguageStandard`, `cxxLanguageStandard`, `defaultLocalization`, `packageKind`, `pkgConfig`, `providers`, `swiftLanguageVersions` | decoded-and-discarded, documented | — | — |
| Unknown/extra keys | ✅ ignored, test: *"decodes dump-package output ignoring extras"* | ignored | ignored |
| Missing required key | ✅ `DecodingError` naming the key | `JSON.Error.missingKey(name)` | `JSON.Error.missingKey(name)` |

**The single most important row in this table is not a difference between B and C.
There is none.** B and C are field-for-field identical: neither reads
`products`, `targets`, `platforms`, or the back-fill (`grep -cE '"products"|"targets"|"platforms"|"traits"'`
returns **0** for both, and **4** for A). They differ in exactly one respect —
C constructs `.path(Paths.Path)` where B constructs `.path(Swift.String)`.

## Observed gap

### G-1 — The migration is a **repair of a build break**, not a discretionary refactor

`swift-spm-standard` commit `56f326c` — *"Repair SPM standard layer boundary"*, the
package's current HEAD — did two things:

```
-        .package(url: "https://github.com/swift-foundations/swift-paths.git", branch: "main"),
-                .product(name: "Paths", package: "swift-paths"),
```
```
-      case path(Paths.Path)
+      case path(Swift.String)
```

That honours `Workspace/ARCHITECTURE.md:105` — *"`swift-spm-standard` must not
regain its former upward dependency on `swift-paths`"* — by removing an L2 → L3
edge.

Decoder **C** constructs `Paths.Path` and passes it to `.path(…)`
(`Package.Manifest.Decode.swift:91–101`). `Paths.Path` is
`public struct Path: Copyable, Sendable, Hashable` (`swift-paths/Sources/Paths/Path.swift:37`),
not a `String` alias, and Swift has no implicit conversion.
`swift-package-graph` resolves `swift-spm-standard` at exactly `56f326cc5`
(its `.build/workspace-state.json`).

**Therefore decoder C cannot type-check against the standard it consumes.**
Restoring it would leave `swift-package-graph` unbuildable. This materially
changes the disposition: the migration is the *downstream half* of a layering
repair that is already committed upstream.

### G-2 — Neither operational path uses the authoritative decoder

The real defect predates the migration: **both** hand decoders recover three of
six modelled fields. The migration does not cause this and does not worsen it —
it consolidates two identical weak decoders into one.

> **Correction to earlier Gate 0A wording.** `Owner Capability Matrix.md` §4.1 and
> `Baseline Build and Test Evidence.md` §6.3 describe the migration as routing
> *"away from"* coverage that `swift-spm-standard` has. That is true of the
> coverage, but it implies a **regression**. There is none: the graph never had
> that coverage. Both documents are corrected accordingly.

### G-3 — `sourceControl.location.local` silently corrupts every mirrored dependency

**Wire evidence**, from `swift-build package dump-package --package-path …/swift-package-graph`
(exit 0, 12,079 bytes). One dump contains both shapes:

Un-mirrored dependency — `swift-package-manager` is one of the eight packages
absent from the mirror map:

```json
{ "sourceControl": [ {
    "identity": "swift-package-manager",
    "location": { "remote": [ { "urlString": "https://github.com/swift-foundations/swift-package-manager.git" } ] },
    "productFilter": null,
    "requirement": { "branch": [ "main" ] },
    "traits": [ { "name": "default" } ]
} ] }
```

Mirror-transformed dependency — five of the six deps in this manifest:

```json
{ "sourceControl": [ {
    "identity": "swift-paths",
    "location": { "local": [ "<developer-root>/swift-foundations/swift-paths" ] },
    "productFilter": null,
    "requirement": { "branch": [ "main" ] },
    "traits": [ { "name": "default" } ]
} ] }
```

Note the **structural asymmetry**: `remote` is `[{urlString: String}]`; `local` is
a bare `[String]`.

What each decoder does:

- **A** — `_Location` declares `let remote: [_Remote]`, non-optional
  (`Package.Manifest._SourceControlRecord._Location.swift:19`). Synthesised
  `Codable` therefore throws `DecodingError.keyNotFound("remote")`. **Loud failure.**
- **B and C** — `record["location"]["remote"].array ?? []` → empty →
  `urlString = ""` → `URI("")`.

`RFC_3986.URI("")` **succeeds**. From `swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.swift:461–467`:

```swift
// Same-document reference (RFC 3986 Section 4.4): the empty string is not
// itself matched by the URI-reference grammar, but is explicitly valid.
if stringValue.isEmpty { self.cache = Cache(value: stringValue); return }
```

corroborated by that package's own test `#expect(RFC_3986.isValidURI(""))`.

**Consequence:** on this machine — where 192 of 200 resolved dependencies are
mirrored — decoders B and C produce, for every mirrored dependency, a
`Package.Dependency` with the **correct identity**, the **correct requirement**,
and an **empty URL**, with no error and no diagnostic.

### G-4 — Blast radius is currently inert, and precisely latent

`Package.Graph` builds every edge from `dependency.name` alone
(`Package.Graph.swift:61–66`, `:188`), and **nothing in the graph reads
`.source`** — `git grep '\.source' HEAD -- Sources` returns no matches. So the
empty URI never reaches a graph query. That is why the 21 graph tests pass and why
real discovery works.

`Workspace.Doctor.package(at:)` reads only `.name`
(`Workspace.Doctor.swift:104–106`). Inert there too.

The corruption becomes live the moment any consumer reads
`Package.Dependency.source` — which is exactly what the declared-versus-effective
resolution report requires. **This is a trap laid for the next slice, not a
present outage.**

### G-5 — `Package.Dependency.Source` cannot represent the observed state

| `Source` case | Can it carry `location.local`? |
|---|---|
| `.path(Swift.String)` | No — drops the `Requirement` the wire carries |
| `.url(URI, Requirement)` | No — requires fabricating a `file://` URL absent from the wire, and erases the distinction between *declared as path* and *declared as URL, resolved locally* |
| `.registry(Identity, Requirement)` | No |

**The stop condition *"the current standard representation cannot express a
required SwiftPM state"* is met.** It is reported here, not worked around. This is
the same absence already logged as *"distinction between declared and effective
source"* in `Owner Capability Matrix.md` §2 — now with wire evidence.

Note what this implies about the format itself: **`dump-package` output is not a
faithful record of the declared manifest on a mirror-active machine.** It reports
a *resolved* location for a dependency the manifest declares by URL. Any type
claiming to model "the manifest" from this wire is modelling a machine-dependent
projection of it.

### G-6 — Test coverage cannot detect any of this

| Package | Coverage fact |
|---|---|
| `swift-package-manager` | Its **only** test decodes `Tests/Fixtures/Fixture`, whose `Package.swift` declares **no dependencies at all**. The test cannot detect *any* dependency-decoding defect. |
| `swift-spm-standard` | 55 tests, none covering `sourceControl.location.local` (grep for `location`+`local` in `Tests/` → no matches). |
| `swift-package-graph` | No test references `products`, `targets`, `platforms`, or the back-fill. `Package.Graph.Tests.swift` builds `Package.Manifest` values in memory and never invokes a decoder; the discovery tests assert manifest **counts and adjacency** only. |

### G-7 — Unmodelled wire fields (informational)

Observed in the dump but absent from `Package.Manifest`: per-dependency `traits`
(`[{"name":"default"}]`), `productFilter`, top-level `traits`, and on targets
`resources`, `settings`, `exclude`, `packageAccess`; on products, `settings`.
`Package.Manifest.Target` models `name`, `kind`, `dependencies`, `path?` only.
None is required by this adjudication; recorded so a later traits-aware slice does
not rediscover it.

## Proposed change

Four ordered changes. **None is implemented in this slice.**

1. **`swift-spm-standard` becomes the single authoritative decoder.**
   `Package.Manifest`'s `Codable` conformance is the one place the wire format is
   interpreted.
2. **`Package.Manager.manifest(at:)` invokes and delegates.** It keeps
   responsibilities 3 and 4 — spawn `dump-package`, map exit status to
   `Package.Manager.Error`/`.Termination` — and hands raw bytes to the standard
   decoder. Its hand-written DOM walk is deleted.
3. **`swift-package-graph` owns no decoder.** This is what the migration already
   does; it becomes correct once (2) lands.
4. **`Package.Dependency.Source` gains the ability to express a source-control
   dependency resolved to a local path**, so `location.local` decodes without loss
   and without silence. Shape deliberately unspecified here — that is a separate
   adjudication, and it is entangled with the declared-versus-effective question.
   Until it lands, decoding `location.local` must **fail loudly**, never yield
   `URI("")`.

## Why Workspace must not own it

Workspace is process/application tooling above the three realised package layers.
`dump-package` output is an **externally
defined format published by the Swift toolchain**; interpreting it is the defining
job of a Layer-2 standards package, and `swift-spm-standard` exists for exactly
that. A Workspace-local decoder would be a fourth implementation of a format
Workspace does not own, would need its own fixtures and version-skew handling, and
would make every other consumer of the graph depend on an application to read a
toolchain format. `Workspace/ARCHITECTURE.md` has already rejected the analogous
move once, refusing `swift-workspace-standard` on the ground that Institute
application policy is not an external standard — the converse applies here with
equal force.

Workspace's legitimate interest is downstream: it needs `Package.Manifest` to be
**complete and honest** so it can build a declared-versus-effective report. It has
no interest in how the JSON is walked.

## Dependency-layer impact

The proposed outcome requires **no new package and no new edge**:

```
swift-package-primitives (L1)
  → swift-spm-standard    (L2)   owns representation + decoding
    → swift-package-manager (L3) owns invocation + failure reporting
      → swift-package-graph (L3) owns discovery + graph construction
        → Workspace         (process/tooling) owns policy
```

- `swift-package-manager` **already** depends on `swift-spm-standard`
  (`Package.swift:13`), so change (2) adds no edge — it deletes code.
- `swift-package-graph → swift-package-manager` is an L3 → L3 edge. Permitted by
  `ARCHITECTURE.md`: *"Acyclic same-layer composition is permitted when the edge
  expresses semantic composition and does not manufacture a helper package."*
  `swift-package-manager` does not depend on `swift-package-graph`, so **no cycle
  exists**.
- The migration also *removes* three graph dependencies (`swift-byte-primitives`,
  `swift-process`, `swift-json`), shrinking the graph's surface.
- **No upward dependency is introduced.** The `swift-paths` edge that violated
  layering was already removed upstream by `56f326c`; that removal is the cause of
  this adjudication.

**No dependency cycle was found. The stop condition on cycles is not triggered.**

## Tests proving the boundary

Specified, **not written**. Four tests, three owners.

### T-1 — Graph preserves manifest content through the real discovery path

| Field | Value |
|---|---|
| Owner repository | `swift-foundations/swift-package-graph` |
| Fixture shape | A temporary on-disk package declaring at least **two products**, **three targets** (one of them a test target), an explicit **`platforms:` list**, and **one path-form dependency** on a second fixture package whose product the first target consumes by `.product(name:package:)` |
| Command path | `Package.Workspace.discover(at:)` → `Package.Manager.manifest(at:)` → `dump-package` → the standard decoder. The **real** path, not in-memory `Package.Manifest` construction |
| Assertions | `graph.manifest(for:)!.products.count == 2`; `.targets.count == 3`; `.platforms != nil` and non-empty; and the dependency's `products` contains the consumed product name (back-fill) |
| Why here | This is the only layer where discovery, invocation, and decoding meet. A test in `swift-spm-standard` proves the decoder; only this proves the **composition** delivers it |
| Fails under | The current dirty migration — all four assertions fail (`[]`, `[]`, `nil`, `[]`) |
| Passes under | The proposed ownership model |

### T-2 — `location.remote` decodes to the canonical URL

| Field | Value |
|---|---|
| Owner repository | `swift-standards/swift-spm-standard` |
| Fixture shape | Minimized JSON literal — the un-mirrored excerpt in G-3 |
| Assertions | Decodes to `.url(URI("https://github.com/swift-foundations/swift-package-manager.git"), .branch("main"))` |
| Why here | Pure wire-format behaviour, no subprocess |

### T-3 — `location.local` does not silently produce an empty URL

| Field | Value |
|---|---|
| Owner repository | `swift-standards/swift-spm-standard` |
| Fixture shape | Minimized JSON literal — the mirror-transformed excerpt in G-3 |
| Assertions | **Before change (4):** decoding throws a `DecodingError` naming `location`. **After change (4):** decodes to the new local-source-control case preserving path *and* `.branch("main")`. In neither state may it yield a `URI` whose value is `""` |
| Why here | The wire shape is the standard's responsibility |
| Note | This test is the guard that makes G-3 non-recurring |

### T-4 — `Package.Manager` decodes a manifest that actually has dependencies

| Field | Value |
|---|---|
| Owner repository | `swift-foundations/swift-package-manager` |
| Fixture shape | Extend `Tests/Fixtures/Fixture` — or add a sibling — so it declares at least one path-form dependency. It currently declares none |
| Assertions | The returned `Package.Manifest.dependencies` is non-empty and its single entry round-trips identity, source, and requirement |
| Why here | The package's sole test decodes a dependency-free manifest, so it cannot fail on any dependency defect. This closes that hole |

## Alternatives considered

| Alternative | Verdict |
|---|---|
| **Reject the migration; restore decoder C** | **Not viable.** C constructs `.path(Paths.Path)` against a standard whose case is `.path(Swift.String)` (G-1). Restoring it leaves `swift-package-graph` unbuildable, and re-adds an L3 dependency the upstream layering repair deliberately removed |
| **Approve as written and stop** | Rejected. Leaves the silent `URI("")` corruption (G-3) in the single surviving operational decoder, on the exact path Workspace is about to depend on |
| **Keep two decoders; fix only `Package.Manager`** | Rejected. Preserves duplicate interpretation of an external format at Layer 3, which is what created this situation |
| **Move decoding up into `swift-package-graph`** | Rejected. Inverts the layering: a graph package would own a wire format |
| **Give Workspace its own decoder** | Rejected. See *Why Workspace must not own it* |
| **Introduce a new `swift-spm-wire` package** | Rejected. The new-package presumption stands; `swift-spm-standard` is the coherent owner and the change is additive |
| **Encode `location.local` as a synthesised `file://` URL in `.url`** | Rejected as the *modelled* answer. It fabricates wire content and erases declared-versus-effective. Acceptable only as an explicitly-named lossy projection, never as the decode result |

## Migration impact

**Disposition of the dirty `swift-package-graph` migration: keep it, do not commit
it yet.**

- It is **necessary** — reverting leaves the package unbuildable (G-1).
- It is **field-neutral** — it removes a duplicate of an equally weak decoder, not
  a stronger one (G-2).
- It is **not sufficient** — it consolidates onto the decoder carrying the silent
  `location.local` defect (G-3).
- It is **currently harmless** — nothing reads `.source` (G-4).

If it is committed before change (2), `swift-package-graph` ships with manifests
that silently carry empty URLs for every mirrored dependency and no products,
targets, or platforms. Nothing breaks today; the next consumer inherits the trap.

**Ordered production slices** (specified, none authorised or implemented):

1. `swift-spm-standard` — decode `sourceControl.location.local` without silence
   (throw, pending change 4). Add T-2 and T-3.
2. `swift-package-manager` — delete the hand-written walk; invoke, then delegate to
   the standard decoder. Add T-4.
3. `swift-package-graph` — commit the migration unchanged. Add T-1.
4. `swift-spm-standard` — the `Source` representation change for locally-resolved
   source-control dependencies, **after** its own adjudication.

Slices 1–3 are strictly ordered. Slice 4 is separable and gated.

## Stop condition or unresolved evidence

**One stop condition is met and is reported rather than worked around:**

> **The current standard representation cannot express a required SwiftPM state.**
> `Package.Dependency.Source` has no case for a source-control dependency whose
> location is a local path *and* which carries a `Requirement` (G-5). This is
> observable on any mirror-active machine and affects 192 of 200 dependencies in
> the reference graph.

Per the brief, this authorises *proposing* a representation change — change (4) —
and nothing more. It is **not** implemented here, and change (4) should not be
designed until the declared-versus-effective adjudication settles, because the two
are the same question seen from different ends.

**Stop conditions checked and NOT triggered:**

| Condition | Result |
|---|---|
| Dependency cycle from `swift-package-manager` consuming the standard decoder | **No.** The edge already exists; no cycle |
| `location.local` unobservable without mutating machine policy | **No.** Observed in one read-only `dump-package` invocation with mirrors untouched |
| The dirty graph migration changed during inspection | **No.** Fingerprint `31347669…40a3b84` verified identical before and after |
| A new package appears necessary | **No.** Every change is additive to an existing owner |
| Wire format differs materially by installed Swift version | **Unresolved — single-version evidence only.** All observations are Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`), `arm64-apple-macosx26.0`. Whether `location.local` appears in other versions is untested. It is a **stable and documented** SwiftPM behaviour under mirroring, not a 6.3.3 artifact, but this adjudication has one data point |

**Other unresolved evidence:**

- Whether `location.local` can appear for a dependency that is *declared* by path
  rather than mirror-transformed was not established: no unmodified fixture in
  scope declares a path-form dependency. `swift-manifests` **generates** one at
  runtime (`Manifest.Executable.Tests.swift:121` asserts on
  `.package(path: "../../../../swift-primitives-linter-rules")`), but that is
  generated, not a static fixture. Constructing one was out of scope.
- The `Package.Manifest.Target` / `.Product` models omit `resources`, `settings`,
  `exclude`, `packageAccess` (G-7). Not required here; not adjudicated.

---

## Recommendation

> # Approve only after specified correction
>
> Approve the `swift-package-graph` migration — it is a necessary repair of a build
> break created by the already-committed `swift-spm-standard` layering fix, and it
> is field-neutral rather than regressive. **Do not commit it before slice 2**,
> because it consolidates onto the decoder that silently yields an empty `URI` for
> every mirror-transformed dependency.
>
> Required corrections, in dependency order: **(1)** `swift-spm-standard` decodes
> `sourceControl.location.local` without silence; **(2)** `Package.Manager.manifest(at:)`
> invokes SwiftPM and delegates decoding to `swift-spm-standard`, deleting its own
> walk; **(3)** commit the migration unchanged and add the composition test T-1.
> Slice **(4)**, the `Source` representation change, is separable and gated on the
> declared-versus-effective adjudication.

---

## Status note — 2026-07-24

The `swift-package-graph` migration has been **committed** as
`8fbcdb8ec96723c1c2bbe469043c70dc99eb9dcd`, ahead of the correction order set
out above. What that commit does and does not establish:

- **Established.** It is a build repair. Decoder C no longer type-checks (it
  passes `Paths.Path` where the standard's case takes `Swift.String`), and the
  package builds and tests clean without it: fresh compile, 0 errors,
  0 warnings, 21 tests in 2 suites.
- **Established.** It is field-neutral *relative to what it replaced*. B and C
  are field-for-field identical (§ table above), so routing through
  `Package.Manager.manifest(at:)` loses nothing decoder C provided.
- **NOT established.** It is **not** the evaluation integration. `manifest(at:)`
  still uses decoder B. Therefore `products`, `targets`, `platforms`, and the
  dependency-product back-fill — all of which A preserves and B and C both drop
  — still do not reach graph discovery, and mirror-transformed
  `sourceControl.location.local` is still not observable on that path.

Correction (2)'s premise has also changed. `Package.Manager.manifest(at:)` is
now to be left as-is; the evaluation capability arrives as a **new sibling
operation**, `Package.Manager.evaluation(at:)`, returning
`Package.Manifest.Evaluation`. The Foundation-free `Swift.Decoder` that makes
this reachable from a Foundation-free L3 target now exists in `swift-json`
(`cb2e77dc49cd71f8d78966beac11484f7e940a34`) and is proven against a real
`dump-package` output carrying five `location.local` members and one
`location.remote`.

**Open:** final graph evaluation integration, gated on
`Package.Manager.evaluation(at:)`.
