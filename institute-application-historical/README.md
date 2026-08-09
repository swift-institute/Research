# institute-application — historical research

Documents relocated from the `swift-institute/institute-application` repository
root by TX-APP1Z, under Amendment 6 item 9 (swift-institute/.github#85 comment
5231144592). They are kept as a historical record of how the Institute
Application reached its end state; they are not maintained and are not the
current description of any package.

- `Local Resolution/` — the local-overlay and resolved-state design record
  (ADR-001, adjudications 001–002, wire shapes, capability matrix, baseline
  build and test evidence). Closes institute-application#62.
- `Identity Collisions/` — the one-off identity-collision check used while the
  package roster was being established.
- `BUILD-AND-GRAPH-FINDINGS.md` — build and dependency-graph findings from the
  pre-flatten Application layout.
- `TOOLCHAINS.md` — the toolchain notes kept at the Application root before the
  flatten.

Command lines quoted in these documents predate TX-APP1Z. They use the
`--package-path Application` layout and, in the oldest of them, the `workspace`
executable name; both were superseded when the package moved to the repository
root and the coordinator was renamed `institute`.
