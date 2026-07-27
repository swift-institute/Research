# Decision packet — who owns the name and address model for the certificates fork

**Stamp:** 2026-07-24 · **Status:** DECISION PACKET — no code changed, nothing landed.
**Routing:** submitted to the team lead. Escalation upward is the lead's.
**Scope:** the consolidated #34 row — (a)'s remaining wire types, `GeneralName` adoption,
(b) the §4.2.1.10 matching law, and the address-family question.
**Contributors:** certificates lane (this packet), `swift-rfc-5280` lane (name model, its
own rationale), layering-review lane (ecosystem measurement). Each claim below names its
source and whether I re-verified it myself.

---

## 0. Headline

**The address question is a non-event and should be struck from the row.** It rested on a
finding of mine that was **wrong**: there is no competing IP family. Two lanes measured it
independently and I re-verified the decisive file myself.

**What genuinely remains is narrower than the row implies:** whether the fork adopts
`RFC_5280.GeneralName`, and whether it adopts the §4.2.1.10 matching law. Those are
separable, and only the second carries behavioural risk.

**And a gap surfaced that nobody was tracking** — §4.2.1.10 IP-range law has no ecosystem
owner (§3.3).

---

## 1. The address model — SETTLED, and it was never a choice

### 1.1 My finding was wrong

I reported that consuming `swift-rfc-5280` would put "two IPv4 and two IPv6 owners" in the
fork's graph, and the deferral rested on it. **It is false.**

```
swift-standards/swift-ipv4-standard   59 LOC, one file
    @_exported import RFC_791
    public typealias IPv4 = RFC_791.IPv4          ← package dep: swift-rfc-791

swift-standards/swift-ipv6-standard   68 LOC, one file
    @_exported import RFC_4007 / RFC_4291 / RFC_5952
    public typealias IPv6 = RFC_4291.IPv6         ← package deps: rfc-4291, rfc-5952, rfc-4007
```

`IPv4.Address` **is** `RFC_791.IPv4.Address` — the same nominal type, not a parallel model.
I read `IPv4Standard.swift` in full myself; the layering lane read both independently.

**How the error happened, since it is the reusable part:** I inferred a second address model
from two package *names* and a manifest edge, without opening either package. Same shape as
reading remote identity off a configured URL — a true observation about the wrong object.
One `wc -l` would have caught it.

### 1.2 Corroboration (layering lane, measured)

Ownership sweep across the census: **1 592 modules, exactly 2 claimed by more than one
package** (`GitHub_OAuth_Types`, `Server_Vapor`). **IP is not among them.** Owners are
`swift-rfc-791` (IPv4) and `swift-rfc-4291` (IPv6) — the packages the fork already uses
under [IMPL-060].

### 1.3 In-degree, two instruments

The layering lane bounded my `@_exported` caveat rather than leaving it rhetorical: direct
manifest edges capture **94.25 %** of real cross-package coupling; transitive closure
**99.54 %**.

| Package | Layer | Manifest in-deg | By-import in-deg | LOC |
|---|---|---|---|---|
| `swift-rfc-791` | L2 | 6 | 6 | 3 378 |
| `swift-rfc-4291` | L2 | 5 | **6** | 969 |
| `swift-ipv4-standard` | L2 | 3 | 3 | 59 |
| `swift-ipv6-standard` | L2 | 3 | 3 | 68 |

The spec packages hold the substance (3 378 and 969 LOC); the convergers hold 59 and 68.
The `rfc-4291` discrepancy (5 declared, 6 importing) is a **live instance of the
under-reporting hazard**: `swift-whatwg-url` binds `RFC_4291` through the closure without
naming the package.

⚠️ **Instrument warning, from my own failure tonight:** my first in-degree sweep used
`xargs -a`, which is **GNU-only and fails silently on macOS**, returning zero for every
input. It also produced the "zero consumers" figure I gave for G0-5 — re-measured since,
genuinely zero, but accidentally so. **Any in-degree number produced with `xargs -a` is
void, not low.**

### 1.4 One real asymmetry

**IPv4 is a pure alias; IPv6 is a superset bundle.** `ipv6-standard` re-exports three
packages, adding RFC 4007 scoped addresses and RFC 5952 canonical text on top of the
rfc-4291 address type. Depending on the converger is therefore *not* capability-neutral for
IPv6 — though the address type is rfc-4291's either way.

### 1.5 Recommendation

**Depend on `swift-rfc-791` / `swift-rfc-4291`.** They are the owners, the fork is already
there, [IMPL-060] already points there, and consuming rfc-5280 is harmless because its
`-standard` deps resolve to the same types. If canonical text or scoped addresses are ever
needed, take **rfc-5952 / rfc-4007 directly** rather than the bundle, so the dependency
stays honest about what it needs.

**UPDATE 2026-07-24 — rfc-5280 has already done this; no offer is outstanding.** Re-read
its manifest myself rather than quoting a report, since it moved once tonight:

```
package deps:     iso-8824 · iso-8825 · domain-standard · swift-rfc-791 · swift-rfc-4291 · byte-primitives
RFC 5280 target:  ISO 8824 · ISO 8825 · Domain Standard · RFC 791 · RFC 4291 · Byte Primitives
-standard IP imports in its sources: 0
```
Its own manifest comment states the reason: *"The IP address owners are the RFC packages
themselves; the `-standard` umbrellas over them are re-export shims, so depending on them
would be an edge to a re-export rather than to the owner."* **It reached the same owner
conclusion independently and wrote it down.**

**Consequence: consuming rfc-5280 now adds exactly two packages — `swift-rfc-5280` and
`swift-domain-standard`.** Everything else it needs (iso-8824/8825, byte-primitives,
rfc-791, rfc-4291) is **already in the fork's graph**. The dependency objection that
deferred the two clean wire swaps is now not merely weaker but close to nil.

---

## 2. The name model — `GeneralName`

### 2.1 Shapes are near-identical

Both model the same nine-case CHOICE. Verified on both sides:

| Case | Fork | RFC_5280 |
|---|---|---|
| `otherName` | `OtherName` | `RFC_5280.OtherName` |
| `rfc822Name`, `dnsName`, `uniformResourceIdentifier` | `String` | `ISO_8824.IA5String` |
| `x400Address` | `ISO_8825.Any` — **opaque** | `ISO_8825.Any` — **opaque** |
| `directoryName` | `DistinguishedName` | `RFC_5280.Name` |
| `ediPartyName` | `ISO_8825.Any` | `RFC_5280.EDIPartyName` |
| `iPAddress` | `ISO_8824.OctetString` | `ISO_8824.OctetString` |
| `registeredID` | `ISO_8824.ObjectIdentifier` | `ISO_8824.ObjectIdentifier` |

**The `x400Address` capability loss the rfc-5280 lane flagged does not apply** — I checked;
the fork keeps it opaque too.

### 2.2 ★ NARROWED 2026-07-24 — the original claim here was wrong; see the correction below

Verified independently on both sides: no custom initialiser, only `init(derEncoded:)`; a
grep for case-folding, trimming, canonicalisation returns **nothing** in either.

**⚠️ CORRECTION (2026-07-24, after §3.1's `directoryName` measurement).** The paragraph
above reasoned about `GeneralName`'s *own* behaviour and stopped at its boundary. That was
the wrong boundary. **`GeneralName` carries other types, and a carried type's `==` can be
the matching law** — which is exactly what `directoryName` turned out to be
(`directoryNameMatchesConstraint` is literally `directoryName == constraint`).

**The corrected claim, which is what should be cited:**
> Adopting `GeneralName` imports no matching-law behaviour *of its own*, but it **does**
> import the equality semantics of every type it transitively carries.

At the time this packet was first written those semantics were **wrong**:
`RFC_5280.RelativeDistinguishedName` compared positionally where X.501 defines a SET, so
adoption would have imported a **fail-open** defect into `NameConstraintsPolicy`.

**That defect is now fixed** — rfc-5280 `5326216`, verified by me at that commit:
set-semantics `==`/`hash(into:)` compared as a **multiset** (so a malformed SET carrying a
duplicate is not silently equated with one that does not), stored order preserved so wire
fidelity is untouched, and documented in place. Their scope check found the **same defect in
`RFC_5280.Attribute.values`**, also a `SET OF`, which my report had not covered — one
instance of a class rather than the class.

**The argument that settled it was theirs and is stronger than the X.501 one I sent:**
`serializeSetOf` canonicalises SET OF ordering on the way out, so two values comparing
*unequal* serialised to **byte-identical DER**. Equality that disagrees with byte-identity
is wrong under any reading of the type — including the wire-faithful reading I had left open
as a defensible counter-position.

**So the safety statement is time-indexed, not absolute:** adopting the wire type is safe
**at `5326216` and after** — it was not safe on 2026-07-24 before it.

### 2.3 Migration cost

`GeneralName` reaches **6 files**: `GeneralName.swift`, `NameConstraints.swift`,
`SubjectAlternativeName.swift`, `AuthorityInformationAccess.swift`,
`AuthorityKeyIdentifier.swift`, `NameConstraintsPolicy.swift`.

Adoption is a **typed-representation** change, not a semantic one — `String` →
`ISO_8824.IA5String` at three cases, `DistinguishedName` → `RFC_5280.Name` at one. The last
is the real cost: `DistinguishedName` is a fork public type with its own consumers, so
adopting `RFC_5280.Name` propagates beyond these six files. **Not scoped here** — it wants
its own measurement before anyone commits.

Adopting `GeneralName` unblocks the three wire types deferred for coupling
(`AIAAccessDescription`, `AuthorityKeyIdentifierValue`, `NameConstraintsValue`/
`GeneralSubtrees`), since the coupling *was* `GeneralName`.

---

## 3. What remains genuinely open

### 3.1 `GeneralName` adoption — de-risked, still a real decision
No normalisation and no matching law travel with it, so it is safe in the sense that
mattered. The open cost is `directoryName`: `RFC_5280.Name` versus the fork's public
`DistinguishedName`. **Recommend: measure that propagation before ruling.**

### 3.2 The §4.2.1.10 matching law — unchanged in risk
Still the one place outcomes can change. The rfc-5280 lane states its matching **rejects
names outside RFC 1123 preferred syntax rather than matching them** — a deliberate
difference from the fork. Preconditions stand: **differential testing** over the
disagreement surface (trailing dots, empty constraints, case, IDNA, partial labels) and a
**joint ruling** rather than a decision from inside either tree.

### 3.3 ~~NEW GAP — §4.2.1.10 IP-range law has no owner~~ — **RETRACTED 2026-07-24**

**This finding was wrong and is withdrawn.** I recorded that §4.2.1.10 IP-range law "has no
owner to delegate to". It does: **RFC 5280 owns it, correctly.**

Re-verified by reading the file myself:
```swift
// RFC_5280.NameConstraints.IPAddress.swift
case v4(base: RFC_791.IPv4.Address, mask: RFC_791.IPv4.Address)
case v6(base: RFC_4291.IPv6.Address, mask: RFC_4291.IPv6.Address)
public func contains(_ address: RFC_791.IPv4.Address) -> Bool      // :78
public func contains(_ address: RFC_4291.IPv6.Address) -> Bool     // :86
public func contains(_ address: ArraySlice<UInt8>) -> Bool         // :101
```

**Why the original claim was wrong:** the symbol sweep it rested on covered the five
candidate *address* packages and not `swift-rfc-5280` itself. The sweep's zero was true of
its scope and false of the question. **A positive control proves an instrument fires; it
does not prove the search space was the right one** — that is the distinct lesson here, and
it is not the same as the `xargs -a` failure, where the instrument itself was dead.

**The accurate, narrower statement:** no *general-purpose* CIDR/prefix package exists
(`swift-rfc-4632`, `swift-rfc-6890`, `swift-rfc-4193` are absent — verified), **and RFC 5280
owns its own base+mask constraint form rather than delegating it.** That is correct under
the ownership principle: §4.2.1.10 *is* RFC 5280's semantics, so the matching law belongs to
it, not to an address package.

**Practical effect: this removes a cost from the row rather than adding one.** rfc-5280's
containment law already operates over `RFC_791.IPv4.Address` / `RFC_4291.IPv6.Address` — the
**same types the fork already parses into** under [IMPL-060]. If the fork ever consumes
rfc-5280's §4.2.1.10 matching, the address types are already shared; nothing converts.

---

## 4. Recommendation

1. **Strike the address question from the row.** Settled: rfc-791/rfc-4291 are the owners,
   the fork is already correct, and there is nothing to reconcile. **Do not narrow a fifth
   time over it** — there is no conflict.
2. **Rule the deferral on timing, not duplication.** Deferring #34 still holds on the
   argument made independently — the row's remaining value depends on decisions that are
   themselves deferred — but the duplication ground is void and should not be cited.
3. **Split the row.** `GeneralName` adoption (measure the `DistinguishedName` propagation
   first) and the matching law (differential testing + joint ruling) are different decisions
   with different risk; keeping them fused now costs more than it buys.
4. **Open RFC 4632 ownership as its own item.** Not certificates work, but the fork and
   rfc-5280 are both downstream of it.

**What I am *not* recommending:** landing the two clean wire swaps now. They remain
mechanically perfect and the dependency objection is now much weaker — but their value is
still contingent on `GeneralName`, and the timing argument for deferral survives the
correction intact.
