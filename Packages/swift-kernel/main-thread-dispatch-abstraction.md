# Main-Thread Dispatch Abstraction

<!--
---
version: 5.0.0
last_updated: 2026-04-16
status: SUPERSEDED
---
-->

## Status

**Superseded and relocated.** The canonical research for `Executor.Main` platform architecture now lives at:

**[`swift-foundations/swift-executors/Research/executor-main-platform-architecture.md`](../../swift-executors/Research/executor-main-platform-architecture.md)**

## Why the relocation

This document was initially created in `swift-kernel/Research/` while the question was framed as "what does the platform stack need to provide?" Revisions 1–3 iterated through:

- **R1**: `Kernel.Main.Dispatch.async` wrapper at L1+L2 with retained `#if os(...)` in `Executor.Main`.
- **R2**: Per-platform `Kernel.Main.Loop` L2 variants with `internal import Dispatch` + `internal import CoreFoundation` at L2 Darwin.
- **R3**: Uniform L3 condvar pump; scope narrowed to headless-only.
- **R4** (current): Witness-struct dependency inversion; universal scope with `MainActor` coexistence; Apple frameworks as L2 spec-mirror per [PLAT-ARCH-012]; `Executor.MainThread` nested global actor per [API-NAME-001].

R4's reframing made clear that the load-bearing design decisions (scope, witness pattern, Apple-framework layering, global-actor naming) belong to **`Executor.Main`** — the consumer-facing type in `swift-executors`. Per [RES-002a] Research Triage, the research belongs in the superrepo that owns the decisions. The L1/L2/L3 platform-stack contributions (`Kernel.Main` namespace, `Kernel.Main.Loop` witness type, per-platform witnesses, default selector) exist to serve `Executor.Main`.

The full R1→R4 analysis — including analytical-error trails for the superseded revisions — is preserved in the new location.

## Canonical reference

See [`swift-foundations/swift-executors/Research/executor-main-platform-architecture.md`](../../swift-executors/Research/executor-main-platform-architecture.md).

## Historical note

The prior content of this document (~1100 lines across R1/R2/R3 with supersession trails) has been reduced to this stub to prevent divergence from the canonical research. The git history for this file preserves the full R1/R2/R3 trail for anyone wanting to see the interim shapes.
