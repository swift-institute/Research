# Operation-Domain Naming and Organization

<!--
---
version: 1.0.1
last_updated: 2026-05-26
status: DECISION
tier: 3
scope: ecosystem-wide
changelog:
  - "1.0.1 (2026-05-26): naming: bulk tier Iterator.Span/Contiguous → Iterator.Chunk (+ module Iterator_Chunk_Primitives / protocol __IteratorChunkProtocol); Memory.Contiguous.Iterator example → Memory.Contiguous. Manner example (§7.1/§7.2/§9), the §6 hoisting worked example, and the §7.3/§9.3 package tier updated to the final Chunk name; Swift.Span (stdlib payload), Iterator.Borrow (keep-and-lend), and the Memory.Contiguous subject left untouched."
supersedes:
  # Fully superseded — primary content is the operation-domain naming/organizing rule, absorbed here:
  - agent-witness-attachable-pattern.md
  - agent-witness-attachable-pattern-triage.md
  - package-namespace-noun-convention.md
  - canonical-attachment-semantic.md
  - canonical-witness-capability-attachment.md
  - sibling-refines-canonical-attachment.md
  - parsing-serialization-capability-organization.md
  - mutator-naming-protocol-and-typealias.md
  # Naming content absorbed; orthogonal (non-naming) content preserved in the source doc + git:
  - byte-primitive-extraction-and-domain-naming.md   # [API-NAME-001b] absorbed; byte→L1 extraction is executed history
  - ascii-parsing-domain-ownership.md                # subject-first exemplar absorbed; ASCII domain-ownership stands
  - nested-protocols-in-generic-types.md             # hoisting mechanism absorbed (§6); compiler-limitation finding preserved here
not_superseded_different_subtopic:
  - value-generic-parameter-naming-convention.md     # value-generic PARAMETER naming — a different axis
  - stdlib-naming-beats-ecosystem-naming.md          # shadowed-API naming (the swapAt question) — different, and IN_PROGRESS
  - unified-iteration-design.md  # witness decision overridden (§5.1); Sequence/Sequencer classification deferred to the protocol-architecture piece
---
-->

> **This is the definitive, final statement of how the Swift Institute names and
> organizes operation-domain packages.** It supersedes every prior document in
> the naming/organizing corpus (see frontmatter). Where those documents
> conflicted, this document governs. The prior documents are retained in place
> and marked `status: SUPERSEDED` per `[META-005]` (no `_archived/`; the
> `_index.json` filter hides them from the active view); nothing below needs
> them to be read.
>
> **Out of scope** (a different axis — the protocol's *contract*, not its
> *name*): `collection-sequence-protocol-detachment`, `iterator-protocol-hierarchy`,
> `sequence-iterator-protocol-architecture`, `iterable-iteration-terminal-surface`,
> `two-world-traversal-decomposition`. Those decide what protocols *require*;
> this decides what they are *called* and where they *live*.

---

## 0. TL;DR

An **operation domain** is a package whose primary export is a capability
derived from a verb — a parser, an iterator, a hash. Name and organize it from
exactly four grammatical forms, each bound to one role:

| Role | Form | Example (iterate) | Example (parse) |
|------|------|-------------------|-----------------|
| **Namespace / package** | agent noun (machines) or deverbal noun (relations) — a non-generic `enum`; **never a gerund** | `enum Iterator` | `enum Parser` |
| **Active protocol** (the machine conforms) | `Namespace.Protocol` (backtick-escaped) + top-level gerund alias | `Iterator.Protocol` / `typealias Iterating` | `Parser.Protocol` / `typealias Parsing` |
| **Passive protocol** (the data conforms) | top-level `-able` adjective | `Iterable` | `Parseable` |
| **Witness** (type-erased value) | nested `Namespace.Witness` + optional gated result-noun alias | `Iterator.Witness` / `typealias Iteration` | `Parser.Witness` |

Then:

- **Specialize subject-first**: `Byte.Parser`, `Memory.Cursor` — the subject owns the namespace.
- **Nest manner-variants role-owns**: `Iterator.Borrow`, `Iterator.Chunk` — the operation owns; split into its own package only when the variant pulls a dependency the core shouldn't carry.
- **Order by the subject-vs-manner discriminator**: data the operation processes → subject-first; a way the operation behaves → role-owns.

The whole convention reduces to: **the agent noun is the namespace; the gerund
is the active protocol's readable alias; the `-able` adjective is the passive
protocol; the witness is `X.Witness`.**

---

## 1. Context

Package and namespace naming, capability-protocol naming, witness placement, and
domain-ordering had each been settled piecemeal across a dozen-plus research
documents (the agent-witness-attachable triple, the noun/gerund convention, the
subject-first ordering rule, the capability-attachment cluster, the sequencer
rename). The documents broadly agreed but diverged on the load-bearing detail —
**where the witness lives** — and used "witness" to mean two different things.
The sprawl made the convention impossible to apply without reading the whole
corpus and reconciling it by hand.

This document is the single normative source. It was produced by re-deriving the
convention from first principles against the live package corpus (183 packages,
surveyed 2026-05-26), reconciling the result with every prior document, and
making the one override the re-derivation forced (the witness; see §5).

**Trigger**: a principal request (2026-05-26) for a definitive piece superseding
all prior naming/organizing work, to be processed into the `swift-package` and
`code-surface` skills.

**The convergence, in one sentence**: every operation domain has the same four
grammatical forms available (agent noun, gerund, `-able` adjective, deverbal
result-noun), and the only question is which form fills which role — a question
that has a single deterministic answer.

---

## 2. Scope — what is an "operation domain"?

An operation domain is a package whose primary export is a **capability derived
from a verb** — expressed as a protocol, with conformers and a type-erased
witness. Two sub-classes:

| Sub-class | Carries per-step mutable state you drive? | Examples |
|-----------|-------------------------------------------|----------|
| **Machine** (stream-processing) | Yes — a cursor, a position, an accumulator | `Parser`, `Serializer`, `Coder`, `Formatter`, `Iterator`, `Lexer`, `Cursor` |
| **Relation / value** (stateless) | No — a pure relation, function, or result | `Hash`, `Comparison`, `Equation`, `Render`, `Transform` |

This document does **not** govern:

- Pure value-type domains with no verb-capability (`Buffer`, `Geometry`, `Time`, `Cardinal`) — they follow `[PKG-NAME-001]` noun rules but have no agent/witness/attachable triple.
- Group-A capability-*marker* protocols (`Byte.Protocol`, `Cardinal.Protocol`) — governed by `[API-NAME-001c]`, a distinct recipe.
- A protocol's **contract** (what methods it requires, what it inherits, `~Copyable`/`~Escapable` support) — that is the protocol-architecture axis, out of scope (see header).

---

## 3. The namespace — agent noun for machines, deverbal noun for relations

**Rule.** The package and its top-level Swift namespace take a **noun** form,
declared as a non-generic `enum` (so the protocol and all nested types resolve
without a generic-binding tax — see §6). Gerund namespaces are **forbidden**
(retained from `[PKG-NAME-001]`). The noun is chosen by sub-class:

- **Machine** → the **agent noun** (`-er`/`-or`): `Parser`, `Serializer`, `Coder`, `Formatter`, `Iterator`, `Lexer`, `Cursor`.
- **Relation / value** → the **deverbal or plain noun**: `Hash`, `Comparison`, `Equation`, `Render`, `Transform`.

> **Deferred — `Sequence` / `Sequencer`.** Whether `swift-sequence-primitives` is a relation (`Sequence` — iterable data that vends an iterator) or a machine (`Sequencer` — agent noun), and indeed whether sequence is a standalone domain or a facet of iteration, depends on the protocol *contract* (consuming-vs-borrowing `makeIterator`, the World-A `Iterable` / World-B `Sequenceable` split) — the protocol-architecture axis this doc fences out (see header). This doc does **not** classify it; the `Sequencer` lock (2026-05-25) stands until the protocol-architecture piece resolves it. The discriminator *leans* relation (the `Iterator` it vends is the machine; `Sequence` resembles the passive `Iterable`), recorded as that piece's starting hypothesis per §11.

**Discriminator.** *Does the type carry mutable per-step state you drive
(machine → agent noun), or is it a stateless relation/value (→ plain noun)?*

**Why the agent noun for machines — the `Cursor` proof.** The agent noun is the
*only universally available* form for the machine class. `Cursor` has no gerund
("cursoring" is not a word) and no distinct deverbal noun (a "cursor" *is* the
noun). A machine like `parse` has no first-class noun either ("a parse" is
verb-derived and marginal; "parsing" is a gerund, forbidden). The agent noun is
the single form *every* machine domain possesses. Anchoring the class on its
least-flexible member (`Cursor`) locks the whole machine family to agent nouns —
which is exactly what the corpus already does.

`[Verified: 2026-05-26]` — the live corpus uses agent nouns for every machine
domain (`swift-parser-primitives`, `swift-serializer-primitives`,
`swift-coder-primitives`, `swift-formatter-primitives`, `swift-iterator-primitives`,
`swift-lexer-primitives`, `swift-cursor-primitives`) and deverbal/plain nouns for
relation domains (`swift-hash-primitives`, `swift-comparison-primitives`,
`swift-equation-primitives`, `swift-render-primitives`,
`swift-transform-primitives`). The rule ratifies what exists; it is not a
migration. (`swift-sequence-primitives` is deferred — see the note above.)

**Consequence — there is no deverbal-noun namespace for machines.** `Iteration`
is *not* the iterator namespace. `Parsing` is *not* the parser namespace. The
machine namespace is the agent noun; the deverbal noun, where it exists, is
reserved for the witness alias (§5).

---

## 4. The two protocols — active (`-ing`) and passive (`-able`)

Every operation domain has **two distinct capabilities with different
conformers**, and they must not be conflated:

| | Conformed by | Reads | Carries | Canonical name |
|--|--------------|-------|---------|----------------|
| **Active** | the *machine* (a concrete parser, a combinator, the witness) | "*is* parsing" (present participle — the doer) | the operation method (`parse`, `next`) + composition | `Namespace.Protocol` |
| **Passive** | the *data* (`Int`, `Date`, a collection) | "*can be* parsed" (adjective — the done-to) | a reference to its canonical machine | `<Verb>able` |

### 4.1 Active protocol — `Namespace.Protocol` + gerund alias

The active protocol is declared **nested in the namespace enum**, named
`Protocol` (backtick-escaped, because `Protocol` is reserved):

```swift
public enum Iterator {}
extension Iterator {
    public protocol `Protocol`<Element, Failure>: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable & ~Escapable
        associatedtype Failure: Swift.Error = Never
        mutating func next() throws(Failure) -> Element?
    }
}
```

A **top-level gerund alias** is exported as the readable conformance surface:

```swift
public typealias Iterating = Iterator.`Protocol`
public typealias Parsing   = Parser.`Protocol`
```

The gerund alias is the form written at conformance and constraint sites,
because it reads as English where the backticked form does not:

```swift
struct JSONTokens: Iterating { … }                       // "is iterating" — natural
func drive<I: Iterating>(_ i: inout I) where I.Element == Int { … }
```

`Namespace.Protocol` remains the canonical declaration the alias targets, and is
used where `Iterating` would be ambiguous. This is the only sanctioned use of a
gerund (`[PKG-NAME-002]`): it names the *active capability reading*, never a
namespace.

### 4.2 Passive protocol — `<Verb>able`

The passive (attachable) protocol is **top-level**, named verb-stem + `able`,
and declares "this value type has a canonical machine":

```swift
public protocol Parseable {
    associatedtype Parser: Parser_Primitives_Core.Parser.`Protocol`
    static var parser: Parser { get }
}
public protocol Iterable: ~Copyable, ~Escapable {
    associatedtype Iterator: Iterating
    @_lifetime(borrow self) borrowing func makeIterator() -> Iterator
}
```

Accessor shape (static vs instance) follows whether the canonical machine is
type-level or value-level: `static var parser` (the parser for `Date` is the
same for every `Date`), `var serializer` / `makeIterator()` (value-dependent).

**The `-ing`/`-able` split is active/passive voice.** This is the same
distinction the standard library draws with `Encoder`(machine) / `Encodable`(value)
and `Hasher`(machine) / `Hashable`(value); the Institute makes it regular by
pairing a gerund-aliased active protocol with an `-able` passive protocol for
every domain.

### 4.3 Attachment is flat, not refining

Format-specific sibling protocols (`JSON.Serializable`, `Binary.Parseable`) are
**flat peers** of the canonical attachable, not refinements of it (absorbed from
`[FAM-010]`). A type's conformance to the canonical attachable carries a
*type-commitment* semantic — one inherent canonical machine per spec-value type
(absorbed from the canonical-attachment-semantic analysis). These remain true;
they are properties of the passive protocol, orthogonal to its naming.

---

## 5. The witness — `Namespace.Witness`, with a gated result-noun alias

A **witness** here means *the type-erased, closure-backed struct that conforms
to the active protocol* — the value you hold when you need "a parser" without
committing to a concrete conforming type.

> **Terminology (disambiguation).** "Witness" in this document is always the
> type-erased struct (`Parser.Witness`). Named canonical *instances* — static
> properties like `UInt32.bigEndianParser` — are **instances**, not "the
> Witness." The prior corpus used "witness" for both; this document does not.

**Rule.** The canonical witness is **nested** as `Namespace.Witness`:

```swift
extension Iterator {
    public struct Witness<Element, Failure: Swift.Error>: Iterator.`Protocol`, ~Copyable {
        @usableFromInline var _next: () throws(Failure) -> Element?
        @inlinable public init(_ next: @escaping () throws(Failure) -> Element?) { self._next = next }
        @inlinable public mutating func next() throws(Failure) -> Element? { try _next() }
    }
}
```

### 5.1 Override of the top-level-verb witness

This **supersedes** the prior convention (the agent-witness-attachable pattern
and the principal-locked-2026-05-25 sequencer draft), which placed the witness
top-level under the bare verb (`Parse`, `Iterate`, `Sequence<E>`) with a
"method-stem divergence" sub-rule. The override is deliberate and rests on three
findings:

1. **The stated justification was vacuous.** The pattern doc justified
   top-level placement as avoiding a "generic-binding tax." But the namespace is
   a non-generic `enum`; nesting `Iterator.Witness<E, F>` incurs *no* tax
   (`[Verified: 2026-05-26]` — `/tmp` `swiftc -typecheck` spike: a struct nested
   in a non-generic enum has no binding obligation). The justification does not
   hold.
2. **Top-level verbs reintroduce collisions and special-casing.** `Format`
   collides with the format-descriptor namespace; `Sequence` collides with
   `Swift.Sequence`; the verb-as-noun (`Iterate`) reads as a command and forced
   the "method-stem divergence" exception. `Namespace.Witness` dissolves all of
   it — no collisions, no exception, one uniform name.
3. **It's already the majority.** `Parser.Witness`, `Serializer.Witness`,
   `Coder.Witness` were never promoted to top-level (`[Verified: 2026-05-26]`).
   The deviations were `Iteration` (iterator) and `Format` (formatter); this
   rule fixes them, it doesn't introduce churn.

The sequencer draft's locked `Sequence<E>` witness becomes `Sequencer.Witness`
— which also removes the `Swift.Sequence` collision the draft accepted. (The
draft was locked but not executed, so the override costs nothing.)

### 5.2 The result-noun alias (gated)

A single top-level alias MAY be added, naming the witness with the operation's
**result-noun** — exempt from `[API-NAME-004a]`'s rename-bridge prohibition —
**iff** all four gates clear:

1. the **deverbal result-noun** of the operation (`iterate → Iteration`, `serialize → Serialization`), derived mechanically — not a gerund, not a bare verb;
2. a **first-class English noun**;
3. **free** in the ecosystem (does not shadow a stdlib type or another package's namespace);
4. the **only** alias for that witness.

```swift
public typealias Iteration     = Iterator.Witness        // ✓ clean, free noun
public typealias Serialization = Serializer.Witness      // ✓
```

Where no noun clears the gates, the witness has **no** alias and consumers use
`Namespace.Witness`:

| Domain | Witness | Result-noun alias | Why |
|--------|---------|-------------------|-----|
| iterate | `Iterator.Witness` | `typealias Iteration` ✓ | clean, free noun |
| serialize | `Serializer.Witness` | `typealias Serialization` ✓ | clean, free noun |
| parse | `Parser.Witness` | — | "parse" is verb-only |
| code | `Coder.Witness` | — | "Code" overloaded / "Encoding" gerund |
| format | `Formatter.Witness` | — | "Format" is taken (descriptor namespace) |
| lex | `Lexer.Witness` | — | no deverbal noun |
| cursor | `Cursor.Witness` | — | no deverbal noun |

The alias is *additive sugar* whose presence is predictable from the gates, not
chosen case-by-case. It is the witness-side twin of the gerund protocol alias:
the gerund names the capability you *conform to*; the result-noun names the
value you *hold*.

---

## 6. The hoisting mechanism (absorbed)

Swift forbids nesting a protocol inside a *generic* type (hard compiler error,
no bypass — absorbed from the nested-protocols analysis). This shapes where
protocols live:

- **Top-level protocol — no hoisting.** Because the namespace is a non-generic
  `enum`, `Iterator.Protocol` nests *directly*. No `__`-hoist is needed at the
  namespace level.
- **Sub-protocol under a generic sub-type — hoist.** A protocol under a generic
  member (e.g. the bulk tier's `Iterator.Chunk<Element>.Protocol`)
  must be hoisted to module scope and re-exported via a param-free typealias:

  ```swift
  public protocol __IteratorChunkProtocol<Element, Failure>: Iterator.`Protocol` { … }
  extension Iterator.Chunk {
      public typealias `Protocol` = __IteratorChunkProtocol
  }
  ```

  `Iterator.Chunk.Protocol` then resolves **unbound** — because the top
  namespace is non-generic (you reach `.Chunk` without binding) and the
  typealias's right-hand side does not mention the sub-type's parameters.
  `[Verified: 2026-05-26]` — `/tmp` spike: a depth-1 param-free typealias on an
  unbound generic resolves; a depth-2 path resolves *only* when the top
  namespace is non-generic. This is precisely why §3 mandates a non-generic enum
  namespace.

---

## 7. Specialization and variants — the ordering axes

### 7.1 Subject-first vs role-owns

A type at the intersection of an operation and another token is ordered by
**what the token is** (absorbed and generalized from `[API-NAME-001b]`):

| Leading token is… | Linguistic test | Ordering | Package owner |
|-------------------|------------------|----------|---------------|
| **A subject** — the data/value/format the op processes | "operate *on the* ___" → *parse the bytes*, *iterate the memory* | **subject-first** `Subject.Op` | the subject |
| **A manner** — *how* the op behaves (a mode/shape/adverb) | "operate ___*-ly*" → *iterate borrowingly*, *iterate in bulk* | **role-owns** `Op.Manner` | the operation |

- **Subject-first** (`[API-NAME-001b]`): `Byte.Parser`, `ASCII.Parser`,
  `Memory.Cursor`, `Binary.Coder`. The subject owns the package; the operation
  is the leaf. `[Verified: 2026-05-26]` — `swift-byte-parser-primitives`,
  `swift-ascii-parser-primitives`, `swift-memory-cursor-primitives`,
  `swift-binary-coder-primitives` all exist in this shape.
- **Role-owns**: `Iterator.Borrow`, `Iterator.Chunk`, `Parser.Many`,
  `Parser.OneOf`. The operation owns; the manner is a nested variant.

**Concept before word.** The same concept can resolve either way depending on
whether you are naming the *manner* or the *subject*. "Iteration that yields
contiguous chunks" is a *manner* (`Iterator.Chunk`); "the contiguous-memory
region itself" is a *subject* (`Memory.Contiguous`). Decide the concept first;
the ordering follows. A token that *could* name a subject (`Memory`, `Span`,
`Contiguous`) must not pull you into subject-first when you are modeling a
manner-variant — which is precisely why the bulk tier is named for *what it
does* (`Chunk`), leaving `Contiguous` to the memory subject.

The ownership tell confirms it: role-owns means the operation package depends
*down* onto the mode (iteration → ownership); subject-first means the subject
package depends *up* onto the operation (byte → parser). If `Borrow.Iterator`
would put a borrowing iterator in the ownership repo, that is the smell telling
you `Borrow` is a manner, not a subject — so it is `Iterator.Borrow`.

### 7.2 Manner-variant naming uses the noun

Manner-variants take the **noun** form, not the gerund: `Iterator.Borrow` (not
`Iterator.Borrowing`), `Iterator.Chunk`. This supersedes the `Borrowing`
spelling wherever it appears in the prior corpus.

### 7.3 When a variant becomes its own package

A manner-variant is a **target** within the operation package by default. It is
promoted to its **own package** only when it pulls a dependency the core should
not carry:

| Tier | Package | Reuses | Dep beyond core |
|------|---------|--------|-----------------|
| core | `swift-iterator-primitives` | — | none |
| borrow | `swift-iterator-borrow-primitives` | `Ownership.Borrow` (one borrowed element) | `swift-ownership-primitives` |
| chunk | `swift-iterator-chunk-primitives` | `Swift.Span` (many borrowed, contiguous) | `swift-cardinal-primitives` |

`[Verified: 2026-05-26]` — `swift-iterator-borrow-primitives` exists and reuses
`Ownership.Borrow<Borrowed>` as its element type (`Iterator.Borrow.Protocol`
where `Element == Ownership.Borrow<Borrowed>`), confirming the pattern: the
borrow tier became its own package *because* it depends on
`swift-ownership-primitives`. The borrow and chunk tiers are
cardinality-siblings — one borrowed element vs many borrowed contiguous elements
— each reusing the canonical borrow-type for its cardinality.

> **Cleanup note.** `swift-borrowing-iterator-primitives` was an empty stub
> duplicating `swift-iterator-borrow-primitives`; it has since been **removed**
> from disk (`[Verified: 2026-05-26]` — absent). No action remains.

---

## 8. The deterministic decision procedure

Given a new operation domain `V`:

1. **Classify.** Stateful machine, or stateless relation/value? (§3 discriminator.)
2. **Namespace** = agent noun (machine) or deverbal/plain noun (relation), as a non-generic `enum`. Never a gerund.
3. **Active protocol** = `Namespace.Protocol` (nested directly; the enum is non-generic) + top-level gerund alias `typealias <Ving> = Namespace.Protocol`.
4. **Passive protocol** = top-level `<V>able`; static accessor if the machine is type-level, instance accessor if value-level.
5. **Witness** = `Namespace.Witness`; add `typealias <ResultNoun> = Namespace.Witness` iff the four gates of §5.2 clear.
6. **Specializations**: a data-subject specialization is subject-first (`Subject.V`); a manner-variant is role-owns (`V.Manner`), noun-form, in its own package iff it pulls a new dep.
7. **Sub-protocols under generic members**: hoist (`__VManerProtocol`) + param-free typealias (§6).

Every step is mechanical given the classification in step 1.

---

## 9. Worked examples

### 9.1 Iterator (machine, full instantiation)

```swift
public enum Iterator {}                                   // §3 agent noun, non-generic enum
extension Iterator {
    public protocol `Protocol`<Element, Failure>: ~Copyable, ~Escapable { … }   // §4.1 active
    public struct Witness<Element, Failure: Swift.Error>: Iterator.`Protocol`, ~Copyable { … }  // §5
}
public typealias Iterating = Iterator.`Protocol`          // §4.1 active alias
public typealias Iteration = Iterator.Witness             // §5.2 result-noun alias (gates clear)
public protocol Iterable: ~Copyable, ~Escapable { … }     // §4.2 passive

// §7.3 manner-variant tiers, role-owns, own packages by dep footprint:
//   Iterator.Borrow  (swift-iterator-borrow-primitives,  reuses Ownership.Borrow)
//   Iterator.Chunk   (swift-iterator-chunk-primitives,   reuses Swift.Span)
```

Reads: `let it: Iteration = …` (the value), `T: Iterating` (a machine),
`T: Iterable` (data). The migration from today's state is small: rename the
top-level `struct Iteration` to `Iterator.Witness` and re-add
`typealias Iteration = Iterator.Witness`; correct `Iterator.Borrowing` →
`Iterator.Borrow`.

### 9.2 Parser (machine, no result-noun alias)

```swift
public enum Parser {}
extension Parser {
    public protocol `Protocol`<Input, Output, Failure>: ~Copyable { … }
    public struct Witness<Input, Output, Failure: Swift.Error>: Parser.`Protocol` { … }
}
public typealias Parsing = Parser.`Protocol`
// no result-noun alias — "parse" is verb-only (§5.2 gate 1/2 fail)
public protocol Parseable { associatedtype Parser; static var parser: Parser { get } }

// subject specializations (§7.1, subject-first):
//   Byte.Parser, ASCII.Parser, Binary.Parser  (each in its subject's package)
```

### 9.3 The chunk tier (manner-variant, naming the payload correctly)

The bulk tier yields `Swift.Span<Element>`. It is named for its *manner*
(`Chunk` — it lends a chunk/batch per step), not its *payload* (`Span` — which
would collide with `Swift.Span`) and not `Contiguous` (which is reserved for the
memory *subject* `Memory.Contiguous`):

```swift
// swift-iterator-chunk-primitives
public protocol __IteratorChunkProtocol<Element, Failure>: Iterator.`Protocol`, ~Copyable, ~Escapable
where Element: Escapable {
    @_lifetime(&self)
    mutating func next(maximumCount: some Carrier.`Protocol`<Cardinal>) throws(Failure) -> Swift.Span<Element>
}
extension Iterator {
    public struct Chunk<Element: ~Copyable & ~Escapable, Failure: Swift.Error>: __IteratorChunkProtocol
    where Element: Escapable { … }
}
extension Iterator.Chunk { public typealias `Protocol` = __IteratorChunkProtocol }  // §6 hoist
```

---

## 10. Prior-art survey (`[RES-021]`)

Every surveyed ecosystem names packages/modules with nouns (or `-able`
adjectives for capability protocols); none uses gerunds as the primary form:

- **Swift / Apple**: `Foundation`, `Combine`, `Network`; protocols `Sequence`,
  `Collection`, `Encodable`, `Hashable` (nouns and `-able`). Machines as agent
  nouns: `Encoder`, `Decoder`, `Hasher`. Point-free's community `swift-parsing`
  ships a `Parsing` *module* — the one prominent gerund-module counter-example,
  noted but not adopted (it conflicts with the noun rule).
- **Rust**: crates `serde`, `tokio`; traits `Iterator`, `Read`, `Write` (agent
  nouns), `IntoIterator` (`-able`-equivalent).
- **Haskell**: `containers`, `bytestring`; classes `Functor`, `Monad`,
  `Traversable` (agent nouns and `-able`).
- **Go**: `fmt`, `io`, `sort` (short nouns / verb-roots); interfaces `Reader`,
  `Writer` (agent nouns).

**Contextualization (`[RES-021]`).** The Institute's one departure from "use the
stdlib's exact form" is the gerund *alias* on the active protocol — stdlib uses
agent-noun protocols (`Encoder`), the Institute uses an agent-noun *namespace*
plus a gerund *alias* (`Parser` + `Parsing`). The departure is forced: the agent
noun is needed for the namespace (to host the combinator family as nested types
with no binding tax), so the active protocol's English reading is recovered via
the gerund alias rather than by naming the protocol with the agent noun. This is
strictly additive and costs one typealias per domain.

---

## 11. Outcome

**Status**: DECISION (2026-05-26).

The convention is as stated in §0–§8. It supersedes the documents listed in the
frontmatter; those are marked SUPERSEDED with a pointer here and retained for
history. The one override against prior (locked) work is the witness placement
(§5.1), authorized by the principal 2026-05-26.

**Promotion to skills** (`[RES-006a]`). This document is the provenance for:

- `swift-package` skill:
  - `[PKG-NAME-001]` — namespace = agent noun (machines) / deverbal noun (relations); gerund forbidden.
  - `[PKG-NAME-002]` — `Namespace.Protocol` active protocol + gerund alias.
  - `[PKG-NAME-005]` — shortest natural noun (tiebreak).
  - **new** — witness rule: canonical `Namespace.Witness` + gated result-noun alias (exempt from `[API-NAME-004a]`).
- `code-surface` skill:
  - `[API-NAME-001b]` — extended with the subject-vs-manner discriminator and the concept-before-word ordering step.
  - `[API-NAME-004a]` — extended with the witness result-noun-alias exemption.
  - `[API-NAME-001c]` — unchanged (capability-marker recipe, distinct family; cross-referenced).

**Out of scope, flagged for a possible second definitive piece**: the
protocol-*contract* axis (inheritance, `~Copyable`/`~Escapable` support,
consuming-vs-borrowing semantics) governed by the protocol-architecture
documents listed in the header.

**Lead question for that piece — `Sequence` vs `Sequencer`.** Its starting
hypothesis (recorded here, not decided): the §3 discriminator *leans relation*
— `Sequence` vends an `Iterator`, so the `Iterator` is the machine and
`Sequence` resembles the passive `Iterable`; stdlib uses `Sequence` for exactly
this and "sequencer" connotes an agent that *imposes* order, which mis-describes
an ordered series. The strongest counter is naming-symmetry with the
agent-noun machine family (`Sequencer` parallels `Iterator`/`Parser`); but per
`[RES-029]`, semantic identity ("what the thing is") outranks aesthetic symmetry
("what's parallel"). The `Sequencer` lock (2026-05-25) stands until that piece
resolves it against the actual protocol contract; this naming doc does not
reverse it.

## 12. References

- `swift-package` skill — `[PKG-NAME-*]`
- `code-surface` skill — `[API-NAME-*]`, `[API-IMPL-009]` (hoisted-protocol pattern)
- `[Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)`
- pointfree `swift-parsing` (`Parsing` module — the gerund-module counter-example)
- Superseded sources (retained in place, `status: SUPERSEDED` per `[META-005]`): see frontmatter `supersedes`.
