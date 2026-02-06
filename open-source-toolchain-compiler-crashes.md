# Open-Source Toolchain Compiler Crashes

<!--
---
version: 1.1.0
last_updated: 2026-02-06
status: DECISION
tier: 3
---
-->

## Context

All 61+ packages in the swift-primitives monorepo build successfully with Xcode's
bundled Swift 6.2.3 toolchain but crash when compiled with the swift.org open-source
Swift 6.2.3 toolchain or any available `main` development snapshot. This blocks all
command-line builds via `swift build` when using swiftly (the official Swift toolchain
manager) and affects CI/CD pipelines that rely on swift.org toolchains.

### Trigger

The swift-primitives ecosystem makes extensive use of `~Copyable` and `~Escapable`
types with `@_lifetime` annotations, `_read`/`_modify` coroutine accessors, and
closure parameters — all experimental features enabled via `-enable-experimental-feature Lifetimes`.

### Impact

- **Scope**: Ecosystem-wide — affects every package that transitively depends on
  `Property_Primitives`, `Comparison_Primitives_Core`, `Algebra_Field_Primitives`,
  or `Bit_Field_Primitives`.
- **Severity**: Complete build failure (signal 6 / assertion failure).
- **Duration**: Ongoing — no swift.org toolchain (release or snapshot) successfully
  builds the monorepo as of 2026-02-06.

## Question

How should the Swift Institute handle the divergence between Xcode-bundled and
swift.org open-source toolchains, given that the open-source builds include
`+assertions` and SIL verification that exposes compiler bugs not caught by
Xcode's non-assertions build?

## Prior Art Survey

### Swift Evolution Proposals

| Proposal | Title | Status | Relevance |
|----------|-------|--------|-----------|
| [SE-0390](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) | Noncopyable structs and enums | Accepted | Introduces `~Copyable` |
| [SE-0446](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md) | Nonescapable Types | Accepted with modifications | Introduces `~Escapable` |
| [SE-0437](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) | Noncopyable Standard Library Primitives | Accepted | stdlib `~Copyable` support |
| [SE-0465](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md) | Nonescapable Standard Library Primitives | Accepted | stdlib `~Escapable` support |

The `@_lifetime` attribute is described as a "supported experimental feature" in
Swift 6.2 ([Swift Forums announcement](https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638)),
explicitly noted as potentially deprecated once an official lifetime-dependency
mechanism is standardized.

The [Property Lifetimes design document](https://gist.github.com/atrick/9409356c89a5f67dd9f68f708f57262e)
specifies that `_read` is required for `~Escapable` types in yielded property
access, and that yielded values maintain borrowed ownership semantics.

### Known Compiler Issues (swiftlang/swift)

| Issue | Title | Relevance | Status |
|-------|-------|-----------|--------|
| [#85275](https://github.com/swiftlang/swift/issues/85275) | ~Copyable/~Escapable crash, inconsistent error based on `final` | Directly related: SIL ownership crash with `~Escapable` + `@_lifetime(borrow)` | Open |
| [#83597](https://github.com/swiftlang/swift/issues/83597) | SIL verification crash in ownership lowering | Related: SIL verifier "Load borrow invalidated by local write" | Closed |
| [#84899](https://github.com/swiftlang/swift/issues/84899) | SIL verification fails in release mode (swift-java) | Related: assertions-only SIL verification failure | Closed |
| [#80759](https://github.com/swiftlang/swift/issues/80759) | OSS 6.1 toolchain MoveOnlyChecker crash | Related: `~Copyable` assertion in OSSALifetimeCompletion | Open |
| [#79722](https://github.com/swiftlang/swift/issues/79722) | OSS toolchain IRGen crash (AsyncHTTPClient) | Pattern match: OSS-only crash, Xcode-clean | Open |
| [swift-configuration#115](https://github.com/apple/swift-configuration/issues/115) | Compiler crash with swift.org 6.2.3, works with Xcode 6.2.3 | Pattern match: identical version, divergent behavior | Closed |

### Swift Forums Discussions

| Thread | Key Finding |
|--------|-------------|
| [Consistent assertion behavior](https://forums.swift.org/t/can-we-get-consistent-assertion-behavior-in-the-latest-release-swift-compiler-across-host-platforms/80545) | No resolution: swift.org macOS/Windows toolchains ship `+assertions`, Xcode and Linux do not. Community consensus is this is problematic but no decision was reached. |
| [Assertions and SIL verifier overhead](https://forums.swift.org/t/compiler-performance-overhead-of-assertions-and-sil-verifier/42983) | Assertions add 10-15% compile time. Disabling assertions implicitly disables SIL verifier. Proposal for optional "asserts toolchains" was made but not implemented. |

## Analysis

### Crash 1: SIL Verifier — `Comparison.Protocol+Property.View.swift:29`

**Toolchains affected**: swift-6.2.3-RELEASE (+assertions)
**Toolchains clean**: Xcode 6.2.3 (no assertions), main snapshots

**Triggering code** (`swift-comparison-primitives`):
```swift
extension Comparison.`Protocol` where Self: ~Copyable {
    public var compare: Property<Comparison.Compare, Self>.View {
        mutating _read {
            yield unsafe Property<Comparison.Compare, Self>.View(&self)
        }
    }
}
```

**SIL error**:
```
Found over consume?!
Value:   %7 = apply ... Property<Comparison.Compare, Self>.View
Consuming Users:
  destroy_value %7
  %8 = mark_dependence [nonescaping] %7 on %5
```

**Root cause**: The SIL verifier detects that the `Property.View` value (`%7`) is
consumed twice — once by `mark_dependence [nonescaping]` (which models the
`@_lifetime(borrow base)` dependency) and once by `destroy_value` (cleanup).
This is an ownership modeling error in the SIL generation for `_read` coroutines
that yield `~Escapable` values with lifetime dependencies.

The `Property.View` type is `~Copyable & ~Escapable` with:
```swift
@_lifetime(borrow base)
public init(_ base: UnsafeMutablePointer<Base>) { ... }
```

The interaction of `_read` (coroutine yield) + `~Escapable` (requires `mark_dependence`)
+ `~Copyable` (no implicit copy to split the consume) creates a double-consume that
the SIL verifier correctly identifies but that is benign at runtime (the
`mark_dependence` is a no-op in codegen).

### Crash 2: IRGen — `Algebra.Field+Bit.swift:33`

**Toolchains affected**: swift-6.2.3-RELEASE, main-snapshot-2026-01-09, main-snapshot-2026-02-05
**Toolchains clean**: Xcode 6.2.3

**Triggering code** (`swift-bit-primitives`):
```swift
extension Algebra.Field where Element == Bit {
    public static var z2: Self {
        .init(
            // ...
            reciprocal: { $0 }  // line 33 — identity closure
        )
    }
}
```

**Error**: Fatal error during `IRGenRequest` — crash while emitting IR for the
identity closure `{ $0 }` in a context constrained by `~Copyable` element types.

**Root cause**: The IRGen pass hits assertion `(hasErrorResult())` in
`getMutableErrorResult` (`Types.h`) when emitting a closure `{ $0 }` assigned
to a stored property typed as `(T) throws(Error) -> T`, where `Error` is a
nested type of the enclosing generic struct and `T` is concretized via a
constrained extension. This is NOT specific to `~Copyable` — it affects any
generic type with a nested error type used in typed throws. Crashes on both
6.2.3-RELEASE and main snapshots.

### Toolchain Divergence Matrix

| Toolchain | Build | Assertions | SIL Verifier | Crash 1 (SIL) | Crash 2 (IRGen) | Result |
|-----------|-------|------------|--------------|---------------|-----------------|--------|
| Xcode 6.2.3 | `swiftlang-6.2.3.3.21` | Off | Off | — | — | **Clean** |
| swift.org 6.2.3 | `swift-6.2.3-RELEASE` | **On** | **On** | **Crash** | **Crash** | Fail |
| main-snapshot-2026-01-09 | `6.3-dev` | **On** | **On** | — | **Crash** | Fail |
| main-snapshot-2026-02-05 | `6.3-dev` | **On** | **On** | — | **Crash** | Fail |

No open-source toolchain successfully builds the monorepo. The two crashes are
independent bugs that happen to partition across the release and development branches.

### The `+assertions` Problem

The [Swift Forums discussion](https://forums.swift.org/t/can-we-get-consistent-assertion-behavior-in-the-latest-release-swift-compiler-across-host-platforms/80545)
reveals this is a known, unresolved ecosystem problem:

- swift.org macOS toolchains ship with `+assertions` (SIL verifier enabled)
- Xcode toolchains ship without assertions (SIL verifier disabled)
- Linux swift.org toolchains ship without assertions
- No official policy exists on which is "correct"

The SIL verifier catches genuine codegen bugs (Crash 1 is a real double-consume),
but the current state means code that compiles on Xcode may crash the swift.org
compiler, creating an untenable situation for projects that need both.

## Options

### Option A: Disable swiftly, use Xcode toolchain exclusively

**Description**: Comment out swiftly from shell profile, rely on `/usr/bin/swift`
which delegates to Xcode's bundled toolchain.

| Criterion | Assessment |
|-----------|------------|
| Immediacy | Immediate — no code changes required |
| CI/CD impact | Requires macOS runners with Xcode installed |
| Linux support | Blocked — no Xcode on Linux |
| Cross-platform parity | Lost — cannot verify same toolchain across platforms |
| Correctness | Masks real compiler bugs that may cause silent miscompilation |

### Option B: File compiler bugs, wait for fixes

**Description**: Report both crashes to swiftlang/swift, continue using Xcode
toolchain until fixes land in a release.

| Criterion | Assessment |
|-----------|------------|
| Immediacy | Months — compiler fixes require triage, implementation, release cycle |
| CI/CD impact | Same as Option A while waiting |
| Correctness | Best long-term — fixes the actual bugs |
| Risk | Experimental features may see deprioritized bug fixes |

### Option C: Workaround the crashing code patterns

**Description**: Restructure `_read` + `~Escapable` yield patterns and closure
expressions to avoid triggering the specific SIL/IRGen bugs.

| Criterion | Assessment |
|-----------|------------|
| Immediacy | Days — requires identifying and testing alternative patterns |
| API impact | May require API changes if workarounds alter signatures |
| Fragility | New code may hit different assertion failures |
| Correctness | Treats symptoms, not cause |

### Option D: Build custom toolchain without assertions

**Description**: Build Swift from source with assertions disabled, distribute
via swiftly or manual installation.

| Criterion | Assessment |
|-----------|------------|
| Immediacy | Hours — requires building Swift from source |
| Maintenance | Ongoing — must rebuild for each Swift release |
| CI/CD impact | Must host custom toolchain artifacts |
| Correctness | Same as Xcode — hides bugs, no worse |

### Comparison

| Criterion | A (Xcode) | B (File bugs) | C (Workaround) | D (Custom) |
|-----------|-----------|---------------|----------------|------------|
| Immediate unblock | Yes | No | Partial | Yes |
| Linux CI support | No | Eventually | Possibly | Yes |
| Long-term fix | No | Yes | No | No |
| Maintenance burden | None | None | Medium | High |
| API stability | Preserved | Preserved | May change | Preserved |

## Outcome

**Status**: DECISION

**Chosen approach**: Option A (Xcode toolchain) + Option B (file bugs). Use the
Xcode-bundled toolchain for immediate unblock while waiting for compiler fixes.

### Actions Taken (2026-02-06)

1. **Disabled swiftly** in `~/.zprofile` to route `swift` to Xcode's toolchain.
   Verified `swift build` succeeds with Xcode 6.2.3 (`swiftlang-6.2.3.3.21`).

2. **Retained swiftly installation** — can be re-enabled by uncommenting the
   `.zprofile` line once a working open-source toolchain is available.

3. **Filed Bug A**: [swiftlang/swift#87029](https://github.com/swiftlang/swift/issues/87029)
   — SIL verifier crash: `_read` yielding `~Escapable` value with `@_lifetime(borrow)`.
   Minimal reproduction (20 lines): [coenttb/swift-issue-sil-verifier-read-escapable-lifetime](https://github.com/coenttb/swift-issue-sil-verifier-read-escapable-lifetime).

4. **Filed Bug B**: [swiftlang/swift#87030](https://github.com/swiftlang/swift/issues/87030)
   — IRGen crash: closure with typed throws using nested Error in generic type.
   Minimal reproduction (8 lines): [coenttb/swift-issue-irgen-typed-throws-nested-error-generic](https://github.com/coenttb/swift-issue-irgen-typed-throws-nested-error-generic).

### Remaining Steps

1. **Monitor the assertions consistency discussion** on Swift Forums — if swift.org
   releases non-assertions macOS toolchains, swiftly can be re-enabled immediately.

2. **Test each new Swift release** against the monorepo before adopting.

3. **Consider workarounds** if compiler fixes are not forthcoming:
   - Bug A: Replace `_read` with a method-based API that avoids the yield +
     `~Escapable` interaction.
   - Bug B: Hoist nested `Error` types to top-level scope (verified workaround).

## References

### Swift Evolution
- [SE-0390: Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0446: Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md)
- [SE-0437: Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- [SE-0465: Nonescapable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md)

### Swift Forums
- [Experimental lifetime dependencies in Swift 6.2](https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638)
- [Consistent assertion behavior across platforms](https://forums.swift.org/t/can-we-get-consistent-assertion-behavior-in-the-latest-release-swift-compiler-across-host-platforms/80545)
- [Compiler performance overhead of assertions](https://forums.swift.org/t/compiler-performance-overhead-of-assertions-and-sil-verifier/42983)
- [Pitch: Non-Escapable Types and Lifetime Dependency](https://forums.swift.org/t/pitch-non-escapable-types-and-lifetime-dependency/69865)

### Compiler Issues (Filed)
- [swiftlang/swift#87029](https://github.com/swiftlang/swift/issues/87029) — **Bug A**: SIL verifier crash with `_read` + `~Escapable` + `@_lifetime(borrow)`
- [swiftlang/swift#87030](https://github.com/swiftlang/swift/issues/87030) — **Bug B**: IRGen crash with typed throws + nested Error in generic type

### Compiler Issues (Related)
- [swiftlang/swift#85275](https://github.com/swiftlang/swift/issues/85275) — ~Copyable/~Escapable ownership crash
- [swiftlang/swift#80759](https://github.com/swiftlang/swift/issues/80759) — OSS toolchain MoveOnlyChecker crash
- [swiftlang/swift#79722](https://github.com/swiftlang/swift/issues/79722) — OSS toolchain IRGen crash
- [swiftlang/swift#79995](https://github.com/swiftlang/swift/issues/79995) — Same assertion as Bug B (`getMutableErrorResult`), different trigger
- [swiftlang/swift#77297](https://github.com/swiftlang/swift/issues/77297) — Nested error in generic + typed throws family
- [swiftlang/swift#76317](https://github.com/swiftlang/swift/issues/76317) — Nested error in `@propertyWrapper` + typed throws
- [swiftlang/swift#73641](https://github.com/swiftlang/swift/issues/73641) — Nested error in generic class + typed throws
- [swift-configuration#115](https://github.com/apple/swift-configuration/issues/115) — swift.org 6.2.3 crash, Xcode clean

### Design Documents
- [Property Lifetimes](https://gist.github.com/atrick/9409356c89a5f67dd9f68f708f57262e) — Andrew Trick's design for property lifetime semantics
- [SIL Ownership](https://github.com/swiftlang/swift/blob/main/docs/SIL/Ownership.md) — SIL ownership model documentation
- [SIL Instructions](https://github.com/swiftlang/swift/blob/main/docs/SIL/Instructions.md) — `mark_dependence` semantics
