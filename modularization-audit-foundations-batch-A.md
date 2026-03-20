# Modularization Audit — Foundations Batch A

**Date**: 2026-03-20
**Scope**: 12 swift-foundations packages (HIGH + MEDIUM complexity)
**Rules**: MOD-001 through MOD-014, adapted for Layer 3 naming (Core = `{Domain} Core`, Umbrella = `{Domain}`, Test Support = `{Domain} Test Support`)

---

## Summary

| # | Package | Targets (src/test) | PASS | FAIL | N/A | Critical Findings |
|---|---------|-------------------|------|------|-----|-------------------|
| 1 | swift-translating | 9/7 | 5 | 6 | 3 | No Core, naming violations, umbrella has implementation |
| 2 | swift-tests | 8/1 | 10 | 2 | 2 | Variant external dep duplication, Tests Performance 45 files |
| 3 | swift-io | 7/7 | 6 | 5 | 3 | No Core (IO Primitives misnamed), umbrella has 42 impl files, depth=4, no MARK |
| 4 | swift-html-rendering | 5/1 | 8 | 3 | 3 | No Core target, naming diverges (HTML Renderable), no MARK |
| 5 | swift-markdown-html-rendering | 4/1 | 6 | 3 | 5 | No Core, no umbrella, Markdown HTML Rendering 59 files |
| 6 | swift-plist | 4/3 | 8 | 2 | 4 | Core named "Primitives" not "Core", umbrella has implementation |
| 7 | swift-testing | 4/2 | 9 | 2 | 3 | Umbrella has 8 impl files, macro target is special case |
| 8 | swift-async | 3/2 | 7 | 3 | 4 | No Core, Async Stream 55 files |
| 9 | swift-darwin | 3/0 | 5 | 3 | 6 | No Core, no umbrella, no tests, no test support |
| 10 | swift-dependencies | 3/1 | 9 | 1 | 4 | Good overall; trait usage is exemplary |
| 11 | swift-effects | 3/3 | 9 | 1 | 4 | Good overall; minor dep centralization gap |
| 12 | swift-file-system | 3/2 | 7 | 3 | 4 | Core named "Primitives" not "Core", no umbrella |

---

## Per-Package Compliance Tables

### 1. swift-translating (9 src, 7 test)

**Targets**: Language (1), Translated (2), TranslatedString (6), SinglePlural (2), Translating+Dependencies (3), Translating (7), Translating Platform (8), TranslatingTestSupport (1), Translations (3)

**Dependency graph**:
```
Language <- Translated <- TranslatedString
Language <- SinglePlural (also -> Translated, TranslatedString)
Language <- Translating+Dependencies (also -> Translated, TranslatedString, Dependencies)
Translating (umbrella re-exports all above)
Translating Platform (depends on almost everything + Translating)
Translations (depends on Translating)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | No Core target. `Translated` and `Language` share the base role but neither is a formal Core. |
| MOD-002 Ext Dep Central | **FAIL** | `Language` imports BCP 47 directly. `Translating+Dependencies` imports Dependencies directly. No central funnel. |
| MOD-003 Variant Decomp | PASS | Variants (Language, Translated, TranslatedString, SinglePlural) are independent along a clear decomposition axis (type -> string -> plural). |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | **FAIL** | `Translating` has 7 files including implementation code (String extensions, Translated.init overloads, TranslatedString operations). Should be re-export-only. |
| MOD-006 Dep Min | PASS | Individual target deps appear minimal. |
| MOD-007 Graph Shape | PASS | Max depth = 3 (Language -> Translated -> TranslatedString -> Translating). |
| MOD-008 Split Decision | PASS | Target sizes are reasonable (1-8 files each). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | **FAIL** | `TranslatingTestSupport` (1 file) has no dependencies -- it contains mock data (Dutch names) but does not depend on the umbrella or re-export anything. |
| MOD-012 Naming | **FAIL** | Multiple violations: `TranslatedString` (compound, no space), `TranslatingTestSupport` (compound, should be `Translating Test Support`), `SinglePlural` (compound, should be `Single Plural`), `Translating+Dependencies` (non-standard `+` syntax). |
| MOD-013 MARK | **FAIL** | 9 source targets, zero `// MARK:` comments in Package.swift. |
| MOD-014 Cross-Pkg Traits | PASS | Uses swift-dependencies directly (core dep for all consumers, trait not needed). |

**Detailed Findings**:

1. **F-TRANS-001** (MOD-012): Target names `TranslatedString`, `SinglePlural`, `TranslatingTestSupport` use compound identifiers without spaces. Per L3 convention these should be `Translated String`, `Single Plural`, `Translating Test Support`.
2. **F-TRANS-002** (MOD-012): `Translating+Dependencies` uses a `+` separator. Should be `Translating Dependencies` or a more descriptive name like `Translating Dependency Integration`.
3. **F-TRANS-003** (MOD-005): The `Translating` umbrella target contains 6 implementation files beyond `exports.swift`: `String.swift`, `Translated.init.swift`, `Translated.init (english non-optional).swift`, `TranslatedString.swift`, `[String].swift`, `[TranslatedString].swift`. These should be extracted into the appropriate variant targets.
4. **F-TRANS-004** (MOD-001): No formal Core. `Language` (1 file) serves as the effective base since most targets depend on it, but it is published as a standalone product rather than being an internal Core target.
5. **F-TRANS-005** (MOD-011): `TranslatingTestSupport` has zero dependencies (line 169: `.target(name: .translatingTestSupport)`). It should depend on the umbrella `Translating` and re-export it.

---

### 2. swift-tests (8 src, 1 test)

**Targets**: Tests Core (44), Tests Snapshot (12), Tests Inline Snapshot (9), Tests Performance (45), Tests Reporter (5), Tests (1 -- umbrella), Tests Apple Testing Bridge (4), Tests Test Support (2)

**Dependency graph**:
```
Tests Core
+-- Tests Snapshot -> Tests Inline Snapshot
|                     +-- Tests Apple Testing Bridge
+-- Tests Performance
+-- Tests Reporter
+-- Tests (umbrella: Core + Reporter + Snapshot + Performance)
Tests Test Support (depends on umbrella Tests)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | PASS | `Tests Core` (44 files) is the Core target. All other targets depend on it. |
| MOD-002 Ext Dep Central | **FAIL** | Tests Core re-exports some deps (Test Primitives, Set Primitives, etc.), but variants declare many external deps directly: Tests Snapshot adds File System, JSON, Kernel, Dependency Primitives; Tests Performance adds Sample Primitives, Time Primitives, Console, Kernel, Memory, Binary Primitives, Formatting Primitives, Dependency Primitives, Clocks, File System, JSON, Environment (10+ external deps). |
| MOD-003 Variant Decomp | PASS | Variants (Snapshot, Performance, Reporter) are independent. Tests Apple Testing Bridge depends on Tests Snapshot (documented: bridges Apple Testing <-> snapshot). |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | PASS | `Tests` target has only `exports.swift` (1 file). Re-exports Core + Reporter + Snapshot + Performance. |
| MOD-006 Dep Min | PASS | Each variant declares only what it needs. |
| MOD-007 Graph Shape | PASS | Max depth = 3 (Tests Core -> Tests Snapshot -> Tests Inline Snapshot -> Tests Apple Testing Bridge). |
| MOD-008 Split Decision | **FAIL** | Tests Core (44 files) and Tests Performance (45 files) are both large. Tests Performance may benefit from splitting (e.g., benchmark infrastructure vs. statistical analysis). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | PASS | No stdlib extensions mixed into Core. |
| MOD-011 Test Support | PASS | `Tests Test Support` published as library product, depends on umbrella `Tests`, re-exports upstream test supports (Test Primitives Test Support, Kernel Test Support, File System Test Support). Path: `Tests/Support`. |
| MOD-012 Naming | PASS | All names follow `Tests {Variant}` pattern. `Tests Core`, `Tests Snapshot`, etc. are correct for L3. |
| MOD-013 MARK | PASS | Has semantic `// MARK:` comments: Core, Snapshot, Inline Snapshot, Performance, Reporter, Umbrella, Apple Testing Bridge, Test Support, Tests. |
| MOD-014 Cross-Pkg Traits | PASS | No cross-package optional integrations identified. |

**Detailed Findings**:

1. **F-TESTS-001** (MOD-002): Tests Performance declares 10+ external dependencies that are not re-exported through Tests Core. This is defensible since Performance has a genuinely different dependency profile (time, memory, sampling, file I/O for benchmark persistence), but it violates the centralization principle. Consider whether the common deps (Kernel, Dependency Primitives, File System, JSON) should be re-exported through Core.
2. **F-TESTS-002** (MOD-008): Tests Core (44 files) and Tests Performance (45 files) are both above the 20-25 file guideline. Tests Core may be irreducible (foundational test types), but Tests Performance is a candidate for splitting along concern (benchmark runner vs. statistical reporters vs. benchmark fixtures).
3. **F-TESTS-003** (MOD-005): The umbrella `Tests` re-exports Core + Reporter + Snapshot + Performance but not Tests Inline Snapshot or Tests Apple Testing Bridge. This is likely intentional (inline snapshots require swift-syntax, bridge is Apple-specific), but should be documented.

---

### 3. swift-io (7 src, 7 test)

**Targets**: IO Primitives (7), IO Blocking (30), IO Blocking Threads (30), IO Events (72), IO Completions (51), IO (42), IO Test Support (3)

**Dependency graph**:
```
IO Primitives
+-- IO Blocking -> IO Blocking Threads
+-- IO Events -> IO Completions
+-- IO (depends on Blocking, Blocking Threads, Events, Completions + Pool, Hash, Ownership, Memory Pool, Array, Dictionary, Dependency)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | `IO Primitives` (7 files) serves the Core role but is named `Primitives` not `Core`. At L3, this should be `IO Core`. Additionally, it is published as a library product -- Core should be internal-only per MOD-001. |
| MOD-002 Ext Dep Central | **FAIL** | IO Primitives re-exports Kernel and Buffer Primitives. But every variant adds massive external dep lists: IO Blocking adds Systems, Clock, Ownership, Witnesses (4 external). IO Blocking Threads adds System, Ownership, Queue DoubleEnded, Queue, Dictionary, Array Fixed, Slab, Heap Fixed, Dependency (9 external). IO Events adds Kernel, Async, Buffer, Hash, Ownership, Heap Core, Memory Pool, Dictionary, Witness, Witnesses (10 external). IO Completions adds Kernel, Buffer, Memory, Dimension, Ownership, Dictionary, Witness, Witnesses (8 external). IO umbrella adds Pool, Hash, Ownership, Memory Pool, Array Fixed, Dictionary, Dependency (7 external). |
| MOD-003 Variant Decomp | PASS | Variants decompose along I/O model axis: Blocking (synchronous), Events (async/epoll/kqueue), Completions (io_uring). IO Blocking Threads depends on IO Blocking (documented delegation: threads build on blocking I/O). IO Completions depends on IO Events (documented: completion I/O shares event infrastructure). |
| MOD-004 Constraint Iso | N/A | IO types are not ~Copyable containers. |
| MOD-005 Umbrella | **FAIL** | `IO` target (42 files) contains massive implementation: IO.Executor, IO.Lane, IO.Handle, IO.Closure, IO.Backend, etc. This is NOT an umbrella -- it is a full implementation target that also re-exports. Either: (a) rename to `IO Executor` or similar, or (b) extract implementation to a new target and make IO a pure re-export umbrella. |
| MOD-006 Dep Min | PASS | Each variant declares deps it genuinely uses. The high counts reflect IO's inherent complexity. |
| MOD-007 Graph Shape | **FAIL** | Max depth = 4: IO Primitives -> IO Blocking -> IO Blocking Threads -> IO. Also: IO Primitives -> IO Events -> IO Completions -> IO. Both paths are depth 4 (counting from root to leaf). Exceeds the recommended max of 3. |
| MOD-008 Split Decision | **FAIL** | IO Events (72 files), IO Completions (51 files), IO (42 files), IO Blocking (30 files), IO Blocking Threads (30 files) -- all exceed the 20-25 file guideline. IO Events and IO Completions are the most significant concerns. |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | PASS | No stdlib extensions in Core-equivalent target. |
| MOD-011 Test Support | PASS | `IO Test Support` published as library product, depends on IO Blocking Threads + Kernel Test Support. Path: `Tests/Support`. Contains 3 files. |
| MOD-012 Naming | **FAIL** | `IO Primitives` should be `IO Core` at Layer 3. The `Primitives` suffix is reserved for Layer 1 packages. |
| MOD-013 MARK | **FAIL** | 7 source targets + 7 test targets = 14 total targets. Zero `// MARK:` comments in Package.swift. |
| MOD-014 Cross-Pkg Traits | PASS | No cross-package optional integrations. NIO integration noted as intentionally excluded (comment in Package.swift). |

**Detailed Findings**:

1. **F-IO-001** (MOD-005, CRITICAL): The `IO` target contains 42 implementation files (IO.Executor.*, IO.Handle.*, IO.Lane.*, IO.Closure.*, IO.Backend.*, etc.). This is the most significant modularization violation in the audit. The umbrella must be re-export-only. Recommended: create `IO Executor` target for the implementation, make `IO` a pure umbrella with only `exports.swift`.
2. **F-IO-002** (MOD-007): Depth 4 chains (Primitives -> Blocking -> Blocking Threads -> IO, and Primitives -> Events -> Completions -> IO). Consider whether Blocking Threads could depend directly on IO Primitives instead of through IO Blocking, or whether the IO umbrella's implementation should be at depth 3.
3. **F-IO-003** (MOD-008): IO Events has 72 source files. Consider splitting along epoll/kqueue platform boundaries or separating the event loop from event sources.
4. **F-IO-004** (MOD-002): Duplicated external deps across variants -- Ownership Primitives appears in IO Blocking, IO Blocking Threads, IO Events, IO Completions, and IO (5 targets). Dictionary Primitives appears in 4 targets. These should be centralized through Core re-exports.
5. **F-IO-005** (MOD-001): `IO Primitives` is published as a library product. Core should be internal-only.
6. **F-IO-006** (MOD-012): `IO Primitives` uses L1 naming. At L3, rename to `IO Core`.

---

### 4. swift-html-rendering (5 src, 1 test)

**Targets**: HTML Renderable (37), HTML Attributes Rendering (125), HTML Elements Rendering (125), HTML Rendering (1 -- umbrella), HTML Renderable Test Support (5)

**Dependency graph**:
```
HTML Renderable
+-- HTML Attributes Rendering (also -> HTML Standard Attributes)
    +-- HTML Elements Rendering (also -> HTML Standard Elements)
        +-- HTML Rendering (umbrella, re-exports Attributes + Elements)
HTML Renderable Test Support (depends on HTML Renderable, trait-gated Test Snapshot Primitives)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | No explicit Core target. `HTML Renderable` (37 files) serves the Core role but is named by concept rather than convention. |
| MOD-002 Ext Dep Central | PASS | HTML Renderable centralizes external deps (Rendering Primitives, ASCII, ISO 9899, W3C CSS Shared, HTML Standard, Dictionary Primitives). Variant targets add only HTML Standard sub-products (Attributes, Elements) which are genuinely different. |
| MOD-003 Variant Decomp | PASS | Linear chain: Renderable -> Attributes -> Elements -> Rendering. Not strictly independent, but the chain matches the HTML specification structure (base -> attributes -> elements). Documented delegation. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | PASS | `HTML Rendering` (1 file) contains only `@_exported import HTML_Attributes_Rendering` and `@_exported import HTML_Elements_Rendering`. Pure re-export. |
| MOD-006 Dep Min | PASS | Deps are minimal per target. |
| MOD-007 Graph Shape | PASS | Max depth = 3 (HTML Renderable -> HTML Attributes Rendering -> HTML Elements Rendering -> HTML Rendering). Exactly at limit. |
| MOD-008 Split Decision | **FAIL** | HTML Attributes Rendering (125 files) and HTML Elements Rendering (125 files) are extremely large. These likely have one file per attribute/element (which follows one-type-per-file [API-IMPL-005]), but the target size is far above 20-25. Consider sub-grouping by HTML specification section. |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | PASS | `HTML Renderable Test Support` published as library product. Uses trait-gated test dependency (`Testing` trait). Path: `Tests/Support`. |
| MOD-012 Naming | **FAIL** | `HTML Renderable` should be `HTML Rendering Core` for consistency with L3 naming. The current name describes the protocol/concept rather than the target's role. |
| MOD-013 MARK | **FAIL** | 5 source targets + 1 test target = 6 total targets. Zero `// MARK:` comments in Package.swift. |
| MOD-014 Cross-Pkg Traits | PASS | Uses SE-0450 trait (`Testing`) correctly for test support's dependency on Test Snapshot Primitives. Exemplary implementation. |

**Detailed Findings**:

1. **F-HTML-001** (MOD-008): HTML Attributes Rendering and HTML Elements Rendering each have 125 files. While each file likely contains one HTML attribute/element rendering conformance (following [API-IMPL-005]), the module size impacts compile time. Consider splitting by HTML spec section (e.g., forms, metadata, text, media).
2. **F-HTML-002** (MOD-014, POSITIVE): The `Testing` trait usage for test support is exemplary. The trait gates the Test Snapshot Primitives dependency, and `#if TESTING` conditionally compiles test-only code. This pattern should be adopted by other packages.
3. **F-HTML-003** (MOD-001): `HTML Renderable` functions as Core but is not named as such. It holds the namespace, foundational protocols, and external dep re-exports.

---

### 5. swift-markdown-html-rendering (4 src, 1 test)

**Targets**: SwiftMarkdown (1), Markdown HTML Rendering (59), Markdown Previews (2), Markdown HTML Rendering Test Support (1)

**Dependency graph**:
```
SwiftMarkdown (wraps Apple swift-markdown)
+-- Markdown HTML Rendering (also -> HTML Rendering, CSS, CSS Theming, OrderedCollections)
    +-- Markdown Previews
Markdown HTML Rendering Test Support (depends on Markdown HTML Rendering, re-exports Testing)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | No Core target. `SwiftMarkdown` (1 file) is a thin wrapper, not a Core. `Markdown HTML Rendering` (59 files) has all the logic. |
| MOD-002 Ext Dep Central | N/A | Only 2 targets with external deps. SwiftMarkdown wraps one external (Apple Markdown). Markdown HTML Rendering declares 4 externals. No duplication since targets are independent. |
| MOD-003 Variant Decomp | PASS | Markdown Previews depends on Markdown HTML Rendering (documented delegation: previews build on rendering). SwiftMarkdown is independent. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | **FAIL** | No umbrella target exists. There is no single target that re-exports everything. `Markdown HTML Rendering` is the main product but has 59 implementation files -- not a pure re-export. |
| MOD-006 Dep Min | PASS | Deps are minimal. |
| MOD-007 Graph Shape | PASS | Max depth = 2 (SwiftMarkdown -> Markdown HTML Rendering -> Markdown Previews). |
| MOD-008 Split Decision | **FAIL** | Markdown HTML Rendering (59 files) significantly exceeds the 20-25 file guideline. Consider splitting by Markdown node type (block vs. inline) or by rendering concern (layout vs. styling). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | PASS | `Markdown HTML Rendering Test Support` published as library product. 1 file (exports.swift). Path: `Tests/Support`. |
| MOD-012 Naming | PASS | Names follow `Markdown {Variant}` pattern. `SwiftMarkdown` is a thin external wrapper -- naming is defensible. |
| MOD-013 MARK | N/A | Only 4 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-MDREND-001** (MOD-008): Markdown HTML Rendering has 59 files. Should investigate splitting by Markdown construct type (block-level rendering vs. inline rendering vs. code highlighting).
2. **F-MDREND-002** (MOD-005): No umbrella. Since there is only one main product (`Markdown HTML Rendering`) plus a supplement (`Markdown Previews`), an umbrella `Markdown Rendering` that re-exports both may be appropriate.
3. **F-MDREND-003** (MOD-011): Test Support exports `@_exported public import Testing` -- this re-exports the entire swift-testing `Testing` module. This is an unusually broad re-export for a test support target. The dependency on `Testing` is not even declared in Package.swift -- it comes transitively through Markdown HTML Rendering's dependency chain, which is fragile.

---

### 6. swift-plist (4 src, 3 test)

**Targets**: Plist Primitives (15), Plist XML (4), Plist Binary (6), Plist (4 -- umbrella with implementation)

**Dependency graph**:
```
Plist Primitives
+-- Plist XML (also -> XML, RFC 4648, ISO 8601)
+-- Plist Binary
+-- Plist (depends on Primitives, XML, Binary + Async)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | `Plist Primitives` (15 files) serves as Core but uses L1 naming (`Primitives`). At L3, should be `Plist Core`. Not published as internal-only -- it is a product. |
| MOD-002 Ext Dep Central | PASS | Plist Primitives has no external deps. Plist XML brings in XML, RFC 4648, ISO 8601 (specific to XML parsing). Plist Binary has no external deps. External deps are where they need to be. |
| MOD-003 Variant Decomp | PASS | XML and Binary are independent format variants, both depending on Plist Primitives. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | **FAIL** | `Plist` (4 files) contains implementation code: `Plist.Parse.swift`, `Plist.Stream.swift`, `Plist.Parse.Accessor.swift` in addition to `exports.swift`. Auto-detection/routing logic lives here. Should be re-export-only with routing logic in a separate target. |
| MOD-006 Dep Min | PASS | Deps are minimal and justified. |
| MOD-007 Graph Shape | PASS | Max depth = 2 (Plist Primitives -> Plist XML/Binary -> Plist). |
| MOD-008 Split Decision | PASS | All targets have reasonable file counts (4-15). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | N/A | No test support product. Acceptable -- plist types are simple enough to construct in tests without fixtures. |
| MOD-012 Naming | **FAIL** | `Plist Primitives` uses L1 naming. At L3, should be `Plist Core`. |
| MOD-013 MARK | N/A | Only 4 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-PLIST-001** (MOD-005): The `Plist` umbrella has 3 implementation files. `Plist.Parse.swift` contains format auto-detection and routing to XML/Binary parsers. `Plist.Stream.swift` and `Plist.Parse.Accessor.swift` add streaming and accessor APIs. These should either: (a) move into Plist Primitives (if format-agnostic), or (b) become a new `Plist Routing` target.
2. **F-PLIST-002** (MOD-012): `Plist Primitives` should be `Plist Core` at L3.

---

### 7. swift-testing (4 src, 2 test)

**Targets**: Testing Core (10 -- path: `Sources/Testing`), Testing (8 -- umbrella, path: `Sources/Testing Umbrella`), Testing Macros Implementation (6 -- macro), Testing Effects (2), Testing Test Support (2)

Note: The macro target `Testing Macros Implementation` is a `.macro` type, which has special compilation rules.

**Dependency graph**:
```
Testing Core
+-- Testing (umbrella, also -> Testing Macros Implementation + SwiftSyntax)
+-- Testing Effects (also -> Effects, Effects Testing)
+-- Testing Test Support (also -> Tests Test Support)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | PASS | `Testing Core` (10 files) is properly named and serves as the Core. All other targets depend on it. |
| MOD-002 Ext Dep Central | PASS | Testing Core re-exports Tests, Dependencies, Time Primitives, etc. Variants add only their specific externals (Effects, SwiftSyntax). |
| MOD-003 Variant Decomp | PASS | Testing Effects is independent of the umbrella. Testing Macros Implementation is independent (compiler plugin). |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | **FAIL** | `Testing` umbrella (8 files) contains implementation code: `Require.swift`, `Test.swift`, `Suite.swift`, `Testing.XCTestBridge.swift`, `Tests.swift`, `Expect.swift`, `Testing.AssertMacroExpansion.swift` plus `exports.swift`. These are macro declarations and bridge code that must coexist with the Testing_Core namespace. This may be a justified exception since macro declarations must live in the module that declares `@_exported import` of the macro implementation. |
| MOD-006 Dep Min | PASS | Deps are minimal. |
| MOD-007 Graph Shape | PASS | Max depth = 2 (Testing Core -> Testing / Testing Effects / Testing Test Support). |
| MOD-008 Split Decision | PASS | All targets have reasonable file counts (2-10). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | PASS | `Testing Test Support` published as library product. Depends on Testing Core + Tests Test Support. Path: `Tests/Support`. |
| MOD-012 Naming | PASS | Names follow `Testing {Variant}` pattern. Core, Effects, Test Support all correct for L3. |
| MOD-013 MARK | **FAIL** | 5 effective source targets (including macro). Zero `// MARK:` comments in Package.swift. There are comments (e.g., `// UMBRELLA TARGET`, `// Core implementation`) but they are not using `// MARK: -` format. |
| MOD-014 Cross-Pkg Traits | PASS | No trait-gated integrations. |

**Detailed Findings**:

1. **F-TESTING-001** (MOD-005): The `Testing` umbrella has 7 implementation files. This is a justified exception: macro declarations (`@Test`, `@Suite`, `#expect`, `#require`) must be in the same module as their `@_exported import Testing_Macros_Implementation`. The umbrella legitimately needs these declarations to make `import Testing` provide both the macro and the Test namespace. Document this as an accepted deviation.
2. **F-TESTING-002** (MOD-013): While descriptive comments exist (e.g., `// UMBRELLA TARGET - what users import as "Testing"`), they do not use the `// MARK: -` format specified by MOD-013.

---

### 8. swift-async (3 src, 2 test)

**Targets**: Async Sequence (9), Async Stream (55), Async (1 -- umbrella)

**Dependency graph**:
```
Async Sequence (-> Async Primitives)
Async Stream (-> Async Primitives, Buffer Primitives, Clocks, Clocks Dependency, Reference Primitives)
Async (umbrella: re-exports Async Primitives + Async Sequence + Async Stream)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | No Core target. `Async Sequence` and `Async Stream` both independently depend on `Async Primitives` (L1). There is no intra-package Core that centralizes shared types. |
| MOD-002 Ext Dep Central | **FAIL** | Both variants independently import `Async Primitives`. `Async Stream` adds 4 more external deps. No centralization funnel. |
| MOD-003 Variant Decomp | PASS | `Async Sequence` and `Async Stream` are fully independent. Clean decomposition along async pattern axis. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | PASS | `Async` (1 file: `Async.swift`) contains only `@_exported public import` statements for Async Primitives, Async Sequence, and Async Stream. Pure re-export. |
| MOD-006 Dep Min | PASS | Both variants declare only deps they need. |
| MOD-007 Graph Shape | PASS | Max depth = 1 (Async Sequence/Stream -> Async). Flat star topology. |
| MOD-008 Split Decision | **FAIL** | Async Stream has 55 files (operators, state types, iterators). This exceeds the guideline. Could split by operator category (combination, timing, buffering, transformation). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | N/A | No test support product. May be acceptable if async types do not need downstream test fixtures. |
| MOD-012 Naming | PASS | Names follow `Async {Variant}` pattern. `Async Sequence`, `Async Stream`, `Async` are correct for L3. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-ASYNC-001** (MOD-008): Async Stream has 55 files covering many reactive operators (CombineLatest, Debounce, FlatMap, Merge, Replay, Sample, Throttle, Timer, Zip, etc.). Each operator has its own state machine type. Consider splitting into `Async Stream Core` (base + iterator + buffer) and `Async Stream Operators` (all operator types).
2. **F-ASYNC-002** (MOD-001): No Core target. With only 2 variants that share Async Primitives externally, a Core may not add much value. This is a borderline case -- the package is small enough that a Core target may be over-engineering.

---

### 9. swift-darwin (3 src, 0 test)

**Targets**: Darwin Kernel (2), Darwin Loader (1), Darwin System (8)

**Dependency graph**:
```
Darwin Kernel (-> Darwin Primitives, Darwin Kernel Primitives, Random Primitives, POSIX Kernel)
Darwin Loader (-> Darwin Primitives, Darwin Loader Primitives, POSIX Loader)
Darwin System (-> Darwin Primitives, Kernel Primitives, System Primitives)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | No Core target. All three targets independently depend on `Darwin Primitives`. |
| MOD-002 Ext Dep Central | **FAIL** | `Darwin Primitives` is imported by all three targets independently. No funnel. |
| MOD-003 Variant Decomp | PASS | All three targets are fully independent. Clean decomposition along OS subsystem axis (kernel, loader, system). |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | **FAIL** | No umbrella target. There is no `Darwin` target that re-exports all three. |
| MOD-006 Dep Min | PASS | Each target has minimal, justified deps. |
| MOD-007 Graph Shape | PASS | Max depth = 0 (all independent). Flat topology. |
| MOD-008 Split Decision | PASS | All targets have reasonable file counts (1-8). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | N/A | No test support product. Concerning given there are also zero test targets. |
| MOD-012 Naming | PASS | Names follow `Darwin {Variant}` pattern. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-DARWIN-001**: Zero test targets. No tests at all for Darwin Kernel, Darwin Loader, or Darwin System. This is a testing gap (not a modularization rule per se, but [TEST-001] likely applies).
2. **F-DARWIN-002** (MOD-005): No umbrella. Adding `Darwin` as a re-export umbrella would allow consumers to `import Darwin_Kernel`, `import Darwin_Loader`, `import Darwin_System` individually, or `import Darwin` for everything.
3. **F-DARWIN-003** (MOD-001): No Core. `Darwin Primitives` is imported by all three targets -- a `Darwin Core` target that re-exports `Darwin Primitives` would centralize this.

---

### 10. swift-dependencies (3 src, 1 test)

**Targets**: Dependencies (10), Dependencies Test Support (5), Clocks Dependency (1)

**Dependency graph**:
```
Dependencies (-> Witnesses, Environment)
+-- Dependencies Test Support
+-- Clocks Dependency (-> Clock Primitives, trait-gated)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | PASS | `Dependencies` (10 files) is the Core. All targets depend on it. |
| MOD-002 Ext Dep Central | PASS | Dependencies re-exports Witnesses. Clocks Dependency adds Clock Primitives with trait gate (justified: different dep set). |
| MOD-003 Variant Decomp | PASS | Clocks Dependency is independent of Test Support. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | N/A | Only one main product. No umbrella needed. |
| MOD-006 Dep Min | PASS | Minimal deps throughout. |
| MOD-007 Graph Shape | PASS | Max depth = 1. |
| MOD-008 Split Decision | PASS | All targets have reasonable file counts (1-10). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | PASS | `Dependencies Test Support` published as library product. 5 files. Depends on Dependencies, re-exports it. Path: `Tests/Support`. |
| MOD-012 Naming | PASS | Names follow L3 convention. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | **PASS** (exemplary) | `Clocks` trait gates the Clock Primitives dependency on the Clocks Dependency target. This is the canonical example from MOD-014's specification. |

**Detailed Findings**:

1. **F-DEPS-001** (POSITIVE): This package is the reference implementation for MOD-014. The `Clocks` trait, `Clocks Dependency` integration target, and consumer opt-in pattern are exactly as specified. No findings.

---

### 11. swift-effects (3 src, 3 test)

**Targets**: Effects (3), Effects Built-in (3), Effects Testing (5)

**Dependency graph**:
```
Effects (-> Effect Primitives, Dependency Primitives)
+-- Effects Built-in (also -> Witness Primitives)
+-- Effects Testing (also -> Async Primitives, Clocks)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | PASS | `Effects` (3 files) is the Core. Both variants depend on it. |
| MOD-002 Ext Dep Central | **FAIL** | Effects re-exports Effect Primitives and Dependency Primitives. But Effects Built-in adds Witness Primitives independently, and Effects Testing adds Async Primitives and Clocks independently. These are genuinely different deps, so this is a borderline case. |
| MOD-003 Variant Decomp | PASS | Built-in and Testing are independent. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | N/A | Only one main Core product. Built-in and Testing are variants, not an umbrella composition. An umbrella could be added but the package is small enough to not need one. |
| MOD-006 Dep Min | PASS | Each target declares only what it needs. |
| MOD-007 Graph Shape | PASS | Max depth = 1. |
| MOD-008 Split Decision | PASS | All targets have reasonable file counts (3-5). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | N/A | No test support product. Effects Testing serves a similar role but is a main product, not test support. |
| MOD-012 Naming | PASS | Names follow L3 convention: `Effects`, `Effects Built-in`, `Effects Testing`. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-EFFECTS-001** (MOD-002, minor): Effects Built-in adds `Witness Primitives` and Effects Testing adds `Async Primitives` + `Clocks` independently. These are genuinely variant-specific deps (not shared across variants), so the violation is borderline acceptable. The deps could be centralized through Core only if other targets would also use them, which they do not.

---

### 12. swift-file-system (3 src, 2 test)

**Targets**: File System Primitives (54), File System (32), File System Test Support (5)

**Dependency graph**:
```
File System Primitives (-> Environment, Kernel, Paths, Strings, Algebra Primitives, IO Primitives, Binary Primitives, ASCII, RFC 4648)
+-- File System (also -> IO)
File System Test Support (depends on File System Primitives, File System, Kernel, Kernel Test Support)
```

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | `File System Primitives` (54 files) serves as Core but uses L1 naming (`Primitives`). At L3, should be `File System Core`. Also published as library product (should be internal-only per MOD-001). |
| MOD-002 Ext Dep Central | PASS | File System Primitives centralizes external deps (9 externals). File System adds only `IO` (the full IO target, vs. Primitives' `IO Primitives`). |
| MOD-003 Variant Decomp | PASS | Only 2 implementation targets in a clear layered relationship. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | **FAIL** | No umbrella target. `File System` contains 32 files of implementation -- it is not an umbrella. There is no pure re-export target that combines File System Primitives + File System. |
| MOD-006 Dep Min | PASS | Deps are appropriate. |
| MOD-007 Graph Shape | PASS | Max depth = 1 (File System Primitives -> File System). |
| MOD-008 Split Decision | **FAIL** | File System Primitives (54 files) and File System (32 files) both exceed the 20-25 file guideline. File System Primitives could potentially split along concern (path operations, directory operations, file metadata, permissions). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | PASS | `File System Test Support` published as library product. 5 files. Depends on both source targets + Kernel Test Support. Re-exports File System, File System Primitives, Kernel, Kernel Test Support. Path: `Tests/Support`. |
| MOD-012 Naming | **FAIL** | `File System Primitives` uses L1 naming. At L3, should be `File System Core`. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-FS-001** (MOD-012): `File System Primitives` should be `File System Core` at L3. The `Primitives` suffix implies a Layer 1 package.
2. **F-FS-002** (MOD-008): File System Primitives has 54 files and File System has 32 files. Both are above guideline. File System Primitives likely contains path operations, directory traversal, file metadata, permissions -- these may warrant decomposition.
3. **F-FS-003** (MOD-001): `File System Primitives` is published as a library product. If it truly serves as Core, it should be internal-only (consumed only by the `File System` product and downstream packages via File System's re-exports).
4. **F-FS-004** (MOD-005): No umbrella exists. `File System` is a substantial implementation target (32 files), not a re-export umbrella.

---

## Cross-Cutting Themes

### 1. L1 Naming in L3 Packages (MOD-012)

Three packages use `{Domain} Primitives` for their Core-equivalent target: swift-io (`IO Primitives`), swift-plist (`Plist Primitives`), swift-file-system (`File System Primitives`). At Layer 3, these should be `{Domain} Core`.

**Affected**: swift-io, swift-plist, swift-file-system

### 2. Umbrellas with Implementation (MOD-005)

Four packages have "umbrella" targets containing implementation code:

| Package | Target | Impl Files | Justified? |
|---------|--------|-----------|------------|
| swift-io | IO | 42 | NO -- Executor/Lane/Handle infrastructure should be a separate target |
| swift-translating | Translating | 6 | NO -- String extensions and init overloads should move to variant targets |
| swift-plist | Plist | 3 | BORDERLINE -- format routing logic may justify living above variants |
| swift-testing | Testing | 7 | YES -- macro declarations must coexist with @_exported imports |

### 3. Large Targets (MOD-008)

Targets exceeding the 20-25 file guideline:

| Package | Target | Files | Splitting Candidate? |
|---------|--------|-------|---------------------|
| swift-html-rendering | HTML Attributes Rendering | 125 | YES -- by HTML spec section |
| swift-html-rendering | HTML Elements Rendering | 125 | YES -- by HTML spec section |
| swift-io | IO Events | 72 | YES -- by platform (epoll/kqueue) |
| swift-markdown-html-rendering | Markdown HTML Rendering | 59 | YES -- by node type |
| swift-async | Async Stream | 55 | YES -- by operator category |
| swift-file-system | File System Primitives | 54 | YES -- by concern |
| swift-io | IO Completions | 51 | MAYBE -- may be one coherent concern |
| swift-tests | Tests Performance | 45 | YES -- by performance concern |
| swift-tests | Tests Core | 44 | MAYBE -- may be irreducible |
| swift-io | IO | 42 | YES -- extract executor to separate target |
| swift-html-rendering | HTML Renderable | 37 | MAYBE |
| swift-file-system | File System | 32 | MAYBE |
| swift-io | IO Blocking | 30 | MAYBE |
| swift-io | IO Blocking Threads | 30 | MAYBE |

### 4. Missing MARK Comments (MOD-013)

Packages with 5+ targets missing `// MARK: -` comments:

- swift-translating (9 targets): NO MARK comments
- swift-io (14 targets): NO MARK comments
- swift-html-rendering (6 targets): NO MARK comments
- swift-testing (6 targets): Has descriptive comments but not `// MARK: -` format

Only swift-tests has proper `// MARK: -` semantic groups.

### 5. External Dependency Duplication (MOD-002)

Most significant in swift-io where `Ownership Primitives` appears in 5/7 targets and `Dictionary Primitives` appears in 4/7 targets. Also notable in swift-tests where `Dependency Primitives` appears in 3 variant targets.

### 6. Positive Patterns

- **swift-dependencies**: Exemplary MOD-014 trait implementation (canonical reference)
- **swift-html-rendering**: Good trait usage for test support gating
- **swift-tests**: Only package with proper MARK comments
- **swift-effects**: Clean, minimal structure with independent variants

---

## Priority Remediation

### Critical (violates core modularization principles)

1. **F-IO-001**: Extract IO umbrella's 42 implementation files into `IO Executor` target
2. **F-TRANS-003**: Move Translating umbrella's 6 implementation files to variant targets
3. **F-IO-006 / F-PLIST-002 / F-FS-001**: Rename `{Domain} Primitives` to `{Domain} Core` in L3 packages

### High (material modularization impact)

4. **F-IO-003 / F-ASYNC-001 / F-MDREND-001**: Split large targets (IO Events 72, Async Stream 55, Markdown HTML Rendering 59)
5. **F-TRANS-004**: Add formal naming convention compliance (spaces in compound names)
6. **F-IO-002**: Address depth-4 chains in swift-io

### Medium (convention compliance)

7. Add `// MARK: -` comments to swift-translating, swift-io, swift-html-rendering, swift-testing
8. Centralize duplicated external deps through Core re-exports (swift-io, swift-tests)
9. Add umbrella targets to swift-darwin, swift-file-system
10. Add test targets to swift-darwin

### Low (polish)

11. Document the swift-testing umbrella exception (macro declarations)
12. Review whether swift-async needs a Core target or is acceptable as-is
13. Review Markdown HTML Rendering Test Support's broad re-export of Testing
