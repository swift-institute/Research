# Handoff: ASCII Domain Ownership & Transformation Architecture Audit

> **SUPERSEDED** (2026-04-08) for Category B migration scope — consolidated into
> [`../../swift-primitives/swift-ascii-primitives/Research/ascii-migration-category-b.md`](../../swift-primitives/swift-ascii-primitives/Research/ascii-migration-category-b.md).
> This is the 2026-03-05 prior handoff for the Parser/Serializer L1 split (now done).
> Retained for history.

<!--
---
version: 1.0.0
last_updated: 2026-03-05
status: SUPERSEDED
tier: 2
---
-->

## Purpose

This is a handoff prompt for a new session to audit and review the ASCII domain ownership implementation and its alignment with the broader transformation domain architecture decisions.

## What Was Done (Implementation Session — 2026-03-05)

### ASCII Domain Ownership Refactoring

The `Parser.ASCII.*` and `Serializer.ASCII.*` types in parser-primitives / serializer-primitives violated domain ownership (the parser/serializer doesn't own the ASCII domain). They were moved to subject-first naming under ASCII's own namespace, in dedicated bridge packages.

**Step 0 — Namespace additions to `swift-ascii-primitives` (Tier 0):**
- Added `ASCII.Decimal` and `ASCII.Hexadecimal` as empty enum namespaces
- Files: `Sources/ASCII Primitives/ASCII.Decimal.swift`, `ASCII.Hexadecimal.swift`
- Committed: `2cffca8`

**Step 1 — Created `swift-ascii-parser-primitives` (Tier 18, new package):**
- 4 targets: `ASCII Decimal Parser Primitives`, `ASCII Hexadecimal Parser Primitives`, `Parseable Integer Primitives`, `ASCII Parser Primitives` (umbrella)
- Types: `ASCII.Decimal.Parser<Input, T>`, `ASCII.Decimal.Error`, `ASCII.Hexadecimal.Parser<Input, T>`, `ASCII.Hexadecimal.Error`, `ASCII.Parser` (empty capability umbrella)
- 2 test targets (19 tests total, all passing)
- Dependencies: `swift-ascii-primitives` + `swift-parser-primitives`
- Private repo: `https://github.com/swift-primitives/swift-ascii-parser-primitives`
- Registered as submodule in `swift-primitives`
- Committed: `19eabf8`

**Step 2 — Created `swift-ascii-serializer-primitives` (Tier 18, new package):**
- 3 targets: `ASCII Decimal Serializer Primitives`, `Serializable Integer Primitives`, `ASCII Serializer Primitives` (umbrella)
- Types: `ASCII.Decimal.Serializer<T>`, `ASCII.Serializer` (empty capability umbrella)
- 1 test target (9 tests, all passing)
- Dependencies: `swift-ascii-primitives` + `swift-serializer-primitives`
- Private repo: `https://github.com/swift-primitives/swift-ascii-serializer-primitives`
- Registered as submodule in `swift-primitives`
- Committed: `1c52ba4`

**Step 3 — Removed old types from `swift-parser-primitives`:**
- Deleted: `Parser ASCII Integer Primitives` target + product (6 files), `Parseable Integer Primitives` target + product (2 files), test target
- Removed from `Parser Primitives` umbrella dependencies
- Umbrella `exports.swift` already did NOT re-export these (they were never in the umbrella exports)
- 163 remaining tests pass
- Committed: `cc964bf`

**Step 4 — Removed old types from `swift-serializer-primitives`:**
- Deleted: `Serializer ASCII Integer Primitives` target + product (4 files), `Serializable Integer Primitives` target + product (2 files), test target
- Removed from `Serializer Primitives` umbrella dependencies
- Committed: `0beebd5`

**Step 5 — Submodule registration:**
- Both new packages registered as submodules in `swift-primitives` parent repo
- Submodule pointers updated for `swift-ascii-primitives`, `swift-parser-primitives`, `swift-serializer-primitives`
- Parent repo commit: `fd57389`

**NOT done (deferred):**
- Downstream consumers in `swift-standards` not updated (3 files with now-stale imports — see below)
- Individual submodule pushes for `swift-ascii-primitives`, `swift-parser-primitives`, `swift-serializer-primitives` (committed locally, not pushed to their remotes)
- `swift-foundations` build verification

### Deviation from plan

The hex parser's `exports.swift` re-exports `Parser_Primitives_Core` + `ASCII_Primitives` (its actual Package.swift dependencies), NOT `ASCII_Decimal_Parser_Primitives` as the plan originally stated. The plan's export chain didn't match the dependency graph — hex has no dependency on decimal.

---

## Research Document Chain

Read these in order for full context. All in `/Users/coen/Developer/swift-institute/Research/`:

### Tier 1: Core Architecture Decisions

| Document | Version | Status | Scope |
|----------|---------|--------|-------|
| `transformation-domain-architecture.md` | v3.2.0 | **DECISION** | Three independent top-level domains (Parser, Serializer, Coder), package structure, protocol design, witness integration |
| `parsing-serialization-capability-organization.md` | v1.3.0 | RECOMMENDATION | From-first-principles analysis: three fundamental capabilities, three implementation strategies, domain namespace principle |
| `canonical-witness-capability-attachment.md` | — | DECISION | How canonical protocol conformers and closure-based witnesses coexist (10/10 experiment variants confirmed) |

### Tier 2: ASCII-Specific

| Document | Version | Status | Scope |
|----------|---------|--------|-------|
| `ascii-parsing-domain-ownership.md` | v4.2.0 | RECOMMENDATION | Why ASCII should own its transformation namespace, package structure, namespace design |
| `ascii-parsing-adversarial-review.md` | — | — | Adversarial challenges to v4.0; responses incorporated into v4.1/v4.2 |
| `ascii-serialization-migration.md` | — | DECISION | Migration plan for `Binary.ASCII.Serializable` (60+ conformances across ~30 packages) |

### Tier 3: Adoption and Implementation

| Document | Version | Status | Scope |
|----------|---------|--------|-------|
| `parsers-ecosystem-adoption-audit.md` | — | — | 95 opportunities, 52 HIGH across ~30 standards packages |
| `parsers-adoption-implementation-plan.md` | — | — | Phased plan for parser adoption |
| `next-steps-parsers.md` | — | — | Tracker for parser ecosystem work |

---

## The Three-Domain Architecture (DECISION)

This is the decided architecture from `transformation-domain-architecture.md` v3.2.0:

```
swift-parser-primitives (existing, Tier 17)
├── Parser.Protocol          — consume input → value
├── Parser.Printer           — prepend value → input (structural dual of Parser)
├── Parser.ParserPrinter     — parsing + printing conjunction
├── @Parser.Builder          — result builder for declarative composition
├── 33 combinator modules    — 18 have conditional Printer conformances
└── Parseable                — associated-type protocol (static var parser)

swift-serializer-primitives (renamed from swift-serialization-primitives)
├── Serializer.Protocol      — value → append to buffer (with Body/@Serializer.Builder)
├── Serializable             — associated-type protocol (static var serializer)
└── Serialization.*          — existing closure-based witness types (coexist)

swift-coder-primitives (new)
├── Coder.Protocol           — bidirectional decode + encode
│   ├── separate DecodeInput / EncodeBuffer types
│   ├── separate DecodeFailure / EncodeFailure types
│   └── no Body/Builder (leaf types)
└── Codable                  — associated-type protocol (shadows stdlib)
```

**Key relationships:**
- Parser ↔ Printer are structural duals (coupled, same package)
- Serializer has NO dual (independent, own package)
- Coder is independent (does NOT refine Parser or Serializer; separate failure types)
- Formatter is deferred (no protocol yet)
- Three implementation strategies are complementary: capability protocols (types that ARE parsers), witness types (types that HAVE parsing), domain protocols (types that CONFORM to format contracts)

---

## Current Implementation State (verified 2026-03-05)

### What exists in code

| Item | Status | Evidence |
|------|--------|----------|
| `Parser.Protocol` in parser-primitives | Done | `Parser Primitives Core/Parser.Parser.swift` |
| `Parser.Printer` in parser-primitives | Done | `Parser Primitives Core/Parser.Printer.swift` |
| `Parser.ParserPrinter` in parser-primitives | Done | `Parser Primitives Core/Parser.ParserPrinter.swift` |
| `Parser.Serializer` removed from parser-primitives | Done | Commit `a7e0703` ("remove Parser.Serializer") |
| `Parseable` in parser-primitives | Done | Commit `a7e0703` ("add Parseable") |
| `ParseOutput` → `Output` rename | Done | Commit `a7e0703` |
| `Serializer.Protocol` with Body/Builder | Done | Commit `db1d7ed` in serializer-primitives |
| `Serializable` in serializer-primitives | Done | Same commit |
| `@Serializer.Builder` | Done | Same commit |
| `Coder.Protocol` in coder-primitives | Done | Commit `39594f7`; has uncommitted modifications |
| `Codable` in coder-primitives | Done | Same commit; has uncommitted modifications |
| `ASCII.Decimal` / `ASCII.Hexadecimal` namespaces | Done | In ascii-primitives |
| `ASCII.Decimal.Parser<Input, T>` | Done | In ascii-parser-primitives |
| `ASCII.Hexadecimal.Parser<Input, T>` | Done | In ascii-parser-primitives |
| `ASCII.Decimal.Serializer<T>` | Done | In ascii-serializer-primitives |
| `ASCII.Decimal.Error` | Done | In ascii-parser-primitives |
| `ASCII.Hexadecimal.Error` | Done | In ascii-parser-primitives |
| `Parseable` integer conformances (10 types) | Done | In ascii-parser-primitives |
| `Serializable` integer conformances (10 types) | Done | In ascii-serializer-primitives |
| `Binary.Coder` conforms to `Coder.Protocol` | Unknown | Needs verification |

### Known deferred items

| Item | Tracking |
|------|----------|
| Downstream `swift-standards` consumer updates (3 stale imports) | Deferred — out of scope |
| `swift-ascii` (L3) restructuring: eliminate `Binary.ASCII` struct, `.ascii` wrappers, correct Machine IR namespace | `ascii-parsing-domain-ownership.md` Phase 4 |
| `Binary.ASCII.Serializable` migration (60+ conformances, ~30 packages) | `ascii-serialization-migration.md` (DECISION) |
| `.Parse` → `.Parser` naming unification across standards | Decided (`.Parser`), migration not started |
| Embedded Swift compatibility experiment | Open item in ascii-parsing-domain-ownership |
| Formatter.Protocol | Deferred until concrete use cases emerge |
| Ad-hoc serializers → `Serializer.Protocol` conformance migration | MEDIUM priority (R2 in capability-organization) |

---

## What to Audit

### 1. Implementation Correctness

Verify the new packages against the research:

- **Do `ASCII.Decimal.Parser` and `ASCII.Hexadecimal.Parser` correctly conform to `Parser.Protocol`?** Check generic constraints, `@inlinable`, typed throws, error types.
- **Does `ASCII.Decimal.Serializer` correctly conform to `Serializer.Protocol`?** Check Buffer type, Failure type, Body == Never.
- **Are the `Parseable` / `Serializable` integer conformances correct?** Check all 10 types, return types, `Parser.ByteInput` usage.
- **Do `exports.swift` files form correct re-export chains?** Each target should re-export its dependencies so consumers get a complete API from a single import.
- **Is the Package.swift dependency structure correct for both new packages?** Verify tier ordering, no upward/lateral violations.
- **Are the test suites adequate?** Compare coverage against the original tests in parser-primitives / serializer-primitives.

### 2. Research Alignment

Check whether implementation matches all DECISION-status research:

- **transformation-domain-architecture.md v3.2.0** — Is the three-package split (parser/serializer/coder) fully realized? Are the protocol designs correct (Output naming, Body/Builder presence/absence, failure types)?
- **ascii-parsing-domain-ownership.md v4.2.0** — Does the implementation match the recommended namespace structure? Subject-first naming? No intermediate `Integer` level?
- **Does `ASCII.Decimal.Error` live in the right place?** The research says "shared error type" — but currently it's only in the parser package. If `ASCII.Decimal.Serializer` is `Failure == Never`, that's fine. But verify.

### 3. Consistency Audit

Cross-reference with the broader ecosystem:

- **Does `binary-parser-primitives` (Tier 20) follow the same domain-ownership pattern?** It's the reference architecture — verify `ASCII.*` mirrors `Binary.*` structurally.
- **Does `swift-coder-primitives` have uncommitted modifications?** Git status showed dirty state. Review what changed and whether it's consistent.
- **Are there any remaining references to `Parser.ASCII.*` or `Serializer.ASCII.*` anywhere in the ecosystem?** Search all of `swift-primitives/`, `swift-standards/`, `swift-foundations/`.
- **Does the `Parser Primitives` umbrella `exports.swift` still NOT export the removed modules?** Verify no dangling re-exports.
- **Does the `Serializer Primitives` umbrella still work without the removed targets?**

### 4. Gap Analysis

Identify what's missing or inconsistent:

- **`ASCII.Hexadecimal.Serializer`** — Does hex need a serializer? The research doesn't mention one, but the namespace is open.
- **`ASCII.Decimal.Printer`** — Would round-trip decimal parsing ever be needed? Research says Printer stays Parser-internal. Verify this is appropriate for ASCII decimal.
- **Capability umbrella namespaces** — `ASCII.Parser {}` and `ASCII.Serializer {}` are defined but empty. Is there a concrete plan for what goes in them, or are they purely forward-looking?
- **`ASCII.Coder`** — Not mentioned in the implementation. Should there be one, given `Coder.Protocol` now exists?
- **`@retroactive` warnings** — The `Parseable` / `Serializable` conformances on stdlib integer types produce warnings. Is this acceptable or does it need addressing?

### 5. Documentation / Research Accuracy

The research documents contain some inaccuracies discovered during implementation:

- **`parsing-serialization-capability-organization.md` v1.3.0** repeatedly references `Parser.Serializer` as an existing protocol in parser-primitives — but it was already migrated to `Serializer.Protocol`. The research's Finding 1 table still says `Parser.Serializer` for Serialization capability. This needs correction.
- **`ascii-parsing-domain-ownership.md` v4.2.0** references "four capability protocols" (`Parser.Protocol`, `Parser.Serializer`, `Parser.Printer`, `Parser.ParserPrinter`) — but `Parser.Serializer` no longer exists. Should be three protocols plus the conjunction.
- **The research's "Package Structure" section** shows `ASCII.Decimal.swift` inside the parser package (`ASCII Decimal Primitives/ASCII.Decimal.swift`). The implementation correctly placed the namespace in `swift-ascii-primitives` (Tier 0) instead, as the plan specified. But the research text is misleading.

---

## Key File Locations

### New packages (implementation)
```
/Users/coen/Developer/swift-primitives/swift-ascii-parser-primitives/
/Users/coen/Developer/swift-primitives/swift-ascii-serializer-primitives/
```

### Modified packages
```
/Users/coen/Developer/swift-primitives/swift-ascii-primitives/
/Users/coen/Developer/swift-primitives/swift-parser-primitives/
/Users/coen/Developer/swift-primitives/swift-serializer-primitives/
```

### Coder package (pre-existing, has uncommitted changes)
```
/Users/coen/Developer/swift-primitives/swift-coder-primitives/
```

### Research documents
```
/Users/coen/Developer/swift-institute/Research/transformation-domain-architecture.md
/Users/coen/Developer/swift-institute/Research/parsing-serialization-capability-organization.md
/Users/coen/Developer/swift-institute/Research/ascii-parsing-domain-ownership.md
/Users/coen/Developer/swift-institute/Research/ascii-parsing-adversarial-review.md
/Users/coen/Developer/swift-institute/Research/ascii-serialization-migration.md
/Users/coen/Developer/swift-institute/Research/canonical-witness-capability-attachment.md
/Users/coen/Developer/swift-institute/Research/parsers-ecosystem-adoption-audit.md
/Users/coen/Developer/swift-institute/Research/parsers-adoption-implementation-plan.md
/Users/coen/Developer/swift-institute/Research/next-steps-parsers.md
```

### Reference architecture
```
/Users/coen/Developer/swift-primitives/swift-binary-parser-primitives/
```

### Downstream consumers with stale imports
```
swift-standards/swift-rfc-9110/Sources/RFC 9110/HTTP.Parse.swift          — imported but unused
swift-standards/swift-rfc-3986/Sources/RFC 3986/RFC_3986.Parse.swift      — imported but unused
swift-standards/swift-iso-8601/Sources/ISO 8601/ISO_8601.Parse.Digits.swift — comment reference only
```

---

## Verification Commands

```bash
# New packages
cd /Users/coen/Developer/swift-primitives/swift-ascii-parser-primitives && swift build && swift test
cd /Users/coen/Developer/swift-primitives/swift-ascii-serializer-primitives && swift build && swift test

# Modified packages
cd /Users/coen/Developer/swift-primitives/swift-parser-primitives && swift build && swift test
cd /Users/coen/Developer/swift-primitives/swift-serializer-primitives && swift build && swift test

# Search for stale references
grep -r "Parser\.ASCII\|Parser_ASCII_Integer\|Serializer\.ASCII\|Serializer_ASCII_Integer" /Users/coen/Developer/swift-primitives/ --include="*.swift" -l
grep -r "Parser\.ASCII\|Parser_ASCII_Integer\|Serializer\.ASCII\|Serializer_ASCII_Integer" /Users/coen/Developer/swift-standards/ --include="*.swift" -l
grep -r "Parser\.ASCII\|Parser_ASCII_Integer\|Serializer\.ASCII\|Serializer_ASCII_Integer" /Users/coen/Developer/swift-foundations/ --include="*.swift" -l
```
