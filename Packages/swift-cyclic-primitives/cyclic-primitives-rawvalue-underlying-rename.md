# cyclic-primitives — rawValue → underlying rename design audit

**Date:** 2026-05-03
**Tier:** 7a (downstream consumer of comparison/hash/ordinal/cardinal/sequence; transitive on tagged-primitives, carrier-primitives)
**Scope:** swift-cyclic-primitives only — propagate the canonical renames from
`carrier-primitives 2b57aac` (`Carrier` → namespace enum + `Carrier.\`Protocol\``,
`raw` → `underlying`) and `tagged-primitives 46ded75` (`RawValue` → `Underlying`,
`.rawValue` → `.underlying`, `init(rawValue:)` → `init(_:)`,
`init(_unchecked: ())` → `init(_unchecked:)`).

## Q1 — Own `public let rawValue` types? (pre-authorized for rename)

**No.** Grep across `Sources` and `Tests` reveals zero own-field `public let rawValue`
or `public var rawValue` declarations. The package's three `public let` storage
fields use domain names that already mirror their semantic role:

| Type | Storage field | Semantic role |
|------|--------------|---------------|
| `Cyclic.Group.Element` | `public let residue: Ordinal` | residue in `[0, modulus)` |
| `Cyclic.Group.Static<N>.Element` | `public let position: Ordinal` | position in `[0, modulus)` |
| `Cyclic.Group.Modulus` | `public let value: Cardinal` | the positive modulus |

These names are deliberate: they encode the algebraic role of the wrapped
ordinal/cardinal, not a generic "rawValue" passthrough. They survived the
cardinal/ordinal precedent because cyclic group elements *are not* simple
Carrier wrappers — they have nontrivial invariants (`< modulus`, `> 0`). The
cardinal/ordinal `_storage` precedent does not apply.

**No own-field rename needed in this package.**

## Q2 — Editorial public surface

Nothing surfaces beyond the established conventions:
- All public types live under `Cyclic.Group.*` (no compound identifiers).
- No top-level free functions; all algebra is `static` on the group / element types
  or instance methods (e.g., `inverse`).
- `exports.swift` only re-exports the five direct deps. No editorial passthrough.
- `Tests/Support/Cyclic.Group.Static.Element+Literals.swift` (single test-support
  conformance) is already isolated as a separate library product
  (`Cyclic Primitives Test Support`) — the SLI sibling-target carve-out is
  already in place.

**Verdict:** no editorial moves needed. Layout already matches conventions.

## Q3 — Three-consumer rule

All five direct deps (`comparison`, `hash`, `ordinal`, `cardinal`, `sequence`)
are imported with at least three distinct consumption sites in `Sources`:

- `Ordinal` — used in `Group.Element.residue`, `Group.Static.Element.position`,
  `Group.Static.Element+Ordinal`, multiple arithmetic sites, and
  `Group.Static.Iterator`.
- `Cardinal` — `Group.Modulus.value`, `Group.Static.modulusCardinal`,
  arithmetic-saturation sites in both `+Arithmetic` files,
  `Group.Static.Iterator.bound`.
- `Comparison_Primitives` / `Hash_Primitives` — `Cyclic.Group.Static.Element`
  conforms to `Equation.\`Protocol\``, `Comparison.\`Protocol\``,
  `Hash.\`Protocol\`` in `Cyclic.Group.Static+Protocol.swift`.
- `Sequence_Primitives` — `Cyclic.Group.Static` conforms to
  `Sequence.\`Protocol\`` and `Iterator: Sequence.Iterator.\`Protocol\``.

Tagged_Primitives is currently used by exactly one extension file
(`Tagged+Cyclic.Group.Static.Element.swift`). However, this file delivers four
distinct convenience overloads (`init(_:)`, `init(_:)throws`, `init(wrapping:)`,
arithmetic operators, `inverse`) — collectively the only ergonomic way to use
the static cyclic group as a `Tagged` underlying. It is a leaf-level public
SLI-style overlay over a single core type. Per ecosystem precedent (Tagged
overlays count as an editorial layer for their host type), this is a legitimate
tier-7a placement, not a three-consumer violation. **No escalation.**

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

Scanned all public surface (`Sources/Cyclic Primitives/*.swift`) — none.

- All identifiers are nested-namespace form: `Cyclic.Group.Element`,
  `Cyclic.Group.Static.Element`, `Cyclic.Group.Modulus`, etc.
- No `*Tag` suffixes anywhere (the only `Tag:` usage is the standard
  `Tag: ~Copyable` generic parameter on `Tagged` extensions).
- One internal abbreviation: `inv` (local var in inverse computations)
  — local, not API surface.
- Property names (`residue`, `position`, `value`, `modulus`, `current`,
  `bound`) are simple lowercase identifiers — no compound names.

**No code-surface violations.**

## Verdict

All four questions resolve cleanly. **No escalation required.** Proceed to
Phase 2 (mechanical rename only).

The mechanical renames in this package reduce to:

1. `Tagged+Cyclic.Group.Static.Element.swift` — three `Self(__unchecked: (), …)`
   construction sites (and three `lhs.rawValue` / `rhs.rawValue` reads) →
   replace with `Self(_unchecked: …)` and `.underlying`.
2. `RawValue == Cyclic.Group.Static<N>.Element` where-clauses (eight call-sites)
   → `Underlying == Cyclic.Group.Static<N>.Element`.
3. `Cyclic.Group.Modulus.swift` — `count.rawValue` (Index.Count's own-field
   `rawValue`, two sites) → `count.underlying` (assuming Index.Count was
   renamed in tier-6 ordinal/cardinal cycle; verify against build).
4. `Cyclic.Group+Arithmetic.swift` line 125 — `offset.vector.rawValue.magnitude`
   → `offset.vector.underlying.magnitude`. Verify `Vector`'s rename landed.
5. `Cyclic.Group.Static.swift` line 95 — `position.rawValue` (Ordinal own-field)
   → `position.underlying`. Verify Ordinal rename landed.
6. `__unchecked` (double-underscore, label `__unchecked:`) on
   `Cyclic.Group.Element`, `Cyclic.Group.Static.Element`, `Cyclic.Group.Modulus`
   own initializers — these are this package's private "bypass" inits, not
   Tagged's. **They are NOT subject to the Tagged rename.** Decision: leave as
   `__unchecked:` (double-underscore) for now — they are local conventions, not
   the upstream Tagged init label. Revisit only if a code-surface skill rule
   is added that bans `__` prefix labels generally.

The Tagged file's commented-out lines 16-30 (zero / one helpers) reference the
old `RawValue ==` form; update those too for consistency, even though commented
out, so they remain accurate if uncommented later.

## Open questions

None.
