# Remediation mechanics

The parts of a remediation that are the same whichever rule fired. Each playbook in this
directory links here rather than restating any of it, so there is one place to correct when the
tooling changes.

Read this once. Then work from the playbook for the rule you are remediating.

---

## 1. Take the rewriter first, when the rule has one

The engine's fix contract is narrow and worth knowing before you decide anything by hand:
`Lint.Rule.fix` is `(@Sendable (borrowing Lint.Source.Parsed) -> Swift.String?)?` — one file's
text in, the same file's text out. There is no path in the signature. A fix therefore cannot
rename a file, cannot emit a new one, and cannot delete one; rules whose canonical fix requires
any of that keep `fix` as `nil` by construction.

Two further engine facts govern what a rewriter can reach:

- `Lint.Fix.apply` re-parses every rewrite and refuses output that does not parse. It does
  **not** typecheck. A rewrite whose correctness is a type-checking fact is out of reach in
  principle, not by omission.
- Application is gated on the declared SwiftPM target roots. A file outside every declared root
  — the package manifest, most notably — is walked for detection but not reached for
  application.

Where a rule declares a fix, run it before you touch anything by hand:

```sh
workspace package lint --package-path <package> --fix --dry-run   # preview
workspace package lint --package-path <package> --fix             # apply
```

`--fix` is valid only with `workspace package lint` and the `workspace lint` sweep, and
`--dry-run` is meaningful only alongside `--fix`. Read the preview before applying it.

What survives a `--fix` run is the **residual population**: the findings the rewriter refused.
Those are the ones your judgment is for, and each playbook for a rewriter-backed rule names its
refusal set explicitly. Do not treat a refusal as a rewriter defect — every refusal in this
directory is a deliberate safety boundary with a stated reason, and the correct response is to
remediate that finding by hand.

A rule with no fix has no rewriter step. Go straight to its decision tree.

---

## 2. Judge the ripple before you commit to a rename

Some remediations are local — a member moves within its file, a category suite is appended, a
manifest element gains a typed accessor. Nothing outside the file can observe the change, and
there is nothing to trace.

Others change a name that other code spells. Before you rename anything, establish which case
you are in:

| The change | Who observes it |
|---|---|
| Member moved from a type body into an extension **in the same file** | Nobody. Member lookup is unchanged; no call site anywhere changes. |
| Empty category suites appended to a suite | Nobody. Purely additive. |
| Bare dependency string replaced by the typed accessor it already resolved to | Nobody. Same resolved graph. |
| A file renamed | Nobody at the language level — Swift attaches no meaning to a filename. Build-system and VCS concerns only. |
| A **`private`- or `fileprivate`-effective** declaration renamed | Its own file. |
| An **`internal`** declaration renamed | Its own module, plus any `@testable import` of it. |
| A **`package`**-effective declaration renamed | Every target in the same package. |
| A **`public`** declaration renamed | Every dependent package in the ecosystem, transitively. |

The last row is the expensive one, and a rename there is an ecosystem-wide API change rather than a
file edit. But do not assume a rule class sits entirely in one row — the largest class in the
ledger straddles two, and reading it into the bottom row alone would misprice it.

`compound identifier` is the case to have in mind. Its predicate exempts `package`,
`fileprivate`, `private`-effective, and local declarations — and **`internal` is not among the
exemptions**, so an `internal` compound-named member fires exactly as a `public` one does. The
findings therefore split across the `internal` row, whose consumer set is one module plus its
`@testable` importers and is fully enumerable, and the `public` row, which is the transitive one.
Those two halves have different costs, different instruments, and different sequencing, and the
playbook for that rule orders the work around the split.

Establish which row a finding is in before pricing it. Effective visibility, not the declaration's
own modifier, is what decides — a member of an `internal` type is `internal` whatever it says.

**Never estimate the ripple from a grep.** `@_exported public import` lets a consumer bind a
package's types without naming that package in any manifest, so both a manifest census and a
source grep under-report. This is the standing instrument trap for any ecosystem-wide absence
claim: a confident zero from the wrong instrument is the failure mode, and it reads as progress.

### cclsp-assisted propagation

SourceKit-LSP, wired up through cclsp, is the instrument that resolves references by symbol
rather than by text. Install and verify it through the Workspace coordinator:

```sh
workspace navigation install
workspace navigation check
```

Use it to **enumerate references before deciding** and to **propagate a decided rename**. Two
limits bound what it can do for you, and both matter for planning:

- It cannot supply the target. For `compound identifier` and `compound type name` the canonical
  remedy is a restructure into nested accessors or a namespace placement, not a rename — there
  is no function from the flagged identifier to the correct decomposition, and the word-boundary
  scan that detected it is a detector, not a decomposition. cclsp upgrades the mechanics of a
  rename you have already decided; it does not decide it.
- Cross-package propagation requires every consumer indexed in one session. A rename propagated
  across an indexed set is only as complete as that set.

Consequently: for any public-surface rename, the unit of work is the **symbol across its whole
consumer set**, never one finding in one file. A playbook that tells you to batch is telling you
that partial application leaves the ecosystem broken between commits.

---

## 3. Suppress only where the shape is lawful, and always with a reason

Suppression is a recorded judgment that a finding is correct and the code should stay as it is.
It is not a way to reduce a count, and it is not a fallback for a remediation that turned out to
be expensive.

### The lawful shape

The engine recognizes two directives, harvested from comment trivia:

```swift
// swift-linter:disable:next <rule-id>
// REASON: <prose>
```

```swift
let x = compute()  // swift-linter:disable:line <rule-id>
```

- `:next` suppresses the next non-blank line of **code** — it advances past blank and
  comment-only lines, so the `// REASON:` line between the directive and the code does not
  consume the suppression.
- `:line` suppresses the same source line the comment sits on, which is the trailing-comment
  form.
- `// REASON:` continuation lines are recorded against the immediately preceding directive.

Three mechanical facts to keep in mind:

- The rule ID is matched **verbatim** against the rule's declared `id:`, which is a natural-
  English phrase — `compound identifier`, `minimal type body`, `suite categories`. Not an
  identifier, not the citation code. **A mistyped ID is silently inert**: nothing is suppressed
  and nothing reports the mistake. Copy the ID from the diagnostic, then verify per §5.
- The engine does not require a `REASON`. The requirement is editorial, and this directory
  treats it as absolute: a suppression without a reason is indistinguishable at review from a
  count being gamed.
- A file carrying a `swift-linter:disable` for a rule is skipped for that rule by the fix pass
  too. Suppressing a finding therefore also removes it from any future rewriter's reach.

### Reasons that qualify, and reasons that do not

A lawful reason names the **external contract** that dictates the flagged shape, specifically
enough that a reviewer can check it:

> A protocol requirement, a language feature's recognized spelling, a specification's
> vocabulary, a documented stdlib API being mirrored at a deliberate compatibility boundary, or
> an adjudicated ruling — cited precisely enough to verify.

These do not qualify, in any playbook in this directory:

- "Legacy." "Pre-existing." "Out of scope for this change."
- "Renaming would be a breaking change." Every finding on public surface has this property; if
  it were sufficient the rule would fire on nothing.
- "Too many call sites." That is a scheduling fact about the remediation, not a property of the
  code. File the work; do not suppress it.
- Any reason that would apply verbatim to every other finding of the same rule. A reason that
  generalizes to the whole class is an argument against the rule, and belongs on the rule's
  issue tracker as a predicate change, not scattered across consumer files as suppressions.

### When the exemption belongs in the predicate instead

If the shape you are about to suppress is **lawful in general** rather than lawful here, the
suppression is the wrong instrument. Exemptions belong in the rule's Swift predicate, naming the
narrowest stable property that distinguishes the lawful shape — not in consumer configuration
and not in scattered directives. Several rules carry citation dictionaries for exactly this
purpose, and each playbook names its rule's.

Proposing an entry is the correct move when you have found broadly-applicable vocabulary. It
requires a citation, and an entry without one is indefensible at review. Suppressing the same
shape in twenty files instead is the failure mode this paragraph exists to prevent.

### There is a third disposition

Some rules define an **accept-as-warning** arm: the rule fires legitimately, the code is right,
and the warning is the intended standing signal. Leave it. Do not suppress it and do not edit
source against the rule's intent. Where a rule has this arm, its playbook says so.

---

## 4. Batch by symbol and by review, not by count

- **One symbol, one change.** For any rename with a ripple, the owner and every consumer move
  together.
- **One rule, one pull request**, per package. Mixing rule classes in one review means a
  reviewer cannot judge either one against its decision tree.
- **Keep refusals separate from rewrites.** Where a rewriter ran, land its output separately
  from the hand-remediated residual. The two need different scrutiny: the rewriter's output
  needs a spot-check that it did what it claimed, the residual needs its judgment reviewed.
- **Do not mix a suppression with a fix in one commit.** A suppression is a recorded judgment
  and should be reviewable as one.

---

## 5. Verify per finding, and verify the whole file

A remediation is not done because the source looks right. Two checks, in order:

**1. The finding is gone and nothing replaced it.** Re-run the rule over the package and confirm
the specific finding no longer appears — and that the count fell by what you changed, not by
more:

```sh
workspace package lint --package-path <package>
```

A count that fell by more than you remediated is a signal to investigate, not to celebrate. The
common cause is a suppression or an exclusion catching more than intended, and it reads exactly
like progress.

**2. The package still builds, and its tests still pass.** The fix pass re-parses but does not
typecheck, and neither does reading. This is not optional for any change that moved a
declaration or altered a name:

```sh
workspace package build --package-path <package>
workspace package test  --package-path <package>
```

Add `--fresh` when the result will be reported as evidence. Never invoke `swift build`, `swift
test`, or `swift package` directly, and never wrap them in a repository-local script.

### Verifying a suppression actually took

Because a mistyped rule ID is silently inert, a suppression that did not take looks identical in
source to one that did — the difference is visible only in the findings. After adding a
suppression, re-run the lint and confirm the count fell by exactly one. If it did not, the ID is
wrong.

### What counts as evidence beyond your own machine

A local green is iteration signal. When a result is being reported as closure evidence for an
issue or a pull request, it comes from a central CI run and is read from that run's own recorded
conclusion — not from a summary of it.

---

## 6. Before you start, know what the rule actually flags

Every playbook here documents its rule as the predicate is written, not as the convention is
described. Where the two differ, the predicate is what fires, and remediating against a
description that is subtly wider or narrower wastes the work.

Two consequences worth internalizing:

- **A zero is not compliance** unless the predicate reaches the shape in question. Where a rule
  has documented residue — a construct it does not resolve and therefore never reports — its
  playbook says so, and a clean run over such a file means only that the rule found nothing it
  can see.
- **A rule's exemption may be narrower than its rationale.** An exemption gated on same-file
  syntax cannot see a conformance declared in a sibling file, whatever the convention intends.
  Where that gap exists, the playbook names it, because a finding you cannot explain from the
  rationale is usually explained by the gate.

---

## Related

- The rewriter-gap assessment that determined which of these rules can gain a safe autofix, and
  what each rewriter must refuse: swift-foundations/swift-linter#31.
- Rewriter work items: swift-foundations/swift-institute-linter-rules#43 (`minimal type body`),
  swift-foundations/swift-institute-linter-rules#44 (`suite categories`),
  swift-foundations/swift-linter#32 (manifest fix scope, prerequisite for `bare string
  dependency`).
