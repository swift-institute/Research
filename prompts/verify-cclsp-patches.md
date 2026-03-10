# Verify CCLSP with Compilation Database

## Context

We've set up a compilation database approach for SourceKit-LSP:

1. **`/Users/coen/Developer/compile_commands.json`** — 2845 entries across 328 modules from all three layers (primitives, standards, foundations), generated from swift-io's build manifest
2. **`/Users/coen/Developer/.sourcekit-lsp/config.json`** — forces `defaultWorkspaceType: "compilationDatabase"` with background indexing enabled
3. **`~/.claude/cclsp.json`** — `rootDir: "/Users/coen/Developer"` (no workspaceFolders)
4. **cclsp patches** — SourceKit-LSP adapter with higher timeouts (workspace/symbol: 120s, hover: 90s, etc.)

## Tests

### Test 1: find_definition across layers
Run `find_definition` on files from each layer. All should resolve instantly (compilation database lookup is O(1)).

```
find_definition(file_path="/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift", symbol_name="Buffer")
find_definition(file_path="/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Primitives/IO.swift", symbol_name="IO")
```

**PASS**: Both return definition locations without timeout.
**FAIL**: Timeout or error.

### Test 2: get_hover
```
get_hover(file_path="/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Primitives/IO.swift", line=14, character=13)
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
find_references(file_path="/Users/coen/Developer/swift-primitives/swift-memory-primitives/Sources/Memory Primitives Core/Memory.Address.swift", symbol_name="Address")
```
(Adjust file path if needed — find it first with Glob for `**/Memory.Address.swift` under swift-memory-primitives)

**PASS**: Returns references from multiple layers (primitives AND foundations).
**FAIL**: Only one layer or timeout.

### Test 5: Speed check
Run Test 1 again after Tests 2-4. The second run should be noticeably faster (index warmed).

## Diagnostics

If tests fail, check:
1. `ls /Users/coen/Developer/compile_commands.json` — file exists, ~13 MB
2. `cat /Users/coen/Developer/.sourcekit-lsp/config.json` — has `defaultWorkspaceType: "compilationDatabase"`
3. `cat ~/.claude/cclsp.json` — has `rootDir: "/Users/coen/Developer"`
4. `grep SourceKitLSPAdapter ~/.npm/_npx/8c82866c3920cdae/node_modules/cclsp/dist/index.js` — adapter present
5. Process check: `ps aux | grep cclsp` — should show a NEW process (started after this session), not the old one from 12:00PM
