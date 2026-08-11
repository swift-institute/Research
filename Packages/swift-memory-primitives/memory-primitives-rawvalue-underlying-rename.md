# Memory Primitives — Tier 12 Migration: `rawValue` → `underlying`, `Carrier` → `Carrier.\`Protocol\``

**Date:** 2026-05-03
**Scope:** Cascade-drop migration following swift-tagged-primitives `46ded75`, swift-carrier-primitives `2b57aac`, and the cardinal/ordinal/vector own-field rename precedent (`ac7f308` / `e42df9f` / `84f93bc`).

## Phase 1 — Design Audit

### Q1. Own `public let rawValue` types? (Pre-authorized for rename.)

Inventory of struct types declared in this package with own-field storage named `rawValue`:

| Type | Storage shape | Verdict |
|------|---------------|---------|
| `Memory.Address` | `typealias = Tagged<Memory, Ordinal>` — no own field | n/a (Tagged-derived) |
| `Memory.Address.Count` | `Tagged<Memory, Cardinal>` (via Ordinal.Protocol.Count) | n/a (Tagged-derived) |
| `Memory.Shift` | `public let rawValue: UInt8`, invariant `0...63` | **Leave as-is**: stdlib-style invariant-bearing struct. The `Carrier.\`Protocol\`` conformance is on `Cardinal` (computed `underlying: Cardinal { Cardinal(UInt(rawValue)) }`), not on the raw `UInt8`. Renaming the internal `UInt8` field would require migrating callers that read `shift.rawValue` for cross-bit-width validation logic without producing a corresponding API improvement. The brief authors explicitly flag this as "audit but probably leave." |
| `Memory.Alignment` | `public let shift: Memory.Shift` (no field named rawValue) | n/a |
| `Memory.Map.Region` | `public let base: Memory.Address; public let length: Memory.Address.Count` | n/a |
| `Memory.Map.Options` | `public let rawValue: Int32` — `OptionSet` | **MUST NOT rename** (stdlib `OptionSet` requirement). |
| `Memory.Map.Advice` | `public let rawValue: Int32` — `RawRepresentable`-ish | **MUST NOT rename** (stdlib `RawRepresentable` ergonomics). |
| `Memory.Map.Access` | `public let rawValue: Int` — same | **MUST NOT rename**. |
| `Memory.Map.Protection` | `public let rawValue: Int32` — `OptionSet` | **MUST NOT rename**. |
| `Memory.Buffer` | n/a (no rawValue field) | n/a (comment update only) |

**Decision**: No own-field rename applied in this tier. All renames are mechanical cascades from the upstream Tagged/Carrier rename plus follow-on consequences in the consumers reading Cardinal's renamed `underlying`.

### Q2. Editorial public surface that could move to a sibling target / SLI?

None surfaces in this audit. The package is already split across:
- `Memory Namespace`
- `Memory Primitives Core`
- `Memory Primitives Standard Library Integration` (already an SLI)
- `Memory Buffer Primitives`, `Memory Arena Primitives`, `Memory Pool Primitives`

The pointer interop (`UnsafeRawPointer.init(_:)`, `mutablePointer` accessor) belongs in the SLI target, and indeed lives in `Sources/Memory Primitives Core/Memory.Address.swift` — that is a possible future relocation. Out-of-scope for this rename tier.

**No escalation.**

### Q3. Three-consumer rule

Each visible primitive in this package is consumed by ≥3 downstream packages (memory addresses, alignment, regions, buffers, pools, arenas all flow into pointer-primitives, slab-primitives, allocator-primitives, kernel/IO primitives, foundations file/buffer packages). No tier-12 candidates for promotion or demotion.

**No escalation.**

### Q4. Compound identifiers / `*Tag` suffixes / code-surface violations

Quick scan:
- `Memory.Map.Options`, `Memory.Map.Protection` — `.Options`/`.Protection` are noun nests, not compound. ✓
- `Memory.Alignment.Align` — namespace `Align` enum hosts `.up`/`.down` as nested accessors. ✓
- No `*Tag` suffix usage anywhere in this package's own type declarations.
- `Memory.Inline ~Copyable.swift` — file naming is unusual but pre-existing; not a code-surface violation.

**No escalation.**

## Phase 1 Verdict

**Proceed to Phase 2 mechanical rename.** Q2/Q3/Q4 produce no non-trivial recommendations; Q1 confirms no own-field renames apply (Memory.Shift's `rawValue: UInt8` is left as a stdlib-style invariant field per the brief's "probably leave" guidance).

## Phase 2 — Files to touch

### Sources

- `Sources/Memory Primitives Core/Memory.Address.swift`
  - 4 × `extension Tagged where Tag == Memory, RawValue == Ordinal` → `Underlying == Ordinal`
  - 1 × `init(__unchecked: (), Ordinal(...))` → `init(_unchecked: (), Ordinal(...))`
  - 2 × `address.rawValue` → `address.underlying` (in UnsafeRawPointer/Mutable inits)
  - 1 × `bitPattern` accessor reads `rawValue.rawValue` (Tagged.rawValue then Ordinal.rawValue): `rawValue.rawValue` → `underlying.underlying` (Tagged → Ordinal → UInt). _Verified Ordinal storage rename_ post-`e42df9f`.
- `Sources/Memory Primitives Core/Memory.Address.Error.swift`
  - 1 × `RawValue == Ordinal` → `Underlying == Ordinal`
- `Sources/Memory Primitives Core/Memory.Shift+Cardinal.Protocol.swift`
  - `extension Memory.Shift: Carrier` → `extension Memory.Shift: Carrier.\`Protocol\``
  - `underlying.rawValue` (read on Cardinal) → `underlying.underlying` (Cardinal post-rename)
- `Sources/Memory Primitives Core/Memory.Alignment.Align.swift`
  - 2 × `<C: Carrier<Cardinal>>` → `<C: Carrier.\`Protocol\`<Cardinal>>`
  - 2 × `value.cardinal.rawValue` → `value.cardinal.underlying` (Cardinal post-rename)
- `Sources/Memory Primitives Core/Memory.Map.Region.swift`
  - `length.rawValue` (Tagged) → `length.underlying.underlying` (Tagged → Cardinal → UInt for bitPattern)
- `Sources/Memory Primitives Core/Memory.Page.swift`
  - `pageSize.rawValue.rawValue` (Tagged → Cardinal → UInt) → `pageSize.underlying.underlying`
- 6 × `Sources/Memory Primitives Standard Library Integration/Memory+Unsafe*Pointer*.swift`
  - `offset.vector.rawValue` (Tagged) → `offset.vector.underlying.underlying` (Tagged → Cardinal → Int/UInt)

  _Note_: `offset.vector` returns the underlying Tagged (e.g., `Tagged<Memory, Affine.Vector<...>>`). The accessor needs investigation at build time; mechanical replace `.rawValue` → `.underlying` chain may need additional step.
- `Sources/Memory Buffer Primitives/Memory.Buffer.swift`
  - Comment: `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`

### Tests

- `Tests/Memory Arena Primitives Tests/Memory.Arena Tests.swift` (×9): `arena.capacity.rawValue` (Tagged) → `arena.capacity.underlying` (Cardinal). Comparing `Cardinal == 1024` works iff Cardinal is `ExpressibleByIntegerLiteral` (it is, post `ac7f308`).
- `Tests/Memory Primitives Tests/Memory Arithmetic Tests.swift` (×~14): `.rawValue.rawValue` → `.underlying.underlying`
- `Tests/Testing/Tests/Memory Alignment Performance Tests/Memory.Alignment Performance Tests.swift` (×3): `alignment.align.up(Cardinal(i)).rawValue` → `.underlying` (Cardinal → UInt)

### Files NOT to touch

- `Memory.Shift.swift` — uses `Carrier` as a *local generic param name* (`<Carrier: FixedWidthInteger>`); these references must stay.
- `Memory.Alignment.swift` — same (`<Carrier: FixedWidthInteger>`).
- `Memory.Map.Options.swift` / `Memory.Map.Advice.swift` / `Memory.Map.Access.swift` / `Memory.Map.Protection.swift` — stdlib `OptionSet`/`RawRepresentable` raw value contracts — must keep `init(rawValue:)` and `rawValue` field.

## Open Questions

None. Proceeding to Phase 2.
