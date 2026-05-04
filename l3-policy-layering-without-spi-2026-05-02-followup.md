# L3-Policy Layering — Tagged + Carrier Pattern (Followup)

**Status**: RECOMMENDATION (§ 7 primary recommendation refuted at production scale 2026-05-02; see Status update below)
**Date**: 2026-05-02
**Supersedes**: § 7 of `l3-policy-layering-without-spi-2026-05-02.md` (approach 10 demoted from primary; approaches 12+13 were the new primary recommendation prior to the post-experiment update)
**Companion experiments**: `swift-institute/Experiments/l3-policy-layering-approach-{11,12,13}/` + `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/`
**Production precedent**: `rule-law-us-nv/Sources/Rule Law US Nevada/Rule Law US Nevada.swift:41-57`

---

## Status update 2026-05-02 (post-experiment)

The Wave 3.5-Corrective L3-policy migration that adopted approach 12+13
per § 7 of this doc surfaced a Swift compiler gap that refutes the
recommendation at production scale: **Swift's nested-type lookup on
constrained extensions of generic types does not consult the where-clause
as a discriminator at name-resolution time.** Two
`extension Tagged where Tag == X, RawValue == Y { typealias Error = ... }`
declarations on disjoint instantiations BOTH appear as candidates for
`Tagged<concrete, concrete>.Error` lookup at every consumer site,
producing an ambiguity error in any package that imports more than one
leg.

This means the followup's § 7 dispatch instructions and § 9 ecosystem-
wide generalization table cannot be applied uniformly: any namespace
that requires per-layer error type customization (which approach 12+13's
template prescribes via per-leg `.Error` typealiases) hits the
ambiguity at every cross-platform consumer that imports two or more
legs. The migration agent pivoted to *Path β* — fresh-enum-at-L3 with
explicit per-layer error types — for the four corrective namespaces
(Stats, Open, Memory.Map, Time).

**Empirical confirmation** (CONFIRMED 2026-05-02 on swift 6.3 system
default, macOS 26 arm64):
`swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/`
— 4-target SwiftPM package; verbatim diagnostic in `Outputs/build-debug.txt`:

```
error: ambiguous type name 'Error' in 'Tagged<TagA, RawA>'
note: found candidate with type 'Tagged<TagA, RawA>.Error' (aka 'NestedAError')
note: found candidate with type 'Tagged<TagA, RawA>.Error' (aka 'NestedBError')
```

**Prior-art investigation**: see
[`swift-constrained-extension-nested-type-lookup-gap.md`](swift-constrained-extension-nested-type-lookup-gap.md)
(RECOMMENDATION 2026-05-02, tier 3) — maps the Swift-side prior art
(SR-5440 / #48014 closed for the wrong-base case; SR-7516 / #50058 open
since 2018; PR #17168 "We don't validate conditionality for decls at all
yet"; Latsis 2020 forum quote "we are not supposed to support this kind
of conditional type member overloading"), the four-language cross-
language survey (Rust, C++, Haskell, Scala 3 — all discriminate at
lookup; Swift's gather-all-candidates-by-name approach is unique among
them), and the workaround analysis (V5/V6 give up per-layer error
customization; V7 breaks the `.Error` naming convention; V8 relies on
unsustainable single-leg-import discipline; Path β is the principled
answer for the foreseeable future).

**Effect on this doc's recommendations**:

- § 7 (action sequence for the four corrective namespaces): **superseded
  for any namespace requiring per-layer error type customization**. Path β
  (fresh-enum-at-L3) is the canonical disposition. The 7.2 / 7.3 / 7.4
  templates remain valid as a *reference* shape for Tagged + Carrier
  composition where per-layer error customization is NOT required (e.g.,
  the 37 non-corrective Wave 3.5 namespaces that share L2's error type
  unmodified at L3).

- § 6 (Carrier generalization): **partially preserved**. The
  `some Carrier<L2-Type>` cross-cutting helper pattern remains useful
  for any case where the consumer accepts L2's type unmodified at the
  generic boundary. It does not work transparently when L3 wraps L2 via
  Tagged with per-layer error customization, because the per-layer
  `.Error` typealias is the load-bearing element that hits the
  ambiguity.

- § 9 (ecosystem-wide generalization table): **needs per-row review**.
  The "POSIX syscalls" and "Win32 syscalls" rows fall under the
  per-layer-error-customization case → Path β. The "Legal:
  statute/case-law/composed-law" row needs separate review against the
  rule-law/rule-legal architecture; if the layered pattern requires
  per-layer error customization (likely), Path β applies there too.

**Action sequence change**:

| Original (this doc § 7) | Revised (post-experiment) |
|---|---|
| Migrate 4 corrective namespaces to approach 12+13 | Migrate 4 corrective namespaces to Path β (fresh-enum-at-L3 with explicit per-layer error types) |
| Promote approach 12+13 to default for L2/L3 layering | Codify ecosystem rule prohibiting same-name nested typealiases on disjoint constrained extensions of the same generic type (per `swift-constrained-extension-nested-type-lookup-gap.md` Rec 2; codification is a separate skill-lifecycle cycle) |
| Add macro `@CarrierForward` for forwarding accessors | Deferred — accessor pattern only applies where Tagged + per-layer customization works, which is the case Path β supersedes |

Ongoing recommendations from this doc that REMAIN VALID:

- Revert the Wave 3.5-Corrective `@_spi(Syscall) public` adoption at
  iso-9945 (commits `2aed9ad`, `cb053e5`); replace with the Path β
  shape rather than approach 12+13. The § 7.1 revert is still required;
  only the § 7.2 / 7.3 replacement target changes from
  `Tagged<POSIX, ISO_9945....>` to a fresh `POSIX.Kernel.File.Stats`
  enum.

- Add at least one regression test per corrective namespace exercising
  the policy method's runtime path (per § 7.5).

- Pause Memory.Map (-3) and Time (-4) Wave 3.5-Corrective dispatches
  until the Path β migration of Stats and Open lands; pick up the same
  shape from inception (per § 10.4, with disposition revised to Path β).

The two new Open Questions for principal that the post-experiment
update introduces:

1. **Codification timing**: should the ecosystem rule (no same-name
   nested typealiases on disjoint constrained extensions) be codified
   in [PLAT-ARCH-*] before or after the Wave 3.5-Corrective Path-β
   migration completes? Codification first reduces re-discovery risk
   for future cycles; codification after lets the migration's findings
   feed the rule's worked examples.
2. **Upstream filing authorization**: file the discrete
   disjoint-overload-at-matching-base issue against swiftlang/swift?
   The recommendation in `swift-constrained-extension-nested-type-lookup-gap.md`
   Rec 1 is yes (medium severity, framed as forcing function for design
   discussion). The filing itself is a separate authorization step.

The recommendations in §§ 1–6 of this doc (the architectural reasoning
about the principal's "single-source-of-data" constraint, the legal-
architecture precedent, the operation-struct intermediate finding, the
Tagged-with-L2-as-RawValue mechanism, the Carrier generalization, and
the verification matrix) remain accurate as a record of the design-
space exploration. The recommendations in §§ 7–10 (the production
action sequence and ecosystem generalization) are partly superseded as
described above.

---

## 0. Executive Summary

The original investigation (approaches 1–10) recommended **approach 10** — distinct L2/L3 top-level types with conversion at the boundary — as the primary answer. Principal feedback rejected this:

> *"we don't want to have duplicate structs. that's a deal breaker. ... if a struct SHOULD be the same, then we want it to be the same right. Ideally I'd have L1 X, L2 Z.Y, and L3 X.Y. where the methods and functions can be overridden on L3."*

Subsequent investigation of the production legal architecture (`rule-law-us-nv`) revealed the structural answer the principal was reaching for: **operations encoded as struct inits + Tagged-based wrapping at L3 + Carrier conformance for layer-agnostic generic APIs**.

**Revised primary recommendation: approaches 12 and 13 combined.**

```swift
// L2 (iso-9945) — UNCHANGED from current production, plus one Carrier line:
extension ISO_9945.Kernel.File.Stats {
    public init(descriptor: Int32) throws(...) { /* raw fstat */ }
}
extension ISO_9945.Kernel.File.Stats: Carrier {
    public typealias Underlying = Self   // trivial self-carrier
}

// L3-policy (swift-posix) — Tagged typealias + constrained-extension policy:
extension POSIX.Kernel.File {
    public typealias Stats = Tagged<POSIX, ISO_9945.Kernel.File.Stats>
}
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public init(descriptor: Int32) throws(...) {
        // EINTR retry + delegate to L2's init
    }
    public static func get(descriptor: Int32) throws(...) -> Self {
        try Self(descriptor: descriptor)
    }
}

// L3-unifier (swift-kernel) — unchanged shape:
extension Kernel.File {
    public typealias Stats = POSIX.Kernel.File.Stats
}

// Layer-agnostic helpers (anywhere in the ecosystem):
public func describeStats(_ s: some Carrier<ISO_9945.Kernel.File.Stats>) -> String {
    "size=\(s.underlying.size)"
}
// Accepts bare L2, Tagged-wrapped L3, AND Kernel.File.Stats (= Tagged via unifier).
```

The pattern: **L2 stays unchanged; L3 wraps L2 via `Tagged<L3-Namespace, L2-Type>`; cross-cutting consumers go through `some Carrier<L2-Type>`.** It generalizes uniformly across the ecosystem — syscalls, legal architecture, and any future spec/policy layering.

---

## 1. Why Approach 10 Was Rejected

The principal's feedback identified two concerns:

1. **Maintenance**: distinct L2 and L3 structs with parallel field declarations means adding a field at L2 requires a parallel change at L3. Even the wrap-as-stored-property variant requires a forwarding accessor per field.
2. **Identity**: "if a struct SHOULD be the same, then we want it to be the same." A struct semantically representing the same concept across layers should be the same nominal type, not parallel types with structural similarity.

The original document's wrap variant of approach 10 partially addresses (1) — data is single-source at L2 via stored property — but doesn't address (2). The two struct types remain distinct nominal entities.

The principal's framing — *"L1 X, L2 Z.Y, and L3 X.Y where the methods and functions can be overridden on L3"* — points toward override-semantic on a single nominal type, which Swift's value-type extension system doesn't directly support.

---

## 2. Structural Truth (Restated)

Swift's type system has exactly four axes for disambiguating same-name methods on a single nominal type: **distinct types**, **distinct paths** (sub-namespace), **distinct names** (rename), or **distinct signatures**. There is no fifth axis. "Method override on a value type" is not directly expressible — some indirection has to break the symmetry.

The new arc (approaches 11/12/13) doesn't break this rule; it works *with* it by redirecting the discrimination axis from method-paths/names to **operation-as-struct + Tagged-based generic instantiation**, while keeping the API surface unified at the consumer level.

---

## 3. The Legal Architecture Precedent

The principal pointed to `rule-legal-us-nv-private-corporation` and its upstream `rule-law-us-nv` as the canonical pattern. Investigation surfaced two load-bearing properties.

### 3.1 Operations are STRUCTS, not methods

Statutes are encoded as structs whose `init` *is* the operation:

```swift
_ = try `NRS 77`.`310`.`1`.init(
    `the filing states the name of a commercial registered agent`:
        registeredAgent.kind.isCommercial,
    ...
)
```

`NRS 77.310.1` IS the operation. Calling its init evaluates the statute clause. There is no separate "data type with methods on it" — the type and the operation are the same struct.

### 3.2 Composition layer = typealias-by-default + replace-with-wrapping-type-on-override

`rule-law-us-nv/Sources/Rule Law US Nevada/Rule Law US Nevada.swift:41-46`:

> *"Typealiases to legislature packages. When case law or composition logic needs to modify a chapter's behavior, replace the typealias with a custom type that wraps or extends the statute encoding."*

The default state is single-line typealias re-export from L3 to L2. The override state replaces the typealias with a wrapping type. The legal architecture has explicitly DECLARED INTENT for this pattern, but no production override has yet been built (the `swift-nl-hoge-raad` and `swift-us-nv-judiciary` packages are empty as of 2026-05-02).

### 3.3 The disconnect (and its resolution)

The legal architecture's prescription ("replace typealias with custom type") contradicts the principal's "duplicate structs deal-breaker" — a custom wrapping type IS a distinct nominal type. The investigation interpreted this as: the deal-breaker is about field/data duplication and maintenance burden, not the existence of distinct nominal types per se. Approach 12 (Tagged with L2 as RawValue) addresses the data/maintenance concern while preserving the structural property that distinct nominal types remain available for code that needs to discriminate layers.

---

## 4. Approach 11 — Operation-Struct Pattern (intermediate finding)

Direct port of the legal pattern's operation-as-struct shape:

- L2: operation struct (init does syscall; struct holds result fields)
- L3-policy: distinct wrapping struct holding L2 as `_underlying`; init applies retry + delegates to L2
- L3-unifier: SOLE site for the ergonomic method (`static func get`); body calls `Kernel.File.Stats(descriptor:)` (a TYPE INIT, not a method call)

Status: CONFIRMED mechanically. Limitations:
- iso-9945 must restructure from method-style (`Stats.get(descriptor:)`) to operation-struct-style (`Stats(descriptor:)`) — substantial L2 surface change
- Distinct nominal types still exist (same as approach 10 wrap)
- Per-field forwarding accessors at L3

Approach 11 establishes the operation-struct paradigm but pays a significant L2 migration cost. Approach 12 supersedes it.

---

## 5. Approach 12 — Tagged with L2 as RawValue (PRINCIPAL-DISCOVERED)

Principal-suggested formulation (verbatim):

```swift
public typealias `POSIX.Kernel.File.Stats` = Tagged<POSIX, ISO_9945.Kernel.File.Stats>
```

### 5.1 Three structural wins over approach 11

| Win | Mechanism |
|-----|-----------|
| **L2 stays unchanged** | iso-9945's struct shape identical to current production; no migration. |
| **Single source of data** | `Tagged.rawValue` IS L2's struct. Adding a field at L2 propagates automatically — `stats.rawValue.newField` works without any L3 change. |
| **Phantom tag = L3 namespace enum itself** | `POSIX` (existing namespace anchor) doubles as the layer discriminator. No new tag types. Same mechanism extends trivially to Windows: `Tagged<Windows, Windows.\`32\`.Kernel.File.Stats>`. |

### 5.2 Operations via constrained extensions

L3-policy methods live in constrained extensions on `Tagged`:

```swift
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public init(descriptor: Int32) throws(FooError) {
        // EINTR retry; delegates to L2's init
    }
    public static func get(descriptor: Int32) throws(FooError) -> Self {
        try Self(descriptor: descriptor)
    }
}
```

Swift's overload resolution distinguishes constrained extensions by `where` clause. Different `Tag` bindings → different overloads. No same-signature collision because `Tagged<POSIX, X>` and `ISO_9945.Kernel.File.Stats` are distinct nominal types via generic instantiation.

### 5.3 Field-access ergonomics — the one trade-off

Consumers access fields via either:
- `stats.rawValue.size` — explicit reach-through, slightly verbose, honest about layer composition
- Forwarding accessors at L3 — one-line `var size: Int64 { rawValue.size }` per field, mechanical boilerplate

Tagged has no `@dynamicMemberLookup` (would interfere with constrained-extension dispatch), so this is a real choice. For the 4 corrective namespaces × ~5–10 fields each, that's ~20–40 forwarding accessor lines if every field is exposed at the L3 surface.

### 5.4 Verification

Build clean, runtime EXIT 0:

```
Kernel.File.Stats.get(descriptor: 0)  = size=1024 perms=644
Kernel.File.Stats.get(descriptor: -1) = size=1024 perms=644 (L3 retry kicked in)
ISO_9945.Kernel.File.Stats(descriptor: -1) THROWS interrupted (L2 has no retry)
POSIX.Kernel.File.Stats(descriptor: -1) = size=1024 (L3 init via Tagged constrained ext)
withRetry.rawValue: size=1024 (L2 struct accessible via .rawValue)
```

The `descriptor: -1` test isolates the L3 policy: succeeds via `Kernel.*` (retry), throws via `ISO_9945.*` (no retry). Confirms L3's constrained-extension init is reached at the consumer call site.

---

## 6. Approach 13 — Carrier Generalization (PRINCIPAL-DISCOVERED)

`Tagged` conforms to `Carrier`. The conformance cascades: `Tagged<Tag, RawValue>.Underlying == RawValue.Underlying`. L2's plain struct conforms as a trivial self-carrier (one-line opt-in: `extension X: Carrier { typealias Underlying = Self }`).

### 6.1 Layer-agnostic generics

```swift
public func describeStats(_ s: some Carrier<ISO_9945.Kernel.File.Stats>) -> String {
    "size=\(s.underlying.size) perms=\(String(s.underlying.permissions, radix: 8))"
}

describeStats(rawL2Stats)        // ✓ bare ISO_9945.Kernel.File.Stats
describeStats(taggedL3Stats)     // ✓ Tagged<POSIX, ISO_9945.Kernel.File.Stats>
describeStats(kernelFileStats)   // ✓ Kernel.File.Stats (= Tagged via unifier typealias)
```

Single generic function, three layer variants accepted. Static type identity preserved (`type(of: l2) == Stats`, `type(of: l3) == Tagged<POSIX, Stats>`) — distinct nominal types remain available for code that needs to discriminate.

### 6.2 Design intent confirmation

`swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.swift:18-21`:

> *"This is the move that lets `some Carrier<Cardinal>` accept bare `Cardinal`, `Tagged<User, Cardinal>`, and any further-nested Tagged variant uniformly — subsuming the per-type `Cardinal.Protocol` cascade with a single parametric extension."*

This is the explicit design intent of the swift-tagged-primitives + swift-carrier-primitives infrastructure. Approach 13 is what that design was built for.

### 6.3 Architectural value beyond approach 12

Approach 12 unified the consumer call shape via the L3-unifier typealias. Approach 13 extends that to the **generic API level**: code processing "any Stats" — across libraries, across layers, across nested Tagged variants — is a single generic function rather than a forest of overloads. This is what ecosystem-wide layer-agnostic helpers look like in practice.

### 6.4 Verification

Build clean, runtime EXIT 0:

```
L2 bare struct via describeStats:                size=1024 perms=644
L3 Tagged variant via describeStats:             size=1024 perms=644
Kernel.File.Stats (= L3 Tagged) via describeStats: size=1024 perms=644
L2.underlying type matches L3.underlying type:   true
type(of: l2): Stats
type(of: l3): Tagged<POSIX, Stats>
```

---

## 7. Recommendation

**Migrate the 4 corrective namespaces (Stats, Open, Memory.Map, Time) to approach 12+13 combined.** Action sequence:

### 7.1 Revert Wave 3.5-Corrective `@_spi` adoption

- iso-9945 commits `2aed9ad` (Stats) and `cb053e5` (Open): drop `@_spi(Syscall) public` modifier.
- swift-posix commits `0c3545a` (Stats) and `d8c5877` (Open): drop `@_spi(Syscall) public import`; remove cross-module same-signature extensions on `ISO_9945.Kernel.File.X` types.

### 7.2 At iso-9945 (per corrective namespace)

```swift
// Method-style methods stay as-is (or become inits if convenient — neither required).
extension ISO_9945.Kernel.File.Stats {
    public static func get(descriptor: borrowing ISO_9945.Kernel.Descriptor)
        throws(ISO_9945.Kernel.File.Stats.Error) -> ISO_9945.Kernel.File.Stats { ... }
}

// Add Carrier conformance (one line):
extension ISO_9945.Kernel.File.Stats: Carrier {
    public typealias Underlying = ISO_9945.Kernel.File.Stats
}
```

That's the entire L2 change per type. No removal of methods, no namespace gymnastics, no `@_spi`.

### 7.3 At swift-posix (per corrective namespace)

```swift
// Replace the typealias chain with a Tagged variant:
extension POSIX.Kernel.File {
    public typealias Stats = Tagged<POSIX, ISO_9945.Kernel.File.Stats>
}

// L3-policy methods via constrained extension:
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public static func get(descriptor: borrowing POSIX.Kernel.Descriptor)
        throws(POSIX.Kernel.File.Stats.Error) -> Self {
        // EINTR retry; delegates to L2:
        while true {
            do {
                let l2 = try ISO_9945.Kernel.File.Stats.get(descriptor: descriptor)
                return Self(__unchecked: (), l2)
            } catch let e where e.isInterrupted { continue }
        }
    }

    // Forwarding accessors for fields the L3 surface exposes:
    public var size: Int64 { rawValue.size }
    public var permissions: UInt16 { rawValue.permissions }
    // ... per field ...
}
```

### 7.4 At swift-kernel (L3-unifier)

```swift
// Unchanged from current pattern:
extension Kernel.File {
    public typealias Stats = POSIX.Kernel.File.Stats
}
```

### 7.5 Verify

- `swift build --build-tests` clean, no recursion warnings
- Runtime regression test per corrective namespace exercising the policy path (Stats.get with valid descriptor; Open.open with valid path; Memory.Map; Time)

### 7.6 Cross-cutting consumers (optional, additive)

Anywhere in the ecosystem where layer-agnostic processing makes sense:

```swift
public func auditableLog(_ s: some Carrier<ISO_9945.Kernel.File.Stats>) {
    let u = s.underlying
    log.debug("stat-result size=\(u.size) perms=\(String(u.permissions, radix: 8))")
}
```

This is purely additive — adopt where useful; legacy concrete-typed consumers continue to work unchanged.

---

## 8. Trade-offs (Honest Accounting)

| Concern | Status under approaches 12+13 |
|---|---|
| **Distinct nominal types still exist** | Yes — `Tagged<POSIX, X> ≠ X`. Expressed via generic instantiation rather than hand-written wrapping struct. If the deal-breaker was distinct nominal types per se, this doesn't clear it. If it was field/data duplication or maintenance burden, it does. |
| **Field access ergonomics** | `stats.rawValue.field` reach-through OR per-field forwarding accessors at L3. Choose per type. |
| **Migration cost at L2** | Near-zero: existing struct + methods unchanged; one-line Carrier conformance per type. |
| **Migration cost at L3** | Replace typealias-chain-with-cross-module-extension shape with Tagged-typealias + constrained-extensions. Mechanical per namespace. |
| **Tagged + Carrier as load-bearing dependencies** | Major architectural commitment. Both packages already exist in production at swift-primitives layer; using them at L3-policy is consistent with ecosystem direction. |
| **`~Copyable` types** | Tagged supports `~Copyable & ~Escapable` design space; Carrier admits all four quadrants. Compatible with `Kernel.Descriptor` integration. |
| **Runtime cost** | Tagged is a thin wrapper; rawValue access is free with WMO. Carrier dispatch is generic specialization (compile-time, no virtual dispatch). |

---

## 9. Generalization Across the Ecosystem

The approach 12+13 pattern applies uniformly anywhere a layered spec/policy boundary exists:

| Domain | L2 (spec authority) | L3 (policy / composition) | Layer-agnostic generic |
|---|---|---|---|
| **POSIX syscalls** | `ISO_9945.Kernel.File.Stats` | `Tagged<POSIX, ISO_9945.Kernel.File.Stats>` | `some Carrier<ISO_9945.Kernel.File.Stats>` |
| **Win32 syscalls** | `Windows.\`32\`.Kernel.File.Stats` | `Tagged<Windows, Windows.\`32\`.Kernel.File.Stats>` | `some Carrier<Windows.\`32\`.Kernel.File.Stats>` |
| **Legal: statute/case-law/composed-law** | `NRS_78.\`035\`` (statute) | `Tagged<CaseLaw_Modifications, NRS_78.\`035\`>` (composed) | `some Carrier<NRS_78.\`035\`>` |
| **Future TBD** | ... | ... | ... |

A single architectural rule eliminates per-case structural decisions. Every L2/L3 boundary in the ecosystem uses the same pattern.

---

## 10. Open Questions for Principal

1. **Migration scope at L2** — Carrier conformance for the 4 corrective namespaces only, OR uniform Carrier conformance across all 41 wrapped namespaces (full ecosystem coherence)? The 37 non-corrective namespaces don't need Tagged at L3 (their existing fresh-enum-at-POSIX shape is fine), but they could still benefit from L2-level Carrier conformance for layer-agnostic generics.

2. **Field-forwarding boilerplate** — accept the per-field accessor lines at L3 (one line per field per type), accept `.rawValue.field` reach-through as the consumer ergonomics, OR adopt a macro to generate forwarding accessors? `@CarrierForward` would be a small macro with high payoff.

3. **Existing Wave 3.5-Corrective regression** — `POSIX.Kernel.File.Open.swift:97` is empirically broken (compiler warning + runtime SIGSEGV); Stats is presumed broken structurally identically. Revert as P0 (corrective revert before any further dispatch), OR absorb into the approach-12+13 migration (the migration revert is structurally larger but lands as one coherent commit chain)?

4. **Memory.Map and Time disposition timing** — currently queued for the broken Wave 3.5-Corrective pattern. Pause and adopt approach 12+13 from inception, OR proceed with broken pattern then revert as part of the migration?

5. **Codification scope** — promote approach 12+13 to default for L2/L3 layering across the ecosystem in [PLAT-ARCH-008f]? The generalization to legal architecture suggests this is more than a platform-stack pattern.

---

## 11. Provenance

- **Original investigation**: `swift-institute/Research/l3-policy-layering-without-spi-2026-05-02.md` (approaches 1–10; recommended approach 10 pre-followup)
- **Principal feedback that triggered this followup** (verbatim):
  - "but we dont want to have duplicate structs. that's a deal breaker."
  - "if a struct SHOULD be the same, then we want it to be the same right. Ideally I'd have L1 X, L2 Z.Y, and L3 X.Y. where the methods and functions can be overridden on L3."
  - "the legal precedent I wanted to point out was here: rule-legal-us-nv-private-corporation and its upstream"
  - "What about public typealias `POSIX.Kernel.File.Stats` = Tagged<POSIX, ISO_9945.Kernel.File.Stats>"
  - "we could then also use carrier-primitives (tagged conforms to carrier) and use some Carrier<X> to allow both L2 and L3 types where it doesn't matter?"
- **Legal architecture investigation**:
  - `rule-legal-us-nv-private-corporation/Sources/Rule Legal US NV Private Corporation Shared/Corporation.swift`
  - `rule-law-us-nv/Sources/Rule Law US Nevada/Rule Law US Nevada.swift:41-57` (the typealias-or-replace prescription)
- **New experiments** (all CONFIRMED mechanically, 2026-05-02):
  - `swift-institute/Experiments/l3-policy-layering-approach-11-operation-struct-pattern/` — operation-struct + L3-unifier-method
  - `swift-institute/Experiments/l3-policy-layering-approach-12-tagged-l2-as-rawvalue/` — `Tagged<POSIX, L2.Stats>` typealias + constrained extensions
  - `swift-institute/Experiments/l3-policy-layering-approach-13-carrier-generic-over-layers/` — `some Carrier<L2.Type>` accepts both layers uniformly
- **Source-level design intent confirmation**: `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.swift:18-21` (explicit design intent for `some Carrier<X>` accepting bare + Tagged variants)
- **Skill rules cited**: [PLAT-ARCH-008e], [PLAT-ARCH-008f], [PLAT-ARCH-008j], [PLAT-ARCH-018], [API-NAME-003]
- **Toolchain**: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102), macOS 26.2 (arm64)
