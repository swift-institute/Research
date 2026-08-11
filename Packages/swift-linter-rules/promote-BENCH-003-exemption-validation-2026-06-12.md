# Validation receipt: [BENCH-003] executable-variant exemption (rule amendment)
Date: 2026-06-12
Rule: benchmark timed required (EXISTING — Wave 2b 2026-05-10; this pilot amends)
Detection method: regex pre-scan + carve-inertness equivalence proof.

The amendment adds the citation-comment carve (suite- or function-level `[BENCH-003]` in
leading trivia exempts; depth-balanced for repeated suites) + variant remediation in the
message. The carve only ever REMOVES findings and only on the literal citation string:

| Step | Result |
|---|---|
| Broad regex (`struct Performance` / `extension *.Performance`) across ladder + 27 tower packages | 56 files in 7 packages |
| Literal `[BENCH-003]` in those packages' Sources+Tests | **0** |
| ⇒ carve inert on the entire validation set | amended rule ≡ shipped rule; the shipped rule's Wave-2b validation stands |
| Fixture suite (3 new carve cases incl. the depth-balance regression) | 8/8 green |

Tower note: the only tower Performance-named suite is tree-keyed's empty
`@Suite(.serialized) struct Performance {}` shell (Tree.Keyed Tests.swift:25) —
pre-existing, zero members, amendment-inert.
