# IO Witness Shape Zoo — Addendum: Macro Convention and Phase 2 Findings

<!--
---
version: 1.0.0
created: 2026-04-17
last_updated: 2026-04-17
status: RECOMMENDATION
tier: 2
scope: swift-io (delta to cross-package Tier 3 parent)
supersedes: none
supersededBy: none
related:
  - ../../../swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md (parent, IN_PROGRESS)
  - ../Experiments/witness-mock-borrowing/EXPERIMENT.md
  - ../Experiments/witness-recording-against-properties/EXPERIMENT.md
  - ../Experiments/witness-maperror-sending-return/EXPERIMENT.md
  - ../../../swift-foundations/swift-witnesses/Experiments/witness-property-method-collision/Sources/main.swift
  - ../../../swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift
  - ../Experiments/io-witness-shape-f/EXPERIMENT.md
  - ../Experiments/io-witness-domain-via-map/EXPERIMENT.md
  - ../Experiments/io-witness-macro-generic-compat/EXPERIMENT.md
  - ../Experiments/io-witness-generic-error/EXPERIMENT.md
  - ../Experiments/io-witness-generic-ops/EXPERIMENT.md
  - ../Experiments/io-witness-domain-generic-substrate/EXPERIMENT.md
  - ../Experiments/io-witness-tokio-style/EXPERIMENT.md
  - ../Experiments/io-witness-zio-style/EXPERIMENT.md
  - ../Experiments/io-witness-eio-style/EXPERIMENT.md
  - ../Experiments/io-witness-monoio-style/EXPERIMENT.md
---
-->

> **Cross-package note (2026-04-20)**: this document was moved from
> `swift-foundations/swift-io/Research/` to
> `swift-primitives/swift-io-primitives/Research/`. Frontmatter paths
> are now true relative paths.

## 1. Context

### 1.1 What this addendum is

This is a **delta** to the parent Tier 3 comparative analysis at
`swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md`
(status IN_PROGRESS, last updated 2026-04-17, 4318 lines). It does not
replace the parent. It captures the empirical validation results that
followed the parent's publication:

1. A **macro convention change** landed in `swift-witnesses` on
   2026-04-17: the `@Witness` macro now uses storage names verbatim
   (no underscore stripping) and emits no deprecation attribute.
2. Three **Phase 2 experiments** were run in
   `swift-foundations/swift-io/Experiments/` to probe the four
   remaining unknowns flagged in parent §6.
3. All ten zoo sketches at
   `swift-primitives/Experiments/io-witness-*/` were **mechanically
   migrated** to the non-underscored storage convention, and each
   sketch now carries a dated "Migration to non-underscored storage"
   (or equivalent) subsection in its EXPERIMENT.md.

### 1.2 State immediately prior to this addendum

- Parent status: **IN_PROGRESS**.
- Four §6 unknowns flagged:
  1. §6.4 — tuples of `~Copyable` (Swift language constraint).
  2. §6.8 — `mapError` region-inheritance problem.
  3. §6.9 — zero-parameter `@Witness` closures don't auto-generate
     methods.
  4. The implicit fourth — `@Witness(.mock)` with `borrowing`/
     `consuming` `~Copyable` parameters, disabled on `IO` per the
     block comment at
     `swift-io/Sources/IO Core/IO.swift:92–98`.
- All ten zoo sketches used underscored storage (`_read`, `_write`,
  `_close`, `_ready`, …).

### 1.3 Why this addendum, specifically

Before the selection document can pick a shape, the parent analysis's
remaining unknowns need to be narrowed from "open" to either
"resolved" or "confirmed-still-open". This addendum does that, with
direct pointers to empirical evidence, and reports the migration's
mechanical impact on each of the ten sketches. The decision weights
can then be applied with no hidden dependencies.

### 1.4 Scope and non-goals

**In scope**: resolution of parent §6.9, confirmation of parent §6.8,
new finding on mock-with-borrowing, uniformity of composition-operator
support under the new convention, migration-impact tabulation,
reassessment of parent §11.2 candidate finalists' relative standing.

**Out of scope**: picking a winner (that is the selection document);
runtime benchmarks; `mapError` compiler-fix vs accepted-limitation
classification (the selection document's decision).

### 1.5 Document location note

The parent analysis lives at
`swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md`
because its scope spans swift-io, swift-kernel, swift-executors, and
swift-witnesses. This addendum lives at
`swift-foundations/swift-io/Research/io-witness-shape-zoo-addendum.md`
under the convention that swift-io-specific delta research is
swift-io-scoped. The selection document that depends on this addendum
will live in `swift-foundations/swift-io/Research/` as well.

---

## 2. The swift-witnesses Macro Convention Change

### 2.1 Empirical basis — the witness-property-method-collision experiment

The macro change is backed by a single empirical study:
`swift-foundations/swift-witnesses/Experiments/witness-property-method-collision/Sources/main.swift`
(267 lines, seven variants V1–V7, dated 2026-04-17, Swift 6.3 release).

| Variant | Case | Outcome | Interpretation |
|---------|------|---------|----------------|
| V1 | `let read: (Int) -> Int` + `func read(from x: Int) -> Int` | CONFIRMED | Labeled property + labeled method coexist. Swift names differ (`read` vs `read(from:)`), no collision. |
| V2 | Inside `func read(from:)`, call `read(x)` (unlabeled) | CONFIRMED | Resolves to property-closure — method requires `from:`. |
| V3 | `self.read` (no parens) | CONFIRMED | Yields the stored closure as a value; assignable to a local. |
| V4 | `let read: (Int) -> Int` + `func read(_ x: Int) -> Int` (same signature) | UNEXPECTED — compiles | Property wins at call site. Method value is reachable only via `self.read` which itself yields the property. Method is effectively shadowed. |
| V5 | `let now: () -> Int` + `func now() -> Int` | REFUTED (as expected) | `error: invalid redeclaration of 'now()'`. Zero-arg + zero-arg collides at declaration. |
| V6 | `@Witness struct` with **non-underscored** storage `let read: (_ from: Int, _ into: Int) -> Int` | CONFIRMED | Macro emits a labeled method; stored closure and method coexist. |
| V7 | `@Witness struct` with **underscored** storage `let _read: (_ from: Int, _ into: Int) -> Int` | CONFIRMED | Backwards compatible. Old deprecation-attribute semantics preserved. |

### 2.2 The macro's mechanical position

V5 (zero-arg + zero-arg) is the **only** mechanically forced collision.
V1–V4 all compile. V6 shows the macro tolerates non-underscored
storage. V7 shows the macro tolerates underscored storage. There is no
mechanical requirement for underscore; for labeled closures the
convention is now purely cosmetic.

The macro's response: use storage names verbatim everywhere, emit no
deprecation attribute, skip method generation for zero-arg closures
(which would collide under V5).

### 2.3 Implementation deltas in the macro

Cited against
`swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift`:

| Concern | Previous behaviour | New behaviour | Evidence |
|---------|-------------------|---------------|----------|
| `methodName` | Strip leading `_` | Verbatim `name` | line 540: `var methodName: String { name }` |
| `initLabel` | Strip leading `_` | Verbatim `name` | line 562: `func initLabel(isPublic: Bool) -> String { name }` |
| Deprecation attribute | Emitted on underscored storage pointing at stripped-name method | Not emitted | lines 257–267: "No deprecation attribute is emitted." |
| Zero-arg closure | Generated zero-arg method; collision | No method generated (skipped) | V5 collision avoided at generation time |
| Labeled closure | Generated labeled method | Generated labeled method (unchanged) | V6 — stored closure and method coexist |

### 2.4 Practical reading for witness-design

| Storage shape | What the macro produces | What the call site looks like |
|---------------|------------------------|------------------------------|
| Labeled closure `read: (_ from: Descriptor, _ into: Buffer) -> Int` | Stored closure `read` + labeled method `read(from:into:)` | `io.read(from: fd, into: buf)` (either path; identical) |
| Zero-arg closure `now: () -> UInt64` | Stored closure `now` (no method generated) | `clock.now()` (closure call on property) |
| Underscored labeled `_read: (…) -> …` | Stored closure `_read` + labeled method `read(from:into:)` + deprecation-on-storage (backcompat) | Either path works; the underscore path emits a warning |

---

## 3. Resolution of §6 Unknowns from the Parent Analysis

### 3.1 §6.9 — Zero-parameter @Witness closures don't auto-generate methods

**Status update**: Resolved as **INTENTIONAL**.

**Evidence**: V5 in witness-property-method-collision proves that a
property `let now: () -> Int` + method `func now() -> Int` collide at
declaration. The macro's response is to skip method generation for
zero-arg closures entirely — there is no Swift name the method could
take that would not collide. Property-as-call-site (`prop()`) is the
canonical convention.

**Concrete direct evidence of value**: the eio-style sketch (`Eio.Clock`)
previously had a manual forwarding extension
`extension Eio.Clock { public func now() -> UInt64 { _now() } }` that
existed solely to turn the `_now` closure into a call-site `clock.now()`.
Under the new convention, the closure is stored directly as `now`, and
the call site `env.clock.now()` is a closure-call on that property. The
entire extension block was **deleted** during migration. Citation:
`swift-primitives/Experiments/io-witness-eio-style/EXPERIMENT.md` lines
50–57 ("the manual `now()` forwarder is gone… that entire extension
block was deleted outright. This is direct, measurable evidence of the
call-site convention change's value").

**Implication for the selection document**: Shape F's
`IO.Runner` (zero-arg `executor` and `shutdown`) does not need manual
forwarding extensions. The parent §6.9 manual-extension budget for
Shape F drops from two (`_executor`, `_shutdown`) to zero. Same for
Shape E (`Clock._now`).

### 3.2 §6.8 — The mapError region-inheritance problem

**Status update**: **CONFIRMED-still-open**. The limitation is
intrinsic to Swift 6.3 region analysis, not a macro concern.

**Evidence**: `swift-foundations/swift-io/Experiments/witness-maperror-sending-return/EXPERIMENT.md`,
dated 2026-04-16, Swift 6.3.1 release, macOS 26 arm64. Five techniques
attempted; results:

| Variant | Technique | Outcome | Failing diagnostic |
|---------|-----------|---------|-------------------|
| V1 | `consume self` + reconstruction | FAIL | `task or actor-isolated value cannot be sent` |
| V2 | Explicit `@Sendable` wrapper closures | FAIL | `#SendableClosureCaptures` — captures not Sendable |
| V3 | `SendableIO` with `LeafError: Sendable` + `@Sendable` closures | **COMPILES** | — (but is a witness-shape change, not mapError technique) |
| V4 | `withSending` helper | FAIL (both sides) | `task or actor-isolated value cannot be sent` + `#SendingRisksDataRace` |
| V5 | Fresh closure literals with `[self]` captures | FAIL | `task or actor-isolated value cannot be sent` |

Only V3 compiles, and it requires `LeafError: Sendable` on the error
parameter plus `@Sendable` annotations on every stored closure. This
violates the "no Sendable constraint on the generic error parameter"
preference
(`/Users/coen/.claude/projects/-Users-coen-Developer/memory/feedback_no_sendable_constraint_workaround.md`).
V3 is not a `mapError` technique; it is a change to the witness's
definition.

**The underlying invariant** (direct quote from the experiment's
Analysis section): "region is a property of closure captures and of
the enclosing value's declared Sendability, not of the textual
construction site. `consume self`, fresh closure literals, `sending`
helpers, and `@Sendable` wrappers all operate at the syntactic surface;
none rebase the region of a closure whose storage type is not
`@Sendable`."

**Reinforces**: parent §6.8, and the earlier REFUTED finding in
`swift-primitives/Experiments/io-witness-generic-error/` that
prompted parent §6.8 in the first place.

**Implication for the selection document**: if a shape relies on
`mapError` to produce a `sending IO<NewError>` (for actor-crossing,
`Task.init(sending:)`, or other region-fresh scenarios), only V3's
shape-level fix works. Two viable responses:

1. **Accept the limitation**: `mapError` returns a same-region
   `IO<NewError>`. Consumers who need a region-fresh witness assemble
   one from sending-safe pieces (factory-level construction).
2. **Adopt V3 shape at the witness definition**: constrain
   `LeafError: Sendable`, annotate every stored closure `@Sendable`.
   Cost is philosophical (violates Sendable-constraint preference);
   cost is syntactic (explicit annotations). Whether this cost is
   acceptable is a selection-document question, not a parent-analysis
   question.

This finding does not eliminate any shape in the parent's §12.1
finalist set. It constrains Shape GE specifically: if Shape GE is used
as the SOLE error story, `mapError` cannot re-region across actors;
if Shape GE is used ALONGSIDE a flat-error primary (Shape F), the
limitation is avoidable.

### 3.3 New finding — mock generation with ~Copyable parameters

**Status**: **REFUTED unexpectedly** — the limitation documented at
`swift-io/Sources/IO Core/IO.swift:92–98` is no longer real.

**Evidence**: `swift-foundations/swift-io/Experiments/witness-mock-borrowing/EXPERIMENT.md`,
dated 2026-04-16, Swift 6.3 release, macOS 26 arm64. Applied
`@Witness(.mock)` to a struct with:

- `read: @Sendable (borrowing Resource, Int) async throws(SomeError) -> Int`
- `write: @Sendable (borrowing Resource, Int) async throws(SomeError) -> Int`
- `close: @Sendable (consuming Resource) async -> Void`

Build completes cleanly:

```
[1997/2000] Compiling witness_mock_borrowing main.swift
[1998/2000] Linking witness-mock-borrowing
[1999/2000] Applying witness-mock-borrowing
Build complete!
```

The macro emits mock closure bodies with `(_, _)` (underscored
parameters, no ownership annotations). Swift 6.3 propagates the target
type's ownership annotation through the underscored parameter,
treating `{ (_, _) in body }` as semantically equivalent to
`{ (_: borrowing Resource, _: Int) in body }` when the target function
type requires it. Macro itself unchanged — compiler behaviour
changed.

**Citation into the macro**:
`swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift`
line 600, `generateMockClosure` uses:

```swift
let underscores = parameters.map { _ in "_" }.joined(separator: ", ")
```

This is unchanged. The refutation is compile-time only.

**Implication for Shape F**: `IO.fake()` can be macro-generated. The
"test fakes" P1 in
`swift-foundations/Research/nio-inspired-capability-additions.md`
becomes near-trivial. The block comment at `IO.swift:92–98` is
**stale** and should be removed. A suggested follow-up is documented
in the experiment: change `@Witness` → `@Witness(.mock)` on
`public struct IO` at `swift-io/Sources/IO Core/IO.swift:132`; remove
lines 92–98; reshape `IO.fake()` around `IO.mock(read:write:close:
ready:unownedExecutor:)`.

**Caveat on scope**: `.mock` takes each return value as a plain
parameter (`read: Int`), not a closure. This is fine for scalar
returns but awkward when the caller wants different returns per call
(e.g., EOF after N bytes). The real Shape F testing story may still
prefer hand-rolled witnesses or `observe` for variable-response
scenarios. `.mock` is useful; it is not the whole story.

### 3.4 §6.4 — Tuple of ~Copyable

**Status**: **Unchanged**. Remains a Swift 6.3 language constraint.

**No new evidence in this addendum**. The parent §6.4 workaround
stands: any shape that wants multi-value returns from operations on
`~Copyable` values must wrap them in named structs
(`Socket.Accepted`, `Memory.Buffer.Returned`). Shape Dvm and Shape M
continue to feel this; Shapes F, Tk, and GE avoid it by construction.
No change in decision weight.

### 3.5 Resolved-vs-open summary

| Parent concern | Status in parent | Status after this addendum |
|----------------|------------------|----------------------------|
| §6.4 Tuples of `~Copyable` | Swift language limit | Unchanged |
| §6.8 `mapError` region inheritance | Open | Confirmed-still-open (intrinsic) |
| §6.9 Zero-param no method generated | Open / macro future-work | Resolved as intentional |
| Mock with borrowing ~Copyable | Disabled in `IO.swift:92–98` | Refuted; macro now works |

Three of four unknowns are now either resolved or pinned. §6.8
remains a real limit but one the selection document can weigh without
further experiment.

---

## 4. The Witness Composition Operators Are Storage-Agnostic

### 4.1 The validation experiment

`swift-foundations/swift-io/Experiments/witness-recording-against-properties/EXPERIMENT.md`,
dated 2026-04-16, Swift 6.3, macOS 26 arm64. A minimal witness
`@Witness struct Logger { let log: @Sendable (_ message: String) -> Void }`
(non-underscored storage) exercised through all five
`swift-witnesses` composition operators.

| Variant | Operator | Compile | Runtime | Notes |
|---------|----------|---------|---------|-------|
| V1 | `Witness.Recording<String>` | ✓ | ✓ (2 calls recorded) | Closure literal assignable to non-underscored `log` property |
| V2 | `Witness.Scope(values:)` | ✓ | ✓ (2 calls routed) | `scope.run { … }`; `Witness.Context.current[Logger.self]` retrieves custom Logger |
| V3 | `Witness.Values` subscript | ✓ | ✓ (2 calls routed) | `values[Logger.self] = …` typechecks via `Logger: Witness.Key`; round-trip preserves the closure |
| V4 | `Witness.Sequence<String>` | ✓ | ✓ (4 calls, last element saturates) | `callAsFunction()` composes inside the `log` closure literal |
| V5 | `Witness.Cycle<String>` | ✓ | ✓ (4 calls, wrap-around) | Same compositional shape as Sequence |

### 4.2 Why the operators are indifferent to storage naming

None of the five operators inspects the witness struct's synthesised
member names directly. Their entry points are:

1. **`Witness.Recording<Args>`** — free-standing recorder, sees only
   `Args`.
2. **`Witness.Values`** — keyed subscript on the `Witness.Key`
   conformance; key is the witness type.
3. **`Witness.Scope`** — wraps a `Witness.Values` and runs a
   caller-provided operation; the operation fetches the witness out
   of `Witness.Context` by key.
4. **`Witness.Sequence<T>` / `Witness.Cycle<T>`** — producers with
   `callAsFunction()`; composed inside the closure body, have no
   knowledge of the surrounding witness struct.

The only syntax sensitive to underscore-vs-not is the consumer's call
on the witness (`logger.log(...)`), which was exercised in V1–V5 via
both stored-closure form and macro-synthesised labeled method. Both
work.

### 4.3 Relation to V4 collision class

V4 in witness-property-method-collision showed that a property +
method with the *same* Swift name silently lets the property win at
the call site. None of the wrapping operators introduces such a
same-signature synthesis, so that failure mode does not apply here.
The only remaining risk class — zero-arg property + zero-arg method
collision (V5) — is a property of the subject `@Witness` declaration,
not of any operator, and is still correctly rejected by the macro at
generation time.

### 4.4 Impact on parent §7.7 composition-operator support matrix

Parent §7.7 tabulated composition-operator support per shape. In light
of this experiment, the "Recording / Scope / Values / Sequence /
Cycle" columns are **uniform across all ten shapes** at the
operator-infrastructure level. Shape-specific disadvantages (e.g., Z's
monadic value has no witness storage, M's tuple-return blocks
standard `observe`) remain; the storage-naming convention does not
add to them. No shape becomes newly advantaged or disadvantaged by
the storage migration.

---

## 5. Migration Impact on the Zoo

Each of the ten sketches was mechanically migrated to non-underscored
storage on 2026-04-16. Each sketch's EXPERIMENT.md now contains a
dated migration subsection. Summary:

| Shape | Dir | What the migration touched | Rebuild |
|-------|-----|---------------------------|---------|
| F | `io-witness-shape-f` | Closure storage on `IO` (`_read`→`read`, `_write`→`write`, `_close`→`close`, `_ready`→`ready`) and `IO.Runner` (`_executor`→`executor`, `_shutdown`→`shutdown`). No manual forwarders present; none to delete. Consumer call sites unchanged (`main.swift` only constructs `.unimplemented()`). | Clean |
| Dvm | `io-witness-domain-via-map` | Closure storage on `IO` and `Socket.IO` (`_read` / `_write` / `_close` / `_ready` / `_accept` / `_connect` / `_shutdown` → non-underscored). The `.map` body's `io.ready(from:interest:)` call unchanged because the synthesised labeled-method name matches. No zero-arg closures. | Clean (2.58s) |
| MG | `io-witness-macro-generic-compat` | Single zero-arg closure `_op` → `op`. Zero-arg no-synthesised-method rule acknowledged; `main.swift` constructs `.unimplemented()` and does not invoke the closure, so no `.op` → `.op()` call-site rewrite was needed in this sketch, but a downstream consumer would call `instance.op()`. | Clean (2.31s incr) |
| GE | `io-witness-generic-error` | **Hand-written sketch** (no `@Witness` macro). Renamed `_read`/`_write`/`_close` to `read`/`write`/`close`. The hand-written forwarding methods `read(from:into:)`, `write(to:from:)`, `close(_:)` **collided** with the renamed closure properties (same base name `read` / `write` / `close`); the forwarding methods were **dropped**. Consumer call sites invoke the closure-properties directly — Swift's labeled closure call syntax `io.read(from: fd, into: buf)` works because the closure type carries argument labels. `mapError` body updated to call `self.read(fd, buf)`. | Clean (0.55s) |
| GO | `io-witness-generic-ops` | `Socket.Ops` and `File.Ops` closure-storage properties renamed (e.g. `_accept`→`accept`, `_pread`→`pread`). Purely cosmetic alignment; sketch is hand-written. Init parameter labels, init-body bindings, and call sites in `main.swift` / `Socket.swift` / `File.swift` updated. `IO<Ops>` generic shape, `sending IO<...>` consumer parameters, virality demonstration all preserved. | Clean (0.49s) |
| DGS | `io-witness-domain-generic-substrate` | Dropped `_` prefix from closure-storage (`IO._read/_write/_ready/_close` → `IO.read/…`; `Socket.IO._accept` → `Socket.IO.accept`). The stored closure `accept` now **shadows** the `accept(on:)` method inside its own body, so the forwarding method disambiguates via `self.accept(substrate, listener)`. Consumer call site in `.on(_:)` updated (`substrate._ready` → `substrate.ready`). | Clean (0.51s) |
| Tk | `io-witness-tokio-style` | Closure storage dropped underscore on all three witnesses (`IO.Reader._read`→`read`, `IO.Writer._write`→`write`, `IO.Closer._close`→`close`). Consumer call sites in `main.swift` / `Demo` unchanged — they already invoked the macro-generated labeled methods (`reader.read(from:into:)`, `writer.write(to:from:)`). | Clean |
| Z | `io-witness-zio-style` | **No rename needed**. `IO<R, E, A>` already used `public let run: …` (not `_run`); every combinator (`map`, `flatMap`, `mapError`, `provide`) already calls `self.run(...)`. | Clean (unchanged) |
| E | `io-witness-eio-style` | `Eio.Clock._now` → `now` (zero-arg); the manual `extension Eio.Clock { public func now() -> UInt64 { _now() } }` extension was **deleted outright** — the stored closure is invoked directly as `env.clock.now()`. Labeled closures in `Eio.Net` (`connect(host:port:)`) and `Eio.File` (`open(path:)`) renamed (`_connect` → `connect`, `_open` → `open`); macro continues to synthesise their labeled methods, so consumer call sites unchanged. | Clean (3.14s) |
| M | `io-witness-monoio-style` | `_read` / `_write` → `read` / `write`. Swift's automatic call-as-method on closure-typed properties made the forwarding extension methods `read(from:into:)` / `write(to:from:)` **redundant**; they were removed. Consumer call site in `readLoop` switched from labelled `io.read(from: fd, into: consume buf)` to positional `io.read(fd, consume buf)` to match the closure's own parameterless signature. Rental-shape semantics (consuming `Memory.Buffer`, tuple return, re-bind loop) preserved. | Clean |

### 5.1 Pattern observations across the migration

1. **Pure-cosmetic rename** (no consumer impact, no code deleted): F,
   Dvm, MG, GO, Tk, Z. Six of ten.
2. **Forwarders deleted because they became redundant**: GE
   (`read(from:into:)` / `write(to:from:)` / `close(_:)`), M
   (`read(from:into:)` / `write(to:from:)`). Two of ten. Both
   hand-written sketches.
3. **Forwarders deleted because the closure-call became uniform**: E
   (`Eio.Clock.now()`). One of ten. This is the zero-arg case.
4. **Shadowing noted but benign**: DGS (`accept` shadows inside its
   own method body; `self.`-prefix disambiguates). One of ten.

Zero-arg closures drove the only **structural** benefit (E's
extension deletion). Labeled-closure shapes were purely cosmetic
renames. The migration's dominant effect is **consistency** across
the zoo, not any shape's viability.

### 5.2 Build status across all ten

All ten sketches rebuild clean post-migration, on Swift 6.3 release,
macOS 26 arm64, 2026-04-16. Parent §1.3 build-time envelope (0.35s
for Z … 106.98s for Tk) is preserved; the rename itself does not
regenerate macro expansions any more expensively.

---

## 6. Cognitive Dimensions Delta

Parent §7.3 scored all ten shapes on six Cognitive Dimensions axes.
This addendum presents a **delta** — which axes shift under the new
convention, and by how much. The full matrix is not re-tabulated.

| Dimension | What changed under the new convention | Net effect | Magnitude |
|-----------|---------------------------------------|-----------|-----------|
| Visibility | Labeled methods more discoverable in autocomplete (no `_` prefix noise). Zero-arg `prop()` slightly less obvious as a call. | Mixed; labeled wins, zero-arg loses | Small |
| Consistency | Uniform `name` / `name()` convention vs prior `_name` storage + synthesised `name(...)` mixed surface | Positive across all shapes with `@Witness` | Moderate |
| Viscosity | No underscored-storage migration friction for downstream packages; a fresh adopter avoids the `_`-prefix rule entirely | Positive for all `@Witness` shapes | Small |
| Role-expressiveness | Unchanged (macro-generated methods still present for labeled closures; stored closures still carry closure-semantic) | Neutral | None |
| Error-proneness | V4 "property wins" risk intrinsic to the macro, independent of storage convention. V5 zero-arg collision prevented at macro level. | Neutral (risks already priced in) | None |
| Abstraction | Unchanged; abstraction level is set by shape, not storage convention | Neutral | None |

**Specific-shape implications**:

- **Shape F** (Capability + Runner split): Visibility **improves**
  for the capability witness (labeled) and **neutral-to-slightly-lossy**
  for the runner's zero-arg closures (`executor`, `shutdown`). Net:
  small positive.
- **Shape E** (Eio): Visibility **improves** — the stored-closure +
  manual-extension awkwardness is gone. Net: small positive. Does
  not change E's compounding-sending-tax structural disadvantage.
- **Shape MG**: Viscosity **improves** — downstream consumers using
  macro-generic witnesses benefit directly.
- **Shape Tk**: Consistency **improves** (three witnesses all
  follow the same name scheme).
- **Others** (Dvm, GE, GO, DGS, Z, M): neutral or small positive on
  consistency/viscosity; no shift on the discriminating axes.

None of the six dimensions shifts enough to reorder parent §7.3's
score column. Shape F, Shape Dvm, Shape MG, Shape Tk remain the four
high-CD-profile shapes; Shapes Z, M, DGS remain the weakest.

---

## 7. Updated Status of §11 Candidate Finalists

Parent §11.2 named candidates Shape F, Shape F + GE, Shape Tk, Shape
Tk + GE, with Shape Dvm as composition mechanism and Shape MG as
tooling enabler. Reassessed against the three Phase-2 findings and
the migration.

| Candidate | §6.9 resolution (zero-arg no-method) | Mock-borrowing resolution | Witness-operators uniform | §6.8 mapError region-inheritance |
|-----------|-------------------------------------|--------------------------|---------------------------|----------------------------------|
| Shape F | Small positive — runner's `executor`/`shutdown` no longer need manual extensions; call sites `runner.executor()` / `runner.shutdown()` are natural | Significant positive — `IO.fake()` can be macro-generated via `.mock`; comment at `IO.swift:92–98` is stale and should be removed | Neutral (F already composed well) | Neutral — F's primary error story is flat `IO.Error`; mapError not on the critical path |
| Shape F + GE | Same as F | Same as F (applies to the `IO<LeafError>` form) | Neutral | Negative — if GE is the SOLE error story, cross-actor `mapError(sending:)` is unachievable without V3's witness-shape change |
| Shape Tk | Neutral — three witnesses, all labeled closures | Significant positive — each of Reader / Writer / Closer can be macro-mocked | Neutral | Neutral (Tk doesn't use mapError) |
| Shape Tk + GE | Same as Tk | Same as Tk | Neutral | Negative (same as F + GE) |
| Shape Dvm (composition mechanism) | Neutral | Positive (domain witnesses macro-mockable) | Neutral | Negative for domain-error variants (inherits §6.8) |
| Shape MG (tooling enabler) | Neutral | Positive (generic witnesses macro-mockable) | Neutral | N/A |

### 7.1 Net direction

- **§6.9 resolution** tilts slightly toward shapes with zero-arg
  runners (Shape F: runner's `executor`/`shutdown`). Small magnitude,
  ergonomic.
- **Mock-borrowing resolution** applies **uniformly** to every
  candidate (all use `borrowing`/`consuming` `~Copyable` parameters).
  The biggest beneficiary is any shape that needed a hand-rolled fake
  — Shape F most of all, because `IO.fake()` was the explicit
  motivator for the original comment. Moderate magnitude.
- **Composition-operator uniformity** is a null delta for ranking
  but a positive for confidence — no shape is silently disadvantaged
  by the storage migration.
- **§6.8 mapError limitation** is a **real constraint on Shape GE
  variants**, independent of the storage convention. Any finalist
  that uses generic-error as the SOLE error story inherits the "no
  cross-actor `mapError` without `LeafError: Sendable`" limit.

### 7.2 No elimination

No candidate is eliminated by these findings. The finalist set
remains as parent §11.2 stated:

- **Shape F** (primary capability / runner split)
- **Shape F + GE** (F with generic-error extension)
- **Shape Tk** (per-capability split)
- **Shape Tk + GE**
- **Shape Dvm** (composition mechanism; compatible with F, Tk, GE)
- **Shape MG** (tooling enabler)

The selection document decides among them.

### 7.3 What the selection document can now take for granted

1. Storage convention is uniform non-underscored (zero-arg excepted
   only at the macro generation-skipping level; the storage name is
   still non-underscored).
2. `Witness.*` composition operators compose uniformly.
3. `@Witness(.mock)` generation is available for witnesses with
   `borrowing`/`consuming` `~Copyable` parameters.
4. `mapError` on a generic-error witness cannot produce a `sending`
   return without `LeafError: Sendable` + `@Sendable` stored closures.
5. Zero-param closures on `@Witness` storage do not get synthesised
   methods; the canonical invocation is `prop()`.

Any of (1)–(5) can be a selection-document weight.

---

## 8. Open Items Remaining

After this addendum, the unknowns that remain for the selection
document to resolve or accept:

| Item | Category | Resolution path |
|------|----------|-----------------|
| Runtime benchmarks | Empirical | Deferred from parent §10 — may be run during selection-doc drafting or deferred to post-selection |
| Incremental build time analysis | Empirical | Deferred; a concern at CI level for high-macro-count shapes (Tk) |
| §6.8 — filed as compiler issue or accepted limitation? | Language / strategy | Selection document decides |
| Hybrid Shape F + GE prototype | Empirical | The sole remaining experiment if the selection document decides to adopt GE as F's error-generic extension. Would verify the combined shape's ergonomics at a non-trivial consumer site. |
| `IO.swift:92–98` comment removal | Housekeeping | Trivially fixable; safe to remove at selection-time or sooner |
| Migration path from current Shape B | Implementation | Selection document; count call sites, estimate churn |

None of these blocks the selection document from starting. All are
either lower-priority, post-selection, or contingent on the
selection's outcome.

---

## 9. Recommendations for the Selection Document

Neutral weight notes. No shape is recommended here — that is the
selection document's task.

### 9.1 Dimensions that now carry higher confidence weight

Because the macro convention change and Phase-2 experiments pinned
the remaining unknowns, the selection document can weight the
following dimensions with full confidence:

1. **Constraint-compliance** (parent §7.6). All six hard constraints
   are empirically verified per shape. No shape is pending on an
   unresolved compiler limit.
2. **Composition-operator support** (parent §7.7). Uniform across
   all ten shapes at the operator-infrastructure level. Shape-specific
   disadvantages remain but are well-characterised.
3. **Test fakes / mock generation**. `@Witness(.mock)` works for every
   shape that uses the macro. Test-story cost is now near-zero for
   any `@Witness` shape.
4. **Zero-arg-closure ergonomics**. `prop()` is canonical, no manual
   extensions needed. Applies to shapes with zero-arg closures (F's
   runner; E's clock).

### 9.2 Dimensions that remain discriminating

1. **Generic-parameter virality** (parent §6.3). Shapes with zero
   generic parameters at the public surface (F, Tk, Dvm) carry
   advantage over GE (one parameter), DGS/Z (multi). Unchanged by
   this addendum.
2. **`mapError` region-inheritance** (§3.2 of this addendum,
   confirming parent §6.8). A discriminator only if GE is used as a
   SOLE error story that requires cross-actor mapError. If GE sits
   beside a flat-error primary, this is a non-issue.
3. **Capability substitution granularity** (parent §11.2). Shape F's
   whole-witness substitution vs Shape Tk's per-capability
   substitution remains the key axis and is orthogonal to this
   addendum.
4. **Build-time cost** (parent §6.10). Macro-heavy shapes (Tk at
   106.98s) vs macro-light shapes (Z at 0.35s). Unchanged.

### 9.3 Suggested weighting posture

The selection document should apply the parent's weighted criteria
(§10.1) **as-stated**. This addendum does not recommend reweighting;
it tightens the empirical basis for the weights already proposed. In
particular:

- Do not down-weight Shape F or Shape F + GE on the basis of the
  now-stale `IO.swift:92–98` `.mock`-disabled comment.
- Do not up-weight Shape E on the basis of the removed manual `now()`
  extension; E's compounding-sending-tax disadvantage (parent §6.7)
  is unaffected.
- Do not treat Shape GE's §6.8 mapError limit as a blanket
  elimination; it is only constraining if GE is used solo AND
  cross-actor `sending mapError` is on the critical path.

---

## References

### Parent

- `swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md`
  (Tier 3, IN_PROGRESS, 4318 lines, 2026-04-17).

### Phase 2 experiments (new)

- `swift-foundations/swift-io/Experiments/witness-mock-borrowing/EXPERIMENT.md`
  — REFUTED unexpectedly: `.mock` with `borrowing`/`consuming`
  `~Copyable` compiles under Swift 6.3.
- `swift-foundations/swift-io/Experiments/witness-recording-against-properties/EXPERIMENT.md`
  — CONFIRMED: all five `Witness.*` operators are storage-agnostic.
- `swift-foundations/swift-io/Experiments/witness-maperror-sending-return/EXPERIMENT.md`
  — CONFIRMED-still-open: region inheritance is intrinsic; V1–V5 all
  fail except V3 which requires `LeafError: Sendable` + `@Sendable`
  closures.

### Macro convention change

- `swift-foundations/swift-witnesses/Experiments/witness-property-method-collision/Sources/main.swift`
  (seven variants V1–V7 documented in-file).
- `swift-foundations/swift-witnesses/Sources/Witnesses Macros Implementation/WitnessMacro.swift`
  — lines 257–267 (no deprecation attribute), 536–540 (verbatim
  `methodName`), 561–562 (verbatim `initLabel`), 597–601
  (`closureParameterList(named:)` used by mock generator).

### Zoo migration notes (per-sketch)

- `swift-primitives/Experiments/io-witness-shape-f/EXPERIMENT.md` §Migration (lines 39–49)
- `swift-primitives/Experiments/io-witness-domain-via-map/EXPERIMENT.md` §Migration (lines 48–50)
- `swift-primitives/Experiments/io-witness-macro-generic-compat/EXPERIMENT.md` §Migration (lines 46–54)
- `swift-primitives/Experiments/io-witness-generic-error/EXPERIMENT.md` §Migration (lines 44–60)
- `swift-primitives/Experiments/io-witness-generic-ops/EXPERIMENT.md` §Migration (lines 47–49)
- `swift-primitives/Experiments/io-witness-domain-generic-substrate/EXPERIMENT.md` §Migration (lines 43–45)
- `swift-primitives/Experiments/io-witness-tokio-style/EXPERIMENT.md` §Migration (lines 44–46)
- `swift-primitives/Experiments/io-witness-zio-style/EXPERIMENT.md` §Migration (lines 50–52)
- `swift-primitives/Experiments/io-witness-eio-style/EXPERIMENT.md` §Migration (lines 44–68)
- `swift-primitives/Experiments/io-witness-monoio-style/EXPERIMENT.md` §Migration (lines 49–51)

### Stale source that needs cleanup

- `swift-foundations/swift-io/Sources/IO Core/IO.swift:92–98` — the
  block comment describing `.mock` as disabled is now contradicted by
  `witness-mock-borrowing/EXPERIMENT.md`. Remove at selection-time
  (or sooner).

### Memory / feedback (cross-referenced)

- `feedback_no_sendable_constraint_workaround.md` — preference
  against adding `Sendable` constraints on generic parameters;
  directly bears on §3.2 V3's cost.

---

## End of Addendum
