# Platform Compliance Audit — Prompt for New Chat

## Objective

Perform an ecosystem-wide inventory of compliance with the `/platform` skill ([PLAT-ARCH-*] and [PATTERN-001–008]) across all three superrepos. Produce a research document with every violation cataloged, assessed, and prioritized.

## Preparation

Before executing, load these skills in order:
1. `/platform` — the authoritative rules being audited
2. `/swift-institute` — five-layer architecture context
3. `/research-process` — document structure and methodology

Read the CLAUDE.md files at:
- `/Users/coen/Developer/CLAUDE.md`
- `/Users/coen/Developer/swift-institute/CLAUDE.md`

## Scope

All `.swift` source files in:

| Superrepo | Path | Layer |
|-----------|------|-------|
| swift-primitives | `/Users/coen/Developer/swift-primitives/` | L1 (Primitives) |
| swift-standards | `/Users/coen/Developer/swift-standards/` | L2 (Standards) |
| swift-foundations | `/Users/coen/Developer/swift-foundations/` | L3 (Foundations) |

Exclude: Tests/, Experiments/, the platform stack itself (swift-kernel-primitives, swift-darwin-primitives, swift-linux-primitives, swift-windows-primitives, swift-iso-9945, swift-darwin, swift-linux, swift-windows, swift-kernel). Those packages ARE the platform boundary — conditionals belong there by definition.

## Methodology

### Phase 1: Design the Search Strategy

Before grepping, think about what violations look like. The /platform skill defines these concrete rules for consumer packages (anything above the platform stack):

**[PLAT-ARCH-008] Consumer Import Rule** — the most likely violation:
- `#if canImport(Darwin)` / `#if canImport(Glibc)` / `#if canImport(Musl)` / `#if os(Linux)` / `#if os(macOS)` / `#if os(Windows)`
- `import Darwin` / `import Glibc` / `import Musl` / `import WinSDK`
- Any direct import of platform-specific modules (Darwin_Kernel_Primitives, Linux_Kernel_Primitives, etc.) outside the platform stack

**[PLAT-ARCH-002] Misplaced Platform Code**:
- Platform-specific syscall wrappers in consumer packages instead of the platform stack
- POSIX code in Darwin/Linux primitives instead of swift-iso-9945

**[PATTERN-004a] canImport for Platform Identity**:
- `#if canImport(Darwin)` used as platform identity check (should be `#if os(macOS) || ...`)
- This rule only applies WITHIN the platform stack, but check consumers aren't doing it at all

**[PATTERN-001] C Shim Violations**:
- Shared C headers with `#if defined(__APPLE__)` conditionals instead of per-platform shims

**[PATTERN-005] Swift Version / Build Settings**:
- Missing `swiftLanguageModes: [.v6]`
- Missing platform declarations
- Missing upcoming/experimental feature flags compared to ecosystem standard

### Phase 2: Execute the Search

Run these searches across all three superrepos (excluding the platform stack packages listed above):

```bash
# 1. Platform conditional compilation in consumer code
grep -rn '#if canImport(Darwin)\|#if canImport(Glibc)\|#if canImport(Musl)\|#if os(Linux)\|#if os(macOS)\|#if os(Windows)\|#if os(iOS)\|#if canImport(WinSDK)' Sources/

# 2. Direct platform module imports
grep -rn 'import Darwin$\|import Glibc$\|import Musl$\|import WinSDK$\|import Darwin_Kernel\|import Linux_Kernel\|import Windows_Kernel' Sources/

# 3. C library conditionals in shim headers
find . -name '*.h' -exec grep -l '#if.*__APPLE__\|#if.*__linux__\|#ifdef _WIN32' {} \;

# 4. Direct syscall usage bypassing Kernel
grep -rn 'open(\|close(\|read(\|write(\|stat(\|fstat(\|lstat(\|mkdir(\|rmdir(\|unlink(\|rename(' Sources/ --include='*.swift'
```

For each hit, determine:
- Is it inside the platform stack? → skip (expected)
- Is it in a consumer package? → VIOLATION — record it

### Phase 3: Assess and Categorize

For each violation:

| Field | Description |
|-------|-------------|
| **Package** | Which package contains the violation |
| **File:Line** | Exact location |
| **Rule violated** | [PLAT-ARCH-*] or [PATTERN-*] ID |
| **What it does** | Brief description of the platform-specific code |
| **Severity** | CRITICAL (blocks cross-platform), HIGH (leaks abstraction), MEDIUM (style/convention), LOW (cosmetic) |
| **Fix** | What should be done — move to platform stack, use Kernel import, delete dead code, etc. |
| **Blocked by** | If fixing requires changes to the platform stack first (missing Kernel abstraction) |

### Phase 4: Produce the Research Document

Write to: `/Users/coen/Developer/swift-institute/Research/platform-compliance-audit.md`

Follow [RES-003] template:
- Status: IN_PROGRESS (will be DECISION once violations are resolved)
- Tier 2 per [RES-020] — cross-package, precedent-setting
- Include summary statistics: total violations by severity, by rule, by superrepo
- Include a prioritized remediation plan
- Update `Research/_index.md` with the new entry

## Key Judgment Calls

1. **`#if !hasFeature(Embedded)` guards on Codable**: These are COMPLIANT per the platform skill's "Conditional Compilation Foresight" section. Do not flag them.

2. **`@_exported` re-exports**: Only flag if they re-export platform-specific modules from consumer packages. Re-exporting Kernel_Primitives from File System Primitives is correct.

3. **Package.swift platform conditions**: `.when(platforms: [...])` in SwiftPM dependency conditions is COMPLIANT per [PATTERN-004]. Only flag if a consumer package has a platform-conditional dependency that should be unconditional.

4. **Test files**: Include in inventory but mark as LOW severity — test-specific platform code is less impactful.

5. **Comments referencing platforms**: Not violations. Only code (imports, conditionals, syscalls) counts.

## Output

The research document should end with a clear summary like:

```
Total violations: N
  CRITICAL: X
  HIGH: Y
  MEDIUM: Z
  LOW: W

Top violating packages: ...
Most common violation: ...
Estimated remediation effort: ...
```

Return ONLY: "Wrote platform-compliance-audit.md to swift-institute/Research/"
