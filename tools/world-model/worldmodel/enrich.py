"""Inference layer: derive domain entities and business rules with an LLM.

Two properties keep this layer trustworthy:

1. The model is shown the *skeleton* produced by the fact layer — components,
   surfaces, hotspots — never the raw tree. That is the point of having a world
   model: reasoning happens over a map, not over 50,000 files.
2. Every returned claim must cite evidence, and any citation that does not
   resolve to a real file is discarded before it reaches the model. A claim the
   model invented cannot survive that check, so hallucinations are dropped
   rather than persisted.

Any OpenAI-compatible endpoint works. Configure it with ``WORLDMODEL_API_BASE``,
``WORLDMODEL_API_KEY`` and ``WORLDMODEL_MODEL``.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from pathlib import Path

from .schema import Entity, Evidence, Rule, WorldModel

DEFAULT_API_BASE = "https://integrate.api.nvidia.com/v1"
DEFAULT_MODEL = "deepseek-ai/deepseek-v4-flash-0731"

MAX_COMPONENTS = 45
MAX_SURFACES = 45

SYSTEM_PROMPT = """You are a staff engineer mapping an unfamiliar codebase.

You are given a structural map of a repository: its components, the HTTP
surfaces it exposes, and which components carry the most dependents.

Infer the DOMAIN MODEL from this map:
- entities: the core concepts the product is built around (e.g. "Thread",
  "Skill"). Name them as the code names them, not with generic labels.
- rules: constraints or invariants the architecture appears to enforce.

Reply with STRICT JSON only, no prose and no markdown fence:

{
  "entities": [
    {"name": "Skill", "description": "one sentence, concrete",
     "evidence": ["backend/app/gateway/routers/skills.py"], "confidence": 0.8}
  ],
  "rules": [
    {"statement": "one sentence, falsifiable",
     "evidence": ["backend/app/gateway/routers/auth.py"], "confidence": 0.6}
  ]
}

Rules for your output:
- Every evidence entry MUST be a file path copied verbatim from the map.
  Never invent a path. If you cannot cite a real path, omit the claim.
- confidence is 0.0-1.0: how strongly the map supports the claim.
- At most 12 entities and 10 rules. Prefer few, well-evidenced claims.
"""


def _skeleton(model: WorldModel) -> str:
    """Render the fact layer as the compact map handed to the LLM."""
    lines: list[str] = [f"# Repository: {model.repo}", ""]

    languages = ", ".join(f"{name} ({count})" for name, count in model.stack.languages.items())
    lines.append(f"Languages: {languages}")
    lines.append(f"Frameworks: {', '.join(model.stack.frameworks) or 'unknown'}")
    lines.append("")

    lines.append("## Components (path | role | files)")
    ranked = sorted(model.components, key=lambda component: -component.loc)
    lines.extend(f"{component.path} | {component.role} | {component.files}" for component in ranked[:MAX_COMPONENTS])
    lines.append("")

    lines.append("## HTTP surfaces (method | path | source file)")
    lines.extend(f"{surface.method or '-'} | {surface.path} | {surface.evidence.path}" for surface in model.surfaces[:MAX_SURFACES])
    lines.append("")

    lines.append("## Most depended-upon components (blast radius)")
    lines.extend(f"{hotspot.component} | radius {hotspot.blast_radius}" for hotspot in model.hotspots[:12])
    return "\n".join(lines)


def _post_chat(prompt: str, *, api_base: str, api_key: str, model_name: str, timeout: int) -> str:
    """Call an OpenAI-compatible chat endpoint and return the message content."""
    payload = json.dumps(
        {
            "model": model_name,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.2,
            "max_tokens": 2048,
        }
    ).encode()

    request = urllib.request.Request(
        f"{api_base.rstrip('/')}/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = json.loads(response.read().decode())
    return body["choices"][0]["message"]["content"]


def _parse_json(raw: str) -> dict:
    """Extract the JSON object from a model reply, tolerating stray prose."""
    text = raw.strip()
    fenced = re.search(r"```(?:json)?\s*(.+?)```", text, re.DOTALL)
    if fenced:
        text = fenced.group(1).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Fall back to the outermost braces, which survives a trailing explanation.
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end > start:
        try:
            return json.loads(text[start : end + 1])
        except json.JSONDecodeError:
            return {}
    return {}


def _verified_evidence(raw: object, known_files: set[str], root: Path) -> list[Evidence]:
    """Keep only citations that resolve to a file that actually exists."""
    if not isinstance(raw, list):
        return []

    verified: list[Evidence] = []
    for item in raw:
        if not isinstance(item, str):
            continue
        candidate = item.split(":", 1)[0].strip().lstrip("./")
        if candidate in known_files or (root / candidate).is_file():
            verified.append(Evidence(path=candidate))
    return verified


def _clamp(value: object) -> float:
    try:
        return max(0.0, min(1.0, float(value)))  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return 0.0


def enrich_model(
    root: Path,
    model: WorldModel,
    changed: list[str],
    *,
    model_name: str | None = None,
    timeout: int = 300,
) -> None:
    """Populate ``model.entities`` and ``model.rules`` in place.

    Cached inferences are kept when nothing changed, so a re-run costs nothing.
    Failures are non-fatal: the fact layer remains valid on its own.
    """
    if model.entities and not changed:
        return

    api_key = os.environ.get("WORLDMODEL_API_KEY") or os.environ.get("NVIDIA_API_KEY", "")
    if not api_key:
        print("enrich: no API key (set WORLDMODEL_API_KEY); keeping fact layer only")
        return

    api_base = os.environ.get("WORLDMODEL_API_BASE", DEFAULT_API_BASE)
    resolved_model = model_name or os.environ.get("WORLDMODEL_MODEL", DEFAULT_MODEL)

    try:
        raw = _post_chat(
            _skeleton(model),
            api_base=api_base,
            api_key=api_key,
            model_name=resolved_model,
            timeout=timeout,
        )
    except (urllib.error.URLError, OSError, KeyError, json.JSONDecodeError) as error:
        print(f"enrich: call failed ({error}); keeping fact layer only")
        return

    parsed = _parse_json(raw)
    if not parsed:
        print("enrich: could not parse model reply; keeping fact layer only")
        return

    known_files = set(model.file_hashes)
    dropped = 0

    entities: list[Entity] = []
    for item in parsed.get("entities", [])[:12]:
        if not isinstance(item, dict) or not item.get("name"):
            continue
        evidence = _verified_evidence(item.get("evidence"), known_files, root)
        if not evidence:
            dropped += 1
            continue
        entities.append(
            Entity(
                name=str(item["name"]).strip(),
                description=str(item.get("description", "")).strip(),
                evidence=evidence,
                confidence=_clamp(item.get("confidence")),
            )
        )

    rules: list[Rule] = []
    for item in parsed.get("rules", [])[:10]:
        if not isinstance(item, dict) or not item.get("statement"):
            continue
        evidence = _verified_evidence(item.get("evidence"), known_files, root)
        if not evidence:
            dropped += 1
            continue
        rules.append(
            Rule(
                statement=str(item["statement"]).strip(),
                evidence=evidence,
                confidence=_clamp(item.get("confidence")),
            )
        )

    model.entities = entities
    model.rules = rules
    print(f"enrich: kept {len(entities)} entities, {len(rules)} rules; dropped {dropped} unevidenced")
