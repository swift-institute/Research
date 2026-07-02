# Platform Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/platform/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> lint-enforcement scope detail, and the dated amendment changelog. The skill file remains the CANONICAL
> source for all `[PLAT-ARCH-*]` / `[PATTERN-*]` requirement statements; nothing in this archive is
> normative. Organized by rule ID in skill order; the dated frontmatter changelog entries are collected
> in the final section.

---

## §[PLAT-ARCH-001] Four-Level Platform Stack

**Stack diagram** (evicted from the skill; the level/package table remains in-skill):

```
L3  swift-kernel          (Foundations)   Unified cross-platform module
         ↑                                `import Kernel` — one import, any platform
         ├── swift-darwin    (Foundations)   Darwin L3: re-exports + Darwin-specific L3 code
         ├── swift-linux     (Foundations)   Linux L3: re-exports + Linux-specific L3 code
         └── swift-windows   (Foundations)   Windows L3: re-exports + Windows-specific L3 code
              ↑
L2  swift-iso-9945        (Standards)     POSIX specification — shared by Darwin + Linux
    swift-linux-standard   (Standards)    Linux kernel API spec (epoll, io_uring)
    swift-darwin-standard  (Standards)    Darwin/XNU kernel API spec (kqueue, mach)
    swift-windows-32       (Standards)    Windows kernel API spec / Win32 (IOCP, WinSock)
              ↑
L1  swift-kernel-primitives (Primitives)  Cross-platform syscall-shaped vocabulary
         ├── swift-cpu-primitives           CPU vocabulary (atomics, barriers, spin hints)
         └── swift-{loader,terminal,...}-primitives  Domain vocabulary
```

---

## §[PLAT-ARCH-002] Placement Decision Rules

**Additional incorrect-placement variants** (evicted; the L1-conditional variant remains in-skill):

```swift
// ❌ POSIX code duplicated in both Darwin and Linux primitives
// Belongs in swift-iso-9945

// ❌ Platform conditional in a consumer package (swift-io, swift-file-system)
#if canImport(Darwin)
import Darwin_Kernel_Standard  // Consumer should import Kernel, not platform modules
#endif
```

---

## §[PLAT-ARCH-003] Namespace Extension Pattern

**Extended correct example** (all five package variants):

```swift
// swift-linux-standard — extends it
extension Kernel.Event { public enum Poll {} }

// swift-darwin-standard — extends it
extension Kernel { public enum Kqueue {} }

// swift-windows-32 — extends it
extension Windows.`32`.Kernel.IO.Completion { public enum Port {} }

// swift-iso-9945 — additional extension
extension Kernel.Process { public enum Fork {} }
```

**Lint enforcement (full scope detail)**: `Lint.Rule.Platform.NamespaceRoot` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Platform`) flags top-level (file-scope) `EnumDeclSyntax` / `StructDeclSyntax` / `ClassDeclSyntax` whose name is a compound platform-prefix form: `<Platform>Kernel` / `<Platform>Kqueue` / `<Platform>Epoll` / `<Platform>IOCP` / `<Platform>IoUring` / `<Platform>EventNotification` where `<Platform>` ∈ `{Linux, Darwin, Windows}`. Bare compound kernel-keyword forms (`KqueueEventNotification` etc.) are also flagged. Nested declarations and `extension Kernel { ... }` are not in scope. Mechanical package-scope classification (is this package platform-specific?) is not feasible from a single file; the rule fires on the compound-name shape and trusts consumers to suppress for legitimate non-platform uses. Added Wave 4 mechanization 2026-05-11.

---

## §[PLAT-ARCH-004] Platform Root Namespaces

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` grep-checks each platform L2 spec package's `Sources/` for the required `public enum <Platform>` root namespace declaration (`Darwin` in `swift-darwin-standard`, `Linux` in `swift-linux-standard`, `Windows` in `swift-windows-32` / `swift-windows-standard`, `ISO_9945` in `swift-iso-9945`). Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-005] Cross-Platform Descriptor Unification

**Residual-case (b) reference pattern** (evicted; no platform currently matches this case after Wave 4c-Socket Prerequisite — POSIX has iso-9945, Win32 has windows-32. Kept for forward-compat with future platforms added without an L2 spec package):

```swift
// (b) L3-policy-canonical pattern (residual case — no L2 spec layer) — for reference only.
extension SomePlatform.Kernel {
    public struct Descriptor: ~Copyable {
        public var _raw: SomePlatform.Handle
        deinit { /* platform close policy */ }
    }
}
// L3-unifier typealiases directly to SomePlatform.Kernel.Descriptor.
```

**Additional incorrect variant** (platform-named descriptor types floating outside the typealias chain):

```swift
struct POSIXFileDescriptor { ... }     // Use ISO_9945.Kernel.Descriptor / POSIX.Kernel.Descriptor (typealias)
struct WindowsHandle { ... }           // Use Windows.`32`.Kernel.Descriptor / Windows.Kernel.Descriptor (typealias)
```

**Three-tier chain composition** (full text): The chain `Kernel.Descriptor → POSIX.Kernel.Descriptor → ISO_9945.Kernel.Descriptor` resolves at compile time to the L2 canonical struct via typealias transitivity, but each link in the chain composes ONE TIER DOWN. swift-kernel does NOT import or reference iso-9945/windows-32 directly — it imports swift-posix/swift-windows and references their typealiases. This satisfies [PLAT-ARCH-008e] (L3-unifier composes its peer L3-policy tier) and [PLAT-ARCH-008j] (Platform-C Import Authority — only L2 imports platform C; L3 packages reach platform C only transitively through L3-policy → L2).

**Source compatibility**: Cross-platform consumers writing `import Kernel; Kernel.Descriptor` see no change — the typealias resolves to the per-platform type at compile time, and extension methods declared once on the typealias name participate in extension-method dispatch identically on each platform. Verified empirically against Apple Swift 6.3.1 / macOS 26 with the `~Copyable` typealias + cross-module extension probe (matrix: A-leg × B-leg × single-module × cross-module × debug × release = 8/8 passes).

**Round-trip elimination mechanism**: With L2-canonical Descriptor, an L3-policy throwing wrapper that owns a typed Descriptor passes it directly (consuming or borrowing) to the L2 typed syscall form. The previous pattern — L3 extracts `descriptor._rawValue` (Int32), calls L2 raw `(_:Int32)` form, L2 typed form (when present) reconstructs an L2 Descriptor via `init(_rawValue:)` — collapses to a single typed call across the L2/L3 boundary. This is the architectural enablement for the typed-everywhere directive ([PLAT-ARCH-005a] revised + [PLAT-ARCH-008j]); without L2-canonical Descriptor, every L3 → L2 typed call requires an `init(_rawValue:)` round-trip that re-introduces the raw integer at the boundary.

**Rationale (full text)**: The unification point lives at the layer where the type's canonical home actually is. For platforms with an L2 spec layer (POSIX, Win32), the spec layer IS the architectural home for the descriptor type — the syscalls are spec-defined, the storage is spec-defined, the type belongs there. Hosting the type at L3 and typealiasing back to L2 (the previous arrangement, before Wave 4c-Socket Prerequisite) inverted the dependency: L3 owned the type that L2 needed for its own typed syscall signatures, forcing L2 raw signatures or round-trip patterns. L2-canonical Descriptor restores the natural placement and eliminates the round-trip class of problems wholesale.

The earlier "L3-policy hosts the type, L1 deletion" framing was correct in spirit (no L1 carve-out, no `#if os(...)` at L1) but suboptimal in placement: L3-policy hosting was the right move from L1, but L2 is the architecturally correct destination when a spec layer exists. Wave 4c-Socket Prerequisite (2026-05-01) corrected the placement.

**Provenance**:
- `swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions.md` (2026-04-26, RECOMMENDATION; § 8.1) — original L1 deletion + L3-policy placement.
- 2026-05-01 Wave 4c-Socket Prerequisite — duplicate Descriptor defect (parallel `ISO_9945.Kernel.Descriptor` + `POSIX.Kernel.Descriptor` ~Copyable structs at L2 and L3 respectively) blocked Wave 4c typed-everywhere refactor at iso-9945 Socket; user authorized Path (C) consolidation: promote L2 to canonical, collapse L3 to typealias, codify the L2-canonical-where-spec-layer-exists tiered rule.

**Implementation note**: the L2 canonical struct exposes `@_spi(Syscall) public init(_rawValue:)` and `var _rawValue: Int32` for raw-fd construction / extraction by syscall-implementation layers (historical shape; see [PLAT-ARCH-008j] migration debt for the SPI phase-out).

---

## §[PLAT-ARCH-005a] No Platform C Types in Public API

**Additional correct variant** (singular overload):

```swift
public static func register(
    _ kq: borrowing Kernel.Descriptor,
    event: Kernel.Kqueue.Event           // ✓ Singular overload, ecosystem type
) throws(Kernel.Kqueue.Error)
```

**Rationale (full text)**: [PLAT-ARCH-005] established the principle for descriptors — `Kernel.Descriptor` wraps `Int32`/`HANDLE` so consumers never see the raw type. The same principle applies to all platform types. C types in public APIs force consumers to understand platform-specific representations, defeating the purpose of the typed wrapper layer. The SPI exception was a Path X transitional accommodation (per [PLAT-ARCH-019], now superseded) that allowed cross-package-stack power-user reach via `@_spi(Syscall)` raw forms; empirical experiment (`swift-institute/Experiments/spi-syscall-phase-out-layering/`, 2026-04-30, CONFIRMED) demonstrated that legitimate raw-FFI use cases are served by L2 internal/private scope without any exposed surface, eliminating the need for the SPI exception.

The rule-body note on migration scope: the pre-existing `@_spi(Syscall)` raw companion sites (~36 across iso-9945 + windows-standard at the time of the 2026-04-30 revision) were queued for retirement in post-Path-X Tier 2 cleanup. (Later empirical recount at [PLAT-ARCH-008j]: ~333 annotations, ~110+ public-function declarations.)

**Provenance**: Experiment `swift-institute/Experiments/spi-syscall-phase-out-layering/` (2026-04-30, CONFIRMED V2-private-at-L2 + user disposition refuting V5-L3-policy-libc-binding); recommendation document at `swift-institute/Research/spi-syscall-phase-out-layering.md`.

**Lint enforcement (full scope detail)**: `Lint.Rule.Platform.CTypeInPublicAPI` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Platform`) walks `FunctionDeclSyntax` / `InitializerDeclSyntax` with `public` / `open` modifiers and recursively descends parameter and return types looking for identifiers in a curated C-type set (`kevent`, `epoll_event`, `OVERLAPPED`, `sockaddr`, `iovec`, `io_uring_sqe`, `io_uring_cqe`, `timespec`, `pid_t`, `HANDLE`, `DWORD`, `WCHAR`, `BOOL`, `LPVOID`, `WSABUF`, `msghdr`, `cmsghdr`, `ifreq`, `sockaddr_in*`, `sockaddr_un`, `stat`, `statfs`, `dirent`, `passwd`). Generic-argument wrappers (`UnsafePointer<kevent>`), optionals, and arrays are descended. Non-public visibility (`internal`, `private`, `fileprivate`, `package`) is exempt. Added Wave 4 mechanization 2026-05-11.

---

## §[PLAT-ARCH-006] Re-Export Chain Architecture

**Consumer-view chain diagram** (evicted; the unification-file example remains in-skill):

```
import Kernel                              ← consumer writes this
  └─ @_exported Kernel_Primitives          ← cross-platform primitives
  └─ @_exported POSIX_Kernel               ← (Darwin/Linux only)
  └─ @_exported Darwin_Kernel              ← (Darwin only)
       └─ @_exported Darwin_Kernel_Standard
```

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` greps each L3 platform package's `Sources/` for `@_exported public import` lines and confirms at least one module-name match for the expected L2 spec prefix (`Darwin_*` in `swift-darwin`, `Linux_*` in `swift-linux`, `Windows_32_*` in `swift-windows`, `ISO_9945_*` in `swift-posix`). A package missing the re-export is structurally broken — consumers cannot reach the L2 spec layer via the L3 unified surface. Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-007] POSIX Code Belongs in ISO 9945

**Diagram** (evicted):

```
                    swift-iso-9945 (POSIX)
                    ┌─────────────────────┐
                    │ Kernel.Signal       │
                    │ Kernel.Process.Fork │
                    │ Kernel.Memory.Map   │
                    │ Kernel.Socket       │
                    │ Kernel.Pipe         │
                    │ Kernel.Termios      │
                    └─────────┬───────────┘
                       ↗              ↖
    swift-darwin-standard    swift-linux-standard
    (kqueue, mach)             (epoll, io_uring)
```

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` greps `swift-darwin-standard` and `swift-linux-standard` sources for direct calls to a curated list of POSIX-shared syscalls (fork/wait/exec, signal/sigaction/kill/raise/alarm, pipe/socket/bind/listen/accept/connect/send/recv/shutdown, mmap/munmap/mprotect/msync/madvise/mlock, canonical pthread ops). Detection regex is `\b<call>\s*\(` — high-precision (matches the call form, not bare references). Linux-specific (io_uring_*, epoll_*) and Darwin-specific (kqueue/kevent/mach_*) syscalls are excluded from the list, so wrapping them in their respective L2 packages is correct and not flagged. Wave 1 mechanization 2026-05-10 added fixture-based regression tests at `swift-institute/.github/.github/scripts/tests/fixtures/plat-arch-007/`.

---

## §[PLAT-ARCH-008] Consumer Import Rule

**Additional incorrect variant** (platform conditionals in consumer logic):

```swift
#if os(Linux)
let events = try Kernel.Event.Poll.wait(...)
#elseif os(macOS)
let events = try Kernel.Kqueue.kevent(...)
#endif
```

**Lint enforcement (full scope detail)**: Reusable workflow `validate-layer-deps.yml` greps non-platform-stack packages' `Sources/` for `import Darwin_Kernel_Standard` / `import Linux_Kernel_Standard` / `import Windows_32_Core` / `import ISO_9945_Core` (L2 spec module names) and `import Darwin_Kernel` / `import Linux_Kernel` / `import Windows_Kernel` / `import POSIX_Kernel` (L3-policy module names); flags any such import. A package is "in the platform stack" if it appears in the explicit registry (L1 platform primitives, L2 spec, L3-policy/unifier/domain) OR its Package.swift declares a dep on a platform package — the latter signals a domain-specific L3-unifier per [PLAT-ARCH-021] without forcing the registry to enumerate every domain unifier. The companion raw-libc-import rule ([PLAT-ARCH-008j]) catches the stricter Darwin/Glibc/Musl/WinSDK import case. Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-008a] Domain Authority Exception (Limited)

**Full hard-line code form** (the four-import within-stack variant, merged in-skill):

```swift
// ❌ ALWAYS wrong: raw platform imports OUTSIDE L2 spec packages
import Darwin   // Forbidden in non-platform-stack packages AND in L3-policy / L3-unifier / L3-domain
import Glibc    // Same
import Musl     // Same
import WinSDK   // Same
```

**Rationale (full text)**: The platform stack abstracts raw syscall interfaces. But domain packages that own platform-varying concepts (path separators, event loop strategies, character encodings) are the natural home for composing those abstractions differently per platform. Forcing all platform conditionals into Kernel would make Kernel absorb domain logic from every consumer, violating separation of concerns in the opposite direction. The within-platform-stack tightening (2026-04-30) reflects user-disposed strict separation: L2 owns spec encoding (including raw libc binding); L3-policy adds policy on top of L2 typed API (no direct libc reach); L3-unifier provides cross-platform name composing typed L2/L3-policy.

---

## §[PLAT-ARCH-008b] Conditional Public API Surface in L3

**Why not unconditional?**: `Kernel.Signal.Error` is defined in `swift-iso-9945` (L2 POSIX standard). Windows has no dependency on `swift-iso-9945`. Creating a stub `Signal.Error` in `swift-kernel-primitives` (L1) would add a signal error type on a platform with no signals — violating the principle that L1 types represent genuine domain concepts.

**Why not absorb into `.platform`?**: The `.signal` case carries semantic meaning distinct from `.platform` — it represents signal-specific operations (`sigaction`, `kill`, `raise`), not generic unmapped errors. Absorbing it would lose domain specificity on POSIX platforms.

**Prior art**: Apple's `swift-system` uses the same pattern — `#if os(...)` on ~20 of 224 `Errno` properties where the underlying POSIX concept is genuinely absent on a platform.

**Provenance**: Research document `swift-kernel/Research/conditional-compilation-public-enum-cases.md` (2026-03-24).

---

## §[PLAT-ARCH-008c] L1 Primitives Are Unconditionally Platform-Agnostic

**Transition note (2026-05-01, supersedes 2026-04-27)**: the rule's "no L1 exceptions" clause names `Kernel.Descriptor`, `Kernel.Process.ID`, and `Kernel.Directory.Entry` as types that MUST relocate per [PLAT-ARCH-005]. The Descriptor relocation completed via Wave 4c-Socket Prerequisite (2026-05-01): L2-canonical placement per the revised [PLAT-ARCH-005] tiered rule (L2 spec layer when one exists, else L3-policy). Process.ID and Directory.Entry follow-on cycles inherit the L2-canonical-where-spec-layer-exists pattern when their cascade resolves. See `swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions-l2-cascade.md` (INVESTIGATION) for the original cascade analysis. (An earlier 2026-04-27 transition note recorded the descriptor migration as DEFERRED pending the L2 spec-wrapper cascade refactor scope decision; the rule text always described the canonical end-state.)

**Second correct example** (divergent-shape type defined per L3-policy + unified by L3 typealias — evicted as redundant with the [PLAT-ARCH-005] in-skill example):

```swift
// L3-policy: swift-posix — native fd shape and POSIX close policy
extension POSIX.Kernel {
    public struct Descriptor: ~Copyable {
        public let _rawValue: Int32
        deinit { _ = close(_rawValue) }
    }
}

// L3-unifier: swift-kernel/Sources/Kernel/Exports.swift — name unified per [PLAT-ARCH-005]
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public typealias Kernel_Descriptor = POSIX.Kernel.Descriptor
#elseif os(Windows)
    public typealias Kernel_Descriptor = Windows.Kernel.Descriptor
#endif
```

**Second incorrect example** (platform-conditional type definition at L1 — the eliminated Descriptor exception):

```swift
// ❌ In swift-kernel-primitives — platform-conditional type definition
extension Kernel {
    public struct Descriptor: ~Copyable {
        #if os(Windows)
        public let _rawValue: UInt          // Windows HANDLE shape
        #else
        public let _rawValue: Int32         // POSIX fd shape
        #endif
        // platform-conditional deinit, etc.
    }
}
```

**Why this is stronger than [PLAT-ARCH-008a]**: The domain authority exception permits `#if os()` at L3 (Foundations) where the platform stack cannot reasonably absorb the logic. This rule goes further for L1 (Primitives): platform-specific behavior AND platform-specific type shape MUST be pushed to platform packages entirely, using the re-export chain (for behavior) or the L3-typealias unification chain (for divergent type shape) to make the per-platform definitions visible to cross-platform consumers. L1 primitives stay unconditionally platform-agnostic — uniform storage shape, uniform implementation, no carve-out.

**Mechanism**: The `Kernel_Primitives` re-export chain (`@_exported public import Path_Primitives`) makes lower-layer types visible in platform packages without adding direct dependencies. Extensions defined in `ISO_9945_Kernel` or `Windows_Kernel_Standard` are visible to any consumer that imports `Kernel`. For divergent-shape types, the L3-unifier package's `Exports.swift` adds a `#if os(...)`-guarded typealias resolving the cross-platform name to the appropriate L3-policy type — the typealias mechanism is the canonical [PLAT-ARCH-005] / [PLAT-ARCH-008e] pattern, not a new mechanism.

**Provenance**: Path decomposition architecture decision (2026-04-01). `Path.View.parentBytes`, `.lastComponentBytes`, `.appending` moved from `swift-path-primitives` to `swift-iso-9945` (POSIX) and `swift-windows-standard` (Windows). 2026-04-26 strengthening: `swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions.md` (RECOMMENDATION; § 8.2) — eliminates the implicit Descriptor exception and adds the type-definition clause. Within-L3 sub-tier framing per `swift-institute/Research/lateral-l3-to-l3-composition-options.md` (2026-04-26, STAMPED).

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` greps every `*-primitives` package's `Sources/` for `^#if (os|canImport)` and flags occurrences (`swift-kernel-primitives` and `swift-cpu-primitives` exempt per [MOD-EXCEPT-001]). Added Wave 2b finalization 2026-05-10. Wave 1 mechanization 2026-05-10 added fixture-based regression tests at `swift-institute/.github/.github/scripts/tests/fixtures/plat-arch-008c/` (pass/fail/edge scenarios) and a `tests/run.sh` runner; same revision fixed a path-filter bug that spuriously hid `.swift` files when fixtures live under a `.github` parent.

---

## §[PLAT-ARCH-008d] Syscall vs Policy Test for L3 Domain Packages

**Architectural background (framing prose)**: Both roles sit at L3. The unification packages absorb platform variation where the consumer shouldn't see it. The domain packages absorb platform variation where the consumer must see it. A unification package that adds policy is out of role; a domain package that dispatches syscalls directly is out of role.

**Examples — L3 domain conditionals classified** (evicted worked-example table):

| Site | Category | Destination |
|------|----------|-------------|
| `File.System.Metadata.Permissions` (chmod bits vs ACLs) | Policy — the permission model itself differs | Stays in swift-file-system |
| `File.System.Metadata.Ownership` (uid/gid vs SIDs) | Policy — the ownership model differs | Stays in swift-file-system |
| `File.System.Delete` (unlink vs `DeleteFileW` dispatch) | Syscall — consumer sees "delete file" either way | Push to `swift-kernel` |
| `File.System.Link.Read.Target` (readlink vs `GetFinalPathNameByHandle`) | Syscall — consumer sees "read link target" either way | Push to `swift-kernel` |
| `File.System.Write.Atomic.Error` / `Write.Streaming.Error` (errno vs GetLastError mapping) | Syscall — error-code → error-enum mapping | Push to `swift-kernel` (`Kernel.Error` absorbs platform taxonomy) |
| `File.Name` internal encoding (UTF-8 vs UTF-16 strict decode) | Representation — consumer sees unified `File.Name` type | Push decoder to `swift-strings` (`Swift.String.strict(platformNative: [Path.Char])`); File.Name's internal `#if` collapses |

**Ideal state**: An L3 domain package has `#if os(...)` ONLY for genuine policy that the consumer observes. Zero `#if`s in a domain package means its policy is platform-neutral and all syscall variation is unified upstream. Some `#if`s will remain where the policy itself genuinely differs (permission models, ownership models) — these are legitimate; removing them would make the domain less accurate, not more portable.

**Provenance**: Reflection `2026-04-20-file-name-nul-fix-execution-and-path-char-adoption.md`. User correction during session: "swift-file-system should ideally not have any platform checks, as syscall unification should happen at swift-kernel. However, swift-kernel does unification but cannot add policy/opinion, and it is swift-file-system that adds the policy/opinion and features."

---

## §[PLAT-ARCH-008e] L3 Unifier Composition Discipline

**Architectural background (framing prose)**: The unifier's role is to collapse platform variation while inheriting what the L3 platform tier has already normalized. Reaching two tiers down — from swift-kernel straight to L2 raw, bypassing swift-posix — forces every consumer wanting normalized behavior to hand-dispatch through the L3 platform tier via namespace-specific imports (e.g., `POSIX.Kernel.*`). That hand-dispatch is exactly what the unifier exists to eliminate.

**Windows twin of the in-skill correct example**:

```swift
// swift-kernel, file-level Windows guard
extension Kernel.File.Flush {
    public static func flush(_ fd: borrowing Kernel.Descriptor) throws(Error) {
        try Windows.Kernel.File.Flush.flush(fd)   // Windows has no EINTR; pass-through acceptable
    }
}
```

**L3-tier emptiness determination (POSIX/Windows narrative)**: for the empty-tier exception to apply, L2 and L3 method names MUST be disjoint at the same namespace. For swift-posix, Phase-A rename of iso-9945 `flush` → `fsync` ensures disjointness (L2 `fsync` vs L3 `flush`), so L3 is non-empty. For swift-windows, no Phase A rename occurs (no retry policy justifies L2 renaming), so the tier is necessarily empty for any name L2 already claims. The symmetry between POSIX and Windows at L3 is aesthetic; the layering reality is asymmetric by design, because the need for L3 policy wrapping is asymmetric (POSIX has EINTR, Windows does not).

The namespace-identity planning check is codified in the skill because the first application of the rule surfaced the choice (i)/(ii) infeasibility mid-execution (provenance: `2026-04-20-kernel-file-flush-plat-arch-008e-execution.md`).

**Rationale (full text)**: The 2026-04-20 swift-file-system Platform Compliance audit surfaced `Kernel.File.Flush.flush(_:)` resolving to iso-9945's raw fsync via namespace-alias extension, while swift-posix's policy-wrapped `POSIX.Kernel.File.Flush.flush(_:)` existed alongside it. Consumers who wanted retry had to hand-dispatch through `POSIX.Kernel.*` — the manual dispatch a cross-platform unifier is designed to eliminate. The pattern is not unique to Flush: any L2 method inherited via namespace alias silently leaks raw behavior through the unifier whenever a policy wrapper exists beside it. Codifying the invariant makes it auditable.

**Provenance**: Codified during the 2026-04-20 swift-file-system Platform Compliance audit (reflection `2026-04-20-l3-unifier-composition-discipline.md`), then first applied in the flush-family relanding (reflection `2026-04-20-kernel-file-flush-plat-arch-008e-execution.md`, commits `639a428`, `ba678e3`, `fd315d4`, `f541a08`, `0618331`). The first application surfaced the namespace-identity corollary.

---

## §[PLAT-ARCH-010] Platform Package Reference

**Namespace-anchor L2 placement reasoning**: Despite being platform-specific by name (each anchor is tied to one platform), anchors ARE L2 (NOT L1) because (a) [PLAT-ARCH-008c] reserves L1 for unconditionally platform-agnostic vocabulary, and (b) the anchor's role is to host the root namespace under which platform-specific L2 specs are encoded — that's an L2 spec-host concern, not an L1 vocabulary concern. The anchor's L2 placement is consistent with the L2 layer being where platform-specific declarations live.

**Reserved-status history**: Currently no namespace anchor packages exist (Windows has only swift-windows-32; Linux has only swift-linux-standard; Darwin has only swift-darwin-standard). Current state post-Wave-2 Tier 1a: `Windows` is declared in `swift-windows-32/Sources/Windows 32 Core/Windows.swift`. User disposition 2026-04-30 deferred Wave 0 (anchor-package creation) on the POSIX side because no second-spec L2 is currently planned.

---

## §[PLAT-ARCH-011] `Swift.Error` Qualification (Always)

**Why "always", not just `.Error` namespaces (full text)**: The original (2026-03-20) rule was scoped to `extension X.Error` blocks because that is the most ambiguity-prone context (where bare `Error` resolves to the enclosing namespace and breaks type resolution). The user broadened the convention 2026-05-05 during the Phase 1.5 SwiftLint canary review: *"Also in those cases we should likely just have Swift.Error everywhere."* Always-qualifying eliminates the per-context judgment call and makes code copyable across contexts without re-evaluation.

**Provenance**: Original — Reflection `2026-03-20-pass4-compound-renames-and-generic-nesting.md`. Broadened — User feedback 2026-05-05 during Phase 1.5 canary review (7 hits across swift-tagged-primitives + swift-carrier-primitives + swift-property-primitives, all real work items).

**Lint enforcement (full scope detail)**: The Tier 1 SwiftLint custom rule `swift_error_qualification` (regex `\b(?<!Swift\.)(?<!\.)Error\b(?!\.)`) catches violations; the rule is a warning but `--strict` in `swift-ci.yml` gates it. The AST counterpart `Lint.Rule.Platform.SwiftQualification` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Platform`) walks type-position syntax — `InheritedTypeSyntax`, `GenericParameterSyntax`, `ConformanceRequirementSyntax`, `SomeOrAnyTypeSyntax` — and flags any leaf identifier `Error` that is not Swift-prefixed; member-type accesses like `MyDomain.Error` are exempt.

---

## §[PLAT-ARCH-012] Vocabulary / Spec / Composition Principle

**Provenance**: io_uring implementation session (2026-04-10), `iso-9945/Research/platform-stack-layering-linux-primitives-role.md`.

---

## §[PLAT-ARCH-013] Shell + Values OptionSet Pattern

**Boolean init extensions** for guided call-site ergonomics (evicted supplementary example):

```swift
// L2 — boolean init references statics, not platform constants [IMPL-002]
extension Kernel.File.Open.Options {
    public init(
        create: Bool = false,
        truncate: Bool = false,
        closeOnExec: Bool = true   // safe default
    ) {
        var result: Self = []
        if create { result.insert(.create) }
        if truncate { result.insert(.truncate) }
        if closeOnExec { result.insert(.closeOnExec) }
        self = result
    }
}
```

**Additional L2 extension variant** (Linux-only constant):

```swift
// L2 swift-linux-standard — Linux adds platform-specific constants
extension Kernel.File.Open.Options {
    public static let direct = Self(rawValue: O_DIRECT)  // Linux-only
}
```

**Provenance**: io_uring semantic flag modeling (2026-04-10), shell type audit.

**Lint enforcement (full scope detail)**: `Lint.Rule.Platform.OptionSetShell` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Platform`) flags `static let X = Self(rawValue: ...)` platform-constant declarations inside an `OptionSet`-conforming struct body. Constants belong in extensions so the shell stays cross-platform and platform packages add their constants per layer. Non-`Self(rawValue:)` initializers are out of scope. Added Wave 3 mechanization 2026-05-11.

---

## §[PLAT-ARCH-015] Per-L2 Platform-Native Typed Values

**Transition note (2026-05-01, supersedes 2026-04-27)**: the corollary's L3-typealias-via-`#if-os` pattern (added 2026-04-26 per § 8.3 of the parent Research doc) is the canonical mechanism. Its first ecosystem application — `Kernel.Descriptor` per [PLAT-ARCH-005] — landed via Wave 4c-Socket Prerequisite (2026-05-01) with the refined L2-canonical-where-spec-layer-exists tiered rule: the typealias chain on POSIX resolves `Kernel.Descriptor` → `ISO_9945.Kernel.Descriptor` (L2 canonical) and `POSIX.Kernel.Descriptor` collapses to a typealias to the same L2 type. The typealias mechanism itself was verified GREEN by the probe at `f14cf8f`/`acc42e5`; Wave 4c-Socket Prerequisite proved it operationally with a real L2 → L3 collapse.

**Incorrect-example detail** (forced bit-pattern conversions at each platform):

```swift
let tid = UInt64(truncatingIfNeeded: pid_t_value)     // loses signedness
let tid = UInt64(bitPattern: Int64(pid_t_value))      // reintroduces it
```

**Corollary mechanism note**: the L3-unifier typealias is the same mechanism `swift-kernel/Sources/Kernel/Exports.swift` already uses for re-exporting per-platform L3 modules ([PLAT-ARCH-006]); extending it to typealiases is not a new pattern — eliminating the structural tension between cross-platform-name desire and per-platform-storage reality.

**Rationale (full text)**: Platform-native ABI fidelity is stronger than uniform portable types for values that genuinely differ per platform. The instinct to unify (UInt64 everywhere) hides real differences: `mach_port_t` is a Mach kernel concept, `pid_t` is the Linux tid namespace, `DWORD` is a Win32 scheduler concept. Forcing them into one type via bit-pattern conversion is lossy AND misrepresents the platform reality. Per-L2 definition with native int widths honors both the platform and the type-system hygiene rules.

**Provenance**: Reflection `2026-04-14-strict-mission-thread-layer-refactor.md`. 2026-04-26 corollary: `swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions.md` (RECOMMENDATION; § 8.3) — codifies the L3-typealias-over-L1-exception preference for divergent-shape types whose cross-platform name is desirable. Within-L3 sub-tier framing per `swift-institute/Research/lateral-l3-to-l3-composition-options.md` (2026-04-26, STAMPED).

---

## §[PLAT-ARCH-016] `checkIsolated` for Thread-Owning SerialExecutors

**Why both members (full text)**: `isIsolatingCurrentContext()` is the fast-path predicate (returns `Bool?`); `checkIsolated()` is the backstop called by the runtime when the predicate returns `nil`. Implementing only one leaves `assumeIsolated` with no correct behavior in the fallback case. Apple's `DispatchMainExecutor` in `swift-platform-executors` implements both via `_dispatchAssertMainQueue()` — this pattern is sanctioned, not a workaround.

**Runtime reference**: the fallback chain is defined in `swiftlang/swift/stdlib/public/Concurrency/Actor.cpp:497-557`. `_taskIsCurrentExecutor` consults `isIsolatingCurrentContext()` first; on `nil`, it falls through to `checkIsolated()`. Without these protocol members, `assumeIsolated` on custom executors traps with "Unexpected isolation context" for code that is in fact correctly isolated at the thread level.

**What this is NOT (full text)**: `nonisolated(unsafe)` is not the answer for cross-thread actor-state visibility in a thread-owning executor. The actor is isolated to the executor; the executor owns the thread; `isIsolatingCurrentContext` bridges the type system's isolation model to the runtime's thread identity. Using `nonisolated(unsafe)` on the actor's state papers over the isolation contract that the executor is structurally set up to honor.

**Rationale (full text)**: Swift tracks isolation per-Task via task-local state set by `runSynchronously(on:)`. Custom executors that own threads and invoke user code outside that entry point need a way to self-certify when code runs on their thread. The protocol extension point exists; our ecosystem missed it historically because custom executors were first used via actor pinning (every access came through a dispatched job). Tick callbacks (synchronous callbacks from a run loop) bypass the per-Task model — the gap was in our implementation not keeping up with a new consumption pattern, not in Swift's design.

**Provenance**: Reflection `2026-04-15-polling-tick-isolation-checkisolated-landing.md`; research doc `swift-foundations/swift-io/Research/polling-tick-isolation-checkisolated.md`.

**Lint enforcement (full scope detail)**: SwiftLint custom rule `no_thread_ismainthread_in_primitives` (`swift-institute/.github/.swiftlint.yml`) flags `Thread.isMainThread` in `Sources/`, which is the Foundation-bound shortcut authors reach for instead of the protocol's `isIsolatingCurrentContext()` member. The check is partial — it covers the Thread-Owning anti-pattern subset (Foundation-shortcut at primitives layers); the broader "implement BOTH `isIsolatingCurrentContext()` AND `checkIsolated()`" composition discipline is not mechanically verifiable (whole-module concern). Added Wave 2b 2026-05-10.

---

## §[PATTERN-004] SwiftPM Platform Conditions

**Lint enforcement (full scope detail)**: Reusable workflow `validate-package-shape.yml` parses each Package.swift for `.product(name:..., package: "<platform-pkg>")` declarations where `<platform-pkg>` is one of the known platform packages (`swift-darwin*`, `swift-linux*`, `swift-windows*`, `swift-iso-9945`, `swift-posix`); flags any such reference whose parenthesized call does NOT also contain `condition: .when(platforms:`. Scoped to cross-platform packages — platform-specific packages are exempt because their own deps are inherently single-platform. Added Wave 2 mechanization 2026-05-11.

---

## §[PATTERN-005] / §[PATTERN-006] Package-Shape Validator History

Both checks were added Wave 2b finalization 2026-05-10 and moved from `validate-platform-architecture.yml` to `validate-package-shape.yml` per Wave 2 consolidation 2026-05-11 (platform-stack invariants and Swift-package shape conventions on separate validators).

---

## §[PATTERN-009] Typed-Throws-Safe Catch Patterns

**Full-loop example form** (the in-skill pair keeps the minimal do/catch):

```swift
func retry() throws(IO.Error) {
    while true {
        do throws(IO.Error) {
            try operation()
            return
        } catch where error.isInterrupted {
            continue  // `error` is IO.Error — concrete type preserved
        }
    }
}
```

**Provenance**: 2026-03-30-noncopyable-descriptor-l3-cascade.md. Lint mapping added Wave 2b 2026-05-10; [VERIFICATION] tags added Wave 4 Bucket 1 doc-gap pass 2026-05-11.

---

## §[PLAT-ARCH-008f] Naming-Parity-Collision Pre-Check for L3 Unifiers

**Example (correct, solution (a) — L2 spec-literal rename), full narrative**:

A 2026-04-26 cycle needed `Kernel.Thread.Local<Payload: AnyObject>` as a generic class at L3 to encapsulate `Unmanaged.passRetained` / `release` payload management for thread-local storage (replacing a private `_FrameLocal` typed wrapper in `swift-foundations/swift-observations`). L2's `ISO_9945.Kernel.Thread.Local` and `Windows.Kernel.Thread.Local` had been authored under informal cross-platform names that occupied the same namespace slot via the `Kernel_Primitives.Kernel` typealias chain. The L3 generic class declaration collided at declaration time on each platform.

Solution (a) renamed L2 to spec-literal forms:

| L2 package | Old name | New name | Spec authority |
|-----------|----------|----------|----------------|
| `swift-iso-9945` | `ISO_9945.Kernel.Thread.Local` | `ISO_9945.Kernel.Thread.Key` | POSIX `pthread_key_t` (IEEE 1003.1) |
| `swift-windows-standard` | `Windows.Kernel.Thread.Local` | `Windows.Kernel.Thread.Index` | Win32 "TLS index" / `DWORD` (MSDN) |

The L3 namespace `Kernel.Thread.Local` was freed for the generic class; the L2 names diverge per platform — that's correct, because the underlying platform abstractions genuinely differ (POSIX has an opaque key; Windows has a numeric index into a per-process table). The spec-literal rename respects [API-NAME-003] strict spec-mirroring at L2; the L3 unifier's job is to provide the cross-platform Swift name (`Local`).

Verification: `Observation.Tracking._FrameLocal` was deleted; the L3 consumer uses `Kernel.Thread.Local<Frame>` directly with zero `unsafe` markers in `Observation.Tracking.Current.swift`. The rule's solution (a) precondition ("L2's name was already informal") held — `Local` was a cross-platform L3-style name that had been imposed at L2; the spec-literal forms (`Key`, `Index`) had not been adopted earlier. Two applications of solution (a) (this and the rule's provenance commit chain) make the example reusable for a future third occurrence.

**Rationale (full text)**: L2 and L3 extensions on the same namespace occupy the same syntactic slot. When both sides happen to be spec-literal at the same intent, the collision is silent at the L2-raw package boundary and surfaces only at the unifier's downstream consumers. Without a pre-check, the L3 unifier's landing commit introduces ecosystem-wide compile breakage at the moment it lands. Enumerating the four solution families inside the rule forces an explicit choice at commit time rather than the choice being postponed to post-landing triage.

**Provenance**: 2026-04-20-consumer-migration-pickup-l3-name-parity-collision.md; 2026-04-20-l2-l3-same-signature-latent-ambiguity.md; 2026-04-26 second application via `Local` → `Key` / `Index` rename (reflection `2026-04-26-ecosystem-audit-and-typed-tls-promotion.md`).

---

## §[PLAT-ARCH-008g] Pre-Flight Memory Consultation Before Cross-L2 Dependencies

**Rationale (full text)**: Cross-L2 dependencies (iso-9945 ↔ darwin-standard, ↔ linux-standard, ↔ windows-standard) are forbidden by [PLAT-ARCH-007] but the rule is in the platform skill, not necessarily loaded when a test dependency is being added. The feedback memory is the redundant backup: it catches the rule at the moment the dependency is being written, even if the platform skill isn't the one the agent consulted. Parallels [REFL-006] (post-commit memory scan) and [SUPER-020] (pre-authorization memory scan); this is the author-time variant positioned earlier than either.

**Provenance**: 2026-04-22-iso9945-socket-message-header-cycle1-and-layer-correction.md

---

## §[PLAT-ARCH-008h] Within-L3 Sub-tiering and Composition Matrix

**Architectural background (full text)**: The platform stack composes downward through 5 layers; within L3-Foundations, three sub-tiers exist to capture the role distinctions between per-spec policy (swift-posix wraps iso-9945, just as swift-darwin wraps darwin-standard), cross-platform unification (swift-kernel composes the policy packages into one cross-platform API), and domain composition (swift-file-system composes the unified API to deliver file-system functionality). Without the sub-tiering, "L3 → L3" composition is ambiguous; the matrix makes the permitted directions explicit.

The L3-unifier sub-tier has internal layering: some unifiers (swift-kernel, swift-strings, swift-paths, swift-ascii, swift-systems) compose L3-policy directly per [PLAT-ARCH-008e]; others (swift-io, swift-threads, swift-environment) compose swift-kernel as a base unifier. This internal layering is captured by the "unifier → unifier peer composition allowed" cell — it is not a separate tier.

The "FROM L3-domain → TO L3-policy" cell is forbidden because L3-domain packages MUST go through the unifier. If a domain package needs platform-specific policy, the missing capability belongs in the unifier — extend the unifier rather than reach past it. Mirrors the [PLAT-ARCH-008c] "platform extensions over primitive conditionals" + [PLAT-ARCH-008d] "syscall vs policy test" structural-fix preference.

**Rationale (full text)**: [ARCH-LAYER-001] forbids lateral within-layer dependencies in strict reading. Within L3, several patterns exist that are structurally intentional (e.g., swift-darwin's POSIX subset extending swift-posix's POSIX policy; swift-file-system's domain-level composition over multiple unifiers) but were uncodified before this rule. The 3-sub-tier explicit enumeration makes the within-L3 composition matrix explicit and SPM-enforceable via Package.swift target-dep declarations: the dep DAG must respect the matrix's permitted cells.

**Provenance**: 2026-04-26 stamped design Doc `swift-institute/Research/lateral-l3-to-l3-composition-options.md` (Hybrid B+C decision); 2026-04-25 audit findings P2.11 + P2.12 + Pattern 3 (P3.5) surfacing the gap.

**Lint enforcement (full scope detail)**: Reusable workflow `validate-layer-deps.yml` parses each L3-policy / L3-domain package's `Package.swift` for `.product(... package: "<dep>")` declarations and flags two forbidden matrix cells: (a) L3-policy packages (`swift-posix`, `swift-darwin`, `swift-linux`, `swift-windows`) MUST NOT depend on any L3-unifier or L3-domain package (upward composition forbidden); (b) L3-domain packages (`swift-file-system`) MUST NOT depend on L3-policy packages directly — they must go through an L3-unifier. The L3-policy-to-L3-policy POSIX-shared-base permission ([PLAT-ARCH-008i]) is enforced separately at `validate-platform-architecture.py`. Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-008i] L3-policy Peer Composition for POSIX-shared Base

**Extended permitted examples**:

```swift
// In swift-darwin/Sources/Darwin Kernel/exports.swift
import POSIX_Kernel_File
import POSIX_Kernel_Directory
// ...Darwin extends Darwin's POSIX subset by composing swift-posix's POSIX policy.

// In swift-linux/Sources/Linux Kernel IO Uring/Kernel.IO.Uring+Supported.swift
import POSIX_Kernel
// Linux extends Linux's POSIX subset by composing swift-posix's POSIX policy.
```

**Architectural background (full text)**: POSIX is a cross-platform spec (IEEE 1003.1) — both Darwin (macOS, iOS, etc.) and Linux are POSIX-compliant platforms. swift-posix (L3-policy) wraps swift-iso-9945 (L2 POSIX spec) with policy normalization. swift-darwin and swift-linux (L3-policy) wrap their respective platform's L2 spec with platform-specific policy. Because Darwin and Linux are POSIX-compliant, their L3-policy packages can extend swift-posix's POSIX-policy base rather than re-implementing it.

**Rationale (full text)**: Without this rule, swift-darwin and swift-linux would have to either (a) duplicate POSIX policy (bad — divergence over time) or (b) reach past swift-posix to swift-iso-9945 (L2) and re-apply policy at the platform level (bad — duplication of policy logic). The [PLAT-ARCH-008i] permission is structurally narrow: it authorizes only the POSIX-shared-base pattern, where one peer is the spec-shared base of the other.

**Provenance**: 2026-04-26 stamped design Doc `swift-institute/Research/lateral-l3-to-l3-composition-options.md`; resolves audit finding P2.11 (lateral L3-policy peer composition) from `swift-institute/Audits/platform-compliance-2026-04-21.md`.

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` parses each L3-policy package's `Package.swift` for `package: "swift-posix"` / `package: "swift-darwin"` / `package: "swift-linux"` declarations and applies the [PLAT-ARCH-008i] permission matrix: only `(swift-darwin → swift-posix)` and `(swift-linux → swift-posix)` are permitted; `swift-windows → swift-posix` is flagged (non-POSIX); peer compositions between Darwin and Linux are flagged. Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-008j] Platform-C Import Authority

**L2 self-deinit libc-inline — production instances** (registry as of 2026-05-01): `ISO_9945.Kernel.Descriptor.deinit` (`Darwin/Glibc/Musl.close`), `Windows.\`32\`.Kernel.Descriptor.deinit` (`CloseHandle`), `Windows.\`32\`.Kernel.Socket.Descriptor.deinit` (`closesocket`), `ISO_9945.Kernel.Directory.Stream.deinit` (`closedir`), `ISO_9945.Kernel.Thread.{Mutex,Condition,Key}.deinit` (`pthread_*_destroy`/`pthread_key_delete`), `Linux.Kernel.IO.Uring.SharedRegions.deinit` (`munmap`).

**Migration debt** (scope indicators for Wave 4; precise per-file recount is Wave 4's responsibility; counts as of 2026-05-01):

- **L3-policy / L3-unifier platform-C imports**: 3 files currently import platform C directly (down from ~5 — Wave 4a-NUMA closed `System.Topology.NUMA.Discover.swift:14` 2026-05-01; Wave 4a-Glob closed `Windows.Kernel.Glob.Match.swift:14` 2026-05-01). Confirmed sites (per architecture-review audit 2026-04-30 verification + Wave 4a-NUMA + Wave 4a-Glob updates 2026-05-01): 3 in swift-posix (`POSIX.Kernel.Close.swift:16-20`, `POSIX.Kernel.Directory.Create.swift:16-20`, `POSIX.Kernel.Socket.Compat.swift:143-147`), 0 in swift-darwin, 0 in swift-linux, 0 in swift-windows. All 3 remaining are migration debt at swift-posix from pre-2026-04-30 architecture; the post-Path-X Tier 2 cleanup cycle migrates them to L2-typed-composition.
- **`@_spi(Syscall)` raw companion sites at L2** (per [PLAT-ARCH-019] superseded): empirical workspace count ~333 `@_spi(Syscall)` annotations across the four L2 spec packages (iso-9945 ~147, windows-standard ~120, linux-standard ~43, darwin-standard ~23 — combined declarations + companion imports + per-file SPI markers). Of these, ~110+ are public-function declarations needing migration; the remainder are SPI imports and intermediate annotations that fall away with the declaration migration. All are dead code under this rule and are deleted in the same Tier 2 pass.

The numbers are scope indicators for Wave 4 sequencing (effort estimation, batch shape, sub-cycle decomposition). Wave 4's first sub-cycle is responsible for the precise per-file recount.

**Rationale (full text)**: The empirical experiment `swift-institute/Experiments/spi-syscall-phase-out-layering/` (2026-04-30, CONFIRMED) tested 6 access-control variants for raw-syscall reach. The user-disposed result selects V2 (private at L2) and refutes V5 (L3-policy as raw-binding home). The architectural shift consolidates raw libc/WinSDK ownership at the spec-encoding tier (L2) where it belongs — L2's role is spec encoding, including spec-mandated raw FFI; L3's role is composition + policy on the typed surface. Single platform-C-import authority eliminates the prior ambiguity where L3-policy could "reasonably" reach into libc; the rule is now mechanical: L2 yes, everything else no.

**Provenance**: Experiment `swift-institute/Experiments/spi-syscall-phase-out-layering/` (2026-04-30, CONFIRMED); recommendation document at `swift-institute/Research/spi-syscall-phase-out-layering.md`; user disposition (2026-04-30) refuting V5 in favor of L2-only.

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` greps every package's `Sources/` for `^[ \t]*import[ \t]+(Darwin|Glibc|Musl|WinSDK)\b`; flags occurrences in any package not on the L2 spec allowlist (`swift-iso-9945`, `swift-linux-standard`, `swift-darwin-standard`, `swift-windows-32`). Wave 1 mechanization 2026-05-10 added fixture-based regression tests at `swift-institute/.github/.github/scripts/tests/fixtures/plat-arch-008j/` (pass — non-L2 with no platform-C imports; fail — non-L2 importing Darwin/Glibc; edge — iso-9945 importing Darwin/Glibc, exempt).

---

## §[PLAT-ARCH-008k] Spec/Policy Namespace Split

**Pre-Wave-3 typealias migration debt (full text)**: The pre-Wave-3 typealias pattern (`extension Linux { public typealias Kernel = ISO_9945.Kernel }` at `swift-linux-standard/Sources/Linux Standard Core/Linux.Kernel.swift:20` + the parallel `extension Darwin_Standard_Core.Darwin { public typealias Kernel = ISO_9945.Kernel }` at `swift-darwin-standard/Sources/Darwin Kernel Standard/Darwin.Kernel.swift:20`) is migration debt — it caused extensions on `Linux.Kernel.X` / `Darwin.Kernel.X` to silently land in `ISO_9945`'s namespace per [PLAT-ARCH-018]. Wave 3 breaks both typealiases and migrates existing per-platform extensions; pre-migration consumers should inventory their `Linux.Kernel.*` / `Darwin.Kernel.*` references per-file before the typealias break lands.

**Why asymmetric naming**: the platform-authority structure differs. POSIX has a formal spec authority (IEEE) and a colloquial alias (POSIX) at the same conceptual level — they are peer names, hence twin top-level roots. Windows has a single platform owner (Microsoft) where the platform name (Windows) and the spec name (Win32 API, the published Windows API documentation) are hierarchically related — Win32 is the spec under Windows, hence sub-namespace. The naming reflects the actual relationship rather than forcing artificial symmetry.

**Why `` `32` `` and not `Win32`**: Microsoft's published spec name is "Win32 API". When nested under `Windows`, the redundancy of `Windows.Win32.X` reads awkwardly (Windows.Windows-32.X). Modern Swift (verified 2026-04-30 against Apple Swift 6.3.1) permits backtick-escaped digit-starting identifiers; `` `32` `` is a valid namespace name under `Windows`. The shorter form `` Windows.`32` `` reads as "Windows 32-bit-API namespace" without the redundant Windows-Win prefix. Compiler error messages preserve the backticks correctly (verified: `cannot convert value of type 'Windows.Kernel.Foo' to expected argument type 'Windows.\`32\`.Foo'`).

**Why distinct types** (not typealiased):

1. **L2/L3 method-name collision avoidance** per [PLAT-ARCH-008e]: when L2 and L3 want the same method name with the same signature (e.g., both want `close(_ handle: Descriptor) throws(Error)` — the common case in the typed-everywhere world), they cannot coexist on the same nominal type. Distinct types resolve the collision structurally; method-name disambiguation (Phase-A-rename per [PLAT-ARCH-008e]) is a tactical fix for specific name conflicts, not a default architectural pattern, and breaks down when L2 and L3 genuinely want identical names+signatures.
2. **Layer separation visibility**: a consumer reading `ISO_9945.Kernel.X` or `` Windows.`32`.Kernel.X `` knows they reach the spec-literal form at L2; reading `POSIX.Kernel.X` or `Windows.Kernel.X` knows they reach the policy-wrapped form at L3. Typealias collapse hides this distinction.
3. **Empirical validation**: experiment `swift-institute/Experiments/windows-l2-l3-namespace-separation/` (2026-04-30) tested 5 top-level namespace patterns; V3 (twin roots) was the empirical recommendation. The sub-namespace variant `` Windows.`32` `` is mechanically the same pattern (distinct nominal types) using sub-namespace nesting + backtick-escaped identifier; user disposition selected this shape over top-level Win32 for aesthetic and naming-relationship reasons.

**Migration scope** (at rule landing, 2026-04-30): the POSIX-side had `public typealias POSIX = ISO_9945` (collapses to one type — the typealias must be removed). The Windows-side had only `Windows.Kernel.X` declared at the (then-named) `swift-windows-standard` L2 (the `` `32` `` sub-namespace didn't exist — must be introduced; existing L2 declarations relocate from `Windows.Kernel.X` to `` Windows.`32`.Kernel.X ``). The post-Path-X Tier 1 cleanup cycle executes:
- **Tier 1a (Windows-side)**: package rename `swift-windows-standard` → `swift-windows-32` + `` `32` `` sub-namespace introduction + relocate `Windows.Kernel.X` → `` Windows.`32`.Kernel.X `` declarations
- **Tier 1b (POSIX-side)**: break `public typealias POSIX = ISO_9945`; ISO_9945 + POSIX become genuinely distinct types

**Multi-spec extensibility — per-platform detail**:

- **Microsoft side**: Microsoft publishes multiple distinct API specifications beyond Win32 — NT Native API (ntdll Nt*/Zw* exports), WinRT (Windows Runtime), COM (Component Object Model), DirectX, WMI, etc. The `Windows.X.Kernel.*` sub-namespace pattern is multi-spec extensible: when a new Microsoft spec needs L2 encoding, add a sibling L2 package (`swift-windows-nt`, `swift-winrt`, `swift-windows-com`, etc.) with its own sub-namespace under `Windows` (`Windows.NT.Kernel.*`, `Windows.RT.*`, `Windows.COM.*`, etc.). Each spec gets its own L2 package; `swift-windows-32` is the Win32 spec encoding specifically. The single-platform-owner authority structure (Microsoft) maps naturally to sub-namespacing under the platform root.
- **Linux side**: future second specs (eBPF as a separate spec, io_uring extracted from `swift-linux-standard`, KVM, perf, etc.) MAY use sub-namespaces under `Linux` (`Linux.BPF.X`, `Linux.IORing.X`, etc.) when the spec is part of the Linux kernel surface and natural under `Linux`; OR get separate L2 packages with their own roots if the spec authority differs (e.g., a future LSB-spec L2 might root at `LSB` rather than under `Linux`). Decision criterion: does the spec belong to "the Linux kernel" (sub-namespace under `Linux`) or is it a separately-authored spec that happens to target Linux (own root)?
- **Darwin side**: future specs (Mach as separate spec, IOKit, ObjC runtime, Metal) follow the same first-principles approach. Mach is historically separate from XNU's POSIX surface — likely a sub-namespace `Darwin.Mach.X` under the Darwin platform root. IOKit and Metal are Apple-published specs with their own authority — they could sub-namespace under `Darwin` (`Darwin.IOKit.X`, `Darwin.Metal.X`) or get their own roots if community convention prefers it.
- **POSIX side**: `ISO_9945` is the IEEE-published shared base. Linux-specific extensions to POSIX live in `swift-linux-standard` under `Linux.Kernel`, NOT under `ISO_9945` — POSIX itself is purely the cross-platform shared spec. Linux and Darwin compose `ISO_9945.Kernel.X` for shared POSIX surface and add platform-specific extensions in their own L2 packages.

**Rationale (full text)**: Empirical experiment validated V3 distinct-types as architecturally robust against L2/L3 method-name collision in the typed-everywhere world. Sub-namespace `` Windows.`32` `` preserves this structural property while improving naming aesthetics (single platform root on Windows-side; spec authority captured under Win32 published name). Asymmetric naming (POSIX twin / Windows sub-namespace) reflects the actual platform-authority structure rather than forcing artificial symmetry. The L3-unifier typealias preserves cross-platform consumer name `Kernel.X` regardless of underlying split.

**Provenance**: Experiment `swift-institute/Experiments/windows-l2-l3-namespace-separation/` (2026-04-30, V3 RECOMMENDED); recommendation document at `swift-institute/Research/windows-l2-l3-namespace-separation.md`; user disposition (2026-04-30) selecting `` Windows.`32` `` sub-namespace variant + ISO_9945/POSIX twin-roots typealias break. Backtick-escaped digit-starting identifier mechanically verified against Apple Swift 6.3.1 (Xcode 26.4.1) — compiles, error messages render `` `32` `` correctly. Linux/Darwin per-platform spec ownership clause + first-principles multi-spec extensibility (refinement 3, 2026-04-30) added per architecture-review audit Findings 6.1 + 2.2 (`swift-institute/Audits/post-path-x-architecture-review-2026-04-30.md`).

---

## §[PLAT-ARCH-008l] Deinit-Context Composition

**Why not non-throwing helpers** (e.g., `closeIgnoringError`, `unlockIgnoringError`): parallel API surface bloat — every deinit-context family (Close, Lock, Memory.Map, ...) would need its own non-throwing twin alongside the throwing form, doubling the L2 public API surface for no semantic gain over `try?`. The `try?` pattern at the call site is idiomatic Swift, ecosystem-consistent, and preserves the typed throwing form as the single canonical entry point.

**Why not raw `(_:Int32)` / `(_:UInt)` companion forms** at the call site: `_rawValue` extraction at L3 / consumer layers reintroduces raw integers at boundaries that the typed-everywhere directive ([PLAT-ARCH-005] / [PLAT-ARCH-005a] / [PLAT-ARCH-008j]) is designed to eliminate. Per `feedback_no_raw_descriptor_reconstruction.md`: L3 / consumer callers never see `_rawValue` — the typed form passes the typed Descriptor across the L2 boundary, and L2 internally extracts raw to call libc/WinSDK if needed.

**Rationale (full text)**: The audit's Wave 4c-Close close note explicitly deferred deinit-context deletions ("until a non-throwing typed-helper pattern is principal-disposed"). Empirical verification at Wave 4c-deinit-helper (2026-05-01) showed the ecosystem had already converged on `try? typed-form(consume descriptor)` pattern at swift-memory, swift-io, linux-standard, swift-kernel DocC. The architectural decision was to codify the converged pattern rather than introduce parallel non-throwing API surface (Option A in the dispatch's options table). Compat-wrapper deletion clause added after Phase 3 escalation: swift-posix's 3 redundant `extension ISO_9945.Kernel.Lock` blocks (added Path X Phase 1 commit `b2c1801`) became structurally redundant post-Wave 4c-Socket Prerequisite (2026-05-01) when iso-9945's typed forms became canonical at L2; same-signature parallel declarations cause recursion hazards under naive mechanical migration.

**Provenance**: Wave 4c-deinit-helper (Item 1 of HANDOFF-post-path-x-final-architectural-cycles); audit close note at `swift-institute/Audits/post-path-x-architecture-review-2026-04-30.md` Wave 4c-deinit-helper section; commits at swift-iso-9945 (Lock.Token migration + raw Close downgrade), swift-foundations/swift-posix (POSIX.Kernel.Lock migration + compat wrapper deletion), swift-microsoft/swift-windows-32 (raw Close downgrade + IOCP helper deletion), swift-institute/Skills (rule addition + [PLAT-ARCH-008j] append).

---

## §[PLAT-ARCH-005b] @convention(c) Representability Pre-Check

**Rationale (full text)**: Layout compatibility is necessary but not sufficient for `@convention(c)` signatures. The compiler's check enforces ABI compatibility across the Swift-C boundary, which requires `@objc`-representability — a property governed by the Clang importer and unavailable to user-written structs. The β' pattern (opaque-pointer-at-callback + typed-wrapper-at-body) preserves type safety at the site where it matters (the Swift body) while respecting the ABI constraint at the site where the constraint is enforced (the signature).

**Provenance**: 2026-04-22-iso9945-signal-information-cycle2-beta-prime-revision.md; 2026-04-22-cycle-2-close-beta-prime-and-c-representability.md

**Lint enforcement (full scope detail)**: `Lint.Rule.Platform.ConventionCRepresentability` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Platform`) walks `AttributedTypeSyntax` with `@convention(c)` (including `@convention(c, cType: ...)`). For each parameter of the underlying `FunctionTypeSyntax` that is `UnsafeMutablePointer<X>` / `UnsafePointer<X>` where `X` is a `MemberTypeSyntax` (qualified path), the parameter is flagged. Primitive C types (`Int32`, `UInt8`, etc.) and `OpaquePointer` / `UnsafeMutableRawPointer` are not flagged. Added Wave 3 mechanization 2026-05-11.

---

## §[PLAT-ARCH-017] Cross-Platform C Anonymous-Enum Constant Type Divergence

**Rationale (full text)**: The Clang importer assigns `Int` to glibc's untyped anonymous-enum constants but infers `Int32` from Darwin's `_Nullable int`-typed definitions. The divergence is invisible at the ISO 9945 spec level but bites downstream consumers matching the constants. Wrapping at the case-label consistently on all platforms is a no-op on Darwin and a correctness fix on Linux; wrapping nowhere produces Linux build failures.

**Provenance**: 2026-04-22-iso9945-signal-information-cycle2-beta-prime-revision.md

---

## §[PLAT-ARCH-018] Typealiased Namespace-Path Conflict Rule

**Why this is silent (full text)**: The source-level path `ISO_9945.Kernel.Descriptor` *looks like* it's authoring iso-9945-resident code, but the typealias chain resolves through to L1's `Kernel.Descriptor`. Conflicts surface only at compiler resolution time, not during source-level authoring. Reviewers reading the source see "this declares ISO_9945's Descriptor"; the compiler sees "this adds to L1.Kernel."

**Relationship to [PLAT-ARCH-005] / [PLAT-ARCH-008c]**: those rules describe the typealias mechanism for L3-typealias-to-L3-policy unification (the design pattern). [PLAT-ARCH-018] documents the *conflict mode* of the same mechanism: typealias chains that resolve to a foreign module's namespace make new-type declarations at the typealiased path silently conflict with existing types in the foreign module. The pattern and its conflict mode are two sides of the same mechanism; codifying the conflict mode separately ensures writers and reviewers can detect the failure case.

**Worked example (the origin incident)**: A 2026-04-28 Phase 1.5 attempt to declare `ISO_9945.Kernel.Descriptor` from `swift-iso-9945` collided structurally with the existing L1 `Kernel.Descriptor` in `swift-kernel-primitives` because `extension ISO_9945 { public typealias Kernel = Kernel_Primitives_Core.Kernel }` makes the path `ISO_9945.Kernel.Descriptor` resolve to `Kernel_Primitives_Core.Kernel.Descriptor` at compile time. The L1 type was retained per the [PLAT-ARCH-008c] update note; the L2 declaration would have either silently added to L1's namespace (if the L1 type didn't exist) or failed at compile time (because the L1 type exists). The declaration was reverted; the type relocation was deferred pending L1 deletion (post-Cycle 23).

**Rationale (full text)**: Typealias chains in Swift make namespace ownership context-dependent: the same source-level path resolves to different modules depending on the typealias declaration. Writers using a typealiased namespace path lack a source-level signal that they're declaring into the foreign module rather than the local module; reviewers reading the source have the same blindness. Codifying the conflict mode and the mechanical mitigation (grep the foreign module before declaring) makes the failure case detectable at write time.

**Method-wrapping exception — origin + known parents** (Wave 3.5-1, 2026-05-01): concrete instance — `POSIX.Kernel.Descriptor.Duplicate` cannot be method-wrapped at L3-policy because `ISO_9945.Kernel.Descriptor.Duplicate` already exists. Confirmed typealiased L3-policy parents at swift-posix as of 2026-05-01: `POSIX.Kernel.Descriptor` (Duplicate sub-namespace exempted Wave 3.5-1), `POSIX.Kernel.Socket.Descriptor` (any sub-namespaces under it exempted similarly).

**Provenance**: Reflection `2026-04-28-phase-1-5-l2-pivot-attempt-and-namespace-correction.md`; method-wrapping exception per Wave 3.5-1 (POSIX.Kernel IO + File completion), audit doc Wave 3.5-1 close note.

**Lint enforcement (full scope detail)**: `Lint.Rule.Platform.TypealiasedNamespace` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Platform`) walks `TypeAliasDeclSyntax` and flags any typealias whose LHS name equals the RHS member-type leaf — `typealias Kernel = <Anything>.Kernel`. Such namespace-bridging typealiases re-point new-type declarations at the aliased path to the foreign module. Added Wave 3 mechanization 2026-05-11.

---

## §[PLAT-ARCH-020] L3-Unifier Shadow Pre-Flight Check

**Post-supersession framing (full text)**: this rule was originally written in the [PLAT-ARCH-019] era when raw `@_spi(Syscall) fd: Int32` companions co-existed alongside typed L2 forms. Post-supersession ([PLAT-ARCH-019] SUPERSEDED 2026-04-30; raw companions phased out per [PLAT-ARCH-008j] V2-only direction), the L3-unifier shadow concern persists for typed-only L2 forms — when L2 and L3-unifier each declare a typed overload at the same `Kernel.X.Y` path, overload-resolution ambiguity surfaces at consumer sites with or without raw companions. The rule's mechanical grep + `@_disfavoredOverload` precondition continues to apply to typed-only L2 surfaces; the worked example below is preserved as historical context but the disambiguation pattern works identically without the raw companion.

**Why `@_disfavoredOverload` is required (full text)**: L3-unifier `swift-kernel` re-exports L2 namespaces and adds its own typed overloads at the same path, expecting consumers to see "the unified surface." Without `@_disfavoredOverload` on the L2 typed forms, both layers' typed overloads become equally-ranked candidates at consumer call sites; Swift's overload-resolution diagnostic surfaces as ambiguity errors at every site importing `Kernel`.

**Worked example (the origin incident)**: Path X Phase 1 sub-cycle 1.1's Wave 1 removed `@_disfavoredOverload` from L2 typed forms in `IO.Read.swift` and `IO.Write.swift`, citing Phase 1.5 Lock.swift / Memory.Map.swift canonical pattern. The justification elided a structural difference: Lock and Memory.Map have NO L3-unifier shims at the same namespace path; IO.Read / IO.Write DO — `swift-kernel/Sources/Kernel File/Kernel.IO.{Read,Write}+CrossPlatform.POSIX.swift` declares parallel typed overloads on the same path, delegating to swift-posix's EINTR-retry wrappers. Without `@_disfavoredOverload` on the L2 typed forms, both layers' typed forms became equally-ranked candidates → ambiguity at every `Kernel.IO.Read.read(...)` consumer site. The fixup (commit `26e8788`) restored `@_disfavoredOverload` on all 4 typed buffer/Span overloads in each of IO.Read.swift / IO.Write.swift; documented the elision in the commit body. A pre-Wave-1 grep of `swift-kernel/Sources` for `Kernel.IO.Read+*` would have caught the precondition violation before any commits landed.

**Rationale (full text)**: The L3-unifier and L2 are at the same namespace path; when L2 adds typed forms, it must consider L3-unifier as a parallel author at the same path. This is a structural reality of the platform stack's typealias-chain composition: L3-unifier `swift-kernel` re-exports L2 namespaces and adds its own typed overloads at the same path, expecting consumers to see "the unified surface." When L2 adds new typed forms (or removes `@_disfavoredOverload`), it changes the unified surface in a way the L3-unifier didn't anticipate. The pre-flight grep for parallel L3-unifier extensions is the mechanical check that closes this.

**Provenance**: Reflection `2026-04-28-sub-cycle-1-1-inverted-pattern-a.md` (Wave 1 `@_disfavoredOverload` regression caught at downstream verify; fixup commit `26e8788`).

---

## §[PLAT-ARCH-021] Domain-Specific Cross-Platform Unification Lives in Domain L3 Packages

**The principle (full text)**: `swift-kernel` is the L3-unifier for kernel-level primitives — file descriptors, signal handling, syscall dispatch policy. When a domain-specific unifier surface is needed (socket-domain RFC composition, TLS protocol handling, time-zone resolution), it belongs in that domain's L3 package, where the domain-specific spec deps (`swift-rfc-791`, `swift-rfc-4291`, `swift-tls-*`, `swift-iso-8601`) can live without making `swift-kernel` a dependency aggregator.

**Why now-not-later**: `swift-kernel` as a "dumping ground for IETF RFC deps" would become a networking aggregator in name only. Moving domain-specific unifiers to their domain packages while the surface is small (e.g., 2 RFC-typed `Connect` overloads) is cheap; moving later, after DNS / TLS / HTTP have added their RFC deps, would compound the migration cost. The scope-creep argument is structural, not stylistic.

**Worked example (the origin incident)**: A 2026-04-20 attempt to add cross-platform `Kernel.Socket.Connect` overloads taking `RFC_791.IPv4.Address` and `RFC_4291.IPv6.Address` was initially landed in `swift-kernel` (commits `6741b6a` + `2afb251`). User correction: `swift-sockets` already exists for socket-domain unification. Migration moved 4 files from `swift-kernel` → `swift-sockets`, removed RFC deps from swift-kernel (`2c63378`), added them to swift-sockets (`9a83433`). swift-kernel returned to domain-neutral kernel-primitive composition.

**Provenance**: Reflection `2026-04-20-socket-unifier-rfc-composition-and-swift-sockets-migration.md` (swift-sockets migration); supporting research `swift-institute/Research/ip-address-value-type-memory-layout.md` (Tier 2, RFC vs sockaddr layout incompatibility).

---

## §[PLAT-ARCH-022] `Swift.<Protocol>` Qualification for Stdlib-Shadowing Namespaces

**Recurrences**:
- 2026-05-06 SwiftSyntax linter Phase 2 Stream C — `some Sequence<UInt8>` shadowed by swift-sequence-primitives `Sequence` namespace. Fixed with `some Swift.Sequence<UInt8>`.

**Provenance**: Generalization of [PLAT-ARCH-011] (Swift.Error everywhere); 2026-05-06 Stream C `Sequence` collision surfaced the broader principle. Lint mechanization added Wave 1 2026-05-10.

---

## §[PLAT-ARCH-024] L2 Platform-Extension Pre-Check Before L3 Placement

**Cost asymmetry**: The pre-check is mechanical and inexpensive (≤1s on a warm cache). The cost asymmetry against skipping it is severe: an L3 placement decision that the L2 grep would have blocked produces a forced unwind cycle once the L2 platform-extension binding surfaces during build (typically 10–30 minutes of refactor turnaround per unwind).

**Worked-example table** (Path X cycle outcomes):

| Type | L2 platform-extension grep | Final placement | Rationale |
|------|---------------------------|-----------------|-----------|
| `Kernel.Completion` | Empty (Linux io_uring is single-platform; no Darwin/Windows extensions) | L3 swift-kernel | Cycle 23 — clean L3 placement |
| `Kernel.Event` | Non-empty (`darwin-standard` has 9 kqueue files extending `Kernel.Event.Queue`; `linux-standard` has epoll equivalents) | L2 ISO_9945.Kernel | G6.B initial L3 attempt UNWOUND because extensions blocked upward import |
| `Kernel.File` / `Kernel.Wakeup` / `Kernel.Channel` | Non-empty (L2 platform packages extend the namespace) | L2 ISO_9945.Kernel | G6.C absorbed at L2 because L2 binding forced placement |
| `Kernel.Time` | Empty (no platform-specific extensions) | L3 swift-kernel | G6.A — clean L3 placement |
| `Terminal.Mode.Raw.Token` | (reverse case) Token's `case posix(Kernel.Termios.Attributes)` references an L2 type | L3 swift-kernel | Cycle 22 — type at L1 was structurally blocked because a content reference reached L2 |

**The Cycle 23 misleading-precedent failure mode**: Cycle 23 Completion → L3 was a clean transfer because Linux io_uring was the only Completion implementation (Darwin and Windows backends absent in Cycle 23 era). Reasoning "Cycle X precedent applies" without re-running the L2 pre-check on the candidate type is the canonical failure mode this rule prevents. G6.B Event "looked like Completion" syntactically but had completely different L2 extension surface.

**Generalization evidence**: the 2026-05-08 Memory↔System and Algebra↔Optic/Witness reversals (`two-l1-layer-reversals`) are the parallel evidence: small bridge files at the wrong package surfaced as audit findings; the bridge author's desk had no L2 extension visibility at write-time.

**Rationale (full text)**: L2 platform-extension binding is the load-bearing constraint that determines vertical placement, not the type's content (which may be semantically platform-neutral). The Path X arc surfaced this pattern across 4+ cycles; the rule consolidates the discipline. Without it, "is this content cross-platform?" gets confused with "where can this type be placed?" — the two questions have different answers when L2 platform packages already extend the namespace.

**Provenance**: Path X cycle 23 / G6.A / G6.B / G6.C / Cycle 22 (Reflections `2026-04-30-path-x-completion-cycles-19-23-and-g6.md`, `2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md`); Wave 4c-Socket Prerequisite I/II (Reflection `2026-05-01-wave-4c-completion-and-finding-6-8-rewire.md`); multi-envelope Item 5 Class B classification (Reflection `2026-05-02-multi-envelope-execution-research-doc-layering-blindspot-and-empirical-classification-corrections.md`); Glob L1 relocation (Reflection `2026-05-02-glob-l1-relocation-and-premise-inversion-research-gate.md`); Memory↔System + Algebra↔Optic reversals (Reflection `2026-05-08-two-l1-layer-reversals-system-and-iso.md`).

---

## §[PLAT-ARCH-025] Class A vs Class B Classification by Declaration Site

**Worked example (the origin incident)**: `Kernel.Thread.ID` initially classified as Class A based on cross-platform usage at swift-posix. Empirical check: declared at `Darwin_Kernel_Standard` and `Linux_Kernel_System_Standard` (platform-specific L2), NOT at iso-9945 Core. Class A bridge attempt at swift-posix correctly failed to compile per [PLAT-ARCH-008e] (L3-policy has no visibility into platform-specific L2). Re-classified as Class B; bridge typealiases placed at swift-darwin + swift-linux L3-policy peers.

**Rationale (full text)**: A type's "where it's used" surface is broad (any package importing the namespace) and tells you nothing about visibility. A type's "where it's declared" is narrow and tells you exactly what packages can name it without an upward import. Classifications grounded in usage produce false-positive Class A determinations that fail at compile time; declaration-grounded classifications fail (or succeed) on the architectural axis they're describing.

**Provenance**: 2026-05-02 Item 5 multi-envelope execution (Reflection `2026-05-02-multi-envelope-execution-research-doc-layering-blindspot-and-empirical-classification-corrections.md` Pattern 2 — Class A vs Class B classification is empirical, not nominal).

---

## §[PLAT-ARCH-026] Platform System Extends `System` Directly, Not as a Subdomain

**Provenance**: memory `feedback_platform_system_not_subdomain.md` (Darwin/Linux/Windows System target shape decision). Lint mechanization added Wave 3 2026-05-11.

---

## §[PLAT-ARCH-027] Platform Core Internal With `@_exported` Re-Export From Variants

**Provenance**: memory `feedback_platform_core_internal_reexport.md` (platform package modularization shape).

**Lint enforcement (full scope detail)**: Reusable workflow `validate-platform-architecture.yml` enumerates each platform-primitives package's (`swift-darwin-primitives`, `swift-linux-primitives`, `swift-windows-primitives`) direct subdirectories of `Sources/`; for every variant target (subdir whose name does not end in `Core`), verifies an `Exports.swift` / `exports.swift` file exists at the variant root AND contains `@_exported public import {Platform}_Primitives_Core`. A missing exports file OR a present file without the Core re-export is flagged. Defensive — no platform-primitives packages exist on disk currently, so the rule fires only when they appear. Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-028] Typealiased-Namespace Unifier Collapse Forbids swift-kernel Delegate

**Contrast with Read/Write (full text)**: Read/Write methods live entirely on `Kernel.IO.{Read,Write}` with iso-9945 (L2) and swift-sockets/swift-kernel (L3 unifier) both extending via typealias. There the collision IS between two different modules both extending `Kernel.IO.Read`, and `@_disfavoredOverload` on the L2 side is the fix. The Darwin/Linux Flush collision is *between two distinct-looking extensions on the same typealiased target* (swift-kernel unifier + platform package), which is a redeclaration error, not an overload-resolution problem. The two failure modes look similar but demand different fixes.

**Ecosystem landing**: Darwin/Linux/Windows Flush pattern established at swift-darwin `1d57f80`, swift-linux `43a43e0`, swift-kernel `e9bafc5` (removed `Kernel.File.Flush.data` unifier delegate), swift-file-system `ce0a511` (consumer `#if` collapse).

**Provenance**: memory `feedback_typealiased_namespace_unifier_collapse.md` (Darwin/Linux Flush relocation 2026-04-20).

---

## §[PLAT-ARCH-029] L2 Spec Wrappers Must Model the Domain, Not Wrap Raw C Fields

**Why (full text)**: Thin accessors like `_fd: Int32`, `_rawFlags: UInt32` just rename C struct layout — they describe mechanism, not domain. The user's explicit pre-1.0 standard is "L2 spec packages are modern Swift spec wrappers — raw integers should never be visible." This composes with `[PLAT-ARCH-013]` (Shell + Values OptionSet pattern) and `[PLAT-ARCH-015]` (Per-L2 Platform-Native Typed Values) — together these rules constitute the L2 typed-modeling standard.

**Provenance**: memory `feedback_semantic_type_modeling.md` (linux-standard L2 modeling correction; user direction "too low level" on raw-accessor proposals).

---

## §[PLAT-ARCH-030] L3 POSIX Layer: Re-Export Raw Syscalls or Layer Policy

**Provenance**: memory `project_l3_posix_policy_principle.md` (POSIX L3 design principle).

---

## §[PLAT-ARCH-031] Linux Stack Mirrors POSIX: Standard at L2, Linux at L3

**Provenance**: memory `project_linux_stack_architecture.md` (Linux L2/L3 architecture decision).

---

## Changelog-Provenance (Dated Amendment History)

Evicted verbatim from the SKILL.md frontmatter comment block (2026-05-11 state). Git history of
`Skills/platform/SKILL.md` remains the authoritative record; these entries are preserved here because
they carry narrative value (wave sequencing, supersession reasoning, migration-debt counts at each
amendment point). Ordered as they appeared in the frontmatter.

- **2026-05-11**: Wave 4 Bucket 1 doc-gap pass (HANDOFF-mechanization-wave-4.md) — added Lint enforcement + [VERIFICATION] tags for [PATTERN-009] (SwiftLint no_typed_catch_let_error_where + Lint.Rule.Throws.DoCatchTyped), [PLAT-ARCH-008i] (WF validate-platform-architecture.py), [PLAT-ARCH-011] (SwiftLint swift_error_qualification + Lint.Rule.Platform.SwiftQualification — renamed existing "Enforcement" sub-section to "Lint enforcement" for uniformity), [PLAT-ARCH-016] (SwiftLint no_thread_ismainthread_in_primitives — partial, Thread-Owning subset), [PLAT-ARCH-023] (WF validate-platform-architecture.py). Statements unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003].
- **2026-05-10**: Phase 3b TRIM-PROSE — compressed Rationale prose on [PATTERN-009] now that `no_typed_catch_let_error_where` mechanically enforces. [PLAT-ARCH-005], [PLAT-ARCH-008c], [PLAT-ARCH-008j] retain dated transition prose pending Phase 3b Q2 (frontmatter changelog deferral). Statements unchanged per [SKILL-LIFE-001]. Phase 3b Batch 3: [PLAT-ARCH-019] body retired to redirect-only per Q3.
- **2026-05-10**: [PLAT-ARCH-024] L2 Platform-Extension Pre-Check + [PLAT-ARCH-025] Class A vs Class B by Declaration Site added per Reflections/{2026-04-30-path-x-completion-cycles-19-23-and-g6, 2026-05-02-multi-envelope-execution-research-doc-layering-blindspot-and-empirical-classification-corrections}.md (Cluster A consolidation)
- **2026-05-10**: Wave 2b lint extraction (HANDOFF-skill-to-ci-cd-extraction-inventory.md) — added Lint enforcement line for [PATTERN-009] mapping the rule to SwiftLint custom rule `no_typed_catch_let_error_where`. Clarifying per [SKILL-LIFE-003].
- **2026-05-10**: Wave 2b finalization (HANDOFF-wave-2b-finalization.md) — added Lint enforcement lines for [PLAT-ARCH-008c], [PLAT-ARCH-008i], [PLAT-ARCH-008j], [PLAT-ARCH-023], [PATTERN-005], [PATTERN-006] mapping each to the new `validate-platform-architecture.yml` reusable workflow + companion `.github/scripts/validate-platform-architecture.py`. Clarifying per [SKILL-LIFE-003].
- **2026-04-26**: [PLAT-ARCH-005] revised + [PLAT-ARCH-008c] strengthened + [PLAT-ARCH-015] augmented per swift-kernel-primitives/Research/l1-types-only-no-exceptions.md (RECOMMENDATION) — eliminates the L1 Kernel.Descriptor exception in favor of L3-typealias unification over L3-policy per-platform descriptor types.
- **2026-04-27**: transition notes added to [PLAT-ARCH-005] / [PLAT-ARCH-008c] / [PLAT-ARCH-015] per swift-kernel-primitives/Research/l1-types-only-no-exceptions-l2-cascade.md (INVESTIGATION) — descriptor migration DEFERRED pending L2 spec-wrapper cascade refactor scope decision. Rule text describes canonical end-state; current ecosystem retains the L1 type until the cascade resolves.
- **2026-04-30**: BREAKING — [PLAT-ARCH-005a] SPI exception clause REMOVED; [PLAT-ARCH-008a] hard line tightened to L2-only platform-C imports within platform stack; [PLAT-ARCH-019] INVERTED Pattern A SUPERSEDED; new [PLAT-ARCH-008j] (Platform-C Import Authority — L2 exclusive) and [PLAT-ARCH-008k] (Spec/Policy Namespace Split — ISO_9945/POSIX twin-roots + Windows.`32`/Windows sub-namespace distinct types) ADDED. Provenance: experiments swift-institute/Experiments/spi-syscall-phase-out-layering/ (CONFIRMED V2-only) + windows-l2-l3-namespace-separation/ (V3 RECOMMENDED) + user disposition 2026-04-30. Migration debt: ~36 @_spi(Syscall) raw companion sites + ~8 L3 platform-C imports + POSIX = ISO_9945 typealias break + Windows.`32` sub-namespace introduction at swift-windows-standard — queued for post-Path-X Tier 1+2 cleanup cycles.
- **2026-04-30 (refinement)**: [PLAT-ARCH-008k] Windows-side namespace shape refined from top-level Win32 (V3 experiment recommendation) to sub-namespace Windows.`32` per user disposition — preserves structural property of distinct nominal types while improving naming aesthetics (single platform root on Windows-side). Backtick-escaped digit-starting identifier mechanically verified against Apple Swift 6.3.1.
- **2026-04-30 (refinement 2)**: [PLAT-ARCH-008k] adds multi-spec extensibility codification (Win32 / NT / WinRT / COM each get own L2 package); package rename swift-windows-standard → swift-windows-32 codified at [PLAT-ARCH-010] reference table + [PLAT-ARCH-008j] L2 spec list + [PLAT-ARCH-008k] canonical mapping. Forward-looking historical references in this skill that retain "swift-windows-standard" describe pre-rename state correctly and are NOT retroactively rewritten; subsequent rule edits will catch them as touched.
- **2026-04-30 (refinement 3)**: audit-driven amendments per `swift-institute/Audits/post-path-x-architecture-review-2026-04-30.md` (Findings 6.1, 2.2, 3.3, 1.2/1.3, 3.1). [PLAT-ARCH-008k] codifies Linux.Kernel + Darwin.Kernel as distinct nominal types with per-platform spec ownership clause + first-principles multi-spec extensibility for all platforms (Microsoft sub-namespacing, POSIX twin-roots, Linux/Darwin case-by-case per spec authority). [PLAT-ARCH-010] adds namespace anchor packages clause (L2 pattern, RESERVED until first multi-spec L2 lands per platform). [PLAT-ARCH-008j] migration debt prose recounted to reflect actual workspace numbers (~5 L3 platform-C imports + ~333 @_spi(Syscall) annotations / ~110+ public-function declarations vs. prior ~8 + ~36 estimates). [PLAT-ARCH-020] post-supersession framing — [PLAT-ARCH-019]-bound prose generalized; underlying L3-unifier shadow concern persists for typed-only L2 surfaces. Provenance: architecture-review audit (2026-04-30) + user disposition 2026-04-30. Per [SKILL-LIFE-003]: amendments are MOSTLY CLARIFYING (existing rule applied to a previously-unaddressed case in [PLAT-ARCH-008k] Linux/Darwin clause; existing rule applied post-supersession in [PLAT-ARCH-020]; corrected scope indicators in [PLAT-ARCH-008j]; explicit codification of an unspoken pattern in [PLAT-ARCH-010] namespace anchor); ADDITIVE for [PLAT-ARCH-008k]'s new "Per-platform spec ownership" clause + multi-spec first-principles section + Linux/Darwin canonical mapping rows.
- **2026-05-01**: [PLAT-ARCH-005] tiered-revision per Wave 4c-Socket Prerequisite (user-authorized Path C consolidation). Statement refined: per-platform Descriptor canonical at L2 spec layer when one exists (POSIX → swift-iso-9945, Win32 → swift-windows-32); L3-policy provides typealias. Where no L2 spec layer exists (residual case), L3-policy hosts the canonical type (unchanged). Round-trip elimination mechanism documented as the architectural enablement for typed-everywhere ([PLAT-ARCH-005a] revised + [PLAT-ARCH-008j]). Transition notes at [PLAT-ARCH-008c] + [PLAT-ARCH-015] corollary updated from "DEFERRED" to "completed via Wave 4c-Socket Prerequisite". Per [SKILL-LIFE-003]: amendments are CLARIFYING + ADDITIVE — original L1-deletion + L3-typealias mechanism unchanged; tiered placement is a refinement of where the typealiased type lives (L2-canonical when spec layer exists), not a reversal.
- **2026-05-01 (Prerequisite II — corrective)**: [PLAT-ARCH-005] re-revised. The morning Prerequisite I revision said "L3-unifier typealiases through to the L2 canonical name", which framed the L3-unifier as composing directly over L2 — violating [PLAT-ARCH-008e] (L3-unifier composes its peer L3-policy tier; never reaches across into L2). The L3-unifier MUST typealias to the L3-policy type (`POSIX.Kernel.Descriptor` / `Windows.Kernel.Descriptor`); typealias transitivity then resolves the chain to the L2 canonical at compile time without any composition-tier skip. Worked example rewritten to show the three-tier chain explicitly (L2 canonical struct → L3-policy typealias → L3-unifier typealias). Cross-references to [PLAT-ARCH-008e] / [PLAT-ARCH-008j] strengthened. Per [SKILL-LIFE-003]: amendment is CORRECTIVE — Prerequisite I's framing introduced a composition-discipline violation that the executable code at swift-kernel `f703ad3` then mirrored; this revision restores the three-tier chain. Code corrections at swift-kernel Package.swift + Exports.swift land alongside this skill revision.
- **2026-05-01 (Wave 4c-deinit-helper)**: [PLAT-ARCH-008j] APPENDED with libc-inline clause for L2 ~Copyable type self-deinits (structurally forced — deinit cannot consume self into a typed close that itself takes consuming Descriptor); new [PLAT-ARCH-008l] (Deinit-Context Composition) ADDED — L2 syscall APIs called FROM other types' deinit contexts use the typed throwing form via `try?`; raw `(_:Int32)` / `(_:UInt)` companion forms are not L2 public API surface and MUST be downgraded to internal/package where typed forms exist; L3-policy compat wrappers extending L2 namespaces with same-signature parallel declarations MUST be deleted once the L2 canonical typed form exists. Provenance: Wave 4c-deinit-helper (Item 1 of post-Path-X cycles); reflection at audit doc Wave 4c-deinit-helper close note. Per [SKILL-LIFE-003]: amendments are ADDITIVE (new [PLAT-ARCH-008l]) + CLARIFYING ([PLAT-ARCH-008j] libc-inline clause codifies what L2 Descriptor.deinit / Socket.Descriptor.deinit / Directory.Stream.deinit / Mutex.deinit etc. already do — just makes the structural rationale explicit and grants visible permission).
- **2026-05-01 (Wave 4a-NUMA)**: [PLAT-ARCH-008j] migration debt count UPDATED — `System.Topology.NUMA.Discover.swift:14` (1 site at swift-windows) closed. L3 platform-C import count drops 5 → 4 (only `Windows.Kernel.Glob.Match.swift:14` remains at swift-windows, queued for Wave 4a-Glob). NUMA discovery relocated from L3 swift-windows to L2 swift-windows-32 with `internal import WinSDK` per Option C YAGNI disposition. Provenance: Wave 4a-NUMA (Item 2 of post-Path-X cycles); audit doc Wave 4a-NUMA close note. Per [SKILL-LIFE-003]: amendment is CLARIFYING (count adjustment only — rule body unchanged).
- **2026-05-01 (Wave 3.5-1)**: [PLAT-ARCH-018] APPENDED with method-wrapping exception clause for typealiased L3-policy parents. When an L3-policy parent type is a typealias to its L2 canonical (e.g., POSIX.Kernel.Descriptor = ISO_9945.Kernel.Descriptor), Swift resolves `extension POSIX.Kernel.Descriptor { public enum X {} }` through the typealias and collides with any existing L2 sub-namespace at that path. Concrete instance: POSIX.Kernel.Descriptor.Duplicate cannot be method-wrapped at L3-policy because ISO_9945.Kernel.Descriptor.Duplicate already exists. Structural consequence: sub-namespaces nested under typealiased L3-policy parents (Descriptor.Duplicate, Socket.Descriptor.X, etc.) are exempt from Option (ii) "distinct enums + method-wrapping" and rely on typealias-chain fall-through. Pre-flight grep added to identify other affected sub-namespaces. Provenance: Wave 3.5-1 (POSIX.Kernel IO + File completion); audit doc Wave 3.5-1 close note. Per [SKILL-LIFE-003]: amendment is CLARIFYING (codifies a structural consequence of [PLAT-ARCH-005] tiered Descriptor placement that surfaced empirically when Option (ii) was applied to nested namespaces).
- **2026-05-01 (Wave 4a-Glob)**: [PLAT-ARCH-008j] migration debt count UPDATED — `Windows.Kernel.Glob.Match.swift:14` (last site at swift-windows; previously deferred per Finding 6.7) closed. L3 platform-C import count drops 4 → 3 (all 3 remaining at swift-posix; Wave 4a Sites 1+2+3 already closed those at the policy layer but the platform-C imports persist as migration debt). Wave 4a-Glob Option B authorized: typed L2 `Windows.\`32\`.Kernel.File.Find` domain at swift-windows-32 (Handle ~Copyable RAII / Entry / Error / pathExists); L3-policy file rewritten to extend `ISO_9945.Kernel.Glob` (mirrors POSIX-side at swift-posix); cross-platform signature asymmetry closed (Windows-side body-closure shape now matches POSIX); pre-existing namespace defect (Windows.Kernel.Glob never declared workspace-wide) fixed. Item 3.5 deferred (Glob vocabulary L1 relocation) — would eliminate the swift-windows → swift-iso-9945 dep asymmetry introduced by Wave 4a-Glob's Option B compromise. Provenance: Wave 4a-Glob (Item 3 of post-Path-X cycles); audit doc Wave 4a-Glob close note. Per [SKILL-LIFE-003]: amendment is CLARIFYING (count adjustment only — rule body unchanged).
- **2026-05-10**: Wave 1 mechanization (HANDOFF-mechanization-wave-1-high-leverage.md) — added Lint enforcement / [VERIFICATION] tags for [PLAT-ARCH-007] (validate-platform-architecture.py POSIX-shared syscall placement check), [PLAT-ARCH-008c] (existing validator + Wave 1 fixture-based regression tests; same revision fixed a path-filter bug), [PLAT-ARCH-008j] (existing validator + Wave 1 fixture-based regression tests), [PLAT-ARCH-022] (Lint.Rule.Platform.SwiftQualification AST rule). Statements unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003].
- **2026-05-11**: Wave 2 mechanization (HANDOFF-mechanization-wave-2-platform-validators.md) — added Lint enforcement / [VERIFICATION] tags for: Validator A `validate-layer-deps.py` ([PLAT-ARCH-008], [PLAT-ARCH-008h]); Validator B `validate-package-shape.py` ([PATTERN-001], [PATTERN-003], [PATTERN-004], [PATTERN-004c], plus the Wave-2b [PATTERN-005] / [PATTERN-006] checks moved here from `validate-platform-architecture.py`); Validator C extension `validate-platform-architecture.py` ([PLAT-ARCH-004], [PLAT-ARCH-005], [PLAT-ARCH-006], [PLAT-ARCH-027]). Statements unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003]. Rules listed in the handoff but NOT mechanized (semantic / pre-flight / ecosystem-wide checks): [PLAT-ARCH-001], [PLAT-ARCH-008a], [PLAT-ARCH-008b], [PLAT-ARCH-008d], [PLAT-ARCH-008e], [PLAT-ARCH-009], [PLAT-ARCH-010], [PLAT-ARCH-014], [PLAT-ARCH-020], [PLAT-ARCH-024], [PLAT-ARCH-028], [PLAT-ARCH-030], [PLAT-ARCH-031], [PATTERN-007] — documented in each validator's script header for traceability.

---

## §[PATTERN-003] Nested Test Package Pattern

**Lint enforcement (full scope detail)**: Reusable workflow `validate-package-shape.yml` performs a best-effort shape check: when `Tests/Package.swift` exists, validate that it has a `// swift-tools-version` first line and declares at least one `.testTarget(...)`. Whether the package SHOULD adopt the nested pattern (the circular-dep-with-swift-testing case) is a semantic call beyond the validator; the rule's MUST-USE clause remains an authoring judgment. Added Wave 2 mechanization 2026-05-11.

---

## §[PLAT-ARCH-020] Addendum — Canonical-Shape Precondition (Full Sentence)

The generalization's original full form: "The canonical Phase 1.5 Lock.swift / Memory.Map.swift shape ('raw with syscall + typed delegating; no `@_disfavoredOverload`') depends on a precondition: *no other layer declares a typed overload at the same namespace path*. When applying canonical shapes to a new file, the writer MUST check the precondition."
