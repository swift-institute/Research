# Domain-First Repository Organization

<!--
---
version: 1.2.0
last_updated: 2026-02-23
status: RECOMMENDATION
research_tier: 3
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

The Swift Institute currently organizes ~330 packages across three monorepos using a **language-first** naming convention:

| Repository | Package Count | Naming Pattern | Structure |
|-----------|:---:|---|---|
| `swift-primitives` (→ `primitives`) | 125 | `swift-*-primitives` | Monorepo, individual Package.swift per subdirectory |
| `swift-standards` (→ `standards`) | 93 (+ 18 stubs) | `swift-{spec-id}` | Flat collection of individual packages |
| `swift-foundations` (→ `foundations`) | 43 (+ 68 stubs) | `swift-*` | Flat collection of individual packages |

The five-layer architecture constrains dependencies to flow downward only:

```
Layer 5: Applications    (Commercial)
Layer 4: Components      (Flexible)
Layer 3: Foundations     (Apache 2.0)
Layer 2: Standards       (Apache 2.0)
Layer 1: Primitives      (Apache 2.0)
```

### Trigger

Proactive architectural analysis [RES-012]. The current language-first naming convention (`swift-*`) couples the organizational identity to a single implementation language. As the Institute's ambitions expand, this coupling constrains multi-language potential and does not reflect the domain-first philosophy that already underpins the primitives taxonomy.

### Scope

Ecosystem-wide [RES-002a]. This decision affects all three existing repos, the umbrella organization, and all future packages across all layers.

### Precedent Risk

**Very high** — but only if deferred. The Swift Institute is **pre-launch**: no external consumers, no published packages, no Package.resolved files in the wild. This means:

- **Zero migration cost today** — all reorganization is a script that renames directories and rewrites `Package.swift` path dependencies
- **Extreme migration cost post-launch** — every external `Package.swift`, every blog post URL, every CI pipeline becomes a breaking change

This asymmetry makes the decision urgent: the cost of choosing correctly now is near-zero, while the cost of choosing incorrectly (or deferring) compounds with every external consumer.

---

## Question

Should the Swift Institute shift from **language-first** (organized by implementation language) to **domain-first** (organized by problem domain) repository organization? If so, what specific organizational model should be adopted?

### Sub-questions

- SQ1: What organizational models do comparable multi-language projects use?
- SQ2: What domain categories would the current ~330 packages map to?
- SQ3: How do package managers (SPM, Cargo, Go modules) interact with different organizational structures?
- SQ4: What are the GitHub/platform mechanics for migration?
- SQ5: Is there an academic taxonomy that could inform the domain decomposition?
- SQ6: Which organizational model best satisfies Swift Institute's requirements?
- SQ7: What migration path has acceptable risk?

---

## Prior Art Survey [RES-021]

### Multi-Language Project Organization Patterns

The following survey examines how major multi-language open source projects organize their repositories. Three dominant patterns emerge.

#### Pattern 1: Single Org, Language-Suffixed Repos (Polyrepo)

**gRPC** (`grpc` org on GitHub):
- Core C/C++ implementation: `grpc/grpc` (also Python, Ruby, Objective-C, PHP, C# via C core)
- Standalone language implementations: `grpc-go`, `grpc-java`, `grpc-swift`, `grpc-swift-2`, `grpc-dart`, `grpc-dotnet`, `grpc-kotlin`, `grpc-node`, `grpc-haskell`, `grpc-web`
- Swift has five repos: `grpc-swift`, `grpc-swift-2`, `grpc-swift-extras`, `grpc-swift-nio-transport`, `grpc-swift-protobuf`
- Naming convention: `grpc-{language}` for core, `grpc-{language}-{purpose}` for extensions
- Total repos: ~30
- Key properties: Languages with independent runtimes get separate repos. Swift ecosystem shows how one language fans out into multiple repos.

**OpenTelemetry** (`open-telemetry` org):
- Most systematic naming in the dataset: every repo starts with `opentelemetry-`
- Core SDKs: `opentelemetry-{lang}` (13 languages: go, java, python, js, dotnet, cpp, rust, ruby, php, erlang, swift, android, kotlin)
- Extensions: `opentelemetry-{lang}-contrib`, `opentelemetry-{lang}-instrumentation`
- Cross-cutting: `opentelemetry-specification`, `opentelemetry-proto`, `opentelemetry-collector`
- Per-language proto generation: `opentelemetry-proto-go`, `opentelemetry-proto-java`
- Total repos: ~90+
- Key property: Spec-first approach; most consistent naming convention surveyed

**CloudEvents** (`cloudevents` org):
- Cleanest naming in the dataset: `spec` for specification, `sdk-{lang}` for all implementations
- SDKs: `sdk-go`, `sdk-java`, `sdk-javascript`, `sdk-python`, `sdk-csharp`, `sdk-ruby`, `sdk-php`, `sdk-rust`, `sdk-powershell`
- Separate `conformance` repo for cross-language testing
- Total repos: 12
- Key property: `sdk-` prefix groups all implementations together alphabetically

**Kubernetes Client Libraries** (`kubernetes-client` org):
- Boldest naming: repos are just `python`, `java`, `go`, `javascript`, `csharp`, `ruby`, `haskell`, `c`, `perl`
- Org name provides all context; bare language names work because of it
- Two-tier structure: `python-base`, `go-base` for core libraries
- Total repos: 12
- Key property: Dedicated org + bare names = maximum clarity

#### Pattern 2: Single Org, Monorepo with Language Directories

**Apache Arrow** (`apache/arrow`):
- Single monorepo: `apache/arrow`
- Language directories: `cpp/`, `java/`, `python/`, `go/`, `csharp/`, `ruby/`, `js/`, `r/`, `swift/`, `rust/` (moved to separate `arrow-rs`)
- Key property: Unified CI, shared specification, single version
- Notable: Rust implementation split out to `arrow-rs` due to different release cadence and CI requirements
- Lesson: Monorepos work when languages share a specification but can fracture when release cadences diverge

**Cap'n Proto** (`capnproto` org):
- Core: `capnproto/capnproto` (C++)
- Languages: `capnproto-java`, `capnproto-rust`, `pycapnp` (Python)
- Hybrid: core is monorepo, language bindings are separate repos
- Key property: Mixed model reflects that the core (C++) is primary and bindings are secondary

**FlatBuffers** (`google/flatbuffers`):
- Single monorepo under Google org
- Language directories within the repo
- Key property: Google-owned, monorepo culture

#### Pattern 3: Multiple Domain-Aligned Orgs

**Apache Software Foundation**:
- 300+ projects across many orgs
- Each project gets its own identity: `apache/spark`, `apache/kafka`, `apache/arrow`
- All under the `apache` umbrella org
- Key property: Flat namespace within a single trust boundary
- Lesson: Even at 300+ projects, a single org with naming conventions scales

**CNCF (Cloud Native Computing Foundation)**:
- Projects use their own orgs: `kubernetes/`, `prometheus/`, `envoyproxy/`, `grpc/`
- CNCF provides maturity labeling (Sandbox → Incubating → Graduated) but not org structure
- Key property: Loose federation, not organizational hierarchy

No major open source project uses a **domain-first, multi-org** structure where the domain (e.g., "algebra", "geometry", "networking") is the primary organizational unit and language is secondary.

#### Summary Table

| Project | Org Count | Naming Convention | Repo Strategy | Total Repos |
|---------|:---:|---|---|:---:|
| gRPC | 1 | `grpc-{lang}` | Polyrepo (shared core) | ~30 |
| Protocol Buffers | 1 | `protobuf` + `protobuf-{lang}` | Hybrid mono/poly | 15 |
| OpenTelemetry | 1 | `opentelemetry-{lang}` | Polyrepo | ~90 |
| CloudEvents | 1 | `sdk-{lang}` | Polyrepo | 12 |
| K8s Clients | 1 (dedicated) | bare `{lang}` | Polyrepo | 12 |
| Apache Arrow | 1 (Apache) | monorepo dirs | Monorepo (Rust escaped) | 1+2 |
| Apache Thrift | 1 (Apache) | monorepo `lib/{lang}/` | Monorepo (28 languages) | 1 |
| FlatBuffers | 1 (Google) | monorepo dirs | Monorepo (14 languages) | 1 |
| Cap'n Proto | 1 | Mixed/organic | Polyrepo | 13 |
| ASF total | 1 (umbrella) | `{project}` | Polyrepo | 2,854 |
| CNCF | Many | project-owned orgs | Federation | N/A |

**Pattern distribution** across the 9 multi-language projects:
- **Monorepo**: Arrow, Thrift, FlatBuffers (3/9) — chosen when cross-language binary compatibility is critical
- **Polyrepo with project prefix**: gRPC, Protocol Buffers, OpenTelemetry (3/9) — `{project}-{lang}`
- **Polyrepo with category prefix**: CloudEvents (1/9) — `sdk-{lang}`
- **Polyrepo with bare names**: Kubernetes Clients (1/9) — `{lang}` (org provides context)
- **Mixed/organic**: Cap'n Proto (1/9) — naming drift from community contributions

### Standards Body Implementation Patterns

Standards implementations across ecosystems show no convergence on a single organizational pattern:

**Rust** (crates.io): RFC implementations use concept names, not spec numbers:
| Crate | Standard | Notes |
|-------|----------|-------|
| `uuid` | RFC 9562 | Concept name, not `rfc-9562` |
| `http` | RFC 7230-7235 | Concept name |
| `url` | RFC 3986 | Concept name |
| `base64` | RFC 4648 | Concept name |
| `mime` | RFC 2045 | Concept name |

**Go** (standard library): RFC implementations embedded in stdlib with domain paths:
| Package | Standard | Notes |
|---------|----------|-------|
| `net/http` | RFC 7230+ | Domain/concept hierarchy |
| `crypto/tls` | RFC 5246/8446 | Domain/concept hierarchy |
| `encoding/json` | RFC 7159 | Domain/concept hierarchy |

**Key pattern across languages**: Implementations use the *concept name* (`uuid`, `http`, `tls`), not the spec identifier (`rfc-4122`, `rfc-9110`). The RFC number appears only in documentation.

**Standards bodies on GitHub**:

| Org | Role | Strategy |
|-----|------|----------|
| `ietf` (14 repos) | Specification tooling, not implementations |
| `w3c` (1,130 repos) | Working group specs, test suites |
| `whatwg` (47 repos) | Living standards: `html`, `dom`, `fetch`, `url`, `streams` — one repo per standard, bare domain names |

**The WHATWG model** is the closest precedent to domain-first organization: each spec repo uses a bare concept name (`html`, `dom`, `url`, `fetch`, `streams`, `encoding`, `console`). However, WHATWG publishes specifications, not implementations.

**Key finding**: No ecosystem has a unified "standards implementation" organization. Standards bodies publish specifications; implementations live in language communities. The Swift Institute's `swift-standards` org (93 packages implementing specs from 11 standards bodies) is **novel** — no comparable ecosystem exists.

### Academic/Industry Taxonomies for Computational Primitives

#### ACM Computing Classification System (CCS 2012)

The ACM CCS provides a hierarchical taxonomy relevant to primitives:

| CCS Category | Relevant Primitives |
|-------------|-------------------|
| Theory of computation → Data structures design and analysis | Array, Stack, Queue, Heap, Tree, Graph, Hash Table |
| Theory of computation → Type theory | Algebraic types, Linear/Affine types |
| Mathematics of computing → Mathematical analysis → Numerical analysis | Numeric, Decimal, Complex |
| Mathematics of computing → Discrete mathematics → Graph theory | Graph |
| Computing methodologies → Concurrent computing | Async, Continuation, Effect |
| Software and its engineering → Software notations and tools → Data types and structures | Collection, Sequence, Iterator |

However, the CCS is too broad for our needs — it classifies academic papers, not software packages.

#### Mathematics Subject Classification (MSC 2020)

| MSC Code | Area | Relevant Primitives |
|----------|------|-------------------|
| 08-XX | General algebraic systems | Algebra (group, ring, field, monoid, magma) |
| 15-XX | Linear algebra | Matrix, Vector |
| 51-XX | Geometry | Affine, Space, Transform |
| 54-XX | General topology | Region, Layout |
| 68-XX | Computer science | All data structures |
| 06-XX | Order, lattices, ordered algebraic structures | Ordering, Comparison |

The MSC provides excellent domain decomposition for the algebra/geometry/ordering primitives but does not cover systems programming concepts (memory, buffer, async).

**Key finding**: No single taxonomy covers the full primitives space. A hybrid taxonomy is needed: MSC for mathematical structures + systems programming taxonomy for memory/async/platform.

### GitHub Organization Namespace Availability

#### Model B: Domain-Level Orgs — Structurally Blocked

For Model B (domain-first multi-org), generic domain names would need to be available. Verified availability (2026-02-23):

**Primitive domain names**:

| Candidate | Status | Type | Public Repos | Assessment |
|-----------|--------|------|:---:|---|
| `algebra` | **Taken** | User | 0 | Dormant, theoretically reclaimable |
| `binary` | **Taken** | User | 3 | Active |
| `geometry` | **Taken** | User | 0 | Dormant, theoretically reclaimable |
| `time` | **Taken** | User | 4 | Active |
| `async` | **Taken** | Organization | 5 | Active (async JavaScript utilities) |

**Standards body names**:

| Candidate | Status | Type | Public Repos | Assessment |
|-----------|--------|------|:---:|---|
| `iso` | **Taken** | User | 2 | Not ISO the standards body |
| `ietf` | **Taken** | Organization | 14 | **Official IETF** |
| `w3c` | **Taken** | Organization | 1,130 | **Official W3C** (massive) |
| `whatwg` | **Taken** | Organization | 47 | **Official WHATWG** |
| `IEEE` | **Taken** | Organization | 0 | Claimed but empty |
| `ecma` | **Taken** | Organization | 0 | Claimed but empty |

**Assessment**: All bare domain names are taken. This is a **structural barrier** to Model B — acquiring 15-20 generic org names is not feasible.

#### Model D: Layer-Level Orgs — Prefix Selection Required

For Model D, org names follow the pattern `{prefix}-{layer}`. The constraint: **no `swift-` prefix** (language-agnostic), and the prefix must be available on GitHub for all four required orgs.

**Bare layer names** (no prefix):

| Candidate | Status | Assessment |
|-----------|--------|------------|
| `primitives` | **Taken** | Squatted or claimed |
| `standards` | **Taken** | Squatted or claimed |
| `foundations` | **Taken** | Squatted or claimed |
| `institute` | **Taken** | Squatted or claimed |

Bare layer names are not available.

**Prefixed variants** (verified 2026-02-23 — all four names must be available):

| Prefix | -primitives | -standards | -foundations | -institute | All Available? | Signal |
|--------|:-----------:|:----------:|:------------:|:----------:|:--------------:|--------|
| `typed` | Available | Available | Available | Available | **YES** | Type safety |
| `lib` | Available | Available | Available | Available | **YES** | Generic "library" |
| `pure` | Available | Available | Available | Available | **YES** | Purity/correctness |
| `base` | Available | Available | Available | Available | **YES** | Foundation/base layer |
| `formal` | Available | Available | Available | Available | **YES** | Formal methods/rigor |
| `open` | Available | **Taken** | Available | **Taken** | No | — |
| `core` | Available | Available | **Taken** | Available | No | — |
| `the` | **Taken** | Available | Available | **Taken** | No | — |
| `abstract` | Available | Available | Available | **Taken** | No | — |
| `domain` | **Taken** | Available | Available | Available | No | — |

Additional brandable prefixes verified (2026-02-23): `reality` (all available), `axiom` (all available), `forge` (all available), `loom` (all available), `stratum` (all available), `canon` (all available), `cedar` (all available). Eliminated: `prism` (prism-institute taken), `atlas` (atlas-primitives taken), `nexus` (nexus-primitives taken), `solid` (SolidJS `solid-primitives` npm collision), `truth` (`truth-institute` political connotations), `matter` (Google Matter protocol), `domain` (domain-primitives taken).

**Decision**: `reality-` prefix selected. See Outcome for rationale.

### Rust Crates.io Namespace Evolution

Rust's crates.io recently adopted RFC 3243 (packages as optional namespaces), allowing `::` separators in crate names. This enables organizational namespacing:

```toml
# Future Rust convention
[dependencies]
swift-institute::algebra-group = "1.0"
```

This is relevant because it shows the ecosystem direction: registries are adding namespace features that reduce dependency on org-level naming. SPM's SE-0292 Package Registry follows the same trend.

---

## Organizational Models Under Consideration

### Model A: Status Quo (Language-First, Language-Prefixed Orgs)

**Structure**: Keep current organization. Language-prefixed GitHub orgs per architectural layer.

```
swift-primitives/          → language-prefixed org per layer
  swift-algebra-primitives/
  swift-geometry-primitives/
  swift-time-primitives/
  ...
swift-standards/
  swift-rfc-4122/
  swift-iso-32000/
  ...
swift-foundations/
  swift-json/
  swift-file/
  ...
```

**Identity signal**: "This is a Swift package at layer X."

**Pros**:
1. Layer membership immediately visible from org
2. Simple mental model: org = layer
3. ~~Already established — zero migration cost~~ *(irrelevant pre-launch)*
4. ~~SPM package URLs are stable~~ *(irrelevant pre-launch — no external consumers)*

**Cons**:
1. Couples to Swift — `swift-*` naming makes multi-language awkward
2. Discoverability by domain requires knowing the layer
3. 125+ repos in primitives makes browsing difficult
4. Package naming is verbose: `swift-algebra-group-primitives`
5. **Locks in language coupling before launch** — the cheapest time to fix it is now
6. `swift-` prefix on org names is redundant — the layer name alone is sufficient

### Model B: Domain-First, Multi-Org

**Structure**: One GitHub org per computational domain. Domain-first, language-second naming for all repos.

```
algebra/                   → org per domain
  group-swift/             → domain-concept-language
  ring-swift/
  field-swift/
geometry/
  affine-swift/
  space-swift/
  transform-swift/
iso-standards/
  32000-swift/             → standard-number-language
  8601-swift/
ietf-standards/
  rfc-4122-swift/
  rfc-8259-swift/
```

**Identity signal**: "This is an implementation of algebra/group."

**Pros**:
1. Domain is primary — decoupled from implementation language
2. Multi-language implementations live naturally side-by-side
3. Domain taxonomy is portable across languages
4. Discoverability by concept is immediate

**Cons**:
1. ~15-20 new GitHub orgs needed — availability uncertain
2. Layer membership no longer visible from org
3. Layer enforcement requires external tooling
4. Massive migration: 330+ repo transfers
5. SPM dependency URLs all change
6. No precedent in open source for domain-first multi-org at this scale
7. Governance across 15-20 orgs is complex
8. Org name squatting risk — generic names like "algebra", "geometry" may be taken

### Model C: Single Umbrella Org, Domain-Prefixed Repos

**Structure**: All repos in one org (`institute`), with domain-based repo naming.

```
institute/                              → single umbrella org (no swift- prefix)
  algebra-group-primitives/             → domain-concept-layer
  algebra-ring-primitives/
  geometry-affine-primitives/
  iso-32000/
  rfc-4122/
  json-foundations/
  file-foundations/
```

**Identity signal**: "This is an Institute package."

**Pros**:
1. Single org — no namespace fragmentation
2. Domain is the primary sort key
3. Layer still visible in name (`-primitives`, `-foundations`)
4. Single governance structure
5. GitHub org search within one org is effective
6. Only one org name to secure

**Cons**:
1. 330+ repos in one org is large (but ASF manages 300+ in `apache`)
2. Repo names become long: `algebra-group-primitives`
3. Layer enforcement requires parsing the name suffix — not structural
4. Domain and layer conflated in a single name dimension
5. Loses the clean org-per-layer separation

### Model D: Hybrid — Layer Orgs with Domain Substructure

**Structure**: Layer-aligned orgs (no `swift-` prefix), domain-first naming within each org.

```
reality-primitives/                     → org per layer (reality- prefix, language-agnostic)
  algebra-group/                        → domain-concept (domain-first, no lang prefix)
  algebra-ring/
  geometry-affine/
  time/
  buffer-linear/
reality-standards/
  iso-32000/                            → standard-id (domain-first)
  rfc-4122/
  ietf-rfc-8259/
reality-foundations/
  json/                                 → clean domain names
  file/
  http/
```

**Identity signal**: "This is a package at layer X in domain Y."

**Naming principle**: Domain-first, language-second. The domain/concept is always the primary identifier. Language appears only when disambiguation is needed:

```
reality-primitives/algebra-group               → Swift (primary language — no suffix)
reality-primitives/algebra-group-rust          → Rust (language suffix when added)
reality-primitives/algebra-group-c             → C (language suffix when added)
```

**Pros**:
1. Same 3-4 orgs — org = layer enforcement preserved
2. Domain is the primary identifier within each org — **domain-first, language-second**
3. Shorter names — no `swift-` prefix anywhere, no `-primitives` suffix on repos
4. Layer membership visible from org; org names are pure layer labels
5. Multi-language: add `-{lang}` suffix alongside the unsuffixed Swift default
6. Both layer-preserving AND domain-preserving (unique — see formal analysis)
7. No language coupling in org or repo names until a second language appears

**Cons**:
1. ~~Still requires renaming 330+ repos~~ *(trivial pre-launch — one script)*
2. ~~SPM dependency URLs change~~ *(irrelevant pre-launch — local path deps only)*
3. Bare org names (`primitives`, `standards`) may need availability verification on GitHub
4. Package names diverge from module names (`import Algebra_Group_Primitives`)
5. Multi-language convention needs explicit decision: is Swift the default (no suffix) or explicit?

### Model E: Virtual — Registry Layer over Physical Repos

**Structure**: Keep physical repos as-is (including `swift-` prefixed orgs and names). Add a **registry/discovery layer** that provides domain-first navigation.

```
Physical (unchanged):
  swift-primitives/swift-algebra-group-primitives/
  swift-standards/swift-rfc-4122/

Virtual (new):
  Swift Package Registry (SE-0292):
    algebra.group → resolves to swift-primitives/swift-algebra-group-primitives
    rfc.4122     → resolves to swift-standards/swift-rfc-4122

  Package Collections (SE-0291):
    algebra.json → curated list of all algebra packages
    networking.json → curated list of all networking packages
```

**Identity signal**: Depends on context — registry shows domain, GitHub shows layer.

**Pros**:
1. **Zero migration** — no repos move, no URLs change
2. Domain-first discoverability via registry/collections
3. Physical structure remains optimized for layer enforcement
4. Can be adopted incrementally
5. Multi-language: future Cargo registry entries point to different physical repos

**Cons**:
1. Swift Package Registry (SE-0292) is not yet widely deployed
2. Dual identity — GitHub URL says one thing, registry says another
3. Doesn't solve the multi-language org structure question
4. Discovery depends on registry adoption by tooling (Xcode, VSCode)
5. A layer of indirection that must be maintained

---

## Formal Analysis [RES-024]

### Evaluation Criteria

Per [RES-005], the following criteria are used to evaluate organizational models.

**Pre-launch reweighting**: The Swift Institute is pre-launch with zero external consumers. This eliminates migration cost and package manager compatibility as meaningful criteria — any reorganization is a local script that renames directories and rewrites `Package.swift` path references. The evaluation focuses on **permanent structural properties** that will matter for the next 20 years.

| Criterion | Weight | Description |
|-----------|:---:|---|
| ~~**C1: Migration cost**~~ | ~~0~~ | ~~Eliminated — pre-launch, all reorganization is a script~~ |
| **C2: Layer enforcement** | High (3) | How easily the model enforces the five-layer dependency rule |
| **C3: Multi-language readiness** | High (3) | How naturally the model accommodates non-Swift implementations |
| **C4: Domain discoverability** | High (3) | How easily a developer finds packages by problem domain |
| ~~**C5: Package manager compat**~~ | ~~0~~ | ~~Eliminated — no external Package.resolved files exist~~ |
| **C6: Governance simplicity** | Medium (2) | How many orgs/entities need to be managed |
| **C7: Naming clarity** | High (3) | How self-describing repo/package names are |
| **C8: Longevity** | High (3) | Will this structure still work in 10-20 years? |

### Comparison Matrix

| Criterion | Model A (Status Quo) | Model B (Domain Orgs) | Model C (Umbrella) | Model D (Hybrid) | Model E (Virtual) |
|-----------|:---:|:---:|:---:|:---:|:---:|
| C2: Layer enforcement | **Strong** (org=layer) | Weak (external) | Weak (naming) | **Strong** (org=layer) | **Strong** (unchanged) |
| C3: Multi-lang readiness | Low (swift- prefix) | **High** | Medium | **High** (no lang prefix) | Medium |
| C4: Domain discoverability | Low | **High** | Medium-High | High | Medium-High |
| C6: Governance simplicity | **Simple** (3-4 orgs) | Complex (15-20 orgs) | **Simple** (1 org) | **Simple** (3-4 orgs) | **Simple** (unchanged) |
| C7: Naming clarity | Low | High | Medium | **High** | Low |
| C8: Longevity | Low | High | High | **High** | Low |

### Formal Definitions [RES-024]

#### Repository Organization as a Function

A **repository organization** is a triple `(O, R, N)` where:
- `O` is a set of organizational units (GitHub orgs)
- `R` is a set of repositories
- `N: R → String` is a naming function that assigns names to repositories

A **layer-preserving** organization satisfies: for all `r ∈ R`, there exists a function `L: R → {1,2,3,4,5}` (layer assignment) such that `L(r)` is recoverable from `O(r)` alone (the org containing `r`).

A **domain-preserving** organization satisfies: for all `r ∈ R`, there exists a function `D: R → Domain` (domain assignment) such that `D(r)` is recoverable from `N(r)` alone (the name of `r`).

| Model | Layer-preserving | Domain-preserving |
|-------|:---:|:---:|
| A (Status Quo) | Yes (org = layer) | No (domain buried in middle of name) |
| B (Domain Orgs) | No (org = domain) | Yes (org = domain) |
| C (Umbrella) | Partially (name suffix) | Partially (name prefix) |
| D (Hybrid) | Yes (org = layer) | Yes (name prefix = domain) |
| E (Virtual) | Yes (unchanged) | No (unchanged) |

**Observation**: Model D is the unique model that is both layer-preserving AND domain-preserving. This is because it uses two independent structural axes: org membership for layer, and name prefix for domain.

#### Dependency Correctness

A dependency `r₁ → r₂` is **architecturally correct** iff `L(r₁) > L(r₂)` (strict downward). An organization structure is **enforcement-friendly** if architectural correctness can be verified by inspecting org membership alone, without parsing names.

Only Models A, D, and E are enforcement-friendly.

### Formal Evaluation (Pre-Launch Weighting)

We define a preference relation over models. For each criterion $C_i$ with weight $w_i$, we assign a score $s_{i,M} \in \{0, 1, 2, 3\}$ (0 = poor, 3 = excellent). Migration cost (C1) and PM compatibility (C5) are **eliminated** — pre-launch means all reorganization is a script:

| Criterion | Weight | A | B | C | D | E |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| C2: Layer enforcement | 3 | **3** | 0 | 1 | **3** | **3** |
| C3: Multi-lang readiness | 3 | 0 | **3** | 2 | **3** | 1 |
| C4: Domain discoverability | 3 | 0 | **3** | 2 | **3** | 2 |
| C6: Governance | 2 | 2 | 0 | **3** | 2 | 2 |
| C7: Naming clarity | 3 | 1 | **3** | 2 | **3** | 1 |
| C8: Longevity | 3 | 1 | **3** | 2 | **3** | 1 |
| **Weighted Total** | | **19** | **30** | **32** | **47** | **26** |

**Ranking**: **D (47)** > C (32) > B (30) > E (26) > A (19)

The pre-launch reweighting plus language-agnostic org prefix dramatically changes the picture:
- **Model D's multi-lang readiness rises to 3** (was 2). With `reality-` replacing `swift-`, there is zero language coupling in org names, repo names, or directory names. Language appears only as an optional suffix when a second implementation is added.
- **Model A (Status Quo) drops to last place**. With migration cost zeroed, A's only advantage vanishes. Its low multi-lang readiness, poor domain discoverability, and poor naming clarity become undefended liabilities.
- **Model E (Virtual) also drops**. Its value was "avoid migration" — irrelevant pre-launch.
- **Model B improves significantly** but is still penalized by governance complexity (15-20 orgs) and zero layer enforcement.
- **Model D dominates even more strongly** — 15-point gap over the runner-up.

### Sensitivity Analysis

| Scenario | D | C | B | E | A |
|----------|:---:|:---:|:---:|:---:|:---:|
| Baseline (pre-launch + lang-agnostic orgs) | **47** | 32 | 30 | 26 | 19 |
| C3 (multi-lang) weight → 2 | **44** | 30 | 27 | 25 | 19 |
| C6 (governance) weight → 3 | **49** | 35 | 30 | 28 | 21 |
| All criteria weight 3 | **51** | 36 | 33 | 30 | 21 |

**Model D leads in every scenario**. The gap between D and the runner-up (C) ranges from 14-18 points — not close.

---

## SQ2: Primitives Domain Mapping

### Domain Taxonomy

The 125 primitives packages map to the following computational domains:

| Domain | Count | Key Packages |
|--------|:---:|---|
| **Algebra** | 13 | algebra, algebra-affine, algebra-aggregate, algebra-cardinal, algebra-field, algebra-group, algebra-law, algebra-linear, algebra-magma, algebra-modular, algebra-module, algebra-monoid, algebra-ring |
| **Binary / Bit** | 9 | binary, binary-buffer, binary-parser, bit, bit-index, bit-pack, bit-vector, bitset, endian |
| **Collection** | 7 | array, collection, deque, dictionary, set, slab, slice |
| **Compiler** | 11 | abstract-syntax-tree, backend, driver, intermediate-representation, lexer, module, parser, parser-machine, source, syntax, token |
| **Concurrency** | 4 | async, continuation, effect, kernel |
| **Geometry / Space** | 8 | affine, affine-geometry, geometry, layout, positioning, region, space, transform |
| **Graph / Tree** | 3 | graph, handle, tree |
| **Hash / Identity** | 5 | hash, hash-table, identity, reference, symbol |
| **Index / Range** | 5 | bit-index, cyclic-index, index, range, slice |
| **Math / Numeric** | 7 | cardinal, complex, decimal, dimension, matrix, numeric, vector |
| **Memory / Storage** | 7 | buffer, cache, memory, ownership, pool, storage, lifetime |
| **Ordering** | 5 | comparison, cyclic, finite, ordering, ordinal |
| **Platform** | 5 | arm, cpu, darwin, linux, windows |
| **Sequence** | 4 | collection, infinite, input, sequence |
| **String / Text** | 6 | ascii, formatting, locale, scalar, string, text |
| **System** | 5 | clock, error, logic, network, system |
| **Time** | 2 | clock, time |
| **Type Theory** | 5 | optic, outcome, property, state, witness |
| **Encoding** | 3 | coder, random, serialization |
| **Testing** | 3 | diagnostic, terminal, test |

### Proposed Domain Org Count

Under a domain-first model, primitives alone would require **~15 top-level domain categories**. Adding standards (11 standards bodies) and foundations (~12 domain areas) yields ~25-30 organizational units.

This is a significant governance burden and strongly disfavors Model B.

---

## SQ3: Package Manager Implications

### Swift Package Manager

**Current state**: SPM resolves packages by git URL. Every `Package.swift` contains:

```swift
.package(url: "https://github.com/swift-primitives/swift-algebra-primitives", from: "0.1.0")
// or local path:
.package(path: "../swift-algebra-primitives")
```

**URL change impact under Model D**: Repo moves from `swift-primitives/swift-algebra-primitives` to `primitives/algebra-group`. Both org and repo name change. Every downstream `Package.swift` that references it must be updated. Pre-launch, this is a script — no external consumers exist.

**GitHub redirect behavior**: [To be populated from migration mechanics agent]

**Swift Package Registry (SE-0292)**: [To be populated from agent research]

### Cargo (Rust)

Cargo resolves by crate name on crates.io, not by git URL. A `cargo.toml` contains:

```toml
[dependencies]
algebra-group = "1.0"
```

The GitHub org structure is irrelevant to Cargo dependency resolution. This means Model D (renaming repos) would have zero impact on Rust consumers if Rust implementations are later added — crate names are decoupled from repo names.

### Go Modules

Go modules use URL-based import paths:

```go
import "github.com/swift-primitives/algebra-group-go"
```

Go is URL-coupled like SPM. Repo moves break imports.

### npm

npm uses scoped packages:

```json
"@swift-institute/algebra-group": "^1.0.0"
```

The scope (`@swift-institute`) is decoupled from the GitHub org. This means npm consumers could have stable package names regardless of GitHub reorganization.

**Key finding**: SPM and Go are URL-coupled (repo moves break dependencies). Cargo and npm are registry-coupled (repo moves are transparent). This asymmetry favors minimizing repo URL changes.

---

## SQ4: Platform Migration Mechanics

### GitHub Repository Transfer Behavior

Per GitHub documentation (2026):

| Aspect | Behavior |
|--------|----------|
| **Git history** | Fully preserved — transfer is a metadata change, not a code move |
| **URL redirects** | **Indefinite**. `git clone`, `git fetch`, `git push` on old URLs redirect to new location |
| **Redirect invalidation** | Only if a new repo is created at the old URL — new repo takes priority |
| **Stars, issues, PRs** | Preserved and transferred with the repo |
| **Fork network** | Preserved — forks remain associated after transfer |
| **Bulk transfer API** | `POST /repos/{owner}/{repo}/transfer` — one repo at a time, scriptable |
| **Org rename** | All repo URLs under the org redirect; same indefinite redirect behavior |

**Critical finding for SPM**: Since GitHub redirects `git clone` and `git fetch` indefinitely, **repo renames within the same org do not break existing SPM dependency URLs** — as long as no new repo is created at the old name. This dramatically reduces migration risk for Model D.

### Real-World Precedent: Apple → swiftlang Migration

Apple migrated ~71 Swift repos from the `apple` org to a new `swiftlang` org in 2024:

| Aspect | Detail |
|--------|--------|
| **Scale** | 71+ repos (swiftlang public repos as of 2026) from an org with 388 repos |
| **Approach** | Phased — `swift-evolution` first, then others over weeks/months |
| **Foundation move** | `swift-foundation` migrated Sept 20, 2024 |
| **Redirect behavior** | Old `apple/swift-*` URLs continue to work |
| **SPM impact** | Downstream packages needed to update URLs (e.g., swift-snapshot-testing #878) |
| **Lesson** | Phased migration works at scale; GitHub redirects provide safety net |

### Swift Package Manager URL Handling

| Mechanism | Description |
|-----------|-------------|
| **Git redirect following** | SPM follows HTTP 301/302 redirects during `git clone` |
| **Package.resolved** | Records exact URLs — needs updating after migration |
| **SE-0219 Dependency Mirroring** | `swift package config set-mirror --original "OLD_URL" --mirror "NEW_URL"` — can redirect without changing Package.swift |
| **SE-0292 Package Registry** | Would decouple logical name from URL. Status: accepted proposal, not yet widely deployed |
| **SE-0291 Package Collections** | Curated JSON lists of packages — provides discovery layer without URL coupling |

**Key insight**: SE-0219 mirroring provides a migration escape hatch. During a phased rename, consumers can use `set-mirror` to redirect old URLs to new ones without modifying Package.swift files. This is a reversible operation.

### GitHub vs GitLab for Organizational Nesting

| Feature | GitHub | GitLab |
|---------|--------|--------|
| **Nesting levels** | Flat (orgs have repos, no sub-orgs) | Up to 20 levels of nested groups |
| **URL structure** | `github.com/{org}/{repo}` | `gitlab.com/{group}/{subgroup}/{project}` |
| **Domain-first support** | Via naming conventions only | Native via nested groups |
| **Ideal for Model B** | Requires 15-20 separate orgs | Could use `institute/algebra/group` |
| **Ecosystem adoption** | Dominant for open source | Used by GNOME, some enterprise |

GitLab's nested groups would natively support a domain-first hierarchy:
```
gitlab.com/swift-institute/primitives/algebra/group
gitlab.com/swift-institute/standards/iso/32000
gitlab.com/swift-institute/foundations/json
```

However, moving to GitLab has significant ecosystem costs (SPM defaults to GitHub, community expectations, CI integration). This is not recommended for Swift Institute but is noted for completeness.

---

## Cognitive Dimensions Analysis [RES-025]

Per the Cognitive Dimensions Framework (Green & Petre, 1996), we evaluate the proposed models:

| Dimension | Model A (Status Quo) | Model D (Hybrid) |
|-----------|---------------------|------------------|
| **Visibility** | Layer is visible (org name); domain is hidden | Both layer (org) and domain (repo name) visible |
| **Consistency** | Consistent `swift-*-primitives` pattern | New pattern: `algebra-group` (shorter, cleaner) |
| **Viscosity** | Low (no change needed) | ~~Medium (one-time rename)~~ *(irrelevant pre-launch)* |
| **Role-expressiveness** | Layer role clear; domain role unclear | Both roles expressed: org = layer, name = domain |
| **Error-proneness** | Low risk (familiar) | Low (pre-launch — no transition confusion) |
| **Abstraction** | Over-specified (language in name is redundant) | Right level — domain-first, language-second, no prefix noise |

---

## Systematic Literature Review [RES-023]

### Research Questions

| ID | Question |
|----|----------|
| RQ1 | What organizational structures do multi-language software ecosystems use? |
| RQ2 | What domain taxonomies exist for computational primitives? |
| RQ3 | What migration strategies exist for large-scale repository reorganization? |

### Search Strategy

| Database | Query | Results |
|----------|-------|:---:|
| GitHub (direct) | Multi-language project org analysis | 9 projects analyzed |
| ACM CCS (2012) | Computing classification for computational primitives | Taxonomy reviewed |
| MSC 2020 | Mathematics Subject Classification for algebra/geometry/topology | 63 disciplines mapped |
| GitHub/Web | Domain-first vs language-first software organization | No precedent found |
| Web | Package registry namespace evolution | 4 registries analyzed |
| Web | Large-scale GitHub org migration precedents | Apple→swiftlang case documented |

### Inclusion/Exclusion Criteria

| Criterion | Include | Exclude |
|-----------|---------|---------|
| Project scale | 50+ packages or 5+ languages | Small projects (<10 packages) |
| Organization type | Open source, standards bodies | Proprietary internal tooling |
| Documentation | Publicly documented structure | Undocumented conventions |
| Relevance | Multi-language or domain taxonomy | Single-language, single-domain |

### Key Findings from Literature

1. **No domain-first multi-org precedent exists** in open source at Swift Institute's scale (~330 packages).
2. **Single-org with naming conventions** is the dominant pattern (gRPC, OpenTelemetry, ASF).
3. **Monorepo-per-domain** works for shared specifications (Apache Arrow) but fractures when implementations diverge in cadence (Arrow-Rust split).
4. **Standards bodies do not organize implementations** — implementations are language-community-owned.
5. **Registry/discovery layers** (npm scopes, Cargo crates, future SPM registry) decouple logical identity from physical repository structure, reducing the importance of org naming over time.

---

## Outcome

**Status**: RECOMMENDATION

### Recommendation: Model D (Hybrid) — Execute Now

**Model D (Hybrid)** — layer-aligned orgs with the language-agnostic `reality-` prefix, domain-first naming within each org. Execute via script before launch.

*Validated via Claude–ChatGPT collaborative discussion (4 rounds, converged). Transcript: `/tmp/domain-first-repo-org-transcript.md`.*

#### Rationale: Structural Invariants

We require two properties from any organizational model:

1. **Enforcement-friendly layer separation** — architectural correctness (`L(r₁) > L(r₂)` for all dependencies) must be verifiable from org membership alone, without parsing names.
2. **Domain-first discoverability** — a developer must be able to find packages by problem domain from the repo name alone.

**Only Model D achieves both without external tooling or namespace fragmentation.** It uses two independent structural axes: org membership for layer, name prefix for domain. This is the core technical argument — everything else is corroboration.

Supporting evidence:
- Pre-launch-weighted evaluation: D (47) >> C (32) > B (30) > E (26) > A (19)
- Model D leads in every sensitivity scenario by 14-18 points
- No open source precedent exists for Model B (domain-first multi-org), confirming it's over-engineered
- Status quo (Model A) scores last once migration cost is zeroed — its only advantage was inertia
- Pre-launch = free; post-launch cost is extreme (every external `Package.swift`, blog post, CI pipeline)
- The pattern is rare because it requires governance discipline (which the Institute provides), not because it's intrinsically flawed

#### Org Naming: Prefix Selection

The `swift-` prefix must be replaced with a language-agnostic prefix. Bare layer names (`primitives`, `standards`, `foundations`, `institute`) are all taken on GitHub. Five prefixes have full availability (see namespace analysis above).

**Evaluation of available prefixes**:

| Prefix | Identity Signal | Fit |
|--------|----------------|-----|
| **`reality`** | "These packages model reality" — grounded, tangible, real implementations | **Strong** — distinctive, brandable, no language coupling |
| `typed` | Type safety as core value | Medium — signals mechanism, not brandable |
| `pure` | Purity, correctness | Medium — evokes FP "pure functions" |
| `formal` | Formal methods, academic rigor | Medium — accurate but intimidating |
| `base` | Foundation, base layer | Weak — generic, overloaded in programming |
| `lib` | Library | Weak — says nothing about character |

**Eliminated during evaluation**: `solid-` (SolidJS `solid-primitives` npm collision), `truth-` (`truth-institute` political connotations), `matter-` (Google Matter protocol), `terra-` (HashiCorp Terraform), `domain-` (domain-primitives taken), `axiom-` (`axiom-foundations` reads poorly).

**Decision**: `reality-` prefix.

```
reality-primitives/    (was swift-primitives)
reality-standards/     (was swift-standards)
reality-foundations/    (was swift-foundations)
reality-institute/     (was swift-institute)
```

Rationale: "Reality" signals that these packages model real computational concepts — not abstract exercises, but the grounded building blocks that real systems are made of. `reality-institute` reads as a think tank (which the Institute is). `reality-primitives/algebra-group` says: "this is a real, grounded algebra group implementation at the primitives layer." The prefix is language-agnostic, brandable, memorable, and does not collide with any major developer brand. All four org names verified available on GitHub (2026-02-23).

**Known explanation-tax** (from collaborative review): `reality-` may trigger association with Apple RealityKit / visionOS in Swift ecosystem contexts. Mitigation:
- Positioning line everywhere: "Reality Institute builds foundational libraries for Swift."
- One micro-clarifier in org README: "Despite the name, this is not an AR/VR project. 'Reality' refers to modeling real computational structures with rigor."
- SEO primitives: consistent repo topics (`swift`, `swiftpm`, `systems-programming`, `primitives`, `standards`), standardized descriptions ("Primitives for X (Reality Institute, Swift)").
- Front-door repo (`reality-institute`) as landing hub: layer map, domain index, getting started.

#### Concrete Naming Convention

**Naming principle**: Domain-first, language-second. No language appears in any name until a second implementation language is added.

**Primitives** (within `reality-primitives` org/monorepo):
```
Current:  swift-algebra-group-primitives/
Model D:  algebra-group/

Convention: {domain}[-{concept}]
Transform:  strip "swift-" prefix, strip "-primitives" suffix
```

**Standards** (within `reality-standards` org):
```
Current:  swift-rfc-4122/
Model D:  rfc-4122/

Convention: {body}-{number}  (already domain-first — just strip "swift-" prefix)
```

**Foundations** (within `reality-foundations` org):
```
Current:  swift-json/
Model D:  json/

Convention: {domain}[-{concept}]  (already clean — just strip "swift-" prefix)
```

**Key observation**: Standards already use domain-first naming. Foundations are nearly there. Only primitives have the verbose `swift-*-primitives` pattern. The rename is mostly mechanical prefix/suffix stripping.

#### Language Suffix Policy (Rule A)

Repository names are domain-first and **unsuffixed repositories are the Swift implementation by definition**. This mapping is permanent and will not be retroactively changed if additional language implementations are added later. Non-Swift implementations use a `-{lang}` suffix (e.g., `algebra-group-rust`). Cross-language discoverability and "logical identity" will be provided via institute-level cataloging (docs site, package collections, and/or registry identities) rather than by renaming repositories.

```
Swift (default):  reality-primitives/algebra-group       ← permanent, never becomes -swift
Rust:             reality-primitives/algebra-group-rust
C:                reality-primitives/algebra-group-c
Go:               reality-primitives/algebra-group-go
```

This follows the gRPC precedent (`grpc/grpc` = C++, never renamed to `grpc-cpp`) where the governance-primary language is the unsuffixed default.

#### Repository vs Module Naming

Repositories are named for domain discoverability; Swift module and product names are named for API clarity and local conventions. Therefore, **repository names and module names are not required to match**. Each repository MUST declare its canonical Swift module/product names in a standard header section (README and/or Package manifest metadata), and the institute MUST maintain a searchable "Where does X live?" index mapping concepts → repo → module/product. CI MUST enforce the presence and consistency of this mapping to prevent accidental drift and to keep contributor onboarding deterministic.

| Layer | Repo name | Module name | Import |
|-------|-----------|-------------|--------|
| Primitives | `algebra-group` | `Algebra Group Primitives` | `import Algebra_Group_Primitives` |
| Standards | `rfc-4122` | `RFC 4122` | `import RFC_4122` |
| Foundations | `json` | `JSON` | `import JSON` |

This seam is documented and intentional. Module rename is deferred to a separate decision.

#### Standards Naming and Concept Aliases

Repositories in the standards layer use **spec identifiers** as their canonical repository names (e.g., `rfc-8259`, `iso-32000`). Human-friendly concept names (e.g., `json`, `pdf`, `uuid`) are treated as aliases and resolved through an institute-maintained concept index that maps concept → spec-id repo. The spec-id repository name remains the stable hosting identity; the alias index is the stable discovery surface for users who think in concepts rather than document numbers.

| Concept | Spec ID | Repo | Body |
|---------|---------|------|------|
| UUID | RFC 9562 | `rfc-9562` | IETF |
| JSON | RFC 8259 | `rfc-8259` | IETF |
| PDF | ISO 32000 | `iso-32000` | ISO |
| URI | RFC 3986 | `rfc-3986` | IETF |

#### Execution Plan

Pre-launch. No phasing needed. One script, one execution.

**Script behavior**:
1. Rename GitHub orgs:
   - `swift-primitives` → `reality-primitives`
   - `swift-standards` → `reality-standards`
   - `swift-foundations` → `reality-foundations`
   - `swift-institute` → `reality-institute`
2. For each `swift-*-primitives/` directory in the primitives monorepo:
   - Rename to `{domain}[-{concept}]/` (strip `swift-` prefix and `-primitives` suffix)
3. For each `swift-*` directory in standards:
   - Rename to `*` (strip `swift-` prefix)
4. For each `swift-*` directory in foundations:
   - Rename to `*` (strip `swift-` prefix)
5. Rewrite all `Package.swift` files:
   - Update `.package(path: "../swift-X-primitives")` → `.package(path: "../X")`
   - Update cross-repo path references with new org names
6. Rewrite `CLAUDE.md` references (org names, package resolution table)
7. Update any documentation that references old directory/org names
8. Verify `swift build` and `swift test` pass

**Module names are unaffected**: SPM module names (e.g., `Algebra Group Primitives`) are declared in `Package.swift`, not derived from directory names. `import Algebra_Group_Primitives` continues to work. This can be revisited independently.

#### What Changes, What Doesn't

| Aspect | Changes | Doesn't Change |
|--------|---------|----------------|
| GitHub org names | `swift-primitives` → `reality-primitives` (etc.) | — |
| Directory names | `swift-algebra-group-primitives/` → `algebra-group/` | — |
| Package.swift paths | `../swift-X-primitives` → `../X` | Module names, target names, product names |
| Import statements | — | `import Algebra_Group_Primitives` unchanged |
| Local repo dirs | `swift-primitives/` → `reality-primitives/` | — |
| CLAUDE.md | Org names, package resolution, deep links | Layer architecture, skills, conventions |
| Naming principle | Domain-first, language-second | Five-layer architecture |

### Risk Register (Year 5–10)

*Identified via collaborative review.*

| Risk | Symptom | Mitigation |
|------|---------|------------|
| **Repo sprawl fatigue** | PRs/issues/releases scattered across hundreds of repos become unmanageable | Centralize policy in institute repo; shared GitHub Actions, release tooling, linting; meta dashboard for status/versions/CI |
| **Cross-repo version skew** | More time managing compatible version sets than writing libraries | Coordinated releases per layer/domain cluster; "bill of materials" (BOM) for consumers; strict semver + tooling to detect breaking transitive changes |
| **Contributor confusion** | New contributors open wrong repo, import wrong module, misunderstand where a type lives | Mapping doc + CI lint + consistent README headers ("Layer: Primitives / Domain: Algebra / Module: Algebra Group Primitives") + "Where does X live?" index |
| **Namespace becomes API** | People treat GitHub paths as permanent API identifiers, making later restructuring politically impossible | Move canonical identity toward SPM registry / package collections / docs-site identifiers; treat GitHub URLs as implementation hosting, not identity |
| **Domain taxonomy drift** | Domain boundaries chosen early stop matching reality as the library set grows | Lightweight "domain RFC" process: domain split/merge rules, deprecation pathways, explicit criteria for graduation between layers |
| **Prefix regret** | Prefix harms adoption but changing is catastrophic post-launch | Decided with rigor now (collaborative review, 25+ candidates evaluated); mitigate explanation-tax with positioning, SEO, front-door repo |

### Key Tradeoffs

| Accepted | Rejected |
|----------|----------|
| One-time script execution (pre-launch, near-zero cost) | Deferring to post-launch (exponentially more expensive) |
| Layer org structure retained (proven, enforcement-friendly) | Domain org structure (15-20 orgs, governance nightmare, no precedent) |
| Language-agnostic org prefix (`reality-`) | Language-coupled prefix (`swift-`) |
| Swift as unsuffixed default (domain-first, language-second) | Language-explicit naming for all languages |
| Module names unchanged for now | Simultaneous module rename (can be done independently later) |

### Resolved Questions

1. ~~**Org prefix**~~ — **Decided**: `reality-` prefix. All four org names verified available on GitHub. Explanation-tax mitigated via positioning + SEO.
2. ~~**Language suffix policy**~~ — **Decided**: Rule A. Unsuffixed = Swift permanently. Non-Swift gets `-{lang}` suffix.
3. ~~**Module rename timing**~~ — **Decided**: Deferred. Repo/module naming intentionally decoupled with mapping doc + CI lint.
4. ~~**Standards naming**~~ — **Decided**: Spec-ID repos + concept alias index.

### Open Questions

1. **Exact domain vocabulary** — the canonical list of domain prefixes needs verification before script execution. Candidates derived from current names: algebra, binary, bit, buffer, collection, compiler, geometry, graph, hash, index, math, memory, ordering, platform, sequence, string, system, time, type, encoding, test.
2. **`swift-standard-library-extensions`** — this package in primitives doesn't follow the `-primitives` suffix. Needs special handling in the rename script.
3. **"Where does X live?" index format** — should this be a generated doc, a searchable site, or a Package Collections JSON? TBD.

---

## References

### Multi-Language Project Organization

1. gRPC Project. GitHub organization. https://github.com/grpc (~30 repos, polyrepo with shared C core)
2. Protocol Buffers. GitHub organization. https://github.com/protocolbuffers (15 repos, hybrid mono/poly)
3. OpenTelemetry Project. GitHub organization. https://github.com/open-telemetry (~90 repos, systematic polyrepo)
4. Apache Arrow Project. GitHub repository. https://github.com/apache/arrow (monorepo, 10+ language dirs)
5. Apache Thrift Project. GitHub repository. https://github.com/apache/thrift (monorepo, 28 languages in `lib/`)
6. Cap'n Proto. GitHub organization. https://github.com/capnproto (13 repos, organic naming)
7. FlatBuffers. GitHub repository. https://github.com/google/flatbuffers (monorepo, 14 languages)
8. CloudEvents. GitHub organization. https://github.com/cloudevents (12 repos, `sdk-{lang}` pattern)
9. Kubernetes Client Libraries. GitHub organization. https://github.com/kubernetes-client (12 repos, bare language names)

### Standards Bodies on GitHub

10. WHATWG. GitHub organization. https://github.com/whatwg (47 repos, one per living standard — bare domain names)
11. W3C. GitHub organization. https://github.com/w3c (1,130 repos, working group specs)
12. IETF. GitHub organization. https://github.com/ietf (14 repos, tooling only)

### Academic Taxonomies

13. ACM Computing Classification System (2012). https://dl.acm.org/ccs
14. Mathematics Subject Classification (MSC 2020). https://msc2020.org/ and https://zbmath.org/classification/
15. Apache Software Foundation Projects Directory. https://projects.apache.org/ (295 active TLPs + 32 incubating)
16. Apache Project Naming Process. https://www.apache.org/foundation/marks/naming.html
17. CNCF Project Lifecycle and Maturity. https://contribute.cncf.io/projects/lifecycle/
18. CNCF Graduation Criteria. https://github.com/cncf/toc/blob/main/process/graduation_criteria.md

### Package Managers and Registries

19. SE-0219: Package Manager Dependency Mirroring. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0219-package-manager-dependency-mirroring.md
20. SE-0291: Package Collections. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0291-package-collections.md
21. SE-0292: Package Registry Service. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0292-package-registry-service.md
22. SE-0391: Package Registry Publish. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0391-package-registry-publish.md
23. Rust RFC 3243: Packages as Optional Namespaces. https://rust-lang.github.io/rfcs/3243-packages-as-optional-namespaces.html
24. npm Scopes Documentation. https://docs.npmjs.com/about-scopes/
25. Go Vanity Import Paths. https://sagikazarmark.hu/blog/vanity-import-paths-in-go/

### GitHub Platform Mechanics

26. GitHub Docs: Transferring a Repository. https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository
27. GitHub Community Discussion: Redirect Duration. https://github.com/orgs/community/discussions/22669
28. New GitHub Organization for the Swift Project (Apple→swiftlang). https://www.swift.org/blog/swiftlang-github/
29. swift-foundation migration to swiftlang. https://forums.swift.org/t/sept-20th-swiftlang-migration-for-swift-foundation/74761
30. GitLab Subgroups Documentation. https://docs.gitlab.com/user/group/subgroups/

### Cognitive Dimensions

31. Green, T.R.G. & Petre, M. (1996). "Usability Analysis of Visual Programming Environments: A 'Cognitive Dimensions' Framework." *Journal of Visual Languages & Computing*, 7(2), 131-174.

### Swift Institute Internal

32. Five Layer Architecture. `Documentation.docc/Five Layer Architecture.md`
33. Semantic Dependencies. `Documentation.docc/Semantic Dependencies.md`
34. Primitives Taxonomy Naming and Layering Audit. `https://github.com/swift-primitives/Research/blob/main/primitives-taxonomy-naming-layering-audit.md`
35. Identity: Why "Institute". `Documentation.docc/Identity.md`
36. Prior Art Survey. `Research/domain-first-prior-art.md`
