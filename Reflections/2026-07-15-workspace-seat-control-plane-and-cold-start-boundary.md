---
date: 2026-07-15
session_objective: Rebuild the Swift Institute multi-session architecture around one Workspace, one general seat, and isolated arc seats, repair its channel failures, and prove the new cold-start path against live sessions.
packages: []
status: pending
---

# Hub-and-Spoke Seats, a Repaired Doorbell, and the Cold-Start Boundary That Moved

## What Happened

The session began with a structural redesign of the Claude Code operating model. The target was one L1 Workspace that owns authority, global status, bookkeeping, and all communication routing; one persistent L2 `general` executor seat; and zero or more L3 arc seats for independently durable bodies of work. Every seat has one bidirectional channel with the Workspace. Seats never communicate with one another directly, and first-class seats are user-owned sessions rather than subagents.

The existing handoff and supervise skills mixed continuation, delegation, authority, transport, and execution. The session separated those concerns into four canonical process skills:

- `Skills/workspace-orchestration/SKILL.md` for actor topology, authority, work state, assignment, and completion;
- `Skills/seat-channel/SKILL.md` for the strict Workspace↔seat transport;
- `Skills/seat-runtime/SKILL.md` for executor conduct; and
- `Skills/workspace-start/SKILL.md` for cold start, recovery, generation rotation, launch manifests, and readiness.

The live channel implementation then exposed four measured defects. A timed watch silently became an unmanaged lease; a live long-running watch wrote output but emitted no completion notification to wake an idle task; a malformed `reply_to` could enter an append-only log and poison health across all future generations; and the watch advanced the same cursor used for processing, making a later empty read indistinguishable from “no work.” `Scripts/seat-channel.py` was repaired so watches are unbounded, one-shot doorbells provide completion notifications, only explicit `ack` advances the processed cursor, outbound `reply_to` values are validated before append, and current-generation defects are fatal while preserved historical defects are advisory. The repair was committed locally as `e71845c` and `74af036` on top of the first Scripts baseline `1a11fbf`. A fresh run of `python3 test-seat-channel.py` at reflection time ran four tests and passed.

The Principal then cleared the old Workspace, General, and Phase-1 tasks, explicitly revoked all predecessor authority, and designated the cleared Workspace task as the sole L1 actor. `/workspace-start` reconstructed the event stores, independently re-verified the repaired channel, rotated `general` generation 1→2 and `skill-corpus-phase1` generation 2→3, refreshed their immutable charters, armed one Workspace-side watch and doorbell for each seat, and generated complete copy-paste launch prompts. It correctly stopped at `WORKSPACE NOT READY` because neither seat had booted.

The proof boundary changed while this reflection was being prepared. Fresh process and channel reads showed that both new seat sessions had since started their seat-side watch and doorbell. General generation 2 completed its handshake, reported healthy, and then sent STATUS/EVIDENCE/BLOCKED records. Phase-1 generation 3 sent BOOT, received a reply-linked Workspace ACK, and passed health. The one-shot notification therefore did wake the Workspace and produced real control-plane work; the original “a live watch rings only into a file nobody opens” failure was not reproduced.

The post-wake transaction was not completed consistently. Phase-1 initially passed health after its Workspace ACK, but a read as Workspace still returned the already-ACKed BOOT, proving that its processed cursor had not yet been explicitly acknowledged. By the final fresh check at 2026-07-15T10:04:51Z, both General and Phase-1 health failed solely because their Workspace-side doorbells were stale; both unbounded Workspace watches were still alive, neither Workspace doorbell process was alive, and each channel had one pending record for the Workspace. This is a narrower but important boundary: notification delivery worked, while `process → ack → re-arm → verify` remained dependent on disciplined end-of-turn execution and was not completed atomically.

Artifact cleanup was intentionally small. `Scripts/check-handoffs.sh` passed; the root scan found zero `HANDOFF.md` or `HANDOFF-*.md` files, so no handoff was deleted or annotated. `Scripts/check-memory-corpus.sh` passed with zero memory topic files and no inbox entry beyond the 14-day cadence. No `/audit`-authored finding section was created in this session, so no audit status was changed. Existing unrelated dirty Research files and the tracked `Reflections/.cadence.log` were left untouched.

## What Worked and What Didn't

The architectural split worked. Authority, transport, execution, and cold-start concerns now have separate owners, and the hub-and-spoke rule is explicit enough that neither generated launch prompt permits peer-channel inspection. Stable seat IDs plus generation rotation preserved history without treating old sessions as live authority.

The strongest practice was repeated primary-source verification. The channel defects were not accepted from a seat report; source, process state, real logs, generation behavior, and tests were checked independently. The new Workspace did the same during recovery. It found stale and wrong facts in predecessor charters, corrected them through archive-and-rotate rather than rewriting history, and refused to claim readiness before the seat handshakes. The current reflection repeated those checks and caught that the live state had advanced beyond the transcript being reviewed.

The channel repair improved failure quality. Before repair, a watch could expire or consume work silently, and a historical citation error could brick every successor generation. After repair, the current lapse is visible: `health` reports both stale Workspace doorbells, and `read` exposes one pending record on each channel, including the unacknowledged Phase-1 BOOT. The system fails closed with specific evidence rather than presenting false health.

The remaining weakness is that the protocol's reliable state depends on a multi-step behavioral epilogue. A one-shot doorbell solves wake-up only if every recipient re-arms it after every processed batch. An explicit cursor solves false consumption only if every recipient advances it after processing. The skills state both duties, but the first live boot showed that prose plus health is not yet the same as a completed receive transaction.

Two bookkeeping judgments were also too loose. The Workspace paraphrased `/clear` plus explicit revocation as “the predecessor session was terminated,” although `WORK-START-002` names termination as its sufficient evidence class. The exclusivity result was sound, but the historical wording was stronger than the Principal's literal statement. Separately, the `seat-channel-reliability` work event called original acceptance satisfied while disclosing that no dedicated arc and no `recover` subcommand existed. `OBVIATED` was defensible because the functional blocker dissolved through generation-scoped rotation, but literal oracle completion and functional supersession were conflated.

Confidence is high in the actor model, event-sourced authority, generation recovery, send-time reply validation, cursor separation, and the fact that one-shot completion can wake the Workspace. Confidence is not yet high in steady-state notification maintenance. A first successful BOOT/ACK is necessary evidence, not sufficient evidence that the channel remains supervised after the turn ends.

## Patterns and Root Causes

The central pattern is **moving a failure boundary is not the same as eliminating the whole failure class**. The original control plane coupled liveness, notification, and consumption in one watch. Splitting them was correct: an unbounded watch is a lease signal, a doorbell is a wake signal, and an ACK cursor is processing state. The split made each claim honest and testable. It also exposed the transaction joining them. The protocol is healthy only after the receiver has processed durable records, advanced its processed cursor, re-armed the one-shot wake mechanism, and verified the replacement lease. Treating the ACK message itself as completion leaves two pieces of state behind.

The hub-and-spoke architecture makes that transaction especially load-bearing. Centralized authority prevents cross-seat drift and gives the Principal one adjudication point, but it also makes the Workspace a liveness cut vertex: every seat can continue writing durable records while an unarmed Workspace doorbell leaves the supervisor unaware. Durable logs prevent data loss; they do not prevent decision latency. The correct response is not peer-to-peer fallback, which would break the architecture, but a mechanically complete receive boundary at the hub.

A second pattern is **immutable history needs typed epistemic status**. A historical event can be honest when authored, stale when read, wrong in one measured denominator, or functionally superseded without being literally satisfied. Active-charter rotation handled this better than mutable prose, but the vocabulary around `terminated`, `acceptance satisfied`, and `OBVIATED` still allowed unlike claims to collapse into one sentence. Event sourcing preserves what was said; it does not itself distinguish whether a later reader should treat the statement as authority, evidence, or history.

A third pattern is **startup readiness and steady-state readiness are different oracles**. `/workspace-start` correctly proved reconstruction, generation preparation, Workspace-side leases, and initial handshakes. The live gap appeared only after messages were processed and a one-shot resource needed replacement. A cold-start gate that ends at the first green `health` can certify a channel that becomes unsupervised one turn later. The strongest canary is therefore a second message after the first ACK, with both processed cursor and replacement doorbell verified.

## Action Items

- [ ] **[skill]** workspace-start: Extend `[WORK-START-002]` to recognize explicit revocation of every predecessor authority plus designation of one sole successor Workspace as sufficient human evidence, and require successor charters/rotation reasons to preserve the Principal's exact evidence class rather than paraphrasing it as termination.
- [ ] **[skill]** seat-channel: Define a mechanically verified receive-completion boundary—process records, `ack --through`, re-arm the one-shot doorbell, and verify its fresh lease—and require a post-ACK second-message canary before a newly booted endpoint is considered steadily supervised.
- [ ] **[skill]** workspace-orchestration: Separate literal acceptance-oracle completion from functional supersession in terminal work judgments; an `OBVIATED` event must state which original clauses remain literally unmet and must not also claim “acceptance satisfied” when an alternative design dissolved the need.
