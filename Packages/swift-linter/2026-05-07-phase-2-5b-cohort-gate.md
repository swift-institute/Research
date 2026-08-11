# Phase 2.5b — Sanitize/TempPath Ecosystem Promotion (Cohort Gate)

**Date**: 2026-05-07
**Phase**: 2.5b (`HANDOFF-sanitize-temppath-ecosystem-promotion.md`)
**Outcome**: GATE PASSED — R5 27-hit invariant preserved across the
helper relocation; transitional helpers removed end-to-end.

---

## Setup

Phase 3a sign-off granted 2026-05-07 (parent supervisor relay). The
`sanitizeForPath` + `tempPathFor` transitional helpers post-Phase-3a:

- `swift-foundations/swift-linter/Sources/Linter Core/Lint.Driver.swift`
  — held both helpers as `internal static func`s, marked
  `// TODO (Phase 2.5b ecosystem-promotion)`. Dead code post-Phase-3a
  (no internal callers; tests anchored).
- `swift-foundations/swift-manifests/Sources/Manifest Resolver/Manifest.Resolver.swift`
  — held an inlined `private static func sanitize(_:)` plus two
  hardcoded temp-path strings (in `fetchHTTP` and `evalParent`).
  Marked `// TODO (Phase 2.5b ecosystem-promotion)`.

R5 baseline pre-refactor: 27 hits on swift-tagged-primitives
(carried over from Phase 3a).

## Ecosystem additions

### `Path.sanitized(from:)` — swift-path-primitives (L1)

`Sources/Path Primitives/Path.Sanitization.swift`:

```swift
extension Path {
    public static func sanitized(from source: Swift.String) -> Swift.String {
        // Retain alphanumerics + _ - .  ; replace everything else with _
    }
}
```

Foundation-clean (L1). Pure-string transform, no dependencies beyond
stdlib. Tests cover alphanumerics, special-char retention, slash
substitution, distinct-input differentiation, empty input,
all-unsafe input, leading dot, trailing whitespace, NUL bytes,
determinism, Unicode letters (11 tests).

### `File.Path.Temporary.deterministic(prefix:key:suffix:)` — swift-file-system (L3)

`Sources/File System Core/File.Path.Temporary.swift`:

```swift
extension File.Path {
    public enum Temporary: Swift.Sendable {}
}

extension File.Path.Temporary {
    public static func deterministic(
        prefix: Swift.String,
        key: Swift.String,
        suffix: Swift.String
    ) throws(File.Path.Error) -> File.Path {
        // <TMPDIR>/<prefix><Path.sanitized(from: key)><suffix>
    }
}
```

Composes `Environment.read("TMPDIR")` (with `/tmp` fallback) +
`Path.sanitized` + `try File.Path(...)` validation. Returns typed
`File.Path` (== `Paths.Path`). Tests cover same-triple determinism,
distinct-key separation, prefix/suffix embedding, unsafe-character
sanitization, NUL-byte sanitization, TMPDIR rooting (7 tests).

[API-NAME-001a] check: `File.Path.Temporary` namespace authored as
a method-collecting enum. Plausible siblings (`random`, `unique`,
`pattern`) make this a real namespace, not single-type-no-namespace.

### Package.swift updates

- `swift-foundations/swift-file-system/Package.swift`:
  - Top-level dependencies gain
    `.package(path: "../../swift-primitives/swift-path-primitives")`.
  - `File System Core` target gains `.product(name: "Path Primitives",
    package: "swift-path-primitives")`.

## Consumer migrations

### swift-foundations/swift-manifests

`Manifest.Resolver` removes its private `sanitize(_:)` helper and
replaces both inline temp-path strings with `File.Path.Temporary.deterministic`:

| Site | Before | After |
|---|---|---|
| `fetchHTTP` | `let tempPath = "/tmp/swift-manifests-fetch-\(sanitize(uri.value)).tmp"` | `let tempPath: File.Path = try File.Path.Temporary.deterministic(prefix: "swift-manifests-fetch-", key: uri.value, suffix: ".tmp")` |
| `evalParent` | `let tempDir = "/tmp/swift-manifests-parent-eval-\(sanitize(uri.value))"` | `let tempDirectory: File.Path = try File.Path.Temporary.deterministic(prefix: "swift-manifests-parent-eval-", key: uri.value, suffix: "")` |

Curl `arguments` use `tempPath.description` for the `-o` String
argument; `File(tempPath)` direct for reads. Resolver's typed-throws
wraps `File.Path.Error` as `parentFetchFailed(...)`.

### swift-foundations/swift-linter

`Lint.Driver` removes both transitional helpers:

- `internal static func sanitizeForPath(_:)` — deleted.
- `internal static func tempPathFor(url:)` — deleted.
- `internal import URI_Standard` — removed (was kept only for `tempPathFor`'s URI-typed parameter).
- `// MARK: - Phase 2.5 ecosystem-promotion candidates` section — deleted.
- TODO markers — deleted.

`Lint.Driver Tests.swift` removes the corresponding test suites:

- `Lint.Driver.Test.SanitizeForPath` (4 tests) — removed; coverage
  lives in `Path.Sanitization.Tests.swift` at L1 (11 tests, broader).
- `Lint.Driver.Test.TempPathFor` (2 tests) — removed; coverage lives
  in `File.Path.Temporary.Tests.swift` at L3 (7 tests, broader).

## Verification

| # | Acceptance Criterion | Verified | Evidence |
|---|---|---|---|
| 1 | `Path.sanitized(from:)` exists in swift-path-primitives + tests pass | ✓ | 11 tests in Path.Sanitization.Tests.swift pass; covers alphanumerics / special-char retention / slash sub / distinct-input separation / empty / all-unsafe / leading dot / trailing whitespace / NUL / determinism / Unicode. |
| 2 | `File.Path.Temporary.deterministic(prefix:key:suffix:)` exists in swift-file-system + tests pass | ✓ | 7 tests in File.Path.Temporary Tests.swift pass; covers determinism / distinct-key separation / prefix-suffix embedding / sanitization / NUL handling / TMPDIR rooting. |
| 3 | Transitional `sanitizeForPath` + `tempPathFor` helpers removed | ✓ | `grep -rn "sanitizeForPath\|tempPathFor" swift-linter/Sources/ swift-manifests/Sources/` → empty. |
| 4 | `// TODO (Phase 2.5 ecosystem-promotion)` markers removed | ✓ | `grep -rn "TODO.*Phase 2\.5\|Phase 2\.5b ecosystem" swift-linter/Sources/ swift-manifests/Sources/` → empty. |
| 5 | swift build + swift test GREEN on all four modified packages | ✓ | swift-path-primitives: build green, sanitization tests pass. swift-file-system: 719 tests in 323 suites pass. swift-manifests: 2 tests in 4 suites pass (144s integration). swift-linter: 109 tests in 49 suites pass (down from 115 — the 6 absent tests are the migrated SanitizeForPath ×4 + TempPathFor ×2 suites whose coverage is now at L1/L3). |
| 6 | R5 27-hit invariant preserved | ✓ | `swift run --package-path . swift-linter /Users/coen/Developer/swift-primitives/swift-tagged-primitives 2>&1 \| grep -c "unchecked_call_site"` → **27**. |
| 7 | Verification record stamped | ✓ | This file. |

## Supervisor ground-rules verification

| # | Rule | Verified |
|---|------|----------|
| 1 | fact: 4-package scope (path-primitives + file-system + linter + manifests); pure-additive at primitives/file-system; pure-subtractive at linter/manifests | ✓ — observed. The brief listed three packages assuming Phase 3a's Option C; Phase 3a's Option A (NEW L1 + RENAMED L3) made it four. The Resolver and Lint.Driver both held copies of the helper logic post-Phase-3a; both are migrated. |
| 2 | MUST verify `File.Path.Temporary` namespace state per [API-NAME-001a] BEFORE authoring | ✓ — pre-flight grep returned zero hits. Authored as a method-collecting namespace (no nested types) with plausible future siblings; not single-type-no-namespace. No escalation needed. |
| 3 | MUST NOT add Foundation imports anywhere | ✓ — no `import Foundation` introduced. `grep -rn "import Foundation" swift-path-primitives/Sources/ swift-file-system/Sources/File\ System\ Core/File.Path.Temporary.swift swift-manifests/Sources/` → empty. |
| 4 | MUST NOT change R5 hit count or rule behavior | ✓ — R5 = 27 pre-refactor; R5 = 27 post-refactor. |
| 5 | MUST NOT push without per-action authorization | ✓ — local commits only. |
| 6 | ask: edge cases in sanitize character set | n/a — no edge case surfaced requiring a decision. The character set inherited from Lint.Driver's `sanitizeForPath` (alphanumerics + `_`, `-`, `.`) is preserved verbatim. Tests cover documented edge cases (empty input, all-unsafe input, leading dot, trailing whitespace, NUL bytes, Unicode letters); behavior matches expectations. |

## Notes

- **Scope expansion vs the brief**: the brief assumed only one package
  carried the transitional helpers (linter OR resolver). After
  Phase 3a's Option A, BOTH packages had copies — Lint.Driver retained
  them as dead code anchored by tests, and Manifest.Resolver had
  inlined private versions. Both are migrated in this dispatch.
- **API-NAME-001a check on Path.sanitization**: `Path.sanitization`
  is not introduced as a sub-namespace; the static method lives
  directly on `Path`. The file `Path.Sanitization.swift` groups by
  topic (a soft [API-IMPL-006] convention; the file name conveys the
  topic without a corresponding type declaration).
- **Resolver curl arg**: switched from String literal `tempPath` to
  `tempPath.description`. Curl invocation accepts the path string
  identically; the typed `File.Path` value carries through internal
  reads as `File(tempPath)` direct.
- **Lint.Driver test count**: dropped from 115 to 109 (6 tests
  migrated to L1/L3 with broader coverage); net coverage increased
  (4+2 → 11+7 = 18 total tests for the same operations).

## Pending (deferred per orchestrator)

Push wave for the four touched packages remains deferred to cohort
terminal post-Phase-4 per the orchestrator's terminal authorization
plan. No per-action surfacing during this phase.
