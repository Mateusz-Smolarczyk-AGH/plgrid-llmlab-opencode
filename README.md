# CyfroCode — OpenCode agent setup

A shareable OpenCode configuration with two ways to run:

- **system** — plain OpenCode on your machine (lightweight: no GitNexus, no Macrodata).
- **container** — an isolated Docker container with GitNexus, Macrodata, Python/Node/Bun,
  Playwright and Crawl4AI, plus easy project mounting.

Models are served through the [PLGrid Forge](https://llmlab.plgrid.pl) provider using the
bundled `plgrid.js` plugin. No API key is stored in the config; authentication is done
once with `opencode providers login -p plgrid` (or seeded from `PLGRID_API_KEY` in the
container).

## Layout

```
opencode.json            canonical agent config (base)
AGENTS.md                workspace constitution
profiles/                thin overlays on the base
  system.json              no GitNexus, no Macrodata
  container.json           adds GitNexus MCP
.opencode/plugins/       plgrid.js provider plugin
skills/  tool/           agent skills and custom tools
docker/                  Dockerfile, entrypoint, requirements
docker-compose*.yml      container definitions
scripts/                 setup and project management
```

The deployed `opencode.json` is always `opencode.json` (base) merged with one profile —
there is a single source of truth; profiles only change what differs.

## Quick start — system (host)

```bash
scripts/setup.sh --profile system --target ~/.config/opencode
opencode providers login -p plgrid
```

## Quick start — container

```bash
cp .env.example .env      # set PLGRID_API_KEY
scripts/setup.sh --profile container --build --up
```

Enter it:

```bash
docker exec -it cyfrocode opencode
```

## Projects

Mount host folders into the container and generate the compose override:

```bash
scripts/add-project.sh /home/you/code/my-api my-api   # -> /projects/my-api
scripts/list-projects.sh
scripts/enter-project.sh my-api                        # cd + opencode
```

`add-project.sh` writes `projects.json` and regenerates `docker-compose.override.yml`
from it — the compose files themselves are never edited in place.

## SSH access (optional)

```bash
docker compose -f docker-compose.yml -f docker-compose.ssh.yml up -d
```

Requires `SSH_KEY_PATH` in `.env`.

## Agents

`architect` (plans, never edits), `editor` / `editor-cheap` (implement), `fastfix`
(mechanical edits), `reviewer` and `researcher` (read-only), `quick` (cheap primary),
`chat` (no tools).

## Notes

- `research/` holds the upstream model benchmarks and provider notes.
- The container profile enables GitNexus and Macrodata; the system profile stays minimal
  on purpose.
- The `llm-wiki` skill builds and maintains local OKF knowledge wikis under `$WIKI_HOME`
  (default `~/wikis`, mounted from `./data/wikis` in the container so they survive rebuilds).
  Before creating a wiki the agent asks for the location, the provenance mode (raw-only or
  flexible) and the language.
