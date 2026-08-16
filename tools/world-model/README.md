# Software World Model

A structured, persistent picture of a codebase — so an agent reasons over a map
of the system instead of re-reading the repository from scratch every session.

Running it on this repository takes ~3 seconds and produces:

```
components   126
surfaces     111
edges        193
cycles       10
```

## Why

A coding agent that reads files on demand knows what a file *says*, but not what
the system *is*: which modules exist, what they expose, and what breaks when one
of them changes. That knowledge gets rebuilt from zero on every session and is
lost the moment the context window rolls over.

This tool builds that knowledge once, stores it, and updates only what changed.

## The one rule: facts and inferences never mix

The model has two layers, and they are kept strictly apart.

**The fact layer** is extracted deterministically from source. Python routes are
parsed with `ast`, imports are resolved against a module index, and dependency
edges are only recorded when an import resolves to exactly one file. An
ambiguous import is dropped rather than guessed — a missing edge is a known gap,
while an invented one silently corrupts every decision built on top of it.

Everything in this layer is reproducible: re-run the scan and compare byte for
byte.

**The inference layer** (domain entities, business rules) is produced by an LLM,
and every claim must cite a file. Citations are checked against the set of files
that actually exist, and any claim whose evidence does not resolve is discarded
before it is written. A hallucinated path cannot survive that check — which is
verified by a test, not just asserted here.

The LLM never sees the raw tree. It sees the map the fact layer produced. That
is the entire point of having a world model.

## Blast radius

The most useful output is not the component list — it is `blast_radius`: how
many components transitively depend on a given one.

```
$ python -m worldmodel impact backend.packages.harness.deerflow.config
component     backend.packages.harness.deerflow.config
blast radius  28 component(s) transitively affected
direct users  22
  ← backend.app.gateway.routers
  ← backend.packages.harness.deerflow.agents
  ...
```

This is what lets an agent push back on a change instead of applying it blindly:
"this touches a module 28 components depend on" is an argument, and it is
derived from the import graph rather than from a model's impression of the code.

Dependency cycles are reported for the same reason — they are the structural
explanation for why a "small" change surfaces somewhere unrelated.

## Usage

```bash
cd tools/world-model

# Fact layer only — no network, no API key.
python -m worldmodel build --root /path/to/repo

# With inferred entities and rules.
export WORLDMODEL_API_KEY=...
python -m worldmodel build --root /path/to/repo --enrich

# What depends on this component?
python -m worldmodel impact backend.app.gateway.routers --root /path/to/repo
```

Output lands in `<root>/.worldmodel/`:

- `world-model.json` — the full model, for agents to consume
- `WORLD_MODEL.md` — the same content, readable

### Enrichment providers

Any OpenAI-compatible endpoint works:

| Variable | Default |
|---|---|
| `WORLDMODEL_API_BASE` | `https://integrate.api.nvidia.com/v1` |
| `WORLDMODEL_API_KEY` | falls back to `NVIDIA_API_KEY` |
| `WORLDMODEL_MODEL` | `deepseek-ai/deepseek-v4-flash-0731` |

Enrichment is optional and never fatal. If the key is missing or the call fails,
the fact layer is still written and still correct.

## Using it from an agent (MCP)

The model is exposed to coding agents over MCP, so they query the map instead of
rediscovering the architecture each session:

| Tool | Purpose |
|---|---|
| `overview` | The architectural map — call it first, instead of globbing the tree |
| `impact` | Blast radius and dependents — call it *before* editing a component |
| `locate` | Which components and surfaces match a term, with `file:line` |

Register it in `opencode.json` (or any MCP client):

```json
{
  "mcp": {
    "world-model": {
      "type": "local",
      "command": ["python3", "-m", "worldmodel.mcp", "--root", "/path/to/repo"],
      "cwd": "/path/to/repo/tools/world-model",
      "enabled": true
    }
  }
}
```

The server only reads a model built earlier — it never scans the tree — so
answers are instant and identical across agents.

### What this changes

Given a planning agent told to call `impact` before proposing a change, asking
it to alter a config loader's signature produces:

```
⚙ world-model_overview
⚙ world-model_locate {"query":"deerflow config load"}
⚙ world-model_impact {"component":"backend.packages.harness.deerflow.config"}

"The overview confirms backend.packages.harness.deerflow.config is the most
 depended-upon component (blast radius 28, fan-in 22)."
```

The agent establishes the risk from the dependency graph before reading a single
file — which is the difference between an assistant that writes code and one
that can argue about whether the change is a good idea.

## Incremental updates

Every file is content-hashed. A re-scan compares hashes and reports what
changed; when nothing has, cached inferences are reused and no API call is made.
This is what makes the model a memory rather than a report.

## Verification

The fact layer was cross-checked against this repository with an independent AST
counter: 90/90 production HTTP routes and 21/21 Next.js routes, with handler
names and line numbers confirmed by hand.

Routes declared inside test fixtures are deliberately excluded — a throwaway
FastAPI app in a test declares routes, but nothing outside that test depends on
them, so counting them would overstate the system's real contract.

```bash
python -m pytest tests/ -q
```

## Limitations

- Python imports resolve via a module-suffix index, not a real import system.
  Ambiguous names are skipped, so the graph under-reports rather than invents.
- TypeScript has no stdlib parser: only relative imports are followed, so
  path-aliased imports (`@/lib/x`) are missed. Next.js routes are read from the
  filesystem convention, which is exact.
- Components are directories at a fixed depth. That is the right altitude for
  architectural reasoning, not for file-level refactoring.
- Only FastAPI-style decorator routes are detected. CLI commands and background
  jobs are modelled in the schema but not yet extracted.
