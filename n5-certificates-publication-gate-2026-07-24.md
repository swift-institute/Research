# N5 Certificates Publication Gate — Clean-Room / Heritage Collision Checklist

**Stamp:** 2026-07-24
**Status:** AUDIT-ONLY. Read-only inspection; no repository, manifest, or source mutation performed or authorized by this note.
**Consumer:** the N5 certificates-fork publication lane (and any lane executing a GitHub-side heritage operation for ASN.1 / certificates / crypto reservations).
**Origin:** extracted and made self-contained from §3 of `Research/n6-tls-engine-scoping-2026-07-23.md`, then **reconciled against `Research/certificates-n5-decision-packet.md` v1.0.0** (its adjudicated GATE A / GATE B and pre-execution checklist), with live remote state independently re-verified on 2026-07-24.

**Why this note exists separately:** the N6 packet's §3 was authored *before* its author had read the decision packet. Several §3 items are now **stale, resolved, or inverted**. This note supersedes §3 for N5 purposes. §6 is the correction register.

**Citations:** `packet:N` = `certificates-n5-decision-packet.md`; `record:N` = `native-networking-wave-3-implementation-heritage-dependency-record.md`; `adj:N` = `native-networking-wave-3-certificate-system-trust-adjudication.md`.

---

## 1. Status board

| Gate / item | State |
|---|---|
| **GATE A** — `swift-certificates-system` [PLAT-ARCH-008a] | **CONFIRMED**, all four criteria (a)–(d), under principal delegation 2026-07-23 (`packet:280-287`). Criterion (b) confirmed in the record's broader reading ("only typed Institute certificate/platform-integration modules, never platform C") per [PLAT-ARCH-008j]; a skill-wording amendment is queued. **N5/N8 are no longer blocked on this.** |
| **GATE B** — Apple ASN.1 / certificates fork authorization | **AUTHORIZED** (`packet:288-294`): true fork `apple/swift-certificates` → Institute `swift-certificates`; ASN.1 cut confirmed; reservation renames **rename-only** (delete arm off the table). |
| **Pre-execution checklist** | **COMPLETE** 2026-07-23 (`packet:303-314`), with one disclosed isolation deviation — see §3 item 3. |
| **Reservation renames** | **EXECUTED and independently re-verified** 2026-07-24 — see §2 / §3 item 4. |
| **ASN.1 publication (8824 + 8825)** | **EXECUTED** — both repos live on GitHub, two-repo split (§4-E1). |
| **Certificates publication** | **NOT DONE — the live gate.** Adapted publication tree must exist first; then fork + [HERITAGE-002] publication commit. See §5-B1. |
| **CryptoExtras/RSA · tags/releases · archive/delete** | **NOT AUTHORIZED** (`packet:300-301`, `:211-225`). |

---

## 2. Provenance ledger (local checkouts + live remotes, verified 2026-07-24)

Local state is read-only `git log`/`remote`; remote state is read-only `git ls-remote` (no fetch, no checkout mutation).

| Directory / identity | Local HEAD | Live remote (2026-07-24) | Shape |
|---|---|---|---|
| `swift-foundations/swift-crypto-reservation-2026` | `d96ccdd` | **RESOLVES `d96ccdd`** | Empty Institute reservation, renamed + PUBLIC. No apple ancestry. |
| `swift-foundations/swift-crypto` (old canonical) | `1a4b60b` (**stale local**) | **redirects → `d96ccdd`** | Rename redirect verified live. Local dir is a pre-rename checkout and no longer mirrors remote topology. |
| `swift-foundations/swift-certificates-reservation-2026` | `a3504eb` | **RESOLVES `a3504eb`** | Empty Institute reservation, renamed + PUBLIC. No apple ancestry. |
| `swift-foundations/swift-certificates` (old canonical) | `c3ae2ec` (**stale local**) | **redirects → `a3504eb`** | Rename redirect verified live. Canonical name vacated for the N5 publication. |
| `swift-foundations/swift-certificates-n5` | `24ccdee`, branch `publication` | remote `upstream` = apple only | **Fork-with-apple-ancestry**, pinned at the reviewed 1.18.0 fork point. **No Institute publication commit atop — on-plan, see §5-B1.** |
| `swift-foundations/swift-certificates-n5-artifacts` | not a git repo | — | Prep artifacts (also mirrored to `Research/certificates-fork-rehearsal-2026-07-23/`). |
| `swift-iso/swift-iso-8824` | `e36eb26` (main) | **EXISTS (published)** | X.680 notation owner; product `ISO 8824`. |
| `swift-iso/swift-iso-8825` | `2945b35` (main) | **EXISTS (published)** | X.690 BER/CER/DER owner; product `ISO 8825`; depends on 8824. |
| `swiftlang/swift-crypto` | `d79c573`, tag **3.12.5** | apple upstream | **Stale shallow mirror — NOT the reviewed pin.** See §5-B2. |
| `swiftlang/swift-asn1` | `a54383a` | apple upstream | Shallow mirror; not the reviewed 1.6.0 pin. |
| `swiftlang/swift-certificates` | `386001a` (1.10.x) | apple upstream | Shallow mirror; not the reviewed 1.18.0 pin. |

**Redirect mechanic — actionable.** The old canonical names currently resolve *by GitHub rename redirect* to the reservation repos. When N5 creates the new `swift-foundations/swift-certificates`, that redirect is superseded. The "history public/reachable with verified redirect" obligation (`record:363-364`) must therefore be asserted against the **reservation name**, which is stable, not against the old canonical name.

---

## 3. The controlling gate — pre-execution checklist (`packet:158-182`), with status

Reported **COMPLETE** 2026-07-23 (`packet:303-314`). Statuses below are as recorded, annotated where this audit re-verified or found a caveat.

- [x] **1. Refresh upstream HEADs, pin exact fork points** (`record:307-310,713-714`). Recorded: evidence pins intact — crypto 4.3.0 `fa308c07`, certificates 1.18.0 `24ccdee`, asn1 1.6.0 `9f54261`; upstream ahead at 4.5.1 / 1.19.3 / 1.7.1. **Ruling:** publication parents pin at the **reviewed** release commits; newer upstream requires a content review before adoption (`packet:348-353`).
- [x] **2. Recheck live state** — remotes, default branches, releases/tags, dependency refs, forks, visibility (`record:356-358`). **Re-verified 2026-07-24 by this audit** (§2). ⚠️ This item is inherently perishable: re-run it immediately before each operation.
- [x] **3. Apple-Crypto clean-room resolved-graph artifact** (`record:363,714-715,816-818`). Recorded result: **`swift-asn1` is FETCHED, NOT PRUNED** — it floats to 1.7.1 via `from: "1.2.0"`; identity set collision-free vs mirrors and workspace. ⚠️ **Disclosed deviation:** the coordinator forbids the isolated-SwiftPM flags, so compensating controls were used (no-mirror proof positive-controlled, `--disable-netrc`/`--disable-keychain`, canonical-URL fetch evidence). **Byte-identical precedent isolation would require a guard exemption** — carry this caveat forward rather than recording the artifact as fully isolated.
- [x] **4. Remote collision / consumer / redirect probes** (`record:358-359,363,365`). Recorded: **zero reservation consumers** (org + global code search); rename targets free; redirects verified. **Independently re-verified 2026-07-24** (§2).
- [ ] **5. Acceptance artifacts per derived package** — fork point, publication-tree source commit, path mapping, deleted upstream surfaces, attribution files, exact `git log --first-parent` shape (`record:367-369`). **OPEN for certificates** (the publication tree does not exist yet). Produced for 8824/8825 via the filtered-import commit maps.
- [x] **6. Isolated SwiftPM naming / module-normalization probe** for the ASN.1 owner (`record:146`; `adj:85-87`). Recorded: both candidate names verified free; module normalization and coexistence with Apple's transitive `swift-asn1` are **build-proven**.

---

## 4. Consolidated collision audit (supersessions applied)

### 4.A Identity collisions

- [x] **A1 — `swift-crypto` (Institute) × `apple/swift-crypto`.** **RESOLVED BY EXECUTION.** Institute reservation renamed to `swift-crypto-reservation-2026`, PUBLIC, redirect verified (§2). Canonical name vacated. Standing rule persists: **never publish two `swift-crypto` identities**; depend on official directly; create no Institute crypto fork (`record:310-311,377`).
- [x] **A2 — Institute ASN.1 authority × transitive `apple/swift-asn1`.** **RESOLVED.** Institute authority identities are `swift-iso-8824` / `swift-iso-8825` — authority-bearing and structurally incapable of colliding with `swift-asn1`. Clean-room proved coexistence; Apple's `swift-asn1` is fetched (not pruned) but never directly imported by Institute code and is not API authority (`record:253-257,498-499`; `packet:139-144,307-309`).
- [x] **A3 — `swift-certificates` (Institute) × `apple/swift-certificates`.** **Reservation side RESOLVED** (renamed to `-reservation-2026`, PUBLIC, redirect verified). **Publication side OPEN**: the canonical name is vacated but the Institute publication has not yet been created (§5-B1).
- [ ] **A4 — Standing audit obligation.** Every duplicate-identity check is re-run at each operation; the clean room **fails on every duplicate SwiftPM identity**; local absence proves nothing (`record:728-730,830-832`). Perishable — re-assert per operation.

### 4.B Heritage dispositions ([HERITAGE-001])

- [x] **B1 — `apple/swift-crypto`: DOES NOT FIRE.** Condition 1 (material lineage) FAILS. Used directly as the sanctioned unmodified backend; no Institute fork or implementation (`record:328-338`; `packet:97-101`).
- [x] **B2 — `apple/swift-asn1`: FIRES** (4/4 PASS). True fork mandatory; satisfied via the two-repo filtered history import (§4.E1).
- [x] **B3 — `apple/swift-certificates`: FIRES** (4/4 PASS). True fork mandatory; **[HERITAGE-002] publication commit still outstanding** (§5-B1).
- [x] **B4 — Institute reservations are NOT forks.** Never merge Apple history into them; never label them forks (`record:110,310`).

### 4.C Provenance / re-derivation contact points

- [ ] **C1** Certificate chain construction / signature verification / policy = true fork of `apple/swift-certificates` `24ccdee`; preserve ancestry, license, NOTICE, attribution; every imported upstream file needs followable history, source/revision mapping, and a modification record (`record:344,833-834`).
- [x] **C2** ASN.1 DER model/codec = true fork of `apple/swift-asn1` `9f54261`, executed as path-filtered imports into 8824/8825 with retained original→filtered commit maps (`packet:325-342`).
- [ ] **C3** Certificate→Crypto binding via `swift-certificates-crypto`: imports only `Crypto` + Institute modules; **must stay separate from the TLS-Crypto adapter** (`record:163,217,268-270`).
- [ ] **C4** `TrustRootLoading`/`systemTrustRoots` **not carried as-is** (upstream: Foundation + Darwin/Glibc/Musl, Linux-only, can degrade to an empty store). Replaced by typed `-darwin-standard` / `-linux` / `-system` integrations; **missing or empty roots are fatal typed errors, fail-closed** (`record:442-445,458-461,488-489`).
- [ ] **C5** RFC 5280 profile law stays in the L2 owner; verifier lineage stays solely in the fork; TLS WebPKI keyUsage/serverAuth-EKU policy is added in the fork, not the L2 owner (`record:307,461-464`).
- [ ] **C6** `_CryptoExtras`/RSA absent from slice 1 — separate STOP/GO on certificate-fixture algorithm evidence (`record:499-501,760-761`; `packet:213-214`).

### 4.D STOP conditions still in full force (`packet:184-209,295-301`)

- [ ] **D1 — ASN.1 row:** unresolved authority naming, module normalization, remote identity, consumer, redirect, visibility, [MOD-041] cohesion, or [HERITAGE-002] mechanics.
- [ ] **D2 — crypto/certificates rows:** any unresolved identity collision; a consumer depending on a reservation; reservation history not public/reachable or redirect unverified; two `swift-crypto` identities.
- [ ] **D3 — N5 leaf:** wrong ancestry · direct current Apple product use · Foundation/platform-C import in an Institute main target · missing typed errors · incomplete system roots · any failing chain/hostname/policy fixture. GO only after heritage, import, fixture, and Apple/Linux trust gates (`record:754-761`).
- [ ] **D4 — [HERITAGE-002] shape risks:** forbidden orphan publication on a fork; mirror-and-sync upstream merges; parent-pointer-dropping squashes.
- [ ] **D5 — Per-action authorization:** each GitHub-side step needs its own [HERITAGE-007] keystone; each is reported to the principal on completion (`packet:295-301`).
- [ ] **D6 — Standing rejections:** direct current Apple ASN.1/certificate product dependencies; clean-room DER/certificate security rewrite; OpenSSL/system TLS; guessed trust; disabled validation; hard-coded incomplete Linux root paths; **combining the TLS-Crypto and Certificates-Crypto adapters**; L4/L5 choosing Darwin vs Linux.
- [ ] **D7 — Unwind boundary:** reversible until external consumers bind to the new URL; after that, consumer-side coordination is required.

### 4.E Formerly-provisional items — now settled

- [x] **E1 — ASN.1 cut: SETTLED, and INVERTED vs the record.** The principal **superseded** the record's one-cohesive-fork preference with **one repo per standard**: `swift-iso/swift-iso-8824` (X.680 notation; product `ISO 8824`, module `ISO_8824`) and `swift-iso/swift-iso-8825` (X.690 BER/CER/DER; product `ISO 8825`, module `ISO_8825`; depends on 8824). The record's rejection condition — "until it proves mechanically truthful heritage for one upstream repository split across two owners" — is **satisfied** by the path-filtered history-import mechanism (reviewed `git-filter-repo`, original→filtered commit map retained, publication commit naming the fork-point SHA). GitHub-native fork badge attaches to at most one repo (8825, the substantive codec mass); 8824 carries heritage via filtered import + attribution/NOTICE (`packet:325-342`).
- [x] **E2 — Convergence layer:** a `swift-standards` convergence package (e.g. `swift-asn1-standard`, the `swift-http-standard` pattern) is **sanctioned only on demonstrated need** — do not mint preemptively (`packet:343-347`).
- [x] **E3 — GATE A / [PLAT-ARCH-008a]:** confirmed; N5/N8 unblocked on that axis (§1).
- [x] **E4 — Visibility:** the STOP-flag raised because the reservations were PRIVATE was adjudicated — visibility flips are pre-approved for Institute packages (standing ruling); **flip-then-rename** satisfies "history public/reachable" (`packet:317-319`).

---

## 5. Live blockers

- **B1 — [HERITAGE-002] publication commit outstanding (the live gate; ON-PLAN, not an anomaly).** `swift-certificates-n5` branch `publication` sits at the raw apple fork point `24ccdee` with no Institute publication commit atop it and only `upstream`=apple configured. This is the **designed** pre-publication state: the fork-point ruling states *"Fork creation waits until the adapted publication trees exist — no raw upstream is parked public in Institute orgs"* (`packet:351-353`). It remains a true gate — D3/D4 and checklist item 5 cannot pass until the adapted tree and its one publication commit exist — but it should be read as *sequence*, not *defect*. **Correction:** an earlier report from this lane framed B1 in defect terms; the decision packet's ruling supplies the missing context.
- **B2 — swift-crypto version discrepancy: EXPLAINED on paper; no fetch required.** Reviewed evidence pin is **4.3.0 `fa308c07`**; upstream is ahead at **4.5.1** (which accounts for the gap-atlas's "4.5.0" from old-lane resolution); the local mirror at **3.12.5** is simply a stale shallow checkout that matches no reviewed pin. Publication parents pin at reviewed commits; newer upstream needs a content review first (`packet:305-307,348-353`). **Residual item is mirror hygiene, not a fork-point question** — and per lead ruling the fetch/deepen is **NOT to be run** while gates are in flight (mirror state is shared; `~/.swiftpm/configuration/mirrors.json` redirects ~1256 entries). Filed as its own scheduled item.
- **B3 — swift-asn1 pruning: RESOLVED (negative).** Not prunable — the clean room proved `swift-asn1` is **fetched, floating to 1.7.1** via `from: "1.2.0"`. Record it as fetched; do not claim pruning (`packet:307-309`; `record:830-832`).
- **B4 — Clean-room isolation caveat (new, open).** The resolved-graph artifact was produced under compensating controls, not true SwiftPM isolation, because the coordinator forbids the isolated flags. Byte-identical precedent isolation needs a guard exemption. Decide whether the artifact stands as-is for publication or requires the exemption first (`packet:311-314`).

---

## 6. Correction register — what this note supersedes in `n6-tls-engine-scoping-2026-07-23.md` §3

| N6 §3 item | Was | Now |
|---|---|---|
| §3-E5 GATE A | "PROVISIONAL; N5/N8 blocked until four criteria confirmed verbatim" | **CONFIRMED** — unblocked (`packet:280-287`) |
| §3-A1 / A3 renames | "decided disposition; staged, not yet published" | **EXECUTED + redirect-verified live** (§2) |
| §3-E1 / E2 ASN.1 cut | "PROVISIONAL; one-cohesive-fork preferred; probe may refine spelling only" | **SETTLED as TWO repos** (8824 + 8825), record preference **superseded** by principal correction (`packet:325-342`) |
| §3-E3 two-repo split | "**REJECTED** unless truthful-split heritage proven" | **SELECTED AND EXECUTED** — condition satisfied by filtered history import; both repos published |
| §3-A2 / E6 / B3 pruning | "UNPROVEN — must be recorded, not assumed" | **RESOLVED: fetched, not pruned**, floats to 1.7.1 |
| §3-D7 / B1 | "HERITAGE-002 unmet by construction" (defect framing) | **True but ON-PLAN** — publication follows the adapted tree by ruling |
| §6.3 R-1 (B2) | "three-way version discrepancy needs chasing" | **Explained**; reviewed pin 4.3.0, upstream ahead 4.5.1, local mirror stale. No fetch needed |
| — | — | **NEW:** clean-room isolation caveat (B4); redirect-supersession mechanic (§2) |

The remainder of N6 §3 (identity-collision framing, [HERITAGE-001] results, provenance contact points, STOP conditions) stands as written.

---

## 7. Verification method

- **Independently verified by this audit (2026-07-24):** all local checkout HEADs/remotes in §2; live `git ls-remote` resolution of both reservation repos, both old-canonical redirects, and both `swift-iso` publication targets.
- **Taken on report from the execution log (`packet:303-314`), not re-run here:** the clean-room resolved-graph artifact, the consumer/code-search sweep, and the module-normalization build proof. Each is re-runnable; checklist item 2 requires live re-verification immediately before any operation regardless.
- **Deliberately not run:** any fetch/deepen against Apple remotes (would mutate shared mirror state while gates are in flight — lead ruling).
- **Probe hygiene note:** an initial `ls-remote` sweep in this lane returned uniform negatives that were **not** evidence — `timeout(1)` does not exist on macOS, so the probes exited 127 without invoking git. Caught by positive control and re-run. Recorded because [the workspace rule](../CLAUDE.md) is explicit that a zero from an untested probe is not evidence of absence.

## 8. Sources

`Research/certificates-n5-decision-packet.md` v1.0.0 (GATE A/B, pre-execution checklist `:158-182`, STOP conditions `:184-209`, DECISION `:274-301`, EXECUTION LOG `:303-357`) · `Research/native-networking-wave-3-implementation-heritage-dependency-record.md` (heritage `:300-386`, N5 leaf `:754-761`, gates `:786-840,861-892`) · `Research/native-networking-wave-3-certificate-system-trust-adjudication.md` · `Research/n6-tls-engine-scoping-2026-07-23.md` §3 (origin) · `Research/certificates-fork-rehearsal-2026-07-23/` · live remote + local git state, 2026-07-24.

**END — audit-only. No design, sequencing, or authorization decision is made here.**
