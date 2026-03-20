---
date: 2026-03-20
session_objective: Audit File/Directory/Path type surface and resolve ExpressibleByStringLiteral vs throwing init tension
packages:
  - swift-file-system
  - swift-paths
  - swift-tests
status: processed
processed_date: 2026-03-20
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-037] string interpolation as type bridge pattern
  - type: experiment_topic
    target: swift-paths
    description: "Path.init(validating:) rename scope — verify breaking change impact across Path family"
  - type: package_insight
    target: swift-tests
    description: "#filePath to File.Path conversion hack (6 occurrences)"
---

# File/Path Literal vs Throwing Init — Harmonization

## What Happened

Started with a research prompt (`file-path-type-unification-audit.md`) investigating whether `File`/`File.Directory` wrapper types earn their keep over `Path` directly. The audit surfaced a fundamental tension: `ExpressibleByStringLiteral` and `init(_ string:) throws` are incompatible on the same type because Swift's overload resolution selects the literal conformance unconditionally — even inside `try` expressions.

Created experiment `literal-vs-throwing-init-disambiguation/` that empirically confirmed: `try` does NOT disambiguate. `@_disfavoredOverload` doesn't help either. The compiler resolves overloads before considering the `try` context, then warns "no calls to throwing functions occur within 'try' expression."

The principled resolution: `File.Directory.init(_ string:) throws` was replaced with `init(validating:) throws` (labeled, no conflict). The `/` operator with `Path`'s `ExpressibleByStringLiteral`/`ExpressibleByStringInterpolation` is the correct composition mechanism. String conversion belongs in `Path`, not in wrapper types.

Also harmonized consumer call sites in swift-tests: error types changed from `path: String` to `path: File.Path` (removing `String(describing: path)` conversions), and pre-existing `String → Path.Component` build failures fixed using string interpolation coercion (`result / "\(stringVariable)"` instead of `result / stringVariable`).

## What Worked and What Didn't

**Worked well:**
- The experiment-first approach definitively settled the `try`-doesn't-disambiguate question. Without empirical evidence, the design discussion would have gone in circles.
- The prior `path-operator-overload-resolution` experiment was directly relevant — it confirmed the `/` operator handles even 15-deep chains without type-checker issues.
- String interpolation coercion to `Path.Component` via `ExpressibleByStringInterpolation` turned out to be the cleanest solution for String-variable-to-path-component conversion, avoiding both throwing and force-unwrapping.

**Didn't work well:**
- Initial instinct was to add `init(validating:)` to both `File` and `File.Directory`, plus `ExpressibleByStringLiteral`. The user correctly pushed back: the real architecture was always `String → Path → File/Directory`, with the `/` operator as the composition mechanism. Adding literal conformance to wrappers was solving a problem that didn't exist.
- Over-corrected when fixing pre-existing `String → Component` issues — made functions throwing with `.appending()` when string interpolation with `/` was simpler and non-throwing.
- Attempted to change error types without checking import chains — `Tests Core` doesn't import `File_System`, so `Provider.Error` correctly stores `String`, not `File.Path`.

## Patterns and Root Causes

**`try` as post-resolution annotation**: This is a language-level design choice that affects any type combining `ExpressibleByStringLiteral` with a throwing `init(_ string:)`. The `Path` family already has this tension (all 4 types: `Path`, `Component`, `Extension`, `Stem`). It's latent but tolerated because nobody `try`s a literal they know is valid. The tension only surfaced when `File.Directory` tried to add the same pattern — because `File.Directory` is more often constructed from runtime strings.

**String interpolation as type bridge**: `"\(stringVariable)"` is a literal expression even though it contains a variable. This means any type conforming to `ExpressibleByStringInterpolation` can accept String variables through interpolation without throwing. This is a general-purpose pattern for the `ExpressibleByStringLiteral` + `init(_:) throws` tension: wrap the variable in interpolation and the literal conformance handles it. The fatalError path is the same one all path literals use.

**Layer-appropriate error types**: Error types should store the most specific type available at their layer. `Tests Core` (no filesystem dependency) stores `path: String`. `Tests Performance` (imports `File_System`) stores `path: File.Path`. The conversion happens at the boundary where layers meet — this is correct, not a hack.

## Action Items

- [ ] **[skill]** implementation: Document string interpolation coercion pattern — `path / "\(stringVar)"` as the non-throwing way to use String variables with `/` operator on types conforming to `ExpressibleByStringInterpolation`. This is a general [IMPL-000] call-site-first pattern.
- [ ] **[experiment]** Verify whether `Path.init(_ string:) throws` should be renamed to `init(validating:)` across the entire `Path` family (Path, Component, Extension, Stem) to eliminate the latent `ExpressibleByStringLiteral` tension at the root. Scope the breaking change impact.
- [ ] **[package]** swift-tests: The `File.Path(stringLiteral: #filePath)` pattern (6 occurrences) remains — a known hack for converting `#filePath` String to `File.Path`. Needs a principled solution (either `Path.init(unchecked:)` or a dedicated `#filePath`-aware init).
