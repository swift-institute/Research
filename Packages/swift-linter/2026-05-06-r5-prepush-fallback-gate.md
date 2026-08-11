# Pre-push #8 Verification Gate — R5 27-hit invariant via v2 consumer-only fallback

**Date**: 2026-05-06
**Dispatch**: Phase 2 file-based-canonical migration for swift-linter
**Gate**: Commit #8 pre-push — verify 27 R5 hits hold via the v2 consumer-only fallback code path (parent URLs return 404 because the .github repos haven't been pushed yet).

---

## Canonical command

```bash
rm -rf /Users/coen/Developer/swift-primitives/swift-tagged-primitives/.swift-manifest
cd /Users/coen/Developer/swift-foundations/swift-linter
swift run --package-path . swift-linter \
    /Users/coen/Developer/swift-primitives/swift-tagged-primitives \
    2>&1 | grep -c "unchecked_call_site"
```

The `rm -rf .swift-manifest` step clears any stale auto-generated shim cache from earlier runs (relevant after the Phase 2.5 swift-manifest fix renamed `main.swift` → `Driver.swift`; without the cache clear, both files coexist in the cache and produce a redeclaration error).

## Result

```
27
```

Six-step end-to-end validation confirmed:

1. `Manifest.load` succeeded against the consumer's `Lint.swift` (Phase 2.5 swift-manifest fix at `ae8e37f` is locally present; the `Driver.swift` filename rename allows `@main` to coexist with the imports).
2. The consumer's typed `Lint.Manifest(enabledRuleIDs: [R1–R5])` was JSON-encoded by the shim, captured by the parent process, and decoded back into a typed `Lint.Manifest` value with the rule-ID set intact.
3. `parseParentURLFromContent` extracted the `// parent: https://raw.githubusercontent.com/swift-primitives/.github/main/Lint.swift` URL from the consumer's source trivia (parser-primitive composition fired: `Parser.Literal<Parser.Input.Bytes>("// parent:")` matched, byte-level scan extracted the URL bytes, scheme prefix validated, `try URI(...)` parsed the typed `URI`).
4. `fetchHTTPURL` invoked `curl -fsSL` against the typed URI; `Process.Spawn.run` returned exit code 56 (curl could not resolve / reach host — the `.github` repo isn't pushed yet, so the raw URL doesn't exist).
5. `fetchHTTPURL` threw `Lint.Run.Error.parentFetchFailed(url:exitCode:stderr:)` with the typed URI; `resolveParentChain` propagated; `resolveConfiguration`'s catch block at the supervisor-block-#5 fallback site fired.
6. The catch block returned `configuration(from: consumerManifest, parent: nil)` — the consumer-only Configuration with the consumer's enabledRuleIDs (R1–R5) driving rule activation. Walker found 27 R5 sites across the package.

## Stderr evidence

```
[swift-linter] WARN: parent chain resolution failed: parentFetchFailed(url: RFC 3986.URI, scheme: https, host: raw.githubusercontent.com, path: /swift-primitives/.github/main/Lint.swift, exitCode: 56, stderr: ""); proceeding with consumer-only configuration.
```

This message is the dispositive proof that step 5 fired. Without the v2 path being reachable, this line could not appear (the v1-default fallback at `defaultConfiguration()` does not invoke `parseParentURL` or `fetchHTTPURL` at all).

## Per-rule finding breakdown

| Rule | Count |
|------|-------|
| `unchecked_call_site` (R5) | 27 |
| `chained_rawvalue_access` (R3) | 7 |
| `cardinal_count_minus_one` (R1) | 1 |
| Total | 35 |

The 27 R5 hits is the load-bearing baseline — established at commit `31bfd4f` (Phase 1.5) and maintained as the verification gate ever since.

## Note on dispatch-document command discrepancy

`HANDOFF-file-based-canonical-migration-phase-2.md:315` literally specified the path argument as `tagged-primitives/Sources` — that command produces 0 R5 hits and exercises NEITHER the v2 manifest evaluation path NOR the parent-chain fallback path because:

1. The CLI uses `paths.first` as `consumerPackageRoot`. Sources/ has no `Lint.swift`, so `lintSwiftPath` returns nil, the driver falls back to `defaultConfiguration()` immediately. The v2 path never fires.
2. Sources/ contains zero `__unchecked:` (double-underscore) call sites — verified directly via `grep -rEcn "\b__unchecked:" tagged-primitives/Sources/`. R5's matchable sites live in Experiments/ and Tests/, not Sources/.

The dispatch document's literal command was authored before the linter's path-handling semantics were validated end-to-end. The canonical command is the package-root form documented in this verification record. The dispatch document remains a frozen audit artifact — this verification record is the correction.

## Acceptance status

**Pre-push #8 gate: PASSED via the v2 consumer-only fallback code path.**

The post-push #8 verification record (planned post-push-wave) will follow the same canonical-command shape; the WARN line will be ABSENT from that run because the parent chain will resolve cleanly once the `.github` repos are pushed.

## Cross-references

- Phase 2 commits #1–#4.5 + #3.5 at `swift-foundations/swift-linter` (HEAD `e6e0534`)
- Phase 2 commits #5/#6/#7 at `swift-institute/.github` (`40810f3`), `swift-primitives/.github` (`4d6c9df`), `swift-primitives/swift-tagged-primitives` (`8077430`)
- Phase 2.5 swift-manifest fix at `swift-foundations/swift-manifest` (`ae8e37f`) — prerequisite for `Manifest.load` to succeed
- `HANDOFF-file-based-canonical-migration-phase-2.md` (frozen dispatch artifact; literal command at line 315 is corrected by this verification record per Q2 of the post-Phase-2.5 supervisor exchange)
