# Storage Pointer Access Level

<!--
---
version: 1.0.0
last_updated: 2026-02-15
status: DECISION
---
-->

## Context

`swift build -c release` of `swift-buffer-primitives` fails with two categories of errors:

1. **Access level**: `Storage.Heap.pointer(at:)` is `package`-scoped in `Storage Primitives Core`, inaccessible from `swift-buffer-primitives` (a separate package). Affects all heap-backed buffers: Ring, Linear, Slab.

2. **Immutable pointer**: `Storage.Pool` only exposes an immutable `pointer(at:) → UnsafePointer` publicly. Buffer.Linked requires mutable pointer access for `.move()`, `.initialize(to:)`, and `.pointee` mutation. The mutable variant exists in Core at `package` scope.

3. **Compiler crash** (separate): Swift 6.2 `CopyPropagation` SIL pass double-consumes a `Property.View.Typed.Valued` in the `Buffer.Linked` test support initializer. Workaround: `@_optimize(none)`.

## Question

How should `Storage.Heap` and `Storage.Pool` expose per-slot mutable pointer access to downstream packages?

## Analysis

### Option A: Promote `package` → `public` in Core

Change the existing `package func pointer(at:)` to `public func pointer(at:)` directly in `Storage Primitives Core`.

- **Pros**: Minimal change (3 lines). No new code. No ambiguity between modules. Methods already marked `@unsafe`.
- **Cons**: Slightly enlarges Core's public surface.

### Option B: Add public wrappers in specialized modules

Add public `pointer(at:)` methods in `Storage Heap Primitives` and `Storage Pool Primitives` that delegate to the `package` Core methods.

- **Pros**: Keeps Core's surface minimal.
- **Cons**: Creates redeclaration conflicts — within the same package, both the `package` (Core) and `public` (specialized) methods are visible with identical signatures. Compiler rejects this.

### Option C: Higher-level operation methods

Add `initialize(at:to:)`, `move(at:)`, `deinitialize(at:)` to Storage types instead of exposing raw pointers.

- **Pros**: Safer API — no raw pointer exposure.
- **Cons**: Large surface area expansion. Duplicates `UnsafeMutablePointer` API. Buffer implementations need many different pointer operations; wrapping each one is impractical.

### Comparison

| Criterion | A: Promote | B: Wrappers | C: Operations |
|-----------|-----------|-------------|---------------|
| Lines changed | 3 | Rejected (ambiguity) | ~30+ |
| Safety model | `@unsafe` preserved | N/A | Higher |
| Architectural fit | Buffer IS trusted consumer | N/A | Over-abstraction |
| Maintenance | Zero | N/A | High |

## Outcome

**Status**: DECISION

**Option A: Promote `package` → `public` in Core.**

Rationale:
- Buffer-primitives is a first-party consumer of storage-primitives. Both are Tier 1 primitives. Restricting mutable pointer access from the buffer layer contradicts the architectural intent where buffers own lifecycle management.
- The `@unsafe` annotation already communicates the safety contract. Callers must opt in with `unsafe`.
- The `package` designation was a holdover from when cleanup lived in Storage. Commit `038e626` moved RAII cleanup to the buffer layer, which now needs the tools to fulfill that responsibility.
- Option B is rejected due to Swift's redeclaration rules within the same package.

### Changes

| File | Line | Change |
|------|------|--------|
| `Storage Primitives Core/Storage.swift` | 591 | `package func` → `public func` (Heap mutable) |
| `Storage Primitives Core/Storage.swift` | 606 | `package func` → `public func` (Heap immutable) |
| `Storage Primitives Core/Storage.swift` | 251 | `package func` → `public func` (Pool mutable) |
| `Storage Primitives Core/Storage.swift` | 464 | `package func` → `public func` (Arena mutable) |
| `Buffer Primitives Test Support.swift` | 55, 67 | `@_optimize(none)` (CopyPropagation workaround) |

## References

- Commit `038e626`: "Move RAII cleanup from storage to buffer layer, fix release builds"
- Swift bug: CopyPropagation double-consume with `~Copyable` + `@lifetime` on `Property.View.Typed.Valued`
