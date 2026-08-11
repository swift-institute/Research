# Byte vs UInt8: Compiler Affordance Audit

<!--
---
version: 1.0.0
last_updated: 2026-05-20
status: RECOMMENDATION
tier: 2
scope: swift-byte-primitives
applies_to: [swift-byte-primitives]
normative: false
depends_on:
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-primitives/swift-byte-primitives/Research/bsli-gap-inventory.md
---
-->

## Context

`Byte` (a `@frozen` struct wrapping `let underlying: UInt8`) is canonical
across the institute's L1 byte domain per
[`feedback-byte-canonical-minimize-uint8`](../../../) and the `byte-discipline`
skill's `[API-BYTE-006]`. Sites that semantically denote "one byte of data"
use `Byte`; `UInt8` is reserved for arithmetic and a small set of structural
boundaries (stdlib carrier-protocol participation, bit-cast, stdlib
literal-init lowering, and C interop boundaries).

A 2026-05-20 audit of the Swift compiler at `/Users/coen/Developer/swiftlang/swift`
catalogued every site where `UInt8` receives compiler-level special treatment
that other unsigned integer widths do not. Four affordances were identified
([§ Affordances](#affordances) below); the audit ([conversation transcript])
prompted this research note to evaluate, per-affordance, whether `Byte` loses
the affordance, what the practical cost is, and whether the institute's BSLI
corpus or known language constraints absorb the loss.

The investigation is retrospective rationale-documentation
([RES-016]) for an existing design — the canonical-Byte rule has shipped
([feedback-byte-canonical-minimize-uint8.md], 2026-05-20 W3-A correction).
This doc adds the compiler-source backing the rule did not previously cite.

## Question

Does `Byte` (the institute's typed byte primitive) lose any compiler-level
affordance compared to using `UInt8` directly, and if so, is the loss
material?

## Methodology

1. **Compiler-side grep**, on `/Users/coen/Developer/swiftlang/swift` at
   2026-05-20: enumerate every site where the type `UInt8` is named
   distinctly from other integer widths in `lib/Sema`, `lib/SIL*`,
   `lib/IRGen`, `lib/ClangImporter`, `lib/AST`, `include/swift/AST`, and
   the runtime/SwiftShims. Distinguish three classes:
   - **Generic enumeration**: `UInt8` is one of `{Int, UInt, Int8/16/32/64, UInt8/16/32/64}`.
   - **Byte-cohort**: `UInt8` paired with `Int8` (and sometimes `Void`).
   - **UInt8-only**: `UInt8` named without `Int8` or other widths.

2. **Per-affordance Byte analysis**: for each non-generic site, determine
   whether the affordance fires when the type is `Byte` instead of `UInt8`.
   Account for: structural compiler checks (`Type::isUInt8()` returns
   false for `Byte`), structural triviality (`Byte` is `@frozen`,
   single-field, trivial — same memory shape as `UInt8`), and explicit
   conversion (`.underlying` / `Byte(_:)`).

3. **Workaround inventory**: for each lost affordance, identify whether
   the institute's existing BSLI corpus
   ([`bsli-gap-inventory.md`](./bsli-gap-inventory.md)) or a known
   language constraint already absorbs or documents the cost.

Each empirical claim about a compiler site is tagged `[Verified: 2026-05-20]`
per [RES-013a] / [RES-023].

## Affordances

The compiler-side grep surfaced four sites where `UInt8` receives compiler
treatment that `UInt16/32/64`/`UInt` do not. Of the four, three pair
`UInt8` with `Int8` (the *byte-pointee* cohort); one is `UInt8`-only.

### Affordance 1 — String → pointer-to-byte conversion

**Site**: `swiftlang/swift/lib/Sema/CSSimplify.cpp:4422–4433`
`[Verified: 2026-05-20]`

```cpp
static bool isStringCompatiblePointerBaseType(ASTContext &ctx, Type baseType) {
  // Allow strings to be passed to pointer-to-byte or pointer-to-void types.
  if (baseType->isInt8())  return true;
  if (baseType->isUInt8()) return true;
  if (baseType->isVoid())  return true;
  return false;
}
```

The check fires when typechecking `String → UnsafePointer<T>` implicit
conversions. The function name and comment ("pointer-to-byte") encode the
compiler-internal vocabulary: `{Int8, UInt8, Void}` is *the byte-pointee
cohort*. Callers at lines 8246, 14728.

**Does Byte inherit?** No. `Type::isUInt8()` returns false for `Byte` (a
distinct nominal type). `let s = "x"; cFn(s)` where
`cFn: (UnsafePointer<UInt8>) -> Void` works via this affordance; the same
with `cFn: (UnsafePointer<Byte>) -> Void` does not.

**Practical cost**: This affordance is exercised when calling C functions
typed as `void f(uint8_t *)`. The Clang importer maps `uint8_t*` to
`UnsafeMutablePointer<UInt8>`, not `UnsafeMutablePointer<Byte>`, so the
C-signature side of the boundary is fixed to `UInt8` regardless of
caller-side preference. Callers therefore use `[UInt8]` /
`UnsafePointer<UInt8>` at the C-boundary anyway; the implicit-String
conversion lands exactly at the layer where `UInt8` is structurally
mandated. Byte-typed code passes through the BSLI bridges (e.g., Byte
sequence → `[UInt8]` via the Sequence `var underlying: [UInt8]` BSLI #4)
and uses `withCString` / `withUTF8` for direct String→pointer needs.

**Workaround**: `s.withCString { (cPtr: UnsafePointer<CChar>) in
cPtr.withMemoryRebound(to: Byte.self, capacity: n) { ... } }` if Byte
pointer is desired interior to a closure. The institute's UTF-8
bridging surface goes the other way: BSLI #6 (`String+Byte.swift`) provides
`String.init(decoding: Sequence<some Byte.Protocol>, as: UTF8.self)`.
The reverse direction (`String → some byte-typed pointer`) is rarely
the wanted shape — institute byte-domain APIs consume `Byte.Borrowed`
or `Sequence<some Byte.Protocol>`, not raw byte pointers.

**Verdict**: Lost, but at a boundary where `UInt8` is structurally
mandated anyway. No material design loss.

### Affordance 2 — C pointer interop defaulting

**Site**: `swiftlang/swift/lib/Sema/CSSimplify.cpp:15159–15189`
`[Verified: 2026-05-20]`

```cpp
// Unsafe[Mutable]Pointer<T> -> Unsafe[Mutable]Pointer<[U]Int8>
if (cPtr->isInt8() || cPtr->isUInt8()) {
  // <T> can default to the type of C pointer.
  addConstraint(ConstraintKind::Defaultable, swiftPtr, cPtr, elementLoc);
  return markSupported();
}
```

When a Swift `UnsafePointer<T>` is matched against a C pointer pointee
of `Int8` or `UInt8`, the constraint is `Defaultable`: `T` may default to
the C pointee. For wider widths (`Int16/UInt16/Int32/UInt32/...`), the
constraint is `Equal` (signed↔unsigned swap, lines 15183–15206), forcing
exact width agreement without defaulting.

**Does Byte inherit?** No. `Type::isUInt8()` returns false for `Byte`.
A Swift `UnsafePointer<T>` argument bound for a C `uint8_t*` parameter
will not default `T = Byte`.

**Practical cost**: This is a Swift type-inference convenience for C
interop; it does not gate compilation, only ergonomics. The C parameter
side is fixed at `UInt8` (via the importer); the question is whether the
Swift side's `T` defaults during constraint solving. Byte-typed code at
the C boundary explicitly states `UnsafePointer<UInt8>` (the C-side
type) and bridges to/from `Byte` via BSLI; the defaulting affordance
does not change shape at byte-typed call sites.

**Verdict**: Lost. Negligible — affects type-inference at C boundaries
where the institute pattern already names `UInt8` explicitly.

### Affordance 3 — Raw-pointer-equivalent SILGen diagnostic

**Site**: `swiftlang/swift/lib/SILGen/SILGenExpr.cpp:6892–6898`
`[Verified: 2026-05-20]`

```cpp
// The element type may contain a reference. Disallow conversion to a "raw"
// pointer type. Consider Int8/UInt8 to be raw pointers. Trivial element types
// are filtered out above, so Int8/UInt8 pointers can't match the source
// type. But the type checker may have allowed these for direct C calls, in
// which Int8/UInt8 are equivalent to raw pointers..
if (!(pointerElt->isVoid() || pointerElt->isInt8() || pointerElt->isUInt8()))
  return;
```

A diagnostic-emission filter for converting nontrivial Swift values to
"raw" pointer types. The filter treats `Int8/UInt8` pointers as raw-
pointer-equivalents.

**Does Byte inherit?** Structurally irrelevant. Byte is `@frozen`,
single-field over UInt8 — trivial. The diagnostic targets *nontrivial*
element types coerced to raw-pointer types ("Trivial element types are
filtered out above"). For Byte (trivial), the diagnostic never fires
in the first place. Same for UInt8.

**Verdict**: Not lost in practice. Affordance is for nontrivial
elements; Byte is trivial.

### Affordance 4 — @const / @DebugDescription `as` coercion

**Site**: `swiftlang/swift/lib/Sema/LegalLiteralExprVerifier.cpp:75–82`
`[Verified: 2026-05-20]`

```cpp
// Coerce expressions to UInt8 are allowed (to support @DebugDescription)
if (const CoerceExpr *coerceExpr = dyn_cast<CoerceExpr>(expr)) {
  auto coerceType = coerceExpr->getType();
  if (coerceType && coerceType->isUInt8()) {
    expressionsToCheck.push_back(coerceExpr->getSubExpr());
    continue;
  }
  return std::make_pair(expr, IllegalConstError::TypeNotSupported);
}
```

In the `@const` expression validator (gating which expressions are legal
inside `@DebugDescription` macros per SE-0492), the *only* allowed `as`
coercion is to `UInt8`. The comment names the motivating consumer
explicitly. This is the single site in the compiler where `UInt8` is
named without also naming `Int8` or other integer widths.

**Does Byte inherit?** No. `as Byte` will fail `isUInt8()` and be
rejected as `IllegalConstError::TypeNotSupported`.

**Practical cost**: `@DebugDescription` is a runtime LLDB-formatter
authoring macro. Bodies using `0xFF as UInt8` patterns are legal;
`0xFF as Byte` is not legal in the same body. The byte-discipline rule
classifies `@DebugDescription`-internal arithmetic as a UInt8-appropriate
site — bodies write `UInt8` directly because the macro's internal model
operates on stdlib integer values, not byte-domain semantics.

**Verdict**: Lost, but only at sites the byte-discipline rule already
classifies as UInt8-appropriate.

## Generic enumerations (UInt8 NOT special)

For completeness — sites where `UInt8` is named but receives identical
treatment to other integer widths, and therefore Byte's
non-participation is not a loss vs UInt8:

| Site | Role | Treatment |
|---|---|---|
| `include/swift/AST/KnownStdlibTypes.def` | Known stdlib type registry | `UInt8` is one of `Int/Int8/16/32/64/UInt/UInt8/16/32/64` `[Verified: 2026-05-20]` |
| `lib/AST/ASTContext.cpp:6688–6700` | `isTypeBridgedInExternalModule` | Flat enumeration of 10 integer types `[Verified: 2026-05-20]` |
| `lib/AST/Type.cpp:1315` | `isStdlibInteger()` | Disjunction across all 10 widths `[Verified: 2026-05-20]` |
| `lib/ClangImporter/ImportDecl.cpp:3083–3093` | retain/release return validation | 10-integer-type flat list `[Verified: 2026-05-20]` |
| `lib/Sema/CSOptimizer.cpp:199` | Constraint optimizer | Flat enumeration `[Verified: 2026-05-20]` |
| `lib/Sema/LiteralExpressionFolding.cpp:62–113` | Bitwidth lookup | Symmetric switch by width `[Verified: 2026-05-20]` |
| `lib/SILOptimizer/Mandatory/OSLogOptimization.cpp:233` | OSLog int handling | Flat enumeration `[Verified: 2026-05-20]` |
| `lib/SILOptimizer/Utils/ConstExpr.cpp:765–770` | ConstExpr evaluator | Flat enumeration `[Verified: 2026-05-20]` |
| `lib/IRGen/IRABIDetailsProvider.cpp:48–62` | LLVM int → Swift int | Symmetric width dispatch `[Verified: 2026-05-20]` |

Byte does not participate in these as a named alternative, but neither
does any other named struct — these tables register stdlib integer types
by identity, not by structural equivalence. Byte and UInt8 sit on the
same side of the line: the registry lists `UInt8` (and the other 9 stdlib
integers); Byte is a struct on top.

## Stdlib-level (NOT compiler) UInt8 keying

Distinct from compiler affordances, the stdlib has APIs whose signatures
are *fixed* to `UInt8` substrate. These are library design choices, not
compiler privileges — but they compose with the byte-typing decision
because Byte must bridge to them.

| Stdlib API | UInt8 substrate | BSLI bridge |
|---|---|---|
| `String.utf8` | `String.UTF8View` element is `UInt8` | none direct; UTF-8 view is read via `.underlying` mapping |
| `String.init(decoding:as:)` | `Sequence<UInt8>` source | BSLI #6 (`String+Byte.swift`) lifts to `Sequence<some Byte.Protocol>` |
| `String.withUTF8` | `UnsafeBufferPointer<UInt8>` closure parameter | none — caller wraps interior reads |
| `Unicode.Scalar.init(UInt8)` | `UInt8` source | BSLI lifts to `Unicode.Scalar.init(some Byte.Protocol)` (`String+Byte.swift:65–69`) |
| `Array<UInt8>(_: Sequence)` C-interop pattern | `Sequence<UInt8>` source | BSLI #3 (`Array+Byte.swift`) bridges both directions |
| `UnsafeMutableRawBufferPointer.copyBytes(from:)` | `Sequence<UInt8>` source | BSLI byte-typed overload (`UnsafeRawBufferPointer+Byte.swift`) |
| `Swift.Span<UInt8>` ↔ `Swift.Span<Byte>` | Span variance | **language-blocked** per [`bsli-gap-inventory.md`] |

The first six are absorbed by BSLI; the seventh is a known language-level
constraint (Span's `~Escapable` lifetime model precludes type-rebinding
across the function boundary; documented as load-bearing in
[`bsli-gap-inventory.md`](./bsli-gap-inventory.md) under "Blocked by
Swift-language constraints").

## Comparison

| Affordance | Type | Byte inherits? | Material loss | Workaround |
|---|---|---|---|---|
| 1. String → pointer-to-byte | `{Int8, UInt8}` cohort | No | No — boundary is structurally UInt8 anyway | BSLI Array bridge + `.withCString` |
| 2. C pointer defaulting | `{Int8, UInt8}` cohort | No | Negligible — type-inference convenience at C boundaries | Name `UInt8` explicitly (already the pattern) |
| 3. Raw-pointer-equivalent diagnostic | `{Int8, UInt8}` cohort | N/A — Byte is trivial; diagnostic targets nontrivial elements | None | None needed |
| 4. `@const` `as` coercion | `UInt8`-only | No | Confined to `@DebugDescription` macro bodies | Write `as UInt8` inside `@DebugDescription` (already correct per byte-discipline) |

## Constraints

The compiler-affordance analysis above is *separate from* the
language-level constraint on Span variance ([`bsli-gap-inventory.md`]).
That constraint — `Swift.Span<UInt8>` cannot be reinterpreted as
`Swift.Span<Byte>` across a function boundary — is the principal
substrate-level friction the byte-typing program lives with. It is not
a compiler affordance to UInt8; it is a structural property of
`~Escapable` lifetime modeling. The institute's resolution
(`Byte.Borrowed.span: Swift.Span<Byte>` per W2 cascade,
[`Byte.Borrowed.swift:63`](../Sources/Byte%20Primitives/Byte.Borrowed.swift),
with `Span<UInt8>` bridged by per-element wrapping at the boundary) is
the documented load-bearing compromise.

## Outcome

**Status**: RECOMMENDATION

**Verdict**: Byte loses **no material compiler affordance** compared to
UInt8. The compiler-level differences are concentrated in two narrow
classes:

1. The `{Int8, UInt8}` byte-pointee cohort at C-interop boundaries
   (affordances 1, 2, 3). These fire at exactly the layer where the
   institute's pattern already names `UInt8` (the C-side imported type),
   so Byte-typed code routes through `.underlying` / `[UInt8]` /
   `withCString` at the same boundary the cohort fires at. The boundary
   does not move; the friction does not accumulate net new ceremony
   beyond what the C-side fixed-`UInt8` mapping already imposes.

2. The `@const` / `@DebugDescription` `as UInt8` coercion (affordance
   4), confined to a Swift macro body context that byte-discipline
   already classifies as UInt8-appropriate.

The substantive substrate-level constraint (Span<UInt8>↔Span<Byte>
reinterpretation) is language-level, not compiler-affordance-level, and
is already documented as load-bearing in
[`bsli-gap-inventory.md`](./bsli-gap-inventory.md).

**Recommendation**: No design change to `Byte` or the byte-discipline
skill is warranted by this audit. The canonical-Byte rule
(`[API-BYTE-006]` per [feedback-byte-canonical-minimize-uint8]) holds
under compiler-affordance scrutiny. This document is the empirical
backing that rule did not previously cite.

**Implications for byte-discipline skill**: `[API-BYTE-007]` (UInt8
necessary at carrier axis, arithmetic, stdlib protocol requirements,
bit-cast, stdlib boundary types) should be read as also covering the
`{Int8, UInt8}` byte-pointee cohort affordances. The four C-boundary
sites in this audit are existing instances of "UInt8 necessary" — the
audit confirms the carve-out's existing boundary is well-drawn.

## References

### Primary sources

- Swift compiler at `/Users/coen/Developer/swiftlang/swift`,
  commit-state per 2026-05-20:
  - `lib/Sema/CSSimplify.cpp:4422–4433` (`isStringCompatiblePointerBaseType`)
  - `lib/Sema/CSSimplify.cpp:15159–15189` (C pointer defaulting)
  - `lib/SILGen/SILGenExpr.cpp:6892–6898` (raw-pointer diagnostic)
  - `lib/Sema/LegalLiteralExprVerifier.cpp:75–82` (`@const`/`@DebugDescription`)
  - `include/swift/AST/KnownStdlibTypes.def` (known type registry)
  - `lib/AST/ASTContext.cpp:6688–6700` (`isTypeBridgedInExternalModule`)
  - `include/swift/ClangImporter/BuiltinMappedTypes.def` (C-type mapping)
  - `stdlib/public/core/CTypes.swift:19` (`CChar`/`CUnsignedChar` typealiases)

### Internal prior art

- [`byte-protocol-capability-marker.md`](../../../swift-institute/Research/byte-protocol-capability-marker.md)
  v1.1.0 (Tier 3, RECOMMENDATION, 2026-05-15) — Q1=Option B: UInt8 does
  NOT conform to Byte.Protocol. Establishes the byte-vs-arithmetic twin
  separation that this audit's verdict relies on.
- [`bsli-gap-inventory.md`](./bsli-gap-inventory.md) (LANDED, 2026-05-19)
  — BSLI bridge corpus and the Span<UInt8>↔Span<Byte> language-block
  documentation.
- `byte-primitive-extraction-and-domain-naming.md`
  (DECISION, 2026-05-15) — Byte landed in swift-byte-primitives.

### Skill rules

- `byte-discipline` skill: `[API-BYTE-006]` (Byte canonical),
  `[API-BYTE-007]` (UInt8 carve-outs).
- [`feedback-byte-canonical-minimize-uint8`](../../../) memory entry
  (2026-05-20 W3-A correction).

### SE proposals

- SE-0492 (`@const` expressions, motivating `@DebugDescription` carve-out
  in `LegalLiteralExprVerifier.cpp`).
