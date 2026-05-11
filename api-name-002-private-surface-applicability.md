# [API-NAME-002] Applicability to Non-Public Surface

<!--
---
version: 1.0.0
last_updated: 2026-05-11
status: RECOMMENDATION
---
-->

## Context

The `compound identifier` lint rule ([API-NAME-002], implemented as
`Lint.Rule.Naming.Compound` in `swift-foundations/swift-institute-linter-rules`)
flags compound method, property, and enum-case identifiers across all
visibility levels — public, package, internal, fileprivate, private.
The 2026-05-11 swift-ownership-primitives Wave 2 leaf triage surfaced
two findings that triaged as RULE-WRONG-or-AMBIGUOUS pending a
policy decision:

- `Ownership.Transfer.Erased.Outgoing.Header.destroyPayload` (fileprivate field)
- `Ownership.Transfer.Erased.Outgoing.Header.payloadOffset` (fileprivate field)

`Header` is a fileprivate (single-file) struct inside `Erased.Outgoing`,
holding type-erased payload metadata. The fields are fileprivate fields
on a fileprivate struct — invisible outside the file, no API consumer
ever observes their names. Both have legitimate compound-identifier
shape (`destroy` + `Payload`, `payload` + `Offset`); both could be
decomposed (e.g., `destroy.payload`, `payload.offset` nested
accessors), but the cost of doing so for an internal storage shape
that no consumer reads is non-zero, and the readability of the
compound form at the implementation site is arguably higher than the
decomposed form.

This is one of six Wave 3 amendment threads (HANDOFF Wave 3 §4); five
have landed as rule amendments. Thread 4 is explicitly flagged as a
*rule-policy question, not a fix* — the answer affects [API-NAME-002]
itself, not the lint rule's mechanics.

## Question

**Does [API-NAME-002] (no compound identifiers) apply uniformly to all
visibility levels, or does it apply only to surfaces consumers can
observe (public / package / internal — i.e., named-export surface)?**

Two sub-questions follow from the answer:

1. If the rule applies only to consumer-observable surface, where is
   the boundary — at the *file* boundary (exclude `fileprivate` /
   `private`), at the *module* boundary (exclude `internal` and
   below), or at the *package* boundary (exclude `package` and below)?
2. How should the answer interact with the existing `package`-scope
   exemption (`feedback_compound_package_scope`), which already treats
   `package`-visible decls as exempt?

## Analysis

### Option A — Apply uniformly to all visibility (status quo)

The rule fires on every compound identifier regardless of visibility.

**Pros**:
- Single, mechanical rule. No visibility-level reasoning at the
  call-site or in the linter.
- Internal naming hygiene compounds (no pun intended) over time:
  decls authored at `private` and later widened to `public`
  ([API-IMPL-010] is the existing rule on that direction) ship
  already-compliant; no rename cycle on the visibility flip.
- Consistency: the institute's pattern of "naming is a load-bearing
  surface" applies internally and externally.

**Cons**:
- Fileprivate/private fields on fileprivate types have no
  consumer-observable surface; the rule's stated intent ("methods
  and properties MUST NOT use compound names") is grounded in
  consumer experience, which doesn't apply here.
- The decomposition cost (nested accessor refactor) for purely
  internal storage shapes is paid for a benefit that no consumer
  receives.
- The `package`-scope exemption already acknowledges a visibility-
  based opt-out; extending the carve-out to other non-public levels
  is a smaller policy step than the original exemption was.

### Option B — Apply to public, package, AND internal; exempt fileprivate + private

The rule fires on `public`, `package`, `internal` (and `open`) decls,
but exempts `fileprivate` and `private`.

**Pros**:
- The boundary aligns with Swift's *module-export surface*: any decl
  visible across a file boundary participates in the module's API,
  even if internal-only — module-internal callers observe these
  names.
- Internal storage shapes (file-private structs holding decomposed
  state) are exempt; nested-accessor decomposition at this level is
  pure ceremony.
- Reading is unambiguous: "the rule applies to names that escape
  their file." `fileprivate` / `private` decls don't escape;
  `internal` and up do.

**Cons**:
- Removes the [API-IMPL-010] ramp benefit — a `private` decl widened
  to `internal` later may still need a rename at the visibility
  flip (since `internal` doesn't have the exemption).
- The exemption boundary doesn't match the `package`-scope
  exemption's existing line (which is at `package`, two steps
  wider). The two carve-outs would coexist with different
  rationales.

### Option C — Apply to public + package; exempt internal, fileprivate, private

The rule fires on `public` and `package`. `internal` and below are
exempt — i.e., the rule applies to *named-export surface*
(consumer-observable across module boundaries).

**Pros**:
- Most consistent with the rule's *stated intent*: [API-NAME-002]'s
  examples (`instance.openWrite { }` vs `instance.open.write { }`)
  are all about consumer call-site readability. Internal decls have
  no external consumer.
- Aligns with how the institute talks about "API surface" elsewhere:
  the `public` + `package` line is the named-export boundary;
  `internal` is implementation.
- Subsumes the existing `package`-scope exemption rationale —
  `package` is already on the exempt side here.

**Cons**:
- The widest carve-out. A team can author internal `walkFiles()`
  freely, then surface a refactor cost on the day the decl widens.
- Some institute patterns (e.g., `@usableFromInline internal`) are
  explicitly *inline-visible* to consumers even at `internal`
  level. The decomposition argument still applies to those —
  consumers reading inlined code see the name. The rule would
  need a secondary check (or a sub-rule) to catch
  `@usableFromInline internal` names.

### Comparison Matrix

| Criterion | A: uniform | B: exempt fileprivate+private | C: exempt internal+below |
|-----------|-----------|-------------------------------|--------------------------|
| Consumer-observable rule scope | All | Module-export | Named-export |
| File boundary respected | No | Yes | Yes |
| Module boundary respected | No | No | Yes |
| Aligned with `package`-scope exemption | Inconsistent | Inconsistent | Consistent |
| [API-IMPL-010] ramp benefit | Full | Partial | None |
| Closes the 2 ownership-primitives RULE-WRONG findings | No | Yes | Yes |
| `@usableFromInline internal` handling | Caught uniformly | Caught uniformly | Needs secondary check |

### Empirical Footprint

The Wave 2 leaf triage's compound-identifier finding distribution
across 10 primitive packages (2026-05-11 aggregate baseline at
`swift-foundations/swift-linter-rules/Research/lint-pass-2026-05-11-aggregate.md`)
includes 363 compound-identifier findings ecosystem-wide. The
fraction on fileprivate/private surface vs public/package surface
has not been measured; this is a verification spike the next
session could run by extending the lint pass to capture
visibility per finding.

The specific Wave 2 findings closed by B or C:

- 2 on `Ownership.Transfer.Erased.Outgoing.Header` fileprivate fields.

The Wave 2 findings NOT closed by B or C (still RULE-WRONG for other
reasons):

- 4 on `takeIfPresent` / `consumeIfStored` — public methods; visibility
  exemption doesn't apply; these are an API-rename decision, deferred
  separately per HANDOFF Open Q3.

## Outcome

**Status**: RECOMMENDATION — three options surfaced; decision pending.

Provisional lean: **Option B** (apply to fileprivate+private exemption).

The argument is structural: the rule's intent is consumer-observable
readability; fileprivate/private decls have NO consumer-observable
surface even within the module. The `module-export` boundary (B) is
defensible on stricter "anything visible across a file boundary
counts as named surface" grounds; the `named-export` boundary (C)
loses the `@usableFromInline internal` case without a sub-rule, and
removes the [API-IMPL-010] ramp benefit entirely. B is the smallest
carve-out that closes the empirical residual without other costs.

A decision either way would amend [API-NAME-002] in the
`code-surface` skill (per the canonical-source path in the
collaboration protocol — skills are authoritative) and update the
`Lint.Rule.Naming.Compound` rule to consult visibility before
firing. The amendment shape:

```swift
// At the visit point, before isCompoundIdentifier check:
if hasVisibility(node.modifiers, at: [.fileprivate, .private]) {
    return .visitChildren
}
```

Empirical follow-up that would inform the decision: re-run the lint
pass with visibility-tagged findings to measure the fileprivate/
private slice ecosystem-wide. If the slice is small (< 5% of
compound-identifier findings), the carve-out's downstream effect is
minor; if large, the carve-out merits more deliberation.

## References

- HANDOFF.md Wave 3 thread #4 (the surfacing dispatch)
- `swift-primitives/swift-ownership-primitives` commit `b475d6f` body, "7 compound identifier" residual
- `swift-foundations/swift-linter-rules/Research/wave-2-rule-amendments-2026-05-11.md` (Wave 2 dispatch ledger)
- `Skills/code-surface/SKILL.md` [API-NAME-002] (the rule under question)
- `Skills/code-surface/SKILL.md` [API-IMPL-010] (existing visibility-flip-triggers-rename rule)
- `Skills/code-surface/SKILL.md` [API-NAME-002] `feedback_compound_package_scope` exemption (the prior visibility-based carve-out)
