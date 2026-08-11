# Async vs Sync Event API

<!--
---
version: 2.0.0
last_updated: 2026-03-03
status: DECISION
tier: 2
---
-->

## Changelog

- **2.0.0** (2026-03-03): Rewritten to build on existing infrastructure: `IO.Event.Selector`
  for fd monitoring, `Async.Stream` + `Async.Channel` for async delivery, parser primitives
  for escape sequence parsing. Removed proposals to build custom kqueue/epoll or custom
  async bridging — this infrastructure already exists and is production-grade.
- **1.0.0** (2026-03-03): Initial research with prior art survey.

## Context

The console library architecture ([console-library-architecture.md](console-library-architecture.md))
establishes that both async and sync event APIs should be provided, layered correctly:
the parser (L1) is sync, the foundation (L3) provides both `Async.Stream` and
`poll(timeout:)`.

**Critical realization**: The Swift Institute ecosystem already has production-grade
infrastructure for every layer of this problem:

| Concern | Existing Infrastructure | Package |
|---------|----------------------|---------|
| Kernel event polling (kqueue/epoll) | `IO.Event.Selector` (actor), `IO.Event.Driver` (witness) | swift-io |
| FD readability monitoring | `IO.Event.Channel`, `IO.Event.Token<Phase>` (~Copyable typestate) | swift-io |
| Lock-free async waiting | `IO.Event.Waiter` (atomic state, cancellation) | swift-io |
| Zero-copy event batching | `IO.Event.Buffer.Pool`, `IO.Event.Bridge` | swift-io |
| Deadline scheduling | `IO.Event.Selector` deadline heap with generation counters | swift-io |
| Wakeup/interruption | `IO.Event.Wakeup.Channel` (EVFILT_USER/eventfd) | swift-io |
| Async stream type | `Async.Stream<T>` (concrete, composable, all operators) | swift-async |
| Sync-to-async bridge | `Async.Channel.Bounded<T>`, `Async.Channel.Unbounded<T>` | swift-async |
| Multi-subscriber broadcast | `Async.Broadcast<T>` | swift-async |
| Stream operators | merge, zip, debounce, throttle, buffer, scan, transducer | swift-async |
| Parser combinators | `Parser.Protocol`, 35+ combinators, `Input.Buffer`, `Input.Slice` | swift-parser-primitives |
| Byte-level parsing | `Parser.Byte`, `Parser.Literal`, `Parser.Prefix` | swift-parser-primitives |
| Defunctionalized state machine | `Parser.Machine` (incremental, memoized) | swift-parser-machine-primitives |
| Backpressured output | `Rendering.Async.Sink.Buffered` via `Async.Channel.Bounded` | swift-rendering-primitives |

Building custom kqueue/epoll, custom async bridging, or a hand-rolled parser would be
redundant and inferior. The correct design composes existing infrastructure.

## Question

How should the console library structure the async and sync event APIs, building on the
existing `IO.Event`, `Async.Stream`, and parser primitives infrastructure?

Sub-questions:
1. How does the terminal fd integrate with `IO.Event.Selector`?
2. How do parsed events flow from parser to `Async.Stream`?
3. How does the sync API relate to the async API?
4. How are ambiguous escape sequences resolved using deadline scheduling?
5. How does resize (SIGWINCH) integrate?

## Analysis

### Prior Art (unchanged from v1.0.0)

The cross-ecosystem consensus is clear:

| Library | Parser | I/O | Async Bridge |
|---------|--------|-----|-------------|
| crossterm (Rust) | Hand-rolled state machine | mio (kqueue/epoll) | `EventStream` via background thread + `Waker` |
| tcell (Go) | Hand-rolled + timeout | goroutine + blocking read | Channels |
| prompt_toolkit (Python) | Generator state machine | asyncio `add_reader()` | Native asyncio |
| Bubbletea (Go) | ansi package parser | goroutine + cancelReader | Channels + Elm architecture |

Every library separates: (1) parser (pure, no I/O), (2) I/O source (fd monitoring),
(3) async delivery. We have production-grade implementations for all three layers.

### How crossterm's Architecture Maps to Our Infrastructure

| crossterm Component | Our Equivalent | Notes |
|--------------------|----------------|-------|
| `mio::Poll` (kqueue/epoll) | `IO.Event.Selector` + `IO.Event.Driver` | Ours is richer: typestate tokens, deadline heap, zero-copy batching |
| `mio::Waker` (EVFILT_USER/eventfd) | `IO.Event.Wakeup.Channel` | Identical mechanism |
| `InternalEventReader` (Mutex) | Not needed — Selector is an actor | Actor isolation replaces Mutex |
| `VecDeque<InternalEvent>` | `Async.Channel.Bounded` | Bounded channel with backpressure |
| `EventStream` (background thread) | `Async.Stream<T>` + `Async.Channel` bridge | No custom thread bridge needed |
| `futures::Stream` trait | `Async.Stream<T>` concrete type | Ours has full operator set (merge, debounce, etc.) |
| Parser (hand-rolled) | `Parser.Protocol` + combinators | Ours: compositional, testable, zero-copy |

### Escape Ambiguity Resolution via Deadline Scheduling

The Escape key (`0x1B`) problem: it could be (a) the Escape key, or (b) the start of
`ESC [`, `ESC O`, etc. The standard resolution is a timeout (50-100ms).

`IO.Event.Selector` already has **deadline scheduling** with generation-counter stale
detection. The flow:

1. Parser encounters `0x1B`, returns `.escapePrefix` (tentative)
2. Event source arms the terminal fd for `.read` with `deadline: .now + .milliseconds(50)`
3. If more bytes arrive before deadline → feed parser, complete the escape sequence
4. If deadline fires (no more bytes) → emit `Terminal.Input.Event.key(.escape)`

This uses existing infrastructure (the Selector's min-heap of deadline entries) rather
than a custom timer.

### Event Coalescing via `Async.Stream` Operators

Resize coalescing becomes trivial with existing operators:

```swift
let rawEvents: Async.Stream<Terminal.Input.Event> = ...
let resizeEvents = rawEvents.filter { $0.isResize }.debounce(.milliseconds(16))
let keyEvents = rawEvents.filter { $0.isKey }
let events = Async.Stream.merge(keyEvents, resizeEvents)
```

Or use the `transducer` operator for stateful coalescing:

```swift
rawEvents.transduce(with: Async.Stream.Transducer(
    initial: { CoalesceState() },
    step: { event, state in state.process(event) },
    complete: { state in state.flush() }
))
```

### Backpressure

Terminal events cannot be back-pressured (the terminal sends data regardless). The
`Async.Channel.Bounded` provides natural bounded buffering. If the consumer falls behind:

| Event Type | Strategy | Implementation |
|------------|----------|---------------|
| Key events | Buffer, never drop | `Async.Channel.Bounded` with large capacity |
| Resize | Keep latest only | `stream.debounce` or transducer |
| Mouse move | Configurable | Application-level: `stream.throttle(.milliseconds(16))` for 60fps |
| Paste | Buffer entire content | Single event delivery (parser accumulates) |

### Thread Safety

`IO.Event.Selector` is an **actor** pinned to `Kernel.Thread.Executor`. All continuation
resumptions happen on the selector's executor — the "single resumption funnel" pattern.
`Async.Stream` and `Async.Channel` are `Sendable`. No custom locking needed.

### Sync API: IO.Blocking.Lane

For consumers who don't use async, `IO.Blocking.Threads` provides a thread pool executor.
The sync API uses the same `IO.Event.Selector` but with a blocking wrapper:

```swift
let result = try await IO.Blocking.Threads.shared.run {
    // Block on the selector's arm + read cycle
}
```

Or more directly: the sync API can use `IO.Event.Driver` directly (bypassing the Selector
actor) since sync consumers don't need actor isolation. The driver's `_poll` witness
accepts a deadline and blocks the calling thread.

## Outcome

**Status**: DECISION

### Layer Architecture (revised)

| Layer | Component | Nature | Builds On |
|-------|-----------|--------|-----------|
| L1 | `Terminal.Input.Parser` | Pure sync parser | `Parser.Protocol`, `Input.Buffer`, combinators |
| L2 | `ECMA_48.Parser` | VT state machine | `Parser.Machine` (defunctionalized, incremental) |
| L3 (internal) | `Console.Events.Source` | I/O coordination | `IO.Event.Selector`, `IO.Event.Channel` |
| L3 (public) | `Console.Events.Stream` | **Async primary** | `Async.Stream<Terminal.Input.Event>` |
| L3 (public) | `Console.Events.Poll` | Sync convenience | `IO.Event.Driver` direct poll |

### Parser (L1 — builds on Parser Primitives)

The parser is composed from existing parser combinators, NOT a hand-rolled state machine:

```swift
// In Terminal Input Primitives module
Terminal.Input.Parser: Parser.Protocol
├── Input = Input.Buffer<[UInt8]>
├── ParseOutput = [Terminal.Input.Event]
├── Failure = Terminal.Input.Parser.Error
│
├── Composed from:
│   ├── Parser.OneOf(               // Branch on first byte
│   │   escapeSequence,             // 0x1B → CSI, SS3, OSC, or bare Escape
│   │   bracketedPaste,             // Accumulated between markers
│   │   printableCharacter,         // 0x20...0x7E, UTF-8 multibyte
│   │   controlCharacter            // 0x00...0x1F (Tab, Enter, Backspace, etc.)
│   │ )
│   │
│   ├── escapeSequence = Parser.Byte(0x1B).flatMap {
│   │     Parser.OneOf(
│   │       csiSequence,            // ESC [ ... → CSI dispatch
│   │       ss3Sequence,            // ESC O ... → SS3 function keys
│   │       oscSequence,            // ESC ] ... → OSC (ignored/passed)
│   │       escapeOnly              // Bare ESC (tentative — timeout at I/O layer)
│   │     )
│   │   }
│   │
│   ├── csiSequence = Parser.Literal([0x1B, 0x5B]).then(
│   │     Parser.OneOf(
│   │       csiMouse,               // CSI < Pb;Px;Py M/m (SGR mouse)
│   │       csiKitty,               // CSI code;mods u (Kitty keyboard)
│   │       csiBracketedPasteStart, // CSI 200 ~ (paste start)
│   │       csiFunctionKey,         // CSI number ~ (F5-F12, Insert, Delete, etc.)
│   │       csiCursor               // CSI A/B/C/D/H/F (arrows, Home, End)
│   │     )
│   │   )
```

The parser is **pure**: `parse(&input) → [Event]`. It consumes bytes from an
`Input.Buffer<[UInt8]>` using checkpoint-based backtracking. No I/O, no timing, no
allocation in the hot path (events written to a pre-allocated buffer).

### VT State Machine (L2 — builds on Parser.Machine)

The ECMA-48 parser should use `Parser.Machine` (defunctionalized) for the VT state
machine, following Paul Williams' canonical model. This gives us:

- **No recursive call-stack growth** — the machine is data, not closures
- **Incremental parsing** — memoization table tracks edit positions
- **~Copyable input support** — machine works with `Input.Buffer` which is `~Copyable`

```swift
ECMA_48.Parser: Parser.Machine.Parser
├── Input = Input.Buffer<[UInt8]>
├── Actions: .print(UInt8), .execute(UInt8), .csiDispatch(...),
│            .escDispatch(...), .oscDispatch(...), .hook/.put/.unhook
```

### Event Source (L3 — builds on IO.Event.Selector)

```swift
Console.Events.Source (internal)
├── selector: IO.Event.Selector          // Existing — kqueue/epoll actor
├── channel: IO.Event.Channel            // Existing — async fd monitoring
├── parser: Terminal.Input.Parser        // Parser from L1
├── asyncChannel: Async.Channel<Terminal.Input.Event>.Bounded  // Existing bridge
│
├── Lifecycle:
│   1. Obtain IO.Event.Selector (shared or dedicated)
│   2. Register terminal stdin fd: selector.register(stdin, interest: .read)
│   3. Arm for readability: selector.arm(token, interest: .read, deadline: escapeTimeout)
│   4. On readable: Kernel.IO.Read.read(stdin, into: buffer)
│   5. Feed buffer to parser: parser.parse(&input) → [Event]
│   6. Push events to Async.Channel: channel.sender.send(event)
│   7. Re-arm for next read
│   8. On deadline (escape timeout): emit bare Escape, re-arm without deadline
│
├── SIGWINCH:
│   Use signal fd or Kernel signal handler → push Terminal.Input.Event.resize(size)
│   through the same Async.Channel
│
├── Cleanup (on deinit/cancellation):
│   Deregister fd from selector, close channel, restore terminal mode
```

The event source does NOT spawn a custom background thread. The `IO.Event.Selector` already
has a dedicated poll thread and the actor-based coordination model. We register our fd
with the existing infrastructure.

### Async API (primary — Async.Stream)

```swift
Console.Events.Stream
├── Wraps Async.Stream<Terminal.Input.Event>
├── Created from Async.Channel.Bounded.Receiver via:
│   Async.Stream(from: receiver)   // Existing bridge
│
├── Gets ALL Async.Stream operators for free:
│   .filter { }           — filter event types
│   .map { }              — transform events
│   .debounce(duration)   — coalesce resize events
│   .throttle(duration)   — rate-limit mouse events
│   .buffer.count(n)      — batch events
│   .merge(other)         — combine with timer/network events
│   .scan(initial) { }    — stateful accumulation
│   .transduce(with:)     — custom state machine transforms
│
├── Lifecycle management:
│   init(configuration:)
│   → enters raw mode (Terminal.Mode.Raw.Token)
│   → enables mouse/paste/kitty per configuration
│   → creates Source, starts fd monitoring
│
│   deinit / task cancellation
│   → disables mouse/paste/kitty
│   → restores terminal mode (Token.restore())
│   → deregisters from selector
```

### Sync API (secondary — direct Driver poll)

```swift
Console.Events.Poll (~Copyable)
├── driver: IO.Event.Driver         // Direct platform driver (no Selector actor)
├── handle: IO.Event.Driver.Handle  // ~Copyable, owned
├── parser: Terminal.Input.Parser
├── eventBuffer: [Terminal.Input.Event]
│
├── poll(timeout: Duration) → Terminal.Input.Event?
│   1. If eventBuffer has events, return first
│   2. driver._poll(handle, deadline, &kernelEvents)  // Blocks calling thread
│   3. On readable: read bytes, feed parser
│   4. Return first event (buffer rest)
│
├── read() → Terminal.Input.Event
│   poll(timeout: .never)
│
├── tryRead() → Terminal.Input.Event?
│   poll(timeout: .zero)
```

The sync API bypasses the Selector actor entirely. It uses `IO.Event.Driver` directly —
the driver's `_poll` witness blocks the calling thread. No async runtime, no background
thread, no channel overhead. The `IO.Event.Driver.Handle` is `~Copyable`, ensuring
single-owner semantics.

### Mutual Exclusivity

`Console.Events.Stream` and `Console.Events.Poll` are exclusive — enforced by the
`Terminal.Mode.Raw.Token` being `~Copyable`. Creating either consumes the token.
Attempting to create both is a compile-time error.

### Why This Design Is Superior to crossterm

| Aspect | crossterm | Our Design |
|--------|-----------|-----------|
| Event polling | Custom mio wrapper | Reuses `IO.Event.Selector` (proven, audited) |
| Async bridge | Custom background thread + AtomicBool + Waker | `Async.Channel.Bounded` → `Async.Stream` (zero custom code) |
| Parser | Hand-rolled state machine | `Parser.Protocol` + combinators (compositional, testable) |
| Escape timeout | Implicit in mio poll timeout | `IO.Event.Selector` deadline scheduling (generation counters, min-heap) |
| Resize coalescing | Manual in event reader | `Async.Stream.debounce` (one line) |
| Mouse throttling | Not supported | `Async.Stream.throttle` (one line) |
| Backpressure | VecDeque capacity 32 | `Async.Channel.Bounded` (configurable) |
| Thread safety | parking_lot::Mutex | Actor isolation (compile-time verified) |
| Typestate | None | `IO.Event.Token<Phase>` (compile-time API safety) |

## References

- IO.Event.Selector: swift-io/Sources/IO Events/IO.Event.Selector.swift
- IO.Event.Driver: swift-io/Sources/IO Events/IO.Event.Driver.swift
- IO.Event.Channel: swift-io/Sources/IO Events/IO.Event.Channel.swift
- IO.Event.Token: swift-io/Sources/IO Events/IO.Event.Token.swift
- Async.Stream: swift-async/Sources/Async Stream/Async.Stream.swift
- Async.Channel: swift-async-primitives (Async.Channel.Bounded, Async.Channel.Unbounded)
- Parser.Protocol: swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift
- Parser.Machine: swift-parser-machine-primitives/Sources/Parser Machine Core Primitives/
- Rendering.Async.Sink: swift-rendering-primitives/Sources/Rendering Async Primitives/
- crossterm event module: https://docs.rs/crossterm/latest/crossterm/event/index.html
- tcell architecture: https://github.com/gdamore/tcell/blob/main/tscreen.go
- Bubbletea architecture: https://github.com/charmbracelet/bubbletea/blob/main/tea.go
