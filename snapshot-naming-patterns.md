# Snapshot Naming Patterns: Cross-Ecosystem Analysis

<!--
---
status: complete
date: 2026-03-03
scope: Research into named vs unnamed snapshots, inline vs file-backed storage, and API design across snapshot testing frameworks
frameworks: [swift-snapshot-testing, Jest, Vitest, Insta, cargo-insta, Verify, ApprovalTests.NET, snapshot_testing (Ruby)]
---
-->

## Executive Summary

Every major snapshot testing framework faces the same design tension: auto-derived names reduce ceremony but introduce fragility; explicit names add verbosity but create stable, reviewable artifacts. Frameworks have converged on broadly similar solutions, but differ meaningfully in how they expose the inline/file-backed axis and whether auto-numbering is a first-class or deprecated feature.

Key finding: **no framework that supports both inline and file-backed modes uses auto-numbering for inline snapshots**. Auto-numbering is exclusively a file-backed concern, and even there it is increasingly discouraged.

---

## 1. Point-Free swift-snapshot-testing (Swift)

### File-Backed Snapshots

**Directory structure**: `__Snapshots__/<TestFileName>/<testFunctionName>.<counter>.<extension>`

**API**:
```swift
assertSnapshot(of: value, as: .json)                    // unnamed, counter = 1
assertSnapshot(of: value, as: .json)                    // unnamed, counter = 2
assertSnapshot(of: value, as: .json, named: "specific") // named, no counter
```

**Auto-numbering mechanism**: A per-test static counter increments for each `assertSnapshot` call that lacks a `named:` parameter. The counter is derived from `#function` (which resolves to the test method name) and resets per test method invocation. The file path is constructed from `#file` (source file path), `testName` (`#function`), and the counter.

**Naming parameters**:
- `named: String?` -- optional explicit name; when provided, replaces the counter in the file path
- `file: StaticString = #file` -- source file for directory derivation
- `testName: String = #function` -- test function name

**Known problems**:
- **Counter not resetting across repetitions**: When tests run multiple times in the same XCTest process (Xcode "Run Repeatedly", retry-on-failure), the counter continues incrementing across iterations. On the second iteration, it looks for `testName.2` instead of `testName.1`. This is documented in [issue #693](https://github.com/pointfreeco/swift-snapshot-testing/issues/693).
- **Insertion fragility**: Adding a new `assertSnapshot` call before existing unnamed calls shifts all subsequent counters, invalidating stored snapshots.
- **Named snapshots are immune**: Snapshots using explicit `named:` do not use the counter and are unaffected by these problems.

### Inline Snapshots

**API** (separate module `InlineSnapshotTesting`):
```swift
import InlineSnapshotTesting

assertInlineSnapshot(of: user, as: .json) {
  """
  {
    "id": 42,
    "name": "Blob"
  }
  """
}
```

**Mechanism**: On first run, the library rewrites the test source file to insert a trailing closure containing the snapshot text. Subsequent runs compare against the closure content. The source file is modified in-place using `#file` and `#line` information.

**No auto-numbering**: Inline snapshots are self-contained; each assertion carries its own expected value in the trailing closure. There is no counter or naming concern.

**Mode discrimination**: The inline and file-backed modes live in separate modules (`InlineSnapshotTesting` vs `SnapshotTesting`) with distinct function names (`assertInlineSnapshot` vs `assertSnapshot`). This is the strongest API separation of any framework studied.

---

## 2. Jest (JavaScript) / Vitest

### File-Backed Snapshots

**Directory structure**: `__snapshots__/<testFile>.snap`

**Naming convention**: Each snapshot is stored as an export keyed by test name plus counter:
```javascript
exports[`renders correctly 1`] = `<a href="https://facebook.com">Facebook</a>`;
exports[`renders correctly 2`] = `<a href="https://instagram.com">Instagram</a>`;
```

The key format is `` `<describe block> <test name> <counter>` `` where the counter increments per `toMatchSnapshot()` call within a single test.

**Auto-numbering**: Always present. Even a test with a single snapshot gets counter `1`. There is no API to provide an explicit snapshot name (though a `hint` string can be appended for disambiguation: `toMatchSnapshot('hint')`). The hint does NOT replace the counter -- it is appended alongside it.

**Known problems**:
- **Merge conflicts**: Snapshot files are a frequent source of merge conflicts. The Jest docs acknowledge this and recommend regenerating snapshots rather than manually resolving conflicts.
- **Silent merge breakage**: Two branches updating the same snapshot can merge cleanly but produce broken tests, since the `.snap` file merge appears conflict-free while the actual content is incompatible.
- **Insertion shifting**: Adding a `toMatchSnapshot` call within a test shifts subsequent counters, just as in swift-snapshot-testing.
- **Review fatigue**: Large auto-generated snapshots are frequently approved without review. Kent Dodds identifies this as "probably the biggest cause" of snapshot testing issues.

### Inline Snapshots

**API**:
```javascript
expect(tree).toMatchInlineSnapshot(`
  <a href="https://facebook.com">Facebook</a>
`);
```

On first run (called with no argument), Jest rewrites the source file to insert the snapshot as a template literal argument. Requires Prettier to be installed for formatting.

**No auto-numbering**: Each inline snapshot is self-contained in the source.

**Mode discrimination**: Same `.toMatch*` method family, differentiated by the `Inline` suffix. Both `toMatchSnapshot()` and `toMatchInlineSnapshot()` are matchers on the `expect()` result. The distinction is purely in the method name.

### Vitest Differences

Vitest follows Jest's API exactly (`toMatchSnapshot` / `toMatchInlineSnapshot`) but adds `toMatchFileSnapshot(filepath)` for writing to a specific file path. This is a third mode not present in Jest, giving explicit control over file naming.

---

## 3. Insta / cargo-insta (Rust)

### File-Backed Snapshots

**Directory structure**: `snapshots/<module>__<snapshot_name>.snap`

**Named snapshots**:
```rust
assert_snapshot!("first_snapshot", "first value");
assert_snapshot!("second_snapshot", "second value");
```
Creates `snapshots/<module>__first_snapshot.snap` and `snapshots/<module>__second_snapshot.snap`.

**Unnamed snapshots** (auto-derived):
```rust
#[test]
fn test_something() {
    assert_snapshot!("first value");  // → snapshots/<module>__something.snap
    assert_snapshot!("second value"); // → snapshots/<module>__something-2.snap
}
```

The `test_` prefix is stripped. Subsequent unnamed assertions within the same test append `-2`, `-3`, etc.

**Auto-numbering considered fragile**: The Insta documentation recommends explicit naming "to be more explicit when multiple snapshots are tested within one function." Adding an assertion before existing unnamed ones shifts all subsequent numbers.

**Doctests**: Unnamed snapshots are explicitly disallowed in doctests ([PR #246](https://github.com/mitsuhiko/insta/pull/246)), acknowledging that auto-naming does not work in all contexts.

### Inline Snapshots

**API** (the `@` syntax):
```rust
assert_snapshot!("first value", @"expected output");
```

The `@` prefix on the string literal signals that this is an inline snapshot. On first run (with `@""`), `cargo-insta` rewrites the source file to fill in the expected value.

**No auto-numbering**: Inline snapshots are self-contained.

**Mode discrimination**: Same macro name (`assert_snapshot!`), differentiated by the presence of `@` in the argument list. This is a syntactic distinction within a single API surface.

### cargo-insta Review Workflow

**Pending snapshots**: When a snapshot changes, a `.snap.new` file is created alongside the existing `.snap` file. The `cargo insta review` command presents an interactive diff for each pending change.

**Commands**:
- `a` accept, `r` reject, `s` skip (per-snapshot)
- `A` accept all, `R` reject all, `S` skip all (bulk)
- `d` toggle diff display, `i` toggle auxiliary info

**Inline snapshot review**: Inline snapshots are identified by absolute file path with line number (e.g., `/foo/bar.rs:42`). They are reviewed through the same workflow.

**Non-interactive mode**: `cargo insta review --snapshot <path>` and `cargo insta reject --snapshot <path>` work without a terminal, enabling CI/LLM integration.

---

## 4. Verify (.NET)

### Naming Convention

**File format**: `{TestClassName}.{TestMethodName}_{Parameters}_{UniqueFor}.verified.{extension}`

**Example**: `UserTests.ShouldSerialize.verified.txt`

**No auto-numbering**: Verify does NOT auto-number snapshots. Each test method produces exactly one snapshot file. For multiple verifications within a single test, you must use `UseMethodName("suffix")`:

```csharp
await Verify("value1").UseMethodName("MultipleCalls_1");
await Verify("value2").UseMethodName("MultipleCalls_2");
```

This produces `TestClass.MultipleCalls_1.verified.txt` and `TestClass.MultipleCalls_2.verified.txt`.

**Explicit naming is mandatory for multiple snapshots**: There is no counter. Duplicate names throw an exception.

### Parameterized Tests

For `[Theory]`/`[TestCase]` tests, parameters are appended to the filename:
- `UseParameters(args)` appends parameter values
- `UseParametersAppender` for custom formatting
- `UniqueFor*()` methods add runtime/platform/architecture suffixes

### File Management

- `.received.*` files are generated on test failure (actual output)
- `.verified.*` files are the approved snapshots (committed to source control)
- Files nest under the test in IDE explorers via MSBuild includes

### Inline Mode

Verify does NOT support inline snapshots. All snapshots are file-backed.

---

## 5. ApprovalTests.NET

### Naming Convention

**File format**: `{ClassName}.{MethodName}.{AdditionalInfo}.approved.{extension}`

**Example**: `OrderProcessorTests.ShouldCalculateTotal.approved.txt`

**No auto-numbering**: Like Verify, ApprovalTests uses one file per test method. The `NamerFactory.AdditionalInformation` property allows disambiguation for parameterized tests:

```csharp
NamerFactory.AdditionalInformation = "case_1";
Approvals.Verify(result);
```

**Workflow**: On failure, a diff tool opens showing `.received.txt` vs `.approved.txt`. The developer accepts or rejects the change by copying `.received` over `.approved`.

---

## 6. Ruby (snapshot_testing gem, rspec-snapshot)

### snapshot_testing Gem

**Directory structure**: `__snapshots__/<test_file>.snap` (mirrors Jest)

**API**:
```ruby
# RSpec (auto-named from test description)
expect(value).to match_snapshot

# RSpec (explicitly named)
expect(value).to match_snapshot("hello.txt")

# Minitest (auto-named)
assert_snapshot value

# Minitest (explicitly named)
assert_snapshot "name", value
```

**Auto-naming**: Derived from the test description/method name. The documentation does not describe an auto-numbering mechanism for multiple snapshots within a single test.

**Update mechanism**: `UPDATE_SNAPSHOTS=1` environment variable triggers regeneration.

### rspec-snapshot Gem

**API**: `expect(value).to match_snapshot("snapshot_name")` -- requires explicit naming. Inspired by Jest but does not replicate Jest's auto-numbering.

**No inline mode**: Both Ruby gems are file-backed only.

---

## Comparative Analysis

### Do Any Frameworks Require Explicit Naming for File-Backed Snapshots?

| Framework | Explicit Name Required? | Notes |
|-----------|------------------------|-------|
| swift-snapshot-testing | No | Counter-based auto-naming; `named:` optional |
| Jest / Vitest | No | Always auto-numbered; hint optional but additive |
| Insta | No | Auto-derived from function name; explicit recommended |
| Verify | **Yes** (for multiple per test) | No counter; `UseMethodName` required for disambiguation |
| ApprovalTests | **Yes** (for multiple per test) | No counter; `AdditionalInformation` required |
| Ruby snapshot_testing | No | Auto-derived from test description |

**Verdict**: The .NET ecosystem (Verify, ApprovalTests) is the only one that refuses auto-numbering entirely. All others provide it as a convenience.

### Auto-Numbering Support and Community Sentiment

| Framework | Has Auto-Numbering? | Considered Good Practice? |
|-----------|---------------------|--------------------------|
| swift-snapshot-testing | Yes (`.1`, `.2`) | No -- causes issues with test repetition, insertion fragility |
| Jest | Yes (` 1`, ` 2`) | Tolerated but not praised; source of merge conflicts |
| Insta | Yes (`-2`, `-3`) | Explicitly discouraged for multi-assertion tests |
| Verify | **No** | N/A -- rejected by design |
| ApprovalTests | **No** | N/A -- rejected by design |
| Ruby | Unclear | Not documented |

**Verdict**: No framework considers auto-numbering a best practice. It exists as a convenience for the single-snapshot-per-test case and becomes a liability for multiple snapshots.

### Inline vs File-Backed API Discrimination

| Framework | Discrimination Mechanism |
|-----------|------------------------|
| swift-snapshot-testing | **Separate modules and function names**: `assertSnapshot` (SnapshotTesting) vs `assertInlineSnapshot` (InlineSnapshotTesting) |
| Jest / Vitest | **Method name suffix**: `toMatchSnapshot()` vs `toMatchInlineSnapshot()` |
| Insta | **Syntactic marker**: `assert_snapshot!("val")` (file) vs `assert_snapshot!("val", @"expected")` (inline, `@` prefix) |
| Verify | No inline mode |
| ApprovalTests | No inline mode |
| Ruby | No inline mode |

**Patterns**:
1. **Separate entry points** (swift-snapshot-testing): Strongest separation; impossible to confuse the two modes. Different imports signal different capabilities.
2. **Name suffix** (Jest/Vitest): Moderate separation; same assertion chain, different terminal method.
3. **Syntactic marker** (Insta): Minimal separation; same macro name, mode determined by argument shape (`@` prefix).

### Known Problems with Auto-Numbered Snapshots

1. **Insertion shifting**: Adding a new assertion before existing ones renumbers all subsequent snapshots, breaking the mapping to stored files. Every framework with auto-numbering suffers this.

2. **Counter state leakage**: swift-snapshot-testing's counter does not reset between test repetitions in the same process, causing spurious failures in retry-on-failure and "Run Repeatedly" workflows.

3. **Merge conflicts**: Jest's `.snap` files with numbered entries are frequent merge conflict sites. Two branches modifying different parts of the same component can produce clean merges with broken snapshot keys.

4. **Review opacity**: Auto-numbered names like `renders correctly 1` carry no semantic intent. Reviewers cannot determine what behavior the snapshot validates without reading the test code. This undermines the "treat snapshots as code" best practice.

5. **Orphaned snapshots**: When tests are deleted or refactored, auto-numbered snapshot files may be left behind. Frameworks mitigate this (`--updateSnapshot` in Jest, `--unreferenced=delete` in Insta) but it remains an operational concern.

6. **Non-deterministic ordering**: In frameworks where test discovery order is not guaranteed (or where parallel test execution is used), auto-numbering can produce different assignments across runs. This is theoretical for most frameworks but has been observed in edge cases.

---

## Design Recommendations for New Frameworks

Based on the cross-ecosystem evidence:

1. **Require explicit names for file-backed snapshots** (Verify/ApprovalTests model). The convenience of auto-numbering does not justify the fragility. If auto-naming is supported, derive from the test name for the single-snapshot case but require explicit names when a test has multiple assertions.

2. **Separate inline and file-backed modes at the API level**. swift-snapshot-testing's separate-module approach provides the cleanest separation. At minimum, use distinct function/method names (Jest model). Insta's syntactic-marker approach is clever but opaque to newcomers.

3. **Inline snapshots should be self-contained**. No naming or numbering should be needed -- the expected value lives in the source. This is universally agreed upon.

4. **Provide a review workflow for file-backed snapshots**. cargo-insta's interactive review is the gold standard. Accept/reject/skip with diff display dramatically improves the snapshot update experience over "nuke and regenerate."

5. **Never auto-number inline snapshots**. No framework does this, and for good reason -- the expected value is right there in the code.

---

## Sources

- [Point-Free swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- [swift-snapshot-testing counter issue #693](https://github.com/pointfreeco/swift-snapshot-testing/issues/693)
- [Point-Free Inline Snapshot Testing blog post](https://www.pointfree.co/blog/posts/113-inline-snapshot-testing)
- [Jest Snapshot Testing documentation](https://jestjs.io/docs/snapshot-testing)
- [Vitest Snapshot Guide](https://vitest.dev/guide/snapshot)
- [Insta Snapshot Types documentation](https://insta.rs/docs/snapshot-types/)
- [cargo-insta CLI documentation](https://insta.rs/docs/cli/)
- [Insta unnamed snapshot support PR #27](https://github.com/mitsuhiko/insta/pull/27)
- [Insta disallow unnamed in doctests PR #246](https://github.com/mitsuhiko/insta/pull/246)
- [Verify naming documentation](https://github.com/VerifyTests/Verify/blob/main/docs/naming.md)
- [ApprovalTests.NET](https://github.com/approvals/ApprovalTests.Net)
- [ApprovalTests.cpp Namers documentation](https://github.com/approvals/ApprovalTests.cpp/blob/master/doc/Namers.md)
- [Ruby snapshot_testing gem](https://github.com/rzane/snapshot_testing)
- [rspec-snapshot gem](https://github.com/levinmr/rspec-snapshot)
- [Kent Dodds: Effective Snapshot Testing](https://kentcdodds.com/blog/effective-snapshot-testing)
- [Artem Sapegin: What's wrong with snapshot tests](https://medium.com/@sapegin/whats-wrong-with-snapshot-tests-37fbe20dfe8e)
- [JetBrains: Snapshot Testing in .NET with Verify](https://blog.jetbrains.com/dotnet/2024/07/11/snapshot-testing-in-net-with-verify/)
