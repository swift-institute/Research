# atexit SIGBUS: Inline Snapshot Write-Back

<!--
---
version: 1.2.0
last_updated: 2026-04-01
status: RECOMMENDATION
tier: 1
---
-->

## Context

`swift test` in swift-tests crashes with `Exited with unexpected signal code 10` (SIGBUS)
before reporting results. The crash was introduced by commit `3c65508` which added an
`atexit` handler to `Test.Snapshot.Inline.State` that drains accumulated inline snapshot
entries and invokes `Rewriter.writeAll()` — a SwiftSyntax-based source file rewriter that
also imports Foundation.

Filtered test subsets pass (`--filter "Baseline"`, `--filter "JSON"`) because no inline
snapshot assertions execute, so `register()` is never called and the `atexit` handler is
never installed.

The `atexit` handler was added to support inline snapshot write-back when tests run under
Apple's Swift Testing runner, which does not call the Institute's `Test.Runner.postRunActions`.
The Institute's runner already has a correct drain path via `postRunActions` (registered in
`Testing.Main`, lines 120–130).

**Trigger**: [RES-001] — implementation blocked by runtime crash requiring design analysis.

## Question

How should inline snapshot write-back work under **both** the Institute's `Test.Runner`
and Apple's Swift Testing runner, without crashing at process exit?

## Constraints

1. **No process-level hook in Swift Testing.** `TestScoping` scopes per-suite or per-test
   only. A GSoC 2026 proposal for globally scoped traits is in early discussion but not
   available. ([swift-testing #36](https://github.com/swiftlang/swift-testing/issues/36),
   [forums](https://forums.swift.org/t/gsoc-2026-question-regarding-globally-scoped-traits-for-swift-testing/85082))

2. **Point-Free uses the identical pattern.** `swift-snapshot-testing` also uses
   `atexit` + SwiftSyntax rewriting. They may not have hit this crash, or may have a
   different module loading topology that avoids it.

3. **SIGBUS (signal 10) during shutdown** is consistent with accessing memory that has
   been unmapped — the Swift runtime and/or dyld may tear down globals, unload dylibs,
   or unmap mmap'd regions before `atexit` handlers complete. `Rewriter.writeAll` imports
   SwiftParser, SwiftSyntax, SwiftSyntaxBuilder, and Foundation — any of these could have
   global state that is torn down before the handler runs.

4. **The Institute's runner path works correctly.** `postRunActions` executes in a
   well-defined point during the test lifecycle, before process exit begins. This path
   must be preserved unchanged.

5. **Inline snapshot write-back is inherently batch.** Source files should be rewritten
   once per file (not once per assertion) to avoid repeated parsing.

6. **Root cause is suspected but not yet confirmed.** The handoff identifies the atexit
   handler as the likely cause. Confirmation (commenting out the handler and re-running)
   should precede any fix.

7. **The Institute has a custom `__swiftPMEntryPoint()`** in a module named `Testing`
   (`swift-testing/Sources/Testing/Testing.Main.swift`). SwiftPM discovers this and uses
   it instead of Apple's default runner. The custom entry point creates a `Test.Runner`
   and registers the inline snapshot drain as a `postRunAction` (lines 120–130). This
   means **all test targets that `import Testing` already go through the correct drain
   path** — the `atexit` handler is only needed for code paths that bypass the custom
   entry point entirely.

8. **The atexit handler is unsafe even for empty state.** The handler accesses the global
   `Test.Snapshot.Inline.state` and calls `isEmpty` (which acquires a `Mutex`). If the
   Swift runtime has torn down the global's memory or the `Mutex` backing store by the
   time `atexit` runs, this alone causes SIGBUS — regardless of whether entries exist.

9. **Apple's `.runEnded` event** fires exactly once after all tests complete, from a
   `defer` block in `Runner.run()` (swift-testing `Runner.swift:493`). It is posted to
   `Configuration.eventHandler`, which is only settable by tools (SwiftPM), not by
   libraries. This event cannot be intercepted from user code without SPI access.

## Analysis

### Option A: Remove `atexit`, No Write-Back Under Apple's Runner

Remove the `atexit` handler entirely. Under the Institute's runner, `postRunActions`
handles write-back. Under Apple's Swift Testing runner, inline snapshot write-back
simply does not happen.

| Criterion | Assessment |
|-----------|------------|
| Crash fix | Yes — removes the crashing code |
| Institute runner | Works — `postRunActions` unchanged |
| Apple runner | **No write-back** — snapshots are lost |
| Complexity | Minimal — deletion only |
| User experience | Degraded under Apple's runner |

### Option B: Serialize Entries in `atexit`, Defer SwiftSyntax to Next Run

Replace the `atexit` handler's call to `Rewriter.writeAll()` with a lightweight
serialization step that writes entries to a known file path (e.g.,
`.build/inline-snapshots-pending.json`) using only POSIX I/O or minimal Swift. The
next test run (or the Institute's runner, or a CLI tool) reads this file and applies
the SwiftSyntax rewrites **before** tests execute.

| Criterion | Assessment |
|-----------|------------|
| Crash fix | Yes — avoids SwiftSyntax/Foundation at exit |
| Institute runner | Works — `postRunActions` drains first; atexit sees empty state |
| Apple runner | **Deferred write-back** — rewrites apply on next run |
| Complexity | Medium — needs serialize/deserialize, startup check, cleanup |
| User experience | Same re-run count (inline snapshots already require re-run) |

**Risk**: Even basic Swift operations (Mutex lock, String creation, Dictionary iteration)
in an `atexit` handler may be unsafe if the Swift runtime is being torn down. POSIX-level
I/O (`open`/`write`/`close`) with pre-formatted data would be safest but requires careful
implementation.

### Option C: Non-Recursive `SuiteTrait` with Reference-Counted Drain

Create a `SuiteTrait & TestScoping` that:
- Increments a global atomic counter on `provideScope` entry
- Decrements on exit
- When the counter reaches zero and state is non-empty, triggers write-back

Apply the trait to every suite that uses inline snapshots.

| Criterion | Assessment |
|-----------|------------|
| Crash fix | Yes — runs during normal execution, not at exit |
| Institute runner | Works — `postRunActions` drains first; trait sees empty state |
| Apple runner | Works — but **only for opted-in suites** |
| Complexity | High — requires opt-in, counter management, race conditions |
| User experience | Good for opted-in suites; entries from non-opted suites are lost |

**Problem**: Requires every suite using inline snapshots to explicitly opt in via
`.inlineSnapshots()` or similar. Forgetting the trait means entries are silently orphaned.
The reference counter has a race window between "last suite exits" and "all entries are
accumulated" if tests register entries during teardown of other suites.

### Option D: Per-Test Write-Back via `TestTrait & TestScoping`

Create a `TestTrait & TestScoping` that checks for pending entries after each test case
completes and writes them back immediately.

| Criterion | Assessment |
|-----------|------------|
| Crash fix | Yes — runs during normal execution |
| Institute runner | Works — `postRunActions` becomes redundant |
| Apple runner | Works — **if trait is applied to every test** |
| Complexity | High — per-test overhead, repeated file parsing, opt-in required |
| User experience | Slow for files with many snapshot assertions |

**Problem**: Rewrites the same source file once per assertion rather than once per file.
Requires universal opt-in. Fundamentally changes the batch model.

### Option E: Eagerly Write Back in `register()` Itself

Instead of accumulating entries, write back immediately when each entry is registered.
This eliminates the need for any post-run drain mechanism.

| Criterion | Assessment |
|-----------|------------|
| Crash fix | Yes — no deferred state to drain |
| Institute runner | Works — `postRunActions` becomes no-op |
| Apple runner | Works — no opt-in needed |
| Complexity | Medium — per-assertion SwiftSyntax parsing |
| User experience | **Slow** — parses each file per assertion. Concurrent tests writing to same file need serialization. |

**Problem**: Destroys the batch model. A file with 10 assertions gets parsed and rewritten
10 times. Concurrent tests in different files would be fine, but concurrent tests in the
same file need file-level locking to avoid data races.

### Comparison

| Criterion | A: Remove | B: Serialize + Defer | C: SuiteTrait | D: Per-Test | E: Eager |
|-----------|-----------|---------------------|---------------|-------------|----------|
| Fixes crash | ✓ | ✓ | ✓ | ✓ | ✓ |
| Institute runner | ✓ | ✓ | ✓ | ✓ | ✓ |
| Apple runner write-back | ✗ | ✓ (deferred) | ✓ (opt-in) | ✓ (opt-in) | ✓ |
| No opt-in required | ✓ | ✓ | ✗ | ✗ | ✓ |
| Batch efficiency | ✓ | ✓ | ✓ | ✗ | ✗ |
| Implementation complexity | Minimal | Medium | High | High | Medium |
| Runtime safety | ✓ | Needs care | ✓ | ✓ | ✓ |

## Recommendation

**Option B (Serialize + Defer)** is the strongest overall, but carries risk that even
the serialization step may be unsafe in `atexit` if the Swift runtime is partially torn
down. This needs empirical verification.

**Pragmatic two-phase approach**:

1. **Immediate (unblocks testing)**: Option A — remove the `atexit` handler. This is a
   one-line fix that eliminates the crash. The Institute's runner path is unaffected.
   Under Apple's runner, inline snapshot write-back is temporarily unavailable.

2. **Follow-up (restores Apple runner support)**: Option B — implement deferred write-back
   via a manifest file. The `atexit` handler writes a minimal manifest (file paths + line
   numbers + snapshot values) using the simplest possible I/O. The Institute's runner (or
   a startup check) reads and applies it. This should be a separate commit/PR after the
   crash is confirmed fixed.

   If Option B proves unsafe (Swift runtime teardown prevents even simple serialization
   in `atexit`), fall back to Option C with a `SuiteTrait` and clear documentation that
   suites using inline snapshots must apply the trait.

## Next Steps

1. **Confirm root cause**: Comment out the `atexit` handler and `_ = Self._installExitHandler`,
   run `swift test`, verify crash disappears.
2. **Apply Option A**: Remove the handler, update doc comments, commit.
3. **Experiment**: Test whether POSIX `write()` from an `atexit` handler is reliable in
   a Swift test process. If yes, prototype Option B.
4. **Implement Option B or C** as a follow-up.

## References

- [swift-testing #36 — After-all hook](https://github.com/swiftlang/swift-testing/issues/36) (closed, resolved by TestScoping)
- [SWT-0007 — Test Scoping Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0007-test-scoping-traits.md) (Swift 6.1)
- [GSoC 2026 — Globally Scoped Traits proposal](https://forums.swift.org/t/gsoc-2026-question-regarding-globally-scoped-traits-for-swift-testing/85082)
- [Point-Free swift-snapshot-testing `atexit` pattern](https://github.com/pointfreeco/swift-snapshot-testing/blob/main/Sources/InlineSnapshotTesting/AssertInlineSnapshot.swift)
- Commit `3c65508` — introduced the `atexit` handler in swift-tests
