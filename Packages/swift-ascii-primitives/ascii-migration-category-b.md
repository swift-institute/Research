# Category B ASCII Migration — Consolidated Plan

<!--
---
version: 3.0.0
last_updated: 2026-04-16
status: CATEGORY B COMPLETE — Step 5 verification blocked by unrelated kernel/string-primitives regression
scope: 22 L2 standards packages → drop swift-ascii (L3) dependency
supersedes:
  - swift-primitives/swift-ascii-primitives/Research/HANDOFF.md (this file's predecessor)
  - swift-institute/Research/handoff-ascii-domain-ownership-audit.md
  - swift-institute/Research/ascii-domain-ownership-audit.md (partial — implementation-complete audit)
  - swift-institute/Research/ascii-parsing-domain-ownership.md (partial — Category B phasing)
  - swift-institute/Research/ascii-parsing-adversarial-review.md (partial — validation history retained)
  - swift-institute/Research/ascii-serialization-migration.md (partial — full witness migration deferred, retained)
---
-->

## Goal

Prepare the Swift Institute ecosystem for releasing **swift-file-system** as a
consumable SwiftPM package. The release-readiness rule is:

> **Standards (L2) depend on Primitives (L1) solely.**
> **Foundations (L3) depend on Standards (L2) or Primitives (L1).**

22 Category B standards packages still depend on `swift-ascii` (L3) via
`Binary.ASCII.Serializable` and/or 5 additional L3 ASCII features. This plan
takes them to L1-only.

**Category B migration is COMPLETE** as of 2026-04-08. All 22 packages have zero
`swift-foundations/swift-ascii` references. Step 5 end-to-end verification is
blocked by an unrelated ecosystem regression (kernel/string-primitives API change)
— see [Step 5](#step-5--end-to-end-release-verification--blocked-not-by-this-migration).

---

## Scope

**In scope**
- 22 Category B L2 standards packages (see [Package Inventory](#category-b-package-inventory))
- The 5 L3 ASCII features that block those packages (see [Blocking Feature Inventory](#blocking-feature-inventory))
- `Binary.ASCII.Serializable` protocol + convenience extensions relocation to L1
- Cycle 2 from the release roadmap (`swift-iso-9945` → `swift-ascii`) — folded in as package #22

**Out of scope**
- Category A packages (24 L2, already done — ~4,500 tests passing)
- Cycle 1 (`swift-rfc-4648` → `swift-ascii`) — DONE, verified at `swift-ietf/swift-rfc-4648/Package.swift:19-29`
- Cycle 3 (`swift-linux`/`swift-windows` → `swift-systems`) — NOT A CYCLE (already acyclic via Linux System / Linux Kernel split)
- Full `Binary.ASCII.Serializable` → `Parseable`/`Serializable` witness migration — DEFERRED post-release (tracked separately in [`ascii-serialization-migration.md`](../../../swift-institute/Research/ascii-serialization-migration.md))
- `swift-ascii` (L3) Machine IR restructuring — DEFERRED (separate concern)

---

## Current State

### What's done (verified 2026-04-08)

| Area | State | Evidence |
|---|---|---|
| Category A (24 pkgs) | Complete | ~4,500 tests passing, zero failures |
| `swift-file-system` itself | Clean | debug + release (`-sil-disable-pass=CopyPropagation`) + 708/708 tests pass |
| Cycle 1 | Fixed | `swift-ietf/swift-rfc-4648/Package.swift:19-29` uses `swift-ascii-primitives` (L1) |
| Cycle 3 | Not a cycle | Linux System / Linux Kernel split already breaks it |
| L1 ASCII parser infra | Exists | `swift-ascii-parser-primitives` (Tier 18): `ASCII.Decimal.Parser`, `ASCII.Hexadecimal.Parser`, `Parseable` integer conformances (10 types) |
| L1 ASCII serializer infra | Exists | `swift-ascii-serializer-primitives` (Tier 18): `ASCII.Decimal.Serializer`, `ASCII.Hexadecimal.Serializer`, `Serializable` integer conformances (10 types) |
| L1 witness infra | Exists | `Parser.Protocol`, `Parseable`, `Serializer.Protocol`, `Serializable`, `Coder.Protocol`, `Codable` all in place |
| Closing commits | Pushed | `3afe05f` in swift-file-system, `ef92761` in swift-institute |
| Handoff relocation | Done | Moved from `/Users/coen/Developer/HANDOFF.md` to `swift-primitives/swift-ascii-primitives/Research/HANDOFF.md` (commit `a4430d0`) |

### What's not done

- **Category B (22 packages)** — no migration work started post-revert
- **Cycle 2** (`swift-iso-9945` → `swift-ascii`) — folded into this migration; iso-9945 is package #22
- **Open Question 1** — destination layer for `Set.ASCII` / `[UInt8].ASCII` / `INCITS_4_1986.ASCII<C>` unresolved; this blocks the entire migration

### L1 & L2 Inventory (for locating where blocking features can move)

**L1 `swift-ascii-primitives`** (Tier 0, zero-dependency; verified prior-session inventory):

- All 128 character constants via `UInt8.ascii.*`, `ASCII.Character.Control`, `ASCII.Character.Graphic`
- `ASCII.Byte` wrapper with classification (`isLetter`, `isDigit`, `isWhitespace`, …)
- `ASCII.Case` + `ASCII.Case.Conversion` (case conversion, `convert(_:to:)`)
- `ASCII.whitespaces: Set<UInt8>` — 4 bytes (SP, HT, LF, CR)
- `ASCII.Line.Ending` enum (`.lf`, `.cr`, `.crlf`)
- `ASCII.Parsing` / `ASCII.Serialization` (byte-level digit/hex functions)
- `ASCII.Decimal`, `ASCII.Hexadecimal` (empty enum namespaces reserved for extension)
- **Does NOT provide**: `Set.ASCII` namespace, `[UInt8].ASCII` namespace, `Binary.ASCII.Serializable` protocol

**L1 `swift-ascii-parser-primitives`** (Tier 18; depends on `ascii-primitives` + `parser-primitives`):

- `ASCII.Decimal.Parser<Input, T>` conforms to `Parser.Protocol`
- `ASCII.Hexadecimal.Parser<Input, T>` conforms to `Parser.Protocol`
- `ASCII.Decimal.Error`, `ASCII.Hexadecimal.Error`
- `Parseable` conformances for all 10 stdlib integer types

**L1 `swift-ascii-serializer-primitives`** (Tier 18; depends on `ascii-primitives` + `serializer-primitives`):

- `ASCII.Decimal.Serializer<T>` conforms to `Serializer.Protocol`
- `ASCII.Hexadecimal.Serializer<T>` conforms to `Serializer.Protocol`
- `Serializable` conformances for all 10 stdlib integer types

**L2 `swift-incits-4-1986`** (depends only on L1):

- `INCITS_4_1986.ASCII<Source>` generic wrapper on byte collections and strings — provides `trimming()`, `lowercased()`, `uppercased()`, `isAllASCII`, case-insensitive comparison, `lineRanges()`, `lines()`, `detectedLineEnding()`
- `INCITS_4_1986.whitespaces` byte constant set
- `INCITS_4_1986.Character.Control.crlf` constant
- `INCITS_4_1986.convert(_:to:)` (case conversion)
- `INCITS_4_1986.Classification` batch predicates (`isAllDigits`, `isAllLetters`, …)
- `INCITS_4_1986.FormatEffectors.normalized()` (LF/CR/CRLF normalization)

**L3 `swift-ascii`** — currently owns:

- `Binary.ASCII.Serializable` (77 conformers) + `Binary.ASCII.RawRepresentable` + `Binary.ASCII.Wrapper`
- `Binary.ASCII` struct (redundant with `ASCII.Byte`)
- `Set<Character>.ascii.whitespaces` (wraps INCITS + CRLF)
- `Set<UInt8>.ascii.whitespaces` (wraps `INCITS_4_1986.whitespaces`)
- `[UInt8].ascii.crlf` (wraps `INCITS_4_1986.Character.Control.crlf`)
- Instance `.ascii` collection accessor returning `INCITS_4_1986.ASCII<Self>` wrapper
- `Binary.ASCII.equals.nulTerminated()` (stdlib-only pointer comparison)
- Machine IR parsers (`Binary.ASCII.Parsing.Machine.Decimal`) — out of scope here

---

## Key Decisions

| Decision | Rationale |
|---|---|
| **Standards depend on primitives solely.** | Non-negotiable release rule. |
| **Strategy (c) chosen: move `Binary.ASCII.Serializable` + convenience extensions to L1.** | The protocol depends only on stdlib + `Binary.Serializable` (L1); the move is architecturally clean. Proven by an earlier attempt (501 L3 tests still passed with the protocol relocated). |
| **Full `Parseable`/`Serializable` witness migration is DEFERRED.** | 77 conformers × (Parser + Serializer + conformances) ≈ 300+ file changes for zero additional release benefit. Protocol relocation unblocks the release; witness migration is post-release quality work. |
| **L2 standards MAY depend on other L2 standards.** | INCITS 4-1986 features (whitespace, case conversion) belong in `swift-incits-4-1986` (L2), not hardcoded in L1. Consumer L2 packages that need them may take an L2→L2 dep. |
| **Preserve call-site syntax.** | Move infrastructure to the right layer; never inline byte literals or rewrite with manual loops. Inline replacements like `[0x0D, 0x0A]` for `[UInt8].ascii.crlf` were explicitly rejected. |
| **Domains as namespaces, capabilities as nested types.** | Inherited from `ascii-parsing-domain-ownership.md` v4.2.0: `ASCII.Decimal.Parser` (not `Parser.ASCII.Decimal`); empty enum namespaces keep room for sibling capabilities. |

---

## Category B Package Inventory

Verify each against current git state before touching — some may have been touched by unrelated work.

| # | Package | Location | Dep type | Prior attempt status | Blocker |
|--:|---|---|---|---|---|
|  1 | swift-rfc-791 | `swift-ietf/swift-rfc-791` | protocol only | OK | — |
|  2 | swift-rfc-1035 | `swift-ietf/swift-rfc-1035` | protocol only | OK | — |
|  3 | swift-rfc-1123 | `swift-ietf/swift-rfc-1123` | protocol only | OK | — |
|  4 | swift-rfc-2369 | `swift-ietf/swift-rfc-2369` | protocol only | OK | — |
|  5 | swift-rfc-2822 | `swift-ietf/swift-rfc-2822` | protocol only | OK | — |
|  6 | swift-rfc-3339 | `swift-ietf/swift-rfc-3339` | protocol only | OK | — |
|  7 | swift-rfc-3986 | `swift-ietf/swift-rfc-3986` | protocol only | OK | — |
|  8 | swift-rfc-3987 | `swift-ietf/swift-rfc-3987` | protocol only | OK | — |
|  9 | swift-rfc-4007 | `swift-ietf/swift-rfc-4007` | protocol only | OK | — |
| 10 | swift-rfc-4291 | `swift-ietf/swift-rfc-4291` | protocol only | OK | — |
| 11 | swift-rfc-7519 | `swift-ietf/swift-rfc-7519` | protocol only | OK | — |
| 12 | swift-rfc-7617 | `swift-ietf/swift-rfc-7617` | protocol only | OK | — |
| 13 | swift-rfc-9557 | `swift-ietf/swift-rfc-9557` | protocol only | OK | — |
| 14 | swift-rfc-2045 | `swift-ietf/swift-rfc-2045` | protocol + features | FAIL | `.ascii.whitespaces`, `.ascii.trimming()`, `.ascii.lowercased()` |
| 15 | swift-rfc-2183 | `swift-ietf/swift-rfc-2183` | protocol + features | FAIL | `.ascii.whitespaces`, `.ascii.trimming()` |
| 16 | swift-rfc-2387 | `swift-ietf/swift-rfc-2387` | protocol + features | FAIL | (shares 5321/5322 lineage — re-verify) |
| 17 | swift-rfc-5321 | `swift-ietf/swift-rfc-5321` | protocol + features | FAIL | `Set<Character>.ascii.whitespaces` |
| 18 | swift-rfc-5322 | `swift-ietf/swift-rfc-5322` | protocol + features | FAIL | `Set<Character>.ascii.whitespaces`, `[UInt8].ascii.crlf` |
| 19 | swift-rfc-6068 | `swift-ietf/swift-rfc-6068` | protocol + transitive | FAIL | via 5321/5322 |
| 20 | swift-rfc-6531 | `swift-ietf/swift-rfc-6531` | protocol + transitive | FAIL | via 5321/5322 |
| 21 | swift-iso-9945 | `swift-iso/swift-iso-9945` | feature only | FAIL | `Binary.ASCII.equals.nulTerminated` (Cycle 2) |
| 22 | swift-whatwg-url | `swift-whatwg/swift-whatwg-url` | unknown | NOT BUILT | unknown; prior attempt didn't finish build |

**Prior-attempt build results**: 13 pure-protocol packages built OK; 8 failed on the 5 blocking features (including 2 transitive); iso-9945 failed on `nulTerminated`; whatwg-url not built. The prior attempt was **fully reverted** — these packages still depend on `swift-ascii` (L3) as of this plan's date.

**Verification gap**: the per-package status above is from the pre-revert snapshot. Re-verify each package's current `Package.swift` dep on `swift-ascii` before starting migration (grep `import ASCII`, `\.ascii\.`, `Binary\.ASCII\.`).

---

## Blocking Feature Inventory

The 5 L3 ASCII features that must relocate (or be reached via a different path) before the 8 feature-blocked packages can migrate. Source file lines verified in a prior session against current `swift-ascii` code.

| # | Feature | Used by | Defined in (L3) | Underlying dependency |
|---|---|---|---|---|
| F1 | `Set<Character>.ascii.whitespaces` | rfc-5321, 5322, 2045, 2183, 6531 | `Set Character+INCITS_4_1986.swift:45` | L2 `INCITS_4_1986.whitespaces` + F3 |
| F2 | `Set<UInt8>.ascii.whitespaces` | rfc-2045, 2183 (via `.trimming()`) | `Set UInt8+INCITS_4_1986.swift:23` | L2 `INCITS_4_1986.whitespaces` |
| F3 | `[UInt8].ascii.crlf` | rfc-5322, 2046 | `[UInt8]+INCITS_4_1986.swift:236` | L2 `INCITS_4_1986.Character.Control.crlf` |
| F4 | `bytes.ascii.trimming()` / `.lowercased()` | rfc-2045 | **Already L2**: `INCITS_4_1986.ASCII.swift:124-169` | stdlib + L2 `INCITS_4_1986.convert` |
| F5 | `Binary.ASCII.equals.nulTerminated()` | iso-9945 | `Binary.ASCII.Equals+nulTerminated.swift:43` | **stdlib only** (UnsafePointer, StaticString) |

**Key observations**:

- **F4 is not really L3.** The `INCITS_4_1986.ASCII<Source>` wrapper type already lives in L2 (`swift-incits-4-1986`). L3 only provides the `.ascii` *accessor* on collections that returns this wrapper. The wrapper + methods are L2 already.
- **F5 has zero external dependencies.** Stdlib-only pointer comparison — trivially movable to L1.
- **F1–F3 wrap L2 constants but are themselves defined as L3 extensions on stdlib collection types.** The underlying constants (`INCITS_4_1986.whitespaces`, `INCITS_4_1986.Character.Control.crlf`) are already at L2. Alternately, **L1 already has equivalent byte constants**: `ASCII.whitespaces: Set<UInt8>` (same 4 bytes), `ASCII.Character.Control.cr`/`.lf`. So F1–F3 can be rehomed at L1 *or* L2 depending on the preferred dependency shape.

---

## Dead Ends

Both were attempted and reverted.

### DE1 — Moving only the protocol without its ecosystem

The initial attempt moved `Binary.ASCII.Serializable`, `Binary.ASCII.RawRepresentable`, and convenience extensions to a new L1 target `ASCII Serializable Primitives` in `swift-ascii-serializer-primitives`. **The protocol itself moved cleanly** — L3 build passed, 501 L3 tests passed, re-exports worked. But migrating the 22 consumers surfaced the 5 blocking features above, which were not anticipated in the original survey.

Then, trying to move `Set.ascii`/`[UInt8].ascii` namespaces to L1 triggered **namespace conflicts**:

- L3 already defined `extension Set { public enum ASCII {} }` on generic `Set<Element>`. When L1 also defined this, the `@_exported import` from L1 through L3 produced `'ascii' is ambiguous`.
- Instance `[UInt8].ascii` (returning `INCITS_4_1986.ASCII<Self>` wrapper, L3) shadows static `[UInt8].ascii` (L1 namespace). Adding a **second** instance `.ascii` at L1 would collide.

The fix is the **atomic-swap pattern**: define at one layer only, extend at the other, with the L3 declaration removed in the same build-graph-visible change that adds the L1/L2 declaration. This was not attempted before the revert.

### DE2 — Inlining replacements at call sites

Rewriting `.trimming(.ascii.whitespaces)` as `.trimming(where: \.isWhitespace)` and `[UInt8].ascii.crlf` as `[0x0D, 0x0A]` was explicitly rejected by the user. The ecosystem uses named constants exclusively; inline hex bytes and manual loops violate the design philosophy. Any proposed fix must preserve the named-constant call-site form (or an equivalent named form from the new layer).

---

## Architecture Context

### The three-domain architecture (Parser / Serializer / Coder)

From `transformation-domain-architecture.md` (DECISION, v3.2.0) — inherited, not re-derived here:

```
swift-parser-primitives      — Parser.Protocol, Parser.Printer, Parser.ParserPrinter, Parseable
swift-serializer-primitives  — Serializer.Protocol, @Serializer.Builder, Serializable
swift-coder-primitives       — Coder.Protocol, Codable (shadows stdlib)
```

- Parser ↔ Printer are structural duals (same package).
- Serializer has no dual (own package).
- Coder is independent (separate decode/encode input and failure types).
- Three complementary strategies: **capability protocols** (types that ARE parsers/serializers), **witness types** (types that HAVE parsing/serialization), **domain protocols** (types that CONFORM to format contracts).

### Domain ownership: domains as namespaces

From `ascii-parsing-domain-ownership.md` v4.2.0 (RECOMMENDATION). **Principle**: a domain namespace SHOULD NOT be consumed by a single capability type. When a domain has or may have multiple capabilities, each is a nested type within the domain namespace.

```swift
// Correct (subject-first, open namespace):
ASCII.Decimal.Parser<Input, T>
ASCII.Decimal.Serializer<T>
ASCII.Decimal.Error
ASCII.Decimal.Machine       // L3 extension

// Wrong (capability-first or conflated):
Parser.ASCII.Integer.Decimal<Input, T>   // capability owns domain
ASCII.Decimal<Input, T>                  // domain struct IS the parser
```

**Degenerate exception**: when serialization is simple enough to not require structured namespace siblings (e.g. LEB128's `[UInt8](leb128:)` collection initializers), the domain type MAY directly conform to `Parser.Protocol` (`Binary.LEB128.Unsigned<T>`). The adversarial review (v2.0.0) corrected the original misstatement that "LEB128 has no serialization counterpart" — the correct criterion is *no structured serialization concern requiring namespace siblings*, not *no serialization at all*.

**Capability-type naming**: noun form (`.Parser`, `.Serializer`), not verb form (`.Parse`, `.Serialize`). Standards convention is split 22/25 between `.Parse` and `.Parser`; the ecosystem adopts `.Parser` as a design choice (type names describe what a type IS, not what it DOES).

---

## Strategy (c) Execution Plan

**This plan executes only AFTER [Open Question 1](#open-questions) is resolved by the user.** Steps 1–4 are sequenced by architectural dependency, not by difficulty.

### Step 0 — Verify current state (no code changes) — DONE

Grepped all 22 packages (2026-04-08). Results corrected the prior attempt's categorization:

| # | Package | Conformances | Blocking features | Corrected group |
|--:|---|--:|---|---|
|  1 | rfc-791 | 2 | — | protocol-only |
|  2 | rfc-1035 | 2 | — | protocol-only |
|  3 | rfc-1123 | 2 | — | protocol-only |
|  4 | rfc-2369 | 4 | — | protocol-only |
|  5 | rfc-2387 | 2 | — | protocol-only (**was FAIL in prior attempt — corrected**) |
|  6 | rfc-3339 | 4 | — | protocol-only |
|  7 | rfc-3986 | 9 | — | protocol-only |
|  8 | rfc-3987 | 2 | — | protocol-only |
|  9 | rfc-4007 | 1 | — | protocol-only |
| 10 | rfc-4291 | 2 | — | protocol-only |
| 11 | rfc-7519 | 2 | — | protocol-only |
| 12 | rfc-9557 | 6 | — | protocol-only |
| 13 | rfc-2045 | 7 | F1, F3 | feature-blocked |
| 14 | rfc-2183 | 6 | F1, F3 | feature-blocked |
| 15 | rfc-2822 | 24 | F3 | feature-blocked (**was OK in prior attempt — corrected**) |
| 16 | rfc-5321 | 4 | F1 | feature-blocked |
| 17 | rfc-5322 | 8 | F1, F2 | feature-blocked |
| 18 | rfc-6531 | 4 | F1, F3 | feature-blocked (**direct, not just transitive**) |
| 19 | rfc-7617 | 4 | F3 | feature-blocked (**was OK in prior attempt — corrected**) |
| 20 | rfc-6068 | 4 | — | transitive (depends on 5321/5322) |
| 21 | iso-9945 | 0 | F5 | feature-blocked |
| 22 | whatwg-url | 16 | — | protocol-only |

**Corrected groupings**: 12 protocol-only (was 13), 8 feature-blocked (was 5+1), 1 transitive (was 2), 1 to verify (whatwg-url — no blocking features detected despite 16 conformances).

All 22 packages still depend on `swift-ascii` in Package.swift. All are in dirty git state (uncommitted changes from unrelated work). Total conformances: ~109 across 22 packages.

### Step 1 — Resolve destination layers — DONE (B + α)

**Resolution** (user-confirmed 2026-04-08):
- *Rule 1*: Features defined by INCITS 4-1986 belong in the spec package (`swift-incits-4-1986`, L2).
- *Rule 2*: L1 stays minimal and spec-agnostic.

| Feature | Destination | Rationale |
|---|---|---|
| F1 `Set.ASCII` namespace + `Set<Character>.ascii.whitespaces` | **L2** (`swift-incits-4-1986`) | INCITS-defined whitespace set |
| F2 `Set<UInt8>.ascii.whitespaces` | **L2** | INCITS-defined whitespace set |
| F3 `[UInt8].ASCII` static namespace + `.crlf`/`.cr`/`.lf` | **L2** | INCITS-defined control characters |
| F4 instance `.ascii` collection accessor | **L2** | Returns `INCITS_4_1986.ASCII<C>` — already L2 |
| F5 `Binary.ASCII.equals.nulTerminated()` | **L2** (`swift-iso-9899`) | NUL-terminated string comparison is ISO 9899 §7.24.4 (`strcmp`); `ISO_9899.String.Comparison` already owns this domain |
| `Binary.ASCII.Serializable` protocol + extensions | **L1** | Depends on stdlib + `Binary.Serializable` (L1) |

### Step 2 — Move features bottom-up — DONE (2026-04-08)

- [x] **2a.** `Binary.ASCII.equals.nulTerminated()` → L2 `swift-iso-9899` as `ISO_9899.String.Comparison.equals`. Commits: `2a5930a` (iso-9899), `1a240d1` (iso-9945).
- [x] **2b.** `Set.ASCII` namespace + `Set<Character>.ascii.whitespaces` + `Set<UInt8>.ascii.whitespaces` → L2 `swift-incits-4-1986`. Atomic swap committed.
- [x] **2c.** `[UInt8].ASCII` static namespace + `.crlf`/`.cr`/`.lf` → L2. Atomic swap committed.
- [x] **2d.** Instance `.ascii` collection accessor → L2. Atomic swap committed.
- [x] **2e.** `Binary.ASCII.Serializable` + `RawRepresentable` + `Wrapper` → L1 `Binary ASCII Serializable Primitives` target. L3 re-exports. Commits: `0a3682d` (L1), `151484c` (L3), `dc83186` (umbrella re-export).

Combined L2 + L3 swaps: `ef85146` (incits), `41f4e07` (swift-ascii). L3 test fixes for pre-existing compound names: `61cabf2`.

### Step 3 — Migrate the 12 protocol-only packages + whatwg-url — DONE (2026-04-08)

All 13 packages swapped `swift-ascii` (L3) → `swift-ascii-serializer-primitives` (L1):

- rfc-791, 1035, 1123, 2369, 2387, 3339, 3986, 3987, 4007, 4291, 7519, 9557
- whatwg-url

### Step 4 — Migrate the 8 feature-blocked packages + 1 transitive — DONE (2026-04-08)

All packages swapped `swift-ascii` (L3) → L1 + L2:

- **L1 + L2 INCITS**: rfc-2045, 2183, 2822, 5321, 5322, 6531, 7617
- **L1 only (transitive)**: rfc-6068 — commit `1d1f4cd`
- **L2 iso-9899 only**: iso-9945 — commit `1a240d1`

### Step 5 — End-to-end release verification — BLOCKED (not by this migration)

**State at 2026-04-16**: All 22 Category B packages build clean in isolation. Zero `swift-foundations/swift-ascii` references remain in any Category B Package.swift.

`swift-file-system` currently fails to build, but the failures are unrelated to Category B migration:

- `File.System.Link.Read.Target.swift:119` — `Swift.String(kernelString)` initializer missing (kernel/string-primitives API change)
- `File.System.Copy.Recursive.swift:211` — same class of error

These are ecosystem-overhaul regressions that predate and are orthogonal to the ASCII migration. They must be resolved before Step 5 closure.

- [ ] Clean build of `swift-file-system` against migrated deps — BLOCKED on kernel/string-primitives API fix
- [ ] 708/708 tests still pass — blocked on build
- [ ] Release builds with CopyPropagation workaround — blocked on build

### Step 6 — Close Cycle 2 / update release roadmap — BLOCKED on Step 5

- [ ] Cross off Cycle 2 in `swift-institute/Research/release-roadmap-swift-file-system.md` §3 (iso-9945 → swift-ascii is resolved, but release roadmap hasn't been updated)
- [ ] Update this plan's status to DONE

### Remaining Work Summary

1. **Unblock swift-file-system build** — kernel/string-primitives `Swift.String(kernelString)` initializer regression (orthogonal to Category B)
2. **Close out release roadmap §3** for Cycle 2
3. **OQ3 — Should L3 `swift-ascii` become a re-export shell?** Deferred per original plan. Now that Category B is complete, `swift-ascii` still contains: Machine IR parsers, `Binary.ASCII` struct (now in L1), Base62 extensions, `Int+ASCII.Serializable.swift` (retroactive conformances), and assorted INCITS bridges. Decision on whether to further slim the L3 package is out of scope for release but worth revisiting post-release.
4. **Full `Parseable`/`Serializable` witness migration** — 77 conformers, deferred per `ascii-serialization-migration.md`. Post-release.

---

## Open Questions

### OQ1 — Destination layer for `Set.ASCII` / `[UInt8].ASCII` / `INCITS_4_1986.ASCII<C>` wrapper — RESOLVED

**RESOLVED** (2026-04-08): **B + α**.

**Rules applied**:
1. Features defined by INCITS 4-1986 belong in the spec package (`swift-incits-4-1986`, L2).
2. L1 stays minimal and spec-agnostic.

**Decision**: All INCITS-derived features (F1–F4) → L2 `swift-incits-4-1986`. F5 (stdlib-only) → L1. Protocol → L1.

**Constraint**: L3 `swift-ascii` declarations must be removed **atomically** with the L2 additions (same build-graph-visible change) to avoid the `'ascii' is ambiguous` re-export conflict that caused the prior revert.

### OQ2 — Strategy (c) vs full witness migration? — RESOLVED

Resolved in favor of **Strategy (c)** in the key decisions. The full `Binary.ASCII.Serializable` → `Parseable`/`Serializable` witness migration (77 conformers × per-type Parser + Serializer + conformances + `CustomStringConvertible`) is roughly an order of magnitude more work than relocating the protocol, for zero additional release benefit. It stays tracked in [`ascii-serialization-migration.md`](../../../swift-institute/Research/ascii-serialization-migration.md) as post-release quality work.

### OQ3 — Should L3 `swift-ascii` retain these features at all, or become a re-export shell?

Follows from OQ1. After L1/L2 absorb the blocking features and the protocol, `swift-ascii` (L3) arguably still earns its keep via Machine IR, `Binary.ASCII` struct (redundant but not Category-B-blocking), and the historical `Binary.ASCII.*` namespace. A full L3 consolidation is a separate concern — not blocking release. Defer the "re-export shell or keep features?" question until after Category B is green.

---

## Constraints

- **Named constants only.** Every call site must use `[UInt8].ascii.crlf`, `.ascii.whitespaces`, etc. or the equivalent named form in the new layer. No `[0x0D, 0x0A]`, no `.trimming(where: \.isWhitespace)`.
- **77 `Binary.ASCII.Serializable` conformers** across the 22 packages. Zero external generic constraints — the protocol move itself is mechanically clean (confirmed by prior attempt).
- **`Binary.ASCII` is a struct**, not an enum, in L3 with `public let byte: UInt8`. Relocating its namespace to L1 requires L3 to remove its declaration and *extend* the L1 type.
- **`Set.ASCII` namespace conflict** — must be defined at ONE layer only; extended at the other. This is the specific error the prior revert hit.
- **Instance vs static `.ascii` on `[UInt8]`** — L1 has `static var ascii` (namespace), L3 has `var ascii` (instance wrapper). Both can coexist today; do not add a second instance `.ascii` at L1.
- **CopyPropagation crash (Swift 6.3)** — release builds across the workspace need `-Xswiftc -Xllvm -Xswiftc -sil-disable-pass=CopyPropagation`. Unrelated but will surface during end-to-end verification.
- **Ask before `swift build` or `swift test`** — per user preference.

---

## Related Work (not absorbed)

- **[`release-roadmap-swift-file-system.md`](../../../swift-institute/Research/release-roadmap-swift-file-system.md) §3** — where the Category B migration was originally identified as the resolution for Cycles 1 & 2. Category B completion closes Cycle 2 and unblocks Phase 2 of the roadmap.
- **[`ascii-serialization-migration.md`](../../../swift-institute/Research/ascii-serialization-migration.md)** — the full 8-phase `Parseable`/`Serializable` witness migration plan. DEFERRED post-release. Still the canonical plan for that work; this Category B plan explicitly does NOT supersede it for the migration itself.

---

## Superseded Sources (in swift-institute/Research/)

The following documents are superseded by this plan for Category B scope. Each has a header note pointing here.

| Source | Supersession scope |
|---|---|
| `swift-primitives/swift-ascii-primitives/Research/HANDOFF.md` | FULL — precursor to this plan; content absorbed. |
| `swift-institute/Research/handoff-ascii-domain-ownership-audit.md` | FULL — historical prior handoff (ASCII domain ownership); post-implementation, superseded by the audit below plus this plan. |
| `swift-institute/Research/ascii-domain-ownership-audit.md` | FULL — implementation audit of the Parser/Serializer split (Steps 0-5 on 2026-03-05); findings are either done or deferred, not Category-B-actionable. |
| `swift-institute/Research/ascii-parsing-domain-ownership.md` v4.2.0 | PARTIAL — the architectural principle ("domains as namespaces") is summarized in [Architecture Context](#architecture-context); the migration phasing is superseded. The broader document retains value for namespace design rationale. |
| `swift-institute/Research/ascii-parsing-adversarial-review.md` v2.0.0 | PARTIAL — retained as validation history for the domain-ownership decisions. Not a migration source. |
| `swift-institute/Research/ascii-serialization-migration.md` v2.0.0 | PARTIAL — the deferred full witness migration; this plan explicitly does NOT supersede its scope. |
| `swift-institute/Research/audits/implementation-naming-2026-03-20/swift-ascii-primitives.md` | TANGENTIAL — L1 naming audit (16 findings). Largely addressed per `Reflections/2026-04-03-pre-publication-audit-fixes-complete.md`. Not Category-B-actionable. |
| `swift-institute/Research/Reflections/2026-04-03-pre-publication-audit-fixes-complete.md` | TANGENTIAL — context for prior audit fixes touching swift-ascii. |
| `swift-institute/Research/Reflections/2026-04-04-darwin-primitives-kernel-narrowing.md` | TANGENTIAL — flags a latent MIV issue in `swift-ascii-parser-primitives` (action item carried forward: re-check `ASCII.Decimal.Parser` / `ASCII.Hexadecimal.Parser` for similar issues during Step 0). |

---

## Changelog

- **v3.0.0** (2026-04-16) — Audit at current state: all 22 Category B packages migrated with zero L3 `swift-ascii` references. Spot-built rfc-791, rfc-2045, rfc-5322, whatwg-url, iso-9945 — all clean. Steps 2–4 complete. Step 5 blocked by unrelated kernel/string-primitives API regression in swift-file-system. Remaining work listed in [Remaining Work Summary](#remaining-work-summary).
- **v2.0.0** (2026-04-08) — OQ1 resolved (B + α): INCITS-derived features → L2, F5 → L1, protocol → L1. Step 0 verification complete: corrected package groupings (12 protocol-only, 8 feature-blocked, 1 transitive, 1 verify). Found 109 conformances across 22 packages. Corrected 3 packages wrongly categorized by prior attempt (rfc-2387: now protocol-only; rfc-2822, rfc-7617: now feature-blocked).
- **v1.0.0** (2026-04-08) — Initial consolidation. Absorbed HANDOFF.md and scattered research sources. Plan was BLOCKED on OQ1 resolution.
