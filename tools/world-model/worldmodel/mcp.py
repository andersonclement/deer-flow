"""MCP server exposing the world model to coding agents.

Speaks JSON-RPC 2.0 over stdio (newline-delimited), which is what MCP clients
such as opencode and Claude Code expect from a local server.

The point of this server is to change how an agent starts a task. Instead of
globbing and grepping to rediscover the architecture every session, it asks for
the map — and, before editing anything, asks what depends on the thing it is
about to touch.

The server only reads a model built earlier; it never scans the tree itself, so
answers are instant and identical across agents.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from .build import load_previous

PROTOCOL_VERSION = "2024-11-05"
SERVER_NAME = "world-model"
SERVER_VERSION = "1.0"

MAX_LOCATE_HITS = 20

TOOLS: list[dict[str, Any]] = [
    {
        "name": "overview",
        "description": (
            "Get the architectural map of the repository: stack, components and "
            "their roles, the HTTP surfaces it exposes, and the most "
            "depended-upon components. Call this FIRST when starting work on an "
            "unfamiliar area, instead of globbing the file tree."
        ),
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "impact",
        "description": (
            "Report what depends on a component: its blast radius (how many "
            "components are transitively affected), its direct dependents, and "
            "what it depends on. Call this BEFORE editing a component to judge "
            "whether a change is safe or needs justification."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "component": {
                    "type": "string",
                    "description": "Component id, e.g. 'backend.app.gateway.routers'.",
                }
            },
            "required": ["component"],
            "additionalProperties": False,
        },
    },
    {
        "name": "locate",
        "description": ("Find which components and HTTP surfaces match a term, with the source files that prove it. Use this to answer 'where is X handled' without grepping the repository."),
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string", "description": "Search term, e.g. 'auth' or 'skills'."}},
            "required": ["query"],
            "additionalProperties": False,
        },
    },
]


class ModelUnavailableError(RuntimeError):
    """Raised when no world model has been built yet."""


def _load(model_path: Path) -> dict:
    model = load_previous(model_path)
    if model is None:
        raise ModelUnavailableError(f"No world model at {model_path}. Run `python -m worldmodel build` first.")
    return model


def tool_overview(model: dict) -> str:
    """Render the compact map an agent should read before touching anything."""
    stack = model.get("stack", {})
    languages = ", ".join(f"{name} ({count})" for name, count in stack.get("languages", {}).items())

    lines = [
        f"# {model.get('repo', 'repository')} @ {(model.get('commit') or 'unknown')[:8]}",
        "",
        f"Languages: {languages or 'unknown'}",
        f"Frameworks: {', '.join(stack.get('frameworks', [])) or 'unknown'}",
        "",
        "## Components (id | role | files)",
    ]

    components = sorted(model.get("components", []), key=lambda item: -item.get("loc", 0))
    lines.extend(f"{item['id']} | {item['role']} | {item['files']}" for item in components[:40])

    surfaces = model.get("surfaces", [])
    lines.append("")
    lines.append(f"## HTTP surfaces ({len(surfaces)} total, first 40)")
    lines.extend(f"{item.get('method') or '-'} {item['path']}  ← {item['evidence']['path']}" for item in surfaces[:40])

    hotspots = model.get("hotspots", [])
    lines.append("")
    lines.append("## Most depended-upon (change these carefully)")
    lines.extend(f"{item['component']} | blast radius {item['blast_radius']} | fan-in {item['fan_in']}" for item in hotspots[:12])

    cycles = model.get("cycles", [])
    if cycles:
        lines.append("")
        lines.append(f"## Dependency cycles ({len(cycles)})")
        lines.extend(" → ".join(cycle) for cycle in cycles[:5])

    entities = model.get("entities", [])
    if entities:
        lines.append("")
        lines.append("## Domain entities (inferred — verify against evidence)")
        lines.extend(f"{item['name']}: {item['description']}" for item in entities)

    return "\n".join(lines)


def tool_impact(model: dict, component: str) -> str:
    """Answer "what breaks if I change this?" from the dependency graph."""
    edges = model.get("edges", [])
    known = {edge["src"] for edge in edges} | {edge["dst"] for edge in edges}

    if component not in known:
        suggestions = sorted(name for name in known if component.lower() in name.lower())[:8]
        hint = f" Did you mean: {', '.join(suggestions)}?" if suggestions else ""
        return f"Unknown component '{component}'.{hint}"

    dependents = sorted({edge["src"] for edge in edges if edge["dst"] == component})
    dependencies = sorted({edge["dst"] for edge in edges if edge["src"] == component})
    hotspot = next(
        (item for item in model.get("hotspots", []) if item["component"] == component),
        None,
    )
    radius = hotspot["blast_radius"] if hotspot else 0

    verdict = "HIGH RISK — a breaking change here propagates widely; prefer an additive change." if radius >= 10 else "MODERATE — check the direct dependents below." if radius >= 3 else "LOW — contained blast radius."

    lines = [
        f"Component: {component}",
        f"Blast radius: {radius} component(s) transitively affected",
        f"Assessment: {verdict}",
        "",
        f"Direct dependents ({len(dependents)}):",
    ]
    lines.extend(f"  ← {name}" for name in dependents)
    lines.append("")
    lines.append(f"Depends on ({len(dependencies)}):")
    lines.extend(f"  → {name}" for name in dependencies)
    return "\n".join(lines)


#: Below this length, a name is too generic for the reverse match to be useful
#: ("id" would match almost any query).
MIN_REVERSE_MATCH = 3


def _entity_matches(entity: dict, needle: str) -> bool:
    """Match an entity against a search term, tolerating singular/plural drift.

    An agent asking about "users" should find the ``User`` entity, so the name
    is matched in both directions — the query may contain the name just as
    often as the name contains the query.
    """
    name = entity.get("name", "").lower()
    if needle in name or needle in entity.get("description", "").lower():
        return True
    return len(name) >= MIN_REVERSE_MATCH and name in needle


def tool_locate(model: dict, query: str) -> str:
    """Point an agent at the right component and files for a term."""
    needle = query.strip().lower()
    if not needle:
        return "Empty query."

    components = [item for item in model.get("components", []) if needle in item["id"].lower()]
    surfaces = [item for item in model.get("surfaces", []) if needle in item["path"].lower() or needle in item["handler"].lower() or needle in item["evidence"]["path"].lower()]
    entities = [item for item in model.get("entities", []) if _entity_matches(item, needle)]

    if not components and not surfaces and not entities:
        return f"No component, surface or entity matches '{query}'."

    lines: list[str] = []
    if components:
        lines.append(f"## Components ({len(components)})")
        lines.extend(f"{item['id']} | {item['role']} | {item['files']} files | {item['path']}" for item in components[:MAX_LOCATE_HITS])
        lines.append("")
    if surfaces:
        lines.append(f"## Surfaces ({len(surfaces)})")
        lines.extend(f"{item.get('method') or '-'} {item['path']} → {item['handler']} ({item['evidence']['path']}:{item['evidence']['line']})" for item in surfaces[:MAX_LOCATE_HITS])
        lines.append("")
    if entities:
        lines.append(f"## Entities ({len(entities)})")
        lines.extend(f"{item['name']}: {item['description']} [{', '.join(evidence['path'] for evidence in item['evidence'])}]" for item in entities)
    return "\n".join(lines).strip()


def dispatch_tool(model_path: Path, name: str, arguments: dict) -> str:
    """Run a tool by name and return its text result."""
    model = _load(model_path)
    if name == "overview":
        return tool_overview(model)
    if name == "impact":
        component = str(arguments.get("component", "")).strip()
        if not component:
            raise ValueError("impact requires a 'component' argument")
        return tool_impact(model, component)
    if name == "locate":
        query = str(arguments.get("query", ""))
        if not query.strip():
            raise ValueError("locate requires a 'query' argument")
        return tool_locate(model, query)
    raise ValueError(f"Unknown tool: {name}")


def handle_message(message: dict, model_path: Path) -> dict | None:
    """Handle one JSON-RPC message, returning a response or ``None``.

    Notifications carry no ``id`` and must not be answered — replying to one is
    a protocol violation that some clients treat as fatal.
    """
    method = message.get("method")
    message_id = message.get("id")

    if message_id is None:
        return None

    def ok(result: dict) -> dict:
        return {"jsonrpc": "2.0", "id": message_id, "result": result}

    def fail(code: int, text: str) -> dict:
        return {"jsonrpc": "2.0", "id": message_id, "error": {"code": code, "message": text}}

    if method == "initialize":
        return ok(
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            }
        )

    if method == "tools/list":
        return ok({"tools": TOOLS})

    if method == "tools/call":
        params = message.get("params") or {}
        name = params.get("name", "")
        arguments = params.get("arguments") or {}
        try:
            text = dispatch_tool(model_path, name, arguments)
        except (ModelUnavailableError, ValueError) as error:
            # Reported as a tool-level error so the agent can recover, rather
            # than as a transport error that would kill the session.
            return ok({"content": [{"type": "text", "text": str(error)}], "isError": True})
        return ok({"content": [{"type": "text", "text": text}]})

    if method == "ping":
        return ok({})

    return fail(-32601, f"Method not found: {method}")


def serve(model_path: Path, stdin=None, stdout=None) -> None:
    """Read newline-delimited JSON-RPC from ``stdin`` until it closes."""
    source = stdin or sys.stdin
    sink = stdout or sys.stdout

    for line in source:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            sink.write(json.dumps({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}) + "\n")
            sink.flush()
            continue

        response = handle_message(message, model_path)
        if response is not None:
            sink.write(json.dumps(response) + "\n")
            sink.flush()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="worldmodel.mcp", description=__doc__)
    parser.add_argument("--root", default=".", help="repository root (default: cwd)")
    parser.add_argument("--out", default=None, help="model directory (default: <root>/.worldmodel)")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    out_dir = Path(args.out) if args.out else root / ".worldmodel"
    serve(out_dir / "world-model.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
