# Release Roadmap: swift-file-system

**Date**: 2026-03-30
**Goal**: Release swift-file-system as a consumable SwiftPM package
**Status**: Inventory complete, cycle fix decided, migration map ready

---

## 1. Release Model

Each package is its own GitHub repo under the appropriate org. The local superrepos (swift-primitives/, swift-foundations/, etc.) are for development only.

| Org | Layer | Repos | Visibility | Has Repos |
|-----|-------|-------|------------|-----------|
| swift-primitives | L1 | 140 | Private | Yes |
| swift-incits | L2 | 0 | — | Empty |
| swift-iso | L2 | 0 | — | Empty |
| swift-ietf | L2 | 0 | — | Empty |
| swift-w3c | L2 | 0 | — | Empty |
| swift-whatwg | L2 | 0 | — | Empty |
| swift-ieee | L2 | 0 | — | Empty |
| swift-iec | L2 | 0 | — | Empty |
| swift-ecma | L2 | 0 | — | Empty |
| swift-standards | L2 (domain) | 102 | Public | Yes (currently also houses RFC/ISO/INCITS/W3C/etc.) |
| swift-foundations | L3 | 126 | Private | Yes |
| coenttb | (mixed) | 152 | Mixed | Yes (legacy — 19 overlap with ecosystem) |

---

## 2. Repo Migration Map

### 2a. swift-standards → specification-body orgs

These repos currently live under `swift-standards` but belong under their specification body's org. Transfer with `gh repo transfer` to preserve history.

**→ swift-ietf** (54 repos):

```
swift-bcp-47
swift-rfc-768  swift-rfc-791  swift-rfc-1034  swift-rfc-1035  swift-rfc-1123
swift-rfc-1950  swift-rfc-1951  swift-rfc-2045  swift-rfc-2046  swift-rfc-2183
swift-rfc-2369  swift-rfc-2387  swift-rfc-2388  swift-rfc-2822  swift-rfc-3339
swift-rfc-3492  swift-rfc-3596  swift-rfc-3986  swift-rfc-3987  swift-rfc-4007
swift-rfc-4122  swift-rfc-4287  swift-rfc-4291  swift-rfc-4648  swift-rfc-5234
swift-rfc-5321  swift-rfc-5322  swift-rfc-5646  swift-rfc-5890  swift-rfc-5952
swift-rfc-6068  swift-rfc-6238  swift-rfc-6265  swift-rfc-6455  swift-rfc-6531
swift-rfc-6570  swift-rfc-6750  swift-rfc-6891  swift-rfc-7230  swift-rfc-7231
swift-rfc-7232  swift-rfc-7233  swift-rfc-7234  swift-rfc-7235  swift-rfc-7301
swift-rfc-7405  swift-rfc-7519  swift-rfc-7578  swift-rfc-7617  swift-rfc-8058
swift-rfc-8200  swift-rfc-8259  swift-rfc-8446  swift-rfc-9110  swift-rfc-9111
swift-rfc-9112  swift-rfc-9293  swift-rfc-9557  swift-rfc-9562
swift-rfc-template
```

**→ swift-iso** (9 repos):

```
swift-iso-639  swift-iso-3166  swift-iso-8601  swift-iso-9899  swift-iso-9945
swift-iso-14496-22  swift-iso-15924  swift-iso-21320  swift-iso-32000
```

Note: swift-iso-9945 is NOT currently on GitHub under swift-standards. It only exists locally. Needs initial push to swift-iso.

**→ swift-incits** (1 repo):

```
swift-incits-4-1986
```

**→ swift-w3c** (6 repos):

```
swift-w3c-css  swift-w3c-cssom  swift-w3c-epub  swift-w3c-png  swift-w3c-svg  swift-w3c-xml
```

**→ swift-whatwg** (2 repos):

```
swift-whatwg-html  swift-whatwg-url
```

**→ swift-ieee** (1 repo):

```
swift-ieee-754
```

**→ swift-iec** (1 repo):

```
swift-iec-61966
```

**→ swift-ecma** (1 repo):

```
swift-ecma-48
```

**Remain under swift-standards** (19 domain-standard repos + meta):

```
swift-base62-standard  swift-color-standard  swift-css-standard  swift-domain-standard
swift-email-standard  swift-emailaddress-standard  swift-epub-standard  swift-html-standard
swift-ipv4-standard  swift-ipv6-standard  swift-json-feed-standard  swift-locale-standard
swift-numeric-formatting-standard (archived)  swift-pdf-standard  swift-rss-standard
swift-sockets-standard  swift-svg-standard  swift-time-standard  swift-uri-standard
swift-standards (meta)  .github
```

### 2b. coenttb → proper orgs

These 19 repos under `coenttb` overlap with ecosystem packages. Each needs evaluation: if the coenttb version has public history worth preserving, transfer it to the org (deleting the org placeholder first if needed).

**→ swift-foundations**:

| coenttb repo | Org repo exists | coenttb visibility | Action |
|-------------|----------------|-------------------|--------|
| swift-posix | swift-foundations/swift-posix (private) | PUBLIC | Transfer (preserves public history) |
| swift-darwin | swift-foundations/swift-darwin (private) | PUBLIC | Transfer |
| swift-linux | swift-foundations/swift-linux (private) | PUBLIC | Transfer |
| swift-windows | swift-foundations/swift-windows (private) | PUBLIC | Transfer |
| swift-kernel | swift-foundations/swift-kernel (private) | PRIVATE | Evaluate which has canonical history |
| swift-io | swift-foundations/swift-io (private) | PUBLIC | Transfer |
| swift-file-system | swift-foundations/swift-file-system (private) | PUBLIC | Transfer |
| swift-memory | swift-foundations/swift-memory (private) | PRIVATE | Evaluate |
| swift-html | swift-foundations/swift-html (private) | PUBLIC | Transfer |
| swift-css | swift-foundations/swift-css (private) | PUBLIC | Transfer |
| swift-svg | swift-foundations/swift-svg (private) | PUBLIC | Transfer |
| swift-epub | swift-foundations/swift-epub (private) | PRIVATE | Evaluate |
| swift-pdf | swift-foundations/swift-pdf (private) | PRIVATE | Evaluate |
| swift-identities | swift-foundations/swift-identities (private) | PUBLIC | Transfer |
| swift-translating | swift-foundations/swift-translating (private) | PUBLIC | Transfer |
| swift-copy-on-write | swift-foundations/swift-copy-on-write (private) | PUBLIC | Transfer |
| swift-defunctionalize | swift-foundations/swift-defunctionalize (private) | PRIVATE | Evaluate |
| swift-dual | swift-foundations/swift-dual (private) | PRIVATE | Evaluate |
| swift-buffer | ? | PRIVATE | Evaluate |

**→ swift-primitives**:

| coenttb repo | Org repo exists | Action |
|-------------|----------------|--------|
| swift-kernel-primitives | swift-primitives/swift-kernel-primitives (private) | PUBLIC → Transfer |
| swift-property-primitives | swift-primitives/swift-property-primitives (private) | PRIVATE → Evaluate |

### 2c. Transfer process (per repo)

```bash
# 1. If org already has a placeholder repo with no meaningful history, delete it first
gh repo delete <org>/<repo> --yes

# 2. Transfer the repo (preserves all history, stars, issues, redirects)
gh repo transfer coenttb/<repo> <org>
# or
gh repo transfer swift-standards/<repo> <org>

# 3. Update local git remote
cd /path/to/local/<repo>
git remote set-url origin https://github.com/<org>/<repo>.git
```

---

## 3. Dependency Cycles to Fix

### Architectural rule (decided)

> Standards (L2) depend on Primitives (L1) solely.
> Foundations (L3) depend on Standards (L2) or Primitives (L1).

### Cycle 1: swift-rfc-4648 (L2) → swift-ascii (L3)

**Current state**:
- 5 source files `import ASCII`
- `exports.swift`: `@_exported public import ASCII` (re-exports entire L3 module)
- Actual usage: character tables for base16/32/64 encoding

**Fix**: Replace `swift-ascii` dependency with `swift-ascii-primitives` (L1).
- Change `@_exported public import ASCII` → `@_exported public import ASCII_Primitives`
- Verify base encoding tables compile with only L1 ASCII types
- This changes RFC 4648's public API surface (consumers who relied on ASCII re-export will need to add their own ASCII dependency)

### Cycle 2: swift-iso-9945 (L2) → swift-ascii (L3)

**Current state**:
- 1 file: `ISO 9945.Kernel.File.Clone.swift`
- `internal import ASCII`
- Uses only `Binary.ASCII.equals.nulTerminated(...)` for path comparison

**Fix**: Remove `swift-ascii` dependency. Replace with inline byte comparison or a utility from `swift-ascii-primitives`.
- `Binary.ASCII.equals.nulTerminated` compares two nul-terminated C strings for ASCII equality
- This is a ~10 line function that can be inlined or moved to a primitives-level utility

### Cycle 3: swift-linux (L3) → swift-systems (L3) → swift-linux

**Current state**:
- `swift-linux/Sources/Linux Kernel/Linux.Thread.Affinity.swift`: `public import Systems`
- Uses `System.topology()` for NUMA-aware thread affinity
- Same pattern in `swift-windows`

**Fix options** (in order of preference):
1. **Move topology type to system-primitives (L1)**: The topology description is a data type, not platform-specific code. Platform packages populate it, systems provides the unified API.
2. **Move thread affinity to swift-systems**: Since affinity inherently needs the unified topology, put it in the package that owns topology.
3. **Break into core/full**: swift-systems-core (no platform deps) provides topology type; platform packages and swift-systems-full depend on core.

---

## 4. Semantic Triage: All Dependencies

### swift-file-system direct dependencies (9) — all correct

| # | Package | Layer | Used for | Verdict |
|---|---------|-------|----------|---------|
| 1 | swift-ascii | L3 | Path component parsing (`File.Path.Component.swift`) | Correct |
| 2 | swift-environment | L3 | Env variable resolution (`File.Path.swift`) | Correct |
| 3 | swift-kernel | L3 | Syscalls throughout | Correct |
| 4 | swift-paths | L3 | Path types | Correct |
| 5 | swift-strings | L3 | String handling for paths/content | Correct |
| 6 | swift-io | L3 | I/O engine (`File.Handle.swift`, `File.Read/Write`) | Correct |
| 7 | swift-algebra-primitives | L1 | Algebraic ops on directory iteration | Correct |
| 8 | swift-binary-primitives | L1 | Metadata, permissions, entry types, names | Correct |
| 9 | swift-rfc-4648 | L2 | Base64 for `File.Name` encoding | Correct |

### Transitive foundation dependencies (11 additional) — all correct

| # | Package | Verdict | Notes |
|---|---------|---------|-------|
| 1 | swift-posix | Correct | POSIX syscall layer |
| 2 | swift-darwin | Correct | macOS/iOS platform |
| 3 | swift-linux | Correct | Linux platform |
| 4 | swift-windows | Correct | Windows platform |
| 5 | swift-systems | Correct | Platform abstraction (cycle to fix) |
| 6 | swift-async | Correct | Async I/O |
| 7 | swift-memory | Correct | Memory management |
| 8 | swift-pools | Correct | Object pools |
| 9 | swift-witnesses | Correct | Macro infrastructure |
| 10 | swift-clocks | Correct | Clock types |
| 11 | swift-dependencies | Correct | Dependency injection |

### Standards dependencies (4) — 2 need cycle fix

| # | Package | Verdict |
|---|---------|---------|
| 1 | swift-incits-4-1986 | Clean (L1 only) |
| 2 | swift-iso-9899 | Clean (L1 only) |
| 3 | swift-iso-9945 | **Fix**: remove swift-ascii dep |
| 4 | swift-rfc-4648 | **Fix**: replace swift-ascii with swift-ascii-primitives |

### Primitives (~60+ packages) — correct by construction

All primitives depend only on other primitives (downward tier deps). No violations.

---

## 5. Release Ordering

Each package is an independent release. Dependencies must be released before dependents.

### Phase 0: Preparation

- [ ] Fix Cycle 1: swift-rfc-4648 → drop swift-ascii, use swift-ascii-primitives
- [ ] Fix Cycle 2: swift-iso-9945 → drop swift-ascii, inline or use primitives
- [ ] Fix Cycle 3: swift-linux/swift-windows → drop swift-systems (move topology or affinity)
- [ ] Execute repo migrations (Section 2)
- [ ] Update all Package.swift files: path deps → url + version deps for release

### Phase 1: Primitives (L1)

Release in tier order (leaf packages first). Approximate count for swift-file-system transitive closure: **~60 packages**.

**Tier 0 — leaf packages (no deps):**
```
swift-identity-primitives    swift-property-primitives    swift-serializer-primitives
swift-standard-library-extensions    swift-error-primitives    swift-random-primitives
swift-algebra-primitives     swift-ascii-primitives       swift-reference-primitives
swift-ownership-primitives
```

**Tier 1 — depend on tier 0:**
```
swift-equation-primitives    swift-comparison-primitives  swift-numeric-primitives
swift-formatting-primitives  swift-dependency-primitives  swift-cardinal-primitives
swift-hash-primitives        swift-ordering-primitives    swift-witness-primitives
swift-optic-primitives
```

**Tier 2+ — progressively higher tiers:**
```
swift-ordinal-primitives → swift-affine-primitives → swift-index-primitives →
swift-collection-primitives → swift-sequence-primitives → swift-buffer-primitives →
swift-memory-primitives → swift-bit-primitives → ...
```

Continue through all tiers until all transitive primitive deps of swift-file-system are released.

### Phase 2: Standards (L2)

After all required primitives are released:

```
swift-incits-4-1986     (depends on: ascii-primitives, standard-library-extensions, binary-primitives, parser-primitives, serializer-primitives)
swift-iso-9899          (depends on: error-primitives)
swift-iso-9945          (depends on: kernel-primitives, loader-primitives, string-primitives, clock-primitives, terminal-primitives)
swift-rfc-4648          (depends on: standard-library-extensions, binary-primitives, ascii-primitives)
```

These 4 can be released in parallel (no interdependencies after cycle fix).

### Phase 3: Foundations (L3)

Release in dependency order. Bottom-up:

**Wave 1 — depend only on L1 + L2:**
```
swift-strings           (string-primitives, swift-iso-9899)
swift-paths             (kernel-primitives, binary-primitives)
swift-witnesses         (swift-syntax + 6 primitives packages)
swift-posix             (swift-iso-9945)
```

**Wave 2 — depend on wave 1 + L1:**
```
swift-ascii             (swift-incits-4-1986 + 8 primitives)
swift-darwin            (swift-posix + 4 primitives)
swift-environment       (swift-kernel, swift-strings) — BLOCKED on swift-kernel
swift-kernel            (swift-posix, swift-darwin, swift-linux, swift-windows, swift-strings + 7 primitives)
```

**Wave 2 has a problem**: swift-kernel depends on swift-linux and swift-windows, which (currently) depend on swift-systems, which depends on swift-kernel path. After fixing cycle 3:

**Wave 2 (after cycle 3 fix):**
```
swift-ascii             (swift-incits-4-1986 + 8 primitives)
swift-darwin            (swift-posix + 4 primitives)
swift-linux             (swift-posix + 4 primitives)     ← no longer depends on swift-systems
swift-windows           (4 primitives)                    ← no longer depends on swift-systems
```

**Wave 3:**
```
swift-systems           (swift-darwin, swift-linux, swift-windows + system-primitives)
swift-kernel            (swift-posix, swift-darwin, swift-linux, swift-windows, swift-strings + 7 primitives)
swift-strings           (already in wave 1)
```

**Wave 4:**
```
swift-environment       (swift-kernel, swift-strings)
swift-memory            (swift-kernel, memory-primitives)
swift-pools             (swift-kernel, pool-primitives)
swift-clocks            (swift-kernel, clock-primitives)
```

**Wave 5:**
```
swift-dependencies      (swift-witnesses, swift-environment, clock-primitives)
```

**Wave 6:**
```
swift-async             (swift-clocks, swift-dependencies + 4 primitives)
```

**Wave 7:**
```
swift-io                (swift-kernel, swift-systems, swift-async, swift-memory, swift-pools, swift-witnesses + 16 primitives)
```

**Wave 8:**
```
swift-file-system       (swift-ascii, swift-environment, swift-kernel, swift-paths, swift-strings, swift-io, swift-rfc-4648 + 2 primitives)
```

---

## 6. Per-Package Release Checklist

For each package, before tagging:

### Code readiness
- [ ] All tests pass: `swift test` (in the package's own directory)
- [ ] No path dependencies on unreleased packages remain
- [ ] Package.swift has correct url + version deps for all dependencies
- [ ] Minimum platform versions set correctly
- [ ] Swift language mode and settings correct
- [ ] No layer violations in dependencies

### Repo readiness
- [ ] Repo is under correct org
- [ ] LICENSE file present
- [ ] Package.swift is at repo root
- [ ] .gitignore includes .build/
- [ ] No secrets or credentials committed

### Release mechanics
- [ ] Create git tag (semver: 0.1.0 for initial release)
- [ ] Verify clean clone + `swift build` succeeds
- [ ] Verify clean clone + `swift test` succeeds
- [ ] If this package has dependents waiting to release, notify/unblock them

### Dependency update
- [ ] After tagging, update dependents' Package.swift to reference this version
- [ ] Re-test dependents with the published version (not path dep)

---

## 7. Package.swift Dual-Mode Pattern

For development (superrepo) and release (individual repos) to coexist:

```swift
// At top of Package.swift:
let useLocalDeps = Context.environment["SWIFT_INSTITUTE_LOCAL"] != nil

// In dependencies array:
useLocalDeps
    ? .package(path: "../../swift-primitives/swift-binary-primitives")
    : .package(url: "https://github.com/swift-primitives/swift-binary-primitives.git", from: "0.1.0")
```

This allows `SWIFT_INSTITUTE_LOCAL=1 swift build` for superrepo development and plain `swift build` for published consumption.

---

## 8. Total Package Count for swift-file-system Release

| Layer | Package count | Status |
|-------|--------------|--------|
| L1 Primitives | ~60 | Need: release tags, url deps |
| L2 Standards | 4 | Need: cycle fix, repo transfer, release tags |
| L3 Foundations | 18 (incl. swift-file-system) | Need: cycle fix, repo transfer, release tags |
| External | 1 (swift-syntax) | Already released |
| **Total** | **~83** | |

---

## 9. Recommended Execution Order

1. **Fix cycles** (Section 3) — unblocks everything
2. **Transfer swift-standards L2 repos** to proper orgs (Section 2a) — can be scripted
3. **Transfer coenttb legacy repos** to proper orgs (Section 2b) — needs case-by-case evaluation
4. **Release L1 primitives** in tier order (Phase 1) — largest batch, most mechanical
5. **Release L2 standards** (Phase 2) — 4 packages, parallel
6. **Release L3 foundations** in wave order (Phase 3) — 8 waves to swift-file-system
7. **Verify end-to-end**: clean clone of swift-file-system resolves and builds
