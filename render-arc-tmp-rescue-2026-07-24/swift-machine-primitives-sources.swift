# swift-machine-primitives

## Package Manifest

// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-machine-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        // MARK: - Namespace
        .library(
            name: "Machine Primitive",
            targets: ["Machine Primitive"]
        ),
        .library(
            name: "Machine Primitives",
            targets: ["Machine Primitives"]
        ),
        .library(
            name: "Machine Value Primitives",
            targets: ["Machine Value Primitives"]
        ),
        .library(
            name: "Machine Capture Primitives",
            targets: ["Machine Capture Primitives"]
        ),
        .library(
            name: "Machine Transform Primitives",
            targets: ["Machine Transform Primitives"]
        ),
        .library(
            name: "Machine Combine Primitives",
            targets: ["Machine Combine Primitives"]
        ),
        .library(
            name: "Machine Next Primitives",
            targets: ["Machine Next Primitives"]
        ),
        .library(
            name: "Machine Finalize Primitives",
            targets: ["Machine Finalize Primitives"]
        ),
        .library(
            name: "Machine Frame Primitives",
            targets: ["Machine Frame Primitives"]
        ),
        .library(
            name: "Machine Node Primitives",
            targets: ["Machine Node Primitives"]
        ),
        .library(
            name: "Machine Program Primitives",
            targets: ["Machine Program Primitives"]
        ),
        .library(
            name: "Machine Convenience Primitives",
            targets: ["Machine Convenience Primitives"]
        ),
        .library(
            name: "Machine Primitives Test Support",
            targets: ["Machine Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-graph-primitives.git", branch: "main"),
    ],
    targets: [
        // MARK: - Namespace
        .target(
            name: "Machine Primitive",
            dependencies: []
        ),

        // MARK: - Value & Capture

        .target(
            name: "Machine Value Primitives",
            dependencies: [
                "Machine Primitive",
            ]
        ),
        .target(
            name: "Machine Capture Primitives",
            dependencies: [
                "Machine Primitive",
            ]
        ),

        // MARK: - Carriers

        .target(
            name: "Machine Transform Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),
        .target(
            name: "Machine Combine Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),
        .target(
            name: "Machine Next Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),
        .target(
            name: "Machine Finalize Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),

        // MARK: - Composition

        .target(
            name: "Machine Frame Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Transform Primitives",
                "Machine Combine Primitives",
                "Machine Next Primitives",
                "Machine Finalize Primitives",
            ]
        ),
        .target(
            name: "Machine Node Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Transform Primitives",
                "Machine Combine Primitives",
                "Machine Next Primitives",
                "Machine Finalize Primitives",
                // Node.ID = Graph.Node, Adjacency.Extract — declared directly per [MOD-038]
                // (previously reached transitively via the dissolved Core funnel).
                .product(name: "Graph Sequential Primitives", package: "swift-graph-primitives"),
            ]
        ),
        .target(
            name: "Machine Program Primitives",
            dependencies: [
                "Machine Node Primitives",
                "Machine Capture Primitives",
                // Program/Builder use Graph.Sequential storage directly per [MOD-038]
                // (previously reached transitively via the dissolved Core funnel).
                .product(name: "Graph Sequential Primitives", package: "swift-graph-primitives"),
            ]
        ),

        // MARK: - Convenience

        .target(
            name: "Machine Convenience Primitives",
            dependencies: [
                "Machine Program Primitives",
            ]
        ),

        // MARK: - Umbrella

        .target(
            name: "Machine Primitives",
            dependencies: [
                "Machine Primitive",
                "Machine Value Primitives",
                "Machine Capture Primitives",
                "Machine Transform Primitives",
                "Machine Combine Primitives",
                "Machine Next Primitives",
                "Machine Finalize Primitives",
                "Machine Frame Primitives",
                "Machine Node Primitives",
                "Machine Program Primitives",
                "Machine Convenience Primitives",
                // Narrowed to Graph Primitives: the Machine umbrella only ever
                // surfaces Graph.Node/Adjacency/Sequential/Analyze (all in Core).
                // Depending on the full Graph umbrella over-broadly re-exported the
                // graph algorithms + their data-structure cohort ([MOD-006]/[MOD-015]).
                .product(name: "Graph Sequential Primitives", package: "swift-graph-primitives"),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "Machine Value Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Combine Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Transform Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Next Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Finalize Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Frame Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Node Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Program Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),

        // MARK: - Test Support
        .target(
            name: "Machine Primitives Test Support",
            dependencies: [
                "Machine Primitives",
                .product(name: "Graph Primitives Test Support", package: "swift-graph-primitives"),
            ],
            path: "Tests/Support"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}

## File Structure

~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Frozen+Reference.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Frozen+Unchecked.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Frozen.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.ID.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.RawID.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Slot.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Store+Reference.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Store+Unchecked.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Store.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Capture Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Combine Primitives/Machine.Combine.Erased.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Combine Primitives/Machine.Combine.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Combine Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Convenience Primitives/Machine.Builder+Carriers.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Convenience Primitives/Machine.Program+Apply.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Convenience Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Finalize Primitives/Machine.Finalize.Array.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Finalize Primitives/Machine.Finalize.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Finalize Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Frame Primitives/Machine.Frame.Sequence.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Frame Primitives/Machine.Frame.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Frame Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Next Primitives/Machine.Next.Erased.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Next Primitives/Machine.Next.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Next Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Node Primitives/Machine.Node.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Node Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Primitive/Machine.Capture.Mode.Reference.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Primitive/Machine.Capture.Mode.Unchecked.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Primitive/Machine.Capture.Mode.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Primitive/Machine.Capture.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Primitive/Machine.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Program Primitives/Machine.Program.Builder.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Program Primitives/Machine.Program.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Program Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Transform Primitives/Machine.Transform.Erased.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Transform Primitives/Machine.Transform.Throwing.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Transform Primitives/Machine.Transform.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Transform Primitives/exports.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Value Primitives/Machine.Value.Arena.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Value Primitives/Machine.Value.Handle.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Value Primitives/Machine.Value.swift
~/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Value Primitives/exports.swift

## Source Files

### File: Sources/Machine Capture Primitives/Machine.Capture.Frozen+Reference.swift

extension Machine.Capture.Frozen where Mode == Machine.Capture.Mode.Reference {
    /// Accesses a captured value by its typed ID.
    @inlinable
    public func with<Value: Sendable, R>(
        _ id: Machine.Capture.ID<Value>,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[id.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with explicit type.
    public func withRaw<Value: Sendable, R>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with typed throws.
    public func withRawThrowing<Value: Sendable, R, E: Swift.Error>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) throws(E) -> R
    ) throws(E) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return try body(value)
    }
}

### File: Sources/Machine Capture Primitives/Machine.Capture.Frozen+Unchecked.swift

extension Machine.Capture.Frozen where Mode == Machine.Capture.Mode.Unchecked {
    /// Accesses a captured value by its typed ID.
    @inlinable
    public func with<Value, R>(
        _ id: Machine.Capture.ID<Value>,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[id.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with explicit type.
    public func withRaw<Value, R>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with typed throws.
    public func withRawThrowing<Value, R, E: Swift.Error>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) throws(E) -> R
    ) throws(E) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return try body(value)
    }
}
// No Sendable conformance for Frozen<Unchecked>: Mode.Unchecked is itself
// non-Sendable per [MEM-SEND-013] Pattern B (terminal direction). Consumers
// transport assembled `Program`/`Parser` values across isolation domains via
// `sending` at the program-transport boundary, not via a structural Sendable
// conformance on Frozen<Unchecked>.

### File: Sources/Machine Capture Primitives/Machine.Capture.Frozen.swift

extension Machine.Capture {
    /// Immutable snapshot of captured values for program execution.
    ///
    /// `Frozen<Mode>` is produced by `Store<Mode>.freeze()` and used
    /// by the machine interpreter to access captured values at runtime.
    ///
    /// ## Sendable
    ///
    /// `Frozen<Mode>` is Sendable when `Mode: Sendable`. For `Mode.Reference`,
    /// this is sound because:
    /// - All values were inserted via `Store.insert<T: Sendable>`
    /// - `Slot` is `@unchecked Sendable` with construction-enforced invariants
    /// - The slots array is immutable (`let`)
    public struct Frozen<Mode> {
        /// The frozen capture slots, indexed by `RawID.rawValue`.
        public let slots: [Slot]

        @usableFromInline
        init(__slots: [Slot]) {
            self.slots = __slots
        }
    }
}

// MARK: - Sendable

extension Machine.Capture.Frozen: Sendable where Mode: Sendable {}

### File: Sources/Machine Capture Primitives/Machine.Capture.ID.swift

extension Machine.Capture {
    /// A typed handle to a captured value of type `Value` in a capture store.
    public struct ID<Value>: Hashable, Sendable {
        /// The untyped slot identifier this typed handle wraps.
        public let raw: RawID

        @usableFromInline
        init(_ raw: RawID) {
            self.raw = raw
        }

        /// The underlying slot index.
        @inlinable
        public var rawValue: Int { raw.rawValue }
    }
}

### File: Sources/Machine Capture Primitives/Machine.Capture.RawID.swift

extension Machine.Capture {
    /// An untyped slot identifier into a capture store.
    public struct RawID: Hashable, Sendable {
        /// The underlying slot index.
        public let rawValue: Int

        @usableFromInline
        init(_ rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

### File: Sources/Machine Capture Primitives/Machine.Capture.Slot.swift

extension Machine.Capture {
    // WHY: Category D — structural Sendable workaround (SP-5).
    // WHY: Struct wraps _Storage (immutable after construction) + ObjectIdentifier.
    // WHY: @unchecked forced because inner _Storage is itself @unchecked.
    // WHEN TO REMOVE: When inner _Storage gains structural Sendable.
    // TRACKING: unsafe-audit-findings.md Category D SP-5.
    /// Table-based erased storage for a captured value.
    ///
    /// `Slot` stores a type-erased value using raw pointer storage and a
    /// type-specialized destroy function. No existentials (`AnyObject`, `Any`)
    /// or dynamic casts (`as?`, `as!`) are used.
    public struct Slot: @unchecked Sendable {
        @usableFromInline
        let type: ObjectIdentifier

        @usableFromInline
        let storage: _Storage

        #if DEBUG
            @usableFromInline
            let typeName: String
        #endif

        /// Creates a slot storing the given value.
        @usableFromInline
        init<T>(_ value: T) {
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
            unsafe pointer.initialize(to: value)

            self.type = ObjectIdentifier(T.self)
            self.storage = unsafe _Storage(
                payload: UnsafeMutableRawPointer(pointer),
                destroy: { raw in
                    unsafe raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                    unsafe raw.deallocate()
                }
            )
            #if DEBUG
                self.typeName = String(reflecting: T.self)
            #endif
        }
    }
}

extension Machine.Capture.Slot {
    // WHY: Category D — structural Sendable workaround (SP-5) per [MEM-SAFE-024].
    // WHY: Immutable pointer + @Sendable destroy function. UnsafeMutableRawPointer
    // WHY: blocks structural inference. No synchronization.
    // WHY: Encapsulation invariant per [MEM-SAFE-021] — `_Storage` is `@usableFromInline`
    // WHY: but its raw-pointer storage is internal-only; consumers see only the
    // WHY: type-safe `Slot` surface.
    // WHEN TO REMOVE: When compiler gains structural Sendable through raw pointers.
    // TRACKING: unsafe-audit-findings.md Category D SP-5.
    /// Reference-counted storage for the erased payload.
    @usableFromInline
    final class _Storage: @unchecked Sendable {
        @usableFromInline
        let payload: UnsafeMutableRawPointer

        @usableFromInline
        let destroy: @Sendable (UnsafeMutableRawPointer) -> Void

        @usableFromInline
        init(
            payload: UnsafeMutableRawPointer,
            destroy: @escaping @Sendable (UnsafeMutableRawPointer) -> Void
        ) {
            unsafe (self.payload = payload)
            unsafe (self.destroy = destroy)
        }

        deinit {
            unsafe destroy(payload)
        }
    }

    /// Single choke-point for payload projection.
    ///
    /// All `assumingMemoryBound` calls for reading go through here.
    @usableFromInline
    func _project<T>(_: T.Type) -> UnsafePointer<T> {
        unsafe UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
    }

    /// Reads the stored value, checking the type matches.
    public func read<T>(_: T.Type) -> T {
        #if DEBUG
            precondition(
                type == ObjectIdentifier(T.self),
                "Capture type mismatch: expected \(T.self), stored \(typeName)"
            )
        #else
            precondition(type == ObjectIdentifier(T.self))
        #endif
        return unsafe _project(T.self).pointee
    }
}

### File: Sources/Machine Capture Primitives/Machine.Capture.Store+Reference.swift

extension Machine.Capture.Store where Mode == Machine.Capture.Mode.Reference {
    /// Inserts a Sendable value and returns a typed capture ID.
    ///
    /// The Sendable constraint ensures all values in Reference mode are safe
    /// to share across isolation domains.
    @inlinable
    public mutating func insert<Value: Sendable>(_ value: Value) -> Machine.Capture.ID<Value> {
        let raw = Machine.Capture.RawID(slots.count)
        slots.append(Machine.Capture.Slot(value))
        return Machine.Capture.ID<Value>(raw)
    }

    /// Accesses a captured value by its typed ID.
    @inlinable
    public func with<Value: Sendable, R>(
        _ id: Machine.Capture.ID<Value>,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[id.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with explicit type.
    @usableFromInline
    func withRaw<Value: Sendable, R>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with typed throws.
    @usableFromInline
    func withRawThrowing<Value: Sendable, R, E: Swift.Error>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) throws(E) -> R
    ) throws(E) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return try body(value)
    }
}

### File: Sources/Machine Capture Primitives/Machine.Capture.Store+Unchecked.swift

extension Machine.Capture.Store where Mode == Machine.Capture.Mode.Unchecked {
    /// Inserts a value and returns a typed capture ID.
    ///
    /// No Sendable constraint—use Unchecked mode when Sendable is not required.
    @inlinable
    public mutating func insert<Value>(_ value: Value) -> Machine.Capture.ID<Value> {
        let raw = Machine.Capture.RawID(slots.count)
        slots.append(Machine.Capture.Slot(value))
        return Machine.Capture.ID<Value>(raw)
    }

    /// Accesses a captured value by its typed ID.
    @inlinable
    public func with<Value, R>(
        _ id: Machine.Capture.ID<Value>,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[id.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with explicit type.
    @usableFromInline
    func withRaw<Value, R>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) -> R
    ) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return body(value)
    }

    /// Accesses a captured value by raw ID with typed throws.
    @usableFromInline
    func withRawThrowing<Value, R, E: Swift.Error>(
        _ raw: Machine.Capture.RawID,
        as _: Value.Type,
        _ body: (borrowing Value) throws(E) -> R
    ) throws(E) -> R {
        let slot = slots[raw.rawValue]
        let value = slot.read(Value.self)
        return try body(value)
    }
}

### File: Sources/Machine Capture Primitives/Machine.Capture.Store.swift

extension Machine.Capture {
    /// Mutable storage for captured values during program construction.
    ///
    /// `Store<Mode>` accumulates type-erased values that will be used by
    /// the machine at runtime. Call `freeze()` to produce an immutable
    /// `Frozen<Mode>` for use with the final `Program`.
    ///
    /// ## Mode
    ///
    /// - `Mode.Reference`: `insert` requires `T: Sendable`
    /// - `Mode.Unchecked`: `insert` accepts any `T`
    public struct Store<Mode> {
        @usableFromInline
        var slots: [Slot]

        /// Creates an empty capture store.
        @inlinable
        public init() {
            self.slots = []
        }

        /// Freezes the store into an immutable `Frozen` for program execution.
        @inlinable
        public consuming func freeze() -> Frozen<Mode> {
            Frozen(__slots: slots)
        }
    }
}

### File: Sources/Machine Capture Primitives/exports.swift

@_exported public import Machine_Primitive

### File: Sources/Machine Combine Primitives/Machine.Combine.Erased.swift

extension Machine.Combine {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased binary combination operation.
    ///
    /// Combines two values into a single result value, used for
    /// sequence operations in the machine.
    @safe
    public struct Erased<Mode>: Sendable {
        /// The capture slot holding the underlying typed combine function.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _combine:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>,
                Machine.Value<Mode>
            ) -> Machine.Value<Mode>

        /// Combines two values into one using the frozen captures.
        @inlinable
        public func combine(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ a: Machine.Value<Mode>,
            _ b: Machine.Value<Mode>
        ) -> Machine.Value<Mode> {
            _combine(captures, a, b)
        }
    }
}

extension Machine.Combine.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased combine from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<A, B, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (A, B) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._combine = { captures, a, b in
            captures.withRaw(raw, as: (@Sendable (A, B) -> Out).self) { combineFn in
                a.combine(b, using: combineFn)
            }
        }
    }
}

extension Machine.Combine.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased combine from a captured typed function (Unchecked mode).
    @inlinable
    public init<A, B, Out>(
        capture: Machine.Capture.ID<(A, B) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._combine = { captures, a, b in
            captures.withRaw(raw, as: ((A, B) -> Out).self) { combineFn in
                a.combine(b, using: combineFn)
            }
        }
    }
}

### File: Sources/Machine Combine Primitives/Machine.Combine.swift

extension Machine {
    /// A namespace for type-erased combination operations.
    public enum Combine {}
}

### File: Sources/Machine Combine Primitives/exports.swift

@_exported public import Machine_Capture_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Convenience Primitives/Machine.Builder+Carriers.swift

public import Machine_Program_Primitives

// MARK: - Builder Carrier Factory Conveniences (Reference Mode)

extension Machine.Builder where Mode == Machine.Capture.Mode.Reference {
    // MARK: Transform.Erased

    /// Creates a type-erased transform by capturing a closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let transform = Transform.Erased<Mode>(capture: captureID)
    /// ```
    @inlinable
    public mutating func transform<In, Out: Sendable>(
        _ fn: @escaping @Sendable (In) -> Out
    ) -> Machine.Transform.Erased<Mode> {
        let captureID = captures.insert(fn)
        return Machine.Transform.Erased<Mode>(capture: captureID)
    }

    // MARK: Transform.Throwing

    /// Creates a type-erased throwing transform by capturing a closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let transform = Transform.Throwing<Mode, Failure>(capture: captureID)
    /// ```
    @inlinable
    public mutating func throwingTransform<In, Out: Sendable>(
        _ fn: @escaping @Sendable (In) throws(Failure) -> Out
    ) -> Machine.Transform.Throwing<Mode, Failure> {
        let captureID = captures.insert(fn)
        return Machine.Transform.Throwing<Mode, Failure>(capture: captureID)
    }

    // MARK: Combine.Erased

    /// Creates a type-erased combine by capturing a binary closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let combine = Combine.Erased<Mode>(capture: captureID)
    /// ```
    @inlinable
    public mutating func combine<A, B, Out: Sendable>(
        _ fn: @escaping @Sendable (A, B) -> Out
    ) -> Machine.Combine.Erased<Mode> {
        let captureID = captures.insert(fn)
        return Machine.Combine.Erased<Mode>(capture: captureID)
    }

    // MARK: Next.Erased

    /// Creates a type-erased next selector by capturing a closure.
    ///
    /// Convenience for:
    /// ```swift
    /// let captureID = builder.captures.insert(fn)
    /// let next = Next.Erased<Mode, NodeID>(capture: captureID)
    /// ```
    @inlinable
    public mutating func next<In>(
        _ fn: @escaping @Sendable (In) -> Machine.Node<Leaf, Failure, Mode>.ID
    ) -> Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID> {
        let captureID = captures.insert(fn)
        return Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID>(capture: captureID)
    }

    // MARK: Finalize.Array

    /// Creates a type-erased array finalizer for a given element type.
    ///
    /// Convenience for:
    /// ```swift
    /// let finalize = Finalize.Array<Mode>(elementType: T.self, store: &builder.captures)
    /// ```
    @inlinable
    public mutating func finalize<T: Sendable>(
        elementType: T.Type
    ) -> Machine.Finalize.Array<Mode> {
        Machine.Finalize.Array<Mode>(elementType: T.self, store: &captures)
    }
}

### File: Sources/Machine Convenience Primitives/Machine.Program+Apply.swift

public import Machine_Program_Primitives

// MARK: - Program Apply Conveniences

extension Machine.Program {
    // MARK: Transform.Erased

    /// Applies a transform using this program's frozen captures.
    ///
    /// Convenience for `transform.apply(using: captures, value)`.
    @inlinable
    public func apply(
        _ transform: Machine.Transform.Erased<Mode>,
        to value: Machine.Value<Mode>
    ) -> Machine.Value<Mode> {
        transform.apply(using: captures, value)
    }

    // MARK: Transform.Throwing

    /// Applies a throwing transform using this program's frozen captures.
    ///
    /// Convenience for `transform.apply(using: captures, value)`.
    @inlinable
    public func apply(
        _ transform: Machine.Transform.Throwing<Mode, Failure>,
        to value: Machine.Value<Mode>
    ) throws(Failure) -> Machine.Value<Mode> {
        try transform.apply(using: captures, value)
    }

    // MARK: Combine.Erased

    /// Combines two values using this program's frozen captures.
    ///
    /// Convenience for `combine.combine(using: captures, a, b)`.
    @inlinable
    public func combine(
        _ combine: Machine.Combine.Erased<Mode>,
        _ a: Machine.Value<Mode>,
        _ b: Machine.Value<Mode>
    ) -> Machine.Value<Mode> {
        combine.combine(using: captures, a, b)
    }

    // MARK: Next.Erased

    /// Selects the next node using this program's frozen captures.
    ///
    /// Convenience for `next.next(using: captures, value)`.
    @inlinable
    public func next(
        _ next: Machine.Next.Erased<Mode, Machine.Node<Leaf, Failure, Mode>.ID>,
        from value: Machine.Value<Mode>
    ) -> Machine.Node<Leaf, Failure, Mode>.ID {
        next.next(using: captures, value)
    }

    // MARK: Finalize.Array

    /// Finalizes an array of values using this program's frozen captures.
    ///
    /// Convenience for `finalize.finalize(using: captures, values)`.
    @inlinable
    public func finalize(
        _ finalize: Machine.Finalize.Array<Mode>,
        _ values: [Machine.Value<Mode>]
    ) -> Machine.Value<Mode> {
        finalize.finalize(using: captures, values)
    }
}

### File: Sources/Machine Convenience Primitives/exports.swift

@_exported public import Machine_Program_Primitives

### File: Sources/Machine Finalize Primitives/Machine.Finalize.Array.swift

extension Machine.Finalize {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased array finalization operation.
    ///
    /// Converts a collection of values into a single typed array value,
    /// used for the `many` combinator.
    @safe
    public struct Array<Mode>: Sendable {
        /// The capture slot holding the underlying typed finalize function.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _finalize:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                [Machine.Value<Mode>]
            ) -> Machine.Value<Mode>

        /// Converts the collected values into a single typed array value.
        @inlinable
        public func finalize(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ values: [Machine.Value<Mode>]
        ) -> Machine.Value<Mode> {
            _finalize(captures, values)
        }
    }
}

extension Machine.Finalize.Array where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased finalizer from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<T: Sendable>(
        capture: Machine.Capture.ID<@Sendable ([Machine.Value<Mode>]) -> [T]>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._finalize = { captures, values in
            captures.withRaw(raw, as: (@Sendable ([Machine.Value<Mode>]) -> [T]).self) { finalizeFn in
                Machine.Value<Mode>.make(finalizeFn(values))
            }
        }
    }

    /// Creates and captures a finalizer that extracts `[T]` from the erased values (Reference mode).
    @inlinable
    public init<T: Sendable>(
        elementType: T.Type,
        store: inout Machine.Capture.Store<Mode>
    ) {
        let finalizeFn: @Sendable ([Machine.Value<Mode>]) -> [T] = { values in
            values.map { $0[as: T.self] }
        }
        let captureID = store.insert(finalizeFn)
        self.init(capture: captureID)
    }
}

extension Machine.Finalize.Array where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased finalizer from a captured typed function (Unchecked mode).
    @inlinable
    public init<T>(
        capture: Machine.Capture.ID<([Machine.Value<Mode>]) -> [T]>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._finalize = { captures, values in
            captures.withRaw(raw, as: (([Machine.Value<Mode>]) -> [T]).self) { finalizeFn in
                Machine.Value<Mode>.make(finalizeFn(values))
            }
        }
    }

    /// Creates and captures a finalizer that extracts `[T]` from the erased values (Unchecked mode).
    @inlinable
    public init<T>(
        elementType: T.Type,
        store: inout Machine.Capture.Store<Mode>
    ) {
        let finalizeFn: ([Machine.Value<Mode>]) -> [T] = { values in
            values.map { $0[as: T.self] }
        }
        let captureID = store.insert(finalizeFn)
        self.init(capture: captureID)
    }
}

### File: Sources/Machine Finalize Primitives/Machine.Finalize.swift

extension Machine {
    /// A namespace for type-erased finalization operations.
    public enum Finalize {}
}

### File: Sources/Machine Finalize Primitives/exports.swift

@_exported public import Machine_Capture_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Frame Primitives/Machine.Frame.Sequence.swift

extension Machine.Frame {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// Sequence continuation state within a frame.
    ///
    /// Tracks progress through a two-element sequence operation.
    @safe
    public enum Sequence {
        /// Waiting to execute the second child.
        case second(b: NodeID, combine: Machine.Combine.Erased<Mode>)

        /// Stores handle to first value in arena, waiting for second value.
        case combine(firstHandle: Machine.Value<Mode>.Handle, combine: Machine.Combine.Erased<Mode>)
    }
}

### File: Sources/Machine Frame Primitives/Machine.Frame.swift

extension Machine {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A stack frame in the machine's execution.
    ///
    /// `Frame` represents the continuation state when the machine enters
    /// a child node. It is generic over:
    /// - `NodeID`: The node identifier type
    /// - `Checkpoint`: The cursor checkpoint type (varies by cursor)
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    /// - `Failure`: The error type for fallible operations
    /// - `Extra`: Extension point for façade-specific frame types (use `Never` if not needed)
    @safe
    public enum Frame<NodeID, Checkpoint, Mode, Failure: Swift.Error, Extra> {
        /// Apply a non-throwing transform to the result.
        case map(transform: Transform.Erased<Mode>)

        /// Apply a throwing transform to the result.
        case tryMap(transform: Transform.Throwing<Mode, Failure>)

        /// Select the next node based on the result.
        case flatMap(next: Next.Erased<Mode, NodeID>)

        /// Sequence continuation state.
        case sequence(Sequence)

        /// Backtracking frame for oneOf - stores checkpoint instead of full input copy.
        case oneOf(alternatives: [NodeID], index: Int, savedCheckpoint: Checkpoint)

        /// Accumulation frame for many - stores handles to accumulated results.
        case many(child: NodeID, savedCheckpoint: Checkpoint, resultHandles: [Value<Mode>.Handle], finalize: Finalize.Array<Mode>)

        /// Fold frame - accumulates without allocation using combine function.
        case fold(child: NodeID, savedCheckpoint: Checkpoint, accumulatorHandle: Value<Mode>.Handle, combine: Combine.Erased<Mode>)

        /// Optional frame - stores handle to none value for backtracking.
        case optional(savedCheckpoint: Checkpoint, wrapSome: Transform.Erased<Mode>, noneHandle: Value<Mode>.Handle)

        /// Marker for recursive call return.
        case recursiveExit

        /// Extension point for façade-specific frames.
        ///
        /// Use `Extra = Never` when no additional frame types are needed (the case becomes uninhabited).
        /// Parsing uses this for memoization: `Extra = Frame.Extra` with `.memoization(node:startPosition:)`.
        case extra(Extra)
    }
}

### File: Sources/Machine Frame Primitives/exports.swift

@_exported public import Machine_Combine_Primitives
@_exported public import Machine_Finalize_Primitives
@_exported public import Machine_Next_Primitives
@_exported public import Machine_Transform_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Next Primitives/Machine.Next.Erased.swift

extension Machine.Next {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased next-node selection function for flatMap.
    ///
    /// Given a value, selects the next node ID to execute, enabling
    /// cursor-agnostic flatMap operations in the machine.
    @safe
    public struct Erased<Mode, NodeID>: Sendable {
        /// The capture slot holding the underlying typed selection function.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _next:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) -> NodeID

        /// Selects the next node ID for the given value using the frozen captures.
        @inlinable
        public func next(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) -> NodeID {
            _next(captures, value)
        }
    }
}

extension Machine.Next.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased selector from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In>(
        capture: Machine.Capture.ID<@Sendable (In) -> NodeID>
    ) where NodeID: Sendable {
        let raw = capture.raw
        self.capture = raw
        self._next = { captures, value in
            captures.withRaw(raw, as: (@Sendable (In) -> NodeID).self) { nextFn in
                nextFn(value[as: In.self])
            }
        }
    }
}

extension Machine.Next.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased selector from a captured typed function (Unchecked mode).
    @inlinable
    public init<In>(
        capture: Machine.Capture.ID<(In) -> NodeID>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._next = { captures, value in
            captures.withRaw(raw, as: ((In) -> NodeID).self) { nextFn in
                nextFn(value[as: In.self])
            }
        }
    }
}

### File: Sources/Machine Next Primitives/Machine.Next.swift

extension Machine {
    /// A namespace for type-erased next-node selection operations.
    public enum Next {}
}

### File: Sources/Machine Next Primitives/exports.swift

@_exported public import Machine_Capture_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Node Primitives/Machine.Node.swift

public import Graph_Sequential_Primitives

extension Machine {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A node in the machine's program graph.
    ///
    /// `Node` represents a single operation in a defunctionalized parser program.
    /// It is generic over:
    /// - `Leaf`: The primitive cursor operations (cursor-specific)
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    ///
    /// The machine interpreter traverses the node graph, executing leaf operations
    /// and combining results according to the combinator structure.
    @safe
    public enum Node<Leaf, Failure: Swift.Error, Mode> {

        /// A unique identifier for a node in the program.
        public typealias ID = Graph.Node<Self>

        /// A primitive cursor operation.
        case leaf(Leaf)

        /// A pure value (no cursor interaction).
        case pure(Value<Mode>)

        /// Transform the result of a child node.
        case map(child: ID, transform: Transform.Erased<Mode>)

        /// Transform the result of a child node, potentially failing.
        case tryMap(child: ID, transform: Transform.Throwing<Mode, Failure>)

        /// Execute a child, then select the next node based on its result.
        case flatMap(child: ID, next: Next.Erased<Mode, ID>)

        /// Execute two nodes in sequence, combining their results.
        case sequence(a: ID, b: ID, combine: Combine.Erased<Mode>)

        /// Try alternatives in order until one succeeds.
        case oneOf([ID])

        /// Execute a child zero or more times, collecting results.
        case many(child: ID, finalize: Finalize.Array<Mode>)

        /// Execute a child zero or more times, folding results without allocation.
        ///
        /// Unlike `many` which collects into an array, `fold` accumulates incrementally:
        /// 1. Start with `initial` as accumulator
        /// 2. Try to parse `child`
        /// 3. If success: `accumulator = combine(accumulator, childResult)`, repeat
        /// 4. If failure: return accumulator
        case fold(child: ID, initial: Value<Mode>, combine: Combine.Erased<Mode>)

        /// Execute a child optionally, wrapping success or returning none.
        case optional(child: ID, wrapSome: Transform.Erased<Mode>, noneValue: Value<Mode>)

        /// Reference to another node (for recursive grammars).
        case ref(ID)

        /// Placeholder for forward references during construction.
        case hole
    }
}

extension Machine.Node: Sendable
where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}

// MARK: - Graph Adjacency

extension Machine.Node {
    /// The structurally adjacent node IDs.
    public var adjacent: [ID] {
        switch self {
        case .leaf, .pure, .hole: return []
        case .map(let child, _): return [child]
        case .tryMap(let child, _): return [child]
        case .flatMap(let child, _): return [child]
        case .sequence(let a, let b, _): return [a, b]
        case .oneOf(let ids): return ids
        case .many(let child, _): return [child]
        case .fold(let child, _, _): return [child]
        case .optional(let child, _, _): return [child]
        case .ref(let id): return [id]
        }
    }

    /// Extract closure for graph algorithms.
    public static var extract: Graph.Adjacency.Extract<Self, Self, [ID]> {
        Graph.Adjacency.Extract { $0.adjacent }
    }
}

### File: Sources/Machine Node Primitives/exports.swift

@_exported public import Graph_Sequential_Primitives
@_exported public import Machine_Combine_Primitives
@_exported public import Machine_Finalize_Primitives
@_exported public import Machine_Next_Primitives
@_exported public import Machine_Transform_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Primitive/Machine.Capture.Mode.Reference.swift

extension Machine.Capture.Mode {
    /// The Sendable capture mode: payloads must be `Sendable` and captures may cross isolation domains.
    public struct Reference: Sendable {
        @usableFromInline
        init() {}
    }
}

### File: Sources/Machine Primitive/Machine.Capture.Mode.Unchecked.swift

extension Machine.Capture.Mode {
    /// Capture mode that admits non-Sendable values into the capture store.
    ///
    /// This is the structural realization of region-based isolation per
    /// [MEM-SEND-013]: combinator factories built atop this mode drop their
    /// Sendable bounds (`<T: Sendable>`, `@Sendable` on stored closures),
    /// and consumers transport assembled programs across actors via
    /// `sending` parameters at the program-transport boundary — not via
    /// per-capture Sendable conformance.
    ///
    /// `Mode.Unchecked` is itself **not** `Sendable`. `Program`s and
    /// `Parser`s parameterized by this mode are non-Sendable; cross-isolation
    /// transport requires `sending` discipline at every transport site,
    /// rather than relying on a structural Sendable conformance on the
    /// assembled value.
    ///
    /// Contrast with `Mode.Reference`, which structurally enforces
    /// Sendable on every captured value and yields Sendable assembled
    /// programs at the cost of a `<T: Sendable>` bound on every combinator.
    public struct Unchecked {
        @usableFromInline
        init() {}
    }
}

### File: Sources/Machine Primitive/Machine.Capture.Mode.swift

extension Machine.Capture {
    /// Namespace for the machine's capture modes (`Reference` and `Unchecked`).
    public enum Mode {}
}

### File: Sources/Machine Primitive/Machine.Capture.swift

extension Machine {
    /// Namespace for the machine's capture vocabulary (slots, stores, IDs, modes).
    public enum Capture {}
}

### File: Sources/Machine Primitive/Machine.swift

/// A namespace for defunctionalized machine-based parsing infrastructure.
///
/// `Machine` provides the core building blocks for representing parsers as data
/// (programs) rather than closures, enabling zero-copy parsing with Swift 6's
/// `~Escapable` types where the lifetime checker rejects closures at abstraction
/// boundaries.
///
/// The Machine infrastructure is generic over:
/// - `Leaf`: The primitive operations (cursor-specific)
/// - `Failure`: The error type for fallible operations
///
/// Cursor-specific packages (Parsing, Binary) provide their own leaf types
/// and inlined interpreters while sharing this common infrastructure.
public enum Machine {}

### File: Sources/Machine Primitives/exports.swift

@_exported public import Graph_Sequential_Primitives
@_exported public import Machine_Capture_Primitives
@_exported public import Machine_Combine_Primitives
@_exported public import Machine_Convenience_Primitives
@_exported public import Machine_Finalize_Primitives
@_exported public import Machine_Frame_Primitives
@_exported public import Machine_Next_Primitives
@_exported public import Machine_Node_Primitives
@_exported public import Machine_Primitive
@_exported public import Machine_Program_Primitives
@_exported public import Machine_Transform_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Program Primitives/Machine.Program.Builder.swift

public import Graph_Sequential_Primitives

extension Machine {
    /// A mutable builder for constructing a `Program`.
    ///
    /// `Builder` accumulates nodes and captures during construction,
    /// then produces an immutable `Program` via `build()`.
    public struct Builder<Leaf, Failure: Swift.Error, Mode>: ~Copyable {
        @usableFromInline
        var storage: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>.Builder

        /// The mutable capture store accumulated alongside the node graph.
        public var captures: Capture.Store<Mode>

        /// Optional maximum machine-stack depth enforced at run time.
        public let maxDepth: Int?

        /// Creates an empty builder, optionally bounding the machine-stack depth.
        @inlinable
        public init(maxDepth: Int? = nil) {
            self.storage = .init()
            self.captures = Capture.Store<Mode>()
            self.maxDepth = maxDepth
        }

        /// The number of nodes allocated so far.
        @inlinable
        public var count: Node<Leaf, Failure, Mode>.ID.Count {
            storage.count
        }

        /// Appends a node to the program graph, returning its ID.
        @inlinable
        public mutating func allocate(_ node: Node<Leaf, Failure, Mode>) -> Node<Leaf, Failure, Mode>.ID {
            storage.allocate(node)
        }

        /// Access/patch a node by ID (for hole patching).
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            get { storage[id] }
            set { storage[id] = newValue }
        }

        /// Consumes the builder, producing the immutable program.
        @inlinable
        public consuming func build() -> Program<Leaf, Failure, Mode> {
            Program(
                graph: storage.build(),
                captures: captures.freeze(),
                maxDepth: maxDepth
            )
        }
    }
}
// Builder is NOT Sendable

### File: Sources/Machine Program Primitives/Machine.Program.swift

// SDG(specializes): Machine.Program is a directed graph with Graph.Sequential storage
public import Graph_Sequential_Primitives

extension Machine {
    /// A program consisting of a graph of nodes.
    ///
    /// `Program` stores the node graph that represents a defunctionalized parser.
    /// Nodes are allocated sequentially and referenced by their IDs. The program
    /// is generic over:
    /// - `Leaf`: The primitive cursor operations
    /// - `Failure`: The error type for fallible operations
    /// - `Mode`: The capture mode (`Mode.Reference` or `Mode.Unchecked`)
    public struct Program<Leaf, Failure: Swift.Error, Mode> {
        /// The sequentially-allocated node graph.
        public let graph: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>

        /// The frozen capture snapshot the interpreter reads at run time.
        public let captures: Machine.Capture.Frozen<Mode>

        /// Optional maximum machine-stack depth enforced at run time.
        public let maxDepth: Int?

        @usableFromInline
        init(
            graph: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>,
            captures: Machine.Capture.Frozen<Mode>,
            maxDepth: Int?
        ) {
            self.graph = graph
            self.captures = captures
            self.maxDepth = maxDepth
        }

        /// Accesses a node by its ID.
        @inlinable
        public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
            graph[id]
        }

        /// Analysis accessor for graph algorithms.
        @inlinable
        public var analyze: Graph.Sequential<Node<Leaf, Failure, Mode>, Node<Leaf, Failure, Mode>>.Analyze<[Node<Leaf, Failure, Mode>.ID]> {
            graph.analyze(using: Node.extract)
        }
    }
}

extension Machine.Program: Sendable where Leaf: Sendable, Mode: Sendable {}

### File: Sources/Machine Program Primitives/exports.swift

@_exported public import Machine_Capture_Primitives
@_exported public import Machine_Node_Primitives

### File: Sources/Machine Transform Primitives/Machine.Transform.Erased.swift

extension Machine.Transform {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased non-throwing transformation from one value to another.
    @safe
    public struct Erased<Mode>: Sendable {
        /// The capture slot holding the underlying typed transform.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _apply:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) -> Machine.Value<Mode>

        /// Applies the transform to the given value using the frozen captures.
        @inlinable
        public func apply(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) -> Machine.Value<Mode> {
            _apply(captures, value)
        }
    }
}

extension Machine.Transform.Erased where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased transform from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (In) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._apply = { captures, value in
            captures.withRaw(raw, as: (@Sendable (In) -> Out).self) { transform in
                value.apply(transform)
            }
        }
    }
}

extension Machine.Transform.Erased where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased transform from a captured typed function (Unchecked mode).
    @inlinable
    public init<In, Out>(
        capture: Machine.Capture.ID<(In) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        self._apply = { captures, value in
            captures.withRaw(raw, as: ((In) -> Out).self) { transform in
                value.apply(transform)
            }
        }
    }
}

### File: Sources/Machine Transform Primitives/Machine.Transform.Throwing.swift

extension Machine.Transform {
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    /// A type-erased throwing transformation from one value to another.
    ///
    /// Generic over `Failure` to support both generic error types (Parsing)
    /// and fixed error types (Binary's `Fault`).
    @safe
    public struct Throwing<Mode, Failure: Swift.Error>: Sendable {
        /// The capture slot holding the underlying typed throwing transform.
        public let capture: Machine.Capture.RawID

        @usableFromInline
        let _apply:
            @Sendable (
                borrowing Machine.Capture.Frozen<Mode>,
                Machine.Value<Mode>
            ) throws(Failure) -> Machine.Value<Mode>

        /// Applies the throwing transform to the given value using the frozen captures.
        @inlinable
        public func apply(
            using captures: borrowing Machine.Capture.Frozen<Mode>,
            _ value: Machine.Value<Mode>
        ) throws(Failure) -> Machine.Value<Mode> {
            try _apply(captures, value)
        }
    }
}

extension Machine.Transform.Throwing where Mode == Machine.Capture.Mode.Reference {
    /// Creates an erased throwing transform from a captured `@Sendable` typed function (Reference mode).
    @inlinable
    public init<In, Out: Sendable>(
        capture: Machine.Capture.ID<@Sendable (In) throws(Failure) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        // [API-ERR-007] Explicit throws(Failure) annotation required for type inference
        // WORKAROUND: Direct slot access instead of withRawThrowing
        // WHY: Compiler crashes (signal 11) with nested typed throws closures
        // WHY: when withRawThrowing's body closure annotates throws(Failure).
        // WHEN TO REMOVE: When the Swift compiler supports nested typed throws
        // WHEN TO REMOVE: in closure contexts without crashing.
        // TRACKING: swift-institute/Research/swift-compiler-bug-catalog.md
        // TRACKING: (nested typed-throws closure crash — candidate entry).
        self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
            let slot = captures.slots[raw.rawValue]
            let transform = slot.read((@Sendable (In) throws(Failure) -> Out).self)
            return try value.apply(transform)
        }
    }
}

extension Machine.Transform.Throwing where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates an erased throwing transform from a captured typed function (Unchecked mode).
    @inlinable
    public init<In, Out>(
        capture: Machine.Capture.ID<(In) throws(Failure) -> Out>
    ) {
        let raw = capture.raw
        self.capture = raw
        // [API-ERR-007] Explicit throws(Failure) annotation required for type inference
        // WORKAROUND: Direct slot access instead of withRawThrowing (see Reference init above)
        // WHY: Compiler crashes (signal 11) with nested typed throws closures
        // WHY: when withRawThrowing's body closure annotates throws(Failure).
        // WHEN TO REMOVE: When the Swift compiler supports nested typed throws
        // WHEN TO REMOVE: in closure contexts without crashing.
        // TRACKING: swift-institute/Research/swift-compiler-bug-catalog.md
        // TRACKING: (nested typed-throws closure crash — candidate entry).
        self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
            let slot = captures.slots[raw.rawValue]
            let transform = slot.read(((In) throws(Failure) -> Out).self)
            return try value.apply(transform)
        }
    }
}

### File: Sources/Machine Transform Primitives/Machine.Transform.swift

extension Machine {
    /// A namespace for type-erased transformation operations.
    public enum Transform {}
}

### File: Sources/Machine Transform Primitives/exports.swift

@_exported public import Machine_Capture_Primitives
@_exported public import Machine_Value_Primitives

### File: Sources/Machine Value Primitives/Machine.Value.Arena.swift

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-machine open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-machine project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Machine.Value {
    /// A simple array-based arena for storing values during machine execution.
    ///
    /// `Arena` provides efficient allocation and deallocation of `Machine.Value`
    /// instances using slot-based handles. Values can be read, released, or
    /// the entire arena can be reset for reuse.
    ///
    /// ## ABA Prevention
    ///
    /// The arena tracks a generation counter that increments on every `reset()`.
    /// Handles include the generation at allocation time. Operations validate
    /// that the handle's generation matches the current arena generation,
    /// preventing use of stale handles after reset.
    public struct Arena: ~Copyable {
        @usableFromInline
        var values: [Machine.Value<Mode>?]

        @usableFromInline
        var nextSlot: UInt32

        /// Current arena generation (incremented on reset).
        @usableFromInline
        var generation: UInt32

        /// Creates an arena with the specified initial capacity.
        @inlinable
        public init(capacity: Int = 64) {
            self.values = [Machine.Value<Mode>?](repeating: nil, count: capacity)
            self.nextSlot = 0
            self.generation = 0
        }
    }
}

extension Machine.Value.Arena {
    /// Allocates a value in the arena and returns a handle to it.
    ///
    /// The returned handle includes the current arena generation for
    /// ABA prevention.
    @inlinable
    public mutating func allocate(_ value: consuming Machine.Value<Mode>) -> Machine.Value<Mode>.Handle {
        let slot = nextSlot
        if Int(slot) >= values.count {
            values.append(contentsOf: repeatElement(nil, count: values.count))
        }
        values[Int(slot)] = value
        nextSlot += 1
        return Machine.Value._makeHandle(slot: slot, generation: generation)
    }

    /// Validates that a handle belongs to the current arena generation.
    @inlinable
    package func validateHandle(_ handle: Machine.Value<Mode>.Handle, operation: StaticString) {
        guard handle.generation == generation else {
            fatalError("Arena.\(operation): stale handle (generation \(handle.generation), current \(generation))")
        }
    }

    /// Reads the value at the given handle without removing it.
    ///
    /// - Parameter handle: A valid handle from this arena.
    /// - Returns: The value at the handle.
    /// - Precondition: The handle must be valid (correct generation, non-empty slot).
    @inlinable
    public func read(_ handle: Machine.Value<Mode>.Handle) -> Machine.Value<Mode> {
        validateHandle(handle, operation: "read")
        let slot = Machine.Value<Mode>._slot(handle)
        guard let value = values[Int(slot)] else {
            fatalError("Arena.read: slot \(slot) is empty")
        }
        return value
    }

    /// Releases and returns the value at the given handle.
    ///
    /// - Parameter handle: A valid handle from this arena.
    /// - Returns: The value that was at the handle.
    /// - Precondition: The handle must be valid (correct generation, non-empty slot).
    @inlinable
    public mutating func release(_ handle: Machine.Value<Mode>.Handle) -> Machine.Value<Mode> {
        validateHandle(handle, operation: "release")
        let slot = Machine.Value<Mode>._slot(handle)
        guard let value = values[Int(slot)] else {
            fatalError("Arena.release: slot \(slot) is empty")
        }
        values[Int(slot)] = nil
        return value
    }

    /// Resets the arena for reuse, clearing all stored values.
    ///
    /// All previously-issued handles become invalid after this call.
    /// The arena generation is incremented to detect stale handle usage.
    @inlinable
    public mutating func reset() {
        for i in 0..<Int(nextSlot) {
            values[i] = nil
        }
        nextSlot = 0
        generation &+= 1  // Increment with wrapping
    }
}

### File: Sources/Machine Value Primitives/Machine.Value.Handle.swift

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-machine open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-machine project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Machine.Value {
    /// A handle to a value stored in an arena.
    ///
    /// `Handle` is a lightweight reference to a slot in a `Machine.Value.Arena`,
    /// enabling efficient value management during machine execution without
    /// copying values between stack frames.
    ///
    /// ## ABA Prevention
    ///
    /// Handles include a generation counter that is validated against the arena.
    /// When an arena is reset, its generation increments, invalidating all
    /// previously-issued handles. Attempts to use a stale handle will be detected.
    public struct Handle: Hashable, Sendable {
        /// The slot index in the arena's storage.
        public let index: Int

        /// The generation counter for ABA prevention.
        public let generation: UInt32

        /// Creates a handle with the given index and generation.
        @inlinable
        public init(index: Int, generation: UInt32) {
            self.index = index
            self.generation = generation
        }
    }
}

// MARK: - Construction Helpers

extension Machine.Value {
    /// Creates a handle from a slot index and generation.
    ///
    /// - Parameters:
    ///   - slot: The slot index.
    ///   - generation: The arena generation at allocation time.
    /// - Returns: A handle suitable for external use.
    @usableFromInline
    static func _makeHandle(slot: UInt32, generation: UInt32) -> Handle {
        Handle(index: Int(slot), generation: generation)
    }

    /// Extracts the slot index from a handle.
    ///
    /// - Parameter handle: The value handle.
    /// - Returns: The slot index.
    @usableFromInline
    static func _slot(_ handle: Handle) -> UInt32 {
        UInt32(handle.index)
    }
}

### File: Sources/Machine Value Primitives/Machine.Value.swift

extension Machine {
    // SAFETY: Encapsulates unsafe internals behind a safe API; see
    // SAFETY: [MEM-SAFE-024] for the absorber-pattern taxonomy.
    /// A type-erased value container for the machine's runtime.
    ///
    /// `Value` stores any type-erased value during machine execution, preserving
    /// the original type information via `ObjectIdentifier` for safe extraction.
    /// Supports both `Copyable` and `~Copyable` payloads.
    ///
    /// ## No Existentials
    ///
    /// This type uses table-based storage to avoid existential types (`AnyObject`,
    /// `Any`, `as?` casts). The internal `_Storage` class holds an opaque pointer
    /// and a `_Table` with type-specialized operations. Access is via `_read`
    /// subscript (borrow) or `~Escapable` `Ref` (lifetime-dependent borrow).
    ///
    /// ## Sendable
    ///
    /// `Value<Mode>` is Sendable when `Mode: Sendable`. For `Mode.Reference`,
    /// values can only be constructed from Sendable payloads via `make<T: Sendable>`,
    /// ensuring the Sendable conformance is structurally sound without `@unchecked`
    /// on `Value` itself.
    ///
    /// ## Construction
    ///
    /// The only public construction paths are:
    /// - `Value<Mode.Reference>.make<T: Sendable & ~Copyable>(_:)` - requires Sendable payload
    /// - `Value<Mode.Unchecked>.make<T: ~Copyable>(_:)` - no Sendable requirement
    @safe
    public struct Value<Mode> {
        @usableFromInline
        let type: ObjectIdentifier

        @usableFromInline
        let storage: _Storage

        // WHY: Category D — structural Sendable workaround (SP-5) per [MEM-SAFE-024].
        // WHY: Immutable `let payload: UnsafeMutableRawPointer` + `let table: _Table`
        // WHY: after construction. UnsafeMutableRawPointer blocks structural inference.
        // WHY: No synchronization, no ~Copyable. Pointee is never mutated.
        // WHY: Encapsulation invariant per [MEM-SAFE-021] — `_Storage` is `@usableFromInline`
        // WHY: but its raw-pointer storage is internal-only; consumers see only the
        // WHY: type-safe `Value` surface.
        // WHEN TO REMOVE: When compiler gains structural Sendable through raw pointers.
        // TRACKING: unsafe-audit-findings.md Category D SP-5.
        /// Reference-counted storage with type-specialized destruction.
        ///
        /// This is NOT `AnyObject`—it's a concrete class type. No `as?` casting
        /// is needed to access the payload.
        @usableFromInline
        final class _Storage: @unchecked Sendable {
            @usableFromInline
            let payload: UnsafeMutableRawPointer

            @usableFromInline
            let table: _Table

            @usableFromInline
            init(payload: UnsafeMutableRawPointer, table: _Table) {
                unsafe (self.payload = payload)
                self.table = table
            }

            deinit {
                unsafe table.destroy(payload)
            }
        }

        // SAFETY: `_Table` stores a single immutable `@Sendable` closure
        // SAFETY: specialised at construction time for `T: ~Copyable`. The
        // SAFETY: closure captures only type metadata (T's layout), not
        // SAFETY: runtime values; the `Sendable` conformance is structural.
        // SAFETY: Encapsulation invariant per [MEM-SAFE-021] — internal table
        // SAFETY: type used only as `_Storage`'s table field.
        /// Table of type-specialized operations.
        ///
        /// The `destroy` function captures only type metadata (`T`'s layout),
        /// not user-provided runtime values. This is acceptable for Embedded
        /// compatibility as it's equivalent to generic specialization—no closure
        /// context with user data, only compiler-generated type information.
        @usableFromInline
        struct _Table: Sendable {
            /// Destroys and deallocates the payload.
            ///
            /// Specialized for `T` at construction time.
            @usableFromInline
            let destroy: @Sendable (UnsafeMutableRawPointer) -> Void

            @usableFromInline
            init<T: ~Copyable>(_: T.Type) {
                unsafe (self.destroy = { raw in
                    unsafe raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                    unsafe raw.deallocate()
                })
            }
        }

        @usableFromInline
        init(type: ObjectIdentifier, storage: _Storage) {
            self.type = type
            self.storage = storage
        }

        /// Single choke-point for payload projection.
        ///
        /// All `assumingMemoryBound` calls go through here, making the
        /// unsafe binding structurally tied to the stored type id.
        ///
        /// - Precondition: `T` must match the type used at construction.
        @usableFromInline
        func _project<T: ~Copyable>(_: T.Type) -> UnsafePointer<T> {
            unsafe UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
        }

        // MARK: - Borrow Access

        /// Borrow access to the stored value via `_read`.
        ///
        /// Yields a borrow of the payload scoped to the accessor call.
        /// Supports `~Copyable` payloads — no copy is made.
        ///
        ///     V._render(value[as: V.self], context: &ctx)
        ///
        /// - Precondition: `T` must match the type used at construction.
        @inlinable
        public subscript<T: ~Copyable>(as type: T.Type) -> T {
            _read {
                precondition(
                    self.type == ObjectIdentifier(T.self),
                    "Machine.Value type mismatch: expected \(T.self), got type with id \(self.type)"
                )
                yield unsafe _project(type).pointee
            }
        }

        // MARK: - ~Escapable Ref

        // SAFETY: Encapsulates unsafe internals behind a safe API; see
        // SAFETY: [MEM-SAFE-024] for the absorber-pattern taxonomy.
        /// A `~Escapable` reference to a stored value.
        ///
        /// Carries a lifetime dependency back to the `Value`, ensuring the
        /// reference cannot outlive its storage. Access the payload via
        /// the `value` property (`_read` accessor).
        @safe
        public struct Ref<T: ~Copyable>: ~Copyable, ~Escapable {
            @usableFromInline
            let _pointer: UnsafePointer<T>

            @usableFromInline
            init(_pointer: UnsafePointer<T>) {
                unsafe (self._pointer = _pointer)
            }

            /// Borrow access to the referenced value.
            public var value: T {
                _read { yield unsafe _pointer.pointee }
            }
        }

        /// Returns a `~Escapable` reference to the stored value.
        ///
        /// The returned `Ref` carries a lifetime dependency on `self`.
        /// No closure needed — use `ref.value` to borrow.
        ///
        /// Uses `_overrideLifetime` (the "returning model") to bridge
        /// from the raw pointer to the lifetime system.
        ///
        /// - Precondition: `T` must match the type used at construction.
        @_lifetime(borrow self)
        public func borrow<T: ~Copyable>(as type: T.Type) -> Ref<T> {
            precondition(
                self.type == ObjectIdentifier(T.self),
                "Machine.Value type mismatch: expected \(T.self), got type with id \(self.type)"
            )
            let ref = unsafe Ref(_pointer: _project(type))
            return unsafe _overrideLifetime(ref, borrowing: self)
        }
    }
}

// MARK: - Reference Mode Value Operations

// swift-format-ignore
// AmbiguousTrailingClosureOverload false-positive: the two `apply` overloads
// below are the standard throwing/non-throwing pair (the stdlib `map` shape) —
// overload resolution picks by the closure's throwing-ness, and `rethrows`-style
// unification is unavailable because the throwing overload's typed `throws(E)`
// must propagate to the return-effect signature.
extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    /// Applies a typed function to this erased value, producing a new erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out: Sendable>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(self[as: In.self]))
    }

    /// Applies a typed throwing function to this erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out: Sendable, E: Swift.Error>(
        _ transform: (In) throws(E) -> Out
    ) throws(E) -> Machine.Value<Mode> {
        .make(try transform(self[as: In.self]))
    }

    /// Combines this value with another using a typed binary function.
    ///
    /// - Precondition: `self` was created from type `A`, `other` from type `B`.
    public func combine<A, B, Out: Sendable>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(self[as: A.self], other[as: B.self]))
    }
}

// MARK: - Unchecked Mode Value Operations

// swift-format-ignore
// AmbiguousTrailingClosureOverload false-positive: the standard
// throwing/non-throwing `apply` overload pair (see the Reference-mode note above).
extension Machine.Value where Mode == Machine.Capture.Mode.Unchecked {
    /// Applies a typed function to this erased value, producing a new erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(self[as: In.self]))
    }

    /// Applies a typed throwing function to this erased value.
    ///
    /// - Precondition: `self` was created from a value of type `In`.
    public func apply<In, Out, E: Swift.Error>(
        _ transform: (In) throws(E) -> Out
    ) throws(E) -> Machine.Value<Mode> {
        .make(try transform(self[as: In.self]))
    }

    /// Combines this value with another using a typed binary function.
    ///
    /// - Precondition: `self` was created from type `A`, `other` from type `B`.
    public func combine<A, B, Out>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(self[as: A.self], other[as: B.self]))
    }
}

// MARK: - Reference Mode Construction

extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    /// Creates a type-erased value from a concrete Sendable value.
    ///
    /// This is the only construction path for `Value<Mode.Reference>`.
    /// The Sendable constraint ensures all values in Reference mode are safe
    /// to share across isolation domains.
    @inlinable
    public static func make<T: Sendable & ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        unsafe payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = unsafe _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Machine.Value<Mode>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}

// MARK: - Unchecked Mode Construction

extension Machine.Value where Mode == Machine.Capture.Mode.Unchecked {
    /// Creates a type-erased value from a concrete value.
    ///
    /// This is the only construction path for `Value<Mode.Unchecked>`.
    /// No Sendable constraint—use this mode when Sendable is not required.
    @inlinable
    public static func make<T: ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        unsafe payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = unsafe _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Machine.Value<Mode>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}

// MARK: - Sendable Conformance

extension Machine.Value: Sendable where Mode: Sendable {}

### File: Sources/Machine Value Primitives/exports.swift

@_exported public import Machine_Primitive
