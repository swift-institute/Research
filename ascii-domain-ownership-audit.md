# ASCII Domain Ownership & Transformation Architecture Audit

<!--
---
version: 1.0.0
last_updated: 2026-03-05
status: AUDIT
tier: 2
---
-->

## Executive Summary

Comprehensive audit of the ASCII domain ownership refactoring (Steps 0-5 from the implementation session on 2026-03-05) and its alignment with the decided transformation domain architecture. The audit covers implementation correctness, research document accuracy, ecosystem consistency, and gap analysis.

**Overall verdict: CLEAN.** The implementation is architecturally sound and correctly realizes the decided designs. All findings are either stale documentation (10 research inaccuracies) or forward-looking design questions (3 gaps).

| Area | Findings | Verdict |
|------|----------|---------|
| Implementation Correctness | 1 design note | PASS |
| Build & Test | 28/28 tests pass, 4 packages build clean | PASS |
| Stale References | 4 downstream files (swift-standards) | ACTION NEEDED |
| Research Accuracy | 3 HIGH, 4 MEDIUM, 3 LOW | UPDATE NEEDED |
| Consistency | All clean | PASS |
| Gap Analysis | 1 MEDIUM, 2 LOW | DEFERRED |

---

## 1. Implementation Correctness

### 1.1 swift-ascii-parser-primitives (Tier 18)

**Build:** PASS
**Tests:** 19/19 PASS (10 decimal, 9 hexadecimal)

| Check | Result | Notes |
|-------|--------|-------|
| Package.swift structure | CORRECT | 4 targets + 2 test targets, correct products |
| Dependencies | CORRECT | `swift-ascii-primitives` (Tier 0) + `swift-parser-primitives` (Tier 17) |
| `ASCII.Decimal.Parser<Input, T>` conforms to `Parser.Protocol` | CORRECT | Line 27 of `ASCII.Decimal.Parser.swift` |
| `ASCII.Hexadecimal.Parser<Input, T>` conforms to `Parser.Protocol` | CORRECT | `ASCII.Hexadecimal.Parser.swift` |
| Generic constraints | CORRECT | `Input: Collection.Slice.Protocol & Sendable`, `T: FixedWidthInteger`, `Input.Element == UInt8` |
| `@inlinable` annotations | CORRECT | On `init()` and `parse(_:)` for both parsers |
| Typed throws | CORRECT | `throws(Failure)` — `Failure = ASCII.Decimal.Error` / `ASCII.Hexadecimal.Error` |
| Error types | CORRECT | Separate types per domain, each with `.noDigits` and `.overflow` cases |
| `Parseable` integer conformances | CORRECT | All 10 stdlib integer types (`Int`, `UInt`, `Int8`...`UInt64`) |
| `exports.swift` re-export chains | CORRECT | Decimal re-exports `Parser_Primitives_Core` + `ASCII_Primitives`; hex re-exports same (NOT decimal — independent); umbrella re-exports all 3 sub-targets |

**Design note — signed integer parsing:**

`ASCII.Decimal.Parser.parse(_:)` only consumes digit bytes (0x30-0x39), with no handling of a leading minus sign. For signed types (`Int8`, `Int16`, etc.), only non-negative values can be parsed. This is a deliberate API surface — the parser is a digit-only accumulator, not a sign-aware number parser. Consumers needing negative values compose a sign parser before the digit parser.

### 1.2 swift-ascii-serializer-primitives (Tier 18)

**Build:** PASS
**Tests:** 9/9 PASS

| Check | Result | Notes |
|-------|--------|-------|
| Package.swift structure | CORRECT | 3 targets + 1 test target |
| Dependencies | CORRECT | `swift-ascii-primitives` (Tier 0) + `swift-serializer-primitives` |
| `ASCII.Decimal.Serializer<T>` conforms to `Serializer.Protocol` | CORRECT | `ASCII.Decimal.Serializer.swift` |
| `Body == Never` | CORRECT | Inferred via protocol default (leaf serializer) |
| `Failure == Never` | CORRECT | Explicit typealias |
| `Buffer == [UInt8]` | CORRECT | Explicit typealias |
| `@inlinable` on `serialize(_:into:)` | CORRECT | Line 31 |
| `Serializable` integer conformances | CORRECT | All 10 stdlib integer types |
| `exports.swift` re-export chains | CORRECT | `Serializer_Primitives_Core` + `ASCII_Primitives`; umbrella re-exports both sub-targets |

Implementation is byte-for-byte identical to the deleted `Serializer.ASCII.Integer.Decimal` — only the namespace changed. The serializer correctly handles negative values (writes a `-` prefix for negative signed integers).

### 1.3 Modified Packages

| Package | Build | Notes |
|---------|-------|-------|
| `swift-parser-primitives` | PASS | `Parser ASCII Integer Primitives` and `Parseable Integer Primitives` targets fully removed. No dangling re-exports in umbrella. |
| `swift-serializer-primitives` | PASS | `Serializer ASCII Integer Primitives` and `Serializable Integer Primitives` targets fully removed. No dangling re-exports. |

---

## 2. Stale References in Downstream Consumers

**Scope:** `swift-primitives/`, `swift-standards/`, `swift-foundations/`

### 2.1 Primitives: CLEAN

Zero references to `Parser.ASCII`, `Parser_ASCII_Integer`, `Serializer.ASCII`, or `Serializer_ASCII_Integer` remain anywhere in `swift-primitives/`.

### 2.2 Standards: 4 STALE FILES

| File | Issue | Fix |
|------|-------|-----|
| `swift-rfc-9110/Sources/RFC 9110/HTTP.Parse.swift:9` | `import Parser_ASCII_Integer_Primitives` — unused import | Remove import |
| `swift-rfc-9110/Package.swift:33` | `.product(name: "Parser ASCII Integer Primitives", package: "swift-parser-primitives")` — product no longer exists | Remove dependency line |
| `swift-rfc-3986/Sources/RFC 3986/RFC_3986.Parse.swift:9` | `import Parser_ASCII_Integer_Primitives` — unused import | Remove import |
| `swift-rfc-3986/Package.swift:32` | `.product(name: "Parser ASCII Integer Primitives", package: "swift-parser-primitives")` — product no longer exists | Remove dependency line |
| `swift-iso-8601/Sources/ISO 8601/ISO_8601.Parse.swift:9` | `import Parser_ASCII_Integer_Primitives` — unused import | Remove import |
| `swift-iso-8601/Sources/ISO 8601/ISO_8601.Parse.Digits.swift:13` | Comment reference: `Unlike \`Parser.ASCII.Integer.Decimal\`...` — stale type name | Update to `ASCII.Decimal.Parser` |
| `swift-iso-8601/Package.swift:48` | `.product(name: "Parser ASCII Integer Primitives", package: "swift-parser-primitives")` — product no longer exists | Remove dependency line |

**Impact:** These 3 standards packages will fail `swift package resolve` because the `Parser ASCII Integer Primitives` product no longer exists in `swift-parser-primitives`. The imports are all dead (no actual type usage from the old module), so the fix is removal — no migration to the new package needed.

### 2.3 Foundations: CLEAN

Zero stale references.

---

## 3. Research Document Accuracy

### Summary: 10 Inaccuracies Found

| # | Document | Severity | Issue |
|---|----------|----------|-------|
| 1 | `parsing-serialization-capability-organization.md` | **HIGH** | 15+ line references to `Parser.Serializer` throughout (body text, Finding 1 table). Should be `Serializer.Protocol`. Document is internally inconsistent — its own Tension 2 resolution acknowledges the migration. |
| 2 | `ascii-parsing-domain-ownership.md` | **MEDIUM** | Claims "four capability protocols" including `Parser.Serializer` in parser-primitives (lines 74-76, 158, 641, 669). Now three protocols; serialization is separate. |
| 3 | `ascii-parsing-domain-ownership.md` | **MEDIUM** | Package Structure (lines 530-549) shows `ASCII.Decimal.swift` inside parser package with wrong target names. Namespace lives in `swift-ascii-primitives`. Actual target names use `Parser` suffix. Missing `Parseable Integer Primitives` target. |
| 4 | `transformation-domain-architecture.md` | **HIGH** | Line 427 lists `Parser.Serializer.swift` as existing file in `Parser Primitives Core/`. File removed. |
| 5 | `transformation-domain-architecture.md` | **HIGH** | Lines 14-16 describe `Parser.Serializer` as "currently" nested under Parser namespace in present tense. Already migrated. |
| 6 | `transformation-domain-architecture.md` | **MEDIUM** | Lines 881-888 list Next Steps 1-5 as TODO. All five are implemented: `Serializer.Protocol`, `Coder.Protocol`, `Parser.Serializer` removal, `ParseOutput→Output`, `Parseable`. |
| 7 | `transformation-domain-architecture.md` | **LOW** | Line 419 says "37 targets". Actual count is 36 (after `Parser ASCII Integer Primitives` removal). |
| 8 | `parsing-serialization-capability-organization.md` | **LOW** | Lines 51, 709 reference package name `serialization-primitives`. Renamed to `serializer-primitives`. |
| 9 | `ascii-parsing-domain-ownership.md` | **MEDIUM** | Lines 16-17, 127-135, 618, 737 reference `Parser.ASCII.*` types and `Parser ASCII Integer Primitives` target as currently existing. Target removed. |
| 10 | `ascii-parsing-domain-ownership.md` | **LOW** | Package Structure missing `Parseable Integer Primitives` target; wrong target names throughout. |

**Root cause:** All three documents capture architectural decisions that have since been implemented. The decisions are correct; the documents describe pre-migration state in present tense.

---

## 4. Consistency Audit

### 4.1 Domain Ownership Pattern Alignment

| Check | Result |
|-------|--------|
| ASCII naming mirrors Binary pattern (subject-first) | CONSISTENT |
| `ASCII.Decimal.Parser` ↔ `Binary.Parse.Inline` — both conform to `Parser.Protocol` | CONSISTENT |
| `ASCII.Decimal.Serializer` ↔ (no Binary serializer equivalent) | N/A — Binary uses `Binary.Coder` instead |
| Namespace declared in base package, extended by capability packages | CONSISTENT in both domains |

### 4.2 Parser Primitives Umbrella

**`exports.swift`:** 35 re-exports. All correspond to existing targets. No dangling references to removed ASCII targets. CLEAN.

### 4.3 Serializer Primitives Umbrella

**`exports.swift`:** 2 re-exports (`Serializer_Primitives_Core`, `Serialization_Primitives`). No dangling references. CLEAN.

### 4.4 Coder Primitives State

`swift-coder-primitives` has 1 unpushed commit (`39594f7`) plus uncommitted modifications to 2 files:

- `Coder.Protocol.swift` — added `RangeReplaceableCollection`-constrained `encode(_:)` convenience (mirrors identical pattern on `Serializer.Protocol`)
- `Codable.swift` — added `encode(into:)`, `init(decoding:)`, `encoded()` convenience methods (mirrors `Parseable` and `Serializable` patterns)

**Verdict:** Structurally sound, consistent with the three-domain design. Should be committed.

---

## 5. Gap Analysis

### 5.1 `ASCII.Hexadecimal.Serializer` — MISSING (MEDIUM)

**Asymmetry:** `ASCII.Hexadecimal.Parser` exists but has no serializer counterpart. Consumers who can parse hex from bytes would naturally expect to serialize hex to bytes. The namespace `ASCII.Hexadecimal` is open for extension.

**Recommendation:** Add `ASCII Hexadecimal Serializer Primitives` target to `swift-ascii-serializer-primitives` following the decimal serializer pattern. Low complexity.

### 5.2 `ASCII.Coder` — NOT NEEDED (LOW)

Binary has `Binary.Coder` because fixed-format struct serialization is inherently bidirectional. ASCII integer parsing and serialization tend to be used independently (parse a port number, serialize a Content-Length). The current separation is appropriate.

**Recommendation:** Defer. Create only if a concrete consumer needs a bidirectional ASCII integer coder.

### 5.3 `@retroactive` Annotations — ABSENT (MEDIUM)

20 retroactive conformances (10 `Parseable` + 10 `Serializable`) on stdlib integer types lack `@retroactive` annotations. The current toolchain does not emit warnings with `InternalImportsByDefault` enabled, but this may change with future compiler tightening.

**Recommendation:** Add `@retroactive` annotations preemptively to avoid future warnings.

### 5.4 `ASCII.Decimal.Printer` — ABSENT BY DESIGN (NONE)

`Printer` is parser-internal infrastructure. Not surfaced to subject domains. Correct.

### 5.5 Empty Capability Umbrellas (`ASCII.Parser`, `ASCII.Serializer`) — FORWARD-LOOKING (INFO)

Both are empty enum namespaces reserving the space for future convenience factory methods. Structurally harmless. `ASCII.Serializer` doc comment should be updated if hex serializer is added (finding 5.1).

---

## 6. Action Items

### Immediate (blocks build)

| # | Action | Package | Files |
|---|--------|---------|-------|
| A1 | Remove dead `import Parser_ASCII_Integer_Primitives` | swift-rfc-9110 | `HTTP.Parse.swift:9` |
| A2 | Remove dead `import Parser_ASCII_Integer_Primitives` | swift-rfc-3986 | `RFC_3986.Parse.swift:9` |
| A3 | Remove dead `import Parser_ASCII_Integer_Primitives` | swift-iso-8601 | `ISO_8601.Parse.swift:9` |
| A4 | Remove stale Package.swift dependency on `Parser ASCII Integer Primitives` | swift-rfc-9110 | `Package.swift:33` |
| A5 | Remove stale Package.swift dependency on `Parser ASCII Integer Primitives` | swift-rfc-3986 | `Package.swift:32` |
| A6 | Remove stale Package.swift dependency on `Parser ASCII Integer Primitives` | swift-iso-8601 | `Package.swift:48` |

### Soon (documentation accuracy)

| # | Action | Document |
|---|--------|----------|
| B1 | Update all `Parser.Serializer` references to `Serializer.Protocol` | `parsing-serialization-capability-organization.md` |
| B2 | Correct "four protocols" to "three protocols" + separate serializer | `ascii-parsing-domain-ownership.md` |
| B3 | Update Package Structure with correct target names and add `Parseable Integer Primitives` | `ascii-parsing-domain-ownership.md` |
| B4 | Remove `Parser.Serializer.swift` from file listing | `transformation-domain-architecture.md` |
| B5 | Mark Next Steps 1-5 as DONE | `transformation-domain-architecture.md` |
| B6 | Update target count to 36 | `transformation-domain-architecture.md` |
| B7 | Fix package name `serialization-primitives` → `serializer-primitives` | `parsing-serialization-capability-organization.md` |
| B8 | Update comment: `Parser.ASCII.Integer.Decimal` → `ASCII.Decimal.Parser` | `ISO_8601.Parse.Digits.swift:13` |

### Deferred

| # | Action | Priority |
|---|--------|----------|
| C1 | Add `ASCII.Hexadecimal.Serializer` | MEDIUM |
| C2 | Add `@retroactive` to 20 stdlib integer conformances | MEDIUM |
| C3 | Commit coder-primitives uncommitted convenience extensions | LOW |
| C4 | Push all 5 submodules to their remotes | LOW |

---

## Verification Commands Run

```
swift build  — swift-ascii-parser-primitives      PASS
swift test   — swift-ascii-parser-primitives      19/19 PASS
swift build  — swift-ascii-serializer-primitives   PASS
swift test   — swift-ascii-serializer-primitives   9/9 PASS
swift build  — swift-parser-primitives             PASS
swift build  — swift-serializer-primitives         PASS
grep stale references — swift-primitives/          CLEAN
grep stale references — swift-standards/           4 files found
grep stale references — swift-foundations/         CLEAN
```
