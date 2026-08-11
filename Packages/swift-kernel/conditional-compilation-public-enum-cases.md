# Conditional Compilation on Public Enum Cases

<!--
---
version: 1.0.0
last_updated: 2026-03-24
status: DECISION
---
-->

## Context

A platform audit of swift-kernel flagged `Kernel.Failure` finding #6: the `.signal(Kernel.Signal.Error)` case is wrapped in `#if !os(Windows)`, which forces any consumer exhaustively switching on `Kernel.Failure` to also write `#if !os(Windows)`. This potentially violates [PLAT-ARCH-008], which states that consumer code above L3 must never contain `#if os(...)`.

**Trigger**: Platform audit finding #6 in `swift-kernel/Research/audit.md`.

**Constraint**: `Kernel.Signal.Error` is defined in swift-iso-9945 (POSIX standard, Layer 2). Windows has no dependency on swift-iso-9945. The type fundamentally cannot exist on Windows without architectural changes.

**Scope**: Package-specific (swift-kernel), but with ecosystem-wide implications if this is a recurring pattern.

## Question

Is `#if !os(Windows)` on `case signal(Kernel.Signal.Error)` in `Kernel.Failure` the correct design, or should the API surface be unconditional to preserve the L3 guarantee?

## Analysis

### Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Consumer unconditional code | High | [PLAT-ARCH-008]: consumer code must not contain `#if os(...)` |
| Semantic honesty | High | API surface must accurately reflect platform reality |
| Dependency feasibility | High | Can the type exist on all platforms? |
| Current consumer impact | Medium | Does this actually affect anyone today? |
| Prior art alignment | Medium | What do comparable systems do? |
| Future-proofing | Low | Does this constrain future evolution? |

### Prior Art Survey

#### Pattern A: Unconditional Superset

**Rust `std::io::ErrorKind`**: Single `#[non_exhaustive]` enum. All ~40 variants exist on all platforms. `Interrupted` (EINTR) exists on Windows but is never produced by OS error decoding. Platform variation lives in the mapping layer (`decode_error_kind()`), not the type definition. Consumers write platform-agnostic match arms; unreachable branches are dead code.

**Go `syscall.Errno` / `os.Signal`**: Invents synthetic POSIX constants on Windows. `EINTR`, `SIGHUP`, `SIGINT` etc. are defined as invented numeric values in the Windows `syscall` package. The constants are meaningless on Windows (never returned by kernel APIs) but allow cross-platform code to compile uniformly.

**libuv `uv_errno_t`**: Unified unconditional error space via X-macro. `UV__EINTR` has different numeric values per platform (negated system `EINTR` on Unix, synthetic `-4072` on Windows). The consumer-facing enum is fully unconditional.

**Boost.System `errc::errc_t`**: Unconditional POSIX-like error condition enum. `interrupted` exists everywhere (Windows CRT defines `EINTR = 4`). Platform mapping is in `system_category::default_error_condition()`. Consumers compare against conditions, never need platform conditionals.

#### Pattern B: Honest Platform Conditionals

**Apple swift-system `Errno`**: Struct wrapping `CInt`. ~20 of 224 static properties are behind `#if os(...)` guards. `Errno.interrupted` (EINTR) is unconditional (Windows CRT defines `EINTR`). But `notBlockDevice` (ENOTBLK), `textFileBusy` (ETXTBSY), and Darwin-specific errnos ARE conditional. Consumers handling platform-specific errors MUST use `#if` guards.

**Rust `nix` crate**: POSIX-only (does not support Windows). Within the Unix world, uses `#[cfg]` on individual `Errno` variants between Unix flavors (e.g., `ENOTBLK` absent on Haiku).

#### Summary

| System | Error type unconditional? | Platform-absent errors | Consumer needs `#if`? |
|--------|--------------------------|------------------------|----------------------|
| Rust std::io::ErrorKind | Yes | Variant exists, never produced | No |
| Go syscall | Yes (synthetic constants) | Constant exists, never returned | No |
| libuv | Yes (X-macro) | Synthetic numeric value | No |
| Boost.System errc | Yes | Condition exists, never equivalent | No |
| swift-system Errno | Partially (~20 conditional) | Compile error if referenced | Yes |
| Rust nix | N/A (POSIX-only) | `#[cfg]` per Unix variant | Yes |

Two dominant approaches: **unconditional superset** (Rust std, Go, libuv, Boost) and **honest conditionals** (swift-system, nix). The unconditional superset approach relies on language features that Swift lacks: Rust has `#[non_exhaustive]`, Go has no exhaustive matching, libuv/Boost are C/C++ without sum type exhaustiveness.

### Design Options

#### Option A: Conditional Compilation (Current)

```swift
// Kernel.Failure
#if !os(Windows)
    case signal(Kernel.Signal.Error)
#endif

// Consumer (hypothetical exhaustive switch)
switch failure {
case .path(let e): ...
case .io(let e): ...
#if !os(Windows)
case .signal(let e): ...  // Consumer forced to write #if
#endif
case .platform(let e): ...
// ...
}
```

| Criterion | Assessment |
|-----------|------------|
| Consumer unconditional code | Violated in theory (forces `#if` on exhaustive switches) |
| Semantic honesty | Perfect (no misleading cases) |
| Dependency feasibility | N/A (no changes needed) |
| Current consumer impact | Zero (no exhaustive switches exist) |
| Prior art alignment | Matches swift-system approach |

#### Option B: Unconditional Case, Never Produced on Windows

```swift
// Kernel.Failure — all platforms
case signal(Kernel.Signal.Error)  // Signal.Error must compile on Windows

// Consumer — no conditionals
switch failure {
case .signal(let e): handleSignal(e)  // dead code on Windows
// ...
}
```

**Blocker**: `Kernel.Signal.Error` is `ISO_9945.Kernel.Signal.Error`, defined in swift-iso-9945 (L2 POSIX standard). The import chain is:

```
ISO_9945.Kernel.Signal.Error  (swift-iso-9945, L2)
  ↓ re-exported as
POSIX.Kernel.Signal.Error     (swift-posix, L3)
  ↓ conditionally imported in
Kernel.Signal.Error           (swift-kernel, L3)
  ↓ only on
macOS, iOS, tvOS, watchOS, visionOS, Linux
```

Windows has no path to swift-iso-9945. To make this work:

1. **Stub in Kernel Primitives (L1)**: Add an empty `Kernel.Signal.Error` enum to swift-kernel-primitives. On POSIX, the ISO 9945 definition would shadow or extend it. On Windows, the stub compiles but is uninhabited.
   - Pro: Unconditional API surface.
   - Con: A signal error type on a platform with no signals is a semantic lie. Violates the principle that L1 types represent genuine domain concepts, not compilation stubs.

2. **Bridge type in swift-kernel (L3)**: Create a `Kernel.Failure.SignalError` wrapper that exists on all platforms but wraps `ISO_9945.Kernel.Signal.Error` only on POSIX.
   - Pro: Contained to L3.
   - Con: Adds a shim type that exists solely for compilation, with no semantic content on Windows.

| Criterion | Assessment |
|-----------|------------|
| Consumer unconditional code | Satisfied |
| Semantic honesty | Poor (type promises signal errors on Windows, cannot deliver) |
| Dependency feasibility | Requires stub type or bridge — architectural cost |
| Current consumer impact | Zero improvement (no exhaustive switches exist) |
| Prior art alignment | Matches Rust std / Go / libuv approach, but those languages have `#[non_exhaustive]` or no exhaustive matching |

#### Option C: Absorb Signal Errors into .platform on POSIX

```swift
// No .signal case at all
// EINTR maps to .platform(Kernel.Error) or .io(Kernel.IO.Error) on POSIX
```

| Criterion | Assessment |
|-----------|------------|
| Consumer unconditional code | Satisfied (no conditional case) |
| Semantic honesty | Poor on POSIX (loses "this was a signal interruption" meaning) |
| Dependency feasibility | Easy |
| Current consumer impact | **Already the status quo for EINTR handling** (see below) |

Critical observation: the two consumer files that handle EINTR (`File.System.Read.Full.swift:233` and `File.System.Write.Append.swift:158`) already route through `.platform(let kernelError)` on domain-specific error types (`Kernel.IO.Read.Error`, `Kernel.IO.Write.Error`), NOT through `Kernel.Failure.signal`. The `.signal` case on `Kernel.Failure` is a semantic marker for signal-specific operations (sigaction, sigmask failures), not for cross-cutting EINTR retry.

#### Option D: Non-Exhaustive Enum

Swift lacks `#[non_exhaustive]` for non-resilient libraries. Library evolution mode would enable `@frozen` / non-frozen semantics, but SwiftPM packages do not use library evolution by default. Enabling it would impose ABI stability requirements on the entire package — disproportionate to the problem.

`@unknown default` can be used without library evolution as a consumer-side annotation, but it generates compiler warnings for missing cases rather than preventing the need for `#if` guards.

| Criterion | Assessment |
|-----------|------------|
| Consumer unconditional code | Partially (requires library evolution or consumer cooperation) |
| Semantic honesty | Good |
| Dependency feasibility | Requires library evolution mode — disproportionate |
| Current consumer impact | Zero improvement |

### Dependency Chain

```
Kernel.Signal.Error
  = ISO_9945.Kernel.Signal.Error
    defined in: swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Kernel.Signal.Error.swift:23-46
    C imports:  Darwin | Glibc | Musl (internal, #if guarded)
    depends on: Kernel_Primitives (L1, cross-platform)

ISO_9945.Kernel.Signal
    defined in: swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Kernel.Signal.swift:15-45
    POSIX-only namespace

Re-export chain:
    ISO_9945 → POSIX_Kernel (swift-posix, L3) → Darwin_Kernel | Linux_Kernel (L3) → Kernel_Core (swift-kernel, L3)
    Windows path: Windows_Kernel_Primitives (L1) → Windows_Kernel (L3) → Kernel_Core (no ISO 9945)
```

**Conclusion**: `Kernel.Signal.Error` is an irreducibly POSIX type. Its definition depends on POSIX C headers (`EINTR`, `EINVAL`, `EPERM`, `ESRCH` constants from `<signal.h>`). While the Windows CRT does define `EINTR = 4` for C compatibility, it does NOT define the signal operation semantics (`sigaction`, `sigprocmask`, `kill`, `raise`) that the error cases represent.

### Ecosystem Pattern Search

**`.signal` is the only conditionally-compiled public enum case in the entire ecosystem.**

- 31 files across swift-primitives, swift-standards, and swift-foundations contain `#if os()` inside public types.
- All other instances guard **initializers**, **computed properties**, or **method implementations** — never case declarations.
- Error types at L1 (`Kernel.IO.Error`, `Kernel.Memory.Error`, `Kernel.Storage.Error`, `Kernel.Permission.Error`, `Kernel.IO.Blocking.Error`) use `#if os(Windows)` / `#else` on their `init?(code:)` initializers, keeping the case declarations unconditional.

The L1 error types demonstrate the ecosystem's preferred pattern: unconditional cases, conditional mapping. `Kernel.Failure.signal` is the sole exception because the type it wraps (`Kernel.Signal.Error`) cannot exist on Windows — unlike the L1 error types whose cases are defined in terms of `Kernel.Error.Code` (a cross-platform type).

### Consumer Impact

| Metric | Count | Details |
|--------|-------|---------|
| Exhaustive switches on Kernel.Failure | 0 | All matches use `default:` or match specific cases |
| Consumer constructions of `.signal` | 0 | Only internal to Kernel.Failure |
| Non-exhaustive matches on Kernel.Failure | 0 | Consumers use domain-specific error types, not Kernel.Failure |
| EINTR retry patterns | 2 | Both use `.platform` on Kernel.IO.{Read,Write}.Error, not Kernel.Failure |
| Platform-conditional consumer code for Kernel.Failure | 0 | The 5 files with `#if os(Windows)` handle `.platform` on domain errors |

The `.signal` case has **zero consumer reach**. No code outside `Kernel.Failure.swift` itself references, constructs, or matches on it. The EINTR retry pattern in swift-file-system operates on domain-specific error types, bypassing `Kernel.Failure` entirely.

### Comparison Matrix

| Criterion | A: Conditional (current) | B: Unconditional + stub | C: Absorb into .platform | D: Non-exhaustive |
|-----------|--------------------------|------------------------|--------------------------|-------------------|
| Consumer unconditional | Theoretical violation | Satisfied | Satisfied | Partial |
| Semantic honesty | Excellent | Poor (stub type) | Poor (loses meaning) | Good |
| Dependency cost | None | Stub type in L1 or bridge in L3 | Remove `.signal` | Library evolution |
| Current consumer impact | None | None | None | None |
| Prior art | swift-system | Rust std, Go | (none — lossy) | (N/A in Swift) |
| Complexity | Low | Medium | Low | High |

## Outcome

**Status**: DECISION

**Decision**: Option A (conditional compilation) is correct. The `#if !os(Windows)` on `case signal(Kernel.Signal.Error)` is the right design for the following reasons:

1. **Zero consumer impact**: No consumer writes exhaustive switches on `Kernel.Failure`. No consumer references `.signal`. The [PLAT-ARCH-008] violation is theoretical only — it would require a consumer to (a) exhaustively switch on `Kernel.Failure` AND (b) explicitly handle `.signal` differently from `default`.

2. **Irreducible platform concept**: POSIX signals are not a leaky abstraction that L3 should hide — they are a fundamental platform concept that genuinely does not exist on Windows. Unlike EINTR (which is a cross-cutting errno value present in the Windows CRT), `Kernel.Signal.Error` represents signal operations (`sigaction`, `kill`, `raise`) with no Windows analogue. The conditional case accurately reflects reality.

3. **Dependency chain makes Option B infeasible without compromise**: `Kernel.Signal.Error` lives in swift-iso-9945 (L2 POSIX standard). Creating a stub or bridge type adds semantic dishonesty (a signal error type on a platform with no signals) for zero practical benefit.

4. **Prior art validates the approach**: Apple's swift-system uses the same pattern — honest platform conditionals on ~20 of 224 `Errno` properties. When the underlying concept is genuinely absent on a platform, omitting it is more honest than providing a compile-but-never-produce stub.

5. **Ecosystem pattern is consistent**: All other L1 error types use unconditional cases with conditional initializers because their case types (`Kernel.Error.Code`) are cross-platform. `.signal` is the sole exception because its wrapped type is POSIX-specific. The exception is justified by the different dependency structure, not an inconsistency.

**If this decision needs revisiting**: Should Swift gain `@nonExhaustive` semantics for non-resilient libraries (analogous to Rust's `#[non_exhaustive]`), Option B could become viable without library evolution overhead. Track Swift Evolution for proposals in this area.

## References

- `Kernel.Failure.swift`: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Core/Kernel.Failure.swift`
- `ISO_9945.Kernel.Signal.Error`: `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Kernel.Signal.Error.swift`
- Audit finding #6: `/Users/coen/Developer/swift-foundations/swift-kernel/Research/audit.md` (Platform section)
- Rust `std::io::ErrorKind`: `library/std/src/io/error.rs` — `#[non_exhaustive]` unconditional enum
- Apple swift-system `Errno`: `Sources/System/Errno.swift` — `#if os()` on individual properties
- Go `syscall`: `src/syscall/types_windows.go` — synthetic POSIX constants
- libuv: `include/uv/errno.h` — unconditional X-macro with synthetic fallback values
- Boost.System: `include/boost/system/detail/errc.hpp` — two-tier error code / error condition
