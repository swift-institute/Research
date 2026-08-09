# Build and graph findings

This note records durable lessons from building the Institute graph. Current roster,
toolchain, target, product, checkout, and work-status facts belong to their authorities:
[`Institute.json`](Institute.json), `institute doctor`, `institute inventory`, and the
owning GitHub Issues. Do not copy their changing values into this document.

## The build coordinator serializes the machine

The coordinator owns SwiftPM execution and serializes builds across sessions. Running many
package builds concurrently does not make the machine perform independent work; they contend
for the same coordinator slot. Use `institute package build` or `institute build` so the
coordinator can account for the work and select the appropriate graph shape.

For a whole-selection build, the workspace path is the meaningful local-source measurement:
it resolves selected members from their materialized paths and compiles the shared closure in
one graph. A package build resolves dependencies from their declared remotes and therefore
cannot prove that a local edit in another checkout was compiled.

## What a build sweep cannot tell you

A successful sweep proves only the sources and graph that the command actually selected. It
does not by itself prove that every inventory entry was enumerated, that every target was in a
generated workspace, that resolution used canonical remote sources, or that a release build is
ready.

The population must be explicit and independently checked. Enumerate the inventory through
`institute inventory`, derive paths through `Institute.json`, and use a positive control that
must be observed. A zero from an unconfigured or empty instrument is not evidence of a clean
ecosystem.

## Why a clean build is often not evidence

Incremental state can make a command compile nothing. Conditional imports can remain excluded
after a dependency changes. A generated scheme can silently omit a target whose blueprint is
stale. For correctness claims, use the coordinator's fresh path and verify the generated
workspace against the manifests before building.

Exit status is not enumeration. A sweep that drops a package, target, or module without
reporting it can still exit successfully. Compare the command's measured population with an
independent enumeration, and treat an absent control or summary as unmeasured rather than
clean.

## The umbrella-root experiment

A synthetic root with `.package(path:)` dependencies is useful for studying graph composition,
but it is not committed and is not a replacement for the Workspace inventory. Path
dependencies override URL dependencies by identity, so this experiment can prove local-source
selection while also changing the resolution shape. Restore the consumer manifest before
sharing work, and use `institute verify` to report which source was actually compiled.

The command sequence is:

```sh
institute compose --consumer <consumer> --dependency <dependency>
institute verify --consumer <consumer> --dependency <dependency>
institute restore --consumer <consumer> --dependency <dependency>
```

`restore` is a structural check: it confirms that the manifest evaluates, the dependency is
declared by URL again, and no local path leaked. It does not resolve or build, so a green
result is not a clean-room reproducibility claim.
