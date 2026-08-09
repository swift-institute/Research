# Resolved State Wire Shapes — `workspace-state.json`

Read-only catalogue of the shapes SwiftPM's resolved-state file actually takes
on this machine. **Design input only.** Nothing is modelled here and no
resolved-state inspection is implemented; this exists so that the shape is known
before anything is built against it, the same discipline that produced
`Fixtures/dump-package-wire-shapes.json` before `Package.Manifest.Evaluation`
was written.

This repository is public; machine-specific path prefixes are rendered as
`<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

Approved by the team lead as design input, explicitly not implementation.

## Method

```
find <developer-root> -maxdepth 4 -name workspace-state.json -path '*/.build/*'
```

**483 files, 483 parsed without error, 27,003 dependency records.** No sampling —
every record was read. Counts below are exact, not estimates.

Machine-specific caveat: these are the shapes present on ONE machine under ONE
mirror configuration. Absence here is not proof of absence in the format (see
§5).

## 1. Envelope

| Key | Occurrences |
|---|---|
| `version` | 483 — **uniformly `7`**, no other value |
| `object` | 483 |

Every dependency record carries exactly four keys, always present:
`packageRef`, `state`, `subpath`, `basedOn`.

`packageRef` likewise always carries exactly four: `identity`, `kind`,
`location`, `name`.

**Consequence:** no optionality to model at the envelope or record level. A
single schema version means no version-drift branch is needed today — but the
`version` field exists precisely because that can change, so it should be read
and rejected on mismatch rather than ignored.

## 2. The two discriminators are DIFFERENT, and they do not agree

`packageRef.kind` and `state.name` are separate discriminators that co-vary
without being redundant.

| `packageRef.kind` | Count |
|---|---|
| `localSourceControl` | 24,912 |
| `remoteSourceControl` | 1,808 |
| `fileSystem` | 283 |

| `state.name` | Count |
|---|---|
| `sourceControlCheckout` | 26,629 |
| `fileSystem` | 283 |
| `edited` | 91 |

**Only 4 of the 9 possible pairs occur:**

| `kind` | `state.name` | Count |
|---|---|---|
| `localSourceControl` | `sourceControlCheckout` | 24,821 |
| `remoteSourceControl` | `sourceControlCheckout` | 1,808 |
| `fileSystem` | `fileSystem` | 283 |
| **`localSourceControl`** | **`edited`** | **91** |

Both source-control kinds collapse to one state name, so **`state.name` cannot
recover `kind`, and `kind` cannot predict `state.name`.** Anything needing both
facts must read both fields. This is the same trap as [ADJ-002 §"third location
form"]: `kind` alone does not tell you what you want to know.

## 3. `state.name` fully determines the payload — cleanly

| `state.name` | has `path` | has `checkoutState` | Count |
|---|---|---|---|
| `sourceControlCheckout` | no | **yes** | 26,629 |
| `fileSystem` | **yes** | no | 283 |
| `edited` | **yes** | no | 91 |

Zero exceptions in 27,003 records. `path` and `checkoutState` are perfectly
disjoint and jointly exhaustive — a sum type, not a struct of optionals.

## 4. `checkoutState` is `revision` + exactly one of `branch` | `version`

| Shape | Count |
|---|---|
| `revision` + `branch` | 26,129 |
| `revision` + `version` | 500 |
| **both `branch` and `version`** | **0** |
| **neither** | **0** |

`revision` is present in all 26,629. The branch/version choice is a genuine
either-or, verified exhaustively rather than inferred from the counts summing.

**Consequence:** model as `revision` plus a two-case pin, NOT as two optionals.
Two optionals would make three unrepresentable states representable — the same
correction the principal required on `Package.Dependency.Evaluation.Source`.

## 5. `registry` never appears — and that is not proof it cannot

`dump-package` models three dependency kinds: `fileSystem`, `sourceControl`,
`registry`. `workspace-state.json` on this machine shows **no `registry` kind in
27,003 records**.

That is an artefact of this workspace (no registry dependencies are in use), not
evidence the format lacks it. A model that omits the case will fail on the first
registry dependency anyone adds. **Treat the absence as unsampled, not
impossible** — a zero from an unexercised path is not evidence of absence.

## 6. `edited` — the retired workflow is still in the state file

**91 records carry `state.name == "edited"`**, all with
`kind == localSourceControl`, all carrying `path` and — critically — **no
`checkoutState`, therefore no revision.**

Observed examples: `swift-parser-primitives`, `swift-affine-geometry-primitives`.

Two consequences:

1. **An edited dependency has no recorded revision.** Any comparison of
   "planned vs resolved vs materialized" must handle a resolved entry that
   simply cannot answer "at what revision?". This is not a gap to fill by
   inference — the fact is genuinely absent from the file.
2. The arc defers editable dependencies, and `swift package edit` is retired at
   the coordinator — but **the state format still carries the case, and 91 live
   records exist**. A reader that treats `edited` as impossible will crash on
   real state present on this machine today.

This is also the resolved-state counterpart to the inert `Packages/` symlinks
the fleet found: residue of the retired editable workflow, still load-bearing
for anything that reads resolved state.

## 7. Also observed

- `artifacts`: present but **empty in all 483 files** — unsampled, do not model
  from this evidence.
- `prebuilts`: **non-empty in 49 files** — a real, populated array this
  catalogue has not characterised. Worth a follow-up before anything claims to
  read resolved state completely.

## 8. What this implies for the next slice

1. Read and check `version`; reject an unexpected value rather than proceeding.
2. Model `state` as a sum over `sourceControlCheckout` / `fileSystem` /
   `edited`, with the payload attached per case — never as a struct of
   optionals.
3. Model `checkoutState` as `revision` + a two-case pin (`branch` | `version`).
4. Keep `kind` and `state.name` as independent facts; do not derive either.
5. Include `registry` even though unobserved, and treat `prebuilts` as
   uncharacterised rather than empty.
6. Accept that `edited` entries have no revision, and design the
   planned-vs-resolved comparison so that absence is representable rather than
   defaulted.
