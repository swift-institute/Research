# Signal.Action.Handler siginfo_t L2 Wrapper Design

Date: 2026-04-22
Scope: package-local (`swift-iso-9945` Signal target); no cross-package consumers in workspace
Audit finding: P2.3 #3 — `Signal.Action.Handler.customInfo` leaks `UnsafeMutablePointer<siginfo_t>?` + `UnsafeMutableRawPointer?` (ucontext_t) in its C-callback case; no typed ecosystem wrapper for siginfo_t exists.
Status: **OPTIONS MATRIX — decision escalates to principal**

This document surveys options for eliminating the `siginfo_t` C-type leak in the signal-handler case of `Kernel.Signal.Action.Handler`. The surface question is "add a typed wrapper"; the real design centers on the union-discriminated `si_code` dispatch and the async-signal-safety constraint that limits what typed work can happen inside a handler context. The doc does not commit a decision; recommendation escalates.

## Problem Statement

`swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Action.Handler.swift:84` defines:

```swift
case customInfo(@convention(c) (Int32, UnsafeMutablePointer<siginfo_t>?, UnsafeMutableRawPointer?) -> Void)
```

Two leaks:

1. `UnsafeMutablePointer<siginfo_t>?` — `siginfo_t` is a C type from `<sys/signal.h>` (Darwin) or `<signal.h>` (Glibc/Musl). Direct [PLAT-ARCH-005a] violation — public API surface carries a platform C type.
2. `UnsafeMutableRawPointer?` (the third parameter) — `ucontext_t*`, raw pointer. Per Doc 2's ratified [PLAT-ARCH-005a] clarifying sub-rule, a bare `UnsafeMutableRawPointer?` in a public function/callback signature — not wrapped in an ecosystem-typed struct — is non-compliant.

Adjacent issue (flagged as drive-by): `Handler.swift:14-20` has `public import Darwin` / `public import Glibc` / `public import Musl`. This propagates platform headers into the L2 public surface. It predates the P2.3 #4 sweep (which converted analogous imports elsewhere to `internal import`) and remains a separate layering concern.

The audit's own framing at `platform-compliance-2026-04-21.md` Pattern 2 list: *"Finding #3: `Signal.Action.Handler` `siginfo_t` L2 wrapper design — NEEDS siginfo_t ecosystem type; multi-file design work."* Principal guidance: "union-typed discriminator is the design center, not the layering question."

## Constraints Inventory

1. **siginfo_t is L2-exclusive (no L1 analog).** `rg "public struct Information|Signal.Information|siginfo_t"` in `swift-kernel-primitives/Sources` returned zero hits. Similar to Doc 2's Message.Header result; Doc 1's L1-enabled method-level split does not apply.

2. **C ABI is irreducible at the handler entry point.** The kernel invokes the handler via a C function pointer with signature `(int, siginfo_t*, void*)`. Any typed wrapper has to either (a) accept the raw pointers at the C-ABI boundary and convert INSIDE the handler, or (b) replace the handler-case entirely with a higher-level abstraction that avoids the C entry point (bridging to a non-handler Swift-safe context — Option 4 below).

3. **Async-signal-safety constraint.** Signal handlers run in a restricted context: allocation (Swift or C), mutex/lock operations, most libc calls, and Swift runtime calls (including closure dispatch) are all async-signal-UNSAFE. This means ANY typed-wrapper work inside the handler is tightly bounded — construction of a typed view from a raw `siginfo_t*` MUST NOT allocate, call into Swift runtime beyond primitive ops, or take locks. Layout-compatible value-typed views (like `Kernel.Socket.Address.Storage`'s cValue-based wrapping) are safe; enum construction with associated values is NOT safe if it involves heap allocation; closure invocation is generally unsafe.

4. **si_code union-discriminated content.** The `siginfo_t` struct is a C union dispatched on `si_code`:
   - `SI_USER` / `SI_QUEUE`: sender is a user process — `si_pid`, `si_uid`, (for QUEUE) `si_value`.
   - `SI_TIMER` / `SI_MESGQ` / `SI_ASYNCIO`: kernel subsystem source — various fields.
   - `SIGCHLD`-specific codes (`CLD_EXITED`, `CLD_KILLED`, …): `si_pid`, `si_uid`, `si_status`, `si_utime`, `si_stime`.
   - `SIGSEGV` / `SIGBUS`: fault info — `si_addr`, `si_addr_lsb` (Linux only).
   - `SIGFPE` / `SIGILL` / `SIGTRAP`: fault info — `si_addr` + specific sub-codes (`ILL_ILLOPC`, `FPE_INTDIV`, …).
   - `SIGIO` / `SIGPOLL`: `si_band`, `si_fd`.
   - Platform-specific codes (Darwin has `SI_USER` + a handful; Linux has a much richer catalog).

   A typed Swift representation has to model this dispatch, and the model's shape is the central design question — NOT whether we add a typed view at all.

5. **Platform layout variance.** `siginfo_t` on Darwin is 104 bytes; on Linux it's 128 bytes; the internal union member layout differs between Darwin (field-named union) and Linux (positional `__pad`/`_sifields` layout). A layout-compatible Swift struct with `internal var cValue: siginfo_t` inherits the platform-appropriate layout automatically (matches `Kernel.Socket.Address.Storage` precedent with `sockaddr_storage`), but typed accessors DISPATCHING on si_code are platform-conditional — Darwin's fault info is in `si_addr` / `_reason`, Linux's is in `_sifields._sigfault.si_addr`.

6. **No prior-art typed discriminator in ecosystem.** `rg "Signal.Information.Code"` + sibling patterns across `swift-primitives` returned nothing. Design is fresh — there's no existing enum + associated-values `Signal.Information` structure to align with. The principal's forward-looking guidance ("check swift-signals / iso-9945's own Signal target for precedent") confirms this via source inventory: 13 Signal files, none typing siginfo content.

7. **Ecosystem types available** for typed siginfo-field representation:
   - `Kernel.Process.ID` (L1, at `swift-kernel-primitives/Sources/Kernel Process Primitives/Kernel.Process.ID.swift`) — natural typing for `si_pid`.
   - `Kernel.User.ID` (L1, at `Kernel.User.swift`) — natural typing for `si_uid`.
   - `Kernel.Signal.Number` (L2, at `ISO 9945 Core/ISO 9945.Kernel.Signal.Number.swift`) — typing for `si_signo` though the handler already receives signo as `Int32` first param.
   - `Kernel.Memory.Address` — natural typing for `si_addr` (fault address).
   - No current typing for `si_code` values — would need a new `Kernel.Signal.Information.Code` enum.
   - No current typing for `si_value` (`sigval` union of int/pointer) — would need a new type.

8. **Handler file's `public import Darwin/Glibc/Musl` is a separate but adjacent concern.** Not in P2.3 #3's strict scope but impossible to ignore while redesigning the Handler surface — any option that changes Handler's signature affects this too. Flagged as Open Question for in-cycle cleanup.

9. **Ecosystem direction (principal ratified 2026-04-22)**: prefer `Span` / stdlib-buffer types over raw pointers where possible; strict [API-NAME-002] no-compound-identifiers on proposed names. This rules out proposing names like `senderProcess`, `childExit`, `userDefined` for si_code enum cases — nested forms only.

## Options Matrix

Five options, spanning from minimum-change to full redesign. Per Doc 2 pattern, Options 1' (refined minimum-change), 2 (helper-utility without signature change), 3 (full enum-mapped typed view), 4 (L3 event-bridge avoiding handler-context), 5 (codify current state).

### Option 1: Typed layout-compatible `Kernel.Signal.Information` struct; Handler.customInfo signature changes to typed pointer

**Shape**:
- Add `Kernel.Signal.Information` struct at iso-9945 `ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Information.swift`. `@unchecked Sendable`, `internal var cValue: siginfo_t`. Layout-compatible, matches `Kernel.Socket.Address.Storage` precedent.
- Typed public accessors: `.number: Kernel.Signal.Number`, `.sender: Process?` (computed from `si_pid` when set), `.fault: Fault?` (`si_addr` when si_code indicates fault), etc. Each accessor reads `cValue` fields directly and conditionalizes on si_code where needed.
- Change Handler.customInfo to:
  ```swift
  case customInfo(@convention(c) (Int32, UnsafeMutablePointer<Kernel.Signal.Information>?, UnsafeMutableRawPointer?) -> Void)
  ```
- `UnsafeMutablePointer<Signal.Information>` is bit-compatible with `UnsafeMutablePointer<siginfo_t>` (both are just pointer values; the kernel passes the same bytes; Swift sees the typed view). Matches Doc 2's Vector.Segment-typed-pointer pattern.
- ucontext_t stays `UnsafeMutableRawPointer?` — typed ucontext_t wrapper is out of scope (rarely used by handlers; would require its own platform-variance mapping).

**Pros**:
- Eliminates the siginfo_t leak from Handler's public signature.
- Uses the layout-compatible-wrapper pattern already ratified by Doc 2 (Q2 ruling) and precedent (Storage, Vector.Segment).
- Consumer code inside the handler can access typed fields directly: `infoPtr?.pointee.number`, `infoPtr?.pointee.sender?.id`, `infoPtr?.pointee.fault?.address`.
- Layout-compatibility means the kernel's siginfo_t bytes are re-typed without copy; no allocation inside the handler (async-signal-safe).

**Cons**:
- Does NOT address si_code's union-discriminated content model — the accessor pattern returns `Optional` typed values, which flattens the discrimination to "is this field meaningful for this si_code?" rather than an enum dispatch. Consumers still have to know which accessors to call for which signal. This is the honest cost of staying close to the C shape.
- Platform conditionals leak INTO the Signal.Information accessors — `.fault` reads `cValue.si_addr` on Darwin vs. `cValue._sifields._sigfault.si_addr` on Linux. Each accessor becomes `#if canImport(Darwin)` / `#elseif` / `#endif`. Not a cleanliness win for the implementation, though the public surface stays uniform.
- ucontext_t stays as a raw pointer — doesn't fully close the finding.
- Adjacent `public import Darwin/Glibc/Musl` unchanged (but Handler no longer exposes siginfo_t so the `public` on those imports is harder to justify post-fix; Option 1 sets up a follow-up demotion).

**Consumer impact**: Low. Existing consumers with `@convention(c) (Int32, UnsafeMutablePointer<siginfo_t>?, ...) -> Void` handlers must change the signature; if they don't read the second parameter, no other change. If they DO read siginfo_t fields, they switch to `Kernel.Signal.Information` accessors.

### Option 2: Keep raw Handler.customInfo signature; add `Signal.Information` view as a helper utility

**Shape**:
- Add `Kernel.Signal.Information` struct as in Option 1, layout-compatible with siginfo_t, with typed accessors.
- Handler.customInfo signature UNCHANGED (still takes `UnsafeMutablePointer<siginfo_t>?`).
- Consumers inside their handler write: `let info = Signal.Information(unsafeBitCast(infoPtr, to: UnsafeMutablePointer<Signal.Information>.self))` or similar, to get typed access from the raw pointer.

**Pros**:
- Zero breaking change to Handler's signature — existing handlers continue compiling.
- Provides typed access to consumers who want it.
- Closes the "no typed ecosystem type for siginfo" half of the finding.

**Cons**:
- Does NOT close Handler's public siginfo_t leak — P2.3 #3 as written flags the LEAK; Option 2 ratifies the leak and only adds an adjacent helper. This is Option 5-lite.
- Per Doc 2's Q2 ruling, the Handler.customInfo's direct `UnsafeMutablePointer<siginfo_t>?` in a function-parameter position (as opposed to a struct-field position) is non-compliant with [PLAT-ARCH-005a] — the clarifying sub-rule specifically called out "function parameters / returns / generic constraints" as the uncompliant case.
- Consumers have to know to use `Signal.Information` instead of reading siginfo_t directly — the compliant path is not the natural one.

**Consumer impact**: Zero.

### Option 3: Enum-mapped typed Information.Content + value-semantic handler dispatch

**Shape**:
- Add `Kernel.Signal.Information` struct (layout-compatible with siginfo_t, as in Options 1 and 2).
- Add `Kernel.Signal.Information.Content` enum with associated values discriminated on si_code:
  ```swift
  extension Kernel.Signal.Information {
      public enum Content {
          case `default`        // no typed info
          case user(User)       // SI_USER / SI_QUEUE — sender process + uid + value
          case fault(Fault)     // SIGSEGV / SIGBUS / SIGILL / SIGFPE — address + reason
          case child(Child)     // SIGCHLD — sender + status
          case io(IO)           // SIGIO / SIGPOLL — band + fd
          case timer(Timer)     // SI_TIMER — timer id + overrun
          // … more per spec …
      }
  }
  extension Kernel.Signal.Information.Content {
      public struct User { public let sender: Kernel.Process.ID, owner: Kernel.User.ID, value: Value }
      public struct Fault { public let address: Kernel.Memory.Address, reason: Reason }
      public struct Child { public let sender: Kernel.Process.ID, owner: Kernel.User.ID, status: Status }
      public struct IO { public let band: Band, descriptor: Kernel.Descriptor }
      public struct Timer { public let id: Timer.ID, overrun: Int32 }
      // …
  }
  ```
- Handler.customInfo signature changes to use typed pointer (like Option 1): `@convention(c) (Int32, UnsafeMutablePointer<Signal.Information>?, UnsafeMutableRawPointer?) -> Void`.
- `Signal.Information.content: Content` accessor dispatches on `cValue.si_code` and builds the appropriate typed case.

**Pros**:
- Fully models siginfo_t's union-discriminated content in Swift's type system. Consumers get exhaustive switch discrimination: `switch info.pointee.content { case .child(let c): … case .fault(let f): … }`.
- Aligns with the ecosystem's modern-Swift direction (enum + associated values for union types). Strongest push against the "move away from unsafe / pointer code where possible" principal steer.
- All proposed names are single-concept per strict [API-NAME-002]: `User`, `Fault`, `Child`, `IO`, `Timer`, `.sender`, `.owner`, `.address`, `.reason`, `.status`, `.band`, `.descriptor`, `.id`, `.overrun`. No compound identifiers.
- Consumer-facing interface: `info.pointee.content` is safe-ish (no allocation for enum+associated-values construction of fixed-size cases), BUT — CRITICAL CONSTRAINT — the `.content` accessor's implementation DOES dispatch on si_code to construct a new enum value. In async-signal-safe context, this must be verified: enum with associated values typically stores payload inline for small cases, heap-allocates for large cases. `User` / `Fault` / `Child` are small value types — likely inline. But this must be tested (Constraint #3).

**Cons**:
- **Async-signal-safety verification required.** `info.pointee.content` does work inside the handler; that work's safety depends on Swift enum construction semantics, which are compiler-version-dependent and not formally spec'd for signal-handler use. Verification via minimal experiment is MANDATORY before shipping. If construction allocates, Option 3 is structurally wrong for the handler-context use case and collapses to Option 4 (bridge out of the handler).
- **Platform dispatch pervades the accessor.** The `content` accessor reads si_code from `cValue` and dispatches on platform-specific code values. Each si_code case requires `#if canImport(Darwin)` / `#elseif` branches for cases where Darwin and Linux have different constants. Implementation effort is substantially larger than Options 1 and 2.
- **Additional types add surface.** `Content.User`, `Content.Fault`, `Content.Child`, etc., plus their sub-types (`Reason`, `Status`, `Value`, `Band`, `Timer.ID`) — ~8–12 new types. Tracker cost not trivial.
- **Platform variance in coverage.** Linux's si_code catalog is richer than Darwin's; cross-platform `Content` enum either (a) supports the union of all platforms (some cases will be Linux-only), (b) supports the intersection (loses Linux-specific dispatch precision), or (c) is platform-specific (different `Content` on different platforms — bad for cross-platform code). Principal ruling required.
- If si_code's value doesn't match any known case, `Content` needs a fallback (probably `.default` or `.platform(rawCode: Int32)`).

**Consumer impact**: Medium-high. Handler.customInfo signature change (same as Option 1). Users who adopt `.content` dispatch get exhaustive switch; users who don't still get Option 1-level typed access.

### Option 4: @_spi(Syscall) demote Handler.customInfo + L3 event-bridge high-level API

**Shape**:
- L2 iso-9945: Handler.customInfo demoted to `@_spi(Syscall)`. Raw C-callback stays available for power users but hidden from the default public surface.
- L3 (swift-posix or a new target): high-level signal-handling API that bridges the async-signal-safe handler to a Swift-safe caller context. Pattern:
  ```swift
  let source = try POSIX.Kernel.Signal.source(for: .user1)
  for await info in source {
      // info is Signal.Information (typed); async-signal-safe concerns don't apply here
      switch info.content { … }
  }
  ```
  Implementation: the L3 API installs a signal-safe C handler that writes a serialized siginfo_t to a pipe/eventfd. The pipe is read from the async iteration side where typed views and closures are safe.
- Ability to use `Signal.Information.Content` enum (Option 3's model) in the Swift-safe context.

**Pros**:
- **Eliminates the async-signal-safety constraint from the consumer.** Typed Swift code runs in the safe caller context; only the minimal C handler runs in the unsafe signal context.
- Most principled layering: L2 is spec-literal C callback; L3 is ergonomic Swift event source. Matches [PLAT-ARCH-008e]'s L3-policy-over-L2-spec pattern.
- Consumers get typed enum dispatch + exhaustive switch WITHOUT the Option 3 allocation-inside-handler concern.
- Aligns with modern Swift (AsyncSequence, structured concurrency).

**Cons**:
- **Largest scope.** New L3 API + new iso-9945 SPI-gating + pipe/eventfd infrastructure + AsyncSequence plumbing. Not a P2 remediation — this is a weeks-scale design cycle.
- Doesn't fit audit-finding-P2.3-#3's strict scope (which asks for a typed siginfo wrapper, not a new high-level API).
- Eventfd/pipe-based signal-info relay has its own nuances: siginfo_t data loss on buffer overflow, ordering, close-on-exec, etc. Design work.
- SPI cascade for Handler.customInfo re-export propagation (~13 files per Doc 2's precedent).
- Does not retire the Handler.customInfo C-ABI concern if power users still reach for the SPI escape hatch.

**Consumer impact**: Very high for consumers using customInfo; near-zero for new code that adopts the L3 event API.

### Option 5: Codify current state + add thin typed-view helper (document-only fix)

**Shape**:
- Keep Handler.customInfo signature as-is.
- Add `Kernel.Signal.Information` struct as a typed-view helper (layout-compatible wrapper; typed accessors). Matches Option 2 but framed as closure.
- Doc + tracker clarifying sub-rule: "handler-case parameters with C-ABI-required signatures are exempt from [PLAT-ARCH-005a] Pattern 2 because the kernel's C calling convention is irreducible at the handler entry point. Typed access is provided via the `Kernel.Signal.Information` helper utility."
- Similar to Option 4 of Doc 2 (codify-current-state) but with an accompanying typed-view utility.

**Pros**:
- Zero breaking change.
- Acknowledges the C-ABI constraint that Options 1/3/4 work around rather than eliminate.
- The clarifying sub-rule prevents re-opens on the same grounds.

**Cons**:
- Weakest interpretation of [PLAT-ARCH-005a]. Doc 2's Q2 ruling specifically said direct `UnsafeMutableRawPointer?` in parameter position is non-compliant — Handler's `UnsafeMutablePointer<siginfo_t>?` + `UnsafeMutableRawPointer?` in its case's @convention(c) signature is structurally identical.
- Codifying the exemption opens a loophole future audits will exploit — "my handler C callback also needs this raw-pointer leak."
- Doesn't advance the ecosystem toward the "modern Swift" direction principal indicated.

**Consumer impact**: Zero.

## Evidence

### Grep results — prior research per [HANDOFF-013a]

```
$ rg -l "siginfo|Signal.Information|async-signal-safe|SA_SIGINFO" swift-iso/swift-iso-9945/Research/
socket-message-header-typed-pointer-fields.md    ← Doc 2 (self-hit, skip)
iso-9945-spec-coverage-gap-analysis.md            ← checked, not materially relevant (spec-coverage tracking lists Signal.Action.Handler as a target but does not discuss siginfo_t wrapping design)

$ rg -l "siginfo|Signal.Information|async-signal-safe|SA_SIGINFO|Signal.Action.Handler" swift-institute/Research/
file-handle-writeall-l2-l3-layering.md           ← Doc 1 (self-hit, skip)
Reflections/2026-04-12-io-uring-escapable-coroutine-discovery.md   ← checked, not materially relevant (covers ~Escapable for io_uring coroutines; no siginfo application)
```

No prior design research on siginfo_t typed wrappers. Fresh territory; options matrix is the first systematic survey.

### Current-state code citations

- **Handler definition**: `ISO 9945.Kernel.Signal.Action.Handler.swift:54-85` — `@unsafe public enum Handler: Sendable` with four cases; `customInfo` is the leak site at line 84.
- **Adjacent concern**: `Handler.swift:14-20` — `public import Darwin/Glibc/Musl`. Exposes platform headers through the Signal.Action.Handler type.
- **Serialization**: `ISO 9945.Kernel.Signal.Action.swift:109-153` — `sigaction init(_ configuration: Configuration)` switches on `configuration.handler` to wire the right `sa_handler` / `sa_sigaction` slot per platform.
- **Deserialization**: `Signal.Action.swift:158-208` — reverse mapping; reads flags to detect SA_SIGINFO, picks `__sa_sigaction` pointer, wraps in `.customInfo`.

### Type-location diagnostic (Doc 2/3 pattern)

`rg "public struct Information|Signal.Information|siginfo_t"` in `swift-primitives/swift-kernel-primitives/Sources` returned zero hits. siginfo_t and all Signal types are L2-exclusive.

### Ecosystem types available for typed siginfo-field representation

- `Kernel.Process.ID`: L1, `swift-kernel-primitives/Sources/Kernel Process Primitives/Kernel.Process.ID.swift`.
- `Kernel.User.ID`: L1, `swift-kernel-primitives/Sources/Kernel Process Primitives/Kernel.User.swift`.
- `Kernel.Signal.Number`: L2, `swift-iso-9945/Sources/ISO 9945 Core/ISO 9945.Kernel.Signal.Number.swift`.
- `Kernel.Memory.Address`: L1 (via `swift-primitives/swift-memory-primitives`).
- `Kernel.Descriptor`: L1 (for `si_fd` on SIGIO/SIGPOLL).

No existing `Signal.Information.Code` typed discriminator — would be new.

### Platform variance — siginfo_t layout

- Darwin: 104 bytes, named union `_si_code`-keyed.
- Linux: 128 bytes, `_sifields` positional union.
- Options-matrix impact: any option accessing siginfo_t fields beyond the common `si_signo`/`si_code`/`si_errno` preamble must dispatch on platform.

## Recommendation

**Option 1 + incremental path to Option 3.**

Reasoning:
- Option 1 is the minimum-change path that closes P2.3 #3's core complaint: eliminating `UnsafeMutablePointer<siginfo_t>?` from Handler.customInfo's public signature while preserving C-ABI compatibility via the layout-compatible-wrapper pattern (Doc 2 precedent, Kernel.Socket.Address.Storage, Kernel.IO.Vector.Segment).
- Option 1's `Kernel.Signal.Information` struct provides the typed-accessor substrate. An Option 3-style `.content` enum can be added LATER as a second cycle without re-breaking Handler's signature — it becomes an additive enrichment of the typed view.
- Option 3 on its own requires async-signal-safety verification of enum-with-associated-values construction that I have not been able to guarantee from reading alone. Principal guidance is "move away from unsafe / pointer code where possible" — enum-with-associated-values is more modern-Swift than Optional accessors, BUT Option 3's allocation uncertainty in a handler context is exactly the class of risk the ecosystem should not take without empirical verification. Option 1 ships the foundation; Option 3 can land on top once verification is done.
- Option 4 (L3 event-bridge) is architecturally right for the modern-Swift direction but is a weeks-scale design cycle — wrong mass for a P2 remediation. Flag as a follow-up cycle, not the current remediation.
- Option 2 (helper utility without signature change) is rejected — Doc 2's Q2 ruling explicitly said function-parameter-position `UnsafeMutableRawPointer?`/`UnsafePointer<C>?` is non-compliant. Option 2 ratifies the non-compliant surface.
- Option 5 (codify + helper) is rejected for the same reason, plus it codifies a loophole future audits will exploit.

**Staging recommendation**: land Option 1 in this cycle as P2.3 #3's primary remediation. Follow up with Option 3's `.content` enum in a dedicated cycle that (a) empirically verifies async-signal-safe construction, (b) resolves platform-variance coverage (union-of-all-platforms vs intersection vs platform-specific), (c) models the full si_code catalog with appropriate ecosystem types.

**Drive-by concern** (separate from the options): Handler.swift's `public import Darwin/Glibc/Musl` at lines 14–20 is non-compliant for the same reason any `public import` of platform headers is — it leaks the full platform surface. With Option 1 landed, the Handler's only platform dependence is the `siginfo_t` layout through `cValue`, which is an implementation detail. These imports can be demoted to `internal import` as a follow-up edit in the same cycle. Not strictly P2.3 #3, but the same layering concern and the edits are localized to the same file.

## Open Questions (escalating to principal)

1. **Primary decision**: approve Option 1 (minimum-change foundation, Option 3 as follow-up) OR Option 3 (full enum-mapped typed view in this cycle, with async-signal-safety verification step added as a ground-rule for the implementation) OR Option 4 (L3 event-bridge, deferred as weeks-scale)? Option 1 is the recommendation; Option 3 is the strict-modern-Swift choice if async-signal-safety verifies; Option 4 is the architecturally-right-but-large-mass choice.

2. **Async-signal-safety verification discipline** (Options 1 and 3-conditional): should the implementation cycle include a mandatory async-signal-safety experiment — install the typed handler, trigger SIGSEGV under a controlled test, verify no allocation occurs? The experiment is ~half-day scope. Without it, Option 1's typed-accessor claim is plausible but unverified. Principal decision: require, recommend, or skip?

3. **Platform-variance coverage model** (Option 3-conditional): if Option 3 or its follow-up proceeds, how should the `Signal.Information.Content` enum handle Linux-exclusive si_code cases (e.g., `SI_TKILL`, `BUS_MCEERR_AR`)? Three shapes: (a) union-of-all-platforms — some cases are always synthesized as `.default` on platforms where they don't exist; (b) intersection — only cross-platform cases, Linux-only variants fall into `.platform(rawCode: Int32)`; (c) platform-specific `Content` — different enum on different platforms (breaks cross-platform consumers). Principal ruling needed.

4. **ucontext_t parameter treatment**: Options 1 and 3 keep `UnsafeMutableRawPointer?` for the third ucontext_t parameter. Is this acceptable given Doc 2's Q2 ruling (function-parameter-position raw pointers are non-compliant)? The ucontext_t ecosystem type doesn't exist and is extremely rarely used. Options: (a) leave as `UnsafeMutableRawPointer?` with docstring acknowledging the narrow-use gap (practical), (b) define `Kernel.Signal.Information.Context` as a typed opaque wrapping `ucontext_t` in the same style as Signal.Information (consistent), (c) drop the third parameter entirely from customInfo — a typical signal handler ignores it (narrows the API). Principal decision on API shape.

5. **Drive-by concern — `public import Darwin/Glibc/Musl` in Handler.swift**: should this be part of the same cycle, or a separate P2.3 follow-up? It's structurally one edit; mechanically it's `public import` → `internal import`. Recommendation: bundle into Option 1's implementation cycle (same file, same concern, additive). Principal ruling.

6. **Naming — should `Signal.Information` be `Kernel.Signal.Information` or `Kernel.Signal.Action.Information`?** The type describes siginfo_t, which is not strictly tied to Action (it's passed to any SA_SIGINFO handler, not just to Action). Placing under Signal.Action couples it to one use site; placing directly under Signal is broader but may imply it's the information about the signal itself (which is partially true). Precedent: `Kernel.Socket.Message.Header` is directly under `.Message`, not under `.Send` or `.Receive`. By analogy, `Kernel.Signal.Information` under `.Signal` is the right home. Confirm?

7. **Option 1's typed-pointer on Handler.customInfo — layout concern**: unlike Doc 2's Name case (where `UnsafeMutablePointer<Storage>` was UB over a 16-byte sockaddr_in allocation), siginfo_t is always allocated as siginfo_t (kernel populates a full siginfo_t, not a narrower type). So `UnsafeMutablePointer<Signal.Information>` over a siginfo_t allocation is size-stride-equal and sound. Confirm this reasoning is correct or flag a layout concern I'm missing?

## Appendix — [SUPER-015] tactical decisions made during investigation

- Ran L1-vs-L2 diagnostic per principal's Doc 3 forward-looking guidance #1; confirmed siginfo_t / Signal.Information is L2-exclusive. Recorded as Constraint #1 and noted parallel to Doc 2.
- Framed Constraint #3 (async-signal-safety) as a load-bearing constraint for Option 3 specifically because the principal's guidance about "union-discriminator is the design center" runs directly into the handler-context limitation. The tension between "modern-Swift enum dispatch" and "runs in async-signal-unsafe context" is surfaced in Option 3's cons AND in Open Question #2.
- Applied strict [API-NAME-002] no-compound-identifiers per principal's direction #5: proposed names `User`, `Fault`, `Child`, `IO`, `Timer` as Content sub-cases (not `senderInfo`, `faultInfo`, `childStatus`); sub-struct fields `.sender`, `.owner`, `.address`, `.reason`, `.status`, `.band`, `.descriptor` (not `senderId`, `senderUid`, `faultAddress`, `statusCode`). Nested accessors only.
- Did NOT model the full si_code catalog in the doc — Option 3's union would need ~15–20 cases each with a sub-struct; deferred to the dedicated Option 3 implementation cycle to keep this doc within the 200–500-line target. Open Question #3 escalates the cross-platform coverage question that the full catalog would resolve.
- Flagged the adjacent `public import Darwin/Glibc/Musl` concern as a drive-by observation and Open Question #5 — principal's Doc 2 guidance on "no silent scope expansion" applies; bundling is proposed, not assumed.
- Applied the principal's "Span / stdlib-buffer over unsafe / pointer code" direction by considering `Span<UInt8>` for siginfo_t in Option 3's concepts — rejected because `Span` is `~Escapable` and the handler receives a pointer whose lifetime isn't scope-bound in the Swift sense. The layout-compatible struct (Kernel.Signal.Information) is the right shape for a fixed-size-layout C struct; Span fits variable-length byte buffers, which siginfo_t is not.

## Principal Decisions (2026-04-22)

Principal reviewed Doc 3 after `fd88ab4` landed; decisions on the 7 escalated open questions recorded here as the durable artifact. Decisions are binding on any implementation-cycle supervise block that carries forward this investigation.

| # | Question | Decision | Rationale (principal's words, compressed) |
|---|----------|----------|-------------------------------------------|
| 1 | Option 1 staged vs Option 3 now vs Option 4 defer | **Option 1 staged.** | Foundation + typed accessors lands now; Option 3's `.content` enum lands as a follow-up cycle after empirical async-signal-safety verification. Option 4 (L3 AsyncSequence event bridge) deferred as weeks-scale. |
| 2 | Async-signal-safety verification discipline | **Recommended for Option 1, required for Option 3.** | Option 1's typed-accessor pattern matches existing layout-compatible wrappers (Socket.Address.Storage, Vector.Segment) which don't allocate — low risk. Option 3 introduces enum construction whose compiler-version-dependent codegen IS the risk. If/when Option 3 ships, the verification experiment is a blocking prerequisite with explicit pass criteria (see Weakness #1 addition below). |
| 3 | Platform-variance coverage (Option 3-conditional) | **Union-of-all-platforms with Linux-only cases marked.** | Cross-platform consumers get the richer Linux catalog as valid enum cases that just never fire on Darwin; Darwin-only consumers switch over the subset that fires for them. Intersection loses Linux-precision; platform-specific breaks portability. Union is the standard enum shape for platform-discriminated unions in the ecosystem. |
| 4 | ucontext_t parameter treatment | **Option (a) — leave as `UnsafeMutableRawPointer?` with docstring acknowledging narrow-use exception. Option (c) "drop entirely" to be investigated as a separate follow-up.** | Option (c) is tempting but needs ABI-soundness verification — can Swift declare a 2-arg `@convention(c)` function type and have the runtime invoke it from a 3-arg sigaction slot? This needs a minimal test before committing. Option (b) "wrap in typed opaque" adds surface for minimal value (ucontext_t is rarely used). Start with (a); investigate (c) as a separate follow-up. See expanded analysis below (Weakness #3). |
| 5 | Drive-by `public import Darwin/Glibc/Musl` bundle | **YES, bundle with Option 1's implementation cycle.** | Same file, same structural concern; the Handler redesign changes this file anyway. Demoting `public import` → `internal import` is additive to the Option 1 edit. Not scope expansion — coherent completion of the Handler.swift file's layering. |
| 6 | Naming: `Kernel.Signal.Information` broad vs `Kernel.Signal.Action.Information` Action-coupled | **Broad: `Kernel.Signal.Information`.** | Precedent is `Kernel.Socket.Message.Header` directly under `.Message` (not under `.Send` or `.Receive`). siginfo_t describes information about the signal, used by any SA_SIGINFO handler — not coupled to Action. Placing under `.Signal` matches the pattern. |
| 7 | Layout-soundness of `UnsafeMutablePointer<Signal.Information>` over kernel-allocated siginfo_t | **Confirmed sound.** | siginfo_t is kernel-allocated at full platform size (104 bytes Darwin, 128 bytes Linux); `Signal.Information`'s `internal var cValue: siginfo_t` inherits the exact layout. `MemoryLayout<Signal.Information>.stride == MemoryLayout<siginfo_t>.stride` by construction. Swift's typed-pointer contract is satisfied. Reasoning is correct — this is unlike Doc 2's Name case where msg_name pointed at a smaller allocation. |

### Additional weaknesses principal flagged for the implementation cycle

#### Weakness #1 — concrete async-signal-safety acceptance criteria

Principal flagged Q2's "verify" as risk of sliding into "seems fine." Concrete pass criteria for the Option 3 verification experiment (required if Option 3 ever ships):

1. **Test harness**: install the typed handler via `ISO_9945.Kernel.Signal.Action.set(signal:configuration:)` using `Handler.customInfo` with a body that constructs `info.pointee.content` and writes a byte to a pipe (async-signal-safe pipe write).
2. **Allocation trap**: `LD_PRELOAD`-equivalent a `malloc`/`calloc`/`realloc`/`free` wrapper that `abort()`s on any call during the handler's execution. On Darwin use `malloc_zone_*` interception; on Linux use a shared library preload.
3. **Trigger**: provoke SIGSEGV (dereference a null pointer in a separate thread). Signal handler runs in the signaled context.
4. **Pass**: the pipe byte arrives AND the malloc-wrapper did NOT abort during `info.pointee.content` construction. Run 1000 iterations to account for stochastic codegen paths.
5. **Fail**: either the malloc-wrapper aborts (indicating heap allocation inside the handler — Option 3 is structurally unsafe for handler use and collapses to Option 4), or the pipe byte never arrives (indicating the handler crashed — separate diagnostic). Either failure blocks the Option 3 remediation until a non-allocating construction path is designed.

Experiment spec estimated at half-day scope once the implementation cycle opens. Without these criteria, "verification" is impossible to judge done.

#### Weakness #2 — scoping estimate for Option 3's full si_code catalog

Principal flagged Option 3's "~15–20 cases" as un-costed for scheduling. Rough estimate for the Option 3 follow-up cycle, conditional on the async-signal-safety experiment passing:

- **POSIX-spec-defined si_code cases** (cross-platform union): `SI_USER`, `SI_QUEUE`, `SI_TIMER`, `SI_ASYNCIO`, `SI_MESGQ`, `CLD_EXITED`, `CLD_KILLED`, `CLD_DUMPED`, `CLD_TRAPPED`, `CLD_STOPPED`, `CLD_CONTINUED`, `SEGV_MAPERR`, `SEGV_ACCERR`, `BUS_ADRALN`, `BUS_ADRERR`, `BUS_OBJERR`, `ILL_ILLOPC`, `ILL_ILLOPN`, `ILL_ILLADR`, `ILL_ILLTRP`, `ILL_PRVOPC`, `ILL_PRVREG`, `ILL_COPROC`, `ILL_BADSTK`, `FPE_INTDIV`, `FPE_INTOVF`, `FPE_FLTDIV`, `FPE_FLTOVF`, `FPE_FLTUND`, `FPE_FLTRES`, `FPE_FLTINV`, `FPE_FLTSUB`, `TRAP_BRKPT`, `TRAP_TRACE`, `POLL_IN`, `POLL_OUT`, `POLL_MSG`, `POLL_ERR`, `POLL_PRI`, `POLL_HUP`. ~40 cases.
- **Linux-only additions**: `SI_KERNEL`, `SI_SIGIO`, `SI_TKILL`, `SEGV_BNDERR`, `SEGV_PKUERR`, `BUS_MCEERR_AR`, `BUS_MCEERR_AO`, `FPE_FLTUNK`, `FPE_CONDTRAP`, `TRAP_BRANCH`, `TRAP_HWBKPT`, `TRAP_UNK`, `POLL_CLR`, etc. ~10–15 additional.
- **Darwin-only additions**: minimal (`SI_USER` derivatives, `EVFILT_*`-adjacent codes). ~3–5 additional.

Total ~55–60 si_code constants mapping into the typed Content enum (consolidating where Content sub-structs can unify multiple si_code values — e.g., all `CLD_*` map into `.child(Child)` with a `Reason` sub-enum). Realistic enum case count is ~8–10 top-level cases + ~5–7 sub-types with ~3–8 sub-enum cases each. Implementation cycle estimated **3–5 days** (catalog + sub-type design + per-platform dispatch + tests), excluding the half-day async-signal-safety verification experiment.

#### Weakness #3 — Q4 option (c) "drop the third ucontext_t parameter" expanded analysis

Principal flagged that "drop the third parameter entirely" was under-analyzed. Expanded:

The kernel invokes sa_sigaction handlers with three arguments per POSIX: `void (*sa_sigaction)(int, siginfo_t *, void *)`. The third argument (`ucontext_t*`) is the execution context at signal delivery. Most handlers ignore it.

Swift allows declaring `@convention(c)` function types with fewer parameters than the calling convention provides, IF the C calling convention discards extras correctly. On most ABIs (x86_64 System V, AArch64 AAPCS) the caller is responsible for parameter cleanup, so extras passed in registers or on the stack are safely ignored by a 2-arg callee. A 2-arg `@convention(c) (Int32, UnsafeMutablePointer<Signal.Information>?) -> Void` COULD be ABI-compatible with a 3-arg sigaction slot — but this is platform-and-ABI-dependent and is NOT guaranteed by the C standard.

Verification experiment for Option (c):
1. Install a 2-arg `@convention(c)` handler via sigaction's sa_sigaction slot.
2. Trigger SIGSEGV.
3. Verify the handler receives correct `Int32` and `siginfo_t*` values (no register-mangling; no crash on return).
4. Run on macOS arm64 + Linux x86_64 + Linux arm64.

If all three pass, Option (c) is viable as a Swift-side API shape (the kernel still passes 3 args; Swift just ignores the third). If any fail, Option (c) is off the table.

Scope: 1–2 days for the experiment across platforms. Not part of Option 1's implementation cycle; either a same-cycle experiment (add a day) or a separate investigation after Option 1 ships.

### Forward-looking note for implementation-cycle scheduling

Principal's recommended implementation-cycle order: Doc 2 → Doc 3 → Doc 1. Rationale:

1. **Doc 2 first** (smallest, iso-9945-local, no cross-package cascade, no verification gate). Establishes the "typed pointer on a struct slot" pattern cleanly.
2. **Doc 3 second** (still iso-9945-local). Applies Doc 2's layout-compatible-wrapper pattern to siginfo_t. Async-signal-safety verification recommended, not blocking for Option 1 alone. Bundle the `public import Darwin/Glibc/Musl` → `internal import` drive-by per Decision #5.
3. **Doc 1 third** (biggest — cross-package iso-9945 + swift-posix, `@inlinable` cascade risk pre-check, Docker Linux verification mandatory per Doc 1's Q5 ruling). Do last so Docs 2 and 3 can establish precedent for the layout-compatible-wrapper pattern before the method-level-split in Doc 1 lands on top.

Each implementation cycle opens with its own fresh `/supervise` block per [SUPER-010]. Implementation-cycle ground rules template (principal-provided at Doc 3 close):

- **MUST** implement the doc's recommended Option as specified; no structural deviation without escalation.
- **MUST** run Docker Linux build (swift 6.3.1) before landing — `swift build --build-tests` clean on macOS AND Linux, not just local-platform. Load-bearing per the 2026-04-20 L2/L3 latent-ambiguity reflection.
- **MUST NOT** touch `descriptor-migration-wip` branches, expand scope beyond the doc's options-matrix bounds, or attempt design changes not contemplated in the approved doc.
- **MUST NOT** bundle with other docs' implementation cycles unless principal explicitly authorizes (each doc gets its own cycle).
- **fact**: open questions for this doc have been principal-answered at cycle-open time (the Principal Decisions section above). Mid-cycle design drift escalates.
- **ask**: tactical decisions → `[SUPER-015]` appendix on the commit. Structural ambiguities → escalate.
