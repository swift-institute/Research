# Underscore API Elimination Audit

## Goal

Inventory every underscore-prefixed identifier (`_foo`, `__bar`) in swift-file-system and its relevant upstream packages. For each, determine: is this underscore hiding something that should be public API, or papering over a missing abstraction? Everything is on the table — breaking changes, big refactors, upstream changes.

The north star: **all behavior flows through canonical, public, named API**. Underscores signal "I couldn't figure out the right API yet" — this audit figures it out.

## Skills to Load

`/implementation`, `/naming`, `/existing-infrastructure`

## Scope

Primary:
- `/Users/coen/Developer/swift-foundations/swift-file-system/`

Upstream (follow underscore chains into these when referenced):
- `/Users/coen/Developer/swift-foundations/swift-kernel/`
- `/Users/coen/Developer/swift-foundations/swift-paths/`
- `/Users/coen/Developer/swift-foundations/swift-io/`
- `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/`
- `/Users/coen/Developer/swift-primitives/swift-identity-primitives/`

## Research Tasks

### 1. Full Inventory

Grep for all underscore-prefixed identifiers across swift-file-system sources (both FSP and FS modules). For each, record:

| Identifier | File:Line | Visibility | Category | Purpose |
|-----------|-----------|------------|----------|---------|
| `_foo` | `File.swift:42` | internal/package/private | stored property / method / init / helper | why it exists |

Categories to watch for:
- **Stored properties** (`_descriptor`, `_storage`, `_stream`, `_finished`) — are these hiding a missing accessor pattern?
- **Helper methods** (`_writeAll`, `_walkCallback`, `_mapKernelError`, `_matchPaths`, `_makeInfo`) — are these implementation details that should be Property accessors, or genuine private helpers?
- **Init labels** (`__unchecked`) — are these upstream patterns that force downstream underscore usage?
- **Resolution helpers** (`_resolvingPOSIX`, `_normalizingWindows`) — are these hiding a missing Path API?
- **Error mapping** (`_mapKernelError`, `_mapKernelReadError`, `_lstatEntryType`) — are these hiding a missing error conversion protocol?

### 2. Classify Each Underscore

For each identifier, classify into one of:

**A. Should be public API** — The underscore hides functionality that consumers need. Design the public name per [API-NAME-001] and [API-NAME-002].

**B. Should be a Property accessor** — The underscore hides a verb-as-property pattern. Design using `Property<Tag, Base>` per [INFRA-106]. Example: `_writeAll` → `write.all` or similar.

**C. Should be eliminated by upstream fix** — The underscore exists because an upstream type doesn't expose what's needed. Identify the upstream change. Example: `_descriptor.kernelDescriptor` chains suggest Handle should expose the descriptor differently.

**D. Correct as internal** — Genuine implementation detail that has no business being public. Document why. These should be rare — most "implementation details" are actually missing abstractions.

**E. Should be inlined / deleted** — The helper exists because of a language limitation that has since been resolved, or because code was written before a better pattern existed.

### 3. Trace Upstream Underscore Dependencies

For each Category C identifier, trace into the upstream package:
- What type/method is being accessed?
- What's the public API gap?
- What would the fix look like?

Pay special attention to:
- `Tagged.__unchecked` init pattern — is this forcing downstream `__unchecked` usage? Should there be labeled public inits?
- `Kernel.File.Stats` field access — are consumers reaching through too many layers?
- `File.Path.__unchecked` inits — are these hiding missing Path construction APIs?
- `Kernel.IO.Read.read` / `Kernel.IO.Write.write` returning bare `Int` — should these return typed counts?

### 4. Design Replacements

For each Category A and B identifier, propose the replacement API. Follow these constraints:

- [API-NAME-001]: Nest.Name pattern. No compound type names.
- [API-NAME-002]: No compound method/property names. Use nested accessors.
- [IMPL-INTENT]: Intent over mechanism. The name should express what, not how.
- [INFRA-106]: Use Property<Tag, Base> for verb-as-property accessors.
- [IMPL-020]: Use `_read`/`_modify` coroutines for accessor implementation.

For each replacement, show:
1. Current call site
2. Proposed call site
3. Implementation sketch (just the signature + delegation, not full body)

### 5. Prioritize

Rank all findings by:
1. **Public API surface impact** — underscores visible to consumers (package/public) first
2. **Call site count** — most-referenced underscores first
3. **Upstream chain depth** — shallow fixes before deep ones

### 6. Check for Naming Violations in Non-Underscore API

While scanning, also flag any public API that violates [API-NAME-002] (compound method names) that wasn't caught in the M-1 audit. The previous audit found `iterateFiles`, `iterateDirectories`, `lstatInfo`, `seekToEnd` — there may be more.

## Output

Write findings to `/Users/coen/Developer/swift-institute/Research/underscore-api-elimination-audit.md`. Return ONLY a one-line confirmation.

## Governing Principles

1. **Underscores are debt, not design.** Every `_` is a question: "what's the real name?"
2. **If it's called from outside the type, it's API.** Internal helpers called from multiple files deserve a name.
3. **Follow the chain.** An underscore in file-system often points to a missing abstraction in kernel or paths.
4. **Breaking changes are fine.** This is timeless infrastructure — get it right, not compatible.
5. **Read before proposing.** Understand why each underscore exists before suggesting removal.
