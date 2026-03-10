---
date: 2026-02-27
session_objective: Validate Option D' cross-module feasibility — @_lifetime propagation through Tagged._storage and generic arity shadowing resolution
packages:
  - swift-identity-primitives
  - swift-string-primitives
  - swift-institute
status: processed
---

# Tagged String Cross-Module — Access Levels and Shadowing

## What Happened

Built a 3-module experiment (`tagged-string-crossmodule/`) to answer two questions that prior single-module experiments could not:

1. Does `@_lifetime` propagation work cross-module through `@usableFromInline internal var _storage` on Tagged?
2. Does generic arity (`String<Tag>` arity 1 vs `Swift.String` arity 0) prevent name shadowing?

The experiment had 11 variants across TaggedLib → StringLib → Consumer, mirroring the production Identity_Primitives → String_Primitives → downstream layering.

**First build failed immediately.** `@usableFromInline internal var _storage` in TaggedLib was inaccessible from `@inlinable` code in StringLib. Three call sites errored: `String.count`, `String.View.withView`, and `String.Domain.isAbsolutePath`. Fix: changed `internal` to `package` on `_storage`. Second build succeeded.

**Run produced 9/11 confirmed, 2/11 falsified.** The critical `@_lifetime` test (V2) passed — `~Escapable` views work cross-module through `package _storage`. The shadowing tests (V4, V11) failed — bare `String` resolves to `StringLib.String<Tag>`, not `Swift.String`, despite different generic arity.

Also added `withRawValue` closure accessor to Tagged as a fallback path for `@_lifetime` propagation, but it was not needed since `package` access resolved the issue directly.

## What Worked and What Didn't

**Worked well:**
- The plan was detailed enough to implement all 7 files without ambiguity. The file contents, directory structure, and verification steps were all correct.
- The 3-module structure faithfully reproduced the production layering. The findings directly transfer.
- Hitting the `internal` vs `package` access error immediately was valuable — it's a finding the experiment was designed to produce, and it surfaced at compile time rather than as a subtle runtime bug.

**Didn't work:**
- The plan assumed `@usableFromInline internal` would enable cross-module source access from `@inlinable` code in other modules. This conflates two things: (a) the symbol being available to the *optimizer* for inlining (which `@usableFromInline` provides), and (b) the symbol being available to *source code* in other modules (which requires `package` or `public` access). The plan's hypothesis was based on an incorrect mental model of `@usableFromInline`.
- The shadowing hypothesis was wrong. The assumption that Swift's name resolver would disambiguate by generic arity was never grounded in language specification — it was a plausible guess. Swift's name lookup finds the closest `String` in scope (the imported typealias) regardless of whether it has different arity.

## Patterns and Root Causes

**Access level semantics are not transitive through annotations.** `@usableFromInline` does not widen access — it makes `internal` symbols available *for inlining* when referenced from `@inlinable` code *in the same module*. When that inlined code lands in another module's binary, the optimizer can see the symbol, but the *source compiler* of the other module cannot reference it. This is the same pattern as C's `static inline` in headers — the definition is visible to the optimizer but not to the programmer's namespace.

The production implication is concrete: `Identity_Primitives.Tagged._storage` needs to change from `internal` to `package`. Since `Identity_Primitives` and `String_Primitives` are both targets in `swift-primitives`, `package` access is exactly right — it's visible within the package but not to external consumers. This is actually *more correct* than `internal` because it makes the intended cross-module-within-package access explicit.

**Name shadowing in Swift follows proximity, not arity.** When `import StringLib` brings `String<Tag>` into scope, Swift's name resolver finds it before `Swift.String` regardless of generic parameter count. This is consistent with how Swift handles all name resolution — the most local declaration wins. There's no arity-based disambiguation in the language.

This kills the "zero-cost shadowing elimination" dream. The ~981 `Swift.String` qualifications in the ecosystem remain. The realistic options are: (a) accept the status quo and qualify, (b) use a different name like `PlatformString<Tag>`, or (c) stop re-exporting and let downstream modules import `String_Primitives` explicitly (which still shadows, but at least is opt-in).

**The experiment validated D' feasibility despite the shadowing setback.** The shadowing question was important but secondary. The primary question — can `@_lifetime` propagate through Tagged's storage cross-module? — is answered definitively: yes, with `package` access. This unblocks the entire D' migration.

## Action Items

- [ ] **[package]** swift-identity-primitives: Change `Tagged._storage` from `@usableFromInline internal` to `@usableFromInline package` — required for cross-module `@inlinable` access from `String_Primitives` and other same-package modules
- [ ] **[research]** Investigate naming alternatives for `String<Tag>` that avoid `Swift.String` shadowing: evaluate `PlatformString<Tag>`, `NativeString<Tag>`, keeping `String` with accepted qualification, or a selective re-export strategy that limits shadowing to only modules that opt in
- [ ] **[skill]** design: Add guidance on `@usableFromInline` + access levels — `@usableFromInline internal` enables inlining within the module only; cross-module `@inlinable` access requires `@usableFromInline package` (same package) or `public`
