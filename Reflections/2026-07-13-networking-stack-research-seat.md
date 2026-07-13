---
date: 2026-07-13
session_objective: Overnight read-only Fable research seat producing the pure-institute networking-stack roadmap (inventory → gap map → build order) for morning ratification
packages:
  - swift-sockets
  - swift-io
  - swift-kernel
  - swift-posix
  - swift-rfc-8446
  - swift-rfc-9112
  - swift-whatwg-url
  - swift-urlrequest-handler
  - swift-transport-layer-security
status: pending
---

# Networking-Stack Research Seat: Five-Lane Census, a Charter Premise Correction, and an Evidence-Driven Ruling Re-Price

## What Happened

Chartered as a fresh read-only research seat (`CHARTER-networking-stack-research-2026-07-13.md`)
under the workspace supervisor, deliverable `DECISIONS-pass2/networking-stack-roadmap.md`.
Boot-handshake on the charter ledger at 22:19; channel confirmed live at 22:20 (both watches
armed with task-id evidence — the night's earlier watch-gap lesson applied). Phase 1 ran as
five parallel sonnet Explore lanes (L1 primitives · L2 swift-standards · L3 http family ·
L3 transport/TLS/DNS · swift-ietf/whatwg census) while the seat read the composition corpus
(de-engine-architecture, standards-gap-roadmap, decomposition-arc-plan, BACKLOG rulings)
itself. Every de-engine §2 replacement-inventory row was re-verified at source and CONFIRMED,
with three sharpenings (swift-sockets also lacks UDP and its reactive path is untested; the
`connect` syscall already exists EINTR-safe at swift-posix; WebSocket's gap is decoder +
handshake). Two ASKs were adjudicated live at minutes-latency: (1) the charter's
`IO.NonBlocking.Selector` premise was corrected — the type does not exist anywhere; (2) the
principal's "swift-url-standard MISSING" ruling was reconciled with the real 3,539-LOC
swift-whatwg-url as a missing S-class *converger*, not an L-class build — presented
explicitly in the deliverable (§1.2 + R8) for the principal's final call. A swift-crypto
v4.5.0 checkout inspection grounded the crypto adjudication (full TLS 1.3 primitive set
verified present, incl. RSA in CryptoExtras). Deliverable written 22:33 (387 lines);
close accepted **Success** and seat released 22:38; the principal RATIFIED the findings
~22:45 ("I endorse all networking findings"; R1 confirmed verbatim: "we want to use
swift-crypto and not create our own") and chartered N1+N2a the same night.

Artifact cleanup ([REFL-008/009]): no root `HANDOFF*.md` files; this seat authored none.
`check-handoffs.sh` reports the store at 111>40 with 6 filename-terminal residents (the
E-program/PROGRAM charters) — all in-flight artifacts of the live overnight program, outside
this seat's cleanup authority (no-touch per [REFL-009a]; the overage is the documented
red-by-design state that drains per-arc). `check-memory-corpus.sh` OK (zero topic files,
inbox within cadence). No `/audit` ran; [REFL-010] n/a. HANDOFF scan: 0 root files found;
0 deleted, 0 annotated; 6 store-resident terminal files noted as another arc's drain queue.

## What Worked and What Didn't

**Worked**: (1) The five-lane fan-out with per-lane grading rubrics returned a complete
Sources-level census in ~5 minutes wall-clock each, with the seat keeping synthesis — the
charter's "subagent read-lanes welcome; the synthesis is yours" split held cleanly. (2) The
ledger channel at full discipline: boot handshake with armed-watch evidence, two ASKs
answered inside a minute, a roll-call caught and ACK'd within one watch cycle, release read
by direct ledger probe when the watch event truncated ([SUPER-061] probe-don't-trust).
(3) Interim ASKs while lanes still ran (the url-standard reconciliation went up BEFORE
Phase 1 finished) — adjudication latency overlapped with lane latency instead of serializing
after it. (4) Verifying the crypto capability claim against a resolved checkout instead of
recall ([RES-037]) — it also surfaced that RSA lives in CryptoExtras, which mattered for the
web-PKI honesty of the adjudication.

**Didn't / friction**: (1) The charter itself carried a non-existent type name as its
transport-tier anchor (`IO.NonBlocking.Selector`) — inherited from a workspace-doc
*illustrative example* ([API-NAME-001]'s example block) that reads as a real type. Cost was
small (one lane prompt asked for verification anyway) but the failure class is real: an
illustrative example in always-loaded context is indistinguishable from a state claim.
(2) Lane E initially got silent zero LOC counts across the board — `xargs wc -l` on paths
with spaces (every institute Sources dir: `Sources/RFC 768/`) drops the files; the lane
self-caught and switched to `-print0 | xargs -0`, but a lane without that reflex would have
graded real packages EMPTY. (3) The first L2 lane dispatch scoped only `swift-standards/` —
the per-authority sub-orgs (swift-ietf, swift-whatwg) where the real content lives surfaced
only from the standards-gap erratum mid-run, costing a fifth lane dispatch. Charter said
"HTTP family" without naming orgs; the seat should have listed `~/Developer` org dirs before
dispatching lanes.

## Patterns and Root Causes

**Illustrative examples age into false state claims.** The `IO.NonBlocking.Selector` error
is not a one-off: always-loaded context (CLAUDE.md critical-requirements examples) presents
type names with no marker distinguishing "real fleet type" from "invented illustration." A
charter author under time pressure transcribes them as anchors ([SUPER-035] pre-dispatch
verification would have caught it — the supervisor classified it as exactly that class).
The cheap structural fix is to make the examples real: every illustrative name in
always-loaded docs should be an actual fleet type, so transcription is harmless. This
composes with tonight's second instance of the same genus — "swift-url-standard MISSING"
was true in the converger frame and false in the implementation frame; the ruling's words
were fine, but pricing it required at-source reconciliation. Both are the
repo-exists ≠ encoded-exists census lesson generalized: *name-exists ≠ type-exists*, and
*gap-named ≠ gap-sized*. The working countermeasure, demonstrated twice tonight, is the
evidence-bearing ASK: present the at-source finding + the consistent reading + the re-priced
cost, and let the ruling's author confirm — cheaper than either silent re-derivation or
blind obedience, and it landed both times without a round-trip to the principal.

**The census silently under-reports without space-safe plumbing.** Institute source dirs
universally contain spaces (`Sources/RFC 768/`, `Sources/IO Events/`). Any LOC/file census
built on unquoted `xargs` returns zeros that look like EMPTY grades — the exact opposite of
the erratum lesson (census by Sources, not ls) if the Sources probe itself is broken. This
belongs in the workspace gotchas so the next census doesn't rediscover it.

**Overlap adjudication with lane latency.** The session's throughput came from treating the
supervisor channel as a concurrent resource: ASKs filed the moment evidence existed, not at
phase boundaries. Combined with [SUPER-063]-style early pointers from the supervisor (three
pointers at boot that pre-empted two would-be wrong turns: routing ruling, gap-map prior art,
crypto honesty framing), the whole arc closed in ~20 minutes of wall-clock research. The
two-tier topology worked exactly as designed: the seat never touched the principal directly.

## Action Items

- [ ] **[skill]** code-surface: [API-NAME-001]'s example block (mirrored in Workspace CLAUDE.md) cites `IO.NonBlocking.Selector`, which does not exist and misled a charter tonight (supervisor-confirmed, ledger 22:29) — replace illustrative non-existent type names with real fleet types (e.g. `Kernel.Event.Source`, `File.Directory.Walk` if real) or mark them `(illustrative)`.
- [ ] **[doc]** Workspace CLAUDE.md Gotchas: add a row — LOC/file censuses over institute packages MUST use `find … -print0 | xargs -0 wc -l`; plain `xargs wc -l` silently reports 0 on the space-bearing `Sources/RFC 768/`-style paths and misgrades REAL packages as EMPTY.
- [ ] **[package]** swift-posix: README's feature list omits its socket surface entirely (14 files / 681 LOC of typed socket policy incl. the EINTR-safe `connect` that stage N1 builds on) — add the socket surface to the README (flagged in networking-stack-roadmap.md §9).
