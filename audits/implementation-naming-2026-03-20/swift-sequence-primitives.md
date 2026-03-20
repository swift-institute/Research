# swift-sequence-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Scope**: 75 source files across 4 modules
**Rules**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-033], [PATTERN-017], [API-IMPL-005], [API-ERR-001]

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 2 |
| LOW | 3 |
| INFO | 2 |

This package is exceptionally clean. Naming follows Nest.Name throughout, one-type-per-file is strictly observed, and `.rawValue` does not appear at call sites. The few findings are boundary-layer `Int(bitPattern:)` usage and minor iteration style observations.

## Findings

### [SEQ-001] `Int(bitPattern:)` in non-boundary code (Sequence.Difference+core.swift)
**Rule**: [IMPL-010] `Int(bitPattern:)` in boundary overloads only
**Severity**: LOW (documented workaround)
**File**: `Sources/Sequence Difference Primitives/Sequence.Difference+core.swift`, lines 40-41
**Finding**: `Int(bitPattern: oldCount)` and `Int(bitPattern: newCount)` are used inside the Myers algorithm implementation, not in a boundary overload.
**Mitigation**: The code has a WORKAROUND comment explaining that the Myers algorithm internals operate in `Int` and do not benefit from typed indexing. Acceptable as-is given the documented rationale.

### [SEQ-002] `Int(bitPattern:)` in Difference iterators could use existing Cardinal overloads
**Rule**: [IMPL-010]
**Severity**: LOW
**Files**: `Sources/Sequence Difference Primitives/Sequence.Difference.Steps.Iterator.swift`, lines 33-34; `Sources/Sequence Difference Primitives/Sequence.Difference.Changes.Iterator.swift`, lines 33-34
**Finding**: `Int(bitPattern: _index)` and `Int(bitPattern: take)` used to bridge from typed indices to `Span.extracting(droppingFirst:)` and `extracting(first:)` which take `Int`. However, `Swift.Span+extracting.swift` in the same package provides `Cardinal`-typed overloads for both methods. The iterators could use these instead.
**Recommendation**: Replace `Int(bitPattern:)` calls with the `Cardinal`-typed `extracting` overloads already provided by this package.

### [SEQ-003] `for i in span.indices` pattern in iterators
**Rule**: [IMPL-033] Iteration: intent over mechanism
**Severity**: INFO
**Files**: `Sequence.Drop.While.Iterator.swift` line 54, `Sequence.Prefix.While.Iterator.swift` line 53
**Finding**: Uses `for i in span.indices` with `span[i]` access. This is a stdlib `Span` API limitation -- `Span` does not provide `forEach` or `enumerated`, so index-based access is the only option. Not a violation; acknowledging the limitation.

### [SEQ-004] `for step in _storage` raw array iteration (Sequence.Difference.Steps)
**Rule**: [IMPL-033]
**Severity**: LOW
**File**: `Sources/Sequence Difference Primitives/Sequence.Difference.Steps.swift`, line 47
**Finding**: `counts()` iterates `_storage` directly via `for step in _storage`. The type conforms to `Sequence.Protocol` so `forEach` is available, but since this is internal implementation on the backing `[Step]` array, direct iteration is appropriate and more readable.

### [SEQ-005] `Sequence.Difference.Changes+hunks.swift` uses `Int(bitPattern:)` in business logic
**Rule**: [IMPL-010]
**Severity**: MEDIUM
**File**: `Sources/Sequence Difference Primitives/Sequence.Difference.Changes+hunks.swift`, lines 37-38, 79, 83, 98
**Finding**: Multiple `Int(bitPattern:)` calls to bridge `Cardinal` to `Int` for `Array.dropFirst` and `Array.count` comparisons. These are not boundary overloads; they are inline conversions in business logic. Consider adding `Cardinal`-typed convenience methods or restructuring to keep `Int` conversion at the boundary.

### [SEQ-006] `Sequence.Difference+diff.swift` subscripts with `Ordinal` (boundary overload)
**Rule**: [IMPL-010]
**Severity**: INFO
**File**: `Sources/Sequence Difference Primitives/Sequence.Difference+diff.swift`, lines 46, 49, 51, 52
**Finding**: `old[oldPosition]` and `new[newPosition]` where positions are `Ordinal`. This relies on `Array` subscript boundary overloads accepting `Ordinal`. Correct usage.

### [SEQ-007] `Sequence.Consume.View` Sendable conformance in same file
**Rule**: [API-IMPL-005]
**Severity**: MEDIUM
**File**: `Sources/Sequence Primitives Core/Sequence.Consume.View.swift`, lines 86-87
**Finding**: The file contains the `Sequence.Consume.View` struct plus a separate `@unchecked Sendable` conformance extension. While conformance extensions on the same type are standard practice, this could be separated into its own file for strict one-type-per-file compliance. Borderline finding.

## Clean Passes

| Rule | Status |
|------|--------|
| [API-NAME-001] Nest.Name | PASS -- All types: `Sequence.Map`, `Sequence.Filter`, `Sequence.Difference.Hunk`, etc. No compound names. |
| [API-NAME-002] No compound methods | PASS -- Methods use nested accessors: `.drop.first(_:)`, `.prefix.while { }`, `.satisfies.all { }`, `.reduce.into(_:) { }`. |
| [IMPL-002] No .rawValue at call sites | PASS -- Zero `.rawValue` occurrences in all 75 files. |
| [PATTERN-017] .rawValue confined to boundary code | PASS -- No `.rawValue` usage at all. |
| [API-ERR-001] Typed throws | PASS -- Package is fully non-throwing. No `throws` declarations. |
| [API-IMPL-005] One type per file | PASS -- 75/75 files contain exactly one primary type. |

## Overall Assessment

swift-sequence-primitives is near-perfect against the audited rules. The two MEDIUM findings are minor boundary conversion patterns in the `Difference` module. The core iteration pipeline (`Map`, `Filter`, `CompactMap`, `FlatMap`, `Drop`, `Prefix`) is exemplary -- proper Nest.Name, one-type-per-file, no `.rawValue` leaks, no compound identifiers.
