# Remediation playbooks

Per-rule guidance for taking a rule's findings to zero, for the classes where the diagnostic
message cannot carry the whole answer.

Every rule in this package states its default disposition and its recognized exemptions in its
own diagnostic message, so most findings are actionable where they are reported. Five rules are
not like that. They are the largest classes in the fleet compliance ledger, their lawful fix is
a judgment rather than a substitution, and the decision tree, the ripple handling, and the
worked examples do not fit in a diagnostic string. These documents are that overflow.

## The rules

Counts are from the fleet compliance ledger of 2026-08-02, the most recent recorded ledger at
authoring time.

| Playbook | Findings | Rewriter |
|---|---|---|
| [compound identifier](remediation-compound-identifier.md) | 4,303 | None possible — restructure, not rename |
| [minimal type body](remediation-minimal-type-body.md) | 2,407 | Filed: value types only ([#43](https://github.com/swift-foundations/swift-institute-linter-rules/issues/43)) |
| [extension file naming](remediation-extension-file-naming.md) | 1,418 | Not expressible — the fix is a rename |
| [bare string dependency](remediation-bare-string-dependency.md) | 1,377 | Gated on a manifest fix scope ([swift-linter#32](https://github.com/swift-foundations/swift-linter/issues/32)) |
| [suite categories](remediation-suite-categories.md) | 1,276 | Filed: additive, bounded refusals ([#44](https://github.com/swift-foundations/swift-institute-linter-rules/issues/44)) |

## Read this first

[remediation-mechanics.md](remediation-mechanics.md) holds everything that is the same whichever rule fired: the
rewriter-first path and the engine's fix contract, how to judge and propagate a rename's ripple
with cclsp, the lawful shape of a suppression and which reasons qualify, batching, and the
per-finding verification step. Each playbook links it rather than restating it.

## How these are meant to be used

Work one rule at a time, in one package at a time. Each playbook opens with what its rule
actually flags — as the predicate is written, which is not always the same as how the convention
is described — then gives the decision tree, then the shapes that are legitimately left alone.

A playbook is correct only against the predicate it documents. When a rule changes, its playbook
changes in the same pull request; that co-location is why these live beside the rules rather
than in a research record.

## Scope

These document remediation, not the conventions themselves. Where a convention has a canonical
statement elsewhere in the ecosystem's development guidance, the playbook points at it and does
not restate it — the convention and its enforcement have different owners, and duplicating one
into the other is how they drift apart.

## Why these live under `Research/`

They are evergreen operational documents rather than dated investigation records, so the
directory name is a compromise rather than a description. It is the compromise the repository's
structure asks for: the canonical, fleet-synced `.gitignore` denies markdown by default and
re-includes it only under a fixed set of directories, of which `Research/` is this package's
prose home. A better-named `Remediation/` directory would require changing a file the whole
ecosystem shares, which is not a decision this material should force.

What matters for correctness is unaffected: these sit beside the predicates they document, so a
rule change and its playbook change are one pull request under one review.
