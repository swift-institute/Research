# Agent-Friendly Access to Dutch Legislation (wetten.overheid.nl)

<!--
---
version: 2.0.0
last_updated: 2026-03-02
status: DECISION
tier: 1
---
-->

## Context

We regularly need agents to look up Dutch law on [wetten.overheid.nl](https://wetten.overheid.nl/). The default HTML pages (e.g. `/BWBR0003045/`) are extremely large and unruly for agent consumption: a single law like Burgerlijk Wetboek Boek 2 produces a page with 455+ articles, deeply nested TOC, and JavaScript-driven navigation. This research investigates structured access methods that produce cleaner, more focused output suitable for LLM agents.

## Question

What URL schemes, APIs, and machine-readable formats does the Dutch government provide for accessing legislation, and which combination produces the best agent workflow?

## Analysis

### Access Method Inventory

Seven distinct access methods exist:

| # | Method | Endpoint | Format | Auth | Granularity |
|---|--------|----------|--------|------|-------------|
| 1 | HTML pages | `wetten.overheid.nl` | HTML | None | Full law |
| **2** | **Print view (`/afdrukken`)** | **`wetten.overheid.nl/.../afdrukken`** | **HTML** | **None** | **Single article or section** |
| 3 | XML Repository | `repository.officiele-overheidspublicaties.nl` | XML | None | Full law version |
| 4 | SRU Search | `zoekservice.overheid.nl/sru/Search` | XML | None | Metadata + download URLs |
| 5 | Manifest files | Repository `/manifest.xml` | XML | None | Version catalog |
| 6 | LiDO Linked Data | `linkeddata.overheid.nl/service/` | XML/RDF | Partial | Cross-references |
| 7 | WTI Metadata | Repository `/{BWBID}.WTI` | XML | None | Amendment history |

---

### Option 1: HTML Pages (wetten.overheid.nl)

**URL patterns:**

```
# Current version of a law
https://wetten.overheid.nl/{BWBID}/

# Specific date version
https://wetten.overheid.nl/{BWBID}/{YYYY-MM-DD}

# Anchor to specific article (still loads full page)
https://wetten.overheid.nl/{BWBID}/{YYYY-MM-DD}/0#{BookPath}_{TitlePath}_{Artikel}
# Example: .../BWBR0003045/2025-01-01/0#Boek2_Titeldeel1_Artikel5
```

**Advantages:** Simple URLs, human-readable, always current.
**Disadvantages:** Massive page size, full law always loaded, JavaScript-heavy, no article isolation. Anchor links scroll within the full page but agents still receive the entire document. Completely impractical for large codes (BW, Sv, Sr).

**Agent suitability:** Poor.

---

### Option 2: Print View — `/afdrukken` (Best for agents)

**URL pattern:**

```
https://wetten.overheid.nl/{BWBID}/{YYYY-MM-DD}/0/{PATH}/afdrukken
```

Appending `/afdrukken` ("print") to any article or section path produces a minimal page containing **only that article or section's text**. No table of contents, no full law, no JavaScript navigation — just the legal text with basic metadata.

**Verified examples:**

```
# Single article — BW Boek 2, Artikel 19 (dissolution of legal entities)
https://wetten.overheid.nl/BWBR0003045/2025-01-01/0/Boek2/Titeldeel1/Artikel19/afdrukken

# Single article — Wetboek van Strafrecht, Artikel 310 (diefstal/theft)
https://wetten.overheid.nl/BWBR0001854/2025-01-01/0/BoekTweede/TiteldeelXXII/Artikel310/afdrukken

# Entire title section — BW Boek 2, Titel 1 (25 articles)
https://wetten.overheid.nl/BWBR0003045/2025-01-01/0/Boek2/Titeldeel1/afdrukken
```

**Path component format:** The path uses the law's structural hierarchy. The exact names vary per law:

| Law structure | Path component examples |
|---------------|------------------------|
| Boek (Book) | `Boek2`, `BoekTweede`, `BoekEerste` |
| Hoofdstuk (Chapter) | `Hoofdstuk3` |
| Titeldeel (Title) | `Titeldeel1`, `TiteldeelXXII` |
| Afdeling (Section) | `Afdeling1` |
| Paragraaf (Paragraph) | `Paragraaf1` |
| Artikel (Article) | `Artikel19`, `Artikel310`, `Artikel3:2` |

**How to discover the correct path:** The path components correspond to the `bwb-ng-variabel-deel` attribute in the XML (Option 3), and to the anchor fragment identifiers in the HTML page (Option 1). The table of contents on the main HTML page reveals the hierarchy.

**Granularity levels:** `/afdrukken` works at any level of the hierarchy:

| Level | Scope | Use case |
|-------|-------|----------|
| Artikel | Single article | Precise lookup |
| Afdeling | Section (group of articles) | Related provisions |
| Titeldeel | Title (larger group) | Full topic area |
| Hoofdstuk/Boek | Chapter/Book | Broad context |

**Advantages:** Minimal payload, focused content, no XML parsing needed, works with WebFetch directly, includes validity date metadata, no authentication, human-readable output.
**Disadvantages:** Still HTML (not structured data), path must be known in advance, path naming is inconsistent across laws (numeric vs Dutch ordinals vs Roman numerals), no programmatic way to discover paths without first inspecting the law's structure.

**Agent suitability:** Excellent. This is the primary method for agents that know which article they need. The output is clean enough for WebFetch + prompt extraction. For discovery of paths, combine with SRU (Option 4) or a quick fetch of the main page's TOC.

---

### Option 3: XML Repository (Best for structured extraction)

**URL pattern:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/{BWBID}/{DATE}_{VERSION}/xml/{BWBID}_{DATE}_{VERSION}.xml
```

**Concrete example:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/BWBR0003045/2025-01-01_0/xml/BWBR0003045_2025-01-01_0.xml
```

**XML structure (verified):**

```xml
<toestand bwb-id="BWBR0003045" inwerkingtreding="2025-01-01">
  <wetgeving>
    <wet-besluit>
      <wettekst>
        <boek> / <titeldeel> / <afdeling> / ...
          <artikel bwb-ng-variabel-deel="/Boek2/Titeldeel1/Artikel1">
            <kop>
              <label>Artikel</label>
              <nr>1</nr>
            </kop>
            <lid>
              <lidnr>1</lidnr>
              <al>De Staat, de provincies, de gemeenten...</al>
            </lid>
          </artikel>
```

**Key XML elements:**

| Element | Meaning | Agent use |
|---------|---------|-----------|
| `<toestand>` | Root, contains `bwb-id` and `inwerkingtreding` (effective date) | Identify law + version |
| `<artikel>` | Article, `bwb-ng-variabel-deel` gives path | Extract by path |
| `<kop>` | Header with `<label>` + `<nr>` | Article number |
| `<lid>` | Paragraph (lid), numbered with `<lidnr>` | Individual subsections |
| `<al>` | Text content (alinea) | Actual legal text |
| `<lijst>` / `<li>` | Enumerated lists within articles | Lettered/numbered items |
| `<intref>` / `<extref>` | Internal/external cross-references | Follow citations |

**Advantages:** Fully structured, machine-parseable, specific articles extractable by path, includes cross-references, no auth needed.
**Disadvantages:** Full law still downloaded (large for codes like BW), requires XML parsing, version suffix (`_0`) not always predictable.

**Agent suitability:** Good. An agent can fetch the XML, parse it, and extract specific `<artikel>` elements by `bwb-ng-variabel-deel` path. This is the primary data source.

---

### Option 4: SRU Search API (Best for discovery)

**Base URL:**

```
https://zoekservice.overheid.nl/sru/Search?operation=searchRetrieve&version=1.2&x-connection=BWB&query={QUERY}
```

**Queryable fields (14 total, from SRU explain):**

| Field | Description | Example |
|-------|-------------|---------|
| `dcterms.identifier` | BWB ID | `BWBR0003045` |
| `dcterms.modified` | Last modification date | `>=2025-01-01` |
| `dcterms.type` | Regulation type | `wet`, `AMvB`, `ministeriele-regeling` |
| `overheid.authority` | Responsible ministry | `Justitie en Veiligheid` |
| `overheidbwb.rechtsgebied` | Legal field | `belastingrecht`, `strafrecht` |
| `overheidbwb.overheidsdomein` | Government domain | `Economie en ondernemen` |
| `overheidbwb.titel` | Law title | (keyword search in title) |
| `overheidbwb.afkorting` | Official abbreviation | `BW`, `WvSr`, `Awb` |
| `overheidbwb.geldigheidsdatum` | Validity date | `2025-01-01` |
| `overheidbwb.zichtdatum` | Visibility/publication date | `2025-01-01` |
| `overheidbwb.bekendmaking` | Publication reference | `stb-2015-123` |
| `overheidbwb.dossiernummer` | Dossier number | — |
| `overheidbwb.wetsfamilie` | Legislative family | — |
| `overheidbwb.onderwerpVerdrag` | Treaty subject | — |

**Query syntax:** CQL (Contextual Query Language). Boolean: `AND`, `OR`. Comparison: `=`, `==`, `>=`, `<=`.

**Pagination:** `maximumRecords` (default 50), `startRecord`.

**Example queries:**

```
# Find a specific law by BWB ID, get current version
query=dcterms.identifier=BWBR0003045 AND overheidbwb.geldigheidsdatum=2025-01-01&maximumRecords=1

# Find all tax laws modified since a date
query=dcterms.modified>=2025-01-01 AND overheidbwb.rechtsgebied==belastingrecht

# Find a law by abbreviation
query=overheidbwb.afkorting=BW

# Find by publication reference
query=overheidbwb.bekendmaking=stb-2015-123 AND overheidbwb.geldigheidsdatum=2025-09-01
```

**Response contains** (per record): identifier, title, type, authority, legal field, validity period, and critically: **direct download URLs** for the XML toestand, WTI, and manifest files.

**Limitations:** No full-text search. Cannot search within article content. Metadata-only.

**Agent suitability:** Excellent for discovery. Agent queries SRU to find the right law and get the XML download URL, then fetches the XML.

---

### Option 5: Manifest Files (Version catalog)

**URL pattern:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/{BWBID}/manifest.xml
```

**Contains:** All historical versions of a law with date ranges and XML file paths. BWBR0003045 has 92+ versions spanning 2002-2025.

**Special labels** (convenience shortcuts):

```
?latestExpression    # Most recent version
?currentExpression   # Currently in-force version
```

**Agent suitability:** Useful when you need to find which version was in force on a specific date, or get the latest XML URL without going through SRU.

---

### Option 6: LiDO Linked Data (Cross-references)

**Endpoints:**

```
# Get internal ID from Juriconnect reference
https://linkeddata.overheid.nl/service/get-id?jci={JURICONNECT_STRING}&output=xml

# Count related links
https://linkeddata.overheid.nl/service/get-aantal?ext-id={ID}&output=xml

# Get linked items (requires credentials for some)
https://linkeddata.overheid.nl/service/get-links?ext-id={ID}&output=xml
```

**Juriconnect BWB reference format:**

```
jci1.3:c:BWBR0003045&boek=2&titeldeel=1&artikel=1
```

Components: `jci1.3` (version) `:c:` (consolidation) `BWBR0003045` (BWB ID) then hierarchical path using `&`-separated key=value pairs.

**Agent suitability:** Specialized. Useful when you need to find what other laws reference a specific article, or to navigate the legal network. Some services require credentials.

---

### Option 7: WTI Metadata (Amendment history)

**URL pattern:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/{BWBID}/{BWBID}.WTI
```

**Contains:** Complete amendment history, which Staatsblad/Staatscourant publications modified which articles, effective dates per article.

**Agent suitability:** Specialized. Useful when tracking legislative history or understanding when a specific article was last amended.

---

## Recommended Agent Workflow

### Primary path: `/afdrukken` (when article path is known)

```
GET https://wetten.overheid.nl/{BWBID}/{DATE}/0/{PATH}/afdrukken
```

This is the simplest and most effective method. An agent can WebFetch this URL and extract the article text with a simple prompt. No XML parsing, no multi-step pipeline.

**Example:** "What does article 310 of the Wetboek van Strafrecht say?"

```
WebFetch https://wetten.overheid.nl/BWBR0001854/2025-01-01/0/BoekTweede/TiteldeelXXII/Artikel310/afdrukken
```

### Discovery path: SRU + `/afdrukken` (when starting from a question)

When the agent doesn't know the BWB ID or article path:

**Step 1:** Use SRU to find the law:

```
GET https://zoekservice.overheid.nl/sru/Search
  ?operation=searchRetrieve&version=1.2&x-connection=BWB
  &query=overheidbwb.afkorting=WvSr&maximumRecords=1
```

**Step 2:** Fetch the main page to discover the structure/path:

```
WebFetch https://wetten.overheid.nl/{BWBID}/{DATE}
  → extract article paths from the table of contents
```

**Step 3:** Fetch the specific article via `/afdrukken`:

```
WebFetch https://wetten.overheid.nl/{BWBID}/{DATE}/0/{PATH}/afdrukken
```

### Structured extraction path: XML Repository (when machine parsing is needed)

For programmatic extraction of multiple articles, cross-references, or when structured data is required:

```
GET https://repository.officiele-overheidspublicaties.nl/bwb/{BWBID}/{DATE}_{VER}/xml/{BWBID}_{DATE}_{VER}.xml
```

Parse with XPath: `//artikel[@bwb-ng-variabel-deel="/Boek2/Titeldeel1/Artikel5"]`

---

## Comparison

| Criterion | HTML | `/afdrukken` | XML Repo | SRU | Manifest | LiDO |
|-----------|------|-------------|----------|-----|----------|------|
| Agent-parseable | Poor | **Excellent** | Excellent | Good | Good | Good |
| Article isolation | No | **Yes (native)** | Yes (parse) | N/A | N/A | N/A |
| Discovery/search | No | No | No | **Excellent** | No | Partial |
| Auth required | No | No | No | No | No | Partial |
| Payload size | Huge | **Tiny** | Large | Small | Small | Small |
| Cross-references | No | No | Inline | No | No | Yes |
| Historical versions | Via URL | Via URL | Yes | Yes | Full catalog | No |
| Requires XML parsing | No | **No** | Yes | Yes | Yes | Yes |

---

## Outcome

**Status**: DECISION

**Primary method**: The `/afdrukken` suffix on article-level URLs is the clear winner for agent access. It produces a minimal, focused page containing just the requested article text — directly consumable by WebFetch without any XML parsing.

**Key insight**: Appending `/afdrukken` to any structural level of a law URL (article, section, title, chapter) produces a print-friendly page scoped to exactly that level. This is undocumented but verified across multiple laws (BW, WvSr) and hierarchy levels.

**Workflow summary for the future skill:**

| Step | Method | When |
|------|--------|------|
| 1. Resolve law | SRU (`overheidbwb.afkorting` or `dcterms.identifier`) | BWB ID unknown |
| 2. Discover path | WebFetch main page TOC | Article path unknown |
| 3. **Read article** | **WebFetch `/{PATH}/afdrukken`** | **Always** |
| 4. Follow refs | LiDO or construct new `/afdrukken` URLs | Cross-references needed |
| 5. Structured data | XML Repository + XPath | Programmatic extraction |

**The `/afdrukken` path is the primary recommended method.** XML Repository remains valuable as a fallback for structured/programmatic use and for discovering the `bwb-ng-variabel-deel` paths that map to URL path components.

**BWB ID prefixes** (for reference):

| Prefix | Meaning |
|--------|---------|
| `BWBR` | Rijksregeling (national regulation) |
| `BWBV` | Verdrag (treaty) |
| `BWBA` | Autonome regeling (autonomous regulation) |

**Common abbreviations** (searchable via `overheidbwb.afkorting`):

| Abbreviation | Full name | BWB ID |
|--------------|-----------|--------|
| BW | Burgerlijk Wetboek | BWBR0002656 (Boek 1) through BWBR0005291 (Boek 8) |
| WvSr | Wetboek van Strafrecht | BWBR0001854 |
| WvSv | Wetboek van Strafvordering | BWBR0001903 |
| Awb | Algemene wet bestuursrecht | BWBR0005537 |
| Gw | Grondwet | BWBR0001840 |

## References

- [BWB Standard](https://standaarden.overheid.nl/bwb)
- [SRU BWB Manual (PDF)](https://data.overheid.nl/sites/default/files/dataset/ab78ba3f-bc07-49cc-95f2-0e23b8653181/resources/Handleiding+SRU+BWB.pdf)
- [Building a BWB copy](https://www.overheid.nl/help/wet-en-regelgeving/een-eigen-kopie-van-het-basiswettenbestand-opbouwen)
- [BWB Open Data](https://data.overheid.nl/dataset/basis-wetten-bestand)
- [LiDO Services](https://linkeddata.overheid.nl/front/portal/services)
- [Repository Service Documentation](https://repository.officiele-overheidspublicaties.nl/uitleg_service_officielepublicaties.html)
- [Juriconnect Documentation](https://juriconnect.nl/implementatie.asp?subpagina=documentatie)
- [identifier.overheid.nl Resolver](https://www.overheid.nl/resolver/introductie)
- [XML Schema: toestand](https://repository.officiele-overheidspublicaties.nl/Schema/BWB-toestand/2016-1/xsd/toestand_2016-1.xsd)
- [XML Schema: WTI](https://repository.officiele-overheidspublicaties.nl/Schema/BWB-WTI/2016-1/xsd/wti_2016-1.xsd)
