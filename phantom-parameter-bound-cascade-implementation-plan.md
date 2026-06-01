# Phantom-Parameter Bound Cascade — Implementation Plan

<!--
---
version: 1.3.0
last_updated: 2026-06-01
changelog:
  - 1.3.0 (2026-06-01): EXECUTED. Relaxed the enumerated phantom sites across 22 committed swift-primitives/swift-foundations packages (G1→G6; per-package 6.3 build gate; index/property/tree embedded-confirmed on 6.5-dev nightly — note the installed nightly rolled 6.4→6.5-dev). pool/byte-parser rebuild-verified transparent. Termination scan (G-B/G-D/G-NP/G-RISK + phantom-scan-v3) → zero in-scope non-maximal phantom sites remain (termination caught 3 missed Tier-1b sites — parser Located/Spanned + Tree.Position — now relaxed); G-RISK invariant held throughout. Companion edits the build gate surfaced (§4 under-stated): conditional conformances must restate suppression (`where Tag: ~Copyable & ~Escapable`), the `Ordinal.Protocol.Domain` phantom associatedtype + the `Ratio<From,To>` decl needed relaxing. Deliberate non-relax: hash (`Hash.Protocol: Swift.Hashable` requires Escapable on <6.4; conformance excluded on 6.4+). Deferred uncommitted (unrelated in-flight-arc baselines): link (own-test `__unchecked`-init overload regression), kernel (iso-9945 Memory.Map L2 skew), identities (RFC_4122 baseline). Skill [API-NAME-010b]/[IDX-001] + advisory lint `Lint.Rule.Naming.PhantomSuppression` landed. SHAs in §7.
  - 1.2.0 (2026-06-01): GENUINELY ecosystem-complete. (1) Reconciled the now-COMPLETED `.Indexed` consumer arc: Array.Indexed/Array.Fixed.Indexed are DELETED (confirmed gone) → the one positive phantom-marker constraint the §4 proof reasoned around is gone, STRENGTHENING the proof to zero; graph/pool/byte-parser are migrated + EDITABLE (held-exclusion dropped). (2) Added a BARE-PHANTOM pass (v1.1.0 caught only ~Copyable-suppressed phantoms + 2 hand-known bare roots): extended the scanner (/tmp/phantom-scan-v3.py) to bare generic params, with full-type-body stored-detection + per-candidate positive confirmation. +13 bare-phantom sites: swift-graph-primitives (10: Sequential/Node/Index/Adjacency.List/Adjacency.Extract/Remappable.Remap/Traversal.First.Breadth/Depth/Topological + Default.list — `Tag` proven never-a-value package-wide) and swift-dimension-primitives (3: abs/min/max<Tag,T>). Property/Identity.ID re-confirmed mechanically. Tier-0 4→13, Tier-1b 59→63, total ~138→~151, packages 24→26 (+graph, +dimension); pool/byte-parser enter as downstream rebuild-only consumers (0 relax sites). Re-derived order: G6 migrated consumers (graph relaxes AFTER the bridge leaf). Stored-value EXCLUSIONS enumerated (§1.6). Non-breaking (the bare pass's critical safety axis): re-ran §4 risk over all new sites — zero positive phantom-marker constraints.
  - 1.1.0 (2026-06-01): HARDENED the Tier-1b inventory. The v1.0.0 G-D grep keyed on the literal param name `Tag`, missing phantom params spelled otherwise (`T`/`Element`/`From`/`To`) — a [HANDOFF-040] name-keyed pattern-incompleteness. Re-ran NAME-AGNOSTICALLY (any identifier) single-line + multi-line-complete via /tmp/phantom-scan.py across all institute orgs. +21 new phantom op-sites (ordinal/cardinal/affine arithmetic + retag/scale; swift-parser-primitives Located/Spanned; Tree.Position), excluding stored-value Storage `<Element>` / pointer `<Pointee>` per §4. Tier-1b 38→59; total ~117→~138; packages 23→24 (+swift-parser-primitives). Non-breaking completeness fix (a missed site stays at its status-quo bound and still builds).
  - 1.0.0 (2026-06-01): initial plan.
status: EXECUTED
tier: 3
scope: ecosystem-wide
kind: implementation-plan
status_line: EXECUTED 2026-06-01 — 22 packages relaxed + committed (unpushed), G1→G6 with per-package build gate + termination scan; G-RISK non-breaking invariant held. 3 packages deferred on unrelated baselines; hash a deliberate non-relax. Skill [API-NAME-010b] + advisory lint landed. SHAs in §7.
implements: phantom-parameter-suppressed-protocol-bound.md (RECOMMENDATION v1.0.0) — the verdict: a phantom (never-stored, discriminator-only) generic parameter MUST be bound ~Copyable & ~Escapable.
extends: phantom-typed-value-wrappers-literature-study.md (RECOMMENDATION v1.0.0, Tier 3) — phantom Tag never affects the substructural classification (cited per [HANDOFF-013]).
toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64, macOS 26.2 — all enumeration greps run 2026-06-01.
---
-->

> **STATUS: EXECUTED 2026-06-01.** The cascade was executed G1→G6 with the §3 per-package 6.3 build gate and the §3/[HANDOFF-035] termination scan. 22 packages relaxed + committed (unpushed); the G-RISK non-breaking invariant held throughout. See §7 for per-package commit SHAs, the deliberate hash non-relax, the 3 deferred packages (blocked by unrelated in-flight-arc baselines), and the acceptable non-breaking residue.

## 0. Summary

The verdict (`phantom-parameter-suppressed-protocol-bound.md`): a **phantom** (never-stored, discriminator-only) generic parameter MUST be bound `~Copyable & ~Escapable`; any non-suppressed marker requirement on a phantom is vacuous over-constraint. This plan enumerates the **complete** cascade that brings the ecosystem into compliance.

**Scale (mechanically enumerated, §1):** ~151 relax sites across **26 packages** (24 in `swift-primitives`, 2 in `swift-foundations`). Three tiers: **Tier 0** phantom *declarations* — the infrastructure roots (`Index`, `Property`, `Identity.ID`) **AND domain-type declarations** (`Graph.Sequential<Tag, Payload>`, `Graph.Adjacency.List<Tag>`, …); **Tier 1** `extension Tagged … Tag: ~Copyable` operation/conformance sites; **Tier 1b** free `func`/`init`/`subscript` operation sites. Enumerated **name-agnostically AND across both bound shapes**: any generic param — `~Copyable`-suppressed (`<T: ~Copyable>`) **or bare** (`<Tag>`, no suppression → currently requires *both* Copyable and Escapable) — used *only* as a `Tagged`/`Index`/`Property`/`.Indexed` discriminator (per `[HANDOFF-040]`; v1.1.0 closed the name axis, v1.2.0 the bare axis). The `swift-tagged-collection-primitives` bridge is the terminal **leaf**. **A site missed by this inventory is non-breaking** — it stays at its status-quo bound and keeps building; surfacing it is a *completeness* fix, not a *safety* fix.

**Scope statement:** the rule covers **ALL phantom parameters** — both the `Tagged`/`Index`/`Property` infrastructure and domain-type declarations (`Graph.*`, `Identity.ID`, …), bare or suppressed. **Stored-value parameters are excluded** (Array/Queue/Set/Storage `<Element>`, `Unsafe*Pointer<Pointee>`, the `Payload`/`Base`/`RawValue`/`Adjacent` of a wrapper) — relaxing a stored param to `~Escapable` is *wrong and breaking*, so every candidate is positively confirmed pure-phantom before inclusion (§1.6 lists the exclusions).

**Scope (principal-directed):** `swift-primitives` is the primary focus (24 packages — all Tier 0/1/1b sites); `swift-foundations` is secondary (2 sites: `Identity.ID`, `Kernel` CPU.Atomic.Flag); `swift-standards` and the standards sub-orgs carry only concrete-tag *uses* (zero relax targets). **`coenttb` and other consumer orgs are ignored** — they import pointfreeco's `Tagged`, not the institute `Tagged_Primitives`.

**Non-breaking (proven by grep, §4) — STRENGTHENED in v1.2.0:** `Array.Indexed<Tag: Copyable>` — the *one* positive phantom-marker constraint the v1.1.0 proof reasoned around — has now been **DELETED** by the completed `.Indexed` consolidation. The risk grep over the entire ecosystem (including all new graph + dimension sites) now returns **zero** positive constraints on a phantom's Copyable/Escapable-ness. Widening only enlarges admissible domains and breaks nothing. (This is the *critical* safety axis for the bare pass: relaxing a stored param would break — hence the §1.6 exclusions.)

**In-flight arcs (§5):** (a) the `*.Indexed` consolidation is **COMPLETE** — `Array.Indexed`/`Array.Fixed.Indexed` are deleted, graph/pool/byte-parser are migrated and editable (no longer held); (b) `swift-array-primitives`'s Collection.Protocol/Iterable relaxation has **settled** (commit `9c226f5`) — array-adjacent work may proceed.

---

## 1. Complete Site Inventory

Completeness is earned by the greps below, not asserted. Every command excludes `.build/` mirror checkouts and `Tests/Experiments/Research` trees, and excludes already-maximal (`& ~Escapable`) sites. All run from `/Users/coen/Developer`, 2026-06-01, Swift 6.3.2.

### 1.1 Generating commands

```bash
# G-A — phantom typealias declarations over Tagged/Index/Property (generic tag param):
grep -rnE 'typealias [A-Za-z_.]+ *<[^>=]*> *= *(Tagged|Index_Primitives\.Index|Index|Property|[A-Za-z_.]+\.Indexed)\b' \
  swift-primitives --include="*.swift" | grep -v '/.build/' | grep -vE '/(Tests|Experiments|Research)/' | grep -v '& ~Escapable'

# G-B — extension Tagged … Tag: ~Copyable (single-line where):
grep -rnE 'extension Tagged\b[^{]*Tag: ~Copyable' swift-primitives --include="*.swift" \
  | grep -v '/.build/' | grep -vE '/(Tests|Experiments|Research)/' | grep -v '& ~Escapable'        # → 63

# G-B' — multi-line where forms missed by G-B (catches Tagged+Literals, +AtomicRepresentable, the bridge):
grep -rnE 'Tag: ~Copyable\b' swift-primitives/swift-tagged-primitives swift-primitives/swift-tagged-collection-primitives \
  --include="*.swift" | grep -v '/.build/' | grep -vE '/(Tests|Experiments|Research)/' | grep -v '& ~Escapable'   # → 11

# G-D — free func/init/subscript/struct with <… Tag: ~Copyable> (not 'extension Tagged'):
grep -rnE '<[^>]*\bTag: ~Copyable\b[^>]*>' swift-primitives --include="*.swift" \
  | grep -v '/.build/' | grep -vE '/(Tests|Experiments|Research)/' | grep -v '& ~Escapable' | grep -vE 'extension Tagged\b'   # → 40

# G-D' — NAME-AGNOSTIC re-run (v1.1.0 hardening). G-D above keys on the literal name `Tag`, so it MISSES phantom
#   params spelled otherwise (T / Element / From / To) — a [HANDOFF-040] name-keyed pattern-incompleteness.
#   (i) single-line: ANY <IDENT: ~Copyable> co-occurring with a phantom wrapper. Pass dir args EXPLICITLY — zsh does
#   NOT word-split an unquoted `$VAR` of space-joined dirs (it silently greps nothing):
grep -rnE '<[^<>]*: ~Copyable[^<>]*>' \
  swift-primitives swift-foundations swift-standards swift-iso swift-microsoft swift-linux-foundation \
  --include="*.swift" | grep -v '/.build/' | grep -vE '/(Tests|Experiments|Research)/' | grep -v '& ~Escapable' \
  | grep -E 'Tagged<|Index<|Index_Primitives\.Index<|Property<|\.Indexed<' | grep -vE '\bTag: ~Copyable\b'
#   (ii) multi-line-complete (generic clause and wrapper-use on different lines) via /tmp/phantom-scan.py: per
#   declaration it accumulates the full signature, extracts every ~Copyable param (any name != Tag), KEEPS those used
#   as a Tagged/Index/Property/.Indexed first type-arg, and FLAGS params also used as a stored value
#   (consuming/borrowing/inout/`: P`/`-> P`) — the §4 phantom-vs-stored discriminator.
#   Result: 56 wrapper-param decls → 21 phantom (added to §1.4 Tier-1b) + 35 stored-value
#   (Storage `<Element>` move/deinit/init; pointer `<Pointee>` arithmetic; Memory raw-pointer) — OUT per §4 / §1.6.

# G-C — Property + *.Indexed struct declarations:
grep -rnE 'struct (Property|Indexed)<' swift-primitives --include="*.swift" | grep -v '/.build/' | grep -vE '/(Tests|Experiments|Research)/'

# G-NP — non-primitives institute orgs (op-sites + generic-tag typealiases):
grep -rnE 'Tag: ~Copyable' swift-foundations swift-standards swift-iso swift-microsoft swift-linux-foundation \
  --include="*.swift" | grep -v '.build/' | grep -vE '/(Tests|Experiments|Research)/' | grep -v '& ~Escapable'
grep -rnE 'typealias [A-Za-z_.]+ ?(<[^>]*>)? *= *Tagged<' swift-foundations swift-standards swift-iso swift-microsoft swift-linux-foundation \
  --include="*.swift" | grep -v '.build/' | grep -vE '/(Tests|Experiments|Research)/'

# G-RISK — positive phantom-marker constraints (the non-breaking check, §4):
grep -rnE '\bTag: (Copyable|Escapable)\b' swift-primitives --include="*.swift" | grep -v '/.build/' | grep -vE '~(Copyable|Escapable)'
grep -rnE '<Element: (Copyable|Escapable)[,>]' swift-primitives --include="*.swift" | grep -v '/.build/'

# G-BARE — v1.2.0 bare-phantom pass. v1.1.0 caught only ~Copyable-SUPPRESSED phantoms (+2 hand-known
#   bare roots). This adds domain-type/func decls with a BARE generic param (no suppression → today
#   requires BOTH Copyable AND Escapable), e.g. Graph.Sequential<Tag, Payload>.
#   CRITICAL safety: a bare param is far more often a STORED VALUE (Array/Storage/Buffer<Element>,
#   Unsafe*Pointer<Pointee>, P?) than a phantom; relaxing a stored param to ~Escapable BREAKS builds.
#   So EVERY candidate is POSITIVELY confirmed pure-phantom (used ONLY as a Tagged/Index/Property/
#   .Indexed discriminator; NEVER a stored prop, by-value param/return, [P], Container<P>, P?,
#   consuming/borrowing/inout P). Mechanized in /tmp/phantom-scan-v3.py, which (a) anchors the generic
#   clause to the DECLARED NAME (the <...> before '(' '=' '{' 'where' — not a <...> in a value type),
#   (b) scans the FULL brace-balanced type body so stored properties are seen, (c) keeps
#   phantom-wrapper-use ∧ ¬stored-use. Survivors are READ BY HAND — the scanner does not strip `///`,
#   so many raw hits are doc-comment examples / Package.swift / concrete namespaces, excluded on read.
#   Package-wide positive confirmation for the bulk locus (graph): `Tag` is NEVER a raw value —
grep -rnE '(:[[:space:]]+Tag\b|->[[:space:]]*Tag\b|\[Tag\]|(Array|Queue|Set|Span|Storage|Buffer)<[^>]*\bTag\b|(consuming|borrowing|inout)[[:space:]]+Tag\b)' \
  swift-primitives/swift-graph-primitives/Sources --include="*.swift" | grep -v '/.build/' | grep -vE 'Tagged|Node<Tag|Index<Tag|Adjacency|//'   # → 0 ⟹ Tag pure phantom package-wide
```

**Org coverage.** Institute-authored orgs searched: `swift-primitives`, `swift-standards`, `swift-foundations`, `swift-institute`, `swift-iso`, `swift-ietf`, `swift-incits`, `swift-ieee`, `swift-iec`, `swift-ecma`, `swift-w3c`, `swift-whatwg`, `swift-microsoft`, `swift-linux-foundation`, `swift-applications`, `swift-components`, `swift-arm-ltd`, `swift-intel`, `swift-riscv`, the legal orgs (`rule-*`, `swift-law`, `swift-nl-*`, `swift-us-*`, `swift-eu-*`), and the consumer orgs `coenttb`/`tenthijeboonkkamp`. **External upstream mirrors** (`apple`, `pointfreeco`, `vapor`, `swiftlang`, `groue`, `stripe`, `tuist`, `bytedance`, `compnerd`, `swift-server`, …) are **not** institute code → out of scope. Only `swift-primitives` and `swift-foundations` contain relax targets (every other org has only concrete-tag *uses* or zero hits); **`coenttb` uses pointfreeco's `Tagged` (`import Tagged` ×151), not the institute `Tagged_Primitives`** → out of scope entirely.

### 1.2 RELAX — Tier 0: phantom declarations — infrastructure roots + domain types (13 sites)

| # | Package | File:line | Current | → Relaxed |
|---|---------|-----------|---------|-----------|
| 1 | swift-index-primitives | `Index.swift:38` | `Index<Element: ~Copyable>` | `Index<Element: ~Copyable & ~Escapable>` **[ROOT]** + DocC `Phantom-Type-Tags.md:14`, `Index.md:34` |
| 2 | swift-property-primitives | `Property.swift:46` | `Property<Tag, Base: ~Copyable>` *(Tag bare → both required)* | `Property<Tag: ~Copyable & ~Escapable, Base: ~Copyable>` |
| 3 | swift-tree-primitives | `Tree.Index.swift:36` | `Index<Tag: ~Copyable> = Index_Primitives.Index<Tag>` *(re-export)* | `Index<Tag: ~Copyable & ~Escapable>` |
| 4 | swift-foundations / swift-identities | `Identity.ID.swift:46` | `ID<Domain, RawValue> = Tagged<Domain, RawValue>` *(Domain bare)* | `ID<Domain: ~Copyable & ~Escapable, RawValue>` *(phantom `Domain` only; `RawValue` is the stored Underlying — see §4 boundary)* |
| 5 | swift-graph-primitives | `Graph.Sequential.swift:27` | `Sequential<Tag, Payload>` *(Tag bare)* | `Sequential<Tag: ~Copyable & ~Escapable, Payload>` **[v1.2.0]** *(Payload stored — keep)* |
| 6 | swift-graph-primitives | `Graph.Node.swift:16` | `Node<Tag> = Index<Tag>` | `Node<Tag: ~Copyable & ~Escapable>` **[v1.2.0]** |
| 7 | swift-graph-primitives | `Graph.Index.swift:37` | `Index<Tag> = Index_Primitives.Index<Tag>` | `Index<Tag: ~Copyable & ~Escapable>` **[v1.2.0]** |
| 8 | swift-graph-primitives | `Graph.Adjacency.List.swift:5` | `List<Tag>` | `List<Tag: ~Copyable & ~Escapable>` **[v1.2.0]** |
| 9 | swift-graph-primitives | `Graph.Adjacency.Extract.swift:18` | `Extract<Payload, Tag, Adjacent>` | relax `Tag` → `~Copyable & ~Escapable` **[v1.2.0]** *(Payload/Adjacent stored — keep)* |
| 10 | swift-graph-primitives | `Graph.Remappable.Remap.swift:9` | `Remap<Payload, Tag, Adjacent>` | relax `Tag` **[v1.2.0]** |
| 11 | swift-graph-primitives | `Graph.Traversal.First.Breadth.swift:14` | `Breadth<Tag, Payload, Adjacent>` | relax `Tag` **[v1.2.0]** |
| 12 | swift-graph-primitives | `Graph.Traversal.First.Depth.swift:20` | `Depth<Tag, Payload, Adjacent>` | relax `Tag` **[v1.2.0]** |
| 13 | swift-graph-primitives | `Graph.Traversal.Topological.swift:28` | `Topological<Tag, Payload, Adjacent>` | relax `Tag` **[v1.2.0]** |

Rows 2–13 are **bare** phantoms (no suppression today → both Copyable + Escapable required); rows 5–13 are the **domain-type** declarations newly covered by the v1.2.0 bare pass. In every graph type, `Tag` is the node-identity phantom (`Graph.Node<Tag> = Index<Tag>`; storage is `Tagged<Tag, Array<Payload>>`) and is **proven never a raw value package-wide** (§1.1 G-BARE grep → 0); `Payload` is the stored node value and `Adjacent` is a `Sequence` type — both **excluded** (§1.6). The many `extension Graph.Sequential where …` algorithm methods (`analyze`/`path`/`reverse`/`first`/`subgraph`/`topological<Adjacent>`) inherit `Sequential`'s relaxed `Tag` — **no separate edit**. `Graph.Default.list<Tag>()` is a func → Tier 1b (§1.4).

The nested `Index.Count` / `Index.Offset` declarations live inside Tier-1 extensions: `Index.Count` at `swift-ordinal-primitives/Ordinal.Protocol.swift:104,110`; `Index.Offset` at `swift-affine-primitives/Tagged+Affine.swift:61` (inside the `:33`/`:66` extension). Relaxing those extensions' `Tag` bound (Tier 1) widens the nested aliases automatically.

### 1.3 RELAX — Tier 1: `extension Tagged … Tag: ~Copyable` (74 sites)

Per-package file:line enumeration (complete; from G-B + G-B'):

| Package | File:lines | n |
|---------|-----------|---|
| swift-affine-primitives | `Tagged+Affine.swift:33,66,88,168,194` | 5 |
| swift-cardinal-primitives | `Tagged+Int+Cardinal.swift:18`; `Tagged+Cardinal.Add.swift:19,26`; `Tagged+Cardinal.Subtract.swift:20,27`; `Tagged+Cardinal.swift:20` | 6 |
| swift-comparison-primitives | `Comparison.Protocol+Identity.Tagged.swift:7` | 1 |
| swift-cyclic-index-primitives | `Index.Cyclic.swift:16,66,89`; `Index.Modular.swift:16,44` | 5 |
| swift-cyclic-primitives | `Tagged+Cyclic.Group.Static.Element.swift:18,43,75` | 3 |
| swift-equation-primitives | `Equation.Protocol+Tagged.swift:7` | 1 |
| swift-finite-primitives | `Index.Bounded.swift:11,40,54`; `Tagged+Ordinal.Finite.swift:11,42,61,82,107,118,134,157` | 11 |
| swift-format-primitives | `Tagged+Format.swift:16` | 1 |
| swift-hash-primitives | `Hash.Protocol+Tagged.swift:7` | 1 |
| swift-ordinal-primitives | `Tagged+Ordinal.Advance.swift:20,27`; `…Distance.swift:21,28`; `…Predecessor.swift:20,27`; `Ordinal.Protocol.swift:104`; `…Retreat.swift:20,27`; `…Successor.swift:20,27`; `Tagged+Ordinal.swift:19,31` | 13 |
| swift-path-primitives | `Tagged+Path.swift:20,36,44,73,92` | 5 |
| swift-string-primitives | `Tagged+String.Borrowed.swift:18`; `Tagged+String.swift:19,26,41,65,91` | 6 |
| swift-structured-queries-primitives | `Traits/Tagged.swift:3,5,11,17,23` | 5 |
| swift-tagged-primitives (SLI) | `Tagged+Literals.swift:45,57,67,77,87,100,110,153,174`; `Tagged+AtomicRepresentable.swift:26` | 10 |
| **swift-tagged-collection-primitives (bridge)** | `Tagged+Indexed.swift:40` *(drop the `// Escapable required: Index<Tag> demands it` comment)* | 1 **[LEAF]** |
| swift-foundations / swift-kernel | `Tagged+CPU.Atomic.Flag.swift:12` | 1 |
| **Tier 1 total** | | **75** |

### 1.4 RELAX — Tier 1b: free func/init/subscript operation sites, NAME-AGNOSTIC, suppressed `<IDENT: ~Copyable>` + bare `<IDENT>` (63 sites)

> Enumerated name-agnostically (v1.1.0 hardening, G-D′ + `/tmp/phantom-scan.py`, §1.1): any `~Copyable` generic param used **only** as a `Tagged`/`Index`/`Property` discriminator — not just params literally named `Tag`. **Bold** file:lines are the v1.1.0 additions (params named `T`/`Element`/`From`/`To`). Storage `<Element>` and pointer `<Pointee>` op-sites are **excluded** — there the param is the stored/pointed-to value type (§4, §1.6), not a pure phantom.

| Package | File:lines | n |
|---------|-----------|---|
| swift-affine-primitives | `Int+Affine.Discrete.Vector.swift:33`; `Tagged+Affine.swift:230`, **`:101,248,263,277,286`**; **`RandomAccessCollection+Tagged.Ordinal.Offset.swift:26`** | 8 |
| swift-cardinal-primitives | `Tagged+Int+Cardinal.swift:34,42,50`; **`Tagged+Cardinal.Add.swift:48,58,68`**; **`Tagged+Cardinal.Subtract.swift:43,53,63`** | 9 |
| swift-cyclic-index-primitives | `Index.Cyclic.swift:40,47,54,59` | 4 |
| swift-cyclic-primitives | `Cyclic.Group+Arithmetic.swift:120`; `Cyclic.Group.Element.swift:76`; `Cyclic.Group.Modulus.swift:59,69` | 4 |
| swift-link-primitives | `Link+Topology.swift:33,61,98,134,170,229,264`; `Link.Header.swift:24` | 8 |
| swift-memory-primitives | `Memory.Address.swift:156,170` | 2 |
| swift-ordinal-primitives | `Array+Cardinal.swift:37`; `Tagged+Int+Ordinal.swift:21,27,35`; **`Tagged+Ordinal.Advance.swift:46`**; **`Tagged+Ordinal.Distance.swift:51`**; **`Tagged+Ordinal.Predecessor.swift:44`**; **`Tagged+Ordinal.Retreat.swift:46`**; **`Tagged+Ordinal.Successor.swift:46,59`** | 10 |
| **swift-parser-primitives** *(NEW package)* | **`Parser.Error.Located.swift:59`**; **`Parser.Spanned.swift:83`** | 2 |
| swift-tree-primitives | **`Tree.Position.swift:49`** | 1 |
| swift-vector-primitives | `Index.Count+Vector.swift:36`; `Vector+Index.swift:31,62,87`; `UnsafeMutableRawBufferPointer+Index.swift:19,28,37`; `UnsafeMutableRawPointer+Index.swift:19`; `UnsafeRawBufferPointer+Index.swift:19,28`; `UnsafeRawPointer+Index.swift:19` | 11 |
| swift-dimension-primitives **(NEW pkg, v1.2.0, bare)** | **`Tagged+Arithmetic.swift:65,71,77`** (`abs`/`min`/`max<Tag, T>(Tagged<Tag, T>)` — `Tag` phantom, `T` the stored underlying) | 3 |
| swift-graph-primitives **(v1.2.0, bare)** | **`Graph.Default.list.swift:5`** (`func list<Tag>() -> Value<Graph.Adjacency.List<Tag>>`) | 1 |
| **Tier 1b total** | | **63** |

The 21 v1.1.0 additions are all in `swift-primitives` (so the "primitives primary" focus holds); the name-agnostic scan found **no** non-`Tag` phantom op-site in `swift-foundations`/`swift-standards`. Representative phantoms confirmed by read: `Tagged+Ordinal.Advance.swift:46` (`clamped<T>(by: Tagged<T,Cardinal>, to: Tagged<T,Ordinal>)`), `Tagged+Affine.swift:248` (`* <From, To>(lhs: Tagged<From,Cardinal>, rhs: Ratio<From,To>) -> Tagged<To,Cardinal>`), `RandomAccessCollection+…Offset.swift:26` (`index<T>(_:offsetBy: Tagged<T,Ordinal>.Offset)`), `Tagged+Cardinal.Add.swift:48` (`saturating<T>(_:) where Base == Tagged<T,Cardinal>`), `Parser.Error.Located.swift:59`/`Parser.Spanned.swift:83` (`init<Element>(… Index<Element>)`), `Tree.Position.swift:49` (`init<T>(index: Index<T>)`). **Excluded as stored-value** (param is the storage element / pointer pointee, used as a value — §4): `swift-storage-primitives` Heap/Inline `<Element>` (Initialize/Deinitialize/Move/Protocol), `swift-storage-split-primitives` `<Element>`, `swift-buffer-ring-primitives` `<Element>`, `swift-affine-primitives`/`swift-ordinal-primitives` `Unsafe*Pointer+…` `<Pointee>`, `swift-memory-primitives` raw-pointer `<T>`.

(`Tree.Index.swift:36` is counted in Tier 0; `Array.Fixed.Indexed.swift:23` is OUT OF SCOPE — §1.5.)

### 1.5 DELETED by the (now-complete) `.Indexed` consolidation — confirmed gone

| Package | File:line (in v1.1.0) | Status (v1.2.0) |
|---------|-----------------------|-----------------|
| swift-array-primitives | `Array.Indexed.swift:25` (`Indexed<Tag: Copyable>`) | **DELETED** — `find swift-array-primitives/Sources -name "*Indexed*.swift"` returns empty |
| swift-array-primitives | `Array.Fixed.Indexed.swift:23` (`Indexed<Tag: ~Copyable>`) | **DELETED** — confirmed gone |

v1.1.0 listed these as "doomed, do-not-relax." The `.Indexed` consumer-migration arc has since **completed**: both per-container wrappers are deleted and their consumers (graph/pool/byte-parser) migrated to the `swift-tagged-collection-primitives` bridge. Consequences for this plan: (1) nothing to relax here — the types are gone; (2) the surviving relax targets in this conceptual area are the **bridge** (`Tagged+Indexed.swift:40`, Tier 1, leaf) plus the migrated **graph** domain types (Tier 0, rows 5–13, §1.2); (3) `Array.Indexed<Tag: Copyable>` was the *one* positive phantom-marker constraint the §4 proof reasoned around — its deletion **strengthens** the non-breaking proof to zero (§4).

### 1.6 OUT OF SCOPE — stored-value parameters (the boundary, §4)

`~Copyable` on a *stored* value parameter is a different question (whether the container holds move-only/non-escapable *values*), governed by the container's value-semantics needs and the `collection-index-escapable-consumer-fallout.md` analysis — NOT this rule. Confirmed-out examples (non-exhaustive; the discriminator is "does any value of the parameter type get stored / flow through an operation?"): `Queue<Element: ~Copyable>`, `Array<Element: ~Copyable>`, `Stack<Element>`, `Slab<Element>`, `Hash.Table<Element>`, `Pool.Acquire<Resource>`, `Ownership.Unique<Value>`, `Async.Mutex<Value>`, `Iterator.Chunk<Element>`, `Link.Node<Element>`. Also out: every **concrete-tag** `Tagged<ConcreteTag, …>` *use* in `swift-foundations`/`swift-iso`/`swift-microsoft`/`swift-standards`/`swift-linux-foundation` (e.g., `Tagged<Kernel.Thread, Cardinal>`, `Tagged<ISO_9945.Kernel.User, UInt32>`, `Tagged<Darwin.Loader.Image, Ordinal>`) — concrete tags are always Copyable & Escapable, so no bound question arises; these auto-benefit when their upstream alias relaxes, with zero edits.

**Bare-pass stored-value exclusions (v1.2.0 — positively confirmed NOT phantom; relaxing any would BREAK).** The bare scan's wrapper-co-occurrence surfaced many candidates that are stored values, each excluded on read: `Graph.Sequential`'s `Payload` + every graph `Adjacent: Sequence<Graph.Node<Tag>>` (the node payload value + the adjacency sequence); `Command.Builder<Root: Sendable>` (command-root value); `Hash.Table<Element>`, `Hash.Occupied<Source>`; `Set.Ordered.Error<Element: Hash.Protocol>`, `Input.Access.Error`/`Input.Remove.Error<Element>` (error params bound to a collection's element-value domain); `Parser.Machine.{Frame,Node,…}<Input>` (the parsed-input domain); `Unsafe*BufferPointer`/`Unsafe*Pointer<Element|Pointee>`; `Machine.Program<Leaf>`; `Vector<Bound>`; all `Storage`/`Buffer.Arena`/`Slab` `<Element>`. Also excluded as **non-declarations**: `///` doc-comment examples the scanner cannot strip (`Affine.swift:43`, `Vector+Index.swift:51`, `Bit.Index.swift:17`, `Source.Location.swift:164`, `package-primitives/Package.swift:16`, the `typealias Property<Tag> = …` usage examples), `Package.swift` manifests, and concrete-namespace first-args mis-read as params (`<ISO_9945>`, `<Kernel>`, `<POSIX>`). Consumer `typealias Property<Tag> = Property_Primitives.Property<Tag, Self>` aliases (heap/stack/…) forward a *bare* `Tag`; they keep compiling after `Property` relaxes (bare ⊂ `~Copyable & ~Escapable`) and need no edit — per-consumer opt-in only.

---

## 2. Dependency-Ordered Execution Sequence

Topological from the deepest types outward. The ordering is **load-bearing for build-correctness**: a downstream op-site relaxed to `<Tag: ~Copyable & ~Escapable>` that internally constructs `Index<Tag>.Offset` will *fail to compile* unless `Index`/`Offset` already admit the wider tag (the wider `Tag` cannot flow into a still-narrow `Index<Tag>`). So upstream-first is mandatory, and the per-package build gate (§3) self-corrects any mis-ordering (a too-early package simply fails to build).

| Group | Packages (build in this order; intra-group order from each `Package.swift`) | Carries |
|-------|------------------------------------------------------------------------------|---------|
| **G1 — root + carriers** | swift-tagged-primitives (SLI Literals×9 + Atomic) → swift-cardinal-primitives → swift-ordinal-primitives *(Index.Count)* → swift-affine-primitives *(Index.Offset)* → swift-comparison-primitives, swift-equation-primitives, swift-hash-primitives | Tagged-SLI, the carriers, `Index.Count`/`Index.Offset` homes |
| **G2 — Index + Property** | swift-index-primitives *(Index.swift:38 ROOT)* → swift-property-primitives | the two foundational phantom types |
| **G3 — primitives consumers** | swift-finite-primitives, swift-cyclic-primitives, swift-cyclic-index-primitives, swift-vector-primitives, swift-link-primitives, swift-memory-primitives, swift-format-primitives, swift-path-primitives, swift-string-primitives, swift-tree-primitives, swift-structured-queries-primitives, **swift-dimension-primitives** *(`abs`/`min`/`max<Tag,T>`)* | Tier-1/1b op-sites built on Index/Ordinal/Cardinal/Affine |
| **G4 — bridge (LEAF)** | swift-tagged-collection-primitives *(`Tagged+Indexed.swift:40`)* | depends on Tagged + Collection + Index; **last in the core L1 chain** |
| **G5 — L3 foundations** | swift-foundations/swift-identities *(`Identity.ID` Domain)*, swift-foundations/swift-kernel *(`Tagged+CPU.Atomic.Flag`)* | after all L1 settle |
| **G6 — migrated consumers (v1.2.0, after the bridge)** | swift-graph-primitives *(relax 10 `Tag` sites — Tier-0 rows 5–13 + `Default.list`)* → swift-pool-primitives, swift-byte-parser-primitives *(rebuild-only — 0 relax sites)* | **downstream of the bridge leaf (G4)**: graph imports `Tagged_Collection_Primitives`, so its `Tag` relax must land AFTER the bridge admits `~Escapable` tags |

Exact intra-group order (derivable, re-run before execution):
```bash
# For any package, list its institute upstream deps to confirm it builds after them:
grep -E '\.package\(' <package>/Package.swift
```
`swift-tagged-primitives` is the deepest node (everything depends on it); its **core** `Tagged.swift` is already maximal (`Tagged.swift:55`) — only its SLI needs the relax, so G1 starts there. The bridge (G4) is the terminal leaf of the core L1 chain; foundations (G5) and the migrated consumers (G6, **new in v1.2.0**) are strictly downstream — graph in particular relaxes after the bridge because it builds on `Tagged_Collection_Primitives`.

---

## 3. Per-Package Build-Verification Gate

**Per `[PKG-BUILD-009]`: never parallel — one `swift build` at a time, foreground, read the trailing output before the next.** Per `[PKG-BUILD-010]`: on any *unexpected* failure, `rm -rf .build` first (stale-cache false-negatives are common). Per `[PKG-BUILD-004]`/`[PKG-BUILD-011]`: the default gate uses the Xcode-default Swift 6.3 toolchain (no `TOOLCHAINS`).

**Primary gate (run in each package's directory, in the §2 order):**
```bash
cd <package-dir>
swift build              # debug; compiles the relaxed bound
swift build --build-tests   # ensures test targets still typecheck against the wider bound
```
A relaxation that builds clean here is non-breaking for that package (widening only enlarges the admissible tag domain; §4).

**L1 invariant — embedded (these are L1 primitives; CI matrix per `[CI-*]` includes Embedded).** The bound change touches no embedded-sensitive surface, so this is a secondary confirmation, on 6.4-dev nightly per `[PKG-BUILD-008]`:
```bash
TOOLCHAINS=$(defaults read ~/Library/Developer/Toolchains/<nightly>.xctoolchain/Info CFBundleIdentifier) \
  swift build -Xswiftc -enable-experimental-feature -Xswiftc Embedded
```

**End-of-cascade termination criterion (per `[HANDOFF-035]`):**
1. **Workspace-wide re-grep** — re-run G-B, G-B', G-D, G-NP **and G-BARE** (§1.1). After the cascade, all must return **zero** un-relaxed phantom sites (the `Array.*.Indexed` doomed types are already deleted). Cover literal + generic-instantiated + conformance-position forms per `[HANDOFF-040]` (the G-B' multi-line grep is part of this); re-run `/tmp/phantom-scan-v3.py` and confirm the `phantom-BARE` + `phantom-supp` buckets are empty (every prior site now carries `& ~Escapable`).
2. **Ecosystem build on the CI matrix** — every touched package + every transitive consumer, on macOS Swift 6.3 (`swift build --build-tests`) AND Linux release via Docker `swift:6.3` (`[PKG-BUILD-005]`) AND 6.4-dev nightly (`swiftlang/swift:nightly-main-jammy`, `continue-on-error`) AND L1 embedded. Serial. Green across the matrix = cascade complete.

---

## 4. Risk / Edge-Case Analysis

**Claim: widening a phantom bound is non-breaking iff no site keys on the phantom's Copyable/Escapable-ness.** Verified by G-RISK (§1.1):

```
$ grep -rnE '\bTag: (Copyable|Escapable)\b' swift-primitives --include="*.swift" | grep -v '/.build/' | grep -vE '~(Copyable|Escapable)'
   (v1.2.0: NO OUTPUT — `Array.Indexed<Tag: Copyable>`, the sole v1.1.0 hit, was DELETED by the completed `.Indexed` arc)
$ grep -rnE '<Element: (Copyable|Escapable)[,>]' swift-primitives --include="*.swift" | grep -v '/.build/'
# → only DocC tutorial `Stack<Element: Copyable>` resources + Storage.Heap `callAsFunction<Element: Copyable>` — all STORED-value params, none is Index<Element>
$ grep -rnE '\bTag: (Copyable|Escapable)\b' swift-graph-primitives/Sources swift-dimension-primitives/Sources --include="*.swift" | grep -vE '~(Copyable|Escapable)'
   (v1.2.0 re-run over ALL new graph + dimension sites: NO OUTPUT)
```

**Finding (STRENGTHENED in v1.2.0):** the ecosystem now has **zero** positive phantom-marker constraints. `Array.Indexed<Tag: Copyable>` — the single one the v1.1.0 proof reasoned around — was deleted by the completed `.Indexed` arc; the risk grep re-run over every new site (graph + dimension) is empty; the remaining `<Element: Copyable>` hits are stored-container element params (none on a phantom). Therefore **no site anywhere positively requires a phantom to be Copyable or Escapable.** Widening `~Copyable` **or bare** → `~Copyable & ~Escapable` strictly enlarges the admissible tag domain; every previously-valid instantiation stays valid, and no conditional conformance, overload, or `where`-clause becomes unsatisfiable. Non-breaking, confirmed. **This is the critical safety axis for the bare pass:** relaxing a *stored* param to `~Escapable` WOULD break, which is exactly why every §1.6 exclusion is positively confirmed (used as a value → excluded), not assumed.

**Stored-value boundary (item 4, confirmed).** The verdict governs *phantom* parameters only. The G-RISK `<Element: Copyable>` hits and the §1.6 list (`Queue`/`Array`/`Stack`/…) are stored-value params: the parameter type *is* the payload, flows through storage/operations, and its Copyable/Escapable-ness is a real value-semantics requirement — out of scope. Discriminator: *does any value of the parameter type get stored or flow through an operation?* No → phantom → relax; Yes → stored → leave to the container's own value-semantics decision.

**Edge cases.**
- **`Identity.ID<Domain, RawValue>` (foundations):** `Domain` is the phantom (relax to `~Copyable & ~Escapable`); `RawValue` is the *stored* Underlying — currently bare (Copyable & Escapable required), narrower than `Tagged`'s `Underlying: ~Copyable & ~Escapable`. Relaxing `RawValue` is a separate stored-value decision (does `ID` wrap move-only/non-escapable values?); flagged, NOT in this cascade.
- **Consumer `typealias Property<Tag> = Property_Primitives.Property<Tag, Self>`** (container packages, DocC-illustrated): these forward a bare `Tag`. After Property's `Tag` widens, a bare forwarded `Tag` still satisfies the wider bound → non-breaking, **no change required**. Widening consumer aliases is per-consumer opt-in to *use* a `~Escapable` tag — outside this cascade.
- **`swift-structured-queries-primitives` / `swift-format-primitives`** conditional conformances (`QueryExpression`, `BinaryFloatingPoint`): `Tag` is the phantom; relaxing it does not touch the `Underlying`-keyed conformance condition → safe.

---

## 5. Cross-Arc Coordination

### 5a. The `.Indexed` consolidation / consumer-migration arc

Per `project_indexed_wrapper_consolidation` (memory) and `swift-array-primitives` commit `45d0a5a`: the per-container `*.Indexed<Tag>` wrappers were replaced by the `swift-tagged-collection-primitives` bridge. **This arc has COMPLETED (verified 2026-06-01):** `Array.Indexed`/`Array.Fixed.Indexed` are deleted (`find … -name "*Indexed*.swift"` → empty), and graph/pool/byte-parser are migrated (importing `Tagged_Collection_Primitives`) with **clean, editable** working trees. The v1.1.0 "held for another agent" exclusion is **dropped** — these packages are now in scope (graph carries the 10 bare-phantom relax sites of §1.2/§1.4; pool/byte-parser are rebuild-only).

**Reconciliation (which `.Indexed` sites survive vs are removed):**
- `Array.Indexed.swift:25` + `Array.Fixed.Indexed.swift:23` → **DELETED**, confirmed gone (§1.5). Nothing to relax.
- `Dictionary.Ordered.Indexed.swift` is **not** a wrapper (live `key(at:)`/`value(at:)` accessors, misnamed) — already out of scope, no relax.
- The **bridge** `Tagged+Indexed.swift:40` (`Tag: ~Copyable`) is the *surviving* relax target (Tier 1, G4 leaf). Its bound is a downstream symptom of `Index`'s narrow bound; it relaxes naturally once `Index` (G2) lands.

**Sequencing:** arc (a) is done, so there is no live coordination constraint. **graph/pool/byte-parser are now in scope (editable).** graph carries 10 bare-phantom `Tag` relax sites (Tier-0 rows 5–13 + `Default.list`) and is **downstream of the bridge leaf** (it imports `Tagged_Collection_Primitives`), so it relaxes in **G6** — after the bridge (G4) admits `~Escapable` tags. pool/byte-parser have **0** relax sites (they consume `Tagged<concrete-tag, …>`); they only rebuild in G6 to confirm the upstream relax is transparent.

### 5b. The `swift-array-primitives` Collection.Protocol / Iterable arc

The Collection.Protocol/Iterable relaxation has **settled** (HEAD commit `9c226f5`, "Relax Array/Array.Fixed Iterable + Memory.Contiguous.Protocol to ~Copyable (Piece 7a / D4)"; working tree clean). **`swift-array-primitives` is NOT in this cascade's relax inventory** — its only former phantom-bound sites were the now-deleted `Array.*.Indexed` (§1.5). No file collision and no remaining hold. Re-confirm quiescence (`git -C swift-primitives/swift-array-primitives status -s` empty) before executing G6, since array-primitives is upstream of the migrated consumers.

---

## 6. Skill Codification Plan

**Provenance (`[SKILL-LIFE-002]`):** `phantom-parameter-suppressed-protocol-bound.md` (RECOMMENDATION) + this plan. **Classification (`[SKILL-LIFE-003]`):** **Additive** — a new requirement governing future phantom-parameter declarations; existing code is brought into compliance by this cascade, but the *rule* adds rather than breaks. **Routing:** author via `skill-lifecycle` (not directly); `[SKILL-LIFE-001]` minimal-revision; `[SKILL-CREATE-012]` ID-uniqueness grep across the full `code-surface` skill before fixing the ID; `[SKILL-CREATE-013]` keep any description edits route-focused.

**Home:** `code-surface`, as a sibling to the phantom-type *naming* rules `[API-NAME-010]` / `[API-NAME-010a]` (which already govern phantom tags). `[API-NAME-010b]` is the natural next ID — confirm free via `grep -nE '^### \[API-NAME-010' Skills/code-surface/SKILL.md` before assigning. **`conversions` `[IDX-001]`** (which currently reproduces the `~Copyable`-only bound verbatim) gets a minimal cross-reference update to cite the new rule.

**Draft rule text:**

> **[API-NAME-010b] — Maximal Suppression on Phantom Parameters.** A generic type parameter that is *phantom* — never stored as a value and never flowing through any operation; a pure compile-time discriminator — MUST be bound `~Copyable & ~Escapable`, whether it is **bare** today (`<Tag>`, no suppression → both required) or partially suppressed (`<Tag: ~Copyable>`). This applies uniformly to (a) the `Tagged`/`Index`/`Property` infrastructure (the `Tag` of `Tagged`/`Property`, the `Element` of `Index`) AND (b) **domain-type declarations** whose phantom is a discriminator — e.g. `Graph.Sequential<Tag, Payload>` / `Graph.Adjacency.List<Tag>` (node-identity `Tag`), `Identity.ID<Domain, RawValue>` (`Domain`). A non-suppressed marker-protocol requirement (`Copyable` and/or `Escapable`) on a phantom parameter is forbidden as vacuous over-constraint: by Reynolds parametricity the implementation witnesses no capability of a phantom, so the requirement shrinks the admissible domain while enabling nothing. The rule does NOT apply to *stored* value parameters (`Queue<Element>`, `Array<Element>`, `Graph.Sequential`'s `Payload`, the `Underlying`/`Base`/`RawValue`/`Adjacent` of a wrapper), whose suppression follows the container's value-semantics needs — and relaxing such a param to `~Escapable` is a *breaking* error. Discriminator: *does any value of the parameter type get stored or flow through an operation?* No → phantom (this rule); Yes → stored (out of scope).
>
> *Provenance:* `phantom-parameter-suppressed-protocol-bound.md`, `phantom-parameter-bound-cascade-implementation-plan.md`. *Cross-references:* `[API-NAME-010]`, `[API-NAME-010a]` (phantom-type naming), `[IDX-001]` (Index = Tagged<Element, Ordinal>), `[MEM-LIFE-001]`.

**Mechanisation follow-on (`lint-rule-promotion`, `[PROMOTE-*]`):** candidate AST rule — flag a `typealias`/`struct`/`enum` generic parameter that is provably phantom (appears only in a `Tagged<P, …>` / `Property<P, …>` / `Index<P>` position, never in a stored-property type) yet whose bound lacks `& ~Escapable`. Deferred to a separate `/promote-rule` cycle after the text rule lands and the cascade provides ground-truth fixtures.

---

## 7. Status

**EXECUTED 2026-06-01.** Run G1→G6 with the §3 per-package 6.3 build gate and the §3/[HANDOFF-035] termination scan (G-B/G-D/G-NP/G-RISK + `/tmp/phantom-scan-v3.py`). The G-RISK non-breaking invariant held throughout (zero production sites positively require a phantom's Copyable/Escapable-ness).

**Committed — 22 packages (swift-primitives + swift-foundations), all main-green on Swift 6.3.2; index/property/tree additionally embedded-confirmed on the 6.5-dev nightly (the installed `nightly-main` rolled 6.4→6.5-dev):**
- **G1** — tagged-primitives `d3caae5`, cardinal `335e064`, ordinal `0d33fe8`, affine `8d4bdfb`, comparison `0484243`, equation `3b23647`
- **G2** — index `0699658`, property `caee49d`
- **G3** — tree `45c2d62`+`087ffa3`, finite `006a34f`, cyclic `2647c85`, cyclic-index `a806edd`, vector `fc8c937`, memory `6ed3651`, format `18a348b`, path `b1376c6`, string `250f569`, structured-queries `e7c5d89`, dimension `03f2510`, parser `6fa86a6`
- **G4** — bridge (tagged-collection) `5502d6f` [LEAF]
- **G6** — graph `38e98c8`; pool / byte-parser rebuild-verified transparent (0 relax sites)

**Codification:** skill `[API-NAME-010b]` Maximal Suppression on Phantom Parameters + `[IDX-001]` update — `swift-institute/Skills` `6c1ede6`. Advisory lint `Lint.Rule.Naming.PhantomSuppression` (`.warning`, conservative, NOT bundled — pending Stage-3 validation+gating) — `swift-institute-linter-rules` `fa4a89a`; outcome record `swift-institute/Audits/PROMOTE-API-NAME-010b-2026-06-01.md` `05f568d`.

**Build-gate findings beyond the plan:** the bridge (Tier-1) was relaxed ahead of graph (§2 G4→G6); the gate then surfaced the full chain graph needs — `Index.Count`/`Index.Offset` (ordinal/affine), the `Ordinal.Protocol.Domain` phantom associatedtype, the `Ratio<From,To>` declaration, and conditional-conformance suppression restatements (`extension Property/Graph.Sequential: Copyable/Sendable where Tag: ~Copyable & ~Escapable`). Several stale-mirror/`.build` skews (storage-split, ordinal-in-linter-rules) were cleared with `rm -rf .build` per `[PKG-BUILD-010]`.

**Deliberate non-relax (NOT a phantom over-constraint):** `swift-hash-primitives/.../Hash.Protocol+Tagged.swift:7` stays `Tag: ~Copyable` — `Hash.Protocol: Swift.Hashable`, and `Swift.Hashable` requires Escapable on Swift <6.4; the conformance is `#if swift(<6.4)`-gated and excluded on 6.4+ (SE-0499 makes it automatic). The Escapable requirement is load-bearing.

**Deferred — uncommitted, source relaxed + main-green where checkable, blocked by *unrelated* in-flight-arc baselines:** `swift-link-primitives` (relax applied, main green; its own tests have an `Index(__unchecked:(),Ordinal())` vs `Index.Offset` overload-resolution regression under the wider bound — needs a test-construction fix); `swift-foundations/swift-kernel` (relax applied; blocked by a `swift-iso-9945 Memory.Map.Region` L2 API skew); `swift-foundations/swift-identities` (`Identity.ID` Domain relax applied; blocked by a pre-existing `swift-rfc-4122 RFC_4122.UUID` typed-throws baseline error).

**Acceptable non-breaking residue** (conservatively-deferred under-included candidates the plan never enumerated + §1.6 stored-value exclusions; all build at status-quo): property-primitives sub-type op-sites (Property.Borrow/Inout/Consume/Typed bare `<Tag>`), heap-primitives ×5 consumer `typealias Property<Tag>` aliases (auto-benefit), affine `Ratio+Tagged`/`+QuotientAndRemainder`/`+Composition` ext op-sites, §1.6 stored params (Hash.Table/Occupied, Input/Set.Ordered errors, Parser.Machine `<Input>`, pointers, Machine.Program), non-institute domain types (CSS/SVG/File.Path), doc-comment/manifest false-reads.

**Not pushed** — all commits are local; bulk-push of ~24 repos is a separate authorization ([HANDOFF-023]).

## References

- **Decision:** `swift-institute/Research/phantom-parameter-suppressed-protocol-bound.md` (RECOMMENDATION v1.0.0) — the verdict this plan implements.
- **Prior art (extended per `[HANDOFF-013]`):** `swift-institute/Research/phantom-typed-value-wrappers-literature-study.md` (RECOMMENDATION v1.0.0, Tier 3) — phantom Tag never affects the substructural classification (S3, soundness #5); `protocol-abstraction-for-phantom-typed-wrappers.md`; `collection-index-escapable-consumer-fallout.md` (DECISION v1.3.0, the value-index a-fortiori predecessor); `byte-protocol-capability-marker.md`.
- **Governing rules:** `[ARCH-LAYER-008]` + `feedback_correctness_and_evergreen` (correctness sole driver; demand excluded); `[PKG-BUILD-004]`/`[PKG-BUILD-009]`/`[PKG-BUILD-010]`/`[PKG-BUILD-011]`/`[PKG-BUILD-008]` (build gates, embedded); `[HANDOFF-035]`/`[HANDOFF-040]` (cascade termination + generic-instantiated/conformance-position grep coverage); `[SKILL-LIFE-001/002/003]`, `[SKILL-CREATE-012/013]` (codification); `[IDX-001]`, `[API-NAME-010]`/`[API-NAME-010a]`, `[MEM-LIFE-001]`.
- **In-flight arcs:** `project_indexed_wrapper_consolidation` (memory); `swift-array-primitives` commits `45d0a5a`, `9c226f5`.
- **Enumeration:** all greps §1.1, run 2026-06-01, Apple Swift 6.3.2 / arm64, from `/Users/coen/Developer`.
```
