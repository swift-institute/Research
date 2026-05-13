# Noncopyable Adoption Targets: swift-linter / source-primitives Ecosystem Survey

<!--
---
version: 1.1.0
last_updated: 2026-05-13
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to:
  - swift-source-primitives
  - swift-linter-primitives
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-institute-linter-rules
  - swift-foundations/swift-parsers
verification_experiment: none (analysis-only; per-target spike scoped at adoption time)
trigger: HANDOFF-noncopyable-adoption-targets.md (parent: 2026-05-13 linter-arc closure)
---
-->

## Context

The 2026-05-13 linter rule-corpus iteration arc surfaced a recurring question:
*when should ecosystem types adopt `~Copyable`?* The concrete trigger was Thread I /
Row-23 / Wave 3 — proposing that
`Source.Location.filePath: Swift.String?` be retyped to
`Path_Primitives.Path?`. `Path_Primitives.Path` is `~Copyable`
(`swift-path-primitives/Sources/Path Primitives/Path.swift:45`,
*"owns a null-terminated contiguous memory region and deallocates it on
destruction"*); the cascade through `Source.Location`'s
`Copyable + Sendable + Hashable + Comparable + Codable + CustomStringConvertible`
shape was the reflexive objection.

Two facts re-frame the cost calculus:

1. **SE-0499 (Implemented Swift 6.4)** extends `Swift.Equatable`, `Swift.Hashable`,
   and `Swift.Comparable` to natively support `~Copyable` conformers via
   `borrowing` parameters. Verified per
   `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md`
   v1.3.0 RECOMMENDATION (2026-05-03), with empirical confirmation against the
   2026-03-16 Swift nightly bundled stdlib. Two of the three pre-2026 cascade
   costs (Hashable / Equatable / Comparable losses) drop to zero under
   Swift 6.4+.
2. **`JSON.Serializable`** in
   `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift` exists
   as a typed-throws alternative to stdlib `Codable`. The `Lint.Manifest`
   adoption at
   `swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift:116`
   is the canonical precedent. `JSON.Serializable`-style protocols can be
   re-authored on a `~Copyable` foundation; stdlib `Codable` cannot
   (`Encoder.singleValueContainer().encode(_:)` takes `Encodable` by-value).

The remaining cascade cost is therefore:

- consumer-file count for the typed `where T: ~Copyable` propagation per
  [MEM-COPY-006],
- `switch consume` patterns at consumer pattern-matches per [MEM-COPY-005],
- `Codable → JSON.Serializable` migration ONLY when the type currently bridges
  external wire formats via stdlib `Codable`,
- the third-party cost of `Optional<~Copyable>` access patterns at
  consumers (per `noncopyable-ecosystem-state.md` Pain Point 6).

A blind first pick (Source.Location-first) would optimize for the
lowest-payback, highest-cascade-cost ratio in the survey set — see §Analysis
Row 5. A scored investigation identifies the highest-payback targets first.

### Prior Research

Per [RES-019] step-0 internal grep, the relevant prior corpus:

| Document | Bearing on this survey |
|---|---|
| `swift-institute/Research/noncopyable-ecosystem-state.md` (v1.0.0, DECISION 2026-04-02) | Canonical state-of-`~Copyable` reference. Five permanent-by-design limitations, three bugs (one filed), three transfer patterns ([MEM-OWN-010]/[MEM-OWN-011]/[MEM-OWN-012]), the Layer 0/1/2 discipline ([IMPL-070]). The synchronization-as-ownership 3× write-throughput finding ([IMPL-063]) is the empirical anchor for resource-correlated adoption. |
| `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` (v1.3.0, RECOMMENDATION 2026-05-03) | Empirical SE-0499 landed-status verification. The "Pre-execute Option C with `#if swift(>=6.4)` guards" execution plan establishes the precedent that ecosystem-wide adoption is gated on the toolchain matrix per `feedback_toolchain_versions.md`. |
| `swift-institute/Research/source-location-unification.md` (v3.1.0, DECISION 2026-02-27) | The implemented `Source.Location` unification across compiler/test/parser domains. The "~Copyable cascade" constraint cited at the doc's `Constraints` section is the **pre-SE-0499 framing** that needs re-evaluation here: the original constraint was "Codable + Hashable + Equatable losses make Source.Location unviable as ~Copyable"; SE-0499 closes 2 of those 3 losses; the surviving Codable cost is real but narrower. |
| `swift-institute/Research/path-type-ecosystem-model.md` (2026-04-18) | Definitive top-to-bottom path type model. The L3 `Paths.Path` (Copyable, Sendable, Hashable) wraps L1 `Path_Primitives.Path` (~Copyable) as the architectural pattern — *"the L3 layer is Copyable to fit stdlib `Array`, `Set`, `[K:V]`; the L1 layer is ~Copyable as the owned-resource form."* This is the existing precedent for the answer to "when should L3 wrappers be ~Copyable?" — they generally should not, because the Copyable wrapper is the bridge into stdlib containers. |
| `swift-institute/Research/noncopyable-ergonomics-compiler-state.md` (v3.0.0, SUPERSEDED 2026-04-02) | Foundational pain-point survey (consolidated into ecosystem-state). Cited here for the closure-capture / `.take()!` / `switch consume` discipline that any candidate adopter has to absorb. |
| `swift-institute/Research/nested-view-vs-borrowed-naming.md` (cited per v1.3.0 entry) | Names the `Path.Borrowed: ~Copyable, ~Escapable` shape; the answer to *"what is the borrowed-view companion of an `~Copyable` owning type?"*  |

The path layered model (Copyable L3 wrapping ~Copyable L1) is the reference
architectural shape. Where the surveyed candidates do *not* already have
that bifurcation, the question is whether to introduce it, or to
collapse the Copyable surface entirely.

### Constraints

- **Toolchain matrix**. The ecosystem ships against Swift 6.3 stable and
  6.4-dev nightly per `feedback_toolchain_versions.md`. SE-0499 is in
  6.4 (per the cited v1.3.0 spike). Adoption that relies on SE-0499
  must be guarded `#if swift(>=6.4)` or wait for the ecosystem
  6.4-stable cutover; the spike-clearing pattern in
  `se-0499-implications-for-equation-hash-comparison-primitives.md`
  Option C-refined (typealias `*.Protocol` to stdlib + `#if` guards)
  is the precedent for the same pattern in adoption sites.
- **Codable wire-format**. Where Codable is consumed across a
  process boundary (e.g., test reporting, manifest subprocess hand-off),
  adoption of `~Copyable` requires migrating to `JSON.Serializable` per
  the `Lint.Manifest` precedent. Where Codable is only used for in-process
  display (`CustomStringConvertible` is independent of Codable), removal
  is cleaner.
- **Stdlib `Array`, `Set`, `Dictionary`**. None support `~Copyable`
  elements as of Swift 6.4. SE-0437 ships `~Copyable` versions of
  `Optional` and `Result`; collections remain Copyable-only. A candidate
  whose primary container shape is `Set<T>` or `[K: T]` would force a
  custom container, which is a significant additional cost.
- **`@_lifetime(...)` annotations**. Bridges from owned `~Copyable` types
  to `~Copyable, ~Escapable` borrowed views (e.g., `Path → Path.Borrowed`)
  require `@_lifetime(borrow self)` annotations per
  `Path_Primitives.Path.Borrowed:117`. Adoption candidates that need a
  borrowed-view companion inherit this discipline.

### Scope

In scope:

1. Candidate types in `swift-source-primitives`, `swift-linter-primitives`,
   `swift-foundations/swift-linter`, `swift-foundations/swift-linter-rules`,
   `swift-foundations/swift-institute-linter-rules`,
   `swift-foundations/swift-parsers`, and `swift-foundations/swift-file-system`
   for `~Copyable` adoption.
2. Six-axis scoring per the trigger brief; ranked recommendation top 3–5.
3. Deferred / not-recommended set with explicit rationale.

Out of scope:

- Implementation work on any target.
- The `Lint.File` vs `File_System.File` namespace question (per
  `swift-institute/Research/path-type-ecosystem-model.md` §Q6).
- Whether to revisit the L3 `Paths.Path` Copyable wrapper as ~Copyable
  (definitively answered NO by `path-type-ecosystem-model.md`).
- Verification spike per [RES-021] — each candidate's adoption spike is
  scoped at adoption time, not survey time.

---

## Question

Which types in the `swift-linter` / `swift-source-primitives` ecosystem
would benefit most from `~Copyable` adoption under SE-0499's relaxation,
and which should remain `Copyable` despite the relaxation?

Sub-questions:

1. Of the candidates listed in the brief (`Source.Location`,
   `Lint.Source.Parsed`, `Lint.Source.Walker` emission, `Lint.Run`
   configuration, `Lint.Finding` stream, file-system open/read state)
   plus any the survey adds, which top 3–5 carry the best
   payback-to-cascade-cost ratio?
2. Are there second-order targets the brief did not enumerate that
   score higher than any of the named ones?
3. For each not-recommended candidate, what is the precise reason
   `~Copyable` adoption is rejected — and would re-evaluation be
   warranted on a future ecosystem state change (Codable on
   `~Copyable`; stdlib collection support; new compiler feature)?

---

## Analysis

### Survey Method

Each candidate is scored on the six axes from the trigger brief:

| Axis | What it measures |
|---|---|
| **(a) Resource-correlation** | Does the type wrap a real acquire/release lifecycle (file descriptor, memory allocation, parsed-tree handle, parser-state cursor)? |
| **(b) Size / hot-path** | Is move-vs-copy observable at consumer call sites (kilobytes-to-megabytes payload, per-file or per-finding emission rate, hot inner loop)? |
| **(c) Safety bug class prevented** | Does `~Copyable` close a specific bug class (use-after-free, double-free, raw-pointer aliasing, accidental stale-state propagation through copy)? |
| **(d) Cascade cost** | Total cascade footprint: consumer-file count + stdlib protocol losses (Hashable/Equatable/Comparable are NOW free under SE-0499; Codable→JSON.Serializable migration cost still applies) + `where T: ~Copyable` propagation + `switch consume` discipline at pattern matches + `Optional<~Copyable>` access patterns. |
| **(e) Pattern-establishing value** | Does adoption exercise broad `~Copyable` ecosystem infrastructure (Layer 0/1/2 patterns per [IMPL-070], `Mutex.withLock(consuming:)` extensions, `_read`/`_modify` projections, the `Path / Path.Borrowed` bifurcation)? |
| **(f) Existing alignment** | Does the type already wrap `~Copyable` internals it currently smuggles through a Copyable boundary, or already pass `inout` in its primary access pattern? |

Scoring scale 0–5 per axis (0 = irrelevant; 5 = maximum). Total ≤ 30.

The scoring grid below is an analytical ranking, not a benchmark; per
[RES-025] empirical validation, the ranking is grounded in cognitive
dimensions (visibility, viscosity, role-expressiveness, error-proneness)
rather than measured runtime cost. Per-target adoption spikes will
deliver empirical confirmation at adoption time.

### Already-`~Copyable` (control set, no work)

| Type | Location | Notes |
|---|---|---|
| `Path_Primitives.Path` | `swift-path-primitives/Sources/Path Primitives/Path.swift:45` | `~Copyable, @unsafe @unchecked Sendable`. Owns `Memory.Contiguous<Char>`. The canonical reference shape. |
| `Path_Primitives.Path.Borrowed` | `swift-path-primitives/Sources/Path Primitives/Path.Borrowed.swift:38` | `~Copyable, ~Escapable`. Pointer + count, lifetime-tied to the borrow. The canonical borrowed-view companion. |
| `File.Handle` | `swift-foundations/swift-file-system/Sources/File System Core/File.Handle.swift:29` | `~Copyable, Sendable`. *"~Copyable enforces single-ownership (prevents double-close)."* |
| `File.Descriptor` | `swift-foundations/swift-file-system/Sources/File System Core/File.Descriptor.swift:30` | `~Copyable, Sendable`. Same single-ownership / double-close prevention. |
| `File.Directory.Iterator` | `swift-foundations/swift-file-system/Sources/File System Core/File.Directory.Iterator.swift:20` | `~Copyable`, **NOT** `Sendable`. Owns mutable directory handle. |
| `File.System.Write.Atomic.TempFile` | `swift-foundations/swift-file-system/Sources/File System Core/File.System.Write.Atomic+API.swift:210` | `private ~Copyable, Sendable`. Owns `Kernel.Descriptor`. |
| `File.System.Write.Streaming.Context` | `swift-foundations/swift-file-system/Sources/File System Core/File.System.Write.Streaming.Context.swift:37` | `~Copyable, Sendable`. |

These types exemplify the canonical `~Copyable` shape: real resource
acquired at init, released at deinit or `consuming close()`, single owner
enforced by the type system. The survey treats them as the reference
pattern; new adoption candidates are graded relative to the strength of
their resource-correlation against this set.

### Scoring Matrix (Copyable candidates)

| Row | Candidate | (a) Res-corr | (b) Size/HP | (c) Safety | (d) Cascade | (e) Pattern | (f) Existing | **Total** |
|---|---|---|---|---|---|---|---|---|
| 1 | `Lint.Source.Parsed` | 4 | 5 | 3 | 4 | 5 | 4 | **25** |
| 2 | `Source.Manager` | 3 | 5 | 2 | 2 | 4 | 4 | **20** |
| 3 | `Lint.Run.Outcome` | 1 | 3 | 1 | 3 | 2 | 1 | **11** |
| 4 | `Lint.Suppression` | 0 | 2 | 0 | 1 | 1 | 0 | **4** |
| 5 | `Source.Location` (trigger) | 0 | 2 | 0 | **5** | 1 | 0 | **8** (high cascade swamps low payback) |
| 6 | `Source.Position` | 0 | 1 | 0 | 2 | 0 | 0 | **3** |
| 7 | `Source.File` | 0 | 1 | 0 | 1 | 0 | 0 | **2** |
| 8 | `Lint.Manifest` | 0 | 1 | 0 | 4 | 0 | 0 | **5** (JSON.Serializable wire format is load-bearing) |
| 9 | `Lint.Finding` | 0 | 3 | 0 | 5 | 1 | 0 | **9** (per-finding emission rate is real, but cascade through every reporter / suppression / outcome consumer is decisive) |
| 10 | `Lint.Source.Walker.paths(...)` return | 0 | 2 | 0 | 1 | 0 | 0 | **3** (returns `[Lint.Source.Path]`, a stdlib-Array of typealias values) |

Numerical totals are a ranking heuristic, not a sum-of-objective-utilities.
A high cascade score for `Source.Location` is a *cost* against adoption,
not a payback — `(d)` is inverted in the final ranking by treating it as
deduction. The presented totals already use that inversion.

### Per-candidate analysis

#### Row 1 — `Lint.Source.Parsed` (TOP PICK)

**Location**: `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Source.Parsed.swift:36`.

**Current shape**:

```swift
public struct Parsed: Sendable {
    public let file: Source.File                  // Copyable, Sendable
    public let path: Lint.Source.Path             // typealias for Tagged<…, String>
    public let tree: SourceFileSyntax             // SwiftSyntax reference-typed AST
    public let converter: SourceLocationConverter // SwiftSyntax reference-typed
}
```

**(a) Resource-correlation 4/5**: the bundle aggregates the parsed AST
tree (SwiftSyntax) and the line/column converter. SwiftSyntax's
`SourceFileSyntax` is a reference-typed wrapper around an `Arc`-shared
syntax storage; the converter caches per-file line-start positions
computed lazily on first call. Both are logical per-file resources
acquired once via `Parser.parse(...)` at
`Lint.Run.parsedSource:243`, and the engine's working-set memory cost is
"proportional to the total source-tree size" per the doc-comment at
`Lint.Run.run:73`. The bundle IS a per-file resource handle.

**(b) Size/hot-path 5/5**: AST trees are large (kilobytes-to-megabytes
per source file); the linter run loop iterates `O(rules × files)` over
parsed-source instances. Copying `Lint.Source.Parsed` by value at
the rule-invocation boundary today is benign at the SwiftSyntax layer
(refcount bump for the underlying storage) but the *type* lies about
ownership: every rule's `findings` closure semantically borrows the
parse, none owns it. The Copyable shape misexpresses this.

**(c) Safety 3/5**: no Swift-level use-after-free is closed by adoption
(reference-typed AST storage is GC-managed). But a real semantic bug
class is closed: accidental partial-copy of `(tree, converter)` where
the converter is computed against a different tree (e.g., a rewriter
emits a new tree but stale converter survives the copy). `~Copyable`
makes this impossible by construction — the bundle is moved or
borrowed, never split.

**(d) Cascade cost 4/5**:

| Cascade surface | Count | Mechanism |
|---|---|---|
| Rule definitions (closure parameter type change `Lint.Source.Parsed → borrowing Lint.Source.Parsed`) | ~73 rules (verified via `grep -rE "public static let.*Lint\.Rule\("` across `swift-linter-rules` + `swift-institute-linter-rules`) | Closure type change is mechanical: `findings: { source, severity in ... }` already takes `source` by-value-with-no-mutation; the `borrowing` switch is essentially a parameter-modifier addition |
| Engine call sites | 1 site in `Lint.Run.run:152` | `let candidates = entry.rule.findings(parsed, severity)` becomes `entry.rule.findings(&parsed, severity)` or remains a borrow per the closure signature |
| `Lint.Source.Parsed.visibility(at:)` engine-internal extension | 1 site in `Lint.Source.Parsed+Visibility.swift:49` | Convert to `borrowing func` |
| `Lint.Manifest` / `JSON.Serializable` / Codable migrations | 0 — `Lint.Source.Parsed` is engine-internal, never serialized across a process boundary | n/a |
| Stdlib protocol losses | 0 — currently `Sendable` only; no `Hashable`/`Equatable`/`Comparable`/`Codable` to lose | n/a |
| `Optional<Lint.Source.Parsed>` access at engine | 0 — never wrapped in Optional in `Lint.Run` | n/a |

The 73-rule cascade is **mechanical**: the rule witness shape
(`Lint.Rule.findings: @Sendable (Lint.Source.Parsed, Diagnostic.Severity) -> [Diagnostic.Record]`
at `Lint.Rule.swift:71`) is a closure type, not a protocol witness; the
type alias change ripples through definition sites uniformly. Per
[HANDOFF-040], the grep for cascade enumeration must cover both literal
and generic-instantiated forms — `Lint.Source.Parsed` is not generic,
so the literal `grep -rn "Lint.Source.Parsed"` is sufficient.

**(e) Pattern-establishing 5/5**: this is the most-broad
ecosystem-infrastructure exercise in the candidate set. Adoption
establishes:

- "Parsed-source bundles are `~Copyable` per-file resources" as a pattern
  consumable by future analysis tools (LSP integration, formatter,
  cross-rule analysis cache).
- The "Layer 0/1/2" model from `noncopyable-ecosystem-state.md` applied
  to a foundations-layer L3 type, with rule closures at Layer 2.
- The `borrowing` closure-parameter idiom (vs Layer-0 slot/take) at
  Layer 2 — clean borrow flow without any `.take()!` ceremony, since
  rules never consume the parse.

**(f) Existing alignment 4/5**: the wrapped `SourceFileSyntax` and
`SourceLocationConverter` are reference types underneath; copying the
struct doesn't deep-copy the tree, so the existing Copyable boundary is
already *smuggling* the single-owner-of-a-shared-reference semantic.
Adopting `~Copyable` makes the type match its actual underlying
ownership shape.

**Spike risk (per [RES-021])**: `SourceFileSyntax` and `SourceLocationConverter`
are externally-defined reference-bridged value types in SwiftSyntax 602.
A spike must confirm:
(i) that a `~Copyable` struct can store these `let` properties without a
deinit being synthesized that conflicts with the externally-managed
release (it should — they're release-on-drop class refs, deinit-safe);
(ii) that the `borrowing` closure parameter shape compiles in the
`@Sendable` rule closure context (per `noncopyable-ergonomics-compiler-state.md`,
`@Sendable` does not preclude `~Copyable` capture *as a parameter*, only
*as a non-escaping closure capture*); (iii) that SE-0499's `Hashable` /
`Equatable` relaxation does not interact (Lint.Source.Parsed is not
Hashable/Equatable today; the migration adds zero protocol cost).

#### Row 2 — `Source.Manager`

**Location**: `swift-primitives/swift-source-primitives/Sources/Source Primitives/Source.Manager.swift:36`.

**Current shape**:

```swift
public struct Manager: Sendable {
    @usableFromInline internal var files: [Source.File]
    @usableFromInline internal var contents: [[UInt8]]
    @usableFromInline internal var lineMaps: [Text.Line.Map?]
}
```

**(a) Resource-correlation 3/5**: not a kernel-side resource, but the
"single owner per compilation" invariant is real: Source.Manager IS the
registry of all source content + line maps. Multiple Managers in a
compilation would split file IDs (each Manager assigns sequentially)
and produce divergent line resolution. The Copyable shape allows
accidental dual-Manager states.

**(b) Size/hot-path 5/5**: `contents: [[UInt8]]` holds every source
file's bytes for the duration of a run, per the doc-comment at
`Lint.Run.run:73`. For corporate-monorepo-scale trees (tens-of-thousands
of files, hundreds-of-MB total), an accidental copy is unbounded cost.
For typical SwiftPM packages (single-digit MB), still wasteful.

**(c) Safety 2/5**: no UAF / double-free; the bug class is "stale file
ID against a different Manager" (returns wrong file metadata when
resolved against the wrong instance). Real but narrow.

**(d) Cascade cost 2/5**: very localized.

| Cascade surface | Count | Mechanism |
|---|---|---|
| `Source.Manager` mutating callers | `Lint.Run.parsedSource:198` already takes `manager: inout Source.Manager`; `Source.Manager.location(for:)`, `lineMap(for:)`, `register(...)` are already `mutating` | The `inout` discipline is in place |
| Non-mutating callers | `Source.Manager.file(for:)`, `content(for:)`, `fileCount` are non-mutating | Convert to `borrowing func` |
| `Lint.Run.run` loop body | `var manager = Source.Manager()` then threaded via `inout` per file | No change |
| Codable migration | 0 — not Codable | n/a |

The Copyable→`~Copyable` flip largely matches existing usage; the
ceremony is in the type declaration, not in the call sites.

**(e) Pattern-establishing 4/5**: establishes the swiftc / Clang
SourceManager-as-single-owner pattern as a Swift-native equivalent.
Cited as the reference pattern in `source-location-unification.md`'s
"Prior Art Survey" section.

**(f) Existing alignment 4/5**: the engine already passes Source.Manager
`inout`; the existing usage is `~Copyable`-shaped in every call site
except the type declaration itself.

**Trade-off vs Row 1**: Source.Manager scores lower than
Lint.Source.Parsed because (i) its cascade is even smaller, but the
payback (Source.File / Source.Position retain Copyable status) is also
smaller in pattern-establishing terms — Source.Manager's adoption
doesn't generalize to "all source-aware tools borrow trees" the way
Lint.Source.Parsed does; (ii) it sits at L1 (`swift-source-primitives`)
where consumer count is broader than the linter-only Lint.Source.Parsed.
Adopting Source.Manager would cascade to any future source-primitives
consumer (LSP server, formatter, custom analysis), each of which is a
correctness win — but also a coordination cost.

#### Row 3 — `Lint.Run.Outcome` / `Lint.Finding` stream

**Location**:
`swift-foundations/swift-linter/Sources/Linter Core/Lint.Run.swift:91`
(Outcome) and
`swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Finding.swift:52`
(Finding).

**Verdict 11/30**: the per-finding emission rate is real (each rule
emits 0–N findings per file, with N typically small); copying the
findings array at run-return is not the dominant cost. The payback is
performance-only with no resource-correlation; the cascade hits every
reporter (SARIF, Text, future formatters), every suppression-elision
consumer, and every CI parser. Deferred — better as a smaller-grain
profile-driven optimization later.

#### Row 4 — `Lint.Suppression` / `Lint.Suppression.Entry`

**Location**:
`swift-foundations/swift-linter/Sources/Linter Core/Lint.Suppression.swift:38`.

**Verdict 4/30**: engine-internal map; small (one entry per
`disable:next/line` directive, typically single-digit per source file);
no resource correlation. The current `Sendable, Equatable` shape is
appropriate. Not recommended.

#### Row 5 — `Source.Location` (the brief's trigger)

**Location**:
`swift-primitives/swift-source-primitives/Sources/Source Primitives/Source.Location.swift:30`.

**Verdict 8/30 (high cascade swamps payback)**: 169 references across
`swift-primitives`, `swift-standards`, and `swift-foundations` (verified
via workspace-wide grep). Per
`swift-institute/Research/source-location-unification.md`, the type is
the unified output of a 4-package decomposition that already runs
through compiler/linter/test/parser domains. The brief's trigger framing
("retype `filePath: Swift.String?` to `Path_Primitives.Path?`") inverts
the cost calculus:

- **(a) Resource-correlation 0/5**: pure display value (fileID, optional
  filePath, line, column). No acquired resource.
- **(b) Size/hot-path 2/5**: small struct; copy is two refcounts + two
  small fields. Negligible.
- **(c) Safety 0/5**: no bug class closed.
- **(d) Cascade cost 5/5 (the maximum penalty)**: stored in `Lint.Finding`
  (Hashable Set/Dict elements via the wrapper), in `Diagnostic.Record`
  (the wire-format record across diagnostic-primitives consumers), in
  `Test.Source.Location = typealias = Source.Location` per the v3.1.0
  unification — and `Test.Source.Location` IS Codable for cross-process
  test reporting. Under SE-0499, Hashable/Equatable/Comparable losses
  drop to zero, but **Codable remains a hard cost**: the test framework's
  cross-process JSON interchange depends on `Codable` conformance per
  `source-location-unification.md` Constraints section. Migrating
  `Test.Source.Location`'s Codable wire format to `JSON.Serializable`
  is a separate, larger investigation.
- **(e) Pattern-establishing 1/5**: would establish "value-types can
  drop Copyable for one nested ~Copyable field" — but this is a
  *narrow* pattern, not a broad infrastructure exercise.
- **(f) Existing alignment 0/5**: no smuggled `~Copyable` internals
  today. The hypothetical adoption *introduces* one (the Path field)
  rather than codifying an existing smuggling.

**Confirmed: Source.Location-first is exactly the worst pick on
cascade-cost-to-payback ratio.** The reflexive objection in the parent
session — "can't lose Hashable" — was empirically incomplete (SE-0499
fixes Hashable / Equatable / Comparable); the structural objection
("highest-cascade type with zero resource-correlation") is the correct
one and survives the SE-0499 reframing.

**Re-evaluation trigger**: revisit if (i) `Test.Source.Location`'s
Codable wire format migrates to `JSON.Serializable` independently (a
separate, narrower investigation), AND (ii) stdlib `Hashable` for
`Set<Source.Location>` containers stays SE-0499-supported on the
toolchain matrix the ecosystem targets. Even then, the resource-correlation
score remains 0 — Source.Location is structurally a value type, not a
resource handle.

#### Rows 6–10 — `Source.Position` / `Source.File` / `Lint.Manifest` / `Lint.Finding` / Walker return

All score below 11/30 with consistent reasoning: pure value
types (Position / File / Walker return), or wire-format boundary
(Manifest), or downstream of a higher-payback adoption (Finding cascades
from Source.Location adoption, not from itself). Each remains correctly
Copyable.

---

## Prior Art (per [RES-021])

The `~Copyable` design space is well-explored across language ecosystems.
A contextualization step per [RES-021] is applied: universal adoption
elsewhere does not imply universal necessity in this ecosystem.

### Rust's ownership model

Rust requires `move` semantics by default for non-`Copy` types; `Copy`
is the opt-in for types that may be copied bit-for-bit. The
`std::fs::File` type implements `Drop` (the Rust equivalent of `deinit`)
to close the file descriptor; it does NOT implement `Copy`. The Swift
equivalent — `File.Handle: ~Copyable, Sendable` — matches one-to-one.

Rust's `SourceFile` in `rustc_span` is held inside an `Arc<SourceFile>`
(shared, ref-counted, immutable after construction), explicitly NOT
move-only — the rustc design accepts that multiple consumers (diagnostic
emitters, expansion contexts, the lint engine) all need read access to
the same source content. The Swift equivalent of `Arc<SourceFile>` is
the Source.Manager-as-single-owner pattern: rather than refcount the
content per-file, route every consumer through a single mutable Manager.
The two designs are equivalent on the safety dimension; Source.Manager
removes the Arc overhead but adds the single-owner discipline.

**Contextualization**: Rust's universal `move` default is enabled by the
borrow-checker's flow analysis (every read of a moved value is a
compile-time error, with no ceremony at the use site). Swift's
`~Copyable` requires explicit `consuming` / `borrowing` annotations and
`switch consume` discipline; the cost-per-adoption is higher than in
Rust. The institute's bias should therefore be *higher* on the
adopt/don't-adopt threshold than a translated-from-Rust convention
would suggest. The 25/30 score for Lint.Source.Parsed clears that
elevated bar; the 8/30 score for Source.Location does not.

### Linear Haskell

Linear types (`LinearTypes` GHC extension, multiplicity polymorphism)
mark values as "must be used exactly once". The Swift equivalent is
SE-0429's `discard` + `consuming` discipline tracked in
[MEM-LINEAR-001] / [MEM-LINEAR-002]. The institute's `Path_Primitives.Path`
must be either `take()`'d (consuming) or it deallocates on scope-exit
deinit — at-most-once semantics per [MEM-LINEAR-002].

**Contextualization**: Linear Haskell's `→1` arrows require multiplicity
annotations on every function signature; the cost is uniform across the
codebase. Swift's `~Copyable` is opt-in per-type; the cost is
concentrated at adoption sites. The asymmetry argues for picking
adoption targets where the at-most-once semantic is genuinely needed —
which Source.Manager and Lint.Source.Parsed both express, and
Source.Location does not.

### C++ `std::unique_ptr` lineage

C++11 introduced `std::unique_ptr<T>` as the canonical move-only owning
pointer; deleted copy-constructor + copy-assignment + move-constructor.
The Swift equivalent is `~Copyable`'s move semantics. C++'s deeper
lesson — that `unique_ptr` only sees broad adoption *after* `auto` and
`std::move()` made the discipline ergonomic in C++14/17 — applies here:
adoption costs scale with the ergonomics of the surrounding language
features. Swift 6.4's SE-0499 reduces a major cost (Hashable/Equatable/
Comparable losses); SE-0437 (noncopyable Optional/Result) reduces another;
the remaining ceremonies (`switch consume`, `Optional<~Copyable>` access)
are documented as permanent per `noncopyable-ergonomics-compiler-state.md`.

**Contextualization**: C++'s `unique_ptr` adoption was driven by RAII
discipline AND the lack of GC. Swift has GC for reference types; the
pressure for `~Copyable` adoption is therefore narrower — concentrated
on types whose value semantics are *wrong* (parser handles, file
descriptors, allocated buffers) rather than on every type that *could*
have move semantics. This argues against blanket adoption and for
targeted, high-payback adoption — which is exactly what the ranking
above selects.

### Swift Evolution proposals

- [SE-0390 Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) — the foundation
- [SE-0427 Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) — the implicit-Copyable-on-extension constraint
- [SE-0432 Borrowing and consuming pattern matching for noncopyable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md) — the `switch consume` discipline
- [SE-0437 Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) — Optional and Result on ~Copyable
- [SE-0499 Support `~Copyable` and `~Escapable` in Standard Library Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) — the SE-0499 relaxation that re-opens this question

The proposal landscape shows a clear trajectory: each release reduces a
cost-of-adoption axis. The ranking here is therefore *forward-stable*:
Lint.Source.Parsed is the right adoption regardless of future SE
proposals; Source.Location remains wrong-shaped even if a hypothetical
future SE proposal closed the Codable gap.

---

## Empirical Validation Notes (per [RES-025])

Per [RES-025], Tier 2+ API-facing decisions SHOULD include empirical
validation via the Cognitive Dimensions framework. The survey is
analysis-only (per Scope §4 — adoption spikes are scoped at adoption
time, not survey time), so this section identifies the cognitive
dimensions the ranking is grounded in, rather than presenting
measurement.

| Dimension | How the top pick (Lint.Source.Parsed) scores |
|---|---|
| **Visibility** | High — the rule witness signature is the most-read declaration in the linter; changing it from `(Lint.Source.Parsed, Severity) -> [Record]` to `(borrowing Lint.Source.Parsed, Severity) -> [Record]` makes the borrow explicit at every site |
| **Consistency** | High — matches the existing `File.Handle / File.Descriptor / Path_Primitives.Path` shape ecosystem-wide |
| **Viscosity** | Low-medium — 73 rule definitions update mechanically; the engine already passes `parsed` by-value into a non-mutating closure consumer |
| **Role-expressiveness** | Maximum gain — the *whole point* of the bundle is "borrowed by rules"; the type currently mis-expresses this |
| **Error-proneness** | Reduced — accidental partial-copy of `(tree, converter)` becomes impossible |
| **Abstraction level** | Unchanged — the type is still a value (`struct`), still `Sendable`, still nest-namespaced under `Lint.Source`; only the move-vs-copy axis flips |

Empirical follow-up at adoption time should:
1. Build a SwiftPM spike with one rule definition, two engine call
   sites, the `borrowing` parameter switch, and confirm clean
   `swift build --build-tests` under both Swift 6.3 (where the change is
   pure-Swift `~Copyable`, no SE-0499 reliance) and 6.4-dev nightly.
2. Confirm the SwiftSyntax `SourceFileSyntax` + `SourceLocationConverter`
   storage works in a `~Copyable` struct (the spike risk per [RES-021]).
3. Optionally measure the residual cost of refcount-bump elimination on
   a representative consumer tree (e.g., `swift-foundations/swift-linter`'s
   own self-lint run) to confirm the move benefit is small-but-positive
   (the AST internals are reference-shared regardless; the saving is at
   the bundle-struct-copy granularity).

---

## Outcome

**Status**: RECOMMENDATION

### Ranked Top Picks

| Rank | Type | Score | One-line rationale |
|---|---|---|---|
| 1 | **`Lint.Source.Parsed`** | 25/30 | Highest payback by every axis: real per-file resource shape, large size, pattern-establishing across all linter rules, mechanical 73-rule cascade, zero protocol losses (not Codable, not Hashable, only Sendable today). The L3 linter-primitives layer is the right home for the pattern. |
| 2 | **`Source.Manager`** | 20/30 | Single-registry semantic; large content payload; engine already passes `inout`; matches swiftc/Clang precedent. Adopts cleanly with near-zero cascade given existing `inout` discipline. |
| 3 | **`Lint.Run.Outcome` / `[Lint.Finding]` stream** | 11/30 | Profile-driven optimization candidate; defer until the top two land and provide adoption-cost calibration. |

**Top pick rationale (Lint.Source.Parsed)**: this is the cheapest-to-adopt
candidate with the broadest pattern-establishing value in the survey.
Cascade is mechanical (closure-parameter modifier change at ~73 sites,
no protocol losses, no Codable migration), payback is decisive (size,
resource shape, role-expressiveness all maximum), and the adoption
*exercises the canonical Layer 0/1/2 model* per [IMPL-070] at a
foundations-layer L3 type with rule closures at Layer 2. It also makes
the linter-primitives layer the institute's standard reference for
"parsed-source-bundles are borrowed by analysis tools" — a pattern that
will recur in future LSP, formatter, and cross-rule-analysis work.

### Deferred / Not-Recommended

| Type | Score | Why deferred | Re-evaluation trigger |
|---|---|---|---|
| `Lint.Suppression` / `.Entry` | 4/30 | Engine-internal map; small payload; no resource shape | Not expected to flip |
| `Source.Location` (brief's trigger) | 8/30 | Highest cascade in the survey × zero resource-correlation. The reflexive "can't lose Hashable" objection is SE-0499-obsolete; the **structural** objection (zero resource-correlation, Codable wire-format dependency in `Test.Source.Location`) survives | (i) `Test.Source.Location`'s Codable wire format independently migrates to JSON.Serializable, AND (ii) a separate use case emerges where Source.Location wrapping a `~Copyable` internal is a hard requirement. Even then, the resource-correlation score is 0 — re-evaluation should require strong justification, not just SE-0499 |
| `Source.Position` | 3/30 | Pure value (file ID + byte offset); no resource | Not expected to flip |
| `Source.File` / `Source.File.ID` | 2/30 | Pure identity values | Not expected to flip |
| `Lint.Manifest` | 5/30 | JSON.Serializable wire-format boundary is load-bearing | Not expected to flip — the entire `swift-manifest`-subprocess boundary depends on JSON-encodable shape |
| `Lint.Finding` | 9/30 | Downstream of any Source.Location decision; cascades through every reporter / suppression / outcome consumer | Re-evaluate IF Source.Location adoption ever becomes viable (per its own row's re-evaluation trigger) — but even then, the per-finding emission-rate payback is small |
| `Lint.Source.Walker.paths(...)` return | 3/30 | `[Lint.Source.Path]` where `Lint.Source.Path` is a `Tagged<…, String>` typealias; can't be ~Copyable while remaining in `Array` | Not expected to flip |
| L3 `Paths.Path` (referenced; not enumerated here) | n/a | Per `path-type-ecosystem-model.md`, the Copyable wrapper IS the architectural bridge to stdlib `Array`/`Set`/`[K:V]`. Flipping it to `~Copyable` would defeat the purpose | Not expected to flip — definitively answered NO by prior research |

### Adoption Plan Sketch (for the top pick only)

When the principal authorizes adoption of `Lint.Source.Parsed: ~Copyable`,
the suggested phased approach mirrors the SE-0499 v1.3.0 RECOMMENDATION
shape:

1. **Verification spike** (per [RES-021]): minimal external SwiftPM
   target declaring `struct Parsed: ~Copyable, Sendable { let tree: SourceFileSyntax; let converter: SourceLocationConverter }`
   plus a single `@Sendable` closure `(borrowing Parsed) -> [Int]`.
   Build clean against both Swift 6.3 (the `~Copyable` mechanism predates
   SE-0499) and 6.4-dev nightly. Confirm no `~Copyable + @Sendable +
   reference-typed `let`` pathological interaction. ETA: 1 hour.
2. **L1 (swift-linter-primitives) change**: edit `Lint.Source.Parsed.swift`
   to `public struct Parsed: ~Copyable, Sendable { ... }`. Update
   `Lint.Rule.findings` closure type to
   `@Sendable (borrowing Lint.Source.Parsed, Diagnostic.Severity) -> [Diagnostic.Record]`.
   Update tests in `swift-linter-primitives/Tests/Linter Primitives Tests/Lint.Rule.Witness Tests.swift`.
   ETA: 2 hours.
3. **L3 (swift-linter) engine change**: update
   `Lint.Source.Parsed+Visibility.swift:49` visibility method to
   `borrowing func`. Update `Lint.Run.run` loop body if any pattern-match
   over `parsed` exists (verified by grep — none today).
   ETA: 1 hour.
4. **Rule pack cascade**: update closure signatures in
   `swift-foundations/swift-linter-rules` (~58 rule defs) and
   `swift-foundations/swift-institute-linter-rules` (~15 rule defs).
   Mechanical addition of `borrowing` modifier to the `source` parameter
   in each `findings: { source, severity in ... }` block.
   ETA: 2–3 hours.
5. **Workspace-wide build + test**: per [HANDOFF-035] termination
   criteria, run `swift build --build-tests` across every transitive
   consumer (the two rule packs, the linter foundation, the CLI, and any
   consumer that imports `Linter_Primitives`). Verify zero residuals via
   workspace-wide grep `Lint.Source.Parsed` (literal-only is sufficient
   per [HANDOFF-040] since the type is non-generic).
   ETA: 30 minutes.

Total adoption estimate: **~6–8 hours**, single principal-authorization
gate for the cascade landing.

### Path-vs-String Cleavage (resolved as side effect of top-pick adoption)

The investigation's parent trigger was Source.Location.filePath's
`Swift.String?` vs `Path` question (Wave 3 of the linter arc). The
top-pick recommendation resolves it cleanly by recognizing that
"filePath" is two structurally different things wearing the same name:

| Layer | Field | Type | Reason |
|---|---|---|---|
| Inside `~Copyable` `Lint.Source.Parsed` | the path the parsed source was *loaded from* | `Path_Primitives.Path` (~Copyable) | **Resource** — real open/read lifecycle; parent type is now `~Copyable` so it can hold a `~Copyable` field naturally |
| Inside Copyable `Source.Location` | the file path embedded in a diagnostic record | `Swift.String?` (status quo) | **Identifier** — external boundaries are genuinely String at every producer site (`#filePath` macro, SwiftSyntax `SourceLocationConverter`, JSON wire format, `hasSuffix` matching in tests) |
| Projection boundary | one well-defined site where Parsed's Path becomes a diagnostic's filePath String | `Path → String` once | The cleavage point is mechanically clear — wherever a `Source.Location` is constructed from a Parsed source, the path projects to its string form via `Path`'s existing string-conversion accessor |

This cleaves along the **resource-vs-identifier** line without forcing
`~Copyable` cascade on Source.Location (per Row 5's structural objection,
which survives SE-0499 because it's grounded in zero-resource-correlation,
not protocol losses).

**On the optional Tagged<Source.File, Swift.String> refinement at the
identifier layer** — purely cosmetic compile-time discrimination for
"this String is a filePath, not arbitrary text". The investigation
framework's [RES-018] second-consumer rule applies: defer until a real
second consumer surfaces. The current single-consumer state (just
Source.Location) does not justify the wrapping cost; status quo
`Swift.String?` wins on cost-benefit.

**Implementer instruction**: Phase 4 of the adoption plan (rule pack
cascade) is the natural place to surface the projection-boundary site
explicitly in the code — annotate where `Path → String` projects so a
future reader can identify the cleavage at a glance.

### Per [HANDOFF-039] / [RES-027] notes

This research document is the predecessor that any subsequent adoption
dispatch supersedes. If the principal authorizes adoption, the
adoption-dispatch handoff retires this document per [HANDOFF-039]:
either deleting it (after the adoption commits land and the
RECOMMENDATION is absorbed into the implemented state) or annotating it
as superseded.

Per [RES-027] loose-end follow-up: every Open Question / Future Work
item in this doc is a *direction*, not a *premise* — none of the
deferred candidates carries forward as a load-bearing constraint on
adjacent design conversations. No verification spike is required at
write time.

---

## Open Questions

| # | Question | Status | Resolution path |
|---|---|---|---|
| Q1 | Should the adoption proceed under Swift 6.3 (pure-`~Copyable`, no SE-0499 reliance) or wait for 6.4-stable? | Recommend 6.3-and-up: `Lint.Source.Parsed` doesn't lose any stdlib protocol on adoption (currently Sendable only), so SE-0499 is irrelevant for this specific target. Adoption can land today. | Principal sign-off at adoption time |
| Q2 | Does the `Lint.Source.Parsed.visibility(at:)` engine-internal extension need a renamed `borrowing` overload, or does it convert in place? | Convert in place — the existing call site (`Lint.Run.run:162`) already calls it with no mutation, so the `borrowing` modifier is mechanical | Adoption-time |
| Q3 | Will SwiftSyntax 602's `SourceFileSyntax`/`SourceLocationConverter` storage interact poorly with a `~Copyable` struct that doesn't synthesize a deinit? | Spike risk per [RES-021]; expected clean — both are reference-typed value wrappers with ARC-managed release | Verification spike at adoption time |
| Q4 | Is Source.Manager's adoption a separate cycle, or bundled with Lint.Source.Parsed? | Recommend separate: Lint.Source.Parsed is L3 with engine-internal cascade; Source.Manager is L1 with broader (compiler/LSP/formatter-shaped future) cascade. Different blast radii, different review surfaces | Principal sign-off at adoption time |
| Q5 | Does the institute already have a `~Copyable` analogue of `Sendable` closure type aliases? The rule witness uses `@Sendable (Lint.Source.Parsed, Diagnostic.Severity) -> [Diagnostic.Record]`; does `@Sendable` compose with a `borrowing` first parameter? | Yes per `noncopyable-ecosystem-state.md` §1: `inout sending Value` and consuming closure parameters compose cleanly. The exact form `@Sendable (borrowing T, U) -> R` builds in stdlib (`stdlib/public/Concurrency/CooperativeExecutor.swift:131` precedent for `(consuming ExecutorJob) -> ()`) | Verification spike will confirm |

---

## References

### Internal research (per [RES-019] step-0 grep)

- `swift-institute/Research/noncopyable-ecosystem-state.md` (DECISION, v1.0.0, 2026-04-02) — canonical `~Copyable` state-of-ecosystem reference
- `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` (RECOMMENDATION, v1.3.0, 2026-05-03) — SE-0499 landed-status verification + Option C-refined pattern; the empirical anchor for the SE-0499 cost-calculus shift
- `swift-institute/Research/source-location-unification.md` (DECISION, v3.1.0, 2026-02-27) — the implemented Source.Location decomposition. The "~Copyable cascade" constraint is the pre-SE-0499 framing that this survey re-evaluates
- `swift-institute/Research/path-type-ecosystem-model.md` (2026-04-18) — top-to-bottom path type model; reference for the L3-Copyable-wraps-L1-~Copyable pattern
- `swift-institute/Research/noncopyable-ergonomics-compiler-state.md` (SUPERSEDED → ecosystem-state, v3.0.0, 2026-03-31) — foundational pain-point survey
- `swift-institute/Research/nested-view-vs-borrowed-naming.md` — naming for borrowed-view companions

### Skill requirements

- [MEM-COPY-001] / [MEM-COPY-001a] — noncopyable type declaration + deinit immutability
- [MEM-COPY-004] — extension constraints for `~Copyable` types ([SE-0427] implicit-Copyable inversion)
- [MEM-COPY-005] — nested accessor pattern incompatibility with `~Copyable`
- [MEM-COPY-006] — `~Copyable` propagation gotchas (the cascade source)
- [MEM-COPY-014] — native ownership for resource types (the canonical adoption signal)
- [MEM-OWN-001] / [MEM-OWN-002] — consuming / borrowing parameters
- [MEM-OWN-010] / [MEM-OWN-011] / [MEM-OWN-012] — three canonical transfer patterns
- [MEM-LINEAR-001] / [MEM-LINEAR-002] — exactly-once / at-most-once types
- [IMPL-063] — synchronization-as-ownership (the 3× write-throughput finding)
- [IMPL-070] — Layer 0/1/2 model
- [RES-018] — premature primitive anti-pattern (the second-consumer check)
- [RES-020] — research tiers; this doc is Tier 2 per cross-package scope + reversible commitment
- [RES-021] — prior art survey + verification spike requirement
- [RES-022] — structural correctness over diff-size in recommendation framing
- [RES-025] — empirical validation via Cognitive Dimensions
- [RES-027] — loose-end follow-up requires extant or immediate experiment
- [HANDOFF-013] / [HANDOFF-013a] — prior-research grep discipline
- [HANDOFF-035] — cascade-migration termination criteria (workspace-wide grep + ecosystem-wide build)
- [HANDOFF-040] — generic-instantiated forms in cascade enumeration

### Swift Evolution

- [SE-0390 — Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) (Swift 5.9)
- [SE-0427 — Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) (Swift 6.0)
- [SE-0429 — Partial Consumption of Noncopyable Values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0429-partial-consumption.md) (Swift 6.0)
- [SE-0430 — `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) (Swift 6.0)
- [SE-0432 — Borrowing and consuming pattern matching for noncopyable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md) (Swift 6.0)
- [SE-0437 — Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) (Swift 6.0)
- [SE-0499 — Support `~Copyable` and `~Escapable` in Standard Library Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) (Implemented Swift 6.4)

### Prior art (external)

- Rust `rustc_span::SourceFile` via `Arc<SourceFile>`: [github.com/rust-lang/rust/blob/master/compiler/rustc_span/src/lib.rs](https://github.com/rust-lang/rust/blob/master/compiler/rustc_span/src/lib.rs) — shared-ownership compiler source map (the architectural alternative to Source.Manager-as-single-owner)
- Rust `std::fs::File`: [doc.rust-lang.org/std/fs/struct.File.html](https://doc.rust-lang.org/std/fs/struct.File.html) — non-Copy, Drop-implementing file handle (the canonical resource-correlated move-only type; matches `File.Handle: ~Copyable, Sendable`)
- C++ `std::unique_ptr`: [cppreference.com/w/cpp/memory/unique_ptr](https://en.cppreference.com/w/cpp/memory/unique_ptr) — move-only owning pointer; the C++11 lineage
- Linear Haskell, *Linear types can change the world!* (Bernardy, Boespflug, Newton, Peyton Jones, Spiwack 2018): [arxiv.org/abs/1710.09756](https://arxiv.org/abs/1710.09756) — linear-types-as-multiplicity foundations
- swiftc `SourceManager`: [github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceLoc.h](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/SourceLoc.h) — single-instance-per-compilation source manager (the Swift compiler precedent that Source.Manager mirrors)
- Clang `SourceManager`: [llvm.org/doxygen/classclang_1_1SourceManager.html](https://clang.llvm.org/doxygen/classclang_1_1SourceManager.html) — same single-owner pattern in Clang

### Apple swift-syntax reference

- `SourceFileSyntax`: [github.com/swiftlang/swift-syntax](https://github.com/swiftlang/swift-syntax) — reference-typed AST root
- `SourceLocationConverter`: same — line/column resolver with lazy line-start cache
