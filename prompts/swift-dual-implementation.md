# Handoff: Implement `swift-dual` Package

## Objective

Create `/Users/coen/Developer/swift-foundations/swift-dual/` — a new Swift package providing the `@Dual` macro that computes the categorical dual of a type:

- **Struct → Enum**: product → coproduct (one case per stored property, literal field types)
- **Enum → Struct**: coproduct → product (Scott encoding: one handler closure per case, parameterized by result R)

This is a pure structural transformation from category theory. No defunctionalization, no DI patterns.

## Design Decisions (settled via Claude + ChatGPT collaborative discussion)

These decisions are final. Do not revisit them.

1. **`@Dual` computes the pure structural dual.** Closure-typed fields preserve their literal type: `var fetch: (Int) -> String` → `case fetch((Int) -> String)`. NO defunctionalization.
2. **Both directions.** Struct → enum AND enum → struct (Scott encoding with `match`).
3. **All stored properties included.** No closure/non-closure distinction. Every stored property becomes a case.
4. **Academic terminology.** `Dual` (category theory), `match` (PL case analysis), `Prism` (optics), `Case` (discriminant). Per [API-NAME-003].
5. **Enum infrastructure is cross-cutting.** Any generated enum gets: extraction properties, Case discriminant (Finite.Enumerable), Prisms, `is(_:)`, `subscript[prism:]`, `modify(_:_:)`.
6. **Homogeneous subscript.** When ALL stored properties share the same type, generate `subscript(case:)` on the source struct for property-as-value access.
7. **`@Dual` on other type kinds is an error.** Only structs and enums.

## Repository and Package Location

**New package**: `/Users/coen/Developer/swift-foundations/swift-dual/`

This is inside the `swift-foundations` superrepo (Layer 3).

## Package Structure

```
swift-dual/
├── Package.swift
├── Sources/
│   ├── Dual/
│   │   └── exports.swift
│   ├── Dual Macros/
│   │   └── Dual.swift
│   └── Dual Macros Implementation/
│       ├── Plugin.swift
│       ├── DualMacro.swift
│       ├── StructExpansion.swift
│       ├── EnumExpansion.swift
│       ├── PrismCodegen.swift
│       ├── CaseDiscriminantCodegen.swift
│       ├── ExtractionCodegen.swift
│       └── Utilities.swift
└── Tests/
    └── Dual Tests/
        ├── Test Fixtures.swift
        ├── Struct Dual Tests.swift
        └── Enum Dual Tests.swift
```

## Package.swift

Use this exact template (adapted from swift-witnesses):

```swift
// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-dual",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Dual",
            targets: ["Dual"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
        .package(path: "../../swift-primitives/swift-optic-primitives"),
        .package(path: "../../swift-primitives/swift-finite-primitives"),
    ],
    targets: [
        .target(
            name: "Dual",
            dependencies: [
                "Dual Macros",
            ]
        ),
        .target(
            name: "Dual Macros",
            dependencies: [
                "Dual Macros Implementation",
                .product(name: "Optic Primitives", package: "swift-optic-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        .macro(
            name: "Dual Macros Implementation",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Dual Tests",
            dependencies: [
                "Dual"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
```

---

## Source Files: `Dual Macros Implementation/`

### Plugin.swift

```swift
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DualMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        DualMacro.self,
    ]
}
```

### DualMacro.swift

Main dispatch. Implements `MemberMacro`, `MemberAttributeMacro`, and `ExtensionMacro`.

**MemberMacro**: Check if the declaration is a struct or enum. Dispatch to `expandStruct` or `expandEnum`. Otherwise emit diagnostic error.

**MemberAttributeMacro**: For public structs, add `@usableFromInline` to non-public stored properties (so `@inlinable` generated code can reference them). Skip properties with restricted access (package/private/fileprivate). Follow the exact pattern from swift-witnesses `WitnessMacro.swift` lines 217-273.

**ExtensionMacro**: For the enum direction only, generate `extension Route: Optic_Primitives.__OpticPrismAccessible {}`. For the struct direction, the conformance goes directly in the `enum Dual` declaration's inheritance clause.

Diagnostics enum:
```swift
enum DualDiagnostic: String, DiagnosticMessage {
    case requiresStructOrEnum
    case noStoredProperties
    case noEnumCases

    var message: String {
        switch self {
        case .requiresStructOrEnum:
            return "@Dual can only be applied to structs or enums"
        case .noStoredProperties:
            return "@Dual requires a struct containing at least one stored property"
        case .noEnumCases:
            return "@Dual requires an enum containing at least one case"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "DualMacro", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
```

### StructExpansion.swift (NEW — this is the novel code)

**Property extraction:**

```swift
struct StoredProperty {
    let name: String      // identifier text (without backticks)
    let type: String      // literal type annotation string
    let isVar: Bool       // var vs let
}
```

Function `extractAllStoredProperties(from structDecl: StructDeclSyntax) -> [StoredProperty]`:
- Walk `structDecl.memberBlock.members`
- Filter: `VariableDeclSyntax` with `var`/`let` binding specifier
- Filter: has `typeAnnotation` (type-annotated stored property)
- Filter: no `accessorBlock` (stored, not computed)
- Filter: not `static`
- Extract: identifier text, type annotation string, isVar flag
- Return ALL stored properties — no closure/non-closure distinction

**Generation** (`expandStruct` function):

Generate `enum Dual` nested inside the source struct containing:

1. **Case declarations**: One `case propertyName(PropertyType)` per stored property. Use `escapeIdentifier` on property names. Use literal type annotation strings.

2. **Extraction computed properties** inside Dual: For each case, generate an Optional computed property (via ExtractionCodegen). Single expression per [IMPL-EXPR-001]:
   ```swift
   var host: String? { if case .host(let v) = self { v } else { nil } }
   ```

3. **Case discriminant** inside Dual: `enum Case: Finite_Primitives.Finite.Enumerable, Sendable` (via CaseDiscriminantCodegen).

4. **`var case: Case`** inside Dual: Switch on self, return the discriminant.

5. **Prisms struct** inside Dual (via PrismCodegen): One `Optic_Primitives.Optic.Prism<Dual, ValueType>` property per case.

6. **`static var prisms: Prisms`** inside Dual.

7. **Prism accessors** inside Dual: `is(_:)`, `subscript[prism:]`, `modify(_:_:)`.

8. **Inheritance clause**: `enum Dual: Sendable, Optic_Primitives.__OpticPrismAccessible` when the source struct is Sendable. Just `enum Dual: Optic_Primitives.__OpticPrismAccessible` otherwise. Check `structDecl.inheritanceClause` for "Sendable".

9. **Homogeneous subscript** on the SOURCE struct (not inside Dual):
   - Only when `Set(properties.map(\.type)).count == 1`
   - Setter included only when ALL properties are `var`
   - Get-only if ANY property is `let`
   ```swift
   subscript(`case` c: Dual.Case) -> Bool? {
       get {
           switch c {
           case .`condition one`: self.`condition one`
           case .`condition two`: self.`condition two`
           }
       }
       set {
           switch c {
           case .`condition one`: self.`condition one` = newValue
           case .`condition two`: self.`condition two` = newValue
           }
       }
   }
   ```

### EnumExpansion.swift (adapted from existing)

This file handles the enum → struct direction AND the enum infrastructure (extraction, prisms, discriminant) that goes on the source enum.

**Reuse from swift-witnesses `EnumExpansion.swift`:**
- `struct EnumCase` (lines 20-28)
- `struct EnumCaseParameter` (lines 30-38)
- `func extractEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCase]` (lines 40-67)
- The extraction property generation from `generateEnumComputedProperty` (lines 213-269)
- The Prisms/Case/is/subscript/modify generation from `generateEnumPrismMembers` (lines 71-210)

**NEW: Scott encoding generation.**

Generate `struct Dual<R>` nested inside the source enum:

1. **Stored closure properties**: One per case.
   - Parameterless case `case home` → `var home: @Sendable () -> R`
   - Single-param case `case profile(id: Int)` → `var profile: @Sendable (_ id: Int) -> R`
   - Multi-param case `case transform(input: Int, scale: Double)` → `var transform: @Sendable (_ input: Int, _ scale: Double) -> R`
   - Closures are `@Sendable` when the source enum is `Sendable`

2. **Memberwise init**: Public, with `@escaping` on each closure parameter.

3. **No Sendable on Dual<R> itself**: The struct stores closures. If they're `@Sendable`, Swift will infer Sendable automatically. Don't force it.

**NEW: `match` function** on the source enum:

```swift
@inlinable
public func match<R>(_ dual: Dual<R>) -> R {
    switch self {
    case .home: dual.home()
    case .profile(let id): dual.profile(id)
    case .settings: dual.settings()
    }
}
```

Each case is a single expression. For multi-param cases:
```swift
case .transform(let input, let scale): dual.transform(input, scale)
```

**Enum infrastructure** on the source enum (NOT inside Dual<R>):
- Extraction properties
- Case discriminant (Finite.Enumerable)
- Prisms struct
- `is(_:)`, `subscript[prism:]`, `modify(_:_:)`

This is essentially what `generateEnumPrismMembers` already does in swift-witnesses, with the addition of Dual<R> and match.

### PrismCodegen.swift

Extract verbatim from swift-witnesses `EnumExpansion.swift` lines 284-346:

```swift
struct PrismCase {
    let caseName: String
    let rootTypeName: String
    let parameters: [(label: String?, type: String)]
}

func generatePrism(for prismCase: PrismCase) -> String {
    // ... exact code from EnumExpansion.swift lines 293-346 ...
}
```

This is completely generic — it takes a case name, root type name, and parameters, and produces an `Optic_Primitives.Optic.Prism` property. No changes needed.

### CaseDiscriminantCodegen.swift

Unified from two duplicated locations in swift-witnesses:
- `EnumExpansion.swift` lines 80-127 (for enum types)
- `WitnessMacro.swift` lines 959-997 (for Action enum)

Create a function:

```swift
func generateCaseDiscriminant(
    caseNames: [String],   // already escaped
    isPublic: Bool
) -> String
```

Produces:
```swift
public enum Case: Finite_Primitives.Finite.Enumerable, Sendable {
    case host, port, retry

    @inlinable
    public static var count: Cardinal_Primitives.Cardinal {
        Cardinal_Primitives.Cardinal(3)
    }

    @inlinable
    public var ordinal: Ordinal_Primitives.Ordinal {
        switch self {
        case .host: Ordinal_Primitives.Ordinal(0)
        case .port: Ordinal_Primitives.Ordinal(1)
        case .retry: Ordinal_Primitives.Ordinal(2)
        }
    }

    @inlinable
    public init(__unchecked: Void, ordinal: Ordinal_Primitives.Ordinal) {
        switch ordinal.rawValue {
        case 0: self = .host
        case 1: self = .port
        default: self = .retry
        }
    }
}
```

Use the same pattern as the existing code: last case uses `default:` in the init.

### ExtractionCodegen.swift

Refactored from `EnumExpansion.swift` lines 71-269. Provide standalone functions:

```swift
/// Generates a single extraction computed property for an enum case.
/// e.g., `var host: String? { if case .host(let v) = self { v } else { nil } }`
func generateExtractionProperty(
    caseName: String,
    parameters: [(label: String?, type: String)],
    isPublic: Bool
) -> DeclSyntax

/// Generates the `var case: Case` property.
func generateCaseProperty(
    caseNames: [String],
    isPublic: Bool
) -> DeclSyntax

/// Generates the Prisms struct containing one prism per case.
func generatePrismsStruct(
    cases: [(name: String, parameters: [(label: String?, type: String)])],
    rootTypeName: String,
    isPublic: Bool
) -> DeclSyntax

/// Generates: static var prisms, is(_:), subscript[prism:], modify(_:_:)
func generatePrismAccessors(
    rootTypeName: String,
    isPublic: Bool
) -> [DeclSyntax]
```

### Utilities.swift

Extract from swift-witnesses `EnumExpansion.swift` lines 350-360 and EXTEND for space-containing identifiers:

```swift
@_spi(RawSyntax) import SwiftSyntax

/// Escapes an identifier with backticks if it's a Swift keyword or contains spaces.
func escapeIdentifier(_ identifier: String) -> String {
    // Space-containing identifiers (Dutch legal text)
    if identifier.contains(" ") {
        return "`\(identifier)`"
    }
    // Swift keyword check
    let isKeyword = Array(identifier.utf8).withUnsafeBufferPointer { buffer in
        let text = SyntaxText(baseAddress: buffer.baseAddress, count: buffer.count)
        return Keyword(text) != nil
    }
    if isKeyword {
        return "`\(identifier)`"
    }
    return identifier
}
```

---

## Source Files: `Dual Macros/`

### Dual.swift

```swift
@_exported public import Optic_Primitives
@_exported public import Finite_Primitives

/// Computes the categorical dual of a type.
///
/// On a struct (product type), generates a nested `Dual` enum (coproduct)
/// with one case per stored property, preserving literal field types.
///
/// On an enum (coproduct), generates a nested `Dual<R>` struct (product)
/// with one handler closure per case (Scott encoding), plus a `match`
/// function for case analysis.
///
/// ```swift
/// @Dual struct Config: Sendable {
///     var host: String
///     var port: Int
/// }
/// // Config.Dual.host("localhost")
/// // Config.Dual.Case.allCases
///
/// @Dual enum Route: Sendable {
///     case home
///     case profile(id: Int)
/// }
/// // route.match(Route.Dual(home: { "Home" }, profile: { id in "Profile \(id)" }))
/// ```
@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(extension, conformances: Optic_Primitives.__OpticPrismAccessible, names: arbitrary)
public macro Dual() = #externalMacro(
    module: "Dual_Macros_Implementation",
    type: "DualMacro"
)
```

Note: `@attached(memberAttribute)` is needed for the `@usableFromInline` attribute injection on stored properties of public structs.

---

## Source Files: `Dual/`

### exports.swift

```swift
@_exported public import Dual_Macros
```

---

## Tests

### Test Fixtures.swift

```swift
import Testing
public import Dual

// MARK: - Struct Fixtures

/// Mixed types — no homogeneous subscript.
@Dual
struct Config: Sendable {
    var host: String
    var port: Int
}

/// Same type — homogeneous subscript generated.
@Dual
struct Homogeneous: Sendable {
    var x: Int
    var y: Int
    var z: Int
}

/// Bool? pattern (statute encoding use case) with space-containing identifiers.
@Dual
struct StatuteArgs: Sendable {
    var `condition one`: Bool? = nil
    var `condition two`: Bool? = nil
    var `condition three`: Bool? = nil
}

/// Single field.
@Dual
struct SingleField: Sendable {
    var value: String
}

/// Let-only — get-only subscript.
@Dual
struct LetOnly: Sendable {
    let x: Int
    let y: Int
}

/// Closure fields — pure structural dual preserves literal closure types.
@Dual
struct WithClosures: Sendable {
    var fetch: @Sendable (Int) -> String
    var count: Int
}

// MARK: - Enum Fixtures

@Dual
enum Route: Sendable {
    case home
    case profile(id: Int)
    case settings
}

@Dual
enum Action: Sendable {
    case load
    case save(path: String)
    case transform(input: Int, scale: Double)
}

@Dual
enum KeywordCases: Sendable {
    case `default`
    case `return`(value: String)
}
```

### Struct Dual Tests.swift

Test suite structure:
```swift
import Testing
@testable import Dual

@Suite("Struct Dual")
struct StructDualTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}
```

**Unit tests** — verify for Config:
- `Config.Dual.host("x").host == "x"`
- `Config.Dual.host("x").port == nil`
- `Config.Dual.port(80).port == 80`
- `Config.Dual.Case.host.ordinal.rawValue == 0`
- `Config.Dual.Case.port.ordinal.rawValue == 1`
- `Config.Dual.Case.count.rawValue == 2`
- `Config.Dual.host("x").case == .host`
- `Config.Dual.prisms.host.extract(.host("x")) == "x"`
- `Config.Dual.host("x").is(\.host) == true`
- `Config.Dual.host("x").is(\.port) == false`
- `Config.Dual.host("x")[prism: \.host] == "x"`
- Modify via prism: `var d = Config.Dual.host("old"); d.modify(\.host) { $0 = "new" }; #expect(d.host == "new")`

**Homogeneous subscript tests**:
- `var h = Homogeneous(x: 1, y: 2, z: 3)`
- `h[case: .x] == 1`
- `h[case: .y] == 2`
- `h[case: .x] = 10; #expect(h.x == 10)`

**StatuteArgs tests** (space-containing identifiers):
- `StatuteArgs.Dual.Case.allCases` or iterate via Finite.Enumerable
- `var args = StatuteArgs(); args[case: .`condition one`] = true; #expect(args.`condition one` == true)`

**LetOnly tests**:
- Subscript is get-only (verify reads work; compiler enforces no setter)

**WithClosures tests**:
- `WithClosures.Dual.fetch` case exists with literal closure type as associated value
- `WithClosures.Dual.count(42).count == 42`

### Enum Dual Tests.swift

```swift
import Testing
@testable import Dual

@Suite("Enum Dual")
struct EnumDualTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}
```

**Unit tests** — verify for Route:
- `Route.Dual<R>` struct has `home`, `profile`, `settings` properties
- Match dispatches correctly:
  ```swift
  let describe = Route.Dual<String>(
      home: { "Home" },
      profile: { id in "Profile \(id)" },
      settings: { "Settings" }
  )
  #expect(Route.home.match(describe) == "Home")
  #expect(Route.profile(id: 42).match(describe) == "Profile 42")
  #expect(Route.settings.match(describe) == "Settings")
  ```
- Extraction: `Route.home.home != nil`, `Route.home.profile == nil`
- Case discriminant: `Route.Case.home.ordinal.rawValue == 0`, count == 3
- Prisms on Route work
- `Route.home.is(\.home) == true`

**Action tests** (multi-param):
- `Action.transform(input: 1, scale: 2.0).transform` returns `(input: 1, scale: 2.0)` tuple
- Match with multi-param handler works

**KeywordCases tests**:
- Backtick-escaped cases compile and match
- `KeywordCases.default.`default` != nil`

---

## Key Implementation Notes

### Sendable detection

Check whether the source type declares Sendable:
```swift
let isSendable = declaration.inheritanceClause?.inheritedTypes.contains { inherited in
    inherited.type.trimmedDescription == "Sendable"
} ?? false
```

For struct direction: add `Sendable` to `enum Dual` inheritance clause when source is Sendable.
For enum direction: mark closures in `Dual<R>` as `@Sendable` when source is Sendable.

### Access level propagation

If source is `public`, generated members are `public` with `@inlinable`. If internal, generated members are internal. Follow the exact pattern from WitnessMacro.swift.

The `canInline` check from WitnessMacro.swift (line 674-681) should be replicated: if any stored property has restricted access (package/private/fileprivate), generated members cannot be `@inlinable`.

### MemberAttributeMacro for @usableFromInline

For public structs, non-public stored properties need `@usableFromInline` so that `@inlinable` generated code can reference them. Skip properties with restricted access. Follow WitnessMacro.swift lines 217-273 exactly. But only add the attribute — do NOT add deprecation attributes (those are @Witness-specific for closure method forwarding).

### Identifier escaping

The `escapeIdentifier` function MUST handle:
1. Swift keywords (`default`, `return`, `class`, etc.) → backtick wrap
2. Identifiers with spaces (Dutch legal text) → backtick wrap

The AST's `IdentifierPatternSyntax.identifier.text` returns the text WITHOUT backticks. So `var \`betreft het de Staat\`: Bool?` gives identifier text `"betreft het de Staat"`. The codegen must add backticks back.

### Fully qualified type references in generated code

All references to primitives types in generated code MUST be fully qualified:
- `Finite_Primitives.Finite.Enumerable`
- `Ordinal_Primitives.Ordinal`
- `Cardinal_Primitives.Cardinal`
- `Optic_Primitives.Optic.Prism`
- `Optic_Primitives.__OpticPrismAccessible`

This prevents name collisions with user types.

---

## Build and Test

```bash
cd /Users/coen/Developer/swift-foundations/swift-dual
swift build 2>&1 | tail -20
swift test 2>&1 | tail -30
```

All tests must pass. The macro must handle both struct and enum inputs correctly.

---

## Files to Read for Reference

Read these files to understand the existing patterns:

| File | Path | What to reference |
|------|------|-------------------|
| WitnessMacro.swift | `/Users/coen/Developer/swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift` | MemberMacro/MemberAttributeMacro/ExtensionMacro dispatch, property extraction, generateCaseEnum, diagnostics, canInline, access level handling |
| EnumExpansion.swift | `/Users/coen/Developer/swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/EnumExpansion.swift` | PrismCase, generatePrism, escapeIdentifier, EnumCase, extractEnumCases, generateEnumPrismMembers, generateEnumComputedProperty |
| Plugin.swift | `/Users/coen/Developer/swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/Plugin.swift` | CompilerPlugin entry point pattern |
| Witness.swift (macros) | `/Users/coen/Developer/swift-foundations/swift-witnesses/Sources/Witnesses Macros/Witness.swift` | @attached macro declaration pattern |
| Package.swift | `/Users/coen/Developer/swift-foundations/swift-witnesses/Package.swift` | Package.swift structure |
| Optic.Prism.swift | `/Users/coen/Developer/swift-primitives/swift-optic-primitives/Sources/Optic Primitives/Optic.Prism.swift` | Optic.Prism type, __OpticPrismAccessible protocol |
| Finite.Enumerable.swift | `/Users/coen/Developer/swift-primitives/swift-finite-primitives/Sources/Finite Primitives Core/Finite.Enumerable.swift` | Finite.Enumerable protocol |

---

## Summary

| What | Details |
|------|---------|
| **Package** | `/Users/coen/Developer/swift-foundations/swift-dual/` |
| **Macro** | `@Dual` — structural duality, both directions |
| **Struct → Enum** | `T.Dual` enum, literal types, extraction, Case, Prisms, homogeneous subscript |
| **Enum → Struct** | `T.Dual<R>` struct (Scott encoding), `match`, extraction, Case, Prisms |
| **Dependencies** | swift-syntax, swift-optic-primitives, swift-finite-primitives |
| **Build** | `cd swift-dual && swift build` |
| **Test** | `cd swift-dual && swift test` |
