# swift-sequence-primitives — `rawValue` → `underlying` / `Carrier.\`Protocol\`` rename audit

**Date**: 2026-05-03
**Tier**: 6 (downstream cycle)
**Upstream commits**: carrier `2b57aac`, tagged `46ded75`, property `c4bce7f`, index `e4f2299`

## Scope

Audit `swift-sequence-primitives` ahead of mechanical rename for the upstream
`rawValue` → `underlying` and bare `Carrier` → `Carrier.\`Protocol\`` migration.

## Q1. Own `public let rawValue` types?

Verdict: **NONE**.

A `grep -rn 'public let rawValue\|public var rawValue\|RawRepresentable'` over
`Sources/` and `Tests/` returned no matches. There is no own-field `rawValue`
storage in this package; nothing to rename to `underlying` under the
Cardinal/Ordinal/Vector precedent.

Sequence-side public types (`Sequence.\`Protocol\``, `Sequence.Iterator.\`Protocol\``,
`Sequence.Difference`, `Sequence.Difference.Changes`, etc.) are protocols and
namespaces. Concrete iterators and views (`Sequence.Difference.Steps.Iterator`,
`Sequence.Difference.Changes.Iterator`, `Sequence.Fixture.Source.Iterator`,
`Sequence.Fixture.ClearableSource`, `Sequence.Fixture.DrainableSource`) carry
underscored `_storage`/`_elements`/`_index`/`_count` fields, never a public
`rawValue` member. Already on the post-rename pattern.

## Q2. Editorial public surface that could move to a sibling target / SLI?

Verdict: **No non-trivial recommendations.**

The package already separates standard-library bridging into a dedicated target
(`Sequence Primitives Standard Library Integration`) and decomposes into
`Core` / `Consuming` / `Lazy` / `Terminal` / `Difference` / SLI sub-targets with
a thin umbrella. No editorial surface in `Core`/`Consuming`/`Lazy`/`Terminal`
appears mis-located.

`Sequence Primitives Test Support` lives at `Tests/Support/` and is exposed as
its own product — already on the post-rename layout.

## Q3. Three-consumer rule for each public init/accessor/method?

Verdict: **No non-trivial recommendations.**

This is an L1 protocol-and-namespace package; nearly all public surface is
either a protocol requirement or a default-method on a protocol. Three-consumer
applicability is therefore evaluated against `Sequence.\`Protocol\``-conforming
types ecosystem-wide, where the surface (`makeIterator`, `nextSpan`, `next`,
`forEach`, `reduce`, `first`, `contains`, `count`, `satisfies`, `prefix`,
`Sequence.Difference`) clears the bar by construction.

No bespoke single-consumer accessor was identified that should be retracted as
part of this rename cycle.

## Q4. Compound identifiers / `*Tag` suffixes / code-surface violations?

Verdict: **No non-trivial recommendations.**

- File naming uses dotted path (`Sequence.Difference.Changes+hunks.swift`,
  `Sequence.Difference.Steps.Iterator.swift`, `Sequence.ForEach+Property.View.swift`)
  — compliant with [API-IMPL-005] one-type-per-file.
- No `*Tag` suffix types (the only `Tag` substrings appear inside `extracting`
  / unrelated identifiers, not as type-name suffixes).
- Public types and methods follow `Nest.Name`; no compound identifiers
  (`forEach.consuming`, `Sequence.Difference.Steps`, etc. follow nested-accessor
  conventions).
- The `Sequence` and `Sequence.Iterator` namespaces declare canonical
  `\`Protocol\`` capability protocols, matching the
  `swift-package` / `code-surface` naming convention.

## Q1–Q4 verdict

Mechanical patch surface is **one line** in `Tests/Support/`:

```
$ git diff Tests/Support/
-            let take = min(Int(maximumCount.rawValue), remaining)
+            let take = min(Int(maximumCount.underlying), remaining)
```

(This was already applied in the working tree from a prior uncommitted pass and
is included in the same commit.) Production sources contain no `rawValue`,
`RawValue`, `Carrier`, or `_unchecked` references.

No bare `: Carrier` constraints, no `Tagged<Tag, RawValue>` declarations, no
own-field rename targets, no `init(_unchecked: ())` callers, no `.rawValue`
accesses.

## Phase 2 — additional non-mechanical adjustment

Although the rename surface is empty, the upstream cardinal cascade-drop
(`Cardinal.Underlying = UInt`, no longer `Cardinal`) collapsed the cross-type
comparison overload coverage: the disfavored
`<O: Ordinal.\`Protocol\`, C: Carrier.\`Protocol\`<Cardinal>>` overloads in
`swift-ordinal-primitives` no longer match a bare `Cardinal` RHS (since bare
`Cardinal: Carrier.\`Protocol\`<UInt>`, not `<Cardinal>`). This surfaced as four
build errors of the form `'Cardinal.Underlying' (aka 'UInt') and 'Cardinal' be
equivalent` at sites comparing `_position: Ordinal` against `_count: Cardinal`.

**Fix**: lift the LHS through `Cardinal(_:)` so the comparison is
`Cardinal-vs-Cardinal` (same-type, no `Carrier` overload required):

| File | Site | Before | After |
| ---- | ---- | ------ | ----- |
| `Sequence Difference Primitives/Sequence.Difference.Changes.Iterator.swift` | `:44` | `_index < _count` | `Cardinal(_index) < _count` |
| `Sequence Difference Primitives/Sequence.Difference.Steps.Iterator.swift` | `:44` | `_index < _count` | `Cardinal(_index) < _count` |
| `Sequence Primitives Standard Library Integration/Swift.Span.Iterator.swift` | `:51` | `_position >= _count` | `Cardinal(_position) >= _count` |
| `Sequence Primitives Standard Library Integration/Swift.Span.Iterator.swift` | `:86` | `_position < _count` | `Cardinal(_position) < _count` |
| `Sequence Primitives Standard Library Integration/Swift.Span.Iterator.Batch.swift` | `:52` | `_position >= _count` | `Cardinal(_position) >= _count` |

Note that the same-file `_position.advance.saturating(by: take)` and
`Cardinal(_position)` arithmetic already use this lift convention; this change
extends it to the comparison sites that previously relied on the now-narrower
cross-type comparison overload.

**Verdict**: build clean, 160 tests in 72 suites pass. No escalation.
