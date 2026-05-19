# `@safe` / `@unsafe` Attribute and `@unchecked Sendable` Best Practices

<!--
---
version: 1.1.0
last_updated: 2026-05-13
status: RECOMMENDATION
changelog:
  - 1.0.0 (2026-05-13): initial recommendation based on SE-0302 / SE-0458 text
    and stdlib + apple/swift-* package survey at that snapshot
  - 1.1.0 (2026-05-13): recency-verification pass against swiftlang/swift
    commits 2025-11 through 2026-05, post-SE-0458 evolution proposals
    (SE-0459–SE-0530), Apple package `main` branches, and the official strict-
    memory-safety compiler tests. Confirmed the peer-not-partner thesis,
    refined the deterministic rule with annotation-position grammar, and added
    the `@safe` type / `@unchecked` conformance worked example from
    `UniqueBox` (Jan–Feb 2026 stdlib commits).
---
-->

## Context

The Swift Institute ecosystem audits roughly two hundred `@unchecked Sendable`
conformance sites and must decide a consistent policy for whether to pair them
with the SE-0458 `@unsafe` attribute. This document gathers an external,
authoritative basis for that policy from the canonical Swift Evolution
proposals (SE-0302 Sendable, SE-0458 Strict Memory Safety, SE-0414 Region-Based
Isolation, SE-0447 Span, SE-0470 Isolated Conformances), the in-tree Swift
standard library, and a representative sample of mature third-party Swift
libraries (`apple/swift-collections`, `apple/swift-nio`,
`apple/swift-async-algorithms`, `swiftlang/swift-atomics`,
`swiftlang/swift/stdlib/public/Synchronization`).

The Institute's own usage is intentionally out of scope per the dispatch — the
load-bearing artifact here is the fresh external read.

## Question

Given a Swift type whose conformance to `Sendable` cannot be machine-checked
and is therefore written as `extension T: @unchecked Sendable`, when (if ever)
should the type *also* be annotated `@unsafe` per SE-0458?

Equivalently: are `@unchecked Sendable` and `@unsafe` *orthogonal*,
*complementary*, *one-implies-the-other*, or *peer attestations of distinct
safety dimensions*?

## Analysis

### A. What `@safe` is (SE-0458)

`@safe` opts a declaration out of the strict-memory-safety diagnostic that
would otherwise fire when the declaration's signature mentions an unsafe type.

> "A given declaration uses an unsafe type within its signature, [it] is
> implicitly considered to be `@unsafe`." — SE-0458 §"Unsafe declarations"
> ([source][se0458])

> "[The `withUnsafeBufferPointer`] operation itself also involves the unsafe
> type that it passes along to the closure ... From that perspective,
> `withUnsafeBufferPointer` itself can be marked `@safe`." — SE-0458
> §"`@safe` declarations" ([source][se0458])

Mechanically, `@safe` suppresses the strict-memory-safety warning at the
declaration site and signals to readers that the author has taken
responsibility for the four dimensions SE-0458 enumerates: lifetime, bounds,
type, and initialization safety. It does *not* silence anything in the
concurrency-checker.

Canonical use case: a wrapper that hands an unsafe-typed pointer to a closure
under its own lifetime discipline. Empirical anchor in stdlib:
`Array.withUnsafeBufferPointer` is `@safe` despite carrying an
`UnsafeBufferPointer` in its signature
([Array.swift:2075][array-2075]).

### B. What `@unsafe` is (SE-0458)

`@unsafe` marks a declaration as introducing memory unsafety. Callers of an
`@unsafe` declaration must, under strict memory safety mode, wrap the call in
an `unsafe` expression — analogous to `try` for thrown errors — to
*acknowledge* the unsafety.

Key properties:

1. **Implicit on signatures mentioning unsafe types.** Any declaration whose
   parameter, result, or stored-property type is itself `@unsafe` becomes
   `@unsafe` without explicit annotation. (SE-0458)
2. **Non-propagating.** Unlike `try`, `unsafe` does not bubble outward through
   the function body: a function containing `unsafe` expressions internally
   is not itself `@unsafe` unless its signature is. SE-0458 cites
   [Rust RFC #2585][rust-2585] as precedent and adopts the same model.
3. **Applicable to conformances.** SE-0458 §"Unsafe conformances" gives the
   canonical form
   `extension UnsafeBufferPointer: @unsafe Collection { ... }`
   and locates the load-bearing concern: a protocol cannot vouch for
   memory safety its requirements do not guarantee. ([source][se0458])

`@unsafe` operates over the *first four* dimensions of memory safety the
proposal enumerates. The fifth dimension — thread safety — is explicitly
delegated to Swift 6 strict-concurrency checking:

> "Swift 6's strict concurrency checking extends Swift's memory safety
> guarantees to the last dimension [thread safety]." — SE-0458 §"Dimensions
> of memory safety" ([source][se0458])

This sentence is the crux of the present question: SE-0458 *defines its
scope* to exclude thread safety, which is the dimension `@unchecked Sendable`
addresses.

### C. What `@unchecked Sendable` is (SE-0302)

`@unchecked Sendable` opts out of compiler verification of the `Sendable`
semantic requirements while leaving the conformance in place. It is the
author's attestation that the type is safe to pass across isolation
boundaries despite the compiler's inability to prove it.

The canonical SE-0302 explanation:

> "Any class may be declared to conform to `Sendable` with an `@unchecked`
> conformance ... This is appropriate for classes that use access control and
> internal synchronization to provide memory safety — these mechanisms cannot
> generally be checked by the compiler." — [SE-0302][se0302]

The stdlib doc-comment is the codified guidance:

> "To declare conformance to `Sendable` without any compiler enforcement,
> write `@unchecked Sendable`. You are responsible for the correctness of
> unchecked sendable types, for example, by protecting all access to its
> state with a lock or a queue." — `stdlib/public/core/Sendable.swift:97-100`
> ([source][sendable.swift])

`@unchecked Sendable` is silent about lifetime, bounds, type, and
initialization safety; those dimensions are not its remit.

### D. Relationship: peers, not nesting

SE-0458 explicitly names `@unchecked Sendable` as a *peer* of `@unsafe`, not
as a subset, superset, or composition:

> "Swift has a number of constructs that are functionally similar to unsafe
> conformances, where safety checking can be disabled locally despite that
> having wide-ranging consequences: `@unchecked Sendable`,
> `nonisolated(unsafe)`, `unowned(unsafe)`, and `@preconcurrency` all fall
> into this category." — SE-0458 §"Alternatives Considered" ([source][se0458])

The proposal places these four mechanisms in the *same family* as `@unsafe`
without folding them into one another. Each is the audit-point for a
different safety dimension:

| Mechanism | Safety dimension | What the author attests |
|---|---|---|
| `@unsafe` / `unsafe` expressions | Lifetime, bounds, type, initialization | The four memory-safety obligations of SE-0458 are met |
| `@unchecked Sendable` | Thread safety (cross-isolation passing) | Cross-domain mutation cannot race |
| `nonisolated(unsafe)` | Thread safety (suppressed isolation check on a stored property) | Property access is data-race-free without isolation |
| `unowned(unsafe)` | Lifetime safety (suppressed retain) | The reference outlives its uses |
| `@preconcurrency` | Migration-time concurrency check | The pre-Swift-6 API contract is preserved across the boundary |

Crucially, when SE-0458's authors *considered* extending `@unsafe` over the
concurrency dimension — specifically, marking `SerialExecutor` conformances
`@unsafe` because misimplementation can corrupt actor isolation — they
*rejected* that approach:

> "The first two options [making `SerialExecutor` `@unsafe`, or marking some
> of its requirements `@unsafe`] ... would effectively make every actor
> `@unsafe`. This pushes the responsibility for acknowledging the memory
> unsafety to clients of `SerialExecutor`, rather than at the conforming type
> where the responsibility for a correct implementation lies. The third
> option [attestation at the conformance, `@safe(unchecked)`] appears best,
> because it provides an auditable place to assert memory safety that
> corresponds with where extra care must be taken." — SE-0458 §"Future
> Directions" ([source][se0458])

The pattern the SE author endorses is *attestation at the conformance
site* — which is precisely what `@unchecked Sendable` already does for the
concurrency dimension. Forcing `@unsafe` onto a `@unchecked Sendable`
conformance reintroduces the "every conformer becomes `@unsafe`" anti-pattern
that the proposal's authors named and rejected.

### E. Stdlib empirical convention

A direct survey of the in-tree stdlib confirms the proposals' framing.
`@unsafe` is **never** paired with `@unchecked Sendable` at the conformance
site. Representative anchors:

| Site | Conformance shape | File |
|---|---|---|
| `Array` | `extension Array: @unchecked Sendable where Element: Sendable { }` | `stdlib/public/core/Array.swift:2262` |
| `Dictionary` | `extension Dictionary: @unchecked Sendable` | `stdlib/public/core/Dictionary.swift:2306` |
| `Set` | `extension Set: @unchecked Sendable` | `stdlib/public/core/Set.swift:1673` |
| `Span` | `extension Span: @unchecked Sendable where Element: Sendable & ~Copyable {}` | `stdlib/public/core/Span/Span.swift:91` |
| `MutableRawSpan` | `extension MutableRawSpan: @unchecked Sendable {}` | `stdlib/public/core/Span/MutableRawSpan.swift:59` |
| `OutputSpan` | `extension OutputSpan: @unchecked Sendable where Element: Sendable & ~Copyable {}` | `stdlib/public/core/Span/OutputSpan.swift:60` |
| `InlineArray` | `extension InlineArray: @unchecked Sendable where Element: Sendable & ~Copyable {}` | `stdlib/public/core/InlineArray.swift:113` |
| `Mutex<Value>` | `extension Mutex: @unchecked Sendable where Value: ~Copyable {}` | `stdlib/public/Synchronization/Mutex/Mutex.swift:56` |
| `Atomic<Value>` | `extension Atomic: @unchecked Sendable where Value: Sendable {}` | `stdlib/public/Synchronization/Atomics/Atomic.swift:59` |
| `_StringGuts` | `struct _StringGuts: @unchecked Sendable { ... }` | `stdlib/public/core/StringGuts.swift:22` |

The same files apply `@unsafe` lavishly to *initializers, methods, properties,
and protocol-conformance sites* that traffic in unsafe pointer types — but
never to the `Sendable` conformance itself. `Span`, which internally holds
the equivalent of a raw pointer, is the clearest data point: its
pointer-taking `init` is `@unsafe` (`Span.swift:40`, `:76`); its `Sendable`
conformance is `@unchecked Sendable` and *not* `@unsafe`.

### F. Third-party empirical convention

The pattern holds across the Apple-maintained server-Swift libraries:

| Library | Pattern observed | Sample anchor |
|---|---|---|
| `swift-collections` | `@unchecked Sendable` for CoW value types; never paired with `@unsafe` | `Sources/DequeModule/Deque.swift:107`, `Sources/OrderedCollections/OrderedDictionary/OrderedDictionary+Sendable.swift:12` |
| `swift-nio` | `@unchecked Sendable` for lock-protected reference types and pthread wrappers; never paired with `@unsafe` | `Sources/NIOPosix/SelectableEventLoop.swift:94`, `Sources/NIOPosix/Thread.swift:289` |
| `swift-async-algorithms` | `@unchecked Sendable` for the `UnsafeTransfer` escape-hatch wrapper; not `@unsafe`-paired | `Sources/AsyncAlgorithms/UnsafeTransfer.swift:13` |

A pre-SE-0458 doc comment in `apple/swift-nio` describes the wrapper as
"similar to `@unsafe Sendable`" — i.e. colloquial shorthand for "unchecked"
predating SE-0458 — and is not a counter-example. No surveyed library spells
`@unsafe @unchecked Sendable` on the same declaration.

### G. Conditions, generics, `~Copyable`, classes

Conformance shape varies across structural-conformance, conditional-on-element
`Sendable`, and `~Copyable` Value types. Empirical patterns:

| Source category | Stdlib pattern | Rationale |
|---|---|---|
| CoW value type (`Array`, `Dictionary`, `Set`, `ContiguousArray`) | `@unchecked Sendable where Element: Sendable` | The buffer is reference-shared internally; CoW prevents observable shared mutation. Conditional on element-sendability. |
| `~Copyable` storage with raw-pointer/handle (`Span`, `OutputSpan`, `InlineArray`, `Mutex`) | `@unchecked Sendable where Element/Value: ... & ~Copyable` | Lifetime/ownership-managed at the type-system level; cross-isolation transfer is sound when the element constraint holds. |
| Synchronization-backed reference (`Mutex<Value>`, `Atomic<Value>`) | `@unchecked Sendable where Value: ~Copyable` / `Sendable` | The type internally serializes all access; Sendable cannot be machine-proven through C-shim atomics or platform mutex syscalls. |
| CoW with bridging machinery (`_StringGuts`) | `@unchecked Sendable` (unconditional) | Internal bridging to Objective-C reference types whose Sendable conformance is not directly expressible. |
| Iterator/Index types backing the above | `@unchecked Sendable` (unconditional or conditional on element) | The iterator/index references the parent storage; Sendable inherits via the same argument as the parent. |

The constraint surface (`where Element: Sendable`, `where Value: ~Copyable`)
is fundamental to the conformance contract and lives on the `@unchecked
Sendable` clause itself. No surveyed example uses `@unsafe` as either an
alternative to or supplement to this constraint surface.

### H. Recency verification (v1.1.0)

Per the principal's request for a recency-focused second pass, the v1.0.0
thesis was stress-tested against the most recent state of the Swift ecosystem
(2025-11 through 2026-05). The verification draws on five evidence streams:
(1) recent commits to `swiftlang/swift` stdlib, (2) Swift Evolution proposals
numbered after SE-0458, (3) Apple package `main` branches, (4) Swift release
notes (CHANGELOG), and (5) the official strict-memory-safety compiler test
suite.

#### H.1 swiftlang/swift recent direction

The 2026-01-26 changelog entry by Guillaume Lessard
([`f17c3e8c967`][sw-f17c3e8]) and the matching source commits document a
*correction wave* that added `@unsafe` to several **methods and properties**
of `Span` family types that should have been `@unsafe` at SE-0458/SE-0467/
SE-0485 landing. The corrections:

- `Span.bytes`, `MutableSpan.bytes` — properties (not conformances) marked
  `@unsafe`.
- `MutableSpan.mutableBytes` — property marked `@unsafe`.
- `OutputRawSpan.append(_:as:)`, `OutputRawSpan.append(repeating:as:)` —
  generic methods marked `@unsafe`.

Critically, **none of these corrections touched the Sendable conformance of
any Span type**. `Span: @unchecked Sendable where Element: Sendable &
~Copyable` remains `@unchecked Sendable` alone (no `@unsafe`); the audit
moved annotations onto *member declarations whose signatures or behavior
expose unsafety*. This is the v1.0.0 pattern preserved verbatim in 2026
maintenance: `@unsafe` belongs on methods and properties; `@unchecked` belongs
on the Sendable conformance clause; **they coexist on the same type only via
different syntactic positions, never paired on one declaration**.

Related corrections in the same window:

- `2026-04-17 Replace @safe with @unsafe in ManagedBuffer's withUnsafe...
  methods` ([`fca347bd7f7`][sw-fca347b]) — moves the annotation on *methods*,
  not conformances; the Sendable conformance of `ManagedBuffer`-using types
  was not touched.
- `2026-04-17 Re-mark OutputSpan's withUnsafeMutableBufferPointer as @unsafe`
  ([`369b9cced0d`][sw-369b9cc]) — likewise on methods.
- `2026-05-01 [stdlib] remove extraneous @safe annotations`
  ([`8410e3e6a9a`][sw-8410e3e]) — TemporaryAllocation cleanup; removes
  `@safe` from declarations that did not need it. Confirms that `@safe`
  is itself sparingly applied and orthogonal to Sendable.

#### H.2 The `UniqueBox` worked example (the most load-bearing 2026 data point)

In January 2026, Alejandro Alonso added a new heap-owning smart-pointer type
to stdlib. The commit-by-commit evolution is dispositive:

| Date | Commit | Change |
|---|---|---|
| 2026-01-06 | [`6de92bc64d6`][sw-6de92bc] | Add `Box` to stdlib (no Sendable) |
| 2026-01-08 | [`0fca1189e29`][sw-0fca118] | Add `extension Box: Sendable where Value: Sendable & ~Copyable {}` (plain `Sendable`, no `@unchecked`) |
| 2026-02-10 | [`3c6dd46953c`][sw-3c6dd46] | Rename Box → Unique |
| 2026-02-10 | [`752de71c6eb`][sw-752de71] | **Mark the sendable conformance on Unique as @unchecked** — diff: `extension Unique: Sendable` → `extension Unique: @unchecked Sendable` |
| 2026-04-21 | [`606ed251ad3`][sw-606ed25] | Rename Unique → UniqueBox |

Current state (`stdlib/public/core/UniqueBox.swift:16,42`):

```swift
@available(SwiftStdlib 6.4, *)
@frozen
@safe                                                      // ← line 16
public struct UniqueBox<Value: ~Copyable>: ~Copyable {
  @usableFromInline
  let pointer: UnsafeMutablePointer<Value>
  // ...
}

@available(SwiftStdlib 6.4, *)
extension UniqueBox: @unchecked Sendable                  // ← line 42
where Value: Sendable & ~Copyable {}
```

This single type carries:

- `@safe` on the type declaration (SE-0458 attestation: the wrapper of
  `UnsafeMutablePointer` is responsibly memory-safe by virtue of its
  initializer/deinitializer discipline).
- `@unchecked` on the `Sendable` conformance (SE-0302 attestation: the
  compiler cannot see through the unsafe-pointer storage to prove
  sendability, but the author attests it).
- `@unsafe` appears nowhere in this file.

The 2026-02-10 commit is the cleanest signal in the entire corpus: a stdlib
engineer realized the type *needed* the unchecked escape hatch (because the
auto-Sendable-synthesis stops at `UnsafeMutablePointer`), and the patch
applied was **exactly `@unchecked`** — not `@unsafe @unchecked`, not
`@unsafe`. The fix-it is the proof.

SE-0517 (UniqueBox), the proposal that ratified this type, *spells* the
conformance as plain `Sendable` in its proposed-solution snippet; the
implementation team strengthened it to `@unchecked Sendable` once it became
clear the compiler synthesis path was blocked. The proposal-to-implementation
delta did not introduce `@unsafe`.

#### H.3 SE proposals post-SE-0458 (SE-0459 through SE-0530)

The full set of post-SE-0458 proposals at `swiftlang/swift-evolution/main`
was surveyed. The relevant ones:

| Proposal | Status | Relevance to the pairing question |
|---|---|---|
| SE-0463 (Sendable completion handlers) | Implemented | Discusses Sendable. No interaction with `@unsafe`. |
| SE-0467 (MutableSpan) | Implemented | `extension MutableSpan: @unchecked Sendable where Element: Sendable & ~Copyable {}` — proposal text spec. `@unsafe` decorates *methods* in the proposal. |
| SE-0470 (Isolated Conformances) | Implemented | Uses `extension C: @unchecked Sendable { }` form; orthogonal to `@unsafe`. |
| SE-0485 (OutputSpan) | Implemented | Same pattern as SE-0467. |
| SE-0517 (UniqueBox) | Implemented | See H.2 above. |
| SE-0518 (`~Sendable`) | Implemented | Introduces explicit `~Sendable` suppression; uses `@unchecked Sendable` on conformance side of subclass attestation. No `@unsafe` interaction. |
| SE-0527 (RigidArray/UniqueArray) | Implemented | `RigidArray: Sendable`, `UniqueArray: Sendable` in proposal text. |

**No post-SE-0458 proposal amends or extends the `@unsafe` / `@unchecked
Sendable` relationship.** SE-0458's *Future Direction* on `SerialExecutor`
(making executor conformances `@unsafe` because misimplementation can corrupt
actor-isolation-based memory safety) has not landed and has not surfaced in
any post-SE-0458 proposal. The only `SerialExecutor`-related work in the
window is SE-0471 (`SerialExecutor.isIsolated`), which is unrelated to
memory safety.

#### H.4 Apple package `main` branches

A fresh count across `apple/swift-*` repositories at HEAD of `main`
(2026-05-13):

| Package | Tag / HEAD | `@unchecked Sendable` count | `@unsafe @unchecked Sendable` count |
|---|---|---|---|
| swiftlang/swift stdlib | latest main | 86 | **0** |
| apple/swift-collections (1.1.6 + `main`) | 1.1.6 / 2026 commits on main | 12 (1.1.6) + new types in BasicContainers preview | **0** |
| apple/swift-foundation | 2026-03 snapshot | ~17 | **0** |
| apple/swift-async-algorithms | 1.0.1 | 5 | **0** |
| apple/swift-syntax | main | 6+ | **0** |
| apple/swift-nio | 2.92.2 | 62 | **0** |
| apple/swift-atomics | latest | 4 | **0** |
| apple/swift-asn1 | latest | 0 | **0** |
| apple/swift-certificates | latest | 3 | **0** |
| apple/swift-crypto | latest | 2 | **0** |
| apple/swift-system | latest | 1 | **0** |
| apple/swift-argument-parser | latest | 4 | **0** |
| apple/swift-log | latest | 1 | **0** |
| apple/swift-subprocess | 0.2.1 | 13 | **0** |
| apple/swift-testing | latest | 0 | **0** |
| apple/swift-numerics | latest | 0 | **0** |

Aggregate: **several hundred `@unchecked Sendable` sites; zero `@unsafe
@unchecked Sendable` pairs.** Most recent representative: swift-collections'
`Sources/BasicContainers/RigidArray/RigidArray.swift:105` (on `main`,
post-SE-0527):

```swift
extension RigidArray: @unchecked Sendable where Element: Sendable & ~Copyable {}
```

The same file's lines 231, 428, 452 carry `@unsafe` on specific methods. Same
pattern as `Span` in stdlib: conformance is bare `@unchecked Sendable`,
unsafety is annotated at member-declaration sites.

#### H.5 Swift release notes (CHANGELOG.md)

Swift 6.2 (where SE-0458 landed) and Swift 6.3 (current development) were
examined for any policy change. Findings:

- Swift 6.2: SE-0458 introduces `@unsafe` / `@safe` / `unsafe` expression /
  unsafe-conformance. The proposal text and the changelog entry both
  enumerate `@unchecked Sendable` as a *peer* opt-out, not a target for
  `@unsafe` adoption.
- Swift 6.3: no entry changes the `@unsafe` / `@unchecked Sendable` story.
- Swift (next, ~6.4): the 2026-01-26 `@unsafe` correction wave (H.1) is
  documented in the changelog; the corrections are entirely on member
  declarations.

No release introduces a "you should pair them" guidance. The vision document
([`memory-safety.md`][vision]) lists `@unchecked Sendable` among the
mechanisms that the strict-memory-safety checker *flags at consumer sites* —
the flagging is the trigger to acknowledge with `unsafe`-expression at the
call site, **not** a requirement to annotate the conformance declaration with
`@unsafe`.

#### H.6 Compiler tests — the dispositive evidence

The official strict-memory-safety test suite (`test/Unsafe/` in
swiftlang/swift) explicitly verifies the convention. Two patterns are
canonical:

`test/Unsafe/unsafe_concurrency.swift:11` (header:
`-strict-memory-safety -enable-experimental-feature StrictConcurrency`):

```swift
class C: @unchecked Sendable {
  var counter: Int = 0
}
// ...
acceptSendable(C()) // okay
```

The comment `// okay` is the test assertion: under strict memory safety mode,
`@unchecked Sendable` alone is the correct spelling. Passing such an instance
to a `Sendable`-requiring function emits no diagnostic.

`test/Unsafe/unsafe-suppression.swift:77-83` shows the canonical patterns
when both attributes are needed:

```swift
@unsafe
class SendableC1: @unchecked Sendable { }   // @unsafe on TYPE, @unchecked on CONFORMANCE

class SendableC2 { }

@unsafe
extension SendableC2: @unchecked Sendable { }  // @unsafe on EXTENSION, @unchecked on CONFORMANCE
```

The test expects no diagnostics on these declarations. The grammar of
SE-0458's `@unsafe` permits three positions:

| Position | Spelling | Semantics |
|---|---|---|
| Type declaration | `@unsafe struct T { ... }` | The type's signature mentions an unsafe type |
| Extension declaration | `@unsafe extension T: P { ... }` | The extension introduces unsafe conformance to a non-Sendable protocol |
| Conformance clause | `extension T: @unsafe P { ... }` | This specific conformance is unsafe |

Position #3 — `@unsafe` *inside* the conformance clause — is grammatically
permitted, but stdlib + Apple packages **never** use it for `Sendable`.
`Sendable` is a concurrency claim, not a memory-safety claim; `@unsafe` at the
conformance-clause position is reserved for protocols that vouch for memory
safety the conforming type cannot guarantee (the SE-0458 canonical example
is `extension UnsafeBufferPointer: @unsafe Collection { ... }`).

The single in-stdlib occurrence of an `@unsafe` type co-existing with
`@unchecked Sendable` is `UnsafeSleepStateToken`
(`stdlib/public/Concurrency/TaskSleep.swift:128`):

```swift
@unsafe struct UnsafeSleepStateToken: @unchecked Sendable {
  let wordPtr: UnsafeMutablePointer<Builtin.Word>
  // ...
}
```

Here `@unsafe` is on the **struct declaration** (because its signature exposes
`UnsafeMutablePointer<Builtin.Word>`); `@unchecked` is on the **conformance
clause**. The attributes inhabit different syntactic positions and address
different safety dimensions. This is the "peers, not partners" pattern in
its purest form.

#### H.7 Conclusion of recency pass

The v1.0.0 conclusion is **confirmed without amendment**. The 2026
ecosystem is, if anything, *more* convergent on the peer-not-partner rule
than the 2024-2025 baseline. The recency pass adds:

1. Refined annotation-position grammar (H.6): `@unsafe` has three syntactic
   positions; only positions #1 and #2 are observed alongside `@unchecked
   Sendable`, and only when the *type or extension itself* (not the
   conformance) traffics in unsafe storage.
2. The `UniqueBox` worked example (H.2): the most recent live demonstration
   of "`@safe` type + `@unchecked Sendable` conformance" — a deliberate,
   commit-by-commit choice to annotate two distinct safety dimensions at two
   distinct positions, with `@unsafe` appearing nowhere.
3. Verification that the SE-0458 *Future Direction* on `SerialExecutor` has
   not landed; no post-SE-0458 proposal amends the rule.
4. Compiler-test confirmation (H.6) that `@unchecked Sendable` *alone* is the
   spelling the language designers test for under strict memory safety mode.

## Outcome

**Status**: RECOMMENDATION

### Headline

`@unchecked Sendable` and `@unsafe` are **peers, not partners**: they
attest to different dimensions of safety, neither implies nor strengthens the
other, and the universal stdlib + third-party-Apple-library convention is
**not to pair them**.

### Recommendations

1. **Use plain `Sendable` whenever the compiler can check it.** The base case
   is the auto-synthesized conformance for value types whose stored members
   are all `Sendable`, or `final class` types with `let`-immutable, `Sendable`
   storage. No annotation beyond the conformance clause is needed or
   appropriate.

2. **Use `@unchecked Sendable` when (and only when) the type is genuinely
   thread-safe but the compiler cannot prove it.** SE-0302's taxonomy is the
   canonical guide; in practice the cases reduce to four families
   (the policy uses the labels from `[MEM-SAFE-024]`-style categorization to
   align with the Institute's audit, but the families themselves are
   externally attested):

   - *Synchronization-backed*: the type guards all mutation with a mutex,
     queue, atomics, or actor-like coordinator. (`Mutex`, `Atomic`,
     `NIOLock`-protected types.)
   - *Ownership-transfer / CoW*: the type uses copy-on-write or move-only
     discipline so that "shared" storage is never concurrently mutated.
     (`Array`, `Dictionary`, `Set`, `Deque`, `OrderedDictionary`, ...)
   - *Caller-attested*: the type is a wrapper whose semantics intentionally
     defer the safety obligation to the caller — typically an explicit
     "Transfer" / "Box" / "Sendable wrapper" type. (`UnsafeTransfer` in
     swift-async-algorithms.)
   - *Structural-workaround*: a type contains a member whose Sendable
     conformance is unexpressible in the type system (e.g., bridged-from-ObjC
     storage, opaque platform handles, `~Copyable` storage whose Sendable
     bound the compiler cannot yet check). (`_StringGuts`, `Span`.)

3. **Do not additionally annotate the conformance with `@unsafe`.** SE-0458
   restricts `@unsafe`'s scope to the four memory-safety dimensions (lifetime,
   bounds, type, initialization). Thread safety is explicitly carved out and
   delegated to the strict-concurrency model, of which `@unchecked Sendable`
   is the audit point. Stdlib, swift-collections, swift-nio,
   swift-async-algorithms, and swift-atomics all follow this convention
   unanimously across the surveyed declarations.

4. **Apply `@unsafe` independently when (and only when) SE-0458 requires it.**
   `@unsafe` on a *separate* declaration — initializer, method, property,
   non-`Sendable` protocol conformance — is the right tool when that
   declaration introduces memory unsafety. The clearest example is
   `Span.init(_unchecked: UnsafeMutableRawPointer, count: Int)`, which is
   `@unsafe` because it takes a raw pointer; the *same* `Span` type's
   `Sendable` conformance is `@unchecked Sendable` *without* `@unsafe`,
   because that conformance is a concurrency claim, not a memory-safety
   claim.

5. **For ecosystem audits whose taxonomy labels Sendable safety claims as
   *synchronization-backed*, *ownership-transfer*, *caller-attested*, or
   *structural-workaround***: the category label is the *justification* for
   the `@unchecked Sendable` clause, not a trigger for additional
   annotation. The category should be recorded — typically as a
   doc-comment or audit-table entry — but does not change the on-source
   spelling of the conformance.

### Edge cases

- **Conditional conformances** (`where Element: Sendable`) follow the same
  rule: the `where` clause carries the conformance constraint; no `@unsafe`
  is appropriate. (`Array`, `Span`, `InlineArray`.)
- **Unconditional conformances** on types with bridged or opaque storage
  (`Dictionary` post-Foundation-bridging, `_StringGuts`) likewise: unconditional
  `@unchecked Sendable`, no `@unsafe`.
- **`~Copyable` types**: stdlib pattern is `@unchecked Sendable where Value:
  ~Copyable` (Mutex) or `@unchecked Sendable where Element: Sendable &
  ~Copyable` (Span, OutputSpan). The `~Copyable` bound is part of the
  conformance contract; `@unsafe` is not added.
- **Classes**: `final class`es with internal synchronization use `@unchecked
  Sendable` per SE-0302's canonical recipe; `final` is not load-bearing for
  the *@unsafe* question. Non-final classes that need `@unchecked Sendable`
  remain a code-smell unrelated to `@unsafe`.

### Deterministic rule (v1.1.0)

The institute requested a single mechanical algorithm. The rule below is
derived from the full Analysis (especially section H.6's annotation-position
grammar) and is intended to be applied uniformly across all `@unchecked
Sendable` sites in the ecosystem audit.

```
GIVEN a type T (or an extension on T) that needs `Sendable` conformance:

  IF the compiler can synthesize Sendable for T:
      (i.e., all stored properties are Sendable and either T is a value
       type with no escape hatches, or T is a final class with let-immutable
       Sendable storage)
    USE plain `Sendable`:
        extension T: Sendable where ...
        // or
        struct T: Sendable { ... }
    No additional attributes.

  ELIF T is genuinely thread-safe but the compiler cannot prove it:
      (one of the four families:
        - synchronization-backed   — Mutex/Atomic/locks/queues
        - ownership-transfer / CoW — Array/Dictionary/Set/Deque/RigidArray
        - caller-attested          — UnsafeTransfer/Box/wrapper types
        - structural-workaround    — _StringGuts/types whose Sendable bound
                                     the type system cannot yet express)
    USE bare `@unchecked Sendable` on the conformance clause:
        extension T: @unchecked Sendable where ...
        // or, if the conformance is at the primary declaration:
        struct T: @unchecked Sendable { ... }
    No `@unsafe` is added to the conformance, the conformance clause,
    or the protocol slot. Stop here.

  ELSE: (T is NOT thread-safe — race conditions are observable)
    DO NOT add a Sendable conformance.
    USE one of:
      - `~Sendable` to explicitly suppress (SE-0518)
      - `sending` parameter to require ownership transfer at call sites
      - isolation (actor / global-actor) to confine access
    Stop here.

ORTHOGONALLY:

GIVEN a declaration D (initializer, method, property, subscript, or non-Sendable
protocol conformance) on T:

  IF D's signature mentions an unsafe type
     (e.g., UnsafeMutablePointer, UnsafeRawPointer, etc.)
     OR D's body bypasses one of SE-0458's four memory-safety dimensions
     (lifetime / bounds / type / initialization):
    APPLY `@unsafe` at the appropriate syntactic position:
      a) on the declaration itself for methods/properties/initializers:
            @unsafe func swapAt(_ i: Index, _ j: Index)
      b) on the type/extension declaration when the storage itself
         carries unsafe types AND consumers should be alerted at every use:
            @unsafe struct UnsafeSleepStateToken: @unchecked Sendable { ... }
      c) on the conformance clause for non-Sendable protocols whose
         requirements the type satisfies only by transferring memory-safety
         obligations to callers:
            extension UnsafeBufferPointer: @unsafe Collection { ... }
    `@unsafe` NEVER decorates the `Sendable` protocol slot. The Sendable
    conformance carries `@unchecked` per the Sendable rule above; the unsafety
    annotation lives on the unsafe declaration, not the safety-orthogonal
    Sendable claim.

  ELSE:
    No annotation; the declaration is implicitly safe.
```

In one line: **Sendable carries `@unchecked` when the compiler can't prove it;
`@unsafe` lives on the unsafe declaration, never on the Sendable conformance.**

#### Worked applications of the rule

**Example 1** — value type with all-Sendable members (the easy case):

```swift
public struct Coordinate: Sendable {           // ← compiler-synthesized
  public var latitude: Double
  public var longitude: Double
}
```

**Example 2** — CoW value type whose buffer is reference-shared internally
(matches `Array`, `Deque`, `OrderedDictionary`, `RigidArray`):

```swift
public struct MyDeque<Element: ~Copyable>: ~Copyable {
  // internal storage uses a reference-typed buffer
}

extension MyDeque: @unchecked Sendable
where Element: Sendable & ~Copyable {}         // ← no @unsafe
```

**Example 3** — synchronization-backed reference type (matches `Mutex`,
`Atomic`, `NIOLock`-protected types):

```swift
public struct AtomicCounter: ~Copyable {
  @usableFromInline
  let storage: UnsafeMutablePointer<Builtin.Word>   // unsafe storage
}

extension AtomicCounter: @unchecked Sendable {}     // ← no @unsafe on conformance
```

**Example 4** — type whose `@unsafe`-ness is fundamental to its identity
(matches `UnsafeSleepStateToken`). Both attributes are needed *at different
positions*:

```swift
@unsafe                                           // ← memory-safety claim on TYPE
struct UnsafeWrapper: @unchecked Sendable {       // ← thread-safety claim on CONFORMANCE
  let pointer: UnsafeMutablePointer<UInt>
}
```

**Example 5** — safe-by-API wrapper of unsafe storage (matches `UniqueBox`):

```swift
@safe                                            // ← attests memory safety
public struct SafeWrapper<Value: ~Copyable>: ~Copyable {
  @usableFromInline
  let pointer: UnsafeMutablePointer<Value>
}

extension SafeWrapper: @unchecked Sendable      // ← attests thread safety
where Value: Sendable & ~Copyable {}
```

This is the **most common shape for an institute primitive that wraps
unsafe storage**: `@safe` on the struct (the API discipline is correct)
plus `@unchecked Sendable` on the conformance (the compiler can't see
through the unsafe pointer to verify it).

**Example 6** — annotating individual methods that escape safety:

```swift
extension MyBuffer {
  @unsafe                                       // ← lives on the METHOD
  public func withUnsafePointer<R>(
    _ body: (UnsafePointer<Element>) -> R
  ) -> R { ... }
}

// Elsewhere the Sendable conformance remains @unchecked Sendable, untouched:
extension MyBuffer: @unchecked Sendable where Element: Sendable {}
```

### Ambiguities surfaced (policy-decision points the Institute will need to resolve)

1. **SE-0458's `SerialExecutor` Future Direction.** The proposal *contemplates*
   marking `SerialExecutor` conformances `@unsafe` (or its alternative
   `@safe(unchecked)`-style attestation) because executor misimplementation
   *does* corrupt memory safety through actor isolation. This is a narrow,
   identified case in the proposal's future-work section; it has not landed.
   If and when it does, the rule above gains an exception for the specific
   protocol(s) that opt into "memory-safety-depends-on-concurrency-semantics."
   Until landed, the rule stands.
2. **`@safe(unchecked)`-style attestation.** SE-0458 rejected its initial
   `@safe(unchecked)` proposal; the language currently has no first-class
   attribute that says "the *concurrency* checker should be bypassed *with*
   an explicit attestation marker." `@unchecked Sendable` is the de facto
   audit point. The Institute may want to layer doc-comment / audit-table
   discipline on top of `@unchecked Sendable` (capturing the four-family
   category, the synchronization mechanism, etc.); that layer is
   complementary to the language and does not require `@unsafe`.
3. **Pre-SE-0458 colloquial usage.** Some libraries (e.g., NIO's NIOSendable
   doc-comment) used "@unsafe Sendable" as casual shorthand for "unchecked
   Sendable" before SE-0458 standardized the vocabulary. This is *not*
   precedent for pairing the attributes; it is pre-standard naming. Audits
   should not treat such comments as endorsement of pairing.

## References

### Swift Evolution proposals

- [SE-0302: `Sendable` and `@Sendable` closures][se0302] — canonical Sendable / `@unchecked Sendable` definition.
- [SE-0414: Region-Based Isolation][se0414] — names `@unchecked Sendable` as an unsafe escape hatch that region analysis aims to reduce.
- [SE-0446: Non-Escapable Types][se0446] — referenced by SE-0458 as the type-system tool that would let `SerialExecutor` become safe.
- [SE-0447: Span — Safe Access to Contiguous Storage][se0447] — explicit rationale for `Span: Sendable` and `RawSpan: Sendable` without `@unsafe`.
- [SE-0458: Strict Memory Safety][se0458] — canonical `@safe` / `@unsafe` / unsafe-conformance definition; explicitly groups `@unchecked Sendable` with `nonisolated(unsafe)` etc. as *peer* mechanisms.
- [SE-0470: Isolated Conformances][se0470] — alternative to `@unchecked Sendable` for actor-isolated types.

### Swift standard library (in-tree)

- [`stdlib/public/core/Sendable.swift`][sendable.swift] — `Sendable` and `SendableMetatype` doc comments.
- [`stdlib/public/core/Array.swift:2262`][array-2262] — conditional CoW `@unchecked Sendable`.
- [`stdlib/public/core/Dictionary.swift:2306`][dictionary-2306] — unconditional `@unchecked Sendable` (Foundation-bridging case).
- [`stdlib/public/core/Span/Span.swift:91`][span-91] — `Span` `@unchecked Sendable` while `Span.init(_unchecked:count:)` is `@unsafe` — the same type carrying the two attributes on *different* declarations.
- [`stdlib/public/core/Span/MutableRawSpan.swift:59`][mutablerawspan-59] — raw-pointer-holding type, `@unchecked Sendable`, not paired with `@unsafe`.
- [`stdlib/public/Synchronization/Mutex/Mutex.swift:56`][mutex-56] — synchronization-backed canonical pattern.
- [`stdlib/public/Synchronization/Atomics/Atomic.swift:59`][atomic-59] — atomic-backed canonical pattern.

### Third-party libraries

- [`apple/swift-collections` — `Sources/DequeModule/Deque.swift:107`][deque-107]
- [`apple/swift-collections` — `Sources/OrderedCollections/OrderedDictionary/OrderedDictionary+Sendable.swift:12`][orderdict-12]
- [`apple/swift-nio` — `Sources/NIOPosix/SelectableEventLoop.swift:94`][nio-selev-94]
- [`apple/swift-nio` — `Sources/NIOPosix/Thread.swift:289`][nio-thread-289]
- [`apple/swift-async-algorithms` — `Sources/AsyncAlgorithms/UnsafeTransfer.swift:13`][asyncalg-transfer-13]

### External

- [Rust RFC #2585: `unsafe` blocks in `unsafe fn`][rust-2585] — cited by SE-0458 as the precedent for non-propagating `unsafe`.

### Recency-verification primary sources (v1.1.0)

- [Swift Memory Safety Vision][vision] — lists `@unchecked Sendable` as a peer of `nonisolated(unsafe)`, `unowned(unsafe)`, etc.; flagged by strict-memory-safety at consumer sites, not by annotating the conformance with `@unsafe`.
- [`stdlib/public/core/UniqueBox.swift`][uniquebox] — current state (`@safe` struct + bare `@unchecked Sendable` conformance, line 42).
- [Commit `0fca1189e29` (2026-01-08)][sw-0fca118] — initial `Box: Sendable`.
- [Commit `752de71c6eb` (2026-02-10)][sw-752de71] — *Mark the sendable conformance on Unique as `@unchecked`*. Fix-it diff: added exactly `@unchecked`; no `@unsafe`.
- [Commit `f17c3e8c967` (2026-01-26)][sw-f17c3e8] — changelog entry on the new `@unsafe` annotations: corrections are on *member declarations*, not conformances.
- [Commit `fca347bd7f7` (2026-04-17)][sw-fca347b] — *Replace `@safe` with `@unsafe` in ManagedBuffer's `withUnsafe...` methods* — methods, not conformances.
- [Commit `369b9cced0d` (2026-04-17)][sw-369b9cc] — *Re-mark OutputSpan's `withUnsafeMutableBufferPointer` as `@unsafe`* — method.
- [`test/Unsafe/unsafe_concurrency.swift`][test-unsafe-conc] — official compiler test for strict memory safety: `class C: @unchecked Sendable { ... }` is `okay`.
- [`test/Unsafe/unsafe-suppression.swift`][test-unsafe-supp] — official compiler test for the three `@unsafe` syntactic positions; lines 77-83 show the canonical "`@unsafe` on type/extension + `@unchecked` on conformance" pattern.
- [`stdlib/public/Concurrency/TaskSleep.swift`][taskleep] — `@unsafe struct UnsafeSleepStateToken: @unchecked Sendable` — both attributes on the same type at different positions.
- [`apple/swift-collections` `Sources/BasicContainers/RigidArray/RigidArray.swift`][rigidarray] — post-SE-0527 type on `main`: bare `@unchecked Sendable` on conformance, `@unsafe` on individual methods.
- [SE-0517: UniqueBox][se0517] — proposes plain `Sendable`; implementation strengthened to `@unchecked Sendable` (no `@unsafe`).
- [SE-0527: RigidArray and UniqueArray][se0527] — most recent type-introducing proposal in the data-structures domain; `Sendable` / `@unchecked Sendable` only, no `@unsafe` pairing.
- [SE-0518: `~Sendable`][se0518] — most recent Sendable-adjacent proposal; introduces explicit suppression, no `@unsafe` interaction.

[se0302]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md
[se0414]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md
[se0446]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
[se0447]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
[se0458]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md
[se0470]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md
[sendable.swift]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Sendable.swift
[array-2075]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Array.swift#L2075
[array-2262]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Array.swift#L2262
[dictionary-2306]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Dictionary.swift#L2306
[span-91]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Span/Span.swift#L91
[mutablerawspan-59]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Span/MutableRawSpan.swift#L59
[mutex-56]: https://github.com/swiftlang/swift/blob/main/stdlib/public/Synchronization/Mutex/Mutex.swift#L56
[atomic-59]: https://github.com/swiftlang/swift/blob/main/stdlib/public/Synchronization/Atomics/Atomic.swift#L59
[deque-107]: https://github.com/apple/swift-collections/blob/main/Sources/DequeModule/Deque.swift#L107
[orderdict-12]: https://github.com/apple/swift-collections/blob/main/Sources/OrderedCollections/OrderedDictionary/OrderedDictionary%2BSendable.swift#L12
[nio-selev-94]: https://github.com/apple/swift-nio/blob/main/Sources/NIOPosix/SelectableEventLoop.swift#L94
[nio-thread-289]: https://github.com/apple/swift-nio/blob/main/Sources/NIOPosix/Thread.swift#L289
[asyncalg-transfer-13]: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/UnsafeTransfer.swift#L13
[rust-2585]: https://rust-lang.github.io/rfcs/2585-unsafe-block-in-unsafe-fn.html
[se0517]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0517-uniquebox.md
[se0518]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0518-tilde-sendable.md
[se0527]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md
[vision]: https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md
[uniquebox]: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/UniqueBox.swift
[taskleep]: https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/TaskSleep.swift
[test-unsafe-conc]: https://github.com/swiftlang/swift/blob/main/test/Unsafe/unsafe_concurrency.swift
[test-unsafe-supp]: https://github.com/swiftlang/swift/blob/main/test/Unsafe/unsafe-suppression.swift
[rigidarray]: https://github.com/apple/swift-collections/blob/main/Sources/BasicContainers/RigidArray/RigidArray.swift
[sw-f17c3e8]: https://github.com/swiftlang/swift/commit/f17c3e8c967a21255a89c1b2e8044b7b04766a7d
[sw-fca347b]: https://github.com/swiftlang/swift/commit/fca347bd7f7321f36d992e148a64a99a2cf46445
[sw-369b9cc]: https://github.com/swiftlang/swift/commit/369b9cced0d4eb9a4789059c1247944abb30b684
[sw-8410e3e]: https://github.com/swiftlang/swift/commit/8410e3e6a9a4296df22e247b507e535c316022f8
[sw-6de92bc]: https://github.com/swiftlang/swift/commit/6de92bc64d685231a61836ef4277a71025f2eb4f
[sw-0fca118]: https://github.com/swiftlang/swift/commit/0fca1189e29ec591a7a639fd5261c79eaa288f32
[sw-3c6dd46]: https://github.com/swiftlang/swift/commit/3c6dd46953c6d761104e89af712fcd7c6fba4da0
[sw-752de71]: https://github.com/swiftlang/swift/commit/752de71c6eb2bf3771f2d31005f7cd413b268f86
[sw-606ed25]: https://github.com/swiftlang/swift/commit/606ed251ad3efc07738718adf4ac013bc4850dd5
