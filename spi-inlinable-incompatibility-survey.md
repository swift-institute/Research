# @_spi + @inlinable Incompatibility Ecosystem Survey

| Field | Value |
|-------|-------|
| Tier | 2 |
| Scope | Ecosystem-wide @_spi / @inlinable usage audit |
| Status | OPEN |
| Provenance | 2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md |

## Context

`@_spi(X)` and `@inlinable` cannot coexist when the `@inlinable` body references symbols from another module that could plausibly be `@_spi`-gated in the future. `swift-posix`'s Read/Write wrappers are one such site; `swift-posix`'s Flush and Socket wrappers are likely siblings. Any L3 platform-policy layer that delegates to L2 raw via `@inlinable` is a potential site.

## Question

Which modules in the ecosystem have `@inlinable public` functions whose bodies reference symbols from another module that could plausibly be `@_spi`-gated? And for each, is the incompatibility already blocking, or latent?

## Procedure

```bash
# Inventory @inlinable public functions in L3 platform-policy packages:
grep -rnE "^@inlinable\s+public" swift-posix/Sources/ swift-darwin/Sources/ swift-linux/Sources/ swift-windows/Sources/

# For each site, identify the L2 symbols it references:
# (manual review; cross-module symbol reference pattern depends on the code)
```

## Analysis (pending)

For each site found:

1. Name the `@inlinable` function.
2. List the L2 symbols it references.
3. Flag whether any of those symbols is `@_spi`-gated today OR is a plausible `@_spi` candidate given the package's stability story.
4. Classify: blocking / latent / benign.

## Outcome (pending)

Determines whether `@_spi(Syscall)` is a usable tool for L2/L3 disambiguation ecosystem-wide or fundamentally limited to non-inlinable boundaries. Feeds into the platform skill's [PLAT-ARCH-008e] and [PLAT-ARCH-008f] discipline.

## References

- Reflections: 2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md
- memory: `feedback_inlinable_blocks_internal_import.md`
