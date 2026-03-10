# Verify CCLSP Patches for Workspace-Wide Symbol Search

## Context

We patched the local cclsp MCP server (npx cache at `/Users/coen/.npm/_npx/8c82866c3920cdae/node_modules/cclsp/dist/index.js`) with three changes:

1. **SourceKit-LSP adapter** — custom timeouts (workspace/symbol: 120s, hover: 90s, references: 120s, call hierarchy: 90s) instead of the default 30s
2. **`workspaceFolders` support** — reads `workspaceFolders` array from config and sends all entries in the LSP initialize request
3. **Config** (`~/.claude/cclsp.json`) — declares three monorepo roots as workspace folders

## What to verify

### Test 1: Adapter is active
Run `find_workspace_symbols` with query "Buffer". Before the patch this timed out at 30s. With the patch it should either:
- Return results (success), or
- Timeout at 120s (adapter active but SourceKit-LSP still building)
- If it times out at 30s, the adapter patch is NOT active

### Test 2: Workspace folders are sent
Run `find_definition` on files in TWO DIFFERENT monorepos:
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift` — symbol "Buffer"
- `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.swift` — symbol "IO" (adjust path if needed; find the file first with Glob)

Both should resolve definitions. If only one works, workspace folders may not be sent correctly.

### Test 3: Hover works
Run `get_hover` on Buffer.swift line 22, character 13. Before the patch this timed out at 30s. With 90s timeout it should return type information.

### Test 4: Workspace symbol search across packages
After Tests 2-3 trigger implicit workspace creation for multiple packages, run `find_workspace_symbols` again for "Buffer" and for "IO". Both should return results (since their implicit workspaces should now exist).

### Test 5: Cross-package references
Run `find_references` for a type used across packages (e.g., "Memory.Address" or "Storage" — something from primitives used in foundations).

## How to report

For each test, report:
- **PASS**: what was returned
- **FAIL**: the error message and timeout duration
- **PARTIAL**: what worked and what didn't

Also check stderr of the cclsp process for debug output:
```bash
ps aux | grep cclsp | grep -v grep
```

If the adapter is active, you should see `Found server for swift: sourcekit-lsp (rootDir: ...)` in the MCP server stderr.

## If tests fail

Check:
1. Is the patched npx cache (`8c82866c3920cdae`) the one being used? `ps aux | grep cclsp`
2. Is the SourceKitLSPAdapter class present in the loaded file? `grep "SourceKitLSPAdapter" /Users/coen/.npm/_npx/8c82866c3920cdae/node_modules/cclsp/dist/index.js`
3. Is `workspaceFolders` in the config? `cat ~/.claude/cclsp.json`
4. Was cclsp restarted AFTER the patches? (Process start time should be after the patch time)
