# Pass 3 (Consumer Cleanup) Verification

**Date**: 2026-03-20
**Scope**: 9 packages targeted for `.rawValue.rawValue` chain elimination, `Int(bitPattern:)` reduction at non-boundary sites, and `__unchecked` cleanup.

---

## Summary

| Package | `.rawValue.rawValue` | `Int(bitPattern:)` | `__unchecked` | Status |
|---------|---------------------|--------------------|---------------|--------|
| swift-affine-primitives | 0 (was 15) | 18 (boundary) | 22 (boundary) | CLEAN |
| swift-memory-primitives | 0 (was 2) | 0 | 0 | CLEAN |
| swift-binary-primitives | 0 (was 6) | 50 (unchanged) | 0 | NOT CLEANED |
| swift-buffer-primitives | 3 (commented-out) | 57 | 0 | PARTIAL |
| swift-queue-primitives | 0 (was 4) | 16 (boundary) | 0 | CLEAN |
| swift-kernel-primitives | 0 (was triple chains) | 3 (boundary) | 1 (boundary) | CLEAN |
| swift-hash-table-primitives | 0 | 16 (unchanged) | 12 (boundary) | NOT CLEANED |
| swift-dictionary-primitives | 0 | 17 (unchanged) | 0 | NOT CLEANED |
| swift-tree-primitives | 0 | 9 (unchanged) | 10 (boundary) | NOT CLEANED |

---

## Per-Package Detail

### 1. swift-affine-primitives (tier 5)

**`.rawValue.rawValue` chains: ELIMINATED (15 -> 0)**

All 15 double-chains in `Tagged+Affine.swift` and the pointer StdLib Integration files are gone. The replacement patterns are:
- `Int(bitPattern: count.cardinal)` — uses typed `.cardinal` accessor on Tagged Cardinal
- `Int(bitPattern: ordinal.ordinal.rawValue)` — single `.rawValue` through the ordinal accessor
- `Int(bitPattern: rhs)` / `Int(bitPattern: lhs)` — direct conversion on Tagged Ordinal values

The 18 `Int(bitPattern:)` that remain are all at **stdlib boundary sites** (UnsafePointer arithmetic, allocate, initialize, deinitialize) and the 22 `__unchecked` usages are all at **type construction boundaries** (creating Tagged values from validated components). Both are correct placements per the Pass 3 rules.

### 2. swift-memory-primitives (tier 13)

**`.rawValue.rawValue` chains: ELIMINATED (2 -> 0)**

`Memory.Address` now exposes a `.bitPattern` computed property:
```swift
public var bitPattern: UInt { rawValue.rawValue }
```
This is defined at line 141 of `Memory.Address.swift`. Consumers (including `Kernel.Memory.Address`) use `address.bitPattern` instead of `address.rawValue.rawValue`. The two stdlib interop sites (`UnsafeRawPointer(bitPattern: address.bitPattern)`) correctly use this accessor.

### 3. swift-binary-primitives (tier 14)

**`.rawValue.rawValue` chains: ELIMINATED (6 -> 0)**

However, `Int(bitPattern:)` count is **unchanged at 50** (34 in Cursor, 16 in Reader). These are used for:
- Error reporting: passing typed indices into error structs that take `Int` fields
- Arithmetic: extracting raw values for bounds checking, offset calculation
- Iterator: converting between typed positions and raw pointer offsets

**Concern**: The original audit identified 44 in Cursor and 14 in Reader (58 total). Current count is 50, suggesting some were removed. But the remaining 50 are dense — most are bounds-checking and error-construction sites where `Int(bitPattern:)` is the correct pattern for crossing into untyped stdlib domains.

**Verdict**: `.rawValue.rawValue` fixed. `Int(bitPattern:)` sites are legitimate boundary crossings, not consumer-side unwrapping.

### 4. swift-buffer-primitives (tier 15)

**`.rawValue.rawValue` chains: 3 remain but ALL are in commented-out code**

The 3 surviving instances are in dead/commented code:
- `Buffer.Slab.Inline Copyable.swift:126` — commented out `underestimatedCount`
- `Buffer.Ring.Inline Copyable.swift:136` — commented out `underestimatedCount`
- `Buffer.Linear.Inline Copyable.swift:107` — commented out `underestimatedCount`

**Arena `UInt32(header.highWater)`**: Confirmed at 2 sites in `Buffer.Arena+Heap ~Copyable.swift` (lines 50, 143). The old pattern was `UInt32(header.highWater.rawValue.rawValue)` — now it uses direct conversion.

**`Int(bitPattern:)` count**: 57 across 19 files. These are in:
- `Buffer.Aligned` (15 sites): byte-count and capacity conversions for UnsafeBufferPointer/Span interop
- Arena (9 sites): slot index conversions for UnsafeMutablePointer subscript
- Ring/Linear span iterators (20+ sites): pointer offset arithmetic
- All are stdlib boundary sites.

**Verdict**: Active code is clean. Commented-out code should be removed.

### 5. swift-queue-primitives (tier 17)

**`.rawValue.rawValue` chains: ELIMINATED (4 -> 0)**

The 4 original double-chains in `Queue+Conveniences.swift` (RandomAccessCollection) have been replaced with `Int(bitPattern:)` on typed indices. The current file uses:
- `Int(bitPattern: end) - Int(bitPattern: start)` for `distance(from:to:)`
- `Int(bitPattern: i) + distance` for `index(_:offsetBy:)`
- Comments mark these as "Stdlib boundary: Collection protocol requires Int"

The 16 total `Int(bitPattern:)` across the package are all at Collection protocol boundaries (`underestimatedCount`, `distance`, `index(_:offsetBy:)`).

### 6. swift-kernel-primitives (tier 17)

**Triple `.rawValue.rawValue.rawValue` chains: ELIMINATED**

`Kernel.Memory.Address` now uses `.bitPattern` on its inner `rawValue`:
```swift
unsafe UnsafeRawPointer(bitPattern: rawValue.bitPattern)
unsafe UnsafeMutableRawPointer(bitPattern: rawValue.bitPattern)
```
This reaches through: `Tagged<Kernel, Memory.Address>` -> `.rawValue` (gets `Memory.Address`) -> `.bitPattern` (gets `UInt`). Clean two-step traversal replacing the old triple chain.

The 3 remaining `Int(bitPattern:)` are in:
- `Kernel.Event.ID.swift:58` — event ID construction from Int32
- `Kernel.System.Path.swift:44` — path length conversion
- `Kernel.Memory.Page.swift:42` — page size alignment

All are boundary conversions from kernel types.

### 7. swift-hash-table-primitives (tier 16)

**`.rawValue.rawValue` chains: 0 (none existed per the audit; the original concern was `Int(bitPattern:)` and `__unchecked`)**

**`Int(bitPattern:)` count: 16** across 10 files. The original audit identified 18 at InlineArray access sites. Current usage:
- Hash-to-bucket modular arithmetic: `Ordinal(UInt(bitPattern: hash)) % capacity.rawValue` (5 sites)
- Position round-tripping: `Int(bitPattern: position)` / `Ordinal(UInt(bitPattern: raw))` in BufferAccess (2 sites)
- `underestimatedCount` returns (2 sites)
- Iterator position extraction (2 sites)
- Capacity/count conversions (5 sites)

**`__unchecked` count: 12** — all at validated construction boundaries (creating `Bucket.Index` after hash modulo, creating `Ordinal.Finite` from validated range).

**Verdict**: No InlineArray subscript(Ordinal.Protocol) migration occurred. The `Int(bitPattern:)` sites are boundary crossings for stdlib `Array` subscript and hash arithmetic. The `__unchecked` sites are validated constructions. These are defensible as-is but were NOT migrated to typed subscript.

### 8. swift-dictionary-primitives (tier 18)

**`.rawValue.rawValue` chains: 0**

**`Int(bitPattern:)` count: 17** across 8 files. The original audit identified 21 systematic chains. Current patterns:
- `Int(bitPattern: count)` for `underestimatedCount` and `endIndex` (9 sites across slab/ordered/bounded/small/static)
- `Int(bitPattern: _keys.count)` for precondition bounds (6 sites)
- `Int(bitPattern: count)` for Collection bounds (2 sites)

**`Ordinal(UInt(index))` chains: 11** — these are the stdlib-to-typed boundary conversions at `subscript(index:)` and `.Values` accessors. Pattern: `Index<Key>(Ordinal(UInt(index)))` where `index` is a raw `Int` from Collection protocol.

**Verdict**: The 21 original chains appear reduced to 17 `Int(bitPattern:)` + 11 `Ordinal(UInt(index))` at boundary sites. These are all Collection/stdlib protocol boundaries. No typed subscript migration occurred.

### 9. swift-tree-primitives (tier 19)

**`.rawValue.rawValue` chains: 0**

**`Int(bitPattern:)` count: 9** across 5 files. The original audit identified 9 in `_validate` and `remove` methods. Current distribution:
- `Tree.Unbounded.swift` (5 sites): `_rawIndex` helper wraps `Int(bitPattern: index)`, plus `firstIndex(of:)` and `push()` calls
- `Tree.N.Bounded.swift`, `Tree.N.Inline.swift`, `Tree.Keyed.swift`, `Tree.N.swift` (1 each): position-to-UInt32 conversion for arena slots

The tree package has a clean helper pattern: `_rawIndex(_ index: Index<Node>) -> Int` centralizes the conversion. The 5 remaining direct calls in `Tree.Unbounded` use `Int(bitPattern: position.index)` for Array subscript access.

**`__unchecked` count: 10** — all in `Tree.N.ChildSlot` for compile-time constant slot definitions (`.left`, `.right`, `.middle`, `.northwest`, etc.). These are static constants, not runtime constructions.

**Verdict**: Count unchanged at 9, but usage is correct boundary crossing for Array subscript. The `_rawIndex` helper is good practice.

---

## Cross-Cutting Findings

### What Changed (Pass 3 successes)
1. **`.rawValue.rawValue` chains fully eliminated** from all 9 packages (active code)
2. **`.rawValue.rawValue.rawValue` triple chain eliminated** from kernel-primitives via `.bitPattern` accessor
3. **`Memory.Address.bitPattern`** property added as the canonical boundary accessor
4. **Queue RandomAccessCollection** double-chains replaced with `Int(bitPattern:)` + boundary comments
5. **Affine** chains replaced with typed `.cardinal` / `.ordinal` accessors

### What Did NOT Change (Pass 3 gaps)
1. **binary-primitives**: 50 `Int(bitPattern:)` remain — all at error/bounds/arithmetic boundaries
2. **hash-table-primitives**: 16 `Int(bitPattern:)` remain — no InlineArray typed subscript migration
3. **dictionary-primitives**: 17 `Int(bitPattern:)` + 11 `Ordinal(UInt(index))` remain — no typed subscript migration
4. **tree-primitives**: 9 `Int(bitPattern:)` remain — boundary crossings for Array subscript
5. **buffer-primitives**: 57 `Int(bitPattern:)` remain — extensive stdlib pointer/span interop

### Assessment

The `.rawValue.rawValue` chain elimination was **fully successful**. Every double/triple chain in active code is gone, replaced with either:
- Named accessors (`.bitPattern`, `.cardinal`, `.ordinal`)
- Direct `Int(bitPattern:)` at boundary crossings

The `Int(bitPattern:)` reduction was **not attempted** for most packages. The remaining instances are concentrated at stdlib boundary sites (Collection protocol requirements, UnsafePointer arithmetic, error construction) where `Int(bitPattern:)` is the correct typed conversion. These are not consumer-site unwrapping — they are the boundary layer itself.

The 3 commented-out `.rawValue.rawValue` chains in buffer-primitives should be removed as dead code.
