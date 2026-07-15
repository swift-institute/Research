---
date: 2026-07-15
session_objective: As L2 general orchestrator, monitor a detached full rebuild of the cclsp unified index to completion so the incoming L1 could lift the navigation warning; on principal directive, stop it and --fast-merge what was built.
packages: []
status: pending
---

# Monitoring a 6-hour detached rebuild: churn-zeros, a self-inflicted scope-gap, an orphaned loop, and a static marker that read as "stuck"

## What Happened

I held one gate slot as the L2 general orchestrator: a detached, fully-nohup'd full rebuild of the cclsp unified index (449 packages, on the correct `swift-6.3.3-RELEASE` compiler — the rebuild existed to fix an index/server compiler mismatch). The task was to watch it to completion and, on success, ledger plainly that the index was trustworthy again so the incoming L1 seat could lift the navigation warning.

Over ~6 hours the ledger watch streamed periodic `[idx] built N/449 · workers(ps)=K` events. Three recurring readings each looked like trouble and each was resolved by a direct disk/process probe rather than by inferring from the notification:

- **`workers=0` (repeatedly).** Every instance was churn-zero: the watch sampled at the instant between packages, or caught a freshly-spawned coordinator still in its plan/resolve phase before it forked any `swift-frontend`. I confirmed each by a fresh marker + a fresh coordinator (small `etime`) on the correct compiler + live `.build` writes. Once I caught a coordinator 29s old with two consecutive zero worker samples and five `.build` trees written in the prior two minutes — the clearest illustration that `workers=0` is not a measurement.
- **Static `built 400/449` marker.** Read as frozen; was not. The script logs a marker only every 25th package processed, and the tail was swift-ietf/RFC packages at ~1.3 min each, so ~33 min of apparent silence per marker is silence by construction.
- **A "stuck" signature I manufactured myself.** At one static-marker decision point I probed `.build` writes across swift-primitives/standards/foundations and got zero, plus zero workers, plus a 24-min-static marker — three stuck indicators at once. I nearly reported it trending-stuck. It was a **scope-gap false-zero**: the active package had walked into `swift-ietf` (coordinator cwd `swift-ietf/swift-rfc-6066`), an org my probe never searched. Re-scoped across all org dirs, five swift-ietf `.build` trees showed fresh writes. The build was never stuck; my probe under-reached.

The principal then asked directly: *"I think it's stuck? has been on 400/449 for hours now?"* I re-derived from the log mtime (primary source): the `400` line had been written **25 minutes** ago, not hours — the log physically cannot have been at 400 for hours. I said so, explained the every-25-packages cadence, and offered the shortcut: 357 correctly-compiled package stores were already on disk (more than the historical 266/395 that gave full cross-package navigation), so we could stop and `--fast`-merge for a trustworthy correct-compiler index in minutes instead of ~90.

Principal: *"stop now and --fast merge."* Executing it surfaced a real trap. Killing the registered wrapper PID (18705) only **orphaned the loop**: `build-unified-index.sh` reparented to init as a different PID (93719, which had not existed at registration time) and kept advancing the marker 400→425. I confirmed via `lsof` that the orphan held my log open (kill-only-what-you-started), killed the loop and its group, verified a clean stop (zero `build-unified-index.sh`/`swift-build`/`swift-frontend`, nothing holding the log), then launched `build-unified-index.sh --fast` (pid 96517, detached), confirmed it passed the toolchain assertion (reached the merge phase past the pre-discovery check → correct compiler), re-registered it in the ledger, and armed a fresh watch. Final rebuild tally at stop: 425/449 processed, 68 failed → 357 succeeded stores. The merge was still running at reflection time; final coverage lands via the watch.

**Artifact cleanup.** Handoff scan: the only in-cleanup-authority handoff is the active charter `CHARTER-general-orchestrator-2026-07-14b.md` — I am mid-session operating under it and a new L1 boots to inherit it, so it is in-flight → **no-touch** per [REFL-009a]; left unchanged. `check-handoffs.sh` reports 60>40 live handoffs plus 2 filename-terminal residents (`CHARTER-endstate-e6-*`, `PROGRAM-repotraffic-endstate-*`) — these belong to the broader repotraffic END-STATE program, are documented red-by-design in Project Status (drain-per-arc-at-close), and are out of this session's scope; triaging in-flight arc handoffs would itself violate [REFL-009a]. Not acted on; triage stays human-driven per [BET-EVAL]. No `/audit` ran this session.

## What Worked and What Didn't

**Worked.** The direct-probe-over-notification discipline held all night. Every ambiguous `workers=0` resolved to a benign churn-zero on inspection, and — the payoff — the one reading that looked genuinely stuck turned out to be my own probe's blind spot, caught only because I checked the coordinator's `cwd` instead of trusting my zero. Grounding the principal's "is it stuck?" in the log mtime rather than in my prior confident read was also correct: the 25-minute measurement refuted the "hours" perception **and** my own "slow but fine" narrative equally — the primary source disagreed with both stories.

**Didn't.** My `.build` probe hardcoded three org dirs while the build had walked into a fourth, and I read the probe's zero as a *build* state ("stuck") when it was a *probe-scope* artifact. I had written the gotcha-table row about exactly this class earlier in the day and still did it — knowing a failure by name does not immunize against committing it. Separately, killing the registered PID *felt* like stopping the run but wasn't: the registration recorded the launcher, and a detached nohup pipeline outlives its launcher's death.

## Patterns and Root Causes

Two of this session's near-misses are the **same** failure wearing different clothes: I made a claim from a handle whose *reach* or *identity* did not match the claim's scope.

- The `.build` probe's reach (3 orgs) did not cover the claim's scope (all orgs where builds run) → a false zero read as "stuck."
- The process registration's identity (pid 18705) did not cover the thing that actually had to die (the loop — a later, different PID) → an orphaned survivor read as "stopped."

Both are the [REFL-011] tool-reach / [SUPER-054] seat-symmetry class: **a zero, or a PID, that you did not re-derive from the live object at action-time is a claim, not a measurement.** The fix in both cases is identical and concrete — derive from the live object *now*: the coordinator's `cwd` tells you which org to probe; `lsof` on the log tells you which PID is actually writing it. Neither answer was available from the value I was carrying forward.

The static-marker-reads-as-stuck problem is a **monitoring-UX defect, not a build defect**. A progress signal whose granularity (every 25 packages) is coarse relative to per-unit time (~1.3 min) manufactures long apparent-silence windows that are indistinguishable from a hang in the notification stream — so the human, watching the same "400/449" repeat across heartbeats, correctly perceives "stuck" from a healthy job. The remedy is not to reassure harder; it is (a) re-derive from the log mtime at every static-marker decision point, and (b) treat the human's "it's been hours" as a *primary-source-re-derivation trigger* in its own right. Their impatience was the most useful instrument in the session: it forced the one measurement that cut through two competing narratives.

Finally, the orphaned-loop-on-kill is a concrete gap in how [SUPER-065] registers long-running processes. Registering by launcher PID is sufficient for a foreground gate but not for a detached self-driving loop, where the process that must die may not exist yet at registration time. The registration needs to record the **stop procedure** (kill target + how to identify it), not just a PID snapshot.

## Action Items

- [ ] **[skill]** supervise: extend [SUPER-065] — a registered *detached* long-running process MUST record its stop procedure (kill target + identification method, e.g. `lsof <log>` / cwd-match), not only the launcher PID. Killing a nohup'd wrapper orphans its loop (reparents to init, keeps running); this session killed the registered pid 18705 and the loop kept advancing 400→425 as a new orphaned PID.
- [ ] **[doc]** cclsp-swiftpm-navigation.md: document that `build-unified-index.sh` emits a progress marker only every 25th package AND that merge→checkout-filter→harvest runs *after* all builds — so a static `built N/449` marker is expected (not a hang) and 449/449 ≠ done (the `.unified-index-store` rewrites only at the merge phase). A monitor lacking this reads the slow RFC-tail marker as stuck.
- [ ] **[skill]** reflect-session: extend [REFL-011] — a human's doubt/impatience signal ("is it stuck? / it's been hours") is itself a primary-source-re-derivation trigger; the correct response is to re-measure from the log/mtime, not to restate a prior confident read. This session the "hours" claim and my own "slow but fine" read were both refuted by the 25-min log mtime.
