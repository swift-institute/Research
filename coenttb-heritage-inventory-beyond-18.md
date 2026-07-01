# Coenttb Heritage Inventory — Beyond the Named 18

<!--
---
version: 1.1.0
last_updated: 2026-07-01
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide (coenttb → swift-institute owned-source heritage)
---
-->

<!--
Changelog:
- v1.1.0 (2026-07-01): GitHub-reconciled. Pulled the live coenttb repo list
  (`gh repo list`, 148 repos) and cross-checked every repo-existence/visibility/
  fork/stars claim. Corrections: swift-io is a PUBLIC 18★ repo (NOT local-only —
  disk clone had a stripped origin); swift-networking is a GitHub FORK (QUIC
  stack, parent not visible), not an owned L3 umbrella. Net-new heritage
  candidates found on GitHub but not on disk: swift-address (postal-address
  types, PRIVATE), swift-protocol-mirror (protocol-gen macro, PUB 1★). Confirmed
  20 candidates have NO GitHub repo (port/create, not transfer). Added the
  authoritative §Final Confidence-Tiered List.
- v1.0.0 (2026-07-01): initial broad inventory. Fulfils the "separate research
  document" deferred in `coenttb-ecosystem-heritage-transfer-plan.md` v1.3.0
  §Future Work — enumeration + disposition of coenttb/* heritage candidates
  BEYOND the named-18 swift-html tree. Produced by a 16-agent read-only
  classification fan-out (Package.swift + README per package) plus an architect
  adversarial review; 18 review corrections applied (2 hallucinated matches, 4
  ABSENT→CONFLICTED, several layer/split rulings). ASSIGNMENT 1 (inventory) of a
  two-assignment arc; ASSIGNMENT 2 is the execution/transfer plan.
-->

## Context

`coenttb-ecosystem-heritage-transfer-plan.md` v1.3.0 (2026-04-23) dispositions the
**named-18 `swift-html` tree** and is backed by `coenttb-stage-1-dep-visibility-audit.md`
(2026-05-04, a 22-step topological transfer order). That plan's **§Future Work**
explicitly defers a *separate* research document:

> "Broader coenttb → swift-institute ambition … most coenttb packages are expected
> to eventually move to swift-foundations. Candidate enumeration and disposition
> analysis for coenttb packages beyond the named 18 … will be addressed in a
> separate research document when scope expansion is user-approved."

**This is that document.** Scope was user-approved 2026-07-01. The canonical example
given — `coenttb/swift-file-system` (a heritage ancestor for the existing
`swift-foundations/swift-file-system`) — is a textbook case that is *not* in the 18.

This is **owned-source heritage** (`swift-package-heritage` skill `[HERITAGE-005]`):
coenttb is the author's own org, so the mechanic is `gh api .../transfer` (preserves
stars/issues/PRs/URL-redirects), **not** `gh repo fork`. The exception is external
forks — packages whose lineage is a non-owned upstream (Point-Free, Apple) — which fall
under the `[HERITAGE-001]` fork mechanic and are called out separately below.

**Method.** Every `coenttb/*` swift package outside the named-18 and outside the obvious
exclusion buckets (compiler-issue repos, personal-site app repos, non-package dirs) was
read read-only (Package.swift + README ± a Sources file) and classified by layer,
destination match against the *live* swift-primitives / swift-standards / swift-foundations
package lists, and disposition. An architect pass then adversarially re-checked every
destination match and layer call; its 18 corrections are folded into the tables here.

**This inventory does not authorize any action.** It is a map. No transfers, renames,
visibility flips, or edits are proposed for execution — that is Assignment 2.

## Question

For each coenttb package beyond the named-18: what is it, which institute **layer** is
its heritage home (L1 primitives / L2 standards / L3 foundations), does a **destination**
package already exist (CONFLICTED / RENAMED / ABSENT / SUPERSEDED / SPLIT), and what is its
**disposition** (owned-source heritage candidate / external fork / superseded-archive /
out-of-scope)?

## Final Confidence-Tiered List (GitHub-reconciled 2026-07-01)

Authoritative summary, ordered by **confidence that the coenttb package is a genuine
heritage ancestor of a newer institute L1/L2/L3 package**. GitHub facts folded in
(`gh repo list coenttb`, 148 repos). "Repo" column: `PUB N★`/`PRIV` = repo exists on GitHub;
`port` = no GitHub repo (local-only — code-port/seed, not a repo transfer); `src-only` = not
even a git repo on disk. Groups A–G (below) carry the per-package evidence.

### Tier 1 — Very high confidence · transfer-ready
Existing 1:1 institute destination, owned-source (not a fork), single unambiguous layer, **and a real published/tagged repo** (genuine heritage transfer with history/stars to preserve).

| coenttb | Repo | → Destination | Layer |
|---|---|---|---|
| **swift-file-system** | PUB 22★ | `swift-foundations/swift-file-system` | L3 ⭐ |
| **swift-io** | PUB 18★ | `swift-foundations/swift-io` | L3 ⭐ |
| swift-environment-variables | PUB 7★ | `swift-foundations/swift-environment` | L3 |
| swift-linux | PUB 5★ | `swift-foundations/swift-linux` | L3 |
| swift-builders | PUB 4★ | `swift-primitives/swift-builder-primitives` | L1 |
| swift-windows | PUB 4★ | `swift-foundations/swift-windows` | L3 |
| swift-email | PUB 2★ | `swift-foundations/swift-email` | L3 |
| swift-memory-allocation | PUB 2★ | `swift-primitives/swift-memory-allocation-primitives` | L1 |
| swift-logic-operators | PUB 2★ | `swift-primitives/swift-logic-primitives` | L1 |
| swift-password-validation | PUB 2★ | `swift-foundations/swift-password` | L3 |
| swift-copy-on-write | PUB 1★ | `swift-foundations/swift-copy-on-write` | L3 |
| swift-jwt | PUB 1★ | `swift-foundations/swift-json-web-token` (rename) | L3 |
| swift-buffer | PRIV | `swift-primitives/swift-buffer-primitives` | L1 |
| swift-kernel | PRIV | `swift-foundations/swift-kernel` | L3 |
| swift-pdf | PRIV | `swift-foundations/swift-pdf` | L3 |
| swift-epub | PRIV | `swift-foundations/swift-epub` | L3 |

### Tier 1′ — Very high confidence pairing · PORT (no source repo)
Existing 1:1 institute destination, but the coenttb code has **no GitHub repo** — no history/stars to preserve, so this is a **code-port/seed**, not a heritage *transfer*. (Still lists here because the ancestor→descendant pairing is unambiguous.)

| coenttb | Repo | → Destination | Layer |
|---|---|---|---|
| swift-sockets | port | `swift-foundations/swift-sockets` | L3 |
| swift-tls | port | `swift-foundations/swift-transport-layer-security` (rename) | L3 |
| swift-dns | port | `swift-foundations/swift-domain-name-system` (rename) | L3 |
| swift-http | port | `swift-foundations/swift-http` | L3 |
| swift-http-routing | port | `swift-foundations/swift-http-routing` | L3 |
| swift-websocket | port | `swift-foundations/swift-websocket` | L3 |
| swift-uri | port | `swift-foundations/swift-uri` | L3 |
| swift-rss | src-only | `swift-foundations/swift-rss` | L3 |
| swift-json-feed | src-only | `swift-foundations/swift-json-feed` | L3 |
| swift-xml | src-only | `swift-foundations/swift-xml` (+ swift-xml-printer merges in) | L3 |

### Tier 2 — High confidence · needs a split / layer ruling
Heritage is certain; the **shape** needs a decision (spec↔behavior or L1↔L3 split, or a layer correction).

| coenttb | Repo | → Destination | Ruling |
|---|---|---|---|
| swift-memory | PRIV | `swift-memory-map/shared/lock-primitives` (L1) | Split; must dep `swift-kernel-primitives` not L3 kernel |
| swift-posix | PUB 2★ | `swift-ieee-1003` (L2) + `swift-posix` (L3) | Spec↔behavior split (both exist) |
| swift-darwin | PUB 1★ | `swift-darwin-standard` (L2) + `swift-darwin` (L3) | Spec↔behavior split (both exist) |
| swift-async | port | `swift-async-primitives` (L1) + `swift-async` (L3) | L1↔L3 split; no repo |
| swift-bounded-cache | PUB 1★ | `swift-primitives/swift-cache-primitives` (L1) | Layer corrected L3→L1 |
| swift-formatting | port | `swift-primitives/swift-formatter-primitives` (L1) | Corrected (was hallucinated L3) |
| swift-one-time-password | PUB 1★ | `swift-foundations/swift-time-based-one-time-password` | Reconcile shape (RFC 6238/4226) |
| swift-pdf-rendering | PRIV | `swift-foundations/swift-pdf-render` | ⚠ verify vs named-18 `*-rendering` |
| swift-svg-printer | PUB 1★ | `swift-foundations/swift-svg-render` | ⚠ likely inside governed named-18 tree |

### Tier 3 — Medium confidence · seeds a NEW institute package
Owned, institute-shaped, but **no existing destination** — heritage would *create* the newer package. Plausible but the descendant doesn't exist yet.

| coenttb | Repo | Proposed new home | Layer |
|---|---|---|---|
| **swift-kernel-primitives** | PUB 1★ | `swift-primitives/swift-kernel-primitives` | L1 ⭐ (load-bearing root; land first) |
| swift-authenticating | PUB 2★ | new `swift-foundations/swift-authenticating` | L3 |
| swift-identities-types | PUB 2★ | new `swift-foundations/swift-identities-types` | L3 |
| swift-address †GH-only | PRIV | new `swift-foundations/swift-address` (postal) | L3 |
| swift-percent | PUB 2★ | new `swift-primitives/swift-percent-primitives` | L1 |
| swift-splat | PUB 1★ | new `swift-foundations/swift-splat` (macro) | L3 |
| swift-protocol-mirror †GH-only | PUB 1★ | new macro pkg (cf witnesses/dual family) | L3 |
| swift-money | PUB 1★ | new `swift-foundations/swift-money` | L3 (borderline L4) |
| swift-sitemap | PUB 1★ | new L3 (corrected from L2 — imports Foundation) | L3 |
| swift-throttling | PUB 3★ | new `swift-foundations/swift-throttling` | L3 |
| swift-multipart-form-coding | PUB 1★ | new L3 (RFC 2388/7578) | L3 |
| swift-url-form-coding | PUB 1★ | new L3 | L3 |
| swift-url-routing-translating | PUB 1★ | new L3 | L3 |
| swift-date-parsing | PUB 1★ | `swift-time-standard` (L2) + new behavior (L3) | split |
| swift-atom | src-only | new L3 (Atom feed) | L3 |
| swift-syndication | port | new L3 (composes rss+atom+json-feed) | L3 |
| swift-uri-routing | port | new L3 | L3 |
| swift-transactional | port | new L3 (deps kernel) | L3 |
| swift-pipes | port | new L3 (folds into posix/kernel) | L3 |
| swift-documents | PRIV | new L3 | L3 |
| swift-epub-rendering | PRIV | new L3 | ⚠ verify vs named-18 |

### Tier 4 — Low confidence · needs a ruling before it's "heritage" at all
Borderline L3/L4, re-export umbrellas, blocked/unbuildable, or fork-of-unknown.

| coenttb | Repo | Issue |
|---|---|---|
| swift-networking | PUB · **FORK** | GitHub-flagged fork (QUIC stack; parent not visible) — settle lineage; may be `[HERITAGE-001]` |
| swift-records | PUB 15★ | ORM over postgres-nio — L3/L4 borderline (high stars, but app-ish) |
| swift-pools / swift-resource-pool | port / PUB 3★ | Competing impls; dedup vs `swift-pool-primitives`/`swift-pool-connections` |
| swift-pty | port | **Blocked** — unbuildable (missing `swift-io-nonblocking`); L3 vs L4 |
| swift-file-events | port | **Blocked** — same missing dep |
| swift-types-foundation · swift-web-foundation · swift-server-foundation · swift-foundation-extensions · swift-form-coding | PUB 1–2★ | Re-export umbrellas — clash with `[MOD]` import-precision; decompose/drop, don't transfer wholesale |
| swift-logging-extras | PUB 2★ | pointfree-dependencies glue |

### External forks — heritage via `[HERITAGE-001]` (fork mechanic, NOT owned-source transfer)

| coenttb | Repo | Upstream |
|---|---|---|
| swift-structured-queries-postgres | PUB 6★ · FORK | pointfreeco/swift-structured-queries → `swift-foundations/swift-sql-postgres` |
| swift-parsing (repo `fork-swift-parsing`) | PUB 1★ · FORK | pointfreeco/swift-parsing — ⚠ lineage taints downstream consumers |
| swift-url-routing | PUB 1★ · FORK | pointfreeco/swift-url-routing |
| pointfree-url-form-coding | PUB 1★ · FORK | pointfreeco/swift-web |
| swift-async-algorithms-fork | PUB 1★ · FORK | apple/swift-async-algorithms |

### No institute heritage
- **Superseded → archive:** swift-testing-performance (PUB 6★ → `swift-foundations/swift-testing`; verify feature absorption first).
- **App / vendor / framework (L4/L5):** stripe·mailgun·github (×3 each), kamer-van-koophandel, image-magick, **swift-bunq** (bank), swift-identities (+ -github/-mailgun), document-templates, folder, webpage, urlrequest-handler, **swift-favicon** (hallucinated match — app-ish), swift-server-foundation-vapor, swift-subscriptions, higher-order-app, stripe-gradient, all `coenttb-*` (incl. new `coenttb-html/-identities/-macros/-mailgun/-openai/-stripe/-utils`).
- **Not heritage:** 22 `swift-issue-*`/crash-repro repos; `swift` (compiler fork) + `cclsp` (tool fork); `swift-package-mirrors`, `test-*` scaffolds, `.github`; legal-domain `burgerlijk-wetboek-boek-2` + `generator-statute-swift-files` (rule-institute); archived `pointfree-html-to-pdf`/`-translating`.
- **Named-18** (governed by the existing plan): the `swift-html` tree — see Appendix.

> † `swift-address` and `swift-protocol-mirror` exist on GitHub but were **not** in the on-disk mirror; surfaced only by the GitHub reconciliation.

## Analysis

### Scale

164 entries on disk under `~/Developer/coenttb/`. After removing non-packages, the
named-18, compiler-issue reproductions, and personal-site app repos, **94 packages** were
classified:

| Disposition | Count |
|---|---:|
| heritage-candidate — L3 foundations | 54 |
| heritage-candidate — L1 primitives | 10 |
| heritage-candidate — L2 standards (incl. splits) | 3 |
| external fork (`[HERITAGE-001]`, not owned-source) | 5 |
| superseded → archive | 1 |
| app-layer / out of scope (L4/L5) | 18 |
| uncertain — needs a ruling | 3 |

The backlog's centre of gravity is a **coherent systems-infrastructure spine**:
`swift-kernel-primitives → posix/darwin/linux/windows → swift-kernel`, a memory/buffer L1
set, an I/O + file-system pair, and a **Foundation-free networking stack**
(sockets/tls/dns/http/websocket) — most mapping **1:1 onto packages already reserved** in
the institute lists. These are the highest-value, lowest-ambiguity targets.

---

### Group A — L1 Primitives heritage candidates (→ `swift-primitives`)

Owned-source. Destination org `swift-primitives`; naming `swift-<x>-primitives`; **must be
Foundation-free** (`[PRIM-FOUND-001]`).

| coenttb package | tag | Destination (swift-primitives) | State | Notes |
|---|---|---|---|---|
| **swift-kernel-primitives** | 0.1.0 | `swift-kernel-primitives` | **ABSENT (new)** | ⭐ Load-bearing L1 root — every kernel/platform package depends on it. Foundation-free (C shims). **Land first.** |
| swift-buffer | 0.1.1 | `swift-buffer-primitives` | CONFLICTED | Aligned/ring/growable buffers, `~Copyable`; deps swift-collection-primitives. |
| swift-memory-allocation | 0.2.0 | `swift-memory-allocation-primitives` | CONFLICTED | Zero-dep allocation observability (malloc_zone/LD_PRELOAD). Clean early win. |
| swift-memory | 0.2.0 | `swift-memory-map-primitives` + `swift-memory-shared-primitives` + `swift-memory-lock-primitives` | CONFLICTED (split) | ⚠ Products are `Memory.Map`/`.Shared`/`.Page.Lock` → route to the specific L1 homes, **not** generic `swift-memory-primitives`. **Layering hazard:** depends on L3 `swift-kernel`; an L1 landing must depend on `swift-kernel-primitives` instead (no upward dep). |
| swift-builders | 0.1.0 | `swift-builder-primitives` | CONFLICTED | Result-builder utilities. |
| swift-logic-operators | 0.1.2 | `swift-logic-primitives` | CONFLICTED | *(corrected from ABSENT)* nil-safe boolean/predicate operators; exact 1:1 L1 home exists. |
| swift-bounded-cache | 0.0.1 | `swift-cache-primitives` | CONFLICTED | *(corrected from L3 `swift-least-recently-used`)* zero-dep Foundation-free LRU → L1. |
| swift-formatting | — | `swift-formatter-primitives` | CONFLICTED | *(corrected from hallucinated L3 `swift-formatting`)* zero-dep `Format.Parsing`/`Format.Style` protocols → L1. |
| swift-percent | — | `swift-percent-primitives` | ABSENT (new) | Small Foundation-free value type. |
| swift-async *(L1 half)* | local-only | `swift-async-primitives` | CONFLICTED (split) | Products name both `Async Primitives` (L1) **and** `Async`/`Async Stream` (L3). **Split** L1↔L3 — see Group C for the L3 half. |

---

### Group B — L2 Standards heritage candidates (→ `swift-standards`)

Spec implementations; **must be Foundation-free**. Several coenttb packages fuse an
external spec with syscall/Foundation behavior and should **split** into an L2 spec surface
+ an L3 behavior surface.

| coenttb package | tag | Destination | State | Notes |
|---|---|---|---|---|
| swift-posix | 0.1.0 | `swift-ieee-1003` (L2) **+** `swift-posix` (L3) | **SPLIT** | Implements IEEE 1003.1. Institute has *both* repos already → Foundation-free spec surface → `swift-ieee-1003`; syscall-wrapper behavior → `swift-posix`. |
| swift-darwin | 0.1.0 | `swift-darwin-standard` (L2) **+** `swift-darwin` (L3) | **SPLIT** | Same shape: `swift-darwin-standard` (L2) exists; kqueue behavior → `swift-darwin` (L3). (Linux/Windows have **no** `-standard` repo → stay L3-only, Group C.) |
| swift-date-parsing | 0.5.2 | `swift-time-standard` (L2) **+** new L3 behavior | SPLIT (new behavior) | Date/time grammar; spec surface aligns with `swift-time-standard`; parsing behavior is L3. |

> **Foundation-in-standards hazard (ruling needed):** `swift-sitemap` and `swift-pipes`
> were initially proposed as L2 but import Foundation / are pure syscall behavior — they are
> re-routed to **L3** (Group C). L2 carries the same Foundation-free bar as L1.

---

### Group C — L3 Foundations heritage candidates (→ `swift-foundations`)

The bulk (54). **Default** heritage destination for composed infrastructure.

**C1 — CONFLICTED / RENAMED (institute counterpart already exists → transfer-rename-and-reconcile):**

| coenttb package | tag | Destination (swift-foundations) | State | Notes |
|---|---|---|---|---|
| **swift-file-system** | 0.6.0 | `swift-file-system` | CONFLICTED | ⭐ The canonical example. Production-tagged, tests + benchmarks, clean 1:1. |
| **swift-io** | PUB 18★ | `swift-io` | CONFLICTED | ⭐ Load-bearing async-I/O executor under file-system + networking. (GitHub-corrected: real public 18★ repo — the disk clone's origin was stripped.) |
| swift-sockets | local-only | `swift-sockets` | CONFLICTED | Networking stack root. |
| swift-tls | local-only | `swift-transport-layer-security` | RENAMED | |
| swift-dns | local-only | `swift-domain-name-system` | RENAMED | |
| swift-http | local-only | `swift-http` | CONFLICTED | |
| swift-http-routing | local-only | `swift-http-routing` | CONFLICTED | |
| swift-websocket | local-only | `swift-websocket` | CONFLICTED | |
| swift-kernel | 0.1.0 | `swift-kernel` | CONFLICTED | Platform umbrella over the kernel spine. |
| swift-posix *(behavior half)* | 0.1.0 | `swift-posix` | CONFLICTED | See Group B split. |
| swift-darwin *(behavior half)* | 0.1.0 | `swift-darwin` | CONFLICTED | See Group B split. |
| swift-linux | 0.1.0 | `swift-linux` | CONFLICTED | epoll/io_uring (no `-standard` sibling). |
| swift-windows | 0.1.0 | `swift-windows` | CONFLICTED | IOCP. |
| swift-copy-on-write | 0.3.1 | `swift-copy-on-write` | CONFLICTED | (macro; also an L11 dep in the named-18 audit.) |
| swift-async *(L3 half)* | local-only | `swift-async` | CONFLICTED | Split — see Group A. |
| swift-pdf | 0.4.0 | `swift-pdf` | CONFLICTED | |
| swift-pdf-rendering | 0.6.0 | `swift-pdf-render` | RENAMED | ⚠ **May overlap the named-18 `*-rendering` set** — de-conflict before scheduling. |
| swift-epub | — | `swift-epub` | CONFLICTED | |
| swift-xml | NOT-GIT² | `swift-xml` | CONFLICTED | `swift-xml-printer` **merges into this** (shares the same products). |
| swift-email | v0.1.1 | `swift-email` | CONFLICTED | *(corrected from ABSENT)* behavior over `swift-email-standard` (L2). |
| swift-rss | NOT-GIT | `swift-rss` | CONFLICTED | *(corrected from ABSENT)* over `swift-rss-standard`. |
| swift-json-feed | NOT-GIT | `swift-json-feed` | CONFLICTED | *(corrected from ABSENT)* over `swift-json-feed-standard`. |
| swift-uri | local-only | `swift-uri` | CONFLICTED | *(corrected from ABSENT)* Foundation.URL↔URI bridge over `swift-uri-standard`. |
| swift-jwt | 0.0.2 | `swift-json-web-token` | RENAMED | Feeds identities-types. |
| swift-environment-variables | 0.1.3 | `swift-environment` | CONFLICTED | ⚠ Carries pointfree-dependencies glue (umbrella tension). |
| swift-password-validation | 0.0.1 | `swift-password` | CONFLICTED | |
| swift-one-time-password | 0.1.0 | `swift-time-based-one-time-password` | CONFLICTED | Low confidence on reconcile shape; RFC 6238/4226. |
| swift-svg-printer | 0.1.0 | `swift-svg-render` | RENAMED | ⚠ **Likely inside the governed named-18 `swift-svg`/`*-rendering` tree** — verify before treating as fresh. |

**C2 — ABSENT (no institute counterpart → transfer-simple / new repo):**

| coenttb package | tag | Notes |
|---|---|---|
| swift-authenticating | v0.1.3 | RFC 7617/6750 auth core; feeds identities-types. |
| swift-identities-types | 0.1.1 | Clean type layer feeding the (out-of-scope L4) identities service. |
| swift-atom | NOT-GIT | Atom feed behavior (genuinely new; rss/json-feed conflict but atom does not). |
| swift-syndication | v0.0.1 | Composes rss + atom + json-feed. |
| swift-networking | PUB · **FORK** | ⚠ GitHub-flagged fork (QUIC transport stack; parent not visible) — reclassified to Tier 4; settle lineage before treating as owned-source. |
| swift-uri-routing | local-only | |
| swift-url-form-coding | 0.1.1 | RFC-backed form encoding. |
| swift-multipart-form-coding | 0.6.2 | RFC 2388/7578. |
| swift-form-coding | 0.5.0 | ⚠ Umbrella over the form-coding family. |
| swift-url-routing-translating | 0.0.1 | |
| swift-throttling | 0.3.3 | Rate limiting over Kernel/Async. |
| swift-transactional | local-only | Depends on L3 Kernel → firmly L3. |
| swift-pools | local-only | ⚠ **Competes with `swift-resource-pool`** and existing `swift-pool-primitives`/`swift-pool-connections` — dedup needed. |
| swift-resource-pool | 0.2.0 | ⚠ See above. |
| swift-pipes | local-only | *(corrected L2→L3)* pipe()/dup() behavior; folds into posix/kernel cluster. |
| swift-sitemap | 0.0.1 | *(corrected L2→L3)* imports Foundation; optional Foundation-free spec split later. |
| swift-splat | 0.3.2 | *(corrected L1→L3)* swift-syntax macro — consistent with other macro pkgs (copy-on-write/dual/defunctionalize) living in L3. |
| swift-money | — | ⚠ L3/L4 borderline (Foundation `Decimal`, currency domain). |
| swift-records | 0.1.0 | ⚠ L3/L4 borderline ORM over postgres-nio. |
| swift-documents | — | |
| swift-epub-rendering | — | ⚠ Possible named-18 `*-rendering` overlap. |
| swift-file-events | local-only | ⚠ **BLOCKED**: depends on non-existent `../swift-io-nonblocking`; not buildable as-is. |
| swift-logging-extras | 0.1.1 | ⚠ pointfree-dependencies glue. |
| swift-foundation-extensions | 0.1.0 | ⚠ Foundation-extension grab-bag (umbrella tension). |
| swift-types-foundation | 0.4.2 | ⚠ Re-export umbrella. |
| swift-web-foundation | 0.1.1 | ⚠ Re-export umbrella. |
| swift-server-foundation | 0.5.2 | ⚠ Re-export umbrella; framework-adjacent. |

> ¹ ~~swift-io local-only~~ — GitHub-corrected: `swift-io` is a real PUBLIC 18★ repo (disk clone's origin was stripped; its only local ref is a `backup/nonblocking-2024-12-30` tag).
> ² NOT-GIT = source-only directory on disk (no `.git`); a repo must be created before transfer.

---

### Group D — External forks (`[HERITAGE-001]`, NOT owned-source)

These derive from **non-owned** upstreams → fork mechanic (`gh repo fork` + publication-squash
+ attribution), **not** `gh api .../transfer`. Their lineage also **taints downstream
consumers** in Group C (anything transitively depending on the swift-parsing fork).

| coenttb package | tag | Upstream | License |
|---|---|---|---|
| swift-parsing | fork branch | pointfreeco/swift-parsing | MIT © 2020 Point-Free |
| swift-url-routing | 0.6.2 | pointfreeco/swift-url-routing | MIT © 2022 Point-Free |
| pointfree-url-form-coding | 0.5.0 | pointfreeco/swift-web | MIT © 2017 PF + 2025 Coen |
| swift-structured-queries-postgres | 0.2.1 | pointfreeco/swift-structured-queries | MIT © 2025 Point-Free (Postgres fork) |
| swift-async-algorithms-fork | 1.2.0 | apple/swift-async-algorithms | Apache 2.0 |

> **Ruling needed:** whether the institute wants any of these as forks at all, or prefers
> independent re-implementation (`[HERITAGE-006]`). `swift-structured-queries-postgres`
> targets `swift-foundations/swift-sql-postgres`; `swift-url-routing` targets a new L3 repo.

---

### Group E — Superseded → archive

| coenttb package | tag | Successor | Action |
|---|---|---|---|
| swift-testing-performance | 0.3.1 | `swift-foundations/swift-testing` | deprecation-README + archive — **but verify** its perf-budget/leak-tracking features are already absorbed first. |

---

### Group F — App-layer / out of scope (L4/L5)

Not primitives/standards/foundations heritage. Vendor SDKs, service integrations, and
framework-bound glue. Listed for completeness; **no institute destination**.

- **Vendor SDKs:** swift-stripe · swift-stripe-live · swift-stripe-types · swift-mailgun · swift-mailgun-live · swift-mailgun-types · swift-github · swift-github-live · swift-github-types · swift-kamer-van-koophandel · swift-image-magick
- **Identity service (L4):** swift-identities · swift-identities-github · swift-identities-mailgun *(note: `swift-identities-types` is L3 — Group C2)*
- **Web/app glue:** swift-document-templates · swift-folder · swift-webpage · swift-urlrequest-handler
- **Corrected into L4** *(architect review)*: swift-server-foundation-vapor (Vapor middleware) · swift-subscriptions (Vapor + DB email-subscription service; only a thin RFC 2369/8058 list-header core would be L3-extractable) · swift-favicon (hallucinated match; html+routing app-ish)

---

### Group G — Uncertain (needs a ruling before disposition)

| coenttb package | Question |
|---|---|
| swift-pty | L3 infra vs L4 app? **BLOCKED** on missing `../swift-io-nonblocking` dep; not buildable. |
| swift-money | L3 value-type vs L4 domain (Foundation `Decimal`, currency)? |
| swift-records | L3 data layer vs L4 ORM (postgres-nio)? |

---

### Cross-cutting findings

1. **Destination-match drift (fixed):** the raw classification wrongly marked
   swift-uri/rss/json-feed/email as ABSENT (they exist in L3 → CONFLICTED), and
   hallucinated non-existent matches for swift-favicon and swift-formatting. All corrected
   above against the live package lists.
2. **Layer/Foundation discipline:** L1 candidates that depend on the L3 `swift-kernel`
   umbrella (swift-memory, swift-transactional, swift-pools) must either re-target
   `swift-kernel-primitives` (L1) or stay L3 — no upward deps. L2 candidates that import
   Foundation (swift-sitemap) violate the standards Foundation-free bar → L3 or split.
3. **Split cases** (spec ↔ behavior): swift-posix, swift-darwin, swift-async, swift-date-parsing —
   these are not straight transfers; each needs a spec/behavior split ruling.
4. **Umbrella tension** (`[MOD]` import-precision): swift-networking, swift-types-foundation,
   swift-web-foundation, swift-server-foundation, swift-form-coding are re-export
   convenience umbrellas. Transferring them wholesale imports app-convenience posture into
   L3 — decide per-umbrella whether to transfer, decompose, or drop.
5. **named-18 overlap:** swift-svg-printer, swift-pdf-rendering, swift-epub-rendering (and
   their swift-renderable/swift-layout deps) plausibly fall under the already-governed
   `swift-svg` + `*-rendering` set. **Risk of double-scoping** work the existing plan owns.

### Operational readiness signals (feed Assignment 2)

- **No GitHub repo (confirmed via `gh repo list` — cannot `transfer`; needs repo creation/port):**
  swift-sockets, swift-tls, swift-dns, swift-http, swift-http-routing, swift-websocket,
  swift-uri, swift-uri-routing, swift-pipes, swift-pools, swift-transactional, swift-pty,
  swift-file-events, swift-async, swift-subscriptions (15). **These strong-pairing
  candidates cannot be transferred as-is** — code must be ported/seeded.
  _(GitHub-corrected: swift-io and swift-networking DO have repos — swift-io is PUBLIC 18★;
  swift-networking is a fork.)_
- **NOT-GIT (source-only):** swift-atom, swift-rss, swift-json-feed, swift-xml, swift-xml-printer.
- **Hard-blocked (unbuildable):** swift-pty, swift-file-events (missing `swift-io-nonblocking`).
- **Named-18 Phase-1 anomaly:** swift-html-chart / -prism / -fontawesome / -css-pointfree
  already show `swift-foundations/*` origin remotes locally — reconcile against the existing
  plan's "ready to execute" status (may already be partially transferred).

## Outcome

**Status: RECOMMENDATION (inventory only).** 94 packages classified; corrections applied.

**The heritage backlog beyond the 18 is dominated by a Foundation-free systems spine that
maps almost 1:1 onto reserved institute repos.** The strongest, lowest-risk wave:

1. `swift-kernel-primitives` (L1 root — land first)
2. `swift-buffer` → `swift-buffer-primitives`, `swift-memory-allocation` → `…-allocation-primitives` (zero-dep L1 early wins)
3. `swift-io` → `swift-io`, then `swift-file-system` → `swift-file-system` (the example)
4. the networking stack `swift-sockets/tls/dns/http/websocket` (coherent chain; but all local-only → repo-creation first)

**What Assignment 2 (the execution plan) must resolve before any transfer:**

- **Repo existence** — create GitHub repos for the ~17 local-only + 5 NOT-GIT candidates (they cannot be `transfer`-ed).
- **Split rulings** — posix/darwin/async/date-parsing spec↔behavior decompositions.
- **Layer/Foundation rulings** — memory L1-vs-kernel-dep, sitemap L2-vs-L3, splat/bounded-cache/logic-operators homes.
- **Fork policy** — fork-vs-reimplement for the 5 `[HERITAGE-001]` upstreams, and settle the swift-parsing fork lineage that taints downstream consumers.
- **Umbrella policy** — transfer / decompose / drop for the 5 re-export umbrellas.
- **named-18 de-confliction** — svg-printer / pdf-rendering / epub-rendering vs the governed `*-rendering` set.
- **Borderline calls** — money / records / pty (Group G).
- **Dep-visibility + topological order** — the same discipline as `coenttb-stage-1-dep-visibility-audit.md`, extended to this set (destination Package.swift dep chains, private-sibling launches).

Every transfer remains **per-action user-authorized** (Rule 6); coenttb history is **never
squashed**; ecosystem work is preserved on top. No step here is authorized for execution.

## References

- [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md) — the named-18 plan; this doc fulfils its §Future Work.
- [`coenttb-stage-1-dep-visibility-audit.md`](./coenttb-stage-1-dep-visibility-audit.md) — dep-visibility method to extend for Assignment 2.
- [`external-upstream-fork-heritage.md`](./external-upstream-fork-heritage.md) / `swift-package-heritage` skill — `[HERITAGE-001]` (fork) vs `[HERITAGE-005]` (owned-source transfer).
- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md) — transfer/apply-on-top mechanics.

## Appendix — Excluded (not classified)

**Named-18 swift-html tree** (governed by the existing plan; cross-reference only):
swift-html, swift-css, swift-svg, swift-translating, swift-renderable, swift-html-rendering,
swift-svg-rendering, swift-css-html-rendering, swift-markdown-html-rendering,
swift-pdf-html-rendering, swift-html-chart, swift-html-fontawesome, swift-html-prism,
swift-html-css-pointfree, swift-html-to-pdf · **archived:** swift-html-types, swift-css-types, swift-svg-types.

**Compiler-issue reproductions** (22 — never heritage): swift-embedded-typed-throws-crash,
swift-nested-copyable-extension-bug, and all `swift-issue-*` (borrowing-actor-closure,
copypropagation-nonescapable-mark-dependence, emit-module-noncopyable-sequence,
inlinearray-deinit-value-generic, irgen-async-typed-throws-noncopyable,
irgen-escapable-typed-throws, irgen-typed-throws-nested-error-generic,
nested-generic-subscript-performance, noncopyable-sequence-conformance,
property-view-tag-constraint-cross-module, rawlayout-deinit-cross-package,
sil-verifier-read-escapable-lifetime, silgen-pack-expansion-cross-module,
silgen-property-wrapper-noncopyable, testing-suite-discovery-generic-specialization,
testing-xcode-nested-suite-filter, typed-throws-autoclosure-inference,
windows-existential-crash, windows-existential-crash-other-package).

**Personal-site app repos** (18 — L5, out of scope): coenttb, coenttb-blog,
coenttb-com-blog-drafts, coenttb-com-server, coenttb-com-shared, coenttb-google-analytics,
coenttb-hotjar, coenttb-kamer-van-koophandel, coenttb-newsletter, coenttb-postgres,
coenttb-server, coenttb-server-vapor, coenttb-syndication, coenttb-ui, coenttb-web,
identity-coenttb-com-server, repotraffic-com-server, boiler.

**Non-package / infra:** Platforms.xcworkspace, Research/, archive/, *.png,
ARCHITECTURE.md, BOILER_ARCHITECTURE_REFACTOR_PLAN.md, MIGRATION_PLAN.md,
`__swift-structured-queries-postgres` (disabled dup), `swift-syndication.PRE-FILTER-REPO-backup`,
swift-package-mirrors (tooling, no Package.swift), swift-newsletters (source-only app).
