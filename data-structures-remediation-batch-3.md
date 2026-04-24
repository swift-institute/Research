# Remediation Plans: Batch 3 (HIGH)

Generated: 2026-04-03

---

## swift-finite-primitives

### Filtering

| Violations file entry | Umbrella | Canonical? | True violation? |
|----------------------|----------|------------|-----------------|
| Package.swift L39: `Ordinal Primitives` | ordinal | Yes | No |
| Package.swift L40: `Identity Primitives` | identity | Yes | No |
| Package.swift L41: `Index Primitives` | index | Yes | No |
| Package.swift L42: `Sequence Primitives` | sequence | No | **Yes** |
| Package.swift L50: `Algebra Primitives` | algebra | Yes | No |
| Source: `Ordinal_Primitives` (6 files) | ordinal | Yes | No |
| Source: `Tagged_Primitives` (4 files) | identity | Yes | No |
| Source: `Index_Primitives` (1 file) | index | Yes | No |

All 12 source file violations are canonical umbrellas and are not true violations.

### True violations (after filtering canonical umbrellas)

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Finite Primitives Core/Finite.Enumeration.swift` | `public import Sequence_Primitives` | `Sequence.Iterator.Protocol` | `public import Sequence_Primitives_Core` |

Note: This file was missed by the source-level scan (uses `public import` rather than bare `import`).

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `"Sequence Primitives"` from `swift-sequence-primitives` | `"Sequence Primitives Core"` | Finite Primitives Core |

---

## swift-array-primitives

### Filtering

| Violations file entry | Umbrella | Canonical? | True violation? |
|----------------------|----------|------------|-----------------|
| Package.swift L66: `Index Primitives` | index | Yes | No |
| Package.swift L79: `Sequence Primitives` | sequence | No | **Yes** |
| Package.swift L113: `Algebra Modular Primitives` | algebra-modular | Yes | No |
| Source: `Index_Primitives` (7 files) | index | Yes | No |
| Source: `Sequence_Primitives` (2 files) | sequence | No | **Yes** |

### True violations (after filtering canonical umbrellas)

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Array Static Primitives/Array Static.swift` | `import Sequence_Primitives` | `Sequence.Protocol`, `Sequence.Iterator.Protocol` (via Iterator typealias) | `import Sequence_Primitives_Core` |
| `Sources/Array Static Primitives/Array.Static ~Copyable.swift` | `import Sequence_Primitives` | `Sequence.Drain`, `Sequence.Protocol` (via Property.View) | `import Sequence_Primitives_Core` |

Additional source files in `Array Dynamic Primitives` also import `Sequence_Primitives` transitively from the Package.swift dep (not flagged as separate source violations because the target has it):
- `Array.Dynamic.swift` uses `Sequence.Iterator.Protocol`, `Sequence.Protocol`
- `Array.Dynamic ~Copyable.swift` uses `Sequence.Drain`

All types are from `Sequence Primitives Core`.

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `"Sequence Primitives"` from `swift-sequence-primitives` | `"Sequence Primitives Core"` | Array Dynamic Primitives |

Note: `Array Static Primitives` imports `Sequence_Primitives` in source but has no explicit Package.swift dep. It receives access transitively. After changing Array Dynamic Primitives, verify Array Static Primitives still resolves (may need its own explicit `"Sequence Primitives Core"` dep added).

---

## swift-async-primitives

### Filtering

| Violations file entry | Umbrella | Canonical? | True violation? |
|----------------------|----------|------------|-----------------|
| Package.swift L87: `Buffer Primitives` | buffer | No | **Yes** |
| Package.swift L88: `Queue Primitives` | queue | No | **Yes** |
| Package.swift L89: `Identity Primitives` | identity | Yes | No |
| Source: `Queue_Primitives` (3 files) | queue | No | **Yes** |
| Source: `Buffer_Primitives` (4 files) | buffer | No | **Yes** |

### True violations (after filtering canonical umbrellas)

**Queue umbrella violations:**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Async Bridge Primitives/Async.Bridge.swift` | `import Queue_Primitives` | `Deque` (= `Queue.DoubleEnded`) | `import Queue_DoubleEnded_Primitives` |
| `Sources/Async Broadcast Primitives/Async.Broadcast.State.swift` | `import Queue_Primitives` | `Deque` (= `Queue.DoubleEnded`) | `import Queue_DoubleEnded_Primitives` |
| `Sources/Async Broadcast Primitives/Async.Broadcast.swift` | `import Queue_Primitives` | `Deque` (= `Queue.DoubleEnded`) | `import Queue_DoubleEnded_Primitives` |

Additional files not flagged as violations but using Queue types:
- `Sources/Async Mutex Primitives/Async.Mutex+Deque.swift`: `public import Queue_Primitives` -- uses `Deque`, `.back.push()`, `.front.take` -- replace with `public import Queue_DoubleEnded_Primitives`
- `Sources/Async Waiter Primitives/`: uses `Queue_Primitives_Core.Queue<T>`, `Queue_Primitives_Core.Queue<T>.Fixed` -- already uses module-qualified names, needs `Queue_Primitives_Core`
- `Sources/Async Channel Primitives/`: uses `Deque` -- needs `Queue_DoubleEnded_Primitives`

**Buffer umbrella violations:**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Async Timer Primitives/Async.Timer.Wheel+Slot.swift` | `import Buffer_Primitives` | (no Buffer types directly; uses `Link<2>` from Link_Primitives) | Remove import (unused) |
| `Sources/Async Timer Primitives/Async.Timer.Wheel.Level.swift` | `import Buffer_Primitives` | (no Buffer types directly; uses `Link<2>.Header<Node>`) | Remove import (unused) |
| `Sources/Async Timer Primitives/Async.Timer.Wheel.Payload.swift` | `import Buffer_Primitives` | (no Buffer types directly; only comments reference Buffer.Linked.Node) | Remove import (unused) |
| `Sources/Async Timer Primitives/Async.Timer.Wheel.Storage.swift` | `import Buffer_Primitives` | `Buffer<Node>.Arena.Bounded`, `Buffer<Node>.Arena.Position` | `import Buffer_Arena_Primitives_Core` |

Additional: `Sources/Async Mutex Primitives/Async.Mutex+Deque.swift` has `internal import Buffer_Primitives` but uses zero Buffer types -- remove.

**Core re-export (`exports.swift`):**

The `Async Primitives Core` module re-exports both umbrellas via `@_exported public import`. The precise replacements depend on the union of all downstream variant needs:

| Current re-export | Downstream usage | Replacement re-export(s) |
|-------------------|-----------------|--------------------------|
| `@_exported public import Buffer_Primitives` | Timer: `Buffer.Arena.Bounded`, `Buffer.Arena.Position` | `@_exported public import Buffer_Arena_Primitives_Core` |
| `@_exported public import Queue_Primitives` | Bridge/Broadcast/Channel/Mutex: `Deque`; Waiter: `Queue`, `Queue.Fixed` | `@_exported public import Queue_Primitives_Core` + `@_exported public import Queue_DoubleEnded_Primitives` |

### Package.swift changes

| Current product dep | Replacement(s) | Target affected |
|--------------------|----------------|-----------------|
| `"Buffer Primitives"` from `swift-buffer-primitives` | `"Buffer Arena Primitives Core"` | Async Primitives Core |
| `"Queue Primitives"` from `swift-queue-primitives` | `"Queue Primitives Core"` + `"Queue DoubleEnded Primitives"` | Async Primitives Core |

---

## swift-dictionary-primitives

### Filtering

| Violations file entry | Umbrella | Canonical? | True violation? |
|----------------------|----------|------------|-----------------|
| Package.swift L41: `Set Primitives` | set | Yes | No |
| Package.swift L42: `Hash Table Primitives` | hash-table | Yes | No |
| Package.swift L43: `Index Primitives` | index | Yes | No |
| Package.swift L45: `Input Primitives` | input | Yes | No |
| Package.swift L56: `Sequence Primitives` | sequence | No | **Yes** |
| Package.swift L67: `Sequence Primitives` | sequence | No | **Yes** |
| Package.swift L76: `Sequence Primitives` | sequence | No | **Yes** |
| Source: `Index_Primitives` (1 file) | index | Yes | No |
| Source: `Set_Primitives` (1 file) | set | Yes | No |
| Source: `Hash_Table_Primitives` (1 file) | hash-table | Yes | No |

### True violations (after filtering canonical umbrellas)

**Package.swift deps only** -- source files import `Sequence_Primitives` via `internal import` and `@_exported public import`, but these were not flagged separately in the violations scan. Analysis of actual usage:

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Dictionary Ordered Primitives/exports.swift` | `@_exported public import Sequence_Primitives` | (re-export) | `@_exported public import Sequence_Primitives_Core` |
| `Sources/Dictionary Ordered Primitives/Dictionary.Ordered Copyable.swift` | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol`, `Sequence.Protocol`, `Sequence.Clearable` | `internal import Sequence_Primitives_Core` |
| `Sources/Dictionary Ordered Primitives/Dictionary.Ordered.Small Copyable.swift` | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol`, `Sequence.Protocol`, `Sequence.Clearable` | `internal import Sequence_Primitives_Core` |
| `Sources/Dictionary Ordered Primitives/Dictionary.Ordered.Static Copyable.swift` | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol`, `Sequence.Protocol`, `Sequence.Clearable` | `internal import Sequence_Primitives_Core` |
| `Sources/Dictionary Bounded Primitives/Dictionary.Ordered.Bounded Copyable.swift` | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol`, `Sequence.Protocol`, `Sequence.Clearable` | `internal import Sequence_Primitives_Core` |
| `Sources/Dictionary Slab Primitives/exports.swift` | `@_exported public import Sequence_Primitives` | (re-export) | `@_exported public import Sequence_Primitives_Core` |
| `Sources/Dictionary Slab Primitives/Dictionary Copyable.swift` | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol`, `Sequence.Protocol`, `Sequence.Clearable` | `internal import Sequence_Primitives_Core` |

All types are from `Sequence Primitives Core`.

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `"Sequence Primitives"` from `swift-sequence-primitives` (L56) | `"Sequence Primitives Core"` | Dictionary Ordered Primitives |
| `"Sequence Primitives"` from `swift-sequence-primitives` (L67) | `"Sequence Primitives Core"` | Dictionary Bounded Primitives |
| `"Sequence Primitives"` from `swift-sequence-primitives` (L76) | `"Sequence Primitives Core"` | Dictionary Slab Primitives |

---

## swift-test-primitives

### Filtering

| Violations file entry | Umbrella | Canonical? | True violation? |
|----------------------|----------|------------|-----------------|
| Package.swift L47: `Identity Primitives` | identity | Yes | No |
| Package.swift L48: `Source Primitives` | source | Yes | No |
| Package.swift L49: `Sample Primitives` | sample | Yes | No |
| Package.swift L51: `Time Primitives` | time | No | **Yes** |
| Package.swift L60: `Async Primitives` | async | No | **Yes** |
| Source: `Sample_Primitives` (5 files) | sample | Yes | No |

### True violations (after filtering canonical umbrellas)

**Time umbrella violation:**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Test Primitives Core/exports.swift` | `@_exported public import Time_Primitives` | `Duration`, `Time.Format`, `Time.Format.Unit`, `Time.Format.Notation` (used across Benchmark, Event, Trait files) | `@_exported public import Time_Primitives_Core` |

All Time types used (`Duration`, `Time.*`) are in `Time Primitives Core`. No Julian types are used.

**Async umbrella violation:**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Test Snapshot Primitives/exports.swift` | `@_exported public import Async_Primitives` | `Async.Callback` (used in Strategy, Strategy+Redacting) | `@_exported public import Async_Primitives_Core` |

`Async.Callback` is defined in `Async Primitives Core`.

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `"Time Primitives"` from `swift-time-primitives` (L51) | `"Time Primitives Core"` | Test Primitives Core |
| `"Async Primitives"` from `swift-async-primitives` (L60) | `"Async Primitives Core"` | Test Snapshot Primitives |

---

## Summary

| Package | Total violations (file) | Canonical (filtered) | True violations | Package.swift changes | Source import changes |
|---------|----------------------:|--------------------:|----------------:|---------------------:|---------------------:|
| swift-finite-primitives | 17 | 16 | 1 | 1 | 1 |
| swift-array-primitives | 12 | 10 | 2 | 1 | 2 |
| swift-async-primitives | 10 | 1 | 9 | 2 (split to 3 products) | 7+ |
| swift-dictionary-primitives | 10 | 7 | 3 | 3 | 7 |
| swift-test-primitives | 10 | 8 | 2 | 2 | 2 |

**Total true violations across batch: 17** (out of 59 filed violations).
42 violations were false positives (canonical umbrellas that are fine to import).
