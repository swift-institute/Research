# `~Copyable RFC_8259.Value` Cascade — Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-05-20
status: RECOMMENDATION
tier: 2
---
-->

## Status

**RECOMMENDATION** — Path B (the `~Copyable RFC_8259.Value` cascade) is
**structurally feasible at the language level** but **practically expensive**
at the migration level. Three independent constraints raise the cost
materially beyond the back-of-envelope LoC estimate:

1. Stdlib `Array<Element>` does NOT accept `Element: ~Copyable` in the
   current toolchain (Swift 6.3+). Production `RFC_8259.Array._storage:
   [Value]` and `RFC_8259.Object._storage: [(key, value)]` therefore CANNOT
   remain as stdlib Array; both must swap to `Buffer<Value>.Linear` from
   `swift-buffer-primitives`. This is a hard structural constraint, NOT a
   migration-ergonomics one.
2. Five conformances on `RFC_8259.Value` break: `Sendable`, `Hashable`,
   `Coder_Primitives.Codable` (associatedtype Coder), `ExpressibleByLiteral`
   family (6 conformances), `CustomStringConvertible`. Each requires either
   redesign (Sendable lost; Hashable → SE-0499 borrowing-Hash.Protocol) or
   ownership-aware rewrite (literals require `init` body that constructs
   `~Copyable`; CustomStringConvertible's `var description: String { get }`
   requires `borrowing` on a `~Copyable` extension — sustainable, but each
   literal becomes a constructed-then-consumed value).
3. The downstream public-API blast radius extends past swift-rfc-8259 into
   swift-foundations/swift-json (the `JSON` wrapper at
   `swift-foundations/swift-json/Sources/JSON/JSON.swift:60-70` stores `raw:
   RFC_8259.Value` — JSON itself must become `~Copyable`), plus
   swift-foundations/swift-tests (snapshot redaction passes `RFC_8259.Value`
   by value, mutates, returns).

Verdict for the canada-perf next-arc decision: **Path B is NOT the
appropriate first move.** A targeted intervention strictly inside the
tree-emit phase (the source of the residual ~233 ms) is cheaper and more
likely to validate or refute the structural-cost premise of the canada
anomaly. Path B remains the documented option for a future arc with a
concrete second consumer asking for sub-microsecond JSON traversal at
larger object sizes OR with an empirical demonstration that a localised
tree-emit fix is insufficient.

## Context

Today (2026-05-20) the swift-foundations/swift-json bench harness at
commit `590f38c` confirmed that ~233 ms of canada.json parse time
post-Patches-1/2/3 sits in the tree-emit phase, NOT in float parsing
(~1 % of total). One candidate fix is to make `RFC_8259.Value` `~Copyable`
so that arena-backed storage doesn't require materialisation at the
public API boundary AND the refcount-per-Copyable-extract trap (which
killed `swift-foundations/swift-json/Research/value-tree-redesign-v2.md`'s
L1 at small N) is structurally avoided.

The v2 arc's §12 disposition refuted **Copyable-wrapper storage swap**:

> The cost dominant in both regressions is **refcount per Object copy on
> `case .object(let o) = raw` extract**. Every JSON traversal step does
> this extract; Object holds the storage as a stored property; the
> storage's refcount(s) get incremented (and later decremented) on each
> copy.

The L1 regression was caused by `let o = raw.object` extracting Object
**by value** (Copyable wrapper), incurring refcount overhead on the
multi-buffer storage that overwhelmed the algorithmic O(1) gain at
mean N=2.

The `~Copyable Value` cascade restructures the extract differently:
`switch self { case .object(let o): ... }` becomes a **borrowing** bind
(or consuming, depending on call shape), with NO refcount fire. The L1
trap structurally cannot apply.

Whether this is enough to close the canada anomaly's ~233 ms tree-emit
wedge is an EMPIRICAL question — this doc establishes structural
feasibility for the cascade. The companion arc would measure.

## Prior research

Per [HANDOFF-013] / [RES-019], grepped the workspace's Research/ corpus
for noncopyable-value, value-tree, and arena-tree prior art:

| Source | Status | Relation |
|---|---|---|
| `swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0 | SUPERSEDED-BY-EVIDENCE | Closest prior arc. L1 (Copyable-wrapper + multi-buffer storage swap) refuted empirically at canonical workload. §3 enumerated L2 (~Copyable Value cascade) as a future option requiring (a) second hot consumer asking for sub-microsecond traversal, AND (b) `Buffer.Arena: Copyable when Element: Copyable` landed (per `buffer-arena-conditional-copyable.md` v1.1.0). This doc revisits L2 with structural validation now that canada-perf has surfaced as a second-consumer candidate. |
| `swift-foundations/swift-json/Research/parse-performance-architecture.md` v1.0.2 §5 | DECISION (Phase B conditional) | Phase B (arena tree) explicitly deferred behind a re-open clause for tree-shape-dominated workloads. Canada-perf's tree-emit wedge is plausibly that workload. |
| `swift-institute/Research/buffer-arena-conditional-copyable.md` v1.1.0 | RECOMMENDATION (Option A) | Constrains arena-backed Value storage: a `Copyable Value`-emitting arena requires Option A (Storage.Arena ManagedBuffer subclass) to land first. NOT a constraint on `~Copyable Value` cascade — that path uses `Memory.Arena` directly (already ~Copyable) without conditional-Copyable buffer. |
| `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md` v1.1.0 | (today's anomaly arc) | Identifies the residual ~233 ms tree-emit wedge that motivated this feasibility doc. |

No prior research doc on the workspace directly addresses **structural
feasibility of `~Copyable RFC_8259.Value`**. This doc fills that gap.

## Consumer-site inventory

Per [HANDOFF-040] enumeration (literal `RFC_8259.Value` AND generic /
position-aware forms — `Value`, `Value<`, `: Value`, `, Value`, payload
extract patterns).

### swift-rfc-8259 (origin package — 65 sites across 4 files)

| File | Sites | Category |
|---|---:|---|
| `Sources/RFC 8259/RFC_8259.Value.swift` | 30+ | (b) Copyable-dependent — enum declaration with `Sendable, Hashable`; 6 ExpressibleByLiteral conformances; CustomStringConvertible (`var description: String { get }`); `from<T>(_:transform:)` static factory; type-accessor properties returning `T?` by value (`var object: RFC_8259.Object?`, `var array: RFC_8259.Array?`, `var number: RFC_8259.Number?`). Every accessor signature breaks. |
| `Sources/RFC 8259/RFC_8259.Object.swift` | 20+ | (b) Copyable-dependent — `_storage: [(key: String, value: Value)]` (stdlib Array, breaks); Sequence + Collection conformance (must become OwnedSequence/OwnedCollection variants); subscript setter `mutating set` works but getter returning `Value?` becomes `borrowing`-projection. Hashable + Equatable lost on Value require redesign per SE-0499 borrowing variants. |
| `Sources/RFC 8259/RFC_8259.Array.swift` | 10+ | (b) Copyable-dependent — `_storage: [Value]` (stdlib Array, breaks); RandomAccessCollection / MutableCollection / RangeReplaceableCollection — none of which currently support `~Copyable Element`. Must redesign. |
| `Tests/RFC 8259 Tests/RFC 8259 Spec Tests.swift` | 5 | (b) Copyable-dependent — assertion patterns rely on Equatable. |

### swift-foundations/swift-json (primary consumer — 92 sites across 12 files)

| File | Sites | Category |
|---|---:|---|
| `Sources/JSON/JSON.swift` | 7 | (b) — `internal var raw: RFC_8259.Value` is the entire JSON wrapper's storage; `JSON` itself becomes `~Copyable`. `@dynamicMemberLookup` subscript returning `JSON` by value breaks (must become projection). `var array: [JSON]?` / `var object: [(key, value: JSON)]?` / `var dictionary: [String: JSON]?` all materialise Copyable Arrays/Dictionaries — all break. |
| `Sources/JSON/JSON.Decode.Implementation.swift` | 15 | (a) Mostly trivially migratable — already builds Value tree by `return .array(...)` / `return .object(...)` patterns. The internal `var elements: [RFC_8259.Value] = []` accumulator (line 197) and `var members: [(key: String, value: RFC_8259.Value)] = []` (line 252) break (stdlib Array). Build path moves to `Buffer<Value>.Linear` + `Buffer<(String, Value)>.Linear` accumulators. |
| `Sources/JSON/JSON.Assemble.swift` | 10 | (a)→(b) — Build paths identical to Decode.Implementation. The `Lexer.Pull.Assemble.Strategy` conformance's `Value` associated type breaks if the cohort assumes Copyable (worth verifying at swift-lexer-primitives). |
| `Sources/JSON/JSON.Coder.swift` | 8 | (b) Copyable + Sendable-dependent — `extension RFC_8259.Value: @retroactive Coder_Primitives.Codable` requires the `Codable` protocol to admit `~Copyable Self`. Coder.Protocol's `Output = RFC_8259.Value` slot must be `~Copyable`-compatible; verify against swift-coder-primitives. |
| `Sources/JSON/JSON.Encode.Encoder.swift` | 3 | (b) — `encode(_ value: RFC_8259.Value, ...)` and `encodeArray(_ array: RFC_8259.Array, ...)` / `encodeObject(_ object: RFC_8259.Object, ...)` take by-value; must take `borrowing`. The `for element in array { ... }` iteration at line 241 needs an OwnedSequence iterator. |
| `Sources/JSON/JSON.Encode.swift` | 2 | (a) Trivially migratable to `borrowing`. |
| `Sources/JSON/JSON.Encode.Size.swift` | 3 | (b) — `public let value: RFC_8259.Value` stored property breaks; must store `~Copyable` (forces Size to be `~Copyable` too). |
| `Sources/JSON/JSON.Serializable.swift` | 5 | (b) — protocol `Serializable { static func serialize(_:) -> JSON; static func deserialize(_ json: JSON) -> Self }` both signatures break (JSON now `~Copyable`). `deserialize(events:)` survives. `static var json: JSON` survives if Self is the consuming-source. ~30 stdlib conformances (Int, String, Bool, etc.) all need their `serialize`/`deserialize` rewritten. |
| `Sources/JSON/JSON.Literals.swift` | 4 | (b) — 4 ExpressibleByLiteral conformances at JSON wrapper level; same rewriting cost. |
| `Sources/JSON/JSON.Span.EventStream.swift` | 1 | (a) Trivially migratable — already ~Copyable; just calls into `RFC_8259.Number` returning paths. |
| `Sources/JSON/JSON.Pull.Stream+Payload.swift` | 8 | (a) Trivially migratable — operates on `RFC_8259.Number` (which is independent of Value's ~Copyable status; Number stays Copyable). |
| `Sources/JSON/JSON.Decode.swift` | 12 | (b) — every public parse entry returns `RFC_8259.Value` by value. Must become consuming-init pattern OR project through a borrowing-accessor wrapper. |
| `Tests/JSON Tests/Encoder Tests.swift` | 17 | (b) — every test uses `let value: RFC_8259.Value = <literal>` then passes by value to encoder. Tests need rewriting around the new ownership model. |
| `Tests/JSON Tests/JSON.Coder.Protocol Tests.swift` | 3 | (b) — `let expected: RFC_8259.Value = true` literal pattern. |
| `Tests/JSON Tests/RFC 8259 Conformance Tests.swift` | (uncounted) | (b) — broad conformance suite; rewriting cost proportional to surface. |

### swift-foundations/swift-tests (consumer — 3 files, ~30 sites)

| File | Sites | Category |
|---|---:|---|
| `Sources/Tests Snapshot/RFC_8259.Value+TreeKeyed.swift` | 7 | (b) — Tree<RFC_8259.Value>.Keyed builds a generic tree; tree currently requires Copyable element. The function `_jsonToKeyedTree(_ value: RFC_8259.Value) -> Tree<RFC_8259.Value>.Keyed<String>` takes by value, recursively walks via Object.makeIterator (pending Object's redesign), Array's RandomAccessCollection. Significant rewrite if Tree<~Copyable> isn't supported by swift-tree-primitives. |
| `Sources/Tests Snapshot/Test.Snapshot.Redaction+JSON.swift` | 20+ | (b) — Redaction recursively rebuilds `RFC_8259.Value` from a path; takes value, returns value. Function signature `_redactPath(_ value: RFC_8259.Value, replacement: RFC_8259.Value) -> RFC_8259.Value` is fundamentally Copyable-shaped. Rewrite cost: high. |
| `Sources/Tests Snapshot/Test.Snapshot.Diffing+Structural.swift` | 1 | (a) — single Tree-construction call site. |

### Downstream consumers (no direct RFC_8259.Value sites)

`swift-foundations/swift-manifests`, `swift-foundations/swift-linter`,
`swift-foundations/swift-impact`, `swift-foundations/swift-json-feed`,
`swift-standards/swift-json-feed-standard`, `coenttb/swift-syndication`,
`coenttb/swift-json-feed`, and `swift-primitives/swift-lexer-primitives`
all route exclusively through `JSON.Serializable`. Their migration cost
is **(a) trivially migratable**: they don't see RFC_8259.Value directly;
they conform to JSON.Serializable. If JSON.Serializable's signatures
adapt to `~Copyable JSON` (`static func serialize(_ value: Self) -> JSON`
becomes `static func serialize(_ value: Self) -> JSON` where JSON is
`~Copyable`, requiring the static method to construct-then-consume), the
downstream conformers' implementation bodies need light auditing for
copy patterns but no large rewrite.

`coenttb/*` workspace search returned zero direct `RFC_8259.Value`
references — all JSON consumption goes through the `JSON` wrapper and
`JSON.Serializable`.

### Category-rollup

| Category | Sites (approx) | Notes |
|---|---:|---|
| **(a) Trivially migratable** — borrowing-friendly, no by-value storage | **~35** | Most of JSON.Decode.Implementation's parse paths, JSON.Pull.Stream+Payload's Number paths, JSON.Encode.swift's top-level dispatchers, Diffing+Structural, downstream JSON.Serializable conformers. |
| **(b) Copyable-dependent** — stores by value in Copyable container, returns by value, or relies on Sendable/Hashable | **~165** | Object/Array `_storage: [Value]`, JSON wrapper's `raw`, all literal conformances, CustomStringConvertible, the Tree<Value>.Keyed paths in swift-tests, every test fixture using `let value: RFC_8259.Value = ...`. |
| **(c) Sendable/Hashable-dependent (no Copyable behavior actually needed)** | **~25** | `RFC_8259.Value: Sendable, Hashable` declaration consumers (concurrency-bound or set-membership patterns). Probably re-expressible via SE-0499 `Hash.Protocol` borrowing variant. |

The (a)/(b)/(c) split is dominated by (b) at roughly **75 % of sites**.
The mechanical rewrite cost is therefore not "small wrapper retype" but
"systematic ownership-aware redesign across the JSON layer."

## Spike

`/Users/coen/Developer/swift-ietf/swift-rfc-8259/Experiments/noncopyable-value-spike/`
— minimal sandbox package. Defines a 6-case `~Copyable Val` enum
(`null` / `bool` / `number` / `string` / `array(IndirectBox)` /
`object(String, IndirectBox)`) plus a borrowing `depth()` accessor. The
class-`IndirectBox` stand-in for multi-element ~Copyable storage isolates
the central-feasibility questions from the Buffer<Val>.Linear redesign.

### Spike result: GREEN (with three structural caveats)

`swift build` clean (5/7 steps), `swift run` produces:

```
noncopyable-value-spike — Q1+Q2 GREEN (tree depth: 2)
noncopyable-value-spike — Q4 sanity GREEN (Memory.Arena compose)
decomposed: object
noncopyable-value-spike — END
noncopyable-value-spike — Q3 RED (stdlib Array<Val> not supported; see file header)
```

Confirmed structurally:

- **Q1** — 6-case `~Copyable` enum with two `~Copyable`-payload cases
  declares and constructs cleanly. ✓
- **Q2** — `borrowing func depth() -> Int` + `switch self { case .x: }`
  inspection compiles; recursive borrowing through a class-payload
  reference (the IndirectBox) works. ✓
- **Q4** — `Memory.Arena` (also `~Copyable`) compose at the type level
  is sanity-clean; allocate-then-reset-then-drop runs. ✓ (Does NOT
  exercise arena-allocated slot install for Val payloads — that's a
  Storage.Arena-level concern outside this spike.)

Refuted by the spike:

- **Q3 RED — stdlib `Array<Element>` does NOT accept `Element: ~Copyable`.**
  Compiler diagnostics:

  ```
  error: 'Array' requires that 'Val' conform to 'Copyable'
  error: tuple with noncopyable element type 'Val' is not supported
  error: cannot infer contextual base in reference to member 'number'
         (knock-on from the Array constraint)
  ```

  This is the **central blocker** for a cheap cascade. Production
  `RFC_8259.Array._storage: [Value]` (line 32) and
  `RFC_8259.Object._storage: [(key: String, value: Value)]` (line 24)
  CANNOT survive as stdlib Array; both must swap to
  `Buffer<Value>.Linear` from `swift-buffer-primitives`. This brings
  swift-buffer-primitives into swift-rfc-8259's dep graph (currently 6
  deps; adds one — within range but structural).

Additional structural constraints discovered through spike iteration:

- Multi-pattern case labels (`case .null, .bool, .number:`) are NOT
  implemented for `~Copyable` switch. The cascade's switch statements
  across the codebase must expand to one case per arm. Mechanical, but
  cosmetic regression — adds ~150 lines across the codebase.
- Top-level `consume` of global `~Copyable let` bindings is NOT
  supported. Globals must be re-scoped into function bodies or made
  `var` with explicit consume points. Not pervasive in production
  (`RFC_8259.Value` is rarely declared at file scope) but a known
  ergonomic constraint.

## Migration cost estimate

| Phase | Scope | Conservative LoC | Honest LoC | Risk |
|---|---|---:|---:|---|
| **1. Spike** | Done — 165 LoC sandbox | — | — | DONE |
| **2. Storage swap** | `RFC_8259.Array._storage: [Value]` → `Buffer<Value>.Linear`; `RFC_8259.Object._storage` → paired-buffer or `[(String, Value)]` analog. Add `swift-buffer-primitives` dep. | 200 | 400 | M — verify Buffer.Linear's iteration / mutation contract matches today's RandomAccessCollection/RangeReplaceableCollection semantics |
| **3. Value enum** | `RFC_8259.Value: ~Copyable`; drop Sendable + Hashable + Equatable; drop 6 ExpressibleByLiteral conformances; rewrite CustomStringConvertible as `borrowing func`; rewrite type-accessor properties as `borrowing` projections (`borrowing var object: ... ?` is not yet syntax — must be `borrowing func asObject() -> ...?` or similar) | 150 | 350 | H — projection accessor API is a public-API break for every consumer reading `value.object?.foo` |
| **4. JSON.Decode.Implementation + Assemble** | Internal accumulators swap; consuming return; build paths re-thread | 200 | 400 | L — entirely internal |
| **5. JSON wrapper** (`JSON.swift`) | `struct JSON: ~Copyable`; dynamic-member-lookup subscripts return `JSON` projections (borrowing-style); `var array: [JSON]?` etc. break completely (Array<~Copyable> still unsupported — must remove or replace with consuming iteration accessor) | 200 | 500 | **VERY HIGH** — this is swift-json's core public API; the `let cached = json.user.name` ergonomic that the README sells breaks |
| **6. JSON.Encode.Encoder** | All `RFC_8259.Value` parameters become `borrowing`; iteration becomes OwnedSequence; sortKeys path's `object.sorted(by:)` breaks (Array<~Copyable> doesn't sort). | 100 | 250 | M |
| **7. JSON.Coder + Coder_Primitives.Codable conformance** | Verify Codable + Coder.Protocol admit `~Copyable Output`. If not, this becomes blocking upstream work. | 50 | 200 (+upstream arc if blocked) | **CRITICAL DEPENDENCY** — Codable's associatedtype slot's Copyability is the gating constraint |
| **8. JSON.Serializable** | `serialize(_:) -> JSON` and `deserialize(_:) -> Self` both signatures change; ~30 stdlib conformances at the bottom of the file each need rewriting | 100 | 400 | M — mechanical but spans every conformer |
| **9. JSON.Literals + JSON.swift literal/factories** | 4 ExpressibleByLiteral conformances on JSON, 6 on RFC_8259.Value, all factory methods (`.bool(_:)`, `.array(_:)`, etc.) — every literal site becomes a consuming-construction | 100 | 250 | L — mechanical |
| **10. swift-tests snapshot Tree+Redaction** | Tree<RFC_8259.Value>.Keyed must support `~Copyable Value` (likely upstream blocker on swift-tree-primitives); _redactPath signature fundamentally rewrites | 100 | 400 (+upstream arc) | **HIGH** — possibly upstream-blocked |
| **11. Test suite** | ~50 tests across swift-json/Tests + swift-rfc-8259/Tests use `let value: RFC_8259.Value = literal`; rewrite around ownership model | 200 | 500 | L — mechanical |
| **12. Downstream sweep** | 8+ packages with JSON.Serializable conformances; light audit | 50 | 150 | L |
| **Total (conservative)** | 4 packages × ~12 phases | **~1450** | **~3800** | mixed |

**Realistic LoC: 3 800–5 000 across 3 primary packages + 1 upstream
constraint + 1 likely upstream blocker (swift-tree-primitives' ~Copyable
support).** This aligns with value-tree-redesign-v2.md §3 L2's original
"Very high — ~3000–5000 LoC" estimate; the spike confirms the architecture
docs' intuition was correct.

**Critical blockers to verify before committing to migration**:

1. `Coder_Primitives.Codable` admits `~Copyable Self`. If not — upstream arc.
2. `swift-tree-primitives.Tree<Element>` admits `Element: ~Copyable`. If not — upstream arc OR rewrite swift-tests redaction without Tree.
3. `swift-lexer-primitives.Lexer.Pull.Assemble.Strategy.Value` admits `~Copyable`. If not — upstream arc.

These three dependencies probably exist; this doc does NOT verify them
empirically. If even one is blocked, the migration is doubly expensive.

## Key structural risks

| Risk | Severity | Mitigation |
|---|---|---|
| `Sendable` on RFC_8259.Value lost — JSON.parse.prepared() etc. break | HIGH | Acknowledge break; document the API contract change. Concurrent JSON consumers must transfer via `consuming` or rebuild via re-parse. Real impact depends on downstream parallel-parse usage; coenttb/* survey shows zero parallel parsers. |
| `Hashable` on RFC_8259.Value lost — Set<JSON> / Dictionary<JSON, …> break | LOW | SE-0499's `Hash.Protocol` borrowing variant restores hashability for ~Copyable types. Conform to it instead. |
| `Coder_Primitives.Codable` retroactive conformance + canonical-attachment | CRITICAL | Verify Coder_Primitives admits ~Copyable Output; if blocked, the cascade halts here. |
| `JSON.dictionary: [String: JSON]?` accessor in `JSON.swift:182-189` — fundamentally Copyable | HIGH | Deprecate this accessor; document migration to OwnedSequence-style iteration. Cosmetic break for downstream code that walks dictionary entries imperatively. |
| `JSON.array: [JSON]?` accessor returning `Array<~Copyable>` | CRITICAL | Same — Array<~Copyable> not supported; must remove. Consumers migrate to consuming iteration. |
| `ExpressibleByDictionaryLiteral` and friends — variadic `(String, Value)...` | CRITICAL | Variadic ~Copyable arguments not supported. Literal conformances must drop. JSON literal ergonomics (`["name": "John"]`) breaks for JSON itself; can be replaced with a builder function but is a usability regression. |
| `dynamic-member-lookup` chain — `json.user.name.string` — each step is a by-value subscript today | HIGH | Each subscript becomes a borrowing projection. Chained access may force the consumer to bind intermediates as `let-borrowed`; the chain's terminal `.string` returning `String?` works fine. The 95 % case (terminal scalar extraction) survives; the 5 % case (storing intermediates) breaks. |
| `RFC_8259.Number` ALSO becomes ~Copyable indirectly | MEDIUM | Number itself is small + Copyable. The cascade only ~Copyable-izes Value; Number stays Copyable. Verify: yes — Number is a stored let property in `.number(Num)`, and the consume happens at the Value layer. |
| `borrowing var property: T?` syntax not yet implemented | HIGH (ergonomic) | Replaced with `borrowing func asProperty() -> T?` or `func property(_:) -> T?`. Every accessor pattern shifts to function-call. Public-API break of medium magnitude. |
| Downstream Swift compiler defects | MEDIUM | The spike surfaced 2 known-but-tracked constraints (multi-pattern case labels; global `consume`). Production migration may surface more. Project_known_graph_test_runtime_crash memory shows this class of issue is live in the toolchain. |

## Recommendation for the canada-perf next-arc decision

**Do NOT pursue Path B as the next arc.**

The structural feasibility is GREEN, but the ~4 000 LoC migration cost
across 3 packages + 3 critical upstream dependencies is not commensurate
with the **unverified** premise that ~Copyable Value will close the
~233 ms tree-emit wedge. The v2 disposition's mechanism (refcount per
`case .object(let o)` extract) is plausibly load-bearing on canada-perf,
but UN-MEASURED at the cascade's full granularity.

Cheaper alternatives that should be exhausted first:

1. **Localised tree-emit profiling on the canada workload.** Run the
   bench harness with allocation-tracing under both the wholesale parser
   path and the event-stream path; identify whether the ~233 ms is
   refcount-bound (cascade would help), allocation-bound (cascade
   helps via arena), or string-conversion-bound (cascade orthogonal).
   This is the empirical premise-check that's missing from the brief.
2. **Targeted Buffer<RFC_8259.Value>.Linear inside parseObject/parseArray
   accumulators** without rolling the cascade to public API. Internal-only
   storage swap; preserves `RFC_8259.Value` Copyability; tests whether
   the wedge is in tree-build or tree-emit. Cheap (~100 LoC); informative.
3. **Pre-sized String construction in lexStringValue** — the
   `String(unsafeUninitializedCapacity:)` path in
   `JSON.Decode.Implementation.swift:428` is already optimised but
   canada's string-heavy shape may have a sub-millisecond per-string
   cost that compounds. Localised intervention.

If interventions (1)+(2)+(3) close the wedge — Path B stays parked. If
they don't — Path B becomes the necessary next arc, this doc becomes its
design entry point, and the ~4000 LoC migration is justified by
empirical evidence (a class-(c) ecosystem-cost decision per the
collaboration protocol).

## Out of scope

- This doc does NOT propose an L2 migration. It documents structural
  feasibility + costs to inform the next-arc decision.
- The arena-allocated slot install for `~Copyable Val` payloads (the
  full Storage.Arena<Val>-style allocator) is OUT OF SCOPE; deferred
  until Path B is selected.
- Validation of Coder_Primitives.Codable's ~Copyable-Output support is
  OUT OF SCOPE; would be done in Phase 0 of a Path B arc.
- Validation of swift-tree-primitives.Tree<~Copyable> support is OUT OF
  SCOPE; same.

## References

### Spike
- `swift-ietf/swift-rfc-8259/Experiments/noncopyable-value-spike/` —
  165 LoC sandbox; ~Copyable Val + IndirectBox + Memory.Arena compose
  sanity probe; builds clean on Swift 6.3+; runs to completion.

### Production current-surface (RFC_8259.Value)
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Value.swift:30-49` —
  Value enum declaration with Sendable + Hashable.
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Object.swift:21-37` —
  Object struct with `_storage: [(String, Value)]` (stdlib Array breaks
  on ~Copyable cascade).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Array.swift:29-43` —
  Array struct with `_storage: [Value]` (stdlib Array breaks).
- `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Number.swift:21-43` —
  Number stays Copyable; not affected by Value's ~Copyable status.

### Production current-surface (JSON layer)
- `swift-foundations/swift-json/Sources/JSON/JSON.swift:60-70` — JSON
  wrapper stores `raw: RFC_8259.Value`; becomes ~Copyable.
- `swift-foundations/swift-json/Sources/JSON/JSON.swift:166-189` —
  `array: [JSON]?` / `object: [(key, value: JSON)]?` /
  `dictionary: [String: JSON]?` — all materialise Array<~Copyable>
  which doesn't exist.
- `swift-foundations/swift-json/Sources/JSON/JSON.Decode.Implementation.swift:197,252` —
  Internal accumulators use stdlib Array.
- `swift-foundations/swift-json/Sources/JSON/JSON.Assemble.swift:102,163` —
  Same.
- `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:125-140` —
  `extension RFC_8259.Value: @retroactive Coder_Primitives.Codable`
  with `typealias Coder = JSON.Coder` — load-bearing retroactive
  conformance.
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:97-132` —
  Serializable protocol with `serialize(_:) -> JSON` /
  `deserialize(_ json: JSON) -> Self`.

### swift-tests consumer
- `swift-foundations/swift-tests/Sources/Tests Snapshot/RFC_8259.Value+TreeKeyed.swift` —
  Tree<RFC_8259.Value>.Keyed integration.
- `swift-foundations/swift-tests/Sources/Tests Snapshot/Test.Snapshot.Redaction+JSON.swift` —
  Value rebuild-by-path patterns.

### Prior research
- `swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0
  (SUPERSEDED-BY-EVIDENCE) — L1 (Copyable-wrapper storage swap) refuted
  empirically; §3 L2 (~Copyable Value cascade) flagged as future option.
- `swift-foundations/swift-json/Research/parse-performance-architecture.md`
  v1.0.2 §5 — Phase B (arena tree) conditional clause; canada-perf may
  trigger it.
- `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md`
  v1.1.0 — Today's anomaly arc.
- `swift-institute/Research/buffer-arena-conditional-copyable.md` v1.1.0 —
  Buffer.Arena conditional-Copyable constraint; orthogonal to ~Copyable
  cascade (which uses Memory.Arena directly).

### Skill references
- [API-NAME-001] — Namespace structure preserved (`RFC_8259.Value`).
- [API-ERR-001] — Typed throws preserved on all surfaces.
- [API-IMPL-005] — One type per file preserved.
- [ARCH-LAYER-001] — Dependency direction: swift-rfc-8259 (L2) gains
  swift-buffer-primitives (L1) dep; layer-consistent.
- [PRIM-FOUND-001] / [ARCH-LAYER-007] — Foundation-free preserved.
- [MEM-COPY-001] — Explicit ~Copyable declaration on Value enum.
- [MEM-OWN-*] — Borrowing / consuming annotations across the cascade.
- [HANDOFF-013] / [RES-019] — Prior-research grep performed (see §"Prior research").
- [HANDOFF-040] — Consumer-site enumeration grep performed (literal +
  generic-instantiated forms; see §"Consumer-site inventory").
- [RES-018] — Consumer-demand thresholds. Per `feedback_correctness_and_evergreen.md`,
  this is NOT the gating consideration for ~Copyable adoption; structural
  correctness drives. The recommendation against Path B as next-arc is
  driven by **migration cost not yet commensurate with measured wedge**,
  NOT by consumer-demand thresholds.
- [EXP-003] — Spike package conventions followed (sandbox under
  Experiments/, single executable target, path-based dep).
- [BENCH-010] — Bench-driven decision; this doc explicitly defers the
  Path B selection to post-measurement of the canada wedge's true
  composition.

## Provenance

2026-05-20 sub-agent dispatch for Path B feasibility validation
following the canada-perf microbench landing (commit 590f38c) confirming
~233 ms of canada parse time in tree-emit. Scope: structural feasibility
+ consumer-site inventory + cost estimate; recommendation for next-arc
decision. Spike confirmed Q1+Q2+Q4 green, Q3 red (stdlib Array<~Copyable>
unsupported). Verdict: feasible but not the right next-arc; localised
tree-emit profiling + targeted Buffer<Value>.Linear in parser accumulators
should run first as the cheaper premise check.
