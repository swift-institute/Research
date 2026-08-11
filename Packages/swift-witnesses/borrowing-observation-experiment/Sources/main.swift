// ============================================================================
// Borrowing Observation Experiment
// ============================================================================
//
// Purpose: Verify whether ~Copyable borrow-and-return patterns compile under
//          Swift 6.2 with the Lifetimes experimental feature enabled.
//
// Compiler: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Feature:  -enable-experimental-feature Lifetimes
// Date:     2026-03-04
//
// Three patterns tested:
//   A - Direct borrow passing (closure takes `borrowing` parameter)
//   B - ~Escapable observation wrapper with @_lifetime(borrow)
//   C - Enum with ~Copyable associated value + conditional Copyable
//
// Build: swift build   (from this directory)
//
// ============================================================================
// FINDINGS
// ============================================================================
//
// PATTERN A: WORKS
//   - A closure typed `(borrowing Handle) -> Void` correctly borrows.
//   - The caller can `return result` after `observe(result)` -- the compiler
//     understands the borrow does not consume the value.
//   - LIMITATION: Cannot return `(Handle, R)` tuples because tuples with
//     ~Copyable elements are not supported in Swift 6.2. Workaround: use
//     an `inout` parameter to extract derived values.
//
// PATTERN B: WORKS
//   - `~Copyable, ~Escapable` structs with `@_lifetime(borrow handle)` work.
//   - The observation wrapper correctly borrows from the handle and cannot
//     escape the scope where the handle is alive.
//   - Generic variants (`TypedObservation<Value>`) also work, as long as the
//     generic parameter is Copyable (or constrained with ~Copyable separately).
//
// PATTERN C: WORKS
//   - Enums with `<T: ~Copyable>: ~Copyable` and conditional
//     `Copyable where T: Copyable` compile and behave correctly.
//   - `consuming func get() throws -> T` with `switch consume self` works.
//   - Borrowing computed properties (`var isSuccess: Bool`) work via
//     pattern matching without binding the associated value.
//   - When `T` is Copyable (e.g., `ActionResult<Int>`), the type is
//     implicitly Copyable and supports normal value semantics.
//
// COMBINED: WORKS
//   - Create a ~Copyable handle, borrow-observe it, wrap in
//     `ActionResult<Handle>`, then `consuming get()` extracts it.
//
// ============================================================================


// MARK: - Shared handle type

struct Handle: ~Copyable {
    let fd: Int
    init(_ fd: Int) { self.fd = fd }
}


// ============================================================================
// MARK: - Pattern A: Direct borrow passing
// ============================================================================
//
// A function creates a ~Copyable value, lets an observer borrow it via a
// closure, then returns the original value.
//
// Key question: Does the compiler understand that `observe(result)` borrows
// rather than consumes `result`, allowing the subsequent `return result`?

func withObservation_A(
    create: () -> Handle,
    observe: (borrowing Handle) -> Void
) -> Handle {
    let result = create()
    observe(result)
    return result
}

// Variant: the observer returns a value derived from the borrow.
//
// NOTE: Tuples with ~Copyable elements are NOT supported in Swift 6.2.
//       Cannot write `-> (Handle, R)`. Must use a struct or inout parameter.
//
// DOES NOT COMPILE:
//   func withObservation_A2<R>(
//       create: () -> Handle,
//       observe: (borrowing Handle) -> R
//   ) -> (Handle, R) { ... }
//
// Workaround: pass an inout accumulator for the derived value.
func withObservation_A2<R>(
    create: () -> Handle,
    observe: (borrowing Handle) -> R,
    into result: inout R?
) -> Handle {
    let handle = create()
    result = observe(handle)
    return handle
}


// ============================================================================
// MARK: - Pattern B: ~Escapable observation wrapper
// ============================================================================
//
// A ~Escapable struct that borrows a Handle. The @_lifetime(borrow handle)
// annotation ties the wrapper's lifetime to the handle it borrows.
//
// Key question: Can we create a non-escaping, non-copyable "view" of a
// ~Copyable resource and use it safely?

struct Observation: ~Copyable, ~Escapable {
    let fd: Int

    @_lifetime(borrow handle)
    init(of handle: borrowing Handle) {
        self.fd = handle.fd
    }
}

func withObservation_B(
    handle: borrowing Handle,
    body: (borrowing Observation) -> Void
) {
    let obs = Observation(of: handle)
    body(obs)
}

// Variant: observation wrapper that carries a derived value.
struct TypedObservation<Value>: ~Copyable, ~Escapable {
    let fd: Int
    let value: Value

    @_lifetime(borrow handle)
    init(of handle: borrowing Handle, value: Value) {
        self.fd = handle.fd
        self.value = value
    }
}

func withTypedObservation_B2<V>(
    handle: borrowing Handle,
    derive: (borrowing Handle) -> V,
    body: (borrowing TypedObservation<V>) -> Void
) {
    let v = derive(handle)
    let obs = TypedObservation(of: handle, value: v)
    body(obs)
}


// ============================================================================
// MARK: - Pattern C: Enum with ~Copyable associated value + conditional Copyable
// ============================================================================
//
// An enum that wraps a ~Copyable value as an associated value, with a
// conditional Copyable conformance when the wrapped type is Copyable.
//
// Key question: Does conditional Copyable on an enum with ~Copyable generic
// parameter compile and behave correctly?

enum ActionResult<T: ~Copyable>: ~Copyable {
    case success(T)
    case failure(any Error)
}

extension ActionResult: Copyable where T: Copyable {}

// Consuming extraction.
extension ActionResult where T: ~Copyable {
    consuming func get() throws -> T {
        switch consume self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// Borrowing inspection.
extension ActionResult where T: ~Copyable {
    var isSuccess: Bool {
        switch self {
        case .success: true
        case .failure: false
        }
    }
}


// ============================================================================
// MARK: - Combined: create-observe-return with ActionResult
// ============================================================================
//
// Combines patterns A and C: create a handle, observe it, wrap in result.

func createAndObserve(
    fd: Int,
    observe: (borrowing Handle) -> Void
) -> ActionResult<Handle> {
    let handle = Handle(fd)
    observe(handle)
    return .success(handle)
}


// ============================================================================
// MARK: - Exercises
// ============================================================================

// Pattern A
do {
    let handle = withObservation_A(
        create: { Handle(42) },
        observe: { h in print("A: observing fd=\(h.fd)") }
    )
    print("A: returned fd=\(handle.fd)")
}

// Pattern A2 (inout workaround for tuple limitation)
do {
    var description: String? = nil
    let handle = withObservation_A2(
        create: { Handle(99) },
        observe: { h in "observed-\(h.fd)" },
        into: &description
    )
    print("A2: returned fd=\(handle.fd), description=\(description!)")
}

// Pattern B
do {
    let handle = Handle(7)
    withObservation_B(handle: handle) { obs in
        print("B: observation fd=\(obs.fd)")
    }
    print("B: handle still alive fd=\(handle.fd)")
}

// Pattern B2
do {
    let handle = Handle(13)
    withTypedObservation_B2(
        handle: handle,
        derive: { h in "derived-\(h.fd)" }
    ) { obs in
        print("B2: observation fd=\(obs.fd), value=\(obs.value)")
    }
}

// Pattern C
do {
    let result: ActionResult<Handle> = .success(Handle(55))
    print("C: isSuccess=\(result.isSuccess)")
    let handle = try result.get()
    print("C: extracted fd=\(handle.fd)")
}

// Pattern C with Copyable type (should be copyable)
do {
    let result: ActionResult<Int> = .success(123)
    let copy = result  // Should compile — Int is Copyable
    print("C-copyable: \(result.isSuccess), copy=\(copy.isSuccess)")
}

// Combined
do {
    let result = createAndObserve(fd: 77) { h in
        print("Combined: observing fd=\(h.fd)")
    }
    let handle = try result.get()
    print("Combined: final fd=\(handle.fd)")
}

print("\nAll patterns compiled and ran successfully.")
