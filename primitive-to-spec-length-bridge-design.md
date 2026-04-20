# Primitive-to-Spec Length Bridge Design

**Status**: IN_PROGRESS
**Tier**: 2
**Scope**: ecosystem-wide

## Context

The 2026-04-16 DocC landing-page progressive-example session (reflection `2026-04-16-docc-landing-restructure-and-layers-show.md`) surfaced friction at the Geometry → CSS.Length handoff: typed dimensions from `swift-geometry-primitives` require `.px(size.width.rawValue)` at every call site bridging into W3C CSS lengths. This kills the composition story in exemplary code (landing-page SHOW) and recurs as a class across the ecosystem: every primitive→spec handoff faces the same question.

The pattern is not unique to Geometry ↔ CSS:

- `swift-time-primitives` → ISO 8601 string formatting
- `swift-geometry-primitives` → CSS.Length (this session)
- `swift-geometry-primitives` → PDF point (ISO 32000)
- `swift-rfc-4122` UUID → URL string encoding (RFC 3986)
- `swift-color-primitives` → CSS.Color / SVG.Color

Each currently requires an explicit `.rawValue` / `.init` hop at the consumer. This is bridge-tax per `[PATTERN-017]` — visible mechanism at the call site.

## Question

**What is the canonical shape for bridging typed primitives (L1) into specification types (L2) across the ecosystem, and where do the bridging conversions live?**

Candidates:
- **Conformance on the primitive** — e.g., `Tagged<Extent.X<Space>, Double>: LengthConvertible`. Puts the bridge on the source type. Discoverable but pulls spec-layer dependency into primitives.
- **Overloads on the spec type** — e.g., `CSS.Length.px(_ x: Tagged<...>)`. Puts the bridge on the target type. Keeps primitives spec-free but spec types grow a surface per-primitive.
- **Explicit-always** — keep `.px(x.rawValue)` at every call site. Zero cross-layer dependency but maximum mechanism.
- **Bridge package** — third-party module (e.g., `swift-geometry-css-bridge`) holding only the extension set. Clean layering but adds a package per bridge.

## Analysis (stub)

Proposed investigation:

1. **Enumerate ecosystem bridges** actually in use — grep for `rawValue`/`.init(...)` at the primitive↔spec boundary.
2. **Apply [SEM-DEP-008]** (join-point packages) to each bridge — does the bridge warrant its own package under the join-point rule?
3. **Weight each candidate** against `[PLAT-ARCH-*]` layering rules — primitives MUST NOT import specs; specs MAY import primitives (they are higher-layer); bridge packages are legitimate but add count.
4. **Prototype the canonical shape** in one bridge (Geometry → CSS.Length, the landing-page motivating case) and validate call-site ergonomics.

## Outcome (placeholder)

Pending. The decision generalizes to every primitive→spec handoff; arriving at a consistent shape is Tier 2 because it sets precedent across the ecosystem.

## Provenance

- `Research/Reflections/2026-04-16-docc-landing-restructure-and-layers-show.md`

## References

- `Skills/implementation/patterns.md` — `[PATTERN-017]` rawValue confinement rule
- `Skills/implementation/infrastructure.md` — `[IMPL-060]` ecosystem dependencies
- `Documentation.docc/Semantic Dependencies.md` — `[SEM-DEP-008]` join-point packages
