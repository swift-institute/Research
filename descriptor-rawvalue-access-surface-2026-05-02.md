# Research: `ISO_9945.Kernel.Descriptor.rawValue` access surface

**Status:** INVESTIGATION (kicked off 2026-05-02; not DECIDED)

## Problem

`ISO_9945.Kernel.Descriptor` (the `~Copyable` POSIX file-descriptor type at
swift-iso-9945 L2) currently has *two* coexisting raw-fd accessor surfaces:

```swift
public struct Descriptor: ~Copyable, Sendable {
    @usableFromInline
    package var _raw: Int32

    @usableFromInline
    package init(_raw: Int32) { self._raw = _raw }
    // ...
}

extension ISO_9945.Kernel.Descriptor {
    @_spi(Syscall) @inlinable
    public init(_rawValue: Int32) { self._raw = _rawValue }

    @_spi(Syscall) @inlinable
    public var _rawValue: Int32 { _raw }
}
```

— the underscored `_raw` (`package`) form for in-package access, and the
underscored `_rawValue` (`@_spi(Syscall) public`) form for cross-package
syscall layers. **Both** are underscored as a "low-level escape hatch"
signal.

Item 1.5 Phase 5 (commit `9f3abb4`) downgraded the related Lock + Duplicate
raw forms from `@_spi(Syscall) public` to `package` after swift-memory was
migrated off cross-package raw access — but the `Descriptor.rawValue` accessor
itself was not addressed in that cycle, leaving the dual surface above.

The user's preference (2026-05-02 conversation): **drop underscores, consolidate
on a single name `rawValue`, keep `package var` storage.**

That direction conflicts with one architectural reality: swift-linux-foundation
(L3 Linux kernel foundation) currently has ~17 cross-package construction sites
that wrap raw `Int32` fds returned from Linux syscalls (`pipe(2)`,
`timerfd_create(2)`, `pidfd_open(2)`, `signalfd(2)`, `eventfd(2)`,
`io_uring_setup(2)`, `epoll_create1(2)`) into typed `ISO_9945.Kernel.Descriptor`.
These are legitimate; no typed API can replace them — they *are* the typed-API
construction sites. They need *some* cross-package construction path.

## Inventory of cross-package raw-fd consumers (Path β close, 2026-05-02)

### Read-direction (`descriptor._rawValue` extraction)

| Site | Justification | Resolution |
|---|---|---|
| `swift-posix/POSIX.Kernel.Termios.swift:40` | None — typed entry exists | **FIXED in Path β close** (`0979335`) |
| `swift-posix/POSIX.Kernel.TTY.swift:46` | None — typed entry exists | **FIXED in Path β close** (`0979335`) |
| `swift-posix/POSIX.Kernel.TTY.swift:63` | None — typed entry exists | **FIXED in Path β close** (`0979335`) |
| `swift-kernel/Kernel Event/Kernel.Event.ID+Descriptor.swift:21-27` | L1↔L2 identity conversion | DEFERRED to relocation handoff |
| `swift-file-system/File System Core/File.Descriptor.swift:55,60` | Intentional L4 public surface (`File.Descriptor.rawValue`) | UNDECIDED — depends on this cycle |
| `swift-linux-foundation/swift-linux-standard/Sources/Linux Kernel IO Uring Standard/Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift:299, 308` | Syscall arg passing | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.IO.Uring.Target.swift:74` | Syscall arg passing | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.IO.Uring.swift:335, 364` | Syscall arg passing | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.IO.Uring+Wakeup.swift:47` | Syscall arg passing | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Event.Descriptor.swift:85, 87, 107, 109, 125` | eventfd read/write/signal | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Event.Poll.swift:127, 155, 157, 178` | epoll_ctl/wait | UNDECIDED |

### Construction-direction (`Descriptor(_rawValue:)`)

| Site | Justification | Resolution |
|---|---|---|
| `swift-kernel/Kernel Event/Kernel.Event.ID+Descriptor.swift:33-40` | reverse direction — **forbidden pattern** | **DELETED in Path β close** (`7c615fc`) |
| `swift-kernel/Kernel/Kernel.docc/event-apis.md:75` | doc example codifying reverse direction | **FIXED in Path β close** (`7c615fc`) — registry-lookup sketch |
| `swift-linux-foundation/.../Linux.Kernel.Pipe.swift:82-83` | wraps `pipe(2)` return | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Timer.Descriptor.swift:73` | wraps `timerfd_create(2)` return | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Process.Descriptor.swift:74` | wraps `pidfd_open(2)` return | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Signal.Descriptor.swift:77` | wraps `signalfd(2)` return | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Event.Descriptor.swift:68` | wraps `eventfd(2)` return | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.IO.Uring.swift:184` | wraps `io_uring_setup(2)` return | UNDECIDED |
| `swift-linux-foundation/.../Linux.Kernel.Event.Poll.swift:143` | wraps `epoll_create1(2)` return | UNDECIDED |

## Constraints on any solution

- **No underscored API names** (user direction).
- **`package var` storage** for `rawValue` (user direction; supports the
  retiring-of-`@_spi(Syscall)` direction the workspace has been moving toward —
  see Item 1.5 Phase 5 commit message).
- **Cross-package construction must remain possible** for swift-linux-foundation's
  ~7 syscall-result wrapping sites (`Pipe`, `Timer.Descriptor`,
  `Process.Descriptor`, `Signal.Descriptor`, `Event.Descriptor`, `IO.Uring`,
  `Event.Poll`). These cannot move into iso-9945 — they're Linux-specific
  syscalls, and iso-9945 is the POSIX standard layer.
- **Cross-package read access** for the ~12 sites above (passing raw fd into
  Linux syscalls).
- **Forbidden pattern** (`feedback_no_raw_descriptor_reconstruction`): no path
  may allow reconstructing a `Descriptor` from an arbitrary `Int32` after the
  original wrapper has been consumed. The legit construction sites are *fresh*
  fds returned from kernel syscalls, never round-tripped from existing
  Descriptors.

## Options

### Option A — `@_spi(Syscall) public init(rawValue:) + var rawValue`, no underscore

```swift
public struct Descriptor: ~Copyable, Sendable {
    @usableFromInline
    package var rawValue: Int32  // package storage
    // (init below in extension)
}

extension ISO_9945.Kernel.Descriptor {
    @_spi(Syscall) @inlinable
    public init(rawValue: Int32) { self.rawValue = rawValue }

    // No accessor in extension — would conflict with package var
}
```

**Problem:** the `package var rawValue` storage and a `@_spi(Syscall) public var rawValue`
accessor in the extension are a redeclaration error. Need to either drop the
accessor (cross-package read access lost) or rename storage internally.

**Verdict:** Functionally identical to Option C with a more obvious naming clash.

### Option B — Move all syscall-layer wrapping into iso-9945

Relocate `Linux.Kernel.Pipe`, `Linux.Kernel.Timer.Descriptor`, etc. from
swift-linux-foundation into iso-9945 under platform-conditional sources.

**Verdict:** *Wrong layer.* iso-9945 is the POSIX standard layer; Linux
extensions (eventfd, signalfd, timerfd, io_uring, epoll, pidfd) are
Linux-platform-specific and exceed POSIX. Putting Linux-only types into
iso-9945 inverts the layering and degrades the spec's identity.

### Option C — `package var` storage + `@_spi(Syscall) public` accessor pair, different storage name

```swift
public struct Descriptor: ~Copyable, Sendable {
    @usableFromInline
    package var storage: Int32   // package storage, non-underscored, hidden cross-package

    deinit { /* uses storage */ }
    public static var invalid: Descriptor { Descriptor(storage: 0).asInvalid() }
    public var isValid: Bool { storage >= 0 }
}

extension ISO_9945.Kernel.Descriptor {
    @_spi(Syscall) @inlinable
    public init(rawValue: Int32) { self.storage = rawValue }

    @_spi(Syscall) @inlinable
    public var rawValue: Int32 { storage }
}
```

**Pros:**
- User-facing single name `rawValue` (no underscore).
- Storage stays `package`.
- Cross-package access requires explicit `@_spi(Syscall) import` ceremony.
- Mirrors current shape closely; easy migration (just rename + drop one
  underscored form).

**Cons:**
- Re-introduces (in renamed form) the SPI surface that Item 1.5 Phase 5 was
  retiring. The prior reasoning was structurally distinct
  (`@_spi(Syscall)` on overloaded *methods* caused Wave 3.5's recursion bug;
  `@_spi(Syscall)` on *accessors* and *inits* does not). But re-emergence
  needs deliberate justification.
- Internal storage name `storage` is awkward when the public surface name
  is `rawValue` — minor cognitive cost when reading iso-9945-internal code.

### Option D — `withRawHandle { rawFd in … }` borrow-scoped accessor + named adopting init

```swift
public struct Descriptor: ~Copyable, Sendable {
    @usableFromInline
    package var rawValue: Int32  // package, single name
}

extension ISO_9945.Kernel.Descriptor {
    /// Borrow-scoped raw-fd access for cross-package syscall layers.
    /// The fd is valid only for the duration of `body`.
    @_spi(Syscall) @inlinable
    public func withRawHandle<R, E: Error>(
        _ body: (Int32) throws(E) -> R
    ) throws(E) -> R {
        try body(rawValue)
    }

    /// Adopts a kernel-allocated raw fd. Caller asserts the fd is fresh
    /// from a syscall (no double-wrap).
    @_spi(Syscall) @inlinable
    public init(adoptingRawHandle rawValue: Int32) {
        self.rawValue = rawValue
    }
}
```

**Pros:**
- `withRawHandle { … }` makes the raw-fd validity scope **explicit** — the
  closure body owns the read, can't escape.
- `init(adoptingRawHandle:)` makes the construction intent **explicit** — this
  is a *fresh* fd from a syscall, not a round-trip. Matches Apple's
  System.framework `FileDescriptor(rawValue:)` semantics in spirit.
- No accessor/storage redeclaration issue (no public `var rawValue`).
- Aligns with `feedback_no_raw_descriptor_reconstruction`: the
  `adoptingRawHandle:` label signals "you are creating a fresh wrapper", not
  reconstructing.

**Cons:**
- swift-linux-foundation's ~12 read-direction sites need rewriting from
  `descriptor._rawValue` to `descriptor.withRawHandle { fd in … }`. Mechanical
  but verbose.
- swift-linux-foundation's ~7 construction sites need rewriting from
  `Descriptor(_rawValue: fd)` to `Descriptor(adoptingRawHandle: fd)`. Also
  mechanical.
- swift-file-system's `File.Descriptor.rawValue` public API needs to become
  `File.Descriptor.withRawHandle { … }` — **API-breaking change** for L4
  consumers.
- Closure ceremony adds friction at hot syscall paths (though `@inlinable` should
  optimize through).

### Option E — Plain `public` access on `~Copyable Descriptor`

```swift
public struct Descriptor: ~Copyable, Sendable {
    @usableFromInline
    public var rawValue: Int32  // plain public — anyone can read
}

extension ISO_9945.Kernel.Descriptor {
    @inlinable
    public init(rawValue: Int32) { self.rawValue = rawValue }
}
```

**Verdict:** *Don't recommend.* Eliminates the encapsulation goal (anyone can
extract or fabricate a raw fd from anywhere). The whole point of typed L2
descriptors over raw `Int32` is to gate raw access; making `rawValue` plain
public collapses the design. Listed for completeness only.

## Prior art

- Apple System.framework `FileDescriptor`:
  ```swift
  @frozen public struct FileDescriptor {
      public let rawValue: CInt
      public init(rawValue: CInt) { self.rawValue = rawValue }
  }
  ```
  Plain `public` (Option E equivalent). Apple's design accepts the encapsulation
  trade-off — `FileDescriptor` is a thin wrapper, not the "no raw extraction"
  type the workspace is building toward.
- Swift Standard Library `RawRepresentable`:
  ```swift
  public protocol RawRepresentable {
      associatedtype RawValue
      init?(rawValue: RawValue)
      var rawValue: RawValue { get }
  }
  ```
  Conformance not applicable here (`Descriptor` is `~Copyable`,
  `RawRepresentable` requires `Copyable`). But the naming convention
  (`rawValue`) and the failable init shape are the closest stdlib analog.
- swift-tagged-primitives `Tagged.init(__unchecked: Void, _ rawValue: …)`:
  uses a `Void` discriminator label to mark the "no domain validation" path.
  Could iso-9945 use a similar discriminator (`init(__syscall: (), _ rawValue: Int32)`)
  to mark the syscall-layer construction without `@_spi`? Worth considering
  as Option F if the SPI re-emergence concern (Option C) is decisive.

## Recommendation (preliminary; needs principal review)

Lean toward **Option D** (`withRawHandle` + `init(adoptingRawHandle:)`) for
new sites and **Option C** as the migration intermediate.

Option D's explicit naming (`adoptingRawHandle`, `withRawHandle`) maps better
onto the `feedback_no_raw_descriptor_reconstruction` invariant than Option C's
`rawValue` (which is symmetric and doesn't signal construction intent). Apple's
choice is at one extreme (Option E); Option D pulls slightly tighter while still
keeping the L1 standard-name convention via the closure scope.

The mechanical migration cost (rewriting swift-linux-foundation's 19+ sites
plus swift-file-system's L4 surface) is real but bounded. The API-breaking
change to `File.Descriptor.rawValue` is the largest risk and may itself
deserve a separate cycle.

## Decision blockers

1. Does the swift-foundations / swift-file-system layer publicly contract
   `File.Descriptor.rawValue` for L4 / L5 (Apps) consumers? If yes, breaking
   that contract is a versioned-API change with downstream impact analysis.
2. Is the `~17 sites` mechanical rewrite at swift-linux-foundation acceptable
   in the same cycle as the iso-9945 surface change? Or split into a
   prerequisite cycle (`Descriptor` surface lands first; swift-linux-foundation
   migration follows)?
3. Does Option F (`__syscall: ()` discriminator pattern, no `@_spi`) need
   serious evaluation? swift-tagged-primitives precedent exists; `@_spi` is
   only one mechanism for "explicit ceremony at use sites".

## Next steps

1. **Surface to principal** for review of options + the three blockers.
2. **Decide** the access surface (DECIDED status).
3. **Sequence the migration**:
   - Phase 1: change `Descriptor` surface at iso-9945.
   - Phase 2: migrate swift-linux-foundation cross-package consumers.
   - Phase 3: address swift-file-system's `File.Descriptor.rawValue` (separate
     versioned-API cycle if Phase 1 chose Option D).
4. **Unblock the deferred Event.ID(descriptor:) relocation handoff**
   (`/Users/coen/Developer/swift-institute/HANDOFF-event-id-descriptor-conversion-relocation-2026-05-02.md`)
   once the surface decision lands.

## Origin

Path β migration close (Wave 3.5-Corrective Phase 2, 2026-05-02). The
inventory pass during the close revealed the dual `_raw`/`_rawValue` surface
and the asymmetric scope of cross-package consumers. Principal disposition
deferred this from the Path β close to a dedicated research cycle since the
decision affects ~20+ cross-package consumer sites and re-emerges the
`@_spi(Syscall)` mechanism (which Item 1.5 Phase 5 was retiring).

Status remains **INVESTIGATION** until principal-level review.
