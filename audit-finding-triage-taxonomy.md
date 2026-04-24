# Audit Finding Triage Taxonomy — Mechanical vs Design-Cycle

| Field | Value |
|-------|-------|
| Tier | 2 |
| Scope | Ecosystem-wide |
| Status | IN_PROGRESS |
| Provenance | 2026-04-22-platform-audit-remediation-cycle-and-advisory-pivot.md |

## Context

Audit findings are currently classified by priority (P0/P1/P2) and effort (S/M/L). Effort classification is an implicit proxy for "remediation vs design-cycle" but the signal is weak: findings labeled S or M routinely surface as design cycles once remediation starts.

Evidence from the 2026-04-22 platform audit cycle:

- P2.2 #1/#11 surfaced as design-cycle after starting as "mechanical" remediation slots.
- P2.3 #3 same.
- P2.4 #8 same.

Pattern: three of four "mechanical" fixes in a row turned into design cycles. The defect is triage-time, not execution-time.

## Question

How can audit triage distinguish mechanical fixes from design cycles BEFORE investigation consumes a remediation slot?

## Analysis (stub)

Hypothesis axes to investigate:

1. **Type-surface crossing**: does the fix touch more than one type's public surface? (Design cycle.)
2. **Layer crossing**: does the fix move code across L1/L2/L3 boundaries? (Design cycle.)
3. **Ownership shape**: does the fix change `~Copyable` / `~Escapable` constraints? (Design cycle.)
4. **Single-file scope**: can the fix be bounded to one file and its local tests? (Mechanical.)

Per-axis triage rule: if ANY of axes 1-3 fires, the finding routes to a design-cycle dispatch, not a remediation slot. Mechanical remediation is reserved for axis-4-only findings.

## Outcome (pending)

A proposed pre-execution classifier matrix, to be prototyped against the remaining findings in the current platform-audit cycle.

## References

- Reflections: 2026-04-22-platform-audit-remediation-cycle-and-advisory-pivot.md
- audit skill [AUDIT-020] Audit-vs-Remediation Separation
- audit skill [AUDIT-022] Estimate-Calibration on First-Finding Overage
