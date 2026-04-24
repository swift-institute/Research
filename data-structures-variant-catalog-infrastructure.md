# Variant Catalog: Banned-Umbrella Packages

Generated: 2026-04-03

This catalog documents every public type, protocol, and extension in each variant module
of the nine banned-umbrella packages in `swift-primitives`.

---

## 1. swift-memory-primitives

### Module: Memory Primitives Core

| Type | Kind | File |
|------|------|------|
| `Memory` | enum | Memory.swift |
| `Memory.Address` (= `Tagged<Memory, Ordinal>`) | typealias | Memory.Address.swift |
| `Memory.Address.Error` | enum (Error) | Memory.Address.Error.swift |
| `Memory.Aligned` | protocol | Memory.Aligned.swift |
| `Memory.Alignment` | struct | Memory.Alignment.swift |
| `Memory.Alignment.Align` | enum (tag) | Memory.Alignment.Align.swift |
| `Memory.Alignment.Error` | enum (Error) | Memory.Alignment.Error.swift |
| `Memory.Allocation` | enum (namespace) | Memory.Allocation.swift |
| `Memory.Contiguous` | struct (~Copyable) | Memory.Contiguous.swift |
| `Memory.Contiguous.Protocol` (= `Memory.ContiguousProtocol`) | typealias | Memory.Contiguous.swift |
| `Memory.Contiguous.View` (= `Span<Element>`) | typealias | Memory.Contiguous+Memory.ContiguousProtocol.swift |
| `Memory.ContiguousProtocol` | protocol | Memory.ContiguousProtocol.swift |
| `Memory.Inline<Element, capacity>` | struct (~Copyable) | Memory.Inline.swift |
| `Memory.Inline._Raw` | struct (~Copyable, package) | Memory.Inline.swift |
| `Memory.Shift` | struct | Memory.Shift.swift |
| `Memory.Shift.Error` | enum (Error) | Memory.Shift.Error.swift |

Extensions on stdlib types:
- `UnsafeRawPointer` (Memory.Address init) -- Memory.Address.swift
- `UnsafeMutableRawPointer` (Memory.Address init) -- Memory.Address.swift
- `Affine.Discrete.Ratio where To == Memory` (stride ratio) -- Memory+Affine.Discrete.Ratio.swift

### Module: Memory Arena Primitives

| Type | Kind | File |
|------|------|------|
| `Memory.Arena` | struct (~Copyable) | Memory.Arena.swift |
| `Memory.Arena.Error` | enum (Error) | Memory.Arena.Error.swift |

### Module: Memory Pool Primitives

| Type | Kind | File |
|------|------|------|
| `Memory.Pool` | struct (~Copyable) | Memory.Pool.swift |
| `Memory.Pool.Error` | enum (Error) | Memory.Pool.Error.swift |
| `Memory.Pool.Slot` | enum (tag/namespace) | Memory.Pool.Slot.swift |

Extensions providing methods:
- `Memory.Pool.duplicate(copySlotContents:)` -- Memory.Pool.Duplicate.swift
- `Property.View.Read where Tag == Memory.Allocation, Base == Memory.Pool` -- Memory.Pool+allocation.swift
- `Property.View.Read where Tag == Memory.Pool.Slot, Base == Memory.Pool` -- Memory.Pool+slot.swift

### Module: Memory Buffer Primitives

(Also re-exported identically in the `Memory Primitives` umbrella target.)

| Type | Kind | File |
|------|------|------|
| `Memory.Allocator` | struct | Memory.Allocator.swift |
| `Memory.Allocator.Protocol` | protocol | Memory.Allocator.Protocol.swift |
| `Memory.Buffer` | struct | Memory.Buffer.swift |
| `Memory.Buffer.Base` | enum (tag) | Memory.Buffer.Base.swift |
| `Memory.Buffer.Mutable` | struct | Memory.Buffer.Mutable.swift |
| `Memory.Buffer.Mutable.Base` | enum (tag) | Memory.Buffer.Mutable.Base.swift |

### Module: Memory Primitives Standard Library Integration (internal)

No new public types. Extensions on stdlib types:

| Extension Target | File |
|-----------------|------|
| `Swift.Array: Memory.Contiguous.Protocol` | Memory+Array.swift |
| `UnsafeMutableRawBufferPointer` (+ `Store` tag enum) | Memory+UnsafeMutableRawBufferPointer.swift, .Store.swift |
| `UnsafeMutableRawPointer` (+ `Store` tag enum, `Move` tag enum) | Memory+UnsafeMutableRawPointer.swift, .Store.swift, .Memory.Move.swift, .Memory.swift |
| `UnsafeRawBufferPointer` | Memory+UnsafeRawBufferPointer.swift |
| `UnsafeRawPointer` | Memory+UnsafeRawPointer.swift |

Tag enums declared inside stdlib extensions:
- `UnsafeMutableRawBufferPointer.Store` -- enum
- `UnsafeMutableRawPointer.Store` -- enum
- `UnsafeMutableRawPointer.Move` -- enum (inside Memory namespace on pointer)

---

## 2. swift-bit-vector-primitives

### Module: Bit Vector Primitives Core

| Type | Kind | File |
|------|------|------|
| `Bit.Vector` | struct (~Copyable) | Bit.Vector.swift |
| `Bit.Vector.Protocol` | protocol | Bit.Vector.Protocol.swift |
| `Bit.Vector.Clear` | enum (tag) | Bit.Vector.Clear.swift |
| `Bit.Vector.Pop` | enum (tag) | Bit.Vector.Pop.swift |
| `Bit.Vector.Set` | enum (tag) | Bit.Vector.Set.swift |
| `Bit.Vector.Ones` | enum (namespace) | Bit.Vector.Ones.swift |
| `Bit.Vector.Ones.View` | struct | Bit.Vector.Ones.View.swift |
| `Bit.Vector.Ones.View.Iterator` | struct | Bit.Vector.Ones.View.Iterator.swift |
| `Bit.Vector.Zeros` | enum (namespace) | Bit.Vector.Zeros.swift |
| `Bit.Vector.Zeros.View` | struct | Bit.Vector.Zeros.View.swift |
| `Bit.Vector.Zeros.View.Iterator` | struct | Bit.Vector.Zeros.View.Iterator.swift |

### Module: Bit Vector Static Primitives

| Type | Kind | File |
|------|------|------|
| `Bit.Vector.Static<wordCount>` | struct | Bit.Vector.Static.swift |
| `Bit.Vector.Ones.Static<wordCount>` | struct | Bit.Vector.Ones.Static.swift |
| `Bit.Vector.Ones.Static.Iterator` | struct | Bit.Vector.Ones.Static.Iterator.swift |
| `Bit.Vector.Zeros.Static<wordCount>` | struct | Bit.Vector.Zeros.Static.swift |
| `Bit.Vector.Zeros.Static.Iterator` | struct | Bit.Vector.Zeros.Static.Iterator.swift |

### Module: Bit Vector Bounded Primitives

| Type | Kind | File |
|------|------|------|
| `Bit.Vector.Bounded` | struct | Bit.Vector.Bounded.swift |
| `Bit.Vector.Bounded.Error` (= `__BitVectorBoundedError`) | typealias -> public enum | Bit.Vector.Bounded.swift, Bit.Vector.Bounded.Error.swift |
| `Bit.Vector.Bounded.All` | enum (tag) | Bit.Vector.Bounded.All.swift |
| `Bit.Vector.Bounded.Capacity` | enum (tag) | Bit.Vector.Bounded.Capacity.swift |
| `Bit.Vector.Bounded.Statistic` | enum (tag) | Bit.Vector.Bounded.Statistic.swift |
| `Bit.Vector.Bounded.Iterator` | struct | Bit.Vector.Bounded+Sequence.swift |
| `Bit.Vector.Ones.Bounded` | struct | Bit.Vector.Ones.Bounded.swift |
| `Bit.Vector.Ones.Bounded.Iterator` | struct | Bit.Vector.Ones.Bounded.Iterator.swift |
| `Bit.Vector.Zeros.Bounded` | struct | Bit.Vector.Zeros.Bounded.swift |
| `Bit.Vector.Zeros.Bounded.Iterator` | struct | Bit.Vector.Zeros.Bounded.Iterator.swift |

### Module: Bit Vector Inline Primitives

| Type | Kind | File |
|------|------|------|
| `Bit.Vector.Inline<wordCount>` | struct | Bit.Vector.Inline.swift |
| `Bit.Vector.Inline.Error` (= `__BitVectorInlineError`) | typealias -> public enum | Bit.Vector.Inline.swift, Bit.Vector.Inline.Error.swift |
| `Bit.Vector.Inline.All` | enum (tag + View typealias) | Bit.Vector.Inline.All.swift |
| `Bit.Vector.Inline.Capacity` | enum (tag + View typealias) | Bit.Vector.Inline.Capacity.swift |
| `Bit.Vector.Inline.Statistic` | enum (tag + View typealias) | Bit.Vector.Inline.Statistic.swift |
| `Bit.Vector.Inline.Iterator` | struct | Bit.Vector.Inline+Sequence.swift |
| `Bit.Vector.Ones.Inline<wordCount>` | struct | Bit.Vector.Ones.Inline.swift |
| `Bit.Vector.Ones.Inline.Iterator` | struct | Bit.Vector.Ones.Inline.Iterator.swift |
| `Bit.Vector.Zeros.Inline<wordCount>` | struct | Bit.Vector.Zeros.Inline.swift |
| `Bit.Vector.Zeros.Inline.Iterator` | struct | Bit.Vector.Zeros.Inline.Iterator.swift |

### Module: Bit Vector Dynamic Primitives

| Type | Kind | File |
|------|------|------|
| `Bit.Vector.Dynamic` | struct | Bit.Vector.Dynamic.swift |
| `Bit.Vector.Dynamic.Error` (= `__BitVectorDynamicError`) | typealias -> public enum | Bit.Vector.Dynamic.swift, Bit.Vector.Dynamic.Error.swift |
| `Bit.Vector.Dynamic.All` | enum (tag) | Bit.Vector.Dynamic.All.swift |
| `Bit.Vector.Dynamic.Statistic` | enum (tag) | Bit.Vector.Dynamic.Statistic.swift |
| `Bit.Vector.Dynamic.Toggle` | enum (tag) | Bit.Vector.Dynamic+returning.swift |
| `Bit.Vector.Dynamic.Iterator` | struct | Bit.Vector.Dynamic+Sequence.swift |

---

## 3. swift-binary-primitives

### Module: Binary Primitives Core

| Type | Kind | File |
|------|------|------|
| `Binary` | enum | Binary.swift |
| `Binary.Aligned` | protocol | Binary.Aligned.swift |
| `Binary.Bytes` | enum (namespace) | Binary.Bytes.swift |
| `Binary.Count<Scalar, Space>` | struct | Binary.Count.swift |
| `Binary.Cursor<Storage>` | struct (~Copyable) | Binary.Cursor.swift |
| `Binary.Endianness` | enum | Binary.Endianness.swift |
| `Binary.Endianness.Value<Payload>` (= `Tagged<Binary.Endianness, Payload>`) | typealias | Binary.Endianness.swift |
| `Binary.Error` | enum (Error) | Binary.Error.swift |
| `Binary.Error.Bit` | struct (Error) | Binary.Error.Bit.swift |
| `Binary.Error.Bit.Kind` | enum | Binary.Error.Bit.swift |
| `Binary.Error.Bounds` | struct (Error) | Binary.Error.Bounds.swift |
| `Binary.Error.Bounds.Field` | enum | Binary.Error.Bounds.swift |
| `Binary.Error.Invariant` | struct (Error) | Binary.Error.Invariant.swift |
| `Binary.Error.Invariant.Kind` | enum | Binary.Error.Invariant.swift |
| `Binary.Error.Negative` | struct (Error) | Binary.Error.Negative.swift |
| `Binary.Error.Negative.Field` | enum | Binary.Error.Negative.swift |
| `Binary.Error.Overflow` | struct (Error) | Binary.Error.Overflow.swift |
| `Binary.Error.Overflow.Operation` | enum | Binary.Error.Overflow.swift |
| `Binary.Error.Overflow.Field` | enum | Binary.Error.Overflow.swift |
| `Binary.LEB128` | enum | Binary.LEB128.swift |
| `Binary.LEB128.Error` | enum (Error) | Binary.LEB128.Error.swift |
| `Binary.Mask` | struct | Binary.Mask.swift |
| `Binary.Parse` | enum (namespace) | Binary.Parse.swift |
| `Binary.Parse.Error` | enum (Error) | Binary.Parse.Error.swift |
| `Binary.Pattern<Carrier>` | enum | Binary.Pattern.swift |
| `Binary.Pattern.Mask` | struct | Binary.Pattern.swift |
| `Binary.Position<Scalar, Space>` (= `Coordinate.X<Space>.Value<Scalar>`) | typealias | Binary.Position.swift |
| `Binary.Offset<Scalar, Space>` (= `Displacement.X<Space>.Value<Scalar>`) | typealias | Binary.Position.swift |
| `Binary.Reader<Storage>` | struct (~Copyable) | Binary.Reader.swift |
| `Binary.Space` | enum (Spatial) | Binary.Space.swift |
| `Pattern8` (= `Binary.Pattern<UInt8>`) | typealias | Binary.Pattern.swift |
| `Pattern16` (= `Binary.Pattern<UInt16>`) | typealias | Binary.Pattern.swift |
| `Pattern32` (= `Binary.Pattern<UInt32>`) | typealias | Binary.Pattern.swift |
| `Pattern64` (= `Binary.Pattern<UInt64>`) | typealias | Binary.Pattern.swift |
| `PatternWord` (= `Binary.Pattern<UInt>`) | typealias | Binary.Pattern.swift |

Operators declared:
- `-?` (prefix), `+?`, `-?`, `*?`, `/?` (infix) -- Binary.Optionator.swift

Extensions on stdlib types:
- `[UInt8]` (byte manipulation) -- Array+Bytes.swift
- `Collection<UInt8>` -- Collection+UInt8.swift
- `RangeReplaceableCollection<UInt8>` -- RangeReplaceableCollection+Bytes.swift
- `FixedWidthInteger` (binary conversion, optionator) -- FixedWidthInteger+Binary.swift, FixedWidthInteger+Optionator.swift, FixedWidthInteger+Optionator.Assignment.swift
- `Optional where Wrapped: FixedWidthInteger` -- FixedWidthInteger+Optionator.swift
- `Optional where Wrapped: Comparable` -- Comparable+Optionator.Range.swift
- `Tagged where RawValue: FixedWidthInteger` (bitwise ops) -- Tagged+Bitwise.swift
- `Memory.Alignment` (Binary.Position conversions) -- Memory.Alignment+Binary.Position.swift
- Integer types (Int, Int8, Int16, Int32, Int64, UInt, UInt16, UInt32, UInt64) -- individual files

### Module: Binary Format Primitives

| Type | Kind | File |
|------|------|------|
| `Binary.Format` | enum (namespace) | Binary.Format.swift |
| `Binary.Format.Bytes` | struct | Binary.Format.Bytes.swift |
| `Binary.Format.Bytes.Notation` | enum | Binary.Format.Bytes.Notation.swift |
| `Binary.Format.Bytes.Unit` | struct | Binary.Format.Bytes.Unit.swift |
| `Binary.Format.Bytes.Units` | enum | Binary.Format.Bytes.Units.swift |
| `Binary.Format.Radix` | struct | Binary.Format.Radix.swift |
| `Binary.Format.Radix.SignDisplayStrategy` | struct | Binary.Format.Radix.swift |

Extensions on stdlib types:
- `BinaryInteger` (format accessors) -- Binary.Format.Bytes.swift, Binary.Format.Radix.swift
- `RawRepresentable where RawValue: BinaryInteger` -- RawRepresentable+Format.swift

### Module: Binary Serializable Primitives

| Type | Kind | File |
|------|------|------|
| `Binary.Serializable` | protocol | Binary.Serializable.swift |

Extensions providing conformances:
- `RangeReplaceableCollection<UInt8>` -- Binary.Serializable.swift
- `Array<UInt8>: Binary.Serializable` -- Binary.Serializable.swift
- `ContiguousArray<UInt8>: Binary.Serializable` -- Binary.Serializable.swift
- `ArraySlice<UInt8>: Binary.Serializable` -- Binary.Serializable.swift
- `StringProtocol` -- Binary.Serializable.swift
- `String: Binary.Serializable` (implicit) -- Binary.Serializable.swift
- `Tagged: Binary.Serializable where RawValue: Binary.Serializable` -- Binary.Serializable.swift
- `Binary.Serializable where Self: RawRepresentable` (multiple constrained extensions) -- Binary.Serializable.swift
- `Binary.Serializable.serializing` (witness bridge) -- Binary.Serializable+Witness.swift

---

## 4. swift-numeric-primitives

### Module: Numeric Primitives Core

| Type | Kind | File |
|------|------|------|
| `Numeric` | enum | Numeric.swift |
| `Numeric.Protocol` (= `Swift.Numeric`) | typealias | Numeric.swift |
| `Numeric.Transcendental` (= `Transcendental`) | typealias | Numeric.swift |
| `Transcendental` | protocol | Numeric.Transcendental.swift |
| `Numeric.Comparison` | enum (namespace) | Numeric.Comparison.swift |
| `Numeric.Comparison.Equals<T>` | struct | Numeric.Comparison.Equals.swift |
| `Numeric.Math` | enum (namespace) | Numeric.Math.swift |
| `Numeric.Math.Accessor<T>` | struct | Numeric.Math.Accessor.swift |
| `Numeric.Quantized` | protocol | Numeric.Quantized.swift |
| `Numeric.Rounding` | enum | Numeric.Rounding.swift |
| `Numeric.Rounding.Direction` | enum | Numeric.Rounding.swift |
| `Numeric.Rounding.Nearest` | enum | Numeric.Rounding.swift |

Extensions on stdlib types:
- `FloatingPoint` (rounding) -- FloatingPoint+Rounding.swift
- `FloatingPoint where Self: Sendable` (comparison accessor) -- Numeric.Comparison.Equals.swift
- `SignedNumeric where Self: Sendable` (comparison accessor) -- Numeric.Comparison.Equals.swift

### Module: Real Primitives

| Type | Kind | File |
|------|------|------|
| `Numeric.Augmented` | enum (namespace) | Numeric.Augmented.swift |
| `Numeric.Fraction<Numerator, Denominator, Result>` | struct | Numeric.Fraction.swift |
| `Numeric.Relaxed` | enum (namespace) | Numeric.Relaxed.swift |

Extensions providing:
- `Numeric.Math` (real-valued operations) -- Numeric.Math.swift
- `Numeric.Math.Accessor where T == Double/Float/Float16` -- Numeric.Math.Accessor.swift
- `Double: Numeric.Transcendental` -- Numeric.Transcendental+Conformances.swift
- `Float: Numeric.Transcendental` -- Numeric.Transcendental+Conformances.swift
- `Float16: Numeric.Transcendental` -- Numeric.Transcendental+Conformances.swift
- `Double`, `Float`, `Float16` (math accessor property) -- Numeric.Math.Accessor.swift

### Module: Integer Primitives

| Type | Kind | File |
|------|------|------|
| `Numeric.Integer` (= `Int`) | typealias | Numeric.Integer.swift |
| `Numeric.Integer.Division<T>` | struct | Numeric.Integer.Division.swift |
| `Numeric.Integer.Rotation<T>` | struct | Numeric.Integer.Rotation.swift |
| `Numeric.Integer.Saturating<T>` | struct | Numeric.Integer.Saturating.swift |
| `Numeric.Integer.Shift<T>` | struct | Numeric.Integer.Shift.swift |

Extensions on stdlib types:
- `BinaryInteger` (shift operations) -- BinaryInteger+Shift.swift
- `FixedWidthInteger where Self: Sendable` (rotation, saturating) -- FixedWidthInteger+Rotation.swift, FixedWidthInteger+Saturating.swift
- `SignedInteger where Self: Sendable` (euclidean division) -- SignedInteger+Division.swift
- `Numeric.Integer` (GCD) -- BinaryInteger+GCD.swift

---

## 5. swift-sequence-primitives

### Module: Sequence Primitives Core (internal)

| Type | Kind | File |
|------|------|------|
| `Sequence` | struct | Sequence.swift |
| `Sequence.Protocol` | protocol (~Copyable, ~Escapable) | Sequence.Protocol.swift |
| `Sequence.Iterator` | enum (namespace) | Sequence.Iterator.swift |
| `Sequence.Iterator.Protocol` | protocol (~Copyable, ~Escapable) | Sequence.Iterator.Protocol.swift |
| `Sequence.Borrowing` | enum (namespace) | Sequence.Borrowing.swift |
| `Sequence.Borrowing.Protocol` | protocol (~Copyable, ~Escapable) | Sequence.Borrowing.Protocol.swift |
| `Sequence.Clearable` | protocol | Sequence.Clearable.swift |
| `Sequence.Consume` | enum (namespace) | Sequence.Consume.swift |
| `Sequence.Consume.Protocol` | protocol (~Copyable) | Sequence.Consume.swift |
| `Sequence.Consume.View<Element, State>` | struct (~Copyable) | Sequence.Consume.View.swift |
| `Sequence.Contains` | enum (tag) | Sequence.Contains.swift |
| `Sequence.Count` | enum (tag) | Sequence.Count.swift |
| `Sequence.Drain` | enum (tag) | Sequence.Drain.swift |
| `Sequence.Drain.Protocol` | protocol (~Copyable) | Sequence.Drain.swift |
| `Sequence.Drop` | enum (namespace) | Sequence.Drop.swift |
| `Sequence.Drop.First<Base>` | struct (~Copyable, ~Escapable) | Sequence.Drop.First.swift |
| `Sequence.Drop.First.Iterator` | struct (~Copyable, ~Escapable) | Sequence.Drop.First.Iterator.swift |
| `Sequence.Drop.While<Base>` | struct (~Copyable, ~Escapable) | Sequence.Drop.While.swift |
| `Sequence.Drop.While.Iterator` | struct (~Copyable, ~Escapable) | Sequence.Drop.While.Iterator.swift |
| `Sequence.Filter<Base>` | struct (~Copyable, ~Escapable) | Sequence.Filter.swift |
| `Sequence.Filter.Iterator` | struct (~Copyable, ~Escapable) | Sequence.Filter.Iterator.swift |
| `Sequence.First` | enum (tag) | Sequence.First.swift |
| `Sequence.FlatMap<Base, InnerSequence>` | struct (~Copyable, ~Escapable) | Sequence.FlatMap.swift |
| `Sequence.FlatMap.Iterator` | struct (~Copyable, ~Escapable) | Sequence.FlatMap.Iterator.swift |
| `Sequence.ForEach` | enum (tag) | Sequence.ForEach.swift |
| `Sequence.Map<Base, Output>` | struct (~Copyable, ~Escapable) | Sequence.Map.swift |
| `Sequence.Map.Iterator` | struct (~Copyable, ~Escapable) | Sequence.Map.Iterator.swift |
| `Sequence.CompactMap<Base, Output>` | struct (~Copyable, ~Escapable) | Sequence.CompactMap.swift |
| `Sequence.CompactMap.Iterator` | struct (~Copyable, ~Escapable) | Sequence.CompactMap.Iterator.swift |
| `Sequence.Prefix` | enum (namespace) | Sequence.Prefix.swift |
| `Sequence.Prefix.First<Base>` | struct (~Copyable, ~Escapable) | Sequence.Prefix.First.swift |
| `Sequence.Prefix.First.Iterator` | struct (~Copyable, ~Escapable) | Sequence.Prefix.First.Iterator.swift |
| `Sequence.Prefix.While<Base>` | struct (~Copyable, ~Escapable) | Sequence.Prefix.While.swift |
| `Sequence.Prefix.While.Iterator` | struct (~Copyable, ~Escapable) | Sequence.Prefix.While.Iterator.swift |
| `Sequence.Reduce` | enum (tag) | Sequence.Reduce.swift |
| `Sequence.Satisfies` | enum (tag) | Sequence.Satisfies.swift |
| `Sequence.Span` | enum (tag) | Sequence.Span.swift |

Property.View extensions for tags: Contains, Count, Drain, First, ForEach, Reduce, Satisfies, Span.

### Module: Sequence Difference Primitives

| Type | Kind | File |
|------|------|------|
| `Sequence.Difference` | enum (namespace) | Sequence.Difference.swift |
| `Sequence.Difference.Change<Element>` | enum | Sequence.Difference.Change.swift |
| `Sequence.Difference.Changes<Value>` | struct | Sequence.Difference.Changes.swift |
| `Sequence.Difference.Changes.Iterator` | struct | Sequence.Difference.Changes.Iterator.swift |
| `Sequence.Difference.Hunk` | struct | Sequence.Difference.Hunk.swift |
| `Sequence.Difference.Step` | enum | Sequence.Difference.Step.swift |
| `Sequence.Difference.Steps` | struct | Sequence.Difference.Steps.swift |
| `Sequence.Difference.Steps.Iterator` | struct | Sequence.Difference.Steps.Iterator.swift |

### Module: Sequence Primitives Standard Library Integration (internal)

No new named types. Extensions:

| Extension Target | File |
|-----------------|------|
| `Sequence.Protocol where Self: Copyable` (Swift.Sequence bridging) | Sequence.Protocol+Swift.Sequence.swift |
| `Swift.Span.Iterator` | Swift.Span.Iterator.swift |
| `Swift.Span.Iterator.Batch` | Swift.Span.Iterator.Batch.swift |
| `Swift.Span where Element: Copyable` (extracting) | Swift.Span+extracting.swift |

Nested types in stdlib extensions:
- `Swift.Span.Iterator` -- struct (~Escapable, ~Copyable)
- `Swift.Span.Iterator.Batch` -- struct (~Escapable, ~Copyable)

---

## 6. swift-affine-primitives

### Module: Affine Primitives Core (internal)

| Type | Kind | File |
|------|------|------|
| `Affine` | enum | Affine.swift |
| `Affine.Discrete` | enum (namespace) | Affine.Discrete.swift |
| `Affine.Discrete.Ratio<From, To>` | struct | Affine.Discrete.Ratio.swift |
| `Affine.Discrete.Vector` | struct | Affine.Discrete.Vector.swift |
| `Affine.Discrete.Vector.Displacement` (= `Vector`) | typealias | Affine.Discrete.Vector.swift |
| `Affine.Discrete.Vector.Protocol` | protocol | Affine.Discrete.Vector.Protocol.swift |
| `Affine.Discrete.Vector.Error` | enum (Error) | Affine.Discrete.Vector.Error.swift |

Extensions providing conformances/methods:
- `Affine.Discrete.Vector: Affine.Discrete.Vector.Protocol` -- Affine.Discrete.Vector.Protocol.swift
- `Tagged: Affine.Discrete.Vector.Protocol where RawValue == Affine.Discrete.Vector` -- Affine.Discrete.Vector.Protocol.swift
- `Ordinal` (affine arithmetic) -- Ordinal+Affine.swift
- `Tagged where RawValue == Ordinal` (affine arithmetic, Offset typealias) -- Tagged+Affine.swift
- `Tagged where RawValue == Affine.Discrete.Vector` -- Tagged+Affine.swift
- `Tagged where RawValue == Cardinal` -- Tagged+Affine.swift

### Module: Affine Primitives Standard Library Integration

No new named types. Extensions on stdlib types:

| Extension Target | File |
|-----------------|------|
| `Int` (Affine.Discrete.Vector conversions) | Int+Affine.Discrete.Vector.swift |
| `RandomAccessCollection` (Tagged.Ordinal.Offset subscripts) | RandomAccessCollection+Tagged.Ordinal.Offset.swift |
| `UnsafeMutablePointer where Pointee: ~Copyable` | UnsafeMutablePointer+Tagged.Ordinal.swift |
| `UnsafePointer where Pointee: ~Copyable` | UnsafePointer+Tagged.Ordinal.swift |

---

## 7. swift-serializer-primitives

### Module: Serializer Primitives Core

| Type | Kind | File |
|------|------|------|
| `Serializer` | enum | Serializer.swift |
| `Serializer.Protocol` | protocol (generic: Output, Buffer, Failure) | Serializer.Protocol.swift |
| `Serializer.Builder<Buffer>` | struct | Serializer.Builder.swift |
| `Serializable` | protocol | Serializable.swift |

### Module: Serialization Primitives

| Type | Kind | File |
|------|------|------|
| `Serialization` | enum | Serialization.swift |
| `Serialization.Parsing` | enum (namespace) | Serialization.Parsing.swift |
| `Serialization.Parsing.Prefix` | enum (namespace) | Serialization.Parsing.Prefix.swift |
| `Serialization.Parsing.Prefix.Result<Output, Count>` | struct | Serialization.Parsing.Prefix.Result.swift |
| `Serialization.Parsing.Prefix.Witness<Output, Count, Representation, Context, Failure>` | struct | Serialization.Parsing.Prefix.Witness.swift |
| `Serialization.Parsing.Whole<Output, Representation, Context, Failure>` | struct | Serialization.Parsing.Whole.swift |
| `Serialization.Serializing` | enum (namespace) | Serialization.Serializing.swift |
| `Serialization.Serializing.Buffer<Output, Element, Context>` | struct | Serialization.Serializing.Buffer.swift |
| `Serialization.Serializing.Value<Output, Representation, Context, Failure>` | struct | Serialization.Serializing.Value.swift |
| `Serialization.Measuring<Output, Context>` | struct | Serialization.Measuring.swift |

Void-context convenience extensions:
- `Serialization.Serializing.Value where Context == Void` -- Serialization+Void.swift
- `Serialization.Serializing.Buffer where Context == Void` -- Serialization+Void.swift
- `Serialization.Parsing.Whole where Context == Void` -- Serialization+Void.swift
- `Serialization.Parsing.Prefix.Witness where Context == Void` -- Serialization+Void.swift
- `Serialization.Measuring where Context == Void` -- Serialization+Void.swift

---

## 8. swift-time-primitives

### Module: Time Primitives Core

| Type | Kind | File |
|------|------|------|
| `Time` | struct | Time.swift |
| `Time.Error` | enum (Error) | Time.swift |
| `Duration` (= `Swift.Duration`) | typealias | Duration.swift |
| `Instant` | struct | Instant.swift |
| `Instant.Error` | enum (Error) | Instant.swift |
| `Time.Format` | struct | Duration+Format.swift |
| `Time.Format.Unit` | enum | Duration+Format.swift |
| `Time.Format.Notation` | enum | Duration+Format.swift |
| `Time.Calendar` | struct | Time.Calendar.swift |
| `Time.Calendar.Gregorian` | enum | Time.Calendar.Gregorian.swift |
| `Time.Calendar.Gregorian.TimeConstants` | enum | Time.Calendar.Gregorian.swift |
| `Time.Calendar.Gregorian.Easter` | enum (namespace) | Time.Calendar.Gregorian.Easter.swift |
| `Time.Calendar.Gregorian.Easter.Error` | enum (Error) | Time.Calendar.Gregorian.Easter.swift |
| `Time.Epoch` | struct | Time.Epoch.swift |
| `Time.Epoch.Conversion` | enum | Time.Epoch.Conversion.swift |
| `Time.Timezone` | enum (namespace) | Time.Timezone.swift |
| `Time.Timezone.Offset` | struct | Time.Timezone.Offset.swift |
| `Time.Week` | enum (namespace) | Time.Week.swift |
| `Time.Weekday` (= `Time.Week.Day`) | typealias | Time.Week.Day.swift |
| `Time.Week.Day` | enum | Time.Week.Day.swift |
| `Time.Week.Day.Error` | enum (Error) | Time.Week.Day.swift |
| `Time.Month` | struct (RawRepresentable) | Time.Month.swift |
| `Time.Month.Error` | enum (Error) | Time.Month.swift |
| `Time.Month.Day` | struct | Time.Month.Day.swift |
| `Time.Month.Day.Error` | enum (Error) | Time.Month.Day.swift |
| `Time.Year` | struct (RawRepresentable) | Time.Year.swift |
| `Time.Hour` | struct | Time.Hour.swift |
| `Time.Hour.Error` | enum (Error) | Time.Hour.swift |
| `Time.Minute` | struct | Time.Minute.swift |
| `Time.Minute.Error` | enum (Error) | Time.Minute.swift |
| `Time.Second` | struct | Time.Second.swift |
| `Time.Second.Error` | enum (Error) | Time.Second.swift |
| `Time.Millisecond` | struct | Time.Millisecond.swift |
| `Time.Millisecond.Error` | enum (Error) | Time.Millisecond.swift |
| `Time.Microsecond` | struct | Time.Microsecond.swift |
| `Time.Microsecond.Error` | enum (Error) | Time.Microsecond.swift |
| `Time.Nanosecond` | struct | Time.Nanosecond.swift |
| `Time.Nanosecond.Error` | enum (Error) | Time.Nanosecond.swift |
| `Time.Picosecond` | struct | Time.Picosecond.swift |
| `Time.Picosecond.Error` | enum (Error) | Time.Picosecond.swift |
| `Time.Femtosecond` | struct | Time.Femtosecond.swift |
| `Time.Femtosecond.Error` | enum (Error) | Time.Femtosecond.swift |
| `Time.Attosecond` | struct | Time.Attosecond.swift |
| `Time.Attosecond.Error` | enum (Error) | Time.Attosecond.swift |
| `Time.Zeptosecond` | struct | Time.Zeptosecond.swift |
| `Time.Zeptosecond.Error` | enum (Error) | Time.Zeptosecond.swift |
| `Time.Yoctosecond` | struct | Time.Yoctosecond.swift |
| `Time.Yoctosecond.Error` | enum (Error) | Time.Yoctosecond.swift |

Extensions on stdlib types:
- `Swift.Duration` (conversion methods) -- Duration+Conversions.swift
- `Swift.Duration` (format accessor) -- Duration+Format.swift

### Module: Time Julian Primitives

| Type | Kind | File |
|------|------|------|
| `Time.Julian` | enum | Time.Julian.swift |
| `Time.Julian.Space` | enum | Time.Julian.swift |
| `Time.Julian.Day` (= `Coordinate.X<Space>.Value<Double>`) | typealias | Time.Julian.Day.swift |
| `Time.Julian.Offset` (= `Displacement.X<Space>.Value<Double>`) | typealias | Time.Julian.Offset.swift |

Extensions:
- `Tagged where Tag == Coordinate.X<Time.Julian.Space>, RawValue == Double` (constants, properties, Time conversion) -- Time.Julian.Day+Constants.swift, Time.Julian.Day+Properties.swift, Time.Julian.Day+Time.swift
- `Tagged where Tag == Displacement.X<Time.Julian.Space>, RawValue == Double` (constants) -- Time.Julian.Offset+Constants.swift
- `Instant` (Julian day conversion) -- Instant+Julian.swift
- `Time` (from Julian Day) -- Time.Julian.Day+Time.swift

---

## 9. swift-test-primitives

### Module: Test Primitives Core

| Type | Kind | File |
|------|------|------|
| `Test` | enum | Test.swift |
| `Test.ID` | struct | Test.ID.swift |
| `Test.Case` | struct | Test.Case.swift |
| `Test.Case.ID` (= `Tagged<Test.Case, UInt64>`) | typealias | Test.Case.swift |
| `Test.Event` | struct | Test.Event.swift |
| `Test.Event.Kind` (= `Tagged<Test.Event, String>`) | typealias | Test.Event.Kind.swift |
| `Test.Event.Result` | enum | Test.Event.Result.swift |
| `Test.Expectation` | struct | Test.Expectation.swift |
| `Test.Expectation.ID` (= `Tagged<Test.Expectation, UInt64>`) | typealias | Test.Expectation.swift |
| `Test.Expectation.Failure` | struct | Test.Expectation.Failure.swift |
| `Test.Expression` | struct | Test.Expression.swift |
| `Test.Expression.ID` (= `Tagged<Test.Expression, UInt64>`) | typealias | Test.Expression.swift |
| `Test.Expression.Value` | struct | Test.Expression.Value.swift |
| `Test.Issue` | struct | Test.Issue.swift |
| `Test.Issue.Kind` | enum | Test.Issue.Kind.swift |
| `Test.Text` | struct | Test.Text.swift |
| `Test.Text.Segment` | struct | Test.Text.Segment.swift |
| `Test.Text.Segment.Style` | enum | Test.Text.Segment.swift |
| `Test.Trait` | struct | Test.Trait.swift |
| `Test.Trait.Kind` | enum | Test.Trait.Kind.swift |
| `Test.Attachment` | struct | Test.Attachment.swift |
| `Test.Attachment.Collector` | class | Test.Attachment.Collector.swift |
| `Test.Benchmark` | enum (namespace) | Test.Benchmark.swift |
| `Test.Benchmark.Metric` (= `Sample.Metric`) | typealias | Test.Benchmark.swift |
| `Test.Benchmark.Configuration` | struct | Test.Benchmark.Configuration.swift |
| `Test.Benchmark.Error` | enum (Error) | Test.Benchmark.Error.swift |
| `Test.Benchmark.Evaluation` | struct | Test.Benchmark.Evaluation.swift |
| `Test.Benchmark.Iteration` | struct | Test.Benchmark.Iteration.swift |
| `Test.Benchmark.Measurement` | struct | Test.Benchmark.Measurement.swift |
| `Test.Benchmark.Trend` | struct | Test.Benchmark.Trend.swift |
| `Test.Benchmark.Trend.Interpretation` | struct | Test.Benchmark.Trend.swift |
| `Test.Benchmark.Complexity` | enum (namespace) | Test.Benchmark.Complexity.swift |
| `Test.Benchmark.Complexity.Candidate` | enum (namespace) | Test.Benchmark.Complexity.Candidate.swift |
| `Test.Benchmark.Complexity.Candidate.Fit` | struct | Test.Benchmark.Complexity.Candidate.Fit.swift |
| `Test.Benchmark.Complexity.Class` | enum | Test.Benchmark.Complexity.Class.swift |
| `Test.Benchmark.Complexity.Evidence` | struct | Test.Benchmark.Complexity.Evidence.swift |
| `Test.Benchmark.Complexity.Exponent` | struct | Test.Benchmark.Complexity.Exponent.swift |

### Module: Test Snapshot Primitives

| Type | Kind | File |
|------|------|------|
| `Test.Snapshot` | enum (namespace) | Test.Snapshot.swift |
| `Test.Snapshot.Diff` | enum (namespace) | Test.Snapshot.Diff.swift |
| `Test.Snapshot.Diff.Result` | struct | Test.Snapshot.Diff.Result.swift |
| `Test.Snapshot.Diff.Result.StructuralOperation` | enum | Test.Snapshot.Diff.Result.StructuralOperation.swift |
| `Test.Snapshot.Diffing<Format>` | struct (Witness.Protocol) | Test.Snapshot.Diffing.swift |
| `Test.Snapshot.Faceted<Value>` | struct | Test.Snapshot.Faceted.swift |
| `Test.Snapshot.Faceted.Result` | struct | Test.Snapshot.Faceted.Result.swift |
| `Test.Snapshot.Inline` | enum (namespace) | Test.Snapshot.Inline.swift |
| `Test.Snapshot.Recording` | enum | Test.Snapshot.Recording.swift |
| `Test.Snapshot.Redaction<Format>` | struct | Test.Snapshot.Redaction.swift |
| `Test.Snapshot.Result` | enum | Test.Snapshot.Result.swift |
| `Test.Snapshot.Strategy<Value, Format>` | struct (Witness.Protocol) | Test.Snapshot.Strategy.swift |
| `Test.Snapshot.SimplyStrategy<Format>` (= `Strategy<Format, Format>`) | typealias | Test.Snapshot.Strategy.swift |

Strategy factory extensions:
- `Test.Snapshot.Strategy where Value == [UInt8], Format == [UInt8]` -- Test.Snapshot.Strategy+Data.swift
- `Test.Snapshot.Strategy where Value == String, Format == String` -- Test.Snapshot.Strategy+Text.swift
- `Test.Snapshot.Strategy where Format == String` (description) -- Test.Snapshot.Strategy+Description.swift
- `Test.Snapshot.Strategy` (redacting) -- Test.Snapshot.Strategy+Redacting.swift
- `Test.Snapshot.Diffing where Format == [UInt8]` -- Test.Snapshot.Strategy+Data.swift
- `Test.Snapshot.Diffing where Format == String` -- Test.Snapshot.Strategy+Text.swift
- `Test.Snapshot.Diff` (styled output) -- Test.Snapshot.Diff+styled.swift

### Module: Test Primitives Standard Library Integration (internal)

No new named types. Extensions on stdlib types:

| Extension Target | File |
|-----------------|------|
| `Bool: CaseIterable` (retroactive) | Bool+CaseIterable.swift |
| `Bool?: CaseIterable` (retroactive) | BoolOptional+CaseIterable.swift |
| `[(Bool, Bool)]`, `[(Bool, Bool, Bool)]`, ... up to 6-tuples | Bool+CaseIterable.swift |
| `[(Bool?, Bool?)]`, `[(Bool?, Bool?, Bool?)]`, ... up to 6-tuples | BoolOptional+CaseIterable.swift |

---

## Summary

| Package | Core | Variant 2 | Variant 3 | Variant 4 | Variant 5 | Total Types |
|---------|------|-----------|-----------|-----------|-----------|-------------|
| memory-primitives | 16 | Arena: 2 | Pool: 3 | Buffer: 6 | StdLib: 3 tags | 30 |
| bit-vector-primitives | 13 | Static: 5 | Bounded: 10 | Inline: 10 | Dynamic: 6 | 44 |
| binary-primitives | 30+ | Format: 7 | Serializable: 1 | -- | -- | 38+ |
| numeric-primitives | 12 | Real: 3 | Integer: 5 | -- | -- | 20 |
| sequence-primitives | 36 | Difference: 8 | StdLib: 2 | -- | -- | 46 |
| affine-primitives | 7 | StdLib: 0 | -- | -- | -- | 7 |
| serializer-primitives | 4 | Serialization: 10 | -- | -- | -- | 14 |
| time-primitives | 46 | Julian: 4 | -- | -- | -- | 50 |
| test-primitives | 32 | Snapshot: 13 | StdLib: 0 | -- | -- | 45 |
