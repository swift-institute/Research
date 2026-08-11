# Consumer Workaround: Array-Literal + Chained `.advanced(by:)` Pointer-Arithmetic Miscompile

**Status**: known upstream bug
[`swiftlang/swift#77558`](https://github.com/swiftlang/swift/issues/77558)
(filed 2024-11-12). **Fixed on Swift 6.4-dev nightly-main** (commit
`82b7720768ba875`). Awaiting backport to 6.3.x or 6.4 release. Transitional
workaround until then.

**Affected**: Swift 6.3.1 release (Apple) + Swift 6.3 (Linux), `-O` / `-Osize`, on
both macOS arm64 and Linux x86_64. Not just Linux — earlier "Linux-only"
framing was a SwiftPM test-framework artifact.

**Tracking**:
- Investigation arc: `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/INVESTIGATION-ARC.md`
- Standalone repro + #77558 comment text: `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/`
- In-tree fix detector: `Tests/Affine Primitives Tests/AffineSLITests.swift::unsafeMutablePointerMinusTypedOffset` (gated via `.disabled(if: isLinux)` + `.bug(URL, ...)`)

## The trigger (narrowed via independent `/collaborative-discussion`)

The bug fires only when ALL of the following hold:

1. **Array<T> literal initialization** — `var values: [Int] = [0, 10, 20, 30, 40]`.
   `Array(repeating:count:)` + sequential subscript writes does NOT bug.
2. **Trivial element type** — `Int`, POD structs. ARC-bearing class element
   types do NOT bug.
3. **Chained `.advanced(by:)` with compile-time-CONSTANT mixed-direction offsets**
   — e.g., `base.advanced(by: 4).advanced(by: -2)`. Parameterized offsets
   passed in as function parameters do NOT bug.
4. **Storage path through `_ContiguousArrayStorage` / CoW lowering** — manual
   `UnsafeMutableBufferPointer.allocate + initialize` and hand-rolled
   `UnsafeMutablePointer<Int>.allocate(capacity:)` do NOT bug.

Under those conditions, the optimizer's dead-store elimination eliminates the
live element stores for intermediate array-literal indices. The chained
`index_addr +M, −N` load reads from one of those eliminated-store slots →
uninitialized memory:

```swift
// FIRES the bug
var values: [Int] = [0, 10, 20, 30, 40]
return values.withUnsafeMutableBufferPointer { buf in
    let base = buf.baseAddress!.advanced(by: 4)
    let backed = base.advanced(by: -2)
    return backed.pointee  // wrong value — read from eliminated-store slot
}
```

## What does NOT trigger the bug

- Single `.advanced(by:)` step (any direction)
- Subscript access: `buf[2]`
- Chained `.advanced(by:)` where ALL offsets are positive
- Chained `.advanced(by:)` with parameterized (non-constant) offsets
- `Array(repeating: 0, count: 5)` + sequential `values[i] = …` writes
- Array of ARC-bearing class elements (the ARC payload blocks the
  transformation)
- Manual `UnsafeMutableBufferPointer.allocate + initialize` + chained advance
- Hand-rolled `UnsafeMutablePointer<T>.allocate(capacity:)` + chained advance
- Any of the above wrapped in user-authored operator overloads (the operator
  body is not part of the trigger)

## Consumer workaround patterns

Three patterns to avoid the trigger. Pick whichever fits the consumer's
ergonomics; all three produce correct output on both affected platforms.

### Pattern 1 — Collapse the arithmetic into one `.advanced(by:)` call

Computes the cumulative offset eagerly; only one stdlib call survives, so
no chain to miscompile.

```swift
// AVOID the chain
let advanced = unsafe base.advanced(by: 4)
let backed = unsafe advanced.advanced(by: -2)

// PREFER the single-step form
let backed = unsafe base.advanced(by: 4 - 2)  // or: base.advanced(by: 2)
```

This is the lowest-cost workaround when the offsets are computable at the
call site. Where they're not (e.g., the package operator overloads add a
typed `Offset` after the consumer has already moved forward), see
Pattern 2.

### Pattern 2 — Bypass the package operator overloads on the affected paths

Direct stdlib `.advanced(by:)` with a single offset has no chain — fires
the bug only when chained. If the consumer code is `let backed = (ptr +
offset1) - offset2`, the two operator calls form a chain that miscompiles.
Substitute a direct stdlib call:

```swift
// AVOID — operator chain miscompiles in release on affected platforms
let backed = ptr + offset1 - offset2

// PREFER — direct stdlib call with the resolved offset
let backed = unsafe ptr.advanced(by: Int(bitPattern: offset1) - Int(bitPattern: offset2))
```

The package's `+` / `-` operators on `UnsafeMutablePointer<Pointee>` (in
`Sources/Affine Primitives Standard Library Integration/UnsafeMutablePointer+Tagged.Ordinal.swift`)
are correct in their bodies — `Q1a` in the investigation arc proved
operator-body code is not part of the trigger. The miscompile lives in
the chaining at the call site, not in the operator's body.

### Pattern 3 — Mask the optimizer via intermediate materialization

If neither collapse nor bypass is feasible, read the result pointer
through a forcing materialization between the chain and the `.pointee`
load. Any read of the result pointer's bit pattern (or a `print` of it)
masks the bug by extending the value's observable live range past the
optimizer's misbehavior point:

```swift
let advanced = unsafe base + offset1
let backed = unsafe advanced - offset2

// Masking materialization — explicit read forces the optimizer to
// preserve `backed` correctly across the load. A single line of
// `_ = unsafe UInt(bitPattern: backed)` was insufficient empirically;
// the proven mask required MULTIPLE intermediate reads through
// `UInt(bitPattern:)` plus a side reference (e.g., in a string).
let backedBitPattern = unsafe UInt(bitPattern: backed)
let advancedBitPattern = unsafe UInt(bitPattern: advanced)
let _ = "\(backedBitPattern)+\(advancedBitPattern)"

let value = unsafe backed.pointee
```

This pattern is the least clean and the most fragile (the optimizer's
behavior may shift between toolchain versions). Use only when the
consumer code structurally cannot adopt Pattern 1 or Pattern 2.

## Detection in CI

The in-tree test `unsafeMutablePointerMinusTypedOffset` in
`Tests/Affine Primitives Tests/AffineSLITests.swift` exercises the failing
shape with `.disabled(if: isLinux)` + `.bug(URL, ...)` trait. When upstream
fixes the bug:

1. Remove the `.disabled(if: isLinux)` trait.
2. Re-run CI. Linux release should pass.
3. Remove this Research note + the `.bug` trait.
4. Consumers using Patterns 1–3 above can revert to natural chained form.

The bug actually also fires on standalone macOS `swiftc -O`, but `swift test
-c release` masks it for this test target on macOS — so the in-tree gate
is conservative (Linux-only). When the upstream fix lands, both platforms
will pass and the gate can be lifted.

## Why not patch the operator definitions

`Q1a` in the investigation arc confirmed that `unsafe` markers in operator
*body* (without `unsafe` at call sites) do not trigger the bug. The
operator bodies are evergreen single-expression `@_transparent` wrappers
matching the initial publication shape; the trigger lives at the
call-site chaining. There is no operator-body fix that resolves the
bug — three were attempted ([ISSUE-005] in the arc) and all failed.

## When upstream fixes ship

1. Watch [`swiftlang/swift#77558`](https://github.com/swiftlang/swift/issues/77558) for resolution status.
2. Track shipped-toolchain availability: the fix is already on Swift 6.4-dev
   nightly-main (commit `82b7720768ba875`); awaiting Xcode 6.4 release or a
   6.3.x backport.
3. When a release-shipped toolchain contains the fix, verify per [ISSUE-001].
4. Remove `.disabled(if: isLinux)` from the in-tree test.
5. Delete this Research note.

## Severity assessment

Most consumer code is unaffected. The narrowed trigger requires the SPECIFIC
combination of array-literal init + trivial element + chained constant-offset
mixed-direction `.advanced(by:)` + CoW storage path. Production codebases
typically use one or more of:

- `Array(repeating:count:)` for buffer initialization (not bug-prone)
- Subscript access `buf[i]` (not bug-prone)
- Single-direction advance loops (not bug-prone)
- Parameterized offsets from runtime values (not bug-prone)

**Most consumers do not need to change anything.** The known-affected pattern
in `swift-affine-primitives` is one test using a literal-initialized array
with chained constant-offset mixed-direction arithmetic — exactly the trigger
shape. That test is gated until the upstream fix ships.
