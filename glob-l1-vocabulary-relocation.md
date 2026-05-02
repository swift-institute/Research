---
date: 2026-05-02
session_objective: Research scoping for Item 3.5 — analyze whether the Kernel.Glob vocabulary's current placement is correct under [PLAT-ARCH-005] L2-canonical-where-spec-layer-exists, and if not, recommend a relocation direction
packages:
  - swift-iso-9945
  - swift-posix
  - swift-foundations/swift-windows
  - swift-microsoft/swift-windows-32 (precedent only, not a Glob consumer)
  - swift-foundations/swift-file-system (transitive consumer)
status: closed
closure_date: 2026-05-02
closure_disposition: Option B (L1 relocation) — accepted by principal; relocation cycle dispatched and executed same day
---

## Closure Note (2026-05-02)

Principal disposed all 5 sub-questions per Option B (L1 relocation):
- Q1: Premise inversion confirmed (Glob was at L2, not L1; question reframed as L2→L1)
- Q2: Option B chosen
- Q3: Top-level `Glob.*` namespace (NOT `Kernel.Glob.*`)
- Q4: Package name `swift-glob-primitives`
- Q5: L3-unifier `Kernel.Glob.match` cross-platform API DEFERRED (separate cycle)

Relocation cycle executed on 2026-05-02 (same day as research):

| Phase | Repo | Commit | Subject |
|---|---|---|---|
| 1 | swift-glob-primitives | initial commit (new repo) | L1 package creation; 14 vocabulary files relocated from `ISO 9945 Glob` |
| 2 | swift-iso-9945 | (current branch HEAD) | Vocabulary files removed; libc Fnmatch/Expand retained at L2 |
| 3 (POSIX) | swift-posix | `97de148` | L3 + tests + Package.swift rewired to L1 |
| 3 (Windows) | swift-windows | `45c9d04` | L3 + Package.swift rewired; **swift-iso-9945 dep dropped entirely** — cross-platform asymmetry eliminated |
| 5 (audit) | swift-institute/Audits | (current branch HEAD) | Item 3.5 entry RESOLVED |

Build verification: all affected packages GREEN on macOS sources-only (`swift build` per package, [SUPER-009a]). swift-file-system cascade has pre-existing Path-ambiguity errors from Item 1.5's parallel edit zones — explicitly carved out per ground rule #4; not introduced by this cycle.

Closes Wave 4a-Glob commit `b223efb`'s explicit roadmap reference: *"Item 3.5 (Glob L1 vocabulary relocation) is the future-cycle architectural symmetry pass that would eliminate this asymmetry by moving the vocabulary to L1."* — done.

---


# Glob L1 Vocabulary Relocation — Research

## Primary Finding (PREMISE INVERSION)

**The dispatch's premise is empirically inverted.** The dispatch frames Item 3.5 as: *"the underlying Glob vocabulary at L1 (its current placement) is correct under [PLAT-ARCH-005], or whether it should relocate to L2 (iso-9945)"*. The actual current state is the opposite:

> **The Kernel.Glob vocabulary already lives at L2 (`swift-iso-9945` `ISO 9945 Glob` target), not at L1.** No `Kernel Glob Primitives` package exists at L1 in the current workspace state — the build artifacts (`Kernel_Glob_Primitives.build` directories under `.build*/`) are stale leftovers from before a prior relocation cycle.

Wave 4a-Glob commits `bff2cca` (swift-windows-32) + `b223efb` (swift-windows) closed a [PLAT-ARCH-008j] WinSDK violation by switching `Windows.Kernel.Glob.Match.swift` from `extension Windows.Kernel.Glob` (an undeclared phantom namespace) → `extension ISO_9945.Kernel.Glob` (the canonical L2 vocabulary that swift-posix L3 also extends). The `b223efb` commit message explicitly notes the inverse direction as the open architectural question:

> *"Cross-platform asymmetry: swift-windows now depends on swift-iso-9945 (POSIX-named package) for Glob vocabulary. Justified per content (the iso-9945 ISO 9945 Glob target is platform-agnostic vocabulary by content; only the POSIX-spec wrappers ISO_9945.Glob.{Fnmatch, Expand} are POSIX-runtime-bound). **Item 3.5 (Glob L1 vocabulary relocation) is the future-cycle architectural symmetry pass that would eliminate this asymmetry by moving the vocabulary to L1.**"*

**Reframed Item 3.5 question** (stated to match observed state):

> The `Kernel.Glob` vocabulary currently lives at L2 inside `swift-iso-9945` despite being **platform-agnostic by content**. Should it stay there (accepting the cross-platform asymmetry that swift-windows depends on a POSIX-named package), relocate **to L1** as a new primitives package (eliminating the asymmetry), or relocate to a **new L2 spec package** (capturing glob's quasi-spec-authority status without binding it to POSIX)?

The remaining sections analyze the corrected question. Per [SUPER-002] ground rule #6, this premise inversion is surfaced rather than silently corrected.

---

## (a) Current Glob Vocabulary Placement + Dependency Graph

### Owner: `swift-iso-9945` `ISO 9945 Glob` target (L2)

Located at `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Glob/`. Contents:

**Vocabulary (`ISO_9945.Kernel.Glob.*` namespace — 13 files):**

| Type | File | Role |
|---|---|---|
| `Glob` (enum namespace) | `Kernel.Glob.swift` | Root namespace + `isPattern(_:)` static helper |
| `Glob.Pattern` | `Kernel.Glob.Pattern.swift` | Compiled pattern (raw string + segments + isRecursive) — has init(String) parser |
| `Glob.Segment` | `Kernel.Glob.Segment.swift` | Path-segment unit: `.literal`, `.pattern(atoms)`, `.doubleStar` |
| `Glob.Atom` | `Kernel.Glob.Atom.swift` | Pattern atom: `.literal`, `.star`, `.question`, `.scalar(class)` |
| `Glob.Scalar`, `.Scalar.Class` | `Kernel.Glob.Scalar*.swift` | Character-class encoding (negated + ranges + scalars) |
| `Glob.Options` (+ nested) | `Kernel.Glob.Options*.swift` | Options OptionSet + nested `Dotfile` / `Error` / `Ordering` policy enums |
| `Glob.Error` (+ nested) | `Kernel.Glob.Error*.swift` | Error enum + nested `IO` / `Parse` errors |

**POSIX-spec libc wrappers (`ISO_9945.Glob.*` namespace — 4 files):**

| Type | File | Role |
|---|---|---|
| `Glob` (top-level enum namespace) | `ISO 9945.Glob.swift` | Top-level POSIX glob namespace |
| `Glob.Fnmatch` + `.Fnmatch.Options` | `ISO 9945.Glob.Fnmatch*.swift` | POSIX `fnmatch(3)` libc wrapper |
| `Glob.Expand` + `.Expand.Options` | `ISO 9945.Glob.Expand*.swift` | POSIX `glob(3)` libc wrapper |

The two namespaces (`ISO_9945.Kernel.Glob` for vocabulary vs `ISO_9945.Glob` for libc wrappers) are **architecturally distinct**. The Kernel-namespaced types are the *grammar / vocabulary* used cross-platform; the top-level-namespaced types are *POSIX libc bindings* that route through `CISO9945Shim` to the host's `fnmatch(3)` / `glob(3)`.

### Vocabulary's L1 dependencies (verified):

`Kernel.Glob.Pattern.swift`: `import ASCII_Primitives` only.
`Kernel.Glob.swift` namespace anchor: `public import ASCII_Primitives` only.

**No L2/L3 dependencies. No POSIX-specific dependencies. No platform conditionals.** The vocabulary is L1-shaped by content.

### L3 consumers extending `ISO_9945.Kernel.Glob`:

| File | Layer | Behavior |
|---|---|---|
| `swift-foundations/swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift` | L3-policy POSIX | Adds `match(pattern:in:options:body:)` — directory traversal + atom-level matching using POSIX directory APIs |
| `swift-foundations/swift-windows/Sources/Windows Kernel/Windows.Kernel.Glob.Match.swift` | L3-policy Windows | Adds same `match(...)` shape — directory traversal using typed L2 `Windows.\`32\`.Kernel.File.Find` (post Wave 4a-Glob `b223efb`) |

Both L3 sites extend the SAME L2 type (`ISO_9945.Kernel.Glob`). This is the cross-platform asymmetry: a Windows-specific implementation file extends a POSIX-named-package type because the vocabulary happens to live in the POSIX package.

### Dep graph (current state):

```
                              ┌─────────────────────────────────────┐
                              │   swift-iso-9945 (L2 POSIX)         │
                              │   ┌─────────────────────────────┐   │
                              │   │  ISO 9945 Glob target       │   │
                              │   │   • Kernel.Glob.* (vocab)   │   │
                              │   │   • ISO_9945.Glob.* (libc)  │   │
                              │   └─────────────────────────────┘   │
                              └─────────────────────────────────────┘
                                 ▲                  ▲
                                 │                  │
                  ┌──────────────┴────┐    ┌────────┴──────────────┐
                  │ swift-posix L3    │    │ swift-windows L3      │
                  │   POSIX Kernel    │    │   Windows Kernel      │
                  │   Glob/Match      │    │   Glob.Match          │
                  └───────────────────┘    └───────────────────────┘
                                              ▲
                                              │
                                ⚠ swift-windows imports from
                                  swift-iso-9945 (POSIX-named pkg)
                                  for platform-agnostic vocabulary —
                                  THE ASYMMETRY
```

---

## (b) [PLAT-ARCH-005] Applicability Question

### The rule

[PLAT-ARCH-005] L2-canonical-where-spec-layer-exists: *spec-bound types belong at the L2 spec package; L3-policy collapses to typealiases when the spec layer exists.*

### The applicability question

Does the rule apply to `Kernel.Glob.{Pattern, Segment, Atom, Options, Error, Scalar.Class}`? The rule applies if and only if those types are **spec-bound to POSIX**. Three lines of evidence:

**1. Stated namespace doc (`Kernel.Glob.swift`):**

> *"Glob pattern matching primitives. Defines the canonical contract for glob pattern matching across platforms. Platform packages (POSIX, Windows) provide implementations."*

By stated intent, this vocabulary is the **cross-platform contract**, not the POSIX-spec form. POSIX/Windows are explicitly named as consumers, not as authoritative spec sources.

**2. Grammar coverage:**

| Feature | POSIX glob spec | Bash extension | Other |
|---|---|---|---|
| `*`, `?` | ✓ POSIX | ✓ | ubiquitous |
| `[abc]`, `[!abc]`, `[^abc]` (`!` is POSIX, `^` is Bash) | partial | `^` is Bash | mixed |
| `**` (recursive) | ✗ | ✓ Bash 4+ globstar | many |
| `\` escape | ✓ POSIX | ✓ | mixed |
| `/` as canonical separator on all platforms | n/a | n/a | **decision** |
| Brace expansion `{a,b}` | ✗ — explicitly excluded | ✓ Bash | many |

The implemented grammar is a **policy choice** that includes Bash's `**` extension and excludes Bash's `{a,b}` expansion. The doc explicitly says *"Brace expansion `{a,b,c}` is shell policy, not glob core. Pre-expand patterns at a higher layer if needed."* This is **not** POSIX 1003.1 fnmatch/glob semantics — it's a derived cross-platform grammar.

**3. The `feedback_authority_not_platform` rule (memory file, source: 2026-04 FNM_CASEFOLD episode):**

> *"L2 packages are named after the spec authority that defines the API contract (IEEE 1003.1, BSD, GNU), not platforms where it compiles. Three distinct questions: (1) Who standardized it? (2) Where is it available? (3) Where should it live architecturally?"*

For `Kernel.Glob.Pattern`: **(1) Who standardized it?** — *no single authority.* Mixed POSIX + Bash + cross-platform policy. **(2) Where is it available?** — *anywhere Swift compiles.* **(3) Where should it live architecturally?** — *whichever package matches its actual content.*

There is no "authority" answer here. POSIX defined `*` and `?` and `[]` and `\`, but it didn't define `**` (Bash extension) or canonical-`/`-separator-on-Windows (cross-platform policy). The `Kernel.Glob.Pattern` shape isn't POSIX-spec-bound; it's an internally-authored cross-platform vocabulary that happens to be named in a POSIX-themed package.

### Verdict on [PLAT-ARCH-005] applicability

**The rule does NOT apply to the `Kernel.Glob.*` vocabulary** — it is not spec-bound to POSIX. The rule **DOES apply** to `ISO_9945.Glob.{Fnmatch, Expand}` — these ARE POSIX libc wrappers and correctly belong at L2 iso-9945.

Current placement violates the spirit of [PLAT-ARCH-005] indirectly: by living in a spec-authority-named package without being spec-authority-bound, the vocabulary forces non-POSIX consumers (swift-windows) to import a POSIX-named package, communicating an architectural claim ("this depends on POSIX") that doesn't match content reality.

---

## (c) Consumer Cascade Inventory

Workspace-wide grep for `ISO_9945.Kernel.Glob`, `ISO_9945_Glob`, `Kernel.Glob` (excluding `.build*`):

| Site | Layer | Role | Consumer-side cost of relocation |
|---|---|---|---|
| `swift-iso-9945` `ISO 9945 Glob/` (13 vocab files) | L2 owner | Move to new home | Files relocate; namespace `ISO_9945.Kernel.Glob` → new namespace |
| `swift-iso-9945` `ISO 9945 Glob/ ISO 9945.Glob.{Fnmatch,Expand}*.swift` (4 libc files) | L2 (correctly) | Stay at L2; possibly extend new vocabulary | Imports + namespace touchups |
| `swift-iso-9945` `ISO 9945 Kernel Tests/ISO 9945.Glob Tests.swift` | L2 tests | Stay or move with vocabulary | Imports + name updates |
| `swift-foundations/swift-posix` `POSIX Kernel Glob/Kernel.Glob+Match.swift` | L3-policy POSIX | Re-target extension to new vocabulary namespace | Import + extension target rename |
| `swift-foundations/swift-posix` `Tests/POSIX Kernel Tests/POSIX.Kernel.Glob Tests.swift` | L3 tests | Imports update | Imports |
| `swift-foundations/swift-posix` `Tests/Support/Kernel.Glob.Test.Helpers.swift` | L3 test support | Imports update | Imports |
| `swift-foundations/swift-windows` `Windows Kernel/Windows.Kernel.Glob.Match.swift` | L3-policy Windows | Re-target extension; **drop swift-iso-9945 dep** (the asymmetry-resolution win) | Import + extension target rename + Package.swift dep delete |
| `swift-foundations/swift-windows` `Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift` | L3 tests | Imports update | Imports |
| `swift-foundations/swift-file-system` `File System/File.Directory.Glob*.swift` (4 files) | L3 (Foundations) | Imports `Kernel` (umbrella) only — **transitive consumer**, no direct rewire needed | None — change is invisible at this layer |
| `swift-foundations/swift-file-system` `Tests/File System Tests/File.Directory.Glob Tests.swift` | L3 tests | Same — transitive only | None |

**Total cascade inventory:**
- **Direct consumer files**: 11 (vocab owner + 6 L3 consumer files + 4 test files)
- **Transitive consumer files** via `Kernel` umbrella: 5 (no direct rewire)
- **Package.swift updates**: 3 (swift-iso-9945, swift-posix, swift-windows) + 1 if a new package created
- **Test impact**: All passes through if extension targets + imports update correctly (no API break — same types, new namespace)

**Scope verdict**: small + bounded. Well below the >20-consumer-file threshold from [SUPER-002] ground rule #7. No breaking API changes if the new namespace is symmetric with the old one (same nested type tree). All swift-file-system consumers see the change transparently.

---

## (d) Cross-Platform Constraints

### The POSIX glob/fnmatch surface (`ISO_9945.Glob.{Fnmatch, Expand}`)

POSIX `fnmatch(3)` and `glob(3)` are libc functions on Unix/Darwin/Linux. Bound to libc; correctly placed at L2 swift-iso-9945. Wave 4a-Glob's L3-policy POSIX `Kernel.Glob+Match.swift` does NOT delegate to libc fnmatch — it implements the matching algorithm itself in Swift, using directory traversal via L2 typed forms. (The libc fnmatch is available separately at `ISO_9945.Glob.Fnmatch.match(...)` for callers who want POSIX-strict semantics.)

### The Win32 file-find surface (`Windows.\`32\`.Kernel.File.Find`)

Win32 `FindFirstFileW` / `FindNextFileW` / `FindClose` are the native file-iteration primitives. They take a path with embedded glob-like wildcards (`*` and `?`) and yield matches via a `WIN32_FIND_DATAW` cursor. Wave 4a-Glob commit `bff2cca` introduced the typed L2 surface `Windows.\`32\`.Kernel.File.Find` (Handle ~Copyable + Entry + Error + pathExists) wrapping these. The Win32 primitives understand their own (POSIX-incompatible) wildcards: `*` matches anything, `?` is single character, `.` is special when adjacent to `*`, no `[...]` classes, no `**` recursion. The L3-policy Windows match implementation uses the typed L2 file-find primitives for **directory traversal only** — it pre-compiles the cross-platform `Kernel.Glob.Pattern` into segments, then uses `Find` to walk one directory level at a time, doing the cross-platform pattern matching itself in Swift (not delegating to Win32's native wildcards).

### Architectural relationship

| Level | POSIX side | Windows side | Cross-platform layer |
|---|---|---|---|
| Native syscall wrappers (L2) | `ISO_9945.Glob.{Fnmatch, Expand}` (libc bindings) | `Windows.\`32\`.Kernel.File.Find` (Win32 bindings) | n/a — they're each platform-specific |
| Cross-platform pattern grammar | (uses L1 vocabulary) | (uses L1 vocabulary) | **`Kernel.Glob.Pattern`** etc. — currently misplaced at swift-iso-9945 L2 |
| L3-policy match algorithm | swift-posix `Kernel.Glob+Match` | swift-windows `Windows.Kernel.Glob.Match` | extension on shared L2 vocab |
| L3-unifier surface | (none yet?) | (none yet?) | `Kernel.Glob.match` could land at swift-kernel L3-unifier as cross-platform entry point |

**Architectural relationship is NOT a tension** — POSIX `fnmatch(3)` and Win32 `FindFirstFileW` are unrelated primitives. The cross-platform `Kernel.Glob.Pattern` vocabulary is what unifies the two: it's neither POSIX nor Win32, it's the workspace's own definition of "what does a glob pattern look like across platforms".

---

## (e) Recommended Relocation Direction(s)

### Option A — Status quo + documentation only

Keep the vocabulary at `swift-iso-9945/Sources/ISO 9945 Glob/`. Document the rationale at the namespace anchor (`Kernel.Glob.swift`) explicitly: *"this vocabulary lives in swift-iso-9945 for historical reasons; by content it is platform-agnostic and consumed by both POSIX and Windows L3-policy packages."*

| Pros | Cons |
|---|---|
| Zero code churn | Cross-platform asymmetry persists (swift-windows depends on swift-iso-9945) |
| No new packages | Violates [PLAT-ARCH-005] in spirit (POSIX-named package owns non-POSIX vocabulary) |
| Lowest risk | Future contributors will keep asking "why does Windows depend on iso-9945?" |
| | The `feedback_authority_not_platform` rule's spirit not honored |

**Cost**: ~10 LOC documentation update at one file. **Verdict**: defensible but architecturally unsatisfying.

### Option B — Relocate vocabulary to a NEW L1 package (RECOMMENDED)

Create `swift-glob-primitives` at `swift-primitives/swift-glob-primitives/` (per Tier 8 / Domain Primitives slot) with:

- **New namespace**: `Glob.{Pattern, Segment, Atom, Options, Error, Scalar.Class}` (top-level under `Glob`, NOT under `Kernel.Glob`)
- **L1-conformant deps**: `ASCII_Primitives` only (already verified — current L2 form has no other deps)
- **Tests**: relocate from swift-iso-9945 self-tests
- **Consumer cascade**: ~25 import statement updates across swift-iso-9945 + swift-posix + swift-windows + 4 Package.swift files

The L2 swift-iso-9945 keeps `ISO_9945.Glob.{Fnmatch, Expand}` (the POSIX libc wrappers — correctly POSIX-bound). It depends on swift-glob-primitives for the vocabulary types its libc wrappers consume.

| Pros | Cons |
|---|---|
| Eliminates cross-platform asymmetry — swift-windows drops swift-iso-9945 dep | New L1 package adds package-count |
| Honors `feedback_authority_not_platform` (vocabulary is authority-less, lives at L1) | Requires Package.swift updates at 4 packages |
| Honors [PLAT-ARCH-005] (L2 retains spec-bound libc wrappers; vocabulary moves out) | Old `ISO_9945.Kernel.Glob.*` namespace surface deprecates → `Glob.*` (renames) |
| Honors `feedback_l2_is_syscalls_level` (Pattern/Atom/Segment are not syscalls — they're grammar primitives) | Test-suite imports update across ~5 test files |
| Aligns with Wave 4a-Glob commit `b223efb`'s explicit roadmap statement | |
| L3-policy match algorithms unchanged — they extend the new namespace identically | |
| Small enough scope to fit one cycle (~30-40 LOC of churn + 1 new package) | |

**Cost**: ~1 new package + ~25-30 LOC of churn across consumers. **Verdict**: cleanest architecture; matches stated intent of the existing namespace doc; aligns with Wave 4a-Glob commit's open roadmap reference.

**Open sub-question for principal**: top-level `Glob.*` namespace OR keep `Kernel.Glob.*`? Stronger arguments for top-level:

- Per `feedback_l2_is_syscalls_level`, the `Kernel.X` namespace prefix telegraphs "syscall-adjacent" — Glob.Pattern is not a syscall.
- Other L1 vocabulary primitives (Buffer, Time, ASCII, Path, Dimension) live under their own top-level namespace, not under `Kernel.X`.
- The current `Kernel.Glob` placement was an artifact of being in iso-9945 where `Kernel` is the dominant namespace; moving to L1 is a chance to restore the conventional shape.

### Option C — Relocate vocabulary to a NEW L2 spec package

Create something like `swift-glob-standard` capturing "glob is a quasi-spec language even if not strictly POSIX" (POSIX defines basics; many tools — Bash, Git, Node, npm — extend). The package would own `Glob.{Pattern, Segment, ...}`.

| Pros | Cons |
|---|---|
| Captures glob's specification-like character | No clear spec authority — POSIX defines basics, but `**` is Bash, exclude-`{a,b}` is policy |
| Consistent with [PLAT-ARCH-005] *if* there were an authority | Naming difficulty — `swift-glob-standard`? `swift-bash-glob-standard`? `swift-fnmatch-standard`? |
| Both swift-posix + swift-windows depend on it | Fragmentation — many tool-specific glob extensions could each justify their own L2 package |
| | More packages to maintain than Option B |
| | Doesn't gain over Option B since the vocabulary is L1-shaped by content (no libc deps, no platform conditionals) |

**Cost**: similar to Option B (~1 new package + ~25-30 LOC churn). **Verdict**: defensible but Option B is cleaner — there's no actual spec authority to anchor to.

### Option D — Defer indefinitely

Take no action; keep status quo without documenting. Continues to leak the asymmetry as a future-question.

| Pros | Cons |
|---|---|
| Zero work | Doesn't close Item 3.5 |
| | Future contributors will rediscover the asymmetry and need to research it again |

**Cost**: 0 LOC. **Verdict**: not recommended; if not relocating, at least update the namespace doc per Option A.

---

## Recommendation

**Option B** (relocate vocabulary to new L1 package) is the recommended direction:

1. **Architectural correctness**: the vocabulary's content is L1-shaped (single L1 dep, no platform conditionals, no libc bindings). Placement should match content.
2. **Closes Wave 4a-Glob commit `b223efb`'s explicit roadmap reference**: that commit named Item 3.5 specifically as the future cycle to "[move] the vocabulary to L1".
3. **Honors `feedback_authority_not_platform`**: glob has no single spec authority; L1 is the right home for authority-less vocabulary.
4. **Eliminates the cross-platform dependency asymmetry** (swift-windows → swift-iso-9945 dep deletion).
5. **Bounded scope**: ~1 new package + ~25-30 LOC of churn + 4 Package.swift updates. No breaking API changes (consumers extend the new namespace identically). Well within "one cycle" capacity.

Pursuant to the dispatch's research-only protocol: **principal disposition required** before any code dispatch. If Option B is selected, sub-question on namespace shape (`Glob.*` top-level vs `Kernel.Glob.*` prefix) also requires disposition.

---

## Surfaced Items for Principal

| # | Item | Disposition needed |
|---|---|---|
| 1 | Premise inversion: dispatch framed Glob as "currently at L1" but it's at L2 | Confirm reframed question is the intended target of Item 3.5 |
| 2 | Direction: A (status quo + doc) / B (L1 relocation, recommended) / C (new L2 spec) / D (defer) | Pick |
| 3 | If B: namespace shape — top-level `Glob.*` OR keep `Kernel.Glob.*` prefix | Pick |
| 4 | If B: package name — `swift-glob-primitives`? other? | Pick |
| 5 | If B: handling of the L3-unifier surface (no `Kernel.Glob.match` exists at swift-kernel L3-unifier today; should the relocation cycle add one for cross-platform-symmetric API access?) | Pick (possibly defer) |

---

## Out-of-Scope Notes

- This research does NOT touch any `Sources/` file (per dispatch ground rule #3).
- This research does NOT touch Item 1.5's edit zones (per ground rule #4).
- This research does NOT touch Tier 5-Windows-Mirror artifacts (per ground rule #5).
- The libc-bound `ISO_9945.Glob.{Fnmatch, Expand}` surface stays at L2 swift-iso-9945 in all options — correctly POSIX-bound.
- Wave 4a-Glob's typed L2 `Windows.\`32\`.Kernel.File.Find` surface (commit `bff2cca`) is unaffected by any relocation — it lives at swift-windows-32 and is consumed only by swift-windows L3-policy match algorithm.
