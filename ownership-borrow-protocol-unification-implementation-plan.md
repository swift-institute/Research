# Ownership.Borrow Protocol Unification — Implementation Plan

<!--
---
version: 1.4.0
last_updated: 2026-04-23
status: IMPLEMENTED
tier: 2
scope: cross-package
---
-->

## Revision History

- **1.4.0 (2026-04-23)** — Phase 9 executed end-to-end. 7 sub-repos swept,
  7 commits landed, ecosystem-wide workspace grep returns zero residual
  `.View` references on the cascade surface. Status promoted from
  PARTIAL_IMPLEMENTED to **IMPLEMENTED**.

  Phase 9 execution log:
  - Commit 9a (swift-iso-9945 `fa7b947`): 48 sites across 20 files; 2 retroactive-conformance files renamed (`Kernel.Path.View+Path.{Decomposition,Modification}.swift` → `.Borrowed+...`)
  - Commit 9b (swift-foundations/swift-kernel `e590817`): 25 Sources + 5 Tests sites across 8 files
  - Commit 9c (swift-foundations/swift-posix `28f79e4`): 10 Sources + 1 Test site across 3 files
  - Commit 9d (swift-microsoft/swift-windows-standard `fc383de`): 8 sites in 2 retroactive-conformance files (renamed + edited; os(Windows)-guarded)
  - Commit 9e (swift-foundations/swift-file-system `903f6ca`): 6 sites in 2 files
  - Commit 9f (swift-linux-foundation/swift-linux-standard `128d597`): 3 sites in 2 files (os(Linux)-guarded)
  - Commit 9g (swift-foundations/swift-paths `a624235`): 2 doc-comment sites in 1 test file (Phase 7b coverage completion)

  Scope revision applied mid-execution: per ground rule #6, the
  workspace-wide grep surfaced a 7th package (swift-foundations/swift-paths
  Tests) beyond the original 6-package Phase 9 scope. Principal ruled
  Option A (fold as 9g) — the coverage gap from Phase 7b.

  Execution order reversed from the plan's prescription: plan said
  9a → 9b → 9c, but swift-kernel (9b) cascade-depends on swift-posix
  (9c) through Kernel.File.Flush+CrossPlatform.POSIX. Actual order was
  9a → 9c → 9b → 9e → 9d → 9f → 9g. Within swift-foundations, the dep
  direction is file-system → kernel → posix → iso-9945 (reverse-topological
  for migration).

  Ecosystem-wide build gate: clean `swift build` green in
  swift-darwin, swift-linux, swift-windows, swift-io, swift-iso-32000.
  Pre-existing failures unrelated to this cascade: swift-loader
  (missing `Darwin_Primitives` module; pre-existing), swift-rfc-4122
  (product-name mismatch to swift-linux-standard; pre-existing). Neither
  references the renamed surface.

  Storage / bridge / plan-doc-trail: the cascade preserves every
  principal ruling (§8.1 foundations Path.View cascade, §8.2 accessor
  names, §8.4 Option A DECISION shape). No DECISION revision.

- **1.3.0 (2026-04-22)** — Post-execution principal audit surfaced two material
  defects in the v1.2.0 "IMPLEMENTED" claim. Status downgraded to
  **PARTIAL_IMPLEMENTED** until Phase 9 closes.

  **Defect 1 — Incomplete consumer sweep (~100 Sources + ~8 Tests sites
  across 6 packages).** The plan's Consumer Sweep grep scope covered only
  swift-primitives, swift-standards, and swift-foundations top-level dirs.
  It did NOT include the parallel org-level repos under /Users/coen/Developer/:

  | Package | Sources sites | Build status |
  |---------|---------------|--------------|
  | `swift-iso/swift-iso-9945` | 48 | FAIL — `'View' is not a member type of Kernel.String` |
  | `swift-foundations/swift-kernel` | 25 | cascade-FAIL via iso-9945 dep |
  | `swift-foundations/swift-posix` | 10 | FAIL |
  | `swift-microsoft/swift-windows-standard` | 8 | FAIL |
  | `swift-foundations/swift-file-system` | 6 | FAIL |
  | `swift-linux-foundation/swift-linux-standard` | 3 | FAIL |

  Subordinate attribution: marked "all build green" from per-sub-repo
  isolated builds; did not run ecosystem-wide cascade builds against
  transitive consumers outside the prescribed grep scope.

  Principal attribution: plan's grep scope was too narrow; it scoped to
  the three top-level ecosystem repos rather than the full
  `/Users/coen/Developer/` workspace.

  **Defect 2 — v1.1.0 attribution misleading.** The v1.1.0 entry stated
  "Principal accepted the plan and resolved both open questions" and then
  listed the flag-day collapse (Phase 2+6 merge) under the same heading.
  That conflated two distinct authorization channels: the §8.1 / §8.2
  resolutions were class-(b) principal rulings, whereas the flag-day
  collapse was authorized by the user's "lets do it in one go, so collapse
  the plan" directive (2026-04-22) — NOT by the §8.1/§8.2 rulings.

  **Phase 9 added**: Cover the 6 missed packages. Grep scope expanded
  workspace-wide. Tests build required, not only Sources. Ecosystem-wide
  build verification gate before re-marking IMPLEMENTED.

- **1.2.0 (2026-04-22)** — [SUPERSEDED by 1.3.0 PARTIAL_IMPLEMENTED]
  Plan reported as executed end-to-end. 10 commits landed across
  9 sub-repos; claimed "all build green" — claim was based on isolated
  per-sub-repo builds, missing transitive-consumer cascade breakage
  across 6 packages outside the prescribed grep scope. Commits landed by
  this revision:
  - Commit 1 (swift-ownership-primitives `b3eb11b`): add hoisted protocol + widen Value
  - Commit 1.1 (swift-ownership-primitives `7eb00b6`): storage correction — migrate `UnsafePointer<Value>` to `UnsafeRawPointer` because stdlib's typed pointer requires Value: Escapable. Typed construction API moved into `where Value: ~Copyable` extensions
  - Commit 2 (swift-identity-primitives `9ac9b04`): flag-day — add new Tagged conformance + delete legacy Viewable
  - Commit 3 (swift-string-primitives `647e5bb`): String.View → String.Borrowed
  - Commit 4 (swift-path-primitives `4780d72`): Path.View → Path.Borrowed; ecosystem re-green point (within the 9 planned sub-repos; transitive consumers NOT rebuilt at this point)
  - Commit 5a (swift-kernel-primitives `e390b0e`): consumer sweep
  - Commit 5b (swift-loader-primitives `11b3440`): consumer sweep
  - Commit 6 (swift-darwin-standard `95350ef`): consumer sweep (~19 sites)
  - Commit 7a (swift-foundations/swift-strings `989b0a6`): String_Primitives.String.View → .Borrowed (7 sites across 3 files)
  - Commit 7b (swift-foundations/swift-paths `0ecc4d2`): parallel Path.View cascade (§8.1)
  - §8.4 escalation surfaced mid-execution (protocol Self suppressions) → principal resolved Option A (keep DECISION shape)

- **1.1.0 (2026-04-22)** — Plan updated to record:
  - Principal's §8.1 class-(b) ruling: cascade the foundations parallel
    `Path.View` rename to `Path.Borrowed` (Phase 7b).
  - Principal's §8.2 class-(b) ruling: keep accessor property names
    (`view`, `nameView`, `kernelPath`) unchanged; only return types migrate.
  - User directive (2026-04-22, "lets do it in one go, so collapse the
    plan"): adopt **flag-day migration** — collapse the original 8-phase
    sequence (which kept legacy `Viewable` alive through Phase 5) into a
    7-phase / 9-commit sequence in which old Phase 2 (add new conformance)
    and old Phase 6 (delete legacy) merge into the new Phase 2.
    Intermediate state between commits 2 and 4 will not build in
    string-primitives / path-primitives (flag-day window); ecosystem
    re-greens at commit 4. Per-sub-repo rollback granularity preserved.

  Prior (now obsolete) v1.1.0 entry attributed the flag-day collapse to
  the principal's accepted-rulings — this conflation is corrected in the
  v1.3.0 revision above.
  - §8.1 foundations parallel `Path.View` → **cascade the rename** (now Phase 7b).
  - §8.2 accessor property names → **keep `view` / `nameView`**; only return
    types change.
  - Execution approach: **flag-day migration**. Collapsed from the original
    8-phase sequence (which kept legacy `Viewable` alive through Phase 5)
    into a 7-phase / 9-commit sequence in which old Phase 2 (add new
    conformance) and old Phase 6 (delete legacy) merge into the new Phase 2.
    Intermediate state between commits 2 and 4 will not build in
    string-primitives / path-primitives because they reference the just-deleted
    `Viewable` symbols; the ecosystem re-greens at commit 4. Per-sub-repo
    rollback granularity is preserved (`git revert HEAD` in reverse order).
- **1.0.0 (2026-04-22)** — initial draft. Eight phases; two open questions
  (foundations parallel `Path.View`; accessor property name).

## Context

The frozen DECISION at `swift-primitives/Research/ownership-borrow-protocol-unification.md`
(v1.0.0, 2026-04-22, tier 2, cross-package) adopts **Option C** — restructure
`Viewable` as `Ownership.Borrow.\`Protocol\`` via a hoisted module-scope protocol
exposed through a nested typealias inside the generic struct `Ownership.Borrow<Value>`.
Empirical validation landed in `swift-primitives/Experiments/ownership-borrow-protocol-unification/`
(CONFIRMED on Apple Swift 6.3.1, 2026-04-22) across 10 variants.

This document is the phase-ordered execution plan for that DECISION. It prescribes
file-level diffs, a dependency-safe phase order, the grep-backed consumer
sweep, per-phase verification commands, rollback steps, and open questions
that require principal input.

**No source files are edited by this document.** Execution happens in a
subsequent session with explicit user authorization per the supervisor
scope-lock-before-execution-lock rule.

## Scope & Constraints

### Pre-release status

The ecosystem is pre-1.0; no backward-compatibility contract binds this
work. Downstream consumers cascade by rename, not by typealias bridge.

### Supervisor ground rules honored by this plan

1. **Plan implements; does not revisit.** The DECISION is frozen. This plan
   treats V8 (hoisted protocol + nested typealias in the struct body) as the
   production shape; V9 (typealias in extension) is rejected as fragile.

2. **No new primitives package.** The hoisted protocol lives at module
   scope inside `swift-ownership-primitives`, alongside `Ownership.Borrow<Value>`.

3. **No `.Generic` suffix; no gerund typealias.** The generic struct
   remains `Ownership.Borrow<Value>`; the canonical conformance spelling
   is `Ownership.Borrow.\`Protocol\`` without a top-level typealias
   (`Borrowing` is forbidden by collision with the `borrowing` parameter
   modifier; [PKG-NAME-002] permits omission when no natural gerund applies).

4. **Plan-only.** Execution requires a subsequent authorization. No `.swift`
   or `Package.swift` edits are prescribed in this session.

### Adjacent work explicitly out of scope

- The `swift-identity-primitives` → `swift-tagged-primitives` package rename
  ([PKG-NAME-001]) is scheduled as separate work. This plan MAY mention
  interaction points but MUST NOT prescribe the rename itself. The file
  `Viewable.swift` deletion IS in scope here; the containing-package
  rename is NOT.

- Ecosystem-wide decisions beyond the four primary packages unless the
  grep sweep surfaced them. The sweep surfaced exactly one non-obvious
  case — the parallel `Path.View` type declaration in
  `swift-foundations/swift-paths` — which is escalated per §8.

## Phase Plan

### Build-order dependency graph (collapsed — flag-day)

```
Phase 1 — swift-ownership-primitives   commit 1  protocol + widening + typealias
                      ↓
Phase 2 — swift-identity-primitives    commit 2  ADD new conformance + DELETE Viewable.swift
                                                 + DELETE Tagged+Viewable.swift
                      ↓
Phase 3 — swift-string-primitives      commit 3  String.View → String.Borrowed,
                                                 Viewable → Ownership.Borrow.`Protocol`
                      ↓
Phase 4 — swift-path-primitives        commit 4  Path.View → Path.Borrowed,
                                                 Viewable → Ownership.Borrow.`Protocol`,
                                                 cascade String.Borrowed refs
                      ↓
Phase 5 — primitives consumer sweep    commit 5a swift-kernel-primitives
                                       commit 5b swift-loader-primitives
                      ↓
Phase 6 — swift-standards sweep        commit 6  swift-darwin-standard (~19 sites)
                      ↓
Phase 7 — foundations sweep            commit 7a swift-foundations/swift-strings (1 site)
                                       commit 7b swift-foundations/swift-paths (parallel
                                                 Path.View rename per §8.1 resolution)
```

Each commit is atomic within its sub-repo. Phase order is mandatory;
within-phase commits (5a/5b, 7a/7b) can be in any order since their
sub-repos are independent after Phase 4 lands.

**Flag-day intermediate-build window**: between commits 2 and 4, running
`swift build` in swift-string-primitives or swift-path-primitives will
fail — those packages reference the `Viewable` symbols that commit 2
deletes, and their own conformances do not re-green until their commits
(3 and 4) land. `swift build` in swift-ownership-primitives and
swift-identity-primitives is green throughout. By commit 4 the full
primitives graph builds again; commits 5–7 cascade downstream consumers.

Final ecosystem verification runs after commit 7b (§Verification Checklist).

### Dependency reasoning per commit

| Commit | Depends on | Why |
|--------|-----------|-----|
| 1 | — | `Ownership.Borrow<Value>` has zero inbound deps from the affected packages; stands alone |
| 2 | 1 | `Tagged+Ownership.Borrow.Protocol.swift` imports `Ownership_Primitives`; the same commit deletes the legacy `Viewable` protocol and `Tagged+Viewable` conformance |
| 3 | 1, 2 | `String.Borrowed.swift` imports `Ownership_Primitives`; String's old `extension String: Viewable` would dangle against commit 2's deletion, so commit 3 replaces it with `extension String: Ownership.Borrow.\`Protocol\`` |
| 4 | 1, 2, 3 | `Path.Borrowed.swift` imports `Ownership_Primitives`; `Path.swift` / `Tagged+Path.swift` / `Path.String.swift` reference `String_Primitives.String.Borrowed` from commit 3 |
| 5a, 5b | 3, 4 | kernel-primitives / loader-primitives reference `Kernel.Path.Borrowed` (= `Path.Borrowed` via Tagged parametric forwarding) and `String.Borrowed` |
| 6 | 3, 4 | swift-darwin-standard references `Kernel.Path.Borrowed` and `String.Borrowed` |
| 7a | 3 | swift-strings references `String.Borrowed` |
| 7b | 4 | swift-paths' own `Path.View` cascades to `Path.Borrowed` per the principal's §8.1 resolution |

## Per-Package Diff Sketches

All snippets are illustrative — no execution in this session.

### Phase 1 — swift-ownership-primitives

**Add new file**: `Sources/Ownership Primitives/__Ownership_Borrow_Protocol.swift`

```swift
// ===----------------------------------------------------------------------===//
// swift-primitives — Apache License v2.0
// ===----------------------------------------------------------------------===//

/// Module-scope hoisted protocol for `Ownership.Borrow.\`Protocol\``.
///
/// Use the canonical spelling `Ownership.Borrow.\`Protocol\`` at
/// conformance sites. This `__`-prefixed declaration is the
/// implementation-detail target of the nested typealias inside
/// `Ownership.Borrow<Value>` and is not intended for direct use.
///
/// Precedent: `swift-tree-primitives`'s `__TreeNChildSlot<n>` pattern
/// (hoisted for value-generic nesting limitations, exposed as
/// `Tree<E>.N<n>.ChildSlot`). SE-0404 opened non-generic nesting only;
/// direct nesting in generic contexts (like `Ownership.Borrow<Value>`)
/// remains prohibited on Swift 6.3.1.
public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
        = Ownership.Borrow<Self>
}
```

**Edit**: `Sources/Ownership Primitives/Ownership.Borrow.swift`

Widen the `Value` constraint on the struct and every `where Value:`
extension, and expose the nested typealias inside the struct body:

```diff
 extension Ownership {
     @safe
-    public struct Borrow<Value: ~Copyable>: ~Escapable {
+    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {

         @usableFromInline
         let _pointer: UnsafePointer<Value>

         @inlinable
         @_lifetime(borrow pointer)
         public init(_ pointer: UnsafePointer<Value>) {
             unsafe (self._pointer = pointer)
         }
+
+        /// Canonical conformance path for the borrow-capability protocol.
+        ///
+        /// Conform with `extension Path: Ownership.Borrow.\`Protocol\` {}`.
+        /// Resolves to the module-scope `__Ownership_Borrow_Protocol`.
+        public typealias `Protocol` = __Ownership_Borrow_Protocol
     }
 }

-extension Ownership.Borrow where Value: ~Copyable {
+extension Ownership.Borrow where Value: ~Copyable & ~Escapable {
     @inlinable
     @_lifetime(borrow value)
     public init(borrowing value: borrowing Value) {
         unsafe (_pointer = withUnsafePointer(to: value) { unsafe $0 })
     }
 }

-extension Ownership.Borrow where Value: ~Copyable {
+extension Ownership.Borrow where Value: ~Copyable & ~Escapable {
     @unsafe
     @inlinable
     @_lifetime(borrow owner)
     public init<Owner: ~Copyable & ~Escapable>(
         unsafeAddress pointer: UnsafePointer<Value>,
         borrowing owner: borrowing Owner
     ) {
         unsafe (self._pointer = pointer)
     }
 }

-extension Ownership.Borrow where Value: ~Copyable {
+extension Ownership.Borrow where Value: ~Copyable & ~Escapable {
     @inlinable
     public var value: Value {
         _read { yield unsafe _pointer.pointee }
     }
 }
```

**Why every extension must widen**: per [MEM-COPY-004], a `where Value: ~Copyable`
clause that does NOT also name `~Escapable` re-introduces the implicit
`Escapable` requirement on Value inside that extension. The struct's Value
admits `~Escapable` types after Phase 1; the extensions must match or they
silently exclude the new conformers.

**No Package.swift change** for swift-ownership-primitives. `Lifetimes` and
`SuppressedAssociatedTypes` are already enabled via the `ecosystem` settings
array (verified — `Package.swift:38-55`).

### Phase 2 — swift-identity-primitives (add new, DELETE legacy; single commit)

**Package.swift edit**: add dep on swift-ownership-primitives.

```diff
 let package = Package(
     name: "swift-identity-primitives",
     ...
+    dependencies: [
+        .package(path: "../swift-ownership-primitives"),
+    ],
     targets: [
-        .target(
-            name: "Identity Primitives"
-        ),
+        .target(
+            name: "Identity Primitives",
+            dependencies: [
+                .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
+            ]
+        ),
         ...
     ]
 )
```

**Add new file**: `Sources/Identity Primitives/Tagged+Ownership.Borrow.Protocol.swift`

```swift
// ===----------------------------------------------------------------------===//
// swift-identity-primitives — Apache License v2.0
// ===----------------------------------------------------------------------===//

public import Ownership_Primitives

// MARK: - Ownership.Borrow.`Protocol` Conformance

extension Tagged: Ownership.Borrow.`Protocol`
where RawValue: Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable {
    /// Resolves `Tagged<Tag, RawValue>.Borrowed` to `RawValue.Borrowed`.
    ///
    /// Type identity is preserved — `Tagged<Kernel, Path>.Borrowed` IS
    /// `Path.Borrowed`, not a wrapper. Functions accepting
    /// `borrowing Path.Borrowed` accept `borrowing Tagged<Kernel, Path>.Borrowed`
    /// without conversion.
    public typealias Borrowed = RawValue.Borrowed
}
```

**Delete in the same commit** (flag-day):
- `Sources/Identity Primitives/Viewable.swift`
- `Sources/Identity Primitives/Tagged+Viewable.swift`

**Consequence of flag-day deletion**: between commit 2 (this one) and
commit 4 (path-primitives migration), running `swift build` in
swift-string-primitives or swift-path-primitives will fail because each
still contains `extension String: Viewable {}` / `extension Path: Viewable {}`
referencing a symbol that no longer exists. This broken intermediate is
accepted per the principal's flag-day directive; final ecosystem
verification runs after commit 7b. swift-identity-primitives itself
builds green at the end of commit 2 because Tagged's parametric
conformance is switched to `Ownership.Borrow.\`Protocol\``.

### Phase 3 — swift-string-primitives

**Package.swift edit**: add dep on swift-ownership-primitives.

```diff
 dependencies: [
     .package(path: "../swift-ascii-primitives"),
     .package(path: "../swift-memory-primitives"),
     .package(path: "../swift-identity-primitives"),
+    .package(path: "../swift-ownership-primitives"),
 ],
 targets: [
     .target(
         name: "String Primitives",
         dependencies: [
             .product(name: "ASCII Primitives", package: "swift-ascii-primitives"),
             .product(name: "Memory Primitives Core", package: "swift-memory-primitives"),
             .product(name: "Identity Primitives", package: "swift-identity-primitives"),
+            .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
         ],
         ...
     ),
 ]
```

**Rename**: `Sources/String Primitives/String.View.swift` → `String.Borrowed.swift`

Inside the renamed file:

```diff
-public import Identity_Primitives
+public import Ownership_Primitives

-// MARK: - Viewable Conformance
-
-extension String: Viewable {}
+// MARK: - Ownership.Borrow.`Protocol` Conformance
+
+extension String: Ownership.Borrow.`Protocol` {}

-// MARK: - View
+// MARK: - Borrowed

 extension String {
     @safe
-    public struct View: ~Copyable, ~Escapable {
+    public struct Borrowed: ~Copyable, ~Escapable {
         public let pointer: UnsafePointer<Char>
         public let count: Int

         @inlinable
         @_lifetime(borrow pointer)
         public init(_ pointer: UnsafePointer<String.Char>, count: Int) {
             #if DEBUG
             unsafe Self.debugValidateTermination(pointer)
             #endif
             unsafe (self.pointer = pointer)
             self.count = count
         }
     }
 }

 #if DEBUG
-extension String.View {
+extension String.Borrowed {
     ...
-        assertionFailure("String.View: pointer does not appear ...")
+        assertionFailure("String.Borrowed: pointer does not appear ...")
 }
 #endif

-extension String.View {
+extension String.Borrowed {
     @unsafe
     @inlinable
     public borrowing func withUnsafePointer<R: ~Copyable, E: Error>(
         _ body: (UnsafePointer<String.Char>) throws(E) -> R
     ) throws(E) -> R { ... }

     @inlinable
     public var length: Int { count }

     @inlinable
     public var span: Span<String.Char> { ... }
 }
```

**Rename**: `Sources/String Primitives/Tagged+String.View.swift` → `Tagged+String.Borrowed.swift`

Inside:

```diff
-    public var view: String.View {
+    public var view: String.Borrowed {
         ...
     }
```

**Edit**: `Sources/String Primitives/String.swift`

```diff
 // line 87:
-    public init(copying view: borrowing String.View) {
+    public init(copying view: borrowing String.Borrowed) {

 // line 150–152:
-    public var view: String.View {
+    public var view: String.Borrowed {
         @_lifetime(borrow self) borrowing get {
-            let view = unsafe String.View(_storage.unsafeBaseAddress, count: _storage.count)
+            let view = unsafe String.Borrowed(_storage.unsafeBaseAddress, count: _storage.count)
             return unsafe _overrideLifetime(view, borrowing: self)
         }
     }
```

**Edit**: `Sources/String Primitives/Tagged+String.swift`

```diff
 // line 52:
-    public init(copying view: borrowing String.View) {
+    public init(copying view: borrowing String.Borrowed) {
```

### Phase 4 — swift-path-primitives

**Package.swift edit**: add dep on swift-ownership-primitives (analogous to Phase 3).

**Rename**: `Sources/Path Primitives/Path.View.swift` → `Path.Borrowed.swift`

Inside — symmetric to String Phase 3:

```diff
-public import Identity_Primitives
+public import Ownership_Primitives

-extension Path: Viewable {}
+extension Path: Ownership.Borrow.`Protocol` {}

 extension Path {
-    public struct View: ~Copyable, ~Escapable {
+    public struct Borrowed: ~Copyable, ~Escapable {
         public let pointer: UnsafePointer<Char>
         public let count: Int
         ...
     }
 }

-extension Path.View {
+extension Path.Borrowed {
     ...  // withUnsafePointer, span, debugValidateTermination
 }

 extension Path {
-    public var view: View {
+    public var view: Borrowed {
         @_lifetime(borrow self) borrowing get {
-            let view = unsafe View(_storage.unsafeBaseAddress, count: _storage.count)
+            let view = unsafe Borrowed(_storage.unsafeBaseAddress, count: _storage.count)
             return unsafe _overrideLifetime(view, borrowing: self)
         }
     }
 }
```

**Edit**: `Sources/Path Primitives/Path.swift` — line 89: `String_Primitives.String.View` → `String_Primitives.String.Borrowed` (Phase 3 already landed).

**Edit**: `Sources/Path Primitives/Tagged+Path.swift` — lines 55 and 80:

```diff
-    public init(copying view: borrowing String_Primitives.String.View) {
+    public init(copying view: borrowing String_Primitives.String.Borrowed) {

-    public var view: Path.View {
+    public var view: Path.Borrowed {
```

**Edit**: `Sources/Path Primitives/Path.String.swift` — 7 closure parameter
signatures at lines 142, 167, 184, 201, 233, 254, 296:

```diff
-    _ body: (borrowing Path.View) throws(E) -> R
+    _ body: (borrowing Path.Borrowed) throws(E) -> R

 (and symmetric for 2-path and 3-path overloads)
```

**Edit**: `Sources/Path Primitives/Path.Scan.swift` — line 26: doc comment
`Path.View` → `Path.Borrowed`.

**Edit**: `Sources/Path Primitives/Path.Decomposition.swift` — line 20: doc
comment `Path.View` → `Path.Borrowed`. The protocol definition `Path.Decomposition`
itself is unaffected (it does not name Path.View; it references `Self`).

### Phase 5 — downstream primitives sweep (kernel-primitives, loader-primitives)

**swift-kernel-primitives**:

- `Sources/Kernel File Primitives/Kernel.Directory.Entry.swift` lines 98, 103, 107:
  - line 98: doc comment `Kernel.Path.View` → `Kernel.Path.Borrowed`
  - line 103: `public var nameView: Kernel.Path.View` → `Kernel.Path.Borrowed`
    (and possibly rename `nameView` → `nameBorrowed` per Open Question §8.2)
  - line 107: `unsafe Kernel.Path.View(ptr, count: rawName.count - 1)` → `Kernel.Path.Borrowed(...)`
- `Sources/Kernel File Primitives/Kernel.File.Direct.Requirements.swift` line 59:
  - `public init(_ path: borrowing Path.View)` → `Path.Borrowed`
- `Tests/Kernel Path Primitives Tests/Kernel.Path Tests.swift` lines 140, 143:
  - test references `String_Primitives.String.View` → `String.Borrowed`
- `Tests/Kernel Path Primitives Tests/Kernel.Path.String Tests.swift` line 155:
  - `borrowing Path.View` → `Path.Borrowed`

**swift-loader-primitives**:

- `Sources/Loader Primitives/Loader.Error.swift` line 77:
  - `public init(copying view: borrowing String_Primitives.String.View)` → `String.Borrowed`

### Phase 6 — swift-standards sweep (swift-darwin-standard)

Mechanical `Kernel.Path.View` → `Kernel.Path.Borrowed` and
`String_Primitives.String.View` → `String.Borrowed` across:

- `Sources/Darwin Kernel Standard/Darwin.Kernel.File.Attributes.Extended.swift` — 4 sites (lines 391, 412, 453, 494)
- `Sources/Darwin Kernel Standard/Darwin.Kernel.File.Move.Extensions.swift` — 4 sites (lines 51, 52, 91, 92)
- `Sources/Darwin Kernel Standard/Darwin.Kernel.File.Clone.swift` — 8 sites (lines 21, 47, 68, 69, 94, 95, 119, 120)
- `Sources/Darwin Kernel Standard/Darwin.Kernel.Copy.Clone.swift` — 2 sites (lines 71, 72)
- `Sources/Darwin Loader Standard/Loader.Symbol+Darwin.swift` — 1 site (line 97)

### Phase 7 — swift-foundations sweep

- `swift-strings/Sources/Strings/Swift.String+Primitives.POSIX.swift` line 25:
  - `public init(_ view: borrowing String_Primitives.String.View)` → `String.Borrowed`

- `swift-paths/Sources/Paths/Path.View.swift` — **cascade the rename** per
  the principal's §8.1 resolution (2026-04-22). This file declares a
  parallel `Path.View` nested struct in foundations' own `Path` type (a
  separate type declaration, not merely a call site referring to primitives'
  `Path.View`). Treatment: rename the file → `Path.Borrowed.swift`; rename
  the nested `struct View` → `struct Borrowed`; update all three
  `extension Path.View { ... }` blocks (lines 41, 68, 127) → `extension Path.Borrowed`;
  update the `var kernelPath: Kernel.Path.View` accessor at line 132 to
  return `Kernel.Path.Borrowed`. The accessor property name `kernelPath`
  stays per §8.2's ruling.

## Consumer Sweep

### Grep commands used (reproducible)

```bash
# Conformance / constraint / doc sites (protocol dispatch):
grep -rn -E ": Viewable|extension Viewable|Viewable &|Viewable,|: *Viewable$" \
  /Users/coen/Developer/swift-primitives \
  /Users/coen/Developer/swift-standards \
  /Users/coen/Developer/swift-foundations \
  --include="*.swift" | grep -v Experiments

# Nested-type references (Path.View / String.View / Kernel.Path.View / Tagged.View):
grep -rn -E "\bPath\.View\b|\bString\.View\b|Tagged.*\.View\b|\.View<" \
  /Users/coen/Developer/swift-primitives \
  /Users/coen/Developer/swift-standards \
  /Users/coen/Developer/swift-foundations \
  --include="*.swift" | grep -v Experiments

# Extension declarations on the renamed types:
grep -rn -E "extension Path\.View|extension String\.View|: Path\.View|: String\.View" \
  /Users/coen/Developer/swift-primitives \
  /Users/coen/Developer/swift-standards \
  /Users/coen/Developer/swift-foundations \
  --include="*.swift" | grep -v Experiments
```

Results below filter out the unrelated namespaces `Sequence.Consume.View`,
`Collection.Remove.View`, `Collection.Count.View`, and `Property.View`
(distinct types whose grep output overlaps but which are NOT in scope).

### 1. Viewable protocol conformance / constraint sites

Three conformance sites plus one doc-comment reference — zero generic-dispatch uses
(confirmed by DECISION doc §Context, re-verified here):

| File:Line | Current | Expected rewrite |
|-----------|---------|-----------------|
| `swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift:14` | `extension Tagged: Viewable where RawValue: Viewable & ~Copyable, Tag: ~Copyable { public typealias View = RawValue.View }` | Phase 2: ADD a new file `Tagged+Ownership.Borrow.Protocol.swift` with body `extension Tagged: Ownership.Borrow.\`Protocol\` where RawValue: Ownership.Borrow.\`Protocol\` & ~Copyable, Tag: ~Copyable { public typealias Borrowed = RawValue.Borrowed }`; DELETE this legacy file in the same commit. |
| `swift-identity-primitives/Sources/Identity Primitives/Viewable.swift:24` | `public protocol Viewable: ~Copyable { associatedtype View: ~Copyable, ~Escapable }` | DELETE file in Phase 2 (flag-day). |
| `swift-path-primitives/Sources/Path Primitives/Path.View.swift:20` | `extension Path: Viewable {}` | Phase 4: `extension Path: Ownership.Borrow.\`Protocol\` {}` |
| `swift-string-primitives/Sources/String Primitives/String.View.swift:18` | `extension String: Viewable {}` | Phase 3: `extension String: Ownership.Borrow.\`Protocol\` {}` |
| `swift-identity-primitives/Sources/Identity Primitives/Viewable.swift:21` | Doc comment: `/// extension Path: Viewable {}` | DELETED with file in Phase 2. |

### 2. Nested-type definition sites

| File:Line | Current | Expected rewrite | Phase |
|-----------|---------|------------------|-------|
| `swift-path-primitives/.../Path.View.swift:35` | `public struct View: ~Copyable, ~Escapable` | `public struct Borrowed: ~Copyable, ~Escapable`; file renamed → `Path.Borrowed.swift` | 4 |
| `swift-path-primitives/.../Path.View.swift:62, 86` | `extension Path.View { ... }` (two blocks) | `extension Path.Borrowed { ... }` | 4 |
| `swift-string-primitives/.../String.View.swift:33` | `public struct View: ~Copyable, ~Escapable` | `public struct Borrowed`; file renamed → `String.Borrowed.swift` | 3 |
| `swift-string-primitives/.../String.View.swift:60, 84` | `extension String.View { ... }` (two blocks) | `extension String.Borrowed { ... }` | 3 |

### 3. Accessor properties returning the renamed type

| File:Line | Current | Expected rewrite | Phase |
|-----------|---------|------------------|-------|
| `swift-path-primitives/.../Path.View.swift:113` | `public var view: View` | `public var view: Borrowed` (see Open Q §8.2 about accessor name) | 4 |
| `swift-path-primitives/.../Tagged+Path.swift:80` | `public var view: Path.View` | `public var view: Path.Borrowed` | 4 |
| `swift-string-primitives/.../String.swift:150` | `public var view: String.View` | `public var view: String.Borrowed` | 3 |
| `swift-string-primitives/.../Tagged+String.View.swift:27` | `public var view: String.View` (file also renamed → `Tagged+String.Borrowed.swift`) | `public var view: String.Borrowed` | 3 |
| `swift-kernel-primitives/.../Kernel.Directory.Entry.swift:103` | `public var nameView: Kernel.Path.View` | `public var nameView: Kernel.Path.Borrowed` (see Open Q §8.2) | 5 |

### 4. Call-site parameter / return / construction references

**In swift-primitives (Phase 3, 4, 5)**:

| File:Line | Current | Expected rewrite | Phase |
|-----------|---------|------------------|-------|
| `swift-path-primitives/.../Path.swift:89` | `init(copying view: borrowing String_Primitives.String.View)` | `…String.Borrowed` | 4 |
| `swift-path-primitives/.../Path.String.swift:142, 167, 184, 201, 233, 254, 296` | 7 × `(borrowing Path.View)` closure-param signatures | 7 × `(borrowing Path.Borrowed)` | 4 |
| `swift-path-primitives/.../Tagged+Path.swift:55` | `init(copying view: borrowing String_Primitives.String.View)` | `…String.Borrowed` | 4 |
| `swift-path-primitives/.../Path.Scan.swift:26` | Doc comment `Path.View` | Doc comment `Path.Borrowed` | 4 |
| `swift-path-primitives/.../Path.Decomposition.swift:20` | Doc comment `Path.View` (references platform-package conformer) | Doc comment `Path.Borrowed` | 4 |
| `swift-string-primitives/.../String.swift:87` | `init(copying view: borrowing String.View)` | `…String.Borrowed` | 3 |
| `swift-string-primitives/.../String.swift:152` | `let view = unsafe String.View(...)` | `String.Borrowed(...)` | 3 |
| `swift-string-primitives/.../Tagged+String.swift:52` | `init(copying view: borrowing String.View)` | `…String.Borrowed` | 3 |
| `swift-kernel-primitives/.../Kernel.Directory.Entry.swift:98` | Doc `Kernel.Path.View` | Doc `Kernel.Path.Borrowed` | 5 |
| `swift-kernel-primitives/.../Kernel.Directory.Entry.swift:107` | `unsafe Kernel.Path.View(ptr, count: rawName.count - 1)` | `Kernel.Path.Borrowed(…)` | 5 |
| `swift-kernel-primitives/.../Kernel.File.Direct.Requirements.swift:59` | `init(_ path: borrowing Path.View)` | `…Path.Borrowed` | 5 |
| `swift-kernel-primitives/Tests/.../Kernel.Path Tests.swift:140, 143` | `String_Primitives.String.View(...)` | `String.Borrowed(…)` | 5 |
| `swift-kernel-primitives/Tests/.../Kernel.Path.String Tests.swift:155` | `(_ : borrowing Path.View) throws(...)` | `…Path.Borrowed` | 5 |
| `swift-loader-primitives/.../Loader.Error.swift:77` | `init(copying view: borrowing String_Primitives.String.View)` | `…String.Borrowed` | 5 |

**In swift-standards (Phase 6)**:

| File:Line | Current | Expected rewrite |
|-----------|---------|------------------|
| `swift-darwin-standard/.../Darwin.Kernel.File.Attributes.Extended.swift:391, 412, 453, 494` | 4 × `path: borrowing Kernel.Path.View` | 4 × `Kernel.Path.Borrowed` |
| `swift-darwin-standard/.../Darwin.Kernel.File.Move.Extensions.swift:51, 52, 91, 92` | 4 × `Kernel.Path.View` | 4 × `Kernel.Path.Borrowed` |
| `swift-darwin-standard/.../Darwin.Kernel.File.Clone.swift:21, 47, 68, 69, 94, 95, 119, 120` | 8 × `Kernel.Path.View` | 8 × `Kernel.Path.Borrowed` |
| `swift-darwin-standard/.../Darwin.Kernel.Copy.Clone.swift:71, 72` | 2 × `Kernel.Path.View` | 2 × `Kernel.Path.Borrowed` |
| `swift-darwin-standard/.../Loader.Symbol+Darwin.swift:97` | `unsafe String_Primitives.String.View(u8Ptr, count: …)` | `String_Primitives.String.Borrowed(…)` |

**In swift-foundations (Phase 7)**:

| File:Line | Current | Expected rewrite |
|-----------|---------|------------------|
| `swift-foundations/swift-strings/Sources/Strings/Swift.String+Primitives.POSIX.swift:25` | `init(_ view: borrowing String_Primitives.String.View)` | `…String.Borrowed` |
| `swift-foundations/swift-paths/Sources/Paths/Path.View.swift` (lines 14, 41, 68, 127, 132) | Parallel `Path.View` type in foundations (distinct from primitives' Path.View) | Phase 7b: rename file → `Path.Borrowed.swift`; `struct View` → `struct Borrowed`; 3 × `extension Path.View` → `extension Path.Borrowed`; return type of `var kernelPath: Kernel.Path.View` → `Kernel.Path.Borrowed` (accessor name `kernelPath` stays per §8.2) |

### Ecosystem-scope summary

| Scope | Files touched | Site count |
|-------|---------------|------------|
| swift-primitives (Phases 1–5) | 14 files across 6 packages | ~30 sites |
| swift-standards (Phase 6) | 5 files in swift-darwin-standard | ~19 sites |
| swift-foundations (Phase 7) | 2 files (swift-strings; swift-paths cascade per §8.1) | ~5 sites |

### Not-in-scope namespaces (explicitly filtered out)

The grep patterns for `.View` overlap with unrelated types. None of the
following are affected by this plan:

- `Sequence.Consume.View<Element, State>` — defined in swift-sequence-primitives; consumed by swift-set-primitives, swift-buffer-primitives. Not a Viewable conformer.
- `Collection.Remove.View<Self>`, `Collection.Count.View<Self>` — defined in swift-collection-primitives. Not Viewable conformers.
- `Property<Tag, Base>.View` — Property.View ecosystem; the `~Copyable` verb-as-property pattern per [IMPL-020]. Distinct from the borrow-capability protocol and out of scope.

## Verification Checklist

Flag-day migration: intermediate state between commits 2 and 4 is
deliberately not green in string/path. Verification runs at the
ecosystem-greening points, not every commit.

| Commit | Expected build state | Reason |
|--------|---------------------|--------|
| 1 | `(cd swift-ownership-primitives && swift build)` → green | protocol added in isolation |
| 2 | `(cd swift-identity-primitives && swift build)` → green; string-primitives and path-primitives will fail from now until commit 4 | legacy Viewable symbols deleted; conformers not yet migrated |
| 3 | `(cd swift-string-primitives && swift build)` → green; path-primitives still fails | String migrated |
| 4 | `(cd swift-string-primitives && swift build)` → green; `(cd swift-path-primitives && swift build)` → green | primitives graph re-green; ecosystem recovery point |
| 5a | `(cd swift-kernel-primitives && swift build)` → green | consumer sweep |
| 5b | `(cd swift-loader-primitives && swift build)` → green | consumer sweep |
| 6 | `(cd swift-standards/swift-darwin-standard && swift build)` → green | standards sweep |
| 7a | `(cd swift-foundations/swift-strings && swift build)` → green | foundations strings |
| 7b | `(cd swift-foundations/swift-paths && swift build)` → green | foundations paths + parallel Path.View cascade |

Final ecosystem-wide verification after commit 7b:

```bash
(cd swift-ownership-primitives && swift build)
(cd swift-identity-primitives && swift build)
(cd swift-string-primitives && swift build)
(cd swift-path-primitives && swift build)
(cd swift-kernel-primitives && swift build)
(cd swift-loader-primitives && swift build)
(cd swift-standards/swift-darwin-standard && swift build)
(cd swift-foundations/swift-strings && swift build)
(cd swift-foundations/swift-paths && swift build)
```

All nine MUST be green. Test suites MAY be run but are not strictly
required; renames are compile-time changes with no runtime semantics.

## Rollback Plan

Each commit is a single atomic landing in its sub-repo. Rollback semantics:

| Commit | Rollback command (from sub-repo root) |
|--------|--------------------------------------|
| 1 | `(cd swift-ownership-primitives && git revert HEAD)` |
| 2 | `(cd swift-identity-primitives && git revert HEAD)` — restores Viewable.swift and Tagged+Viewable.swift |
| 3 | `(cd swift-string-primitives && git revert HEAD)` |
| 4 | `(cd swift-path-primitives && git revert HEAD)` |
| 5a | `(cd swift-kernel-primitives && git revert HEAD)` |
| 5b | `(cd swift-loader-primitives && git revert HEAD)` |
| 6 | `(cd swift-standards/swift-darwin-standard && git revert HEAD)` |
| 7a | `(cd swift-foundations/swift-strings && git revert HEAD)` |
| 7b | `(cd swift-foundations/swift-paths && git revert HEAD)` |

**Cascading rollback**: rolling back an earlier commit invalidates all
later commits. Example: reverting commit 1 (the protocol disappears)
leaves commits 2–7's references to `Ownership.Borrow.\`Protocol\``
dangling. Rollbacks therefore go in reverse chronological order:
7b → 7a → 6 → 5b → 5a → 4 → 3 → 2 → 1.

**Partial-commit failure** (edit applied, build fails, not yet committed):
`git checkout .` within the sub-repo discards the partial work and
restores pre-commit state. No `--amend` or `--force` needed.

**Mid-flag-day abort** (commits 2–3 landed, decide to abort before commit 4):
revert commit 3, then revert commit 2. swift-string-primitives and
swift-path-primitives return to pre-migration Viewable-conforming state
and rebuild cleanly.

## Phase 9 — Ecosystem Completion Sweep (v1.3.0, pending dispatch)

The v1.2.0 "IMPLEMENTED" claim was based on per-sub-repo isolated builds
across the 9 sub-repos touched by Phases 1–7. Transitive consumers in
6 additional packages — outside the original grep scope — were not
rebuilt, and 4 of them fail to compile against the renamed types.

### Missed packages (as of 2026-04-22)

| Repo | Sources sites | Tests sites | Build status |
|------|--------------:|------------:|--------------|
| `swift-iso/swift-iso-9945` | 48 | 0 | FAIL — `'View' is not a member type of generic struct Kernel.String` (aka `Tagged<Kernel, String>`) |
| `swift-foundations/swift-kernel` | 25 | 5 | cascade-FAIL via iso-9945 dep |
| `swift-foundations/swift-posix` | 10 | 1 | FAIL |
| `swift-microsoft/swift-windows-standard` | 8 | 0 | FAIL |
| `swift-foundations/swift-file-system` | 6 | 0 | FAIL |
| `swift-linux-foundation/swift-linux-standard` | 3 | 0 | FAIL |

### Phase 9 recommended order (topological)

| Sub-phase | Package | Reason |
|-----------|---------|--------|
| 9a | `swift-iso/swift-iso-9945` | 48 sites; blocks cascade for swift-kernel + swift-posix + swift-file-system |
| 9b | `swift-foundations/swift-kernel` | 25 sites + 5 Tests; depends on iso-9945 landing first |
| 9c | `swift-foundations/swift-posix` | 10 sites + 1 Test; L3 POSIX layer |
| 9d | `swift-microsoft/swift-windows-standard` | 8 sites; platform standard |
| 9e | `swift-foundations/swift-file-system` | 6 sites; composed filesystem |
| 9f | `swift-linux-foundation/swift-linux-standard` | 3 sites; platform standard |

### Ground rules for Phase 9 dispatch

1. **fact:** 10 commits from Phases 1–7 are landed and valid. Phase 9 extends the cascade; it does not revisit Phases 1–7.
2. **MUST:** Expand the grep scope to the full `/Users/coen/Developer/` workspace, not just the three top-level ecosystem repos. The v1.2.0 defect was rooted in too-narrow grep.
3. **MUST:** Verify via `swift build` in EACH affected consumer package before marking its commit green. Isolated-per-sub-repo-build is insufficient for transitive-consumer cascades.
4. **MUST:** Tests also build (not only Sources). Tests that reference the renamed types must migrate in the same commit.
5. **MUST NOT:** Touch the DECISION doc or Phases 1–7 commit history. Phase 9 is additive.
6. **ask:** Escalate before touching any repo outside the six listed above. If a grep-ecosystem surfaces a 7th package, surface the finding before prescribing its rename.

### Acceptance criteria for Phase 9

1. Each of the 6 packages' `swift build` returns exit 0 (verified by principal running the commands).
2. Each of the 6 packages' `swift build --build-tests` returns exit 0 (Tests included).
3. Ecosystem-wide verification: `swift build` in every transitive consumer of ownership-primitives / string-primitives / path-primitives / kernel-primitives succeeds. (Scope: all packages under `/Users/coen/Developer/` whose Package.swift references any of those primitives, directly or transitively.)
4. No residual `.View` references on the renamed namespace surface. Grep cleanup across the full workspace yields zero matches for: `Path.View`, `String.View` (String_Primitives-qualified), `Kernel.Path.View`, `Kernel.String.View`, `Tagged.View`. (`ISO_9899.String.View` is out of scope — separate parallel type.)

### Phase 9 handoff

Detailed Phase 9 execution brief: `/Users/coen/Developer/HANDOFF-borrow-protocol-unification-phase-9.md` (drafted 2026-04-22, pending user authorization before subordinate dispatch).

## Principal Resolutions

### §8.1 Treatment of the foundations parallel `Path.View` type — RESOLVED 2026-04-22

**Finding**: `swift-foundations/swift-paths/Sources/Paths/Path.View.swift`
declares a separate nested `Path.View` struct inside swift-paths's own
`Path` type (not the primitives Path). Three `extension Path.View` blocks
extend it; one accessor (`var kernelPath: Kernel.Path.View`) bridges to
primitives.

**Ruling (principal, 2026-04-22)**: **cascade the rename**. Execute in
commit 7b. The primitives and foundations `Path.View` types are
conceptually identical (null-terminated, ~Escapable borrow over a Path);
diverging names across layers would undermine the ecosystem-coherence
rationale that motivated the DECISION. Rationale per principal: the
"update downstream to match" directive covers parallel type declarations,
not only call sites.

**Execution**:
- Rename file `swift-foundations/swift-paths/Sources/Paths/Path.View.swift`
  → `Path.Borrowed.swift`
- Inside: `struct View: ~Copyable, ~Escapable` → `struct Borrowed: ~Copyable, ~Escapable`
- Three `extension Path.View { ... }` blocks (lines 41, 68, 127) →
  `extension Path.Borrowed { ... }`
- `var kernelPath: Kernel.Path.View` (line 132) → return type
  `Kernel.Path.Borrowed`; accessor name `kernelPath` stays per §8.2.

### §8.2 Accessor property name — RESOLVED 2026-04-22

**Finding**: Every renamed type is exposed through an accessor property
whose name is literally `view` or contains `View`:

- `Path.view: Path.View`
- `String.view: String.View`
- `Tagged.view: Path.View` in `Tagged+Path.swift`, `Tagged+String.View.swift`
- `Kernel.Directory.Entry.nameView: Kernel.Path.View`
- `Path.kernelPath: Kernel.Path.View` (foundations)

**Ruling (principal, 2026-04-22)**: **keep accessor names as-is**. Only
the return types change. `view` (noun/verb) and `nameView` /
`kernelPath` remain. Rationale per principal: verb-as-property per
[IMPL-020], role-over-type per [API-IMPL-013]. The accessor's role
("expose a view of") is unchanged by renaming the borrowed type.

**Execution**: in every commit where a `View`-typed property's return
type changes, rename ONLY the return type, not the property name:

- `public var view: View` → `public var view: Borrowed` (Path, String)
- `public var view: Path.View` → `public var view: Path.Borrowed` (Tagged+Path, Tagged+String)
- `public var nameView: Kernel.Path.View` → `public var nameView: Kernel.Path.Borrowed`
- `public var kernelPath: Kernel.Path.View` → `public var kernelPath: Kernel.Path.Borrowed`

### §8.4 Protocol Self suppressions — RESOLVED 2026-04-22 (Option A — keep DECISION shape)

**Finding surfaced during execution (commits 7eb00b6 and 9ac9b04 landed).**
The DECISION prescribes protocol Self as `~Copyable, ~Escapable`, which
forced a storage rewrite from `UnsafePointer<Value>` to `UnsafeRawPointer`
because stdlib's `UnsafePointer<Pointee>` requires `Pointee: Escapable`.
Cross-referencing with `swift-property-primitives` (the ecosystem's
comparable pattern) shows a deliberately narrower shape:

| Type | `Self`/`Base` suppressions | Storage |
|------|---------------------------|---------|
| `Property<Tag, Base>` | `Base: ~Copyable` (Escapable implicit) | `UnsafeMutablePointer<Base>` — typed |
| `Property.View` | `Base: ~Copyable` (Escapable implicit) | `UnsafeMutablePointer<Base>` — typed |
| Original `Viewable` protocol | `Self: ~Copyable` only | (no storage) |
| DECISION's `Ownership.Borrow.\`Protocol\`` | `Self: ~Copyable, ~Escapable` | — |

All current conformer classes (A, B, C from the DECISION's framing) are
Escapable types — Ordinal/Cardinal (Case A), Path/String (Case B),
Tagged (Case C). **No current conformer is `~Escapable`.** The
`~Escapable` admission on Self is speculative surface area.

**Options**:

1. **Keep DECISION shape** (Self: ~Copyable & ~Escapable; UnsafeRawPointer storage). Current commits 7eb00b6 + 9ac9b04 stand. Future ~Escapable conformers possible (no known consumer).
2. **Narrow Self to `~Copyable`** (matches Viewable + property-primitives). Revert 7eb00b6; keep the protocol hoisting and typealias + identity-primitives flag-day. Storage stays `UnsafePointer<Value>`. Zero production API break, aligns with ecosystem pattern.

**Recommendation**: Option 2 (narrow). Matches property-primitives, no speculative surface, simpler storage. If a future ~Escapable conformer needs the protocol, the widening can be performed then with a real use case to guide the storage decision.

**Consequence for DECISION doc**: Option 2 requires a small DECISION revision (version bump to 1.1.0) — narrowing the protocol shape described in the Outcome section. The revision is scoped: change `~Copyable, ~Escapable` → `~Copyable` on the protocol Self and on the struct Value constraint in the "unified shape" text.

Status: awaiting principal resolution.


**Resolution (user decision, 2026-04-22)**: Option A selected. Protocol admits `Self: ~Copyable, ~Escapable`; struct `Value: ~Copyable & ~Escapable`; `UnsafeRawPointer` storage stays; split extensions stay. Commits `b3eb11b` and `7eb00b6` stand. No DECISION revision required.

Grounds: the raw-pointer storage is `@usableFromInline` internal; the typed construction API and the typed `value` accessor remain in the `where Value: ~Copyable` extensions; the only raw-address-exposing init is gated behind the opt-in `where Value: ~Copyable & ~Escapable` extension. Consumers with Escapable Value see a fully typed API. The internal complexity does not leak. Ownership.Borrow is itself `~Escapable`; admitting `Self: ~Escapable` on the capability protocol is conceptually coherent with the family's purpose.

Phase 1 execution continues with commits 3–7 as planned.

### §8.3 Path.Decomposition protocol — no action required

**Finding**: `Path.Decomposition` (at
`swift-path-primitives/.../Path.Decomposition.swift:53`) is a protocol
with `~Copyable, ~Escapable` Self that platform packages "conform
`Path.View` to" per the doc comment at line 20. The grep found no actual
conformers in the ecosystem today.

**Implication**: post-rename, the protocol's implicit expectation becomes
"platform packages conform `Path.Borrowed` to this protocol". The protocol
body itself requires no rename (it uses `Self`, not `Path.View`); only
the doc comment cascades.

**Execution**: update the doc comment in commit 4 (Phase 4).

## References

### Primary sources

- **DECISION (frozen)**: `swift-primitives/Research/ownership-borrow-protocol-unification.md` (v1.0.0, 2026-04-22, tier 2, cross-package)
- **Experiment (CONFIRMED)**: `swift-primitives/Experiments/ownership-borrow-protocol-unification/Sources/main.swift` (Swift 6.3.1, 2026-04-22)
- **Prior DECISION (tier 2, 2026-02-28)**: `swift-primitives/Research/view-vs-span-borrowed-access-types.md` — grounds the Case B specialization (null-termination invariant is type-level information that the generic `Ownership.Borrow<Path>` cannot encode)

### Current source state (to be edited by execution)

- `swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Borrow.swift`
- `swift-identity-primitives/Sources/Identity Primitives/Viewable.swift`
- `swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift`
- `swift-string-primitives/Sources/String Primitives/String.View.swift`
- `swift-string-primitives/Sources/String Primitives/String.swift`
- `swift-string-primitives/Sources/String Primitives/Tagged+String.swift`
- `swift-string-primitives/Sources/String Primitives/Tagged+String.View.swift`
- `swift-path-primitives/Sources/Path Primitives/Path.View.swift`
- `swift-path-primitives/Sources/Path Primitives/Path.swift`
- `swift-path-primitives/Sources/Path Primitives/Tagged+Path.swift`
- `swift-path-primitives/Sources/Path Primitives/Path.String.swift`
- `swift-path-primitives/Sources/Path Primitives/Path.Scan.swift`
- `swift-path-primitives/Sources/Path Primitives/Path.Decomposition.swift`
- `swift-kernel-primitives/Sources/Kernel File Primitives/Kernel.Directory.Entry.swift`
- `swift-kernel-primitives/Sources/Kernel File Primitives/Kernel.File.Direct.Requirements.swift`
- `swift-kernel-primitives/Tests/Kernel Path Primitives Tests/Kernel.Path Tests.swift`
- `swift-kernel-primitives/Tests/Kernel Path Primitives Tests/Kernel.Path.String Tests.swift`
- `swift-loader-primitives/Sources/Loader Primitives/Loader.Error.swift`

### Downstream consumers (Phase 7–8)

- `swift-standards/swift-darwin-standard/Sources/Darwin Kernel Standard/` — 4 files, 18 sites
- `swift-standards/swift-darwin-standard/Sources/Darwin Loader Standard/Loader.Symbol+Darwin.swift` — 1 site
- `swift-foundations/swift-strings/Sources/Strings/Swift.String+Primitives.POSIX.swift` — 1 site
- `swift-foundations/swift-paths/Sources/Paths/Path.View.swift` — parallel type declaration (§8.1)

### Ecosystem precedent (hoisted protocol pattern)

- `swift-primitives/swift-tree-primitives/Sources/Tree Primitives Core/Tree.N.ChildSlot.swift` — `__TreeNChildSlot<n>` hoisted at module scope, exposed as `Tree<E>.N<n>.ChildSlot`. Same structural pattern this plan applies to `Ownership.Borrow.\`Protocol\``.

### Convention sources

- **[PKG-NAME-001]**: package name = noun form of canonical type
- **[PKG-NAME-002]**: canonical capability protocol = `Namespace.\`Protocol\``; gerund typealias MAY be omitted when no natural gerund applies
- **[MEM-COPY-004]**: extension constraints on ~Copyable/~Escapable generic types MUST repeat suppressions
- **[API-IMPL-009]**: hoisted protocol with nested typealias pattern (declaring-module conformance uses hoisted name; consumers use typealias path)
- **[API-IMPL-005]**: one type per file
- **[API-IMPL-007]**: extension files use `+` suffix pattern

### Language references

- SE-0404 (Protocols Nested in Non-Generic Contexts) — generic contexts remain prohibited
- SE-0446 (Nonescapable Types) — `~Escapable`
- SE-0519 (Borrow<T> / Mutate<T>) — stdlib borrow types; `Ownership.Borrow<Value>` mirrors
- Swift 6.3.1 experimental features: `Lifetimes`, `SuppressedAssociatedTypes`
