# swift-ascii-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming, implementation
**Scope**: All 17 `.swift` files in `Sources/ASCII Primitives/`
**Status**: READ-ONLY audit

---

## Summary Table

| ID | Severity | Rule | File | Finding |
|----|----------|------|------|---------|
| ASCII-001 | HIGH | API-NAME-001 | ASCII.ControlCharacters.swift | `ControlCharacters` is a compound type name |
| ASCII-002 | HIGH | API-NAME-001 | ASCII.GraphicCharacters.swift | `GraphicCharacters` is a compound type name |
| ASCII-003 | HIGH | API-NAME-001 | ASCII.CaseConversion.swift | `CaseConversion` is a compound type name |
| ASCII-004 | HIGH | API-NAME-001 | ASCII.LineEnding.swift | `LineEnding` is a compound type name |
| ASCII-005 | MEDIUM | API-NAME-002 | ASCII.Serialization.swift:55 | `hexDigitUppercase` is a compound method name |
| ASCII-006 | MEDIUM | API-NAME-002 | ASCII.Serialization.swift:71 | `hexDigitLowercase` is a compound method name |
| ASCII-007 | MEDIUM | API-NAME-002 | ASCII.Serialization.swift:103,158 | `serializeDecimal` is a compound method name |
| ASCII-008 | MEDIUM | API-NAME-002 | ASCII.Validation.swift:54 | `isAllASCII` is a compound method name |
| ASCII-009 | MEDIUM | API-NAME-002 | ASCII.Classification.swift:257 | `isHexDigit` is a compound method name |
| ASCII-010 | MEDIUM | API-NAME-002 | ASCII.Classification.swift:340 | `isAlphanumeric` is a compound method name |
| ASCII-011 | MEDIUM | API-NAME-002 | ASCII.Byte+Classification.swift:50 | `isHexDigit` compound property on Byte |
| ASCII-012 | MEDIUM | API-NAME-002 | ASCII.Byte+Classification.swift:62 | `isAlphanumeric` compound property on Byte |
| ASCII-013 | LOW | API-NAME-002 | ASCII.Byte+Constants.swift | 19 compound property aliases (forwardSlash, leftSquareBracket, doubleQuote, etc.) |
| ASCII-014 | LOW | API-IMPL-005 | ASCII.swift | Two types in one file: `ASCII` + `ASCII.Case` |
| ASCII-015 | INFO | IMPL-INTENT | ASCII.CaseConversion.swift:87-88 | Raw hex literals `0x61`, `0x20` instead of named constants |
| ASCII-016 | INFO | PATTERN-017 | ASCII.Byte+Classification.swift:83 | `rawValue` at call site `CaseConversion.convert(rawValue, to:)` |

**Totals**: 4 HIGH, 8 MEDIUM, 2 LOW, 2 INFO

---

## Detailed Findings

### ASCII-001 [HIGH] — `ControlCharacters` compound type name

**Rule**: [API-NAME-001] All types MUST use the `Nest.Name` pattern. Compound type names are forbidden.

**Location**: `ASCII.ControlCharacters.swift:72`

**Current**: `ASCII.ControlCharacters`

**Proposed**: `ASCII.Control` — mirrors INCITS 4-1986 Section 4.1 terminology ("Control Characters" describes the *category*, "Control" is the domain noun). The nested constants are already characters; the namespace does not need to redundantly say "Characters".

---

### ASCII-002 [HIGH] — `GraphicCharacters` compound type name

**Rule**: [API-NAME-001]

**Location**: `ASCII.GraphicCharacters.swift:75`

**Current**: `ASCII.GraphicCharacters`

**Proposed**: `ASCII.Graphic` — same rationale as ASCII-001. The namespace groups graphic characters; the plural "Characters" is redundant with the context. INCITS 4-1986 Section 4.3 heading is "Graphic Characters" but the domain noun is "Graphic".

---

### ASCII-003 [HIGH] — `CaseConversion` compound type name

**Rule**: [API-NAME-001]

**Location**: `ASCII.CaseConversion.swift:16`

**Current**: `ASCII.CaseConversion`

**Proposed**: Two options:
- **Option A**: Merge into `ASCII.Case` — the `Case` enum already exists. Case conversion is an operation *on* `ASCII.Case`, so `ASCII.Case.convert(_:to:)` and `ASCII.Case.offset` read naturally.
- **Option B**: `ASCII.Conversion` — if a standalone namespace is desired. Less precise but non-compound.

Option A is preferred because it eliminates the namespace entirely and places the operation where it belongs.

---

### ASCII-004 [HIGH] — `LineEnding` compound type name

**Rule**: [API-NAME-001]

**Location**: `ASCII.LineEnding.swift:14`

**Current**: `ASCII.LineEnding`

**Proposed**: `ASCII.Line.Ending` — uses Nest.Name pattern. Requires creating `ASCII.Line` as a namespace enum first.

---

### ASCII-005 [MEDIUM] — `hexDigitUppercase` compound method name

**Rule**: [API-NAME-002] Methods MUST NOT use compound names. Use nested accessors.

**Location**: `ASCII.Serialization.swift:55`

**Current**: `ASCII.Serialization.hexDigitUppercase(_:)`

**Proposed**: When integrated with the `ASCII.Hexadecimal` subject domain, this would become something like `ASCII.Hexadecimal.Serializer.digit(_:case:)` or nest via an accessor. At minimum, separate the hex domain from the case: `hexDigit(_:case: .upper)` using the existing `ASCII.Case` enum.

---

### ASCII-006 [MEDIUM] — `hexDigitLowercase` compound method name

**Rule**: [API-NAME-002]

**Location**: `ASCII.Serialization.swift:71`

**Current**: `ASCII.Serialization.hexDigitLowercase(_:)`

**Proposed**: Same resolution as ASCII-005 — unify into a single `hexDigit(_:case:)` method.

---

### ASCII-007 [MEDIUM] — `serializeDecimal` compound method name

**Rule**: [API-NAME-002]

**Location**: `ASCII.Serialization.swift:103,158`

**Current**: `ASCII.Serialization.serializeDecimal(_:into:)`

**Proposed**: The word "serialize" is redundant given the `Serialization` namespace. Should be `ASCII.Serialization.decimal(_:into:)` or, when the `ASCII.Decimal.Serializer` subject domain is populated, move there entirely.

---

### ASCII-008 [MEDIUM] — `isAllASCII` compound method name

**Rule**: [API-NAME-002]

**Location**: `ASCII.Validation.swift:54`

**Current**: `ASCII.Validation.isAllASCII(_:)`

**Proposed**: `ASCII.Validation.all(_:)` — the `ASCII.Validation` namespace already provides context. "isAllASCII" is triply redundant (is + all + ASCII, where ASCII and validation context are already in the namespace).

---

### ASCII-009 [MEDIUM] — `isHexDigit` compound method name

**Rule**: [API-NAME-002]

**Location**: `ASCII.Classification.swift:257`

**Current**: `ASCII.Classification.isHexDigit(_:)`

**Proposed**: Restructure classification to use a nested accessor pattern. For example, `ASCII.Classification.hex.isDigit(_:)` or introduce `ASCII.Hex` as a namespace with `isDigit` on it. Alternatively, accept this as a domain term from the standard ("hexadecimal digit" is a single concept in INCITS 4-1986), which would make it specification-mirroring rather than compound. Needs discussion.

---

### ASCII-010 [MEDIUM] — `isAlphanumeric` compound method name

**Rule**: [API-NAME-002]

**Location**: `ASCII.Classification.swift:340`

**Current**: `ASCII.Classification.isAlphanumeric(_:)`

**Proposed**: Similar to ASCII-009 — "alphanumeric" is arguably a single domain term from the character classification literature. If treated as compound: `ASCII.Classification.isAlpha(_:)` is not equivalent. This may warrant an exception as a specification-mirroring term. Needs discussion.

---

### ASCII-011 [MEDIUM] — `isHexDigit` compound property on Byte

**Rule**: [API-NAME-002]

**Location**: `ASCII.Byte+Classification.swift:50`

**Current**: `byte.ascii.isHexDigit`

**Proposed**: Flows from ASCII-009. If the underlying classification method is renamed, this follows.

---

### ASCII-012 [MEDIUM] — `isAlphanumeric` compound property on Byte

**Rule**: [API-NAME-002]

**Location**: `ASCII.Byte+Classification.swift:62`

**Current**: `byte.ascii.isAlphanumeric`

**Proposed**: Flows from ASCII-010.

---

### ASCII-013 [LOW] — 19 compound property aliases on ASCII.Byte

**Rule**: [API-NAME-002]

**Location**: `ASCII.Byte+Constants.swift` (multiple lines)

These are convenience aliases that mirror `GraphicCharacters` names. 19 instances of compound property names:

- `exclamationPoint`, `quotationMark`, `doubleQuote`, `numberSign`, `dollarSign`, `percentSign`, `plusSign`, `leftParenthesis`, `rightParenthesis`, `forwardSlash`, `lessThanSign`, `lessThan`, `greaterThanSign`, `greaterThan`, `equalsSign`, `questionMark`, `commercialAt`, `atSign`, `circumflexAccent`, `leftSingleQuotationMark`, `leftBracket`, `rightBracket`, `leftSquareBracket`, `rightSquareBracket`, `reverseSlant`, `reverseSolidus`, `verticalLine`, `leftBrace`, `rightBrace`

**Discussion**: Many of these mirror INCITS 4-1986 Table 7 terminology directly (e.g., "EXCLAMATION POINT", "QUOTATION MARK", "LEFT PARENTHESIS"). Under [API-NAME-003], specification-mirroring names are required. This creates a tension: the spec names are inherently multi-word. The compound names here are arguably specification-compliant ([API-NAME-003]) rather than violations of [API-NAME-002]. However, the *aliases* that are NOT spec terms (e.g., `forwardSlash`, `doubleQuote`, `atSign`, `leftSquareBracket`, `rightSquareBracket`) are pure compound convenience names and should be reconsidered.

---

### ASCII-014 [LOW] — Two types in one file

**Rule**: [API-IMPL-005] One type per file.

**Location**: `ASCII.swift`

**Current**: File contains both `public enum ASCII` (line 55) and `public enum Case` (line 63, nested in ASCII extension).

**Proposed**: Extract `ASCII.Case` to `ASCII.Case.swift`.

---

### ASCII-015 [INFO] — Raw hex literals instead of named constants

**Rule**: [IMPL-INTENT] Code reads as intent, not mechanism.

**Location**: `ASCII.CaseConversion.swift:87-93`

```swift
let isLower = (byte &- 0x61) < 26
return isLower ? byte &- 0x20 : byte
```

The hex literals `0x61`, `0x41`, `0x20`, `26` could reference named constants:
- `0x61` = `ASCII.GraphicCharacters.a`
- `0x41` = `ASCII.GraphicCharacters.A`
- `0x20` = `ASCII.CaseConversion.offset`
- `26` could be a named constant for letter count

**Counterpoint**: This is `@_transparent` performance-critical code. The branchless arithmetic is the *intent* here — the hex literals are the standard form for this well-known bit manipulation pattern. Marking as INFO rather than a violation.

---

### ASCII-016 [INFO] — `.rawValue` at call site

**Rule**: [PATTERN-017] `.rawValue` confined to boundary code.

**Location**: `ASCII.Byte+Classification.swift:83,88`

```swift
ASCII.CaseConversion.convert(rawValue, to: .lower)
```

`rawValue` is accessed within `ASCII.Byte` to delegate to static functions. This is boundary code (the Byte wrapper's own implementation bridging to the static classification/conversion layer), so it is correctly placed. Not a violation, but noted for completeness.

---

## Types Not Violating

The following types use the Nest.Name pattern correctly:

| Type | Pattern |
|------|---------|
| `ASCII` | Root namespace |
| `ASCII.Byte` | Nest.Name |
| `ASCII.Case` | Nest.Name |
| `ASCII.Classification` | Nest.Name |
| `ASCII.Validation` | Nest.Name |
| `ASCII.Parsing` | Nest.Name |
| `ASCII.Serialization` | Nest.Name |
| `ASCII.Decimal` | Nest.Name |
| `ASCII.Hexadecimal` | Nest.Name |
| `ASCII.SPACE` | Nest.Name (spec term) |

## Architectural Note

The 4 compound type names (ASCII-001 through ASCII-004) are the highest-impact findings because they propagate through every call site. `ControlCharacters` and `GraphicCharacters` appear in approximately 130+ references in `ASCII.Byte+Constants.swift` alone, plus all downstream consumers. Renaming these requires a coordinated migration across swift-primitives and all dependent packages in swift-standards and swift-foundations.
