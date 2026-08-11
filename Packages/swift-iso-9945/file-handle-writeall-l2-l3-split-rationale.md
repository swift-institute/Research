# File.Handle.writeAll L2→L3 method-level split rationale

Date: 2026-04-22
Scope: swift-iso-9945 (L2 deletions) + swift-foundations/swift-posix (L3 addition)
Audit findings closed: P2.2 #1 (L2 free-function `writeAll` hosted partial-IO policy), P2.2 #11 (L2 `File.Handle.writeAll` extension cascade)

`ISO_9945.Kernel.IO.Write.writeAll(_:from:)` and the sibling `Kernel.File.Handle.writeAll(from:)` L2 extension are deleted. Partial-IO — looping `write(2)` until all bytes land — is composed behavior, not a spec-literal syscall, and belongs at L3 per `[PLAT-ARCH-008e]` ("L2 is spec-literal, L3 (swift-posix) is policy-wrapped"). The method-level layer split preserves consumer ergonomics (`handle.writeAll(from:)` still reads the same at call sites) and the `Either<Error, Kernel.Interrupt>` error contract (`Kernel.Interrupt` is L1 and cross-layer-available). The L3 replacement lives in swift-posix as `extension Kernel.File.Handle { public borrowing func writeAll(from:) }` on the L1 `Kernel.File.Handle` type, delegating to the already-retry-wrapped L3 `POSIX.Kernel.IO.Write.write` in a partial-IO loop. iso-9945 keeps its spec-literal `.write` / `.pwrite` File.Handle methods — they match L2's spec-literal-syscall mandate — so the split is at method granularity, not type granularity.

## Cross-references

- Option-matrix investigation and principal decisions: [`swift-institute/Research/file-handle-writeall-l2-l3-layering.md`](../../../swift-institute/Research/file-handle-writeall-l2-l3-layering.md) — decisions binding at commit `d20d91b` (Option 5 chosen over Options 1–4; `Either<Error, Kernel.Interrupt>` preserved; both split-legibility aids required; Linux Docker `--build-tests` hard gate).
- POSIX-side cascade rationale: [`swift-foundations/swift-posix/Research/l3-policy-design.md`](../../../swift-foundations/swift-posix/Research/l3-policy-design.md) — extended in the Phase 2 commit of this cycle with the File.Handle.writeAll cascade paragraph; the prior `POSIX.Kernel.IO.Write.writeAll()` entry already documented the free-function form as "a pure L3 invention … no L2 equivalent."
- Cycle-3 implementation handoff (verification stamp): `swift-institute/Audits/HANDOFF-cycle-3-file-handle-writeall.md`.
