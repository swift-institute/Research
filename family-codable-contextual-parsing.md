# Family-Codable Contextual Parsing

<!--
---
version: 1.0.0
last_updated: 2026-06-29
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
governing_conventions:
  - 2026-05-15-family-codable-convention.md            # [FAM-001..009] sibling shape + placement (ecosystem-wide)
  - swift-foundations/swift-json/Research/family-codable-convention.md  # [FAM-001..008] canonical per-package, incl. [FAM-007] sub-sibling carve-out
originating_deferral:
  - ascii-domain-evergreen-end-state.md                # v1.3.0 § "W3 Execution Decisions" → OQ2 (the DEFERRED context gap this doc resolves)
---
-->

> **Headline recommendation**: Keep **concrete-API-only (status quo)** now — no protocol-level context mechanism is built during or after W3. **If** a genuine polymorphic need ever materializes, the correct shape is a **[FAM-007] context-bearing sub-sibling** (a refinement of the flat read marker carrying `associatedtype Context: Sendable = Void`), **NOT** an `associatedtype` on the flat top-level `ASCII.Parseable` / `Binary.Parseable` marker (which [FAM-001] forbids). This vindicates the deprecated protocol's *actual* structure (itself a sub-sibling) while correcting the W3 deferred note's literal wording.

## Context

The family-Codable system ([FAM-001..009]) uses flat top-level sibling marker protocols to mark a type as readable/writable as bytes for a given format:

- `ASCII.Parseable` — flat empty marker `public protocol Parseable {}` (`swift-ascii-parser-primitives/Sources/Parseable ASCII Primitives/ASCII.Parseable.swift:32`), explicitly citing [FAM-001/006].
- `ASCII.Serializable` — flat empty marker `public protocol Serializable {}` (`swift-ascii-serializer-primitives/Sources/Serializable ASCII Primitives/ASCII.Serializable.swift:35`).
- `Binary.Parseable` — carries one method, **no** associated type: `static func parse<Source: RangeReplaceableCollection>(from source: inout Source) throws(Binary.Parse.Failure) -> Self where Source.Element == Byte` (`swift-binary-parser-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift:61-76`). This is a **streaming/cursor** read.

Five real conformers need **out-of-band context** to parse from bytes (all `[Verified: 2026-06-29]`, file:line from `ascii-domain-evergreen-end-state.md` v1.3.0 OQ2 table + direct read):

| Conformer | Context type | Read witness (whole-buffer `init(ascii:in:)`) |
|---|---|---|
| `WHATWG_URL.URL` | `ParsingContext { base: URL? }` | `swift-whatwg-url/Sources/WHATWG URL/WHATWG_URL.URL+Serializable.swift:168` |
| `WHATWG_URL.URL.Host` | `Context { isSpecial: Bool }` | `WHATWG_URL.URL.Host.swift:107` |
| `WHATWG_URL.URL.Path` | `Context { isOpaque: Bool }` | `WHATWG_URL.URL.Path.swift:60`; context type `WHATWG_URL.URL.Path.Context.swift:10` |
| `RFC_2046.Multipart` | `Context { boundary: RFC_2046.Boundary, subtype }` | `RFC_2046.Multipart.swift:330` |
| `RFC_2387.Related` | `Context { boundary }` | `RFC_2387.Related.swift:321` |

The **deprecated** `Binary.ASCII.Serializable` supplied this via two associated types and a whole-buffer context init (`swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift:17-34`):

```swift
public protocol Serializable: Binary.Serializable {            // a SUB-SIBLING: refines Binary.Serializable
    static func serialize<Buffer: RangeReplaceableCollection>(ascii serializable: Self, into buffer: inout Buffer) where Buffer.Element == Byte
    associatedtype Error: Swift.Error
    associatedtype Context: Sendable = Void                     // ← the context slot
    init<Bytes: Collection>(ascii bytes: Bytes, in context: Context) throws(Error) where Bytes.Element == Byte
}
// + a Void-default convenience giving context-free conformers a no-arg init(ascii:):
extension Binary.ASCII.Serializable where Context == Void {     // :89-95
    init<Bytes: Collection>(ascii bytes: Bytes) throws(Self.Error) where Bytes.Element == Byte { try self.init(ascii: bytes, in: ()) }
}
```

The in-flight W3 migration (separate Cleave session; `ascii-domain-evergreen-end-state.md` v1.3.0 § "W3 Execution Decisions" → OQ2) **defers** this: the 5 keep a plain concrete `init(ascii:in:)` reader (non-protocol API), uniformly shaped so a future retrofit is "a declaration change, not a rewrite." That OQ2 note records a principal-ratified *deferred shape* — *"add `associatedtype Context = Void` to the existing `Parseable` / `ASCII.Parseable` … NOT a separate `ContextualParseable` sibling"* — and explicitly flags the two **open checks** to perform when/if the mechanism is built: *"any `any Parseable` / `any ASCII.Parseable` existential usage, + how `Context` threads through `parse(from:)` and the `Binary.Parseable` parent."*

**This document resolves those two open checks and the build-now-or-when + shape question.** It is the Tier-2 investigation the W3 OQ2 deferred — it extends `ascii-domain-evergreen-end-state.md`, it does not contradict it.

**Trigger**: principal Tier-2 dispatch, 2026-06-29. **Constraints**: read-only on all package source, the deprecated target, and the W3 conformers (parallel migration in flight); writes limited to this doc, its `_index.json` entry, and throwaway `/tmp` probes; not committed pending principal review.

## Question

Should the family-Codable system have a first-class mechanism for context-bearing parsing, and in what shape? Recommend **build-now-or-when + the design**, OR recommend **keeping concrete-API-only (status quo)**.

Four candidate shapes are compared:

1. `associatedtype Context = Void` on the **existing** flat `Parseable` / `ASCII.Parseable` top-level sibling (the W3 note's literal wording; "the principal's instinct").
2. A **separate context-bearing protocol** (serde-`DeserializeSeed` style) that keeps the flat marker flat — realized in the institute as a **[FAM-007] sub-sibling**.
3. A **coder/driver side-channel** (Swift-Codable-`userInfo` style) — context off the protocol entirely.
4. **Status quo** — concrete `init(ascii:in:)` only; no generic mechanism.

## Methodology

- **[RES-019]/[HANDOFF-013] internal grep first.** `rg -li "context|parseable|family.codable|deserialize" swift-institute/Research/` + `_index.json` scan. Two docs bear directly: (a) `2026-05-15-family-codable-convention.md` + the canonical per-package `swift-foundations/swift-json/Research/family-codable-convention.md` ([FAM-001..009]); (b) `ascii-domain-evergreen-end-state.md` v1.3.0 (the W3 plan whose OQ2 *defers* exactly this question and names Q1/Q2 as its open checks). The latter does **not** decide the question — it parks it — so this is **cite + extend**, not a duplicate. No other doc decides context-bearing parsing.
- **Q1 (existential usage)** answered by a workspace-wide grep across all institute per-authority org-dirs (below).
- **Q2 (generic context-supply)** answered by seven single-file `swiftc -typecheck -swift-version 6` probes (Swift 6.3.3) per [RES-028] smallest-isolation-first — pure type-system semantics, no SwiftPM behavior involved.
- **[RES-021] prior-art survey** with the mandatory contextualization step; load-bearing signatures verified against primary sources per [RES-020]/[RES-032].
- Every empirical claim carries file:line / probe verdict / primary-source citation per [RES-023].

---

## Analysis

### Q1 — Existential usage: **ZERO** (decisive)

**Claim**: No institute code uses `any` / `some` `ASCII.Parseable`, `Binary.Parseable`, `ASCII.Serializable`, or `Binary.Serializable` as an existential/opaque type, in any form (`any X`, `some X`, `[any X]`, `-> any X`, `[Key: any X]`, `as any X`).

**Evidence** `[Verified: 2026-06-29]`. Grep across all 10 institute per-authority org-dirs (`swift-primitives swift-standards swift-foundations swift-ietf swift-iso swift-iec swift-w3c swift-whatwg swift-incits swift-ieee`), excluding `.build/`, `.swift-lint/`, `Research/`, `coenttb*`, `swiftlang`, `apple`, `bytedance`:

```
rg -n '\b(any|some)\s+[A-Za-z_.]*(Parseable|Serializable)\b'   → 1 hit (false positive)
rg -n '\[[A-Za-z_.]*\.(Parseable|Serializable)\]|->\s*…|:\s*\[…\]'  → 0 hits
```

The single hit is prose, not code: `swift-ascii-serializer-primitives/README.md:21` — *"`asciiCodes` is the canonical ASCII form of **any Serializable** integer"* (English "any", not the `any` keyword). **Genuine existential count: 0.**

**Why it matters**: adding `associatedtype Context` to a protocol makes it a constrained existential — `any P` can no longer call any member whose signature mentions `Context` (proved in probe D). Q1 establishes that this erasure cost is **currently unrealized**: no site uses these as existentials. So shape 1's forfeiture of the flat-marker simple-erasure property breaks **nothing today**. It does, however, permanently forfeit a *property* that the flat-marker design deliberately holds for all ~120 conformers — see the [FAM-001] weighing below. (Note: the canonical attachment `Parser_Primitives_Core.Parseable` already carries `associatedtype Parser` per [FAM-002] (`swift-parser-primitives/Sources/Parser Primitive/Parseable.swift:26-32`) and is therefore *already* non-erasable — the simple-erasure property is a **sibling-only** property, which is precisely what [FAM-001] protects.)

### Q2 — Generic context-supply: **achievable only in the "context-handed-in" form; the generic payoff is illusory**

Seven probes (`/tmp` scratchpad, `swiftc -typecheck -swift-version 6`, Swift 6.3.3). Verdicts:

| Probe | Construct | Verdict | Compiler evidence |
|---|---|---|---|
| **A** | `associatedtype Context = Void` + whole-buffer `init(ascii:in:)` + Void-default convenience + a generic `f<T>(_ b, in ctx: T.Context)` | **COMPILES** | the proven shape works; Void conformers get `init(ascii:)` free; generic works *when the caller hands in the context* |
| **B** | generic `f<T: Parseable>(_ b)` tries to **construct** `T.Context()` | **FAILS** | `error: type 'T.Context' has no member 'init'` |
| **C** | generic `f<T: Parseable>(_ b)` calls Void convenience `T(ascii: b)` with **no** constraint | **FAILS** | `error: referencing initializer 'init(ascii:)' … requires the types 'T.Context' and '()' be equivalent` |
| **C2** | same, **with** `where T.Context == Void` | **COMPILES** | the no-context generic path needs the explicit Void constraint |
| **D** | parse through `any Parseable.Type` (existential) | **FAILS** | `error: member 'init' cannot be used on value of type 'any Parseable.Type' [#ExistentialMemberAccess]` |
| **E** | flat `Parseable {}` + **separate** `ContextualParseable { associatedtype Context; init(ascii:in:) }` (serde-seed shape) + generic `g<T: ContextualParseable>(_ b, in c: T.Context)` | **COMPILES** | flat marker stays fully erasable (`[any Parseable]` works); generic identical to A |
| **F** | `associatedtype Context = Void` on the **streaming** `parse(from:in:)` parent (the `Binary.Parseable` shape) | **COMPILES, but** | the requirement becomes `parse(from:in:)`; **every** Void conformer must respell its witness `in context: Void` — not free |

**Interpretation.**

1. **The illusory form (probe B).** A generic algorithm `f<T: Parseable>` cannot *fabricate* a `T.Context` — there is no init to call on an unconstrained associated type. Putting `Context` on the protocol does **not** enable "parse any context-requiring `T` generically," because the generic caller has no way to produce the context.

2. **This is not merely a type-system limit — it is semantic.** The five contexts are derived from **format-specific upstream parse state**: `RFC_2046.Multipart.Context.boundary` is the MIME boundary lifted from the `Content-Type` header; `WHATWG_URL.URL.Path.Context.isOpaque` is computed from the URL's scheme; `URL.ParsingContext.base` is the base URL for relative resolution. A caller that can construct the right context is, by construction, a caller that **already knows the concrete type** (it must, to know which context to build). The realistic call site is therefore always concrete — exactly the `Multipart(ascii: bytes, in: context)` form, which needs no protocol at all (probe A direct call).

3. **The achievable form (probes A, C2, E).** Generic contextual parsing *is* achievable when the caller **hands in** the context: `func f<T>(_ b: [UInt8], in ctx: T.Context) -> T`. But this form is delivered **equally** by shape 1 (Context on the existing protocol, probe A) and shape 2 (Context on a separate sibling, probe E). The two shapes are **indistinguishable** for the only generic use that compiles. **No additional context-supply mechanism (provider/factory) is required** for the achievable form; one would be required only to rescue the *illusory* form, and even then it would have to be type-specific — defeating the genericity it was meant to provide.

4. **The existential split (probe D vs E).** The *only* place shapes 1 and 2 diverge is existential erasure. Shape 1 forfeits `any Parseable` parse-dispatch for **all** ~120 conformers (probe D); shape 2 keeps the flat marker fully erasable and confines the associated type to the opt-in sibling (probe E). Q1 shows neither side has an existential consumer today — but shape 2 *preserves* the property, shape 1 *destroys* it.

5. **The "`Binary.Parseable` parent" open check, answered (probe F).** Context must **not** be threaded onto the streaming `parse(from:)` requirement: doing so turns the requirement into `parse(from:in:)`, forcing every existing Void conformer (`UInt32`, `Array`, `ArraySlice`, `ContiguousArray`, `Tagged` in `swift-binary-parser-primitives`) to respell its witness signature — a breaking change for the context-free majority. The deprecated protocol got this right: it put context on a **whole-buffer `init(ascii:in:)`** (a *separate* read entry), leaving the streaming parent untouched. Context belongs on the whole-buffer decode, not the cursor parse.

### Prior-art survey ([RES-021], with contextualization)

All signatures `[Verified: 2026-06-29]` against primary sources.

#### Rust `serde::DeserializeSeed` — a **separate** trait, the seed carries state

```rust
pub trait DeserializeSeed<'de>: Sized {            // separate from Deserialize
    type Value;
    fn deserialize<D>(self, deserializer: D) -> Result<Self::Value, D::Error> where D: Deserializer<'de>;
}
```
(docs.rs/serde `de::DeserializeSeed`.) Plain `Deserialize::deserialize(deserializer) -> Result<Self, …>` is context-free. When stateful/contextual deserialization is needed (canonical use: deserializing into a pre-existing buffer), serde does **not** add a context slot to `Deserialize` — it adds a **separate** trait whose `self` (the *seed*) carries the state. **Why separate?** Because the vast majority of deserialization is context-free, and burdening the universal trait with a state parameter would tax every implementor and every call site for a minority capability. **Institute equivalent**: shape 2 — a separate context-bearing protocol. In the institute's witness model, "the seed *is* the stateful deserializer" maps cleanly onto **the parser witness carrying the context** (e.g., `static func parser(in context: Context) -> Parser`), with the value-attachment marker staying flat.

#### Swift `Codable` `userInfo` — context via an **untyped side-channel on the decoder**

`var userInfo: [CodingUserInfoKey : Any] { get }` lives on `Decoder` / `JSONDecoder`, **not** on `Decodable`. `Decodable.init(from:)` reads `decoder.userInfo[key]`. **Tradeoffs**: the `Decodable` protocol stays flat (no context requirement), but type-safety is lost — values are `Any`, keyed by a stringly-typed `CodingUserInfoKey`, cast at runtime, failing or defaulting silently when absent. **Institute equivalent**: shape 3 — context on the coder/driver. This is doubly disfavored: the institute *deliberately rejected* the single-coder Codable model (the family-codable convention's founding premise; `2026-05-15-family-codable-convention.md:531-544`), **and** the byte-stream split-pair has no shared decoder *instance* to hang a `userInfo` bag on — parse is a static method / whole-buffer init. The mechanism doesn't even fit.

#### Haskell `aeson` / parser-combinator state — context in the **parsing monad**, not the typeclass

`aeson`'s `FromJSON`/`ToJSON` carry no context slot (Hackage `Data.Aeson`). Context-dependent parsing is expressed *inside* the `Parser` monad — explicit field combinators or a `ReaderT env Parser` environment — leaving the typeclass context-free. **Institute equivalent**: context as state of the *parser combinator/witness*, again leaving the marker flat.

#### Contextualization ([RES-021]: universal adoption ≠ universal necessity — and here, the reverse)

The three surveyed systems are **unanimous**: every one keeps its main deserialize protocol/typeclass **context-free** and supplies context through a **separate** mechanism (separate trait / driver side-channel / parser-monad environment). **None** places a context associated type on the universal deserialize protocol. The contextualization step normally guards against importing a *universally-present* feature the institute may not need; here it cuts the other way — the universal *absence* of "context on the main protocol" is a strong signal that shape 1 is a design smell. Crucially, the institute already has the institute-native realization of the separate-mechanism pattern: **[FAM-007]** (sub-sibling associated types) and **the witness layer** (`associatedtype Parser` + `static var parser`). Prior art does not merely tolerate shape 2 — it converges on it, independently of the convention.

### Weighing against the [FAM-*] convention (ground-rule #4)

This is the load-bearing convention analysis. Exact text:

- **[FAM-001]** (`swift-foundations/swift-json/Research/family-codable-convention.md:117`): *"**Top-level format-specific sibling protocols MUST NOT declare associated types.** … Sub-siblings (refinements of a top-level sibling) MAY carry associated types under [FAM-007]."* The rationale (`:107-115`) is the associated-type *anchor-unification trap* (`getAssociatedTypeAnchor`, blog `2026-04-20-associated-type-trap.md`): the flat marker's value is that it is a clean, erasure-safe, collision-free whole-format marker.
- **[FAM-007]** (`:298-323`): *"**Sub-sibling protocols — protocols that refine a top-level format-attachment sibling carrying no associated types — MAY declare domain-specific associated types**"* provided unique names (the doc explicitly lists `Context`), `@_implements` for cross-sub-sibling collisions, and a default bridge to the parent's required method.
- The convention's worked examples (`:308-309`) state that `UInt8.Base62.Serializable` (which declares `associatedtype Error` + `associatedtype Context: Sendable = Void`) **PASSES [FAM-007]**, and that the deprecated `Binary.ASCII.Serializable` **"structurally would also PASS [FAM-007]"** — it is deprecated for W4 namespace reasons, *not* for its context slot.

**Consequences for the four shapes:**

- **Shape 1 is a hard [FAM-001] violation.** `ASCII.Parseable` and `Binary.Parseable` are *top-level* siblings (`:294` names `ASCII.Parseable` as the canonical example of a top-level sibling). Adding `associatedtype Context` to them is exactly what [FAM-001] forbids. The W3 OQ2 note's literal wording — *"add `associatedtype Context = Void` to the existing `Parseable` / `ASCII.Parseable` … NOT a separate sibling"* — therefore prescribes a [FAM-001] violation.
- **The deprecated "proven shape" the W3 note cites is itself a sub-sibling.** `Binary.ASCII.Serializable: Binary.Serializable` *refines* a top-level sibling — it **is** a [FAM-007] sub-sibling, structurally **shape 2**, not shape 1. The W3 note's prose ("not a separate sibling") and the artifact it invokes as proof point at *opposite* shapes; the artifact is the authority. There is no [FAM-001]-compliant way to realize "context on the existing flat marker."
- **Shape 2 is explicitly convention-sanctioned.** A context-bearing **sub-sibling** carrying `associatedtype Context: Sendable = Void` (+ `associatedtype Error`) with a default bridge to its parent is the [FAM-007] pattern verbatim, and matches the deprecated protocol's actual structure.

**Two independent lines of evidence — prior art (serde/Codable/aeson) and the institute's own [FAM-001]/[FAM-007] — converge on shape 2 and reject shape 1.**

### Candidate-shape comparison matrix

| Criterion | 1: assoc on flat marker | 2: [FAM-007] context sub-sibling | 3: coder/driver side-channel | 4: status quo (concrete) |
|---|---|---|---|---|
| [FAM-001] compliance | **VIOLATES** (assoc on top-level sibling) | **COMPLIES** (assoc on sub-sibling per [FAM-007]) | complies (no protocol change) | complies |
| Existential-erasure cost (Q1) | forfeits `any X` for all ~120 (probe D); 0 sites today | preserves flat-marker erasure (probe E) | preserves | preserves |
| Generic-supply viability (Q2) | achievable form only (handed-in); illusory form fails (B) | identical achievable form (E); illusory fails too | achievable but untyped (`Any`) | n/a (concrete) |
| `Binary.Parseable` streaming-parent interaction (probe F) | risks breaking Void conformers if put on `parse(from:)` | clean: lives on whole-buffer read, parent untouched | n/a | n/a |
| Witness-model fit | poor (marker absorbs state) | strong (seed↔parser-witness analog) | poor (no decoder instance in split-pair) | strong (state is a ctor arg) |
| Ergonomics for the 5 | `init(ascii:in:)` via protocol | `init(ascii:in:)` via sub-sibling | `userInfo[key] as!` casts | `init(ascii:in:)` concrete |
| Ergonomics for the ~115 context-free | Void-default free **but** non-erasable | Void-default free **and** erasable; opt-out by not conforming | unaffected | unaffected |
| Prior-art alignment | **none** (no system does this) | **serde DeserializeSeed** (direct) | Codable userInfo (rejected model) | aeson/combinator default |
| Migration cost FROM concrete readers | medium (+ later re-migration off [FAM-001] violation) | low, additive (readers already uniformly shaped) | medium (build a driver) | **zero** |
| Re-opens freshly-shipped W0 contract | yes (mutates flat markers) | no (adds a new protocol) | no | no |

Ordering: **status quo ≥ shape 2 ≫ shape 1 > shape 3**. Status quo and shape 2 are structurally clean; shape 1 is dominated by shape 2 on every axis where they differ (it is shape 2 minus [FAM-001]-compliance minus erasure-preservation minus prior-art); shape 3 is both philosophically rejected and mechanically ill-fitting.

### Theoretical grounding (Tier-2 light formalism, [RES-022]/[RES-024])

Model a read protocol as a relation `decode : (Context, [Byte]) ⇀ Value` (partial; failure = `Error`). The flat marker is the degenerate case `Context = Void`, i.e. `decode : [Byte] ⇀ Value`. The design choice is *where the `Context` parameter is universally-quantified*:

- **Shape 1** quantifies it on the *universal* marker: `∀ T : Parseable . decode_T : (T.Context, [Byte]) ⇀ T`. Every `T` — including the ~115 with `Context = Void` — now ranges over a `Context`-indexed family, and the existential `∃ T . T` (i.e. `any Parseable`) can no longer apply `decode` because the domain type `T.Context` is not exposed (probe D = the standard "associated type escapes the existential" result).
- **Shape 2** quantifies it on a *refinement* inhabited only by the 5: `∀ T : ContextualParseable . decode_T : (T.Context, [Byte]) ⇀ T`, while `Parseable` stays `decode_T : [Byte] ⇀ T` and `∃ T . T` remains applicable. The universal-quantifier scope is the minimal set that needs it.

**The structural-correctness argument** ([RES-022]): the question is *where does the `Context` universal belong*, and the answer is determined by semantic scope, not by diff-size. `Context` is meaningful for exactly 5 of ~120 conformers; quantifying it over all 120 (shape 1) is a category error that the type system punishes via lost erasure. Quantifying it over the 5 (shape 2) is the structurally-correct scope. Diff-size/migration-cost are *not* invoked to choose between shape 2 and status quo — that choice is made on the *use-site* axis next.

### Build-now or when? — the use-site axis ([RES-018]/[RES-027])

Even shape 2 (the correct shape *if* built) introduces a protocol with conformers but **zero polymorphic call sites**: Q1 shows no existential consumer; Q2 shows the only generic form that compiles is "context handed in," and the callers that can build the context are concrete by construction. An abstraction with no polymorphic use site is a premature abstraction — the concrete `init(ascii:in:)` *is* the first-class expression of context-bearing parsing, and probe A confirms it needs no protocol to be fully capable. Per [RES-018]'s anti-over-abstraction posture (decided structurally, not by consumer count): there is no polymorphic shape that composition-of-concrete-readers fails to cover, because **nothing parses the 5 polymorphically**.

The retrofit is cheap and the W3 plan already pays for it: the 5 concrete readers are kept *uniformly shaped* precisely so that adopting shape 2 later is "a declaration change, not a rewrite" (`ascii-domain-evergreen-end-state.md` v1.3.0 OQ2). Building shape 1 *now* would be strictly worse than waiting — it is the more expensive path (it would itself need re-migration off the [FAM-001] violation). So the use-site axis points to **defer**.

---

## Outcome

**Status**: RECOMMENDATION (not yet implemented; for principal review).

### Recommendation

1. **Now — keep concrete-API-only (status quo, shape 4).** Do **not** add a protocol-level context mechanism during or after W3. The five conformers keep their concrete whole-buffer `init(ascii:in:)` readers (non-protocol API), uniformly shaped per the W3 OQ2 plan. Rationale, evidence-backed: zero existential consumers (Q1); the generic payoff is illusory (Q2 probe B) and the realistic caller is concrete; the concrete API loses no capability (probe A); there is no polymorphic use site, so a protocol would be premature abstraction; the retrofit is cheap and additive.

2. **If/when ever built — use shape 2 (a [FAM-007] context sub-sibling), NOT shape 1.** Pre-resolved design:

   ```swift
   // In swift-ascii-parser-primitives (read side), refining the flat read marker.
   extension ASCII {
       /// Context-bearing ASCII read. [FAM-007] sub-sibling of the flat `ASCII.Parseable`.
       public protocol ContextualParseable: ASCII.Parseable {     // refines the flat top-level sibling
           associatedtype Error: Swift.Error                       // unique name per [FAM-007]
           associatedtype Context: Sendable = Void                 // unique name per [FAM-007]; Void-default
           init<Bytes: Collection>(ascii bytes: Bytes, in context: Context) throws(Error) where Bytes.Element == Byte
       }
   }
   // Void-default convenience: context-free conformers get a no-arg reader for free.
   extension ASCII.ContextualParseable where Context == Void {
       init<Bytes: Collection>(ascii bytes: Bytes) throws(Self.Error) where Bytes.Element == Byte {
           try self.init(ascii: bytes, in: ())
       }
   }
   ```

   This is the deprecated `Binary.ASCII.Serializable` shape (`:25-34`) re-homed onto the read marker, [FAM-007]-sanctioned, serde-`DeserializeSeed`-aligned, and erasure-preserving (probe E). Context lives on the **whole-buffer read**, never on the streaming `Binary.Parseable.parse(from:)` (probe F). Equivalently, the institute-idiomatic realization is **context-as-witness-state** (`static func parser(in context: Context) -> Parser`), keeping even the read marker flat — preferable if/when the parser-witness layer is the integration point.

   **Trigger to build it** (a *premise* item per [RES-027], backed by the probes which are the empirical verification): a real consumer must parse **≥2 of the 5 polymorphically through a single generic algorithm that is handed the context**. Q1+Q2 show this is not on the horizon; it may never arise.

3. **Correct the W3 OQ2 deferred note.** Its wording — *"add `associatedtype Context` to the existing `Parseable` / `ASCII.Parseable` … NOT a separate `ContextualParseable` sibling"* — should be revised to *"a [FAM-007] context sub-sibling (the deprecated protocol's actual structure), not an associated type on the flat top-level marker."* The literal wording prescribes a [FAM-001] violation; the "proven shape" it cites (`Binary.ASCII.Serializable`, itself a sub-sibling) already **is** the separate-sibling form. This is a wording/shape correction, not a reversal of the deferral — the deferral (don't build now) stands and is reinforced.

### Reversibility

Maximal. The recommendation is "do nothing structural now," and the if-ever design is purely additive (a new refinement protocol + per-conformer conformances; the concrete readers already have the right signature). No W0/W3-shipped contract is touched.

### Open follow-ups

- This doc's correction (#3) is a candidate edit to `ascii-domain-evergreen-end-state.md` OQ2 and, on principal authorization, a one-line clarification to the W3 executor's brief. **Not actioned here** (read-only on the W3 arc; the parallel session owns that doc).
- If shape 2 is ever built, it is also a candidate [FAM-007] worked-example addition (a second sanctioned instance alongside `UInt8.Base62.Serializable`).

## References

### Internal (primary)
- `swift-institute/Research/ascii-domain-evergreen-end-state.md` v1.3.0 — § "W3 Execution Decisions" → OQ2 (the DEFERRED context gap; this doc resolves its two open checks). Originating deferral.
- `swift-foundations/swift-json/Research/family-codable-convention.md` — [FAM-001] (:117 no assoc on top-level siblings), [FAM-006] (:141), **[FAM-007]** (:298-323 sub-sibling carve-out; worked examples :308-309), top-level-sibling definition (:294).
- `swift-institute/Research/2026-05-15-family-codable-convention.md` — [FAM-001..009] ecosystem-wide placement; serde/aeson/Codable prior-art (§6).
- `swift-institute/Blog/Published/2026-04-20-associated-type-trap.md` — [BLOG-IDEA-031] anchor-unification rationale behind [FAM-001].

### Empirical anchors (`[Verified: 2026-06-29]`)
- Flat markers: `swift-ascii-parser-primitives/Sources/Parseable ASCII Primitives/ASCII.Parseable.swift:32`; `swift-ascii-serializer-primitives/Sources/Serializable ASCII Primitives/ASCII.Serializable.swift:35`.
- Streaming parent (no assoc type): `swift-binary-parser-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift:61-76`.
- Canonical attachment (has assoc type per [FAM-002]): `swift-parser-primitives/Sources/Parser Primitive/Parseable.swift:26-32`.
- Deprecated proven shape (sub-sibling, Context+Error): `swift-ascii-serializer-primitives/Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift:17-34,89-95`.
- The 5 conformer contexts: `WHATWG_URL.URL.Path.Context.swift:10`; `WHATWG_URL.URL.Host.swift:107`; `WHATWG_URL.URL.Path.swift:60`; `RFC_2046.Multipart.swift:330`; `RFC_2387.Related.swift:321`; `WHATWG_URL.URL+Serializable.swift:168`.
- Q1 grep false-positive: `swift-ascii-serializer-primitives/README.md:21`.
- Q2 probes (throwaway, `/tmp` scratchpad `probes/A..F.swift`): verdicts A=compiles, B=fails (`'T.Context' has no member 'init'`), C=fails (`Context==()` mismatch), C2=compiles, D=fails (`#ExistentialMemberAccess`), E=compiles, F=compiles-but-breaks-Void-conformers.

### External (per [RES-021], primary-source verified)
- [Rust serde `DeserializeSeed`](https://docs.rs/serde/latest/serde/de/trait.DeserializeSeed.html) — separate trait; seed (`self`) carries state; canonical use = deserialize into pre-existing state.
- [Swift `Decoder.userInfo`](https://developer.apple.com/documentation/swift/decoder/userinfo) — `[CodingUserInfoKey : Any]` untyped side-channel on the decoder, not on `Decodable`.
- [Haskell aeson `Data.Aeson`](https://hackage.haskell.org/package/aeson/docs/Data-Aeson.html) — `FromJSON`/`ToJSON` carry no context slot; context lives in the `Parser` monad / `ReaderT` environment.

### Process anchors
- [RES-018] compose-first / anti-over-abstraction (no polymorphic use site → premature). [RES-019]/[HANDOFF-013] internal grep first. [RES-020]/[RES-032] primary-source verification of load-bearing claims. [RES-021] prior-art + contextualization. [RES-022] structural-correctness framing. [RES-023] empirical-claim verification. [RES-027] loose-end follow-up (premise backed by the probes). [RES-028] smallest-isolation-first (single-file `swiftc`). [FAM-001]/[FAM-007] family-codable convention.
