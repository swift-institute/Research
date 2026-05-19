---
date: 2026-05-12
session_objective: Re-triage post-Wave-3 dispositions 2.1 (takeIfPresent) + 2.2 (absorber pattern); verify or refute prior RECOMMENDATIONs' precedent claims; produce findings for parent stamp
packages:
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-institute-linter-rules
  - swift-primitives/swift-ownership-primitives
  - swift-institute
status: pending
---

# Re-Triage of takeIfPresent + Absorber-Pattern: Anchoring Detected via In-Package Sibling

## What Happened

Branching investigation dispatched from a parent conversation working a post-Wave-3 follow-up program. Two Phase-2 RECOMMENDATIONs (`swift-foundations/swift-linter-rules/Research/api-name-002-ifpresent-stdlib-idiom-2026-05-12.md` and `wave-4-absorber-pattern-policy-lean-2026-05-12.md`) were held pending user stamp; the orchestrator flagged both for "anchored to preserve existing API rather than principled rule-fix triage" before routing them through. Investigation scope was limited to producing recommended dispositions with evidence; no implementation, no source-file edits, no Skills edits.

The investigation produced two diverging verdicts:

**2.1 takeIfPresent**: Reverse direction. The prior RECOMMENDATION's RULE-WRONG disposition (extend `[API-NAME-002]` with an "Optional-paired-variant" stdlib-idiom exemption citing `popFirst`/`popLast`) does not hold. Five lines of evidence supported SOURCE-WRONG instead:

1. The RECOMMENDATION concedes the structural mismatch in its own body (lines 45-49: "the distinction is in the VERB, not a suffix... equally valid as a pairing convention"). "Equally valid" is the load-bearing rationalization.
2. The existing `stdlib-idiom-pattern` mechanism in `Lint.Rule.Naming.Compound.swift:67-113` is identity-keyed (dict of 30 verbatim stdlib names), not pattern-keyed. The proposed `<verb>If<Condition>` exemption converts the mechanism, not extends it "alongside."
3. Stdlib has no `<verb>IfPresent`-suffix variant paired with a precondition twin on a single type. Codable's `decodeIfPresent`/`encodeIfPresent` is the only stdlib `IfPresent` shape; pairing axis is different (key-absence, protocol witness).
4. **The decisive finding**: `Ownership.Slot+Take.swift:23-47` already pairs `take() -> Value?` / `take(__unchecked: Void) -> Value` in the SAME package. The 4 residual `takeIfPresent`/`consumeIfStored` sites are out-of-pattern within their own package; the RECOMMENDATION's analysis omitted this in-package sibling entirely.
5. `[API-NAME-008]` (multi-form → Property.View) and `[API-NAME-007]` (internal-capital re-check) both point SOURCE-FIX-ward.

**2.2 absorber pattern**: Hold direction. The "absorber pattern" terminology IS grounded in the corpus — `[MEM-SAFE-020]:21-28` defines "Absorber" as the canonical role-name for `@safe`-annotated declarations; `[MEM-SAFE-025b]:319` uses "the correct absorber pattern" verbatim; the Wave 3 ledger uses the term throughout. The orchestrator's "post-hoc-coined?" suspicion does not survive audit. BUT two concrete defects must be fixed before stamping: (a) the carve-out's condition (2a) cites `Category <A|B|C|D|E>` but Category E is undefined in `[MEM-SAFE-024]` (and line 225 explicitly forbids silent extension); (b) condition (1d) ("invocation of an `@unsafe`-marked function inside an inline method") requires cross-file symbol resolution that the AST-only swift-linter cannot perform.

Findings appended to the handoff file (`/Users/coen/Developer/HANDOFF-rule-triage-re-examination.md` lines 128-226, structured per the prescribed `### 2.1` / `### 2.2` template). Parent subsequently annotated the file as "Superseded by Wave 3 aggregate ledger v1.4.0" — 2.1 drove SOURCE-WRONG implementation at swift-ownership-primitives `6adf223` (Open Q1 closure, Option A); 2.2 folded into HANDOFF.md Open Q1 (Wave 4 stamp conditional on defect-fixes per this audit).

## What Worked and What Didn't

**Worked**:
- *Reading the RECOMMENDATION's own body adversarially.* The "equally valid as a pairing convention" phrase on line 47 of the 2.1 doc was diagnostic — the structural inanaloguity is conceded on the same paragraph that proposes the exemption. Treating the RECOMMENDATION's text as a hostile witness (rather than a load-bearing argument) surfaced this in ~2 minutes.
- *Reading the lint rule's actual implementation, not just its prose description.* The RECOMMENDATION described the existing mechanism as `stdlib-idiom-pattern` citations the new exemption would extend "alongside." The implementation at `Lint.Rule.Naming.Compound.swift:67-113` revealed the mechanism is a `[String: String]` dict keyed on verbatim stdlib names — identity-keyed, not pattern-keyed. The proposed amendment is a category-conversion, not an extension. The prose framing was misleading; the implementation was authoritative.
- *Greping the source-tree for in-package siblings of the conceptual pair.* The discovery of `Slot.take(__unchecked:)` was the single strongest piece of evidence for SOURCE-WRONG — and the prior RECOMMENDATION had omitted it entirely. The session-level cost of the grep was seconds; the analytical weight it carried was decisive.
- *Cross-checking carve-out citations against the cited rule's actual body.* The 2.2 carve-out's "Category E" reference jumped out as soon as `[MEM-SAFE-024]`'s taxonomy was read end-to-end (only A-D defined; line 225 forbids silent extension). This is a mechanical defect a reviewer should catch on first read.

**Didn't work**:
- *Excess context spent enumerating stdlib `IfPresent` shapes before the in-package precedent surfaced.* The grep for `IfPresent` / `ifPresent` across primitives + foundations + standards returned the Codable + Ownership-package occurrences + a `dispatchNestedIfPresent` audit-finding from swift-linter. The Slot precedent was found later via the `take`/`consume` API-shape grep. In retrospect, leading with "what does this package already do for the same conceptual pair?" would have arrived at SOURCE-WRONG faster. The stdlib enumeration confirmed what the RECOMMENDATION already conceded; it was double-evidence, not decisive evidence.
- *The investigation could have surfaced the in-package precedent within the first three tool calls if the session had explicitly asked "for the same conceptual pair (precondition-asserting + Optional-returning consume of one element), what shapes already exist in this package?" before doing stdlib enumeration.*

## Patterns and Root Causes

**Pattern 1: Prior RECOMMENDATIONs anchor next-session triage by what they omit, not just what they cite.** The 2.1 RECOMMENDATION's "Stdlib Precedent" table listed four stdlib analogues — but the precedent that would have decided the case (`Ownership.Slot.take(__unchecked:)`, in the same package the residual sites live in) was absent. The orchestrator's "anchored to preserve existing API" suspicion was correct, but the anchoring mechanism wasn't "cited a weak precedent" — it was "framed the analysis matrix to omit the in-package counter-precedent." A re-triage that just inspects the cited precedents and asks "do these hold?" misses the omission. The discipline needed is **counter-precedent enumeration in the same scope as the prior doc's citation scope** — if the prior doc cites stdlib precedents, the re-triage must enumerate in-package + ecosystem precedents; if the prior doc cites in-package precedents, the re-triage must enumerate ecosystem + stdlib precedents; etc. Parallels `[HANDOFF-013a]` (writer-side prior-research grep) but on the symmetric reviewer-side counter-precedent axis.

**Pattern 2: A mechanism's actual implementation is authoritative; the proposing doc's prose description is not.** The 2.1 RECOMMENDATION described the existing exemption mechanism in terms that implied pattern-keyed extension would be "alongside" the existing form. Reading the source revealed identity-keyed shape — the proposal would be a category-conversion, materially broader. The lesson: when a RECOMMENDATION proposes to "extend an existing mechanism alongside existing X," the reviewer MUST read the mechanism's implementation before accepting the framing. The "alongside" claim is a structural claim that source code can verify or refute; the doc's prose alone cannot.

**Pattern 3: Carve-outs that cite undefined corpus entries are corpus-inconsistencies the linter cannot catch but a reviewer can.** The 2.2 carve-out's "Category E" reference is a mechanical defect: cited rule is read end-to-end, and the citation is verified or refuted against the rule's actual content. This class of defect (citation-without-corresponding-definition) is exactly the kind of inconsistency that accumulates in a fast-moving rule corpus and that mechanical lint cannot catch (the rule corpus IS the linter). The cheapest catch point is the carve-out's review pass — five seconds to verify "is Category E defined in `[MEM-SAFE-024]`?"

**Pattern 4: Orchestrator-flagged re-triage produces asymmetric outcomes.** Both 2.1 and 2.2 were flagged on the same suspicion ("post-hoc rationalization"). 2.1's precedent failed audit (the popFirst/popLast structural mismatch is conceded by the RECOMMENDATION itself); 2.2's term-grounding survived (the corpus does define "absorber"). The flag was warranted for both but the answers diverge. **Re-triage flags are signals that warrant investigation, not predictions of outcome.** A skilled investigator should approach each flag with genuine uncertainty about which direction the evidence will point.

Root cause for 2.1's defect class: the prior RECOMMENDATION was written by an executor who had just landed multiple Wave-2 exemption amendments. The framing "alongside the existing `stdlib-idiom-pattern` citations" was natural-cohort context bleed — the author was in the headspace of admitting exemptions, not in the headspace of asking "should this be admitted at all?" The 4 residual sites were stable, the API was already shipped, and the easiest path was an exemption. The in-package counter-precedent was unsearched because the framing didn't invite that search.

## Action Items

- [ ] **[skill]** handoff: Add a sibling rule to `[HANDOFF-013a]` for re-triage / re-examination handoffs that inherit framing from a prior RECOMMENDATION. The receiver MUST enumerate counter-precedents in the same scope as the prior doc's citation scope (in-package siblings when prior cites stdlib; ecosystem siblings when prior cites in-package; etc.). Rationale: the 2.1 case demonstrated that anchoring is detected via what the prior doc OMITS from its precedent table, not via what it cites. Provenance: this reflection.
- [ ] **[skill]** code-surface: Extend `[API-NAME-002]` (or add as sibling under `[API-NAME-007]`/`[API-NAME-008]`) — exemption proposals MUST (a) read the exemption mechanism's actual implementation, not the prose description, and (b) enumerate in-package sibling pairs for the same conceptual shape. The Wave 3 ledger's existing line "Citation key required at write time" is the corpus norm for the identity-keyed mechanism; extensions that propose pattern-keying are category-conversions and require explicit user-adjudication.
- [ ] **[skill]** memory-safety: Add a guard for carve-out citations against `[MEM-SAFE-024]` taxonomy — citing a category not defined in the rule body (e.g., "Category E" without Category E's prior introduction) is a mechanical defect. Either codify "carve-out wording cites only currently-defined categories" or extend `[MEM-SAFE-024]:225`'s user-adjudication gate to fire at carve-out-proposal time, not just at silent-extension time.
