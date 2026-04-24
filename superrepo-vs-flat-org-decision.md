# Superrepo vs Flat-Org Decision

| Field | Value |
|-------|-------|
| Tier | 2 |
| Scope | Ecosystem organization |
| Status | DECISION (flat-org adopted 2026-04-22) |
| Provenance | 2026-04-22-phase-i-completion-and-direction-reversals.md; 2026-04-23-superrepo-dismantle-and-phase-0-5-remediation.md |

## Context

`swift-primitives`, `swift-foundations`, and `swift-standards` were originally organized as submodule-aggregating superrepos: a parent git repo with each primitive as a `.gitmodules` entry. The Institute's own siblings (`swift-institute/`) adopted a flat-org pattern: a directory holding independent sibling repos, no parent git.

On 2026-04-22 the decision was made to dismantle the superrepo pattern for the three ecosystem monorepos and move to the flat-org pattern uniformly.

## Trade-offs

| Dimension | Superrepo | Flat-org |
|-----------|-----------|----------|
| Version lock across primitives | `.gitmodules` pins each primitive to an exact SHA — strong invariant | No built-in pin — relies on downstream version constraints |
| Clone-everything | One clone of the superrepo brings every primitive checked out | N clones required, one per primitive |
| Submodule-pointer discipline | Every cross-primitive commit requires a pointer bump commit in the superrepo | No pointer bumps — each primitive commits independently |
| Mental model | Two-level: superrepo + submodules | One-level: directory of siblings |
| Phased refactors | Two-stage push: submodule first, then superrepo pointer bump | One-stage push per primitive |
| CI workflow reuse | Callers in submodules reference central workflows in the superrepo — same as flat-org | Same as flat-org |

## Rationale for flat-org

The version-lock benefit does not pay for the operational cost in practice. Evidence:

1. Pointer-bump commits accumulate in the superrepo without carrying semantic information — they are mechanical translations of submodule state.
2. Phased refactors crossing multiple primitives double the push-ordering discipline: submodule → superrepo pointer bump → possibly another submodule → another pointer bump.
3. Agents performing ecosystem-wide work routinely forgot the second-stage push, producing a superrepo whose `.gitmodules` pointed at out-of-date submodule SHAs.
4. The mental-model simplification of flat-org materially improves agent performance on multi-repo scripts and ecosystem-wide tooling.

The version-lock invariant, where it matters, is recoverable via `.package(branch:)` discipline in `Package.swift` + explicit version pins at release-tag time.

## Historical Rationale for Superrepo Existence

Superrepos existed to:

- Support the original "one clone gets everything" developer ergonomic.
- Encode a version-alignment invariant across primitives that might otherwise drift.
- Provide a single-point GitHub entry for each layer.

As the ecosystem grew past ~50 primitives, the ergonomic inverted: one clone became 50+ MB of submodule state for consumers who only needed one primitive. The flat-org pattern restores per-package autonomy at the cost of discovery (consumers find packages via the `swift-institute.org` catalog, not via a superrepo README).

## References

- Reflections: 2026-04-22-phase-i-completion-and-direction-reversals.md, 2026-04-23-superrepo-dismantle-and-phase-0-5-remediation.md
- memory: `feedback_superrepo_terminology.md`
