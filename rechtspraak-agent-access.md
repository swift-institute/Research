# Agent-Friendly Access to Dutch Case Law (rechtspraak.nl)

<!--
---
version: 1.0.0
last_updated: 2026-03-02
status: DECISION
tier: 1
---
-->

## Context

The `dutch-law` skill [NL-WET-*] covers legislation lookup via wetten.overheid.nl. This research maps the case law API (data.rechtspraak.nl) to enable extending the skill with case law lookup. Goal: produce actionable URL patterns like we did with `/afdrukken` for legislation.

**Trigger**: Extending dutch-law skill with [NL-WET-012+].
**Prior research**: `wetten-overheid-agent-access.md`, `dutch-law-open-source-landscape.md`.

## Question

What are the exact API endpoints, parameters, and response formats for agent-friendly Dutch case law access?

## Analysis

### API Architecture

Dutch case law uses a **two-step process**:
1. **Search** the ECLI index → get a list of ECLI identifiers
2. **Fetch** the full verdict by ECLI → get XML with metadata + full text

### ECLI Identifier Format

```
ECLI:NL:{COURT}:{YEAR}:{NUMBER}
```

| Component | Meaning | Example |
|-----------|---------|---------|
| `ECLI` | Fixed prefix | — |
| `NL` | Country code | Netherlands |
| `{COURT}` | Court abbreviation (max 7 chars) | `HR`, `RBAMS`, `GHSHE` |
| `{YEAR}` | Year of decision | `2023` |
| `{NUMBER}` | Sequential number | `1291` |

**Example**: `ECLI:NL:HR:2023:1291` = Hoge Raad, 2023, decision #1291.

---

### Endpoint 1: Content (Fetch verdict by ECLI)

**URL** (verified):

```
https://data.rechtspraak.nl/uitspraken/content?id={ECLI}
```

**Example**:

```
https://data.rechtspraak.nl/uitspraken/content?id=ECLI:NL:HR:2023:1291
```

**Response**: XML (~25 KB for a typical Hoge Raad decision). Contains:

```xml
<open-rechtspraak>
  <rdf:RDF>
    <rdf:Description>
      <dcterms:identifier>ECLI:NL:HR:2023:1291</dcterms:identifier>
      <dcterms:creator>Hoge Raad</dcterms:creator>
      <dcterms:date>2023-09-22</dcterms:date>
      <psi:zaaknummer>22/01446</psi:zaaknummer>
      <dcterms:subject>Civiel recht; Arbeidsrecht</dcterms:subject>
    </rdf:Description>
  </rdf:RDF>

  <inhoudsindicatie>           <!-- Summary -->
    <para>Arbeidsrecht (art. 7:611 BW)...</para>
  </inhoudsindicatie>

  <uitspraak>                  <!-- Full verdict text -->
    <uitspraak.info>           <!-- Parties, case number -->
    <section role="procesverloop">  <!-- Procedural history -->
    <section role="overwegingen">   <!-- Court's reasoning -->
    <section role="beslissing">     <!-- Judgment/decision -->
  </uitspraak>
</open-rechtspraak>
```

**Key XML elements for agents**:

| Element | Content | Agent use |
|---------|---------|-----------|
| `dcterms:identifier` | ECLI | Citation |
| `dcterms:creator` | Court name | Context |
| `dcterms:date` | Decision date | Citation |
| `psi:zaaknummer` | Case number | Reference |
| `dcterms:subject` | Legal area(s) | Classification |
| `inhoudsindicatie/para` | Summary | **Quick answer** |
| `uitspraak` | Full verdict text | Deep analysis |
| `section[@role="beslissing"]` | Decision/ruling | **Key outcome** |
| `section[@role="overwegingen"]` | Legal reasoning | Analysis |

**Agent suitability**: Excellent. The `inhoudsindicatie` (summary) alone often answers the question. The full `uitspraak` is structured into sections. An agent can WebFetch this URL and extract specific sections with a prompt.

---

### Endpoint 2: Search (ECLI index)

**URL** (verified):

```
https://data.rechtspraak.nl/uitspraken/zoeken?{PARAMETERS}
```

**Parameters** (verified via WetSuite documentation + empirical testing):

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `max` | int | Max results (default: 1000) | `max=10` |
| `from` | int | Offset for pagination (0-based) | `from=10` |
| `sort` | string | `ASC` (oldest first, default) or `DESC` (newest first) | `sort=DESC` |
| `type` | string | `Uitspraak` (verdict) or `Conclusie` (AG opinion) | `type=Uitspraak` |
| `date` | date | Decision date. One value = exact. Two values = range. | `date=2025-01-15` |
| `modified` | datetime | Last modification. One value = since. Two = range. | `modified=2025-01-01T00:00:00` |
| `return` | string | `DOC` = only results with full text available | `return=DOC` |
| `subject` | URI | Legal area (rechtsgebied) | See table below |
| `creator` | URI | Court (instantie) | See table below |
| `replaces` | string | Old LJN identifier → find ECLI equivalent | `replaces=BQ1234` |

**Date range**: Use two `date` parameters: `date=2025-01-01&date=2025-01-31`.

**Important**: No full-text search parameter. The search endpoint is metadata-only. To find cases by content, use the uitspraken.rechtspraak.nl web interface or Dutch-law-mcp.

**Response**: Atom XML feed with entries containing `<id>` (ECLI), `<title>`, `<summary>`, `<updated>`, `<link>`.

---

### Subject URIs (Legal Areas)

| `subject` value | Legal area |
|-----------------|------------|
| `http://psi.rechtspraak.nl/rechtsgebied#civielRecht` | Civiel recht (civil law) |
| `http://psi.rechtspraak.nl/rechtsgebied#strafrecht` | Strafrecht (criminal law) |
| `http://psi.rechtspraak.nl/rechtsgebied#bestuursrecht` | Bestuursrecht (administrative law) |
| `http://psi.rechtspraak.nl/rechtsgebied#belastingrecht` | Belastingrecht (tax law) |

Verified: `subject=http://psi.rechtspraak.nl/rechtsgebied%23civielRecht` returned 392 results for a single date.

---

### Creator URIs (Courts)

| `creator` value | Court |
|-----------------|-------|
| `http://standaarden.overheid.nl/owms/terms/Hoge_Raad_der_Nederlanden` | Hoge Raad (128,310 results) |
| `http://standaarden.overheid.nl/owms/terms/Rechtbank_Amsterdam` | Rechtbank Amsterdam |
| `http://standaarden.overheid.nl/owms/terms/Rechtbank_Den_Haag` | Rechtbank Den Haag |
| `http://standaarden.overheid.nl/owms/terms/Gerechtshof_Amsterdam` | Gerechtshof Amsterdam |
| `http://standaarden.overheid.nl/owms/terms/Centrale_Raad_van_Beroep` | Centrale Raad van Beroep |
| `http://standaarden.overheid.nl/owms/terms/Raad_van_State` | Raad van State |

Pattern: `http://standaarden.overheid.nl/owms/terms/{Court_Name_With_Underscores}`

Verified: Hoge_Raad_der_Nederlanden returned 128,310 ECLIs. `Hoge_Raad` alone returned 0 — the full canonical name is required.

---

### Court Codes (ECLI)

| Code | Court | Level |
|------|-------|-------|
| **HR** | Hoge Raad | Supreme Court |
| **PHR** | Parket bij de Hoge Raad | AG at Supreme Court |
| **RVS** | Raad van State | Council of State |
| **CRVB** | Centrale Raad van Beroep | Social Security Appeals |
| **CBB** | College van Beroep voor het bedrijfsleven | Trade/Industry Appeals |
| **GHAMS** | Gerechtshof Amsterdam | Court of Appeal |
| **GHARL** | Gerechtshof Arnhem-Leeuwarden | Court of Appeal |
| **GHDHA** | Gerechtshof Den Haag | Court of Appeal |
| **GHSHE** | Gerechtshof 's-Hertogenbosch | Court of Appeal |
| **RBAMS** | Rechtbank Amsterdam | District Court |
| **RBDHA** | Rechtbank Den Haag | District Court |
| **RBGEL** | Rechtbank Gelderland | District Court |
| **RBLIM** | Rechtbank Limburg | District Court |
| **RBMNE** | Rechtbank Midden-Nederland | District Court |
| **RBNHO** | Rechtbank Noord-Holland | District Court |
| **RBNNE** | Rechtbank Noord-Nederland | District Court |
| **RBOBR** | Rechtbank Oost-Brabant | District Court |
| **RBOVE** | Rechtbank Overijssel | District Court |
| **RBROT** | Rechtbank Rotterdam | District Court |
| **RBZWB** | Rechtbank Zeeland-West-Brabant | District Court |

---

### Data Scale

| Metric | Value |
|--------|-------|
| Total ECLIs | ~3,646,105 |
| Full-text verdicts | ~800,000+ |
| Metadata-only | ~2,800,000 |
| Rate limit | 10 requests/second |

---

## Recommended Agent Workflow

### When the user has an ECLI

```
WebFetch https://data.rechtspraak.nl/uitspraken/content?id={ECLI}
  → extract inhoudsindicatie (summary) for quick answer
  → extract section[@role="beslissing"] for the ruling
  → extract section[@role="overwegingen"] for reasoning
```

This is the `/afdrukken` equivalent for case law — a single URL that gives focused, structured content.

### When the user describes a case

1. **Search** by date + court + legal area:
   ```
   WebFetch https://data.rechtspraak.nl/uitspraken/zoeken
     ?type=Uitspraak
     &creator=http://standaarden.overheid.nl/owms/terms/{Court}
     &subject=http://psi.rechtspraak.nl/rechtsgebied%23{Area}
     &date={YYYY-MM-DD}
     &max=10&sort=DESC
   ```
2. **Extract** ECLIs from the Atom feed
3. **Fetch** the most relevant verdict by ECLI

### When the user wants recent case law on a topic

No full-text search via API. Options:
- Use Dutch-law-mcp MCP server (has FTS5 index over 903k decisions)
- Use the web interface at uitspraken.rechtspraak.nl (JavaScript-rendered, not agent-friendly)
- Search by legal area + date range and scan summaries

---

## Comparison with Legislation Access

| Criterion | Legislation (wetten.overheid.nl) | Case law (rechtspraak.nl) |
|-----------|----------------------------------|--------------------------|
| Primary method | `/afdrukken` (HTML) | Content endpoint (XML) |
| Identifier | BWB ID + path | ECLI |
| Search | SRU (14 metadata fields) | Atom feed (8 metadata fields) |
| Full-text search | No | No (API), Yes (Dutch-law-mcp) |
| Auth required | No | No |
| Rate limit | None documented | 10 req/sec |
| Response format | HTML (afdrukken) / XML (repo) | XML |
| Content structure | `<artikel>` / `<lid>` / `<al>` | `<inhoudsindicatie>` / `<uitspraak>` / `<section>` |

---

## Outcome

**Status**: DECISION

The case law API is straightforward for agents:
- **One URL** to fetch any verdict: `data.rechtspraak.nl/uitspraken/content?id={ECLI}`
- **Structured XML** with clear sections (summary, reasoning, decision)
- **Metadata search** by court, legal area, date, and type
- **No auth** required

The `inhoudsindicatie` (summary) element is the case law equivalent of a single article — focused, concise, immediately useful.

**Gap**: No full-text search in the API. For topic-based case law discovery, the Dutch-law-mcp MCP server or the web interface is needed.

## References

- [Open Data van de Rechtspraak](https://www.rechtspraak.nl/Uitspraken/Paginas/Open-Data.aspx)
- [Technical Documentation (PDF)](https://www.rechtspraak.nl/SiteCollectionDocuments/Technische-documentatie-Open-Data-van-de-Rechtspraak.pdf)
- [WetSuite rechtspraak module docs](https://wetsuite.knobs-dials.com/apidocs/wetsuite.datacollect.rechtspraaknl.html)
- [ECLI format (EU e-Justice Portal)](https://e-justice.europa.eu/topics/legislation-and-case-law/european-case-law-identifier-ecli/nl_en)
- [Dutch-law-mcp (MCP server)](https://github.com/Ansvar-Systems/Dutch-law-mcp)
