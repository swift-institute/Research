# Swift Testing Data Maximization
<!--
---
version: 1.0.0
last_updated: 2026-03-14
status: RECOMMENDATION
---
-->

**Status**: Tier 2 Research [RES-004]
**Date**: 2026-03-14
**Author**: Claude (co-architect)
**Packages**: swift-test-primitives (L1), swift-tests (L3), swift-testing (L3)

---

## Context

The Swift Institute builds "timeless infrastructure" — primitives, standards, and foundations packages. Development increasingly involves LLM-assisted iteration: an LLM reads test output, identifies regressions or opportunities, proposes changes, and the cycle repeats.

The bottleneck is test output quality. Currently:

- Performance data is rich per-test (Tests.Diagnostic) but the summary table is plaintext-only
- Functional test results are pass/fail with no structured context beyond the event stream
- Test output is a mix of human-readable ANSI text, HTML-delimited JSON blocks, and a minimal JSON reporter
- There is no unified schema for test artifacts — performance diagnostics use `<!-- PERFORMANCE_DIAGNOSTIC_BEGIN/END -->` markers, complexity diagnostics use `<!-- COMPLEXITY_DIAGNOSTIC_BEGIN/END -->`, and everything else is unstructured
- Comparison across runs requires manual correlation via history JSONL files
- The .timed() scope provider prints directly to stdout, bypassing the reporter event system
- The JSON reporter (Test.Reporter.JSON) accumulates events in a Mutex and serializes a minimal `{"kind": "...", "elapsed_ns": ...}` object per event — losing test identity, expectation details, and all performance data

The goal: transform test runs into a structured data pipeline where every test emits machine-readable diagnostics that LLMs can consume to drive the next iteration.

---

## Question

How should the Swift Institute testing infrastructure (swift-test-primitives, swift-tests, swift-testing) be evolved to maximize the quantity, quality, and structure of data emitted from test runs for LLM consumption?

---

## Prior Art Survey

Eight test output formats were analyzed. Key findings:

| Format | Type | Streamable | Environment | Tests+Benchmarks | Hierarchy | Schema Versioned |
|--------|------|------------|-------------|-----------------|-----------|-----------------|
| Rust cargo test --format json | JSONL | Yes | No | Yes | Flat | No |
| Go go test -json | JSONL | Yes | No | Yes | Implicit (/) | No |
| JUnit XML | Single XML | No | Via properties | Tests only | Native nesting | No |
| pytest --json-report | Single JSON | No | Yes (rich) | Tests only | Implicit (nodeid) | No |
| Google Benchmark JSON | Single JSON | No | Yes (excellent) | Benchmarks only | Flat | Yes (v1) |
| Criterion.rs | JSONL | Yes | No | Benchmarks only | Group messages | No |
| Apple Swift Testing | JSONL | Yes | No | Tests only | Two-phase (records+events) | Yes (ABI) |
| OpenTelemetry | JSON/Proto | No (batched) | Yes (resource) | Possible | Native (parentSpanId) | Yes (OTLP 1.x) |

**Insights for our design**:

1. **JSONL is the right format for streaming**, but a single summary document at the end is also valuable. Go and Apple Swift Testing both use JSONL and are the most LLM-friendly formats for functional tests.

2. **No existing format combines functional tests AND benchmarks** in a single rich schema. Google Benchmark has excellent benchmark data; Apple Swift Testing has excellent functional test data; nobody has both. This is our opportunity.

3. **Environment metadata matters enormously**. Google Benchmark's context block (CPU cache topology, load average, schema version) is the gold standard for reproducibility. pytest's environment block is also excellent. Most other formats omit it entirely.

4. **Apple Swift Testing's two-phase design** (emit test records first, then events referencing them by ID) is the most architecturally sound approach for a consumer that needs to build a model of the test plan before interpreting events.

5. **Schema versioning** (Google Benchmark's `json_schema_version: 1`, Apple's ABI versioning) is essential for forward compatibility. We should adopt this from the start.

6. **Criterion.rs's statistical rigor** — confidence intervals on every metric, regression detection built in — is the best model for benchmark data.

7. **pytest's three-phase model** (setup/call/teardown per test) captures exactly where failures occur. Our scope provider chain is analogous.

---

## Analysis

### Area 1: Unified Structured Output Schema

**Problem**: Test output is a mix of ANSI console text, HTML-delimited JSON blocks, and a minimal JSON reporter that drops most data. An LLM consuming `swift test` output must parse multiple formats with different delimiters.

**Option A: Enhance the existing JSON reporter**

Extend `Test.Reporter.JSON` to serialize the full `Test.Event` (including `id`, `kind` with all associated values, `elapsed`) instead of just `{"kind": "...", "elapsed_ns": ...}`.

- *Pro*: Minimal changes. Builds on existing infrastructure.
- *Con*: Still a single JSON document (not streamable). Events don't carry performance diagnostics or complexity results. The event schema is coupled to L1 primitives types.

**Option B: JSONL event stream reporter**

Create a new reporter that emits one JSON object per line, similar to `go test -json` and Apple Swift Testing. Each line is a self-contained event with full context.

- *Pro*: Streamable — LLMs can process events as they arrive. No accumulation needed. Each line is independently parseable. Natural fit for the existing event-driven architecture.
- *Con*: Requires consumers to maintain state (accumulate test records to interpret events). Larger output than a single document with shared references.

**Option C: Two-phase JSONL (Apple Swift Testing model)**

Phase 1: Emit test plan records (all discovered tests with traits, source locations, hierarchy). Phase 2: Emit event records referencing test IDs. End with a summary record.

- *Pro*: Cleanest separation of structure and behavior. Consumer can build a complete model of the test plan before processing events. Natural fit for LLM context windows (the plan is a compact overview).
- *Con*: More complex to implement. Requires the reporter to receive the plan before events begin.

**Option D: Single summary JSON document at run end**

Instead of streaming, accumulate everything and emit one structured JSON document when the run completes. Include the test plan, all events, all diagnostics, and aggregated results.

- *Pro*: Simplest to consume — one document, one parse. LLMs can receive the entire context at once. No state management needed.
- *Con*: Not streamable. For large test suites, the document could be very large. No incremental feedback during long runs.

**Recommendation: Option C (Two-phase JSONL) with Option D (summary document) as a post-run action.**

Rationale: The two-phase model gives streaming consumers incremental feedback while the summary document gives LLMs a single artifact to consume. The summary can be written to a file (e.g., `.build/test-results.json`) while the JSONL stream goes to stdout. This mirrors how the existing architecture already separates the reporter sink (events) from post-run actions (summary table).

**Proposed schema version**: `1`

**Proposed record types**:

```json
{"version": 1, "kind": "plan", "payload": <plan>}
{"version": 1, "kind": "event", "payload": <event>}
{"version": 1, "kind": "diagnostic", "payload": <diagnostic>}
{"version": 1, "kind": "summary", "payload": <summary>}
```

**Layer**: The schema definition (record types, field names) belongs in L1 (swift-test-primitives) as value types. The serialization and reporter implementation belongs in L3 (swift-tests).

---

### Area 2: Expectation Data Enrichment

**Problem**: `Test.Expectation` currently carries `expression: Test.Expression` (with `sourceCode`, `sourceLocation`, and `values: [Value]`) and optional `failure: Test.Expectation.Failure` (with `message`, `expected`, `actual`, `difference`, `comment`). This is already richer than most frameworks. But the data is only emitted for failing expectations in the console reporter, and the JSON reporter drops it entirely.

**Option A: Emit all expectation data (pass and fail) in structured output**

Include every `Test.Expectation` in the JSONL stream, with full expression, values, and failure details.

- *Pro*: Maximum information. An LLM can see exactly what was tested, even on passing tests. Useful for understanding test coverage.
- *Con*: Extremely verbose. A test with 100 `#expect` calls would emit 100 expectation records. Most passing expectations add noise, not signal.

**Option B: Emit only failing expectations in structured output, with full detail**

Include failing expectations with all fields (expression source code, source location, expected/actual values, diff, comment). Passing expectations emit only a count.

- *Pro*: Focused signal. Failures have maximum detail. Passing test count provides confidence without noise.
- *Con*: On a passing test run, the LLM sees no detail about what was actually tested.

**Option C: Configurable verbosity**

Default: emit failures with full detail + passing count. Verbose mode (`.diagnostic` trait or environment variable): emit all expectations.

- *Pro*: Right default for most cases. Opt-in richness when needed.
- *Con*: Two code paths to maintain.

**Recommendation: Option C (configurable verbosity).**

The default should emit:
- Failing expectations: full detail (source code, source location, expected, actual, diff, comment)
- Passing expectations: count only (e.g., `"expectations_passed": 7`)
- Per-test duration: always (computed from testStarted/testEnded elapsed difference)

Verbose mode (activated by a `.verbose` trait or `SWIFT_TEST_VERBOSE=true`): emit every expectation as a separate event.

**Layer**: `Test.Expectation` and `Test.Expectation.Failure` are already L1. The verbosity trait is an L3 concern (Test.Trait.Collection.Modifier). No L1 changes needed — the existing types already carry all the data.

---

### Area 3: Performance Data Completeness

**Problem**: The `.timed()` infrastructure already captures rich data per-test via `Tests.Diagnostic`. But there are gaps:
- The summary table (`Tests.Diagnostic.summary()`) is plaintext only
- No cross-test ratio/speedup computation in the structured output
- Allocation data is collected but excluded from the `PERFORMANCE_DIAGNOSTIC` JSON block
- Complexity analysis (`Tests.Complexity.Diagnostic`) is separate from `.timed()` diagnostics
- No raw iteration data in the performance summary (only aggregated stats)

**Option A: Add allocations and complexity to the PERFORMANCE_DIAGNOSTIC JSON**

Extend `Tests.Diagnostic.jsonBlock()` to include allocation stats and (if available) complexity classification.

- *Pro*: Incremental. Backward-compatible with existing HTML delimiter parsing.
- *Con*: Still uses the HTML-delimited format. Still printed via stdout, bypassing the reporter.

**Option B: Emit Tests.Diagnostic as a first-class event in the JSONL stream**

Add a new record kind `"diagnostic"` to the JSONL output. The `.timed()` scope provider emits a structured diagnostic event instead of printing directly.

- *Pro*: All performance data flows through the reporter system. Machine-parseable without delimiter scanning. Natural deduplication — the diagnostic is emitted once, not printed AND collected.
- *Con*: Requires changing the `.timed()` scope provider to emit events instead of printing. Requires the scope provider to have access to the reporter's sender.

**Option C: Emit a structured PERFORMANCE_SUMMARY as JSON after all tests complete**

The `Tests.Diagnostic.Collector.shared.drain()` call in `Test.Runner.run()` already aggregates all diagnostics. Instead of printing a plaintext table, emit a JSON summary record.

- *Pro*: Cross-test comparison data in one place. Can include ratios, rankings, groupings.
- *Con*: Only available at run end, not per-test.

**Recommendation: Option B + Option C combined.**

The `.timed()` scope provider should emit a `Test.Event.Kind.custom(name: "performanceDiagnostic", payload: jsonString)` event (or better, a new first-class event kind — see Area 6). This replaces the direct `print()` calls. The runner's post-run aggregation emits a `"performanceSummary"` record in the JSONL stream.

The performance diagnostic JSON should include:
- All current fields (test name, qualified name, metric, distribution, trend, environment)
- **Allocations**: per-iteration allocation counts, peak memory, net heap growth
- **Complexity**: if a complexity analysis was performed on the same test, include the classification, exponent, confidence, and growth ratios
- **Raw durations**: the full `durations_seconds` array (already present)
- **Ratios**: vs baseline (already present as `change`), vs first test in the suite (new)

**Layer**: `Tests.Diagnostic` serialization is L3. If we add a new `Test.Event.Kind` case, that's an L1 change to `Test.Event.Kind.swift`.

---

### Area 4: Test Run Metadata

**Problem**: The test run itself has no structured metadata envelope. An LLM receiving test output doesn't know what commit was tested, what branch, how long the run took, what the test plan was, or how many tests were discovered vs run vs filtered.

**Option A: Enrich .runStarted and .runEnded events**

Add payload fields to the existing `runStarted` and `runEnded` event kinds.

- *Pro*: Natural fit for existing event lifecycle. No new event kinds needed.
- *Con*: L1 change (modifying `Test.Event.Kind` enum cases to carry associated values). The `runStarted` case currently has no payload.

**Option B: Emit metadata as separate "plan" and "summary" records in the JSONL stream**

The plan record emits the complete test plan (all discovered tests with traits). The summary record emits aggregate results, timing, and environment.

- *Pro*: Clean separation. Plan and summary are self-contained documents. No L1 changes needed — these are reporter-level constructs.
- *Con*: The "plan" record duplicates information that the event stream will eventually convey via testStarted/testEnded events.

**Option C: Embed metadata in the summary JSON document (Option D from Area 1)**

The single summary document includes a metadata section with git SHA, branch, timestamp, plan summary, environment, and pass/fail/skip counts.

- *Pro*: All metadata in one place. Easy to consume.
- *Con*: Not available until run end.

**Recommendation: Option B (plan + summary records in JSONL stream) + Option C (metadata in summary document).**

The plan record should include:
- **Schema version**: integer
- **Timestamp**: ISO 8601 start time
- **Git metadata**: SHA, branch, dirty flag (captured at run start via `git rev-parse HEAD` and `git branch --show-current`)
- **Environment**: full `Test.Environment` (architecture, cores, memory, Swift version, optimization, feature flags, OS)
- **Test plan**: array of test entries with `{id, module, suite, name, traits, sourceLocation}`
- **Counts**: `{discovered, filtered, pending}`

The summary record should include:
- **Duration**: total run time
- **Counts**: `{passed, failed, skipped, total}`
- **Performance diagnostics**: array of summarized diagnostics (qualified name, metric value, change from baseline)
- **Failures**: array of `{testId, issueKind, sourceLocation, message}` for quick triage

**Layer**: Git metadata capture is L3 (uses `Kernel` for process execution). `Test.Environment` is already L3. The plan/summary record types could be defined as L1 value types or as L3-only constructs. Recommendation: define the record envelope in L1 (`Test.Report.Record`), but the serialization in L3.

**Git metadata capture**: The runner should attempt to read git state at run start. If git is not available (e.g., in CI without git, or a non-git project), the fields are nil. This is best-effort, not a hard dependency.

---

### Area 5: Failure Diagnostics

**Problem**: When a test fails, the current output is an issue record with a kind (`.expectationFailed(id)` or `.errorCaught(type, description)`) and a source location. For LLM-driven debugging, richer failure context would help.

**Option A: Include stack traces in failure events**

Capture the call stack when an expectation fails or an error is caught, and include it in the issue record.

- *Pro*: Gives the LLM the full execution path to the failure. Essential for debugging complex failures.
- *Con*: Stack traces are expensive to capture. Platform-specific (different APIs on Darwin vs Linux). Can be very long. Most `#expect` failures don't benefit from stack traces — the source location is sufficient.

**Option B: Cross-reference failures with source code**

Include the test body source code (or a snippet around the failing line) in the failure diagnostic.

- *Pro*: The LLM can see exactly what code failed without a separate file read.
- *Con*: Source code embedding increases output size significantly. The LLM usually has access to the source code anyway via tool use. Fragile — source locations can be stale if code changed after compile.

**Option C: Track "newly failing" vs "consistently failing"**

Compare the current test results against the history to classify each failure:
- **New regression**: was passing in recent history, now failing
- **Known failure**: has been failing consistently
- **Flaky**: passes intermittently

- *Pro*: Extremely high signal. "This test was passing in the last 5 runs and just started failing" is the most actionable diagnostic an LLM can receive.
- *Con*: Requires the history system to track pass/fail status, not just performance metrics. Requires comparing test identities across runs.

**Option D: Minimal enrichment — expected/actual values and diff**

The current `Test.Expectation.Failure` already has `expected`, `actual`, and `difference` fields. Ensure these are always populated when applicable and always serialized in structured output.

- *Pro*: Already implemented at the data model level. Just needs to be serialized.
- *Con*: Only helps for assertion failures, not thrown errors.

**Recommendation: Option D (always serialize existing rich failure data) + Option C (track newly-failing).**

Option D is nearly free — the data already exists in `Test.Expectation.Failure`, we just need the structured reporter to serialize it. Option C provides the highest-value signal for LLM-driven iteration.

Stack traces (Option A) should be deferred. They add complexity and platform-specific code for limited value in the common case. Source code embedding (Option B) is not worth the cost when the LLM has file access.

**Newly-failing detection**:
- Extend `Tests.History.Record` to include a `result: Test.Event.Result` field (passed/failed/skipped)
- On test completion, compare against the last N history records for the same test ID
- Classify as: `newRegression`, `knownFailure`, `flaky`, `newlyPassing`, `stable`
- Include this classification in the test's result event

**Layer**: `Tests.History.Record` is L3. The classification logic is L3. The classification enum could be L1 (as a `Test.Event.Kind.testEnded` enrichment) or L3 (as a post-run annotation). Recommendation: L3, emitted as part of the summary record.

---

### Area 6: Event Stream Architecture

**Problem**: The current event architecture has a split-brain issue: `.timed()` prints directly to stdout while the reporter receives events separately. This creates interleaved, uncoordinated output. Performance diagnostics bypass the reporter entirely.

**Current flow**:
```
Test body → scope provider (.timed) → print(diagnostic.formatted())
                                    → print(diagnostic.jsonBlock())
                                    → Tests.Diagnostic.Collector.shared.append(diagnostic)
Test body → runner → sender.send(Test.Event(kind: .testEnded)) → reporter
```

**Option A: Route all diagnostics through the event system**

The `.timed()` scope provider emits a `Test.Event.Kind.custom(name: "performanceDiagnostic", payload: json)` event. The reporter handles formatting. No direct `print()` in scope providers.

- *Pro*: Single output path. No interleaving. The reporter has complete control over formatting.
- *Con*: The `.custom` case uses `String` payload — no type safety. The reporter must know how to parse/format performance diagnostics, creating a dependency on Tests Performance from Tests Reporter.

**Option B: Add first-class event kinds for diagnostics**

Add new cases to `Test.Event.Kind`:
```swift
case performanceDiagnosticReady
case complexityDiagnosticReady
```

The diagnostic data itself is stored in a side channel (the existing `Tests.Diagnostic.Collector` or a new per-test attachment), and the event signals the reporter to retrieve and format it.

- *Pro*: Type-safe event kinds. Clear lifecycle signal.
- *Con*: L1 change (new cases in `Test.Event.Kind`). The side channel is awkward — the event should carry its data, not point to a mutable singleton.

**Option C: Diagnostic attachment model**

Add an `attachments: [Test.Attachment]` field to `Test.Event`. Attachments are typed key-value pairs that any scope provider can add to events. The `.timed()` scope provider attaches a performance diagnostic. The snapshot scope provider attaches snapshot diffs.

- *Pro*: Extensible. Any scope provider can attach structured data without modifying the event kind enum. Type-safe via an attachment protocol.
- *Con*: Significant L1 change (new `Test.Attachment` type, new field on `Test.Event`). More complex than needed for the immediate use case.

**Option D: Scope providers return diagnostics; runner routes them**

Change the scope provider's `provideScope` signature to return an optional diagnostic value. The runner receives the diagnostic and routes it to the reporter as an event.

- *Pro*: Clean data flow — no singletons, no side channels, no direct printing. The runner is already the orchestration point.
- *Con*: Changes the scope provider protocol signature (L3 API change). Not all scope providers produce diagnostics.

**Recommendation: Option A (use `.custom` events) for now, with a migration path to Option C (attachment model) as a future evolution.**

Rationale: Option A is the minimal change that fixes the split-brain problem. The `.custom(name:payload:)` case already exists in L1 and is currently unused. Using it doesn't require any L1 changes. The reporter can pattern-match on the custom event name to decide formatting.

**Concrete changes**:
1. `.timed()` scope provider: replace `print(diagnostic.formatted())` and `print(diagnostic.jsonBlock())` with emitting a custom event containing the JSON diagnostic
2. `.timed()` scope provider: needs access to the reporter's `Sender`. This requires either passing the sender through the scope provider chain, or using the existing `Tests.Diagnostic.Collector` as a side channel and having the runner emit the diagnostic events after the scope provider returns.
3. The simplest approach: keep `Tests.Diagnostic.Collector.shared.append(diagnostic)` in the scope provider, but **remove the direct print() calls**. The runner, after the test body completes, drains per-test diagnostics from the collector and emits them as custom events.

**Future evolution (Option C)**: Define `Test.Attachment` as an L1 type with `name: String` and `payload: String`. Replace `.custom(name:payload:)` with a more general attachment model. This can be done in a later phase without breaking the JSONL schema — just add a new record kind.

**Layer**: No L1 changes needed for Option A. All changes in L3 (Tests Performance, Tests Core, Tests Reporter).

---

### Area 7: Reporter Composability

**Problem**: Currently there's one reporter per run (console OR JSON, selected by `SWIFT_TEST_OUTPUT`). For LLM consumption, you want both human-readable output AND machine-readable output simultaneously.

**Option A: Tee reporter**

Create a `Test.Reporter.tee(reporters:)` factory that creates a `Sink` forwarding events to multiple underlying sinks.

```swift
extension Test.Reporter {
    public static func tee(_ reporters: [Test.Reporter]) -> Test.Reporter {
        Test.Reporter {
            Sink(TeeSink(sinks: reporters.map { $0.sink() }))
        }
    }
}
```

- *Pro*: Simple. Composable. No changes to the reporter protocol. The console reporter continues to work as-is, the structured reporter works as-is, and you get both.
- *Con*: Multiple sinks means the `~Copyable` ownership model gets more complex. The `TeeSink` must own multiple `Sink` values, which are `~Copyable`. Actually — `Sink` stores its implementation as `any Implementation` (Copyable via protocol existential), so this works.

**Option B: Reporter writes structured output to a file**

The structured reporter always writes to `.build/test-results.json` (or a configurable path). The console reporter always writes to stdout. Both are active by default.

- *Pro*: No tee needed. File output is always available for LLM consumption. Console output is always available for human developers.
- *Con*: Two separate reporter instances with separate event accumulation. Slightly wasteful. The file path needs to be discoverable.

**Option C: Single structured reporter with a console formatter**

Replace the console reporter entirely with a structured reporter that can optionally format its output for the console. The structured data is the source of truth; console output is a derived view.

- *Pro*: Single source of truth. No duplication. The structured output is always complete.
- *Con*: Major refactor. The console reporter has complex ANSI formatting logic that's hard to derive from structured data.

**Recommendation: Option A (tee reporter) + Option B (file output for structured reporter).**

Default behavior:
1. Console reporter writes human-readable output to stdout (existing behavior)
2. Structured reporter writes JSONL to `.build/test-results.jsonl` (new)
3. Both receive every event via a tee reporter

This is activated by default — no environment variable needed. The file path can be overridden with `SWIFT_TEST_OUTPUT_PATH`.

**Implementation**: The tee reporter is straightforward. The `TeeSink` holds an array of `any Sink.Implementation` (since `Implementation` is a Copyable protocol). On `send()`, it forwards to all implementations. On `finish()`, it calls finish on all.

Wait — `Sink` is `~Copyable` but `Sink.Implementation` is a protocol requiring `Sendable`. The `TeeSink` would itself implement `Sink.Implementation` and hold the child implementations. This works because `any Sink.Implementation` is `Sendable` and `Copyable`.

**Layer**: Tee reporter is L3 (Tests Reporter or Tests Core). File output path logic is L3.

---

### Area 8: Snapshot Testing Integration

**Problem**: `#snapshot` tests produce artifacts (reference files, diffs) that are separate from the test event stream. An LLM analyzing test results doesn't see snapshot diffs.

**Current state**: The inline snapshot system (`Tests Inline Snapshot` module) uses a separate state accumulation (`Test.Snapshot.Inline.state`) and writes back to source files via `Test.Snapshot.Inline.Rewriter.writeAll()` in a post-run action. Snapshot mismatches are reported as expectation failures with a diff in the `Test.Expectation.Failure.difference` field.

**Option A: Include snapshot diff in the structured output**

The expectation failure already contains the diff. Ensure the structured reporter serializes the `difference` field of `Test.Expectation.Failure`.

- *Pro*: Nearly free — the data is already there. Just needs serialization.
- *Con*: Diffs can be very large (especially for complex rendered output). May overwhelm the structured output.

**Option B: Summary-only snapshot data**

Include snapshot test results in the summary: count of snapshots checked, count of mismatches, list of mismatched snapshot names with file paths.

- *Pro*: Compact. Gives LLM actionable data (which snapshots changed) without the full diff.
- *Con*: Less detail than the full diff.

**Option C: Truncated diffs with full diff in a separate file**

Include first N lines of the diff in the structured output. Write the full diff to a file alongside the test results.

- *Pro*: Balances signal and size.
- *Con*: More complex. Another file to manage.

**Recommendation: Option A (serialize the existing diff) with size limits.**

The `Test.Expectation.Failure.difference` field should be serialized in the structured output. If the diff exceeds 2000 characters, truncate it and add a `"truncated": true` flag. The full diff remains available in the expectation's source location context.

This is almost entirely free — the structured reporter just needs to serialize `failure.difference.plainText` when present.

**Layer**: No changes needed. The data is already L1. Serialization is L3.

---

### Area 9: Test.ID Hierarchy

**Problem**: The `@Suite` macro on nested types doesn't thread the enclosing type name into inner suite IDs. `@Suite(.serialized) enum AllBenchmarks { @Suite struct V1 { ... } }` produces `Test.ID(suite: "V1")` not `Test.ID(suite: "AllBenchmarks.V1")`.

**Option A: Fix the macro to inspect enclosing type context**

The `@Suite` and `@Test` macro implementations use SwiftSyntax and can inspect the lexical context to discover enclosing types.

- *Pro*: Correct by construction. No runtime cost. Suite names automatically reflect nesting.
- *Con*: SwiftSyntax's enclosing context discovery may be limited. Macros execute in isolation — they may not see other macros' effects. This needs investigation.

**Option B: Change `Test.ID.suite` from `String?` to `[String]`**

Each nesting level is a separate array element. `Test.ID(suite: ["AllBenchmarks", "V1"])`.

- *Pro*: Precise hierarchy. Easy to construct at any level. Natural for filtering ("all tests in AllBenchmarks") and display.
- *Con*: Breaking L1 change. Affects baseline storage paths, history file paths, and every consumer of `Test.ID.suite`.

**Option C: Use the registry's tree structure to resolve hierarchy**

The `Test.Plan.Registry.finalize()` already builds a tree from suite registrations and test entries. The tree path provides the full hierarchy. Use this path as the authoritative suite nesting.

- *Pro*: No L1 change. The tree already has the information. `fullyQualifiedName` can be derived from the tree path.
- *Con*: The tree path is only available after finalization. `Test.ID.suite` would remain a simple string, with the full hierarchy only available in the plan.

**Option D: Thread enclosing suite names through `@Suite` macro registration**

When the `@Suite` macro expands, it registers the suite with both its own name and its enclosing type (if any). The registry can then build the full path.

- *Pro*: Works within the existing architecture. The macro already registers suites.
- *Con*: Requires macro changes.

**Recommendation: Option B (change `suite` to `[String]`) + Option A (fix macro).**

Rationale: `suite: [String]` is the correct model. A string with dots is a poor substitute for a structured path. The breaking change is acceptable per the research constraints. The `fullyQualifiedName` property is trivially updated:

```swift
public var fullyQualifiedName: String {
    ([module] + suite + [name]).joined(separator: ".")
}
```

Baseline and history storage paths use the suite components as directory nesting, which already works because `Test.Plan.Registry` splits on dots. With an array, the splitting is eliminated.

**Migration**: `Test.ID.suite: String?` becomes `Test.ID.suite: [String]`. An empty array replaces `nil`. `Codable` conformance uses the array directly. The macro passes enclosing type names as array elements.

**Layer**: L1 change (`Test.ID.swift`). Macro changes in L3 (`swift-testing`). Storage path changes in L3 (`Tests.Baseline.Storage`, `Tests.History.Storage`).

---

### Area 10: Inline Diagnostics for Non-Performance Tests

**Problem**: Only `.timed()` tests produce structured diagnostics. Regular functional tests produce only pass/fail events. But functional tests could also benefit from structured output.

**Option A: Every test emits a diagnostic block**

After each test completes, the runner emits a functional diagnostic with: test ID, result, duration, expectations checked (count), expectations failed (count), issues recorded, memory delta (if measurable).

- *Pro*: Every test has structured output. LLM can see how long each test took, how many assertions it made, and whether it's a fast unit test or a slow integration test.
- *Con*: May be noisy for trivial tests. Duration measurement adds overhead (but it's already captured via `elapsed`).

**Option B: Opt-in `.verbose` or `.diagnostic` trait**

Add a trait that enables rich output for specific tests. Only tests with this trait emit detailed diagnostics.

- *Pro*: No noise on tests that don't need it. Test authors control verbosity.
- *Con*: Requires annotation on every test that should emit diagnostics. Easy to forget.

**Option C: Always capture, conditionally emit**

The runner always captures per-test metadata (duration, expectation count, issue count). This data is always included in the summary record. Per-test diagnostic events are only emitted in verbose mode.

- *Pro*: Zero annotation burden. The summary always has per-test data. Verbose mode provides per-test detail.
- *Con*: Two output levels to document.

**Recommendation: Option C (always capture, conditionally emit).**

The runner already computes `elapsed` for every event and counts expectations via the collector. Adding an expectation count and duration to the `testEnded` event's payload is nearly free.

**Per-test summary data** (always included in the summary record):
- `id`: fully qualified test name
- `result`: passed/failed/skipped
- `duration_seconds`: test execution time
- `expectations_checked`: number of `#expect` / `#require` calls
- `expectations_failed`: number of failed expectations
- `issues_recorded`: number of issues

**Per-test diagnostic event** (emitted in verbose mode):
- All of the above, plus:
- `expectations`: array of all expectation results (with source code and values)
- `issues`: array of all issue records

**Layer**: The per-test summary is L3 (runner captures the data). The summary record type could be L1 or L3.

---

## Comparison

| Area | Priority | L1 Changes | L3 Changes | LLM Value | Implementation Cost |
|------|----------|------------|------------|-----------|-------------------|
| 1. Unified Schema | **Critical** | Optional (record envelope type) | New reporter, JSONL serialization | Very High | Medium |
| 6. Event Stream Architecture | **Critical** | None | Remove direct print(), route through events | Very High | Low |
| 7. Reporter Composability | **Critical** | None | Tee reporter, file output | High | Low |
| 4. Test Run Metadata | **High** | None | Git capture, plan/summary records | Very High | Medium |
| 2. Expectation Enrichment | **High** | None | Serialize existing failure data | High | Low |
| 3. Performance Data Completeness | **High** | None | Add allocations/complexity to JSON | High | Low |
| 10. Functional Test Diagnostics | **Medium** | None | Per-test metadata capture | Medium | Low |
| 5. Failure Diagnostics | **Medium** | None | Newly-failing detection, history tracking | High | Medium |
| 9. Test.ID Hierarchy | **Medium** | Yes (suite: [String]) | Macro fix, storage path updates | Medium | Medium |
| 8. Snapshot Integration | **Low** | None | Serialize existing diff data | Low | Very Low |

---

## Outcome

### Unified Vision: What Should Test Output Look Like?

A `swift test` run produces two artifacts:

1. **JSONL event stream** (stdout or configurable): Real-time, one JSON object per line. Events flow as tests execute. This is the primary output for streaming consumers and CI systems.

2. **Summary document** (`.build/test-results.json`): A single JSON document produced at run end containing the complete test plan, all results, all diagnostics, and aggregate metadata. This is the primary output for LLM consumption — one file, one context window.

Both artifacts use the same schema. The summary document is a "materialized view" of the event stream plus aggregated data.

### Draft Schema

**JSONL Record Envelope**:
```json
{"version": 1, "kind": "<kind>", "payload": {}}
```

**Kind: "plan"** (emitted once at run start):
```json
{
  "version": 1,
  "kind": "plan",
  "payload": {
    "timestamp": "2026-03-14T10:30:00Z",
    "git": {
      "sha": "abc123...",
      "branch": "main",
      "dirty": false
    },
    "environment": {
      "arch": "arm64",
      "physical_cores": 10,
      "logical_cores": 10,
      "memory_bytes": 34359738368,
      "swift_version": "6.2.4",
      "optimization": "debug",
      "feature_flags": {
        "NonisolatedNonsendingByDefault": true,
        "StrictMemorySafety": false
      },
      "os": "Darwin 25.2.0"
    },
    "tests": [
      {
        "id": "MyModule.MySuite.testExample",
        "module": "MyModule",
        "suite": ["MySuite"],
        "name": "testExample",
        "source_location": {"file_id": "MyModule/Tests.swift", "line": 42, "column": 5},
        "traits": [".timed(iterations: 10)", ".serialized"]
      }
    ],
    "counts": {"discovered": 50, "filtered": 5, "pending": 45}
  }
}
```

**Kind: "event"** (emitted per lifecycle event):
```json
{
  "version": 1,
  "kind": "event",
  "payload": {
    "type": "testEnded",
    "test_id": "MyModule.MySuite.testExample",
    "result": "passed",
    "elapsed_seconds": 0.123,
    "expectations_checked": 7,
    "expectations_failed": 0,
    "issues_recorded": 0
  }
}
```

**Kind: "event" (failure)**:
```json
{
  "version": 1,
  "kind": "event",
  "payload": {
    "type": "expectationFailed",
    "test_id": "MyModule.MySuite.testExample",
    "elapsed_seconds": 0.045,
    "expression": "count == 5",
    "source_location": {"file_id": "MyModule/Tests.swift", "line": 48, "column": 9},
    "expected": "5",
    "actual": "3",
    "difference": "- 5\n+ 3",
    "comment": null
  }
}
```

**Kind: "diagnostic"** (emitted per .timed() test):
```json
{
  "version": 1,
  "kind": "diagnostic",
  "payload": {
    "type": "performance",
    "test_id": "MyModule.MySuite.testExample",
    "metric": "median",
    "status": "PASS",
    "distribution": {
      "count": 10,
      "min": 0.000123,
      "median": 0.000145,
      "mean": 0.000148,
      "max": 0.000189,
      "stddev": 0.000012,
      "cv": 8.1,
      "mad": 0.000008,
      "p95": 0.000178,
      "p99": 0.000189,
      "outliers": 1
    },
    "trend": {
      "mann_kendall_z": 0.45,
      "interpretation": "none"
    },
    "allocations": {
      "per_iteration": [
        {"bytes_allocated": 1024, "allocation_count": 5},
        {"bytes_allocated": 1024, "allocation_count": 5}
      ]
    },
    "baseline": {
      "value": 0.000142,
      "change": 0.021,
      "is_regression": false
    },
    "history": {
      "record_count": 15,
      "mann_kendall_z": -0.32,
      "interpretation": "none",
      "overall_change": -0.05
    },
    "environment": { "..." : "..." },
    "durations_seconds": [0.000123, 0.000145, "..."]
  }
}
```

**Kind: "diagnostic" (complexity)**:
```json
{
  "version": 1,
  "kind": "diagnostic",
  "payload": {
    "type": "complexity",
    "test_id": "MyModule.MySuite.testComplexity",
    "exponent": {"k": 1.02, "r_squared": 0.9987},
    "best": {"class": "linear", "r_squared": 0.9992},
    "confidence": "high",
    "candidates": [
      {"class": "linear", "r_squared": 0.9992},
      {"class": "linearithmic", "r_squared": 0.9845}
    ],
    "points": [
      {"size": 100, "seconds": 0.00012},
      {"size": 1000, "seconds": 0.00123}
    ],
    "growth_ratios": [10.25, 9.98, 10.12]
  }
}
```

**Kind: "summary"** (emitted once at run end):
```json
{
  "version": 1,
  "kind": "summary",
  "payload": {
    "duration_seconds": 12.345,
    "counts": {"passed": 42, "failed": 1, "skipped": 2, "total": 45},
    "failures": [
      {
        "test_id": "MyModule.MySuite.testBroken",
        "issue_kind": "expectationFailed",
        "source_location": {"file_id": "MyModule/Tests.swift", "line": 99, "column": 9},
        "message": "Expected 5, got 3",
        "classification": "newRegression"
      }
    ],
    "performance": [
      {
        "test_id": "MyModule.MySuite.testExample",
        "metric": "median",
        "value_seconds": 0.000145,
        "baseline_change": 0.021,
        "status": "PASS"
      }
    ]
  }
}
```

### Summary Document Schema

The `.build/test-results.json` summary document is the concatenation of all JSONL records into a single JSON object:

```json
{
  "version": 1,
  "plan": { "..." },
  "events": [ { "..." }, { "..." } ],
  "diagnostics": [ { "..." }, { "..." } ],
  "summary": { "..." }
}
```

This is written as a post-run action, after all events and diagnostics have been collected.

---

## Implementation Plan

### Phase 1: Fix Event Stream Architecture (Areas 6, 7)
**Priority**: Critical. Unblocks all other phases.
**Scope**: L3 only (swift-tests).

1. **Remove direct print() from `.timed()` scope provider** (`Test.Trait.Scope.Provider.timed.swift`):
   - Delete `print(diagnostic.formatted())` and `print(diagnostic.jsonBlock())`
   - Keep `Tests.Diagnostic.Collector.shared.append(diagnostic)` for the summary
   - The console reporter will format performance diagnostics when it receives the event

2. **Emit performance diagnostics as custom events**:
   - After the test body returns, the runner checks `Tests.Diagnostic.Collector.shared` for new diagnostics
   - For each diagnostic, emit `Test.Event(kind: .custom(name: "performanceDiagnostic", payload: json))`
   - The console reporter pattern-matches on this name and calls `diagnostic.formatted()`

3. **Implement tee reporter** (`Test.Reporter.Tee.swift`):
   - `Test.Reporter.tee(_ reporters: [Test.Reporter]) -> Test.Reporter`
   - `TeeSink` implements `Sink.Implementation`, forwards to multiple implementations

4. **Wire up default reporter composition** in `Testing.Main.swift`:
   - Default: `Test.Reporter.tee([.console, .structured(to: ".build/test-results.jsonl")])`
   - Override via `SWIFT_TEST_OUTPUT=json` (JSON only) or `SWIFT_TEST_OUTPUT=console` (console only)

**Files changed**:
- `Test.Trait.Scope.Provider.timed.swift` — remove print calls
- `Test.Runner.swift` — emit diagnostic events after test execution
- `Test.Reporter.Tee.swift` — new file
- `Testing.Main.swift` — wire up tee reporter

### Phase 2: Structured JSONL Reporter (Area 1, 2, 3, 8)
**Priority**: Critical. The core deliverable.
**Scope**: L3 (swift-tests, Tests Reporter module).

1. **Implement `Test.Reporter.Structured`** (`Test.Reporter.Structured.swift`):
   - JSONL output: one JSON object per line
   - Handles all event kinds with full serialization
   - Serializes `Test.Expectation.Failure` with expected/actual/diff
   - Serializes performance diagnostic custom events
   - Writes to file or stdout

2. **Implement plan record emission**:
   - Requires the structured reporter to receive the test plan
   - Option: the runner emits a `.planCreated` event (already exists) — enhance it to carry the plan data via the custom event mechanism
   - Or: the structured reporter receives the plan separately at construction time

3. **Implement summary record emission**:
   - Post-run action that serializes aggregated results
   - Include failure list, performance summary, pass/fail/skip counts, total duration

4. **Serialize existing rich data**:
   - `Test.Expectation.Failure.expected` and `.actual` as strings
   - `Test.Expectation.Failure.difference` as plaintext (truncated at 2000 chars)
   - `Test.Expectation.Failure.comment` as string
   - `Test.Expression.sourceCode` and `.sourceLocation`
   - Allocation stats in performance diagnostics

**Files changed**:
- `Test.Reporter.Structured.swift` — new file (Tests Reporter module)
- `Test.Reporter.JSON.swift` — may be superseded or refactored
- `Testing.Main.swift` — updated reporter selection

### Phase 3: Test Run Metadata (Area 4)
**Priority**: High. Enables reproducibility.
**Scope**: L3 (swift-tests, swift-testing).

1. **Capture git metadata at run start**:
   - Shell out to `git rev-parse HEAD` and `git branch --show-current`
   - Check dirty state with `git status --porcelain`
   - Best-effort: nil if git unavailable

2. **Emit plan record with metadata**:
   - Schema version, timestamp, git state, environment, test plan, counts
   - Environment is already captured by `Test.Environment.capture()`

3. **Emit summary record with metadata**:
   - Total duration, result counts, failure list, performance summary

**Files changed**:
- `Test.Git.swift` — new file (Tests Performance or Tests Core) for git metadata capture
- `Test.Reporter.Structured.swift` — plan and summary record serialization
- `Testing.Main.swift` — pass git metadata to the reporter

### Phase 4: Test.ID Hierarchy Fix (Area 9)
**Priority**: Medium. Improves data quality.
**Scope**: L1 (swift-test-primitives) + L3 (swift-testing macros, swift-tests storage).

1. **Change `Test.ID.suite` from `String?` to `[String]`** (L1):
   - Update `fullyQualifiedName` property
   - Update `Comparable` conformance
   - Update `Codable` conformance

2. **Fix macro to thread enclosing types** (L3):
   - `@Suite` and `@Test` macros inspect enclosing type context via SwiftSyntax
   - Pass enclosing type names as suite path components

3. **Update storage paths** (L3):
   - `Tests.Baseline.Storage.path()` — use suite array elements as directory components
   - `Tests.History.Storage.path()` — same

**Files changed**:
- `Test.ID.swift` (L1) — suite type change
- `Testing Macros Implementation/` (L3) — macro context inspection
- `Tests.Baseline.Storage.swift` (L3) — path computation
- `Tests.History.Storage.swift` (L3) — path computation

### Phase 5: Failure History and Classification (Area 5)
**Priority**: Medium. High signal for LLM iteration.
**Scope**: L3 (swift-tests).

1. **Extend `Tests.History.Record` with result field**:
   - Add `result: Test.Event.Result` to the history record
   - Update serialization/deserialization

2. **Implement failure classification**:
   - Compare current result against last N history records
   - Classify as: `newRegression`, `knownFailure`, `flaky`, `newlyPassing`, `stable`

3. **Include classification in summary record**:
   - Each failure in the summary includes its classification

**Files changed**:
- `Tests.History.Record.swift` — add result field
- `Tests.History.Record+JSON.swift` — update serialization
- `Tests.History.Analysis.swift` — add failure classification
- `Test.Reporter.Structured.swift` — include classification in summary

### Phase 6: Functional Test Diagnostics (Area 10)
**Priority**: Low. Polish.
**Scope**: L3 (swift-tests).

1. **Capture per-test metadata** in the runner:
   - Duration (already captured via elapsed)
   - Expectation count (from `Test.Expectation.Collector.drain()`)
   - Issue count

2. **Include in testEnded event** (structured reporter):
   - `expectations_checked`, `expectations_failed`, `issues_recorded`, `duration_seconds`

3. **Include in summary record**:
   - Per-test row with all metadata

**Files changed**:
- `Test.Runner.swift` — capture metadata, emit enriched testEnded events
- `Test.Reporter.Structured.swift` — serialize per-test metadata

---

## Summary of L1 vs L3 Changes

| Change | Layer | File |
|--------|-------|------|
| `Test.ID.suite: [String]` | L1 | `Test.ID.swift` |
| All other changes | L3 | Various files in swift-tests, swift-testing |

The only L1 change is `Test.ID.suite` from `String?` to `[String]` (Phase 4). All other improvements are L3 (swift-tests, swift-testing). The existing L1 types (`Test.Event`, `Test.Event.Kind`, `Test.Expectation`, `Test.Issue`, `Test.Text`) are already rich enough to carry all the data we need. The `.custom(name:payload:)` event kind provides the extension point for diagnostics without L1 changes.

## Priority Ordering (LLM Value per Effort)

1. **Phase 1** (event stream fix) — Very High value, Low effort. Unblocks everything.
2. **Phase 2** (structured reporter) — Very High value, Medium effort. The core deliverable.
3. **Phase 3** (metadata) — Very High value, Medium effort. Enables reproducibility.
4. **Phase 5** (failure classification) — High value, Medium effort. Highest-signal data for LLM iteration.
5. **Phase 6** (functional diagnostics) — Medium value, Low effort. Easy win.
6. **Phase 4** (Test.ID hierarchy) — Medium value, Medium effort. Important but not urgent.
