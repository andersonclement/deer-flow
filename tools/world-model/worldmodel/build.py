"""Assemble a :class:`WorldModel` from a repository, incrementally when possible."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path

from .graph import build_edges, compute_hotspots, find_cycles
from .scan import build_components, current_commit, detect_stack, iter_source_files
from .schema import Entity, Evidence, Rule, WorldModel
from .surfaces import extract_surfaces


def load_previous(path: Path) -> dict | None:
    """Load a previously generated model, if one exists and is readable."""
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def changed_files(previous: dict | None, hashes: dict[str, str]) -> list[str]:
    """Return paths whose content differs from the previous run.

    On a first run every file counts as changed, which is what makes the caller
    fall back to a full analysis.
    """
    if not previous:
        return sorted(hashes)
    old = previous.get("file_hashes") or {}
    return sorted(path for path in set(old) | set(hashes) if old.get(path) != hashes.get(path))


def _revive_inferences(previous: dict) -> tuple[list[Entity], list[Rule]]:
    """Rebuild cached entities and rules from a previous model's JSON."""

    def evidence_of(raw: dict) -> list[Evidence]:
        return [Evidence(path=item.get("path", ""), line=item.get("line")) for item in raw.get("evidence", [])]

    entities = [
        Entity(
            name=item.get("name", ""),
            description=item.get("description", ""),
            evidence=evidence_of(item),
            confidence=item.get("confidence", 0.0),
        )
        for item in previous.get("entities", [])
    ]
    rules = [
        Rule(
            statement=item.get("statement", ""),
            evidence=evidence_of(item),
            confidence=item.get("confidence", 0.0),
        )
        for item in previous.get("rules", [])
    ]
    return entities, rules


def build_model(root: Path, previous: dict | None = None) -> tuple[WorldModel, list[str]]:
    """Scan ``root`` and return the fact layer of the model plus changed paths.

    The inference layer (entities, rules) is left to :mod:`worldmodel.enrich`;
    when nothing changed, any cached inferences are carried over untouched.
    """
    root = root.resolve()
    files = iter_source_files(root)

    components, hashes = build_components(root, files)
    surfaces = extract_surfaces(root, files)
    edges = build_edges(root, files)

    model = WorldModel(
        repo=root.name,
        commit=current_commit(root),
        generated_at=datetime.now(UTC).isoformat(timespec="seconds"),
        stack=detect_stack(root, files),
        components=components,
        surfaces=surfaces,
        edges=edges,
        hotspots=compute_hotspots(edges),
        cycles=find_cycles(edges),
        file_hashes=hashes,
    )

    changed = changed_files(previous, hashes)
    if previous and not changed:
        model.entities, model.rules = _revive_inferences(previous)

    return model, changed
