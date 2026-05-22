# swift-primitives Triage for Agent-Witness-Attachable Pattern

**Companion to**: `agent-witness-attachable-pattern.md`
**Date**: 2026-05-22
**Total packages surveyed**: 175

## Categories

- **A — Pattern host (codec-shaped, agent-named)**: primary targets for applying the triple
- **B — Codec-shaped, needs renaming**: would become A after a rename
- **C — Attachable consumer (value-domain)**: conforms to Parseable / Serializable / etc.; not a pattern host
- **D — Not a candidate**: storage / layout / algebraic / runtime infrastructure

## Counts (after adjustments)

| Category | Count |
|---|---|
| A (pattern host) | 13 |
| B (rename → A) | 1 |
| C (attachable consumer) | 20 |
| D (not a candidate) | 141 |

## Category A — Pattern Host (13)

### Primary agents

| Package | Notes |
|---|---|
| swift-parser-primitives | Largest surface; partial implementation in flight as of 2026-05-22 (Pair conformance landed, witness still nested as `Parser.Witness`). |
| swift-serializer-primitives | Paired with parser; less mature combinator surface. |
| swift-coder-primitives | Leaf agent (no Body/Builder). Inverse-of-parser-and-serializer unification type. |
| swift-formatter-primitives | Protocol-only currently; needs witness promotion + attachable. |
| swift-lexer-primitives | Agent-shaped, needs formal `Lexer.\`Protocol\``. |
| swift-render-primitives | Builder-based; needs formal `Renderer.\`Protocol\``. |
| swift-render-async-primitives | Async variant of render. |
| swift-transform-primitives | Verify shape before committing — name is generic; might be umbrella or actual agent. |
| swift-sequencer-primitives | **Renamed from swift-sequence-primitives.** Biggest payoff: replaces stdlib's compound-name proliferation. |

### Specialized agents (inherit pattern from primaries)

| Package | Inherits from |
|---|---|
| swift-binary-parser-primitives | swift-parser-primitives |
| swift-binary-serializer-primitives | swift-serializer-primitives |
| swift-binary-coder-primitives | swift-coder-primitives |
| swift-byte-parser-primitives | swift-parser-primitives |
| swift-byte-serializer-primitives | swift-serializer-primitives |
| swift-ascii-parser-primitives | swift-parser-primitives |
| swift-ascii-serializer-primitives | swift-serializer-primitives |

(Specialized variants are not independent pilots — they follow the primary's pattern.)

## Category B — Rename → A (1)

| Package | Suggested rename | Reason |
|---|---|---|
| swift-sequence-primitives | **swift-sequencer-primitives** | Agent name needs verb-er form. After rename: `Sequencer.\`Protocol\``, `Sequence<E>` witness, `Sequenceable` attachable. Replaces stdlib's compound identifier pile (AnySequence, IteratorProtocol, LazySequence, …). |

## Category C — Attachable Consumer (20)

Value-domain types that would conform to Parseable / Serializable / Formattable / etc. Not pattern hosts.

| Package | Likely attachables |
|---|---|
| swift-abstract-syntax-tree-primitives | Parseable, Serializable |
| swift-argument-primitives | Parseable, Serializable |
| swift-ascii-primitives | Parseable, Serializable |
| swift-complex-primitives | Parseable, Serializable, Formattable |
| swift-decimal-primitives | Parseable, Serializable, Formattable |
| swift-diagnostic-primitives | Serializable, Formattable |
| swift-error-primitives | Formattable |
| swift-format-primitives | Formattable consumer (format value type) |
| swift-glob-primitives | Parseable (Glob.Pattern already has this) |
| swift-locale-primitives | Parseable, Formattable |
| swift-outcome-primitives | Serializable |
| swift-path-primitives | Parseable, Serializable, Formattable |
| swift-predicate-primitives | Serializable, Formattable |
| swift-source-primitives | Parseable, Serializable |
| swift-string-primitives | Parseable, Serializable, Formattable |
| swift-structured-queries-primitives | Parseable, Serializable, Formattable |
| swift-symbol-primitives | Parseable, Serializable |
| swift-text-primitives | Parseable, Serializable, Formattable |
| swift-time-primitives | Parseable, Serializable, Formattable |
| swift-token-primitives | Parseable, Serializable (consumed by Lexer) |
| swift-version-primitives | Parseable, Serializable, Formattable |

## Category D — Not a Candidate (141)

Grouped by sub-domain for legibility. These are storage / layout / algebraic / runtime infrastructure — no codec-triple analogue.

### Storage / containers (32)
swift-array-primitives, swift-bit-vector-primitives, swift-bitset-primitives, swift-buffer-primitives, swift-cache-primitives, swift-collection-primitives, swift-dictionary-primitives, swift-finite-primitives, swift-graph-primitives, swift-hash-table-primitives, swift-heap-primitives, swift-infinite-primitives, swift-list-primitives, swift-matrix-primitives, swift-memory-arena-primitives, swift-memory-buffer-primitives, swift-memory-pool-primitives, swift-memory-shared-primitives, swift-pool-primitives, swift-queue-primitives, swift-region-primitives, swift-sample-primitives, swift-set-primitives, swift-slab-primitives, swift-slice-primitives, swift-stack-primitives, swift-storage-primitives, swift-tensor-primitives, swift-tree-primitives, swift-vector-primitives, swift-bit-pack-primitives, swift-bitset-primitives

### Cursor / view / navigation (5)
swift-binary-cursor-primitives, swift-byte-cursor-primitives, swift-cursor-primitives, swift-memory-cursor-primitives, swift-slice-primitives

### Memory / layout (7)
swift-layout-primitives, swift-memory-primitives, swift-memory-lock-primitives, swift-memory-map-primitives, swift-bit-primitives, swift-byte-primitives, swift-binary-base-primitives

### Algebra / functional (20)
swift-affine-geometry-primitives, swift-affine-primitives, swift-algebra-affine-primitives, swift-algebra-cardinal-primitives, swift-algebra-field-primitives, swift-algebra-group-primitives, swift-algebra-law-primitives, swift-algebra-linear-primitives, swift-algebra-magma-primitives, swift-algebra-modular-primitives, swift-algebra-module-primitives, swift-algebra-monoid-primitives, swift-algebra-primitives, swift-algebra-ring-primitives, swift-algebra-semigroup-primitives, swift-algebra-semilattice-primitives, swift-algebra-semiring-primitives, swift-bifunctor-primitives, swift-coproduct-primitives, swift-optic-primitives

### Composition primitives (used BY the pattern)
swift-either-primitives, swift-pair-primitives, swift-product-primitives

These are D in the sense of "not pattern hosts," but they're the *shape primitives* the pattern composes against. Worth a one-line note: every Category A package will likely add conformances against these.

### Numeric / type infrastructure (8)
swift-cardinal-primitives, swift-index-primitives, swift-numeric-primitives, swift-ordinal-primitives, swift-scalar-primitives, swift-cyclic-index-primitives, swift-cyclic-primitives, swift-range-primitives

### Algebraic structure / comparison / equation (6)
swift-comparison-primitives, swift-dimension-primitives, swift-equation-primitives, swift-logic-primitives, swift-order-primitives, swift-symmetry-primitives

### Runtime / IO / system (16)
swift-async-primitives, swift-backend-primitives, swift-clock-primitives, swift-continuation-primitives, swift-cpu-primitives, swift-dependency-primitives, swift-driver-primitives, swift-effect-primitives, swift-endian-primitives, swift-executor-primitives, swift-input-primitives, swift-io-primitives, swift-machine-primitives, swift-network-primitives, swift-observation-primitives, swift-system-primitives

### Loader / link / package / module (5)
swift-link-primitives, swift-loader-primitives, swift-manifest-primitives, swift-module-primitives, swift-package-primitives

### Tooling / linting / IR / syntax (5)
swift-intermediate-representation-primitives, swift-linter-primitives, swift-primitives-linter-rules, swift-syntax-primitives, swift-witness-primitives

### Reflection / type / property / position / reference (8)
swift-abi-primitives, swift-binary-format-primitives, swift-carrier-primitives, swift-position-primitives, swift-property-primitives, swift-reference-primitives, swift-tagged-primitives, swift-type-primitives

### Misc infrastructure (7)
swift-binary-leb128-primitives, swift-binary-primitives, swift-bit-index-primitives, swift-geometry-primitives, swift-hash-primitives, swift-ownership-primitives, swift-random-primitives, swift-space-primitives, swift-standard-library-extensions, swift-terminal-primitives, swift-terminal-input-primitives, swift-test-primitives

### Documentation / non-package
swift-primitives.org

## Recommended Pilot Order

**Chosen pilot (2026-05-22): swift-formatter-primitives.** Sequencer has higher leverage but a larger downstream dependency tail; piloting on formatter keeps the blast radius bounded while exercising the full pattern (witness promotion, attachable, Pair conformance, parity tests). Sequencer follows after the pilot has shaken out the migration playbook.

Order:

1. **swift-formatter-primitives** (Category A) — **PILOT**. Moderate scope; protocol already exists; needs witness promotion + attachable verification + Pair conformance + parity tests. Bounded downstream impact.
2. **swift-sequencer-primitives** (Category B → A after rename) — second wave. Highest leverage; replaces stdlib's compound-name explosion. Applied after the pilot validates the playbook.
3. **swift-lexer-primitives** (Category A) — confirms the pattern outside parser/serializer.
4. **swift-render-primitives** (Category A) — exercises the builder-pattern dimension of the triple.

Not for pilot:
- swift-parser-primitives — already in flight.
- swift-coder-primitives — leaf, no combinator surface to exercise.
- Specialized variants — inherit from primaries; not standalone pilots.

## Borderline Classifications Worth Principal Review

| Package | Current | Alternative | Question |
|---|---|---|---|
| swift-linter-primitives | D | A (validator-shaped) | If the pattern extends to validation (Validator agent + Validate witness + Validatable attachable), this becomes A. Under strict codec-shape, D. |
| swift-transform-primitives | A | D or umbrella | "Transform" is generic; verify shape before committing. |
| swift-witness-primitives | D | meta | This is infrastructure FOR witness types broadly, not a codec agent itself. Stays D, but worth flagging — it might be relevant if the pattern needs shared witness machinery. |
| swift-render-async-primitives | A | sub-A | If render-async is a variant of render (parallel target structure), it inherits the pattern from render-primitives rather than being a standalone pilot. |

## Source

Survey conducted 2026-05-22 by listing `/Users/coen/Developer/swift-primitives/` and applying the Category A/B/C/D framework defined in `agent-witness-attachable-pattern.md`. Primary classification done by package name + brief Sources/ inspection where ambiguous. Adjustments to the initial automated classification documented above.
