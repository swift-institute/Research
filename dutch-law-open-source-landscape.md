# Open-Source Landscape for Dutch Legal Research

<!--
---
version: 1.0.0
last_updated: 2026-03-02
status: RECOMMENDATION
tier: 2
---
-->

## Context

We built a `dutch-law` skill [NL-WET-*] for looking up individual articles on wetten.overheid.nl. To expand into a comprehensive Dutch legal research capability — covering case law, parliamentary data, cross-references, and legal analysis — we need to understand what open-source tools, APIs, datasets, and agent integrations already exist. This survey maps the complete landscape so we can build on existing infrastructure rather than duplicating effort.

**Trigger**: Expanding `dutch-law` skill scope.
**Methodology**: Systematic search per [RES-021]/[RES-023] (Kitchenham-lite for Tier 2).

## Research Questions

| RQ | Question |
|----|----------|
| RQ1 | What open-source tools exist for accessing Dutch legislation (wetten)? |
| RQ2 | What open-source tools exist for accessing Dutch case law (rechtspraak)? |
| RQ3 | What open-source tools exist for Dutch parliamentary data? |
| RQ4 | What MCP servers / agent integrations exist for Dutch law? |
| RQ5 | What NLP/ML models and datasets exist for Dutch legal text? |
| RQ6 | What machine-readable law initiatives exist from the Dutch government? |

## Search Strategy

**Sources**: GitHub (gh search repos), PyPI, npm, Hugging Face, WebSearch (Google), data.overheid.nl
**Query terms**: `dutch-law`, `rechtspraak`, `wetsuite`, `wetten.overheid.nl`, `ECLI Netherlands`, `parlhist`, `openkamer`, `MinBZK law`, `Dutch legal NLP`, `awesome-legal-data`
**Inclusion**: Open-source, actively maintained (commit in last 2 years), Dutch law focus
**Exclusion**: Forks, homework projects (0 stars + no description), non-Dutch jurisdictions, closed-source SaaS

---

## RQ1: Legislation Access Tools

### 1.1 Ansvar-Systems/Dutch-law-mcp

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/Ansvar-Systems/Dutch-law-mcp](https://github.com/Ansvar-Systems/Dutch-law-mcp) |
| **Language** | TypeScript |
| **Stars** | 2 |
| **Last updated** | 2026-02-28 |
| **License** | Apache-2.0 |

**What it does**: Production-grade MCP server for Dutch legal research. Pre-ingests legislation, case law, and parliamentary documents into a local SQLite database with FTS5 full-text indexing.

**Data scope**: 3,248 statutes, 79,967 articles, 903,000+ court decisions (ECLI-indexed), 21,891 parliamentary documents, 1,008 EU directives.

**14 MCP tools exposed**:
- `search_legislation` — Full-text search across statutes
- `get_provision` — Retrieve specific articles by citation (e.g., "Art. 6:162 BW")
- `search_case_law` — Query court decisions with filtering
- `get_preparatory_works` — Parliamentary documents
- `validate_citation` — Check citation validity
- `build_legal_stance` — Assemble research bundles
- `check_currency` — Verify if provisions are currently in force
- `get_eu_basis` / `get_dutch_implementations` — EU cross-references

**Installation**: `npx @ansvar/dutch-law-mcp` or remote at `https://dutch-law-mcp.vercel.app/mcp`

**Assessment**: The most comprehensive single tool found. Directly usable as an MCP server for Claude. Full-text search fills the gap that wetten.overheid.nl's SRU API lacks. However, relies on periodic ingestion (database may lag behind live law). Worth integrating directly.

---

### 1.2 MinBZK/poc-machine-law (RegelRecht)

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/MinBZK/poc-machine-law](https://github.com/MinBZK/poc-machine-law) |
| **Language** | Python, Go |
| **Stars** | 37 |
| **Last updated** | active |
| **License** | EUPL |

**What it does**: Treats Dutch laws as executable algorithms. Laws are encoded in YAML; an execution engine interprets them. Covers social benefit laws (AOW, zorgtoeslag, huurtoeslag, participatiewet, kieswet).

**MCP server**: Yes, at `http://0.0.0.0:8001/mcp/` with tools: `execute_law`, `check_eligibility`, `calculate_benefit_amount`.

**Assessment**: Remarkable for computational law. Not a general legislation lookup tool — it's for *executing* specific benefit/eligibility calculations. Complementary to, not competing with, our `dutch-law` skill.

---

### 1.3 statengeneraal/laws-markdown

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/statengeneraal/laws-markdown](https://github.com/statengeneraal/laws-markdown) |
| **Language** | — (data) |
| **Stars** | 24 |
| **Last updated** | 2025-11-03 |

**What it does**: Human-legible Markdown versions of all Dutch laws, scraped from wetten.overheid.nl. Git-tracked, enabling diff-based legislative change tracking.

**Assessment**: Interesting for versioning history but not actively maintained as a tool. The data is stale vs. live wetten.overheid.nl.

---

### 1.4 WetSuiteLeiden/wetsuite-core

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/WetSuiteLeiden/wetsuite-core](https://github.com/WetSuiteLeiden/wetsuite-core) |
| **Language** | Python |
| **Stars** | 0 |
| **Last updated** | 2025-12-09 |
| **License** | EUPL-1.2 |

**What it does**: Python library for NLP analysis of Dutch legal text. Provides `datasets.load()` for pre-made legal datasets, helpers for XML parsing, text processing, and data collection from BWB/rechtspraak.

**Website**: [wetsuite.nl](https://www.wetsuite.nl/) with dataset catalogue.

**Assessment**: Academic tool (Leiden University). Low adoption but solid for NLP research on Dutch legal text. The dataset catalogue is valuable for understanding what pre-processed data exists.

---

### 1.5 MinBZK/regels.overheid.nl

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/MinBZK/regels.overheid.nl](https://github.com/MinBZK/regels.overheid.nl) |
| **Language** | TypeScript |
| **Stars** | 26 |

**What it does**: The Dutch government's rules registry platform. Rules are machine-readable specifications linked to wetten.overheid.nl via Juriconnect deep links. Supports multiple methods including **RegelSpraak** — a controlled Dutch language readable by both lawyers and computers.

**Assessment**: Government initiative, not an agent tool. Important context: the Dutch government is actively investing in machine-readable law.

---

## RQ2: Case Law (Rechtspraak) Tools

### 2.1 Official APIs

**Two separate APIs exist:**

#### data.rechtspraak.nl (Official judiciary API)

| Endpoint | Purpose | Format |
|----------|---------|--------|
| `data.rechtspraak.nl/uitspraken/content?id={ECLI}` | Get full verdict by ECLI | XML |
| `data.rechtspraak.nl/uitspraken/zoeken` | Search verdicts | XML |

Two-step process: (1) query ECLI index → (2) fetch document by ECLI. Rate limit: 10 req/sec. ~800,000 full-text verdicts, ~3 million metadata records.

#### openrechtspraak.nl/api/v1 (Community API)

| Endpoint | Purpose | Format |
|----------|---------|--------|
| `/person` | Search judges | JSON |
| `/person/{id}/verdicts` | Get verdicts by judge | JSON |

Free, no auth, JSON responses. Focused on judge transparency (person-centered, not case-centered).

---

### 2.2 maastrichtlawtech (Maastricht University Law & Tech Lab)

The most prolific producer of Dutch legal tech tools:

| Repo | Stars | Purpose | Language |
|------|-------|---------|----------|
| [extraction_libraries](https://github.com/maastrichtlawtech/extraction_libraries) | 13 | Umbrella (archived, split into individual repos) | — |
| [rechtspraak-extractor](https://github.com/maastrichtlawtech/rechtspraak-extractor) | 2 | Extract rechtspraak data + metadata via API | Python |
| [rechtspraak-segmentation](https://github.com/maastrichtlawtech/rechtspraak-segmentation) | 2 | Segment verdicts into structural sections | Python |
| [rechtspraak-citation-extractor](https://github.com/maastrichtlawtech/rechtspraak_citation_extraction) | — | Extract citations from verdicts | Python |
| [case-law-explorer](https://github.com/maastrichtlawtech/case-law-explorer) | — | Network analysis of Dutch/EU court decisions | Python |
| [awesome-legal-nlp](https://github.com/maastrichtlawtech/awesome-legal-nlp) | — | Curated resource list | — |

**Assessment**: Academic-quality, well-structured libraries. The `rechtspraak-extractor` on PyPI is the most practical for programmatic access.

---

### 2.3 digitalheir/rechtspraak-js

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/cacfd3a/rechtspraak-js](https://github.com/digitalheir/rechtspraak-js) |
| **Language** | TypeScript |
| **Stars** | 17 |
| **Last updated** | 2025-11-25 |

**What it does**: Sanitizes and formalizes Dutch court judgment XML from Rechtspraak.nl into well-formed JSON-LD with JSON Schema. Published as linked data graph.

**Assessment**: Most starred rechtspraak-specific tool. Useful for structured data extraction from verdicts.

---

### 2.4 axyr/rechtspraak-solr-mcp-server

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/axyr/rechtspraak-solr-mcp-server](https://github.com/axyr/rechtspraak-solr-mcp-server) |
| **Language** | Python |
| **Stars** | 2 |
| **Last updated** | 2025-10-10 |

**What it does**: MCP server backed by Solr-indexed rechtspraak data. Enables AI agent search over Dutch case law.

**Assessment**: Another MCP server option for case law, but smaller scope than Ansvar's.

---

### 2.5 CaseLawAnalytics

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/caselawanalytics/CaseLawAnalytics](https://github.com/caselawanalytics/CaseLawAnalytics) |
| **Language** | Python |

**What it does**: Constructs citation networks from Dutch case law. Queries rechtspraak.nl API + LiDO for cross-references. Calculates network statistics. Joint project of Maastricht University + Netherlands eScience Center.

**Assessment**: Specialized for citation network analysis, not general lookup. Demonstrates LiDO cross-reference extraction.

---

## RQ3: Parliamentary Data Tools

### 3.1 opendata.tweedekamer.nl (Official)

| API | Format | Purpose |
|-----|--------|---------|
| **OData API** | JSON | Search parliamentary data (bills, motions, amendments, reports) |
| **SyncFeed API** | XML (Atom 1.0) | Synchronize data with local database |

**Scope**: Tweede Kamer only. Eerste Kamer data not available via these APIs.

**Documentation**: [opendata.tweedekamer.nl/documentatie](https://opendata.tweedekamer.nl/documentatie)

**GitHub**: [TweedeKamerDerStaten-Generaal/OpenDataPortaal](https://github.com/TweedeKamerDerStaten-Generaal/OpenDataPortaal)

---

### 3.2 openkamer/openkamer

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/openkamer/openkamer](https://github.com/openkamer/openkamer) |
| **Language** | Python |
| **Stars** | 70 |
| **Last updated** | 2026-02-12 |

**What it does**: Full parliamentary insight application at [openkamer.org](https://www.openkamer.org/). Aggregates Tweede Kamer data into a browsable interface.

**Assessment**: Highest-starred Dutch legal/parliamentary tool found. Active as of Feb 2026. Valuable as reference for data model.

---

### 3.3 openkamer/tkapi

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/openkamer/tkapi](https://github.com/openkamer/tkapi) |
| **Language** | Python |
| **Stars** | 20 |
| **Last updated** | 2025-12-28 |

**What it does**: Pure Python ORM and bindings for the Tweede Kamer OData API. Type-annotated.

**Assessment**: The cleanest way to access parliamentary data from Python. Well-maintained.

---

### 3.4 mastaal/parlhist

| Attribute | Value |
|-----------|-------|
| **Repo** | [github.com/mastaal/parlhist](https://github.com/mastaal/parlhist) (moved to Codeberg) |
| **Language** | Python |
| **Stars** | 2 |
| **Last updated** | 2026-01-22 |

**What it does**: Download and analyze Dutch parliamentary minutes (Handelingen) and documents (Kamerstukken). Enables empirical/statistical academic studies.

**Assessment**: Academic tool. Also the author of `mastaal/uitspraken` (load rechtspraak XML into database).

---

## RQ4: MCP Servers / Agent Integrations

| MCP Server | Domain | Transport | Data |
|------------|--------|-----------|------|
| **Ansvar-Systems/Dutch-law-mcp** | Legislation + case law + parliamentary | stdio / HTTP | 3,248 statutes, 903k decisions, 21k parliamentary docs |
| **MinBZK/poc-machine-law** | Executable benefit law | HTTP | ~10 social benefit laws |
| **axyr/rechtspraak-solr-mcp-server** | Case law | MCP/Solr | Rechtspraak index |
| **viralistic/Dutch_Law_MCP** | Legislation | TypeScript | Unknown scope (0 stars, minimal) |

**Assessment**: Ansvar's Dutch-law-mcp is the clear leader for comprehensive MCP integration. poc-machine-law fills a unique niche (computational law). The others are experimental.

---

## RQ5: NLP/ML Models and Datasets

### Models

| Model | Source | Type | Use |
|-------|--------|------|-----|
| `fine-tuned/dutch-legal-c` | Hugging Face | Embedding | Dutch legal text classification/retrieval |
| `nlpaueb/legal-bert-base-uncased` | Hugging Face | BERT | Legal NER, classification (multilingual) |
| GPT-NL (planned) | SURF/TNO | LLM | Dutch-native LLM (in development) |

### Datasets

| Dataset | Source | Content |
|---------|--------|---------|
| `ethux/Dutch-GOV-Law-wetten.overheid.nl` | Hugging Face | Full BWB dump |
| bBSARD | Academic | Statutory article retrieval for Dutch (first of its kind) |
| `fine-tuned/dutch-legal-c-*` | Hugging Face | Chunked Dutch legal text (64/128/256 token variants) |
| LawInstruct | GitHub (JoelNiklaus) | Multi-jurisdictional instruction dataset (includes Dutch) |
| WetSuite datasets | wetsuite.nl | Pre-processed BWB, rechtspraak collections |

### Dutch NLP Tools (General)

| Tool | Purpose |
|------|---------|
| [Frog](https://github.com/proycon/python-frog) | Dutch POS tagging, lemmatization, NER, dependency parsing |
| spaCy `nl_core_news_*` | Dutch language models for NLP pipeline |

---

## RQ6: Government Machine-Readable Law Initiatives

| Initiative | Owner | Purpose | Status |
|------------|-------|---------|--------|
| **regels.overheid.nl** | MinBZK | Rules registry linked to wetten.overheid.nl | Active |
| **RegelSpraak** | MinBZK/ALEF | Controlled Dutch for executable rules | Active |
| **NRML** | MinBZK | Normalized Rule Model Language | Active (7 stars) |
| **RegelRecht** | MinBZK | PoC for executable law | Active (37 stars) |
| **wetstaal** | MinBZK | Formal syntax/semantics for Dutch law | Active (3 stars) |
| **LEOS** | MinBZK (EU fork) | Legislation Editing Open Software | Active |

The Dutch Ministry of Interior (MinBZK) has a significant open-source portfolio for machine-readable law. The ecosystem is converging on: (1) human-readable controlled Dutch (RegelSpraak), (2) formal machine representation (NRML), and (3) executable specifications (RegelRecht).

---

## Synthesis

### Landscape Map

```
                    ┌─────────────────────────────────┐
                    │     Dutch Legal Data Sources     │
                    └───────┬─────────┬───────┬───────┘
                            │         │       │
                    ┌───────▼───┐ ┌───▼───┐ ┌─▼──────────┐
                    │ Legislation│ │ Case  │ │Parliamentary│
                    │  (BWB)    │ │  Law  │ │   Data     │
                    └───┬───┬───┘ └──┬──┬─┘ └──┬────┬────┘
                        │   │        │  │      │    │
              ┌─────────▼┐ │  ┌─────▼┐ │  ┌───▼┐  │
              │wetten.nl │ │  │recht-│ │  │TK  │  │
              │/afdrukken│ │  │spraak│ │  │OData│  │
              │SRU, XML  │ │  │.nl   │ │  │API  │  │
              └──────────┘ │  └──────┘ │  └─────┘  │
                           │           │           │
              ┌────────────▼───────────▼───────────▼──┐
              │         Open-Source Tools              │
              │                                       │
              │  MCP Servers:                          │
              │  • Dutch-law-mcp (comprehensive)      │
              │  • poc-machine-law (executable)        │
              │  • rechtspraak-solr-mcp               │
              │                                       │
              │  Libraries:                            │
              │  • rechtspraak-extractor (Python)     │
              │  • rechtspraak-js (TypeScript)         │
              │  • tkapi (Python, parliamentary)       │
              │  • wetsuite-core (NLP)                 │
              │  • openkamer (web app)                │
              │                                       │
              │  Datasets:                             │
              │  • ethux/Dutch-GOV-Law (HF)           │
              │  • bBSARD (article retrieval)          │
              │  • dutch-legal-c (embeddings)          │
              └───────────────────────────────────────┘
```

### Gap Analysis

| Capability | Covered by | Gap |
|------------|------------|-----|
| Read specific article | **dutch-law skill** (`/afdrukken`) | None |
| Full-text search in legislation | Dutch-law-mcp (FTS5) | Not in our skill yet |
| Case law by ECLI | data.rechtspraak.nl API | Not in our skill |
| Case law search | Dutch-law-mcp, rechtspraak-extractor | Not in our skill |
| Parliamentary documents | tkapi, TK OData API | Not in our skill |
| Citation network | CaseLawAnalytics, LiDO | Not in our skill |
| Executable benefit law | poc-machine-law | Specialized, not general |
| Legal NLP (Dutch) | wetsuite, Frog, spaCy | Out of scope for skill |
| EU cross-references | Dutch-law-mcp | Not in our skill |

---

## Outcome

**Status**: RECOMMENDATION

### Primary recommendation: Integrate Dutch-law-mcp

[Ansvar-Systems/Dutch-law-mcp](https://github.com/Ansvar-Systems/Dutch-law-mcp) is the single most valuable tool for expanding the `dutch-law` skill:
- Already an MCP server (direct Claude integration)
- Full-text search across legislation (fills our biggest gap)
- Case law search (903k decisions)
- Parliamentary documents (21k kamerstukken)
- Citation validation
- Apache-2.0 licensed
- Remote endpoint available: `https://dutch-law-mcp.vercel.app/mcp`

### Secondary recommendations

1. **Case law**: Add rechtspraak.nl API endpoints (`data.rechtspraak.nl/uitspraken/content?id={ECLI}`) to the `dutch-law` skill as a new section [NL-WET-012+]
2. **Parliamentary**: Document the Tweede Kamer OData API (`opendata.tweedekamer.nl`) in the skill
3. **Do not duplicate**: These tools exist and are maintained. Reference them rather than reimplementing

### What to NOT build

- Full-text search engine for legislation (Dutch-law-mcp does this)
- Rechtspraak scraper (maastrichtlawtech provides this)
- Parliamentary data library (tkapi/openkamer exist)
- Dutch legal NLP (academic domain, out of scope)

### Skill evolution path

| Phase | Scope | Method |
|-------|-------|--------|
| Current | Read articles by path | `/afdrukken` [NL-WET-001] |
| Next | Add case law lookup | rechtspraak.nl API + [NL-WET-012] |
| Next | Add parliamentary data | TK OData API + [NL-WET-013] |
| Consider | MCP server integration | Dutch-law-mcp as external tool |

---

## References

### Official Government APIs
- [wetten.overheid.nl](https://wetten.overheid.nl/) — Legislation portal
- [data.rechtspraak.nl](https://www.rechtspraak.nl/Uitspraken/Paginas/Open-Data.aspx) — Case law open data
- [openrechtspraak.nl/api_docs](https://openrechtspraak.nl/api_docs) — Judge/verdict API
- [opendata.tweedekamer.nl](https://opendata.tweedekamer.nl/) — Parliamentary open data
- [linkeddata.overheid.nl](https://linkeddata.overheid.nl/front/portal/services) — LiDO linked data
- [data.overheid.nl](https://data.overheid.nl/) — National open data portal

### Key Open-Source Repositories
- [Ansvar-Systems/Dutch-law-mcp](https://github.com/Ansvar-Systems/Dutch-law-mcp) — Comprehensive MCP server
- [MinBZK/poc-machine-law](https://github.com/MinBZK/poc-machine-law) — Executable law PoC
- [MinBZK/regels.overheid.nl](https://github.com/MinBZK/regels.overheid.nl) — Rules registry
- [openkamer/openkamer](https://github.com/openkamer/openkamer) — Parliamentary insight (70 stars)
- [openkamer/tkapi](https://github.com/openkamer/tkapi) — TK OData Python bindings (20 stars)
- [maastrichtlawtech/rechtspraak-extractor](https://github.com/maastrichtlawtech/rechtspraak-extractor) — Case law extractor
- [digitalheir/rechtspraak-js](https://github.com/digitalheir/rechtspraak-js) — Case law JSON-LD (17 stars)
- [WetSuiteLeiden/wetsuite-core](https://github.com/WetSuiteLeiden/wetsuite-core) — Legal NLP toolkit
- [mastaal/parlhist](https://github.com/mastaal/parlhist) — Parliamentary minutes analysis
- [caselawanalytics/CaseLawAnalytics](https://github.com/caselawanalytics/CaseLawAnalytics) — Citation networks

### Curated Lists
- [openlegaldata/awesome-legal-data](https://github.com/openlegaldata/awesome-legal-data)
- [maastrichtlawtech/awesome-legal-nlp](https://github.com/maastrichtlawtech/awesome-legal-nlp)
- [Liquid-Legal-Institute/Legal-Text-Analytics](https://github.com/Liquid-Legal-Institute/Legal-Text-Analytics)

### Datasets (Hugging Face)
- [ethux/Dutch-GOV-Law-wetten.overheid.nl](https://huggingface.co/datasets/ethux/Dutch-GOV-Law-wetten.overheid.nl)
- [fine-tuned/dutch-legal-c](https://huggingface.co/fine-tuned/dutch-legal-c)
