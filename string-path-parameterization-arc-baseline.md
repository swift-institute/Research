# String / Path Parameterization — arc baseline & status quo

<!--
---
version: 1.0.0
last_updated: 2026-06-29
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
consolidates:
  - string-char-generic-future-cycle.md        # DELETED 2026-06-29 — findings migrated here (§7.1)
  - string-path-type-unification.md             # DELETED 2026-06-29 — findings migrated here (§7.2)
inherits_decision_from:
  - tagged-path-string-identity-resolution.md   # KEPT — DECISION (Option G), inherited not re-litigated (§4)
builds_on:
  - memory-contiguous-dissolution.md            # KEPT — EXECUTED; this is its deferred String<Backing> follow-on (§5.3)
  - storage-buffer-abstraction-analysis.md      # KEPT — general storage thesis intact; not String/Path-overtaken
  - string-primitives-shadowing.md              # KEPT — shadowing hazard, resolved-by-construction here (§6)
  - path-type-ecosystem-model.md                # KEPT — type inventory reference
forcing_function:
  - .handoffs/HANDOFF-swift-linter-closure-publication.md  # path-primitives [PLAT-ARCH-008c] blocks the publication closure
---
-->

## Purpose

This document is the **single authoritative baseline** for the String / Path
parameterization arc. It (a) records the current status quo verified against source,
(b) reconciles five prior research documents that partially contradicted one another,
and (c) frames the decision the arc must make. It was created when the publication
campaign turned a long-deferred design question into a blocker: `swift-path-primitives`
cannot be made outsider-consumable while it violates `[PLAT-ARCH-008c]`, and that
violation is structural, not cosmetic.

Per `[META-016]`, every finding from the two documents deleted on 2026-06-29
(`string-char-generic-future-cycle.md`, `string-path-type-unification.md`) is
preserved here (§7). The deletions were a principal decision; git history retains
the originals.

## 1. Status quo (verified against source, 2026-06-29)

| Fact | Evidence |
|------|----------|
| `String` storage is concrete `Memory.Heap`, no generic parameter, no SSO | `swift-string-primitives/Sources/String Primitives/String.swift:58` (`internal let _storage: Memory.Heap`); decl `:48` |
| `String.Char` is platform-selected | `String.Char.swift:17-23` — `#if … && os(Windows) { UInt16 } else { UInt8 }` |
| `Path` storage is concrete `Memory.Heap`, no generic parameter | `swift-path-primitives/Sources/Path Primitives/Path.swift:54` (`internal let _storage: Memory.Heap`) |
| `Path.Char` re-exports `String.Char` (inherits the platform `#if`) | `Path.swift:65` (`public typealias Char = String_Primitives.String.Char`) |
| Whole `Path` struct is `#if os(...)`-gated | `Path.swift:12` |
| `Path` deps | `string-primitives`, `memory-heap-primitives`, `tagged-primitives`, `ownership-primitives`, `error-primitives` |

**Reading**: String and Path are structural twins — `Memory.Heap` backing plus a
platform-selected element type. `Path.Char` *is* `String.Char`, so the encoding
problem has a single root in string-primitives; Path merely inherits it. Neither
type is generic today.

## 2. The `[PLAT-ARCH-008c]` violation, precisely

`[PLAT-ARCH-008c]` forbids compile-time data/type selection via `#if os()` in **L1
public API**. The violation is the platform-selected `Char` (`UInt8` POSIX / `UInt16`
Windows) surfaced through `String.Char` and re-exported by `Path.Char`. This is what
blocks publication: an outsider building path-primitives gets a type whose public
surface changes shape by platform, decided inside L1.

Making the backing storage generic (`Path<Memory.Small>`) does **not** touch this —
the violation is on the **encoding** axis, not the storage axis. This is the single
most important distinction in the arc.

## 3. The three orthogonal axes

| Axis | Generic shape | Buys | Status entering the arc |
|------|---------------|------|--------------------------|
| ① Domain identity (String vs Path, Kernel vs Loader) | `Tagged<Domain, RawValue>` | Type-level domain separation; resolves shadowing | **DECIDED** — Option G (§4) |
| ② Encoding (UTF-8 / UTF-16) | `String<Char>` | Removes the `#if` → fixes `[PLAT-ARCH-008c]` | **The fix** (§5.2) |
| ③ Backing storage | `String<Backing>` | SSO (`Memory.Small`), inline (`Memory.Inline`) | **The SSO rider** (§5.3) |

The prior corpus collapsed or separated these inconsistently. They are independent
and **composable**: domain stays on the `Tagged` wrapper; encoding and backing become
generic parameters of the concrete RawValue it wraps.

## 4. Axis ① is already decided — inherit, do not re-litigate

`tagged-path-string-identity-resolution.md` (DECISION, v2.0.0, 2026-02-27) settled the
domain axis as **Option G**:

1. Concrete types (`PlatformString`, `PlatformPath`) own `Storage.Contiguous<Char>` and
   expose `@_lifetime` accessors.
2. `Tagged` wraps them with domain identity: `Tagged<Kernel, PlatformString>`.
3. **Kind** (String vs Path) is the nominal RawValue; **Domain** (Kernel, Loader) is the Tag — two orthogonal axes.
4. Type distinctness comes from nominal RawValue difference, not tag difference.
5. The two-level `@_lifetime` chain (`Tagged.rawValue` → borrow concrete → `.span` → re-parent via `_overrideLifetime`) was validated in debug + release (`tagged-two-level-lifetime`, 6 variants).

Option G was chosen over **Option F** (`String<Domain>` — a generic struct carrying
the domain) specifically so that `Tagged`'s functors (`retag`, `map`, conditional
conformances) apply uniformly with no per-type generic duplication.

**Consequence for this arc**: the domain stays on `Tagged`. Axes ② and ③ are added
*inside* the concrete RawValue, which simply becomes generic. Option G survives intact:
`Tagged<Domain, String<Char, Backing>>` is still "concrete-RawValue wrapped by Tagged",
where the concrete RawValue is now itself parameterized. The arc must not reopen
Option F vs G.

## 5. What the arc must do

### 5.1 Unified shape (recommended)

```
Tagged<Domain, String<Char, Backing>>
```

- `Char` carries the encoding (axis ②) — resolves `[PLAT-ARCH-008c]`.
- `Backing: Memory.Growable` carries the storage strategy (axis ③) — delivers SSO.
- `Tagged<Domain, …>` carries identity (axis ①) — unchanged from the standing decision.

Equivalent single-parameter framing under consideration: `String<Storage>` where
`Storage = Storage.Contiguous<Char, Allocation>` folds both ② and ③ into one
parameter (the storage composition already exists — see §5.4). One-parameter vs
two-parameter is an open design question (§8).

### 5.2 `[PLAT-ARCH-008c]` resolution mechanism

Parameterizing `Char` removes the `#if` from L1 public API: `String<Char>` exists for
*all* encodings on *all* platforms, with no platform conditional in its surface. The
platform binding moves **up to L3** (kernel / platform layer), where selecting platform
data is the layer's job and `#if os()` is legal:

```swift
// L3 platform layer — NOT in string-primitives (L1)
#if os(Windows)
public typealias PlatformString = String<UTF16, Memory.Heap>
#else
public typealias PlatformString = String<UTF8, Memory.Heap>
#endif
```

> **Correction to prior art**: `string-char-generic-future-cycle.md` proposed keeping
> `PlatformString = String<UInt8/UInt16>` *inside string-primitives (L1)*. That would
> leave the `#if` in L1 and **not** satisfy `[PLAT-ARCH-008c]`. The L3 relocation is
> this baseline's contribution.

### 5.3 SSO (the deferred follow-on, now actionable)

`memory-contiguous-dissolution.md` (EXECUTED, v1.2.0, 2026-06-23) deferred exactly this:

> "`String<Backing>` where `Backing` is a raw-leaf protocol = `Memory.Region`
> (base+capacity) + a borrowed raw-base egress accessor + **conditional**
> `Memory.Growable`. Admits `Memory.Heap`, `Memory.Small<n>`, `Memory.Inline<n>`."

Constraints it recorded, carried forward verbatim:

- **Ownership boundary**: keep `String<Backing>` to **self-owning, self-freeing,
  egress-capable** leaves (uniform lifecycle). Zero-copy / foreign / arena cases are a
  *different* ownership model and ride the existing owning/borrowed split
  (`String.Borrowed` / `Path.Borrowed`, `Memory.Foreign`), **not** a wider backing generic.
- **Ergonomic-default problem**: `typealias String = String<Memory.Heap>` does **not**
  work — the alias name collides with the generic `String<…>`. Provide convenience inits
  via a constrained extension instead: `extension String where Backing == Memory.Heap { init(…) }`.
- **SSO is the prize**: `Memory.Small<n>` = inline ≤ n bytes with heap spill;
  `Memory.Inline<n>` = bounded, borrowed-egress only; `Shared<…>` layers CoW value-semantics.

It was deferred (not rejected) as "a separate follow-on arc, AFTER the dissolution
lands, … wide consumer impact". The dissolution has landed; this is that arc.

### 5.4 Infrastructure already exists (this is a refactor, not a new-primitive arc)

Verified present in `swift-primitives`:

- **Variants**: `Memory.Heap`, `Memory.Small<n>` (inline⊕heap spill), `Memory.Inline<n>`
  (fixed, `@_rawLayout`), `Memory.Foreign`.
- **Seam protocols**: `Memory.Region` (`base` + `capacity`), `Memory.Allocatable`
  (`makeAllocator`), `Memory.Growable` (`init(byteCount:alignment:)`).
- **Conformance reality**: `Heap`/`Small`/`Inline`/`Foreign` conform `Memory.Region`;
  `Heap`/`Small` conform `Memory.Growable`; `Inline` correctly does **not** (fixed
  capacity cannot grow → fails to compile, the desired safety).
- **Composition point**: `Storage.Contiguous<Element, Allocation: Memory.Region>` already
  exists and composes the element type and the allocation — the natural home for a
  single-parameter `String<Storage.Contiguous<Char, Allocation>>` framing.

## 6. Bonus: parameterization resolves the shadowing problem by construction

`string-primitives-shadowing.md` and the `typealias-without-reexport` experiment
(7 variants, 2026-02-27) establish that `@_exported public import String_Primitives`
makes bare `String` resolve to `String_Primitives.String` (~Copyable) wherever Kernel
is imported, and that **import-level fixes are structurally impossible** under SE-0444
(MemberImportVisibility): a typealias alone gives type-level visibility but zero member
access. A generic `String<…>` resolves this **by construction** — bare `String` without
parameters is unambiguous from `Swift.String`. This is a free win of axis ② / ③, not a
separate workstream.

## 7. Preserved findings from the deleted documents (`[META-016]`)

### 7.1 From `string-char-generic-future-cycle.md` (was: NOT YET PROPOSED)

**Thesis**: parameterize `String` over `Char` for compile-time UTF-8/UTF-16 distinction.

Proposed signature and aliases:

```swift
public struct String<Char: UnsignedInteger & FixedWidthInteger>: ~Copyable { ... }
public typealias PlatformString = String<UInt8>   // POSIX   (relocate to L3 — see §5.2)
public typealias PlatformString = String<UInt16>  // Windows (relocate to L3 — see §5.2)
extension ISO_9899 { public typealias String = String_Primitives.String<UInt8> }  // UTF-8 explicit
public typealias UTF16OwnedString = String_Primitives.String<UInt16>              // rare, explicit
```

**Pros recorded**: type-level encoding distinction; resolves apparent `ISO_9899.String`
duplication (becomes an explicit alias); enables a clean `Lexer.Scanner` generic-over-Char;
modularization closure.

**Cons recorded ("LARGE")**: touches every `String.Char` consumer; overload-resolution
complexity at call sites; Tagged forwarding cascade; `Kernel.String` migration; per-stage
cross-layer equivalence tests.

**Why it was deferred (quoted)**: *"Benefit is hypothetical: no production consumer today
needs the type-level encoding distinction. The current platform-typealias design works for
OS-syscall use cases."* — **This rationale is now reversed**: the trigger is no longer a
hypothetical consumer need but `[PLAT-ARCH-008c]` compliance gating publication. Per
`[feedback_correctness_and_evergreen]`, structural-correctness triggers are not subject to
the `[RES-018]` consumer-demand threshold this doc invoked.

**Staged pathway it provided** (reusable): (1) introduce `String<Char>` alongside the
existing type; (2) migrate `ISO_9899.String` to `String<UInt8>`, verify byte-identical;
(3) migrate `Kernel.String` via the platform typealias; (4) deprecate the old
platform-typealias form.

### 7.2 From `string-path-type-unification.md` (was: RECOMMENDATION v3.1.0)

**Question**: correct type architecture for the five string/path types across L1–L3
(`String_Primitives.String`, `Kernel.Path`, `ISO_9899.String`, foundations `Path`, `Strings`).

**Options & verdicts**:

| Option | Shape | Verdict |
|--------|-------|---------|
| A — status quo (keep 5 types) | thin `Kernel.Path` wraps `String_Primitives.String` | Safe but ~150 lines pure delegation; two near-identical View types |
| B — merge Path into String | `typealias Kernel.Path = String_Primitives.String` | **Rejected** — loses domain distinction; namespace cohesion violation |
| C — unify Views only | single `String.View` | Partial; doesn't fix core duplication |
| D — phantom-tagged custom struct | `String<Tag: ~Copyable>` | Technically sound; 9/9 experiment variants CONFIRMED |
| D′ — literally `Tagged<Domain, StringStorage>` | uses Tagged infra | **Preferred in v3.1**; blocked by Tagged `rawValue._read` vs `@_lifetime` |
| E — refine status quo (dedupe internals) | no API change | Conservative fallback |

**Critical D′ blocker (carried forward)**: Tagged's `rawValue` uses `_read { yield _storage }`,
creating a coroutine scope boundary that blocks `@_lifetime` propagation for `~Escapable`
View types. Resolutions: (a) `@usableFromInline _storage`, (b) a `withRawValue(_:)` closure
accessor on Tagged, or (c) same-package placement. **This is why the later DECISION went to
Option G (concrete RawValue with direct `.span` access + two-level `@_lifetime`)** — §4.

**Shadowing finding (v3.1)**: only the phantom/generic options (D/D′/G) resolve the
`Swift.String` shadowing; A/B/C/E cannot (§6).

**Release-mode SIL crash `#87029`**: scoped `callAsFunction` creating a `~Escapable` View
crashes CopyPropagation in release; workaround `@_optimize(none)` (already applied to 6
existing primitives functions). Carry as a known constraint, not a blocker.

**`[COPY-FIX-003]` tax**: every extension on a `~Copyable`-generic type must carry
`where Tag: ~Copyable` (pattern already applied across ~278 targets).

**Validating experiments (all CONFIRMED, retained in `Experiments/`)**:
`phantom-tagged-string-unification` (9 variants), `tagged-string-literal` (10),
`tagged-two-level-lifetime` (6), `typealias-without-reexport` (7).

**Peer-language reference**: Rust `str/String → OsStr/OsString → Path/PathBuf → CStr/CString`;
Apple swift-system `FilePath` (Copyable); C++17 `std::filesystem::path` (cautionary —
implicit encoding conversions); Python PEP 529 (Windows UTF-8 migration).

## 8. Open questions for the arc

1. **Parameter shape** — one parameter (`String<Storage.Contiguous<Char, Allocation>>`,
   reuses existing composition, verbose) vs two (`String<Char, Backing>`, matches the
   prior-art signatures, ergonomic). *Lean: two-parameter for call-site clarity, with a
   `Storage`-based internal representation.* Decide empirically.
2. **Scope** (principal fork, still open):
   - **Scope-minimal** — parameterize **encoding only** now (fixes `[PLAT-ARCH-008c]`,
     unblocks path + platform stack + publication sooner), defer backing/SSO. Pays the
     String-migration tax twice.
   - **Scope-complete** — parameterize encoding **and** backing in one arc. One migration,
     delivers SSO, bigger diff, slower to unblock publication. *Baseline lean:
     scope-complete, since the migration tax is dominated by adding the first parameter.*
3. **`@_lifetime` through a generic RawValue** — Option G's two-level chain was validated
   for a *concrete* RawValue. When the RawValue becomes `String<Char, Backing>`, re-validate
   the chain holds through the generic (new experiment required — none currently covers it).
4. **`PlatformString` home** — confirm the L3 platform package that will own the
   `#if os()` typealias binding (kernel-primitives is the likely site; verify it is ≥ L3).
5. **Migration ordering** — string-primitives is the root (`Path.Char` inherits it), so it
   migrates first; path-primitives follows; then the `Tagged<Domain, …>` consumers
   (`Kernel.String`, `Kernel.Path`, `ISO_9899.String`).

## 9. Blast radius

Wide. `String` is consumed across L1–L3 and the 54-package swift-linter closure. The first
generic parameter is the expensive step (every `extension` gains a `where` clause; every
`String.Char` site and Tagged-forwarding site is touched). Adding a second parameter in the
same pass is marginal by comparison — this is the core argument for scope-complete (§8.2).
Treat as a multi-wave arc with cross-layer equivalence tests per wave (§7.1 staged pathway).

## 10. Cross-references

- **Inherited decision**: `tagged-path-string-identity-resolution.md` (Option G)
- **Predecessor (executed)**: `memory-contiguous-dissolution.md` (String<Backing> follow-on)
- **Shadowing**: `string-primitives-shadowing.md`, `string-primitives-tagged-tag-selection.md`
- **Storage thesis (general, intact)**: `storage-buffer-abstraction-analysis.md`
- **Type inventory**: `path-type-ecosystem-model.md`
- **Experiments**: `phantom-tagged-string-unification`, `tagged-string-literal`,
  `tagged-two-level-lifetime`, `typealias-without-reexport` (all in `swift-institute/Experiments/`)
- **Forcing function**: `.handoffs/HANDOFF-swift-linter-closure-publication.md`
- **Rules**: `[PLAT-ARCH-008c]` (platform), `[API-NAME-001]`/`[API-IMPL-005]` (code-surface),
  `[COPY-FIX-003]` (implementation), SE-0444 MemberImportVisibility

## 11. Provenance

- **Created** 2026-06-29 consolidating the corpus during the swift-linter publication arc.
- **Deleted same day** (principal decision; findings migrated to §7): `string-char-generic-future-cycle.md`,
  `string-path-type-unification.md`. Git history retains both.
- **Verified against source** 2026-06-29 (file:line in §1).
