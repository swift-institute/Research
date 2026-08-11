# Wave 5: L2/L3 Leaf Triage — Scope and Dispatch Setup

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
---
-->

## Context

Wave 2 (the canonical rule-amendment-from-empirical-signal dispatch) covered **10 L1
primitives** producing 11 amendment threads ([wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md)).
L1 primitives are atomic; their lint signal is dominated by naming, copyability,
and stdlib-idiom patterns.

L2 (standards — spec-mirroring) and L3 (foundations — composition-heavy) have
different finding shapes. Per HANDOFF.md Phase 2.3, these need their own per-leaf
triage pass.

This document is the dispatch SETUP — it enumerates the leaf universe, recommends
a representative-sample-first dispatch shape, and identifies expected pattern
classes that may surface novel rule-amendment threads.

## Leaf Universe

| Layer | Repos (org-mirror) | Leaf count |
|---|---|---:|
| L2 standards (`swift-standards/`) | `swift-*-standard` | 19 |
| L2 standards (`swift-iso/`) | `swift-iso-*` | ~10 |
| L2 standards (`swift-ietf/`) | `swift-rfc-*`, `swift-bcp-*` | ~80 |
| L2 standards (other) | `swift-whatwg/`, `swift-incits/`, `swift-darwin*/`, `swift-microsoft/`, `swift-linux-foundation/`, `swift-intel/`, `swift-color-standard/`, etc. | varies |
| **L2 total** | | **~110** |
| L3 foundations (`swift-foundations/`) | `swift-*` (147 leaves) | **147** |
| **Combined L2 + L3** | | **~257** |

Wave 2 sampled **10 leaves out of ~80 L1 primitives** (~13%). A proportional L2/L3
sample = ~30 leaves. The first dispatch SHOULD sample ~5-10 from each layer to
discover layer-specific patterns before scaling.

## Recommended Sample

### L2 Sample (5 leaves)

| Leaf | Why |
|---|---|
| `swift-rfc-3986` (URI) | Cross-cutting parsing primitives; deep dep graph; widely consumed |
| `swift-iso-9945` (POSIX) | Kernel-adjacent; many `@unsafe`/`nonisolated(unsafe)` sites; surfaces memory-safety pattern signal |
| `swift-rfc-4122` (UUID) | Bit/byte-level encoding; mirrors stdlib UUID + Codable idioms |
| `swift-darwin-standard` | Platform-bridging; surfaces platform-mirroring patterns ([API-NAME-003] specification-mirroring stress test) |
| `swift-html-standard` | Markup-grade L2; tests result-builder + protocol-layered conventions |

### L3 Sample (5 leaves)

| Leaf | Why |
|---|---|
| `swift-io` | Workspace anchor; broadest dep graph; surfaces composition-heavy L3 patterns |
| `swift-linter-rules` | Self-referential; running rules on rules surfaces meta-amendment opportunities |
| `swift-executors` | Concurrency-heavy; many `Atomic<...>`/`nonisolated(unsafe)` sites |
| `swift-file-system` | Cross-cutting L3; consumes many L1/L2 primitives |
| `swift-html-render` | Result-builder-heavy; expressions, closures, throws-typed catches |

## Expected Pattern Classes (Layer-Specific)

Wave 2 surfaced 6 recurring exemption shapes ([wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md)
v1.0.0 closeout). L2 + L3 will likely surface DIFFERENT patterns:

### Expected at L2 (standards)

1. **Specification-mirrored names triggering [API-NAME-002]**: spec terms like
   `RFC_4122.UUID` (Compound? No — namespaced). Spec field names like
   `RFC 3986.URI.Authority` may trigger compound-identifier inside the spec
   namespace. [API-NAME-003] amendment may be needed to formalize "spec-mirroring
   nominal-form is exempt from compound rule when the spec defines the term."

2. **`@unsafe` / `nonisolated(unsafe)` density at kernel-adjacent leaves**:
   swift-iso-9945, swift-darwin-standard. May surface MEM-SAFE patterns the
   Wave 3 Thread 7 split didn't anticipate (e.g., platform-callback-stored
   function pointers).

3. **Bit/byte encoding idiom**: RawValue-from-bytes (`Tagged`-shaped raw types),
   `BitPattern` initializers. May surface a new [API-NAME-*] exemption for
   raw-encoding constructors.

### Expected at L3 (foundations)

1. **Composition over composition**: `Driver`/`Pool`/`Manager`/`Source` types
   that compose 5+ L1 primitives. Naming surface may stress `single type per
   file` vs `cohesive composition`. Per [API-IMPL-005] but at composition scope.

2. **`@MainActor` / `nonisolated` boundaries**: L3 packages frequently expose
   actor-isolated public surface. New Memory-Safety patterns may surface.

3. **Result-builder DSLs**: HTML, CSS, query-builders. The result-builder pack
   rules ([RULE-001 for_loop_in_result_builder] etc.) get exercised heavily.
   Expect novel patterns around `if`/`else` chains and nested builders.

4. **Async/await call-site density**: foundations are async-rich. Throws-typed
   rules + closure-typed annotations + iteration patterns get stress-tested.

## Dispatch Shape (Mirror Wave 2)

For each sample leaf:

1. **Set up Lint/ nested SwiftPM package** consuming `Lint.Rule.Bundle.institute`
   or `.primitives` (per [README.md](https://github.com/swift-foundations/swift-linter)
   three-tier mechanism).
2. **Run lint pass**, capture findings in `Research/lint-pass-2026-05-12-{leaf}.md`
   mirroring Wave 2's per-leaf ledger format.
3. **Triage each finding** as RULE-WRONG / SOURCE-WRONG / AMBIGUOUS using the
   carry-forward methodology.
4. **Aggregate** RULE-WRONG amendments into a Wave-2-style dispatch ledger
   covering all sampled leaves.
5. **Dispatch one commit per amendment** (per Wave 2 discipline).

The first ledger ([wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md))
is the template; the L2/L3 variant will name its own threads as patterns surface.

## Cross-references

- [wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md)
  (the L1 template)
- [wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md) v1.3.0
  (closure ledger + Open Follow-Up cross-references)
- [api-name-002-ifpresent-stdlib-idiom-2026-05-12.md](api-name-002-ifpresent-stdlib-idiom-2026-05-12.md)
  (RECOMMENDATION shape this scope doc mirrors)
- [wave-4-absorber-pattern-policy-lean-2026-05-12.md](wave-4-absorber-pattern-policy-lean-2026-05-12.md)
  (Wave 4 — runs in parallel with this L2/L3 sweep; their dispatch order is
  independent)

## Deferral Note

This document is SETUP, not execution. The actual lint passes + per-leaf
triage + amendment dispatches are the Wave 5 work. The setup is queued; the
execution opens on next available capacity per HANDOFF.md sequencing
("each its own dispatch").
