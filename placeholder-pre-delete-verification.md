# Placeholder Pre-Delete Verification Protocol

| Field | Value |
|-------|-------|
| Tier | 2 |
| Scope | GitHub repo lifecycle (destructive-action safety) |
| Status | IN_PROGRESS |
| Provenance | 2026-04-22-heritage-transfers-investigation-and-placeholder-verification-gap.md |

## Context

During an ecosystem transfer investigation, `swift-foundations/swift-testing` was casually labeled a "placeholder" repo and queued for `gh repo delete`. Subsequent inspection surfaced two substantive commits (macro fixes + XCTest bridge removal) that would have been lost by the delete. The "placeholder" label was a visual judgment, not a verified classification.

~9 placeholder deletes currently sit in the html-tree transfer checklist, none of whose contents have been verified.

## Question

What verification protocol separates safe-to-delete placeholders from repos with non-scaffold content?

## Proposed Protocol

For each candidate repo, run ALL of:

1. **Commit log scan for non-scaffold tokens**:

   ```bash
   gh api repos/<org>/<repo>/commits --paginate \
     | jq -r '.[].commit.message' \
     | grep -cE "^(Fix|Remove|Add [^s]|Implement|Refactor|Deprecate)"
   # Count > 0 → NOT a placeholder; flag for user decision.
   ```

2. **Non-empty Sources/ tree check**:

   ```bash
   gh api repos/<org>/<repo>/contents/Sources?ref=main 2>/dev/null | jq '. | length'
   # Count > 0 → investigate contents.
   ```

3. **Tag enumeration**:

   ```bash
   gh api repos/<org>/<repo>/git/refs/tags 2>/dev/null | jq '. | length'
   # Count > 0 → a release exists; NOT a placeholder.
   ```

4. **Issues / PRs enumeration**:

   ```bash
   gh issue list --repo <org>/<repo> --state all --json number | jq '. | length'
   gh pr list --repo <org>/<repo> --state all --json number | jq '. | length'
   # Count > 0 → conversation happened; investigate.
   ```

**Decision**: safe-to-delete ONLY if all four checks return 0. Any non-zero signal routes to flag-for-user-decision with the specific signal cited.

## Application

The 9 html-tree transfer placeholders need this protocol applied before any of them are deleted. Output: a verified classification per repo; user confirms each safe-to-delete decision.

## References

- Reflections: 2026-04-22-heritage-transfers-investigation-and-placeholder-verification-gap.md
- handoff skill [HANDOFF-025] Anti-Defer Rule for Cheap Verifications
