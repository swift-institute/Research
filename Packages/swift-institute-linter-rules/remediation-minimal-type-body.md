# minimal type body

**2,407 findings** — the second-largest class in the fleet compliance ledger of 2026-08-02.
Citation `[API-IMPL-008]`. Predicate:
[`Lint.Rule.Structure.MinimalTypeBody.swift`](../Sources/Institute%20Linter%20Rule%20Structure/Lint.Rule.Structure.MinimalTypeBody.swift).

Read [remediation-mechanics.md](remediation-mechanics.md) first.

---

## What the convention means

A type declaration should contain only its **storage** — stored properties, the canonical
initializer, and `deinit` where the type has one. Everything else belongs in an extension.

The reason is legibility of the thing that is hardest to change. A type's stored properties are
its memory layout, its `Codable` synthesis, its memberwise initializer, its size and its
copy cost. Behaviour churns; layout does not, and changing it is the expensive kind of change.
When the body carries only storage, a reader sees the whole layout at a glance and the diff on a
layout change is unmistakable. When behaviour is interleaved, the layout is something you
reconstruct by reading past it.

This is a structural convention, not a naming one, which is what makes it the class most
amenable to mechanization: **member lookup is identical whether a member is declared in a type's
body or in an extension of that type**. Moving one changes no call site anywhere. That property
is what the whole remediation rests on.

## What the predicate actually flags

The rule walks `struct`, `class`, `enum`, and `actor` declarations, and reports each member of
the body that is:

- a **`static`** or **`class`** member (any kind, including stored ones);
- a **computed property** — a binding carrying a `get`, `set`, `_read`, or `_modify` accessor,
  or a shorthand getter;
- a **function**;
- a **subscript**;
- a **`typealias`**;
- a **nested type** — `struct`, `class`, `enum`, or `actor`;
- a **nested `protocol`**.

It does **not** flag non-`static` stored properties, initializers, or `deinit`. It does not
consider visibility at all: a `private func` in a type body fires exactly as a `public` one
does. That fact matters in the decision tree below.

`#if`-guarded members **are** flagged. The predicate splices each clause's members in
recursively, so a platform-conditional member is checked exactly as an unguarded one is.

### Exemptions already in the predicate

These do not fire; you will not see findings for them, and you should not "fix" them if you
encounter the shape.

| Shape | Why |
|---|---|
| A type carrying **`@resultBuilder`** | SE-0289 / SE-0348 dictate the static builder-method shape. The attribute is the spec. |
| A type carrying **`@Suite`** | swift-testing dictates the nested-`@Suite` substructure. Both the bare and qualified (`@Testing.Suite`) spellings are recognized. |
| A **`SyntaxVisitor`**-family subclass | The member shape is dictated by the base class's `open` visit hooks; `override func visit(_:)` members are protocol-shaped by the visitor contract. |
| A **`` `Protocol` ``-sentinel typealias** | The hoisted-protocol pattern `[API-IMPL-009]` intends the typealias to live in the type's namespace. Extracting it yields an empty body plus an extension holding one typealias, for no gain. |
| A nested type carrying `@resultBuilder` or `@Suite` | Same reasoning, applied to the nested declaration. |

---

## Step 1 — run the rewriter

`minimal type body` is the strongest rewriter candidate in the ledger, and the fix is filed as
[#43](https://github.com/swift-foundations/swift-institute-linter-rules/issues/43). Once it
lands:

```sh
workspace package lint --package-path <package> --fix --dry-run
workspace package lint --package-path <package> --fix
```

The rewrite moves each flagged member out of the body into an `extension <DottedPath> { … }`
appended **in the same file**, carrying member text and modifiers verbatim.

Two properties make it safe, and both are worth understanding rather than trusting:

- **No call site changes**, because member lookup is unaffected. This is why the class is
  mechanizable at all.
- **Same-file placement is load-bearing, not incidental.** `private` members remain mutually
  visible between a type body and an extension only within a single file. A same-file move
  preserves access exactly where a cross-file move would break it — and remember the predicate
  flags `private` members too, so this is not a corner case.

Generic parameters are implicit in an unconstrained extension, and the predicate never flags
stored properties or initializers, so synthesized memberwise initializers are untouched.

Until #43 lands, everything below is the whole remediation rather than the residual.

### What the rewriter refuses

Each refusal is a deliberate safety boundary. Findings in these shapes survive `--fix` and are
your work.

1. **`class` and `actor` declarations, outright.** The most important refusal in the class — see
   step 2.
2. Members carrying **`@objc`**, **`dynamic`**, **`override`**, or **`final`**.
3. Any member reached through an **`#if`** clause. The predicate deliberately fires inside
   `#if`; a rewriter would have to reconstruct the condition around the moved member, and
   declines instead.
4. **Nested `protocol` declarations.**
5. A type whose enclosing declaration chain includes an **extension carrying a `where` clause**,
   where the dotted path cannot be reproduced without also reproducing the constraints.

---

## Step 2 — the decision tree for what remains

### Is the enclosing type a `class` or an `actor`?

This is the one place where the "no call site changes" property fails, and it fails silently.

**A method declared in a class body is dynamically dispatched and overridable. The same method
declared in an extension is statically dispatched and cannot be overridden.** Where a subclass
overrides it, moving it breaks the build — which is the good outcome, because you find out.
Where none does today, the move silently removes the ability for any subclass to override it
ever, and for a `public`/`open` class that is an API contract change no compiler will report.

Work through it in this order:

- **Is the class `final`?** Then no subclass exists or can, and the dispatch change is
  unobservable. Move the members as for a value type. This is the common case in Institute code
  and the cheapest one.
- **Is the class `public` or `open` and non-`final`?** Treat the move as an API change. Every
  dependent package that subclasses it is affected, and a grep will not find them — enumerate
  subclasses through cclsp per [remediation-mechanics.md §2](remediation-mechanics.md#2-judge-the-ripple-before-you-commit-to-a-rename),
  and treat an unindexed consumer set as an unanswered question rather than a clean one. If the
  class is designed for subclassing, leaving the members in the body is the correct outcome:
  suppress with that reason.
- **Is it `internal` and non-`final`?** The consumer set is the module plus its `@testable`
  importers, which cclsp can enumerate completely. Confirm nothing overrides the member, then
  move it. Consider whether the class should be `final` — often the finding is pointing at a
  missing `final`, and adding it is the better change.
- **Is it an `actor`?** Members declared in an extension of an actor are actor-isolated as body
  members are, so the isolation is preserved. Check for `nonisolated` members and for any member
  whose isolation was inferred rather than written, and let the build be the arbiter — the fix
  pass re-parses but does not typecheck, and neither does reading.

### Is the member `override`?

**Leave it in the body.** An `override` cannot be declared in an extension; this is a language
rule, not a preference. The finding has no lawful fix and is a legitimate suppression — see
below.

### Is the member `@objc` or `dynamic`?

Establish what depends on the dispatch behaviour before moving it. Where the member exists to be
reached from the Objective-C runtime or to be dynamically replaced, its declaration site is part
of that contract. Where you cannot establish that it isn't, leave it and suppress.

### Is the member inside an `#if`?

Two lawful shapes, and the choice is about how many members are involved:

- **One or few conditional members**: move the member into the extension and reconstruct the
  same `#if` condition around it there.
- **A whole platform's worth of members**: hoist the `#if` to file scope around a complete
  `extension` declaration. This is usually the better structure anyway, and it removes the
  conditional from inside the type entirely.

Whichever you choose, the condition must be reproduced exactly. This is the refusal the rewriter
makes because getting it subtly wrong compiles fine on the platform you are building.

### Is it a nested `protocol`?

A protocol cannot be declared in an extension of a generic type. If the enclosing type is
generic, the finding has no lawful in-place fix — either promote the protocol to the enclosing
namespace as a sibling declaration, or suppress. If the enclosing type is not generic, move it
as normal.

### Is it a nested type?

Nested types move to an extension like any other member, but ask first whether the nesting is
right. A nested type large enough to be interesting usually wants its own file, which is a
better change than either leaving it or moving it into a same-file extension. Note that a
`typealias` and a nested type are both flagged, but only one of them is usually worth relocating
rather than restructuring.

### Everything else — the ordinary case

Move it to an extension. The only remaining decision is **which** extension, and there are two
lawful answers:

- **A same-file extension**, which is what the rewriter produces. Always correct, always safe,
  and mandatory when any moved member is `private` or `fileprivate` and is referenced from the
  remaining body.
- **A topic-named sibling file**, which is what a reviewer would often prefer for a large or
  coherent member group.

If you choose the sibling file, two things follow. First, `private` mutual visibility does not
survive the move — check every moved member's visibility before splitting. Second, the new file
contains only extensions, which puts it directly in the surface of `extension file naming`: it
must be named `<Base>+<Topic>.swift`. See [extension-file-naming.md](remediation-extension-file-naming.md)
before you name it.

The original file is unaffected by that rule either way, because it still declares a top-level
primary nominal type, which is excluded from that rule's surface.

---

## Worked examples

### A struct with behaviour in the body — the ordinary case

`swift-render-primitives`, `Sources/Render Primitive/Render.Push.swift`:

```swift
    public struct Push {
        @usableFromInline var _block: (_ role: Render.Semantic.Block?, _ style: Render.Style) -> Void
        @usableFromInline var _inline: (_ role: Render.Semantic.Inline?, _ style: Render.Style) -> Void
        …                                                    // six more stored closures

        @inlinable
        public init(block: …, inline: …, …) { … }

        @inlinable public func block(role: Render.Semantic.Block?, style: Render.Style) { _block(role, style) }
        @inlinable public func inline(role: Render.Semantic.Inline?, style: Render.Style) { _inline(role, style) }
        @inlinable public func list(kind: Render.Semantic.List, start: Int?) { _list(kind, start) }
        …                                                    // five more forwarding methods
    }
```

Eight findings, one per method. The remediation moves all eight into a same-file extension,
leaving the eight stored closures and the initializer:

```swift
    public struct Push {
        @usableFromInline var _block: (_ role: Render.Semantic.Block?, _ style: Render.Style) -> Void
        …

        @inlinable
        public init(block: …, inline: …, …) { … }
    }

extension Render.Push {
    @inlinable public func block(role: Render.Semantic.Block?, style: Render.Style) { _block(role, style) }
    @inlinable public func inline(role: Render.Semantic.Inline?, style: Render.Style) { _inline(role, style) }
    …
}
```

The layout is now the whole body — and this type is the case for the convention: eight stored
closures and eight one-line forwarders interleave into something you have to read twice, and
separated they are a storage declaration and a dispatch table. No call site changed.

Note the members are `@inlinable` and the storage is `@usableFromInline`. That combination survives
the move unchanged — `@usableFromInline` internal storage is visible to an `@inlinable` member in
an extension in the same module exactly as in the body. It is worth checking rather than assuming
for any `@inlinable` member you move, because the failure is a compile error at the point of
inlining rather than at the declaration.

### A `~Copyable` type — check the accessor kinds

`swift-graph-primitives`, `Sources/Graph Sequential Primitives/Graph.Sequential.Builder.swift`,
`public struct Builder: ~Copyable`, whose body carries a computed property, a `mutating func`, a
`subscript`, and a `consuming func`. Four findings, four kinds, one move.

Non-copyable types are not a refusal — the refusal set is about `class`/`actor` dispatch, not about
ownership — but they are where the build check earns its place: a `consuming func` moved into an
extension keeps its ownership modifier, and a `subscript` with a `_modify` accessor keeps its
coroutine accessors, and neither is something reading the diff confirms.

### A `private` member — why same-file is load-bearing

```swift
struct Parser {
    var input: [UInt8]
    var position: Int

    private func peek() -> UInt8? { … }   // fires — visibility is not consulted
    func next() -> UInt8? { peek() }      // fires
}
```

Moving both into a **same-file** extension compiles: `private` is file-scoped for this purpose,
so `next()` can still call `peek()`. Moving them into a sibling `Parser+Scanning.swift` does
not compile, because `peek()` is no longer visible to `next()`. If you want the sibling file,
`peek()` must be promoted to `internal` first — which is a real API decision, not a mechanical
consequence, and is exactly why the rewriter does not attempt it.

### A class the rewriter refuses but you should not — `final`

`swift-records`, `Sources/Records/Core/Database.ClientRunner.swift`:

```swift
    public final class ClientRunner: Writer, @unchecked Sendable {
        private let client: PostgresClient
        private let runTask: Task<Void, Never>

        public init(…) { … }

        public func read<T: Sendable>(…) async throws -> T { … }    // fires
        public func write<T: Sendable>(…) async throws -> T { … }   // fires
        public func close() async throws { … }                      // fires
    }
```

The rewriter refuses this because it is a `class` — the refusal is on the declaration kind, not on
an analysis of whether the move is safe. But it is `final`, so no subclass exists or can, and the
dispatch change the refusal exists to prevent is unobservable. Move all three members into a
same-file extension exactly as for a value type.

This is the largest cheap subset of the class-and-actor residual: the rewriter's refusal is
deliberately coarse, and `final` is the property that makes the coarseness safe to look past.

### An actor whose findings are nested types

`swift-throttling`, `Sources/Throttling/RequestPacer.swift`:

```swift
public actor RequestPacer<Key: Hashable & Sendable> {

    public struct ScheduleResult: Sendable { … }   // fires — nested type
    public struct Config: Sendable { … }           // fires — nested type
    public struct ScheduleInfo: Sendable { … }     // fires — nested type
    …
}
```

Three findings, all nested types rather than methods, so the dispatch question does not arise at
all — a nested type has no dispatch. What it does have is a size: three public nested types is
usually three files. Moving them to same-file extensions satisfies the rule; giving each its own
file, named for the type it declares, is the better change and is what the rest of the ecosystem's
file conventions expect.

Note that a nested type moved to a **sibling file** is not in `extension file naming`'s surface,
because that file then declares a top-level primary nominal type. Only member-only moves create a
file that rule cares about.

### A non-`final` class — the refusal that matters

```swift
public class Reporter {
    public var destination: Destination

    public init(destination: Destination) { self.destination = destination }

    public func emit(_ record: Record) { … }   // fires
}
```

Moving `emit` into an extension makes it non-overridable. If any consumer subclasses `Reporter`
to customise `emit`, that consumer breaks — and if none does today, the move quietly forecloses
it. The lawful outcomes are: mark `Reporter` as `final` if it was never meant to be subclassed
and then move the member; or, if it is a designed extension point, leave `emit` in the body and
suppress with that reason.

---

## Suppression: the lawful shapes

Per [remediation-mechanics.md §3](remediation-mechanics.md#3-suppress-only-where-the-shape-is-lawful-and-always-with-a-reason),
a suppression records a judgment that the code is right as it stands. For this rule, these
qualify:

```swift
// swift-linter:disable:next minimal type body
// REASON: `override` cannot be declared in an extension.
override func visitPost(_ node: TokenSyntax) { … }
```

```swift
// swift-linter:disable:next minimal type body
// REASON: `Reporter` is a designed subclassing point; a method in an extension
// cannot be overridden, so moving this would remove the extension point.
public func emit(_ record: Record) { … }
```

```swift
// swift-linter:disable:next minimal type body
// REASON: nested protocol; the enclosing type is generic, and a protocol cannot
// be declared in an extension of a generic type.
protocol Storage { … }
```

These do **not** qualify: "moving it is a big diff", "this type is legacy", "the members are
tightly coupled to the storage" (member lookup is identical either way, so coupling is not
affected by the move), or any reason that would apply equally to all 2,407 findings.

If you find a **type-level** shape whose member layout is dictated by an external contract —
another informal protocol like `@resultBuilder`, another visitor-family base class — that is a
predicate exemption, not a suppression. The rule already carries four such exemptions; propose a
fifth with its citation rather than suppressing the shape repeatedly.

---

## Verification

Per [remediation-mechanics.md §5](remediation-mechanics.md#5-verify-per-finding-and-verify-the-whole-file):

```sh
workspace package lint  --package-path <package>
workspace package build --package-path <package>
workspace package test  --package-path <package>
```

The build is not optional for this rule. Everything in the remediation is a declaration move,
the fix pass re-parses without typechecking, and the two failure modes that matter —
a broken `private` reference after a cross-file split, and a lost `override` — are both
type-checking facts that reading will not surface.

One rule-specific check: confirm the finding count fell by exactly the number of members you
moved. This rule reports **one finding per member**, not one per type, so a type with six
flagged members contributes six. A count that fell further than that is a signal that a
suppression or an exclusion caught more than you intended.

---

## Honest limitations

- **The rewriter satisfies the predicate, not the whole convention.** It produces same-file
  extensions. A reviewer might well place the same members in topic-named sibling files, and the
  rule cannot tell the difference. A `--fix` run makes a package compliant; it does not make it
  well-organized.
- **A clean run does not mean the type body is minimal in spirit.** The predicate flags a fixed
  member-kind list. A stored property that should have been computed, or storage that belongs in
  a different type entirely, is invisible to it.
