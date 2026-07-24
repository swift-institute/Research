# G0-4 — Apple Crypto Resolved Graph: Identity Collision Audit

```
<!--
---
version: 1.0.0
last_updated: 2026-07-24
status: COMPLETE
tier: 2
scope: G0-4 of the N7/N8 gate — audit the complete Apple Crypto resolved graph
       for local/remote SwiftPM identity collisions, including swift-asn1.
       Audit only; nothing mirrored, renamed, re-pinned or refreshed.
---
-->
```

## Verdict

**✅ NO COLLISIONS. NO UNRESOLVED REDIRECTS. NO UNINTENDED ANCESTRY. G0-4 is MET.**

No STOP condition found. Per the record's STOP clause (`:725-730`) the triggers
are an unapproved operation, an unresolved identity/consumer/redirect, or an
ancestry shape. **None is present.**

| Criterion | Result | Instrument reached it? |
|---|---|---|
| Every identity resolves local == remote | ✅ MET | yes |
| No identity reachable by two spellings | ✅ MET (one *intended* dual-spelling, §4) | yes |
| No two identities resolving to one repo | ✅ MET | yes |
| Redirects resolved and intended | ✅ MET — **zero redirects in this graph** | yes |
| Ancestry shape for forks | ✅ MET — **neither package is a fork** | yes |

---

## 1. The Apple Crypto graph is exactly two identities

Resolved graph of the certificates fork: **89 pins**, of which the Apple Crypto
subgraph is:

| Identity | Version | Revision | Kind | Location |
|---|---|---|---|---|
| `swift-crypto` | **4.5.1** | `47d3869a7291` | `remoteSourceControl` | `github.com/apple/swift-crypto.git` |
| `swift-asn1` | **1.7.1** | `a9a5efd40eaf` | `remoteSourceControl` | `github.com/apple/swift-asn1.git` |

`swift-asn1` enters **transitively** through swift-crypto's `from: "1.2.0"` —
**FETCHED, never imported, and never to be recorded as pruned**, corroborating
the certificates lane's independent record.

**Remote identity resolved with `gh`, not from `.git/config`:**

| Queried | Resolves to | Fork? | Parent | Archived? | Redirect? |
|---|---|---|---|---|---|
| `apple/swift-crypto` | `apple/swift-crypto` | no | none | no | **none** |
| `apple/swift-asn1` | `apple/swift-asn1` | no | none | no | **none** |

Both are canonical upstream, non-forks, unarchived, public, and neither name
redirects. **Ancestry shape is therefore trivially clean: there is no fork in
this subgraph to have a shape.**

## 2. Collision analysis over the whole 89-pin graph

Rather than checking only the two Apple identities, the collision check ran over
every pin, since a collision is by definition a relationship between two:

- **89 pins · 89 distinct identities · 89 distinct locations.**
- **Duplicate identities: NONE.**
- **Locations claimed by more than one pin: NONE.**

So no identity is reachable by two spellings within the resolved graph, and no
two identities resolve to one repository.

## 3. Competing-identity risk from the ASN.1 split — checked, absent

The ASN.1 work produced `swift-iso-8824`/`swift-iso-8825` from lineage related to
`swift-asn1`, which raises the obvious question of whether an Institute
`swift-asn1` identity exists that could collide with Apple's. **It does not.**
All three plausible spellings return 404: `swift-foundations/swift-asn1`,
`swift-institute/swift-asn1`, `swift-iso/swift-asn1`.

**Consequence:** `swift-asn1` is unambiguous — one identity, one repository,
Apple's — so the transitive fetch cannot be confused with an Institute package.

## 4. The mirror map: what it does and does not do here

**The Apple packages are NOT mirrored.** With a *verified* control (below), a
search of all 1,256 entries for `crypto` or `asn1` returns **zero**. They are the
**only two `remoteSourceControl` pins in the 89** — the other 87 are
`localSourceControl`, redirected to local directories.

⚠️ **This connects G0-4 back to G0-3's drift finding and explains it.** Two
different resolution regimes coexist in one graph:

| Cohort | Count | Resolution | Drift mechanism |
|---|---:|---|---|
| Institute packages | 87 | mirrored → local committed HEAD | pins advance onto already-committed changes, undated |
| **Apple Crypto graph** | **2** | **real upstream, `from:` ranges** | **floats to newest under the major, outrunning review** |

The 4.3.0 → 4.5.1 drift recorded in G0-3 is a direct consequence of this cohort
being unmirrored: it is the only part of the graph that reaches the network, and
so the only part where an upstream release can move it. **Not a defect — it is
the intended shape of "depend directly on official Apple Crypto" — but the review
cadence has to be sized for a dependency that moves on someone else's schedule.**

### The `Kind` trap — measured, and why it did not bite here

The audit was warned that mirror-target *spelling* changes the resolved
`PackageReference.Kind`: a bare path yields `localSourceControl`, `file:///…` for
the same directory yields `remoteSourceControl`. **So `Kind` alone cannot be
trusted to mean locality, and this audit read `location` for every pin, not
`Kind`.**

Measured property of this map: **all 1,256 entries use bare paths; zero use
`file://`.** Because the spelling is uniform, `Kind` *happens* to be a faithful
proxy here — but that is a property of the map, not of `Kind`. **A single entry
rewritten as `file://` would silently flip that identity to
`remoteSourceControl` with no other change**, and any audit keyed on `Kind` would
misreport it. Recorded so the next audit does not inherit a conclusion that is
only accidentally true.

### One dual-spelling case — intended, not a collision

`apple/swift-argument-parser` appears **twice**, as
`…/swift-argument-parser` and `…/swift-argument-parser.git`, both mapping to the
**same** directory. That is two spellings of one identity resolving to one
target — deliberate coverage of the `.git` suffix, which SwiftPM canonicalises.
**Correct behaviour, not a collision.** Flagged only because it is the shape a
real collision would superficially resemble: the distinguishing test is whether
the two spellings point at the *same* target (fine) or *different* ones (a
collision). Outside the Apple Crypto graph in any case.

## 5. Orphan finding — the shallow mirror is unreferenced

`swiftlang/swift-crypto` (the depth-1 clone whose truncated tag list produced
G0-3's "4.3.0 is current" false answer) is referenced by **zero mirror entries**
— control: `swiftlang/swift-argument-parser` *is* a mirror target and returns 2.

**So nothing resolves through it. It is an orphan checkout**, which explains both
its staleness (HEAD 2025-07-23) and its shallowness: no resolution path keeps it
current, because no resolution path uses it.

This is good news for identity — an unreferenced checkout cannot cause a
resolution collision — but it sharpens the G0-3 recommendation: **the mirror is
not merely stale, it is unused, so a lane consulting it is consulting nothing
that participates in resolution.** Deepening it would fix the false answers;
removing it would fix the temptation. Recommending the latter unless something
outside SwiftPM reads it.

Note also the directory/identity mismatch already recorded in G0-3: a directory
named `swiftlang/…` holding a mirror of `apple/…`. Harmless while unreferenced;
worth correcting because a lane reasoning from directory layout attributes it to
the wrong organisation.

## 6. Instrument reachability — per question

The audit was asked to report where the instrument could not reach the question.

| Question | Instrument | Reached? |
|---|---|---|
| identities/versions/kinds in the resolved graph | resolved-state file | ✅ yes |
| local == remote identity | `gh api repos/…` | ✅ yes |
| is X mirrored | mirrors.json, **verified control** | ✅ yes |
| does a competing Institute `swift-asn1` exist | `gh api`, 404 × 3 | ✅ yes |
| ancestry shape | `gh api .fork/.parent` | ✅ yes — no forks to shape |
| **upstream version history** | **local shallow mirror** | ❌ **NO — depth 1; see G0-3.** Answered against upstream instead |

### Method note — my first control was itself unverified

The mirror probe initially returned zero for `crypto`/`asn1`, and the control I
chose to validate it (`rfc-5280`) **also returned zero**. That could have meant a
broken probe. It did not: `rfc-5280` simply is not mirrored either — **I had
picked a control I assumed was present without checking.**

Re-running with a control proven present by direct inspection of the map's own
sample (`swift-argument-parser`, 2 entries) confirmed the probe works and the
zero for `crypto`/`asn1` is a **true negative**.

**The lesson is one level up from "positive-control your probes": a control is
only a control if its expected result is independently established.** An assumed
control that fails is indistinguishable from a broken instrument, and an assumed
control that passes proves nothing at all. This is the same failure class as the
degenerate `--since` control recorded in the RFC 9110/9112 inventory §1.1 — there
the control could not fail; here it could not succeed.
