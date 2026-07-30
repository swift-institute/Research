# Prior art: machine-readable specification and durable-identifier ecosystems

Research task for the Institute's agent-first GitHub-presence question (stress-testing the
first-pass report's P4 "persistent identifiers" principle and its record-grammar idea).
Produced 2026-07-30. Method: 32 web sources across five pattern families (content
addressing, persistent-identifier schemes, schema registries, docs-as-code, automation-heavy
codebases), plus two read-only `gh` verifications against live Institute records. Strictly
read-only; nothing filed or mutated.

Verified live facts used below:

- Org `swift-institute` ProjectV2 **number 2** resolves to node ID `PVT_kwDODzfg4s4BenOf`,
  title "Institute Work" (read 2026-07-30). One object, three identifier classes.
- Issue `swift-institute/.github#94`'s amended body contains verbatim "The Goal is
  **admitted to Institute Work**" — the motivating display-name defect — in the same bullet
  list that correctly cites #68 for partitioned authority. #94 also already implements
  coordinate-based evidence expiry ("Evidence expires by coordinate, not by a forecast
  date") and flags floating `@main` workflow references as non-evidence.

---

## Part I — Pattern survey

Each pattern: the problem it solves → minimal viable adoption (MVA) for a ~390-repo,
single-org, GitHub-native, agent-operated programme → failure modes.

### 1. Content addressing

**Git object model** [S1]. Objects are named by hash of content; identity and integrity
collapse into one string. The crucial design is the *split*: immutable content addresses
(SHAs) underneath, mutable refs (branch names) on top. History rewriting never edits an
object; it creates new objects and moves refs. → MVA: already inherited — every Institute
repo has it; the policy question is only *which layer prose may cite* (SHA permalinks for
content claims, refs never). → Failure mode: citing the mutable layer ("on `main`") for a
content claim; SHA-1 weakness is irrelevant at this trust level.

**Nix store paths** [S30]. `/nix/store/{digest}-{name}`: digest for identity, symbolic name
for readability, *in one token*. The name is carried but never trusted; the digest
guarantees "a store path will always reference exactly one store object." → MVA: adopt the
*composite rendering* convention (durable coordinate + human gloss in a single reference),
not the mechanism. → Failure mode: paths are scoped to a store; copying across stores
breaks embedded references — the container-scoping lesson (see L3).

**IPFS CID** [S3]. Content addressing with self-describing identifiers (multibase +
version + codec + multihash). Two lessons: (a) mutable naming (IPNS/DNSLink) is layered
*over* immutable CIDs, never mixed into them; (b) **CIDv0 → CIDv1 shows identifier formats
themselves evolve** — self-description (the format announces its own version) is what made
that survivable. → MVA: make Institute receipts and grammar records self-describing
(carry their own schema/version marker). → Failure mode: identifier-format migration
without self-description strands old references.

**OCI descriptors** [S2]. A reference is a typed triple `{mediaType, digest, size}` — not a
bare hash. Digest enables verifying "content from an insecure source by recalculating the
digest independently"; registries MUST NOT alter content behind an identifier. Ecosystem
norm (outside the descriptor spec): tags are mutable pointers, digests are evidence; deploy
by `name@digest`. → MVA: the Institute's receipts already pin by digest (#90, #94); adopt
the *typed descriptor* habit — a digest reference states what kind of thing it addresses
and how it was serialized. #94's canonical-serialization-then-hash rule is exactly this. →
Failure mode: the "latest-tag problem" — the Institute's floating `@main` workflow
references, already flagged in #94's CHECKED rows, are its instance of this.

**TUF** [S4]. Adds the third leg identity and integrity lack: **freshness**. Signed roles;
expiring metadata ("clients MUST NOT trust an expired file"); a frequently re-signed
timestamp role bounds how long an attacker (or entropy) can freeze a client on stale state.
→ MVA: do not build signing roles — GitHub's audit trail and immutable comment timestamps
carry authenticity in a single-org trust model. Adopt the *freshness discipline*: every
receipt states its generation coordinates; every "current state" sentence in prose is
either dated or routed to native state. Notably, #94's coordinate-based expiry ("a
repository-main change expires that repository's evidence") is *stronger than* TUF's
wall-clock expiry for reproducible facts, because it expires on cause, not on schedule;
TUF-style time expiry remains right only where staleness itself is the risk (liveness
claims). → Failure mode: full TUF is heavy governance (root-key ceremonies) with no threat
model to justify it here.

**in-toto attestations** [S5]. The generalized receipt: a **Statement** binds `subject`
(artifacts by cryptographic digest) to a `predicate` (arbitrary typed claim) via a
**versioned `predicateType` URI**; envelope handles authentication; bundles group
statements. → MVA: shape Institute receipts as Statements: subject = the exact revisions
audited (inventory blob, page revisions), predicateType = rule-set identity + version
(digest or URI), predicate = the result. #90/#94 receipts already have all three parts
implicitly; naming the shape costs one schema comment and buys a decades-tested structure.
→ Failure mode: none material; skip the DSSE envelope (no multi-party trust needed).

### 2. Persistent-identifier schemes

**ARK vs DOI vs Handle vs PURL vs URN** [S8]. The single most load-bearing finding of this
survey: **"It is never without cost to keep content access persistent in the long term,
regardless of identifier type."** Persistence is a *service commitment* (forwarding tables
maintained, resolver funded, names never reassigned), not a property of the string. DOIs
and Handles buy that service with membership fees and centralized resolvers; ARKs
decentralize it but still require an institution that answers forever; URNs [S10] require
IANA namespace registration, mandate that a name is "never reassigned to a different
resource," and explicitly *decouple persistence from resolvability* — which is exactly why
bare URNs failed on the web: an unresolvable durable name is just a name. → MVA:
**mint no Institute namespace.** GitHub is a funded resolver the Institute does not have to
operate; repo-scoped issue numbers, org-scoped project numbers, SHAs, and digests are
identifiers *with* a resolution service attached. The Institute's entire PID budget should
be spent on a *citation policy* over GitHub-native coordinates, not on identifier
infrastructure. → Failure modes: governance overhead (fees, registries, resolver ops) and
dual identity against the GitHub coordinates agents actually traverse.

**W3C DID** [S7]. Persistence via cryptographic self-certification; no central authority —
but every DID method needs a verifiable data registry and resolver, and interop wants
method registration. Solves adversarial, multi-authority identity. The Institute is one
authority on one platform. → Reject; same dual-identity cost as URNs.

**purl** [S6]. `pkg:type/namespace/name@version` — a *grammar over existing ecosystem
coordinates*, deliberately registry-free: it standardizes how to write down identity others
already govern. It does not survive package renames (the name is the coordinate). → MVA:
this is the model for the Institute's reference grammar — a fixed way of writing GitHub
coordinates, not a new identifier space. → Failure mode: inherits the underlying
namespace's rename semantics; mitigated on GitHub by redirects (below) — if old names are
never reclaimed.

**Cool URIs don't change** [S9]. "URIs don't change: people change them." Durable
references are achieved by *leaving volatile information out*: no status ("draft",
"latest"), no classification, no implementation detail in the identifier. → MVA: direct
authoring doctrine for Institute references and receipt keys — a reference must not embed
anything that can drift (titles, counts, phase words). → Failure mode: none; this is the
1998 statement of P4.

**SPDX license IDs** [S31]. A small curated list of short identifiers (`MIT`,
`Apache-2.0`), embedded as one machine-readable comment line, with an expression grammar
(`AND`/`OR`/`WITH`). Wins because identifiers are short, stable, curated by one authority,
and *embedded at the point of use*. Deprecated IDs are kept, never reused. → MVA: the
pattern for any small controlled vocabulary the Institute ratifies (record kinds,
disposition values): short IDs, one canonical list, deprecate-don't-delete. → Failure mode:
curation is real governance; keep vocabularies tiny.

### 3. Schema registries and evolution

**Confluent Schema Registry** [S11]. Schemas are immutable versions under a subject, each
with a stable ID; a **declared compatibility mode** (BACKWARD / FORWARD / FULL, each with
TRANSITIVE variants) is *enforced at write time* — incompatible registrations are rejected.
Consumers and producers never negotiate manually. → MVA: no registry service. The
`.github` repo is the registry; issue forms/templates are the write-time check; a linter
predicate is the read-time check. Adopt the *declared-compatibility* idea: the record
grammar states, in itself, that evolution must be backward-compatible ("every record valid
under grammar vN remains valid under vN+1, or a migration sweep is filed as exact-owner
work"). Without this single sentence, the first grammar change either ossifies the fleet
or forces mass re-edits. → Failure mode: registry-as-service is ops burden with zero gain
at one-grammar scale.

**Protobuf field discipline** [S12]. "Never re-use a tag number." Field numbers are wire
identity; names are cosmetic and renameable; deleted numbers are `reserved` forever. This
is the purest statement of the two-layer identity law, and its cost is explicit,
deliberate ossification of the number space. → MVA: for Institute grammars, key semantics
to stable field *names with reservation on removal* (prose records, not wire format);
adopt the reserve-don't-recycle rule for any retired record kind or field. → Failure mode:
reservation lists grow monotonically — acceptable at Institute scale.

**CloudEvents** [S13]. A minimal envelope: exactly four REQUIRED attributes (`id`,
`source`, `specversion`, `type`), a few optional ones, open extension attributes.
`specversion` carries only major.minor so patch-level spec changes don't invalidate
serialized events. Identity is the pair (`source`, `id`). → MVA: **the closest existing
model for the Institute record grammar**: a tiny required core (kind, owner, status,
grammar version), everything else optional or extension; identity = (repo, issue number).
→ Failure mode: envelope minimalism pushes real semantics into predicates/extensions —
fine, that is where Institute judgment already lives.

**JSON Schema `$id`/`$schema`** [S14]. Schemas are identified by URIs that "are not
necessarily network-addressable. They are just identifiers"; documents declare their own
dialect via `$schema`. → MVA: if receipts get a schema, give it an `$id` under a stable
Institute URL and stamp receipts with it (self-description again). OpenAPI's
`info.version` + `$ref` reuse is the same pattern at API scale. → Failure mode:
unvalidated schemas rot silently — enforcement (fixtures, CI) is the actual guarantee, per
#90's model.

### 4. Docs-as-code at scale

**Google g3doc culture** [S18]. "A small set of fresh and accurate docs is better than a
large assembly of 'documentation' in various states of disrepair." Docs live beside code,
change in the same CL, dead docs are deleted, duplication is replaced by links to one
canonical source. → MVA: already largely Institute doctrine (#79); prior art confirms
deletion is a first-class documentation operation. → Failure mode: freshness-by-proximity
fails for surfaces with no adjacent code (org profiles, issue records) — those need the
identifier/receipt machinery instead.

**Diátaxis/Divio** [S19]. Four modes on two axes; reference is austere and best generated;
explanation carries understanding. → MVA: under the agents-only-readers assumption,
tutorial and how-to (acquisition/action modes for human learners) largely collapse into
reference + explanation. That derives the first-pass README split — generate the
reference, author only the explanation — from an independent framework. → Failure mode:
over-collapsing: rationale ("explanation") is precisely what agents cannot regenerate and
must stay authored.

**ADRs (Nygard)** [S17]. One decision per record; statuses proposed → accepted →
deprecated/superseded; "we will keep the old one around, but mark it as superseded";
numbers "will not be reused." Immutable past + linked supersession = future readers can
reconstruct "what were they thinking?" → MVA: adopt wholesale for issue records: status
field, dated amendment blocks, `Superseded-by:` links to comment permalinks; never silent
edits, never deletion. #94's amendment block already practices this. → Failure mode: none
material; ceremony stays proportional if records stay one-decision-sized.

**PEP process** [S15]. Numbers assigned once, never reused; required headers (`Status`,
`Type`, `Created`, `Replaces`, `Superseded-By`); terminal PEPs are "a historical document
rather than a living specification." **Rust RFCs** [S16] are the instructive contrast:
numbered by PR, but amendable post-merge with judgment-delegated "very minor" edits and no
formal supersession mechanics — which produces drift between RFC text and reality, a known
Rust-community pain. IETF RFCs sit at the PEP end (immutable, `Obsoletes:`/`Updates:`
headers, errata separate). → MVA: choose the PEP/IETF end: records freeze at terminal
status; later change is a new record plus a back-link. → Failure mode (Rust end): informal
amendment converts records back into living documents and re-imports fact drift.

### 5. Automation-heavy codebases and GitHub's own coordinates

**Gerrit Change-Id** [S20]. A random token in the commit footer survives amend, rebase,
and cherry-pick — tracking the *logical change* while SHAs churn. Injected by a commit-msg
hook (write-time, path-of-least-resistance) and scoped: matching needs Change-Id +
repository + branch. → MVA for the *mechanism*: none needed — GitHub PR numbers already
provide logical-change identity, and Institute review flows are PR-based; a second token
would be dual identity. → MVA for the *lesson*: identity that must survive rewriting
belongs in structured footers injected/enforced at write time.

**Chromium footers** [S28]. `Bug:`/`Fixed:` (machine-actioned: `Fixed:` auto-closes),
`Change-Id`, `Cq-`* directives, auto-added `Reviewed-on`/`Cr-Commit-Position` — a
commit-message *trailer grammar* consumed by bots; footers outside the last paragraph are
ignored. Fuchsia and other Google Gerrit trees share this machinery, and in-tree OWNERS
files are the same move for ownership facts. **Conventional Commits** [S29] generalizes:
`type(scope): description` + `BREAKING CHANGE:` footers exist *because tools parse them*
(changelogs, semver bumps). **CODEOWNERS** [S32]: path→owner metadata in one file at a
known location, mechanically consumed by review routing and branch protection — with the
sobering detail that invalid lines are *skipped silently* (enforcement must be checked,
not assumed). → MVA: a small Institute trailer set (`Goal:` canonical URL, `Receipt:`
digest, invariant line), validated by CI exactly like other linter predicates;
`Workspace.json` already is the Institute's CODEOWNERS-shaped deterministic-facts file. →
Failure mode: trailer grammars only pay when something consumes them — adopt trailers the
audit tooling will actually read, not a taxonomy for its own sake.

**GitHub's stable coordinates** [S21–S27]. The platform's own hierarchy, verified:

- **Issue/PR numbers**: repo-scoped, never reused within a repo. *Transfer* to another
  repo assigns a new number but the "original URL redirects to the new issue's URL" [S26].
- **Repository renames**: web, git, and API traffic redirect; but GitHub Pages URLs break,
  **Actions `uses:` references do not redirect at all**, and — critically — "if you create
  a new repository under your account [with] the original name … redirects to the renamed
  repository will break" [S25]. Redirects are a service that survives rename but *not name
  reclaim*.
- **Permalinks**: branch-URL file links drift; the `y`-key SHA permalink is the platform's
  own blessed durable form [S27].
- **Global node IDs**: GitHub's opaque GraphQL IDs — recommended for persistence [S21] —
  were themselves **migrated from the legacy base64 format to "next IDs" in 2021**, with a
  migrate → deprecate → sunset schedule and a compatibility header [S22–S24]. The
  platform's most "stable-looking" identifier class is the one that rotated in living
  memory.
- **ProjectV2**: org-scoped *number* (durable coordinate), node ID (opaque, API-layer),
  *title* (freely mutable display name) — the verified triple for Institute Work.

→ MVA: a trusted-coordinate ranking (Part III). → Failure modes: name reclaim silently
breaking redirect chains; Actions' no-redirect gap; opaque-ID rotation; numbers changing
across transfer (URL redirect saves prose references, but cached numbers go stale).

---

## Part II — Cross-cutting laws

Nine invariants recur across all five families:

- **L1 — Persistence is a service property, not a string property.** ARK/DOI literature is
  explicit; URNs are the proof by absence. Choose identifiers whose resolver someone else
  funds forever: for the Institute, that is GitHub + git + content digests. [S8, S9, S10]
- **L2 — Two-layer identity: mutable name over immutable coordinate; render both, trust
  one.** git refs/SHAs; OCI tag/digest; Nix `{digest}-{name}`; IPNS/CID; Gerrit
  change/Change-Id; ProjectV2 title/number. Prior art's rendering convention:
  `name@coordinate` in one token. [S1–S3, S20, S30]
- **L3 — Coordinates are container-scoped; a durable reference captures the container.**
  Issue numbers per repo; ProjectV2 numbers per org; protobuf field numbers per message;
  Change-Ids per repo+branch; Nix paths per store. "#94" is not a coordinate;
  `swift-institute/.github#94` is. [S12, S20, S26, S30]
- **L4 — Never reuse or reclaim identifiers; reserve on delete.** Protobuf `reserved`;
  PEP/ADR/IETF numbers; URN non-reassignment; SPDX deprecation; GitHub's reclaimed-name
  redirect break. [S10, S12, S15, S17, S25, S31]
- **L5 — Freshness is a separate mechanism from identity.** TUF expiry; the Institute's
  own (stronger, cause-based) coordinate expiry in #94; dating of volatile prose. [S4]
- **L6 — Records and grammars must be self-describing and version-carrying, with a
  declared compatibility direction.** CIDv1; CloudEvents `specversion`; in-toto
  `predicateType`; JSON Schema `$schema`; Confluent compatibility modes. [S3, S5, S11,
  S13, S14]
- **L7 — Write-time enforcement beats read-time cleanup.** Gerrit hook; Confluent
  registration rejection; issue forms; CODEOWNERS consumed by the platform — with the
  CODEOWNERS caveat that silent skipping means enforcement itself needs fixtures. [S11,
  S20, S32]
- **L8 — Supersede with status and links; never silently edit terminal records.**
  ADR/PEP/IETF vs the cautionary Rust-RFC amendment model. [S15, S16, S17]
- **L9 — Opaque platform IDs rotate; human-legible coordinates with funded redirects are
  the safer prose key.** GitHub's 2021 node-ID migration vs never-reused issue numbers.
  Store node IDs as cache, never as the only key — and never as prose. [S21–S24]

---

## Part III — Testing the first-pass report against prior art

### P4 ("persistent, machine-checkable identifiers") — **survives, with five refinements**

P4's direction is unanimously confirmed (L1–L4). But as stated it is a principle without a
coordinate policy. Prior art supplies the missing content:

1. **Enumerate trusted coordinate classes, ranked.** (a) content digests over canonical
   serialization (receipts) — strongest, resolver-free; (b) commit-SHA permalinks for any
   file/line/content claim; (c) canonical URL + container-scoped number for GitHub objects
   (`https://github.com/swift-institute/.github/issues/94`; org `swift-institute`
   ProjectV2 number 2); (d) GraphQL node IDs — API-layer cache only, never the sole key in
   prose (L9); (e) display names — glosses only.
2. **Fix the gloss grammar.** Prior art's `name@digest` convention, adapted: *coordinate
   first, title as parenthetical* — e.g. "the Institute portfolio Project (org
   `swift-institute`, ProjectV2 number 2, currently titled 'Institute Work')". The
   first-pass Draft C micro-fix for #94 already has exactly this shape; prior art confirms
   it and supplies the rule that generates it.
3. **Add the never-reclaim rule.** GitHub redirects survive renames but break on name
   reclaim [S25], and Actions `uses:` never redirects. A standing org rule — retired
   repo/org names are never recreated — is the zero-cost governance that keeps every
   historical URL resolving. This rule is absent from the first-pass report.
4. **Add resolution auditing.** Persistence is a service (L1); services are verified.
   The periodic fail-closed audits the Institute already runs should include a
   reference-resolution predicate (do cited URLs/SHAs/digests still resolve?). Redirect
   rot is detectable mechanically; no prior-art ecosystem leaves it unchecked.
5. **Reject namespace minting explicitly.** No Institute URN NID, DID method, DOI/ARK
   registration, or custom purl type. Every one imports resolver operations and a dual
   identity against the GitHub coordinates agents actually traverse. purl's design — a
   *grammar over coordinates someone else governs* — is the correct model for what the
   Institute should ratify instead.

### The record grammar — **validated; four upgrades required**

CloudEvents, in-toto, PEP headers, and Confluent jointly confirm a fixed record grammar is
mainstream engineering, not over-formalization. Prior art demands four properties the
first-pass sketch does not yet state:

1. **Self-describing version** (L6): every conforming record carries the grammar version
   (or the receipt carries the grammar digest, as #90 receipts already do for rule sets).
2. **Declared BACKWARD compatibility**: grammar vN+1 must accept every vN-conforming
   record, or the change ships with a filed migration sweep. One sentence in the
   ratification prevents the ossification-vs-mass-re-edit dilemma.
3. **Minimal required core** (CloudEvents: four attributes): required = kind, owner
   coordinate, status, grammar version; everything else optional/extension. Goal bodies
   like #94's stay rich *by choice*, while Tasks stay cheap — the grammar must not make
   every record a Goal-sized record.
4. **Both enforcement ends** (L7): issue forms as write-time schema; linter predicate with
   positive/negative/fail-closed fixtures as read-time validator (the #90 model), because
   CODEOWNERS shows platform-side validation can fail silently.

Receipts specifically should adopt the in-toto Statement shape — subject (exact revisions,
by digest) + predicateType (versioned rule-set identity) + predicate (result) — which
#90/#94 receipts already match in substance; naming the shape makes the schema reviewable
against a decades-tested reference model. Skip envelopes/signing (single-org trust).

### Supersession and commit messages

- Amendment practice: prior art picks the PEP/ADR end (status headers, dated supersession,
  immutable terminal records) over Rust-style informal amendment. The Institute's dated
  amendment blocks already match; ratify them as the only lawful edit form for accepted
  records.
- Commit messages: trailer grammar (`Goal:` URL, `Receipt:` digest, invariant line) per
  Chromium/Gerrit; adopt the *trailer mechanism* without Conventional Commits' semver
  taxonomy unless changelog automation becomes a consumer.

### Disposition (new Goal vs evolving #79)

Prior art consistently separates *process/standard authority* from *work items*: PEP 1
governs PEPs but is its own Active document; the Rust RFC process repo is not an RFC;
Confluent separates registry (standing) from schemas (versioned artifacts). An
identifier-and-grammar standard is standing doctrine with registry character; #79 is a
finite convergence episode. This supports the first-pass "new Goal, consume #79's receipt
as a gate" disposition — same shape as #94 consuming #90 — and nothing in the surveyed
ecosystems suggests folding a standards ratification into an in-flight cleanup episode.

---

## Part IV — Ranked shortlist for the Institute

**Adopt (highest value, near-zero governance):**

1. **Durable-coordinate citation policy over GitHub-native identifiers** — canonical URL +
   container-scoped number; coordinate-first gloss grammar; node IDs as cache only;
   linter predicate for bare display-name references to renameable objects. (L1–L3, L9)
2. **Commit-SHA permalinks for every content claim** in records and docs (`y`-key norm);
   branch URLs banned in durable records. (L2)
3. **in-toto-shaped receipts**: subject digests + versioned predicateType + predicate,
   canonical-serialization-then-hash (already #94 practice); receipts self-describe their
   schema. (L5, L6)
4. **PEP/ADR supersession discipline**: status field, dated amendment blocks,
   `Superseded-by` links to comment permalinks, terminal records frozen, numbers/records
   never deleted or reused. (L4, L8)
5. **Never-reclaim rule for repo/org names** + resolution-audit predicate in existing
   fail-closed audits. (L1, L4)

**Adapt (right idea, resize for scale):**

6. **CloudEvents-style minimal record grammar** — small required core, extensions,
   self-declared version, BACKWARD-compatibility clause; `.github` as the registry; issue
   forms write-time, linter read-time. (L6, L7)
7. **Trailer-based commit grammar** — `Goal:`/`Receipt:`/invariant trailers enforced by
   CI; skip the Conventional-Commits type taxonomy until a consumer exists. (L7)
8. **TUF freshness, scoped** — keep #94's cause-based coordinate expiry as doctrine; add
   wall-clock dating only for liveness-flavored prose claims; no signing roles. (L5)
9. **Protobuf reservation habit** — retired grammar fields and record kinds are reserved,
   never recycled. (L4)
10. **Diátaxis-derived page contract** — generate reference, author explanation; tutorials
    and how-tos are non-surfaces under agents-only readership. (supports P5)

**Reject (documented, with reasons):**

11. **Minting any Institute PID namespace** (URN NID, DID method, DOI/ARK, custom purl
    type) — resolver operations forever + dual identity against GitHub coordinates. (L1)
12. **A schema-registry service** — one grammar family, one org; the repo-plus-fixtures
    registry is strictly cheaper and equally enforced.
13. **Gerrit-style secondary change tokens** — PR numbers already provide logical-change
    identity on GitHub; a second token is dual identity.
14. **GraphQL node IDs as primary prose keys** — GitHub rotated the format in 2021;
    opaque, ungreppable, cache-only. (L9)

## Part V — Failure-mode register (what each mitigation answers)

| Failure mode | Prior-art instance | Institute mitigation |
|---|---|---|
| Governance overhead | DOI/Handle fees; DID method registries; running resolvers | GitHub-native coordinates + digests only (items 1–3, 11–12) |
| Identifier ossification | Protobuf reserved-forever; frozen URN namespaces; over-required schema fields | Minimal required core + BACKWARD clause + extensions (item 6) |
| Dual-identity drift | tag vs digest; DNS vs IP; title vs number ("Institute Work" vs ProjectV2 2); node ID vs number | Coordinate-first gloss grammar + linter predicate (item 1) |
| Redirect rot | GitHub name reclaim breaks redirects; Actions/Pages don't redirect | Never-reclaim rule + resolution audit (item 5) |
| Opaque-ID rotation | GitHub 2021 node-ID migration; CIDv0→v1 | Numbers+URLs primary; self-describing records (items 1, 3) |
| Freshness gaps / freeze | TUF threat model; stale green | Coordinate-based expiry (#94) + dated prose (item 8) |
| Silent enforcement failure | CODEOWNERS skips invalid lines silently | Fail-closed fixtures per #90 for every predicate (item 6) |
| Supersession drift | Rust RFC informal amendments | PEP/ADR statuses + dated amendment blocks (item 4) |

---

## Sources

Web (fetched 2026-07-30):

1. Pro Git, "Git Internals — Git Objects" — https://git-scm.com/book/en/v2/Git-Internals-Git-Objects
2. OCI image-spec, content descriptor — https://github.com/opencontainers/image-spec/blob/main/descriptor.md
3. IPFS docs, "Content addressing and CIDs" — https://docs.ipfs.tech/concepts/content-addressing/
4. TUF specification (latest) — https://theupdateframework.github.io/specification/latest/
5. in-toto Attestation Framework spec — https://github.com/in-toto/attestation/blob/main/spec/README.md
6. package-url purl-spec — https://github.com/package-url/purl-spec
7. W3C DID Core — https://www.w3.org/TR/did-core/
8. arks.org, "Comparing ARKs to other identifiers" — https://arks.org/about/comparing-arks-and-other-identifiers/
9. W3C, "Cool URIs don't change" — https://www.w3.org/Provider/Style/URI
10. RFC 8141, Uniform Resource Names — https://datatracker.ietf.org/doc/html/rfc8141
11. Confluent Schema Registry, schema evolution and compatibility — https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html
12. Protocol Buffers, "Proto best practices: dos and don'ts" — https://protobuf.dev/best-practices/dos-donts/
13. CloudEvents v1.0 specification — https://github.com/cloudevents/spec/blob/main/cloudevents/spec.md
14. JSON Schema, "Structuring a complex schema" — https://json-schema.org/understanding-json-schema/structuring
15. PEP 1, PEP purpose and guidelines — https://peps.python.org/pep-0001/
16. rust-lang/rfcs README — https://github.com/rust-lang/rfcs/blob/master/README.md
17. M. Nygard, "Documenting Architecture Decisions" — https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
18. Google styleguide, documentation best practices — https://google.github.io/styleguide/docguide/best_practices.html
19. Diátaxis — https://diataxis.fr/
20. Gerrit, "Change-Ids" — https://gerrit-review.googlesource.com/Documentation/user-changeid.html
21. GitHub Docs, "Using global node IDs" — https://docs.github.com/en/graphql/guides/using-global-node-ids
22. GitHub Blog, "New global ID format coming to GraphQL" — https://github.blog/news-insights/product-news/new-global-id-format-coming-to-graphql/
23. GitHub Blog, "GraphQL global ID migration update" (2021-11-16) — https://github.blog/2021-11-16-graphql-global-id-migration-update/
24. GitHub Docs, "Migrating GraphQL global node IDs" — https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids
25. GitHub Docs, "Renaming a repository" — https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository
26. GitHub Docs, "Transferring an issue to another repository" — https://docs.github.com/en/issues/tracking-your-work-with-issues/administering-issues/transferring-an-issue-to-another-repository
27. GitHub Docs, "Getting permanent links to files" — https://docs.github.com/en/repositories/working-with-files/using-files/getting-permanent-links-to-files
28. Chromium docs, "Contributing" (commit footers) — https://chromium.googlesource.com/chromium/src/+/HEAD/docs/contributing.md
29. Conventional Commits v1.0.0 — https://www.conventionalcommits.org/en/v1.0.0/
30. Nix manual, "Store path" — https://nix.dev/manual/nix/2.28/store/store-path
31. SPDX, "Handling license info" — https://spdx.dev/learn/handling-license-info/
32. GitHub Docs, "About code owners" — https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners

Live read-only verifications (gh, 2026-07-30): org `swift-institute` ProjectV2 number 2
(node `PVT_kwDODzfg4s4BenOf`, title "Institute Work"); `swift-institute/.github#94` body
(motivating defect text; coordinate-based evidence expiry; floating `@main` CHECKED rows).
