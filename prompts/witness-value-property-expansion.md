# Handoff Prompt: Extend @Witness to Handle Non-Closure (Value) Properties

## Objective

Extend the `@Witness` macro in `swift-witnesses` so that when applied to a struct
with non-closure stored properties (e.g., `Bool?`, `Int`, `String`), it generates
the same structural dual as it does for enum cases: a `Case` enum with one case per
property, a subscript bridging Case → property access, and supporting infrastructure.

Currently, `@Witness` on a struct only expands closure properties. If the struct has
no closures, it emits a diagnostic error and returns empty. This change makes it also
handle value properties, producing the enum dual that enables treating properties as
first-class values (iterable, passable, serializable).

---

## Repository and Files

**Repository**: `https://github.com/swift-foundations/swift-witnesses`

**Files to modify**:
1. `https://github.com/swift-foundations/swift-witnesses/blob/main/Sources/Witnesses Macros Implementation/WitnessMacro.swift` — main macro implementation
2. `https://github.com/swift-foundations/swift-witnesses/blob/main/Sources/Witnesses Macros Implementation/EnumExpansion.swift` — may need shared utilities
3. `https://github.com/swift-foundations/swift-witnesses/blob/main/Tests/Witnesses Tests/Test Fixtures.swift` — add test fixtures
4. `https://github.com/swift-foundations/swift-witnesses/blob/main/Tests/Witnesses Tests/Witness.Enum Tests.swift` — or create new test file

**Files to read for context**:
- Any struct with `Bool?` (or other uniform-typed) stored properties benefits from this expansion — pick a representative fixture from the existing test suite.

**Build command**:
```bash
cd swift-witnesses && swift build 2>&1 | tail -10
```

**Test command**:
```bash
cd swift-witnesses && swift test 2>&1 | tail -20
```

---

## Current Behavior

### @Witness on struct (closure properties) — WORKS

```swift
@Witness
struct FileSystem: Sendable {
    var open: @Sendable (_ path: String) throws -> Int
    var read: @Sendable (_ fd: Int) throws -> [UInt8]
}
```

Generates:
1. Public init (if not present)
2. Convenience methods for labeled closures (`func open(path:)`, `func read(fd:)`)
3. `Action` enum: `enum Action { case open(path: String); case read(fd: Int) }`
4. `Observe` struct for wrapping/middleware
5. `unimplemented()` static method
6. `mock()` if `.mock` derive mode

### @Witness on struct (NO closure properties) — FAILS

```swift
@Witness
struct Arguments: Sendable {
    var `is the first condition satisfied`: Bool? = nil
    var `is the second condition satisfied`: Bool? = nil
    var `is the third condition satisfied`: Bool? = nil
}
```

Currently emits diagnostic: `WitnessDiagnostic.noClosureProperties` and returns `[]`.

### @Witness on enum — WORKS

```swift
@Witness
enum TestAction: Sendable {
    case load
    case save(path: String)
}
```

Generates:
1. Computed properties per case (`.load: Void?`, `.save: String?`)
2. `Case` enum (discriminant): `enum Case: Finite.Enumerable { case load; case save }`
3. `.case` computed property: `TestAction → Case`
4. `Prisms` struct with optic prisms per case
5. `is(_:)` method, `subscript[prism:]`, `modify(_:_:)` method

---

## Required Change

When `@Witness` is applied to a struct that has value (non-closure) properties,
it should generate a `Case` enum and subscript access — the same structural dual
that enum expansion produces, but in the struct→enum direction.

### What to generate for structs with value properties

Given:
```swift
@Witness
struct Arguments: Sendable {
    var `condition one`: Bool? = nil
    var `condition two`: Bool? = nil
    var `condition three`: Bool? = nil
    var `condition four`: Bool? = nil
    var `condition five with a longer descriptive phrase`: Bool? = nil
}
```

Generate:

**1. `Case` enum** — one case per value property, conforming to `CaseIterable` and `Sendable`:

```swift
public enum Case: CaseIterable, Sendable {
    case `condition one`
    case `condition two`
    case `condition three`
    case `condition four`
    case `condition five with a longer descriptive phrase`
}
```

Note: For the initial implementation, use `CaseIterable` instead of `Finite.Enumerable`
(which requires `Cardinal_Primitives` and `Ordinal_Primitives` imports). We can upgrade
to `Finite.Enumerable` later if needed. The enum expansion for enums uses `Finite.Enumerable`
because it's already in that ecosystem, but for value-property structs we want to keep it
simpler initially.

**2. Subscript** — bridging `Case` to property access:

```swift
public subscript(`case`: Case) -> Bool? {
    get {
        switch `case` {
        case .`condition one`: self.`condition one`
        case .`condition two`: self.`condition two`
        case .`condition three`: self.`condition three`
        case .`condition four`: self.`condition four`
        case .`condition five with a longer descriptive phrase`:
            self.`condition five with a longer descriptive phrase`
        }
    }
    set {
        switch `case` {
        case .`condition one`: self.`condition one` = newValue
        case .`condition two`: self.`condition two` = newValue
        case .`condition three`: self.`condition three` = newValue
        case .`condition four`: self.`condition four` = newValue
        case .`condition five with a longer descriptive phrase`:
            self.`condition five with a longer descriptive phrase` = newValue
        }
    }
}
```

**Important constraint for subscript**: The subscript only works when ALL value properties
share the same type (e.g., all `Bool?`). If properties have mixed types, do NOT generate
the subscript — the return type would be ambiguous. In that case, only generate the `Case`
enum.

To check: iterate the value properties. If they all have the same type annotation string,
generate the subscript with that type. Otherwise, skip the subscript.

---

## Implementation Guide

### Step 1: Extract value properties

In `WitnessMacro.swift`, add a function parallel to `extractClosureProperties`:

```swift
struct ValueProperty {
    let name: String        // property identifier
    let type: String        // type annotation string (e.g., "Bool?")
    let isVar: Bool         // var vs let
    let hasDefault: Bool    // has default value (e.g., "= nil")
}

func extractValueProperties(from structDecl: StructDeclSyntax) -> [ValueProperty] {
    // Iterate memberBlock.members
    // Find VariableDeclSyntax where:
    //   - binding has typeAnnotation
    //   - typeAnnotation is NOT a function type (FunctionTypeSyntax)
    //   - binding has no accessorBlock (stored, not computed)
    // Return ValueProperty for each
}
```

Use the existing `extractClosureProperties` as a template — it already filters for
function types. Value properties are the complement: everything that ISN'T a function type.

Note: The existing `extractNonClosureProperties` function already exists and extracts
non-closure stored properties. Check if it returns enough info or needs augmentation.
Read the function carefully — it may already have the `name` and `type` you need.

### Step 2: Modify expandStruct

Current flow (lines 101-193):
```
expandStruct:
  closureProperties = extractClosureProperties(structDecl)
  guard !closureProperties.isEmpty else { ERROR }
  ... generate closure-based members ...
```

New flow:
```
expandStruct:
  closureProperties = extractClosureProperties(structDecl)
  valueProperties = extractValueProperties(structDecl)

  // At least one of the two must be non-empty
  guard !closureProperties.isEmpty || !valueProperties.isEmpty else {
      diagnostic error
      return []
  }

  var members: [DeclSyntax] = []

  // Closure-based members (existing — only if closures exist)
  if !closureProperties.isEmpty {
      // ... existing init, methods, Action, Observe, unimplemented, mock ...
  }

  // Value-property members (NEW — only if value properties exist)
  if !valueProperties.isEmpty {
      members.append(generateCaseEnum(for: valueProperties, isPublic: isPublic))

      // Subscript only if all value properties share the same type
      let types = Set(valueProperties.map(\.type))
      if types.count == 1, let sharedType = types.first {
          members.append(generateCaseSubscript(
              for: valueProperties,
              sharedType: sharedType,
              isPublic: isPublic
          ))
      }
  }

  return members
```

### Step 3: Generate the Case enum

Create a new function:

```swift
private static func generateCaseEnum(
    for valueProperties: [ValueProperty],
    isPublic: Bool
) -> DeclSyntax {
    let accessLevel = isPublic ? "public " : ""
    let cases = valueProperties.map { prop in
        "case \(escapeIdentifier(prop.name))"
    }.joined(separator: "\n        ")

    return """
    \(raw: accessLevel)enum Case: CaseIterable, Sendable {
        \(raw: cases)
    }
    """
}
```

Use `escapeIdentifier` from `EnumExpansion.swift` — it handles Swift keyword escaping.
The backticked Dutch identifiers (e.g., `` `betreft het de Staat` ``) will need the
backticks preserved. Check how `escapeIdentifier` handles identifiers that already
contain backticks or spaces. The property name from the AST may already include backticks;
you need to verify this by inspecting what `IdentifierPatternSyntax.identifier.text`
returns for backticked identifiers. It likely returns the raw text WITHOUT backticks,
so you'll need to add them back for identifiers containing spaces.

### Step 4: Generate the subscript

```swift
private static func generateCaseSubscript(
    for valueProperties: [ValueProperty],
    sharedType: String,
    isPublic: Bool
) -> DeclSyntax {
    let accessLevel = isPublic ? "public " : ""

    let getCases = valueProperties.map { prop in
        let escaped = escapeIdentifier(prop.name)
        return "case .\(escaped): self.\(escaped)"
    }.joined(separator: "\n            ")

    let setCases = valueProperties.map { prop in
        let escaped = escapeIdentifier(prop.name)
        return "case .\(escaped): self.\(escaped) = newValue"
    }.joined(separator: "\n            ")

    return """
    \(raw: accessLevel)subscript(`case`: Case) -> \(raw: sharedType) {
        get {
            switch `case` {
            \(raw: getCases)
            }
        }
        set {
            switch `case` {
            \(raw: setCases)
            }
        }
    }
    """
}
```

Note: The setter requires `var` properties. If a value property is `let`, the setter
should NOT include it (or the subscript should be get-only if ANY property is `let`).
Check `isVar` on each ValueProperty.

### Step 5: Handle the mixed case (closures AND value properties)

When a struct has BOTH closure and value properties (like `DriverPatternAPI` which has
`let capabilities: Int` alongside closures), the existing expansion already handles
the closures. The new code should ALSO generate the Case enum for the value properties.

Currently, non-closure properties in closure-bearing structs are handled by
`extractNonClosureProperties` and included in the init/unimplemented/mock. The new
Case enum generation should coexist with this — it adds the enum, doesn't replace
anything.

Check: `DriverPatternAPI` in Test Fixtures has `let capabilities: Int`. After the change,
`@Witness` should generate a `Case` enum with `case capabilities` AND the existing
Action/Observe/unimplemented for the closures.

### Step 6: Update diagnostics

The current diagnostic `WitnessDiagnostic.noClosureProperties` should be replaced or
augmented:
- If struct has neither closures nor value properties → error
- If struct has only value properties → generate Case enum (no closures is OK now)
- If struct has only closures → existing behavior (no Case enum for closures; they get Action)

You may want to rename the diagnostic or add a new one. Check the diagnostics definition
(search for `WitnessDiagnostic` in the file) and update accordingly.

---

## Test Plan

### Test Fixture 1: Pure value property struct (all same type)

```swift
@Witness
struct PureValueStruct: Sendable {
    var name: String = ""
    var age: String = ""
    var city: String = ""
}
```

Verify:
- `Case` enum generated with 3 cases
- Subscript generated (all String)
- `PureValueStruct.Case.allCases.count == 3`
- `var s = PureValueStruct(); s[.name] = "test"; #expect(s.name == "test")`

### Test Fixture 2: Pure value property struct (Bool? — backticked identifiers)

```swift
@Witness
struct Questionnaire: Sendable {
    var `condition one`: Bool? = nil
    var `condition two`: Bool? = nil
    var `condition three`: Bool? = nil
}
```

Verify:
- `Case` enum generated with 3 backticked cases
- Subscript generated (all Bool?)
- `Questionnaire.Case.allCases.count == 3`
- `var args = Questionnaire(); args[.`condition one`] = true; #expect(args.`condition one` == true)`
- Iteration: `for c in Questionnaire.Case.allCases { ... }`

### Test Fixture 3: Mixed types (no subscript)

```swift
@Witness
struct MixedStruct: Sendable {
    var name: String = ""
    var count: Int = 0
    var active: Bool = false
}
```

Verify:
- `Case` enum generated with 3 cases
- NO subscript (types are mixed: String, Int, Bool)
- `MixedStruct.Case.allCases.count == 3`

### Test Fixture 4: Mixed closures + value properties

```swift
@Witness
struct MixedWitness: Sendable {
    let label: String
    var fetch: @Sendable (_ id: Int) throws -> String
}
```

Verify:
- Existing closure expansion still works (Action, methods, etc.)
- ALSO generates `Case` enum for value property: `enum Case { case label }`
- NO subscript if mixed types between value properties (only `label: String` here, so yes subscript)

### Test Fixture 5: Let vs var (subscript behavior)

```swift
@Witness
struct LetStruct: Sendable {
    let x: Int
    let y: Int
}
```

Verify:
- `Case` enum generated
- Subscript is GET-ONLY (no setter because `let`)

---

## Important Considerations

### Backticked identifiers

Some domains use backticked identifiers with spaces:
```swift
var `condition one`: Bool? = nil
```

The AST's `IdentifierPatternSyntax.identifier.text` returns `"condition one"`
(without backticks). When generating switch cases in the subscript, you need to add
backticks back if the identifier contains spaces or is a keyword. The existing
`escapeIdentifier` function only checks for Swift keywords. You may need to also check
for spaces:

```swift
func escapeIdentifier(_ identifier: String) -> String {
    if identifier.contains(" ") {
        return "`\(identifier)`"
    }
    // ... existing keyword check ...
}
```

Verify this by inspecting how the existing `extractClosureProperties` handles backticked
identifiers and what `identifier.text` returns for them.

### Coexistence with @Splat

The `@Witness` expansion on the `Arguments` struct must coexist with `@Splat` on the
outer struct. `@Splat` generates a convenience init on the OUTER struct. `@Witness`
generates the Case enum on the INNER Arguments struct. They operate on different types
and should not conflict.

The usage pattern:
```swift
@Splat
public struct `1`: Sendable {
    public let arguments: Arguments

    @Witness
    public struct Arguments: Sendable {
        public var `condition one`: Bool? = nil
        // ...
    }

    public init(_ arguments: Arguments) throws(Error) { ... }
}
```

### Do NOT generate DI infrastructure for value-only structs

When a struct has ONLY value properties (no closures):
- DO generate: `Case` enum, subscript
- Do NOT generate: `Action` enum, `Observe`, `unimplemented()`, `mock()`

These DI features make no sense for value structs. They're only relevant for
closure-bearing witness types.

### Do NOT change enum expansion

The enum expansion (`expandEnum`) is unaffected by this change. Only `expandStruct`
changes.

### Access level

Follow the same pattern as existing code:
- If struct is `public`, Case enum and subscript are `public`
- If struct has `@usableFromInline`, Case enum gets `@usableFromInline`
- Otherwise, internal

---

## Build and Test

After implementation:

```bash
# Build the macro
cd swift-witnesses && swift build

# Run all tests (existing + new)
cd swift-witnesses && swift test

# Verify existing tests still pass (no regressions)
# The DriverPatternAPI fixture has non-closure properties — verify it still works
# and now ALSO has a Case enum generated
```

All existing tests MUST continue to pass. The change is additive — it generates MORE
members for structs, never fewer.

---

## Summary of Changes

| File | Change |
|------|--------|
| `WitnessMacro.swift` | Add `extractValueProperties`, modify `expandStruct` to handle value properties, add `generateCaseEnum` and `generateCaseSubscript` |
| `EnumExpansion.swift` | Possibly extend `escapeIdentifier` for space-containing identifiers |
| `Test Fixtures.swift` | Add 5 test fixtures (pure value, Bool?, mixed types, mixed closures+values, let) |
| New or existing test file | Add tests for Case enum generation, subscript, iteration, backticked identifiers |
