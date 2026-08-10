# IO channel realization under the generic `IO<Capabilities>` front door

**Status:** RULING PACKAGE — awaiting principal ratification.
**Author:** IO-channel design session, commissioned 2026-08-10 by the principal via the Launch coordinator (session 8830f961).
**Governs:** TX-N1 (swift-foundations/swift-io#7) — the ratified two-tier channel design (`IO.Channel<Element, Failure>` generic duplex; `IO.Byte.Channel<Failure>` thin byte interpretation).
**Toolchain for every probe:** Apple Swift 6.4 (swiftlang-6.4.0.27.1), `xcrun swiftc`, arm64-apple-macosx27.0.0. Probe sources preserved verbatim in this document.

## 1. The question

The ratified spellings nest the channels under `IO`. Live source has `IO` as the generic
struct `IO<Capabilities: Sendable>` (swift-io-primitives, `IO.swift:93`), so the spellings
do not realize as written. The principal's binding frame: `IO<Capabilities>` stays; the
question to answer with proof, not assertion, is **why can't the channel be
`IO<Capabilities>.Channel`?** — including whether duplexity is *already* a capability in
the `IO` algebra, making capability-parameterized channels the deeper unification.

## 2. What `IO<Capabilities>` means (read from source, not from the name)

`IO<Capabilities>` is the L1 **coproduct bundle**: a *value* pairing

- `capabilities: Capabilities` — a **stored** domain witness struct of operation closures
  (`File.Capabilities`, `Socket.Capabilities`: `open`/`read`/`write`/… as `@Sendable`
  closures), and
- `runner: Runner` — the scheduling evidence (executor + shutdown hook).

The doc comment states the design basis explicitly: the Plotkin–Power–Pretnar
algebraic-effects coproduct — each domain supplies its own *signature*, the runner is the
shared scheduling concern, `IO` is the shell that combines them.

Two consequences, both decisive:

1. **`Capabilities` is not a phantom and not a type-level capability algebra.** It is a
   stored value-level witness. There is no `Read`/`Write`/`Seek` tag lattice anywhere in
   swift-io-primitives or swift-io; "capability" in this design (and throughout the
   Research corpus — `io-prior-art-and-swift-io-design-audit.md` §3.6 "Capability Passing
   vs. Ambient Authority") means *explicitly passed operation sets*, the Eio/Zig style,
   not Rust-typestate phantom tags. The prior-art audit in fact **rejects** the generic
   lowest-common-denominator surface deliberately (its "no generic Reader/Writer trait —
   by design" finding, and the .NET `Stream` cautionary case where callers discover
   capabilities at runtime).

2. **Directionality/duplexity is therefore not a capability in this algebra.** Direction
   lives in *which operations a domain's Capabilities struct contains* (a `read` closure,
   a `write` closure) — value-level, per-domain, behind the witness. A channel is not an
   operation signature; it is the **data plane** those operations feed. `IO<ReadWrite>.Channel`
   presupposes a phantom algebra that does not exist in live source; introducing one would
   be exactly the refactor of `IO<Capabilities>` whose default the principal has set to
   "no refactor without proof of better". The capability algebra does not subsume the
   duplex design — the two are orthogonal concerns related by *integration* ("a channel is
   pumped by operations drawn from an `IO<C>`"), not by *nesting*.

The doctrine names this relation precisely: the channel↔bundle relation is an
**interpretation/integration** (doctrine §3.2), owned at the narrowest unit that can see
both — the L3 channel target — never expressed by capturing one type's parameter in the
other's identity.

## 3. Can it compile? Yes. Should it? The probes

The coordinator's earlier "phantom capture changes type identity" was an assertion. It is
now compiler-confirmed, alongside the full cost/benefit at real call sites.

### Probe P1 — nested `Channel` in `extension IO` (option a)

```swift
public struct IO<Capabilities: Sendable>: Sendable { public let capabilities: Capabilities }
extension IO {
    public struct Channel<Element: Sendable, Failure: Swift.Error> {
        public init() {}
        public func send(_ e: Element) {}
    }
}
public struct SocketCapabilities: Sendable {}
public struct FileCapabilities: Sendable {}

func a(_ c: IO<SocketCapabilities>.Channel<Int, Never>) {}          // ✅ compiles
func b() {
    let ch: IO<SocketCapabilities>.Channel<Int, Never> = .init()    // ✅ with full annotation
    ch.send(1)
}
func stream<C: Sendable, E: Sendable, F: Swift.Error>(_ ch: IO<C>.Channel<E, F>) {}  // ✅
func d(_ x: IO<SocketCapabilities>.Channel<Int, Never>) {
    let y: IO<FileCapabilities>.Channel<Int, Never> = x
    // ❌ error: cannot convert parent type 'IO<SocketCapabilities>' to expected type
    //    'IO<FileCapabilities>'
}
```

Findings, each verified:
- The **bound** spelling compiles and works, including generic consumers.
- **Type identity fragments per domain** (P1d, the hard error above): a channel produced
  against `Socket.Capabilities` and one against `File.Capabilities` are *distinct types*
  even at identical `Element`/`Failure`. The generic duplex tier exists precisely to be
  domain-independent (TX-N5's HTTP body must flow over sockets in tests and mock
  transports alike); nesting defeats its purpose at the type level.
- **Every consumer generic signature grows a `Capabilities` parameter it never uses**
  (P1c: `stream<C: Sendable, …>`), violating the swift skill's own phantom rule — a
  parameter never stored and never flowing through an operation is a phantom, and
  `Channel` would store no `Capabilities` and draw no law from it.
- **The unbound spelling is a hard error** (`reference to generic type 'IO' requires
  arguments in <...>`; lane probe, re-confirmed here), so domain-free channels need dummy
  binds. The ecosystem already demonstrates that cost live: `Buffer<S>` is the same
  generic-front-door shape, and TX-N1B's **own tests** must write `Buffer<Never>.Slice(span)`
  — a `Never` bind carrying no meaning, pure ceremony at every domain-free site.

`IO.Runner` is not a counter-precedent: its doc comment concedes the phantom carry and
explains why it is tolerable *there* — runners are constructed inside per-(domain ×
strategy) factories where `Capabilities` is already bound and never flow across domains.
Channels are the opposite: they are the values that *cross* consumers.

### Probe P2 — the member-typealias workaround crashes swift-frontend (reproduced)

```swift
public struct IO<Capabilities> { let c: Capabilities }
extension IO { public typealias Alias<E> = Array<E> }
func h(_ x: IO.Alias<Int>) {}   // 💥 swift-frontend SIGSEGV
```

Reproduced on swiftlang-6.4.0.27.1: SIGSEGV in
`TypeResolution::applyUnboundGenericArguments` →
`InFlightSubstitution::substType` while resolving `IO.Alias<Int>`
(`ResolveTypeRequest`). Recorded as an internal toolchain defect at
swift-institute/Issues (crash text and reproducer preserved there); NOT filed upstream —
upstream contact is principal-gated. Adjacent to, but distinct from, Issues#81 (the
rejects-valid lookup gap through an unbound generic *alias*; this is a crash through an
unbound generic *nominal* with a generic member alias).

### Probe P3 — capability-constrained extension (option b)

```swift
extension IO where Capabilities == Never {
    public struct Channel<Element, Failure: Swift.Error> {}
}
func a(_ c: IO<Never>.Channel<Int, Never>) {}   // ✅ compiles
```

Compiles, but the member exists only at the pinned bind and every call site spells the
pin (`IO<Never>.Channel<…>`). This is the dummy-bind ceremony of option (a) made
mandatory, with a lie in the middle — `Never` (or any sentinel) is not a domain. Rejected.

### Probe P4 — a second `IO` namespace in another module (option d-variant)

Module `IOP`: `public struct IO<Capabilities: Sendable>`. Module `IOX`:
`public enum IO { public struct Channel<…> }`. Client imports both:

```
error: 'IO' is ambiguous for type lookup in this context
```

Unqualified `IO` — the entire point of the spelling — dies for every consumer that can
see both modules, and swift-io's umbrella re-exports IO_Primitives, so every consumer
sees both. Only fully qualified `IOX.IO.Channel` survives. Rejected. A nested caseless
`IO.Channels` sibling enum is the same option (a) phantom capture (any member of
`extension IO` captures `Capabilities`), so it is not a distinct option at all.

### Probe P6 — #104/#105-class metadata check for the bound nested shape

Because option (a) remains *admissible* in bound form, the value-generic/nested-generic
metadata risk was probed: `IO<SocketCapabilities>.Channel<Int, any Swift.Error>`
instantiated, mutated, and dynamically reflected (`Any.Type` metatype request) under
`-O`; ran clean, exit 0. No `let n: Int` value generics appear in any candidate shape, so
the Issues#104/#105 signatures (value-generic metadata; runtime libswiftCore
generic-metadata instantiation SIGSEGV) do not recur here on the shapes probed. This is
evidence about the probed shapes only, not a general clearance.

## 4. Option (c): top-level `Channel` — the package's own realized convention

swift-io's realized convention is **top-level noun per target**: `Event` (IO Events
target), `Completion` (IO Completions target) — neither nests under `IO`, for exactly the
reason at issue. The channels follow it:

- **`Channel<Element, Failure>`** — top-level, new `IO Channels` target in swift-io.
  Owns exactly the ratified tier-1 laws: half-close ordering, cross-direction failure
  propagation, shutdown sequencing, as the product of two L1 channel ends.
- **`Byte.Channel<Failure>`** — tier 2, nested by **namespace adoption** in the existing
  `Byte` owner (`public struct Byte`, swift-byte-primitives — a plain non-generic struct,
  so nesting is phantom-free). `Byte.Channel` is the corpus's subject-first shape ("parse
  the bytes" → `Byte.Parser`; "channel the bytes" → `Byte.Channel`), and the adoption is
  the sanctioned kind: substantial domain behavior (chunk-boundary erasure law) built on
  the adopted concept, not a shortening alias. It also preserves the ratified reading
  order `…Byte.Channel<Failure>` exactly.

The ratified *vocabulary* (two tiers, their laws, their parameters) is preserved
untouched; only the leading `IO.` prefix — which live source has never been able to
honor — is dropped, in favor of the convention the package already realizes twice.
`IO<Capabilities>` is not touched: zero refactor, zero fleet impact, and the L1 bundle
remains the sole owner of the capability/runner concept.

## 5. Consumer call-site comparison

| Consumer | (a) nested in `IO` | (c) top-level per convention |
|---|---|---|
| TX-N5 HTTP body streaming (domain-generic) | `func body<C: Sendable>(_: IO<C>.Channel<Buffer…, HTTP.Error>)` — phantom `C` threaded through every signature in the stack | `func body(_: Channel<Buffer…, HTTP.Error>)` |
| TX-N2 sockets (domain-fixed) | `IO<Socket.Capabilities>.Byte.Channel<Socket.Error>` — a nested `Byte` captures the phantom too, so a file-domain byte channel is a *different type* | `Byte.Channel<Socket.Error>` |
| TX-N7B client (crosses domains: socket transport, mock transport in tests) | impossible without erasure or a phantom parameter on the client's own API; a test-mock channel cannot be handed where a socket channel is expected (P1d hard error) | `Byte.Channel<Client.Error>` — one type, any transport |
| Domain-free construction (tests, adapters) | `IO<Never>.Channel<Int, Never>()` — dummy bind (live precedent: `Buffer<Never>.Slice(span)` in TX-N1B's own tests) | `Channel<Int, Never>()` |
| Extension authoring | every `extension IO<…>.Channel` re-states the phantom context; constrained-per-member extensions pin sentinel binds (P3) | `extension Channel`, `extension Byte.Channel` |

## 6. Recommendation

**Realize the ratified two-tier design as option (c):** top-level `Channel<Element,
Failure>` in a new swift-io `IO Channels` target, plus `Byte.Channel<Failure>` by
namespace adoption on the `Byte` owner. Reject (a)/(b) on the compiler-verified identity
fragmentation, phantom-parameter violation, and dummy-bind ceremony; reject (d) on the
ambiguity probe; (e) surfaced nothing beyond these.

The answer to the principal's question in one sentence: `IO<Capabilities>.Channel`
*compiles* when bound, but `Capabilities` is a stored value-level operation witness — not
a type-level capability algebra — so nesting buys the channel no law while charging every
consumer a phantom parameter, splitting channel identity per domain (compiler-confirmed),
and forcing sentinel binds at every domain-free site; the channel's true relation to
`IO<C>` is integration (operations pump channels), which composition expresses and
nesting distorts. **`IO<Capabilities>` itself is correct and stays exactly as designed** —
this ruling changes nothing about it; it locates the channels beside it, per the
package's own convention.

ABI/evolution posture: top-level types in a fresh target carry no phantom in their
mangling; adding future capability-parameterized *views* later (if a real law ever
demands one) remains additive. Under (a), by contrast, the phantom is burned into every
mangled symbol and can never be removed without a source- and ABI-breaking migration.

## 7. Sub-question A — typed failure and the L1 `Async.Channel`

Live: `Async.Channel<Element: ~Copyable>` has no `Failure` parameter; errors are the
hoisted non-generic `Async._ChannelError`, deliberately hoisted around a documented IRGen
crash (typed throws + async + nested generic error).

Probe P5 (this toolchain, `-O`, run clean): a two-parameter
`Async.Channel2<Element, Failure>` with `async throws(Failure)` members **and** a nested
generic error with `async throws(NestedError)` both compile and execute in the minimal
shape. So the historical guard does not fire minimally on 6.4 — but the swift skill's
accidental-generic `@error` trap is SIL-level (`-O -enable-default-cmo`, eliminable
argument) and a minimal pass is not clearance for the full package.

Decision inputs: a two-parameter retrofit is **source-breaking for every
`Async.Channel<E>` spelling** (Swift has no default generic parameters on types); 18+
consumer files outside the owner package reference `Async.Channel` today.

**Recommendation: the additive failure-typed tier at the L1 owner** — a sibling
failure-typed channel variant in Async Channel Primitives whose ends transport
`Result`-or-terminal with a typed fail-terminal, existing spellings untouched; the L3
`Channel<Element, Failure>` composes it. Reject the two-parameter retrofit (fleet-wide
break for zero law gained at existing call sites). Reject typed-throws-at-operation-only
(it leaves failure un-transportable across the duplex pair — cross-direction failure
propagation, a ratified tier-1 law, needs failure as *state* in the channel, not merely
as an effect on one call). Exact naming of the tier is the executing lane's, under the
swift skill's naming rules.

## 8. Sub-question B — `Buffer.Slice<Byte>` is the handoff, and the owned chunk is named

Confirmed, from TX-N1B source and receipt: `Buffer.Slice<Element>` is `~Copyable ~Escapable`,
a Span-backed bounded read **view** — structurally impossible to buffer across a
suspension, so it is the **handoff type** at the read/write API boundary, exactly as its
own doc comment binds it ("the canonical contiguous byte-chunk representation … `IO.Byte.Channel`
fixes exactly `Buffer.Slice<Byte>` as its handoff type").

The owned escapable chunk stored internally is likewise already named — by the TX-N1B
receipt itself (swift-buffer-primitives#10, measured-gap plan): the byte-chunk binding is
**`Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Byte>>.Linear`** — the
`~Copyable` (escapable) linear buffer discipline over heap-allocated contiguous byte
storage, span-read via `Storage.Contiguous`'s Span conformance. `Async.Channel` supports
`Element: ~Copyable`, so this chunk is a lawful channel element as-is; the channel vends
`Buffer.Slice<Byte>` by borrowing the stored chunk's span at the boundary. The lane's
reading is confirmed on both halves.

## 9. Doctrine records

### Composition record — the channels themselves

```yaml
request:
  capability: duplex async channel (tier 1) + byte interpretation (tier 2), typed failure
  laws: [half-close ordering, cross-direction failure propagation, shutdown sequencing, chunk-boundary erasure]
search:
  roots: [swift-primitives/*, swift-foundations/swift-io, Research/io-*, Research/Pure-Institute-Networking]
  positiveControls: [Async.Channel found at swift-async-primitives; Event/Completion found at swift-io]
  candidates: [Async.Channel (L1, single-direction), Event.Channel vocabulary (audit), no existing duplex owner]
owner:
  conceptId: io.channel.duplex
  coordinate: swift-foundations/swift-io, new target "IO Channels"
disposition: implementOnce   # tier 1; tier 2 is compose (interpretation over tier 1 + Buffer.Slice handoff)
change:
  dependency: swift-io -> swift-async-primitives (L3 -> L1, lawful, new manifest edge)
  relationOwner: "IO Channels" target owns Relation(Async.Channel×2, half-close/failure/shutdown laws)
  closureDelta: adds swift-async-primitives to swift-io resolution (already resolved transitively via swift-async today)
compatibility: none — no shipped consumer of the ratified spellings exists yet
verification:
  ownerFirst: [build/test IO Channels via workspace package, then N2/N5/N7B consumers]
stopConditions: [principal ratification of this realization]
```

### Reduction record — the `IO.` prefix of the ratified spelling

```yaml
candidate:
  coordinate: "ratified spelling 'IO.Channel' / 'IO.Byte.Channel' (prefix only)"
  description: nesting of the channel tiers under the IO front door
canonicalConcept: { id: io.bundle, owner: swift-io-primitives IO<Capabilities> }
relation:
  kind: interpretation
  explanation: channels are the data plane pumped by operations drawn from an IO<C>; not members of its algebra
independentProperties:
  invariants: [none carried by the prefix — no channel law references Capabilities]
  dependencyClosure: [nesting would burn a phantom into every consumer signature and mangled symbol]
preservation:
  lawfulObservations: [all four ratified laws land unchanged on the top-level types]
  proof: [P1 (bound admissible but identity-fragmenting), P2 (alias escape crashes), P3 (pin ceremony), P4 (shadow ambiguity)]
verdict: reduce   # drop the prefix; keep both tiers, all laws, all parameters
```

## 10. Evidence boundary

Read at head: swift-io-primitives `IO.swift`/`IO.Runner.swift`; swift-io `Package.swift`,
target listings, umbrella exports; swift-async-primitives Async Channel Primitives
(`Async.Channel.swift`, `Async.Channel.Error.swift`); swift-buffer-primitives
`Buffer.swift`, `Buffer.Slice*.swift`, `Buffer.Storage.swift`, `Buffer.Protocol.swift`,
TX-N1B tests; swift-buffer-primitives#10 receipt; swift-io#7 full thread;
`io-prior-art-and-swift-io-design-audit.md`. Probes P1–P6 run on swiftlang-6.4.0.27.1
via `xcrun swiftc` (the swiftly shim's 6.3.3 explicitly avoided and versions verified
first). Not measured: full-package `-O -enable-default-cmo` behavior of any candidate
(flagged in §7 as a lane-time gate); Windows/Linux legs (CI-owned).
