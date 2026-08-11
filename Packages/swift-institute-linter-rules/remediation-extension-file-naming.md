# extension file naming

**1,418 findings** — third-largest class in the fleet compliance ledger of 2026-08-02. Citation
`[API-IMPL-007]`; adjudicated on swift-institute-linter-rules#6 (ruling D2, 2026-07-30),
implemented per swift-institute-linter-rules#9. Predicate:
[`Lint.Rule.Structure.ExtensionFileNaming.swift`](../Sources/Institute%20Linter%20Rule%20Structure/Lint.Rule.Structure.ExtensionFileNaming.swift).

Read [remediation-mechanics.md](remediation-mechanics.md) first.

---

## What the convention means

A file that contains only extensions has no type declaration to take its name from, so it names
its **base type plus a discriminator** that says what this particular extension does:

```
Array.Dynamic+Sequence.swift                      conformance addition
Array.Dynamic where Element Comparable.swift      constraint-discriminated extension
Array.Dynamic+Iteration.swift                     member-only, grouped by topic
```

The point is that the file tree answers a question the type declaration cannot: given a type
spread across a dozen files, which file holds which part of it. `Foo.swift`, `Foo2.swift`, and
`FooExtensions.swift` all answer "some of it", which is the same as not answering.

This is the one rule in the top five whose canonical fix is **a rename, with no source edit**.

## What the predicate actually flags

Scope: a `.swift` file **under a `Sources/` directory**. `Tests`, `Experiments`, and `Examples`
path segments are excluded.

Surface: a file whose **top-level declarations are exclusively `extension` declarations** — zero
top-level primary nominal types. A file declaring a `struct`, `class`, `enum`, `actor`, or
`protocol` at top level is excluded and belongs to `single type per file`'s surface instead. A
type nested inside a top-level extension shell counts as a primary type too, and also excludes
the file.

For a file in that surface, the rule classifies into exactly one arm and checks the basename
against it:

| # | When | Required basename |
|---|---|---|
| 1 | The extensions extend **different base types** | None exists — a mixed-base file has no lawful name |
| 2 | Else, any extension **adds a conformance** | `<Base>+<Conformance>` |
| 3 | Else, any extension carries a **`where` clause** | `<Base> where <discriminator>` |
| 4 | Else (**member-only**) | `<Base>+<Topic>` |

The arms are checked in that order, so **a conditional conformance classifies under 2, not 3**:
`extension T: P where …` needs `T+P.swift`, not the `where` shape.

Some details that decide individual findings:

- **`<Base>` is the dotted path**, not the leaf. An extension of `Array.Dynamic` needs
  `Array.Dynamic+…`, not `Dynamic+…`.
- **Any added conformance satisfies arm 2.** A file adding three conformances may name any one of
  them; the rule does not require the first.
- **A module-qualified conformance accepts its leaf.** `extension Array.Dynamic: Swift.Sequence`
  is satisfied by `Array.Dynamic+Sequence.swift` — the fully-qualified `Array.Dynamic+Swift.Sequence.swift`
  is accepted too but is a name no repository uses.
- **The discriminator and the topic are repository-owned.** The rule checks that the segment is
  present and non-empty. It has no opinion about the words, and will not tell you your topic name
  is bad.
- The diagnostic is located at the file's **first extension declaration**, which is a position in
  the file rather than a position in its name.

### The sugar-type fallback

When the extended type is not an identifier, member, or metatype type — `[Int]`, `Int?`, a tuple —
the base key falls back to the type's own trimmed source text. That is deliberate: dropping
unresolvable extensions would let a genuinely mixed-base file pass undetected. But it means the
required basename the rule computes for such a file is something like `[Int]+Topic.swift`. See the
decision tree.

---

## Step 1 — there is no rewriter, and there cannot be one under the current contract

The rule's own documentation is explicit: the canonical fix is a rename, and no source edit. A
rename is **not expressible** under the engine's fix contract at all — the signature is one file's
text in, the same file's text out, and carries no path. This is not an omission to be filled in;
it is the shape of the contract.

Closing this class mechanically would require a new engine capability — a **path rewrite** —
rather than a rewriter. And even with one, only **arm 2** has a derivable target:

- Arms 3 and 4 require a discriminator or topic whose wording the rule states is repository-owned.
  There is no name to synthesise.
- Arm 1 requires splitting one file into several, which means emitting files — out of contract by
  construction and by the rule's own doc comment.

So this class is manual, and the largest part of it will stay manual even if the capability is
built. What that capability *would* need to refuse is worth knowing anyway, because every item is
a way a hand rename goes wrong:

- the target path already exists;
- a case-insensitive filesystem collision with a file differing only in case;
- the file is named in a manifest `exclude:` or `sources:` list;
- the base key came from the sugar fallback rather than a resolved dotted name;
- a conformance name containing a character illegal in a path component.

---

## Step 2 — the decision tree

Start by reading which arm the diagnostic classified into; the message tells you, and it is the
only thing that decides the required shape.

### Arm 1 — mixed base

```
[extension file naming]: extension file 'X.swift' mixes extensions on different
base types ('A', 'B'); a mixed-base extension file has no lawful name — split
into one file per base type.
```

This is the only arm that is real work rather than a rename. There is no name that describes a
file extending two unrelated types, which is the rule's point: the file has two jobs.

Split it into one file per base type. Then **each new file is itself in this rule's surface**, so
name each one by re-running the classification on it — usually arm 2 or arm 4. Do the split with
`git mv` for the file that keeps the majority of the content so history follows it, and create the
remainder as new files.

Before splitting, check whether the extensions share anything file-scoped — a `private` helper, a
file-scope constant. `private` is file-scoped, so a helper used by both halves stops compiling the
moment they are separated. Promote it to `internal` and give it a home, or duplicate nothing and
put it where it belongs.

### Arm 2 — a conformance is added

```
extension file 'X.swift' must be named '<Base>+<Conformance>.swift' for the
conformance it adds
```

Rename to the shape the message names. This is the derivable arm — the message contains the
answer.

If the file adds several conformances, any one satisfies the rule, so choose the one a reader
would look for. Prefer the conformance that is the file's actual subject over an incidental
`Sendable` or `Equatable` riding along. If the file genuinely adds three unrelated conformances,
consider whether it should be three files — the rule will accept one name, but the reason it
accepts any is that a file usually has one job.

Use the **leaf** spelling of a module-qualified conformance: `Array.Dynamic+Sequence.swift`, not
`Array.Dynamic+Swift.Sequence.swift`.

### Arm 3 — a `where` clause, no conformance

```
extension file 'X.swift' must use the '<Base> where <discriminator>.swift' shape
```

Rename to `<Base> where <discriminator>.swift`. Note the literal spaces around `where`; the shape
is a readable phrase, not a token.

The discriminator is yours to choose, and the rule will accept any non-empty text. Choose the text
that states the constraint the way the constraint is written:

```
extension Array.Dynamic where Element: Comparable   →  Array.Dynamic where Element Comparable.swift
extension Buffer where Element: ~Copyable           →  Buffer where Element NonCopyable.swift
```

Drop the punctuation the filesystem does not want (`:`), keep the words. If the extension carries
several constraints, name the one that distinguishes this file from its siblings — the point is
telling two constrained extensions of the same type apart, not restating the generic signature.

### Arm 4 — member-only

```
extension file 'X.swift' must carry a '+<Topic>' segment naming the member group
(e.g. '<Base>+Topic.swift')
```

Rename to `<Base>+<Topic>.swift`. The topic is yours, and this is where the rule buys the least on
its own and the most from you: it enforces that a topic is *present*, and it cannot tell whether
your topic name is informative.

Name the member group by what the members do, in the domain's vocabulary:

- Good: `Cursor+Advancing.swift`, `Path+Components.swift`, `Buffer+Initialization.swift`.
- Useless but compliant: `Cursor+Extensions.swift`, `Path+Helpers.swift`, `Buffer+Misc.swift`.
  These pass the rule and defeat its purpose; a reviewer should reject them even though the linter
  will not.

If the file holds one member, name the topic after it. The one-extension-per-member convention
produces exactly this shape, and it is why a file named `Type+method.swift` is a house idiom
rather than an over-split.

### The base is a sugar type

The required basename contains brackets or a question mark — `[Int]+Topic.swift`,
`Int?+Topic.swift`. Those characters are legal in a path component on the platforms this ecosystem
targets, but the name is hostile and the shape is a symptom.

Prefer the restructure: an extension of `[Int]` is an extension of `Array<Int>`, and an extension
of a sugar spelling is usually better written against the named type, or moved onto the domain
type that actually owns the operation. Where that is not available, this is a lawful suppression —
see below.

---

## Performing the rename

The rename itself is where the avoidable damage happens.

**Use `git mv`.** It keeps the file's history attached, which matters more here than usual because
a large fraction of this class is being renamed at once and a lost history is not recoverable from
the diff.

**Case-only renames need two steps** on a case-insensitive filesystem, which is the default on
macOS. `git mv Foo.swift foo.swift` may silently do nothing or produce a confusing state; go via a
temporary name.

**Check the manifest before renaming.** If the target declares `exclude:` or an explicit
`sources:` list, a renamed file that is named there stops being compiled — and the build may still
succeed, because the file's contents were extensions the rest of the code did not require to
compile. This is the one failure mode in this rule that a green build does not catch. Search the
manifest for the old basename before you move it, and for the new one after.

**Check that the target path is free**, including a differing-case sibling.

SwiftPM globs `Sources/` by default, so where no `exclude:`/`sources:` list is involved a rename is
invisible to the build. That is what makes this class cheap per finding — and what makes the
manifest check the one thing you must not skip.

---

## Worked examples

### Arm 2 — a topic name where a conformance name is required

`swift-tagged-primitives`,
`Sources/Tagged Primitives Standard Library Integration/Tagged+Literals.swift`:

```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable & ~Escapable, Underlying: ExpressibleByIntegerLiteral { … }

extension Tagged: ExpressibleByFloatLiteral
where Tag: ~Copyable & ~Escapable, Underlying: ExpressibleByFloatLiteral { … }

…                                    // nine conformance-adding extensions in all
```

The basename `Tagged+Literals` has the right *shape* — `<Base>+<something>` — and fires anyway,
because `Literals` is not one of the conformances added. Note also that these extensions carry
`where` clauses and still classify under arm 2: conformance beats `where`.

This is the arm-2 judgment case rather than the mechanical one. Any of the nine conformance names
satisfies the rule, and naming a nine-conformance file after one of them is worse than the name it
has. The honest options are to split into `Tagged+ExpressibleByIntegerLiteral.swift`,
`Tagged+ExpressibleByFloatLiteral.swift` and so on — which is what the one-conformance-per-file
convention would produce anyway and is the recommendation — or, if the nine genuinely belong
together as one unit, to pick the primary conformance and accept that the name under-describes the
file. Do not invent a tenth conformance to name it after.

### Arm 2 — the base is not what the filename says

`swift-ascii-serializer-primitives`,
`Sources/Serializable Integer Primitives/FixedWidthInteger+ASCII.Serializable.swift`:

```swift
extension Int: ASCII.Serializable { … }
extension UInt: ASCII.Serializable { … }
extension Int8: ASCII.Serializable { … }
…
```

The filename names `FixedWidthInteger`, which is the protocol these types all conform to and is
**not the base type of any extension in the file**. The base keys are `Int`, `UInt`, `Int8`, … —
so this is actually arm 1, mixed base, and it has no lawful name at all.

The fix is the split: one file per concrete type, each named `<Type>+ASCII.Serializable.swift`.
That is more files, and it is also the only arrangement in which the file tree tells you where
`Int`'s ASCII serialization lives.

### Arm 4 — member-only with no topic

`swift-bit-index-primitives`, `Sources/Bit Index Primitives/Bit.Index.swift`, whose entire
top-level content is:

```swift
extension Bit {
    /// A position in a bit collection.
    public typealias Index = Index_Primitives.Index<Bit>
}
```

No conformance and no `where`, so arm 4. The base is `Bit`; the basename `Bit.Index` does not start
with `Bit+`, so it fires. Required: `Bit+<Topic>.swift`.

This one is worth sitting with, because the instinct is that the file is already well named — it
declares `Bit.Index` and it is called `Bit.Index.swift`. But it does not *declare* `Bit.Index` in
the sense the file tree uses: a `typealias` is not a primary nominal type, so the file is an
extension-only file, and `Bit.Index.swift` is exactly the name the real declaration of a nested
`Index` type would want. Renaming to `Bit+Index.swift` keeps that name free and says what the file
is:

```sh
git mv "Sources/Bit Index Primitives/Bit.Index.swift" \
       "Sources/Bit Index Primitives/Bit+Index.swift"
```

### Arm 1 — mixed base

`swift-order-primitives`,
`Sources/Order Primitives Standard Library Integration/Order.Orderable+Swift.Comparable.swift`:

```swift
extension Int: Order.Orderable {}
extension UInt: Order.Orderable {}
extension Int8: Order.Orderable {}
…                                    // fourteen base types in all
```

Fourteen base keys, so no lawful name — and the current name is doubly wrong, since
`Order.Orderable` is the conformance rather than the base and `Swift.Comparable` appears nowhere.

The lawful shape is one file per base type: `Int+Order.Orderable.swift`,
`UInt+Order.Orderable.swift`, and so on. Fourteen one-line files feels like a lot for fourteen
empty conformance declarations, and that reaction is worth naming: the rule's position is that a
file's name is how the tree is searched, and a file that answers for fourteen types answers for
none of them. If the conformances genuinely belong in one place, the alternative is a single
generic conformance — `extension FixedWidthInteger: Order.Orderable` — which is one base and one
file, and is a design change rather than a rename.

Note that a split of one mixed-base file into fourteen well-named ones removes **one** finding, not
fourteen: the rule reports per file.

### The conditional-conformance trap

```swift
extension Array.Dynamic: Swift.Equatable where Element: Swift.Equatable { … }
```

This has a `where` clause, but it **adds a conformance**, and arm 2 is checked first. The required
name is `Array.Dynamic+Equatable.swift` — not `Array.Dynamic where Element Equatable.swift`, which
would still fire.

---

## Suppression: the lawful shapes

Per [remediation-mechanics.md §3](remediation-mechanics.md#3-suppress-only-where-the-shape-is-lawful-and-always-with-a-reason).
The directive goes at the file's first extension declaration, where the diagnostic is located:

```swift
// swift-linter:disable:next extension file naming
// REASON: the base is the sugar spelling `[Int]`, for which the rule's computed
// basename is `[Int]+Topic.swift`. The bracket characters make that name hostile
// to tooling; the operations are being moved onto the owning domain type instead.
extension [Int] { … }
```

```swift
// swift-linter:disable:next extension file naming
// REASON: this file is generated; its name is fixed by the generator and a rename
// here would be overwritten on the next run.
extension Descriptor { … }
```

These do **not** qualify: "renaming loses git history" — use `git mv`, which does not; "the topic
would be arbitrary" — if no topic describes the member group, the group is the problem, and arm 1's
reasoning applies; "there are too many files to rename in this package" — that is a scheduling
fact, and this is the cheapest per-finding class in the top five.

**Do not suppress arm 1.** A mixed-base file has no lawful name, and suppressing it records that
the file should keep doing two jobs. Split it.

---

## Verification

Per [remediation-mechanics.md §5](remediation-mechanics.md#5-verify-per-finding-and-verify-the-whole-file):

```sh
workspace package lint  --package-path <package>
workspace package build --package-path <package>
```

Three rule-specific checks, in decreasing order of how easily they are missed:

1. **The file is still being compiled.** A rename that dropped a file out of an `exclude:`/
   `sources:` list can leave the build green while removing code from it. Confirm the package's
   compiled file count is unchanged, not merely that the build succeeded.
2. **`git status` shows a rename, not a delete plus an add.** If it shows the latter, the history
   did not follow and it is worth redoing.
3. **The count fell by exactly one per file.** This rule reports **one finding per file**,
   whichever arm it classified into and however many extensions the file holds — so a file with
   six extensions contributes one, and a split of one mixed-base file into three well-named files
   removes one finding, not three.

---

## Honest limitations

- **The rule checks shape, not vocabulary.** `Foo+Extensions.swift` and `Foo+Misc.swift` are fully
  compliant and tell a reader nothing. Getting this class to zero improves the file tree only to
  the extent that the topics chosen are informative, and that part is entirely on the person
  renaming.
- **The excluded surface is large.** Files declaring a top-level type are out of scope here, so a
  package can be clean on this rule while its file organization is poor in ways `single type per
  file` and `file name nested path` own instead.
- **`Tests`, `Experiments`, and `Examples` are excluded**, so the ledger count is a statement about
  `Sources/` only.
