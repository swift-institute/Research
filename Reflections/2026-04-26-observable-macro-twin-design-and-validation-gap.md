---
date: 2026-04-26
session_objective: Build the @Observable macro for swift-observations under live supervision (Pattern B) and verify integration via the existing 12-test runtime suite.
packages:
  - swift-foundations/swift-observations
  - swift-primitives/swift-bit-primitives
status: pending
---

# @Observable macro: twin-macro design forced by Swift's per-site validation, plus the assertMacroExpansion gap

## What Happened

Session received a `/handoff` brief naming the `@Observable` macro
implementation for `swift-foundations/swift-observations`, plus a
6-entry supervisor ground-rules block and 6 acceptance criteria. Pattern
B per [SUPER-023] (continuation principal, fresh subordinate). Goal:
synthesize the boilerplate `_$registrar` + per-property `_read`/`_modify`
accessor pattern that L3 Subjects currently hand-author.

**Pre-flight surfaced two blockers**: (1) `swift test` failed at
baseline `f9607b8` with upstream errors in `swift-bit-primitives`; (2)
deeper investigation revealed those errors cascaded from uncommitted
in-progress work in `swift-property-primitives` (Carrier conformance).
Surfaced both as class (c) escalations per [SUPER-005]. User
diagnosed correctly — the `.build` cache was stale; `rm -rf .build` +
rebuild produced `Build complete!` and the 12-test suite all green at
baseline. Resolved without touching either upstream package.

**Implementation arc** (commit `7e03bdd`):

1. Package.swift updated to add the `Observations Macros` `.macro` target
   (swift-syntax `602.0.0..<603.0.0`) plus the `Observations Macros Tests`
   testTarget for `assertMacroExpansion`-based expansion tests.
2. `Sources/Observations Macros/Plugin.swift` — `CompilerPlugin` listing
   `ObservableMacro.self` and `ObservationTrackedMacro.self`.
3. `Sources/Observations Macros/ObservableMacro.swift` — type-level macro
   conforming to `MemberMacro` (`_$registrar`), `ExtensionMacro`
   (`Observable` conformance), `MemberAttributeMacro`
   (reattaches `@_ObservationTracked(N)` to each stored `var`).
4. `Sources/Observations Macros/ObservationTrackedMacro.swift` —
   property-level helper conforming to `AccessorMacro`
   (`init`/`_read`/`_modify`) and `PeerMacro` (`_<name>` storage peer).
5. `Sources/Observations/Observable.swift` — public `@Observable` macro
   declaration with three attached forms.
6. `Sources/Observations/_ObservationTracked.swift` — public
   `@_ObservationTracked` helper declaration with two attached forms.
7. `Tests/Observations Macros Tests/ObservableMacro Tests.swift` — 6
   expansion tests (simple struct, ~Copyable struct [research gate per
   ground rule #2], class, generic struct, mixed let/var, underscored
   skip).
8. `Tests/Observations Tests/Observation.Tracking Tests.swift` — `Counter`
   replaced with `@Observable struct Counter { var x: Int = 0; var y: Int = 0 }`;
   `Box` reworked off Foundation onto `Synchronization.Mutex`.

**Verification line stamped in HANDOFF.md** per [SUPER-011] before
triggering `/reflect-session`. All 6 ground rules and all 6 acceptance
criteria verified mechanically.

**HANDOFF scan**: 1 file found (`swift-observations/HANDOFF.md`); deleted
after triage — all 6 ground rules verified, all 6 ACs met, all 7 Next
Steps completed, no pending escalation. Verification line was stamped
before deletion per [SUPER-011]; the durable knowledge is captured in
this reflection and the commit message. The file is gitignored anyway,
so deletion is local-only.

## What Worked and What Didn't

**Worked**:

- The brief's load-bearing equivalence check (replace hand-authored
  `Counter`, run 12 runtime tests) caught semantic drift exactly where
  intended. After the macro was correct, those tests went green
  immediately — no integration friction.
- The pre-flight escalation discipline (`/supervise` ground rule:
  "surface class (c) before starting"). Two real escalations surfaced;
  the user resolved both quickly with the right diagnosis (stale
  `.build` cache). Without escalation, I'd have either silently fixed
  upstream packages (rule #4 violation) or stalled.
- Class (b) refinement protocol per [SUPER-005]+[SUPER-015]. Five
  refinements landed in-flight (module name, twin macros, init
  accessors, filter syntax, test framework); each was logged in the
  HANDOFF verification stamp so the parent session can audit the
  delta from the original brief.

**Didn't work / had to recover**:

- **`assertMacroExpansion` does not validate `@attached(...)` form
  applicability against the attachment site.** Wrote tests, all 6
  passed. Migrated the integration test, hit hard compile errors at
  Phase 6:
  `'accessor' macro cannot be attached to struct ('Counter')`
  and `'memberAttribute' macro cannot be attached to property ('x')`.
  The single-macro-with-five-attached-forms design was structurally
  invalid; the test harness skipped the validation that real compilation
  performs. Forced a Phase-3 redesign at Phase-6 cost (split into
  `@Observable` + `@_ObservationTracked`).
- **SwiftSyntax `==` is identity-based, not structural.** The first
  MemberAttributeMacro implementation counted siblings via
  `candidate == varDecl`; the loop never broke because the iterating
  instance was a different object than the parameter. Both `x` and
  `y` got `Property.ID(2)` (the total count), not `0` and `1`.
  Recovered with name-based comparison via `firstBindingName`.
- **Apple's `Observation` framework shadows ecosystem `@Observable` on
  macOS 26.** The runtime test imports `Foundation` for `NSObject`;
  Foundation transitively pulls Apple's `Observation`, and its
  `@Observable` macro (class-only) takes precedence over ours via
  `@testable import Observations`. Compile failed with `'@Observable'
  cannot be applied to struct type 'Counter'` (Apple's class-only
  rejection). Recovered by replacing `import Foundation` + `NSObject`
  + `objc_sync_*` in the test file with `import Synchronization` +
  `Mutex.withLock`.
- **Module-name brief mismatch.** Brief said `module: "ObservationsMacros"`;
  SwiftPM's actual module name from target `"Observations Macros"` is
  `"Observations_Macros"` (spaces → underscores). Caught by compile
  warning, fixed in seconds.
- **Stale `.build` initial pre-flight.** Cost ~10 minutes investigating
  phantom upstream errors that vanished on `rm -rf .build`. The
  user's "try clean .build" suggestion was the correct intervention.

## Patterns and Root Causes

**Pattern 1 — Test-harness vs real-compile drift in macros.**
`assertMacroExpansion` simulates expansion in a mock environment that
lacks the real compiler's per-site validation logic. A macro can pass
all expansion tests yet fail at compile time because `@attached(member)`
on a property-attachment site is rejected by the compiler but accepted
by the test harness. **The lesson**: macro validation has TWO axes —
expansion correctness (textual output) and attachment validity
(form-vs-site compatibility). `assertMacroExpansion` covers axis 1
only. The integration test (real `swift build`) is the only check that
covers axis 2. Macro test coverage that omits a real-compile gate is
fragile.

This connects to a broader pattern: simulator-vs-runtime drift is a
recurring source of late-discovered bugs. The mock/simulator's
cheaper-to-run nature means it's the primary feedback loop, but its
permissiveness invites silent acceptance of constructs the real
runtime rejects. The correct response is not to abandon the simulator
(it's still useful for textual checks) but to NEVER trust simulator
sign-off as ship-readiness.

**Pattern 2 — Single macro with multi-attached-forms is incompatible
with Swift's per-site validation.** A single `public macro` declaration
with `@attached(member)` AND `@attached(accessor)` AND
`@attached(extension)` is **invalid at every site** because Swift
checks each `@attached(...)` against the actual attachment context.
Type sites reject the property-only forms; property sites reject the
type-only forms. The structural fix is twin macros with disjoint
attached-form sets. Apple's `@Observable` does this for the same
reason — `@Observable` (type) + `@ObservationTracked` (property).
This isn't a "neat trick"; it's a forced architectural shape.

The brief's specification implied a single macro. The implementation
required two. The class (b) decision under [SUPER-005] correctly
classified this as principal-scope refinement, but the recursive
pattern was not anticipated by either side at handoff authoring time.
Future macro briefs that combine type-level synthesis with
property-level accessor injection will hit the same wall.

**Pattern 3 — Identity vs structural equality in syntax-tree
iteration.** `Equatable` on `SyntaxProtocol` is `lhs.id == rhs.id` —
node identity, not structural equivalence. Iterating
`declaration.memberBlock.members` yields *new instances* even for
syntax that exists in the original source; comparing those to the
`member` parameter via `==` returns false even when both represent
the same logical declaration. The fix is content-based comparison
(name, position, or text). Future macro authors counting siblings,
finding parents, or detecting peer relationships should default to
content comparison; identity comparison only works for "is this
literally the same node we just received."

**Pattern 4 — Ecosystem name collisions with first-party Apple
frameworks are stronger than expected.** Naming our macro `@Observable`
identical to Apple's framework macro creates a shadowing surface.
On macOS 26, even an indirect `import Foundation` brings Apple's
`Observation` framework into scope, and its macro takes precedence.
The collision is not detectable at our package's compile time — it
only manifests at consumer call sites where Foundation happens to be
imported. **Choices going forward**: (a) accept the shadow risk and
provide consumer guidance ("don't import Foundation in test code that
uses our @Observable"), (b) rename to `@Observation.Observable` (but
attribute names cannot be qualified per current Swift), or (c) rename
the user-facing surface entirely. Option (a) is the path the brief
took; option (c) is a non-starter given the brief's "fact: Scope
confirmed" entry. Document and live with the constraint.

## Action Items

- [ ] **[skill]** testing-swiftlang: Add a [SWIFT-TEST-XXX] requirement
  noting that `SwiftSyntaxMacrosTestSupport` is XCTest-based and pulls
  Foundation transitively — both forbidden by [TEST-001] and the
  ecosystem-wide no-Foundation principle. Macro tests MUST use
  `SwiftSyntaxMacrosGenericTestSupport`, whose `assertMacroExpansion`
  takes a framework-agnostic `failureHandler` closure, paired with a
  Swift Testing adapter routing failures to `Issue.record(...)`. Same
  rule SHOULD note that the generic helper does not validate
  `@attached(...)` form-vs-site applicability either — the
  real-`swift build` integration test remains the only check that
  catches type-only-vs-property-only mismatch.
- [ ] **[skill]** modularization: Add a [MOD-XXX] note that
  `#externalMacro(module: ...)` MUST use the SwiftPM-converted module
  name (spaces → underscores). Targets named with spaces (e.g.,
  `"Observations Macros"`) produce module identity `"Observations_Macros"`,
  not `"ObservationsMacros"`.

## Correction (post-management-review)

User correction during management briefing pointed at /implementation:
**Foundation is banned absolutely**, not "in macro implementation +
generated code only" (the original brief's letter), and not as a
contingent macOS-26-shadow workaround (my session's framing). The
ecosystem rule is stronger than the brief's ground rule #5.

Two consequences re-applied post-commit `7e03bdd`:

1. The runtime-test `Box` swap from `import Foundation` (`NSObject` +
   `objc_sync_*`) to `import Synchronization` (`Mutex.withLock`) is
   correct *for the absolute-ban reason*, not the Apple-shadow reason.
   The shadow happens to disappear as a side benefit; the rule would
   forbid the Foundation import even on a platform where no shadow
   existed.
2. The macro expansion tests originally used XCTest +
   `SwiftSyntaxMacrosTestSupport` — both forbidden ([TEST-001] +
   absolute Foundation ban). Rewritten in commit `4e665a9` using
   Swift Testing `@Suite`/`@Test` + `SwiftSyntaxMacrosGenericTestSupport`
   with an `Issue.record`-routing `failureHandler`. Test count
   unchanged (6 expansion + 12 runtime = 18); suite hierarchy now
   complies with [TEST-005] under `ObservableMacro.Test.{Unit, Edge Case}`.

**Pattern lesson (added to "Patterns and Root Causes" by reference)**:
when a brief carves a partial scope for a foundational rule (e.g.,
"no Foundation in macro source/generated code"), the subordinate
should still apply the broader rule when its scope encompasses the
brief's scope. The brief is permissive of the rule's letter; the
ecosystem axiom is the rule's spirit. Defaulting to the broader rule
costs nothing when the brief's scope is a subset, and avoids re-work
when the principal later corrects the framing.

## Session continuation (second arc)

After this reflection was written, the same session continued into an
ecosystem-audit + adoption arc. Several action items above are now
superseded or refined by that work; the durable lessons are captured
in a sibling reflection:

→ `2026-04-26-ecosystem-audit-and-typed-tls-promotion.md`

**Supersession map**:

- *Action item — testing-swiftlang `SwiftSyntaxMacrosTestSupport` /
  Foundation*: Still valid, sharper now that we know XCTest pulls
  Foundation specifically (vs being a separate framework choice). The
  rule "no Foundation, period" subsumes it; Apple-shadow is a side
  benefit, not the reason.
- *Action item — modularization underscore module name*: Still valid,
  unchanged.
- *(Did not appear here, but worth noting)*: the second arc tested
  every "primitive" against three criteria — capability beyond
  language + existing primitives, ≥1 real consumer, theoretical
  content per `[MOD-DOMAIN]`. `swift-lifetime-primitives` failed all
  three and was deleted. The criteria graduated from "this session's
  rigor" to a candidate ecosystem rule.
- *(New)*: The `_FrameLocal` private helper that this session created
  was promoted to ecosystem level via [PLAT-ARCH-008f] solution (a):
  L2 raw classes renamed to spec-literal `Key` (POSIX) / `Index`
  (Windows), and L3 `Kernel.Thread.Local<Payload>` became the canonical
  typed wrapper. Plus POSIX destructor support for automatic per-
  thread cleanup.
