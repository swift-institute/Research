---
date: 2026-02-13
session_objective: Bring collection-primitives to the same standard as sequence-primitives
packages:
  - swift-collection-primitives
  - swift-sequence-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: design
    description: Add [PATTERN-051] inherit vs shadow for refining protocols
  - type: package_insight
    target: swift-collection-primitives
    description: Broken collection-foreach-test experiment needs update
  - type: experiment_topic
    target: cross-module-protocol-shadowing
    description: Validate shadowing works across module boundaries (current experiment is single-module)
---

# Collection-Sequence Inheritance — Deduplication Through Protocol Refinement

## What Happened

Session began with an audit comparing collection-primitives against
sequence-primitives after the recent SuppressedAssociatedTypes adoption
(commit `804c721`) and default accessor property addition (commit `3575d08`)
in sequence-primitives. Collection-primitives had not been updated.

The comparison revealed that `Collection.Protocol` already refines
`Sequence.Protocol`, but collection-primitives defined its own parallel
tag types (`Collection.Contains`, `Collection.First`, `Collection.Map`,
`Collection.Filter`, `Collection.Reduce`, `Collection.Satisfies`) with
Property.View extensions that were **literally identical** to their Sequence
counterparts — same `makeIterator()` loop, same logic, only the tag differed.

6 of 8 shared operations were pure copy-paste. Only `forEach` (index-based
vs iterator-based) and `count` (returns `Index<Element>.Count` vs `Cardinal`)
genuinely differed.

Created an experiment (`protocol-inheritance-shadowing/`) validating that:

1. A `Collection.Protocol` conformer inherits `Sequence.Protocol` default
   accessor properties for free (`.contains`, `.map`, etc.)
2. A more-specific `Collection.Protocol` extension can shadow the inherited
   Sequence default (`.forEach` tagged `Collection.ForEach` wins over
   `Sequence.ForEach` for collection conformers)
3. The compiler resolves to the correct overload via standard protocol
   refinement — no ambiguity

Proceeded with cleanup: deleted 12 files (6 tag enums + 6 Property.View
extensions), added `Collection.Protocol+ForEach.swift` providing a default
`.forEach` accessor, updated namespace documentation. Build succeeded.

## What Worked and What Didn't

**Worked well:**

- The systematic side-by-side comparison immediately revealed the duplication
  scope. Reading actual source files (not just file listings) was essential —
  the identical `makeIterator()` loops were invisible from file names alone.
- The self-contained experiment was decisive. It validated the shadowing
  mechanism in under a minute, giving full confidence to delete 12 files.
- The inheritance approach is clean: conformers get 9+ operations for free
  from Sequence defaults, and collection only provides tags where the
  implementation genuinely differs.

**Confidence was low on:**

- Whether the compiler would reliably prefer the more-specific protocol
  extension when both extensions provide the same-named property with
  different return types (`Property<Sequence.ForEach, Self>.View` vs
  `Property<Collection.ForEach, Self>.View`). The experiment confirmed it
  works, but this is the kind of thing that could regress with compiler
  changes.

## Patterns and Root Causes

**Root cause of the duplication:** Collection-primitives was created before
sequence-primitives had default accessor properties. Each package independently
defined its own tags and Property.View extensions. When sequence-primitives
gained protocol-level defaults (`Sequence.Protocol+Contains.swift` etc.),
collection-primitives wasn't updated to leverage them.

**The broader pattern: protocol refinement as deduplication.** When a refining
protocol (`Collection.Protocol`) doesn't change the implementation of an
inherited operation, it should not re-declare a tag for it. Tags should only
exist at the level where the implementation diverges. This is analogous to
how stdlib's `Collection` inherits `contains(_:)`, `first(where:)` etc. from
`Sequence` without re-declaring them — only overriding where the collection
can do better (e.g., `count` via `distance(from:to:)`).

**Decision framework established:** For any operation shared across Sequence
and Collection, ask: "Does the collection implementation differ from the
sequence implementation?" If no, inherit. If yes, shadow with a
collection-specific tag and a more-constrained Property.View extension.

## Action Items

- [ ] **[skill]** design: Add guidance for protocol refinement deduplication — when a refining protocol inherits operations vs shadows them with its own tag
- [ ] **[package]** swift-collection-primitives: The `collection-foreach-test` experiment is broken (pre-existing — uses `typealias Index = Int` and `Array<Element>.Iterator` which doesn't conform to `Sequence.Iterator.Protocol`). Needs update to match current patterns.
- [ ] **[experiment]** Validate that the shadowing approach works across module boundaries (current experiment is single-module; the real scenario has Sequence tags in one module and Collection's shadowing extension in another)
