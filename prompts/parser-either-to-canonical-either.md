# Replace Parser.Error.Either with Canonical Either — Prompt for New Chat

## Objective

Replace `Parser.Error.Either<Left, Right>` in swift-parser-primitives with the canonical `Either<Left, Right>` from swift-algebra-primitives. Direct replacement, no typealias. Breaking change is acceptable.

## Skills to Load

1. `/naming`
2. `/errors`
3. `/code-organization`

Read the workspace-level CLAUDE.md and `https://github.com/swift-primitives/CLAUDE.md`.

## Background

`Either<Left, Right>` was added to swift-algebra-primitives as the canonical binary coproduct. It lives at:
`https://github.com/swift-primitives/swift-algebra-primitives/blob/main/Sources/Algebra Primitives/Either.swift`

Read it first. Key differences from `Parser.Error.Either`:

| Feature | `Parser.Error.Either` | Canonical `Either` |
|---------|----------------------|-------------------|
| Constraints | `Left: Error & Sendable, Right: Error & Sendable` | Unconstrained (conditional Error conformance) |
| `@frozen` | Yes | No |
| Never elimination | `.error` property | `.value` property |
| Chain accessors | `.first`, `.second`, `.third` (via `_EitherChain`) | None (not general-purpose) |
| Basic accessors | `.left`, `.right` | `.left`, `.right` |
| Functor ops | None | `map`, `mapLeft`, `bimap`, `swapped` |
| Located error | `LocatedError` conformance | None |

## Scope

Package: `https://github.com/swift-primitives/swift-parser-primitives`

### Files that reference `Parser.Error.Either` (11 total):

**Definition (delete/rewrite):**
- `Sources/Parser Error Primitives/Parser.Either.swift` — the local definition + chain accessors + Never elimination + LocatedError

**Failure typealiases (mechanical replacement):**
- `Sources/Parser Take Primitives/Parser.Take.Two.swift:32` — `Failure = Parser.Error.Either<P0.Failure, P1.Failure>`
- `Sources/Parser Skip Primitives/Parser.Skip.First.swift:31` — same pattern
- `Sources/Parser Skip Primitives/Parser.Skip.Second.swift:31` — same pattern
- `Sources/Parser Map Primitives/Parser.Map.Throwing.swift:36` — `Failure = Parser.Error.Either<Upstream.Failure, E>`
- `Sources/Parser Literal Primitives/Parser.Literal.swift:40` — `Failure = Parser.Error.Either<EndOfInput.Error, Match.Error>`
- `Sources/Parser Filter Primitives/Parser.Filter.swift:37` — `Failure = Parser.Error.Either<Upstream.Failure, Constraint.Error>`
- `Sources/Parser First Primitives/Parser.First.Where.swift:34` — `Failure = Parser.Error.Either<EndOfInput.Error, Match.Error>`
- `Sources/Parser FlatMap Primitives/Parser.FlatMap.swift:36` — `Failure = Parser.Error.Either<Upstream.Failure, Downstream.Failure>`
- `Sources/Parser Conditional Primitives/Parser.Conditional.swift:23` — `Failure = Parser.Error.Either<First.Failure, Second.Failure>`
- `Sources/Parser Byte Primitives/Parser.Byte.swift:29` — same as Literal

**Throws clause:**
- `Sources/Parser Match Primitives/Parser.Protocol+parse.swift:13` — `throws(Parser.Error.Either<Failure, Parser.Match.Error>)`

**Tests using `.error` (Never elimination):**
- `Tests/Parser Take Primitives Tests/Parser.Builder Tests.swift` — uses `.error.map { ... }` pattern extensively (lines 162, 198, 229, etc.)

## Execution Steps

### Step 1: Add dependency

In `Package.swift`, add `swift-algebra-primitives` as a dependency and add `"Algebra Primitives"` to the `"Parser Error Primitives"` target's dependencies.

```swift
.package(path: "../swift-algebra-primitives"),
```

### Step 2: Rewrite Parser.Either.swift

The file currently contains:
1. `_EitherChain` protocol
2. `Parser.Error.Either` enum definition
3. `_EitherChain` conformance
4. Basic accessors (`.left`, `.right`)
5. Chain accessors (`.first` through `.sixth`)
6. Deprecated `Parser.Either` typealias
7. Never elimination (`.error`)
8. `LocatedError` conformance
9. `earliestOffset`

Replace with:
1. **Delete** the `Parser.Error.Either` enum definition entirely
2. **Keep** `_EitherChain` protocol — move chain accessors to constrained extensions on `Either`
3. **Keep** `LocatedError` conformance — move to constrained extension on `Either`
4. **Delete** deprecated `Parser.Either` typealias
5. **Delete** `.error` Never elimination (canonical Either uses `.value` instead)
6. **Delete** basic `.left`/`.right` accessors (canonical Either already has them)
7. **Delete** `Equatable` conformance (canonical Either already has it)
8. **Add** `import Algebra_Primitives`
9. **Add** `@_exported public import Algebra_Primitives` in the module's exports.swift so `Either` is visible to all parser modules

The file should end up with ONLY:
- `_EitherChain` protocol definition
- `Either: _EitherChain` conformance
- Chain accessors (`.first` through `.sixth`) as extensions on `Either where Left: Error & Sendable, Right: Error & Sendable`
- `LocatedError` conformance on `Either`
- `earliestOffset` on `Either`

### Step 3: Mechanical replacement across 11 files

In every file, replace:
```
Parser.Error.Either<A, B>  →  Either<A, B>
```

Each file may need `import Algebra_Primitives` if `Either` isn't already visible through the re-export chain. Check if the Parser Error Primitives module's exports.swift re-exports it — if so, downstream modules that import Parser Error Primitives get Either transitively.

### Step 4: Fix tests

Tests use `.error` for Never elimination. The canonical Either uses `.value` instead:
```
.error  →  .value
```

Specifically in `Parser.Builder Tests.swift`, patterns like:
```swift
.error.map { $0.error }    // Either<Never, X>.error → X, then further elimination
```
Become:
```swift
.value.map { $0.value }    // Either<Never, X>.value → X
```

Wait — `.error.map` is not on Either. It's likely on a parser type. Read the test file carefully to understand the `.error.map` chain before replacing. The `.error` might be a property on the parser result type, not on Either itself.

### Step 5: Build and test

```bash
cd swift-parser-primitives
swift build
swift test
```

All must pass. There are test targets per module — verify all compile.

### Step 6: Verify no references remain

```bash
grep -rn "Parser\.Error\.Either\|Parser\.Either" Sources/ Tests/
```

Should return zero hits (except possibly in doc comments — those should be updated too).

## Critical Details

1. **`_EitherChain` conformance**: The canonical `Either` doesn't conform to `_EitherChain`. You must add it as a constrained extension. The constraint should be `where Left: Error & Sendable, Right: Error & Sendable` to match the parser's usage pattern, OR unconstrained if the protocol's associated types allow it.

2. **`LocatedError` conformance**: Move to `extension Either: Parser.Error.LocatedError where Left: Parser.Error.LocatedError, Right: Parser.Error.LocatedError`. This is the parser's protocol — it stays in parser-primitives, just applied to the canonical type.

3. **Module visibility**: `Either` must be visible in every parser module that uses it. The cleanest path: add `@_exported public import Algebra_Primitives` to `Parser Error Primitives/exports.swift`. Since all parser modules that use Either already depend on Parser Error Primitives, this propagates automatically.

4. **The `@frozen` loss**: `Parser.Error.Either` was `@frozen`. The canonical `Either` is not. This is intentional — `@frozen` on an ecosystem-wide type is premature ABI coupling. Parser-primitives is source-distributed, not ABI-stable, so this has zero impact.

5. **Constraint relaxation**: `Parser.Error.Either` required `Left: Error & Sendable, Right: Error & Sendable`. The canonical `Either` is unconstrained. All parser Failure types already conform to both, so the relaxation is source-compatible. The Failure typealiases like `Either<P0.Failure, P1.Failure>` work because parser `Failure` associated types have these bounds.

## Output

Commit with message following the repo's style. Return the commit hash and confirm:
- Build passes
- Tests pass
- Zero references to `Parser.Error.Either` remain in source
