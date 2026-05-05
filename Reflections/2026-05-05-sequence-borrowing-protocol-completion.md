---
date: 2026-05-05
session_objective: Promote Sequence.Protocol-family to primary-associated-type form, then complete the Sequence.Borrowing.Protocol iterator-constraint family (relax + restore `@_lifetime(borrow self)`) under audit-authorised, "perfect end-state, no defer" framing.
packages:
  - swift-sequence-primitives
  - swift-buffer-primitives
status: pending
---

# Sequence.Borrowing.Protocol completion — PAT promotion + iterator-constraint family + local-function scoping for _read yield chains

## What Happened

A focused-handoff session in two cycles. Cycle 1 (PAT promotion) was the
authorised handoff item; cycle 2 was a user-elevated follow-up that
explored the originally-out-of-scope iterator-constraint inconsistency.

### Cycle 1 — Primary-associated-type promotion (handoff `198f6b9`)

Mechanical 3-file edit promoting `Element` to a primary associated type
on the three sibling protocols (`Sequence.\`Protocol\``,
`Sequence.Iterator.\`Protocol\``, `Sequence.Borrowing.\`Protocol\``).
Audit framed it as "additive — every existing
`extension where Element == X` keeps working." Verified empirically:
`swift build` clean, 160/160 tests pass, swift-buffer-primitives clean
rebuild + 431/431 tests pass. The PAT promotion claim held exactly.

### Cycle 2 — Iterator-constraint family completion (`81157d6`)

The user lifted the original handoff's "out of scope" flag on the
`> Note:` block in `Sequence.Borrowing.Protocol.swift` (lines 43-46
and 64-65) — Iterator missing `& ~Copyable & ~Escapable` and
`@_lifetime(borrow self)` deferred. Framing escalated to "perfect
end-state, no matter what it takes, and not defer work."

The exploration revealed this change is **not purely additive at the
protocol level**, contra the audit's framing for the PAT promotion:

1. `& ~Copyable` alone — additive. Conformers may return ~Copyable
   iterators; current Copyable conformers continue to satisfy.
2. Adding `& ~Escapable` to the constraint — compiler hard-requires
   an `@_lifetime` annotation on `makeIterator()`:
   `error: cannot infer the lifetime dependence scope on a method with
   a ~Escapable parameter, specify '@_lifetime(borrow self)' or
   '@_lifetime(copy self)'`. The associated-type suppression couples
   to a lifetime decision on the protocol method.
3. `@_lifetime(borrow self)` — broke 4 internal call sites in
   `Sequence.Span+Property.Inout.swift` (`forEach`, `elements`,
   `reduceInto`, `reduceFrom`). Pattern
   `var iterator = base.value.makeIterator()` violates the new
   borrow-lifetime requirement: `base.value` is a `_read` yield
   bounded by the statement scope; the iterator binding outlives
   the yield.
4. `@_lifetime(copy self)` — wrong semantics for *borrowing*
   iteration (copy-self is for `consuming` makeIterator).

The original `> Note:` author's wording — *"Will be restored when
**Iterator gains `~Escapable`**"* — turned out to be precise: the
restoration was waiting for actual `~Escapable` conformer iterators
**and** call-site discipline, not just constraint-level permission.

### The local-function scoping pattern

Resolution: rewrite each Property.Inout method with a local function
that contains the iteration:

```swift
@inlinable
public func forEach(_ body: (Span<Base.Element>) -> Void) {
    func loop(_ source: borrowing Base) {
        var iterator = source.makeIterator()
        while true {
            let span = iterator.nextSpan(maximumCount: .max)
            if span.isEmpty { break }
            body(span)
        }
    }
    loop(base.value)
}
```

The single-statement `loop(base.value)` call holds the `_read` yield
through the entire iteration; inside the local function, `source`'s
borrow scope is the function scope, which fully contains the iterator's
lifetime. No protocol-level API additions, no cross-package changes,
no `unsafe` escape hatches.

Verification on Path B: 160/160 sequence-primitives tests pass; clean
rebuild of swift-buffer-primitives + 431/431 tests pass; representative
sweep of 5 additional consumers (`array`, `vector`, `graph`, `list`,
`posix`) clean; risk-surface verified empirically nil — zero
`.value.makeIterator()` patterns exist outside swift-sequence-primitives.

### Side-track — `Audits/audit.md` untrack (`ff66211`)

The Audits/ directory is gitignored ecosystem-wide via the canonical
`/*` whitelist pattern in `sync-gitignore.sh`. `audit.md` was
grandfathered into tracking from a pre-tightening commit; user
directed alignment ("we should align with the .gitignore. remove
audit.md from tracked"). `git rm --cached` keeps the file on disk
(with the cycle-1 RESOLVED edits intact for local reference) while
removing it from the index.

### HANDOFF.md cleanup

`/Users/coen/Developer/HANDOFF.md` (workspace-level scratchpad,
untracked) deleted. Per the existing convention from prior cycles
(Property cascade closeout), handoff content is preserved in:
- per-package commits + audit row history
- this reflection

## Lessons

### Lesson 1 — Audit "additive" claims need empirical scope qualification

The Cycle 1 audit said the PAT promotion was "additive — every existing
`extension where Element == X` keeps working." That claim verified.
The Cycle 2 audit also implicitly modeled `& ~Copyable & ~Escapable`
addition as additive (it's the same protocol family, same shape as
already-shipped on Sequence.Protocol). Empirically: NOT additive at
the **protocol level** because the compiler couples constraint
suppression to a lifetime decision on the protocol method. The
"additive" framing applies to **conformer** satisfiability, not to
the protocol's call-site contract.

**Rule of thumb**: an audit that claims a protocol-level associated-type
relaxation is "additive" should explicitly distinguish conformer-side
additivity (does X still satisfy Y?) from call-site additivity (do
existing callers still type-check against Y?). Suppression on an
associated type can flip a previously-implicit lifetime relationship
to explicitly-required, breaking call sites without breaking
conformers.

### Lesson 2 — `_read` yield chains and `@_lifetime(borrow self)` couple at the call site

Property.Inout.base.value goes through three `_read` yield accessors
(self → base → value). Each is bounded by the calling expression's
scope. Without `@_lifetime(borrow self)` on the consuming side
(makeIterator), the iterator return type's lifetime is implicit and
the chain works because Swift treats Escapable returns as
unconstrained. Adding `@_lifetime(borrow self)` on the protocol
method makes the iterator's lifetime explicit-and-tied-to-source;
the source's yield ends at end-of-statement, so a `var iterator = …`
binding fails.

The `Borrow-vs-Inout.md` doc in swift-ownership-primitives already
documents this exact interaction for the `Copyable` `get` vs ~Copyable
`_read` split — Copyable bases get a `get` accessor specifically to
"escape the compound coroutine lifetime chain that `_read` introduces."
For the ~Copyable case (which is forced for any
`Property.Inout where Base: ~Copyable`), the chain is unavoidable;
the call-site discipline must change instead.

### Lesson 3 — The local-function pattern is reusable

`func loop(_ source: borrowing Base) { … }; loop(base.value)` is a
clean general-purpose pattern for any "I need to call a borrowing
method on a `_read`-yielded value and use the result in a multi-line
loop." The single-statement function call holds the yield through
the entire body. No new types, no cross-package API, no `unsafe`.
Worth promoting to a code-surface pattern entry if more sites
surface needing it.

### Lesson 4 — Auto-mode "perfect end-state" framing changed pacing

Standard pacing for a flagged-deferred audit item is one cycle per
sitting, with explicit re-authorisation between cycles. The user's
framing "no matter what it takes, and not defer work" — combined
with the auto-mode active — meant rolling the deferred constraint
addition into the current session. The
`feedback_user_plan_is_roadmap_not_authorization` rule still applied
(each push got its own per-action authorisation; "yes push" was
explicit, not implied), but the **work** was bundled — explore +
fix + verify + commit + push, all in-session. The supervisor
stop-rule from the original handoff (STOP and surface non-additive
consequences) was honored: when `@_lifetime(borrow self)` broke
internal call sites, I reverted, surfaced three options (A/B/C),
let the user pick B, then proceeded.

## Action Items

(none load-bearing for upcoming cycles; corpus-meta-analysis can
absorb the local-function pattern entry if it sees enough recurrence
to warrant codification)

- [ ] If a third call-site needs the local-function pattern in a
      different file/package, promote it to an `[IMPL-*]` rule under
      the **implementation** skill with the "_read yield chain +
      @_lifetime(borrow self)" trigger and the `func loop(_:_:)`
      template.

## Cross-References

- `swift-sequence-primitives/Audits/audit.md` (local; per-package
  Audits is gitignored — file lives on disk only)
- Commits:
  - `198f6b9` PAT promotion (Sequence.Protocol family `<Element>`)
  - `ff66211` Audits/audit.md untrack to align with .gitignore
  - `81157d6` Sequence.Borrowing.Protocol iterator-constraint family completion
- `swift-ownership-primitives/Sources/Ownership Primitives/Ownership Primitives.docc/Borrow-vs-Inout.md` — pre-existing documentation of the `_read` coroutine lifetime chain interaction
- Original handoff (now deleted from workspace): `/Users/coen/Developer/HANDOFF.md` covering the PAT-promotion brief
