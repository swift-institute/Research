# Domain-First Repository Organization: Prior Art Survey

<!--
---
tier: 3
status: DEFERRED
created: 2026-02-23
scope: Repository naming, org structure, package identity
---
-->

## Purpose

Concrete data on how major multi-language open-source projects and ecosystems organize their repositories across GitHub, how package registries interact with organizational identity, and how academic/industry taxonomies classify computational domains.

---

## 1. Multi-Language Projects — Repository Naming Conventions

### 1.1 gRPC (`grpc` org) — Polyrepo, Language-Suffix Pattern

**Org**: Single org `grpc` on GitHub.
**Pattern**: `grpc-{language}` for standalone implementations; core C-based languages share the main `grpc/grpc` repo.
**Strategy**: Polyrepo with shared-core exception.

| Repository | Description |
|-----------|-------------|
| `grpc` | Core C++ implementation (also covers Python, Ruby, Objective-C, PHP, C#) |
| `grpc-go` | Go implementation (standalone, no C dependency) |
| `grpc-java` | Java implementation (standalone) |
| `grpc-swift` | Swift implementation (original, based on C core) |
| `grpc-swift-2` | Swift implementation (rewrite, pure Swift) |
| `grpc-swift-extras` | Swift ecosystem extensions |
| `grpc-swift-nio-transport` | Swift NIO transport layer |
| `grpc-swift-protobuf` | Swift protobuf integration |
| `grpc-dart` | Dart implementation |
| `grpc-dotnet` | .NET implementation |
| `grpc-haskell` | Haskell implementation |
| `grpc-kotlin` | Kotlin implementation |
| `grpc-node` | Node.js implementation |
| `grpc-php` | PHP implementation |
| `grpc-web` | Browser client |
| `grpc-ios` | iOS-specific |
| `grpc-proto` | Shared proto definitions |
| `grpc-java-api-checker` | Java-specific tooling |
| `proposal` | Design proposals |
| `grpc-experiments` | Experimental work |
| `grpc-community` | Community governance |

**Total repos**: ~30 (including infra, docs, test tooling).

**Key observation**: Languages with independent runtimes (Go, Java, Swift, Dart, .NET, Kotlin, Haskell) get their own repo. Languages that bind to the C core stay in the monorepo. Swift has *five* repos under the `grpc-swift-*` namespace, showing how a single language implementation can fan out.

---

### 1.2 Protocol Buffers (`protocolbuffers` org) — Hybrid Mono/Polyrepo

**Org**: Single org `protocolbuffers` on GitHub.
**Pattern**: Main monorepo `protobuf` with language subdirectories; standalone repos for languages needing independent release cycles.

| Repository | Description |
|-----------|-------------|
| `protobuf` | Core: C++, Java, Python, C#, Ruby, Objective-C, PHP (monorepo with `java/`, `python/`, `csharp/` etc.) |
| `protobuf-go` | Go implementation (standalone, google.golang.org/protobuf) |
| `protobuf-javascript` | JavaScript implementation |
| `protobuf-php` | PHP implementation |
| `upb` | Micro Protobuf — small C implementation |
| `protobuf-ci` | CI infrastructure |
| `protobuf-grammar` | Language grammar definitions |
| `protoscope` | Debugging tool |
| `txtpbfmt` | Text proto formatter |
| `utf8_range` | UTF-8 validation library |
| `rules_ruby` | Bazel rules for Ruby |

**Total repos**: 15.

**Key observation**: Java lives *inside* the monorepo (`protobuf/java/`), while Go gets its own repo (`protobuf-go`). The deciding factor appears to be whether the language runtime can share the same release cadence as the core. Go's module system effectively requires a separate repo for `go get` to work naturally.

---

### 1.3 Apache Arrow (`apache/arrow`) — Monorepo, Language-Directory Pattern

**Org**: `apache` org on GitHub (single org for all ASF projects).
**Pattern**: Single monorepo with top-level language directories.
**Strategy**: Pure monorepo.

```
apache/arrow/
├── cpp/          # Core C++ implementation
├── python/       # PyArrow
├── java/         # Java implementation
├── go/           # Go implementation
├── r/            # R bindings
├── js/           # JavaScript
├── csharp/       # C# bindings
├── ruby/         # Ruby bindings
├── matlab/       # MATLAB bindings
├── swift/        # Swift bindings
└── ...
```

**Rationale (from project)**: "This project is held together by its inter-language binary integration tests. A single pull request may affect multiple implementations — if we split the project up into multiple git repos, effectively we would have a network of circular dependencies in the CI." JavaScript developers can merge support for emitting binary streams that CI verifies are consumable by Java and C++.

**Key observation**: The monorepo is explicitly chosen for cross-language binary compatibility testing. This is the strongest case for monorepo in the dataset — the shared columnar format *requires* synchronized testing across all implementations.

---

### 1.4 Apache Thrift (`apache/thrift`) — Monorepo, Language-Directory Pattern

**Org**: `apache` org on GitHub.
**Pattern**: Single monorepo with `lib/{language}/` directories.
**Strategy**: Pure monorepo.

```
apache/thrift/
├── compiler/     # Thrift IDL compiler (C++)
├── lib/
│   ├── cpp/
│   ├── java/
│   ├── py/
│   ├── go/
│   ├── swift/
│   ├── rs/       # Rust
│   ├── rb/       # Ruby
│   └── ... (28 languages total)
└── tutorial/
```

**Key observation**: Supports 28 programming languages in a single monorepo. Each language has its own README in `lib/{language}/README.md`. The compiler and all language libraries are versioned and released together.

---

### 1.5 Cap'n Proto (`capnproto` org) — Polyrepo, Mixed Naming

**Org**: Single org `capnproto` on GitHub (originally under `sandstorm-io`, later split out).
**Pattern**: Core repo + language-specific repos with inconsistent naming.

| Repository | Description |
|-----------|-------------|
| `capnproto` | Core: serialization/RPC system + C++ library |
| `capnproto-java` | Java implementation |
| `capnproto-rust` | Rust implementation |
| `capnproto-dlang` | D implementation |
| `go-capnp` | Go implementation (note: `go-capnp`, not `capnproto-go`) |
| `node-capnp` | Node.js bindings (note: `node-capnp`, not `capnproto-node`) |
| `pycapnp` | Python bindings (note: `pycapnp`, not `capnproto-python`) |
| `capnp-futures-rs` | Rust async futures |
| `capnp-rpc-rust` | Rust RPC layer |
| `capnpc-rust` | Rust compiler plugin |
| `capnp-ocaml` | OCaml implementation |
| `kj-rs` | Rust bindings for KJ async framework |
| `ekam` | Build system |

**Total repos**: 13.

**Key observation**: Naming is inconsistent — some repos use `capnproto-{lang}` (Java, Rust, D), others use `{lang}-capnp` (Go, Node), and Python uses `pycapnp`. This appears to reflect organic growth where community-contributed implementations were later adopted into the org with their original names preserved. The Rust implementation is split across three repos (`capnproto-rust`, `capnp-futures-rs`, `capnp-rpc-rust`).

---

### 1.6 FlatBuffers (`google/flatbuffers`) — Monorepo

**Org**: `google` org on GitHub.
**Pattern**: Single monorepo with all language implementations.
**Strategy**: Pure monorepo.

Supports 14+ languages (C++, C#, Dart, Go, Java, JavaScript, Kotlin, Lobster, Lua, PHP, Python, Rust, Swift, TypeScript) in a single repository with a shared `flatc` compiler.

**Key observation**: Like Thrift, the schema compiler and all runtimes are co-versioned. Being under the `google` org means FlatBuffers shares org-level namespace with thousands of other Google projects.

---

### 1.7 OpenTelemetry (`open-telemetry` org) — Polyrepo, Full-Name-Prefix Pattern

**Org**: Single org `open-telemetry` on GitHub.
**Pattern**: `opentelemetry-{language}` for core SDKs, with `-contrib`, `-instrumentation` suffixes for extensions.
**Strategy**: Polyrepo with systematic naming.

**Core SDK repos** (each language gets its own):
| Repository | Notes |
|-----------|-------|
| `opentelemetry-go` | Go SDK |
| `opentelemetry-java` | Java SDK |
| `opentelemetry-python` | Python SDK |
| `opentelemetry-js` | JavaScript SDK |
| `opentelemetry-dotnet` | .NET SDK |
| `opentelemetry-cpp` | C++ SDK |
| `opentelemetry-rust` | Rust SDK |
| `opentelemetry-ruby` | Ruby SDK |
| `opentelemetry-php` | PHP SDK |
| `opentelemetry-erlang` | Erlang SDK |
| `opentelemetry-swift` | Swift SDK |
| `opentelemetry-android` | Android SDK |
| `opentelemetry-kotlin` | Kotlin SDK |

**Contrib/extension repos** (per-language pattern):
| Pattern | Examples |
|---------|----------|
| `opentelemetry-{lang}-contrib` | `opentelemetry-go-contrib`, `opentelemetry-java-contrib`, `opentelemetry-python-contrib`, `opentelemetry-dotnet-contrib`, `opentelemetry-ruby-contrib`, `opentelemetry-rust-contrib`, `opentelemetry-cpp-contrib`, `opentelemetry-js-contrib`, `opentelemetry-php-contrib`, `opentelemetry-erlang-contrib` |
| `opentelemetry-{lang}-instrumentation` | `opentelemetry-java-instrumentation`, `opentelemetry-go-instrumentation`, `opentelemetry-go-compile-instrumentation`, `opentelemetry-php-instrumentation`, `opentelemetry-dotnet-instrumentation`, `opentelemetry-ebpf-instrumentation` |

**Cross-cutting repos**:
| Repository | Purpose |
|-----------|---------|
| `opentelemetry-specification` | Spec docs |
| `opentelemetry-proto` | Proto definitions |
| `opentelemetry-proto-go` | Generated Go protos |
| `opentelemetry-proto-java` | Generated Java protos |
| `opentelemetry-collector` | Collector core |
| `opentelemetry-collector-contrib` | Collector extensions |
| `opentelemetry-collector-releases` | Release artifacts |
| `opentelemetry-demo` | Demo application |
| `opentelemetry-helm-charts` | Kubernetes deployment |
| `opentelemetry-operator` | Kubernetes operator |
| `semantic-conventions` | Shared semantic conventions |
| `weaver` | Schema/codegen tool |
| `opentelemetry-configuration` | Configuration schema |

**Swift-specific repos**:
| Repository | Purpose |
|-----------|---------|
| `opentelemetry-swift` | Core Swift SDK |
| `opentelemetry-swift-core` | Swift core primitives |
| `opentelemetry-swift-grpc` | Swift gRPC exporter |

**Total repos**: ~90+ (across core SDKs, contrib, instrumentation, infra, SIGs, and tooling).

**Key observation**: The most systematic naming in this dataset. Every repo starts with `opentelemetry-` prefix. Language SDKs follow `opentelemetry-{lang}`, extensions follow `opentelemetry-{lang}-{purpose}`. The protocol definition repo (`opentelemetry-proto`) gets per-language generated repos (`opentelemetry-proto-go`, `opentelemetry-proto-java`). Also notable: SIG (Special Interest Group) repos like `sig-security`, `sig-profiling`, `sig-end-user` break the prefix convention.

---

### 1.8 CloudEvents (`cloudevents` org) — Polyrepo, SDK-Prefix Pattern

**Org**: Single org `cloudevents` on GitHub.
**Pattern**: `sdk-{language}` for implementations, `spec` for the specification.
**Strategy**: Polyrepo with systematic naming.

| Repository | Description |
|-----------|-------------|
| `spec` | CloudEvents Specification |
| `sdk-go` | Go SDK |
| `sdk-java` | Java SDK |
| `sdk-javascript` | JavaScript SDK |
| `sdk-python` | Python SDK |
| `sdk-csharp` | C# SDK |
| `sdk-ruby` | Ruby SDK |
| `sdk-php` | PHP SDK |
| `sdk-rust` | Rust SDK |
| `sdk-powershell` | PowerShell SDK |
| `conformance` | Conformance testing |
| `cloudevents-web` | Website |

**Total repos**: 12.

**Key observation**: Cleanest naming pattern in the dataset. The `sdk-` prefix groups all implementations together alphabetically. The spec is just `spec`. No language has more than one repo. The `conformance` repo exists separately for cross-language testing (compare with Apache Arrow's monorepo approach to the same problem).

---

### 1.9 Kubernetes Client Libraries (`kubernetes-client` org) — Polyrepo, Language-Only Names

**Org**: Separate org `kubernetes-client` (distinct from `kubernetes` org).
**Pattern**: Repo name is just the language name.
**Strategy**: Polyrepo with bare language names.

| Repository | Description |
|-----------|-------------|
| `python` | Python client |
| `java` | Java client |
| `javascript` | JavaScript client |
| `csharp` | C# client |
| `go` | Go client (OpenAPI-generated; *not* the same as `kubernetes/client-go`) |
| `go-base` | Go base library |
| `c` | C client |
| `haskell` | Haskell client |
| `perl` | Perl client |
| `ruby` | Ruby client |
| `python-base` | Python base library |
| `gen` | Code generation tooling |

**Total repos**: 12.

**Key observation**: The boldest naming strategy — repos are just `python`, `java`, `go`, etc. This works because the org name (`kubernetes-client`) provides all context. Also notable: the `kubernetes` org itself has `client-go` as a staging repo synced from the main monorepo, creating a parallel naming universe. The `-base` suffix pattern (`python-base`, `go-base`) indicates a two-tier library structure.

---

### Summary Table: Multi-Language Project Patterns

| Project | Org | Strategy | Naming Pattern | Repo Count |
|---------|-----|----------|---------------|------------|
| gRPC | `grpc` | Polyrepo (shared core) | `grpc-{lang}` | ~30 |
| Protocol Buffers | `protocolbuffers` | Hybrid mono/poly | `protobuf` + `protobuf-{lang}` | 15 |
| Apache Arrow | `apache` | Monorepo | `arrow/` + `{lang}/` dirs | 1 |
| Apache Thrift | `apache` | Monorepo | `thrift/lib/{lang}/` dirs | 1 |
| Cap'n Proto | `capnproto` | Polyrepo | Mixed/inconsistent | 13 |
| FlatBuffers | `google` | Monorepo | `flatbuffers/` + language dirs | 1 |
| OpenTelemetry | `open-telemetry` | Polyrepo | `opentelemetry-{lang}` | ~90 |
| CloudEvents | `cloudevents` | Polyrepo | `sdk-{lang}` | 12 |
| Kubernetes Clients | `kubernetes-client` | Polyrepo | `{lang}` (bare name) | 12 |

**Pattern distribution**:
- **Monorepo**: Apache Arrow, Apache Thrift, FlatBuffers (3/9) — chosen when cross-language binary compatibility testing is critical
- **Polyrepo with prefix**: gRPC, Protocol Buffers, OpenTelemetry (3/9) — `{project}-{lang}`
- **Polyrepo with category prefix**: CloudEvents (1/9) — `sdk-{lang}`
- **Polyrepo with bare names**: Kubernetes Clients (1/9) — `{lang}`
- **Mixed/organic**: Cap'n Proto (1/9)

---

## 2. Domain-Namespaced Organizations on GitHub

### 2.1 Primitive Domain Names

| Name | Status | Type | Public Repos | Notes |
|------|--------|------|-------------|-------|
| `algebra` | **Taken** | User | 0 | Dormant user account, zero repos |
| `binary` | **Taken** | User | 3 | User account with repos |
| `geometry` | **Taken** | User | 0 | Dormant user account, zero repos |
| `time` | **Taken** | User | 4 | User account with repos |
| `async` | **Taken** | Organization | 5 | Active org (async JavaScript utilities) |

**Assessment**: All five domain names are taken. `algebra` and `geometry` are dormant user accounts with zero repos — theoretically reclaimable via GitHub's name release policy for inactive accounts, but not reliably.

### 2.2 Standards Body Names

| Name | Status | Type | Public Repos | Notes |
|------|--------|------|-------------|-------|
| `iso` | **Taken** | User | 2 | User account, not ISO the standards body |
| `ietf` | **Taken** | Organization | 14 | Official IETF org (contains `ietf`, `wiki.ietf.org`, `www.ietf.org`, etc.) |
| `w3c` | **Taken** | Organization | 1130 | Official W3C org (massive presence) |
| `whatwg` | **Taken** | Organization | 47 | Official WHATWG org (spec repos: `html`, `dom`, `fetch`, `url`, `streams`, etc.) |
| `IEEE` | **Taken** | Organization | 0 | Claimed but empty |
| `ecma` | **Taken** | Organization | 0 | Claimed but empty |

**Assessment**: All standards body names are taken. `ietf`, `w3c`, and `whatwg` are official. `iso`, `IEEE`, and `ecma` are claimed but largely unused. WHATWG is particularly notable: each spec gets its own repo named after the standard (`html`, `dom`, `fetch`, `url`, `streams`, `encoding`, `console`, etc.) — a domain-first naming pattern.

### 2.3 Suffixed Domain Names

| Name | Status | Notes |
|------|--------|-------|
| `algebra-lang` | **Available** | Not found (404) |
| `algebra-impl` | **Available** | Not found (404) |
| `algebra-lib` | **Available** | Not found (404) |

**Assessment**: Suffixed variants are available. The `-lang`, `-impl`, `-lib` suffixes are all unused for `algebra-*`. This pattern could be applied systematically to claim domain-namespaced orgs.

---

## 3. Standards Body Implementations Across Languages

### 3.1 Rust (crates.io)

RFC implementations on crates.io use **domain names without RFC numbers** as crate names:

| Crate | RFC/Standard | Downloads |
|-------|-------------|-----------|
| `uuid` | RFC 9562 (UUIDs) | Very high |
| `http` | RFC 7230-7235 (HTTP) | Very high |
| `url` | RFC 3986 (URIs) | Very high |
| `base64` | RFC 4648 (Base64) | Very high |
| `base64ct` | RFC 4648 (constant-time) | Moderate |
| `mime` | RFC 2045 (MIME) | High |

**Key pattern**: Crate names are the *concept* (`uuid`, `http`, `url`), not the specification (`rfc-9562`, `rfc-7230`). The RFC number appears only in documentation. Flat namespace means first-come-first-served; no organizational hierarchy.

**Namespacing RFC 3243** (accepted, in implementation): Cargo will support `foo::bar` syntax on crates.io, where owners of `foo` implicitly own `foo::bar`. This is the first step toward organizational namespacing in Rust's flat namespace.

### 3.2 Go (standard library + modules)

Go embeds RFC implementations directly in the **standard library** under domain-organized paths:

| Package | RFC/Standard |
|---------|-------------|
| `net/http` | RFC 7230-7235 |
| `crypto/tls` | RFC 5246, RFC 8446 |
| `net/url` | RFC 3986 |
| `encoding/base64` | RFC 4648 |
| `encoding/json` | RFC 7159 |
| `net/mail` | RFC 5322 |
| `mime` | RFC 2045 |

**Key pattern**: Go's standard library uses a **domain/concept** path structure: `crypto/tls`, `encoding/base64`, `net/http`. This is a two-level hierarchy where the first component is the domain (`crypto`, `encoding`, `net`) and the second is the concept.

For external modules, Go uses URL-based import paths (`github.com/org/repo`). Vanity import paths (e.g., `golang.org/x/crypto`) decouple identity from hosting, allowing migration between hosts without breaking imports.

### 3.3 Python (PyPI)

Python uses a flat namespace on PyPI with domain-name packages:

| Package | Standard |
|---------|----------|
| `cryptography` | Multiple TLS/crypto RFCs |
| `urllib3` | RFC 3986 |
| `uuid` (stdlib) | RFC 4122 |
| `http` (stdlib) | RFC 7230+ |

**Key pattern**: Like Rust, concept names dominate. The stdlib uses `http.client`, `http.server` — a nested module structure within the package.

### 3.4 Organizations Dedicated to Standards Bodies

| GitHub Org | Standards Body | Strategy |
|-----------|---------------|----------|
| `ietf` | IETF | Official org; repos for website/wiki/tooling only, NOT individual RFC implementations |
| `w3c` | W3C | Official org; 1130+ repos, one per specification working group |
| `whatwg` | WHATWG | Official org; one repo per living standard (`html`, `dom`, `fetch`, `url`) |
| `ietf-wg-httpbis` | *Does not exist* | Working group-level orgs are not a pattern used by IETF |

**Key finding**: Standards bodies use GitHub for *specification text*, not implementations. Implementations live in language ecosystem repos (`uuid` crate, `net/http` stdlib). The WHATWG pattern of one-repo-per-standard using bare domain names (`html`, `dom`, `url`, `fetch`, `streams`) is the closest precedent to a "domain-first" organization.

---

## 4. Package Registry Conventions

### 4.1 Swift Package Registry (SE-0292)

**Status**: Accepted and implemented. Supported in SwiftPM.

**Identity model**: Packages use scoped identifiers in the form `scope.package-name` (e.g., `apple.swift-argument-parser`). The scope is an organizational namespace.

**Key features**:
- Decouples package identity from git URL
- `swift package resolve --replace-scm-with-registry` maps git URLs to registry identifiers
- Registry can serve packages by identifier, independent of where source code is hosted
- Xcode support is still evolving (as of recent forum discussions)

**SE-0391**: Adds `swift package-registry publish` for publishing to a registry.

**Implication for org structure**: If Swift Package Registry becomes the primary distribution mechanism, the `scope` in `scope.package-name` replaces the GitHub org as the organizational unit. A single GitHub org (or monorepo) could publish many scoped packages. Conversely, packages from multiple GitHub orgs could share a scope.

### 4.2 Cargo / crates.io (Rust)

**Namespace model**: Flat. No organizational hierarchy. First-come-first-served.

**Workarounds for organization**:
- **Prefix convention**: `tokio-*` (20+ crates), `serde-*` (ecosystem), `rusoto-*`
- **RFC 3243** (accepted): `foo::bar` syntax, where `foo` owners control `foo::bar`. In implementation.
- **Workspace manifests**: Multiple crates in one repo using `[workspace]` in `Cargo.toml`

**Implication**: The absence of namespacing led to prefix-based grouping. RFC 3243 will introduce opt-in namespacing but won't retroactively apply. The Tokio project effectively uses crate name prefixes as a namespace: `tokio`, `tokio-stream`, `tokio-util`, `tokio-macros`, etc.

### 4.3 Go Modules

**Namespace model**: URL-based. Module identity IS the URL path.

```
github.com/grpc/grpc-go        → GitHub org determines namespace
golang.org/x/crypto             → Vanity URL decouples from hosting
google.golang.org/protobuf      → Vanity URL with org prefix
```

**Vanity import paths**: A server at a custom domain returns `<meta name="go-import" content="...">` tags that redirect `go get` to the actual repository. This allows:
- Migration between hosts without breaking imports
- Organizational identity independent of GitHub org
- Multiple repos behind a single domain

**Implication**: Go's URL-based identity means the GitHub org is part of the package identity *unless* vanity imports are used. OpenTelemetry uses `go.opentelemetry.io/otel` as its vanity path, completely decoupling from GitHub structure.

### 4.4 npm Scopes

**Namespace model**: Hierarchical. `@scope/package-name` where scope = org or user.

**Key properties**:
- Every npm org gets a scope matching its name: org `wombat` → scope `@wombat`
- Only scope owners can publish `@scope/*` packages
- Scoped packages are private by default; `--access public` required for first publish
- Unscoped packages are in a flat global namespace (legacy)

**Examples**:
```
@angular/core          → Angular org
@babel/parser          → Babel org
@types/node            → DefinitelyTyped org
@opentelemetry/api     → OpenTelemetry org
```

**Implication**: npm's scope system is the most mature organizational namespace in package registries. It directly ties npm org identity to package namespace. A domain-first approach would map naturally: `@algebra/linear`, `@geometry/euclidean`, `@time/duration`.

### Summary: Registry Namespace Models

| Registry | Namespace Model | Org Coupling | Decoupling Mechanism |
|----------|----------------|-------------|---------------------|
| Swift (SE-0292) | `scope.package` | Weak (scope != GitHub org) | Registry maps identifiers |
| crates.io | Flat (prefix conventions) | None | RFC 3243 `::` (pending) |
| Go modules | URL-based | Strong (URL = identity) | Vanity import paths |
| npm | `@scope/package` | Strong (scope = org) | None needed — built in |
| PyPI | Flat | None | None |

---

## 5. Academic/Industry Taxonomies

### 5.1 ACM Computing Classification System (CCS 2012)

The ACM CCS is a poly-hierarchical ontology with 13 top-level categories:

1. General and reference
2. Hardware
3. Computer systems organization
4. Networks
5. Software and its engineering
6. Theory of computation
7. **Mathematics of computing**
8. Information systems
9. Security and privacy
10. Human-centered computing
11. Computing methodologies
12. Applied computing
13. Social and professional topics

**Relevant subcategories under "Mathematics of computing"**:
- Discrete mathematics (combinatorics, graph theory)
- Probability and statistics
- Mathematical analysis (numerical analysis)
- **Mathematical software** (solvers, libraries)

**Relevant subcategories under "Theory of computation"**:
- Design and analysis of algorithms
- Formal languages and automata theory
- Computational complexity

**Assessment**: The CCS does not have a category for "computational primitives" as a concept. The closest are "Mathematical software" (under Mathematics of computing) and "Software and its engineering > Software organization and properties > Software functional properties". The CCS is organized by *discipline*, not by *abstraction level* — it has no concept analogous to a "primitives/standards/foundations" layering.

### 5.2 Mathematics Subject Classification (MSC 2020)

63 two-digit top-level categories. Categories most relevant to computational primitives:

**Algebra & Number Theory**:
| Code | Category |
|------|----------|
| 06 | Order, lattices, ordered algebraic structures |
| 08 | General algebraic systems |
| 11 | Number theory |
| 12 | Field theory and polynomials |
| 13 | Commutative algebra |
| 15 | Linear and multilinear algebra; matrix theory |
| 16 | Associative rings and algebras |
| 17 | Nonassociative rings and algebras |
| 18 | Category theory; homological algebra |
| 20 | Group theory and generalizations |

**Geometry & Topology**:
| Code | Category |
|------|----------|
| 14 | Algebraic geometry |
| 51 | Geometry |
| 52 | Convex and discrete geometry |
| 53 | Differential geometry |
| 54 | General topology |
| 55 | Algebraic topology |
| 57 | Manifolds and cell complexes |

**Analysis (relevant to time/continuous domains)**:
| Code | Category |
|------|----------|
| 26 | Real functions |
| 28 | Measure and integration |
| 34 | Ordinary differential equations |
| 37 | Dynamical systems and ergodic theory |

**Applied/Computational**:
| Code | Category |
|------|----------|
| 65 | Numerical analysis |
| 68 | Computer science |
| 90 | Operations research, mathematical programming |
| 93 | Systems theory; control |
| 94 | Information and communication, circuits |

**Assessment**: The MSC maps well to the Swift Institute's domain packages:
- `algebra` corresponds to MSC codes 06, 08, 15, 16, 17, 18, 20
- `geometry` corresponds to MSC codes 14, 51, 52, 53
- `time` touches MSC codes 37 (dynamical systems), 26 (real functions)
- `binary` is closest to MSC 94 (information and communication)

The MSC validates that "algebra", "geometry", and "time" are recognized top-level mathematical domains, not arbitrary groupings. The MSC has been stable since its inception in the 1940s; the domain boundaries are well-established.

### 5.3 Apache Software Foundation — Organization of 300+ Projects

**Scale**: 2,854 public repos under the `apache` GitHub org. 295 active top-level projects + 32 incubating podlings.

**Organization model**:
- Single GitHub org: `apache`
- Repo naming: `apache/{project-name}` (e.g., `apache/kafka`, `apache/arrow`, `apache/spark`)
- No domain-based sub-organization
- Projects categorized by: Big Data, Cloud, Content, Library/Framework, Network/Client/Server, Web/Application/Framework, XML, etc.
- Maturity: Incubator → Top-Level Project (TLP) → Attic (retired)

**Naming process**: All project names must go through a trademark search and approval by the Apache Trademarks Committee. The formal name is "Apache {ProjectName}". Subprojects use `{project}-{subproject}` within the org.

**Project data**: Each project maintains a DOAP (Description Of A Project) file — an RDF/XML description of the project.

**Key observation**: Apache's approach is "one org, many projects" with flat naming. At 2,854 repos, this works because the `apache/` org prefix provides the brand/trust signal. Projects self-organize via PMCs (Project Management Committees).

### 5.4 CNCF — Maturity-Based Organization

**Organization model**: Projects do NOT live under a single org. Each project has its own GitHub org:
- `kubernetes/kubernetes` (kubernetes org)
- `prometheus/prometheus` (prometheus org)
- `envoyproxy/envoy` (envoyproxy org)
- `etcd-io/etcd` (etcd-io org)

**Maturity levels**:
| Level | Description | Signal | Approximate Count |
|-------|-------------|--------|-------------------|
| Sandbox | Early-stage, experimental | Innovators | ~100+ |
| Incubating | Growing adoption, stabilizing | Early Adopters | ~30+ |
| Graduated | Production-ready, widely deployed | Early Majority | ~30+ |

**Advancement criteria**: Adoption evidence, healthy change rate, committers from multiple organizations, CII Best Practices Badge, CNCF Code of Conduct adoption.

**Key observation**: CNCF is the opposite of Apache — each project keeps its own org. CNCF's role is certification/maturity labeling, not hosting. The CNCF Landscape (landscape.cncf.io) serves as the organizational index. This is a "federated" model where the foundation provides maturity signaling without controlling repository structure.

**Contrast with Apache**:
| Dimension | Apache | CNCF |
|-----------|--------|------|
| GitHub org | Single `apache` org | Per-project orgs |
| Naming control | Foundation controls names | Projects control names |
| Maturity model | Incubator → TLP → Attic | Sandbox → Incubating → Graduated |
| Repo count in org | 2,854 | ~100 (cncf org is governance only) |
| Identity | `apache/{project}` | `{project-org}/{project}` |

---

## 6. Synthesis: Patterns and Anti-Patterns

### Pattern 1: Language-Suffix Polyrepo (most common)
`{project}-{lang}` — Used by gRPC, Protocol Buffers, OpenTelemetry.
- **Pro**: Clear ownership, independent release cycles, language-idiomatic tooling
- **Con**: Coordination overhead, naming drift (see Cap'n Proto)

### Pattern 2: Domain-Directory Monorepo
`{project}/{lang}/` — Used by Apache Arrow, Thrift, FlatBuffers.
- **Pro**: Cross-language testing, synchronized releases
- **Con**: Scales poorly past ~5 active language communities, git history becomes noisy

### Pattern 3: Category-Prefix Polyrepo
`sdk-{lang}` or `{lang}` (bare) — Used by CloudEvents, Kubernetes Clients.
- **Pro**: Clean alphabetical grouping, org name provides all context
- **Con**: Requires org name to be sufficiently descriptive

### Pattern 4: Standards-Body-Per-Standard
`{standard-name}` (bare domain name) — Used by WHATWG.
- **Pro**: Each spec is independently versionable, names are maximally clear
- **Con**: Requires owning a GitHub org that matches the standards body

### Anti-Pattern: Organic/Inconsistent Naming
Mixed patterns within one org — Cap'n Proto.
- Early repos adopted community names; later standardization was not applied retroactively
- Creates confusion about which repo contains the "official" implementation for a given language

### Anti-Pattern: Overloaded Org
Single org with 1000+ repos — W3C (1130), Apache (2854).
- Discoverability suffers; browsing the org page is useless
- Mitigated by external catalogs (Apache Projects Directory, CNCF Landscape)

---

## 7. Implications for Swift Institute

### Key Findings

1. **The "domain-first" pattern has precedent**: WHATWG uses bare domain names (`html`, `dom`, `url`, `fetch`). Kubernetes Clients use bare language names. CloudEvents uses `sdk-{lang}`. The pattern of org-name-provides-context is established.

2. **Standards bodies don't own implementations**: IETF, W3C, and WHATWG publish specifications on GitHub. Implementations live in language ecosystems. No standards body has a GitHub org containing implementations of their standards across languages.

3. **Package registries are converging on scoped namespaces**: npm has `@scope/package`, Swift has `scope.package`, Rust is adding `foo::bar`. All three recognize that flat namespaces don't scale and organizational identity needs to be part of package identity.

4. **MSC validates domain names**: "algebra", "geometry", and "time" are established top-level mathematical domains with 80+ years of stability in classification systems. They are not arbitrary names.

5. **Monorepo vs polyrepo is decided by testing needs**: If cross-language binary compatibility testing is required (Arrow, Thrift), use monorepo. If languages have independent release cycles and no binary interface (gRPC, OpenTelemetry), use polyrepo.

6. **The largest ecosystems need external catalogs**: Apache (2854 repos) and CNCF use external directories/landscapes to organize projects. The GitHub org page alone doesn't scale past ~50 repos for discoverability.

7. **GitHub org names for common nouns are scarce**: `algebra`, `binary`, `geometry`, `time`, and `async` are all taken. Suffixed variants (`algebra-lang`, `algebra-impl`, `algebra-lib`) are available.

---

## Sources

- [gRPC GitHub Organization](https://github.com/grpc)
- [Protocol Buffers GitHub Organization](https://github.com/protocolbuffers)
- [Apache Arrow Repository](https://github.com/apache/arrow)
- [Apache Thrift Repository](https://github.com/apache/thrift)
- [Cap'n Proto GitHub Organization](https://github.com/capnproto)
- [Google FlatBuffers Repository](https://github.com/google/flatbuffers)
- [OpenTelemetry GitHub Organization](https://github.com/open-telemetry)
- [CloudEvents GitHub Organization](https://github.com/cloudevents)
- [Kubernetes Client Libraries](https://github.com/kubernetes-client)
- [WHATWG GitHub Organization](https://github.com/whatwg)
- [IETF GitHub Organization](https://github.com/ietf)
- [W3C GitHub Organization](https://github.com/w3c)
- [SE-0292: Package Registry Service](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0292-package-registry-service.md)
- [SE-0391: Package Registry Publish](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0391-package-registry-publish.md)
- [SwiftPM Package Registry Usage](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md)
- [Rust RFC 3243: Packages as Optional Namespaces](https://rust-lang.github.io/rfcs/3243-packages-as-optional-namespaces.html)
- [crates.io Namespacing Discussion](https://internals.rust-lang.org/t/namespacing-on-crates-io/8571)
- [Rust API Guidelines: Naming](https://rust-lang.github.io/api-guidelines/naming.html)
- [npm Scopes Documentation](https://docs.npmjs.com/about-scopes/)
- [npm Organization Scopes](https://docs.npmjs.com/about-organization-scopes-and-packages/)
- [Go Vanity Import Paths](https://sagikazarmark.hu/blog/vanity-import-paths-in-go/)
- [ACM Computing Classification System](https://www.acm.org/publications/class-2012)
- [MSC 2020 Mathematics Subject Classification](https://msc2020.org/)
- [zbMATH MSC 2020 Classification](https://zbmath.org/classification/)
- [Apache Projects Directory](https://projects.apache.org/)
- [Apache Project Naming Process](https://www.apache.org/foundation/marks/naming.html)
- [CNCF Graduated and Incubating Projects](https://www.cncf.io/projects/)
- [CNCF Project Lifecycle](https://contribute.cncf.io/projects/lifecycle/)
- [CNCF Graduation Criteria](https://github.com/cncf/toc/blob/main/process/graduation_criteria.md)
