---
title: Tool-Path Env-Var Fallback Pattern for Cross-Adopter Deployment
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-05-07
last_updated: 2026-05-07
applies_to:
  - swift-foundations/swift-linter
  - any institute tool deployed beyond the developer's workspace
---

# Context

The 2026-05-07 swift-linter pre-publishable discovery investigation
surfaced a runtime-resolution defect: `Lint.Driver` carried a hardcoded
fallback to `/Users/coen/Developer/swift-foundations/swift-linter` when
the `SWIFT_LINTER_PATH` environment variable was unset. The fallback
worked perfectly in the developer's local workspace and would have
silently misbehaved on the first non-developer adopter run — adopter
doesn't have that path → path resolution silently fails → empty
configuration → zero findings → adopter thinks linter is broken.

D1' execution removed the hardcoded fallback (now emits an explicit
error and returns the empty default Configuration when
`SWIFT_LINTER_PATH` is unset). The point fix is in place; the broader
question is whether the institute has a canonical pattern for this
class of "runtime resolution that works in the development environment
will silently work-but-misbehave in adopter environments" defect.

The defect class generalizes beyond swift-linter: any institute tool
that resolves a path / URL / endpoint via environment variable with a
developer-workspace-specific fallback has the same shape. Examples
that may carry the same class:

- Tools that read `<TOOL>_CONFIG_PATH` env var and fall back to a
  hardcoded developer config file path.
- Tools that read `<TOOL>_DATA_DIR` and fall back to a hardcoded
  developer data directory.
- Build-driver tools that resolve project roots via environment with a
  developer-workspace-specific fallback.

# Question

What is the institute's canonical pattern for tools deployed beyond
the developer's workspace, when the tool's runtime needs a path /
config / endpoint that varies per adopter?

Specifically:

1. **Env-var-or-fail vs env-var-or-fallback**: when SHOULD a tool
   fail loudly on missing env var vs. fall back to a sensible default?
2. **Acceptable fallback shapes**: when a fallback IS appropriate,
   what fallback shapes are acceptable (current working directory?
   well-known XDG paths? canonical install location?)? Hardcoded
   developer-workspace paths are obviously not.
3. **Diagnostic discipline**: when the env var is unset and the
   fallback fires, what's the right diagnostic discipline? Silent
   fallback (current pre-fix behavior — surfaces as "linter is
   broken")? Warning emit + fallback? Hard error + tool exits
   non-zero?
4. **Detection at release-readiness time**: should the
   release-readiness skill enforce a check for hardcoded
   developer-workspace paths in tool source? (Mechanical: grep for
   `/Users/`, `/home/<username>/`, `~/Developer/` patterns in tool
   source.)

# Prior Work

- `swift-foundations/swift-linter/Sources/Linter Library/Lint.Driver.swift`
  (post-fix at D1' commit `ba02932`).
- Reflection `2026-05-07-d1-readme-and-driver-repair.md` (the fix
  execution).
- Reflection `2026-05-07-swift-linter-pre-publishable-discovery-investigation.md`
  (the discovery).
- XDG Base Directory Specification (potential prior art for
  fallback-path conventions).
- `feedback_no_public_or_tag_without_explicit_yes.md` — analogous
  per-action authorization discipline for irreversible actions.

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does the institute already have any tool that's been hardened for
  cross-adopter deployment? If yes, what pattern did it use?
- For each of the 4 question axes above, enumerate the design space
  and recommend a canonical pattern.
- The release-readiness gate (per [RELEASE-007] / [RELEASE-008]
  pattern) for hardcoded-developer-workspace paths could be
  mechanical; spec the grep recipe.

# Options Considered

_To be expanded during investigation._

| Option | Shape | Where it fires |
|--------|-------|----------------|
| A — env-var-or-fail | Tool exits non-zero with explicit diagnostic if env var unset | Strict; safest; some adopter friction |
| B — env-var-or-warn-and-empty-default | Tool emits diagnostic, falls back to empty/no-op default | Current post-fix shape on swift-linter |
| C — env-var-or-XDG-fallback | Tool falls back to XDG paths (config: `$XDG_CONFIG_HOME/swift-linter/`, data: `$XDG_DATA_HOME/swift-linter/`) | Cross-adopter convention |
| D — env-var-or-cwd-walk | Tool walks parents of CWD looking for config marker | Convention from build tools (Cargo, npm) |

# Outcome

_Pending investigation._

# Cross-References

- [RES-013a] Synthesis Verification (the discovery investigation
  applied this rule by reading source rather than reasoning forward).
- [RELEASE-007] Empirical Example-Compile Gate (companion gate at
  release-readiness time for the README-non-compile failure class).
- [RELEASE-008] Filter-Parameter Runtime-Enforcement Test Gate
  (companion gate for the API-surface-vs-runtime-enforcement failure
  class).

# Provenance

Reflection `2026-05-07-swift-linter-pre-publishable-discovery-investigation.md` (action item 3).
