# Parameter Ordering Conventions

<!--
---
version: 1.1.0
last_updated: 2026-04-16
status: DECISION
changelog:
  - 2026-04-16 v1.1.0: Promoted to code-surface as [API-IMPL-012] – [API-IMPL-015]. [SKILL-LIFE-003] classification: Additive (zero-violation ecosystem survey; no previously-conforming code is now non-conforming). Status updated to DECISION.
  - 2026-04-16 v1.0.0: Initial investigation.
tier: 2
workflow: Investigation [RES-001] (triggered by /code-surface session on parameter ordering)
trigger: Ecosystem needs a normative rule on (1) configuration parameter placement and (2) closure parameter conventions. Current code-surface skill is silent on both.
scope: All init and function signatures across swift-primitives, swift-standards, swift-foundations. Excludes rules whose jurisdiction sits with other skills (ownership annotations → memory-safety; typed throws → implementation; compound identifier prohibition → unchanged).
---
-->

## Context

The `code-surface` skill codifies type, method, property, error, and file conventions via [API-NAME-*], [API-ERR-*], [API-IMPL-*]. It does not legislate **parameter ordering** — neither configuration struct placement nor closure parameter positioning. Ecosystem code has converged on clear patterns, but the convention is tacit rather than written. This investigation surveys prior art (Apple guidelines, Swift Evolution, stdlib precedents, community writing) and the ecosystem's own practice, then proposes normative rules to add to `code-surface`.

The investigation is bounded by three hard constraints provided by the user:

1. Ecosystem conventions take precedence where they diverge from external guidance.
2. The rule MUST NOT reverse any existing `code-surface` prohibition (notably [API-NAME-002] compound identifiers).
3. The focus is narrow: configuration placement and closure positioning. Other parameter-ordering concerns (ownership annotations, typed throws) stay with their respective skills.

## Question

What ordering rules should govern (1) configuration struct parameters (`.Options`, `.Configuration`, `.Context`, `OptionSet`) and (2) closure parameters in Swift Institute initializers and functions?

---

## Analysis

### Prior Art Summary

#### Apple Swift API Design Guidelines

Four normative passages from https://www.swift.org/documentation/api-design-guidelines/ :

| Rule | Exact wording |
|------|---------------|
| Defaults-at-end | "Prefer to locate parameters with defaults toward the end of the parameter list. Parameters without defaults are usually more essential to the semantics of a method, and provide a stable initial pattern of use where methods are invoked." |
| Fluency decay | "It is acceptable for fluency to degrade after the first argument or two when those arguments are not central to the call's meaning" |
| Closure parameter naming | "Names used for closure parameters should be chosen like parameter names for top-level functions. Labels for closure arguments that appear at the call site are not supported." (Pre-SE-0279; the second sentence is superseded by [SE-0279].) |
| Roles over types | "Name variables, parameters, and associated types according to their roles, rather than their type constraints." |

The Guidelines do **not** speak to configuration-struct placement as a distinct category. The only `options:` example — `AudioUnit.instantiate(with: description, options: [.inProcess], completionHandler: stopProgressBar)` — places `options:` in the middle, not end, without normative commentary.

#### Swift Evolution

**SE-0279 (Multiple Trailing Closures)** accepts: first trailing closure drops its label; subsequent trailing closures require labels. Example syntax:
```swift
UIView.animate(withDuration: 0.3) { ... } completion: { _ in ... }
```
SE-0279 acknowledged that its initial backward-scan matching rule conflicted with default parameters.

**SE-0286 (Forward-Scan Matching)** replaced that rule. Quoted: *"The unlabeled trailing closure will be matched to the next parameter that is either unlabeled or has a declared type that structurally resembles a function type."* The proposal's own motivation names the canonical shape it preserves: `View.sheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> Content)` — **a defaulted closure sitting between config and the primary closure**. SE-0286 was tuned precisely to keep this shape callable via trailing-closure syntax.

**SE-0245 (Array uninitialized initializer)** provides the clearest rationale for config-first placement: *"Because trailing closures are commonly used, it's important to include those terms in the initial argument label, such that they're always visible at the use site."*

#### The Swift Programming Language

From `swiftlang/swift-book/TSPL.docc/LanguageGuide/Functions.md` and `Closures.md`:

- **Default parameters**: "Place parameters that don't have default values at the beginning of a function's parameter list, before the parameters that have default values."
- **Trailing closures (single)**: "you don't write the argument label for the first closure as part of the function call."
- **Trailing closures (multiple)**: "if a function takes multiple closures, you omit the argument label for the first trailing closure and you label the remaining trailing closures."

#### stdlib Precedents

| Signature | Config position | Closure position |
|-----------|-----------------|------------------|
| `Sequence.reduce(_ initial:_ next:)` | Seed first | Last |
| `Sequence.reduce(into:_:)` | Seed first | Last |
| `Task.init(priority: TaskPriority? = nil, operation: sending @escaping …)` | Defaulted config first | Last |
| `Task.init(name:priority:executorPreference:operation:)` | Three defaulted configs first | `operation:` last |
| `Array.init(unsafeUninitializedCapacity:initializingWith:)` | Capacity first | Last |
| `withTaskGroup(of:returning:isolation:body:)` | Three configs (two defaulted) first | `body:` last |
| `URLSession.dataTask(with:completionHandler:)` | URL first | Last |
| `View.sheet(isPresented:onDismiss:content:)` | Binding + defaulted closure first | Content builder last |
| `Sequence.sorted(by:)` | — | Only param, trails |

**The stdlib uniformly places configuration (including defaulted config) before the closure.** This directly contradicts a literal reading of "defaults at end." Swift evolved the compiler (SE-0286 forward-scan) to accommodate this precedence.

#### Community writing

- **Sundell** (swiftbysundell.com): advocates `then:` label for completion closures for call-site clarity; closures uniformly trail in examples. No explicit rule on configuration-struct placement.
- **hpique style guide**: *"In functions with more than one closure, treat the trailing closure as the most important closure of the function."* — justifies ordering the "success" closure last so it wins the trailing slot.
- **objc.io / Advanced Swift**: recommend trailing-closure syntax as the default except in specific disambiguation cases.
- **Point-Free**: no primary-sourced article on configuration parameter placement surfaced.
- **Swift Forums**: SE-0279 review thread debates the feature's existence, not placement rules. No Doug Gregor / Ben Cohen / John McCall post on this narrow question was located.

### Ecosystem Survey

Survey of public signatures in `swift-primitives`, `swift-standards`, `swift-foundations`:

**Configuration placement pattern (observed):**

| Site | Shape | Position |
|------|-------|----------|
| `swift-primitives/.../Kernel.Event.swift:53` | `init(id: ID, interest: Interest, flags: Options = [])` | Config LAST, defaulted |
| `swift-foundations/.../SVG.Context.swift:25` | `init(_ configuration: Configuration = .default)` | Config FIRST, only param |
| `swift-standards/.../EmailAddress.swift:28` | `init(displayName: String? = nil, _ string: String)` | Defaulted config FIRST |
| `swift-primitives/.../Pool.Bounded.swift:102` | `init(capacity:, destroy:, check:)` | Domain param FIRST, closures LAST |

Zero instances of configuration sandwiched between domain parameters (with or without closures) were found.

**Closure pattern (observed):**

| Site | Shape |
|------|-------|
| `swift-primitives/.../Predicate.swift:41` | `init(_ evaluate: @escaping (T) -> Bool)` — single closure, unlabeled, last |
| `swift-primitives/.../List.Linked.Inline.swift:135` | `forEach<E>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` — unlabeled body, last, typed throws thunk per [IMPL-092] |
| `swift-primitives/.../Sequence.swift:17` | `count(where predicate: (Element) throws(E) -> Bool) throws(E)` — labeled `where`, last |
| `swift-primitives/.../Pool.Bounded.Acquire.Callback.swift:81` | `callAsFunction<T>(_ body:, completion:)` — two trailing closures SE-0279 style |
| `swift-primitives/.../Kernel.Completion.Driver.swift:104` | `init(submit:flush:drain:close:overflowCount:)` — five closures, all trailing |

**Zero violations found**: no closure parameter appears before a non-closure parameter; every multi-closure signature orders closures by lifecycle (setup → body → completion); no builder-closure configuration (`(inout Options) -> Void`) was found anywhere.

### Points of Agreement Between Prior Art and Ecosystem

1. **Closure goes last.** TSPL, hpique, stdlib, SE-0286's forward-scan algorithm, and every surveyed ecosystem signature concur.
2. **Primary closure wins trailing position.** In multi-closure APIs, the semantically central closure occupies the unlabeled trailing slot.
3. **Configuration may precede closures even when defaulted.** Stdlib practice and the ecosystem both allow this; SE-0286 was designed to support it.

### Points of Tension

1. **API Design Guidelines "defaults at end" vs. stdlib practice.** The stdlib consistently violates this rule for closure-bearing APIs. SE-0286 legitimised the violation. De-facto precedence: **trailing-closure position > default-at-end**.
2. **`AudioUnit.instantiate(with:options:completionHandler:)`** sits `options:` in the middle. This is the only Guidelines example of `options:` and is non-normative. It contradicts the ecosystem's "no middle placement" practice.
3. **Configuration-FIRST vs. configuration-LAST for closure-free APIs** is genuinely not legislated by any external source. The ecosystem shows both patterns exist, differentiated by semantic role (primary input vs. modifier).

### Contextualization ([RES-021])

**Universal external pattern**: configuration parameters first, closure parameter last — enforced by compiler via SE-0286 forward-scan.

Adoption cost in the ecosystem (typed throws, `~Copyable`, `Property.View`, nested namespaces):

| Feature | Interaction | Cost |
|---------|-------------|------|
| Typed throws `throws(E)` | Orthogonal; effect on function type, not parameter position | Zero |
| `~Copyable` closure captures | Orthogonal to position; `borrowing`/`consuming`/`sending` annotations independent | Zero |
| `Property.View` coroutine accessors | Not a parameter-ordering concern | Zero |
| Nested namespaces (`File.Directory.Walk.Options`) | Parameter type nesting orthogonal to ordering | Zero |
| SE-0279 multi-closure | Requires label discipline on non-primary closures; names become API surface | Label-design cost; no structural conflict |

No ecosystem feature imposes an ordering constraint that would conflict with "configuration before closure." The external pattern imports cleanly.

### Option Analysis

#### Option A: Adopt "defaults at end" strictly (Guidelines literal)

Description: Follow API Design Guidelines literally. Defaulted params — including `.Options` with default — go at the end of the signature, even after closures if necessary.

Advantages: Consistent with Guidelines wording.
Disadvantages: Breaks trailing-closure syntax at call sites (SE-0286 forward-scan cannot match across a trailing required param). Contradicts stdlib. Contradicts every surveyed ecosystem signature.

**Rejected**: would require callers to write parentheses and explicit labels for every closure-bearing call. Zero ecosystem code follows this.

#### Option B: Adopt "closure last; configuration first when primary, last when modifier" (ecosystem pattern)

Description: Three-rule stack:
1. All closures trail the signature.
2. Configuration that **is** the primary input goes first (often as the only non-closure param).
3. Configuration that **modifies** a primary operation goes immediately before any closures, with a default value.

Advantages: Matches every ecosystem signature without revision. Consistent with stdlib. Compatible with SE-0286. Avoids middle placement uniformly.
Disadvantages: Requires authors to classify configuration as "primary input" vs. "modifier." The classification is subjective at boundary cases.

#### Option C: Adopt "closure last; configuration always first" (stdlib literal)

Description: All configuration parameters — defaulted or not — go before all other parameters. Closures last.

Advantages: Single rule. Matches `Task.init`, `withTaskGroup`, `View.sheet`.
Disadvantages: Contradicts ecosystem signatures like `Kernel.Event.init(id:interest:flags:)` that use defaulted config at the end when no closure is present. Forces configuration-first even when domain parameters carry the semantic weight.

#### Option D: Adopt "closure last; configuration always last" (Guidelines literal, but only the non-closure portion)

Description: Within the non-closure prefix of the signature, configuration goes last (with defaults). Closures trail the whole thing.

Advantages: Matches `Kernel.Event.init`. Consistent with Guidelines for closure-free cases.
Disadvantages: Contradicts `SVG.Context.init(_ configuration:)` where configuration is a single primary-input parameter. Contradicts stdlib practice for closure-bearing APIs where defaulted config often precedes domain params.

### Comparison

| Criterion | Option A | Option B | Option C | Option D |
|-----------|----------|----------|----------|----------|
| Matches API Design Guidelines | Literal | De-facto via SE-0286 precedence | No | Partial |
| Matches stdlib practice | No | Yes | Yes | Partial |
| Matches ecosystem signatures | No | Yes | No | No |
| Compatible with SE-0286 forward-scan | Depends | Yes | Yes | Yes |
| Avoids middle placement | Yes | Yes | Yes | Yes |
| Single-rule simplicity | Yes | No (two-case) | Yes | Yes |
| Classification ambiguity | None | "Primary" vs. "modifier" judgement | None | None |

### Recommended Rules

Option B is the only option that matches all three authorities (Guidelines de-facto, stdlib, ecosystem) without revision. The classification ambiguity is the real cost — but the ecosystem survey already demonstrates the boundary is stable in practice. The following rules codify Option B.

**Proposed additions to `code-surface`**:

---

#### [API-IMPL-012] Closure Parameters Trail the Signature

All closure parameters MUST occupy the final positions of a function or initializer signature. A non-closure parameter MUST NOT appear after a closure parameter.

Rationale: Without this ordering, SE-0286 forward-scan cannot match the closure to a trailing-closure call site, and the compiler silently disables trailing-closure syntax. Closure-last is the de-facto universal Swift convention (TSPL, stdlib, ecosystem).

Typed-throws thunk parameters per [IMPL-092] — `() throws(E) -> T` — are closures for the purpose of this rule.

Applies to: all public and package-visible signatures. Private signatures SHOULD follow the rule; violations MUST be justified by a `// WHY:` comment per [PATTERN-016].

---

#### [API-IMPL-013] Multiple Closures Follow Lifecycle Order

For signatures with two or more closure parameters, closures MUST be ordered by lifecycle: setup → body → completion/teardown. The primary body closure MAY be unlabeled; all subsequent closures MUST be labeled (SE-0279 requirement).

Labels for secondary closures participate in the call-site surface (`… completion: { … }`, `… onError: { … }`) and MUST be chosen to read well in that position. Labels SHOULD follow API Design Guidelines role-naming: the label names the closure's *role* in the operation, not its Swift type.

Example, validated at `swift-primitives/.../Kernel.Completion.Driver.swift:104`:

```swift
public init(
    submit:    @escaping (…) throws(Error) -> Void,
    flush:     @escaping () throws(Error) -> Submission.Count,
    drain:     @escaping ((Event) -> Void) -> Event.Count,
    close:     @escaping () -> Void,
    overflowCount: @escaping () -> Event.Count = { .zero }
)
```

---

#### [API-IMPL-014] Configuration Parameter Placement

Configuration-bearing parameters — `.Options`, `.Configuration`, `.Context`, or `OptionSet` types — MUST sit at one of two positions:

1. **First**, labeled or unlabeled, when the configuration IS the primary input (the operation's output or identity is fully determined by the configuration). Example: `SVG.Context.init(_ configuration: Configuration = .default)`.
2. **Last in the non-closure portion of the signature**, labeled, with a default value, when the configuration modifies a primary operation and closure parameters (if any) follow. Example: `Kernel.Event.init(id: ID, interest: Interest, flags: Options = [])`.

Middle placement — configuration between two unrelated domain parameters — is FORBIDDEN. Splitting configuration across sibling parameters when a struct would suffice is FORBIDDEN; bundle into the struct.

**Decision test**: Can the operation's *purpose* be stated with only the configuration parameter? If yes → first. If the operation's purpose is stated with other parameters and the configuration only tunes it → last (before any closures).

**Rationale**: Middle placement is not compatible with SE-0286 forward-scan when a closure trails, and violates "roles over types" because it hides the configuration's relationship to the operation. The first/last dichotomy maps onto the semantic role (primary input vs. modifier).

---

#### [API-IMPL-015] Struct Configuration Over Builder Closures

Configuration surfaces MUST use explicit struct parameters (with defaults) rather than builder closures of the shape `(inout Options) -> Void` or `(ConfigBuilder) -> Void`.

Rationale: Struct parameters are inspectable at the call site, composable across calls (`let base: Options = …; foo(…, options: base.with(\.flag, true))`), participate in typed-throws and `Sendable` analysis naturally, and preserve the compile-time constraint surface. Builder closures trade all of that for construction syntax sugar that the ecosystem has not needed. The ecosystem survey found zero builder-closure configurations; this rule codifies that practice.

---

### What These Rules DO NOT Cover

To prevent scope creep, the following concerns are explicitly OUT OF SCOPE and remain with their respective skills:

| Concern | Owning skill | Reference |
|---------|--------------|-----------|
| Ownership annotations (`consuming`, `borrowing`, `inout`) | memory-safety | [MEM-OWN-*], [IMPL-067] |
| `sending` annotations | implementation | [IMPL-066] |
| `isolated` parameter position | implementation | [IMPL-062], [IMPL-083] |
| Typed throws `throws(E)` | code-surface / implementation | [API-ERR-001], [IMPL-040] |
| Closure parameter *name* selection (not label) | API Design Guidelines baseline | — |
| Compound-identifier prohibition on labels | code-surface (unchanged) | [API-NAME-002] |

Ordering is orthogonal to these annotations: `func f(x: consuming T, body: sending () async -> R)` satisfies the closure-last rule regardless of `consuming` and `sending`.

---

## Outcome

**Status**: DECISION.

Four rules promoted to `code-surface` on 2026-04-16 as [API-IMPL-012] closure-trail, [API-IMPL-013] multi-closure lifecycle, [API-IMPL-014] configuration placement, [API-IMPL-015] struct-over-builder. All four are validated by zero-violation ecosystem surveys, external consistency with stdlib and SE-0286, and non-interference with existing `code-surface`, `implementation`, and `memory-safety` rules.

**Implementation**: `/Users/coen/Developer/swift-institute/Skills/code-surface/SKILL.md` — new "## Parameter Ordering" section between `[API-IMPL-011]` and the Post-Implementation Checklist; checklist extended with four new items.

**Residual open question**: [API-IMPL-014]'s first/last dichotomy requires the author to classify configuration as "primary input" vs. "modifier." The ecosystem survey showed this classification is stable in practice, but boundary cases may arise. If classification drift appears across future reflections, revisit with a single-rule alternative (Option C always-first or Option D always-last).

---

## References

Primary sources:

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [SE-0279: Multiple Trailing Closures](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0279-multiple-trailing-closures.md)
- [SE-0286: Forward-Scan Matching for Trailing Closures](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0286-forward-scan-trailing-closures.md)
- [SE-0245: Array uninitialized initializer](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0245-array-uninitialized-initializer.md)
- [The Swift Programming Language — Functions](https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/Functions.md)
- [The Swift Programming Language — Closures](https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/Closures.md)

Community:

- [John Sundell — Using `then:` for completion closures](https://www.swiftbysundell.com/tips/using-then-as-an-external-parameter-label-for-closures/)
- [John Sundell — Designing Swift APIs](https://www.swiftbysundell.com/articles/designing-swift-apis/)
- [hpique — Style guide for functions with closure parameters](https://github.com/hpique/Articles/blob/master/Swift/Style%20guide%20for%20functions%20with%20closure%20parameters/Style%20guide%20for%20functions%20with%20closure%20parameters.md)
- [SE-0279 review thread](https://forums.swift.org/t/se-0279-multiple-trailing-closures/34255)

Internal:

- Ecosystem survey (this session): `Kernel.Event.swift:53`, `SVG.Context.swift:25`, `EmailAddress.swift:28`, `Pool.Bounded.swift:102`, `Predicate.swift:41`, `List.Linked.Inline.swift:135`, `Sequence.swift:17`, `Pool.Bounded.Acquire.Callback.swift:81`, `Kernel.Completion.Driver.swift:104`.
- Related skills: `code-surface` ([API-NAME-*], [API-IMPL-*]), `implementation` ([IMPL-092] typed-throws thunks, [IMPL-066] sending, [IMPL-083] isolation bridge).
