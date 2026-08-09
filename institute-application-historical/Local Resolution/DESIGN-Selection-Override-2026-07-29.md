# Design — the local selection override

**Status:** implemented and landed (`2cbaa17`) · **Date:** 2026-07-29
**Durable record:** [swift-institute/Workspace#46](https://github.com/swift-institute/Workspace/issues/46)

**Objective (verbatim):** *"a developer can change which packages their local
Workspace checkout opens **without editing a tracked file** — so local choice and
committed policy stop sharing one artifact."*

**Filing note.** This sits in `Research/Local Resolution/` because that is where the
design corpus lives, not because it is part of the local-overlay objective. It is a
different problem — *which packages the workspace opens*, not *how their manifests
resolve each other* — and it can be moved without loss if the corpus is ever split by
topic. It is the direct successor to the fail-closed selection work, and everything
that work established is preserved rather than revisited.

**Vantage.** One macOS 27.0 machine, Swift 6.4 locally against a CI floor of 6.3.3.
No `swift-tools-version` was touched. Every claim below marked *measured* was taken
through the built `workspace` binary against a **fresh clone of the repository at
`2cbaa17` in a scratch directory** — never against the shared working tree, which
carries several sessions' uncommitted work.

---

## 1. What was actually wrong

`Selection.json` is a **committed policy input**, and that design is correct. It
bounds the public default checkout, the README tells contributors to edit its
`repositories` list, and it fails closed on missing, malformed, duplicate, empty,
unsupported-version and inventory-stale input. Nothing can generate it: the only
candidate source is `Workspace.json`, which yields the full 445-package roster that
the fail-closed design exists to prevent.

None of that changed. The defect was that the **same file was also the only way to
expand a local checkout**, so one artifact carried two jobs with opposite properties:

| | committed policy | local choice |
|---|---|---|
| audience | everyone who clones | one machine |
| lifetime | as long as the policy holds | as long as the developer is working on it |
| correct state in `git status` | clean | *should not appear at all* |

Sharing the artifact meant every local expansion looked like a pending policy change,
was one `git add .` from becoming one, and left the file perpetually dirty.

**This was not a hypothetical.** On 2026-07-28 it became a live coordination hazard:
multiple concurrent sessions had to be warned individually not to commit, checkout,
stash or clean the file, and one session edited it deliberately while another was
populating it. That was handled correctly — by snapshotting and diffing — but only
because the session happened to know. A mechanism that depends on every future
participant being told is not a mechanism.

At the time of writing, this machine's `Selection.json` carries **437** entries
against a committed **5**. The defect is the current state, not a risk.

## 2. The decision, and the one that mattered

`Selection.local.json` beside the committed document, gitignored, holding a **delta**:

```json
{ "version": 1, "add": ["owner/name"], "remove": ["owner/name"] }
```

Delta versus replacement was the only genuinely close call, and the deciding argument
is not the obvious one.

The obvious argument is that a delta keeps `Selection.json` the authority in the
literal sense — the effective selection is always *the committed list plus a named
departure*, so `doctor` has something specific to report. True, but a replacement
could be reported too.

The deciding argument is **staleness**. A replacement document freezes a machine at
the policy of the day it was written. A package added to `Selection.json` next month
would silently never arrive on that machine, and nothing would say so, because from
the tool's point of view the developer chose that set. That is the same class of
defect as the one being fixed — local state quietly diverging from committed policy —
reintroduced in a form that is *harder* to notice than a dirty `git status`. A delta
cannot do this: policy changes flow through, and only the named departures persist.

The cost is real and accepted: expressing "I want exactly these twelve packages"
requires knowing what the committed five are. That is the right trade, because the
overwhelmingly common case is *expansion*, and expansion is precisely where a delta
is shorter than a replacement.

### Rejected

- **Environment variable.** Invisible in the checkout, does not survive a new shell,
  and its characteristic failure — a developer forgetting an exported variable and
  blaming the tool — could only be diagnosed by `doctor` reading the environment it
  is otherwise trying to be independent of.
- **`workspace selection` subcommand writing ignored state.** More machinery to write
  a small JSON file that a text editor already writes correctly, in a format
  vocabulary contributors already know from `Selection.json`. If the override grows
  beyond `add`/`remove` this becomes worth revisiting; today it is not.
- **Reusing the already-ignored `.workspace/` directory.** Nothing would appear in
  `git status`, but nothing would appear to a developer looking for it either. The
  file belongs next to the document it modifies.

## 3. Fail-closed applies to the merged result

This was the requirement most easily satisfied on paper and most easily got wrong in
practice. The shape that gets it right is a **single path**:

```
Selection.effective(at:in:)
    ├─ Selection.load          → validated()          committed half, unchanged
    ├─ Override.load           → validated()          the delta's own closures
    ├─ Override.applied(to:)                          merge, with staleness checks
    └─ Selection.resolved(in:origin:)                 the MERGED document
```

Every command reaches a selection through `effective`. There is no second door
through which an override could arrive unvalidated, and `resolved` — which is where
version, emptiness, duplication and inventory presence are finally decided — sees the
merged document, never the committed half.

Three properties are worth stating because a later change could quietly drop any of
them:

**Absence and unreadability are distinguished.** An absent override is a valid state
(committed policy is in effect); a present-but-unreadable one fails the command. The
tempting `try?` collapses these, and that is exactly how a typo becomes a silently
different checkout. `Workspace.Xcode.contents(at:)` already collapses them for its own
reasons; the override deliberately does not copy that.

**A stale delta fails rather than degrading.** Adding something the committed document
already selects, or removing something it does not, means the local file no longer
describes a real departure. Silently dropping the redundant entry would leave a
developer holding a file that says something untrue about their checkout.

**An empty override fails.** A file with `add` and `remove` both empty would make
`doctor` report an override in effect while overriding nothing — a state that *reads*
as a departure but is not one. That is the same failure grammar as a check that
reports "not run", so it is rejected at load.

**Attribution.** A missing identity is reported against whichever document named it. A
typo in a developer's local file must never be reported as a defect in committed
policy; `origin` is threaded into `resolved` for exactly this, and is not decoration.

Eleven fail-closed cases were measured end to end through the binary; all exit 1, a
valid override and no override both exit 0. The table is in
[#46](https://github.com/swift-institute/Workspace/issues/46).

## 4. Why provenance is a report line and not a doctor check

`doctor` leads every run with:

```
selection: Selection.json — 5 selected; Selection.local.json — 1 added, 1 removed; 5 in effect
  Selection.local.json withholds: swift-foundations/swift-http-body
```

or, with no override:

```
selection: Selection.json — 5 selected; no local override
```

Removals are named individually and additions are not. This is not an oversight: the
two answer different questions, and only one of them is asked under duress. A
developer reading this line is looking for a package that **is not there**, and the
override's `remove` list is the answer.

Modelling this as a `Workspace.Doctor.Check` was considered and rejected. A local
override is a legitimate developer choice, not a finding, so the check would be
permanently `ok` — and an `ok` result renders as `ok (population 1)`, which says
nothing about *which* selection is in effect, failing the actual requirement. Making
it emit a finding would flag correct behaviour as a problem.

The stronger objection is structural. A check can also be `notApplicable` or
`unmeasured`, and **a check that reports "not run" is indistinguishable from one that
passed**. This repository already has a live instance of that in
[#43](https://github.com/swift-institute/Workspace/issues/43), a drift detector that
has never executed. A second one would be a self-inflicted wound. A header line has no
such state: it is always printed or the report is empty.

Provenance therefore lives on `Selection.Resolved` — travelling *with* the resolved
repositories rather than beside them — so no consumer can hold the effective set
without being able to say where it came from. `sync` prints it too, since `sync` is
what writes the workspace.

## 5. Evidence

Two claims here cannot be checked by reading code, so both were measured in both
directions in a clone at `2cbaa17`. Full tables in
[#46](https://github.com/swift-institute/Workspace/issues/46); the shape of the
controls is the part worth preserving.

**Invisible to `git status`.** A one-directional control proves nothing here — an
empty `git status` is also what a broken instrument prints. So:

- *positive:* file present → status empty, `git add .` stages nothing,
  `git check-ignore -v` names `.gitignore:10:/Selection.local.json`.
- *negative, instrument:* `Selection.local2.json`, `Selection.local.json.bak` and
  `Application/Selection.local.json` all appear as `??`. Git status was capable of
  reporting; it simply had nothing to report.
- *negative, causation:* delete the rule, same file, same path → `?? Selection.local.json`,
  and `git add .` stages it. That rule is what is doing the hiding.
- *restore* → empty again, file still on disk.

The subdirectory case is worth understanding rather than fixing. The rule is anchored
(`/Selection.local.json`), so an override placed in a subdirectory is *not* ignored —
which is correct, because the loader only ever reads the checkout root. **The only
path that is read is the only path that is ignored.** Broadening the rule would start
hiding files nothing reads.

**Flows through to the generated `.xcworkspace`.** `institute.xcworkspace` derives
from the selection, not the roster — deriving it from `Workspace.json` would open all
445 packages. A real `sync` with an override active produced a workspace containing
the added package and omitting the withheld one, with `git status` empty throughout.
The check discriminates in both directions: override active → `workspace-reference:
ok`; override removed with the workspace file untouched → `error findings —
"institute.xcworkspace does not match the resolved selection"`; override restored →
`ok`. The second state is the control: without it, `ok` would only prove the check is
capable of printing `ok`.

## 6. What a future change could get wrong

1. **Adding a second path to a selection.** Any new command that calls
   `Selection.load(...).resolved(...)` directly bypasses the override *and* its
   validation. `effective(at:in:)` is the only door.
2. **Giving `resolved(in:origin:)` a default origin.** It would compile everywhere and
   silently misattribute every override typo to committed policy.
3. **Relaxing the strict key set.** `version`, `add` and `remove`, all three, no
   others. A tolerated unknown key is an override that silently does less than the
   file says.
4. **Turning the provenance line into a check.** See §4.
5. **Broadening the gitignore rule.** See §5.

`Workspace.Doctor.Report.init` takes `origin` with a default of `.committed(count: 0)`
for report tests that assert on statuses and summaries. The single production caller,
`Doctor.run(access:)`, always passes the measured origin. If a second production
caller ever appears, that default should be removed rather than relied on.

## 7. Not done here

- **`README.md` and `CLAUDE.md`.** Both were dirty from a concurrent session in the
  shared working tree at the time of writing; the collision is being resolved once, and
  the documentation lands after. Until then the mechanism is documented here and in #46
  only, which is a real gap for a contributor reading the README.
- **Migrating this machine's working copy.** `Selection.json` carries 437 entries
  against a committed 5. The migration is byte-neutral for the `.xcworkspace` — write
  the 432 extras as `add` in `Selection.local.json`, then restore `Selection.json` —
  but it touches a deliberately-dirty tracked file that several sessions were
  instructed not to touch. That is the principal's call.
- **Out of scope by instruction:** what `Selection.json` validates, the roster
  generator, and #43.
