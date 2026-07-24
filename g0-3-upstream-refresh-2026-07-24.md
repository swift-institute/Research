# G0-3 — Official Upstream Points: Verification Result

```
<!--
---
version: 1.0.0
last_updated: 2026-07-24
status: COMPLETE
tier: 2
scope: G0-3 of the N7/N8 gate — verify the heritage record's upstream citations
       for apple/swift-http-api-proposal, and reconcile the three conflicting
       apple/swift-crypto version claims. Verification only; nothing refreshed,
       renamed, or re-pinned.
---
-->
```

## Verdict table

| Item | Criterion | Result |
|---|---|---|
| **(a)** | Cited commit exists upstream | ✅ **MET** |
| **(a)** | Record's line citations resolve to what it claims | ✅ **MET — 6 of 6 verified exactly** |
| **(a)** | Local checkout can read them | ❌ **NOT MET** — 22 behind; commit absent locally |
| **(b)** | Which swift-crypto version is reviewed | ✅ measurable — **4.3.0** |
| **(b)** | Which is actually resolved | ✅ measurable — **4.5.1** |
| **(b)** | Reviewed version == resolved version | ❌ **NOT MET — two minor versions of drift** |
| **(b)** | Local mirror can answer the question | ❌ **UNMEASURABLE at depth 1** — tags stop at 4.3.0 |

**Headline:** (a)'s citations are **sound** — the "build, not adopt" verdict needs
no re-examination on citation grounds. (b) has a **real gap**: the reviewed
upstream evidence is 4.3.0, but 4.5.1 is what ships.

---

## (a) `apple/swift-http-api-proposal` — citations verified, checkout stale

**Remote identity resolved** (a configured URL is not evidence): `gh repo view`
→ `apple/swift-http-api-proposal`, public, default branch `main`, last pushed
2026-07-22 — consistent with a cited commit dated 2026-07-21.

**The cited commit exists upstream.** `10db597e0adaeba2b84fd23688cd1b02d7644793`
= *"Import swift-http-server as a submodule (#137)"*, 2026-07-21T20:11:11Z,
retrieved via the API with a positive control (the same probe resolves the local
HEAD `8636308`). It is **absent from the local checkout**, which is 22 behind at
`8636308`, 2026-04-01. The checkout is **not shallow** and **clean** (0 dirty
entries), so a refresh would be non-destructive — but none was performed here.

**All six line citations resolve exactly**, checked against the pinned SHA
through the API rather than the stale checkout. Because the record's URLs pin the
commit, the citations are immutable references and were verifiable without
refreshing anything:

| Record's claim | Citation | Verified content |
|---|---|---|
| semantic/execution separation | `Package.swift:25–32` | products separate `HTTPAPIs` from `URLSessionHTTPClient` / `AHCHTTPClient` ✓ |
| — same | `Package.swift:60–108` | `HTTPAPIs` target deps are `AsyncStreaming` + `HTTPTypes` only; `HTTPClient` pulls `AsyncHTTPClient` ✓ |
| move-only ownership | `HTTPClient.swift:16–38` | `public protocol HTTPClient<RequestOptions>: Sendable, ~Copyable, ~Escapable`; `Writer`/`Reader` are `~Copyable` ✓ |
| upstream TODOs on non-escapable readers | `HTTPClient.swift:29–37` | two `// TODO: Check if we should allow ~Escapable readers` ✓ |
| region transfer via `sending` | `HTTPServerRequestHandler.swift:85–90` | `reader: consuming sending Reader`, `responseSender: consuming sending ResponseSender` ✓ |
| test support needs `nonisolated(unsafe)` | `Disconnected.swift:14–36` | `private nonisolated(unsafe) var value: Value?` ✓ |
| borrowed buffers lent via callback | `AsyncReader+CollectInto.swift:18–49` | `into buffer: inout Buffer`; `reader.read { (chunk: inout Self.Buffer, …) }` ✓ |

**Conclusion.** The Adopt/Adapt/Reject table is **not** resting on unreadable
evidence — it is resting on evidence that is *locally* unreadable and *remotely*
intact. The defect is checkout staleness, not citation drift. **No basis here to
re-examine the "build, not adopt" verdict.** (Its independent grounds —
`[HERITAGE-001]` firing nowhere, and NIO making release purity unreachable by
construction — were out of scope and are untouched.)

**Recommended:** refresh the checkout so future readers can verify locally. It is
clean and non-shallow, so this is a fast-forward with no loss. Not done here —
it is someone's checkout and the assignment was verification.

---

## (b) `apple/swift-crypto` — the reviewed version is not the shipped version

### What each source actually says

| Source | Version | Status |
|---|---:|---|
| Heritage record ("reviewed upstream evidence", `:120`, `:449`) | **4.3.0** | what was reviewed |
| Consumer manifests (e.g. certificates fork `Package.swift:47`) | **`from: "4.3.0"`** | a **floor, not a pin** — range `>=4.3.0 <5.0.0` |
| Resolved state, certificates fork | **4.5.1** (`47d3869a…`) | **what actually ships** |
| Third cited figure | 3.12.5 | matches neither review nor resolution |
| Fourth cited figure | 4.5.0 | exists upstream; is neither reviewed nor resolved |

**The conflict dissolves once `from:` is read as a range.** Nothing pins
swift-crypto. The record reviewed 4.3.0; the manifest permits anything below
5.0.0; resolution has floated to **4.5.1**. Upstream currently offers 4.3.1,
4.4.0, 4.5.0, 4.5.1 and two 5.0.0 betas.

### The finding

**Two minor versions of unreviewed upstream sit in the shipped graph.** "Use
official 4.3.0 directly as sanctioned backend" describes a review that no longer
matches what resolves. This is not a version-choice error — 4.5.1 may well be
fine — it is that **the sanctioning evidence and the shipped artifact have come
apart**, and nothing in the manifest prevents them drifting further.

Note this is the *same shape* as the corpus-invalidation incident analysed in
`rfc-9110-9112-law-inventory-2026-07-24.md` §1.1: an unpinned dependency moving
underneath a review that was performed once. There the mechanism was a mirror map
with no version gate; here it is `from:` with no upper reconciliation.

### The mirror cannot answer the question — and fails silently

`swiftlang/swift-crypto` is a **depth-1 shallow clone** (1 commit reachable,
HEAD `d79c573` dated 2025-07-23). It lists 72 tags, of which **3.12.5 and 4.3.0
resolve, and 4.5.0 is absent entirely** — its newest visible tags are 4.1.0,
4.2.0, 4.3.0.

⚠️ **So a version check run against the local mirror concludes "4.3.0 is
current" — a true answer to a different question**, and precisely the answer that
would conceal the 4.3.0 → 4.5.1 drift. The shallow clone does not error; it
answers confidently from a truncated history. Any G0 re-check must query
upstream, not the mirror.

### Identity finding — directory name, remote URL, and actual repository all disagree

Resolving identities rather than trusting configured URLs turned up a
three-way mismatch worth recording:

| Local directory | Configured remote | **Actually resolves to** |
|---|---|---|
| `swiftlang/swift-crypto` | `github.com/apple/swift-crypto.git` | `apple/swift-crypto` |
| `swift-foundations/swift-crypto` | `github.com/swift-foundations/swift-crypto.git` | **`swift-foundations/swift-crypto-reservation-2026`** |

The second is **good news**: the record prescribed *"rename the unrelated empty
Institute reservation to `swift-crypto-reservation-2026`"* and **that rename has
already happened upstream** — the URL redirects. The local directory name is
merely stale. But it means the configured URL names a repository that no longer
exists under that name, which is exactly why identity must be resolved rather
than read.

The first is a **naming hazard**: a directory called `swiftlang/…` holding a
mirror of `apple/…`. Nothing is broken, but a lane reasoning from directory
layout would attribute this mirror to the wrong org.

### swift-asn1, confirmed

`apple/swift-asn1` **1.7.1** (`a9a5efd4…`) is present in the resolved graph,
entering **transitively through swift-crypto** (which declares it
`from: "1.2.0"`). Consistent with the certificates lane's record: **FETCHED,
never imported, and never to be recorded as pruned.**

---

## Recommendations

**G0-3a — refresh the `swift-http-api-proposal` checkout.** Clean, non-shallow,
22 behind; a fast-forward restores local verifiability of citations that are
already known-good remotely. Low value for correctness, real value for the next
reader.

**G0-3b — decide what "sanctioned backend" pins to.** The gap is not 4.5.1; it
is that review and resolution are unlinked. Either re-review at 4.5.1 and record
that, or constrain the manifest range so resolution cannot outrun review.
Recommending the former: `from:` is the right shape for a widely-shared
dependency, and the fix belongs in *review cadence*, not in tighter pinning that
would fragment the fleet.

**G0-3c — deepen or replace the shallow mirror.** While it is depth-1 it will
keep returning confident, wrong answers to history and version questions. If it
exists only to satisfy offline resolution, note that in place so no one reasons
from it.

**G0-3d — rename the stale local directory** `swift-foundations/swift-crypto` →
`swift-crypto-reservation-2026` to match the upstream rename already performed.
Cosmetic, but it removes a live identity trap.

**Method note carried forward.** Every negative in this document was
positive-controlled: the upstream-commit probe was checked against a commit known
to exist, the tag probe against a tag resolved locally. Both defects found here —
the shallow mirror and the redirected reservation — produce *confident wrong
answers* rather than errors, which is the class that survives casual checking.
