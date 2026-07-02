# Implementation Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/implementation/` (SKILL.md hub + sibling files), following the
> landed platform pattern (`Research/platform-skill-rationale.md`). This document holds evicted rationale
> prose, provenance, extended worked examples, incident narratives, lint-enforcement scope detail, and the
> dated amendment changelog. The skill files remain the CANONICAL source for all `[IMPL-*]` / `[PATTERN-*]` /
> `[COPY-*]` / `[API-LAYER-*]` / `[SEM-DEP-*]` requirement statements; nothing in this archive is normative.
> Organized by skill file, then by rule ID in skill order; the dated frontmatter changelog entries are
> collected in the final section. `accessors.md` and `patterns.md` were already lean — nothing evicted.

---

# concurrency.md

## §[IMPL-076] StructSendableClassMember — lint scope detail

**Lint enforcement**: `Lint.Rule.Memory.StructSendableClassMember` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) flags `struct: @unchecked Sendable` declarations whose member block contains a stored property whose type annotation matches the class-name heuristic (`NSObject` / `Thread` / `DispatchQueue` / `AnyObject` known set; or any identifier ending in `Class` / `Reference`). Plain `Sendable` structs, structs with value-typed members only, and structs without Sendable conformance are not flagged. Mechanical class-vs-struct classification requires symbol resolution; the heuristic is narrow. Added Wave 4 mechanization 2026-05-11. [VERIFICATION: AST Lint.Rule.Memory.StructSendableClassMember]

---

## §[IMPL-085] Why `@unchecked Sendable` loses

**Why `@unchecked Sendable` loses**: Granting `@unchecked Sendable` to a type makes it freely shareable across ALL isolation boundaries, at all call sites, forever — regardless of whether the lock is present. The assertion is about the type; the safety is about a specific site. `sending` + `nonisolated(unsafe)` scopes the unsafe promise to the exact transfer point where the lock dominates, preserving the type's unsendability elsewhere.

---

## §[IMPL-085] Provenance

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-08-architectural-simplification-and-api-consolidation.md` — `Handle.Slot` rendezvous pattern replaced initial `@unchecked Sendable` design.

---

## §[IMPL-088] Rationale

**Rationale**: Lock ordering deadlocks are invisible in pseudo-code that describes lock scopes via indentation. They surface only when two threads encounter the cross-lock interaction simultaneously. A "lock ordering" column in any design table forces the interaction to be analyzed before implementation. Separated scopes are the default because they require no global ordering invariant — the fewer invariants the architecture depends on, the fewer ways it can fail.

---

## §[IMPL-088] Provenance

**Provenance**: `swift-institute/Research/Reflections/2026-04-15-executor-primitives-l1-and-l3-compositions.md` — ABBA deadlock in Stealing's `trySteal` under own lock; `Scheduled`'s `base.enqueue` under scheduled lock. Both fixed by separating lock scopes.

---

## §[IMPL-083] Why Handle is required (full walkthrough)

**Why Handle is required**: the executor is a stored property being assigned in the actor's init. The tick closure literal is the RHS of that assignment. Self-capture in the RHS (`[weak self]`, `[self]`, bare `self`) is rejected by Swift 6.3's DI rule because `self.executor` is not yet initialized. A local `let handle = Handle()` captured by the tick (not self) sidesteps DI — the closure captures the local binding, and the tail `handle.actor = self` runs after all stored properties are assigned.

---

## §[IMPL-083] Closed avenues on Swift 6.3 (full survey)

**Closed avenues on Swift 6.3** (see `swift-foundations/Experiments/`): `sending @escaping` at init, `@isolated(any)` sync or async tick, `var polling: Polling! = nil` default, `Unmanaged.passUnretained(self)` during init, stored-Handle captured by name (compiles but provides no structural improvement), polling-as-actor (actor cannot be its own executor), alternative custom SerialExecutor patterns (SE-0424 IS the canonical pattern), macro-based Handle synthesis (expands to equivalent binary), Swift 6.4+ DI relaxation (no evidence in swiftlang/swift tree as of 2026-03-16 snapshot).

---

## §[IMPL-091] Rationale

**Rationale**: Region analysis operates on types and closure annotations at compile time. It sees a task-isolated closure parameter passed into an actor-isolated closure body and treats the call as a boundary crossing — even when the runtime executor identity means no boundary is actually crossed. The runtime verifies via `isIsolatingCurrentContext` ([IMPL-083]); the compile-time analysis verifies via regions. Both systems must be satisfied, because they operate at different abstraction levels. Materialising the result into `Sendable` locals is the generic bridge: the locals cross the region boundary freely, and the closure body only reads them.

---

## §[IMPL-091] Provenance

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-15-polling-tick-isolation-checkisolated-landing.md` — `IO.Events.Actor` tick rewrite; `Polling.swift:220-228` is the internal precedent.

---

## §[IMPL-098] Provenance

**Provenance**: 2026-04-16-io-completions-full-delegation-and-simplification.md

---

## §[IMPL-099] Provenance

**Provenance**: 2026-04-16-io-completions-test-support-and-witness-factory.md

---

# errors.md

## §[IMPL-042] Problem / Solution analysis

**Problem**: Typed throws with a *generic* error parameter cannot always be specialized away by the compiler. Even when the caller binds the parameter to `Never`, a generic outer type (e.g. `struct Parser<Sink: Handler>` where `Handler.Failure` is the propagated error) hides the binding from the body's codegen. The callee retains error-propagation scaffolding — boxing, spill slots, and cleanup edges that can never execute — and the hot path pays for machinery it does not use.

**Solution**: Duplicate the hot-path body under a `where` clause that fixes the propagated error to `Never`. Because the duplicated body is compiled in a context where the error type is *concrete*, the compiler eliminates the propagation scaffolding entirely. This is a direct application of [IMPL-COMPILE]: the invariant "this callback cannot throw" is expressed where the compiler can act on it.

---

## §[IMPL-042] Provenance

**Provenance**: `compnerd/xylem` `Sources/SAXParser/SAXParser.swift:309` — the duplicated `parse(bytes:)` under `where Processor.Failure == Never` eliminates per-callback error boxing in the SAX hot loop. The source comment at line 313 explicitly warns: *"The body is intentionally duplicated from the generic overload so the compiler can eliminate per-callback error boxing when Failure == Never. Do not fold the two paths together without measuring SIL."*

---

## §[IMPL-042] GenericNeverSpecialization — full recognizer detail

**Lint enforcement**: `Lint.Rule.Throws.GenericNeverSpecialization` (in `swift-foundations/swift-institute-linter-rules`, target `Institute Linter Rule Throws`) flags public generic functions / initializers declared `throws(<G>.<Sub>)` where `<G>` is a generic parameter visible in the enclosing type clause, the function's own generic clause, or an `extension Type<G>` short-form. The rule surfaces the missing specialization as a **review prompt** — the developer applies the "When to apply" table above to decide whether duplication is justified. Concrete throw types and untyped throws are not flagged.

The recognizer skips two well-defined non-firing cases:

1. **`@inlinable` / `@_alwaysEmitIntoClient` declarations**. The developer has opted into cross-module inlining; the compiler can specialize at consumer call sites without a duplicated body. The codegen-scaffolding premise that motivates the rule does not apply to these declarations.
2. **In-extension Never companion already present**. When a sibling function or initializer in the same extension carries a `where <G>.<Sub> == Never` clause and shares the same baseName as the throwing declaration, the rule's recommendation has already been addressed. The recognizer detects this in-extension companion via a single member-block pre-scan and suppresses the firing.

These two skips reflect the rule's design as a review prompt rather than a hard requirement: when the developer has either declared inlinability (case 1) or supplied a companion (case 2), the rule's prompt has been satisfied, and re-firing is a recognizer defect.

For declarations where neither skip applies, the disposition is per the "When to apply" table: if any condition fails, the duplication is unjustified and the firing should be suppressed via `// swift-linter:disable:next generic throws missing never` with a `// REASON:` continuation citing the failing condition. Bare suppression is forbidden per the rule corpus discipline; documented suppression is the canonical "considered, not justified" disposition.

Added Wave 3 mechanization 2026-05-11; recognizer refined 2026-05-19 with `@inlinable` exemption + in-extension companion detection. [VERIFICATION: AST Lint.Rule.Throws.GenericNeverSpecialization]

---

## §[IMPL-092] Two-callback fallback — failure signatures

**Two-callback storage fallback for toolchain-blocked thunk composition**: when the thunk form is blocked by a compiler bug involving composed `~Copyable` + `sending` + `@Sendable` capture (e.g., SILGen crash in `emitApplyWithRethrow` → `buildThunkBody` → `createThunk`, or bogus SIL detonating at runtime as task-allocator violation), internal storage MAY fall back to *two-callback storage* — separate `_onValue` and `_onError` closures — while keeping the consumer-facing interface on `throws(E)`. Two-callback storage is denotationally equivalent to a tagged union; it loses the single-point-of-delivery intuition of a thunk but preserves the public-interface typed-throws semantics.

---

## §[IMPL-092] Precedent

**Precedent**: `copypropagation-nonescapable-fix.md` applies the same discipline at the `~Escapable` layer — Property.View omits `~Escapable` to avoid a CopyPropagation bug, with the omission tracked as a revisit trigger, not treated as architectural surrender.

---

## §[IMPL-092] Heuristic for toolchain-blocked composition

**Heuristic for recognizing toolchain-blocked composition** (as distinct from code-shape problems): when three or more ownership/concurrency primitives layer at a single syntactic site (`~Copyable` + `sending` + `@Sendable` capture + typed-throws + `consuming`), expect a compiler bug before assuming the code shape is wrong. The `Kernel.Event.Driver.swift` `var slot + take!` pattern works *synchronously*; when the same pattern is pushed inside a `sending` thunk captured by an `@Sendable` async closure, Swift 6.3.1 produces either a SILGen crash or a runtime task-allocator violation. The failing configuration is the composition, not any single part.

---

## §[IMPL-092] Provenance

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-15-polling-tick-throws-thunk-over-result.md` — Polling tick signature migrated from `Result<T, E>` proposal to `() throws(E) -> T` thunk after user override: "use LANGUAGE SEMANTICS so throws see /implementation." Two-callback fallback added per 2026-04-17-effect-primitives-ncopyable-widening-silgen-workaround.md — `Effect.Continuation.One` storage reshaped from `sending` thunk (SIGABRT on first suspension) to `_onValue`/`_onError` callback pair with `noncopyable-optional-capture-crash` reproducer experiment and revisit trigger.

---

## §[IMPL-092] ResultCallback — lint scope detail

**Lint enforcement**: `Lint.Rule.Throws.ResultCallback` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Throws`) walks `FunctionTypeSyntax` (closure types appearing in function/init parameters and stored properties) and flags each parameter type that is `Result<T, E>` or `Swift.Result<T, E>` after stripping optional / attributed wrappers. Function-return `Result` and top-level (non-closure-parameter) `Result` parameters are not flagged — they could be storage-shape uses of Result. Added Wave 3 mechanization 2026-05-11. [VERIFICATION: AST Lint.Rule.Throws.ResultCallback]

---

## §[IMPL-093] Rationale (origin incident)

**Rationale**: The consuming move transfers ownership to the destination (Entry); the nil reinitialization satisfies the ownership checker that the capture slot is valid for the closure's remaining lifetime. This is a language-level pattern, not an ecosystem-level abstraction. The 2026-04-16 IO.Completion.Storage elimination used this pattern to move `~Copyable` descriptors into proactor Entry records without introducing any wrapping types.

---

## §[IMPL-093] Provenance

**Provenance**: 2026-04-16-io-completion-storage-elimination.md

---

## §[IMPL-108] Provenance

**Provenance**: swift-sockets Phase 3B Linux hot-spin (2026-03-15) — `Kernel.Completion.Notification.wait()` swallowed `EAGAIN`, four io_uring Loop threads hot-spun at 99.9% CPU. Pre-fix file: `swift-kernel/Sources/Kernel Completion/Kernel.Completion.Notification+Wait.swift`.

---

## §[IMPL-109] The mechanism

**The mechanism**: `do throws(E) { ... }` constrains the implicit `error` in the catch to `E` per [IMPL-075], so `return .failure(error)` is well-typed. The closure passed to the stdlib function is non-throwing (returns `Result<T, E>`), so the stdlib's `rethrows` is a no-op at the call site. `try result.get()` outside the call propagates the typed error cleanly.

---

## §[IMPL-109] Already-canonical sites (extended)

**Already-canonical sites in the ecosystem**: `Array.withUnsafeBufferPointer` (typed-throws overload), `withUnsafeTemporaryAllocation`, and now `withTaskCancellationHandler` use this shape. A less-clean parallel pattern (typed-catch + `preconditionFailure` for the unreachable arm) has accumulated in some files; SHOULD be rewritten when encountered.

---

## §[IMPL-109] Worked example (origin incident)

**Worked example (the origin incident, 2026-05-08)**: `swift-standard-library-extensions/Sources/.../withTaskCancellationHandler.swift` originally used `throw error as! E` (force-cast); a Phase 1 lint fix replaced it with typed-catch + `preconditionFailure`; user pushback ("isn't this unnecessary with 100% typed throws?") pushed convergence to the Result-wrapper pattern already used elsewhere in the same package. Same shape, three-cycle convergence — codifying the canonical form prevents re-derivation.

---

## §[IMPL-109] Provenance

**Provenance**: `swift-standard-library-extensions/Sources/.../withTaskCancellationHandler.swift` commit `ef3b09e` (2026-05-08); existing precedent in `Array.withUnsafeBufferPointer` and `withUnsafeTemporaryAllocation` typed-throws overloads.

---

## §[IMPL-112] Provenance

**Provenance**: memory `feedback_either_error_composition.md` (Kernel error-shape decision; cross-cutting concerns via Either+typed-throws over polluted domain enums or Kernel.Outcome).

---

# infrastructure.md

## §[IMPL-010] Naming.IntParameter — lint scope detail

**Lint enforcement (public API surface)**: `Lint.Rule.Naming.IntParameter` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags bare `Int` (or `Swift.Int`) parameters AND return types in `public` / `open` function and initializer signatures. Optional and implicitly-unwrapped Int wrappers are detected; closure-typed parameters (the closure may legitimately take Int internally) and tuple-typed parameters are exempt. Sized integers (`Int8`/`Int16`/`Int32`/`Int64`/`UInt`/`UInt8`–`UInt64`) are NOT flagged — those are valid domain types (`Int32` for fd, `UInt8` for byte). Typed wrappers (`Index<T>`, `Cardinal`, `Ordinal`, `Count<T>`, `Offset<T>`) do not match the literal `Int` token and are NOT flagged. Non-public visibility is exempt. Added Wave 1 mechanization 2026-05-10. [VERIFICATION: AST Lint.Rule.Naming.IntParameter]

---

## §[IMPL-011] Memory.PointerArithmetic — lint scope detail

**Lint enforcement**: `Lint.Rule.Memory.PointerArithmetic` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Memory`) walks `FunctionCallExprSyntax` for `<expr>.advanced(by: <expr>)` member-access calls with a single `by:`-labelled argument. The flag catches the canonical raw-pointer-arithmetic shape at consumer call sites — types managing memory SHOULD provide a typed slot `subscript` and the Span family (`span` / `mutableSpan` / `outputSpan`) instead of exposing raw offset arithmetic. Bare `+`/`-` operator arithmetic on pointer types is harder to detect mechanically (requires type information) and is out of scope; the named-method form is the dominant idiom. Added Wave 4 mechanization 2026-05-11. [VERIFICATION: AST Lint.Rule.Memory.PointerArithmetic]

---

## §[IMPL-089] Why (full performance analysis)

**Why**: `Character` iteration + `distance(from:to:)` produces O(n²) complexity on every re-index. Grapheme cluster boundary analysis on each iteration is 10-1000× slower than byte comparison. For the vast majority of foundation-free scans (newline discovery, substring search, percent decoding, path component splitting), byte-literal matching is the correct semantics — and the only semantics that does not require a Unicode table dependency.

---

## §[IMPL-089] Rationale

**Rationale**: At L1/L2, byte-level is the right abstraction unless grapheme semantics are explicitly required. Foundation-free types cannot carry Unicode tables; pretending to provide Character equivalence without those tables either produces wrong results or reaches through to the stdlib's Unicode data, which is a hidden dependency. Byte-literal matching is explicit, O(n), and correct for the use cases where it applies.

---

## §[IMPL-089] Provenance

**Provenance**: `swift-institute/Research/Reflections/2026-04-15-utf8-perf-and-string-primitives-shadow-fix.md` — `StringProtocol.range(of:)` and `Parsers.Diagnostic.Source.init` converted from O(n²) Character scans to UTF-8 byte scans. External trigger: tuist/FileSystem#325.

---

## §[IMPL-089] StringUTF8Scanning — lint scope detail

**Lint enforcement**: `Lint.Rule.Idiom.StringUTF8Scanning` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Idiom`) flags `.unicodeScalars` member access — the institute default at L1 / L2 is `.utf8` byte-view scanning. The rule cannot resolve the base type per-file; bare `.unicodeScalars` is rare enough outside string scanning that false positives are acceptable. `.utf8` and direct `Character` access are not flagged. Added Wave 3 mechanization 2026-05-11. [VERIFICATION: AST Lint.Rule.Idiom.StringUTF8Scanning]

---

## §[IMPL-090] Rationale

**Rationale**: An abstraction seam's validity is measured by data flow, not by surface shape. Two patterns can have matching method signatures ("both are executors with a run loop") while having non-overlapping data contracts (one emits events, the other consumes CQEs from a separate ring). Forcing the mismatched pair through a shared shell produces code where the core data contract is ignored — the shell's promise ("I hand you the important data") is broken at the seam.

---

## §[IMPL-090] Provenance

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-15-completion-loop-proactor-reactor-boundary.md` — Polling (reactor) and IO.Completion.Loop (proactor) cannot share the run loop because proactor requires flush-before-wait, and the reactor shell's tick emits data the proactor consumer ignores.

---

## §[IMPL-095] Rationale (worked failure mode)

**Rationale**: Platform-guarded imports are the most fragile class of import because they're invisible to the builder on the wrong platform. A silent drop of `@_spi(Syscall) import Kernel_Completion_Primitives` inside a `#if os(Linux)` block passes macOS builds and fails Linux Docker builds; the gap between commit and failure report is long enough that the cause becomes hard to locate. The verbatim-preservation-plus-diff discipline closes the window at the commit point.

---

## §[IMPL-095] Provenance

**Provenance**: 2026-04-17-kernel-completion-opcode-enum-reshape-implementation.md

---

# ownership.md

## §[PATTERN-022] validate-package-shape — lint scope detail

**Lint enforcement**: Reusable workflow `validate-package-shape.yml` + companion `.github/scripts/validate-package-shape.py` walk Sources/**/*.swift and flag files whose top-level declaration is a generic type carrying a `~Copyable` constraint AND whose body contains nested `struct`/`class`/`enum`/`actor` declarations — the in-body nested type SHOULD be hoisted to a sibling file via `extension Parent where Element: ~Copyable { … }` per the rule. The check is narrow: ManagedBuffer nesting-level constraints are out of scope (whole-module concern). Wave 4 mechanization 2026-05-11. [VERIFICATION: WF validate-package-shape.py (PATTERN-022)]

---

## §[IMPL-096] Provenance

**Provenance**: 2026-04-22-investigation-only-cycle-three-doc-pattern.md

---

## §[IMPL-106] Rationale (origin formulation)

**Rationale**: The implementation skill's foundational axioms ([IMPL-INTENT], [IMPL-COMPILE], [IMPL-002], [IMPL-010], [PATTERN-017]) require code to read as intent and the compiler to enforce ownership invariants. Custom shadow types and raw-Int overloads are mechanism leaks. The user-corrected formulation: "we want to minimize raw Int overloads and use actual types" and "ALWAYS leverage the language over custom concepts. Why not use `borrowing`/`consuming` appropriately?"

---

## §[IMPL-107] Provenance

**Provenance**: 2026-05-07 swift-linter cohort surfaced `Lint.Configuration._ParentBox` (`swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Configuration.swift`) as the canonical instance of the pattern.

---

## §[IMPL-107] Naming.BoxClass — lint scope detail

**Lint enforcement**: `Lint.Rule.Naming.BoxClass` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags free-standing `class` declarations whose name (after stripping a leading underscore) is in `{Box, Storage, Wrap, Wrapper, Cell}` AND which carries no inheritance clause. Classes with inheritance (framework hierarchies, `ManagedBuffer`-derived buffers) are exempt. The heuristic targets bare ad-hoc wrappers; legitimate domain types named `StorageRing` / `WrapperDescriptor` etc. (longer names, distinct semantics) are not flagged. Added Wave 4 mechanization 2026-05-11. [VERIFICATION: AST Lint.Rule.Naming.BoxClass]

---

# style.md

## §[IMPL-086] Rationale

**Rationale**: Swift's type system does not have to defend every invariant. Invariants fall into two classes: (1) load-bearing — deleting them breaks memory safety, user contracts, or compositional correctness, and (2) author-imposed — we wrote the check because it seemed tidy, but the looser contract produces acceptable behavior. Class 2 is surprisingly common in actor-based designs where state machines accumulate.

---

## §[IMPL-086] Provenance

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-08-parent-side-deletion-vs-addition.md` — actor-state visibility fix where 5 proposal iterations of "add structure" preceded the realization that deletion was the right move.

---

## §[IMPL-087] Rationale

**Rationale**: Every IO framework tutorial starts with "create an event loop." This creates the implicit premise that every backend needs one. Modern kernel interfaces (io_uring's shared-memory rings, IOCP's completion port semantics, eventfd notification) were designed specifically to invalidate that premise. Building on the inherited convention reproduces the constraints of older paradigms inside a newer one.

---

## §[IMPL-087] Architectural corollary of [IMPL-000]

**The architectural corollary of [IMPL-000]**: at call sites, "write the ideal expression first; improve the infrastructure if it doesn't compile." At the architecture level, "write the ideal system first; question the component if it does not serve a consumer." Same principle, different scope.

---

## §[IMPL-087] Provenance

**Provenance**: `swift-foundations/swift-io/Research/Reflections/2026-04-09-io-uring-no-separate-loop.md` — `IO.Completion.Loop` proposed, then deleted after recognizing that io_uring + eventfd requires no separate poll thread.

---

## §[IMPL-094] Provenance

**Provenance**: 2026-04-17-audit-borrowing-self-chained-property-access.md (`Executor.Job.Priority.Entry` reproduction)

---

## §[IMPL-097] Provenance

**Provenance**: 2026-04-21-mod-017-batch-followups-silgen-workaround-shaping.md

---

## §[IMPL-101] Worked example (origin incident)

**Worked example (the origin incident)**:

A 2026-04-23 Ownership.Borrow.`Protocol` cascade hit a §8.4 escalation: widening `Value: ~Copyable & ~Escapable` forced a storage rewrite from `UnsafePointer<Value>` to `UnsafeRawPointer`. Recommended Option B — narrow the protocol to keep the typed pointer storage simpler — citing YAGNI. User pushed back: "wouldn't the pointer stuff be internal anyway?" The pointer machinery was confined behind `@usableFromInline let _storage` and `where Value: ~Copyable & ~Escapable` constrained extensions; consumers with `Escapable` Value still saw a fully-typed API regardless of storage. The "simpler" option was simpler-internally but less-flexible-externally — the wrong trade. Corrected disposition (Option A — keep the DECISION shape) preserved internal complexity in exchange for a more flexible external surface; the constrained-extension layering was working as designed.

---

## §[IMPL-101] Rationale

**Rationale**: YAGNI is a design discipline against speculative external surface. When applied to internal-to-type machinery, it inverts: the machinery exists precisely to keep the external surface clean. Misapplying YAGNI to internal complexity biases the design toward narrow-surface shapes that require retrofitting when a genuine consumer arrives — exactly the future-cost YAGNI is supposed to prevent.

---

## §[IMPL-101] Provenance

**Provenance**: Reflection `2026-04-23-borrow-protocol-unification-full-cascade-and-iso-9899-tail.md` (§8.4 Option B misrecommendation).

---

## §[IMPL-102] Provenance

**Provenance**: Reflection `2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md` (Group A's "structural composition limit in Swift" finding — overlapping conditional conformances on Tagged blocked the original Cardinal/Ordinal capability-lift proposal).

---

## §[IMPL-103] Why manual children-cast is unsafe (full analysis)

**Why manual children-cast is unsafe**: `expr.children(viewMode:)` is a *shallow* iterator over immediate children, not a deep iterator over descendants. The cast-and-recurse pattern looks like a tree traversal but skips every intermediate node whose syntactic type is not the cast target. SwiftSyntax has many such intermediate types — function-call argument lists, closure capture clauses, member-access argument expressions — and they are exactly where descendant `MemberAccessExprSyntax` / `IdentifierExprSyntax` references hide. The defect is silent: the predicate appears to work on simple call sites and returns false for the very call sites the predicate was authored to catch.

---

## §[IMPL-103] Rationale

**Rationale**: SwiftSyntax's `SyntaxVisitor` walks the full descendant tree regardless of intermediate node types — it dispatches per-type without requiring the caller to predict which intermediate-type chains the target node hides under. Manual children-cast recursion couples the predicate to SwiftSyntax's syntactic structure, which is rich and revision-sensitive. The visitor pattern is the idiomatic abstraction; the children-cast pattern is appealing because `children()` looks like a tree iterator, but it is a shallow iterator, and using it for descendant search is a category error.

---

## §[IMPL-103] Provenance

**Provenance**: Reflection `2026-05-07-d4-linter-rules-predicate-narrowing-and-readme-repair.md` (initial `containsCountMemberAccess` truncated against `LabeledExprListSyntax` inside function-call argument lists; SyntaxVisitor switch resolved).

---

## §[IMPL-104] The institute case (Array.Builder)

**The institute case**:

`Standard_Library_Extensions/Array.Builder` declares four overloads:

```swift
@resultBuilder public struct Builder {
    public static func buildExpression(_ x: Element) -> [Element] { [x] }
    public static func buildExpression(_ xs: [Element]) -> [Element] { xs }
    public static func buildExpression<S: Sequence>(_ s: S) -> [Element] where S.Element == Element { Array(s) }
    public static func buildExpression(_ x: Element?) -> [Element] { x.map { [$0] } ?? [] }
}
```

At an unconstrained top-level call site like `Lint.Configuration(rules: { .enable(R.self) })`, the compiler sees the leading-dot needing a contextual type, finds 4 candidates, prefers `[Element]` (the buildBlock parameter shape), and looks for `enable` on the array. The lookup fails (`'[Lint.Rule.Configuration]' has no member 'enable'`).

---

## §[IMPL-104] Rationale

**Rationale**: Multi-overload `buildExpression` is a deliberate ecosystem-wide design choice in `Array.Builder` — it serves many call-site shapes (single elements, arrays, sequences, optionals) so consumers don't write `[x]` boilerplate. The cost of that ergonomic flexibility is leading-dot ambiguity at unconstrained top-level positions. Single-overload result-builders (rare in the institute ecosystem) wouldn't have this problem; the multi-overload design is intentional and the qualification rule is the corresponding documentation discipline. Companion to [IMPL-094] (chained-property `&&` rejection on `borrowing Self`) — both are Swift compiler ergonomics codified as institute rules at the consumer-template authoring layer.

---

## §[IMPL-104] Provenance

**Provenance**: Reflection `2026-05-07-lint-manifest-drop-and-array-builder-inference.md` (first build cycle of `swift-tagged-primitives/Lint/Sources/Lint/main.swift` typed-DSL conversion; bare `.enable(R.self)` failed; fully-qualified `Lint.Rule.Configuration.enable(R.self)` succeeded; verified at commit `4f5d467`).

---

## §[IMPL-105] Worked example (origin incident)

**Worked example (the origin incident)**:

The 2026-05-07 result-builder performance research initially recommended shipping `Repeat<S: Sequence, Element>` as a wrapper that defers iteration into a builder body. The user's "no new type in standard-library-extensions" constraint forced a search for a non-type fix. Discovery: a bare `buildExpression<S: Sequence>(_ s: S) -> [Element] where S.Element == Element` overload measured 0.13–0.17× of imperative for direct sequences — *strictly faster* than `Repeat`, with less code shipped. The overload subsumed `Repeat`'s value-add ("I'm a thing that defers iteration") because `Sequence` is already that vocabulary. Without the user constraint, the institute would have shipped a parallel-name redundant type.

---

## §[IMPL-105] Rationale

**Rationale**: The institute's multi-package ecosystem has many protocols (`Sequence`, `Collection`, `Comparable`, etc.) that already encode common shapes. Adding wrapper types in parallel produces vocabulary fragmentation: callers must learn the new wrapper's name, when to reach for it vs the protocol, and the wrapper-vs-protocol-overload trade-off at every consumer site. An overload accepting the existing protocol preserves the protocol's primacy and reduces ecosystem learning load. The exception (phantom-type / compile-time tagging) is the case where the wrapper IS the novel semantics — `Tagged<Domain, Raw>` is justified because the tagging IS the value-add, not because it wraps a `Raw`.

---

## §[IMPL-105] Provenance

**Provenance**: Reflection `2026-05-07-result-builder-map-anomaly-refuted.md` (Pattern 1: shipping a redundant type; near-miss prevented by user's no-new-type constraint).

---

## §[IMPL-110] Worked example (origin incident)

**Worked example (the origin incident)**:

The 2026-05-07 D7' Path.Filter runtime enforcement typed at the rim only — `[Tagged<Path.Filter, Swift.String>]` at the surface, `.underlying` at every internal call site. D7'' added `Tagged.hasPrefix` as a single mechanism site that operated on tagged values throughout, eliminating `.underlying` at every operation. Before/after `.underlying` grep count was 18→0.

---

## §[IMPL-110] Provenance

**Provenance**: Reflections `2026-05-07-d7p-typed-throughout-correction.md` (D7'' typed-throughout correction; `Tagged+HasPrefix` boundary helper as the model), `2026-05-07-d7-path-filter-runtime-enforcement.md` (D7' rim-only typing defect that motivated the correction).

---

## §[IMPL-111] Why (origin incident detail)

**Why**: The ecosystem has *three* owning string types (`String_Primitives.String`, `Kernel.String`, `ISO_9899.String`). D1 of `string-type-ecosystem-model.md` bans a fourth. The platform-varying element type is already solved by `String_Primitives.String.Char` (= `UInt8` POSIX / `UInt16` Windows), chained through `Path.Char` via `swift-path-primitives/Path.swift:59`. In the 2026-04-20 swift-file-system session, `File.Name.RawEncoding` — a two-case enum with a dead case per platform — was discovered to be re-solving what `Path.Char` already solves. The refactor to `rawBytes: [Path.Char]` (commit `4515c23`) deleted 14 `switch rawEncoding` sites, eliminated the `#if os(Windows)` in `init(from:)`, and net +141/-205. Three iterations of consumer-side mechanism were needed because this check was not performed up front.

---

## §[IMPL-111] Worked example

**Worked example**: 2026-04-20 `Kernel.Directory.Entry.rawName` NUL-leak investigation initially proposed promoting `Kernel.File.System.Name` from namespace to typed value — would have been the fourth parallel string type, compounding D1 — when the correct fix was a three-line consumer change using existing `Kernel.Directory.Entry.nameView: Kernel.Path.View` API.

---

## §[IMPL-111] Provenance

**Provenance**: memory `feedback_ecosystem_type_adoption_check.md` (folded from `feedback_grep_research_before_new_types.md` 2026-05-08).

---

# SKILL.md

## §Changelog-Provenance

Dated frontmatter changelog entries evicted from `SKILL.md` (verbatim; each was verified to carry no
normative clause absent from the owning rule body before eviction):

```
# 2026-06-11: [PATTERN-059] ADDED (patterns.md design table) — construction pins, operations generic: bind operations to the capability seam, pin only construction to the concrete resource. Principal-ratified at the W5-1 §A15 adoption (arena 208c8d1 / pool 9dd38e7). Additive per [SKILL-LIFE-003].
# 2026-05-11: Wave 4 Bucket 1 doc-gap pass (HANDOFF-mechanization-wave-4.md) — added Lint enforcement + [VERIFICATION] tags for [IMPL-034] in style.md (SwiftLint no_unsafe_block_form + Lint.Rule.Unchecked), [IMPL-040] in errors.md (SwiftLint typed_throws_required + Lint.Rule.Throws.Untyped — mirrors [API-ERR-001]), [IMPL-075] in errors.md (Lint.Rule.Throws.DoCatchTyped + Lint.Rule.Throws.DoCatchTypedThrow), [IMPL-084] in style.md (Lint.Rule.Naming.SingleTypeNamespace), [IMPL-108] in errors.md (SwiftLint no_try_optional + Lint.Rule.Try), [PATTERN-016] in patterns.md (SwiftLint workaround_marker_present — annotated via sidecar "Lint enforcement (per-rule)" block beneath the Anti-Pattern Reference table per [SKILL-CREATE-005] table-row variant). Statements unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003].
# 2026-05-10: Phase 3b TRIM-PROSE — compressed Why prose on [IMPL-108] now that `no_try_optional` lint mechanically enforces. [IMPL-075]/[IMPL-010]/[IMPL-109] bodies already lean, kept as-is. Statements unchanged per [SKILL-LIFE-001].
# 2026-05-10: [IMPL-110] Pair Tagged-Typed Identities With Typed Operations added to style.md per Reflections/2026-05-07-d7p-typed-throughout-correction.md (Cluster I)
# 2026-05-10: [IMPL-111] Ecosystem-Type Adoption Check added to style.md; [IMPL-112] `Either` for Cross-Cutting Error Composition added to errors.md per memory→skill refactor (memories `feedback_ecosystem_type_adoption_check.md`, `feedback_either_error_composition.md`)
# 2026-05-10: Wave 2b lint extraction (HANDOFF-skill-to-ci-cd-extraction-inventory.md) — added Lint enforcement lines for [IMPL-108] in errors.md (SwiftLint custom rule `no_try_optional`) and [IMPL-010] in infrastructure.md (`no_int_bitpattern_arithmetic`). Clarifying per [SKILL-LIFE-003].
# 2026-05-10: Wave 2b finalization Batch 3 (HANDOFF-wave-2b-finalization.md) — added Lint Enforcement appendix mapping [IMPL-075] (Lint.Rule.Throws.DoCatchTyped), [IMPL-109] (Lint.Rule.Throws.RethrowsResultShim). patterns.md gets parallel Lint Enforcement appendix mapping [PATTERN-019] (Lint.Rule.RawValue.TaggedExtensionPublicInit), [PATTERN-052] (Lint.Rule.Structure.InlinableInternalAccess). Clarifying per [SKILL-LIFE-003].
# 2026-05-10: Wave 1 mechanization (HANDOFF-mechanization-wave-1-high-leverage.md) — added Lint enforcement / [VERIFICATION] tag for [IMPL-010] in infrastructure.md mapping the public-API-surface variant to Lint.Rule.Naming.IntParameter (AST rule covering bare Int / Swift.Int in public function or initializer parameters AND return types). Sibling SwiftLint `no_int_bitpattern_arithmetic` continues to cover the call-site form. Statement unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003].
```
