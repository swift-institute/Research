# L3-Policy Layering Without `@_spi(Syscall)` — Investigation

**Status**: SUPERSEDED — primary recommendation refuted at production scale (see post-experiment update below); § 4 Wave 3.5-Corrective runtime-broken finding remains load-bearing
**Followup**: `l3-policy-layering-without-spi-2026-05-02-followup.md` documented approaches 11/12/13 (operation-struct + Tagged + Carrier) as the revised primary recommendation. **The followup's recommendation has since been empirically refuted at production scale** — see the followup doc's own Status update for details, and `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/` for the minimal repro. The current production pattern is **fresh nominal enums at L3 ("Path β")** for sites with policy substance + plain typealias chains for sites without (per `feedback_no_gratuitous_l3_delegation`). This document remains the canonical record of approaches 1–10 and the empirical demonstration that Wave 3.5-Corrective is runtime-broken (§ 4).

## Post-experiment status update (2026-05-02)

The `Tagged + Carrier with constrained-extension nested-type typealiases` recommendation in the followup doc cannot generalize. A subsequent migration cycle attempted to apply approach 12+13 across the four Wave 3.5-Corrective sites and hit a Swift compiler limitation: nested-type lookup on constrained extensions of a generic type does NOT consult the where-clause as a discriminator. Two `extension Tagged where Tag == X, RawValue == Y { typealias E = ... }` declarations on disjoint instantiations BOTH appear as candidates for `Tagged<concrete, concrete>.E` — producing an ambiguity error at every consumer site.

The toy approach-12 + 13 experiments missed this because they had ONE Tagged variant in scope. Production scale (where swift-memory-primitives' `Tagged<Memory, Ordinal>.Error` and the proposed `Tagged<POSIX, Stats>.Error` coexist transitively) hits the ambiguity at every consumer.

Empirical refutation: `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/` (CONFIRMED 2026-05-02, minimal 4-target repro). Recorded as a known Swift limitation in `~/.claude/projects/-Users-coen-Developer/memory/swift-6.3-fix-status.md` "Still Broken on 6.3.1" table. Branching investigation `HANDOFF-constrained-extension-nested-type-lookup-prior-art.md` queued at `/Users/coen/Developer/` to map upstream + cross-language prior art and decide whether to file SE-discussion.

The migration agent pivoted to **Path β** (fresh nominal enums at swift-posix for Stats / Open / Memory.Map; plain typealias for Time per `feedback_no_gratuitous_l3_delegation`). Path β is the empirically-correct production pattern as of 2026-05-02.
**Date**: 2026-05-02 (revised in same session per principal feedback; followup added same day)
**Scope**: Wave 3.5-Corrective dispatch (swift-iso-9945 + swift-foundations/swift-posix); generalises to any L2/L3 same-name method-wrapping case
**Companion experiments**: `swift-institute/Experiments/l3-policy-layering-approach-{1..10}/` (this doc); `l3-policy-layering-approach-{11,12,13}/` (followup)
**Drives**: 4 corrective namespaces in flight (`File.Stats`, `File.Open`, `Memory.Map`, `Time`); ~20 net-new `@_spi(Syscall) public` declarations dispatched at iso-9945 (commits `2aed9ad`, `cb053e5`, planned for Memory.Map and Time)

---

## REVISION NOTE (same session, post-principal-feedback)

The initial recommendation favored **approach 9** (sub-namespace nested inside the L2 type, e.g., `ISO_9945.Kernel.File.Stats.Syscall.get()`). Principal feedback reframed the problem: the existing `ISO_9945.*` and `POSIX.*` top-level namespaces already provide the natural L2/L3 separation; approach 9's sub-namespace is structurally redundant with that existing separation. The principal's framing:

> *"ISO_9945.* and POSIX.* achieve the same [as the sub-namespace]; ISO_9945.* is l2 (the equivalent of .Syscall), POSIX.* is l3. I'd like lower level (l2) to be coded without regard to downstream. and STILL have upstream be able to present its public API as it wants."*

This reframing identifies the actual root cause of the Wave 3.5-Corrective recursion: **the typealias `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats` collapses the natural L2/L3 namespace separation into a single nominal type**. Once collapsed, every `extension POSIX.Kernel.File.Stats` declaration silently becomes an `extension ISO_9945.Kernel.File.Stats` declaration ([PLAT-ARCH-018] typealiased namespace-path conflict). The same-signature collision is a *consequence* of the typealias, not a structural property of L2/L3 layering.

**Revised recommendation**: drop the typealias. Let `POSIX.Kernel.File.Stats` be its own distinct struct at swift-posix, with conversion at the L2/L3 boundary internal to swift-posix's body. Approach 10 (verified 2026-05-02) confirms this works mechanically.

This document is reorganised below: § 4 documents the runtime defect (unchanged); § 5 documents per-approach findings (1–9 unchanged; § 5.10 added for approach 10); § 6 reframes around approach 10 as the primary recommendation; § 7 demotes approach 9 to "fallback when one nominal type is required"; § 8 updates open questions (the `.Syscall.` sub-namespace question is moot under approach 10).

---

## 0. Executive Summary

The Wave 3.5-Corrective pattern (`@_spi(Syscall) public` at iso-9945 + typealias `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats` + same-signature cross-module extension at swift-posix) is **structurally broken at runtime**. The L3-policy method's body call to its L2 SPI counterpart resolves to the L3 declaration itself — Swift's overload resolution prefers the same-module declaration over the imported `@_spi` declaration when signatures are identical. Result: the L3-policy method infinitely self-recurses → stack overflow (SIGSEGV) on the first invocation.

The defect is present in shipped Wave 3.5-Corrective code: `swift-foundations/swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Open.swift:97` produces the compiler diagnostic *"function call causes an infinite recursion"* under clean build. The Stats analogue (commit `0c3545a`) shares the same shape with simpler body and presumably the same defect; tests don't exercise the runtime path so the regression hasn't surfaced.

**Root cause**: the typealias `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats` collapses the natural L2/L3 namespace separation. Per [PLAT-ARCH-018], `extension POSIX.Kernel.File.Stats` declarations resolve through the typealias to `extension ISO_9945.Kernel.File.Stats` — putting same-signature methods on the SAME nominal type as iso-9945's typed methods. The collision is a *consequence* of the typealias, not a structural property of L2/L3 layering itself.

**Recommended pattern: distinct L2/L3 top-level namespaces** (approach 10). iso-9945 owns `ISO_9945.Kernel.File.Stats` as its own struct with the spec-literal `get()` method — coded naturally as the POSIX `struct stat` mirror, **without regard to any downstream layer**. swift-posix declares `POSIX.Kernel.File.Stats` as its **own distinct struct** (with the necessary field shape — copying or wrapping iso-9945's), with its own `get()` method carrying EINTR retry policy. No typealias. Conversion from `ISO_9945.Kernel.File.Stats` to `POSIX.Kernel.File.Stats` happens internal to swift-posix's body via an `internal init(from l2:)`. The cross-platform unifier flip (`Kernel.File = POSIX.Kernel.File` at swift-kernel) preserves the consumer call shape `Kernel.File.Stats.get(...)`.

This is the SAME pattern Wave 3.5-1..8 already established for the 37 non-corrective namespaces (distinct enum at POSIX with method wrappers). The 4 corrective namespaces (Stats, Open, Memory.Map, Time) were treated as exceptional because they're STRUCT-shape rather than namespace-enum-shape, but the structural disposition is the same: declare a distinct type at POSIX. Wave 3.5-1's mistake was using a fresh enum where a fresh struct was needed; Wave 3.5-Corrective overcorrected by introducing the typealias chain that broke overload resolution.

**Recommended action**: revert the Wave 3.5-Corrective `@_spi(Syscall) public` adoption at iso-9945 (commits `2aed9ad`, `cb053e5`); for each of the four corrective namespaces, replace the typealias-chain pattern with a distinct struct at POSIX. iso-9945 returns to plain `public` typed methods (no `@_spi`), uninvolved in disambiguation choices. swift-posix declares its own struct + methods + boundary conversion.

**Approach 9** (sub-namespace nested inside the L2 type, e.g., `ISO_9945.Kernel.File.Stats.Syscall.get()`) was the initial recommendation in this document. It is preserved here as a fallback for the case where some downstream constraint requires L2 and L3 to share a single nominal type (typealias chain). For the production case, approach 10 is the structurally cleaner answer because the L2/L3 namespace separation already exists at the top level.

---

## 1. Context

The Wave 3.5 envelope is a multi-cycle build-out at swift-foundations/swift-posix that adds L3-policy method wrappers (EINTR retry, partial-IO loops, error normalization) over iso-9945's typed Phase 1.5 syscall surface. The envelope's atomic L3-unifier flip (`Kernel = POSIX.Kernel`) requires every consumer reference `Kernel.X.Y` to resolve correctly through `POSIX.Kernel.X.Y`.

For 37 of 41 wrapped namespaces (the audit-confirmed "namespace-enum" shape — fresh `enum POSIX.Kernel.X` declared at swift-posix, distinct from iso-9945's enum `ISO_9945.Kernel.X` with the same name), the established Wave 3.5-1..8 disposition works fine: distinct namespace enums at POSIX, method wrappers added directly to `POSIX.Kernel.X.Y` with no collision.

For 4 namespaces (`File.Stats`, `File.Open`, `Memory.Map`, `Time`), iso-9945's `X` is itself a `struct` data type (with size/permissions/uid/gid fields, not just a namespace anchor). Consumer references like `let s: Kernel.File.Stats` require the *struct identity*, not a different `enum POSIX.Kernel.File.Stats`. The Wave 3.5-1 namespace-enum disposition fails for these — the fresh enum is a distinct nominal type, breaking type identity at consumer use sites.

Wave 3.5-Corrective (commits `2aed9ad`, `cb053e5`, in flight for Memory.Map and Time) restructured these four into a typealias + cross-module extension pattern:

```swift
// At iso-9945 — downgrade typed methods to @_spi(Syscall) public:
extension ISO_9945.Kernel.File.Stats {
    @_spi(Syscall)
    public static func get(descriptor: borrowing ISO_9945.Kernel.Descriptor)
        throws(ISO_9945.Kernel.File.Stats.Error) -> ISO_9945.Kernel.File.Stats {
        try unsafe get(fd: descriptor._rawValue)
    }
}

// At swift-posix — typealias + cross-module extension:
@_spi(Syscall) public import ISO_9945_Kernel_File

extension POSIX.Kernel.File {
    public typealias Stats = ISO_9945.Kernel.File.Stats   // type identity preserved
}

extension ISO_9945.Kernel.File.Stats {
    public static func get(descriptor: borrowing ISO_9945.Kernel.Descriptor)
        throws(ISO_9945.Kernel.File.Stats.Error) -> ISO_9945.Kernel.File.Stats {
        try ISO_9945.Kernel.File.Stats.get(descriptor: descriptor)   // intended L2 delegation
    }
}
```

The pattern was dispatched as the principled solution to (a) preserve struct identity through the typealias chain, (b) provide L3 method-wrapping at the same call shape `Kernel.File.Stats.get(...)`, (c) keep iso-9945's typed forms accessible cross-module via `@_spi(Syscall)`. Principal flagged the introduction of ~20 net-new `@_spi(Syscall) public` declarations as inconsistent with the Wave 4b/4c lineage of "reduce SPI surface" (the `@_spi(Syscall)` raw-companion phase-out codified in [PLAT-ARCH-008j], 2026-04-30).

This investigation tested whether a Swift layering pattern exists that achieves all three goals (type identity, L3-policy method wrapping, NO @_spi at L2) AND, in the process, surfaced that the Wave 3.5-Corrective pattern itself is runtime-broken.

---

## 2. Method

Eight experiment packages built in `swift-institute/Experiments/l3-policy-layering-approach-{1..9}/` (approach 7 is documentation-only — investigation of rule-legal-demo / rule-law-demo precedent; approach 9 is a NEW pattern surfaced during analysis). Each experiment uses the simplest minimal reproduction per [EXP-004]:

- **L1Defs** target — declares `public struct Foo: Sendable`, `public init(tag: String)`, `public enum FooError: Error`
- **L2Methods** target — extends `Foo` with the typed Phase 1.5 method (`public static func make() throws(FooError) -> Foo`)
- **L3Policy** target — declares the policy-wrapped method using whichever disambiguation mechanism the approach is testing
- **Consumer** executable target — calls the user-facing entry and observes which method is dispatched

Each approach evaluated against six criteria from the handoff:

| # | Criterion |
|---|-----------|
| 1 | Type identity preserved (`L3.Foo == L1.Foo` at compile time) |
| 2 | Consumer `Foo.make()` resolves to L3-policy method (with delegation actually reaching L2 internally) |
| 3 | Consumer `let f: Foo` works (struct instantiation reachable) |
| 4 | NO `@_spi` at L1 or L2 (verified by grep) |
| 5 | NO consumer code change required (call shape stays `Foo.make()`) |
| 6 | Compiles cleanly (no warnings about ambiguity, infinite recursion, deprecation) |

Verification: `swift build` (debug) for each experiment captured to `Outputs/build.txt`; binary execution exit code captured to `Outputs/run.txt`. Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102), macOS 26.2 (arm64).

---

## 3. Approach Matrix

| # | Approach | (1) Type ID | (2) L3 resolves & delegates | (3) Foo() | (4) NO @_spi | (5) NO consumer change | (6) Clean compile | Verdict |
|---|----------|:---:|:---:|:---:|:---:|:---:|:---:|---|
| 1 | `internal import` + `public import` of same module | n/a | n/a | n/a | ✓ | n/a | ✗ (consumer can't see Foo) | REFUTED |
| 2 | Types-only sub-module split at L2 | ✓ | ✗ (recursion) | ✓ | ✓ | ✓ | ✗ (recursion warning) | PARTIAL |
| 3 | `@_implementationOnly import` | ✓ | ✗ (recursion) | ✓ | ✓ | ✓ | ✗ (recursion + deprecated) | REFUTED |
| 4 | `@_disfavoredOverload` on L2 | ✓ | ✗ (recursion in L3 body) | ✓ | ✓ | ✓ | ✗ (recursion warning) | REFUTED |
| 5 | Sub-namespace at L3 (`Foo.Policy.make()`) | ✓ | ✓ | ✓ | ✓ | ✗ (call shape changes) | ✓ | PARTIAL |
| 6 | Protocol extension | ✓ | ✓ | ✓ | ✓ | ✗ (call shape changes — different method name) | ✓ | PARTIAL |
| 7 | rule-legal-demo / rule-law-demo precedent | — | — | — | — | — | — | NO PRECEDENT |
| 8 | `@_spi(Syscall)` at L2 (the Wave 3.5-Corrective baseline) | ✓ | ✗ (recursion in L3 body) | ✓ | ✗ | ✓ | ✗ (recursion warning) | REFUTED |
| 9 | Sub-namespace at L2 (`Foo.Syscall.make()`, single nominal type) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | CONFIRMED (fallback) |
| 10 | **Distinct L2/L3 top-level namespaces (no typealias)** | ✓† | ✓ | ✓ | ✓ | ✓ | ✓ | **CONFIRMED — primary** |

† For approach 10, type identity is preserved *at consumer* (via `Kernel.File = POSIX.Kernel.File` typealias on the unifier namespace), not via a chain to L1. iso-9945's struct and POSIX's struct are distinct types; conversion at the L2/L3 boundary is internal to swift-posix.

Per-approach evidence: each `Experiments/l3-policy-layering-approach-N-*/Sources/*/main.swift` carries a result block with build/runtime evidence and the criterion outcome.

---

## 4. Critical Finding: Wave 3.5-Corrective is Runtime-Broken

The handoff stated that the existing Wave 3.5-Corrective pattern *"achieves (1) and (2) but introduces ~20 net-new `@_spi(Syscall) public` typed methods at L2."* Empirical verification refutes the (2) claim: the pattern compiles cleanly in isolation, but the L3-policy method's body call to L2 does NOT actually delegate — it resolves to the L3 method itself, infinitely recursing.

**Evidence at the experiment level** (`l3-policy-layering-approach-8-spi-baseline`):

```
warning: function call causes an infinite recursion
  L3Policy/Foo+policy.swift:5
    let l2 = try Foo.make()
                     `- warning: function call causes an infinite recursion
```

Runtime: `EXIT: 139` (SIGSEGV — stack overflow from infinite self-recursion).

**Evidence at the production level** (clean build of `swift-foundations/swift-posix` target *POSIX Kernel File* on 2026-05-02):

```
warning: function call causes an infinite recursion
  POSIX.Kernel.File.Open.swift:97
        return try ISO_9945.Kernel.File.Open.open(
                                          `- warning: function call causes an infinite recursion
```

The Wave 3.5-Corrective-2 commit `d8c5877` for File.Open landed broken delegation. The Stats analogue (commit `0c3545a`, structurally identical with simpler body — pure pass-through, no retry loop) is presumed broken in the same way; runtime exercise has not yet exposed the regression because no test path invokes `Kernel.File.Stats.get(...)` from the policy entry. Wave 3.5-Corrective-3 (Memory.Map) and -4 (Time) are queued for the same pattern and would inherit the same defect.

**Why the pattern fails**: Within swift-posix's module, two declarations of `static func open(...)` exist on the same nominal type `ISO_9945.Kernel.File.Open`:

1. iso-9945's `@_spi(Syscall) public static func open(...)` — visible because swift-posix imports with `@_spi(Syscall) public import ISO_9945_Kernel_File`
2. swift-posix's local `extension ISO_9945.Kernel.File.Open { public static func open(...) }`

When swift-posix's body writes `try ISO_9945.Kernel.File.Open.open(...)`, Swift's overload resolution sees both candidates with identical signatures. Same-module declarations win over imported declarations in overload resolution; `@_spi(Syscall)` does NOT participate in this preference (it gates *external* visibility, not internal preference between module-local and module-imported candidates). The local L3 declaration wins → the method calls itself → stack overflow.

**Why Wave 3.5-Corrective wasn't caught earlier**: the `swift build` of swift-posix's *POSIX Kernel File* target succeeds. The recursion warning appears in the build output but does not error. The runtime regression manifests only when a consumer actually invokes `Kernel.File.Open.open(...)` *through the policy path*; consumers that bypass the wrapper (e.g., calling iso-9945's SPI form directly) don't trigger it. swift-posix's own test surface presumably doesn't exercise the `open` policy method path, masking the defect.

**Relationship to the [PLAT-ARCH-008e] disambiguation invariant** (`reflection 2026-04-20-l2-l3-same-signature-latent-ambiguity.md`, lines 138–148):

> when the L2-raw method name equals the L3-unifier method name on the same type, the L3 unifier cannot land alongside the L2 raw without a disambiguation mechanism (rename one side, demote L2's module visibility, @_disfavoredOverload, or equivalent). The mechanism is not optional.

Wave 3.5-Corrective uses `@_spi(Syscall)` as the disambiguation mechanism, but `@_spi(Syscall)` is NOT actually a disambiguation mechanism for this purpose — it is a visibility mechanism. The reflection's "demote L2's module visibility" framing was already known to require something stronger than `@_spi(Syscall)` (the same reflection notes `@_spi(Syscall)` + `@inlinable` is structurally incompatible). The current corrective pattern is the rejected `.Raw.` sub-namespace problem under a different name: it tries to disambiguate via attribute-based visibility, but Swift's overload resolution doesn't consult `@_spi` at the disambiguation step.

---

## 5. Per-Approach Findings

### Approach 1 — `internal import L2Methods` + `public import L2Methods`

Build: L3Policy compiles; consumer fails with `error: cannot find 'Foo' in scope`. The `public import L2Methods` makes L2Methods part of L3Policy's API stability surface but does NOT re-export L2Methods's exported symbols (Foo, FooError) into the consumer's name resolution scope. To re-export, the import must be `@_exported public import` — but adding `@_exported` makes L2Methods's `make()` visible to consumers, returning to approach 8's collision.

**What it rules out**: There is no Swift import-attribute combination that (a) lets L3's body see L2's methods AND (b) does NOT re-export those methods to consumers. `public import` without `@_exported` doesn't re-export at all (consumer can't see types). Swift's import system has no "types-only re-export" granularity; that granularity must come from packaging (see approach 2: types-only module split).

### Approach 2 — Types-only module split at L2

Split L2 into two sub-modules: L2Types (struct only, no methods) and L2Methods (extension with typed methods). L3 publicly re-exports L2Types via `@_exported public import L2Types` (so consumers see the struct) but only `internal import L2Methods` (so consumers don't see the methods). Then L3 declares its own same-signature method.

Result: warning *"function call causes an infinite recursion"* at the L3 body call site; runtime SIGSEGV. The split addresses CONSUMER-side visibility correctly (consumer's `Foo.make()` sees only L3's method, no L2 candidate to confuse it). But the L3-internal delegation still fails — inside L3's module, both L2Methods's extension on Foo and L3's local extension are visible (the latter via the internal import), and Swift picks the local declaration as the closer candidate.

**What it rules out**: The types-only module split is *necessary* for hiding L2's methods from consumers without `@_spi` but is NOT sufficient for L3-delegates-to-L2. The split changes nothing about overload resolution within L3.

### Approach 3 — `@_implementationOnly import`

Two warnings: the same recursion warning AND a deprecation warning [#ImplementationOnlyDeprecated]. `@_implementationOnly import` is the older, stricter form of what `internal import` provides; Swift 5.9+ deprecates it in favor of `internal import`. Behaviorally identical to approaches 1 and 2 for our case — same recursion at L3 body. Doubly disqualified.

### Approach 4 — `@_disfavoredOverload` on L2

L2's typed method gets `@_disfavoredOverload`; L3's same-signature method does not. Hypothesis: at consumer sites with both visible, Swift selects L3 (non-disfavored). Within L3's module, L2's imported declaration is disfavored, L3's local is preferred — L3's body call resolves to the local non-disfavored.

Result: same recursion at L3 body. `@_disfavoredOverload` addresses overload resolution PREFERENCE but does not change the fact that within L3's module, L3's own non-disfavored declaration is the closest candidate. The disfavored modifier helps consumers pick the right method but does not provide a disambiguation path for L3's body to reach L2.

### Approach 5 — Sub-namespace at L3 (`Foo.Policy.make()`)

L3 declares its policy method at `Foo.Policy.make()` rather than `Foo.make()`. Build clean; runtime success: `Foo.make()` returns L2's value, `Foo.Policy.make()` returns L3-wrapped value. All criteria pass *except* (5): consumers must migrate every `Foo.make()` to `Foo.Policy.make()` to opt into the policy. For the production case, this means `Kernel.File.Stats.get(...)` becomes `Kernel.File.Stats.Policy.get(...)`, with a per-name consumer cascade across swift-kernel, swift-memory, swift-file-system, etc.

Useful as a fallback if no criterion-(5)-respecting alternative survives principal review.

### Approach 6 — Protocol extension

A protocol declares the policy method (with a *different* method name than L2's, e.g., `makeWithPolicy` vs `make`). L3's protocol-extension default forwards to the conforming type's `Self.make()`. Result: works mechanically, but criterion (5) fails for the same reason as approach 5 — the protocol method must use a different name from the type method (protocol extensions do NOT shadow type extensions of the same name; type-extension methods take priority at dispatch). Equivalent to approach 5 in trade-off.

### Approach 7 — rule-legal-demo / rule-law-demo precedent

Documentation-only investigation. Grep results:

```
$ grep -rln "@_spi\|@_implementationOnly\|@_disfavoredOverload\|@_exported" \
    /Users/coen/Developer/rule-legal/ /Users/coen/Developer/rule-law/
```

Findings: only `@_exported import` for the standard re-export chain pattern (`[PLAT-ARCH-006]`). No `@_spi`, no `@_implementationOnly`, no `@_disfavoredOverload`. The legal architecture's four layers (Namespace, Legislature, Judiciary, Composition, Products) compose ADDITIVELY — each layer adds NEW types/methods on NEW namespaces. The Layer N package never overrides Layer N-1's same-signature method on the same type. The recalled precedent does not address the same-name method-wrapping problem.

### Approach 8 — `@_spi(Syscall)` baseline (Wave 3.5-Corrective pattern)

REFUTED. See § 4 for the complete analysis.

### Approach 9 — Sub-namespace at L2 (`Foo.Syscall.make()`) — fallback for single-nominal-type case

L2 declares its typed method at a sub-namespace inside `Foo` (`Foo.Syscall.make()`) rather than on `Foo` directly. L3 declares its user-facing method at `Foo.make()` directly. The two declarations occupy different namespace paths: only L2 declares at `Foo.Syscall.make()`, only L3 declares at `Foo.make()`. No same-signature collision at any step of overload resolution.

Build: clean, no warnings.
Runtime:
```
Foo.make() = L3(L2.Syscall)              # L3 wraps and delegates correctly
Foo.Syscall.make() = L2.Syscall          # power-user can still reach raw L2
Type identity preserved: L3(L2.Syscall)
EXIT: 0
```

All six criteria PASS. The pattern is structurally identical to [PLAT-ARCH-008f] solution family (c) "Sub-namespace on L2".

**This approach assumes a typealiased single nominal type for both L2 and L3** — i.e., the Wave 3.5-Corrective shape with `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats`. Within that constraint, sub-namespace at L2 disambiguates correctly. **For the production case, the typealias itself is the problem** — see approach 10 for the structurally cleaner answer where the typealias is dropped.

### Approach 10 — Distinct L2/L3 top-level namespaces (no typealias) — **PRIMARY RECOMMENDATION**

L2 owns `ISO_9945.Kernel.File.Stats` as its own struct with its own methods, coded naturally as the POSIX `struct stat` mirror — no `@_spi`, no sub-namespace, no awareness of any downstream layer. L3 owns `POSIX.Kernel.File.Stats` as a distinct struct (with the necessary field shape — copied from L2's struct, or wrapping it as a stored property) with its own policy methods. **No typealias** between `POSIX.Kernel.File.Stats` and `ISO_9945.Kernel.File.Stats` — they are different nominal types.

Conversion at the L2/L3 boundary is internal to swift-posix's body:

```swift
extension POSIX.Kernel.File.Stats {
    public static func get() throws(FooError) -> POSIX.Kernel.File.Stats {
        // EINTR retry policy here in production
        let l2 = try ISO_9945.Kernel.File.Stats.get()
        return POSIX.Kernel.File.Stats(from: l2)   // internal init(from l2: ISO_9945...)
    }
}
```

Build: clean, no warnings.
Runtime:
```
ISO_9945.Kernel.File.Stats.get() = size=1024 perms=644
POSIX.Kernel.File.Stats.get() = size=1024 perms=644
Kernel.File.Stats.get() = size=1024 perms=644      # via Kernel.File = POSIX.Kernel.File flip
Type via Kernel.File.Stats: size=1024
EXIT: 0
```

All six criteria PASS. The L3-unifier flip (`Kernel.File = POSIX.Kernel.File` at swift-kernel) is a typealias on the cross-platform UNIFIER namespace, not between `POSIX.*` and `ISO_9945.*` — preserving per-layer namespace independence.

**Why this is structurally cleaner than approach 9**:

- The `ISO_9945.*` and `POSIX.*` top-level namespaces *already exist* as the L2/L3 separation in the production ecosystem. Approach 10 uses what's already there. Approach 9 introduces a *new* sub-namespace (`.Syscall.`) inside the L2 type to recreate that separation at a finer grain — redundant with the existing top-level structure.
- iso-9945 codes the spec-literal POSIX form naturally, with no compromises for downstream needs. No `@_spi`, no sub-namespacing, no disambiguation modifiers. The user's framing: *"lower level (l2) coded without regard to downstream"*.
- swift-posix presents whatever public API surface IT wants. Independent type definition. Independent method shape. The user's framing: *"upstream presents its public API as it wants"*.
- Same structural shape Wave 3.5-1..8 already established for the 37 non-corrective namespaces (distinct enum at POSIX). For the 4 corrective namespaces (Stats, Open, Memory.Map, Time), the disposition is the same — declare a distinct struct at POSIX. Wave 3.5-1's mistake was using a fresh enum where a fresh struct was needed; Wave 3.5-Corrective overcorrected by introducing the typealias chain.

**Trade-off**: conversion at the L2/L3 boundary. For `Stats` (10–11 fields per the POSIX struct), the conversion is one `init(from l2:)` per corrective namespace — ~10 lines of field copies, contained inside swift-posix. With whole-module optimization, the conversion is typically free at runtime. Alternatively, swift-posix's struct can wrap iso-9945's struct as a stored property with field-forwarding accessors (`var size: Int64 { _underlying.size }`) — also free at runtime, and forward-compatible if iso-9945 adds fields.

**What it confirms**: The typealias chain `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats` is the actual cause of Wave 3.5-Corrective's recursion. Without the typealias, no same-signature collision is possible — the two types are distinct nominal types and Swift's overload resolution sees them as different. The disambiguation problem dissolves entirely; no `@_spi`, no sub-namespace, no disfavored overloads, no import attribute dance needed.

---

## 6. The Distinct-Namespaces Pattern in the Production Topology

Applied to the four corrective namespaces:

```swift
// At iso-9945 — natural spec-literal form, no @_spi, no sub-namespacing:
extension ISO_9945.Kernel.File.Stats {
    // The POSIX `struct stat` mirror, declared at L2's spec namespace.
    // Coded WITHOUT REGARD to any downstream layer.
}

extension ISO_9945.Kernel.File.Stats {
    public static func get(descriptor: borrowing ISO_9945.Kernel.Descriptor)
        throws(ISO_9945.Kernel.File.Stats.Error) -> ISO_9945.Kernel.File.Stats {
        try unsafe Self.get(fd: descriptor._rawValue)
    }
    // ... + the path / lget / unsafePath overloads, plain public.
}

// At swift-posix — declare a DISTINCT struct in POSIX namespace.
// No typealias. POSIX.Kernel.File.Stats is its own nominal type.
public import ISO_9945_Kernel_File   // ordinary public import — typed forms re-exported

extension POSIX.Kernel.File {
    public struct Stats: Sendable, Equatable {
        public let size: Int64
        public let permissions: UInt16
        // ... whatever field shape swift-posix wants to present.

        // Internal conversion at the L2/L3 boundary. Contained inside swift-posix.
        internal init(from l2: ISO_9945.Kernel.File.Stats) {
            self.size = l2.size
            self.permissions = l2.permissions
            // ... per-field copy; alternatively wrap as stored property.
        }
    }
}

extension POSIX.Kernel.File.Stats {
    public static func get(descriptor: borrowing POSIX.Kernel.Descriptor)
        throws(POSIX.Kernel.File.Stats.Error) -> POSIX.Kernel.File.Stats {
        // EINTR retry policy lives here in production.
        let l2 = try ISO_9945.Kernel.File.Stats.get(descriptor: descriptor)
        return POSIX.Kernel.File.Stats(from: l2)
    }
}

// At swift-kernel (L3-unifier) — typealias on the cross-platform Kernel namespace.
// This typealias is on the UNIFIER namespace, NOT between POSIX.* and ISO_9945.*.
extension Kernel.File {
    public typealias Stats = POSIX.Kernel.File.Stats
}
```

Consumer call shapes:

| Use case | Call shape (after L3-unifier flip) |
|----------|-----------------------------------|
| Default — policy-wrapped (typical consumer) | `Kernel.File.Stats.get(descriptor:)` → resolves to `POSIX.Kernel.File.Stats.get(...)` |
| Power-user — raw spec-literal syscall | `ISO_9945.Kernel.File.Stats.get(descriptor:)` (already exists at the spec namespace) |
| L3 layer-specific | `POSIX.Kernel.File.Stats.get(descriptor:)` (also reachable directly) |

For Open with EINTR retry, the L3 body becomes:

```swift
extension POSIX.Kernel.File.Open {
    public static func open(...) throws(...) -> POSIX.Kernel.Descriptor {
        while true {
            do throws(...) {
                let l2Descriptor = try ISO_9945.Kernel.File.Open.open(...)
                return POSIX.Kernel.Descriptor(from: l2Descriptor)
            } catch {
                if case .platform(let primitiveError) = error,
                   primitiveError.code.isInterrupted {
                    continue
                }
                throw error
            }
        }
    }
}
```

The recursion is gone because `ISO_9945.Kernel.File.Open.open(...)` and `POSIX.Kernel.File.Open.open(...)` are methods on **distinct nominal types** — Swift's overload resolution sees them as completely unrelated functions; no candidate-collision is even possible.

### Architectural alignment with existing skill rules

- **[PLAT-ARCH-008e]** (L3-unifier composition discipline): Approach 10 IS the natural execution of "L3-policy adds policy on top of L2's typed API." L3-policy declares its own type, composes by calling L2's typed API, applies policy in the body. The composition relationship is value-level (call + convert), not type-level (typealias).
- **[PLAT-ARCH-008j]** (Platform-C Import Authority — L2 Exclusive): Approach 10 is fully compatible. L2 owns the libc/WinSDK call; L3 reaches L2 via L2's typed throwing API; no platform-C imports leak into L3.
- **[PLAT-ARCH-018]** (Typealiased namespace-path conflict): Approach 10 *avoids* the rule's failure mode entirely by not introducing a typealias between the L2 type and the L3 type. The rule continues to apply to anyone who tries — but the corrective namespaces stop trying.
- **Wave 3.5-1..8 architectural consistency**: For the 37 non-corrective namespaces, the established pattern is "fresh enum at POSIX with method wrappers." For the 4 corrective namespaces (struct-shape rather than enum-shape), the structurally analogous disposition is "fresh struct at POSIX with method wrappers" — exactly what approach 10 implements. Wave 3.5-Corrective deviated to the typealias chain because it confused "type identity" with "single nominal type"; the L3-unifier flip provides type identity at consumer sites without requiring a single nominal type at the L2/L3 layer.

### Comparison with Phase A rename and approach 5/9

| Mechanism | What it changes | Cost |
|-----------|-----------------|------|
| Phase A rename ([PLAT-ARCH-008f] solution (a)) | L2's method name (e.g., `flush` → `fsync`) | Method-level rename per name; awkward when L2's name *is* the POSIX man-page name |
| Approach 5 — L3 sub-namespace | Consumer call shape (`get` → `Policy.get`) | Per-call-site consumer migration |
| Approach 9 — L2 sub-namespace | L2 internal organisation (`get` → `Syscall.get`) | Single mechanical rule at L2; preserves typealias chain |
| **Approach 10 — distinct types** | L2/L3 type identity is per-layer (not shared) | One conversion init per corrective type, contained inside swift-posix |

Approach 10's cost is the conversion init — for the corrective four, this is one `init(from l2:)` per type, ~10 lines of field copies. Whole-module optimization usually elides the copy at runtime. Alternatively, swift-posix's struct can wrap iso-9945's struct as a stored property (`var size: Int64 { _underlying.size }`) — same runtime cost, plus forward-compatibility if iso-9945 adds fields.

The conversion site is the *only* place inside swift-posix that knows about the L2/L3 boundary. Consumers see only their own layer's types. Power-users who want raw L2 access reach into `ISO_9945.*` directly — which already exists naturally as the spec namespace; no special opt-in (no `@_spi`, no sub-namespace) needed.

### Why the typealias was the wrong tool

Wave 3.5-Corrective adopted the typealias chain `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats` to preserve struct identity across the L2/L3 boundary. The reasoning: consumer code carries `let s: Kernel.File.Stats` annotations; if `POSIX.Kernel.File.Stats` is a different struct from iso-9945's, the consumer's type annotation breaks.

This reasoning is correct in mechanism but wrong in scope. Type identity at the **consumer level** (where `Kernel.File.Stats` is referenced) is established by the L3-unifier typealias `Kernel.File.Stats = POSIX.Kernel.File.Stats`. That typealias is on the cross-platform unifier namespace, not the per-layer L2/L3 boundary. Once the L3-unifier flip is in place, the consumer's `Kernel.File.Stats` resolves through `POSIX.Kernel.File.Stats` to a single concrete struct — there's no "different struct" problem to solve.

The typealias `POSIX.Kernel.File.Stats = ISO_9945.Kernel.File.Stats` was solving a problem that the L3-unifier flip already solves. That redundancy collapsed two layers' namespaces into a single nominal type, which (per [PLAT-ARCH-018]) made every `extension POSIX.Kernel.File.Stats` declaration land on `ISO_9945.Kernel.File.Stats` — creating the same-signature collision that the `@_spi` disambiguation was then introduced to paper over.

Approach 10 simply removes the L2/L3-boundary typealias. Type identity at consumer is preserved by the L3-unifier typealias (which already exists). L2 and L3 own their own types. The same-signature collision is structurally impossible.

---

## 7. Recommendation

**Primary recommendation**: revert the Wave 3.5-Corrective `@_spi(Syscall) public` adoption AND drop the typealias chain `POSIX.Kernel.File.X = ISO_9945.Kernel.File.X` for the four corrective namespaces. Migrate to **approach 10** — distinct L2/L3 top-level types — with conversion at the L2/L3 boundary internal to swift-posix.

**Action sequence** (subject to principal authorization per `feedback_no_public_or_tag_without_explicit_yes.md`):

1. **Revert at iso-9945** (commits to undo: `2aed9ad` for Stats, `cb053e5` for Open; no equivalent commit yet for Memory.Map or Time):
   - Remove `@_spi(Syscall)` modifier from the typed methods.
   - Methods stay at the natural namespace path (e.g., `ISO_9945.Kernel.File.Stats.get(descriptor:)`). No sub-namespace introduction.
   - Internal `get(fd:)` / `get(unsafePath:)` raw helpers stay at file-private scope inside iso-9945 (per [PLAT-ARCH-008j]).
   - Net effect at iso-9945: code returns to the pre-Wave-3.5-Corrective shape — plain `public` typed methods, no awareness of any downstream layer.

2. **Restructure at swift-posix** (commits to revise: `0c3545a` for Stats, `d8c5877` for Open):
   - Remove `@_spi(Syscall)` modifier from `public import ISO_9945_Kernel_File` (now plain `public import`).
   - **Replace the typealias** `extension POSIX.Kernel.File { public typealias Stats = ISO_9945.Kernel.File.Stats }` with a **distinct struct declaration** at `POSIX.Kernel.File.Stats`. Field shape: copy iso-9945's struct fields, OR wrap as stored property — either choice is acceptable; prefer wrap-as-stored-property for forward-compat if iso-9945 adds fields (see § 6 trade-off discussion).
   - Add `internal init(from l2: ISO_9945.Kernel.File.Stats)` boundary conversion inside swift-posix.
   - L3-policy method bodies (`POSIX.Kernel.File.Stats.get(descriptor:)`, `POSIX.Kernel.File.Open.open(...)`, etc.) delegate via plain `try ISO_9945.Kernel.File.X.method(...)` — no `.Syscall.` sub-namespace, no `@_spi`, no disambiguation modifier needed. Cross-type call resolves cleanly because the local `POSIX.*` and imported `ISO_9945.*` types are distinct nominal types.
   - The L3-unifier typealias at swift-kernel (`extension Kernel.File { public typealias Stats = POSIX.Kernel.File.Stats }`) **remains unchanged** — it already typealiases the user-facing `Kernel.*` namespace to the corresponding POSIX type. With approach 10, the unifier typealias resolves to swift-posix's distinct struct, preserving consumer call shape `Kernel.File.Stats.get(...)`.

3. **Verify runtime**: build swift-posix's *POSIX Kernel File* target with `swift build --build-tests`; confirm zero recursion warnings. Add at least one regression test per corrective namespace that exercises the policy method's runtime path (Stats.get with valid descriptor, Open.open with valid path, etc.) to catch any future re-introduction of the recursion class.

4. **Apply uniformly to Wave 3.5-Corrective-3 (Memory.Map) and -4 (Time)**: the not-yet-landed cycles use the distinct-type pattern from inception, avoiding the broken pattern entirely.

5. **Codify in the platform skill**: add provenance link and worked example to [PLAT-ARCH-008f] documenting approach 10 as the canonical pattern when L2 and L3 share a struct-shape type-name. Strengthen [PLAT-ARCH-008e] / [PLAT-ARCH-018] guidance: typealiased namespace-path collapse is the actual cause of same-signature collisions; the structural answer is to keep L2 and L3 as distinct nominal types with conversion at the boundary, not to disambiguate via `@_spi` (which is a visibility mechanism, not a disambiguation mechanism).

**Fallback if principal rejects approach 10**: approach 9 (L2 sub-namespace, `ISO_9945.Kernel.File.Stats.Syscall.get(...)`). Mechanically clean and verified; preserves the typealias chain. The disposition question becomes whether the prior `.Raw.` rejection generalizes to all L2 sub-namespacing — see § 8.

**Second fallback if both 10 and 9 are rejected**: approach 5 (L3 sub-namespace, `Kernel.File.Stats.Policy.get(...)`). Per-call-site consumer migration; no `@_spi` reintroduction.

**Not recommended**: continuing Wave 3.5-Corrective with the `@_spi(Syscall)` pattern. The pattern is provably runtime-broken; landing Memory.Map and Time in the same shape would extend the regression to two more namespaces and increase the eventual revert cost.

### Comparison: approach 10 vs approach 9 in production cost

| Concern | Approach 10 (distinct types) | Approach 9 (L2 sub-namespace) |
|---------|------------------------------|-------------------------------|
| iso-9945 modification | Revert `@_spi` only — back to pre-Corrective shape | Revert `@_spi` AND nest typed methods under `.Syscall` |
| swift-posix modification | Replace typealias with distinct struct + boundary init | Update method body delegations to `.Syscall.` paths; typealias unchanged |
| Power-user access to raw L2 | Already exists at `ISO_9945.Kernel.File.Stats.get(...)` (the spec namespace) | New path `ISO_9945.Kernel.File.Stats.Syscall.get(...)` |
| Architectural consistency with non-corrective 37 | High — same "distinct type at POSIX" shape, just struct rather than enum | Lower — L2 sub-namespace is a 4-namespace-only mechanism not used elsewhere |
| Runtime conversion cost | One `init(from:)` per corrective type (~10 lines) | None |
| Codification in skill | New canonical pattern | Promotes [PLAT-ARCH-008f] family (c) from "one of four" to "preferred for struct-shape" |

The principal's framing — *"lower level (l2) coded without regard to downstream"* — favors approach 10 strictly: with approach 10, iso-9945 is *literally* coded without regard to downstream (no sub-namespace decision required). With approach 9, iso-9945 still must make a downstream-driven choice (nest methods under `.Syscall.` so swift-posix can declare same-name methods at the typealiased path).

---

## 8. Open Questions for Principal

1. **POSIX struct field shape — copy vs wrap** — for each of the four corrective namespaces (Stats, Open, Memory.Map, Time), should `POSIX.Kernel.File.X` *copy* iso-9945's struct fields directly into its own struct, or *wrap* iso-9945's struct as a stored property (`var _underlying: ISO_9945.Kernel.File.X`) with field-forwarding accessors? Trade-off: copy is simpler at the boundary; wrap is forward-compat if iso-9945 adds fields (no per-field-add change at swift-posix). Current recommendation: wrap-as-stored-property for forward-compat, but principal preference may differ. May also legitimately differ per namespace (e.g., Stats wraps because POSIX `struct stat` evolves with platform extensions; Time copies because the field set is fixed by POSIX spec).

2. **Field accessor surface at POSIX** — when `POSIX.Kernel.File.Stats` wraps iso-9945's struct, which fields does swift-posix expose as public properties? Mirror iso-9945 1:1, OR present a curated subset / renamed shape (e.g., `Stats.modifiedAt: Time` instead of `Stats.mtim: timespec`)? The user's framing — *"upstream presents its public API as it wants"* — is a license, not a directive; principal disposition needed on whether swift-posix actually exercises that license or stays mirror-shape for predictability.

3. **Existing Wave 3.5-Corrective regression — disposition timing** — Stats (commit `0c3545a`) is presumed broken at runtime (warning: function call causes infinite recursion under clean build, structurally identical shape to Open which is empirically broken). Open (`d8c5877`) is empirically broken. Should the regression be flagged as P0 (immediate revert before any further dispatch) or absorbed into the migration to approach 10 (the migration revert is structurally larger but lands as one coherent commit chain)?

4. **Memory.Map and Time disposition timing** — these were queued for the Wave 3.5-Corrective pattern. Pause the dispatch pending principal disposition on this recommendation, or proceed and migrate them in the same revert cycle?

5. **Codification scope** — should approach 10 (distinct L2/L3 top-level types with boundary conversion) be added to [PLAT-ARCH-008f] solution families as a fifth option, OR promoted to "preferred default for struct-shape namespaces" (with the existing four families remaining for namespace-enum-shape and special cases)? The 37 non-corrective Wave 3.5 namespaces already use the analogous pattern (distinct enum at POSIX); approach 10 is the struct-shape generalization. Codifying it as a uniform structural rule (distinct type at POSIX, regardless of enum vs struct shape) would simplify [PLAT-ARCH-008f] from a four-options-decision-tree to a single rule plus boundary-conversion guidance.

6. **Legacy approach 9 disposition** — keep approach 9 (L2 sub-namespace, `.Syscall.`) as a documented fallback for any future case where a single nominal type is genuinely required, OR remove it from the family of acceptable patterns? Approach 10 dominates approach 9 on the principal's "l2 coded without regard to downstream" criterion. The only case where approach 9 wins is if some future pattern *requires* type identity at the L2/L3 boundary (not just at consumer level via L3-unifier). No such case exists in the current ecosystem, but principal may have foresight on hypothetical future needs.

---

## 9. Provenance

- Companion experiments: `swift-institute/Experiments/l3-policy-layering-approach-{1..10}/` (10 experiment packages, each with `Package.swift` + minimal L1/L2/L3/Consumer source + `Outputs/{build,run}.txt` receipts)
  - Approach 10 (`l3-policy-layering-approach-10-distinct-l2-l3-namespaces`) is the primary recommended pattern — verified 2026-05-02, all six criteria PASS, runtime EXIT 0 with three-way call-shape verification (`ISO_9945.*`, `POSIX.*`, `Kernel.*`).
- Audit doc: `swift-institute/Audits/post-path-x-architecture-review-2026-04-30.md` (Wave 3.5 envelope, Wave 3.5-Audit catalogue, Corrective queue)
- Reflections referenced:
  - `Research/Reflections/2026-04-20-l2-l3-same-signature-latent-ambiguity.md` ([PLAT-ARCH-008e] disambiguation invariant; Phase A precedent)
  - `Research/Reflections/2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md` (`.Raw.` rejection at lines 89–90; `@_spi + @_inlinable` incompatibility)
  - `Research/Reflections/2026-04-20-kernel-file-flush-plat-arch-008e-execution.md` (Flush Phase A precedent)
- Skill rules cited: [PLAT-ARCH-008e], [PLAT-ARCH-008f], [PLAT-ARCH-008j], [PLAT-ARCH-012], [PLAT-ARCH-018], [API-NAME-003]
- Prior research: `Research/spi-syscall-phase-out-layering.md` (V2-only disposition, RECOMMENDATION 2026-04-30); `Research/file-handle-writeall-l2-l3-layering.md` (related L2/L3 layering options matrix)
- Production code verified: `swift-foundations/swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Open.swift:97` (recursion warning under clean build, 2026-05-02)
- Principal feedback (this session, post-initial-recommendation): *"so I don't want *.Syscall.*, but doesn't ISO_9945.* and POSIX.* achieve the same? where ISO_9945.* is l2 (*.Syscall) and POSIX.* is l3 (*.*). I think it's important to note that I'd like lower level (l2) to be coded without regard to downstream. and STILL have upstream be able to present its public API as it wants"* — drove the pivot from approach 9 (sub-namespace) to approach 10 (distinct top-level namespaces) as primary recommendation.
- Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102), macOS 26.2 (arm64), Xcode default toolchain
