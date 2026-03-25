# ~Sendable Semantic Inventory

<!--
---
version: 1.0.0
last_updated: 2026-03-25
status: RECOMMENDATION
tier: 2
workflow: Discovery [RES-012]
trigger: Swift 6.3 release (SE-0518 TildeSendable experimental)
scope: swift-kernel-primitives, swift-kernel, swift-io, swift-file-system
---
-->

## Context

Swift 6.3 introduces `~Sendable` (SE-0518) as an experimental feature. It allows types to explicitly suppress Sendable inference at the declaration site, analogous to `~Copyable` for non-copyable types. This document inventories every type across four packages and triages which ones **semantically should** have `~Sendable` — independent of whether `~Sendable` is currently stable or whether practical constraints (async APIs, closure boundaries) would require workarounds.

**Packages audited**: swift-kernel-primitives (L1), swift-kernel (L3), swift-io (L3), swift-file-system (L3)

**Methodology**: Every struct, class, and enum with stored properties was evaluated against this semantic criterion:

> Does this type represent state that is inherently unsafe to use from multiple concurrency domains, even if all its stored properties are individually `Sendable`?

Types that are `~Copyable` with `Sendable` were evaluated separately: single-owner transfer semantics (move to another thread) is a valid use of `Sendable` when `~Copyable` prevents sharing.

## Question

Which types in these four packages should semantically be `~Sendable`, and which current `@unchecked Sendable` annotations mask a semantic mismatch?

---

## Semantic Framework

Three categories of Sendable usage emerge:

| Category | Semantics | Correct annotation |
|----------|-----------|-------------------|
| **Thread-safe by construction** | Internal synchronization (mutex, atomic) | `@unchecked Sendable` ✓ |
| **Ownership transfer** | `~Copyable` ensures single owner; Sendable enables move across threads | `~Copyable, Sendable` ✓ |
| **Thread-confined** | All access happens on one specific thread; Sendable used only to cross one controlled boundary | Should be `~Sendable`; current `@unchecked Sendable` masks the confinement |

The third category is where `~Sendable` adds value. These types use `@unchecked Sendable` not because they're thread-safe, but because they need to cross exactly one boundary (e.g., poll thread → actor). The `@unchecked Sendable` is a lie about the type's nature — it's not safe to send arbitrarily, only to transfer to its designated thread.

---

## Tier 1: Should Be ~Sendable

Types where `Sendable` is semantically incorrect. Current annotations mask non-thread-safe access patterns.

| # | Type | Package | Current | Stored State | Semantic Argument |
|---|------|---------|---------|--------------|-------------------|
| 1 | `IO.Completion.IOUring.Ring` | swift-io | `final class: @unchecked Sendable` | FD + 3 mmap'd regions + 6 raw pointers into kernel shared memory | Thread-confined: comment states "all access happens on the poll thread." The ring is a single-threaded io_uring interface. Sending it to a second thread would corrupt the submission/completion state machine. |
| 2 | `IO.Completion.IOCP.State` | swift-io | `final class: @unchecked Sendable` | IOCP registry + pending state | Thread-confined: comment states "all access happens on the poll thread." Same pattern as IOUring.Ring. |
| 3 | `File.Directory.Contents.IteratorHandle` | swift-file-system | `final class: @unchecked Sendable` | `Kernel.Directory.Stream` (OS directory handle) | The stream has mutable kernel state advanced by `readdir()`. Concurrent `next()` calls from two threads is a POSIX data race. Already flagged as OPEN finding in `swift-file-system/Research/audit.md` finding #1 (MEM-SEND-001). |

### Pattern: Thread Confinement Misrepresented as Thread Safety

Findings #1 and #2 share a structural pattern in the IO layer: poll-thread-confined types marked `@unchecked Sendable`. The `@unchecked Sendable` exists solely to cross the poll-thread → actor boundary during initialization. After that single transfer, the type is used exclusively on the poll thread.

With `~Sendable`, the true semantics would be expressed at the type level. The single boundary crossing would require an explicit `unsafe` transfer (e.g., `nonisolated(unsafe)` or `@unchecked Sendable` at the transfer site, not on the type itself).

---

## Tier 2: Debatable

Types where the semantic argument goes both ways. The correct answer depends on architectural philosophy.

| # | Type | Package | Current | Stored State | For ~Sendable | Against ~Sendable |
|---|------|---------|---------|--------------|---------------|-------------------|
| 4 | `Kernel.File.Write.Streaming.Context` | swift-kernel | `struct: Sendable` | `Kernel.Descriptor` + path strings + durability settings | Holds an active file descriptor for a multi-phase write. Comment: "operations on it should be sequential." Concurrent writes through the descriptor are a POSIX race. | All fields are `let`. The struct is immutable after creation. Sequential-use is an operational contract, not a data-level one. The descriptor is just a number — the unsafety is in the *operations*, not in sending the struct. |
| 5 | `Kernel.Memory.Map.Region` | swift-kernel-primitives | `struct: @unchecked Sendable` | `Kernel.Memory.Address` (pointer) + length + Windows mapping handle | Points into mapped memory. Concurrent pointer access through the region is a data race on the mapped bytes. | At L1, the struct is raw metadata: "where is the mapping?" The address and length are immutable. Concurrent *pointer dereferencing* is an access-level concern, not a send-level concern. L1 mirrors kernel semantics — the kernel allows cross-thread access to mappings. |
| 6 | `IO.Event.Batch` | swift-io | `struct: @unchecked Sendable` | Pool slot index + count + `UnsafePointer<IO.Event>` | Contains a raw pointer into a memory pool. The pointer is only valid while the slot is held. Sending to a second consumer without protocol adherence is use-after-free. | Documented ownership transfer protocol (poll thread writes → bridge → selector reads). The @unchecked Sendable enables exactly this single, controlled transfer. The pool slot is exclusively owned during the batch's lifetime. |
| 7 | `IO.Blocking.Threads.Job.Instance` | swift-io | `struct: ~Copyable, @unchecked Sendable` | Job closure pointer + metadata | Wraps a raw function pointer. The @unchecked Sendable exists to hand the job from the submitting thread to the worker thread. | ~Copyable already prevents sharing. The Sendable enables a single ownership transfer from submitter → worker, which is the intended use. Removing Sendable would break the hand-off. |

### Architectural observation

Types #4–#7 share a tension: their stored properties are technically safe to copy across threads (numbers, pointers-as-values), but their *intended usage protocol* requires single-threaded access. The question is whether `Sendable` should encode data-level safety (the bytes are safe to memcpy) or protocol-level safety (the operations through those bytes are safe to perform concurrently).

At **L1** (primitives), data-level Sendable is correct — L1 represents raw kernel values faithfully.

At **L3** (foundations), the answer depends on whether the type is designed for ownership transfer (keep Sendable + ~Copyable) or for thread confinement (should be ~Sendable).

---

## Tier 3: Correctly Handled

Types where current annotations are semantically correct. Brief rationale for each pattern.

### Pattern A: Thread-Safe by Construction (`@unchecked Sendable` ✓)

| Type | Package | Mechanism |
|------|---------|-----------|
| `Kernel.Thread.Synchronization<N>` | swift-kernel | Internal mutex + condition variables |
| `Kernel.Thread.Barrier` | swift-kernel | Protected by `SingleSync` (mutex + CV) |
| `Kernel.Thread.Gate` | swift-kernel | Protected by `SingleSync` |
| `Kernel.Thread.Executor` | swift-kernel | Internal synchronization; `SerialExecutor` conformance |
| `Kernel.Thread.Handle.Reference` | swift-kernel | Atomic-like join semantics; documented safety invariant |
| `Kernel.Continuation.Context` | swift-kernel | Atomic state machine (`compareExchange`) |
| `IO.Blocking.Threads.Runtime` | swift-io | Internal mutex via `Synchronization<1>` |
| `IO.Blocking.Threads.Runtime.State` | swift-io | Protected by parent's synchronization |
| `IO.Completion.Waiter` | swift-io | Atomic state + continuation |
| `IO.Event.Waiter` | swift-io | Atomic state + continuation |
| `IO.Event.Buffer.Pool` | swift-io | Internal synchronization |
| `IO.Blocking.Lane.Sharded.Selector` | swift-io | Atomic counter + immutable array |
| `IO.Blocking.Lane.Sharded.Snapshot.Storage` | swift-io | All atomic fields |
| `IO.Completion.Operation.Storage` | swift-io | Documented single-owner transfer |
| `IO.Executor.Shards` | swift-io | Documented synchronization invariant |
| `IO.Completion.Poll.Context` | swift-io | `~Copyable` + single-owner transfer to poll thread |

### Pattern B: Ownership Transfer (`~Copyable, Sendable` ✓)

| Type | Package | Rationale |
|------|---------|-----------|
| `Kernel.File.Handle` (L1) | swift-kernel-primitives | Owns FD; ~Copyable prevents sharing; Sendable enables move to another thread |
| `File.Descriptor` | swift-file-system | Same pattern — ~Copyable ownership + Sendable transfer |
| `File.Handle` | swift-file-system | Same pattern — composes File.Descriptor |
| `IO.Event.Driver.Handle` | swift-io | ~Copyable driver handle transferred to poll thread |
| `IO.Completion.Driver.Handle` | swift-io | Same pattern |
| `IO.Event.Channel` | swift-io | ~Copyable; wraps @Sendable closures |
| `IO.Completion.Channel` | swift-io | Same pattern |
| `Kernel.Thread.Worker` | swift-kernel | ~Copyable; enforces exactly-once join |

### Pattern C: Pure Values (explicit `Sendable` ✓)

All Sendable types in this category contain only immutable value-type fields. No semantic tension.

Includes: all error enums, option sets, configuration structs, metadata structs, phantom-type tags, namespace enums, and `RawRepresentable` wrappers across all four packages. These represent the vast majority of types (250+ across the four packages).

### Pattern D: Correctly Not Sendable

| Type | Package | Rationale |
|------|---------|-----------|
| `File.Directory.Iterator` | swift-file-system | `~Copyable`, explicitly NOT Sendable (comment documents this). Owns mutable directory handle. |
| `File.Directory.Contents.Iterator` | swift-file-system | No Sendable annotation. Wraps `Kernel.Directory.Stream`. |
| `IO.Event.Backoff.Exponential` | swift-io | `~Copyable`, no Sendable. Mutable iteration counter. |
| `IO.Blocking.Threads.Acceptance.Queue` | swift-io | `~Copyable`, no Sendable. Complex mutable queue state. |
| `Kernel.Environment.Entry` | swift-kernel-primitives | `~Copyable, ~Escapable`. Borrows OS pointers. |

---

## Quantitative Summary

| Package | Total types | Tier 1 (~Sendable) | Tier 2 (debatable) | @unchecked Sendable (correct) | ~Copyable + Sendable | Pure Sendable | Not Sendable |
|---------|-------------|--------------------|--------------------|-------------------------------|----------------------|---------------|--------------|
| swift-kernel-primitives | ~250 | 0 | 1 | 1 | 1 | ~245 | 2 |
| swift-kernel | ~55 | 0 | 1 | 6 | 1 | ~45 | 2 |
| swift-io | ~200 | 2 | 2 | ~22 | ~10 | ~155 | ~11 |
| swift-file-system | ~50 | 1 | 0 | 0 | 2 | ~44 | 3 |
| **Total** | **~555** | **3** | **4** | **~29** | **~14** | **~489** | **~18** |

---

## Architectural Observations

### 1. ~Copyable already solves most of the problem

The ecosystem's aggressive adoption of `~Copyable` for resource-owning types means that the primary use case for `~Sendable` (preventing accidental sharing) is largely handled. `~Copyable + Sendable` gives "transferable but not sharable" — exactly right for file descriptors, driver handles, and I/O tokens.

### 2. The remaining gap: thread-confined types

The 3 Tier 1 findings all follow the same pattern: a type used exclusively on a single thread (the poll thread), marked `@unchecked Sendable` to cross one initialization boundary. These types are not thread-safe — they're thread-*confined*. `~Sendable` would express the truth; the boundary crossing would need explicit unsafe transfer rather than a type-level lie.

### 3. L1 vs L3 philosophy

At L1 (primitives), Sendable mirrors kernel semantics faithfully. Kernel descriptors, memory addresses, and PIDs are just numbers — the kernel allows any thread to use them. `~Sendable` would be semantically wrong at L1 because it would impose a constraint the kernel doesn't.

At L3 (foundations), types encode higher-level contracts. The streaming write context, the io_uring ring, and the directory iterator handle all have operational contracts that go beyond their stored data. This is where `~Sendable` adds the most value.

### 4. `@unchecked Sendable` audit interaction

The 3 Tier 1 types are a subset of the 29 `@unchecked Sendable` types across these packages. The existing swift-io audit (`swift-io/Research/audit.md`) already verified all 22 IO-layer `@unchecked Sendable` conformances have synchronization mechanisms. However, that audit checked for *data race safety*, not *semantic correctness of the Sendable claim*. "All access happens on the poll thread" is data-race-free, but it's not Sendable — it's confined.

---

## Outcome

**Status**: DEFERRED — ready to execute

### Phase 1: Enable experimental features ecosystem-wide

Edit `swift-institute/Scripts/sync-swift-settings.sh`, add to `ECOSYSTEM_LINES` array (after the existing `SuppressedAssociatedTypes` line):

```bash
'        .enableExperimentalFeature("TildeSendable"),'
'        .enableExperimentalFeature("ManualOwnership"),'
'        .treatWarning("SemanticCopies", as: .warning),'
'        .treatWarning("DynamicExclusivity", as: .warning),'
```

Then run:
```bash
./swift-institute/Scripts/sync-swift-settings.sh
```

This propagates to all Package.swift files across swift-primitives, swift-standards, and swift-foundations.

**Note**: `.treatWarning` requires SwiftPM PackageDescription 6.2+ (available since Swift 6.2). `ManualOwnership` unlocks the `SemanticCopies` and `DynamicExclusivity` diagnostic groups (both `DefaultIgnoreWarnings`); the `.treatWarning` lines activate them.

### Phase 2: Apply ~Sendable to Tier 1 types

Replace `@unchecked Sendable` with `~Sendable` on 3 types:

| Type | File | Change |
|------|------|--------|
| `IO.Completion.IOUring.Ring` | `swift-io/Sources/IO Completions/IO.Completion.IOUring.Ring.swift` | `final class … : @unchecked Sendable` → `final class … : ~Sendable` |
| `IO.Completion.IOCP.State` | `swift-io/Sources/IO Completions/IO.Completion.IOCP.State.swift` | Same pattern |
| `File.Directory.Contents.IteratorHandle` | `swift-file-system/Sources/File System Core/File.Directory.Contents.IteratorHandle.swift` | Same pattern |

At each site, resolve the boundary-crossing mechanism. The single transfer (e.g., poll thread initialization) needs explicit unsafe handling:
- `nonisolated(unsafe)` at the transfer site, OR
- Local `@unchecked Sendable` wrapper at the transfer site (not on the type itself)

### Phase 3: Build, test, triage warnings

```bash
cd /Users/coen/Developer/swift-primitives && swift build 2>&1 | grep -c 'SemanticCopies\|DynamicExclusivity'
cd /Users/coen/Developer/swift-foundations && swift build 2>&1 | grep -c 'SemanticCopies\|DynamicExclusivity'
```

Triage any `SemanticCopies` warnings — these flag unintended copies in `~Copyable` code. High signal given the ecosystem's heavy `~Copyable` usage.

### Phase 4: Tier 2 design discussion (deferred)

The 4 debatable types require case-by-case decision after Phase 3 experience:
- `Kernel.File.Write.Streaming.Context` (swift-kernel)
- `Kernel.Memory.Map.Region` (swift-kernel-primitives)
- `IO.Event.Batch` (swift-io)
- `IO.Blocking.Threads.Job.Instance` (swift-io)

## References

- SE-0518: `~Sendable` (experimental, Swift 6.3)
- `swift-6.3-ecosystem-opportunities.md` — Tier C2 tracking entry
- `swift-io/Research/audit.md` — Memory Safety section, 22 `@unchecked Sendable` audit
- `swift-file-system/Research/audit.md` — Finding #1 (MEM-SEND-001), IteratorHandle
- `swiftlang/swift/include/swift/Basic/Features.def:550` — `SUPPRESSIBLE_EXPERIMENTAL_FEATURE(TildeSendable, false)`
- `swiftlang/swift-package-manager/Sources/Runtimes/PackageDescription/BuildSettings.swift:682` — `.treatWarning(_:as:)` API (PackageDescription 6.2+)
