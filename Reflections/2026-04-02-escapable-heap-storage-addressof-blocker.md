---
date: 2026-04-02
session_objective: Investigate whether Builtin.addressof + UnsafeMutableRawPointer can replace ManagedBuffer for ~Escapable heap storage
packages:
  - swift-storage-primitives
status: processed
---

# ~Escapable Heap Storage — Builtin.addressof Blocker and Upstream Resolution

## What Happened

The parent session's IO.Completion.Queue redesign needed `Dictionary<K, V: ~Escapable>`, which depends on `Storage.Heap<Element: ~Escapable>`. The parent session claimed `Builtin.addressof` + `UnsafeMutableRawPointer.copyMemory` could bypass the `Escapable` constraint on typed pointer APIs. This session investigated that claim empirically.

Built `swift-storage-primitives/Experiments/escapable-heap-storage/` with 10 variants across 6 phases. Phase 1 confirmed `Builtin.addressof` works for `~Copyable`-only types. Phase 2 tested four approaches to make it work with `~Escapable` — all REFUTED. The compiler treats `Builtin.addressof` as an escape, which violates `~Escapable`'s scope confinement. This is enforced during SIL generation (not Sema) and cannot be suppressed by `@unsafe`, `@_unsafeNonescapableResult`, `inout`, or `unsafeBitCast`.

A field-by-field workaround (decompose to Escapable fields, store individually, reconstruct via init) was confirmed working for the full lifecycle. However, this was correctly identified as a workaround that doesn't generalize to `Storage.Heap<Element: ~Escapable>`.

Searched `swiftlang/swift` at `https://github.com/swiftlang/swift` and found `origin/nonescapable-pointers` branch (Nate Cook, 2026-03-19, commit `885fa6e1f87`). This WIP changes `UnsafePointer<Pointee: ~Copyable>` to `UnsafePointer<Pointee: ~Copyable & ~Escapable>` with conditional `Escapable` conformance. Also updates `Span`, `assumingMemoryBound`, and adds `@_lifetime(copy self)` to accessors. This is the proper fix — once it lands, `Storage.Heap<Element: ~Escapable>` via `ManagedBuffer` becomes possible without workarounds.

Decision: wait for `nonescapable-pointers` to land. Do not build a workaround layer.

## What Worked and What Didn't

**Worked well:**
- Incremental experiment methodology (EXP-004a) caught the addressof blocker on the first build attempt, then systematically tested alternatives
- The `_detach` pattern (`@_unsafeNonescapableResult` identity function to sever lifetime dependencies) — useful technique even though it didn't solve this specific problem
- `@_lifetime(borrow storage)` on EntryView init composing directly with `@_lifetime(borrow self)` on class accessors — cleaner than `_overrideLifetime`
- Searching the Swift compiler repo for upstream work turned the investigation from "blocked, need workaround" to "blocked, upstream fix in progress"

**Didn't work:**
- Initial assumption that `Builtin.addressof` works with `~Escapable` (from parent session's claim) — the parent session likely tested `~Copyable`-only and extrapolated
- `swiftc -typecheck` passing when `swift build` fails — the escape check is SIL-level, not Sema. This is a diagnostic trap: code that type-checks successfully still fails during compilation
- User-defined `_overrideLifetime` in a `borrowing get` — fails where stdlib's internal version works, likely due to `@_alwaysEmitIntoClient` compiler integration

## Patterns and Root Causes

**"Builtin" doesn't mean "unconstrained"**: The assumption was that `Builtin.addressof` bypasses type system constraints because it's a compiler intrinsic. In reality, the SIL lifetime dependence pass treats `AddressToPointerInst` (which wraps `Builtin.addressof`) as creating an escape path. The constraint isn't at the type level — it's at the SIL optimization level. This is why `swiftc -typecheck` passes but `swift build` fails.

**~Escapable is deeper than ~Copyable**: For `~Copyable`, the constraint is about ownership (single owner, no implicit copy). For `~Escapable`, the constraint is about scope confinement (value cannot leave the scope where it was created). Scope confinement is fundamentally harder to work around because ANY pointer to the value is a potential escape path. The compiler correctly identifies `Builtin.addressof` as such a path.

**The stdlib evolves with the features**: `UnsafePointer` requiring `Escapable` on its pointee isn't a design choice — it's a historical artifact. The `Lifetimes` feature is experimental, and the stdlib is catching up. The `nonescapable-pointers` branch is the natural progression: as `~Escapable` matures, the stdlib's pointer types will accept it.

## Action Items

- [ ] **[package]** swift-storage-primitives: When `nonescapable-pointers` lands, re-run the experiment with typed pointer APIs and convert `Storage.Heap` to support `~Escapable` elements
- [ ] **[skill]** memory-safety: Document that `Builtin.addressof` on `~Escapable` values is blocked (SIL-level escape check, not Sema) — this is a non-obvious constraint
- [ ] **[experiment]** Revalidation: `escapable-heap-storage` should be re-tested when a toolchain containing the `nonescapable-pointers` changes becomes available
