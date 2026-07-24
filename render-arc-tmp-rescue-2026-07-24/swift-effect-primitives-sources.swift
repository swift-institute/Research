# swift-effect-primitives

## Package Manifest

// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-effect-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Effect Primitives",
            targets: ["Effect Primitives"]
        ),
        .library(
            name: "Effect Primitives Test Support",
            targets: ["Effect Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-dependency-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-equation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Effect Primitives",
            dependencies: [
                .product(name: "Dependency Primitives", package: "swift-dependency-primitives"),
                .product(name: "Equation Primitives", package: "swift-equation-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
            ]
        ),
        .target(
            name: "Effect Primitives Test Support",
            dependencies: [
                "Effect Primitives",
                .product(name: "Hash Primitives Test Support", package: "swift-hash-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Effect Primitives Tests",
            dependencies: [
                "Effect Primitives",
                "Effect Primitives Test Support",
            ]
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

~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Context.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Continuation.Multi.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Continuation.One.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Continuation.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Handler.Sync.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Handler.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Outcome.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Protocol.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.perform.swift
~/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.swift

## Source Files

### File: Sources/Effect Primitives/Effect.Context.swift

public import Dependency_Primitives

extension Effect {
    /// Task-local context for effect handler registration.
    ///
    /// `Effect.Context` provides scoped handler registration via Task-local storage.
    /// This is a thin wrapper around ``Dependency/Scope`` that provides
    /// effect-specific terminology.
    ///
    /// Use ``with(_:operation:)-5q3q7`` to register handlers for a scope:
    ///
    /// ```swift
    /// try await Effect.Context.with { handlers in
    ///     handlers[ConsoleHandler.self] = .live
    /// } operation: {
    ///     // ConsoleHandler.self resolves to .live here
    ///     Console.print("Hello")
    /// }
    /// ```
    ///
    /// ## Nested Scopes
    ///
    /// Handlers can be overridden in nested scopes:
    ///
    /// ```swift
    /// Effect.Context.with { handlers in
    ///     handlers[Logger.self] = .file
    /// } operation: {
    ///     // Logger is .file here
    ///     Effect.Context.with { handlers in
    ///         handlers[Logger.self] = .console
    ///     } operation: {
    ///         // Logger is .console here
    ///     }
    ///     // Logger is .file here again
    /// }
    /// ```
    ///
    /// ## Accessing Handlers
    ///
    /// Within a scope, access the current handlers:
    ///
    /// ```swift
    /// let console = Effect.Context.current[ConsoleHandler.self]
    /// ```
    public struct Context: Sendable {
        private init() {}
    }
}

// MARK: - Type Aliases

extension Effect.Context {
    /// Protocol for context keys.
    ///
    /// Use `Effect.Context.Key` to refer to this type.
    /// This is an alias for ``Dependency/Key``.
    ///
    /// ```swift
    /// struct ConsoleHandler: Effect.Context.Key {
    ///     typealias Value = ConsoleHandlerImpl
    ///     static var liveValue: Value { .live }
    ///     static var testValue: Value { .mock }
    /// }
    /// ```
    public typealias Key = Dependency.Key

    /// Storage for registered handlers.
    ///
    /// This is an alias for ``Dependency/Values``.
    public typealias Handlers = Dependency.Values
}

// MARK: - Current Access

extension Effect.Context {
    /// The current handlers for this task.
    ///
    /// Returns the handlers from the innermost ``with(_:operation:)-5q3q7`` scope,
    /// or the default handlers if not in a scope.
    public static var current: Handlers {
        Dependency.Scope.current
    }
}

// MARK: - Scoped Registration (Synchronous)

extension Effect.Context {
    /// Executes a closure with modified handlers.
    ///
    /// This is the primary way to establish effect handling scope.
    /// Handlers registered here are visible to all code executed within
    /// the operation closure.
    ///
    /// - Parameters:
    ///   - modify: A closure that modifies the handlers for the scope.
    ///   - operation: The operation to execute with the modified handlers.
    /// - Returns: The result of the operation.
    /// - Throws: The typed error from the operation.
    public static func with<T, E: Swift.Error>(
        _ modify: (inout Handlers) -> Void,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try Dependency.Scope.with(modify, operation: operation)
    }

    /// Executes a closure with modified handlers (non-throwing).
    ///
    /// - Parameters:
    ///   - modify: A closure that modifies the handlers for the scope.
    ///   - operation: The operation to execute with the modified handlers.
    /// - Returns: The result of the operation.
    public static func with<T>(
        _ modify: (inout Handlers) -> Void,
        operation: () -> T
    ) -> T {
        Dependency.Scope.with(modify, operation: operation)
    }
}

// MARK: - Scoped Registration (Asynchronous)

extension Effect.Context {
    /// Executes an async closure with modified handlers.
    ///
    /// This is the primary way to establish async effect handling scope.
    /// Handlers registered here are visible to all code executed within
    /// the operation closure, including across await points.
    ///
    /// - Parameters:
    ///   - modify: A closure that modifies the handlers for the scope.
    ///   - operation: The async operation to execute with the modified handlers.
    /// - Returns: The result of the operation.
    /// - Throws: The typed error from the operation.
    nonisolated(nonsending)
        public static func with<T, E: Swift.Error>(
            _ modify: (inout Handlers) -> Void,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        try await Dependency.Scope.with(modify, operation: operation)
    }

    /// Executes an async closure with modified handlers (non-throwing).
    ///
    /// - Parameters:
    ///   - modify: A closure that modifies the handlers for the scope.
    ///   - operation: The async operation to execute with the modified handlers.
    /// - Returns: The result of the operation.
    nonisolated(nonsending)
        public static func with<T>(
            _ modify: (inout Handlers) -> Void,
            operation: nonisolated(nonsending) () async -> T
        ) async -> T
    {
        await Dependency.Scope.with(modify, operation: operation)
    }
}

### File: Sources/Effect Primitives/Effect.Continuation.Multi.swift

extension Effect.Continuation {
    /// A multi-shot continuation that can be resumed multiple times.
    ///
    /// Multi-shot continuations enable patterns like:
    /// - Backtracking search
    /// - Probabilistic programming
    /// - Non-deterministic computation
    /// - Coroutines that can be forked
    ///
    /// Each resumption creates a new branch of computation.
    /// The continuation can be copied to enable multiple resumptions.
    ///
    /// ```swift
    /// func handle(_ continuation: Multi<Int, Never>) async {
    ///     // Resume with multiple values - each creates a branch
    ///     for i in 0..<3 {
    ///         await continuation.resume(returning: i)
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// Multi-shot continuations require copying the entire call stack,
    /// making them significantly slower than one-shot continuations.
    /// Use ``One`` when possible.
    ///
    /// ## Use Cases
    ///
    /// - **Backtracking**: Try multiple paths, backtrack on failure
    /// - **Probabilistic**: Sample from distributions, fork execution
    /// - **Generators**: Yield multiple values from a single call
    /// - **Coroutines**: Fork and join concurrent branches
    public struct Multi<Value, Failure: Swift.Error>: __EffectContinuation, Sendable {
        @usableFromInline
        internal let _resume: @Sendable (sending Result<Value, Failure>) async -> Void

        /// Creates a multi-shot continuation with the given resume closure.
        ///
        /// - Parameter resume: The closure to invoke when resuming.
        @usableFromInline
        internal init(_ resume: @escaping @Sendable (sending Result<Value, Failure>) async -> Void) {
            self._resume = resume
        }

        /// Resume the continuation with a successful value.
        ///
        /// This can be called multiple times to create multiple branches.
        ///
        /// - Parameter value: The value to resume with.
        @inlinable
        public func resume(returning value: sending Value) async {
            await _resume(.success(value))
        }

        /// Resume the continuation with an error.
        ///
        /// This can be called multiple times to create multiple branches.
        ///
        /// - Parameter error: The error to resume with.
        @inlinable
        public func resume(throwing error: Failure) async {
            await _resume(.failure(error))
        }

        /// Resume the continuation with a result.
        ///
        /// This can be called multiple times to create multiple branches.
        ///
        /// - Parameter result: The result to resume with.
        @inlinable
        public func resume(with result: sending Result<Value, Failure>) async {
            await _resume(result)
        }
    }
}

extension Effect.Continuation.Multi where Value == Void {
    /// Resume the continuation with void.
    ///
    /// Convenience method for effects that return `Void`.
    @inlinable
    public func resume() async {
        await _resume(.success(()))
    }
}

extension Effect.Continuation.Multi where Failure == Never {
    /// Resume the continuation with a successful value.
    ///
    /// This overload is provided for infallible continuations where
    /// the error type is `Never`.
    ///
    /// - Parameter value: The value to resume with.
    @inlinable
    public func resume(returning value: sending Value) async {
        await _resume(.success(value))
    }
}

extension Effect.Continuation.Multi where Value == Void, Failure == Never {
    /// Resume the continuation with void.
    ///
    /// Convenience method for infallible effects that return `Void`.
    @inlinable
    public func resume() async {
        await _resume(.success(()))
    }
}

### File: Sources/Effect Primitives/Effect.Continuation.One.swift

extension Effect.Continuation {
    /// A one-shot continuation that MUST be consumed exactly once.
    ///
    /// This continuation uses `~Copyable` to enforce linear usage.
    /// The compiler ensures you cannot accidentally resume twice
    /// or forget to resume.
    ///
    /// ```swift
    /// func handle(_ continuation: consuming One<String, Never>) async {
    ///     await continuation.resume(returning: "Hello")  // Consumes
    ///     // continuation.resume(returning: "World")  // Error: already consumed
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// One-shot continuations are more efficient than multi-shot because:
    /// - No stack copying required
    /// - No reference counting overhead
    /// - No runtime checks for double-resume
    ///
    /// ## Safety
    ///
    /// The `~Copyable` constraint provides compile-time guarantees:
    /// - Cannot be resumed twice (would require copying)
    /// - Cannot be accidentally forgotten (ownership tracking)
    /// - Cannot be stored without consuming
    ///
    /// ## Noncopyable Value
    ///
    /// `Value` admits `~Copyable` types so handlers can resume with linear
    /// resources. `Value` carries no `Sendable` bound: cross-isolation
    /// transport rides the `consuming sending Value` callback parameters
    /// (region-based isolation), so a non-Sendable `Value` resumes safely
    /// without constraining every consumer — per [MEM-SEND-012]. The value
    /// and error paths are stored as two independent
    /// callbacks (`onValue`, `onError`) rather than a single closure over
    /// stdlib `Result` — `Result<Value, Failure>` requires `Value: Copyable`,
    /// and encoding the delivery as a `throws(E) -> sending Value` thunk
    /// that captures a `~Copyable` `Value` runs into task-allocator
    /// ordering issues under `@Sendable` capture. The two-callback form is
    /// the smallest structural change that supports both paths.
    ///
    /// ## Revisit Trigger
    ///
    /// Two-callback storage and the `@Sendable` retention on `_onValue` /
    /// `_onError` are interim, pending a Swift-compiler fix for the
    /// task-allocator / `Optional<~Copyable>` / `@Sendable` capture
    /// interaction that crashes under the thunk form.
    /// Reproducer: `swift-institute/Experiments/silgen-thunk-noncopyable-sending-capture/`.
    /// Revisit thunk form (`() throws(Failure) -> sending Value`) and
    /// `@Sendable` removal ([IMPL-092], research §4.1) when the crash is
    /// resolved upstream.
    public struct One<Value: ~Copyable, Failure: Swift.Error>: ~Copyable, Sendable {
        @usableFromInline
        internal let _onValue: @Sendable (consuming sending Value) async -> Void

        @usableFromInline
        internal let _onError: @Sendable (Failure) async -> Void

        /// Creates a one-shot continuation from value and error callbacks.
        ///
        /// Handlers invoke exactly one of the two callbacks via `resume(returning:)`
        /// or `resume(throwing:)`.
        ///
        /// - Parameters:
        ///   - onValue: Invoked when the handler resumes with a value.
        ///   - onError: Invoked when the handler resumes with an error.
        @usableFromInline
        internal init(
            onValue: @escaping @Sendable (consuming sending Value) async -> Void,
            onError: @escaping @Sendable (Failure) async -> Void
        ) {
            self._onValue = onValue
            self._onError = onError
        }

        /// Resume the continuation with a successful value.
        ///
        /// This consumes the continuation, ensuring it cannot be used again.
        ///
        /// - Parameter value: The value to resume with.
        @inlinable
        public consuming func resume(returning value: consuming sending Value) async {
            await _onValue(value)
        }

        /// Resume the continuation with an error.
        ///
        /// This consumes the continuation, ensuring it cannot be used again.
        ///
        /// - Parameter error: The error to resume with.
        @inlinable
        public consuming func resume(throwing error: Failure) async {
            await _onError(error)
        }
    }
}

// MARK: - Copyable Value Conveniences

extension Effect.Continuation.One where Value: Copyable {
    /// Resume the continuation with a result.
    ///
    /// Available when `Value` is `Copyable` because stdlib's
    /// `Result<Value, Failure>` requires a copyable value.
    ///
    /// - Parameter result: The result to resume with.
    @inlinable
    public consuming func resume(with result: sending Result<Value, Failure>) async {
        switch result {
        case .success(let value): await _onValue(value)
        case .failure(let error): await _onError(error)
        }
    }

    /// Wraps this continuation with an intercepting callback.
    ///
    /// The callback is invoked with the result before the original resume.
    /// Returns a new one-shot continuation that must be consumed exactly once.
    ///
    /// Use this to observe or record the result without breaking one-shot semantics.
    ///
    /// - Note: Available when `Value: Copyable` — observation requires that
    ///   the value be inspectable twice (once by the callback, once by the
    ///   original resume). A `~Copyable` value cannot be shared across two
    ///   sinks.
    ///
    /// ```swift
    /// func handle(continuation: consuming One<Int, Never>) async {
    ///     let wrapped = continuation.onResume { result in
    ///         print("Intercepted: \(result)")
    ///     }
    ///     await inner.handle(continuation: wrapped)
    /// }
    /// ```
    @inlinable
    public consuming func onResume(
        _ callback: @escaping @Sendable (sending Result<Value, Failure>) async -> Void
    ) -> Effect.Continuation.One<Value, Failure> where Value: Sendable {
        let onValue = _onValue
        let onError = _onError
        return Effect.Continuation.One(
            onValue: { value in
                await callback(.success(value))
                await onValue(value)
            },
            onError: { error in
                await callback(.failure(error))
                await onError(error)
            }
        )
    }
}

extension Effect.Continuation.One where Value == Void {
    /// Resume the continuation with void.
    ///
    /// Convenience method for effects that return `Void`.
    @inlinable
    public consuming func resume() async {
        await _onValue(())
    }
}

extension Effect.Continuation.One where Value: Copyable, Failure == Never {
    /// Resume the continuation with a successful value.
    ///
    /// This overload is provided for infallible continuations where
    /// the error type is `Never`.
    ///
    /// - Parameter value: The value to resume with.
    @inlinable
    public consuming func resume(returning value: sending Value) async {
        await _onValue(value)
    }
}

extension Effect.Continuation.One where Value == Void, Failure == Never {
    /// Resume the continuation with void.
    ///
    /// Convenience method for infallible effects that return `Void`.
    @inlinable
    public consuming func resume() async {
        await _onValue(())
    }
}

### File: Sources/Effect Primitives/Effect.Continuation.swift

/// Protocol for continuation types that can resume suspended computations.
///
/// Continuations represent "the rest of the computation" after an
/// effect is performed. Handlers receive a continuation and can:
/// - Resume with a value (success)
/// - Resume with an error (failure)
/// - Never resume (abort)
/// - Resume multiple times (multi-shot, requires copying)
///
/// ## One-Shot vs Multi-Shot
///
/// One-shot continuations can be resumed at most once. They are
/// more efficient because the stack doesn't need to be copied.
/// Multi-shot continuations can be resumed multiple times, enabling
/// patterns like backtracking or probabilistic programming.
///
/// The `~Copyable` constraint on ``Effect.Continuation.One`` enforces one-shot semantics
/// at compile time, preventing double-resume bugs.
///
/// ## Noncopyable Value Support
///
/// The `Value` associated type admits `~Copyable` types so a handler may
/// resume with a linear resource. `resume(with:)` (which takes a stdlib
/// `Result`) is provided as an extension where `Value: Copyable`; it is
/// intentionally absent from the protocol requirement because stdlib's
/// `Result<Value, Failure>` requires `Value: Copyable`.
///
/// ## See Also
///
/// - ``Effect.Continuation.One``: One-shot continuation (move-only, enforced)
/// - ``Effect.Continuation.Multi``: Multi-shot continuation (copyable)
///
/// - Note: This protocol is hoisted to module level due to Swift limitations.
///   Use `Effect.Continuation.Protocol` to refer to this type.
public protocol __EffectContinuation<Value, Failure>: ~Copyable {
    /// The success value type this continuation accepts.
    associatedtype Value: ~Copyable

    /// The error type this continuation accepts.
    associatedtype Failure: Swift.Error

    /// Resume the continuation with a successful value.
    ///
    /// - Parameter value: The value to resume with.
    consuming func resume(returning value: consuming sending Value) async

    /// Resume the continuation with an error.
    ///
    /// - Parameter error: The error to resume with.
    consuming func resume(throwing error: Failure) async
}

extension Effect {
    /// Namespace for continuation types.
    public enum Continuation {
        /// Protocol for continuation types.
        ///
        /// Use `Effect.Continuation.Protocol` to refer to this type.
        public typealias `Protocol` = __EffectContinuation
    }
}

### File: Sources/Effect Primitives/Effect.Handler.Sync.swift

extension Effect.Handler {
    /// Protocol for handlers that can operate synchronously.
    ///
    /// Synchronous handlers don't require `async` context in their
    /// implementation, though they still use the async continuation
    /// interface for consistency.
    ///
    /// ## When to Use
    ///
    /// Use synchronous handlers when:
    /// - The effect can be handled immediately without async work
    /// - You need deterministic, predictable behavior for testing
    /// - Performance is critical and async overhead matters
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct PureRandomHandler: Effect.Handler.Sync {
    ///     typealias Handled = RandomInt
    ///
    ///     let seed: UInt64
    ///
    ///     func handle(
    ///         _ effect: RandomInt,
    ///         continuation: consuming Effect.Continuation.One<Int, Never>
    ///     ) async {
    ///         // Pure deterministic "random" for testing
    ///         let value = Int(seed % UInt64(effect.range.count))
    ///         await continuation.resume(returning: effect.range.lowerBound + value)
    ///     }
    /// }
    /// ```
    public typealias Sync = __EffectHandler
}

### File: Sources/Effect Primitives/Effect.Handler.swift

/// Protocol for types that can handle (interpret) effects.
///
/// A handler wraps an operation and intercepts effects performed
/// within it. When an effect is performed:
/// 1. The current continuation is captured
/// 2. Control transfers to the handler
/// 3. The handler can resume, transform, or abort
///
/// Handlers compose via nesting (inner handlers run first):
///
/// ```swift
/// try await Effect.Context.with { handlers in
///     handlers[OuterHandler.self] = outer
/// } operation: {
///     try await Effect.Context.with { handlers in
///         handlers[InnerHandler.self] = inner
///     } operation: {
///         perform(someEffect)  // innerHandler handles first
///     }
/// }
/// ```
///
/// ## Handler Semantics
///
/// Handlers receive ownership of a one-shot continuation and must
/// decide what to do:
///
/// - **Resume normally**: Call `continuation.resume(returning:)`
/// - **Resume with error**: Call `continuation.resume(throwing:)`
/// - **Abort**: Don't resume (continuation is dropped)
/// - **Defer**: Store continuation for later resumption
///
/// ## Type Safety
///
/// Handlers are parameterized by the effect type they handle,
/// ensuring type-safe interpretation of effect arguments and results.
///
/// ## Noncopyable Support
///
/// The handler itself admits `~Copyable` conformers: a handler may own
/// linear state (a descriptor, a connection, a pool token). The handled
/// effect also admits `~Copyable` types — the `handle` requirement takes
/// the effect by `borrowing`, allowing the handler to observe a linear
/// effect instance without consuming it.
///
/// - Note: This protocol is hoisted to module level due to Swift limitations.
///   Use `Effect.Handler.Protocol` to refer to this type.
public protocol __EffectHandler: ~Copyable {
    /// The effect type this handler interprets.
    associatedtype Handled: ~Copyable & __EffectProtocol

    /// Handle an effect, resuming the continuation.
    ///
    /// - Parameters:
    ///   - effect: The effect being performed
    ///   - continuation: The continuation to resume (consumed)
    func handle(
        _ effect: borrowing Handled,
        continuation: consuming Effect.Continuation.One<Handled.Value, Handled.Failure>
    ) async
}

extension Effect {
    /// Namespace for handler-related types.
    public enum Handler {
        /// Protocol for types that can handle (interpret) effects.
        ///
        /// Use `Effect.Handler.Protocol` to refer to this type.
        public typealias `Protocol` = __EffectHandler
    }
}

### File: Sources/Effect Primitives/Effect.Outcome.swift

public import Equation_Primitives
public import Hash_Primitives

extension Effect {
    /// The outcome of handling an effect.
    ///
    /// When an effect is performed and handled, the outcome captures
    /// what the handler decided to do with the continuation.
    ///
    /// ## Cases
    ///
    /// - `resumed`: The handler resumed with a value
    /// - `threw`: The handler resumed with an error
    /// - `aborted`: The handler did not resume (computation halted)
    ///
    /// ## Usage
    ///
    /// Outcomes are useful for:
    /// - Inspecting how an effect was handled in tests
    /// - Building effect interpreters that collect results
    /// - Debugging effect handling behavior
    ///
    /// ```swift
    /// let outcome: Effect.Outcome<String, MyError> = ...
    /// switch outcome {
    /// case .resumed(let value):
    ///     print("Got value: \(value)")
    /// case .threw(let error):
    ///     print("Got error: \(error)")
    /// case .aborted:
    ///     print("Handler did not resume")
    /// }
    /// ```
    ///
    /// ## Noncopyable Value
    ///
    /// `Value` admits `~Copyable` types so an outcome may carry a linear
    /// resource. `Outcome` becomes `~Copyable` when `Value` is, gaining
    /// conditional `Copyable` and `Sendable` conformances. Equality and
    /// hashing for `~Copyable` `Value` go through the ecosystem's
    /// `Equation.Protocol` and `Hash.Protocol`; the stdlib's
    /// `Swift.Equatable`/`Swift.Hashable` conformances are available
    /// whenever `Value` is `Copyable`.
    public enum Outcome<Value: ~Copyable, Failure: Swift.Error>: ~Copyable {
        /// The effect was handled and computation resumed with a value.
        case resumed(Value)

        /// The effect was handled and computation resumed with an error.
        case threw(Failure)

        /// The effect was handled but computation was aborted (not resumed).
        case aborted
    }
}

// MARK: - Conditional Conformances

extension Effect.Outcome: Copyable where Value: Copyable {}
extension Effect.Outcome: Sendable where Value: Sendable & ~Copyable, Failure: Sendable {}

// Copyable Value: stdlib Equatable/Hashable (backward compatible).
// Under Swift 6.4+, `Equation.\`Protocol\`` is a typealias to
// `Swift.Equatable` (and `Hash.\`Protocol\`` to `Swift.Hashable`)
// per SE-0499, so the conformances below would collide with the
// explicit ones further down. Guard them to Swift <6.4 only.
#if swift(<6.4)
    extension Effect.Outcome: Equatable where Value: Equatable, Failure: Equatable {}
    extension Effect.Outcome: Hashable where Value: Hashable, Failure: Hashable {}
#endif

// ~Copyable-compatible equality and hashing via the ecosystem primitives.
extension Effect.Outcome: Equation.`Protocol`
where Value: Equation.`Protocol` & ~Copyable, Failure: Equation.`Protocol` {
    /// Compares two outcomes for equality via their payloads' `Equation.Protocol` conformance.
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        switch lhs {
        case .resumed(let lv):
            switch rhs {
            case .resumed(let rv): return lv == rv
            case .threw: return false
            case .aborted: return false
            }

        case .threw(let le):
            switch rhs {
            case .resumed: return false
            case .threw(let re): return le == re
            case .aborted: return false
            }

        case .aborted:
            switch rhs {
            case .resumed: return false
            case .threw: return false
            case .aborted: return true
            }
        }
    }
}

extension Effect.Outcome: Hash.`Protocol`
where Value: Hash.`Protocol` & ~Copyable, Failure: Hash.`Protocol` {
    /// Feeds this outcome's discriminant and payload into `hasher`.
    public borrowing func hash(into hasher: inout Hasher) {
        switch self {
        case .resumed(let value):
            hasher.combine(0)
            value.hash(into: &hasher)

        case .threw(let error):
            hasher.combine(1)
            error.hash(into: &hasher)

        case .aborted:
            hasher.combine(2)
        }
    }
}

// Swift 6.4+: `Hash.Protocol` REFINES `Swift.Hashable`; a conditional conformance to it
// does not synthesize the inherited `Swift.Hashable`, so declare it explicitly (the
// `hash(into:)` witness above satisfies it). `Equatable` comes from the sibling
// `Equation.Protocol` conformance. Ref: Research/se-0499-…md Addendum (2026-06-01).
#if swift(>=6.4)
    extension Effect.Outcome: Swift.Hashable
    where Value: Hash.`Protocol` & ~Copyable, Failure: Hash.`Protocol` {}
#endif

// MARK: - Result Conversion

extension Effect.Outcome where Value: Copyable {
    /// Creates an outcome from a result.
    ///
    /// - Parameter result: The result to convert.
    public init(_ result: Result<Value, Failure>) {
        switch result {
        case .success(let value):
            self = .resumed(value)

        case .failure(let error):
            self = .threw(error)
        }
    }

    /// Converts this outcome to a result, if possible.
    ///
    /// Returns `nil` if the outcome is `.aborted`.
    public var result: Result<Value, Failure>? {
        switch self {
        case .resumed(let value):
            return .success(value)

        case .threw(let error):
            return .failure(error)

        case .aborted:
            return nil
        }
    }
}

// MARK: - Value Access

extension Effect.Outcome where Value: Copyable {
    /// The resumed value, if any.
    public var value: Value? {
        if case .resumed(let value) = self {
            return value
        }
        return nil
    }

    /// The thrown error, if any.
    public var error: Failure? {
        if case .threw(let error) = self {
            return error
        }
        return nil
    }
}

extension Effect.Outcome where Value: ~Copyable {
    /// Whether the outcome is an abort.
    public var isAborted: Bool {
        switch self {
        case .aborted: return true
        case .resumed: return false
        case .threw: return false
        }
    }
}

### File: Sources/Effect Primitives/Effect.Protocol.swift

/// Marker protocol for types representing effect operations.
///
/// An effect operation is a request to perform some action that
/// the current computation cannot handle directly. Effects are:
/// - **Declared** by conforming to this protocol
/// - **Performed** by yielding to a handler
/// - **Handled** by providing an implementation with access to the continuation
///
/// ## Conformance Requirements
///
/// Conforming types declare their argument and result types:
///
/// ```swift
/// struct ReadLine: Effect.Protocol {
///     typealias Arguments = Void
///     typealias Value = String
///     typealias Failure = Never
/// }
///
/// struct Fetch: Effect.Protocol {
///     typealias Arguments = URL
///     typealias Value = Data
///     typealias Failure = NetworkError
///
///     let url: URL
///     var arguments: URL { url }
/// }
/// ```
///
/// ## Design Rationale
///
/// Effects carry their arguments as instance data rather than method
/// parameters. This enables type-level dispatch and cleaner composition.
///
/// ## Noncopyable Support
///
/// `Arguments` and `Value` admit `~Copyable` types: an effect may carry
/// linear resources (owning file descriptors, unique tokens) as arguments
/// or deliver them as results. `arguments` is exposed through a
/// `borrowing get` so a `~Copyable` Arguments value can be observed
/// without being consumed.
///
/// - Note: This protocol is hoisted to module level due to Swift limitations.
///   Use `Effect.Protocol` to refer to this type.
public protocol __EffectProtocol: ~Copyable {
    /// The arguments provided when performing this effect.
    associatedtype Arguments: ~Copyable = Void

    /// The success value type returned when the effect is handled.
    associatedtype Value: ~Copyable

    /// The error type that handling may produce.
    associatedtype Failure: Swift.Error = Never

    /// The arguments for this effect instance.
    var arguments: Arguments { borrowing get }
}

extension __EffectProtocol where Self: ~Copyable, Arguments == Void {
    /// Default implementation providing `()` for effects with no arguments.
    public var arguments: Void { () }
}

### File: Sources/Effect Primitives/Effect.perform.swift

// Note: The actual perform implementation requires integration with a runtime layer
// that provides the suspension/resumption coordination. This file defines the shape
// and documents the intended semantics. The swift-effects package builds on these
// primitives to provide the full implementation.

extension Effect {
    /// Marker type for perform operations.
    ///
    /// The actual `perform` functions are defined as extensions on `Effect`
    /// in the runtime layer (swift-effects), which provides:
    /// - Handler dispatch via `Effect.Context`
    /// - Continuation capture and management
    /// - Integration with Swift's async/await
    ///
    /// ## Expected Signature
    ///
    /// The runtime layer provides:
    ///
    /// ```swift
    /// extension Effect {
    ///     static func perform<E: Effect.Protocol>(
    ///         _ effect: E
    ///     ) async throws(E.Failure) -> E.Value
    /// }
    /// ```
    ///
    /// ## Semantics
    ///
    /// When `perform` is called:
    /// 1. The current continuation is captured
    /// 2. The handler for `E` is looked up in `Effect.Context.current`
    /// 3. The handler's `handle(_:continuation:)` is called
    /// 4. The caller suspends until the handler resumes
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Define an effect
    /// struct ReadLine: Effect.Protocol {
    ///     typealias Value = String
    ///     typealias Failure = Never
    /// }
    ///
    /// // Perform it (with handler in scope)
    /// let line = await Effect.perform(ReadLine())
    /// ```
    public enum Perform {}
}

// MARK: - Continuation Factory

extension Effect.Continuation {
    /// Creates a one-shot continuation from a `Result`-delivering closure.
    ///
    /// Available when `Value` is `Copyable` because stdlib's
    /// `Result<Value, Failure>` requires a copyable value.
    ///
    /// - Parameter resume: The closure invoked when the handler resumes.
    /// - Returns: A one-shot continuation.
    public static func one<Value, Failure: Swift.Error>(
        _ resume: @escaping @Sendable (sending Result<Value, Failure>) async -> Void
    ) -> One<Value, Failure> {
        One(
            onValue: { value in await resume(.success(value)) },
            onError: { error in await resume(.failure(error)) }
        )
    }

    /// Creates a one-shot continuation from explicit value and error callbacks.
    ///
    /// Handlers invoke exactly one of the two callbacks via
    /// `resume(returning:)` or `resume(throwing:)`. This form supports
    /// `~Copyable` `Value` types where stdlib's `Result` cannot be used.
    ///
    /// - Parameters:
    ///   - onValue: Invoked when the handler resumes with a value.
    ///   - onError: Invoked when the handler resumes with an error.
    /// - Returns: A one-shot continuation.
    public static func one<Value: ~Copyable, Failure: Swift.Error>(
        onValue: @escaping @Sendable (consuming sending Value) async -> Void,
        onError: @escaping @Sendable (Failure) async -> Void
    ) -> One<Value, Failure> {
        One(onValue: onValue, onError: onError)
    }

    /// Creates a multi-shot continuation from a resume closure.
    ///
    /// Multi-shot continuations can be resumed multiple times,
    /// creating multiple branches of computation.
    ///
    /// - Parameter resume: The closure to call when resuming.
    /// - Returns: A multi-shot continuation.
    public static func multi<Value, Failure: Swift.Error>(
        _ resume: @escaping @Sendable (sending Result<Value, Failure>) async -> Void
    ) -> Multi<Value, Failure> {
        Multi(resume)
    }
}

### File: Sources/Effect Primitives/Effect.swift

/// Namespace for algebraic effect primitives.
///
/// Algebraic effects provide a way to define, perform, and handle
/// operations with resumable continuations. This namespace contains
/// the minimal building blocks required.
///
/// ## Core Concepts
///
/// - **Effects** are operations that a computation cannot handle directly
/// - **Perform** suspends the computation and yields to a handler
/// - **Handlers** interpret effects and resume the continuation
///
/// ## Example
///
/// ```swift
/// // Define an effect
/// struct ReadLine: Effect.Protocol {
///     typealias Value = String
///     typealias Failure = Never
/// }
///
/// // Perform effects in a handled context
/// try await Effect.Context.with { handlers in
///     handlers[ConsoleHandler.self] = .live
/// } operation: {
///     let line = try await Effect.perform(ReadLine())
///     print("Read: \(line)")
/// }
/// ```
public enum Effect {
    /// Protocol for types representing effect operations.
    ///
    /// Use `Effect.Protocol` to refer to this type.
    public typealias `Protocol` = __EffectProtocol
}
