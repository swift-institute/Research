# apple/swift-asn1 Two-Repo Heritage Split — Rehearsal Record (2026-07-23)

<!--
---
version: 1.0.0
last_updated: 2026-07-23
status: EVIDENCE
tier: 2
scope: swift-iso-8824 + swift-iso-8825 publication mechanics
---
-->

Rehearsal of the principal-ruled two-repo split (certificates-n5-decision-packet.md
§EXECUTION LOG item 3). Temp-clone only; no real repo mutated. Fork point verified:
`9f542610331815e29cc3821d3b6f488db8715517` = tag 1.6.0, 129 commits reachable.
Commit maps archived beside this file (commit-map-8824.txt: 40 retained/94 pruned,
filtered head 41343ec; commit-map-8825.txt: 45 retained/89 pruned, filtered head
5195023). Mechanism: `git clone --no-local` → branch at fork point →
`git filter-repo --force --path <list> --path-rename 'Sources/SwiftASN1/Basic ASN1
Types/:Sources/ISO 882x/' --path-rename 'Sources/SwiftASN1/:Sources/ISO 882x/'
--path-rename 'Tests/SwiftASN1Tests/:Tests/ISO 882x Tests/'` (specific prefix first),
per the GitHub types→core precedent.

## Path partition (authoritative for the real run)

**swift-iso-8824 (X.680 notation)**: ASN1Identifier.swift (pure); Errors.swift
(straddler→8824: shared error currency, 8825 imports 8824); the Basic ASN1 Types
value types — ASN1BitString, ASN1Integer, ASN1Null, ASN1OctetString, ASN1Strings,
ObjectIdentifier, GeneralizedTime, UTCTime (straddlers→8824; their
DER/BERImplicitlyTaggable conformance BODIES move to 8825 as retroactive extensions
at reshape); TimeUtilities.swift (value-law; wire halves migrate with conformances);
tests ASN1StringTests, GeneralizedTimeTests, UTCTimeTests.

**swift-iso-8825 (X.690 BER/CER/DER; depends on 8824)**: DER.swift, BER.swift (pure);
ASN1.swift (straddler→8825 — TLV node tree is X.690 §8 wire shape; DECISIVE: DER.swift
was created at 28d0e07 as a copy of ASN1.swift, so DER's pre-split heritage lives in
ASN1.swift history and ASN1.swift MUST be in 8825's path list for --follow);
ASN1Boolean.swift, ArraySliceBigint.swift, ASN1Any.swift (conformance/serialized-bytes
only); ASN1Tests.swift + Test Helper Types/ (5 files); HISTORICAL paths
Sources/SwiftASN1/{ECDSASignature,PKCS8PrivateKey,SEC1PrivateKey,SubjectPublicKeyInfo}.swift
(helpers moved sources→tests at e30f8d2 R093 — old paths required for heritage).

**Both**: LICENSE.txt, NOTICE.txt ("The SwiftASN1 Project", 2022), CONTRIBUTORS.txt.
**Excluded** (per the record): PEMDocument.swift (the ONLY Foundation importer),
Docs.docc/, Benchmarks/, CMake, .github/, dev/, Package.swift, README/meta dotfiles.

Heritage probes all PASS: `git log --follow` reaches upstream file-creation images
for ObjectIdentifier/ASN1Strings/UTCTimeTests (8824) and DER (via the ASN1 copy-split),
BER, moved ECDSASignature (8825).

## Mechanism controls the real run MUST apply

1. **Fork-point commit is PRUNED by both filters** (9f54261 touched only .github) —
   the [HERITAGE-002] parent-pointer cannot hold literally; the publication commit's
   parent is the filtered head and its MESSAGE must name fork-point 9f54261 (already
   mandated by the execution-log ruling). Record this as the sanctioned shape for
   filtered-split heritage.
2. **Ref/tag leakage**: filter-repo rewrites ALL refs (post-1.6.0 main + 26 upstream
   tags leak into the filtered clone). Real run: clone `--branch 1.6.0` or pass
   `--refs <branch>`; fetch into Institute repos `--no-tags`, reviewed branch only.
3. **filter-repo does not follow renames**: the DER copy-split (28d0e07) and the
   helpers move (e30f8d2) are covered only via explicit old paths; any path-list edit
   re-runs the provenance probe (`git log --follow --name-status --diff-filter=ACR`).
4. Archive `.git/filter-repo/commit-map` before cleanup; filter strips `origin`;
   never force-push rewritten refs; import = fetch + `--allow-unrelated-histories
   --no-ff` merge, tree reviewed pre-merge.
5. ~35 shared-file-only commits (LICENSE/NOTICE/CONTRIBUTORS) appear in BOTH maps —
   intentional overlap, note in the reconciliation record.

## Publication-reshape inventory (per repo; inventory, not design)

Modules ISO_8824 / ISO_8825 (products "ISO 8824"/"ISO 8825"); 8825 manifest depends
on swift-iso-8824; new Package.swift per repo. Compound ASN1* identifiers → Nest.Name.
Conformance split per the partition. Foundation: nothing to strip (isolated to the
excluded PEMDocument). 92 [UInt8]/ArraySlice<UInt8> surface occurrences → Byte
discipline at the boundary. Untyped ASN1Error → typed throws (error-code set assigned
per partition). XCTest (4 files) → swift-testing. Upstream tags are not the Institute
release line ([HERITAGE-004]).
