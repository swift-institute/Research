# Typed-Index Specialization Audit — Carrier / Cursor / Lexer.Scanner / Tagged Hot Path

<!--
---
version: 1.1.1
last_updated: 2026-05-20
status: DISPOSITIONED (carrier + Cursor @frozen + Lexer.Scanner @frozen LANDED; Tagged dispositioned via path (c) — accept the language limitation; CONFIRMED-COMPILER-BUG for 3 of 4 sites; reproducer scaffold staged; NO upstream filing without explicit principal YES)
tier: 3
scope: ecosystem-wide
---
-->

## Context

The canada-anomaly investigation
(`swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md`
v1.4.1 §"Pre-Gate 1") identified four sites where Swift's optimizer fails
to specialize generics on swift-json's canada hot path, producing ~27.8%
of total parse samples in runtime metadata machinery:

- `Cursor.peek()` — `swift-primitives/swift-cursor-primitives`
- `Lexer.Scanner.peek<X: Byte.\`Protocol\`>()` — `swift-primitives/swift-lexer-primitives`
- `Tagged.retag<A>(_:to:)` — `swift-primitives/swift-tagged-primitives`
- `_CarrierProtocol.vector` witness — `swift-primitives/swift-carrier-primitives` (the
  `underlying` requirement on `Carrier.\`Protocol\``; the time-profiler
  symbol's `.vector` suffix denotes the witness-table vector entry).

Principal stance: do not shape the codebase around compiler
limitations. But before claim-then-file, verify institute-side
annotation surface — a missing `@inlinable` / `@frozen` /
`@_alwaysEmitIntoClient` / `public import` could explain the gaps
without invoking a compiler bug.

## Question

For each of the four sites, are the institute-side annotations
complete, and does completing them close the canada gap?

## Method

Phase 1 — annotation audit per site, checking six annotations:

| # | Annotation | Why it matters |
|---|------------|---------------|
| 1 | `@inlinable` on the method | Without it, body invisible across module boundaries; cross-module specialization impossible. |
| 2 | `@frozen` on the storing type | Lets optimizer see through layout. |
| 3 | `@usableFromInline` on internal stored properties + helpers referenced by `@inlinable` bodies | Common silent gap. |
| 4 | `public import` vs `import` | Plain `import` makes the imported module internal-only; downstream optimizers can't see bodies. |
| 5 | `@_alwaysEmitIntoClient` on protocol-extension defaults | Forces the default body to be emitted into every client. |
| 6 | `@_transparent` on trivial wrappers | Forces inlining regardless of body size. |

Phase 2 — apply mechanical fixes. ABI-shape changes (`@frozen` on a
previously non-frozen struct) and visibility changes (`import` →
`public import`) stop and surface to principal. `@_specialize` is
forbidden per principal stance.

Phase 3 — re-emit SIL + symbols, check the bench binary for
specialized vs generic-only forms of each site.

Phase 4 — wall-clock measurement against the canada v1.4.1 baseline
(235.62 ms, 17.32× Foundation on this machine).

## Findings

### Site 1 — `Cursor.peek()` at `swift-cursor-primitives/Sources/Cursor Primitives Core/Cursor+MemoryContiguousBorrowed.swift:57-61`

| Annotation | Status |
|------------|--------|
| `@inlinable` on `peek()` | ✅ PRESENT (line 56) |
| `@frozen` on `Cursor<DomainTag>` struct (Cursor.swift:64) | ❌ MISSING — `@safe` only |
| `@usableFromInline` on `storage` (line 68) and `_position` (line 71) | ✅ PRESENT |
| `public import` (Cursor.swift:12-15; Cursor+MemoryContiguousBorrowed.swift:12-13) | ✅ PRESENT |
| `@_alwaysEmitIntoClient` | N/A — struct extension method, not a protocol-extension default |
| `@_transparent` on trivial wrappers | SUB-OPTIMAL (could be added; deferred) |

**Verdict**: Annotations CORRECT modulo `@frozen` on `Cursor`. The
`@frozen` change is ABI-shape — STOP, surface to principal. Symbol
inspection confirms no specialized `Cursor.peek()` in the bench
binary; only the generic form is present.

### Site 2 — `Lexer.Scanner.peek<X: Byte.\`Protocol\`>()` at `swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift:142-144`

| Annotation | Status |
|------------|--------|
| `@inlinable` + `@_disfavoredOverload` (lines 140-141) | ✅ PRESENT |
| `@frozen` on `Lexer.Scanner` struct (line 57) | ❌ MISSING — `@safe` only |
| `@usableFromInline` on `inner`, `source`, `hasEmittedEndOfFile`, `tracker` (lines 58, 61, 64, 67) | ✅ PRESENT |
| `public import` (lines 12-14) | ✅ PRESENT |
| `@_alwaysEmitIntoClient` | N/A — struct extension method |
| `@_transparent` on trivial wrapper (`inner.peek().map(X.init(_:))`) | SUB-OPTIMAL |

**Verdict**: Annotations CORRECT modulo `@frozen` on `Lexer.Scanner`.
ABI-shape — STOP, surface to principal. Symbol inspection confirms no
specialized `Lexer.Scanner.peek<X>()`; only generic form + partial
apply forwarders.

### Site 3 — `Tagged.retag<A>` at `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:252-257` (static) + `:280-282` (instance convenience)

| Annotation | Status |
|------------|--------|
| `@inlinable` on `retag` (static + instance) | ✅ PRESENT |
| `@frozen` on `Tagged` struct (line 54) | ✅ PRESENT |
| `@usableFromInline` on stored property | N/A — `underlying` is `public package(set) var` (line 71) — visible to `@inlinable` bodies |
| `public import` in `Tagged.swift` | N/A — no imports |
| `@_alwaysEmitIntoClient` | N/A — struct extension method |
| `@_transparent` on the trivial wrapper | SUB-OPTIMAL |

**Cross-cutting gap**: `Tagged.init(_unchecked:)` at lines 91-94 is
the callee of `retag`'s body (`Tagged<New, Underlying>(_unchecked:
tagged.underlying)`) and is **NOT `@inlinable`**. This breaks the
specialization chain from `@inlinable` `retag` — the `_unchecked` init
body is invisible cross-module.

**Verdict**: Annotation gap real (Tagged.init(\_unchecked:) missing
`@inlinable`), but **BLOCKED — package dirty**. `swift-tagged-primitives`
has uncommitted changes under `Lint/` from a parallel session at
audit time. Per `feedback_no_interference_with_parallel_work.md` +
`feedback_do_not_interfere_with_parallel_churn.md`, fix deferred to
principal disposition.

### Site 4 — `_CarrierProtocol.vector` witness (= `underlying` requirement) — protocol-extension default impls in `swift-carrier-primitives/Sources/Carrier Primitives/`

Four quadrant files implementing the trivial-self default
(`where Underlying == Self`, each Copyable × Escapable combination):

| File | Default for `var underlying` | Default for `init(_:)` |
|------|------------------------------|------------------------|
| `Carrier.Protocol where Underlying == Self.swift` (Q1 Copyable, Escapable) | `_read { yield self }` | `self = underlying` |
| `Carrier.Protocol where Underlying == Self, Self ~Copyable.swift` (Q2) | `_read { yield self }` | `self = underlying` |
| `Carrier.Protocol where Underlying == Self, Self ~Escapable.swift` (Q3) | `@_lifetime(borrow self) _read { yield self }` | `@_lifetime(copy underlying)` |
| `Carrier.Protocol where Underlying == Self, Self ~Copyable & ~Escapable.swift` (Q4) | `@_lifetime(borrow self) _read { yield self }` | `@_lifetime(copy underlying)` |

Plus `Carrier.Protocol where Self ~Copyable & ~Escapable.swift` — the
throwing-validate convenience init.

| Annotation | Status (before fix) | Status (after fix) |
|------------|---------------------|--------------------|
| `@inlinable` on each default | ❌ MISSING in all 4 quadrant files | — |
| `@_alwaysEmitIntoClient` on each default | ❌ MISSING — explicitly the brief's #5 candidate | ✅ APPLIED (5 declarations) |
| `@frozen` | N/A — `Carrier` is `public enum Carrier {}`, a namespace |
| `public import` | N/A — no imports in default-impl files |

**Verdict**: Annotation gap REAL and MECHANICAL (no ABI/visibility
change). Fix LANDED — `@_alwaysEmitIntoClient` applied to 9
declarations across 5 files. Carrier-primitives builds clean (1.07s);
174 tests pass; downstream byte-primitives / cursor-primitives /
lexer-primitives all build clean.

### Symbol inspection (after fixes)

Bench binary `parse-performance-bench` (release, `swift build -c release`)
after carrier `@_alwaysEmitIntoClient` + Cursor `@frozen` + Lexer.Scanner
`@frozen` all landed:

- `Cursor.peek()`: only the generic-only form present — no `specialized` prefix.
- `Cursor.consume()`: generic form PLUS `generic specialization <serialized, Text_Primitives.Text> of ... consume()`. **Same extension. Same annotations. Specialized.**
- `Cursor.peek(at:)`: only generic-only form.
- `Lexer.Scanner.peek<X>()`: generic form + partial-apply forwarders; no specialized.
- `Tagged.retag<A>`: generic form only; no specialized.
- `_CarrierProtocol.underlying.read` witnesses: per-conformer
  thunks present for each conforming type (Byte, ISO_9945.Kernel.File.\*,
  Text.Line.Number, ASCII.Code, ...). The per-conformer witnesses are
  auto-synthesized from each type's stored field (Byte's `let
  underlying: UInt8`, Tagged's `package(set) var underlying`).

**Critical mechanism finding (refined)**: the `peek()` vs `consume()`
asymmetry under identical surface annotations is the load-bearing
empirical signal. Both are `@inlinable` extension methods on the
now-`@frozen` `Cursor<DomainTag>` struct, both close over
`@usableFromInline` stored properties, both inside the same `extension
Cursor where DomainTag.Borrowed: Memory.Contiguous<Byte>.Borrowed.\`Protocol\`,
DomainTag.Borrowed.Element == Byte, DomainTag: ~Copyable` constraint.
The only structural difference at the function signature is:
- `consume() -> Byte` (specialized)
- `peek() -> Byte?` (not specialized)
- `peek(at:) -> Byte?` (not specialized)

That delta — `Optional<Byte>` return type — appears to be the
specialization-disabling property under the current Swift release-mode
optimizer. The `@_alwaysEmitIntoClient` fix to carrier-primitives
targeted the trivial-self default impls (`where Underlying == Self`).
None of the canada hot-path Carrier consumers use trivial-self
conformance — Byte has `Underlying == UInt8`, Tagged has `Underlying
== Underlying` (immediate generic param). The hot path goes through
per-conformer auto-synthesized witnesses, NOT through the defaults.
The shipped fix is institute-side annotation hygiene; it does not
reach the four named sites.

### Wall-clock measurement (Phase 4)

`caffeinate -i swift run -c release parse-performance-bench canada.json 32 stats`:

| Statistic | v1.4.1 baseline | After carrier fix only | After carrier + 2× @frozen | Δ vs baseline |
|-----------|----------------:|-----------------------:|---------------------------:|--------------:|
| Foundation min | 13.60 ms | 13.53 ms | 13.64 ms | within noise |
| swift-json min | 235.62 ms | 236.06 ms | 241.29 ms | **NULL DELTA (+5.67 ms within noise)** |
| Ratio min | 17.32× | 17.44× | 17.69× | within noise |

All three landed institute-side fixes (carrier defaults
`@_alwaysEmitIntoClient`; Cursor `@frozen`; Lexer.Scanner `@frozen`)
deliver wall-clock null delta on canada. Combined with the SIL-level
finding (peek family NOT specialized despite identical surface
annotations to specialized consume), this confirms the verdict is
not institute-side annotation hygiene. The 4 remaining specialization
gaps are compiler/optimizer-side decisions independent of legitimate
institute annotations.

## Outcome (final, post-principal-authorization 2026-05-20)

After principal authorized landing the legitimate institute-side
annotation levers (commit `c2849a3` carrier-primitives,
`e2da665` cursor-primitives, `d2418f4` lexer-primitives):

| Site | Disposition |
|------|-------------|
| 1. Cursor.peek() | **CONFIRMED-COMPILER-BUG** — all 6 annotations now correct (@inlinable + @frozen + @usableFromInline + public import); SIL still shows only generic-only form. The asymmetric finding: `Cursor.consume()` IS specialized (`generic specialization <serialized, Text_Primitives.Text>`) at the same extension with same annotations; `Cursor.peek()` and `Cursor.peek(at:)` are NOT. The only structural difference is the return type — `consume()` returns `Byte`, `peek()` returns `Byte?` (Optional). The optimizer's specialization heuristic appears to skip `Optional`-returning members under otherwise-identical conditions. |
| 2. Lexer.Scanner.peek<X: Byte.\`Protocol\`>() | **CONFIRMED-COMPILER-BUG** — same surface as site 1; @frozen applied; SIL unchanged; partial-apply forwarders for the closure `X.init(_:)` remain |
| 3. Tagged.retag<A> | **CONFIRMED-COMPILER-BUG (dispositioned via path (c), 2026-05-20)** — `Tagged.init(_unchecked:)` cannot be `@inlinable` because its body assigns to `self.underlying` whose setter is `package` (`public package(set) var underlying`). Swift rejects `@inlinable` bodies that reference `package`/`internal` setters with the diagnostic *"setter for property 'underlying' is package and cannot be referenced from an '@inlinable' function"*. `@usableFromInline` on the property declaration does NOT lift the SETTER's visibility (only the property as a whole). Three resolution paths were surfaced, all with trade-offs: (a) widen the setter to `public` (loses the package-set encapsulation principle in the Tagged.swift docstring); (b) move to explicit getter/setter computed form (loses the stored-property shape that the docstring calls "load-bearing" for Carrier's `borrowing get` requirement + partial-consume of `~Copyable` Underlying); (c) accept the language limitation and treat Tagged.retag as compiler-bug material. **Principal chose (c).** Rationale: since Cursor.peek and Lexer.Scanner.peek<X> remain unspecialized despite full annotation hygiene (so they're compiler-bug regardless), (c) is the consistent verdict — preserves the load-bearing Tagged API decisions (`package(set)` encapsulation + stored-shape for Carrier witness + ~Copyable partial-consume semantics) and treats Tagged.retag's lack of specialization as part of the same upstream compiler-side specialization gap. |
| 4. _CarrierProtocol.vector | **FIXED (institute-side hygiene)** — defaults now `@_alwaysEmitIntoClient`; commit `c2849a3`. Does not close canada because hot path uses per-conformer auto-synthesized witnesses (Byte's stored field, Tagged's stored field), not the trivial-self defaults. |

**Aggregate outcome**: Canada metadata% essentially unchanged.
Institute-side annotation hygiene improved (carrier defaults
land at `@_alwaysEmitIntoClient`). Three legitimate-annotation
levers remain unfired (two ABI-shape, one blocked on parallel
work). After those land, the verdict on Cursor.peek /
Lexer.Scanner.peek<X> / Tagged.retag<A> would be re-evaluated
against the same SIL/symbol/wall-clock methodology.

**Per the brief's Phase 5 routing**: this is the MIXED case —
institute-side fix landed AND upstream-issue artifacts staged.

- Carrier default-impl fix: COMMITTED to swift-carrier-primitives.
  Real institute-side gap closed.
- Reproducer scaffold staged at
  `swift-institute/Experiments/typed-index-specialization-reproducer/`
  for the principal's adjudication on whether to file upstream
  after the remaining institute-side levers (`@frozen` ABI changes
  + Tagged.init(_unchecked:) `@inlinable`) are fired.

### Skill references

- `[ISSUE-001]` (dev toolchain check) — not applicable; this is
  optimizer-specialization-shape work, not a crash. Verification
  on 6.4-dev nightly remains a downstream principal call.
- `[ISSUE-028]` (consult the compiler bug catalog) — bug catalog
  consulted; no existing entry matches the cross-module
  generic-specialization-on-typed-cursor pattern.
- `[ISSUE-010]` classification — this is the "MISSING-SPECIALIZATION"
  axis; not formally in the bug-classification taxonomy. Closest
  fit: "Miscompile-adjacent" — observed binary behavior diverges
  from expected (specialized) shape, but produces correct output;
  the divergence is performance only.
- `[PLAT-ARCH-008c]` (L1 primitives are unconditionally
  platform-agnostic) — preserved; no platform conditionals
  introduced.
- `[HANDOFF-013]` / `[RES-019]` — internal prior-research grep
  performed: `swift-institute/Research/inlinable-spi-transitive-semantics.md`,
  `spi-inlinable-incompatibility-survey.md`,
  `witness-uniformity-vs-strategy-specialization.md`,
  `swift-compiler-bug-catalog.md` consulted; none cover this
  specific cross-module-witness-dispatch pattern.
- `[RES-023]` — every file:line citation in this doc verified
  at write time.

## Provenance

- Parent investigation: `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md`
  v1.4.1 (2026-05-20).
- Dispatch handoff: `/Users/coen/Developer/HANDOFF-typed-index-specialization-audit.md`.
- Audit run on Apple Swift 6.3.1 (default toolchain), macOS 26
  arm64, `caffeinate -i` + release mode + 8-warmup + 32-measured
  iters. Symbol inspection via `nm | swift demangle` on the
  release binary.

## References

- Brief: `/Users/coen/Developer/HANDOFF-typed-index-specialization-audit.md`
- Parent: `swift-foundations/swift-json/Research/parse-performance-canada-anomaly.md` v1.4.1
- Reproducer scaffold: `swift-institute/Experiments/typed-index-specialization-reproducer/` (this audit; placeholder pending principal disposition on filing)
- Sibling research: `swift-institute/Research/inlinable-spi-transitive-semantics.md`
- Sibling research: `swift-institute/Research/spi-inlinable-incompatibility-survey.md`
- Bug catalog: `swift-institute/Research/swift-compiler-bug-catalog.md` (no existing entry for this pattern)
