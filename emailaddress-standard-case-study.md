# EmailAddress Standard Case Study

<!--
---
version: 2.0.0
last_updated: 2026-03-13
status: DECISION
tier: 1
scope: cross-package
parent: standard-facade-package-organization.md
---
-->

## Context

This case study examines `swift-emailaddress-standard` as a second concrete instance of the broader question raised in [Standard Facade Package Organization](standard-facade-package-organization.md). Where the [PDF case study](pdf-standard-case-study.md) examined a thin facade with one consumer, the EmailAddress case examines a substantive composition with many consumers — a structurally different problem.

## The EmailAddress Stack Today

### The domain-concept chain

Three facade packages form a progression of increasingly composed domain concepts:

```
RFC 1035 ──┐
RFC 1123 ──┼──→ swift-domain-standard          3 files, Domain type
RFC 5321 ──┤       ↓
RFC 5890 ──┘       │
                   │
RFC 2822 ──┐       │
RFC 5321 ──┼──→ swift-emailaddress-standard    11 files, EmailAddress type
RFC 5322 ──┤
RFC 6531 ──┘
                   ↓
RFC 2045 ──┐       │
RFC 2046 ──┼──→ swift-email-standard            5 files, Email type
RFC 4648 ──┤
RFC 5322 ──┘
```

Each level composes RFCs from the level below plus additional RFCs into a higher-level domain concept:
- **Domain**: DNS name that works across RFC 1035 (strict) and RFC 1123 (permissive), with IDNA2008 internationalization
- **EmailAddress**: Address that works across RFC 2822, 5321, 5322, and 6531, storing the most permissive representation internally
- **Email**: Full message with headers, body, multipart, boundaries

### What swift-emailaddress-standard actually does

11 source files (not counting tests). This is **real composition**, not re-export:

| File | Purpose | Lines |
|------|---------|-------|
| `EmailAddress.swift` | Core type: stores canonical RFC 6531 representation, lazy-computes RFC 5321/5322 views, provides `localPart`/`domain`/`name` | ~100 |
| `EmailAddress+RFC2822.swift` | Bidirectional conversion EmailAddress ↔ RFC_2822.AddrSpec | ~20 |
| `EmailAddress+RFC5321.swift` | Bidirectional conversion EmailAddress ↔ RFC_5321.EmailAddress | ~20 |
| `EmailAddress+RFC5322.swift` | Bidirectional conversion EmailAddress ↔ RFC_5322.EmailAddress | ~20 |
| `EmailAddress+RFC6531.swift` | Bidirectional conversion EmailAddress ↔ RFC_6531.EmailAddress (direct, canonical) | ~10 |
| `RFC_2822+RFC_6531.swift` | Cross-RFC conversion RFC_2822.AddrSpec ↔ RFC_6531.EmailAddress | ~15 |
| `RFC_5321+RFC_5322.swift` | Cross-RFC conversion RFC_5321 ↔ RFC_5322 | ~15 |
| `RFC_5321+RFC_6531.swift` | Cross-RFC conversion RFC_5321 ↔ RFC_6531 | ~15 |
| `RFC_5322+RFC_6531.swift` | Cross-RFC conversion RFC_5322 ↔ RFC_6531 | ~15 |
| `String.swift` | String representation: priority-selects RFC 5321 > 5322 > 6531 | ~10 |
| `exports.swift` | Re-exports all RFC modules + Domain_Standard | 5 |

**Core design insight**: RFC 6531 (SMTPUTF8) is the superset of all email address formats. The `EmailAddress` type stores the RFC 6531 form internally and provides typed, failable conversions to stricter formats:

```
RFC 5321 ⊂ RFC 5322 ⊂ RFC 6531
(SMTP)     (IMF)      (internationalized)
```

An internationalized address (`user@日本語.jp`) has an RFC 6531 representation but no RFC 5321/5322 representation. The type makes this explicit through optionality — `rfc5321` and `rfc5322` are `nil` for internationalized addresses.

### What swift-domain-standard provides (upstream)

3 source files. Also real composition:

| File | Purpose |
|------|---------|
| `Domain.swift` | Core type: stores RFC 1123 (required) + RFC 1035 (optional, stricter). Auto-upgrades. Domain operations: `parent()`, `root()`, `isSubdomain(of:)`, `addingSubdomain(_:)` |
| `Domain+RFC.swift` | Bidirectional conversions Domain ↔ RFC_1035.Domain, Domain ↔ RFC_1123.Domain |
| `Domain+IDNA.swift` | RFC 5890 internationalization: ASCII ↔ Unicode A-label/U-label conversions |

Same pattern: stores the most permissive representation, provides typed conversions to stricter forms.

### Consumer graph

Unlike the PDF case (one gateway consumer), EmailAddress has **many direct consumers**:

```
swift-emailaddress-standard (Layer 2)
    ↓
    ├─→ swift-email-standard (Layer 2)
    │       ↓
    │       └─→ coenttb/swift-email (external)
    │
    ├─→ coenttb/swift-syndication
    ├─→ coenttb/swift-newsletters
    ├─→ coenttb/swift-subscriptions
    ├─→ coenttb/swift-mailgun-types
    ├─→ coenttb/swift-rss
    ├─→ coenttb/swift-atom
    ├─→ coenttb/swift-authenticating
    └─→ coenttb/swift-types-foundation
```

**9+ direct consumers** across the ecosystem. The `EmailAddress` type is used as:
- Struct field type in domain models (`email: EmailAddress`, `from: EmailAddress`)
- Array element type (`to: [EmailAddress]`, `cc: [EmailAddress]`)
- Parsing target in validation middleware
- String representation for storage and APIs

**Critical difference from PDF**: No consumer bypasses the facade. Nobody imports `RFC_5321` or `RFC_6531` directly to work with email addresses — they all use `EmailAddress`. The abstraction boundary holds.

## Question

Where should `swift-emailaddress-standard` (and its dependency chain: `swift-domain-standard`, `swift-email-standard`) live?

## Analysis

### Option A: Keep in swift-standards (Status Quo)

**Description**: Leave all three packages where they are.

**Advantages**:
- These implement well-defined, externally-specified concepts (domain name, email address, email message)
- The underlying semantics ARE dictated by external specifications — the composition just bridges multiple specs that define the same concept
- "Domain" and "EmailAddress" are standards-level concepts, not foundations-level compositions
- Zero migration work
- The abstraction boundary holds — consumers use the composed type, not the underlying RFCs

**Disadvantages**:
- `swift-standards/` now contains zero spec implementations (all moved to standards-body orgs) — only facades remain
- The directory name is misleading

**Assessment**: The strongest case yet for "these are standards-layer." These packages don't add policy or opinion — they faithfully unify multiple specs that define the same concept from different angles.

### Option B: Move to swift-foundations

**Description**: Relocate all three to `swift-foundations/`.

**Advantages**:
- Architecturally clean per layer definitions: they compose standards
- Clears `swift-standards/` for retirement

**Disadvantages**:
- These are not foundations in spirit. Foundations are "composed building blocks" like HTTP, JSON, TLS — infrastructure with dependencies on standards. `EmailAddress` doesn't build on top of RFC 5322 the way an HTTP server builds on top of RFC 9110. It IS RFC 5322 (plus 5321, 6531, 2822).
- Naming: "swift-emailaddress-standard" in foundations is awkward
- Would need to rename to drop `-standard` suffix, but `swift-emailaddress` already conceptually conflicts with the coenttb/swift-email ecosystem

**Assessment**: Technically valid but semantically wrong. These are not infrastructure compositions — they are domain concept unifications.

### Option C: Move to swift-ietf

**Description**: Since all dependencies are IETF RFCs, house them in the IETF org.

**Advantages**:
- All underlying specs are IETF RFCs
- Keeps them in the standards layer
- `swift-ietf/` already contains the RFCs they compose

**Disadvantages**:
- `swift-ietf/` naming convention is `swift-rfc-NNNN` or `swift-bcp-NN` — `swift-emailaddress-standard` doesn't fit the pattern
- `swift-domain-standard` depends on RFC 5890 (IETF) but also RFC 1035 — both IETF, so this works
- But `swift-email-standard` depends on `swift-emailaddress-standard` + `swift-domain-standard` + more RFCs — the chain belongs together
- What about cross-body compositions? `swift-color-standard` composes IEC + ISO + ECMA — it can't go in any single body org

**Assessment**: Works for the email chain specifically (all IETF) but doesn't generalize to other facades.

### Option D: Recognize a "domain concepts" sub-layer within standards

**Description**: Keep these in `swift-standards/` but explicitly recognize them as a distinct category: domain-concept unifications that compose multiple specs from the same problem domain. Rename the directory/org to reflect this role (e.g., keep the org name `swift-standards` but acknowledge that after the split, it houses domain compositions rather than spec implementations).

**Advantages**:
- Matches what these packages actually are — neither spec implementations nor infrastructure compositions, but domain-concept bridges
- The `swift-standards` GitHub org already exists and houses them
- Other facades in the same category: `swift-domain-standard`, `swift-uri-standard`, `swift-time-standard`, `swift-locale-standard` — all unify multiple specs around a single domain concept
- No migration needed

**Disadvantages**:
- The term "standards" becomes overloaded: the spec implementations are in body orgs, the domain concepts are in `swift-standards`
- Doesn't appear in the five-layer architecture doc — would need documentation update

**Assessment**: Pragmatic and semantically honest. These packages ARE standards-layer — they just sit at a different granularity than individual spec implementations.

### Option E: Absorb into first consumer

**Description**: Per the PDF case study recommendation, absorb into the first foundations-layer consumer.

**Assessment**: **Does not apply.** There is no single first consumer. `EmailAddress` is consumed by 9+ packages directly. Unlike `PDF.Configuration` (rendering infrastructure used by one renderer), `EmailAddress` is domain vocabulary used everywhere. Absorbing it into any one consumer would force all other consumers to depend on that consumer for vocabulary — a layer violation.

## Comparison

| Criterion | A (Status Quo) | B (→ Foundations) | C (→ swift-ietf) | D (Domain concepts) | E (→ First consumer) |
|-----------|---------------|-------------------|-------------------|---------------------|---------------------|
| Semantic fit | High | Low | Medium | High | N/A |
| Migration cost | None | High | Medium | None-Low | N/A |
| Generalizes to other facades | Yes | Yes | No (cross-body) | Yes | No |
| Abstraction holds | Yes | Yes | Yes | Yes | N/A |
| Five-layer alignment | Acceptable | Technically correct | Acceptable | Needs docs update | Violates layering |

## Observations

### EmailAddress vs PDF: Two fundamentally different patterns

| Aspect | swift-pdf-standard | swift-emailaddress-standard |
|--------|-------------------|---------------------------|
| Substance | 5 files, mostly re-export + 3 types | 11 files, real conversion logic |
| Direct consumers | 1 (swift-pdf-rendering) | 9+ packages |
| Abstraction holds | No — consumers bypass facade | Yes — consumers use EmailAddress exclusively |
| Types added | Rendering infrastructure (Configuration, Stroke) | Domain vocabulary (EmailAddress) |
| Policy content | Yes (A4 paper, Times font defaults) | No (faithful spec unification) |
| Could absorb into consumer | Yes (one consumer) | No (many consumers) |

This suggests the general research recommendation needs refinement. The "eliminate or absorb" strategy works for:
- **Thin re-exports** with one consumer and leaky abstraction (PDF pattern)

But does NOT work for:
- **Domain concept unifications** with many consumers and strong encapsulation (EmailAddress pattern)

### The domain-concept chain is a real architectural pattern

`Domain → EmailAddress → Email` is not three independent facades — it's a layered domain model where each level composes the one below with additional specs. This is a legitimate pattern worth preserving, not eliminating.

### All three packages are standards-layer, not foundations-layer

None of these add policy, opinion, or infrastructure. They faithfully implement externally-defined concepts by bridging the multiple specs that define each concept. This is standards-layer behavior — the domain concept IS the standard, just expressed across multiple RFC documents.

## Recommendation

**Keep the full email chain** (`swift-domain-standard`, `swift-emailaddress-standard`, `swift-email-standard`) in `swift-standards/`.

The parent research ([Standard Facade Package Organization v2.0](standard-facade-package-organization.md)) confirmed Option D: domain-concept packages are a recognized sub-layer within Layer 2. The email chain is Shape B (standard-first, multi-spec) — the canonical example of convergence value. These packages:

- Converge multiple specs into canonical types (`EmailAddress` unifies 4 RFCs)
- Provide stability (consumers import `EmailAddress_Standard`, not individual RFCs)
- Maintain strong encapsulation (all 9+ consumers use `EmailAddress`, none bypass to raw RFCs)

Each domain concept in the chain should also have (or will have) a corresponding foundations package for ecosystem integration — validation middleware, service API bindings, database storage, etc.

## Outcome

**Status**: DECISION

Keep in `swift-standards/`. The email chain is the strongest validation of the domain-concept sub-layer: substantive convergence logic, many direct consumers, strong encapsulation boundary. The "absorb into first consumer" approach does not apply — there is no single first consumer.

## References

- [Standard Facade Package Organization](standard-facade-package-organization.md) — parent research
- [PDF Standard Case Study](pdf-standard-case-study.md) — contrasting case study
- [Five Layer Architecture](../Documentation.docc/Five%20Layer%20Architecture.md) — layer definitions
