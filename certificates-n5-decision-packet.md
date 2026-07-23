# Certificates N5 Decision Packet — [PLAT-ARCH-008a] Confirmation and Fork Authorization

<!--
---
version: 1.0.0
last_updated: 2026-07-23
status: DECISION
tier: 2
scope: certificate/ASN.1/trust decision gates only; no runtime, manifest,
  repository, or dependency mutation is proposed or authorized by this packet
changelog:
  - 0.1.0 (2026-07-23): Initial decision packet extracting the two open
    principal gates (GATE A: swift-certificates-system [PLAT-ARCH-008a]
    exception; GATE B: Apple SwiftASN1 / swift-certificates fork
    authorization) from the Wave-3 implementation/heritage/dependency
    record v1.1.0 and the certificate-system trust adjudication note.
---
-->

## Purpose and provenance

Two decisions block networking milestone N5 ("certificate heritage and semantic
leaves", record `native-networking-wave-3-implementation-heritage-dependency-record.md:740`–`:747`).
Both are principal-only gates: the [PLAT-ARCH-008a] exception is PROVISIONAL and
"requires explicit user confirmation before applying"
(`Skills/platform/composition.md:13`), and fork/rename/publication require
separate explicit per-action authorization
(`Skills/swift-package-heritage/SKILL.md:364`–`:379`; record `:367`–`:372`).

Sources, in precedence order:

1. `Research/native-networking-wave-3-implementation-heritage-dependency-record.md`
   v1.1.0 (Tier 2 RECOMMENDATION, 2026-07-22) — "the record"; all bare `:N`
   anchors below refer to it.
2. `Research/native-networking-wave-3-certificate-system-trust-adjudication.md`
   (untracked, 2026-07-22) — "the adjudication note", anchors `note:N`.
3. `Skills/platform/composition.md` ([PLAT-ARCH-008a]) and
   `Skills/swift-package-heritage/SKILL.md` ([HERITAGE-001/002/007]).

This packet asks for decisions; it performs nothing. Per the record, no source
edit outside Research, repository creation, push, rename, transfer, visibility
change, tag, or release is authorized (`:49`–`:52`).

---

## GATE A — `swift-certificates-system` [PLAT-ARCH-008a] exception

### Decision requested

Confirm (or reject) each of the four [PLAT-ARCH-008a] criteria for the proposed
L3 integration/unifier `swift-certificates-system` (record `:152`, `:266`–`:284`;
note `:43`, `:45`–`:51`). The record states N5/N8 "remain blocked until the user
confirms all four [PLAT-ARCH-008a] criteria verbatim" (`:269`–`:270`).

The four criteria, verbatim from the record (`:271`–`:277`), with the skill's
canonical wording (`composition.md:17`–`:20`) and the evidence:

| # | Record wording (`:271`–`:277`) | Skill wording (`composition.md:17`–`:20`) | Evidence |
|---|---|---|---|
| (a) | "Certificates is domain authority for trust-provider selection" | "Domain authority: The package is the canonical owner of the concept that varies by platform." | The certificate domain owns trust acquisition: Darwin anchors come from a typed Security.framework surface, Linux anchors from distribution trust-store discovery; only the Certificates domain can decide which provider is production-correct (`:150`–`:152`, `:257`–`:262`; note `:41`–`:43`). |
| (b) | "only typed Institute certificate/platform-integration modules are imported, never platform C" | "Kernel imports only: All platform access goes through `import Kernel` (L3) or `import Kernel_Primitives` (L1) — never raw `import Darwin`/`Glibc`/`Musl`/`WinSDK`." | Its only dependencies are `Certificates + Certificates Darwin Standard + Certificates Linux` (`:209`–`:210`); those integrations in turn import typed L2 Darwin Security surfaces and Kernel File/Path APIs, never Glibc/Musl/raw Security (`:150`–`:151`, `:205`–`:208`, `:474`–`:476`). **Note the wording divergence flagged in "Contradictions" below.** |
| (c) | "the conditional selects trust domain strategy, not a syscall" | "Domain strategy, not syscall selection: The conditional selects between domain-level strategies or defines platform-varying vocabulary types — it does not wrap raw syscalls." | The conditional chooses the Darwin-trust versus Linux-trust integration strategy behind one typed system-trust witness; the syscalls/SDK calls live below, in the L2 typed surfaces (`:152`, `:258`–`:262`; note `:43`, `:47`–`:49`). Analogous to the accepted `swift-io` kqueue-vs-epoll strategy conditional (`composition.md:27`). |
| (d) | "pushing it into Kernel would contaminate Kernel with certificate semantics" | "Irreducible: The platform variation cannot be pushed to the platform stack without Kernel absorbing domain semantics it shouldn't own." | Kernel owns no concept of trust anchors, certificate stores, or WebPKI policy; hosting the selection there would make Kernel absorb certificate semantics (`:276`–`:277`; note `:49`–`:50`; rationale `composition.md:44`). |

### Consequence of each outcome (verbatim in substance, `:279`–`:284`)

- **If confirmed**: `swift-certificates-system` is the sole production-default
  selector and exports one typed system-trust witness; `HTTP.Client` depends on
  that L3 surface for its default while retaining explicit witness injection for
  tests and configuration; Workspace and other L5 consumers do not choose Darwin
  versus Linux (`:279`–`:283`; note `:50`–`:51`).
- **If any criterion is rejected**: the package/DAG returns to architecture
  review; "no platform selection leaks upward as a workaround" (`:283`–`:284`).

---

## GATE B — Apple SwiftASN1 / swift-certificates fork authorization

### Decision requested

Authorize (or decline) the true-fork heritage plan for the two Apple-derived
packages. Per [HERITAGE-001] both verifications pass 4/4, so "true fork heritage
is mandatory if this material … lineage remains" (`:335`–`:336`, `:349`–`:350`;
`SKILL.md:45`–`:55`). Per [HERITAGE-007], each GitHub-side step needs its own
explicit per-action authorization (`SKILL.md:364`–`:379`); this packet requests
the architecture-level authorization the record's G0/N5 gates demand
(`:713`–`:716`, `:740`–`:747`, `:855`–`:866`) — execution keystones remain
per-action.

#### B.1 — Which repos, which upstreams

| Institute publication | Upstream | Reviewed evidence pin (2026-07-22, NOT the fork point) | [HERITAGE-001] |
|---|---|---|---|
| `swift-foundations/swift-certificates` (L3 chain/policy runtime, `:148`, `:329`–`:338`) | `apple/swift-certificates` | 1.18.0 at `24ccdeee…` (`:330`, `:436`–`:437`) | 4/4 PASS (`:329`–`:335`) |
| provisional ITU-T X.680/X.690 authority-bearing owner(s) (L2, `:146`, `:340`–`:352`) | `apple/swift-asn1` | 1.6.0 at `9f542610…` (`:344`, `:437`) | 4/4 PASS (`:340`–`:349`) |

Explicitly NOT a fork: `apple/swift-crypto` fails [HERITAGE-001] condition 1
("FAIL — no adapted lineage", `:316`) — it is used directly as the sanctioned
unmodified backend at official 4.3.0
`fa308c07a6fa04a727212d793e761460e41049c3` (`:106`–`:108`, `:312`–`:328`,
`:363`); "Never publish two `swift-crypto` identities" (`:363`).

#### B.2 — Fork points must be refreshed at execution

The local release pins above "are the 2026-07-22 content-review evidence, not
permission to fork"; "the exact fork point must be refreshed from the official
repository and pinned immediately before an authorized operation"
(`:307`–`:310`). Each publication is one Institute commit directly atop the
refreshed, pinned fork point per [HERITAGE-002] (`:298`, `:364`, `:469`;
`SKILL.md:86`–`:137`: parent = fork-point commit, tree = Institute publication
state, upstream history intact and reachable).

#### B.3 — Reservation renames (non-destructive)

Both target names are occupied by empty, original, unrelated Institute
reservations — "they are not Apple forks" (`:96`). The plan (`:354`–`:365`):

- Rename the unrelated empty Institute `swift-crypto` reservation to
  **`swift-crypto-reservation-2026`** "or another approved noncanonical
  identity" (`:363`).
- Rename the unrelated empty `swift-foundations/swift-certificates` reservation
  to **`swift-certificates-reservation-2026`** (`:364`).
- Preservation rule: "Preserve unrelated Institute history under non-canonical
  reservation names if migration is authorized. Never merge Apple history into
  them or label reservations as forks" (`:296`). Reservation history must remain
  public/reachable with verified redirect behavior (`:363`–`:364`).

#### B.4 — ASN.1 authority-naming question

- **Preferred (record + adjudication note): one cohesive fork.** "one cohesive
  renamed true fork of official `apple/swift-asn1`, one publication commit atop
  the refreshed fork point, with separate X.680 notation and X.690 BER/CER/DER
  products" (`:365`; also `:146`, `:181`–`:184`, `:467`–`:469`; note `:15`–`:18`,
  `:37`).
- **Rejected alternative: two-repository split.** "The decomposed two-repository
  alternative remains rejected until it proves mechanically truthful heritage for
  one upstream repository split across two owners" (`:365`); the note adds
  "identity avoidance is not decomposition evidence" (note `:60`–`:62`).
- **Identity constraint**: Apple Crypto's manifest unconditionally declares
  `apple/swift-asn1` (`apple/swift-crypto` `Package.swift:248`–`:256`, per record
  `:480`–`:481`), so "the Institute adaptation must use distinct
  authority-bearing identity/identities"; "identity avoidance alone cannot
  select that L2 name" (`:242`–`:243`, `:365`); no duplicate SwiftPM identity and
  no direct Institute import of `SwiftASN1` (`:483`–`:485`; note `:26`–`:28`).

#### B.5 — What remains provisional pending the SwiftPM normalization probe

"Exact package/product/module spellings await the isolated SwiftPM normalization
probe and user confirmation" (`:146`). The note narrows the probe's authority:
it "may refine the spelling but may not reopen the approved
one-family/two-product authority cut", and its load-bearing result is a
canonical Institute identity that cannot collide with Apple Crypto's transitive
`apple/swift-asn1` (note `:23`–`:28`). No ASN.1 repository operation is
authorized before that resolves (`:365`).

---

## Pre-execution checklist (mandated by the record)

Before any authorized fork/rename/publication operation:

1. **Refresh upstream HEADs and pin exact fork points** immediately before the
   operation (`:307`–`:310`, `:713`–`:714`).
2. **Recheck live state**: remotes, default branches, releases/tags, dependency
   references, forks, visibility, and official upstream HEADs (`:356`–`:358`).
3. **Apple Crypto clean-room resolved-graph artifact**: audit the complete
   resolved graph of official 4.3.0, "including `swift-asn1`, for local and
   remote SwiftPM identity collisions" (`:363`, `:714`–`:715`); the clean room
   "records Apple Crypto's exact resolved package identities, revisions, and
   fetched products, including SwiftASN1 unless pruning is actually proved"
   and "fails on every duplicate SwiftPM identity" (`:816`–`:818`); "product
   pruning of SwiftASN1 may be recorded only if that gate proves it"
   (`:371`–`:372`).
4. **Remote collision/consumer/redirect probes**: "Audit remote candidates and
   consumers; local absence proves nothing" (`:365`); "any material consumer of
   an empty reservation stops the plan for a replacement/redirect review"
   (`:358`–`:359`); verified redirect behavior for renamed reservations (`:363`).
5. **Acceptance artifacts per derived package**: "the fork point,
   publication-tree source commit, path mapping, deleted upstream surfaces,
   attribution files, and exact `git log --first-parent` shape" (`:367`–`:369`).
6. **Isolated SwiftPM naming/module-normalization probe** for the ASN.1 owner
   (note `:85`–`:87`; record `:146`).

## Risks and stop conditions (verbatim in substance)

- **STOP (ASN.1 row, `:365`)**: "unresolved authority naming, module
  normalization, remote identity, consumer, redirect, visibility, [MOD-041]
  cohesion, or [HERITAGE-002] mechanics."
- **STOP (crypto/certificates rows, `:363`–`:364`)**: any unresolved identity
  collision; a consumer depending on a reservation; reservation history not
  public/reachable or redirect unverified; two `swift-crypto` identities.
- **STOP (N5, `:743`–`:747`)**: "wrong ancestry, direct current Apple product
  use, Foundation/platform-C import in an Institute main target, missing typed
  errors, incomplete system roots, or any failing chain/hostname/policy
  fixture"; GO only after heritage, import, fixture, and Apple/Linux trust
  gates.
- **STOP (first leaf gate, note `:91`–`:93`)**: "any unresolved name, ancestry,
  identity, bounds, import, or vector failure."
- **Standing rejections (`:489`–`:492`; note `:55`–`:68`)**: direct current
  Apple ASN.1/certificate product dependencies; a clean-room DER/certificate
  security rewrite; OpenSSL/system TLS; guessed trust; disabled validation;
  hard-coded incomplete Linux root paths; combining the TLS-Crypto and
  Certificates-Crypto adapters; L4/L5 choosing Darwin versus Linux.
- **[HERITAGE-002] shape risks (`SKILL.md:120`–`:126`)**: forbidden orphan
  publication on a fork, mirror-and-sync upstream merges, and
  parent-pointer-dropping squashes.
- **Unwind boundary (`SKILL.md:381`–`:387`)**: reversible until external
  consumers bind to the new URL; after that, consumer-side coordination is
  required.

## What is explicitly NOT being asked

- **No `CryptoExtras`/RSA release**: it "remains a separate STOP/GO triggered by
  fixture evidence" (`:746`–`:747`; also `:485`–`:487`, `:863`–`:864`; note `:79`).
- **No tags or releases**: "No archive/delete, force-push, history rewrite, or
  release/tag is implied" (`:824`–`:826`).
- **No archive/delete of the reservations**: renames only, history preserved
  (`:296`, `:363`–`:364`, `:825`).
- **No repository operation now**: fork/rename/repository creation/publication
  "require a separate explicit authorization after this architecture is
  re-approved" (`:369`–`:370`); each GitHub-side step then needs its own
  per-action keystone per [HERITAGE-007] (`SKILL.md:364`–`:379`).
- **No commit/push of the Research records**, and `_index.json` is untouched
  (`:868`–`:870`).
- **No Institute crypto fork or implementation** (`:321`–`:322`, `:456`–`:457`).

## Contradictions and tensions found (for principal awareness)

1. **Criterion (b) wording divergence.** The skill's canonical criterion 2 is
   "All platform access goes through `import Kernel` (L3) or `import
   Kernel_Primitives` (L1)" (`composition.md:18`), but the record's (b) reads
   "only typed Institute certificate/platform-integration modules are imported,
   never platform C" (`:272`–`:273`), and the concrete graph routes Darwin
   access through typed L2 `swift-darwin-standard` Security surfaces — not
   through Kernel (`:150`, `:205`–`:206`, `:474`–`:475`). The record's variant is
   consistent with the post-2026-04-30 platform-stack revision ("everything
   above L2 composes via L2's typed API", `composition.md:42`), but a verbatim
   confirmation of the skill's criterion 2 would not literally describe this
   package. Confirming GATE A as phrased by the record implicitly accepts the
   broader "typed Institute modules, never platform C" reading; the principal
   may wish to confirm that reading explicitly (or amend the skill wording).
2. **How settled is the one-cohesive-fork cut?** The record labels it
   "**Preferred proposal pending probe/user confirmation**" and keeps "the exact
   cut … provisional" (`:365`, `:243`, `:146`), while the adjudication note
   hardens it: the probe "may not reopen the approved one-family/two-product
   authority cut" (note `:23`–`:25`). The note is untracked and self-describes
   as "ACCEPTED ARCHITECTURE CONTENT" whose final ratification still requires
   principal confirmation (note `:3`–`:6`), so GATE B should state whether the
   principal is confirming the cut itself (note's framing) or only the
   preference pending probe results (record's framing).
3. **[HERITAGE-007] step 1 offers "delete or rename"** (`SKILL.md:373`), but the
   record forbids the delete arm for these reservations ("No archive/delete",
   `:825`; preservation rule `:296`). Not a conflict in practice — rename is the
   only compliant arm here — but authorization language should say rename-only.
4. **No contradiction found** between the record's four criteria, the note's
   restatement (note `:45`–`:50`), and the record's [HERITAGE-001] tables versus
   the skill's four-condition test; the note's rejected-alternatives list
   matches the record's (`:489`–`:492` vs note `:53`–`:68`).

## Requested confirmations (summary)

- **GATE A**: confirm criteria (a)–(d) for `swift-certificates-system`
  verbatim, or reject one and return the DAG to architecture review — noting
  contradiction 1's (b)-wording choice.
- **GATE B**: authorize the true-fork architecture — `apple/swift-certificates`
  → Institute `swift-certificates` and `apple/swift-asn1` → one cohesive
  renamed X.680/X.690 authority fork (spelling pending probe) — plus the two
  non-destructive reservation renames (`swift-crypto-reservation-2026`,
  `swift-certificates-reservation-2026`), with execution still gated on the
  pre-execution checklist and per-action [HERITAGE-007] keystones.

---

## DECISION (2026-07-23 — final adjudication under principal delegation)

The principal delegated final adjudication of this packet to the team-lead
session of 2026-07-23 ("adjudicate in final … proceed straight to
implementation"). Rulings:

- **GATE A: CONFIRMED — all four criteria (a)–(d).** Criterion (b) is confirmed
  in the record's broader reading: "only typed Institute
  certificate/platform-integration modules are imported, never platform C" —
  consistent with the post-2026-04-30 revision in which L2 spec packages are the
  exclusive platform-C home and everything above composes via L2's typed API
  ([PLAT-ARCH-008j], composition.md:42). Follow-up queued: amend
  [PLAT-ARCH-008a] criterion 2's wording via skill-lifecycle so the skill text
  matches the operative rule (inbox entry).
- **GATE B: AUTHORIZED.** (1) True fork `apple/swift-certificates` → Institute
  `swift-certificates`; (2) ASN.1: the **one-cohesive-fork cut itself is
  CONFIRMED** (the adjudication note's hardened framing adopted) — the isolated
  SwiftPM normalization probe may refine spelling only, not reopen the
  one-family/two-product cut; (3) reservation renames are **rename-only**
  (`swift-crypto-reservation-2026`, `swift-certificates-reservation-2026`) —
  the [HERITAGE-007] step-1 delete arm is explicitly off the table.
- **Execution order stands as mandated**: the pre-execution checklist (upstream
  refresh, Apple Crypto clean-room resolved-graph artifact, remote
  collision/consumer/redirect probes, the ASN.1 normalization probe) runs
  FIRST; every listed STOP condition retains full force; GitHub-side operations
  execute only after the checklist passes, and each is reported to the
  principal on completion. CryptoExtras/RSA, tags/releases, and archive/delete
  remain NOT authorized.
