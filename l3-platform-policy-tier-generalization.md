# L3 Platform-Policy Tier Generalization

**Status**: IN_PROGRESS
**Tier**: 2
**Scope**: ecosystem-wide

## Context

`[PLAT-ARCH-008e]` codified the L3 Unifier Composition Discipline on 2026-04-20: `swift-kernel` (L3 unifier) MUST compose over peer L3 platform-policy packages when those wrappers add behavior, MUST NOT inherit methods directly from L2 raw via namespace-alias extension when a policy wrapper exists. The canonical case study is `swift-posix` — EINTR retry-wrappers on syscalls that iso-9945 exposes in raw form.

The follow-up audit found 17 HIGH violations in `swift-kernel` of the pattern, all in a single uniform shape (POSIX retry-wrappers shadowed by their L2-raw inheritance). Darwin / Linux / Windows L3 packages were clean (novel APIs only, zero L2-raw shadows).

This produces a sharp asymmetry: **swift-posix is currently the sole L3 platform-policy package.** The question is whether this is a gap (other L3 unifiers lack analogous policy layers where they should have them) or principled (no platform policy to normalize there).

## Question

**Does the L3 platform-policy tier exist for `swift-strings`, `swift-paths`, and other L3 unifiers beyond `swift-kernel` — and is its absence a gap or an intentional property of the domain?**

Sub-questions:
- What does "platform policy" look like for strings? (Encoding normalization? Platform-conditional canonicalization? No analog?)
- What does it look like for paths? (Separator normalization already exists as L3 domain logic — is there a POSIX-vs-Windows behavioral gap beneath that deserving of a dedicated policy layer?)
- Are there other L3 unifiers across `swift-foundations` (executors, completions, file-system) where platform policy is currently inlined in the unifier when it should live in a peer L3 platform-policy package?

## Analysis (stub)

Proposed investigation:

1. **Enumerate L3 unifiers**: packages that re-export across platform variants (e.g., `swift-kernel`, `swift-strings`, `swift-paths`, possibly `swift-executors`).
2. **For each unifier**, grep for `#if os(...)` sites inside the unifier's own code — these are candidates for L3 platform-policy extraction per `[PLAT-ARCH-008d]` syscall-vs-policy test.
3. **Classify** by shape: is the platform-conditional adding behavior (policy candidate) or selecting between raw L2 calls (legitimate unifier delegation)?
4. **Decision per unifier**: extract a platform-policy package, absorb into domain policy, or document as "no platform policy here by design."

## Outcome (placeholder)

Pending ecosystem audit against `[PLAT-ARCH-008d]`/`[PLAT-ARCH-008e]` for the non-kernel unifiers. Expected finding shape: most L3 unifiers will not produce a swift-posix analog (strings and paths do not have an EINTR-equivalent policy gap), but the audit may surface a small number of legitimate extractions that currently live incorrectly inline.

If the audit confirms swift-posix is structurally unique, `[PLAT-ARCH-008e]`'s current framing (as a general rule) is correct; if the audit finds analogs, the rule's examples should be expanded to include them.

## Provenance

- `Research/Reflections/2026-04-20-l3-unifier-composition-discipline.md`
- `Skills/platform/SKILL.md` — `[PLAT-ARCH-008e]`

## References

- `swift-posix/Sources/.../POSIX.Kernel.File.Flush.swift` — canonical L3 platform-policy example
- `swift-kernel/Sources/.../Kernel.File.Flush+*.swift` — post-`[PLAT-ARCH-008e]` unifier pattern
