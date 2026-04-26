# withUnsafe* + borrowing + ~Copyable + @inlinable Pattern-Reach Survey

Date: 2026-04-26
Scope: ecosystem-wide (stdlib `withUnsafe*` family + production consumers in swift-primitives / swift-foundations)
Tier: 2 (cross-package, empirical survey, reversible precedent)
Status: IN_PROGRESS — survey scope defined; reproducer construction + empirical verification deferred until A2 upstream filing is authorized
Provenance: Reflection `2026-04-24-noncopyable-inlinable-abi-fix-and-v11-overclaim-walkback.md` action item B3; informs the eventual upstream compiler-issue filing (gated on audit action A2)

---

## Context

The 2026-04-24 ownership-borrow miscompile (`swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`) established that `withUnsafePointer(to: borrowing value)` where `Value: ~Copyable`, wrapped in an `@inlinable` init that stores the returned `UnsafePointer<Value>` into a `~Escapable` return value, returns a pointer into a callee-frame spill slot when inlined across a module boundary. The spill slot dies with the inlined call; release-mode reads yield garbage or trap.

The fix at `Ownership.Borrow` and `Property.View` was to remove `@inlinable` from the affected inits — the cross-module function-call boundary preserves the `@in_guaranteed` indirect ABI the inlined form loses. The fix is ABI-preserving, not an optimization choice.

The open question: **does this pattern extend to other `withUnsafe*` APIs in the stdlib that accept `borrowing` parameters?** If so, the audit needs to enumerate them; if not, the bug is specific to `withUnsafePointer(to:)` and the workaround scope is bounded.

---

## Question

Which stdlib `withUnsafe*` overloads accepting `borrowing` parameters exhibit the same release-mode miscompile shape, and which production consumers in the swift-institute ecosystem touch each?

Candidate APIs to enumerate:

| API | Parameter shape | Hypothesis |
|-----|-----------------|------------|
| `withUnsafePointer(to: borrowing T)` where `T: ~Copyable` | The known broken case (V1 / V7 reproducers) | CONFIRMED broken |
| `withUnsafeBytes(of: borrowing T)` where `T: ~Copyable` | Same family, raw-byte view | Untested — likely same shape |
| `withUnsafeMutablePointer(to: inout T)` where `T: ~Copyable` | Sibling for mutable inout | Likely OK (the original audit's `inout` case worked) |
| `withUnsafeMutablePointer(to: consuming T)` where `T: ~Copyable` | Consuming variant | Untested |
| `withUnsafeTemporaryAllocation` | Capacity-driven temporary buffer | Likely OK (different mechanism) |

**Output expectations**: an enumeration table with per-API (a) reproducer status (CONFIRMED broken / CONFIRMED safe / UNTESTED), (b) production consumer list, (c) per-consumer in-package regression-guard status. The output feeds the upstream compiler-issue filing's "scope" section.

---

## Empirical Census Plan (deferred until A2 authorized)

Per [EXP-018] / [ISSUE-025] the cascade claim for each candidate API requires per-consumer in-package release-mode tests. The plan:

1. **Enumerate stdlib `withUnsafe*` overloads accepting `borrowing` parameters** via Swift documentation + standard library source. Output: a per-API table.
2. **Construct minimal reproducers** in `swift-institute/Experiments/borrow-pointer-storage-release-miscompile/` per API. Each reproducer mirrors V1/V7 shape but swaps the `withUnsafe*` call. Track per-reproducer outcome in the experiment's findings.
3. **Cross-package consumer grep** across swift-primitives, swift-standards, swift-foundations for each `withUnsafe*` call paired with `borrowing` `~Copyable` parameter shape. Output: a per-consumer table indicating which production sites each API touches.
4. **Per-consumer in-package release-mode regression guards** per [EXP-018]. For each cited consumer, write a release-mode test exercising the consumer's production shape under the failure trigger. Initial guards as `withKnownIssue`; convert to positive assertion if the test passes (production evades) or remove the wrapper if it fails (production affected).

**A3 V13 experiment** from the source reflection sits inside step 2 — V13 isolates which of `@_rawLayout` / generic-Element / stride-advance-arithmetic is the structural discriminator that protected `Memory.Inline.pointer(at:)` from V11. V13's output makes the upstream bug report shape-precise.

---

## Status

This Doc is IN_PROGRESS; empirical work is deferred until audit action A2 (upstream compiler-issue filing) is authorized. The current shipping posture per `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md` is NORMAL — Finding #12 was inverted from HIGH/HOLD to LOW/watchflag based on 3/3 in-package production-shape regression guards passing.

This Doc's primary purpose at IN_PROGRESS is to scope the survey before V13 + A2 land, so the empirical work has a clear plan to pick up from. When A2 is authorized:

- V13 runs first to isolate the discriminator (per the source reflection's action item B3).
- The enumeration table fills in per-API reproducer status.
- Consumer grep + per-consumer regression guards complete the cascade-claim verification.
- Doc graduates to RECOMMENDATION or DECISION based on outcomes.

---

## Cross-references

- Reflection: `2026-04-24-noncopyable-inlinable-abi-fix-and-v11-overclaim-walkback.md` (origin)
- Reflection: `2026-04-24-narrow-shape-bug-extrapolation-and-in-package-verification.md` (parallel record + V11 inversion methodology)
- Audit: `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md` (the parent audit — action A2 upstream filing gates this Doc's empirical work)
- Experiment: `swift-institute/Experiments/borrow-pointer-storage-release-miscompile/` (V1–V12 already landed; V13 deferred per source reflection action A3)
- Skill rules: [EXP-018] Claim Validation Trap, [ISSUE-025] In-Package Verification of Synthetic-Reproducer Claims, [AUDIT-027] Shipping HOLD Evidence Bar
