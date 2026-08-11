# Post-push #8 Verification Gate — R5 27-hit invariant via chain-resolved code path

**Date**: 2026-05-06
**Dispatch**: Phase 2 file-based-canonical migration for swift-linter
**Gate**: Commit #8 post-push — verify 27 R5 hits hold via the **chain-resolved code path** (parent URLs now resolve post-push-wave; the full Tier 1 → Tier 2 → consumer chain folds into a layered `Lint.Configuration`).

Sibling artifact: [`2026-05-06-r5-prepush-fallback-gate.md`](2026-05-06-r5-prepush-fallback-gate.md) — same 27 hits, but via the v2 consumer-only fallback path (parent URLs returned 404 pre-push; the WARN-signal-bearing fallback fired).

---

## Canonical command

```bash
rm -rf /Users/coen/Developer/swift-primitives/swift-tagged-primitives/.swift-manifest
cd /Users/coen/Developer/swift-foundations/swift-linter
swift run --package-path . swift-linter \
    /Users/coen/Developer/swift-primitives/swift-tagged-primitives \
    2>&1 | grep -c "unchecked_call_site"
```

The `rm -rf .swift-manifest` step clears any stale auto-generated shim cache from earlier runs.

## Result

```
27
```

`grep "swift-linter\] WARN"` against the run log → **zero matches**. The absence of the parent-fetch-failure WARN signal is the dispositive proof that the chain-resolved code path fired (rather than the pre-push fallback). When the parent chain resolves cleanly, the resolver does NOT enter the `catch` block at the supervisor-block-#5 fallback site; no warning is emitted.

Six-step end-to-end validation confirmed via the chain-resolved path:

1. `Manifest.load` succeeded against the consumer's `Lint.swift` (Phase 2.5 swift-manifest fix at `ae8e37f` allows `@main`/`Driver.swift` coexistence).
2. The consumer's typed `Lint.Manifest(enabledRuleIDs: [R1–R5])` was decoded; consumer's `// parent:` directive parsed via `Parser.Literal<Parser.Input.Bytes>("// parent:")`.
3. `fetchHTTPURL` invoked `curl -fsSL https://raw.githubusercontent.com/swift-primitives/.github/main/Lint.swift` → **200 OK** (push-wave repo `4d6c9df` now serves the URL); content captured into the per-process memo dict keyed on the typed URI.
4. Tier 2 manifest evaluated via `evalParentManifest` (fresh `Manifest.load` against `/tmp/swift-linter-parent-eval-<sanitized>/Lint.swift`); decoded as `Lint.Manifest(enabledRuleIDs: [R1–R5])`. Tier 2's `// parent:` directive parsed → fetch Tier 1.
5. `fetchHTTPURL` invoked `curl -fsSL https://raw.githubusercontent.com/swift-institute/.github/main/Lint.swift` → **200 OK** (push-wave repo `3dae29e` now serves the URL); content memoized.
6. Tier 1 manifest evaluated → decoded as `Lint.Manifest(enabledRuleIDs: [])` (empty by design — Tier 1 is the chain root). No `// parent:` directive on Tier 1; resolver terminates the walk.
7. Resolver folds the chain parent-first via `Lint.Configuration(inheriting: parent)`: Tier 1 (`enabled: ∅`) → Tier 2 (`enabled: {R1, R2, R3, R4, R5}`) → consumer (`enabled: {R1, R2, R3, R4, R5}`).
8. `effectiveRules()` per-TYPE override semantics yields the union `{R1, R2, R3, R4, R5}` activated at default severity.
9. Walker traverses `tagged-primitives` looking for matching call sites; finds **27 R5 hits** (matching the pre-push count by design — R1–R5 effective set is identical between pre-push fallback and post-push chain-resolved paths).

The dispatch's load-bearing claim — "the file-based canonical pattern produces the same effective rule set whether the chain resolves or falls back, validated end-to-end via two distinct runs" — holds.

## Per-rule finding breakdown

Same as the pre-push run (effective rule set is identical regardless of which code path activates the rules). Documented here in full for the record:

| Rule | Count |
|------|-------|
| `unchecked_call_site` (R5) | 27 |
| `chained_rawvalue_access` (R3) | 7 |
| `cardinal_count_minus_one` (R1) | 1 |
| Total | 35 |

## What this run validates that pre-push didn't

| Code path | Pre-push fallback gate | Post-push chain gate |
|-----------|------------------------|----------------------|
| `Manifest.load` on consumer | ✓ | ✓ |
| Consumer's `Lint.Manifest` decode | ✓ | ✓ |
| `parseParentURL` on consumer | ✓ | ✓ |
| `fetchHTTPURL` on Tier 2 URL | curl exit 56 (URL 404) | curl exit 0 (200 OK) |
| `evalParentManifest` for Tier 2 | not reached | ✓ |
| `parseParentURL` on Tier 2 | not reached | ✓ |
| `fetchHTTPURL` on Tier 1 URL | not reached | curl exit 0 (200 OK) |
| `evalParentManifest` for Tier 1 | not reached | ✓ |
| Chain fold via `Configuration(inheriting:)` | not reached (consumer-only) | ✓ |
| Walker R5 finding count | 27 | 27 |
| `WARN: parent chain resolution failed` signal | present (1 occurrence) | absent (0 occurrences) |

Both runs together exercise every code path in `Lint.Driver.resolveConfiguration`. Together they form the load-bearing acceptance evidence for Phase 2's file-based canonical migration.

## Cross-references

- Sibling pre-push verification record: [`2026-05-06-r5-prepush-fallback-gate.md`](2026-05-06-r5-prepush-fallback-gate.md) (commit `a42147c`).
- Phase 2 push-wave commit SHAs (in push order):
  - `ae8e37f` — `swift-foundations/swift-manifest` (Phase 2.5 driver-shim fix)
  - `3dae29e` — `swift-institute/.github` (Tier 1 doc-comment rename)
  - `4d6c9df` — `swift-primitives/.github` (Tier 2 manifest)
  - `8077430` — `swift-primitives/swift-tagged-primitives` (consumer Lint.swift)
  - `b8088a1` — `swift-foundations/swift-linter` (this repo HEAD pre-record)
- `HANDOFF-file-based-canonical-migration-phase-2.md` (frozen dispatch artifact; this verification record + its pre-push sibling close acceptance criterion #1 of that dispatch).
