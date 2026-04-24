# Submodule Worktree-Alias Misconfiguration Detection

| Field | Value |
|-------|-------|
| Tier | 1 |
| Scope | Ecosystem-wide (read-only audit) |
| Status | OPEN |
| Provenance | 2026-04-22-ci-centralization-rollout-and-ecosystem-hygiene.md |

## Context

Submodule `.git` files point at the superrepo's `modules/` tree. When a superrepo is dismantled or when a submodule's working tree is moved, the `.git` file can end up pointing at a stale or incorrect gitdir. Symptoms observed: `swift-console` / `swift-compiler` case where two `.git` files' `gitdir:` targets collided, producing ghost state that read-consistent but wrote to the wrong index.

## Question

Are there other sites in the ecosystem with the same misconfiguration class?

## Procedure

```bash
# Enumerate every sub-repo's .git file and target:
for base in ~/Developer/swift-{primitives,standards,foundations,institute} ~/Developer/swift-*/; do
  for d in "$base"/*/; do
    [[ -f "$d/.git" ]] || continue
    printf "%s -> %s\n" "$d" "$(head -1 "$d/.git")"
  done
done | sort

# Flag duplicates (two sub-repos pointing at the same gitdir):
awk '{print $NF}' <above output> | sort | uniq -d
```

## Outcome (pending)

Either:

- Inventory empty — no additional misconfigurations.
- Inventory surfaces sites — each site becomes a remediation item (re-clone the sub-repo cleanly, or fix the `.git` file target by hand).

## References

- Reflections: 2026-04-22-ci-centralization-rollout-and-ecosystem-hygiene.md
