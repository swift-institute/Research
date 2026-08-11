# Dropping the `borrowing:` Argument Label from `Property.View*` Inits

<!--
---
version: 1.0.0
last_updated: 2026-04-20
status: DECISION
---
-->

**Coen ten Thije Boonkkamp**
Swift Institute
April 2026

---

## Context

The `Property.View*` family ships two init overloads per type (e.g. `Property.View.Read`):

```swift
public init(_ base: UnsafePointer<Base>)
public init(_ base: borrowing Base)
```

The first takes a caller-supplied pointer; the second obtains one via
`withUnsafePointer(to:)` from a borrowing parameter. Prior to 2026-04-20 the
borrowing overload carried an explicit `borrowing:` argument label:

```swift
public init(borrowing base: borrowing Base)
```

The 2026-04-20 release polish dropped the label. This note documents why.

---

## Question

Should the `borrowing:` argument label stay, or drop?

---

## Why the label existed

The `borrowing:` label was added to disambiguate the two overloads at the call site,
particularly for readers unfamiliar with the pattern:

```swift
yield unsafe Property.View.Read(self)                  // borrowing init
yield unsafe Property.View.Read(&self)                 // pointer init — but &self
yield unsafe Property.View.Read(pointer)               // pointer init — with explicit pointer
```

The first call site's argument type (`Base`) and the third's (`UnsafePointer<Base>`)
are distinct, but a reader glancing at `Property.View.Read(self)` alone might wonder
which overload is being invoked. The `borrowing:` label made the borrowing path
explicit: `Property.View.Read(borrowing: self)`.

---

## Why the label dropped

### Type-based overload resolution is sufficient

Swift resolves `init(_ base: borrowing Base)` vs `init(_ base: UnsafePointer<Base>)`
by argument type. `Property.View.Read(self)` has type `Self → Base` (borrowing);
`Property.View.Read(pointer)` has type `UnsafePointer<Base>`. The compiler cannot
confuse them, and the IDE shows the resolved signature on hover.

The `borrowing:` label was redundant with this resolution — it added no information
the type signature didn't already carry. Its role was purely cognitive, helping
readers trace the path. But the implicit form reads more naturally and matches the
ecosystem pattern used by every other Swift init that doesn't disambiguate.

### No explicit-borrow expression form exists at call sites

A reasonable expectation is that readers could request `borrowing self` as a
call-site expression to make the borrow explicit even without a label:

```swift
// Hypothetical — does NOT compile in Swift 6.3.1:
yield unsafe Property.View.Read(borrowing self)
yield unsafe Property.View.Read(borrow self)
```

Neither form is valid Swift 6.3.1 syntax. The only explicit ownership-qualifying
expression forms are `consume x` and `copy x`. There is no `borrowing x` or
`borrow x` expression form. Testing with `swiftc -parse`:

```
error: expected ',' separator
Property.View.Read(borrowing self)
                             ^
```

The language grammar permits `borrowing` as a *parameter-type modifier*
(`func f(_ x: borrowing T)`) and `consume` / `copy` as *expression forms*
(`let y = consume x`). It does not provide a `borrowing` expression form. This
asymmetry is a deliberate language-design choice (see SE-0377 / SE-0427): the
absence of a call-site marker for borrow reflects that borrowing is the default
and requires no opt-in.

Since callers cannot write `Property.View.Read(borrowing: self)` as an
expression-level annotation even if they wanted to, the argument label cannot be
offering expression-level explicitness. It was offering declaration-level
documentation — which the init's signature already carries.

### The 19-site migration cost

Before the drop, 19 downstream call sites across the primitives ecosystem
(`swift-memory-primitives`, `swift-buffer-primitives`, `swift-storage-primitives`,
`swift-dictionary-primitives`, `swift-list-primitives`,
`swift-ownership-primitives`) carried the `borrowing:` label on every invocation of
`Property.View*(borrowing: …)`. Every new accessor in the ecosystem was one more
site to write the label.

The label was pure repetition. Dropping it removed 19 boilerplate sites without any
loss in clarity; downstream consumers now write `Property.View.Read(self)` the same
way they'd write any other init with a type-disambiguated overload. The migration
was mechanical (`\.Read\(borrowing: \1\)` → `\.Read(\1)` via grep-and-replace) and
preserved by git history.

### The stale Swift 6.2 workaround no longer applies

Retaining the label was load-bearing during an earlier window when Swift 6.2
required `@_optimize(none)` workarounds on `@inlinable` consumers of `Property.View`
to avoid a CopyPropagation crash (swiftlang/swift#88022). The workarounds
incidentally interacted with the label pattern in a way that made dropping the label
mid-workaround-era risky.

Swift 6.3.1 confirmed the fix for #88022 (verified against the reproducer in
`swift-buffer-primitives/Experiments/copypropagation-nonescapable-mark-dependence/`).
The `@_optimize(none)` annotations were removed across 149 sites in the
`property-view-escapable-removal` pass. With the workaround gone, the last argument
for retaining the label vanished.

---

## Outcome

**Status**: DECISION — the `borrowing:` label is dropped from all `Property.View*`
`init(_ base: borrowing Base)` overloads as of 2026-04-20.

Applied changes:
- 7 `Property.View*` types (`Property.View`, `.Typed`, `.Typed.Valued`,
  `.Typed.Valued.Valued`, `.View.Read`, `.Read.Typed`, `.Read.Typed.Valued`) all
  declare `public init(_ base: borrowing Base)` with no label.
- 19 downstream call sites migrated across 6 consumer packages.
- Stale `@_optimize(none)` + `WORKAROUND / TRACKING` comment blocks removed
  (verified redundant after swiftlang/swift#88022 fix in Swift 6.3.1).

The pattern decision for future `Property.View*` additions: new pointer-wrapping
view types declare the same unlabeled dual-init pattern —
`init(_ base: UnsafePointer<Base>)` / `init(_ base: UnsafeMutablePointer<Base>)`
and `init(_ base: borrowing Base)`. Type-based overload resolution handles
disambiguation; no label is introduced.

---

## References

- SE-0377 *Borrowing and consuming parameter ownership modifiers* — parameter-type-modifier syntax.
- SE-0427 *Noncopyable Generics* — `~Copyable` constraint semantics.
- swiftlang/swift#88022 — CopyPropagation mark_dependence bug (confirmed fixed in Swift 6.3.1).
- [`property-view-escapable-removal.md`](property-view-escapable-removal.md) — companion decision record; the `@_optimize(none)` mass removal happened in the same release window. Status: DECISION.
- `Audits/audit.md` — Code Surface section; finding 2 ([API-NAME-002] on `borrowBase` / `consumeBase`) sits alongside this label drop as the same kind of "identifier simplification" work.
- `[PRP-006]` in `Skills/SKILL.md` — the corresponding enforcement rule.
