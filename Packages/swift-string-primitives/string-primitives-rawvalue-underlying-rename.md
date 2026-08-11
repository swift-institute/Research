# swift-string-primitives — RawValue → Underlying / Carrier.\`Protocol\` rename

**Status**: design audit, downstream tier 13
**Scope**: `/Users/coen/Developer/swift-primitives/swift-string-primitives`
**Upstream**: carrier-primitives `2b57aac`, tagged-primitives `46ded75`

## Q1 — Own `public let rawValue` types?

**Answer**: No.

`String_Primitives.String` (`Sources/String Primitives/String.swift`) stores
`@usableFromInline internal let _storage: Storage.Contiguous<Char>` — already
the cardinal/ordinal/vector precedent shape (private `_storage`, no own
`rawValue`). The type does NOT conform to `Carrier.\`Protocol\`` today; it
exposes its underlying `Storage.Contiguous<Char>` only via deliberate
accessors (`view`, `span`, `withUnsafePointer`, `take()`) and a
`Span.\`Protocol\`` retroactive conformance.

`String.Borrowed` (`Sources/String Primitives/String.Borrowed.swift`) is a
two-field `~Copyable & ~Escapable` view (`pointer: UnsafePointer<Char>`,
`count: Int`). Both fields are `public let`, but neither is named
`rawValue` — they're domain fields, not a Carrier underlying. No rename
applies.

**No own-field rawValue migrations needed in this package.**

## Q2 — Editorial public surface that could move to a sibling target / SLI?

**Answer**: No.

Public surface is purely platform-string mechanics:

- `String` (owned, ~Copyable, null-terminated)
- `String.Borrowed` (~Escapable view)
- `String.Char` typealias (UInt8/UInt16 by platform)
- `String.length(of:)`, `String.terminator`
- `Tagged where RawValue == String` extensions in
  `Tagged+String.swift` and `Tagged+String.Borrowed.swift`

There is no Foundation interop, no Swift-stdlib `Swift.String` bridging,
no `RawRepresentable`/literal-conformance editorial work, no test-only
helpers leaked into public — nothing that fits a `* Standard Library
Integration` or `* Foundation Integration` carve-out per
[MOD-015]/[PRIM-FOUND-001].

The only Foundation/stdlib touch points are `StaticString` (allowed in
primitives) and `UnsafePointer/UnsafeBufferPointer`/`Span` (stdlib only).

**No SLI/FI carve-out warranted.**

## Q3 — Three-consumer rule

**Answer**: Tagged extensions are scoped to `RawValue == String` of THIS
package's `String`, not a generic carve-out. The two files
`Tagged+String.swift` and `Tagged+String.Borrowed.swift` extend
`Tagged where RawValue == String, Tag: ~Copyable` to provide
adopting/copying init, ascii literal init, count, span, view, take,
plus a `@retroactive Span.\`Protocol\`` conformance.

These are consumer ergonomics for downstream packages that mint phantom
tags onto `String_Primitives.String` (e.g., file-name and path tags in
swift-file). They are NOT a `Tagged<Tag, X>` editorial carve-out — they
are this package's defining surface for "tagged platform string". The
three-consumer rule is satisfied by the package's role as the canonical
home for `String` (no other package owns this type).

**Three-consumer rule satisfied by package role; nothing to relocate.**

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

**Answer**: None observed.

- No `*Tag`-suffixed types declared.
- No compound public identifiers — all members nest under `String` or
  `String.Borrowed` per [API-NAME-001]/[API-NAME-002].
- One type per file per [API-IMPL-005]: `String` (`String.swift`),
  `String.Borrowed` (`String.Borrowed.swift`), `String.Char` typealias
  family (`String.Char.swift`), `String.length` family (`String.Length.swift`),
  Tagged extensions in their own paired files.
- Errors: none thrown from this surface (initializers `precondition`-trap
  on bad inputs; no typed-throws surface), so [API-ERR-001] not engaged.

**No violations.**

## Verdict

Phase 2 is a pure mechanical rename plus mechanical Tagged shape
update. No own-field rawValue precedent applies. No escalations under
Q2/Q3/Q4.

Concretely, expected mechanical edits in this package:

1. `Tagged+String.swift` and `Tagged+String.Borrowed.swift` —
   `where RawValue == String` → `where Underlying == String`,
   `rawValue` reads → `underlying`,
   `init(__unchecked: (), String(...))` → `init(_unchecked: String(...))`.
2. No `Carrier`-bare conformance to retarget (`String` is not Carrier),
   no `extension X: Carrier` rewrites.
3. No public-mutation sites (the file is read-only on `rawValue`).

Tagged's `Carrier.\`Protocol\`` conformance is unconditional and immediate
upstream, so consumers like file-name/path tags downstream of this
package will pick up the new shape transparently.
