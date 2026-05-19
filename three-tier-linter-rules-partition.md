# Three-Tier Linter Rules Partition

<!--
---
version: 0.1.0
last_updated: 2026-05-11
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

`swift-linter-rules` currently holds 72 rules in a single package. The
mixed-tier audience is its load-bearing limitation: a consumer that
wants only typed-throws hygiene receives compound-identifier opinions
that presume institute namespace conventions, and a primitives-tier
consumer receives both plus rules that bake in `Tagged`/`Cardinal`/
`RawValue` conventions that don't apply outside the primitives layer.

The 2026-05-11 lint pass against 11 public primitives packages
(`swift-foundations/swift-linter-rules/Research/lint-pass-2026-05-11-aggregate.md`)
empirically confirms the mismatch: 896 findings across 23 rules, with
Tagged-conformance and Cardinal-arithmetic rules firing exclusively on
their relevant primitives, while typed-throws and minimal-type-body
rules fire across every layer.

The proposed restructure splits the 72 rules into three hierarchical
packages, with consumers depending on the tier whose vocabulary they
adopt:

```
                ┌─────────────────────────────────────────┐
                │ swift-primitives-linter-rules           │
                │  primitives-tier conventions            │
                │  (Tagged, Cardinal, RawValue chains)    │
                └──────────────┬──────────────────────────┘
                               │ depends on
                ┌──────────────▼──────────────────────────┐
                │ swift-institute-linter-rules            │
                │  institute architecture + naming        │
                │  (Nest.Name, typed throws, ~Copyable,   │
                │   five-layer, API-IMPL conventions)     │
                └──────────────┬──────────────────────────┘
                               │ depends on
                ┌──────────────▼──────────────────────────┐
                │ swift-linter-rules                      │
                │  universal Swift hygiene                │
                │  (compiler invariants, SE performance)  │
                └──────────────┬──────────────────────────┘
                               │ depends on
                ┌──────────────▼──────────────────────────┐
                │ swift-linter-primitives                 │
                │  engine type definitions                │
                │  (Lint.Rule, Lint.Configuration, ...)   │
                └─────────────────────────────────────────┘
```

A consumer like `swift-carrier-primitives` depends on
`swift-primitives-linter-rules` and transitively receives all three
tiers' rules in its `Lint.swift` manifest.

## Question

How should the existing 72 rules partition into the three packages?
What classification criteria are sufficient to make each rule's tier
unambiguous? What are the borderline cases that need explicit
adjudication?

## Analysis

### Classification criteria

A rule belongs in tier `T` if its **normative kernel** — the underlying
anti-pattern or compiler hazard it catches, stripped of any
institute-flavored framing in the message — satisfies the tier's
predicate:

| Tier | Predicate |
|------|-----------|
| **T1 universal** | The kernel is a Swift compiler invariant, a Swift Evolution-documented performance issue, or a type-system hygiene rule that bites any Swift project regardless of architecture, naming convention, or stylistic choice. Stripping the institute citation, if any, leaves a rule that's still defensible in isolation. |
| **T2 institute** | The kernel encodes institute architecture (five-layer model, Nest.Name namespace, typed-throws stance, ~Copyable conventions, API-IMPL type design) or institute-specific feedback memories. Defensible only when those conventions are adopted. |
| **T3 primitives** | The kernel encodes primitives-tier specifics — `Tagged`, `Cardinal`, `Ordinal`, `Index`, RawValue chains, primitives-layer protocol patterns (`Carrier.\`Protocol\``, `Equation.\`Protocol\``, `Ownership.Borrow.\`Protocol\``). Doesn't generalize even within the institute layer model. |

**Citation as evidence, not verdict**: a `[PLAT-ARCH-022]` citation is
strong evidence the rule is institute, but the kernel test takes
precedence. Some rules carry institute citations even though their
underlying kernel is universal (e.g., `inlinable internal access`
cites `[PATTERN-052]` but the underlying issue — `@inlinable` accessing
`internal` symbols — is a Swift compiler invariant). Those rules go
universal with the institute citation rewritten as a generic message.

### Tier 1 — Universal (7 rules)

These catch Swift compiler hygiene, Swift Evolution-documented
performance issues, or type-system facts. Generic message; no institute
citation in the body.

| Rule | Current citation | Kernel |
|------|------------------|--------|
| `` `for loop in result builder` `` | research-doc only | SE-0289 `buildArray` materializes intermediate `[[Element]]`; 12–44× slower than imperative |
| `` `inlinable internal access` `` | `[PATTERN-052]` | `@inlinable` declarations cross-module-accessing `internal` symbols is a Swift compiler invariant |
| `` `usable from inline internal import` `` | `[PATTERN-055]` | `@usableFromInline` + `internal import` is a Swift compiler error in 6.x; surfaceable at the lint layer |
| `` `unchecked sendable categorization` `` | `[MEM-SAFE-024]` | `@unchecked Sendable` without a justification comment is a documented Sendable Evolution recommendation |
| `` `unchecked sendable noncopyable` `` | `[MEM-SEND-004]` | `~Copyable` types can't be shared between actors, so `@unchecked Sendable` is type-system-redundant |
| `` `mock factory zero collision` `` | `[TEST-028]` | Mock factories whose default offsets collide silently merge test cases; universal testing hygiene |
| `` `unsafe storage visibility` `` | `[MEM-SAFE-023]` | Public stored properties of Swift `@unsafe` types are exposure hazards; universal Swift safety hygiene |

### Tier 3 — Primitives (5 rules)

These reference primitives-tier types (`Tagged`, `Cardinal`, `RawValue`)
or primitives-tier conventions by structural construction. Tier
membership is the strict reading: the rule cannot be detached from
primitives-layer vocabulary.

| Rule | Current citation | Primitives-tier coupling |
|------|------------------|--------------------------|
| `` `zero or one literal` `` | `[CONV-001]` | Flags `Cardinal(0)`/`Cardinal(1)` constructors; references the `Cardinal` type |
| `` `count minus one` `` | `[CONV-002]` | Flags `count - 1` rewrites; presumes `Cardinal` arithmetic |
| `` `chained rawvalue access` `` | `[API-NAME-???]` | Targets `Tagged.rawValue.method()` escape paths |
| `` `bitpattern rawvalue chain` `` | (raw-value) | Targets `Tagged.rawValue.bitPattern` conversions |
| `` `tagged extension public init` `` | `[PATTERN-019]` | Targets `extension Tagged: ... { public init(rawValue:) }`; structurally about `Tagged` |

### Tier 2 — Institute (60 rules)

Everything not in T1 or T3. Each rule's kernel presumes institute
architecture, naming, typed-throws stance, or ~Copyable conventions —
or cites an institute feedback memory. The full table:

#### Naming pack (10 rules in institute)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `compound identifier` `` | `[API-NAME-002]` | No compound camelCase identifiers; use nested accessors |
| `` `compound type name` `` | `[API-NAME-001]` | All types use Nest.Name; no compound names like `FileDirectoryWalk` |
| `` `bool public parameter` `` | `[API-IMPL-003]` | Enum-over-Boolean for public-API state |
| `` `int public parameter` `` | `[IMPL-010]` | Push Int to the edge; typed wrappers at the surface |
| `` `ad hoc box class` `` | `[IMPL-107]` | Ownership.Indirect over ad-hoc `_Box`/`_Storage` |
| `` `variable named impl` `` | `feedback_no_impl_abbreviation` | Don't bind locals as `impl`; use the type's name |
| `` `property named flags` `` | `feedback_options_naming` | OptionSet types named `*.Flags` should be `*.Options` |
| `` `redundant prefix` `` | `[API-NAME-???]` | Type names redundantly prefixing their pack/namespace |
| `` `single type namespace` `` | `[API-NAME-???]` | Single-type namespace shape check |
| `` `tag suffix` `` | `feedback_no_tag_suffix` | Phantom-type tags suffixed `Tag` (institute convention) |
| `` `unification typealias` `` | `[API-NAME-004]` | Type-unification rename bridges anti-pattern |
| `` `namespace adoption typealias` `` | `[API-NAME-004a]` | Same-leaf typealias namespace adoption review |

#### Structure pack (8 rules)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `minimal type body` `` | `[API-IMPL-008]` | Types contain only storage + canonical init; methods in extensions |
| `` `single type per file` `` | `[API-IMPL-005]` | One type declaration per `.swift` file |
| `` `raw value access` `` | `[PATTERN-017]` | `.rawValue` / `.position` at unsealed boundaries |
| `` `wrapper backing exposed` `` | `[PATTERN-???]` | Property-wrapper backing storage leaked |
| `` `hoisted protocol alias` `` | `[PATTERN-???]` | Protocol typealias hoisted from conformance site |
| `` `type transform placement` `` | `[PATTERN-012]` | Type-transform shapes in correct extension placement |
| `` `throwing wrapper init` `` | `[PATTERN-020]` | Validating wrapper inits without throws |

#### Memory pack (7 rules, after T1 extractions)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `extension noncopyable constraint` `` | `[MEM-COPY-004]` | Extensions on `~Copyable`-aware generics need explicit `~Copyable` constraint |
| `` `noncopyable error` `` | `[MEM-COPY-???]` | Error types should/shouldn't be `~Copyable` |
| `` `borrowing self short circuit` `` | `[IMPL-094]` | Operator overload short-circuit using `borrowing self` |
| `` `sendable struct with class member` `` | `[MEM-SEND-???]` | `Sendable` struct with a class-typed member |
| `` `nonisolated unsafe without safe` `` | `[MEM-SAFE-025]` | `nonisolated(unsafe)` policy — needs reconciliation: rule currently requires `@safe`, but institute policy is to forbid `@safe` entirely |
| `` `pointer advanced by` `` | `[IMPL-011]` | Pointer arithmetic kernel under review — institute math-reading preference suggests typed `Offset<T>` over `.advanced(by:)` |
| `` `unsafe assignment granularity` `` | `[MEM-???]` | Multi-byte unsafe-pointer assignments without granularity ceremony |

#### Throws pack (10 rules) — all institute (typed-throws stance)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `untyped throws` `` | `[API-ERR-001]` | `throws` without typed-throws clause |
| `` `existential throws` `` | `[API-ERR-???]` | `throws(any Error)` is existential, anti-pattern |
| `` `do throws for typed catch` `` | `[API-ERR-???]` | `do throws(E) { ... } catch` shape |
| `` `do throws for typed catch with throw` `` | `[API-ERR-???]` | Variant with explicit `throw` |
| `` `closure typed throws annotation` `` | `[API-ERR-???]` | Closure parameters need typed-throws annotation |
| `` `generic throws missing never` `` | `[API-ERR-???]` | Generic-throws specialization to `Never` |
| `` `hoisted error in public throws` `` | `[API-ERR-???]` | Hoisted error type in public typed-throws |
| `` `result wrapper for rethrows shim` `` | `[API-ERR-???]` | `Result`-wrapper around rethrows |
| `` `callback result over throws thunk` `` | `[API-ERR-???]` | Result-callback over throws thunk |
| `` `typed throws cannot use self error` `` | `[API-ERR-002]` | `throws(Self.Error)` in bare-protocol context |
| `` `lifecycle typealias review` `` | (review prompt) | Lifecycle-typealias review surfacing |

#### Try pack (1 rule)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `try optional` `` | `[API-ERR-???]` | `try?` swallowing typed errors |

#### Platform pack (9 rules)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `c type in public api` `` | `[PLAT-ARCH-005a]` | C types in public-API shapes |
| `` `convention c representability` `` | `[PLAT-ARCH-???]` | `@convention(c)` representability |
| `` `dead case per platform` `` | `[PATTERN-056]` | Dead-case enum branches across platforms |
| `` `compound platform namespace root` `` | `[PLAT-ARCH-???]` | Platform namespace root compound shape |
| `` `optionset shell pattern` `` | `[PATTERN-???]` | OptionSet shell pattern |
| `` `canimport conditional` `` | `[PLAT-ARCH-???]` | `#if canImport(...)` conditional shape |
| `` `swift protocol qualification` `` | `[PLAT-ARCH-022]` | Stdlib-protocol references need `Swift.` qualification |
| `` `system subdomain` `` | `[PLAT-ARCH-???]` | Platform system subdomain shape |
| `` `typealiased namespace bridge` `` | `[PLAT-ARCH-018]` | Typealiased namespace bridge |

#### Idiom pack (5 rules)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `bounded index static capacity` `` | `[IDX-???]` | Bounded-index static capacity check |
| `` `enumerated with subscript` `` | `[PATTERN-058]` | `enumerated()` + subscript-access pattern |
| `` `intermediate binding then return` `` | `[PATTERN-???]` | Intermediate let-binding then return |
| `` `counter loop iteration` `` | `[IMPL-033]` | `for i in 0..<N { i }` counter loops |
| `` `string utf8 scanning` `` | `[PATTERN-???]` | String-UTF8 scanning idiom |

#### Closure pack (4 rules)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `configuration before content` `` | `[PATTERN-???]` | Configuration parameters before content closures |
| `` `lifecycle order` `` | `[PATTERN-???]` | Multi-closure lifecycle ordering |
| `` `unlabeled lifecycle closure` `` | `[PATTERN-???]` | Unlabeled lifecycle closures |
| `` `parameter position` `` | `[PATTERN-???]` | Parameter position in API surfaces |

#### Testing pack (4 rules in institute, after T1 extraction)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `benchmark timed required` `` | `[BENCH-???]` | Benchmark suites require `.timed(...)` measurement ceremony |
| `` `compound suite name` `` | `[INST-TEST-???]` | Test-suite name avoids compound shape |
| `` `test function naming` `` | `[SWIFT-TEST-???]` | Test-function naming convention |
| `` `performance suite serialized` `` | `[INST-TEST-???]` | Performance suites must run serialized |

#### Unchecked pack (1 rule)

| Rule | Citation | Kernel |
|------|----------|--------|
| `` `unchecked call site` `` | `[CONV-016]` | `__unchecked:` argument labels at call sites bypass the typed contract |

### Borderline rules and open questions

The classification above contains six rules whose tier I'm least
confident in:

1. **`unchecked call site`** — uses `__unchecked:` argument labels,
   which are an institute convention introduced for the `[CONV-001]`
   tier-5 extension-init machinery. Is that label pattern broadly
   adopted in Swift, or institute-only? If institute-only, this rule
   stays T2. If the label is standard Swift, it moves to T1.

2. **`nonisolated unsafe without safe`** — **RESOLVED → T2 institute**,
   but with a policy-reconciliation follow-up. `@safe` is a Swift 6.x
   attribute (SE-0458 strict memory safety), not institute-only.
   Institute policy is to **forbid `@safe` in any source file**, with
   explicit override only for narrow carve-outs. This inverts the
   current `[MEM-SAFE-025]` rule logic, which presently *requires*
   `@safe` next to every `nonisolated(unsafe)`. Two follow-ups before
   migration:
   - Reconcile `[MEM-SAFE-025]`: either rewrite the rule to forbid
     `@safe` next to `nonisolated(unsafe)` (institute prefers stating
     the encapsulation invariant differently), OR replace it with a
     pair: (i) `nonisolated(unsafe)` needs an invariant comment;
     (ii) `@safe` is forbidden in Sources except via explicit override.
   - Add a NEW rule: `@safe forbidden in sources` (T2 institute) that
     fires on any `@safe` attribute in `Sources/` paths.

3. **`unsafe storage visibility`** — **RESOLVED → T1 universal**.
   `@unsafe` is a Swift 6.x attribute (SE-0458), not institute-only.
   The kernel — public stored properties of `@unsafe` types are
   exposure hazards — is a universal Swift hygiene rule that bites
   any Swift codebase using `@unsafe`. Move from T2 to T1; rewrite
   the message to drop the `[MEM-SAFE-023]` framing in favor of a
   generic Swift safety articulation.

4. **`pointer advanced by`** — **RESOLVED → T2 institute**, but
   requires deeper rule-design research before migration. Principal
   preference: code should read close to math (use ecosystem typed
   offset types rather than raw `.advanced(by:)`). The rule as
   currently framed (`[IMPL-011]`: prefer `.advanced(by:)`) may
   itself be misaligned with that direction — the institute target
   is likely "prefer typed `Offset<T>` arithmetic over both raw
   pointer math and `.advanced(by:)`". Open the rule's normative
   kernel up for review during the migration. Tier classification:
   stays T2 (institute math-reading preference).

5. **`tag suffix`** — **RESOLVED → T2 institute**. The rule is
   institute-wide, not primitives-tier (L2 institute rules cover
   L1 primitives, L2 standards, L3 foundations consumers). The
   actual policy is two-pronged:
   - **No compound name like `UserID`** — use `User.ID` (the nested
     namespace form). This is the `[API-NAME-001]` / `[API-NAME-002]`
     surface.
   - **No `*Tag` marker types like `UserTag`** that exist solely to
     phantom-tag — reuse the conceptual type itself (`User` as its
     own tag). The rule's normative kernel.

   Update the rule's source-of-truth doc-comment accordingly during
   migration; tier classification confirmed T2.

6. **`counter loop iteration`** — **RESOLVED → T2 institute** with
   deeper rule-design research deferred. Principal preference: code
   should read like math (express iteration intent through institute
   typed range/index methods, not raw counter loops). The rule's
   `[IMPL-033]` framing already aligns with this direction but may
   need re-articulation during migration to capture the math-as-intent
   reading. Tier classification: stays T2.

**Updated tier counts** after adjudication: **T1 universal: 7**
(unchanged + `unsafe storage visibility` promoted from T2),
**T2 institute: 60** (was 61, minus `unsafe storage visibility`),
**T3 primitives: 5** (unchanged). Total 72.

**Follow-ups surfaced during adjudication** (out of partition scope,
tracked separately):
- Reconcile `[MEM-SAFE-025]` policy: `@safe` is currently required
  next to `nonisolated(unsafe)` per the existing rule, but institute
  policy is to forbid `@safe` in sources.
- Add new rule `@safe forbidden in sources` (T2 institute).
- Re-examine `pointer advanced by` rule kernel against the math-reading
  preference — the rule may need to recommend `Offset<T>` arithmetic
  over `.advanced(by:)`, not the reverse.
- Re-examine `counter loop iteration` framing against the math-reading
  preference — likely already aligned but worth re-articulating.

### Empirical validation

The 2026-05-11 lint pass against 11 public primitives packages gives
per-rule fire rates:

| Rule | Findings | Proposed tier | Empirical signal |
|------|----------|---------------|------------------|
| `compound_identifier` | 363 | T2 | Fires across every package (universal-shaped within institute) |
| `minimal_type_body` | 252 | T2 | Fires across every package |
| `extension_noncopyable_constraint` | 108 | T2 | Fires across every package |
| `int_parameter_public` | 54 | T2 | Fires across packages (broad institute concern) |
| `bool_parameter_public` | 27 | T2 | Fires across packages |
| `closure_typed_throws_annotation` | 20 | T2 | Typed-throws — broad institute concern |
| `tagged_rawvalue_extension_public_init` | 11 | T3 | Fires only on tagged-primitives — confirms T3 |
| `swift_protocol_qualification` | 9 | T2 | Platform-arch fires across packages |
| `unification_bridge_typealias` | 5 | T2 | Cross-package |
| `borrowing_self_short_circuit` | 3 | T2 (borderline T3) | Fires only on equation-primitives; supports T3 reclassification |
| `inlinable_internal_access` | 2 | T1 | Compiler-hygiene — fires sporadically; behavior matches T1 |
| `unnecessary_unchecked_sendable_noncopyable` | 3 | T1 | Confirms type-system fact, broad applicability |

The empirical signal mostly supports the classification. One rule
(`borrowing_self_short_circuit`) fires exclusively on
equation-primitives, suggesting it could move from T2 to T3 — but the
rule's normative kernel (operator overload short-circuit semantics) is
general, so I keep it T2 pending review.

### SwiftPM dependency mechanics

Each rules-tier package depends path-style on the tier below. The
consumer's `Lint/Package.swift` template lists products explicitly so
ambiguous SwiftPM resolution is avoided:

```swift
// swift-primitives-linter-rules/Package.swift
let package = Package(
    name: "swift-primitives-linter-rules",
    products: [
        .library(name: "Linter Rule Primitives Cardinal", targets: ["..."]),
        .library(name: "Linter Rule Primitives RawValue",  targets: ["..."]),
        .library(name: "Linter Rule Primitives Tagged",    targets: ["..."]),
    ],
    dependencies: [
        .package(path: "../../swift-foundations/swift-institute-linter-rules"),
    ],
    targets: [ /* ... */ ]
)
```

A primitives-layer consumer's manifest:

```swift
// swift-carrier-primitives/Lint/Package.swift
let package = Package(
    name: "Lint",
    dependencies: [
        .package(path: "../../swift-foundations/swift-linter"),
        .package(path: "../../swift-primitives-linter-rules"),
        // institute and universal rules pulled transitively
    ],
    targets: [ /* executable target that enables the rules */ ]
)
```

Cross-tier rule references use the natural-language `id` (now stable
post-unification per `swift-linter-rules` commit `c4d72ee`):

```swift
Lint.Configuration {
    .enable(.`compound identifier`)              // institute tier
    .enable(.`for loop in result builder`)       // universal tier
    .enable(.`chained rawvalue access`)          // primitives tier
}
```

### Naming and org placement

| Package | Repo path | Org | Notes |
|---------|-----------|-----|-------|
| `swift-linter-rules` | `swift-foundations/swift-linter-rules/` | swift-foundations | Existing; would become genuinely public if marketed as universal |
| `swift-institute-linter-rules` | `swift-foundations/swift-institute-linter-rules/` | swift-foundations | NEW; institute-flavored rules |
| `swift-primitives-linter-rules` | `swift-primitives/swift-primitives-linter-rules/` | swift-primitives | NEW; primitives-tier rules |

Org placement options to discuss:
- Move `swift-linter-rules` to a "swift-linter" or "swiftlang-adjacent"
  org if intended for external visibility — keeps the institute name
  off a genuinely universal package.
- Keep all three in `swift-foundations` for now, then re-home the
  universal one once the partition is validated.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Adopt the three-tier partition with the **7 / 60 /
5** split. All six borderline rules originally flagged for adjudication
have been resolved (see §Borderline rules), with one promotion
(`unsafe storage visibility` T2 → T1) and four reconfirmations. Two
policy-reconciliation follow-ups were surfaced and are tracked
out-of-scope below.

**Migration sequence**:

1. **Partition decision** — resolve the 6 borderline rules; lock the
   final tier assignment per rule.
2. **Create `swift-institute-linter-rules`** — move 61 rules out of
   `swift-linter-rules`, preserving rule IDs (no breaking change at
   the diagnostic level since IDs are stable post-`c4d72ee`).
3. **Create `swift-primitives-linter-rules`** — move 5 rules out of
   `swift-linter-rules`.
4. **`swift-linter-rules` rewrite** — pare down to the 6 universal
   rules; rewrite messages to drop institute-citation framing where
   the kernel is universal; update README and docs.
5. **Consumer migration** — each existing consumer (the 11 audited
   primitives packages) updates its `Lint/Package.swift` to depend on
   `swift-primitives-linter-rules` instead of `swift-linter-rules`.
   Transitive resolution pulls institute + universal automatically.
6. **External-visibility step (optional)** — if `swift-linter-rules`
   moves to a new org, do that after the partition validates.

**Non-goals for this partition**:
- Cross-tier rule duplication (a universal rule isn't also published
  by institute). Each rule lives at exactly one tier.
- Rule renames. The `c4d72ee` rename was the breaking change; this
  partition keeps IDs stable.
- Adding new rules. Pure restructure of existing 72. (The follow-ups
  below — `@safe forbidden in sources`, `pointer advanced by` kernel
  reconsideration, MEM-SAFE-025 policy reconciliation — are tracked
  separately and not part of the partition's mechanical scope.)

**Out-of-scope follow-ups surfaced during borderline adjudication**:

1. **MEM-SAFE-025 policy reconciliation**. The current rule
   `nonisolated unsafe without safe` requires `@safe` next to every
   `nonisolated(unsafe)`. Institute policy is to forbid `@safe` in
   sources entirely (with explicit override only). The rule's
   normative kernel needs rewriting — either inverted ("`@safe` next
   to `nonisolated(unsafe)` is forbidden") or paired with a separate
   invariant-comment rule.

   *Concrete instance surfaced during 2026-05-11 leaf triage*:
   `swift-property-primitives/Sources/Property Consume Primitives/Property.Consume.State.swift:54`
   ( `extension Property.Consume.State: @unchecked Sendable where Base: Sendable {}` ).
   The WORKAROUND/WHY/WHEN TO REMOVE/TRACKING doc-comment block at lines 4–22
   (SIL EarlyPerfInliner crash citation, conditional `where Base: Sendable`,
   removal condition, Experiments citation, dual-experiment refutation tracking)
   IS the documentation `[MEM-SAFE-024] unchecked sendable categorization`
   asks for — but in `[PATTERN-016]` WORKAROUND shape rather than the
   literal `// CATEGORY: D` marker the rule's mechanical check expects.
   Resolution direction: rule should recognize `[PATTERN-016]` block as
   equivalent (and possibly preferred) documentation. Held AMBIGUOUS in
   the swift-property-primitives leaf report (Cluster E) pending this
   reconciliation.

2. **New rule: `@safe forbidden in sources`** (T2 institute). Fires
   on any `@safe` attribute appearing in a `Sources/` path; explicit
   per-call override available for narrow carve-outs.

3. **`pointer advanced by` kernel reconsideration**. The current rule
   recommends `.advanced(by:)` per `[IMPL-011]`. The institute math-
   reading preference suggests the recommendation should be typed
   `Offset<T>` arithmetic, not `.advanced(by:)`. Re-examine the
   rule's normative kernel before migration.

4. **`counter loop iteration` kernel re-articulation**. Likely
   already aligned with the math-reading preference (`.indices` /
   typed-range iteration over raw counter loops) but worth
   re-articulating in the migration commit.

**Validation criterion**: after migration, a consumer outside the
institute (hypothetical or real) can depend on `swift-linter-rules`
alone and receive only universal Swift hygiene. A consumer inside the
institute but outside primitives (any foundations-layer package) can
depend on `swift-institute-linter-rules` and receive universal +
institute without Tagged-specific noise.

## References

- `swift-foundations/swift-linter-rules/Research/lint-pass-2026-05-11-aggregate.md`
  — empirical fire-rate data backing the per-rule classifications.
- `swift-institute/Research/rule-corpus-iteration-framework.md` v1.1.0
  — the disposition vocabulary (TIGHTEN, LOOSEN, RETIRE, etc.) and the
  framework that this partition operationalizes for the linter-rule
  half of the framework's scope.
- `swift-foundations/swift-linter-rules` commit `c4d72ee` — the
  rule-ID unification that made cross-tier rule references stable
  enough to permit the partition.
- `swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md`
  — the `Lint/Package.swift` consumer pattern this partition uses.
