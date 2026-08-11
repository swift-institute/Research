# Platform Stack Layering: The Role of linux-primitives

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: IN_PROGRESS
tier: 3
scope: ecosystem-wide (primitives + standards + foundations)
trigger: io_uring implementation exposed that linux-primitives (L1) needs POSIX types from iso-9945 (L2), creating an upward dependency that violates strict layering
---
-->

## Context

The io_uring implementation in `swift-linux-primitives` revealed a structural tension in
the platform stack. io_uring's operations (accept, connect, recv, send) need POSIX types
(sockaddr, timespec, iovec) that live in `swift-iso-9945` (L2). But `swift-linux-primitives`
is classified as L1 (Primitives), and L1 cannot depend upward on L2 (Standards).

The current workaround is the "shell + values" pattern: `kernel-primitives` (L1) defines
empty OptionSet shells (`Kernel.Socket.Message.Options`), `linux-primitives` adds platform
values via extension, and io_uring references the shell type. This works but is architectural
gymnastics — creating types in L1 whose sole purpose is to be filled by L1-platform
packages that need L2 types but can't import L2.

[PLAT-ARCH-007] says "both swift-darwin-primitives and swift-linux-primitives depend on
swift-iso-9945." But in practice, this dependency was **never added**. The architecture
documented an intent that was never realized, and the implementation has been working
around the gap ever since.

This research examines whether the current layering is correct, and if not, what should
change.

## Question

**At which layer should platform-specific kernel API wrappers (linux-primitives,
darwin-primitives, windows-primitives) live?** Is L1 (Primitives) correct, or should
they be L2 (Standards)?

---

## Analysis

### The Five-Layer Question Test

The architecture assigns each layer a question:

| Layer | Question | Examples |
|-------|----------|---------|
| L1 Primitives | What must exist? | Buffer, Cardinal, Property, Memory |
| L2 Standards | What is specified externally? | ISO 32000 (PDF), RFC 4122 (UUID), ISO 9945 (POSIX) |
| L3 Foundations | What can be composed safely? | File I/O, JSON, TLS |

Applying the test to each package:

| Package | "What must exist?" (L1) | "What is specified externally?" (L2) |
|---------|------------------------|--------------------------------------|
| kernel-primitives | ✓ Kernel.Descriptor, Kernel.Error — atomic types every platform needs | — |
| cpu-primitives | ✓ Atomics, barriers, timestamps — hardware primitives | — |
| arm-primitives | ✓ ARM registers, instructions — hardware | — |
| iso-9945 | — | ✓ POSIX specification (IEEE 1003.1) |
| **linux-primitives** | ? | ✓ Linux kernel API (man pages, stable ABI, versioned) |
| **darwin-primitives** | ? | ✓ Darwin/Mach API (Apple documentation, SDK headers) |
| **windows-primitives** | ? | ✓ Win32 API (MSDN, Windows SDK) |

Linux-primitives answers "what is specified externally?" far more naturally than
"what must exist?" The Linux kernel API is an external specification with:
- Formal documentation (man pages, kernel.org)
- Versioned stable ABI (syscall table, ioctl numbers)
- Backward compatibility guarantees
- A specification owner (kernel team, Linus)

Compare with genuine L1 primitives:
- `Cardinal`: mathematical concept, domain-agnostic, no external spec
- `Buffer.Linear`: data structure discipline, domain-agnostic
- `Property.View`: Swift accessor pattern, language-level

linux-primitives wraps `io_uring_setup(2)`, `epoll_create1(2)`, `eventfd(2)` — these
are platform-specific syscalls defined by an external authority. They are not "atomic
building blocks" in the same sense as Buffer or Cardinal.

---

### Option A: Status Quo — Platform packages stay L1

**Description**: linux-primitives, darwin-primitives, windows-primitives remain L1.
The upward dependency on iso-9945 (L2) is either (a) tolerated as principled, or
(b) avoided by the shell+values pattern.

**Current architecture**:
```
L3  swift-kernel → swift-linux → swift-darwin → swift-windows
L2  swift-iso-9945
L1  swift-kernel-primitives
    ├── swift-linux-primitives  ← here
    ├── swift-darwin-primitives ← here
    └── swift-windows-primitives ← here
    ├── swift-cpu-primitives
    ├── swift-arm-primitives
    └── swift-x86-primitives
```

**Advantages**:
1. No migration — existing code stays where it is
2. "Primitives" = thinnest possible layer — syscall wrappers are thin
3. kernel-primitives (L1) defines the namespace; platform packages (L1) extend it — same level, clean
4. Hardware primitives (cpu, arm, x86) and platform primitives (linux, darwin) coexist at L1

**Disadvantages**:
1. linux-primitives cannot use POSIX types from iso-9945 without an upward dependency
2. The shell+values pattern is a workaround: creating empty types in kernel-primitives so linux-primitives can fill them — architectural gymnastics
3. Every typed io_uring operation that needs sockaddr, timespec, or iovec must either use raw C types (violates [PLAT-ARCH-005a]) or create duplicate types
4. The [PLAT-ARCH-007] dependency (linux-primitives → iso-9945) was documented but never implemented — the architecture describes a state that doesn't exist
5. "What must exist?" doesn't describe what linux-primitives contains — nobody says "io_uring must exist" the way they say "Buffer must exist"

---

### Option B: Platform packages move to L2

**Description**: linux-primitives, darwin-primitives, windows-primitives reclassify as L2
(Standards). They ARE specification implementations — just platform-specific ones.

**Proposed architecture**:
```
L3  swift-kernel → swift-linux → swift-darwin → swift-windows
L2  swift-iso-9945 (POSIX)
    ├── swift-linux-primitives  (Linux kernel API)   ← moved here
    ├── swift-darwin-primitives (Darwin/Mach API)    ← moved here
    └── swift-windows-primitives (Win32 API)         ← moved here
L1  swift-kernel-primitives (cross-platform namespace + types)
    ├── swift-cpu-primitives (hardware)
    ├── swift-arm-primitives (hardware)
    └── swift-x86-primitives (hardware)
```

**Dependency graph becomes clean**:
```
L2 linux-primitives → L2 iso-9945 → L1 kernel-primitives
L2 linux-primitives → L1 cpu-primitives
L2 darwin-primitives → L2 iso-9945 → L1 kernel-primitives
L2 windows-primitives → L1 kernel-primitives (no POSIX dep — correct)
```

**Advantages**:
1. **Clean layering** — L2 depends on L1 and L2. No upward dependencies anywhere.
2. **linux-primitives can import iso-9945 naturally** — POSIX types (sockaddr, timespec) available without shells or workarounds
3. **Honest classification** — Linux kernel API IS an external specification, classified as such
4. **Eliminates the shell+values dance** — no need to create empty OptionSets in kernel-primitives for platform packages to fill
5. **L1 becomes purely cross-platform and domain-agnostic** — Buffer, Cardinal, Memory, Property, CPU, ARM, x86. No platform API wrappers.
6. **The re-export chain stays clean**:
   ```
   import Kernel
   → @_exported Linux_Kernel (L3)
   → @_exported Linux_Kernel_Primitives (L2, was L1)
   → @_exported ISO_9945_Kernel (L2)
   → @_exported Kernel_Primitives (L1)
   ```
7. **Answers the "what's left in linux-primitives?" question** — everything. It doesn't dissolve; it just moves one layer up.

**Disadvantages**:
1. **"Primitives" suffix misleading at L2** — naming tension. "swift-linux-primitives" at L2 sounds wrong. But renaming is high-churn.
2. **Tier numbering in swift-primitives superrepo** — linux-primitives is currently Tier 18 alongside other L1 packages. Moving to L2 means it's in the wrong superrepo (should be in swift-standards?). Or the superrepo boundaries don't align with layers.
3. **Cross-repo dependency** — if linux-primitives moves to swift-standards (or swift-iso), it needs to depend on swift-primitives for kernel-primitives. This already exists for iso-9945.
4. **Darwin asymmetry** — Darwin's platform API (Mach, GCD) isn't POSIX-first the way Linux is. darwin-primitives would also be L2 but its relationship with iso-9945 differs from Linux's.
5. **Precedent change** — the -primitives suffix has always meant L1. Changing that for three packages changes a convention.

---

### Option C: Platform packages dissolve — split to iso-9945 + L3

**Description**: Eliminate linux-primitives. POSIX-compatible parts go to iso-9945.
Linux-only parts (io_uring, epoll, futex) go to swift-linux (L3).

**Advantages**:
1. Clean layering by construction — no cross-layer dependencies
2. POSIX syscalls shared by Darwin and Linux are in one place (iso-9945)
3. No "primitives at L2" naming problem

**Disadvantages**:
1. **io_uring at L3 is wrong** — it's a thin syscall wrapper, not a composed abstraction.
   L3 types like `IO.Event.Channel` compose io_uring; io_uring itself is the raw API.
2. **swift-linux (L3) becomes both composition and syscall wrapping** — mixed abstraction levels
3. **Loses the "here is what Linux provides beyond POSIX" story** — the Linux kernel API has
   no dedicated home; it's scattered across L2 (POSIX parts) and L3 (Linux-only parts)
4. **Linux-specific syscalls that share nothing with POSIX** (futex, io_uring, bpf) don't
   belong in iso-9945 and shouldn't be at L3. They need an L2 home.

---

### Option D: Hybrid — thin wrapper stays L1, typed API moves to L2

**Description**: Split linux-primitives into two layers:
- L1: C shim + raw namespace declarations + untyped syscall wrappers
- L2: Typed io_uring, typed epoll — these need POSIX types

**Advantages**:
1. Strict layering — L1 is truly primitive (no POSIX deps)
2. L2 typed API can import iso-9945

**Disadvantages**:
1. Adds a package to the stack (or splits an existing one into two targets)
2. Where does the line fall? Most "thin" wrappers also need at least Kernel.Descriptor
3. Two packages for "Linux kernel API" is confusing
4. The split is maintenance overhead with little conceptual benefit

---

### Option E: Keep structure, rename to clarify purpose

**Description**: Keep platform packages at L1 physically but rename them to reflect their
true nature. Accept the upward dependency on iso-9945 as documented and intentional.

- `swift-linux-primitives` → `swift-linux-kernel` (or keep name)
- Add the iso-9945 dependency that [PLAT-ARCH-007] already specifies
- Stop pretending this is strict L1 — it's L1.5

**Advantages**:
1. Minimal code change — just add the dependency
2. Honest about the layering exception
3. Gets io_uring access to POSIX types immediately

**Disadvantages**:
1. "L1.5" is not a real layer — either the architecture has strict layers or it doesn't
2. Erodes the layering principle — if this exception is OK, what prevents others?

---

## Comparison

| Criterion | A (Status quo) | B (Move to L2) | C (Dissolve) | D (Split) | E (Rename) |
|-----------|---------------|-----------------|--------------|-----------|------------|
| Strict layering | ✗ | ✓ | ✓ | ✓ | ✗ |
| POSIX type access | ✗ | ✓ | ✓ | ✓ | ✓ |
| io_uring at correct level | ✓ (L1) | ✓ (L2) | ✗ (L3 too high) | ✓ (L2) | ✓ (L1) |
| Migration cost | None | Medium | High | High | Low |
| Conceptual clarity | Low | High | Medium | Low | Medium |
| Naming consistency | ✓ | ✗ (primitives at L2) | ✓ | ✗ (split) | ✓ |
| Shell+values workaround needed | Yes | No | No | No | No |
| L1 stays domain-agnostic | No | Yes | Yes | Partially | No |

---

## Factors Not Previously Considered

### 1. The superrepo boundary question

`swift-primitives` is a superrepo containing all L1 packages. If linux-primitives moves
to L2, does it move to `swift-standards`? Or does `swift-primitives` become "L1 + L2
platform packages"? The superrepo boundary doesn't have to align with layers — it's a
build/organization concern, not a semantic one. iso-9945 already lives in `swift-iso`,
not `swift-standards`.

### 2. The -primitives suffix as a signal

Today, `-primitives` means "L1 atomic building block." If linux-primitives becomes L2,
the suffix signals the wrong thing. But renaming packages is high-churn (Package.swift
dependencies, import statements, CI). The pragmatic path: keep the name, update the
documentation. The suffix becomes historical rather than architectural.

### 3. The Linux kernel API IS a specification

The Linux kernel has:
- Numbered syscalls with stable ABI (`__NR_io_uring_setup = 425`)
- Man pages (man7.org, kernel.org)
- Backward compatibility guarantees (Linus's #1 rule: "we don't break userspace")
- Versioned feature flags (`IORING_FEAT_SINGLE_MMAP` in kernel 5.4+)

This is MORE formally specified than many things we already put at L2. The Linux kernel
API has stronger stability guarantees than most RFCs.

### 4. Hardware vs platform API — the real L1/L2 boundary

L1 packages fall into two natural categories:
- **Hardware primitives**: cpu, arm, x86 — wrap HARDWARE, no platform API dependency
- **Platform API wrappers**: linux, darwin, windows — wrap a PLATFORM'S SYSCALL TABLE

These are fundamentally different things. Hardware primitives are L1 by any definition.
Platform API wrappers answer "what does this platform specify?" — that's L2.

### 5. The shell+values pattern is a dependency inversion smell

Creating `Kernel.Socket.Message.Options` (empty shell) in kernel-primitives so that
linux-primitives can fill it with MSG_* values is **dependency inversion**. The shell
exists solely to break a layering constraint. If the layering were correct, the type
would be defined where the values are — in the platform package (with POSIX types
available for the parameter types).

### 6. Consumer perspective

Consumers write `import Kernel`. They never import linux-primitives directly. The
re-export chain makes the layer invisible. Whether linux-primitives is L1 or L2
is invisible to consumers — it only matters for the platform stack's internal
dependency graph.

---

## Outcome

**Status**: DECISION

**Option B selected** with dedicated organizations and renamed packages.

### Decision

```
L3  swift-foundations/swift-linux              — Modern Swift API, composition, async, ergonomics
         ↑
L2  swift-linux-foundation/swift-linux-standard — Faithful Linux kernel API spec encoding
    swift-iso/swift-iso-9945                    — POSIX spec encoding (IEEE 1003.1)
         ↑
L1  swift-primitives/swift-kernel-primitives   — Cross-platform namespace + types
    swift-primitives/swift-cpu-primitives      — Hardware: atomics, barriers, timestamps
    swift-primitives/swift-arm-primitives      — Hardware: ARM registers, instructions
    swift-primitives/swift-x86-primitives      — Hardware: x86 CPUID, RDRAND, RDTSCP
```

| Old | New | Layer | Organization |
|-----|-----|-------|-------------|
| `swift-linux-primitives` | **`swift-linux-standard`** | **L2** | `swift-linux-foundation` (new org) |
| `swift-darwin-primitives` | `swift-darwin-standard` | L2 | (TBD) |
| `swift-windows-primitives` | `swift-windows-standard` | L2 | `swift-microsoft` (new org) |
| `swift-linux` (L3) | unchanged | L3 | `swift-foundations` |
| `swift-kernel-primitives` | unchanged | L1 | `swift-primitives` |
| `swift-cpu-primitives` | unchanged | L1 | `swift-primitives` |

### Rationale

1. **L2 is the correct classification**: The Linux kernel API is an external specification
   with versioned ABI, man pages, and backward compatibility guarantees. It answers
   "what is specified externally?" — the L2 question. Hardware primitives (cpu, arm, x86)
   stay L1 — they wrap silicon, not specifications.

2. **L2/L3 split serves two distinct audiences**:
   - L2 (`swift-linux-standard`): spec-accurate encoding of the Linux kernel API.
     io_uring as the kernel defines it. Faithful, thin, timeless.
   - L3 (`swift-linux`): modern Swift API layered on top. Event loops, async integration,
     composed abstractions, ergonomic wrappers.
   - A consumer who wants raw io_uring imports L2. A consumer who wants an event loop
     imports L3.

3. **Clean dependency graph**: L2 → L2 (linux-standard → iso-9945) is same-layer.
   L2 → L1 (linux-standard → kernel-primitives) is downward. No upward dependencies.
   The shell+values workaround is eliminated — linux-standard imports POSIX types directly.

4. **Dedicated organizations**: `swift-linux-foundation` and `swift-microsoft` give
   platform-specific standards their own home, separate from cross-platform primitives.

5. **Naming clarity**: `swift-linux-standard` communicates "standard encoding of Linux API"
   rather than `swift-linux-primitives` which incorrectly implied L1 atomic building blocks.

### Implementation Plan

1. Create `swift-linux-standard` repo in `swift-linux-foundation` org
2. Move all content from `swift-primitives/swift-linux-primitives/`
3. Add `swift-iso-9945` as a dependency — unblocks POSIX type access
4. Audit and eliminate shell types in kernel-primitives (dependency-inversion workarounds)
5. Update `swift-linux` (L3) to depend on `swift-linux-standard` (L2)
6. Update [PLAT-ARCH-001] and five-layer architecture documentation
7. Apply same pattern: `swift-darwin-standard`, `swift-windows-standard`

## References

- [PLAT-ARCH-001] through [PLAT-ARCH-010] — Platform skill
- [ARCH-LAYER-001] — Five-layer architecture (swift-institute)
- io_uring implementation session (2026-04-10) — triggered this investigation
- `io-uring-semantic-flag-modeling.md` — documents the shell+values workaround
- `Five Layer Architecture.md` — swift-institute/Documentation.docc/
