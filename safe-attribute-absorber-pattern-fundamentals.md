# `@safe` Attribute and Absorber-Pattern Invariant Disclosure: Fundamentals

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The Wave 4 dispatch (2026-05-12, `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md` v1.1.0) stamped an absorber-pattern carve-out on `[MEM-SAFE-025b]`. The carve-out admits `@safe` on type declarations that satisfy two conditions: (1) the type's body shows direct unsafe internals (`@unsafe` attribute, `@unchecked Sendable` clause, `nonisolated(unsafe)` stored property, or `Unsafe*Pointer` / `OpaquePointer` / `Unmanaged` storage), AND (2) an adjacent `// WHY: Category <A|B|C|D>` line or `## Safety Invariant` doc-comment section discloses the invariant.

The Wave 4 prediction was that the carve-out would close ~128 sites. The actual closure pattern revealed substantial residuals:

| Residual cause | Cluster |
|---|---|
| Method-level absorption | `@safe` was a documentation marker on a type whose internals are method-encapsulated, not type-level |
| Transitive absorption | The outer type stores another absorber type (e.g., `Tagged<...>`, `Ownership.Borrow<...>`), not a raw unsafe pointer |
| Heading-text mismatch | Sites use `## Safety Invariant`-equivalent doc sections under different headings (`## Thread Safety`, `## Ownership`, `## Usage`) |

The user's instruction for this research: *"do /research-process on this, to see what the fundamentally, structurally correct approach here is. it should not make any assumptions nor prefer what we already have."* This is a Tier 2 foundational re-examination per [RES-029] — a semantic-identity question ("what `@safe` IS-A in institute code") that ranks above cost/pragmatism per the same rule. Structural correctness dominates diff-size per [RES-022].

This document re-opens the underlying framing. It MAY conclude the Wave 4 DECISION is correct, partially correct, or fundamentally wrong. Per [RES-019] and [RES-021], it grounds the analysis in internal research (mem-safe-025-reconciliation, three-tier-linter-rules-partition, swift-safety-model-reference, the Wave 4 dispatch doc) and external primary sources (SE-0458, Memory Safety Vision Document, Rust unsafe-keyword documentation, Rust RFC 2585, the Rustonomicon's "Safe and Unsafe" chapter).

## Question

**What is the fundamentally, structurally correct approach to `@safe`-attribute usage and absorber-pattern invariant disclosure in the Swift Institute ecosystem?**

Sub-questions:

1. **Identity**: What does `@safe` semantically ASSERT, and what mechanism (attribute, comment, doc section, type system) is the structurally correct one for asserting it in institute code?
2. **Boundary**: Is the type-vs-method distinction (the Wave 4 carve-out's foundation) the right axis to gate the rule? Or is the correct cut elsewhere (direct-pointer-storage vs other, Sendable-related vs not, etc.)?
3. **Granularity**: Is the empirical universe of ~150 `@safe` sites composed of a single coherent pattern ("the absorber pattern") or a heterogeneous mix that the single-rule framing forces together?
4. **Adoption**: Does the institute's "forbid `@safe`" policy reflect a structural insight or an aesthetic preference for comments-over-attributes?
5. **Compatibility**: How does institute policy interact with SE-0458's intended use of `@safe`? Is the institute choosing a less-expressive mechanism over a more-expressive one, or is it choosing a more-expressive mechanism over a less-expressive one?

## Prior Art Survey

### A. SE-0458 (Swift Evolution)

**Authoritative source**: [SE-0458 "Opt-in Strict Memory Safety Checking"](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md), accepted. Verified 2026-05-12.

SE-0458 introduces `@safe` and `@unsafe` as first-class Swift attributes. The proposal's intended use:

> *"The `@safe` attribute is used on declarations whose signatures involve unsafe types but are, nonetheless, safe to use."*
> — SE-0458, §"Acknowledging unsafety > @safe attribute"

The proposal cites `Array.withUnsafeBufferPointer` as the exemplar:

> *"`withUnsafeBufferPointer` itself takes responsibility for the memory safety of the unsafe buffer pointer it vends, ensuring that the elements have been initialized... that the bounds are correct, and that nobody else has access to the buffer when it is provided."*
> — SE-0458, ibid.

Critical mechanical effect: `@safe` suppresses argument-unsafety diagnostics. From SE-0458:

> *"a variable of unsafe type that is used as its direct arguments (including the `self`). If such a variable is used to access a `@safe` property or subscript, or in a function call to a `@safe` function, it will not be diagnosed as unsafe"*
> — SE-0458, ibid.

For types containing unsafe storage, SE-0458 mandates explicit marking:

> *"warning: type `DataWrapper` that includes unsafe storage must be explicitly marked `@unsafe` or `@safe`"*
> — SE-0458 (cited from prior research `swift-institute/Research/swift-safety-model-reference.md`:268-270, verified 2026-05-12 against the proposal text)

The compiler emits two fix-its: `add '@unsafe' if this type is also unsafe to use` and `add '@safe' if this type encapsulates the unsafe storage in a safe interface`. Compiler source: `lib/Sema/TypeCheckUnsafe.cpp`, diagnostic group `StrictMemorySafety`, cited at `swift-institute/Research/swift-safety-model-reference.md`:303-315.

SE-0458's **alternatives considered** rejects the `@safe(unchecked)` form (an earlier iteration) and an optional `message` argument on `@unsafe`:

> *"a comment could provide the same information, and there is established tooling to expose comments to programmers, so we have omitted this feature."*
> — SE-0458, §"Alternatives considered > Optional `message` for @unsafe attribute"

**Structural insight from SE-0458**: `@safe` is intentionally minimal — it asserts safety without explaining what makes it safe. The proposal explicitly anticipates that prose (in `///` doc comments or `//` line comments) carries the explanation. The attribute is the *machine-checkable* claim; the comment is the *human-auditable* justification. The proposal does not treat these as mutually exclusive — they are complementary.

**Note on the no-propagation principle**: SE-0458 enforces that unsafety does not propagate outward through function boundaries. `@safe` is the mechanism that draws this boundary: callers of a `@safe` API need not write `unsafe` even when unsafe types flow through the call. This is the **machine-checkable** half of the safety boundary.

### B. Swift Memory Safety Vision Document

**Authoritative source**: [Memory Safety Vision Document](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md), in `swiftlang/swift-evolution/visions/`. Verified 2026-05-12.

The Vision document positions `@safe` and `@unsafe` as primary mechanisms for **auditability**, not merely warning suppression:

> *"a Swift module that enables strict safety checking must limit its use of unsafe constructs to `@unsafe` declarations or those parts of the code that have acknowledged local use of unsafe constructs"*
> — Memory Safety Vision Document

> *"Swift tooling should provide a way to audit the uses of unsafe constructs within an entire project (including its dependencies)"*
> — ibid.

**Structural insight from the Vision**: The intended audience of `@safe`/`@unsafe` is three-fold — **compiler** (diagnostic enforcement), **tooling** (audit traversal), **developer** (intent signaling). Comments serve the third audience only. A policy that strips `@safe` from Sources gives up the first two audiences entirely.

### C. Rust — the closest cross-language analogue

Rust's safety model has been the most studied prior art for safety-claim mechanisms. The relevant features:

**Rust has four uses of the `unsafe` keyword** ([Rust std docs for `unsafe`](https://doc.rust-lang.org/std/keyword.unsafe.html), verified 2026-05-12):

1. `unsafe fn` — function declaration, defines obligation on callers
2. `unsafe { }` — block at call site, discharges the obligation
3. `unsafe trait` — trait declaration, defines obligation on implementors
4. `unsafe impl` — implementation, discharges the obligation

The Rustonomicon's "Safe and Unsafe Meaning" chapter ([rust-lang/nomicon](https://doc.rust-lang.org/nomicon/safe-unsafe-meaning.html), verified 2026-05-12) frames the four uses through obligation/discharge symmetry:

> *"`unsafe {}` blocks are about discharging obligations, but `unsafe fn` are about defining obligations."*
> — Rust RFC 2585

> *"Safe Rust is a safe language: all the unsafe parts are kept exclusively behind the `unsafe` boundary."*
> — Rustonomicon, "Safe and Unsafe Meaning"

Rust RFC 2585 (`unsafe-block-in-unsafe-fn`) addressed an inconsistency where `unsafe fn` bodies implicitly acted as one big `unsafe` block, removing the line-level acknowledgment requirement. The RFC's rationale parallels Swift's expression-level `unsafe` keyword design.

**Rust has a `// SAFETY:` comment convention** but it is **not enforced by the language** — it is enforced by clippy's `undocumented_unsafe_blocks` lint and its inverse `unnecessary_safety_comment`. The Rust API Guidelines specify (verified 2026-05-12 via [API Guidelines: Documentation](https://rust-lang.github.io/api-guidelines/documentation.html)):

> *"Unsafe functions should be documented with a 'Safety' section that explains all invariants that the caller is responsible for upholding to use the function correctly."*

Rust thus distinguishes:

| Mechanism | Surface | Audience | Enforced by |
|---|---|---|---|
| `unsafe fn` keyword | Function signature | Compiler, tooling | Compiler (hard error) |
| `unsafe { }` block | Call site | Compiler | Compiler (hard error) |
| `# Safety` rustdoc section | Function docstring | Reviewer, tool user | Convention; clippy lint optional |
| `// SAFETY:` comment | Adjacent to `unsafe { }` | Reviewer | Clippy lint (`undocumented_unsafe_blocks`) |

The decisive structural fact: **Rust uses BOTH attributes (the `unsafe` keyword) AND comments (the `// SAFETY:` / `# Safety` convention). They are complementary, not alternative.** The attribute is machine-checkable; the comment is human-auditable. A `unsafe { }` block without a `// SAFETY:` comment compiles, but clippy can flag it. A `// SAFETY:` comment without a surrounding `unsafe { }` is meaningless to the compiler.

The Rustonomicon also articulates the **measured-trust principle** for the safety boundary:

> *"Safe Rust inherently has to trust that any Unsafe Rust it touches has been written correctly. On the other hand, Unsafe Rust cannot trust Safe Rust without care."*

The boundary's *placement* matters: `unsafe` is asymmetric — trust flows one direction (safe code trusts unsafe code internally), and the mechanism that establishes this trust must be machine-checkable. Documentation alone cannot establish the trust contract because documentation is not enforced.

### D. Haskell — semantic comparison

Haskell's `unsafePerformIO` and the `Unsafe.*` module convention encode safety claims through **module structure** rather than attributes. The Safe Haskell language extension (`-XSafe`, `-XTrustworthy`, `-XUnsafe`) makes safety a module-level property checked by the compiler. The key insight: Haskell encodes the safety boundary at *module granularity* via language extensions; the compiler then checks that `Safe` modules only import `Safe` or `Trustworthy` modules.

This is structurally similar to SE-0458's per-declaration `@safe` / `@unsafe`, but coarser-grained. Haskell does not use a comment-based mechanism for safety claims at the level of individual operations; it uses the module-level extension and the type-level `IO` distinction (with `unsafePerformIO` as the bridge whose call sites are expected to be rare).

**Structural insight from Haskell**: When safety is genuinely module-scoped (a whole subsystem absorbs unsafe internals behind a safe API), module-level annotation works. When safety is per-declaration (most of the code is safe; a few items absorb unsafe), per-declaration annotation works. Comment-based mechanisms are weaker because they have no enforcement.

### E. Type-theoretic context — Proof-Carrying Code

The general principle from proof-carrying code (PCC) literature (e.g., Necula's 1997 paper "Proof-Carrying Code", POPL): a *safety claim* is composed of two parts — the *proof obligation* (what must be shown to hold) and the *proof witness* (the evidence that it holds). In a type-theoretic system, attribute-encoded claims correspond to the proof witness; comment-encoded claims correspond to documentation of the proof obligation. Stripping the attribute removes the witness; stripping the comment removes the obligation's stated form. Either alone is weaker than both together.

**Structural insight from PCC**: A safety claim that exists ONLY in a comment is a stated obligation with no witness; a claim that exists ONLY in an attribute is a witness with no stated obligation. Mature safety models use both.

### F. Contextualization step (per [RES-021])

The four prior-art systems above all use **complementary** mechanisms (machine-checkable annotation + human-readable documentation):

| System | Machine-checkable | Human-readable |
|---|---|---|
| Swift (SE-0458) | `@safe` / `@unsafe` / `unsafe` keyword | `///` doc comments, `// SAFETY:` / `// WHY:` lines |
| Rust | `unsafe { }`, `unsafe fn`, `unsafe trait`, `unsafe impl` | `# Safety` rustdoc, `// SAFETY:` |
| Haskell | `-XSafe` / `-XTrustworthy` / `-XUnsafe` extensions; `IO` type | Haddock haddocks, module headers |
| PCC (theory) | Proof witness | Proof obligation statement |

**The institute's current policy** (forbid `@safe` in Sources, mandate adjacent `// SAFETY:` / `// WHY:` invariant comments) chooses **comments-only**. Across all four surveyed systems this is an outlier choice. The contextualization step asks: does this absence reflect a deliberate institute design or a not-yet-considered gap?

The institute's articulated rationale (from the Wave 3 reconciliation doc, the Wave 4 lean doc, and the safety-isolation skill text): comments are richer than attributes (they name the specific invariant) and can cite skill rules. This rationale is **partially true** but does not address: machine-checkability, tool-traversability for ecosystem-wide audits, the suppression of argument-unsafety diagnostics that SE-0458 provides, or the no-propagation guarantee that `@safe` is the *only* mechanism for.

## Empirical Universe

Per [RES-023], the empirical claims here are verified at write-time.

### F.1 Ecosystem-wide `@safe` site count

Live grep on 2026-05-12 across `swift-primitives/*/Sources`, `swift-foundations/*/Sources`, `swift-standards/*/Sources` (excluding `.build/`, `/Tests/`, `/Experiments/`):

```
$ find swift-primitives swift-foundations swift-standards \
    -name "*.swift" -path "*/Sources/*" -not -path "*/.build/*" \
    -exec grep -l "^[[:space:]]*@safe" {} \; | wc -l
125
```

The pre-Wave-4 estimate (Wave 3 ledger v1.3.0) was ~128 sites. The live count is 125, within counting error. The Wave 4 carve-out's predicted closure was for substantially all of these.

### F.2 Distribution of direct unsafe-internals markers per `@safe` site

For each `@safe` file, count occurrences of any direct unsafe marker (`UnsafePointer`, `UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeMutableRawPointer`, `OpaquePointer`, `@unchecked Sendable`, `nonisolated(unsafe)`, `@unsafe`). Histogram (verified 2026-05-12):

| Markers per file | Site count |
|---:|---:|
| 0 | 54 |
| 1 | 29 |
| 2 | 13 |
| 3 | 11 |
| 4 | 8 |
| 5-9 | 22 |
| 10+ | 19 |

**Critical finding**: 54 of the ~150 sample rows (some duplicated by Experiments/ shadow targets in the raw output) have **zero direct unsafe markers** in the file. The Wave 4 carve-out's condition (1) requires direct evidence of unsafe internals — these 54 sites would fail condition (1) and remain flagged unless the carve-out is broadened.

Random samples from the zero-marker bucket (verified by reading the files in full at write-time):

| File | Pattern |
|---|---|
| `swift-bit-vector-primitives/.../Bit.Vector.Ones.Inline.swift` | `@safe public struct Inline<let wordCount: Int>: Copyable, Sendable` storing `InlineArray<wordCount, UInt>` — no unsafe internals at all |
| `swift-bit-vector-primitives/.../Bit.Vector.Ones.Bounded.swift` | `@safe public struct Bounded: Copyable, Sendable` storing `ContiguousArray<UInt>` — no unsafe internals |
| `swift-ownership-primitives/.../Ownership.Shared.swift` | `@safe public final class Shared<Value: ~Copyable & Sendable>: Sendable` with `let value: Value` — fully safe, no unsafe markers |
| `swift-property-primitives/.../Property.Borrow.swift` | `@safe public struct Borrow: ~Copyable, ~Escapable` storing `Tagged<Tag, Ownership.Borrow<Base>>` — transitive absorption through `Ownership.Borrow` |
| `swift-property-primitives/.../Property.Inout.Typed.Valued.swift` | Same pattern — wraps `Ownership.Inout` via `Tagged` |
| `swift-ownership-primitives/.../Ownership.Mutable.swift` | `@safe` on a non-Sendable heap-allocated wrapper — no unsafe internals visible in file |

These sites use `@safe` as **transitive absorption acknowledgment** or **pure documentation**. The carve-out's "direct evidence" condition treats these as policy violations, but they are *exactly* the kind of safe-by-construction sites that the institute's isolation principle [MEM-SAFE-020] is supposed to admit.

### F.3 Three distinct empirical clusters

| Cluster | Description | Approx. count | Carve-out treatment | Correct treatment? |
|---|---|---:|---|---|
| **A. Direct absorber** | Type stores `Unsafe*Pointer` / has `@unchecked Sendable` / has `nonisolated(unsafe)`; `@safe` declares the absorption | ~70 | Admitted by carve-out (if `// WHY: Category` line is present) | Yes |
| **B. Transitive absorber** | Type wraps another absorber type (`Tagged<...>`, `Ownership.Borrow<...>`, `Ownership.Inout<...>`); no raw unsafe internals in file | ~30 | Rejected by condition (1); flagged | No — these are correctly `@safe` |
| **C. Pure documentation** | Type is fully safe by construction; `@safe` is a documentation marker for "this type is safe; no unsafe internals" | ~25 | Rejected by condition (1); flagged | Ambiguous — depends on whether `@safe` is valuable when the type doesn't need argument-unsafety suppression |

The Wave 4 carve-out admits ~70 of 125 sites (cluster A), leaving ~55 residuals across clusters B and C. The original ~29-site empirical closure suggests the actual cluster-A count is even lower than 70 — many cluster-A sites use heading text other than the literal `## Safety Invariant` or `// WHY: Category` form the carve-out's condition (2) matches.

### F.4 The mechanical detection problem

The Wave 4 carve-out's condition (1) requires *AST-only* detection of "this type's body shows direct unsafe internals." This works for cluster A (mechanical signal present) but cannot resolve cluster B (transitive absorption — would require cross-file type resolution) or cluster C (semantic claim of safety, no syntactic marker). The carve-out is *axis-bound by tool capability*, not by structural correctness.

## Analysis

### Question 1 (Identity): What does `@safe` semantically ASSERT?

SE-0458's answer is unambiguous: `@safe` asserts that **a declaration whose signature contains unsafe types is nonetheless safe to use**. The mechanism is twofold:

1. **Diagnostic suppression**: Callers passing unsafe-typed arguments to a `@safe` API receive no diagnostic.
2. **No-propagation guarantee**: Unsafety does not flow outward through the `@safe` boundary.

The institute's "absorber pattern" terminology aligns with SE-0458: an absorber is precisely a `@safe` declaration that encapsulates unsafe internals. The skill text [MEM-SAFE-020] codifies this:

> *"Every declaration plays one of three roles: Absorber (`@safe`) — encapsulates unsafe internals behind a safe API; Propagator (`@unsafe`) — escape hatch that pushes safety responsibility to caller; Unspecified — compiler infers."*

**Structural conclusion**: `@safe` IS the absorber-pattern mechanism in the Swift language. To call something an "absorber" while forbidding `@safe` is to use language-level vocabulary while rejecting the language-level mechanism that materializes it.

### Question 2 (Boundary): Is the type-vs-method axis the right cut?

The Wave 4 carve-out cuts at type-level absorption (admitted) vs method-level absorption (forbidden, must use `[MEM-SAFE-025a]` invariant comments). The dispatching rationale (Wave 4 v1.1.0 defect-fix #2): "method-level absorption sits outside the carve-out's principled scope."

This is a **tool-capability cut**, not a **structural cut**. The AST-only linter can identify type declarations and their immediate attributes; it cannot resolve cross-file `@unsafe`-marked function calls. Calling this distinction "principled" reifies a tool-capability boundary as a design boundary.

The empirically-correct cuts are different:

1. **Direct vs transitive absorber** (clusters A vs B) — distinguished by whether the file directly stores unsafe primitives. Both are legitimate absorbers.
2. **Absorber vs documentation marker** (clusters A+B vs C) — distinguished by whether the type genuinely encapsulates unsafe (even transitively) or is fully safe by construction.
3. **Argument-unsafety-suppressing vs not** — distinguished by whether callers pass unsafe-typed arguments. SE-0458's `@safe` is *mechanically useful* for the former; for the latter, it is documentation-only.

The Wave 4 carve-out fires its condition (1) on axis (1) but stops there. The structural correctness analysis suggests the cut should be on axis (3) — `@safe` is useful precisely where it suppresses an argument-unsafety diagnostic that would otherwise fire. Sites where `@safe` doesn't materially affect compilation are documentation-only and could go either way.

### Question 3 (Granularity): Is "the absorber pattern" a single coherent pattern?

No. The empirical universe shows three clusters with materially different shapes. Forcing them into a single rule with a single carve-out predicate creates:

- **False positives**: ~25 cluster-C sites where `@safe` is documentation only would be flagged unless they also gain an arbitrary `// WHY:` heading.
- **False negatives**: cluster-A sites that absorb unsafe but use non-canonical heading text (e.g., `## Thread Safety` instead of `## Safety Invariant`) pass through despite being the carve-out's intended target.
- **Tool-capability bias**: cluster-B sites (transitive absorption) cannot be detected with the AST-only mechanism, so the carve-out either rejects them (current behavior) or admits ALL `@safe` sites that have ANY adjacent comment (which would erode the rule).

**Structural conclusion**: The "absorber pattern" is a useful conceptual umbrella but not a mechanical predicate. A single rule attempting to police all three clusters with a single predicate is structurally over-constrained.

### Question 4 (Adoption): Is "forbid `@safe`" an insight or a preference?

The institute's articulated rationale (from `mem-safe-025-reconciliation.md`):

> *"`@safe` provides a positive declaration of 'this is encapsulated-safe', which has signal beyond a comment. The compiler treats `@safe` as a marker; future tooling may consume it. ... [BUT] The institute already prefers stating encapsulation invariants in comments tied to skill rules, not in attribute decoration."*

The "future tooling" argument is in `@safe`'s favor; the "comments over decoration" argument is against it. The Option B selection (forbid `@safe`) won on **policy coherence with the partition doc's articulated direction**, NOT on a structural argument that comments are richer than attributes.

Three structural arguments against the "forbid `@safe`" position:

**(a) `@safe` is the only mechanism that suppresses argument-unsafety diagnostics.** Per SE-0458, when a caller passes an unsafe-typed argument to a method, the compiler diagnoses it as `CallArgument` unsafe use — *unless* the method (or its enclosing type) is `@safe`. Comments cannot do this. Stripping `@safe` from Sources means either the caller MUST write `unsafe` at every call site (defeating isolation per [MEM-SAFE-020]) or the institute relies on the empty signature path (no unsafe types in the signature) which is not always achievable.

**(b) `@safe` is the no-propagation mechanism.** SE-0458 design principle: `unsafe` does not propagate outward. `@safe` is the language-level marker that draws this firewall. Comments are not consulted by the compiler when computing propagation. Comment-based justification does not invoke the no-propagation guarantee.

**(c) `@safe` is the audit-tool boundary.** The Memory Safety Vision document explicitly designates `@safe`/`@unsafe` as the surface auditing tools traverse. A `grep`-able comment is not equivalent: comments have no schema, no compiler-validated form, no relationship to the actual code shape beyond textual adjacency. Tools cannot reliably distinguish a `// SAFETY:` comment from an in-doc-comment safety paragraph that mentions "safety" in passing.

The institute's "comments are richer" argument is partially true but applies to **explanation**, not **claim**. The richness of a comment is its prose; the value of an attribute is its mechanical truth. A comprehensive safety design uses both. The institute's choice to use only comments treats the comment as carrying both burdens — but a `// SAFETY:` comment cannot mechanically suppress an argument-unsafety diagnostic; only `@safe` can.

### Question 5 (Compatibility): Is the institute choosing a more-expressive or less-expressive mechanism?

SE-0458's `@safe` is *more* expressive than a comment along three axes:

| Axis | `@safe` attribute | `// SAFETY:` comment |
|---|---|---|
| Diagnostic suppression | Yes (argument-unsafety, member access on unsafe variables) | No |
| Propagation boundary | Yes (no-propagation guarantee) | No |
| Audit-tool traversal | Yes (compiler-validated, mechanically distinguishable) | Best-effort textual match |
| Invariant explanation | No (asserts only) | Yes (prose) |
| Skill-citation embedding | No | Yes (`[MEM-SAFE-024]` etc.) |
| Multi-line elaboration | No | Yes |

The comment is more expressive on **explanation** (rows 4-6); the attribute is more expressive on **claim** (rows 1-3). The institute's "forbid `@safe`" policy chooses the explanation axis over the claim axis. This is a defensible aesthetic choice but a **structurally inferior** one if claim-axis properties are also valuable.

The empirical question: are the claim-axis properties valuable in institute code? The answer is yes, observable in the Wave 4 audit itself:

- ~70 cluster-A sites use `@safe` AND `// WHY: Category` together. Both mechanisms are present. The institute's "forbid `@safe`" policy treats this as policy violation (the `@safe` is forbidden in Sources). But the joint use is the structurally correct mechanism.
- Cluster B (transitive) and cluster C (documentation) sites currently use `@safe` without unsafe internals in the file. The Wave 4 carve-out does not admit them; the broader institute policy forbids them. But they are following the [MEM-SAFE-020] isolation principle — placing the safety boundary as low as possible.

The "forbid `@safe`" stance is incompatible with the [MEM-SAFE-020] isolation principle the institute itself articulates.

## Options Enumeration

Per [RES-004] / [RES-009], all viable options are enumerated. The full Outcome ranks them on structural correctness (per [RES-022]) and rejects the diff-size axis as a recommendation criterion.

### Option A. Status quo (Wave 4 DECISION as stamped)

`[MEM-SAFE-025b]` forbids `@safe` in Sources EXCEPT under the absorber-pattern carve-out: type-decl + direct unsafe internals + canonical disclosure heading.

**Mechanics**: AST-only linter; carve-out fires when condition (1) detects direct unsafe markers AND condition (2) finds an adjacent `// WHY: Category <A|B|C|D>` line OR `## Safety Invariant` doc section.

**Coverage**:
- Cluster A (~70): Admitted IF heading is canonical; otherwise flagged.
- Cluster B (~30): Flagged. Migration required.
- Cluster C (~25): Flagged. Migration required.

**Cost of consequence**: ~55 migrations across clusters B+C, OR per-site disable directives.

**Structural correctness assessment**: The carve-out is tool-capability-bound. The cut between "direct" and "transitive" absorption is mechanical, not principled. The institute's [MEM-SAFE-020] isolation principle is partially honored (cluster A admitted) and partially violated (cluster B+C rejected despite being legitimate isolation sites).

**SE-0458 alignment**: Partial. The carve-out admits `@safe` on the most direct cases but rejects it on the transitive and documentation cases SE-0458 contemplates as part of the same mechanism.

### Option B. Embrace SE-0458 fully — `@safe` is admitted per SE-0458's intent

The institute adopts SE-0458's `@safe` as the canonical absorber-pattern mechanism. The institute layer adds *complementary* requirements for invariant disclosure (not as a substitute for `@safe`):

- `@safe` is permitted on type declarations, methods, properties, subscripts, initializers — wherever SE-0458 permits it.
- Type declarations that use `@safe` MUST have an accompanying invariant disclosure: either a `## Safety Invariant` doc section OR an adjacent `// SAFETY:` / `// WHY:` comment block. The accompanying disclosure is enforced by lint.
- The invariant disclosure can cite a skill category, multi-line prose, etc. — the institute keeps its prose-richness preference.
- Method/property-level `@safe` is similarly admitted with an accompanying inline `// SAFETY:` comment OR a doc-comment `## Safety` paragraph.

**Mechanics**: The lint rule inverts — instead of forbidding `@safe`, it requires an accompanying invariant disclosure. Two rules:
- `Lint.Rule.Memory.SafeAttributeUndocumented` (new): fires when a `@safe` declaration has no adjacent invariant comment or `## Safety Invariant` doc section.
- `Lint.Rule.Memory.NonisolatedUnsafeInvariant` ([MEM-SAFE-025a]): unchanged — `nonisolated(unsafe)` requires its invariant comment.

**Coverage**:
- Cluster A (~70): Admitted (already have invariant disclosure).
- Cluster B (~30): Admitted (add invariant comment if not present; small migration).
- Cluster C (~25): Admitted (add invariant comment OR remove `@safe` if it's truly documentation-only).

**Cost of consequence**: ~20-40 sites need an invariant comment added (cluster B sites that have transitive absorption but no comment, plus cluster C sites that need an explicit "this is safe because" rationale).

**Structural correctness assessment**: Aligned with SE-0458's intended mechanism. Aligned with the [MEM-SAFE-020] isolation principle. Aligned with the cross-language convention (Rust uses both attribute and comment).

**SE-0458 alignment**: Full. Uses `@safe` exactly as SE-0458 intends; layers institute disclosure requirements on top.

**Drawback**: The institute gives up its "forbid `@safe`" articulation. The Wave 3 reconciliation argument that "comments are richer than attributes" becomes a *preference for richness on the explanation axis*, not a *prohibition on the claim axis*. This is a more nuanced articulation than the current one.

### Option C. Forbid `@safe` uniformly — the Wave 3 reconciliation's Option B as originally framed

Strip `@safe` from all Sources. All sites migrate to invariant-comment form. No carve-out. The Wave 4 DECISION reverts.

**Mechanics**: `Lint.Rule.Memory.SafeForbidden` fires unconditionally on any `@safe` in Sources. No carve-out predicate.

**Coverage**: ~125 migrations across 15+ packages. Cluster A, B, and C all migrate uniformly to comment form.

**Cost of consequence**: ~125 source-edits, mechanical. The Wave 4 DECISION's predicted cost.

**Structural correctness assessment**: Internally consistent (one rule, no carve-out). Sacrifices SE-0458's argument-unsafety suppression for the cluster-A sites that genuinely need it. The `@safe` no-propagation boundary is given up entirely.

**SE-0458 alignment**: None — the institute uses SE-0458's strict-memory-safety mode but rejects its primary absorber mechanism.

### Option D. Comment-and-attribute together — require BOTH everywhere

`@safe` is required on every absorber type AND an adjacent invariant comment is required. Neither alone is sufficient.

**Mechanics**: One rule with two conditions. Fires when a type has unsafe internals (direct or `@unchecked Sendable` etc.) but lacks `@safe` OR lacks an invariant comment. Fires when a type has `@safe` but lacks an invariant comment (current Option-B-style requirement).

**Coverage**:
- Cluster A (~70): Admitted if both present; flagged otherwise.
- Cluster B (~30): Detection requires cross-file resolution (same problem as Option A condition 1) — can't reliably mandate `@safe` on transitive absorbers without a type-resolution mechanism.
- Cluster C (~25): Admitted if both present; the policy is that even pure-documentation `@safe` requires comment.

**Cost of consequence**: ~30-50 sites add the missing half (some currently have `@safe` without canonical comment, some have comment without `@safe`). The cross-file resolution problem for cluster B is structurally unsolvable with AST-only linting; would require either (a) a SourceKit/compiler-level rule or (b) accepting AST-only as best-effort.

**Structural correctness assessment**: Uses both mechanisms (good). Tool-capability-bound on cluster B (bad). Slightly more verbose than strictly necessary on cluster C.

**SE-0458 alignment**: Full. Both the claim axis and the explanation axis are required.

### Option E. Type-system answer — encode safety in the type

Define a wrapper type (e.g., `Safety.Absorber<UnsafeStorage>`) or use existing typed-storage primitives so the safety contract is encoded at the type level. `@safe` becomes vestigial.

**Mechanics**: Wrap raw unsafe storage in an absorber type that exposes a safe API by construction. The type's API is the safety contract; no attribute or comment is needed because the type system enforces correctness.

**Coverage**: Long-term aspiration. Not achievable in the short term — would require ecosystem-wide type design work, may not even be expressible (the institute's `nonisolated(unsafe)` use cases include sentinels and lazy-init patterns that don't fit a single absorber wrapper).

**Cost of consequence**: Multi-year design work. Not orthogonal to the absorber-pattern rule question — the rule has to govern the transition period.

**Structural correctness assessment**: Best-of-breed long-term. Not a candidate for the current dispatch — would need to be a separate Tier 3 design effort.

**SE-0458 alignment**: Compatible. Type-system absorption is what `@safe` documents; if the type system itself enforces absorption, `@safe` is redundant.

### Option F. Doc-comment-driven — require `## Safety Invariant` section; attribute optional

Require a `## Safety Invariant` doc-comment section on any type with unsafe internals (direct or transitive). The `@safe` attribute is optional; lint does not forbid OR require it.

**Mechanics**: New rule fires on types with detected unsafe internals lacking the doc section. `[MEM-SAFE-025b]` is dropped. `@safe` is silently admitted everywhere.

**Coverage**:
- Cluster A (~70): Admitted; doc section already required by current convention.
- Cluster B (~30): Admitted; doc section either already present or added.
- Cluster C (~25): Admitted; the rule doesn't fire if there are no unsafe internals to detect.

**Cost of consequence**: ~30-40 sites add a doc section if not already present.

**Structural correctness assessment**: Reasonable. Slightly different from Option B (it focuses on the doc section as the canonical disclosure mechanism, whereas Option B accepts both `// SAFETY:` comments and `## Safety Invariant` doc sections). The choice between B and F is mostly a heading-style preference.

**SE-0458 alignment**: Compatible. Doesn't forbid `@safe`; doesn't require it. Treats SE-0458 as orthogonal — institute layer is documentation-required, language layer is attribute-optional.

### Option G. Capability-based — explicit capability enumeration

Define institute-specific "capability" categories (e.g., `// CAPABILITY: unsafe-pointer-storage`, `// CAPABILITY: unchecked-sendable-synchronized`) that explicitly enumerate the unsafe operations a type encapsulates. The category names form a closed taxonomy.

**Mechanics**: Replaces both `@safe` and the `// WHY: Category` comment with a structured capability declaration. Linter validates against the closed taxonomy. The taxonomy roughly mirrors the SP-1/SP-2/SP-4/SP-5 subpatterns from [MEM-SAFE-024] Category D plus the synchronized/ownership-transfer/thread-confined categories A/B/C.

**Coverage**: All clusters admitted via the capability declaration.

**Cost of consequence**: ~125 sites add (or migrate) to capability declaration. The closed taxonomy must be designed (similar effort to [MEM-SAFE-024] but broader). The capability mechanism is institute-specific and has no SE-0458 mapping.

**Structural correctness assessment**: Most rigorous but most diverged from SE-0458. The institute's existing `// WHY: Category` form is already approximately this — extending it to a fully-enumerated capability taxonomy is a natural evolution.

**SE-0458 alignment**: None. The capability form supplants `@safe` entirely. Tools that audit `@safe` see nothing.

## Comparison Matrix

| Criterion | A: Wave 4 carve-out | B: Embrace SE-0458 | C: Forbid uniformly | D: Both required | E: Type system | F: Doc-section primary | G: Capability taxonomy |
|---|---|---|---|---|---|---|---|
| SE-0458 alignment | Partial | Full | None | Full | Full | Full | None |
| Argument-unsafety suppression (mechanical) | Cluster A only | All clusters | None | All clusters | N/A (type-encoded) | All clusters | None |
| No-propagation guarantee | Cluster A only | All clusters | None | All clusters | N/A | All clusters | None |
| Cross-language defensibility (Rust convention) | Partial | Yes | No | Yes | Yes | Yes | No |
| Disclosure expressiveness | High (canonical heading required) | High | High | High | Low (type-encoded) | High (doc section) | High (taxonomy) |
| Verifiability by AST-only linter | Yes (with cluster-B/C false-negatives) | Yes (sibling-disclosure check) | Yes (uncondit. fire) | Yes (with cluster-B problem) | Yes (type-checker) | Yes | Yes |
| Migration cost (sites) | ~55 residuals | ~30-40 invariant adds | ~125 strips | ~30-50 dual-mode | Multi-year | ~30-40 doc adds | ~125 capability migrations |
| Cognitive load on author | Medium (heading-text-sensitive) | Low | Low (uniform) | Medium (dual req.) | Low (type-natural) | Low | Medium (taxonomy lookup) |
| Coverage of all three clusters (A, B, C) | A only | All | All | A+C (B not detectable) | All (long-term) | All | All |
| Aligned with [MEM-SAFE-020] isolation principle | Partial | Yes | No | Yes | Yes | Yes | Yes |
| Compatible with future tooling (audit traversal) | Yes (cluster A) | Yes (all) | No | Yes (all) | Yes (types) | Partial | Yes (taxonomy) |
| Structural correctness | Low | High | Low | High | High (long-term) | High | Medium |

## Outcome

**Status**: RECOMMENDATION

**Recommended option**: **Option B — Embrace SE-0458 fully, layering an institute invariant-disclosure requirement on top.**

The semantic-identity question per [RES-029] resolves the framing: `@safe` IS the absorber-pattern mechanism in SE-0458's Swift dialect. The institute's "forbid `@safe`" stance treats it as a NOT-A-absorber-mechanism, which contradicts the [MEM-SAFE-020] isolation principle the institute itself articulates and which contradicts SE-0458's design.

The choice is structural, not aesthetic. The Wave 4 carve-out is a tool-capability-bound compromise that admits cluster A while rejecting clusters B and C — yet B and C are *exactly* the cases the [MEM-SAFE-020] isolation principle is meant to admit. The carve-out's residual is a symptom of the underlying framing being wrong, not of the carve-out being too narrow.

The institute's "prose is richer than attributes" rationale (from the Wave 3 reconciliation) is partially true but applies to the explanation axis (what makes this safe), not the claim axis (the no-propagation, argument-unsafety-suppression mechanism). A correct disclosure uses both: the attribute is the machine-checkable claim; the comment or doc section is the human-auditable explanation. This is the convention across SE-0458, Rust, Haskell, and proof-carrying-code theory.

### Structural rationale

Three structural facts dominate:

1. **`@safe` is the only language-level mechanism for argument-unsafety suppression and the no-propagation boundary.** Comments cannot fulfill this role. Per SE-0458 §"Acknowledging unsafety > @safe attribute", a `@safe` declaration suppresses diagnostic emission on its direct arguments. Stripping `@safe` from cluster-A sites that genuinely need this suppression either forces `unsafe` at every call site (violating isolation) or pushes the type to use a less-expressive signature (also degrading).

2. **The cross-language convention is complementary use of attributes AND comments.** Rust uses `unsafe` keywords AND `// SAFETY:` comments. Haskell uses module-level extensions AND haddocks. The institute's choice to use only comments places it outside the established convention for no structural reason.

3. **The Wave 4 carve-out's tool-capability bound is not a principled distinction.** The "type-level vs method-level" cut works only because AST-only linting can resolve type declarations but not cross-file call resolution. Reifying a tool capability as a design boundary creates a rule whose principled scope is narrower than its mechanical scope, leading to the cluster-B and cluster-C residuals.

### Implementation path (if Option B is adopted)

**Phase 0 — Skill update**:

1. `swift-institute/Skills/memory-safety/safety-isolation.md`:
   - Update [MEM-SAFE-025b] body: replace "the `@safe` attribute MUST NOT appear on any declaration in `Sources/`" with "the `@safe` attribute MAY appear on any declaration in `Sources/`; when it does, it MUST be accompanied by an invariant disclosure per [MEM-SAFE-025c] (new)".
   - Author new [MEM-SAFE-025c]: "Every `@safe` declaration MUST carry an adjacent invariant disclosure: either a `// SAFETY:` / `// WHY:` line comment OR a `## Safety Invariant` doc-comment section. The disclosure SHOULD cite a [MEM-SAFE-024] Category when applicable. The disclosure is mandatory for documentation purposes even when the attribute mechanically suppresses diagnostics."
   - Drop the Wave 4 absorber-pattern carve-out language; the carve-out is no longer needed under the inverted policy.

**Phase 1 — Lint rule update**:

1. `swift-foundations/swift-linter-rules/Sources/Linter Rule Memory/`:
   - Rename `Lint.Rule.Memory.SafeForbidden.swift` → `Lint.Rule.Memory.SafeAttributeUndocumented.swift`.
   - Invert the rule: it now fires when `@safe` is present WITHOUT an adjacent invariant disclosure (matching the existing carve-out's condition 2). Drop condition 1 (the "direct unsafe internals" check) — it's not needed; the disclosure is the requirement.
   - Update the rule message text accordingly.

**Phase 2 — Source pass**:

1. Ecosystem-wide grep for `@safe` declarations lacking adjacent invariant disclosure. Estimate ~20-40 sites based on cluster-B/C sampling. Per-site add a `// SAFETY:` line or `## Safety Invariant` doc paragraph.
2. Cluster-C sites where `@safe` is pure documentation: author decides per-site whether to keep `@safe` (with invariant explaining "this type is fully safe; no unsafe internals — `@safe` is documentation only") or drop it. Both are acceptable.

**Phase 3 — Rollout**:

1. The rule pack ships with the inverted form. Existing `@safe` sites that already have invariant disclosure (~70 cluster-A sites) pass through cleanly.
2. The Wave 5 L2/L3 leaf triage continues unchanged — the inverted rule is forward-compatible.

### Migration cost (honest framing per [RES-022])

- ~20-40 source sites need an invariant disclosure added (cluster B + some cluster C).
- 1 skill update.
- 1 lint rule inversion + new tests.
- 0 sites need `@safe` stripped (a strict superset admission relative to the carve-out).

This is **less** invasive than the Wave 4 carve-out's predicted ~55 residual migrations, and **substantially less** invasive than the Option C uniform-strip migration of ~125 sites.

### Open questions for orchestrator/user resolution

1. **Should pure-documentation `@safe` (cluster C, ~25 sites) keep `@safe` or drop it?** The recommendation defaults to "keep, with invariant disclosure" — but the user may prefer "drop, when no mechanical effect is gained." Either is internally consistent under Option B; the choice affects per-site author judgment, not policy text.

2. **Should the institute also admit `@safe` on individual methods/properties (currently forbidden by `[MEM-SAFE-025b]`)?** Option B as recommended says yes — SE-0458 permits `@safe` on methods, the institute should mirror. But the institute's existing prose (Wave 3 reconciliation) hints at "direct `@safe` on funcs/vars/lets/inits/subscripts remains forbidden — `[MEM-SAFE-025a]` invariant comments are the canonical mechanism for those (separate sub-thread)." The "separate sub-thread" suggests this was deferred. The recommendation is to fold it into this same decision: admit `@safe` everywhere SE-0458 permits, with disclosure required.

3. **Should the [MEM-SAFE-024] Category citation be required or recommended?** Currently the Wave 4 carve-out's condition (2a) requires it. Under Option B, it should be recommended (it's a stronger disclosure when applicable) but not required (some `@safe` sites are not categorizable under A/B/C/D, e.g., cluster C pure-documentation sites). The recommendation is to make the Category citation SHOULD-strength.

4. **What is the migration sequence relative to Wave 5 L2/L3 leaf triage?** If Option B is adopted, Wave 4 closes via the inverted rule; the residuals shrink dramatically. Wave 5 can proceed in parallel. If Option B is rejected and Option A retained, Wave 4 stays open through Wave 5's per-leaf disambiguation passes.

5. **Is the "absorber pattern" terminology still useful under Option B?** Yes — the absorber is the role the type plays per [MEM-SAFE-020]. `@safe` is the language-level mechanism that materializes the role. The terminology continues to describe the design pattern; it's no longer carrying weight as a carve-out predicate.

### If the orchestrator/user prefers status quo (Option A)

The Wave 4 DECISION is internally consistent within its tool-capability bound. The structural correctness analysis above does not invalidate it; it shows that the rule has a narrower principled scope than its current articulation suggests. The Wave 4 DECISION can stand if the institute accepts:

- The cluster-B and cluster-C residuals (~55 sites) require either invariant-comment migration or per-site disable directives.
- The "forbid `@safe`" policy is now scoped to "forbid `@safe` except on the type-decl-level direct-absorber form" — a narrower articulation than "forbid entirely."
- SE-0458's argument-unsafety suppression and no-propagation guarantee are not used on cluster B and C sites.

This is defensible as a policy but is **not** the structurally correct answer.

## References

- [SE-0458 "Opt-in Strict Memory Safety Checking"](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md) — the canonical Swift Evolution proposal. Verified 2026-05-12.
- [Swift Memory Safety Vision Document](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md) — the design vision underlying SE-0458. Verified 2026-05-12.
- [Rust std documentation for the `unsafe` keyword](https://doc.rust-lang.org/std/keyword.unsafe.html) — the four uses of `unsafe` in Rust. Verified 2026-05-12.
- [Rust API Guidelines: Documentation](https://rust-lang.github.io/api-guidelines/documentation.html) — the `# Safety` rustdoc convention. Verified 2026-05-12.
- [Rust RFC 2585 — unsafe-block-in-unsafe-fn](https://rust-lang.github.io/rfcs/2585-unsafe-block-in-unsafe-fn.html) — Rust's line-level acknowledgment requirement. Verified 2026-05-12.
- [Rustonomicon — Safe and Unsafe Meaning](https://doc.rust-lang.org/nomicon/safe-unsafe-meaning.html) — the obligation/discharge framing. Verified 2026-05-12.
- Necula, G. (1997). "Proof-Carrying Code". POPL '97 — the proof-witness vs proof-obligation distinction.
- `swift-institute/Skills/memory-safety/safety-isolation.md` ([MEM-SAFE-020]–[MEM-SAFE-026]) — institute safety isolation rules.
- `swift-institute/Research/swift-safety-model-reference.md` — institute-side SE-0458 reference, Tier 2 DECISION 2026-03-25.
- `swift-institute/Research/mem-safe-025-reconciliation.md` v1.1.0 DECISION — the Wave 3 Thread 7 decision that produced [MEM-SAFE-025a]/[MEM-SAFE-025b].
- `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md` v1.1.0 DECISION — the Wave 4 carve-out under re-examination.
- `swift-institute/Research/three-tier-linter-rules-partition.md` — the partition doc that articulated "forbid `@safe`" direction.
- `swift-primitives/swift-binary-primitives/Research/SE-0458 Strict Memory Safety.md` — institute-side SE-0458 overview.
- `swift-primitives/swift-binary-primitives/Research/SE-0458 Audit Methodology.md` — institute-side SE-0458 audit methodology.
- `swift-institute/Research/Reflections/2026-05-12-re-triage-takeifpresent-absorber-anchoring-detection.md` — the re-triage reflection that motivated this re-examination.
