# swift-serializer-primitives — `Tagged.underlying` + Carrier `\`Protocol\`` migration audit

**Date**: 2026-05-03
**Scope**: `/Users/coen/Developer/swift-primitives/swift-serializer-primitives`
**Migration cycle**: rename `Tagged.rawValue` → `Tagged.underlying`; rename Carrier protocols to canonical namespace `\`Protocol\``.
**Verdict**: **No-op.** No source changes required.

---

## Phase 1 — Design audit

### Q1. Own `public let rawValue` types?

**None.** Grep across `Sources/` and `Tests/` returns zero hits for `rawValue`. The package's public surface is built from witness structs whose stored members are
`call` closures plus typed payload fields (`value`, `count`), never `rawValue`. There is nothing to rename under the pre-authorized `rawValue → underlying` carve-out.

### Q2. Editorial public surface that could move to a sibling target / SLI?

**None of consequence.** The package is already decomposed along the right axes:

| Target | Role |
|--------|------|
| `Serializer Namespace` | Bare `public enum Serializer {}` — namespace seed. |
| `Serializer Primitives Core` | `Serializer.\`Protocol\``, `Serializer.Builder`, `Serializable` attachment protocol. |
| `Serialization Primitives` | Witness structs (`Serialization.Serializing.{Value,Buffer}`, `Serialization.Parsing.{Whole,Prefix.Witness,Prefix.Result}`, `Serialization.Measuring`, `Serialization+Void` conveniences). |
| `Serializer Primitives` | Umbrella `@_exported import` of the three above. |
| `Serialization Primitives Test Support` | Test fixtures only. |

The `Serialization+Void` conveniences (`call(_:)`, `returning(_:)`) are editorially adjacent extensions on the witness structs but not Standard-Library-Integration in the
SLI sense — they are plain Swift conveniences that depend only on the witness types and `Array`. There is no Foundation, no Tagged/Carrier conformance surface, no
protocol bridging that would justify carving them off into a sibling target. **Recommendation: leave as-is.**

### Q3. Three-consumer rule

Not applicable inside this package as a gating concern — the package has zero direct consumers of Tagged/Carrier and exposes no `rawValue`-style accessors that
downstream packages would adopt-or-fork. Consumer count for this package's witness types lives outside its boundary (e.g., `swift-rfc-*`, `swift-ietf-*` standards
adopting `Serializable`); the migration cycle does not change that surface. **No recommendation.**

### Q4. Compound identifiers / `*Tag` suffixes / code-surface violations

**None found.**

- No `*Tag` suffix anywhere.
- No compound identifiers — every type uses `Nest.Name` form: `Serialization.Parsing.Prefix.Witness`, `Serialization.Parsing.Prefix.Result`, `Serialization.Serializing.Value`,
  `Serialization.Serializing.Buffer`, `Serialization.Measuring`, `Serializer.Builder`, `Serializer.\`Protocol\``.
- One file = one type (`Serialization+Void.swift` is conventional convenience-extension namespacing, not a type-bearing file).
- Errors are typed via the `Failure: Swift.Error` associated type; no `throws` / `throws(any Error)` exists.
- Canonical capability protocol uses `\`Protocol\`` (backticked), matching the swift-package skill convention.
- Two namespace hubs (`Serializer` and `Serialization`) — this is the explicit canonical pattern (noun namespace + gerund namespace for the witness family); not a violation.

---

## Verdict

Migration is a **no-op** for this package on all four questions. No escalation. No source edits. The build and full test suite are green on Swift 6.3.1 against the
current Package.swift toolchain settings.

## Build verification

```
swift package update   # Everything is already up-to-date
rm -rf .build
swift build            # Build complete! (0.82s) — all 5 targets compile clean
swift test             # 17 tests in 8 suites passed (0.001s)
```

No warnings, no diagnostics, no deprecations surfaced.
