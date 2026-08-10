# C-Shim Naming Convention and Mechanical Enforcement

<!--
---
version: 2.0.0
last_updated: 2026-08-10
status: RULING PACKAGE (recut under the principal's 2026-08-10 ruling; awaiting coordinator review of the recut)
decision_tier: 2
---
-->

## Context

The naming-rules transaction (swift-foundations/swift-institute-linter-rules#65,
PR #67) extended Nest.Name enforcement to manifest, directory, and file names at
advisory tier. Its fleet sweep flagged the C-shim directories (`CDarwinKernelShim`
and siblings) as a convention class needing a principal ruling before the rules
graduate to error tier.

**History of this document.** Version 1 recommended keeping the upstream
C-prefixed concatenated convention as a sibling grammar; it survived a
collaborative adversarial review (RATIFY-WITH-CHANGES, two enforcement fixes
absorbed). The principal then **overruled** the v1 recommendation with a durable
ruling: C-shims use the spaced Nest.Name grammar with a `* Shims` shape, the
same grammar as every other target. This version is the recut under that
ruling: the census and toolchain constraints stand unchanged; the convention,
migration wave, and enforcement are recut. Both adversarial-review enforcement
fixes are retained in recut form.

Placement of C shims (which package owns which shim) was settled separately in
[C Shim Placement Architecture](c-shim-placement-architecture.md); this ruling
covers naming only.

## 1. Census

Every C-interop target in canonical Institute checkouts (clang targets,
`module.modulemap`-bearing targets, system-library targets), enumerated by three
independent predicates — authored `module.modulemap` presence, C-family
source/header presence in a `Sources/<dir>`, and manifest declaration scan — and
confirmed by the adversarial review's independent re-sweep (which also verified
the suborgs beyond these roots carry no C-interop targets). All predicates fired
on the positive control `CDarwinKernelShim`. Build directories, lane worktrees,
dependency checkouts, fixture trees, and a duplicate task-branch checkout of
`swift-windows-32` were excluded.

### 1.1 Importable C targets (regular `.target`, clang module)

| Current target / module / directory | Package | Layer | Modulemap | Shims | Import sites |
|---|---|---|---|---|---|
| `CCPUShim` | swift-cpu-primitives | L1 | authored | cross-arch atomics, barriers | 8 |
| `_Shims` | swift-numeric-primitives | L1 | auto | libm | 2 |
| `CARMShim` | swift-arm-standard | L2 | authored | ARM register/instruction access | 4 |
| `CX86Shim` | swift-x86-standard | L2 | authored | x86 CPUID and intrinsics | 3 |
| `CDarwinKernelShim` | swift-darwin-standard | L2 | authored | Darwin `sys/mman.h`, `fcntl.h`, `dlfcn.h`, … | 2 |
| `CDarwinMemoryShim` | swift-darwin-standard | L2 | authored | Darwin malloc-zone statistics | 1 |
| `CLinuxKernelShim` | swift-linux-standard | L2 | authored | Linux headers absent from SwiftGlibc | 53 |
| `CLinuxMemoryShim` | swift-linux-standard | L2 | authored | Linux allocation tracking | 1 |
| `CWindowsMemoryShim` | swift-windows-32 | L2 | authored | Windows heap statistics | 1 |
| `CISO9945Shim` | swift-iso-9945 | L2 | authored | POSIX variadic/macro wrappers | 5 |
| `CPOSIXProcessShim` | swift-iso-9945 | L2 | authored | `fork`, wait macros, spawn | 11 |
| `CISO9899Math` | swift-iso-9899 | L2 | auto | C standard library `math.h` | 13 |
| `CISO9899Errno` | swift-iso-9899 | L2 | auto | `errno.h` | 1 |
| `CISO9899String` | swift-iso-9899 | L2 | auto | `string.h` | 7 |
| `CISO9899Ctype` | swift-iso-9899 | L2 | auto | `ctype.h` | 1 |
| `CISO9899Stdlib` | swift-iso-9899 | L2 | auto | `stdlib.h` | 5 |
| `CIEEE754` | swift-ieee-754 | L2 | auto | FPU environment (C implementations) | 6 |
| `CTypeMetadata` | swift-loader | L3 | auto | Swift runtime metadata (C++) | 1 |
| `CAllocationTracking` | swift-testing-performance | L3 | auto | allocation hooks (Linux-only) | 1 |

### 1.2 System-library targets (`.systemLibrary`)

| Target / module | Package | Layer | Import sites | Notes |
|---|---|---|---|---|
| ~~`imagemagick`~~ | ~~swift-image-magick~~ | — | — | **OUT-OF-FLEET: the repository is archived** (see §1.5) |

### 1.3 Out of the importable class (recorded, not in scope)

- `iso-9945-test-helper` (swift-iso-9945): an **executableTarget** built from C
  sources at `path: "Sources/CPOSIXTestHelper"`. Executables expose no
  importable module; the target-name and directory questions belong to the
  parent manifest/path rules.
- `CUring` (swift-io, `Experiments/proactor-buffer-ownership`): liburing shim in
  a scratch experiment package, not a canonical surface.

### 1.5 Archived repositories are out-of-fleet (ruled during execution)

`swift-foundations/swift-image-magick` is **archived**. An archived repository
is read-only — push, issue, and visibility mutations all fail — so a naming
finding against one is **permanently unactionable**: a report no lawful action
can ever clear. The coordinator ruled during wave execution (2026-08-10) that
archived repositories leave sweep scope entirely, generalized beyond this rule;
roughly 75 Institute repositories are deliberately archived, so this is
structural rather than a one-off.

`imagemagick` is therefore recorded as out-of-fleet, not as an outstanding
violation. **The migration wave is 19 targets across 12 repositories**, not 20
across 13. The rename was authored before the archive status was discovered and
was reverted; the repository is untouched.

The census's own omission is part of the finding and is encoded as an R2
requirement (§5.2): enumeration that reads a local checkout tree sees archived
repositories exactly like live ones — **filesystem presence is not fleet
membership**, and `.archived` must be resolved through the API before a target
is counted.

### 1.4 Census facts that bear on the ruling

1. **No C-interop target is exported as a product.** Every consumer is a Swift
   target inside the owning package; the 127 `import` sites (per-target counts
   above) exist only in-package. A rename therefore never breaks an external
   consumer.
2. Everywhere conforming today, one spelling carries target name == module
   identifier == directory basename; there is no skew in the fleet.
3. `swift-image-magick` also declares its **package** name as
   `SwiftImageMagick`, a kebab-slug violation owned by the existing manifest
   rule — recorded here, not part of this ruling.

## 2. Toolchain constraints (compiling probes)

Probes ran on the pinned Swift 6.4 toolchain (`swiftlang-6.4.0.27.1`,
arm64-apple-macosx), each probe on **both** build backends (default
swift-build/PIF and `--build-system native`, the backend Linux CI exercises).
Scratch packages, one probe per package; each is a two-target package (the C
target plus a Swift executable consumer calling a shimmed function).

| # | Probe | Result |
|---|---|---|
| P1 | Clang target named `"C Darwin Probe"` (spaced), spaced directory, **no** authored modulemap | **Builds** on both backends. SwiftPM derives the module identifier by C99 mangling: the consumer imports `C_Darwin_Probe` (spaces become underscores). |
| P2 | Spaced target name + authored modulemap declaring `module CDarwinProbe` | **Builds** on both backends, no diagnostic. SwiftPM imposes **no** correspondence between target name and authored module name. |
| P3 | Authored modulemap declaring `module "C Darwin Probe"` (string-literal name) | clang **accepts** the quoted spaced module name and builds a PCM (verified directly with `clang -fmodules -Rmodule-build`). But Swift's `import` grammar takes identifiers only — plain and backticked spellings both fail — so a spaced module is **unreachable from Swift**. |
| P4 | Spaced target name + concatenated directory via explicit `path:` | **Builds.** Directory naming is fully decoupled from the target name. |
| P5 | `.systemLibrary(name: "Image Probe")` (spaced) with modulemap `module ImageProbe` | **Builds.** System-library names are equally free; the import uses the modulemap identifier. |
| P6 | Assembly-only `.target` (`probe.S`, no C files) | **Builds** as a clang target (adversarial-review counterexample, re-verified independently). The classifier must include assembly extensions. |
| P7 | Spaced target `"Darwin Kernel Probe"` + authored modulemap declaring `module Darwin_Kernel_Probe` (the c99 underscored mirror); consumer `import Darwin_Kernel_Probe` | **Builds on both backends.** The ruled convention's exact shape is realizable with authored modulemaps, and converges with P1's auto-derivation. |

Constraint map:

| Surface | Constrained by toolchain? |
|---|---|
| Module identifier (the `import` spelling) | **Yes** — must be a Swift-importable identifier; no spaces. |
| SwiftPM target name (clang or systemLibrary) | No — spaces legal on both backends. |
| Directory name | No — free, including via explicit `path:`. |
| Authored module name vs target name | No — no matching requirement, no warning. |
| Auto-generated modulemap | Module identifier = c99name of the target name (spaces → underscores). |

Evidence boundary: probes are macOS/arm64, both backends. The adversarial
review confirmed the one binding constraint is Swift language grammar
(platform-invariant) and the underscore mangling is shared SwiftPM code; a
Linux CI re-run of P1/P7 remains the pre-error-tier gate.

## 3. The principal's ruling and the identifier surface

### 3.1 Ruling (principal, 2026-08-10, relayed on #65 — durable)

> C-shims do **not** use concatenated compound identifiers; they use the spaced
> Nest.Name grammar with a `* Shims` shape (`Darwin Kernel Shims`), the same
> grammar as every other target. Target names and directories go spaced.

This overrules v1's recommendation. Under it, exactly one surface still cannot
be spaced — the module identifier Swift `import` names (P3). The remaining
convention question is the identifier form, settled below.

### 3.2 Identifier options under the ruling

| Option | Shape | Assessment |
|---|---|---|
| **I1 — c99 underscored mirror (recommended)** | `"Darwin Kernel Shims"` → `import Darwin_Kernel_Shims` | This is what SwiftPM **auto-derives** from the spaced target name (P1), and it is already the Institute's established import spelling for spaced *Swift* targets (`Base62_Primitives`-style module disambiguation). The identifier is a mechanical function of the target name — no second choice to govern, no authored map required to pin it (P7 proves authored maps converge on the same spelling where they exist to curate headers). C-interop imports become uniform with Swift-target imports across the fleet. |
| I2 — concatenated mirror | `import DarwinKernelShims` | Requires an authored modulemap on all 20 targets solely to override the auto-derivation; reintroduces a concatenated compound identifier the ruling just removed from the name surface; makes the identifier an authored choice instead of a derived fact. Rejected. |
| I3 — C-prefix retained at identifier only | `import CDarwinKernelShims` | Maximum continuity with the upstream `CFoo` idiom, but the identifier stops being any mechanical function of the target name (prefix added *and* spaces removed), needs authored maps on all 20 targets, and preserves the old spelling class at exactly the surface developers read most. Rejected. |

**Convention (recut §4, for ratification of the identifier half):**

> A C-interop target takes a spaced Nest.Name target name with terminal word
> `Shims`, an identically named source directory, and the module identifier
> auto-derived from that name by c99 mangling (spaces → underscores). An
> authored `module.modulemap`, where present to curate headers, declares
> exactly one top-level module named exactly that c99 mirror. Consumers import
> the mirror: `import Darwin_Kernel_Shims`.

Spec-mirroring note: name words that transliterate C standard tokens
(`Errno`, `Ctype`, `Stdlib` — header names of ISO 9899) are spec-mirroring
forms under the existing L2 rule and are not compound-word violations.

## 4. Migration wave (recut)

All renames touch four surfaces per target — manifest name, directory,
authored-modulemap module name (where present), and in-package import sites —
and nothing outside the owning package (census fact 1). Proposed names follow
the domain nest; final word choice within the grammar is the owning package's.

| Current | Proposed target/directory | Import spelling | Sites | Package |
|---|---|---|---|---|
| `CCPUShim` | `CPU Shims` | `CPU_Shims` | 8 | swift-cpu-primitives |
| `_Shims` | `Numeric Shims` (suggested) | `Numeric_Shims` | 2 | swift-numeric-primitives |
| `CARMShim` | `ARM Shims` | `ARM_Shims` | 4 | swift-arm-standard |
| `CX86Shim` | `x86 Shims` | `x86_Shims` | 3 | swift-x86-standard |
| `CDarwinKernelShim` | `Darwin Kernel Shims` | `Darwin_Kernel_Shims` | 2 | swift-darwin-standard |
| `CDarwinMemoryShim` | `Darwin Memory Shims` | `Darwin_Memory_Shims` | 1 | swift-darwin-standard |
| `CLinuxKernelShim` | `Linux Kernel Shims` | `Linux_Kernel_Shims` | 53 | swift-linux-standard |
| `CLinuxMemoryShim` | `Linux Memory Shims` | `Linux_Memory_Shims` | 1 | swift-linux-standard |
| `CWindowsMemoryShim` | `Windows Memory Shims` | `Windows_Memory_Shims` | 1 | swift-windows-32 |
| `CISO9945Shim` | `ISO 9945 Shims` | `ISO_9945_Shims` | 5 | swift-iso-9945 |
| `CPOSIXProcessShim` | `POSIX Process Shims` | `POSIX_Process_Shims` | 11 | swift-iso-9945 |
| `CISO9899Math` | `ISO 9899 Math Shims` | `ISO_9899_Math_Shims` | 13 | swift-iso-9899 |
| `CISO9899Errno` | `ISO 9899 Errno Shims` | `ISO_9899_Errno_Shims` | 1 | swift-iso-9899 |
| `CISO9899String` | `ISO 9899 String Shims` | `ISO_9899_String_Shims` | 7 | swift-iso-9899 |
| `CISO9899Ctype` | `ISO 9899 Ctype Shims` | `ISO_9899_Ctype_Shims` | 1 | swift-iso-9899 |
| `CISO9899Stdlib` | `ISO 9899 Stdlib Shims` | `ISO_9899_Stdlib_Shims` | 5 | swift-iso-9899 |
| `CIEEE754` | `IEEE 754 Shims` | `IEEE_754_Shims` | 6 | swift-ieee-754 |
| `CTypeMetadata` | `Type Metadata Shims` | `Type_Metadata_Shims` | 1 | swift-loader |
| `CAllocationTracking` | `Allocation Tracking Shims` | `Allocation_Tracking_Shims` | 1 | swift-testing-performance |
| ~~`imagemagick`~~ | — not actionable — | — | — | swift-image-magick (**archived**, §1.5) |

Wave shape: **12 repository PRs, 19 targets, ~126 import sites** (revised: swift-image-magick is archived and out-of-fleet, §1.5), ordinary PR
flow in each owning repo (no history involvement). Heaviest single edit:
swift-linux-standard (54 files). The nine auto-modulemap targets need **no**
new modulemap — the auto-derived identifier is the convention. The eleven
authored modulemaps have their module declaration renamed to the c99 mirror in
the same PR. Judgment flags for owners inside the grammar: the `_Shims`
replacement word, and whether the systemLibrary binding prefers a different
domain word than `Image Magick Shims`.

## 5. Mechanical enforcement (recut, both adversarial-review fixes retained)

### 5.1 Class detection (derived, never authored — review fix 2 retained)

A target is **C-interop** iff:

- its manifest factory is `.systemLibrary`; or
- its manifest factory is `.target` and its resolved source directory contains
  at least one file in **SwiftPM's own supported clang-family source and
  header extension set** (C/C++/Objective-C sources and headers **and
  assembly** — `.c .cc .cpp .cxx .c++ .m .mm .h .hh .hpp .S .s` — or a
  `module.modulemap`) and **no** `.swift` file. The implementation MUST key
  this set to SwiftPM's supported-extension list, not a locally authored copy:
  an assembly-only clang target builds on the pinned 6.4 toolchain (P6) and
  must classify C-interop.

No annotation, name shape, or registry entry feeds the classifier. Mixed
Swift+C targets cannot exist (SwiftPM rejects mixed-language targets —
review-verified), so the no-`.swift` conjunct cannot misfire.

### 5.2 Predicates and owners (Axiom 9)

Under the ruling, C-interop targets take the **same** spaced grammar as every
other target, which dissolves most of v1's special-casing:

**R1 — `manifest naming grammar` (swift-institute-linter-rules, Naming
family).** One amendment only: add `.systemLibrary` to the policed factory set
(it is absent today). No C-form admission exists any more — concatenated
`CDarwinKernelShim`-class names are ordinary compound-word violations, which is
now the *correct* verdict; the current advisory firings become the migration
work-list. The `path name grammar` rule needs no change (C-target directories
still contain no lintable file; their directory surface is R2's).

**R2 — validator predicates (Workspace/Institute validator family, owner of
manifest↔filesystem and kind facts).** For every §5.1-classified target:

- *R2a (grammar).* The target name is a spaced Nest.Name form whose terminal
  word is `Shims`, with each word passing the shared compound-word predicate
  (spec-mirroring forms exempt as everywhere).
- *R2b (module identity).* If an authored `module.modulemap` exists under the
  target directory, it declares exactly one top-level module whose **decoded**
  name (string-literal, `framework module`, and `extern module` declaration
  forms included — review fix 4) equals the c99 mirror of the target name. If
  no authored map exists, the auto-derivation produces the mirror by
  construction and nothing further is checked.
- *R2c (directory).* The target's source-directory basename equals the spaced
  target name (default layout or explicit `path:` alike).
- *R2d (suffix reservation — review fix 1, recut).* A target the classifier
  does **not** mark C-interop whose name's terminal word is `Shims` (or
  `Shim`) is a violation: the suffix is the class's ruled shape, and a Swift
  target wearing it would assert C-interop kind it does not have. This is the
  recut of the review's inverse predicate; it lives with the kind-facts owner
  for the same reason. (V1's evasion counterexample dissolves — there is no
  admission at the manifest any more — but the misleading-suffix window this
  closes is the same class of hole, policed on both sides of the boundary.)
- *R2e (fleet-membership precondition — ruled 2026-08-10, generalized beyond
  this rule).* Repository enumeration excludes every repository with
  `.archived == true`, resolved through the API rather than inferred from a
  checkout tree. A rule firing on an archived repository yields a permanently
  unactionable finding — the informationless-gate shape in reverse. Fixtures
  prove the exclusion by contrast: an archived repository carrying a violating
  target must NOT fire, while a live repository carrying the same target must.

**Two defect classes observed during wave execution**, both required as
fixtures and both caught by sweep positive controls rather than by any rule:

1. *Stale explicit `path:`.* A target whose `path:` still names the pre-rename
   directory. R2c compares basenames and passes a *consistent* pair, so it
   misses a path pointing at a directory that is simply gone.
2. *Third-party identifier rewritten by a mechanical rename.* `providers:`
   entries name Homebrew formulae and Debian packages owned by external
   authorities and are as out-of-bounds as dependency references. The live
   instance rewrote `.brew(["imagemagick"])` to the new target name, which
   would have broken provider resolution on every macOS machine.

### 5.3 Fixture set (rule-maturity gate §8.4)

| Kind | Fixtures |
|---|---|
| Positive (fires) | Clang target `CDarwinKernelShim` (concatenated — R1 compound word + R2a); `.systemLibrary(name: "imagemagick")` (R1 via the new factory + R2a); `_Shims` (R1 + R2a); authored modulemap declaring `CDarwinProbe` under target `Darwin Kernel Probe` (R2b mismatch, decoded-name form); modulemap declaring two top-level modules (R2b); clang target `Darwin Kernel Shims` with `path:` ending `Sources/DarwinKernelShims` (R2c); Swift target named `Parser Shims` (R2d). |
| Negative (silent) | The ruled shape end-to-end: target `Darwin Kernel Shims`, matching directory, authored map declaring `Darwin_Kernel_Shims`, consumer `import Darwin_Kernel_Shims` (P7's exact shape); the auto-modulemap variant (no authored map); `ISO 9899 Errno Shims` (spec-mirroring words); `x86 Shims` (lowercase spec token). |
| Edge | Conditional platform dependency on the shim; nested test-package manifest; `Package@swift-*` variant; modulemap with submodules under one top-level module (passes R2b). |
| Near-miss | Swift target `CPU` (not classified, no `Shims` terminal — silent everywhere); assembly-only clang target (`probe.S` — classifies C-interop, R2a demands the spaced `* Shims` name); C-language `executableTarget` (excluded from the importable class); Swift target `Shim Support` (`Shim` not terminal — silent under R2d). |
| Exemption | None. No exemption list exists; the §5.1 class boundary is the only scoping mechanism, and it is derived. |
| Self-firing | The rule packs' and validator's fixture trees must not fire on their host repositories' real manifests. |
| Positive control | A fixture mutating `Darwin Kernel Shims` to `DarwinKernelShims` proves R1/R2a fire before any sweep result is accepted. |

### 5.4 Graduation path

1. **Now (advisory).** R1's `.systemLibrary` amendment lands; the existing
   compound-word firings on the 20 targets are the work-list, correctly
   advisory during migration.
2. **Migration wave** per §4: 13 PRs, 20 targets, 127 import sites, ordinary
   flow, heaviest repo swift-linux-standard.
3. **R2a–R2d in the validator** ship with the fixture tree; unsuppressed
   baseline reaches zero as the wave lands.
4. **Error tier.** After the wave, baseline zero with no legacy exceptions; R1
   graduates with the parent naming rules, R2 on the validator's cadence.
   Pre-graduation gate: re-run P1/P7 on Linux CI to close the macOS-only
   evidence boundary.

## 6. Stop conditions and open questions

- Word choices inside the grammar (the `_Shims` replacement; the systemLibrary
  domain word) are the owning packages' during the wave.
- The plural terminal `Shims` is the ruled shape; existing singular `Shim`
  names all migrate to it.
- If a future package legitimately needs two top-level modules in one authored
  modulemap, R2b's one-module predicate is the stop condition: a new
  convention question, not a local exception.
- **Recorded consequence:** the underscored import mirror means C-interop
  import statements (`import Darwin_Kernel_Shims`) are spelled identically to
  spaced Swift-target imports — uniform, but no longer visually marked as C
  interop at the import site. The `Shims` terminal word carries that signal
  instead. Recorded so the trade is ratified, not accidental.
