# Dimension Primitives: rawValue → underlying / Carrier.`Protocol` Migration

**Tier:** 15 (downstream cycle)
**Date:** 2026-05-03
**Upstream drivers:**
- `swift-carrier-primitives` `2b57aac` — `Carrier` becomes a namespace `enum`, capability protocol is `Carrier.\`Protocol\``, member rename `raw` → `underlying`.
- `swift-tagged-primitives` `46ded75` — `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `.rawValue` → `.underlying`; `init(rawValue:)` → `init(_:)`; `init(_unchecked: ())` → `init(_unchecked:)`. Tagged's `Carrier.\`Protocol\`` conformance is unconditional + immediate. `init(_unchecked:)` is `public`.
- Cardinal/Ordinal/Vector precedent — own-field `rawValue` renames to a `_storage` field with a separate `*+Carrier.swift` conformance file exposing `underlying`.

## Q1 — What is the per-file edit surface?

### Tagged-touching files (mechanical-pattern)

- `Sources/Dimension Primitives/Tagged+Arithmetic.swift` — high-volume `RawValue`, `.rawValue`, `init(__unchecked: (), …)` usage.
- `Sources/Dimension Primitives/Tagged+Dimension.swift` — same patterns.
- `Sources/Dimension Primitives/Tagged+Quantized.swift` — same patterns.
- `Sources/Dimension Primitives/Degree.swift` — `Tagged where … RawValue: BinaryFloatingPoint`.
- `Sources/Dimension Primitives/Radian.swift` — same pattern.
- `Sources/Dimension Primitives/Radian+Trigonometry.swift` — same.
- `Tests/Dimension Primitives Tests/Tagged Tests.swift` — `.rawValue` accessors (test names contain "rawValue" — left in test-name strings since they describe historical API; renamed in code paths only where the symbol resolves).
- `Tests/Dimension Primitives Tests/Tagged+Quantized.swift` — `.rawValue` chains.

### Own-field rawValue refactors (precedent-following)

Two types in this package have an own-field `rawValue` (i.e., they store the raw value themselves rather than wrapping `Tagged`):

- **`Axis<N>`** — currently `public let rawValue: Int`, with `init(_:) throws` and `init(__unchecked: Void, _ rawValue: Int)`. Migrate per Cardinal/Ordinal precedent: rename storage to `_storage: Int`, add `Axis+Carrier.swift` conformance with `Underlying = Int`, expose `underlying: Int { _read { yield _storage } }` and `init(_ underlying: consuming Int)`. Public-throwing `init(_:) throws(Error)` is the *checked* constructor and stays distinct from the conformance's bare `init(_:)`.
  - **Tension:** `Carrier.\`Protocol\`` requires a non-throwing `init(_ underlying: consuming Underlying)`. `Axis` already has `public init(_ rawValue: Int) throws(Error)`. Two same-shape inits collide. **Resolution (precedent):** the throwing checked `init` keeps the throws signature (overload set permits), and the carrier-derived `init(_:)` is the unchecked constructor. Per Cardinal/Ordinal where there is no throwing ctor at all, the conformance is the *only* `init(_:)`. Here we must keep the throwing one. Per Swift's overload resolution, `init(_ value: Int) throws(Error)` and `init(_ underlying: consuming Int)` differ on `throws` and `consuming` — Swift treats these as distinct, but call-sites `Axis(0)` will become ambiguous. **Decision:** drop the unchecked-via-`__unchecked` initializer and route the conformance through `init(_unchecked: ())` style? No — the precedent does NOT do that. Looking again at Cardinal: there is no throwing ctor; `Cardinal(_:)` is the only entrypoint. Looking at Axis use sites: `try Axis(value)` is the *checked* form; the unchecked form is `Axis(__unchecked: (), value)`.
  - **Final resolution:** rename the unchecked ctor to follow the new tagged convention, and DO NOT introduce a Carrier-protocol bare `init(_:)` that would shadow the throwing one. Instead, conform via the *protocol* with the typealias and `underlying`/`init` requirements satisfied by an *internal* unchecked-ctor wrapper. Concretely: Carrier's `init(_ underlying: consuming Int)` is satisfied by an internal init that `assert`s bounds in debug — but this collides with the public throwing `init(_:)` because protocol ctors are public. **Escalation candidate (Q4).** See Q4 for resolution.

- **`Interval.Unit`** — `public var rawValue: Scalar { _storage }` (already storage-based! good). Has `_storage: Scalar` directly. Migrate: rename `var rawValue` → `var underlying`. Drop the `_rawValue` deprecated alias (no `@available(*, deprecated, renamed: "rawValue")` migration backstops are kept in primitives — no backward-compat). Add a `Interval.Unit+Carrier.swift` conformance? The type is generic on `Scalar: BinaryFloatingPoint` — Carrier conformance must mirror that: `extension Interval.Unit: Carrier.\`Protocol\` where Scalar: BinaryFloatingPoint`. But `Interval` is generic on `Scalar`, and `Interval.Unit` is nested inside the floating-point branch via `extension Interval where Scalar: BinaryFloatingPoint`. The protocol's required `init(_ underlying: consuming Scalar)` would collide with the existing `init?(_ value: Scalar)` (failable) — same selector. **Escalation candidate (Q4).**

### No-Carrier files (unaffected)

- All other source files (`Coordinate.swift`, `Direction.swift`, `Spatial.swift`, `Chirality.swift`, `Winding.swift`, `Orientation.swift`, `Horizontal.swift`, `Vertical.swift`, `Depth.swift`, `Temporal.swift`, `Measure.swift`, `Displacement.swift`, `Extent.swift`, `Interval.swift`, `Angle.swift`, `Axis.{Direction,Horizontal,Vertical,Depth,Temporal}.swift`, `Dimension+Arithmetic.swift`, `Scale.swift`) — unchanged.

## Q2 — Do any new public APIs need to be introduced?

**No** new public-API additions are required by the Tagged-touching mechanical edits — they are pure rename.

**Yes (with caveat)** for Axis/Interval.Unit Carrier conformance — see Q4.

## Q3 — Are there cross-type compound-assignment cascades to drop?

The existing `Research/cross-type-compound-assignment-completeness.md` documents the package's compound-assignment surface; this rename cycle does not affect that surface (operator types are unchanged; only the underlying-value accessor name changes). No cascade-drop needed.

`.retag(...)` (used in `width`/`height`/`depth` helpers in Tagged+Arithmetic.swift) is a Tagged API. Whether it survives the upstream rename: confirmed alive in Tagged 46ded75 (still public on Tagged_Primitives). No edit needed beyond Underlying rename.

## Q4 — Forced API additions / escalation calls

### Axis: Carrier.`Protocol` conformance vs. throwing `init(_:)`

The `Carrier.\`Protocol\``-required `init(_ underlying: consuming Underlying)` is non-throwing. `Axis<N>` already has `public init(_ value: Int) throws(Error)`. Adding the carrier-derived ctor would shadow or ambiguate call sites.

**Three options:**

1. **Skip Carrier.`Protocol` conformance for `Axis<N>`.** Rename `rawValue` → `underlying` cosmetically (storage rename + property rename), but do NOT conform to `Carrier.\`Protocol\``. This keeps the throwing `init(_:)` unambiguous. Loses the `Carrier.\`Protocol\``-derived constants/operators, but `Axis` doesn't use any (it's not arithmetic-shaped).
2. **Conform `Axis<N>` to `Carrier.\`Protocol\``, drop the throwing `init(_:)`.** Replace with `static func make(_ value: Int) throws(Error) -> Self` or similar. **Breaking** beyond what this rename cycle authorizes. Class-(c) escalation.
3. **Conform `Axis<N>`, keep throwing `init(_:)`, accept call-site ambiguity.** Caller must disambiguate. Bad ergonomics.

**Recommendation: Option 1.** `Axis<N>` is not a Carrier-shape value (no arithmetic, no monoid, no need for cross-type lifts). The new convention is `underlying` for the accessor; we can adopt that name without claiming protocol conformance. This matches the precedent's *spirit* (public exposure via `underlying`) without forcing protocol conformance where it doesn't fit.

### Interval.Unit: Carrier.`Protocol` conformance vs. failable `init(_:)`

Same shape problem: protocol requires non-throwing, non-failable `init(_ underlying: consuming Scalar)`. `Interval.Unit` has `init?(_:)` (failable, bounds-checked). Cannot conform without breaking the failable ctor.

**Recommendation: Option 1 for Interval.Unit too.** Rename `rawValue` → `underlying`, drop the `_rawValue` deprecated alias, do NOT conform to `Carrier.\`Protocol\``. The unit-interval type is a *constrained* numeric — its construction is inherently failable. Carrier-of-floating-point would not give it useful operations beyond what it already has.

### Verdict

**Q4 escalations are RESOLVED at Option 1 for both types** — purely cosmetic rename of the public accessor (`rawValue` → `underlying`) with NO new protocol conformance. This matches the spirit of the upstream rename (Carrier-aware naming) while respecting that these two types do not match the Carrier-shape contract (which requires unconditional, non-throwing, non-failable construction from `Underlying`).

This decision means:
- Axis storage: `public let rawValue: Int` → `public let underlying: Int` (rename in place — no `_storage` introduction needed since the field is already public, and storage abstraction would only matter if Carrier conformance were added).
- Interval.Unit storage: keep `_storage: Scalar`, rename `var rawValue` → `var underlying`. Drop `_rawValue`.
- The `init(__unchecked: Void, ...)` patterns rename to `init(_unchecked: ...)` mechanically (matching new Tagged surface).

**No new public API. No protocol additions. No class-(c) escalation.**

## Verdict

**Proceed with Phase 2.** Mechanical patterns from the brief apply to all Tagged-touching files. Two own-field types (Axis, Interval.Unit) get cosmetic accessor renames only — no Carrier protocol conformance, per the analysis above.
