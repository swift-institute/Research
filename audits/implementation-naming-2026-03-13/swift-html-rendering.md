# swift-html-rendering Audit: Implementation + Naming

Date: 2026-03-13

## Summary
- Total files audited: 324 (across 4 modules: HTML Renderable, HTML Rendering, HTML Elements Rendering, HTML Attributes Rendering)
- Total violations found: 37
- Critical (naming/compound types): 26
- Implementation style: 11

## Violations

### [API-NAME-002] Compound property names on HTML.Tag static members
- **File**: `Sources/HTML Renderable/HTML.Tag.swift:85-141`
- **Issue**: `headOpen`, `headClose`, `bodyOpen`, `bodyClose`, `styleOpen`, `styleClose` are compound property names. Should use nested accessors.
- **Current**: `HTML.Tag.headOpen`, `HTML.Tag.headClose`, `HTML.Tag.bodyOpen`, `HTML.Tag.bodyClose`, `HTML.Tag.styleOpen`, `HTML.Tag.styleClose`
- **Expected**: `HTML.Tag.head.open`, `HTML.Tag.head.close`, `HTML.Tag.body.open`, `HTML.Tag.body.close`, `HTML.Tag.style.open`, `HTML.Tag.style.close` (requires a nested namespace type per tag)

### [API-NAME-002] Compound property name `doubleQuotationMark`
- **File**: `Sources/HTML Renderable/HTML.swift:12`
- **Issue**: `doubleQuotationMark` is a compound identifier.
- **Current**: `HTML.doubleQuotationMark`
- **Expected**: Nested accessor, e.g. `HTML.entity.doubleQuotation` or `HTML.entity.quot`

### [API-NAME-002] Compound property name `propertyName` on HTML.Element.Style
- **File**: `Sources/HTML Renderable/HTML.Style.swift:87`
- **Issue**: `propertyName` is a compound identifier. The property extracts the CSS property name from the declaration string.
- **Current**: `style.propertyName`
- **Expected**: Nested accessor pattern, e.g. `style.property.name`

### [API-NAME-002] Compound method names on HTML.DocumentProtocol
- **File**: `Sources/HTML Renderable/HTML.Document.Protocol.swift:124-132`
- **Issue**: `asyncDocumentBytes` and `asyncDocumentString` are compound method names.
- **Current**: `document.asyncDocumentBytes(...)`, `document.asyncDocumentString(...)`
- **Expected**: Nested accessor pattern, e.g. `document.async.bytes(...)`, `document.async.string(...)`

### [API-NAME-002] Compound method name `pushStyle`
- **File**: `Sources/HTML Renderable/HTML.Context.swift:537`
- **Issue**: `pushStyle` is a compound method name.
- **Current**: `context.pushStyle(style)`
- **Expected**: `context.push.style(style)` (note: `context.push.style()` already exists for the no-arg variant in the Rendering.Context protocol, so this should align)

### [API-NAME-002] Compound method name `writeOpeningTag`
- **File**: `Sources/HTML Renderable/HTML.Context.swift:329`
- **Issue**: `writeOpeningTag` is a compound method name (internal).
- **Current**: `context.writeOpeningTag(tag)`
- **Expected**: `context.write.opening(tag:)` or similar nested accessor

### [API-NAME-002] Compound method name `writeClosingTag`
- **File**: `Sources/HTML Renderable/HTML.Context.swift:348`
- **Issue**: `writeClosingTag` is a compound method name (internal).
- **Current**: `context.writeClosingTag(tag)`
- **Expected**: `context.write.closing(tag:)` or similar nested accessor

### [API-NAME-002] Compound method name `escapeAttributeValue`
- **File**: `Sources/HTML Renderable/HTML.Context.swift:356`
- **Issue**: `escapeAttributeValue` is a compound method name (internal).
- **Current**: `context.escapeAttributeValue(value)`
- **Expected**: `context.escape.attribute(value)` or similar nested accessor

### [API-NAME-002] Compound property name `stylesheetBytes`
- **File**: `Sources/HTML Renderable/HTML.Context.swift:554,610`
- **Issue**: `stylesheetBytes` is a compound identifier.
- **Current**: `context.stylesheetBytes`
- **Expected**: `context.stylesheet.bytes` (nested accessor)

### [API-NAME-002] Compound method names `nextSibling` and `subsequentSibling` on HTML.Selector
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:168,199`
- **Issue**: `nextSibling(of:)` and `subsequentSibling(of:)` are compound method names.
- **Current**: `selector.nextSibling(of:)`, `selector.subsequentSibling(of:)`
- **Expected**: `selector.next.sibling(of:)`, `selector.subsequent.sibling(of:)` or use the existing aliases `adjacent(to:)` and `sibling(of:)` as the primary names

### [API-NAME-002] Compound property name `firstLine` on HTML.Pseudo
- **File**: `Sources/HTML Renderable/HTML.Pseudo.swift:192`
- **Issue**: `firstLine` is a compound identifier.
- **Current**: `.firstLine`
- **Expected**: `.first.line` (requires a nested accessor namespace)

### [API-NAME-002] Compound property names on HTML.Pseudo structural pseudo-classes
- **File**: `Sources/HTML Renderable/HTML.Pseudo.swift:355-395`
- **Issue**: `firstChild`, `lastChild`, `onlyChild`, `firstOfType`, `lastOfType`, `onlyOfType` are compound identifiers.
- **Current**: `.firstChild`, `.lastChild`, `.onlyChild`, `.firstOfType`, `.lastOfType`, `.onlyOfType`
- **Expected**: `.first.child`, `.last.child`, `.only.child`, `.first.ofType`, `.last.ofType`, `.only.ofType`

### [API-NAME-002] Compound property names on HTML.Pseudo form state pseudo-classes
- **File**: `Sources/HTML Renderable/HTML.Pseudo.swift:313-345`
- **Issue**: `inRange`, `outOfRange`, `readOnly`, `readWrite`, `placeholderShown` are compound identifiers.
- **Current**: `.inRange`, `.outOfRange`, `.readOnly`, `.readWrite`, `.placeholderShown`
- **Expected**: `.in.range`, `.out.ofRange`, `.read.only`, `.read.write`, `.placeholder.shown`

### [API-NAME-002] Compound method names on HTML.Pseudo functional pseudo-classes
- **File**: `Sources/HTML Renderable/HTML.Pseudo.swift:454-494`
- **Issue**: `nthChild`, `nthLastChild`, `nthOfType`, `nthLastOfType` are compound method names.
- **Current**: `.nthChild("even")`, `.nthLastChild("2")`, `.nthOfType("odd")`, `.nthLastOfType("1")`
- **Expected**: `.nth.child("even")`, `.nth.last.child("2")`, `.nth.ofType("odd")`, `.nth.last.ofType("1")`

### [API-NAME-002] Compound property names on HTML.Selector form input types (21 instances)
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:495-515`
- **Issue**: 21 compound identifiers: `inputText`, `inputPassword`, `inputEmail`, `inputNumber`, `inputTel`, `inputUrl`, `inputSearch`, `inputDate`, `inputTime`, `inputDatetime`, `inputMonth`, `inputWeek`, `inputColor`, `inputRange`, `inputFile`, `inputCheckbox`, `inputRadio`, `inputSubmit`, `inputReset`, `inputButton`, `inputHidden`.
- **Current**: `.inputText`, `.inputPassword`, etc.
- **Expected**: `.input.text`, `.input.password`, etc. (requires a nested `input` namespace)

### [API-NAME-002] Compound method name `inputType` on HTML.Selector
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:490`
- **Issue**: `inputType` is a compound method name.
- **Current**: `.inputType("text")`
- **Expected**: `.input.type("text")` (nested accessor)

### [API-NAME-002] Compound method names `withClass`, `withId`, `withAttribute`, `withPseudo` on HTML.Selector
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:330-397`
- **Issue**: `withClass`, `withId`, `withAttribute`, `withPseudo` are compound method names.
- **Current**: `selector.withClass("nav")`, `selector.withId("main")`, `selector.withAttribute(...)`, `selector.withPseudo(.hover)`
- **Expected**: Nested accessor pattern

### [API-NAME-002] Compound method name `containsWord` (parameter label)
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:449`
- **Issue**: `containsWord` in `attribute(_:containsWord:)` is a compound parameter label. Borderline -- CSS spec terminology mirroring (API-NAME-003) may justify this.
- **Current**: `.attribute("data", containsWord: "value")`
- **Expected**: Potentially `.attribute("data", contains: .word("value"))` or accept as CSS spec mirroring.

### [API-NAME-002] Compound method name `startsWithOrHyphen` (parameter label)
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:469`
- **Issue**: `startsWithOrHyphen` in `attribute(_:startsWithOrHyphen:)` is a compound parameter label.
- **Current**: `.attribute("lang", startsWithOrHyphen: "en")`
- **Expected**: Potentially `.attribute("lang", starts: .withOrHyphen("en"))` or accept as CSS spec mirroring.

### [API-NAME-002] Compound method name `combinePseudo` on HTML.Element.Style.Context
- **File**: `Sources/HTML Renderable/HTML.Style.Context.swift:135`
- **Issue**: `combinePseudo` is a compound method name (private).
- **Current**: `combinePseudo(lhs, rhs)`
- **Expected**: `combine.pseudo(lhs, rhs)` or `pseudo.combined(lhs, rhs)`

### [API-NAME-002] Compound method name `hasAttribute` on HTML.Selector
- **File**: `Sources/HTML Renderable/HTML.Selector.swift:439`
- **Issue**: `hasAttribute` is a compound identifier.
- **Current**: `.hasAttribute("disabled")`
- **Expected**: `.has.attribute("disabled")` or `.attribute.exists("disabled")`

### [API-NAME-004] Typealias for type unification: `HTML.AtRule.Media`
- **File**: `Sources/HTML Renderable/HTML.AtRule.Media.swift:12`
- **Issue**: `public typealias Media = HTML.AtRule` creates a typealias that unifies `HTML.AtRule.Media` with `HTML.AtRule` itself. This is a self-referencing typealias that adds no semantic distinction.
- **Current**: `extension HTML.AtRule { public typealias Media = HTML.AtRule }`
- **Expected**: Either `HTML.AtRule.Media` should be a distinct type (if it has unique behavior), or callers should use `HTML.AtRule` directly.

### [API-NAME-004] Typealiases for type unification: `HTML.Builder`, `HTML.Empty`, `HTML.Group`
- **File**: `Sources/HTML Renderable/HTML.Builder.swift:19`, `Sources/HTML Renderable/HTML.Empty.swift:13`, `Sources/HTML Renderable/HTML.Group.swift:12`
- **Issue**: `HTML.Builder = Rendering.Builder`, `HTML.Empty = Rendering.Empty`, `HTML.Group = Rendering.Group` are typealiases for type unification. Borderline -- these serve DSL ergonomics (users write `HTML.Builder` not `Rendering.Builder`).
- **Current**: `public typealias Builder = Rendering.Builder`, etc.
- **Expected**: Use canonical types directly, or accept as intentional API ergonomics.

### [IMPL-EXPR-001] Unnecessary intermediate variable in Script rendering
- **File**: `Sources/HTML Elements Rendering/script Script.swift:14-30`
- **Issue**: `callAsFunction` creates a mutable `escaped` String with a manual character-by-character loop. The escape logic is mechanism, not intent.
- **Current**:
```swift
let script = script()
var escaped = ""
escaped.unicodeScalars.reserveCapacity(script.unicodeScalars.count)
for index in script.unicodeScalars.indices { ... }
```
- **Expected**: Extract escaping into a named function/method expressing intent, e.g. `script.escapedForEmbedding()`

### [IMPL-EXPR-001] Unnecessary intermediate variable in Input rendering
- **File**: `Sources/HTML Elements Rendering/input Input.swift:18`
- **Issue**: `let input = HTML.Element.Tag(for: Self.self) { HTML.Empty() }` creates an intermediate variable used in every switch branch across 22 cases.
- **Current**: `let input = HTML.Element.Tag(...)` followed by `switch type { case .button: input.value(...) ... }`
- **Expected**: Compute type-specific attributes first, then chain them.

### [IMPL-EXPR-001] Unnecessary intermediate variable in Base rendering
- **File**: `Sources/HTML Elements Rendering/base Document Base URL.swift:16`
- **Issue**: `let element = HTML.Element.Tag(for: Self.self) { content() }` creates an intermediate variable before the switch.
- **Current**: `let element = HTML.Element.Tag(...)` then `switch self.configuration { ... }`
- **Expected**: Inline construction.

### [IMPL-EXPR-001] Script.body re-creates the entire Script struct
- **File**: `Sources/HTML Elements Rendering/script Script.swift:50-69`
- **Issue**: The `body` computed property re-creates a new `Script(...)` with all the same properties just to call `.callAsFunction { "" }`. This is unnecessary indirection.
- **Current**:
```swift
public var body: some HTML.View {
    Script(src: self.src, async: self.async, ...).callAsFunction { "" }
}
```
- **Expected**: `self.callAsFunction { "" }` -- call `callAsFunction` directly on `self`.

### [IMPL-INTENT] Stylesheet generation uses manual mechanism-heavy code
- **File**: `Sources/HTML Renderable/HTML.Context.swift:554-607`
- **Issue**: `stylesheetBytes` method manually groups styles by atRule, sorts, and iterates with explicit byte-level appending. The grouping + sorting + iteration is mechanism-heavy. Performance justification may apply.
- **Current**: Manual `var grouped: [HTML.AtRule?: [...]]` dictionary, manual sorting, nested for-loops with byte appending.
- **Expected**: Could express intent more clearly with a dedicated `Stylesheet` type.

### [IMPL-031] Manual switch over tag names in `elementType(for:)`
- **File**: `Sources/HTML Renderable/HTML.Element.swift:44-184`
- **Issue**: A 140-line manual switch statement maps tag name strings to element types. This is the canonical mapping, but could be a dictionary literal.
- **Current**: `switch tag { case "html": return WHATWG_HTML.HtmlRoot.self ... default: return nil }`
- **Expected**: `static let tagMap: [String: any WHATWG_HTML.Element.Protocol.Type]` dictionary. However, the switch may be intentional for exhaustive control and performance.

### [API-IMPL-005] `HTML.important` extension in wrong file
- **File**: `Sources/HTML Renderable/HTML.Context.swift:620-633`
- **Issue**: `extension HTML { static let important: [UInt8] }` is an extension on `HTML`, not `HTML.Context`. Per one-type-per-file, this belongs in the `HTML.swift` file or its own file.
- **Current**: Lives at the bottom of `HTML.Context.swift`
- **Expected**: Move to `HTML.swift` or a dedicated file

### [IMPL-040] Thin Error type
- **File**: `Sources/HTML Renderable/HTML.Context.Configuration.swift:147-150`
- **Issue**: `HTML.Context.Configuration.Error` has only a bare `message: String` field with no structured information.
- **Current**: `public struct Error: Swift.Error { public let message: String }`
- **Expected**: Consider adding structured fields or accept as a rendering-layer error.

## Non-Violations (Explicitly Cleared)

### [PATTERN-009] No Foundation imports
All source files import only primitives/standards/foundations-layer modules. No `import Foundation` found anywhere. **PASS**.

### [API-NAME-001] Nest.Name pattern
All types follow the Nest.Name pattern correctly: `HTML.Tag`, `HTML.Context`, `HTML.Element.Tag`, `HTML.Element.Style`, `HTML.Document`, `HTML.Pseudo`, `HTML.Selector`, `HTML.AtRule`, `HTML.Styled`, `HTML.Text`, `HTML.Raw`, `HTML.AnyView`, `HTML._Attributes`, `HTML.Context.Configuration`, `HTML.Context.Configuration.Error`, `HTML.Element.Style.Context`. **PASS**.

### [API-NAME-003] Specification-mirroring names
HTML element types from `HTML_Standard_Elements` / `WHATWG_HTML_Shared` mirror WHATWG spec terminology (e.g., `ContentDivision`, `NavigationSection`, `ThematicBreak`, `BidirectionalIsolate`). **PASS**.

### [IMPL-020] callAsFunction pattern
The HTML elements use `callAsFunction` extensively and correctly for the builder DSL. **PASS**.

### [API-ERR-001] Typed throws
`StringProtocol+HTML.swift:68` uses `throws(HTML.Context.Configuration.Error)` correctly. **PASS**.

### [PATTERN-017] rawValue confinement
All `.rawValue` access on `HTML.Selector`, `HTML.Pseudo`, and `HTML.AtRule` is within the same package. **PASS**.

### [IMPL-034] unsafe keyword placement
No unsafe operations in the codebase. **PASS**.
