---
date: 2026-04-21
session_objective: Land the final documentation + CI + code-surface polish for swift-property-primitives 0.1.0, then dispatch the pre-release audit
packages:
  - swift-property-primitives
  - swift-institute/Research
  - swift-institute/Skills/documentation
  - swift-institute/Skills/property-primitives
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Property Primitives Typealias Sweep and Self-Compliance Gap During Rule Enforcement

## What Happened

Session continuation from the earlier supervised 0.1.0 handoff execution,
after the `[SUPER-010]` Success termination. Three threads ran in
sequence across nine commits:

**Thread 1 — v1.2.0 DocC pipeline.** The prior pipeline used `xcodebuild
docbuild -scheme "Property Primitives"` plus symbol-graph patching to
inject `@_exported`-stripped doc comments. A speculative switch to
`swift build -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir
<out>` revealed that swiftc's symbol-graph extractor PRESERVES doc
comments on `@_exported public import` re-exports, while `xcodebuild
docbuild` strips them. The patch step became a defensive no-op; variant
`.docc/` directories (previously needed to silence docbuild's "No valid
content" warnings — resolved 2026-04-20 by restoring `.gitkeep`-only
placeholders at commit `60a1180`) could be removed entirely. Pipeline
reshape shipped at `d1cea57`; research `docc-multi-target-documentation-
aggregation.md` v1.1.0 → v1.2.0 at `e13d517`; skill `documentation`
[DOC-019a]/[DOC-020] at `ac27be1`; README block rewritten at `1aa4d01`.

**Thread 2 — [PRP-003] typealias short-form sweep.** The user spotted
a rendered DocC page (`Property.Consuming`) showing the long form
`Property<ForEach, Self>.Consuming<Element>` at accessor sites, and
asked whether we had inventoried. Inventory: 15 sites across 8 articles
and 7 source inline `///` examples, plus 3 skill examples. Converted
all to `Property<Tag>` short form with `typealias Property<Tag> =
Property_Primitives.Property<Tag, Self>` on the container. Extension
sites standardised on `extension Property_Primitives.Property.X
where ...`. Commits `ef72a75` (package), `5e28b36` (skill).

**Thread 3 — "why is long-form used in [PRP-012]?"** User asked me to
justify why the tag-enum-View typealias uses long form inside its body.
I confidently answered "that's the correct shape for that pattern" from
memory. User pushed back: *"I'd also be curious to have an experiment
that validates the long form is necessary for extensions."* The
experiment (`property-typealias-extension-forms`, commit `98a1926`)
revealed:

- Q-A: short form `Property<Insert>.View.Typed<E>.Valued<N>` DOES
  resolve inside a nested tag enum's own typealias body (Swift's
  unqualified lookup climbs enclosing-type scopes). Long form is a
  self-containment convention in consumers that don't adopt a
  container-level `Property<Tag>`, not a compiler requirement.
- Q-B: `extension Stack.Property where Tag == ..., Base == ...`
  compiles cleanly.
- Q-B': `extension Stack.Property.Typed` FAILS —
  *"'Typed' is not a member type of type 'Stack.Property'"*. Swift does
  NOT expand generic typealiases during extension member-type lookup.
  This asymmetry is the real reason the ecosystem canonicalises
  `extension Property_Primitives.Property.X where ...`.

Commit `98a1926` introduced the experiment with method names
`shapeA_back`, `shapeB_back`, `shapeBprime_back` — compound identifiers
in violation of `[API-NAME-002]`. Commit `1ea8a9c` rewrote the
experiment body to use a `Deque` with `push.back(_:)` / `push.front(_:)`
/ `peek.back` / `peek.count` nested accessors. Commit `50515c7` added
the `## Where the container-scoped Property<Tag> typealias applies`
section to `Phantom-Tag-Semantics.md` and renamed the experiment's
`BufferLinked<Element, N>` to `Ring<Element, N>` to eliminate a
separate compound-identifier violation of `[API-NAME-001]`. The user
prompted the self-compliance check by reminding me to *"strictly
comply with /code-surface , especially re no compound identifier"*
after I had already committed two violations.

**Thread 4 — audit dispatch.** Committed `cb9be51` drafted
`AUDIT-0.1.0-release-readiness.md` at package root per `[HANDOFF-015]`
convention, with a `.gitignore` LOCAL OVERRIDES line `!/AUDIT-*.md`
added because the canonical `sync-gitignore.sh` does not yet carry
that whitelist. The handoff dispatches Part A (re-verify 4 remaining
DEFERRED/OPEN findings from the 2026-04-20 audit), Part B (fresh
audits against skills not yet covered), Part C (release-readiness
checks). User confirmed the intent is a fresh-agent audit, not
self-invocation.

**HANDOFF scan**: 1 file found at working directory root
(`AUDIT-0.1.0-release-readiness.md`); 0 deleted, 0 annotated, 1 left
as fresh-dispatch (audit not yet run, no supervisor ground-rules
block present, no scope items completed yet — per `[REFL-009]`
"Some items remain → Leave the updated file").

**AUDIT cleanup**: `/audit` was not invoked this session, so
`[REFL-010]` does not apply. The existing `Audits/audit.md` was read
for prior-findings summarisation but not edited.

## What Worked and What Didn't

**Worked:**

- User pushback on the `[PRP-012]` claim was the cheapest possible
  correction. *"I'd also be curious to have an experiment that
  validates..."* reframed the question from "is my answer right?" to
  "let's check." The experiment took five minutes and revealed three
  findings I had glossed over.
- The typealias short-form sweep itself was mechanical and effective.
  Inventory (grep), conversion (edit), verification (rebuild + docc
  convert + route check) — no surprises, commit landed clean.
- The swift-build-vs-xcodebuild-docbuild distinction is genuinely new
  ecosystem-level knowledge. v1.2.0's research documents the
  mechanism and cost comparison; the skill reflects the simpler shape.
- HANDOFF-015 audit-prefix convention held up in practice. The file's
  name (`AUDIT-0.1.0-release-readiness.md`) self-identifies as an
  audit artifact; the gitignore-override pathway was clean once the
  override was added.

**Didn't work:**

- First answer to *"why is long-form used in [PRP-012]?"* was a
  post-hoc justification from memory, not a verified claim. I wrote
  *"that's the correct shape for that pattern"* and gave the
  self-containment reason — which turned out to be true for the
  convention but false for "correct shape." The stronger claim
  ("works only in long form") was never the actual rule.
- Committed `shapeA_back` / `shapeB_back` / `BufferLinked` as fresh
  compound-identifier violations immediately after a 15-file sweep
  enforcing `[API-NAME-002]` / `[API-NAME-001]` on pre-existing
  examples. The rule I was enforcing had a blind spot for new code
  authored in the same session.
- The self-compliance gap was not caught by any mechanical check.
  The user's explicit *"if so, also need to strictly comply with
  /code-surface"* was the catch. Without it, the violations would
  have shipped.

## Patterns and Root Causes

**Pattern 1 — Enforcement creates a blind spot for parallel new
code.** When a session's primary work is "apply rule R to
pre-existing files 1..N", the agent's attention is directed at
those N files. Any new code produced in the same session for a
different purpose (tests, experiments, fixtures, article example
code, handoff artifacts) sits outside the sweep's scope *even though
the rule applies to it equally*. This is structurally similar to the
"re-verify-after-edit" rule in `[REFL-006]`, but oriented along a
different axis: re-verify-after-edit widens the DETECTION pass to
catch missed instances in the scope; the new pattern widens the
SCOPE itself to include parallel new code authored for other
purposes.

Concrete this session: 15 files swept for `[PRP-003]` short-form +
`[API-NAME-002]` extension-site shape. During that sweep, I authored
(a) an experiment with `shapeA_back`/`shapeB_back` compound names
violating `[API-NAME-002]`, and (b) a `BufferLinked` container type
violating `[API-NAME-001]`. Both fresh-code, neither touched by the
sweep's inventory grep. The user's catch was mechanical: check that
the rule being enforced applies to new code too.

The `feedback_docs_strict_code_surface` memory — *"All documentation
must strictly comply with code-surface rules, especially no compound
identifiers"* — already exists. The gap isn't a missing rule; it's
missing memory consultation when new docs/examples are authored.
Similar to the `feedback_no_unsafe_api_surface` consultation gap
surfaced on 2026-04-20.

**Pattern 2 — "Why is X correct?" defaults to justification-from-memory
rather than verification.** When asked to justify a past claim, an
agent's default response is a post-hoc rationalisation drawn from the
claim's surrounding context rather than a re-verification of the
claim's grounding. This session's `[PRP-012]` example: my initial
answer was internally consistent (self-containment is a real reason
the convention exists) but missed that the STRONGER form of the claim
— "works only in long form" — was never verified. The user's
experiment-request reframed the question from "justify" to "verify";
the experiment falsified the strong form while confirming the weak
form.

`feedback_verify_prior_findings` already covers this in memory
(*"Verify each finding against current code before synthesis"*). The
consultation gap is the same as Pattern 1 — memory exists, not
consulted at the moment of speech-act.

**Pattern 3 — Ecosystem convention vs compiler requirement is an
asymmetric distinction worth drawing explicitly.** Three shapes
emerged in the `[PRP-012]` experiment:

- Q-A: short-form works; long-form is convention-choice
- Q-B: container-scoped extension works; module-qualified is
  convention-choice
- Q-B': module-qualified extension is the *only* shape that works;
  container-scoped fails to compile

Only Q-B' is a compiler requirement. Q-A and Q-B are convention
choices. The ecosystem's uniform use of module-qualified `extension
Property_Primitives.Property.X where ...` is grounded in Q-B' — if
ANY extension site needs the module-qualified form (for `.Typed`,
`.View`, `.Consuming` nested types), all sites should use it for
consistency. Without the experiment, the distinction (which sites
are "forced" vs "preferred") was not clear; the skill and articles
carried a rule without clear grounding.

**Recurring theme**: memory consultation gaps are the session-level
failure mode most cheaply closed by mechanical scans (grep
`feedback_*`) at commit boundaries, not by adding new rules. The
post-commit memory scan rule in `[REFL-006]` aims at this; it needs
to fire on ANY commit in a session where code-surface rules touch
the change class, not just the primary-work commits.

## Action Items

- [ ] **[skill]** code-surface: Add new-code self-compliance clause. When an agent runs a rule-enforcement sweep (converting N files to comply with [API-NAME-*] or similar), new code authored in the same session for ANY purpose (tests, experiments, fixtures, article examples, handoff artifacts) MUST be swept for the same rule before commit. Session-level scope includes parallel new code, not just the enforcement target. Provenance: this session introduced `shapeA_back` / `shapeB_back` compound IDs and `BufferLinked` compound type while sweeping 15 files for `[PRP-003]`; caught only when user explicitly invoked the compliance reminder.

- [ ] **[package]** swift-institute: Update `Scripts/sync-gitignore.sh` to whitelist `AUDIT-*.md` at root per `[HANDOFF-015]` convention. The canonical gitignore currently ignores audit artifacts alongside `HANDOFF-*.md` transient files; `[HANDOFF-015]` explicitly intends audit artifacts to live in git history ("audit history stays in the repo, task handoffs churn"). This session added the whitelist as a local override in swift-property-primitives; the ecosystem-wide fix belongs in the sync script. ~50+ packages use sync-gitignore.sh; they will need the update to match the skill's intent.
