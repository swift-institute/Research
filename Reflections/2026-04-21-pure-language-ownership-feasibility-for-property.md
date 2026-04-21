---
date: 2026-04-21
session_objective: Investigate whether pure Swift 6.3 ownership vocabulary can replace the Property / Property.Typed / Property.Consuming / Property.View type families at equivalent ergonomics; write consolidated research + four experiments without touching production source.
packages:
  - swift-property-primitives
status: pending
---

# Pure-Language Ownership Feasibility for the Property Type Family

## What Happened

Followed the investigation handoff at
`swift-property-primitives/HANDOFF-pure-language-ownership-feasibility.md`.
Created four experiment packages (one per type family) under
`Experiments/language-semantic-*-replacement/`, wrote the consolidated
verdict to `Research/pure-language-ownership-feasibility.md` v1.0.0,
appended a `## Findings` section to the handoff, and committed the
bundle as 8945902 (10 files, 1180 insertions). Four families
evaluated:

1. **`Property<Tag, Base>`** — per-namespace hand-rolled `~Copyable`
   proxy + CoW `_modify` recipe reproduces `container.push.back(_:)` in
   debug.
2. **`Property.Typed<Element>`** — nesting the proxy inside the
   parametric outer container places `Element` in lexical scope,
   one-for-one replacement of property-case extensions.
3. **`Property.Consuming`** — handoff's worked example
   `container.forEach { process(consume $0) }` REFUTED by the compiler
   itself: `warning: 'consume' applied to bitwise-copyable type 'Int'
   has no effect`. V2 (`consuming func drain`) reproduces the consume
   behaviour but with stronger whole-binding-consume semantics. V3
   reproduces Property.Consuming's dynamic state machine per namespace.
4. **`Property.View` family** — per-namespace `~Copyable, ~Escapable` +
   `@_lifetime(borrow base)` + `mutating _read`/`_modify` reproduces
   the pattern. Requires `-enable-experimental-feature Lifetimes` (the
   flag the shipped package already enables).

Verdict: all four **PARTIALLY-REPLACEABLE**, none REPLACEABLE at
equivalent ergonomics ecosystem-wide. Retention recommended. Value of
the types is amortization + centralised compiler-bug absorption, not
language-capability gap-filling.

Mid-session also surfaced a `.docc` layout question for the umbrella
catalogue — flat vs subdirectories. Consulted the documentation skill,
which had `[DOC-026] Companion Document Subdirectories` SHOULD them.
User decision: always keep flat, because DocC resolves by filename not
path. Inverted the rule in
`swift-institute/Skills/documentation/SKILL.md`:
[DOC-026] now reads "Flat Catalogue Layout" (MUST-level);
[DOC-027] phrasing updated to drop the subdirectories reference.
Committed as b317ef7 in the Skills repo.

Handoff triage per [REFL-009]: one file scanned
(`HANDOFF-pure-language-ownership-feasibility.md`), all items complete
(Findings appended; 4 experiments + research doc committed); no
supervisor ground-rules block present; no pending escalation. File is
gitignored (`.gitignore:37 *.md`), so deleting it has no git-history
implication — deleted per the standard rule.

No `/audit` invoked this session; [REFL-010] not applicable.

## What Worked and What Didn't

**Worked**:

- *The compiler as refutation engine.* The handoff's own worked example
  compiled without error — and the compiler's warning *"'consume'
  applied to bitwise-copyable type 'Int' has no effect"* was a
  first-line, authoritative rejection. No judgment call needed; the
  toolchain did the reasoning. Capturing this warning verbatim in the
  experiment header made the REFUTED verdict unarguable.
- *Per-family experiment decomposition.* One experiment per type
  family mapped cleanly onto the handoff's enumerated scope. Each
  experiment's main.swift header carried the V1/V2/V3 variant summary
  + per-variant verdict; the consolidated research doc just assembled
  the verdicts. No extra synthesis layer was needed because the
  experiments were already structured for consolidation.
- *Prior-research consultation.* `[HANDOFF-013]` directed reading
  `property-type-family.md`, `variant-decomposition-rationale.md`,
  `borrowing-label-drop-rationale.md`,
  `property-view-escapable-removal.md`, and
  `noncopyable-ownership-transfer-patterns.md`. All five informed the
  "amortization vs language-capability" framing that became the
  verdict's load-bearing argument. Without those reads, the verdict
  would have been narrower and more vulnerable to "but pure language
  CAN replace this" counter-arguments.

**Didn't work (and recoveries)**:

- *First-pass V1 Property experiment used `@inlinable` without
  `@usableFromInline` on internal storage.* Got clean compiler errors
  naming the exact property. One-edit recovery. Cost: one build cycle.
- *Swift 6.3 "a mutating method cannot return a ~Escapable result"
  rule surprised the Property.View experiment.* The shipped package
  has this pattern working, which meant the issue had to be
  environmental, not fundamental. Matched: enabling `LifetimeDependence`
  + `Lifetimes` experimental features on the experiment's Package.swift
  (same flags the shipped package enables ecosystem-wide) lifted the
  rule. The experiment header now documents this explicitly — future
  readers don't re-run this discovery.
- *Release-mode V1 Property experiment crashed* with `forwardToInit:
  Cannot initialize a nonCopyable type with a guaranteed value` in
  `CrossModuleOptimization`. Same crash shape as
  `Experiments/property-consuming-value-state`. Consulted that
  experiment's index entry; confirmed it is the same inliner bug. The
  shipped Property type sidesteps it by living in a separate library
  target — single-module executable + ~Copyable proxy + `_read`/`_modify`
  coroutine + CMO hits the bug. Documented in the experiment header as
  "orthogonal to the semantic-equivalence question."

**`_index.json` editing race condition**:
while I was appending my four language-semantic-* entries to
`Experiments/_index.json`, the parent session committed a separate
entry (`property-typealias-extension-forms`) to the same file. My Edit
failed ("File has been modified since read"). Re-read, re-positioned
the insert, succeeded. Later, the parent session also committed my
four entries as part of a subsequent commit — so `git diff` on my
branch showed an empty diff for that file even though my content was
present. Learned: in a live multi-agent setting, the `_index.json`
file is a hot object; edits need to re-read before every attempt and
the final commit should use `git diff` as a source of truth rather
than working-tree state.

## Patterns and Root Causes

**The compiler-evidenced refutation pattern.** The handoff's proposal
looked reasonable on the page. The correction came from the compiler,
not from analysis — `consume $0` on `Int` is a no-op, and Swift itself
says so with a warning. This is a recurring pattern: proposed language
simplifications that read naturally often fail on the exact scope the
annotation applies to (the closure parameter, not the container; the
CLOSURE-LOCAL, not the source value). When evaluating a proposed
simplification of this shape, the first step is *compile it and read
the compiler's output*, not analyze it prose-first. Two earlier
reflections (Sendable-audit option C, borrowing-label drop) lean the
same way — when a pattern reads well but the compiler disagrees, the
compiler wins and the disagreement *is* the finding.

**The amortization-vs-capability axis.** Three of the four Property
families have pure-language equivalents — per namespace. The types
don't plug a language gap; they amortize a per-namespace template
across the ecosystem. This is a distinct category from types that
genuinely fill language-capability gaps (e.g., `Span<T>` for
`~Escapable` lifetime-bounded views before SE-0446). When asked "is X
still needed?" the answer should be partitioned: (a) is there a
language capability that X is wrapping? (b) is there amortization
value? (c) is there centralised compiler-bug absorption? Only (a) is a
removal candidate on its own merit; (b) and (c) are ecosystem
arguments that require counting consumers and workarounds. The
Property family is (b)+(c), not (a), and the reflection is that this
distinction was not historically spelled out in the family's own
research doc — it had to be reconstructed this session from
`property-view-escapable-removal.md`'s 149-site `@_optimize(none)`
history and `borrowing-label-drop-rationale.md`'s 19-site migration
evidence.

**Single-module vs library-target ~Copyable proxy exposure.** The V1
Property experiment's release-mode `forwardToInit` crash is not a
property-primitives-specific bug. It is a general SIL interaction:
~Copyable struct + `_read`/`_modify` coroutine + CMO +
single-module-executable = crash. The shipped package sidesteps it by
the Core-target / consumer-target boundary. This means any future
pure-language replacement of the family would need to rebuild the
same module boundary to compile in release — effectively reconstructing
Property Primitives Core under a different name. The module boundary
is doing load-bearing work that isn't visible in the type's type
signature.

**DocC layout is invisible to readers.** The `[DOC-026]` inversion
rests on a simple fact: DocC addresses articles by filename, not path.
Subdirectories had been admitted on SHOULD-basis for "large companion
documents" — but there was no evidence any reader benefited. The user
asked the simple question ("should we add directories or keep flat?"),
and the honest answer was "nesting adds zero reader value". This
suggests a general skill-review question: *which SHOULD rules rest on
evidence of reader/consumer benefit, and which rest on author
preference?* Author-preference SHOULD rules are candidates for
inversion or deletion.

## Action Items

- [ ] **[research]** swift-institute: Document the "single-module ~Copyable
      proxy + `_read`/`_modify` coroutine + CMO = `forwardToInit` SIL
      crash" pattern as an ecosystem-wide note, not just a
      property-primitives-specific observation. Cross-reference the
      three experiments that have hit it
      (`property-consuming-value-state`,
      `language-semantic-property-replacement`,
      `language-semantic-property-typed-replacement`) and note the
      library-target-boundary as the empirically verified escape
      hatch. Tier 2.
- [ ] **[blog]** "When the compiler is the refutation":
      `consume $0` on bitwise-copyable types produces
      `warning: 'consume' applied to bitwise-copyable type 'Int' has
      no effect`. Use this session's Property.Consuming replacement
      investigation as the case study — a proposal that compiles but
      the compiler itself flags as a no-op. Short form (under 800
      words); publishable from the V1 variant of
      `language-semantic-property-consuming-replacement` verbatim.
- [ ] **[skill]** documentation: audit remaining SHOULD rules for
      reader-benefit evidence vs author-preference basis, using
      [DOC-026]'s recent inversion as the template. Candidates for
      scrutiny: [DOC-023] substantive per-symbol article SHOULD-level
      sections, [DOC-091] hero image SHOULD placement.
