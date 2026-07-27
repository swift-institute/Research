# Skill Corpus Holistic Review

<!--
---
version: 2.0.0
last_updated: 2026-07-15
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Executive verdict

The current corpus is valuable but not yet a reliable system of authority. It contains 65 skills, not the 70 suggested by the intake hint: 52 under Swift Institute, 4 under Rule Institute, and 9 under Engagement. The complete corpus is 124 Markdown files, 49,121 lines, 3,120,050 bytes, and 1,596 canonical requirement definitions.

Only 3 skills meet the Strong rubric without material qualification. 28 are Medium and 34 are Weak. The weakness is not that the corpus lacks thought. It is that substantial thought has accumulated faster than ownership normalization, discovery repair, validator activation, and removal of obsolete topology/runtime assumptions.

The recommended end state keeps every current skill name, adds one new meta skill (engagement-core), performs four internal file splits, replaces two unsafe operational implementations in place, and tightens the other 56 skills. No current merge, absorption, rename, root move, deprecation, or removal passes the formal lifecycle tests. End-state count: 66 skills.

The most important correction to the initial enforcement premise is categorical: mechanically decidable does not automatically mean swift-linter. Swift syntax predicates belong in swift-linter; compiler/SwiftPM-native facts should remain native; Markdown, JSON, YAML, filesystem, GitHub, release, and control-state predicates belong in purpose-built validators. Every candidate below is adjudicated individually.

## Authority, safety, and method

This is a read-only architecture review of live skills, control state, discovery projections, gates, and Git history. The only writes are this recommendation, its index entry, the formal findings appended to Audits/audit.md, and that audit index entry. No skill, control file, script, CI file, symlink, baseline, allowlist, commit, or remote state was changed.

The review read every Markdown file in every skill directory. It also read the required control files, all applicable AGENTS.md and CLAUDE.md files, the gate scripts before executing read-only modes, the predecessor research, the current audit, the system skill-creator guidance, and current first-party Codex skill-discovery documentation. Independent agents covered architecture/implementation, quality/tooling, process/control, legal/Engagement, structural lifecycle tests, and enforcement; the coordinator rechecked every finding retained here.

Rating is deliberately strict:

- Strong means exclusive ownership, precise trigger, current references, sound composition, bounded context, appropriate enforcement, and demonstrated use.
- Medium means useful and substantially correct, with a concrete bounded path to Strong.
- Weak means conflicting authority, incorrect or obsolete facts, broken discovery, unsafe operational guidance, unbounded context, or missing effective enforcement.

## Coverage receipt

| Root | Skills | Markdown files | Lines | Bytes | Canonical rules |
|---|---:|---:|---:|---:|---:|
| Swift Institute Skills | 52 | 110 | 45,616 | 2,975,987 | 1,525 |
| Rule Institute Skills | 4 | 4 | 2,067 | 75,757 | 71 |
| Engagement Skills | 9 | 10 | 1,438 | 68,306 | 0 |
| Total | 65 | 124 | 49,121 | 3,120,050 | 1,596 |

The 1,596 definitions reconcile as 1,560 unique heading IDs plus 36 legitimate registry/body definitions. There are 1,566 heading sites because six SEM-DEP definitions are intentionally mirrored in Workspace/CLAUDE.md; site count is therefore not definition count.

No skills were excluded. Scripts and non-Markdown assets were inspected where they implemented or contradicted a skill, but they are not counted as skill files.

## Corpus scorecard

| Dimension | Rating | Verified reason | Path to Strong |
|---|---|---|---|
| Canonical ownership | Medium | 1,596 definitions reconcile; PATTERN is the only multi-owner prefix, but several one-way or contradictory seams remain. | Repair the 22 RESHAPE_FIRST rules and add bilateral owner seams. |
| Dependency DAG | Medium | 65 nodes, 92 declared edges, no cycle and no missing declared skill; Engagement declares no edges. | Add engagement-core and explicit component dependencies; correct stale loading-order prose. |
| Trigger quality | Weak | Broad ALWAYS triggers collide; Engagement has nine independent triggers without shared schema authority; several process triggers are vendor-specific. | Narrow predicates and make composition explicit through requires and routing tables. |
| Requirement quality | Weak | 12 unresolved burned/demoted/ghost tokens, contradictory status models, stale topology and runtime assumptions. | Resolve contradictions before mechanization; keep burned IDs explicit. |
| Enforcement | Medium | 173 declarations exist, but 349 selected candidates still need adjudicated action; one declared AST rule is unbundled and 19 validators are authored/deferred. | Execute the sequential queue in this report one rule at a time. |
| Context efficiency | Weak | 12,824 description characters; names plus descriptions are 13,829 characters, 72.9% above Codex's 8,000-character initial listing budget before formatting. Eight legacy files exceed 1,000 lines under prune-only baselines. | Tighten descriptions, evict rationale, and perform only the four qualifying splits. |
| Discovery | Weak | Source and workspace Claude projection align, but user Claude projection has six broken links and Codex has no project/user projection in its current discovery locations. | Repair primitives, remove five retired links, generate Claude and Codex projections from one registry. |
| Lifecycle/gates | Weak | Size and description gates pass; canon enforce reports baselined debt, but documentation says report-only, the baseline contains orphans, and Engagement has no CI. | Make mode truthful, prune baselines, and add concern-root gate coverage. |
| Multi-agent architecture | Weak | The conceptual hub topology is sound; the live general seat is unhealthy, closed charter placement is wrong, status omits required edit zones, and role boundaries are prose-only. | Transactional state changes, capability checks, pinned charters, dormant general identity, and terminology cleanup. |
| Fresh-agent comprehensibility | Weak | A new agent sees stale layer/loading prose, broken personal routes, 65 broad descriptions, and three different L1/L2/L3 meanings. | Generate registry views and use unambiguous workspace/general/arc vocabulary. |

## Inventory A — identity, trigger, ownership, shape

Abbreviations: SI = Swift Institute, RI = Rule Institute, E = Engagement; SF = single file, H = routed multi-file hub. Review shows last_reviewed; dash means absent. Rule counts are canonical, not a naive heading grep.

| Skill | Root | Layer | Actual purpose and trigger | Prefixes | Shape; lines/bytes; rules | Review |
|---|---|---|---|---|---|---|
| audit | SI | process | Compliance audits and standardized findings | AUDIT | SF; 1114/86509; 40 | 2026-07-12 |
| benchmark | SI | implementation | Performance-test construction and review | BENCH | SF; 426/23416; 12 | 2026-07-05 |
| blog-process | SI | process | Blog ideation, drafting, evidence, publishing | BLOG | SF; 838/53643; 27 | 2026-05-10 |
| byte-discipline | SI | implementation | UInt8/Byte boundary decisions | API-BYTE | SF; 340/33140; 8 | 2026-07-05 |
| ci-cd-workflows | SI | process | Reusable CI architecture and rollout | CI | H(8); 1249/131039; 61 | 2026-07-14 |
| code-navigation | SI | process | Cross-package cclsp navigation/index maintenance | NAV | SF; 165/8831; 8 | 2026-07-14 |
| code-surface | SI | implementation | API names, errors, declarations, file shape | API-NAME, API-ERR, API-IMPL, API-BRAND | SF; 1421/99153; 50 | 2026-07-07 |
| collaborative-discussion | SI | process | Cross-agent design discussion | COLLAB | SF; 534/16868; 13 | 2026-07-05 |
| conversions | SI | implementation | Typed indices and conversion boundaries | IDX, CONV | SF; 976/41886; 34 | 2026-07-06 |
| corpus-meta-analysis | SI | process | Research/experiment corpus health | META | SF; 876/43764; 28 | 2026-07-05 |
| document-markup | SI | implementation | HTML/PDF/Markdown document creation | DOC-MARKUP | SF; 722/20314; 17 | 2026-07-15 |
| documentation | SI | implementation | DocC comments and catalogues | DOC | H(8); 2148/104352; 63 | 2026-07-06 |
| ecosystem-data-structures | SI | implementation | Data-structure catalog and selection | DS | SF; 740/58101; 21 | 2026-07-06 |
| existing-infrastructure | SI | implementation | Reuse catalog before new mechanisms | INFRA | SF; 1225/55593; 26 | 2026-06-02 |
| experiment-process | SI | process | Experiment hypothesis, execution, lifecycle | EXP | SF; 895/58129; 42 | 2026-07-05 |
| github-repository | SI | implementation | GitHub metadata, settings, automation | GH-REPO | SF; 1003/56904; 44 | 2026-07-05 |
| handoff | SI | process | Same-seat continuation across generations | HANDOFF | H(7); 1514/118973; 56 | 2026-07-15 |
| implementation | SI | implementation | General Swift implementation discipline | IMPL, IMPL-EXPR, COPY-FIX, COPY-REM, PATTERN, API-LAYER, SEM-DEP | H(8); 2269/155904; 124 | 2026-07-06 |
| issue-investigation | SI | process | Compiler/toolchain issue reduction | ISSUE | SF; 876/59378; 32 | 2026-07-06 |
| lint-rule-promotion | SI | process | One-rule mechanical promotion lifecycle | PROMOTE | SF; 659/58851; 11 | 2026-07-07 |
| memory-safety | SI | implementation | Ownership, lifetime, safety, concurrency | MEM-COPY/OWN/LINEAR/SAFE/SEND/REF/LIFE/SPAN/UNSAFE | H(9); 2494/159218; 91 | 2026-07-05 |
| modularization | SI | implementation | Target decomposition and import placement | MOD, MOD-EXCEPT | H(7); 1730/154419; 49 | 2026-07-13 |
| package-export | SI | process | Export a package for LLM review | PKG-EXPORT | SF; 340/9487; 11 | 2026-03-20 |
| platform | SI | architecture | Platform placement, shims, compilation | PLAT-ARCH, PATTERN | H(6); 2053/136288; 59 | 2026-07-05 |
| primitives | SI | architecture | Primitives tier/layer constraints | PRIM-ARCH, PRIM-FOUND, PRIM-NAME | SF; 292/14098; 8 | 2026-07-14 |
| quick-commit-and-push-all | SI | process | Fleet save/push operation | SAVE | SF; 217/10476; 5 | 2026-07-05 |
| readme | SI | implementation | README family routing and contracts | README | H(7); 3251/185825; 87 | 2026-07-06 |
| reflect-session | SI | process | Session reflection and artifact triage | REFL | SF; 604/56373; 18 | 2026-07-05 |
| reflections-processing | SI | process | Turn reflections into maintained artifacts | REFL-PROC | SF; 629/36760; 19 | 2026-07-05 |
| release-readiness | SI | process | Pre-release scan and authorization gates | RELEASE | SF; 787/85437; 21 | 2026-07-02 |
| research-process | SI | process | Research documents, rigor, discovery | RES | SF; 1075/83507; 52 | 2026-07-05 |
| rule-exemptions | SI | process | Linter exemption shapes | RULE-EXEMPT | SF; 577/24604; 7 | 2026-05-12 |
| seat-channel | SI | process | Workspace-seat JSONL transport | CHANNEL | SF; 171/8375; 13 | 2026-07-15 |
| seat-runtime | SI | process | General/arc executor runtime contract | SEAT | SF; 149/7578; 13 | 2026-07-15 |
| skill-lifecycle | SI | process | Skill creation/update/review/deprecation | SKILL-CREATE, SKILL-LIFE | SF; 1021/69670; 39 | 2026-07-06 |
| social-preview | SI | implementation | GitHub preview-card pipeline | SOC | SF; 629/27736; 11 | 2026-05-10 |
| supervise | SI | process | Tactical oversight of bounded execution | SUPER | H(7); 1974/156997; 77 | 2026-07-15 |
| swift-evolution | SI | process | Swift Evolution pitch phase | PITCH-PROC | SF; 427/13587; 7 | 2026-05-10 |
| swift-forums-review | SI | process | Simulated Forums review/pressure test | FREVIEW | SF; 540/34262; 21 | 2026-07-05 |
| swift-institute-core | SI | meta | Manifest, registry, loading authority | registry | SF; 261/19899; 4 | 2026-07-15 |
| swift-institute-ecosystem | SI | architecture | Orientation and layer tour | ECO | SF; 225/18229; 9 | 2026-07-14 |
| swift-institute | SI | architecture | Five-layer architecture/core conventions | ARCH-LAYER, SEM-DEP | SF; 303/31445; 14 | 2026-07-14 |
| swift-linter | SI | implementation | Consumer-side linter setup/bundles | LINT-* | SF; 525/38089; 19 | 2026-07-07 |
| swift-package-build | SI | process | Toolchain/build troubleshooting | PKG-BUILD | SF; 612/58144; 22 | 2026-07-14 |
| swift-package-heritage | SI | architecture | External-upstream lineage decisions | HERITAGE | SF; 430/21891; 7 | 2026-04-30 |
| swift-package-index | SI | process | SPI onboarding and collections | SPI | SF; 314/13533; 16 | 2026-07-03 |
| swift-package | SI | architecture | Package/name/dependency conventions | PKG-NAME, PKG-DEP | SF; 1036/73731; 29 | 2026-07-12 |
| swift-pull-request | SI | process | Upstream Swift PR workflow | SWIFT-PR | SF; 466/19653; 12 | 2026-07-05 |
| testing-institute | SI | process | Nested test package/snapshot isolation | INST-TEST | SF; 369/17558; 10 | 2026-07-11 |
| testing-swiftlang | SI | implementation | Apple Swift Testing patterns | SWIFT-TEST | SF; 710/29535; 16 | 2026-07-12 |
| testing | SI | implementation | Test routing/support/file conventions | TEST | SF; 1169/60024; 27 | 2026-07-12 |
| workspace-orchestration | SI | process | Workspace work ledger and seat authority | WORK | SF; 246/14811; 15 | 2026-07-15 |
| dutch-law | RI | process | Dutch statute/case lookup | NL-WET | SF; 521/19895; 17 | 2026-07-05 |
| legal-encoding | RI | implementation | Executable legal types | LEG/JUD/COMP/PROD-ENC | SF; 993/37725; 36 | 2026-07-11 |
| legal-testing | RI | implementation | Legal truth-table/witness tests | LEG-TEST | SF; 352/9928; 11 | 2026-07-05 |
| rule-law-core | RI | meta | Legal corpus manifest and routing | RL-CORE | SF; 201/8209; 7 | 2026-07-05 |
| engagement-actionables | E | process | User-facing actionable queue view | none | SF; 85/2615; 0 | — |
| engagement-compose | E | process | Compose quick-reply drafts | none | SF; 144/7475; 0 | — |
| engagement-process | E | process | Orchestrate engagement pipeline | none | SF; 213/9541; 0 | — |
| engagement-review | E | process | Read-only queue review | none | SF; 75/2872; 0 | — |
| engagement-themes | E | process | Theme/coverage view | none | SF; 254/12689; 0 | — |
| engagement-triage | E | process | Route ingested posts | none | SF; 167/10608; 0 | — |
| ingest-swift-forums | E | process | Ingest Swift Forums topics | none | SF; 132/4640; 0 | — |
| ingest-x-feeds | E | process | Poll X feed aggregators | none | SF; 135/5841; 0 | — |
| ingest-x | E | process | Fetch X posts into queue | none | H(2); 233/12025; 0 | 2026-07-05 |

All existing skills remain in their declared source root and layer in the recommendation. Structural weakness is corrected inside those boundaries; no evidence justified a layer or root move.

## Inventory B — graph, enforcement, usage, overlap, assessment

Enforcement codes: AST = swift-linter/SwiftLint declaration; V = purpose-built validator or CI; N = compiler/SwiftPM/test-native; M = manual/process judgment; P = prose only. Usage is a 90-day Git commit/file-reference proxy, not invocation telemetry. The Claude doctor report supplies separate invocation counts where stated below.

| Skill | Declared requires; direct dependents | Current enforcement | Usage proxy (commits/refs) and main overlap | Rating | Primary disposition |
|---|---|---|---|---|---|
| audit | swift-institute; 1 | V+M | 24/854; taxonomy/status authority conflicts internally | Weak | SPLIT |
| benchmark | testing; 0 | AST(partial)+N | 10/163; performance ownership overlaps testing-institute | Weak | TIGHTEN |
| blog-process | swift-institute; 0 | V(partial)+M | 8/35; publication/release doctrine leaks in | Medium | TIGHTEN |
| byte-discipline | swift-institute, code-surface; 0 | AST(partial)+M | 11/53; overlaps code-surface and conversions | Weak | TIGHTEN |
| ci-cd-workflows | swift-institute-core; 1 | V+CI | 41/98; thin-caller authority overlaps GitHub skill | Medium | TIGHTEN |
| code-navigation | swift-institute-core; 0 | N+M | 2/6; exclusive cclsp boundary | Strong | KEEP |
| code-surface | swift-institute; 12 | AST+V | 57/188; byte and declaration seams incomplete | Medium | SPLIT |
| collaborative-discussion | core, package-export; 0 | M | 4/38; Claude/ChatGPT-specific roles | Weak | TIGHTEN |
| conversions | institute, code-surface; 2 | AST(partial)+N | 7/173; arithmetic/byte ownership overlaps | Weak | TIGHTEN |
| corpus-meta-analysis | research, experiment, reflect; 0 | V(partial)+M | 6/79; research/experiment lifecycle conflicts | Weak | TIGHTEN |
| document-markup | institute, code-surface; 0 | N+M | 2/19; clean exclusive artifact boundary | Strong | KEEP |
| documentation | institute, code-surface; 0 | V+AST(partial) | 14/419; README and style ownership seams | Medium | TIGHTEN |
| ecosystem-data-structures | institute; 0 | AST(partial)+M | 16/59; catalog vs implementation/memory prescriptions | Weak | TIGHTEN |
| existing-infrastructure | institute, implementation, conversions; 0 | AST(partial)+M | 7/57; depends on its own dependent implementation | Weak | TIGHTEN |
| experiment-process | institute; 2 | V(partial)+N | 13/55; lifecycle conflicts META | Medium | TIGHTEN |
| github-repository | institute, readme; 2 | V+API | 26/40; CI/README/social ownership seams | Weak | SPLIT |
| handoff | core; 0 | V(partial)+M | 38/671; old file/state authority overlaps WORK | Medium | TIGHTEN |
| implementation | institute, code-surface, conversions; 4 | AST+N+M | 23/1041; catch-all pattern and memory seams | Weak | TIGHTEN |
| issue-investigation | core, experiment; 0 | N+M | 12/83; experiment output seam | Medium | TIGHTEN |
| lint-rule-promotion | core, audit; 0 | V+M | 7/82; author-side boundary is sound, lifecycle gaps remain | Medium | TIGHTEN |
| memory-safety | institute, code-surface, implementation; 1 | AST+N+M | 29/158; duplicated implementation prescriptions | Weak | TIGHTEN |
| modularization | institute, code-surface, implementation; 0 | AST+V+M | 37/198; package/layer placement seams | Medium | TIGHTEN |
| package-export | core; 1 | P/script | 0/19; documented output differs from script | Weak | REPLACE |
| platform | institute; 1 | AST+V+N | 41/915; PATTERN shared owner and stale platform claims | Weak | TIGHTEN |
| primitives | institute, code-surface, memory; 0 | V+N+M | 10/2013; catalog snapshot contradicts computed source | Weak | TIGHTEN |
| quick-commit-and-push-all | core; 0 | script | 4/25; obsolete clone-mirror topology and unsafe push | Weak | REPLACE |
| readme | institute; 1 | V+M | 16/106; docs/CI family authority drift | Medium | TIGHTEN |
| reflect-session | institute; 2 | V(partial)+M | 18/104; stale handoff/memory authority | Weak | TIGHTEN |
| reflections-processing | institute, reflect, lifecycle, research; 0 | V(partial)+M | 6/86; evidence/recency and artifact ownership drift | Weak | TIGHTEN |
| release-readiness | institute; 0 | V(partial)+M | 15/75; audit/GitHub/CI authority overlaps | Weak | TIGHTEN |
| research-process | institute; 2 | V(partial)+M | 21/144; multiple incompatible status/method models | Weak | SPLIT |
| rule-exemptions | core, code-surface; 0 | AST-seam+M | 3/25; helper names and lifecycle routing stale | Weak | TIGHTEN |
| seat-channel | workspace; 2 | control script | 0/15; transport boundary good, capabilities absent | Medium | TIGHTEN |
| seat-runtime | seat-channel; 0 | control script+M | 0/8; lifecycle overlaps WORK/HANDOFF | Medium | TIGHTEN |
| skill-lifecycle | core; 1 | V+CI | 13/138; discovery and gate-mode prose stale | Weak | TIGHTEN |
| social-preview | github, institute; 0 | V+script | 7/18; metadata seam needs validation | Medium | TIGHTEN |
| supervise | seat-channel; 0 | M+control | 35/201; subagent/seat authority overlaps WORK | Weak | TIGHTEN |
| swift-evolution | core; 0 | M | 2/95; current upstream-process facts need maintenance | Medium | TIGHTEN |
| swift-forums-review | core, institute; 0 | M+corpus | 9/32; deferred calibration stated normatively | Medium | TIGHTEN |
| swift-institute-core | none; 19 | V(partial) | 18/55; registry/loading prose stale | Weak | TIGHTEN |
| swift-institute-ecosystem | core; 0 | M | 2/10; orientation claims enforcement and stale tiers | Weak | TIGHTEN |
| swift-institute | core; 28 | V+M | 10/934; contradictory lateral rule and duplicated SEM-DEP | Weak | TIGHTEN |
| swift-linter | institute, package, code-surface; 0 | AST/V setup | 5/350; setup boundary sound, inventory drift | Medium | TIGHTEN |
| swift-package-build | core; 0 | N+V | 15/48; build cleanup and toolchain claims need guards | Medium | TIGHTEN |
| swift-package-heritage | institute, package; 0 | Git+M | 2/21; exclusive, bounded lineage authority | Strong | KEEP |
| swift-package-index | institute, github, CI; 0 | V+API | 2/6; ghost workflow and mutable external state | Weak | TIGHTEN |
| swift-package | institute; 2 | V+SwiftPM | 31/256; path/URL rules contradict | Weak | TIGHTEN |
| swift-pull-request | core; 0 | N+CI+M | 2/17; issue/CODEOWNERS/upstream drift | Medium | TIGHTEN |
| testing-institute | core, testing, platform; 0 | N+V | 3/38; performance and nested-package overlap | Weak | TIGHTEN |
| testing-swiftlang | testing; 0 | N+AST(partial) | 7/37; framework-specific, some stale patterns | Medium | TIGHTEN |
| testing | institute, code-surface; 4 | V+AST(partial)+N | 15/484; index incomplete and performance seam | Medium | TIGHTEN |
| workspace-orchestration | core; 1 | control script | 0/11; correct authority concept, incomplete implementation | Medium | TIGHTEN |
| dutch-law | core; 0 | API+M | 2/10; required research receipt absent | Medium | TIGHTEN |
| legal-encoding | rule-law-core, code-surface, implementation; 1 | AST(candidate)+M | 5/10; ternary semantics conflict | Weak | TIGHTEN |
| legal-testing | rule-law-core, legal-encoding, testing; 0 | N+V(candidate) | 2/10; complements encoding but shares conflict | Medium | TIGHTEN |
| rule-law-core | none; 2 | V(partial) | 2/7; registry misclassifies/omits dutch-law | Weak | TIGHTEN |
| engagement-actionables | none; 0 | script+M | 2/3; shared schema owner missing | Medium | TIGHTEN |
| engagement-compose | none; 0 | script+M | 2/3; shared state/voice mixed | Medium | TIGHTEN |
| engagement-process | none; 0 | script+M | 5/4; orchestrator owns too much shared state | Weak | TIGHTEN |
| engagement-review | none; 0 | script/read-only | 2/2; independent useful view, no core dependency | Medium | TIGHTEN |
| engagement-themes | none; 0 | script+M | 2/4; generated view/schema incompleteness | Medium | TIGHTEN |
| engagement-triage | none; 0 | script+LLM | 3/3; required state updates not enforced | Weak | TIGHTEN |
| ingest-swift-forums | none; 0 | API+script | 3/3; useful independent source, schema owner missing | Medium | TIGHTEN |
| ingest-x-feeds | none; 0 | network+script | 2/2; dedup/source semantics weak | Weak | TIGHTEN |
| ingest-x | none; 0 | API+script | 4/4; unsupported reliability claim and invalid sibling shape | Weak | TIGHTEN |

Rating totals: Strong 3; Medium 28; Weak 34. Disposition totals for existing skills: KEEP 3; TIGHTEN 56; SPLIT 4; REPLACE 2. Proposed creations: 1.

## Ownership, dependency, and composition maps

The prefix map is the Prefixes column in Inventory A. PATTERN is the sole multi-owner family: platform owns 001–009 and implementation owns the remaining sparse range. This partition is understandable but lacks a bilateral owner seam and contains contradictory members. SEM-DEP is duplicated verbatim between swift-institute/SKILL.md:287-291 and implementation/patterns.md:60-62 with only one-way canonical prose. Every other live prefix has a single skill owner.

The declared graph has 65 nodes, 92 edges, no cycle, and no missing target. The high-fan-out edges are:

- swift-institute-core → 19 direct dependents.
- swift-institute → 28.
- code-surface → 12.
- implementation → 4.
- testing → 4.
- conversions, experiment-process, github-repository, reflect-session, research-process, rule-law-core, and seat-channel → 2 each.

The nine Engagement skills are isolated nodes. The recommended graph adds engagement-core → all nine stages and swift-institute-core → engagement-core. No existing edge is removed until the contradictory ownership repairs are complete.

Recurrent composition clusters:

| Cluster | Current composition | Problem | Recommendation |
|---|---|---|---|
| Architecture/code | core → institute → code-surface/implementation/platform/memory | broad ALWAYS triggers and stale loading prose | retain DAG; narrow trigger predicates and repair one-way seams |
| Testing | testing → benchmark/testing-swiftlang/testing-institute/legal-testing | performance ownership and incomplete index | testing routes; leaf skills own framework/performance mechanics |
| Repository/release | readme → GitHub → social/SPI/CI/release | duplicated workflow, metadata, and release authority | GitHub owns remote metadata; CI owns workflow architecture; release only adjudicates readiness |
| Research lifecycle | research/experiment/reflect → meta/reflection-processing | conflicting status, archive, and memory models | one lifecycle enum per artifact class and validators at each corpus boundary |
| Workspace | workspace → channel → runtime; channel → supervise; handoff adjacent | authority/transport/runtime distinction is conceptually correct but operationally non-transactional | keep separate; add referential integrity and capability boundaries |
| Legal | rule-law-core → encoding → testing | unknown/exception semantics conflict | repair semantic canon before linter promotion |
| Engagement | nine unconnected stages | no shared queue/schema owner | add engagement-core and explicit requires |

Trigger overlaps are acceptable only when routing resolves them. The most material unresolved overlaps are: code-surface versus implementation for declarations; byte-discipline versus conversions for UInt8/rawValue; testing versus benchmark/testing-institute for performance; documentation versus README for explanatory content; GitHub versus CI for thin callers; audit versus release for disposition/GO; workspace versus supervise/handoff for first-class-seat completion; and legal-encoding versus legal-testing for ternary truth.

Trigger gaps are: shared Engagement state; Codex skill discovery; dormant/idle general-seat semantics; and a generated source-to-projection integrity check. A separate release-notes skill is not justified: release-readiness, README, GitHub, and blog-process already own the relevant distinct surfaces.

## Cross-reference and canon report

The canon scan covered 127 files because it also checks corpus-level README/LICENSE and Workspace/CLAUDE.md mirrors. It found 13 raw unresolved tokens. EXP-004b occurs only in changelog prose, leaving 12 live burned, retired, demoted, or ghost references:

AUDIT-035, COLLAB-012, FAM-008, IMPL-030, IMPL-031, IMPL-032, IMPL-041, MEM-ARITH-001, MEM-COPY-007, PROMOTE-005a, PRP-002, TEST-004.

Some are deliberately burned or subsumed; the defect is that references/templates/changelogs do not consistently mark that status. They must not be silently reused. The canon baseline currently reports 31 baselined findings (2 citations, 17 artifacts, 12 review findings) and contains two orphan entries for document-markup and testing-institute that are no longer emitted. Baseline count therefore overstates current active debt.

## Discovery and routing

| Projection | Current result | Verdict |
|---|---|---|
| Source roots | 65 skills | canonical |
| [local-workspace]/.claude/skills | 65 links, 0 broken | source-complete Claude workspace view |
| ~/.claude/skills | 11 links, 6 broken | incorrect user projection |
| [local-workspace]/swift-primitives/.claude/skills | primitives link broken | incorrect repo projection |
| [local-workspace]/swift-standards/.claude/skills | 65 links, healthy | complete but broad |
| swift-institute.org repo-local projection | 19 links, all broken | incorrect checked-in projection |
| project/user .agents/skills | absent | no current Codex project/user projection |

The Claude doctor report corroborates the user projection with real use: research-process 574, swift-institute-core 531, swift-institute 353, experiment-process 287, and blog-process 33 lifetime invocations remain healthy. The broken primitives route has 313 lifetime uses. Five retired broken names still have historical uses: naming 82, code-organization 18, anti-patterns 13, errors 13, memory 6.

The immediate repair is to repoint both broken primitives links to the central source and remove only the five dead projection links. This does not remove live skills. The user has separately reserved the doctor's no-op permission-rule cleanup; it is not part of this review.

The deeper defect is contradictory ownership: SKILL-CREATE-014 says the home projection is generated, while sync-skills.sh manages workspace/repository projections only. The Principal must choose whether home scope is managed or intentionally purged. Do not silently expose all 65 skills globally. Current first-party Codex documentation describes project and user discovery under .agents/skills, with an 8,000-character initial listing budget; current local policy describes only Claude projections.

## Enforcement adjudication

### Current state

The current declaration inventory is 173 rules:

| Declared class | Count | Interpretation |
|---|---:|---|
| Mechanical annotations | 162 | 91 AST/SwiftLint and 71 validator declarations |
| Architectural | 9 | intentionally outside linter |
| Native | 1 | delegated to compiler/toolchain |
| Manual | 1 | judgment remains required |

There are 96 AST declarations but only 95 bundled. BENCH-003 is declared AST yet its only declaration is commented/unbundled, so it is WAIT. API-NAME-010b is bundled/live despite lacking its Verification annotation. These are inventory defects, not reasons to infer coverage from prose.

The selected candidate/stop queue contains 349 unique IDs. Expanded ranges were checked: categories sum to 349 with zero duplicates.

| Disposition | Count | Meaning |
|---|---:|---|
| PROMOTE_AST | 51 | Deterministic parsed-Swift predicate; implement in swift-linter |
| PROMOTE_VALIDATOR | 218 | Deterministic non-Swift or repository/external-state predicate; use the smallest purpose-built validator |
| NATIVE | 7 | Compiler, SwiftPM, test framework, platform, or TSan is authoritative |
| RESHAPE_FIRST | 22 | Rule conflicts or scope ambiguity; no checker may choose a side |
| WAIT | 51 | Missing ground truth, unstable policy, placeholder, or immature control schema |

The remaining 1,247 canonical definitions were not selected for transfer because they are already covered, architectural, judgment/manual/process, permissive, or reference material. They are not a hidden queue of mechanically transferable rules.

### PROMOTE_AST — 51

All retain their normative statement in the owning skill. Enforcement implementation and fixtures go to the existing Institute swift-linter packs unless explicitly noted.

| Owner area | IDs | Target/rationale |
|---|---|---|
| Code surface | API-IMPL-021 | parsed declaration/signature predicate |
| Implementation | IMPL-012, IMPL-022, IMPL-026, IMPL-062, IMPL-098, PATTERN-061, COPY-FIX-004, COPY-FIX-008 | deterministic syntax/structure |
| Memory | MEM-COPY-004 residual; MEM-SAFE-010, 021, 026–030; MEM-SPAN-001, 002; MEM-SEND-009–011 | Swift ownership/safety syntax; residual means do not duplicate already-covered portion |
| Data structures | DS-024, DS-025 residual, DS-027–030 | primitives Tower pack |
| Legal encoding/testing | LEG-ENC-002, 020, 031; JUD-ENC-002, 003; PROD-ENC-002; LEG-TEST-003, 010, 020, 021, 040 | new Rule Institute legal-linter package and legal bundle, not the Institute Swift bundle |
| Testing | TEST-038, 040; SWIFT-TEST-001, 003, 010, 011, 015 | parsed test-declaration/call structure |
| Package/build/modularization/platform | PKG-BUILD-007; MOD-040; PLAT-ARCH-028 | deterministic Swift/manifest syntax |
| Documentation | DOC-001, DOC-045 | parsed declaration/documentation attachment |

### PROMOTE_VALIDATOR — 218

These should not be forced into an AST rule merely because they are mechanical. Extend existing checkers by artifact and keep diagnostics bound to the owning requirement ID.

| Validator family | IDs |
|---|---|
| Activate authored/deferred P0 outcomes (19) | CI-004b, 030, 031, 054, 059, 112; GH-REPO-074; API-IMPL-006, 007; TEST-009; MOD-023, 031, 032, 038; PRIM-ARCH-002; PRIM-NAME-001; PKG-DEP-008; PKG-NAME-014, 017 |
| Ratified naming vocabulary | PKG-NAME-001, 002, 015 |
| Skill canon/lifecycle | SKILL-CREATE-003, 004, 005, 007, 008, 009, 010, 012, 014; SKILL-LIFE-004, 007, 020, 022, 028 |
| Audit artifacts | AUDIT-003, 004, 009, 010, 018, 021, 025, 027 |
| Blog artifacts | BLOG-002, 003, 004, 005, 009, 017, 021, 023 |
| Corpus meta-analysis | META-001, 008, 009, 011, 012, 020, 021, 022, 025, 026, 027 |
| Research | RES-002, 003, 003a, 003b, 003c, 008 |
| Experiments | EXP-002, 002b, 003, 003a, 003b, 003c, 003d, 003e, 006, 007, 008, 017 |
| Reflection | REFL-002, 003, 004, 005, 007, 009, 010, 013, 015; REFL-PROC-003a, 014, 015, 016 |
| Release | RELEASE-001b, 001c, 002, 009, 010, 015, 016, 017 |
| Handoff/supervision | HANDOFF-004, 006, 007, 011, 012, 014, 021, 031, 041, 051, 052; SUPER-002, 003, 004, 009, 009a, 011, 049, 052, 054, 069 |
| Documentation/README | DOC-019a, 028, 029, 030, 041, 042, 046, 053, 054, 073, 103; README-016, 017, 137 residual, 161–165, 168, 170 |
| GitHub/CI | GH-REPO-010, 020, 022, 023, 030, 031, 050–057, 060, 062, 063, 075, 077, 090–094; CI-106, 113, 114 |
| Modularization/platform | MOD-020, 026, 035; PLAT-ARCH-014, 020, 024, 031 |
| Package/SPI | PKG-DEP-010, 011; PKG-NAME-013; PKG-BUILD-012; SPI-003, 020–024 |
| Testing | TEST-010, 019, 020, 021, 024, 033; INST-TEST-001, 002, 004, 005, 011, 013 |
| Legal corpus | LEG-ENC-040–044, 046; LEG-TEST-001, 011, 041; RL-CORE-010, 011 |
| Promotion process | PROMOTE-007, 009, 010, 011 |
| Social preview | SOC-006, 007, 009 |

### NATIVE — 7

PKG-DEP-007; PRIM-FOUND-002; TEST-027, 036, 037; MEM-COPY-001a; MEM-SEND-007.

SwiftPM/compiler/platform/test/TSan diagnostics are the authoritative ground truth. Duplicating them would add drift and poorer diagnostics.

### RESHAPE_FIRST — 22

API-BYTE-004, API-BYTE-008; CONV-013 with IMPL-108; ARCH-LAYER-001 with ARCH-LAYER-012; LEG-ENC-003, 005, 007, 063 with LEG-TEST-002; PATTERN-052 with MOD-036; PKG-DEP-001 with PKG-DEP-009; PLAT-ARCH-001, 005, 008c, 008e, 017, 027, 030.

These pairs/clusters contradict one another or lack a stable scope boundary. Promotion before semantic repair would mechanically entrench an arbitrary side.

### WAIT — 51

BENCH-003; API-NAME-003; API-BRAND-001; API-IMPL-019; MOD-016, 037; INFRA-020; PLAT-ARCH-016; FREVIEW-017; CI-107; WORK-001–015; CHANNEL-001–013; SEAT-001–013.

Reasons are missing ground truth/list, semantic engine dependency, explicit placeholder, unstable network-current policy, or the new/uncommitted/unhealthy control-plane schema. The nine architectural rules retained outside linter are CI-003, 011, 012, 013, 020, 053, 081, 109, 110.

### Promotion order

PROMOTE-001 requires sequential, one-ID adjudication. The safe order is:

1. Repair every RESHAPE_FIRST cluster through skill-lifecycle.
2. Activate the 19 authored/deferred outcomes one at a time, beginning with CI-112's first live run.
3. Promote PKG-NAME-001, 002, and 015 sequentially now that naming-vocabulary is ratified.
4. Add the 14 skill-canon/lifecycle validators.
5. After the legal semantic repair, create the separate Rule Institute legal-linter package and bundle.
6. Promote high-risk memory/data-structure/Swift-source predicates.
7. Add package, documentation, testing, and GitHub validators.
8. Add artifact-process validators, then the social/SPI/promotion tail.

Every ID requires fixtures, warning-only soak, diagnostic binding to the owner ID, an outcome record, and review before the next ID. ARCH-LAYER-012 must not be activated until its conflict with ARCH-LAYER-001 is repaired.

## Per-cluster assessment

### Strongest areas

Code-navigation is a small, exclusive operational contract with a current tool boundary and no competing owner. Document-markup has a clear artifact trigger and current package-specific expertise. Swift-package-heritage has an unusually crisp decision boundary: it governs provenance/lineage, not API design or package naming. These three should stay structurally unchanged.

The strongest Medium clusters are CI, testing-swiftlang, issue investigation, promotion lifecycle, and the workspace/channel/runtime conceptual decomposition. Their boundaries are basically correct; they need enforcement completion or operational hardening, not taxonomy replacement.

### Architecture and implementation

This cluster is the largest source of semantic conflict. ARCH-LAYER-001 forbids lateral dependencies at swift-institute/SKILL.md:48-50 while ARCH-LAYER-012 permits lateral L3 dependencies at :220-229. The ecosystem tour says it carries no enforcement at swift-institute-ecosystem/SKILL.md:24-26 yet defines nine MUST-style ECO requirements, and its 13-tier claim at :80-88 conflicts with the computed 19-tier source at primitives/SKILL.md:100-108. Swift-package's path-safe-default at swift-package/SKILL.md:590-655 is contradicted by PKG-DEP-009's no-path rule at :818-828.

Platform, implementation, memory, conversions, byte discipline, and data structures all contain useful requirements, but catch-all growth and imperfect seams make them Weak. Splitting them further is not the remedy: only code-surface satisfies the current formal split gate. First repair ownership and move rationale out.

### Testing, documentation, repository, and tooling

Testing is useful but its Rule Index is incomplete and performance authority is divided among testing, testing-institute, and benchmark. Documentation has conflicting ownership between inline and style siblings; README retains retired family assumptions; GitHub and CI have a one-way thin-caller seam. Package-export's promised output is not what its embedded script produces. Quick-save's script assumes clone-mirror parents are repos and blindly pushes a hard-coded fleet.

The correct response is one qualified GitHub internal split, targeted tightening of testing/docs/CI, and in-place replacement of the two operational scripts. Do not create extra testing or release-notes skills.

### Research, audit, reflection, and release

Audit and research-process each qualify for a structural split, but their deeper defect is status and authority conflict. Audit has multiple placement rules, contradictory FALSE_POSITIVE/PREMISE_STALE handling, and a rule that requires implementing a fix during audit. Research has incompatible status enums and mandates particular methods/tools regardless of question or authority.

Experiment and META conflict on archive and FIXED/SUPERSEDED semantics. Reflection skills still route through retired HANDOFF/memory assumptions and can commit or delete user WIP. Release has incompatible phase models and contains unacceptable advice to delete CI history or rewrite Git history for presentation. RELEASE-013 should be removed as a rule during TIGHTEN; removing one rule is not removing the skill.

### Multi-agent control plane

The design boundary is good:

- Workspace owns authority, topology, work state, assignment, acceptance, and completion.
- Seat-channel owns transport.
- Seat-runtime owns executor conduct after authority is granted.
- Handoff owns same-seat continuation.
- Supervise owns tactical oversight, not first-class-seat authority.

Do not merge these skills. The live implementation is not production-ready:

- WORK-014 requires edit-zone/worktree visibility, but workspace-state.py:501-560 and Workspace/control/STATUS.md:8-20 omit it.
- Exactly-one general is normative at workspace-orchestration/SKILL.md:47-63, while the checker only rejects more than one at Scripts/workspace-state.py:619-631 and close permits zero at :993-1017.
- Reconcile executes tracked event-log shell predicates through /bin/zsh at workspace-state.py:403-455 and :1061-1126.
- Rotate and close span separate non-transactional channel/registry operations at seat-channel.py:291-322 and :481-510 versus workspace-state.py:968-1017.
- Charter immutability is prose-only; only path/existence is checked.
- Same-user callers can spoof workspace role, read peer channels, regress unlocked cursors, and close without a required close transaction.
- The general seat is currently UNHEALTHY with incomplete BOOT; sending-regions is CLOSED but its charter remains under charters/active.
- L1/L2/L3 actor terminology collides with the five-layer architecture and platform tiers.

Recommended model: a persistent general identity may be DORMANT with no active transport lease; assignment requires a healthy current-generation handshake. Use workspace/general/arc names, not numeric layer names. Use structured allowlisted oracle executables, content-hashed immutable charters, transactional rotate/close journals, monotonic locked cursors, capability-bound role operations, and work/channel referential integrity.

### Rule Institute

The legal root belongs where it is. The core registry currently misclassifies/omits Dutch-law routing, and legal-encoding conflicts with legal-testing over unknown/exception semantics. Repair the semantic canon before adding the proposed separate legal linter package. Dutch-law and legal-testing are Medium because their boundaries remain useful; legal-encoding and rule-law-core are Weak until authority is coherent.

### Engagement

All nine skills have useful independent triggers, so absorption fails. None has a requirement-ID family or requires edge. Shared queue schema, status transitions, IDs, deduplication, index integrity, and no-posting safety are repeated but ownerless. This is the only justified new skill gap.

Current implementation evidence also shows concrete defects: triage does not enforce all tags/status transitions, themes omits surfaces and includes draft text, review references a nonexistent draft.file, Forums ingestion stores reply count as likes, and X dedup uses URL rather than stable post ID. Fifty current queue records are dormant from 2026-04-22 (46 ignore, 3 blog, 1 research), so operational usefulness is not yet demonstrated.

## Structural recommendations

### SPLIT code-surface

Why: 50 rules, 1,421 lines, at least four independently loadable narrative clusters; all SKILL-CREATE-005a conditions pass.

| File | Rules |
|---|---|
| SKILL.md | thin hub, global axioms, Files table, full Rule Index |
| naming.md | API-NAME-001/001a/001b/001c/002/003/004/004a/005/006/007/008/010/010a/010b/011/012/013/014/015 plus API-BRAND-001 |
| errors.md | API-ERR-001–008 |
| declarations-and-conformances.md | API-IMPL-005/006/007/008/009/016/018/019/020/022/023/024 |
| signatures-and-state.md | API-NAME-009 plus API-IMPL-003/010/011/012/013/014/017/021 |

### SPLIT audit

Why: 40 rules, 1,114 lines, four independently useful audit concerns; the threshold is met exactly.

| File | Rules |
|---|---|
| SKILL.md | hub and complete Rule Index |
| artifacts.md | AUDIT-001/002/003/004/005/007/008/009/010/015/016/017 |
| modes-and-routing.md | AUDIT-006/011/012/013/014/019/032 |
| evidence.md | AUDIT-018/021/023/026/027/028/029/033/034/036/037/039/040/041 |
| findings-and-remediation.md | AUDIT-020/022/024/025/030/031/038 |

### SPLIT research-process

Why: 52 rules, 1,075 lines, four independently loadable research modes.

| File | Rules |
|---|---|
| SKILL.md | hub and complete Rule Index |
| investigation.md | RES-001/001a/004/004a/011/027/028/029/033/035 |
| documents.md | RES-002/002a/003/003a/003b/003c/004b/005/006/006a/007/008/009/010/010a/010b/010c/036/039 |
| rigor-and-verification.md | RES-020/021/022/023/024/025/026/031/032/034/037/038 |
| discovery.md | RES-012/013/013a/014/015/016/017/018/019/020a/030 |

### SPLIT github-repository

Why: 44 rules, 1,003 lines, five independently useful concerns.

| File | Rules |
|---|---|
| SKILL.md | hub and complete Rule Index |
| public-presentation.md | GH-REPO-001/003/010/011/012/013/014/020/021/022/023/024/030/031/040/041 |
| settings.md | GH-REPO-050–057 |
| metadata.md | GH-REPO-002/060/061/062/063/076 |
| automation.md | GH-REPO-070/071/072/073/074/075/077 |
| organization-and-discussions.md | GH-REPO-080/081/090/091/092/093/094 |

All four splits retain skill name, directory, IDs, and references. They are breaking only for raw path/line consumers. Land relocation without wording changes, update scanners to recurse, then remove the size-baseline entry only after each file is below 1,000 lines.

Rejected splits: swift-package (29 rules), existing-infrastructure (26), testing (27), skill-lifecycle (39), legal-encoding (36), and conversions (34). SKILL-CREATE-005a requires at least 40; line count alone is insufficient. Evict rationale first. Do not invent rules to cross the threshold.

Rejected absorptions: every Engagement stage has an independent trigger or direct invocation; seat-channel and seat-runtime are not proper subsets of workspace authority. No candidate meets 100% co-load, under-200-line proper-subset, and no-independent-consumer simultaneously.

## New skill: engagement-core

| Field | Recommendation |
|---|---|
| Name | engagement-core |
| Source | Engagement/Skills/engagement-core/SKILL.md |
| Layer | meta |
| Prefix | ENG-CORE |
| Trigger | Whenever any Engagement queue, schema, status, route, ID, dedup, or shared-state operation runs, including direct invocation of a stage |
| Requires | swift-institute-core |
| Owns | repo-root resolution; queue and index schema; status/route state machine; stable IDs; dedup/idempotency; index↔Queue integrity; universal test-only/no-posting invariant |
| Does not own | ingestion mechanics; classification; composition/voice; view rendering; review; end-to-end orchestration |
| Why existing skills cannot own it | engagement-process is deliberately pure orchestration, while stages are independently invoked; assigning shared canon to either would make direct runs unsafe or duplicate authority |
| Example invocations | validating a queue migration; changing allowed statuses; repairing index/Queue divergence; adding a new source stage |
| Effect | all nine existing stages add engagement-core to requires and stop redefining shared state |

## Replacement specifications

Package-export remains the same skill and prefix but its implementation is replaced with one tested maintained script. It must emit the documented tree and content, preserve namespace-root ordering, honor git check-ignore, exclude build/vendor material, and accept an explicit context budget. Remove the static vendor-table prose.

Quick-commit-and-push-all remains the same skill and prefix but becomes registry-driven and fail-closed. Discover leaf repositories rather than treating org mirrors as repos; classify visibility authoritatively; enforce branch and dirty-state guards; produce a dry-run receipt; separate public/private authorization; and verify every push. No operation proceeds merely because a repo appears in a hard-coded list.

## Complete proposed end-state catalog

KEEP:

code-navigation; document-markup; swift-package-heritage.

SPLIT internally:

audit; code-surface; github-repository; research-process.

REPLACE in place:

package-export; quick-commit-and-push-all.

TIGHTEN:

benchmark; blog-process; byte-discipline; ci-cd-workflows; collaborative-discussion; conversions; corpus-meta-analysis; documentation; ecosystem-data-structures; existing-infrastructure; experiment-process; handoff; implementation; issue-investigation; lint-rule-promotion; memory-safety; modularization; platform; primitives; readme; reflect-session; reflections-processing; release-readiness; rule-exemptions; seat-channel; seat-runtime; skill-lifecycle; social-preview; supervise; swift-evolution; swift-forums-review; swift-institute-core; swift-institute-ecosystem; swift-institute; swift-linter; swift-package-build; swift-package-index; swift-package; swift-pull-request; testing-institute; testing-swiftlang; testing; workspace-orchestration; dutch-law; legal-encoding; legal-testing; rule-law-core; engagement-actionables; engagement-compose; engagement-process; engagement-review; engagement-themes; engagement-triage; ingest-swift-forums; ingest-x-feeds; ingest-x.

CREATE:

engagement-core.

There are no MERGE/ABSORB, RENAME, MOVE ROOT, DEPRECATE, or REMOVE dispositions for live skills. Five retired broken symlinks are removed as projections, not skills. RELEASE-013 is removed as a defective rule during tightening, not as a skill disposition.

## Systemic root causes

1. Canon grew additively without a single generated registry. The corpus now has correct raw ownership for most prefixes but stale narrative indexes, loading prose, and discovery projections.
2. Mechanical annotations were treated as coverage claims. Authored, bundled, activated, and independently validated states are not consistently distinguished.
3. Process skills captured point-in-time runtime/tooling facts as permanent requirements. Claude memory, HANDOFF files, old org topology, toolchain versions, and external service behavior survived later architecture changes.
4. Control-plane authority converged faster than implementation. The conceptual boundaries are recent and sound, but scripts do not yet provide transactions, capabilities, referential integrity, or safe idle state.
5. Engagement evolved as executable stages before acquiring shared canon. This explains zero IDs, zero dependencies, schema repetition, and inconsistent state handling.
6. Baselines became both debt registers and apparent success metrics. Prune-only is sound, but orphan/stale entries and contradictory enforce/report-only documentation obscure actual gate state.

## Predecessor reconciliation

| Predecessor claim/finding | Current classification | Evidence |
|---|---|---|
| 37-skill corpus and four-layer count | Premise-stale | current census is 65 across three roots |
| Platform should split as a single file | Resolved structurally | platform is now a six-file routed hub; content weakness remains |
| Testing cluster needed cross-review | Confirmed/refined | cluster boundaries useful; ownership/index defects remain |
| Many April ghost references/duplicate IDs | Resolved for those exact findings | prior audit section records 31 resolved; current unresolved tokens are a different residue set |
| Missing release-notes skill | Rejected | responsibility is already partitioned across release, README, GitHub, blog |
| Quick-save hard-coded topology risk | Confirmed and worsened | current no-superrepo topology makes the embedded implementation unsafe |
| Collaboration/reflection stable | Premise-stale | Codex runtime and July workspace authority invalidate vendor/memory assumptions |
| Handoff heading/orphan findings | Resolved or previously withdrawn | do not reopen old resolved rows |
| Workspace cluster CLEAN after 13 remediations | Confirmed for those exact 13 findings | new runtime/state findings arose after closure and are separately recorded |
| Merge process skills for neatness | Rejected | independent triggers and durable outputs fail absorption criteria |

This document replaces the predecessor's current-state conclusions in place. Historical reasoning remains available through Git history and the predecessor audit sections.

## Migration plan

### Phase 1 — correctness and discovery

Scope: repair the two broken primitives projections; remove five dead user links; decide managed versus purged home scope; repair all checked-in broken projections; add a read-only source/projection integrity gate; correct canon mode documentation and prune two orphan baseline entries.

Preconditions: Principal chooses home-scope policy and authorizes symlink/script changes.

Validation: zero broken/missing/extra/wrong-target links for each declared projection; description and size checks; canon enforce; Claude discovery smoke test; Codex .agents discovery smoke test if adopted.

Rollback: projection changes are reversible links; retain a generated before/after manifest. Do not change skill sources.

This is the smallest safe first implementation batch.

### Phase 2 — semantic correctness and ownership

Scope: repair all 22 RESHAPE_FIRST clusters; reconcile audit/research/experiment/META status models; remove RELEASE-013; correct architecture tier/path/lateral contradictions; legal unknown/exception semantics; add bilateral seams for PATTERN and duplicated SEM-DEP.

Preconditions: one Principal ruling for each semantic conflict.

Validation: canon scan, cross-reference scan, dependency DAG, targeted examples/counterexamples, and independent cluster audit.

Rollback: one rule cluster per commit; preserve redirect/burn records for changed IDs.

### Phase 3 — triggers and dependency cleanup

Scope: narrow broad triggers; correct core loading order; add engagement-core and nine requires edges; correct legal/core routing; make collaborative-discussion runtime-neutral.

Preconditions: engagement-core schema approved; semantic repairs from Phase 2 that affect routing complete.

Validation: synthetic routing tasks, complete dependency graph, no cycle/missing owner, description budget under the current harness limit.

Rollback: additive engagement-core can be removed before consumer edits if routing tests fail.

### Phase 4 — qualified splits and replacements

Scope: four file-only splits exactly as specified; replace package-export and quick-save implementations.

Preconditions: semantic edits to each split skill land before mechanical relocation; replacement acceptance tests written first.

Validation: recursive canon scan, each Markdown file at or below 1,000 lines, unchanged ID set, path/citation migration, package-export golden fixtures, quick-save dry-run/fail-closed tests.

Rollback: splits are one mechanical relocation commit each; replacements retain old behavior only as versioned test fixtures, not executable fallback.

### Phase 5 — control-plane hardening

Scope: dormant general identity; nonnumeric actor vocabulary; transactional rotate/close; capability checks; structured oracles; locked cursors; charter hashes; work/channel referential integrity; durable tracked state.

Preconditions: Principal approves lifecycle model and security boundary; live work is quiesced or migrated through an explicit journal.

Validation: crash-injection tests at every transaction boundary; spoof/peer-read/close negative tests; concurrent cursor tests; charter tamper test; active/dormant/closed lifecycle matrix; independent closure audit.

Rollback: version event schema and provide a read-only migration verifier; never rewrite existing event logs in place.

### Phase 6 — enforcement

Scope: execute the adjudication queue in the exact order above. Swift-source predicates go to swift-linter; artifact/API/state predicates to purpose-built validators; native rules stay native.

Preconditions: Phase 2 resolves contradictions; diagnostics cite canonical owner IDs; baseline policy is prune-only and truthful.

Validation: fixtures, warning-only soak, false-positive review, first live run, outcome receipt, and one-ID independent review.

Rollback: disable one new diagnostic/bundle entry while retaining fixtures and outcome record; never weaken the canonical rule silently.

### Phase 7 — lifecycle expiry and independent validation

Scope: remove temporary redirects after their stated windows, expire suppressions, prune baselines, regenerate projections, and run a fresh whole-corpus audit.

Preconditions: all consumers migrated and discovery receipts clean.

Validation: full census; zero cycles; zero unexplained ghosts; zero broken projections; all gates blocking as documented; operational control-plane health; end-state catalog count 66.

## Risks and tradeoffs

- Tightening 56 skills is a large semantic program. Batch by composing cluster, not by arbitrary file count.
- Four splits reduce load cost but increase path-sensitive consumer risk; IDs must remain stable and scanners must recurse.
- A managed home projection improves Claude use outside Developer but can pollute unrelated sessions. Purging home scope is safer unless cross-workspace loading is explicitly required.
- More validators can create a fragmented enforcement UX. A common diagnostic schema and one aggregate gate are preferable to one monolithic checker.
- Control-plane capability enforcement is limited by same-user filesystem access. The goal is robust protocol/tool boundaries and tamper evidence, not an OS security boundary that does not exist.
- Legal linter separation preserves domain/privacy boundaries but adds another package/bundle to maintain.

## Principal decisions required

1. Choose managed or purged home-level Claude skill projection.
2. Approve project/user Codex projection under .agents/skills and the description-budget reduction needed to fit it.
3. Rule on each of the 22 RESHAPE_FIRST semantic clusters.
4. Approve engagement-core's meta layer, ENG-CORE prefix, schema ownership, and dependency edges.
5. Approve the four breaking file relocations.
6. Approve in-place replacement specifications for package-export and quick-save.
7. Approve dormant-general lifecycle and workspace/general/arc terminology.
8. Approve the control-plane trust model and transactional migration.
9. Approve a separate Rule Institute legal-linter package/bundle.
10. Authorize the sequential 349-ID enforcement program; no blanket transfer is recommended.

## Gate and verification receipt

| Check | Result |
|---|---|
| Description check | PASS: 65 skills; ceiling 250; one stale allowlist entry outside corpus |
| Size check | PASS against prune-only baseline; 8 legacy over-ceiling files remain baselined |
| Canon enforce | PASS with 31 baselined findings across 127 files and 1,596 IDs; baseline has 2 orphan entries |
| Dependency graph | 65 nodes, 92 edges, acyclic, no missing declared name |
| Prefix ownership | one multi-owner prefix, PATTERN; no accidental second owner |
| Source census | 65 skills, 124 Markdown files; no exclusions |
| Sync dry run | discovers 65; manages Developer/.claude and swift-standards projections only |
| Workspace state check | internal ledger/view consistency PASS |
| General channel health | FAIL: incomplete BOOT; stale workspace heartbeat; missing seat heartbeat |
| Sending-regions lifecycle | CLOSED state but charter still under active |
| Git/worktree | dirty user-owned state preserved; no commit/push |

Verification limits:

- Usage counts are file-reference proxies except the explicit Claude-doctor lifetime invocation counts.
- No mutating sync, warning rollout, CI dispatch, remote API mutation, or control-plane repair was authorized.
- External mutable facts were not promoted to timeless rules; current first-party Codex discovery documentation was used only for the current harness comparison.
- The current worktree is heavily modified across several repositories. Findings describe that live state and should be rechecked immediately before implementation.

## Key evidence

- Skill lifecycle structural gates: Skills/skill-lifecycle/SKILL.md:203-225, :583-593, :829-840.
- Discovery contradiction: Skills/skill-lifecycle/SKILL.md:562-575; Scripts/sync-skills.sh:15-23, :99-161, :263-276.
- Architecture conflict: Skills/swift-institute/SKILL.md:48-50, :220-229.
- Tier drift: Skills/swift-institute-ecosystem/SKILL.md:80-88; Skills/primitives/SKILL.md:100-108.
- Package dependency conflict: Skills/swift-package/SKILL.md:590-655, :818-828.
- Promotion architecture: Skills/lint-rule-promotion/SKILL.md:56-66, :89-150, :505-511.
- Control findings: Skills/workspace-orchestration/SKILL.md:47-63, :207-215; Scripts/workspace-state.py:403-455, :501-560, :619-631, :968-1017, :1061-1126; Scripts/seat-channel.py:291-408, :481-571.
- Formal compliance findings: Audits/audit.md, 2026-07-15 holistic cluster sections.
- Current Codex skill guidance: https://learn.chatgpt.com/docs/build-skills
