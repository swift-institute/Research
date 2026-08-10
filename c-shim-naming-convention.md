# C-Shim Naming Convention and Mechanical Enforcement

<!--
---
version: 1.1.0
last_updated: 2026-08-10
status: RULING PACKAGE (adversarial review complete — RATIFY-WITH-CHANGES applied; awaiting principal ratification of §4)
decision_tier: 2
---
-->

## Context

The naming-rules transaction (swift-foundations/swift-institute-linter-rules#65,
PR #67) extended Nest.Name enforcement to manifest, directory, and file names at
advisory tier. Its fleet sweep flagged the C-shim directories (`CDarwinKernelShim`
and siblings) as a convention class needing a principal ruling before the rules
graduate to error tier: the targets carry concatenated C-prefixed names that the
spaced Nest.Name grammar reads as compound-word violations.

This document determines (1) what the convention for C-interop target names
SHOULD be, and (2) its fully-automated mechanical enforcement. Placement of C
shims (which package owns which shim) was settled separately in
[C Shim Placement Architecture](c-shim-placement-architecture.md); this ruling
covers naming only.

## 1. Census

Every C-interop target in canonical Institute checkouts (clang targets,
`module.modulemap`-bearing targets, system-library targets), enumerated by three
independent predicates — authored `module.modulemap` presence, C-family
source/header presence in a `Sources/<dir>`, and manifest declaration scan. All
three fired on the positive control `CDarwinKernelShim`. Build directories, lane
worktrees, dependency checkouts, and a duplicate task-branch checkout of
`swift-windows-32` were excluded.

### 1.1 Importable C targets (regular `.target`, clang module)

| Target / module / directory | Package | Layer | Modulemap | Shims |
|---|---|---|---|---|
| `CCPUShim` | swift-cpu-primitives | L1 | authored | cross-arch atomics, barriers |
| `_Shims` | swift-numeric-primitives | L1 | auto | libm |
| `CARMShim` | swift-arm-standard | L2 | authored | ARM register/instruction access |
| `CX86Shim` | swift-x86-standard | L2 | authored | x86 CPUID and intrinsics |
| `CDarwinKernelShim` | swift-darwin-standard | L2 | authored | Darwin `sys/mman.h`, `fcntl.h`, `dlfcn.h`, … |
| `CDarwinMemoryShim` | swift-darwin-standard | L2 | authored | Darwin malloc-zone statistics |
| `CLinuxKernelShim` | swift-linux-standard | L2 | authored | Linux headers absent from SwiftGlibc |
| `CLinuxMemoryShim` | swift-linux-standard | L2 | authored | Linux allocation tracking |
| `CWindowsMemoryShim` | swift-windows-32 | L2 | authored | Windows heap statistics |
| `CISO9945Shim` | swift-iso-9945 | L2 | authored | POSIX variadic/macro wrappers |
| `CPOSIXProcessShim` | swift-iso-9945 | L2 | authored | `fork`, wait macros, spawn |
| `CISO9899Math` | swift-iso-9899 | L2 | auto | C standard library `math.h` |
| `CISO9899Errno` | swift-iso-9899 | L2 | auto | `errno.h` |
| `CISO9899String` | swift-iso-9899 | L2 | auto | `string.h` |
| `CISO9899Ctype` | swift-iso-9899 | L2 | auto | `ctype.h` |
| `CISO9899Stdlib` | swift-iso-9899 | L2 | auto | `stdlib.h` |
| `CIEEE754` | swift-ieee-754 | L2 | auto | FPU environment (C implementations) |
| `CTypeMetadata` | swift-loader | L3 | auto | Swift runtime metadata (C++) |
| `CAllocationTracking` | swift-testing-performance | L3 | auto | allocation hooks (Linux-only) |

### 1.2 System-library targets (`.systemLibrary`)

| Target / module | Package | Layer | Notes |
|---|---|---|---|
| `imagemagick` | swift-image-magick | L3 | pkgConfig `MagickWand-7.Q16HDRI`; lowercase name |

### 1.3 Out of the importable class (recorded, not in scope)

- `iso-9945-test-helper` (swift-iso-9945): an **executableTarget** built from C
  sources at `path: "Sources/CPOSIXTestHelper"`. Executables expose no
  importable module, so the C-interop module grammar does not reach them; the
  target-name and directory questions belong to the parent manifest/path rules.
- `CUring` (swift-io, `Experiments/proactor-buffer-ownership`): liburing shim in
  a scratch experiment package, not a canonical surface.

### 1.4 Census facts that bear on the ruling

1. **No C-interop target is exported as a product.** Every consumer is a Swift
   target inside the owning package; `import CFooShim` statements exist only
   in-package. A rename therefore never breaks an external consumer.
2. **Everywhere conforming, one spelling carries three surfaces**: target name
   == module identifier == directory basename. There is no skew anywhere in the
   fleet today.
3. Three name shapes exist: `C…Shim` re-export shims (11), `C…` C/C++
   implementation targets without the suffix (8: `CISO9899*`, `CIEEE754`,
   `CTypeMetadata`, `CAllocationTracking`), and two nonconforming outliers
   (`_Shims`, `imagemagick`).
4. `swift-image-magick` also declares its **package** name as
   `SwiftImageMagick`, a kebab-slug violation owned by the existing manifest
   rule — recorded here, not part of this ruling.

## 2. Toolchain constraints (compiling probes)

Probes ran on the pinned Swift 6.4 toolchain (`swiftlang-6.4.0.27.1`,
arm64-apple-macosx), each probe on **both** build backends (default
swift-build/PIF and `--build-system native`, the backend Linux CI exercises).
Scratch packages, one probe per package; all probes are two-target packages (the
C target plus a Swift executable consumer that calls a shimmed function).

| # | Probe | Result |
|---|---|---|
| P1 | Clang target named `"C Darwin Probe"` (spaced), spaced directory, **no** authored modulemap | **Builds** on both backends. SwiftPM derives the module identifier by C99 mangling: the consumer imports `C_Darwin_Probe` (spaces become underscores). |
| P2 | Spaced target name + authored modulemap declaring `module CDarwinProbe` | **Builds** on both backends, no diagnostic. SwiftPM imposes **no** correspondence between target name and authored module name; consumer imports `CDarwinProbe`. |
| P3 | Authored modulemap declaring `module "C Darwin Probe"` (string-literal name) | clang **accepts** the quoted spaced module name and builds a PCM for it (verified directly with `clang -fmodules -Rmodule-build`). But Swift's `import` grammar takes identifiers only — the plain and backticked spellings both fail — so a spaced module is **unreachable from Swift**. |
| P4 | Spaced target name + concatenated directory via explicit `path:` | **Builds.** Directory naming is fully decoupled from the target name. |
| P5 | `.systemLibrary(name: "Image Probe")` (spaced) with modulemap `module ImageProbe` | **Builds.** System-library target names are equally free; the import uses the modulemap identifier. |

Constraint map:

| Surface | Constrained by toolchain? |
|---|---|
| Module identifier (the `import` spelling) | **Yes** — must be a Swift-importable identifier; no spaces. |
| SwiftPM target name (clang or systemLibrary) | No — spaces legal on both backends. |
| Directory name | No — free, including via explicit `path:`. |
| Authored module name vs target name | No — no matching requirement, no warning. |
| Auto-generated modulemap | Module identifier = c99name of the target name (spaces → underscores). |

Evidence boundary: probes are macOS/arm64. The native backend run is the same
code path Linux CI uses, and no probe touched a platform-conditional surface, so
Linux divergence is unlikely; a Linux CI re-run of P1/P2 is listed as a
graduation-gate check rather than assumed.

## 3. Convention options

The probes establish that the toolchain constrains exactly one surface — the
module identifier — and leaves target and directory names free. The ruling is
therefore a genuine convention choice among:

### Option A — C-interop grammar as a sibling rule (recommended)

C-interop targets keep the upstream ecosystem convention on **all three
surfaces**: target name == module identifier == directory basename, spelled as a
concatenated C-prefixed PascalCase identifier (`CDarwinKernelShim`). The spaced
Nest.Name grammar's scope is bounded to Swift-module targets; C-interop targets
get their own grammar, scoped by a mechanically derived target kind.

- **Authority.** The `C`-prefix concatenated module convention is the
  Swift-ecosystem-wide standard for C interop (`COpenSSL`, `CSQLite`,
  `CNIOLinux`, `CSystem`, …). L2 doctrine already prefers 1:1 encodings of an
  external authority's tokens; a C-interop module identifier is exactly such a
  spec-mirroring identifier, and the compound-word prohibitions do not apply to
  spec-mirroring forms.
- **Doctrinal fit.** The spaced-target ruling's own rationale is that a target
  name is the spaced spelling of the Swift nest it contains. A C-interop target
  contains no Swift nest — the rule's justification does not reach it. This is a
  scope boundary keyed on target kind, not a §8.5 exemption list: no
  coordinates, no authored labels, nothing to govern per-package.
- **Identity.** One spelling carries manifest, import site, modulemap, and
  directory. Grep coherence between `import CDarwinKernelShim` and
  `Sources/CDarwinKernelShim/` is preserved. This is the fleet's current
  conforming state (census fact 2).
- **Migration:** two renames (`imagemagick`, `_Shims`). Consumer impact: none
  outside the owning packages (census fact 1).

### Option B — spaced target/directory, unspaced module identifier (rejected)

P2 proves the hybrid is buildable: target `"C Darwin Kernel Shim"`, directory
spaced, authored modulemap pinning `module CDarwinKernelShim`, imports
unchanged. Rejected because it splits one identity into two spellings that must
be kept in correspondence by a **new** predicate (spaced form ↔ concatenation),
desynchronizes import sites from directory names, and forces authored
modulemaps onto the nine auto-modulemap targets solely to pin the identifier
(else P1's silent underscore mangling changes every in-package import to
`C_Darwin_Kernel_Shim` forms). Fleet-wide cost: ~19 target renames + 19
directory renames + 9 new modulemaps, and the 127 in-fleet `import C…` sites
would spell a name matching no target or directory anywhere — permanent
name≠identifier≠directory skew normalized only by a new correspondence
predicate. The directory-grammar uniformity gained is real but manifest-side
only: the import spelling stays concatenated under every option, because the
toolchain pins it.

### Option C — spaced everywhere (infeasible)

P3: a spaced module identifier is declarable in clang but unreachable from
Swift's `import` grammar. No full-spaced convention exists to choose.

### Sub-question: the `Shim` suffix

The census splits into re-export shims (`C…Shim`: header adapters over an SDK)
and C/C++ implementation targets (`CIEEE754`, `CTypeMetadata`, …: real compiled
code). The distinction is semantic — what the target *is*, not how it is
spelled — and no reliable mechanical discriminator exists (most shims also carry
a stub `.c`). The suffix therefore stays **authored judgment**: the grammar
below requires the `C`-prefix form and does not mandate or forbid `Shim`.

## 4. Ruling (proposed)

> **C-interop naming grammar.** A target that SwiftPM classifies as a clang
> module target or a system-library target names one C-interop module. Its
> SwiftPM target name, its module identifier, and its source-directory basename
> are one spelling: a concatenated identifier matching
> `C` + uppercase-or-digit + alphanumerics (regex `^C[A-Z0-9][A-Za-z0-9]*$`;
> no spaces, no underscores). An authored `module.modulemap` must declare
> exactly one top-level module bearing that spelling; a target relying on the
> auto-generated modulemap must already be spelled as a valid C99 identifier so
> the derived module identifier equals the target name. The spaced Nest.Name
> manifest/directory grammar does not apply to targets of this kind.
> C-language **executable** targets expose no module and stay under the parent
> manifest/path rules.

## 5. Mechanical enforcement

### 5.1 Class detection (derived, never authored)

A target is **C-interop** iff:

- its manifest factory is `.systemLibrary`; or
- its manifest factory is `.target` and its resolved source directory contains
  at least one file whose extension is in **SwiftPM's own supported
  clang-family source and header set** (C/C++/Objective-C sources and headers
  **and assembly** — `.c .cc .cpp .cxx .c++ .m .mm .h .hh .hpp` `.S .s` — or a
  `module.modulemap`) and **no** `.swift` file — SwiftPM's own clang-target
  classification, re-derived from manifest + filesystem facts. The
  implementation MUST key this set to SwiftPM's supported-extension list rather
  than a locally authored copy: an assembly-only clang target (`probe.S`, no
  C files) builds on the pinned 6.4 toolchain and must classify C-interop
  (adversarial-review finding, verified by two sessions independently).

No annotation, comment, name shape, or registry entry ever feeds the
classifier. In particular the `C` prefix itself is **not** the class signal:
Swift targets named `CPU` or `CSS Test Support` must classify as Swift targets
(near-miss fixtures below).

### 5.2 Predicate owners (Axiom 9: one predicate, one owner)

The full predicate needs manifest facts **and** filesystem facts. swift-linter's
rules are AST-local over the file being linted, and a C-interop target contains
no lintable Swift file — the linter structurally cannot see C-target directories
or modulemaps. The enforcement therefore splits along fact ownership:

**R1 — amendment to `manifest naming grammar`
(owner: swift-institute-linter-rules, Naming family).** Operating on the
manifest AST alone:

- *R1a.* A single-token `.target`/product name matching
  `^C[A-Z0-9][A-Za-z0-9]*$` is admitted (not a compound-word violation). The
  linter cannot prove the target is clang from the AST; it admits the C-interop
  spelling and leaves kind verification to R2.
- *R1b.* A `.systemLibrary(name:)` string MUST match `^C[A-Z0-9][A-Za-z0-9]*$`
  (fires today on `imagemagick`).
- *R1c.* A `.target` name that is neither a spaced Nest.Name form nor an
  admitted C-interop form remains a violation (fires today on `_Shims`).

R1a's admission window: a **Swift** target wrongly given a concatenated `C…`
name (e.g. `CSSParser`) is admitted by R1a at the manifest. The package's
original claim that path-rule composition closes this window was **overturned**
under adversarial review (an explicit grammatical `path:` evades every
composed rule); the window is instead closed by R2d in the validator, the
owner of target-kind facts. Live-fleet exposure while R2d ships: of 2,972
distinct declared names in canonical manifests, the C-interop grammar matches
only the census C-targets plus the single words `CPU` and `CSS` — the
evasion class is currently an empty set.

**R2 — new validator predicates
(owner: the Workspace/Institute validator family, per the 2026-08-06 Nest.Name
directory ruling assigning manifest↔filesystem correspondence there).** For
every target the §5.1 classifier marks C-interop:

- *R2a (grammar).* Target name matches `^C[A-Z0-9][A-Za-z0-9]*$`.
- *R2b (module identity).* If an authored `module.modulemap` exists under the
  target directory, it declares exactly one top-level module whose name equals
  the target name. If none exists, the target name must itself be a valid C99
  identifier — which under R2a it already is — so the auto-derived module
  identifier equals the target name and P1's silent underscore mangling cannot
  occur. Implementation precision (adversarial-review finding 4): clang module
  maps admit string-literal module names (`module "CFoo"`), `framework module`,
  and `extern module` declaration forms; the equality compares the **decoded**
  module name, and the one-top-level-module count is defined over all
  declaration forms.
- *R2c (directory).* The target's source-directory basename equals the target
  name (default layout or explicit `path:` alike).
- *R2d (inverse predicate — closes the review's finding 1).* A target the
  classifier does **not** mark C-interop whose declared name matches the
  C-interop grammar and is not a single grammatical word is a violation. This
  replaces the original blanket carve-out ("non-classified targets are excluded
  from R2a–R2c"), whose closure argument was **overturned** under adversarial
  review: a Swift target `.target(name: "CSSParser", path: "Sources/Parser")`
  evades R1a (name admitted), the spacing-only path predicate (substantive
  difference — recorded residue), the per-file path grammar (directory
  `Parser` is grammatical), and the API-IMPL/API-NAME composition (grammatical
  basenames) — nothing fires. The compositional backstop holds only when the
  directory repeats the concatenated name, precisely what an evader avoids.
  R2d closes the window at the owner of kind facts. Single grammatical words
  (`CPU`, `CSS`) stay admitted by both grammars.
- *Scope.* Targets classified C-interop are excluded from the spaced
  manifest/directory predicates and take R2a–R2c; targets not so classified
  take the spaced grammar plus R2d. Exactly one grammar applies to every
  target, and the C-form near-miss is policed on both sides of the boundary.

### 5.3 Fixture set (rule-maturity gate §8.4)

| Kind | Fixtures |
|---|---|
| Positive (fires) | `.systemLibrary(name: "imagemagick")`; clang target `_Shims`; clang target with spaced name `"C Darwin Probe"`; authored modulemap declaring `CDarwinProbe` under target `CDarwinShim` (R2b mismatch); modulemap declaring two top-level modules; clang target `CFooShim` with `path:` ending `Sources/CFoo` (R2c); Swift target `.target(name: "CSSParser", path: "Sources/Parser")` — the review's evasion counterexample (R2d). |
| Negative (silent) | The canonical shape (`CDarwinKernelShim`, authored modulemap, matching directory); the auto-modulemap shape (`CISO9899Math`, valid identifier, no authored map); `CIEEE754` (digits, no suffix); `CTypeMetadata` (C++ sources). |
| Edge | Conditional platform dependency on the shim; nested test-package manifest; `Package@swift-*` variant manifest; modulemap with submodules under one top-level module (one top-level module — passes R2b). |
| Near-miss | Swift target named `CPU` (single word, not classified C-interop, admitted by both grammars); Swift target `CSS Test Support` (spaced, classified Swift); C-language `executableTarget` from `Sources/CPOSIXTestHelper` (excluded from the importable class); assembly-only clang target (`probe.S` + `include/`, no C files — must classify C-interop, the review's classifier-drift counterexample). |
| Exemption | None. The design has no exemption list; the §5.1 class boundary is the only scoping mechanism, and it is derived. |
| Self-firing | The rule packs' and validator's own fixture trees must not fire on their host repositories' real manifests. |
| Positive control | `CDarwinKernelShim` with its name mutated to `cDarwinKernelShim` in a fixture proves each of R1/R2a can fire before any sweep result is accepted. |

### 5.4 Graduation path

1. **Now (advisory).** Land R1 as an amendment to `manifest naming grammar` at
   `.warning`, same tier as the parent rules. Effect on the live fleet: the ~17
   conforming C-interop targets stop firing the compound-word predicate;
   `imagemagick` and `_Shims` start firing correctly.
2. **Migration wave (2 renames, in-package only).**
   - swift-image-magick: `imagemagick` → `CImageMagick` (target, directory,
     modulemap module, in-package import sites).
   - swift-numeric-primitives: `_Shims` → a `C…`-form name chosen by the
     package owner (`CNumericShim` suggested; it shims libm), same four
     surfaces. The `public import _Shims` history in that package means the
     rename touches its leaf-product interface files — still in-package.
3. **R2 in the validator** ships with its own fixture tree and a fleet sweep;
   its unsuppressed baseline is zero once the wave lands (census fact 2: no
   skew exists today).
4. **Error tier.** After the wave, the C-interop baseline is zero with **no**
   legacy exceptions; R1's amendment graduates to error in lockstep with the
   parent naming rules (it is the same rule), and R2 graduates on the
   validator's cadence. Gate check before graduation: re-run probes P1/P2 on
   Linux CI to close the macOS-only evidence boundary.

## 6. Stop conditions and open questions

- The replacement name for `_Shims` is the package owner's choice within the
  grammar; this ruling constrains the form only.
- The `Shim`-suffix semantics (re-export shim vs implementation target) stays
  authored; if a future mechanical discriminator is wanted, it needs its own
  investigation — do not encode it from name shape.
- If a future package legitimately needs two top-level modules in one authored
  modulemap, R2b's one-module predicate is the stop condition: that shape is a
  new convention question, not an exception to grant locally.
- **Recorded consequence** (adversarial-review finding 3): the grammar's
  underscore rejection deliberately forecloses the wider Swift ecosystem's
  underscore-prefixed internal-module idiom (`_SwiftSyntaxCShims`-class) for
  Institute C-interop targets, and its second-character rule requires
  re-spelling lowercase upstream family names (`Curl` → `CCurl`,
  `Cmark` → `CMark`). The census shows neither idiom in Institute use; both
  are convention choices, recorded here so they are ratified, not accidental.
