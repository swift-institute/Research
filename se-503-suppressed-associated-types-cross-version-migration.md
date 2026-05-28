# SE-503 Suppressed Associated Types: Cross-Version Migration

<!--
---
version: 1.0.0
last_updated: 2026-05-28
status: DECISION
tier: 2
scope: ecosystem-wide
---
-->

## Context

All swift-primitives packages enable `.enableExperimentalFeature("SuppressedAssociatedTypes")` — the **prototype** of the now-accepted [SE-0503](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md). Swift's migration note [`OldSuppressedAssociatedTypes`](https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/old-suppressed-associatedtypes.md) states the prototype is **deprecated and source-incompatible** with the accepted version, but only for **suppressed _primary_ associated types** (those in a protocol's `<…>` angle brackets). The question this raises: can we make the forward-looking edits **today** as a single source form that works on both the current toolchain and a final-SE-503 one?

**Scope**: swift-primitives (L1) — per the active L1-only workspace scope. L2/L3 consumers are deferred follow-up.

**Trigger**: user request to assess the migration doc, then to verify a cross-version path empirically before moving.

**Prior art** (per [RES-019]; reconciled below):
- `swift-6.3-ecosystem-opportunities.md` §"Feature flags" — established that `SuppressedAssociatedTypesWithDefaults` is **absent from `Features.def` in 6.2.4/6.3** (a silent no-op) and was **removed from all Package.swift (DONE)**. This doc *extends* that with the `main`/SE-503-toolchain behavior.
- `phantom-typed-value-wrappers-literature-study.md` — cites the Farvardin "Suppressed Associated Types With Defaults" Forums pitch (Dec 2025) as the feature that would "unblock Phase 2 of the protocol abstraction."
- `feature-flags-coroutine-borrow-accessors.md` (lines 328–329) shows both flags in an example block — **stale relative to the cleanup**; current mainline carries only `SuppressedAssociatedTypes` (verified below).

**Companion artifacts**: full per-site audit in `Audits/AUDIT-se-503-suppressed-associated-types-2026-05-28.md`; runnable proof in `Experiments/se503-cross-version` (status CONFIRMED).

## Question

Given the prototype→SE-503 source incompatibility, **what is the best migration strategy for swift-primitives** — and specifically, is there a single source form that compiles on both Swift 6.3 and a final-SE-503 toolchain so the edits can land today?

## Analysis

### The migration surface `[Verified: 2026-05-28 — audit]`

13 protocols suppress a **primary** associated type (the only kind SE-503 changes): `Sequenceable`, `Sequence.Iterator.`Protocol``, `Sequence.Borrowing.`Protocol``, `Iterator.`Protocol``, `__IteratorChunkProtocol`, `Iterator.Borrow.`Protocol``, `__EffectContinuation`, `_CarrierProtocol`, `Input.`Protocol``, `Input.Access.Random`, `Parser.`Protocol``, `Parser.Printer`, `Parser.Bidirectional`. Reference surface ≈ **641 sites across ~40 L1 packages** (alias- and module-qualifier-inclusive); ≈ **197 are NEEDS-SUPPRESSION**, of which only ≈ **39 are load-bearing** (sequence/input/carrier/iterator-borrow). The ≈158 parser-family sites are latent — their `Input` is Copyable in every current instantiation (`Substring`, `ArraySlice<Byte>`, `Byte.Input`). Protocols suppressing only a *non-primary* associated type (`__BufferProtocol`, `__ArrayProtocol`, `__StorageProtocol`, `__SetProtocol`, `Collection.`Protocol``, …) need **zero** changes.

### Current ecosystem state `[Verified: 2026-05-28]`

196 mainline Package.swift enable `SuppressedAssociatedTypes`; **0** enable `SuppressedAssociatedTypesWithDefaults` (confirms the prior cleanup). Code uses the **bare form** (no use-site restatements).

### Cross-version empirical findings `[Verified: 2026-05-28 — Experiments/se503-cross-version]`

Built on Apple Swift **6.3.2** (`org.swift.632202605101a`) and Apple Swift **6.5-dev** snapshot 2026-05-12-a (`org.swift.64202605121a` — reports `6.5-dev`, *not* 6.4 despite the bundle-ID prefix; per the snapshot-label rule the `swift --version` string governs).

| Form | 6.3.2 | 6.5-dev |
|---|---|---|
| Un-gated restatement `where <Assoc>: ~Copyable` | ❌ `cannot suppress '~Copyable' on generic parameter '…' defined in outer scope` | ✅ builds (flag-deprecation warnings) |
| **`#if compiler(>=6.5)` gated** (restatement / bare) | ✅ builds + runs (debug+release), takes `#else` | ✅ builds + runs (debug+release), takes `#if` |
| Today's **bare** library shape (P6) | ✅ compiles | ✅ **compiles** (does NOT hard-break) |
| Bare API + move-only-assoc **consumer** (P7) | ✅ | ❌ `referencing '…' requires '…' conform to 'Copyable'` |

Five consequences:
1. **The un-gated restatement is mutually exclusive** — 6.3 *forbids* restating the suppression; SE-503 *requires* it. No single un-gated source satisfies both.
2. **`#if compiler(>=6.5)` is the only portable single-source form** — verified to build+run on both, cross-module, debug+release; branch witnesses confirm correct selection.
3. **`hasFeature(SuppressedAssociatedTypesWithDefaults)` is NOT a usable gate** on the snapshot — false even when the flag is enabled; only the compiler *version* discriminates.
4. **SE-0503 is "Accepted", not in a numbered release** — it lives on `main` behind `SuppressedAssociatedTypesWithDefaults`, so the exact release version is unknown. `>=6.5` is conservative (the verified-accepting version); revisit on the actual release.
5. **"Switch later" is NOT a flag-day** — today's bare library keeps *compiling* through the transition (P6). The narrowing bites only at consumer call sites that pass a move-only associated type to a bare API (P7) — i.e. only the ≈39 load-bearing sites; the ≈158 parser sites never hit it.

### Why no naming trick escapes the version split `[Verified: 2026-05-28 — Probes/]`

`~Copyable` is a **suppression** (removal of the implicit `Copyable`), not a protocol you conform to (addition). Tested:
- `associatedtype Item: NonCopyable` (protocol bound, `NonCopyable: ~Copyable`): move-only **rejected** on both (P2); real `~Copyable` accepts it (P3). A conformance can't substitute for a suppression.
- `typealias NC = ~Copyable`: names the suppression and works at **declaration** sites (P4), but at a **use-site restatement** hits the *identical* 6.3 error (P5) — the compiler desugars the alias before applying the rule.

What flipped between toolchains is a **language rule about where the suppression may appear**, not its spelling — so nothing nameable escapes it; only `#if compiler` flips the rule.

### Options

| Option | What it does | Pros | Cons |
|---|---|---|---|
| **A — Defer; keep `SuppressedAssociatedTypes` + bare form; lazy per-package switch** (RECOMMENDED) | No change now; when a package adopts the SE-503 release, drop the flag + add its load-bearing restatements | Zero churn now; library never hard-breaks (P6); current ecosystem already in this exact state; switch is small (≈39 sites), lazy, per-package, pre-enumerated | Deprecation warnings once on the SE-503 toolchain; latent narrowing at load-bearing sites until each is restated |
| **B — `#if compiler(>=6.5)` gate now** | Wrap each NEEDS site in the gate | Forward-ready, behavior-preserving on both | ≈197 `#if/#else` blocks on a *provisional* threshold likely to be revised when SE-0503 ships; heavy churn on timeless infra |
| **C — Move ecosystem to a nightly now** (6.5-dev already has SE-503) | Adopt SE-503 fully today, clean single restatement form | No wait, no `#if` | Pins all consumers + CI to an unstable dev toolchain for a non-urgent feature |
| **D — De-primary-ize the suppressed types** (drop them from `<…>`) | Makes the protocols non-primary → SE-503-immune (zero migration), one-time edit at 13 declarations, version-agnostic | Dodges SE-503 entirely | Destroys the `some/any P<Arg>` sugar used in 142+ `Carrier.`Protocol`<…>` count-param sites + the parser API; larger churn + permanent API regression |

## Outcome

**Status: DECISION** — **Option A (defer + keep + lazy per-package switch).**

Rationale: the current ecosystem state (196 packages on `SuppressedAssociatedTypes` + bare form) *is* Option A; the experiment proves nothing breaks today and the transition is not a flag-day (P6); the eventual switch is a small, pre-enumerated, per-package edit (≈39 load-bearing sites). The alternatives each pay more — B commits ≈197 gated edits on a guessed threshold, C trades stability ecosystem-wide, D regresses the primary-associated-type API. Per [RES-022], structural correctness dominates: A preserves the protocols' intended shape and defers only mechanical work, on a documented trigger.

**`#if compiler(>=6.5)` is the validated escape hatch** if any single package must move before the ecosystem toolchain does — but it is not the default.

**Deferred-execution trigger** (what resolves the deferral): SE-0503 ships in a numbered Swift release. Then:
1. Re-run `Experiments/se503-cross-version` on that toolchain to **lock the real `#if`/version threshold** (replace the provisional `>=6.5`) and confirm the load-bearing site list.
2. Per package, on adoption: drop `.enableExperimentalFeature("SuppressedAssociatedTypes")` (declarations go native), add the load-bearing restatements from the audit checklist.
3. Optionally drop the now-redundant flag from the ≈157 unaffected packages too.

**Do NOT** pursue naming/alias indirection (disproven) or de-primary-ization (API regression).

## References

- Swift migration note: [`OldSuppressedAssociatedTypes`](https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/old-suppressed-associatedtypes.md) — *re-checked 2026-05-28: only two sections ("Source Changes", "ABI Changes"); it offers **no** cross-version guidance (no `#if compiler`, `hasFeature`, upcoming-feature flag, `SuppressedAssociatedTypesWithDefaults`, migration order, or fix-it). The note is forward-only — it assumes you are already on an SE-503 toolchain — which is consistent with this doc's lazy-switch decision.*
- [SE-0503 Suppressed Associated Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md) (Status: Accepted)
- Farvardin, K. "[Suppressed Associated Types With Defaults](https://forums.swift.org/t/pitch-suppressed-associated-types-with-defaults/83663)." Swift Forums pitch, Dec 2025.
- `Audits/AUDIT-se-503-suppressed-associated-types-2026-05-28.md` — full per-site migration audit.
- `Experiments/se503-cross-version/` — cross-version proof (status CONFIRMED); probes P1–P7 in `Probes/`.
- `Research/swift-6.3-ecosystem-opportunities.md` — prior finding: WithDefaults no-op removal (DONE). *This doc extends it with main/SE-503 behavior.*
- `Research/phantom-typed-value-wrappers-literature-study.md` — SE-503 pitch as Phase-2 unblock.
