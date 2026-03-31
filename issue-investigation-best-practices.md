# Issue Investigation Best Practices: Literature Study and Comparative Analysis

**Date**: 2026-03-31
**Status**: Complete
**Purpose**: Strengthen the `issue-investigation` skill with evidence-based practices from compiler communities, academic research, and Swift-specific tooling.
**Provenance**: Research handoff from `HANDOFF-issue-investigation-research.md`.

---

## A. Literature and Comparative Analysis

### A.1 Compiler Bug Investigation Across Ecosystems

#### Universal Pipeline

All four major compiler ecosystems converge on the same investigation pipeline:

```
Report --> Minimize --> Bisect --> Dump IR --> Identify root cause --> Fix --> Regression test
```

The ordering varies (sometimes bisection precedes minimization), but these are the universal building blocks. Every ecosystem treats test case minimization as a prerequisite for serious investigation, not an optional nicety.

#### Rust (rustc)

The Rust compiler team operates a structured triage centered on GitHub issues with a well-defined label taxonomy:

- **Priority labels**: `P-critical`, `P-high`, `P-medium`, `P-low`
- **Category labels**: `C-bug`, `I-ICE` (Internal Compiler Error), `A-*` area tags
- **Regression labels**: `regression-from-stable-to-*` receive elevated priority
- **Weekly triage meetings** in the `rust-lang/compiler-team` repository

**ICE tracking** is a specific, well-tracked category. ICEs are always-bugs (the compiler should never panic regardless of input). The **`glacier`** project (`rust-lang/glacier`) maintains a collection of ICE-inducing snippets run against each nightly, automatically tracking which ICEs have been fixed and which persist. Each file is named after its GitHub issue number.

**`cargo-bisect-rustc`** (`rust-lang/cargo-bisect-rustc`) binary-searches across nightly toolchain releases (or CI artifacts) to find the exact nightly where behavior changed. Can narrow to a single PR. This is the standard first investigation step for regressions:

```bash
cargo bisect-rustc --start=2024-01-01 --end=2024-06-01 -- test
```

**Debugging flags**: The compiler exposes `-Z` flags for internal inspection: `-Z dump-mir=*` for MIR dumps, `-Z verbose-internals`, `-Z query-dep-graph`, `-Z self-profile` for Chrome-trace-compatible profiles. The `RUSTC_LOG` environment variable enables per-module tracing via the `tracing` crate.

**Relevance to our skill**: `glacier`-style persistent regression corpus is an idea worth considering. `cargo-bisect-rustc` has no Swift equivalent; toolchain bisection is manual for us.

#### LLVM/Clang

LLVM uses a two-tier reduction approach:

**`C-Reduce` / `cvise`** for source-level reduction: language-aware AST transformations via Clang, producing outputs 25x smaller than generic delta debugging. 69 Clang-based passes plus text-level passes.

**`llvm-reduce`** for IR-level reduction: interestingness-test-driven, produces valid IR at each step, significantly faster than the legacy `bugpoint`. Does NOT identify which pass is at fault -- purely minimizes IR.

**`bugpoint`** (legacy, being removed): combined pass-bisection AND IR reduction. Unique dual role.

**Triage process**: GitHub Issues (migrated from Bugzilla in 2022), labeled by component, type, and severity. `git bisect` on the monorepo is standard for regression identification. CODE_OWNERS routes bugs to reviewers.

**Relevance to our skill**: The two-tier approach (source reduction + IR reduction) and the interestingness-test pattern are directly applicable. `bugpoint`'s pass bisection is analogous to our `-sil-opt-pass-count` technique.

#### GCC

GCC has one of the most rigorous regression tracking processes:

- **P1 regressions** (from previous release) block releases. Release gating on P1 count reaching zero.
- Keywords distinguish `ice-on-valid-code`, `ice-on-invalid-code`, `wrong-code`, `rejects-valid`, `accepts-invalid`, `missed-optimization`, `diagnostic`.
- Every bug fix must include a DejaGnu test case in `gcc/testsuite/`.
- "Most test cases can be reduced to fewer than 30 lines" -- explicit guidance.

**`cvise`** (`github.com/marxin/cvise`): A C-Reduce fork by GCC contributor Martin Liska, faster and more maintainable.

**Relevance to our skill**: The bug classification taxonomy (crash/miscompile/rejects-valid/accepts-invalid/diagnostic) is worth adopting explicitly. P1 regression gating is a model for our own release validation.

#### GHC (Glasgow Haskell Compiler)

GHC handles some of the most complex type system features in any production compiler:

- **`-dcore-lint`**: Validates Core IR after every pass, catching type system soundness issues early. Analogous to `-sil-verify-all`.
- **`-ddump-tc-trace`**: Full trace of the type checker / constraint solver.
- **Note [...] convention**: Inline documentation of invariants directly in source code, searchable. Used extensively during bug investigation to understand whether an invariant was violated.
- **No widely-adopted automatic reducer** for Haskell. Manual reduction is dominant. This is a known gap.
- **Standalone .hs file** requirement for bug reports, with all language extensions listed at the top.

**Relevance to our skill**: GHC's `-dcore-lint` (verify after every pass) validates our `-sil-verify-all` approach. The Note convention for documenting invariants near the code that enforces them is a practice we should look for when reading Swift compiler source.

#### Cross-Cutting Themes

| Theme | Universal Practice |
|-------|-------------------|
| Reduction is paramount | Every ecosystem treats minimization as prerequisite |
| Bisection for regressions | Rust: `cargo-bisect-rustc`, LLVM/GCC: `git bisect`, GHC: `git bisect` |
| IR dumping infrastructure | Rust: `-Z dump-mir`, LLVM: `-print-after-all`, GCC: `-fdump-tree-*`, GHC: `-ddump-simpl` |
| Bug classification | Crashes, miscompilations, rejects-valid, accepts-invalid, diagnostic quality |
| Regression gating | GCC most rigorous (P1 blocks releases), all ecosystems treat regressions with elevated priority |
| Test case as artifact | Every bug fix includes a regression test |

**Context-sensitive bugs** are a known challenge everywhere:
- Rust: incremental compilation caching creates order-dependent bugs (`-Z incremental-verify-ich`)
- LLVM: phase-ordering bugs -- `bugpoint` bisects both IR and pass pipeline simultaneously
- GCC: target-specific issues reproduced via cross-compilation flags
- GHC: extension + instance combinations progressively enabled one at a time

---

### A.2 Reduction Tooling

#### The Reduction Landscape

| Ecosystem | Source-Level | IR-Level | Bisection | Maturity |
|-----------|-------------|----------|-----------|----------|
| C/C++ | C-Reduce (69 Clang passes + agnostic), cvise (parallel port) | llvm-reduce (replacing bugpoint) | git bisect | Excellent |
| Rust | treereduce-rust (syntax-aware), icemelter (ICE wrapper) | None (uses LLVM tier) | cargo-bisect-rustc | Good |
| Swift | **None** (C-Reduce agnostic passes only) | bug_reducer (SIL, alpha, pass+function only) | Manual git bisect | **Poor** |

Swift has a **significant tooling gap** in test case reduction.

#### C-Reduce Architecture

C-Reduce (Regehr et al., PLDI 2012) uses a modular fixpoint architecture:

1. **Perl/Python top layer** -- orchestrates pass scheduling, parallelism, interestingness test loop
2. **clang_delta** -- C++ tool built on Clang libraries for source-to-source transformations
3. **Language-agnostic passes** -- text-level transformations (line deletion, token renaming, balanced-delimiter removal)

Key insight: some passes potentially *increase* size to eliminate coupling within the test case, unblocking progress in other passes. The fixpoint architecture means passes compose.

**Effectiveness**: Produces outputs 25x smaller than generic delta debugging (Regehr et al. 2012). Handles crashes well; miscompilations harder (interestingness test must check output correctness).

#### Swift-Specific Reduction

**No `swift-reduce` exists.** Searches confirm no dedicated Swift source-level reduction tool in the swiftlang organization or broader ecosystem.

**`bug_reducer`** (`swiftlang/swift/utils/bug_reducer/`): Python script for SIL-level reduction. Capabilities:
1. **Pass reduction**: Reduces optimization pass count to minimal set triggering crash
2. **Function reduction**: Extracts functions or partitions module into optimized/unoptimized parts
3. **Output**: Minimal SIB, minimal function set, minimal passes, reproduction command

Explicitly described as "still very alpha." Block/instruction reduction listed as TODO. Miscompile detection not implemented.

**C-Reduce for Swift**: Mike Ash demonstrated (2018) that C-Reduce works "out of the box" on Swift via language-agnostic passes. The C-specific passes fail silently; agnostic passes still achieve significant reduction. Interestingness test is simply a shell script running `swiftc` and checking for the crash.

**`tree-sitter-swift` exists** (`github.com/tree-sitter/tree-sitter-swift`). This means `treereduce` *could* be instantiated for Swift, but no `treereduce-swift` currently exists.

**SIL pass bisection**: `-Xllvm -sil-opt-pass-count=<n>` limits optimization passes. Sub-pass bisection: `-Xllvm -sil-opt-pass-count=<n>.<m>`. The `llvm/utils/bisect` utility can automate this.

#### Could a SIL-Level Reducer Be Built?

Yes, and the infrastructure exists:
- SIL parser, printer, verifier already functional
- `sil-opt` processes textual SIL
- `sil-func-extractor` extracts specific functions
- `bug_reducer` provides working Python harness
- `llvm-reduce` provides proven architectural template
- MLIR-reduce demonstrates the pattern generalizes to typed SSA IRs

A full SIL reducer would need: function removal (exists), basic block removal, instruction removal/simplification, argument reduction, type simplification, witness table/vtable removal, and ownership-aware transformations.

#### Delta Debugging Academic Lineage

1. **Zeller 1999** -- Delta debugging concept ("Yesterday, my program worked")
2. **Zeller & Hildebrandt 2002** -- Formalized `dd_min` algorithm (1-minimal results)
3. **Misherghi & Su 2006** -- HDD: tree-structured delta debugging, syntax validity
4. **Regehr et al. 2012** -- C-Reduce: domain-specific modular passes + fixpoint
5. **Sun et al. 2018** -- Perses: grammar-guided reduction (2% the size of DD output)
6. **Donaldson et al. 2021** -- Transformation reversal approach (PLDI 2021)
7. **Zhang et al. 2024** -- LPR: LLM-aided program reduction (ISSTA 2024)

#### Automated vs. Manual Reduction

**When automated is better**: Large inputs, crash bugs with clear interestingness tests, consistent results.

**When manual is preferable**:
1. When the interestingness test is hard to define (miscompilations, configuration-dependent bugs)
2. When semantic understanding matters (recognizing that reduction introduced undefined behavior)
3. When the bug is multi-file/multi-module (most tools operate on single files)
4. For teaching/understanding (manual reduction builds insight into *why* the bug occurs)
5. When no reduction tool exists for the language (Swift's current situation)

**LPR (ISSTA 2024)**: Uses LLMs for semantic transformations within reduction loops. On 50 benchmarks across C, Rust, and JavaScript, produced programs 24.93% (C), 4.47% (Rust), and 11.71% (JavaScript) smaller than the previous state-of-the-art.

---

### A.3 Bug Report Quality Research

#### Academic Findings

**Bettenburg et al. 2008 / Zimmermann et al. 2010** -- "What Makes a Good Bug Report?" (FSE 2008, IEEE TSE 2010). Surveyed 872 developers from Apache, Eclipse, Mozilla.

Developer-ranked elements by importance:
1. **Steps to reproduce** -- 89% importance rating, single most valued element
2. **Stack traces** -- ranked second
3. **Test cases** -- ranked third
4. **Observed behavior** -- important but surprisingly not at the top
5. **Expected behavior** -- relatively less important than reproduction info

Core finding: systematic gap between what developers need and what reporters provide. The most critical elements are the same ones reporters find hardest to supply.

**Hooimeijer & Weimer 2007** -- "Modeling Bug Report Quality" (ASE 2007). Built prediction model from 27,000+ Firefox bug reports. Found: more comments/attachments correlate with *longer* fix times (signals complexity, not helpfulness). Reporter reputation matters.

**Guo et al. 2010** -- ICSE 2010, studied Microsoft Windows bugs. Reporter reputation strongly predicts fix likelihood. Organizational proximity matters. One reassignment increases fix likelihood; many decrease it.

**Sun et al. 2016** -- "Toward Understanding Compiler Bugs in GCC and LLVM" (ISSTA 2016). Studied ~50K bugs across both compilers. Findings: 80% of bug-revealing test cases are small. 92% of fixes involve fewer than 100 lines. GCC bugs average 200 days to resolution, LLVM 111 days.

**Soltani et al. 2020** -- Empirical Software Engineering. Crash reproduction steps, stack traces, and test cases have statistically significant impacts on resolution time. Over 70% of bug reports lack these critical elements.

#### Compiler-Specific Bug Reports

Compiler bug reports differ from application bug reports:

**Easier**: Deterministic behavior given same input. Test case is just source code. Expected behavior often well-defined by spec.

**Harder**: Test cases may rely on undefined behavior (Keil: "<1% of reports are actual bugs"). Reduction is non-trivial (syntax breakage). Miscompilations far harder than crashes. Reporter must distinguish frontend/middle-end/backend bugs.

#### What Each Ecosystem Expects

**LLVM**: Requires reduced test case. Asks reporters to triage component (use `-emit-llvm -Xclang -disable-llvm-passes` to test frontend vs middle-end). Recommends C-Reduce / llvm-reduce.

**GCC**: Requires `gcc -v` output, preprocessed file (`-save-temps`), exact command-line. "Most test cases can be reduced to fewer than 30 lines."

**Rust**: Requires code sample, expected vs actual behavior, `rustc --version --verbose`. ICEs auto-generate a filing link with pre-populated labels. `-Z treat-err-as-bug=1` converts first error to ICE for stack trace.

**Swift**: Requires concise description, stack trace (if crash), reproducer ("roughly within 50 lines"), environment info. "Write test cases at the abstraction level nearest to the actual feature." "Reduce test cases as much as possible."

#### Synthesis: Elements Correlated with Faster Resolution

Across all literature, this ranking emerges:

1. **Reproducible test case / steps to reproduce** -- strongest predictor
2. **Stack traces** -- dramatically reduces investigation time for crashes
3. **Minimal reproducer** -- smaller reports get fixed faster (80% of compiler test cases are small)
4. **Clear observed-vs-expected** -- necessary for non-crash bugs
5. **Environment information** (compiler version, platform, optimization level)
6. **Reporter reputation/investigation depth** -- issues with bisection results get same-day fixes (e.g., swiftlang/swift#66312)

---

### A.4 Ownership/Move Semantics Debugging

#### Rust Borrow Checker Bug Investigation

The borrow checker operates on MIR and uses dataflow analysis to track:
- **Move paths**: represent paths through which data can be moved
- **Loan tracking**: each borrow creates a "loan" with a region/lifetime
- **Region inference**: NLL computes minimal region for each borrow

**Debugging workflow**: `--emit=mir` for MIR dumps, `-Z treat-err-as-bug=1` for stack traces at emission point, `cargo-bisect-rustc --regress=ice` for ICE-specific bisection. Polonius (next-gen checker) reformulates as Datalog facts, enabling precise inspection.

**OOPSLA 2025 study** of 301 rustc bugs (ETH Zurich): Type system bugs (30.23%) and ownership/lifetime bugs (13.62%) are the top Rust-specific categories. Bug-triggering code involves unstable features, advanced trait usage, and lifetime annotations.

#### Transferable Techniques to Swift ~Copyable

**Directly transferable**:
1. **Dataflow-based move tracking** -- both compilers track "move paths" via dataflow. The mental model of "value is live, consumed, then dead" is shared.
2. **IR-level verification passes** -- Rust's borrow checker and Swift's MoveOnlyChecker are both mandatory IR verification passes. Debugging: dump IR before/after pass, inspect what the pass "sees."
3. **Regression bisection** -- same technique, different tooling. Rust has `cargo-bisect-rustc`; Swift is manual.
4. **Bug clustering** -- in both ecosystems, ownership bugs cluster around generics, conditional conformances, and interactions between ownership annotations and other type system features.

**Not directly transferable**:
- Rust's Polonius/Datalog approach is architecturally different from Swift's OSSA-based approach
- Rust's borrow checker is a unified single pass; Swift's ownership checking is split across SILGen, MoveOnlyChecker, and other SIL passes -- meaning bugs arise from pass *interactions*, not just within one pass
- This is precisely what makes our investigations complex: the CopyPropagation crash was caused by a chain of 6 passes, each individually correct

---

## B. Swift-Specific Practices

### B.5 Swift Compiler Debugging Tools

#### SIL Pipeline Stages

| Command | Stage |
|---------|-------|
| `swiftc -emit-silgen file.swift` | Raw SIL (immediately after SILGen) |
| `swiftc -emit-sil -Onone file.swift` | Canonical SIL (after mandatory passes) |
| `swiftc -emit-sil -O file.swift` | Optimized SIL (after full pipeline) |
| `swiftc -emit-irgen -O file.swift` | LLVM IR before LLVM optimization |
| `swiftc -emit-ir -O file.swift` | LLVM IR after LLVM optimization |
| `swiftc -emit-assembly -O file.swift` | Final assembly |

Use `-save-sil`, `-save-irgen`, `-save-ir` to save alongside normal compilation output.

#### SIL Printing Flags (via `-Xllvm`)

| Flag | Purpose |
|------|---------|
| `-sil-print-all` | Print all functions after any modifying pass |
| `-sil-print-function=NAME` | Print specific function (exact mangled name, comma-separated for multiple) |
| `-sil-print-functions=SUBSTR` | Print functions containing substring in mangled name |
| `-sil-print-around=PASS` | Print before and after a named pass |
| `-sil-print-before=PASS` | Print only before named pass |
| `-sil-print-after=PASS` | Print only after named pass |
| `-sil-print-last` | Print SIL before/after the n-th optimization (use with `-sil-opt-pass-count`) |
| `-sil-print-pass-name` | Print which passes execute |

#### Pass Bisection (The Primary Technique)

```bash
# Step 1: Binary search for the bad pass
swiftc -O -Xllvm -sil-opt-pass-count=1000 file.swift   # works?
swiftc -O -Xllvm -sil-opt-pass-count=5000 file.swift   # crashes?
# Binary search between 1000 and 5000...

# Step 2: Sub-pass bisection for multi-transformation passes
swiftc -O -Xllvm '-sil-opt-pass-count=3500.50' file.swift

# Step 3: Print SIL around the identified pass
swiftc -O -Xllvm -sil-opt-pass-count=3500 -Xllvm -sil-print-last file.swift 2>sil_dump.txt

# Automated bisection via LLVM utility:
llvm-project/llvm/utils/bisect --start=0 --end=10000 ./invoke_swift_passing_N.sh "%(count)s"
```

For large projects: `-Xllvm -sil-pass-count-config-file=<file>` reads pass counts from a file.

#### SIL Verification

| Flag | Purpose |
|------|---------|
| `-sil-verify-all` (via `-Xllvm` or `-Xfrontend`) | Run verifier after every pass |
| `-sil-disable-pass=PASS_TAG` (via `-Xllvm`) | Disable a specific optimization pass |

#### Diagnostic Tools

| Flag | Purpose |
|------|---------|
| `-Xfrontend -debug-diagnostic-names` | Append diagnostic ID (e.g., `[cannot_convert_value]`) to every error |
| `-Xfrontend -debug-constraints` | Full constraint solver trace (type checker debugging) |
| `-Xfrontend -print-educational-notes` | Emit longer-form educational notes |
| `-Xllvm -swift-diagnostics-assert-on-error=1` | Assert on first error (get stack trace at emission point) |
| `-Xllvm -swift-diagnostics-assert-on-warning=1` | Assert on first warning |
| `swiftc -dump-ast file.swift` | Dump type-checked AST |
| `swiftc -dump-parse file.swift` | Dump parse tree (no type checking) |
| `swiftc -typecheck file.swift` | Type-check only, no codegen |

#### Standalone SIL Tools

- **`sil-opt`**: Run specific SIL passes in isolation. Usage: `sil-opt -enable-sil-verify-all input.sil -inline -dce`
- **`sil-func-extractor`**: Extract specific SIL functions into a separate file
- **`swift-demangle`** / **`swift demangle`**: Demangle Swift symbol names
- **`sil-nm`**: SIL symbol listing (analogous to `nm` for `.sib` files)
- **`bug_reducer.py`**: SIL-level test case reduction (pass + function reduction)

#### Performance Diagnostics

| Flag | Purpose |
|------|---------|
| `-driver-time-compilation` | High-level timing of all driver jobs |
| `-Xfrontend -debug-time-function-bodies` | Time spent type-checking every function |
| `-Xfrontend -print-stats` | All statistic counters (assert builds only) |
| `-stats-output-dir <dir>` | Write counters as JSON (works in release builds) |
| `-Rmodule-loading` | Show which modules are being loaded and from where |

#### SIL Statistics

| Flag | Purpose |
|------|---------|
| `-sil-stats-modules` | Module-level counters |
| `-sil-stats-functions` | Function-level counters |
| `-sil-stats-only-instructions=all` | Instruction-level counters |
| `-sil-stats-lost-variables` | Track debug variables lost during optimization |
| `-sil-stats-output-file=FILE` | Redirect stats to file |

Post-processing: `utils/optimizer_counters_to_sql.py` loads CSV into SQLite, `utils/process-stats-dir.py` aggregates JSON stats.

#### Using -Xllvm via swift build

```bash
# Via swiftc directly:
swiftc -Xllvm -sil-print-all file.swift

# Via swift build (each LLVM flag needs its own -Xswiftc):
swift build -Xswiftc -Xllvm -Xswiftc -sil-print-all

# Frontend flags via swift build:
swift build -Xswiftc -Xfrontend -Xswiftc -debug-diagnostic-names
```

---

### B.6 Community Triage Patterns

#### Erik Eckstein (@eeckstein) -- SIL Optimizer Owner

Fixes are surgical, single-file changes in `lib/SILOptimizer/`. Prefers to route reporters to debugging flags. On swiftlang/swift#58851 (CMO hang): "this is most likely not a bug of cross-module-optimization itself, but only exposed by CMO" -- key insight that CMO exposes latent bugs in existing passes. Authored `bug_reducer`, the libswift project for SIL passes in Swift, and cross-module optimization.

On swiftlang/swift#66312: after a contributor bisected to the exact sub-pass, Eckstein responded "Thanks for reporting! It's unbelievable that we didn't hit this bug earlier. It's in the compiler since 7 years." and delivered a same-day fix.

#### Meghana Gupta (@meg-gupta) -- Lifetime/Dependence Reviewer

Contributed the key detail about sub-pass bisection: `-sil-opt-pass-count=<n>.<m>` for multi-transformation passes like SILCombine. Emphasized "only the pass count number matters for bisecting purposes."

#### Andrew Trick (@atrick) -- SIL Optimizer Reviewer

Methodology visible in writing: the variable lifetimes gist establishes the theoretical framework the SIL verifier enforces (deinitialization barriers, lexical lifetimes). Key principle: "Well-defined lifetime rules that are explicitly represented in SIL allow strong verification."

#### Joe Groff (@jckarter) -- SIL/SILGen Owner

Explained the architectural reason verification isn't continuous: "normally we only run the SIL verifier at the end of the mandatory and optimization pipelines" -- the verifier is a pass inserted into the pipeline, not a continuous check.

#### Gold Standard Issue: swiftlang/swift#66312

A contributor investigation that received an immediate fix:
1. Provided full build command from `swift build -c release -vvv`
2. Bisected pass count using `-sil-opt-pass-count=<n>` to identify pass #13699
3. Used sub-pass bisection with `<n>.<m>` to find transformation 13669.10
4. Extracted before/after SIL with `-sil-print-function`
5. Identified the exact transformation: `alloc_ref_dynamic [stack]` replaced without preserving stack annotation
6. Explained the invariant violation

This is the template that gets same-day fixes from the compiler team.

---

### B.7 Issue Filing Quality

#### What Gets Quick Attention

1. Issues with standalone reproducers (single .swift file, swiftc command)
2. Issues where the reporter has bisected to a specific pass or sub-pass
3. Issues affecting release configurations (`-O`, WMO) -- they affect shipping apps
4. Issues tagged `SILOptimizer` with verification failures routed to correct reviewers

#### What Reviewers Consistently Ask For

- Standalone single-file reproducer buildable with bare `swiftc`
- Exact Swift version and platform
- Optimization level: `-O`, `-Osize`, `-Onone`, WMO
- `-sil-verify-all` results identifying the responsible pass
- Minimal code: remove everything not affecting reproduction

#### Recommended Report Format

```
Description: [one-line summary of crash/miscompile]
Environment: [Swift version, platform, optimization level]
Reproducer: [standalone .swift file, or exact build command]
Stack trace: [full symbolicated trace]
SIL output: [if applicable, the problematic SIL]
Investigation: [if done: pass bisection results, before/after diff]
```

#### Bug Classification Taxonomy (from GCC/LLVM/Rust/GHC)

This taxonomy should be adopted:

| Category | Description | Example |
|----------|-------------|---------|
| **ICE/Crash** | Compiler itself crashes | SIL verification failure, LLVM verifier crash |
| **Miscompile** | Wrong code generated (compiles but wrong output) | Incorrect enum destructuring in release mode |
| **Rejects-valid** | Correct code rejected | False type error on valid ~Copyable code |
| **Accepts-invalid** | Incorrect code accepted | Missing ownership error |
| **Diagnostic** | Confusing/wrong error message | Misleading error pointing to wrong line |

---

## C. Ecosystem-Specific Patterns

### C.8 Our Unique Challenges

The Swift Institute ecosystem creates investigation challenges not documented in any other compiler community, arising from the combination of cutting-edge Swift features at scale.

#### Challenge 1: Sub-repo vs Superrepo Divergence

WMO with the full dependency graph (61 packages across 9 tiers) triggers bugs invisible in isolation. Sub-repo release builds pass because they have shallower inlining depth; the full superrepo enables deeper cross-module inlining that exposes many more crash sites.

**Evidence**: Bug 2 (CopyPropagation) affected 5 functions in sub-repo builds but 60+ functions across 9 repos in the superrepo. CMO bugs are latent in existing passes, only exposed when cross-module inlined code creates new patterns (confirmed by Eeckstein on #58851).

**Technique**: Always validate release builds at the superrepo level. Sub-repo builds are necessary but not sufficient.

#### Challenge 2: One Bug, Wide Blast Radius

A single compiler bug cascades through the entire type hierarchy. swiftlang/swift#86652 is a single IRGen codegen divergence (21 lines in GenStruct.cpp) that blocked deinits on Storage.Inline, requiring 22 `_deinitWorkaround: AnyObject?` sites across 10 packages.

**Technique**: When a bug manifests widely, look for a single root cause in the compiler rather than per-site workarounds. Fix the compiler when possible.

#### Challenge 3: Access-Level Context Sensitivity

`internal` types work but `public` types crash, because the compiler uses different codegen paths (element-wise vs VWT destruction). Standalone experiments with `internal` types give false positives.

**Technique**: Always test with `public` access and real dependencies. The standalone reproducer trap: experiments with zero deps and `internal` types may pass while production fails.

#### Challenge 4: ~Escapable + @_lifetime Interaction

Combining `~Escapable` with `@_lifetime(borrow)` creates `mark_dependence` instructions classified as `PointerEscape` by CopyPropagation, causing false positive ownership violations across control flow joins. A sound type annotation triggered an optimizer crash.

**Evidence**: Bug 2 required 149 `@_optimize(none)` annotations across 12 sub-repos before the root cause was identified by reading the compiler source (TODO comment at `OSSACanonicalizeOwned.cpp:40-46`).

**Technique**: For optimizer bugs, reading the optimizer source can be more efficient than empirical exploration. The TODO comment provided more signal in 5 lines than 7 experiments.

#### Challenge 5: Stale Build Cache Hazard

`rm -rf .build` can fail silently (locked files, nested structures), leaving stale artifacts that produce misleading results. Multiple investigations produced false reductions because cached SIL from earlier variants survived.

**Evidence**: In the 2026-03-31 investigation, `print("hello")` appeared to crash because the stale `.build` was running cached SIL from the first reproduction.

**Technique**: Verify `rm -rf .build` succeeded (check exit code or confirm directory absence). For critical verification, use `swiftc` directly to eliminate all caching.

#### Challenge 6: Multi-Pass Interaction Bugs

The CopyPropagation crash (Bug 2) was caused by a chain of 6 passes:
1. PredictableDeadAllocationElimination (mandatory, #32) -- eliminates alloc_stack, inserting compensating destroy_value
2. SILCombine (#14) -- removes redundant mark_dependence, RAUW creates triple consume
3. DeinitDevirtualizer (#20) -- converts destroy_value to end_lifetime
4. Serialization -- malformed SIL is serialized
5. EarlyPerfInliner -- propagates the bug cross-module
6. CopyPropagation -- verifies ownership, crashes

No single pass is incorrect in isolation. The bug emerges from their interaction. This is specific to ecosystems with deep optimization pipelines and cross-module serialization.

**Technique**: Sub-pass bisection (`-sil-opt-pass-count=<n>.<m>`) to identify the exact transformation. Dump SIL before/after each pass in the chain using `-sil-print-around`.

#### Generalizable Patterns from Our Ecosystem

Several techniques discovered in our investigations generalize:

1. **File-level elimination**: Empty files, add back incrementally. Decisive for LLVM verifier crash (minutes to find trigger).
2. **Variable isolation**: Test one variable at a time (access level, field count, dependency presence, generic vs concrete). Produces clear constraint models.
3. **Experiment consolidation**: Group experiments by hypothesis to make evidence base visible. 14-->3 grouping exposed three distinct bug threads.
4. **SIL from passing builds shows correlation, not causation**: The first SIL analysis agent examined a passing build and found patterns that were real but not causal. For crash diagnosis, analyze the crashing build's output.

---

### C.9 Context-Sensitive Reproduction

Context-sensitive compiler bugs -- those that don't reproduce in isolation -- are a specific challenge documented across ecosystems but particularly acute in our ~Copyable codebase.

#### Our Context-Sensitive Bugs

| Bug | Context Required | Why Isolation Fails |
|-----|-----------------|---------------------|
| Bug 2 (CopyPropagation, #88022) | Full dependency graph with `~Escapable` + `@_lifetime(borrow)` | mark_dependence only generated in cross-module inlined coroutine yields |
| Bug 1 (@_rawLayout LLVM verifier) | Full dependency graph's serialized SIL volume | Optimizer requires enough type metadata in single compilation unit |
| Access-level trigger (#86652) | `public` types with dependencies | Different codegen paths for `public` vs `internal` |
| SILGen trivial load (#85743) | Generic ~Copyable enum + tuple + consuming switch | Standalone reproduction achieved but required specific feature combination |

#### Methodologies for Context-Sensitive Bugs

**Module bisection**: Build sub-repos individually, then full superrepo. The crash surface widens at each level of integration. For our ecosystem:
```
Sub-repo (13-30s build) --> Superrepo (--> 2+ min build)
```

**File-level elimination**: Empty all source files in a target, add back one at a time. Proved decisive for the LLVM verifier crash -- identified the trigger file in minutes. More coarse-grained than code modification but faster feedback.

**Variable isolation**: For each potential trigger variable, test it independently:
1. Access level: `public` vs `internal`
2. Field count: 1-field vs 2+ fields
3. Dependencies: zero deps vs full dependency graph
4. Generic vs concrete
5. Debug vs release
6. WMO vs single-file

This produces a constraint model (e.g., "public + 2+ fields + @_rawLayout + deinit = crash").

**Incremental construction** (EXP-004a): When you can't reproduce by reduction, build up from nothing. Add one feature at a time until the crash appears. The 7 failed standalone reproduction attempts for Bug 2 were searching the wrong feature space; once the compiler source revealed `~Escapable` + `@_lifetime(borrow)` = `mark_dependence`, the reproducer succeeded immediately.

**Experiment consolidation** (EXP-018): When investigation produces 5+ experiments, consolidate by hypothesis. This makes the evidence structure visible: which hypotheses have been tested, which remain open, how findings relate. The 14-->3 consolidation revealed the investigation had three distinct bug threads, not one.

**Delta debugging in practice**: Neither Zeller's dd_min nor C-Reduce addresses multi-module context sensitivity directly. Our effective approach is a manual analog:
1. Start at the integration level where the bug reproduces (superrepo release build)
2. Remove one integration dimension at a time (remove one package, remove WMO, change access level)
3. If the bug disappears, that dimension is required -- restore it
4. Continue until the minimal context is identified

This is structurally identical to [ISSUE-004] Required Ingredient Verification but applied to the *build configuration* rather than the *source code*.

#### Cross-Ecosystem Approaches to Context-Sensitive Bugs

- **Rust**: Incremental compilation bugs depend on compilation ordering and cache state. Dedicated flags: `-Z incremental-info`, `-Z incremental-verify-ich`. Fuzzing with `icemaker` can discover reproducible triggers.
- **LLVM**: Phase-ordering bugs bisected with `bugpoint` (both IR and pass pipeline simultaneously). For link-time bugs, `llvm-reduce` reduces across module boundaries.
- **GCC**: Target-specific bugs reproduced via cross-compilation flags (`-march`, `-mtune`). Avoids needing specific hardware.
- **GHC**: Extension + instance combinations progressively enabled one at a time. `-XNoExtension` flags help narrow the triggering combination.

---

## Summary of Findings by Skill Impact

### New Rules for the Skill

| Finding | Proposed Rule | Source |
|---------|---------------|--------|
| Bug classification taxonomy | Adopt crash/miscompile/rejects-valid/accepts-invalid/diagnostic | GCC, LLVM, Rust, GHC (universal) |
| Sub-pass bisection | Add `-sil-opt-pass-count=<n>.<m>` technique | Meg-gupta forum post, DebuggingTheCompiler.md |
| SIL-level reduction tooling | Document `bug_reducer.py`, C-Reduce for Swift, `sil-func-extractor` | swiftlang/swift/utils/, Mike Ash 2018 |
| Interestingness test pattern | Document shell-script-based bug verification | C-Reduce architecture, LLVM/Rust practices |
| Variable isolation for context-sensitive bugs | Systematic one-variable-at-a-time testing | Our investigations (2026-03-20, 2026-03-22) |
| File-level elimination | Empty files, add back incrementally | Our investigation (2026-03-20) |
| Access-level testing | Always test with `public` access | Our investigation (2026-03-22) |
| Experiment consolidation during investigation | Group by hypothesis when >5 experiments | Our investigation (2026-03-21), EXP-018 |
| Compiler source reading | For optimizer bugs, read the source early | Our investigation (2026-03-22): TODO comment resolved Bug 2 |

### Tools Not Currently in the Skill

| Tool | Purpose | Where |
|------|---------|-------|
| `-sil-opt-pass-count=<n>.<m>` | Sub-pass bisection | `-Xllvm` |
| `-sil-print-last` | Print SIL around bisected pass | `-Xllvm` |
| `-sil-disable-pass=PASS_TAG` | Disable specific pass | `-Xllvm` |
| `-swift-diagnostics-assert-on-error=1` | Stack trace at diagnostic emission | `-Xllvm` |
| `-debug-diagnostic-names` | Diagnostic ID in error output | `-Xfrontend` |
| `sil-func-extractor` | Extract specific SIL functions | Built with compiler |
| `bug_reducer.py` | SIL-level pass + function reduction | `swift/utils/bug_reducer/` |
| `llvm/utils/bisect` | Automate pass count bisection | Built with LLVM |
| C-Reduce (agnostic passes) | Source-level reduction for Swift | External tool |
| `-emit-silgen` / `-emit-sil -Onone` / `-emit-sil -O` | SIL at different pipeline stages | `swiftc` |

---

## References

### Academic Papers

- Bettenburg et al. 2008 / Zimmermann et al. 2010. "What Makes a Good Bug Report?" FSE 2008, IEEE TSE 36(5):618-643
- Hooimeijer & Weimer 2007. "Modeling Bug Report Quality." ASE 2007
- Guo et al. 2010. "Characterizing and Predicting Which Bugs Get Fixed." ICSE 2010
- Soltani, Hermans, & Back 2020. "The Significance of Bug Report Elements." EMSE 2020
- Sun et al. 2016. "Toward Understanding Compiler Bugs in GCC and LLVM." ISSTA 2016
- Regehr et al. 2012. "Test-Case Reduction for C Compiler Bugs." PLDI 2012
- Yang et al. 2011. "Finding and Understanding Bugs in C Compilers." PLDI 2011
- Zeller 1999. "Yesterday, my Program Worked. Today, it Does Not. Why?" ESEC/FSE 1999
- Zeller & Hildebrandt 2002. "Simplifying and Isolating Failure-Inducing Input." IEEE TSE 2002
- Misherghi & Su 2006. "HDD: Hierarchical Delta Debugging." ICSE 2006
- Sun et al. 2018. "Perses: Syntax-Guided Program Reduction." ICSE 2018
- Zhang et al. 2024. "LPR: LLM-Aided Program Reduction." ISSTA 2024
- ETH Zurich 2025. "An Empirical Study of Rust-Specific Bugs in the rustc Compiler." OOPSLA 2025

### Compiler Documentation

- swiftlang/swift `docs/DebuggingTheCompiler.md`
- swiftlang/swift `docs/CompilerPerformance.md`
- swiftlang/swift `docs/OptimizerDesign.md`
- swiftlang/swift `utils/bug_reducer/README.md`
- swiftlang/swift `include/swift/SILOptimizer/PassManager/Passes.def`
- Rust `rustc-dev-guide`: https://rustc-dev-guide.rust-lang.org/
- LLVM "How to Submit an LLVM Bug Report": https://llvm.org/docs/HowToSubmitABug.html
- GCC "How to Minimize Test Cases": https://gcc.gnu.org/bugs/minimize.html

### Tools

- C-Reduce: https://github.com/csmith-project/creduce
- C-Vise: https://github.com/marxin/cvise
- treereduce: https://github.com/langston-barrett/treereduce
- icemelter: https://lib.rs/crates/icemelter
- cargo-bisect-rustc: https://github.com/rust-lang/cargo-bisect-rustc
- glacier (Rust ICE corpus): https://github.com/rust-lang/glacier
- icemaker (Rust ICE fuzzer): https://github.com/matthiaskrgr/icemaker
- tree-sitter-swift: https://github.com/tree-sitter/tree-sitter-swift
- llvm-reduce: `llvm/tools/llvm-reduce/` in LLVM monorepo

### Blog Posts and Practitioner Guides

- Regehr. "Design and Evolution of C-Reduce" (Parts 1 & 2): https://blog.regehr.org/archives/1678, https://blog.regehr.org/archives/1679
- Regehr. "Reducers are Fuzzers": https://blog.regehr.org/archives/1284
- Mike Ash. "Debugging with C-Reduce" (2018): https://www.mikeash.com/pyblog/friday-qa-2018-06-29-debugging-with-c-reduce.html
- Brad Larson. "Debugging the Swift Compiler, Part 1": https://medium.com/passivelogic/debugging-the-swift-compiler-part-1-writing-good-bug-reports-8357cfc459e
- Trick. Variable lifetimes gist: https://gist.github.com/atrick/cc03c4d07fb0a7bee92c223ae5e5695b

### Swift Institute Investigations

- `Research/Reflections/2026-03-31-noncopyable-io-completion-cascade-and-silgen-bug-discovery.md`
- `Research/Reflections/2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md`
- `Research/Reflections/2026-03-20-release-mode-llvm-verifier-crash-investigation.md`
- `Research/Reflections/2026-03-21-rawlayout-experiment-consolidation-and-workaround-exhaustion.md`
- `Research/Reflections/2026-03-22-sil-copypropagation-bug2-workaround.md`
- `Research/Reflections/2026-03-22-rawlayout-deinit-compiler-fix.md`
- `Research/compiler-pr-copypropagation-mark-dependence-handoff.md`
