---
title: Should `feedback_clean_build_first` Be Elevated From Advisory to Preemptive?
version: 0.1.0
status: DEFERRED
tier: 1
created: 2026-05-07
last_updated: 2026-07-02
applies_to:
  - all institute build verification workflows
  - swift-institute/Skills/swift-package-build
---

# Context

`feedback_clean_build_first.md` is currently advisory: "rm -rf .build
before debugging unexpected failures." The rule fires reactively —
after an unexpected failure, the discipline is to clean and rebuild.

The 2026-05-07 cohort surfaced two recent instances where the
`.build` cache was stale enough to produce link-time symbol-not-found
failures that initially looked like real source defects:

1. **Stream 2 polish dispatch** (commit `f55cafa` adjacency):
   `swift-linter` build failed with `ld: symbol(s) not found for
   architecture arm64` referencing Binary primitives symbols. Symptom
   read like a real source defect for several seconds before
   recognition as cache staleness. `rm -rf .build` resolved.
2. **lint-manifest-drop dispatch** (commit `4f5d467` adjacency):
   `swift-tagged-primitives` initial incremental build hit a
   stale-state linker failure with duplicate
   `Binary.Bytes._withBorrowedPrefixContiguous` symbols from
   `Binary_Borrowed_Primitives`. Resolved by clean rebuild per the
   advisory rule.

Common context: BOTH instances were verification phases running
against `.build` directories whose age spanned multiple ecosystem
churn events (Binary primitives evolution between the cache's
last-touch time and the current source state). Neither dispatch
expected to need a clean build — both were doc-only or
narrowly-scoped source changes; the cache staleness was incidental
to the dispatch's own scope.

The question this raises: should the discipline shift from REACTIVE
("clean .build when debugging unexpected failures") to PREEMPTIVE
("clean .build before verification when ecosystem churn has occurred
since last build")?

# Question

Should the institute's build verification discipline preemptively
clean `.build` when ecosystem churn has occurred since the last
build, instead of waiting for cache-staleness symptoms to surface?

Sub-questions:

1. **Detection mechanism**: how does the verification discipline
   detect "ecosystem churn has occurred since last build"? Mtime
   comparison of dependent packages' source vs. consumer's
   `.build/checkouts/` cache? Last-pulled dates on dep manifests?
   Time-since-last-build threshold (e.g., always clean if `.build`
   is >24 hours old)?
2. **Cost asymmetry**: clean rebuild on swift-linter is ~140-280s
   per package; incidental clean-rebuilds across a multi-package
   verification could add minutes to dispatch latency. The
   per-instance cost is bounded; the per-cohort cost compounds.
3. **Scope of preemptive rule**: applies to all verification phases?
   Only to verification phases against packages NOT touched by the
   current dispatch (i.e., dep packages whose cache may have aged)?
   Only when the verification follows a ≥X-day gap?
4. **Third-instance threshold**: this research doc surfaces 2
   instances; the polish-stream-2 reflection notes the discipline
   shift would be motivated by a third. Is 2 enough to elevate, or
   is the right move to wait for the third instance and then
   formalize?

# Prior Work

- `feedback_clean_build_first.md` — current advisory rule.
- Reflection `2026-05-07-pre-publishable-polish-stream-2.md` (Pattern:
  the recurring class).
- Reflection `2026-05-07-lint-manifest-drop-and-array-builder-inference.md`
  ("first build cycle hit a stale-`.build` linker failure that ate
  ~10 seconds of real time").
- Reflection `2026-05-07-swift-linter-code-surface-cleanup-cohort-and-mirror-config-unblock.md`
  (mirror-config deadlock — initially misdiagnosed as SwiftBuild
  framework bug; user steered to mirror-config; this is a different
  failure class but same "verification phase against stale state"
  category).
- `swift-institute/Skills/swift-package-build/SKILL.md` (where a
  preemptive rule would live if elevated).

# Analysis

_Stub — to be filled in during investigation._

# Options Considered

| Option | Shape | Cost / Benefit |
|--------|-------|----------------|
| A — Stay advisory | Current rule unchanged; clean reactively when symptoms surface | Lowest dispatch cost; ~10-30s recognition latency per instance |
| B — Elevate to preemptive | Always clean .build before verification | High dispatch cost (~minutes per cohort); zero cache-staleness symptoms |
| C — Conditional preemptive (≥24h since last build) | Clean only when .build mtime indicates staleness | Bounded dispatch cost; covers the most-likely-stale cases |
| D — Conditional preemptive (ecosystem-churn-aware) | Clean only when dep packages' source is newer than .build/checkouts/ cache | Tightest predicate; requires implementation infra |

# Outcome

> **DEFERRED (2026-07-02 corpus-meta-analysis sweep, [META-001]/[META-002])** — stale IN_PROGRESS triage.
> **Blocker**: Pending-investigation stub; doc's own recommendation is to wait for more evidence.
> **Resumption trigger**: A third independent clean-build-first instance surfaces (doc's own criterion).

_Pending investigation. Recommendation: defer the elevation decision
until a third independent instance surfaces, per the reflection's
"third would push the recommendation toward preemptive form" framing._

# Cross-References

- `feedback_clean_build_first.md`
- `feedback_no_parallel_swift_builds.md` (related verification
  discipline)
- `feedback_rm_build_benchmarks.md` (analogous discipline for
  benchmark verification)

# Provenance

Reflection `2026-05-07-pre-publishable-polish-stream-2.md` (action item 3).
