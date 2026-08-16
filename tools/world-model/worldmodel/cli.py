"""Command line entry point for building and inspecting a world model."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .build import build_model, load_previous
from .render import render_markdown

DEFAULT_OUT = Path(".worldmodel")
JSON_NAME = "world-model.json"
MARKDOWN_NAME = "WORLD_MODEL.md"


def _build(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2

    out_dir = Path(args.out) if args.out else root / DEFAULT_OUT
    json_path = out_dir / JSON_NAME

    previous = load_previous(json_path)
    model, changed = build_model(root, previous)

    if args.enrich:
        # Imported lazily: enrichment needs network and an API key, and the
        # fact layer must stay usable without either.
        from .enrich import enrich_model

        enrich_model(root, model, changed, model_name=args.model, timeout=args.timeout)

    out_dir.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(model.to_dict(), indent=2, sort_keys=False), encoding="utf-8")
    (out_dir / MARKDOWN_NAME).write_text(render_markdown(model), encoding="utf-8")

    print(f"components   {len(model.components)}")
    print(f"surfaces     {len(model.surfaces)}")
    print(f"edges        {len(model.edges)}")
    print(f"cycles       {len(model.cycles)}")
    print(f"entities     {len(model.entities)}")
    print(f"rules        {len(model.rules)}")
    print(f"changed      {len(changed)} file(s) since last run")
    print(f"written      {json_path}")
    print(f"             {out_dir / MARKDOWN_NAME}")
    return 0


def _impact(args: argparse.Namespace) -> int:
    """Report what depends on a component — the "can I change this?" query."""
    root = Path(args.root).resolve()
    json_path = (Path(args.out) if args.out else root / DEFAULT_OUT) / JSON_NAME
    previous = load_previous(json_path)
    if previous is None:
        print(f"error: no model at {json_path}; run `build` first", file=sys.stderr)
        return 2

    target = args.component
    edges = previous.get("edges", [])
    direct = sorted({edge["src"] for edge in edges if edge["dst"] == target})
    depends_on = sorted({edge["dst"] for edge in edges if edge["src"] == target})

    hotspot = next(
        (item for item in previous.get("hotspots", []) if item["component"] == target),
        None,
    )

    if not direct and not depends_on and hotspot is None:
        print(f"unknown component: {target}", file=sys.stderr)
        return 1

    radius = hotspot["blast_radius"] if hotspot else 0
    print(f"component     {target}")
    print(f"blast radius  {radius} component(s) transitively affected")
    print(f"direct users  {len(direct)}")
    for name in direct:
        print(f"  ← {name}")
    print(f"depends on    {len(depends_on)}")
    for name in depends_on:
        print(f"  → {name}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="worldmodel", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    build = sub.add_parser("build", help="scan a repository and write the model")
    build.add_argument("--root", default=".", help="repository root (default: cwd)")
    build.add_argument("--out", default=None, help="output directory (default: <root>/.worldmodel)")
    build.add_argument("--enrich", action="store_true", help="infer entities and rules with an LLM")
    build.add_argument("--model", default=None, help="model id for enrichment")
    build.add_argument("--timeout", type=int, default=300, help="enrichment timeout in seconds")
    build.set_defaults(func=_build)

    impact = sub.add_parser("impact", help="show what depends on a component")
    impact.add_argument("component", help="component id, e.g. backend.app.gateway.routers")
    impact.add_argument("--root", default=".", help="repository root (default: cwd)")
    impact.add_argument("--out", default=None, help="output directory (default: <root>/.worldmodel)")
    impact.set_defaults(func=_impact)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
