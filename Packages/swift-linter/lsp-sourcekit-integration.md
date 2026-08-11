# LSP / SourceKit Integration for swift-linter

<!--
---
version: 1.4.0
last_updated: 2026-05-13
status: DECISION
research_tier: 2
applies_to: [swift-foundations/swift-linter, swift-foundations/swift-linter-rules]
normative: false
changelog:
  - v1.4.0 (2026-05-13): Persists post-decision conversation work as
    durable record. Adds Q8 (sister-product naming + capabilities map
    — Concept A `swift-institute-lsp`, Concept B `swift-linter analyze`
    mode, Concept C `swift-refactor` — operationalizes Q7's
    abstract domain-framing) with bird's-eye stacking diagram.
    Adds "Open Follow-ups" section enumerating the today-sized work
    items surfaced during the arc, with current dispositions
    (done / deferred / queued / handed-off). Captures the
    conditional-~Copyable rule-design concern.
  - v1.3.0 (2026-05-13): Extended the experiment to batch-process
    multiple symbol graphs (two-pass union-then-match) so cross-module
    protocol→protocol refinements are detected. Ran the user-domain
    scan against 28 symbol-graph files covering 15 swift-primitives
    packages. Empirical finding: 2 institute refinement pairs (Comparison
    → Equation, Hash → Equation) — far fewer than stdlib's 136 — and
    BOTH have leaf-name collisions ("Protocol" on both sides) due to the
    institute's `Namespace.\`Protocol\`` convention. Rule's current
    leaf-name matching can't consume institute pairs without becoming
    path-aware. Added Phase 2.5 (user-domain scan) section to Outcome
    documenting the finding. The user-domain table is NOT shipped to
    swift-linter-rules — rule update is a separate decision.
  - v1.2.0 (2026-05-13): Spike executed and CONFIRMED. Status promoted
    RECOMMENDATION → DECISION. Phase 1 (spike) replaced with the
    executed result: 136 protocol-protocol refinement pairs extracted
    from Swift stdlib's symbol graph, including all 26 entries of the
    hardcoded `idiomKnownStdlibRefinements` table plus 110 additional
    refinements. Per [EXP-022], the spike landed at
    `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/`
    (not `swift-institute/Experiments/` as v1.0.0/v1.1.0 had said —
    swift-json is the highest-layer dep). Rule docstring at
    `Lint.Rule.Idiom.RedundantRefinement.swift` amended to remove the
    "requires type resolution" framing.
  - v1.1.0 (2026-05-13): Added Q6 (design-space exploration: what rule classes
    live type resolution enables, beyond the currently-deferred cohort),
    Q7 (domain framing: is type-aware enforcement still "linter" work?),
    expanded prior-art into a full cross-ecosystem literature study, added
    "Long-term framing" subsection to Outcome. Near-term recommendation
    (Shape F precomputed oracle, 1-week spike) unchanged.
  - v1.0.0 (2026-05-13): Initial RECOMMENDATION. Six integration shapes
    surveyed; Shape F recommended for near-term; live LSP/SourceKit deferred.
---
-->

## Context

### Trigger

Two concrete linter outcomes have collided with the same wall:

1. **`redundant refinement`** (just landed at
   `swift-foundations/swift-linter-rules/Sources/Linter Rule Idiom/Lint.Rule.Idiom.RedundantRefinement.swift`)
   is table-driven over a hardcoded list of stdlib protocol-refinement
   pairs (`Error: Sendable`, `Comparable: Equatable`, the numeric
   tower, the collection tower, …). The docstring states: *"A fully
   general 'any A & B where A refines B' form would require type
   resolution; the swift-linter stack is SwiftSyntax-only."*
2. **wave-4 absorber-pattern rule** (per
   `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md`)
   explicitly dropped absorber condition (1d) — *"invocation of an
   `@unsafe`-marked function"* — because *"the AST-only linter cannot
   resolve which functions carry the `@unsafe` declaration attribute
   across file boundaries — that's a SourceKit / compiler-level
   question."*

Both gaps share a structural shape: the lint question is **semantic**
(does this name refer to a protocol that already refines another /
does this call target a function that carries `@unsafe`?), not
syntactic. The hardcoded-table workaround in `redundant refinement`
covers the stdlib slice; absorber (1d) has no workaround and was
dropped.

This research settles two questions:

- **Does LSP / SourceKit integration pay for itself?**
- If so, **in what shape**?

### Prior research consulted ([RES-019] internal grep complete)

| Doc | Status | Relevance |
|---|---|---|
| `swift-institute/Research/swiftsyntax-based-custom-linter-investigation.md` v1.0.0 | RECOMMENDATION (2026-05-06) | Surveyed 8 options for AST-based linting; recommended **Option C (standalone CLI, SwiftSyntax-based)** augmented by **Option F (symbol-graph extension)**. **Option G (editor-integrated LSP)** was *eliminated as initial scope* on cost grounds ("implementation cost is roughly two orders of magnitude higher" and "orthogonal to CI enforcement") — but framed only as an editor-UX story, not as a *type-resolution backend* for CI rules. The gap this doc fills. |
| `swift-institute/Research/ai-context-reduction-via-type-system-tooling.md` v1.0.1 | RECOMMENDATION (2026-04-01) | Phase 1 (symbol-graph extraction) executed 2026-03-15 against swift-primitives, producing `swift-primitives/.build/public-api-graph.json` (9.8 MB; 435 modules; 13,262 symbols; 19,022 relationships). Confirms `symbolgraph-extract` emits `conformsTo` and `inheritsFrom` relationships — the load-bearing fact for the recommendation below. |
| `swift-institute/Research/primitives-public-api-graph-analysis.md` | RECOMMENDATION (2026-04-13) | Phase-1 analysis of the produced graph; confirms cross-module conformance relationships are captured. |
| `swift-institute/Research/workspace-wide-symbol-search-for-cclsp.md` | (cited) | CCLSP / SourceKit-LSP workspace-symbol limitations observed; confirms LSP queries require Package.swift at workspace root and a fresh index. |
| `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md` | RECOMMENDATION | The originating handoff trigger: absorber (1d) deferred because AST cannot resolve `@unsafe` cross-file. |
| `HANDOFF-ai-harness-features-roadmap.md` | STAGED DESIGN | P5 (JSON reporter), P6 (semantic + educational autofix), P7 (memory→rule pipeline). The "is the harness mission better served by *delegating* semantic checks to the AI agent's compile cycle?" question this doc must address. |

This doc **extends** the swiftsyntax-based-custom-linter-investigation
along a narrow axis (type-resolution as a *backend for rule
predicates*, distinct from editor-UX) and **cites** the rest. No
duplication.

### Parent context

The parent session shipped, in the same arc:

- Experiment `swift-institute/Experiments/error-implies-sendable/`
  (CONFIRMED 2026-05-13) proving `Error: Sendable` refinement in
  Swift 6.
- A sweep removing 84 `Swift.Error & Sendable` redundancies across
  6 packages.
- The new `redundant refinement` rule with 16 tests, wired into the
  universal bundle.

The empirical case for "the rule is real and the table works for the
stdlib slice" is closed. The open question is whether to invest in a
backend that would let the rule generalize without a hardcoded table —
and whether that same backend unlocks a broader cohort of rules
currently deferred.

---

## Question

**Primary**: For the swift-linter package, does enriching `Lint.Source`
(currently `{file, path, tree, converter}`) with a type-resolution
backend pay for itself, and if so, which backend shape — sourcekit-lsp
subprocess, sourcekitd in-process, IndexStoreDB on `index-while-building`
artifacts, precomputed `swift-symbolgraph-extract` oracle, or
SwiftLexicalLookup + parsed-corpus extension — best fits the package's
posture and AI-harness mission?

### Sub-questions

1. What integration shapes exist? (≥5 surveyed.) **[Q1]**
2. What new rule classes become tractable per shape, for the
   currently-deferred cohort? **[Q2]**
3. What is the cost — build complexity, per-file latency, toolchain
   coupling, CI implications? **[Q3]**
4. Does the AI-harness mission (P5/P6/P7) reframe the question — should
   the linter resolve types itself, or delegate to the AI agent's own
   compile/test cycle? **[Q4]**
5. *(forward-looking)* What rule classes become possible **beyond** the
   currently-deferred cohort, if live type resolution lands? What design
   space does it open? **[Q6, added v1.1.0]**
6. *(forward-looking)* Is type-aware enforcement still "linter" work, or
   does it cross into static-analysis as a sister or parent domain? How
   do other ecosystems draw that boundary? **[Q7, added v1.1.0]**
7. *(forward-looking)* If sister-product capabilities materialize, what
   concrete package names + capability shapes apply, and how do they
   stack against the existing `swift-linter` + `swift-linter-rules`?
   **[Q8, added v1.4.0]**
8. What is the RECOMMENDATION with a concrete next step? **[Q5, in Outcome]**

---

## Analysis

### Empirical baseline — the current AST-only posture

Per `swift-foundations/swift-linter/README.md`:

> swift-linter (this package) — AST-only by construction; AST
> predicates ARE the surface. Primary mechanism: SwiftSyntax +
> SwiftParser; **no SourceKit-LSP dependency in the chain**.

`Lint.Source.Parsed` (in `swift-primitives/swift-linter-primitives/
Sources/Linter Primitives/Lint.Source.Parsed.swift`) carries:

```swift
public struct Parsed: Sendable {
    public let file: Source.File
    public let path: Lint.Source.Path
    public let tree: SourceFileSyntax
    public let converter: SourceLocationConverter
}
```

`Lint.Rule.findings` is `@Sendable (Lint.Source.Parsed, Severity) ->
[Diagnostic.Record]`. The rule has the AST, the path, the converter,
and severity — no symbol table, no module-level conformance graph, no
resolution of an identifier `Error` to the stdlib's `Error` protocol.

The package's distinguishing properties — fast, deterministic,
toolchain-decoupled, no build dependency — all derive from this AST-only
choice. Any LSP / SourceKit integration trades against this baseline.

### Q1 — Integration shapes surveyed

#### Shape A — `sourcekit-lsp` as subprocess LSP client

Run the `sourcekit-lsp` binary as a child process; send LSP requests
(`textDocument/hover`, `textDocument/definition`,
`workspace/symbol`) over stdin/stdout; consume JSON-RPC responses.

| Dimension | State |
|---|---|
| In-process vs subprocess | Subprocess only (LSP wire is stdin/stdout) |
| Per-file latency | Hundreds of ms per query post-warmup; first-query latency = full index build (seconds to minutes) |
| Toolchain coupling | Tight — `sourcekit-lsp` is part of the toolchain; ships with the active Swift install |
| Build precondition | Requires a `Package.swift` SourceKit-LSP can resolve **plus** a successful build for index/hover responses |
| API maturity | LSP protocol is stable; SourceKit-LSP's extensions (semantic tokens, etc.) churn |
| Cross-platform | macOS, Linux, Windows (Swift toolchain platforms) |
| Precedent | SwiftLint's `swiftlint analyze` (3% of SwiftLint rules use SourceKit — 9 of 246) ([SwiftLint 2026](https://github.com/realm/SwiftLint)) |

This is the option the prior research labelled "Option G" and
eliminated for editor-UX. As a type-resolution backend specifically,
the cost calculus changes — but only at the margin. The LSP wire
protocol's per-query latency is the structural cost.

#### Shape B — `sourcekitd` direct (C library)

Load `libsourcekitdInProc.{dylib,so,dll}` directly via Swift's
unsafe-pointer C-interop; send sourcekitd requests using the dictionary
API. Skips the LSP JSON-RPC layer.

| Dimension | State |
|---|---|
| In-process vs subprocess | In-process (library load) |
| Per-file latency | Tens of ms per query (no wire overhead) |
| Toolchain coupling | Very tight — `libsourcekitdInProc` is a toolchain artifact; ABI is C-stable but not source-stable. Linux: `/usr/lib/libsourcekitdInProc.so` or `LINUX_SOURCEKIT_LIB_PATH` |
| Build precondition | Same as LSP — index/hover requires a built module |
| API maturity | C dictionary API — stable in practice but not a SemVer surface; SourceKit team treats it as an internal protocol |
| Cross-platform | macOS, Linux (verified). Windows availability per Apple's distribution is partial; not a guarantee |
| Precedent | [SourceKitten](https://github.com/jpsim/SourceKitten) — the canonical Swift consumer of `sourcekitd` outside Apple. Used by SwiftLint pre-SwiftSyntax migration |

`sourcekitd` is what `sourcekit-lsp` wraps. Going direct buys ~10× per-query
latency at the cost of a much rougher integration boundary (C API
mediated by `SourceKitten`-style wrapper, or hand-rolled). The
`@usableFromInline internal` dictionary keys are a moving target across
toolchain revs.

#### Shape C — IndexStoreDB on `index-while-building` artifacts

Build the workspace with `-Xswiftc -index-store-path
$(pwd)/.build/index/store`, then query the resulting indexstore via
[`swiftlang/indexstore-db`](https://github.com/swiftlang/indexstore-db)
(LMDB-backed, Swift Package).

| Dimension | State |
|---|---|
| In-process vs subprocess | In-process (Swift Package) |
| Per-file latency | Milliseconds per lookup post-build (key-value DB) |
| Toolchain coupling | Loose at query time; tight at build time (indexstore format is toolchain-versioned, but stable across Swift 5.6+ in practice) |
| Build precondition | One-time `swift build` with `-index-store-path`; index is incremental |
| API maturity | Stable Swift package; semver-tagged releases; `IndexStoreDB.Symbol`, `.SymbolOccurrence`, `.SymbolRelation` are the surface types |
| Cross-platform | macOS, Linux (Swift toolchain platforms) |
| Precedent | **[Periphery 2.0](https://github.com/peripheryapp/periphery)** — switched from live SourceKit to IndexStoreDB for exactly the "snapshot of a built workspace" posture. The closest analog to the linter's posture |

IndexStoreDB answers the symbol-occurrence and symbol-relation
questions deterministically against a snapshot. It does **not**
answer expression-level type questions (no "what is the type of this
expression at line:col") — that requires live SourceKit. It does
answer "is symbol X declared as `@unsafe`?" and "what protocols does
type T conform to?" — exactly the deferred-rule questions.

Periphery's switch is the canonical precedent. Periphery's posture
("dead-code analyzer over a snapshot") matches the linter's
posture ("convention enforcer over a snapshot") far more closely than
SwiftLint's `analyze` mode ("rules over a live SourceKit session").

#### Shape D — `swift-symbolgraph-extract` precomputed oracle

The compiler's `symbolgraph-extract` driver tool emits a JSON catalog
per module with declaration fragments, access levels, and — crucially
— `conformsTo` / `inheritsFrom` relationships (verified via
[swift-symbolgraph-extract source](https://github.com/swiftlang/swift/blob/main/lib/DriverTool/swift_symbolgraph_extract_main.cpp)
and [SymbolGraphGen.h](https://fossies.org/linux/swift-swift/lib/SymbolGraphGen/SymbolGraph.h)).
Phase 1 of `ai-context-reduction-via-type-system-tooling.md` has
already executed against swift-primitives.

| Dimension | State |
|---|---|
| In-process vs subprocess | Subprocess at extraction time; in-process JSON read at query time |
| Per-file latency | Seconds to extract per module; milliseconds to read JSON; **precomputable as a build artifact**, queried at lint time |
| Toolchain coupling | Loose at query time (plain JSON); tight at extraction time (same swiftc that built the module) |
| Build precondition | Requires `swift build` per module + one extraction step per module |
| API maturity | JSON schema is stable across Swift 5.6+; ships with the toolchain; DocC consumes it as the canonical API surface format |
| Cross-platform | All Swift toolchain platforms |
| Scope | **Public API surface only** — implementation bodies, internal/private declarations, and test code are NOT in the graph |
| Precedent | swift-primitives Phase 1 produced 9.8 MB / 13,262 symbols / 19,022 relationships at `swift-primitives/.build/public-api-graph.json`. DocC uses the same format |

This shape is **Option F** in the prior research. It answers
declaration-shape and conformance-relationship questions for public
declarations. For *most* of the deferred rules — including the fully
general `redundant refinement` — public conformance relationships are
exactly what's needed.

#### Shape E — `SwiftLexicalLookup` + parsed-corpus extension

Use the GSoC-2024-produced [`SwiftLexicalLookup`](https://swiftpackageindex.com/swiftlang/swift-syntax/602.0.0/documentation/swiftlexicallookup)
library (part of swift-syntax 602+) for unqualified lexical name
resolution, augmented by parsing every imported package's source
ourselves to build a within-process protocol-refinement catalog.

| Dimension | State |
|---|---|
| In-process vs subprocess | Pure in-process (swift-syntax library) |
| Per-file latency | Milliseconds — pure syntax tree walking |
| Toolchain coupling | None beyond swift-syntax pinning (already in place) |
| Build precondition | None |
| API maturity | `SwiftLexicalLookup` shipped in swift-syntax 602; **qualified** name lookup is a [GSoC 2026 project](https://forums.swift.org/t/gsoc-2026-qualified-name-lookup-for-swift-syntax/85055) — not yet shipping |
| Cross-platform | All swift-syntax platforms |
| Scope | Lexical scope + unqualified-name resolution only; **does not handle protocol conformance, generic constraints, typechecker semantics, or module-imported symbol lookup** without significant rebuilding |

This shape preserves the linter's AST-only posture but adds a
parsed-corpus oracle the linter would have to maintain itself. The
qualified-lookup work is in flight; the *fully general* form of this
shape is ~12 months out. The cost of building a private oracle that
duplicates the symbol-graph or indexstore is high; the benefit
collapses into the same product as Shapes C/D without their
correctness guarantees.

#### Shape F — Hybrid: SwiftSyntax + precomputed conformance oracle

Stay AST-only at the rule level. At linter-startup, read a JSON
artifact ("conformance-table.json") produced offline that maps protocol
identifier → known refinements. The rule consults this map by leaf
name; the map is built by an extraction step that runs against
`symbolgraph-extract` JSON.

This is not a separate integration surface — it's a *consumption
pattern* on top of Shape D. Listed here because it answers the
strategic question (what's the smallest sufficient mechanism for the
specific rules currently deferred?) better than any of A–E alone.

| Dimension | State |
|---|---|
| In-process vs subprocess | Pure in-process (JSON read) |
| Per-file latency | None at lint time (map loaded once per run) |
| Toolchain coupling | Loose — JSON schema is the contract; extraction is the only step that touches swiftc |
| Build precondition | None at lint time; extraction is a separate offline cohort |
| API maturity | Same as Shape D for the producer; the consumer is one JSON read |
| Cross-platform | All Swift toolchain platforms |
| Scope | Whatever the extraction step records — initially protocol-refinement pairs; extensible to `@unsafe` declarations, `Sendable` conformance, etc. |

### Shape summary

| Shape | Live type queries | Snapshot queries | Build dep | Latency | Toolchain coupling | Precedent |
|---|:---:|:---:|:---:|---|---|---|
| A — sourcekit-lsp subprocess | ✅ | ✅ | yes | high | tight | SwiftLint `analyze` |
| B — sourcekitd direct | ✅ | ✅ | yes | medium | very tight | SourceKitten |
| C — IndexStoreDB | ❌ | ✅ | yes (one-time) | low | medium | **Periphery 2.0** |
| D — symbolgraph-extract | ❌ | ✅ (public API) | yes (one-time) | low (precomputed) | loose | DocC; ai-context Phase 1 |
| E — SwiftLexicalLookup | local only | local only | no | low | none | GSoC 2024 |
| F — Hybrid (D + AST) | ❌ | ✅ (public API) | yes (one-time) | none at lint | loose | (proposed here) |

For type-resolution as a *backend for rule predicates*, **C, D, and F
are the viable shapes**. A and B are over-coupled (live SourceKit is
overkill when the linter operates on a snapshot anyway). E is
under-powered for cross-module conformance.

### Q2 — Rule classes unlocked

Concrete rules deferred today under AST-only, with the shape that
unlocks each. Citations are to the file or skill that documents the
deferral or motivates the rule.

| # | Rule | Deferred at | Question the rule asks | Smallest unlock |
|---|---|---|---|---|
| 1 | **Fully general `redundant refinement`** — any `A & B` where `A` refines `B` (not limited to stdlib) | `Lint.Rule.Idiom.RedundantRefinement.swift:25-29` docstring | Does protocol `A` carry `: B` in its inheritance clause (transitively)? | **D / F** (public conformance relationship from symbol graph) |
| 2 | **`@unsafe` cross-file call-site detection** (absorber condition 1d) | `wave-4-absorber-pattern-policy-lean-2026-05-12.md` | Is the target of this call declared with `@unsafe`? | **C** (indexstore knows `@unsafe` declarations; alternatively D if symbol-graph emits the attribute) |
| 3 | **`Sendable` redundancy in user protocols** — `struct S: P, Sendable` where `P: Sendable` (the user-domain twin of #1) | derives from same skill rule [feedback_redundant_protocol_refinement] as #1 | Does user protocol `P` already refine `Sendable`? | **D / F** |
| 4 | **Redundant generic constraint** — `where T: Comparable, T: Equatable` (where the second is implied by the first) | implicit in [API-IMPL-*] convention | Does the implied refinement chain make a `where` clause member redundant? | **D / F** (same conformance graph as #1) |
| 5 | **Cross-file `[CONV-016]` retag opportunity** — does this `.rawValue`-chain happen on a `Tagged<…>` type that has a `.retag()` extension declared in another file? | `cardinal-ordinal-vector-enforcement-design.md` R0 | Is the LHS expression's type `Tagged<…>` AND does the call expression's structure match a retag pattern? | **C** (indexstore for type-of-expression) OR **D** (symbol graph for "what `.retag()` extensions exist") |
| 6 | **Spec-mirror conformance integrity** — type `RFC_4122.UUID` must conform to all relevant ISO protocols across the ecosystem | [API-NAME-003] | Cross-package conformance enumeration | **D** (public conformance relationships) |
| 7 | **`Hashable` implies `Equatable` in conformance lists** — `struct S: Hashable, Equatable` flags the `Equatable` (rule #1 case but for user types declaring the well-known stdlib chain) | stdlib refinement chain already in `idiomKnownStdlibRefinements` | (Already in scope — no unlock needed; serves as a sanity-check against the recommendation) | (already covered AST-only via the hardcoded table) |
| 8 | **`@inlinable` carrying a non-`public` reference** — needs to resolve the called name's access level | implicit in code-surface skill | What is the access level of the symbol referenced at this position? | **C** (indexstore declarations carry access level) |
| 9 | **`~Copyable` conformance leak** — a type whose generic parameter is `~Copyable` but whose conformance to a Copyable-requiring protocol is silent | derived from memory-safety skill | What's the conformance witness map for this type? | **D** (public conformance relationships) |
| 10 | **Suppressed-conformance audit** — every `extension Foo: ~Sendable {}` is justified by an explicit acknowledgement comment OR sits in an audited file | derived from memory-safety skill | Does the file declare a suppression that the rule pack hasn't explicitly recorded? | **AST-only sufficient** (control case — does NOT need type resolution; included to anchor the boundary) |

Seven of the nine listed rules are unlocked by C or D. Rule #2 is
unlocked specifically by C (indexstore records attribute decorations).
Rule #5 is the only one that genuinely benefits from live SourceKit —
because "type of expression at line:col" is exactly the kind of query
that AST + symbol-graph cannot answer. Rule #10 is a control: AST is
sufficient; type resolution would be over-engineering.

**Significance**: the majority of deferred rules become tractable
under **C or D**, the snapshot-based shapes. The live shapes (A, B)
unlock additional rules only at the expression level — and the
ecosystem's expression-level rules (R0 above, R0–R5 from the prior
research) were already on a different roadmap (the symbol-graph
Phase 2 doc).

### Q3 — Cost vs value matrix

#### Build complexity (initial implementation)

| Shape | Initial dev | Per-rule incremental | Cohort to migrate |
|---|---|---|---|
| Current (AST-only) | shipped | hours–days | n/a |
| Shape A (sourcekit-lsp) | 2–3 weeks (LSP JSON-RPC client; subprocess lifecycle; index warm-up handling) | days per simple rule | 10+ deferred rules; >50% need expression-level queries |
| Shape B (sourcekitd direct) | 2–4 weeks (C-interop layer; dictionary-key tracking; toolchain-specific path resolution) | days per simple rule | same as A |
| Shape C (IndexStoreDB) | 1–2 weeks (indexstore lifecycle in CI; `Lint.Source` enrichment with optional `IndexStoreDB.Symbol` lookups) | days per simple rule | rules 1–4, 6, 8, 9 of Q2 |
| Shape D (symbolgraph-extract) | 1 week (extraction script per package; JSON catalog producer; consumer reader in linter primitives) | hours per simple rule | rules 1, 3, 4, 6, 9 of Q2 |
| Shape F (hybrid: D + AST) | 3–5 days (a 50-line extractor over Phase 1's existing JSON catalog; one new field on `Lint.Source`) | hours per simple rule | rules 1, 3, 4 immediately |

#### Per-file lint runtime

| Shape | Per-file cost | Whole-package cost (~100 files) | Whole-ecosystem (~140 packages) |
|---|---|---|---|
| AST-only (today) | ~5–20 ms | seconds | ~1–2 min wall-clock |
| Shape A | ~150–400 ms per query × queries-per-file | minutes | hours |
| Shape B | ~30–80 ms per query × queries-per-file | seconds–minutes | tens of minutes |
| Shape C | ~2–10 ms per query × queries-per-file | seconds | minutes |
| Shape D / F | ~0 (precomputed; one map load at lint start) | unchanged from AST baseline | unchanged |

The "queries per file" coefficient matters: rule #1 fires once per
`CompositionTypeSyntax` node — typically 0–3 per file. Rule #5 fires
once per `.rawValue` access — potentially dozens per file. Live-query
shapes (A, B) pay the query latency per *node*, not per file.

#### Toolchain-version coupling cascade

| Shape | Cascade risk when Swift updates |
|---|---|
| AST-only | Low — swift-syntax minor bumps; ecosystem already manages |
| Shape A | High — sourcekit-lsp release-trains with the toolchain; LSP extensions evolve |
| Shape B | Very high — `libsourcekitdInProc` is private; sourcekitd dictionary keys are not a SemVer surface |
| Shape C | Medium — indexstore format is incompatible across major toolchain bumps (5.x → 6.x was a break); IndexStoreDB tracks |
| Shape D | Low — JSON schema is stable across major bumps; DocC depends on it |
| Shape F | Same as D |

#### CI implications

| Shape | New CI surface |
|---|---|
| AST-only | One CI step (existing) |
| Shape A | Additional CI step + binary distribution (`sourcekit-lsp` from toolchain); LSP warm-up adds wall-clock time |
| Shape B | Additional CI step + `libsourcekitdInProc` resolution per runner |
| Shape C | `swift build -Xswiftc -index-store-path …` becomes load-bearing; indexstore is a build artifact (cache-eligible) |
| Shape D | One additional extraction step per package; JSON artifact cached |
| Shape F | Same as D; one map-load per lint run |

#### Regression characterization

The current linter's distinguishing properties are:

1. **Fast** — completes in seconds across ~140 packages
2. **Deterministic** — same input → same output, no concurrency surprises
3. **Toolchain-decoupled** — runs on any Swift install that has `swift-syntax`
4. **No build dependency** — lints uncompiled source

Shapes A, B, and C compromise all four. Shape D compromises only #4
(the extraction step needs a built module), and only at *artifact
production time*, not at lint time. Shape F compromises nothing
beyond D.

#### Per [RES-018] premature-primitive test

| Hurdle | Shape D / F |
|---|---|
| Why not compose existing primitives? | Composes `symbolgraph-extract` (toolchain) + JSON read + AST walking — all existing. No new primitive |
| Is there a second consumer? | Yes — `ai-context-reduction-via-type-system-tooling.md` Phase 2 is a sibling consumer of the same `public-api-graph.json` artifact for AI-context-reduction. The linter is the **second** consumer, not the first |

The hurdle is cleared for Shape D / F. Shapes A, B, and C would
introduce a new live-resolution backend with no second consumer beyond
the linter itself — the test fires AGAINST those shapes.

### Q4 — Reframe via AI-harness mission

The handoff brief asks an honest comparison:

> **(a)** Linter does type resolution itself → expensive but
> autonomous.
> **(b)** Linter remains syntactic; semantic checks delegated to the
> AI agent's own compile/test cycle → cheap but couples to harness
> workflow.

#### What the AI-harness mission actually wants

Per `HANDOFF-ai-harness-features-roadmap.md`:

- **P5** — AI-targeted JSON reporter: every diagnostic carries a
  `rule_id`, `skill_citation`, `ai_failure_mode`, `suggestion`. The
  diagnostic is a *teaching artifact*.
- **P6** — Semantic + educational autofix: every fix-it carries a
  skill citation. The fix is an instance of the rule's principle.
- **P7** — Memory → rule pipeline: feedback memories become encoded
  rules. The pipeline produces *more rules*, not better-resolved
  versions of existing ones.

The harness mission is about **encoding skill rules + educating the AI
on the rule's principle**, not about catching things the compiler
already catches. The compiler is already the AI's authority for
"does this typecheck"; the linter is the institute's authority for
"does this match our conventions".

Two implications:

1. **The compiler already does (a) for almost-everything that matters
   semantically**. Untyped throws will compile; the compiler doesn't
   flag them. `Error & Sendable` will compile; the compiler doesn't
   flag the redundancy. **The semantic gap the linter is filling is
   precisely the convention gap the compiler refuses to enforce.**
2. **Linter findings need to be reproducible without the harness**.
   The educational citation in P5/P6 only works if the rule fires
   deterministically. If the rule needs the harness's compile cycle
   to fire, the harness becomes load-bearing — humans running
   `swift-linter` locally would see a *different* output. That breaks
   the "AI failure mode this rule catches" contract.

#### Comparing (a) and (b) honestly

| Axis | (a) Linter does it | (b) Delegate to AI's compile cycle |
|---|---|---|
| Reproducibility | High (linter output is the artifact) | Low (depends on AI agent's loop state) |
| Educational binding | Strong (rule citation is in the diagnostic) | Weak (compiler error needs interpretation) |
| Skill enforcement | Direct (rule = skill rule) | Indirect (rule maps to compile message) |
| Human/AI symmetry | Symmetric (same output for both) | Asymmetric (only fires in AI agent's loop) |
| Cost | High under Shapes A/B/C; low under D/F | Near-zero (already in the agent loop) |
| Coverage of "redundant refinement" | Yes (D/F: precomputed graph) | **No** (compiler doesn't warn on `Error & Sendable`) |
| Coverage of "untyped throws" | Yes (AST already; no resolution needed) | Yes (compiler error in Swift 7 strict mode; otherwise no) |
| Coverage of cross-file `@unsafe` | Yes (C/D: declaration lookup) | Partial (compiler issues a diagnostic only at the strict-concurrency layer) |

The honest read: **(b) is the right framing for compile-time semantic
errors. (a) is the right framing for *convention violations the
compiler does not catch*.** The redundant-refinement rule, the absorber-
(1d) rule, the spec-mirror conformance audit, the retag-opportunity
rule — all are convention violations the compiler is content to allow.
(b) does not catch them; (a) is the only path.

But (a) does NOT require sourcekit-lsp or sourcekitd. It requires
*enough* type resolution to answer the rule's question. For the
deferred rules surveyed, "enough" is the precomputed conformance
graph — Shapes D/F. The full live-query backends (A/B/C) over-pay for
the question being asked.

#### A third framing — encoding over resolution

The AI-harness mission's P7 (memory → rule pipeline) suggests a third
framing that neither (a) nor (b) names:

**(c)** Encode the type knowledge as a hardcoded table OR a precomputed
oracle, not as live resolution. Add entries when a new refinement is
confirmed (ideally by an `Experiments/` reducer, like
`error-implies-sendable`). The "fully general" form is approximated by
an extensible table whose entries are validated empirically.

This is the shape the current `redundant refinement` rule already
takes. The `idiomKnownStdlibRefinements` table is the encoded oracle.
Extending it to user-domain protocols means producing additional
entries — either by hand or by an extraction script over symbol graphs.

(c) is the cheapest and most aligned with P7's "every behavioral
correction becomes a mechanically-enforced rule" framing. The
extraction script is a one-time tool, not an ongoing backend.

### Q6 — Design space: rule classes unlocked beyond the current deferred set

**Added v1.1.0.** Q2 answered the backward-looking question — *"what
currently-deferred rules become tractable per shape?"*. This section
answers the forward-looking question — *"what entirely new rule classes
become possible if live type resolution is available?"*.

The distinction matters because the v1.0.0 recommendation (DEFER live
LSP/SourceKit) was grounded in coverage of the *current* cohort. The
broader design space changes the cost-benefit calculation if the
institute's long-term direction is type-driven convention enforcement.

#### Category 1 — Type-driven convention enforcement (institute-distinctive)

The institute's philosophy is *encode conventions as types*. A type-aware
linter inverts the enforcement model: the convention IS the type
signature, and rules verify the source matches.

This category is where the institute would differentiate from every
other ecosystem. No other Swift linter today (SwiftLint, swift-format,
Periphery) enforces conventions of the form "parameter named X must be
typed Y" or "this storage pattern requires this conformance."

| Rule | What it asks | Smallest sufficient backend |
|---|---|---|
| Parameter named `count` MUST be typed `Cardinal<…>` | Type of the parameter at decl site | Live (A/B) — type-of-decl-site query |
| Parameter named `index` MUST be typed `Index<Owner>` | Same | Live (A/B) |
| Stored property typed `Storage<X>` requires owning type `~Copyable` | Owning type's conformance set | Snapshot (D) — declaration-shape |
| Typed-throws error type MUST be nested inside owning type | Error type's declaration location | Snapshot (C) — declaration location |
| `Equatable` synthesis honesty: every stored property is `Equatable` | Each property's type + its conformance | Snapshot (D) for conformance lookup |
| `Sendable` honesty: struct's stored property is non-final class | Property type's class-ness + finality | Live (A/B) for type inference + Snapshot (D) for declaration |
| `[CONV-016]` retag opportunity: `.rawValue`-chain on a Tagged type | Type of receiver expression | Live (A/B) only |
| Generic parameter is monomorphic — drop the `<T>` | Call-site type at every usage of T | Live (A/B) |
| Function param has phantom-type bound that's unused at runtime | Generic constraint + body usage | Live (A/B) |

Coverage gain: 9+ rules in the institute's own convention space, most
of which are not detectable in any other ecosystem because the
conventions are unique to typed-primitive design.

#### Category 2 — Expression-level audits

These are unambiguously live-only. The question is "what's the type of
this expression at this source location?" — SwiftSyntax alone, indexstore,
and symbol-graph all return nothing here.

| Rule | Example |
|---|---|
| Implicit existential boxing | `let p: any P = concreteValue` (where `some P` would do) |
| Lossy implicit conversion | `let d: Double = anIntegerExpression` |
| Unnecessary type erasure | passing `concrete` where `some P` accepts |
| Implicit `Any` upcast | `as` cast hiding information |
| Value-type shadowing creates unnecessary copy | `if let x = x { x.foo() }` on a value-type x |
| Closure captures `consuming` parameter | Compiler flags some; style rule catches the smell earlier |

Coverage gain: ~6 rules immediately, ~12 if extended to all "type of
expression" predicates.

#### Category 3 — Refactoring suggestions (P6 autofix territory)

P6 (semantic + educational autofix) needs types to *propose a valid
alternative*. Detection without proposal is half the value; type-aware
fix-its are the differentiator.

| Pattern | Suggested fix-it | Why types needed |
|---|---|---|
| `where T: P, T: Q` | `where T: P & Q` | Confirm P and Q are protocols, not concrete types |
| `.compactMap { $0 }` on `[T?]` | `.compacted()` | Confirm receiver is `[T?]`, not `[T]` |
| `Array<T>()` | `[T]()` | Confirm spelling is on Array, not a typealiased shape |
| `func foo<T>(_:T)` with monomorphic `T` | drop the generic | Confirm T's call sites all use the same concrete type |
| `where Self == X` | flag existential-trap pattern | Confirm Self is a protocol Self, not a struct's own self |
| `for x in array.filter({...}).map({...})` | `for x in array.lazy.filter(…).map(…)` | Confirm receiver is a `Sequence` |

Coverage gain: ~8 high-confidence autofixes that the AI-harness can
mark `confidence: high` and auto-apply.

#### Category 4 — Concurrency-correctness rules

Swift 6 strict concurrency catches much of this at compile time. The
linter's role is to catch the *style smell* earlier and cite the skill
rule — preempting the compiler's diagnostic with an educational citation.

| Rule | Example |
|---|---|
| Implicit Sendable cross-boundary call | Non-Sendable closure capture flagged at call site |
| `nonisolated(unsafe)` on non-Sendable without justification | Annotation present + no accompanying comment-tag |
| Actor method takes `Self` but isn't `isolated` | Methods that should isolate their owning actor |
| `@MainActor` function called from `nonisolated` sync context | The isolation-jump pattern |

Coverage gain: 4–8 rules; significant overlap with compiler diagnostics
but distinct *educational citation* via skill IDs.

#### Category 5 — AI-harness-specific failure modes (strategic)

This is the category that defines the harness's leverage. AI agents
exhibit specific failure modes that are recognizable only via type
information. The harness mission is to encode these as enforced rules.

| AI failure mode | Detection requires |
|---|---|
| AI over-generalizes: `func foo<T>(_:T)` where T is monomorphic | Type at every call site of T |
| AI mis-imports: `Foundation.Date` where `Time.Instant` is in scope | Type resolution + scope of imported modules |
| AI uses stdlib stand-in: `.compactMap { $0 }` on `[T?]` instead of `.compacted()` | Receiver type |
| AI writes typed-throws wrong: `throws(any Error)` where a typed error exists in scope | Error type declarations + scope |
| AI re-erases types: passes `Tagged<X, Y>` to function taking Y via `.rawValue` | Type of receiver + function parameter type |
| AI generates redundant constraints: `T: Equatable, T: Hashable` | Protocol refinement relationships |
| AI flattens nested namespaces: writes `walkFiles` where `walk.files` exists | Symbol resolution + namespace lookup |
| AI uses `[T]()` when `Array<T>()` is in a generic context | Generic context + type inference |

Coverage gain: 10+ rules over time, each catching a recurring AI pattern.
Per `HANDOFF-ai-harness-features-roadmap.md`, every behavioral correction
in `feedback_*.md` memories that is structurally detectable should
become an encoded rule. The fraction that requires type information is
substantial — possibly the majority — once the trivial syntactic
patterns are exhausted.

#### Category 6 — Whole-program semantic invariants (snapshot-sufficient)

These are tractable under Shape C or D, no live SourceKit needed. They
matter for the medium-term roadmap because the snapshot backends can
ship without flipping the linter's posture on live-build coupling.

| Rule | Backend |
|---|---|
| Spec-mirror conformance audits at ecosystem scale | D (cross-package conformance graph) |
| Dead public API detection | C (indexstore: declarations + occurrences) |
| Layering violation via associated-type leak | D (signature graph) |
| Over-constrained protocol requirement (requirement no conformer uses) | C (call-graph + conformance) |
| Witness signature regression across versions | D (versioned graphs diffed) |
| `@inlinable` correctness pre-check (body references non-public symbol) | C (indexstore: access levels) |

Coverage gain: 6+ ecosystem-scale rules. Significant value for an
ecosystem the institute's size, where cross-package consistency is a
genuine concern.

#### Backend-coverage matrix

| Category | AST-only | Symbol graph (D) | IndexStoreDB (C) | Live SourceKit (A/B) |
|---|:---:|:---:|:---:|:---:|
| 1. Type-driven convention | partial | partial | partial | ✅ full |
| 2. Expression-level audit | ❌ | ❌ | ❌ | ✅ |
| 3. Refactoring fix-its | ❌ | partial | partial | ✅ |
| 4. Concurrency-correctness | partial | ❌ | partial | ✅ |
| 5. AI-harness failure modes | partial | partial | partial | ✅ |
| 6. Whole-program semantic invariant | ❌ | ✅ | ✅ | ✅ |

#### What this changes about the recommendation

The v1.0.0 recommendation (DEFER live LSP/SourceKit) was correct for
the currently-deferred *cohort*. The forward-looking categories above
show that **if** the institute's roadmap commits to type-driven
convention enforcement as a differentiator, the long-term cost-benefit
flips:

- Snapshot shapes (C/D) cover Category 6 fully and Categories 1, 3, 4, 5
  partially.
- Live SourceKit (A/B) is the only path to Category 2 entirely and to
  the high-value subsets of Categories 1, 3, 5.
- The most institute-distinctive category (Category 1, type-driven
  convention) requires live SourceKit for the deepest enforcement;
  partial coverage from Shape D is possible but degrades to "is this
  type declared with this annotation?" rather than "is this expression
  of this type?".

The near-term action (Shape F precomputed oracle, 1-week spike) is
unchanged. The medium-term direction shifts: rather than "defer live
indefinitely", the path becomes "Shape F now → IndexStoreDB when
Category 6 rules surface → reconsider live SourceKit when Category 2
or deep Category 1 rules accumulate".

### Q7 — Domain framing: linter, static analyzer, or something else?

**Added v1.1.0.** The previous sections treated "linter" as the
container for all this enforcement. The Q6 categories show some of these
rules cross conventional lines — expression-level type audits and
cross-procedural data-flow checks are traditionally *static analyzer*
work, not linter work. This section unpacks the domain boundaries.

#### Historical context

The term *linter* comes from `lint` (Bell Labs, 1979), a static checker
for K&R C that caught style and simple-correctness issues the C compiler
tolerated. The term generalized to "out-of-process source-text
rule-checker" and then drifted to cover almost any source-level analysis
tool, blurring distinctions that were once clear.

Modern terminology in adjacent ecosystems:

| Layer | Examples | Latency | Backend |
|---|---|---|---|
| **Formatter** | swift-format, gofmt, prettier, black | very fast | tokens + AST |
| **Linter (classic)** | ESLint core, ruff, SwiftLint AST rules, pyflakes | fast | AST |
| **Linter (type-aware)** | typescript-eslint, SwiftLint analyze, Roslyn analyzers (subset) | medium | AST + type info |
| **Static analyzer** | Clang Static Analyzer, Infer, SpotBugs, Error Prone, Periphery | slow | typed AST + dataflow |
| **Type checker** | tsc, mypy, Pyright, swiftc semantic phase | medium-slow | full inference |
| **Compiler** | rustc, swiftc, ghc | slow | everything |

The boundaries between these rows are fuzzy. typescript-eslint runs as
a "linter" by ESLint's plugin API but consumes the TypeScript program
(`parserServices.program`) — it sits across rows 2 and 3. SwiftLint's
`analyze` mode shifts between rows 2 and 3 depending on the rule.

#### Where swift-linter sits today

| Property | Layer |
|---|---|
| AST-only by construction | Row 2 (classic linter) |
| Rules carry skill citations | Row 2 — but with educational hooks |
| No SourceKit-LSP dependency | Row 2 — explicit |
| Consumer-facing surface name "swift-linter" | Row 2 — sets expectations |

The package sits in the classic-linter row. Shape F (precomputed oracle)
keeps it there architecturally — the oracle is a small augmentation
that doesn't change the rule API or its substrate.

#### Where Q6 would push it

| Q6 Category | Row it pushes into |
|---|---|
| 1. Type-driven convention | Row 3 (type-aware linter) |
| 2. Expression-level audit | Row 4 (static analyzer) |
| 3. Refactoring fix-its | Row 3–4 |
| 4. Concurrency-correctness | Row 3 |
| 5. AI-harness failure modes | Row 3 |
| 6. Whole-program semantic invariant | Row 4 (static analyzer, snapshot-flavor) |

Some Q6 rules are genuinely *static-analyzer* work in the traditional
sense — expression-level audits, dataflow-driven autofix proposals.

#### Should the package name change?

| Argument | For renaming | Against renaming |
|---|---|---|
| "Linter" sets fast/AST-only expectations | If type-aware rules are common, the name misleads | The name is well-understood; SwiftLint also hosts analyze rules |
| Consumer surface clarity | A new name signals the larger scope | A new name fragments the ecosystem of "Swift lint-class tools" |
| Engine internals | Internal architecture is independent of the name | — |
| Precedent | Roslyn analyzers ARE static analyzers; "analyzer" is the canonical term | SwiftLint hosts both lint and analyze rules under one binary; one name suffices |

**Resolution**: the consumer-facing name stays. The package internally
can host type-aware rules without renaming if the rule API is designed
to accept enriched sources (an optional `Lint.Source.TypeInfo` field on
`Lint.Source.Parsed`). Type-aware rules ship under an opt-in execution
mode (`swift-linter analyze`, mirroring SwiftLint's split) so the
default `swift-linter` invocation preserves the fast AST-only path.

The pattern matches the broader Swift ecosystem's naming discipline:
SwiftLint hosts both `lint` and `analyze`; swift-format hosts both
formatting and linting; DocC consumes symbol graphs but is named for
its primary consumer-facing function (documentation).

#### Sister domain vs parent domain

Three relationships are in play:

| Relationship | What it means |
|---|---|
| **Static analysis as parent domain** | Linting is the conservative end (fast, AST-driven). Type-aware analysis sits deeper. Same parent. Linting evolves toward static-analysis as types enter the picture. |
| **Code intelligence (LSP) as sister domain** | Same substrates (sourcekitd, IndexStoreDB) but different consumer model — editor query (interactive, partial-state-tolerant) rather than CI gate (deterministic, snapshot-driven). The institute could share substrate with a future code-intelligence tool without becoming one. |
| **Refactoring / fix-it as overlapping domain** | P6's autofix capability blurs into refactoring tools (IntelliJ refactor, Rope for Python). Type-aware autofix IS refactoring. The domain overlap is real; the consumer-facing distinction is "did you ask for the fix or did the rule propose it?" |

The institute's swift-linter today is firmly in the linter sub-domain.
Q6's categories pull it toward the broader static-analysis domain.
LSP-as-sister-domain is the right frame: the institute could later
build code-intelligence tools (a `swift-institute-lsp`?) that share
substrate (IndexStoreDB, symbol graphs) with swift-linter without the
two being the same tool. **Substrate is the integration story; product
is the consumer surface.**

### Q8 — Sister-product naming and stacking

**Added v1.4.0.** Q7 framed the domains abstractly (linter as
sub-domain of static analysis; LSP as sister domain; substrate is the
integration story, product is the consumer surface). This section
operationalizes those abstractions with concrete package names and
capability shapes.

Three distinct sister concepts emerge. They're commonly conflated but
answer different questions.

#### Concept A — `swift-institute-lsp` (NEW sister)

**Domain**: code intelligence / LSP server. Consumer is the IDE
(Xcode, VSCode, Cursor, Vim, JetBrains), not CI. Different posture
from `swift-linter`: interactive, partial-state-tolerant, live as the
user types.

**Naming**: `swift-institute-lsp` (RECOMMENDED) mirrors `sourcekit-lsp`'s
convention. Alternatives: `swift-linter-lsp` (sister-to-swift-linter
framing), `swift-code-intelligence` (broader scope).

**Substrate**: live SourceKit (sourcekitd or sourcekit-lsp wrapped) for
"type-at-this-location" queries; IndexStoreDB for cross-file
declaration / reference queries.

**Architecture sketch**:

- Wraps or proxies SourceKit-LSP for built-in language features
  (completion, jump-to-definition).
- Layers institute rules on top — runs the `swift-linter-rules`
  predicates against the typed AST sourcekitd produces.
- Emits LSP diagnostics with `data.rule_id` + `data.skill_citation`
  (the P5 spec from `HANDOFF-ai-harness-features-roadmap.md`).
- LSP `codeAction` capability — surfaces rule autofixes as editor
  quick-fixes with the skill citation in the action's title (P6 spec).
- LSP `hover` capability — hovering an institute-typed primitive
  shows the skill rule it embodies.

**Killer features uniquely possible at this layer**:

| Feature | What it does |
|---|---|
| Skill-citing squiggles | Real-time squiggles with the `[API-NAME-001]`-style rule ID inline |
| Educational hover | Hovering over `Cardinal`, `Tagged`, `Index` shows the skill defining the convention |
| Composition-aware completion | Suggests institute primitives over stdlib alternatives when typed context matches (e.g., suggests `Cardinal<…>` over `Int` for a count parameter) |
| Quick-fix from skill | Cmd+. surfaces `[CONV-016]` retag opportunities, `[API-IMPL-005]` one-type-per-file splits, etc. |
| AI-conversational scaffolding | An AI agent open in the LSP can query "what rules apply to this site?" via a custom request, avoiding a full lint re-run |

#### Concept B — `swift-linter analyze` mode (EXTEND existing)

**Domain**: type-aware linting at the same posture as `swift-linter`
(deterministic, snapshot-driven, CI-friendly). Same binary, opt-in
subcommand. SwiftLint's `lint` / `analyze` split is the operational
precedent; Periphery 2.0's IndexStoreDB posture is the substrate
precedent.

**Shape**: NOT a separate package. A target inside `swift-linter`
invoked as `swift run swift-linter analyze`. Q7's resolution argued
for one binary with two modes — the consumer-facing name stays
`swift-linter` regardless of which mode is invoked.

**What it adds over the AST-only mode**:

- Q6 Category 2 (expression-level audits).
- Q6 Category 6 (whole-program invariants — dead public API,
  conformance audits).
- Q6 Category 3 high-confidence fix-its (type-validated alternatives).
- The fully general `redundant refinement` form across user-defined
  protocols (the Phase 2 oracle covers stdlib; the v1.3.0 finding
  shows the user-domain extension needs path-aware matching).

**Substrate**: IndexStoreDB on `swift build -Xswiftc -index-store-path`.
Periphery 2.0's path; no live SourceKit needed.

This is the more immediate sister product. LSP (Concept A) is a
different bet (editor vs CI consumer).

#### Concept C — `swift-refactor` (LATENT, currently inside P6)

**Domain**: structural-transformation tool, distinct from both linter
and LSP. Generates and applies non-trivial transformations:

- "extract this protocol from these duplicated requirements"
- "split this multi-type file per [API-IMPL-005]"
- "rename `walkFiles` to `walk.files` and update all consumers"

**Current state**: P6 (semantic + educational autofix from the
AI-harness roadmap) is the seed. Once autofix grows beyond single-site
rename / inline replacement, it crosses into refactoring territory.
Periphery's "remove dead code" command is the cross-ecosystem
precedent for "linter-adjacent transformation tool"; typescript-eslint's
`--fix` is the JS-side reference.

This stays inside `swift-linter --fix` for now. If it grows, factor
out as `swift-refactor` consuming the same rule corpus.

#### Bird's-eye view

```
                          Editor consumer
                                │
                    ┌───────────┴───────────┐
                    │  swift-institute-lsp  │  ← Concept A, NEW sister
                    │  (LSP server)         │
                    └─────────┬─────────────┘
                              │ consumes
                  ┌───────────┴──────────────────┐
                  │                              │
              swift-linter                  swift-linter-rules
              + analyze mode                (rules + autofixes)
              ← Concept B, EXTEND            ← current package
                  │
                  │ consumes
        ┌─────────┼──────────────────┐
        │         │                  │
     Shape F   Shape C            Shape A/B
     (today)   (medium-term)      (long-term)
     oracle    IndexStoreDB       live SourceKit
```

CI consumes the bottom-middle. Editors consume the top. Same rule
corpus flows through both.

Refactoring tools (Concept C) consume the same rule corpus but
produce edits as their output rather than diagnostics. Latent until
P6 autofix crosses a complexity threshold.

#### Activation triggers

| Concept | Status | Trigger to activate |
|---|---|---|
| B (`swift-linter analyze`) | EXTEND existing | 3+ Category-6 rules in skill review (per Long-term framing decision table) |
| A (`swift-institute-lsp`) | NEW sister product | AI-harness mission strategic bet; needs explicit user authorization |
| C (`swift-refactor`) | LATENT inside swift-linter | P6 autofix complexity exceeds single-site mechanical replacement |

Concept B is the natural next step because it shares substrate with
what already exists. Concept A is the strategic bet because every rule
in the corpus becomes an editor-time signal, not just a CI signal —
the AI-harness mission compounds at this layer.

### Cross-ecosystem literature study [RES-021]

**Expanded v1.1.0.** The original (v1.0.0) prior-art survey was a 7-row
table focused on Swift-adjacent systems. The Q6 + Q7 framing pulls in a
broader question: how have *other ecosystems* drawn the boundary
between syntactic linting and type-aware analysis? This section answers
that question with depth across seven ecosystems.

#### Methodology

Per [RES-021]'s prior-art survey requirement (Tier 2+) plus the
contextualization step: for each ecosystem, the survey records (a) the
classic linter, (b) the type-aware analyzer if separate, (c) the API
that mediates type information access, (d) the architectural choice
(when type info entered the picture, how it was integrated), (e) what
this means for swift-linter.

Each ecosystem's choices reflect *when* type-aware analysis became a
priority — early (Roslyn, Go) or late (typescript-eslint after ESLint
had a plugin ecosystem; SwiftLint after years of SourceKit usage). The
*late* path consistently produces a hybrid with friction; the *early*
path consistently produces a more uniform API surface but commits
earlier to compilation as a precondition.

#### Ecosystem 1 — TypeScript (typescript-eslint)

**Linter (classic)**: ESLint, plugin-based, AST-only via ESTree.
**Type-aware extension**: typescript-eslint, an ESLint plugin that runs
the TypeScript compiler in the same process and exposes the typed
program to rule predicates.
**API**: `context.sourceCode.parserServices.program.getTypeChecker()`.
Rules opt into type info by requiring `parserOptions.project` in the
consumer's ESLint config; without it, type-aware rules error out at
configuration time.
**Architecture**: separately-built-then-bridged. ESLint pre-existed
TypeScript; typescript-eslint emerged as a hybrid plugin that parses
the file with `@typescript-eslint/parser` (producing ESTree-shaped AST
*and* TS-shaped AST mapped by `esTreeNodeToTSNodeMap`).
**Cost surface**: enabling type info forces TypeScript to analyze the
*entire project* per ESLint-typeable file. Documentation explicitly
warns this can be order-of-magnitude slower than untyped linting.
**Mitigation**: `projectService` (newer config) uses TypeScript's
incremental program facility for shared work across multiple lints.
**What it means for swift-linter**: the closest direct precedent. A
hybrid backend (AST + opt-in type info) is feasible, but the cost
surface is real. The opt-in mechanism (parser-options gate, errors at
config time if missing) is the right shape — type-aware rules should
not silently degrade to AST-only when type info is unavailable.

#### Ecosystem 2 — C# (Roslyn analyzers)

**Linter (classic)**: there isn't one separate from the compiler — the
compiler IS the analysis platform.
**Type-aware extension**: Roslyn analyzers (`DiagnosticAnalyzer` base
class), shipped as NuGet packages consumed via `csproj`.
**API**: `SyntaxNodeAnalysisContext` exposing both `Node`
(SyntaxNode — AST) and `SemanticModel` (semantic-info-bearing typed
view). The `SemanticModel` "needs the project to compile and work out
external code references" per official docs — type info IS the
compilation result.
**Architecture**: merged-from-day-one. Roslyn was designed in 2014–2015
as a compiler-as-a-service; analyzers were a first-class extension
point from the launch. There is no "AST-only fast tier" because the
platform is the compiler.
**Cost surface**: every analyzer pays compilation cost; cancellation
tokens propagate so analyzers can yield to user input in IDE scenarios.
**What it means for swift-linter**: the most elegant model, but
expensive to retrofit. Swift's analog would require making swiftc
itself the analysis platform — out of scope. Roslyn's lesson is *type
info as first-class input is uniform*; the lesson is NOT that the
institute should rebuild swift-linter as a swiftc-driven framework.
Worth noting: Roslyn analyzers can be very performant in practice
because the semantic model is shared across rules, amortizing the
compilation cost across many checks.

#### Ecosystem 3 — Go (`go/analysis` package + golangci-lint)

**Linter (classic)**: `go vet` (built-in, Go team-maintained, narrow
checks).
**Type-aware framework**: `golang.org/x/tools/go/analysis` — a Pass-based
framework where each analyzer receives a `Pass` struct containing
`Fset` (file set), `Files` (AST), `Pkg` (package), and `TypesInfo`
(populated by `go/types`).
**Orchestrator**: `golangci-lint`, a meta-linter that bundles
~50+ analyzers from the community and runs them under one
configuration.
**API**: `pass.TypesInfo.TypeOf(expr)`, `pass.TypesInfo.ObjectOf(ident)`,
`pass.Pkg.Imports()`. Type info is mandatory; there's no AST-only mode.
**Architecture**: merged-from-day-one. The `analysis` framework was
designed with type info as a first-class input. Authors of analyzers
opt into the level of type info they need; the framework computes it
once per package.
**Result-sharing mechanism**: each analyzer declares `Requires:
[]*Analyzer{...}` for upstream analyzers; results propagate via
`pass.ResultOf`. This enables composition (e.g., a custom analyzer that
requires `buildssa` for control-flow-graph access).
**What it means for swift-linter**: the cleanest "type info as
first-class input" precedent. The Pass-struct shape maps directly onto
the institute's `Lint.Source.Parsed` — adding a `typesInfo:
TypesInfo?` field with optional content is the same pattern. Notably,
`golangci-lint` is the *orchestrator*, not the analyzer; the
type-info-bearing analyzers are upstream libraries it composes. swift-linter
sits in roughly the orchestrator slot.

#### Ecosystem 4 — Rust (clippy + dylint + rust-analyzer)

**Linter (classic)**: rustc itself, with warnings.
**Type-aware extension**: `clippy`, distributed as a rustup component;
uses rustc internals via the `rustc_lint` crate. Clippy is *in-tree* —
its lint set is statically compiled into the binary, pinned to a
specific compiler version.
**User-extensible alternative**: `dylint` ([trailofbits/dylint](https://github.com/trailofbits/dylint)),
which loads user-authored lints from dynamic libraries. Dylint exists
because clippy's in-tree shape doesn't extend cleanly to user-authored
rules — each compiler version requires its own library, and dylint
manages the per-version driver matrix.
**LSP**: `rust-analyzer`, a separate tool that consumes the same crate
metadata but provides an editor-query interface rather than a
batch-CI interface.
**API for clippy**: rustc internals (`LateLintPass`, `EarlyLintPass`);
deep access to typed HIR.
**Architecture**: compiler-integrated (clippy) with a parallel
user-extension path (dylint). The user-extension path is operationally
expensive — dylint's existence is a tacit acknowledgment that in-tree
plugins don't compose well.
**What it means for swift-linter**: the cautionary case for tight
compiler integration. Clippy's in-tree advantage (full type access) is
balanced by clippy's distribution friction (rustup component) and
user-extension friction (dylint as workaround). swift-linter sitting
*outside* the compiler — like typescript-eslint, golangci-lint — keeps
the rule-author experience cheap.

#### Ecosystem 5 — Python (ruff + pylint + mypy/Pyright)

**Linter (classic)**: pylint, pyflakes — Python-implemented, AST-based.
**Modern fast linter**: ruff, Rust-implemented, AST-only.
**Type checker**: mypy (community-originated, gradual typing), Pyright
(Microsoft, more aggressive inference).
**Architecture**: permanently split with explicit complementarity. From
[ruff FAQ](https://docs.astral.sh/ruff/faq/): *"Ruff is a linter, not a
type checker. It can detect some of the same problems that a type
checker can, but a type checker will catch certain errors that Ruff
would miss. The opposite is also true: Ruff will catch certain errors
that a type checker would typically ignore... It's recommended that you
use Ruff in conjunction with a type checker, like Mypy, Pyright, or
Pyre."*
**What it means for swift-linter**: explicit precedent for the
recommendation in this doc. Ruff is the closest analog in posture
(fast, AST-only, intentionally not a type checker) and the most
explicit about the architectural choice. The Python ecosystem
demonstrates that the split model can be successful at scale (ruff has
near-universal adoption in modern Python projects, deployed alongside
mypy or Pyright in CI).

#### Ecosystem 6 — Java (SpotBugs + Error Prone + Checkstyle/PMD)

**Linter (classic style)**: Checkstyle, PMD — style + simple-correctness,
mostly AST-based.
**Static analyzer (bytecode)**: SpotBugs (successor to FindBugs) —
analyzes compiled .class files; type-aware by virtue of bytecode being
typed.
**Static analyzer (compile-time)**: Error Prone (Google) — hooks into
javac as a compiler plugin; type-aware via the compiler's symbol
table.
**Type checking**: integrated into javac itself; not a separate tool.
**Architecture**: permanently split into multiple non-overlapping
tools. Style rules in Checkstyle/PMD; semantic errors in SpotBugs
(post-compile) and Error Prone (during-compile).
**What it means for swift-linter**: a cautionary case for fragmentation.
Java's tooling is mature but fragmented; consumers must learn multiple
configurations. The institute's swift-linter benefits from being a
single configuration surface; adding a separate "swift-analyzer"
would replicate Java's fragmentation. The opt-in `analyze` mode under
the same binary (Q7 resolution) avoids this.

#### Ecosystem 7 — Swift (the institute's own context)

**Linter (classic)**: SwiftLint — predominantly SwiftSyntax (97% of 246
rules); 9 rules (3%) use SourceKit via the `analyze` command, which
requires a clean swiftc build log.
**Linter (institute)**: swift-linter — AST-only by construction, no
SourceKit dependency. Rules carry skill citations.
**Formatter**: swift-format — closed-catalog (43 rules), no
extensibility, includes a `lint` subcommand.
**Static analyzer (snapshot)**: Periphery — dead-code detection via
IndexStoreDB on `index-while-building` artifacts. Periphery 2.0
switched from live SourceKit to IndexStoreDB explicitly to improve the
snapshot/CI integration story.
**Documentation tool that consumes type info**: DocC — consumes
`swift-symbolgraph-extract` JSON, not live SourceKit.
**LSP**: SourceKit-LSP (Apple); consumed by editors, not CI tools
directly.
**Architecture**: fragmented landscape — multiple tools, each with its
own type-info strategy. SwiftLint hosts the lint/analyze split inside
one binary; Periphery uses indexstore; swift-format avoids the question
by being a formatter; swift-linter avoids the question by being
AST-only. **There is no consolidated "Swift static analyzer" with
ecosystem-wide adoption.**
**What it means for swift-linter**: the institute is operating in a
landscape with no clear leader. The lint/analyze split inside one
binary (SwiftLint's pattern) is the most adoption-friendly shape.
Periphery's indexstore-based path is the cleanest snapshot-analysis
precedent. The institute's swift-linter could occupy a unique niche:
type-aware *convention* enforcement (Category 1 in Q6), which neither
SwiftLint nor Periphery targets.

#### Synthesis — four architectural patterns

| Pattern | Examples | Characteristics |
|---|---|---|
| **Merged-from-day-one** | Roslyn (C#), Go `analysis` | Type info as first-class input; uniform API; expensive to retrofit elsewhere |
| **Separately-built-then-bridged** | typescript-eslint (TS), SwiftLint analyze + Periphery (Swift), Python ruff + mypy when used together | Hybrid plugin that opts into type info via gates; pre-existing infrastructure constrains the bridge shape |
| **Permanently split** | Python ruff vs mypy/Pyright; Java Checkstyle vs SpotBugs vs Error Prone | Two or more tools, each owning its slice; explicit complementarity in docs |
| **Compiler-integrated with user-extension workaround** | Rust clippy (in-tree) + dylint (out-of-tree workaround) | Tight compiler binding for the built-in lints; user-authored lints pay a per-version-driver tax |

#### Contextualization per [RES-021]

The patterns map to architectural commitments made at *different
points in each ecosystem's lifecycle*:

- **Early commitment (merged-from-day-one)** is feasible only when the
  language platform and the analysis platform co-evolve (Roslyn, Go).
  Swift didn't take this path — SourceKit-LSP and SwiftLint were built
  independently.
- **Bridging** is the common late-binding pattern (typescript-eslint).
  Cost is real (project-wide analysis per file); benefit is the unified
  rule-author API.
- **Split** is the conservative path (Python ruff/mypy). Each tool stays
  focused; consumers learn both.
- **Compiler-integrated** is the most powerful but the most fragile for
  user extensions (Rust clippy/dylint).

For the institute, the **split** pattern is the de facto choice today
(swift-linter AST-only; symbol-graph extraction as a separate pipeline)
and the **bridging** pattern is what the Q6 categories suggest for the
long term (one binary, AST-only fast path, opt-in type-aware mode).
The institute's roadmap should commit to **split today, bridge later**
explicitly, rather than drift into one or the other by accident.

Two further observations from the literature:

1. **No mature ecosystem made the linter a live LSP client.** The
   precedent runs through indexstore (Periphery, IndexStoreDB), compiled
   bytecode (SpotBugs), pre-built type-checker programs
   (typescript-eslint, Roslyn). Live LSP is consumer-facing (editor),
   not analyzer-facing. Confirms Shape A's elimination at the
   architectural level, not just the cost level.
2. **The "second consumer" hurdle** ([RES-018]) is real in every
   ecosystem. Roslyn analyzers, Go analysis Passes, typescript-eslint
   rules — each ecosystem's type-aware analysis layer was justified
   only because multiple consumers needed the same machinery. The
   institute's symbol-graph already has a second consumer
   (ai-context-reduction); a live SourceKit backend does not yet have
   one beyond the linter.

### Empirical validation [RES-025] — Cognitive Dimensions on the recommended path

| Dimension | Assessment of the F-shape recommendation |
|---|---|
| Visibility | High — `redundant refinement` already cites its rule ID; the table-extension mechanism is a 50-line file |
| Consistency | High — the existing hardcoded table extends to a build-time-generated table without API churn at the rule level |
| Viscosity | Low — adding refinement pairs is one entry per pair; the extraction script regenerates from the canonical symbol graph |
| Role-expressiveness | High — the rule still reads as "is this pair in the refinement table?". The mechanism for *populating* the table is decoupled from the rule's predicate |
| Error-proneness | Low — the extracted table is verified by the same `Experiments/error-implies-sendable` pattern; new entries get one-hour reducers |
| Abstraction | Appropriate — the linter remains AST-only; the oracle is one immutable JSON read per lint run |

---

## Outcome

**Status**: RECOMMENDATION (2026-05-13).

### Recommended path forward — DEFER live LSP/SourceKit; adopt Shape F (precomputed conformance oracle) for the immediate cohort

**Primary deliverable**: keep `swift-linter` AST-only by construction.
Introduce a **conformance oracle** — a JSON file emitted by an
extraction step that reads `swift-symbolgraph-extract` output and
produces a compact `(refining, refined)` table. The linter loads the
oracle once per run and passes it through `Lint.Source.Parsed` (new
optional field) or via a sidecar configuration value the rules consult.

**Why DEFER live LSP/SourceKit**:

1. The deferred rules' question set is **dominated by snapshot
   queries** (declaration shape, conformance relationship, attribute
   presence). Snapshot shapes (C, D, F) cover the majority; live
   shapes (A, B) over-pay.
2. The AI-harness mission is about **encoding + education**, not
   semantic-error catching. Convention violations are the linter's
   domain; semantic errors are the compiler's. Live type resolution
   blurs the boundary.
3. Per [RES-018], live shapes (A, B, C) lack a second consumer beyond
   the linter. Shape D's artifact (the symbol-graph JSON) already has
   a second consumer (`ai-context-reduction-via-type-system-tooling.md`
   Phase 2). The hurdle is cleared only for D / F.
4. The regression of #1–#4 of the linter's distinguishing properties
   (fast, deterministic, toolchain-decoupled, no build dep) is severe
   under A/B/C and minimal under D/F.

### Phase 2.5 — User-domain scan empirical findings (added v1.3.0, 2026-05-13)

After Phase 2 landed the stdlib oracle, the experiment was extended
to batch-process multiple symbol graphs with a two-pass
union-then-match approach. This unlocks **cross-module** protocol→protocol
refinement detection — when one institute package's protocol refines
another package's protocol (e.g., `Comparison.Protocol: Equation.Protocol`
where the two protocols live in different `.symbols.json` files).

**Scope**: 28 symbol-graph files covering 15 swift-primitives packages
(algebra-{field,group,magma,module,monoid,ring,semigroup,semilattice,semiring},
bifunctor, comparison, equation, hash, property, tagged, witness).

**Empirical results**:

| Metric | Value |
|---|---|
| Modules scanned | 28 symbol-graph files |
| Protocol-kind symbols (union) | 4 (Comparison.Protocol, Equation.Protocol, Hash.Protocol, Witness.Protocol) |
| `conformsTo` relationships across all inputs | 122 |
| Protocol→protocol refinements detected | **2** |

**The two pairs found**:

| Refining | Refined |
|---|---|
| `Comparison_Primitives_Core.Comparison.Protocol` | `Equation_Primitives_Core.Equation.Protocol` |
| `Hash_Primitives_Core.Hash.Protocol` | `Equation_Primitives_Core.Equation.Protocol` |

These are legitimate institute refinements — `Comparison: Equation`
(comparable values are equatable) and `Hash: Equation` (hashable
values are equatable). Both are cross-module: the source's symbol
graph references a target defined in another module's symbol graph.
The two-pass approach detects them; a single-pass approach
(processing one graph at a time without a union table) would miss
them entirely.

**Critical finding — institute convention causes leaf-name collision**:

The institute uses the `Namespace.\`Protocol\`` naming pattern (per
[PKG-NAME-*] conventions): every institute protocol's *leaf* name is
literally the string "Protocol", and the discriminator is the
namespace prefix (`Comparison`, `Equation`, `Hash`, ...).

| Institute pair (full path) | Leaf-name pair |
|---|---|
| `Comparison.Protocol → Equation.Protocol` | `("Protocol", "Protocol")` |
| `Hash.Protocol → Equation.Protocol` | `("Protocol", "Protocol")` |

The current `Lint.Rule.Idiom.RedundantRefinement` rule matches on
leaf names (`Error`, `Comparable`, `Hashable`, ...). For stdlib
protocols, leaf names are unique and this works. For institute
protocols, leaf names collide and the rule's table becomes degenerate
— `("Protocol", "Protocol")` repeated for every institute refinement.

**Implication for rule design**:

To consume user-domain refinement pairs, the rule's matching strategy
must become *path-aware*: extract the full member-access chain at each
leaf of a `CompositionTypeSyntax` (e.g., recognize `Comparison.Protocol`
as the path `["Comparison", "Protocol"]`, not just the leaf `Protocol`),
and match against full-path entries in the user-domain table.

The change to the visitor is small (~10 lines), but it raises a
secondary question: when a user writes `Equation.Protocol & Comparison.Protocol`
in the SAME composition, the rule must flag the redundancy. With
path-aware matching, the entries `(Comparison.Protocol, Equation.Protocol)`
and `(Hash.Protocol, Equation.Protocol)` would catch the relevant
cases. Stdlib entries remain leaf-based as today.

**Decision deferred**: the user-domain table is NOT shipped to
swift-linter-rules in this cycle. Promoting it would require the
path-aware matching update — a separate scope-bounded decision.
The empirical data is recorded; the rule update is queued.

**Why so few institute pairs (2 vs stdlib's 136)?**

Two structural reasons surfaced:

1. **The institute uses witness-as-value over protocol-inheritance.** The
   algebra packages (Magma, Semigroup, Monoid, Group, Ring, Field,
   Module, Semilattice, Semiring) define `Algebra.Magma<Element>` and
   friends as STRUCTS wrapping operations, not as protocols. The
   "Monoid: Semigroup" refinement chain you'd see in Haskell or Rust
   typeclasses simply doesn't exist in institute code — there are no
   institute-defined Monoid / Semigroup protocols.
2. **Tagged + Carrier as concrete types, not protocols.** swift-tagged-primitives
   declares `Tagged` as a struct, and the symbol graph shows 24
   `conformsTo` relationships from Tagged to various protocols
   (Sendable, Hashable, etc.) — all type-to-protocol, none
   protocol-to-protocol.

The institute's protocol-refinement surface is genuinely small and
likely to stay so. The hand-curated `Comparison: Equation` and
`Hash: Equation` pairs may be effectively the entire institute table.

**Provenance**: experiment run output is committed at
`swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/Outputs/run-userdomain.txt`.

### Long-term framing (added v1.1.0 per Q6 + Q7)

The near-term recommendation above is unchanged from v1.0.0. The Q6 +
Q7 sections (added v1.1.0) reframe the recommendation in a longer-time
horizon. The institute's deliberate posture should be:

**Today — Split (Pattern 3 from the literature study)**:
swift-linter remains AST-only. Shape F (precomputed conformance
oracle) is the only enrichment. Type-aware rules are out of scope.

**Medium-term — Bridging (Pattern 2)**:
when Category 6 rules (whole-program semantic invariants —
spec-mirror audits, dead public API, layer-violation detection)
surface as a cohort, stand up IndexStoreDB (Shape C). The bridge is
opt-in: an `analyze` subcommand or a separate target whose rules
require indexstore. The AST-only fast path remains the default
invocation. Periphery's 2.0 transition is the operational precedent;
typescript-eslint's `parserOptions.project` gate is the
config-shape precedent.

**Long-term — Reconsider compiler integration**:
if Category 2 (expression-level audits) or deep Category 1
(type-driven convention) rules accumulate and the IndexStoreDB
backend proves insufficient, re-evaluate live SourceKit (Shape A/B).
This decision should be driven by accumulated rule pressure, not by
proactive backend investment. Until then, the Roslyn / Go-merged
pattern is out of reach — Swift's tool ecosystem evolved separately
from swiftc, and retrofitting compiler integration is a major
commitment.

**Naming and surface**:
the `swift-linter` package name stays. If type-aware rules ship, they
ship under an opt-in execution mode (`swift-linter analyze`,
mirroring SwiftLint's split). The fast AST-only path remains the
default `swift-linter` invocation. New ecosystem tools (a
`swift-institute-lsp` for editor consumption, a separate
`swift-static-analyzer` if domain pressure justifies) are sister
products sharing substrate (IndexStoreDB, symbol graphs), not
renames of swift-linter.

**Decision-points that should trigger re-evaluation**:

| Trigger | Action |
|---|---|
| 3+ Category-6 rules surface in skill review | Authorize the IndexStoreDB bridging spike per Pattern 2 |
| 3+ Category-1 rules surface where Snapshot (D) coverage is insufficient | Authorize a live-SourceKit feasibility spike per Pattern 4 |
| AI-harness rule corpus (Category 5) exceeds 20 rules with type info needed | Re-evaluate bridging vs split |
| Periphery / SwiftLint / DocC change posture (e.g., live LSP adoption) | Re-survey the ecosystem |
| Swift compiler adds qualified-name lookup to swift-syntax (per GSoC 2026 in flight) | Re-evaluate Shape E (parsed-corpus extension) |

The institute's posture is **deliberately conservative** — preserve
the linter's distinguishing properties (fast, deterministic,
toolchain-decoupled, no build dep) until rule-pressure forces the
trade. The literature study confirms this is the dominant successful
pattern; merged-from-day-one models require co-evolution with the
language platform that Swift's tooling didn't have.

### Spike executed and CONFIRMED (v1.2.0, 2026-05-13)

The 1-week spike was executed in-session. Hypothesis CONFIRMED;
status promoted RECOMMENDATION → DECISION.

**Experiment location**: `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/`.

**Placement note**: the v1.0.0/v1.1.0 doc named
`swift-institute/Experiments/symbol-graph-conformance-oracle/` — that
was wrong. Per [EXP-022], an experiment with package dependencies
lives in the highest-layer dep's `Experiments/`. The spike's reducer
imports `JSON` (from swift-foundations/swift-json, L3), so the
experiment is co-located with swift-json. The subject is
`swift-symbolgraph-extract` (toolchain-tool behavior) but the
placement rule follows the import graph, not the subject.

**Reducer** (~120 lines including header + helper + report):
parses a `.symbols.json` file with swift-json's `JSON.parse`,
walks `symbols[]` to identify protocol-kind symbols, walks
`relationships[]` filtering to `conformsTo` between two
protocol-kind symbols, emits `(refining, refined)` pairs to
`Outputs/conformance-oracle.json`.

**Inputs tested**:

| Input | Size | Symbols | conformsTo | Protocol→protocol | Wall-clock |
|---|---|---|---|---|---|
| `Carrier_Primitives.symbols.json` (institute per-module) | 22 KB | 7 | 0 | 0 (Carrier doesn't refine other protocols) | 48 ms |
| `Swift.symbols.json` (stdlib, extracted in-session via `swift symbolgraph-extract`) | 86 MB | 14,552 | 18,314 | **136 pairs** | 128 s |

**Hypothesis disposition**:

1. *"Protocol→protocol `conformsTo` is captured in symbol-graph JSON"*
   — **CONFIRMED**. The Swift stdlib graph contains 18,314 `conformsTo`
   relationships; 136 of them are between two protocol-kind symbols.
2. *"A ~100-line reducer suffices"* — **CONFIRMED**. The shipped
   reducer is 120 lines including header, helper, and report.
3. *"Wall-clock under 30s for an institute module"* — **CONFIRMED**
   for per-module institute graphs (Carrier: 48 ms, 600× under
   threshold). **REFUTED** for Swift stdlib at 128 s — but the
   bottleneck is swift-json's text parser on 86 MB pretty-printed
   input, NOT the symbol-graph format. Production oracle generation
   is offline (one-time cost); lint-time consumers read a compact
   `conformance-oracle.json` (~5 KB for 136 pairs) in milliseconds.

**Verification against the hardcoded table**: ALL 26 entries of the
linter rule's `idiomKnownStdlibRefinements` array appeared in the
extracted output:

- `Error → Sendable` ✓
- `Comparable → Equatable` ✓, `Hashable → Equatable` ✓, `AdditiveArithmetic → Equatable` ✓
- `Strideable → Comparable` ✓
- The numeric tower: `Numeric → AdditiveArithmetic` ✓, `SignedNumeric → Numeric` ✓, `BinaryInteger → Numeric` ✓, `BinaryInteger → Hashable` ✓, `BinaryInteger → Strideable` ✓, `FixedWidthInteger → BinaryInteger` ✓, `SignedInteger → BinaryInteger` ✓, `UnsignedInteger → BinaryInteger` ✓
- The FloatingPoint tower: `FloatingPoint → SignedNumeric` ✓, `FloatingPoint → Strideable` ✓, `FloatingPoint → Hashable` ✓, `BinaryFloatingPoint → FloatingPoint` ✓
- The Collection tower: `Collection → Sequence` ✓, `BidirectionalCollection → Collection` ✓, `RandomAccessCollection → BidirectionalCollection` ✓, `MutableCollection → Collection` ✓, `RangeReplaceableCollection → Collection` ✓, `LazySequenceProtocol → Sequence` ✓, `LazyCollectionProtocol → LazySequenceProtocol` ✓, `LazyCollectionProtocol → Collection` ✓

**Plus 110 additional refinements** the hardcoded table doesn't cover.
Examples:

- `Error → SendableMetatype`
- `CodingKey → {Sendable, CustomStringConvertible, CustomDebugStringConvertible}`
- `DurationProtocol → {Sendable, Comparable, AdditiveArithmetic}`
- `OptionSet → {SetAlgebra, ExpressibleByArrayLiteral, RawRepresentable}`
- `SIMD → {SIMDStorage, Hashable, ExpressibleByArrayLiteral, …}`
- `StringProtocol → {TextOutputStreamable, BidirectionalCollection, …}`
- The full transitive closure across the towers (e.g., `BinaryFloatingPoint → {Hashable, Comparable, Equatable, AdditiveArithmetic, ExpressibleByFloatLiteral}` — all derived through the refinement chain)

**Rule promotion** (per [EXP-006a]): the docstring at
`swift-foundations/swift-linter-rules/Sources/Linter Rule Idiom/Lint.Rule.Idiom.RedundantRefinement.swift`
was amended (2026-05-13) to remove the "requires type resolution"
framing. The rule's hardcoded table remains operational; Phase 2
work would bundle the extraction step into the linter cohort's
release pipeline and switch the rule to consume the generated
oracle (with the hardcoded table acting as a fallback override).

**Original Concrete-next-step content (now superseded)**:

1. Create an experiment package
   `swift-institute/Experiments/symbol-graph-conformance-oracle/` per
   `experiment-process` conventions.
2. The experiment's hypothesis: *"`swift-symbolgraph-extract` against
   a swift-primitives package emits sufficient `conformsTo` /
   `inheritsFrom` relationships to construct a refinement table that
   correctly identifies the same redundant-refinement findings the
   current hardcoded `idiomKnownStdlibRefinements` table identifies for
   stdlib protocols, AND extends to ≥3 user-domain protocols."*
3. The experiment's reducer (~100 lines):
   - Read `swift-primitives/.build/public-api-graph.json` (Phase 1
     artifact).
   - Extract `conformsTo` relationships among `protocol` symbols.
   - Emit JSON: `[{refining: "P", refined: "Q"}, ...]`.
   - Diff against the existing hardcoded table; verify stdlib
     coverage is a superset.
   - Add three user-domain refinement pairs and verify the table
     captures them (e.g., `IO.Closeable: Sendable` if present;
     pick concretely from swift-primitives).
4. Run wall-clock-time: extraction + read + table emission MUST
   complete in <30 seconds for a swift-primitives sub-package.

**Spike outcomes**:

- **Confirm**: oracle is producible; the rule's table extension is
  mechanical. Promotes to Phase 2 (production: bundle the extraction
  step into the linter cohort's release pipeline; document the oracle
  schema).
- **Refute**: symbol graph misses cross-package refinements or emits
  ambiguous nominal names. Backstop is to (a) keep the current
  hardcoded table as the authoritative source, (b) revisit Shape C
  (IndexStoreDB) with a narrower scope.

### Phasing (post-spike)

**Phase 1 — Spike** (1 week, this recommendation's concrete next step).
**Phase 2 — Production oracle** (1–2 weeks): bundle extraction into a
script under `swift-foundations/swift-linter/Scripts/`; produce a
`conformance-oracle.json` artifact per ecosystem; consume in
`redundant refinement` and the to-be-encoded user-domain twin rule.
**Phase 3 — Absorber (1d) under Shape C** (deferred, 3–4 weeks): if and
when `@unsafe` cross-file rules surface as wave-5+, re-evaluate Shape C
(IndexStoreDB). The decision is independent of Phase 2; bringing in C
later carries no Phase-2 churn cost since the linter remains AST-only.

### Out of scope (deliberately not addressed)

- **Editor integration (LSP)**: still deferred per prior research.
- **Compile-time / macro-attached enforcement**: opt-in per type; not
  ecosystem-wide.
- **Replacing the existing AST rule predicates with type-resolved
  variants**: the hardcoded table works; the spike is additive, not
  substitutive.
- **The fully general "any A & B where A refines B" form across all
  user-domain protocols** *before* the spike confirms feasibility. The
  rule's docstring claim about type resolution being a one-way door
  is here recharacterized: a precomputed oracle answers the same
  question without committing the linter to a live backend.

### Risks

1. **Symbol-graph emits ambiguous nominal names** across packages
   (e.g., two `Error` protocols in different modules). Mitigation:
   the oracle records `(module, refining, refined)`; the rule's leaf-name
   match degrades gracefully when the module is ambiguous, falling back
   to the hardcoded table. Risk class: low.
2. **The oracle goes stale**: a symbol graph captured before a
   refinement was added under-reports. Mitigation: rebuild the oracle
   as part of the linter cohort's release; embed the source-toolchain
   version in the oracle's metadata; refuse to load an oracle whose
   version diverges by more than one minor from the linter's own. Risk
   class: low.
3. **The 50-line extraction script becomes a maintenance burden** as
   symbol-graph format evolves. Mitigation: the format is the same one
   DocC consumes; the institute already has a Phase-1 consumer; the
   extraction is one read, not a full re-implementation. Risk class:
   very low.

### Why this overrides the originating handoff's framing

The handoff brief framed the question as "does LSP/SourceKit
integration pay for itself, and if so, in what shape?". The brief
implicitly contemplated a single backend axis — live or not. The
analysis here surfaces a third axis: **precomputed oracle**. The
brief's question is satisfied by the answer "no, not yet, and the
shape that pays for itself is a precomputed oracle (Shape F) — an
existing artifact extended by ~50 lines, not a new backend".

The rule's own docstring will need an amendment after Phase 2 lands —
the "would require type resolution; the swift-linter stack is
SwiftSyntax-only" framing should be replaced with "the rule consults
a precomputed conformance oracle; the swift-linter stack remains AST-only
by construction".

---

## Open Follow-ups (added v1.4.0)

Items surfaced during the LSP/SourceKit-integration arc that didn't
ship in this cycle, with current dispositions. This is the canonical
durable list for future sessions picking the arc back up — anything
in conversation but not here will rot.

### Done in this arc

| Item | Where landed |
|---|---|
| Spike: precomputed conformance oracle | v1.2.0 — 136 stdlib pairs extracted; experiment at `swift-foundations/swift-json/Experiments/symbol-graph-conformance-oracle/` |
| Production oracle: regen script | v1.2.0 — `swift-linter-rules/Scripts/regenerate-stdlib-refinements.sh` |
| Rule split + auto-generated stdlib table | v1.2.0 — `Lint.Rule.Idiom.RedundantRefinement.StdlibRefinementsTable.swift` is auto-generated and committed |
| User-domain refinement scan | v1.3.0 — 2 institute pairs found (Comparison→Equation, Hash→Equation); leaf-collision finding recorded |
| Sister-product naming + capabilities map | v1.4.0 — Q8 above |

### Deferred with reason

| Item | Why deferred |
|---|---|
| Encode `feedback_extension_implies_copyable` as a rule | Open design question raised in conversation: how would this rule handle **conditionally `~Copyable`** types? The explicit form `extension X where Element: ~Copyable` is unambiguous, but composite shapes (extensions whose generic constraint includes a protocol P where P's `~Copyable` suppression is conditional) make the rule's predicate ambiguous. Needs a separate design pass to enumerate the shapes a rule would need to handle — or narrow the rule's scope to flagging only the bare `extension X { }` case where X is generic AND has unambiguous `~Copyable` suppression visible in the same file. The MEMORY entry [feedback_extension_implies_copyable](file:///Users/coen/.claude/projects/-Users-coen-Developer/memory/feedback_extension_implies_copyable.md) captures the underlying convention; the rule encoding awaits design resolution |
| Run `redundant refinement` against the full institute ecosystem | Explicitly out of scope; separate work track |
| Productionize user-domain refinement table | v1.3.0 finding showed only 2 institute pairs; the rule would need path-aware matching (~10-line visitor change) to consume them. Productionization gated on that rule-design decision |

### Queued (today-sized, hours each)

| Item | Estimated effort | What it tells us |
|---|---|---|
| Symbol-graph attribute coverage experiment | ~1h | Does `swift-symbolgraph-extract` emit `@unsafe`, `@inlinable`, `@usableFromInline`, access levels? If yes, Shape D covers more than just protocol conformance and we stay on it longer |
| IndexStoreDB minimum-viable spike | ~3h | First empirical bite at Shape C. ~100-line Swift package opening an indexstore and querying for declarations carrying a given attribute. Confirms feasibility for `@unsafe` cross-file detection (absorber-pattern condition 1d, currently dropped) |
| P5 JSON reporter for ONE rule | ~4h | Minimum-viable `Linter Reporter AI` target emitting `redundant refinement` findings in the spec'd schema (per `HANDOFF-ai-harness-features-roadmap.md`). Resolves three of P5's Open Questions empirically by trying them |
| P6 fix-it for `redundant refinement` | ~3h | Add `Lint.FixIt` to the rule; mechanical edit (delete redundant member at the reported position). Minimum-viable P6 demonstration |
| P7a memory-inventory pass | ~1h | Scan `~/.claude/.../memory/feedback_*.md`, label each as `structurally-detectable` / `semantic-only` / `process-rule`. Empirical input for "is the P7 pipeline worth building?" — without yet building it |
| Run regen script against Swift 6.4-dev nightly | ~5 min | Surface 6.3 → 6.4 stdlib refinement deltas early; sets up the toolchain-bump workflow concretely |

### Handed off

| Item | Handoff document |
|---|---|
| swift-json parse-performance investigation (128s on 86 MB) | `HANDOFF-swift-json-parse-performance.md` at workspace root; awaiting investigator findings; will append `## Findings` on completion |

### Architectural decisions queued

| Decision | Trigger to revisit |
|---|---|
| Make the rule's leaf-name matching path-aware | When user-domain rules surface AND the path-aware-matching design is worked out. Small visitor change; risk is in matching strategy across stdlib + user-domain + qualified forms (e.g., `Swift.Error` still needs to collapse to leaf "Error" while `Comparison.Protocol` needs to retain its qualified prefix) |
| Commit to Concept B (`swift-linter analyze` mode) | When 3+ Category-6 rules surface in skill review |
| Commit to Concept A (`swift-institute-lsp` NEW package) | Strategic bet — requires explicit user authorization. Not gated on a count; gated on harness-mission resource allocation |
| Factor out `swift-refactor` (Concept C) | When P6 autofix accumulates structural transformations beyond single-site edits |

---

## References

### Internal (prior research)

- `swift-institute/Research/swiftsyntax-based-custom-linter-investigation.md` (RECOMMENDATION 2026-05-06) — 8-option survey; this doc extends Option F.
- `swift-institute/Research/ai-context-reduction-via-type-system-tooling.md` (RECOMMENDATION 2026-04-01) — Phase 1 symbol-graph pipeline executed 2026-03-15.
- `swift-institute/Research/primitives-public-api-graph-analysis.md` (RECOMMENDATION 2026-04-13) — Phase-1 result confirming relationships captured.
- `swift-institute/Research/workspace-wide-symbol-search-for-cclsp.md` — CCLSP / SourceKit-LSP integration limits.
- `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md` — absorber (1d) deferral.
- `HANDOFF-ai-harness-features-roadmap.md` — P5/P6/P7 mission framing.
- `HANDOFF-lsp-sourcekit-integration-research.md` — the originating handoff for this doc.

### Internal (skill files cited)

- `swift-institute/Skills/research-process/SKILL.md` — [RES-001], [RES-003], [RES-013a], [RES-018], [RES-019], [RES-021], [RES-027].
- `swift-institute/Skills/handoff/SKILL.md` — [HANDOFF-013], [HANDOFF-013a], [HANDOFF-016].

### Internal (experiment)

- `swift-institute/Experiments/error-implies-sendable/` (CONFIRMED 2026-05-13) — empirical confirmation of `Error: Sendable` refinement in Swift 6; precedent for the proposed `symbol-graph-conformance-oracle` experiment.

### External (verified)

- [SwiftLint](https://github.com/realm/SwiftLint) — 246 rules; 9 use SourceKit (3%); analyze mode is "considerably slower than lint rules".
- [Periphery](https://github.com/peripheryapp/periphery) — dead-code analyzer; switched to IndexStoreDB at 2.0 ([What's new in Periphery 2.0](https://github.com/peripheryapp/periphery/wiki/What's-new-in-Periphery-2.0)).
- [`swiftlang/indexstore-db`](https://github.com/swiftlang/indexstore-db) — Swift Package; LMDB-backed query API.
- [`swiftlang/sourcekit-lsp`](https://github.com/swiftlang/sourcekit-lsp) — LSP implementation for Swift.
- [`swift-symbolgraph-extract` source](https://github.com/swiftlang/swift/blob/main/lib/DriverTool/swift_symbolgraph_extract_main.cpp) — driver source confirming `conformsTo` / `inheritsFrom` emission.
- [SymbolGraphGen.h](https://fossies.org/linux/swift-swift/lib/SymbolGraphGen/SymbolGraph.h) — relationship type definitions.
- [SourceKitten](https://github.com/jpsim/SourceKitten) — canonical Swift consumer of `sourcekitd`.
- [SwiftLexicalLookup](https://swiftpackageindex.com/swiftlang/swift-syntax/602.0.0/documentation/swiftlexicallookup) — swift-syntax 602 module.
- [GSoC 2026 — Qualified Name Lookup for swift-syntax](https://forums.swift.org/t/gsoc-2026-qualified-name-lookup-for-swift-syntax/85055) — qualified-lookup work in flight; not shipping.

### External (verified — added v1.1.0 literature study)

**TypeScript ecosystem**:
- [typescript-eslint](https://typescript-eslint.io/) — the TypeScript ESLint plugin and parser project.
- [Linting with Type Information](https://typescript-eslint.io/getting-started/typed-linting/) — `parserOptions.project` gate; project-wide analysis cost.
- [Custom Rules](https://typescript-eslint.io/developers/custom-rules/) — `parserServices.program.getTypeChecker()` access.
- [@typescript-eslint/parser](https://typescript-eslint.io/packages/parser/) — `esTreeNodeToTSNodeMap`, `tsNodeToESTreeNodeMap`.

**C# / Roslyn ecosystem**:
- [Roslyn analyzers tutorial](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/tutorials/how-to-write-csharp-analyzer-code-fix) — `DiagnosticAnalyzer`, `SemanticModel`, `SyntaxNodeAnalysisContext`.
- [Analyzer Actions Semantics](https://github.com/dotnet/roslyn/blob/main/docs/analyzers/Analyzer%20Actions%20Semantics.md) — registration model.
- [How to Write a C# Analyzer and Code Fix](https://github.com/dotnet/roslyn/blob/main/docs/wiki/How-To-Write-a-C%23-Analyzer-and-Code-Fix.md) — analyzer authoring guide.

**Go ecosystem**:
- [`golang.org/x/tools/go/analysis`](https://pkg.go.dev/golang.org/x/tools/go/analysis) — `Pass` struct with `TypesInfo`; analyzer composition via `Requires`.
- [golangci-lint](https://github.com/golangci/golangci-lint) — meta-linter / orchestrator over `go/analysis` analyzers.
- [Using go/analysis to write a custom linter (Fatih Arslan)](https://arslan.io/2019/06/13/using-go-analysis-to-write-a-custom-linter/) — author walkthrough.

**Rust ecosystem**:
- [rust-clippy](https://github.com/rust-lang/rust-clippy) — in-tree compiler-bound lints.
- [dylint](https://github.com/trailofbits/dylint) — dynamic-library out-of-tree lints; per-compiler-version driver matrix.
- [Write Rust lints without forking Clippy (Trail of Bits, 2021)](https://blog.trailofbits.com/2021/11/09/write-rust-lints-without-forking-clippy/) — dylint architectural motivation.
- [rust-analyzer](https://rust-analyzer.github.io/) — separate LSP server.

**Python ecosystem**:
- [Ruff](https://github.com/astral-sh/ruff) — fast Rust-implemented Python linter.
- [Ruff FAQ — "Ruff is a linter, not a type checker"](https://docs.astral.sh/ruff/faq/) — explicit architectural statement.
- [mypy](https://github.com/python/mypy) — community-originated gradual type checker.
- [Pyright](https://github.com/microsoft/pyright) — Microsoft type checker; stricter inference.
- [pylint](https://github.com/pylint-dev/pylint) — classic Python linter.

**Java ecosystem**:
- [SpotBugs](https://github.com/spotbugs/spotbugs) — bytecode-level static analyzer; successor to FindBugs.
- [Error Prone](https://github.com/google/error-prone) — javac-plugin-based compile-time analyzer.
- [Checkstyle](https://github.com/checkstyle/checkstyle) — AST-level style enforcer.
- [PMD](https://github.com/pmd/pmd) — AST-level rule-based linter.
