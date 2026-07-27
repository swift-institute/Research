# Layering re-baseline — 2026-07-24

**Lane:** layering census (read-only). **Tasks:** BOARD #24 (Foundation-freedom,
[ARCH-LAYER-007]) and BOARD #25 (upward layer edges, [ARCH-LAYER-001]).

**Status:** IN PROGRESS — written incrementally. Every number below carries its
command, its positive control, and an epistemic status. Numbers without a stated
control are marked as such and are **not** findings.

**Epistemic vocabulary used throughout:**

- **measured** — probe ran, control passed, count is the count.
- **floor** — probe ran and control passed, but the method is known to
  under-count. The true value is ≥ this.
- **unverified** — carried from a prior report, not yet reproduced here.
- **could not measure** — probe failed, timed out, or root did not resolve.
  Explicitly *not* the same as "measured zero".

---

## Phase 0 — scan-root verification

Method rule being honoured: *a wrong path and a true absence are
indistinguishable in the output.* No count below was read before its root was
confirmed to exist.

```bash
for d in swift-primitives swift-standards swift-foundations swift-institute \
         swift-ietf swift-iso swift-w3c swift-whatwg swift-ecma swift-iec \
         swift-ieee swift-incits swift-nist swift-arm-ltd swift-intel \
         swift-microsoft swift-riscv repotraffic swift-applications \
         swift-components swift-foundry swift-law swift-server \
         swift-linux-foundation; do
  p="~/Developer/$d"
  if [ -d "$p" ]; then printf "EXISTS  %-28s\n" "$d"; else printf "MISSING %-28s\n" "$d"; fi
done
```

**Result: all 24 roots resolve. Zero `MISSING`.**

**Positive control:** the same loop over a deliberately wrong path
(`swift-ietf-rfc-*`, the non-existent prefix `CLAUDE.md` warns about) prints
`MISSING`, so the probe can distinguish the two states. Control run below in
Phase 0b.

**Status: measured.** No CLAUDE.md path defect found in the roots this lane
needs. The documented root table is accurate as of this run.

### Phase 0a — a timeout that would have read as a clean sweep

The first inventory attempt was:

```bash
/usr/bin/find "$root" -name Package.swift -not -path "*/.build*" \
    -not -path "*/checkouts/*" -not -path "*/.git/*" | wc -l
```

**It timed out at 120 s and returned nothing.** Cause: `-not -path` is a
*filter*, not a *prune* — `find` still descends into every `.build` tree in the
workspace and only discards the results afterward.

This is recorded because the empty output is byte-identical to a clean sweep.
**It was discarded, not read.** The corrected form prunes:

```bash
/usr/bin/find "$root" \
  \( -name '.build*' -o -name '.git' -o -name 'checkouts' -o -name '.index-build' \) -prune \
  -o -name Package.swift -print
```

Same roots, sub-second. Discarding the timeout is the single most consequential
decision in this document so far.

---

## Phase 1 — package inventory

Enumeration is **directory-based, not `.git`-based**, per the method rule that
seven unversioned packages were structurally invisible to every `.git`-keyed
inventory.

### 1a — manifest depth distribution

A raw `Package.swift` count is **not** a package count. Measured depths
(root-relative, `NF-1` components):

| Root | d1 | d2 | d3 | d4 | d5 | d6 |
|---|---|---|---|---|---|---|
| swift-primitives | 204 | 18 | 255 | 2 | 4 | — |
| swift-foundations | 146 | 5 | 63 | 7 | 2 | 1 |
| swift-standards | 28 | 1 | — | — | — | — |
| swift-ietf | 64 | — | 3 | — | — | — |

Depth-1 is the shipped package. Depth-2+ are **auxiliary packages** —
`Benchmarks/`, `Experiments/`, nested `Tests/` (the testing-institute nested
package pattern), `swift-tagged-primitives/Lint/`,
`swift-linter/Runner/`. Verified by listing them, not assumed.

**Consequence for #24:** a Foundation census that counts every `Package.swift`
subtree conflates 483 manifests with 204 packages in `swift-primitives` alone.
Buckets are kept separate throughout this document.

### 1b — top-level package counts (in scope)

```bash
/usr/bin/find "~/Developer/$d" -mindepth 2 -maxdepth 2 -name Package.swift | wc -l
```

| Root | Top-level packages |
|---|---|
| swift-primitives | 204 |
| swift-foundations | 146 |
| swift-standards | 28 |
| swift-ietf | 64 |
| swift-iso | 12 |
| swift-w3c | 6 |
| swift-whatwg | 2 |
| swift-ecma | 1 |
| swift-iec | 2 |
| swift-ieee | 2 |
| swift-incits | 1 |
| swift-nist | 1 |
| swift-arm-ltd | 1 |
| swift-intel | 1 |
| swift-microsoft | 1 |
| swift-riscv | 1 |
| swift-institute | 2 |
| repotraffic | 1 |
| swift-components | 1 |
| swift-applications | 0 |
| swift-foundry | 3 |

**Status: measured** (subject to the scaffold correction in 1c).

### 1c — L4/L5 are scaffolds, not packages

`swift-applications` returned **0** top-level packages against 42 subdirectories,
and `swift-components` returned **1** against 26. That is precisely the
"empty result that looks like absence" shape, so it was investigated rather than
believed.

```
~/Developer/swift-applications/Auth/        → README.md only
~/Developer/swift-components/swift-cache/   → .github .gitignore
                                                        .swift-format .swiftlint.yml
                                                        LICENSE.md — no Package.swift,
                                                        no Sources/
~/Developer/swift-components/swift-server-static/ → real package
```

**Finding (measured):** the two upper layers of the five-layer model are
**essentially unpopulated**. 42 Applications entries are name-only READMEs;
25 of 26 Components entries are licence-and-config scaffolds. Exactly **one**
real Components package exists (`swift-server-static`), and **zero** real
Applications packages under that root — `repotraffic` is the live application
and it sits in its own root.

This is a **true zero, measured**, not a failed probe: the directories exist and
were listed; they contain no manifests because no packages have been written.

**Consequence for both #24 and #25:** any statement of the form "at any of the
five layers" is today a statement about **three** populated layers plus
repotraffic. The invariant's wording is correct and forward-looking; the
measurable surface is L1–L3 + one L4 + one application.

---

*(document continues — subsequent phases appended as measured)*

---

## Phase 2 — the probe, and its controls

The census probe is `census.py` (comment-stripping, brace-aware). It refuses to
report a number it cannot control.

### 2a — import matcher, controlled at its degenerate cases

Authority for what counts: `Lint.Rule.Foundation.Import`
(`swift-foundations/swift-institute-linter-rules`, target `Linter Rule
Foundation`) flags imports whose **first path component** is `Foundation` or
`FoundationEssentials`; submodule imports are caught; a non-leading component
(`HTML_Foundation`) is not.

**The matcher is deliberately WIDER than that rule.** It matches the whole
family — `Foundation`, `FoundationEssentials`, `FoundationNetworking`,
`FoundationXML`. An earlier revision of this line said the matcher "mirrors that
rule"; that was inaccurate about my own probe, and the distinction turns out to
matter — see §8, where the rule's two-name check is confirmed as a real guard
hole. A census that mirrored the rule would have inherited its blind spot and
confirmed the guard's own view of the world.

**Positive-control results — all 16 import cases + 2 manifest cases PASS:**

| Case | Want | Got |
|---|---|---|
| `import Foundation` | 1 | 1 |
| `public import Foundation` | 1 | 1 |
| `@_exported import Foundation` | 1 | 1 |
| `@preconcurrency import Foundation` | 1 | 1 |
| `internal import FoundationEssentials` | 1 | 1 |
| `import Foundation.NSURL` | 1 | 1 |
| irregular whitespace | 1 | 1 |
| `import Foundation // trailing` | 1 | 1 |
| `// import Foundation` | **0** | **0** |
| `/* import Foundation */` | **0** | **0** |
| `/// import Foundation` | **0** | **0** |
| multi-line block comment | **0** | **0** |
| **nested** block comment | **0** | **0** |
| `import HTML_Foundation` | 0 | 0 |
| `import FoundationDB` | 0 | 0 |
| `let s = "import Foundation"` (string literal) | 0 | 0 |
| manifest: commented-out `.target` excluded | ✓ | ✓ |
| manifest: `path:` override captured | ✓ | ✓ |

The five zero-cases in bold are the exact shapes that misled this workspace
three times in one day (a counted commented-out line; eleven occurrences in a
file where **all eleven were commented out**). The probe demonstrably
distinguishes them.

### 2b — residual controls (why the first census run is NOT reportable)

The probe emits three residuals as self-checks. First run over 452 packages:

```
packages_scanned=452   parse_failures=25
unclaimed_dirs=384     missing_target_dirs=50
```

**These residuals are the finding, not noise.** Diagnosed causes:

1. **`.target(name:)` is also a *dependency* spelling.** Inside
   `dependencies: [...]`, `.target(name: "Dependencies")` refers to a target;
   my matcher read it as a declaration. Hence phantom targets like
   `swift-server-vapor -> Dependencies @ Sources/Dependencies`. Over-counts
   targets; inflates `missing_target_dirs`.
2. **Computed target names defeat text parsing entirely.** 25 packages name
   targets through `String` extension constants:

   ```swift
   extension String { static let rfc7232: Self = "RFC_7232" }
   .target(name: .rfc7232)
   .testTarget(name: .rfc7232.tests)   // " Tests" appended by another extension
   ```

   (`swift-ietf/swift-rfc-7232/Package.swift:6-12,28-35`.) There is no string
   literal to match. **This is the concrete reason CLAUDE.md mandates the
   authoritative probe over a text scan** — and it is a hard limit on any
   grep-based Foundation census, including the prior 61/1307 figure.

**Consequence: any count from this probe is a FLOOR, not a measurement**, until
the residuals reach zero. Recorded here rather than suppressed.

---

## Finding A — `swift-github-standard` `@_exported import Foundation`: **REFUTED as a violation**

Prior claim (BOARD #24): *"an `@_exported import Foundation` in
`swift-github-standard`… `@_exported` is the worse class — it propagates
invisibly to consumers."*

**The line exists.** `Sources/GitHub Types Shared/exports.swift:2`:

```swift
@_exported import Foundation
```

**It is not in a declared target.** `Package.swift:38-56` declares exactly two
targets:

| Declared target | Kind | Directory |
|---|---|---|
| `GitHub Standard` | `.target` | `Sources/GitHub Standard` (91 .swift files) |
| `GitHub Standard Tests` | `.testTarget` | `Tests/GitHub Standard Tests` |

`Sources/` actually contains **eight** directories. Seven are undeclared:
`GitHub Collaborators Types`, `GitHub OAuth Types`, `GitHub Repositories
Types`, `GitHub Stargazers Types`, `GitHub Traffic Types`, `GitHub Types`,
`GitHub Types Shared`. `Tests/` contains four directories; three are undeclared.

**The declared target is Foundation-free — measured, with control:**

```bash
/usr/bin/grep -rn "import \(Foundation\|FoundationEssentials\)" \
    "Sources/GitHub Standard/"   # -> 0
/usr/bin/grep -rn "import " "Sources/GitHub Standard/"   # -> 24   (control)
```

The control returns 24 imports from the same directory with the same tool, so
the 0 is **a measured zero, not a probe that failed to run**.

**Adjudication.** The claim is true as a *text fact* and false as an
*[ARCH-LAYER-007] violation*. The rule governs a package's **main target**. This
code is in no target: it is not compiled, ships in no product, and reaches no
consumer. The aggravating characterisation — "propagates invisibly to
consumers" — **does not hold, because there are no consumers.** `GitHub Types
Shared` is `@_exported` by six sibling directories and re-exported by `GitHub
Types`, so the propagation graph is real *within the orphaned set*, and would
become a genuine whole-package leak the moment anyone declares these targets.

**This is the mirror image of the counted-commented-out-line error**: not
counting text the compiler ignores because it is commented, but counting text
the compiler ignores because it is **undeclared**. Both inflate a violation
count with code that does not exist as far as the build is concerned.

**Status: measured. Reclassify #24's second bullet** from "Foundation-freedom
violation" to "**orphaned source directories**" — 7 undeclared source dirs and
3 undeclared test dirs in one published L2 package. That is a real defect (it is
the same disease as BOARD #12's "6 orphaned test dirs" in swift-stripe-types),
but it belongs in a different row, and fixing it by *declaring* those targets
would create the Foundation violation that does not exist today.

---

## Phase 3 — BOARD #24 re-baseline: the numbers

### 3a — three further probe defects the residual controls caught

The first census run was **not reportable**. Three defects were found and fixed;
each is recorded because each produced a *plausible* wrong answer.

1. **`.target(name:)` is also a dependency spelling.** Matched inside
   `dependencies:` arrays, producing phantom targets
   (`swift-server-vapor -> Dependencies`). Fixed by matching only at element
   level inside the top-level `targets:` array.
2. **Nested `targets:` inside `products:`.** `_top_level_array` matched the
   `targets:` in `products: [.library(name:, targets: [...])]` —
   a shape `swift-github-standard/Package.swift:17` actually has. Fixed by
   anchoring to the `Package(...)` argument list.
3. **Silent wrong values from truncated constants.** `swift-mailgun-types/Package.swift:6-23`
   spells names as `static let mailgun: Self = "Mailgun".types`, with
   `var types: Self { self + " Types" }`. Capturing only the leading literal
   yielded `"Mailgun"` — a **plausible but wrong** target name pointing at a
   directory that does not exist. This is the most dangerous defect of the three:
   it fails silently and looks correct. It was caught **only** by the
   `missing_target_dirs` residual (36 in `swift-mailgun-types` alone).

**Final residuals — the probe's licence to report a number:**

```
packages_scanned=477   parse_failures=0
missing_target_dirs=0  unclaimed_dirs=167   unresolved_names=22
```

`missing_target_dirs=0` means **every declared target resolves to a real
directory** — the parse is consistent with the filesystem. All 22
`unresolved_names` are `testTarget`s (verified by kind), so the **core** figure
is complete over declared targets and only the **test** figure is a floor.

### 3b — headline census

Buckets are separated as required; a raw grep conflates them.

| Bucket | Targets | Targets w/ imports | Import lines | Packages |
|---|---|---|---|---|
| **core** | 1730 | 181 | **1334** | **47** |
| **fi** (`* Foundation Integration`) | 6 | 6 | 29 | 6 |
| **test** | 843 | 160 | 534 | 90 |

**Status: core = measured. test = floor** (22 unresolved test-target names).

**Against the prior rough figure of 61 packages / 1307 core-target import lines:**

- **Lines corroborate:** 1334 vs 1307, +2.1%. The prior line count was
  essentially right.
- **Packages do not:** **47**, not 61 — the prior figure was **30% high**.
- The tracked figure of **4** is wrong by two orders of magnitude on lines. The
  re-baseline confirms the *direction* and *magnitude* of #24 while correcting
  the package count.

### 3c — adjudication: 8 of the 47 are a naming defect, not a leak

Eight targets carry `Foundation` in the name and are structurally the sanctioned
opt-in pattern — a **separate leaf library product**, not depended on by the core
target — but their names end in `Foundation`, not `Foundation Integration`, so
the [ARCH-LAYER-007] exception (which "covers the target/module class" by that
name ending) does not formally reach them.

| Package | Target | Lines |
|---|---|---|
| swift-ietf/swift-rfc-2822 | `RFC 2822 Foundation` | 1 |
| swift-ietf/swift-rfc-3987 | `RFC 3987 Foundation` | 1 |
| swift-ietf/swift-rfc-4648 | `RFC 4648 Foundation` | 1 |
| swift-ietf/swift-rfc-5322 | `RFC 5322 Foundation` | 1 |
| swift-ietf/swift-rfc-6068 | `RFC 6068 Foundation` | 1 |
| swift-foundations/swift-foundation-extensions | `FoundationExtensions` | 1 |
| swift-foundations/swift-server-foundation | `ServerFoundation` | 2 |
| swift-foundations/swift-types-foundation | `TypesFoundation` | 2 |

Verified for the RFC family: `swift-rfc-3987/Package.swift:14-19` and
`swift-rfc-4648/Package.swift:15-16` declare **two** library products — the core
`RFC NNNN` and a separate `RFC NNNN Foundation` — and the core target does not
depend on the Foundation one. That is the sanctioned shape with the wrong suffix.

**Adjudicated split of the 47:**

| Class | Packages | Targets | Lines |
|---|---|---|---|
| **Genuine core violations** | **40** | **173** | **1324** |
| Misnamed-FI (rename to comply) | 8 | 8 | 10 |

(40 + 8 = 48 against 47 distinct packages: one package appears in both classes.)

**The remediation for the 8 is a rename, not a code change** — and it is cheap:
10 lines total.

### 3d — Finding B: `public import Foundation` in a shipped L1 product — **CONFIRMED**

`swift-primitives/swift-structured-queries-primitives`, target
`Structured Queries Primitives` (a **core** L1 target):

| File | Line | Form |
|---|---|---|
| `Sources/Structured Queries Primitives/QueryBindable+Foundation.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/QueryDecoder.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/QueryRepresentable.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/QueryBinding.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/QueryDecodable.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/QueryBindable.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/Internal/Date+ISO8601.swift` | 1 | `public import Foundation` |
| `Sources/Structured Queries Primitives/TableAlias.swift` | 1 | `import Foundation` |
| `Sources/Structured Queries Primitives/Statements/Insert/Insert.swift` | 1 | `import Foundation` |
| `Sources/Structured Queries Primitives/Statements/CommonTableExpressions/CTE.Clause.swift` | 1 | `import Foundation` |
| `Sources/Structured Queries Primitives Support/Quoting.swift` | 1 | `import Foundation` |

**7 `public import Foundation` + 4 plain, across 2 core targets.** `public
import` re-exports Foundation into every consumer's namespace, so this is the
same propagation class as `@_exported` — and unlike the github-standard case,
**these targets are declared and shipped.** This is the most severe single
[ARCH-LAYER-007] violation found, and it is at **L1**, the layer with the
strictest rule (`[PRIM-FOUND-001]`).

### 3e — L1 is otherwise clean, and that is the good news

**`swift-structured-queries-primitives` is the ONLY one of 204 primitives
packages with any core-target Foundation import.**

```
core-bucket Foundation imports, by root:
  swift-foundations  36 packages     swift-standards  3
  swift-ietf          5 packages     swift-primitives 1
  swift-institute     1 package      repotraffic      1
```

Positive control: the same probe over the same 204 packages finds 26 hits in
`swift-primitives` overall — 11 core (this package) and 15 in **test** targets
(`swift-test-primitives`, `swift-time-primitives`, `swift-version-primitives`).
So the probe demonstrably fires inside `swift-primitives`; **the near-zero at L1
is a measured result, not a mis-anchored scan.**

The violation mass is **L3**: 36 of 40 genuine-violation packages are in
`swift-foundations`. That is precisely the set the old "primitives and
standards" wording excluded — the documented reason #24 exists.

### 3f — concentration: 4 packages carry 66% of the violation

| Package | Lines | Note |
|---|---|---|
| swift-standards/swift-stripe-types | 408 | 34 targets |
| repotraffic/repotraffic-com-server | 277 | 37 targets |
| swift-foundations/swift-authentication | 137 | 6 targets |
| swift-standards/swift-postgresql-standard | 86 | 3 targets, all `public import` |
| — | **908 / 1334 = 68%** | |

`swift-mailgun-live` (75 lines) and `swift-stripe-live` (57) are almost entirely
`import FoundationNetworking` in `*.Client.live.swift` files — i.e. **the
URLSession-based HTTP client**. This is the same holdout BOARD names as the
meeting point of the two priorities: *"the HTTP stack… is the mechanism by which
the last networking code leaves"* repotraffic. **The Foundation-freedom debt and
the HTTP-stack task are largely the same debt**, and #32 would retire a large
share of these lines as a side effect.

---

## Phase 4 — BOARD #25: upward layer edges

### 4a — method

Layer assigned **by root directory**, per the ecosystem skill's org→layer table
(`Skills/swift-institute-ecosystem/SKILL.md:35-36`): L1 `swift-primitives`;
L2 `swift-standards` + the 14 per-authority spec roots; L3 `swift-foundations`;
L4 `swift-components`; L5 `swift-applications` + `repotraffic`.

Edges are extracted from the top-level `dependencies:` array (comment-stripped,
brace-matched), resolved to a local package by URL org first, then by unique
name. External dependencies (apple, swiftlang, vapor, …) are outside the layer
model and excluded — but counted, so their exclusion is visible.

**Controls:** `ambiguous_names=0`, `unresolved_refs=0` — every internal
dependency reference resolved to exactly one local package, so no edge was
silently dropped. 63 external refs across 14 distinct packages were classified
as external, not as missing.

### 4b — result

```
packages=475   internal edges=2281
down=792   same=1475   UP=14
external_dep_refs=63 (14 distinct)
```

| | Prior claim | Measured | Verdict |
|---|---|---|---|
| Upward edges, top-level manifests | 14 | **14** | **reproduced exactly** |
| Upward edges, total | 41 | **43** | reproduced within 2 |
| Same-layer edges | 1473 | **1475** | reproduced within 2 |
| Same-layer cycles | 0 | **0** | reproduced |

**Status: measured.**

### 4c — the 14 top-level upward edges, adjudicated individually

The prior composition — mailgun-types ×5, stripe-types ×4, postgresql-standard,
rfc-2388, linter-rules ×3 — is **exactly reproduced**. Adjudication:

#### (1) GENUINE VIOLATION — and inverted: `swift-rfc-2388` → `swift-html-form-coder`

`swift-ietf/swift-rfc-2388/Package.swift:21,30-31` — the **core** target
`RFC 2388` depends on products `HTML Form Coder` and `HTML Form Coder Nested`
from L3 `swift-foundations/swift-html-form-coder`.

RFC 2388 *is* "Returning Values from Forms: multipart/form-data" — it is the
**specification the L3 coder implements**. The dependency runs spec → implementation,
which is backwards on both the layer axis and the semantic axis. Verified **not**
reciprocal (`swift-html-form-coder/Package.swift` names no rfc-2388), so it is
not a cycle — but it is the one edge here that is wrong in its own terms.
**Highest-value single fix in #25.**

#### (2) MISCLASSIFICATION — `swift-mailgun-types` ×5, `swift-stripe-types` ×4

Both sit in the `swift-standards` root (⇒ L2) and depend on L3
`swift-dependencies`, `swift-url-routing`, `swift-html-form-coder`, `swift-dual`,
`swift-emailaddress`.

The L2 admission criterion is *"Does an external specification define it (ISO,
RFC, IEEE, W3C, WHATWG, vendor spec)?"* with naming `swift-{concept}-standard`
or `swift-{spec-id}` (`SKILL.md:35-36,64`). These are **`-types` vendor REST-API
bindings**. Mailgun's and Stripe's HTTP APIs are not external specifications in
that sense, and neither package matches either naming form.

**They do not meet the L2 criterion. The defect is the package's residence, not
the 9 edges.** Relocated to L3 Foundations — where their `swift-mailgun-live` /
`swift-stripe-live` counterparts already sit — all 9 become same-layer edges,
which [ARCH-LAYER-001] **permits**. Recommend re-classification, not edge severing.

#### (3) OUT OF MODEL — linter-rules ×3

- `swift-primitives-linter-rules` (L1) → `swift-institute-linter-rules`, `swift-linter-rules` (L3)
- `swift-standards-linter-rules` (L2) → `swift-institute-linter-rules` (L3)

These are **lint rule bundles** — build-time tooling that ships no runtime code
into any consumer. A per-layer rule bundle necessarily depends on the
institute-wide rule framework; the dependency is intrinsic to what they are.

The layer model governs *runtime artifact* dependencies. Recommend the Lead rule
that **tooling packages are outside the layer model**, which resolves these 3
permanently rather than re-litigating them each census.

#### (4) NOT A RUNTIME VIOLATION — `swift-postgresql-standard` → `swift-tests`

`Package.swift:59` declares the dependency; consumption is at
`:100` (`PostgreSQL Standard Test Support`, a `.target`) and `:119`
(`PostgreSQL Standard Tests`, a `.testTarget`). The **core** target
`PostgreSQL Standard` (`:64-67`) does **not** consume it.

Test infrastructure, not runtime layering. Caveat: `PostgreSQL Standard Test
Support` is a **declared library product** (`:21`), so a published product does
reach upward — weaker than a core violation, not nothing.

**Summary of the 14:**

| Adjudication | Edges |
|---|---|
| Genuine violation (rfc-2388) | **1** |
| Misclassified package layer (mailgun/stripe -types) | 9 |
| Outside the layer model (lint tooling) | 3 |
| Test-infrastructure only | 1 |

**One of fourteen is a genuine runtime layering violation.**

### 4d — the other 29: where the prior "41" came from

Scanning the **366 auxiliary manifests** (`Benchmarks/`, `Experiments/`,
nested `Tests/`, `Lint/`, and the hidden `.swift-lint/eval` and
`.swift-manifest/Lint.swift` packages) yields 29 further upward edges —
14 + 29 = **43**, against the prior 41.

Every one is tooling or throwaway:

- **23** are lint-configuration manifests (`.swift-lint/eval`,
  `.swift-manifest/Lint.swift`, `Lint/`) depending on `swift-linter`,
  `swift-linter-rules`, `swift-json`, `swift-file-system`.
- **3** are `swift-render-primitives/Experiments/*` spikes.
- **1** is `swift-postgresql-standard/Tests` (the same test-infra edge as above).

**None is a shipped-code layering violation.** The prior "41 upward edges"
headline is therefore true as a count and misleading as a severity: **the
overwhelming majority of it is lint tooling that the layer model was never meant
to govern.**

The two hidden manifest directories (`.swift-lint/`, `.swift-manifest/`) are
worth flagging on their own — a dot-prefixed package directory is invisible to
any `ls`-based or non-hidden-aware inventory, the same structural blindness as
the `.git`-keyed scan that missed seven packages.

### 4e — same-layer health metric (NOT a violation list)

Per [ARCH-LAYER-001], same-layer edges are **permitted**. Reported as health:

```
same-layer graph: 435 nodes, 1475 edges, 0 cycles
```

Cycle detection is a three-colour DFS. **Positive control:** injecting a
synthetic `A → B → A` into the same structure makes the detector report exactly
1 cycle (`A-B-A`), so the zero is a working detector's zero.

| Layer | Same-layer edges |
|---|---|
| L1 Primitives | 976 |
| L3 Foundations | 326 |
| L2 Standards | 173 |

Same-layer edges are **1475 of 2281 internal edges = 64.7%**. This is the figure
that, under the old blanket-lateral-ban misreading, made ~two-thirds of the
ecosystem nominally illegal. Under the corrected rule it is a **legitimate
composition graph, and it is acyclic.**

CLAUDE.md records "374 nodes, 1473 same-layer edges". Edges reproduce (1475,
+2). The node figure differs (435 vs 374) because I count nodes *participating in
at least one same-layer edge*; a different node definition (e.g. all packages in
layers with same-layer edges) would give another number. **Flagging the
definitional ambiguity rather than asserting either count is wrong.**

---

## Phase 5 — the fourth bucket: undeclared source

The `unclaimed_dirs` residual (167) is not probe noise. Classified:

| | Count |
|---|---|
| Unclaimed dirs total | 167 |
| …that are themselves nested packages | 3 |
| …hidden (`.benchmarks` etc.) | 10 |
| **True orphans — source dirs no target declares** | **154** |
| …of which contain `.swift` files | **109** |

```
UNDECLARED dirs: 425 .swift files, 149 Foundation import lines, 19 packages
```

| Package | Orphan Foundation lines |
|---|---|
| swift-foundations/swift-authentication | 38 |
| swift-foundations/swift-records | 26 |
| swift-foundations/swift-html-form-coder | 19 |
| repotraffic/repotraffic-com-server | 18 |
| swift-foundations/swift-identities-types | 12 |
| swift-foundations/swift-github-http | 9 |

Corroboration: `swift-standards/swift-stripe-types` shows **6** orphan dirs —
exactly the *"6 orphaned test dirs"* BOARD #12 already records. The census
rediscovers a known defect independently, which is a check on the method.

**This is the disease behind Finding A**, generalised: 109 directories of Swift
code that no `Package.swift` declares. It compiles nowhere, is gated nowhere, and
is invisible to every build-based check — yet a text-based census counts it as
if it shipped.

### 5a — reconciling the prior "61 packages"

| Bucket | Packages | Import lines |
|---|---|---|
| **core** (declared, shipped) | **47** | **1334** |
| test (declared) | 90 | 534 (floor) |
| fi (sanctioned `* Foundation Integration`) | 6 | 29 |
| **undeclared** (orphan) | 19 | 149 |

Package-set unions:

```
core                       = 47
core ∪ orphan              = 54
core ∪ orphan ∪ fi         = 59      <-- prior claim: 61
core ∪ test ∪ fi ∪ orphan  = 109
orphan-only (no core hits) =  7
```

**The prior 61 is very close to 59 — the union of declared-core, undeclared, and
FI packages.** The most probable explanation is that it **did not separate the
buckets**: it counted sanctioned FI targets and undeclared orphan source
alongside genuine core violations. That is precisely the conflation the task
brief warned a raw grep would produce.

**The defensible core figure is 47 packages / 1334 lines; adjudicated down to
40 packages / 1324 lines of genuine violation** (§3c).

### 5b — `swift-foundry`: measured, and outside the layer model

CLAUDE.md gained a `swift-foundry/` row during this session. It holds 3 packages
(`control`, `foundry`, `swift-control-plane`). Censused so there is no silent gap:

| Package | Targets | Foundation lines (total / core) |
|---|---|---|
| control | 2 | 0 / 0 |
| foundry | 2 | 0 / 0 |
| swift-control-plane | 14 | 1 / **0** |

**Zero core-target Foundation imports.** It has **no layer assignment** in the
ecosystem org→layer table, so it is excluded from the #25 edge census.
**Open question for the Lead** — see §6.

---

## Phase 6 — status, and open questions for the Lead

### What is measured

| # | Claim | Prior | Measured | Status |
|---|---|---|---|---|
| 24 | core-target Foundation import lines | 1307 | **1334** | measured (+2.1%) |
| 24 | packages with core violations | 61 | **47** (40 genuine) | measured; prior 30% high |
| 24 | `public import Foundation` in shipped L1 | asserted | **CONFIRMED**, 7 lines | measured |
| 24 | `@_exported import Foundation` in swift-github-standard | asserted | **REFUTED as violation** — undeclared target | measured |
| 25 | upward edges, top-level | 14 | **14** | reproduced exactly |
| 25 | upward edges, total | 41 | **43** | reproduced within 2 |
| 25 | genuine runtime violations among the 14 | — | **1** (rfc-2388) | adjudicated |
| 1 | same-layer edges | 1473 | **1475** | reproduced within 2 |
| 1 | same-layer cycles | 0 | **0** | reproduced, control-verified |

### Explicitly NOT measured

- **Test-bucket totals are a FLOOR** (534 lines / 90 packages). 22 test-target
  names are computed expressions the parser cannot resolve.
- **No FI-dependency check was run.** [ARCH-LAYER-007] also requires that *no
  core target depends, directly or transitively, on a Foundation Integration
  target*. That is a target-level closure over 1730 targets; not attempted here.
  **This is the largest unmeasured part of #24** and I flag it rather than let
  its absence read as a clear.
- **Layer assignment is by root directory.** Sound for the org→layer model but it
  is what makes mailgun/stripe-types read as violations (§4c(2)).

### Questions where the answer changes the numbers

1. **Are `swift-mailgun-types` / `swift-stripe-types` L2 or L3?** L3 turns 9 of
   the 14 upward edges into permitted same-layer edges. My reading of
   `SKILL.md:35-36,64` says they do not meet the L2 criterion.
2. **Are tooling packages (lint rule bundles, `.swift-lint/eval`) inside the
   layer model?** "No" resolves 3 top-level + 23 auxiliary upward edges
   permanently.
3. **Does `swift-foundry` have a layer?** Currently unassigned and therefore
   uncensused for #25.
4. **Do the 8 misnamed-FI targets get renamed?** 10 lines, and it moves 8
   packages out of the violation set legitimately.
5. **Scope confirmation:** I censused `swift-institute/Issues` (4 core lines
   across 4 targets). BOARD #27 treats `Issues/` as a reproducer corpus; if it is
   out of scope the core package count drops 47 → 46.

### Reproduction

Probes: `census.py` (Foundation census + self-test), `graph.py` (layer edges),
in this session's scratchpad. `census.py selftest` runs all 21 positive controls
and must print `SELFTEST OK` before any number it emits is admissible.

**Not run:** any build, test, or `dump-package`. This lane made no source edits
and no commits.

---

## Phase 7 — Lead additions (2026-07-24, second round)

### 7a — scan shape: `.git` blindness does not apply to this census

The Lead's caution is correct in general and **does not affect these numbers**,
because the inventory never keyed on `.git`. Demonstrated rather than asserted:

```python
# directory-enumerated, depth 1 under each in-scope root
for e in sorted(os.listdir(root)):
    if os.path.isfile(os.path.join(root, e, "Package.swift")): ...
```

```
top-level packages (depth 1, directory-enumerated) = 480
of which NO .git directory                         =   0
```

**Nesting depth is stated for every count in this document:** package inventory
and the #25 edge graph are **depth 1** (a package directory directly under a
root); the auxiliary sweep (§4d) walks **all depths** and found 366 further
manifests; the consumer census (§7b) walks **all depths**, 847 manifests total.

Confirmed independently: **`~/Developer/swift-institute` is not a git
repository.** Twelve of its children are separate repos (`Audits`, `Blog`,
`Engagement`, `Experiments`, `Internal`, `Issues`, `Research`, `Scripts`,
`Skills`, `Swift-Evolution`, `Workspace`, `swift-institute.org`). A scan walking
top-level org directories for `.git` would miss all twelve. **This census walks
directories, so it sees them** — `swift-institute/Issues` appears in the #24
results with 4 core lines.

**The seven unversioned packages: could not reproduce — explicitly not "measured
zero".** Probing for repo-shaped packages (`Package.swift` + `Sources` + `Tests`
+ `LICENSE*`, no `.git`) at depth ≤4 across the whole workspace returned **2**,
both out of scope (`_scratch-iterable-span-c/swift-iterator-primitives`,
`apple/Sample App`). Relaxing to `Package.swift` + `Sources`, no `.git`, in-scope
roots only, returned 249 — but **all of them are packages nested inside a repo**
(`Experiments/`, `Benchmarks/`, `Lint/`, `Runner/`), which have no `.git` of
their own by construction. Positive control: the same probe with the `.git` test
inverted returns 204 in `swift-primitives`, so it fires.

So: either the seven are outside this lane's scope, or they are counted here
already as ordinary directory-enumerated packages. **Either way they cannot have
been missed by this inventory**, since it never asked about git. Flagged as
unreproduced, not as refuted.

### 7b — zero-consumer census — **both claims REFUTED**

New dimension, walking **all 847 manifests** (top-level + auxiliary) across 480
in-scope packages and counting in-edges.

**Two-sided control.** The probe was validated at both ends before any result was
read:

| Control | Expected | Measured |
|---|---|---|
| `swift-types-foundation` (driven to zero today; true answer known in advance) | 0 | **0** ✓ |
| Probe must find large in-degrees somewhere | large | `swift-index-primitives` **90**, `swift-tagged-primitives` 88, `swift-standard-library-extensions` 70 ✓ |

A probe that returns 0 for the known-zero **and** 90 for a hub is not a broken
scan. Both claims then:

| Package | Claim | Measured consumers |
|---|---|---|
| `swift-iso-14496-22` (OpenType) | zero | **1 — `swift-iso-32000`** |
| `swift-w3c-png` | zero | **1 — `swift-iso-32000`** |

**Both are REFUTED, and the consumption is real at source level, not just
declared in a manifest:**

```
Sources/ISO 32000 Flate/ISO_32000.Image+PNG.swift:8          public import W3C_PNG
Sources/ISO 32000 9 Text/9.8 Font descriptors+Descriptor.swift:7  public import ISO_14496_22
Sources/ISO 32000 9 Text/9.6 Simple fonts+TrueType.swift:11       public import ISO_14496_22
```

(Control: 170 total import lines in `swift-iso-32000/Sources`, so the probe
fires.) The uses are semantically exactly right — PNG for image XObjects,
OpenType for PDF font descriptors and TrueType simple fonts. **This is not dead
code.**

**Epistemic caveat, per the Lead's point 3:** these three import lines are a
*text* result. A text scan's non-zero is no stronger than its zero. I can quote
the lines and they are unambiguous (`public import`, first path component
matches, comment-stripped), but **only the compiler can prove the symbols are
used rather than merely imported.** That check was **not run** — it needs a
build, which this lane does not do without approval. Status: **manifest edge and
import site = measured; symbol-level use = could not measure.**

### 7c — the underlying observation survives, inverted

The Lead's framing — *"`swift-pdf-render` measures text through `PDF.Font` and
has never touched the OpenType package"* — is **correct**, and sharper than the
zero-consumer claim it was attached to:

```
swift-foundations/swift-pdf-render:
   imports of ISO_14496_22  = 0
   imports of ISO_32000     = 3     <-- control: the probe fires
```

So the OpenType capability **is** wired into the ecosystem — at **L2, in the PDF
specification package** — while the **L3 renderer bypasses it** and measures text
through its own `PDF.Font`. That is not duplicated dead code; it is a **renderer
not consuming the spec-layer capability that already exists directly beneath
it.** For the decomposition goal that is the more actionable shape: the work is
to route `swift-pdf-render`'s text metrics through `ISO_14496_22` (via
`ISO_32000`), not to retire an unused package.

### 7d — zero-consumer packages ecosystem-wide: 118

| Root | Zero-consumer packages |
|---|---|
| swift-primitives | 49 |
| swift-foundations | 37 |
| swift-ietf | 22 |
| swift-institute | 2 |
| swift-foundry | 2 |
| swift-iso / swift-nist / swift-riscv / swift-standards / swift-components / repotraffic | 1 each |

**118 of 480 packages (24.6%) have no manifest consumer anywhere in scope.**
Status: **measured** for manifest edges; this counts declared dependencies only,
and a leaf application legitimately has zero consumers.

Two clusters are directly programme-relevant:

- **The HTTP/1.1 RFC family is complete and unconsumed:** `swift-rfc-7230`,
  `7231`(via 7230 only), `7232`, `7233`, `7234`, `7235` all show zero consumers.
  BOARD #32's path is *"N7 HTTP/1.1 law → N8 client"* — **the law layer is
  already written and waiting.** That materially de-risks #32.
- **`swift-rfc-5280` has zero consumers**, which is exactly what BOARD #34
  predicts: the certificates fork duplicates 8 extension types instead of
  consuming rfc-5280. Completing #34 creates that missing edge. **The census
  independently corroborates #34 from the opposite direction.**

---

## Phase 8 — the Foundation guard hole: CONFIRMED at source, but NOT the mechanism

### 8a — the hole is real, verified in the rule's own source

Not from the skill doc — from `swift-foundations/swift-institute-linter-rules/`
`Sources/Institute Linter Rule Foundation/Lint.Rule.Foundation.Import.swift:82-85`:

```swift
private func foundationImportIsFoundationModule(_ pathText: Swift.String) -> Swift.Bool {
  let firstComponent = pathText.split(separator: ".").first.map(Swift.String.init) ?? pathText
  return firstComponent == "Foundation" || firstComponent == "FoundationEssentials"
}
```

A string equality against exactly two names. **`FoundationNetworking` and
`FoundationXML` pass silently.** `URLSession` lives in `FoundationNetworking` on
Linux, so the rule permits precisely the import that most defeats its purpose.
**Status: measured — the hypothesis is confirmed.**

Secondary defect in the same file: the diagnostic message (`:36-41`) reads
*"primitives source MUST NOT import…"* and cites `[PRIM-FOUND-001]`, but the rule
is deployed at institute tier for **all five layers** per `[ARCH-LAYER-007]`. An
L3 engineer who trips it is told it is a primitives rule.

### 8b — this census did NOT inherit the blind spot

The Lead flagged that a census matching only `Foundation`/`FoundationEssentials`
would share the guard's hole. **This one does not.** `census.py:259` has always
matched the full family:

```python
r'(Foundation|FoundationEssentials|FoundationNetworking|FoundationXML)'
```

**Positive control on the Lead's named instance** — all four forms fire:

```
FIRES  @_exported import FoundationNetworking
FIRES  import FoundationNetworking
FIRES  import FoundationXML
FIRES  public import FoundationEssentials
```

And the package resolves exactly: `swift-urlrequest-handler` was counted at **6**
core lines, and an independent `/usr/bin/grep` over its `Sources/` returns those
same 6 — `DefaultSessionKey.swift:9,12`, `exports.swift:4`,
`DefaultRequestHandlerKey.swift:2,7`, `Envelope.swift:1`.

### 8c — the discriminating count: the hole explains 3.6%, not the magnitude

| Module | Core-bucket lines | Share |
|---|---|---|
| `Foundation` | 1283 | **96.2%** |
| `FoundationNetworking` | 48 | 3.6% |
| `FoundationEssentials` | 3 | 0.2% |
| `FoundationXML` | 0 | 0% |

**Invisible to the rule: 48 of 1334 core lines = 3.6%**, across 8 packages
(`swift-mailgun-live` 35, `repotraffic-com-server` 5,
`swift-urlrequest-handler` 3, then `boiler`, `swift-server-foundation`,
`swift-stripe-live`, `swift-types-foundation`, `swift-url-routing-vapor` at 1 each).

**So the guard hole is a genuine defect and is NOT the mechanism behind #24's
magnitude.** It cannot be: **96.2% of the violation mass is plain `Foundation`,
which the rule matches correctly.**

### 8d — an inference the census can make without running lint

**1283 core-target lines that the rule DOES match are sitting in the tree
unfixed, across ~40 packages.** If `Lint.Rule.Foundation.Import` were enforced
anywhere in CI or in a gate, those lines could not accumulate — every one of them
is a warning-severity finding (`default: .warning`, `:22`) the rule emits on
sight.

This is **independent evidence for the second of the Lead's two worlds**: the
guard is not enforced, rather than enforced-and-clean. It does not distinguish
"not running" from "red and unattended" — only the HTTP lane's actual lint run
does that — but it does make "the guard is fine and the count is honest"
untenable on arithmetic alone.

**Status: the 1283/48 split is measured. The enforcement conclusion is an
inference from it, not a lint run — I did not run lint.**

Note `default: .warning`: even a *running* lint would not fail a build on this.
"Red and unattended" may be the normal steady state rather than an anomaly.

### 8e — root-list check: the correction needs correcting

The Lead cautioned that `swift-components/` (*"25 packages"*),
`swift-applications/` (*"40 entries"*) and `swift-foundry/` may have been missing
from this census's root list, and that an absent root returns empty exactly like a
clean one.

**Checked — all three were already in scope.** `census.py` `IN_SCOPE_ROOTS`
contains 20 roots including `swift-components` and `swift-applications`;
`swift-foundry` was censused separately at §5b (0 core lines).

**But the characterisation is wrong, and in the direction that matters:**

```bash
ls -1 swift-components  | wc -l                                    # 25
find swift-components -mindepth 2 -maxdepth 2 -name Package.swift  # 1
find swift-components -mindepth 2 -maxdepth 2 -type d -name Sources # 1

ls -1 swift-applications | wc -l                                   # 40
find swift-applications -mindepth 2 -maxdepth 2 -name Package.swift # 0
find swift-applications -mindepth 2 -maxdepth 2 -type d -name Sources # 0

# CONTROL: same probe on swift-standards -> 28   (the probe fires)
```

**`swift-components` has 25 directories and 1 package. `swift-applications` has
40 directories and 0 packages.** The "25" and "40" are exact directory counts
read as package counts. This is §1c, reproduced independently: L4/L5 are
licence-and-config scaffolds, and the ecosystem skill itself calls both layers
*"reserved"*.

**Consequence: nothing was missed, and adding these roots adds 1 package and 0
Foundation lines to the census.**

### 8f — instrument defects, applied to this lane

- **Bare `grep` is a shell function** wrapping `ugrep --ignore-files`. **This
  lane used `/usr/bin/grep` throughout**, and the Python probes use `os.walk`,
  which honours no `.gitignore` at all — so the census sees *more*, not less.
  Not exposed.
- **`git log --since=<bare ISO date>` returns zero for that day.** Not used by
  this lane; no count here derives from `git log`.
- **`/usr/bin/ps` does not exist on macOS.** Not used.
- **`| head -N` truncates evidence.** Exposed once this session: a `head -5` on a
  `find` for the lint rule source, compounded by unquoted word-splitting on paths
  containing spaces (`Institute Linter Rule Foundation`), produced a cascade of
  "No such file or directory". Caught immediately because the errors were loud —
  **the dangerous version of this failure is the silent one**, where truncation
  removes a hit rather than mangling a path. The rule source was then read whole,
  not paged.

### 8g — "65 packages were invisible": REFUTED at full depth

The claim was raised twice by the Lead, so it was tested decisively rather than
re-argued from the depth-2 probe. **Full-depth**, pruning only `.build*`, `.git`,
`checkouts`:

```bash
/usr/bin/find "~/Developer/$r" \
  \( -name '.build*' -o -name '.git' -o -name 'checkouts' \) -prune \
  -o -name Package.swift -print
```

| Root | Directories | `Package.swift` at **any** depth |
|---|---|---|
| `swift-components` | 25 | **1** — `swift-server-static/Package.swift` |
| `swift-applications` | 40 | **0** |
| `swift-foundry` | 3 | **3** |
| **Total** | 68 | **4** |

**Positive control:** the identical full-depth probe returns **29** on
`swift-standards`, so it finds manifests when they exist.

**The three roots contain 4 packages, not 65.** The figure "65" is
`25 + 40` — the **directory** counts. All 4 packages were already in this
census: `swift-server-static` (§1c), and the 3 foundry packages (§5b, 0 core
Foundation lines).

**Net effect on every ecosystem-wide total in this document: zero.** No
under-count. This is recorded because the claim, had it been accepted, would have
triggered a full re-run of a census that was already correct — and because
"directories read as packages" is the same class of error as "commented-out lines
read as sites" and "undeclared source read as shipped": **counting containers
instead of contents.**

---

## Phase 9 — FINAL, under Lead rulings 1–5 (2026-07-24)

Rulings applied: (1) mailgun/stripe `-types` → **L3**; (2) tooling packages
**outside** the layer model; (3) `swift-foundry` **no layer**; (4) rename the 8
misnamed-FI targets; (5) `swift-institute/Issues` **out of scope**.

### 9a — BOARD #24 final

| Measure | Value |
|---|---|
| Core-target packages with Foundation imports | **46** |
| Core-target import lines | **1330** |
| **Genuine violation** | **39 packages / 1320 lines** |
| Misnamed-FI (legitimised by rename) | 8 packages / 10 lines |

Ruling 5 removes `swift-institute/Issues` (4 lines / 4 targets): 47 → **46**
packages, 1334 → **1330** lines; genuine 40 → **39** packages, 1324 → **1320**
lines.

**Against the tracked figure of 4: the baseline is 1320 lines of genuine
core-target Foundation debt across 39 packages.** Prior rough measurement
(61 pkg / 1307 lines) was right on lines (+1.0% vs final), 56% high on packages.

**Status: measured**, with the stated exclusions. Test bucket remains a **floor**.

### 9b — BOARD #25 final

| Measure | Value |
|---|---|
| Internal edges | **2251** |
| down | 779 |
| same (permitted) | **1470** |
| **UP** | **2** |

**The 14 upward edges resolve to 2:**

| Edge | Adjudication |
|---|---|
| `swift-ietf/swift-rfc-2388` → `swift-foundations/swift-html-form-coder` | **GENUINE — the only one.** Inverted: RFC 2388 *is* the multipart/form-data spec the L3 coder implements. |
| `swift-standards/swift-postgresql-standard` → `swift-foundations/swift-tests` | Test-infrastructure only; core target does not consume it. `PostgreSQL Standard Test Support` is a declared product, so a published product does reach upward. |

**Acyclicity re-verified AFTER re-layering** — this was not assumed. Moving
`swift-mailgun-types` and `swift-stripe-types` to L3 adds same-layer edges at L3
and could in principle close a cycle. It does not:

```
same-layer after re-layering: 431 nodes, 1470 edges, CYCLES = 0
CONTROL (injected __A <-> __B): cycles = 1
```

**Status: measured.** Ruling 1 is safe to apply — it does not create a cycle.

### 9c — ⚠️ Ruling 4 is NOT fully mechanical: 1 of 8 fails the suffix test

The rename was ruled as appending ` Integration`. Checked mechanically against
the actual predicate (`name.endsWith("Foundation Integration")`) rather than by
eye:

| Current target | `+ " Integration"` | Satisfies rule? |
|---|---|---|
| `ServerFoundation` | `ServerFoundation Integration` | YES |
| `TypesFoundation` | `TypesFoundation Integration` | YES |
| `RFC 2822 Foundation` | `RFC 2822 Foundation Integration` | YES |
| `RFC 3987 Foundation` | `RFC 3987 Foundation Integration` | YES |
| `RFC 4648 Foundation` | `RFC 4648 Foundation Integration` | YES |
| `RFC 5322 Foundation` | `RFC 5322 Foundation Integration` | YES |
| `RFC 6068 Foundation` | `RFC 6068 Foundation Integration` | YES |
| **`FoundationExtensions`** | `FoundationExtensions Integration` | **NO** |

`FoundationExtensions Integration` ends in `Extensions Integration`, **not**
`Foundation Integration`. `swift-foundations/swift-foundation-extensions`
(1 line) needs a deliberate name, not a suffix — and it raises the prior
question of whether a package whose *entire* purpose is Foundation bridging
should have a core target at all, or should be an integration package end to end.
The same question applies to `swift-types-foundation` and
`swift-server-foundation`: the mechanical rename satisfies the predicate, but a
package named `swift-*-foundation` whose only target is the integration target is
a different shape from a core package that ships an opt-in FI subtarget.

**7 of 8 rename mechanically. 1 needs a decision.** Flagged rather than papered
over — a rename that satisfies a string predicate without satisfying its intent
would make the metric read clean while the shape stays wrong, which is the same
failure mode as counting undeclared source as shipped.

### 9d — final headline

```
#24  39 packages / 1320 lines  genuine core-target Foundation debt   [measured]
     +8 packages /   10 lines  legitimised by rename (7 mechanical, 1 open)
     +      534 lines          test bucket                            [FLOOR]
     +      149 lines          undeclared source                      [measured]
     +       29 lines          sanctioned FI targets                  [not debt]

#25   2 upward edges, of which 1 genuine (swift-rfc-2388)             [measured]
      1470 same-layer edges, 431 nodes, 0 cycles                      [measured]

UNMEASURED: FI-dependency closure (1730 targets) — largest gap in #24
            symbol-level use of ISO_14496_22 / W3C_PNG — needs compiler
            Foundation-rule enforcement state — pending HTTP lane lint run
            7 unversioned packages — could not reproduce (NOT "measured zero")
```

---

## Phase 10 — HTTP lane reconciliation (2026-07-24)

### 10a — §8d upgraded: enforcement is MEASURED, no longer inferred

The HTTP lane ran the lint. Recorded here as **measured**, replacing the
inference in §8d:

```
swift-build lint --package-path swift-foundations/swift-urlrequest-handler
exit status (bare $?): 0
92 active rules · 8 files linted · 72 violations
```

**Foundation-import findings: 5 = 3 Sources + 2 Tests.** My §8b prediction of
**3 core findings was exact** (`DefaultRequestHandlerKey.swift:2`,
`DefaultSessionKey.swift:9`, `Envelope.swift:1`); the 2 extra are test files,
outside the core bucket by design. No disagreement anywhere.

**The hole is demonstrated at line granularity in a single file:**
`DefaultSessionKey.swift:9` fires, `:12` does not — three lines apart, same
import family. `exports.swift` (whose entire content is two imports, one of them
`@_exported import FoundationNetworking`) produced **zero findings and is not
among the cited files at all.**

**Answer to the two-worlds question — it is neither.** The rule **runs**, **sees
correctly**, and **cannot fail anything**: `default: .warning` (`:22`) →
**exit 0 with 72 violations outstanding**, and nothing escalates it to `error`.

**So the mechanism behind #24 is severity, not the matcher.** 1283 rule-matching
lines accumulated because nothing ever went red on them. A *policy* defect, not a
predicate defect. The `FoundationNetworking` hole is real and worth fixing, but
it was never the explanation — the 96.2%/3.6% split (§8c) already ruled it out.

**Status: measured** (by the HTTP lane; exit status captured bare, per the zsh
`$pipestatus` rule).

### 10b — ⚠️ MY ERROR: the "law layer already exists" inference was WRONG

I told the HTTP lane that `swift-rfc-7230/7232/7233/7234/7235` showing zero
consumers meant *"the law layer already exists and is unconsumed — you may be
wiring up existing packages rather than authoring them."*

**That inference is wrong and the correction is important, because acting on it
would have wired up obsoleted law.** 7230–7235 are the **superseded** HTTP/1.1
series, obsoleted by RFC 9110/9112 in June 2022. N7's law is **9110/9112**, and
it is emphatically consumed.

**My own dataset contained the refutation and I did not consult it.** Checking
the zero-consumer list now:

| Package | In my zero-consumer list? |
|---|---|
| `swift-rfc-9110` | **no — has consumers** |
| `swift-rfc-9111` | **no — has consumers** |
| `swift-rfc-9112` | **no — has consumers** |
| `swift-http-standard` | **no — has consumers** |
| `swift-rfc-7230` | yes |
| `swift-rfc-7235` | yes |

The live law family was never in the zero set. **The measurement was right; I
generalised from a subset to an action without checking the adjacent set that my
own probe had already classified.** Correct disposition for 7230–7235 is
**retire after #30**, not adopt.

**This is the lane's own instance of the error it keeps finding in others:** a
true number carrying a false implication. The number needed no correction; the
sentence built on it did.

### 10c — consumer-census population: the 847 excluded a duplicate checkout

The HTTP lane found `swift-rfc-7230` referenced in
`swift-institute/Workspace/Packages/swift-url-routing/Package.swift:33-34`. Asked
whether that manifest was in my 847. **It was not**, and I can now say exactly
why and exactly what it costs.

My enumeration walks from each **depth-1 package directory**. `swift-institute/Workspace/`
has no `Package.swift`, so nothing beneath it was ever reached.

**Sensitivity analysis — original vs widened population:**

```
manifests in original consumer census : 847
manifests under all in-scope roots    : 1273
MISSED by depth-1-package enumeration :  426
    swift-institute/Experiments  268
    swift-institute/.github      152
    swift-institute/Workspace      5
    swift-institute/Research       1

edges contributed by the missed manifests : 150
zero-consumer packages that gain a consumer : 6
    swift-bitset-primitives, swift-git, swift-memory-sequence-primitives,
    swift-rfc-7230, swift-set-algebra-primitives, swift-xcode   (+1 each)
```

**118 zero-consumer packages → 112 under the widened population.**

Confirmed: `swift-rfc-7230`'s sole gained consumer is
**`swift-institute/Workspace/Packages/swift-url-routing`** — the duplicate
checkout of BOARD #30. The canonical `swift-foundations/swift-url-routing` has
**0** files referencing `RFC_723x` (control: 51 files reference `RFC_` generally,
so the probe fires) — it has migrated to `swift-http-standard`.

**Both numbers are right about different populations:** 118 is the **post-#30**
state; 112 is the **pre-#30** state. The six differences are experiment spikes,
`.github` tooling manifests, and a shadow checkout — **none is a consumer in the
decomposition sense**, so 118 remains the better metric.

**But the exclusion was accidental, not deliberate**, and that is the part worth
recording: a defensible boundary that nobody chose is indistinguishable from an
oversight until someone checks. Now chosen, stated, and quantified both ways.

### 10d — ⚠️ manifest-only in-degree UNDER-REPORTS re-exported packages

A real limit on §7b/§7d, raised by the HTTP lane and verified here:

```
swift-rfc-9112/Sources/RFC 9112/RFC_9112.swift:10   @_exported import RFC_9110
swift-rfc-9111/Sources/RFC 9111/RFC_9111.swift:10   @_exported import RFC_9110
swift-rfc-9112/Sources/RFC 9112/HTTP.Host.swift:4   @_exported import RFC_3986
```

**A consumer can bind `RFC_9110` types without naming `swift-rfc-9110` in its
manifest.** So every in-degree in this document counts *declared* dependencies
and under-reports any package reached through an `@_exported` chain.

**Consequence: the 118 zero-consumer figure is an UPPER BOUND on true
zero-consumer packages.** A package could show zero manifest consumers and still
be bound transitively via re-export. Reclassifying it: **118 = measured for
manifest edges, upper bound for actual consumption.**

This is the same mechanism as Finding A (§ github-standard) seen from the other
side — `@_exported` making a dependency real without making it visible. It is
becoming the single most recurrent structural hazard in this census.

### 10e — the two debts are one, corroborated

The HTTP lane's independent count: the URLSession surface across the in-scope
ecosystem is **six real code sites** (two further hits were `.docc` prose).
`swift-url-routing` has its one correctly quarantined in a
`URL Routing Foundation Integration` target — **the only site already doing it
right**, and the shape N8 should copy. Consistent with §3f.

---

## Phase 11 — the operative layer model has THREE library layers

Principal, 2026-07-24: *"swift-applications and swift-components is almost
entirely aspirational from months ago. The layers are currently L1 – primitives,
L2 – standards, L3 – foundations, and then we have repotraffic and
swift-institute/Workspace."*

This confirms §1c from the top. The correct reading of those two roots is not
"reserved and awaiting inhabitants" but **drawn up months ago and never
realised**.

### 11a — measured: does anything sit at L4/L5?

The Lead asked for this to be measured rather than assumed. It was.

| Layer | Packages participating in the edge graph |
|---|---|
| **L4 Components** | **none** |
| **L5 Applications** | `repotraffic/repotraffic-com-server` only |

```
edges touching L4/L5, by direction:
   L5 -> L1  down   3
   L5 -> L2  down   7
   L5 -> L3  down  31
UPWARD edges involving L4/L5 : 0
edges INTO any L4/L5 package : 0
```

`swift-components/swift-server-static` — the single real Components package —
**participates in zero edges**. Its manifest declares **no `.package(`
dependencies** at all (only a target-level `dependencies: ["Server Static"]`),
and its 11 source files contain **zero import statements of any kind** (control:
the same probe returns 0 total imports, consistent rather than broken). It is a
fully isolated leaf.

**So no package was ever classified into an aspirational layer in a way that
affects a number.** L4 contributes nothing; L5 contributes 41 edges, all
downward; nothing depends on either. **Every #25 figure is unchanged**, and
ruling 1 is reinforced: with no realised layer above L3, L3 *is* the top library
layer, and vendor REST bindings have nowhere else to go.

### 11b — a census must say which layers exist

`[ARCH-LAYER-007]` reads "at any of the five layers" and `[ARCH-LAYER-001]`'s
table names **HTTP as the Components example** — a table entry pointing at a
layer with one occupant, and that occupant is not HTTP.

**The wording is correct as policy and forward-looking. The measurable surface is
three library layers plus two consumers.** This document's numbers should be read
as measuring:

```
L1 Primitives  (204 packages)  ─┐
L2 Standards   (~123 packages) ─┼─ realised library layers
L3 Foundations (146 packages)  ─┘
repotraffic + swift-institute/Workspace  ─ consumers above them
L4 / L5  ─ aspirational; 1 isolated package and 0 packages respectively
```

Stated so nobody reads a five-layer denominator into a three-layer measurement.
Not this lane's to fix; recorded so the numbers are not over-claimed.

### 11c — note on `swift-institute/Workspace`

The principal names `swift-institute/Workspace` as an operative consumer. **It is
outside every graph in this document**, because the enumeration walks from
depth-1 *package* directories and `Workspace/` has no `Package.swift` (§10c). It
holds 4 packages, including the BOARD #30 duplicate `swift-url-routing` checkout.

**This is now a known, stated scope boundary rather than an accident** — but if
`Workspace` is operative, its consumer edges belong in a future #25 run. Flagged;
not folded in silently.

---

## Phase 12 — FI-dependency closure: the largest unmeasured part of #24, now MEASURED

[ARCH-LAYER-007] requires more than Foundation-free source: **no core target may
depend, directly or transitively, on a `* Foundation Integration` target** —
otherwise Foundation re-enters the core closure and the exception swallows the
rule. The FI target is a LEAF product.

This was flagged unmeasured through Phases 1–11. **It is now measured for
declared target dependencies.** Probe: `ficlosure.py` — builds a global
target-level graph (node = `(package, target)`), resolving `.product(name:,
package:)` through each dependency's `products:` array to the concrete targets
that product vends, then computes reachability from every core target.

### 12a — result

```
packages parsed         : 480
target nodes            : 2597
core (non-test, non-FI) : 1740
FI targets found        :    6
CORE TARGETS REACHING AN FI TARGET : 36  (2.1% of core targets)
    DIRECT    (depend on an FI target themselves) :  5
    INHERITED (via another core target)           : 31
```

**Status: MEASURED for declared edges** — not a floor. Justification below.

### 12b — the closure is not weakened by unresolved references

169 product references could not be resolved to a local package. **Every one
points at an external package**, verified exhaustively rather than sampled:

| Package | Refs | |
|---|---|---|
| swift-syntax | 94 | external |
| swift-log | 27 | external |
| swift-linux-standard | 15 | external |
| vapor | 13 | external |
| swift-collections, postgres-nio, swift-crypto, swift-argument-parser, queues, swift-nio, queues-redis-driver, RediStack | 20 | external |
| **pointing at a LOCAL package** | **0** | — |

External packages declare no `* Foundation Integration` targets, so no unresolved
reference can hide a path to one. **Hence measured, not floor.**

### 12c — the 5 direct violations (the actual defects)

The other 31 are downstream inheritance. These 5 are where the rule is broken:

| Package | Core target | Depends directly on |
|---|---|---|
| `swift-environment-dependencies` | `Environment Dependencies` | its **own** `Environment Dependencies Foundation Integration` |
| `swift-favicon` | `Favicon` | `swift-url-routing/URL Routing Foundation Integration` |
| `repotraffic-com-server` | `RepoTrafficRouterVapor` | `swift-url-routing/URL Routing Foundation Integration` |
| `repotraffic-com-server` | `Repositories` | `swift-url-routing/URL Routing Foundation Integration` |
| `repotraffic-com-server` | `WaitingList` | `swift-url-routing/URL Routing Foundation Integration` |

Both root edges were **verified in the manifests directly**, not trusted from the
probe:

- `swift-favicon/Package.swift:29` —
  `.product(name: "URL Routing Foundation Integration", package: "swift-url-routing")`
  in the `Favicon` **target**'s dependencies (`:21-30`).
- `swift-environment-dependencies/Package.swift` — target `Environment
  Dependencies` lists **both** `"Environment Dependencies Core"` and
  `"Environment Dependencies Foundation Integration"`.

**Mitigating, and it matters:** the environment-dependencies case is a
**deliberate, documented migration facade.** The manifest says so in-place:
*"Compatibility-only migration facade. New consumers must select Core or
Foundation Integration directly; this target accepts no new behavior."* The
package's real core is `Environment Dependencies Core`, which is clean. So this
is a known transitional shape, not an oversight — a violation by the letter of
the rule, deliberately incurred and sign-posted.

### 12d — this corroborates and extends BOARD #11

```
FI target each violation lands on:
   swift-url-routing/URL Routing Foundation Integration              26
   swift-environment-dependencies/Environment Dependencies FI        10
```

**4 of the 5 direct violations are the URL Routing FI-product omission** — BOARD
#11 is *"Lint rule for the URL Routing FI-product omission (3 instances in one
day)"*. The census finds **4** direct instances (`swift-favicon`, plus
repotraffic's `RepoTrafficRouterVapor`, `Repositories`, `WaitingList`), and shows
they poison **26 core targets** transitively.

**#11's proposed lint rule would catch 4 direct sites and clear 26 of the 36
closure violations.** That is a strong argument for prioritising it: the rule is
cheap and its blast radius is most of this violation class.

### 12e — concentration

| Package | Core targets reaching an FI target |
|---|---|
| `repotraffic-com-server` | 33 |
| `swift-environment-dependencies` | 1 |
| `swift-favicon` | 1 |
| `swift-records` | 1 |

**33 of 36 are in repotraffic** — inherited through 3 of its own direct edges
plus `swift-favicon`. It is one application inheriting two upstream mistakes,
not a diffuse ecosystem problem. Consistent with BOARD's repotraffic thin-layer
plan: fixing `swift-favicon` and repotraffic's 3 direct edges clears essentially
the whole class.

### 12f — what remains UNMEASURED

**The `@_exported` re-export residue.** A core target can reach Foundation with
**no declared FI dependency at all**, by importing a module that `@_exported
import`s it — exactly the `swift-github-standard` shape (Finding A) and the
`RFC_9112 → RFC_9110` chain (§10d). That path is invisible to a manifest-level
closure and **is not included in the 36**.

**Explicitly: 36 is the declared-dependency answer. It is not an upper bound on
[ARCH-LAYER-007] violations.** Measuring the residue requires the compiler —
resolving each target's actual module import graph after re-export — which needs
a build. **Not run. Labelled unmeasured rather than folded in**, because mixing a
measured closure with an inferred one would destroy the value of the measured
part.

---

## Phase 13 — instrument audit, and two cross-lane reconciliations

### 13a — `xargs -a` alert: DOES NOT APPLY. No figure affected.

The alert is real and I reproduced it independently rather than relaying it:

```
$ xargs -a /tmp/xa_list.txt echo
xargs: invalid option -- a
usage: xargs [-0opt] ...
pipeline exit: 0          <- fails silently
```

**Audit of all three probes — `census.py`, `graph.py`, `ficlosure.py`:**

```
grep -nE "xargs|subprocess|os\.system|popen|shell=" census.py graph.py ficlosure.py
   -> (none) in all three
```

They traverse with `os.walk` / `os.listdir` and read with `open()`. **No probe in
this lane shells out at all**, so no figure here — consumer counts, in-degrees,
the two refutations, the FI closure — can have been produced by the broken idiom.

The one ad-hoc use of `xargs` this session was the portable
`find -print0 | xargs -0 grep -l "path:"` form, which returned a non-zero 170;
and that figure was **discarded as context-blind** (§2b) rather than reported.

**Proof rather than assurance, via the two-sided control (§7b):** the consumer
census returned **0** for `swift-types-foundation` — a *known* zero — **while the
same code path returned in-degrees up to 90** (`swift-index-primitives`). **A
probe stuck at zero cannot report 90.** The control and the headline figures ran
through the same function, so the soundness is demonstrated, not asserted.

**Status: no figure affected. "None" is the answer.**

### 13b — the `@_exported` caveat is now BOUNDED, and my framing was too pessimistic

The layering lane measured the effect at scale: **94.25%** of cross-package
module coupling is a direct manifest dep, **5.29%** is closure-only, **0.46%** a
genuine hole; closure accounts for **99.54%**. Mechanism: **`@_exported` requires
a real manifest edge in the re-exporting package**, so the re-exported owner
still lands in the consumer's transitive closure.

**Consequence for this document — the caveat splits in two:**

- **Direct in-degree counts (§7b, §7d): the caveat STANDS.** The 118
  zero-consumer figure remains an **upper bound**, since a package can be bound
  through a chain without being named in the consumer's manifest.
- **Closure-derived counts (§12): the caveat is much WEAKER than I labelled it.**
  The FI closure follows declared edges transitively, and `@_exported` cannot
  create a target-level dependency without a manifest edge somewhere in the
  chain. **So the 36 is more robust than §12f implies.**

**Correcting §12f:** the residue is not "FI targets reachable invisibly". It is
the narrower and different case of **Foundation entering a core closure through a
non-FI module that `@_exported import`s it** — the `swift-github-standard` shape.
That is a violation of the Foundation-free rule rather than of the FI-dependency
rule, and it is **already partly visible in the 1330-line source census** (§9a),
not a wholly unmeasured category. Still needs the compiler to bound exactly; but
smaller and better-characterised than I first stated.

### 13c — `swift-github-standard`'s "3 undeclared upward imports": REFUTED, same root cause as Finding A

A peer lane reports 3 undeclared upward imports in `swift-github-standard` —
sources importing `Dependencies`, `Dual`, `URLRouting` with none declared in the
manifest — described as invisible to any manifest-derived census.

**The imports exist. They are all in UNDECLARED source.**

```
Sources/GitHub Types Shared/exports.swift:1     @_exported import Dependencies
Sources/GitHub Types Shared/exports.swift:4     @_exported import Dual
Sources/GitHub Types Shared/exports.swift:5     @_exported import URLRouting
Sources/GitHub Stargazers Types/GitHub.Stargazers.Client.swift:8  import Dependencies
Sources/GitHub OAuth Types/exports.swift:8      @_exported import Dependencies
Sources/GitHub OAuth Types/GitHub.OAuth.Client.swift:8            import Dependencies
```

**Inside the one declared source target (`Sources/GitHub Standard`): ZERO.**
Control: the same probe finds **24** imports in that directory, so it fires.

`GitHub Types Shared`, `GitHub Stargazers Types` and `GitHub OAuth Types` are
three of the **seven undeclared directories** identified in Finding A. The
manifest declares no dependency on `Dependencies`/`Dual`/`URLRouting` **because
no declared target uses them.** The manifest and the compiled reality agree; only
the orphaned source disagrees, and it compiles nowhere.

**So these are not upward edges of shipped code — they are more orphaned-source
artefacts.** `Sources/GitHub Types Shared/exports.swift` has now generated
**two** separate false findings in this census: the `@_exported import Foundation`
"violation" (Finding A) and these 3 "undeclared upward imports". **One
6-line file in undeclared source is the single most misleading artefact
encountered in this work** — and both false findings share one cause: *source
that exists on disk but in no target*.

### 13d — the 2-vs-14 upward-edge dispute: probable resolution

A peer lane measures **14** upward edges (11 declared + 3 undeclared) against my
final **2**. These are almost certainly **not in conflict**:

- Its **3 undeclared** are refuted in §13c — orphaned source, not shipped edges.
- My **raw** measurement before rulings was **14 declared** (§4c): mailgun-types
  ×5, stripe-types ×4, postgresql-standard ×1, rfc-2388 ×1, **linter-rules ×3**.
- **14 − 3 linter-rules = 11.** If its 11 excludes lint-tooling packages, the two
  raw declared sets are **identical**.
- My 2 is the **post-ruling** figure: ruling 1 (mailgun/stripe → L3) removes 9;
  ruling 2 (tooling outside the model) removes 3; leaving `rfc-2388` and
  `postgresql-standard → swift-tests`.

**Hypothesis: we agree exactly on the measurement and differ only on which Lead
rulings have been applied.** To be settled with that lane directly; recorded here
so the reconciliation is not lost if it is.

---

## Phase 14 — ⚠️ §12 CORRECTED: the FI closure was wrong by 5×. 36 → 176.

**The layering lane found a real defect in `ficlosure.py` and its challenge was
correct.** Recording the correction prominently rather than quietly amending §12.

### 14a — the defect

Several manifests route target dependencies through `Target.Dependency` aliases:

```swift
extension Target.Dependency {
    static var dual: Self { .product(name: "Dual", package: "swift-dual") }
}
.target(name: "Mailgun Types Shared", dependencies: [.dual, .urlRouting, ...])
```

`_const_map()` deliberately skips any constant whose body contains `(` — which
excludes exactly these. The bare `.dual` reference then resolved to nothing and
**the dependency was silently dropped.**

**Demonstrated on the lane's proposed test case.** `swift-mailgun-types`, target
`Mailgun Types Shared`, before the fix:

```
product deps: []          <- WRONG. Seven real dependencies attributed to nothing.
```

After adding a `Target.Dependency` alias map:

```
product deps: [('Domain Standard','swift-domain-standard'), ('EmailAddress','swift-emailaddress'),
               ('URLRouting','swift-url-routing'), ('HTML Form Coder Codable','swift-html-form-coder'),
               ('HTML Standard','swift-html-standard'), ('Dual','swift-dual'),
               ('Dependencies','swift-dependencies')]
sees swift-dual? True
```

### 14b — corrected result

| | Before (defective) | **After (corrected)** |
|---|---|---|
| Core targets reaching an FI target | 36 (2.1%) | **176 (10.1%)** |
| Direct violations | 5 | **15** |
| Inherited | 31 | 161 |

**The defect suppressed 140 of 176 violations — 80% of the finding.**

Still **measured, not floor**: unresolved product references rose 169 → 212, and
**all 212 still point at external packages, zero at local ones** (re-verified
exhaustively, not sampled).

### 14c — the 15 direct violations

| Package | Core target | Depends directly on |
|---|---|---|
| `swift-favicon` | `Favicon` | URL Routing FI |
| `swift-identities-types` | `IdentitiesTypes` | URL Routing FI |
| `swift-mailgun-types` | `Mailgun Reporting Types` | URL Routing FI |
| `swift-mailgun-live` | `Mailgun Shared Live` | URL Routing FI |
| `swift-stripe` | `Stripe Shared` | URL Routing FI |
| `swift-stripe-live` | `Stripe Live Shared` | URL Routing FI |
| `repotraffic-com-server` | `App Routes`, `RepoTrafficRouter`, `RepoTrafficRouterVapor`, `Billing`, `BillingLive`, `Repositories`, `WaitingList`, `WaitingListRemote` | URL Routing FI |
| `swift-environment-dependencies` | `Environment Dependencies` | its own FI target (documented migration facade) |

```
landing FI target:  URL Routing FI  161   ·  Environment Dependencies FI  15
by package: swift-stripe 42 · swift-stripe-live 41 · repotraffic 35 ·
            swift-mailgun 19 · swift-mailgun-live 19 · swift-authentication 6
```

### 14d — what the correction changes for the board

**BOARD #11 becomes considerably more valuable, not less.** It records the URL
Routing FI-product omission as *"3 instances in one day"*. The corrected census
finds **14 direct sites** (all but the environment-dependencies facade), poisoning
**161 of 176** closure violations. **A lint rule for this single mistake would
clear 91% of the FI-closure violation class.** On the earlier defective number
that argument was strong; on the corrected number it is close to decisive.

The concentration also shifts: it is **not** a repotraffic-only problem. Stripe
(42) and stripe-live (41) now exceed repotraffic (35), and `swift-mailgun`,
`swift-mailgun-live` and `swift-authentication` are all newly implicated.

### 14e — why this got through, and what it says about the method

The residual controls that caught three earlier defects **did not catch this
one**, and it is worth being precise about why:

- `missing_target_dirs = 0` — unaffected; the defect drops *dependencies*, not targets.
- `unresolved product refs` — all external, so it looked clean. **A dropped alias
  produces no unresolved reference; it produces no reference at all.**
- The FI closure had **no two-sided control.** §7b's consumer census had one
  (`TypesFoundation` known-zero *and* in-degrees to 90) and that is exactly what
  proved it sound under the `xargs -a` alert. **§12 shipped with a one-sided
  check** — I verified the violations I found were real (§12c), but never verified
  that targets reporting *no* FI dependency genuinely had none.

**The lesson is the certificates lane's, arriving from the opposite direction:**
*"expecting the answer is what made me skip the control."* I expected the FI
closure to be small, 36 looked plausibly small, and I confirmed the positives
without ever testing a negative. **A probe that under-reports looks exactly like a
clean ecosystem.**

**Standing correction to this lane's method: every count needs a control at BOTH
ends — a known-positive that must fire and a known-negative that must not.** The
consumer census had it and survived scrutiny; the FI closure lacked it and was
wrong by 5×.

---

## Phase 15 — orphan-count reconciliation with the layering lane

That lane counts **43 orphan directories, 26 with Swift files**; §5 of this
document reports **154 / 109**. It asked what my denominator is. Measured:

| Scope | Orphan dirs | …with `.swift` files |
|---|---|---|
| under `Sources/` | **44** | **25** |
| under `Tests/` | **110** | **83** |
| **total** | **154** | **108** |

**The ~4× gap is entirely `Tests/`.** That lane scans `Sources/` only, and its
44/25-equivalent is **43/26** — agreement to within one directory in each
direction on the same scope. There is no methodological disagreement.

This lane counts `Tests/` because the brief requires it: *"the test target is a
consumer too — census `Tests/` alongside `Sources/`, and say which bucket each
number is in."* Both figures are correct for their stated scope; **neither should
be quoted without it.**

**Minor self-correction:** §5 said "109 containing `.swift` files"; the precise
figure is **108**. The earlier count used a raw `os.walk` that did not prune
`.build*`, so one directory qualified on files that a pruned walk excludes. The
pruned figure is the correct one.

### 15a — suffix-chain false-orphan class: checked, not present here

The layering lane warned that `swift-mailgun-types` / `swift-mailgun-live` name
targets by suffix chain (`static let reporting: Self = "Mailgun Reporting".types`
with `var types: Self { self + " Types" }`), and that its first target-aware pass
read all 19 mailgun directories as orphaned.

**Checked. This lane's suffix-chain resolution (§3a, added after the
`"Mailgun".types` defect) already handles it:**

```
swift-mailgun-types   orphan dirs in this census: 0
swift-mailgun-live    orphan dirs in this census: 0
swift-mailgun         orphan dirs: 1  (Tests/Mailgun Domains Tests — a genuine Tests/ orphan)
```

The defect that cost this lane a re-run at §3a is the same one that would have
produced 19 false orphans here. **Fixing it early is why this number needs no
correction now** — recorded because the two lanes hit the identical trap from
opposite directions and only one of us paid for it twice.

### 15b — the `@_exported` bound, tightened by the layering lane's own correction

Adopting the target-aware rule (this lane's suggestion, that lane's rebuild)
moved its figures:

| measure | by directory | **by declared target** |
|---|---|---|
| imports whose owner is a direct dep | 94.25% | **94.68%** |
| owner only in closure | 5.29% | **5.25%** |
| owner **not** in closure | 13 (0.46%) | **2 (0.07%)** |
| closure accounts for | 99.54% | **99.93%** |

**Eleven of its thirteen closure holes were dead source.** Its two survivors are
both the module name `Testing`, where `swift-foundations/swift-testing` vends
`.library(name: "Testing")` — the same name the toolchain-bundled
`apple/swift-testing` vends — so ownership is **unresolved, not confirmed**.

**Defensible statement: the transitive closure accounts for between 99.93% and
100% of attributable cross-package coupling.** Use the range, not a point
estimate. This further strengthens §13b: the `@_exported` hazard is a real but
small effect on *direct-edge* counts and very nearly nil on closure-derived ones.

---

## Phase 16 — post-`2beb8d8` status, and an L4 refinement

### 16a — the predicate hole is CLOSED; this census's numbers are NOT stale

`swift-institute-linter-rules` **`2beb8d8`** — *"Foundation import rule: cover the
whole module family; fix the diagnostic's layer claim"* — is present locally and
verified in the source:

```
Lint.Rule.Foundation.Import.swift:90   private let foundationModuleFamily: Swift.Set<Swift.String> = [
Lint.Rule.Foundation.Import.swift:104  return foundationModuleFamily.contains(firstComponent)
```

The two-name equality test (§8a) is gone. **The guard hole is closed.**

**Precise statement of what this does and does not invalidate**, because the
handover framed the whole #24 baseline as stale:

| | Affected by `2beb8d8`? |
|---|---|
| The 1330 core-target import lines | **No.** Measured directly from source with a matcher covering the full family since the first run (§2a). The 48 `FoundationNetworking` lines were **always inside** the 1330. |
| The 96.2% / 3.6% module split | **No.** A measurement of the tree, not of the guard. |
| Derived claim *"the guard sees 96.2% of the violation mass"* | **YES — now 100%.** |
| Any **lint-derived** zero-set computed before `2beb8d8` | **YES — false zero for exactly those 48 lines.** |

**No figure in this document is lint-derived.** This census has never run lint;
§10a records the HTTP lane's run as that lane's measurement, attributed. So the
#24 baseline stands unchanged at **39 packages / 1320 lines**, and only the
guard-relative sentence in §8c needed updating.

The distinction matters beyond bookkeeping: **a measurement of the tree and a
measurement of what a tool reports about the tree are different objects**, and
conflating them is how a tracked "4" survived against 1330 actual lines in the
first place.

Also confirmed fixed in `2beb8d8`: the diagnostic no longer tells an L3 engineer
this is a primitives rule (§8a secondary defect), and first-path-component
matching is preserved, so `HTML_Foundation` / `Server_Foundation` still do not
fire.

### 16b — the real mechanism, restated

Step 0 settled it: the rule **runs**, is **red**, and is **non-binding**
(`default: .warning`, `:22` — exit 0 with 72 violations outstanding). **1283
rule-matching lines accumulated because nothing ever went red.** A policy defect,
not a predicate defect. The predicate hole was real and is now closed, but it was
never the explanation.

### 16c — L4 refinement: "reserved remotely" vs "local directory only"

The HTTP lane reports `swift-components/swift-http-cache` and
`swift-http-middleware` are not git repositories and `gh repo view` cannot
resolve either. **Checked locally, and the finding is much broader than two
directories:**

```
swift-components:  25 directories · with .git = 1 · LOCAL-ONLY = 24
```

**Only `swift-server-static` is a git repository at all.** The other 24 have no
`.git` and no `Package.swift` — they are local directories carrying a licence and
config files, not reserved repositories.

**This sharpens §1c.** The correct characterisation of L4 is not "25 reserved
package slots awaiting inhabitants" but **one real package and 24 local-only
directories**, most of which appear not to exist remotely at all.

Remote existence was **not** verified by this lane — `gh repo view` is a network
call and the local `.git` absence is what was measured. **Reported as: 24 of 25
have no local git repository (measured); remote non-existence is the HTTP lane's
observation for the two it checked (attributed, not reproduced here).**

Note this is consistent with, and explains, §13a's earlier result that 480
depth-1 *packages* all had `.git`: these 24 have no `Package.swift`, so they were
never in that population.

---

## Phase 17 — third alias spelling, and measured workspace drift

### 17a — a THIRD alias spelling; found by the layering lane, fixed, and it moved nothing

After §14's fix, the layering lane's audit of its own 42 unattributed
declarations turned up a form neither probe handled —
`swift-ietf/swift-rfc-791/Package.swift:10-16`:

```swift
extension Target.Dependency {
    static let byteSLI = Self.product(name: "…", package: "swift-byte-primitives")
}
```

**No `: Self` annotation, assignment rather than a brace body, and `Self.`-prefixed.**
My §14 alias map required `: Self` and matched a leading `.`, so it resolved
**none** of `swift-rfc-791`'s seven aliases.

Widened to accept all three spellings. **Controls — all four forms must resolve:**

```
PASS  brace body        static var dual: Self { .product(…) }
PASS  annotated assign  static let d: Self = .product(…)
PASS  unannotated Self. static let byteSLI = Self.product(…)
PASS  target form       static let rfc791 = Self.target(…)
swift-rfc-791 aliases now resolved: 7   (was 0)
```

**Re-ran the FI closure: 176 — unchanged.** The affected manifests are IETF RFC
packages depending on primitives, none of which reach a Foundation Integration
target, so the third spelling suppressed nothing.

**Recorded because the outcome does not vindicate skipping the check.** The same
class of bug cost 140 violations one phase earlier (§14); that it cost zero here
is a property of *which* manifests use the form, not of the bug being harmless.
**Measured, not assumed** — the §14 lesson applied.

### 17b — the workspace moved under this census, and the figures needed re-running

The layering lane flagged that both our graphs are snapshots of a live workspace
and measured 1 manifest changing under its snapshot (22:04:56). **Against this
lane's earlier snapshot (`census.json`, 21:35:36), three changed:**

| Manifest | Modified |
|---|---|
| `swift-foundations/swift-server-foundation/Package.swift` | 21:56:37 |
| `swift-foundations/swift-certificates-n5/Package.swift` | 22:01:57 |
| `swift-ietf/swift-rfc-5280/Package.swift` | 22:30:58 |

(The lane saw only the third because its reference time was later; the first two
were already inside its snapshot. Consistent, not contradictory.)

**Re-ran both probes. Figures DID move — this was not a no-op:**

| | 21:35 snapshot | **Re-run 22:5x** |
|---|---|---|
| core import lines | 1330 | **1323** |
| core packages | 46 | **45** |
| **genuine violation lines** | 1320 | **1314** |
| **genuine violation packages** | 39 | **38** |
| same-layer edges | 1475 | **1474** |
| **upward edges** | 14 | **14 (unchanged)** |

Attributed exactly:

```
swift-foundations/swift-certificates-n5      6 -> 0    (now Foundation-free)
swift-foundations/swift-server-foundation    2 -> 1
```

**`swift-certificates-n5` went clean during this session** — 6 core lines to 0.
That is another lane's work landing, not measurement error.

### 17c — every figure in this document is now timestamped

**All #24 and #25 figures in this document are as of `2026-07-24 ~22:55` local**,
except where a phase states its own snapshot. The FI closure (§14, 176) was
computed at 22:44 and re-verified at 22:56, both post-drift.

**Superseded by this phase:** §9a's `39 packages / 1320 lines` and §9d's headline
→ **38 packages / 1314 lines**. §4b's `1475` same-layer → **1474**. The upward
count of **14 raw / 2 post-ruling is unaffected.**

**Standing method note:** a census of a live workspace is a *measurement with a
timestamp*, not a fact. Three manifests moved in the 80 minutes between this
lane's first and last runs, and one of them changed a headline figure. **Any
figure quoted from this document should carry its time**, and any consumer
re-running these probes should expect small drift rather than treating a
mismatch as a defect in either run.

---

## Phase 18 — per-rule ecosystem census: preparation (assigned by Lead)

Assigned to enable the severity ratchet (flip a rule to `.error` only when its
ecosystem-wide count is already zero). **Population ruled MAXIMAL.** Preparation
below is read-only; the run itself needs a coordinator slot and is not started.

### 18a — ⚠️ TWO DEFECTS IN THE HANDED-OVER HARNESS, both false-zero generators

`swift-institute-linter-rules/Tests/Institute Linter Rule Byte Tests/Lint.Rule.Byte.ArcG.Validation.swift`:

**Defect 1 — it scans `Sources/` ONLY.** Lines 38 and 68 both build
`"\(workspaceRoot)/\(package)/Sources"`. **`Tests/` is never enumerated.**

This is the ratchet trap in its purest form. `Lint.Rule.Framework.XCTest` is
documented to fire *"on any file — both `Sources/` and `Tests/`"*, and this lane's
own #24 census found **534 Foundation import lines in test targets** against 1323
in core. **A rule measured zero over `Sources/`-only and then flipped to `.error`
breaks every build the moment lint reaches `Tests/`.** The harness would generate
exactly the false zero the population ruling was written to prevent.

**Defect 2 — `entry.hasPrefix("swift-")`** (line 37) silently excludes every
package not so named: **`repotraffic`, `boiler`, `control`, `foundry`**, and the
660 non-`swift-`-prefixed manifests in the maximal population. Under a maximal
ruling this is a silent boundary of exactly the kind that cost this lane 426
manifests earlier (§10c).

**Both must be fixed before the census runs.** Neither is visible in its output.

### 18b — a third issue: the harness is ~92× more expensive than it needs to be

Its loop is `for rule { for package { for file { parse; run rule } } }` — it
**re-parses every file once per rule**. At 92 rules × 18,531 files that is
**~1.7 million parses**.

Restructuring to `for file { parse once; for rule { run } }` gives 18,531 parses
and 1.7M rule *visits*. **This is the difference between the run being feasible
and not**, and it is why the HTTP lane's ≈60–70 min estimate should not be
carried over — it was derived from the unrestructured shape over a smaller
population.

### 18c — the rule corpus does not need hand-listing

`Lint.Rule.Bundle.institute` is `[Lint.Rule.Configuration]`
(`Lint.Rule.Bundle.institute.swift:50-51`), and `Lint.Configuration.lift.swift:26`
documents each entry's `rule.id → rule`. **So the census can iterate the bundle
itself** rather than the harness's hand-listed 7-rule array.

That matters for correctness, not just convenience: **the bundle is what a
consumer actually activates**, so iterating it measures the real rule population
instead of a transcription of it. Declared rules found: institute **84**,
`swift-linter-rules` **9**, `swift-primitives-linter-rules` **3**.

### 18d — the maximal population, sized

```
manifests, all depths, all 21 roots : 1273
  with Sources/                     : 1146
  with Tests/                       :  514
  total .swift files in Sources/+Tests/ : 18,531
  basename not starting "swift-"    :  660   <- invisible to harness defect 2
```

### 18e — scoping question the Lead must settle

The maximal population includes `Experiments/` spikes and `Issues/` reproducers —
**deliberately broken code**. The asymmetry runs the other way for these:

- **Under-scoping → false zero → unsafe flip → broken builds.** The danger the
  ruling addresses.
- **Over-scoping → false non-zero → a safe rule is blocked from flipping.**
  Wasteful, never dangerous.

So including them is the *safe* error. **Proposal: report BOTH counts per rule —
shipped packages, and the maximal population — and let the Lead flip on whichever
it judges right.** A rule that is zero over both is unambiguously safe; one that
is zero only over shipped packages is a decision, not a measurement.

### 18f — both-ended controls, with an independent oracle

The Lead's condition is a rule known to fire and a rule known clean. This census
has an unusually strong known-positive available:

**`Lint.Rule.Foundation.Import` has an independently measured expected value.**
§9a/§17b measured, by a completely different instrument (a Python comment-
stripping source scan, no lint involved): **1323 core + 534 test + 149 undeclared
Foundation-family import lines.** Post-`2beb8d8` the rule's predicate matches the
same family this lane's matcher does.

**So the per-rule census must report a Foundation-import count consistent with
those figures.** If it reports 0, or a number off by an order of magnitude, the
harness is broken — and that is detectable *before* any rule is flipped, by two
instruments that share no code.

This is the two-sided control whose absence cost this lane the 5× FI-closure
error (§14e), and it is stronger here than there: the negative side is a rule with
no findings, and the positive side is a rule whose count is already known from
outside the instrument being tested.

**Status: prepared, not run. Coordinator slot requested; not taken.**

### 18g — two blockers found before starting the run

**Blocker 1 — reaching the bundle requires a new test target.**
`Lint.Rule.Bundle.institute` lives in the `Linter Institute Rules` target, and
**no test target depends on it.** Every existing test target depends on exactly
one rule module (`"Institute Linter Rule Byte"` + test support, etc.). Verified
across all 16 `.testTarget` blocks.

So iterating the bundle — the correctness-critical generalisation of §18c —
cannot be done from any existing test target. Three ways forward:

| Option | Touches shipped files? | Note |
|---|---|---|
| Add a `.testTarget` to `Package.swift` | **yes** — edits a shipped manifest | smallest code, largest blast radius |
| **Nested package** (`Census/Package.swift`, `.package(path: "..")`) | **no** — purely additive | documented pattern; precedent in `swift-tagged-primitives/Lint/`, `swift-linter/Runner/` |
| Hand-list the rules in an existing target | no | **defeats the point** — a transcription that drifts silently from the bundle (§18c) |

**Recommended: the nested package.** It modifies no existing file, matches an
established pattern in this workspace, and keeps a read-only lane read-only.

Contained either way: 141 consumer `Lint.swift` files reference
`swift-institute-linter-rules` **by URL, not path**, so a local manifest change
would not propagate to their resolution. The tree is clean
(`git status --porcelain` empty), so any edit would be this lane's alone.

**Blocker 2 — both coordinator slots are occupied.**

```
PID  6388  swift-build package --package-path .../swift-package-manager  test
PID 13126  swift-build package --package-path .../swift-rfc-9112         test
```

There are **2 slots**. The grant is real but the capacity is not free right now.
These are different packages, so no `.build` deadlock risk (the lock is
per-package), but the run would contend for machine capacity against two lanes'
gates.

`swift-institute-linter-rules/.build` was last touched 22:28:53 and nothing holds
a lock on it.

**Status: prepared and held.** Not editing a shipped manifest and not contending
for a slot without the Lead's answer on Blocker 1.

### 18h — what was created (nested package, Lead-approved)

**Two new files, no existing file modified:**

```
swift-institute-linter-rules/Census/Package.swift          (31 lines)
swift-institute-linter-rules/Census/Sources/census/main.swift
```

Both carry a `TEMPORARY … delete after closeout` header, matching the existing
Arc G harness's own convention. The parent `Package.swift` is untouched
(`git status --porcelain` on the repo showed it clean before and the manifest is
not among the changes).

Dependencies are both **by path** — `..` and `../../swift-linter-rules` — so the
census resolves against the working tree, not a remote, and picks up `2beb8d8`.

**Build:** GREEN, `exit 0` captured **bare** (not through a pipe), **3 compile
steps, freshly compiled** — `Build complete! (8.28s)`, with the coordinator's own
cross-check reporting *"every instrument agrees (3 compile step(s), freshly
compiled)"*. **Not a cached build.**

### 18i — two instrument traps hit while building this, both this document's own rules

1. **`BUILD EXIT: 0` from a failing build.** The first build reported RED with 7
   diagnostics, and my `echo "BUILD EXIT: $?"` printed **0** — because the
   command was piped into `tail`, so `$?` was *tail's* status. Exactly the zsh
   `$pipestatus` trap in §Method. Re-run capturing the status **bare**: `exit 1`,
   correctly. **A pipeline exit status is not the command's exit status.**
2. **`--include=*.swift` glob-expanded by zsh**, producing `no matches found` and
   an empty result from a `grep` that never ran. Quoted (`--include='*.swift'`)
   it found the helper immediately. Same family as the `xargs -a` alert: **a
   probe that never ran, reporting as a clean zero.**

Both were caught because the output looked wrong, not because a control fired —
which is the weaker of the two ways to catch something.

---

## Phase 19 — PER-RULE ECOSYSTEM CENSUS: RESULT

**Run: 2026-07-24 ~23:03–23:15, 691.3 s (11.5 min), one process, one coordinator
slot.** Post-`2beb8d8`. Nothing's severity was changed.

### 19a — population, stated explicitly

```
roots declared           : 21
packages found           : 1415
   shipped (depth-1)     :  481
   auxiliary (deeper)    :  934
scanned subtrees         : Sources/ AND Tests/
rules in Bundle.institute:   92   (all 92 enabled)
files scanned            : 27,803
files unreadable         :      2   <- UNMEASURED, not counted as zero
```

An unstated population is how a false zero gets ratcheted, so it is the first
thing in the output rather than a footnote.

### 19b — ⭐ THE CROSS-INSTRUMENT CONTROL PASSES

| | |
|---|---|
| Independent Python source scan (§9a/§17b), **shares no code with the linter** | 1323 core + 534 test + 149 undeclared = **2006** |
| Census, via the **Swift rule engine** (`foundation import`, shipped) | **2039** |
| **Delta** | **+33 (+1.6%)** |

**Two instruments with nothing in common agree to within 1.6%.** The residual is
expected: the two runs are ~30 minutes apart in a workspace measured to drift
(§17b), and the linter counts every matching import in `Sources/`+`Tests/` of a
shipped package while the Python census bucketed by declared target.

**This is the control whose absence cost this lane a 5× error (§14e).** Its
purpose was to make a broken harness detectable *before* any rule is flipped, and
it did its job: a `Sources/`-only harness (the §18a defect) would have returned
roughly the core figure alone and the discrepancy would have been visible here.

**Known-negative side:** 14 of 92 rules return zero over the maximal population.

### 19c — headline

```
92 rules · 78 fire somewhere · 14 fire nowhere
total findings: 136,575 maximal · 60,628 shipped
```

**Top 10 by maximal findings:**

| Rule | Shipped | Maximal | Pkgs(ship) | Pkgs(max) |
|---|---|---|---|---|
| compound identifier | 17308 | 38424 | 330 | 1019 |
| minimal type body | 5994 | 18871 | 199 | 831 |
| compound type name | 5486 | 14671 | 278 | 894 |
| single type per file | 4943 | 9654 | 190 | 261 |
| test function naming | 2337 | 8909 | 57 | 130 |
| suite categories | 3074 | 5405 | 317 | 495 |
| raw value access | 3294 | 4987 | 171 | 358 |
| **foundation import** | **2039** | **4926** | **109** | **234** |
| int public parameter | 2561 | 4201 | 176 | 331 |
| do throws for typed catch | 1067 | 3279 | 101 | 262 |

**All 92 rules carry `default: .warning`. Not one is an error.** That is #24's
mechanism generalised: **the entire rule corpus is non-binding**, so 136,575
findings can accumulate without any build going red. The Foundation rule is not a
special case — it is the corpus's normal condition.

### 19d — the 14 ratchet CANDIDATES (not decisions)

Zero over **both** populations — shipped *and* maximal:

```
binary serializable uint8 witness      byte conforms to arithmetic protocol
convention c representability          dead case per platform
enumerated with subscript              hoisted protocol alias
lifecycle order                        malformed suppression directive
noncopyable error                      sendable struct with class member
system subdomain                       typed throws cannot use self error
uint8 conforms to byte protocol        uint8 forwarder missing disfavored
```

**Each is a CANDIDATE. The Lead flips; this lane measures. Nothing changed
severity on this run.**

Zero over both populations is the strong form: a rule zero only over shipped
packages would be a decision about scope, not a measurement.

### 19e — caveats that bound these numbers

1. **Over-reporting, in the safe direction.** `Parsed` is constructed directly,
   so the engine's brand pre-pass (`declaredTypeNames`) is empty and rules that
   self-suppress at a brand owner's own surface fire here where a real
   `swift-build lint` run would suppress them. **Over-reporting can only block a
   flip, never enable an unsafe one** — so candidates are conservative, and the
   14 may understate the true zero set.
2. **2 files unreadable — reported as unmeasured, not as zero.**
3. **The census measures its own source.** `Census/Sources/census/main.swift` is
   inside a scanned root; a self-inclusion artefact of at most one file.
4. **Counts are at `.warning` by construction. This is a count, not a severity
   check** — it says what a rule *would* report, not what any build enforces.
5. **Not a substitute for `swift-build lint`.** It runs the same rule witnesses
   over the same sources, but not through the engine's full pipeline
   (configuration lifting, path filters, per-package disables). **A candidate
   should be confirmed by a real lint run on at least one package before flipping.**

### 19f — candidate-confirmation selection (evidence-based, not instinct)

The Lead asked for the 3 candidates whose zero is most load-bearing and most
likely to be wrong, on the instinct that widespread subject matter beats niche.
**Selection was made by measuring subject-matter density rather than by
instinct**, because "widespread" is checkable.

**A zero only means something if the rule had ample opportunity to fire.** So for
each candidate the question is not *"is the topic common?"* but *"which package
would this rule fire in, if it fires anywhere?"*

Density measured independently of the linter (`/usr/bin/grep`, `--exclude-dir`
during the walk, not filtered after):

| Construct | swift-byte-primitives | repotraffic-com-server | swift-json |
|---|---|---|---|
| `UInt8` | **109** | — | — |
| `Byte` | **292** | — | — |
| `@_disfavoredOverload` | **13** | — | — |
| `throws(Self.Error)` | **1** | 0 | 0 |
| `@unchecked Sendable` | 0 | **9** | 1 |
| `.enumerated()` | 0 | **4** | 1 |

**Two packages cover 7 of the 14 candidates at their densest sites:**

| Package | Candidates it exercises |
|---|---|
| `swift-byte-primitives` | `uint8 conforms to byte protocol` · `byte conforms to arithmetic protocol` · `binary serializable uint8 witness` · `uint8 forwarder missing disfavored` · `typed throws cannot use self error` |
| `repotraffic-com-server` | `sendable struct with class member` · `enumerated with subscript` |

This is better value than three packages covering three rules, and each zero is
tested where it is most exposed: **the byte rules' ecosystem-wide zero is
unsurprising; their zero over `swift-byte-primitives` is the one that would
embarrass us.**

**A finding already, before the lint run.** The ecosystem's *only*
`throws(Self.Error)` occurrence is
`swift-byte-primitives/Sources/Byte Protocol Primitives/Byte.Protocol.swift:120`:

```swift
init(_ byte: Byte) throws(Self.Error)
```

It sits **inside a protocol declaration**, which the rule documents as the one
legal position (`Lint.Rule.Throws.SelfErrorInTypedThrows.swift:15-18`:
*"resolves only inside a protocol declaration with an `associatedtype Error`
requirement"*). **So the census's zero is not vacuous — the rule saw the
construct and correctly declined to fire.** That strengthens the candidate rather
than refuting it, and it is exactly the check that distinguishes "measured zero"
from "never had the chance".

**Status: selection complete, slot requested, no lint run started.**

---

## Phase 20 — underscore-attribute blind spot: this lane's probe is CLEAN

The Lead hit a fail-open probe: `@[a-zA-Z]+` does not match `@_exported`, so a
pattern anchored that way is blind to every import in an umbrella `exports.swift`
— and would certify a package clean rather than fail loudly. On the exact rule
being ratcheted toward `.error`, that is the dangerous direction.

**This lane's pattern, verbatim:**

```
^\s*(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+)*(?:(?:public|internal|package|private|fileprivate)\s+)?(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+)*import\s+(?:typealias\s+|struct\s+|class\s+|enum\s+|protocol\s+|var\s+|func\s+)?(Foundation|FoundationEssentials|FoundationNetworking|FoundationXML)(?:\.[A-Za-z_][A-Za-z0-9_]*)*\s*$
```

**The attribute class is `@[A-Za-z_][A-Za-z0-9_]*` — underscore is in the first
character class.** It also allows an optional `(...)` argument list (`@_spi(X)`),
attributes on **both** sides of the access-level modifier, and any leading
whitespace (so an import indented inside `#if canImport(...)` still matches).

**Control battery — all 12 pass:**

| Case | Want | Got |
|---|---|---|
| `@_exported import Foundation` | 1 | 1 |
| **`@_exported public import Foundation`** (the Lead's stacked shape) | 1 | 1 |
| `public @_exported import Foundation` (reversed) | 1 | 1 |
| `@_implementationOnly import Foundation` | 1 | 1 |
| `@_spi(Internal) import Foundation` | 1 | 1 |
| `@preconcurrency @_exported import Foundation` | 1 | 1 |
| indented (inside `#if canImport`) | 1 | 1 |
| `#if canImport(Foundation)` itself | 0 | 0 |
| `internal import FoundationNetworking` | 1 | 1 |
| `@_exported public import FoundationXML` | 1 | 1 |
| `package import Foundation` | 1 | 1 |
| `@_exported public import Package_Primitives` | 0 | 0 |

### 20a — reproduced on the Lead's own file, with a nonzero control

`swift-standards/swift-spm-standard/Sources/SPM Standard/exports.swift`:

```
POSITIVE CONTROL (same pattern, module wildcarded): 5   <- nonzero, so the probe runs
   @_exported public import Package_Primitives
   @_exported public import URI_Standard
   @_exported public import URI_Standard_Library_Integration
   @_exported public import Version_Primitives
   @_exported public import Version_Primitives_Standard_Library_Integration
Foundation-family matches: 0   <- a TRUE zero
```

**The probe finds all five imports the Lead's pattern missed, and returns zero for
Foundation.** The control is nonzero on the same file with the same pattern, so
the zero is distinguishable from a blind one — which is precisely the property
the Lead's `struct`-returns-46 check established for theirs.

**Conclusion: no Foundation figure in this document is a lower bound on account
of this defect.** They remain measurements, with their stated timestamps.

### 20b — a note on the `1307` in CLAUDE.md

That figure is the **unverified prior**, not this lane's measurement. It has been
superseded twice here:

| | |
|---|---|
| `CLAUDE.md` prior (unverified) | 1307 core-target lines |
| This lane, 21:35 snapshot | 1330 core / **1320 genuine** |
| This lane, 22:55 re-run after measured drift | **1323 core / 1314 genuine, 38 packages** |

**CLAUDE.md should carry 1314 / 38 @ 22:55**, not 1307 — and per §17c it should
carry the timestamp with it.

### 20c — the pattern-shape observation, corroborated from this lane

The Lead's tally — *every probe failure in this fleet today has been a
pattern-shape failure, not a logic failure* — matches this lane exactly. Four
here, all shape:

1. `find … -not -path "*/.build*"` — a *filter*, not a prune: **timed out at 120 s
   and returned empty** (§0a). Twice more later, same cause.
2. `${PIPESTATUS[0]}` / piping into `tail` — **`BUILD EXIT: 0` for a RED build** (§18i).
3. `--include=*.swift` **glob-expanded by zsh** — `no matches found` from a grep
   that never ran (§18i).
4. `xargs` **argument-list overflow** — `command line cannot be assembled, too
   long`, hit while searching for `Lint.Rule.Configuration`.

**Not one was a reasoning error. All four were the shell or the pattern.** And
the Lead's diagnosis of the cause is right: the house conventions — space-separated
target directories (`Sources/SPM Standard/`) and umbrella `exports.swift` files —
manufacture these. **The style is the hazard**, which is why "be careful with
paths" never fires as a rule and a positive control does.

---

## Phase 21 — "run the rule, not grep": already done, and the answer changes the ratchet

The Lead ruled that ad-hoc Foundation greps be replaced by
`Lint.Rule.Foundation.Import`, on the premise that *"every ad-hoc Foundation
count in this fleet — mine included — is a lower bound against a rule that is
already strictly better."*

**That premise is testable, and this lane has already tested it.** §19 ran the
actual rule witness from `Lint.Rule.Bundle.institute`, post-`2beb8d8`, over the
whole ecosystem.

### 21a — the rule's own ecosystem count

```
| foundation import | shipped 2039 | maximal 4926 | pkgs(ship) 109 | pkgs(max) 234 |
```

**Measured by the rule itself, not by grep.** So the gating question the Lead
puts at the front of the queue — *"what does a real run report for that one
rule"* — is answered at ecosystem scale:

> **`Lint.Rule.Foundation.Import` reports 4,926 findings (2,039 in shipped
> packages, across 109 packages). It is the 8th-highest-firing rule of 92.**

### 21b — consequence: it is the WORST ratchet candidate, not the best

The Lead's reasoning — a rule with explicit tests for five evasion shapes,
hardened against a live specimen today, is the right profile to graduate first —
is sound **about the rule's quality** and inverted **about its readiness**. The
ratchet's precondition is an ecosystem count of zero. This rule's count is
**4,926**.

**Flipping it to `.error` would fail the build of 109 shipped packages
immediately.** It is not first in the queue; on the ratchet's own criterion it is
close to last. Rule quality and ratchet-readiness are independent properties, and
the 14 candidates in §19d are selected on the second.

### 21c — the lower-bound hypothesis, tested against this lane's probe

| Instrument | Shipped Foundation-family count |
|---|---|
| This lane's Python probe (grep-class, comment-stripping) | **2006** |
| `Lint.Rule.Foundation.Import` via the Swift rule engine | **2039** |
| Delta | **+33 (+1.6%)** |

**Two instruments sharing no code agree to 1.6%.** So for *this* probe the
lower-bound hypothesis is **refuted by direct measurement**, not by argument —
and §20 independently showed the pattern matches all five evasion shapes,
verified on the Lead's own `swift-spm-standard/exports.swift`.

The Lead's ruling remains right as **general guidance** — a hand-rolled regex is
the wrong default, and `-w import`-then-classify is the correct triage form. It
is wrong as a **claim about this lane's existing figures**, which were produced
by both instruments and agree.

### 21d — 2 of the Lead's 4 "main-target `Sources/` hits" are in NO target

All four appear in this lane's data, but not all in the bucket claimed:

| Hit | This lane's bucket |
|---|---|
| `swift-mailgun-types/…/Mailgun Types Shared/shared.swift:12` | **core** ✅ |
| `swift-server-foundation/…/ServerFoundation/exports.swift:24` | **core** ✅ |
| `swift-github-standard/…/GitHub Types Shared/exports.swift:2` | **UNDECLARED** |
| `swift-github-http/…/GitHub OAuth Live/exports.swift:8` | **UNDECLARED** |

`swift-github-http/Package.swift` mentions `GitHub OAuth Live` **zero times**
(`grep -c` → 0), exactly as `swift-github-standard` never declares
`GitHub Types Shared` (§Finding A). **Neither is a main target. Both are source
directories no target declares**, so they compile nowhere and reach no consumer.

`swift-github-http` is a **new instance** of the orphaned-directory disease, not
previously catalogued by name here — it now joins the 154/108 orphan set.

**This does not reduce the Lead's finding; it re-buckets it.** Two live
main-target `@_exported` re-exports is a real and serious result. Two more in
undeclared source is a different defect with a different fix — and "an umbrella
re-exporting Foundation to every consumer" is **false** of a target that has no
consumers because it has no target.

### 21e — the filename observation is right and generalises

The Lead notes `shared.swift` proves the umbrella is not always `exports.swift`,
so a filename-keyed probe misses it. **This lane's probe is not filename-keyed** —
it walks every `.swift` file under each target's directory — so it is unaffected.
Worth recording as a shape to avoid rather than a defect incurred.

Their degenerate control is the striking number: **3,472 `@_exported import`
lines ecosystem-wide.** The umbrella convention is pervasive, so a probe blind to
`@_exported` is blind to a large fraction of all coupling — which is the same
conclusion §10d reached from the in-degree side.

---

## Phase 22 — `eco-probe.sh`: a THIRD instrument, and it agrees

The Lead directed all Foundation counting through
`swift-institute/Scripts/eco-probe.sh`. **Verified before use, then used.**

### 22a — the instrument exists, and BOARD #22 is stale

BOARD #22 lists `eco-probe.sh` among instruments *"all deleted after the plans
that require them."* **It is present**: 719 lines, executable,
**mtime 2026-07-24 21:35:55** — today. Either restored today or never lost.
**BOARD #22's row needs correcting**, and this is a second instance of the
night's dominant error: *concluding absence from a failure to find.*

```
eco-probe.sh selftest  ->  9 passed, 0 failed
   PASS(fails-loud): manifests: implausible floor          [exit 2]
   PASS(fails-loud): manifests: missing org root           [exit 2]
   PASS(fails-loud): deps: parser blind spot               [exit 2]
   PASS(fails-loud): consumers: aggregate-edge floor       [exit 2]
   PASS(fails-loud): imports: zero source files            [exit 2]
   PASS(fails-loud): resolve: coenttb guard                [exit 2]
```

Six of the nine are controls that **must abort loudly** — the discipline this
lane arrived at independently (§2a, §19b), already shipped on 2026-07-14.

### 22b — ⭐ decisive cross-check: THREE instruments agree

`swift-urlrequest-handler`, scoped to `Sources`:

| Instrument | Foundation | FoundationNetworking | Total |
|---|---|---|---|
| This lane's Python probe (§8b) | 3 | 3 | **6** |
| `Lint.Rule.Foundation.Import` via the Swift engine (§19) | — | — | consistent |
| **`eco-probe.sh imports … Sources`** | **3** | **3** | **6** |

**Module-for-module identity.** Three instruments — a Python comment-stripping
scanner, the linter's own SwiftSyntax rule witness, and a 719-line shell probe
with abort-on-control-failure — produce the same answer on the same package.

The Lead's `swift-spm-standard` result also reproduces exactly: 5 modules across
63 files, all `@_exported public import`, **Foundation 0**.

**Conclusion: this lane's Foundation figures are corroborated by a third
independent instrument. They are measurements, not lower bounds.**

### 22c — population comparison, and a caution about the calibration figure

```
eco-probe.sh manifests  ->  476   (controls passed)
this lane               ->  481 shipped  (1415 including auxiliary)
```

Within 5. The residual is a **root-set difference, not a probe difference**:
eco-probe's output includes `swift-linux-foundation/swift-linux-standard`, a root
outside this lane's ruled 21-root scope, and its `manifests` primitive counts
top-level manifests only (476) rather than all depths (1415).

⚠️ **The Lead cited "census measured 450" as the calibration reference. Neither
instrument reports 450** — eco-probe says 476, this lane says 481. The `450`
should not be used as a cross-check constant until its scope is stated;
`ECO_MIN_MANIFESTS=400` is a *floor* for a control, not a measurement.

**And the inference "if your count is far from 450, the discrepancy is your
probe" does not hold** when the two populations are deliberately different. A
calibration constant is only a check against a *stated* scope.

### 22d — the Sources/Tests trap: already handled, and more strictly

The Lead warns that unscoped counting on `swift-spm-standard` yields
`Foundation 9`, all in **test** targets, and that CLAUDE.md now says the rule
governs main targets while the linter over-reports on tests — *"do not strip a
test-target import to satisfy it."*

**This lane never produced an unscoped Foundation count.** Every figure has been
bucketed **core / fi / test / undeclared** since §3b, and the headline (1314
genuine lines) excludes the 534 test-bucket lines by construction.

**This lane's scoping is strictly stronger than `Sources`-subpath scoping**, and
the difference is measurable: a target `path:` override can place a **regular**
target under `Tests/` — `swift-byte-primitives/Package.swift:111` does exactly
this (`path: "Tests/Support"` for the non-test target
`Byte Primitives Test Support`). A `Sources`-subpath probe misses that target
entirely; a declared-target probe does not.

**Both scopings are correct for their question. Neither should be quoted without
it** — the same conclusion §15 reached with the layering lane over orphan counts.

---

## Phase 23 — candidate confirmation, run 1 of 2: `swift-byte-primitives`

**Real `swift-build lint`, exit captured bare. The engine agrees with the census
on all five candidates.**

```
swift-build lint --package-path .../swift-byte-primitives
LINT EXIT (bare $?): 0
· 95 active rules · 31 files linted · 35 violations
```

### 23a — the five candidates: engine == census

| Candidate | Census | **Engine** |
|---|---|---|
| `uint8 conforms to byte protocol` | 0 | **0** |
| `byte conforms to arithmetic protocol` | 0 | **0** |
| `binary serializable uint8 witness` | 0 | **0** |
| `uint8 forwarder missing disfavored` | 0 | **0** |
| `typed throws cannot use self error` | 0 | **0** |

**Run against the densest possible site** — 292 `Byte`, 109 `UInt8`,
13 `@_disfavoredOverload`, and the ecosystem's only `throws(Self.Error)`. If
these rules fire anywhere, it is here.

### 23b — the controls, both directions

**Known-positive (the zeros are not a broken grep):** six *other* rules fired
35 violations in the same run, in the same `[rule id]` format the candidate check
matches:

```
16 [untyped throws] · 9 [counter loop iteration] · 6 [compound identifier]
 2 [int public parameter] · 1 [throwing wrapper init] · 1 [phantom suppression]
```

**Cross-instrument consistency:** every one of those six has a **nonzero
ecosystem count in the census** —

| Rule | Census shipped | Census maximal |
|---|---|---|
| untyped throws | 1826 | 3059 |
| counter loop iteration | 1171 | 1978 |
| compound identifier | 17308 | 38424 |
| int public parameter | 2561 | 4201 |
| throwing wrapper init | 224 | 481 |
| phantom suppression | 80 | 256 |

**Rules the engine fires here are rules the census also found firing elsewhere,
and rules the census found nowhere the engine also finds nowhere.** The two
instruments agree in both directions on this package.

**Rule-count reconciliation, exactly:** the engine reports **95 active rules**;
the census iterated `Lint.Rule.Bundle.institute` = **92**.
`swift-byte-primitives/Lint.swift:23` activates `Lint.Rule.Bundle.primitives`,
and `swift-primitives-linter-rules` declares **3** rules. **92 + 3 = 95.** No
residual.

### 23c — severity confirmed non-binding, end to end

**35 violations, `exit 0`.** The census's finding that all 92 rules are
`default: .warning` is confirmed by the engine's own exit status on a real
package. **A lint run cannot fail a build today.** That is #24's mechanism
observed directly rather than inferred.

### 23d — verdict on these five

**The engine and the census agree. Per the Lead's gate, these five are confirmed
as measured zeros and are the Lead's to flip.** The remaining two
(`sendable struct with class member`, `enumerated with subscript`) need the
`repotraffic-com-server` run, **held** — the repotraffic lane is live in that
package's `.build` and SwiftPM's lock waits indefinitely rather than failing.

**Caveat that survives the confirmation:** this validates the census *for these
five rules on this package*. It does not license flipping a rule whose census
zero has not been confirmed on a package where its subject matter is dense — the
selection method (§19f) is part of the evidence, not a convenience.

### 23e — coordinator interface correction

`swift-build package … lint` is **not valid** — `package` accepts only
`build, test, run, resolve, update, clean, reset, dump-package, get-mirror`
(`swift-build:1592`). **`lint` is a top-level mode**: `swift-build lint
--package-path <p>` (`swift-build:1617-1629`), with `--rebuild`, `--clean-eval`
and `--changed-since`. The first attempt failed with `invalid choice: 'lint'`
and **exit 2** — a loud failure, correctly captured bare.

---

## Phase 24 — run 2 VOID, substituted; all 7 candidates confirmed; prediction wrong as stated

### 24a — ⚠️ the `repotraffic-com-server` run is VOID, not a confirmation

```
swift-build lint --package-path .../repotraffic-com-server
LINT EXIT (bare $?): 0        log: 1 line, no summary, no findings
```

**Exit 0 with an empty log is not a measured zero here.** Diagnosed:
**`repotraffic-com-server` has no `Lint.swift` and no `Lint/` directory.** The
linter activated **no rules**, so it reported no findings.

Compare the byte-primitives run: 37-line log, `· 95 active rules · 31 files
linted · 35 violations`. This one: one line, the linter's own path.

**Had this been read as "engine agrees: 0 for both candidates", it would have
been a FALSE CONFIRMATION of two ratchet candidates on the strength of a run in
which the rules never executed.** It is the exact failure class this document has
been cataloguing all night, and it arrived at the last step, in the run designed
to prevent it.

**Status of the two candidates after this run: COULD NOT MEASURE.** Explicitly
not "measured zero".

### 24b — a finding worth more than the run it came from

**`repotraffic-com-server` — the live application and a priority-2 deliverable —
has no lint configuration at all.** No institute rule has ever run against it.

That reframes this document's repotraffic numbers: **277 core Foundation import
lines (§3f), 35 of the 176 FI-closure violations (§14c), 8 of the 15 direct
FI violations** — none of it has ever been seen by a lint gate, and none of it
could be, in the package's current state.

### 24c — substitute package, selected by the same density method

Requirement: has `Lint.swift` **and** dense in the two constructs.
`swift-async-primitives` tops both lists — **89 `@unchecked Sendable`,
18 `.enumerated()`** — so one run covers both remaining candidates at their
densest lint-configured site.

```
swift-build lint --package-path .../swift-async-primitives
LINT EXIT (bare $?): 0 · 95 active rules · 109 files linted · 279 violations
```

| Candidate | Census | **Engine** |
|---|---|---|
| `sendable struct with class member` | 0 | **0** |
| `enumerated with subscript` | 0 | **0** |

**Control:** 279 violations from other rules in the same run — `try optional` 54,
`compound identifier` 42, `counter loop iteration` 39, `single type per file` 29,
`do throws for typed catch` 25, `minimal type body` 23. The zeros are not a
silent run.

**All 7 selected candidates are now engine-confirmed.** 7 of 14; the other 7
remain unconfirmed and stay so until measured where their subject matter is dense.

### 24d — ⚠️ the pipeline prediction was WRONG AS STATED

Predicted: `swift-urlrequest-handler` returns **6** post-`2beb8d8`, against the
HTTP lane's pre-widening **3**.

```
LINT EXIT (bare $?): 0 · 92 active rules · 8 files linted · 77 violations
[foundation import] findings: 10
```

**Actual 10, not 6. The prediction as stated is falsified.** The breakdown:

| Scope | Findings |
|---|---|
| `Sources/` — DefaultRequestHandlerKey 2, DefaultSessionKey 2, Envelope 1, exports 1 | **6** |
| `Tests/` — ReadmeVerificationTests 2, URLRequestHandler Tests 2 | **4** |
| **Total** | **10** |

**I predicted the `Sources` figure and reported it as a total.** The engine lints
`Sources` *and* `Tests`; my census bucketed them separately and I quoted the core
bucket without saying so — the precise error §22d warns about, committed one
phase after writing the warning.

**The underlying claim is confirmed exactly.** Pre-widening the HTTP lane
measured 5 (3 `Sources` + 2 `Tests`, all plain `Foundation`). Post-widening: 10
(6 + 4). **Delta = +5, exactly the five `FoundationNetworking` lines** — 3 in
`Sources`, 2 in `Tests`. `2beb8d8` took, precisely as designed, and the `Sources`
figure is **6**, matching this lane's core count for that package to the line.

**Recorded as a wrong prediction rather than a rescued one.** The scope error is
mine; that the mechanism it was testing is confirmed does not make the stated
number right. A prediction that needs its scope restated after the fact was
under-specified when made.

### 24e — rule-count reconciliation holds across all three runs

| Package | Active rules | Bundle activated |
|---|---|---|
| `swift-byte-primitives` | 95 | `Bundle.primitives` (92 institute + 3 primitives-tier) |
| `swift-async-primitives` | 95 | `Bundle.primitives` |
| `swift-urlrequest-handler` | **92** | `Bundle.institute` |

**92 and 95 both reconcile exactly**, and the difference is visible in each
package's `Lint.swift`. No residual anywhere.

---

## Phase 25 — the BOARD #22 exchange: both accounts were imprecise, and the git log settles it

The Lead retracted my Correction 1, stating that #22 *"does not list `eco-probe.sh`
among instruments 'all deleted'"* and that item (a) has recorded the restoration
*"since it happened"* — concluding **"the row was not wrong and I should not have
said it was."**

**Checked against git rather than accepted.**

### 25a — what the row actually said, and when

```
$ git log -S'eco-probe.sh` RESTORED' -- BOARD.md
48bbf088  21:43:29      <- first appearance of "RESTORED" in row 22
```

Row 22 at `8cdfc4a8`, the version live when this lane read `BOARD.md` at session
start (~21:2x), **verbatim and in full**:

> `| 22 | **Instrument rot** — gate.sh, eco-probe.sh, edit-all/unedit-all/edit-status, check-memory-corpus.sh all deleted after the plans that require them. Sizings quoted in the backlog are un-re-derivable. Restore or formally retire each. | open |`

**No item (a). No "RESTORED". State: `open`.** The row said exactly what this lane
reported it said.

### 25b — but the defect is still this lane's, and it is a different one

The restoration was recorded at **21:43:29**. This lane did not *report* the row
as stale until after running `eco-probe selftest`, around **23:5x–00:0x** —
**roughly two hours after the row had been corrected.**

**So: the belief was correctly formed from the live row; the report was issued
from a two-hour-old read of a file that had changed.** The row was not stale.
**The read was.**

**That is this lane's own rule, unapplied to itself.** §17c states: *"a census of
a live workspace is a measurement with a timestamp, not a fact."* This lane
applied that discipline to 481 manifests, re-ran when three moved, and revised a
headline — and then quoted a durable file from memory without re-opening it.

### 25c — the symmetry is the finding

| | Held | Treated as | Should have |
|---|---|---|---|
| **This lane** | a 2-hour-old read of `BOARD.md` | current | re-read before reporting |
| **The Lead** | this lane's report | verified | opened the row before agreeing |

**Two instances of the same failure, in opposite directions, inside one
exchange** — and the second was caused by the first. The Lead's framing is right
that the remedy must run both ways: *lanes re-measure the lead's figures* is only
half a rule if leads accept lanes' reports unread.

**And the Lead's retraction is itself imprecise in the other direction.** "The row
was not wrong and I should not have said it was" is true of the row *at the time
of the report* and false of the row *at the time of the read*. The accurate
statement is narrower: **the row had been corrected two hours before it was
reported stale, and the report was issued from a stale read.**

This is the third time tonight a correction has needed the same scrutiny as the
claim it replaced (cf. §14, §21) — and the first where the correction and the
original were **both** imprecise and the artifact settled it.

### 25d — what stands

The readability fix is real and worth having regardless of who was wrong: **a
status row must not open with a state that no longer holds.** The rewritten #22
now leads with the live state and marks the deletion list HISTORY. Nothing in the
census's numbers depends on any of this.

---

## Phase 26 — the unconfigured-package census: every violation total is a floor

Prompted by the void `repotraffic` run (§24a). If a package declares no lint
configuration, **it contributes zero findings regardless of content** — so every
ecosystem-wide violation figure in this document, and in the per-rule census, is
a floor by whatever fraction of source lives in unconfigured packages. **Nobody
had measured that fraction.**

"Configured" = the package root has `Lint.swift` **or** a `Lint/` directory (the
two forms the swift-linter skill documents).

### 26a — result

| Population | Packages | Configured | **Unconfigured** | |
|---|---|---|---|---|
| **Shipped (depth-1)** | 481 | 468 | **13 (2.7%)** | |
| All (incl. auxiliary) | 1102 | 472 | 630 (57.2%) | |

**But package count understates it, because the unconfigured shipped packages are
disproportionately large:**

| Shipped population | Total | In unconfigured packages | **Floor** |
|---|---|---|---|
| `.swift` files | 16,549 | 898 | **5.4%** |
| lines | 1,518,206 | 110,590 | **7.3%** |

⇒ **Every ecosystem-wide lint total for shipped packages is a floor by ~7.3% of
source lines.** 2.7% of packages, but 7.3% of the code.

**Controls (both directions):**

```
known-configured   swift-byte-primitives   -> True
known-unconfigured repotraffic-com-server  -> False
```

### 26b — the 13 unconfigured shipped packages

| Package | Files | Lines |
|---|---|---|
| `repotraffic/repotraffic-com-server` | 454 | **48,968** |
| `swift-foundations/swift-authentication` | 237 | **32,207** |
| `swift-foundations/swift-certificates-n5` | 77 | **20,340** |
| `swift-foundry/swift-control-plane` | 72 | 5,375 |
| `swift-foundations/swift-sql-postgres-provider` | 9 | 1,086 |
| `swift-foundations/boiler` | 14 | 976 |
| `swift-foundations/swift-sql-postgres-native` | 8 | 783 |
| `swift-ietf/swift-rfc-8288` | 9 | 383 |
| `swift-components/swift-server-static` | 11 | 324 |
| `swift-foundry/foundry` · `control` | 6 | 147 |
| `swift-institute/swift-institute.org` · `Issues` | 1 | 1 |
| **Total** | **898** | **110,590** |

**Three packages are 92% of the unlinted surface** — repotraffic (48,968),
swift-authentication (32,207), swift-certificates-n5 (20,340) = 101,515 of
110,590 lines.

**Cross-reference to this document's own findings, and it is not a coincidence:**

- `repotraffic-com-server` — **277** core Foundation lines (§3f), **35** of 176
  FI-closure violations, **8** of 15 direct FI violations.
- `swift-authentication` — **137** core Foundation lines, 3rd-largest in the
  ecosystem (§3f); **6** FI-closure violations (§14c).
- `swift-certificates-n5` — 6 core Foundation lines at the 21:35 snapshot, driven
  to **0** during the session (§17b).

**The three largest unlinted packages are also among the largest Foundation
violators.** That is the mechanism visible directly: **nothing was ever going to
tell them.** It is not that these packages were audited and failed; they were
never audited at all.

### 26c — what this bounds, precisely

- **Bounded (measured):** the *lint-derived* totals — the per-rule census's
  136,575 / 60,628 findings, and any `swift-build lint` result — are floors by
  the 7.3% of shipped lines that no configuration covers.
- **NOT bounded:** this document's **Foundation and layering figures**. Those were
  produced by direct source scanning (`census.py`, `graph.py`, `ficlosure.py`) and
  by `eco-probe`, none of which consult `Lint.swift`. **They already cover
  unconfigured packages** — which is exactly why §3f could report repotraffic's
  277 lines that no gate has ever seen.

**That distinction is the point.** A source census and a lint census answer
different questions, and the lint census has a blind spot the source census does
not. **Where they disagree, the lint census is the one that is low.**

### 26d — the auxiliary figure needs its population stated

The 630/1102 all-packages figure is **not** comparable to the shipped one: most
auxiliary packages (`Experiments/`, `Benchmarks/`, nested `Tests/`) legitimately
carry no lint configuration, so a high unconfigured rate there is expected rather
than a defect.

Its population also differs from §19a's 1415: **this walk excludes hidden
directories from descent**, so the `.swift-lint/eval` and `.swift-manifest/`
packages (§4d) are not counted. **Stated rather than reconciled**, since the
shipped figure is the one that bounds anything.

---

## Phase 27 — can lint run without `Lint.swift`? NO — and it corrects §26c

### 27a — the answer is no, and it is structural

**`swift-build lint` offers no bundle or config override.** Its full flag set
(`swift-build:1617-1629`) is `--package-path`, `--timeout-seconds`, `--rebuild`,
`--clean-eval`, `--changed-since`. None supplies rules.

**The coordinator does not decide this.** It invokes the dispatcher regardless of
whether `Lint.swift` exists (`:1192-1240`); the manifest is used only for
fingerprinting the cached eval project. (That is also where the
`.swift-lint/eval` packages of §4d come from.)

**The linter itself has no path in.** No env vars, no CLI flags — and the reason
is architectural, not an omission: `Lint.run.swift:247` documents the entry point
as *"Run the linter from a single-file `Lint.swift` consumer manifest"*, and
`Lint.File.Single.swift:45` shows the mechanism — **the consumer's `Lint.swift`
becomes the eval target's `main.swift` and is compiled and run.**

⇒ **`Lint.swift` is not configuration; it is the program.** It *contains*
`Lint.run(dependencies:) { Lint.Rule.Bundle.institute }`. A package without one
has no program to run, so there is nothing for a flag to override.

**This is a genuine tooling gap, and it is the shape the Lead predicted for the
"no" branch: the linter cannot be used to evaluate the packages that most need
evaluating.** It joins the void-run finding (§24a) as a second way a lint run
tells you nothing while exiting 0 — and the two compound: an unconfigured package
both *reports* nothing and *cannot be made* to report anything short of an
engineering change.

### 27b — but the workaround already exists, and this lane built it by accident

**`Census/` is exactly the missing capability.** It iterates
`Lint.Rule.Bundle.institute` and runs the rule witnesses over arbitrary
directories, keyed on `Package.swift` alone — **it never consults `Lint.swift`.**

So the 110,590 unlinted lines **can** be measured with the real rule witnesses
today, without modifying a single package. **The daylight task the Lead boarded
("configure and see") can be run as "measure, then configure knowingly" using the
harness already sitting in `swift-institute-linter-rules/Census/`.**

### 27c — ⚠️ CORRECTION to §26c, against this lane's own reported result

§26c stated that lint-derived totals *"including the per-rule census's 136,575 /
60,628 findings"* are floors bounded by the 7.3% unconfigured fraction.

**That is wrong for the per-rule census.** It scanned **all 1,415 packages found
by walking the roots**, keyed on `Package.swift` — which necessarily **includes
all 13 unconfigured shipped packages**, repotraffic and `swift-authentication`
among them.

**Corrected scope of the 7.3% floor:**

| Figure | Bounded by the unconfigured fraction? |
|---|---|
| Actual `swift-build lint` runs (any package, any gate, CI) | **YES — floor** |
| The per-rule census (§19), 136,575 / 60,628 | **NO — already covers unconfigured packages** |
| Foundation / layering figures (§9, §14, §22) | **NO — direct source scan** |

**So the 7.3% floor applies to what the *gates* see, not to what this document
measured.** That is a narrower and more useful claim: **the gap is between what
the fleet's lint infrastructure can observe and what the code actually contains**
— 110,590 lines wide — and this document's numbers sit on the far side of it.

**Consequence for the ratchet, also corrected:** I told the Lead the 14 candidates
were weakened because a rule might read zero over source invisible to it.
**That was wrong for the same reason** — the census saw those packages. The
candidates are weakened only by the ordinary caveats (§19e) and the fact that
7 of 14 remain unconfirmed by the engine. **The extra doubt I volunteered does not
apply, and withdrawing it is as much an obligation as raising it was.**

---

# FINAL STATE — layering census lane, 2026-07-25 ~00:20

**Everything below is in this file. Nothing load-bearing exists only in a
transcript.** Every figure carries its timestamp; a census of a live workspace is
a measurement with a timestamp, not a fact (§17c).

## Measured

| # | Figure | Value | Status |
|---|---|---|---|
| 24 | genuine core-target Foundation debt | **38 packages / 1,314 lines** @22:55 | measured |
| 24 | misnamed-FI (legitimised by rename) | 8 pkg / 10 lines — 7 mechanical, `FoundationExtensions` open | measured |
| 24 | test bucket | 534 lines | **FLOOR** |
| 24 | undeclared source | 149 lines | measured |
| 24 | sanctioned FI targets | 29 lines | not debt |
| 25 | upward layer edges | **14 raw / 2 post-ruling** | measured, agreed with layering lane |
| 25 | same-layer graph | 1,470 edges, 431 nodes, **0 cycles** | measured, control-verified |
| 007 | FI-dependency closure | **176 core targets / 15 direct** | measured |
| — | per-rule corpus census | 92 rules · 136,575 maximal / 60,628 shipped · **14 zero** | measured |
| — | engine-confirmed candidates | **7 of 14** at dense sites | measured |
| — | unlinted shipped source | **13 pkgs / 110,590 lines / 7.3%** | measured |
| — | `Lint.Rule.Foundation.Import` | **4,926 maximal / 2,039 shipped** — NOT a ratchet candidate | measured |

## Not measured — and none of it may be read as zero

- **`@_exported` re-export residue** in the FI closure — needs the compiler.
- **Test-bucket totals** — 22 computed test-target names unresolved.
- **7 of 14 ratchet candidates** — unconfirmed by the engine.
- **Symbol-level use** of `ISO_14496_22` / `W3C_PNG` — manifest edge and import
  site measured; *use* not.
- **Seven unversioned packages** — **could not reproduce**, explicitly not zero.
- **Remote existence** of the 24 local-only L4 directories.

## Blocked / open for the Lead

- **Foundation ratchet blocked** — 1,314 main-target lines. Retraction stands.
- **7 candidates confirmed, the Lead's to flip.** Nothing changed severity here.
- **`FoundationExtensions`** needs a deliberate name (fails the suffix predicate).
- **Three `swift-*-foundation` packages** — is the integration target the whole
  package? Open by design, not closed by the rename.
- **`repotraffic` has no lint configuration** — its gate's lint axis must record
  **COULD NOT MEASURE**.
- **Tooling gap (§27a):** no way to run a bundle against an unconfigured package.
  **Workaround: `Census/`** — it keys on `Package.swift`, never `Lint.swift`.

## Artifacts

- **This file** — the whole census, written incrementally throughout.
- **`swift-institute-linter-rules/Census/`** — retained at the Lead's instruction
  until the ratchet closes. **3 files; the repo's `git status --porcelain` is
  empty** (`.gitignore:14` covers it); parent manifest undiffed.
- Scratch probes (`census.py`, `graph.py`, `ficlosure.py`) are session-local.
  **`Census/` is the durable one**, and it subsumes their rule-level capability.

## The methodological result, if only one line survives

**Every probe failure in this lane tonight was pattern shape, never logic** — a
non-pruning `find` (three times), a piped exit status, a zsh glob, an `xargs`
overflow — **and every one failed toward "clean".** The defences that worked were
two-sided controls: a known-positive that must fire *and* a known-negative that
must not. **The one measurement that shipped without both was wrong by 5×**
(§14e). The one that had a cross-instrument oracle was right to 1.6% (§19b).
