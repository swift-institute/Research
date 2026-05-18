# Word16 / Word32 / Word64 Protocol Viability

<!--
---
version: 1.0.0
last_updated: 2026-05-18
status: DECISION
tier: 2
scope: ecosystem-wide
---
-->

## Context

Triage item R3 (`HANDOFF-byte-arc-next-phase-triage.md`) / HANDOFF.md Wave 1 Item 3 proposed introducing `Word16.Protocol`, `Word32.Protocol`, and `Word64.Protocol` as machine-word-sized capability-marker protocols at L1, analogous to `Byte.Protocol`'s role for byte-domain typed wrappers.

The proposal originated from **symmetric-completeness reasoning**: "`Byte.Protocol` exists (with `ASCII.Code` as a verified conformer per the R4 arc); by analogy, `Word16.Protocol` should exist for hypothetical 16-bit typed wrappers (UTF16.CodeUnit), `Word32.Protocol` for 32-bit (Unicode.Scalar), `Word64.Protocol` for 64-bit identifiers, etc."

## Question

Should the institute introduce `Word16.Protocol` / `Word32.Protocol` / `Word64.Protocol` as L1 capability-marker protocols, parallel to `Byte.Protocol`?

## Analysis

Two independent rules dispose of the proposal:

**[RES-018] case (a) — Cross-cutting primitive proposals**: New cross-cutting primitive proposals MUST satisfy three checks:
- Concrete cross-domain consumer demand (NOT symmetric-completeness reasoning by analogy)
- Composition check (can existing primitives compose to provide the capability?)
- Cross-domain-fit check (does the proposed protocol express the same abstraction across candidate domains?)

The proposal fails the first check decisively. No concrete consumer has surfaced requesting a word-size capability-marker protocol. The hypothetical candidates (UTF16.CodeUnit, Unicode.Scalar) work fine today as concrete types with their own domain operations; they need no capability-marker conformance to function. The proposal's only justification is "by symmetry with Byte.Protocol" — which [RES-018] case (a) explicitly forbids.

**[API-NAME-001c] anti-meta-protocol verdict**: The byte-protocol capability-marker arc (2026-05-15/16) established that capability markers should be **per-domain manual**, not meta-protocol generalized. The recipe is `Byte.Protocol` as a domain-specific marker (with `ASCII.Code` as conformer); not a meta-protocol over which all "byte-like-things" must abstract.

Even if a concrete consumer for word-sized capability markers surfaced, the principled response per [API-NAME-001c] would be a per-domain marker (e.g., a specific `UTF16.CodeUnit.Protocol` for that domain's needs), NOT a unified `Word16.Protocol` covering all 16-bit typed wrappers across all domains.

## Outcome

**Status**: DECISION — Principled refuse

The institute will NOT introduce `Word16.Protocol` / `Word32.Protocol` / `Word64.Protocol`. Two rule-based reasons compound: [RES-018] case (a) forbids the symmetric-completeness origin; [API-NAME-001c] forbids the meta-protocol shape even if consumer demand were to materialize.

Closes HANDOFF.md Wave 1 Item 3 and triage row R3.

## Revisit conditions

The DECISION is not absolute. Re-open IF AND ONLY IF:

1. A concrete cross-domain consumer surfaces that genuinely needs a word-size capability-marker conformance to function (not merely benefits aesthetically from one). AND
2. The consumer's needs span multiple unrelated domains in a way that a per-domain marker (per [API-NAME-001c]) would fail to express adequately.

Both conditions are unlikely. Most word-size-typed-wrapper consumers (UTF16.CodeUnit, Unicode.Scalar, etc.) are best served by their own domain-specific shape per [API-NAME-001c]'s per-domain marker recipe, not by a unified Word*.Protocol.

## References

- `byte-protocol-capability-marker.md` v1.1.0 DECISION — establishes [API-NAME-001c] per-domain marker recipe; ancestor of this DECISION
- `byte-primitive-extraction-and-domain-naming.md` v1.0.1 DECISION — [API-NAME-001b] subject-first naming; consistent with per-domain markers
- `HANDOFF-byte-arc-next-phase-triage.md` row R3 — origin of the symmetric-completeness proposal
- HANDOFF.md Wave 1 Item 3 — sequence-tracking of this principled-refusal
