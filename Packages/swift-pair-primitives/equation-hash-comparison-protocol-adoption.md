# Equation / Hash / Comparison Protocol Adoption

<!--
---
version: 1.1.0
last_updated: 2026-05-08
status: DECISION
tier: 1
scope: per-package
applies_to: [swift-pair-primitives]

## Changelog
- v1.2.0 (2026-05-08): Corrected shape after Phase 0 release-readiness
  empirical contradiction. Hybrid: institute conformances are
  **unconditional**; stdlib `Equatable` / `Hashable` / `Comparable`
  conformances are gated by `#if swift(<6.4)`. Verification:
  (a) **Swift 6.3.1** without the `#if swift(<6.4)` stdlib block —
  `Pair<Int,Int>` does NOT satisfy stdlib `Equatable`/`Hashable`/`Comparable`
  generic constraints (`func foo<T: Equatable>(_:)` rejects Pair); the
  institute conformance to a separate fork protocol is insufficient for
  stdlib interop on 6.3. (b) **Swift 6.4-dev** with both stdlib AND
  institute conformances unconditional — Swift rejects with `conflicting
  conformance of 'Pair<First, Second>' to protocol 'Comparable'; there
  cannot be more than one conformance, even with different conditional
  bounds`. The empirically-correct shape: institute always; stdlib under
  `#if swift(<6.4)` only — on 6.4+ the institute typealias IS the stdlib
  conformance.
- v1.1.0 (2026-05-08, RETRACTED): Claimed both blocks unnecessary;
  empirically refuted by 6.3.1 stdlib-generic-constraint failure +
  6.4-dev duplicate-conformance error. The "overlapping-but-distinct"
  claim does NOT hold for Pair under Swift's actual conformance-resolution
  rules — `where First: Equatable` and `where First: Equatable & ~Copyable`
  are treated as conflicting conformances, not distinct, on Swift 6.4+.
- v1.0.0 (2026-05-08): Initial DECISION with dual `#if compiler(>=6.4)`
  + `#if swift(<6.4)` blocks. Subsequent v1.2.0 simplified by dropping
  the `#if compiler(>=6.4)` branch since the institute conformance covers
  6.4+ via typealias; only the `#if swift(<6.4)` stdlib branch remains.
---
-->

## Context

`Pair<First, Second>: ~Copyable` previously declared its `Equatable` and
`Hashable` conformances via a `#if compiler(>=6.4)` gate — under Swift 6.4+
the conformances admit `~Copyable` components per SE-0499; under Swift 6.3
they collapse to Copyable-only (the components must be `Copyable` because
stdlib `Equatable`/`Hashable` did not yet support `~Copyable` on 6.3). Pair
was not previously `Comparable`.

The swift-primitives ecosystem already provides the `borrowing`-parameter
fork protocols `Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol`
(`swift-equation-primitives`, `swift-hash-primitives`,
`swift-comparison-primitives`) precisely to admit `~Copyable` conformers on
Swift 6.3. On Swift 6.4+, each fork is a typealias to its stdlib counterpart
per `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md`
(v1.3.0, RECOMMENDATION) — adopting the fork is forward-compatible with
the stdlib path.

## Question

Should `Pair` adopt the fork protocols, and if so, what does the dual-mode
conformance shape look like?

## Decision

**Adopt** `Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol`
unconditionally with `& ~Copyable` constraint shape and
`@_disfavoredOverload` borrowing impls. Drop the prior `#if compiler(>=6.4)`
stdlib block AND the prior `#if swift(<6.4)` institute wrapper. The
institute protocols cover both Swift 6.3 (fork) and Swift 6.4+ (typealias to
stdlib) without compiler guards.

## Conformance shape

Hybrid: institute conformances unconditional, stdlib conformances gated
under `#if swift(<6.4)`. On Swift 6.4+ the institute typealias IS the
stdlib conformance (declaring both would conflict per Swift's rule
"there cannot be more than one conformance, even with different
conditional bounds"). On Swift 6.3 the institute fork protocol is
distinct from stdlib `Equatable`/`Hashable`/`Comparable`, so an
additional stdlib extension is needed for `Pair<Copyable, Copyable>`
to satisfy stdlib generic constraints (`func foo<T: Equatable>(_:)`
etc.).

```swift
// Stdlib Equatable / Hashable / Comparable — Swift 6.3 only.
// On Swift 6.4+ the institute typealias covers these; declaring them
// here would be a duplicate conformance.
#if swift(<6.4)
    extension Pair: Equatable where First: Equatable, Second: Equatable {}
    extension Pair: Hashable where First: Hashable, Second: Hashable {}
    extension Pair: Comparable where First: Comparable, Second: Comparable {
        @inlinable
        public static func < (lhs: Pair, rhs: Pair) -> Bool {
            if lhs.first < rhs.first { return true }
            if rhs.first < lhs.first { return false }
            return lhs.second < rhs.second
        }
    }
#endif

// Institute Equation.Protocol / Hash.Protocol / Comparison.Protocol — always.
// On Swift 6.4+ each is a typealias to its stdlib counterpart per SE-0499,
// so this extension IS the stdlib conformance there. On Swift 6.3 these
// are the borrowing-parameter forks that admit ~Copyable conformers.
extension Pair: Equation.`Protocol`
where First: Equation.`Protocol` & ~Copyable, Second: Equation.`Protocol` & ~Copyable {
    @inlinable
    @_disfavoredOverload
    public static func == (lhs: borrowing Pair, rhs: borrowing Pair) -> Bool {
        lhs.first == rhs.first && lhs.second == rhs.second
    }
}

extension Pair: Hash.`Protocol`
where First: Hash.`Protocol` & ~Copyable, Second: Hash.`Protocol` & ~Copyable {
    @inlinable
    @_disfavoredOverload
    public borrowing func hash(into hasher: inout Hasher) {
        first.hash(into: &hasher)
        second.hash(into: &hasher)
    }
}

extension Pair: Comparison.`Protocol`
where First: Comparison.`Protocol` & ~Copyable, Second: Comparison.`Protocol` & ~Copyable {
    @inlinable
    @_disfavoredOverload
    public static func < (lhs: borrowing Pair, rhs: borrowing Pair) -> Bool {
        if lhs.first < rhs.first { return true }
        if rhs.first < lhs.first { return false }
        return lhs.second < rhs.second
    }
}
```

Empirically verified on:
- Swift 6.3.1 (Apple swiftlang-6.3.1.1.2): clean build, 30 tests pass,
  `Pair<Int,Int>` satisfies stdlib `Equatable`/`Hashable`/`Comparable`
  generic constraints.
- Swift 6.4-dev DEVELOPMENT-SNAPSHOT-2026-03-16-a: clean Embedded build
  via `TOOLCHAINS=org.swift.64202603161a swift build -Xswiftc
  -enable-experimental-feature -Xswiftc Embedded`.

## Rationale

1. **Removes the `#if compiler(>=6.4)` gating from the public conformance** —
   `~Copyable` Pairs can already participate in equality / hashing /
   comparison on Swift 6.3 via the fork protocols, without waiting for
   Swift 6.4 GA in the ecosystem.
2. **Adds `Comparable`** — lexicographic ordering over `(first, second)`
   was previously absent. Adoption gives the natural ordering for free
   wherever components are ordered.
3. **Forward-compatible with SE-0499** — once the ecosystem moves to Swift 6.4
   minimum and `swift-equation-primitives` retires per its own DECISION path,
   the `#if swift(<6.4)` block becomes dead code and can be removed
   mechanically without changing call sites: `Equation.Protocol === Equatable`
   on Swift 6.4+ via the typealias.
4. **`~Copyable`-aware components conform via `borrowing` parameters** —
   matches the canonical pattern from `Equation.Protocol+Tagged.swift`:
   `static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool`.
5. **`@_exported public import`** — consumers of Pair don't need to manually
   import the three primitives packages even when their own types conform to
   the fork protocols.

## Migration cost

Zero downstream call sites affected. Pair gains capabilities (Comparable,
~Copyable equality on Swift 6.3); existing call sites using stdlib
`Pair: Equatable` / `Hashable` continue to work unchanged. Verified: zero
hits across symmetry / algebra / finite / region-primitives for `Equation` /
`Hash.Protocol` / `Comparison.Protocol` / `Hash.Value` (no naming collisions
from the new `@_exported` re-exports).

## References

- `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md`
  v1.3.0 — ecosystem-wide RECOMMENDATION on the fork protocols' future
- `swift-equation-primitives/Sources/Equation Primitives/Equation.Protocol+Tagged.swift` —
  canonical adopter pattern (`@_disfavoredOverload` + `borrowing` impl + `#if swift(<6.4)`)
- `swift-equation-primitives/Sources/Equation Primitives Core/Equation.Protocol.swift`
  — protocol declaration with SE-0499 dual-mode shape
- `swift-hash-primitives/Sources/Hash Primitives Core/Hash.Protocol.swift`
- `swift-comparison-primitives/Sources/Comparison Primitives Core/Comparison.Protocol.swift`
- SE-0499 — Support `~Copyable` and `~Escapable` in Standard Library Protocols (Implemented Swift 6.4)
