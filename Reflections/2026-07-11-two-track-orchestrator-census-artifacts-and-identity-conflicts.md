---
date: 2026-07-11
session_objective: Orchestrate the afternoon two-track dispatch — Track A (mailgun family + dotenv, executable) and Track B (D2+D3 design via a fork) — per HANDOFF-orchestrator-2026-07-11.md
packages:
  - swift-mailgun-types
  - swift-mailgun-live
  - swift-mailgun
  - swift-environment
  - swift-witnesses
status: pending
---

# Two-track orchestration: census artifacts, transitive identity conflicts, and a macro's Never default

## What Happened

Both tracks ran concurrently from boot. Track B (a fork inheriting full
context) produced the D2+D3 unification plan in one pass — adopt-and-finish
the RFC-first url-routing rewrite on L1 swift-parser-primitives; D2 becomes a
new `swift-case-primitives` (Case.Path + @Cases macro) pending the new-package
YES; ten-consumer single-wave pin-flip — filed as
PLAN-routing-parsing-unification-2026-07-11.md (`eac18745`) after a
coherence review. Track A inverted two premises and closed one item green:
(1) **D5 dissolved** — `swift package dump-package` shows ZERO mailgun
cross-repo target collisions; the ratified "19 collisions" census was an
artifact of regex constant-resolution that missed the manifests'
`.types`/`.live` computed suffix helpers (tiers are already disjoint:
"Mailgun X Types" / "Mailgun X Live" / bare). The same artifact had produced
mailgun-live's uncommitted WIP that rewrote 20 product asks to bare names —
committed verbatim (`70d035c`, [HANDOFF-049]) then fixed (`cba068f`).
(2) **The swift-mailgun build livelock root-caused**: a capped solo reproduce
+ 180s `sample` showed 3651/3667 samples in one swift-package frame looping
into `_platform_memmove` — SwiftPM's conflicting-identity path enumeration
(catalog §A26), triggered by identity `swift-dependencies` under two
canonical locations: coenttb/swift-authenticating@0.1.2 and
coenttb/swift-environment-variables@0.1.3 (read from the shared-cache clones)
ask pointfreeco/swift-dependencies (unmirrored → remote) while the closure
carries the mirrored institute spelling. Fix is decision-gated (D1 + env-vars
consumer migration). (3) **Item 3 green**: `Environment.Dotenv` landed in
swift-environment (`1d210b3`, build+test 0, 27 tests) — one lane round-trip
after ASCII_Primitives made stdlib `UInt8(ascii:)` ambiguous. mailgun-types'
full gate went RED on a pre-existing systemic failure: 364 @Witness macro
expansions emit `Result<Response, Never>.failure(error)` for bare
`async throws` closure fields. Re-adds 0/3; all blockers logged, none
improvised. Zero pushes; morning window confirmed pushed between sessions.

## What Worked and What Didn't

Worked: dump-package as the authoritative census settled in seconds what two
regex-based censuses got wrong; reading the shared-cache clones
(`~/Library/Caches/org.swift.swiftpm/repositories`) extended the identity
audit to remote-resolved manifests — where the actual conflict lived; the
fork-for-design pattern returned a ratification-ready plan without burning
coordinator context; capped-reproduce-with-sample turned "mystery hang" into
a named §A26 instance in one 5-minute run.

Didn't: my own first census reproduced the identical constants-resolution
error before I checked the helpers — the artifact class survives tool
authorship changes because the error is in the resolution model, not the
regex. The overday session's "verified coherent vs mailgun-types@HEAD" claim
for the live WIP was the same artifact propagating: a verification built on
the naive census verified against a phantom state.

## Patterns and Root Causes

1. **Manifest censuses must be executed, not parsed.** Institute manifests
   are programs (constants + computed suffix helpers); any string-level scan
   is an interpreter with undefined coverage. `swift package dump-package`
   IS the census tool — SwiftPM evaluates the manifest. Two dispatches
   (D5 ruling, mailgun-live WIP) were misdirected by the parsed census.
2. **Identity audits stop too early at the local-mirror boundary.** The
   [PKG-DEP-002]/[PKG-DEP-009] conflict that actually fired lived in the
   manifests of REMOTE-resolved deps, readable only from the shared cache.
   A closure walk over editable mirrors alone systematically under-reaches
   ([REFL-011] tool-reach class). The memmove-dominated single-frame sample
   is the recognizable §A26 signature.
3. **Defaults that encode an absent case as Never convert missing input
   into type errors at the client.** @Witness maps "no throws clause" and
   "bare throws" onto the same `Failure = Never`, which is correct for the
   first and wrong for the second — 364 errors from one defaulting decision.
   Same shape as [IMPL-042]'s Never-specialization concerns: Never is a
   claim, not a fallback.

## Action Items

- [ ] **[skill]** swift-package: amend [PKG-NAME-014] (authoring-time check
  guidance) — any target/product-name census MUST come from
  `swift package dump-package`, never from string-level manifest scanning
  (constants + computed suffix helpers make parsed censuses undefined;
  provenance: the false "19-collision" D5 census, 2026-07-11).
- [ ] **[skill]** swift-package: amend [PKG-DEP-009]/[PKG-DEP-002] — the
  identity audit MUST extend to remote-resolved deps' manifests via the
  shared-cache clones, and document the §A26 runtime signature (pre-compile
  hang; sample = single swift-package frame dominated by `_platform_memmove`).
- [ ] **[package]** swift-witnesses: @Witness derives `Failure = Never` for
  bare `throws` closure fields and emits `Result<T, Never>.failure(error)`
  in catch paths (364 errors across swift-mailgun-types). Either map untyped
  throws to `any Swift.Error` or emit a diagnostic requiring typed throws.
