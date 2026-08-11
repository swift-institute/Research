# Element ~Escapable Relaxation Blocked by `Swift.Span<Element>`

<!--
---
version: 1.0.0
last_updated: 2026-05-21
status: DEFERRED
tier: 2
scope: cross-package
---
-->

## Context

The revision pitch [_Iterable_ (formerly _BorrowingSequence_)] proposes
broadening the iterator protocol's `Element` associated type from
`~Copyable` (the prior `BorrowingSequence` pitch) to `~Copyable, ~Escapable`.
The pitch's stated rationale, quoted from its "Changes from Original Version"
section:

> Nonescapable elements: `Element` is now constrained to `~Copyable & ~Escapable`,
> instead of just `~Copyable`.

This raises the question for our package: should our
`Sequence.Protocol.Element` and `Sequence.Iterator.Protocol.Element` be
relaxed similarly? The institute equivalents currently constrain `Element`
to `~Copyable` only — matching the prior pitch, not the revision.

[_Iterable_ (formerly _BorrowingSequence_)]: https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834

## Question

Can we relax `associatedtype Element: ~Copyable` to
`~Copyable, ~Escapable` on `Sequence.Protocol`, `Sequence.Borrowing.Protocol`,
and `Sequence.Iterator.Protocol` today?

## Analysis

### The blocker — `Swift.Span<Element>` requires Element: Escapable

Our `Sequence.Iterator.Protocol`'s sole requirement is:

```swift
@_lifetime(&self)
mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>
```

The return type is `Swift.Span<Element>` — using the standard library's
`Span`. Its current signature (verified against `swiftlang/swift` source
at commit `e578b3a` from 2026-05-05, file
`stdlib/public/core/Span/Span.swift:29`):

```swift
public struct Span<Element: ~Copyable>: ~Escapable, Copyable, BitwiseCopyable
```

`where Element : ~Copyable` only — no `~Escapable` suppression on the
generic parameter. `Span`'s Element MUST be `Escapable`.

The same constraint holds across the Span family (verified against the
same commit):

| Type | Element constraint | File:line |
|---|---|---|
| `Swift.Span<Element>` | `Element: ~Copyable` (Escapable required) | `stdlib/public/core/Span/Span.swift:29` |
| `Swift.MutableSpan<Element>` | `Element: ~Copyable` (Escapable required) | `stdlib/public/core/Span/MutableSpan.swift:23` |
| `Swift.OutputSpan<Element>` | `Element: ~Copyable` (Escapable required) | `stdlib/public/core/Span/OutputSpan.swift:25` |
| `Swift.RawSpan` | (no Element parameter) | `stdlib/public/core/Span/RawSpan.swift:29` |

If we declare `associatedtype Element: ~Copyable, ~Escapable`, then
`Swift.Span<Element>` in the `nextSpan` signature fails type-checking:
the `Element` we're substituting may be `~Escapable`, but `Span`'s
parameter requires `Escapable`.

### Empirical verification

#### Reproduction on Swift 6.3.2 (default toolchain)

In `swift-sequence-primitives`, applying the relaxation to all three
core protocols and rebuilding:

```text
$ swift build
.../Sequence.Iterator.Protocol.swift:129:65:
  error: type 'Self.Element' does not conform to protocol 'Escapable'
        mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>
                                                                ^
```

Cascading errors followed in `Sequence.Span+Property.Inout.swift` and in
the default `next() -> Element?` extension. The relaxation cannot
compile.

#### Reproduction on Swift 6.5-dev (`swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`)

Same outcome. Minimal reproduction in `/tmp/sptest/Sources/sptest/main.swift`:

```swift
public protocol IterP<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable, ~Escapable
    
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Swift.Span<Element>
}
```

Build via direct toolchain invocation
(`/Users/coen/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a.xctoolchain/usr/bin/swift build`):

```text
.../sptest/main.swift:5:56:
  error: type 'Self.Element' does not conform to protocol 'Escapable'
```

#### `Swift.SpanIterator` in 6.5-dev does NOT help

The 6.5-dev snapshot's stdlib already ships
`Swift.BorrowingIteratorProtocol` and `Swift.SpanIterator` (the pitch's
own protocol family, landed early). Quoted from the toolchain's
`/usr/lib/swift/macosx/Swift.swiftmodule/arm64-apple-macos.private.swiftinterface`:

```swift
@available(anyAppleOS 9999, *)
public protocol BorrowingIteratorProtocol<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable             // ← ~Copyable only
    
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Swift.Int) -> Swift.Span<Self.Element>
}

public struct SpanIterator<Element>: Swift.BorrowingIteratorProtocol, ~Swift.Copyable, ~Swift.Escapable
    where Element: ~Copyable                       // ← ~Copyable only
```

**The pitch text says `Element: ~Copyable, ~Escapable`. The actually-shipped
stdlib protocol — the pitch's own implementation — uses `Element: ~Copyable`
only.** Stdlib's implementation backed off from the pitch's broader claim,
likely because of this same `Swift.Span<Element>` constraint.

### What relaxing would require

The relaxation requires either:

1. **Upstream relaxation of `Swift.Span<Element>` to accept `Element: ~Escapable`.**
   Hasn't shipped; not visible in 6.5-dev source or swiftinterface. The
   pitch's own concrete `extension Span: Iterable` conformance reverts
   to `Element: ~Copyable` for the same reason — quoted from the pitch:
   `extension Span: Iterable where Self: ~Copyable & ~Escapable, Element: ~Copyable`.

2. **A different return type that accepts `Element: ~Escapable`.**
   Would mean diverging from `Swift.Span<Element>` as the lending
   substrate. Architecturally significant change; impacts every
   conformer that currently returns `Swift.Span` (the
   `Swift.Span.Iterator` + `Swift.Span.Iterator.Batch` adapters in
   `Sequence Primitives Standard Library Integration/`, and every
   downstream conformer in `swift-buffer-primitives`,
   `swift-bit-vector-primitives`, `swift-vector-primitives`, etc.). Not
   approached in this analysis.

3. **A protocol declaration that broadens `Element` to `~Copyable, ~Escapable`
   but constrains `nextSpan`'s availability to `where Element: Escapable`.**
   Effectively splits the protocol into "the Element-suppressed declaration"
   and "the requirements only available for Escapable Element." For
   `~Escapable Element` conformers, there'd be no iteration mechanism
   at all (no nextSpan, no closure-based alternative declared). The
   protocol would be conformable but useless for `~Escapable Element`
   types — a hollow generalization. Rejected as a structurally
   incoherent path.

## Outcome

**Status: DEFERRED**

**Decision**: maintain `Element: ~Copyable` on
`Sequence.Protocol`, `Sequence.Borrowing.Protocol`, and
`Sequence.Iterator.Protocol`. Do NOT relax to `~Copyable, ~Escapable`.

**Rationale**:

- The relaxation cannot compile against any currently-released or
  currently-nightly Swift toolchain (6.3.2 stable through 6.5-dev
  May 12 nightly).
- The pitch's own concrete conformances and stdlib's actually-shipped
  `BorrowingIteratorProtocol` both back off to `Element: ~Copyable`,
  matching what we already have.
- Path 2 (custom span type) is architecturally significant and not
  motivated by any concrete consumer today.
- Path 3 (broadened declaration + conditional `nextSpan`) is incoherent.

**Unblock condition**: `Swift.Span<Element>` accepts `Element: ~Escapable`
upstream (`stdlib/public/core/Span/Span.swift` adds `~Escapable` to the
`Element` constraint), AND a corresponding compiler-feature gate or
language-mode flag becomes available. At that point: re-apply the
relaxation to all three core protocols + verify the lazy wrappers and
default extensions still compose.

**Tripwire**: the CI matrix's `linux-nightly` job (now relabeled to
"Swift main nightly" — see `swift-institute/.github` commit `68a1006`)
runs `swiftlang/swift:nightly-main-jammy` which floats with main. When
`Swift.Span<Element: ~Escapable>` lands, the relaxation experiment can
be re-run against that nightly. No additional CI work required to catch
the day the unblock condition fires.

**Doc comment encoding in code**: each of the three protocols carries a
doc-comment annotation:

```swift
/// Supports move-only elements (file descriptors, unique handles) via
/// `~Copyable`. `~Escapable` relaxation is BLOCKED until
/// `Swift.Span<Element>` accepts `Element: ~Escapable` upstream
/// (Swift 6.3.1 requires `Element: Escapable`).
associatedtype Element: ~Copyable
```

(see `Sequence.Protocol.swift:94`, `Sequence.Iterator.Protocol.swift:114`,
`Sequence.Borrowing.Protocol.swift:48`)

## References

- [Revision pitch: _Iterable_ (formerly _BorrowingSequence_)](https://forums.swift.org/t/revision-pitch-iterable-formerly-borrowingsequence/86834) — Swift Forums
- `swiftlang/swift` source at commit `e578b3a` (2026-05-05),
  `stdlib/public/core/Span/{Span,MutableSpan,OutputSpan,RawSpan}.swift`
- `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a` toolchain, `Swift.swiftmodule/arm64-apple-macos.private.swiftinterface`
  (the actually-shipped `BorrowingIteratorProtocol` + `SpanIterator`)
- Companion design doc: `count-direct-vs-fluent-and-hint-namespace.md`
  (the design-level adoption of pitch-aligned customization points where
  the constraint *doesn't* block us)
- Companion comparison: `iterable-revision-pitch-comparison.md`
  (full pitch ↔ sequence-primitives axis comparison)
