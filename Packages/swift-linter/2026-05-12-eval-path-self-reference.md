# Eval-path self-reference — `path: "."` thread

<!--
---
version: 2.0.0
last_updated: 2026-05-12
status: DECISION
---
-->

## Changelog

- **v2.0.0 (2026-05-12) — DECISION.** Closed via Option 1 (CLI-side
  normalization) per the platform-skill L3-unifier composition
  discipline. The `Linter Core` library stays kernel-free; the CLI
  binds the closure-injected cwd to `Kernel.Directory.Working` from
  swift-kernel (L3 unifier), which composes through L3-policy
  (`POSIX.Kernel.Directory.Working` at swift-posix) onto the L2 spec
  (`ISO_9945.Kernel.Directory.Working` at swift-iso-9945) per
  `[PLAT-ARCH-008e]`. Closure-injection keeps Linter Core unit-testable
  without kernel-tier deps. Closure SHAs land alongside this revision
  in the Thread B halt report (`HANDOFF-thread-b-rule-pack-dogfeed.md`).
- **v1.0.0 (2026-05-12)** — DEFERRED. Original framing: "no current
  consumer needs `path: '.'`; rule-pack repos are the trigger." The
  trigger fired with Thread B (foundation-up rule-pack dogfeed); the
  Option 1 implementation lands in this revision.

## Summary

The Shape-γ `Lint.swift` consumer manifest documents
`.package(path: ".")` as a self-reference to the consumer's own
package. The materializer's
`Lint.SingleFile.Materializer.resolveConsumerPath(_:relativeRoot:)`
correctly handles the path side (commit `595c138` Shape γ + `fe2c18e`
typed-path arithmetic) — it collapses `"."` to the eval-root-relative
path (`"../.."`). The package-name side landed partially in commit
`50d312b` (`Extractor.packageName: derive self-reference basename from
consumer root`) but still failed end-to-end when the CLI was invoked
as `swift-linter .`, because `basename(".") == "."` yields the same
SwiftPM-rejected literal.

Thread B closed the gap by canonicalizing `"."` → absolute path at the
CLI boundary, before any engine-side path arithmetic. The
`Lint.SingleFile.Extractor.packageName` derivation continues to handle
the self-reference case defensively for direct-API callers, but in
practice the CLI path now never threads `"."` through to the Extractor.

## What landed

### Linter Core — `canonicalize(consumerRoot:currentWorkingDirectory:)` helper

Public static helper on `Lint.SingleFile`:

```swift
@inlinable
public static func canonicalize(
    consumerRoot: Swift.String,
    currentWorkingDirectory: () -> Swift.String?
) -> Swift.String {
    if consumerRoot.isEmpty || consumerRoot == "." {
        return currentWorkingDirectory() ?? consumerRoot
    }
    return consumerRoot
}
```

Closure-injected cwd keeps the helper platform-neutral and unit-testable
without pulling kernel-tier deps into Linter Core. Five unit tests
cover the four shapes plus the cwd-unavailable fallback.

### Linter CLI — binds closure to `Kernel.Directory.Working.withCurrentBytes`

```swift
let consumerRoot = Lint.SingleFile.canonicalize(
    consumerRoot: paths.first ?? ".",
    currentWorkingDirectory: {
        try? Kernel.Directory.Working.withCurrentBytes { (span: Span<UInt8>) -> Swift.String in
            var bytes: [UInt8] = []
            bytes.reserveCapacity(span.count)
            for i in 0..<span.count {
                bytes.append(span[i])
            }
            return Swift.String(decoding: bytes, as: UTF8.self)
        }
    }
)
```

The CLI is the boundary between user-supplied paths and engine
internals. Per the platform skill, L3-foundations consumers compose
through the L3-unifier `Kernel` namespace (`import Kernel`); the CLI
imports the umbrella, the umbrella conditionally re-exports
`POSIX_Kernel_Directory` (POSIX) or (eventually)
`Windows_Kernel_Directory` (Windows symmetric exposure deferred until
a cross-platform consumer surfaces), and `Kernel.Directory.Working`
resolves via the `Kernel = POSIX.Kernel` typealias chain on POSIX.

### swift-kernel — Kernel umbrella exposes Directory

The `Kernel` umbrella target gained a conditional dependency on the
`POSIX Kernel Directory` product from swift-posix, plus
`@_exported public import POSIX_Kernel_Directory` in `Exports.swift`
(POSIX-only). The Descriptor / Socket re-export chain at the same site
established the pattern; Directory follows it.

### Linter Core — TODO removed from `Extractor.packageName`

The pointer at the deferred-doc TODO is gone. The doc-comment on
`Extractor.packageName(fromPath:consumerPackageRoot:)` now references
the canonicalize helper as the upstream resolution site rather than
naming the unfinished problem.

## Reproducer (now passes)

```bash
cd /Users/coen/Developer/swift-primitives/swift-cardinal-primitives
SWIFT_LINTER_PATH=/Users/coen/Developer/swift-foundations/swift-linter \
  /Users/coen/Developer/swift-foundations/swift-linter/.build/debug/swift-linter .
```

Pre-Thread-B: SwiftPM error `'eval': unknown package '.' in
dependencies of target 'Lint'`.

Post-Thread-B: dogfeed runs, materializes the eval project, emits
findings against the cardinal-primitives source tree.

## Architectural rationale

Per the **platform** skill `[PLAT-ARCH-002]` and `[PLAT-ARCH-008e]`:

- L3-foundations consumers (`swift-linter`, `swift-file-system`, etc.)
  MUST consume cross-platform abstractions through the L3-unifier
  (`swift-kernel`, `import Kernel`). Direct dep on L2 spec packages
  (`swift-iso-9945`) bypasses the unification discipline and locks the
  consumer to a specific platform's vocabulary.
- The L3-unifier composes its peer L3-policy tier (`swift-posix`,
  `swift-windows`); it never reaches across into L2.
- The Working-directory operation is canonical at L2
  (`ISO_9945.Kernel.Directory.Working`), wrapped at L3-policy
  (`POSIX.Kernel.Directory.Working`), unified at L3-unifier
  (`Kernel.Directory.Working` via the `Kernel = POSIX.Kernel`
  typealias chain on POSIX).

Earlier draft of this fix tried to add `swift-iso-9945` as a direct
dep of `Linter Core`. That direction was rejected: it bypasses the
L3-unifier and carries L2-spec coupling into a foundations consumer.
The current approach respects the layering.

## Cross-references

- Commit `595c138` (swift-foundations/swift-linter): Shape γ SingleFile
  Lint.swift dispatch with self-reference path fix — the matching
  path-side resolution.
- Commit `fe2c18e` (swift-foundations/swift-linter):
  Materializer.resolveConsumerPath typed-path arithmetic via
  File.Path — the typed-path infrastructure the path-side fix uses.
- Commit `50d312b` (swift-foundations/swift-linter):
  Extractor.packageName partial fix — defensive handling that
  Thread B's canonicalize helper now subsumes for the CLI path.
- swift-institute/Skills/platform/SKILL.md `[PLAT-ARCH-002]`,
  `[PLAT-ARCH-008e]` — the layering discipline that drove the Option 1
  CLI-boundary placement (vs the v1.0.0 brief's Option 2 / dispatch-
  level normalization).
- `swift-foundations/swift-linter-rules/Research/numerics-rule-recognizer-2026-05-12.md`
  v1.2.0 DECISION — the Phase B numerics Lint.swift pattern uses
  sibling-relative deps; the rule packs (Thread B) use `path: "."`
  self-reference, which this fix unblocks.
