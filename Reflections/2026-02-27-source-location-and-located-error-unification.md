---
date: 2026-02-27
session_objective: Unify duplicate source location and located error types across the ecosystem
packages:
  - swift-text-primitives
  - swift-source-primitives
  - swift-test-primitives
  - swift-witnesses
  - swift-parsers
  - swift-parser-primitives
  - swift-json
status: processed
---

# Source Location and Located Error Unification — Type Deduplication at Scale

## What Happened

Executed a four-phase plan (from research v2.1) to unify source location types across the ecosystem, then extended it with two further unifications discovered during a post-implementation inventory.

**Phase 1** (text-primitives): Created `Text.Line.Number`, `Text.Line.Column`, `Text.Location`, and `Text.Line.Map` — factoring the shared `(line, column)` substructure into reusable primitives. `Text.Line.Map` was moved from source-primitives' `Source.Manager.LineMap`.

**Phase 2** (source-primitives): Renamed `Source.Location` → `Source.Position` (compact byte-level), replaced `Source.Location.Resolved` with a new self-contained `Source.Location` (fileID + filePath + Text.Location). Updated `Source.Manager`, `Source.File`, `Source.Range`.

**Phase 3** (test-primitives): Initially created a typealias `Test.Source.Location = Source.Location`. User rejected typealiases — "I'd prefer using Source.Location directly." Deleted the typealias, the `Test.Source` namespace, and updated all four consuming types (Expression, Issue, ID, Trait) and their tests.

**Phase 4** (downstream): Eliminated `Witness.Unimplemented.Location` in swift-witnesses (updating the macro code generator to capture all four source literals) and `Parser.Diagnostic.Location` in swift-parsers.

**Inventory**: Exhaustive search across 61+ primitives packages and all foundations packages found one additional duplicate: `JSON.LocatedError` duplicating `Parser.Error.Located<E>`. Added `Hashable where E: Hashable` to `Parser.Error.Located`, then replaced `JSON.LocatedError` with `Parser.Error.Located<JSON.Error>`.

Seven packages committed. Four duplicate types eliminated. One conformance gap filled.

## What Worked and What Didn't

**Worked well**:
- The research document (v2.1) provided a clear decomposition plan. Execution was mostly mechanical once the types were designed.
- The `Text.Location` factoring was clean — `Source.Location ≅ FileIdentity × Text.Location` is a natural product decomposition.
- The user's "no typealiases" decision improved the outcome. Direct usage of `Source.Location` makes the canonical type visible at every call site and avoids namespace pollution (e.g., extending `Source.Location` through `Witness.Unimplemented.Location` would add members globally).
- The post-implementation inventory caught `JSON.LocatedError` — a different category of duplication that shared the same root cause (packages inventing local types instead of using primitives).

**Didn't work well**:
- The initial typealias approach for test-primitives was wrong. Typealiases look like unification but create ambiguity about which name is canonical.
- Name resolution inside `extension Parser.Diagnostic` required full `Source_Primitives.Source.Location` qualification because `Parser.Diagnostic.Source` shadowed the top-level `Source` namespace. This is a recurring friction point with deeply nested types that share common words.
- The `column: 1` default for witnesses was initially proposed as "good enough" before the user pushed for capturing `#column` at call sites. The "perfect" solution was strictly better and not significantly harder.

## Patterns and Root Causes

**Pattern: Organic type duplication**. When packages are developed independently, they invent local types for common concepts (source location, located error). The duplication isn't visible until someone audits cross-package. This is the same pattern that motivated the five-layer architecture — primitives exist so that higher layers don't reinvent them. The root cause here was that `Source.Location.Resolved` had the wrong shape (handle-based, not self-contained) so higher layers couldn't use it and made their own.

**Pattern: Typealiases as false unification**. A typealias `A = B` looks like it eliminates duplication, but it preserves two names for one concept. When the user writes `Test.Source.Location` they don't see that it's actually `Source.Location`. The "no typealiases" rule produces a stronger invariant: there is exactly one name for each concept, visible at every call site. This is related to [API-NAME-001] — naming should be unambiguous.

**Pattern: Name shadowing in nested extensions**. Inside `extension Parser.Diagnostic { }`, the name `Source` resolves to `Parser.Diagnostic.Source`, not the top-level `Source` from source-primitives. This requires full module qualification (`Source_Primitives.Source.Location`). This friction appears whenever a type shares a common word (`Source`, `Error`, `Location`) with a type from a dependency. No clean fix exists — it's inherent to Swift's name resolution.

## Action Items

- [ ] **[skill]** design: Add guidance that packages SHOULD use primitives types for common concepts (source location, located errors) rather than inventing local equivalents. Reference this session as the cautionary example.
- [ ] **[skill]** naming: Add guidance that typealiases SHOULD NOT be used for type unification — prefer direct usage of the canonical type to maintain naming clarity at call sites.
- [ ] **[package]** swift-async: Pre-existing build error in `Async.Stream.swift:165` (`Sequence` conformance issue) blocks CLI builds of swift-json and swift-parsers. Needs investigation.
