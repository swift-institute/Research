# File.Handle.writeAll L2→L3 Layering Investigation

Date: 2026-04-22
Scope: cross-package (`swift-iso-9945` + `swift-foundations/swift-posix` + `swift-foundations/swift-kernel`)
Audit findings: P2.2 #1 (`ISO 9945.Kernel.IO.Write.writeAll` body at L2) + P2.2 #11 (`ISO 9945.Kernel.File.Handle.writeAll` cascade)
Status: **OPTIONS MATRIX — decision escalates to principal**

This document surveys options for resolving the `writeAll` L2/L3 layer violation flagged by P2.2 #1 and its File.Handle cascade flagged by P2.2 #11. It does not commit a decision; each recommendation below names what remains for the principal.

## Problem Statement

Two iso-9945 L2 sites host L3 policy code:

- **`swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.IO.Write.swift:145, 220`** — `ISO_9945.Kernel.IO.Write.writeAll(_:from:)` implements a partial-IO `while written < total` loop, calling the L2 raw `write(_:from:)` repeatedly until all bytes land. The loop is L3 policy per [PLAT-ARCH-008e]: "L2 is spec-literal, L3 (swift-posix) is policy-wrapped." Partial-IO is a composed behavior, not a spec-literal syscall.

- **`swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.File.Handle.write.swift:85, 148`** — `Kernel.File.Handle.writeAll(from:)` in L2 iso-9945 delegates to the L2 `ISO_9945.Kernel.IO.Write.writeAll`. Deleting the L2 free function per P2.2 #1 breaks this File.Handle method, creating a cascade.

The parent handoff's four options (a) delete File.Handle.writeAll, (b) inline the partial-IO loop in File.Handle.writeAll (moves policy back to L2 in a different form), (c) let L2 File.Handle.writeAll delegate to L3 swift-posix (upward layer dep, forbidden), (d) relocate File.Handle to L3 entirely — classified the problem as design-blocked and deferred it. This investigation refines the option space based on one material discovery during grep.

## Constraints Inventory

Listing the hard constraints that bound the option space before any option is chosen:

1. **L1 `Kernel.File.Handle` is the type; L2 adds extensions.** `Kernel.File.Handle` is defined at `swift-primitives/swift-kernel-primitives/Sources/Kernel File Primitives/Kernel.File.Handle.swift` — an L1 type. L2 iso-9945 only adds method extensions (`read`, `write`, `close`, `writeAll`). This is the material discovery: the parent handoff's "relocate File.Handle to L3 entirely" is imprecise — the **type** is already L1-neutral; only its L2 method-extensions would relocate. See `rg "public struct Handle" swift-kernel-primitives` → `Kernel.File.Handle.swift:37`-ish, one definition site.

2. **L3 unifier already exists.** `swift-foundations/swift-kernel/Sources/Kernel File/Kernel.IO.Write+CrossPlatform.POSIX.swift:142, 160` defines `Kernel.IO.Write.writeAll(_:from:)` as an L3 unifier that delegates to `POSIX.Kernel.IO.Write.writeAll`. This is the consumer-facing cross-platform entry point on POSIX platforms. The current L2 `ISO_9945.Kernel.IO.Write.writeAll` is advertised via the unifier's doc comment as "raw access (partial-write loop without retry)" — [PLAT-ARCH-008e] catches this: partial-IO is policy, and L2 should not have it even as a "raw" variant.

3. **L3 policy already implements `writeAll` independently.** `swift-foundations/swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.IO.Write.swift:108–132` defines `POSIX.Kernel.IO.Write.writeAll` that calls the L3 `POSIX.Kernel.IO.Write.write` (which has the EINTR retry loop) in its own partial-IO loop. It does NOT delegate to the L2 writeAll — it has its own loop body. So two partial-IO loops coexist (L2 + L3), one of which is the drift.

4. **L2 File.Handle.writeAll's `Either<Error, Kernel.Interrupt>` error shape has a consumer contract.** File.Handle.writeAll throws `Either<Error, Kernel.Interrupt>` — left for domain errors, right for EINTR. This shape is load-bearing for call sites that need to distinguish EINTR from substantive errors. Any replacement must preserve this semantic or explicitly declare the breaking change.

5. **Upward dependencies are forbidden.** L2 cannot delegate to L3. This rules out the parent handoff's option (c) outright.

6. **`@_spi(Syscall) + @inlinable` is structurally incompatible.** Per `swift-institute/Research/Reflections/2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md`: swift-posix's L3 wrappers are `@inlinable` for cross-module specialization; Swift rejects `@inlinable` bodies referencing `@_spi` symbols. This rules out one naive alternative (hide the L2 writeAll via SPI but keep L3 wrappers inlinable).

7. **`.Raw.` sub-namespace is rejected.** Per the same reflection: user explicitly forbade `.Raw.` as a disambiguation namespace on iso-9945. The one prior handoff proposing it is superseded.

8. **Consumer surface: File.Handle.writeAll has in-workspace callers.** `grep -r "File.Handle.*writeAll\|\.writeAll\b.*Handle"` + the in-file delegation sites show the method is used — notably by `swift-foundations/swift-file-system` (multiple sites via `File System Core`), `swift-iso-9945`'s own test helpers, and any downstream consumer that owns a `Kernel.File.Handle` instance. An options-matrix decision that breaks or migrates this surface has non-trivial consumer impact.

## Options Matrix

Five options, each named, shaped, and classified by layer-correctness, consumer impact, and scope:

### Option 1: Delete both L2 writeAll sites; consumers migrate to the L3 unifier `Kernel.IO.Write.writeAll`

**Shape**: Delete `ISO_9945.Kernel.IO.Write.writeAll` (all overloads). Delete `Kernel.File.Handle.writeAll` in iso-9945. Consumers that wrote `handle.writeAll(from: buffer)` migrate to `Kernel.IO.Write.writeAll(handle.descriptor, from: buffer)` via the L3 unifier.

**Pros**:
- Strictest layer separation. L2 is purely spec-literal; policy (partial-IO + EINTR) lives entirely at L3 where it belongs per [PLAT-ARCH-008e].
- No new L3 code needed — the unifier already exists and delegates correctly.
- No upward-dep risk.

**Cons**:
- Breaks the `handle.writeAll(...)` method-call ergonomics. Consumers must switch from `instance.writeAll(...)` method style to `Kernel.IO.Write.writeAll(instance.descriptor, ...)` free-function style.
- Loses the `Either<Error, Kernel.Interrupt>` shape at the method site. The L3 unifier throws `Kernel.IO.Write.Error` (EINTR is retried internally); consumers who depended on EINTR signaling must adjust.
- Non-trivial consumer migration across swift-file-system + any test helpers that call `handle.writeAll(...)`.

**Consumer impact**: Medium to high. swift-file-system and possibly other foundations packages need call-site edits.

### Option 2: Delete L2 free-function writeAll; inline partial-IO loop in L2 `File.Handle.writeAll` body

**Shape**: Delete `ISO_9945.Kernel.IO.Write.writeAll`. Keep `Kernel.File.Handle.writeAll` in iso-9945 L2 but inline the partial-IO loop into its body (calling `ISO_9945.Kernel.IO.Write.write` — the spec-literal L2 write — repeatedly).

**Pros**:
- File.Handle.writeAll surface preserved; `Either<Error, Kernel.Interrupt>` shape preserved.
- No consumer migration.
- Closes P2.2 #1 (L2 free-function writeAll is gone).

**Cons**:
- **Does not close P2.2 #11** — the partial-IO loop (L3 policy) is now at L2 inside File.Handle. The finding's spirit ("L3 policy should live at L3") is not resolved; the policy just moves from one L2 site to another.
- Violates [PLAT-ARCH-008e]'s spirit: L2 should not host policy, even inside a method body.

**Consumer impact**: Zero.

### Option 3: Keep L2 writeAll; re-frame its documentation as "raw partial-IO only, no EINTR retry"

**Shape**: No code changes. Update L2 `ISO_9945.Kernel.IO.Write.writeAll` doc comments to explicitly name it as "raw partial-write loop, no EINTR retry — use `POSIX.Kernel.IO.Write.writeAll` for retry-aware." The current unifier already advertises this "raw access" framing (`Kernel.IO.Write+CrossPlatform.POSIX.swift:134`); Option 3 ratifies the status quo.

**Pros**:
- Zero code disruption. Fastest to ship.
- Preserves all consumer surfaces.

**Cons**:
- **Does not close the audit finding.** P2.2 #1 flags partial-IO at L2 as the violation; the unifier doc's claim that L2 writeAll is "raw access" doesn't change the fact that partial-IO IS policy. Calling it "raw" re-frames the semantics but doesn't move the code.
- Preserves the layer violation; future layer audits re-surface the same finding.
- Contradicts `swift-posix/Research/l3-policy-design.md` (2026-04-10): *"`POSIX.Kernel.IO.Write.writeAll()` is a pure L3 invention — it handles both partial writes and EINTR in a loop. This does not exist at L2."* — the prior ecosystem research explicitly said L2 writeAll should not exist.

**Consumer impact**: Zero.

### Option 4: Relocate ALL File.Handle extensions (read, write, close, writeAll) from L2 to L3

**Shape**: Move `ISO 9945.Kernel.File.Handle.read.swift`, `write.swift`, `close.swift` entirely out of iso-9945 into swift-posix (or a new target). iso-9945 keeps the free-function raw syscalls (`ISO_9945.Kernel.IO.Write.write` etc.) but no File.Handle extensions. Delete L2 IO.Write.writeAll separately (P2.2 #1).

**Pros**:
- File.Handle becomes entirely L3-authored; policy and convenience live together.
- writeAll can freely co-exist with its siblings without layer asymmetry.
- Makes future L3-policy additions on File.Handle (timeouts, async variants, closeAfter) structurally natural.

**Cons**:
- **Over-migration.** File.Handle.read, File.Handle.write, File.Handle.close are each spec-literal single-syscall wrappers with no policy. They match L2's semantics perfectly. Moving them to L3 places spec-literal code at L3, which is the *inverse* of the layer violation we're trying to fix.
- Large cross-package churn. All iso-9945 File.Handle tests move too; downstream consumers that import iso-9945 for File.Handle methods must switch imports.
- Sets a precedent that "types with any L3 method must have all methods at L3," which conflicts with [MOD-008]-style method-level domain decomposition.

**Consumer impact**: High — import chain changes across many packages.

### Option 5: Method-level layer split — iso-9945 (L2) keeps spec-literal methods; swift-posix (L3) adds File.Handle.writeAll as an extension

**Shape**:
- Keep `ISO 9945.Kernel.File.Handle.{read,write,close}.swift` at L2 (spec-literal syscalls — layer-correct).
- Delete `ISO_9945.Kernel.IO.Write.writeAll` (P2.2 #1).
- Delete the `writeAll` method from `ISO 9945.Kernel.File.Handle.write.swift` at L2 (P2.2 #11).
- Add a new file in swift-posix, e.g., `POSIX.Kernel.File.Handle.writeAll.swift`, that opens an extension on `Kernel.File.Handle` (the L1 type) and defines `writeAll(from:)` with the partial-IO + EINTR loop, delegating to `POSIX.Kernel.IO.Write.write` (the already-retry-wrapped L3 raw).

**Pros**:
- **Layer-correct at method granularity.** Each method lives at the layer matching its semantics: spec-literal at L2, policy at L3.
- Preserves `handle.writeAll(from:)` method-call ergonomics for consumers.
- Preserves `Either<Error, Kernel.Interrupt>` shape (the L3 file can define the same shape; `Kernel.Interrupt` is L1 and cross-layer-available).
- Closes both P2.2 #1 and #11 simultaneously.
- Consumers already import swift-posix (which re-exports iso-9945), so they see the full File.Handle surface transitively.
- Matches the method-level split pattern already established by the existing L3 free-function writeAll (`POSIX.Kernel.IO.Write.writeAll`), making File.Handle consistent.

**Cons**:
- File.Handle's method surface splits across two modules (iso-9945 for {read, write, close}; swift-posix for writeAll). Maintainers looking at iso-9945 alone see an incomplete surface; a Research-note pointer in iso-9945's File.Handle source would mitigate this.
- Slight consumer coupling increase: a package that only imported `ISO_9945_Kernel_File` (not `POSIX_Kernel_File`) would lose `writeAll`. Mitigation: check via grep for any such narrow consumers; almost certainly none, since all existing callers import through the `Kernel` unifier.
- `@inlinable` interaction (revised per principal review): the naive claim that "we aren't introducing any SPI-gated symbols" understates the risk. The new L3 `File.Handle.writeAll` body will ultimately reach `descriptor._rawValue` (which IS `@_spi(Syscall)`) through its call chain to `POSIX.Kernel.IO.Write.write` or the raw POSIX write wrapper. If the new extension is marked `@inlinable` for cross-module specialization (matching the existing `Kernel.IO.Write.writeAll` unifier's `@inlinable` pattern), the same trap surfaced in `Research/Reflections/2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md` can fire: `@inlinable` bodies cannot reference `@_spi` symbols across module boundaries. Implementation mitigation: declare the method, compile, verify no "`@inlinable` cannot reference `@_spi`" errors BEFORE committing to the method signature. If the error appears, the fix is either (a) drop `@inlinable` on this specific method (accepting the per-call cost), (b) route through a non-SPI `Kernel.Descriptor` accessor if one exists, or (c) defer to the implementation cycle's design slot. This is an implementation-time pre-check, not a matrix-time blocker, but it is material enough to warrant a dedicated verification step in the implementation-cycle ground rules.

**Consumer impact**: Zero for consumers importing through the `Kernel` or `POSIX_Kernel` umbrella; unknown minor impact for any narrow `ISO_9945_Kernel_File`-only importer (subject to a workspace grep).

## Evidence

### Grep results — prior research per [HANDOFF-013a]

```
$ grep -l writeAll swift-iso/swift-iso-9945/Research/
(none found)

$ grep -l writeAll swift-foundations/swift-posix/Research/
post-modularization-design-notes.md    ← checked, not materially relevant (writeAll appears only in a namespace-depth ergonomics discussion at line 27, unrelated to L2/L3 layer placement)
l3-policy-design.md                    ← highly relevant

$ grep -l "writeAll|File.Handle|IO.Write|partial-IO" swift-institute/Research/
19 hits — 3 materially relevant:
  Reflections/2026-04-20-l2-l3-same-signature-latent-ambiguity.md
  Reflections/2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md
  io-prior-art-and-swift-io-design-audit.md
```

### Prior-research citations

**`swift-posix/Research/l3-policy-design.md` (2026-04-10)** —  explicitly stated that L2 `writeAll` should not exist:

> "L3 adds composed operations. `POSIX.Kernel.IO.Write.writeAll()` is a pure L3 invention — it handles both partial writes and EINTR in a loop. This does not exist at L2." (§POSIX Enum vs Typealias / point 2)

> "EINTR retry for write/pwrite, plus `writeAll()` (a composed operation that handles both partial writes and EINTR — pure L3 value-add with no L2 equivalent)." (§Pattern Across Targets)

The current L2 `ISO_9945.Kernel.IO.Write.writeAll` directly contradicts both claims; it is the drift P2.2 #1 catches.

**`swift-institute/Research/Reflections/2026-04-20-l2-l3-same-signature-latent-ambiguity.md`** — documents the `[PLAT-ARCH-008e]` disambiguation invariant: when L2-raw and L3-unifier methods share a name on the same type (which is the case for `Kernel.IO.Write.writeAll`), the L3 unifier cannot land alongside L2-raw without an explicit disambiguation mechanism. Ruled out: `.Raw.` sub-namespace (user-forbidden), `@_spi` (incompatible with `@inlinable`). Viable for the Read/Write family: import demotion of `ISO_9945_Kernel_File` from swift-posix because the error types live at L1 and swift-posix's public signatures don't reference iso-9945 types. This is referenced in the Ambiguity-family handoff at `swift-kernel/HANDOFF-io-read-write-l2-l3-ambiguity.md`.

**`swift-institute/Research/Reflections/2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md`** — documents the consumer-side impact of the L2/L3 same-signature collision; confirms that the Read/Write error types live at L1 (so the import-demotion mechanism is viable asymmetrically for this family but not for Socket).

### Current-state code citations

- L2 partial-IO site: `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.IO.Write.swift:145` (UnsafeRawBufferPointer overload) and `:220` (Span overload). Body: `while written < total { ... write(descriptor, from: remaining) ... }`.
- L2 File.Handle cascade: `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.File.Handle.write.swift:81–92` (buffer form) and `:144–155` (Span form). Body delegates to `ISO_9945.Kernel.IO.Write.writeAll`.
- L3 retry-wrapped writeAll (L3-correct): `swift-foundations/swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.IO.Write.swift:109–132` (buffer) and `:181–189` (Span). Calls `POSIX.Kernel.IO.Write.write` (with EINTR retry) in a partial-IO loop.
- L3 unifier delegating to POSIX L3: `swift-foundations/swift-kernel/Sources/Kernel File/Kernel.IO.Write+CrossPlatform.POSIX.swift:142, 160`. Marked `@inlinable`.
- L1 type definition: `swift-primitives/swift-kernel-primitives/Sources/Kernel File Primitives/Kernel.File.Handle.swift` (`Kernel.File.Handle` struct).

### Consumer-surface grep

`grep -r "File\.Handle"` across the workspace returned 57 files. Workspace-owned consumers most-relevant to the cascade:

- swift-file-system (`swift-foundations/swift-file-system/Sources/File System Core/`, `File System/`, `File System Primitives/`) — multiple sites reference `File.Handle` and its methods; likely the dominant external caller of File.Handle.writeAll.
- iso-9945's own test helpers and File.Handle tests.
- coenttb/* repos (`coenttb/swift-file-system/*`) — parallel tree, may or may not be in scope for this session's verification.

A verify-consumer-by-consumer grep of explicit `.writeAll(` calls on `File.Handle` instances is warranted before Option 1 or 5 lands; omitted here because the decision itself is escalated and the consumer migration scope will be the next session's verification step.

## Recommendation

**Option 5 — method-level layer split.**

Reasoning:
- It is the only option that closes BOTH P2.2 #1 and P2.2 #11 simultaneously while preserving the `handle.writeAll(from:)` method-call ergonomics and the `Either<Error, Kernel.Interrupt>` error contract.
- It is layer-correct at method granularity: spec-literal syscall wrappers stay L2, partial-IO policy lives L3, matching [PLAT-ARCH-008e] exactly.
- It is consistent with the existing POSIX.Kernel.IO.Write.writeAll pattern — swift-posix already owns the partial-IO+EINTR policy for the free-function form; extending the same discipline to the File.Handle method form is the natural structural move.
- Consumer migration is zero for callers importing through the `Kernel` or `POSIX_Kernel` umbrella (which is essentially all current callers per workspace convention).
- The "File.Handle methods split across two modules" cost is mitigable by a doc-pointer in iso-9945's File.Handle source, and the split is legible: L2 has the spec-literal methods, L3 has the policy method. This matches the ecosystem's broader `L2-spec-literal + L3-policy` narrative.

Option 4 (relocate all File.Handle extensions to L3) is rejected because it over-migrates — read/write/close are correctly L2 and moving them creates an inverse layer violation.

Option 2 (inline the loop in L2 File.Handle.writeAll) is rejected because it relocates the policy rather than fixing it — P2.2 #11's spirit is that L2 methods should not host policy bodies, and moving the partial-IO loop from a free function to a method body is structurally the same violation.

Option 3 (re-frame docs) is rejected because it preserves the violation; the partial-IO loop IS L3 policy by the ecosystem's own design-principle doc and calling it "raw" does not change the layer semantics.

Option 1 (delete both; consumers migrate to unifier) is a live alternative if the principal wants the narrower layer surface and is willing to absorb the consumer migration. Option 5 strictly dominates it only if preserving `handle.writeAll(from:)` ergonomics is valued; if the ergonomics are themselves the target of a future cleanup (e.g., ecosystem-wide "no .method() on primitives, use free functions"), Option 1 becomes the forward-looking choice.

## Open Questions (escalating to principal)

1. **Primary decision**: approve Option 5 (method-level split) as the implementation path, or pick Option 1 (delete both; unifier-only surface)? Option 5 is the recommendation but Option 1 is architecturally simpler if the principal views `handle.writeAll(from:)` ergonomics as non-load-bearing. Other options are rejected above and not revived unless the principal wants to reopen the analysis.

2. **Error shape preservation (conditional on Option 5)**: Option 5 preserves `Either<Error, Kernel.Interrupt>`. The L3 extension can define the same shape because `Kernel.Interrupt` is L1. Is this the right error shape for a new L3 API, or should the L3 File.Handle.writeAll use the plainer `Kernel.IO.Write.Error` that L3 `POSIX.Kernel.IO.Write.writeAll` uses (retry-exhausted as `Error.io(.hardware)`)? Two L3 writeAlls with different error shapes is an ecosystem inconsistency; two convergent error shapes simplifies it. Escalates because it's an API-design choice, not a code-relocation choice.

3. **File.Handle module-boundary split legibility**: Option 5 leaves iso-9945's File.Handle.write.swift with .write and .pwrite methods while the companion .writeAll lives in swift-posix. Would the principal prefer (a) a DocC cross-reference comment in the iso-9945 file pointing to the L3 site, (b) a Research-note per package explaining the split rationale, or (c) both? (This is a documentation-only open question; it does not block the structural decision.)

4. **Consumer migration scope (conditional on Option 1)**: if Option 1 is chosen, the migration of `handle.writeAll(from:)` call sites to `Kernel.IO.Write.writeAll(handle.descriptor, from:)` is mechanical but multi-package (at minimum: swift-file-system, iso-9945 test helpers). Does the principal authorize that as part of the same implementation slot, or as a staged subsequent cycle? Escalates because scope-expansion beyond P2.2 is a session-boundary question.

5. **Verification discipline**: any implementation lands must satisfy `swift build --build-tests` on both macOS AND Linux (Docker swift:6.3.1) — per [PLAT-ARCH-008e]'s disambiguation-invariant sub-rule established at `Research/Reflections/2026-04-20-l2-l3-same-signature-latent-ambiguity.md`: "compiles in isolation" is a false positive for cross-module changes. The Build complete message from swift-kernel alone is not sufficient — test-support target transitively imports both modules and is the canary for ambiguity. Does the principal want this as a hard ground-rule in the implementation cycle's supervise block?

6. **Drive-by observation — consumer-migration grep outstanding**: the consumer-surface inventory above (57 files) has not been filtered to only-the-workspace-owned-callers-of-`handle.writeAll`. Principal may want an exact call-site list (under 30 min of grep work) before the implementation-cycle ground rules lock; flagging as a prep-phase task rather than something to do in this investigation slot.

## Appendix — [SUPER-015] tactical decisions made during investigation

- Chose to grep both involved packages' `Research/` + `swift-institute/Research/` per rule #1; found high-value prior context in `swift-posix/Research/l3-policy-design.md` directly addressing the L3-writeAll-invention question. Documented the prior-state contradiction (the 2026-04-10 doc already said L2 writeAll shouldn't exist; audit P2.2 #1 catches the drift that survived) as evidence rather than re-arguing from scratch.
- Chose to include the `Kernel.File.Handle` L1-type discovery as a Constraint (rather than bury it in Evidence), because it materially reframes parent-handoff option (d) "relocate File.Handle to L3" — the type is already L1-compatible and only extensions move. This changes the option-space shape.
- Chose not to grep-enumerate every `handle.writeAll(` call site in the workspace in this doc (documented as open question #6) because the options matrix does not require the exact call-site list to be decidable; it is load-bearing at implementation time, not at options-matrix time. Principal may redirect.
- Chose not to investigate the `Either<Error, Kernel.Interrupt>` shape's design history for this doc; flagged as Open Question #2 because it is an API-design choice orthogonal to layer-correctness.

## Principal Decisions (2026-04-22)

Principal reviewed Doc 1 after `e871dbe` landed; decisions on the 6 escalated open questions recorded here as the durable artifact for a future implementation cycle. Decisions are binding on any implementation-cycle supervise block that carries forward this investigation.

| # | Question | Decision | Rationale (principal's words, compressed) |
|---|----------|----------|-------------------------------------------|
| 1 | Option 5 vs Option 1 (primary decision) | **Option 5 — method-level layer split.** | Ergonomics preservation is genuine value; Option 1's mass migration across swift-file-system + test helpers is churn explicitly budgeted as "minimum-quality floor," not "migration cycle." Option 5 closes both findings at method granularity — the layer rule cleanly re-asserts. |
| 2 | Error shape for the new L3 `File.Handle.writeAll` — `Either<Error, Kernel.Interrupt>` or plain `Kernel.IO.Write.Error` | **Keep `Either<Error, Kernel.Interrupt>`.** | Preserves the existing File.Handle method contract (consumers already rely on EINTR visibility at the method site). Asymmetry with the free-function `POSIX.Kernel.IO.Write.writeAll` is justified semantically: "method surfaces `Interrupt` for caller; free-function retries internally — pick your abstraction." Convergence to a plain error would be a separate ecosystem-wide API decision, not a P2.2 decision. |
| 3 | Split-legibility aids | **Both.** Short DocC `See Also` cross-reference in iso-9945's `File.Handle.write.swift` pointing to the L3 sibling; one-paragraph Research note per package (swift-posix's existing `l3-policy-design.md` absorbs the update; iso-9945 gets a new short note). | Keeps future-reader friction low. |
| 4 | Consumer-migration scope (Option 1-conditional) | **N/A.** | Option 5 was chosen; Option 5 has zero migration cost for umbrella-importing consumers. Question #4 is moot for the implementation cycle. |
| 5 | Hard ground-rule: `swift build --build-tests` must be clean on both macOS AND Linux Docker (swift:6.3.1) before implementation commits land | **YES, hard ground-rule.** | Per the 2026-04-20 latent-ambiguity reflection: `swift build` clean on macOS alone is a false positive for the L2/L3 ambiguity class this change creates. Must be a named MUST entry in the implementation-cycle supervise block. |
| 6 | Consumer call-site grep timing | **Prep-phase, before implementation-cycle supervise block locks.** | ~30 min task; its result verifies Option 5's "zero migration" claim. Almost certainly no narrow `ISO_9945_Kernel_File`-only importer exists, but verified vs assumed is different. Do not spend a mid-investigation slot on it. |

### Additional risks principal flagged for the implementation cycle

- **`@inlinable` cascade risk in Option 5**: the new L3 `File.Handle.writeAll`'s body will transitively reach `descriptor._rawValue` (which is `@_spi(Syscall)`). Implementation cycle's first act must be: declare the method, compile, verify no "`@inlinable` cannot reference `@_spi`" errors BEFORE committing to the method signature. If the error fires, drop `@inlinable` on this method or route through a non-SPI accessor. Captured in Option 5's revised cons above.
- **Prior-research citation hygiene**: this doc's original Evidence section listed `post-modularization-design-notes.md` as a grep hit without marking it checked-and-not-relevant. Loop closed in the amended Evidence section — the single mention (line 27) is about namespace-depth ergonomics, unrelated to L2/L3 placement. Documentation pattern for future docs: explicitly annotate each grep hit as "materially relevant" OR "checked, not materially relevant (reason)" — silence is ambiguous.

### Forward-looking guidance to Doc 2 and Doc 3

Principal flagged three patterns from Doc 1 to carry into subsequent investigations:

1. **L1-vs-L2 type-location check up-front.** Doc 1's whole pivot was the File.Handle-is-L1 discovery. Doc 2 must run the equivalent diagnostic for `Kernel.Socket.Message.Header` (`rg "public struct Header" swift-primitives/swift-kernel-primitives/`). Doc 3 same for whatever type hosts `siginfo_t`.
2. **Grep consumer packages' own `Research/`.** For msghdr specifically, `swift-foundations/swift-sockets/Research/` is load-bearing because swift-sockets is the package currently consuming these raw-pointer fields via the hand-coded byte-offset hack (surfaced as the drive-by finding in the Session 3 P3.3 #10 work).
3. **Don't stop at the handoff's implicit option count.** Doc 1's Option 5 emerged from pushing past the parent handoff's 4-option framing. Doc 2's handoff framing is implicitly 2-option ("wrap pointer+length in typed ecosystem types or leave alone") — the real space is almost certainly richer (method-level split, shadow-struct + View pattern, per-field typed setters). Push.
