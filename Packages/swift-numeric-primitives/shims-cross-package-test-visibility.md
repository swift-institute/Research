# `_Shims` cross-package test-visibility cascade

**Status**: investigation complete, awaiting user decision on remediation shape.
**Date**: 2026-04-18.
**Provenance**: `swift-primitives/HANDOFF-shims-cross-package-test-visibility.md`.

## Summary

The cascade `error: missing required module '_Shims'` at `swift test` in packages
that transitively depend on `swift-numeric-primitives` is produced by exactly one
site: `public import _Shims` in `Sources/Real Primitives/Numeric.Relaxed.swift:13`.
The cascade is reachable from consumer test targets only when SwiftPM's declared
transitive dep closure does NOT reach `Real Primitives`, yet the consumer's source
files transitively load its module interface by some other route. This happens in
practice whenever a test target has source-level `import` statements that are not
reflected in its `Package.swift` dependencies.

No remediation preserves all three user constraints simultaneously
(`_Shims` internal, `@inlinable` bodies, full cross-module `fadd reassoc` inlining).
One remediation preserves them by splitting the public surface: move Numeric.Relaxed
to a new library product. Other remediations trade one constraint for another.
The chosen direction requires a user decision between three shapes; this document
records the options rather than selecting one.

## Reproduction

### Observed failure

```
$ cd /Users/coen/Developer/swift-foundations/swift-effects
$ swift test
...
error: emit-module command failed with exit code 1 (use -v to see invocation)
[2/11] Emitting module Effects_Tests
<unknown>:0: error: missing required module '_Shims'
```

Affects `Effects Tests` and `Effects Built-in Tests`.
`Effects Testing Tests` — the third test target in the same package — builds
cleanly, which is the diagnostic asymmetry that pins the cause.

### Build-command diff

`-v` output shows exactly one difference in the Swift frontend arguments:

| Target | `-Xcc -fmodule-map-file=…/_Shims.build/module.modulemap` |
|--------|----------------------------------------------------------|
| Effects Testing Tests | ✅ present |
| Effects Tests | ❌ absent |
| Effects Built-in Tests | ❌ absent |

The passing target declares `Effects Testing` as its dep (via Package.swift). The
declared transitive closure reaches
`Real Primitives` → `_Shims`, so SwiftPM emits `-Xcc -fmodule-map-file=…`. The
failing targets only declare `Effects` or `Effects Built-in`; neither reaches
`_Shims` in the declared closure, so the flag is omitted.

### Source-import divergence

```
Tests/Effects Tests/PerformTests.swift:3:       import Effects_Testing   # NOT declared
Tests/Effects Built-in Tests/YieldTests.swift:3: import Effects_Testing  # NOT declared
                                                import Async_Primitives  # NOT declared
                                                import Dependency_Primitives # NOT declared
```

`Effects_Testing.swiftmodule` exists in `.build/…/debug/Modules/` because the
sibling `Effects Testing` target builds. Swift frontend finds it via `-I Modules`.
Loading `Effects_Testing.swiftmodule` pulls in its transitive `public import`
graph, which reaches `Real_Primitives.swiftmodule`. `Real_Primitives`' serialized
interface declares `public import _Shims`. Without the `-Xcc -fmodule-map-file`
flag, clang cannot resolve `_Shims`, so emit-module fails.

### Transitive chain

```
Effects_Testing (via Clocks)
  → Kernel_Clock
    → Kernel_Core       @_exported public import Dimension_Primitives
      → Dimension_Primitives   public import Real_Primitives
        → Real_Primitives      public import _Shims  ← the only leak site
          → _Shims (.target, NOT a library product)
```

Identified `public import` sites (verified via `grep`):
- `Sources/Real Primitives/Numeric.Relaxed.swift:13: public import _Shims`
- `Sources/Dimension Primitives/{Radian,Degree,Radian+Trigonometry}.swift: public import Real_Primitives` (4 sites)
- `Sources/Kernel Core/exports.swift:36: @_exported public import Dimension_Primitives`
- `Sources/Clocks/exports.swift: @_exported public import Kernel_Clock`

`Numeric.Math.swift` uses a plain `import _Shims` (internal) and routes
`@inlinable public` surface through `@usableFromInline internal` helpers — no
leak. The transcendentals, augmented ops, and fraction types in Real Primitives
all follow that pattern. `Numeric.Relaxed.swift` is the only file using
`public import _Shims`.

### Minimal reproducer

`/tmp/shims-repro-v4/` (archived during investigation). Key ingredients:

1. Package **A**: a non-library C target `_Shims`, a library `Real` depending on
   `_Shims`, with `public import _Shims` and an `@inlinable public` body calling
   a `shim_*` symbol.
2. Package **B**: library `Mid` depending on `Real`, with
   `@_exported public import Real` and another `@inlinable public` body calling
   into `Real`.
3. Package **C**: library `Consumer` + test target `ConsumerTests`. The test
   target declares `Consumer` as dep (which reaches `Real`), and the source
   ALSO has an `import Mid` that is NOT in the declared dep closure.

On clean build, `swift test` produces
`error: missing required module '_Shims'` at `ConsumerTests.swiftmodule`
emit-module. Building `Mid` separately then re-running `swift test` surfaces the
exact signature seen in swift-effects.

### Ingredient verification

Each ingredient removed in isolation makes the error disappear:

| Removed | Result |
|---------|--------|
| `public import _Shims` on the Swift side of `Real` | Passes (bodies then can't reference `shim_*` from `@inlinable`, so build fails for a DIFFERENT reason — compiler rejects internal-access reference inside inlinable body) |
| `@inlinable` on the C-calling function | Passes (symbol resolution no longer needed in consumer's emit-module) |
| Undeclared `import` in the failing test source | Passes (SwiftPM's declared closure becomes sufficient) |
| `_Shims` as `.library` instead of `.target` | Passes (SwiftPM propagates via product transitively) |

## Toolchain verification

`TOOLCHAINS=swift swift test` against 6.4-dev is blocked by an unrelated
RegionIsolation error in `swift-ownership-primitives/Optional+take.swift:36`
before reaching the `_Shims` site (per [ISSUE-001] "blocked by unrelated crash
is not evidence of distinctness"). The minimal reproducer confirms the `_Shims`
behavior is not a 6.3 regression — it reflects a stable language-rule interaction.

## Why the cascade exists (Swift + SwiftPM interaction)

Two rules intersect:

1. **Swift language rule**: an `@inlinable` body may reference only declarations
   accessible to any future caller. For a symbol imported from another module,
   this requires a `public import` of that module — not `import`, not
   `@_implementationOnly import`. Because the `@inlinable` body is serialized
   into the swiftmodule and must type-check at any consumer's emit-module time,
   the referenced module's interface must be visible to every consumer.

2. **SwiftPM propagation rule**: for a C target declared as `.target` (not
   `.library`), SwiftPM includes `-Xcc -fmodule-map-file=…` in a consumer's
   compile command only if the C target is reachable through the consumer's
   DECLARED transitive dep closure. A source-level `import` that lacks a matching
   `Package.swift` dependency bypasses this computation — the Swift frontend
   finds the transitively-loaded swiftmodule (because all targets share
   `.build/.../debug/Modules/`), but the clang module map paths needed by that
   swiftmodule's `public import` graph are absent.

The combination: the moment a test target has an undeclared source-level
`import` whose transitive `public import` chain reaches Real Primitives, the
cascade surfaces.

## Candidate remediations

### A. Hoist to `@usableFromInline internal` wrapper

```swift
import _Shims   // internal — no leak

extension Numeric.Relaxed {
    @inline(__always) @usableFromInline
    internal static func _relaxedAdd(_ a: Double, _ b: Double) -> Double {
        shim_relaxed_add(a, b)
    }

    @inlinable
    public static func sum(_ a: Double, _ b: Double) -> Double {
        _relaxedAdd(a, b)
    }
}
```

- **Fixes cascade**: yes (verified in `/tmp/shims-repro-v5`).
- **Preserves `@inlinable` surface**: yes.
- **Preserves performance**: **NO**.

At `-O`, the consumer's LLVM IR for
`Numeric.Relaxed.sum` reduces to
`tail call swiftcc double @_relaxedAdd(…)` — an opaque cross-module call.
LLVM cannot inline `_relaxedAdd` across module boundaries without LTO. The
whole-program `fadd reassoc contract` that the current public-import pattern
produces collapses into a per-operation function call. Reduction loops lose
cross-iteration reassociation and vectorization.

Verified by `-emit-ir -c release` in `/tmp/shims-repro-v5/C`:
```
define swiftcc double @consumerSum(double %0, double %1) {
entry:
  %2 = tail call swiftcc double @_add(double %0, double %1)
  ret double %2
}
```

Rejected by user constraint #2 as interpreted: "Performance-critical;
inlinability required" — the constraint is about the end-to-end inlined
`fadd reassoc contract`, not just the syntactic `@inlinable` attribute.

### B. Split Numeric.Relaxed into a new library target (PROPOSED)

Restructure swift-numeric-primitives into three library products:

1. **Real Primitives** — `Numeric.Math`, `Numeric.Transcendental`,
   `Numeric.Augmented`, `Numeric.Fraction`, `Numeric.Math.Accessor`. Uses
   `_Shims` internally via `@usableFromInline` helpers. NO `public import _Shims`.
2. **_new_ Numeric Relaxed Primitives** — contains Numeric.Relaxed (moved from
   Real Primitives). Has `public import _Shims`. Library product; declares
   `_Shims` as a target dep.
3. **Numeric Primitives** (umbrella) — currently re-exports `Real Primitives`,
   `Integer Primitives`. After split, it would need a decision: re-export
   `Numeric Relaxed Primitives` too (re-introducing the leak via the umbrella),
   or NOT (breaking source for consumers that reach `Numeric.Relaxed` through
   the umbrella).

- **Fixes cascade**: yes — for every dep chain that does not need Relaxed
  (verified in `/tmp/shims-repro-v6`). Downstream consumers that do not import
  `Numeric Relaxed Primitives` never see `_Shims`. Chains like
  `swift-effects → Clocks → … → Dimension Primitives → Real Primitives` no
  longer carry `_Shims`.
- **Preserves `@inlinable` surface**: yes.
- **Preserves performance**: yes. Consumers that explicitly depend on
  `Numeric Relaxed Primitives` get the same end-to-end
  `fadd reassoc contract` inlining as today, because SwiftPM propagates
  `_Shims`' module map along the declared chain. Verified in
  `/tmp/shims-repro-v6/C` `-emit-ir -c release`:
  ```
  define swiftcc double @consumerRelaxedSum(double %0, double %1) {
  entry:
    %add.i = fadd reassoc contract double %0, %1
    ret double %add.i
  }
  ```
- **Source-breaking**: one known consumer affected.
  `swift-complex-primitives/Sources/Complex Primitives/Complex.Relaxed.swift`
  uses `Numeric.Relaxed.sum` and `Numeric.Relaxed.product`. That package would
  need to add a product dep on `Numeric Relaxed Primitives` and (if
  `InternalImportsByDefault` is active) an import. No other workspace consumer
  currently references `Numeric.Relaxed`. `swift-dimension-primitives`, the
  main transitive consumer of Real Primitives, uses only `Numeric.Fraction`
  and `Numeric.Transcendental` — unaffected.
- **Handoff-constraint reading**: the handoff's "consumers should not have to
  change" clause is ambiguous. Interpreted as "no workarounds in consumer
  packages to paper over a primitives bug" — Option B is compliant. Interpreted
  as "no dependency-list edits in any consumer, ever" — Option B violates it
  for one consumer (swift-complex-primitives). User to disambiguate.

### C. `@_silgen_name` to an externally-linked C symbol

Re-declare each shim as an extern-linkage C function in `shims.c` (not
`static inline`), and reference it from Swift via `@_silgen_name` with
`@usableFromInline internal`. Removes `public import _Shims` from Numeric.Relaxed.

- **Fixes cascade**: yes.
- **Preserves `@inlinable` surface**: yes.
- **Preserves performance**: **NO** — the extern-linkage function is an opaque
  LLVM call at the consumer's site, identical to Option A. Worse: the
  `clang fp reassociate` pragma applies only within `shims.c`'s TU, so the
  externally-callable form of the function no longer participates in
  cross-iteration reassoc at consumer call sites.

### D. `@_implementationOnly import _Shims`

Compiler-rejected. `@_implementationOnly import` explicitly forbids the imported
module's declarations from appearing in `@inlinable` bodies or the public ABI.
Since the current `Numeric.Relaxed` bodies reference `shim_*` directly, the
compiler diagnoses the violation at parse time.

### E. `package import _Shims`

Doesn't apply. `package` access is limited to the same Swift package. All
consumers of Numeric.Relaxed live in separate packages. `package` scope would
fail to compile at the consumer.

### F. `@inlinable @usableFromInline internal` wrapper whose body references `shim_*` under an internal `import _Shims`

Compiler-rejected: `@inlinable` bodies can only reference declarations with
`public` or `@usableFromInline` access. Symbols imported via internal `import`
do not satisfy this rule, even when redeclared via a Swift wrapper.

### G. Status quo + document

Accept the current behavior and document the workaround for downstream packages
(declare all source-level imports in Package.swift).

- **Fixes cascade**: no.
- **Matches user's "consumers should not have to change"**: no.
- **Preserves performance**: yes.

## Recommendation

**Option B**, with the scope question put to the user:

> swift-complex-primitives (one line edit to its Package.swift) is the only
> known source-breaking consumer. Acceptable, or do you want Option G (document
> as Swift/SwiftPM limitation + close the handoff)?

Option A is technically viable and is the MINIMUM change that fixes the
cascade, but it silently trades the end-to-end `fadd reassoc contract`
inlining that the current pattern provides. That trade is not visible at the
API level — consumers call `Numeric.Relaxed.sum` either way — but the
compiled code becomes a call-per-operation instead of an inlined vectorizable
reduction. Given the user's ruled-out list explicitly protects "inlinability",
Option A should not be adopted without explicit approval.

## Implementation sketch (Option B, if approved)

1. Add a new SwiftPM target in swift-numeric-primitives:
   ```swift
   .target(
       name: "Numeric Relaxed Primitives",
       dependencies: ["Numeric Primitives Core", "_Shims"]
   )
   ```
2. Add a matching library product:
   ```swift
   .library(
       name: "Numeric Relaxed Primitives",
       targets: ["Numeric Relaxed Primitives"]
   )
   ```
3. Move `Sources/Real Primitives/Numeric.Relaxed.swift` to
   `Sources/Numeric Relaxed Primitives/Numeric.Relaxed.swift`.
4. Remove `_Shims` from `Real Primitives`' target `dependencies`.
5. Remove the `public import _Shims` leak path entirely from `Real Primitives`.
6. Move Relaxed tests (`Tests/Real Primitives Tests/Relaxed.Tests.swift`) to
   `Tests/Numeric Relaxed Primitives Tests/`.
7. In `swift-complex-primitives/Package.swift`, add
   `.product(name: "Numeric Relaxed Primitives", package: "swift-numeric-primitives")`
   to `Complex Primitives` target deps.
8. Decide umbrella re-export: if `Numeric Primitives` umbrella re-exports
   `Numeric Relaxed Primitives`, the cascade re-appears through the umbrella.
   To keep the separation clean, the umbrella should NOT re-export
   `Numeric Relaxed Primitives`; consumers that use `Numeric.Relaxed` adopt the
   new product explicitly. This is the principal source-breaking decision.

## Open questions

1. **Umbrella re-export decision** — does `Numeric Primitives` (the umbrella)
   re-export the new `Numeric Relaxed Primitives`? Re-exporting reverts the fix
   for consumers that go through the umbrella. Not re-exporting breaks
   consumer source in one known case.

2. **"Consumers should not have to change" scope** — does this rule out the
   one-line Package.swift edit in swift-complex-primitives?

3. **Swift language gap** — this pattern is a recurring architectural hazard
   for any primitives package with internal C shims referenced from inlinable
   public wrappers. Worth filing as a Swift Evolution pitch for a
   `@usableFromInline import` (or similar) that allows `@inlinable` bodies to
   reference the imported module's declarations without making the import
   publicly visible to transitive consumers? Out of scope for this handoff,
   but note for future work.

## References

- Handoff: `swift-primitives/HANDOFF-shims-cross-package-test-visibility.md`
- Numeric.Relaxed: `Sources/Real Primitives/Numeric.Relaxed.swift:13`
- Existing hoist pattern: `Sources/Real Primitives/Numeric.Math.swift:13`
  (compare to Relaxed — shows the working pattern)
- C shims: `Sources/_Shims/include/shims.h` (SHIM_INLINE + SHIM_RELAX_FP)
- Package manifest: `Package.swift:30` (`_Shims` declared as `.target`)
- Complex consumer (source-breaking): `swift-complex-primitives/Sources/Complex Primitives/Complex.Relaxed.swift`
- Reproducers: `/tmp/shims-repro-v4` (cascade), `/tmp/shims-repro-v5` (Option A),
  `/tmp/shims-repro-v6` (Option B + IR verification)
