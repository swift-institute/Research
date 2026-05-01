# Windows L2/L3 Namespace Separation

**Status**: RECOMMENDATION
**Date**: 2026-04-30
**Scope**: swift-windows-standard (L2 Win32 spec), swift-windows (L3-policy Windows), swift-kernel (L3-unifier)
**Drives**: future strict-platform compliance phase-out of raw forms at L2 (typed-only L2 surface), per user direction post-Path-X-close
**Companion experiment**: `swift-institute/Experiments/windows-l2-l3-namespace-separation/`

---

## 1. Context

Path X closed on 2026-04-30. The user direction that follows is twofold:

1. **Raw forms phased out at L2 entirely.** Not "relocated under `@_spi(Syscall)`" — phased out. Future L2 spec packages MUST expose only typed surface (typed handles, typed errors, typed parameters).
2. **Spec/policy separation visible at the namespace level.** L2 spec and L3 policy must be distinguishable by namespace path, not only by parameter-type-overload differences.

The POSIX-side stack already encodes this two-name structure:

| Tier | POSIX-side root | Role |
|---|---|---|
| L2 spec | `ISO_9945` | IEEE 1003.1 specification (literal spec authority) |
| L3-policy / unifier | `POSIX` | EINTR retry, partial-IO loop, error normalization |

Today the two POSIX names typealias to the same type (`public typealias POSIX = ISO_9945`); the namespaces are *named* separately but the underlying type is one. The typealias is convenient and source-compatible; whether to break it is the open question this document closes with (§5).

The Windows-side stack has only `Windows`. There is no separate Windows analog of `ISO_9945` ↔ `POSIX`. When raw forms phase out at L2, the typed-only L2 surface and the typed L3 unifier surface will collide at `Windows.Kernel.X` — one syntactic slot for two semantic tiers, exactly the namespace-occupancy collision rule from [PLAT-ARCH-008e].

This document captures the empirical survey of five candidate naming patterns and recommends one as the path forward.

## 2. Method

The companion experiment ships five variants as a single SPM package with sixteen targets (5 variants × {L2, L3, Consumer} + a SharedHandle utility carrying the cross-variant `FakeHandle` stand-in). All sixteen targets build green in debug AND release; all five Consumer executables run and print expected output. Build receipts:

| Variant | Debug | Release | Cross-module | Runtime |
|---|---|---|---|---|
| V1 | `Outputs/V1-debug.txt` | `Outputs/V1-release.txt` | `Outputs/V1-cross-module.txt` | `Outputs/V1-runtime.txt` |
| V2 | `Outputs/V2-debug.txt` | `Outputs/V2-release.txt` | `Outputs/V2-cross-module.txt` | `Outputs/V2-runtime.txt` |
| V3 | `Outputs/V3-debug.txt` | `Outputs/V3-release.txt` | `Outputs/V3-cross-module.txt` | `Outputs/V3-runtime.txt` |
| V4 | `Outputs/V4-debug.txt` | `Outputs/V4-release.txt` | `Outputs/V4-cross-module.txt` | `Outputs/V4-runtime.txt` |
| V5 | `Outputs/V5-debug.txt` | `Outputs/V5-release.txt` | `Outputs/V5-cross-module.txt` | `Outputs/V5-runtime.txt` |

Each consumer's build is itself the cross-module receipt — the chain Consumer → L3 → L2 crosses two module boundaries, with each module emit-module'd separately by SwiftPM before the next consumes it. Release-mode is captured per [EXP-017].

Per the brief, L2 carries the raw form (`UInt`-shaped close) and L3 carries the typed wrapper (`FakeHandle`-shaped close); the experiment's question is the namespace pattern, not the parameter typing. Because raw and typed differ on parameter type, all five variants compile mechanically — including V1, where L2 and L3 share namespace identity. The differential signal is therefore architectural, not mechanical: spec/policy separation, [API-NAME-003] specification-mirroring fidelity, and Windows-host module-vs-type collision risk.

The architectural assessments cite [PLAT-ARCH-008e] (L3-unifier composition discipline + namespace-identity collision rule), [PLAT-ARCH-008f] (naming-parity-collision pre-check), [PLAT-ARCH-010] (platform-package reference), and [API-NAME-003] (specification-mirroring names).

## 3. Variant Verdicts

### 3.1 V1 — status quo (`Windows.Kernel.X` at L2 + L3)

| Receipt | Result |
|---|---|
| `V1-debug.txt` | GREEN |
| `V1-release.txt` | GREEN |
| `V1-cross-module.txt` | GREEN |
| `V1-runtime.txt` | `V1 typed close (L3 policy): true` / `V1 raw close (L2 reachable via UInt overload): true` |

Mechanically CONFIRMED in the present state. The raw `UInt` overload at L2 and the typed `FakeHandle` overload at L3 coexist at `Windows.Kernel.Close.close(_:)` because their signatures differ; overload resolution at the consumer site disambiguates. Power-user reach to L2 raw is by `Kernel.Close.close(0xCAFEBABE as UInt)`.

Architecturally REFUTED on three grounds:

1. **No spec/policy audit boundary at the namespace level.** Both tiers occupy `Windows.Kernel.Close`. A reader cannot tell from the namespace alone which tier owns a given member; the only signal is parameter type. Auditing tools that grep for "L2 spec usage" vs "L3 policy usage" by import path are useless here — both come through one symbol path.

2. **The future typed-only L2 phase-out collides at the same syntactic slot.** When L2 stops carrying `UInt` overloads and exposes only typed `FakeHandle`-shaped surface (per the user direction), L2 typed and L3 typed have the same signature. They occupy the same slot per [PLAT-ARCH-008e]; the canonical disambiguators are [PLAT-ARCH-008f]'s four solution families: (a) L2 spec-literal rename, (b) L3 abstract rename, (c) sub-namespace on L2, (d) package-level separation. Solution (c) is V2; solution (d), at the cross-stack level, is V3/V4/V5. V1 itself is the structural shape that drives the need for one of those solutions.

3. **`@_disfavoredOverload` is not a permanent answer.** The natural V1 mitigation is to mark L2 typed `@_disfavoredOverload` per [PLAT-ARCH-020], so consumer overload resolution prefers L3. But that is a pre-flight discipline ([PLAT-ARCH-020]'s shadow grep), not a structural separation. Any author adding a new typed L2 form forgets the annotation, ambiguity surfaces at downstream consumers, and the disambiguation is fragile across L2 / L3 / L3-unifier authors who cannot all be expected to remember the rule on every commit.

V1 is **REFUTED** as the recommended path. The mechanical pass it produces in the present state is precisely the property that makes the future-state collision invisible — a CI green that masks the architectural failure mode the experiment exists to surface.

### 3.2 V2 — sub-namespace (`Windows.ABI.Kernel.X` at L2 + `Windows.Kernel.X` at L3)

| Receipt | Result |
|---|---|
| `V2-debug.txt` | GREEN |
| `V2-release.txt` | GREEN |
| `V2-cross-module.txt` | GREEN |
| `V2-runtime.txt` | `V2 typed close (L3 policy at Windows.Kernel): true` / `V2 raw close (L2 spec at Windows.ABI.Kernel): true` |

CONFIRMED. The L2 spec surface lives at `Windows.ABI.Kernel.X` and the L3 unifier slot at `Windows.Kernel.X`. The two are syntactically disjoint extension paths under one `Windows` root. Future typed-only L2 declarations stay at `Windows.ABI.Kernel` and cannot collide with typed L3 wrappers; [PLAT-ARCH-008e]'s namespace-occupancy collision rule does not fire because the namespaces are different.

Architectural assessment is mixed:

**Pros.** The single `Windows` root signals platform identity; the `ABI` qualifier names the binary contract layer. Microsoft's own documentation refers to "the Win32 ABI" and "the Windows ABI" as the calling-convention / binary-interface specification; the Swift `Windows.ABI.Kernel` namespace mirrors that vocabulary. Source-compatibility-wise, anything that reaches `Kernel.Close.X` through `swift-kernel`'s typealias chain stays at `Windows.Kernel.X` and is unaffected by the L2 sub-namespace.

**Cons.** The sub-namespace label `ABI` is a meta-tag, not a spec authority name. The ecosystem's [API-NAME-003] specification-mirroring naming convention prefers the literal spec identity (`ISO_9945`, `RFC_4122`, `RFC_3986`) over meta-tags. There is no "Windows ABI specification document" in the same sense that there is an IEEE 1003.1 specification document; "Win32 API" is the closest analog, and the Microsoft-published name for it is "Win32" (see V3) or "Windows SDK" (see V5), not "ABI". The sub-namespace adds a level of indirection — `Windows.ABI.Kernel.X` — that no other platform-stack package introduces (`ISO_9945.Kernel.X`, `Linux.Kernel.X`, `Darwin.Kernel.X`, `Win32.Kernel.X` are all two levels; V2's L2 path is three).

V2 is **CONFIRMED** mechanically and architecturally workable, but **sub-optimal** vs V3 on specification-mirroring grounds. Recommendation: not V2.

### 3.3 V3 — twin roots (`Win32.Kernel.X` at L2 + `Windows.Kernel.X` at L3)

| Receipt | Result |
|---|---|
| `V3-debug.txt` | GREEN |
| `V3-release.txt` | GREEN |
| `V3-cross-module.txt` | GREEN |
| `V3-runtime.txt` | `V3 typed close (L3 policy at Windows.Kernel): true` / `V3 raw close (L2 spec at Win32.Kernel): true` |

CONFIRMED. L2 spec lives under `Win32` (Microsoft's literal name for the Windows API specification — `Win32` is what Microsoft calls the API Microsoft documents), and L3 policy / unifier lives under `Windows`. The two are entirely disjoint namespace trees, with no shared root.

Architectural assessment, in three parts:

**Spec-authority parallel with POSIX.** The POSIX-side tower is:

| Tier | POSIX root | Windows root (V3) |
|---|---|---|
| L2 spec | `ISO_9945` (IEEE 1003.1) | `Win32` (Microsoft Win32 API) |
| L3-policy / unifier | `POSIX` | `Windows` |

The structural parallel is exact. `ISO_9945` and `Win32` are both literal spec-authority names; `POSIX` and `Windows` are both platform-identity names that the policy / unifier layers root themselves at. Audits become mechanical — `import Win32_Kernel_*` flags spec consumers, `import Windows_Kernel_*` flags policy / unifier consumers; the same grep pattern works on both POSIX and Windows.

**Specification-mirroring fidelity.** [API-NAME-003] requires that types implementing specifications mirror the specification terminology. `Win32` is the Microsoft-published name for the API specification — not "Microsoft Win32," not "Windows API," just `Win32`. It is the literal term Microsoft uses in its own documentation, in the C-shim header file names (`Win32.h`-rooted), and in the Windows SDK's own API surface. Rooting the L2 spec at `Win32` is exactly what [API-NAME-003] asks for.

**Future typed-only L2 phase-out is structurally clean.** When L2 sheds its raw `UInt` overloads and exposes only typed `Win32.Kernel.Close.close(_ handle: Kernel.Descriptor)`, the namespace path is `Win32.Kernel.X`. The L3-unifier's typealias chain at `swift-kernel/Sources/Kernel/Exports.swift` resolves cross-platform `Kernel.X` to `Windows.Kernel.X` on Windows, which is a *different* namespace tree. The two cannot collide because they cannot occupy the same syntactic slot. [PLAT-ARCH-008e]'s namespace-occupancy collision rule is structurally satisfied — no `@_disfavoredOverload` discipline required, no [PLAT-ARCH-020] shadow-grep precondition for L2-to-L3-unifier shadow.

V3 is **CONFIRMED** and the **recommended path**. See §4.

### 3.4 V4 — org-prefix (`Microsoft.Kernel.X` at L2 + `Windows.Kernel.X` at L3)

| Receipt | Result |
|---|---|
| `V4-debug.txt` | GREEN |
| `V4-release.txt` | GREEN |
| `V4-cross-module.txt` | GREEN |
| `V4-runtime.txt` | `V4 typed close (L3 policy at Windows.Kernel): true` / `V4 raw close (L2 spec at Microsoft.Kernel): true` |

CONFIRMED mechanically. The L2 spec surface roots at `Microsoft` (the publishing organization); L3 unifier roots at `Windows`. Disjoint trees — same property as V3 — and the future typed-only L2 phase-out is structurally clean for the same reason.

Architecturally REFUTED on specification-mirroring grounds:

The ecosystem already publishes spec-rooted L2 packages (see [PLAT-ARCH-010]):

| Spec authority | L2 package | Root namespace |
|---|---|---|
| IEEE 1003.1 | `swift-iso-9945` | `ISO_9945` |
| Linux kernel | `swift-linux-standard` | `Linux` (with `.Kernel.IO.Uring`, etc.) |
| Apple / Darwin | `swift-darwin-standard` | `Darwin` (with `.Kernel.Kqueue`, etc.) |
| ARM ARM | `swift-arm-standard` | `ARM` |
| Intel / AMD | `swift-x86-standard` | `x86` |
| RISC-V ISA | `swift-riscv-standard` | `RISC_V` |

The pattern is: root = literal spec name, not publishing organization. None of the existing standards packages root at `IEEE`, `Apple`, `Linus`, or similar. V4's `Microsoft` root would be the lone exception, and an exception with no architectural justification — `Microsoft` carries less specification fidelity than `Win32`, because `Win32` is the spec name Microsoft itself uses.

V4 is **REFUTED** as the recommended path on specification-mirroring grounds. Mechanically equivalent to V3; semantically inferior.

### 3.5 V5 — literal-spec (`WinSDK.Kernel.X` at L2 + `Windows.Kernel.X` at L3)

| Receipt | Result |
|---|---|
| `V5-debug.txt` | GREEN |
| `V5-release.txt` | GREEN |
| `V5-cross-module.txt` | GREEN |
| `V5-runtime.txt` | `V5 typed close (L3 policy at Windows.Kernel): true` / `V5 raw close (L2 spec at WinSDK.Kernel): true` |

CONFIRMED on macOS (the experiment host). The shape works mechanically — `WinSDK.Kernel.X` and `Windows.Kernel.X` are disjoint namespace trees in any host environment.

Architecturally REFUTED on a Windows-host-specific concern that the macOS receipts cannot rule out:

`WinSDK` is the Microsoft-published Swift module name for the Windows SDK headers — the C-shim umbrella that surfaces `CloseHandle`, `CreateFileW`, etc. to Swift code on Windows. Any Swift code on Windows reaching for raw Win32 types writes `import WinSDK` and then `WinSDK.CloseHandle(...)`.

If we additionally publish a Swift `enum WinSDK` in `swift-windows-standard` and consumers `import WinSDK_Standard` (or whatever the L2 module is named), references to `WinSDK.X` become ambiguous between:

- The **module** `WinSDK` (C-shim), giving `WinSDK.CloseHandle` (a C function)
- The **type** `WinSDK` (Swift enum from `swift-windows-standard`), giving `WinSDK.Kernel.Close.close(_:)` (a Swift method)

Swift's name resolution treats modules and top-level types as participants in the same lookup space at qualified-reference sites; resolution is generally biased toward types, but the disambiguation is implicit and varies by context (qualified expression vs. type position vs. generic constraint). Even where it works, every reference reads as if it might mean either thing. Auditors and reviewers must keep both candidates in mind on every site. This is not a hypothetical: the standards-package precedent at `swift-darwin-standard` already navigates a similar identifier-overload tax with the `Darwin` Swift module on macOS, and the audited resolution there is that *compound disambiguators* are needed at every cross-reference site (e.g., `Darwin_Standard_Core.Darwin` from the platform skill's "Namespace Collision Handling" section).

The collision **cannot fire on macOS or Linux CI** because the `WinSDK` module does not exist outside Windows. Cross-platform CI alone cannot rule out the latent risk; a green CI matrix on macOS + Linux says nothing about Windows resolution behavior.

V5 is **REFUTED** as the recommended path. The Windows-host-only collision risk and the precedent for compound-disambiguation-on-collision both argue against adopting an L2 root that shares its name with an existing Microsoft-published Swift module.

## 4. Recommendation

**Adopt V3 — twin roots.**

L2 spec for Windows: `swift-windows-standard` exposes types under `Win32.Kernel.X` (and a `Win32` root namespace alongside it for non-`Kernel` Win32 types when those arise — e.g., `Win32.GDI`, `Win32.User`, `Win32.Common.Controls` in any future L2 package decomposition).

L3 policy / unifier: `swift-windows` (L3-policy) and `swift-kernel` (L3-unifier on Windows) extend `Windows.Kernel.X` per the existing [PLAT-ARCH-004] platform-root convention. The cross-platform consumer's `Kernel.X` typealias resolves to `Windows.Kernel.X` via the [PLAT-ARCH-005] / [PLAT-ARCH-006] re-export chain at `swift-kernel/Sources/Kernel/Exports.swift`.

The two roots are disjoint, so:

- Future typed-only L2 phase-out is structurally clean (no [PLAT-ARCH-008e] namespace collision).
- Audit greps work mechanically (`import Win32_Kernel_*` for spec consumers; `import Windows_Kernel_*` for unifier consumers).
- Spec-authority naming follows [API-NAME-003] (Microsoft's literal spec name `Win32`, parallel to IEEE's literal spec name `ISO_9945`).
- The pattern is symmetric with the POSIX side at the namespace level: `ISO_9945 ↔ POSIX` mirrors `Win32 ↔ Windows`.

V1 is REFUTED on architectural grounds (no spec/policy boundary; future typed-only L2 collision; `@_disfavoredOverload` is not durable).
V2 is sub-optimal vs V3 on specification-mirroring grounds (the `ABI` sub-tag is not a Microsoft-published spec authority).
V4 is REFUTED on specification-mirroring grounds (the publishing-organization root is the lone non-spec-name root in the ecosystem and contradicts the existing pattern).
V5 is REFUTED on Windows-host-only identifier-overload risk (latent module-vs-type collision invisible to macOS / Linux CI).

## 5. Open Question — POSIX-Side Mirroring

The user's brief surfaces this question explicitly:

> If V3 (twin roots) is empirically clean and ergonomic, does the recommendation include breaking the existing `POSIX = ISO_9945` typealias so POSIX-side mirrors? Surface this question rather than autonomously deciding.

The current POSIX-side state is:

```swift
// swift-iso-9945
public enum ISO_9945 { /* IEEE 1003.1 root */ }

// swift-iso-9945
public typealias POSIX = ISO_9945  // ← convenience typealias
```

`POSIX` and `ISO_9945` *name* different conceptual tiers (spec authority vs platform identity for the L3-policy / unifier root) but resolve to the same type. Extensions written `extension POSIX.Kernel.X { ... }` and `extension ISO_9945.Kernel.X { ... }` add to the same underlying namespace.

Adopting V3 on the Windows side puts `Win32` and `Windows` as **distinct types** (declared separately in `swift-windows-standard` and `swift-windows` respectively, with no typealias bridging them). For the architecture to be parallel across platforms — for the V3 mirror to be more than skin-deep — the POSIX side would need to break the `POSIX = ISO_9945` typealias and declare `POSIX` as a distinct type from `ISO_9945`.

The question is not architectural in isolation — V3 stands on its own as a Windows-side recommendation regardless of what POSIX does — but it has implications:

1. **Audit symmetry.** With `POSIX = ISO_9945`, `import POSIX_Kernel_File` and `import ISO_9945_Kernel_File` ARE the same import. Audits cannot use `import` paths to distinguish "L3-policy POSIX consumer" from "L2 spec POSIX consumer" the way they can on V3-style Windows. If we want the audit symmetry V3 provides on Windows to also hold on POSIX, the typealias must break.

2. **Type-system distinction.** `Kernel.Descriptor`-shaped extensions added via `extension POSIX.Kernel.Descriptor` today land in the L1 / L3-policy `Kernel.Descriptor`. With distinct types, extensions on `POSIX.Kernel.Descriptor` would have to sit on a *different* type from `ISO_9945.Kernel.Descriptor`, and the relationship between the two would require explicit forwarding (typealias-on-the-method instead of typealias-on-the-namespace, or wrapped-type / parallel-type construction).

3. **Source-compatibility cost.** Every existing call site that uses `POSIX.X` reaches `ISO_9945.X` today. Breaking the typealias requires either (a) a coordinated rename across all consumer call sites (a non-trivial sweep across swift-foundations, swift-io, swift-file-system, etc.), or (b) maintaining the typealias for one further deprecation cycle and migrating sites incrementally.

4. **Asymmetric outcome is also valid.** The architecture does not strictly require POSIX-side mirroring. V3 on the Windows side stands alone — it solves the Windows-specific problem of typed-only-L2 collision under a single `Windows` root. The POSIX side does not have the same forcing function because typed-only L2 is already mostly addressed by Phase 1.5 / INVERTED Pattern A's coexistence pattern at L2, with `swift-iso-9945`'s typed-and-raw forms living alongside each other in one package and `swift-posix` providing the L3-policy compat wrappers. POSIX-side L2-typed and L3-policy-typed already occupy *different* roots (`ISO_9945` for L2, `POSIX` for L3-policy), even if those roots typealias to the same type. The typealias is a source-compatibility bridge, not an architectural compromise.

**Surfaced for principal decision.** This document does not autonomously decide whether to break `POSIX = ISO_9945`. Three coherent choices:

| Choice | Outcome |
|---|---|
| **Keep `POSIX = ISO_9945` typealias** | V3 adopted on Windows side; POSIX side remains type-identified. Asymmetric, but the asymmetry is a source-compat bridge with low downstream pain. The audit-symmetry property V3 provides on Windows does not extend to POSIX, but POSIX has weaker forcing function (no single-root collision pressure). |
| **Break the typealias as part of V3 adoption** | Full architectural mirror. Audit symmetry on both platforms. One-time source-compat cost across the POSIX consumer surface. |
| **Defer the POSIX-side decision; adopt V3 on Windows now** | Structurally identical to "Keep" but signals an explicit re-evaluation point. POSIX typealias revisit becomes a follow-on cycle once Windows-side V3 is in production. |

This is a principal decision; the empirical receipts in the experiment do not constrain it.

## 6. Cross-References

- Skill rules: [PLAT-ARCH-001], [PLAT-ARCH-003], [PLAT-ARCH-004], [PLAT-ARCH-005], [PLAT-ARCH-006], [PLAT-ARCH-008e], [PLAT-ARCH-008f], [PLAT-ARCH-010], [PLAT-ARCH-020], [API-NAME-003]
- Companion experiment: `swift-institute/Experiments/windows-l2-l3-namespace-separation/`
- Sibling research: `swift-institute/Research/spi-syscall-phase-out-layering.md` (raw-FFI access-control survey, also Path-X-driven)
- Path X close memory entry: see `feedback_l2_is_syscalls_level.md` (memory) and Phase-1.5 / INVERTED Pattern A reflections

## 7. Next-Step Sketch (if V3 adopted)

1. **`swift-windows-standard` rename of L2 root.** `Windows` namespace at L2 → `Win32`. All `extension Windows.Kernel.X` declarations become `extension Win32.Kernel.X`.
2. **`swift-windows` (L3-policy) keeps `Windows` root.** Typed wrappers at `Windows.Kernel.X` are unaffected (extensions on the L3-policy root, not on L2).
3. **`swift-kernel` typealias chain unchanged.** `swift-kernel/Sources/Kernel/Exports.swift` continues to provide `public typealias Kernel = Windows.Kernel` under `#if os(Windows)`. Cross-platform consumers see no change.
4. **Power-user raw access.** Consumers wanting Win32 spec-literal forms write `import Win32_Standard` (or whatever the rename produces) and use `Win32.Kernel.X` directly. The path is explicit and audit-grep-friendly.
5. **Cascading cleanup.** Any audit / grep tooling that currently assumes `Windows` is a single root can be updated to recognize `Win32` as the spec authority; per [PLAT-ARCH-010]'s package reference, the new `Win32` root can be added without disturbing other platform-spec roots.
6. **POSIX-side decision per §5** is independent of this sketch and requires principal authorization before any typealias-break.
