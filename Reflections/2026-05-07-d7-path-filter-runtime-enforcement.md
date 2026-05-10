---
date: 2026-05-07
session_objective: Close the Path.Filter runtime-enforcement gap (D7'/CQ5/DT1/PR9) so the per-rule `paths:` filter on `Lint.Rule.Configuration` actually scopes rule invocation in the engine.
packages:
  - swift-foundations/swift-linter
  - swift-primitives/swift-linter-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction Linter_Primitives.Path vs Paths.Path collision research deferred (single-instance, package-specific). Handoff brief consumer-emission shape captured in [HANDOFF-031] syntactic-vs-semantic disclaimer. Blog Tagged + SLI ExpressibleByStringLiteral candidate for Blog/_index.json (deferred to blog process).
---

# D7' — Path.Filter Runtime Enforcement

## What Happened

Branching dispatch `HANDOFF-d7-path-filter-runtime-enforcement.md` closed
the gap where `Lint.Rule.Configuration.paths: Path.Filter?` was a
public-API surface element threaded through `Lint.Configuration.effectiveRules()`
but never read by `Lint.Run.run`. First adopter passing a `paths:`
filter would have seen the rule fire on every file regardless.

Five scope items executed:

1. **`Lint.Run.run` filter-application logic** — built `(rule, filter)`
   pair list from `effectiveRules()`, gated per-source rule invocation
   on `Path.Filter.matches(sourcePath:)`. Documented composition order
   inline: `Mode.disabled` short-circuits at `effectiveRules()`
   (stage 1); the per-rule path filter applies HERE on enabled
   entries (stage 2).

2. **`Path.Filter.matches(sourcePath:) -> Bool` helper** — public,
   `@inlinable`, located on `Path.Filter` itself rather than as a
   free function. Prefix-match per `Swift.String.hasPrefix` against
   each prefix's underlying string.

3. **Four integration tests** under `Lint.Run.Test.Integration`
   exercising `.all` / `.including A` / `.excluding B` / `.including
   non-matching` against a `Tests/Fixtures/path-filter-fixture/`
   carrying `__unchecked:` violations in `Sources/A/x.swift` and
   `Sources/B/y.swift`. `Linter Rule Unchecked` activated via a new
   test-target dep on `swift-linter-rules` (Package.swift dep only;
   no source modification).

4. **`Path.Filter` doc-comment refresh** — dropped the stale "Open
   Question (Phase 1.5 Item 5)" framing; documented prefix-match
   enforcement contract.

5. **Composition order documented** in `Lint.Run.run`'s doc comment.

Mid-flight supervisor redirect (Ground Rule #7 appended to handoff)
caused a typed-shape rollback: initial implementation used
`[Swift.String]` for `included` / `excluded`. Supervisor cited
`swift-institute/Research/tagged-path-string-identity-resolution.md`
v2.0.0 DECISION (Tier 2) and required `Path.Filter.Prefix =
Tagged<Path.Filter, Swift.String>`. Rollback was localized — Path.Filter,
Lint.Configuration, Lint.Driver, and the new tests all updated to the
typed shape. Tagged's SLI `ExpressibleByStringLiteral` made the
existing `["Tests/Fixtures", ".build"]` literals continue to type-check
without any test changes in the existing Lint.Configuration test suite
(8/8 pass).

Local commits (no push per Ground Rule #5):
- `swift-linter-primitives@3ebc5d0` — Path.Filter typed prefixes + matches helper
- `swift-linter@27c8009` — Lint.Run filter logic + integration tests

Build outcomes: both `rm -rf .build && swift build && swift test`
green. Test count: primitives 8/8; foundations 10/10 (6 baseline + 4
new). Supervisor constraints #1–#7 all verified end-to-end per
`HANDOFF-d7-path-filter-runtime-enforcement.md` Implementation Notes.

## What Worked and What Didn't

**Worked**:

- **Tagged-shape redirect, mid-flight rollback small.** The redirect
  came after the initial Path.Filter.swift edit but before any commit.
  The blast radius of switching `[Swift.String]` → `[Path.Filter.Prefix]`
  was bounded to four files (Path.Filter, Lint.Configuration,
  Lint.Driver, the new tests). Existing Lint.Configuration tests
  (`["Tests/Fixtures", ".build"]` literals) continued to type-check
  via SLI's `ExpressibleByStringLiteral` — zero test changes
  required. The typed-shape composition with literal syntax is the
  feature that made the redirect cheap; absent it, every call site
  would have needed `Path.Filter.Prefix(_unchecked: ())` or similar
  explicit construction.

- **`#filePath`-anchored fixture-root resolution.** Pure-string path
  manipulation (split-by-`/`, drop two trailing components, append)
  kept the test Foundation-clean and CWD-independent. `swift test`
  works regardless of where it's invoked from.

- **Helper-on-type vs free-function decision.** Putting `matches` on
  `Path.Filter` directly reads call-site as
  `filter.matches(sourcePath:)` — intent-first per [IMPL-INTENT]. A
  free `func matches(_ filter: Path.Filter, sourcePath: …)` would have
  fragmented the surface.

**Didn't work as expected**:

- **Handoff's literal test prefixes were not actually-runnable.** The
  brief's `paths: .including(["Sources/A"])` would only yield 1 finding
  IF the walker emitted source paths starting with `Sources/A`. The
  walker emits paths anchored on the run root passed in — when the
  test passes the absolute fixture root (computed from `#filePath`),
  source paths come back as `<absolute-fixture-root>/Sources/A/x.swift`,
  and bare `"Sources/A"` is never a valid char-prefix of those.
  Substituted with `Path.Filter.Prefix(root + "/Sources/A")` to
  preserve the test's semantic intent (filter discriminates A from B
  by prefix). Documented the deviation in Implementation Notes.

- **`Path` namespace collision required fully-qualified names in the
  engine.** `Linter_Primitives.Path` is one of two `Path` namespaces
  visible inside `Lint.Run.swift` and `Lint.Driver.swift` — `Paths.Path`
  is also reachable transitively via `File_System`. The compiler
  rejected bare `Path.Filter?` with `'Path' is ambiguous for type
  lookup in this context`. Fix was `Linter_Primitives.Path.Filter` +
  `internal import Linter_Primitives`. Bandaid, not a fix at the
  ecosystem level.

## Patterns and Root Causes

**1. The "feature mention vs feature fire" gap class.** The Path.Filter
defect — public surface declared, factories accept the parameter,
`effectiveRules()` threads it, but the engine never reads it — is the
exact pattern CQ5/DT1/PR9 surfaced as HIGH pre-publishable. Unit tests
on each layer pass: `Lint.Configuration` tests assert the filter is
captured; per-rule predicate tests assert findings fire. None of them
asserted the engine USES the filter. Integration tests at the engine
layer are the missing tier; this dispatch added one suite. The class
itself recurs whenever a public field on a configuration value
type is silently un-read by its consumer — and the only protection
is a test that runs the consumer end-to-end and asserts its
configuration-shaped expectations propagate.

**2. Tagged ergonomics under SLI's
`ExpressibleByStringLiteral`.** A migration from `[Swift.String]` to
`[Tagged<Tag, Swift.String>]` would normally require updating every
call site that uses array literals. The SLI `@_disfavoredOverload
init(stringLiteral:)` makes the Tagged form transparent at literal
sites — `["Tests/Fixtures", ".build"]` keeps working when the
declared parameter type changes from `[Swift.String]` to `[Tagged<X,
Swift.String>]`. This is the feature that lets the institute typed-shape
discipline ratchet upward without breaking adopters. Worth surfacing
as an institute-wide pattern: when redirecting from raw strings to
Tagged, the SLI conformance is the reason the redirect's blast radius
is small.

**3. `Path` namespace collision is structural, not local.** Two
ecosystem packages declare top-level `public enum Path { }`:
`swift-linter-primitives` and `swift-paths`. They have different
domain meanings. When both are reachable in a consumer (e.g.,
`swift-linter`'s `Lint.Run.swift` imports `File_System`, which
transitively re-exports `Paths`), the bare `Path` reference is
ambiguous. The fully-qualified workaround is local; the structural
question is whether `Linter_Primitives.Path` should nest under
`Lint.Path` (like `Lint.Source`, `Lint.Rule`) to escape the
collision permanently. This wasn't in scope for D7' but the friction
will recur every time a `Path.Filter` reference is needed from a
file that also pulls in `File_System`.

## Action Items

- [ ] **[research]** `Linter_Primitives.Path` vs `Paths.Path` ecosystem
  collision: investigate whether `Lint.Path` (nested under the `Lint`
  namespace, like `Lint.Source` and `Lint.Rule`) is the right
  long-term home, and what the migration cost looks like across
  swift-linter / swift-linter-rules / swift-linter-primitives consumers.
  Author as `swift-institute/Research/linter-path-namespace-collision.md`.

- [ ] **[skill]** handoff: when a brief specifies test cases with
  literal filter / prefix / pattern strings, the brief MUST also
  specify the consumer-emission shape that the literal aligns with
  (absolute path, run-root-relative, glob-pattern, etc.). The D7'
  brief's `["Sources/A"]` was actionable only under an unstated
  assumption that the walker emits run-root-relative paths; the
  walker emits absolute paths when the run root is absolute, so the
  literal needed in-test computation. Adding this to the handoff
  skill closes a class of executor-time deviation that the brief
  should have specified at write time.

- [ ] **[blog]** "Tagged + SLI's `ExpressibleByStringLiteral`: how a
  `[String] → [Tagged<X, String>]` migration becomes a one-line
  callsite change." Worked example from D7'. The SLI conformance is
  the reason the institute can ratchet from raw-string surfaces to
  typed surfaces without breaking adopters.
