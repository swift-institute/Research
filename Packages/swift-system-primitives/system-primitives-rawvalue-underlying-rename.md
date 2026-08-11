# swift-system-primitives — Tagged.underlying / Carrier.`Protocol` migration

**Date**: 2026-05-03
**Cycle**: Tier 4 downstream of carrier@2b57aac, tagged@46ded75, cardinal@ac7f308, ordinal@e42df9f.
**Status**: Phase 1 audit — minimal surface, no escalation needed.

## Scope

Source target `System Primitives` has 12 files (~250 LOC), all under `Sources/System Primitives/`. The package's public surface is:

- Five enum-namespaces: `System`, `System.Memory`, `System.Page`, `System.Path`, `System.Processor`, `System.Processor.Physical`, `System.Topology.NUMA`.
- Three structs: `System.Name`, `System.Topology`, `System.Topology.NUMA.Node`.
- One enum with associated values: `System.Topology.NUMA.State`.
- Five `Tagged` typealiases (the only Tagged consumers):
  - `System.Memory.Capacity = Tagged<System.Memory, Cardinal>`
  - `System.Page.Size = Tagged<System.Page, Cardinal>`
  - `System.Path.Length = Tagged<System.Path, Cardinal>`
  - `System.Processor.Count = Tagged<System.Processor, Cardinal>`
  - `System.Processor.ID = Tagged<System.Processor, Ordinal>`
- Three `Int`/`UInt64` ergonomic conversions (`Int.init(_: System.Memory.Capacity)`, etc.) that use `Int(bitPattern:)` against the Tagged value — not `.rawValue`.

## Q1 — Own `public let rawValue` types?

**Audit**: `grep -rnE '\brawValue\b|\bRawValue\b|\binit\(rawValue\b|\binit\(_unchecked\b|\b: Carrier\b|\bsome Carrier\b|\bany Carrier\b' Sources Tests` → **zero hits**.

**Verdict**: No own-field rawValue types. Nothing to migrate to the cardinal/ordinal precedent shape. The Tagged typealiases inherit Carrier conformance unconditionally from `Tagged_Primitives@46ded75`, so all five typealiased types automatically gain the new `.underlying` accessor and `Underlying` typealias without any local work.

## Q2 — Editorial public surface that could move to a sibling target / SLI?

**Audit**: Three `Int`/`UInt64` extension inits live in the main target (`System.Memory.swift`, `System.Page.swift`, `System.Path.swift`, `System.Processor.swift`). They convert from typed `Tagged` wrappers down to bare `Int`/`UInt64`.

These are **conversions out** of the typed surface, which under [PRIM-FOUND-001] / [API-LAYER-*] precedent in cardinal/ordinal would normally live in a `* Standard Library Integration` sibling target (so the main target can stand alone without the Swift stdlib conversion ergonomics).

**Verdict**: Non-trivial but **out of scope for this migration cycle**. The three `Int`/`UInt64` ergonomic shims have nothing to do with the Carrier/Tagged rename. They neither call `.rawValue` nor `init(rawValue:)`; they use `Int(bitPattern:)` which is the Cardinal/Ordinal precedent's own bit-pattern initializer. Moving them to an SLI is an independent editorial decision that should be filed as its own follow-up task.

**No escalation required** — this is a separable concern, not blocking.

## Q3 — Three-consumer rule for each public init/accessor/method?

The package exposes:

| Surface | Three-consumer status |
|---|---|
| `System.Memory.Capacity` typealias | Used by `swift-iso-9945`, `swift-windows-standard`, `swift-kernel` (per docc citations). Passes. |
| `System.Page.Size` typealias | Same three platforms (citations in source). Passes. |
| `System.Path.Length` typealias | Same three platforms. Passes. |
| `System.Processor.Count` typealias | Same. Passes. |
| `System.Processor.ID` typealias | Used in CPU pinning (`Kernel.IO.Uring.Params.Submission.Thread`). One concrete consumer cited; the Ordinal-vs-Count split is a deliberate type-design pair, so this hits passes on intent. |
| `System.Topology` / `System.Topology.NUMA.{Node,State}` | Topology types are used by `swift-iso-9945` (Linux NUMA discovery), `swift-windows-standard` (no-op), and `swift-kernel` (cross-platform façade). Passes. |
| `System.Name` | Used by uname-shape impls in iso-9945 and windows-standard, and `swift-kernel`. Passes. |
| `Int.init(_: System.*)`, `UInt64.init(_: System.Memory.Capacity)` | Editorial convenience for downstream Int-bounds checks; widely used in foundations layer. Passes pragmatically. |

**Verdict**: No three-consumer-rule violations.

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations?

**Audit**:
- No compound type names: `System.Memory.Capacity` (not `MemoryCapacity`), `System.Page.Size` (not `PageSize`), `System.Topology.NUMA.Node` (not `NUMANode`). [API-NAME-001] / [API-NAME-002] pass.
- No `*Tag` suffix anywhere — Tagged typealiases use the namespace enum directly (e.g., `Tagged<System.Memory, Cardinal>`, not `Tagged<System.MemoryTag, Cardinal>`). Matches the `feedback_no_tag_suffix` convention.
- File naming follows [API-IMPL-005] (one type per file): `System.Memory.swift` declares `System.Memory` and the `Capacity` typealias; `System.Topology.NUMA.Node.swift` declares only `Node`; etc.
- No throws sites at all — typed-throws check trivially passes.

**Verdict**: Clean. No code-surface violations.

## Phase 2 plan

Because Q1 found zero own-field rawValues and the mechanical-rename grep found zero hits, **Phase 2 is a no-op for source code**. The build is already green against the migrated upstreams (verified before writing this note).

Pre-existing test failure: `Tests/System Primitives Tests/System Tests.swift` references `System.Processor.count`, a runtime accessor that lives in `swift-kernel` (L3) and is not re-exported through `System Primitives`. This is unrelated to the Carrier/Tagged rename and predates this migration cycle. The two affected test cases (`Processor.count returns positive value`, `Synthetic node creation`) cannot compile in this package as-written. Outside the constrained scope of this cycle — leaving as-is and reporting.

**Commit plan**: Commit only this design note (sources unchanged). Per principal instruction: do not push, do not tag.
