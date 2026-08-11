# Buffer Base Nullability

<!--
---
version: 1.1.0
last_updated: 2026-01-28
status: DECISION
---
-->

## Context

`Memory.Buffer` internally guarantees a non-null `_start` address using a sentinel allocation for empty buffers. Two public interop properties currently exist:

- `base` — returns `UnsafeRawBufferPointer(start: nil, count: 0)` for empty buffers (stdlib convention)
- `baseNonNull` — returns `UnsafeRawBufferPointer(start: sentinel, count: 0)` for empty buffers

Extensive C interop is expected across the ecosystem, making non-null buffer access a primary use case rather than a niche concern. Many C APIs reject null pointers even when accompanied by a zero count.

The name `baseNonNull` is a compound identifier, which violates [API-NAME-002].

## Question

What should the naming and API structure of `Memory.Buffer`'s stdlib interop properties be, given that both null and non-null forms serve real use cases?

## Analysis

### Option A: Keep current dual API (`base` + `baseNonNull`)

Current implementation. `base` returns nil-for-empty (stdlib convention); `baseNonNull` preserves the sentinel.

**Advantages:**
- Both interop modes are available
- Explicit about what each variant provides

**Disadvantages:**
- `baseNonNull` is a compound identifier — violates [API-NAME-002]
- Unclear which is the "primary" variant
- Name implies the non-null version is the exceptional case, when in practice it may be the common one

### Option B: `base` always non-null; add `base.nullable` or similar for stdlib

Make the default `base` return non-null (matching the internal invariant). Provide a stdlib-convention variant for code that expects nil.

**Advantages:**
- Default behavior matches the type's core invariant (non-null)
- C interop path is the simple, obvious one

**Disadvantages:**
- Breaks existing code that checks `buffer.base.baseAddress == nil`
- Requires a wrapper type or namespace

### Option C: Nested accessor via Property pattern

Use `Property<Tag, Base>` from `swift-property-primitives` to create a namespace:

```swift
import Property_Primitives

extension Memory.Buffer {
    enum Base {}

    var base: Property<Base, Memory.Buffer> { .init(self) }
}

extension Property where Tag == Memory.Buffer.Base, Base == Memory.Buffer {
    /// Stdlib-normal form: `nil` base address for empty buffers.
    var nullable: UnsafeRawBufferPointer {
        if base.isEmpty {
            return unsafe UnsafeRawBufferPointer(start: nil, count: 0)
        }
        return unsafe UnsafeRawBufferPointer(
            start: UnsafeRawPointer(base._start),
            count: base.count
        )
    }

    /// Non-null form: sentinel base address for empty buffers.
    /// Use for C APIs that reject null pointers even with count 0.
    var nonNull: UnsafeRawBufferPointer {
        unsafe UnsafeRawBufferPointer(
            start: UnsafeRawPointer(base._start),
            count: base.count
        )
    }
}
```

Usage: `buffer.base.nullable`, `buffer.base.nonNull`.

**Advantages:**
- Follows [API-NAME-002] — nested accessor, no compound name
- Progressive disclosure: autocomplete on `buffer.base.` shows both options
- Uses established Property pattern from the primitives ecosystem
- Zero runtime overhead — Property stores the buffer value directly

**Disadvantages:**
- `buffer.base` alone is no longer usable as `UnsafeRawBufferPointer` — you must pick a variant
- Adds a dependency on `Property Primitives` (already Tier 1, so allowed)
- Internal methods like `withRebound` that currently call `base.withMemoryRebound` must change to `base.nullable.withMemoryRebound` or `base.nonNull.withMemoryRebound`

### Option D: Non-null `base`; stdlib conversion via manual construction

Make `base` always non-null. Users construct the nil-base buffer themselves when needed.

**Advantages:**
- Single property, simple API

**Disadvantages:**
- Stdlib nil-convention becomes manual boilerplate
- Error-prone: users must remember to apply the convention

### Option E: `base` returns non-null; add `stdlib` conversion property

Two flat properties: `base` (non-null) and `stdlib` (nil-for-empty).

**Advantages:**
- Non-null is the default
- No compound names

**Disadvantages:**
- `stdlib` is vague — stdlib of what?
- Two properties at the same level without namespace grouping

### Option F: Rename only — `base` stays nil; rename `baseNonNull`

Keep `base` as stdlib-convention. Rename `baseNonNull` to a convention-compliant name.

**Advantages:**
- `base` retains stdlib compatibility

**Disadvantages:**
- All candidates (`cBase`, `rawBase`, `unsafeBase`) are still compound-ish or carry misleading connotations

### Comparison

| Criterion | A: Current | C: Property | D: Non-null only | E: base + stdlib |
|-----------|-----------|-------------|-------------------|-----------------|
| [API-NAME-002] compliance | No | Yes | Yes | Yes |
| C interop path | `buffer.baseNonNull` | `buffer.base.nonNull` | `buffer.base` | `buffer.base` |
| Stdlib interop path | `buffer.base` | `buffer.base.nullable` | Manual | `buffer.stdlib` |
| API simplicity | Two flat properties | Namespace + two | One property | Two flat properties |
| Discoverability | Flat | Progressive | Trivial | Flat |
| Ecosystem consistency | Ad hoc | Uses Property pattern | N/A | Ad hoc |

### Constraints

1. **C interop is extensive.** Non-null base is a primary interop path.

2. **Stdlib convention is real.** A conversion to stdlib-normal form must exist.

3. **[API-NAME-002]** forbids compound identifiers. `baseNonNull` violates this.

4. **The sentinel is an implementation detail.** The API should expose the guarantee (non-null) or the convention (nullable), not sentinel mechanics.

5. **`start` provides non-null access within primitives.** `base` is specifically for crossing to stdlib/C types.

6. **`base` defaults to nil-for-empty** (for now). This preserves stdlib compatibility during the pre-1.0 period. Can be revisited when the ecosystem matures and the default can shift to non-null.

7. **[API-IMPL-005]**: The `Base` tag enum and Property extension should live in their own file (`Memory.Buffer.Base.swift`).

## Outcome

**Status**: DECISION

**Decision**: Option C — nested accessor via `Property<Tag, Base>`.

**Rationale:**

1. **Convention compliance.** `buffer.base.nonNull` and `buffer.base.nullable` follow [API-NAME-002] — no compound identifiers. The current `baseNonNull` does not.

2. **Progressive disclosure.** Autocomplete on `buffer.base.` reveals both options. Users learn that a choice exists — they are not silently getting one convention when they needed the other.

3. **Ecosystem consistency.** The `Property<Tag, Base>` pattern is established infrastructure from `swift-property-primitives`. Using it here is consistent with how other primitives create namespaced accessors.

4. **Future-proof.** When the ecosystem matures and the default can shift to non-null, this is a naming change within the namespace (`base.nullable` → deprecated, `base.nonNull` → possibly promoted to `base` directly) rather than a breaking rename of a top-level property.

5. **Explicit choice.** Neither convention is silently assumed. Users must write `buffer.base.nullable` or `buffer.base.nonNull`, making the choice visible and grep-able.

**Implementation path:**
- Add `Property Primitives` dependency to `swift-memory-primitives`
- Create `Memory.Buffer.Base.swift` with tag enum and Property extension
- Create `Memory.Buffer.Mutable.Base.swift` with parallel mutable implementation
- Update `withRebound` and any internal callers from `base` → `base.nullable`
- Update tests
- Remove old `base` and `baseNonNull` properties

## References

- `Memory.Buffer.swift:136-161` — current `base` and `baseNonNull` definitions
- `Memory.Buffer.Mutable.swift` — parallel mutable implementation
- `Memory.Buffer Tests.swift:128-140` — tests for both properties
- `memory-address-mutability.md` — address-as-position design philosophy
- `swift-property-primitives` — `Property<Tag, Base>` pattern
- [API-NAME-002] — no compound identifiers
- [API-IMPL-005] — one type per file
