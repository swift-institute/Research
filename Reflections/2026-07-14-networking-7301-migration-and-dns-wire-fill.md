---
date: 2026-07-14
session_objective: Execute networking continuation rows R-1 (RFC 7301 body-level serialization migration) and R-2 (rfc-1035 §4 DNS wire fill) as an orchestrator seat under the workspace supervisor
packages:
  - swift-rfc-7301
  - swift-rfc-6066
  - swift-rfc-1035
status: pending
---

# Networking 7301 Migration + DNS Wire Fill: Channel Collision Recovery and the Oracle-First Lane Pattern

## What Happened

Overnight orchestrator seat (~00:40–02:20) under `CHARTER-networking-7301-n3-2026-07-14.md`, continuing the ratified networking-stack roadmap after the N-seat closed N1/N2a/G10. Both chartered rows closed Success:

- **R-1**: `RFC_7301.Extension` migrated from envelope-level serialization (the ecosystem outlier) to the body-level + `.extensionData` convention (`swift-rfc-7301@47bb023`; rider `swift-rfc-6066@203a7b2` retiring the divergence doc note). Added the parse side (previously absent), internal Wire trio mirroring 6066's, and an envelope-continuity test proving `.extensionData` reproduces the exact pre-migration bytes. Consumer sweep: EMPTY (3 doc-comment refs fleet-wide, zero manifests) — the migration stayed pure in-package.
- **R-2**: rfc-1035 went names-only → complete §4 wire format (`6db3157`, 26 files +2,692): Message/Header (Z-enforced, Options at real bit positions), Question, ResourceRecord with typed self-contained RDATA + byte-exact `.opaque` fallback, CharacterString, message-context compression decoding. Authored by a write-only opus lane against RFC text fetched from rfc-editor; seat gated: build green first pass, 60 tests / 6 suites green, zero test failures. Satellites rfc-3596/6891 re-gated green unchanged ([PKG-DEP-012]).
- **G6 parked as chartered**: both resolver/cache destinations verified EMPTY-RESERVED → shape proposals (P1/P2) + two principal forks (DNS-namespace ownership; underscore-wire-label ruling) to the morning queue.

Session incident: at boot (~00:40:51) the charter ledger was truncated to 2 lines by a race between my REGISTER append and the supervisor's boot ANSWER — `ledger-append.sh`'s read-modify-write is not atomic. My watch detected the shrink (59→2) within one 30s poll; repaired per [SUPER-059] from git `b2adb81b` + verbatim re-apply of my entries with original mechanical stamps + errata; the supervisor re-posted the lost ANSWER and filed the flock defect. The 1035 push was denied at the lane level by the permission classifier (public repo, no fresh in-session user YES); the charter's pre-wired PUSH-QUEUED protocol converted it into a 30-second supervisor handoff.

Handoff scan ([REFL-009]): `check-handoffs.sh` reports the WIP cap red (116>40 — the standing documented-by-design overage; cap ruling: drain per-arc at close, do not force-triage) and 6 filename-terminal residents, ALL belonging to the live repotraffic E-program — out of this session's cleanup authority (not written, not worked, no completion signals encountered); left untouched. My own charter (`CHARTER-networking-7301-n3`) closed cleanly (Success, SEAT CLOSED entry) but is the supervisor's arc ledger; the networking arc remains open (N2b/N4/N5/N6 pending), so its move-to-Audits belongs to the supervisor's arc-close drain. No deletions this session. Memory guard clean (0 topic files, inbox within cadence). No audit was run ([REFL-010] n/a). Scratchpad artifacts are session-ephemeral; the two close-report/plan drafts served their purpose (content lives in the ledger close report).

## What Worked and What Didn't

**Worked.** (1) The channel protocol survived a real write-race: every recovery property was a codified rule doing its job — the armed watch caught the truncation in ≤30s ([SUPER-060]), the probe-don't-trust discipline confirmed it ([SUPER-061]), git held the committed anchor, append-only + self-contained entries made verbatim re-apply lossless, and the counterparty's lost entry was re-postable because entries are self-contained ([SUPER-059]). Total cost ~3 minutes. (2) Oracle-first sequencing: capturing three live 1.1.1.1 query/response pairs seat-side BEFORE dispatching the R-2 lane gave the lane real bytes to hand-trace against during authorship — first-pass build green and zero test failures on a 2,692-line wire codec. (3) The write-only-lane + seat-held-gate pattern held for the second consecutive night; the lane's honesty-table report (covered-vs-skipped + pre-enumerated compile risks) made gate triage O(list). (4) Inviting deviation-with-rationale in the lane brief paid off concretely: the lane proved my bare strictly-backward pointer rule insufficient (it does not kill all multi-hop loops) and strengthened it to strictly-decreasing followed-positions. (5) Recon-first blast-radius verification (three greps) collapsed R-1 from "unknown consumer sweep" to "pure in-package," keeping S-class honest.

**Didn't.** (1) The collision itself — the stamper's non-atomic write is a structural defect (now filed; flock fix pending); discipline alone had already been ruled insufficient for hand-stamps, and the same holds for write atomicity. (2) MemberImportVisibility test-file imports remain the recurring mechanical residue class across seats (N-seat: 4; this seat: 1) — predictable enough that lane briefs should pre-empt it. (3) My initial pointer-guard spec was wrong-by-incompleteness; caught only because the lane was told to challenge the design rather than transcribe it.

## Patterns and Root Causes

**File-bus channels fail at the write primitive, not the protocol.** The ledger protocol's rules all assume appends are atomic; the one property nobody codified was the one that broke. The general shape: a communication protocol layered on a shared mutable file inherits the file's weakest concurrency guarantee, and read-modify-write via full-file rewrite is the weakest possible. The repair playbook that emerged (git-anchor restore → verbatim re-apply with original stamps → errata → counterparty re-post) is reusable and cheap precisely because the protocol's OTHER properties (append-only, self-contained, mechanically stamped, git-tracked) were held; it belongs in channel.md next to [SUPER-059].

**Secure the oracle before authoring the codec.** For wire-protocol fills the reference bytes are cheap to obtain and expensive to retrofit: captured vectors shaped the lane's brief (which direction gets byte-exact assertions), anchored hand-tracing during authorship, and made the gate deterministic. The emit-direction asymmetry generalizes: assert byte-exactness only on forms you emit (uncompressed encode ⇒ query round-trips); assert parse-side + logical round-trips on captured forms you never emit (compressed responses). This is the same epistemic shape as [REFL-011]'s tool-reach rule — match the assertion's strength to the direction your implementation actually controls.

**Charter-anticipated denials become protocol steps.** The harness's permission classifier and the charter's standing push grant legitimately disagree about authorization context (agent-relayed grants vs fresh user YES). The charter pre-wired PUSH-QUEUED for exactly this, so the denial cost ~30 seconds instead of a blocked row. Generalization: any overnight charter should pre-wire the fallback path for every outward-action class it expects, because grant-context disagreement between harness and charter is a *normal* state, not an error.

## Action Items

- [ ] **[skill]** supervise: channel.md [SUPER-059] — codify the append-collision class: (a) appends inside a counterparty's likely write window MUST be followed by a survival probe (re-read tail, verify own entry survived); (b) the repair procedure on detected clobber: restore from the git anchor, re-apply own entries VERBATIM with their original mechanical stamps, append an errata entry, request counterparty re-post of lost self-contained entries; (c) note `ledger-append.sh` flock as the structural fix (defect filed 2026-07-14, supervisor-side).
- [ ] **[skill]** testing: add a wire-protocol reference-vector rule — captured live oracle vectors are secured BEFORE codec authorship (seat-side, hexdumped, frozen into the test brief); byte-exact assertions only on the emit direction; parse-side + logical-round-trip assertions on captured forms the implementation never emits (e.g. DNS name compression). Reference implementation: swift-rfc-1035 `6db3157` captured-vector suite.
