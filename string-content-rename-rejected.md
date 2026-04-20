# String `.span` → `.content` Rename — REJECTED

**Status**: REJECTED (Wave 3 reverted)
**Decision context**: string-primitives correction cycle (2026-04-18), consensus C6 attempted then reverted same day
**Decision binding**: user-directed, after Wave 3 implementation surfaced two structural problems

---

## What was attempted

Wave 3 implemented consensus C6 of the string-correction-cycle synthesis: rename `String_Primitives.String.span` → `.content` (and same on `.View` and `Tagged<…, String>`), and add matching `.content` accessors on `ISO_9899.String` + `.View`. The rationale, mirrored from the path cycle's `.bytes` → `.content` rename:

- `[IMPL-081]` "intent over mechanism" — `.content` describes the SEMANTIC return value (the string's content, NUL-excluded) while `.span` describes the SHAPE (a `Span<Char>`).
- Path-cycle precedent: paths converged on `.content` for the NUL-excluded form.

## Why rejected

Two structural problems surfaced during Wave 3 implementation:

### 1. The path-cycle precedent does not apply

Path's `.bytes` → `.content` rename resolved a **real semantic ambiguity**: `Paths.Path` had both a `.bytes` property (including NUL) AND a span-style accessor (excluding NUL) — same domain noun (`.bytes`) with different semantics at L1 vs L3. Renaming L1 `.bytes` → `.content` disambiguated.

Strings have **no such ambiguity**. The model's D9 finding was:
- `String_Primitives.String.span` excludes NUL
- `String_Primitives.String.View.span` excludes NUL
- `ISO_9899.String` has NO span accessor at all

This is an asymmetry of **existence** (one type lacks the accessor), not asymmetry of **semantics**. The right fix is additive: add `.span` to `ISO_9899.String` + `.View` matching the existing semantics. Not a rename of a name that was never ambiguous.

### 2. `Memory.Contiguous.Protocol` requires `.span`

`String_Primitives.String` (via `String.swift:185`) and `Tagged<…, String_Primitives.String>` (via `Tagged+String.swift:100`) both conform `@retroactive` to `Memory.Contiguous.Protocol` (defined at `swift-memory-primitives/Sources/Memory Primitives Core/Memory.ContiguousProtocol.swift:101`). The protocol requires `var span: Span<Element> { get }`. Renaming to `.content` breaks the witness.

The implementation perspective's analysis missed this constraint. The fix would have required either:
- Dropping the protocol conformance (loses generic-algorithms-over-contiguous-storage capability for String — many consumers across `swift-buffer-primitives`, `swift-storage-primitives`, etc. would lose the ability to write `T: Memory.Contiguous.Protocol` constraints that admit String).
- Keeping both `.span` (witness) and `.content` (idiomatic) — duplicates surface for no benefit.
- Renaming the protocol's requirement (out of scope).

None is a good trade.

### 3. `.span` is the canonical Swift name

`Array.span`, `Memory.Contiguous.span`, `Span<T>` itself — `.span` is the cross-stdlib + cross-ecosystem name for "give me a Span". Renaming String specifically to `.content` makes it inconsistent with hundreds of other ecosystem types using `.span`. The "intent over mechanism" argument from `[IMPL-081]` loses to ecosystem-consistency when the existing name is already a domain-recognized term.

## What stays from Wave 3

The **additive part** of Wave 3 is kept: `.span` (not `.content`) is now exposed on `ISO_9899.String` and `ISO_9899.String.View`. This addresses D9 by adding the missing accessor with the standard name and semantics, without renaming anything.

## Process lesson

Synthesis output's mechanical "mirror the path cycle" framing missed two cycle-specific facts: (1) paths had a real ambiguity strings don't, and (2) String conforms to a protocol that requires the existing name. Reading "what does the precedent fix?" carefully before adopting it would have caught both.

When deriving from a precedent, validate per question:
- Does the precedent's PROBLEM exist in the new domain?
- Does the new domain have constraints (protocol witnesses, stdlib parallels, downstream consumers) the precedent did not?

## Related

- D9 in `Research/string-type-ecosystem-model.md`
- Wave 3 + consensus C6 in synthesis output (in conversation history)
- Implementation perspective on D9 (in conversation history) — the analysis that missed the conformance constraint
- Path-cycle `.bytes` → `.content` commit history in `swift-foundations/swift-paths` git log
- `string-iso-9899-extraction-rejected.md` — analogous rejection of mechanical-mirror reasoning
