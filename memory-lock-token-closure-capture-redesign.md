# Memory.Lock.Token closure-capture redesign

**Status**: research deliverable (Item 1.5, deferred from post-Path-X Wave 4c-deinit-helper Phase 5)
**Date**: 2026-05-02
**Author**: subordinate A (research-then-dispatch protocol)

## Summary

`Memory.Lock.Token` currently holds a witness closure that captures a raw `Int32` file descriptor and reconstructs a typed `Kernel.Descriptor` inside the closure body for the lock-release + close calls. This violates `feedback_no_raw_descriptor_reconstruction` (forbidden pattern #2 — closure capture) and blocks the iso-9945 raw `Kernel.Lock.lock(fd:Int32)` form from being downgraded to `internal` (the post-Wave-4c-deinit-helper cleanup target).

Two redesigns are viable:

- **Option A** (witness-preserving): keep the closure but capture a typed `Kernel.Descriptor` via `var Optional<Descriptor> + .take()!`. Requires typed `Kernel.Descriptor.Duplicate.duplicate(_:borrowing Descriptor)` + typed `Kernel.Lock.unlock(_:borrowing Descriptor, range:)` at iso-9945. Hits a known constraint: `~Copyable` capture in `@Sendable` closures is forbidden by Swift.
- **Option B** (explicit-storage redesign): replace the witness closure with explicit `_descriptor: Kernel.Descriptor?` + `_range: Kernel.Lock.Range` fields. Eliminates closure capture entirely; all ownership tracked via the type system. Same iso-9945 prerequisites as Option A.

**Recommendation**: **Option B**. Cleaner architectural fit with `feedback_language_features_over_custom_types`; eliminates the `@Sendable`-closure-of-`~Copyable` constraint; matches the dominant `feedback_no_raw_descriptor_reconstruction` "use language semantics" guidance.

## (a) Current shape — Memory.Lock.Token + closure capture today

**L1 declaration** at `swift-primitives/swift-memory-primitives/Sources/Memory Primitives Core/Memory.Lock.Token.swift:29-52`:

```swift
extension Memory.Lock {
    public struct Token: ~Copyable, Sendable {
        @usableFromInline
        var _release: (@Sendable () -> Void)?

        @inlinable
        public init(release: @escaping @Sendable () -> Void) {
            self._release = release
        }

        @inlinable
        public mutating func release() {
            _release?()
            _release = nil  // idempotent
        }

        deinit {
            _release?()  // RAII close-on-drop
        }
    }
}
```

The token is a `~Copyable, Sendable` struct holding a single optional `@Sendable () -> Void` closure. `release()` invokes the closure once and clears it; `deinit` invokes the closure if `release()` wasn't called explicitly. RAII close-on-drop semantics; idempotent explicit release.

**L3 acquire site** at `swift-foundations/swift-memory/Sources/Memory/Memory.Lock.Token+Acquire.swift:28-62`:

```swift
public static func acquire(
    descriptor: borrowing Kernel.Descriptor,
    range: Kernel.Lock.Range,
    kind: Memory.Lock.Kind
) throws(Kernel.Lock.Error) -> Memory.Lock.Token {
    let sourceFd = unsafe descriptor._rawValue                    // VIOLATION 1: raw extraction

    let dupedFd: Int32
    do throws(Kernel.Descriptor.Duplicate.Error) {
        dupedFd = try unsafe Kernel.Descriptor.Duplicate.duplicate(fd: sourceFd)  // raw arg
    } catch {
        throw .unavailable
    }

    do throws(Kernel.Lock.Error) {
        try unsafe Kernel.Lock.lock(fd: dupedFd, range: range, kind: kernelKind)  // raw arg
    } catch {
        let fd = unsafe Kernel.Descriptor(_rawValue: dupedFd)     // VIOLATION 2: reconstruction
        try? Kernel.Close.close(consume fd)
        throw error
    }

    return Memory.Lock.Token(release: {
        try? unsafe Kernel.Lock.unlock(fd: dupedFd, range: range)  // closure captures raw Int32
        let fd = unsafe Kernel.Descriptor(_rawValue: dupedFd)      // VIOLATION 3: reconstruction
        try? Kernel.Close.close(consume fd)
    })
}
```

**The release closure captures `dupedFd: Int32` by value** (Swift closure-capture-by-value for trivial types). Inside the closure body, the captured raw Int32 is reconstructed into a typed `Kernel.Descriptor` for the close call.

**Consumer cascade**: only call site is `swift-foundations/swift-memory/Sources/Memory/Memory.Map+Init.swift:80-99` (single coordinated-access mmap call site). The token is stored in `Memory.Map._lockToken: Memory.Lock.Token?` (L1 declaration at `swift-memory-primitives/Memory.Map.swift:64`) and released when the Map drops.

## (b) Specific footgun(s) closure-capture surfaces

**Footgun 1 — raw-descriptor anti-pattern** (per `feedback_no_raw_descriptor_reconstruction`):

The closure captures a raw `Int32` and reconstructs a typed `Kernel.Descriptor` inside the closure body. This is forbidden pattern #2 in the feedback memory:

> 2. **Closure capture**: `let raw = descriptor._rawValue` to dodge ~Copyable capture in `Mutex.withLock` — defeats ownership.

The current code dodges `~Copyable` capture by capturing the raw Int32 instead of the typed descriptor. The dodge is necessary because the closure is `@Sendable () -> Void` and `Kernel.Descriptor` is `~Copyable` — Swift forbids capturing `~Copyable` types in `@Sendable` closures (per `feedback_noncopyable_sendable_capture`).

**Footgun 2 — silent ownership invariant violation**:

The token's RAII contract is "the descriptor is closed when the token drops". Today this works because the captured Int32 + the manually-reconstructed-and-closed Descriptor inside the closure body do the right thing operationally. But the type system has no way to enforce this: nothing prevents the closure body from being modified to forget to close, or accidentally double-close (if `release()` is called and the closure also runs in `deinit` — guarded by setting `_release = nil`, but the guard is closure-state, not ownership-state).

**Footgun 3 — blocks raw-Lock downgrade**:

Per the audit-doc Item 1.5 entry: the raw `Kernel.Lock.lock(fd:Int32)` form at iso-9945 needs to be downgraded to `internal` to complete Wave 4c-deinit-helper's typed-everywhere refactor. Today's code at `Memory.Lock.Token+Acquire.swift:50` requires the raw form to be `public` (or `@_spi(Syscall) public`); downgrade would break Memory.Lock.Token. The dependency chain is:

```
swift-memory L3   →   raw Kernel.Lock.lock(fd:)   →   blocks raw Lock downgrade
                  →   raw Kernel.Descriptor.Duplicate.duplicate(fd:)   →   blocks raw Duplicate downgrade
```

Both raw forms must remain public to support the witness-closure pattern. Eliminating the raw extractions in Memory.Lock.Token+Acquire.swift unblocks both downgrades.

## (c) ~Copyable / consuming / borrowing alternatives

Three Swift-native ownership tools apply:

**Tool 1 — `var Optional<~Copyable> + .take()!` for one-shot consumption** (per `feedback_no_raw_descriptor_reconstruction` line 22):

```swift
var dupedOptional: Kernel.Descriptor? = consume duped
// later:
let fd = dupedOptional.take()!  // exactly-once consume; subsequent take()! traps
try? Kernel.Close.close(consume fd)
```

This pattern handles the "store a ~Copyable for later consume" need without raw extraction. Already established as the canonical pattern in the memory feedback.

**Tool 2 — `~Copyable` struct with explicit fields** (avoid closure entirely):

```swift
public struct Token: ~Copyable, Sendable {
    @usableFromInline var _descriptor: Kernel.Descriptor?
    @usableFromInline let _range: Kernel.Lock.Range
    // ... explicit release() + deinit bodies operate on _descriptor.take()
}
```

The token's behavior (lock + close on drop) is encoded in the type's release/deinit bodies, not in a captured closure. All ownership tracked at the field level.

**Tool 3 — Typed iso-9945 forms as prerequisite**:

Both Option A and Option B require iso-9945 to expose typed forms:

```swift
// At iso-9945 Kernel.Descriptor.Duplicate (or post-Final-Atomic at the canonical L2 location)
public static func duplicate(_ source: borrowing Kernel.Descriptor) throws(Error) -> Kernel.Descriptor

// At iso-9945 Kernel.Lock
public static func lock(_ descriptor: borrowing Kernel.Descriptor, range: Range, kind: Kind) throws(Error)
public static func unlock(_ descriptor: borrowing Kernel.Descriptor, range: Range) throws(Error)
```

These typed forms may already exist (post-Wave-4c-Socket Prerequisite II established the typed-everywhere convention). Verify at execution-cycle pre-flight.

## (d) Cross-platform constraints

**POSIX-only today**: `Memory.Lock.Token+Acquire.swift` is wrapped in `#if !os(Windows)`. Windows lock acquisition is deferred per `Memory.Map+Init.swift:211` (`let lockToken: Memory.Lock.Token? = nil  // Windows lock acquisition deferred`).

**Post-Final-Atomic flip considerations**: After the Wave 3.5-Final-Atomic flip (`Kernel = POSIX.Kernel` on POSIX), `Kernel.Descriptor` resolves through `POSIX.Kernel.Descriptor → ISO_9945.Kernel.Descriptor` typealias chain. Both Option A and Option B work identically post-flip — the chain is transparent to both designs.

**Windows path compatibility**: When Windows lock acquisition is wired, the L3 Acquire would need a Windows-platform implementation (`LockFileEx` + `CloseHandle`). Option B's explicit-field design transfers cleanly: the `_descriptor` field is a `Kernel.Descriptor` (cross-platform via three-tier chain); the `_range` field is cross-platform; `release()` body would dispatch to platform-appropriate `Kernel.Lock.unlock` (cross-platform L3-unifier API).

**Sendability**: `Memory.Lock.Token` is `Sendable`. The current witness-closure design uses `@Sendable () -> Void`. Option B's explicit-field design needs `Kernel.Descriptor` to be Sendable for the Token to remain Sendable — verify at execution time (likely true since iso-9945's Descriptor is `@unchecked Sendable` by virtue of being a wrapper around an OS resource handle, not heap-shared mutable state).

## (e) Recommended redesign direction(s) with trade-offs

### Option A — Witness-preserving (typed-Descriptor in closure capture)

**Shape**:

```swift
public static func acquire(
    descriptor: borrowing Kernel.Descriptor,
    range: Kernel.Lock.Range,
    kind: Memory.Lock.Kind
) throws(Kernel.Lock.Error) -> Memory.Lock.Token {
    var dupedOpt: Kernel.Descriptor? = try Kernel.Descriptor.Duplicate.duplicate(descriptor)
    let duped = dupedOpt.take()!  // consume now for the lock call

    do {
        try Kernel.Lock.lock(duped, range: range, kind: kernelKind)
    } catch {
        try? Kernel.Close.close(consume duped)
        throw error
    }

    // Re-store for closure capture
    var captured: Kernel.Descriptor? = consume duped
    return Memory.Lock.Token(release: {
        guard let fd = captured.take() else { return }
        try? Kernel.Lock.unlock(fd, range: range)
        try? Kernel.Close.close(consume fd)
    })
}
```

**Constraints**: `var captured: Kernel.Descriptor?` captured by an `@escaping @Sendable () -> Void` closure. **Swift forbids `~Copyable` capture in `@Sendable` closures** (per `feedback_noncopyable_sendable_capture`). The capture would fail to compile.

**Mitigation paths**:
- (i) Drop the `@Sendable` requirement on the closure → breaks `Memory.Lock.Token: Sendable` (the Token would no longer be Sendable, breaking Memory.Map's Sendable conformance)
- (ii) Use `nonisolated(unsafe)` or similar override on the captured optional → works around the constraint but is a mechanism leak (per `feedback_language_features_over_custom_types`)
- (iii) Wrap the captured optional in a class to make it heap-shared → adds allocation + indirection for no benefit

**Pros**:
- Minimal API change (Token interface unchanged)
- Witness-closure pattern preserved (extensible to other release strategies)

**Cons**:
- **Hits a Swift language constraint** (`~Copyable` capture in `@Sendable` closure forbidden)
- Mitigation paths are all mechanism leaks
- Doesn't actually use language ownership semantics — encodes ownership in closure capture instead of type fields
- Witness-closure pattern is itself the "custom mechanism over language features" defect per `feedback_language_features_over_custom_types`

### Option B — Explicit-storage redesign (recommended)

**Shape (L1 swift-memory-primitives change)**:

```swift
extension Memory.Lock {
    public struct Token: ~Copyable, Sendable {
        @usableFromInline var _descriptor: Kernel.Descriptor?
        @usableFromInline let _range: Kernel.Lock.Range

        @inlinable
        public init(descriptor: consuming Kernel.Descriptor, range: Kernel.Lock.Range) {
            self._descriptor = consume descriptor
            self._range = range
        }

        /// Releases the lock + closes the descriptor immediately. Idempotent.
        @inlinable
        public mutating func release() {
            guard let fd = _descriptor.take() else { return }
            try? Kernel.Lock.unlock(fd, range: _range)
            try? Kernel.Close.close(consume fd)
        }

        deinit {
            if _descriptor != nil {
                release()  // ~Copyable mutating deinit pattern
            }
        }
    }
}
```

**Shape (L3 swift-memory acquire site)**:

```swift
public static func acquire(
    descriptor: borrowing Kernel.Descriptor,
    range: Kernel.Lock.Range,
    kind: Memory.Lock.Kind
) throws(Kernel.Lock.Error) -> Memory.Lock.Token {
    let duped: Kernel.Descriptor
    do throws(Kernel.Descriptor.Duplicate.Error) {
        duped = try Kernel.Descriptor.Duplicate.duplicate(descriptor)
    } catch {
        throw .unavailable
    }

    do throws(Kernel.Lock.Error) {
        try Kernel.Lock.lock(duped, range: range, kind: kernelKind)
    } catch {
        try? Kernel.Close.close(consume duped)
        throw error
    }

    return Memory.Lock.Token(descriptor: consume duped, range: range)
}
```

**Pros**:
- Eliminates closure entirely → no `@Sendable` capture constraint
- Eliminates raw extraction + reconstruction → satisfies `feedback_no_raw_descriptor_reconstruction`
- All ownership encoded in field types via Swift language semantics → satisfies `feedback_language_features_over_custom_types`
- Token is trivially Sendable (Descriptor is `@unchecked Sendable`; Range is Sendable)
- No allocation, no closure indirection — fields stored inline
- Unblocks raw-Lock downgrade (per audit-doc Item 1.5)
- Mutating-deinit pattern matches `~Copyable` ownership-transfer-patterns precedent (multiple existing types in the ecosystem use this pattern)

**Cons**:
- API change at L1: `init(release: @escaping @Sendable () -> Void)` removed; `init(descriptor: consuming Kernel.Descriptor, range: Kernel.Lock.Range)` added
- Token is no longer extensible to non-Lock release strategies (the witness-closure was theoretically extensible to other resources; in practice only Lock acquisition uses it)
- Requires iso-9945 typed-Lock + typed-Duplicate forms to exist publicly (probable, given Wave 4c-Socket Prerequisite II / Wave 4c-deinit-helper precedents — verify at execution)

**Workspace impact**: Single L1 declaration change + single L3 Acquire-site change + zero call-site changes (the only consumer at `Memory.Map+Init.swift:80-99` calls `Memory.Lock.Token.acquire(...)` with the same signature).

### Option C — Hybrid (witness-closure with internal mutable state class)

Wrap the descriptor in an internal heap-allocated class for mutable shared state; closure captures the class instance. Avoids the `@Sendable`-of-`~Copyable` constraint by hiding the descriptor inside a class.

**Pros**:
- Preserves witness-closure shape
- Token remains Sendable

**Cons**:
- Adds heap allocation per Token (regression from current zero-alloc design)
- Adds indirection for every release call
- Doubles down on the witness-closure pattern (which is itself the anti-pattern per `feedback_language_features_over_custom_types`)
- More complex than Option B for no architectural benefit

**Not recommended.**

## Recommendation

**Option B (explicit-storage redesign)** is the principled fix. Reasoning:

1. **Eliminates the raw-extraction anti-pattern** (`feedback_no_raw_descriptor_reconstruction`) at the source — no `_rawValue` / `_rawValue:` on either side of the boundary.
2. **Uses language ownership semantics** (`feedback_language_features_over_custom_types`) — `~Copyable` field, `consuming` init, mutating deinit, `Optional + take()`. No custom mechanisms.
3. **Avoids the `@Sendable` × `~Copyable` Swift constraint** entirely (no closure to capture into).
4. **Unblocks raw-Lock downgrade** per Item 1.5 audit-doc target.
5. **Single-call-site impact** — only `Memory.Map+Init.swift:80-99` uses `Memory.Lock.Token.acquire`; signature unchanged from L3 caller's perspective.

**Pre-execution verifications (next cycle)**:

- (V1) Verify `Kernel.Descriptor.Duplicate.duplicate(_:borrowing Descriptor)` typed form exists at iso-9945 / canonical L2 location (or add it as a prerequisite).
- (V2) Verify `Kernel.Lock.lock(_:borrowing Descriptor, range:, kind:)` + `Kernel.Lock.unlock(_:borrowing Descriptor, range:)` typed forms exist (or add as prerequisite).
- (V3) Verify `Kernel.Descriptor` is Sendable (`@unchecked Sendable` likely sufficient for Token's Sendable conformance).
- (V4) Run `swift build` + `swift test` at swift-memory + downstream consumers (swift-io, swift-executors) to confirm zero unintended cascade.

**Estimated dispatch envelope**: 3 commits — (1) iso-9945 typed prerequisites if missing, (2) L1 swift-memory-primitives Token redesign, (3) L3 swift-memory Acquire-site rewrite + raw-Lock downgrade verification at iso-9945.

**Out of scope for this dispatch**: extending Memory.Lock.Token to Windows. Current `#if !os(Windows)` guard remains; Windows wiring is a separate cycle.

---

## Addendum (2026-05-02) — Phase 2 structural conflict + Path δ resolution

### Phase 2 structural conflict — research doc oversight

The original Option B shape (lines 211-242 above) required field types `Kernel.Descriptor?` and `Kernel.Lock.Range` at L1 swift-memory-primitives. **Empirical check at dispatch time revealed L1 swift-memory-primitives cannot import these types**: its Package.swift deps are exclusively other L1 primitives packages (ordinal/cardinal/carrier/affine/tagged/property/index/bit/vector/error/system) — no L2 (`ISO_9945_Kernel`) or L3 (`Kernel`) deps allowed.

Original research doc Option B was structurally invalid at L1. The oversight: the research did not verify L1's import constraints before drafting field-typed shape. **Lesson codified**: future research-then-dispatch cycles for L1 redesigns must check Package.swift dep constraints alongside the type-system analysis.

### Phase A empirical experiment (CONFIRMED)

Path δ candidate: drop Token's `Sendable` conformance to enable `var Optional<~Copyable>` capture in non-`@Sendable` closure. Tested at `swift-institute/Experiments/memory-lock-token-noncopyable-closure-capture/` (CONFIRMED 2026-05-02; Apple Swift 6.3.1).

**Hypothesis tested**: "non-@Sendable closure capture of `var Optional<~Copyable>` compiles and runs correctly, releasing the captured value via `.take()` exactly once."

**Result**: CONFIRMED in both debug (2.62s) and release builds. 3 test cases verified:
- Test 1: explicit `release()` — closure invokes `.take()`, Resource consumes, deinit fires; subsequent Token deinit no-ops (idempotent)
- Test 2: deinit-only release — Token deinit fires closure path; consumption + Resource deinit chain works
- Test 3: idempotent double-release — second `release()` call no-ops because `_release` was set to nil

**Observation**: Swift's `~Copyable` × `@Sendable` capture restriction does NOT apply when the closure type is non-`@Sendable`. The trade-off (Token loses Sendable conformance) is bounded — Token is held inside `Memory.Map` which is `@unchecked Sendable` for distinct architectural reasons (raw mapping bytes), so the parent's existing escape hatch absorbs the Sendable invariant.

### Path β scoping skipped

After Phase A's clean CONFIRMATION, the principal directive ("report Phase A result before starting Phase B so I can dispose if a clean Path δ confirmation collapses the disposition tree") collapsed the tree to Path δ. Path β (move Memory.Lock.Token + Memory.Map to L3 swift-memory) was **not scoped**; its larger architectural surgery (Memory.Map L1→L3 relocation + consumer cascade) is unnecessary given Path δ's Sendable trade-off is acceptable per the Memory.Map @unchecked Sendable absorption analysis.

### Revised recommendation: Path δ

Replace Option B's L1 explicit-field redesign (structurally invalid) with Path δ's L1 closure-shape-preserving redesign:

**L1 swift-memory-primitives Token shape** (Phase 2):
- Drop `Sendable` conformance: `public struct Token: ~Copyable { ... }` (was `~Copyable, Sendable`)
- Closure storage: `@usableFromInline var _release: (() -> Void)?` (was `@Sendable () -> Void`)
- Initializer: `public init(release: @escaping () -> Void)` (no `@Sendable`)
- `release()` mutating method + `deinit` unchanged

**L3 swift-memory Acquire shape** (Phase 3):
```swift
public static func acquire(
    descriptor: borrowing Kernel.Descriptor,
    range: Kernel.Lock.Range,
    kind: Memory.Lock.Kind
) throws(Kernel.Lock.Error) -> Memory.Lock.Token {
    let duped: Kernel.Descriptor
    do throws(Kernel.Descriptor.Duplicate.Error) {
        duped = try Kernel.Descriptor.Duplicate.duplicate(descriptor)
    } catch {
        throw .unavailable
    }

    do throws(Kernel.Lock.Error) {
        try Kernel.Lock.lock(duped, range: range, kind: kernelKind)
    } catch {
        try? Kernel.Close.close(consume duped)
        throw error
    }

    var ownedFd: Kernel.Descriptor? = consume duped
    return Memory.Lock.Token(release: {
        guard let fd = ownedFd.take() else { return }
        try? Kernel.Lock.unlock(fd, range: range)
        try? Kernel.Close.close(consume fd)
    })
}
```

### Sendable trade-off — architectural analysis

Three load-bearing properties preserved despite the Sendable change:

1. **Witness-closure abstraction integrity**: The L1 Token's witness-closure shape stays at L1. L3 fills in policy-specific semantics. Same architectural pattern, different closure-type annotation. Token's role as a cross-platform lock-release abstraction is unchanged.

2. **L1 layering preserved**: Token does NOT import `Kernel` or `ISO_9945.Kernel.Lock.Range`. The closure body lives at L3 swift-memory where typed Descriptor capture is valid; L1 sees only the abstract `() -> Void` shape.

3. **Memory.Map @unchecked Sendable absorption**: Memory.Map is `@unsafe @unchecked Sendable` because its raw mapping bytes carry data races the caller must synchronize (per L1 doc-comment). Token's loss of `Sendable` is absorbed by Memory.Map's existing escape hatch — the parent's `@unchecked Sendable` makes Memory.Map (with its non-Sendable Token field) Sendable to consumers. Cross-thread transfer of a Token-bearing Memory.Map remains supported. Net effect: Token's Sendable was effectively delegated to Memory.Map's escape hatch even before Item 1.5; making the delegation explicit is not a safety regression.

### Item 1.5 envelope state — dispatched (2026-05-02)

- Phase 1 (typed-form prerequisite verification): NO-OP (V1/V2/V3 all pre-existed at iso-9945)
- Phase 2 (L1 Token redesign — Path δ): commit `39cb45d` at swift-memory-primitives
- Phase 3 (L3 Acquire rewrite — typed Descriptor capture): commit `371a6e5` at swift-memory
- Phase 4 (cascade verification): swift-memory ✅ + swift-io ✅ (101.23s) + swift-executors ✅ (98.98s); zero annotation adjustment needed at Memory.Map
- Phase 5 (raw-form downgrade at iso-9945): commit `9f3abb4` (`@_spi(Syscall) public` → `package` for Lock.lock + Lock.unlock + Duplicate.duplicate raw fd-int forms)
- Phase 6 (audit doc + research doc update): this addendum

### Pre-existing breakage NOT introduced by Item 1.5

- `swift-iso-9945/Tests/Support/Lock Helper/ISO 9945.Lock.Helper.swift:55`: `'open' is inaccessible due to '@_spi' protection level` — from Wave 3.5-Corrective-2's `File.Open.open` SPI access; the Lock Helper test wasn't updated to add `@_spi(Syscall) import ISO_9945_Kernel_File`. Out of Item 1.5 scope per [SUPER-009a].

### Lessons codified

- **Lesson 1 (research-then-dispatch)**: Research deliverables MUST verify Package.swift import constraints alongside type-system shape analysis. Field-typed redesigns at L1 require explicit L1-deps inventory.
- **Lesson 2 (Path δ pattern)**: `~Copyable` types CAN be captured in non-`@Sendable` closures. Dropping `Sendable` from a witness-holder type unblocks ownership-transferring closures while preserving the closure-as-witness abstraction.
- **Lesson 3 (Sendable absorption)**: When a parent type is `@unchecked Sendable` for distinct safety reasons, child types held inside it can drop `Sendable` without changing observable safety (the parent's escape hatch absorbs the invariant).
- **Lesson 4 (raw-form downgrade access level)**: Use `package` (SE-0386) — not `internal` — when downgrading raw forms to preserve cross-target in-package test access while denying cross-package consumption.
