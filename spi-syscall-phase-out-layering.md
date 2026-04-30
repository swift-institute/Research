# Access-Control Pattern for Raw-Syscall Reach After `@_spi(Syscall)` Phase-Out

**Status**: RECOMMENDATION — V2+V5 framing **SUPERSEDED** by user disposition 2026-04-30 (see § 0 below)
**Date**: 2026-04-30
**Scope**: Ecosystem-wide (swift-iso-9945, swift-windows-standard, swift-darwin-standard, swift-linux-standard at L2; swift-posix, swift-darwin, swift-linux, swift-windows at L3-policy; swift-kernel at L3-unifier)
**Drives**: ~36 existing `@_spi(Syscall) public func close(_ fd: Int32)` style sites across the four L2 spec packages
**Companion experiment**: `swift-institute/Experiments/spi-syscall-phase-out-layering/`

---

## 0. User Disposition (2026-04-30) — REFUTED V5

This document originally recommended a **V2+V5 hybrid**: V2 at L2 (typed-only public surface; raw binding file-scope private inside L2) PLUS **V5-as-L3-policy** (L3-policy owns its own libc/WinSDK binding directly — see § 3.5 and § 4 below). User disposition on 2026-04-30 **refuted V5** in favor of **V2-only**:

- **L2 spec packages are the EXCLUSIVE home** for `import Darwin` / `import Glibc` / `import Musl` / `import WinSDK` within the platform stack.
- **L3-policy / L3-unifier / L3-domain packages MUST NOT import platform C** — they compose via L2's typed API exclusively.
- Within L2, raw libc/WinSDK calls live at `private` / `fileprivate` / `internal` scope; L2's public surface is typed-only ([PLAT-ARCH-005a] revised).

**Doc status**: § 4 "Recommendation" + § 5 "Migration Plan" Shape B framing (L3-policy adds its own libc binding) are SUPERSEDED. The codified rule **[PLAT-ARCH-008j]** (Platform-C Import Authority — L2 Exclusive) is authoritative. See `swift-institute/Skills/platform/SKILL.md` sections **[PLAT-ARCH-005a]**, **[PLAT-ARCH-008a]**, **[PLAT-ARCH-008j]**, **[PLAT-ARCH-008k]** for canonical rules.

**What remains valid**: the experiment's empirical findings (§ 3 — V1-V6 verdicts, build receipts, mechanical compile/link/run outcomes) and the architectural reasoning that V6-pragmatic ("no raw at L2 public/SPI surface") is achievable. The recommendation conclusion changes — V5's L3-policy-owns-libc framing is rejected; the L2-only direction at [PLAT-ARCH-008j] is the canonical post-Path-X architecture.

**Migration shape under L2-only direction** (replacing § 5 Shape B):

- Existing `@_spi(Syscall) public func name(_:Int32) -> Int32` raw-companion sites at L2 are migration debt — relocate the raw libc call site to L2 internal/private scope (V2 shape) and delete the SPI surface.
- Existing L3-policy files that currently import platform C directly (`internal import Darwin/Glibc/Musl/WinSDK`) are migration debt — refactor to compose L2's typed API; the EINTR retry / partial-IO loop / error normalization that L3-policy adds operates on L2's typed throwing functions, not on raw libc calls.
- Per [PLAT-ARCH-008j] the L2 typed wrapper does its own libc call privately (V2-internal). The L3-policy retry loop calls `try L2.Kernel.X.method(...)` and catches the typed error — never reaches into libc directly.

**Provenance for this disposition**: experiment `swift-institute/Experiments/spi-syscall-phase-out-layering/` (CONFIRMED V2-only); user disposition 2026-04-30 (Path X close + post-close architectural decisions); skill amendment commit `Skills/platform/SKILL.md` 2026-04-30 introducing [PLAT-ARCH-008j] / [PLAT-ARCH-008k] and superseding [PLAT-ARCH-019]. Doc correction landed per [REFL-011] correction-from-primary-source rule.

---

## 1. Context

Path X closed on 2026-04-30. User direction is now strict on two points that bind together:

1. **`@_spi(Syscall)` is phased out entirely** at the L2 spec packages. The annotation is no longer permissible as a mechanism for exposing raw forms alongside typed forms.
2. **Raw integer types (`Int32`, `UInt`, `UInt32`, `UInt64`) MUST NOT appear in any L2 API surface** — neither `public` nor `@_spi(Syscall) public`.

These two constraints together force a re-architecture of how raw FFI is reached. Today, L3-policy packages (swift-posix's EINTR-retry wrapper around iso-9945's `fsync`, etc.) reach the underlying C `close(_:)` / `fsync(_:)` / etc. via `@_spi(Syscall) import` of the L2 spec package's raw companion. After phase-out there is no `@_spi(Syscall)` raw companion at L2 to import.

The ~36 existing call-pair sites across `swift-iso-9945` / `swift-darwin-standard` / `swift-linux-standard` / `swift-windows-standard` (where each site is one `@_spi(Syscall) public func name(_:Int32) -> Int32` paired with an L3-policy retry-wrapped `name(_:borrowing Descriptor) throws(Error)`) all need a new mechanism to bind L3-policy → platform C without crossing L2's surface.

This document records the empirical access-control survey and recommends a path forward.

## 2. Method

The companion experiment ships six variants as a single SPM package with 18 targets (6 variants × {L2 wrapper, L3 policy, Consumer}). All 18 targets build green in debug AND release; all 6 Consumer executables run and print expected output. Build receipts: `Experiments/spi-syscall-phase-out-layering/Outputs/V{1..6}-{debug,release,cross-module}.txt`.

The differential signal is in the **architectural reachability** each access-control mechanism provides for our ecosystem's actual cross-package-stack consumer topology, not in any compile failure within the sandbox. Receipts confirm the *mechanical* compile/link/run behavior; this document ties it to the *architectural* constraints from [PLAT-ARCH-005a] (no platform C in public APIs), [PLAT-ARCH-008a] (consumers must not bypass platform stack to import platform C), [PLAT-ARCH-008c] (L1 platform-agnostic, no exceptions), and [PLAT-ARCH-008e] (L3-unifier composes L3-policy).

## 3. Variant Verdicts

Citations are by output filename in the experiment package's `Outputs/` directory.

### 3.1 V1 — `@_spi(Syscall)` raw companion at L2 (status quo)

| Receipt | Result |
|---|---|
| `V1-debug.txt` | GREEN |
| `V1-release.txt` | GREEN |
| `V1-cross-module.txt` | `V1 (b) raw via @_spi(Syscall): rc=0` |

Mechanically CONFIRMED. Architecturally **REFUTED by user direction** — Path X close removes `@_spi(Syscall)` from the toolbox.

### 3.2 V2 — `private` raw helper inside L2 wrapper

| Receipt | Result |
|---|---|
| `V2-debug.txt` | GREEN |
| `V2-release.txt` | GREEN |
| `V2-cross-module.txt` | `V2 (b) raw: NOT REACHABLE — private helper invisible to consumers` |

Raw FFI lives at file scope inside L2; nothing outside that file (not other files in the same module, not L3-policy, not consumers) can reach it. The typed L2 surface is the only export.

CONFIRMED for "L2 author keeps raw call site contained inside one source file". REFUTED for "expose raw to L3-policy or to anyone with a legitimate need". The L3-policy retry wrapper now has nothing to wrap — it cannot reach the raw call from L2.

This is the right shape for L2 itself — it's just not the *whole* answer because L3-policy needs its own raw binding.

### 3.3 V3 — `internal` raw + sibling target via `@testable import`

| Receipt | Result |
|---|---|
| `V3-debug.txt` | GREEN (V3_L2 carries `-enable-testing`) |
| `V3-release.txt` | GREEN |
| `V3-cross-module.txt` | `V3 (b) raw via @testable: rc=0` |

Mechanically CONFIRMED **only because** the experiment's `Package.swift` sets `.unsafeFlags(["-enable-testing"])` on V3_L2 (and V3_Consumer). Without this, `@testable import V3_L2` fails at compile with `module 'V3_L2' was not compiled for testing` — a well-documented Swift behavior, not exercised here only because the success case is what the experiment is testing.

The architectural cost is structural and disqualifying:

- `-enable-testing` disables certain optimizations (TBD-emission and dead-code-elimination boundaries change). It is not a flag we ship on production L2 modules.
- Setting it module-wide on every L2 spec package as a permanent mechanism for L3-policy raw reach turns `@testable` into the new SPI surface — replacing one informal escape hatch (`@_spi(Syscall)`) with another (`@testable`).
- `@testable` is intended for test targets. Co-opting it as a production cross-module access mechanism is exactly the kind of soft-rule violation that auditors flag and that drifts back into hard-rule territory over the course of a year.

PRACTICALLY REFUTED for ecosystem-wide adoption.

### 3.4 V4 — `package` raw form

| Receipt | Result |
|---|---|
| `V4-debug.txt` | GREEN |
| `V4-release.txt` | GREEN |
| `V4-cross-module.txt` | `V4 (b) raw via package: rc=0` |

Within the experiment's single `Package.swift`, `package` access works between V4_Consumer and V4_L2. SE-0386 specifies that `package` access is scoped to one SPM package — it does NOT span sibling `Package.swift` files.

In our ecosystem, every layer is its own SPM package: `swift-iso-9945` (L2 POSIX), `swift-windows-standard` (L2 Win32), `swift-darwin-standard` (L2 Darwin), `swift-linux-standard` (L2 Linux), `swift-posix` (L3-policy POSIX), `swift-darwin` (L3-policy Darwin), `swift-linux` (L3-policy Linux), `swift-windows` (L3-policy Windows), `swift-kernel` (L3-unifier). Each of these has its own `Package.swift`. The L2-to-L3-policy edge — the very edge where raw FFI reach matters — crosses a `Package.swift` boundary in every case.

`package` therefore provides no mechanism for cross-stack-package raw reach. Within an SPM package, `package` is useful for benchmark / private-target access; across SPM packages, it is invisible.

STRUCTURALLY REFUTED for cross-stack raw reach in our topology. (Within-package use is unaffected — this verdict is specifically about the L2↔L3-policy edge.)

### 3.5 V5 — typed-only L2; consumer writes own raw shim

| Receipt | Result |
|---|---|
| `V5-debug.txt` | GREEN |
| `V5-release.txt` | GREEN |
| `V5-cross-module.txt` | `V5 (b) raw via consumer-owned shim: rc=0` |

Mechanically CONFIRMED. Architecturally:

- Every consumer needing raw duplicates an FFI binding. With ~36 sites across four L2 spec packages plus four L3-policy packages plus L3-unifier, this duplication is multi-hundred lines of redundant `import Darwin` / `import Glibc` / `import Musl` / `import WinSDK` and per-syscall thin wrappers.
- General consumers (e.g., a `swift-file-system` end-user, a benchmark in `swift-io`'s repository) writing their own raw shim VIOLATES [PLAT-ARCH-008a] — non-platform-stack consumers are not allowed to import Darwin/Glibc/Musl/WinSDK directly.
- The "consumer" in the L2↔L3-policy case is, however, `swift-posix` itself — a *platform-stack* package, which IS permitted to import platform C per [PLAT-ARCH-008a]. So the V5 pattern, applied narrowly to L3-policy as the "consumer", is not a [PLAT-ARCH-008a] violation.

Reframed this way, V5 splits cleanly:

- **V5-as-general-consumer-pattern**: STRUCTURALLY REFUTED by [PLAT-ARCH-008a].
- **V5-as-L3-policy-pattern**: CONFIRMED and architecturally clean — L3-policy packages are platform-stack packages, [PLAT-ARCH-008a] permits them to import platform C, and they already do (e.g., swift-posix already binds libc for retry-wrapping fsync).

This split is the substance of the recommendation in §4.

### 3.6 V6 — typed everywhere, no raw at any layer

| Receipt | Result |
|---|---|
| `V6-debug.txt` | GREEN |
| `V6-release.txt` | GREEN |
| `V6-cross-module.txt` | `V6 (b) raw: REFUTED — no raw access; production raw use cases unserved` |

V6 *builds*. The refutation is at the use-case-coverage level, not the build-success level. Production raw-required use cases that no purely typed surface can serve without unbounded growth:

1. **Benchmark bypass**: measuring `close(2)` cost without retry overhead. Solvable INSIDE the L3-policy SPM package as a private benchmark target with `package` access to L3-policy's own raw binding (V2-style at L3-policy). Doesn't require L2 raw, doesn't require @_spi.
2. **`posix_spawn_file_actions_addclose(_:_:)`**: takes raw `Int32` fd that the child process inherits. The typed `Descriptor.consuming` semantics conflict with the descriptor staying alive across the spawn for the child to inherit. Solvable as a typed `SpawnActions.add(close: borrowing Descriptor)` at L3-policy, where L3-policy reaches `descriptor._rawValue` and binds it into the C `posix_spawn_file_actions_t` privately.
3. **`setrlimit` / `dup2` fd-table manipulation**: the fd table is reasoned about as integer slots. Solvable by typed APIs that take `Descriptor`s and convert to integers internally at the L3-policy boundary.
4. **ABI shims for non-Swift callers** (C, Objective-C, Rust FFI): these consumers literally have an `Int32` with no Descriptor in sight. Solvable by dedicated bridge packages (e.g., a notional `swift-c-bridge`) that own the raw boundary as their explicit job — separate from L2 spec packages.
5. **`select(2)` / `poll(2)` legacy fd-set handling**: typed APIs over fd-sets exist (`Kernel.Event.Poll.wait`); legacy fd_set is wrapped at L3-policy.

Result: **V6's strict reading ("no raw at any architectural layer") is REFUTED** — L3-policy's libc binding is *itself* raw access, just confined to a layer where it is architecturally permitted. **V6's pragmatic reading ("no raw at L2 public/SPI surface") is CONFIRMED** and matches the recommended pattern.

The terminology matters because the user direction reads "MUST NOT appear in any L2 API surface". That is V6-pragmatic, achievable. "No raw at any layer" is V6-strict, not achievable, not what user direction requires.

## 4. Recommendation

**Adopt a hybrid: V2 at L2 + L5-style binding at L3-policy.**

| Layer | Pattern | Raw FFI surface |
|---|---|---|
| L2 spec (swift-iso-9945, swift-{darwin,linux,windows}-standard) | **V2** — typed-only public surface; raw binding is file-scope `private` inside L2 if used at all (e.g., for L2's own typed wrappers) | None reachable from outside L2 |
| L3-policy (swift-posix, swift-{darwin,linux,windows}) | **V5-as-L3-policy** — owns its own libc / WinSDK binding directly; this is permitted under [PLAT-ARCH-008a] because L3-policy IS a platform-stack package | Internal to L3-policy; not exported |
| L3-unifier (swift-kernel) | Composes L3-policy per [PLAT-ARCH-008e]; pure typed surface | None |
| L4+ consumers (swift-foundations packages, applications) | Typed API only via Kernel | None |

**The architectural shift**: today L2 owns the raw FFI binding (with `@_spi(Syscall)` for L3-policy reach). After phase-out, L3-policy owns the raw FFI binding (with no L2 escape hatch). L2 becomes a strictly typed, spec-literal layer — `Descriptor` types, `Error` enums, typed throwing wrappers that L3-policy may or may not delegate to. L3-policy holds the C bindings privately and exposes typed forms.

**Why this respects each rule**:

| Rule | How recommendation respects it |
|---|---|
| [PLAT-ARCH-005a] No platform C types in public API | L2 has no platform C types in its public surface (V2 hides them). L3-policy has no platform C types in its public surface (binding is internal). |
| [PLAT-ARCH-008a] Consumers don't bypass platform stack | L3-policy IS a platform-stack package. Importing platform C is permitted. Non-platform-stack consumers see typed only. |
| [PLAT-ARCH-008c] L1 platform-agnostic | Untouched — primitives stay platform-agnostic. |
| [PLAT-ARCH-008e] L3-unifier composes L3-policy | Preserved — L3-unifier (swift-kernel) calls L3-policy typed forms, which now hold the binding directly. |
| [API-NAME-001 / 002] Nest.Name + no compounds | Typed surfaces follow the existing rules; no change. |
| User direction (Path X close): no `@_spi(Syscall)`, no raw ints in L2 API | L2 surface is typed-only. `@_spi(Syscall)` does not appear. No `Int32` in L2's API surface. |

**Why the L3-policy binding is not a duplication problem**:

[PATTERN-001] already endorses per-package C-shim independence: *"Each platform's shim MUST be independent — even when wrapping identical C functions — to maintain independent compilability."* The L3-policy binding, when it holds the libc reach previously held by L2, is the canonical home — consistent with [PATTERN-001]'s model where per-package independence is a feature, not a flaw.

The current ecosystem already has L3-policy packages doing platform C imports for some operations (e.g., swift-posix's pthread bindings). Moving the rest of the C bindings up from L2 to L3-policy unifies the architecture: L2 is *spec types*, L3-policy is *platform binding*. Today's split (L2 holds bindings via @_spi, L3-policy wraps them) is the legacy pattern that Path X retires.

## 5. Migration Plan for the ~36 Existing Sites

**Per-site evaluation, mechanically guided.** Mass conversion is feasible but each site is one of two shapes:

### Shape A — L3-policy already has its own libc binding for this syscall

The L3-policy site already imports platform C and has its own raw call (e.g., for retry construction or platform error mapping). The L2 raw companion is dead code — only the L3-policy import via `@_spi(Syscall)` keeps it alive in the link graph.

**Action** (one PR per L2 package):
1. Delete the `@_spi(Syscall) public func name(_:Int32) -> Int32` site at L2.
2. Delete `@_spi(Syscall) import` at L3-policy.
3. Verify L3-policy still binds platform C directly (it does; that's the precondition for Shape A).
4. Build green, no-op semantically.

### Shape B — L3-policy reaches L2's raw via @_spi but does not have its own binding

L3-policy's typed wrapper today calls L2's raw form via the `@_spi(Syscall) import`; L3-policy itself does not directly import libc for this syscall. After phase-out, L3-policy must add its own libc binding.

**Action** (one PR per (L2-package, L3-policy-package) pair):
1. Add libc binding at L3-policy (private function or per-package C shim per [PATTERN-001]).
2. Update L3-policy's typed wrapper to call its own binding instead of `@_spi(Syscall)` L2 raw.
3. Delete the `@_spi(Syscall)` L2 raw site.
4. Drop `@_spi(Syscall) import` at L3-policy.
5. Build green; verify retry semantics survive (L3-policy's existing tests).

**Per-site triage step** (do this before ANY deletion):

Grep each candidate L3-policy package for direct platform C imports (`import Darwin`, `import Glibc`, `import Musl`, `import WinSDK`). If the import already exists in the L3-policy file that wraps the syscall, the site is Shape A. If not, Shape B. The grep is cheap (`grep -r "^import \(Darwin\|Glibc\|Musl\|WinSDK\)" swift-posix/Sources/`) and triages all ~36 sites in one pass.

**Sequencing**: Shape A deletions are zero-risk and can land first as a cleanup wave. Shape B conversions need pairwise coordination (the L2 deletion and the L3-policy binding addition must land together to avoid broken builds during migration). Shape B sites should be batched per-platform and per-syscall-family (e.g., "all File close-family across iso-9945 + posix in one wave"; then "all File flush-family"; etc.) to keep PR scope reviewable.

**Estimated effort**: ~36 sites × ~10 minutes triage + ~30 minutes per Shape B conversion (2/3 of sites estimated Shape B; 1/3 Shape A) ≈ 12-18 hours of mechanical work + review cycles. The work is shaped for incremental landing, not a big-bang rewrite.

## 6. V6 Feasibility — Final Verdict

**V6's strict reading is empirically REFUTED**: zero raw access at any architectural layer is not achievable while preserving the existing platform stack's role separation. L3-policy genuinely needs to bind libc to do its job (retry, error normalization, posix_spawn integration). Forbidding raw at *every* layer would either dissolve L3-policy as a layer (its job vanishes) or push the binding into the L3-unifier (swift-kernel), which would conflate domain-neutral unification with platform-policy mechanics — violating [PLAT-ARCH-008e]'s decomposition.

**V6's pragmatic reading is empirically CONFIRMED**: zero raw at the L2 public/SPI surface IS achievable, AND it's the only stable interpretation of the user direction "raw integer types MUST NOT appear in any L2 API surface (public OR @_spi)". The pragmatic V6 is what this recommendation adopts.

**Naming clarification**: the current "V6" framing in the experiment's variant table is empirically ambiguous between strict and pragmatic readings. Future references should disambiguate:

- "V6-strict" — no raw FFI at any architectural layer (refuted, non-achievable).
- "V6-pragmatic" — no raw FFI at L2's public/SPI surface (confirmed, recommended).

The recommendation IS V6-pragmatic, achieved via V2 at L2 + L3-policy holding the binding privately.

## 7. References

- Experiment: `swift-institute/Experiments/spi-syscall-phase-out-layering/`
  - Build receipts: `Outputs/V{1..6}-{debug,release,cross-module}.txt`
  - Per-variant analysis: `EXPERIMENT.md`
- Platform skill rules: [PLAT-ARCH-005a], [PLAT-ARCH-008a], [PLAT-ARCH-008c], [PLAT-ARCH-008e], [PATTERN-001]
- Code-surface rules: [API-NAME-001], [API-NAME-002], [API-ERR-001], [API-IMPL-005]
- Experiment-process rules: [EXP-002a], [EXP-002c], [EXP-003e], [EXP-006], [EXP-009], [EXP-017]
- Path X close (2026-04-30) — user direction governing the L2 raw-int surface
- SE-0386 (Swift package access)
