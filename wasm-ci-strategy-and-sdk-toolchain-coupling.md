# Wasm CI Strategy and SDK ↔ Toolchain Coupling

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
normative: false
provenance: HANDOFF-wasm-strategy-research.md (parent conversation, 2026-05-05)
---
-->

## Changelog

- **v1.0.0 (2026-05-05)**: Initial Tier 2 prior-art survey investigating Wasm CI strategy across `swiftlang/swift-syntax`, six Apple/swiftlang first-party packages, the swift.org Wasm SDK distribution model, and the Embedded/Wasi semantic distinction. Six sub-questions framed by parent handoff (`HANDOFF-wasm-strategy-research.md`). Extends `centralized-swift-ci-and-spine-gate.md` v1.3.0 §3.4.6 + §3.5.7 (cite-and-extend per [HANDOFF-013]).

## Context

### Trigger

Today's rollout of γ-3 (Embedded Wasm SDK advisory job in the swift-primitives layer wrapper, commit `8e3a76c`) surfaced two correctness wrinkles that the v1.1.0/v1.3.0 spec did not anticipate:

1. **SDK ↔ toolchain ABI tight coupling.** The 6.3.0 Wasm SDK (`swift-6.3-RELEASE_wasm.artifactbundle.tar.gz`) fails to import into the 6.3.1 compiler with `module compiled with Swift 6.3 cannot be imported by the Swift 6.3.1 compiler`. Fix was patch-version pin (commit `b5c632f` → `8e3a76c`). But this means the SDK URL + checksum and the `swift:6.3` Docker image (which currently rolls forward to 6.3.1) must be updated in lockstep on every patch release. Brittle.

2. **Three coexisting "Embedded" concepts** with opaque relationships:
   - The toolchain compiler flag `-enable-experimental-feature Embedded` (used by the existing nightly-Linux `embedded` job since well before Wasm CI started).
   - The artifact-bundle SDK ID `swift-X.Y.Z-RELEASE_wasm-embedded` (chosen via `--swift-sdk`).
   - The artifact-bundle SDK ID `swift-X.Y.Z-RELEASE_wasm` (the non-suffixed variant).

   The naming is opaque; the relationships are not stated in any user-facing swift.org doc.

### Prior research (carry-forward; cite-and-extend per [HANDOFF-013])

- `centralized-swift-ci-and-spine-gate.md` v1.3.0 §3.4.6 — converged γ-3 plan: "build with the Embedded Wasm SDK on stable Swift 6.3 first (per `swiftlang/swift-syntax` precedent), nightly only if SDK requires." Four-week classified soak with five-class taxonomy (A package-actionable / B toolchain / C SDK install / D workflow / E known-unsupported).
- `centralized-swift-ci-and-spine-gate.md` v1.3.0 §3.5.7 — implementation lesson: "the Wasm SDK and the container Swift toolchain MUST match exactly (down to the patch version)." Captured the 6.3.0/6.3.1 ABI mismatch as a class-B (toolchain) failure.
- `ci-cd-workflows` skill [CI-001]–[CI-004], [CI-020]–[CI-022] — three-tier reusable chain; layer wrappers carry layer-specific invariants; embedded buildability is the L1 invariant manifested in CI.

This doc focuses on what §3.4.6 / §3.5.7 do not yet address: the **SDK distribution model**, the **embedded/wasi semantic distinction**, the **patch-version coupling architecture**, and the **swift-foundation / swift-collections / swift-numerics precedent**.

### Empirical state (verified 2026-05-05)

| Fact | Source | Verified |
|------|--------|----------|
| swift.org `releases.json` API publishes Wasm SDK checksums for all 6.2.x (6.2 → 6.2.4) and both 6.3.x (6.3, 6.3.1) | `https://www.swift.org/api/v1/install/releases.json` direct fetch | 2026-05-05 |
| Bundle URL `https://download.swift.org/swift-6.3.1-release/wasm-sdk/swift-6.3.1-RELEASE/swift-6.3.1-RELEASE_wasm.artifactbundle.tar.gz` is HTTP 200 (72.6 MB) | `curl -sI` direct fetch | 2026-05-05 |
| 6.3.1 SDK checksum `bd47baa20771f366d8beed7970afaa30742b2210097afd15f85427226d8f4cf2` in `releases.json` matches the value hardcoded in swift-primitives layer wrapper line 119 | `releases.json` + `swift-primitives/.github/.github/workflows/swift-ci.yml:119` | 2026-05-05 |
| Bundle ships TWO SDK IDs: `swift-X.Y.Z-RELEASE_wasm` (full stdlib + WASI) and `swift-X.Y.Z-RELEASE_wasm-embedded` (Embedded Swift subset). BOTH target `wasm32-unknown-wasip1`. | bundle's `info.json` extracted via tar partial fetch | 2026-05-05 |
| The `_wasm-embedded` SDK's `embedded-toolset.json` automatically passes `-enable-experimental-feature Embedded -static-stdlib -wmo -D__EMBEDDED_SWIFT__` to swiftc | `embedded-toolset.json` extracted from bundle | 2026-05-05 |
| swift-syntax routes Wasm CI through `swiftlang/github-workflows/.github/workflows/swift_package_test.yml@0.0.9` with `enable_wasm_sdk_build: true`. Default matrix `["nightly-main", "nightly-6.3", "6.2"]` (i.e., stable AND nightly together). Hard-gated, no `continue-on-error`. | `swiftlang/swift-syntax/.github/workflows/pull_request.yml:17-22` | 2026-05-05 |
| 6 of 7 surveyed Apple/swiftlang packages have Wasm CI. 5 of 6 use the swiftlang/github-workflows reusable; swift-nio is the lone outlier (own `wasm_swift_sdk.yml`). | direct workflow file inspection | 2026-05-05 |
| Only swift-collections among surveyed Apple packages uses `enable_embedded_wasm_sdk_build: true`. The other 5 reusable users only set `enable_wasm_sdk_build: true` (WASI variant). | `apple/swift-collections/.github/workflows/pull_request.yml` | 2026-05-05 |
| The reusable's `install-and-build-with-sdk.sh` (857 lines) **resolves the SDK dynamically at runtime** from `https://www.swift.org/api/v1/install/releases.json` (releases) or `https://www.swift.org/api/v1/install/dev/<branch>/wasm-sdk.json` (nightlies); side-loads a matching toolchain into `~/.swift-toolchains` if the container's preinstalled `swift` differs from the SDK's required tag (lines 393–407, 641–648). | reusable script direct fetch | 2026-05-05 |
| swiftly does not yet know about Wasm SDKs (no Wasm references on `swift.org/install/macos/swiftly/`). | direct doc fetch | 2026-05-05 |
| Internal Swift compiler renames in March + April 2026: `WasmSwiftSDK` → `WASISwiftSDK`, `WasmStdlib` → `WASIStdlib`. Naming convention is converging on **WASI = full-stdlib variant**, **Embedded = subset variant**. | forums.swift.org/t/swift-for-wasm-march-2026-updates and april-2026-updates | 2026-05-05 |

## Question

The handoff frames six sub-questions:

1. What is the current Swift Wasm SDK distribution model? (where, cadence, guarantees)
2. Embedded vs Wasi vs other Wasm targets — what's the conceptual model and how does it align with swift-primitives' L1 invariant?
3. Should γ-3 use stable or nightly?
4. What's the right job structure (one job? two? three? other shape)?
5. What does swift-foundation / swift-collections / swift-numerics / others do?
6. Is the §3.4.6 five-class soak (A/B/C/D/E) the right tracking taxonomy, or does class C need an ABI sub-class?

## Analysis

### Q1. SDK distribution model

#### Where SDKs live

- **swift.org (canonical, since Swift 6.2 on 2025-09-15)**. Bundles at `download.swift.org/<version>-release/wasm-sdk/<TAG>/<TAG>_wasm.artifactbundle.tar.gz`. Metadata + checksums via the `releases.json` and `dev/<branch>/wasm-sdk.json` API endpoints.
- **swiftwasm/swift-sdk-index** (community, parallel). Active (last updated 2026-05-04) but **has gaps**: no entries for 6.0.x, 6.1, 6.2/6.2.1/6.2.2 (only 6.2.3 indexed), and **no entry for 6.3.1 as of investigation**. Points at `github.com/swiftwasm/swift/releases` rather than swift.org.
- **swiftwasm/swift GitHub releases** (legacy). Pre-6.2 home; still consumed by swiftwasm/swift-sdk-index.

#### Cadence and guarantees

- Empirical pattern on swift.org: **every patch in the 6.2/6.3 line has a published Wasm SDK** with checksum exposed via `releases.json`. 6.3 shipped 2026-03-24; 6.3.1 shipped 2026-04-16 (≈3 weeks). [Verified: 2026-05-05]
- **No published guarantee.** The wasm-getting-started article only soft-prescribes "make sure to install and use an exactly matching Swift SDK version" [Verified: 2026-05-05] — prescriptive but not contractual.
- **No documented cutover statement** from swiftwasm/swift to swift.org. The Swift 6.2 release blog (2025-09-15) is the de facto announcement; the community swiftwasm/swift-sdk-index continues in parallel.

#### Implication

CI strategies that hardcode an SDK URL (current state) carry a per-patch update burden. CI strategies that resolve dynamically from `releases.json` (the swiftlang/github-workflows reusable's pattern) **completely sidestep the patch-version-pin problem**.

### Q2. Embedded vs Wasi — the conceptual model

#### Three concepts disambiguated

| Concept | What it is | How it's selected |
|---------|------------|-------------------|
| `-enable-experimental-feature Embedded` | Toolchain compiler flag enabling the **Embedded Swift language subset** (eliminates the Swift runtime, restricts language features for microcontroller / freestanding targets). Vision doc target audience: bare-metal / microcontrollers. Does not mention Wasm. | `swift build -Xswiftc -enable-experimental-feature -Xswiftc Embedded` |
| `swift-X.Y.Z-RELEASE_wasm` SDK ID | The **WASI SDK**: full Swift stdlib + Swift Testing + WASI runtime. Target triple `wasm32-unknown-wasip1`. Article wording: "Supports all Swift features." | `--swift-sdk swift-X.Y.Z-RELEASE_wasm` |
| `swift-X.Y.Z-RELEASE_wasm-embedded` SDK ID | The **Embedded Swift SDK on Wasm**. Target triple **STILL `wasm32-unknown-wasip1`** (NOT bare-metal `wasm32-unknown-none`). The bundled `embedded-toolset.json` automatically injects `-enable-experimental-feature Embedded -static-stdlib -wmo -D__EMBEDDED_SWIFT__` into swiftc. Article wording: "subset of features allowed in the experimental Embedded Swift mode." Stated motivation: "Wasm binaries that are multiple orders of magnitude smaller" — 9.7 KB for "Hello, World!" | `--swift-sdk swift-X.Y.Z-RELEASE_wasm-embedded` |

#### Critical clarifications (verified empirically against the bundle's info.json, swift-sdk.json, embedded-swift-sdk.json, toolset.json, embedded-toolset.json)

1. **Selecting `_wasm-embedded` automatically passes `-enable-experimental-feature Embedded` to swiftc.** The two SDK IDs are NOT independent of the compiler flag — the embedded SDK ID *is* the compiler-flag-driven Embedded mode, packaged for cross-compilation.
2. **Both SDK IDs target `wasm32-unknown-wasip1`.** The hypothesis "WASI = full Wasm + WASI sysroot, embedded = bare-metal Wasm" is **empirically false** for the official swift.org 6.3.1 bundle. There is no `wasm32-unknown-none` SDK shipped.
3. **Both SDK IDs share the same `WASI.sdk` rootpath.** They differ in the bound toolset (compiler flags + linker invocations + macro defines), not in the platform headers/libraries.
4. **`wasm-embedded` is not a documented swift.org architectural term.** It's an SDK ID convention defined in the bundle's `info.json`. Wasm-getting-started refers to it descriptively ("the SDK with `-embedded` suffix").

#### L1 invariant alignment

swift-primitives' L1 invariant is "Foundation-independent + freestanding-buildable" — currently enforced via `-enable-experimental-feature Embedded` against the nightly Linux container.

| Variant | L1 alignment |
|---------|--------------|
| `_wasm-embedded` | **Closer fit.** Auto-enables the same `-enable-experimental-feature Embedded` flag the existing CI already uses. Selecting it against the Wasm target tests the same language-subset invariant against a different target triple. |
| `_wasm` (WASI) | **Does not test the L1 invariant.** Links full Swift stdlib including `swift_Concurrency`. Building L1 packages against `_wasm` would not exercise freestanding-buildability. |

Caveat (un-verified at write time): the embedded SDK still links `-lswift_Concurrency` per `embedded-toolset.json` line 23. Whether some L1 packages compile under "embedded on Linux" but fail under "embedded on Wasm-WASI" (or vice versa) is empirical and per-package — not answerable from documentation.

### Q3. Stable vs nightly

#### The v1.1.0 framing

> "build with the Embedded Wasm SDK on stable Swift 6.3 first (per `swiftlang/swift-syntax` precedent), nightly only if SDK requires."

#### Empirical reality (verified 2026-05-05)

The `swiftlang/swift-syntax` precedent the v1.1.0 spec cites is **partly inaccurate**:

- swift-syntax inherits the swiftlang/github-workflows reusable's default `wasm_sdk_versions` matrix.
- For `swift_package_test.yml@0.0.9` (swift-syntax's pin), the default is `["nightly-main", "nightly-6.3", "6.2"]` — **stable AND nightly together, three rows**.
- For `swift_package_test.yml@0.0.11` (swift-foundation, swift-argument-parser), the default is `["nightly-main", "nightly-6.3", "6.3"]`.
- All swift-syntax Wasm rows are **hard-gated** (no `continue-on-error`).

Apple Wasm CI summary table:

| Package | Reusable @version | `_wasm` | `_wasm-embedded` | Hard-gated |
|---------|-------------------|---------|------------------|------------|
| swift-foundation | @0.0.11 | ✓ (nightly-main only) | — | ✓ |
| swift-collections | @0.0.9 | ✓ | ✓ | ✓ |
| swift-numerics | @main | ✓ | — | ✓ |
| swift-system | @0.0.7 | ✓ (with version carve-outs) | — | ✓ |
| swift-async-algorithms | @main | ✓ | — | ✓ |
| swift-argument-parser | @0.0.11 | ✓ | — | ✓ |
| swift-nio | own `wasm_swift_sdk.yml` | ✓ (3-version matrix) | — | ✓ |
| **swift-syntax** | @0.0.9 | ✓ (`["nightly-main", "nightly-6.3", "6.2"]`) | — | ✓ |

Observations:

- **Five-of-six reusable adopters use only the WASI variant.** swift-collections is the lone embedded-variant adopter.
- **All seven (incl. swift-nio) hard-gate Wasm.** None advisory.
- **No package uses stable-only.** Every single one runs at least one nightly row.

#### Implication

The "stable, not nightly" framing of v1.1.0 §3.4.6 was based on an incomplete read of the swift-syntax precedent. The actual industry pattern is **stable + nightly together, hard-gated**, with SDK resolved dynamically. The Institute's choice to start advisory (γ-3 `continue-on-error: true`) is more conservative than any surveyed Apple package — appropriate for a 4-week soak window, but the destination state should be hard-gating.

### Q4. Job structure

#### Current state (commit `8e3a76c`)

```yaml
embedded:                   # nightly Linux, -enable-experimental-feature Embedded, no Wasm SDK
  container: swiftlang/swift:nightly-main-jammy
  continue-on-error: true   # nightly precedent (CI-021)
embedded-wasm-sdk:          # stable 6.3 (rolls forward), Embedded Wasm SDK pinned to 6.3.1
  container: swift:6.3
  continue-on-error: true   # γ-3 advisory; classified soak
matrix:
  uses: swift-institute/.github/.github/workflows/swift-ci.yml@main  # universal 4-job matrix
```

#### Three options for the destination shape

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **α — Status quo + dynamic resolution** | Keep two layer-wrapper jobs (`embedded`, `embedded-wasm-sdk`); replace hardcoded SDK URL with a curl-based lookup against `releases.json`. | Minimal architectural change. Solves the patch-version-pin problem. Preserves layer-wrapper ownership of L1 invariants per [CI-003]. | Requires a `python3 -c` or `jq` step inside the job. Does not benefit from upstream improvements to the swiftlang reusable. |
| **β — Adopt swiftlang reusable as a sub-job** | Add a third job `wasm-via-swiftlang-reusable` that calls `swiftlang/github-workflows/.github/workflows/swift_package_test.yml@<tag>` with `enable_embedded_wasm_sdk_build: true`. Keep `embedded` (Linux nightly) and remove `embedded-wasm-sdk` (replaced by the reusable). | Reuses Apple's battle-tested dynamic resolution + matching-toolchain logic. Auto-tracks future swiftlang improvements. Aligns with the broader Apple ecosystem. | Adds an external dependency to the L1 layer wrapper. The reusable's universal-matrix logic conflicts with our own three-tier chain (`[CI-001]`); we'd need to disable `enable_linux_checks`/`enable_macos_checks`/`enable_windows_checks` and only enable the embedded-wasm row, which is fragile if the reusable's input surface changes. |
| **γ — Full migration to swiftlang reusable** | Rewrite the universal reusable + layer wrapper to compose with `swiftlang/github-workflows`. | Strongest alignment with Apple. | Massive blast radius across 132 consumer repos. Conflicts with Institute-specific invariants ([CI-002] format/lint absorption, [CI-031] minimum caller, [CI-032] visibility gate, [CI-040] no-cache, [CI-058] enable-private-repos default-true). Not tractable as a single migration; would need its own multi-phase plan. |

#### Recommendation: Option α

Adopt dynamic SDK resolution while preserving the layer-wrapper architecture. The patch-version-pin lockstep problem is solved by replacing the hardcoded URL + checksum with a runtime resolution step that mirrors the swiftlang reusable's pattern but stays inside the layer wrapper.

Sketch:

```yaml
- name: Resolve and install Embedded Wasm SDK matching container Swift
  shell: bash
  run: |
    set -euo pipefail
    apt-get update -qq && apt-get install -qq -y curl python3
    SWIFT_VERSION="$(swift --version | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
    SDK_INFO=$(curl -sf "https://www.swift.org/api/v1/install/releases.json" | python3 -c "
    import sys, json
    data = json.load(sys.stdin)
    target = '$SWIFT_VERSION'
    rec = next((r for r in data if r.get('name') == target or r.get('tag') == f'swift-{target}-RELEASE'), None)
    if not rec: sys.exit('No release matching Swift ' + target)
    wasm = next((p for p in rec['platforms'] if p.get('platform') == 'wasm-sdk'), None)
    if not wasm: sys.exit('No Wasm SDK for Swift ' + target)
    print(rec['tag'] + '|' + wasm['checksum'])
    ")
    TAG="${SDK_INFO%%|*}"
    CHECKSUM="${SDK_INFO##*|}"
    SDK_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/wasm-sdk/${TAG}/${TAG}_wasm.artifactbundle.tar.gz"
    swift sdk install "$SDK_URL" --checksum "$CHECKSUM"
    echo "WASM_SDK_ID=${TAG}_wasm-embedded" >> "$GITHUB_ENV"

- name: Build (Embedded Wasm)
  run: swift build --swift-sdk "$WASM_SDK_ID"
```

Job count: keep at **two** (`embedded` + `embedded-wasm-sdk`).

- **Do NOT add** a `wasi-wasm-sdk` (non-embedded) job at L1. Rationale: the WASI variant links the full stdlib including `swift_Concurrency`, which does NOT test the L1 freestanding-buildability invariant. Adding it would test something L1 doesn't claim. (May be appropriate to add at L2 or L3 layer wrappers when those layers gain CI invariants — out of scope for L1.)
- The `embedded` Linux-nightly job and the `embedded-wasm-sdk` job test the **same** L1 invariant against two different platforms. Keeping both is defense-in-depth: a bug that surfaces only on the Wasm target (e.g., calling-convention quirk, ABI difference) is caught by the Wasm job; a bug that surfaces only on the development branch's bleeding-edge subset enforcement is caught by the Linux-nightly job.

### Q5. Apple package precedent

Already summarized in Q3 above. Synthesis points:

- **Wasm CI is now table stakes** for first-party Apple Swift packages (6 of 7 surveyed have it).
- **The dominant pattern is the swiftlang/github-workflows reusable**, not bespoke per-package implementations. swift-nio's `wasm_swift_sdk.yml` is a legacy holdout.
- **Default matrix is multi-row** (`["nightly-main", "nightly-6.3", "6.3"]` for current 0.0.11 reusable; `[..., "6.2"]` for older 0.0.9 pinned consumers). Both stable and nightly run side-by-side.
- **Hard-gated, not advisory.** No surveyed Apple package uses `continue-on-error: true` on the Wasm jobs.
- **WASI is the default; embedded is opt-in.** Only swift-collections among surveyed packages exercises both.
- **Dynamic SDK resolution architecturally solves the patch-version coupling.** The `install-and-build-with-sdk.sh` script side-loads a matching toolchain when the container's preinstalled `swift` differs from the SDK's required tag.

For Swift Institute, **starting advisory under γ-3 is more conservative than any surveyed Apple package** — but appropriate during the 4-week soak window. The destination state should match the industry default of hard-gating after the soak passes.

### Q6. Soak taxonomy (five-class A/B/C/D/E)

#### Current taxonomy from §3.4.6 / §3.4.6's Static-musl variant + γ-3b's E

```
A. package-actionable failure
B. toolchain failure
C. SDK installation failure
D. workflow failure
E. known unsupported target
```

The 6.3.0/6.3.1 ABI mismatch surfaced today was classified by §3.5.7 as **B (toolchain)**. The handoff asks whether class C needs an ABI sub-class.

#### Analysis

The failure mode "Wasm SDK was built against compiler X but is being imported by compiler Y" is structurally about **a mismatch between two installed components** (the SDK and the toolchain), not a defect in either component individually. In the current taxonomy:

- B (toolchain) implies the toolchain itself is the defect (e.g., a regression in the compiler or stdlib).
- C (SDK install) implies the SDK installation step itself failed (network, archive corruption, version not yet on the CDN).

The 6.3.0/6.3.1 mismatch doesn't fit cleanly in either: the toolchain works, the SDK installs, but they are incompatible. Both are "fine" individually; the *pairing* is broken.

#### Recommendation: extend C with a sub-class

Adopt:

```
A. package-actionable failure
B. toolchain failure                — defect in the toolchain itself
C. SDK installation/coupling failure
   C.1 SDK install network/availability (CDN 404, checksum mismatch, archive corruption)
   C.2 SDK ↔ toolchain ABI mismatch (versions diverge; both work alone)
D. workflow failure
E. known unsupported target
```

The C.1/C.2 sub-class makes the diagnostic precise and matches the failure's structural shape. C.2 is the failure class the 6.3.0/6.3.1 mismatch belongs to.

**If Option α (dynamic resolution) is adopted, C.2 becomes empty/non-applicable** — by construction, dynamic resolution always pairs the SDK with its matching toolchain. This is the right outcome: a closed sub-class is a sub-class whose failure mode has been architecturally eliminated, not merely tracked.

#### Re-classification of §3.5.7's incident

The §3.5.7 incident (6.3.0 SDK ↔ 6.3.1 compiler) was reported as class B (toolchain). With the C.2 sub-class added, it is more precisely class C.2 (SDK ↔ toolchain ABI mismatch). This is a pure documentation correction; no operational consequence.

## Recommendation Summary

1. **Adopt dynamic SDK resolution** in the layer-wrapper `embedded-wasm-sdk` job. Replace the hardcoded URL + checksum with a runtime lookup against `https://www.swift.org/api/v1/install/releases.json`. Sketch given in Q4 Option α above. Eliminates the patch-version-pin lockstep.
2. **Keep the two-job structure** (`embedded` Linux nightly + `embedded-wasm-sdk`). Do NOT add a wasi-variant job at L1 (does not test the L1 invariant).
3. **Continue using `_wasm-embedded` (the Embedded SDK variant) — not `_wasm`.** It is the closer fit for swift-primitives' L1 freestanding-buildability invariant.
4. **Keep stable Swift 6.3 as the toolchain pin** (`container: swift:6.3`). The patch-version coupling is the binding issue, not stable-vs-nightly. With dynamic resolution, the container can stay on `swift:6.3` (rolls forward) and the SDK auto-pairs.
5. **Maintain γ-3 advisory through the 4-week soak.** Destination state after flip: hard-gate (`continue-on-error: true` removed), matching the Apple ecosystem default.
6. **Extend the soak taxonomy** with C.1 (install failure) vs C.2 (ABI mismatch) sub-class. Re-classify §3.5.7's incident from B → C.2 in the centralized doc's next revision.
7. **Defer Option β (swiftlang reusable adoption)** to a future investigation. The architectural conflicts with our three-tier chain are non-trivial; Option α captures the operational benefit (dynamic resolution) at far lower blast radius.
8. **Subscription signal**: monitor `forums.swift.org/t/swift-for-wasm-<month>-<year>-updates` thread series for cadence/strategy changes. Max Desiatov's monthly digests are the de facto channel; there is no separate Swift Wasm working group attribution.

## Outcome

**Status**: RECOMMENDATION

The current γ-3 design (Option α "status quo + hardcoded URL") is **structurally correct in choice of variant and toolchain, but operationally brittle in the SDK pin**. The patch-version-pin lockstep is a known-resolvable problem with an empirically-validated solution path: dynamic SDK resolution from the swift.org API, which the swiftlang/github-workflows reusable already exercises across 6 first-party Apple packages.

The recommended next step is a **single-commit edit** to the `embedded-wasm-sdk` job in `swift-primitives/.github/.github/workflows/swift-ci.yml` replacing the hardcoded SDK URL + checksum with the dynamic resolution sketch in Q4. This:

- Resolves §3.5.7's "Wasm SDK ABI is pinned to a specific Swift version" lesson architecturally (not just operationally).
- Aligns the swift-primitives layer wrapper with the Apple ecosystem default for SDK acquisition (dynamic, not URL-pinned).
- Preserves the three-tier chain ([CI-001]) and the layer-wrapper ownership of L1 invariants ([CI-003]) — the dynamic resolution is a step inside the existing job, not a structural change.
- Eliminates the C.2 sub-class of the soak taxonomy by construction.

Implementation is a separate authorization gate (per `feedback_no_public_or_tag_without_explicit_yes.md` and `[CI-050]`). This research is Phase 1 (research-only) per the parent handoff's scope.

**Open follow-ups (deferred):**

- Empirical verification per L1 package: do any L1 packages compile under "embedded on Linux nightly" but fail under "embedded on Wasm-WASI" (or vice versa)? Would surface as class-A failures during the soak; classification gives the data.
- L2/L3 layer wrappers when those layers add CI invariants: the WASI (`_wasm`) variant might be appropriate at those layers (e.g., swift-foundations testing full stdlib + WASI). Out of scope for this doc.
- Swiftly Wasm SDK support: when swiftly adds Wasm SDK install commands (not present as of 2026-05-05), reconsider the resolution mechanism — `swiftly install-sdk wasm` would be cleaner than the curl + jq pattern. Track via the forums thread series.
- Embedded Swift compiler-flag stabilization: if `-enable-experimental-feature Embedded` graduates to non-experimental, the `_wasm-embedded` SDK ID's relationship to it may shift. Track via Swift Evolution.

## References

### Primary sources (verified 2026-05-05)

- **swift.org Wasm SDK distribution**:
  - [swift.org Wasm getting-started article](https://www.swift.org/documentation/articles/wasm-getting-started.html) — official user-facing doc; states "make sure to install and use an exactly matching Swift SDK version"; describes the two SDK IDs descriptively.
  - [swift.org install API releases endpoint](https://www.swift.org/api/v1/install/releases.json) — machine-readable release index with Wasm SDK checksums per release.
  - [swift.org install API dev/wasm-sdk endpoint](https://www.swift.org/api/v1/install/dev/main/wasm-sdk.json) — nightly snapshot index.
  - [swift.org Swift 6.2 release announcement (2025-09-15)](https://www.swift.org/blog/swift-6.2-released/) — de facto cutover from swiftwasm/swift to swift.org.

- **Bundle structure (extracted from `swift-6.3.1-RELEASE_wasm.artifactbundle.tar.gz`)**:
  - `info.json` — declares the two SDK IDs (`_wasm`, `_wasm-embedded`).
  - `swift-sdk.json` + `embedded-swift-sdk.json` — both target `wasm32-unknown-wasip1`, both use `WASI.sdk` rootpath.
  - `toolset.json` — standard variant (`-static-stdlib` only).
  - `embedded-toolset.json` — embedded variant (`-static-stdlib -enable-experimental-feature Embedded -wmo -D__EMBEDDED_SWIFT__`).

- **Apple package CI**:
  - [swiftlang/swift-syntax pull_request.yml](https://github.com/swiftlang/swift-syntax/blob/main/.github/workflows/pull_request.yml) — calls `swiftlang/github-workflows/.github/workflows/swift_package_test.yml@0.0.9` with `enable_wasm_sdk_build: true`.
  - [swiftlang/github-workflows swift_package_test.yml](https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/swift_package_test.yml) — the canonical reusable. Default Wasm matrix `["nightly-main", "nightly-6.3", "6.3"]` (in 0.0.11) or `["nightly-main", "nightly-6.3", "6.2"]` (in 0.0.9). Both `enable_wasm_sdk_build` and `enable_embedded_wasm_sdk_build` inputs.
  - [swiftlang/github-workflows install-and-build-with-sdk.sh](https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/scripts/install-and-build-with-sdk.sh) — 857-line resolution script; lines 393–407 (release tag resolution), 641–648 (toolchain side-loading on mismatch).
  - [apple/swift-collections pull_request.yml](https://github.com/apple/swift-collections/blob/main/.github/workflows/pull_request.yml) — sole surveyed package using `enable_embedded_wasm_sdk_build: true`.
  - [apple/swift-nio wasm_swift_sdk.yml](https://github.com/apple/swift-nio/blob/main/.github/workflows/wasm_swift_sdk.yml) — bespoke implementation predating the reusable.

- **Forums** (Swift Wasm monthly digests):
  - [Swift SDKs for WebAssembly now available on swift.org](https://forums.swift.org/t/swift-sdks-for-webassembly-now-available-on-swift-org/80405) (2025-06-11)
  - [Swift for Wasm March 2026 Updates](https://forums.swift.org/t/swift-for-wasm-march-2026-updates/85725) (2026-03-31) — internal rename `WasmSwiftSDK` → `WASISwiftSDK`.
  - [Swift for Wasm April 2026 Updates](https://forums.swift.org/t/swift-for-wasm-april-2026-updates/86371) (2026-04-30) — internal rename `WasmStdlib` → `WASIStdlib`; explicit "Foundation-free TAR library … with WebAssembly and Embedded Swift support" framing.

- **Swift Evolution / vision**:
  - [Embedded Swift vision document](https://github.com/swiftlang/swift-evolution/blob/main/visions/embedded-swift.md) — "subset of the Swift language that … eliminate[s] the need for the Swift runtime"; targets microcontrollers; does not mention Wasm.
  - [Embedded Swift restrictions diagnostic](https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/embedded-restrictions.md) — current language-subset constraints under the experimental flag.

### Internal cross-references

- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.3.0 §3.4.6 (γ-3 plan), §3.4.10 (graduation models), §3.5.7 (SDK ABI lesson).
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` [CI-001]–[CI-004] (three-tier chain), [CI-020]–[CI-022] (L1 invariants), [CI-030]–[CI-032] (caller pattern + visibility gate), [CI-040]–[CI-043] (caching), [CI-050]–[CI-052] (mass-rollout discipline).
- `swift-primitives/.github/.github/workflows/swift-ci.yml` (the layer wrapper hosting both `embedded` and `embedded-wasm-sdk` jobs).
- Memory: `feedback_no_public_or_tag_without_explicit_yes.md`, `feedback_toolchain_versions.md`, `feedback_latest_versions_only.md`.

### Methodology notes

- **Tier 2 prior-art survey** per `[RES-021]` (cross-package, not ecosystem-wide foundational).
- **Parallel subagent verification** per `[RES-020]` — 5 subagents dispatched against primary sources; each load-bearing claim tagged `[Verified: 2026-05-05]` per `[RES-023]`.
- **Empirical-claim verification** per `[RES-023]` — every claim about external state (URL availability, file contents, workflow YAML) verified against current source at write time, not synthesized from prior knowledge.
- **One small inconsistency between subagent reports** flagged in Q3: swift-syntax Wasm matrix default differs between the 0.0.9 reusable (`["nightly-main", "nightly-6.3", "6.2"]`) and the 0.0.11 reusable (`["nightly-main", "nightly-6.3", "6.3"]`). Resolution: swift-syntax pinned to 0.0.9 inherits the older default; swift-foundation/swift-argument-parser on 0.0.11 inherit the newer. Both are correct for their respective pin.
