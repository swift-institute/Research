---
title: "Test Output Quality: Parity with Apple and Beyond"
version: 1.0.0
status: DECISION
last_updated: 2026-03-03
---

# Test Output Quality: Parity with Apple and Beyond

<!--
---
tier: 2
version: 1.0.0
status: DECISION
created: 2026-03-03
packages: [swift-tests, swift-testing, swift-test-primitives, swift-console]
skills: [testing, design, implementation]
---
-->

## Context

When running `swift test` in a package that uses the Institute's `swift-testing` (which provides the `Testing.__swiftPMEntryPoint` and installs the Institute's `Test.Runner`), failure output is significantly less informative than Apple's native Swift Testing runner. A snapshot test failure currently shows:

```
  ▶ AtRuleSnapshotTests
    ✗ assertInlineSnapshot(of: ..., as: ...)
      Inline snapshot does not match.
      1 line removed, 1 line added
  ✗ `AtRule media snapshot - mixed media queries` (3.898834 ms)
```

Under Apple's native runner, the equivalent failure shows:

```
◇ Test "AtRule media snapshot - mixed media queries" started.
✘ Test "AtRule media snapshot - mixed media queries" recorded an issue
    at AtRuleSnapshotTests.swift:42:5
    Inline snapshot does not match.
    1 line removed, 1 line added

    -old line
    +new line
```

Apple's output is superior in several ways: source location, colored diff in terminal, and a unified diff body. The Institute's infrastructure already captures all of this data (source locations in `Source.Location`, styled diffs in `Test.Text` with semantic segment styles, expected/actual values in `Test.Expectation.Failure`), but the console reporter discards most of it.

## Question

How should the Institute's test output achieve parity with — and then surpass — Apple's Swift Testing failure output, while leveraging the existing `Test.Text` styling infrastructure and structured `Test.Expectation.Failure` type?

---

## Root Cause Analysis

### Finding 1: Console Reporter Discards Styling

The console reporter at `swift-testing/Sources/Testing/Testing.Reporter.Console.swift:89-95` handles failures:

```swift
case .expectationChecked(let expectation):
    if expectation.isFailing {
        print("    ✗ \(expectation.expression.sourceCode)")
        if let failure = expectation.failure {
            print("      \(failure.message.plainText)")
        }
    }
```

**Problems:**
1. Calls `.plainText` on `failure.message`, discarding all `Test.Text.Segment.Style` information (`.diffAdded`, `.diffRemoved`, `.diffContext`, etc.)
2. Does not render `failure.expected` or `failure.actual` — these fields are captured but never displayed
3. Does not render `failure.difference` — the structured diff `Test.Text` is ignored
4. Does not show source location (`expectation.expression.sourceLocation`)
5. Does not show `failure.comment` — user-provided comments are lost

### Finding 2: Failure Message Embeds Diff as Plain String

Snapshot assertions construct failure messages by string-concatenating the diff:

`swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift:511-517`:
```swift
if let diff = strategy.diffing.diff(expectedValue, actual) {
    var message = "Inline snapshot does not match.\n"
    message += diff.summary
    if let unifiedDiff = diff.unifiedDiff {
        message += "\n\n\(unifiedDiff)"    // Test.Text → String via interpolation
    }
    return message
}
```

The `diff.unifiedDiff` is a `Test.Text` with rich semantic segments (`.diffAdded`, `.diffRemoved`, `.diffContext`). Interpolating it into a `String` calls `.plainText`, losing all styling. The diff data IS captured — it's just thrown away at message construction time.

### Finding 3: Source Code is a Static Placeholder

`swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift:579-583`:
```swift
private func makeInlineFailingExpectation(...) -> Test.Expectation {
    .record(
        failing: message,
        sourceCode: "assertInlineSnapshot(of: ..., as: ...)",   // ← static string
        at: Source.Location(...)
    )
}
```

The `sourceCode` is always `"assertInlineSnapshot(of: ..., as: ...)"` — a hardcoded placeholder. Compare with Apple's `#expect(a == b)` macro, which captures `"a == b"` as source text via macro expansion.

### Finding 4: No Source Location in Output

`Test.Expression` stores `sourceLocation: Source.Location` with `fileID`, `filePath`, `line`, `column`. The console reporter never prints this. Apple always shows `at File.swift:42:5`.

### Finding 5: No ANSI Color

The `Test.Text.Segment.Style` enum has 13 semantic styles including `.diffAdded`, `.diffRemoved`, `.success`, `.failure`. The console reporter ignores all of them. A terminal-aware renderer could map these to ANSI escape codes for colored diff output.

---

## Data Already Captured

The primitives types already carry everything needed for rich output. Nothing new needs to be invented at the type level.

| Data | Type | Location | Currently displayed? |
|------|------|----------|:---:|
| Failure message | `Test.Text` (styled) | `Failure.message` | Partially (plainText only) |
| Expected value | `Test.Expression.Value` | `Failure.expected` | **No** |
| Actual value | `Test.Expression.Value` | `Failure.actual` | **No** |
| Structured diff | `Test.Text` (styled) | `Failure.difference` | **No** |
| User comment | `Test.Text` | `Failure.comment` | **No** |
| Source location | `Source.Location` | `Expression.sourceLocation` | **No** |
| Source code | `String` | `Expression.sourceCode` | Yes (but static placeholder) |
| Captured values | `[Test.Expression.Value]` | `Expression.values` | **No** |
| Diff segments | `.diffAdded/.diffRemoved/.diffContext` | `Test.Text.Segment.Style` | **No** (discarded via `.plainText`) |

---

## Improvement Analysis

### Improvement 1: Render Source Location

**Effort**: Trivial
**Impact**: High (parity with Apple)

Add source location to expectation output:

```swift
case .expectationChecked(let expectation):
    if expectation.isFailing {
        let loc = expectation.expression.sourceLocation
        print("    ✗ \(expectation.expression.sourceCode)")
        print("      at \(loc.fileID):\(loc.line):\(loc.column)")
        // ... failure details
    }
```

Output:
```
    ✗ assertInlineSnapshot(of: ..., as: ...)
      at HTMLRenderingTests/AtRuleSnapshotTests.swift:42:5
```

### Improvement 2: Render Expected vs Actual

**Effort**: Trivial
**Impact**: High (parity with Apple for equality assertions)

Show `failure.expected` and `failure.actual` when present:

```swift
if let expected = failure.expected, let actual = failure.actual {
    print("      expected: \(expected.stringValue)")
    print("      actual:   \(actual.stringValue)")
}
```

Output:
```
    ✗ lhs == rhs
      at Tests/UserTests.swift:15:5
      Values are not equal
      expected: 42
      actual:   41
```

### Improvement 3: Styled Output via swift-console

**Effort**: Low (mapping function + dependency wire-up)
**Impact**: High (exceeds Apple — semantic color palette, capability-aware)

The ecosystem already has `swift-console` (Layer 3), which provides:

- **`Console.Capability.detect(stream: .stdout)`** — handles TTY detection, `NO_COLOR`, `FORCE_COLOR`, CI environments (GitHub Actions, GitLab CI), `COLORTERM`/`TERM` inspection, with graceful degradation from trueColor → palette8 → palette4 → none
- **`Console.Style`** — predefined styles (`.error` red+bold, `.warning` yellow, `.success` green, `.info` blue, `.bold`, `.dim`) plus custom styles via `init(foreground:background:attributes:)`
- **`Console.Style.apply(to: String, capability: Console.Capability) -> String`** — wraps text with capability-appropriate ANSI sequences, returns plain text when capability is `.none`
- **`ECMA_48.SGR.Color`** — `.palette(Palette)`, `.extended(UInt8)`, `.rgb(r:g:b)` with automatic downgrading

`swift-tests` already depends on `swift-console` (via `Tests Performance`). `swift-testing` does not — adding it as a dependency to `Testing Core` wires the reporter to real terminal infrastructure instead of ad-hoc `print()`.

**Mapping `Test.Text.Segment.Style` → `Console.Style`:**

```swift
private func consoleStyle(for style: Test.Text.Segment.Style) -> Console.Style {
    switch style {
    case .plain:        .plain
    case .diffAdded:    Console.Style(foreground: .palette(.green))
    case .diffRemoved:  Console.Style(foreground: .palette(.red))
    case .diffContext:  .dim
    case .success:      .success
    case .failure:      .error
    case .warning:      .warning
    case .emphasis:     .bold
    case .secondary:    .dim
    case .identifier:   Console.Style(foreground: .palette(.cyan))
    case .value:        Console.Style(foreground: .palette(.yellow))
    case .keyword:      Console.Style(foreground: .palette(.magenta))
    case .punctuation:  .plain
    }
}
```

**Rendering a `Test.Text` with capability:**

```swift
private func render(_ text: Test.Text, capability: Console.Capability) -> String {
    text.segments.map { segment in
        consoleStyle(for: segment.style)
            .apply(to: segment.content, capability: capability)
    }.joined()
}
```

This is ~20 lines in the console reporter. All TTY detection, color space conversion, and `NO_COLOR` handling come from `swift-console` for free.

**Where this lives**: Private in the `ConsoleSink` implementation at `Testing.Reporter.Console.swift`. The `ConsoleSink` detects capability once at init time (`Console.Capability.detect(stream: .stdout)`) and uses it for all subsequent rendering.

**Optional improvement to swift-console**: If the `Test.Text.Segment.Style` → `Console.Style` mapping proves useful beyond test output (e.g., for CLI tools that use `Test.Text` as a general styled-text type), the mapping could be promoted to a `Console` extension. But for now, keeping it private in the reporter follows the minimal-change principle.

### Improvement 4: Render Structured Diff

**Effort**: Trivial (data is already there)
**Impact**: Very high (exceeds Apple for snapshot tests)

Instead of embedding the diff as plain text in `failure.message`, use `failure.difference` and render it with ANSI colors:

```swift
if let difference = failure.difference {
    // Render with colors
    print(difference.renderANSI().split(separator: "\n")
        .map { "      \($0)" }.joined(separator: "\n"))
}
```

This requires a change to how snapshot assertions construct failures. Currently, the diff is string-concatenated into the message. Instead, the diff should be passed as the `difference` field of `Test.Expectation.Failure`.

**Required change** in `Test.Snapshot.assert.swift` and `Test.Snapshot.Inline.assert.swift`: construct `Failure` with the `difference` field populated, rather than embedding the diff text into the message string.

### Improvement 5: Pass Structured Diff Through Failure

**Effort**: Moderate (touches assertion functions)
**Impact**: Enables Improvement 4

Currently, `makeFailingExpectation` and `makeInlineFailingExpectation` call `Test.Expectation.record(failing:sourceCode:at:)` which creates `Failure(message: ...)` with only the message field. The diff data is lost.

**Option A: Expand `record(failing:...)` signature**

Add a new `record(failing:...)` overload that accepts structured failure data:

```swift
@discardableResult
public static func record(
    failing message: Swift.String,
    expected: Test.Expression.Value? = nil,
    actual: Test.Expression.Value? = nil,
    difference: Test.Text? = nil,
    sourceCode: Swift.String,
    at location: Source.Location
) -> Self
```

**Option B: Accept `Failure` directly**

```swift
@discardableResult
public static func record(
    failure: Failure,
    sourceCode: Swift.String,
    at location: Source.Location
) -> Self
```

**Recommendation**: Option B. The `Failure` struct already exists with the right shape. No need to flatten its fields into parameters.

### Improvement 6: Better Source Code Capture

**Effort**: Varies by approach
**Impact**: Moderate (parity with Apple)

| Approach | Effort | Quality |
|----------|--------|---------|
| Show test name + assertion function name | Trivial | Adequate |
| Include the value being snapshotted | Low | Good |
| Macro-based expression capture | High | Best (Apple-level) |

The expression decomposition research at `Research/expression-decomposition-implementation.md` already covers macro-based capture for `#expect`. For snapshot assertions, the practical minimum is to include meaningful information instead of the static placeholder:

```swift
sourceCode: "assertInlineSnapshot(of: \(Swift.String(describing: type(of: value))), as: .\(strategyName))"
```

This is a small change in each assertion function (pass `Value.Type` and strategy name through). It won't match Apple's macro decomposition, but it replaces a useless placeholder with actionable information.

### Improvement 7: Multiline Diff Indentation

**Effort**: Trivial
**Impact**: Moderate (readability)

When printing multiline failure messages, each line must be properly indented to align with the error context. Currently, raw `print()` dumps multiline strings without indentation:

```
    ✗ assertInlineSnapshot(of: ..., as: ...)
      Inline snapshot does not match.
1 line removed, 1 line added      ← no indentation

-old line                          ← no indentation
+new line                          ← no indentation
```

Fix: split multiline output on `\n` and prefix each line with the indentation.

---

## Proposed Console Output Format

Combining all improvements, a failing inline snapshot test would produce:

```
  ▶ AtRuleSnapshotTests
    ✗ assertInlineSnapshot(of: AtRule, as: .lines)
      at HTMLRenderingTests/AtRuleSnapshotTests.swift:42:5
      Inline snapshot does not match. 1 line removed, 1 line added.

      @@ -1,3 +1,3 @@
       context line
      -old line
      +new line
       context line

  ✗ `AtRule media snapshot - mixed media queries` (3.898 ms)
```

Where `-old line` is red, `+new line` is green, and context is gray.

For equality assertions:

```
    ✗ user.age >= 18
      at Tests/UserTests.swift:15:5
      Expectation failed
      expected: true
      actual:   false
```

---

## Phased Implementation

### Phase 1: Console Reporter via swift-console (Parity) — 2 files

**File 1**: `swift-testing/Package.swift`
- Add `swift-console` package dependency
- Add `.product(name: "Console", package: "swift-console")` to `Testing Core` target

**File 2**: `swift-testing/Sources/Testing/Testing.Reporter.Console.swift`
- Import `Console`
- Store `Console.Capability` in `ConsoleSink` (detected once at init)
- Add private `Test.Text.Segment.Style` → `Console.Style` mapping (~15 lines)
- Add private `render(_ text: Test.Text, capability:) -> String` helper (~5 lines)
- Print source location after source code
- Print `failure.expected` / `failure.actual` when present
- Print `failure.difference` rendered with `Console.Style` when present
- Print `failure.comment` when present
- Indent multiline output properly

**Scope**: ~60 lines changed in reporter, dependency wire-up. No API changes. No primitives changes. Immediate improvement for all existing tests. TTY detection, `NO_COLOR`, `FORCE_COLOR`, CI environments all handled by `Console.Capability.detect()`.

### Phase 2: Structured Diff Passthrough — 2-3 files

**Files**:
- `swift-tests/Sources/Tests Core/Test.Expectation+Factory.swift` — add `record(failure:sourceCode:at:)` overload
- `swift-tests/Sources/Tests Snapshot/Test.Snapshot.assert.swift` — pass `DiffResult` as `Failure.difference`
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift` — same

This separates the diff summary (in `message`) from the styled diff body (in `difference`), allowing the reporter to render them with appropriate styling. Currently the styled `Test.Text` diff is flattened to plain string at assertion time — Phase 2 preserves it through to the reporter.

### Phase 3: Better Source Code — 2 files

**Files**:
- `swift-tests/Sources/Tests Snapshot/Test.Snapshot.assert.swift` — include `Value.Type` in sourceCode
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift` — same

Low-effort improvement that replaces static placeholders with type-aware descriptions.

### Phase 4: Expression Decomposition (Beyond Apple) — separate research

Already covered by `Research/expression-decomposition-implementation.md`. This is a larger effort involving macro expansion changes in `swift-testing/Sources/Testing Macros Implementation/`.

---

## Comparison: After Phase 1-3

| Feature | Apple (current) | Institute (current) | Institute (after Phase 1-3) |
|---------|:---:|:---:|:---:|
| Source location | Yes | **No** | Yes |
| Colored terminal output | Yes | **No** | Yes (13 semantic styles) |
| Colored diffs | Yes | **No** | Yes (hunk-based unified) |
| Expected vs actual | Yes | **No** | Yes |
| User comments | Yes | **No** | Yes |
| Expression capture | Yes (macro) | **No** (static placeholder) | Partial (type + strategy) |
| Structured JSON diff | No | Available (not rendered) | **Yes** |
| Diff context lines | Configurable | Available (not rendered) | **Yes** |
| CI attachments | Via Attachments API | Available (not rendered) | Yes |
| Semantic text styles | No | 13 styles (unused) | **Yes** (ANSI-rendered) |
| Test.Text extensibility | No | Reporter-pluggable | **Yes** |

**After Phase 1-3**: Parity on all Apple features, exceeding Apple on structural diffs, semantic styling, and extensibility.

---

## Open Questions

1. **TTY / NO_COLOR / FORCE_COLOR**: Resolved. `Console.Capability.detect(stream: .stdout)` handles all of this: `isatty` check, `NO_COLOR` (https://no-color.org), `FORCE_COLOR`, CI environment detection (GitHub Actions, GitLab CI), `COLORTERM`/`TERM` parsing. No ad-hoc code needed.

2. **Diff context lines**: The `styledDiff` function takes a `contextLines` parameter (default 3). Should the console reporter respect a configuration for this, or is 3 always sufficient?

3. **Performance test output**: Performance test failures have their own formatting concerns (baseline comparison, trend data). Should the console reporter handle `Test.Event.Kind.custom` events for performance diagnostics?

4. **JSON reporter**: The JSON reporter (`Testing.Reporter.json`) should also benefit from structured diff data. Should it emit styled segments as JSON objects?

5. **Console.write for Test.Text**: Should `swift-console` gain a general `Console.write(_ text: Test.Text, to: Terminal.Stream, capability: Console.Capability)` method? This would couple Console to Test_Primitives. Alternative: a protocol-based abstraction (`Console.StyledText`) that `Test.Text` could conform to. For now, the private mapping in the reporter is sufficient — promote only if the pattern repeats.

---

## References

- `swift-testing/Sources/Testing/Testing.Reporter.Console.swift` — Current console reporter
- `swift-testing/Package.swift` — Testing Core dependencies (needs Console)
- `swift-tests/Sources/Tests Core/Test.Expectation+Factory.swift` — Failure recording path
- `swift-tests/Sources/Tests Snapshot/Test.Snapshot.assert.swift:714-738` — `resultToFailureMessage()`
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift:511-517` — Inline diff message
- `swift-primitives/swift-test-primitives/Sources/Test Primitives Core/Test.Expectation.Failure.swift` — Failure type
- `swift-primitives/swift-test-primitives/Sources/Test Primitives Core/Test.Text.Segment.swift` — Segment styles
- `swift-primitives/swift-test-primitives/Sources/Test Snapshot Primitives/Test.Snapshot.Diff.swift` — Styled diff
- `swift-console/Sources/Console/Console.Capability.swift` — Terminal capability detection
- `swift-console/Sources/Console/Console.Capability+Detect.swift` — TTY/NO_COLOR/FORCE_COLOR/CI detection
- `swift-console/Sources/Console/Console.Style.swift` — Style → ANSI rendering with capability degradation
- `swift-standards/swift-ecma-48/Sources/ECMA 48/ECMA_48.SGR.Color.swift` — Color types (palette/extended/rgb)
- `swift-institute/Research/expression-decomposition-implementation.md` — Macro-level expression capture
- `swift-institute/Research/comparative-swift-testing-frameworks.md` — Apple vs Institute comparison
