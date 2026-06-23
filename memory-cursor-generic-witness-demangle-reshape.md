# Memory.Cursor Generic-Witness Demangle — Reshape to Dodge

<!--
---
version: 1.0.0
last_updated: 2026-05-28
status: RECOMMENDATION
tier: 2
scope: cross-package
supersedes_note: "Extends unified-iteration-design.md Outcome OQ-2 (the DORMANT verdict) with a literal-topology reproduction + a validated reshape. Does not supersede that doc; it resolves its open /issue-investigation."
changelog:
  - "1.0.0 (2026-05-28): Literal-topology REPRODUCED (target F, principal-authorized transient-restore of the crashing Memory.Cursor<Self> form on the real Buffer.Linear.Inline; fully reverted). 3-module synthetic reconstruction (target E) still PASSES. Three reshape directions tested against F: unconditional-conformance (FAIL), @frozen-removal (FAIL), element-only-generic erased witness Memory.Snapshot.Cursor<Element> (PASS). Root cause triangulated to the deep generic instantiation in the associated-type-witness mangled name (same compiler-emission class as compiler-bug-catalog §A9). Reshape lives in swift-memory-cursor-primitives + swift-memory-sequence-primitives; validated debug + release-with-verify-off. Ambient buffer-linear release LLVM-verifier ICE identified as a DISTINCT, pre-existing bug (fires with the production scalar iterator at HEAD)."
---
-->

> **Status**: RECOMMENDATION. Resolves the `/issue-investigation` that
> `unified-iteration-design.md` (Outcome OQ-2) left open by marking the
> `Memory.Cursor → Sequenceable` bridge **DORMANT**. A working reshape now exists; whether to
> **adopt** it (and how) is a principal decision. All transient production edits used to
> reproduce were fully reverted; no package was left altered; no commits were made.

## TL;DR

- **The crash reproduces only on the literal `Buffer.Linear.Inline`** — confirmed by a
  principal-authorized transient-restore of the crashing `Memory.Cursor<Self>` `Sequenceable`
  conformance (target F in `Experiments/memory-cursor-generic-witness-demangle`). Even a faithful
  **3-module** synthetic reconstruction (target E: type / ops / bridge-default split + value-generic
  `@_rawLayout` + dual `@_implements` + cross-module bridge-default witness + span-witness-in-type-
  module) **passes**. This *extends and confirms* the prior "not synthetically reproducible" verdict.
- **Root cause** (triangulated): IRGen emits a **corrupt associated-type-witness mangled name**
  (literally the single byte `'}'`) for the **deep generic instantiation**
  `Memory.Cursor<Buffer<A>.Linear.Inline<8>>` used as the `Sequenceable.Iterator` witness. Same
  compiler-**emission** class as `swift-compiler-bug-catalog.md` §A9 (`Atomic<Tagged<…>>` malformed
  mangled name). Debug → runtime SIGABRT in `collect()`; release → masked by an ambient verifier ICE.
- **The reshape that dodges it**: flatten the `Sequenceable.Iterator` witness to an
  **element-only-generic** type — `Memory.Snapshot.Cursor<Element>` — that eagerly snapshots the
  contiguous span into an owned `[Element]`. Its witness mangled name (`Memory.Snapshot.Cursor<A>`)
  never embeds the conforming type, so it sidesteps the corrupt emission. **Validated against the
  literal topology**, debug + release-with-`-disable-llvm-verify`.
- **Two other reshape directions FAIL** (still crash): making the `Iterator.Protocol` conformance
  unconditional, and removing `@frozen`. So the lever is *specifically* witness-flattening, not
  layout or conformance-conditionality.

## Reproduction

Toolchain Apple Swift 6.3.2 (`swiftlang-6.3.2.1.108`), macOS 26 arm64. Hard-clean builds throughout.

The crashing form (transiently restored on the real type for the duration of the investigation):

```swift
// Buffer.Linear.Inline+Sequence.Protocol.swift  (ops module, plural)
extension Buffer.Linear.Inline: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Memory.Cursor<Buffer<Element>.Linear.Inline<capacity>>
    // witness = the cross-module bridge default makeIterator() -> Memory.Cursor<Self>
}
```

```
$ swift run F-literal-buffer-linear-exe      # DEBUG, hard-clean
failed to demangle witness for associated type 'Iterator' in conformance
'…Buffer<A>.Linear.Inline<8>: Sequenceable' from mangled name '}' - unknown error
# exit 134 (SIGABRT / Signal 6), in Sequenceable.collect()
```

The mangled name fed to `swift_getAssociatedTypeWitness` is the **single byte `'}'`** — a
truncated/garbage relative-pointer target. This is the decisive diagnostic: the *emission* of the
associated-type-witness mangled name is corrupt for this instantiation.

### Why it is not synthetically reproducible

`Experiments/memory-cursor-generic-witness-demangle` builds ~10 reconstructions (targets A–E). Every
one PASSES, including target **E**, the faithful 3-module topology — the single structural factor the
prior 2026-05-27 investigation flagged as un-reconstructed. The trigger needs some factor of the full
literal `Buffer.Linear.Inline` member/conformance-cluster surface that resists synthetic isolation. So
there is still **no `swiftc`/SwiftPM-outside-buffer-linear reducer** → no upstream filing per
[ISSUE-002]/[ISSUE-017]; reproduction requires the literal type.

## Reshape attempts (all hard-clean, validated against the literal F crash)

| # | Reshape | Result |
|---|---------|--------|
| 1 | conform `Iterator.\`Protocol\`` **unconditionally** on the struct (vs conditional `extension … where Base: ~Copyable`) | **FAIL** — identical `'}'` crash |
| 2 | **element-only-generic erased witness** `Memory.Snapshot.Cursor<Element>` (eager span→`[Element]` snapshot) | **PASS** — debug `[10,20,30]`; release `-disable-llvm-verify` `[10,20,30]` |
| 3 | remove `@frozen` from `Memory.Cursor` | **FAIL** — identical `'}'` crash |

Triangulation: 1 and 3 fail; only 2 dodges. The trigger is therefore the **deep generic instantiation
embedded in the witness's mangled name** — neither the cursor's layout (`@frozen`) nor the
conditional-vs-unconditional conformance is the lever. Flattening the witness so the conforming type
is *absent* from the witness mangling is the necessary and sufficient dodge.

## The reshape

`swift-memory-cursor-primitives` — new `Memory.Snapshot.Cursor<Element>` (file
`Memory.Snapshot.Cursor.swift`), element-only-generic, `@frozen`, Copyable & Escapable, owning a
`[Element]` snapshot, conforming `Iterator.\`Protocol\`` with index-based `next()`.

`swift-memory-sequence-primitives` — a `makeSnapshotIterator()` witness on
`Span.Protocol` that snapshots `span` into `[Element]` and returns
`Memory.Snapshot.Cursor`. The original lazy `makeIterator() -> Memory.Cursor<Self>` default is kept.

A conformer adopts it by binding `@_implements(Sequenceable, Iterator) typealias = Memory.Snapshot.Cursor<Element>`
and `makeIterator() { makeSnapshotIterator() }`.

### Trade-off

| | lazy `Memory.Cursor<Base>` | reshape `Memory.Snapshot.Cursor<Element>` |
|---|---|---|
| Witness mangled name | deep (`…Cursor<Buffer<A>.Linear.Inline<8>>`) → **corrupt for literal** | shallow (`…Snapshot.Cursor<A>`) → **safe** |
| Cost | per-`next()` span re-derivation, no alloc | one `[Element]` alloc + bulk copy up front |
| `~Copyable` element | yes (lazy) | no (snapshot copies out; needs `Copyable & Escapable`) |
| Inline `@_rawLayout` conformers | corrupt witness | **only safe element-only-generic shape** (a lazy element-only iterator would dangle a pointer into consumed inline storage) |

## Important: a DISTINCT, ambient buffer-linear release ICE

`swift-buffer-linear-primitives` **fails to compile in release** with an LLVM "Broken module found"
verifier abort **at clean HEAD with the production hand-written scalar iterator** (no `Memory.Cursor`
at all) — verified by building the standalone `Buffer Linear Inline Primitives` target at HEAD,
`-c release`. This is almost certainly the documented `@_rawLayout`+deinit verifier issue
(`swiftlang/swift#86652`; cf. WORKAROUND comments in `Buffer.Linear.Inline.swift` /
`Storage.Inline.swift`). It is **independent of the Memory.Cursor demangle** and a Memory.Cursor
reshape neither causes nor fixes it. It is flagged here as its own candidate catalog entry / upstream
item. (The reshape's release codegen is sound — confirmed with `-disable-llvm-verify`.)

## Recommendation (for principal decision)

1. **Adopt the reshape** as the `Memory.Cursor → Sequenceable` bridge witness for *generic contiguous
   conformers that trip the demangle* (currently: the inline `@_rawLayout` buffer-linear family), in
   place of leaving the bridge DORMANT. The element-only-generic snapshot is demangle-safe and
   structurally honest (a snapshot iterator over already-contiguous memory).
   - **Open sub-decision**: keep `Memory.Snapshot.Cursor` *alongside* the lazy `Memory.Cursor` (lazy
     remains preferred for conformers that don't trip the bug), or make the snapshot the sole
     `Sequenceable` bridge. Recommended: **alongside** — the lazy cursor is strictly better where it
     works, and the bug is context-specific.
   - **Naming**: `Memory.Snapshot.Cursor` is a placeholder chosen to read clearly; confirm against
     [API-NAME-001] / the cursor-family conventions before adoption.
2. **Alternatively, stay hand-written-scalar** (the current production HEAD). That is *also* a valid
   dodge of the same class (a concrete, non-deep-generic witness). The reshape's advantage is that it
   is **generic and reusable** across contiguous conformers — one bridge witness instead of a
   per-variant hand-written scalar iterator. If the ecosystem expects many more contiguous
   `Sequenceable` conformers, the reshape pays off; if Inline is the only one, hand-written-scalar is
   simpler.
3. **File the ambient buffer-linear release ICE** (§ above) separately — it blocks release builds of
   buffer-linear today regardless of this investigation.
4. **No upstream filing for the demangle yet** — no standalone reducer. If pursued, vendor the full
   literal type into a self-contained reducer, or do upstream-side bisection of the mangled-name
   emission for the deep instantiation.

## References

- `swift-institute/Experiments/memory-cursor-generic-witness-demangle` — reproduction (targets A–F),
  Outputs, EXPERIMENT.md.
- `swift-institute/Research/unified-iteration-design.md` — Outcome OQ-2 (the DORMANT verdict
  this note resolves).
- `swift-institute/Research/swift-compiler-bug-catalog.md` — § A12 (this bug), § A9 (sibling
  corrupt-mangled-name-emission class), § A11 (same buffer-linear `@_rawLayout`/Span context),
  master fix-status table; `swiftlang/swift#86652` (ambient release confound).
- Source touched (reshape): `swift-memory-cursor-primitives/Sources/Memory Cursor Primitives/Memory.Snapshot.Cursor.swift`;
  the `Sequenceable` extension on the owned typed region (then `Memory.Contiguous+Sequenceable.swift` in `swift-memory-sequence-primitives`; the region is now `Storage.Contiguous`).
- Skills: [ISSUE-002], [ISSUE-013], [ISSUE-025], [ISSUE-028], [EXP-006], [EXP-020], [API-NAME-001].
