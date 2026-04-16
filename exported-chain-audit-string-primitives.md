---
title: "@_exported Chain Audit — String_Primitives and L1 Module Propagation"
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-kernel
  - swift-clocks
  - swift-parsers
  - swift-async
---

# Context

The UTF-8 perf + string-primitives shadow session resolved one leak path:
`Parsers → @_exported Async → Async_Stream → Async_Stream_Core → Clocks →
@_exported Kernel → @_exported Kernel_Core → @_exported Kernel_Path_Primitives →
@_exported Path_Primitives → public import String_Primitives`. The fix
removed `@_exported public import Kernel` from `Clocks/Exports.swift`. But
the root remains: `Path_Primitives` has `public import String_Primitives`
for its `Path.Char` typealias, and *any* module that `@_exported import
Path_Primitives` still propagates the `String_Primitives.String` shadow
over `Swift.String`. The fix must be at the re-export level, not the
typealias level. This is a single known instance of a broader pattern:
`@_exported` is viral and accumulative, and L1 modules (`String_Primitives`,
`Buffer_Primitives`, `Memory_Primitives`) leaking into L3 consumer APIs
via multi-hop re-exports are the highest-risk case.

# Question

Enumerate every `@_exported import` chain in the ecosystem that propagates
an L1 module (particularly `String_Primitives`) into an L3 consumer's
public namespace. For each chain, design a fix at the re-export level.
Specifically:

- Which `@_exported` declarations exist across swift-primitives,
  swift-standards, swift-foundations?
- For each, which L3 consumers are downstream?
- For each, does the re-export provide a real convenience to consumers,
  or is it umbrella-by-habit?
- Which fixes are safe demotions (drop `@_exported`, keep `public`)
  versus semantic changes (drop the typealias, rename the type)?

# Prior Work

- `swift-institute/Research/string-primitives-shadowing.md`
- `swift-institute/Experiments/typealias-without-reexport/` (2026-02-27)
- `swift-foundations/Research/kernel-type-relocation.md`
- Source reflection: `swift-institute/Research/Reflections/2026-04-15-utf8-perf-and-string-primitives-shadow-fix.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does `Kernel_Core` (L3) need to re-export `Kernel_Path_Primitives`
  at all, or can consumers import both explicitly?
- Can we enforce "no `@_exported` of L1 modules at L3" as a lint /
  acceptance-gate rule?
- What's the migration path for consumers currently relying on the
  transitive visibility?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-institute/Research/Reflections/2026-04-15-utf8-perf-and-string-primitives-shadow-fix.md` action item.
