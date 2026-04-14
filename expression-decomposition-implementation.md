# Expression Decomposition Implementation

<!--
---
version: 1.0.0
last_updated: 2026-03-01
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute's `#expect` and `#require` macros currently expand to simple boolean checks that lose operand values at evaluation time. When `#expect(a == b)` fails, the failure message is "Expectation failed" with no information about what `a` or `b` were. This was identified as the #1 usability gap in `comparative-swift-testing-frameworks.md` (Priority: HIGH).

Apple's swift-testing solves this with expression decomposition: the macro analyzes the syntax tree at compile time, decomposes the expression into its constituent parts, and generates code that captures operand values at runtime before evaluating the operator. On failure, it can report:

```
Expectation failed: (leftValue == rightValue)
  left:  42
  right: 17
```

The Institute must implement equivalent functionality while respecting its own conventions ([API-NAME-001], [API-ERR-001], [PRIM-FOUND-001]) and five-layer architecture.

### Trigger

Design question arose from comparative analysis. Cannot make a decision without systematic analysis of alternatives.

### Constraints

- No Foundation imports in primitives or standards [PRIM-FOUND-001]
- Typed throws required [API-ERR-001]
- Nest.Name pattern required [API-NAME-001]
- One type per file [API-IMPL-005]
- Five-layer architecture: primitives -> standards -> foundations (no upward/lateral)
- `Test.Expression` and `Test.Expression.Value` already exist in `swift-test-primitives` (Layer 1)
- `Test.Expectation` and `Test.Expectation.Failure` already exist in `swift-test-primitives` (Layer 1)
- Macro implementation lives in `swift-testing` (Layer 3 -- foundations)
- Runtime checking functions live in `swift-tests` (Layer 3 -- foundations)
- Current architecture: `ExpectMacro` -> `Testing.__expect()` -> `expect()` -> `Test.Expectation`

## Question

How should expression decomposition be implemented in the Institute's `#expect` and `#require` macros, and what changes are needed across the five-layer architecture?

## Prior Art

### Apple swift-testing Architecture

Apple's expression decomposition uses a three-part design:

**Part 1: Macro-level syntax analysis** (`ConditionArgumentParsing.swift`)
- The macro's `parseCondition()` analyzes the AST of the condition expression
- Recognizes: binary operators (`InfixOperatorExprSyntax`), `is`/`as?` casts, function calls (`FunctionCallExprSyntax`), member access (`MemberAccessExprSyntax`), negation (`!`), closures
- Falls back to opaque `__checkValue` for unrecognized patterns (try, await, unsafe)
- Each recognized pattern produces a `Condition` struct with: expanded function name, decomposed arguments, and an `__Expression` construction expression

**Part 2: Runtime `__check*` functions** (`ExpectationChecking+Macro.swift`)
- `__checkValue(_ condition: Bool, ...)` -- fallback, no decomposition
- `__checkBinaryOperation<T, U>(_ lhs: T, _ op: (T, () -> U) -> Bool, _ rhs: @autoclosure () -> U, ...)` -- captures both operands
- `__checkFunctionCall<T, each U>(_ lhs: T, calling: (T, repeat each U) throws -> Bool, _ arguments: repeat each U, ...)` -- captures receiver and arguments
- `__checkPropertyAccess<T>(_ lhs: T, getting: (T) -> Bool, ...)` -- captures receiver
- `__checkCast(_ lhs: some Any, is/as: some Any.Type, ...)` -- captures cast subject
- `__checkInoutFunctionCall<T, U>(_ lhs: T, calling: (T, inout U) throws -> Bool, ...)` -- captures inout calls
- Additional non-variadic overloads to work around compiler bugs
- All return `Result<Void, any Error>` (or `Result<R, any Error>` for optional-returning variants)
- `.__expected()` / `.__required()` adapter methods on `Result` finalize the expansion

**Part 3: `__Expression` type** (`Expression.swift`, `Expression+Macro.swift`)
- Tree structure with `sourceCode`, `runtimeValue`, and `subexpressions: [__Expression]`
- `runtimeValue` is `__Expression.Value` -- captures `description`, `debugDescription`, `typeInfo`, `children` via Mirror
- Static factory methods: `__fromSyntaxNode`, `__fromBinaryOperation`, `__fromFunctionCall`, `__fromPropertyAccess`, `__fromNegation`, `__fromStringLiteral`
- `capturingRuntimeValues(_ firstValue:, _ additionalValues:)` -- variadic parameter pack method that captures values into the subexpression tree
- Lazy evaluation: runtime values only captured when the expression is populated, and only fully reflected on failure

**Key Expansion Example:**

```swift
// Source:
#expect(a == b)

// Expands to:
Testing.__checkBinaryOperation(
    a,                                           // lhs captured as generic T
    { $0 == $1() },                              // operator as closure
    b,                                           // rhs captured as generic U (autoclosure)
    expression: .__fromBinaryOperation(
        .__fromSyntaxNode("a"),
        "==",
        .__fromSyntaxNode("b")
    ),
    comments: [],
    isRequired: false,
    sourceLocation: ...
).__expected()
```

On failure, `__checkBinaryOperation` calls `expression.capturingRuntimeValues(condition, lhs, rhs)` which populates the subexpression tree with the actual runtime values of `a` and `b`.

### Catch2 (C++)

Uses expression templates / operator overloading at the language level. A `REQUIRE(a == b)` expands to `DecomposerLHS(a) == b` where `DecomposerLHS` overloads comparison operators to capture both sides. This approach is language-specific and not applicable to Swift macros.

### Institute's Current Architecture

```
ExpectMacro.expansion() -->  Testing.__expect(condition, comment, fileID, filePath, line, column)
                                   |
                                   v
                        expect(condition, comment, fileID, filePath, line, column)
                                   |
                                   v
                        Test.Expectation(id, expression, isPassing, failure)
```

The condition is evaluated to `Bool` before `__expect` sees it. Operand values are lost.

The Institute already has infrastructure for capturing values:
- `Test.Expression.Value` has `label`, `stringValue`, `typeDescription`, `isNil`
- `Test.Expression` has a `values: [Value]` field
- `Test.Expectation.Failure` has `expected: Value?`, `actual: Value?`, `difference: Test.Text?`
- `expect(_ lhs:, equals rhs:)` already captures values (but only for the explicit `equals:` API, not via `#expect`)

## Analysis

### Option A: Mirror Apple's Full `__Expression` Tree Architecture

**Description**: Port Apple's `__Expression`-based tree architecture wholesale: `__fromBinaryOperation`, `__fromFunctionCall`, etc. Create a `Condition` parser in the macro that recognizes binary ops, function calls, property accesses. Implement `__checkBinaryOperation`, `__checkFunctionCall`, `__checkPropertyAccess`, `__checkCast` runtime functions.

**Advantages**:
- Maximum feature parity with Apple
- Handles all expression forms: binary ops, function calls, property access, negation, casts
- Well-tested design with years of production usage
- Cleanest failure messages for complex expressions

**Disadvantages**:
- Large implementation surface: ~8 `__check*` functions with variadic overloads, ~6 `__from*` factory methods, full `Condition` parser
- Apple's `__Expression` uses `Mirror` for runtime value reflection (would need to be avoided or adapted for primitives)
- Apple uses `Result<Void, any Error>` return convention with `.__expected()`/`.__required()` adapters -- conflicts with typed throws [API-ERR-001]
- Apple's `__Expression` uses double-underscore naming convention and global functions -- conflicts with [API-NAME-001]
- `__Expression.Value` uses `Mirror` and `TypeInfo` -- Foundation-adjacent patterns
- Requires parameter packs for variadic function call capture (compiler maturity concern)

**Convention Compliance**:
- [API-NAME-001]: Must rename `__Expression` -> namespace-compliant form (e.g., `Test.Expression.Captured` or reuse existing `Test.Expression`)
- [API-ERR-001]: Must replace `Result<Void, any Error>` with typed throws
- [PRIM-FOUND-001]: Must avoid `Mirror`-based reflection in primitives; `String(describing:)` is acceptable
- [API-IMPL-005]: Each `__check*` function in its own file

**Estimated Changes**: ~25 new files across 3 layers

---

### Option B: Operator-Specialized Overloads (No Macro Change)

**Description**: Add operator-overloaded versions of `expect` that accept two operands plus an operator: `expect(a, .equalTo, b)`, `expect(a, .lessThan, b)`. No macro changes needed; users call these directly.

**Advantages**:
- Zero macro complexity
- Type-safe operator selection
- Clear, explicit API

**Disadvantages**:
- Does NOT solve the `#expect(a == b)` problem -- users must change their call sites
- Worse ergonomics than `#expect(a == b)`
- Does not match Apple's API surface at all
- Already partially exists as `expect(_ lhs:, equals rhs:)` -- extending this pattern means N overloads per operator

**Convention Compliance**: Fully compliant but does not address the core requirement.

**Verdict**: **Rejected** -- does not solve the stated problem (macro-level decomposition).

---

### Option C: Macro-Level Decomposition with Minimal Runtime

**Description**: The macro recognizes binary operations and decomposes them into separate argument captures, but uses the existing `expect`/`require` infrastructure with `Test.Expression.Value` arrays. No tree structure; just flat value capture.

For `#expect(a == b)`:
```swift
Testing.__checkBinaryOperation(
    { $0 == $1 },    // operator closure
    a,                // lhs value
    b,                // rhs value
    "a",              // lhs source
    "==",             // operator source
    "b",              // rhs source
    comment,
    sourceLocation: ...
)
```

The runtime function evaluates the operator, and on failure builds a `Test.Expectation` with populated `Test.Expression.Value` entries for both operands and `Test.Expectation.Failure` with `expected`/`actual`.

For unrecognized patterns, fall back to current `__expect(condition, ...)`.

**Advantages**:
- Smallest implementation surface
- Reuses existing `Test.Expression.Value` and `Test.Expectation.Failure` types
- No new types needed in primitives
- Solves the 80/20 case: binary operators cover `==`, `!=`, `<`, `>`, `<=`, `>=`
- Clean typed-throws compliance

**Disadvantages**:
- No function call or property access decomposition
- No tree structure -- cannot represent `!(a.foo() == b.bar())` with full subexpression capture
- Less extensible than Option A
- Flat value array does not capture structural relationships between subexpressions

**Convention Compliance**: Fully compliant with all conventions.

**Estimated Changes**: ~8 new/modified files across 2 layers

---

### Option D: Hybrid -- Phased Implementation

**Description**: Implement expression decomposition in two phases:

**Phase 1** (Option C core): Binary operator decomposition only. The macro recognizes `InfixOperatorExprSyntax` with `BinaryOperatorExprSyntax` and decomposes into lhs/rhs capture. Uses existing `Test.Expression` with populated `values` field. Covers `==`, `!=`, `<`, `>`, `<=`, `>=`, `===`, `!==`. Falls back to current `__expect` for everything else. No new primitives types needed.

**Phase 2** (Option A extensions): Add function call, property access, negation, and cast decomposition. Extend `Test.Expression` with optional subexpression tree support (additive, non-breaking). Add `__checkFunctionCall`, `__checkPropertyAccess`, etc.

**Advantages**:
- Immediate value: Phase 1 covers the most common failure case (comparison assertions)
- Incremental: Phase 2 can be deferred without blocking
- Lower risk: smallest possible change for maximum user impact
- Existing types are sufficient for Phase 1
- Phase 2 can learn from Phase 1 deployment experience
- Convention-compliant throughout

**Disadvantages**:
- Phase 1 does not handle `#expect(array.isEmpty)`, `#expect(x is Foo)`, etc.
- Two-phase approach means the API surface changes over time
- Phase 2 will eventually require primitives-layer changes (subexpression tree)

**Convention Compliance**: Fully compliant with all conventions in both phases.

**Estimated Changes**: Phase 1: ~8 files. Phase 2: ~15 additional files.

---

### Comparison

| Criterion | Option A (Full Mirror) | Option B (Overloads) | Option C (Minimal) | Option D (Hybrid) |
|-----------|----------------------|---------------------|-------------------|------------------|
| Solves `#expect(a == b)` | Yes | No | Yes | Yes |
| Solves `#expect(x.isEmpty)` | Yes | No | No | Phase 2 |
| Solves `#expect(x is Foo)` | Yes | No | No | Phase 2 |
| Implementation size (Phase 1) | ~25 files | ~5 files | ~8 files | ~8 files |
| Convention compliance | Requires adaptation | Full | Full | Full |
| Risk | Moderate (parameter packs, tree structure) | None | Low | Low |
| Reuses existing types | Partially | Yes | Yes | Yes |
| User impact (immediate) | Maximum | Minimal | High | High |
| Extensibility | Maximum | Limited | Limited | Maximum |
| Typed throws [API-ERR-001] | Requires redesign | N/A | Natural | Natural |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option D (Hybrid -- Phased Implementation)

**Rationale**: Phase 1 of Option D delivers the highest-impact improvement (binary operator decomposition for `#expect(a == b)` failure diagnostics) with the smallest possible change set and zero new primitives types. It reuses the existing `Test.Expression.Value`, `Test.Expectation.Failure`, and `Test.Expression` types. Phase 2 extends this to function calls, property access, and casts when needed.

Apple's architecture is instructive but cannot be ported directly -- their `Result<Void, any Error>` return convention, `Mirror`-based value reflection, double-underscore global functions, and untyped error handling all conflict with Institute conventions. The hybrid approach takes the core insight (macro-level syntax analysis + runtime value capture) while preserving the Institute's design principles.

---

## Implementation Plan: Phase 1

### Layer 1: Primitives (`swift-test-primitives`) -- No Changes Required

The existing types are sufficient:

- `Test.Expression` -- has `sourceCode: String` and `values: [Value]`
- `Test.Expression.Value` -- has `label: String?`, `stringValue: String`, `typeDescription: String`, `isNil: Bool`, and `init(capturing:label:)`
- `Test.Expectation.Failure` -- has `expected: Value?`, `actual: Value?`, `difference: Test.Text?`

The `values` array on `Test.Expression` can hold the captured lhs and rhs. The `Failure` type already has `expected`/`actual` slots.

### Layer 3: Foundations (`swift-tests`) -- New Runtime Functions

**File: `Test.check.swift`** (new)

Path: `https://github.com/swift-foundations/swift-tests/blob/main/Sources/Tests Core/Test.check.swift`

```swift
/// Checks a binary operation and captures operand values on failure.
///
/// - Parameters:
///   - lhs: The left-hand operand.
///   - op: A closure that evaluates the binary operation.
///   - rhs: The right-hand operand.
///   - lhsSource: Source code of the left-hand expression.
///   - opSource: Source code of the operator.
///   - rhsSource: Source code of the right-hand expression.
///   - comment: Optional user comment.
///   - fileID: Source file ID.
///   - filePath: Source file path.
///   - line: Source line.
///   - column: Source column.
/// - Returns: The evaluated expectation.
@discardableResult
public func __checkBinaryOperation<L, R>(
    _ lhs: L,
    _ op: (L, R) -> Bool,
    _ rhs: R,
    lhsSource: String,
    opSource: String,
    rhsSource: String,
    _ comment: Test.Text? = nil,
    fileID: String,
    filePath: String,
    line: Int,
    column: Int
) -> Test.Expectation
```

Implementation: evaluates `op(lhs, rhs)`. On failure, constructs `Test.Expression` with `values` populated from both operands, and `Test.Expectation.Failure` with `expected`/`actual` filled in.

**File: `Test.check.require.swift`** (new)

Path: `https://github.com/swift-foundations/swift-tests/blob/main/Sources/Tests Core/Test.check.require.swift`

```swift
/// Checks a binary operation and throws on failure, capturing operand values.
///
/// Throwing variant of __checkBinaryOperation for #require expansions.
public func __requireBinaryOperation<L, R>(
    _ lhs: L,
    _ op: (L, R) -> Bool,
    _ rhs: R,
    lhsSource: String,
    opSource: String,
    rhsSource: String,
    _ comment: Test.Text? = nil,
    fileID: String,
    filePath: String,
    line: Int,
    column: Int
) throws(Test.Requirement.Failed)
```

**Design Notes**:
- Uses typed throws `throws(Test.Requirement.Failed)` per [API-ERR-001]
- Separate `expect` and `require` variants (not `Result`-based) to match existing Institute pattern
- `String(describing:)` for value capture, not `Mirror` (no Foundation dependency)
- Returns `Test.Expectation` from expect variant (matches existing `expect()` return type)

### Layer 3: Foundations (`swift-testing`) -- Macro Changes

**File: `ExpectMacro.swift`** (modify)

Path: `https://github.com/swift-foundations/swift-testing/blob/main/Sources/Testing Macros Implementation/ExpectMacro.swift`

Changes:
1. Add AST analysis to detect `InfixOperatorExprSyntax` with `BinaryOperatorExprSyntax`
2. When detected, expand to `Testing.__checkBinaryOperation(lhs, { $0 OP $1 }, rhs, lhsSource:, opSource:, rhsSource:, ...)`
3. When not detected, fall back to existing `Testing.__expect(condition, ...)` expansion

```swift
public struct ExpectMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let firstArg = node.arguments.first?.expression else {
            throw ExpectMacroError.missingCondition
        }

        let comment: String = /* existing comment extraction */

        // Attempt to decompose binary operations
        if let infixOp = firstArg.as(InfixOperatorExprSyntax.self),
           let op = infixOp.operator.as(BinaryOperatorExprSyntax.self) {
            let lhs = infixOp.leftOperand
            let rhs = infixOp.rightOperand
            let opText = op.trimmedDescription

            return """
                Testing.__checkBinaryOperation(
                    \(lhs),
                    { $0 \(raw: opText) $1 },
                    \(rhs),
                    lhsSource: \(literal: lhs.trimmedDescription),
                    opSource: \(literal: opText),
                    rhsSource: \(literal: rhs.trimmedDescription),
                    \(raw: comment),
                    fileID: #fileID,
                    filePath: #filePath,
                    line: #line,
                    column: #column
                )
                """
        }

        // Fallback: existing boolean expansion
        return """
            Testing.__expect(
                \(firstArg),
                \(raw: comment),
                fileID: #fileID,
                filePath: #filePath,
                line: #line,
                column: #column
            )
            """
    }
}
```

**File: `RequireMacro.swift`** (modify)

Path: `https://github.com/swift-foundations/swift-testing/blob/main/Sources/Testing Macros Implementation/RequireMacro.swift`

Parallel changes: detect binary operations and expand to `Testing.__requireBinaryOperation(...)`.

**File: `Testing.Helpers.swift`** (modify)

Path: `https://github.com/swift-foundations/swift-testing/blob/main/Sources/Testing/Testing.Helpers.swift`

Add forwarding helpers:

```swift
extension Testing {
    @inlinable
    @discardableResult
    public static func __checkBinaryOperation<L, R>(
        _ lhs: L,
        _ op: (L, R) -> Bool,
        _ rhs: R,
        lhsSource: String,
        opSource: String,
        rhsSource: String,
        _ comment: Test.Text? = nil,
        fileID: String,
        filePath: String,
        line: Int,
        column: Int
    ) -> Test.Expectation {
        Tests.__checkBinaryOperation(
            lhs, op, rhs,
            lhsSource: lhsSource,
            opSource: opSource,
            rhsSource: rhsSource,
            comment,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    @inlinable
    public static func __requireBinaryOperation<L, R>(
        _ lhs: L,
        _ op: (L, R) -> Bool,
        _ rhs: R,
        lhsSource: String,
        opSource: String,
        rhsSource: String,
        _ comment: Test.Text? = nil,
        fileID: String,
        filePath: String,
        line: Int,
        column: Int
    ) throws(Test.Requirement.Failed) {
        try Tests.__requireBinaryOperation(
            lhs, op, rhs,
            lhsSource: lhsSource,
            opSource: opSource,
            rhsSource: rhsSource,
            comment,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}
```

### Failure Message Format

Phase 1 failure output for `#expect(count == 5)` where `count` is 3:

```
Expectation failed: count == 5
  left:  3 (Int)
  right: 5 (Int)
```

This is produced by the console reporter reading `Test.Expectation.Failure.expected` and `.actual`.

### Effect Keyword Handling

Following Apple's lead, the macro MUST NOT decompose expressions containing `try`, `await`, or `unsafe` keywords. These expressions fall back to the existing boolean expansion. This is because:
- `try` inside a decomposed closure would change error handling semantics
- `await` inside a decomposed closure would change concurrency context
- `unsafe` must not be silently dropped

Detection: check `firstArg.tokens(viewMode: .sourceAccurate)` for `try`/`await`/`unsafe` keyword tokens before attempting decomposition.

### Summary of File Changes (Phase 1)

| File | Layer | Action | Description |
|------|-------|--------|-------------|
| `Test.check.swift` | L3 (swift-tests) | New | `__checkBinaryOperation` expect variant |
| `Test.check.require.swift` | L3 (swift-tests) | New | `__requireBinaryOperation` require variant |
| `ExpectMacro.swift` | L3 (swift-testing) | Modify | Add binary operation decomposition |
| `RequireMacro.swift` | L3 (swift-testing) | Modify | Add binary operation decomposition |
| `Testing.Helpers.swift` | L3 (swift-testing) | Modify | Add `__checkBinaryOperation` / `__requireBinaryOperation` forwarding |
| Reporter files | L3 (swift-testing) | Modify | Format `expected`/`actual` from `Failure` in console output |

**No changes to Layer 1 (primitives).** All needed types already exist.

---

## Implementation Plan: Phase 2 (Future)

Phase 2 extends decomposition to additional expression forms. This is additive and non-breaking.

### New Expression Forms

| Form | Example | Runtime Function |
|------|---------|-----------------|
| Property access | `#expect(array.isEmpty)` | `__checkPropertyAccess` |
| Function call | `#expect(str.hasPrefix("x"))` | `__checkFunctionCall` |
| Type cast (`is`) | `#expect(x is Foo)` | `__checkCast` |
| Optional cast (`as?`) | `#require(x as? Foo)` | `__checkCast` |
| Negation (`!`) | `#expect(!value)` | Wraps inner decomposition |

### Primitives Changes (Phase 2 Only)

Add optional subexpression tree to `Test.Expression`:

**File: `Test.Expression.Subexpression.swift`** (new)

```swift
extension Test.Expression {
    /// A child expression within a decomposed expression tree.
    public struct Subexpression: Sendable, Hashable, Codable {
        /// The source code of this subexpression.
        public let sourceCode: String
        /// The captured runtime value, if any.
        public let value: Value?
        /// The role of this subexpression (e.g., "left", "right", "receiver").
        public let role: String
    }
}
```

Extend `Test.Expression` with:
```swift
/// Decomposed subexpressions, if the expression was analyzed.
public let subexpressions: [Subexpression]
```

This is an additive change. Existing callers that pass `values: []` continue to work. The new `subexpressions` field provides structured decomposition for Phase 2 expression forms.

### Macro Changes (Phase 2)

Extract a `ConditionParser` utility type that mirrors Apple's `ConditionArgumentParsing.swift`:

```swift
struct ParsedCondition {
    let expandedFunctionName: String
    let arguments: [/* macro argument representations */]
    let sourceCodeExpression: ExprSyntax
}
```

This would analyze `InfixOperatorExprSyntax`, `FunctionCallExprSyntax`, `MemberAccessExprSyntax`, `IsExprSyntax`, `AsExprSyntax`, `PrefixOperatorExprSyntax` (negation), and `ClosureExprSyntax`.

---

## Design Decisions

### D1: Separate expect/require vs Result-based

**Decision**: Use separate `__checkBinaryOperation` (returns `Test.Expectation`) and `__requireBinaryOperation` (throws `Test.Requirement.Failed`) rather than Apple's `Result<Void, any Error>` + `.__expected()`/`.__required()` pattern.

**Rationale**: The Institute uses typed throws [API-ERR-001]. Apple's `Result<Void, any Error>` pattern erases the error type to `any Error`, which is forbidden. Separate functions provide typed throws naturally and match the existing `expect()`/`require()` split.

### D2: String-based value capture vs Mirror reflection

**Decision**: Use `String(describing:)` for value capture (already done by `Test.Expression.Value.init(capturing:label:)`), not `Mirror`-based reflection.

**Rationale**: [PRIM-FOUND-001] forbids Foundation in primitives. `Mirror` is stdlib (not Foundation), but the deep reflection tree Apple builds (with `children`, `isCollection`, `TypeInfo`) pulls in Foundation-adjacent patterns. The existing `Test.Expression.Value` with `stringValue` and `typeDescription` is sufficient for Phase 1 diagnostics.

### D3: Operator closure signature

**Decision**: Use `(L, R) -> Bool` for the operator closure, not Apple's `(T, () -> U) -> Bool` autoclosure pattern.

**Rationale**: Apple wraps the rhs in `() -> U` to support short-circuit evaluation (e.g., `&&`, `||`). For Phase 1, we only decompose comparison operators which always evaluate both sides. If Phase 2 needs short-circuit support, the autoclosure pattern can be added as a separate overload. Simpler signature reduces type-checking complexity.

### D4: Flat values vs tree structure

**Decision**: Phase 1 uses the existing flat `values: [Value]` array on `Test.Expression`. Phase 2 introduces structured `subexpressions` for tree decomposition.

**Rationale**: The flat array is sufficient for binary operations (left, right). A tree structure adds complexity that is only justified when function calls and nested expressions need representation.

### D5: Namespace for runtime functions

**Decision**: Runtime functions are prefixed with `__` (double underscore) to indicate macro-implementation-detail status, placed as free functions in the Tests module, and forwarded through `Testing` namespace for macro expansion.

**Rationale**: This matches the existing pattern (`Testing.__expect`, `Testing.__require`). The double underscore convention, while not ideal by [API-NAME-001], is justified for macro-generated code that users never call directly -- consistent with Apple's convention and the existing Institute codebase.

---

## Open Questions

1. **Short-circuit operators**: Should `#expect(a && b)` decompose `a` and `b` separately? Apple handles this via the `() -> U` autoclosure pattern. Phase 1 does not address this -- the expression falls back to boolean check.

2. **Optional comparisons**: Should `#expect(optionalValue == 42)` handle the optional case specially? Apple's generic `<T, U>` signature handles this naturally. The Institute's typed version should also work generically.

3. **Custom operators**: Should user-defined operators like `=~` be decomposed? Apple decomposes all `InfixOperatorExprSyntax` regardless of operator. Phase 1 should follow suit.

4. **Reporter formatting**: The console reporter needs updates to display `expected`/`actual` from `Test.Expectation.Failure`. This is a presentation concern, not an architectural one.

5. **Macro test coverage**: Apple has extensive macro expansion tests in `ConditionMacroTests.swift`. The Institute should add equivalent tests verifying the expanded form of `#expect(a == b)` vs `#expect(boolExpr)`.

## References

- Apple swift-testing source: `https://github.com/swiftlang/swift-testing`
  - `Sources/TestingMacros/ConditionMacro.swift` -- macro protocol and expansion
  - `Sources/TestingMacros/Support/ConditionArgumentParsing.swift` -- expression analysis
  - `Sources/TestingMacros/Support/SourceCodeCapturing.swift` -- `__Expression` construction
  - `Sources/Testing/Expectations/ExpectationChecking+Macro.swift` -- `__check*` functions
  - `Sources/Testing/SourceAttribution/Expression.swift` -- `__Expression` type
  - `Sources/Testing/SourceAttribution/Expression+Macro.swift` -- `__from*` factory methods
- Institute sources:
  - `swift-testing/Sources/Testing Macros Implementation/ExpectMacro.swift` -- current macro
  - `swift-testing/Sources/Testing/Testing.Helpers.swift` -- `__expect`/`__require` helpers
  - `swift-tests/Sources/Tests Core/Test.expect.swift` -- runtime `expect()` function
  - `swift-tests/Sources/Tests Core/Test.require.swift` -- runtime `require()` function
  - `swift-test-primitives/Sources/Test Primitives Core/Test.Expression.swift` -- expression type
  - `swift-test-primitives/Sources/Test Primitives Core/Test.Expression.Value.swift` -- value capture
  - `swift-test-primitives/Sources/Test Primitives Core/Test.Expectation.swift` -- expectation type
  - `swift-test-primitives/Sources/Test Primitives Core/Test.Expectation.Failure.swift` -- failure details
- Comparative analysis: `swift-institute/Research/comparative-swift-testing-frameworks.md`
