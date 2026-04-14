# PR Submission Research: swiftlang/swift

**Date**: 2026-03-22
**Status**: Complete
**Purpose**: Research how to submit a PR to `swiftlang/swift` from the `coenttb` GitHub account.

---

## 1. Fork vs Direct Push

**Answer: You must fork first.** No fork currently exists for `coenttb`.

The local clone has only the upstream remote:
```
origin  https://github.com/swiftlang/swift.git (fetch/push)
```

Running `gh repo view coenttb/swift` confirms: **"No fork exists"**.

The official [GettingStarted.md](/docs/HowToGuides/GettingStarted.md) is explicit (lines 345-367):

> If you are building the toolchain for development and submitting patches, you will need to setup a GitHub fork.
>
> First fork the `swiftlang/swift` repository, using the "Fork" button in the web UI. This will create a repository `username/swift`. Next, add it as a remote:
> ```sh
> git remote add my-remote git@github.com:username/swift.git
> ```
> Finally, create a new branch.
> ```sh
> git checkout -b my-branch
> git push --set-upstream my-remote my-branch
> ```

**Action required**:
```sh
# Fork via GitHub UI or:
gh repo fork swiftlang/swift --clone=false

# Then add as remote:
git remote add coenttb https://github.com/coenttb/swift.git
```

Only users with **commit access** (granted after 5 accepted non-trivial PRs) can push directly to `swiftlang/swift`.

---

## 2. Branch Naming Convention

**Answer: No enforced convention.** Contributors use ad-hoc, descriptive branch names.

Evidence from the 10 most recent merged PRs:

| Branch Name | Author |
|---|---|
| `add-tests` | hamishknight |
| `fix-embedded-swift-build` | tshortli |
| `63-ordering` | compnerd |
| `don't-mock-cgfloat` | slavapestov |
| `pretty-stack-top-level-silgen` | kavon |
| `mergebc` | meg-gupta |
| `owenv/benchpath` | owenv |
| `just-func-type-lifetimes-try-print` | aidan-hall |
| `mandatory-temprvalue-elimination` | eeckstein |

Patterns observed:
- Short descriptive slugs: `add-tests`, `fix-embedded-swift-build`
- Some use `username/description`: `owenv/benchpath`
- No prefix convention like `feature/` or `fix/`

**Recommendation**: Use a descriptive kebab-case name. Something like `siloptimizer-mark-dependence-fix` would fit the observed patterns.

---

## 3. Target Branch

**Answer: PRs go to `main` for new work.** Release branches (`release/x.y`) have a separate, stricter process.

From CONTRIBUTING.md (lines 217-234):

> A pull request targeting a release branch (`release/x.y` or `swift/release/x.y`) cannot be merged without a GitHub approval by a corresponding branch manager. In order for a change to be considered for inclusion in a release branch, the pull request must have:
> - A title starting with a designation containing the release version number
> - The release template form filled out

For normal contributions: **target `main`**.

---

## 4. PR Template

**Answer: There is no default PR template file in the swift repo itself**, but the PR body contains HTML comment guidance that appears when you open a PR.

The PR body from actual merged PRs (e.g., #86602, #86842) contains this template via GitHub's org-level configuration:

```html
<!--
If this pull request is targeting a release branch, please fill out the
following form:
https://github.com/swiftlang/.github/blob/main/PULL_REQUEST_TEMPLATE/release.md?plain=1

Otherwise, replace this comment with a description of your changes and
rationale. Provide links to external references/discussions if appropriate.
If this pull request resolves any GitHub issues, link them like so:

  Resolves <link to issue>, resolves <link to another issue>.

For more information about linking a pull request to an issue, see:
https://docs.github.com/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue
-->

<!--
Before merging this pull request, you must run the Swift continuous integration tests.
For information about triggering CI builds via @swift-ci, see:
https://github.com/apple/swift/blob/main/docs/ContinuousIntegration.md#swift-ci

Thank you for your contribution to Swift!
-->
```

**What goes in the PR body** (based on merged PRs):
- A clear description of the change and rationale
- Links to related issues or prior PRs if applicable
- `rdar://` references if relevant (Apple contributors use these)
- `Resolves #NNN` links to close GitHub issues

**Release branch template** (from `swiftlang/.github/PULL_REQUEST_TEMPLATE/release.md`):

```markdown
- **Explanation**: (description of changes)
- **Scope**: (impact assessment, can it break existing code?)
- **Issues**: (references to issues)
- **Original PRs**: (links to mainline PRs)
- **Risk**: (specific risk to the release)
- **Testing**: (specific testing done or needed)
- **Reviewers**: (code owners who approved the original changes)
```

This release template is **only for release branch PRs**, not for `main`.

---

## 5. Testing Expectations

### CI System

**Answer: CI is triggered by `@swift-ci` comments.** Contributors without commit access cannot trigger CI themselves -- they must ask a reviewer.

From [ContinuousIntegration.md](/docs/ContinuousIntegration.md) and [FirstPullRequest.md](/docs/HowToGuides/FirstPullRequest.md):

> Contributors without write access are not able to run the continuous integration (CI) bot. Please ask a code reviewer with write access to invoke the bot for you.

**CI trigger commands** (run by a reviewer with commit access):

| Scope | Comment |
|---|---|
| All platforms (smoke) | `@swift-ci Please smoke test` |
| All platforms (full) | `@swift-ci Please test` |
| macOS only (smoke) | `@swift-ci Please smoke test macOS platform` |
| Linux only (smoke) | `@swift-ci Please smoke test Linux platform` |
| macOS only (full) | `@swift-ci Please test macOS platform` |
| Benchmarks | `@swift-ci Please benchmark` |

**Smoke test** builds Swift + stdlib and runs `test` + `validation-test` for one platform.
**Validation test** does a clean build, builds for all platforms + simulators, runs optimized and non-optimized tests.

### Local Testing

From CONTRIBUTING.md (lines 182-203):

> Developers are required to create test cases for any bugs fixed and any new features added.
> - All test cases go in the appropriate test directory (e.g., `swift/test`)
> - Write test cases at the abstraction level nearest to the actual feature (SIL optimization -> write in SIL)
> - Reduce test cases as much as possible

**Recommendation**: Run relevant tests locally before submitting:
```sh
# Run specific SILOptimizer tests
llvm-lit -sv test/SILOptimizer/your_test.sil
```

---

## 6. Commit Message Format

**Answer: Tag prefix in square brackets, concise subject, optional body.**

From CONTRIBUTING.md (lines 77-96):

> - Separate the commit message into a single-line title and a separate body
> - Make the title concise to be easily read within a commit log
> - In changes restricted to a specific part of the code, include a **[tag]** at the start in square brackets -- for example, `[stdlib] ...` or `[SILGen] ...`
> - When there is a body, separate it from the title by an empty line
> - If the commit fixes an issue, include a link to the issue

**Observed patterns from recent commits**:

```
[test] Test more cases in `unbound_base.swift`
[Sema] NFC: Use `defaultUnboundTypeOpener` in more places
IRGen: Force VWT-based destruction for ~Copyable types with @_rawLayout fields
AST: Introduce JoinType and MeetType singletons
Embedded: Fix typos in EmbeddedRuntime.swift.
SILGen: add PrettyStackTraceDecl at top-level decl visitor
```

**Notable conventions**:
- `NFC:` prefix means "No Functional Change" (refactoring only)
- Tags are either `[Component]` or `Component:` -- both are used
- Some use backticks for code identifiers in the subject line

**For a SIL optimizer change**, use:
```
[SILOptimizer] Brief description of the change
```
or:
```
SILCombine: Brief description of the change
```

---

## 7. CLA / Contributor Requirements

**Answer: No CLA or DCO is required.** The swift.org contributing page and CONTRIBUTING.md do not mention any contributor license agreement or Developer Certificate of Origin sign-off.

The project uses the Apache License v2.0 with Runtime Library Exception. Contributors implicitly license their contributions under this license by submitting a PR.

**Required for new source files**: Include the standard header:
```swift
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
```

(Update the year to `2026` for new files.)

---

## 8. Review Process for SIL Optimizer Changes

### Automatic Review Assignment

From [FirstPullRequest.md](/docs/HowToGuides/FirstPullRequest.md) (line 139):

> Reviews are automatically requested from code owners per the CODEOWNERS file upon opening a non-draft pull request.

### CODEOWNERS for SIL Optimizer

From `.github/CODEOWNERS`:

| Path | Owner(s) |
|---|---|
| `/include/swift/SILOptimizer/` | **@eeckstein** |
| `/lib/SILOptimizer/` | **@eeckstein** |
| `/test/SILOptimizer/` | **@eeckstein** |
| `/validation-test/SILOptimizer/` | **@eeckstein** |
| `/SwiftCompilerSources` | **@eeckstein** |
| `/lib/SILOptimizer/Mandatory/MoveOnly*` | @kavon |
| `/lib/SILOptimizer/Mandatory/AddressLowering*` | @kavon |
| `/lib/SILOptimizer/Mandatory/ConsumeOperator*` | @kavon |
| `/lib/SILOptimizer/Utils/Distributed*` | @ktoso |
| `/include/swift/SIL/` | **@jckarter** |
| `/lib/SIL/` | **@jckarter** |
| `/lib/SILGen/` | @jckarter @kavon |

### Who Actually Reviews SIL Optimizer PRs (Empirical)

Based on examination of 6 recent merged SIL optimizer / mark_dependence PRs:

| PR | Author | Reviewers / Approvers |
|---|---|---|
| #87279 (SILCombine: don't sink mark_dependence) | eeckstein | **meg-gupta** (approved), atrick (requested) |
| #86602 (OptimizeDeadAlloc: Handle MarkDependenceAddrInst) | aidan-hall | **meg-gupta** (approved), atrick/eeckstein/elsakeirouz (requested) |
| #86644 (OSSA lifetimes throughout pipeline) | eeckstein | meg-gupta, asl (commented), kavon/jckarter/atrick/aidan-hall (requested) |
| #87819 (Hoist bounds checks) | meg-gupta | **eeckstein** (approved then changes then approved), atrick/jckarter (requested) |
| #81706 (InlineArray Onone perf) | eeckstein | **nate-chandler** (approved), **atrick** (commented LGTM), jckarter/meg-gupta (requested) |
| #86842 (LifetimeDependence function types) | aidan-hall | **meg-gupta** (approved), slavapestov/hamishknight/Xazax-hun (commented) |

**Key reviewers for SIL optimizer changes**:

| Person | GitHub | Role |
|---|---|---|
| Erik Eckstein | **@eeckstein** | CODEOWNER for SILOptimizer. Primary reviewer for all SIL optimizer work. |
| Meghana Gupta | **@meg-gupta** | Very active reviewer/approver for SIL optimizer and lifetime/dependence PRs. |
| Andrew Trick | **@atrick** | Frequently requested reviewer for SIL optimizer work. |
| Joe Groff | **@jckarter** | CODEOWNER for SIL/SILGen. Requested on cross-cutting SIL changes. |
| Kavon Farvardin | **@kavon** | Owns move-only / address lowering optimizer passes. |

**For a mark_dependence / lifetime_dependence SIL optimizer PR, the likely reviewers are**:
1. **@eeckstein** (auto-assigned via CODEOWNERS)
2. **@meg-gupta** (actively reviews lifetime/dependence changes)
3. **@atrick** (frequently requested on these PRs)

---

## Summary: Submission Checklist

1. **Fork**: `gh repo fork swiftlang/swift --clone=false`, then add remote
2. **Branch**: Create descriptive branch, push to your fork
3. **Target**: PR against `main`
4. **PR body**: Replace the HTML comment template with a description of the change and rationale
5. **Commit messages**: `[SILOptimizer] Description` format with a concise subject
6. **Tests**: Include SIL-level test cases in `test/SILOptimizer/`
7. **No CLA needed**: Just submit the PR
8. **CI**: Ask reviewer to run `@swift-ci Please smoke test` (you cannot trigger CI yourself without commit access)
9. **Reviewers**: @eeckstein will be auto-assigned; consider mentioning @meg-gupta and @atrick

---

## Sources Consulted

- `https://github.com/swiftlang/swift/blob/main/CONTRIBUTING.md`
- `https://github.com/swiftlang/swift/blob/main/docs/HowToGuides/FirstPullRequest.md`
- `https://github.com/swiftlang/swift/blob/main/docs/HowToGuides/GettingStarted.md` (lines 345-367)
- `https://github.com/swiftlang/swift/blob/main/docs/ContinuousIntegration.md`
- `https://github.com/swiftlang/swift/tree/main/.github/CODEOWNERS`
- `https://www.swift.org/contributing/`
- `swiftlang/.github/PULL_REQUEST_TEMPLATE/release.md` (via GitHub API)
- `git log --oneline -40` on local `swiftlang/swift` checkout
- `gh pr view` for PRs: #87279, #86602, #86644, #87819, #81706, #86842
- `gh pr list --repo swiftlang/swift --state merged` with various search filters
- `gh repo view coenttb/swift` (confirmed no fork exists)
- `git remote -v` (confirmed only upstream origin)
