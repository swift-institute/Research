# Variant Catalog: Parser Banned-Umbrella Packages

Generated: 2026-04-03

This catalog documents every public type in every variant module across four
banned-umbrella packages in swift-primitives. Types are listed in their
`Nest.Name` form. Extensions on external types are listed separately.

---

## 1. swift-parser-primitives

Umbrella module: `Parser Primitives` (re-exports all 35 variants below)

### Core (`Parser Primitives Core`)

| File | Public Type / Protocol |
|------|----------------------|
| Parser.swift | `Parser` (enum, top-level namespace) |
| Parseable.swift | `Parseable` (protocol) |
| Parser.Parser.swift | `Parser.Protocol` (protocol) |
| Parser.Printer.swift | `Parser.Printer` (protocol) |
| Parser.Bidirectional.swift | `Parser.Bidirectional` (protocol) |
| Parser.Builder.swift | `Parser.Builder` (result builder struct) |
| Parser.Input.swift | `Parser.Input` (enum namespace), `Parser.Input.Protocol` (typealias), `Parser.Input.Streaming` (typealias), `Parser.Input.Stream` (typealias), `Parser.Input.Bytes` (typealias), `Parser.Input.Collection` (typealias) |
| Parser.Input.Bytes.swift | extension `Parser.Input.Bytes` (convenience inits) |

Re-exports: `Input_Primitives`, `Collection_Primitives`, `Sequence_Primitives`, `Array_Primitives`

### Error (`Parser Error Primitives`)

| File | Public Type |
|------|------------|
| Parser.Error.swift | `Parser.Error` (enum namespace), `Parser.Error.Transform` (struct) |
| Parser.Error.Located.swift | `Parser.Error.Located` (struct) |
| Parser.Error.Located.Protocol.swift | `__ParserErrorLocatedProtocol` (protocol, canonical path: `Parser.Error.Located.Protocol`) |
| Parser.Error.Map.swift | `Parser.Error.Map` (struct, conforms to `Parser.Protocol`) |
| Parser.Error.Replace.swift | `Parser.Error.Replace` (struct, conforms to `Parser.Protocol`) |
| Parser.Either.swift | `_EitherChain` (protocol), extension `Either` (chain accessors) |

### Match (`Parser Match Primitives`)

| File | Public Type |
|------|------------|
| Parser.Match.swift | `Parser.Match` (enum namespace) |
| Parser.Match.Error.swift | `Parser.Match.Error` (enum) |
| Parser.Protocol+parse.swift | extension `Parser.Protocol` (full-input `parse(_:)` methods) |

### EndOfInput (`Parser EndOfInput Primitives`)

| File | Public Type |
|------|------------|
| Parser.EndOfInput.swift | `Parser.EndOfInput` (enum namespace) |
| Parser.EndOfInput.Error.swift | `Parser.EndOfInput.Error` (enum) |

### Constraint (`Parser Constraint Primitives`)

| File | Public Type |
|------|------------|
| Parser.Constraint.swift | `Parser.Constraint` (enum namespace) |
| Parser.Constraint.Error.swift | `Parser.Constraint.Error` (enum) |

### OneOf (`Parser OneOf Primitives`)

| File | Public Type |
|------|------------|
| Parser.OneOf.swift | `Parser.OneOf` (enum namespace) |
| Parser.OneOf.Two.swift | `Parser.OneOf.Two` (struct, conforms to `Parser.Protocol`) |
| Parser.OneOf.Three.swift | `Parser.OneOf.Three` (struct, conforms to `Parser.Protocol`) |
| Parser.OneOf.Any.swift | `Parser.OneOf.Any` (struct, conforms to `Parser.Protocol`), `Parser.OneOf.Any.Error` (struct) |
| Parser.OneOf.Sequence.swift | `Parser.OneOf.Sequence` (struct, conforms to `Parser.Protocol`) |
| Parser.OneOf.Builder.swift | `Parser.OneOf.Builder` (result builder struct) |

### Map (`Parser Map Primitives`)

| File | Public Type |
|------|------------|
| Parser.Map.swift | `Parser.Map` (enum namespace) |
| Parser.Map.Transform.swift | `Parser.Map.Transform` (struct, conforms to `Parser.Protocol`) |
| Parser.Map.Throwing.swift | `Parser.Map.Throwing` (struct, conforms to `Parser.Protocol`) |
| Parser.Protocol+map.swift | extension `Parser.Protocol` (`map`, `tryMap` methods) |

### FlatMap (`Parser FlatMap Primitives`)

| File | Public Type |
|------|------------|
| Parser.FlatMap.swift | `Parser.FlatMap` (struct, conforms to `Parser.Protocol`) |
| Parser.Protocol+flatMap.swift | extension `Parser.Protocol` (`flatMap` method) |

### Filter (`Parser Filter Primitives`)

| File | Public Type |
|------|------------|
| Parser.Filter.swift | `Parser.Filter` (struct, conforms to `Parser.Protocol`) |
| Parser.Protocol+filter.swift | extension `Parser.Protocol` (`filter` method) |

### Conditional (`Parser Conditional Primitives`)

| File | Public Type |
|------|------------|
| Parser.Conditional.swift | `Parser.Conditional` (enum, conforms to `Parser.Protocol`) |

### Optional (`Parser Optional Primitives`)

| File | Public Type |
|------|------------|
| Parser.Optional.swift | `Parser.Optional` (struct, conforms to `Parser.Protocol` + `Parser.Printer`) |
| Parser.Optionally.swift | `Parser.Optionally` (struct, conforms to `Parser.Protocol`) |

### Skip (`Parser Skip Primitives`)

| File | Public Type |
|------|------------|
| Parser.Skip.swift | `Parser.Skip` (enum namespace) |
| Parser.Skip.First.swift | `Parser.Skip.First` (struct, conforms to `Parser.Protocol`) |
| Parser.Skip.Second.swift | `Parser.Skip.Second` (struct, conforms to `Parser.Protocol`) |

### Many (`Parser Many Primitives`)

| File | Public Type |
|------|------------|
| Parser.Many.swift | `Parser.Many` (enum namespace) |
| Parser.Many.Error.swift | `Parser.Many.Error` (enum) |
| Parser.Many.Simple.swift | `Parser.Many.Simple` (struct, conforms to `Parser.Protocol`) |
| Parser.Many.Separated.swift | `Parser.Many.Separated` (struct, conforms to `Parser.Protocol`) |

### Take (`Parser Take Primitives`)

| File | Public Type |
|------|------------|
| Parser.Take.swift | `Parser.Take` (enum namespace) |
| Parser.Take.Builder.swift | `Parser.Take.Builder` (result builder struct) |
| Parser.Take.Two.swift | `Parser.Take.Two` (struct, conforms to `Parser.Protocol`) |
| Parser.Take.Two.Map.swift | `Parser.Take.Two.Map` (struct, conforms to `Parser.Protocol`) |
| Parser.Take.Sequence.swift | `Parser.Take.Sequence` (struct, conforms to `Parser.Protocol`) |
| Parser.Take.Transform.swift | `Parser.Take.Transform` (struct, conforms to `Parser.Protocol`) |
| Parser.Builder+Take.swift | extension `Parser.Builder` (sequential composition `buildBlock` overloads) |
| Parser.Optionally+Builder.swift | extension `Parser.Optionally` (builder init) |
| Collection.Slice+parse.swift | extension `Collection.Slice.Protocol` (`parse`, `parsing` inline entry points) |

### Consume (`Parser Consume Primitives`)

| File | Public Type |
|------|------------|
| Parser.Consume.swift | `Parser.Consume` (enum namespace) |
| Parser.Consume.Exactly.swift | `Parser.Consume.Exactly` (struct, conforms to `Parser.Protocol`) |

### Discard (`Parser Discard Primitives`)

| File | Public Type |
|------|------------|
| Parser.Discard.swift | `Parser.Discard` (enum namespace) |
| Parser.Discard.Exactly.swift | `Parser.Discard.Exactly` (struct, conforms to `Parser.Protocol`) |

### Prefix (`Parser Prefix Primitives`)

| File | Public Type |
|------|------------|
| Parser.Prefix.swift | `Parser.Prefix` (enum namespace) |
| Parser.Prefix.While.swift | `Parser.Prefix.While` (struct, conforms to `Parser.Protocol`) |
| Parser.Prefix.UpTo.swift | `Parser.Prefix.UpTo` (struct, conforms to `Parser.Protocol`) |
| Parser.Prefix.Through.swift | `Parser.Prefix.Through` (struct, conforms to `Parser.Protocol`) |

### First (`Parser First Primitives`)

| File | Public Type |
|------|------------|
| Parser.First.swift | `Parser.First` (enum namespace) |
| Parser.First.Element.swift | `Parser.First.Element` (struct, conforms to `Parser.Protocol`) |
| Parser.First.Where.swift | `Parser.First.Where` (struct, conforms to `Parser.Protocol`) |

### Tracked (`Parser Tracked Primitives`)

| File | Public Type |
|------|------------|
| Parser.Tracked.swift | `Parser.Tracked` (struct, input wrapper tracking byte offset) |

### Spanned (`Parser Spanned Primitives`)

| File | Public Type |
|------|------------|
| Parser.Spanned.swift | `Parser.Spanned` (struct, value + source span) |

### Span (`Parser Span Primitives`)

| File | Public Type |
|------|------------|
| Parser.Span.swift | `Parser.Span` (struct, conforms to `Parser.Protocol`) |

### Locate (`Parser Locate Primitives`)

| File | Public Type |
|------|------------|
| Parser.Locate.swift | `Parser.Locate` (struct, conforms to `Parser.Protocol`) |

### Peek (`Parser Peek Primitives`)

| File | Public Type |
|------|------------|
| Parser.Peek.swift | `Parser.Peek` (struct, conforms to `Parser.Protocol`) |

### Not (`Parser Not Primitives`)

| File | Public Type |
|------|------------|
| Parser.Not.swift | `Parser.Not` (struct, conforms to `Parser.Protocol`), `Parser.Not.Error` (enum) |

### Always (`Parser Always Primitives`)

| File | Public Type |
|------|------------|
| Parser.Always.swift | `Parser.Always` (struct, conforms to `Parser.Protocol` + `Parser.Printer`) |

### Fail (`Parser Fail Primitives`)

| File | Public Type |
|------|------------|
| Parser.Fail.swift | `Parser.Fail` (struct, conforms to `Parser.Protocol`) |

### Rest (`Parser Rest Primitives`)

| File | Public Type |
|------|------------|
| Parser.Rest.swift | `Parser.Rest` (struct, conforms to `Parser.Protocol`) |

### End (`Parser End Primitives`)

| File | Public Type |
|------|------------|
| Parser.End.swift | `Parser.End` (struct, conforms to `Parser.Protocol` + `Parser.Printer`) |

### Lazy (`Parser Lazy Primitives`)

| File | Public Type |
|------|------------|
| Parser.Lazy.swift | `Parser.Lazy` (struct, conforms to `Parser.Protocol`) |

### Trace (`Parser Trace Primitives`)

| File | Public Type |
|------|------------|
| Parser.Trace.swift | `Parser.Trace` (struct, conforms to `Parser.Protocol`) |

### Backtrack (`Parser Backtrack Primitives`)

| File | Public Type |
|------|------------|
| Parser.Backtrack.swift | `Parser.Backtrack` (struct, conforms to `Effect.Protocol`) |

### Parse (`Parser Parse Primitives`)

| File | Public Type |
|------|------------|
| Parser.Parse.swift | `Parser.Parse` (struct, nested accessor for parse variants) |

### Byte (`Parser Byte Primitives`)

| File | Public Type |
|------|------------|
| Parser.Byte.swift | `Parser.Byte` (struct, conforms to `Parser.Protocol`) |

### Literal (`Parser Literal Primitives`)

| File | Public Type |
|------|------------|
| Parser.Literal.swift | `Parser.Literal` (struct, conforms to `Parser.Protocol` + `Parser.Printer`) |

### Conformance (`Parser Conformance Primitives`)

| File | Public Type |
|------|------------|
| Parser.Array+Parser.swift | extension `Swift.Array: Parser.Protocol` (where `Element: Equatable`), extension `Swift.Array: Parser.Printer` |
| Parser.String+Parser.swift | extension `String: Parser.Protocol`, extension `String: Parser.Printer` |

---

## 2. swift-parser-machine-primitives

Umbrella module: `Parser Machine Primitives` (re-exports all 5 variants below)

### Parser Machine Core (`Parser Machine Core Primitives`)

| File | Public Type |
|------|------------|
| Parser.Machine.swift | `Parser.Machine` (enum namespace), `Parser.Machine.Value` (typealias to `Machine.Value<Mode.Reference>`), `Parser.Machine.Transform` (typealias), `Parser.Machine.Combine` (typealias), `Parser.Machine.Finalize` (typealias), `Parser.Machine.Next` (typealias), `Parser.Machine.Parser` (struct, conforms to `Parser.Protocol`), `Parser.Machine.Reference` (struct), `Parser.Machine.Mode` (typealias), `Parser.Machine.Builder` (struct, `~Copyable`), `Parser.Machine.Expression` (struct) |
| Parser.Machine.Node.swift | `Parser.Machine.Node` (typealias to `Machine.Node<Leaf, Failure, Mode.Reference>`), `Parser.Machine.Leaf` (struct) |
| Parser.Machine.Program.swift | `Parser.Machine.Program` (typealias to `Machine.Program<Leaf, Failure, Mode.Reference>`) |
| Parser.Machine.Frame.swift | `Parser.Machine.Frame` (typealias to `Machine.Frame<...>`), `Parser.Machine.Extra` (enum) |
| Parser.Machine.Leaf.swift | extension `Parser.Machine` (`leaf` static factory methods) |
| Parser.Machine.Run.swift | extension `Parser.Machine` (`run` package-scoped static method) |
| Parser.Machine.Runtime.swift | `Parser.Machine.Runtime` (package enum), `Parser.Machine.Runtime.Error` (package enum) |
| Parser.Machine.Failure.swift | `Parser.Machine.Failure` (package enum), `Parser.Machine.Failure.Recovery` (package enum) |

Re-exports: `Parser_Primitives`, `Tagged_Primitives`, `Machine_Primitives`, `Stack_Primitives`, `Slab_Primitives`

### Memoization (`Parser Machine Memoization Primitives`)

| File | Public Type |
|------|------------|
| Parser.Machine.Memoization.swift | `Parser.Machine.Memoization` (enum namespace) |
| Parser.Machine.Memoization.Edit.swift | `Parser.Machine.Memoization.Edit` (struct) |
| Parser.Machine.Memoization.Entry.swift | `Parser.Machine.Memoization.Entry` (package enum) |
| Parser.Machine.Memoization.Key.swift | `Parser.Machine.Memoization.Key` (package struct) |
| Parser.Machine.Memoization.Table.swift | `Parser.Machine.Memoization.Table` (package struct) |
| Parser.Machine.Run.Memoization.swift | extension `Parser.Machine` (memoized `run` static method) |

### Compile (`Parser Machine Compile Primitives`)

| File | Public Type |
|------|------------|
| Parser.Machine.Compile.Witness.swift | `Parser.Machine.Compile` (enum namespace), `Parser.Machine.Compile.Witness` (struct) |
| Parser.Machine.Compiled.swift | `Parser.Machine.Compiled` (struct, lazy-compiling parser wrapper) |
| Parser.Machine.Prepared.swift | `Parser.Machine.Prepared` (struct, immutable pre-compiled parser) |

### Combinator (`Parser Machine Combinator Primitives`)

| File | Public Type |
|------|------------|
| Parser.Machine.Combinators.swift | extension `Parser.Machine` (`pure` static method), extension `Parser.Machine.Expression` (`map`, `tryMap`, `flatMap`, `sequence`, `oneOf`, `many`, `fold`, `optional` combinators) |
| Parser.Machine.Recursive.swift | extension `Parser.Machine` (`recursive` static method) |

### Parse (`Parser Machine Parse Primitives`)

| File | Public Type |
|------|------------|
| Parser.Machine.Parser+Compiled.swift | extension `Parser.Parse` (`compiled(using:)`, `prepared(using:)` methods) |
| Parser.Machine.Parser.Parse.swift | `Parser.Machine.Parser.Parse` (struct, accessor for execution variants) |
| Parser.Machine.Parser.Parse.Incremental.swift | `Parser.Machine.Parser.Parse.Incremental` (struct, memoized execution context) |

---

## 3. swift-machine-primitives

Umbrella module: `Machine Primitives` (re-exports all 11 variants below + `Graph_Primitives`)

### Core (`Machine Primitives Core`)

| File | Public Type |
|------|------------|
| Machine.swift | `Machine` (enum, top-level namespace) |
| Machine.Capture.swift | `Machine.Capture` (enum namespace) |
| Machine.Capture.Mode.swift | `Machine.Capture.Mode` (enum namespace) |
| Machine.Capture.Mode.Reference.swift | `Machine.Capture.Mode.Reference` (struct, `Sendable`) |
| Machine.Capture.Mode.Unchecked.swift | `Machine.Capture.Mode.Unchecked` (struct, intentionally not `Sendable`) |

Re-exports: `Graph_Primitives_Core`

### Value (`Machine Value Primitives`)

| File | Public Type |
|------|------------|
| Machine.Value.swift | `Machine.Value` (struct, type-erased value container) |
| Machine.Value.Handle.swift | `Machine.Value._MachineValueArenaTag` (enum, phantom type), `Machine.Value.Handle` (typealias to `Handle_Primitives.Handle<_MachineValueArenaTag>`) |
| Machine.Value.Arena.swift | `Machine.Value.Arena` (struct, `~Copyable`, slot-based arena) |

### Capture (`Machine Capture Primitives`)

| File | Public Type |
|------|------------|
| Machine.Capture.Slot.swift | `Machine.Capture.Slot` (struct, table-based erased storage) |
| Machine.Capture.RawID.swift | `Machine.Capture.RawID` (struct) |
| Machine.Capture.ID.swift | `Machine.Capture.ID` (struct, typed capture identifier) |
| Machine.Capture.Store.swift | `Machine.Capture.Store` (struct, mutable capture storage) |
| Machine.Capture.Store+Reference.swift | extension `Machine.Capture.Store` (Reference mode: `insert`, `with` methods) |
| Machine.Capture.Store+Unchecked.swift | extension `Machine.Capture.Store` (Unchecked mode: `insert`, `with` methods) |
| Machine.Capture.Frozen.swift | `Machine.Capture.Frozen` (struct, immutable capture snapshot) |
| Machine.Capture.Frozen+Reference.swift | extension `Machine.Capture.Frozen` (Reference mode: `with`, `withRaw` methods) |
| Machine.Capture.Frozen+Unchecked.swift | extension `Machine.Capture.Frozen` (Unchecked mode: `with`, `withRaw` methods) |

### Transform (`Machine Transform Primitives`)

| File | Public Type |
|------|------------|
| Machine.Transform.swift | `Machine.Transform` (enum namespace) |
| Machine.Transform.Erased.swift | `Machine.Transform.Erased` (struct, type-erased non-throwing transform) |
| Machine.Transform.Throwing.swift | `Machine.Transform.Throwing` (struct, type-erased throwing transform) |

### Combine (`Machine Combine Primitives`)

| File | Public Type |
|------|------------|
| Machine.Combine.swift | `Machine.Combine` (enum namespace) |
| Machine.Combine.Erased.swift | `Machine.Combine.Erased` (struct, type-erased binary combination) |

### Next (`Machine Next Primitives`)

| File | Public Type |
|------|------------|
| Machine.Next.swift | `Machine.Next` (enum namespace) |
| Machine.Next.Erased.swift | `Machine.Next.Erased` (struct, type-erased next-node selection) |

### Finalize (`Machine Finalize Primitives`)

| File | Public Type |
|------|------------|
| Machine.Finalize.swift | `Machine.Finalize` (enum namespace) |
| Machine.Finalize.Array.swift | `Machine.Finalize.Array` (struct, type-erased array finalization) |

### Frame (`Machine Frame Primitives`)

| File | Public Type |
|------|------------|
| Machine.Frame.swift | `Machine.Frame` (enum, stack frame with cases: `map`, `tryMap`, `flatMap`, `sequence`, `oneOf`, `many`, `fold`, `optional`, `recursiveExit`, `extra`) |
| Machine.Frame.Sequence.swift | `Machine.Frame.Sequence` (enum, sequence continuation state) |

### Node (`Machine Node Primitives`)

| File | Public Type |
|------|------------|
| Machine.Node.swift | `Machine.Node` (enum, program graph node with cases: `leaf`, `pure`, `map`, `tryMap`, `flatMap`, `sequence`, `oneOf`, `many`, `fold`, `optional`, `ref`, `hole`), `Machine.Node.ID` (typealias to `Graph.Node<Self>`) |

### Program (`Machine Program Primitives`)

| File | Public Type |
|------|------------|
| Machine.Program.swift | `Machine.Program` (struct, immutable program containing graph + captures) |
| Machine.Program.Builder.swift | `Machine.Builder` (struct, `~Copyable`, mutable program builder) |

### Convenience (`Machine Convenience Primitives`)

| File | Public Type |
|------|------------|
| Machine.Builder+Carriers.swift | extension `Machine.Builder` (Reference mode: `transform`, `throwingTransform`, `combine`, `next`, `finalize` factory methods) |
| Machine.Program+Apply.swift | extension `Machine.Program` (`apply`, `combine`, `selectNext`, `finalize` convenience methods) |

---

## 4. swift-binary-parser-primitives

Umbrella module: `Binary Parser Primitives` (re-exports all 9 variants below + `Binary_Primitives` + `Parser_Primitives`)

### Core (`Binary Parser Primitives Core`)

Re-exports only: `Binary_Primitives`, `Parser_Primitives`. No types defined in this module.

### Input (`Binary Input Primitives`)

| File | Public Type |
|------|------------|
| Binary.Bytes.Input.swift | `Binary.Bytes.Input` (struct, `Sendable`, owned byte cursor) |
| Binary.Bytes.Input+init.swift | extension `Binary.Bytes.Input` (collection/array/slice inits) |
| Binary.Bytes.Input+properties.swift | extension `Binary.Bytes.Input` (`count`, `isEmpty`, `consumedCount`, `first` properties) |
| Binary.Bytes.Input+mutation.swift | extension `Binary.Bytes.Input` (`advance()`, `advance(by:)` methods) |
| Binary.Bytes.Input+subscript.swift | extension `Binary.Bytes.Input` (`subscript(offset:)`, `starts(with:)`) |
| Binary.Bytes.Input+Input.Protocol.swift | extension `Binary.Bytes.Input: Input.Protocol` (conformance + `Input.Access.Random`) |

### Input View (`Binary Input View Primitives`)

| File | Public Type |
|------|------------|
| Binary.Bytes.Input.View.swift | `Binary.Bytes.Input.View` (struct, `~Copyable & ~Escapable`, borrowed byte cursor over `Span<UInt8>`) |
| Binary.Bytes.Input.View+typed.swift | extension `Binary.Bytes.Input.View` (typed index subscript) |

### Machine (`Binary Machine Primitives`)

| File | Public Type |
|------|------------|
| Binary.Bytes.Machine.swift | `Binary.Bytes.Machine` (enum namespace), `Binary.Bytes.Machine.Value` (typealias), `Binary.Bytes.Machine.Transform` (typealias), `Binary.Bytes.Machine.Combine` (typealias), `Binary.Bytes.Machine.Finalize` (typealias), `Binary.Bytes.Machine.Next` (typealias) |
| Binary.Bytes.Machine.Instruction.swift | `Binary.Bytes.Machine.Instruction` (enum, closed-world instruction set: `take1`, `take`, `skip`, `peek`, `byte`, `bytes`, `satisfy`, `takeWhile`, `skipWhile`, `end`, `leb128Unsigned`, `leb128Signed`) |
| Binary.Bytes.Machine.Error.swift | `Binary.Bytes.Machine.Fault` (enum, machine execution errors) |
| Binary.Bytes.Machine.Node.swift | `Binary.Bytes.Machine.Node` (typealias to `Machine.Node<Instruction, Fault, Mode.Reference>`) |
| Binary.Bytes.Machine.Program.swift | `Binary.Bytes.Machine.Program` (typealias to `Machine.Program<Instruction, Fault, Mode.Reference>`) |
| Binary.Bytes.Machine.Frame.swift | `Binary.Bytes.Machine.Checkpoint` (typealias to `Index<UInt8>`), `Binary.Bytes.Machine.Frame` (typealias to `Machine.Frame<..., Never>`) |
| Binary.Bytes.Machine.Builder.swift | `Binary.Bytes.Machine.Mode` (typealias), `Binary.Bytes.Machine.Builder` (struct, `~Copyable`), `Binary.Bytes.Machine.Expression` (struct), `Binary.Bytes.Machine.Reference` (struct) |
| Binary.Bytes.Machine.Build.swift | `Binary.Bytes.Machine.Parser` (struct), extension `Binary.Bytes.Machine` (`build`, `recursive` static methods) |
| Binary.Bytes.Machine.Combinators.swift | extension `Binary.Bytes.Machine` (combinator factory methods: `take1`, `take`, `skip`, `byte`, `bytes`, `satisfy`, `takeWhile`, `skipWhile`, `end`, `leb128Unsigned`, `leb128Signed`), extension `Binary.Bytes.Machine.Expression` (`map`, `tryMap`, `flatMap`, `sequence`, `oneOf`, `many`, `fold`, `optional` combinators) |
| Binary.Bytes.Machine.Parsers.swift | extension `Binary.Bytes.Machine` (pre-built parser factories: `u8Parser`, `u16leParser`, `u16beParser`, `u32leParser`, `u32beParser`, `u64leParser`, `u64beParser`, `i8Parser`, `i16leParser`, `i16beParser`, `i32leParser`, `i32beParser`, `i64leParser`, `i64beParser`) |
| Binary.Bytes.Machine.Run.swift | extension `Binary.Bytes.Machine` (`run` static method, owned-path executor) |

### Borrowed (`Binary Borrowed Primitives`)

| File | Public Type |
|------|------------|
| Binary.Bytes.withBorrowed.swift | `Binary.Bytes.WithBorrowed` (struct, `Sendable`), extension `Binary.Bytes` (`withBorrowed` static accessor), inlined interpreter for `Input.View` |

### Parse (`Binary Parse Primitives`)

| File | Public Type |
|------|------------|
| Binary.Parse.Access.swift | `Binary.Parse.Access` (struct, nested accessor for `.parse.whole` / `.parse.prefix`) |
| Binary.Parse.Access+whole.swift | extension `Binary.Parse.Access` (`whole` method) |
| Binary.Parse.Access+prefix.swift | extension `Binary.Parse.Access` (`prefix` method) |
| Binary.Parse.Converting.swift | `Binary.Parse.Converting` (struct, conforms to `Parser.Protocol`), `Binary.Parse.Converting.Error` (enum) |
| Binary.Parse.Validated.swift | `Binary.Parse.Validated` (struct, conforms to `Parser.Protocol`), `Binary.Parse.Validated.Error` (enum) |
| Binary.Parse.Variable.swift | `Binary.Parse.Variable` (struct, conforms to `Parser.Protocol`) |

Note: `Binary.Parse` (enum namespace) and `Binary.Parse.Error` (enum) are defined upstream in `Binary Primitives Core` (swift-binary-primitives), re-exported here.

### LEB128 (`Binary LEB128 Primitives`)

| File | Public Type |
|------|------------|
| Binary.LEB128.Signed.swift | `Binary.LEB128.Signed` (struct, conforms to `Parser.Protocol`) |
| Binary.LEB128.Unsigned.swift | `Binary.LEB128.Unsigned` (struct, conforms to `Parser.Protocol`) |

Note: `Binary.LEB128` (enum namespace) and `Binary.LEB128.Error` (enum) are defined upstream in `Binary Primitives Core` (swift-binary-primitives), re-exported here.

### Coder (`Binary Coder Primitives`)

| File | Public Type |
|------|------------|
| Binary.Coder.swift | `Binary.Coder` (struct, witness-based bidirectional coder, conforms to `Witness.Protocol`) |
| Binary.Coder+Coder.Protocol.swift | extension `Binary.Coder: Coder.Protocol` |

### Integer (`Binary Integer Primitives`)

| File | Public Type |
|------|------------|
| Binary.Parse.Inline.swift | `Binary.Parse.Inline` (struct, conforms to `Parser.Protocol`, fixed-size `InlineArray` parser) |
| InlineArray+Binary.swift | extension `InlineArray` (parsing initializer, where `Element: FixedWidthInteger`) |
| UInt8+Parser.swift | extension `UInt8` (`coder(endianness:)` static method) |
| UInt16+Parser.swift | extension `UInt16` (`coder(endianness:)` static method) |
| UInt32+Parser.swift | extension `UInt32` (`coder(endianness:)` static method) |
| UInt64+Parser.swift | extension `UInt64` (`coder(endianness:)` static method) |
| Int8+Parser.swift | extension `Int8` (`coder(endianness:)` static method) |
| Int16+Parser.swift | extension `Int16` (`coder(endianness:)` static method) |
| Int32+Parser.swift | extension `Int32` (`coder(endianness:)` static method) |
| Int64+Parser.swift | extension `Int64` (`coder(endianness:)` static method) |
| Parser.Parser+parse.swift | extension `Parser.Protocol` (`parse` accessor returning `Binary.Parse.Access`, where `Input == Binary.Bytes.Input`) |
