# HTML.Element.Tag Indirect Storage Performance Analysis

## Context

`HTML.Element.Tag<Content>` was changed from inline storage (all fields stored directly in the struct) to class-backed indirect storage (all fields stored in a heap-allocated `_Storage` class, Tag holds a single 8-byte reference). This prevents cooperative thread pool stack overflow (544 KB) during result builder expansion of complex HTML documents.

The change is in: `Sources/HTML Renderable/HTML.Element.swift`

## Benchmark Results (debug mode, macOS 26.2, ARM64)

All microbenchmarks: 100K operations x 3 measured iterations.

### Tag Creation (isolates heap allocation overhead)

| Variant | Time (100K x 3) | Per-op |
|---------|-----------------|--------|
| Inline (struct init) | 331ms | ~1.1us |
| Indirect (class alloc + init) | 858ms | ~2.9us |
| **Overhead** | **2.6x** | **+1.8us/op** |

### Tag Copy — small content (String)

| Variant | Time (100K x 3) | Per-op |
|---------|-----------------|--------|
| Inline (memcpy ~40 bytes) | 996ms | ~3.3us |
| Indirect (atomic retain, 8 bytes) | 1,132ms | ~3.8us |
| **Overhead** | **1.14x** | **+0.5us/op** |

### Tag Copy — large content (6 Strings)

| Variant | Time (100K x 3) | Per-op |
|---------|-----------------|--------|
| Inline (memcpy ~120 bytes + 6 retains) | 1,307ms | ~4.4us |
| Indirect (atomic retain, 8 bytes) | 1,469ms | ~4.9us |
| **Overhead** | **1.12x** | **+0.5us/op** |

### Real-World Impact

The Aandeelhoudersregister PDF (the document that triggered the stack overflow) has ~100-200 Tags per render. Extra overhead per render = 200 x 1.8us = **~0.36ms**. The full test (`renders Hakuna register to PDF`) completes in **7.7 seconds**. Allocation overhead is ~0.005% of total render time.

## Analysis

1. **Creation is 2.6x slower in isolation** — this is the heap allocation cost (malloc + class header init). In any real workload, this is dwarfed by rendering work (string building, UTF-8 encoding, context closure dispatch).

2. **Copy overhead is minimal (12-14%)** — indirect copy is just an atomic refcount increment on 8 bytes. For large-content Tags, indirect copy should theoretically be FASTER (8-byte retain vs N-byte memcpy + N retains), but debug mode overhead masks this. Release mode would likely show indirect winning for large content.

3. **The trade-off is sound** — microseconds of allocation overhead to save kilobytes of stack. Without indirect storage, the cooperative pool (544 KB) overflows; with it, body evaluation uses ~2.5 KB instead of ~14 KB.

4. **Debug vs Release caveat** — these are debug-mode measurements. Release builds optimize malloc fast-path and inline retain/release, so the overhead gap narrows. Release builds could not be tested due to unrelated compilation errors in upstream dependencies.

## Test Location

Performance tests: `Tests/HTML Renderable Performance Tests/HTMLElement Tag Storage Performance Tests.swift`

The tests use an `InlineTag<Content>` struct that mirrors the original inline layout as a measurement control, compared against the real `HTML.Element.Tag<Content>` with class-backed storage.

## References

- Stack overflow fix: `Sources/HTML Renderable/HTML.Element.swift` — `_Storage` class + computed property getters
- Crash report: `~/Library/Logs/DiagnosticReports/Retired/swiftpm-testing-helper-2026-03-17-153906.ips`
- Cooperative pool research: `swift-rendering-primitives/Research/cooperative-pool-stack-overflow.md`
