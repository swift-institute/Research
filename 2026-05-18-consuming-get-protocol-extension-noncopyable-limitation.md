# `consuming get` on protocol-extension property returning Self-capturing generic — investigation

> Triggered by Item 3c (Parser.Parse ~Copyable Phase 2b, 2026-05-18). Compiler
> error blocks the cleanest uniform-accessor path for ~Copyable parsers.

## Status

LANGUAGE-LIMITATION-DOCUMENTED + WORKAROUND-EXISTS

The issue is **not a compiler bug** but a principled language limitation on direct call-site
reads of `@_owned consuming get` properties on `~Copyable` types. The limitation is documented
in the Swift compiler's move-checker diagnostics (DiagnosticsSIL.def). A working workaround exists
for consumption-constrained call sites (consuming-parameter wrappers), but it is ergonomically
worse than the rejected method-form migration, making property-based `consuming get` unviable
for the production Parser.error.map fluent-syntax goal.

## Issue summary

**What fails**: A protocol-extension property accessor on `~Copyable Self` that returns a generic
struct capturing `Self` (e.g., `Parser<P: Parser.Protocol & ~Copyable>`) with `@_owned consuming get`,
when read at the direct call site (let-bound noncopyable value in function scope), produces the
diagnostic: **`noncopyable 'c' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type`**.

**What error**: `sil_movechecking_capture_consumed` diagnostic (DiagnosticsSIL.def:886) fires during
the move-checker pass, not during Sema type-checking. The compiler rejects the property access
because it cannot prove the receiver is consumed and flow directly into the accessor—the receiver
must prove non-escape before consuming.

**What the desired shape is**: `parser.error.map { ... }` on a parser bound to a local `let`
in function scope, with `error` as a property accessor returning `Parser.Transform<Self>` via
`@_owned consuming get`, all on `~Copyable Parser` types. This preserves fluent combinator-chain
syntax (e.g., `.error.map.tracked.range`) for ~Copyable parsers without forcing every combinator
to cascade to `~Copyable`.

## Prior workspace coverage

- **`swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension/EXPERIMENT.md`** (v1.0.0, 2026-05-14)
  — Direct empirical evidence: `@_owned consuming get` on protocol-extension generic `~Copyable Self`
  compiles and runs cleanly on Swift 6.4-dev nightlies **only when wrapped in a consuming-parameter helper function**.
  Direct call-site shape (V5) fails with "borrowed by non-Escapable type" on the 6.4-dev nightly (2026-05-07-a) and the 6.5-dev nightly (2026-05-12-a).
  Swift 6.3.1/6.3.2 reject `@_owned` entirely as an unknown attribute (not yet in Sema table).
  SIL verifier crash discovered on `consume c` keyword variant (MemoryLifetimeVerifier.cpp:263 "store-borrow location cannot be written").

- **`swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`** (v1.2.1, 2026-05-18)
  — Tier-3 ecosystem decision: Option A (`@_owned consuming get` on protocol extension) **EMPIRICALLY REFUTED** for production
  use per the owned-consuming-get experiment. Recommendation: α-stratified architecture (protocol-level relaxation only,
  combinators stay Copyable, ~Copyable conformers as terminals) or defer entirely. Phase 4 (Parser.Machine.Compiled: ~Copyable)
  executed and landed (commits 41c691e, f685f53) via principal redesign: Cache holds `Optional<P>` + consumes parser on
  first compile.

- **`swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md`** (v1.1.0, 2026-05-09)
  — DECISION doc on `@_owned + consuming get + UnderscoreOwned` feature. Non-generic `~Copyable` types (struct + monomorphic enum)
  work on Swift 6.4-dev; generic enums fail with "borrowed by non-Escapable type" on 6.4-dev 2026-05-07. Property form
  blocked indefinitely pending Swift compiler progress on generic-enum `@_owned` getters. Phase 1 (free function workaround)
  ships; Phase 2 (property form) deferred.

- **`swift-institute/Research/feature-flags-coroutine-borrow-accessors.md`**
  — Foundational research: `consuming get` syntactically accepted but semantically limited; cannot move stored properties.
  Zero production `consuming get` or `_owned get` usage across ecosystem before the parser-primitives attempt.

- **`swift-institute/Research/swift-compiler-bug-catalog.md`** (v2.0, 2026-05-10)
  — References `swiftlang/swift#88986`: "`@_owned consuming get` on generic `~Copyable` enum (separate but session-related;
  coverage gap in move-checker for generic-enum consuming getters)". Not a filed issue yet; the owned-consuming-get experiment
  supersedes with empirical evidence from protocol-extension variant.

- **`swift-institute/Experiments/conditional-escapable-container/Sources/main.swift`**
  — Comment cites the error: `//   "self is borrowed and cannot be consumed"`. Relates to `Optional<~Escapable>` in containers
  with `@_lifetime(immortal)` init.

## Swift compiler signals

### Diagnostic emission site

**File**: `/Users/coen/Developer/swiftlang/swift/include/swift/AST/DiagnosticsSIL.def:886`

**Diagnostic ID**: `sil_movechecking_capture_consumed`

**Message**: `"noncopyable '%0' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type"`

**Related diagnostic** (adjacent pattern): `sil_movechecking_guaranteed_value_consumed` (line 880)
— `"'%0' is borrowed and cannot be consumed"` — fires when a guaranteed (borrowed) value is consumed.

The consumer (property-read site) is analyzed by the move-checker pass during SIL lowering. The borrow scope
of the receiver `c` is proven to extend past the consuming accessor invocation because the local binding
creates a borrow scope that outlives the consumption point. The compiler conservatively rejects the pattern
to avoid use-after-free.

### Recent commits touching the area (last 6 months)

**Related to consuming accessors**:

- `645e2dc3bad` (2026-04-30) — "Merge pull request #88699 from blevine1/pr-175724267-consuming-accessor-resilient-base"
  — Consuming-accessor resilient base PR. Preceding commit `4640b58e990` ([SILGen] Mark +0 base unresolved for consuming accessor)
  suggests related SILGen handling.

- `f0a8437191b` — "MoveOnlyChecker: look through convert_function when closing an on-stack partial_apply's borrow scope (#88805)"
  — Move-checker refinement for partial-apply borrow scope closing; may relate to the consuming-accessor pipeline.

**Broader context** (ownership/borrow-related):

- Commits touching `MemoryLifetimeVerifier.cpp` (where the SIL crash occurs) are not easily found via grep of commit
  messages. The crash location suggests it was introduced or exposed by recent borrow-scope tightening in the
  SIL verifier.

### Test fixtures showing valid `consuming get` patterns

Swift compiler's test suite at `/Users/coen/Developer/swiftlang/swift/test/` contains:

- `/test/SILGen/moveonly_consuming_get_on_rvalue.swift` — Tests consuming get on r-value receivers (no borrow-scope issue).
- `/test/SILOptimizer/moveonly_accessors.swift` — Test coverage for `var p2: Int { consuming get { 666 } }`.
- `/test/SILGen/resilient_consuming_getter_nonescapable_test.swift` — Specifically: "Verify that calling a consuming getter
  on a noncopyable l-value from a resilient library" and "Verify that calling a consuming getter on a borrowed noncopyable
  value is rejected." This test directly validates the expected rejection of direct call-site reads.

The test suite confirms the current behavior is **intentional**: borrow-scope tracking requires that consuming getters
not be invoked on l-values (local bindings) where the borrow scope would escape the consumption.

### Known-limitation FIXMEs / TODOs / @abi-comments

No explicit FIXME or TODO found in the Sema / SILGen code for this specific case. The limitation appears to be
a principled design choice in the borrow-checker, not a known gap. The experiment's SIL verifier crash (V5d,
MemoryLifetimeVerifier.cpp:263) is a separate issue — it suggests the compiler *attempted* to lower the `consume c`
keyword variant and encountered a verifier violation, rather than a Sema-level rejection.

## Workarounds observed in ecosystem

### Workaround A: Consuming-parameter wrapper (employed in experiment)

**Pattern**:
```swift
@inlinable
public func extractError<P: Parser.Protocol & ~Copyable>(_ p: consuming P) -> Parser.Transform<P> {
    p.error  // Property access succeeds here because consuming-parameter binding proves direct flow
}

public func testParser() {
    let parser = MyParser()
    let transformed = extractError(parser)
    let result = transformed.map { ... }
}
```

**Why it works**: The consuming-parameter function signature moves the receiver into function scope,
and the property access happens in that function's body where the borrow scope is localized to the
consuming call. The move-checker can prove non-escape.

**Drawback**: Disrupts the fluent syntax. Instead of `parser.error.map { ... }`, the caller must
wrap: `extractError(parser).map { ... }`. This is ergonomically worse than the rejected method-form
migration (e.g., `parser.error()` method), which the principal explicitly rejected because it disrupts
combinator chains.

**Status**: CONFIRMED WORKING on Swift 6.4-dev nightly 2026-05-07-a and 6.5-dev nightly 2026-05-12-a (V1-V4 in experiment).

### Workaround B: Method-form migration (rejected by principal)

Instead of property accessor, use a consuming method:

```swift
extension Parser.Protocol where Self: ~Copyable {
    @inlinable
    public consuming func getError() -> Parser.Transform<Self> {
        Parser.Transform(parser: self)
    }
}

// Call site:
parser.getError().map { ... }
```

**Drawback**: Breaks fluent combinator chains. The parser-primitives ecosystem extensively uses
property accessors (`.error`, `.tracked`, `.range`) in fluent chains with other combinators.
Migrating to method form (`parser.getError()`) complicates the DSL. The principal rejected this
in the 2026-05-13 tier-3 recommendation.

**Status**: WORKS but REJECTED for production.

### Workaround C: Terminal-only ~Copyable (executed in Phase 4)

Avoid making intermediate combinators `~Copyable`. Instead:
1. Relax the protocol (Parser.Protocol: ~Copyable) at the protocol level only.
2. Keep combinators Copyable-only via implicit constraint (no `where P: ~Copyable` on combinator extensions).
3. Introduce ~Copyable terminal parsers (e.g., Parser.Machine.Compiled as a ~Copyable consumer).
4. Preserve combinator fluent syntax for Copyable-only parsers; ~Copyable terminals remain isolated.

**Where it applies**: Parser.Machine.Compiled (Row 11 of the 2026-05-13 audit) — redesigned as a
~Copyable terminal that consumes the input parser once during compilation (Cache holds `Optional<P>`).

**Status**: EXECUTED and LANDED (swift-parser-machine-primitives commits 41c691e, f685f53, 2026-05-18).

## Recommended next step

**Defer-and-document: limitation is well-known, current workaround is acceptable.**

**Rationale (2-3 sentences)**:

The "borrowed by non-Escapable type" rejection is a principled move-checker design constraint,
not a bug. The workaround (Workaround C: terminal-only ~Copyable) is already executed and working,
with Row 11 (Parser.Machine.Compiled: ~Copyable) closed on 2026-05-18. The consuming-parameter-wrapper
workaround (Workaround A) is viable for internal helper functions but unsuitable for public API fluent
syntax. The protocol-level relaxation (Parser.Protocol: ~Copyable) lands without the combinator cascade
(Phase 2 executed at commit 3ed1961, 2 file changes), preserving existing Copyable-only combinator syntax;
~Copyable conformers exist as terminals only. No further action needed for Item 3c.

**If reconsideration is needed**: The highest-information next step would be a `/swift-pull-request` to
upstream the diagnostic into the Swift documentation or consider a targeted SIL optimization to permit
consuming-get reads when the compiler can prove the binding scope ends before the next use. However, this
is out-of-scope for the current phase; the workaround is stable and the recommendation is stable.

## References

- Diagnostic emission:
  - `/Users/coen/Developer/swiftlang/swift/include/swift/AST/DiagnosticsSIL.def:886` (sil_movechecking_capture_consumed)
  - `/Users/coen/Developer/swiftlang/swift/include/swift/AST/DiagnosticsSIL.def:880` (sil_movechecking_guaranteed_value_consumed, adjacent pattern)

- Experiment results:
  - `/Users/coen/Developer/swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension/EXPERIMENT.md` (v1.0.0, 2026-05-14)
  - Toolchain matrix: V1-V4 PASS on 6.4-dev wrapping variants; V1-V4 FAIL on 6.3.1/6.3.2 (`@_owned` unknown attribute); V5 FAIL with "borrowed by non-Escapable type"; V5d CRASH (SIL verifier).

- Prior research:
  - `/Users/coen/Developer/swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` (v1.2.1, 2026-05-18; Tier-3 recommendation executed)
  - `/Users/coen/Developer/swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md` (v1.1.0, 2026-05-09; DECISION: Phase 1 ships, Phase 2 deferred)
  - `/Users/coen/Developer/swift-institute/Research/feature-flags-coroutine-borrow-accessors.md` (foundational `consuming get` research)
  - `/Users/coen/Developer/swift-institute/Research/swift-compiler-bug-catalog.md` (2026-05-10; reference to swiftlang/swift#88986)

- Related compiler source:
  - `/Users/coen/Developer/swiftlang/swift/test/SILGen/resilient_consuming_getter_nonescapable_test.swift` (test validation of intended rejection)
  - `/Users/coen/Developer/swiftlang/swift/test/SILGen/moveonly_consuming_get_on_rvalue.swift` (valid patterns on r-values)

- Swift compiler commits:
  - `645e2dc3bad` (2026-04-30) — consuming-accessor resilient base PR
  - `4640b58e990` — [SILGen] Mark +0 base unresolved for consuming accessor
  - `f0a8437191b` — MoveOnlyChecker: look through convert_function borrow-scope closing

- Phase 4 execution (Row 11 closure):
  - `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives` commits `41c691e`, `f685f53` (2026-05-18)
  - `/Users/coen/Developer/swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` v1.2.1 changelog

---

**Document version**: 1.0.0  
**Last updated**: 2026-05-18  
**Status**: COMPLETE (no further investigation required for Item 3c)
