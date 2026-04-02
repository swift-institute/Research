---
date: 2026-04-01
session_objective: Investigate and fix swift-io test hang caused by Kernel.Descriptor deinit closing process file descriptors
packages:
  - swift-io
  - swift-kernel-primitives
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: package_insight
    target: swift-kernel-primitives
    description: "Kernel.Socket.Descriptor must become ~Copyable with deinit for ownership consistency; Kernel.Descriptor(_ socket:) conversion needs consuming path that avoids double-close"
  - type: skill_update
    target: memory-safety
    description: "Add rule: adding deinit to existing ~Copyable type is a breaking change — all downstream _rawValue usage must be audited"
  - type: research
    target: kqueue-ebadf-investigation
    description: "All kqueue-based tests fail with EBADF (posix(9)); root cause unknown — could be driver initialization, wakeup channel creation, or handle validity"
---

# Kernel.Descriptor Deinit — Process fd Corruption and ~Copyable Ownership Gaps

## What Happened

`swift test` in swift-io hung indefinitely — ~40 suites started, zero tests completed. Investigation traced the root cause to `Kernel.Descriptor`'s newly-added deinit calling `Darwin.close(_raw)`. Test code created descriptors with arbitrary `_rawValue` (1, 2, 3, 42) as "fake" values. The deinit closed stdout (fd 1) and stderr (fd 2), breaking the Swift Testing runner.

The fix (commit `e85a7ec`) used three approaches: negative `_rawValue` for fake descriptors (deinit skips `_raw < 0`), `~Copyable` `RawPipe` struct with `Kernel.Descriptor.Duplicate.duplicate()` for pipe ownership, and `SocketPair` struct for socket pair ownership (tuples of ~Copyable types are unsupported).

After the hang fix, a second pre-existing issue surfaced: all kqueue-based tests fail with EBADF. These tests never ran before — they were masked by the hang. A handoff covers both the `Kernel.Socket.Descriptor` → `~Copyable` migration and the kqueue investigation.

## What Worked and What Didn't

**Worked well**: Systematic isolation via `swift test --filter` on progressively narrower test subsets. Running `registerUniqueIDs` alone (closes fds 1, 2, 3) proved the single-test hang. Running `registerCreatesMapping` alone (closes fd 42) proved it was fd-specific. This diagnostic chain was conclusive in ~30 minutes.

**Worked well**: The `~Copyable RawPipe` with `dup()` — clean ownership model where partial field consumption transfers fds to `Channel.wrap` and deinit handles cleanup. No manual `closeAll()` needed.

**Didn't work**: Initial attempt to use tuples for socket pair return types — `(Kernel.Descriptor, Kernel.Descriptor)` rejected by compiler ("tuple with noncopyable element type not supported"). Required a `SocketPair` struct workaround.

**Didn't work**: `consume pipe.write` syntax for partial field consumption — compiler treats `consume` on a field as consuming the entire struct. Plain `_ = pipe.write` works for field moves. This cost ~20 minutes of trial-and-error.

**Missed initially**: The `@const`/`@section` macro errors were assumed to be the root cause early in investigation. The actual root cause (fd close) was much more subtle and required reading the `Kernel.Descriptor` deinit source.

## Patterns and Root Causes

**Adding a deinit to a previously-deinit-free type is a breaking change.** `Kernel.Descriptor` went from a passive Int32 wrapper to an owning resource handle. Every call site that created a descriptor from a raw value, used it temporarily, and let it drop now has a side effect (closing the fd). Test code was the most exposed because it created descriptors with arbitrary values for identity-only purposes.

**The `_rawValue` SPI is a footgun.** It lets callers create "owning" descriptors from arbitrary fd numbers. There's no way to create a non-owning descriptor or to suppress the deinit from outside the type. The negative-value workaround works because of an implementation detail (`isValid` checks `_raw >= 0`), not by design.

**`Kernel.Socket.Descriptor` being Copyable while `Kernel.Descriptor` is ~Copyable creates an asymmetric ownership model.** `Kernel.Descriptor(socket)` silently transfers ownership from a non-owning type to an owning type. After the conversion, both the socket descriptor (Copyable, no deinit) and the kernel descriptor (~Copyable, deinit) reference the same fd. The kernel descriptor's deinit closes it; the socket descriptor is oblivious. This will cause bugs wherever socket descriptors are converted to kernel descriptors temporarily.

## Action Items

- [ ] **[package]** swift-kernel-primitives: `Kernel.Socket.Descriptor` must become `~Copyable` with deinit for ownership consistency. The `Kernel.Descriptor(_ socket:)` conversion needs a consuming path that doesn't double-close.
- [ ] **[skill]** memory-safety: Add guidance for "adding deinit to existing ~Copyable types is a breaking change" — all downstream `_rawValue` usage must be audited when a type gains a deinit.
- [ ] **[research]** Investigate the kqueue EBADF failures — all `IO.Event.Selector.make(driver: .kqueue(), ...)` calls fail with posix(9). Root cause unknown; could be driver initialization, wakeup channel creation, or handle validity.
