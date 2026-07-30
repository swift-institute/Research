# Live GitHub verification — agent-first presence programme ground truth

Verified 2026-07-30, read-only via `gh` (REST GET + GraphQL queries only; zero mutations).
Scope: swift-institute/.github issues #68, #79, #80, #82, #90, #94; ProjectV2 org `swift-institute` number 2; org profile; open-issue overlap scan; issue templates; durable coordinates. Draft under test: an earlier working draft of the synthesis report, superseded and not durably stored.

## 1. Durable coordinates (for downstream draft authoring)

| Entity | Coordinate |
|---|---|
| ProjectV2 "Institute Work" | node `PVT_kwDODzfg4s4BenOf`, org `swift-institute`, number 2, private, open |
| Priority field | `PVTSSF_lADODzfg4s4BenOfzhZLJgE` (SINGLE_SELECT) |
| Status field (exists, doctrine says unset) | `PVTSSF_lADODzfg4s4BenOfzhZAGNQ` |
| #68 | `I_kwDOSDTLes8AAAABKpxhYw` — CLOSED (COMPLETED, 2026-07-30T06:42:16Z), type **Task**, on Project (item `PVTI_lADODzfg4s4BenOfzg0h7rU`), Priority **High** |
| #79 | `I_kwDOSDTLes8AAAABKr-qeA` — OPEN, type **Goal**, on Project (item `PVTI_lADODzfg4s4BenOfzg0kD7E`), Priority **Critical** |
| #80 | `I_kwDOSDTLes8AAAABKsLU1A` — OPEN, type **Task**, on Project (item `PVTI_lADODzfg4s4BenOfzg0kQt4`), Priority **Normal** |
| #82 | `I_kwDOSDTLes8AAAABKsZVWQ` — OPEN, **no issue type**, **NOT on the Project** |
| #90 | `I_kwDOSDTLes8AAAABKsthOw` — OPEN, type **Goal**, on Project (item `PVTI_lADODzfg4s4BenOfzg0ks6w`), Priority **Critical** |
| #94 | `I_kwDOSDTLes8AAAABKthsYQ` — OPEN, type **Goal**, on Project (item `PVTI_lADODzfg4s4BenOfzg0nciA`), Priority **Critical** |

Key comment permalinks (id → URL form `https://github.com/swift-institute/.github/issues/<n>#issuecomment-<id>`):

| Comment | Issue | id | Created |
|---|---|---|---|
| #79 dedicated assessment | 79 | `5122723062` | 2026-07-29T19:44:19Z |
| #79 principal acceptance + activation | 79 | `5122813499` | 2026-07-29T19:55:11Z |
| #82 assessment-before-admission correction | 82 | `5122540856` | (pre-#79-assessment) |
| #68 Project-view sequencing correction | 68 | `5122471427` | — |
| #90 principal acceptance (cure-in-place, activation + admission receipt) | 90 | `5122795614` | 2026-07-29T19:52:49Z |
| #94 pause note ("unassigned, off Project") | 94 | `5123626319` | 2026-07-29T21:37:32Z |
| #94 principal acceptance (accepted as written; paused) | 94 | `5123685873` | 2026-07-29T21:45:11Z |
| #94 Project-admission clarification | 94 | `5126676306` | 2026-07-30T04:53:39Z |
| #94 wave plan + fleet measurement | 94 | `5129689259` | 2026-07-30T10:33:29Z |

Org issue types enabled: `Task`, `Bug`, `Feature`, `Goal` ("A durable Institute-wide observable outcome"). Note: #76's quoted github-skill rule still says "Those three are the org's enabled types; there is no fourth" — that skill text is stale relative to the live Goal type.

## 2. ProjectV2 "Institute Work" (number 2)

- Title: **Institute Work**. Private, open. shortDescription (verbatim): "Authoritative for programme membership and Priority only; the Issue is authoritative for everything else. Doctrine: swift-institute/Skills github skill (github.com/swift-institute/.github/issues/68)."
- Fields: Title, Assignees, **Status** (single-select — exists but doctrine requires it unset; all five inspected rows have no Status value), Labels, Linked pull requests, Milestone, Repository, Reviewers, Parent issue, Sub-issues progress, Created, Updated, Closed, **Priority** (single-select). Priority is confirmed present and populated (Critical on #79/#90/#94, High on #68, Normal on #80).
- Rows confirmed: #68, #79, #80, #90, #94 are items. **#82 is not a row.**

## 3. Issue-by-issue verbatim anchors

### #68 (Task, CLOSED completed) — partitioned authority
Body ratifies the problem ("If two surfaces must be updated independently, neither is a reliable single source of truth") and alternative 2 as leading hypothesis. The ratified partition lives in the Project shortDescription above and downstream doctrine. Comment `5122471427` ("Principal sequencing correction — defer all Project view design") confirms: "Issue state and close reason are completion authority; Project membership and Project-only Priority are programme facts; native hierarchy/progress is evidence only." Also: the Goal issue type "and canonical Goal/gate/topology model are now operational."

### #79 (Goal, OPEN, Critical, activated) — stale-derived content
- Body scope-injection sentence (verbatim, from the **body**, "Activation" section): "The admitted remediation set is the activation findings plus direct replacements, splits, or owner corrections required to resolve them. It is sealed after page-complete triage. **Later unrelated content or policy proposals are new exact-owner work and do not reopen this Goal.**"
- Accepted assessment (comment `5122723062`) parallel language: "Later unrelated content and later policy proposals are new work." and (doctrine section) "Future violations are new `Task`, `Bug`, or `Feature` Issues at the exact owner. **A later broad, finite recurrence would require its own assessment rather than reopening #79.**"
- Assessment also: "The continuing rule against duplicate authority is doctrine and enforcement after closure." Eligible surfaces enumerated: "READMEs and organization profiles, DocC and tutorials, instructions and skills, templates and issue forms, repository and Project descriptions…" Five-disposition semantic-review rule. #80 "should remain an exact-owner `.github` child" and must not merge into #42.
- Acceptance comment `5122813499`: "the dedicated assessment is accepted, and the recommended cure-in-place preserves this Goal's identity… This Goal is now active while open."
- Sub-issues: 13 (12 closed, 1 open = #80). Children include Issues#67, .github#68, Workspace#74, five org-profile "remove hand-maintained coverage inventory" issues, and .github#117.

### #80 (Task, OPEN, Normal, child of #79) — README product-coverage predicate
Verbatim boundary: "This issue owns the product-coverage predicate only. It does not require READMEs to mirror target lists, dependency graphs, or every manifest field." Requires reuse of the Workspace/Swift manifest model, unmeasured-not-clean semantics, and fixtures.

### #82 (untyped, OPEN, off-Project) — Goal-system design
Body is the design task ("Project owns membership and Priority only, with Status unset"). The governing correction is comment `5122540856` (verbatim core): "Before any substantive Goal is admitted, a **dedicated strongest-class assessment must be documented publicly and accepted into the portfolio**. Prepared Goal payloads remain drafts until that acceptance." Note the draft report calls this "the correction about dedicated assessments" — confirmed, and the #79 assessment explicitly says this correction "still governs."

### #90 (Goal, OPEN, Critical, activated) — swift-linter baseline
Content-addressed pattern (verbatim): "The activation rule set is the canonical runner-manifest receipt with digest `89924760b9b292ea2d18118c4c9d99af20e218a59b8538ef420bd6e0712f1483`; the receipt, rather than this body, owns the exact component revisions." Acceptance = comment `5122795614` ("cure #90 in place… This one-time comment is the activation and portfolio-admission receipt"). Active execution: D1–D6 ratified (`5127613230`), next-wave plan (`5129688954`).

### #94 (Goal, OPEN, Critical, admitted but activation paused) — CI-green launch cohort
- The motivating-defect sentence (verbatim, in the body's amended "Assessment disposition" block): "- The Goal is **admitted to Institute Work** (principal admission clarification, 2026-07-30). Per the partitioned-authority model (#68), the Project row — not this body — is authoritative for Priority."
- Amendment/supersession style (verbatim lead-in): "**Amended 2026-07-30** (the original disposition read \"not admitted for execution … unassigned, off Project\"; superseded by the comment record):" — i.e. dated amendment block in the body pointing at the comment record; the superseding comment (`5126676306`) itself says "This supersedes only earlier statements that the Goal is unadmitted or off Project". Note the comment repeats the display name too: "clarified that it should appear on **Institute Work**".
- #90-as-prerequisite (verbatim): "[The swift-linter Goal] … Its accepted result is a prerequisite wherever the canonical CI contract executes swift-linter, not a child objective of this Goal."
- Wave-plan comment `5129689259`: 471 public non-archived package repos measured; 289 success / 155 failure / 23 no-runs / 2 in-progress / 2 skipped; FMT lane 81 repos, BUILD lane 64; "**Filed:** 145 exact-owner Bug issues"; 13 HOLD repos listed; activation "remain[s] paused per the acceptance record."

## 4. Org profile (.github/profile/README.md, blob `6c9c85878647dd2c4aee5d444e116760e58897ad`, 4076 bytes)
Durable scope + curated routing table (Workspace front door, layer orgs, Research, Experiments, CI workflows "pin an immutable SHA"). Residual current-state prose confirmed live, as the draft claims: "RISC-V (pending)", "Public alpha… packages continue to land repository by repository", and the License section: "The public fleet is being reconciled against that policy; until that work is complete, each repository's `LICENSE` file is the authority."

## 5. Overlap scan — does anything already own agent-first authoring?
Open issues in swift-institute/.github (44 open) and org-wide searches for authoring / identifier / README / DocC / documentation / agent-first found **no existing issue owning an agent-first authoring standard, identifier-durability policy, or record grammar**. Nearest neighbors, all with distinct exact scopes:
- #79 (fact-drift removal — the sibling Goal), #80 (product-coverage predicate), #82 (Goal-system design, still open and itself untyped/off-Project).
- **#76 "Issue type is set on 1 of 53 issues, against a documented rule that says always"** (Workspace population) — adjacent record-discipline defect; a new authoring-standard Goal should acknowledge it rather than absorb it; also evidence the github skill text predates the Goal type.
- #104 (Project membership behaviour probes), #114 (Project built-in workflows), #119 (reconciler reporting) — Project-mechanics, not authoring.
- Skills#21 (module-import visibility probe for documentation audits) — instrument, not policy.
- Several open items titled "Goal: …" (#109, #113, #115) are untyped-in-title-only candidates awaiting the #82-correction assessment path — consistent with the assessment-before-admission regime.

## 6. Issue templates (.github/.github/ISSUE_TEMPLATE)
`bug.yml` (type: bug), `change.yml` (type: feature), `documentation.yml` (type: task; fields: Documentation gap / Location link / Proposed correction / Supporting evidence), `config.yml` (blank issues disabled; Discussions for non-actionable work). **No Goal form/template exists in the directory** despite the Goal type being operational — the record grammar currently lives only in prose convention (#79/#90/#94 section grammar), supporting the draft's "embed the record grammar in issue forms" as genuinely unowned work.

## 7. Spot-checks of the draft's README-drift examples (live)
- `swift-standards/swift-rss-standard` README: line "Swift 6.0 Concurrency: Strict concurrency mode…" and `.package(url: …, from: "0.0.4")` — **both present, confirmed**.
- `swift-primitives/swift-comparison-primitives` README: hand-maintained "Four library products plus a Test Support target" product table — **confirmed**.

## 8. Discrepancies / corrections to the first-pass report
1. **Quote attribution (minor but citation-relevant).** The report attributes "later policy proposals are new exact-owner work and do not reopen this Goal" to "#79's accepted assessment". The exact sentence is in the **#79 body**: "Later unrelated content or policy proposals are new exact-owner work and do not reopen this Goal." The assessment's own wording is "Later unrelated content and later policy proposals are new work," plus the recurrence sentence "A later broad, finite recurrence would require its own assessment rather than reopening #79." Downstream drafts should cite the body for the first phrase and comment `5122723062` for the recurrence rule.
2. **Status field exists on the Project.** The partition is "membership + Priority", but a Status single-select field (`PVTSSF_…GNQ`) is live with values unset. Doctrine ("Project owns membership and Priority only, with Status unset") is honored in values, not by field absence. Drafts referencing the partition should say "Status unset", not "no Status field".
3. **#82 is itself non-conformant**: no issue type, not on the Project, though open. Not noted in the report; relevant as evidence for the identifier/record-discipline gap (alongside #76).
4. **Stale skill text**: the github skill (quoted in #76) still says only three issue types exist; the Goal type is live. An agent-first Goal touching doctrine should include this correction path.
5. **Display-name defect is wider than one sentence**: besides #94's body, comment `5126676306` and even #79's acceptance ecosystem use "Institute Work" bare. Draft C's micro-fix targets the body sentence; the durable-coordinate gloss pattern should also be prescribed for future comments. The Project shortDescription itself references the github skill and #68 by display/URL — an acceptable authority pointer.
6. Everything else the report asserts about live state checks out: #79 OPEN/Goal/Critical/activated; #90/#94 content-addressed receipt language verbatim as characterized; #94 admitted-with-pause with Priority owned by the Project row (Critical); #80 exact ownership; #68 closed completed with view-design deferred; 145 filed wave issues; README drift examples live; no pre-existing owner for the agent-first standard.

## 9. Confirmation of the report's disposition inputs
- New-Goal-not-#79-expansion is supported by live text: #79 body's sealed-remediation-set sentence, the assessment's recurrence-requires-own-assessment sentence, and the #82 correction requiring a dedicated accepted assessment before admission.
- Precedent for consume-not-absorb is live in #94 ("prerequisite … not a child objective").
- The activation grammar a new Goal must follow is live in #90/#94: "Opening activates this Goal only after its dedicated assessment is accepted" (#90) and #94's paused-admission pattern; acceptance/admission arrive as dated principal comments, Priority set only on the Project row.
