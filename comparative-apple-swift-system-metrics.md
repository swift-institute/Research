# Comparative Analysis: apple/swift-system-metrics vs Swift Institute Ecosystem

<!--
---
version: 1.0.0
last_updated: 2026-02-25
status: RECOMMENDATION
tier: 1
type: discovery
trigger: Apple released swift-system-metrics (formerly swift-metrics-extras); cross-package review to identify opportunities and learnings.
---
-->

## Context

Apple released [swift-system-metrics](https://github.com/apple/swift-system-metrics) (formerly `swift-metrics-extras`), a focused package for collecting and reporting process-level system metrics (memory, CPU, file descriptors). The package underwent a significant API revision (SSM-0001) for its 1.0 release and was renamed (SSM-0002) to better reflect its scope.

The Swift Institute ecosystem has extensive kernel, system, and platform primitives across `swift-primitives` (Layer 1) and `swift-foundations` (Layer 3). This analysis identifies: (1) what Apple's package does that we lack, (2) what we have that Apple's package lacks, (3) design pattern learnings, and (4) concrete opportunities for improvement.

## Question

What can the Swift Institute ecosystem learn from apple/swift-system-metrics, and where are there gaps or opportunities for improvement in our kernel/system/platform primitives?

## Analysis

### Apple's Package: Scope and Architecture

**Single module, 4 source files, 6 gauges.** Extremely focused:

| Metric | Darwin Mechanism | Linux Mechanism |
|--------|-----------------|-----------------|
| Virtual memory bytes | `proc_pidinfo(PROC_PIDTASKALLINFO)` | `/proc/self/stat` field 23 (vsize) |
| Resident memory bytes | `proc_pidinfo(PROC_PIDTASKALLINFO)` | `/proc/self/stat` field 24 (rss × page size) |
| Process start time (epoch) | `proc_taskallinfo.pbsd.pbi_start_tvsec` | `/proc/self/stat` field 22 (starttime ticks ÷ CLK_TCK + btime) |
| CPU seconds total (user+sys) | Mach ticks via `mach_timebase_info` | `getrusage(RUSAGE_SELF)` user + system |
| Max file descriptors | `getrlimit(RLIMIT_NOFILE)` | `getrlimit(RLIMIT_NOFILE)` |
| Open file descriptors | `proc_pidinfo(PROC_PIDLISTFDS)` | enumerate `/proc/self/fd/` |

**Dependencies**: swift-metrics (Gauge reporting), swift-service-lifecycle (`Service` protocol), swift-async-algorithms (`AsyncTimerSequence` for polling).

**Key design decisions**:
- Conforms to `Service` protocol — lifecycle managed via `ServiceGroup`
- `AsyncTimerSequence` for periodic polling (configurable interval, default 15s)
- `SystemMetricsProvider` protocol abstracts platform data collection
- `package` access for testing (SE-0386) — no `@testable import`
- Optional `MetricsFactory` injection to decouple from global `MetricsSystem`
- Prometheus-compatible default metric names (`process_*`)
- Graceful failure: `data()` returns `nil` on unsupported platforms, no throws
- No Foundation dependency on Linux (custom `CFile` class for procfs reading)
- Swift 6 strict concurrency with upcoming feature flags

### Swift Institute Ecosystem: What Exists

#### Primitives Layer (swift-primitives)

| Capability | Module | Coverage |
|-----------|--------|----------|
| Process ID (current, parent) | Kernel Primitives + ISO 9945 Kernel | `Kernel.Process.ID.current`, `.parent` via getpid/getppid |
| Processor count | System Primitives | `System.processorCount` via sysconf/GetSystemInfo |
| NUMA topology | System Primitives | `System.Topology` with `.unavailable`/`.uniformAccess`/`.nonUniform(nodes:)` |
| File stats (size, perms, times, inode) | Kernel Primitives + ISO 9945 | `Kernel.File.Stats.get(path:)`, `.get(descriptor:)` |
| Filesystem stats (blocks, inodes) | Kernel Primitives | `Kernel.File.System.Stats` |
| Darwin file stats + birthtime | Darwin Kernel Primitives | `Darwin.File.Stats` with `birthtime` |
| Darwin malloc zone statistics | Darwin Memory Primitives | `Darwin.Memory.Allocation.Statistics.capture()` |
| Linux malloc tracking (LD_PRELOAD) | Linux Memory Primitives | `Linux.Memory.Allocation.Statistics.capture()`/`.startTracking()` |
| CPU timestamps (TSC/RDTSCP/ARM) | CPU Primitives + X86/ARM Primitives | `CPU.Timestamp.read` with arch-specific variants |
| Monotonic clocks (continuous/suspending) | Kernel Primitives + ISO 9945 | `Kernel.Clock.Continuous`, `.Suspending` |
| Memory page size | Kernel Primitives | `Kernel.Memory.Page.Size` |
| Memory mapping | Kernel Primitives + ISO 9945 | `Kernel.Memory.Map` (mmap/munmap) |
| File descriptors (type, validation) | Kernel Primitives | `Kernel.Descriptor`, `.isValid`, limit error types |
| kqueue (Darwin) | Darwin Kernel Primitives | Complete wrapper: filters, events, flags |
| epoll (Linux) | Linux Kernel Primitives | Full wrapper with Duration support |
| io_uring (Linux) | Linux Kernel Primitives | 50+ files: setup, SQ/CQ, operations, registration |
| Process fork/wait/status | ISO 9945 Kernel | Fork with typed result, wait with selector pattern, status classification |

#### Foundations Layer (swift-foundations)

| Capability | Module | Coverage |
|-----------|--------|----------|
| Thread pool executor | swift-kernel | `Kernel.Thread.Executor`, `.Worker`, `.Barrier`, `.Gate` |
| Async I/O event loop | swift-io | `IO.Event.Poll.Loop`, selectors, non-blocking I/O |
| Unified system topology | swift-systems | Cross-platform `System.topology()` dispatch |
| Platform kernel bindings | swift-darwin, swift-linux, swift-windows | Platform-specific kernel/system/loader modules |
| Atomic operations | swift-kernel | `Kernel.Atomic.Flag` and related primitives |

### Gap Analysis

#### What Apple Has, We Lack

| Capability | Apple's Approach | Gap Severity | Where It Would Live |
|-----------|-----------------|--------------|---------------------|
| **`proc_pidinfo` / task info** | `proc_pidinfo(PROC_PIDTASKALLINFO)` for virtual/resident memory, start time | **High** | Darwin Kernel Primitives (C shim + Swift wrapper) |
| **`mach_timebase_info`** | Convert Mach absolute time ticks to nanoseconds | **Medium** | Darwin Kernel Primitives or Darwin Time Primitives |
| **`getrusage`** | `getrusage(RUSAGE_SELF)` for user+system CPU time | **High** | ISO 9945 Kernel (POSIX standard) |
| **`getrlimit` / `setrlimit`** | Query/set resource limits (RLIMIT_NOFILE, etc.) | **High** | ISO 9945 Kernel (POSIX standard) |
| **procfs reading** | Custom `CFile` class reads `/proc/self/stat`, `/proc/self/fd/`, `/proc/stat` | **Medium** | Linux Kernel Primitives |
| **Open FD count** | `proc_pidinfo(PROC_PIDLISTFDS)` on Darwin; enumerate `/proc/self/fd/` on Linux | **Medium** | Platform-specific kernel primitives |
| **Process start time** | From task info (Darwin) or `/proc/self/stat` (Linux) | **Low** | Derivable once proc_pidinfo/procfs exist |
| **Prometheus-compatible labels** | `process_*` naming convention with configurable prefix | **N/A** | Application-layer concern, not primitives |
| **Service protocol integration** | Conforms to `Service` from swift-service-lifecycle | **N/A** | Application-layer concern |

#### What We Have, Apple Lacks

| Capability | Our Approach | Apple's Gap |
|-----------|-------------|-------------|
| **NUMA topology** | `System.Topology.NUMA.State` with per-node CPU sets | No topology awareness |
| **CPU timestamps (TSC/RDTSCP)** | Architecture-specific `CPU.Timestamp` with serialized reads | No hardware-level timing |
| **io_uring** | 50+ files of complete io_uring bindings | No async I/O primitives |
| **epoll** | Full wrapper with Duration-typed timeouts | No event notification |
| **kqueue** | Complete kqueue with filter/event/flag types | No event notification |
| **Filesystem stats** | `Kernel.File.System.Stats` (blocks, inodes, fstype) | No filesystem metrics |
| **Thread affinity** | `Kernel.Thread.Affinity` (.any, .cores, .numaNode) | No thread control |
| **Move-only thread handles** | `~Copyable` thread handle preventing double-join UB | N/A (no thread management) |
| **Windows support** | `Windows.Kernel.Process`, `.System`, `.IO.Completion.Port` | macOS + Linux only |
| **Typed process status** | Fork result enum, wait selector, exit/signal/stop classification | No process management |
| **Memory allocation tracking** | Platform-specific `Allocation.Statistics` (malloc zone / LD_PRELOAD) | No allocation tracking |

### Design Pattern Comparison

| Aspect | Apple | Swift Institute | Assessment |
|--------|-------|-----------------|------------|
| **Platform abstraction** | `#if os()` in extension files, protocol for injection | Multi-package: platform primitives → ISO 9945 → unified foundations | Ours is more layered and reusable; Apple's is simpler for single-purpose use |
| **Error handling** | `data()` returns `nil` — silent failure | Typed throws everywhere (`throws(Kernel.Error)`) | Ours is stricter, better for infrastructure; Apple's pragmatic for metrics (transient failures expected) |
| **Naming** | `SystemMetricsMonitor`, `SystemMetricsProvider` — compound names | `Kernel.Process.ID`, `System.Topology.NUMA.State` — nested namespaces | Ours follows [API-NAME-001]; Apple uses conventional Swift compound naming |
| **Configuration** | Immutable `Configuration` struct with nested `Labels` | Property/Tagged patterns for type-safe configuration | Different domains — Apple's is application-config, ours is type-level |
| **Testing** | `package` access + mock provider injection | Platform varies (some `@testable`, moving toward `package`) | Apple's `package` access pattern is clean; worth adopting more broadly |
| **Foundation independence** | Custom `CFile` on Linux (avoids Foundation) | Foundation-free across all primitives/standards [PRIM-FOUND-001] | Aligned philosophy — Apple independently arrived at the same conclusion for procfs |
| **Concurrency** | `Sendable` everywhere, upcoming feature flags | `Sendable` where applicable, `~Copyable` for ownership | Ours is more advanced (substructural types); Apple uses standard Swift 6 |
| **Swift 6 feature flags** | `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`, `NonisolatedNonsendingByDefault` | Varies by package | Apple's aggressive adoption of `NonisolatedNonsendingByDefault` is notable |

### Learnings from Apple's Implementation

**1. `NonisolatedNonsendingByDefault` adoption.** Apple enables this upcoming feature flag. We should evaluate adopting it across the ecosystem. It changes the default isolation of nonisolated async functions from `@Sendable` to non-sendable, reducing unnecessary Sendable constraints.

**2. `package` access for testability (SE-0386).** Apple uses `package` access instead of `@testable import` for injecting test providers. This is cleaner — the test surface is explicitly designed, not a testing backdoor. We should adopt this pattern where we currently use `@testable import`.

**3. Custom `CFile` for procfs — Foundation-free file reading.** Apple's Linux implementation has a minimal C FILE wrapper to avoid Foundation entirely. This validates our [PRIM-FOUND-001] philosophy and demonstrates that even Apple's server-side packages are moving away from Foundation for low-level operations.

**4. `AsyncTimerSequence` for periodic operations.** Apple uses `AsyncTimerSequence` from swift-async-algorithms for the polling loop. Clean integration with structured concurrency and task cancellation. Worth considering for any periodic operations in our foundations layer (health checks, metric collection, pool maintenance).

**5. Prometheus naming conventions.** The `process_*` metric names follow an industry standard. If we ever build a metrics/observability layer, adopting Prometheus naming from the start prevents migration pain.

**6. Silent failure for transient metrics.** `data() -> Data?` returning nil on failure (rather than throwing) is a deliberate design choice for metrics — a missed sample is not an error worth propagating. Different from our infrastructure philosophy but appropriate at the application layer.

## Outcome

**Status**: RECOMMENDATION

### Priority 1: Add Missing POSIX Syscall Wrappers (ISO 9945 Kernel)

These are standard POSIX calls that belong in `swift-standards/swift-iso-9945`:

| Syscall | Type | Purpose |
|---------|------|---------|
| `getrusage(RUSAGE_SELF)` | Resource usage | CPU time (user + system), max RSS, page faults, context switches |
| `getrlimit(resource)` | Resource limits | Query soft/hard limits (RLIMIT_NOFILE, RLIMIT_AS, etc.) |
| `setrlimit(resource, rlimit)` | Resource limits | Set soft/hard limits |

These are fundamental POSIX APIs that our ISO 9945 implementation should cover regardless of the metrics use case.

**Recommended types**:
- `Kernel.Process.Resource.Usage` — wraps `struct rusage` fields
- `Kernel.Process.Resource.Limit` — wraps `struct rlimit` (soft, hard)
- `Kernel.Process.Resource.Kind` — enum for RLIMIT_* constants

### Priority 2: Add Darwin Process Info (Darwin Kernel Primitives)

Platform-specific extensions that cannot be expressed through POSIX alone:

| API | Purpose |
|-----|---------|
| `proc_pidinfo(PROC_PIDTASKALLINFO)` | Virtual memory, resident memory, start time |
| `proc_pidinfo(PROC_PIDLISTFDS)` | Enumerate open file descriptors |
| `mach_timebase_info` | Convert Mach ticks to nanoseconds |

**Recommended types**:
- `Darwin.Kernel.Process.TaskInfo` — wraps `proc_taskallinfo` fields
- `Darwin.Kernel.Process.FileDescriptors` — open FD enumeration
- `Darwin.Kernel.Time.MachTimebase` — tick-to-nanosecond conversion factor

### Priority 3: Add Linux Procfs Utilities (Linux Kernel Primitives)

Linux-specific process information not available through POSIX:

| Source | Fields |
|--------|--------|
| `/proc/self/stat` | Virtual memory size, RSS pages, start time ticks, CPU ticks |
| `/proc/self/fd/` | Open file descriptor enumeration |
| `/proc/stat` | System boot time (for start time calculation) |

**Recommended approach**: A lightweight `Linux.Kernel.Process.Stats` type that reads and parses `/proc/self/stat` without Foundation. Apple's `CFile` approach (C-level `fopen`/`fgets`/`fclose` wrapper) is one option; we could also use direct `open`/`read`/`close` syscalls since we already have those wrappers.

### Priority 4: Evaluate Swift 6 Feature Flag Adoption

Apple enables these across their package:
- `ExistentialAny` — we likely already require this
- `MemberImportVisibility` — controls transitive member visibility
- `InternalImportsByDefault` — imports are internal by default
- **`NonisolatedNonsendingByDefault`** — most impactful; changes async function defaults

Recommend a targeted audit of which flags we can adopt without breaking changes.

### Not Recommended

- **Building a metrics collection service**: Apple's `SystemMetricsMonitor` is an application-layer component (Layer 4/5 in our model). It depends on swift-metrics and swift-service-lifecycle — external opinionated frameworks. Not appropriate for our primitives/standards/foundations layers.
- **Adopting silent-failure patterns**: Apple's `nil`-return pattern makes sense for their use case but conflicts with our typed-throws philosophy. Keep our strict error handling in the lower layers.

## References

- [apple/swift-system-metrics](https://github.com/apple/swift-system-metrics) — Source repository
- SSM-0001 — API revision proposal (Service protocol, factory injection)
- SSM-0002 — Package rename from swift-metrics-extras
- [PRIM-FOUND-001] — No Foundation in primitives/standards
- [API-ERR-001] — Typed throws requirement
- [API-NAME-001] — Namespace structure (Nest.Name pattern)
- POSIX.1-2024 (IEEE Std 1003.1) — `getrusage`, `getrlimit`, `setrlimit` specifications
- Darwin `libproc.h` — `proc_pidinfo`, `PROC_PIDTASKALLINFO`, `PROC_PIDLISTFDS`
