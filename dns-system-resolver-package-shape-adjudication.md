# DNS System-Resolver Package Shape — Adjudication Packet

<!--
---
version: 1.0.0
last_updated: 2026-07-23
status: DECISION
tier: 2
scope: swift-domain-name-system-iso-9945 + platform stack
---
-->

Principal flag (2026-07-23 handoff): `swift-domain-name-system-iso-9945` (public, single
commit `3dc1b16`) is likely NOT the correct shape. Read-only adjudication against the
platform skill; no mutation performed.

## Facts

- The package imports the **L2 spec module directly**: `public import
  ISO_9945_Kernel_Socket_Address` (`DNS.Resolver.System.swift:14`; call site `:68`
  `ISO_9945.Kernel.Socket.Address.Info.List.get(host:hints:)`), and leaks the L2 error
  type into its public surface (`DNS.Resolver.System.Error.swift:38`
  `.resolution(ISO_9945.Kernel.Socket.Address.Info.Error)`).
- No `import Kernel`, no `POSIX_*`, no platform C, no `#if`. Content = one type
  `DNS.Resolver.System` (thread-pool offload + hints/family/address translation).
- The L3-policy tier is EMPTY for this syscall family: no
  `POSIX.Kernel.Socket.Address.Info` wrapper in swift-posix, nothing in swift-kernel.
- Sibling precedent `swift-sockets-ip-address` imports only L3 surfaces (`Kernel`,
  `Sockets`, `IP_Address`) — its provider suffix names an L3 package; this repo's names
  an L2 spec.
- The layer-deps lint passes **by construction, not adjudication**: any package declaring
  an L2-spec dep is auto-classified as "in the platform stack" and exempted
  (`validate-layer-deps.py:148-162`) — circular for exactly this case.
- The Wave-3 record explicitly approved the current name and edge
  (`native-networking-wave-3-implementation-heritage-dependency-record.md:143`,
  `:193-195`, `:251-253`), so this is a record-vs-skill tension, not implementation drift.

## Legality analysis (summary)

- Legal TODAY only via the [PLAT-ARCH-008e] empty-tier exception (no policy wrapper
  exists to skip). Fragile: the moment swift-posix grows an Address.Info policy wrapper
  (e.g. EAI_AGAIN retry), this package silently skips it — the exact 008e failure mode.
  [PLAT-ARCH-030] also wants the policy slot reserved; it never was.
- **[PLAT-ARCH-008d] is decisive**: getaddrinfo exists under the same name/shape on POSIX
  and Winsock; platform variance is syscall mechanics, not consumer-observable domain
  policy → unification belongs in the platform stack (swift-kernel). A per-spec DNS leg
  expresses an ecosystem gap, not a domain necessity.
- The certificates analog (`swift-certificates-system` + per-leg providers) is the WRONG
  model here: trust acquisition differs **in kind** per platform; host resolution does not.

## Recommended disposition: restructure + rename

1. swift-posix: add re-export target `POSIX Kernel Socket Address` (reserves the policy
   slot per [PLAT-ARCH-030]).
2. swift-kernel: expose unified `Kernel.Socket.Address.Info` (POSIX delegate now, Windows
   `GetAddrInfoW` leg later) per [PLAT-ARCH-008e]/[PLAT-ARCH-021] — kernel-level,
   domain-neutral vocabulary, like `Kernel.IO.Read`.
3. Rename repo → **`swift-domain-name-system-kernel`**; product/target `Domain Name
   System Kernel`, module `Domain_Name_System_Kernel`; type `DNS.Resolver.System`
   unchanged; deps become Domain Name System + Kernel + Thread Pool + IP Address; drop
   the direct swift-iso-9945 edge; error case becomes
   `.resolution(Kernel.Socket.Address.Info.Error)`.
4. Amend the Wave-3 record rows (`:143`, `:193-195`, `:251-253`) in the same motion.

Rename cost is at its lifetime minimum: zero manifest consumers exist (one doc-comment
mention at `swift-domain-name-system/.../DNS.Resolver.swift:17`); GitHub rename preserves
history + redirects; [HERITAGE-001] does not fire (original work, no upstream).

Fallback if swift-kernel work is out of scope this wave: keep as-is with a recorded
sunset condition — "restructure before any second-platform leg or any swift-posix
Address.Info policy wrapper lands". A rename to `-kernel` without the Kernel surface
would be dishonest; `-posix` + re-export target would leave a domain→policy edge
[PLAT-ARCH-008h] disfavors.

## Open questions for the principal

1. **Classification ruling** (everything follows from this): host resolution =
   kernel-level domain-neutral (→ Kernel unification + `-kernel` rename) or a
   per-platform provider concern on the certificates pattern (→ keep `-iso-9945`,
   committing to future `-windows-32` leg + `-system` selector + provisional 008a
   exception)?
2. Record amendment: amend Wave-3 record in the same motion, or a superseding decision
   entry?
3. Tighten the `validate-layer-deps.py:148-162` self-exemption heuristic (explicit
   registry classification per [PLAT-ARCH-021]) so such cases are adjudicated rather than
   self-exempting?
4. Is swift-kernel/swift-posix work in scope this wave, or defer with the sunset
   condition?
5. Confirm/deliberate the asymmetric `@_exported` re-exports in `exports.swift:12-13`
   (re-exports recipient, not provider).

## DECISION (2026-07-23 — final adjudication under principal delegation)

1. **Classification: kernel-level, domain-neutral.** The recommended disposition
   executes in full: swift-posix gains the `POSIX Kernel Socket Address`
   re-export slot ([PLAT-ARCH-030]); swift-kernel gains the unified
   `Kernel.Socket.Address.Info` surface ([PLAT-ARCH-008e]/[PLAT-ARCH-021],
   POSIX delegate now, Windows leg later); the repo is renamed
   **`swift-domain-name-system-kernel`** (product `Domain Name System Kernel`,
   module `Domain_Name_System_Kernel`), drops the direct swift-iso-9945 edge,
   and its error case becomes `.resolution(Kernel.Socket.Address.Info.Error)`.
   The certificates per-leg pattern is rejected for DNS.
2. **Record amendment**: the Wave-3 record is amended in the same motion
   (changelog 1.2.0 + amendment note; rows :143/:193-195/:251-253 superseded).
3. **Lint heuristic**: tighten `validate-layer-deps.py:148-162` to an explicit
   registry classification per [PLAT-ARCH-021] — queued as a follow-up task
   (.github repo), not a blocker for this restructure.
4. **swift-kernel/swift-posix scope**: IN scope now (principal delegation
   "proceed straight to implementation").
5. **Re-export asymmetry**: deliberate and retained — the adapter re-exports its
   recipient surface (Domain_Name_System, Thread_Pool) and must NOT re-export
   its provider (Kernel); consumers of a DNS provider should not ambiently
   acquire the kernel surface.

Rename mechanics: GitHub rename (redirect-preserving), zero manifest consumers
to migrate; the doc-comment at `swift-domain-name-system/.../DNS.Resolver.swift:17`
updates in the same wave. [HERITAGE-001] does not fire (original work).
