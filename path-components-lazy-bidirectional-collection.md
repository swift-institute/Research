# Path.Components as lazy BidirectionalCollection — design sketch

## Status

OPEN. Tracked here pending implementation decision.

## Why this note exists

Two independent concerns converged:

1. **`lastComponent` violates `[API-NAME-002]`** (no compound identifiers).
   Workgroup 2026-04-18 deferred the rename because moving to a direct
   replacement either:
    - regresses perf (`path.components.last` on `[Component]` allocates all
      N components before returning the tail), or
    - introduces a Property.View nested accessor (`path.component.last`) —
      over-engineered for an operation that should be a Collection access.

2. **Decision 2026-04-18**: keep `lastComponent` for perf (1 allocation
   via reverse byte scan) over `components.last` (N allocations via eager
   `[Component]` generator). Documented there as acceptable for pre-1.0.

The solution that resolves both is neither option the workgroup considered:
change the return type of `components` so `path.components.last` is
itself O(k) with 1 allocation.

## Design

Introduce `Paths.Path.Components` as a lazy `BidirectionalCollection`.
The value is a wrapper over `Paths.Path` that does not materialize
segments until a subscript or `index(_:)` is performed.

```swift
extension Paths.Path {
    public struct Components: BidirectionalCollection, Sendable {
        public typealias Element = Component
        public typealias Index = Int  // byte position of segment start

        @usableFromInline internal let path: Paths.Path

        @usableFromInline init(_ path: Paths.Path) { self.path = path }

        public var startIndex: Int {
            // first non-separator byte; count when all-empty or empty path
            path._firstNonSeparator(from: 0)
        }

        public var endIndex: Int { path._storage.count }

        public subscript(i: Int) -> Component {
            let end = path._firstSeparator(from: i) ?? endIndex
            return Component(storage: Storage(copying: path._storage.buffer[i..<end]))
        }

        public func index(after i: Int) -> Int {
            let segmentEnd = path._firstSeparator(from: i) ?? endIndex
            return path._firstNonSeparator(from: segmentEnd)
        }

        public func index(before i: Int) -> Int {
            // Walk back past trailing separators to find previous segment end,
            // then back to previous separator (or 0) to find segment start.
            let prevSegmentEnd = path._lastNonSeparator(before: i)       // pos after last non-sep in [0, i)
            let prevSeparator  = path._lastSeparator(before: prevSegmentEnd)
            return prevSeparator.map { $0 + 1 } ?? 0
        }
    }

    /// Lazy component view.
    @inlinable
    public var components: Components { Components(self) }
}
```

Required byte-scan helpers on `Paths.Path` (internal, `@usableFromInline`):

| Helper | Contract |
|---|---|
| `_firstNonSeparator(from i: Int) -> Int` | first `j >= i` where buffer[j] is not a separator; `_storage.count` if none |
| `_firstSeparator(from i: Int) -> Int?` | first `j >= i` where buffer[j] is a separator; nil if none |
| `_lastNonSeparator(before i: Int) -> Int` | `j+1` where j is last non-separator in `[0, i)`; `0` if none |
| `_lastSeparator(before i: Int) -> Int?` | last separator in `[0, i)`; nil if none |

`_lastSeparator` already exists (Wave 1 / Phase 4b); the other three are new.

## What the solution delivers

With this type:

| Expression | Complexity | Allocations |
|---|---|---|
| `path.components.last` | O(k), k = last component length | 1 (Component) |
| `path.components.first` | O(k'), k' = leading-separator prefix + first component | 1 (Component) |
| `for c in path.components { ... }` | O(n) total, per-step lazy | N (one per segment) |
| `path.components.count` | O(n) | 0 (stdlib iterates indices) |
| `path.components[i]` | O(k_i) | 1 |
| `Array(path.components)` | O(n) | N + 1 (array) |

Key property: **`path.components.last` is byte-for-byte equivalent in
perf to the current `path.lastComponent`** — both walk the buffer in
reverse to the last separator and allocate exactly one Component.

## Consumer impact

Signature change: `var components: [Component]` → `var components: Components`.

Source-breaking for callers that bind the result to `[Component]`
explicitly. Grep across the ecosystem (2026-04-18) found zero such
bindings — all uses are via `.map`, `.count`, `for ... in`, subscript,
`.last`, `.first` — all of which `BidirectionalCollection` supports.

Behavioral change: `path.components.count` goes from O(1) (array) to O(n)
(collection walk). Users who need O(1) count must materialize:
`Array(path.components).count`.

After landing, `lastComponent` can be deleted: every call site
`path.lastComponent` becomes `path.components.last`, same perf, same
semantics, no compound name.

## Risks and open questions

1. **`BidirectionalCollection` Sendable conformance**: The Components
   type wraps a `Paths.Path` by value; since `Paths.Path` is `Sendable`,
   the wrapper is `Sendable`. No escape hatch needed.

2. **Index stability**: Byte-position indices are stable across CoW copies
   of the underlying `Paths.Path` (same bytes, same positions). They are
   NOT stable across mutations (mutations produce a new Path with a new
   buffer). Standard Collection discipline — document.

3. **`RandomAccessCollection` upgrade**: `BidirectionalCollection` is the
   minimum for `.last`. Upgrading to `RandomAccessCollection` would
   require O(1) `index(_:offsetBy:)` — not achievable without precomputing
   a boundary index. Skip unless a consumer needs it.

4. **`lastComponent` deletion**: Once this lands, `lastComponent` is
   redundant. Delete in the same PR, with migration of the 4 swift-file-
   system call sites.

## Implementation cost

Single PR in swift-paths:

| File | Change |
|---|---|
| `Path.Components.swift` | New — 80 lines for the struct |
| `Path.Navigation.swift` | Replace eager `components: [Component]` with lazy `components: Components`; add 3 new byte-scan helpers; delete `lastComponent`; rewrite `hasPrefix` / `relative(to:)` to work on lazy view (already Collection-compatible — likely no change) |
| `File.swift`, `File.Directory.swift`, `File.Path.Property.swift` in swift-file-system | Migrate `.lastComponent` → `.components.last` (4 sites) |
| `Path Tests.swift` | Update assertions; no change needed if tests already use `.map(\.string)` / `.count` |

Estimated ~100 lines added, ~50 deleted, ~10 migrated.

## Recommendation

Proceed. Resolves the `[API-NAME-002]` violation by deletion (no rename,
no alias, no new identifier) while preserving perf at the operation that
matters. Consistent with release-eng no-backwards-compat policy.

## Cross-references

- `/ecosystem-data-structures` [DS-003] — `Paths.Path.Components` is not
  a new *container* (it borrows, doesn't own); it's a view over an
  existing owned `Paths.Path`. Falls outside DS-003 selection matrix.
- `/implementation` `[API-NAME-002]` — compound identifiers forbidden in
  public API; deletion via view is the clean resolution.
- `/implementation` `[IMPL-086]` — deletion-first over type-system
  enforcement when the invariant (here, "lastComponent is a distinct
  operation") is not load-bearing.
- Workgroup synthesis 2026-04-18 D2 — retained omit-empty semantics;
  lazy view preserves them via the `_firstNonSeparator` / `_firstSeparator`
  helpers skipping leading and trailing separator runs.
