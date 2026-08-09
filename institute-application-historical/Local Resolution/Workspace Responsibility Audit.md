# Workspace Responsibility Audit

**Gate:** 0A — pre-project repository and capability audit
**Repository:** `swift-institute/Workspace`, branch `main`
**Audited content:** working tree at `2c6787d47` + 12 uncommitted modifications, **committed mid-audit as `ef0579a8b`** ("Migrate Workspace Application GitHub-family sites to the Tagged API", 12 files, +82/−70). The committed content was verified to match what was read. **Cite this audit against `ef0579a8b`.**
**Date:** 2026-07-24
**Method:** direct source inspection, read-only. No file was altered by this audit.

---

## 0. Scope and reading notes

Production targets audited: `Workspace Application` (33 files, 1,480 lines) and
`Workspace CLI` (1 file, 4 lines). Every top-level declaration in both targets is
enumerated. Significant members are enumerated where they carry the
responsibility being classified; trivial stored properties, `init`s, and
`CustomStringConvertible` cases are grouped into their owning type's row.

Test-only helpers are grouped in §4, **except** where a helper reveals production
duplication or an unowned representation — those are given individual rows, per
the audit brief.

Classifications use only the allowed values:
*Institute policy — keep in Workspace*, *application orchestration — keep in
Workspace*, *presentation — keep in Workspace*, *generic representation — lower-layer
owner*, *generic external operation — lower-layer owner*, *duplicated semantic
capability*, *uncertain — adjudication required*.

**⚠ marker.** Eight of the twelve files that were uncommitted when read are in the
inventory subsystem (`Workspace.Inventory.Error`, `.Merge.Error`, `.Merge`,
`.Organization`, `.Policy.Error`, `.Policy`, `.Repository`, and
`Workspace.Repository.Key`). Rows W-14 through W-22 and W-28 are marked ⚠ to record
that they were read pre-commit; that content is now committed at `ef0579a8b` and
verified identical, so the marker is provenance, not instability.

**No Apple `Foundation` import exists in either production target** — verified by
`/usr/bin/grep -rln 'import Foundation'` over `Application/Sources/`, which
returns nothing. The corresponding release gate in `ARCHITECTURE.md` holds.

---

## 1. Declaration audit — `Workspace Application`

| # | Declaration | Module and file | Current role | Correct semantic owner | Classification | Evidence | Recommended disposition |
|---|---|---|---|---|---|---|---|
| W-01 | `Workspace` | `Workspace Application › Workspace.swift:1` | Root namespace enum (1 line) | Workspace | Institute policy — keep in Workspace | `public enum Workspace` | Keep |
| W-02 | `Workspace.Layer` | `Workspace.Layer.swift:4` | Five-case layer model + `order` + `JSON.Serializable` | Workspace | Institute policy — keep in Workspace | `case primitives/standards/foundations/components/applications`; `package var order` | Keep. The layer model is Institute architecture, not an external standard. |
| W-03 | `Workspace.Repository` | `Workspace.Repository.swift:4` | `name: Swift.String`, `url: Swift.String`, `layer: Layer` + `JSON.Serializable` | Workspace (shape) / `swift-git-standard` (the URL type) | uncertain — adjudication required | `public let name: Swift.String`, `public let url: Swift.String` | Keep the value; replace `url: Swift.String` with the Git remote-location type already named as required in `ARCHITECTURE.md:136`. No such type exists in `swift-git-standard` @ `ed8b3796c`. |
| W-04 | `Workspace.Repository.Key` ⚠ | `Workspace.Repository.Key.swift:5` | `(GitHub.Organization.Name, GitHub.Repository.Name)` pair; `url` synthesis; `init?(repository:)` URL parsing; `precedes(_:_:)` UTF-8 ordering | Workspace (the pair) / lower layer (the parsing) | duplicated semantic capability | `let prefix = "https://github.com/"`, `let suffix = ".git"`, `components.count == 2`, `components[1] == repository.name` | The pair is Institute policy — keep. The **URL parsing is a Git remote-location parser** written inline against two string literals; it hard-codes GitHub, rejects any non-`.git` spelling, and requires the repository basename to equal the declared name. Replace with the owner type once it exists. |
| W-05 | `Workspace.Configuration` | `Workspace.Configuration.swift:5` | `version`, `scope`, `swift`, `xcode`, `repositories`; `load(at:)`; `JSON.Serializable` with exact-key validation | Workspace | Institute policy — keep in Workspace | `public static func load(at root: File.Directory)`; `let expected: Set<Swift.String>` | Keep. `swift: Swift.String` / `xcode: Swift.String` are raw versions — `ARCHITECTURE.md:137` already names this as adjudication-pending. |
| W-06 | `Workspace.Configuration.Document` | `Workspace.Configuration.Document.swift:5` | Configuration + its exact bytes, for lost-update protection | Workspace | application orchestration — keep in Workspace | `public let bytes: [Byte]`; `public static func load(at:)` | Keep — publication concurrency is application policy. |
| W-07 | `Workspace.Configuration.rendered()` | `Workspace.Configuration+render.swift:4` | Deterministic JSON rendering with a round-trip decode check | Workspace | presentation — keep in Workspace | `let decoded: Self` re-decode before returning | Keep. Byte determinism currently rests on `serialize` building the object in fixed literal order, not on a `swift-json` guarantee — see Owner Capability Matrix §9.4 item 1. |
| W-08 | `Workspace.Configuration.validated()` | `Workspace.Configuration+validate.swift:2` | Rejects duplicate names and non-canonical keys | Workspace | Institute policy — keep in Workspace | `var names`, `var keys` | Keep |
| W-09 | `Workspace.Error` | `Workspace.Error.swift:2` | 5-case application error + `CustomStringConvertible` | Workspace | Institute policy — keep in Workspace | `.changed`, `.configuration`, `.filesystem`, `.process`, `.repository` | Keep. Note that `.process` is currently the sink for **both** Git failures and direct subprocess failures (see W-24, W-27), which loses the distinction. |
| W-10 | `Workspace.Action` | `Workspace.Action.swift:4` | Sync outcome: `.clone`, `.current`, `.update(Git.Object.ID)`, `.skip(String)`, `.fail(String)` + `.text` + `.fatal` | Workspace | Institute policy — keep in Workspace | `public var fatal: Bool` | Keep — this is the safety-severity policy the constitution §15 asks for. |
| W-11 | `Workspace.Inspection` | `Workspace.Inspection.swift:2` | `(Repository, Action)` pair | Workspace | Institute policy — keep in Workspace | 4 lines | Keep — this is the sync plan element. |
| W-12 | `Workspace.Inventory` | `Workspace.Inventory.swift:2` | Namespace enum (3 lines) | Workspace | Institute policy — keep in Workspace | `public enum Inventory` | Keep |
| W-13 | `Workspace.Inventory.Eligibility` | `Workspace.Inventory.Eligibility.swift:2` | Namespace enum (3 lines) | Workspace | Institute policy — keep in Workspace | — | Keep |
| W-14 | `Workspace.Inventory.Eligibility.Reason` ⚠ | `Workspace.Inventory.Eligibility.Reason.swift:4` | 7 exclusion reasons: `.archived`, `.disabled`, `.fork`, `.visibility`, `.denied`, `.absent`, `.kind` | Workspace | Institute policy — keep in Workspace | carries `GitHub.Repository.Visibility` and `GitHub.Repository.Content.Kind` from the owner package | Keep |
| W-15 | `Workspace.Inventory.Exclusion` ⚠ | `Workspace.Inventory.Exclusion.swift:2` | `(Repository.Key, Eligibility.Reason)` | Workspace | Institute policy — keep in Workspace | — | Keep |
| W-16 | `Workspace.Inventory.Discovery` ⚠ | `Workspace.Inventory.Discovery.swift:2` | `([Repository], [Exclusion])` result | Workspace | Institute policy — keep in Workspace | — | Keep |
| W-17 | `Workspace.Inventory.Organization` ⚠ | `Workspace.Inventory.Organization.swift:5` | `(GitHub.Organization.Name, Workspace.Layer)` | Workspace | Institute policy — keep in Workspace | — | Keep — the org→layer map is exactly Institute policy. |
| W-18 | `Workspace.Inventory.Policy` ⚠ | `Workspace.Inventory.Policy.swift:5` | `organizations`, `denied`, `limit`; `institute()` factory | Workspace | Institute policy — keep in Workspace | `public static func institute() -> Self` | Keep — the canonical statement of "which organizations constitute the Institute". |
| W-19 | `Workspace.Inventory.Policy.Error` ⚠ | `Workspace.Inventory.Policy.Error.swift:5` | `.organization`, `.deny` | Workspace | Institute policy — keep in Workspace | — | Keep |
| W-20 | `Workspace.Inventory.Repository` ⚠ | `Workspace.Inventory.Repository.swift:5` | `(GitHub.Repository.ID, Repository.Key, Layer)` | Workspace | Institute policy — keep in Workspace | — | Keep |
| W-21 | `Workspace.Inventory.Error` ⚠ | `Workspace.Inventory.Error.swift:5` | Generic over `Listing`/`Content`; `.cancellation`, `.repositories`, `.content`, `.collision`, `.path`, `.merge`, `.workspace` | Workspace | Institute policy — keep in Workspace | typed-throws error preserving cancellation distinctly | Keep — the cancellation case is tested (`Cancellation is not erased into a client failure`). |
| W-22 | `Workspace.Inventory.Merge` + `.Error` ⚠ | `Workspace.Inventory.Merge.swift:5`, `…Merge.Error.swift:5` | Merges discovered repositories into the existing inventory, preserving annotations, detecting duplicates, collisions, and owner transfers | Workspace | Institute policy — keep in Workspace | `callAsFunction(…)`; errors `.annotation`, `.duplicate`, `.collision`, `.transfer` | Keep — annotation preservation and transfer semantics are application policy. |
| W-23 | `Workspace.Inventory.Client` | `Workspace.Inventory.Client.swift:4` | Generic over `Listing`/`Content`; `discover(…)` paginating org repositories and probing for `Package.swift`; `reason(…)` | Workspace | application orchestration — keep in Workspace | `GitHub.Organization.Repositories.Client<Listing>`, `GitHub.Repository.Content.Client<Content>` | Keep — composes `swift-github` rather than reimplementing it. |
| W-24 | `Workspace.Inventory.Client.reason(…)` | `Workspace.Inventory.Client.swift:97` | Maps a GitHub summary to an eligibility reason | Workspace | Institute policy — keep in Workspace | `private static func reason(` | Keep |
| W-25 | `Workspace.Inventory.Application` | `Workspace.Inventory.Application.swift:4` | Orchestrates discover → merge → write | Workspace | application orchestration — keep in Workspace | `public func run(` | Keep |
| W-26 | `Workspace.Inventory.Writer` + `.Plan` | `Workspace.Inventory.Writer.swift:4`, `…Writer.Plan.swift:2` | `plan(…) -> .current \| .replace(String)`; `run(…)`; `read(_:)` | Workspace (plan) / `swift-file-system` (the read) | uncertain — adjudication required | `private func read(_ file: File) throws(Workspace.Error) -> [Byte]` containing a manual `for index in 0..<bytes.count { storage.append(bytes[index]) }` copy loop | Keep the dry-run plan. The **byte-copy loop is duplicated three times** across the target (W-26, W-30, W-33) — see §3.1. |
| W-27 | `Workspace.Inventory.client(…)` | `Workspace.Inventory+GitHub.HTTP.swift:5` | Constructs the concrete GitHub HTTP client | Workspace | application orchestration — keep in Workspace | generic over `Execution`, `Pagination` | Keep |
| W-28 | `Workspace.Sync` | `Workspace.Sync.swift:5` | 333 lines. `run(dry:)`, `inspect(…)`, `remoteContains(…)`, `update(…)`, `clone(…)`, `path(for:in:)`, `reference(_:)`, `execute(_:)` | Workspace (policy) / `swift-git` (mechanics) | application orchestration — keep in Workspace | `public func run(dry: Bool)` | Keep. The safety rules — clean, on `main`, tracking `origin/main`, not ahead, proven-descendant before fast-forward — are exactly the constitution §15 model and are Institute policy. All Git verbs go through `Git.Client`. |
| W-29 | `Workspace.Sync.remoteContains(…)` | `Workspace.Sync.swift:201` | Clones the remote bare into a same-filesystem temporary sibling and asks `ancestor(…)` | Workspace | application orchestration — keep in Workspace | `File.Path.Temporary.sibling(of:prefix:suffix:)`; `defer { try? temporary.delete.recursive() }` | Keep — correct composition of `swift-file-system` and `swift-git`. |
| W-30 | `Workspace.Sync.path(for:in:)` **and** `Workspace.Doctor.path(for:in:)` | `Workspace.Sync.swift:304`, `Workspace.Doctor.swift:136` | **Byte-identical private helper declared twice** | Workspace | duplicated semantic capability | both are `packages[directory: try File.Path.Component(repository.name)]` with the identical `catch` | Consolidate within Workspace. Not a lower-layer move. |
| W-31 | `Workspace.Sync.execute(_:)` **and** `Workspace.Doctor.execute(_:)` | `Workspace.Sync.swift:323`, `Workspace.Doctor.swift:147` | **Byte-identical private generic** mapping `Git.Client.Error` → `Workspace.Error.process` | Workspace | duplicated semantic capability | both `throws(Git.Client.Error) -> Result` wrappers | Consolidate within Workspace. |
| W-32 | `Workspace.Sync.reference(_:)` | `Workspace.Sync.swift:315` | Wraps `Git.Ref.Name(_:)` validation into `Workspace.Error` | Workspace | application orchestration — keep in Workspace | — | Keep |
| W-33 | `Workspace.Doctor` | `Workspace.Doctor.swift:7` | 157 lines. Toolchain, checkout, remote, upstream, branch, divergence, manifest-name and workspace-reference checks; error/warning severity split | Workspace | application orchestration — keep in Workspace | `public func run() throws(Workspace.Error)` | Keep the severity policy. Two specific behaviours need disposition — W-34 and W-35. |
| W-34 | `Workspace.Doctor.tool(_:arguments:)` | `Workspace.Doctor.swift:112` | **Spawns `swift --version` and `xcodebuild -version` directly** via `Process.Spawn.run` with `/usr/bin/env` | `swift-package-manager` (toolchain query); the coordinator (execution) | generic external operation — lower-layer owner | `executable: "/usr/bin/env"`, `arguments: [executable] + arguments`; call sites `Workspace.Doctor.swift:29,33` | **Replace Workspace-local use.** Two defects: (a) toolchain-version inspection is a `swift-package-manager` capability that does not exist (Owner Capability Matrix §3); (b) `xcodebuild` is invoked directly, which the machine coordinator exists to serialize. Version comparison is also `swift.contains(configuration.swift)` — substring matching, not typed version comparison. |
| W-35 | `Workspace.Doctor.package(at:)` | `Workspace.Doctor.swift:104` | Calls `packages.manifest(at:).name.underlying` and the caller compares it to `repository.name` under the label "manifest identity" | `swift-spm-standard` (identity) | uncertain — adjudication required | `let identity = try package(at: path)` then `if identity != repository.name { errors.append("\(repository.name): manifest identity is \(identity)") }` at `Workspace.Doctor.swift:88–91` | **Adjudication required.** `Package.Manifest.name` is the manifest **display name** (`Package(name:)`), not the SwiftPM package **identity**, which is derived from the resolved location basename (Owner Capability Matrix §1.3). Conflating them is the exact hazard the implementation plan's §10.2 forbids, live in production. The check happens to pass today only because display name equals repository name across the five inventory packages. |
| W-36 | `Workspace.Xcode` | `Workspace.Xcode.swift:5` | `document(_:)`, `render(_:)`, `path(at:)`, `current(_:at:)`, `write(_:at:)` | Workspace (membership policy) / `swift-xcode` (serialization) | application orchestration — keep in Workspace | `Xcode_Workspace.Xcode.Workspace(references: […])` | Keep membership selection. Two sub-findings: W-37, W-38. |
| W-37 | `Workspace.Xcode.document(_:)` reference construction | `Workspace.Xcode.swift:6–17` | Builds `.group("Application")` + `.group("Packages/\($0.name)")` by **string interpolation** | `swift-xcode` / `swift-xcode-standard` | uncertain — adjudication required | `.init(location: .group("Packages/\($0.name)"))` | The relative-path *policy* is Workspace's; composing a workspace-relative reference from a base and a package root is a `swift-xcode` capability that is absent (Owner Capability Matrix §6). Adjudicate whether the owner should gain a relative-reference constructor. |
| W-38 | `Workspace.Xcode.current(_:at:)` | `Workspace.Xcode.swift:26` | Verifies the generated workspace by reading the whole file and comparing **the entire string** to a freshly rendered one | `swift-xcode` (reference verification) | duplicated semantic capability | whole-file `contents == render(repositories)` byte equality, plus a manual `[Byte]` copy loop | **Replace Workspace-local use** once `swift-xcode` gains reference verification. Whole-file equality cannot distinguish "a reference is missing" from "the version attribute changed" or "whitespace differs", so its diagnostic in `Doctor` is only ever *"institute.xcworkspace does not match Workspace.json"*. |

## 2. Declaration audit — `Workspace CLI`

| # | Declaration | Module and file | Current role | Correct semantic owner | Classification | Evidence | Recommended disposition |
|---|---|---|---|---|---|---|---|
| W-39 | top-level `await Command.main(Workspace.CLI.self, initial: .init())` | `Workspace CLI › main.swift:4` | Entire executable target — 4 lines | Workspace | presentation — keep in Workspace | `import Command`, `import Workspace_Application` | Keep. The thin-executable split is correct and already exemplary. |
| W-40 | `Workspace.CLI` | `Workspace Application › Workspace.CLI.swift:6` | `Command.Protocol` conformance: `operation`, `dry`, `configuration`, `schema`, `validate()`, `run()` | Workspace | presentation — keep in Workspace | `Command.Positional(\.operation, …)`, `Command.Flag(\.dry, …)` | Keep. **Note the target placement**: the command schema lives in `Workspace Application`, not in `Workspace CLI`; only `main.swift` is in the executable target. The implementation plan's §13.3 assumes the CLI target holds the command schema. |
| W-41 | `Workspace.CLI.Operation` | `Workspace.CLI.Operation.swift:4` | `.sync` \| `.doctor` + `Argument.Codable` | Workspace | presentation — keep in Workspace | `argumentDescription` | Keep |
| W-42 | `Workspace.CLI.run()` workspace-root derivation | `Workspace.CLI.swift:49–56` | `Environment.read("PWD")` → `File.Directory(validating:)` | Workspace | uncertain — adjudication required | `guard let working = Environment.read("PWD")` | **Adjudication required.** The workspace root is taken from the inherited `PWD` environment variable. There is no ancestor-marker search and no explicit `--root`. The implementation plan's §12.1 requires commands invoked *inside* a context to infer that context from an ancestor marker; the current mechanism cannot support that, and `PWD` is not reliably set for every invocation path. |
| W-43 | Exit behaviour | `Workspace.CLI.swift`, `Workspace.Doctor.swift:96–103` | Failure is signalled by throwing `Workspace.Error`; `Doctor` additionally `print`s each warning and error | Workspace / `swift-arguments` | uncertain — adjudication required | `for warning in warnings { print(…) }`; `throw .repository("doctor found \(errors.count) error(s)…")` | **Adjudication required.** There is no exit-code category model. The implementation plan's §12.5 requires nine stable exit categories. Whether `swift-arguments` already provides an exit mapping was not established in this slice (Owner Capability Matrix §9.4 item 4). |

## 3. Cross-cutting findings within Workspace

### 3.1 The `[Byte]` read loop is written three times

```swift
var storage = [Byte]()
storage.reserveCapacity(bytes.count)
for index in 0..<bytes.count { storage.append(bytes[index]) }
return Swift.String(decoding: storage, as: Swift.UTF8.self)   // or: return storage
```

Occurrences: `Workspace.Configuration.Document.swift:22`,
`Workspace.Inventory.Writer.swift:42`, `Workspace.Xcode.swift:29`.

Classification: **duplicated semantic capability**. The disposition is *not*
"consolidate in Workspace" — the loop exists because `File.read.full { … }` hands
back a non-escaping buffer view and `swift-file-system` offers no
"read whole file as `[Byte]`" or "read whole file as `String`" convenience. That
is a lower-layer gap surfaced by Workspace, which is exactly the forcing-function
role the constitution §19 describes.

Recommended disposition: **extend `swift-file-system`**, then replace all three
Workspace sites.

### 3.2 Two private helpers are declared identically in two types

`path(for:in:)` and `execute(_:)` are byte-identical in `Workspace.Sync` and
`Workspace.Doctor` (W-30, W-31). Purely internal duplication; consolidate within
Workspace. No lower-layer implication.

### 3.3 `Workspace.Error.process` is overloaded

It is thrown for Git client failures (W-31), for direct subprocess failures
(W-34), and nowhere distinguishes them. Any future exit-category mapping (W-43)
will need this split.

### 3.4 The inventory subsystem is 18 of 33 files; local resolution is 0 of 33

| Subsystem | Files | Share |
|---|---:|---:|
| Inventory (discovery, policy, merge, writer, errors) | 18 | 55% |
| Sync | 1 (333 lines) | 3% |
| Doctor | 1 (157 lines) | 3% |
| Configuration | 4 | 12% |
| Xcode composition | 1 | 3% |
| CLI | 3 | 9% |
| Core values (`Workspace`, `Layer`, `Repository`, `Key`, `Action`, `Inspection`, `Error`) | 7 | 21% |
| **Context / resolution / graph** | **0** | **0%** |

`swift-package-graph` is not a dependency of `Workspace/Application/Package.swift`
@ `ef0579a8b`. No declaration in either production target references a package
graph, a dependency closure, a context, a resolution plan, or an effective source.

### 3.5 Manifest inspection is the only SwiftPM surface consumed

`Package.Manager` is used at exactly one site: `Workspace.Doctor.package(at:)`
(W-35). Workspace consumes no other SwiftPM capability.

---

## 4. Test-target helpers

Grouped, except where the brief requires an individual row.

| Helper | File | Grouping | Note |
|---|---|---|---|
| `Workspace.CLI.Test`, `Workspace.Inventory.Test`, `Workspace.Sync.Test`, `Workspace.Xcode.Test` + `.Unit` / `.Edge Case` / `.Integration` suites | `Workspace.CLI Tests.swift`, `Workspace.Inventory Tests.swift`, `Workspace.Sync Tests.swift`, `Workspace.Xcode Tests.swift` | Semantically equivalent suite scaffolding | Consistent `Type.Test.Category` convention throughout |
| `Workspace.Inventory.Test.Failure` | `Workspace.Inventory.Test.Failure.swift:4` | Test error type | — |
| `GitHub.Repository.Summary` fixture, `GitHub.Page.Number` / `Traversal.Limit` fixtures | `GitHub.Repository.Summary+fixture.swift`, `GitHub.Traversal.Limit+fixture.swift` | Owner-type fixtures | Extend `swift-github` types locally for tests; appropriate |
| `Workspace.Sync.Fixture.State` | `Workspace.Sync.Fixture.State.swift:7` | Test value | Uses `Foundation.Data` to snapshot `.git/FETCH_HEAD` |

### 4.1 Individually reported — `Workspace.Sync.Fixture` reveals unowned production capability

| # | Declaration | Module and file | Current role | Correct semantic owner | Classification | Evidence | Recommended disposition |
|---|---|---|---|---|---|---|---|
| T-01 | `Workspace.Sync.Fixture.command(_:at:)` | `Tests › Workspace.Sync.Fixture.swift:100–113` | Runs raw `git` subcommands through `Foundation.Process` at `/usr/bin/git` | `swift-git` | duplicated semantic capability | `let process = Foundation.Process()`, `process.executableURL = URL(fileURLWithPath: "/usr/bin/git")` | **Reveals unowned production capability.** The helper exists because `Git.Client` @ `a9955a9d9` exposes no `config`, no `branch -M`, no `add`, no `commit`, and no `push` / `push --force`. Every one of those verbs is used by the fixture. Recorded as evidence for extending `swift-git`, not as a Workspace defect. |
| T-02 | `Workspace.Sync.Fixture` filesystem work | `Tests › Workspace.Sync.Fixture.swift:1,17–35,84–88` | `import Foundation`; `FileManager.default.temporaryDirectory`, `UUID().uuidString`, `createDirectory`, `contentsOfDirectory`, `String.write(to:atomically:encoding:)` | `swift-file-system` | duplicated semantic capability | `base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)` | Production sources import no Foundation; the test target does, at three files. `File.Path.Temporary.sibling(of:prefix:suffix:)` is already used **in production** (`Workspace.Sync.swift:207`), so the capability exists and the test simply does not use it. Recommend migrating the fixture; no lower-layer gap. |

---

## 5. Disposition summary

| Classification | Count | Rows |
|---|---:|---|
| Institute policy — keep in Workspace | 17 | W-01…W-05, W-08…W-10, W-12…W-15, W-17…W-22, W-24 |
| Application orchestration — keep in Workspace | 9 | W-06, W-23, W-25, W-27, W-28, W-29, W-32, W-33, W-36 |
| Presentation — keep in Workspace | 5 | W-07, W-39, W-40, W-41 |
| Generic external operation — lower-layer owner | 1 | W-34 |
| Duplicated semantic capability | 6 | W-04, W-30, W-31, W-38, T-01, T-02 |
| Uncertain — adjudication required | 7 | W-03, W-26, W-35, W-37, W-42, W-43, and §3.1 |
| Generic representation — lower-layer owner | 0 | — |

**Reading.** Workspace is, at `ef0579a8b`, close to the constitution's target
shape: 31 of 43 production rows are correctly Workspace-owned policy,
orchestration, or presentation. There is exactly **one** unambiguous generic
external operation to move out (W-34, the direct `swift`/`xcodebuild` spawn), and
it is a small one.

The audit's substantive output is therefore not "Workspace is thick". It is:

1. **W-34** — the one real boundary violation, and it invokes `xcodebuild`
   outside the machine coordinator.
2. **W-35** — a live identity conflation (`manifest display name` presented as
   `manifest identity`) that the local-resolution project must not inherit.
3. **W-04** — a hard-coded GitHub URL parser standing in for an absent
   `swift-git-standard` remote-location type.
4. **§3.1 / T-01** — two capability gaps in `swift-file-system` and `swift-git`
   that Workspace and its tests surfaced by working around them, which is the
   forcing-function outcome the constitution §19 predicts.
5. **§3.4** — the local-resolution surface is 0% of the current codebase, and
   `swift-package-graph` is not yet a dependency. Every capability this project
   needs is new construction, not refactoring.

None of the above authorises API design. Each is a classification for the
adjudications the implementation plan's §17.2 requires before any code.
