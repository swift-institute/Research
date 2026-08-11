# Pure-Language Ownership Feasibility for the Property Type Family

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: DECISION
---
-->

**Coen ten Thije Boonkkamp**
Swift Institute
April 2026

---

## Abstract

`swift-property-primitives` ships four user-facing type families —
`Property<Tag, Base>`, `Property.Typed<Element>`, `Property.Consuming`, and
the `Property.View` family (plus `.View.Read`) — whose original motivation
was to express ownership / phantom-tag / borrow-vs-consume contracts that
the Swift language could not say directly. Swift 6.3 has since grown
`consume` / `copy` expressions, `consuming` / `borrowing` parameter
conventions, `~Copyable` / `~Escapable`, `@_lifetime`, and the
Lifetimes / LifetimeDependence experimental features that the shipped
package already enables ecosystem-wide. This document evaluates whether
each family can now be re-expressed using only language-level constructs
at equivalent ergonomics, based on four executable experiments.

The verdict is **RETAIN with refined framing**: pure Swift 6.3 language
vocabulary has the mechanism to reproduce every observable behaviour of
every family, at equivalent call-site ergonomics, PER NAMESPACE. What the
types provide is not a missing language capability — it is **amortization
of a per-namespace boilerplate template** across the ecosystem, plus
**a centralised anchor point** for the compiler-bug workarounds the
pattern has absorbed historically. The call-site proposal
`container.forEach { process(consume $0) }` advanced in the handoff is
REFUTED on its own terms: `consume $0` consumes the closure parameter,
not the container, and the compiler itself emits a no-op warning for
Copyable elements.

---

## Context

The parent conversation just closed a Sendable audit that rejected Option
C (value-type `Property.Consuming.State`) and adopted Option A
(conditional `@unchecked Sendable` on the class-based state) because of
a release-mode SIL crash. The adjacent question is whether the custom
wrappers are still *conceptually* earning their keep now that the
language has grown richer. The handoff proposed the worked example

```swift
// Current:  container.forEach.consuming { process($0) }
// Pure:     container.forEach { process(consume $0) }
```

as a candidate one-for-one replacement. This document takes that
seriously, enumerates the other three families, and tests each
replacement proposal against a minimal reproducer.

---

## Question

Can each user-facing pattern of the `Property<Tag, Base>` family be
re-expressed using only language-level constructs at equivalent
ergonomics?

- **Pattern A** — `Property<Tag, Base>` (owned, method-case):
  `container.push.back(_:)` via phantom-tag extension.
- **Pattern B** — `Property.Typed<Element>` (owned, property-case):
  `container.peek.back` returning `Element?` where `Element` must be
  in scope for a `var` extension.
- **Pattern C** — `Property.Consuming` (state-tracked):
  `container.forEach { }` borrows; `container.forEach.consuming { }`
  empties the container (but keeps the binding).
- **Pattern D** — `Property.View` family (pointer-indirection on
  `~Copyable` bases): `box.inspect.current`, `slice.access.resize(to:)`.

---

## Method

Four minimal executable Swift 6.3.1 experiments, one per family, each
in `Experiments/language-semantic-{…}-replacement/`. Each experiment
declares multiple variants (V1, V2, …) corresponding to candidate
pure-language replacements, and records observable behaviour under
`swift run`. Headers document hypothesis, compiler output (warnings and
errors), and a per-variant verdict. The Lifetimes / LifetimeDependence
experimental features are enabled on the Property.View experiment to
match the shipped package's ecosystem-wide baseline.

Prior-art consultation per `[HANDOFF-013]`:
`property-type-family.md` v1.0.0 (the founding paper),
`variant-decomposition-rationale.md` v1.0.0 (the 2026-04-20 release
shape), `borrowing-label-drop-rationale.md` v1.0.0,
`property-view-escapable-removal.md` v1.0.0,
`swift-institute/Research/noncopyable-ownership-transfer-patterns.md` v2.0.0,
and the existing Experiments/ corpus (14 packages documenting related
questions).

---

## Analysis

### Pattern A: `Property<Tag, Base>` — owned method-case

**Canonical** (Tests/Support/Container.swift):
```swift
extension Container { var push: Property<Push, Container<Element>> { … } }
extension Property where Tag == Container<Int>.Push, Base == Container<Int> {
    mutating func back(_ element: Int) { self.base.storage.append(element) }
}
container.push.back(42)
```

**Pure-language V1** (Experiments/language-semantic-property-replacement):
per-namespace `PushProxy: ~Copyable` / `PopProxy: ~Copyable` struct, each
carrying its own `_read`/`_modify` on `base` plus the CoW
`_modify`+defer+restore recipe. Call site `container.push.back(42)` is
identical. CONFIRMED in debug.

**Pure-language V2**: flat methods on the container (`pushBack(_:)`,
`popBack()`). Compiles; rejected by `[API-NAME-002]` compound-identifier
ban.

| Criterion | Property<Tag, Base> | Pure V1 (hand-rolled) | Pure V2 (flat methods) |
|-----------|---------------------|-----------------------|------------------------|
| Call-site shape | `container.push.back(42)` | `container.push.back(42)` | `container.pushBack(42)` |
| [API-NAME-002] | Conforms | Conforms | **VIOLATES** |
| Proxy-struct declarations per container | 0 (1 typealias) | N (one per namespace) | 0 |
| CoW `_modify` recipe | Centralised in Property | Duplicated per namespace | N/A (no proxy) |
| Phantom-tag extension selection | `where Tag == …` | Namespace-struct itself selects | Method names collide |

**Finding**: `Property<Tag, Base>` earns its keep as a proxy-struct
factory. The language has the mechanism (`~Copyable` structs with
`_read`/`_modify`), but amortization matters at ecosystem scale.

### Pattern B: `Property.Typed<Element>` — owned property-case

**Canonical**:
```swift
extension Property.Typed where Tag == Container<Int>.Peek, Base == Container<Int>, Element == Int {
    var back: Int? { base.storage.last }
}
container.peek.back  // Int?
```

The motivation is that Swift methods can introduce their own generics
(`func back<E>(…)`) but `var` accessors cannot. `Property.Typed<Element>`
smuggles `Element` into type scope so property extensions can constrain it.

**Pure-language V1**: nest the per-namespace proxy inside the parametric
container (`extension V1Container { struct Peek: ~Copyable { … var back:
Element? … } }`). `Element` reaches `var back` through ordinary lexical
scoping — no generic-parameter introduction on the property is needed.
CONFIRMED.

**Finding**: The "properties cannot introduce generics" limitation is
not circumvented by `Property.Typed` — it is *worked around* by scope.
Pure language replicates the workaround per namespace. Same
amortization ratio as Pattern A.

### Pattern C: `Property.Consuming` — state-tracked

**Canonical**:
```swift
container.forEach { print($0) }              // borrow — container preserved
container.forEach.consuming { process($0) }  // consume — container emptied, binding kept
```

One accessor declaration; the caller's method choice at invocation time
decides whether the `_modify`+defer restores the container.

**Pure-language V1 (the handoff's proposal)**:
```swift
container.forEach { process(consume $0) }
```
**REFUTED**. `consume $0` applies to the closure parameter (one element
at a time), not the container. The Swift 6.3.1 compiler emits a
warning:

```
warning: 'consume' applied to bitwise-copyable type 'Int' has no effect
```

and the container remains fully populated after the loop (observed
`count=3` when the container was initialised with 3 elements).

**Pure-language V2**: two distinct methods on the container — `func
forEach(_:)` (borrow) and `consuming func drain(_:)` (consuming self).
CONFIRMED. But `drain` consumes the whole caller binding, not just its
contents: after `container.drain { … }`, the caller's variable is
invalid. `Property.Consuming` preserves the binding (empty container is
still usable to refill). V2 is a STRICTLY STRONGER consume; it is a
different operation at the source level.

**Pure-language V3**: hand-roll the state machine — reference-type
`V3State` with `_consumed: Bool`, `V3ForEach: ~Copyable` with
`callAsFunction` and `mutating func consuming`, and the
`_read`/`_modify`+defer+restore accessor on the container. CONFIRMED.
This is exactly what `Property.Consuming` packages, reproduced by hand
per namespace.

**Finding**: language ownership annotations are STATIC; the borrow-vs-
consume choice `Property.Consuming` expresses is DYNAMIC. No
annotation-only rewrite reaches the same call-site semantics. V2 works
if stronger consume-the-whole-binding semantics are acceptable;
otherwise the state-machine packaging is load-bearing.

### Pattern D: `Property.View` family — pointer indirection on ~Copyable

**Canonical** (Tests/Support/Box.swift, Slice.swift):
```swift
box.inspect.current            // Property.View.Read borrowing accessor
slice.access.resize(to: 10)    // Property.View mutating accessor
```

The view wraps `UnsafePointer` / `UnsafeMutablePointer` to a `~Copyable`
base; `~Copyable, ~Escapable` on the view + `@_lifetime(borrow base)`
on its init confine the lifetime. Mutating `_read`/`_modify` on the
container yields the view.

**Pure-language V1 (read-only)**: per-namespace `BorrowView: ~Copyable,
~Escapable` with `@_lifetime(borrow base) init(_ base: borrowing Base)`
and a non-mutating `_read` accessor on the base. Call-site identical.
CONFIRMED.

**Pure-language V2 (mutable)**: per-namespace `AccessView: ~Copyable,
~Escapable` wrapping `UnsafeMutablePointer<Base>`, obtained via
`withUnsafeMutablePointer(to: &self)` from a `mutating _read`/`_modify`.
CONFIRMED. Requires the `Lifetimes` experimental feature — both for
`@_lifetime(borrow base)` syntax and to lift the Swift 6.3 rule "a
mutating method cannot return a ~Escapable result". The shipped package
enables the same flag.

**Pure-language V3 (no view)**: single read-only accessor with no
namespace discrimination collapses to a direct computed property on the
`~Copyable` base — no view struct needed. This is the degenerate case
where the whole family is overhead.

**Finding**: every mechanism `Property.View*` uses is pure Swift 6.3
vocabulary (`~Copyable`, `~Escapable`, `@_lifetime`, coroutine accessors,
`withUnsafe{,Mutable}Pointer`). There is NO compile-time capability
Property.View provides that pure language cannot reproduce per
namespace. The amortization is the same ecosystem argument as the
other patterns, plus a centralisation benefit: `Property.View*` is the
single place where compiler bugs that historically affected this shape
were absorbed (the 149-site `@_optimize(none)` workaround restored
through `property-view-escapable-removal.md`, the `borrowing:` label
drop across 19 sites through `borrowing-label-drop-rationale.md`).
Replacing with hand-rolled views spreads that absorption surface to
every consumer.

---

## Cross-cutting observations

### The "pure language" envelope already includes experimental features

The shipped `Property.View*` family and the pure-language V2 both
require `-enable-experimental-feature Lifetimes` to compile. Without
the flag, `@_lifetime(borrow base)` is rejected and the Swift 6.3 rule
"a mutating method cannot return a ~Escapable result" blocks the
`mutating _read`/`_modify` accessors. "Pure language" in the context of
this investigation does not mean "Swift 6.3 without experimental flags"
— it means "the same set of features the shipped package already
depends on." Removing the Property types does NOT get the package off
experimental features; it rewrites each view per-namespace while
keeping the same toolchain requirements.

### Release-mode SIL crash exposure

Two of the four experiments (Property, Property.Typed) hit the same
Swift 6.3.1 SIL CrossModuleOptimization crash
(`forwardToInit: Cannot initialize a nonCopyable type with a guaranteed
value`) in release mode that `Experiments/property-consuming-value-state`
already documents. The shipped `Property<Tag, Base>` sidesteps this
because it lives in a separate library target; single-module executables
containing ~Copyable proxy structs with `_read`/`_modify` coroutines hit
the inliner bug under CMO. A pure-language ecosystem would have to
structure every consumer's proxy in a separate module to avoid this —
effectively rebuilding the current Core-target shape from scratch.

### The handoff's worked example reads but does not replace

```swift
container.forEach { process(consume $0) }
```

is readable Swift and compiles, but the compiler warns it is a no-op
for Copyable elements and the container is unchanged afterward. It is
NOT an equivalent of `container.forEach.consuming { process($0) }`.
Anyone proposing this substitution should expect the compiler's warning
to be the first-line correction.

### What language features WOULD change the verdict

The verdict would flip toward REPLACEABLE if either:

1. **A `borrow` expression form** (parallel to `consume x` and `copy x`)
   let callers request a borrowed view in-expression. Currently absent
   per `borrowing-label-drop-rationale.md` §"No explicit-borrow
   expression form exists at call sites".
2. **Generic computed properties** would remove the motivation for
   `Property.Typed`'s scope-smuggling.
3. **A per-call consuming-mode selector** for methods (e.g., allowing
   the caller to pick between `func` and `consuming func` bindings at
   call time) would replace `Property.Consuming`'s runtime state machine
   with a language-level dispatch.

None of these is on the near-horizon of Swift Evolution.

---

## Per-family verdict

| Family | Verdict | Rationale |
|--------|---------|-----------|
| `Property<Tag, Base>` | **RETAIN** | Pure language replicates per namespace; amortization + release-mode SIL shelter lost on replacement. |
| `Property.Typed<Element>` | **RETAIN** | Same reasoning as Property; Element-in-scope workaround is per-namespace duplication without the type. |
| `Property.Consuming` | **RETAIN** | Handoff's `consume $0` proposal REFUTED. Pure-language V2 (consuming self) is stronger semantics; V3 reproduces the state machine but per namespace. |
| `Property.View` family | **RETAIN** | Pure language replicates per namespace; the 19-site ecosystem migration cost + the historical compiler-bug absorption surface argue against dispersing the pattern. |

None of the four families are **REPLACEABLE** in the sense of "pure
language at equivalent ergonomics ecosystem-wide." All four are
**PARTIALLY-REPLACEABLE** in the sense of "pure language can reproduce
the call-site shape and observable behaviour per namespace, by
hand-rolling the mechanism the types currently amortize."

The package's named value is amortization and centralisation, not
language capability. Both remain earned.

---

## Outcome

**Status**: DECISION — RETAIN all four type families.

The handoff's worked-example proposal is REFUTED on compiler-evidenced
grounds (no-op warning, observable container preservation). The broader
replaceability question is answered: pure Swift 6.3 can express every
mechanism the types use, but the types' value is the per-ecosystem
amortization of the mechanism across 19+ call sites in 6+ consumer
packages, plus a centralised absorption point for compiler bugs that
historically affected this shape (mark_dependence / CopyPropagation,
`forwardToInit` / CrossModuleOptimization, etc.).

No production edits are required. The experiments are retained as
documentation that the types' continued existence is a deliberate
amortization choice, not language-capability debt.

### Revisit triggers

Reopen this decision if any of:

1. A Swift Evolution proposal introduces a `borrow` expression form,
   generic computed properties, or a call-site consuming-mode selector.
2. The ecosystem's consumer count drops below ~5, making the
   amortization no longer clearly positive.
3. The compiler bugs that `Property.View*` centralises are all fixed
   upstream AND the 19+ consumer sites are willing to absorb
   per-site maintenance of the replacement view struct.

---

## References

### Experiments (this investigation, 2026-04-21)

- [language-semantic-property-replacement](../Experiments/language-semantic-property-replacement/) — Pattern A. Status: PARTIAL (CONFIRMED debug; known Swift 6.3.1 release-mode SIL crash).
- [language-semantic-property-typed-replacement](../Experiments/language-semantic-property-typed-replacement/) — Pattern B. Status: PARTIAL (same shape as A).
- [language-semantic-property-consuming-replacement](../Experiments/language-semantic-property-consuming-replacement/) — Pattern C. Status: PARTIAL (handoff proposal REFUTED; V2 and V3 CONFIRMED alternatives).
- [language-semantic-property-view-replacement](../Experiments/language-semantic-property-view-replacement/) — Pattern D. Status: PARTIAL (CONFIRMED with Lifetimes flag).

### Prior Research (this package)

- [`property-type-family.md`](property-type-family.md) v1.0.0 — Founding paper; taxonomy and typealias pattern.
- [`variant-decomposition-rationale.md`](variant-decomposition-rationale.md) v1.0.0 — 2026-04-20 release shape; five variant targets + umbrella.
- [`borrowing-label-drop-rationale.md`](borrowing-label-drop-rationale.md) v1.0.0 — Documents the absence of a `borrow` expression form (Swift 6.3.1); 19-site migration cost evidence.
- [`property-view-escapable-removal.md`](property-view-escapable-removal.md) v1.0.0 — 149-site `@_optimize(none)` history; centralisation as compiler-bug absorption value.

### Prior Research (swift-institute)

- [`swift-institute/Research/noncopyable-ownership-transfer-patterns.md`](../../../swift-institute/Research/noncopyable-ownership-transfer-patterns.md) v2.0.0 — Three consumption patterns; coroutine-accessor end state; layer model for ownership mechanism confinement.

### Adjacent Experiments

- [`property-consuming-value-state`](../Experiments/property-consuming-value-state/) — Recorded the Swift 6.3.1 release-mode SIL crash (`forwardToInit: Cannot initialize a nonCopyable type with a guaranteed value`) that this investigation's Patterns A and B also hit.
- [`property-consuming-state-allocation-benchmark`](../Experiments/property-consuming-state-allocation-benchmark/) — Companion that refuted the allocation-elimination motivation for Option C (value-state).
- [`borrowing-read-accessor-test`](../Experiments/borrowing-read-accessor-test/) — Demonstrated that `withUnsafePointer(to: borrowing T)` on `~Copyable` types enables the `Property.View.Read` borrowing-init overload used in V1 of Pattern D.

### Language References

- SE-0377 — Borrowing and consuming parameter ownership modifiers (the basis for `consuming self` in Pattern C V2).
- SE-0427 — Noncopyable Generics.
- SE-0430 — `sending` parameter and result values.
- swiftlang/swift#88022 — CopyPropagation / mark_dependence (fixed in Swift 6.3.1; see `property-view-escapable-removal.md`).
- The Swift 6.3 rule "a mutating method cannot return a ~Escapable result" (lifted by `-enable-experimental-feature Lifetimes`).
