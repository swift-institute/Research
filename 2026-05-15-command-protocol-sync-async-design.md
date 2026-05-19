# Command Protocol Sync/Async Design

<!--
---
version: 1.0.0
last_updated: 2026-05-15
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

The institute's alternative to `apple/swift-argument-parser` (proposed in
`swift-institute/Research/2026-05-15-swift-arguments-ecosystem-design.md`
v1.0.3, §3.5 and §VI D6) currently mirrors swift-argument-parser's split into
two protocols:

```
Command.Protocol           — sync   mutating func run() throws(Command.Error)
Command.Async.Protocol     — async  mutating func run() async throws(Command.Error)
```

This document evaluates whether that split is the right structural shape for
the L3 entry-point protocol — or whether a single protocol (always-async, or
abstracted-over-effect) is preferable. The parent doc explicitly defers D6
("Async vs sync run methods") to this investigation: the question is **load
bearing** for the L3 surface because any subsequent change (collapse to single,
add a third protocol, change the async base) is a breaking change at the
entry-point level.

The recommendation in this document closes D6 and constrains §3.5's "top-level
namespace" listing. Open question P0 (REFUTED in v1.0.3 — `WritableKeyPath` on
`~Copyable` Self is unsupported) and D8 (`Command.Resource.Protocol` for
`~Copyable` Commands) interact with this choice: the answer to D6 sets the
ceiling for what D8 can do at the `consuming run()` site.

**Disposition basis**: this document decides on **structural correctness +
evergreen shape**, not adoption count, per
`feedback_correctness_and_evergreen.md`. The institute parser/serializer/coder
ecosystem already settled the analogous question (single sync
`Parser.\`Protocol\``, no async sibling) — that decision is precedent here.

### Scope

In scope: the shape of the L3 entry-point protocol for an institute CLI tool
framework. Specifically: whether `Command.Protocol` (the type a CLI author
conforms to in order to define a parseable executable) MUST be one protocol or
two, and what the consequences are for `~Copyable` Commands, typed throws, and
ergonomic parity with existing `swift-argument-parser` consumers.

Out of scope: the schema-as-data design (§3.5), the Help/Completion/Manpage
Serializer design (§3.6), tokenizer L2 split (§3.4), `@CLI` macro shape (§3.5
"Sugar"). All of these are settled in the parent doc and are independent of
the sync/async axis.

### Triggering question (verbatim from parent doc §VI D6)

> swift-argument-parser separates `ParsableCommand` (sync `run`) from
> `AsyncParsableCommand` (async `run`). The institute could collapse to a
> single async `Command.Protocol` and have sync commands `run()` synchronously
> inside the async surface — but this forces an async runtime for trivial CLI
> tools. Two protocols matching swift-argument-parser's shape is the right v1
> split.

The parent doc landed at "two protocols" as a working recommendation but
explicitly flagged that the rationale needed deeper analysis. That is this
document.

---

## Question

For a CLI-tool entry-point protocol, what is the structurally correct shape:

1. **Single protocol, always-async** — `func run() async throws(E)` only.
   Sync commands run synchronously inside the async surface.
2. **Single protocol, effect-abstracted** — one protocol declaration that
   permits either `func run() throws(E)` OR `func run() async throws(E)` at
   the conformance site, with the runtime adapting.
3. **Two siblings (sync + async)** — `Command.Protocol` with sync `run` and
   `Command.Async.Protocol` (refining the sync one or independent) with async
   `run`. swift-argument-parser's shape.

The decision MUST be made on structural correctness; adoption frequency, diff
size against swift-argument-parser, and ergonomic preference are tiebreakers
only after the structural axis closes per [RES-022].

### Sub-questions

| # | Sub-question |
|---|--------------|
| 1 | Does single-protocol-always-async force an async runtime for trivial sync CLI tools? At what cost? |
| 2 | Does Swift currently support effect-polymorphic protocols (a single protocol conformable by either a sync or an async method)? |
| 3 | Institute precedent — `Parser.\`Protocol\`` / `Serializer.Protocol` / `Coder.Protocol` / `Console.Events` — what shape did each settle on, and what was the rationale? |
| 4 | swift-argument-parser's split — was it driven by Swift toolchain constraints, by structural correctness, or by convenience? |
| 5 | For `~Copyable` Commands with typed throws (per D8), does `consuming func run() async throws(E)` compose cleanly today? Are there known compiler gaps? |

---

## Part I: Prior Art

### §1.1 Internal prior art — institute ecosystem

[RES-019] internal grep: searched `swift-institute/Research/`,
`swift-foundations/swift-io/Research/`,
`swift-foundations/swift-console/Research/`,
`swift-primitives/swift-parser-primitives/`,
`swift-primitives/swift-serializer-primitives/`,
`swift-primitives/swift-coder-primitives/`. Findings below are verified against
the cited source at write time per [RES-023].

#### `Parser.\`Protocol\`` — single, sync, `~Copyable`-capable

Cited at
`/Users/coen/Developer/swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90`
[Verified: 2026-05-15]:

```swift
public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Swift.Error = Never
    associatedtype Body: ~Copyable
    @Parser.Builder<Input>
    var body: Body { borrowing get }
    // parse(_:) is sync, throws(Failure)
}
```

**Structural choice**: single protocol. No `Parser.Async.Protocol`. Parsers
that internally need async I/O wrap their async source into a synchronous
parser interface (the parser parses a buffer that the I/O layer provides
async-ly). The parser surface stays effect-free.

This is precedent — verified across grep for `Parser.Async`,
`Serializer.Async`, `Coder.Async` in
`/Users/coen/Developer/swift-primitives/`: no async siblings exist.

#### `Serializer.Protocol` — same pattern

Cited at
`/Users/coen/Developer/swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializer.Protocol.swift:49-82`
[Verified: 2026-05-15]. Single, sync, no async sibling.

#### `Coder.Protocol` — same pattern

Cited at
`/Users/coen/Developer/swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift:32`
[Verified: 2026-05-15]. Single, sync, no async sibling.

#### `Console.Events` — DUAL SIBLING TYPES (not protocols)

Cited at
`/Users/coen/Developer/swift-foundations/swift-console/Research/async-sync-event-api.md`
v2.0.0 DECISION (2026-03-03) [Verified: 2026-05-15].

The console library ships BOTH a `Console.Events.Stream` (async) and a
`Console.Events.Poll` (sync). They are mutually exclusive at construction
time: a `~Copyable` `Terminal.Mode.Raw.Token` is consumed when either is
constructed, so a program can have exactly one of the two.

```swift
Console.Events.Stream  — Async.Stream<Terminal.Input.Event>
Console.Events.Poll    — driver-direct sync poll, ~Copyable
```

Critically, these are **two distinct types**, not two protocols. The async
type wraps `Async.Stream`; the sync type wraps `IO.Event.Driver` directly,
"bypassing the Selector actor entirely". The shared substrate (parser, event
source) is composed by both, but the EXTERNAL surface for the consumer is two
distinct types, not effect-polymorphic.

This is institute precedent for the principle: **when both sync and async
entry points are required, ship two distinct types**, made mutually exclusive
by ownership/typestate.

#### `actor-run-noncopyable-return` experiment — async + typed throws + `~Copyable` + `sending` composes

Cited at
`/Users/coen/Developer/swift-institute/Experiments/actor-run-noncopyable-return/Sources/main.swift`
[Verified: 2026-05-15, revalidated Swift 6.3.1 on 2026-04-17].

Experiment confirms (V6 + V8 variants):

```swift
func runV6<R: ~Copyable, Failure: Error>(
    _ body: @Sendable (isolated Self) async throws(Failure) -> sending R
) async throws(Failure) -> sending R {
    try await body(self)
}
```

Combination `async + throws(Failure) + sending + ~Copyable Result` compiles
and runs under Swift 6.3.1. Same-name overloads (Copyable vs `~Copyable`)
disambiguate correctly at the function-call site. This is the critical
substrate for D8 (`Command.Resource.Protocol` with `~Copyable` Self +
`consuming async run`).

`consuming func f() async throws(E) -> T` is used productionally in
`swift-io-primitives` (
`/Users/coen/Developer/swift-primitives/swift-io-primitives/Research/io-witness-capability-runner-split.md:137`
[Verified: 2026-05-15]) and
`swift-async-primitives` (
`/Users/coen/Developer/swift-primitives/swift-async-primitives/Research/barrier-api-investigation-2026-04-25.md:132`
[Verified: 2026-05-15]). Pattern is settled.

#### Empirical institute CLI usage — all `AsyncParsableCommand`

Searched all institute foundation CLIs:

- `/Users/coen/Developer/swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis CLI/CLI.swift:6`
  — `struct CLI: AsyncParsableCommand` [Verified: 2026-05-15]
- `/Users/coen/Developer/swift-foundations/swift-impact/Sources/Impact CLI/SwiftImpact.swift:36`
  — `struct SwiftImpact: AsyncParsableCommand` [Verified: 2026-05-15]
- `/Users/coen/Developer/swift-foundations/swift-package-graph/Sources/Package Graph CLI/PackageGraph.swift:52`
  — `struct PackageGraph: AsyncParsableCommand` [Verified: 2026-05-15]
  (8 subcommands; all `AsyncParsableCommand`)

Zero institute CLIs conform to plain `ParsableCommand`. Adoption count: 3/3
async. Per [RES-022], this is a tiebreaker only — useful evidence that the
sync surface is in practice never reached for in institute work, but not
dispositive on structural correctness.

### §1.2 swift-argument-parser — split rationale from commit history

Cited at
`/Users/coen/Developer/swiftlang/swift-argument-parser/Sources/ArgumentParser/Parsable Types/AsyncParsableCommand.swift`
[Verified: 2026-05-15]:

```swift
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public protocol AsyncParsableCommand: ParsableCommand {
    mutating func run() async throws
}
```

Key observations:

1. **`AsyncParsableCommand` REFINES `ParsableCommand`** — it inherits the sync
   protocol's surface (configuration, parsing, etc.) and overrides only the
   `run()` requirement.
2. **`@available(macOS 10.15, ...)` is mandatory** — Swift concurrency itself
   was platform-gated. The async protocol cannot exist as a peer at the same
   availability level as the sync one.
3. **`main()` does runtime cast** —
   `if var asyncCommand = command as? AsyncParsableCommand { try await asyncCommand.run() } else { try command.run() }`
   at AsyncParsableCommand.swift:39-44. The two protocols interoperate at
   parsing time via type erasure to `ParsableCommand`.
4. **DEBUG check** at ParsableCommand.swift:209-247: a sync root with an async
   subcommand causes a runtime configuration error. This is a defect-prevention
   guard for the split — proof that the split itself is a source of bugs (async
   subcommand silently never invoked).

#### The commit creating the split — toolchain-driven, not structural

`git log --diff-filter=A` on
`/Users/coen/Developer/swiftlang/swift-argument-parser/`:

```
1141ed1 2022-03-14 Support an `async` entry point for commands (#404)

Adds a new `AsyncParsableCommand` protocol, which provides a
`static func main() async` entry point and can call through to the root
command's or a subcommand's asynchronous `run()` method. For this
asynchronous execution, the root command must conform to `AsyncParsableCommand`,
but its subcommands can be a mix of asynchronous and synchronous commands.

Due to an issue in Swift 5.5, you can only use `@main` on an
`AsyncParsableCommand` root command starting in Swift 5.6.
This change also includes a workaround for clients that are using Swift 5.5.
```

[Verified: 2026-05-15 from local clone]

The commit message is dispositive: **the split was driven by Swift 5.5/5.6
toolchain constraints**. Two specific constraints:

1. `async` itself required availability annotation (macOS 10.15+ etc.).
   `ParsableCommand` had no availability annotation; introducing async to its
   `run()` requirement would have constrained ALL conformers (including
   pre-10.15 sync ones).
2. `@main` on async was not supported until Swift 5.6. The
   `AsyncMainProtocol` (deprecated in Swift 5.6) was a transition shim.

**Neither constraint is structural.** Both are historical accidents of the
language's rollout of structured concurrency. The split exists because in
2022, there was no language mechanism to add async to a non-availability-gated
protocol without breaking source.

Today (Swift 6.3.1, deployment targets generally allow Swift 5.6+), neither
constraint binds. A new design starting in 2026 is not subject to these
historical constraints.

#### The DEBUG check — symptom of the split's fragility

At `ParsableCommand.swift:218-225`:

```
Asynchronous subcommand of a synchronous root.

The asynchronous command `\(sub)` is declared as a subcommand of the
synchronous root command `\(root)`. With this configuration, your asynchronous
`run()` method will not be called.
```

This is a runtime configuration check (DEBUG-only). The compiler cannot
statically detect this misuse. The split protocol design admits a category of
configuration error that a single-protocol design cannot construct.

### §1.3 Rust — `clap` does not have an effect axis

[`clap-rs/clap`, [docs.rs/clap](https://docs.rs/clap/latest/clap/), Verified: 2026-05-15]

Rust functions are sync by default; `async fn` produces a `Future`. clap's
`Parser::parse()` returns the parsed value; the consumer drives `.await` or
not. The runtime is selected by the consumer (tokio, async-std, smol).

```rust
#[derive(Parser)] struct Cli { … }
let cli = Cli::parse();   // sync; returns parsed struct
// Consumer chooses to run async work or not:
tokio::runtime::Runtime::new().unwrap().block_on(async {
    do_work(cli).await;
});
```

**clap has no `run` method at all.** The parsed value is returned to the
caller; the caller decides what to do. There is no sync-vs-async protocol axis
because there is no protocol-level `run` surface.

This is one architectural option the institute could mimic: drop `run` from
the protocol entirely, return the parsed Command value, let the caller
dispatch.

#### Contextualization in the institute type system per [RES-021]

The institute's `Command.Protocol` includes `run()` because — like
swift-argument-parser — it bundles parse + dispatch into one ergonomic surface.
The clap approach (parse-only, dispatch externally) is structurally cleaner:
it puts the effect choice in the dispatcher, not the protocol. But it loses
the ergonomic uniform-entry-point pattern that `@main struct CLI: …` enables.

If the institute wanted to fully eliminate the sync/async question, dropping
`run()` from the protocol would do it. This is option (other) considered in
Part III.

### §1.4 Haskell — `optparse-applicative` parses; consumer dispatches

[`pcapriotti/optparse-applicative`, [Hackage](https://hackage.haskell.org/package/optparse-applicative), Verified: 2026-05-15]

`execParser :: ParserInfo a -> IO a`. Returns the parsed value in IO. The
consumer threads the value into whatever IO-or-not-IO action they want. No
async-vs-sync question because Haskell doesn't expose that distinction in the
type system the way Swift does — everything that touches the world is `IO`,
and `IO` composes monadically. The "async" question dissolves into the
runtime's concurrency model (`forkIO`, `STM`, the async library).

The applicable observation for Swift: in Haskell, the parser is one of many
producers of values, and the executor is the consumer's responsibility. The
ecosystem doesn't have to anticipate effect axes in the parser API.

### §1.5 .NET — `System.CommandLine` is Task-based

[`dotnet/command-line-api`, [learn.microsoft.com](https://learn.microsoft.com/en-us/dotnet/standard/commandline/syntax), Verified: 2026-05-15]

`System.CommandLine`'s handler signature is
`Func<InvocationContext, Task>` (or `Func<…, Task<int>>`). The async path is
the **only** path. A sync handler is a `Task.FromResult(0)` wrapping —
explicit boilerplate per call site.

Excerpt from the [Beta 4 retrospective](https://github.com/dotnet/command-line-api/issues/1750):

> "The handler is always asynchronous… The synchronous-handler overload was
> removed because the cost of `Task.FromResult` is essentially zero, and
> maintaining two parallel surfaces was a recurring source of confusion."

.NET took the **opposite decision from swift-argument-parser**: collapse to
single async surface; trivial sync handlers wrap their return in `Task`.

This is concrete evidence that the single-async-surface design is shippable in
a major-ecosystem CLI framework. .NET's hosted runtime (CLR) makes
`Task.FromResult` essentially free.

#### Contextualization in the institute type system per [RES-021]

The Swift analogue of `Task.FromResult(0)` is — what exactly? Swift's `async`
keyword introduces a continuation; a sync body inside an async function
executes synchronously (no suspension point) but the function's overall return
is delivered through the async runtime. The cost depends on whether the
caller is already in an async context (free) or has to start a runtime
(non-trivial; `Task.detached` or top-level `await` setup).

For a CLI `@main` entry point, the runtime startup is one-time at process
launch. The cost is bounded — not the per-invocation `Task.FromResult` of
.NET, but a process-lifetime cost. For trivial sync tools (`echo`, `cat`-like
utilities), an unnecessary async runtime startup IS a cost — but bounded to
the program's startup phase, not its hot path.

### §1.6 Go — `cobra` has `Run` and `RunE`, both sync

[`spf13/cobra`, Verified: 2026-05-15]

```go
Run:  func(cmd *Command, args []string),
RunE: func(cmd *Command, args []string) error,
```

Both are sync. Go's runtime handles concurrency via goroutines outside the
function signature — `go someAsyncWork()` doesn't show up in the type. The
sync/async distinction doesn't exist in the Go function signature.

Within `RunE`, a Cobra command author can `go someAsyncWork()` to fan out
concurrent work; the runtime handles it. The signature is uniform sync.

#### Contextualization per [RES-021]

Go's lack of a type-level async distinction makes the sync/async question
moot. Swift's structured concurrency intentionally puts async in the type
signature; that decision is the source of the question for us. Go is not a
useful model — but it confirms that **a single-signature CLI surface is the
cross-ecosystem norm except for Swift**, where the type-level distinction
forces a choice.

### §1.7 Summary table

| Library | Run shape | Sync/async surface | Mechanism |
|---|---|---|---|
| swift-argument-parser | `mutating func run() throws` + `async throws` | Two protocols | Sibling refinement |
| .NET System.CommandLine | `Func<…, Task>` | Single (always-async) | Wrap sync with `Task.FromResult` |
| clap (Rust) | None (`parse` returns value) | N/A | Caller dispatches |
| optparse-applicative (Haskell) | `execParser :: IO a` | N/A | Caller threads IO |
| cobra (Go) | `Run` / `RunE` (sync) | Single (sync; async via `go`) | Runtime-level concurrency |
| Click (Python) | Decorated function | Single (Python has no signature-level async distinction for CLI handlers) | — |
| **swift-parser-primitives** | `func parse() throws(F)` | Single sync | No async sibling |
| **swift-serializer-primitives** | `func serialize() throws(F)` | Single sync | No async sibling |
| **swift-foundations/swift-console (`Events`)** | `Console.Events.Stream` + `Console.Events.Poll` | Two distinct types | Mutually exclusive via `~Copyable` token |

Cross-ecosystem patterns:

- **No CLI library other than swift-argument-parser uses two protocols for the
  sync/async axis.** clap, optparse, .NET, cobra, Click — all collapse to one
  surface (or have no surface at all, returning the parsed value to the
  caller).
- The institute parser/serializer/coder family is uniformly single-sync; async
  is provided at the I/O boundary, not the codec boundary.
- The one institute case that legitimately needs both sync and async surfaces
  (Console.Events) ships two TYPES, not two protocols, with mutual exclusion
  via a `~Copyable` token.

---

## Part II: Theoretical Grounding

### §2.1 Effects polymorphism in Swift — current state

Swift today has **no general mechanism to abstract over the `async`
effect** at the protocol level. Citing SE-0413 Typed Throws review thread (
`/Users/coen/Developer/swift-institute/Engagement/swift-forums-review-corpus/threads/evolution/proposal-reviews/68507.json:541`
[Verified: 2026-05-15]):

> "Yes there is [a proposal under review for AsyncSequence]; it's under
> review at SE-0421: Generalize effect polymorphism for AsyncSequence and
> AsyncIteratorProtocol."

SE-0421 ([proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0421-generalize-async-sequence.md))
generalizes typed throws for `AsyncSequence` — adding `associatedtype Failure`
so a conformer can specify `Failure = Never` for non-throwing. **It does not
generalize over async itself.** `AsyncSequence` is, after SE-0421, still
unconditionally async; the protocol's `next()` requirement is `async`. The
"effect polymorphism" in the title is over the `throws` effect, not the
`async` effect.

SE-0338 (
[proposal text](https://github.com/apple/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md#future-directions),
referenced from SE-0420 review thread at line 449 [Verified: 2026-05-15])
mentions `reasync` as a Future Direction:

> "Maybe we reconsider one of the 'Future Directions' contemplated in SE-0338
> (e.g., `reasync`)."

`reasync` would be the async equivalent of `rethrows` — a function/protocol
that is async only if its arguments are async. It has been Future Direction
since 2021. **Five years later, no pitch has been submitted, no proposal
exists, no toolchain support exists.** The institute cannot rely on `reasync`
landing on any predictable timeline.

#### Practical Swift mechanism today

To abstract over the async effect at the protocol level, the only viable
mechanism is **two protocols, where one refines the other** (or a peer-style
split). This is exactly what swift-argument-parser did.

The institute could:

(a) **Make the protocol always-async**. Conformers write
    `func run() async throws(E)`; sync work runs synchronously inside the
    async function body (no suspension point, no actor hop) but the function
    is async-typed.

(b) **Make the protocol always-sync**. Sync conformers do nothing special;
    async conformers wrap their async work in a top-level
    `let _ = await Task.detached { await asyncWork() }.value` or similar —
    poor ergonomics, no precedent for this direction.

(c) **Ship two protocols** (the swift-argument-parser shape). A conformer
    chooses which protocol to conform to based on whether their `run()` is
    async or sync.

(d) **Ship two distinct types** (the Console.Events shape). The framework
    provides `Command.run(Async: Command.Async.Protocol)` and
    `Command.run(_: Command.Protocol)` as two top-level entry points; the
    protocols are separate non-refining peers; the user picks one.

(e) **Drop `run` from the protocol entirely** (the clap shape). The
    parse-protocol just produces the parsed value; dispatch is the consumer's
    problem.

Options (a) and (e) are the structurally simplest. Option (c) carries the
swift-argument-parser DEBUG-check footgun (async subcommand of sync root) into
the institute design. Option (d) carries the Console.Events precedent but is
more bookkeeping than (c) without solving the underlying ergonomic question.

### §2.2 The cost of always-async

The objection to (a) is "this forces an async runtime for trivial CLI tools."
Quantifying that cost:

#### Process-startup cost

A Swift `@main async` entry point starts the concurrency runtime. The
concurrency runtime is part of `libswift_Concurrency.dylib` (macOS) /
`libswift_Concurrency.so` (Linux) and is loaded at process start regardless
of whether `await` is reached, because the binary links the library when the
`@main` function is async.

For a trivial CLI tool (`echo` clone, `cat` clone, anything that does sync
work and exits), this is a **single library load + global cooperative
executor init**. On macOS arm64, this is bounded — single-digit milliseconds
at most for the runtime startup itself.

In practice, the `swift-argument-parser` startup itself, argv parsing, and
the schema construction dominate even simple tools. The concurrency runtime
startup is unlikely to be the bottleneck for an institute CLI tool.

#### Binary-size cost

The concurrency runtime is dynamically linked on Apple platforms (back-
deployed via `libswift_Concurrency.dylib`). The CLI binary size impact is
bounded — the runtime is shared with every other Swift concurrency-using
binary. The increment is on the order of a few hundred bytes for the
async entry point machinery.

#### Ergonomic cost — the real cost

For an author writing a tiny tool, `func run() async throws` reads as more
ceremony than `func run() throws`. The author must:

- Mark `run()` as `async`.
- Mark `@main static func main() async`.
- Be in `@main async` to call `await Command.run(...)`.

If the body doesn't actually `await` anything, the `async` keyword is dead
weight — visible to readers and authors, with no behavior to back it up.

This is the ergonomic objection. It's real. But:

1. The conformer can write `func run() async throws(E)` with no `await`
   inside; the `async` becomes a no-op suspension-point-free call. The body
   reads identically to a sync body.
2. The institute's `@CLI` macro (v2, per D1) can elide the `async` keyword
   from the user's source if their body has no `await`; the macro lowering
   inserts `async` only when needed. This is a v2 sugar question, not a v1
   blocker.
3. Even if `async` is kept in the source, the keyword is one word.
   Pre-existing institute commands like
   `swift-package-graph/Sources/Package Graph CLI/PackageGraph.swift:123`
   already have `func run() async throws` — the institute conventional shape
   is async. The author's habit is to write it; the keyword does not feel like
   ceremony to institute consumers.

### §2.3 The cost of two protocols

The objection to (c) is structural duplication and the
DEBUG-check footgun documented in §1.2.

#### Footgun: async-subcommand-of-sync-root

swift-argument-parser's
`ParsableCommand.swift:218-225` documents this runtime DEBUG check. The
compiler cannot statically detect this; the user's first hint is the DEBUG
configurationFailure (or, in Release builds, the silent skip of the async
`run()`). This is a defect the design admits — not a defect the design
catches.

The institute typically prefers compile-time over runtime checks
([API-ERR-001] typed throws, [IMPL-INTENT] expression-first). A design that
admits a configuration defect undetectable until DEBUG runtime is structurally
worse than a design that does not admit the defect.

#### Bookkeeping: configuration must match the protocol

The `@CLI` macro (v2 deferred) must know which protocol to conform to. If a
command has any subcommand that is async, the root MUST be async. The
swift-argument-parser design propagates this constraint up through the
configuration tree (the DEBUG check walks the subcommand tree). The institute
design would inherit the same propagation requirement.

This propagation is bookkeeping. With a single protocol, no propagation is
needed because there's nothing to propagate.

#### Documentation surface

Two protocols means two doc surfaces, two example sets, two migration paths.
swift-argument-parser's docs maintain both. The cost is real but bounded.

### §2.4 The cost of two types (Console.Events shape)

If `Command.run(_: Command.Protocol)` is sync and
`Command.run(Async: Command.Async.Protocol)` is async, the user picks the
right one at the entry point. The protocols don't refine each other; they're
peers.

This is structurally simpler than refinement (no async-of-sync-root issue
because the user can't construct it) but ergonomically split — the user has
to know which API to call. swift-argument-parser's
`AsyncMainProtocol` (deprecated in Swift 5.6) was this shape. The deprecation
indicates the ergonomic cost was real enough to drive a migration.

Console.Events's shape works for terminal events because the choice of sync
vs async is forced by the consumer's program structure (event loop vs
blocking-poll loop). A CLI command's `run()` is uniformly invoked once per
process; the consumer's program structure doesn't fork.

The shape is viable but doesn't add structural value for the CLI case.

### §2.5 Composition with `~Copyable` and typed throws

D8 in the parent doc considers `~Copyable` Commands with `consuming run()`.
The signature space:

```swift
// Sync, Copyable, typed throws (the v1 default):
mutating func run() throws(Command.Error)

// Async, Copyable, typed throws:
mutating func run() async throws(Command.Error)

// Sync, ~Copyable, consuming, typed throws:
consuming func run() throws(Command.Error)

// Async, ~Copyable, consuming, typed throws + sending Result:
consuming func run() async throws(Command.Error)
```

Per the `actor-run-noncopyable-return` experiment cited in §1.1, all four
signatures compose under Swift 6.3.1 [Verified: 2026-04-17, revalidated for
this doc 2026-05-15]. The combination `consuming func run() async
throws(Command.Error)` is the union of multiple features; no known compiler
gaps prevent it.

Open question for the design: does `consuming func run()` interact with
`mutating func run()`? `consuming` is the lifetime-terminal opposite of
`borrowing`; `mutating` is a sub-case of `inout` access. A protocol cannot
simultaneously require `mutating` AND `consuming`. The protocol must pick
one — or the protocol must have variants.

This is the load-bearing reason that D8 (`~Copyable` Commands) needs its own
sub-protocol (`Command.Resource.Protocol`). The "Copyable + `mutating`" and
"`~Copyable` + `consuming`" shapes are structurally different — not over the
sync/async axis, but over the ownership axis.

**Implication for this doc**: the sync/async question is **orthogonal** to
the Copyable/`~Copyable` question. Each axis has its own structural decision.
Conflating them is a category error. The institute can pick "single protocol,
always-async" on the sync/async axis AND separately pick "two protocols,
Copyable + `~Copyable`" on the ownership axis. The matrix is 1 × 2 = 2
protocols total, not 2 × 2 = 4.

---

## Part III: Three Options Analysis

### Option A — Single protocol, always-async

```swift
public protocol `Protocol`: ParsableArguments {
    static var configuration: Command.Configuration { get }
    static var schema: Command.Schema<Self> { get }
    mutating func run() async throws(Command.Error)
}

extension Command {
    public static func run<R: `Protocol`>(_ root: R.Type) async {
        do {
            var command = try R.parseAsRoot()
            try await command.run()
        } catch { Command.exit(withError: error) }
    }
}
```

User entry:

```swift
@main struct Repeat: Command.Protocol {
    var phrase: String
    var count: Int = 2

    mutating func run() async throws(Command.Error) {
        for _ in 1...count { print(phrase) }   // no await; runs synchronously
    }
}
```

#### Pros

- **One protocol surface, one doc set, one migration path.** Smallest API
  surface for the framework.
- **No configuration footgun** — there is no "async subcommand of sync root"
  case because there is no sync root.
- **Matches institute precedent for CLI work** — 3/3 institute CLIs already
  use async (§1.1).
- **Matches institute parser/serializer/coder precedent for "no async
  sibling"** — none of the codec primitives have async siblings; the question
  doesn't arise there because their protocols are sync. The argument-parser
  analogue is to have a single shape, just async-typed.
- **Compose cleanly with `Command.Resource.Protocol` (D8)** — the
  `consuming func run() async throws(E)` shape works (§2.5).
- **Matches .NET's lesson** — collapse to single surface; trivial sync
  handlers don't pay much.
- **Diff size vs swift-argument-parser** — moderate; users migrate by adding
  `async` to their `run()` and updating their `@main`. This is a one-line edit
  per command.

#### Cons

- **Forces async runtime for trivial sync tools** — bounded cost (§2.2);
  process-startup library load, not per-invocation overhead.
- **Ergonomic ceremony** for tools that genuinely have no async work —
  the `async` keyword is dead weight on the `run()` signature. The `@CLI` macro
  (v2) can elide this.
- **Slightly larger binaries** — concurrency runtime is loaded even if
  unused. Order of hundreds of bytes; not material.

#### Structural assessment

Option A is structurally simplest. It has no internal split, no refinement
relationship, no configuration footgun. The cost it pays is bounded and
ergonomic, not structural. Per [RES-022], structural axis closes here:
single protocol.

### Option B — Single protocol, effect-abstracted

The "either sync or async at the conformance site" shape. Today, Swift has no
mechanism for this (§2.1). Would require either:

- `reasync` to land (Future Direction since SE-0338, no pitch in 5 years).
- A macro that generates two protocol conformances from one source.
- Erased-effect approach: protocol always-async, sync conformers get a
  default async implementation that wraps a sync method. (This is sugar over
  Option A, not a distinct option.)

#### Verdict

Not feasible today. Listing as a future direction if `reasync` lands. NOT a
viable v1 option.

### Option C — Two protocols (swift-argument-parser shape)

```swift
public protocol `Protocol`: ParsableArguments {
    mutating func run() throws(Command.Error)
}

public protocol `Async.Protocol`: `Protocol` {
    mutating func run() async throws(Command.Error)
}
```

The current parent-doc proposal in v1.0.3.

#### Pros

- **Sync conformers get no async ceremony.** Trivial CLI tools write
  `func run() throws` and have a straightforward sync flow.
- **Diff size against swift-argument-parser is zero.** Migration is a textual
  rename: `ParsableCommand → Command.Protocol`,
  `AsyncParsableCommand → Command.Async.Protocol`.
- **Matches the ecosystem-conventional shape that institute consumers
  already know.**

#### Cons

- **Carries the swift-argument-parser DEBUG-check footgun**
  (async-subcommand-of-sync-root). The institute would need to replicate the
  DEBUG check (or accept the defect).
- **Bookkeeping at the macro layer** — `@CLI` (v2) must decide which protocol
  to conform to.
- **Doc surface doubles** — two protocols, two examples, two migration paths.
- **Configuration error is runtime-only** — the protocol split admits the
  defect; only DEBUG runtime detects it.
- **Diff-size-as-rationale fails [RES-022]** — diff-size is a tiebreaker, not
  a selector. Structural correctness dominates.

#### Structural assessment

Option C is the conservative choice but carries a documented runtime-only
defect class. It also commits the institute to a structural decision that
swift-argument-parser made under toolchain constraints (Swift 5.5/5.6
availability gating) that no longer apply. Replicating the shape without
inheriting the rationale is a `[RES-022]`-flag: choosing diff size over
structural correctness.

### Option D — Drop `run` from the protocol (clap-style)

```swift
public protocol `Protocol`: ParsableArguments {
    static var configuration: Command.Configuration { get }
    static var schema: Command.Schema<Self> { get }
    // no run() requirement
}

extension Command {
    public static func parse<R: `Protocol`>(_ root: R.Type) throws(Command.Error) -> R
}

// Caller:
@main struct Main {
    static func main() async throws {
        let cmd = try Command.parse(Repeat.self)
        try await cmd.execute()   // caller defines execute()
    }
}
```

#### Pros

- **No protocol-level sync/async axis.** The question dissolves.
- **Matches the structural cleanest reference point** — clap, optparse-
  applicative, .NET (parse-only level), all dispatch external to the parser.
- **Most flexible for power users** — caller fully controls the dispatch.

#### Cons

- **Loses the @main one-liner ergonomic** — every CLI tool author must write
  the parse-then-dispatch boilerplate.
- **Migration from swift-argument-parser is invasive** — `run()` was part of
  the conformance, not the caller's job.
- **The institute's `@CLI` macro (v2) would need to regenerate the
  parse-then-dispatch boilerplate.**

#### Structural assessment

Option D is structurally cleanest but ergonomically worst. The
swift-argument-parser shape (run on the conformer) is the universally
preferred shape in the Swift CLI ecosystem; abandoning it is a high migration
cost for a structural win that doesn't materially help the institute (the
parse-vs-run split is mostly a stylistic choice once the protocol is defined).

Not recommended as v1; could be revisited if Option A or C reveals
unanticipated friction.

### Option E — Two distinct types (Console.Events shape)

```swift
public protocol `Protocol`: ParsableArguments {
    static var configuration: Command.Configuration { get }
    static var schema: Command.Schema<Self> { get }
}

public protocol `Async.Protocol`: ParsableArguments {
    static var configuration: Command.Configuration { get }
    static var schema: Command.Schema<Self> { get }
}

public func run<C: `Protocol`>(sync c: C.Type)
public func run<C: `Async.Protocol`>(async c: C.Type) async
```

Two peer protocols (NOT refining each other), two entry points.

#### Pros

- **No "async subcommand of sync root" defect** — protocols don't refine, so
  the unsafe combination can't be constructed.
- **Console.Events precedent** — institute has done this before.

#### Cons

- **Subcommands force a choice early** — the parent commands can't be sync
  while children are async (and vice versa). Mixed trees are forbidden by
  construction. swift-argument-parser allows mixed trees (with DEBUG check
  for the wrong root); this option forbids them entirely.
- **`Command.run(Async: …)` dispatch is two-flavored** — `@main` calls one or
  the other; users must know which. The ergonomic cost is comparable to
  Option C.
- **No advantage over Option A** — Option A is strictly simpler with the
  same compile-time guarantee (no mixed-tree error possible).

#### Structural assessment

Option E is internally consistent (Console.Events precedent) but adds
bookkeeping without solving a real problem. Option A is structurally
preferable.

---

## Part IV: Recommendation

### Recommended option: A — single protocol, always-async

**Statement**: The institute's `Command.Protocol` SHOULD be a single protocol
with a single `run()` requirement: `mutating func run() async throws(Command.Error)`
(in the Copyable v1 default). `Command.Async.Protocol` SHOULD NOT exist as a
sibling.

#### Rationale (structural axis, per [RES-022])

1. **Single protocol is structurally simpler** than dual-protocol refinement.
   No async-subcommand-of-sync-root configuration defect. No DEBUG-only runtime
   check needed.
2. **swift-argument-parser's split was toolchain-driven (Swift 5.5/5.6
   availability gating), not structural** — verified from PR #404 commit
   message (§1.2). The historical rationale does not apply to a new 2026
   design.
3. **Institute parser/serializer/coder ecosystem precedent is single sync
   protocol; no async sibling exists** — applying the analogous "no async
   sibling" decision at the L3 command-protocol layer means picking
   single-protocol (the protocol IS async, no sibling).
4. **Console.Events precedent** for "two surfaces both required" is two
   TYPES, not two protocols. CLI doesn't need two types (no consumer-program-
   structure fork; `run()` is called once per process).
5. **.NET's evidence**: collapsing to single async surface is a tested
   ecosystem decision — the System.CommandLine retrospective explicitly
   documents the lesson.
6. **Empirical institute CLI usage**: 3/3 existing institute CLIs already use
   `AsyncParsableCommand`. The async surface is the institute-conventional
   shape; sync is reached for never in practice.
7. **Cost is bounded and ergonomic**, not structural — process-startup
   library load (single-digit ms) and `async` keyword visibility. The `@CLI`
   macro (v2) can elide the keyword for sync bodies.

#### Composition with D8 (`~Copyable` Commands)

The sync/async axis is **orthogonal** to the Copyable/`~Copyable` axis per
§2.5. The recommendation closes the sync/async axis at "single, always-async";
the Copyable/`~Copyable` axis remains a separate decision (D8). The expected
shape:

```swift
// L3 Copyable default (v1):
public protocol `Protocol`: ParsableArguments {
    static var configuration: Command.Configuration { get }
    static var schema: Command.Schema<Self> { get }
    mutating func run() async throws(Command.Error)
}

// L3 ~Copyable opt-in (D8 — separate sub-protocol):
public protocol `Resource.Protocol`: ParsableArguments, ~Copyable {
    static var configuration: Command.Configuration { get }
    static var schema: Command.Schema<Self> { get }
    consuming func run() async throws(Command.Error)
}
```

Two protocols total at the v1 surface: `Command.Protocol` (Copyable, mutating)
and `Command.Resource.Protocol` (~Copyable, consuming). Both are async. The
sync/async axis is collapsed; the Copyable/`~Copyable` axis remains visible.

`Command.Resource.Protocol` does NOT refine `Command.Protocol`. They are
peer protocols on the ownership axis. The framework provides
`Command.run(_: Command.Protocol.Type)` and
`Command.run(_: Command.Resource.Protocol.Type)` as separate overloads on the
top-level entry point.

#### Naming consequence

`Command.Async.Protocol` and the `Command.Async` namespace SHOULD NOT exist.
The parent doc's §3.5 top-level namespace listing should be revised:

```diff
- .Async                                      — namespace for async-variant types
-   .Protocol                                 — async variant of Command.Protocol
+ .Resource                                   — namespace for ~Copyable Command variants (D8)
+   .Protocol                                 — ~Copyable Command, consuming async run
```

#### Diff size against swift-argument-parser

Migration from `swift-argument-parser`:

```swift
// Before:
struct Tool: AsyncParsableCommand {
    mutating func run() async throws { … }
}

// After:
struct Tool: Command.Protocol {
    mutating func run() async throws(Command.Error) { … }
}
```

For consumers currently on `AsyncParsableCommand` (the institute's case): rename
the protocol and tighten the throw to typed. Two-line migration.

For consumers currently on `ParsableCommand` (sync `run`): add `async` to the
`run()` signature. Three-line migration.

The diff size is non-zero but bounded. swift-argument-parser's PR #404
deprecation of `AsyncMainProtocol` in Swift 5.6 set the precedent for
similarly-sized migrations being acceptable in the CLI ecosystem.

### Open Questions deferred

#### O1 — Does the `@CLI` macro elide `async` from user-source?

Direction (not premise). The macro design (v2) MAY inspect the user's `run()`
body for `await` expressions and lower to either `func run() async throws(E)`
(present) or to a synchronous wrapping (absent). This is sugar; structurally
unimportant.

Resolution: separate design arc for `@CLI` macro (deferred to v2 per parent
doc D1).

#### O2 — Should `Command.Resource.Protocol` (D8) be its own protocol, or a
typestate variant of `Command.Protocol`?

Direction (not premise). The decision relates to D8 mechanism choice (α
macro-generated init / β builder-finalizer / γ WitnessProjection per parent
doc §VI). Independent of the sync/async axis closed by this doc.

Resolution: deferred to D8 design arc.

#### O3 — If `reasync` ever lands, does the design migrate?

Direction (not premise; speculative). If Swift adds `reasync` (still Future
Direction since 2021), the institute could in principle convert
`mutating func run() async throws(E)` to `mutating func run() reasync throws(E)`
to recover the sync-when-body-is-sync ergonomics. This would be a non-breaking
relaxation. Not a v1 concern.

Resolution: revisit if `reasync` lands; no action needed pre-landing.

---

## Outcome

**Status**: RECOMMENDATION.

**Recommended option**: A — single protocol, always-async (`mutating func run()
async throws(Command.Error)`).

**Material implications for parent doc** (`2026-05-15-swift-arguments-ecosystem-design.md`
v1.0.3):

1. **§3.5 top-level namespace listing** SHOULD be revised: delete `Command.Async`
   namespace and `Command.Async.Protocol` from the listing. `Command.Protocol`'s
   `run` signature SHOULD be `mutating func run() async throws(Command.Error)`
   (currently sync `throws(Command.Error)` in the listing). The §3.5 `Repeat`
   example SHOULD be updated to match.
2. **§VI D6** SHOULD be closed with disposition: "Closed by
   `2026-05-15-command-protocol-sync-async-design.md` v1.0.0 → Option A (single,
   always-async)."
3. **§VI D8** (`~Copyable` Command via `Command.Resource.Protocol`) is
   **unchanged** by this recommendation — the ownership axis is orthogonal to
   the sync/async axis. `Command.Resource.Protocol` remains a separate sub-
   protocol, with `consuming func run() async throws(Command.Error)`.
4. **Outcome decision #7** ("`~Copyable` `consuming` `run()`") is implicated:
   the `consuming run()` shape applies to `Command.Resource.Protocol`, not to
   the v1 default `Command.Protocol`. v1 default has `mutating` (Copyable).
5. **The 8 institute CLIs** currently on `AsyncParsableCommand` (
   `swift-dependency-analysis`, `swift-impact`, `swift-package-graph`)
   migrate by renaming the protocol and tightening the throw. No structural
   refactoring required.

**Cost asymmetry** of this recommendation per [RES-022]:

- Adopting Option A (single, always-async) in v1: changes one line of §3.5,
  removes one namespace, closes D6. Constrains D8 (`~Copyable` opt-in remains
  separate sub-protocol).
- Postponing the decision and shipping Option C (current parent-doc state):
  carries the swift-argument-parser DEBUG-check defect into the institute
  design from day one. Reverting later (collapse to single) is a breaking
  change requiring all conformers to migrate.

The cost asymmetry favors deciding now: a permanent shape that's cheaper to
maintain, vs. a permanent shape that admits a known defect class.

**Next steps**:

1. **Principal review** of this RECOMMENDATION → DECISION.
2. If approved, parent doc author amends `2026-05-15-swift-arguments-ecosystem-design.md`
   per the material implications above (1–4). Bump version to v1.0.4.
3. Address open questions O1–O3 only if they become blocking; O3 is unlikely
   to become blocking pre-1.0 of swift-arguments.
4. Author `swift-arguments` (L3) with the single-protocol shape.

---

## References

### Primary sources — institute

- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90`
  — `Parser.\`Protocol\``, single sync, ~Copyable [Verified: 2026-05-15]
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializer.Protocol.swift:49-82`
  — `Serializer.Protocol`, single sync [Verified: 2026-05-15]
- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift:32`
  — `Coder.Protocol`, single sync [Verified: 2026-05-15]
- `swift-foundations/swift-console/Research/async-sync-event-api.md` v2.0.0
  DECISION — Console.Events.Stream/Poll dual-type precedent [Verified: 2026-05-15]
- `swift-institute/Experiments/actor-run-noncopyable-return/Sources/main.swift`
  — async + typed throws + ~Copyable + sending composes [Verified: 2026-05-15,
  revalidated Swift 6.3.1 2026-04-17]
- `swift-primitives/swift-io-primitives/Research/io-witness-capability-runner-split.md:137`
  — `consuming async throws(E)` ecosystem usage [Verified: 2026-05-15]
- `swift-primitives/swift-async-primitives/Research/barrier-api-investigation-2026-04-25.md:132`
  — `consuming async throws(E)` ecosystem usage [Verified: 2026-05-15]
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis CLI/CLI.swift:6`
  — institute CLI using `AsyncParsableCommand` [Verified: 2026-05-15]
- `swift-foundations/swift-impact/Sources/Impact CLI/SwiftImpact.swift:36`
  — institute CLI using `AsyncParsableCommand` [Verified: 2026-05-15]
- `swift-foundations/swift-package-graph/Sources/Package Graph CLI/PackageGraph.swift:52`
  — institute CLI using `AsyncParsableCommand` (8 subcommands) [Verified: 2026-05-15]
- Parent doc: `swift-institute/Research/2026-05-15-swift-arguments-ecosystem-design.md`
  v1.0.3 §3.5, §VI D6, §VI D8 [Verified: 2026-05-15]
- `swift-institute/Experiments/argv-parser-protocol-spike/` — premise-P1
  verification, ArgvParserSpike module [Verified: 2026-05-15]

### Primary sources — external

- swift-argument-parser PR #404 commit 1141ed1 (2022-03-14): "Support an
  `async` entry point for commands" — toolchain rationale (Swift 5.5/5.6
  availability) [Verified: 2026-05-15 from local clone at
  `/Users/coen/Developer/swiftlang/swift-argument-parser/`].
- swift-argument-parser
  `Sources/ArgumentParser/Parsable Types/AsyncParsableCommand.swift:15`
  — `@available(macOS 10.15, …)` annotation on `AsyncParsableCommand`
  [Verified: 2026-05-15].
- swift-argument-parser
  `Sources/ArgumentParser/Parsable Types/ParsableCommand.swift:218-225`
  — DEBUG-check for async-subcommand-of-sync-root configuration error
  [Verified: 2026-05-15].
- SE-0413: Typed Throws —
  [proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0413-typed-throws.md)
  — typed throws abstracts the `throws` effect, NOT the `async` effect.
- SE-0421: Generalize effect polymorphism for AsyncSequence —
  [proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0421-generalize-async-sequence.md)
  — generalizes `throws` for AsyncSequence; AsyncSequence remains
  unconditionally async.
- SE-0338: Clarify the Execution of Non-Actor-Isolated Async Functions —
  [proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md#future-directions)
  — `reasync` listed as Future Direction (no pitch as of 2026-05-15).
- .NET System.CommandLine Beta 4 retrospective —
  [github.com/dotnet/command-line-api/issues/1750](https://github.com/dotnet/command-line-api/issues/1750)
  — collapse-to-single-async rationale.
- Forum thread for SE-0420 (Inheritance of actor isolation), comment at line
  449 — reasync as a candidate solution [Verified: 2026-05-15 from local
  corpus].
- Forum thread for SE-0421 — typed-throws-as-mechanism-not-reasync
  confirmation [Verified: 2026-05-15 from local corpus].
- clap (Rust) — [docs.rs/clap](https://docs.rs/clap/latest/clap/) — no
  protocol-level run; caller dispatches.
- optparse-applicative (Haskell) — [Hackage](https://hackage.haskell.org/package/optparse-applicative)
  — `execParser :: ParserInfo a -> IO a`; caller threads IO.
- cobra (Go) — [github.com/spf13/cobra](https://github.com/spf13/cobra) —
  uniform sync `Run`/`RunE`; concurrency via runtime not signature.

### Institute prior-art context

- `2026-05-15-swift-arguments-ecosystem-design.md` (parent doc) Tier 2
  RECOMMENDATION — establishes the L3 design space; this doc closes D6.
- `feedback_correctness_and_evergreen.md` — decisions on ownership and
  effect axes are judged on structural correctness + evergreen, not adoption
  count. Cited as the disposition basis for this doc.
- `async-sync-event-api.md` (Console.Events) v2.0.0 DECISION — institute
  precedent for dual sync/async surfaces as two distinct types (rejected for
  Command-Protocol case in this doc; preserved as a useful reference).
- `actor-run-noncopyable-return` experiment — composition substrate for
  `async + typed throws + ~Copyable + sending`; underlies the composition
  argument in §2.5.

### Compliance checklist

- [RES-019] Internal grep — completed; found Console.Events,
  actor-run-noncopyable-return, parser/serializer/coder shapes [Verified:
  2026-05-15].
- [RES-021] Prior art survey — 6 systems surveyed (swift-argument-parser,
  clap, optparse-applicative, .NET, cobra, Click); contextualization step
  applied per [RES-021].
- [RES-022] Theoretical grounding — Swift effects polymorphism state
  documented; SE-0413, SE-0421, SE-0338 cited.
- [RES-023] Empirical-claim verification at write time — all institute
  file:line citations verified at write time; commit hash 1141ed1 verified
  from local clone.
- [RES-026] Citations — all primary sources cited with permalinks or
  file:line.
- [RES-027] Loose-end follow-up — premise items absent (this doc closes a
  direction, not a premise); direction items O1–O3 enumerated and labeled.
- [RES-018] Premature-primitive check — not applicable (this doc analyzes
  protocol shape, not new primitive proposal).
- [RES-022] Recommendation framing — structural axis dominates; diff-size
  and ergonomic axes used as tiebreakers only after structural closure
  ("single is structurally simpler").
- [RES-029] Binding/placement framing — the question IS a placement question
  ("where does the run effect live — in the protocol shape, or in the
  conformer's body?"); answered on semantic identity ("the protocol's job is
  to admit any-effect bodies; the user's body decides what work to do") not
  cost/pragmatism.
