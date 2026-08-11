# Default Generic Parameters — Swift Status

<!--
---
version: 1.0.0
last_updated: 2026-03-05
status: DEFERRED
tier: 1
---
-->

## Context

The unified `Optic.Prism<Whole, Part, Failure>` design (see
`swift-coder-primitives/Research/optics-streaming-io-bridge.md`) uses a
`PrismOf<W, P>` typealias to recover two-parameter ergonomics. Native default
generic parameters (`struct Prism<W, P, F: Error = Extraction.Error>`) would
eliminate this workaround. This document surveys whether Swift has progressed
toward that feature.

### Trigger

[RES-001] Architecture choice — determining whether the `PrismOf` typealias
is a permanent design decision or a temporary workaround pending language
evolution.

## Question

What is the current status of default generic type parameters in Swift, and
should the unified Prism design depend on this feature arriving?

## Analysis

### Generics Manifesto

Default generic arguments are listed in `swiftlang/swift/docs/GenericsManifesto.md`
(lines 240–252) as a "Minor extension":

```swift
public final class Promise<Value, Reason=Error> { ... }

var p1: Promise<Int> = ...
var p2: Promise<Int, Error> = p1     // okay: same type
```

The manifesto also notes (line 581) that generic argument **labels** "make more
sense if Swift gains default generic arguments."

### Proposal History

| Date | Event | Outcome |
|------|-------|---------|
| Jan 2017 | PR #591 to swift-evolution (Srdan Rasic) | Closed by Doug Gregor, Feb 2017 |
| Feb 2017 | Core Team assessment | "Purely additive, no ABI impact, nontrivial feature for a relatively small audience." Could be staged later. |
| Mar 2018 | Draft pitch by Dmitry Lobanov | Slava Pestov noted ABI implications for defaults. Never reached SE number. |
| Feb 2020 | Forum request | Workarounds discussed. No proposal activity. |
| Nov 2021 | Forum discussion (David Roman) | SE-0347 noted as partial solution for functions. No type-level progress. |
| Mar 2024 | Most recent forum thread | No solution. Workaround: method overloading. |
| 2025–2026 | No forum threads, no pitches, no roadmap mention | — |

**No SE number has ever been assigned.** The feature has never progressed past
informal discussion.

### SE-0347 (Related but Distinct)

SE-0347 "Type inference from default expressions" was accepted and shipped in
Swift 5.7. It allows inferring generic parameters from default **value**
expressions at function call sites:

```swift
func compute<C: Collection>(_ values: C = [0, 1, 2]) { ... }
```

This is NOT default generic type parameters on type declarations. SE-0347 does
not help with `struct Prism<W, P, F: Error = Extraction.Error>`.

### Compiler Implementation Status

Searched `/Users/coen/Developer/swiftlang/swift/`:

| Area | Finding |
|------|---------|
| `lib/Sema/`, `lib/AST/`, `lib/Parse/` | No implementation of default generic type parameters |
| `include/swift/AST/Decl.h` | `DefaultTypeRequest` exists for **associated type** defaults, not generic parameter defaults |
| `test/`, `validation-test/` | No test files for `<T = SomeType>` syntax |
| Recent commits (2023–2026) | No commits implementing this feature |
| C++ interop | Defaulted C++ template parameters are handled, but not exposed as Swift syntax |

### Workaround Assessment

| Workaround | Applicability | Limitation |
|------------|--------------|------------|
| **Typealias** (`PrismOf`) | Excellent for our use case | Consumer must know the alias exists; generic type shows in diagnostics |
| **Overloaded inits** | Functions only | Code duplication; not applicable to type declarations |
| **`Never` sentinel** | Works since `Never: Error` | Semantically different from "default"; doesn't generalize |
| **SE-0347 inference** | Function parameters only | Not type-level |

## Outcome

**Status**: DEFERRED

**Finding**: Default generic type parameters have no implementation, no active
proposal, and no visible roadmap presence in Swift through 6.2. The last
meaningful forum activity was March 2024 (a question, not a pitch). The Core
Team's 2017 assessment — "nontrivial feature for a relatively small audience" —
appears to remain the governing view.

**Implications for unified Prism**:

1. `PrismOf<W, P>` is the **permanent** design, not a temporary workaround.
   Design accordingly — documentation, naming, and API surface should treat the
   typealias as first-class.
2. If default generics ever ship, `PrismOf` remains valid (typealiases are
   stable API). The migration would be: add `= Extraction.Error` to the generic
   parameter and keep `PrismOf` as a convenience alias.
3. No design decisions should be deferred waiting for this feature.

## References

- `swiftlang/swift/docs/GenericsManifesto.md` (lines 240–252, 581)
- [PR #591: Default Generic Arguments (closed Feb 2017)](https://github.com/apple/swift-evolution/pull/591)
- [SE-0347: Type inference from default expressions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0347-type-inference-from-default-exprs.md)
- [Default Generic Arguments — Forums (2017)](https://forums.swift.org/t/default-generic-arguments/4960)
- [Draft: Default values for generic parameters (2018)](https://forums.swift.org/t/draft-allow-default-value-for-parameters-in-generic-clause/11200)
- [Providing a default type for a generic API (2024)](https://forums.swift.org/t/providing-a-default-type-for-a-generic-api/70927)
- `swift-coder-primitives/Research/optics-streaming-io-bridge.md` (v1.1.0)
- `swift-optic-primitives/Experiments/unified-throwing-prism/` (CONFIRMED)
