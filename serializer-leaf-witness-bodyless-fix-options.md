# Fix options — serializer leaf-`body` bodyless-witness SIL crash (catalog A16)

**Status**: RECOMMENDATION / decision-pending. Drafted 2026-06-25 from the
`/issue-investigation` of `HANDOFF-windows-compiler-crashes.md`. No package edits made.

**Bug**: `swift-issue-noncopyable-assoctype-never-bodyless-witness` (dossier) / catalog
**A16**. Unfixed on Swift 6.5-dev. The `Body == Never` leaf-default `var body: Never`
witness in `Serializer_Primitive` is emitted **bodyless** as a `shared [serialized]` SIL
function in any consumer module that conforms a `Body == Never` type — but only because
`Serializer_Primitive` *itself* contains a `Body == Never` conformer (`Serializer.Witness`)
that forces the generic default to be serialized into the module. The crash fires wherever
SIL verification runs (Windows +Asserts, Embedded, `-sil-verify-all`); it is latent/silent
on NoAsserts RELEASE (macOS/Linux pass). It affects **every** leaf combinator (Trace, Map,
Optional, Filter, Lazy, Literal, Always, Fail, Tagged), not just Trace.

The crash discriminator is **ingredient #3**: a `Body == Never` conformer existing in the
same module as the leaf-default. Remove that and the bug disappears (verified: with no
in-defining-module conformer, consumer modules using the default compile clean even under
`-sil-verify-all`/Embedded).

## Options

| # | Option | Verified? | Blast radius | Notes |
|---|--------|-----------|--------------|-------|
| 1 | **Relocate `Serializer.Witness` (+ its `: Serializer.Protocol` conformance) out of `Serializer_Primitive`** into a new sibling target (e.g. `Serializer Witness Primitives`) | ✅ verified CLEAN (WA3 / reducer M4) | Medium — new target; umbrella + any consumer using `Serializer.Witness`/`Serializer.Pure` re-point | The only verified-compiling fix. Move the TYPE *and* the conformance together (moving only the conformance = retroactive-conformance smell). In-package only DocC references Witness today; institute-wide `Serializer.Witness`/`.Pure` consumers must be inventoried before moving. |
| 1b | Keep `Witness` in `Serializer_Primitive` but give it an **explicit** `var body: Never` instead of using the default | ❌ does not compile | Small if it worked | The `@Serializer.Builder<Buffer>` result builder applies to the explicit witness and demands `Never: Serializer.Protocol`. Would require also exempting `body` from the builder for the leaf case — i.e. partial Option 2. |
| 2 | **Redesign leaf modeling** — drop the `Body == Never` + `fatalError()` leaf-default pattern (e.g. no `body` requirement default; a dedicated leaf marker; or `body` not result-builder'd) | ❌ not prototyped | Large — touches the converged Parser/Serializer body+builder design ([project_parser_serializer_coder_system_framing]) and all combinators | Most "principled" (the `var body: Never { fatalError() }` phantom is inherently awkward) but the biggest change to timeless infrastructure; needs a design pass, not a patch. |
| 3 | Attribute-only escape on the default (`@_optimize(none)` / `@inline(never)` / `@_alwaysEmitIntoClient`) | ❌ all FAIL | Tiny | Ruled out — it is a verification/emission bug, not optimization. |
| 4 | Hold Windows/Embedded RED, wait for upstream | n/a | none | **Not viable** — unfixed on 6.5-dev, so no near-term release carries a fix. |

## Recommendation

**Option 1** is the only verified fix and the most surgical. Before executing:

1. **Inventory institute-wide consumers** of `Serializer.Witness` / `Serializer.Pure`
   (`grep -rn "Serializer\.\(Witness\|Pure\)"` across the org dirs) — they would import the
   new target instead of (or in addition to) `Serializer Primitive`.
2. Decide the new target's name/placement and whether `Serializer Primitive` (the namespace
   target) should re-export it for source-compat.
3. Re-verify the whole package builds clean under Embedded **and** `-sil-verify-all`, and that
   a second consumer (e.g. a Map-shaped module) also passes — the bug hit all leaf combinators.

If the principal prefers the cleaner long-term shape, **Option 2** is the design-pass
alternative; it should be scoped as its own arc (it edits the converged protocol), not folded
into this fix.

## Open question for the principal

Option 1 moves `Serializer.Witness` — currently the canonical closure-backed conformer
co-located with `Serializer.Protocol` — out of the namespace target. Is that acceptable, or
is co-location of `Witness` with the protocol load-bearing enough to prefer the Option 2
redesign instead?

## References

- Dossier: `swift-institute/Issues/swift-issue-noncopyable-assoctype-never-bodyless-witness/`
- Catalog: A16 in `swift-institute/Research/swift-compiler-bug-catalog.md`
- Root-cause source: `swift-serializer-primitives/Sources/Serializer Primitive/Serializer.Protocol.swift:73-81`, `Serializer.Witness+Protocol.swift:13-22`
- Cross-refs: [ISSUE-008], [ISSUE-022], [PKG-BUILD-007], [project_parser_serializer_coder_system_framing]
