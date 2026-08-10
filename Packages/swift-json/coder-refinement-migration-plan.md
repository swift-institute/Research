# Coder.Protocol → Parser.Protocol + Serializer.Protocol Refinement Migration Plan

**Date**: 2026-05-14
**Author**: Phase C1 (design only)
**Convention**: [FAM-006] in `family-codable-convention.md` v1.1.2 §3a
**Status**: PLAN — ready for Phase C2 execution

---

## Summary of structural change

Today (`swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift:45–86`):

```swift
public protocol `Protocol`<DecodeInput, EncodeBuffer, Output>: ~Copyable {
    associatedtype DecodeInput: ~Copyable & ~Escapable
    associatedtype EncodeBuffer
    associatedtype Output
    associatedtype DecodeFailure: Swift.Error
    associatedtype EncodeFailure: Swift.Error
    borrowing func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> Output
    borrowing func encode(_ output: Output, into buffer: inout EncodeBuffer) throws(EncodeFailure)
}
```

Target ([FAM-006]):

```swift
public protocol `Protocol`: Parser.`Protocol`, Serializer.`Protocol` { }
```

Same-name unification across the refinement folds:

| Today (Coder.Protocol)         | After ([FAM-006])         | Unification origin |
|--------------------------------|---------------------------|--------------------|
| `DecodeInput`                  | `Input` (Parser)          | inherited rename — semantic change |
| `EncodeBuffer`                 | `Buffer` (Serializer)     | inherited rename — semantic change |
| `Output`                       | `Output`                  | Parser.Output ≡ Serializer.Output (the codec value) |
| `DecodeFailure`, `EncodeFailure` | **one** `Failure`       | Parser.Failure ≡ Serializer.Failure |
| (none)                         | `Body: ~Copyable`         | inherited — defaults to `Never` for leaf coders |
| `decode(_:) -> Output`         | `parse(_:) -> Output`     | Parser's method name |
| `encode(_:into:)`              | `serialize(_:into:)`      | Serializer's method name |

Two method renames AND two associated-type renames are required at the protocol level. The `Failure` collapse is the v1.1.2 §3a focus.

---

## Section 1: Caller survey

Ecosystem-wide grep on `/Users/coen/Developer` (excluding `.build/`, `.git/`, `Experiments/`) for:
- `JSON.Coder`, `JSON.Coder().decode`, `JSON.Coder().encode`
- `Binary.Coder…decode`, `Binary.Coder…encode`
- `RFC_8259.Value(decoding:`, `.encoded()` paired with `RFC_8259.Value`
- Catches of `RFC_8259.Error`, `JSON.Encode.Error`, `Binary.Bytes.Machine.Fault` from a Coder path

### Pattern legend
- **(a) Generic-protocol caller** — over `Coder.Protocol` constraint. Minimal impact: renames at the protocol propagate via the same-name unification; explicit type writes need updating.
- **(b) Canonical-attachment shape** — `var coder: Coder`, `init(decoding:)`, `encoded()` via `Codable` extension. Affected only via `Codable.swift` internal-references update.
- **(c) Direct caller** — `JSON.Coder().decode(_:)` or `Binary.Coder…decode(_:)` going through Coder.Protocol method names. Hit by **both** method renames AND `Failure`-type collapse.

### Results

#### JSON.Coder

| File:Line | Pattern | Notes |
|-----------|---------|-------|
| `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:68–106` | declaration | The Coder.Protocol conformance itself — Phase C2 target. |
| `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:110–116` | declaration | The `RFC_8259.Value: @retroactive Coder_Primitives.Codable` conformance. Phase C2 target. |
| `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift:24–25` | doc-comment | `RFC_8259.Value(decoding: &input)` + `value.encoded()` in DocC example. No code change needed, but doc text references method names. |
| `swift-foundations/swift-json/Sources/JSON/JSON.Encode.swift:25` | doc-comment | `JSON.Coder(encodeOptions:)` + `coder.encode(value)` in DocC example. Doc text only. |
| `swift-foundations/swift-json/Sources/JSON/JSON.Decode.swift:24` | doc-comment | `RFC_8259.Value(decoding: &span)`. Doc text only. |
| `swift-foundations/swift-json/Sources/JSON/JSON.Decode.Implementation.swift:16,35` | doc-comment | References "JSON.Coder.decode" by name. Doc text only. |
| `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:13,28,35,58` | doc-comment | Multiple comment references to `JSON.Coder()` and `coder = JSON.Coder()`. Doc text only. |
| `swift-foundations/swift-json/Tests/JSON Tests/Round-Trip Tests.swift:9` | suite-namespace only | `extension JSON.Coder { @Suite("Round-Trip Tests") struct Tests { ... } }`. Tests themselves call `JSON.Decode.parse(_:)` / `JSON.Encode.encode(_:)` (the `JSON.Serializable` sibling-protocol surface) — **NOT** `JSON.Coder().decode(_:)`. Suite namespace is unaffected by the refinement. |
| `swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.swift:14`, `RFC_8259.Pull.swift:26` | doc-comment | Cross-package doc references to `JSON.Coder`. No code change. |

**Pattern (c) direct callers: ZERO.** No live code calls `JSON.Coder().decode(_:)` or `JSON.Coder().encode(_:into:)`. All Coder.Protocol exercise goes through the canonical-attachment shape (pattern b) — which is itself only declared, not consumed, outside the package.

**Pattern (b) callers in live code: ZERO.** `RFC_8259.Value(decoding:)` and `.encoded()` appear only in DocC examples. No production code or test invokes them.

**Pattern (a) callers: ONE.** `swift-coder-primitives/Sources/Coder Primitives/Codable.swift:36,43,52,59,66` — the default-implementation extensions over `Codable where Coder.Output == Self`. These reference `Coder.DecodeInput`, `Coder.EncodeBuffer`, `Coder.DecodeFailure`, `Coder.EncodeFailure` — all four renamed associated-type slots. Must be updated.

#### Binary.Coder

| File:Line | Pattern | Notes |
|-----------|---------|-------|
| `swift-primitives/swift-binary-coder-primitives/Sources/Binary Coder Primitives/Binary.Coder+Coder.Protocol.swift:10–25` | declaration | The Coder.Protocol conformance. Phase C2 target. |
| `swift-primitives/swift-binary-coder-primitives/Sources/Binary Coder Primitives/Binary.Coder.swift:43–60` | declaration | The base `Binary.Coder<Output>: Witness.Protocol` struct, with **stored closures** `decode:` and `encode:`. These are NOT the Coder.Protocol methods — they are stored properties used by the `decodeWhole`/`decodePrefix`/`encodeToArray` helpers. **Unaffected by Coder.Protocol refinement** since those helpers do not go through the protocol method-name surface. |
| `swift-primitives/swift-binary-coder-primitives/Sources/Binary Coder Primitives/Binary.Coder.swift:71,86,95,107` | helpers | `decodeWhole`/`decodePrefix`/`encodeToArray`/`encodeAppending` — all invoke the stored-closure properties `self.decode` and `self.encode` directly. These survive the protocol method renames intact. |
| `swift-primitives/swift-binary-coder-primitives/Sources/Binary Integer Coder Primitives/{UInt8,UInt16,UInt32,UInt64,Int8,Int16,Int32,Int64}+Coder.swift` (8 files) | construction | Build `Binary.Coder<T>` via `Binary.Coder.machine(...)` — passes closures into the stored properties. Unaffected. |
| `swift-primitives/swift-binary-coder-primitives/Tests/Binary Coder Primitives Tests/Binary.Coder Tests.swift` (15 sites) | tests | All use `coder.decodeWhole(_:)` / `coder.decodePrefix(_:)` / `coder.encodeToArray(_:)` / direct `Binary.Coder<Void>(decode:, encode:)` constructor calls. Unaffected. |
| `swift-primitives/swift-binary-coder-primitives/Tests/Binary Coder Primitives Tests/Integer Coder Tests.swift` (≈30 sites) | tests | Same pattern — `decodeWhole` only. Unaffected. |

**Pattern (c) direct callers via Coder.Protocol method surface: ZERO.** The `decode` and `encode` members visible to Binary.Coder callers are stored closures (Witness.Protocol shape), not the Coder.Protocol's required `decode(_:)` and `encode(_:into:)` methods. There's a name collision risk worth flagging: after refinement the protocol requires methods named `parse(_:)` and `serialize(_:into:)`. The conformance in `Binary.Coder+Coder.Protocol.swift:17,22` currently provides them under the names `decode(_:)` and `encode(_:into:)` AND calls `self.decode(&input)` / `self.encode(output, &buffer)` (the stored-closure properties). Rename of the protocol-required methods to `parse`/`serialize` means the witness no longer shadows the stored-closure name — eliminating a subtle internal collision. **Net: the rename clarifies, doesn't break.**

#### Coder.Protocol generic surface (pattern a)

| File:Line | Pattern | Notes |
|-----------|---------|-------|
| `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:28` | attachment | `associatedtype Coder: Coder_Primitives.Coder.Protocol`. Unchanged — the bound stays the same. |
| `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:36–55` | extension | `extension Codable where Coder.Output == Self`. References `Coder.EncodeBuffer` (line 43), `Coder.EncodeFailure` (line 43), `Coder.DecodeInput` (line 52), `Coder.DecodeFailure` (line 52). Method body calls `Self.coder.encode(self, into: &buffer)` (line 44) and `Self.coder.decode(&input)` (line 53). **All four typealiases + both method names need updating.** |
| `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:59–69` | extension | `extension Codable where Coder.Output == Self, Coder.EncodeBuffer: RangeReplaceableCollection`. References `Coder.EncodeFailure` (line 66). Method body calls `Self.coder.encode(self)` (line 67). Updates needed. |
| `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift:90–107` | extension | The "Buffer-constructing encode convenience" extension on `Coder.Protocol where EncodeBuffer: RangeReplaceableCollection`. References `EncodeBuffer`, `EncodeFailure`, calls `encode(_:into:)`. After refinement this entire extension is **redundant** — `Serializer.Protocol`'s default extension at `Serializer.Protocol.swift:116–128` already provides `serialize(_:) -> Buffer` for the same constraint. Should be deleted. |

### Surprise findings flagged

1. **No live callers at the Coder.Protocol surface.** Both the `init(decoding:)` and `encoded()` canonical-attachment APIs (pattern b) and the direct `JSON.Coder().decode/.encode` APIs (pattern c) are documented but unused outside doc-comment examples. The caller-side impact of [FAM-006] is therefore **far smaller than v1.1.2 §3a's caller-ergonomic discussion anticipated** — at this point in the ecosystem, the refinement is essentially internal to swift-coder-primitives + the two conformer files.
2. **Binary.Coder's `decode`/`encode` are stored closures, not protocol methods.** This is a structural detail v1.1.2 §3a doesn't model. The refinement renames the protocol methods to `parse`/`serialize`, removing a latent name-shadowing problem inside Binary.Coder+Coder.Protocol.swift (the conformance method `decode(_:)` today shadows the stored-property `decode:`; after rename, this is gone).
3. **`Body: ~Copyable` unifies, but default-Never extensions kick in.** Both Parser.Protocol and Serializer.Protocol inherit a `Body: ~Copyable` slot, and both supply `where Body == Never` leaf-default extensions (Parser.Parser.swift:130–138; Serializer.Protocol.swift:87–95). Same-name unification gives Coder.Protocol one `Body` slot; conformers leave it implicit (`Never`), and both protocols' Never-default `body { fatalError(...) }` extensions are satisfied simultaneously. **No class-(c) blocker** — `Never` satisfies both `Body: ~Copyable` slots.
4. **The `@Parser.Builder<Input>` / `@Serializer.Builder<Buffer>` property-wrappers on `body`** are only a problem if a Coder author overrides `body`. Per v1.1.0 framing (`project_parser_serializer_coder_system_framing`), Coder is a leaf type with NO Body/Builder by design — codecs do NOT override `body`. So the doubled property-wrapper issue is structurally inert in this ecosystem.
5. **No public dependent that catches `RFC_8259.Error` or `JSON.Encode.Error` specifically from the Coder.Protocol path.** All `RFC_8259.Error` catches in tests (`JSON.Pull.Stream Tests.swift`) are on the `RFC_8259.Pull` parser path, not the Coder. `JSON.Encode.Error` is throw-typed inside `JSON.Coder.encode` but not caught downstream in current code.

---

## Section 2: Per-conformer migration choice

### JSON.Coder → **Option 2 (Accept `Either<DecodeFailure, EncodeFailure>`)**

```swift
extension JSON.Coder: Coder_Primitives.Coder.`Protocol` {
    public typealias Input   = Swift.Span<UInt8>
    public typealias Buffer  = [UInt8]
    public typealias Output  = RFC_8259.Value
    public typealias Failure = Either<RFC_8259.Error, JSON.Encode.Error>
    // ...
}
```

**Reasoning** (one sentence): With zero pattern-(c) and zero pattern-(b) live callers and only one pattern-(a) caller (Codable.swift's own internal extension), the caller-side `Either<D, E>` ergonomic cost predicted by v1.1.2 §3a is **not actually paid** in this ecosystem, while option 1 (umbrella `JSON.Error` enum) would force a breaking error-type API change rippling through swift-json's published surface (the existing public types `RFC_8259.Error` and `JSON.Encode.Error` are useful as distinct types for their respective directions; collapsing them is a semantic loss). Option 3 (view accessors) is unnecessary given the absence of callers. Pick option 2: lowest semantic disruption, zero caller-side fallout today.

### Binary.Coder → **Option 2 (Accept `Either<DecodeFailure, EncodeFailure>`)**

```swift
extension Binary.Coder: Coder.`Protocol` {
    public typealias Input   = Binary.Bytes.Input
    public typealias Buffer  = [UInt8]
    public typealias Failure = Either<Binary.Bytes.Machine.Fault, Never>
    // ...
}
```

**Reasoning** (one sentence): `EncodeFailure == Never` triggers the `Either<Fault, Never>.value` collapse via `Either+Never.swift:35–44`, so the unified `Failure` reads at use sites as effectively-`Fault` through the `.value` accessor — option 2 is free here, and matches the v1.1.2 §3a paragraph about Never-collapse cleanliness.

(For both: the rationale tracks the convention's suggested heuristic given the caller-pattern survey.)

---

## Section 3: Concrete source-change plan

### Files to modify (count = **5 source files** + **1 test file** for doc-comment refresh = 6 total; the Binary.Coder test files DO NOT need code changes because they never touch the Coder.Protocol surface)

#### File 1: `/Users/coen/Developer/swift-primitives/swift-coder-primitives/Package.swift`

- **Change kind**: deps
- **Before**: (lines 24–37) target has no dependencies; no `dependencies:` array on `let package =` either.
- **After**: Add three deps to the package `dependencies:` array and to the `Coder Primitives` target's `dependencies:`:
  ```swift
  dependencies: [
      .package(path: "../swift-parser-primitives"),
      .package(path: "../swift-serializer-primitives"),
      .package(path: "../swift-either-primitives"),
  ],
  ```
  And in the `.target(name: "Coder Primitives", ...)`:
  ```swift
  dependencies: [
      .product(name: "Parser Primitives Core", package: "swift-parser-primitives"),
      .product(name: "Serializer Primitives Core", package: "swift-serializer-primitives"),
      .product(name: "Either Primitives", package: "swift-either-primitives"),
  ],
  ```
  (Product names to be verified against each package's `Package.swift` `products:` declaration; the natural reading of the L1 catalog is `Parser Primitives Core` and `Serializer Primitives Core` for the core Parser.Protocol / Serializer.Protocol declarations, and `Either Primitives` for swift-either-primitives — Phase C2 should confirm before writing.)

#### File 2: `/Users/coen/Developer/swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift`

- **Change kind**: declaration (collapse to refinement)
- **Before** (lines 45–86): the full split declaration with `DecodeInput`, `EncodeBuffer`, `Output`, `DecodeFailure`, `EncodeFailure`, `decode(_:)`, `encode(_:into:)`.
- **After**:
  ```swift
  public import Parser_Primitives_Core
  public import Serializer_Primitives_Core

  extension Coder {
      /// A type that can both decode (parse) and encode (serialize) a value.
      ///
      /// `Coder.Protocol` refines `Parser.Protocol` and `Serializer.Protocol`
      /// per [FAM-006]: the bidirectional codec IS a parser AND a serializer
      /// sharing one value type. Swift's same-name-associated-type unification
      /// across the refinement automatically gives:
      ///
      /// - `Input`   — inherited from `Parser.Protocol`
      /// - `Output`  — inherited (unified) from both refined protocols
      /// - `Buffer`  — inherited from `Serializer.Protocol`
      /// - `Failure` — inherited (unified) from both refined protocols; codecs
      ///   with distinct decode/encode failures populate this with
      ///   `Either<DecodeFailure, EncodeFailure>` from `Either_Primitives`
      ///   (the `Either<X, Never>` collapse via `Either+Never.swift` makes
      ///   one-direction-infallible codecs free at call sites).
      ///
      /// ## No Body/Builder
      ///
      /// Coders are leaf types — `Body == Never` for both inherited
      /// `Body` slots. Codecs do not override `body`.
      public protocol `Protocol`: Parser.`Protocol`, Serializer.`Protocol` { }
  }
  ```
- Delete the lines 88–107 redundant `encode(_:) -> EncodeBuffer` convenience extension (now provided by `Serializer.Protocol.swift:116–128` as `serialize(_:) -> Buffer`).

#### File 3: `/Users/coen/Developer/swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift`

- **Change kind**: typealias / method-rename / caller-update at the default-implementation extension
- **Before** (lines 36–69): two extensions over `Codable where Coder.Output == Self [, Coder.EncodeBuffer: RangeReplaceableCollection]`, using `Coder.DecodeInput`/`Coder.EncodeBuffer`/`Coder.DecodeFailure`/`Coder.EncodeFailure` and calling `Self.coder.encode(self, into:)` / `Self.coder.decode(&input)` / `Self.coder.encode(self)`.
- **After**:
  ```swift
  // MARK: - Instance-level encode

  extension Codable where Coder.Output == Self {

      /// Encodes this value by appending to a buffer.
      ///
      /// - Parameter buffer: The buffer to append to.
      /// - Throws: `Coder.Failure` if encoding fails.
      @inlinable
      public func encode(into buffer: inout Coder.Buffer) throws(Coder.Failure) {
          try Self.coder.serialize(self, into: &buffer)
      }

      /// Decodes a value from the input using the canonical coder.
      ///
      /// - Parameter input: The input to decode from. Modified to reflect consumption.
      /// - Throws: `Coder.Failure` if decoding fails.
      @inlinable
      public init(decoding input: inout Coder.Input) throws(Coder.Failure) {
          self = try Self.coder.parse(&input)
      }
  }

  // MARK: - Buffer-constructing encode

  extension Codable where Coder.Output == Self, Coder.Buffer: RangeReplaceableCollection {

      /// Encodes this value, returning a new buffer.
      ///
      /// - Returns: A new buffer containing the encoded representation.
      /// - Throws: `Coder.Failure` if encoding fails.
      @inlinable
      public func encoded() throws(Coder.Failure) -> Coder.Buffer {
          try Self.coder.serialize(self)
      }
  }
  ```
  Note the **caller-side** consequence: `init(decoding:)` and `encoded()` now throw `Coder.Failure` (typically `Either<D, E>`), not the direction-specific `Coder.DecodeFailure` / `Coder.EncodeFailure`. With zero live callers, no caller update is needed today — but this is the breaking-API change at the canonical-attachment surface that future callers will see.

#### File 4: `/Users/coen/Developer/swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift`

- **Change kind**: typealias / method-rename
- **Before** (lines 68–106): the Coder.Protocol conformance with split typealiases and `decode(_:)` / `encode(_:into:)` methods.
- **After**:
  ```swift
  public import Coder_Primitives
  public import Either_Primitives
  public import RFC_8259

  // ...

  extension JSON.Coder: Coder_Primitives.Coder.`Protocol` {
      public typealias Input   = Swift.Span<UInt8>
      public typealias Buffer  = [UInt8]
      public typealias Output  = RFC_8259.Value
      public typealias Failure = Either<RFC_8259.Error, JSON.Encode.Error>

      @inlinable
      public func parse(
          _ input: inout Swift.Span<UInt8>
      ) throws(Failure) -> RFC_8259.Value {
          let value: RFC_8259.Value
          do {
              value = try JSON.Decode.Implementation.parse(input, maxDepth: maxDepth)
          } catch let error as RFC_8259.Error {
              throw .left(error)
          }
          input = input.extracting(input.count..<input.count)
          return value
      }

      @inlinable
      public func serialize(
          _ output: RFC_8259.Value,
          into buffer: inout [UInt8]
      ) throws(Failure) {
          var encoder = JSON.Encode.Encoder(options: encodeOptions)
          do {
              try encoder.encode(output, into: &buffer)
          } catch let error as JSON.Encode.Error {
              throw .right(error)
          }
      }
  }

  extension RFC_8259.Value: @retroactive Coder_Primitives.Codable {
      public typealias Coder = JSON.Coder
      @inlinable
      public static var coder: JSON.Coder { JSON.Coder() }
  }
  ```
- Add `public import Either_Primitives` (Phase C2 will need to confirm the module name; consistent with `Either_Primitives.Either` usage in v1.1.2 §3a §"Coder.Protocol's `Failure` slot").
- Add `swift-either-primitives` to swift-json's `Package.swift` deps.
- Update DocC example at lines 22–26 to reflect that `init(decoding:)` and `.encoded()` now throw `Either<RFC_8259.Error, JSON.Encode.Error>` — callers must handle both arms or pattern-match.

#### File 5: `/Users/coen/Developer/swift-primitives/swift-binary-coder-primitives/Sources/Binary Coder Primitives/Binary.Coder+Coder.Protocol.swift`

- **Change kind**: typealias / method-rename
- **Before** (lines 10–25): conformance with `DecodeInput`/`EncodeBuffer`/`DecodeFailure`/`EncodeFailure` and `decode(_:)` / `encode(_:into:)`.
- **After**:
  ```swift
  public import Coder_Primitives
  public import Either_Primitives

  extension Binary.Coder: Coder.`Protocol` {
      public typealias Input   = Binary.Bytes.Input
      public typealias Buffer  = [UInt8]
      public typealias Failure = Either<Binary.Bytes.Machine.Fault, Never>

      @inlinable
      public func parse(_ input: inout Binary.Bytes.Input) throws(Failure) -> Output {
          do {
              return try self.decode(&input)   // stored closure, unchanged
          } catch let fault as Binary.Bytes.Machine.Fault {
              throw .left(fault)
          }
      }

      @inlinable
      public func serialize(_ output: Output, into buffer: inout [UInt8]) {
          self.encode(output, &buffer)         // stored closure, unchanged
      }
  }
  ```
- Add `swift-either-primitives` to swift-binary-coder-primitives' `Package.swift` deps and `Binary Coder Primitives` target.
- Note: the rename of the protocol-required method from `decode`/`encode` to `parse`/`serialize` removes the name shadowing between the conformance method and the stored property — the body of `parse` can now call `self.decode(&input)` (the stored closure) unambiguously without `Self.` qualification or workarounds. **Net clarity gain.**

#### Test file: `/Users/coen/Developer/swift-foundations/swift-json/Tests/JSON Tests/Round-Trip Tests.swift`

- **Change kind**: none (tests live in the JSON.Serializable sibling-surface and don't go through Coder.Protocol)
- Confirmed by inspection (lines 9, 16, 17, 26, 27, 36, 37, ...): all tests call `JSON.Decode.parse(_:)` and `JSON.Encode.encode(_:)` — the JSON.Serializable sibling protocol APIs, not Coder.Protocol. The `extension JSON.Coder { @Suite ... }` namespace wrap is unaffected by Coder.Protocol method renames.

#### Test file: `/Users/coen/Developer/swift-primitives/swift-binary-coder-primitives/Tests/Binary Coder Primitives Tests/{Binary.Coder Tests.swift, Integer Coder Tests.swift}`

- **Change kind**: none (tests use `decodeWhole` / `decodePrefix` / `encodeToArray` and direct `Binary.Coder<T>(decode:, encode:)` constructor — all stored-closure paths)

### Optional pseudo-code prototype for Option 3 (view accessors)

The convention's option 3 (direction-specific view accessors on `Coder.Protocol`) would look like this — **not** part of the C2 plan (option 2 is the choice for both conformers), but included per the C1 task brief for completeness:

```swift
// PROTOTYPE ONLY — not for commit in Phase C2

extension Coder.`Protocol` where Self: ~Copyable {
    /// View this coder as a direction-specific parser, exposing the
    /// decode-side failure type narrowly.
    public var parser: some Parser.`Protocol`<Input, Output, Failure> {
        // Identity wrap — for documentary purposes the alias narrows
        // generic constraints but does not change the static type.
        // To get a narrower DecodeFailure, the type-level rewrite at
        // each conformer (declaring a `var asParser: some Parser.Protocol<Input, Output, DecodeFailure>`)
        // is required — protocol-level provision is limited to the unified
        // Failure type and cannot recover the pre-collapse split type
        // without per-conformer narrowing.
        self
    }
}
```

This shows option 3 is **partial** at the protocol-extension level (cannot recover split types without conformer-side work); the convention's text already notes this as "optional convenience." Option 2 remains the cleaner choice.

---

## Section 4: Risk + rollback

### What breaks if Phase C2 is partially applied?

- **If only Coder.Protocol.swift is rewritten (without Codable.swift updated):** Codable.swift's `extension Codable where Coder.Output == Self` references vanished `Coder.DecodeInput`, `Coder.EncodeBuffer`, `Coder.DecodeFailure`, `Coder.EncodeFailure`. Build break inside swift-coder-primitives itself. Loud, immediate, easy to diagnose.
- **If Coder.Protocol.swift + Codable.swift are updated but JSON.Coder.swift is not:** The `extension JSON.Coder: Coder_Primitives.Coder.Protocol` conformance fails — JSON.Coder's `DecodeInput`/`EncodeBuffer`/`DecodeFailure`/`EncodeFailure` typealiases don't satisfy the new `Input`/`Buffer`/`Failure` requirements; `decode(_:)`/`encode(_:into:)` don't satisfy `parse(_:)`/`serialize(_:into:)`. Build break in swift-json. Immediate, diagnosable.
- **If JSON.Coder is updated but Binary.Coder is not:** Build break in swift-binary-coder-primitives' conformance — symmetric to the above. Immediate.
- **If swift-either-primitives dep is omitted:** Build break at `typealias Failure = Either<...>` site. Loud.

There is **no silent breakage path**. Every partial application produces a build error in the immediate package or its direct dependents. Rollback = revert.

### Recommended commit granularity

**Single atomic commit across all three packages.** The refinement is structurally non-decomposable: Coder.Protocol's new shape and the two conformers' updated shapes must land together to keep any package buildable. Splitting into multiple commits would leave the intermediate states broken.

If git history wants logical separation, **squash-merge of a feature branch** containing per-package commits is acceptable as long as the merge commit is the atomic unit. The three packages cross-reference via path-dependency in `Package.swift`, so a single `swift test` from each package's directory after the squash-merge is the verification gate.

### Tests relying on split DecodeFailure / EncodeFailure that need rewriting

**None identified.**

Surveyed:
- `Round-Trip Tests.swift` — uses JSON.Serializable surface (independent of Coder.Protocol)
- `Binary.Coder Tests.swift` — uses stored-closure surface (independent of Coder.Protocol method names)
- `Integer Coder Tests.swift` — same

No test catches `Coder.DecodeFailure` or `Coder.EncodeFailure` by name. No test asserts on the split-type shape of the protocol.

### Risk register

| Risk | Severity | Mitigation |
|------|----------|------------|
| Product-name guess wrong for `Parser Primitives Core` / `Serializer Primitives Core` / `Either Primitives` in Package.swift deps | LOW | Phase C2 verifies against each package's `products:` declaration before writing |
| `Either<DecodeFailure, EncodeFailure>` typealias requires `Failure: Swift.Error` constraint — needs `Either: Swift.Error where Left, Right: Swift.Error` (already provided at `Either.swift:121`) | LOW | Conformance verified in source; the constraint is `Left, Right: Swift.Error`, both arm types satisfy this |
| `~Copyable` propagation: `Parser.Protocol` and `Serializer.Protocol` both inherit `~Copyable`, so `Coder.Protocol` automatically does too — but conformers must still match | LOW | JSON.Coder is `Sendable`-struct (Copyable); Binary.Coder is `Witness.Protocol` (Copyable). Both satisfy the implicit-Copyable conformance to `~Copyable` protocols since Copyable refines ~Copyable. |
| Same-name unification of `Body` requires both Parser and Serializer extensions' `where Body == Never` defaults to apply — verify both extensions are in scope after the imports | LOW | Both extensions are at module top level in their respective `Parser.Parser.swift` / `Serializer.Protocol.swift` files. Importing the modules brings them in. |
| Doc-comment churn — references to "JSON.Coder.decode" in `JSON.Decode.Implementation.swift`, `JSON.Serializable.swift`, `RFC_8259.Pull.swift`, `RFC_8259.swift` use the OLD method name | LOW | Doc-only update in Phase C2 sweep; not a build break. Update to "JSON.Coder.parse" or leave generic ("JSON.Coder's parse path") at your discretion. |

---

## Phase C2 verification checklist

Phase C2 should additionally verify before committing:

1. `swift build` clean in `/Users/coen/Developer/swift-primitives/swift-coder-primitives/`
2. `swift build` clean in `/Users/coen/Developer/swift-primitives/swift-binary-coder-primitives/`
3. `swift build` clean in `/Users/coen/Developer/swift-foundations/swift-json/`
4. `swift test` green in all three packages
5. No new warnings about `~Copyable` requirements unsatisfied
6. Doc-comment updates land in the same commit (no broken references to renamed methods)
7. The redundant `encode(_:) -> EncodeBuffer` extension in `Coder.Protocol.swift:90–107` is **deleted**, not left as dead code (it's now provided by Serializer.Protocol's extension)

---

## Convention text updates (out of scope for Phase C2, suggested for follow-up)

The convention's `family-codable-convention.md` v1.1.2 will need a status-table refresh in §"State of the workspace" once Phase C2 lands — the "NOT YET refined" / "NOT YET added" entries become "DONE" with the Phase C2 commit hash referenced. This is a doc-update, not a Phase C2 deliverable.

---

**End of plan.**
