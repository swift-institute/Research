# Follow-up: `@frozen` on `Kernel.Socket.Accept.Result`

<!--
---
version: 1.0.0
created: 2026-04-14
status: OPEN
tier: 3
related:
  - swift-foundations/swift-io/Research/io-events-completions-fate.md (retired under later directive)
---
-->

## Issue

`ISO_9945.Kernel.Socket.Accept.Result` is a `~Copyable`, non-frozen struct:

```swift
extension ISO_9945.Kernel.Socket.Accept {
    public struct Result: ~Copyable, Sendable {
        public var descriptor: Kernel.Socket.Descriptor
        public var address: Kernel.Socket.Address.Storage
        public var length: UInt32
    }
}
```

Consumers in other Swift packages (e.g., a future `swift-sockets` implementing
an `accept` wrapper) cannot **partially consume** the `.descriptor` field
across the module boundary. Attempting `consume result.descriptor` at the
call site produces:

```
error: cannot partially consume 'result' of non-frozen type
       'Kernel.Socket.Accept.Result' imported from 'ISO_9945_Kernel_Socket'
```

This is a Swift language rule for resilient (non-frozen) types: the layout
can change across ABI versions, so the compiler cannot emit a field-level
ownership transfer.

## Workaround (current)

```swift
var result = try Kernel.Socket.Accept.accept(descriptor)
var extracted = Kernel.Socket.Descriptor.invalid
Swift.swap(&result.descriptor, &extracted)
// extracted now holds the real descriptor; result.descriptor is .invalid
// (harmless on drop — invalid descriptor's deinit is a no-op).
```

`Swift.swap(&_:&_:)` for `~Copyable` types (SE-0437) is available in Swift 6.x
and works across module boundaries because it operates on inout storage, not
on field-level partial consumption.

## Fix

Add `@frozen` to the `Result` type:

```swift
extension ISO_9945.Kernel.Socket.Accept {
    @frozen
    public struct Result: ~Copyable, Sendable { ... }
}
```

`@frozen` declares the layout stable across ABI versions, which lifts the
partial-consumption restriction for cross-module consumers.

## Consumers affected

- Any package that imports `ISO_9945_Kernel_Socket` and calls
  `Kernel.Socket.Accept.accept(...)` and needs to destructure the return.
  At present this includes a future `swift-sockets` accept implementation
  (the prior swift-io `IO.Socket.blocking(...)` used the swap workaround
  internally; that code has since been reverted from swift-io).

## Decision needed

- Is `@frozen` acceptable for this type given iso-9945's ABI-stability posture?
- If yes, audit other `~Copyable` return types from iso-9945 syscall wrappers
  that may have the same cross-module decomposition need.
