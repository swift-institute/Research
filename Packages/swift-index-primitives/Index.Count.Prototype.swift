// ===----------------------------------------------------------------------===//
//
// PROTOTYPE: Index.Count as Tagged Typealias
//
// This file demonstrates Option 3 from index-count-offset-as-tagged.md
// DO NOT USE IN PRODUCTION - for validation only
//
// ===----------------------------------------------------------------------===//

import Cardinal_Primitives
@_spi(Internal) import Tagged_Primitives

// MARK: - Type Definition (replaces nested struct)

/*
 PROPOSED CHANGE:

 Instead of:
 ```swift
 extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
     public struct Count: Hashable, Comparable, Sendable {
         public let count: Cardinal
         // ... 100+ lines of manual implementations
     }
 }
 ```

 We define:
 ```swift
 extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
     public typealias Count = Tagged<Tag, Cardinal>
 }
 ```

 Then Index<Foo>.Count = Tagged<Foo, Cardinal>

 All Tagged machinery (retag, map, Equatable, Hashable, Comparable, Sendable) applies automatically.
*/

// MARK: - Simulated typealias (can't actually redefine in same module)

// For prototype purposes, we'll define a parallel type to test the approach
typealias ProtoCount<Tag: ~Copyable> = Tagged<Tag, Cardinal>

// MARK: - API Compatibility Extensions

extension Tagged where RawValue == Cardinal, Tag: ~Copyable {

    // MARK: Compatibility Properties

    /// The underlying cardinal count (API compatibility with nested struct).
    @inlinable
    package var count: Cardinal { rawValue }

    // Note: Can't shadow rawValue, but could provide:
    // @inlinable
    // var unsignedValue: UInt { rawValue.rawValue }

    // MARK: Construction

    /// Creates a typed count from an unsigned integer.
    @inlinable
    package init(_ rawValue: UInt) {
        self.init(__unchecked: (), Cardinal(rawValue))
    }

    /// Creates a typed count from a signed integer.
    /// - Throws: `Cardinal.Error.negativeSource` if negative.
    @inlinable
    package init(_ rawValue: Int) throws(Cardinal.Error) {
        self.init(__unchecked: (), try Cardinal(rawValue))
    }

    /// Creates a typed count without validation.
    @inlinable
    package init(__unchecked: Void, _ rawValue: Int) {
        self.init(__unchecked: (), Cardinal(UInt(rawValue)))
    }

    // MARK: Constants

    /// The zero count.
    @inlinable
    package static var zero: Self {
        Self(__unchecked: (), Cardinal.zero)
    }

    /// The count of one.
    @inlinable
    package static var one: Self {
        Self(__unchecked: (), Cardinal.one)
    }
}

// MARK: - Arithmetic (still needed, but simpler)

extension Tagged where RawValue == Cardinal, Tag: ~Copyable {
    /// Adds two counts (trapping on overflow).
    @inlinable
    package static func + (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), lhs.rawValue + rhs.rawValue)
    }

    /// Increments the count by another count.
    @inlinable
    package static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
}

// MARK: - What We Get For Free

/*
 FROM TAGGED CONDITIONAL CONFORMANCES:

 - Equatable (when RawValue: Equatable) ✓ Cardinal is Equatable
 - Hashable (when RawValue: Hashable) ✓ Cardinal is Hashable
 - Comparable (when RawValue: Comparable) ✓ Cardinal is Comparable
 - Sendable (when RawValue: Sendable) ✓ Cardinal is Sendable

 NO MANUAL OPERATORS NEEDED FOR:
 - ==
 - <, <=, >, >=
 - hash(into:)

 FROM TAGGED FUNCTOR:

 - retag<NewTag>() -> Tagged<NewTag, RawValue>
 - map<NewRaw>((RawValue) -> NewRaw) -> Tagged<Tag, NewRaw>
*/

// MARK: - Validation Tests

#if DEBUG
func validatePrototype() {
    // Test 1: Construction
    let count1 = ProtoCount<Int>(5 as UInt)
    let count2 = ProtoCount<Int>(10 as UInt)

    // Test 2: Equality (free from Tagged)
    assert(count1 == count1)
    assert(count1 != count2)

    // Test 3: Comparison (free from Tagged)
    assert(count1 < count2)

    // Test 4: Arithmetic
    let sum = count1 + count2
    assert(sum.rawValue == 15)

    // Test 5: Retag (THIS IS THE KEY BENEFIT)
    let retagged: ProtoCount<String> = count1.retag(String.self)
    assert(retagged.rawValue == count1.rawValue)

    // Test 6: Cross-domain init (uses retag internally)
    let converted = ProtoCount<String>(count1)
    assert(converted.rawValue == count1.rawValue)

    // Test 7: Static constants
    assert(ProtoCount<Int>.zero.rawValue == 0)
    assert(ProtoCount<Int>.one.rawValue == 1)

    // Test 8: Map (transform raw value)
    let doubled = count1.map { Cardinal($0.rawValue * 2) }
    assert(doubled.rawValue == 10)

    print("✓ All prototype validations passed")
}
#endif
