# Remediation Prompt: Naming + Implementation Audit
<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: RECOMMENDATION
---
-->

Paste this into a new Claude Code chat to address the audit findings.

---

## Prompt

Read `Research/naming-implementation-audit-swift-tests-swift-testing.md` — this is the full audit of swift-tests and swift-testing against the `/naming` and `/implementation` skills. 88 violations identified, organized by priority.

Invoke `/naming` and `/implementation` before writing any code.

Work through the findings in priority order. For each priority group:

1. Read the relevant source files first
2. Apply fixes
3. Build both packages after each group to verify nothing breaks:
   - `cd swift-tests && swift build`
   - `cd swift-testing && swift build`
4. When a rename affects a public API, use the LSP `rename_symbol` tool to catch all references across both packages

**Specific guidance per priority:**

**Priority 1 (active defects):** Fix I15 (`reason.plainText` → `render(reason)`) and I9 (delete dead `nodeColumn` binding). These are trivial one-line fixes.

**Priority 2 (public compound types):** The macro implementation types (N33-N43) are the largest batch. These are internal to the macro target — no external consumers reference `ExpectMacro` directly. Rename to nested forms (`Expect.Macro`, etc). Watch for the `CompilerPlugin` conformance in Plugin.swift — it takes an array of type names that must match. For N1-N3 in swift-tests, I created these recently — rename freely. For N48 (`__Test*` ABI typealiases), evaluate whether renaming is feasible given macro codegen references — if not, document per [PATTERN-016] with a `// WORKAROUND` comment.

**Priority 3 (deprecated typealiases):** Delete N6-N9. Search for any remaining call sites first with `find_references`.

**Priority 4 (public compound methods):** These require careful renaming. `fromEnvironment()` → static property or init. `discoverFromSections()` → restructure. `outputFormat`/`outputPath` → consider an `Output` struct with `.format` and `.path` properties. For the `with*` scoping methods (N22-N25): the `with` prefix is standard Swift idiom — rename to `with(_:operation:)` where the argument type disambiguates, rather than eliminating the pattern.

**Priority 5 (private non-static compounds):** Lower priority. N27-N28 (`makePassingExpectation`/`makeFailingExpectation`) — these duplicate `Test.Expectation.passing()`/`.failing()` that already exist in `Test.Expectation+Factory.swift`. Consider deleting them and calling the factory methods directly.

**Priority 6 (implementation):** For `.rawValue` violations, the fix is usually to use `.description` or string interpolation (I2-I4), or to add an `==` operator / predicate (I16). For `Int(...)` conversions (I5-I8, I19), add boundary extensions or initializers. For unnecessary intermediate bindings (I10-I12, I21-I25), inline the expressions. The `import Foundation` (I1) can be deferred if `File_System` doesn't expose string-content read/write yet.

**Do NOT:**
- Change any public API in swift-test-primitives (Layer 1) — those types are upstream
- Break the macro expansion codegen — test with `swift build` after macro type renames
- Add new files unless a type rename requires it (e.g., moving a type into a new nesting namespace)
- Fix things not in the audit — scope is strictly the 88 findings

**Commit strategy:** One commit per priority group. Message format: `Fix [naming|implementation] violations: priority N — [brief description]`
