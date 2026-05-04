# Cardinal Trivial-Self Revert Plan

<!--
---
version: 1.0.0
last_updated: 2026-05-04
status: RECOMMENDATION
---
-->

## Context

Between 2026-05-03 and 2026-05-04, a Cardinal.\`Protocol\` unification cascade
landed across ~16 swift-primitives packages, with 30+ commits. The cascade
was authored to resolve a recurring bare-vs-Carrier overload split pattern
that had appeared in six packages independently after Tagged's `46ded75`
cascade-drop made `Tagged<Tag, Cardinal>.Underlying == Cardinal` (immediate
wrap) instead of `== UInt` (recursive cascade).

The cascade's design endpoint:

- Cardinal/Ordinal/Vector collapsed from trivial-self Carrier
  (`Underlying == Self`) to non-trivial Carrier of `UInt`/`Int`
  (`Underlying == UInt|Int`), with `_storage: UInt|Int` as
  `@usableFromInline let` storage and the `underlying` accessor returning
  the raw machine word.
- A new `Cardinal.\`Protocol\`` sibling protocol (mirror of the existing
  `Ordinal.\`Protocol\``) introduced as the unifier — both bare `Cardinal`
  and `Tagged<Tag, Cardinal>` conform, providing a single domain-axis
  constraint that consumer-side generic operators target instead of the
  bare-vs-Carrier split.
- Downstream packages migrated their `Carrier.\`Protocol\`<Cardinal>`
  constraints to `Cardinal.\`Protocol\``.

The principal's stated direction (2026-05-04, after the cascade had landed):

> "we DON'T want the cascade, but we DO want to align Tagged with
> carrier-primitives. Ideally we'd also NOT want \*.\`Protocol\` protocols,
> but use carrier-primitives".

The cascade's design endpoint — coexisting `Carrier` + per-domain `.Protocol`
— is not the desired one. The principal's goal is to make
`Carrier<Cardinal>` itself the universal unifier. Under trivial-self for
the primitive types, both bare `Cardinal` and `Tagged<Tag, Cardinal>` (under
Tagged's unchanged immediate-wrap) report `Underlying == Cardinal`, and
`Carrier<Cardinal>` matches both — eliminating the need for
`Cardinal.\`Protocol\``.

This plan is a per-repo revert sequence to surgically restore that
trivial-self semantics on Cardinal/Ordinal/Vector while preserving (a)
the Tagged immediate-wrap (`46ded75`), (b) the rename work
(`rawValue` → `underlying` at the Carrier-protocol level, `RawValue` →
`Underlying`, `__unchecked: ()` → `_unchecked:`), and (c) all parallel
CI/metadata/Phase-7a-revalidation commits.

The prior cascade memo at
[`swift-institute/Research/cardinal-protocol-unification-memo.md`](./cardinal-protocol-unification-memo.md)
(DECISION — Option C, 2026-05-04) IS SUPERSEDED BY THIS PLAN. The Option C
decision documented there is reversed. The memo's analysis of the recurring
split pattern remains accurate; the resolution diverges.

## Question

How do we surgically revert the Cardinal.\`Protocol\` cascade across ~23
repos while preserving (a) the Tagged `46ded75` immediate-wrap, (b) the
Carrier-protocol-level `rawValue` → `underlying` rename, and (c) parallel
CI/metadata commits?

Sub-questions:

1. The three mixed commits (`ac7f308` cardinal, `8e83f7f` ordinal,
   `24a9286` vector) bundle rename + trivial-self collapse in a single
   commit. What partial-revert mechanism extracts the rename portion and
   reverts only the collapse portion?
2. Several consumer-side cascade-recovery commits (cyclic's `d3afe09`,
   sequence's `2083160`, finite's `c8e6b3b`) are themselves reversals of
   pre-cascade workarounds. Under post-revert (with Carrier<Cardinal>
   unifying both bare and Tagged forms), are these workarounds still
   needed?
3. Under trivial-self Cardinal, `cardinal.underlying: Cardinal` returns
   Self via the Carrier default extension. The pre-cascade machine-word
   access path was `cardinal.rawValue: UInt`. The principal's directive
   "the rename stays" was crafted assuming the cascade endpoint where
   `underlying: UInt` covered both purposes; under post-revert, the
   per-type machine-word accessor needs a name. What should it be?

## Analysis

### Architectural target state

After the revert, the type-level shape is:

```
Tagged<Tag, U>: Carrier.`Protocol` where Underlying == U  // 46ded75 immediate-wrap (UNCHANGED)

Cardinal: Carrier.`Protocol` where Underlying == Cardinal  // trivial-self (RESTORED)
Ordinal:  Carrier.`Protocol` where Underlying == Ordinal   // trivial-self (RESTORED)
Affine.Discrete.Vector: Carrier.`Protocol` where Underlying == Affine.Discrete.Vector  // trivial-self (RESTORED)

// Both bare Cardinal and Tagged<Tag, Cardinal> have Underlying == Cardinal:
//   - bare Cardinal:           Underlying == Cardinal (trivial-self)
//   - Tagged<Tag, Cardinal>:   Underlying == Cardinal (Tagged's 46ded75 immediate-wrap)
//
// Therefore `Carrier.`Protocol`<Cardinal>` matches both — universal unifier.
// No `Cardinal.`Protocol`` sibling needed.
```

`Ordinal.\`Protocol\`` (the older sibling that predates this cascade — added
by `operator-ergonomics-and-carrier-migration.md` RECOMMENDATION 2026-04-26)
remains, because its reason to exist is the `associatedtype Count`
machinery that Carrier cannot host. Its `+`/`+=` typed-advance extension
reverts from `where Count: Cardinal.\`Protocol\`` (cascade form) back to
the pre-cascade upper bound `where Count: Carrier<Cardinal>` (which under
post-revert covers both bare-Cardinal and Tagged-of-Cardinal Count types).
The principal's "ideally we'd also NOT want \*.\`Protocol\` protocols"
hint is captured under Open Questions for a separate cycle.

### Per-repo classification table

Each commit since the Cardinal.\`Protocol\` cascade started (2026-05-03)
classified per the legend:

| Code | Meaning |
|------|---------|
| KEEP | Commit preserved; no revert needed |
| REVERT | Commit reverted in full |
| PARTIAL | Mixed commit; rename-portion KEEP, collapse-portion REVERT |
| KEEP+EDIT | Commit preserved with a small text edit (DocC referring to a removed type) |

#### Tagged + Carrier (no behavioural changes)

| Repo | Commit | Title | Disposition |
|------|--------|-------|-------------|
| swift-tagged-primitives | `96f2a76` | Rename rawValue → underlying; align with Carrier.\`Protocol\` (breaking) | KEEP |
| swift-tagged-primitives | `73020e6` | Tagged: revert init(_unchecked:) from package to public | KEEP |
| swift-tagged-primitives | `46ded75` | Tagged: drop cascade in Carrier conformance — unconditional + immediate | KEEP (load-bearing for the post-revert design) |
| swift-tagged-primitives | `9b1986c` | ci: pin reusable workflows to @main during active CI/CD development | KEEP |
| swift-tagged-primitives | `53da188` | ci: route through swift-primitives layer wrapper | KEEP |
| swift-carrier-primitives | `99ad46e` | Hoist Carrier to namespace + Carrying alias; rename storage to underlying | KEEP |
| swift-carrier-primitives | `2b57aac` | Carrier.md: update Tagged conformance shape to unconditional immediate | KEEP |
| swift-carrier-primitives | `26b7eba` | Revalidate Phase 7a: swift-carrier-primitives — 4 experiments against Swift 6.3.1 | KEEP |
| swift-carrier-primitives | `cde1075`, `719d3d0`, `764870a` | ci: link-check pilot iterations | KEEP |
| swift-carrier-primitives | `15b5f77`, `dc22f24` | ci: pin reusable workflows to @main during active CI/CD development | KEEP |
| swift-carrier-primitives | `be054ae` | ci: opt into embedded-check job (Foundation-free, embedded-buildable) | KEEP |
| swift-carrier-primitives | `b9e91db` | DocC: correct Carrier<Cardinal> vs Cardinal.\`Protocol\` distinction | **KEEP+EDIT** — DocC text refers to Cardinal.\`Protocol\`; needs a follow-up text edit to delete or re-frame the distinction since Cardinal.\`Protocol\` will no longer exist. The KEEP-portion is the surrounding Carrier explanation, which is independently valuable. |
| swift-carrier-primitives | `56e4367` | ci: route through swift-primitives layer wrapper | KEEP |

#### Domain primitives (mixed; partial reverts)

| Repo | Commit | Title | Disposition |
|------|--------|-------|-------------|
| swift-cardinal-primitives | `cb368b6` | Revalidate Phase 7a: swift-cardinal-primitives — 3 experiments against Swift 6.3.1 | KEEP |
| swift-cardinal-primitives | `ac7f308` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename); Cardinal own-field rawValue → underlying | **PARTIAL** — keep the Carrier-protocol rename adoption (`Carrier` → `Carrier.\`Protocol\``, `__unchecked: ()` → `_unchecked:` at Tagged/Tagged-call sites, all `.rawValue` consumer-side reads → `.underlying`). REVERT the Cardinal collapse: restore `Underlying == Cardinal` (trivial-self), restore the per-type machine-word field (see Open Question #1 for naming), restore the `Carrier where Underlying == Cardinal` constrained extensions for `cardinal`/`count` synonyms, `.zero`/`.one` constants, and `+`/`+=` arithmetic. |
| swift-cardinal-primitives | `208805d` | Add Cardinal.\`Protocol\` — domain-axis sibling to Carrier | **REVERT** — delete `Sources/Cardinal Primitives Core/Cardinal.Protocol.swift`. |
| swift-cardinal-primitives | `3ac3ba6` | ci: pin reusable workflows to @main during active CI/CD development | KEEP |
| swift-cardinal-primitives | `20886c5` | Migrate Cardinal SLI bridges to Cardinal.\`Protocol\` | **REVERT** — restore the `Carrier.\`Protocol\`<Cardinal>`-constrained SLI bridges. |
| swift-cardinal-primitives | `d544e2f` | ci: route through swift-primitives layer wrapper | KEEP |
| swift-ordinal-primitives | `ba7c05b` | Add Ordinal: Carrier; retain Ordinal.Protocol as sibling | KEEP — pre-cascade adoption of Carrier with `Ordinal.\`Protocol\`` retained as the sibling for the `Count` machinery. |
| swift-ordinal-primitives | `3790d1e` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP — pure upstream-rename adoption. |
| swift-ordinal-primitives | `8e83f7f` | Migrate Ordinal own-field rawValue → underlying via Carrier.\`Protocol\` | **PARTIAL** — keep the `Carrier` → `Carrier.\`Protocol\`` syntactic rename. REVERT the Ordinal trivial-self → non-trivial collapse (restore `Underlying == Ordinal`); REVERT the `Ordinal.\`Protocol\`.Count` upper-bound restructuring (restore `associatedtype Count: Carrier<Cardinal>`); REVERT the typed-advance operator splits in `Ordinal.Protocol.swift`, `Ordinal.Advance.swift`, `Ordinal.Distance.swift`, `Swift.Range+Ordinal.swift` (re-collapse the bare-vs-Carrier split pairs into single signatures using `where Count: Carrier<Cardinal>` — under post-revert, this single bound matches both bare-Cardinal and Tagged-of-Cardinal `Count` types). Restore the per-type machine-word field on `Ordinal` per Open Question #1. |
| swift-ordinal-primitives | `1eec318`, `b1a00c0` | metadata: add .github/metadata.yaml draft (#1); anomaly-fix | KEEP |
| swift-ordinal-primitives | `20f0bc0` | ci: migrate to centralized reusables | KEEP |
| swift-ordinal-primitives | `fef326a` | Migrate to Cardinal.\`Protocol\` unified constraint | **REVERT** — restore the bare-vs-Carrier split that this commit collapsed (across `Ordinal+Cardinal.swift`, `Ordinal.Protocol.swift`, `Ordinal.Advance.swift`, `Ordinal.Distance.swift`, `Atomic+Ordinal.swift`, `Swift.Range+Ordinal.swift`). Under post-revert (trivial-self Cardinal + Tagged-of-Cardinal both at `Underlying == Cardinal`), the split collapses naturally back to a single `where Count: Carrier<Cardinal>` signature — which is what the original Ordinal.Protocol typed-advance extension used pre-`8e83f7f`. The split was a workaround for the cascade-induced asymmetry; under post-revert it is unnecessary. The simpler outcome: restore the single Carrier<Cardinal>-constrained signature directly. |
| swift-ordinal-primitives | `4def264` | Remove @_disfavoredOverload from cross-type +/+=/% (Cardinal-side wins .one) | **REVERT** — restore `@_disfavoredOverload` on cross-type `+`/`+=`/`%`. |
| swift-ordinal-primitives | `6999310` | ci: route through swift-primitives layer wrapper | KEEP |
| swift-affine-primitives | `b00f5e2` | Migrate Affine.Discrete.Vector to Carrier; remove Vector.Protocol | KEEP — pre-cascade adoption of Carrier (trivial-self at the time); Vector.Protocol removal predates the cascade. |
| swift-affine-primitives | `aaebba1` | Follow rename swift-identity-primitives → swift-tagged-primitives | KEEP |
| swift-affine-primitives | `2098d67`, `a39ca24`, `5aa9ec9` | ci: migrate to centralized reusables | KEEP |
| swift-affine-primitives | `789bcac` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-affine-primitives | `24a9286` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename); Vector own-field rawValue → underlying | **PARTIAL** — keep the upstream-rename adoption (Tagged/Carrier syntactic). REVERT the Vector trivial-self → non-trivial collapse (restore `Underlying == Affine.Discrete.Vector` and the per-type machine-word field per Open Question #1); REVERT the bare-vs-Carrier-of-Vector split in `Affine.Discrete+Arithmetic.swift` (re-collapse to a single `Carrier<Vector>`-constrained signature, mirroring the Cardinal/Ordinal pattern under post-revert). |
| swift-affine-primitives | `51af2fa` | Migrate Cardinal-side splits to Cardinal.\`Protocol\` | **REVERT** — restore `C: Carrier.\`Protocol\`, C.Underlying == Cardinal` constraints in the Vector ↔ Cardinal cross-type comparison operators (`<`/`<=`/`>`/`>=`); REVERT body changes (`rhs.cardinal.underlying` → `rhs.underlying.underlying`); REVERT the `Cardinal_Primitives` import promotion from internal to public — under post-revert, `Cardinal.\`Protocol\`` is no longer needed in public signatures, so an internal import suffices for the in-body uses. |
| swift-affine-primitives | `e089eaf` | ci: pin reusable workflows to @main during active CI/CD development | KEEP |
| swift-affine-primitives | `3a2248c` | Add @_disfavoredOverload to bare-Vector +/+= (Cardinal-side wins .one) | **REVERT** — drop `@_disfavoredOverload` from bare-Vector `+`/`+=`. |
| swift-affine-primitives | `3f7046b` | ci: route through swift-primitives layer wrapper | KEEP |

#### Cardinal-\`Protocol\` consumers (cascade-migrated)

| Repo | Commit | Title | Disposition |
|------|--------|-------|-------------|
| swift-cyclic-primitives | `d3afe09` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | **PARTIAL** — keep the upstream-rename adoption. The same commit also added `Sources/Cyclic Primitives Core/Ordinal+Cardinal.Bare.swift` (per the parent memo) as a cascade-recovery workaround for the Tagged-cascade-drop-induced asymmetry. Under post-revert, the asymmetry is gone and the Bare file is unnecessary — and the subsequent commit `8f90085` already deleted it. Net effect: the file should NOT exist post-revert (= current state); the rename portion of d3afe09 stays. **No additional changes needed beyond confirming the file is absent.** |
| swift-cyclic-primitives | `8f90085` | Delete Ordinal+Cardinal.Bare.swift — Cardinal.\`Protocol\` unification | **KEEP** — under post-revert, the file is unnecessary; this commit's effect (file absent) is the correct outcome. (Originally classified as a cascade migration; semantically aligned with the post-revert target.) |
| swift-cyclic-primitives | `829006a` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-cyclic-primitives | `5dc7ccc` | ci: migrate to centralized reusables | KEEP |
| swift-cyclic-primitives | `d68e8c4`, `bbf41a9` | ci: pin reusable workflows; route through wrapper | KEEP |
| swift-sequence-primitives | `87e200e` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP |
| swift-sequence-primitives | `2083160` | Drop Cardinal(_:) lifts at Ordinal-vs-Cardinal comparisons | **KEEP** — under post-revert, the lifts are not needed because the upstream `Carrier<Cardinal>`-constrained operator covers both bare-Cardinal and Tagged-of-Cardinal RHS. Dropping the lifts is the correct outcome. (Originally a cascade migration; semantically aligned with post-revert.) |
| swift-sequence-primitives | `92e04fe` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-sequence-primitives | `ba7d3ea`, `a2b049a`, `260886a`, `f2611a5`, `f6c07db` | Phase 7a revalidation work | KEEP |
| swift-sequence-primitives | `999b2a1`, `747bb98` | ci: pin reusable workflows; route through wrapper | KEEP |
| swift-finite-primitives | `ed5353b` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP |
| swift-finite-primitives | `c8e6b3b` | Drop Cardinal(_:) lifts at Ordinal-vs-Cardinal comparisons | **KEEP** — same reasoning as sequence-primitives `2083160`. |
| swift-finite-primitives | `01c8231` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-finite-primitives | `6e37978`, `0b1bde6`, `8e8b0e3` | Phase 7a revalidation | KEEP |
| swift-finite-primitives | `9e00626`, `6bf5e49` | ci: pin reusable workflows; route through wrapper | KEEP |
| swift-finite-primitives | `17a41c8` | Migrate finite-primitives multi-arg unchecked inits to _unchecked label | KEEP — pure rename, unrelated to cascade. |
| swift-bit-vector-primitives | `3abf42e` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP — upstream-rename adoption included the v3-cycle `Index<UInt>.Count.one` disambig at five call sites. |
| swift-bit-vector-primitives | `8e26916` | Restore .one — Cardinal-side wins after operator disfavor rebalance | **REVERT** — under post-revert (the disfavor rebalances in ordinal `4def264` and affine `3a2248c` are reverted), the original `.one` ambiguity returns. Restore the explicit `Index<UInt>.Count.one` disambig at the affected call sites (= the state immediately after `3abf42e` and before `8e26916`). |
| swift-bit-vector-primitives | `58b2548` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-bit-vector-primitives | `92da3b1`, `a466638`, `78876a0` | Phase 7a revalidation | KEEP |
| swift-bit-vector-primitives | `3469973`, `e8f891d` | ci: pin reusable workflows; route through wrapper | KEEP |
| swift-binary-primitives | `e23655c` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP |
| swift-binary-primitives | `999a2c9` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename); own-field rawValue → underlying on Binary.Count/Mask/Pattern | KEEP — Binary.Count/Mask/Pattern were not previously trivial-self Carrier; this commit added Carrier conformance with `Underlying == Int`/`Scalar` (forward progress, NOT a trivial-self collapse). The `rawValue → underlying` rename here is a pure cosmetic accessor rename. **Not in revert scope.** |
| swift-binary-primitives | `4598b09` | Migrate Tagged shift operators to Cardinal.\`Protocol\` | **REVERT** — restore the prior `Carrier<Cardinal>`-constrained shift operators. |
| swift-binary-primitives | `714c577` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-binary-primitives | `a9249da` | ci: migrate to centralized reusables | KEEP |
| swift-binary-primitives | `44974e9`, `febe6c1` | ci: pin reusable workflows; route through wrapper | KEEP |
| swift-bit-primitives | `b69b617` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP |
| swift-bit-primitives | `72b14f5` | Migrate FixedWidthInteger shift operators to Cardinal.\`Protocol\` | **REVERT** — restore the prior `Carrier<Cardinal>`-constrained shift operators (the immediate predecessor commit `7c70ebe` "Migrate FixedWidthInteger+Cardinal shifts to Carrier<Cardinal>" is the pre-cascade target state). |
| swift-bit-primitives | `5301d05` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-bit-primitives | `f1c32fe` | ci: migrate to centralized reusables | KEEP |
| swift-bit-primitives | `2b9618a`, `bec9ee2` | ci: pin reusable workflows; route through wrapper | KEEP |
| swift-bit-primitives | `dd4f3b8` | Migrate bit-primitives Finite.Enumerable inits to _unchecked label | KEEP — pure rename, unrelated to cascade. |
| swift-memory-primitives | `2dd4990` | Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename) | KEEP |
| swift-memory-primitives | `c629f07` | Migrate Memory to Cardinal.\`Protocol\` | **REVERT** — restore the prior `Carrier<Cardinal>`-constrained sites (the immediate predecessor commit `9ed2a84` "Migrate Memory.Shift and Memory.Alignment.Align to Carrier<Cardinal>" is the pre-cascade target state). |
| swift-memory-primitives | `c07a84c` | metadata: add .github/metadata.yaml draft (#1) | KEEP |
| swift-memory-primitives | `aadc031` | Sync Phase 7a SUPERSEDED status into _index.json for swift-memory-primitives | KEEP |
| swift-memory-primitives | `da55e2b`, `7e8991e` | ci: pin reusable workflows; route through wrapper | KEEP |

#### swift-io discovery cascade repos (no cascade work; no changes)

The following 11 repos saw pure rename + `_unchecked:` migrations only —
no Cardinal.\`Protocol\` adoption, no trivial-self collapse, no
cascade-recovery splits. All commits since the cascade started are
**KEEP**.

| Repo | Latest cascade-window commit |
|------|------------------------------|
| swift-text-primitives | `8c93c5b` — text-primitives → Tagged.underlying + _unchecked: rename |
| swift-source-primitives | `e45f100` — source-primitives → Tagged.underlying + _unchecked: rename |
| swift-collection-primitives | `b7cb828` + `ddb583d` (regression revert follow-up) |
| swift-cyclic-index-primitives | `c8c3c91` — cyclic-index-primitives → Tagged.underlying + _unchecked: rename |
| swift-handle-primitives | `4dc78f3` — handle-primitives → Tagged.underlying + _unchecked: rename |
| swift-input-primitives | `028ddc9` — input-primitives → Tagged.underlying + _unchecked: rename |
| swift-path-primitives | `3ca5357` — path-primitives → Tagged.underlying + defer view/content; restore take() (Tagged ~Copyable lifetime gap noted as deferred per the handoff brief, OUT OF SCOPE for this revert) |
| swift-time-primitives | `c124853` — time-primitives Tagged constraints + multi-arg unchecked inits |
| swift-buffer-primitives | `a71cdcc` — Buffer.Unbounded.resize bytesToCopy to .underlying.underlying. Note: the `.underlying.underlying` double-unwrap pattern reaches `UInt` through Tagged-of-Cardinal under the cascade endpoint; under post-revert, the same call site needs adjustment (`.underlying.<machine-word-accessor>`, see Open Question #1). One file edit, included as part of Phase 4 below. |
| swift-hash-table-primitives | `f51f5ee` — hash-table-primitives → _unchecked + collapse 2-arg Tagged inits |
| swift-dimension-primitives | `7dec9f9` + `ee15d87` — Tagged.underlying rename + Axis/Interval.Unit cosmetic accessor rename (NO Carrier conformance, per the commit message). |

### Mixed-commit partial-revert mechanism

The three mixed commits cannot be `git revert`ed in full without losing
the rename portion. Two mechanisms are available:

#### Mechanism A: hand-authored partial-revert commit (RECOMMENDED)

For each mixed commit, author a new commit that:
1. Restores the trivial-self `Carrier` conformance shape on the type
   (`extension X: Carrier.\`Protocol\` { typealias Underlying = X }` —
   note the namespace rename `Carrier` → `Carrier.\`Protocol\`` is
   PRESERVED from the rename-portion).
2. Restores the per-type machine-word accessor (per Open Question #1 —
   either as `public let rawValue: UInt` field or as a `var` accessor of
   the chosen name over `_storage`).
3. Restores the `Carrier where Underlying == X` (now
   `Carrier.\`Protocol\` where Underlying == X`) constrained extensions
   for `cardinal`/`count` synonyms (cardinal), `ordinal` (ordinal),
   `vector` (vector), and `.zero`/`.one`/arithmetic.
4. For ordinal specifically: restores `associatedtype Count: Carrier<Cardinal>`
   (now `Carrier.\`Protocol\`<Cardinal>`) on `Ordinal.\`Protocol\`` and
   re-collapses the typed-advance operator splits to single signatures.
5. Updates all in-package read sites: `_storage`-based local arithmetic
   in package-internal code stays as `_storage`; cross-package read sites
   that were migrated to `.underlying` (returning UInt under cascade) now
   need adjustment per Open Question #1.

This mechanism produces a clean forward commit history; the cascade
commits remain in git history as a record of what was tried. Recommended
for clarity and reversibility.

#### Mechanism B: git-revert + reapply

`git revert ac7f308` (and similarly for `8e83f7f`, `24a9286`) followed
by hand-application of the rename portion only. More mechanical but
produces noisier history (revert + cherry-pick + manual edits). Not
recommended.

### Per-repo revert sequence (bottom-up)

The revert sequence is ordered such that each repo builds against the
previously-reverted dependencies. Within each phase, repos are
independent and can be reverted in parallel.

#### Phase 0 — Pre-flight enumeration and baseline

**Enumeration command** (per [HANDOFF-021]):

```bash
# Enumerate all current Cardinal.`Protocol` usage across the workspace
grep -rln "Cardinal\.\`Protocol\`" /Users/coen/Developer/swift-primitives/swift-*-primitives/Sources \
  | sort
```

Re-run this command at the start of each phase. The set should monotonically
shrink as phases land. Final post-revert count: zero (modulo the carrier
DocC `b9e91db` text-edit cleanup).

**Baseline build verification**: `swift build --build-tests` per repo at
HEAD. All 23 repos green at start (currently verified by the cascade-finish
state).

#### Phase 1 — Tagged + Carrier (no source changes; one DocC edit only)

Repos: `swift-tagged-primitives`, `swift-carrier-primitives`.

- swift-tagged-primitives: no changes.
- swift-carrier-primitives: text-only edit on the DocC content from
  `b9e91db` to remove or re-frame the `Cardinal.\`Protocol\`` reference,
  since the type will no longer exist post-revert. Single-file edit.

#### Phase 2 — Cardinal/Ordinal/Affine partial reverts

Sequencing: cardinal first (Ordinal+Affine depend on Cardinal); then
ordinal and affine in parallel.

##### 2a. swift-cardinal-primitives

Apply per Mechanism A:

1. Partial-revert of `ac7f308`: restore trivial-self Carrier of Cardinal,
   restore per-type machine-word field per Open Question #1, restore
   `Carrier.\`Protocol\` where Underlying == Cardinal` constrained
   extensions (cardinal/count synonyms; .zero/.one; +/+=).
2. Delete `Sources/Cardinal Primitives Core/Cardinal.Protocol.swift` (revert of `208805d`).
3. Revert `20886c5` SLI bridges: restore `Carrier.\`Protocol\`<Cardinal>`-constrained
   bridge signatures.
4. Verify: `cd /Users/coen/Developer/swift-primitives/swift-cardinal-primitives && swift build && swift test`.

Estimated diff: ~150 lines net change (delete Cardinal.Protocol.swift
~150 lines; net partial-revert across Cardinal+Carrier.swift, Cardinal.swift
roughly cancels with the rename delta).

##### 2b. swift-ordinal-primitives

Apply per Mechanism A:

1. Partial-revert of `8e83f7f`:
   - Restore trivial-self Carrier of Ordinal in `Ordinal+Carrier.swift`.
   - Restore per-type machine-word field on `Ordinal` per Open Question #1.
   - Restore `associatedtype Count: Carrier.\`Protocol\`<Cardinal>` upper
     bound on `Ordinal.\`Protocol\``.
   - Re-collapse typed-advance operator splits to single signatures using
     `where Count: Carrier.\`Protocol\`<Cardinal>` (or alternatively the
     pre-`8e83f7f` shape with no `where` clause, since the upper bound
     on `Count` is restored). Affected files: `Ordinal.Protocol.swift`,
     `Ordinal.Advance.swift`, `Ordinal.Distance.swift`,
     `Swift.Range+Ordinal.swift`.
   - Restore `Property where Tag == Ordinal.Distance` and
     `Property where Tag == Ordinal.Advance` to single signatures.
   - In-package read sites: `_storage`-based local arithmetic stays
     `_storage`; the public surface for cross-package consumers reads
     through the per-type accessor per Open Question #1.
2. Revert `fef326a` (Cardinal.\`Protocol\` unified constraint migration):
   restore the bare-vs-Carrier split — but under post-revert the upper
   bound of `Count` covers both, so the split itself is unnecessary; the
   single `where Count: Carrier.\`Protocol\`<Cardinal>` extension covers
   both cases. (The "split" only existed because of the cascade-induced
   asymmetry that this revert eliminates.)
3. Revert `4def264` (Remove @_disfavoredOverload from cross-type +/+=/%):
   restore `@_disfavoredOverload` on cross-type comparison/arithmetic
   operators in `Ordinal+Cardinal.swift`.
4. Verify: `cd /Users/coen/Developer/swift-primitives/swift-ordinal-primitives && swift build && swift test`.

Estimated diff: ~200 lines net deletion (the cascade's split-into-pairs
adds ~100 lines that collapse back; the trivial-self restore is ~80 lines
of restored Carrier-constrained extension surface).

##### 2c. swift-affine-primitives

Apply per Mechanism A:

1. Partial-revert of `24a9286`: restore trivial-self Carrier of
   Affine.Discrete.Vector in `Affine.Discrete.Vector+Carrier.swift`,
   restore per-type machine-word field on `Affine.Discrete.Vector` per
   Open Question #1, restore the `Carrier where Underlying == Vector`
   constrained extensions for `vector` synonym, `.zero`/`.one`,
   `+`/`-`/`+=`/`-=`.
2. Revert `51af2fa` (Cardinal-side splits → Cardinal.\`Protocol\`):
   restore `C: Carrier.\`Protocol\`, C.Underlying == Cardinal` constraints
   in Vector ↔ Cardinal cross-type comparison operators in
   `Affine.Discrete+Arithmetic.swift`. Demote `Cardinal_Primitives`
   import from public back to internal.
3. Revert `3a2248c` (Add @_disfavoredOverload to bare-Vector +/+=):
   drop `@_disfavoredOverload` from bare-Vector arithmetic.
4. Verify: `cd /Users/coen/Developer/swift-primitives/swift-affine-primitives && swift build && swift test`.

Estimated diff: ~120 lines net change.

#### Phase 3 — Cardinal-\`Protocol\` consumers

Sequencing: parallel after Phase 2 lands.

##### 3a. swift-cyclic-primitives

No changes. Current state aligns with the post-revert target (the cascade
deleted the `Ordinal+Cardinal.Bare.swift` workaround — under post-revert
that file is correctly absent).

Verify: `cd /Users/coen/Developer/swift-primitives/swift-cyclic-primitives && swift build && swift test`.

##### 3b. swift-sequence-primitives

No changes. The dropped `Cardinal(_:)` lifts (commit `2083160`) are
correctly absent under post-revert because the upstream
`Carrier<Cardinal>`-constrained operator covers both bare-Cardinal and
Tagged-of-Cardinal RHS.

Verify: `cd /Users/coen/Developer/swift-primitives/swift-sequence-primitives && swift build && swift test`.

##### 3c. swift-finite-primitives

No changes (same reasoning as sequence-primitives).

Verify: `cd /Users/coen/Developer/swift-primitives/swift-finite-primitives && swift build && swift test`.

##### 3d. swift-bit-vector-primitives

Revert `8e26916` ("Restore .one"). Under post-revert with disfavor
rebalances reverted, the original `.one` ambiguity returns; restore the
explicit `Index<UInt>.Count.one` disambig at the five call sites.

Verify: `cd /Users/coen/Developer/swift-primitives/swift-bit-vector-primitives && swift build && swift test`.

##### 3e. swift-binary-primitives

Revert `4598b09` ("Migrate Tagged shift operators to Cardinal.\`Protocol\`").
Restore the prior `Carrier<Cardinal>`-constrained shift operators.
The immediately preceding `b0b6931` "Migrate Tagged+Bitwise from
Cardinal.Protocol to Carrier<Cardinal>" is forward progress (NOT in
revert scope); it represents a previous, unrelated migration AWAY from
an older pre-2026-04-26 Cardinal.Protocol that was already removed.

Verify: `cd /Users/coen/Developer/swift-primitives/swift-binary-primitives && swift build && swift test`.

##### 3f. swift-bit-primitives

Revert `72b14f5` ("Migrate FixedWidthInteger shift operators to
Cardinal.\`Protocol\`"). The pre-cascade target state is captured by
`7c70ebe` "Migrate FixedWidthInteger+Cardinal shifts to Carrier<Cardinal>".

Verify: `cd /Users/coen/Developer/swift-primitives/swift-bit-primitives && swift build && swift test`.

##### 3g. swift-memory-primitives

Revert `c629f07` ("Migrate Memory to Cardinal.\`Protocol\`"). The
pre-cascade target state is captured by `9ed2a84` "Migrate Memory.Shift
and Memory.Alignment.Align to Carrier<Cardinal>".

Verify: `cd /Users/coen/Developer/swift-primitives/swift-memory-primitives && swift build && swift test`.

#### Phase 4 — swift-io discovery cascade repos (one targeted fix)

For `swift-buffer-primitives`, the `a71cdcc` commit migrated `Buffer.Unbounded.resize`
`bytesToCopy` reads from a previous form to `.underlying.underlying`
double-unwrap (Tagged-of-Cardinal → UInt under the cascade's `underlying: UInt`
endpoint). Under post-revert, `.underlying` on Tagged-of-Cardinal returns
Cardinal (not UInt); the `.underlying.<machine-word-accessor>` chain
needs adjustment per Open Question #1's resolved name.

Single-file edit: `Sources/Buffer Primitives Core/Buffer.Unbounded.swift`
(or wherever `resize` lives — verify path before editing).

Verify: `cd /Users/coen/Developer/swift-primitives/swift-buffer-primitives && swift build && swift test`.

#### Phase 5 — Workspace-wide verification (per [HANDOFF-035])

End-of-cascade gate: ecosystem-wide `swift build --build-tests` across
every transitive consumer of Cardinal/Ordinal/Vector. Per
[HANDOFF-035], per-sub-repo isolated builds are insufficient evidence
of completion for cross-package cascades.

Repos to verify (the 23 from this plan PLUS any consumers in swift-standards
and swift-foundations layers that depend on these primitives):

```bash
# Workspace-wide grep — should return zero hits
grep -rln "Cardinal\.\`Protocol\`" \
  /Users/coen/Developer/swift-primitives/ \
  /Users/coen/Developer/swift-standards/ \
  /Users/coen/Developer/swift-foundations/ \
  /Users/coen/Developer/swift-institute/ 2>/dev/null
```

Per-repo `swift build --build-tests` across the full transitive consumer
set. Acceptance criteria: all green; grep returns zero hits.

### Estimated diff size

| Phase | Repos touched | Approx. lines changed (net) |
|-------|---------------|------------------------------|
| Phase 1 | 2 | ~10 (text-only DocC edit) |
| Phase 2 | 3 | ~470 net change (cardinal ~150 + ordinal ~200 + affine ~120) |
| Phase 3 | 7 | ~50 (small revert commits per repo) |
| Phase 4 | 1 | ~5 (one-file accessor adjustment) |
| **Total** | **13** | **~535 lines** |

The remaining 10 repos (Tagged + 8 swift-io discovery + cyclic/sequence/
finite where current state is the target) require build-verification
only.

## Outcome

**Status**: RECOMMENDATION (execution pending principal authorization).

The plan restores trivial-self-Carrier semantics on Cardinal/Ordinal/
Affine.Discrete.Vector while preserving:

- Tagged's `46ded75` immediate-wrap (the load-bearing dependency of the
  post-revert design — without it, neither bare-Cardinal nor
  Tagged-of-Cardinal can reach a unified shape).
- The Carrier-protocol-level rename `raw → underlying`,
  `RawValue → Underlying`, `__unchecked: ()` → `_unchecked:`.
- All `ci:`, `metadata:`, Phase 7a revalidation, and unrelated work
  commits.

The post-revert state achieves the principal's stated goal:
`Carrier<Cardinal>` (and parallels `Carrier<Ordinal>`,
`Carrier<Affine.Discrete.Vector>`) become the universal unifier, matching
both bare and Tagged-wrapped forms under a single constraint. The
`Cardinal.\`Protocol\`` sibling protocol is removed entirely; no
`*.\`Protocol\`` sibling needs to be introduced for the unification role.

`Ordinal.\`Protocol\`` (which predates this cascade — added per
[`operator-ergonomics-and-carrier-migration.md`](./operator-ergonomics-and-carrier-migration.md))
remains, because its `associatedtype Count` machinery cannot be hosted
on Carrier directly. The principal's "ideally we'd also NOT want
\*.\`Protocol\` protocols" hint applies to it as a separate question,
captured under Open Questions below.

### Bottom-up execution sequence

1. **Phase 1**: swift-carrier-primitives DocC text edit (1 commit).
2. **Phase 2a**: swift-cardinal-primitives partial-revert (3 commits:
   trivial-self restore, Cardinal.Protocol.swift deletion, SLI bridges).
3. **Phase 2b/2c**: swift-ordinal-primitives + swift-affine-primitives
   partial-reverts in parallel (3 commits each).
4. **Phase 3**: 4 small consumer reverts (bit-vector, binary, bit, memory)
   in parallel, after Phase 2 lands.
5. **Phase 4**: swift-buffer-primitives single-file accessor adjustment.
6. **Phase 5**: workspace-wide grep + ecosystem-wide
   `swift build --build-tests` gate per [HANDOFF-035].

### Open Questions

#### Open Question #1 — Per-type machine-word accessor name

Under trivial-self Cardinal/Ordinal/Vector, the Carrier-derived
`underlying` accessor returns `Self` (Cardinal/Ordinal/Vector). Cross-package
consumers that need the raw machine word (`UInt` for Cardinal/Ordinal,
`Int` for Vector) require a per-type accessor with a distinct name.

Options:

| Option | Name | Trade-off |
|--------|------|-----------|
| 1 | `rawValue: UInt\|Int` (restore pre-cascade name) | RECOMMENDED. Naming continuity with pre-cascade state. Matches Swift's `RawRepresentable` convention. The original Carrier-protocol-level rename `raw → underlying` (96f2a76, 99ad46e) operates on the protocol-derived accessor; the per-type field rename was tied to the trivial-self collapse and is reverted with it. Two accessors with clear roles: `cardinal.underlying: Cardinal` (Carrier-derived, returns Self), `cardinal.rawValue: UInt` (per-type field, returns the machine word). Cross-package read sites that the cascade had migrated to `.underlying` (returning UInt) revert to `.rawValue`. |
| 2 | `value: UInt\|Int` (new neutral name) | Avoids any partial-rename rollback. Conflicts with potential future use of `.value` for other purposes (e.g., cell-of-Property). |
| 3 | Public `_storage: UInt\|Int` (drop @usableFromInline) | Leaks implementation-detail naming convention (`_`-prefix typically signals package-private); not recommended. |
| 4 | Domain-specific names: `cardinal.count`, `ordinal.position`, `vector.displacement`, all `: UInt\|Int` | Most descriptive but requires three different names; cross-package consumers writing generic code over Carrier need to special-case per type. |

**Recommendation**: Option 1 (`rawValue: UInt|Int`). It is the cleanest path
to naming continuity AND to a structurally honest two-accessor pattern
under trivial-self.

Pending principal decision before Phase 2 begins (the answer changes the
diff content of Phase 2a/2b/2c and the content of the Phase 4 buffer fix).

#### Open Question #2 — `Ordinal.\`Protocol\`` longer-term disposition

The principal's stated direction includes "Ideally we'd also NOT want
\*.\`Protocol\` protocols, but use carrier-primitives". `Ordinal.\`Protocol\``
was added pre-cascade per `operator-ergonomics-and-carrier-migration.md`
specifically because Carrier cannot host the `associatedtype Count`
machinery that makes `slot + .one` infer cleanly at call sites
(per-conformer concrete `Count`).

Under post-revert, the `+`/`+=` operator hosting works without
Cardinal.\`Protocol\` because `Carrier<Cardinal>` covers both bare and
Tagged forms — but the `Count` associatedtype STILL cannot live on
Carrier. To remove `Ordinal.\`Protocol\`` entirely would require
restructuring the typed-advance operator hosting; the alternatives are:

- Move typed-advance to bare extensions on `Ordinal` and on
  `Tagged where Underlying == Ordinal` (loses the per-conformer `Count`
  concretization for nested wrappings — would only support depth-1).
- Push `Count` machinery into Carrier itself (significant change to
  Carrier's protocol surface).
- Accept `Ordinal.\`Protocol\`` as a permanent operator-ergonomics
  carve-out (the current shape).

OUT OF SCOPE for this revert plan; principal decision on direction
pending. Track as a separate cycle.

#### Open Question #3 — Affine.Discrete.Vector with no Vector.\`Protocol\` analog

The cascade explicitly deferred `Vector.\`Protocol\`` (per the prior memo
Option C). Vector currently has no sibling protocol. Under post-revert,
should the Vector arithmetic operators be hosted exclusively on
`Carrier where Underlying == Vector` (matching both bare-Vector and
Tagged-of-Vector under the post-revert design)? The
`Affine.Discrete+Arithmetic.swift` shape from `b00f5e2` (pre-cascade
Carrier adoption) is the natural target — verify it still works under
trivial-self with the rename adjustments.

This is a verification question rather than a design question; resolved
empirically during Phase 2c by running tests.

#### Open Question #4 — Tagged ~Copyable lifetime gap

Per the handoff brief: Tagged's `~Copyable` lifetime gap (path-primitives
`view`, `content` deferred) is OUT OF SCOPE for this revert plan but
its existence is noted. Resolution is independent of the
Cardinal.\`Protocol\` cascade.

### Risks

1. **Hidden cascade-recovery commits**. The classification table above
   identifies the visible cascade commits; hidden cascade-recovery work
   may exist in commits with rename-only titles (e.g., a "rename"
   commit that secretly restructured an operator under cascade pressure).
   Mitigation: Phase 2's `swift build && swift test` verification per
   repo will catch missed reverts; Phase 5's workspace-wide grep ensures
   nothing references `Cardinal.\`Protocol\`` post-revert.

2. **Mixed-commit boundary errors**. Mechanism A (hand-authored partial
   reverts) requires careful identification of rename-portion vs
   collapse-portion in each of `ac7f308`/`8e83f7f`/`24a9286`. Mitigation:
   the diff portions are well-separated in the original commits (the
   trivial-self collapse is structurally distinct from the rename
   adoption); a careful read of the original commit diffs against this
   plan's mechanism gives a clean partial-revert.

3. **Open Question #1 lock-in**. The recommendation is option 1
   (`rawValue: UInt|Int`); a different choice (option 2 `value` or
   option 4 domain-specific) changes the diff content of multiple
   phases. Resolve OQ #1 before starting Phase 2.

4. **Workspace-wide consumer reach**. The 23 repos enumerated here are
   the core; transitive consumers in swift-standards and swift-foundations
   may exist. Phase 5's workspace-wide grep covers these but execution
   may surface more sites than enumerated here. Mitigation: the bulk-grep
   command in Phase 5 is the source of truth.

5. **Tagged immediate-wrap dependency**. The post-revert design's
   correctness depends on Tagged's `46ded75` being preserved exactly.
   Any revert pressure on Tagged's immediate-wrap would re-introduce the
   asymmetry that the cascade was designed to address. Tagged's
   immediate-wrap is also load-bearing for `Property.View<Tag,
   Ownership.Inout<Base>>` (per the parent memo); the dependency is
   already structural and will not regress, but explicit non-regression
   verification is part of Phase 1 (no source change).

## References

### Empirical validation

- **`swift-tagged-primitives/Experiments/carrier-recursive-root-extension/`**
  (CONFIRMED, 2026-05-04) — design-validation experiment that tested
  Path A against the full alternative-design space (Paths E, H3, H4)
  empirically. Findings, in summary:
  - **Path A (trivial-self)** uniquely preserves all of: Carrier-based
    universal unifier (`some Carrier<Cardinal>` matches both bare and
    Tagged-wrapped), type-safe Cardinal-vs-Ordinal distinction,
    Property.View case, no new protocols, no per-domain
    `*.\`Protocol\``.
  - **Path E** (non-trivial Cardinal + depth-coupled constraint
    `where C.Underlying.Underlying == UInt`) and **H4** (sibling
    `Rooted` protocol with `Root` associatedtype) BOTH produce a
    Cardinal-vs-Ordinal type-safety leak — generic dispatch over
    "Cardinal-meaning" admits Ordinal-shaped values (and vice versa)
    because both domain types share a UInt bottom.
  - **H3** (recursive `Root` on Carrier itself) re-introduces the
    Property.View blocker by forcing `Tagged: Carrier` to be
    conditional on `Underlying: Carrier`.
  - The empirical result table (E2/E5 false positives, E6 sugar-syntax
    incompatibility) closes the design question: Path A is the only
    structurally-correct endpoint under the principal's stated
    constraints.

### Prior research

- [`cardinal-protocol-unification-memo.md`](./cardinal-protocol-unification-memo.md)
  (DECISION — Option C, 2026-05-04). **SUPERSEDED by this plan.** The
  memo's analysis of the recurring split pattern is accurate; the
  Option C resolution is reversed in favour of the trivial-self revert
  documented here.
- [`operator-ergonomics-and-carrier-migration.md`](./operator-ergonomics-and-carrier-migration.md)
  (RECOMMENDATION, 2026-04-26). Origin of `Ordinal.\`Protocol\``; the
  rationale for Count-as-associatedtype hosting remains valid post-revert.
- [`capability-lift-pattern.md`](./capability-lift-pattern.md) — referenced
  by both Cardinal.Protocol.swift and Ordinal.Protocol.swift for
  capability-lift framing; relevant background but not directly
  superseded.

### Skill IDs

- [RES-003] Document structure (this document follows the template).
- [RES-003a] Metadata requirements (version, last_updated, status).
- [RES-003c] Research index (this entry must be added to
  `swift-institute/Research/_index.json`).
- [RES-008] Research document lifecycle (the prior memo will be flagged
  SUPERSEDED upon principal authorization of this plan).
- [HANDOFF-021] Scope enumeration at write-time (Phase 0's grep command).
- [HANDOFF-029] Pre-fire precondition re-check (Phase 5's workspace-wide
  re-grep).
- [HANDOFF-035] Cascade-migration termination criteria (Phase 5's
  ecosystem-wide build gate).

### Commits cited (chronological)

#### Tagged-side baseline (KEEP)

- `46ded75` — Tagged: drop cascade in Carrier conformance — unconditional + immediate
- `73020e6` — Tagged: revert init(_unchecked:) from package to public
- `96f2a76` — Tagged: rename rawValue → underlying

#### Carrier-side baseline (KEEP, one DocC edit)

- `99ad46e` — Carrier: hoist to namespace + Carrying alias; rename raw → underlying
- `2b57aac` — Carrier.md: update Tagged conformance shape
- `b9e91db` — DocC: Carrier<Cardinal> vs Cardinal.\`Protocol\` distinction (KEEP+EDIT)

#### Cardinal cascade (PARTIAL or REVERT)

- `ac7f308` — Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename); Cardinal own-field rawValue → underlying (PARTIAL)
- `208805d` — Add Cardinal.\`Protocol\` — domain-axis sibling to Carrier (REVERT)
- `20886c5` — Migrate Cardinal SLI bridges to Cardinal.\`Protocol\` (REVERT)

#### Ordinal cascade (PARTIAL or REVERT)

- `8e83f7f` — Migrate Ordinal own-field rawValue → underlying via Carrier.\`Protocol\` (PARTIAL)
- `fef326a` — Migrate to Cardinal.\`Protocol\` unified constraint (REVERT)
- `4def264` — Remove @_disfavoredOverload from cross-type +/+=/% (REVERT)

#### Affine cascade (PARTIAL or REVERT)

- `24a9286` — Migrate to Tagged.underlying + Carrier.\`Protocol\` (upstream rename); Vector own-field rawValue → underlying (PARTIAL)
- `51af2fa` — Migrate Cardinal-side splits to Cardinal.\`Protocol\` (REVERT)
- `3a2248c` — Add @_disfavoredOverload to bare-Vector +/+= (REVERT)

#### Consumer cascade migrations

- swift-cyclic-primitives: `d3afe09` (PARTIAL → no net change), `8f90085` (KEEP)
- swift-sequence-primitives: `2083160` (KEEP — semantically aligned with post-revert)
- swift-finite-primitives: `c8e6b3b` (KEEP — same reasoning)
- swift-bit-vector-primitives: `8e26916` (REVERT)
- swift-binary-primitives: `4598b09` (REVERT)
- swift-bit-primitives: `72b14f5` (REVERT)
- swift-memory-primitives: `c629f07` (REVERT)

#### swift-io discovery cascade (KEEP, one accessor adjustment)

- swift-buffer-primitives: `a71cdcc` (KEEP, with one-file accessor
  adjustment in Phase 4 for the `.underlying.underlying` double-unwrap
  pattern).
- All other swift-io discovery cascade repos: KEEP (pure rename + `_unchecked:`).
