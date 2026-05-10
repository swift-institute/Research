---
date: 2026-05-07
session_objective: Close the Swift.String leak at the linter engine pipeline's internal boundaries (D7'' correction on top of D7' Path.Filter rim).
packages:
  - swift-primitives/swift-linter-primitives
  - swift-foundations/swift-linter
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [IMPL-110] Pair Tagged-Typed Identities With Typed Operations (entry 5 AI 1; D7-prime-prime Tagged.hasPrefix worked example; before/after .underlying grep 18 to 0). NoAction walker-emission shape research deferred package-specific. NoAction institute-namespace stdlib-shadowing catalog covered by [PLAT-ARCH-022] Swift.<Protocol> Qualification.
---

# D7'' — Typed-Throughout Correction on D7' Rim

## What Happened

D7' (commits `3ebc5d0` linter-primitives + `27c8009` linter, captured
in `2026-05-07-d7-path-filter-runtime-enforcement.md`) typed the
`Lint.Configuration` rim — `Path.Filter.Prefix = Tagged<Path.Filter,
Swift.String>`, `included` / `excluded` / `Lint.Configuration.excluded`
all `[Path.Filter.Prefix]`. Sound at the rim; bare `Swift.String`
leaked at every internal call site of the engine pipeline (matches
predicate, walker output, run surface, driver manifest conversion,
test fixture authoring).

D7'' is a CORRECTION dispatch — branching, stacked on D7' parents,
not a revert. Nine scope items executed:

1. **L1 typealias `Lint.Source.Path = Tagged<Lint.Source, Swift.String>`** — distinct phantom-tag from `Path.Filter.Prefix` (asymmetric haystack/needle roles in the prefix-match relation).
2. **L1 boundary helper `Tagged+HasPrefix.swift`** — `extension Tagged where Underlying == Swift.String { @inlinable public func hasPrefix<OtherTag>(_ other: Tagged<OtherTag, Swift.String>) -> Swift.Bool { underlying.hasPrefix(other.underlying) } }`. Single mechanism site for `Swift.String.hasPrefix`; both sides typed at the call site.
3. **L1 retype `Path.Filter.matches(sourcePath: Lint.Source.Path)`** — body reads `sourcePath.hasPrefix(prefix)` (typed both sides).
4. **L3 walker** — `swiftSourcePaths(under root: File.Path) -> [Lint.Source.Path]` emits run-root-relative paths (strips root prefix before constructing typed values); single-file root case emits empty-relative.
5. **L3 `Lint.Run.run(paths: [File.Path], …)`** — typed pipeline: walker → relative `Lint.Source.Path` → typed filter match → `parsedSource(root:relativePath:manager:)` resolver reconstructs the absolute string for I/O inside its body.
6. **L3 typed extension inits** — `Path.Filter.Prefix.init(_ filePath: File.Path)` and `Lint.Source.Path.init(_ filePath: File.Path)` encapsulate `.description`; Driver call site reads `manifest.excludedPaths.map(Path.Filter.Prefix.init)`.
7. **CLI boundary conversion** — ArgumentParser `[Swift.String]` → `[File.Path]` exactly once at `try paths.map { try File.Path($0) }`; engine receives typed.
8. **Tests drop absolute-root concat** — bare typed prefix literals (`.including(["Sources/A"])`) work because the walker emits relative paths.
9. **Mechanical Swift.String grep** with per-occurrence justification table — categorized as (T) Tagged underlying parameter / (B) boundary mechanism / (R) resolver body / (W) walker body / (P) pre-D7'' API / (D) doc comment / (G) glob pattern API / (O) out-of-scope public surface / (U) UTF-8 byte decoding.

Outcomes: `swift-linter-primitives@f0d15b0` + `swift-linter@fd76f69`
(local commits, unpushed per Ground Rule #6). Clean rebuilds green:
primitives 8/8 tests, foundations 10/10 tests (4 D7' integration tests
now pass with bare `["Sources/A"]` literals via Tagged SLI's
`ExpressibleByStringLiteral`). All 13 Acceptance Criteria + 7
Supervisor Ground Rules verified per `[SUPER-011]` stamp.

HANDOFF triage: 2 in-authority files. `HANDOFF-d7-path-filter-runtime-enforcement.md` (D7' precursor — completed prior session, supervisor constraints #1–#7 all verified per [SUPER-011]) deleted. `HANDOFF-d7p-typed-throughout-correction.md` (this session — all 9 scope items completed, supervisor constraints #1–#7 verified per [SUPER-011] stamp appended this session) deleted. ~35 other HANDOFF-*.md files at workspace root left in place (out of bounded cleanup authority).

## What Worked and What Didn't

**Worked**:

- **Tagged.hasPrefix as the single mechanism site.** The boundary helper is one extension method (~6 lines including doc), and it eliminates `.underlying` from every consumer call site. The asymmetric phantom-tag generic parameter (`OtherTag`) makes `Lint.Source.Path.hasPrefix(Path.Filter.Prefix)` express the haystack-needle relation in the type system itself. This is the [IMPL-010] discipline at its cleanest: bare `Swift.String` survives only inside the helper body; everything above reads typed.

- **Walker run-root-relative emission collapses test ergonomics.** D7' had to compute `root + "/Sources/A"` at every test site because the walker emitted absolute paths. D7'' moved the prefix-strip mechanism into the walker body (one-line `absolute.dropFirst(normalizedRoot.count)`) and tests now use bare typed prefix literals — `.including(["Sources/A"])` — via Tagged SLI's `ExpressibleByStringLiteral`. The Tagged-typed parameter type plus walker-relative emission are the two changes that compose to make the call site read intent.

- **Stacked correction on D7' parents.** Ground Rule #1 directed building incrementally rather than reverting. Two new commits stacked on D7' parents preserved the typed-rim work; D7'' added typed-throughout body operations. No history rewrite, no force-push affordance taken; `git log` shows the two-phase progression cleanly.

**Didn't work as expected**:

- **Brief's `.rawValue` slip.** D7'' brief code samples used `prefix.rawValue.hasPrefix(other.rawValue)` but `Tagged`'s canonical accessor is `.underlying` (verified at `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:71` — `public package(set) var underlying: Underlying`). Caught at verification before edits; mechanical substitution. The slip is symptomatic of `.rawValue` being the broader Swift convention (RawRepresentable, NS-Foundation) — Tagged's deliberate choice of `.underlying` (per the typed-system literature) is institute-specific naming that doesn't auto-recall.

- **`File_System` import shadowing `Swift.String` in the CLI.** Adding `import File_System` to `Linter CLI.swift` brought `String_Primitives.String` into scope, shadowing `Swift.String` at the unqualified name. ArgumentParser's `Decodable` synthesis broke on `var paths: [String]` and `var lintSwiftPath: String?` because the synthesized `init(from:)` couldn't reach `Swift.String.init(from:)` through the now-shadowed name. Mechanical fix: qualify with `Swift.String` at both properties. The build error message (`type 'SwiftLinter' does not conform to protocol 'Decodable'`) was misleading — the proximate cause was the synthesis failure, but the root cause was the namespace shadow two layers up the chain.

## Patterns and Root Causes

**1. Typed-at-the-rim is necessary but not sufficient.** D7' shipped Tagged at the public API surface — `Path.Filter.Prefix`, `Path.Filter.included`, `Path.Filter.excluded`, `Lint.Configuration.excluded` all typed. Every internal call site read `.underlying` to extract `Swift.String` for the predicate (`prefix.underlying.hasPrefix(sourcePath)`), the I/O resolution (`File.Path(stringPath)`), the test fixture (`Path.Filter.Prefix(root + "/Sources/A")`), and the manifest conversion (`manifest.excludedPaths.map { Path.Filter.Prefix($0.description) }`). The defect is an inversion of `[IMPL-010]`: the typed wrapper carried identity at the API surface but unwrapped to the underlying primitive at every operation. The cure is operations on the typed wrapper itself (`Tagged.hasPrefix` as the canonical example — note: the institute pattern is to put boundary operations like `hasPrefix`, `contains`, `split`, `lowercased` on `Tagged where Underlying == Swift.String` so the typed wrapper composes without re-extraction). This is a recurring class — Tagged-based identity for stdlib-underlying types (especially `Swift.String`) has the pattern of "underlying exposed at the property level" that consumers will reach for unless typed operations exist as the path of least resistance. The [skill]-implementation rule should be: when introducing a Tagged-based identity, audit the consumer call sites; if any reach for `.underlying`, that's a typed-operation gap.

**2. Walker emission shape determines consumer ergonomics.** A walker that emits absolute paths forces every consumer to align to absolute form — concat at test sites, `.description` at driver sites, root-prefixing at filter-match sites. D7' deferred the walker fix citing minimum-scope, then carried the deferral as a documented test-deviation; D7'' moved the strip into the walker body (10 lines including the single-file edge case) and the deviation evaporated. The pattern: when test ergonomics force absolute references against a typed identity, the upstream enumerator is probably emitting wrong shape. This generalizes beyond Path.Filter — any walker / iterator / glob emitting "discovered identifiers" should ask "what shape do consumers naturally compose against?" before defaulting to "whatever's cheapest to produce."

**3. Institute namespace primitives shadowing stdlib types is a structural recurring pattern.** D7' surfaced `Linter_Primitives.Path` vs `Paths.Path` collision in `Lint.Run.swift`/`Lint.Driver.swift` (transitively via `File_System`) — fix was fully-qualified `Linter_Primitives.Path.Filter` references. D7'' surfaced `Swift.String` vs `String_Primitives.String` collision in `Linter CLI.swift` after `import File_System` — fix was `Swift.String` qualification at the ArgumentParser properties. Same root cause: institute primitives are deliberately named to mirror their domain meaning (Path, String) and the institute namespace pattern (`Paths.Path`, `String_Primitives.String`) doesn't prevent the unqualified name colliding at consumer sites. The mechanical fix is always Swift-qualification at the consumer; the structural question is how many more such collisions are latent in the pipeline as more institute primitives mature. Worth a research pass at corpus level (catalog of "stdlib name shadowed by which institute namespace; when qualification is needed; whether the typed-wrapper hierarchy sidesteps it") rather than discovering each one at individual session-build time.

## Action Items

- [ ] **[skill]** implementation: When introducing a Tagged-based identity over a stdlib-underlying type (especially `Swift.String`, `Swift.Int`, `Swift.UInt`, `Swift.Double`), pair the typealias with typed operations on `Tagged where Underlying == X` so consumers operate at the typed level. The D7'' `Tagged+HasPrefix` is the model — encapsulates `Swift.String.hasPrefix` inside the typed predicate. Without this discipline, the `[IMPL-010]` rim-typing defect (typed at the surface, `.underlying` at every operation) is the path of least resistance. Audit-target: when a `[skill]/[doc]` review encounters a Tagged-based public API, grep its call sites for `.underlying`; non-zero results indicate missing typed operations.

- [ ] **[research]** Walker / enumerator emission shape and consumer ergonomics: when a walker emits absolute paths, every consumer must align to absolute form — forcing concat at test sites and root-prefix at filter sites. Run-root-relative emission is the single design decision that makes typed prefix literals work without absolute-concat ceremony. Investigate whether this generalizes to other walker-shaped APIs in the institute ecosystem (file walks, glob, archive iteration, manifest discovery, dependency graph traversal, bytecode iteration). The pattern: enumerators that discover identifiers should ask "what shape do consumers compose against?" before defaulting to whatever's cheapest to produce. Author as `swift-institute/Research/walker-emission-shape-and-consumer-ergonomics.md`.

- [ ] **[research]** Institute namespace shadowing of stdlib types — corpus catalog: D7' surfaced `Linter_Primitives.Path` vs `Paths.Path`; D7'' surfaced `Swift.String` vs `String_Primitives.String`. Both are mechanical fixes (Swift-qualification at consumer). The structural question is how many more such collisions are latent as institute primitives mature. Catalog: which stdlib names are shadowed by which institute namespaces, when qualification is needed at consumer sites, whether Tagged-typed identities sidestep it (since `Lint.Source.Path` carries no collision with `Paths.Path`), and whether import-path discipline can pre-empt the discovery cost. Author as `swift-institute/Research/institute-namespace-stdlib-shadowing-catalog.md`.
