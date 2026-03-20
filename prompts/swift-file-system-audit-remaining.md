# swift-file-system Deep Audit — Remaining Phases

## Context

You are continuing a deep audit of swift-file-system. Three phases are complete (committed):
- **Phase 1-2** (f2837b9): Dead code removal (-1290 lines), all typed throws workarounds eliminated
- **Phase 3** (e4f270c): Walk consolidation (3→1), Glob consolidation (6→1), error mapping, IO.Closable
- **C-1** (98ea137): All bare throws eliminated via `Either<Operation.Error, E>`
- **Platform fix** (598be56): Dead platform conditional imports removed

The audit document is at:
`/Users/coen/Developer/swift-institute/Research/swift-file-system-deep-audit.md`

Read it first — it has the complete finding inventory with current statuses.

## Package Location

`/Users/coen/Developer/swift-foundations/swift-file-system/`
- 47 files in File System Primitives, 32 in File System
- 709 tests across 329 suites, all passing
- Build: clean

## Skills to Load

`/naming`, `/errors`, `/code-organization`, `/implementation`

## Work Items

Execute in the order listed. Build and test after each item. Do NOT proceed to the next item if tests fail.

---

### Item 1: File Splitting (M-2) — Mechanical

Split 6 files that declare multiple types, per [API-IMPL-005] (one type per file).

| Current File | Extra Type(s) | New File(s) |
|-------------|---------------|-------------|
| `File.Name.swift` | `RawEncoding` | `File.Name.RawEncoding.swift` |
| `File.Directory.Contents.swift` | `Control` | `File.Directory.Contents.Control.swift` |
| `File.Directory.Contents.Iterator.swift` | `IteratorHandle` | `File.Directory.Contents.IteratorHandle.swift` |
| `File.Directory.Walk.swift` | `InodeKey` (internal) | `File.Directory.Walk.InodeKey.swift` |
| `File.System.Create.swift` | `Options` | `File.System.Create.Options.swift` |
| `File.System.Create.Directory.swift` | `Options`, `Error` | `File.System.Create.Directory.Options.swift`, `File.System.Create.Directory.Error.swift` |

For each split:
1. Read the current file to find the type declaration and all its extensions
2. Move the type declaration + extensions to the new file
3. Keep the correct imports in both files
4. The new file contains ONLY the extracted type and its extensions — nothing else

`InodeKey` is `internal` — the new file still uses `internal` visibility.

Build + test after all 6 splits.

---

### Item 2: Naming Compliance (M-1) — Breaking API

These are [API-NAME-002] violations (compound method/property names). All are breaking changes.

**2a: Walk iteration methods**

In `File.Directory.Walk.swift`:
- `iterateFiles(options:body:)` → rename to a non-compound form
- `iterateDirectories(options:body:)` → rename to a non-compound form

Since Walk is already a namespace struct with nested accessors (`dir.walk.iterate { }`), the natural pattern is:

```swift
// Current:
dir.walk.iterateFiles { file in ... }
dir.walk.iterateDirectories { dir in ... }

// Option A — parameter-based filtering (simpler):
dir.walk.iterate(kind: .files) { entry in ... }
dir.walk.iterate(kind: .directories) { entry in ... }

// Option B — nested struct accessors:
dir.walk.files { file in ... }
dir.walk.directories { dir in ... }
```

Read the current implementations — `iterateFiles` and `iterateDirectories` are thin filters that delegate to `iterate`. Choose the cleanest approach. Option B is more aligned with existing ecosystem patterns (Walk.files, Walk.directories as callable).

**2b: Stat method**

In `File.System.Stat.swift` (File System Primitives):
- `lstatInfo(at:)` → `info(at:followSymlinks: false)` or similar that distinguishes stat vs lstat

Read the file first. There may be both `info(at:)` (stat, follows symlinks) and `lstatInfo(at:)` (lstat, doesn't follow). Unify into `info(at:followSymlinks: Bool = true)`.

**2c: Handle seek**

In `File.Handle.swift` (File System module):
- `seekToEnd()` → evaluate. If Handle already has a `seek` namespace or method, add `.toEnd()` variant. If not, `seek.toEnd()` requires a Seek namespace struct.

Read the file first to understand what seek methods exist.

**2d: Update tests**

All test files that call the renamed methods need updating. Grep for the old names across `Tests/`.

Build + test after all renames.

---

### Item 3: ExpressibleByStringLiteral (L-2) — Quick Fix

`File` and `File.Directory` have doc comments claiming string literal conformance but the conformance is missing.

Check `Sources/File System Primitives/File.swift` and `Sources/File System Primitives/File.Directory.swift` for the type declarations. Add:

```swift
extension File: ExpressibleByStringLiteral {
    public init(stringLiteral value: Swift.String) {
        self.init(File.Path(value))
    }
}
```

Same for `File.Directory`. Verify `File.Path` has an init from `String` first.

---

### Item 4: Walk.Error / Contents.Error Overlap (L-6) — Evaluate

Both define `.pathNotFound`, `.permissionDenied`, `.notADirectory`. Walk maps Contents errors to its own type in `_walkCallback`.

Read both error types. Evaluate whether Walk.Error should contain Contents.Error as a case (`.contents(Contents.Error)`) instead of duplicating the cases + manual mapping. This would eliminate the switch-based error mapping in `_walkCallback` (lines 308-323).

If the unification is clean, do it. If it creates more complexity than it removes, skip it and document why in the audit.

---

### Item 5: Handle.Open / Descriptor.Open Duplication (L-3) — Evaluate

~70% structural overlap between `File.Handle.Open` and `File.Descriptor.Open`.

Read both files:
- `Sources/File System/File.Handle.Open.swift`
- `Sources/File System/File.Descriptor.Open.swift`

Evaluate whether a shared `_scoped` implementation can serve both, with Handle.Open delegating through Descriptor.Open. If the duplication is truly structural and the shared extraction is clean, do it. If Handle.Open has enough distinct logic (e.g., Handle-specific setup/teardown beyond descriptor open/close), skip it.

---

### Item 6: Remaining Low-Priority Findings — Assess and Skip or Fix

For each, read the relevant code and make a judgment call:

- **M-3** (raw Int arithmetic in Handle/Read.Full/Stat): Only fix if the typed count infrastructure already exists and the change is mechanical. Don't add new typed count types just for this.
- **M-9** (Path._resolvingPOSIX ad-hoc strings): Only fix if Paths already provides the needed APIs.
- **M-10** (Handle._pwrite/_pwriteAll): Document as deferred — needs design discussion.
- **M-12** (Walk.Options.onUndecodable closure): Skip — the closure pattern works and provides maximum flexibility.
- **L-5** (Binary.Serializable premature conformances): Skip — removing conformances is also a breaking change.
- **L-7** (File.Path.Property novel pattern): Skip — 2 properties isn't worth refactoring.

---

## Governing Principles

1. **Subtract before adding.** Unify before extending. Remove before replacing.
2. **Every finding must cite specific file paths and line numbers.**
3. **Do NOT fix anything without verifying it compiles (`swift build`) and tests pass (`swift test`).**
4. **Read before writing.** Understand existing code before modifying.
5. **If a fix creates more complexity than it removes, skip it and document why.**

## After All Work

Update the audit document at `/Users/coen/Developer/swift-institute/Research/swift-file-system-deep-audit.md`:
- Mark completed findings as resolved with the phase/commit
- Update the statistics table
- Update file counts if files were added (splits) or removed

Commit with a descriptive message following the repo's existing style (see `git log --oneline -5`).
