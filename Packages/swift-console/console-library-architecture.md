# Console Library Architecture

<!--
---
version: 3.0.1
last_updated: 2026-04-01
status: DECISION
tier: 2
---
-->

## Changelog

- **3.0.0** (2026-03-03): Rewritten to build on existing infrastructure. The ecosystem
  has production-grade IO event loops (swift-io), async streams with full operator sets
  (swift-async), parser combinators and defunctionalized machines (swift-parser-primitives),
  and backpressured rendering sinks (swift-rendering-primitives). The architecture now
  composes these rather than reinventing them.
- **2.0.0** (2026-03-03): Revised architecture from separate packages to multi-module
  within existing packages. Resolved all five open questions. Added modularization
  rationale and prior art detail.
- **1.0.0** (2026-03-03): Initial research with inventory, gap analysis, and three
  architecture options.

## Context

We have substantial infrastructure across three layers of the Swift Institute ecosystem
for terminal and console work:

- **Layer 1 (Primitives)**:
  - `Terminal Primitives` — `Terminal.Stream` (.stdin/.stdout/.stderr), `Terminal.Size`,
    `Terminal.Mode.Raw`, `Terminal.Mode.Raw.Token` (~Copyable RAII)
  - `Kernel Primitives` — `Kernel.Descriptor`, `Kernel.TTY`, `Kernel.Termios.Attributes`,
    `Kernel.Event` (readiness event), `Kernel.Event.Interest` (.read/.write)
  - `ASCII Primitives` — `ASCII.ControlCharacters` (.esc, .cr, .lf, .bs, .del, etc.)
  - `Text Primitives` — `Text.Location`, `Text.Line`, `Text.Line.Map`
  - `Input Primitives` — `Input.Protocol` (checkpoint backtracking), `Input.Buffer`,
    `Input.Slice` (zero-copy cursors)
  - `Parser Primitives` — `Parser.Protocol` (typed throws), 35+ combinators (OneOf, Map,
    FlatMap, Many, Byte, Literal, Prefix, Peek, etc.), `Input.Buffer<[UInt8]>` support
  - `Parser Machine Primitives` — `Parser.Machine` (defunctionalized, incremental, memoized),
    recursive grammar support, ~Copyable input compatibility
  - `Binary Parser Primitives` — `Binary.Bytes.Input`, `Binary.Bytes.Machine`,
    byte-level parsing
  - `Buffer Primitives` — `Buffer.Ring.Bounded`, `Buffer.Linear`, 14 modules
  - `Rendering Primitives` — `Rendering.Async.Sink.Buffered` (backpressured async output
    via `Async.Channel.Bounded.Sender`)
- **Layer 2 (Standards)**:
  - `ECMA 48` — SGR attributes (19 cases), `SGR.Color` (palette/256/RGB), `Cursor`
    (movement, save/restore, show/hide), `Screen` (erase, scroll, alternate buffer).
    **Output-only** — no parser yet.
  - `ISO 9945` — POSIX terminal: `isatty`, `ioctl(TIOCGWINSZ)`, `tcgetattr`/`tcsetattr`,
    raw mode implementation via `Kernel.Termios.Attributes.withRaw()`
  - `Color Standard` — RGB → 256 → 16 degradation with `Color.sgr` conversions
- **Layer 3 (Foundations)**:
  - `Console` — `Console.Capability` (color, cursor, alternate screen detection),
    `Console.Style` (.bold, .error, .warning, .success, .info)
  - `IO` — **Production-grade event-driven I/O**: `IO.Event.Selector` (actor, kqueue/epoll),
    `IO.Event.Driver` (witness-based platform abstraction), `IO.Event.Channel` (async fd
    monitoring with typestate tokens), `IO.Event.Waiter` (lock-free, cancellation-safe),
    `IO.Event.Bridge` (zero-copy thread-safe handoff), `IO.Event.Buffer.Pool`,
    `IO.Event.Wakeup.Channel` (EVFILT_USER/eventfd), deadline scheduling
  - `IO.Blocking.Threads` — Thread pool executor with backpressure, deadline management
  - `Async` — `Async.Stream<T>` (concrete composable stream type), `Async.Channel.Bounded`,
    `Async.Channel.Unbounded`, `Async.Broadcast`, operators: merge, zip, combineLatest,
    debounce, throttle, buffer, scan, transducer, flatMap.latest, share, replay
  - `Parsers` — Re-exports all parser primitives + higher-level parsers (Integer,
    Identifier, Expression, Whitespace, Comment, Quoted)

The current `Console` module provides capability detection (NO_COLOR, FORCE_COLOR,
COLORTERM, TERM, CI) and styled text output. This is a solid foundation but covers
only a fraction of what a comprehensive command-line library needs.

The goal is to design the architecture for expanding the console/CLI library surface
while maintaining the Five-Layer Architecture, the Nest.Name convention, and the
layered composability that distinguishes this ecosystem.

## Question

What should the architecture, scope, layer placement, and implementation roadmap be
for expanding terminal/console/CLI capabilities in the Swift Institute ecosystem?

Sub-questions:
1. What components are needed and how do they decompose?
2. What belongs in `swift-console` vs `swift-terminal-primitives` vs `swift-ecma-48`?
3. How do we handle the terminal event loop (key events, resize, mouse)?
4. Should we pursue a TUI framework, and if so, at what layer?
5. What is the right phased delivery order?
6. Modules within existing packages, or new packages?

## Existing Infrastructure Inventory

### Layer 1 — Primitives

#### Core Terminal

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-terminal-primitives | `Terminal Primitives` | `Terminal.Stream` (.stdin/.stdout/.stderr), `Terminal.Size`, `Terminal.Mode.Raw`, `Terminal.Mode.Raw.Token` (~Copyable RAII), `Terminal.Stream.Interactive`, `Terminal.Error` | Complete |
| swift-kernel-primitives | `Kernel Primitives` | `Kernel.Descriptor`, `Kernel.Error`, `Kernel.TTY`, `Kernel.Termios`, `Kernel.Termios.Attributes`, `Kernel.Console` (Windows) | Complete |

#### Text & Characters

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-ascii-primitives | `ASCII Primitives` | `ASCII.ControlCharacters` (ESC, LF, CR, TAB, DEL...), `ASCII.GraphicCharacters`, `ASCII.LineEnding`, `ASCII.Validation` | Complete |
| swift-text-primitives | `Text Primitives` | `Text.Location`, `Text.Range`, `Text.Line`, `Text.Line.Number`, `Text.Line.Column`, `Text.Line.Map` | Complete |
| swift-string-primitives | `String Primitives` | `String` (~Copyable), `String.View`, `String.Char`, `String.Length` | Complete |

#### I/O & Buffers

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-input-primitives | `Input Primitives` | `Input.Protocol` (checkpoint backtracking), `Input.Stream.Protocol` (forward-only), `Input.Buffer`, `Input.Slice` (zero-copy), `Input.Access.Random` | Complete |
| swift-buffer-primitives | 14 modules | `Buffer.Ring.Bounded`, `Buffer.Linear`, `Buffer.Storage.Heap`, inline variants | Complete |
| swift-handle-primitives | `Handle Primitives` | Handle abstraction over file descriptors | Complete |

#### Parsing

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-parser-primitives | 35 modules | `Parser.Protocol<Input, Output, Failure>` (typed throws, ~Copyable input), `Parser.OneOf`, `Parser.Map`, `Parser.FlatMap`, `Parser.Many`, `Parser.Byte`, `Parser.Literal`, `Parser.Prefix`, `Parser.Peek`, `Parser.Not`, `Parser.Backtrack` | Complete |
| swift-parser-machine-primitives | 6 modules | `Parser.Machine` (defunctionalized, no call-stack growth), `Parser.Machine.Memoization` (incremental), `Parser.Machine.Compile`, `Parser.Machine.Recursive` | Complete |
| swift-binary-parser-primitives | 9 modules | `Binary.Bytes.Input` (owned cursor), `Binary.Bytes.Input.View` (~Escapable borrowed), `Binary.Bytes.Machine` | Complete |

#### Formatting & Rendering

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-formatting-primitives | `Formatting Primitives` | `Format.Numeric`, `FormatStyle`, sign/separator/notation strategies | Complete |
| swift-rendering-primitives | `Rendering Async Primitives` | `Rendering.Async.Sink.Protocol`, `.Sink.Buffered` (backpressured via `Async.Channel.Bounded`), `.Sink.Chunked` | Complete |
| swift-property-primitives | `Property Primitives` | `Property.View`, `.View.Typed`, `.Valued` (nested accessor pattern) | Complete |

### Layer 2 — Standards

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-ecma-48 | `ECMA 48` | `ECMA_48.SGR.Attribute` (19 cases), `SGR.Color` (palette/256/RGB), `Cursor` (movement, save/restore, show/hide), `Screen` (erase, scroll, alternate buffer). **Output-only — no parser.** | Complete |
| swift-iso-9945 | `ISO 9945 Kernel` | Extensions: `Terminal.Stream.Interactive`, `Terminal.Size.query()`, `Terminal.Mode.Raw.enter()` (termios manipulation) | Complete |
| swift-color-standard | `Color Standard` | `Color.sgr`, `.sgr(for:)`, `.sgr256`, `.sgrPalette` (RGB to 256 to 16 degradation) | Complete |

### Layer 3 — Foundations

| Package | Module | Key Types | Status |
|---------|--------|-----------|--------|
| swift-console | `Console` | `Console.Capability` (color, cursor, alternate screen), `Console.Capability.Color` (none/palette4/palette8/trueColor), `Console.Style` (.bold, .error, .warning, .success, .info) | Complete |
| swift-io | `IO Events` | `IO.Event.Selector` (actor, kqueue/epoll), `IO.Event.Driver` (witness platform abstraction), `IO.Event.Channel` (async fd monitoring), `IO.Event.Token<Phase>` (~Copyable typestate), `IO.Event.Waiter` (lock-free), `IO.Event.Bridge` (zero-copy), `IO.Event.Buffer.Pool`, `IO.Event.Wakeup.Channel`, deadline scheduling | Complete |
| swift-io | `IO Blocking` | `IO.Blocking.Threads` (thread pool with backpressure, deadline management) | Complete |
| swift-async | `Async Stream` | `Async.Stream<T>` (concrete composable), operators: merge, zip, combineLatest, debounce, throttle, buffer, scan, transducer, flatMap.latest, share, replay | Complete |
| swift-async | `Async` | `Async.Channel.Bounded/Unbounded` (sync-to-async bridge), `Async.Broadcast` (multi-subscriber) | Complete |
| swift-parsers | `Parsers` | Re-exports parser primitives + Integer, Identifier, Expression, Whitespace, Comment, Quoted | Complete |

## Gap Analysis

What exists vs. what a comprehensive CLI library needs:

| Capability | Have | Layer | Gap |
|------------|------|-------|-----|
| Terminal stream abstraction | Yes | L1 | — |
| Raw mode with RAII | Yes | L1+L2 | — |
| Terminal size query | Yes | L1+L2 | — |
| ANSI escape generation | Yes | L2 | — |
| ANSI escape *parsing* | **No** | — | Need VT state machine parser (build on `Parser.Machine`) |
| Parser combinators | Yes | L1 | — (30+ combinators, byte-level matching) |
| Event-driven fd monitoring | Yes | L3 | — (`IO.Event.Selector`, kqueue/epoll) |
| Async stream with operators | Yes | L3 | — (`Async.Stream`, merge/debounce/throttle) |
| Sync-to-async bridge | Yes | L3 | — (`Async.Channel.Bounded/Unbounded`) |
| Backpressured output | Yes | L1 | — (`Rendering.Async.Sink.Buffered`) |
| Capability detection | Yes | L3 | — |
| Styled text output | Yes | L3 | — |
| Key event types + parser | **No** | — | Need `Terminal.Input.Event/Key` types + parser combinators |
| Mouse event types + parser | **No** | — | Need `Terminal.Input.Mouse` types + SGR parser |
| Resize event handling | **No** | — | SIGWINCH → `IO.Event.Selector` integration |
| Unified event stream | **No** | — | Compose IO.Event.Selector + parser → `Async.Stream` |
| Line editing | **No** | — | Readline-style input |
| Interactive prompts | **No** | — | Confirm, select, text input |
| Progress indicators | **No** | — | Bars, spinners, multi-bar |
| Table/grid layout | **No** | — | Columnar data display |
| Argument parsing | **No** | — | Deliberate non-goal (defer to ArgumentParser) |
| TUI widgets | **No** | — | Future Layer 4 concern |
| TUI layout engine | **No** | — | Future Layer 4 concern |

## Prior Art

### Layering Patterns Across Ecosystems

| Concern | Rust | Swift (current) | Node |
|---------|------|-----------------|------|
| Terminal abstraction | crossterm (backend) | Terminal Primitives + ISO 9945 | Node runtime |
| Color/style | console crate | ECMA 48 + Console.Style | chalk |
| Arg parsing | clap (derive + builder) | ArgumentParser (Apple) | commander |
| Interactive prompts | dialoguer | **none** | inquirer |
| Progress/spinners | indicatif | **none** | ora, listr2 |
| TUI framework | ratatui (immediate-mode, backend-agnostic) | SwiftTUI (experimental) | ink (React), blessed |

### Key Architectural Insights from Prior Art

**Rust `console-rs` family** (mitsuhiko): Three crates with clean separation:
- `console` — terminal abstraction, ANSI, detection (≈ our Terminal Primitives + Console)
- `dialoguer` — interactive prompts built on `console`
- `indicatif` — progress bars built on `console`

This demonstrates that prompts and progress are **peer concerns** sharing a terminal
abstraction, not a monolithic framework. In Rust these are separate *crates* because
Cargo's package model differs from SwiftPM. The architectural insight (peer modules
over a shared core) transfers; the packaging choice does not.

**Rust `ratatui`**: Immediate-mode TUI rendering with pluggable backends (crossterm or
termion). Key insight: the TUI framework does NOT own the event loop — the application
does. This keeps the framework composable.

**Rust `crossterm`**: Command-queue pattern (`queue!` + `flush`) for batching terminal
operations. Provides unified `Event` enum (Key, Mouse, Resize) with an event stream.
This is the missing primitive in our stack. Crossterm provides both `EventStream`
(async) and `poll()`/`read()` (sync) — we should do the same.

**Node ecosystem**: chalk + inquirer + commander compose without formal layering but
each owns a clear domain. No library tries to be everything.

**Anti-patterns observed**:
- ConsoleKit (Vapor): Tightly coupled to NIO dependency graph — too heavyweight for standalone use
- blessed (Node): Monolithic widget toolkit, now unmaintained — scope too large for one project
- SwiftTUI: Retained-mode SwiftUI clone — high ambition, limited adoption, hard to maintain

## Analysis

### Modules vs. Packages

The original v1.0 proposed separate packages (`swift-console-events`,
`swift-console-prompts`, etc.) modeled after Rust's `console-rs` family.

However, our ecosystem's established pattern is **multi-module packages** when
components share a namespace and core:

| Precedent | Pattern | Modules |
|-----------|---------|---------|
| swift-buffer-primitives | Shared core + discipline modules | 15 products, 14 source targets |
| swift-async | Shared core + concern modules | 3 products (Async, Async Sequence, Async Stream) |
| swift-ascii | Module + test support | 2 products |

Single-module packages account for ~95% of our packages. Multi-module is reserved for
cases where a shared core serves distinct discipline variants — which is exactly what
Console is: a shared core (capability + style) serving distinct interactive concerns
(events, prompts, progress, layout, line editing).

**Decision**: Multi-module within existing packages.

Rationale:
- All modules share the `Console` namespace and `Console.Capability`/`Console.Style` core
- Consumers declare one dependency (`swift-console`), import specific modules
- Unified versioning — modules evolve together
- Less boilerplate (one Package.swift, one CI pipeline per package)
- SwiftPM only compiles imported targets — unused modules cost nothing

The same reasoning applies at Layer 1: `Terminal Input Primitives` shares the
`Terminal` namespace with `Terminal Primitives` and depends on the same `Kernel
Primitives`. It belongs as a second module in `swift-terminal-primitives`.

### Architecture Options (revised)

#### Option A: Monolithic single module

Expand the existing `Console` module with all new types.

**Rejected**: Consumers import everything. No selective compilation. Violates the
buffer-primitives precedent for discipline separation.

#### Option B: Multi-module within existing packages (selected)

Add modules to `swift-terminal-primitives` and `swift-console`. Each module is a
separate SwiftPM target with its own source directory and test target. Consumers
import only what they need.

**Selected**: Matches ecosystem precedent. Balances composability with package
management simplicity. Follows the buffer-primitives pattern.

#### Option C: Separate packages per concern

Create `swift-console-events`, `swift-console-prompts`, etc. as separate sub-packages
in the `swift-foundations` monorepo.

**Rejected**: Unnecessary package proliferation. The concerns are not independent
enough to warrant separate versioning. The Rust `console-rs` pattern exists because
of Cargo's package model, not because of inherent architectural need.

### Layer Placement Analysis

| Component | Layer | Package | Module | Rationale | Builds On |
|-----------|-------|---------|--------|-----------|-----------|
| Key/mouse/resize event *types* | L1 | swift-terminal-primitives | `Terminal Input Primitives` | Atomic, no policy, reusable | Terminal Primitives, ASCII Primitives |
| Escape sequence *parsing* | L1 | swift-terminal-primitives | `Terminal Input Primitives` | Specification-shaped parser | Parser Primitives (OneOf, Byte, Literal, Prefix) |
| VT state machine | L2 | swift-ecma-48 | `ECMA 48` (extended) | ECMA-48 specification | Parser.Machine (defunctionalized, incremental) |
| Signal handling (SIGWINCH) | L2 | swift-iso-9945 | `ISO 9945 Kernel` (extended) | POSIX-specific | Kernel Primitives |
| Event source / fd monitoring | L3 | swift-console | `Console Events` | Compose terminal fd + parser | **IO.Event.Selector**, IO.Event.Channel |
| Unified event stream | L3 | swift-console | `Console Events` | Async delivery | **Async.Stream**, Async.Channel.Bounded |
| Interactive prompts | L3 | swift-console | `Console Prompts` | Composed from events + style | Console Events, Console core |
| Progress indicators | L3 | swift-console | `Console Progress` | Composed from style + timer | Console core, **Async.Stream.interval** |
| Table/grid layout | L3 | swift-console | `Console Layout` | Composed from style + text | Console core, Text Primitives |
| Line editing | L3 | swift-console | `Console Line` | Composed from events + buffer | Console Events, Buffer Primitives |
| TUI widget framework | L4 | Separate future package | — | Opinionated assembly | Console Events, **Rendering.Async.Sink** |
| Argument parsing | — | — | — | Deliberate non-goal | — |

## Proposed Architecture

### Layer 1: `swift-terminal-primitives` (extended)

New module: **`Terminal Input Primitives`**

Event types and escape sequence parsing. No I/O, no policy — pure data types and a
parser composed from existing parser combinators.

```
Terminal.Input (namespace)
├── Terminal.Input.Event (enum)
│   ├── .key(Terminal.Input.Key)
│   ├── .mouse(Terminal.Input.Mouse)
│   ├── .resize(Terminal.Size)
│   ├── .paste(String)                    // bracketed paste
│   └── .escapePrefix                     // tentative: 0x1B seen, timeout pending
├── Terminal.Input.Key (struct)
│   ├── code: Terminal.Input.Key.Code     // character, arrow, function, etc.
│   ├── modifiers: Terminal.Input.Key.Modifiers  // shift, ctrl, alt, super
│   ├── text: String?                     // Kitty protocol: associated text
│   └── kind: Terminal.Input.Key.Kind?    // Kitty protocol: press/repeat/release
├── Terminal.Input.Key.Code (enum)
│   ├── .character(Unicode.Scalar)
│   ├── .function(UInt8)                  // F1-F24
│   ├── .up, .down, .left, .right
│   ├── .enter, .escape, .tab, .backspace, .delete
│   ├── .home, .end, .pageUp, .pageDown
│   └── .insert
├── Terminal.Input.Key.Modifiers (OptionSet)
│   └── .shift, .control, .alt, .super, .hyper, .meta, .capsLock, .numLock
├── Terminal.Input.Key.Kind (enum)
│   └── .press, .repeat, .release        // Kitty protocol only
├── Terminal.Input.Mouse (struct)
│   ├── kind: Terminal.Input.Mouse.Kind
│   ├── column: UInt16
│   ├── row: UInt16
│   └── modifiers: Terminal.Input.Key.Modifiers
├── Terminal.Input.Mouse.Kind (enum)
│   └── .press(Button), .release(Button), .move, .drag(Button),
│       .scrollUp, .scrollDown, .scrollLeft, .scrollRight
├── Terminal.Input.Mouse.Button (enum)
│   └── .left, .right, .middle, .backward, .forward
│
└── Terminal.Input.Parser: Parser.Protocol
    ├── Input = Input.Buffer<[UInt8]>
    ├── ParseOutput = [Terminal.Input.Event]
    ├── Failure = Terminal.Input.Parser.Error
    │
    ├── Composed from existing parser combinators:
    │   Parser.OneOf(
    │     escapeSequence,          // Parser.Byte(0x1B) → CSI/SS3/OSC/bare
    │     bracketedPasteContent,   // Accumulate between markers
    │     printableCharacter,      // Parser.Filter { $0 >= 0x20 }
    │     controlCharacter         // Parser.Filter { $0 < 0x20 || $0 == 0x7F }
    │   )
    │
    │   csiSequence = Parser.Literal([0x1B, 0x5B]).then(
    │     Parser.OneOf(
    │       csiSGRMouse,           // CSI < Pb;Px;Py M/m
    │       csiKittyKey,           // CSI code;mods u
    │       csiBracketedPaste,     // CSI 200 ~ / CSI 201 ~
    │       csiFunctionKey,        // CSI number ~
    │       csiCursorKey           // CSI A/B/C/D/H/F
    │     )
    │   )
    │
    ├── Zero-copy: consumes from Input.Buffer via checkpoint backtracking
    ├── Non-allocating hot path (events written to pre-allocated buffer)
    └── Testable in isolation: parse(&Input.Buffer([0x1B, 0x5B, 0x41])) → [.key(.up)]
```

Internal dependency within the package: depends on `Terminal Primitives` (for
`Terminal.Size`, `Terminal.Stream`).

External dependencies: `ASCII Primitives`, `Parser Primitives` (OneOf, Map, Byte,
Literal, Prefix, Filter, Many), `Input Primitives` (Input.Buffer).

### Layer 2: Standards Extensions

#### In `swift-ecma-48` (extended module)

Add escape sequence parsing — symmetric with existing generation. Built on
`Parser.Machine` (defunctionalized) for the VT state machine:

```
ECMA_48.Parser: Parser.Machine.Parser
├── Input = Input.Buffer<[UInt8]>
├── Actions: .print(UInt8), .execute(UInt8), .csiDispatch(...),
│            .escDispatch(...), .oscDispatch(...), .hook/.put/.unhook
│
├── Built on Parser.Machine for:
│   ├── No recursive call-stack growth (defunctionalized)
│   ├── Incremental parsing with memoization
│   ├── ~Copyable input compatibility
│   └── Follows Paul Williams' canonical VT parser state machine
│
├── Why Parser.Machine (not Parser.Protocol):
│   The VT state machine has 16 states × 256 byte transitions.
│   Representing this as nested Parser.OneOf would be inefficient.
│   Parser.Machine represents it as data (instruction program) with
│   table-driven dispatch — the natural fit for a state machine.
```

This follows Paul Williams' VT parser state machine — the standard approach used by
crossterm, alacritty, wezterm, and others.

#### In `swift-iso-9945` (extended module)

Add SIGWINCH handling:

```swift
extension Terminal.Size {
    static func onResize(_ handler: @Sendable @escaping (Terminal.Size) -> Void)
}
```

### Layer 3: `swift-console` (multi-module)

#### Package Structure

```
swift-console/
├── Package.swift
├── Sources/
│   ├── Console/                  ← EXISTING (core: capability, style)
│   ├── Console Events/           ← NEW: async + sync event stream
│   ├── Console Prompts/          ← NEW: interactive prompts
│   ├── Console Progress/         ← NEW: progress bars, spinners
│   ├── Console Layout/           ← NEW: tables, columns, wrapping
│   └── Console Line/             ← NEW (stretch): line editing
├── Tests/
│   ├── Console Tests/            ← EXISTING
│   ├── Console Events Tests/     ← NEW
│   ├── Console Prompts Tests/    ← NEW
│   ├── Console Progress Tests/   ← NEW
│   ├── Console Layout Tests/     ← NEW
│   └── Console Line Tests/       ← NEW (stretch)
└── Research/
```

#### Products

| Product | Targets | Purpose |
|---------|---------|---------|
| `Console` | `["Console"]` | Core capability + style (existing) |
| `Console Events` | `["Console Events"]` | Event stream |
| `Console Prompts` | `["Console Prompts"]` | Interactive prompts |
| `Console Progress` | `["Console Progress"]` | Progress indicators |
| `Console Layout` | `["Console Layout"]` | Structured text output |
| `Console Line` | `["Console Line"]` | Line editing (stretch) |
| `Console All` | all of the above | Umbrella re-export |

#### Module: `Console Events`

Unified terminal event stream composing the primitives parser with I/O. This module
builds almost entirely on existing infrastructure — the novel code is glue, not machinery.

```
Console.Events (namespace)
├── Console.Events.Configuration (struct)
│   ├── mouse: Mouse          // .disabled (default), .normal/.buttonEvent/.anyEvent
│   ├── paste: Paste          // .disabled (default), .bracketed
│   └── keyboard: Keyboard    // .legacy (default), .kitty / .kitty(flags:)
│
├── Console.Events.Source (internal)
│   ├── Registers terminal stdin fd with IO.Event.Selector
│   ├── Arms IO.Event.Channel for readability with deadline (escape timeout)
│   ├── On readable: Kernel.IO.Read.read(stdin, into: buffer)
│   ├── Feeds buffer to Terminal.Input.Parser → [Terminal.Input.Event]
│   ├── Pushes events through Async.Channel.Bounded.Sender
│   ├── On deadline (escape timeout): emit .key(.escape), re-arm without deadline
│   ├── SIGWINCH: push Terminal.Input.Event.resize(size) through same channel
│   └── Cleanup: deregister fd, close channel, restore terminal mode
│
├── Console.Events.Stream (struct)
│   ├── Wraps Async.Stream<Terminal.Input.Event>
│   ├── Created from Async.Channel.Bounded.Receiver via Async.Stream(from:)
│   ├── Gets ALL Async.Stream operators for free:
│   │   .filter { }           — filter event types
│   │   .debounce(duration)   — coalesce resize events (1 line)
│   │   .throttle(duration)   — rate-limit mouse events (1 line)
│   │   .merge(other)         — combine with timer/network events
│   │   .scan(initial) { }    — stateful accumulation
│   │   .transduce(with:)     — custom state machine transforms
│   ├── Lifecycle:
│   │   init(configuration:) → enters raw mode (Terminal.Mode.Raw.Token)
│   │                        → enables mouse/paste/kitty per configuration
│   │                        → creates Source, starts fd monitoring
│   │   deinit/cancellation  → disables protocols, restores mode, deregisters
│   └── Mutual exclusivity with Console.Events.Poll enforced by
│       Terminal.Mode.Raw.Token being ~Copyable (creating either consumes it)
│
└── Console.Events.Poll (~Copyable)
    ├── Uses IO.Event.Driver directly (bypasses Selector actor)
    ├── driver._poll(handle, deadline, &kernelEvents) blocks calling thread
    ├── No async runtime, no background thread, no channel overhead
    ├── poll(timeout:) → Terminal.Input.Event?
    ├── read() → Terminal.Input.Event   // blocks indefinitely
    └── tryRead() → Terminal.Input.Event?   // non-blocking
```

**Infrastructure composed** (no custom implementations needed):
| Concern | Existing Infrastructure | Package |
|---------|----------------------|---------|
| Kernel event polling | `IO.Event.Selector` (actor, kqueue/epoll) | swift-io |
| FD readability monitoring | `IO.Event.Channel`, `IO.Event.Token<Phase>` (~Copyable typestate) | swift-io |
| Escape timeout | `IO.Event.Selector` deadline scheduling (min-heap, generation counters) | swift-io |
| Wakeup/interruption | `IO.Event.Wakeup.Channel` (EVFILT_USER/eventfd) | swift-io |
| Sync-to-async bridge | `Async.Channel.Bounded<Terminal.Input.Event>` | swift-async |
| Async delivery | `Async.Stream<Terminal.Input.Event>` | swift-async |
| Stream operators | merge, debounce, throttle, scan, transducer | swift-async |
| Sync poll (no async) | `IO.Event.Driver` direct `_poll` witness | swift-io |

**Dependencies**: `Console`, `Terminal Input Primitives`, `ISO 9945 Kernel`,
`IO Events` (swift-io), `Async Stream` + `Async` (swift-async)

#### Module: `Console Prompts`

Interactive prompt components.

```
Console.Prompt (namespace)
├── Console.Prompt.Confirm       → yes/no with default
├── Console.Prompt.Input         → free text with validation
├── Console.Prompt.Password      → masked input
├── Console.Prompt.Select        → single selection from list
└── Console.Prompt.MultiSelect   → multiple selections
```

**Dependencies**: `Console`, `Console Events`

#### Module: `Console Progress`

Progress indicators. Output-only — no event loop dependency.

```
Console.Progress (namespace)
├── Console.Progress.Bar         → bounded progress bar with template
├── Console.Progress.Spinner     → unbounded activity indicator
├── Console.Progress.Multi       → multiple concurrent indicators (Sendable)
└── Console.Progress.Template    → format string for progress display
```

Output rendering uses `Rendering.Async.Sink.Buffered` for backpressured terminal writes.
Timer ticks for spinner animation use `Async.Stream.interval` or `Async.Stream.timer`.

**Dependencies**: `Console`, `Rendering Async Primitives`, `Async Stream`

#### Module: `Console Layout`

Structured text output.

```
Console.Layout (namespace)
├── Console.Layout.Table         → columnar data with headers, alignment, borders
├── Console.Layout.Grid          → fixed-width grid
├── Console.Layout.Columns       → side-by-side text blocks
└── Console.Layout.Wrap          → text wrapping respecting terminal width
```

**Dependencies**: `Console`

#### Module: `Console Line` (stretch)

Line editing for REPL-style interfaces.

```
Console.Line (namespace)
├── Console.Line.Editor          → readline-style line editing
├── Console.Line.History         → command history
└── Console.Line.Completion      → tab completion
```

**Dependencies**: `Console`, `Console Events`

### Intra-Package Dependency Graph

```
swift-console internal:
                                  ┌──────────────┐
                                  │ Console All   │ (umbrella)
                                  └──────┬────────┘
            ┌─────────┬──────────────────┼──────────────┬───────────┐
            │         │                  │              │           │
     ┌──────▼───┐ ┌───▼──────┐  ┌───────▼───────┐ ┌───▼────┐ ┌───▼────┐
     │ Prompts  │ │  Line    │  │    Events     │ │Progress│ │ Layout │
     └────┬─────┘ └────┬─────┘  └───────┬───────┘ └───┬────┘ └───┬────┘
          │             │                │             │           │
          └─────────────┴────────────────┤             │           │
                                         │             │           │
                                  ┌──────▼─────────────▼───────────▼──┐
                                  │            Console (core)          │
                                  └────────────────────────────────────┘
```

### Cross-Package Dependency Graph

```
swift-console (L3)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Console Events ─────┬──────► swift-io (L3)                 │
│    │                 │         IO.Event.Selector             │
│    │                 │         IO.Event.Channel              │
│    │                 │         IO.Event.Driver               │
│    │                 │                                       │
│    │                 ├──────► swift-async (L3)               │
│    │                 │         Async.Stream                  │
│    │                 │         Async.Channel.Bounded         │
│    │                 │                                       │
│    │                 └──────► swift-terminal-primitives (L1) │
│    │                           Terminal Input Primitives     │
│    │                                                        │
│  Console Prompts ──────────► Console Events                 │
│  Console Line ─────────────► Console Events                 │
│    │                                                        │
│  Console Progress ─────────► swift-rendering-primitives (L1)│
│    │                          Rendering.Async.Sink          │
│    │                 ┌──────► swift-async (L3)               │
│    │                 │         Async.Stream                  │
│    │                 │                                       │
│  Console Layout      │                                      │
│    │                 │                                       │
│  Console (core) ─────┴──────► swift-ecma-48 (L2)            │
│                                ECMA 48 (SGR, Cursor, Screen)│
│                       ┌─────► swift-iso-9945 (L2)           │
│                       │        ISO 9945 (raw mode, SIGWINCH)│
└───────────────────────┘                                     │
                                                              │
swift-terminal-primitives (L1)                                │
┌─────────────────────────────────────────────────┐           │
│  Terminal Primitives                            │           │
│  Terminal Input Primitives ──► swift-parser-primitives (L1) │
│    │                           Parser.Protocol, combinators │
│    └─────────────────────────► swift-input-primitives (L1)  │
│                                Input.Buffer, Input.Slice    │
└─────────────────────────────────────────────────┘           │
                                                              │
swift-ecma-48 (L2)                                            │
┌─────────────────────────────────────────────────┐           │
│  ECMA 48 (+ VT Parser) ─────► swift-parser-machine-prims   │
│                                Parser.Machine               │
└─────────────────────────────────────────────────┘
```

**Key insight**: Console Events composes three existing foundation packages (IO, Async,
Parsers) with one new primitives module (Terminal Input). The novel code is coordination
glue — registration, read-parse-dispatch, lifecycle — not infrastructure.

### Argument Parsing — Deliberate Non-Goal

Argument parsing is excluded from this architecture. Apple's Swift ArgumentParser is
the established solution and operates in a different domain (command structure, not
terminal I/O). Our libraries compose alongside it without coupling:

```swift
import ArgumentParser
import Console_Prompts

@main struct Deploy: ParsableCommand {
    mutating func run() throws {
        let env = Console.Prompt.Select(
            "Target environment?",
            options: ["staging", "production"]
        ).run()

        guard Console.Prompt.Confirm("Deploy to \(env)?").run() else { return }
        // proceed
    }
}
```

If someone later wants a `@PromptOption` property wrapper that integrates Console
prompts into ArgumentParser's validation phase, that is a Layer 4 Component concern.

### TUI Framework — Deliberate Future (Layer 4)

TUI is opinionated assembly (widget tree, layout engine, render loop). It belongs at
the Component layer. A future TUI package would consume `Console Events` as its
backend, similar to how ratatui uses crossterm. The primitives and foundation modules
designed here provide the right abstraction surface for that future work.

## Design Decisions

### 1. Mouse Protocol — Opt-In

**Decision**: Mouse capture (SGR 1006) is opt-in, disabled by default.

**Rationale**: Enabling mouse capture steals text selection from the terminal emulator.
This is jarring for CLI tools where the user expectation is: terminal mouse = select
text, not interact with the program. Only TUI frameworks and specific prompt widgets
(clickable selection lists) need mouse events.

**API**:
```swift
Console.Events.Stream(configuration: .init(mouse: .disabled))       // default
Console.Events.Stream(configuration: .init(mouse: .normal))         // click + release (1000)
Console.Events.Stream(configuration: .init(mouse: .buttonEvent))    // + drag (1002)
Console.Events.Stream(configuration: .init(mouse: .anyEvent))       // + all motion (1003)
```

SGR 1006 encoding is always used when mouse is enabled. Three configurable tracking modes
give consumers bandwidth control (Bubbletea-style granularity over crossterm's all-or-nothing).

The `Terminal.Input.Mouse` type exists in primitives regardless — it is the *enabling*
of the protocol that is opt-in at the foundation layer.

### 2. Bracketed Paste — Opt-In, Recommended for Line Editing

**Decision**: Bracketed paste is opt-in at the event stream level, but on by default
in `Console.Line.Editor`.

**Rationale**: Bracketed paste wraps pasted content in `\e[200~`...`\e[201~` so the
program can distinguish typed input from pasted text. Without it, pasted text is
indistinguishable from rapid keystrokes — this is a **security concern** for line
editors (pasted text could contain newlines that trigger command execution mid-paste).
Simple prompts don't need it.

**API**:
```swift
Console.Events.Stream(configuration: .init(paste: .disabled))    // default
Console.Events.Stream(configuration: .init(paste: .bracketed))   // opt-in
```

When enabled, paste content is delivered as `Terminal.Input.Event.paste(String)`
instead of individual key events.

### 3. Kitty Keyboard Protocol — Progressive Enhancement

**Decision**: Design the `Terminal.Input.Key` type to accommodate Kitty protocol data
from day one, but don't require or default-enable the protocol.

**Rationale**: The Kitty protocol provides disambiguated keys (Ctrl+i vs Tab),
key release events, and associated text. This is genuinely useful but only ~60% of
terminals support it (Kitty, WezTerm, Ghostty, foot, rio — notably NOT macOS
Terminal.app or iTerm2 as of early 2026).

**Design**: Progressive enhancement at the type level:

```swift
Terminal.Input.Key
├── code: Code              // works with both legacy and Kitty
├── modifiers: Modifiers    // always present
├── text: String?           // nil on legacy terminals, populated with Kitty
└── kind: Kind?             // nil on legacy terminals; .press/.repeat/.release with Kitty
```

The parser detects Kitty responses and fills the extra fields when available. Legacy
terminals get `text: nil, kind: nil`. No consumer code breaks either way.

**API**:
```swift
Console.Events.Stream(configuration: .init(keyboard: .legacy))  // default, universal
Console.Events.Stream(configuration: .init(keyboard: .kitty))   // opt-in, richer events
```

### 4. Async vs Sync Event API — Both, Layered on Existing Infrastructure

**Decision**: Provide both, built entirely on existing IO and Async infrastructure.

| Layer | API | Nature | Builds On |
|-------|-----|--------|-----------|
| L1 (Primitives) | `Terminal.Input.Parser` | **Sync**. Pure: `parse(&input) → [Event]`. No I/O. | `Parser.Protocol`, combinators |
| L3 (Foundation) | `Console.Events.Stream` | **Async primary**. `Async.Stream<Terminal.Input.Event>`. | `IO.Event.Selector` + `Async.Channel.Bounded` → `Async.Stream` |
| L3 (Foundation) | `Console.Events.Poll` | **Sync convenience**. `poll(timeout:) → Event?`. | `IO.Event.Driver` direct `_poll` (no async runtime) |

**Rationale**: The parser is a primitive composed from `Parser.Protocol` combinators.
The async API registers the terminal fd with `IO.Event.Selector` (actor, kqueue/epoll)
and bridges events through `Async.Channel.Bounded` into `Async.Stream` — which gives
every operator (merge, debounce, throttle, scan, transducer) for free. The sync API
bypasses the Selector actor entirely, using `IO.Event.Driver._poll` to block the calling
thread directly — zero async overhead for simple scripts. Escape timeout uses the
Selector's built-in deadline scheduling (min-heap with generation counters).

No custom kqueue/epoll, no custom async bridging, no background thread. Every component
is production-grade and already audited.

### 5. ArgumentParser Integration — Fully Independent

**Decision**: No coupling, no convenience bridge, not even as a stretch goal.

**Rationale**: ArgumentParser is command *structure*. Console is terminal *interaction*.
Orthogonal concerns. Coupling would force an ArgumentParser dependency on all Console
users. The composition is trivial without any bridge (see example above). A convenience
bridge, if ever needed, belongs at Layer 4.

## Proposed Roadmap

### Phase 1: Terminal Input Foundation

**Scope**: `swift-terminal-primitives` (new module), `swift-ecma-48` (extended), `swift-iso-9945` (extended)

**Rationale**: Everything interactive (prompts, line editing, TUI) depends on being
able to read and parse terminal input. This is the critical missing primitive.

**Deliverables**:
1. `Terminal Input Primitives` module in `swift-terminal-primitives`:
   `Terminal.Input.Event`, `.Key`, `.Mouse`, `.Parser`
2. `ECMA_48.Parser` — VT state machine for escape sequence parsing
3. `Terminal.Input.Parser` composes ECMA-48 parser into typed events
4. SIGWINCH handling extension in `swift-iso-9945`

### Phase 2: Event Loop + Prompts

**Scope**: `swift-console` (two new modules: `Console Events`, `Console Prompts`)

**Rationale**: The event loop unlocks interactivity. Prompts are the highest-value
interactive component for CLI tools. Because the event loop composes existing
`IO.Event.Selector` + `Async.Stream` + `Async.Channel`, this phase is primarily
coordination glue — not infrastructure creation.

**Deliverables**:
1. `Console Events` module: `Console.Events.Source` (internal, composes IO.Event.Selector +
   parser + Async.Channel), `Console.Events.Stream` (wraps `Async.Stream`),
   `Console.Events.Poll` (wraps `IO.Event.Driver`), `Console.Events.Configuration`
2. `Console Prompts` module: `Console.Prompt.Confirm`, `.Input`, `.Password`,
   `.Select`, `.MultiSelect`

### Phase 3: Progress + Layout

**Scope**: `swift-console` (two new modules: `Console Progress`, `Console Layout`)

**Rationale**: These are independent of the event loop (output-only) and can be built
in parallel with or after Phase 2. High value for CLI tools that process data. Progress
rendering uses `Rendering.Async.Sink.Buffered` for backpressured output and
`Async.Stream` operators for timer ticks.

**Deliverables**:
1. `Console Progress` module: `Console.Progress.Bar`, `.Spinner`, `.Multi`, `.Template`
2. `Console Layout` module: `Console.Layout.Table`, `.Grid`, `.Columns`, `.Wrap`

### Phase 4: Line Editing (stretch)

**Scope**: `swift-console` (new module: `Console Line`)

**Rationale**: Requires mature event handling. Needed for REPL-style tools but not
for most CLIs.

**Deliverables**:
1. `Console Line` module: `Console.Line.Editor`, `.History`, `.Completion`

### Phase 5: TUI Framework (future, separate package, Layer 4)

Out of scope for this architecture. Mentioned for completeness. Would consume
`Console Events` as its backend.

## Constraints

1. **No Foundation** — All primitives and standards packages must remain Foundation-free
   per [PRIM-FOUND-001]. Foundation is discouraged but not forbidden at Layer 3.
2. **Nest.Name convention** — All new types must follow [API-NAME-001]
3. **Typed throws** — All throwing functions per [API-ERR-001]
4. **One type per file** — Per [API-IMPL-005]
5. **~Copyable where appropriate** — Event parser state, raw mode tokens
6. **Sendable** — All types must be Sendable; event stream must be safe for structured
   concurrency; `Console.Progress.Multi` must be thread-safe
7. **Platform abstraction** — Types defined in primitives, implementations in standards
   (ISO 9945 for POSIX, Windows primitives for Windows)

## Outcome

**Status**: DECISION

**Decision**: Multi-module architecture within existing packages, composing production-grade
infrastructure rather than building custom machinery.

**Core architectural principle**: The ecosystem already has every building block — event-driven
I/O (`IO.Event.Selector`), async streams with full operator sets (`Async.Stream`), sync-to-async
bridges (`Async.Channel`), parser combinators (`Parser.Protocol`), defunctionalized state machines
(`Parser.Machine`), and backpressured rendering (`Rendering.Async.Sink`). The console library's
role is to compose these with terminal-specific types and coordination glue. No custom kqueue/epoll,
no custom async bridging, no hand-rolled parsers.

**What is new** (the actual gaps to fill):
1. `Terminal.Input.Event/Key/Mouse` — type definitions (L1)
2. `Terminal.Input.Parser` — composed from `Parser.Protocol` combinators (L1)
3. `ECMA_48.Parser` — VT state machine via `Parser.Machine` (L2)
4. `Console.Events.Source` — registers fd with `IO.Event.Selector`, bridges to `Async.Channel` (L3)
5. `Console.Events.Stream` — wraps `Async.Stream<Terminal.Input.Event>` (L3)
6. `Console.Events.Poll` — wraps `IO.Event.Driver._poll` (L3)
7. `Console.Prompt.*` — interactive prompts built on Console Events (L3)
8. `Console.Progress.*` — progress bars/spinners using `Rendering.Async.Sink` (L3)
9. `Console.Layout.*` — structured text output (L3)

**Summary of design decisions**:
- Terminal input types and parser → new module in `swift-terminal-primitives` (builds on Parser Primitives)
- Console events → new module in `swift-console` (builds on IO.Event.Selector + Async.Stream)
- Console prompts, progress, layout, line editing → new modules in `swift-console`
- Mouse: SGR 1006, three configurable tracking modes, opt-in disabled by default
- Bracketed paste: opt-in (default-on in line editor for security)
- Kitty keyboard: unified Key type with optional fields, progressive enhancement, legacy default
- Event API: async primary (Async.Stream) + sync poll convenience (IO.Event.Driver)
- ArgumentParser: fully independent, zero coupling

**Comparison with crossterm** (the best-in-class reference):

| Aspect | crossterm | Our Design |
|--------|-----------|-----------|
| Event polling | Custom mio wrapper | Reuses `IO.Event.Selector` (proven, audited) |
| Async bridge | Custom background thread + AtomicBool + Waker | `Async.Channel.Bounded` → `Async.Stream` (zero custom code) |
| Parser | Hand-rolled state machine | `Parser.Protocol` + combinators (compositional, testable) |
| Escape timeout | Implicit in mio poll timeout | `IO.Event.Selector` deadline scheduling (generation counters) |
| Resize coalescing | Manual in event reader | `Async.Stream.debounce` (one line) |
| Mouse throttling | Not supported | `Async.Stream.throttle` (one line) |
| Backpressure | VecDeque capacity 32 | `Async.Channel.Bounded` (configurable) |
| Thread safety | parking_lot::Mutex | Actor isolation (compile-time verified) |
| Typestate | None | `IO.Event.Token<Phase>` (compile-time API safety) |

Next steps:
- Begin Phase 1: `Terminal Input Primitives` module in `swift-terminal-primitives`
- Add `ECMA_48.Parser` to `swift-ecma-48`
- Add SIGWINCH handling to `swift-iso-9945`

## References

- ECMA-48: Control Functions for Coded Character Sets (5th edition, June 1991)
- Paul Williams' VT parser state machine: https://vt100.net/emu/dec_ansi_parser
- Rust crossterm: https://github.com/crossterm-rs/crossterm
- Rust console-rs family: https://github.com/console-rs
- Rust ratatui: https://github.com/ratatui/ratatui
- Kitty keyboard protocol: https://sw.kovidgoyal.net/kitty/keyboard-protocol/
- NO_COLOR standard: https://no-color.org
- CLICOLOR spec: https://bixense.com/clicolors/
- Apple Swift ArgumentParser: https://github.com/apple/swift-argument-parser
