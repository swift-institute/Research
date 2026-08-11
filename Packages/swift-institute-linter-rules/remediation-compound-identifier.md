# compound identifier

**4,303 findings** — the largest class in the fleet compliance ledger of 2026-08-02, by a factor
of nearly two over the next. Citation `[API-NAME-002]`. Predicate:
[`Lint.Rule.Naming.Compound.swift`](../Sources/Institute%20Linter%20Rule%20Naming/Lint.Rule.Naming.Compound.swift).

Read [remediation-mechanics.md](remediation-mechanics.md) first.

This is the most expensive class per finding in the ledger and the one where the wrong
remediation does the most damage. Most of this document is about deciding **which** findings to
act on, and in what order.

---

## What the convention means

A method or property does not carry a compound camelCase name. The operation is reached through
a nested accessor instead:

```swift
dir.walk.files()          not   dir.walkFiles()
instance.open.write { }   not   instance.openWrite { }
```

The reasoning is that a compound name is a namespace that was never declared. `walkFiles`,
`walkDirectories`, and `walkSymlinks` are three members of a `walk` concept, flattened into the
enclosing type's namespace where they sit alphabetically among everything else. Declaring the
namespace makes the grouping real: it becomes discoverable by autocomplete after a single dot, it
gets a place to put shared state and shared documentation, and adding a fourth operation extends
something instead of adding another top-level member.

That is a claim about API design, not about spelling. It is why this class has no mechanical fix
and why the count is so large: the convention asks for structure that the flattened name was
substituting for.

## What the predicate actually flags

A **method or property at type-member scope** whose name starts lowercase and contains an
uppercase letter after a lowercase one. Package manifests are excluded before the walk begins.

### What it exempts — and one thing it does not

Exempt, and therefore never a finding:

- **`package`-scope declarations.**
- **`fileprivate` and `private` effective** declarations. The walk-up captures *effective*
  visibility, so a member of a `private` type is exempt even with no modifier of its own.
- **Local declarations** — anything inside a function, initializer, accessor, closure, `deinit`,
  or subscript body. The rule's surface is named exports, not implementation.
- **Backticked names.** Backticks signal a deliberate opt-out of identifier conventions.
- **Boolean prefixes**: `is`, `has`, `should`, `will`, `did`, `can`, `must` followed by an
  uppercase letter. `isEmpty` and `hasPrefix` do not fire.
- **Documented stdlib vocabulary**, held in `namingCompoundSwiftNativeIdiomCitations` — `rawValue`,
  `flatMap`, `swapAt`, `storeBytes`, `withUnsafeBufferPointer`, `span`, `callAsFunction`, and
  roughly fifty others, each carrying its Swift citation.
- **The eight `@resultBuilder` method names** per SE-0289 / SE-0348, exempt by name only.
- **Protocol-required witnesses** listed in `namingCompoundProtocolWitnessMethodCitations`. Entries
  are either *conformance-gated* — exempt only where the enclosing context introduces a conformance
  — or *name-only*, exempt everywhere.

**`internal` is not exempt.** This is the single most useful fact for planning the remediation, and
it is easy to get wrong from the convention's framing: the rule's stated intent is public API
surface, but the predicate's exemptions are `package`, `fileprivate`, `private`-effective, and
local. An `internal` method with a compound name fires, and its entire consumer set is one module
plus that module's `@testable` importers — fully enumerable, no cross-package ripple, no
adjudication needed. The class is therefore **not uniformly expensive**, and the internal subset is
where a remediation should start. See "Order the work" below.

### Why name-only exemptions exist

Worth understanding, because it explains findings that otherwise look like predicate bugs. The
house one-extension-per-member convention puts a witness in a bare extension (`Type+method.swift`)
whose conformance is declared in a **sibling file**. No same-file AST walk can see that
conformance, so a conformance-gated exemption would never fire there. Name-only entries exist for
exactly that structural limitation — which is also why a name-only entry must be protocol
vocabulary distinctive enough that non-witness reuse is implausible.

---

## Step 1 — there is no rewriter, and this is not a gap to be filled

Two independent blockers, either one sufficient.

**The target is not a rename.** The canonical remedy is a restructure into nested accessors.
`dir.walkFiles()` becoming `dir.walk.files()` requires inventing a `walk` namespace, deciding its
storage and its borrowing semantics, and deciding what else belongs in it. There is no function
from a camelCase identifier to a correct decomposition; the word-boundary scan that found the
finding is a detector, not a decomposition.

**Even a plain rename would ripple past what a single-package pass can reach.** Every finding is on
`internal`-or-wider surface by construction, and the public share of it changes call sites in every
dependent package.

cclsp does not close this class. It will enumerate references and propagate a rename you have
already decided — see [remediation-mechanics.md §2](remediation-mechanics.md#2-judge-the-ripple-before-you-commit-to-a-rename)
— but it cannot supply the target, and cross-package propagation is only as complete as the set
indexed in one session.

---

## Step 2 — triage before you restructure anything

Four dispositions. Only one of them is the restructure, and it is not the most common.

### A. Accept as warning — the rule fires legitimately and the code is right

The rule's own message defines this arm, and it is unusual: **leave the warning standing.** Do not
suppress it, and do not edit source against the rule's intent. The warning is the intended signal —
a standing canary that a reviewer re-examines periodically to confirm the justification still
holds.

Two shapes qualify:

- **A stdlib-mirroring name at a consumer-facing typed-input bridge.** An overload that takes an
  Institute typed index in place of `Int`, mirroring the stdlib operation it replaces — a
  typed-`Cardinal` overload of `OutputSpan.removeLast` mirrors `Array.removeLast(_:Int)`. The
  operation *is* the stdlib operation; renaming it would defeat the drop-in property that is the
  reason it exists.
- **A protocol requirement not yet in the witness allowlist.** The enclosing extension conforms to
  a protocol that requires this exact name, and the name is not in the citation dictionary yet.

For the second, the disposition is usually B rather than a standing warning — propose the entry.

### B. Propose a predicate exemption

If the name is dictated by an external contract that will recur across the ecosystem, the exemption
belongs in the rule, not in your file. Two dictionaries take entries:

- **`namingCompoundSwiftNativeIdiomCitations`** — broadly applicable stdlib-mirror vocabulary.
  Propose with the canonical Swift citation: the specific stdlib symbol whose spelling you are
  aligning with. An entry without a citation is indefensible at review.
- **`namingCompoundProtocolWitnessMethodCitations`** — protocol-required witness names. Propose with
  the specific `Protocol.requirement` whose contract dictates the name, and say whether it should be
  conformance-gated or name-only. Conformance-gated is the default and the safer choice; name-only
  is correct when the one-extension-per-member layout puts the conformance in a sibling file, and it
  requires that the name be distinctive enough that non-witness reuse is implausible. Entries are
  proposed in lint drains and ratified; the ratifying adjudication is cited in the entry.

Twenty suppressions of the same name across twenty files is the failure mode this step exists to
prevent. If you are writing the same reason twice, stop and propose the entry.

### C. Drop a redundant word — the cheap fix

Before reaching for a namespace, check whether the compound name is compound because it restates
its own context:

```swift
extension Header {
    public func parseHeader(from bytes: [UInt8]) -> Header    // parseHeader on Header
}
```

The `Header` in `parseHeader` is the type you are already on. The fix is `parse(from:)` — no
namespace, no new type, no design decision. This is a rename with an ordinary ripple and nothing
more, and a meaningful share of this class is exactly this shape. Look for it first, because it is
an order of magnitude cheaper than D.

Related to the `redundant prefix` rule, which detects the type-name-prefix form specifically.

### D. Restructure into a nested accessor

Everything else. This is step 3.

---

## Step 3 — the restructure, and how to make it affordable

### Batch by prefix, never by finding

**This is the single decision that determines what this class costs.** A finding is one member; a
namespace is a group of them. Remediating `walkFiles` alone means inventing a `walk` namespace to
hold one method, which is over-engineering and will read as such at review. Remediating
`walkFiles`, `walkDirectories`, and `walkSymlinks` together means declaring a namespace that was
already there implicitly.

So the unit of work is: **within one type, all findings sharing a leading word.** Group the
package's findings by (enclosing type, first word) before deciding anything. Most groups will have
two or more members, and those are the ones where the convention pays. A group of one is a
different decision — see below.

This also collapses the review surface: one namespace, one design decision, one review, however
many findings it clears.

### The shape

```swift
// Before
extension Directory {
    public func walkFiles() -> [File] { … }
    public func walkDirectories() -> [Directory] { … }
}

// After
extension Directory {
    public var walk: Walk { Walk(base: self) }
}

extension Directory {
    public struct Walk {
        let base: Directory
    }
}

extension Directory.Walk {
    public func files() -> [File] { … }
    public func directories() -> [Directory] { … }
}
```

Note the layout: the accessor, the namespace type, and its members each sit in their own extension,
which is what [minimal type body](remediation-minimal-type-body.md) asks for anyway. If you place these in new
files, each extension-only file is in the surface of
[extension file naming](remediation-extension-file-naming.md) and must be named accordingly.

### The decisions the shape does not make for you

Before writing it, answer these. They are why no tool can:

1. **Does the namespace already exist?** Search the ecosystem for an owning type before declaring a
   new one — by capability, not by name, since equivalent capabilities routinely use different
   vocabulary. A `Walk` may already exist at a lower layer and want extending rather than
   duplicating.
2. **Is this type the right owner?** `dir.walkFiles()` might not want a `Directory.Walk` at all; the
   operation may belong on a file-system type that takes the directory as input. A compound name
   often marks an operation living on the wrong type, and the namespace question surfaces it.
3. **What are the view's ownership and lifetime semantics?** A namespace struct holding `base` is a
   value copy. Where the base is expensive, non-copyable, or must not outlive the call, the view
   needs `borrowing`/`~Copyable`/`~Escapable` treatment — and that is a real design decision with
   real ergonomic consequences, not a mechanical wrapper.
4. **What else belongs in it?** The namespace is a place future operations will land. Name it for
   the concept, not for the two methods that happen to exist today.

### When the group has exactly one member

Three lawful outcomes, in order of preference:

- **The word is not a namespace, it is redundant** — apply C.
- **The namespace is real and this is its first member.** Declare it. The test is whether you can
  name a second operation that would plausibly belong, not whether one exists yet.
- **Neither.** The name is a genuine two-word concept with no grouping behind it. Then the honest
  disposition is a standing warning under A, or a suppression with that reason. Manufacturing a
  one-member namespace to clear a finding produces worse API than the finding described.

---

## Ripple and sequencing

Per [remediation-mechanics.md §2](remediation-mechanics.md#2-judge-the-ripple-before-you-commit-to-a-rename). For this
rule specifically:

| Effective visibility | Consumer set | Disposition |
|---|---|---|
| `internal` | The module, plus `@testable` importers | Fully enumerable via cclsp. Remediate freely. |
| `public` | Every dependent package, transitively | The symbol and all consumers move together, in one coordinated change. |

Deprecation is the tool for the public share where a coordinated change is not possible: keep the
old spelling as a `@available(*, deprecated, renamed:)` forwarding member, land the new shape, let
consumers migrate, remove the old one. Note that the deprecated member **still fires the rule** —
it is still a compound name — so this trades one finding now for one finding later plus a migration
window. That is often the right trade for public surface and is never the right trade for internal.

Never estimate the consumer set from a grep: `@_exported public import` lets a consumer bind types
without naming the package in any manifest, so both a manifest census and a source search
under-report.

---

## Order the work

For a package, in this order. Each step is strictly cheaper than the next:

1. **`internal` findings that are case C** (redundant word). Local rename, enumerable consumers,
   no design decision.
2. **`internal` findings grouped by prefix** with two or more members. One namespace decision per
   group, consumers enumerable within the module.
3. **`internal` singletons.** Decide A, C, or a namespace.
4. **`public` findings that are case B** — propose the dictionary entries. These clear findings
   ecosystem-wide at once and are the highest-leverage move available.
5. **`public` findings, grouped by prefix.** Coordinated, one namespace at a time.
6. **`public` singletons.** The most expensive per finding and the last to touch.

Do not start at the top of the diagnostic list. It is ordered by file.

---

## Worked examples

### Case C — the redundant word

`swift-throttling`, `Sources/Throttling/RequestPacer.swift`, inside `public actor RequestPacer`:

```swift
    public func getRequestCount(_ key: Key) async -> Int {
        schedules[key]?.requestCount ?? 0
    }
```

Two words are carrying nothing. `get` is a prefix the Swift API guidelines already argue against
for a plain accessor, and `Request` restates the type you are calling it on. What is left is
`count(_:)` — `pacer.count(key)` — which is not compound, needs no namespace, and reads better.

This is the disposition to look for first, and this example shows why: the finding looks like it
demands a `RequestPacer.Request` namespace, and it does not. It demands two deletions.

### Case D — a real prefix group, on public surface

`swift-binary-parser-primitives`, `Sources/Binary Machine Primitives/Binary.Parser.swift`, in one
extension:

```swift
extension Binary.Parser {
    @inlinable
    public func parseWhole(_ bytes: [Byte]) throws(Binary.Machine.Fault) -> Value { … }

    @inlinable
    public func parsePrefix(_ input: inout Byte.Input) throws(Binary.Machine.Fault) -> Value { … }
}
```

Two findings, one group, one namespace. `parse` is the concept; `whole` and `prefix` are the two
ways of applying it, and a third (`parse.streaming(…)`, say) would extend the namespace rather
than add a third top-level member:

```swift
extension Binary.Parser {
    public var parse: Parse { Parse(base: self) }
}

extension Binary.Parser {
    public struct Parse {
        let base: Binary.Parser
    }
}

extension Binary.Parser.Parse {
    @inlinable
    public func whole(_ bytes: [Byte]) throws(Binary.Machine.Fault) -> Value { … }

    @inlinable
    public func prefix(_ input: inout Byte.Input) throws(Binary.Machine.Fault) -> Value { … }
}
```

Both members are `public`, so this is the coordinated-change path: the symbol and every consumer
move together. It is also a good illustration of decision 3 above — `Binary.Parser` is generic over
`Value` and the members are `@inlinable`, so the view type must carry the generic parameters and
must itself be `@inlinable`-compatible, and if the parser is ever made non-copyable the
`Parse` view holding `base` by value stops compiling and needs a borrowing design. None of that is
derivable from the name.

### Case D on internal surface — start here instead

`swift-file-system`, `Sources/File System Core/File.System.Write+Shared.swift`:

```swift
extension File.System.Write {
    internal static func syncFile(…) { … }
    internal static func syncDirectory(…) { … }
}
```

The same prefix-group shape, but `internal`: the consumer set is this module plus its `@testable`
importers, fully enumerable with cclsp, no cross-package coordination, no adjudication. Two
findings clear for the cost of one local decision — `sync.file()` and `sync.directory()`. This is
the shape step 1 and 2 of "Order the work" are pointing at, and the same file carries several more
of it.

### Case B — a witness needing a dictionary entry

```swift
extension Postgres.Connection: Wire.Codec {
    public func encodeMessage(_ message: Message) -> [UInt8] { … }
}
```

`encodeMessage` fires. If `Wire.Codec` requires exactly that spelling, the name is not the author's
to choose. Propose a `namingCompoundProtocolWitnessMethodCitations` entry citing
`Wire.Codec.encodeMessage(_:)`, conformance-gated — the conformance is declared right here in the
same extension, so the gate will fire. Do not suppress it in each conforming type.

### Case A — the standing warning

```swift
extension OutputSpan {
    public mutating func removeLast(_ count: Cardinal) { … }
}
```

Mirrors `Array.removeLast(_:Int)` at a typed-input bridge. `removeLast` is in the witness dictionary
conformance-gated, so outside a conformance context it still fires — correctly. Leave the warning.
Renaming would break the drop-in property the overload exists for.

---

## Suppression: narrow, and rarely the right answer

Per [remediation-mechanics.md §3](remediation-mechanics.md#3-suppress-only-where-the-shape-is-lawful-and-always-with-a-reason).
For this rule, note the ordering: **A (standing warning) and B (dictionary entry) both come before
suppression**, and between them they cover most of what people reach for a suppression to do.

A lawful suppression here names a contract that is real, specific, and *not* general enough to be a
dictionary entry:

```swift
// swift-linter:disable:next compound identifier
// REASON: the wire protocol names this field `contentLength` and the serializer
// derives the on-wire key from the property name; renaming changes the encoded
// output. Specification-fixed, single-site.
public var contentLength: Int
```

```swift
// swift-linter:disable:next compound identifier
// REASON: two-word concept with no namespace behind it — there is no second
// operation that would belong in a `<prefix>` view, and declaring one to hold a
// single member would be worse API than this name.
public func flushPending() { … }
```

These do **not** qualify:

- "Renaming is a breaking change." True of every public finding in this class; if it sufficed the
  rule would fire on nothing.
- "There are too many call sites." A scheduling fact. File the work.
- "It reads fine." The convention is not about readability.
- Anything that would apply verbatim to the other 4,302 findings. A reason that general is an
  argument about the rule, and belongs on the rule's tracker as a predicate change.

---

## Verification

Per [remediation-mechanics.md §5](remediation-mechanics.md#5-verify-per-finding-and-verify-the-whole-file):

```sh
workspace package lint  --package-path <package>
workspace package build --package-path <package>
workspace package test  --package-path <package>
```

Three rule-specific checks:

1. **One finding per declaration.** A property with several bindings reports per binding. Confirm
   the count fell by what you changed.
2. **The new names do not fire.** A namespace member named `files()` is fine; a namespace member
   named `filesInTree()` moved the finding rather than clearing it. Re-run and read the new
   findings, not just the count.
3. **Every consumer built, not just the owner.** For a public rename this is the check that
   matters, and the owner's own green build says nothing about it. Build the consumer set; an
   unindexed consumer is an unanswered question.

---

## Honest limitations

- **The predicate is a word-boundary scan.** It cannot tell a namespace-shaped compound
  (`walkFiles`) from a genuine two-word concept (`contentLength`), and it does not try. The
  citation dictionaries exist precisely because the mechanical split is wrong often enough to need
  an adjudicated escape hatch.
- **A clean run is not good naming.** Renaming `walkFiles` to `walkfiles` or backticking it clears
  the finding and defeats the rule; never evade a detector by respelling the prohibited code.
- **The exemption is narrower than the rationale in one specific way**: the conformance gate cannot
  see a conformance declared in a sibling file. A witness finding you cannot explain from the
  convention is usually explained by that gate.
- **The count will not fall linearly with effort.** Cases C and B clear findings cheaply and in
  bulk; case D clears them a namespace at a time and is where the cost lives. Any projection from
  an average cost per finding across this class will be wrong in both directions.
