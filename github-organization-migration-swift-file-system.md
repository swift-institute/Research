# GitHub Organization Migration: swift-file-system

<!--
---
version: 5.0.0
last_updated: 2026-04-02
status: DECISION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

### Trigger

An external company needs access to `swift-file-system` for contribution. This is the first external consumer of the ecosystem.

### Constraints

1. **Separate GitHub orgs** — one per standards body, one per layer
2. **No versioned release yet** — `branch: "main"` dependencies
3. **Primitives and standards are Apache 2.0** — most standards repos are public (22 of 102 are still private); internal consumers exist in `coenttb/` packages
4. **Foundations is private** — company needs org invitation
5. **Local development workflow must not degrade**

### GitHub Organization Hierarchy

The GitHub orgs form a three-level hierarchy that mirrors the five-layer architecture:

```
swift-institute                          (org of orgs — ecosystem umbrella)
├── swift-primitives                     (org of repos — L1, flat)
├── swift-standards                      (org of orgs — L2, namespace authority)
│   ├── swift-ietf                       (sub-org — IETF RFCs and BCPs)
│   ├── swift-iso                        (sub-org — ISO standards)
│   ├── swift-incits                     (sub-org — INCITS standards)
│   ├── swift-w3c                        (sub-org — W3C specifications)
│   ├── swift-whatwg                     (sub-org — WHATWG living standards)
│   ├── swift-ieee                       (sub-org — IEEE standards)
│   ├── swift-iec                        (sub-org — IEC standards)
│   ├── swift-ecma                       (sub-org — ECMA standards)
│   └── (17 composed cross-body repos)   (direct repos in swift-standards)
└── swift-foundations                     (org of repos — L3, flat)
```

- **swift-institute** is the organization of organizations — the top-level umbrella for the entire ecosystem.
- **swift-standards** is an organization of organizations — the namespace authority for the standards layer. The body-specific orgs (swift-ietf, swift-iso, etc.) are semantically sub-organizations. The 17 composed standards that span multiple bodies live directly in swift-standards.
- **swift-primitives** and **swift-foundations** are simple organizations of repos — flat, no sub-orgs.

GitHub has no formal sub-org feature, so this hierarchy is semantic, not structural. It is expressed through naming conventions and documentation.

### Key Findings

**Local standards-body packages are already git repos** with remotes pointing to `github.com/swift-standards/*.git`. They have unpushed local commits. The migration is: transfer repo on GitHub, update local remote URL, push. No file copying, no force-push, no Package.swift changes.

**Repo settings are trivially empty**: no branch protections, no secrets, no deploy keys, no teams, no rulesets across any of the 78 repos. Post-transfer verification only needs to confirm the repo exists in the destination org.

**All repos use `main` as default branch**. Uniform — no dynamic branch detection needed.

**17 "new" IETF packages are scaffold-only** (no Package.swift, just CI templates + LICENSE). Skip entirely — create repos when actual code exists.

**swift-base62-standard → swift-base62-primitives** is the same git lineage evolved, not a replacement. Transfer+rename, then regular push.

### Collaborative Review

This plan was pressure-tested in a structured Claude–ChatGPT discussion (4 rounds, converged). Key improvements from the review:

- Manifest-driven execution with verification gates and audit trail
- Serial transfers with polling for async completion
- Preflight validation including origin URL verification
- Phase separation: transfer identity first, then create new identity, then archive
- Onboarding bundle acceptance-tested in clean-room environment
- swift-standards treated as permanent home for composed standards, superrepo frozen as legacy

---

## Migration Scope

| Category | Count | Action |
|----------|-------|--------|
| Transfer (tracked, local git repo) | 74 | transfer → update remote → push |
| Transfer + rename | 1 | swift-base62-standard → swift-base62-primitives |
| Transfer + archive (orphaned) | 6 | swift-rfc-7230 through 7235 |
| Create new | 1 | swift-iso-9945 |
| Delete | 1 | swift-rfc-template |
| Scaffolds (local-only, no GitHub repo) | 17 | Not ready — no Package.swift, no .git |
| Remain in swift-standards | 20 | 18 composed standards + .github + superrepo |

**Total GitHub mutations: 83** (74 transfers + 1 rename + 6 archive + 1 create + 1 delete)

### Transfer Map

**To `swift-ietf`** (60 repos, of which 6 are orphaned → archive after transfer):

swift-bcp-47, swift-rfc-768, swift-rfc-791, swift-rfc-1034, swift-rfc-1035, swift-rfc-1123, swift-rfc-1950, swift-rfc-1951, swift-rfc-2045, swift-rfc-2046, swift-rfc-2183, swift-rfc-2369, swift-rfc-2387, swift-rfc-2388, swift-rfc-2822, swift-rfc-3339, swift-rfc-3492, swift-rfc-3596, swift-rfc-3986, swift-rfc-3987, swift-rfc-4007, swift-rfc-4122, swift-rfc-4287, swift-rfc-4291, swift-rfc-4648, swift-rfc-5234, swift-rfc-5321, swift-rfc-5322, swift-rfc-5646, swift-rfc-5890, swift-rfc-5952, swift-rfc-6068, swift-rfc-6238, swift-rfc-6265, swift-rfc-6455, swift-rfc-6531, swift-rfc-6570, swift-rfc-6750, swift-rfc-6891, swift-rfc-7230, swift-rfc-7231, swift-rfc-7232, swift-rfc-7233, swift-rfc-7234, swift-rfc-7235, swift-rfc-7301, swift-rfc-7405, swift-rfc-7519, swift-rfc-7578, swift-rfc-7617, swift-rfc-8058, swift-rfc-8200, swift-rfc-8259, swift-rfc-8446, swift-rfc-9110, swift-rfc-9111, swift-rfc-9112, swift-rfc-9293, swift-rfc-9557, swift-rfc-9562

(Includes 6 orphaned repos — swift-rfc-7230 through 7235 — to be archived after transfer.)

**To `swift-iso`** (8 repos):

swift-iso-639, swift-iso-3166, swift-iso-8601, swift-iso-9899, swift-iso-14496-22, swift-iso-15924, swift-iso-21320, swift-iso-32000

**To `swift-incits`** (1 repo): swift-incits-4-1986

**To `swift-w3c`** (6 repos): swift-w3c-css, swift-w3c-cssom, swift-w3c-epub, swift-w3c-png, swift-w3c-svg, swift-w3c-xml

**To `swift-whatwg`** (2 repos): swift-whatwg-html, swift-whatwg-url

**To `swift-ieee`** (1 repo): swift-ieee-754

**To `swift-iec`** (1 repo): swift-iec-61966

**To `swift-ecma`** (1 repo): swift-ecma-48

**To `swift-primitives`** (1 repo, rename): swift-base62-standard → swift-base62-primitives

### Remain in `swift-standards` (18 composed standards + 2 org repos)

swift-color-standard, swift-css-standard, swift-domain-standard, swift-email-standard, swift-emailaddress-standard, swift-epub-standard, swift-html-standard, swift-ipv4-standard, swift-ipv6-standard, swift-json-feed-standard, swift-locale-standard, swift-numeric-formatting-standard (archived), swift-pdf-standard, swift-rss-standard, swift-sockets-standard, swift-svg-standard, swift-time-standard, swift-uri-standard

Plus: `.github` (org config), `swift-standards` (superrepo — to be frozen as legacy in Phase 8).

These are cross-body composed standards — permanent residents, not transitional.

---

## Execution Plan

### Phase 0: Preflight

Generate TSV manifest from GitHub API + local filesystem scan. Validate:

- All 81 source repos exist in swift-standards
- All 9 destination orgs exist and user is owner
- No name conflicts in destination orgs
- All 75 tracked local repos have clean working trees
- Each tracked local repo's origin matches expected `swift-standards` URL
- Note: 22 repos in swift-standards are currently private (will be made public in Phase 7)
- Default branch is `main` for all repos

**Manifest columns**: source_org, source_repo, dest_org, dest_repo, action, local_path, local_repo_state, post_action_check, status, verified_at, notes

**local_repo_state values**: tracked | tracked_unpushed | orphan_remote_only | local_only_new

### Phase 1: Delete obsolete

```bash
gh repo delete swift-standards/swift-rfc-template --yes
```

### Phase 2: Transfer repos (serial, verified)

Transfer 81 repos from swift-standards to destination orgs. Serial execution with polling loop per transfer.

```bash
# Per-repo transfer
gh api "repos/swift-standards/$SOURCE_REPO/transfer" \
  -X POST -f new_owner="$DEST_ORG"

# For swift-base62-standard (rename):
gh api "repos/swift-standards/swift-base62-standard/transfer" \
  -X POST -f new_owner=swift-primitives -f new_name=swift-base62-primitives

# Per-repo verification with retry (transfer is async)
for i in 1 2 3 5 10; do
  sleep "$i"
  gh repo view "$DEST_ORG/$DEST_REPO" --json name,defaultBranch 2>/dev/null && break
done
```

Record status + verified_at in manifest per row.

### Phase 3: Update local remotes

For 75 tracked local repos (74 transfers + 1 rename):

```bash
cd "$LOCAL_PATH"
git remote set-url origin "https://github.com/$DEST_ORG/$DEST_REPO.git"
```

### Phase 4: Push unpushed commits

For repos with local commits ahead of origin:

```bash
cd "$LOCAL_PATH"
git push origin main
```

### Phase 4.5: Update internal consumer Package.swift URLs

The `swift-standards` repos are already public with internal consumers in the `coenttb` org. These packages stay in `coenttb` but their Package.swift dependency URLs must be updated to point to the new orgs. Refs to composed standards (which stay in `swift-standards`) are unchanged.

| Consumer package (stays in coenttb) | Dep to update | New URL org |
|-------------------------------------|---------------|-------------|
| swift-pdf-html-rendering | swift-rfc-4648 | swift-ietf |
| swift-pdf-html-rendering | swift-iso-9899 | swift-iso |
| swift-pdf-html-rendering | swift-iec-61966 | swift-iec |
| swift-pdf-html-rendering | swift-w3c-css | swift-w3c |
| swift-form-coding | swift-rfc-7578 | swift-ietf |
| swift-webpage | swift-incits-4-1986 | swift-incits |
| swift-date-parsing | swift-rfc-2822, swift-rfc-5322 | swift-ietf |
| swift-documents | swift-bcp-47 | swift-ietf |
| swift-url-form-coding | swift-rfc-2388 | swift-ietf |
| swift-url-form-coding | swift-whatwg-url | swift-whatwg |
| swift-email | swift-rfc-5322 | swift-ietf |
| swift-epub-rendering | swift-bcp-47 | swift-ietf |
| swift-epub | swift-bcp-47 | swift-ietf |
| swift-types-foundation | swift-rfc-7578 | swift-ietf |
| swift-authenticating | swift-rfc-6750, swift-rfc-7617 | swift-ietf |
| swift-one-time-password | swift-rfc-6238 | swift-ietf |
| swift-multipart-form-coding | swift-rfc-2045 | swift-ietf |
| swift-jwt | swift-rfc-7519 | swift-ietf |
| swift-url-routing | swift-rfc-3986, swift-rfc-6570, swift-rfc-2045 | swift-ietf |

**Unchanged** (composed standards stay in `swift-standards` — no URL rewrite needed):
- swift-syndication → swift-emailaddress-standard
- swift-web-foundation → swift-emailaddress-standard, swift-domain-standard
- swift-pdf-html-rendering → swift-html-standard, swift-css-standard
- swift-css, swift-html, swift-css-html-rendering, swift-html-css-pointfree → swift-css-standard, swift-html-standard
- (plus ~4 other consumers referencing only composed standards)

The URL rewrite is mechanical — replace `swift-standards/{repo}` with `{new-org}/{repo}` for transferred repos only.

### Phase 5: Create new repo

Only `swift-iso-9945`. Note: this directory is already a git repo with a mispointed remote (origin → `swift-primitives/swift-posix-primitives`). Do NOT `git init` — fix the remote instead:

```bash
cd swift-iso-9945
gh repo create swift-iso/swift-iso-9945 --private
git remote set-url origin https://github.com/swift-iso/swift-iso-9945.git
git push origin main
```

### Phase 6: Archive orphaned repos

```bash
for repo in swift-rfc-7230 swift-rfc-7231 swift-rfc-7232 swift-rfc-7233 swift-rfc-7234 swift-rfc-7235; do
  gh repo archive "swift-ietf/$repo" --yes
done
```

### Phase 7: Verify visibility

Standards repos are already public — GitHub transfer preserves visibility. Verify all transferred repos remain public in their new orgs. Make `swift-primitives` repos public (if not already):

```bash
# Verify transferred standards repos are still public
for org in swift-ietf swift-iso swift-incits swift-w3c swift-whatwg swift-ieee swift-iec swift-ecma swift-standards; do
  gh repo list "$org" --limit 200 --json name,visibility -q '.[] | select(.visibility != "PUBLIC") | .name' | \
    while read repo; do
      echo "PRIVATE: $org/$repo — making public"
      gh repo edit "$org/$repo" --visibility public
    done
done

# Make primitives public (may currently be private)
gh repo list swift-primitives --limit 200 --json name -q '.[].name' | \
  while read repo; do
    gh repo edit "swift-primitives/$repo" --visibility public
  done
```

### Phase 8: Legacy notice

Add to swift-standards superrepo README:

> **Note**: Body-specific standards repos have moved to dedicated GitHub organizations (swift-ietf, swift-iso, swift-incits, swift-w3c, swift-whatwg, swift-ieee, swift-iec, swift-ecma). This organization remains canonical only for composed cross-body standards.

### Phase 9: Onboarding bundle

1. Generate transitive dependency closure from `swift-file-system/Package.swift` (recursive path-dep parsing)
2. Emit two artifacts:
   - **Bootstrap script**: clones all required repos into correct directory layout at pinned SHAs
   - **Lock manifest**: lists every repo, org, commit SHA, and expected local path
3. **Acceptance test**: run bootstrap in a fresh temporary workspace, verify `swift build` succeeds for swift-file-system
4. Commit artifacts to swift-institute or swift-foundations

Then: invite company to `swift-foundations` org, grant team access to swift-file-system and its transitive foundations dependencies.

---

## Execution Status

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Preflight + manifest generation | PENDING |
| 1 | Delete swift-rfc-template | PENDING |
| 2 | Transfer 81 repos | PENDING |
| 3 | Update local remotes | PENDING |
| 4 | Push unpushed commits | PENDING |
| 4.5 | Update internal consumer Package.swift URLs | PENDING |
| 5 | Create swift-iso-9945 | PENDING |
| 6 | Archive 6 orphaned repos | PENDING |
| 7 | Set visibility to public | PENDING |
| 8 | Legacy notice on swift-standards | PENDING |
| 9 | Onboarding bundle + company invite | PENDING |

---

## Changelog

### v5.0.0 (2026-04-02)

- Post-audit fixes addressing 14 findings (2 CRITICAL, 4 HIGH, 4 MEDIUM, 4 LOW)
- CRITICAL #1: Added missing `swift-css-standard` to remain list (18 composed standards, not 17)
- CRITICAL #2: Expanded Phase 4.5 consumer list from 10 to 19 entries (10 missing coenttb/ packages)
- HIGH #3/#4: Fixed IETF count to 60, total transfers to 81, total mutations to 83
- HIGH #5: Fixed Phase 5 — swift-iso-9945 is already a git repo, don't reinitialize
- HIGH #6: Corrected "already public" claim — 22 of 102 repos are private
- MEDIUM #7: Phase 3 count corrected to 75
- MEDIUM #12: Phase 6 archive command fixed (`gh repo archive`, not `gh repo edit --archived`)
- LOW #10: Added .github and swift-standards superrepo to remain list
- LOW #11: Clarified scaffolds are local-only dirs, not GitHub repos
- LOW #13: Phase 2 polling changed from flat sleep to retry loop with backoff
- LOW #14: Noted swift-numeric-formatting-standard is already archived

### v4.0.0 (2026-04-02)

- Converged plan after 4-round Claude–ChatGPT collaborative review
- Key discovery: local body-specific packages ARE git repos → Step 5 collapses to remote URL update + push
- 17 scaffold IETF packages reclassified as "skip" (no Package.swift)
- Added manifest-driven execution with audit trail
- Added preflight validation including origin URL verification
- Adopted serial transfer with polling, 9-phase execution ordering
- swift-standards → permanent home for composed standards, superrepo frozen as legacy
- Onboarding bundle pinned to SHAs with clean-room acceptance test

### v3.0.0 (2026-04-02)

- Corrected transfer map to match actual GitHub inventory
- swift-base62-standard → swift-primitives with rename

### v2.0.0 (2026-04-02)

- Incorporated finding that swift-standards org has repos needing transfer

### v1.0.0 (2026-04-02)

- Initial research

---

## References

- [dual-mode-package-publication.md](dual-mode-package-publication.md) — Future versioned publication
- [git-subtree-publication-pattern.md](git-subtree-publication-pattern.md) — Repo structure confirmation
- [Transferring a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository)
- [GitHub API: Transfer a repository](https://docs.github.com/en/rest/repos/repos#transfer-a-repository)
- Collaborative discussion transcript: `/tmp/github-org-migration-transcript.md`
