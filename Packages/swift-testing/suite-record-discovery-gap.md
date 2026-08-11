# Suite Record Discovery Gap

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: DECISION
---
-->

## Context

During audit of the snapshot macro unification work, discovered that `Testing.Discovery` only processes `kind == .test` records. Suite records emitted by `@Suite` macro are silently skipped, making suite-level traits (`.serialized`, `.snapshots(record: .all)`, etc.) non-functional under the Institute's Test.Runner.

## Question

How should suite records be processed during section-based and type-metadata discovery?

## Analysis

### Current State

The `@Suite` macro emits binary section records with `kind == .suite` (FourCC `'suit'`). These records are placed in the same `__swift5_tests` section as test records. The accessor boxes a `Test.Suite.Registration` (id + modifiers, no body).

Discovery has three paths:

| Path | Method | Suite handling |
|------|--------|---------------|
| Section-based | `parseTestContentSection` | **Skipped** — `guard record.kind == .test` at line 86 |
| Type metadata | `typeMetadata` | **Skipped** — same guard at line 136 |
| dlsym fallback | `discover(factoryNames:)` | N/A — suites never used `@_cdecl` factories |

### Impact

Without suite discovery, `finalize()` never populates the `suites` array. Tests still group structurally (Tree.Keyed creates `nil` intermediates for path components), but:

- `nil` intermediate nodes carry **no modifiers** — suite traits are silently dropped
- `propagate(through:from:inherited:)` passes inherited modifiers through `nil` nodes unchanged, but since the suite node was never created with its modifiers, there's nothing to inherit

**Result**: `@Suite(.serialized)`, `@Suite(.snapshots(record: .all))`, etc. have no effect.

### Option A: Inline Kind Dispatch

Add suite handling directly in the existing loops of `parseTestContentSection` and `typeMetadata`.

- Pro: Minimal diff, easy to review
- Con: Duplicates the kind → unbox → registry dispatch in two methods

### Option B: Extract Record Processing Helper

Extract a `processRecord(_:into:)` method that both `parseTestContentSection` and `typeMetadata` delegate to after obtaining the record tuple.

- Pro: Single point for kind dispatch, eliminates accessor-calling duplication
- Con: More refactoring than strictly needed

### Option C: Extract Only Unboxing Helper

Extract just the kind-based unboxing + registry insertion, keep accessor-calling inline.

- Pro: Focused helper, minimal change to control flow
- Con: Accessor-calling still duplicated

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Lines changed | ~20 per method | ~40 total | ~25 total |
| Duplication | Both methods dispatch | One method | Accessor duplicated |
| Future kinds (exitTest) | Add in two places | Add in one place | Add in two places |
| Review clarity | Obvious | Moderate | Moderate |

### Constraints

- `discover(factoryNames:)` is test-only — no suite change needed
- `isEmpty` check uses `count` which counts test entries only — correct behavior (suite-only registry has nothing to execute, fallback is appropriate)
- Both `Test.Registration` and `Test.Suite.Registration` are available in `Testing Core` via the `Tests` dependency

## Outcome

**Status**: DECISION

**Option B** — extract a `processRecord` helper. The accessor-calling logic (get accessor, call it, check success, get pointer) is identical for all record kinds. Only the unboxing type and registry method differ per kind. A single helper:

1. Eliminates the duplicated accessor-calling between `parseTestContentSection` and `typeMetadata`
2. Centralizes kind dispatch — when `exitTest` records need processing, only one method changes
3. Reads as intent: "process this record into the registry"

The helper signature:

```swift
private static func processRecord(
    _ record: Test.__TestContentRecord,
    into registry: inout Test.Plan.Registry
)
```

Both `parseTestContentSection` and `typeMetadata` delegate to it after obtaining the record tuple.
