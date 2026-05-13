# Noncopyable Adoption: Ecosystem Corners Audit (Beyond the Linter)

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
applies_to:
  - swift-foundations/swift-file-system
  - swift-foundations/swift-kernel
  - swift-foundations/swift-io
  - swift-foundations/swift-threads
  - swift-foundations/swift-process
  - swift-foundations/swift-sockets
  - swift-foundations/swift-source
  - swift-foundations/swift-parsers
  - swift-primitives/swift-source-primitives
  - swift-primitives/swift-buffer-primitives
  - swift-primitives/swift-storage-primitives
  - swift-primitives/swift-async-primitives
  - swift-primitives/swift-input-primitives
  - swift-primitives/swift-text-primitives
  - swift-primitives/swift-string-primitives
  - swift-primitives/swift-lexer-primitives
  - swift-primitives/swift-parser-primitives
  - swift-primitives/swift-parser-machine-primitives
  - swift-primitives/swift-binary-parser-primitives
  - swift-primitives/swift-path-primitives
verification_experiment: none (analysis-only; per-target spike scoped at adoption time)
predecessor: 2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md (v1.2.0 RECOMMENDATION; scoped to linter / source-primitives)
trigger: HANDOFF-noncopyable-ecosystem-corners-audit.md (parent: post-Wave-5+6 calibration; broaden scope across ecosystem corners)
---
-->

## Context

The v1.2.0 RECOMMENDATION at
`swift-institute/Research/2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md`
ranked `~Copyable` adoption candidates within the linter / source-primitives
surface. Adoption of Rows 1 + 2 closed cleanly:

| Wave | Target | Estimated | Actual |
|---|---|---|---|
| Wave 5 | `Lint.Source.Parsed` (`swift-linter-primitives@110a72c`) | 6–8 h | ~2–3 h |
| Wave 6 | `Source.Manager` (`swift-source-primitives@23e584e`) | 3–5 h | ~1–2 h |

The ~3× under-estimate came from **ecosystem-readiness benefits**:

- Wave 5: Swift's closure-type inference auto-propagated `borrowing` through
  the 73-rule `Lint.Rule.findings` cascade — no manual signature edits at
  most consumer sites.
- Wave 6: `Source.Manager`'s consumer sites already used `inout` discipline
  (`Lint.Run.parsedSource(manager: inout Source.Manager)` predated the
  `~Copyable` flip); the L1 type-shape change absorbed at the type
  declaration only.

The fresh calibration raised an obvious question: are there **more
ready-to-adopt corners** beyond the linter that the v1.2.0 survey did not
consider? Wave 5 + Wave 6 came in cheap because two specific structural
shapes (closure inference, existing `inout` discipline) ABSORBED the
cascade. If the same structural shapes recur elsewhere — file-system,
kernel, IO, parsers, storage — the same cheap adoption applies.

This audit broadens the scope across ecosystem corners — file-system,
kernel, IO, parsers, storage, buffer, time, async, source — and surveys
*all* resource-bearing or large-value-typed candidates against the v1.2.0
six-axis scoring framework, **enhanced** with the Wave-5+6
ecosystem-readiness lens.

### Prior Research

Per [RES-019] step-0 internal grep, the relevant prior corpus
(`grep -l 'noncopyable\|~Copyable' swift-institute/Research/`):

| Document | Bearing on this audit |
|---|---|
| `2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md` v1.2.0 RECOMMENDATION | **Predecessor.** Six-axis scoring framework; Row 3 sharpened-deferred for stdlib-Array structural barrier; control set of already-~Copyable types. This audit extends the framework across ecosystem corners and DOES NOT revisit the predecessor's adopted Rows 1+2 or its already-deferred Row 3. |
| `noncopyable-ecosystem-state.md` v1.0.0 DECISION | Canonical `~Copyable` state-of-ecosystem reference. Five permanent-by-design limitations, three transfer patterns ([MEM-OWN-010]/[MEM-OWN-011]/[MEM-OWN-012]), the Layer 0/1/2 discipline ([IMPL-070]), the 3× write-throughput synchronization-as-ownership finding ([IMPL-063]). |
| `se-0499-implications-for-equation-hash-comparison-primitives.md` v1.3.0 RECOMMENDATION | Empirical SE-0499 landed-status verification. Hashable / Equatable / Comparable natively support `~Copyable` from Swift 6.4; Codable / IteratorProtocol do not. |
| `path-type-ecosystem-model.md` (2026-04-18) | The canonical L3-Copyable-wraps-L1-`~Copyable` reference architectural shape; cited as the answer to "should the Copyable wrapper become ~Copyable?" — definitively NO when the wrapper IS the architectural bridge to stdlib containers. |
| `noncopyable-ergonomics-compiler-state.md` v3.0.0 SUPERSEDED | Foundational pain-point survey (consolidated into ecosystem-state). `switch consume` discipline; closure-capture limitation; `Optional<~Copyable>` access ceremony. |
| `nested-view-vs-borrowed-naming.md` | Naming for borrowed-view companions (`X.Borrowed: ~Copyable, ~Escapable`). |
| `frozen-noncopyable-deinit-tradeoff.md` | Frozen + ~Copyable + deinit interaction (relevant when evaluating @_rawLayout-bearing types). |
| `noncopyable-property-extract-via-underscore-owned.md` | The `_owned` extraction pattern (relevant for nested ~Copyable fields). |
| `view-vs-span-borrowed-access-types.md` | Borrowed access types (View / Span) — the L1-`~Copyable` foundation companion pattern. |
| `withUnsafe-borrowing-noncopyable-pattern-reach-survey.md` | Survey of `withUnsafe...` + borrowing + ~Copyable patterns. |

This audit **extends** the v1.2.0 framework; it does not duplicate or
revise it. Rows already analysed in v1.2.0 (1–10) are NOT re-scored here.

### Constraints

(carry-forward from v1.2.0 — verified still current 2026-05-13)

- **Toolchain matrix**: Swift 6.3 stable + 6.4-dev nightly per
  `feedback_toolchain_versions.md`. SE-0499 (stdlib Hashable/Equatable/
  Comparable on `~Copyable`) is 6.4-only.
- **Codable wire format**: stdlib `Encoder/Decoder` cannot encode/decode
  `~Copyable` values; migration to `JSON.Serializable` per the
  `Lint.Manifest` precedent is required when Codable is load-bearing.
- **Stdlib `Array`, `Set`, `Dictionary`**: do NOT support `~Copyable`
  elements as of Swift 6.4. SE-0437 ships `~Copyable` `Optional` /
  `Result`; collections remain Copyable-only.
- **Stdlib `IteratorProtocol`**: requires Copyable element type and
  `mutating func next() -> Element?` returning Copyable — `~Copyable`
  iterators cannot conform.
- **Stdlib `Sequence` / `Collection`**: same — `~Copyable` cannot conform
  pre-stdlib-revision.

### Scope

In scope (analysis only — NO code modifications):

1. Enumerate `~Copyable` candidate types across **ecosystem corners
   beyond the linter**: file-system, kernel, IO, parsers, storage,
   buffer, time, async, source, threads, process, sockets, lexer,
   parser-machine, binary-parser, text, string, input.
2. Apply v1.2.0 six-axis scoring per candidate.
3. Apply the **Wave-5+6 ecosystem-readiness lens** — does existing
   structure absorb the cascade (closure inference, inout discipline,
   single-instance, callback-based access), or does adoption require
   structural API redesign (stdlib-Array migration, stdlib-protocol
   conformance, escaping-closure capture, Codable migration)?
4. Identify **structural enablers**: candidates whose adoption is gated
   by a separate design decision (per the v1.2.0 Row 3 pattern); cite
   and defer.
5. Produce a ranked recommendation of the **top 3–5 NEW targets** beyond
   Rows 1 + 2, with explicit rationale for the top pick.
6. Identify deferred / not-recommended candidates with reasoning.

Out of scope: implementation work on any target; revisiting already-adopted
Rows 1 + 2; revisiting already-deferred Row 3; Wave 4 (swift-uuids /
swift-identities — explicitly excluded per HANDOFF "Do Not Touch");
upstream Swift Evolution drafting (gating decisions cited but not pitched);
Lint.File vs File_System.File namespace question.

---

## Question

Beyond the linter / source-primitives surface that the v1.2.0
RECOMMENDATION covered, what types across the ecosystem
(file-system, kernel, IO, parsers, storage, buffer, time, async,
source, threads, process, sockets, lexer, parser-machine, binary-parser,
text, string, input) are ready for `~Copyable` adoption with cascade
cost that the Wave-5+6 ecosystem-readiness benefits can absorb cheaply?

Sub-questions:

1. Which currently-Copyable resource-bearing or large-value-typed
   candidates does the ecosystem still hold?
2. Of those, which structural-shape pattern do they exhibit —
   absorbable-cascade (Wave-5+6 shape) or structural-redesign-required
   (Row 3 shape)?
3. Are there candidates that score 20+/30 on the v1.2.0 scoring grid
   AND meet the Wave-5+6 readiness lens? If yes, rank them; if no,
   document the finding explicitly.
4. For each deferred candidate, what is the gating structural decision
   (stdlib protocol, stdlib container, upstream SE proposal, ecosystem
   API redesign) and what would unblock it?

---

## Analysis

### Survey Method

Each candidate is scored on the v1.2.0 six axes (definition unchanged
from the predecessor):

| Axis | What it measures |
|---|---|
| **(a) Resource-correlation** | Does the type wrap a real acquire/release lifecycle? |
| **(b) Size / hot-path** | Is move-vs-copy observable at consumer call sites? |
| **(c) Safety bug class** | Does `~Copyable` close a specific bug class (UAF, double-free, aliasing, stale-state)? |
| **(d) Cascade cost** | Total cascade footprint: consumer-file count + stdlib protocol losses + `where T: ~Copyable` propagation + `switch consume` + `Optional<~Copyable>` access. **High score = high cost = inverted in ranking.** |
| **(e) Pattern-establishing** | Does adoption exercise broad `~Copyable` ecosystem infrastructure (Layer 0/1/2 patterns, `Mutex.withLock(consuming:)`, `_read`/`_modify` projections, the `X / X.Borrowed` bifurcation)? |
| **(f) Existing alignment** | Does the type already smuggle single-owner semantics through a Copyable boundary, or already pass `inout` in its primary access pattern? |

Each candidate is also tagged with a **Wave-5+6 readiness shape**:

| Shape | Description | Absorbable-cascade? |
|---|---|---|
| **Closure-inference** | Consumers borrow via closures the compiler can re-infer (Wave 5 Lint.Source.Parsed pattern) | Yes — cheap |
| **Inout-discipline** | Consumers already use `inout` for mutation (Wave 6 Source.Manager pattern) | Yes — cheap |
| **Single-instance** | One owner per scope, threaded through call sites manually | Yes — moderate |
| **Stdlib-array-storage** | Type stored in `[T]` / `Set<T>` / `[K:V]` (Row 3 pattern) | NO — requires structural redesign |
| **Stdlib-protocol** | Type conforms to a stdlib protocol that requires Copyable (`IteratorProtocol`, `Sequence`, etc.) | NO — requires upstream evolution |
| **Codable-wire-format** | Type bridges across process boundary via stdlib `Codable` | NO — requires `JSON.Serializable` migration |
| **Cross-thread-shared** | Type intentionally reference-typed for cross-thread sharing (sync primitives) | NO — `~Copyable` is the wrong model |

### Already-`~Copyable` (control set, no work)

Beyond the v1.2.0 control set (`Path_Primitives.Path`,
`Path_Primitives.Path.Borrowed`, `File.Handle`, `File.Descriptor`,
`File.Directory.Iterator`, `File.System.Write.Atomic.TempFile`,
`File.System.Write.Streaming.Context`), the ecosystem ALREADY adopts
`~Copyable` extensively. The complete already-adopted set surveyed:

| Package | Type | Location |
|---|---|---|
| `swift-source-primitives` | `Source.Manager` | `Sources/Source Primitives/Source.Manager.swift:53` (Wave 6 landed) |
| `swift-linter-primitives` | `Lint.Source.Parsed` | (Wave 5 landed) |
| `swift-process` | `Process.Handle` | `Sources/Process/Process.Handle.swift:40` |
| `swift-sockets` | `Sockets.TCP.Connection` | `Sources/Sockets/Sockets.TCP.Connection.swift:32` |
| `swift-threads` | `Kernel.Thread.Worker` | `Sources/Thread Worker/Kernel.Thread.Worker.swift:50` |
| `swift-kernel` | `Kernel.Event.Source` | `Sources/Kernel Event/Kernel.Event.Source.swift:25` |
| `swift-kernel` | `Kernel.Event.Driver` | `Sources/Kernel Event/Kernel.Event.Driver.swift:30` |
| `swift-kernel` | `Kernel.Terminal.Mode.Raw.Token` | `Sources/Kernel Terminal/Terminal.Mode.Raw.Token.swift:28` |
| `swift-kernel` | `Kernel.Completion` | `Sources/Kernel Completion/Kernel.Completion.swift:33` |
| `swift-kernel` | `Kernel.Completion.Driver` | `Sources/Kernel Completion/Kernel.Completion.Driver.swift:47` |
| `swift-kernel` | `Kernel.Completion.Notification` | `Sources/Kernel Completion/Kernel.Completion.Notification.swift:31` |
| `swift-io` | `IO.Completion.Entry` | `Sources/IO Completions/Completion.Entry.swift:56` |
| `swift-string-primitives` | `String` | `Sources/String Primitives/String.swift:47` |
| `swift-string-primitives` | `String.Borrowed` | `Sources/String Primitives/String.Borrowed.swift:36` |
| `swift-lexer-primitives` | `Lexer.Scanner` | `Sources/Lexer Primitives/Lexer.Scanner.swift:39` (`~Copyable, ~Escapable`) |
| `swift-input-primitives` | `Input.Slice`, `Input.Buffer`, `Input.Protocol`, `Input.Stream.Protocol`, `Input.Access.Random` | `Sources/Input Primitives/*` |
| `swift-buffer-primitives` | `Buffer.Slots`, `Buffer.Ring.Inline`, `Buffer.Ring.Small` | `Sources/Buffer * Primitives/*` |
| `swift-storage-primitives` | `Storage.Inline`, `Storage.Pool.Inline`, `Storage.Arena.Inline` | `Sources/Storage Primitives Core/*` |
| `swift-async-primitives` | `Async.Channel.Bounded`, `Async.Channel.Unbounded`, `Async.Channel.{Take,Ends}`, `Async.Mutex.Local`, `Async.Waiter.{Entry,Queue.Flagged,Resumption}`, `Async.Lifecycle.State.Shutdown` | `Sources/Async * Primitives/*` |
| `swift-parser-machine-primitives` | `Parser.Machine.Builder` | `Sources/Parser Machine Core Primitives/Parser.Machine.swift:71` |
| `swift-binary-parser-primitives` | `Binary.Bytes.Input.View`, `Binary.Bytes.Machine.Builder` | `Sources/Binary * Primitives/*` |

**Finding (calibration anchor)**: the ecosystem ALREADY adopts `~Copyable`
on essentially every type with a genuine acquire/release lifecycle, AND
on essentially every ~Copyable-friendly value-bundle that doesn't have
to fit a stdlib protocol or container. The two Wave-5+6 picks
(Lint.Source.Parsed, Source.Manager) brought the linter / source domain
to the same adoption level the lower layers already enjoyed; **the
remaining Copyable surface is not Copyable by accident**.

### Scoring Matrix (Candidate types beyond Rows 1–10)

The v1.2.0 doc enumerated Rows 1–10. This audit adds Rows 11–18,
covering ecosystem corners beyond the linter. Row IDs continue the
predecessor's numbering for cross-doc reference.

| Row | Candidate | (a) Res-corr | (b) Size/HP | (c) Safety | (d) Cascade | (e) Pattern | (f) Existing | Wave-5+6 shape | **Total** |
|---|---|---|---|---|---|---|---|---|---|
| 11 | `Parser.Machine.Compiled` (parser-machine-primitives L1) | 3 | 4 | 3 | **5** | 3 | 4 | **Stdlib-protocol** (Parser.`Protocol` requires Copyable) | **14** |
| 12 | `Parser.Machine.Prepared` (parser-machine-primitives L1) | 2 | 3 | 1 | **5** | 2 | 3 | **Stdlib-protocol** + already shared via Sendable | **6** |
| 13 | `File.Directory.Contents.Iterator` (file-system L3) | 5 | 2 | 4 | **5** | 1 | 5 | **Stdlib-protocol** (`IteratorProtocol`) | **12** |
| 14 | `Text.Line.Map` (text-primitives L1) | 0 | 2 | 0 | **5** | 0 | 0 | **Stdlib-array-storage** (`[Text.Position]`) | **2** |
| 15 | `Source.Cache` (swift-source L3) | 1 | 3 | 1 | **5** | 0 | 1 | **Stdlib-array-storage** (`[String: [UInt8]]`) | **1** |
| 16 | `Kernel.Thread.Handle.Reference` (threads L3) | n/a | n/a | n/a | n/a | n/a | n/a | **Stdlib-array-storage** workaround (already EXISTS for this reason) | **NOT-A-CANDIDATE** |
| 17 | `Kernel.Thread.{Semaphore,Synchronization,Gate,Barrier}` (threads L3) | n/a | n/a | n/a | n/a | n/a | n/a | **Cross-thread-shared** (reference-typed by design) | **NOT-A-CANDIDATE** |
| 18 | `Storage.{Slab,Pool,Heap,Arena,Split}` (storage-primitives L1) | n/a | n/a | n/a | n/a | n/a | n/a | **Cross-thread-shared** (ManagedBuffer-backed, COW-shareable) | **NOT-A-CANDIDATE** |

Same convention as v1.2.0: column (d) is a **cost**; the Total is the
sum of (a) + (b) + (c) + (e) + (f) MINUS (d) — already applied in the
Total column.

### Per-candidate analysis

#### Row 11 — `Parser.Machine.Compiled` (HIGHEST-SCORED NEW CANDIDATE)

**Location**:
`swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compiled.swift:37`.

**Current shape**:

```swift
public struct Compiled<P: Parser_Primitives.Parser.`Protocol`>
where
    P.Input: Parser_Primitives.Parser.Input.`Protocol`,
    P.Failure: Swift.Error
{
    let source: P
    let witness: Compile.Witness<P>
    let cache: Cache  // final class
}

extension Parser.Machine.Compiled: Parser_Primitives.Parser.`Protocol` {
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        let result = cache.getOrCompile(source: source, witness: witness)
        return try Parser.Machine.run(...)
    }
}
```

The doc-comment at line 27–31 already names the semantic:
*"`Compiled` is NOT `Sendable`. Use it within a single isolation
domain. For cross-task sharing, use `prepared()` which returns an
immutable `Prepared` wrapper that is conditionally `Sendable`."*

This is **exactly the Row 1 (Lint.Source.Parsed) shape**: a value type
that smuggles single-owner-of-a-reference semantic through a Copyable
boundary, with the reference type intentionally hidden internal.

**(a) Resource-correlation 3/5**: the `Cache` reference holds the
compiled state-machine `Program` (instructions, jump table, recursion
context — `Parser.Machine.Program<Input, Failure>`). The lazy
`getOrCompile` path is a real resource-acquisition step; once compiled,
the cache owns the program for the lifetime of the `Compiled` value.
Not a kernel resource (no fd, no syscall), but a substantial
amortized-allocation lifecycle.

**(b) Size/hot-path 4/5**: the compiled `Program` can be substantial
(O(rules × productions) instructions for complex grammars); the
single-isolation-domain constraint means the cache is the working-set
for an entire parse run. Move-vs-copy at the consumer level is
observable through accidental `Cache` aliasing when a `Compiled` value
is copied into a generic `some Parser.Protocol` slot.

**(c) Safety 3/5**: prevents the "two compiled wrappers, one cache"
aliasing bug — if a consumer copies `let p2 = compiled` and then calls
`p2.prepared()` and `compiled.prepared()` on different isolation
threads, the cache is shared without synchronisation. The doc-comment
warning is currently a documented invariant; `~Copyable` would make it
a compile-time guarantee.

**(d) Cascade cost 5/5 (HIGHEST — STRUCTURAL BARRIER)**: this is the
deal-breaker. `Parser.Machine.Compiled` conforms to
`Parser_Primitives.Parser.Protocol`. That protocol at
`swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90`
is declared **without** `: ~Copyable`:

```swift
public protocol `Protocol`<Input, Output, Failure> {
    associatedtype Input: ~Copyable & ~Escapable   // ← Input IS ~Copyable
    associatedtype Output
    associatedtype Failure: Swift.Error
    associatedtype Body
    var body: Body { get }
    func parse(_ input: inout Input) throws(Failure) -> Output
}
```

The Input is `~Copyable`, but `Self` (the parser) is Copyable-by-default.
Adopting `~Copyable` on `Compiled` requires either:

(i) Adding `: ~Copyable` to `Parser.Protocol` itself — a sweeping change
that cascades through **every parser combinator** (Parser.Map.Transform,
Parser.Take.Sequence, Parser.OneOf.Two, Parser.Skip.First, Parser.Lazy,
etc., across `swift-parser-primitives` + `swift-parser-machine-primitives`
+ `swift-binary-parser-primitives` + downstream parser packages —
roughly 30+ combinator types just in the L1 parser layer).

(ii) Making `Compiled` NOT conform to `Parser.Protocol` and exposing it
via a sibling type that the consumer uses directly (`compiled.parse(&input)`
instead of `someParser.parse(&input)` where `someParser = compiled`).
This forfeits the composability that makes `Compiled` ergonomic in the
first place.

Neither (i) nor (ii) is absorbable by the Wave-5+6 mechanisms. **Option
(i)** is the Row-3-shape structural redesign at protocol scope; it would
itself be a Tier-3 ecosystem-wide investigation (the parser protocol is
the foundation of the parsing ecosystem). **Option (ii)** abandons the
composability that motivates having `Compiled` at all.

**(e) Pattern-establishing 3/5**: if the protocol-level change landed,
adoption WOULD establish "parser composition is borrow-based, parsers
own compiled state machines" as the ecosystem norm — substantial pattern
value. But this is conditional on the gating decision.

**(f) Existing alignment 4/5**: the wrapped `Cache` is a class
(reference-shared); copying `Compiled` smuggles shared ownership through
a Copyable boundary today. Adopting `~Copyable` matches the actual
ownership shape. Same alignment-strength as Row 1.

**Wave-5+6 readiness shape**: **Stdlib-protocol**. The cascade is NOT
absorbed by closure inference or inout discipline; it requires a
protocol-level redesign at `Parser.Protocol` that affects every
combinator in the parser stack. This is a Row-3-shape gating decision,
not a Wave-5+6 absorbable cascade.

**Score 14/30**: enough on the substantive axes (a/b/c/e/f) to be a
*structural* candidate, but the cascade cost dominates — same pattern
as Row 5 (Source.Location) but a different gating cause.

**Re-evaluation trigger**: if `Parser.Protocol` independently adopts
`: ~Copyable` (as a Tier-3 decision covering the whole parser stack),
`Compiled` becomes a Row-1-shape absorbable cascade — adopt at that
point.

#### Row 12 — `Parser.Machine.Prepared`

**Location**:
`swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Prepared.swift:40`.

**Verdict 6/30**: Prepared is the **already-shared** immutable Sendable
variant of Compiled. The whole design intent is "Prepared can cross
isolation boundaries"; ~Copyable is the **wrong** ownership model here.
The Compiled / Prepared bifurcation IS the architectural pattern (single-
owner / multi-owner-immutable), analogous to the L1-`~Copyable` /
L3-Copyable Path bifurcation. **Not a candidate**, by design.

#### Row 13 — `File.Directory.Contents.Iterator`

**Location**:
`swift-foundations/swift-file-system/Sources/File System Core/File.Directory.Contents.Iterator.swift:15`.

**Current shape**:

```swift
public struct Iterator: IteratorProtocol {
    internal let _stream: Kernel.Directory.Stream
    internal var _finished: Bool = false
    internal var _lastError: Kernel.Directory.Error? = nil
    public mutating func next() -> File.Name? { ... }
}

public static func makeIterator(
    at directory: File.Directory
) throws(...) -> (iterator: Iterator, handle: IteratorHandle)

// And separately:
public final class IteratorHandle: @unchecked Sendable {
    internal let stream: Kernel.Directory.Stream
    deinit { stream.close() }
}
```

**(a) Resource-correlation 5/5**: owns a `Kernel.Directory.Stream` (a
DIR* opaque pointer in POSIX, an HANDLE on Windows). This is THE
canonical fd-shaped resource. The split `(Iterator, IteratorHandle)`
return at line 56 is documented at
`File.Directory.Contents.IteratorHandle.swift:11–28` as a **workaround**:
*"`IteratorHandle` wraps the underlying `Kernel.Directory.Stream` for
proper resource management ... The caller is responsible for closing
the handle via `closeIterator(_:)`."* The reference-typed handle
deinit-closes the stream because the Copyable Iterator cannot own a
resource.

**(b) Size/hot-path 2/5**: small struct (one stream pointer, two flag
bytes). Not a hot-path size concern.

**(c) Safety 4/5**: the current design has TWO bug classes:

1. **Double-close**: if the Copyable Iterator is copied and both copies
   trigger `closeIterator(handle)`, the stream pointer is double-closed.
   The IteratorHandle's class reference disambiguates the close-once
   intent, but the *Iterator* contains a copy of the `_stream` pointer
   too — semantically aliased.
2. **Use-after-close**: nothing in the type system prevents calling
   `.next()` on an Iterator after `closeIterator(handle)`. The Iterator
   sees a closed stream and the kernel returns EBADF (or platform
   equivalent).

`~Copyable` would close both bug classes by construction.

**(d) Cascade cost 5/5 (HIGHEST — STRUCTURAL BARRIER)**: `IteratorProtocol`
requires Copyable conformers:

```swift
public protocol IteratorProtocol<Element> {
    associatedtype Element
    mutating func next() -> Element?
}
```

Adopting `~Copyable` on `File.Directory.Contents.Iterator` requires
either:

(i) Dropping `IteratorProtocol` conformance — the Iterator becomes a
custom protocol-less type. Consumers can no longer use it with `for
... in ...` (which requires `Sequence`, which itself requires
`IteratorProtocol`).

(ii) Upstream Swift Evolution: a proposal to allow `~Copyable`
conformers on `IteratorProtocol` / `Sequence`. This is an active topic
in the noncopyable evolution roadmap but has not yet shipped.

Either path is NOT absorbable by the Wave-5+6 mechanisms.

**(e) Pattern-establishing 1/5**: low — adopting via (i) removes the
type from the iterator ecosystem, defeating the pattern; adopting via
(ii) is downstream of a stdlib evolution change that itself establishes
the pattern.

**(f) Existing alignment 5/5**: this is the **highest f-score in the
audit**. The IteratorHandle workaround is a *direct admission* in the
current code that the Iterator wants to be `~Copyable`. The split-handle
pattern is the workaround for the missing `~Copyable IteratorProtocol`
support. Once upstream lands, the workaround can be retired and the
Iterator gains its natural shape.

**Wave-5+6 readiness shape**: **Stdlib-protocol**. Same gating-decision
class as Row 11 but at the stdlib level, not the institute level — the
unblock requires upstream Swift Evolution.

**Score 12/30**: structural candidate strong on resource + alignment +
safety; cascade cost dominates the ranking because the gating decision
is outside the institute.

**Re-evaluation trigger**: when (or if) upstream Swift Evolution lands
`~Copyable IteratorProtocol` / `~Copyable Sequence` support. Track at
`swiftlang/swift-evolution` for proposals affecting `IteratorProtocol`
generics relaxation.

#### Row 14 — `Text.Line.Map`

**Location**:
`swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Line.Map.swift:21`.

**Verdict 2/30**: sorted `[Text.Position]` array of line-start offsets;
pure value type with **no resource correlation** (built once by
scanning content bytes, immutable thereafter under the current init).
The storage `[Text.Position]` is a stdlib `Array`; `~Copyable` adoption
would require migrating to a `~Copyable`-element container or to
`Storage.Pool.Inline`-style storage. Same Row-3-shape structural
barrier. The COW backing means accidental copy is cheap-in-practice;
the bug class is null.

**Not a candidate**. Reason: zero resource-correlation × stdlib-array
storage barrier; no safety win to motivate the structural redesign.

#### Row 15 — `Source.Cache`

**Location**:
`swift-foundations/swift-source/Sources/Source/Source.Cache.swift:33`.

**Verdict 1/30**: path-keyed `[String: [UInt8]]` content cache.
Storage is `Dictionary<String, [UInt8]>` — both keys and values are
Copyable-required by stdlib `Dictionary`. Adoption requires migrating
to a `~Copyable`-value container, which doesn't exist in the ecosystem
catalog at the necessary key/value generality. The doc-comment at line
14–17 explicitly names: *"`Cache` is a value type (`struct`) and is
`Sendable`. It does not provide internal synchronization — concurrent
mutation requires external coordination (e.g., wrapping in an actor)."*

The same Row-3-shape stdlib-container barrier applies. The cache's
single-owner semantic is real but the structural cost is decisive.

**Not a candidate**. Reason: stdlib-Dictionary storage barrier + the
shape is already explicitly documented as a value-type design choice.

#### Row 16 — `Kernel.Thread.Handle.Reference`

**Location**:
`swift-foundations/swift-threads/Sources/Thread Worker/Kernel.Thread.Handle.Reference.swift:64`.

**NOT-A-CANDIDATE (already a v1.2.0-pattern workaround)**: this `final
class @unsafe @unchecked Sendable` wrapper exists *specifically* to hold
a `~Copyable Kernel.Thread.Handle` inside a stdlib `[T]` for
orchestration-layer thread-pool drivers. The doc-comment at line 13–18
names the workaround explicitly: *"Reference wrapper for storing
`~Copyable` handle in arrays. This class allows storing
`Kernel.Thread.Handle` (which is `~Copyable`) in arrays and other
Copyable containers. The reference type is Copyable, but the inner
handle enforces exactly-once join semantics."*

This is the **same** L1-`~Copyable` / L3-Copyable bifurcation that
`path-type-ecosystem-model.md` documents for Path. The inner
`Kernel.Thread.Handle` IS already `~Copyable`; the Reference is
intentionally Copyable to bridge into stdlib containers. Flipping
Reference itself to `~Copyable` would defeat the whole point of having
it.

**Listed for completeness**: confirms the ecosystem is already
ANTICIPATING the stdlib-Array barrier and shipping the Copyable-wrapper
bridge pattern where needed. No new adoption work.

#### Row 17 — `Kernel.Thread.{Semaphore, Synchronization, Gate, Barrier}` (sync primitives)

**Locations** (all in `swift-foundations/swift-threads/Sources/`):

- `Kernel.Thread.Semaphore` — `Thread Semaphore/Kernel.Thread.Semaphore.swift:65`
- `Kernel.Thread.Synchronization<let N: Int>` — `Thread Synchronization/Kernel.Thread.Synchronization.swift:72`
- `Kernel.Thread.Gate` — `Thread Gate/Kernel.Thread.Gate.swift:54`
- `Kernel.Thread.Barrier` — `Thread Barrier/Kernel.Thread.Barrier.swift:56`

All declared as `public final class ... @unsafe @unchecked Sendable`.

**NOT-A-CANDIDATE (intentionally reference-typed)**: sync primitives are
*designed* to be shared across threads — that's their function.
`~Copyable` requires single ownership, which is exactly the wrong
model for a semaphore / barrier / gate that multiple threads must
hold concurrently. The reference-type-with-@unchecked-Sendable shape
is the correct pattern per
[MEM-SAFE-024] `@unchecked Sendable` semantic categories: Category C
*"compiler-limitation"* applied because the underlying primitive
(futex / pthread_cond_t / sem_t) is platform-defined Sendable but
stdlib's `Sendable` cannot express it natively.

**Listed for completeness**: clarifies that "currently-Copyable" is not
always a defect — sometimes it's a deliberate architectural choice
for cross-thread sharing. Auditors should recognize the
"sync-primitive-as-class" pattern and not propose `~Copyable` for it.

#### Row 18 — `Storage.{Slab, Pool, Heap, Arena, Split}` (heap-backed storage)

**Locations** (all in
`swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/`):

- `Storage.Slab` — `Storage.Slab.swift:36` (`public final class Slab`)
- `Storage.Pool` — `Storage.Pool.swift:58` (`public final class Pool`)
- `Storage.Heap` — `Storage.Heap.swift:35` (`public final class Heap: ManagedBuffer<Storage.Heap.Header, Element>`)
- `Storage.Arena` — `Storage.Arena.swift:46` (`public final class Arena`)
- `Storage.Split<Lane>` — `Storage.Split.swift:77` (`public final class Split<Lane: BitwiseCopyable>: ManagedBuffer<...>`)

**NOT-A-CANDIDATE (ManagedBuffer-backed, COW-shareable)**: these
heap-backed storage classes are designed for COW (copy-on-write) sharing
via ManagedBuffer. The `final class` shape is the correct backing for
COW value-type wrappers; converting them to `~Copyable` would defeat the
COW pattern (which the ecosystem-data-structures skill catalogues as
the canonical heap-storage shape per [DS-*]).

The companion `~Copyable` storage variants ALREADY exist at the same
layer for owned-storage use cases: `Storage.Inline`,
`Storage.Pool.Inline`, `Storage.Arena.Inline` (all `~Copyable` per
`Storage.Inline.swift:60`, etc.). The Copyable-class variants and the
`~Copyable`-struct variants are **co-existing alternatives**, not
candidates for unification.

**Listed for completeness**: same purpose as Row 17 — preempts a "why
isn't Storage.Pool ~Copyable?" follow-up.

### Wave-5+6 ecosystem-readiness — generalization or accident?

The fresh calibration data (Wave 5 + Wave 6 came in ~3× under
estimate) prompted this audit. The hypothesis was: maybe the ecosystem
has more ready-to-adopt corners, since Wave 5+6 absorbed the cascade
cheaply.

**The audit's finding is the opposite**: the Wave-5+6 cheap cascade
was a property of two *specific* structural shapes:

| Wave | Adopted type | Absorbable mechanism |
|---|---|---|
| Wave 5 | `Lint.Source.Parsed` | **Closure-inference** — Swift auto-propagated `borrowing` through 73 rule-closure parameters; no manual signature edits at most sites |
| Wave 6 | `Source.Manager` | **Inout-discipline** — every consumer site already used `inout Source.Manager`; the L1 type-shape change absorbed at the type declaration only |

These two mechanisms are NOT generic — they apply when the cascade
shape matches. Survey results show:

- **Closure-inference shape**: rare in the residual Copyable surface.
  Most candidates (Parser.Compiled, Iterator, Map, Cache) flow through
  stored properties or container backings, not through closure-typed
  rule witnesses.
- **Inout-discipline shape**: also rare. Most residual candidates are
  stored in containers (`[T]`, `[K:V]`) or in protocol witnesses, not
  threaded `inout` through a top-level run loop.

**The dominant residual shape is stdlib-protocol / stdlib-container
barrier** (Rows 11–15). These cascades are NOT absorbable by Wave-5+6
mechanisms; they require structural API redesign at the protocol or
container level. This is the same pattern as v1.2.0's Row 3 (`Lint.Finding`
+ `Lint.Run.Outcome`) — sharpened to recognise stdlib-Array storage as
the structural barrier.

**Generalization**: Wave-5+6's cheap cascade is the **exception** within
the Copyable residual, not the rule. The fresh calibration is NOT a
license to expand the recommendation set — it should NOT be cited to
justify adopting candidates whose cascade shape differs structurally
from Wave 5 / Wave 6.

### Structural enablers — gating decisions that would unblock candidates

Per v1.2.0 Row 3 pattern, candidates gated on a *separate* design
decision are listed below with the gating decision named. The audit
**does not** recommend pitching these gating decisions; it documents
which downstream candidates would unblock when (if) the gates open.

| Gating decision | Candidates unblocked | Authority |
|---|---|---|
| `Parser.Protocol: ~Copyable` (institute-side; Tier-3 cross-package parser-stack redesign) | Row 11 `Parser.Machine.Compiled`, Row 12 `Parser.Machine.Prepared` (would be re-evaluated), 30+ parser combinators across the parser stack | swift-parser-primitives owners |
| Upstream Swift Evolution: `~Copyable` `IteratorProtocol` / `Sequence` | Row 13 `File.Directory.Contents.Iterator` + IteratorHandle workaround retirement; ecosystem-wide iterator-shape simplification | swift-evolution |
| Ecosystem `~Copyable`-friendly Dictionary / Map container | Row 15 `Source.Cache`; future caches and registries | swift-storage-primitives / swift-collection-primitives owners |
| Ecosystem callback-emission or `Storage.Pool.Inline`-element `[T]` analog (the v1.2.0 Row 3 emission-pattern decision) | Row 14 `Text.Line.Map` (if `[Text.Position]` storage migrates); v1.2.0 Row 3 (`Lint.Finding` stream / `Lint.Run.Outcome`) | swift-linter-primitives owners (already in flight per v1.2.0) |

These are NOT recommendations for the institute to pursue — they are
landscape annotations for future research-doc readers.

---

## Prior Art (per [RES-021])

Prior art on `~Copyable` adoption beyond the linter draws on the same
canonical sources as v1.2.0 plus additional ecosystem-scoped material.

### Rust ownership across resource domains

Beyond `std::fs::File` (cited in v1.2.0), Rust's standard library
applies move-only semantics broadly:

- `std::process::Child` — move-only process handle; matches
  `Process.Handle: ~Copyable` (already adopted).
- `std::net::TcpStream` — move-only socket; matches
  `Sockets.TCP.Connection: ~Copyable` (already adopted).
- `std::thread::JoinHandle<T>` — move-only thread handle; matches
  `Kernel.Thread.Worker: ~Copyable` (already adopted) and the
  `Kernel.Thread.Handle` + `.Reference` bridge (Row 16).
- `std::fs::ReadDir: Iterator` — directory iterator IS move-only AND
  conforms to Rust's `Iterator` trait. Rust's `Iterator` does NOT
  require `Copy` on `Self` (unlike Swift's `IteratorProtocol` requiring
  Copyable). This is the **direct upstream gating decision** that Row
  13 (`File.Directory.Contents.Iterator`) is waiting on for Swift.

**Contextualization**: Rust's `Iterator` trait was designed from day-1
to support move-only iterators because Rust's ownership model
*required* it. Swift's `IteratorProtocol` is older than `~Copyable`;
its Copyable-only assumption is a historical artefact. The Swift
Evolution path to relax this is the institute's gating dependency for
Row 13.

### Linear Haskell and parser combinator state

Linear Haskell's `Parser` types model parser state as linear: the
`Parser :: 1 -> Input -> Result` arrow consumes input exactly once.
Compiled parsers (e.g., the PEG `Compiled p` wrapper) are
NOT linear, however — they're shared across parse calls. This matches
Row 11's analysis: the Compiled-shape parser is single-owner
(`~Copyable`-shaped), while the Parser-trait-conforming
combinator-shape is shared (Copyable-shaped). Linear Haskell models
this with multiplicity polymorphism (`p :: m -> Input -> Result`); the
m can be 1 for compiled / Unrestricted for combinator. Swift's
`~Copyable` is a per-type opt-in, so the bifurcation has to be made at
type definition (which Row 11 surfaces as the structural barrier).

### C++ unique_ptr / shared_ptr split in resource libraries

C++ libraries that ship both move-only and shared variants of
resource-bearing types (e.g., `std::unique_ptr<T>` and
`std::shared_ptr<T>`) commonly use a **single underlying impl** + two
ownership wrappers. The institute's analog is:

- `Path_Primitives.Path` (`~Copyable`) vs `Paths.Path` (Copyable) per
  `path-type-ecosystem-model.md` — same single-impl + two-wrapper
  pattern.
- `Parser.Machine.Compiled` (single-owner) vs `Parser.Machine.Prepared`
  (shared, immutable, Sendable) — the same pattern in the parser
  domain, already implemented (Row 12).
- `Kernel.Thread.Handle` (`~Copyable`) vs `Kernel.Thread.Handle.Reference`
  (Copyable bridge) — the same pattern in the threads domain (Row 16).

**Contextualization**: the institute is already correctly applying the
"two ownership flavors with a single underlying impl" pattern at the
boundaries where it matters. The audit confirms there are no missing
flips in this dimension — the bifurcations exist where they should.

### Swift Evolution proposals

(Same list as v1.2.0 — no new SE proposals affecting ecosystem-corners
candidates have landed between 2026-05-13 v1.2.0 and the audit date
2026-05-13.)

- [SE-0390 Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0427 Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0432 Borrowing and consuming pattern matching for noncopyable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md)
- [SE-0437 Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- [SE-0499 Support `~Copyable` and `~Escapable` in Standard Library Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)

The `~Copyable IteratorProtocol` / `~Copyable Sequence` proposal that
would unblock Row 13 has NOT been ratified at the audit date; track at
`swiftlang/swift-evolution` for future drafts.

---

## Empirical Validation Notes (per [RES-025])

Per [RES-025], the audit is analysis-only; cognitive-dimensions framing
applies to the candidate ranking rather than to a benchmark.

| Dimension | Audit application |
|---|---|
| **Visibility** | The audit foregrounds the Wave-5+6 readiness shape table; readers can see at-a-glance which cascade-shape each candidate inhabits |
| **Consistency** | Row IDs continue v1.2.0's numbering (11+); the scoring grid, axis definitions, and inversion convention match v1.2.0 exactly |
| **Viscosity** | The "Not-a-candidate" rows (16, 17, 18) are an explicit category for "already considered, deliberate Copyable design" — prevents future readers from re-asking the question |
| **Role-expressiveness** | Each candidate row names the structural barrier explicitly (Stdlib-protocol / Stdlib-array / Cross-thread-shared / Codable-wire-format) rather than abstracting to a generic "high cascade" verdict |
| **Error-proneness** | The Wave-5+6 generalization-or-accident section (above) is a direct counter-prompt to "the calibration says cheap, so adopt more" — closes off the foreseeable wrong inference |
| **Abstraction level** | The audit ADDs rows but does NOT add new scoring axes; the framework remains the v1.2.0 framework |

Empirical follow-up at adoption time (for any candidate that gets the
structural-barrier gate opened in the future) should mirror the v1.2.0
plan: build a minimal external-package spike per [RES-021]; confirm the
specific protocol-conformance / container-storage interaction; measure
the residual cost.

---

## Outcome

**Status**: RECOMMENDATION

### Ranked Top Picks

| Rank | Type | Score | Recommendation |
|---|---|---|---|
| — | **None** | — | **The audit's principal finding: there are NO new top-tier ~Copyable adoption candidates beyond Rows 1+2.** The ecosystem has already adopted `~Copyable` on every type where the adoption is cheap and the structural shape allows. Residual Copyable types are either (a) intentionally Copyable for cross-thread sharing / COW backing / stdlib-container bridging, or (b) structurally gated on a separate decision (stdlib protocol, stdlib container, parser-protocol relaxation). |

**Top finding rationale**: Wave 5 + Wave 6 came in cheap NOT because
the ecosystem has many cheap-to-adopt corners; they came in cheap
because the institute had **already** built the surrounding structural
support (closure-typed rule witnesses, inout-disciplined consumer
sites) before the type-level adoption. That structural support is
*specific* to the linter / source-manager shape. Applying the same
Wave-5+6 calibration to other ecosystem corners would mis-predict
cascade cost — Parser.Compiled, Iterator, Map, and Cache all sit
behind structural barriers (Parser.Protocol, IteratorProtocol,
stdlib-Array storage, stdlib-Dictionary storage) that the Wave-5+6
mechanisms do NOT absorb.

### Highest-Scoring Structural Candidates (Conditional on Gating Decision)

The audit identifies the following STRUCTURAL candidates — scoring
high enough on substantive axes (a/b/c/e/f) to be worth recording,
but blocked on a gating structural decision documented inline. NONE
of these are recommended for adoption without the gating decision
landing first.

| Rank | Type | Score | Gating decision | Notes |
|---|---|---|---|---|
| Structural 1 | **`Parser.Machine.Compiled`** (Row 11) | 14/30 | `Parser.Protocol: ~Copyable` relaxation across the parser stack (Tier-3 cross-package decision) | Highest-scoring structural candidate. Same shape as v1.2.0 Row 1 (Lint.Source.Parsed) — reference-typed Cache wrapped in Copyable boundary, smuggling single-owner semantic. Adopt-if-and-when the protocol gate opens. |
| Structural 2 | **`File.Directory.Contents.Iterator`** (Row 13) | 12/30 | Upstream Swift Evolution: `~Copyable IteratorProtocol` / `Sequence` | Strongest resource-correlation (5/5) and existing-alignment (5/5) in the audit. The IteratorHandle workaround at `File.Directory.Contents.IteratorHandle.swift:18` is a *direct admission* that the Iterator wants to be `~Copyable`. Watch upstream. |

### Deferred / Not-Recommended

| Type | Score | Why deferred | Re-evaluation trigger |
|---|---|---|---|
| `Parser.Machine.Prepared` (Row 12) | 6/30 | Designed as the SHARED immutable Sendable variant of Compiled; the Compiled/Prepared bifurcation IS the architectural pattern | Not expected to flip — by design |
| `Text.Line.Map` (Row 14) | 2/30 | Pure value, no resource; stdlib-Array storage barrier | Not expected to flip |
| `Source.Cache` (Row 15) | 1/30 | Stdlib-Dictionary storage barrier; explicit Sendable-value-type design choice | Stdlib `~Copyable`-value Dictionary support (no path) |
| `Kernel.Thread.Handle.Reference` (Row 16) | NOT-A-CANDIDATE | EXISTS specifically as the Copyable bridge over `~Copyable Kernel.Thread.Handle` for `[T]` storage | Not expected to flip — by design |
| `Kernel.Thread.{Semaphore,Synchronization,Gate,Barrier}` (Row 17) | NOT-A-CANDIDATE | Cross-thread-shared sync primitives; reference-typed by intentional design per [MEM-SAFE-024] Category C | Not expected to flip — by design |
| `Storage.{Slab,Pool,Heap,Arena,Split}` (Row 18) | NOT-A-CANDIDATE | ManagedBuffer-backed COW heap storage; companion `~Copyable Storage.{Inline,Pool.Inline,Arena.Inline}` already exists at the same layer | Not expected to flip — by design |

### Adoption-readiness summary

| Bucket | Count | Action |
|---|---|---|
| Already `~Copyable` (control set + Wave 5 + Wave 6) | ~25 types across 13 packages | None needed |
| New cheap-to-adopt candidates this audit identifies | **0** | None |
| Structural candidates blocked on gating decisions | 2 (Rows 11, 13) | Watch for upstream / institute-side gating decisions; adopt-if-and-when |
| Structurally Copyable by design (not candidates) | 3 row-groups (16, 17, 18) | Documented for completeness; no action |

### Per [HANDOFF-039] / [RES-027] notes

The v1.2.0 predecessor remains the authoritative scoring framework for
adopted Rows 1 + 2 and deferred Row 3. THIS audit extends to ecosystem
corners; the predecessor is NOT superseded.

Per [RES-027] loose-end follow-up: every Open Question / Future Work
item in this doc is a *direction*, not a *premise* — none of the
deferred candidates carry forward as a load-bearing constraint on
adjacent design conversations. The audit's principal finding ("no new
top-tier candidates") is itself the deliverable; no verification spike
is required at write time.

---

## Open Questions

| # | Question | Status | Resolution path |
|---|---|---|---|
| Q1 | Should the institute pitch `Parser.Protocol: ~Copyable` (a Tier-3 cross-package parser-stack redesign) to unblock Row 11 and the parser combinator family? | DEFERRED. The audit does NOT recommend pursuing this; the cost-vs-benefit (30+ combinator types affected at L1, more downstream) is high and Row 11's payback is moderate. Revisit if a *second* parser-stack consumer surfaces with strong borrow-by-default needs per [RES-018] | Future research IF the second-consumer hurdle is cleared |
| Q2 | Should the institute follow / contribute to upstream Swift Evolution proposals for `~Copyable IteratorProtocol` / `Sequence`? | RECOMMEND watch-only. The institute has a clear stake (Row 13 unblocks; ecosystem-wide iterator-shape simplification); upstream contribution beyond observation is out of scope for this audit | Track `swiftlang/swift-evolution` for relevant pitches; engage at pitch-review time if the trajectory aligns |
| Q3 | Does the v1.2.0 Row 3 emission-pattern investigation (separate decision about `[Lint.Finding]` vs callback vs Inline.Array) also unblock Row 14 (`Text.Line.Map`)? | UNLIKELY but worth noting. The Text.Line.Map adoption has no resource-correlation (score 2/30) — even if the emission-pattern decision lands a `~Copyable`-element container, the adoption motivation for Text.Line.Map remains weak | Re-evaluate IF a callback-emission pattern lands AND Text.Line.Map develops a resource-correlation use case (e.g., owning a memory-mapped backing buffer) |
| Q4 | Are there candidates the audit missed in unexplored corners — e.g., swift-json's parser state, swift-msgpack, swift-yaml, swift-plist, swift-html, swift-css, swift-uri, swift-http-headers? | Survey was extensive but not exhaustive. Spot-checked corners (swift-plist, swift-json, swift-source) confirm the dominant pattern is Sendable-value-types (no resource correlation; pure data trees). Format-parser packages mostly produce pure-value AST output; they are not resource-handle-shaped | Spot-check additional format-parser packages when adding new ones; the pattern is unlikely to shift |
| Q5 | Is the Wave-5+6 calibration "ecosystem-readiness benefit" reusable for future adoption arcs, or session-specific to the linter / source-manager shape? | RESOLVED INLINE (§ "Wave-5+6 ecosystem-readiness — generalization or accident?"). The cheap cascade was a property of two specific structural shapes; the dominant residual is stdlib-protocol / stdlib-container barrier. The calibration is NOT a general license — it must be re-verified per-candidate against the cascade-shape table | Cite this section in any future audit that wants to invoke Wave-5+6 cost-prediction |

---

## References

### Internal research (per [RES-019] step-0 grep)

- `swift-institute/Research/2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md` (v1.2.0 RECOMMENDATION, 2026-05-13) — **predecessor**; six-axis scoring framework + Rows 1–10
- `swift-institute/Research/noncopyable-ecosystem-state.md` (v1.0.0 DECISION, 2026-04-02) — canonical `~Copyable` state-of-ecosystem
- `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` (v1.3.0 RECOMMENDATION, 2026-05-03) — empirical SE-0499 verification
- `swift-institute/Research/path-type-ecosystem-model.md` (2026-04-18) — L3-Copyable-wraps-L1-`~Copyable` reference architectural shape
- `swift-institute/Research/noncopyable-ergonomics-compiler-state.md` (v3.0.0 SUPERSEDED, 2026-03-31) — foundational pain-point survey
- `swift-institute/Research/nested-view-vs-borrowed-naming.md` — borrowed-view companion naming
- `swift-institute/Research/frozen-noncopyable-deinit-tradeoff.md` — `frozen` + `~Copyable` + deinit interaction
- `swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md` — `_owned` extraction pattern
- `swift-institute/Research/view-vs-span-borrowed-access-types.md` — borrowed access type bifurcation pattern
- `swift-institute/Research/withUnsafe-borrowing-noncopyable-pattern-reach-survey.md` — `withUnsafe...` + borrowing + ~Copyable pattern survey
- `swift-institute/Research/buffer-arena-conditional-copyable.md` — conditional Copyable on Buffer types

### Skill requirements

- [MEM-COPY-001] / [MEM-COPY-001a] — noncopyable type declaration + deinit immutability
- [MEM-COPY-004] — extension constraints for `~Copyable` types
- [MEM-COPY-005] — nested accessor pattern incompatibility
- [MEM-COPY-006] — `~Copyable` propagation gotchas
- [MEM-COPY-014] — native ownership for resource types
- [MEM-OWN-001] / [MEM-OWN-002] — consuming / borrowing parameters
- [MEM-OWN-010] / [MEM-OWN-011] / [MEM-OWN-012] — three canonical transfer patterns
- [MEM-LINEAR-001] / [MEM-LINEAR-002] — exactly-once / at-most-once types
- [MEM-SAFE-024] — `@unchecked Sendable` semantic categories (Category C "compiler-limitation" for sync primitives)
- [IMPL-063] — synchronization-as-ownership (3× write-throughput finding)
- [IMPL-070] — Layer 0/1/2 model
- [RES-018] — premature primitive anti-pattern (second-consumer check)
- [RES-019] — step-0 internal research grep
- [RES-020] — research tiers; this doc is Tier 2 per ecosystem-wide scope + reversible-recommendation commitment
- [RES-021] — prior art survey + verification spike requirement
- [RES-022] — structural correctness over diff size in recommendation framing
- [RES-023] — empirical-claim verification for dependent-package state (every file:line in this doc verified against current source on 2026-05-13)
- [RES-025] — empirical validation via Cognitive Dimensions
- [RES-027] — loose-end follow-up requires extant or immediate experiment
- [HANDOFF-013] / [HANDOFF-013a] — prior-research grep discipline
- [HANDOFF-019] — commit-as-you-go for multi-phase refactors
- [HANDOFF-039] — research-doc supersession discipline
- [ARCH-LAYER-001] — five-layer dependency direction
- [ARCH-LAYER-008] — correctness as sole driver of split/reshape during pre-1.0
- [DS-*] — ecosystem-data-structures catalog (heap-backed storage as COW classes)

### Swift Evolution

- [SE-0390 — Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) (Swift 5.9)
- [SE-0427 — Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) (Swift 6.0)
- [SE-0429 — Partial Consumption of Noncopyable Values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0429-partial-consumption.md) (Swift 6.0)
- [SE-0432 — Borrowing and consuming pattern matching for noncopyable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md) (Swift 6.0)
- [SE-0437 — Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) (Swift 6.0)
- [SE-0499 — Support `~Copyable` and `~Escapable` in Standard Library Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) (Implemented Swift 6.4)

### Prior art (external)

- Rust `std::process::Child`: [doc.rust-lang.org/std/process/struct.Child.html](https://doc.rust-lang.org/std/process/struct.Child.html) — move-only process handle
- Rust `std::net::TcpStream`: [doc.rust-lang.org/std/net/struct.TcpStream.html](https://doc.rust-lang.org/std/net/struct.TcpStream.html) — move-only socket
- Rust `std::thread::JoinHandle`: [doc.rust-lang.org/std/thread/struct.JoinHandle.html](https://doc.rust-lang.org/std/thread/struct.JoinHandle.html) — move-only thread handle
- Rust `std::fs::ReadDir`: [doc.rust-lang.org/std/fs/struct.ReadDir.html](https://doc.rust-lang.org/std/fs/struct.ReadDir.html) — move-only directory iterator (the upstream-Iterator-trait-without-Copy precedent for Row 13)
- C++ `std::unique_ptr` vs `std::shared_ptr`: [cppreference.com/w/cpp/memory/unique_ptr](https://en.cppreference.com/w/cpp/memory/unique_ptr) / [cppreference.com/w/cpp/memory/shared_ptr](https://en.cppreference.com/w/cpp/memory/shared_ptr) — single-impl + two-wrapper pattern
- Linear Haskell, *Linear types can change the world!* (Bernardy, Boespflug, Newton, Peyton Jones, Spiwack 2018): [arxiv.org/abs/1710.09756](https://arxiv.org/abs/1710.09756) — multiplicity polymorphism foundation

### File:line citations verified 2026-05-13 (per [RES-023])

Every file:line citation in the audit was verified against current
source on 2026-05-13:

- `swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compiled.swift:37` ✓
- `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90` ✓
- `swift-foundations/swift-file-system/Sources/File System Core/File.Directory.Contents.Iterator.swift:15` ✓
- `swift-foundations/swift-file-system/Sources/File System Core/File.Directory.Contents.IteratorHandle.swift:18` ✓
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Line.Map.swift:21` ✓
- `swift-foundations/swift-source/Sources/Source/Source.Cache.swift:33` ✓
- `swift-foundations/swift-threads/Sources/Thread Worker/Kernel.Thread.Handle.Reference.swift:64` ✓
- `swift-foundations/swift-threads/Sources/Thread Semaphore/Kernel.Thread.Semaphore.swift:65` ✓
- `swift-foundations/swift-threads/Sources/Thread Synchronization/Kernel.Thread.Synchronization.swift:72` ✓
- `swift-foundations/swift-threads/Sources/Thread Gate/Kernel.Thread.Gate.swift:54` ✓
- `swift-foundations/swift-threads/Sources/Thread Barrier/Kernel.Thread.Barrier.swift:56` ✓
- `swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.Slab.swift:36` ✓
- `swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.Pool.swift:58` ✓
- `swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.Heap.swift:35` ✓
- `swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.Arena.swift:46` ✓
- `swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.Split.swift:77` ✓
- All control-set citations (Path, File.*, Process.Handle, Sockets.TCP.Connection, Kernel.*, Async.*, Buffer.*, Storage.*Inline, Input.*, String, Lexer.Scanner, Source.Manager) ✓
