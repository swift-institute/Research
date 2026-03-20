# swift-witness-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming [API-NAME-*], implementation [IMPL-*], errors [API-ERR-*], code-organization [API-IMPL-*]
**Scope**: All `.swift` files in `Sources/Witness Primitives/` (4 files)
**Status**: READ-ONLY audit

---

## Summary Table

| ID | Severity | Rule | File | Description |
|----|----------|------|------|-------------|
| WIT-001 | LOW | [API-ERR-001] | Witness.swift:26-28 | Doc example closures use untyped `throws` |
| WIT-002 | LOW | [API-ERR-001] | Witness.Protocol.swift:33,44-45 | Doc example closures use untyped `throws` |
| WIT-003 | LOW | [PRIM-FOUND-001] | Witness.Protocol.swift:33,44-45 | Doc examples reference Foundation `Data` type |
| WIT-004 | INFO | [API-IMPL-005] | Witness.swift | File contains one enum + one typealias (borderline) |

**Total**: 4 findings (0 CRITICAL, 0 HIGH, 0 MEDIUM, 3 LOW, 1 INFO)

---

## Findings

### [WIT-001] LOW -- Untyped `throws` in Witness.swift doc examples

**Rule**: [API-ERR-001] All throwing functions MUST use typed throws.
**File**: `/Users/coen/Developer/swift-primitives/swift-witness-primitives/Sources/Witness Primitives/Witness.swift`
**Lines**: 26-28

The doc comment for `Witness` shows closure properties with untyped `async throws ->`:

```swift
///     var open: (_ path: String, _ flags: Int) async throws -> Int
///     var read: (_ descriptor: Int, _ count: Int) async throws -> [UInt8]
///     var close: (_ descriptor: Int) async throws -> Void
```

These are documentation examples, not executable code, so impact is LOW. However, doc examples set expectations for consumers. Consider showing typed throws (e.g., `async throws(FileSystem.Error) ->`) to model the correct pattern.

---

### [WIT-002] LOW -- Untyped `throws` in Witness.Protocol.swift doc examples

**Rule**: [API-ERR-001] All throwing functions MUST use typed throws.
**File**: `/Users/coen/Developer/swift-primitives/swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift`
**Lines**: 33, 44-45

Three additional untyped `throws` in doc comments:

```swift
///     var fetch: (String) async throws -> Data          // line 33
///     var read: (String) async throws -> Data           // line 44
///     var write: (String, Data) async throws -> Void    // line 45
```

Same assessment as WIT-001: documentation-only, but models the wrong pattern for consumers.

---

### [WIT-003] LOW -- Foundation `Data` type in doc examples

**Rule**: [PRIM-FOUND-001] Primitives MUST NOT import Foundation.
**File**: `/Users/coen/Developer/swift-primitives/swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift`
**Lines**: 33, 44-45

The doc examples use `Data` (a Foundation type) as return/parameter types. While this is only in comments and does not create an actual Foundation dependency, it normalizes Foundation usage in a primitives-layer package. Consider using `[UInt8]` or a domain-appropriate type instead.

---

### [WIT-004] INFO -- Witness.swift contains enum + typealias

**Rule**: [API-IMPL-005] Each `.swift` file MUST contain exactly one type declaration.
**File**: `/Users/coen/Developer/swift-primitives/swift-witness-primitives/Sources/Witness Primitives/Witness.swift`
**Lines**: 46, 50

The file declares:
1. `public enum Witness {}` (line 46) -- the namespace enum
2. `public typealias __WitnessProtocol = Witness.Protocol` (line 50) -- macro workaround

A `typealias` is not a type *declaration* (struct/enum/class/actor), so this is technically compliant per the [API-IMPL-005] clarification. Marked INFO because the typealias is a documented workaround for macro limitations. If the workaround is no longer needed, removing it would simplify the file.

---

## Clean Findings (rules evaluated, no violations)

| Rule | Assessment |
|------|------------|
| [API-NAME-001] Nest.Name pattern | PASS. `Witness`, `Witness.Composition`, `Witness.Protocol` all use proper nesting. No compound type names. |
| [API-NAME-002] No compound identifiers | PASS. No methods or properties use compound names. |
| [API-NAME-003] Specification-mirroring | N/A. Package does not implement a specification. |
| [IMPL-INTENT] Intent over mechanism | PASS. Code is minimal and declarative. Enum namespace, marker protocol, composition enum -- all read as intent. |
| [IMPL-040] Typed throws vs preconditions | N/A. No throwing functions in source (only in doc examples). |
| [API-IMPL-005] One type per file | PASS. `Witness.swift` has the namespace enum, `Witness.Composition.swift` has `Witness.Composition`, `Witness.Protocol.swift` has `Witness.Protocol`. Each file has exactly one type declaration. |
| [PRIM-FOUND-001] No Foundation imports | PASS. No Foundation imports in executable code. |
| [PATTERN-052] @usableFromInline | N/A. No @inlinable functions. |

---

## Overall Assessment

This package is very clean. The codebase is minimal (4 files, ~140 lines of source) and well-structured. All naming conventions are followed. No executable code violations found. The only findings are in documentation examples that model untyped throws and Foundation types -- these are cosmetic but worth fixing to set the right example for consumers of the witness pattern.
