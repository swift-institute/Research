# File / Path Type Unification Audit

## Context

swift-file-system wraps `Paths.Path` (from swift-paths) in convenience types: `File`, `File.Directory`, `File.Path` (typealias for `Paths.Path`). A recent attempt to add `ExpressibleByStringLiteral` to `File` and `File.Directory` revealed a fundamental tension: `Paths.Path` already conforms to `ExpressibleByStringLiteral` (with `fatalError` on invalid input), but `File.Directory` has a throwing `init(_ string: String) throws(Paths.Path.Error)`. Adding literal conformance to `File.Directory` silently overrides the throwing init for all string literals — a footgun that `@_disfavoredOverload` cannot mitigate.

This raises a broader question: are the File/Directory wrapper types pulling their weight, or are they creating friction with the well-designed Path layer below?

## Package Locations

- **swift-paths**: `/Users/coen/Developer/swift-foundations/swift-paths/`
- **swift-file-system**: `/Users/coen/Developer/swift-foundations/swift-file-system/`

## Research Tasks

### 1. Inventory the Type Surface

Map every public type, protocol conformance, and initializer across both layers:

**swift-paths** (`Sources/Paths/`):
- `Path` — conformances, inits (throwing, literal, interpolation), operators (`/`), properties
- `Path.Component` — conformances, inits, operators
- `Path.Component.Extension` — conformances, inits
- `Path.Component.Stem` — conformances, inits
- Any other public types

**swift-file-system** (`Sources/File System Primitives/`, `Sources/File System/`):
- `File` — conformances, inits, properties, methods
- `File.Directory` — conformances, inits, properties, methods
- `File.Path` (typealias) — any extensions added
- `File.Path.Component` — any extensions added
- `File.Path.Property` — the generic property pattern
- `File.Handle`, `File.Descriptor` — how they relate to Path

For each type, note:
- What value does the wrapper add over `Path` directly?
- What API surface is duplicated vs novel?
- Where do String/Path/Component conversions happen?

### 2. Trace Initialization Paths

For each way a user can create a `File` or `File.Directory`, document the full call chain:

```
File(path)           → stores Path directly
File.Directory(path) → stores Path directly
File.Directory(string) throws → try Path(string), stores result
```

Compare with Path's own initialization:
```
Path(string) throws  → validated
Path(stringLiteral:) → fatalError on invalid
Path(stringInterpolation:) → fatalError on invalid
```

Identify every point where validation can be bypassed or where the same string goes through different validation paths depending on call site.

### 3. Analyze the `name` / `extension` / `stem` Properties

The recent String → Path.Component migration changed:
- `File.name: String` → `File.name: Path.Component`
- `File.extension: String?` → `File.extension: Path.Component.Extension?`
- `File.stem: String?` → `File.stem: Path.Component.Stem?`

And similar for `File.Directory.name`.

Questions:
- Are these properties just forwarding to `path.lastComponent`, `path.extension`, `path.stem`?
- If so, do the wrapper types add anything that `Path` doesn't already provide?
- Are there consumers that depend on the `String` return types (grep the workspace)?

### 4. Evaluate the `/` Operator

Both `Path` and `File`/`File.Directory` define `/`:
- `Path / Component → Path`
- `File / Component → File`
- `File.Directory / Component → File.Directory`

Is the wrapper operator just `File(path / component)`? If so, is the convenience worth the type proliferation?

### 5. Evaluate File.Path.Property

`File.Path.Property<Value>` is a generic property modification pattern with two built-in properties (`.extension`, `.lastComponent`). Questions:
- Does `Path` itself have similar mutation APIs?
- Is this pattern used anywhere outside the two built-in properties?
- Should this live in swift-paths instead?

### 6. Assess Unification Options

Based on the inventory, evaluate these options:

**Option A: Status Quo** — Keep File/Directory as thin wrappers. Document the literal conformance limitation. Accept that `File.Directory("...")` is throwing while `Path("...")` string literals are not.

**Option B: Remove throwing init from File.Directory** — Make `File.Directory(string)` use `Path(stringLiteral:)` semantics (fatalError on invalid). Add `try File.Directory(validating: string)` for the throwing path. This aligns with Path's own design.

**Option C: Remove File/Directory wrappers** — Users work with `Path` directly. `File.System.*` APIs already take `Path`. The wrappers exist only for ergonomic dot-syntax (`file.read()` instead of `File.System.Read.read(from: path)`). Evaluate whether the ergonomic benefit justifies the type surface.

**Option D: Strengthen the wrappers** — Make File/Directory `~Copyable` or add invariants that Path doesn't have (e.g., File guarantees it's not a directory path). This would justify their existence as distinct types.

**Option E: Hybrid** — Keep wrappers but make them conform to `ExpressibleByStringLiteral` correctly by removing the competing throwing `init(_ string:)`. Replace with `init(validating:)` to make the overload set unambiguous.

For each option, assess:
- Breaking API changes required
- Impact on existing consumers (grep for `File(`, `File.Directory(`, etc. across the workspace)
- Alignment with ecosystem conventions (how do other ecosystem types handle this?)

### 7. Check Ecosystem Precedent

How do other types in the ecosystem handle the literal-vs-throwing tension?
- Does `Path.Component` have the same issue? (It has both `ExpressibleByStringLiteral` and `init(_ string:) throws`)
- Any other types with both conformances?

Grep across swift-primitives, swift-standards, and swift-foundations for types that conform to `ExpressibleByStringLiteral` and also have a throwing `init` from `String`.

## Output

Write findings to `/Users/coen/Developer/swift-institute/Research/file-path-type-unification-audit.md`. Return ONLY a one-line confirmation: "Wrote file-path-type-unification-audit.md".

## Skills to Load

`/naming`, `/design`, `/implementation`
