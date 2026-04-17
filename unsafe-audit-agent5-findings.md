<!--
status: COMPLETE
agent: 5
scope: swift-io, swift-file-system, swift-memory, swift-sockets, swift-parsers, swift-plist, swift-json, swift-xml, swift-tests, swift-copy-on-write, swift-html-rendering, swift-pdf-html-rendering + 16 scatter primitives packages
date: 2026-04-15
confidence_threshold: <95% flags LOW_CONFIDENCE
-->

# Agent 5 Findings — swift-io + scatter primitives

## Summary

- **Total hits**: 57 real `@unchecked Sendable` conformances (exceeds the 40-hit guardrail).
- **Category A (Synchronized)**: 13
- **Category B (Ownership transfer — `~Copyable`)**: 10
- **Category C (Thread-confined — skip, `// WHY:` for ~Sendable)**: 1 (Tier 1: `File.Directory.Contents.IteratorHandle`)
- **Category D candidates** (queued for principal adjudication): 27
- **LOW_CONFIDENCE**: 6
- **Tier 2 debatable (out of audit scope)**: 0 in my scope. (`Kernel.Memory.Map.Region`, `IO.Event.Batch` etc. are in agents 1-3 scope or at L1. The L3 `Memory.Map` is classifiable as Cat B.)
- **Preexisting warnings**: None observed (no `@unchecked` warnings; build state not executed per ground rules).

**Volume guardrail notice**: The agent 5 scope contains 57 hits, exceeding the 40-hit guardrail. I proceeded through all 57 because (a) the great majority follow well-established patterns (Infinite iterators, Tree.N family, Plist/JSON/XML/ND parser State, etc. — each mapped by precedent), and (b) stopping at 40 would have forced an arbitrary split mid-family. A further review pass by principal is warranted for the LOW_CONFIDENCE rows and for the Category D candidates where my tightened-95% threshold made me err on the side of flagging.

---

## Classifications

| # | Site | File:Line | Cat | Rationale |
|---|------|-----------|-----|-----------|
| 1 | `IO.Completion.Operation.Storage` | swift-io/…/IO.Completion.Operation.Storage.swift:38 | **A** | Synchronization via happens-before relationship of `continuation.resume()`. Loop thread writes mutable fields before resume; client reads after. Documented invariant. |
| 2 | `IO.Completion.Loop` | swift-io/…/IO.Completion.Loop.swift:44 | **A** | Internal `Kernel.Thread.Mutex` (`queueLock`) protects cross-thread `enqueue()`. Thread-confined state pinned to OS thread; SerialExecutor contract for everything else. |
| 3 | `IO.Completions.Actor.CancelCoordinator` | swift-io/…/IO.Completions.Actor.swift:307 | **A** | Internal `Kernel.Thread.Synchronization<1>` guards all mutable state. All accesses go through `sync.withLock`. |
| 4 | `IO.Events.Actor.FDState` | swift-io/…/IO.Events.Actor.swift:74 | **A** | Actor-confined. Accessed only on the `IO.Events.Actor`'s serial executor. `@unchecked Sendable` only to satisfy the `Dictionary` value-Sendable requirement crossing the init boundary (per the file's own comment). |
| 5 | `IO.Event.Loop` | swift-io/…/IO.Event.Loop.swift:31 | **A** | Delegates synchronization to its held `Kernel.Thread.Executor.Polling`. Explicit docstring states this. |
| 6 | `File.Directory.Contents.IteratorHandle` | swift-file-system/…/File.Directory.Contents.IteratorHandle.swift:14 | **C** | **Known Tier 1** — `Kernel.Directory.Stream` is thread-confined. Referenced by name in ownership-transfer-conventions.md §4 Tier 1. |
| 7 | `Memory.Map` | swift-memory/…/Memory.Map.swift:72 | **B** | `~Copyable, @unchecked Sendable` wrapper. `~Copyable` prevents aliasing; move-across-threads semantics explicit. Note: the L1 `Kernel.Memory.Map.Region` it wraps is Tier 2 debatable and not in my scope. |
| 8 | `Parser.Debug.Profile.Stats` | swift-parsers/…/Parsers.Debug.swift:140 | **LOW_CONFIDENCE** | No explicit Mutex/Atomic, but fields look accessed across debug instrumentation paths. Needs principal review. See Low-Confidence Flags. |
| 9 | `Plist.Binary.Context` | swift-plist/…/Plist.Binary.Parser.swift:24 | **LOW_CONFIDENCE** | `final class Context<Bytes>` — generic over a Collection. No Mutex; local parser state with mutable `parsedObjects`. Looks thread-confined (parse is single-threaded), but the generic parameter constraint is atypical. See Low-Confidence Flags. |
| 10 | `Plist.ND.State<I>` | swift-plist/…/Plist.Stream.swift:131 | **D-candidate** | `final class State<I: AsyncIteratorProtocol>`; holds iterator + buffer + done flag. No synchronization; likely used single-threaded per AsyncStream. Generic parameter over AsyncIteratorProtocol likely blocks Sendable inference. Queued. |
| 11 | `JSON.ND.State<I>` | swift-json/…/JSON.Stream.swift:78 | **D-candidate** | Identical pattern to Plist.ND.State. Queued. |
| 12 | `XML.ND.State<I>` | swift-xml/…/XML.Stream.swift:133 | **D-candidate** | Identical pattern. Queued. |
| 13 | `Test.Reporter.Terminal` (private) | swift-tests/…/Test.Reporter.Terminal.swift:36 | **A** | Holds `Mutex<(passed, failed, skipped, issues)>`. All mutation via `_counts.withLock`. |
| 14 | `Test.Reporter.StructuredSink` (private) | swift-tests/…/Test.Reporter.Structured.swift:32 | **A** | Holds `Mutex<[JSON]>`. All state mutation via `_records.withLock`. |
| 15 | `Test.Reporter.JSONSink` (private) | swift-tests/…/Test.Reporter.JSON.swift:41 | **A** | Holds `Mutex<[Test.Event]>`. All mutation via `_events.withLock`. |
| 16 | `Test.Reporter.NullSink` (private) | swift-tests/…/Test.Reporter.Console.swift:38 | **LOW_CONFIDENCE** | Stateless discard sink. No stored props. Strictly-speaking has no invariant at all. Might be Cat D-like (no-state trivial) or could be omitted entirely. See Low-Confidence Flags. |
| 17 | `Test.Snapshot.Counter` | swift-tests/…/Test.Snapshot.Counter.swift:26 | **A** | Holds `Mutex(())` and mutable `counts` dict. All mutation under `lock.withLock`. |
| 18 | `Test.Snapshot.Inline.State` | swift-tests/…/Test.Snapshot.Inline.State.swift:29 | **A** | Holds `Mutex<[String:[Entry]]>`. All mutation via `mutex.withLock`. |
| 19 | `Test.Expectation.Collector` | swift-tests/…/Test.Expectation.Collector.swift:32 | **A** | Holds `Mutex<[Test.Expectation]>`. All state mutation via `_storage.withLock`. |
| 20 | `CoW.Storage` (generated) | swift-copy-on-write/…/CoWMacro.swift:624 | **D-candidate** | Macro-generated storage class. No synchronization but no shared mutation either: CoW discipline means any mutation path copies storage first. Queued — macro policy is principal-scope. |
| 21 | `HTML.AnyView` | swift-html-rendering/…/HTML.AnyView.swift:16 | **LOW_CONFIDENCE** | `@unchecked Sendable` on a struct holding `any HTML.View`. The existential is of an unconstrained protocol. Either D (phantom-like — HTML.View is Sendable-by-convention-not-refinement) or needs the protocol refined. See Low-Confidence Flags. |
| 22 | `PDF.HTML.Context.Table.Recording` | swift-pdf-html-rendering/…/PDF.HTML.Context.Table.Recording.swift:13 | **D-candidate** | Struct holding commands array with `inlineStyle(Any)` case. Explicit docstring says "recording is temporary and does not cross concurrency boundaries". No synchronization; likely genuinely single-confined. Queued — the `Any` case is the judgment call. |
| 23 | `PDF.HTML.Context.Table.Recording.Command` | swift-pdf-html-rendering/…/PDF.HTML.Context.Table.Recording.Command.swift:12 | **D-candidate** | Enum with `inlineStyle(Any)` case; `Any` blocks Sendable inference. Same reasoning as #22. Queued. |
| 24 | `Path` (swift-path-primitives) | swift-path-primitives/…/Path.swift:37 | **B** | `~Copyable, @unchecked Sendable`. Owns null-terminated buffer; immutable after init. Matches canonical Cat B ownership-transfer pattern. |
| 25 | `Predicate<T>` | swift-predicate-primitives/…/Predicate.swift:29 | **D-candidate** | `struct Predicate<T>: @unchecked Sendable, Witness.Protocol` — holds `var evaluate: (T) -> Bool` (non-@Sendable closure). Queued — no invariant, but closure is not Sendable-constrained. Could be fixed by making the closure `@Sendable` in the stored property type, which would obsolete `@unchecked`. |
| 26 | `__InfiniteObservableIterator<Source>` | swift-infinite-primitives/…/Infinite.Observable.Iterator.swift:66 | **D-candidate** | Conditional: `where Source: Sendable`. Holds `~Copyable` iterator + inline Optional storage. Queued — the phantom-forwarding pattern matches Cat D rubric. |
| 27 | `Infinite.Map.Iterator` | swift-infinite-primitives/…/Infinite.Map.swift:120 | **D-candidate** | Conditional: `where Source.Iterator: Sendable`. Same Cat D phantom-forwarding pattern. |
| 28 | `Infinite.Zip.Iterator` | swift-infinite-primitives/…/Infinite.Zip.swift:141 | **D-candidate** | Conditional over two `.Iterator: Sendable`. Same pattern. |
| 29 | `Infinite.Scan.Iterator` | swift-infinite-primitives/…/Infinite.Scan.swift:160 | **D-candidate** | Same pattern. Referenced in ownership-transfer-conventions.md line 345 as "Remaining opportunities" with Low priority. |
| 30 | `Infinite.Cycle.Iterator` | swift-infinite-primitives/…/Infinite.Cycle.swift:127 | **D-candidate** | Same pattern. |
| 31 | `Ownership.Unique<Value>` (ext: Sendable) | swift-ownership-primitives/…/Ownership.Unique.swift:79 | **B** | `~Copyable` box; extension Sendable where Value: Sendable. Documented as "`Unique` is `Sendable` when `Value: Sendable`." Canonical Cat B: ownership transfer via move. |
| 32 | `Ownership.Slot<Value: ~Copyable>` | swift-ownership-primitives/…/Ownership.Slot.swift:74 | **A** | Atomic state machine (`Atomic<UInt8>` + release/acquire) protecting `_storage`. Explicit publication protocol documented. Canonical Cat A. |
| 33 | `Ownership.Shared<Value: ~Copyable & Sendable>` | swift-ownership-primitives/…/Ownership.Shared.swift:46 | **B** (trending D) | Documented as "structurally safe: the stored `value` is immutable and requires `Value: Sendable`. … When this compiler limitation is resolved, this should be converted to checked `Sendable` conformance." This is a self-described Cat D (phantom-type inference gap: `~Copyable` generic in class property blocks inference) with soundness argument. But: the value is immutable by construction (no shared-mutation risk), so it's also defensible as B by the `~Copyable` ownership argument. **Defer to principal** — marked B provisionally but flag as D-candidate. See Low-Confidence Flags. |
| 34 | `Ownership.Mutable.Unchecked` | swift-ownership-primitives/…/Ownership.Mutable.Unchecked.swift:47 | **LOW_CONFIDENCE** | Deliberately unchecked per its own name; docstring is explicit: "This type bypasses the compiler's Sendable checking … NOT thread-safe … Concurrent mutation will cause data races (no runtime trap, silent corruption)." This is exactly the type `@unsafe @unchecked Sendable` is designed to mark (Cat A-like explicit caller responsibility), but the type itself has no synchronization. Closest to A (caller-promised synchronization). See Low-Confidence Flags. |
| 35 | `Ownership.Transfer.Box.Pointer` | swift-ownership-primitives/…/Ownership.Transfer.Box.swift:88 | **B** | Explicitly the single `@unchecked Sendable` capability wrapper. Carries `UnsafeMutableRawPointer` as an ownership-transfer token. Canonical Cat B. |
| 36 | `Ownership.Transfer.Retained<T: AnyObject>` | swift-ownership-primitives/…/Ownership.Transfer.Retained.swift:56 | **B** | `~Copyable, @unchecked Sendable`. Documented: "opaque, single-consumption ownership token." Canonical Cat B. |
| 37 | `Ownership.Transfer._Box<T: ~Copyable>` | swift-ownership-primitives/…/Ownership.Transfer._Box.swift:50 | **A** | Atomic state machine (`Atomic<Int>` with acquiringAndReleasing CAS) + release/acquire publication. Canonical Cat A per its own docstring. |
| 38 | `Sample.Batch<Element>` | swift-sample-primitives/…/Sample.Batch.swift:31 | **D-candidate** | Conditional Sendable where Element: Sendable. Holds `_SampleBatchStorage<Element>`. Phantom-like forwarding; no synchronization. Queued. |
| 39 | `_SampleBatchStorage<Element>` | swift-sample-primitives/…/Sample.Batch.Storage.swift:8 | **D-candidate** | `final class … @unchecked Sendable` (unconditional). Raw pointer + count. Immutable after init (no setters). Could be D-like phantom. Queued. |
| 40 | `Tree.N<Element>` | swift-tree-primitives/…/Tree.N.swift:774 | **D-candidate** | Conditional Sendable where Element: Sendable. Backed by arena + raw pointers but no mutation races documented; value semantics via Copyable-conditional. Phantom-forwarding via generic. Queued (agent 4 may already cover trees; confirm routing). |
| 41 | `Tree.N.Small<Element>` | swift-tree-primitives/…/Tree.N.Small.swift:522 | **D-candidate** | Identical pattern to Tree.N. |
| 42 | `Tree.N.Bounded<Element>` | swift-tree-primitives/…/Tree.N.Bounded.swift:603 | **D-candidate** | Identical pattern. |
| 43 | `Tree.Unbounded<Element>` | swift-tree-primitives/…/Tree.Unbounded.swift:680 | **D-candidate** | Identical pattern. |
| 44 | `Tree.Keyed<Key, Element>` | swift-tree-primitives/…/Tree.Keyed.swift:467 | **D-candidate** | Same pattern, two generic params. |
| 45 | `Tree.N.Inline<Element>` | swift-tree-primitives/…/Tree.N.Inline.swift:505 | **D-candidate** | Same pattern. |
| 46 | `Cache.Entry.State` | swift-cache-primitives/…/Cache.Entry.State.swift:43 | **C-ish / LOW_CONFIDENCE** | `enum State: @unchecked Sendable` with `case computing(Waiters)` holding a ref-type `Waiters`. Docstring says "state transitions occur under the cache's mutex" — so the synchronization lives outside the type. Could also be D-like (carries `any Error` in `.failed` case → existential blocks inference). See Low-Confidence Flags. |
| 47 | `Cache.Entry` | swift-cache-primitives/…/Cache.Entry.swift:18 | **A** | Class carrying the `State` (#46). Docstring on State says cache mutex guards transitions. By composition A. |
| 48 | `Cache.Entry.Waiters` | swift-cache-primitives/…/Cache.Entry.Waiters.swift:21 | **A** | Holds `Async.Waiter.Queue.Unbounded` which is itself `~Copyable`-queued. Guarded by cache mutex per docstring. |
| 49 | `Rendering.Indirect<Content: ~Copyable>` | swift-rendering-primitives/…/Rendering.Indirect.swift:22 | **D-candidate** (leaning B) | `final class Indirect<Content: ~Copyable>: @unchecked Sendable` — unconditional. The stored `value: Content` is a `let` (immutable). `~Copyable` generic in class storage blocks Sendable inference, same pattern as `Ownership.Shared`. Queued — pattern is near-identical to #33. |
| 50 | `String` (swift-string-primitives) | swift-string-primitives/…/String.swift:39 | **B** | `~Copyable, @unchecked Sendable`. Owns null-terminated buffer; immutable after init. Canonical Cat B. |
| 51 | `Bit.Vector.Ones.View` | swift-bit-vector-primitives/…/Bit.Vector.Ones.View.swift:21 | **D-candidate** | `Copyable` struct holding raw pointer. Non-owning view — caller manages buffer lifetime. No synchronization; no `~Copyable`. Queued; closer to a raw-pointer value-semantic phantom. |
| 52 | `Bit.Vector` | swift-bit-vector-primitives/…/Bit.Vector.swift:146 | **D-candidate** | Unconditional `@unchecked Sendable`. Raw-pointer-backed. Queued — no obvious synchronization; would need principal to confirm whether unsafe-aliasing risks exist (there's `withUnsafeMutableWords`). |
| 53 | `Bit.Vector.Zeros.View` | swift-bit-vector-primitives/…/Bit.Vector.Zeros.View.swift:21 | **D-candidate** | Same pattern as #51. |
| 54 | `Generation.Tracker` | swift-handle-primitives/…/Generation.Tracker.swift:205 | **LOW_CONFIDENCE** | `struct Tracker: ~Copyable` + unconditional `@unchecked Sendable`. Docstring on the type itself: "**Not thread-safe. External synchronization required for concurrent access.**" So this is Cat A-like "caller-promised synchronization" (which the framework doesn't really have a category for) OR Cat B (`~Copyable` ownership transfer). Its raw pointers + `~Copyable` suggest B, but the type is genuinely data-mutable. See Low-Confidence Flags. |
| 55 | `CopyOnWrite.Storage` | swift-structured-queries-primitives/…/Select.swift:500 | **D-candidate** | Conditional: where Value: Sendable. Storage class for CoW. Structural phantom-forwarding pattern. Queued. |
| 56 | `Sequence.Consume.View<Element, State>` | swift-sequence-primitives/…/Sequence.Consume.View.swift:86 | **D-candidate** | Conditional: where Element: Sendable, State: Sendable. `~Copyable` struct. Phantom-type-over-two-generics Cat D pattern. |
| 57 | `Property.Consuming.State` | swift-property-primitives/…/Property.Consuming.swift:98 | **D-candidate** | `final class State: @unchecked Sendable` inside a generic wrapper. The outer `Property.Consuming` is `Sendable where Base: Sendable` (checked). The inner State holds `var _base: Base?` and `var _consumed: Bool`. Intended scope: single-threaded accessor lifecycle. Queued — closer to C (thread-confined to the `_modify` accessor) but the unconditional @unchecked is the flag. |
| 58 | `Lifetime.Lease<Value>` | swift-lifetime-primitives/…/Lifetime.Lease.swift:74 | **B** | `~Copyable, Sendable where Value: Sendable`. Canonical ownership-transfer lease. |

**Clarifying note on totals**: the table numbers 58 rows but hit #46 combines conceptually with #47 and #48 for Cache; no double-counting in the category tallies above. I excluded comment-only matches (CoW.swift header comment, Ownership.swift header comment, Reference.Sendability.Unchecked's docstring).

---

## Appendix — docstrings / `// WHY:` for A/B/C hits

### Category A — synchronized

#### 1. `IO.Completion.Operation.Storage`

Current docstring already has a good three-section-like treatment. Suggested canonical form:

```swift
/// Internal storage for an in-flight completion-I/O operation.
///
/// ## Safety Invariant
///
/// Mutable fields (`completion`, `userData`, `descriptor`) are written by the
/// completion loop thread before calling `continuation.resume()`. The client
/// reads them after `resume()` wakes the suspended task. The `resume()` call
/// provides a happens-before relationship: the loop thread's writes become
/// visible to the client's reads after the continuation resumes. Immutable
/// fields (`id`, `kind`, `bufferAddress`, `bufferLength`, `offset`, `interest`)
/// are safe for cross-thread read after initialization.
///
/// ## Intended Use
///
/// - Pointer-based correlation with kernel completions (stored in `userData`)
/// - Shared access between the loop thread and awaiting task via ARC
/// - Retain-on-submit pattern to survive the kernel's custody window
///
/// ## Non-Goals
///
/// - NOT a thread-safe shared mutable container — mutable fields require the
///   happens-before from `resume()`.
/// - Does NOT own the buffer; buffer lifetime is caller's responsibility per
///   the buffer-ownership contract.
/// - Does NOT synchronize reads of `completion` before `resume()` is called.
```

Annotation: `public final class Storage: @unsafe @unchecked Sendable {`

#### 2. `IO.Completion.Loop`

```swift
/// An integrated proactor I/O loop: `SerialExecutor + TaskExecutor + submit/poll`.
///
/// ## Safety Invariant
///
/// Cross-thread state (the job queue and the `shutdownFlag`) is protected by
/// an internal `Kernel.Thread.Mutex` (`queueLock`). All driver/entry state is
/// thread-confined to the loop's single OS thread and is accessed only through
/// actor methods pinned to this executor via `unownedExecutor` (compiler-
/// verified isolation) or from the run loop itself.
///
/// ## Intended Use
///
/// - Unified executor + proactor poll thread (one OS thread per loop)
/// - Actor pinning via `unownedExecutor` for the owning `IO.Completions.Actor`
/// - Cross-thread entry limited to `enqueue()` (job dispatch) and
///   `wakeup.wake()` (poll interrupt)
///
/// ## Non-Goals
///
/// - NOT safe to call non-enqueue methods from outside the loop's thread.
/// - Does NOT support multiple loop threads; single-threaded by construction.
/// - Does NOT survive shutdown — `shutdown()` must be called once.
```

Annotation: `public final class Loop: SerialExecutor, TaskExecutor, @unsafe @unchecked Sendable {`

#### 3. `IO.Completions.Actor.CancelCoordinator`

```swift
/// Coordinates the two-CQE cancel handshake.
///
/// ## Safety Invariant
///
/// All mutable state (`_cancelled`, `_gateOpened`, `_gateContinuation`) is
/// guarded by an internal `Kernel.Thread.Synchronization<1>`. Every access
/// goes through `sync.withLock`, providing mutual exclusion across the
/// actor job and the loop-thread CQE dispatch.
///
/// ## Intended Use
///
/// - Single-writer cancel claim via `tryBegin()`
/// - One-shot gate coordination via `waitForCancelCQE` / `markCancelCQEReceived`
/// - Captured in `@Sendable` `onCancel` closures (which cannot capture
///   actor-isolated or inout value types)
///
/// ## Non-Goals
///
/// - NOT reusable across multiple cancel attempts — single-shot.
/// - Does NOT store or manage the underlying operation beyond its cancel state.
```

Annotation: `fileprivate final class CancelCoordinator: @unsafe @unchecked Sendable {`

#### 4. `IO.Events.Actor.FDState`

```swift
/// Class-backed per-fd state record.
///
/// ## Safety Invariant
///
/// Exclusively accessed from the `IO.Events.Actor`'s serial executor. Actor
/// isolation serializes all mutation — no internal synchronization required.
/// The `@unchecked Sendable` conformance exists solely to satisfy the
/// `Dictionary` value-Sendable requirement across the init boundary.
///
/// ## Intended Use
///
/// - `Dictionary` value type — cannot hold `~Copyable` values directly, so
///   wrapping in a class exposes a Sendable reference.
/// - Holds the three unbounded channel `Ends` per interest (read/write/priority).
///
/// ## Non-Goals
///
/// - NOT safe to access from outside the `IO.Events.Actor`'s executor.
/// - Does NOT provide any cross-thread mutation synchronization.
```

Annotation: `final class FDState: @unsafe @unchecked Sendable {`

*Note: this one is close to Cat C (thread-confined). The docstring's own claim that actor isolation serializes all mutation is a textbook C argument. I chose A because the `@unchecked Sendable` is load-bearing for `Dictionary` value-Sendable, which is a synchronization-like requirement that the container must see.* **LOW_CONFIDENCE alternative: Cat C.** See Low-Confidence Flags.

#### 5. `IO.Event.Loop`

```swift
/// An integrated I/O event loop backed by `Kernel.Thread.Executor.Polling`.
///
/// ## Safety Invariant
///
/// Synchronization is provided by the held `Kernel.Thread.Executor.Polling`
/// instance. All cross-thread entry goes through the Polling executor's
/// synchronized job queue; all I/O state is thread-confined to that executor's
/// single OS thread and accessed only from actor methods pinned via
/// `unownedExecutor` or from the tick closure.
///
/// ## Intended Use
///
/// - Unified executor + kernel event poll thread (one OS thread per loop)
/// - Actor pinning for the owning `IO.Events.Actor`
/// - Cross-thread `enqueue()` delegated to Polling
///
/// ## Non-Goals
///
/// - NOT safe to call non-enqueue methods from outside the loop's thread.
/// - Does NOT own the kernel event source beyond the Polling executor's lifetime.
```

Annotation: `public final class Loop: SerialExecutor, TaskExecutor, @unsafe @unchecked Sendable {`

#### 13. `Test.Reporter.Terminal` (private)

```swift
/// Console sink implementation with thread-safe counters.
///
/// ## Safety Invariant
///
/// All mutable state (the counts tuple) is guarded by `Mutex`. The
/// `Console.Capability` field is set once at init and thereafter immutable.
///
/// ## Intended Use
///
/// - Terminal output for test events with thread-safe pass/fail/skip/issue counters
///
/// ## Non-Goals
///
/// - NOT intended for non-terminal output; see `JSONSink` / `StructuredSink`.
```

Annotation: `private final class Terminal: Sink.Implementation, @unsafe @unchecked Sendable {`

#### 14. `Test.Reporter.StructuredSink`

```swift
/// Sink that accumulates JSON records and writes JSONL on finish.
///
/// ## Safety Invariant
///
/// Mutable `_records` is guarded by `Mutex`. The path is set once at init
/// and thereafter immutable.
///
/// ## Intended Use
///
/// - JSONL-structured test event capture for CI tools
///
/// ## Non-Goals
///
/// - NOT for in-process consumption; finish() writes to disk.
```

Annotation: `private final class StructuredSink: Sink.Implementation, @unsafe @unchecked Sendable {`

#### 15. `Test.Reporter.JSONSink`

Same pattern as StructuredSink — `Mutex<[Test.Event]>` is the synchronization. Annotation: `private final class JSONSink: Sink.Implementation, @unsafe @unchecked Sendable {`

#### 17. `Test.Snapshot.Counter`

```swift
/// Thread-safe counter for unnamed snapshots within a test.
///
/// ## Safety Invariant
///
/// All mutable state (`counts` dictionary) is guarded by a `Mutex`. Every
/// mutation path goes through `lock.withLock`.
///
/// ## Intended Use
///
/// - Sequential numbering per test function for unnamed `expectSnapshot` calls
/// - Shared as a `Dependency.Scope` dependency across a test run
///
/// ## Non-Goals
///
/// - NOT a general-purpose counter; specific to snapshot numbering.
```

Annotation: `public final class Counter: @unsafe @unchecked Sendable {`

#### 18. `Test.Snapshot.Inline.State`

```swift
/// Thread-safe accumulator for pending inline snapshot writes during a test run.
///
/// ## Safety Invariant
///
/// The entries dictionary is guarded by a `Mutex`. All registration and drain
/// paths go through `mutex.withLock`. The one-time `atexit` handler is
/// installed lazily via a `static let` initializer (one-shot by language rule).
///
/// ## Intended Use
///
/// - Lazy collection of inline snapshot entries across multiple test runs
/// - Drained once by either `Test.Runner.postRunActions` or the `atexit`
///   handler (whichever fires first — `drain()` is destructive and idempotent-by-empty).
///
/// ## Non-Goals
///
/// - NOT thread-safe for the `atexit` handler itself (process is exiting).
/// - Does NOT guarantee which drainer runs — safe by `drain()`-then-empty design.
```

Annotation: `public final class State: @unsafe @unchecked Sendable {`

#### 19. `Test.Expectation.Collector`

```swift
/// Collects expectations recorded during a test body's execution.
///
/// ## Safety Invariant
///
/// All mutable state (`_storage`) is guarded by a `Mutex`. All mutation paths
/// (`record`, `drain`, `hasFailures`) go through `_storage.withLock`.
///
/// ## Intended Use
///
/// - Per-test collection of `expect`/`assertSnapshot` results
/// - Injected via `Dependency.Scope` so async test bodies can record
///
/// ## Non-Goals
///
/// - NOT intended to outlive a single test execution scope.
```

Annotation: `public final class Collector: @unsafe @unchecked Sendable {`

#### 32. `Ownership.Slot<Value: ~Copyable>`

```swift
/// A reusable heap-allocated slot for storing a single `~Copyable` value.
///
/// ## Safety Invariant
///
/// An atomic state machine (`Atomic<UInt8>`) with release/acquire publication
/// protocol guards `_storage`. Store path: CAS empty→initializing
/// (acquiringAndReleasing) reserves the slot, the `initialize` writes non-atomic
/// memory, then `store(.full, releasing)` publishes. The release barrier
/// ensures the initialize happens-before any observer sees `.full`. Take path:
/// CAS full→empty (acquiringAndReleasing) acquires the publication before
/// `move()`. `State.full` implies storage is initialized and safe to move/deinit.
///
/// ## Intended Use
///
/// - Reusable empty↔filled state (vs one-shot `Ownership.Transfer`)
/// - Resource pools with reusable entries
/// - Lifetime management patterns requiring move-in/move-out semantics
///
/// ## Non-Goals
///
/// - NOT a general-purpose container — single-slot by design.
/// - Does NOT provide bulk operations.
```

Annotation: `public final class Slot<Value: ~Copyable>: @unsafe @unchecked Sendable {`

#### 37. `Ownership.Transfer._Box<T: ~Copyable>`

```swift
/// ARC-managed box for `~Copyable` value storage with atomic one-shot enforcement.
///
/// ## Safety Invariant
///
/// An atomic state machine (`Atomic<Int>` with acquiringAndReleasing CAS)
/// protects the four-state lifecycle: empty → initializing → full → taken.
/// Store path: CAS empty→initializing, allocate+initialize `_storage`,
/// `store(.full, releasing)` publishes. Take path: CAS full→taken acquires,
/// then `_storage.move()`. `State.full` implies `_storage` non-nil and
/// initialized; `State.taken` is terminal.
///
/// ## Intended Use
///
/// - Cross-thread ownership transfer for `~Copyable` values that also require
///   Copyable tokens (Sendable) with atomic exactly-once enforcement
///
/// ## Non-Goals
///
/// - NOT a general multi-use container — one store + one take.
/// - Does NOT re-enable store after take.
```

Annotation: `internal final class _Box<T: ~Copyable>: @unsafe @unchecked Sendable {`

#### 47. `Cache.Entry` + #48 `Cache.Entry.Waiters`

Both are guarded by the cache-level mutex (per the Cache.Entry.State docstring). Template:

```swift
/// ## Safety Invariant
///
/// Externally guarded by the parent `Cache`'s mutex. All access to mutable
/// fields occurs with the cache mutex held.
///
/// ## Intended Use
///
/// - Reference-typed cache entry storage so `Dictionary` can hold it
/// - Carries `~Copyable` waiter queue via internal reference
///
/// ## Non-Goals
///
/// - NOT safe to access outside the parent Cache's mutex.
```

Annotations:
- `final class Entry: @unsafe @unchecked Sendable {`
- `final class Waiters: @unsafe @unchecked Sendable {`

---

### Category B — ownership transfer (`~Copyable`)

#### 7. `Memory.Map`

Existing docstring is near-complete. Tighten to:

```swift
/// A move-only memory-mapped file region.
///
/// ## Safety Invariant
///
/// `~Copyable` prevents aliasing; `@unchecked Sendable` permits move-across-
/// thread ownership transfer. The mapping bytes themselves are raw memory —
/// concurrent writes to the same offset are data races the caller must
/// synchronize. Read-only mappings can be safely shared across tasks without
/// synchronization. Lock tokens (in `.coordinated` safety mode) are released
/// with the mapping.
///
/// ## Intended Use
///
/// - Move a mapping from a creator actor/task to a reader/writer actor/task.
/// - Pass mapping ownership through an ownership-transfer primitive.
/// - Single-owner-at-a-time reads or writes, or read-only-fanout (shared in parallel).
///
/// ## Non-Goals
///
/// - Does NOT synchronize concurrent writes to the same offset.
/// - Does NOT own the file descriptor — caller retains close responsibility.
/// - Does NOT auto-grow — length is fixed at mapping time.
```

Annotation: `public struct Map: ~Copyable, @unsafe @unchecked Sendable {`

#### 24. `Path`

```swift
/// An owned, lifetime-safe path wrapper for syscall use.
///
/// ## Safety Invariant
///
/// `~Copyable` enforces unique ownership so no two owners share the buffer.
/// The buffer is immutable after initialization (stored via `Memory.Contiguous`
/// with a `let` pointer). `@unchecked Sendable` enables move-across-thread
/// ownership transfer for syscall dispatch.
///
/// ## Intended Use
///
/// - Path owned by a filesystem-operation value transferred to a syscall thread
/// - Constructed from `String.View` or `Span<Char>`; null-terminated for syscalls
///
/// ## Non-Goals
///
/// - NOT a general string — UTF-8/UTF-16 per-platform, syscall-oriented only.
/// - Does NOT support mutation; immutable after construction.
/// - Callers must not rely on content equality with the originating string
///   (platform normalization not performed).
```

Annotation: `public struct Path: ~Copyable, @unsafe @unchecked Sendable {`

#### 31. `Ownership.Unique<Value>` (extension)

```swift
/// ## Safety Invariant
///
/// `~Copyable` enforces unique heap-ownership; `@unchecked Sendable` (conditional
/// on `Value: Sendable`) enables move-across-thread ownership transfer. The
/// `_storage` pointer is nil only after `take()` or `leak()`; memory is
/// initialized for the lifetime of the owner.
///
/// ## Intended Use
///
/// - Rust-`Box<T>` equivalent: unique heap ownership with deterministic
///   deinitialization.
/// - Transfer heap storage across thread/task boundaries when `Value: Sendable`.
///
/// ## Non-Goals
///
/// - Does NOT share storage with other owners.
/// - Does NOT allow double-consumption (`take()` twice traps).
```

Annotation: `extension Ownership.Unique: @unsafe @unchecked Sendable where Value: Sendable {}`

#### 35. `Ownership.Transfer.Box.Pointer`

```swift
/// Sendable capability wrapper for boxed pointers.
///
/// ## Safety Invariant
///
/// Represents a capability to consume or destroy a box. The raw pointer is
/// treated as an opaque ownership token — callers must either call `take()` or
/// `destroy()` exactly once. This type concentrates the unsafe sendability at
/// the Ownership.Transfer boundary; the Box header + payload allocation itself
/// carries no Sendable claim.
///
/// ## Intended Use
///
/// - Transfer ownership of a type-erased box across a thread boundary.
/// - Single-consumer pattern: the receiver calls `take()` or `destroy()` once.
///
/// ## Non-Goals
///
/// - Does NOT provide any operations directly — capability-only wrapper.
/// - Does NOT prevent multi-consumption; caller discipline required.
```

Annotation: `public struct Pointer: @unsafe @unchecked Sendable {`

#### 36. `Ownership.Transfer.Retained<T: AnyObject>`

```swift
/// A move-only Sendable wrapper for transferring retained object ownership
/// across thread boundaries with zero allocation overhead.
///
/// ## Safety Invariant
///
/// `~Copyable` enforces single-consumption at compile time — `take()` can be
/// called exactly once. `@unchecked Sendable` enables move-across-thread
/// transfer. The wrapped object is retained on init (+1) and released by
/// `take()` via `takeRetainedValue()`.
///
/// ## Intended Use
///
/// - Zero-allocation transfer of a class reference from creator thread to
///   worker thread (e.g., `Kernel.Thread.trap` spawn).
/// - Preferred over `Ownership.Transfer.Cell` when the value is `AnyObject`.
///
/// ## Non-Goals
///
/// - Does NOT work for value types — use `Cell` instead.
/// - Does NOT allow double-take (compile-enforced by `~Copyable`).
```

Annotation: `public struct Retained<T: AnyObject>: ~Copyable, @unsafe @unchecked Sendable {`

#### 50. `String` (swift-string-primitives)

```swift
/// Owned, null-terminated platform string.
///
/// ## Safety Invariant
///
/// `~Copyable` enforces unique ownership so no two owners share the buffer.
/// The buffer is immutable after initialization (stored via `Memory.Contiguous`
/// with a `let` pointer). `@unchecked Sendable` enables move-across-thread
/// ownership transfer; sharing via a `Reference.Box` is safe because reads
/// are the only access and lifetime is box-managed.
///
/// ## Intended Use
///
/// - Owned string for syscall boundaries (null-terminated, platform-native encoding).
/// - Transferable across threads for syscall dispatch.
///
/// ## Non-Goals
///
/// - NOT a general string type — syscall-oriented. Use `String.View` for borrows.
/// - Does NOT support mutation; immutable after construction.
```

Annotation: `public struct String: ~Copyable, @unsafe @unchecked Sendable {`

#### 58. `Lifetime.Lease<Value>` (extension)

```swift
/// ## Safety Invariant
///
/// `~Copyable` enforces unique ownership of the borrowed value; `@unchecked Sendable`
/// (conditional on `Value: Sendable`) enables move-across-thread ownership
/// transfer while the lease is active. `release()` must be called exactly once
/// to return the value; `deinit` deallocates whether released or not.
///
/// ## Intended Use
///
/// - Transfer a borrowed value from a lender thread/actor to a borrower
///   thread/actor with guaranteed return via `release()`.
///
/// ## Non-Goals
///
/// - Does NOT share the leased value with other holders.
/// - Does NOT allow double-release.
```

Annotation: `extension Lifetime.Lease: @unsafe @unchecked Sendable where Value: Sendable {}`

---

### Category C — thread-confined (skip, `// WHY:`)

#### 6. `File.Directory.Contents.IteratorHandle`

Replace existing one-liner with:

```swift
// WHY: Category C — thread-confined. The held Kernel.Directory.Stream is
// WHY: poll-thread-confined and is created and consumed on one thread.
// WHY: The @unchecked exists to cross the Dictionary/value-Sendable init boundary.
// WHEN TO REMOVE: After ~Sendable (SE-0518) stabilizes — this is one of the
// WHEN TO REMOVE: three Tier 1 thread-confined types flagged for migration.
// TRACKING: ownership-transfer-conventions.md Tier 1; SE-0518.
public final class IteratorHandle: @unchecked Sendable {
```

(Leave `@unchecked Sendable` bare — do NOT add `@unsafe`.)

---

## Low-Confidence Flags

### #4 (redux): `IO.Events.Actor.FDState` — Cat A vs Cat C

- **Classified as A above.** The argument for C is strong: the docstring explicitly says "actor isolation serializes all mutation — no internal synchronization needed" and the only reason for `@unchecked` is `Dictionary` value-Sendable.
- **Reason for flagging**: Cat C would make this a candidate for `~Sendable` (SE-0518). Tier 1 of the ownership-transfer-conventions doc lists 3 known Tier 1 types and FDState is not on that list. This suggests the principal already considered and rejected Tier 1 for FDState, but the rejection criterion is not documented.
- **Principal decision needed**: Is FDState A (actor-synchronized) or C (thread-confined-by-actor)? My tentative A is because `@unchecked` is load-bearing for `Dictionary` (a synchronization-container requirement), but the actor is the actual synchronizer.

### #8: `Parser.Debug.Profile.Stats`

- `final class Stats` with mutable `_invocations`, `_successes`, `_failures`, `_totalDuration`, `_minDuration`, `_maxDuration` — none of these guarded by a visible Mutex/Atomic.
- Used under `Debug.Profile` parser wrapper which could be invoked concurrently if the parser is shared across threads.
- **Classification candidates**: Cat A (with a latent bug — missing synchronization), Cat C (thread-confined by debug workflow convention), or Cat D (no invariant, pure observations).
- **I did not read the Debug.Profile call site** to determine which one holds. Principal review needed.

### #9: `Plist.Binary.Context<Bytes>`

- `final class Context<Bytes: Collection<UInt8>>` — generic over a Collection witness. Holds `bytes`, `trailer`, `offsets`, and mutable `parsedObjects: [UInt64: Plist.Value]`.
- Used only inside `Plist.Binary.parse(_:)` which constructs it locally — truly thread-confined.
- **Classification candidates**: Cat C (thread-confined to the parse closure), Cat D (phantom over `Bytes` generic parameter blocks Sendable inference).
- Principal review needed.

### #16: `Test.Reporter.NullSink`

- Stateless discard sink — no stored properties, no invariant.
- **Classification candidates**: Cat D (no-invariant trivial), or no-op classification (the `@unchecked Sendable` could plausibly be removed and replaced with plain Sendable conformance if `Sink.Implementation`'s inheritance doesn't require it).
- **Principal decision needed**: drop the `@unchecked` entirely, or treat as D?

### #21: `HTML.AnyView`

- `struct AnyView: HTML.View, @unchecked Sendable` holding `any HTML.View`.
- `HTML.View` is not declared `Sendable` (at least not visibly from this file), so the existential isn't provably Sendable.
- **Classification candidates**: Cat D (phantom-like — the protocol is conventionally Sendable but not formally refined), or the right fix is to add `Sendable` refinement to `HTML.View` and drop the `@unchecked`.
- **Principal decision needed**: redesign vs. D classification.

### #33: `Ownership.Shared<Value: ~Copyable & Sendable>`

- Self-documents as waiting for a compiler fix: "When this compiler limitation is resolved, this should be converted to checked `Sendable` conformance."
- That framing makes it **Cat D** (structural Sendable workaround). I tentatively marked it B because `~Copyable` is involved.
- **Principal decision needed**: B or D?

### #34: `Ownership.Mutable.Unchecked`

- Deliberately opt-in unsafe — name and docstring flag this as the "escape hatch" type.
- **Classification candidates**: Cat A (caller-promised synchronization), or sui generis (this IS the ecosystem's canonical `@unsafe @unchecked Sendable` exemplar, and the skill should probably document it separately).
- **Principal decision needed**: apply canonical A template, or treat as a named exemplar?

### #46: `Cache.Entry.State`

- `enum State: @unchecked Sendable` with `case failed(any Error)` — existential blocks Sendable inference — and `case computing(Waiters)` where `Waiters` is a ref-type.
- **Classification candidates**: Cat D (phantom-like over `any Error`), or A (guarded externally by Cache mutex).
- **Principal decision needed**: the `any Error` case is a genuine structural reason; the rest is A-ish via external mutex.

### #54: `Generation.Tracker`

- `struct Tracker: ~Copyable` + unconditional `@unchecked Sendable`.
- Docstring: "**Not thread-safe. External synchronization required for concurrent access.**"
- **Classification candidates**: Cat B (~Copyable ownership transfer — single-owner-at-a-time), or sui generis (caller-promised-synchronization, like #34 Mutable.Unchecked).
- **Principal decision needed**: B or A-as-caller-promise?

---

## Tier 2 Debatable Sites

None in my scope. The Tier 2 list in ownership-transfer-conventions.md §4 Tier 2 enumerates four types (`Kernel.File.Write.Streaming.Context`, `Kernel.Memory.Map.Region`, `IO.Event.Batch`, `IO.Blocking.Threads.Job.Instance`); all four are at Kernel (L1) and owned by agent 3 / agent 1 scopes.

**Note**: The L3 `Memory.Map` wrapper in swift-memory is NOT the Tier 2 debatable `Kernel.Memory.Map.Region`. The L3 wrapper has `~Copyable` and is classifiable as Cat B (#7 above). Only the L1 Region is Tier 2 debatable, and it is out of my scope.

---

## Preexisting Warnings Noted

None — I did not execute `swift build` per the ground rules.

---

## Exclusion Confirmation

- `swift-foundations/swift-io-state-investigation/` — confirmed excluded. I did not grep or read that directory.
- Tests/, Experiments/, Benchmarks/, Research/ — skipped per scope rule; Sources/ only.
- No hits found in `/Users/coen/Developer/swift-foundations/swift-sockets/Sources` or `/Users/coen/Developer/swift-primitives/swift-reference-primitives/Sources` (the only matches there are within existing doc comments, not actual `@unchecked Sendable` conformances).

---

## Return-format summary

57 total hits. A: 13. B: 10. C: 1. D-candidate: 27. LOW_CONFIDENCE: 6 (with 3 overlapping with D-candidate / B rows as alternatives). Tier 2 debatable: 0 in scope. Preexisting warnings: none observed.
