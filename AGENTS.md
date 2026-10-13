# GLOBAL WORKSPACE CONSTITUTION

These rules apply to ALL agents operating in this workspace.

## 1. Identity & Working Agreement

**Before changing code:**
- Read the files you are about to change. Never edit from memory of a filename.
- If the request is ambiguous in a way that changes the output, ask one question, then proceed.
- Do not add a dependency without saying so first.

**While writing:**
- Match the surrounding code — its naming, comment density and idioms. A patch should be invisible in review except for the behaviour change.
- Return new values rather than mutating arguments in place.
- Handle every error explicitly. Never swallow an exception.
- Validate anything arriving from a user, a file, or an API.
- Never hardcode a secret.
- Extract rather than let a file grow past ~400 lines.

**Verifying:**
- Run the code. Report the real output, including failures.
- If you did not verify something, say so.
- Delegate implementation with the task tool when a subagent fits the work better; state what you delegated and what came back.

**Tool calls:**
- Inspect real files with your tools instead of guessing at contents.
- Put only the parameter value inside a tool call — never reasoning or commentary. Think first, then emit a clean call.

**Never:**
- Commit or push unless asked.
- Reformat files you were not asked to touch.
- Modify a test to make it pass. If a test looks wrong, say so and stop.
- Describe work as complete while part of it is unfinished — name what is left.

## 2. Agent Roster & Delegation

**Available agents:**
- `architect` — Primary planner. Cannot edit files, always delegates. Use for complex planning and orchestration.
- `chat` — No tools, for models without function calling.
- `researcher` — Read-only code tracing. Use to understand how code works with file:line citations.
- `reviewer` — Read-only defect review. Use to verify code correctness and security.
- `fastfix` — Small mechanical edits (rename, docstring, obvious bug fix).
- `editor` — Substantial code implementation. Writes and edits files, runs tests/type checks, reports real output. Can pull in `@researcher` and `@reviewer` itself.
- `editor-cheap` — Implements routine code changes from a concrete plan step, at ~1/3 the output cost of @editor. Use for routine work; escalate to @editor when the task is hard or spans many files.
- `quick` —  Small primary for cheap, fast tasks.
**Workflow:**
1. `architect` plans → breaks into numbered steps naming files
2. Delegate to `@editor` (substantial changes) or `@fastfix` (small mechanical edits)
3. `@reviewer` verifies the result

**STOP RULE:** Before acting, review available subagents and delegate when a specialist fits. Do not do work yourself that matches another agent's description.

**Domain playbooks:** For implementation in a specific domain (backend/API, frontend/UI, data and AI/ML, infrastructure/DevOps, security, QA and testing, refactoring, HPC/MLOps), load the `cyfrocode-specialists` skill and read the matching `references/<cluster>/<name>.md` file before writing code. `editor` does this by default; `architect` should name the relevant playbook in each plan step.

## 3. Core Tool: GitNexus

GitNexus provides a deep relational knowledge graph of the codebase.

**Mandatory usage:**
- `gitnexus_query` — Find execution flows related to a concept
- `gitnexus_context` — 360-degree view of a symbol (callers, callees, imports, extends)
- `gitnexus_impact` — Analyze blast radius BEFORE changing any symbol

**CLI fallback (if MCP fails or times out):**
```bash
gitnexus query "search terms"
gitnexus context <symbol_name>
gitnexus impact <symbol_name> --direction upstream
gitnexus rename <old_name> <new_name>
```

**Index maintenance:** After any significant change, re-run:
```bash
gitnexus analyze . --embeddings --skills
```

**Pre-commit validation:** Before committing, always run:
```bash
gitnexus detect_changes
```

## 4. Core Tool: Macrodata (Persistent Memory)

Macrodata provides persistent memory across sessions.

**Recall BEFORE asking:**
- `macrodata_search_memory` — Search retained facts
- `macrodata_search_conversations` — Search today's conversations

**Journal after significant work:**
- `macrodata_log_journal` — Record accomplishments, decisions, technical facts

**Workspace state:**
- Keep `~/.config/macrodata/state/workspace.md` current with active projects/tasks
- Keep `~/.config/macrodata/state/today.md` current with immediate objectives


## 5. Web & Research Tools

**context7:** Library/framework documentation lookup. Works unauthenticated; add auth header for higher rate limits.

**gitingest:** Code ingestion and analysis. Use to analyze external repositories.

**crwl (Crawl4AI) — MANDATORY PIPELINE:**
For web scraping, documentation reading, or structured data extraction:
1. Fetch to temp file: `crwl crawl <URL> -o markdown -O /tmp/crwl-test/<name>.md`
   (`-o` selects the OUTPUT FORMAT, `-O` the output FILE — `-o <filename>` is wrong)
2. Read the file: `cat /tmp/crwl-test/<name>.md`
3. Analyze and implement
4. Delete immediately: `rm -f /tmp/crwl-test/<name>.md && rmdir /tmp/crwl-test`

Important before first use in a fresh container:
- Run `playwright install chromium` if the crawl fails with "Executable doesn't exist at ~/.cache/ms-playwright/...".
- Do NOT write temp files to `/tmp/opencode` — it is root-owned (not writable by uid 1000). Use `/tmp/crwl-test/`.
- Use `markdown`, `md-fit`, or `all` output formats. `-o json` is broken in this build (fails with "JSON object must be str, bytes or bytearray, not NoneType"); use `-o all` for full JSON metadata instead.
- This workspace's permission rules deny `rm -rf *`; delete with `rm -f <files>` then `rmdir <dir>`.

Use crwl proactively via bash. It handles JavaScript rendering, anti-bots, and infinite scroll automatically.

**paper-search:** Academic literature search. Downloads papers from 20+ sources (arXiv, PubMed, Semantic Scholar).

## 6. Code Standards & Language

**No comments in code files:**
- Write self-documenting code
- No explanatory comments inside implementation files
- Only minimal JSDoc/Docstrings for public APIs
- No TODO notes or unnecessary whitespace

**Language:**
- Answer in English
- Understand both English and Polish
- Keep responses concise, professional

**Communication style:**
- Concise and direct
- No verbose explanations unless requested
- No emojis

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **plgrid-llmlab-opencode** (1252 symbols, 1333 relationships, 3 execution flows).

> Index stale? Run `node .gitnexus/run.cjs analyze --index-only` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? Bootstrap with `npx`, `bunx`, or `pnpm dlx` — e.g. `bunx gitnexus@latest analyze` (npm 11 npx crash; #1939).

## Always Do

- **MUST run impact before editing.** Use `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`; report callers, processes, and risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing.** Use `detect_changes({scope: "all"})` (MCP) or `node .gitnexus/run.cjs detect-changes --scope all --repo .` (CLI fallback). `partial: true` or `truncated: true` is not a clean check — a zero means unseen, not unaffected; re-run it. For regression review: `detect_changes({scope: "compare", base_ref: "main"})` or `node .gitnexus/run.cjs detect-changes --scope compare --base-ref "main" --repo .`.
- MUST warn on HIGH/CRITICAL `risk` pre-edit; never use `riskSharedAxes` to waive a HIGH/CRITICAL `risk` warning. Compare File/symbol: MCP File omits axes; Graph-RAG expands File.
- **MUST treat `risk: UNKNOWN` as unresolved, not as low.** An empty caller set is not evidence the symbol is unused — it can also mean the callers are not resolvable by the index (plain-object property access, dynamic dispatch, cross-language calls). `impact` pairs `UNKNOWN` with a `riskNote` saying so. Confirm with a text search before treating the symbol as safe to change or delete; do not proceed on the strength of a zero.
- **MUST use `query({search_query: "concept"})` for concepts/flows, `context({name: "symbolName"})` for a named symbol, or `impact` for blast radius, on read-only callers, dependencies, imports, or execution flow.** Graph first; text search only for empty/`UNKNOWN`/literals.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method before MCP/CLI impact analysis.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis, and never read `UNKNOWN` as an all-clear — it means the walk could not answer, which is the one verdict that requires confirming by other means.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit before MCP/CLI graph change analysis.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/plgrid-llmlab-opencode/context` | Codebase overview, check index freshness |
| `gitnexus://repo/plgrid-llmlab-opencode/clusters` | All functional areas |
| `gitnexus://repo/plgrid-llmlab-opencode/processes` | All execution flows |
| `gitnexus://repo/plgrid-llmlab-opencode/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
| --- | --- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
