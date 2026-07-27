# Context projection needs whole-corpus validation

A path-scoped audit reduced the Swift Institute skill hubs but missed oversized
Rule Institute skills that the same entrypoint also projects. The mistake became
visible only after the 500-line limit moved into Workspace's Swift context
validator and ran across every canonical projection source.

The durable rule is to enforce context invariants at the projection boundary,
where the complete installed population is known. Hand-written scans remain
useful for editing, but they are not the acceptance gate for a multi-root
context system.
