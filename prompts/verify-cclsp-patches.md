# Verify CCLSP with Compilation Database

## Context

We've set up a compilation database approach for SourceKit-LSP:

1. **Compilation database** — 2845 entries across 328 modules from all three layers (primitives, standards, foundations), generated from swift-io's build manifest
2. **SourceKit-LSP config** — forces `defaultWorkspaceType: "compilationDatabase"` with background indexing enabled
3. **cclsp config** — `rootDir` points at the workspace root (no workspaceFolders)
4. **cclsp patches** — SourceKit-LSP adapter with higher timeouts (workspace/symbol: 120s, hover: 90s, etc.)

## Tests

### Test 1: find_definition across layers
Run `find_definition` on files from each layer. All should resolve instantly (compilation database lookup is O(1)).

```
find_definition(file_path="swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift", symbol_name="Buffer")
find_definition(file_path="swift-io/Sources/IO Primitives/IO.swift", symbol_name="IO")
```

**PASS**: Both return definition locations without timeout.
**FAIL**: Timeout or error.

### Test 2: get_hover
```
get_hover(file_path="swift-io/Sources/IO Primitives/IO.swift", line=14, character=13)
```

**PASS**: Returns type information.
**FAIL**: Timeout.

### Test 3: find_workspace_symbols
```
find_workspace_symbols(query="Buffer")
find_workspace_symbols(query="IO")
```

**PASS**: Returns symbols from the compilation database.
**FAIL**: Empty or timeout.

### Test 4: find_references (cross-layer)
Find a type used across layers. Memory types are used everywhere:
```
find_references(file_path="swift-memory-primitives/Sources/Memory Primitives Core/Memory.Address.swift", symbol_name="Address")
```
(Adjust file path if needed — find it first with Glob for `**/Memory.Address.swift` under swift-memory-primitives)

**PASS**: Returns references from multiple layers (primitives AND foundations).
**FAIL**: Only one layer or timeout.

### Test 5: Speed check
Run Test 1 again after Tests 2-4. The second run should be noticeably faster (index warmed).

## Diagnostics

If tests fail, check:
1. The compilation database exists at the workspace root (~13 MB)
2. SourceKit-LSP config has `defaultWorkspaceType: "compilationDatabase"`
3. cclsp config has `rootDir` pointing at the workspace root
4. cclsp adapter is present in the installed cclsp package
5. Process check: `ps aux | grep cclsp` — should show a NEW process (started after this session), not the old one from 12:00PM
