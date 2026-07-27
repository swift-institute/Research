# N5 swift-certificates — Acceptance artifacts (pre-execution checklist item 5)

**Stamp:** 2026-07-24 · **Status:** DRAFT for the team lead. Facts below were read from the
live tree and remotes at the stated commit; nothing is quoted from an earlier report.
**Routing:** submitted to the team lead; escalation upward is the lead's to make.

Satisfies checklist item 5 (`record:367-369`), recorded **OPEN for certificates** in
`n5-certificates-publication-gate-2026-07-24.md` §3 because the publication tree did not
yet exist. It now does, on the work branch — so the artifacts can be produced from
substance rather than intention. This does **not** assert that publication may proceed:
item 5 is one input, and B1/D3–D5 are separate gates.

---

## 1. Fork point

| | |
|---|---|
| Upstream | `apple/swift-certificates` |
| Fork point | **`24ccdeeeed4dfaae7955fcac9dbf5489ed4f1a25`** |
| Corresponds to | tag `1.18.0` ("Custom private key (#282)", 2026-02-10) |
| Reachable history | **312 commits** |
| Ancestry check | fork point is an ancestor of the work branch — `git merge-base --is-ancestor 24ccdee n5-green-checkpoint` → true |

The fork point survives literally as an ancestor: no filtering was performed on this
repository, so the [HERITAGE-002] parent-pointer holds without the message-names-SHA
workaround the ASN.1 split required.

## 2. Publication-tree source commit

| | |
|---|---|
| Source commit | **`308f1b0a01bc3d023b93395f1d448917e2b6b2b9`** |
| Branch | `n5-green-checkpoint` (work branch) |
| Durable at | `swift-foundations/swift-certificates-n5`, **PRIVATE**, branch-only |
| Gate at that commit | `package test` exit 0 — **133 tests in 45 suites passed** |

`publication` remains at raw `24ccdee` locally and was deliberately **not** pushed, per
the fork-point ruling (no raw upstream parked public in an Institute org). The adapted
tree lives on the work branch until the publication commit is authored.

## 3. `git log --first-parent` shape

Ten Institute commits atop the fork point; linear, no merges, parent chain intact:

```
308f1b0  Correct the now-stale swift-crypto dependency note
d95f8f5  (C) batch 3: main target is Crypto-free and Foundation-free — D3 discharged
54d5b14  (C) batch 2c: cover the witness before reshaping what sits behind it
f8395fe  (C) batch 2b: make the verify witness a required parameter
d2eb753  (C) batch 2a: establish the Certificate.Verify seam and inject it
2e40fc7  (C) batch 1: remove dead Digests, relocate SubjectKeyIdentifier hash init
35b855c  Increment 2 batch 3: freeze 5 identity fixtures, rewire ServerIdentityPolicy
7da9e4d  Increment 2 batch 2: restore PolicyBuilder tests on a frozen fixture
be01687  Increment 2 batch 1: restore DistinguishedName + NameConstraints essence tests
b7005cb  WIP: N5 swift-certificates fork — green library + increment-1 tests
         └─ parent: 24ccdee (fork point)
```

**Note on shape at publication.** [HERITAGE-002] calls for the publication tree to arrive
as **one** commit whose parent is the fork point. The ten above are the working history
that produced it and are **not** the intended published shape; the publication commit is
authored at the gate. Recorded explicitly so this list is not mistaken for the artifact
it documents.

## 4. Path mapping

| Upstream path | Institute target | Product |
|---|---|---|
| `Sources/X509/` | target `Certificates` | library `Certificates` |
| `Sources/_CertificateInternals/` | target `Certificate Internals` | — (internal) |
| `Tests/X509Tests/` | test target `Certificates Tests` | — |
| `Tests/CertificateInternalsTests/` | test target `Certificate Internals Tests` | — |

Directory paths are retained as upstream wrote them; only target/product **names** are
Institute-side. Keeping the paths stable is what preserves per-file followable history
across the fork point.

## 5. Deleted upstream surfaces

**301 paths** deleted relative to the fork point. 57 `.swift` files survive under
`Sources/`. By area:

| Area | Paths | Why |
|---|---|---|
| `Benchmarks/` (incl. Thresholds) | 174 | Not verifier essence; benchmarking is a separate package concern |
| `Sources/X509/` | 61 | Excluded surfaces: issuance/private keys, CSR, CMS, OCSP, builders, system-trust loading, PEM, RSA |
| `Tests/X509Tests/` | 44 | Tests of the above, plus the excluded-surface tests recorded in the deferred-tests ledger |
| `cmake/`, `.github/workflows/`, `dev/` | 8 | Upstream build/CI/meta, replaced by Institute equivalents |
| Repo meta (`README`, `CONTRIBUTING`, `CODE_OF_CONDUCT`, `SECURITY`) | 4 | Upstream project docs; Institute authors its own |
| `Sources/_CertificateInternals/`, `Tests/CertificateInternalsTests/` | 2 | Superseded files within retained targets |

The per-path list is the 295-path deletions manifest in this directory
(`deletions-manifest.md`), authored at staging; the count differs from 301 because later
batches removed further files (notably dead `Digests.swift`) — the manifest is the
staging record, the diff against `24ccdee` is authoritative.

**Deferral is recorded, not implied.** Excluded *tests* are itemised per case in
`deferred-tests-ledger.md`, each naming the surface it needs and the arc that
reactivates it. Deleted ≠ lost: git history retains all of it, and the ledger makes each
deferral auditable and reversible.

## 6. Attribution files

| File | At fork point | Retained | Content |
|---|---|---|---|
| `LICENSE.txt` | yes | **yes** | Apache 2.0, unmodified |
| `NOTICE.txt` | yes | **yes** | Names the SwiftCertificates Project and `github.com/apple/swift-certificates`, unmodified |

Every retained source file keeps its upstream Apache-2.0 header and the
"part of the SwiftCertificates open source project" attribution block.

**★ Correction to the rehearsal record.** `REHEARSAL.md:35` lists `CONTRIBUTORS.txt`
among the attribution files to retain. **That file does not exist upstream at
`24ccdee`** — verified by `git ls-tree -r --name-only 24ccdee`, which returns no match
anywhere in the tree. Its absence here is therefore correct and is **not** a missing
artifact; the rehearsal record is inaccurate on that one item and should be amended
rather than the tree "fixed" to match it.

## 7. Modification record

Substantive Institute changes to retained upstream files, each with its adjudication:

| Change | Nature | Ruling |
|---|---|---|
| SwiftASN1 → `ISO_8824`/`ISO_8825` | Dependency retarget onto Institute standards owners | two-repo ASN.1 cut (gate note §4-E1) |
| `CertificateError` → `Certificate.Error` nest | Typed-error taxonomy; payloads carry evidence | error-taxonomy design |
| `Foundation.Date` → `Instant` | Injected verification time; no system-clock read | Q4 time-surface ruling |
| Signature verification → injected `Certificate.Verify` | Model holds algorithm + raw bytes; cryptography leaves the target | witness-reshape design; **discharges D3** |
| Per-algorithm key-length checks at parse | Restores validation the backing flip would otherwise have silently removed | lead Ruling 1 |
| `inet_pton`/`Foundation.URL` → RFC 791/4291/3986 | Ecosystem reuse in place of platform C and Foundation | [IMPL-060] |
| XCTest → swift-testing | 445 cases converted; Institute suite shapes | testing conventions |

## 8. What this artifact does **not** establish

- **Not** publication authorisation. B1 (publication commit outstanding) and D3–D5 are
  separate gates; D5 requires per-action authorisation for each GitHub-side step.
- **Not** a clean-room claim. That artifact carries its own disclosed isolation caveat
  (gate note §5-B4).
- **Not** a pruning claim for `apple/swift-asn1`: it is **FETCHED** transitively via
  swift-crypto (`from: "1.2.0"`, floating to 1.7.1), never imported by Institute code.
  Recorded in `Package.swift` beside the dependency as well as here.
- **Not** final on test coverage: 253 tests across five suites remain deferred to the
  TestPKI-shim tier, itemised in the ledger.
