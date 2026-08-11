# Unbounded Channel: Consuming Endpoint Extraction

<!--
---
version: 1.1.0
last_updated: 2026-05-31
status: DECISION
statusDetail: "Frontmatter reconciled to the doc's own Decision section (Option A -- restore consuming func take() -> Take). Triaged 2026-05-31 per [META-002]; was IN_PROGRESS."
tier: 1
related:
  - swift-async-primitives/Research/audit.md
  - swift-institute/Research/Reflections/2026-03-27-async-channel-noncopyable-restructure.md
  - swift-institute/Research/Reflections/2026-03-29-channel-split-full-duplex-io.md
---
-->

## Context

`Async.Channel<Element>.Unbounded` is ~Copyable with a Copyable `.sender` and a
~Copyable `.receiver`. The consuming endpoint extraction pattern extracts the sender
(shareable), then consumes the channel to obtain the receiver as part of an `Ends`
bundle.

The call site in `IO.Event.Selector` (swift-io) does:

```swift
var channel = Async.Channel<Kernel.Event>.Unbounded()
let sender = channel.sender                              // Copyable — extract first
let ends = (consume channel).take().ends()               // consume → Take → Ends
```

A `consuming func take() -> Take` was removed in commit `520f1c5` with message
"zero call sites" — but the swift-io call site existed. The `Take.init` is
`@usableFromInline` (internal), so external packages cannot reconstruct the chain.

## Question

What is the Swift-native approach for consuming a ~Copyable container and extracting
its mixed Copyable/~Copyable components?

## Prior Art

### Swift Stdlib

| Pattern | Example | Source |
|---------|---------|-------|
| `consuming func` → extracted value | `Optional._consumingMap`, `Optional._consumingUnsafelyUnwrap` | Optional.swift |
| `switch consume self` for enum decomposition | `Result.consuming get()` | Result.swift |
| `discard self` to extract fields from struct | `FixedSizeQueue.cleanupQueue()` | moveonly_fixedsizequeue.swift |
| Scoped borrowing instead of decomposition | `Mutex.withLock { inout sending Value }` | Mutex.swift |
| `Borrow<Value: ~Copyable>` safe reference | `Borrow.value` via `_read` coroutine | Borrow.swift (6.4) |

**Pattern**: stdlib uses direct `consuming func` methods returning the extracted
value or a bundle. No intermediate "accessor namespace" types.

### Apple swift-http-api-proposal

| Pattern | Example |
|---------|---------|
| `consuming func consumeAndConclude` | Consumes reader, returns `(Result, FinalElement)` |
| `consuming func produceAndConclude` | Consumes writer, returns `Result` |
| `Optional.take()!` for call-once semantics | Wraps ~Copyable in Optional before closure boundary |
| `Disconnected<Value: ~Copyable>` | Cross-isolation transfer via `consuming func take() -> sending Value` |

**Pattern**: Apple uses `consuming func` directly on the type being consumed.
No intermediate namespace types. The consuming method returns the bundle directly.

### Ecosystem (Swift Institute)

| Pattern | Example | Source |
|---------|---------|-------|
| `consuming func split() → Split` | IO.Event.Channel → Reader + Writer | IO.Event.Channel.swift |
| Bundle struct + Optional `.take()!` | `Split._reader.take()!` | IO.Event.Channel.swift |
| `consuming func take() → Take` then `.ends()` | Async.Channel.Unbounded → Ends | Take.swift, Ends.swift |
| `Ownership.Slot.take() → Value?` | Reusable heap slot | Ownership.Slot.swift |
| `Ownership.Transfer.Retained.take()` | One-shot cross-boundary | Ownership.Transfer.swift |

**Pattern**: The ecosystem uses `consuming func` → bundle type consistently.
The `Take → Ends` two-step chain on Unbounded is the sole instance of an
intermediate "consuming accessor namespace" type.

## Analysis

### Option A: Restore `consuming func take() -> Take`

Restore the deleted one-line method. The `Take` intermediate stays.

```swift
// On Unbounded:
public consuming func take() -> Take {
    Take(channel: consume self)
}

// Call site:
let ends = (consume channel).take().ends()
```

| Criterion | Assessment |
|-----------|-----------|
| Swift-native | No — stdlib/Apple don't use intermediate accessor types |
| Consistency | Matches ecosystem Property.View pattern, but Take has only 1 method |
| Call site | Two-step: `.take().ends()` — extra indirection |
| Extensibility | Can add more consuming operations on Take later |

### Option B: Direct `consuming func ends() -> Ends`

Skip the intermediate. Consuming method directly on `Unbounded` returns `Ends`.

```swift
// On Unbounded:
public consuming func ends() -> Ends {
    Ends(storage: storage, receiver: consume receiver)
}

// Call site:
let ends = (consume channel).ends()
```

| Criterion | Assessment |
|-----------|-----------|
| Swift-native | Yes — matches stdlib `consuming func` → value pattern |
| Consistency | Matches `IO.Event.Channel.split()` (direct consuming → bundle) |
| Call site | Single step: `.ends()` — reads as intent |
| Extensibility | If a second consuming operation is needed, add Take namespace then |

### Option C: Consuming property `var take: Take`

Use a consuming get property for the namespace pattern.

```swift
// On Unbounded:
public var take: Take {
    consuming get { Take(channel: consume self) }
}

// Call site:
let ends = channel.take.ends()  // no explicit consume needed
```

| Criterion | Assessment |
|-----------|-----------|
| Swift-native | Experimental — `consuming get` is not widely used in stdlib |
| Consistency | Matches [API-NAME-002] verb-as-property pattern |
| Call site | Clean: `channel.take.ends()` |
| Compiler support | Uncertain — `consuming get` on computed property may have edge cases |

### Option D: Inline the extraction (no public API)

Make `Ends.init` public instead. Consumers construct Ends directly.

```swift
// Call site:
let ends = Async.Channel<Kernel.Event>.Unbounded.Ends(
    storage: channel.storage, receiver: consume channel.receiver
)
```

| Criterion | Assessment |
|-----------|-----------|
| Swift-native | No — exposes internal storage details |
| Consistency | Violates encapsulation |
| Call site | Verbose, leaks implementation |

## Comparison

| Criterion | A: Restore take() | B: Direct ends() | C: Consuming property | D: Public Ends.init |
|-----------|-------------------|-------------------|----------------------|---------------------|
| Swift-native | Weak | **Strong** | Experimental | Weak |
| Call-site clarity | `.take().ends()` | **`.ends()`** | `.take.ends()` | Verbose |
| Intermediate types | Take (1 method) | **None** | Take (1 method) | None |
| Ecosystem consistency | Property.View pattern | **Channel.split() pattern** | Property.View pattern | — |
| Premature abstraction | Yes (1 method on Take) | **No** | Yes (1 method on Take) | No |
| Future extensibility | Ready | Add namespace when needed | Ready | — |

## Recommendation

**Option B: Direct `consuming func ends() -> Ends`.**

The stdlib pattern is clear: `consuming func` directly on the type, returning the
bundle. Apple's HTTP proposal confirms this. The ecosystem's own `Channel.split()`
follows the same pattern. The `Take` intermediate is premature abstraction for a
single method.

```swift
extension Async.Channel.Unbounded where Element: ~Copyable {
    /// Consume the channel and return both endpoints as a bundle.
    ///
    /// Extract the sender first (Copyable, shareable), then consume
    /// the channel to obtain the receiver:
    /// ```swift
    /// var channel = Async.Channel<Int>.Unbounded()
    /// let sender = channel.sender
    /// let ends = (consume channel).ends()
    /// let receiver = ends.receiver
    /// ```
    public consuming func ends() -> Ends {
        Ends(storage: storage, receiver: consume receiver)
    }
}
```

The `Take` type can remain as internal infrastructure. If a second consuming
operation is needed in the future, promote `Take` to a public consuming accessor
namespace at that point.

### Call site change

```swift
// Before:
let readEnds = (consume readChannel).take().ends()

// After:
let readEnds = (consume readChannel).ends()
```

### Option E: Factory-bundle pattern (Apple swift-async-algorithms)

Factory returns a ~Copyable bundle struct; consumers extract parts from the bundle.
The channel is never in a state where you need to "consume it to get its parts."

```swift
// Factory:
var bundle = Async.Channel<Int>.Unbounded.makeChannel()
let sender = bundle.sender            // Copyable, extract freely
let receiver = bundle.takeReceiver()  // consuming extraction

// Apple's actual API (MultiProducerSingleConsumerAsyncChannel):
var channelAndSource = MPSC.makeChannel(backpressureStrategy: ...)
var channel = channelAndSource.takeChannel()
let source = consume channelAndSource.source
```

| Criterion | Assessment |
|-----------|-----------|
| Swift-native | Yes — Apple's modern channel pattern in swift-async-algorithms |
| Consistency | Breaks with `init()` construction pattern used everywhere in ecosystem |
| Call site | Different shape: factory → bundle → extract |
| Trade-off | Avoids the consume-to-decompose problem entirely, but requires static factory method instead of `init()` |

**Not recommended for adoption**: requires replacing `init()` with a static factory
method, which is a deeper redesign than needed and inconsistent with the ecosystem's
preference for initializer-based construction.

## Decision

**Restore `consuming func take() -> Take`** (Option A).

The `Take` namespace enables future consuming decompositions if needed. The two-step
chain `channel.take().ends()` is idiomatic for the ecosystem's accessor pattern.
The method was incorrectly removed — the "zero call sites" claim missed the swift-io
consumer. Apple's modern swift-async-algorithms validates the bundle-extraction
pattern; our `Take → Ends` chain is a consuming variant of the same idea.

## References

- Apple swift-http-api-proposal: `consumeAndConclude`/`produceAndConclude` pattern
- Swift stdlib: `Optional._consumingMap`, `Result.consuming get()`
- `IO.Event.Channel.split()` → `Split` bundle pattern
- Commit `520f1c5`: "Remove redundant take() from Async.Channel.Unbounded and Bounded"
