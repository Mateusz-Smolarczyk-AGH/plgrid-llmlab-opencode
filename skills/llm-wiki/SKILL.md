---
name: llm-wiki
description: "Create, populate, query and maintain local OKF (Open Knowledge Format) wikis: a self-contained bundle of markdown concept pages with YAML frontmatter plus index.md and log.md. Use when the user asks to build a wiki or knowledge base, ingest documents or a folder into a wiki, ask questions against a wiki, or lint/manage one. Raw-only vs flexible sourcing is chosen per wiki."
---

# LLM Wiki over OKF

Build and maintain persistent OKF knowledge bundles, locally, on demand. Each **wiki** is an
**Open Knowledge Format (OKF) v0.2** bundle: a directory of markdown concept pages with YAML
frontmatter, plus `index.md` and `log.md`. A wiki is self-describing: it carries its own
`AGENTS.md` (the OKF structure spec) at its root.

The full normative spec is bundled at `references/okf-spec.md` in this skill. **Read it before
your first wiki, and re-read the sections you touch.** It is copied verbatim into every new
wiki as that wiki's `AGENTS.md`. This skill tells you how to *work* a wiki; the spec defines
the *format*.

This is a local, agent-managed wiki — no external pipeline, no registry service, no crawling
infrastructure. The agent curates and reads the wiki directly.

---

## Ask before you create (never guess)

Before creating a wiki, ask the user three things:

1. **Where should it live?**
   - **Default (recommended):** `$WIKI_HOME` (default `~/wikis`) — a mounted, persistent
     location that survives container rebuilds.
   - **Current project:** `./wikis/<name>` inside the working repo, so the wiki travels with it.
   - **A custom path** the user names.
2. **Provenance mode** — how content may be sourced:
   - **raw-only:** wiki facts may come *only* from files in the wiki's `raw/`. No web, no
     model knowledge. Every claim traceable to a raw source.
   - **flexible:** the agent may also use web content, local documents, or its own knowledge
     when asked; provenance is recorded but not restricted to `raw/`.
3. **Language** of the wiki pages (e.g. `pl`, `en`). If the user does not say, infer it from
   the source documents and confirm.

Record the wiki's name, location, provenance mode and language in the preamble of its
`AGENTS.md` (see "Creating a wiki"). Honour those choices for that wiki thereafter.

---

## Layout of a wiki

```
<WIKI_HOME>/<name>/
  AGENTS.md        # this wiki's OKF structure spec (from references/okf-spec.md) + a "This wiki" preamble
  raw/             # source documents (immutable; may be empty in flexible mode)
  wiki/            # the OKF bundle: concept pages, index.md, log.md
    index.md
    log.md
```

- If `$WIKI_HOME` is unset, use `~/wikis`.
- A directory is a wiki if it has `AGENTS.md` + `wiki/` (and usually `raw/`). To discover the
  managed wikis, list `$WIKI_HOME`.
- `raw/` is immutable: never edit, rename, or write extracted text back into it.

---

## Creating a wiki

After the three questions above:

1. Create the tree. If `<name>` exists, stop and ask rather than overwriting.
2. Write `<wiki>/AGENTS.md` = the contents of `references/okf-spec.md`, prefixed with a
   preamble block, e.g.:

   ```markdown
   # <label> wiki

   - **Topic:** <one or two lines>
   - **Language:** <pl|en|...>
   - **Provenance mode:** raw-only | flexible
   - **Location:** <absolute path>

   ---
   ```

3. Seed `<wiki>/wiki/index.md` from `assets/index.md` and `<wiki>/wiki/log.md` from
   `assets/log.md`, filling in the date and an initialization entry.
4. Report the absolute path and suggest the first sources to ingest (read the folder with
   `bash`, `glob`, `grep`).

---

## Orientation before every session (do not skip)

For the wiki you are about to touch, in order:

1. Read its `AGENTS.md` — the structure spec and the per-wiki choices (mode, language).
2. Read `wiki/index.md` — what concepts exist.
3. Read the recent entries of `wiki/log.md` — what changed and what the last pass did.
4. List `raw/` (`glob`) and compare with the source coverage noted in the wiki.
5. `grep` the bundle for the topic at hand so you extend existing pages instead of duplicating
   them, and check inbound/outbound links.

Orientation prevents duplicate pages, missed cross-references, and schema violations.

---

## Operations

### Ingest — turn sources into concept pages

**Step 1 — inventory.** List `raw/` (or the paths the user gave). Decide which files are new
or changed. Note type and size.

**Step 2 — read the source completely.** Small files: read in full. Large files (multi-page
PDF, big docx/xlsx, long text): read **in fragments** — article/chapter/section for PDFs,
Heading-styled blocks for `.docx`, sheet by sheet for `.xlsx` — and distill each fragment
before moving to the next. Reading a large document in one shot truncates it; that is exactly
how material is silently lost. When you finish, the structural units you covered must equal
the units in the source; go back for any gap before calling it ingested.

Extraction helpers (only if the format needs it; prefer the tools already available):
- PDF: `python3 -c "from pypdf import PdfReader; ..."` to dump text to a temp file, then slice.
- `.docx`: `python-docx` (walk the body element so paragraphs and tables keep order).
- `.xlsx`: `openpyxl` — sheet by sheet; re-read with `data_only=False` when a value is `None`
  (an uncached formula is not an empty cell).
- Images / scans / legacy `.doc`/`.xls`/`.ppt`: unsupported without OCR — record the file as
  unreadable and tell the user; never invent its content.

Write extracted text to a temp location **outside** the wiki and `raw/`.

**Step 3 — check what exists.** `grep`/`glob` the bundle for the entities the source touches.

**Step 4 — write or update concept pages** under `wiki/`, per the spec in the wiki's
`AGENTS.md`, grouped by domain in subdirectories as makes sense. See "Writing concept pages".

**Step 5 — update navigation.** Refresh `wiki/index.md` (add entries, bump the count and
"Last updated") and append a `## <YYYY-MM-DD>` entry to `wiki/log.md` (newest first) listing
every file created or updated. Report the changes to the user.

**Batch ingest.** When several sources land together: read them all first, identify all
entities across them, check existing pages in one pass, write/update pages in one pass
(cross-linking concepts that span sources), then update `index.md` and `log.md` once.

### Query — answer from the wiki

1. Read `wiki/index.md` to find relevant pages; `grep` the bundle for key terms.
2. Read the relevant pages.
3. Answer from what is **in the wiki**, citing the pages you used
   (e.g. "Based on `wiki/concepts/foo.md` and `wiki/regulations/bar.md`").
4. In raw-only mode, if no raw source covers the answer, say so instead of filling the gap
   from web or model knowledge.
5. File substantial answers (comparisons, deep dives) back as a new concept page; skip trivial
   lookups. Log the query.

### Lint — conformance and health check

Scan the bundle with `bash`/`grep`/`glob` and report grouped by severity:

1. **Schema (highest):** `.md` files missing frontmatter or a non-empty `type`.
2. **Reserved files:** `index.md` / `log.md` follow §8/§9 and are never concepts.
3. **Broken links** (informational — OKF tolerates them): links to missing targets.
4. **Orphans** (informational): pages with no inbound links.
5. **Provenance gaps:** pages with no `sources` or no `generated`.
6. **Trust tiers:** list unverified and machine-confirmed pages needing human review.
7. **Stale:** pages where `now >= stale_after`.
8. **Contradictions:** pages sharing tags/domain but stating conflicting facts.
9. **Page size:** flag concepts over ~200 lines for splitting.
10. **Index completeness:** every concept appears in some `index.md`.
11. **Log rotation:** if `log.md` exceeds 500 entries, rotate to `log-<YYYY>.md`.

Append `## <YYYY-MM-DD> | lint | N issues found` to `wiki/log.md`.

### List wikis

List `$WIKI_HOME`; for each directory with an `AGENTS.md`, report its name, topic and language
from the preamble.

---

## Writing concept pages

Use this cheat-sheet; the authoritative definitions are in the wiki's `AGENTS.md`.

```yaml
---
type: Concept                 # REQUIRED (the only always-required key). e.g. Concept, Reference, Guide, Metric, Comparison
title: Human-readable name
description: One-line summary
resource: <canonical URI>     # optional
tags: [keyword, ...]          # optional
status: draft                 # draft | stable | deprecated
sources:                      # provenance (encouraged; required in raw-only mode)
  - id: src-1                 # stable key used by body footnotes
    resource: ../../raw/<file>  # the file the claim came from
    title: Title of the source
generated: { by: opencode/<model>, at: <ISO now> }
---
```

- **`type` is required; everything else is optional.** Populate `sources`, `generated` and
  `status` for agent-maintained trust.
- **Per-claim attribution:** use markdown footnotes whose label is the source `id`
  (`[^src-1]`), never positional indices like `sources[0]`.
- **Cross-link** to at least two other pages using bundle-relative paths (`/concepts/foo.md`),
  and check that existing pages link back.
- **Structure suits the content:** use headings that reflect the material (e.g. `# Definition`,
  `# Scope`, `# Examples`, `# Timeline`), favouring lists and tables over prose.
- **Language:** write prose and headings in the wiki's `language`; keep verbatim quotes in the
  raw source's own language — do not translate quoted authoritative text.
- **Status:** default new machine-written pages to `status: draft` until reviewed.
- Keep each page readable; split beyond ~200 lines and cross-link the pieces.

### Conflict / update policy

When new information conflicts with existing content, do not silently overwrite:

1. **Same page, newer content** — an ordinary refresh: update the page to the current state and
   keep history in `sources` and `log.md`.
2. **Contradiction** — note **both** positions with their dates and sources, so the record
   preserves the dispute, and flag it for review in the lint report. Never present one reading
   as settled when the sources disagree.

### Archiving / deprecating

Retire a concept through the `status` lifecycle field, not by deleting the file:

1. Set `status: deprecated` in frontmatter (kept for links and history).
2. Remove its entry from `index.md` (or mark it "(deprecated)" in place).
3. Update pages that linked to it.
4. Log the deprecation.

Delete a file outright only if no inbound links remain and it has no historical value.

---

## Pitfalls

- **Never modify `raw/`** — immutable; corrections go in the bundle's concept pages.
- **Ask where and how before creating a wiki** — default mounted location, current project, or
  a custom path; and raw-only vs flexible. Never assume.
- **Never skip fragment-reading for large files** — read unit by unit and verify full coverage
  before declaring a source ingested.
- **Always orient first** — spec + index + recent log + list `raw/` before any operation.
- **Always update `index.md` and `log.md`** — the navigational backbone.
- **Don't create pages for passing mentions** — 2+ mentions, or central to one source.
- **Don't create pages without cross-references** — every page links to 2+ others.
- **Footnotes key to `sources[].id`, never positional indices** — positional keys misattribute
  the moment the list is reordered.
- **Respect the wiki's `language`** — prose in it, verbatim quotes in the source's own language.
- **Respect the active wiki's spec** — its `AGENTS.md` is authoritative when unsure.
- **Never silently overwrite a contradiction** — record both positions with sources and dates.
- **In raw-only mode, do not fetch the web or use model knowledge** — if a raw source does not
  cover it, say so. This is a distillation task, not a research task.
- **Ask before mass-updating 10+ existing pages.**
