> Commissioned exploratory research, delivered 2026-08-14. Committed to Research by the CI programme coordinator. Ratification and sequence: https://github.com/swift-institute/institute-continuous-integration/issues/35#issuecomment-5293015006

# Maximally composed Swift-Institute-native CI architecture

## I. Executive ruling

### Ruling

The terminal Swift Institute CI/control plane is a seven-layer composition:

```text
typed protocol and system owners
    ↓
Foundation-free capability implementations
    ↓
Git / GitHub / SwiftPM relations
    ↓
vendor-neutral CI algebra
    ↓
GitHub ↔ CI relation
    ↓
Institute CI and repository policy
    ↓
trusted application host and thin .github wiring
```

The current architecture does **not** satisfy that model. It has made substantial extraction progress, but extraction has not yet produced terminal ownership:

- `swift-continuous-integration` currently contains GitHub-specific and Institute-specific policy.
- `swift-github-continuous-integration` does not yet depend on the generic CI package and locally implements YAML.
- `institute-continuous-integration` owns CI policy, repository policy, repository inventory, gitignore policy, README policy, manifest-binding policy, schema correspondence, skill hygiene, process mechanics, filesystem mechanics, JSON mechanics and GitHub acquisition.
- `institute-repository-policy` and the embedded `Repository Policy` target in Institute CI are two active policy owners that have already diverged.
- `institute-continuous-integration-control` exports six semantic libraries in addition to its executable, although its only terminal responsibility is privileged application of already-owned semantics.
- `.github` still contains substantial parsing, validation, API access, downloading, hashing, process orchestration and policy interpretation.

That violates the doctrine’s requirements for one semantic owner, one canonical implementation, lawful relation ownership and `UNMEASURED` treatment of missing evidence. 

### Terminal allocation

| Unit | Terminal responsibility |
|---|---|
| `swift-continuous-integration` | Vendor-neutral plan, obligation, observation, evidence, receipt and verdict algebra. |
| `swift-github-continuous-integration` | The relation between generic CI and GitHub Actions, workflows, runs, jobs and checks. |
| `institute-continuous-integration` | Institute policy selecting operations, tiers, support obligations, exceptions and gating posture. |
| `institute-repository-policy` | Institute repository-governance predicates and desired-state schema. |
| `institute-application` | Fleet inventory, architecture facts, repository-policy/CI composition and unprivileged operational planning. |
| `institute-continuous-integration-control` | One private credential-bearing executable that acquires live state and applies already-typed plans and transactions. |
| `swift-institute/.github` | Triggers, schedules, GitHub permission envelopes, environments, explicit secret mapping and invocation of typed executables. |

### Decisive answers

1. **The generic CI package must be reduced and rebuilt around a measured-evidence algebra.**
2. **The GitHub CI package must become an actual relation owner by depending on generic CI.**
3. **The standalone repository-policy package is the sole policy-engine owner. The embedded copy must disappear.**
4. **Control remains a separate private package only because repository visibility, credential authority and trusted binary publication are independent application-boundary properties. It must cease exporting semantic libraries.**
5. **No local YAML parser, GitHub JSON parser, repository-coordinate parser, SHA parser, branch parser, package-graph parser or time parser remains in CI or Control.**
6. **No Foundation-family module remains anywhere in the terminal implementation closure.**
7. **No non-Institute Swift package remains in the terminal closure.**
8. **No non-GitHub external Action remains.**
9. **GitHub-owned `actions/*` may remain only as explicitly classified GitHub host primitives.**
10. **There is no logical contradiction preventing the requested end state. There are, however, four substantial missing implementation fronts: native cryptography/TLS, Swift-language syntax, Foundation-free HTTP transport, and removal of the installed Git executable from semantic application code.**

The doctrine requires owner-first completion rather than consumer workarounds and admits only `REUSE`, `EXPOSE`, `COMPLETE`, `COMPOSE`, `IMPLEMENT ONCE`, or `DO NOT IMPLEMENT`. 

---

## II. Evidence boundary

### Exact revisions

The final head snapshot was taken after the repositories moved during the investigation.

| Repository | Inspected revision |
|---|---|
| `swift-institute/.github` | `e9136a0462a3e53fafb5dbb397ad3a1bbbc14861` |
| `swift-institute/institute-continuous-integration` | `63a144ad4eb53eeed5354cb40a007b2eaa643c1f` |
| `swift-institute/institute-continuous-integration-control` | `77e5599729a2e23d06c1fc39ba3d922ff38613ee` |
| `swift-institute/institute-repository-policy` | `85f1e68106d6a30498077cc5ce6cb90b5d271409` |
| `swift-institute/institute` | `fd9931cff09901b15d3af8ef60ae59735ecb57a4` |
| `swift-institute/institute-application` | `e7b52d10d9b770c92dcd95a0b70119cecdadac97` |
| `swift-foundations/swift-continuous-integration` | `b8c34ab8e04926048f99030dc667a931731161ae` |
| `swift-foundations/swift-github-continuous-integration` | `75bb0e553797612ba991b3fcfc0a63b55d4be224` |
| `swift-foundations/swift-linter` | `c22a94761125414bab73249c629bdc0c22141e95` |
| `swift-foundations/swift-institute-linter-rules` | `4ae4c70e543d2848bceec4095bb7a2cd3b10a568` |

The latest `.github` tree and its exact workflow/action blob identities are recorded at the final revision.  Control’s latest manifest remained structurally unchanged while its live validation path advanced. 

### Repositories additionally inspected by capability

The owner search included, among others:

- `swift-file-system`
- `swift-paths`
- `swift-process`
- `swift-environment`
- `swift-json`
- `swift-yaml`
- `swift-time`
- `swift-time-primitives`
- `swift-time-standard`
- `swift-uuids`
- `swift-uri-standard`
- `swift-rfc-3986`
- `swift-http-standard`
- `swift-rfc-9110`
- `swift-github`
- `swift-github-http`
- `swift-github-standard`
- `swift-git`
- `swift-git-standard`
- `swift-package-manager`
- `swift-spm-standard`
- `swift-source`
- `swift-lexer`
- `swift-parsers`
- `swift-arguments`
- `swift-io`
- `swift-sockets`
- `swift-fips-180-4`
- `swift-agent-skills`
- `swift-async`
- `swift-console`
- `swift-xcode`
- `swift-xml`

### Instruments used

The commission inspected:

- manifests;
- exact Git trees and blob sizes;
- source declarations;
- target and product structures;
- workflow and composite-action source;
- repository-local rulesets;
- current commit heads;
- package owner candidates and positive controls;
- selected current source implementations;
- direct external dependency declarations.

### Evidence not available

The following are `UNMEASURED`, not clean:

1. **Exact SwiftPM resolved closure.** The scoped roots do not carry usable `Package.resolved` records at the frozen revisions.
2. **Compiled module and framework linkage.** The environment could not materialize and build the repositories, so `otool`, `readelf`, link-map and COFF import evidence was not produced.
3. **Complete source-import count across every transitive package.**
4. **Organization-level inherited rulesets.** The organization ruleset API was not readable; the repository-local `.github` ruleset was readable.
5. **The implementation state of `swift-foundations/swift-http-client`.** A repository exists, but no readable default-branch tree or manifest was returned.
6. **The contents and linkage of currently published private Control binaries.**
7. **Exact fleet-wide consumer counts and all live generated caller revisions.**
8. **Terminal after-migration line counts and binary sizes.**

The doctrine expressly requires unavailable probes and stop conditions to remain visible and prohibits treating unexecuted builds, sweeps or enumerations as passed. 

---

## III. Current dependency closure

### A. Direct package graph at the scoped roots

| Root | Direct package shape | Current architectural issue |
|---|---|---|
| `swift-continuous-integration` | One product and target; no package dependencies. | Internally owns GitHub event/ref/check concepts and Institute tier/platform policy despite claiming a vendor-neutral role.  |
| `swift-github-continuous-integration` | Base, workflow and validation products; depends on GitHub Standard. | It does **not** depend on generic CI, so it is not yet the GitHub-to-CI relation owner. It also embeds its own YAML implementation.  |
| `institute-continuous-integration` | CI, Canon, Validation, Inventory, Repository Policy, CLI and executable products. | Under-decomposed semantically and over-decomposed structurally. It owns multiple unrelated predicates and duplicates repository policy.  |
| `institute-repository-policy` | Repository Policy library and CLI; depends on byte primitives and FIPS. | Correct package-level owner candidate, but currently mixes repository semantics with Foundation-based GitHub transport and manual YAML parsing.  |
| `institute-continuous-integration-control` | One executable plus six library products. | Trusted execution, fleet semantics, GitHub transport, issue evidence and private verification are grouped by current location rather than semantic ownership.  |
| `institute-application` | Architecture model/facts/graph/index/validation/candidates/migration, GitHub relation, application and CLI. | It already has the correct broad application layer and most lower dependencies needed to absorb fleet semantics from Control.  |
| `swift-linter` | Depends on Institute packages plus `swift-syntax` and `swift-argument-parser`. | Two prohibited non-Institute implementation dependencies.  |
| `swift-institute-linter-rules` | Depends on `swift-syntax`. | The rule bundle inherits the missing Swift-language syntax owner.  |

### B. Proven non-Institute Swift package edges

The current closure has a proven minimum of three distinct non-Institute SwiftPM package identities:

| Package | Consumer | Capability |
|---|---|---|
| `swiftlang/swift-syntax` | Linter and linter rules | Swift parsing, concrete syntax and source locations |
| `apple/swift-argument-parser` | Linter CLI | Command-line parsing |
| `apple/swift-crypto` | FIPS 180-4 owner | SHA-1 and SHA-2 implementation |

The FIPS package explicitly states that no native Institute hash implementation exists and delegates its typed surface to pinned `swift-crypto`. 

These are a **proven minimum**, not an assertion that the unresolved full transitive graph contains exactly three external implementation packages.

### C. Foundation-family closure

Foundation-family implementation paths were directly observed in at least three scoped roots:

- Institute CI application mechanics;
- repository-policy GitHub transport;
- Control acquisition, audit, serialization, filesystem and process code.

The latest Control live-validation path still imports Foundation and uses:

- raw repository, pull, SHA, path and token primitives;
- `gh`;
- `git`;
- `FileManager`;
- `Data`;
- `JSONEncoder`;
- `URL`;
- regular-expression SHA/coordinate validation;
- integer process status;
- string dictionaries for authentication. 

The repository-policy client directly owns `URLSession`, `URL`, `Data`, JSON encoder/decoder and integer HTTP handling rather than composing GitHub HTTP. 

### D. GitHub Actions and host-tool closure

At the final `.github` head there are:

- **five workflow files**;
- **six local composite actions**;
- **81,271 bytes of workflow YAML**;
- **46,716 bytes of local composite-action YAML**;
- **127,987 bytes total** across those eleven execution files.

The exact sizes are in the final tree. 

#### GitHub-owned host primitives currently used

- `actions/checkout`
- `actions/cache`
- `actions/create-github-app-token`

These can remain only under the terminal host-primitive policy described below.

#### Non-GitHub external Actions currently used

- `step-security/harden-runner`
- `SwiftyLab/setup-swift`

The public and private workflows use both families directly. 

#### Downloaded or invoked external implementations

- Realm SwiftLint;
- Python;
- `pip`;
- `yamllint`;
- Git CLI;
- GitHub CLI;
- `jq`;
- `curl`;
- `sed`;
- `date`;
- `find`;
- `unzip`;
- `sha256sum`;
- platform package managers;
- Xcode and `xcodebuild`;
- Swift compiler, SwiftPM and `swift-format`;
- Swift container images and SDK artifacts;
- Android NDK.

The current lint workflow downloads and executes Realm SwiftLint independently of the Institute linter. 

The newly added Control publisher workflow installs `git`, `gh` and `jq`, validates SHAs in Bash, enumerates branch heads with `git ls-remote`, hashes them with `sha256sum`, uses `date`, constructs JSON with `jq`, builds the package and publishes through `gh`. 

### E. Current repository ruleset evidence

The readable repository-local `.github` ruleset protects `main` against deletion and non-fast-forward changes and requires pull-request review, but its retrieved rule body did not contain a required-status-check rule. Organization-level inherited rulesets are `UNMEASURED`. 

---

## IV. Primitive-obsession census

The relevant problem is not raw token frequency. It is primitives that cross semantic boundaries while carrying stable concepts.

### Current semantic primitives

| Primitive representation | Concept actually carried | Current location | Ruling |
|---|---|---|---|
| `String "swift-institute/foo"` | GitHub repository coordinate | CI, Control, workflows | Use typed GitHub owner/login/repository components; add a canonical coordinate product if absent. |
| `String "refs/heads/main"` | Git reference | Generic CI and workflow shell | Use `Git.Ref.Name`; compose a GitHub branch relation. |
| 40/64-hex `String` | Git object identifier | Generic CI, Control, Bash | Use `Git.Object.ID`. |
| `String "ci / matrix / ci-ok"` | GitHub check context | Generic CI and policy | New `GitHub.Check.Context`, owned by GitHub Standard; Institute relation supplies its value. |
| `String "windows-release"` | CI operation identity | Generic CI | `CI.Operation.ID`; platform and configuration remain separate endpoint concepts. |
| `String "build"/"full"/"exhaustive"` | Institute verification tier | Generic CI | Move to `Institute.CI.Tier`. |
| `[String]` legs | Finite operation set | Generic CI/workflow outputs | `Set<CI.Operation.ID>` or a typed plan collection. |
| `[String: String]` job results | Observations keyed by job name | Generic verdict | Typed `CI.Observation` collection keyed by operation identity. |
| `Bool private` | GitHub repository visibility | Workflows and Control | `GitHub.Repository.Visibility`. |
| `Bool continueOnError` | GitHub execution/advisory relation | Workflow AST | Typed GitHub expression/literal field; policy maps it to `CI.Obligation`. |
| `String path` | Filesystem path | All top-level packages | `File.Path`. |
| `String URL` | URI or URL | Policy and Control | RFC 3986 URI/typed GitHub endpoint. |
| `Int exitCode` | Process termination | Control/private verification | `Process.Status`. |
| `Int HTTP status` | HTTP status | Policy and Control | `HTTP.Status`. |
| `String timestamp` / `Date` | Instant or civil date | Control and exceptions | `Instant`, `Time`, RFC 3339/ISO 8601 owners. |
| `TimeInterval`/raw integer | Duration/deadline | retry/audit | Typed duration/deadline. |
| UUID string | UUID identity | receipts/inventory | `UUID` owner. |
| SHA-256 string | FIPS digest | manifests and publication | Typed FIPS digest, backed by a native Institute implementation. |
| permission dictionary | GitHub App permission set | Control and YAML | Typed `GitHub.Permission` and access level. |
| token `String` | Secret-bearing credential | Control | Typed non-renderable/redacted credential with authority and lifetime. |
| JSON dictionaries | GitHub responses, manifests, receipts | Control and workflows | Decode once at the GitHub/format boundary into typed models. |
| YAML nodes/mappings | Actions workflows | GitHub CI | Typed GitHub Actions model; raw YAML confined to codec owner. |
| raw package identities | SwiftPM package/dependency identity | Control | Existing SPM Standard identities. |
| raw image strings | OCI image reference and digest | workflow plan | Typed OCI image reference. |
| raw Swift version/SDK strings | Toolchain release and SDK artifact | installer action | Typed toolchain/SDK owner. |

### Top-level code classification

| Target | Intended categories | Current non-terminal categories |
|---|---|---|
| Generic CI | A, B | E, K, L plus GitHub and Institute policy |
| GitHub CI | C | F, I, K through local YAML and raw fields |
| Institute CI | B, C, D | E–M across package diff, inventory and validation |
| Repository Policy | B, C | F, H, I, K, L |
| Control | D | E–M are dominant in several paths |
| `.github` | Host D | F, H, I, J, K and L remain extensive |

The generic plan currently stores raw repository, ref, SHA, reason, event, platform and lint strings and performs manual event/ref/directive parsing.  Its legs and requirements use raw strings and even own the Institute’s required-check spelling.  

---

## V. Ideal top-level CI code

The following is the **proposed terminal API shape**, not a claim that these declarations already exist.

```swift
let invocation = try GitHub.CI.Invocation.current(
    environment: Environment.current
)

let subject = try await GitHub.CI.Subject.acquire(
    for: invocation,
    using: github
)

let plan = Institute.CI.Policy.current.plan(
    for: subject
)

let receipt = try await Institute.CI.Runner(
    packages: packageManager,
    lint: linter,
    formatting: formatter,
    toolchains: toolchains
).execute(
    plan,
    in: invocation.workspace
)

try await GitHub.CI.Checks.publish(
    receipt,
    for: invocation,
    using: github
)
```

The private path should differ only in trust acquisition:

```swift
let invocation = try GitHub.CI.PrivateInvocation.authenticate(
    environment: Environment.current,
    credentials: credentials
)

let subject = try await invocation.acquireSubject(using: github)
let plan = Institute.CI.Policy.current.plan(for: subject)
let receipt = try await runner.execute(plan, in: invocation.workspace)
try await invocation.publish(receipt, using: github)
```

### Meaning of each line

1. `GitHub.CI.Invocation` owns decoding the GitHub host boundary.
2. `GitHub.CI.Subject` composes:
   - repository coordinate;
   - exact commit object ID;
   - ref;
   - event kind;
   - visibility;
   - workspace path.
3. `Institute.CI.Policy` owns only Institute selection and obligations.
4. `Institute.CI.Runner` orchestrates package, linter, formatter and toolchain owners.
5. Generic CI owns plan/evidence/receipt/verdict laws.
6. GitHub CI owns publication as checks.
7. Control supplies credentials and transactional sequencing, not endpoint parsing or policy.

No top-level declaration should need to know:

- how a path is split;
- how a SHA is validated;
- how JSON is traversed;
- how an HTTP request is serialized;
- how a process is spawned;
- how an ISO timestamp is parsed;
- how a GitHub permission is spelled;
- how a Package manifest is evaluated;
- how a workflow YAML document is tokenized.

---

## VI. Canonical owner matrix

| Capability | Canonical owner | Current state | Disposition |
|---|---|---|---|
| Bytes and UTF-8 | Byte/text primitive owners | Existing | **REUSE** |
| Filesystem path | `swift-file-system` / path owner | Existing validated path | **REUSE** |
| File operations and atomic writes | `swift-file-system` | Existing | **REUSE / EXPOSE** |
| Environment | `swift-environment` | Existing | **REUSE** |
| Process status and spawning | `swift-process` | Existing but public config leaks strings | **COMPLETE** |
| Time, civil date, instant, duration | `swift-time`, time primitives and Time Standard | Existing, including RFC 3339 relations | **REUSE / EXPOSE** |
| UUID | `swift-uuids` | Existing | **REUSE** |
| URI | RFC 3986 and URI Standard owners | Existing | **REUSE** |
| JSON | `swift-json` | Existing Foundation-free core | **REUSE** |
| YAML | `swift-yaml` | Parser/composer exists; typed complete codec insufficient for GHCI | **COMPLETE** |
| HTTP messages/status | HTTP Standard/RFC 9110 family | Existing | **REUSE** |
| HTTP transport | `swift-http-client` over IO/sockets/TLS | Named owner lacks usable evidence | **COMPLETE** |
| TLS | RFC 8446 standard owner plus `swift-tls` implementation | No owner found | **IMPLEMENT ONCE** |
| SHA-1/SHA-2 | FIPS 180-4 | Typed owner exists but delegates to `swift-crypto` | **COMPLETE** |
| Git object ID and ref | `swift-git-standard` | Existing | **REUSE** |
| Git operations | `swift-git` | Foundation-free but shells to `/usr/bin/git` | **COMPLETE** |
| GitHub domain model | `swift-github-standard` | Repository identity/visibility exists; branch/check/workflow families incomplete | **COMPLETE** |
| GitHub HTTP relation | `swift-github-http` | Typed endpoint families exist; live coverage incomplete | **COMPLETE** |
| SwiftPM model | `swift-spm-standard` | Existing | **REUSE** |
| SwiftPM evaluation and graph | `swift-package-manager` | Existing capabilities; required graph snapshot API not exposed completely | **EXPOSE / COMPLETE** |
| Command-line grammar | `swift-arguments` | Existing Institute-native owner | **REUSE** |
| Swift-language syntax | New Swift-language standard and syntax implementation owners | Generic lexer/parser/source owners exist; concrete Swift owner absent | **IMPLEMENT ONCE** |
| Lint rules | `swift-linter` and rule packages | Existing but depend on SwiftSyntax | **COMPLETE** |
| Toolchain and SDK release | New `swift-toolchain` owner | No complete owner found | **IMPLEMENT ONCE** |
| OCI image reference | New OCI standards owner | No owner found | **IMPLEMENT ONCE** |
| Archive formats | New archive/format owners | No usable owner found | **IMPLEMENT ONCE**, or redesign distributions to avoid archives |
| Generic CI algebra | `swift-continuous-integration` | Existing representation is mislayered | **COMPLETE by replacement** |
| GitHub ↔ CI relation | `swift-github-continuous-integration` | Existing package does not yet compose generic CI | **COMPLETE** |
| Institute CI policy | `institute-continuous-integration` | Existing but mixed with lower mechanics | **COMPLETE by reduction** |
| Repository policy | `institute-repository-policy` | Duplicate active owner exists | **REUSE standalone; delete embedded** |
| Fleet/application semantics | `institute-application` | Appropriate application owner already exists | **COMPLETE / COMPOSE** |
| Trusted mutation | Private Control application | Exists but owns too many semantic libraries | **COMPLETE by reduction** |
| GitHub host wiring | `.github` | Exists but carries semantic implementation | **COMPLETE by deletion** |

Existing `File.Path` validates path identity, and the filesystem owner already has atomic-write semantics.   JSON already exposes a canonical RFC 8259 coder. 

---

## VII. Existing Institute reuse opportunities

These changes can begin without inventing new CI-local abstractions.

### Immediate replacements

| Current local mechanic | Existing owner |
|---|---|
| Path validation, joining, enumeration, temporary paths and atomic writes | `swift-file-system` |
| Process termination interpretation | `Process.Status` |
| Environment snapshots | `swift-environment` |
| JSON parsing/encoding | `swift-json` |
| URI parsing | RFC 3986/URI packages |
| Civil dates, instants, ISO 8601/RFC 3339 | Time packages |
| UUID generation/validation | `swift-uuids` |
| Git object-ID validation | `Git.Object.ID` |
| Git ref validation | `Git.Ref.Name` |
| Repository name, owner login and visibility | GitHub Standard |
| HTTP status/method/request/response | HTTP Standard |
| SwiftPM package/dependency identity and evaluated source | SPM Standard and Package Manager |
| Command-line parsing | `swift-arguments` |
| File and byte output | File System and byte primitives |

`Git.Object.ID` already validates SHA-1 and SHA-256 object-ID forms, and `Git.Ref.Name` already owns ref-name validity.  

GitHub Standard already defines typed owner logins, repository names and repository visibility.   

SwiftPM package identity, dependency declarations, evaluated locations and source-control source concepts already exist beneath CI.  

### API exposure rather than local adaptation

Several owner APIs still expose primitives. For example, `Process.Spawn.Configuration` uses raw executable paths, arguments, working-directory strings and an environment dictionary. The correct change is to complete that owner with `File.Path`, typed arguments and `Environment.Snapshot`, not to add a CI-local `Command` wrapper. 

---

## VIII. Upstream owner gaps

### Critical owner-completion programme

| Owner repository | Product/target | Required lawful operation | Why it belongs there | Required tests | Consumers unlocked |
|---|---|---|---|---|---|
| `swift-standards/swift-fips-180-4` | `FIPS 180-4` | Native incremental SHA-1/SHA-2, digest streaming and constant-time comparison | FIPS owns the algorithm and digest laws | NIST vectors, boundary lengths, incremental equivalence, endian and cross-platform fixtures | CI manifests, checksums, Git, publication |
| New FIPS/RFC crypto owners | Algorithm-specific products | HMAC, HKDF, AEAD, key agreement and signature primitives needed by TLS | Each algorithm has independent external authority and laws | Official vectors, negative controls, misuse resistance | TLS |
| New `swift-ietf/swift-rfc-8446` | `RFC 8446` | TLS 1.3 protocol model and state-machine laws | Protocol authority is IETF | Transcript, downgrade, alert, resumption and interop fixtures | Foundation-free HTTPS |
| New `swift-foundations/swift-tls` | `TLS` | Portable Swift TLS implementation over sockets/IO and canonical cryptography | Implementation relation over protocol and transport | Linux/Windows/Darwin interop, certificate-validation and failure fixtures | HTTP client, GitHub, downloads |
| `swift-foundations/swift-http-client` | `HTTP Client` | Request execution, streaming bodies, redirects, deadlines, pooling and TLS relation | HTTP transport is not GitHub-specific | RFC fixtures, redirect loops, partial bodies, cancellation, retry boundaries | GitHub HTTP, toolchain downloads |
| `swift-foundations/swift-yaml` | `YAML` | Complete byte/text coder, canonical emission, closed schema decoding and source spans | YAML syntax is not a GitHub CI concern | CRLF/LF, anchors, quotes, block scalars, duplicate keys, round-trip and rejection corpus | GitHub workflow model, skills, policy |
| `swift-standards/swift-github-standard` | `GitHub Standard` | Repository coordinate, branch, commit, workflow/run/job/check/ruleset/install IDs, permission/access-level and credential concepts | GitHub is external semantic authority | Accepted/rejected wire-value fixtures and endpoint identity tests | GHCI, policy, Control |
| `swift-foundations/swift-github-http` | `GitHub HTTP` | Checks, rulesets, App-token, pulls, releases, pagination, rate-limit and typed retry endpoints | Owns GitHub ↔ HTTP relation | Recorded wire fixtures, pagination and retry controls | Control and `.github` |
| `swift-foundations/swift-process` | `Process` | Typed executable path, working directory, environment, deadline, output and `exec` replacement | Process effects and termination laws belong here | Signals, large pipe output, cancellation, path errors, Windows quoting | CI runner, Git, tools |
| `swift-foundations/swift-git` | `Git` | Native operations required by Institute application, or removal of those operations from consumers | Current package is an adapter over an installed external implementation | Object/ref/tree/index/diff fixtures and Git compatibility corpus | Institute application and Control |
| `swift-foundations/swift-package-manager` | `Package Manager` | Typed evaluated graph and dependency snapshot API | SwiftPM owns package evaluation and graph facts | Manifest variants, mirrors, local paths, source-control and materialization fixtures | CI planning and GitHub snapshots |
| New Swift-language standard owner | Swift grammar products | Concrete Swift lexical/syntax model | Swift syntax has independent language authority | Compiler corpus, versioned grammar and recovery fixtures | Syntax implementation |
| New `swift-foundations/swift-language-syntax` | Swift syntax parser | Concrete syntax tree, parser, source locations and diagnostics over generic lexer/parser/source owners | Relation between Swift grammar and parsing mechanisms | Differential compiler fixtures, malformed-source recovery | Linter and formatter rules |
| `swift-foundations/swift-linter` | Linter | Consume Institute syntax owner and expose typed rule execution/receipt | Linter owns rule application, not syntax parsing | Rule parity, fixture corpus, source-location accuracy | CI quality gates |
| New `swift-foundations/swift-toolchain` | Toolchain/SDK | Release identity, version selection, artifact URL, checksum, SDK identity and installation | Toolchain distribution is a stable domain concept | swift.org metadata fixtures, checksum/refusal and platform tests | Windows, Android, static SDK jobs |
| New OCI standard owner | OCI image model | Image name, tag, digest and immutable reference | OCI grammar and digest binding are externally governed | OCI conformance corpus | Container planning |
| New archive owners | ZIP/tar/gzip products | Streaming archive reading/extraction with path-traversal protection | Archive format and extraction laws are independent | malformed archives, traversal, duplicate entries, checksums | SDK/tool publication |
| New CommonMark/Markdown owner | Markdown model/parser | Typed links and citations | Closure evidence must not implement Markdown ad hoc | CommonMark corpus and link edge cases | Issue/closure evidence |
| New Package URL owner | Package URL | Typed purl parsing and rendering | purl has an independent specification | official examples, percent encoding and invalid forms | Dependency snapshots |

### Foundation-free HTTP is a hard critical path

`swift-github-http` already models typed GitHub endpoints over `HTTP.Request` and `HTTP.Response`, but a Foundation-free live transport remains necessary. 

`swift-io` supplies a substantial Institute-native reactor/proactor and kernel substrate suitable for that implementation. 

On Darwin and Windows, system TLS APIs may be lawful implementation substrates beneath the canonical TLS owner. On Linux, silently introducing OpenSSL would violate the stated zero-external-implementation objective. A portable Institute-native TLS implementation is therefore part of the critical path unless the normative rule is deliberately changed.

### Native Git requirement

`swift-git` describes itself as Foundation-free but stores the executable as a raw string and invokes `/usr/bin/git` through `swift-process`. 

Under this commission’s actual-closure rule, that is an external implementation dependency. The shortest route is:

1. remove Git CLI dependence from CI and Control wherever GitHub HTTP or a prepared checkout provides the required fact;
2. complete only the native Git operations still required by `institute-application`;
3. retain `actions/checkout` separately as an explicit GitHub host primitive.

---

## IX. Domain-type architecture

### Domain replacement matrix

| Current primitive | Actual concept | Canonical owner | Existing type | Gap | Terminal disposition |
|---|---|---|---|---|---|
| `"swift-institute/foo"` | GitHub repository coordinate | GitHub Standard | Owner login and repository name exist | Coordinate composition/API | **COMPLETE** |
| `"refs/heads/main"` | Git ref | Git Standard | `Git.Ref.Name` | GitHub branch relation | **REUSE + COMPOSE** |
| 40/64-hex string | Git object ID | Git Standard | `Git.Object.ID` | None for identity | **REUSE** |
| `"ci / matrix / ci-ok"` | GitHub check context | GitHub Standard | No complete type found | `GitHub.Check.Context` | **COMPLETE** |
| `"windows-release"` | CI operation ID | Generic CI | Current string | `CI.Operation.ID` laws | **IMPLEMENT ONCE** |
| `"full"` | Institute tier | Institute CI | Current generic `Tier` | Move owner and narrow laws | **COMPLETE by move** |
| String platform | Target/runner/platform class | SwiftPM, target-triple and GitHub Actions owners | Partial | Separate currently conflated concepts | **COMPLETE / COMPOSE** |
| `Int32` exit code | Process status | Process | `Process.Status` | Better typed public config | **REUSE / COMPLETE** |
| integer HTTP status | HTTP status | HTTP Standard | `HTTP.Status` | None | **REUSE** |
| path string | Filesystem path | File System | `File.Path` | Process APIs must accept it | **REUSE / EXPOSE** |
| URL string | URI | URI/RFC 3986 | Typed URI family | GitHub endpoint integration | **REUSE / COMPOSE** |
| date string | Civil date | Time | Time components/calendar | Direct date-only codec where missing | **EXPOSE** |
| timestamp string | Instant/RFC 3339 | Time Standard | RFC 3339 relation exists | Ensure direct public codec | **EXPOSE** |
| duration number | Duration/deadline | Time/clock | Existing primitives | Retry API integration | **COMPOSE** |
| SHA-256 string | Digest | FIPS 180-4 | Typed digest | Native implementation | **COMPLETE** |
| UUID string | UUID | UUID owner | Existing | None | **REUSE** |
| permission string | GitHub permission | GitHub Standard | Incomplete | Finite permission/access model | **COMPLETE** |
| visibility string/Bool | Repository visibility | GitHub Standard | Existing enum | None | **REUSE** |
| token string | Credential | GitHub App/security relation | Incomplete | secrecy, redaction, authority, expiry | **COMPLETE** |
| raw JSON object | Wire/storage value | JSON + endpoint owner | JSON value/coder exists | Typed GitHub models | **COMPOSE** |
| raw YAML node | Workflow wire representation | YAML + GHCI | YAML parser exists | Typed workflow codec | **COMPLETE / COMPOSE** |
| package name string | SPM package identity | SPM Standard | Existing | None | **REUSE** |
| image string | OCI image reference | OCI owner | Absent | Full type family | **IMPLEMENT ONCE** |
| toolchain string | Swift toolchain release | Toolchain owner | Absent/incomplete | Full type family | **IMPLEMENT ONCE** |

### Genuinely new types and their laws

| Type | Independent semantic law |
|---|---|
| `CI.Operation.ID` | Unique within a plan and referentially valid for dependency edges and observations. |
| `CI.Obligation` | Determines whether failure or missing evidence affects the aggregate verdict; advisory and gating are not Boolean aliases. |
| `CI.Measurement` | Distinguishes measured pass, measured failure and unmeasured absence. |
| `CI.Evidence` | Binds a measurement to the exact operation, subject and admissible receipt. |
| `CI.Receipt` | Binds the evaluated plan and its evidence to exact subject identity and execution provenance. |
| `GitHub.Check.Context` | Has GitHub ruleset matching semantics and is not interchangeable with an arbitrary label. |
| `GitHub.Actions.Workflow.ID` | Carries GitHub endpoint identity and API authority. |
| `GitHub.Actions.Run.ID` | Carries run-specific lifecycle and endpoint operations. |
| `GitHub.Actions.Job.ID` | Carries job-specific endpoint identity; distinct from a display name. |
| `GitHub.Ruleset.ID` | Carries repository/organization ruleset authority and endpoint operations. |
| `GitHub.Permission` | Finite GitHub permission vocabulary paired with an access level. |
| `GitHub.Credential` | Secret-bearing, non-renderable identity with scoped authority and expiry. |
| `Institute.CI.PlatformSupport` | Encodes admitted platform classes and their gating obligations. |
| `Institute.CI.Exception` | Has exact subject, reason, authority and expiry; an expired exception cannot silently continue. |
| `Institute.Fleet.Layer` | Authored organizational architecture classification with one governing owner. |
| `Institute.Fleet.Status` | Authored lifecycle state with explicit transition laws. |
| `Swift.Toolchain.Release` | Binds version, release authority, platform and artifact catalogue. |
| `Swift.SDK.Artifact` | Binds SDK identity, target, checksum and immutable source. |
| `OCI.Image.Reference` | Binds registry/name/tag/digest under OCI grammar; a digest reference is immutable. |

Types such as `CIString`, `ValidatedString`, `PathString` or `SafeInt` are prohibited because they do not add domain laws.

### Lawful primitive boundaries

Primitives remain lawful at:

- JSON/YAML wire encoding;
- HTTP serialization;
- process ABI boundaries;
- filesystem syscall boundaries;
- environment-variable boundaries;
- reporting and human-readable diagnostics;
- generic algorithms that genuinely operate on strings, integers or bytes.

They should be decoded once into domain types before policy code sees them.

---

## X. Third-party elimination

### SwiftPM packages

| Current dependency | Elimination |
|---|---|
| `swift-syntax` | Implement Swift grammar and concrete syntax once at the Swift-language owners; migrate linter and rule packages; delete edge. |
| `swift-argument-parser` | Reuse `swift-arguments`; delete edge and manual CLI fallback code. |
| `swift-crypto` | Complete FIPS and other cryptographic owners with Institute-native implementations; delete edge. |

### External Actions

| Current Action | Terminal ruling |
|---|---|
| `step-security/harden-runner` | **REMOVE.** Current use is audit-only. Explicit permissions, ephemeral credentials, immutable inputs and typed receipts remain. A future normative egress-enforcement requirement must be implemented once at a host-security owner rather than retaining this action. |
| `SwiftyLab/setup-swift` | **REMOVE.** Replace through a typed Institute toolchain installer or a verified preinstalled runner toolchain. |
| `actions/checkout` | **RETAIN as GitHub host primitive**, pinned to a full SHA, with credentials disabled unless explicitly required. |
| `actions/cache` | **RETAIN as GitHub host primitive** only for approved immutable cache classes. It owns no semantic success predicate. |
| `actions/create-github-app-token` | **RETAIN as GitHub host primitive** until a GitHub-native credential mechanism displaces it; scope every mint exactly and revoke explicitly. |
| Other `actions/*` | Allowed only after explicit host-primitive classification and full-SHA pinning. |

### Downloaded and shell implementations

| Current implementation | Elimination route |
|---|---|
| Realm SwiftLint | Complete Institute linter rule parity and delete the job. |
| Python / `pip` / `yamllint` | Complete YAML owner and typed policy validation. |
| `gh` | GitHub HTTP and typed endpoint owners. |
| `jq` | JSON plus endpoint models. |
| `curl` | HTTP client. |
| `date` | Time owner. |
| `sha256sum` | FIPS digest owner. |
| `unzip` | Archive owner or artifact distribution redesign. |
| `find`, `cp`, `rm`, `sed` | File System and typed text/format owners. |
| direct Git CLI | Remove from CI/Control; complete native Git owner where genuinely required. |
| shell SHA/ref/coordinate regexes | Git/GitHub domain types. |
| shell GitHub API paths | GitHub HTTP. |
| `xcodebuild` | May remain a toolchain host authority, but invocation and result interpretation belong in an Xcode/toolchain relation owner. |
| `swift`, SwiftPM, `swift-format` | May remain compiler/toolchain substrate; top-level policy must invoke them through typed Institute owners. |
| Swift containers and SDKs | May remain toolchain/platform substrate only with immutable digest/checksum and typed provenance. |
| Android NDK | May remain platform SDK authority with immutable provenance. |

### Terminal external-dependency policy

The terminal Swift package closure contains:

```text
Swift Institute packages
Swift standard library
Swift compiler/runtime
lawful OS ABI modules
```

It contains zero:

```text
non-Institute SwiftPM packages
Foundation-family modules
third-party utility libraries
third-party parser libraries
third-party crypto libraries
third-party HTTP libraries
third-party process/filesystem libraries
```

Outside that closure, the only retained executable/platform authorities are explicitly classified:

- GitHub host primitives;
- the Swift toolchain;
- platform SDKs;
- Xcode;
- OS ABI and system facilities.

They are not represented as “eliminated”; they are recorded as lawful host or platform authorities.

---

## XI. Foundation elimination

| Foundation capability | Current use | Canonical replacement | Implementation boundary | Deletion proof |
|---|---|---|---|---|
| `FileManager` | enumeration, directories, deletion, file existence | File System | POSIX/WinSDK/Darwin ABI beneath File System | source scan + filesystem parity fixtures |
| `URL` | paths and HTTP endpoints | `File.Path`, URI and typed endpoint | URI owner / File System | no `URL` fields or constructors |
| `Data` | bytes, base64, JSON and file output | Byte primitives, RFC 4648, JSON, File System | raw buffers beneath owners | no Foundation `Data` symbols |
| `Date` | timestamps and expiry | Time/Instant | platform clock beneath Time | RFC 3339 fixtures |
| `Calendar` | civil dates | Time Calendar | calendar owner | leap-year and boundary fixtures |
| `UUID` | identifiers | `swift-uuids` | random/clock substrate beneath UUID owner | UUID corpus |
| `Process` | shell execution | `swift-process` | POSIX/WinSDK process ABI | no Foundation Process symbols |
| `Pipe` | output capture | Process/IO | descriptors/handles beneath owner | large-output/deadlock tests |
| `FileHandle` | standard IO | IO/File System | descriptors/handles | no Foundation IO |
| `JSONEncoder/Decoder` | receipts and API payloads | `swift-json` plus typed codecs | JSON owner | round-trip and malformed fixtures |
| `JSONSerialization` | untyped GitHub traversal | GitHub HTTP typed models | JSON boundary only | no dictionaries in application APIs |
| `URLSession` | GitHub HTTP | HTTP client + TLS | sockets/IO/TLS | endpoint integration tests |
| `FoundationNetworking` | Linux HTTP | same | native Institute transport | no module/link reference |
| `ProcessInfo` | environment and platform facts | Environment/toolchain owners | OS ABI | typed environment receipt |
| `Bundle` | resource lookup | Package/resource owner or File System | runtime/package substrate | no Bundle use |
| `NSError`, `URLError`, `NS*` | untyped error transport | domain-specific typed errors | owner-specific | public typed-error audit |
| `CoreFoundation` numeric coercion | JSON number interpretation | JSON number owner | JSON parser | no CoreFoundation import |

The Time ecosystem already contains typed time primitives and RFC 3339/ISO 8601 relations.  

### Required double proof

Foundation elimination is complete only when both independent instruments pass:

1. **Source/dependency instrument**
   - no Foundation-family imports;
   - no Foundation-family products;
   - no transitive package target importing Foundation into the closure;
   - no compatibility target linked into the executable.

2. **Compiled/link instrument**
   - Darwin load-command and autolink inspection;
   - ELF dynamic-section and symbol inspection;
   - Windows import-table inspection;
   - static-archive member inspection;
   - link-map receipt.

Removing top-level imports alone is insufficient.

---

## XII. Package/product/target redesign

### 1. `swift-continuous-integration`

#### Retain package

Its ecosystem identity is valid, but replace its current semantic model.

#### Delete or move

- `Tier` moves to Institute CI.
- GitHub event/ref handling moves to GitHub CI.
- required-check context moves to GitHub CI/Institute relation.
- platform roster and lint-bundle selection move to Institute CI.
- raw job dictionaries disappear.
- current `Leg.Family` string families disappear.

#### Terminal targets

```text
Continuous Integration
Continuous Integration Test Support
```

The production target owns only:

```text
Subject identity abstraction
Operation.ID
Obligation
Plan DAG
Observation
Evidence
Receipt
Verdict
deterministic aggregation laws
```

### 2. `swift-github-continuous-integration`

#### Retain package

It owns a genuine relation.

#### Required package edge

```text
swift-github-continuous-integration
    → swift-continuous-integration
```

That edge is absent today. 

#### Delete

- local YAML lexer/parser/emitter implementation;
- empty namespace-only base target;
- Institute organization baselines;
- Institute platform matrix and tier policy.

#### Terminal targets

```text
GitHub Continuous Integration
GitHub Continuous Integration Validation
```

The first owns workflow/check/run/job relations. The second owns deterministic structural GitHub-CI predicates where consumers need them independently.

Current workflow models expose raw `String`, `YAML.Node` and `YAML.Mapping` fields, forcing consumers back into format mechanics. Those public APIs must become typed.  

### 3. `institute-continuous-integration`

#### Retain package

It owns Institute CI policy.

#### Delete products/targets

- embedded `Repository Policy`;
- embedded repository-policy CLI;
- `Foundation Integration`;
- `Institute Continuous Integration Canon` as a separate target;
- `Institute Continuous Integration Contract` as a separate target;
- current Inventory product;
- validation predicates whose facts belong to linter, SwiftPM, repository policy or architecture tools.

#### Move

| Current content | New owner |
|---|---|
| gitignore policy | Repository Policy |
| README policy | Repository Policy or exact documentation-policy owner |
| skill hygiene | Agent Skills/linter |
| manifest binding | SwiftPM/package-graph authority |
| schema correspondence | Architecture/application owner |
| package diff acquisition | GitHub HTTP/SwiftPM relation |
| filesystem/process/JSON mechanics | lower owners |
| fleet inventory | Institute Application |
| GitHub workflow details | Institute GitHub CI relation target |

#### Terminal targets

```text
Institute Continuous Integration
Institute GitHub Continuous Integration
Institute CI Application
Institute CI Command
```

The core target remains provider-neutral. The GitHub relation target depends on core Institute CI plus GitHub CI. The application target composes executors. The command target is a thin `swift-arguments` route.

### 4. `institute-repository-policy`

#### Retain package as sole engine owner

The standalone package has independent governance, consumers and release identity.

#### Delete

- the embedded copy in Institute CI;
- Foundation-based HTTP client;
- manual workflow/YAML parser;
- raw GitHub coordinate and ruleset parsing.

The duplicate is already observably unsafe: the embedded caller policy admits a `tier` input while the standalone extracted copy does not.  

#### Terminal targets

```text
Institute Repository Policy
Institute GitHub Repository Policy
Repository Policy Command
```

The GitHub target is the relation between generic repository policy and GitHub repository/ruleset/workflow concepts.

Authored desired-state data may remain in `.github` only where it genuinely belongs to that GitHub control-plane deployment. The schema and predicates remain owned here; generated indexes must not become a second editable registry.

### 5. `institute-continuous-integration-control`

#### Retain repository/package because of the private trust boundary

The package boundary is justified by:

- private source/release visibility;
- credential-bearing execution;
- trusted binary publication;
- live mutation authority;
- independent deployment closure.

#### Delete every public library product

Current library products to retire:

```text
GitHub Control
Fleet Audit
Fleet Inventory
Fleet Convergence
Private Verification
Closure Evidence
```

Their dispositions are:

| Product | Terminal disposition |
|---|---|
| GitHub Control | Reduce into GitHub Standard/GitHub HTTP and private host composition |
| Fleet Audit | Move predicates to exact owners; orchestration to Institute Application |
| Fleet Inventory | Move to Institute Application |
| Fleet Convergence | Move plan semantics to Institute Application; retain application of plan in Control |
| Private Verification | Move request/evidence/verdict semantics to Institute CI/GitHub CI; retain credential transport |
| Closure Evidence | Move issue/evidence semantics to Institute Application/repository governance relation |

#### Terminal package

```text
one executable product
one internal application target, if compile visibility requires it
zero public library products
```

Its mission is the credential-bearing transaction:

```text
authenticate
acquire typed live state
invoke a typed plan
apply an authorized mutation
publish a typed receipt
destroy credentials and sensitive workspace
```

It does not own the plan, policy, GitHub model, JSON, filesystem, process or evidence vocabulary.

### 6. `institute-application`

#### Complete as the public application/control-plane composition owner

Move here:

- fleet census;
- fleet inventory;
- architecture facts;
- desired-state derivation;
- audit planning;
- convergence planning;
- issue/closure planning;
- composition between repository policy and CI policy.

Its current manifest already exposes architecture model, facts, graph, index, validation, candidates and migration products and imports the lower Institute owners required for this role. 

### 7. Linter packages

#### Retain

- `swift-linter`
- `swift-linter-rules`
- `swift-institute-linter-rules`

#### Replace dependencies

- `swift-syntax` → Institute Swift-language syntax owner.
- `swift-argument-parser` → `swift-arguments`.

#### Delete

- Realm SwiftLint CI path after parity;
- Foundation-integration exemptions that no longer describe an admitted architecture;
- local source parsing in rule packages.

### 8. `.github`

All six current local composite actions should disappear after typed tool completion:

```text
central-style
ci-subject
configure-private-repos
install-swift-sdk
install-system-deps
institute-ci
```

They currently own semantic copying, subject validation, credential wiring, toolchain resolution, package provisioning and binary provenance mechanics. The terminal workflows should call one typed executable rather than distribute those mechanics among composite actions.

---

## XIII. Terminal dependency graph

```text
Swift standard library / compiler / runtime
Glibc / Musl / WinSDK / Darwin system ABI
    ↓
byte, text, path, time, clock, environment, error, collection primitives
    ↓
RFC 3986 / RFC 9110 / RFC 3339 / RFC 8446
FIPS cryptographic standards
Git Standard / SPM Standard / GitHub Standard
Swift-language grammar
YAML / JSON / OCI / archive specifications
    ↓
File System
Process
Time
UUID
JSON
YAML
IO / Sockets
Cryptography
TLS
HTTP Client
Git
SwiftPM
Swift-language Syntax
Linter
Toolchain / SDK
    ↓
GitHub HTTP
GitHub ↔ SwiftPM relation
GitHub ↔ Git relation
    ↓
swift-continuous-integration
    ↓
swift-github-continuous-integration
    ↓
Institute Continuous Integration
Institute GitHub Continuous Integration
Institute Repository Policy
Institute GitHub Repository Policy
    ↓
institute-application
    ↓
institute-continuous-integration-control
    ↓
swift-institute/.github
```

### Exact important edges

```text
swift-github-continuous-integration
    → swift-continuous-integration
    → lower neutral owners

Institute GitHub Continuous Integration
    → Institute Continuous Integration
    → swift-github-continuous-integration

Institute GitHub Repository Policy
    → Institute Repository Policy
    → GitHub Standard
    → GitHub Continuous Integration Workflow model

institute-application
    → Institute CI
    → Institute Repository Policy
    → Institute GitHub relation targets
    → architecture/fleet owners

Control
    → institute-application
    → Institute GitHub CI
    → GitHub HTTP
    → File System / Environment
```

No lower package depends on Institute policy. No policy package owns credentials. No Control package redefines lower predicates. No `.github` YAML parses domain data.

---

## XIV. Top-level package missions

| Package | One-sentence terminal mission |
|---|---|
| `swift-continuous-integration` | Own the provider-neutral algebra that turns a finite plan and admissible observations into evidence and a verdict. |
| `swift-github-continuous-integration` | Own the relation between generic CI concepts and GitHub Actions, workflows, runs, jobs and checks. |
| `institute-continuous-integration` | Own the Institute policy that selects CI operations and obligations for a typed subject. |
| `institute-repository-policy` | Own the Institute’s repository-governance desired state and deterministic repository predicates. |
| `institute-application` | Compose Institute facts and policies into unprivileged operational plans. |
| `institute-continuous-integration-control` | Apply authorized Institute plans to live GitHub state through private credentials. |
| `swift-institute/.github` | Host GitHub-native triggers, permissions, secrets and invocation wiring. |

---

## XV. `.github` / GitHub Actions terminal surface

### Current state

The final head contains five workflows and six composite actions. The newest workflow alone contains:

- Bash SHA validation;
- package installation;
- Git branch-head enumeration;
- raw dependency-head hashing;
- JSON construction with `jq`;
- static binary build;
- release creation and upload;
- manual timestamp and manifest production. 

The review transaction similarly parses repository coordinates, JSON plans, GitHub API payloads and exact revisions in shell and `jq`. 

### Terminal `.github` contents

`.github` may retain:

```text
workflow triggers
workflow_call inputs that are irreducibly GitHub-host fields
schedules
job permission envelopes
environment selection
explicit secret mapping
runner/container declarations
GitHub-owned host actions
invocation of typed Institute tools
generated callers and GitHub artifacts
community files and templates
authored GitHub deployment desired state
```

It must not retain:

```text
coordinate parsing
SHA validation
GitHub API JSON parsing
workflow YAML interpretation
plan or verdict algorithms
package graph parsing
toolchain URL construction
checksum computation logic
time parsing
Git command semantics
repository-policy predicates
linter rule selection
manual release-manifest generation
```

### Terminal workflow inventory

A plausible terminal host surface is:

1. `swift-ci.yml`
   - `workflow_call`;
   - permissions;
   - platform host jobs generated from a typed plan schema;
   - invoke Institute CI executable;
   - expose final check.

2. `private-verification.yml`
   - private visibility gate;
   - exact credential scope;
   - invoke the same policy and runner;
   - publish the same receipt type.

3. `control-validate.yml`
   - dispatch;
   - separate reader/publisher credential phases;
   - invoke Control.

4. `review-pr-transaction.yml`
   - dispatch and permission envelope;
   - invoke the typed pull-request transaction tool.

The Control binary publisher should move to the Control repository because source acquisition, package build, provenance and release are the package owner’s publication responsibility. The central `.github` repository may schedule or dispatch it, but should not implement the publication transaction.

### Final external-action policy

```text
Allowed:
    GitHub-owned actions/*
    exact full-SHA pin
    explicit host-primitive classification
    least privilege
    no hidden Institute policy

Forbidden:
    every non-GitHub external Action
    branch or tag pins
    Actions used to supply domain semantics
    Actions whose outputs are parsed as untyped policy data
```

---

## XVI. Public/private verification composition

Public and private verification share exactly:

- `CI.Plan`;
- `CI.Operation.ID`;
- `CI.Obligation`;
- Institute tier policy;
- platform support policy;
- linter and Foundation-free rules;
- package graph;
- observation/evidence model;
- verdict aggregation;
- required-check identity;
- receipt schema.

They differ only in:

| Dimension | Public | Private |
|---|---|---|
| Subject acquisition | Public GitHub event/checkout/API | Narrow GitHub App token |
| Repository access | No privileged private content | Exact repository scope |
| Credential lifetime | None or read-only host token | Explicit mint/revoke phases |
| Candidate workspace | Ordinary checkout | Isolated candidate directory |
| Publication credential | Ordinary workflow permissions | Separate narrowed publisher token |
| Destruction proof | Normal runner disposal | Explicit candidate and credential destruction |

Current private verification duplicates Linux, Windows and Apple job bodies and performs its own string aggregation.  Terminally, those jobs are generated or selected from the same typed plan as public CI.

The latest Control acquisition path still uses raw strings, `gh`, `git`, Foundation and manually constructed Git authentication headers. That is a migration implementation, not terminal private-transport architecture. 

---

## XVII. Mechanical enforcement

The doctrine requires each executable predicate to live with the tool that owns its facts and requires positive, negative, edge, near-miss and self-firing controls before a rule becomes blocking. 

| Rule | Fact owner | Enforcement |
|---|---|---|
| Forbidden non-Institute SwiftPM package | Package graph authority | Evaluate manifests and resolved graph; compare every package identity/source against allowed authorities |
| Forbidden Foundation-family import | Source analyser/linter | Exact import predicate over all production and test targets |
| Forbidden Foundation linkage | Binary/link inspector | Mach-O, ELF and PE/COFF receipt |
| Forbidden non-Institute implementation library | Package and link graph authorities | Package-source classification plus binary dependency inspection |
| Undeclared direct dependency | Package/import graph authority | Every imported module must have a direct target dependency |
| Wrong-layer import | Architecture graph authority | Compare target mission/owner claim with import graph |
| Duplicate active semantic owner | Architecture owner index | Unique concept identity and active-owner constraint |
| Raw repository-coordinate parsing in CI | Source linter + GitHub owner claim | Forbid split/regex patterns in top-level targets; require GitHub type |
| Raw SHA parsing in CI | Source linter | Forbid 40/64-hex validation outside Git owner |
| Manual ref parsing | Source linter | Forbid `refs/heads` manipulation outside Git/GitHub relation |
| Manual Package.swift parsing | SwiftPM graph authority | Top-level CI may consume only evaluated package facts |
| Raw JSON/YAML traversal in top-level packages | Source/import rule | Forbid raw node/value APIs outside format and relation targets |
| Semantic shell/YAML | GitHub CI workflow validator | Reject GitHub API calls, JSON parsing, SHA regexes and policy branching in `run:` blocks |
| Non-GitHub external Action | GitHub workflow authority | `uses:` owner allowlist plus immutable SHA |
| Missing required evidence | Generic CI | Aggregate verdict is `UNMEASURED`, never pass |
| Incomplete fleet enumeration | Institute application/fleet owner | Scope receipt and positive control required |
| Primitive leakage across public APIs | Owner-specific API rule | Known concept-to-type mapping at package boundaries |
| Test primitive leakage | Same semantic owner | Fixtures use owner-supplied validated constructors |
| Generated artifact without provenance | Generator/architecture authority | Producer, source model and exact revision required |

### Primitive-boundary enforcement

A global count of `String` or `Int` is rejected.

The enforceable rule is domain-specific:

```text
At a declared domain boundary, a value for a known concept must use the
canonical concept type unless the declaration is an authorized wire,
rendering, system-ABI or generic-algorithm boundary.
```

Examples:

- a public `repository: String` in CI is forbidden;
- `JSON.String` inside the JSON codec is lawful;
- `status: Int` in HTTP application code is forbidden;
- an integer decoded by the HTTP codec before constructing `HTTP.Status` is lawful;
- `path: String` in Control is forbidden;
- raw C path bytes beneath File System are lawful.

### Authored semantic claims

Each package should carry a structured local architecture claim:

```yaml
mission:
conceptsOwned:
relationsOwned:
compatibilitySurfaces:
allowedLayers:
forbiddenImports:
wireBoundaries:
systemSubstrates:
```

The central index is generated from these claims and derived graphs. It is not a second hand-edited registry.

---

## XVIII. Quantified reduction

These are observed baselines and terminal requirements, not proof by score.

| Metric | Current observed baseline | Terminal |
|---|---:|---:|
| Proven distinct non-Institute SwiftPM package identities | At least 3 | 0 |
| Non-GitHub external Actions | 2 | 0 |
| Downloaded Realm SwiftLint implementation | 1 | 0 |
| Python/yamllint runtime path | Present | 0 |
| Direct Foundation-bearing scoped roots | At least 3 | 0 |
| Foundation-family linkage paths | `UNMEASURED` | 0 |
| Local `.github` composite actions | 6 | 0 |
| `.github` workflow files | 5 | Thin host workflows only |
| Workflow + local-action bytes | 127,987 | Not yet measured; semantic shell must be 0 |
| Central `.swiftlint.yml` + `.swift-format` bytes in `.github` | 37,832 | Generated/deployment projection only, or move to rule owner |
| Local GitHub-CI YAML implementation files | Approximately 12 | 0 |
| Active Repository Policy engines | 2 | 1 |
| Control public library products | 6 | 0 |
| Institute CI Validation source | Approximately 161 KB | Predicates moved to exact owners; residual policy code not yet measured |
| Institute CI Inventory source | Approximately 58 KB | Moved to Institute Application |
| Institute CI Foundation CLI/application integration | Approximately 43 KB across inspected targets | 0 Foundation mechanics |
| Raw JSON/YAML handling in top-level packages | Multiple proven sites | 0 |
| Manual SHA/ref/repository parsing sites | Multiple proven sites | 0 |
| Git CLI use in CI/Control semantics | Present | 0 |
| Top-level E–M categories | Material in every top-level unit | Forbidden except declared boundaries |

The exact terminal LOC is intentionally not specified. A line-count target would invite compression without semantic reduction.

---

## XIX. Bottom-up migration sequence

### Phase 0 — Freeze facts and ownership

1. Generate exact package/product/target/import/action graphs.
2. Record one owner claim for every admitted concept.
3. Record every current external package, framework, Action, tool and download.
4. Add positive controls proving all census instruments can detect known violations.
5. Keep every incomplete probe `UNMEASURED`.

### Parallel lane A — Core formats and effects

1. Complete `swift-process` typed path/environment/deadline APIs.
2. Expose File System, JSON, Time, UUID and URI APIs needed by consumers.
3. Complete YAML codec and source-span support.
4. Implement archive owners or redesign distributions to avoid archive extraction.
5. Add owner-local test-support constructors.

### Parallel lane B — Cryptography, TLS and HTTP

1. Replace `swift-crypto` in FIPS 180-4.
2. Implement remaining cryptographic standards required by TLS.
3. implement RFC 8446 model and `swift-tls`.
4. Complete `swift-http-client`.
5. Complete GitHub HTTP endpoints, pagination and rate-limit handling.
6. Migrate one read-only GitHub operation as a vertical proof.
7. Migrate mutation and App-token operations after the read-only path passes.

This is the longest critical-path lane.

### Parallel lane C — Swift syntax and linter

1. Ratify the Swift grammar authority.
2. Implement Swift concrete syntax over generic source/lexer/parser owners.
3. Port linter rules.
4. Replace `swift-argument-parser`.
5. Run existing linter and new linter side by side.
6. Classify every difference.
7. Delete `swift-syntax`, Realm SwiftLint and their CI paths.

### Parallel lane D — Git, GitHub and SwiftPM types

1. Replace SHA and ref strings with existing Git types.
2. Complete GitHub identities, checks, permissions and rulesets.
3. Expose typed SwiftPM evaluated graph/snapshot.
4. Remove GitHub dependency-tree JSON re-parsing.
5. Remove Git CLI from CI and Control.
6. Complete only the native Git operations still required by Institute Application.

### Phase 1 — Replace generic CI

1. Add the new plan/evidence/receipt/verdict model.
2. Preserve the current API only as a non-owning compatibility facade.
3. Add pass, fail, unmeasured, skipped, advisory and dependency-DAG fixtures.
4. Migrate GitHub CI to the new algebra.
5. Delete current generic Tier, GitHub event/ref and required-check ownership.

### Phase 2 — Complete GitHub CI relation

1. Add direct dependency on generic CI.
2. Introduce typed invocation, subject, workflow, run, job and check relations.
3. Migrate to canonical YAML.
4. Move Institute-specific baselines upward.
5. Delete local YAML implementation.

### Phase 3 — Converge repository policy

1. Declare the standalone repository-policy package canonical.
2. Complete its typed GitHub relation.
3. Point every consumer to it.
4. Retain embedded exposure only long enough for source compatibility.
5. Delete embedded target and CLI.
6. Prove generated and authored policy indexes converge.

### Phase 4 — Reduce Institute CI

1. Move inventory to Institute Application.
2. Move gitignore/README/repository predicates to repository policy.
3. Move package graph predicates to SwiftPM/architecture owners.
4. Move skill/source predicates to linter/agent-skill owners.
5. Collapse policy types into the core target.
6. Add the Institute GitHub CI relation target.
7. Replace Foundation application mechanics.
8. Delete the Foundation Integration target.

### Phase 5 — Reduce Control

1. Move all reusable models and predicates to their owners.
2. Move fleet and closure plans to Institute Application.
3. Convert the private executable to `swift-arguments`.
4. Replace Foundation, `gh`, `jq`, `git`, raw JSON and filesystem mechanics.
5. Remove all library products.
6. Publish one credential-bearing executable.

### Phase 6 — Shadow execution

1. Run incumbent and terminal tools on the same exact subject.
2. Produce independently versioned receipts.
3. Compare plans, observations and verdicts.
4. Classify every difference as:
   - incumbent defect;
   - new defect;
   - intentional policy change;
   - missing measurement.
5. Do not allow either implementation to silently borrow the other’s result.

### Phase 7 — Activate and reduce `.github`

1. Activate terminal public CI for a bounded positive-control set.
2. Activate private CI using the same plan/evidence model.
3. Move Control publication to the Control repository.
4. Replace composite actions with typed invocation.
5. Remove non-GitHub external Actions.
6. Remove semantic shell/YAML.
7. Converge generated callers.
8. Switch required checks only after exact-head evidence.
9. Delete incumbent surfaces.

Parallel operation is a bounded migration state with an explicit activation record; it is not a terminal dual authority. 

---

## XX. Deletion gates

| Surface | Exact deletion gate |
|---|---|
| `swift-crypto` | Native owner passes official vectors on Linux, Windows and Darwin; resolver graph has no edge; compiled binary has no crypto package symbols. |
| `swift-syntax` | Institute parser covers the admitted Swift language versions; linter corpus parity is classified; no linter/rule import remains. |
| `swift-argument-parser` | All command routes use `swift-arguments`; help, invalid-input and exit-status fixtures pass. |
| Realm SwiftLint | Every retained rule has an Institute owner; fleet unsuppressed baseline is zero; no downloaded binary path remains. |
| Python/pip/yamllint | YAML owner passes the complete policy/workflow corpus; no subprocess or environment path remains. |
| Local GHCI YAML implementation | Canonical YAML passes LF/CRLF, comments, quotes, anchors, block scalar, duplicate-key and emission fixtures; GHCI uses it directly. |
| Embedded Repository Policy | Every consumer imports standalone owner; compatibility facade delegates only; policy fixture corpus agrees; source target removed from build graph. |
| Institute CI Foundation Integration | All command, file, JSON, time, process and HTTP capabilities are supplied by canonical owners; source and link scans pass. |
| Control library products | Public owners carry all types/predicates; Control application receipt parity passes; no external consumer imports those libraries. |
| `gh` | Every endpoint is represented in GitHub HTTP; recorded wire fixtures pass; no process invocation remains. |
| Direct Git CLI | CI and Control use host checkout/GitHub HTTP/native Git owner; no `git` process invocation remains. |
| `jq` | All payloads decode into typed models; no workflow or executable invokes it. |
| `curl` | HTTP client handles every download/API path; checksum and cancellation fixtures pass. |
| non-GitHub external Actions | Equivalent required host property is either provided by GitHub itself, an Institute executable, or deliberately not implemented; workflow scan is zero. |
| local composite actions | Every workflow invokes the typed executable directly; host validator proves no semantic step was lost. |
| current generic CI compatibility API | All consumers migrated; exact build graph shows no reference; compatibility retirement record satisfied. |
| current publisher workflow in `.github` | Control repository owns its publication transaction; central schedule/dispatch no longer implements package build or release semantics. |

Text search alone is not a deletion proof. Build-level, exact-head and consumer evidence is required, consistent with the doctrine’s reduction protocol. 

---

## XXI. Terminal verification procedure

### 1. Exact dependency receipt

For every root executable:

```text
evaluate every manifest
resolve every package identity to an exact revision
record every selected product and target
record every imported module
classify every package source
record every system-library and binary target
```

The receipt must fail if any branch dependency cannot be resolved or if a source is missing.

The current publication workflow hashes selected branch heads manually. That is useful provenance data but is not a substitute for an evaluated SwiftPM product/target/import closure. 

### 2. Source import proof

Run a source analyser over production and test targets for:

```text
Foundation
FoundationEssentials
FoundationInternationalization
FoundationNetworking
CoreFoundation
CFNetwork
```

Also inspect:

- `@_exported import`;
- public imports;
- conditional imports;
- generated source;
- plugins/macros;
- test-support targets;
- compatibility targets.

### 3. Compiled link proof

For every supported platform and linkage mode:

#### Darwin

```text
Mach-O load commands
Swift autolink sections
link map
archive members
symbol imports
```

#### Linux glibc and musl

```text
ELF NEEDED entries
dynamic symbols
static archive members
link map
```

#### Windows

```text
PE/COFF import table
linked libraries
PDB/link map
```

The proof must establish absence of Foundation-family linkage and prohibited external libraries.

### 4. External package proof

The evaluated graph must contain no package source outside:

```text
swift-institute
swift-primitives
swift-foundations
swift-standards
listed standards organizations
explicit compiler/toolchain substrate
```

A positive-control fixture must add a known external package and cause the rule to fail.

### 5. GitHub workflow proof

Parse every workflow and local action through the typed GHCI model and prove:

- every external `uses:` is GitHub-owned;
- every action is pinned to a full commit SHA;
- permissions are explicit and least-privilege;
- no `secrets: inherit`;
- no PAT fallback;
- no semantic `jq`, `gh api`, SHA regex, coordinate split or Package parsing;
- no unexpected skip can satisfy a gating obligation;
- every required operation produces an admissible receipt;
- missing plan or observation is `UNMEASURED`.

### 6. Domain-boundary proof

Check public/internal APIs of top-level targets for known primitive leaks:

```text
repository: String
sha: String
ref: String
path: String
status: Int
permission: String
visibility: Bool/String
timestamp: String
[String: Any]
YAML.Node
JSON.Value
```

The rule permits only declared wire/rendering/ABI boundaries.

### 7. Owner uniqueness proof

Generate a concept-owner index and require:

```text
one active owner per concept
no duplicate concept IDs
no integration owning its endpoints
no compatibility facade declaring ownership
no generated declaration lacking source provenance
```

### 8. Behavioural and failure controls

For every blocking rule:

- positive fixture;
- negative fixture;
- edge fixture;
- exemption fixture;
- near-miss fixture;
- self-firing fixture;
- missing-evidence fixture.

### 9. Platform matrix

Build and test at least:

```text
Linux glibc
Linux musl
Windows with assertions enabled
macOS
required Apple SDK targets
admitted cross-compilation SDKs
```

### 10. Exact-head live verification

For public and private paths:

1. acquire exact repository and commit identity;
2. prove visibility and authorization scope;
3. produce plan;
4. produce per-operation evidence;
5. produce receipt;
6. publish exact check context;
7. reacquire current head;
8. refuse publication if the head changed;
9. destroy private candidate and credentials;
10. record resolved executable/source revisions.

### 11. Fleet closure

The final fleet receipt must state:

```text
enumerated population
expected population source
unreachable repositories
exceptions
generated caller revisions
effective required checks
effective rulesets
unmeasured entries
```

A partial enumeration cannot produce a clean fleet verdict.

---

## XXII. Residual `UNMEASURED`

The following facts remain genuinely unavailable from this read-only commission:

1. The exact fully resolved transitive SwiftPM closure at every frozen root.
2. The exact count of external implementation packages hidden below all transitive Institute packages.
3. The complete Foundation-family import count across the transitive source closure.
4. Actual Mach-O, ELF and PE/COFF linkage of current binaries.
5. Contents and dependencies of the published private Control executable.
6. The current implementation state of the named `swift-http-client` repository.
7. Effective organization-level inherited rulesets.
8. Complete fleet-wide caller and workflow population.
9. Runtime contents of every referenced container image.
10. Full current use of external system tools inside all lower Institute packages.
11. Behavioural parity of proposed native cryptography, TLS, Swift syntax and Git implementations.
12. Terminal LOC, binary size and execution-time reductions, because the terminal system has not yet been implemented.
13. Whether every current branch dependency head remained unchanged after the final snapshot.
14. Complete build/test evidence for the proposed package and target graph.

These gaps do not leave the architecture undecided. They define the exact receipts needed to prove implementation completion.

# Final ruling

The smallest lawful terminal CI/control-plane layer is:

```text
generic plan/evidence/verdict algebra
+
GitHub relation
+
Institute policy
+
application orchestration
+
trusted credential boundary
+
thin GitHub host wiring
```

Everything else currently found there—YAML parsing, JSON traversal, GitHub URL construction, SHA validation, branch parsing, filesystem mechanics, process mechanics, HTTP transport, time parsing, SwiftPM graph reconstruction, source parsing, linter implementation, archive extraction and toolchain resolution—belongs below it.

The decisive dependency order is therefore:

```text
complete owners
    before
migrating consumers
    before
activating new authority
    before
deleting compatibility
    before
enforcing terminal absence
```

That is the doctrine’s closing rule applied literally: reduce until every distinction carries an independent law, decompose until every unit has one coherent mission, and compose until higher capability is assembled entirely through canonical owners. 
