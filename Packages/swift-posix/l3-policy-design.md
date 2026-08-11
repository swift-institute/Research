# L3 Policy Design: swift-posix

Date: 2026-04-10

## Design Principle

The POSIX layer (L3) exists for two purposes:

1. **Re-export** — where the raw L2 syscall is already what consumers need, L3 re-exports it under the `POSIX` namespace with no modification.
2. **Layer policy** — where the raw syscall has sharp edges (EINTR, partial writes, platform divergence), L3 wraps it with opinionated behavior that most applications want.

L3 is the creative layer. L2 (`ISO_9945`) mirrors the specification faithfully — it does not make choices. L3 makes the choices: retry on EINTR, loop on partial writes, compose multi-step operations into single calls. The two roles are complementary: re-export is the default; policy is added where the raw interface would be a footgun.

This principle governs all target design in swift-posix. A target that only re-exports is not empty — it anchors the `POSIX.Kernel.*` namespace and reserves the slot for future policy. A target that adds policy must delegate to L2, never re-implement the syscall.

## Current State

swift-posix (L3) has 15 source targets organized under `Sources/`:

| Target | Content |
|--------|---------|
| `POSIX Core` | `public enum POSIX {}` namespace declaration, `Kernel.Error.Code+message`, re-exports `Kernel_Primitives_Core` + `Kernel_Error_Primitives` |
| `POSIX Kernel File` | **Policy code**: EINTR-retry wrappers for flush + write. Re-exports `ISO_9945_Kernel_File` |
| `POSIX Kernel Glob` | **Implementation code**: Full glob matching engine (`Kernel.Glob.match()`), extends L1's `Kernel_Glob_Primitives` types directly |
| `POSIX Kernel Directory` | Pure re-export of `ISO_9945_Kernel_Directory` |
| `POSIX Kernel Environment` | Pure re-export of `ISO_9945_Kernel_Environment` |
| `POSIX Kernel Lock` | Pure re-export of `ISO_9945_Kernel_Lock` |
| `POSIX Kernel Memory` | Pure re-export of `ISO_9945_Kernel_Memory` |
| `POSIX Kernel Process` | Pure re-export of `ISO_9945_Kernel_Process` |
| `POSIX Kernel Signal` | Pure re-export of `ISO_9945_Kernel_Signal` |
| `POSIX Kernel Socket` | Pure re-export of `ISO_9945_Kernel_Socket` |
| `POSIX Kernel System` | Pure re-export of `ISO_9945_Kernel_System` |
| `POSIX Kernel Terminal` | Pure re-export of `ISO_9945_Kernel_Terminal` |
| `POSIX Kernel Thread` | Pure re-export of `ISO_9945_Kernel_Thread` |
| `POSIX Kernel` | Umbrella: re-exports all 12 `POSIX_Kernel_*` targets |
| `POSIX Loader` | Pure re-export of `ISO_9945_Loader` |

**Key observation**: Of 13 domain targets, only 2 add policy code (Kernel File, Kernel Glob). The other 11 are pure re-export shims with no L3-specific logic.

## Flush Duplication Analysis

### L2: `ISO_9945.Kernel.File.Flush` (swift-iso-9945)

File: `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.File.Flush.swift`

- Raw POSIX syscall wrappers: `flush(fd)`, `data(fd)` (Linux), `full(fd)` (Darwin), `barrier(fd)` (Darwin)
- Calls Darwin/Glibc/Musl `fsync()`, `fdatasync()`, `fcntl(F_FULLFSYNC)`, `fcntl(F_BARRIERFSYNC)` directly
- Does NOT retry on EINTR - documents this explicitly
- Uses `@_spi(Syscall)` imports from L1 kernel primitives
- Error mapping via `Error.current()` using errno

### L3: `POSIX.Kernel.File.Flush` (swift-posix)

File: `/Users/coen/Developer/swift-foundations/swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Flush.swift`

- `@inlinable` wrappers that delegate to L2's functions
- Adds a `while true` EINTR-retry loop around each L2 call
- Catches `error.isInterrupted`, continues on match
- Uses the same L1 error types (`Kernel.File.Flush.Error`) - no new error types
- Methods: `flush(fd)`, `data(fd)` (Linux), `full(fd)` (Darwin), `barrier(fd)` (Darwin) - mirror of L2 surface

### Verdict: Not duplication - genuine policy layering

This is the correct L2/L3 split. L2 exposes the raw syscall that can fail with EINTR (per POSIX specification behavior). L3 adds the opinionated policy that most applications want: automatic EINTR retry. The L3 functions delegate to L2; they do not re-implement the syscall. The `while true` + `catch where error.isInterrupted` pattern is the L3 value-add.

The L2 documentation explicitly states: "For automatic EINTR retry, use the policy-aware wrapper in `POSIX_Kernel`." The layering is intentional and documented.

## Pattern Across Targets

### Targets with L3 policy logic (2 of 13)

**POSIX Kernel File** - Two policy files:
1. `POSIX.Kernel.File.Flush.swift` - EINTR retry for flush operations
2. `POSIX.Kernel.IO.Write.swift` - EINTR retry for write/pwrite, plus `writeAll()` (a composed operation that handles both partial writes and EINTR - pure L3 value-add with no L2 equivalent)

Both follow the same pattern: `while true { do { try L2.operation() } catch where error.isInterrupted { continue } }`.

**POSIX Kernel Glob** - Full implementation, not a policy wrapper:
- `POSIX.Kernel.Glob.Match.swift` contains a complete glob matching engine (400+ lines)
- Extends `Kernel.Glob` (L1 type) with `.match()` implementation
- Uses `opendir`/`readdir`/`stat` directly from Darwin/Glibc/Musl
- NOT a wrapper around L2 - it extends L1 types directly at L3

This is a different pattern from flush/write. Glob's Match implementation calls POSIX C functions directly rather than going through L2. It lives under the `Kernel.Glob` namespace (L1), not `POSIX.Kernel.Glob`.

**POSIX Core** - One extension:
- `POSIX.Kernel.Error.Code+message` adds a `posixMessage` computed property that calls `strerror()`. This is a platform-specific convenience, not an EINTR policy.

### Targets that are pure re-exports (10 of 13)

Directory, Environment, Lock, Memory, Process, Signal, Socket, System, Terminal, Thread - each has only an `exports.swift` that re-exports `POSIX_Core` + the corresponding `ISO_9945_Kernel_*` module.

### Summary

| Pattern | Targets | Count |
|---------|---------|-------|
| EINTR retry policy wrapper | Kernel File (flush, write) | 1 |
| Full implementation extending L1 | Kernel Glob | 1 |
| Platform convenience extension | Core (strerror) | 1 |
| Pure re-export shim | Directory, Environment, Lock, Memory, Process, Signal, Socket, System, Terminal, Thread | 10 |

## Method-form writeAll cascade (2026-04-22)

A third L3 policy file landed in the `POSIX Kernel File` target — `POSIX.Kernel.File.Handle.writeAll.swift` — per Doc 1 § Principal Decisions (binding at `swift-institute/Research/file-handle-writeall-l2-l3-layering.md` commit `d20d91b`). This closes audit findings **P2.2 #1** (L2 free-function `ISO_9945.Kernel.IO.Write.writeAll` hosted partial-IO policy, resolved by deletion) and **P2.2 #11** (its L2 `Kernel.File.Handle.writeAll` extension cascade, resolved by the method-level split).

The new file opens `extension Kernel.File.Handle` (L1 type from `Kernel_File_Primitives`) with two `writeAll(from:)` overloads — `UnsafeRawBufferPointer` and `Span<UInt8>`. The partial-IO while-loop is L3 policy per [PLAT-ARCH-008e]; each iteration delegates to the raw L2 syscall wrapper `ISO_9945.Kernel.IO.Write.write`, so signal interruption propagates as `.right(.occurred)` of `Either<Kernel.File.Handle.Error, Kernel.Interrupt>` per **Decision #2**: *"method surfaces `Interrupt` for caller; free-function retries internally — pick your abstraction."* This is the designed asymmetry with the free-function `POSIX.Kernel.IO.Write.writeAll` in the same target — which retries EINTR internally via the inner `POSIX.Kernel.IO.Write.write` call. The method form's EINTR surfacing keeps intra-family consistency with the preserved `Kernel.File.Handle.write(from:)` and `.pwrite(from:at:)` L2 methods in iso-9945, which also surface EINTR.

Split-legibility aids per Decision #3: (i) the iso-9945 sibling Research note at `swift-iso/swift-iso-9945/Research/file-handle-writeall-l2-l3-split-rationale.md` records the L2 deletion rationale and cross-links here; (ii) a DocC `See Also` cross-reference in `ISO 9945.Kernel.File.Handle.write.swift` points to this module's `writeAll(from:)`; (iii) this paragraph provides the POSIX-side cascade rationale.

## POSIX Enum vs Typealias

### Current declaration

```swift
// Sources/POSIX Core/POSIX.Kernel.swift
public enum POSIX {
    public enum Kernel {
        public enum File {}
    }
}
```

`POSIX` is already a separate `public enum`, not a typealias to `ISO_9945`.

### Recommendation: Keep `public enum POSIX {}`

The evidence strongly supports keeping `POSIX` as its own enum namespace:

1. **L3 adds policy, not just re-exports.** The EINTR retry wrappers (`POSIX.Kernel.File.Flush`, `POSIX.Kernel.IO.Write`) declare new enums and static methods under the `POSIX` namespace that have no L2 counterpart. A typealias cannot host new nested types.

2. **L3 adds composed operations.** `POSIX.Kernel.IO.Write.writeAll()` is a pure L3 invention - it handles both partial writes and EINTR in a loop. This does not exist at L2. You need an independent namespace to own these.

3. **Glob extends L1, not L2.** The glob implementation adds methods to `Kernel.Glob` (L1) rather than wrapping `ISO_9945.Kernel.Glob`. This means L3's glob target bypasses L2 entirely and provides its own implementation. A typealias `POSIX = ISO_9945` would not help here since the implementation lives on L1 types.

4. **Type-definition conflict.** If `POSIX` were a typealias to `ISO_9945`, then `POSIX.Kernel.File` would resolve to `ISO_9945.Kernel.File` — which already has a `Flush` member. You cannot add `public enum Flush {}` to a type that already has a `Flush` member; this is a type-definition conflict, not mere overload ambiguity. We hit this exact compiler error during implementation. The typealias approach is structurally impossible when L3 needs to declare types that mirror L2's namespace structure.

5. **Forward compatibility.** As more domains gain EINTR wrappers (read, accept, connect, etc.), L3 will accumulate more `POSIX.Kernel.*` types. An independent namespace supports this growth naturally.

A `public typealias POSIX = ISO_9945` would only work if L3 never added its own types or methods - only re-exported. Since L3 already adds types (`POSIX.Kernel.File.Flush`, `POSIX.Kernel.IO`, `POSIX.Kernel.IO.Write`), typealias is not viable.

## Open Questions

1. **Glob's layering anomaly — needs split investigation.** `POSIX.Kernel.Glob.Match.swift` extends `Kernel.Glob` (L1 type) directly with an implementation that calls C library functions. This bypasses L2 entirely. But this is not a single-layer question — the implementation contains two distinct concerns:

   - **Directory traversal** (`opendir`, `readdir`, `stat`): These are ISO 9945 syscalls. The act of walking a directory tree and stat-ing entries is L2 specification behavior — it belongs alongside `ISO_9945.Kernel.Directory` and `ISO_9945.Kernel.File.Stats`. This is not "policy"; it is faithfully executing what the standard specifies.

   - **Pattern matching algorithm** (wildcard expansion, `*`/`?`/`[...]` semantics): This is algorithmic logic that composes the directory traversal results. The matching rules are specified by POSIX `glob(3)`, but the implementation is a composed operation — matching patterns against enumerated entries.

   The current placement treats glob as monolithically L3. The harder question: should the directory traversal be extracted to L2 (`ISO_9945.Kernel.Glob`) with L3 owning only the composed match-and-traverse operation? Or does the tight coupling between traversal and matching justify keeping both at L3?

   If the traversal is L2 work, then the current implementation violates the design principle: L3 policy must delegate to L2, never re-implement the syscall. The `opendir`/`readdir`/`stat` calls in glob should go through `ISO_9945.Kernel.Directory` and `ISO_9945.Kernel.File.Stats`, not call C functions directly.

2. **10 pure re-export targets.** Directory, Environment, Lock, Memory, Process, Signal, Socket, System, Terminal, Thread currently add zero L3 policy. Are these placeholders for future EINTR wrappers, or should they be removed until they have actual L3 logic? The re-export targets serve a role in making `import POSIX_Kernel` provide the full surface, but each is an additional compilation target with no unique code.

3. **EINTR retry scope.** Currently only flush and write have EINTR wrappers. The same EINTR pattern applies to: `read`, `pread`, `open`, `close`, `accept`, `connect`, `send`, `recv`, `poll`, `select`, `flock`, `fcntl`, `ioctl`, `waitpid`, `nanosleep`, among others. What is the prioritization for expanding EINTR coverage across domains?

4. **Namespace depth.** `POSIX.Kernel.IO.Write.writeAll()` is 5 levels deep. The doc comment examples show `POSIX.Kernel.IO.Write.write(fd, from: buffer)`. Is this call-site ergonomic enough, or should L3 offer a shorter path (e.g., `POSIX.write(fd, from: buffer)`)?

5. **strerror convenience.** `Kernel.Error.Code.posixMessage` in POSIX Core calls `strerror()` directly. This is a platform C function call, not a wrapper around L2. Should L2 (`ISO_9945`) provide a `strerror` wrapper that L3 then re-exports, or is `strerror` appropriately an L3 convenience?
