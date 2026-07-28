# Enforceability Taxonomy and Honest Voice

<!--
---
version: 3.0.0
last_updated: 2026-07-28
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## The claim

A line of normative prose has an *enforcement disposition*. The convention corpus does not
currently distinguish three dispositions that behave very differently, and where a line's voice
implies an enforcer that does not exist, the line is not guidance — it is decoration that reads
as guidance.

The proof is not hypothetical. A line in the Swift conventions asserted that a failable
integer-from-bytes initializer traps on a short slice before the optional is evaluated. It was
specific, mechanism-level, and confident. It was also false of the API for what appears to be
the corpus's entire life — both initializers guard their count and return `nil`; the trap is the
*slice expression* at the call site, firing before the initializer is entered. It survived
because nothing checked it and nobody had cause to. It was corrected only when a downstream task
happened to send someone to the source.

## The taxonomy

**Decidable.** A program can read the artifacts and return a verdict. Enforcement is available.
If no rule exists, the prose is standing in for a rule nobody has written — a backlog item, not
a category.

**Judgeable.** There is a fact of the matter, and a party who knows something *not present in the
artifact* could establish it. The missing information is typically intent, domain meaning, or a
decision recorded elsewhere. A predicate cannot reach it; an informed person can.

**Open.** There is no fact of the matter to establish. The question is a design choice with
defensible answers, and whoever decides is *creating* the answer rather than *checking* it.
Consequence settles it later, not inspection now.

### The sharp edge is between the second and the third

Both fail the same test — no predicate decides them — so they get pooled and routed to "review."
That pooling damages them in opposite directions.

Routing an **open** item to review manufactures false confidence: the reviewer's preference is
recorded as a verdict, and a defensible alternative now reads as a violation.

Routing a **judgeable** item to review is correct in principle, and on a fleet with no second
party routes it nowhere.

The separating test: *would two informed parties, given the same context, necessarily converge?*
If yes, it is judgeable and a disagreement would be a mistake by one of them. If they could
reasonably differ and both be right, it is open.

### Open is rare by construction, and hunting for it is the greater danger

A conventions corpus is largely a record of decisions that have already been made. So *"two
reasonable people could have chosen differently"* is **not** the test. If the question was
settled, it is closed, and the line should keep commanding — the fact that some other choice was
once available says nothing about whether this one is now binding.

The asymmetry matters. Mislabelling a settled decision as open **licenses divergence from a
decision that was actually taken**, which is a live harm. Leaving a genuinely open line in the
imperative is a smaller one. When uncertain, prefer to leave it commanding.

The operational test is therefore not "could this have gone another way" but: **has this been
settled, or is the prose asserting a preference that was never resolved?** And where the second is
suspected, **measure adoption**. A prescribed shape that nothing in the ecosystem actually uses is
open content written as settled — which is exactly how the board-vocabulary defect surfaced, at
zero uses out of ninety-four items. Adoption is the evidence; measure before reclassifying
anything.

### Splits are the common case

In practice, few sentences carry a single disposition. Most carry two: a decidable prohibition
beside an open preference, or a judgeable procedure beside an open choice of instrument.

A naming rule that both forbids one suffix and prefers another between two acceptable
alternatives is decidable in its first half and open in its second. A namespace rule that gives a
determinate procedure for choosing between two forms, then instructs the author to pick a
different word when a candidate is ambiguous, is judgeable then open. A design rule whose
enumerated cases are settled but whose novel cases turn on which properties the author intends a
type to carry is settled *and* open, by case.

**The split is the useful output, not the label.** Classifying such a sentence as a whole forces a
wrong answer either way; separating its clauses lets the enforceable half be enforced and the open
half stop pretending.

## Voice is a second axis

Category and voice are independent, and checking only one misses a whole class of defect. Three
voices matter:

**Imperative** — "every throwing function uses typed throws." Honest when something fires.

**Hedged** — "consider possibly preferring the typed form." Almost never right; see below.

**Descriptive** — a vocabulary or state written as observation: "Status: Backlog, Ready, In
progress, Blocked, Done." This is the most misleading of the three when the content is
aspirational, because the reader gets no cue that anything is being asked of them at all. An
unenforced imperative at least announces itself as a demand.

A live instance: the org project board's status and priority vocabulary is written descriptively
and is used by none of the board's items. That is *open* content — zero adoption is evidence the
vocabulary was never actually settled — wearing *descriptive* voice, which makes it read as
*decidable and observed*. A two-step misclassification. The corpus already owns the correct
framing for this shape elsewhere: a reserved directory "records an intention, never precedent or
ownership evidence." A vocabulary with no adoption records an intention.

## Enforcement claims are verified, not classified

A sentence asserting that something *is checked* — "a validator rejects", "the check flags",
"this is mechanical rather than advisory" — is not a normative rule at all. It is a
source-checkable factual claim about the repository, in exactly the sense the initializer claim
above was a source-checkable claim about an API.

These are greppable, and they are the highest-yield sweep available to a corpus review. At least
one was already false: a claim that the skill validator rejects hubs over a fixed line count,
made in a document whose job is to explain how the corpus is governed, and whose entire
rhetorical purpose was the clause asserting the discipline was mechanical rather than advisory.
The ceiling had been retired and the replacement check states outright that it imposes no length
limit.

An enforcement claim that has gone stale is worse than a wrong technical claim. A wrong technical
claim misleads about the subject. A wrong enforcement claim manufactures exactly the false
confidence this taxonomy exists to name.

## The decidable shell

This is the most useful move available, and the corpus already contains an instance of it.

You cannot check a judgment. You can check that a judgment was **made and recorded, in a fixed
place, in a fixed form**. That converts "trust the author" into "the author's reasoning exists at
a known location," which a predicate confirms and a later reader can audit.

The judgment stays unenforced. What becomes enforced is its *legibility* — and an unenforced
judgment that must be written down is a substantially stronger artifact than one that lives only
in the author's head, because it can be reviewed whenever someone next has cause to look, which
is precisely what did not happen with the initializer claim.

Splitting a judgeable rule into shell plus core should be the default response to finding one,
not an occasional refinement.

### Granularity decides whether a shell works

> **A decidable shell's granularity determines whether it is a live detector or a rubber stamp.
> Pick the coarsest unit that still makes each addition a decision — and measure the yield before
> implementing, because a list that is mostly noise fails in the same way as the check it
> replaces.**

The measurement step is not optional and is easy to skip. For a check distinguishing sanctioned
references to a private location from genuine leaks, the obvious shape — list every occurrence of
a path-like token — was measured before implementation and would have produced a list of
twenty-five entries, twenty-four of which were ordinary prose: `A/B`, `CI/CD`, `ISO/IEC`,
`Tests/Package.swift`. A list that is overwhelmingly noise gets appended to reflexively rather
than read, which reproduces the failure mode of the mechanical gate it was meant to replace.
Narrowing to the *owner* rather than the token shape produced six entries, all real.

The positive framing is the sharper one: **sanctioning an owner arms its namespace.** Listing one
sanctioned path under a private owner is exactly what makes every *other* path under that owner
visible. Coarse granularity is not a concession to brevity; it is what gives the check its reach.

### Co-location is the mechanism, not an addition

The list must live in the repository it scans, so that the entry and the thing it sanctions land
in the same change.

This is not a separate refinement — it is *how* the shell's central claim becomes true. The claim
is that judgment happens at authoring time, while the author is present and knows the intent,
rather than at a review that never occurs. Co-location is the mechanism that delivers it. Put the
list beside the checker instead, and adding an entry becomes a separate change in a different
repository; the judgment drifts back to review, and the shell quietly becomes the thing it
replaced.

A reader who takes co-location as an incidental implementation detail will mis-implement the
whole pattern.

## Worked examples

### A sanctioned reference to a private location

A public file names a private path. So does a genuine leak. No syntactic property separates them:
not the path spelling, not the surrounding sentence, not the file it sits in. What separates them
is that *this* occurrence was decided to be publishable, and that decision is not in the artifact.

Judgeable — but contingently so. Nothing prevented the decision from being written into a list,
at which point the question became decidable. **Some judgeable items are decidable ones whose
distinguishing fact nobody has encoded yet.** Ask that question before accepting the
classification; here, asking it produced a shipped check.

### Domain classification of a raw byte value

The corpus admits this one itself: the decision turns on whether the raw value participates in
arithmetic, and arithmetic happens in method bodies rather than at the storage declaration.

Two layers. Whether arithmetic occurs anywhere is arguably reachable by whole-program analysis.
Whether that arithmetic is *domain* arithmetic or incidental is a judgment about what the type
means. The second layer is what makes it judgeable, and no analysis budget reaches it. Informed
parties converge, which is what distinguishes it from an open question.

### Unchecked concurrency-safety categories

The category assigned to an unchecked `Sendable` conformance depends on *why* the author believes
the type is safe — synchronized, ownership-transferred, thread-confined, or a limitation of
inference. That reason exists nowhere but in their head unless written down.

This is the corpus's existing shell-plus-core instance and the pattern to copy. Whether the
chosen category is correct: judgeable, unenforceable. Whether a justification exists carrying the
required disclosure fields: decidable, and a predicate can require it. The corpus asks for both
and never says which half is checked, so a reader cannot tell that picking the wrong category
costs nothing mechanically while omitting the comment costs a diagnostic.

## A test a reader can apply to a line

1. **Could a program answer this by reading the files?** If yes — decidable. Then ask whether a
   rule exists. If not, the line is a backlog item wearing normative clothing.
2. **If no: what would a person need to know that is not in the artifact?** If the honest answer
   is "nothing, they would just have to look carefully" — it is decidable and the rule is
   unwritten. If it is intent, domain meaning, or a decision made elsewhere — it is judgeable.
   Then ask whether that fact could be recorded to promote it.
3. **If judgeable: would two informed parties necessarily converge?** If they could reasonably
   differ, it is open, and must not be written as a requirement.
4. **Then check the voice against the answer.** Does the line command? Does it describe? Does it
   imply something will catch a violation? A decidable line may command. A judgeable line must
   disclose that nothing checks it. An open line must not command, and must not describe itself
   as practice.

Step 4 finds existing defects; steps 1–3 only classify. And separately from all four: **is this
line an enforcement claim?** If so, verify it against the check that allegedly implements it.

One addition for decidable lines, because it is the step most often skipped: **name the venue.**
Syntax and AST facts belong to the source linter; package-graph and manifest facts to the
workspace validators; repository and platform state to the policy layer; some things are only
provable by building, and some are best enforced by a commit hook rather than any of these.
*Decidable* without a named venue is still unenforced — it merely sounds enforced, which is the
failure this document exists to name.

## Classifying an existing corpus

Applied to the conventions corpus, the taxonomy sorts roughly as follows. Rules are named by their
subject rather than by location, because locations move.

**Decidable, cheap, and purely syntactic** — forbidden suffix and identifier forms; prohibited
local binding names; phantom-tag spellings; the experimental accessor spelling; error-erasing
catch bindings; namespace-restricted extension members; attribute ordering on conformance clauses;
qualification of stdlib protocols that are also used as namespaces; one-type-per-file and
file-name-matches-type-path; the restriction of type bodies to stored properties, the canonical
initializer, and deinit; untyped and existential throws clauses.

**Decidable, but silent when violated** — these deserve rules first, because nothing else will
surface them. A lock-scoped closure returning its own parameter, which hands a region-disconnected
alias out of the lock with no diagnostic. A generic leaf conformer missing its explicit
never-bodied typealias, which fails at link time far from the edit. A multi-level reach-through
from a typed index to a raw integer, which the corpus calls unconditionally wrong. Ownership
escape hatches used outside their declaring file, which the corpus itself describes as costing a
human reviewer. A missing safety disclosure adjacent to an unsafety-asserting attribute — itself a
decidable shell over a judgeable core, since the disclosure's *existence* is checkable and its
*soundness* is not.

**Decidable, but not by the source linter** — platform-C imports outside their sanctioned layer,
retroactive-conformance scope, required package settings and upcoming features, and conditional
compilation confined to particular files. All need package-graph or manifest facts the syntax tree
cannot see.

**Judgeable, and already admitted as such** — the domain classification of a raw byte value, and
the untyped-callee boundary in typed-throws code. Both say outright that no mechanical rule can
decide them. These are the best honest-voice models the corpus already contains, and new
disclosures should be patterned on them rather than newly invented.

**Judgeable with a decidable shell** — the classification of unchecked concurrency-safety
conformances, where the category is judgeable and the presence of the required disclosure fields
is decidable. State which half is checked.

**Open** — the choice between an acceptable suffix and a domain word, once the forbidden form is
excluded; preference between equally natural nouns; default scoping of introductory documentation;
the choice of replacement word when a candidate name is ambiguous; the variant axes of a container
family, which are performance bets rather than correctness facts; and whether to mint a capability
seam at all, which the corpus already calls a deletable convenience.

That last group is short, and it should be. If a review of a conventions corpus produces a long
list of open lines, the classification is probably wrong.

## What honest voice looks like

### For decidable lines

The imperative is honest. Something fires.

### For judgeable lines — three moves

**State the basis, not just the verdict.** The decision procedure is the transferable part; a
verdict without its reasoning cannot be applied to the next case.

**Name who settles it, and say that nothing does so automatically.** This is the move the corpus
never makes, and it is why a reader cannot distinguish a line backed by a rule from a line backed
by nothing.

**State the recording obligation where a shell exists** — where the judgment must be written down,
say where, in what form, and that *this* part is checked.

### What to avoid

**Passive constructions that hide the absent enforcer.** "Is required," "is forbidden," "must
not" — these read as though a system is doing the requiring. When nothing is, they are the precise
failure this document is about.

**Descriptive voice for aspirational content.** See the board vocabulary above.

### Honest is not hedged

Disclosing that a line is unenforced is a statement about *who decides*, not about *how confident
the guidance is*. A softened suggestion is worse than a false imperative: it is both unenforced
*and* unclear, and it discards the transferable decision procedure.

Keep the guidance decisive. Change only the claim about enforcement.

## Which dispositions are actually available

On a fleet operating through a single account, the available dispositions are narrower than they
appear, and two superficially similar ones diverge sharply.

**Authorization before acting is available.** An obligation of the form "this needs the
principal's approval" is real: the principal is asked in band, and answers. Release gates, tag
pushes, and visibility flips work this way and are genuinely gated.

**Review after the fact is not.** An obligation of the form "a reviewer will catch this" names a
party that does not exist as a *gate*. A disposition is real only if there is a moment at which
the check happens and can block. Where one account authors and merges, and the hosting platform
will not accept that account's approval of its own pull request, no such moment exists — the
work has not been routed to a slower gate, but to a gate that cannot close.

This generalises past pull requests: any obligation whose enforcement mechanism is "someone else
checks" is unavailable, which strengthens the case for pushing everything checkable into rules
and for being honest in prose about what remains.

### The pattern in practice

A check for leaked private-repository internals was declined on judgeability grounds — correctly,
since no pattern separates a sanctioned reference from a genuine leak — and its residue was
disposed of as "route to human review." Inspection of the implementation confirmed no allowlist
of any kind and no exemption path; the decline was right and the disposition was not.

The remedy was the decidable shell at owner granularity, with the list co-located in the scanned
repository. The resulting check adjudicates nothing: a listed owner is silent, an unlisted one
stops the build, and the person adding the reference decides inside the change that adds it.
Judgment moved earlier rather than being assigned to a gate that could not close.

## Implications

Every normative line carries a disposition, and its voice should match. Judgeable lines split into
shell plus core wherever a shell exists. Open lines stop commanding, and stop describing
themselves as settled practice. Enforcement claims get verified against the checks they name.

And the standing hazard, on a fleet with no second party: a line that is confident, specific, and
unchecked is indistinguishable from a line that is confident, specific, and correct. A review that
reads every line is the cheapest moment that will ever exist to verify the source-checkable ones.
A review that only improves the prose carries every existing error forward in better English.
