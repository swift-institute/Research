# Apple HTTP: OutputSpan Writer Pattern

<!--
---
version: 1.0.0
last_updated: 2026-04-02
status: REFERENCE
tier: 3
trigger: Apple swift-http-api-proposal — answered research gap
---
-->

## Context

How should an async writer expose its buffer to callers? The question was whether writers should accept owned data (caller allocates, writer copies) or provide a buffer for callers to fill (zero-copy append). Apple's `AsyncWriter` protocol answers: provide an `OutputSpan`.

## Pattern

```swift
public protocol AsyncWriter<WriteElement, WriteFailure>: ~Copyable, ~Escapable {
    associatedtype WriteElement: ~Copyable
    associatedtype WriteFailure: Error

    mutating func write<Result, Failure: Error>(
        _ body: (inout OutputSpan<WriteElement>) async throws(Failure) -> Result
    ) async throws(EitherError<WriteFailure, Failure>) -> Result
}
```

Callers append into the span; the writer manages buffer allocation:

```swift
try await writer.write { outputSpan in
    for item in items {
        outputSpan.append(item)
    }
}
```

## Design Details

- **`OutputSpan<WriteElement>`** is the dual of `Span<ReadElement>` — Span is the read view (non-owning, non-escaping), OutputSpan is the write view (appendable, bounded by capacity).
- **`inout` parameter** — the closure mutates the OutputSpan in place; no return-based buffer handoff.
- **`EitherError<WriteFailure, Failure>`** — separates writer infrastructure errors from user-closure errors. When the writer never fails (`WriteFailure == Never`), a convenience overload simplifies to `throws(Failure)`.
- **Single-element convenience**: `write(_ element: consuming WriteElement)` moves the element into an Optional, then `take()`s it inside the closure — the canonical ~Copyable-through-closure workaround.
- **Span-based bulk write**: `write(_ span: Span<WriteElement>)` loops over the span, filling OutputSpan batches until all elements are written. Throws `AsyncWriterWroteShortError` if the writer provides a zero-capacity OutputSpan before all elements are consumed.

## Source

`/Users/coen/Developer/apple/swift-http-api-proposal/Sources/AsyncStreaming/Writer/AsyncWriter.swift`
