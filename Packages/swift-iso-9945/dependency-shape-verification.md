# Dependency Shape Verification

Post-modularization analysis of cross-domain dependencies in `swift-iso-9945` (14 targets: Core + 12 domain variants + umbrella).

## Terminal -> File Dependency

### What the dependency provides

Terminal depends on `ISO 9945 Kernel File` (declared in Package.swift line 217, re-exported in Terminal's `exports.swift` line 2). The dependency exists because:

1. `ISO 9945.Kernel.IO.Read+Terminal.swift` (line 32) extends `ISO_9945.Kernel.IO.Read` with a `read(_:Terminal.Stream, into:)` overload.
2. That extension calls `Error.current()` (lines 51, 57, 63) -- a `package`-scoped factory method defined in the File target at `ISO 9945.Kernel.IO.Read.swift` line 149.

The type `Kernel.IO.Read` itself and `Kernel.IO.Read.Error` are both declared in `Kernel File Primitives` (L1), not in the File target. The File target provides:
- The `read(_:Kernel.Descriptor, into:)` syscall implementation (not called by Terminal)
- The `Error.current()` errno-to-error conversion factory (called by Terminal)
- The `Kernel.Syscall.require` helper (imported from `Kernel_Syscall_Primitives`, also independently importable)

### Is it essential?

**No.** Terminal does not call any File-target functions. It calls `Kernel.Syscall.require` (from L1 `Kernel_Syscall_Primitives`, already imported directly) and `Error.current()`. The sole coupling is the `Error.current()` factory.

### Alternatives

**Option A: Duplicate `Error.current()` in Terminal.** Terminal could have its own `Error.current()` as a `private` or `internal` extension on `Kernel.IO.Read.Error`. This is ~18 lines of errno-to-error mapping. Clean separation, but code duplication. Since `IO.Write.Error.current()` (File target, line 228) is `internal` and follows the same pattern, duplication is already the norm for Write vs. Read.

**Option B: Move `Error.current()` to Core or a shared internal target.** Would require Core to depend on `Kernel File Primitives` (for `Kernel.IO.Read.Error`), which it currently does not. This widens Core's dependency surface and is worse.

**Option C: Move `Error.current()` to L1 (`Kernel File Primitives`).** Would push platform-specific errno mapping into the primitives layer. Violates the L1/L2 split -- L1 declares the error types, L2 provides the POSIX errno mapping.

**Recommendation**: Option A. Duplicate the factory as `private` in the Terminal target file. The Terminal target already imports `Kernel_File_Primitives` (for the error type) and the platform modules (for `errno`). The duplication is small, matches the existing `IO.Write` pattern, and eliminates the cross-domain dependency entirely.

## Lock -> System Dependency

### What the dependency provides

Lock depends on `ISO 9945 Kernel System` (Package.swift line 148, re-exported in Lock's `exports.swift` line 2). The dependency exists because:

1. `ISO 9945.Kernel.Lock.Token.swift` line 166: `deadline: Clock.Continuous.Instant` parameter (type from `Clock_Primitives`, L1)
2. Lines 173-174: `let now = Clock.Continuous.now` -- this calls the **static computed property** on `Clock.Continuous` defined in `ISO 9945.Clock.Continuous.swift` line 29, which delegates to `Kernel.Clock.Continuous.now()` defined in `ISO 9945.Kernel.Clock.swift` line 33.
3. Line 184: Second `Clock.Continuous.now >= deadline` check.
4. Line 199: Third `Clock.Continuous.now` call for remaining-time calculation.

The System target provides the POSIX `clock_gettime` implementation that backs `Clock.Continuous.now`. Without it, `Clock.Continuous.Instant` is just a type with no way to obtain the current time.

### Is it essential?

**Yes.** The `.deadline(Clock.Continuous.Instant)` acquisition strategy in `Kernel.Lock.Acquire` (defined in L1 `Kernel File Primitives`) requires reading the current clock to implement timed polling. This is not incidental -- it is the fundamental mechanism for deadline-based lock acquisition:

- Line 174: Check if deadline has already passed before attempting.
- Line 184: Post-acquisition deadline re-check (correctness invariant: "success means lock was acquired before deadline").
- Line 199: Calculate remaining sleep time to avoid overshooting.

The polling loop with exponential backoff (1ms to 100ms cap) is the only way to implement timed `fcntl(F_SETLK)` -- POSIX `fcntl` has no native timeout parameter for file locking.

### Alternatives

There is no clean way to remove this. The clock reading could theoretically be injected as a closure parameter, but `Kernel.Lock.Acquire.deadline` already stores a `Clock.Continuous.Instant`, so the System target dependency is structurally required by the L1 type definition. Any target implementing the `.deadline` case needs a clock implementation.

**Recommendation**: Keep as-is. This is an essential dependency.

## IO.Read `package` Visibility

### Current state

`ISO 9945.Kernel.IO.Read.Error.current()` was changed from `internal` to `package` (File target, line 149) as an expedient fix during modularization. This allows the Terminal target (same package) to call it. The `package` visibility was chosen to unblock the build quickly; this document recommends reverting it.

### Analysis of both approaches

**Approach 1: `package` visibility (current)**

Pros:
- Single implementation of errno-to-error mapping for `IO.Read.Error`.
- No code duplication.
- Semantically correct: all targets in `swift-iso-9945` share the POSIX errno mapping logic.

Cons:
- Exposes `Error.current()` to all 14 targets in the package, not just Terminal.
- Creates a structural dependency: Terminal depends on File. This is the cross-domain coupling under analysis.
- Inconsistent with `IO.Write.Error.current()` which remains `internal` (line 228 of `ISO 9945.Kernel.IO.Write.swift`).

**Approach 2: Move the file to Terminal, duplicate for File**

This was the alternative considered. Terminal would own `IO.Read+Terminal.swift` (already does) plus a private `Error.current()`. File would keep its own `internal` copy.

Pros:
- Terminal becomes self-contained; File dependency eliminated.
- `Error.current()` returns to `internal` in File (consistent with Write).
- Each domain target owns exactly the code it needs.

Cons:
- ~18 lines duplicated. But the mapping is mechanical (errno -> error case) and unlikely to diverge.

### Recommendation

**Approach 2 is better.** The `package` visibility change was the expedient fix during modularization, but the principled fix is duplication. Reasons:

1. `IO.Write.Error.current()` is `internal` -- there is no reason `IO.Read.Error.current()` should have wider visibility.
2. The Terminal -> File dependency exists solely because of this one factory method. Removing it eliminates the dependency.
3. `package` visibility leaks the factory to 12 other targets that have no use for it.
4. The duplication is small, mechanical, and stable (errno codes do not change).

**Action:** Revert `Error.current()` to `internal` in File (matching `IO.Write.Error.current()`). Add a `private` copy in `ISO 9945.Kernel.IO.Read+Terminal.swift`. This eliminates the Terminal → File dependency entirely. The current `package` visibility is an expedient from the modularization phase, not the intended final state.

## Dependency Graph Summary

### Current shape (with cross-domain edges)

```
                    ISO 9945 Kernel (umbrella)
                   /  |  |  |  |  |  |  |  |  \  \  \
                  v   v  v  v  v  v  v  v  v   v  v   v
               File Dir Lock Sock Mem Sig Proc Thr Term Env Sys
                 |        |                          |
                 |        +----> System               |
                 |                                    |
                 +<-----------------------------------+
                      Terminal depends on File
```

Cross-domain dependencies:
1. **Terminal -> File**: For `Error.current()`. **Removable** (duplicate the factory).
2. **Lock -> System**: For `Clock.Continuous.now`. **Essential** (deadline-based locking requires clock reads).

### Recommended shape (after fix)

```
                    ISO 9945 Kernel (umbrella)
                   /  |  |  |  |  |  |  |  |  \  \  \
                  v   v  v  v  v  v  v  v  v   v  v   v
               File Dir Lock Sock Mem Sig Proc Thr Term Env Sys
                          |
                          +----> System
```

One cross-domain edge remains (Lock -> System), which is essential and clean. All other domain targets depend only on Core and L1 primitives.

### Verdict

The dependency shape is **nearly clean**. The single actionable item is removing Terminal -> File by duplicating `Error.current()`. The Lock -> System dependency is a legitimate architectural requirement. After the Terminal fix, each domain target forms a clean spoke from Core with at most one justified cross-domain edge.
