---
date: 2026-07-08
session_objective: Take swift-webpage to a green build by completing the §Swap-2 port, zero its warning budget, and hand off the repotraffic W4 arc
packages:
  - swift-webpage
  - swift-html
  - swift-css
  - swift-css-html-render
  - swift-server
status: pending
---

# A Commented-Out Type Re-Binds Silently; A Filtered Test Run Passes Vacuously

Continuation of `2026-07-08-swiftpm-identity-collision-livelock-and-swap2-fanout.md`
(same day, predecessor session died on a usage cap mid-fan-out).

## What Happened

Resumed `HANDOFF-swift-webpage-swap2-port.md`. Took `swift-foundations/swift-webpage` from
**1,871 true `error:` diagnostics across 12 files** to **0 errors, 0 warnings**, tests passing on
6.3.2; committed `6e93be8` + `05a7019`, both pushed (repo PRIVATE). Then rewrote the arc handoff.

**Ground truth first.** The handoff claimed *"4338 errors across 14 files."* A fresh build showed
1,871 / 12. It also prescribed type-level renames (`: HTML` → `: HTML.View`, `@HTMLBuilder`,
`HTMLText`) — a precise grep for bare-`HTML` markers returned **zero**; that work was already done.
Two files it listed as "untouched" (`Header`, `Paragraph`) were already partly ported. The one thing
it flagged **"PARTIAL — SUSPECT"** (`Halftone.swift`) was correct.

**Spec validation before fan-out.** Rather than dispatch immediately, I derived the §Swap-2 mapping
from the actual API surface (`.css` proxy on `HTML.CSS`, not `HTML.View`; `pseudo:`/`media:`/`selector:`
parameters replaced by context closures; compound `position(_:top:…)` gone; `transform` typed, not
`String`; `Length`/`FontSize` ambiguous; `tag(_:)` behind `@_spi(DynamicHTML)`), hand-ported
`Halftone.swift` **382 → 0 errors**, and only then wrote the spec to disk and fanned out 10 agents
(one file each, edits only, no builds — the `.build` is shared and builds must be serial per
[PKG-BUILD-009]). Result: **1,489 → 56 errors in one pass**, all 10 agents in scope, zero strays
outside `Sources/Webpage/`.

**The 56 residuals were three real problems**, not noise: a wrong `Color` namespace, and two sites
where `any HTML.View` was passed to `HTML.AnyView.init`.

**The buried bug.** Three files — `Link.swift`, `Label.swift`, `Length.swift` — had been commented
out **wholesale since the initial commit** `dae306d`. Not port damage. Because `Link` did not exist
locally, every `Link(href:) { … }` in `NavigationBar.swift` silently bound to `HTML_Standard.Link` —
the void `<link rel=…>` element — and the compiler reported `missing argument label 'as:'` and
`value of type 'Link' has no member 'padding'` rather than *"cannot find 'Link'"*. Restoring `Link`
fixed a genuine rendering defect: those links now emit `<a href>`. `Label`'s absence had the same
shape (`Button` referenced a `LabelTypealias` that existed only inside the comment block).

**Two symbols had no successor.** `ArrayBuilder` existed nowhere — but `Array.Builder` already ships
in `swift-standard-library-extensions`; I probe-compiled `@Array<any Item>.Builder` on 6.3.2 before
using it. **Zero new public API.** `LegacySVG` was retired by genericising `NavigationBarSVGLogo`.

**Verification.** Compiling is not correctness, so I rendered the ported components to HTML and read
the emitted CSS. Halftone's `::before` rules, `transform:rotate(20deg)` (the typed `Transform`
serialises identically to the old raw string), NavLink's `:hover`/`:link`/`:visited`, Paragraph's
`:not(:last-child)`, and — the riskiest rewrite — NavigationBar's four-argument padding reorder:
desktop emits `padding:0.5rem 0px 0.75rem 0px`, mobile `padding:0.75rem 1.5rem`, matching the
pre-port sources per side.

**Then: `swift test --filter "Scratch Render Check"` returned exit 0 having run zero tests.**
The filter matches the symbol, not the display name. The proof line never printed. I nearly accepted it.

**Warning budget.** 126 → 0. 118 were `'HTMLColor' is deprecated: renamed to 'DarkModeColor'` —
a plain typealias with no local shadow, so the rename is behaviour-neutral *by construction*. The
remaining 16 (2 distinct sites) were `cannot use default expression for inference of '() -> Actions'
… this will be an error in a future Swift language mode`: `Alert`/`Banner` already ship
`extension … where Actions == HTML.Empty` convenience inits, making the `= { HTML.Empty() }` default
both redundant and the cause of the diagnostic. Dropping it is source-compatible — proven by a
throwaway test exercising all six call shapes, not asserted.

**Handoff.** Before writing it I ran a 5-probe read-only recon (docs / git state / blockers / rulings /
membrane). It overturned three claims and found a new one: **`swift-css-html-layout-render` has no
GitHub repo and no `origin` remote** — `bb9170b` exists only on local disk, the directory is its only
copy — while `swift-css`'s unpushed `main` (`6aef222`, **PUBLIC**) declares a URL dependency on it,
resolving only via `mirrors.json:52-53`. A handoff written from the documents would have prescribed
pushing swift-css and broken its public CI at resolve time. Also: the "torn mains consumer-sync gap"
is stale (healed 2026-07-06, zero ecosystem-wide grep hits outside `.build` caches), and swift-server's
"31/31 green" is document-claimed — its `test.out.log` predates HEAD by seven commits.

**Handoff triage** ([REFL-009]; guard: `check-handoffs.sh` reports **61 live files > cap 40**;
`check-memory-corpus.sh` OK — 0 topic files, inbox within cadence). Store scanned: 46 `HANDOFF-*.md`.

| File | Authority | Outcome |
|---|---|---|
| `HANDOFF-swift-webpage-swap2-port.md` | wrote/worked | **retired** → `.trash/` (all Next Steps done; no ground-rules block; no escalation). Durable record = `6e93be8` commit message + this reflection. |
| `swift-webpage-swap2-artifacts/` (14 stale digests) | consumed & superseded | **retired** → `.trash/` |
| `HANDOFF-repotraffic-w4-execution.md` | rewrote | **annotated and left** — live arc; `### Supervisor Ground Rules` block present, entries unverified (fresh dispatch, no work yet) |
| `HANDOFF-overnight-repotraffic-w2-w4.md` | not worked | left, no annotation (predecessor run record, still cited) |
| 43 others | out of authority | left, no annotation |

Per the principal's 2026-07-06 cap ruling, I drained the arc that closed and did **not** re-triage
the rest to force the number down.

## What Worked and What Didn't

**Worked.** Building before believing. Every one of the handoff's five factual claims was checked;
three were wrong. Porting the single hardest file to zero *before* fanning out meant the spec handed
to 10 agents was compiler-validated, not inferred — they cleared 96% of the remaining errors in one
pass with no scope violations. Probing `@Array<any Item>.Builder` with a 20-line `swiftc` program
before committing to it avoided inventing a public `ArrayBuilder` when the ecosystem already had one.
Reading emitted CSS rather than trusting a green build caught nothing wrong, which is the point: it
made "behaviour preserved" an observation instead of a hope.

**Didn't.** I twice mistook a tool's silence for a fact. First: `tail -400 > out.txt` — the redirect
creates the file immediately, so an empty file read as "build finished, no output" when the build was
still running. Second, and worse: `swift test --filter "Scratch Render Check"` exited **0** having run
**0 tests**, and my summary line printed `EXIT=0`. Only checking for the proof line revealed the
vacuity. Both are the same error — reading an exit code or an empty buffer as evidence about a
*different* proposition than the one the tool actually settled.

**Confidence was lowest** exactly where it should have been: the three "genuine design gap" symbols
(`ArrayBuilder`, `LegacySVG`, `Label`). I nearly asked the principal. The right resolution turned out
to be *derivable from the code* in all three cases (an existing builder; genericise; restore the
in-package dead file minus the parts depending on symbols that no longer exist) — and each is one
`git revert` away. Asking would have been slower and no safer. But I should note the asymmetry: the
same instinct correctly stopped me from touching `coenttb/*` under a prior-session override.

## Patterns and Root Causes

**A deleted declaration does not produce a "not found" error in an `@_exported`-heavy package — it
produces the wrong member set.** This is the session's most transferable finding. `swift-html`'s
`exports.swift` re-exports `CSS`, `CSS_Theming`, `Color`, `HTML_Rendering`, `HTML_Standard`,
`Markdown_HTML_Rendering`, `SVG`. Comment out a local `Link`, and the name still resolves — to
`HTML_Standard.Link`. The compiler's diagnostics then describe a type you never intended, and every
instinct ("what changed in the `<link>` element's API?") points away from the actual cause. The tell
is: *an error complaining about the wrong member set on a name you expect to be local.* The mechanical
pre-check is one line — `grep -cvE '^\s*(//|$)' file` == 0 finds fully-commented files — and it belongs
in the diagnostic procedure, not in anyone's memory. Generalised: **the more a package re-exports, the
more a missing local declaration behaves like a *wrong* local declaration.**

**Exit codes settle a narrower proposition than the one being claimed.** [REFL-011]'s tool-reach
extension and [REFL-012]'s belief-vs-state gap are the same failure viewed from two sides, and both
fired here. `swift test --filter X` exiting 0 settles *"nothing that ran, failed."* It does not settle
*"the tests I care about ran and passed"* — and when the filter matches nothing, those two propositions
diverge completely while the exit code stays identical. The generalisation is uncomfortable because it
indicts the most common acceptance gate in the ecosystem: **a test run is evidence only when the
executed-test count is asserted, not merely its exit status.** The same shape produced the `tail` trap
an hour earlier: an empty output file settles *"nothing has been flushed yet,"* not *"the build produced
no output."* Both times I wrote a summary line (`EXIT=0`, `BUILD DONE`) that asserted the broader claim.

**Handoffs decay non-uniformly, and the decay is predictable.** Three of five factual claims were stale;
the one *qualitative, uncertainty-flagged* claim ("PARTIAL — SUSPECT") was accurate. Counts, file lists,
and completion states rot — because they were true when written and nothing re-derives them. Expressions
of the writer's *uncertainty* survive, because they encode a judgement rather than a snapshot. This is
[HANDOFF-006] ("git is ground truth, not agent memory") observed from the reader's side, and it argues
for a sharper writer-side rule than "verify at write time": **prefer recording the enumerating command
over its output.** I did exactly that in the rewritten W4 handoff, and it immediately paid — running the
shipped command surfaced that `swift-css-html-layout-render` has no remote at all, a fact no prose
version of the table had ever contained.

**Validate the transformation on the hardest instance, then fan out.** The predecessor session dispatched
15 agents against an unvalidated spec and lost 13 to a usage cap, leaving `Halftone.swift` torn mid-file.
This session ported that same file by hand first (382 → 0), which is what turned an inferred mapping into
a compiler-checked one — including three things I would certainly have gotten wrong at scale (`transform`
is typed; `pseudo:` is not a parameter; `position(_:top:…)` no longer exists). The cost was one build.
The 10 downstream agents then cleared 1,489 → 56. Fan-out amplifies whatever the spec contains, defects
included; the hardest instance is the cheapest place to discover the spec is wrong.

## Action Items

- [ ] **[skill]** testing: add a rule that a test run is acceptance evidence only when the **executed-test count** is asserted non-zero and matched against expectation — an exit code settles "nothing that ran, failed," not "the intended tests ran." Cite this session: `swift test --filter "Scratch Render Check"` exited 0 having run 0 tests because `--filter` matches the symbol (`ScratchRenderCheck`), not the `@Suite` display name. Prescribe parsing `Test run with N test` (swift-testing) / `Executed N tests` (XCTest), and treat `N == 0` under a filter as a **failure**.
- [ ] **[skill]** issue-investigation: codify the `@_exported` silent-rebind diagnostic. A commented-out or deleted **local** declaration in a package whose umbrella re-exports element/attribute namespaces does not error as "cannot find X" — the name re-binds to the re-exported symbol and the compiler reports the *wrong member set* (`missing argument label 'as:'`, `value of type 'Link' has no member 'padding'`). Tell: an error describing a type you did not intend, on a name you expect to be local. Mechanical pre-check before trusting any "no member" error: `grep -cvE '^\s*(//|$)' <file>` == 0 across the target's sources to find fully-commented files. Provenance: `swift-webpage`'s `Link.swift` binding to `HTML_Standard.Link` (the void `<link>` element) since `dae306d`.
- [ ] **[skill]** supervise: before dispatching a **mechanical fan-out** over N files, require the supervisor to hand-execute the transformation on the single hardest instance and drive it to a green compile, then hand the resulting spec — not an inferred one — to the agents. Complements the prior reflection's post-run reconciliation item ([SUPER-036] gap). Provenance: `Halftone.swift` 382 → 0 by hand validated the §Swap-2 spec; the subsequent 10-agent fan-out took 1,489 → 56 with zero scope violations, where the predecessor's unvalidated 15-agent fan-out tore a file.
