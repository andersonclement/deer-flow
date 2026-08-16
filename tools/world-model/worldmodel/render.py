"""Render a :class:`WorldModel` as Markdown for humans and agents alike.

The output is deliberately compact: an agent should be able to read the whole
file into context and understand the system without opening 50,000 source
files, which is the entire point of keeping this model.
"""

from __future__ import annotations

from .schema import WorldModel

MAX_COMPONENTS = 40
MAX_SURFACES = 60
MAX_EDGES = 30


def _table(headers: list[str], rows: list[list[str]]) -> list[str]:
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    lines.extend("| " + " | ".join(row) + " |" for row in rows)
    return lines


def render_markdown(model: WorldModel) -> str:
    """Produce the human-readable view of the model."""
    out: list[str] = [
        f"# World Model — {model.repo}",
        "",
        f"- **Commit**: `{model.commit or 'unknown'}`",
        f"- **Generated**: {model.generated_at}",
        f"- **Schema**: v{model.schema_version}",
        "",
        "> Facts below (stack, components, surfaces, graph) are extracted deterministically from source. Entities and rules are model-inferred and carry a confidence score — verify them against the cited evidence.",
        "",
        "## Stack",
        "",
    ]

    languages = ", ".join(f"{name} ({count})" for name, count in model.stack.languages.items())
    out.append(f"- **Languages**: {languages or 'none detected'}")
    out.append(f"- **Frameworks**: {', '.join(model.stack.frameworks) or 'none detected'}")
    out.append(f"- **Package managers**: {', '.join(model.stack.package_managers) or 'none'}")
    out.append("")

    out.append(f"## Components ({len(model.components)})")
    out.append("")
    ranked = sorted(model.components, key=lambda component: -component.loc)
    out.extend(
        _table(
            ["Component", "Role", "Lang", "Files", "LOC"],
            [[f"`{c.id}`", c.role, c.language, str(c.files), str(c.loc)] for c in ranked[:MAX_COMPONENTS]],
        )
    )
    if len(ranked) > MAX_COMPONENTS:
        out.append("")
        out.append(f"_…and {len(ranked) - MAX_COMPONENTS} smaller components._")
    out.append("")

    out.append(f"## Surfaces ({len(model.surfaces)})")
    out.append("")
    if model.surfaces:
        out.extend(
            _table(
                ["Method", "Path", "Handler", "Source"],
                [[s.method or "—", f"`{s.path}`", f"`{s.handler}`", f"`{s.evidence}`"] for s in model.surfaces[:MAX_SURFACES]],
            )
        )
        if len(model.surfaces) > MAX_SURFACES:
            out.append("")
            out.append(f"_…and {len(model.surfaces) - MAX_SURFACES} more surfaces._")
    else:
        out.append("_No HTTP surfaces detected._")
    out.append("")

    out.append("## Blast radius")
    out.append("")
    out.append("How many components transitively depend on each one. A change to a high-radius component needs justification, not just correctness.")
    out.append("")
    if model.hotspots:
        out.extend(
            _table(
                ["Component", "Blast radius", "Fan-in", "Fan-out"],
                [[f"`{h.component}`", str(h.blast_radius), str(h.fan_in), str(h.fan_out)] for h in model.hotspots],
            )
        )
    else:
        out.append("_No dependencies resolved._")
    out.append("")

    out.append(f"## Dependencies ({len(model.edges)} edges)")
    out.append("")
    if model.edges:
        out.extend(
            _table(
                ["From", "To", "Imports"],
                [[f"`{e.src}`", f"`{e.dst}`", str(e.weight)] for e in model.edges[:MAX_EDGES]],
            )
        )
        if len(model.edges) > MAX_EDGES:
            out.append("")
            out.append(f"_…and {len(model.edges) - MAX_EDGES} weaker edges._")
    else:
        out.append("_No edges resolved._")
    out.append("")

    if model.cycles:
        out.append(f"## Dependency cycles ({len(model.cycles)})")
        out.append("")
        out.append("Cycles make change propagation unpredictable — treat them as risk.")
        out.append("")
        out.extend(f"- {' → '.join(f'`{node}`' for node in cycle)}" for cycle in model.cycles)
        out.append("")

    out.append(f"## Domain entities ({len(model.entities)})")
    out.append("")
    if model.entities:
        for entity in model.entities:
            citations = ", ".join(f"`{item}`" for item in entity.evidence) or "_no evidence_"
            out.append(f"### {entity.name}")
            out.append("")
            out.append(entity.description)
            out.append("")
            out.append(f"- Confidence: {entity.confidence:.2f}")
            out.append(f"- Evidence: {citations}")
            out.append("")
    else:
        out.append("_Not yet inferred — run with enrichment enabled._")
        out.append("")

    out.append(f"## Business rules ({len(model.rules)})")
    out.append("")
    if model.rules:
        for rule in model.rules:
            citations = ", ".join(f"`{item}`" for item in rule.evidence) or "_no evidence_"
            out.append(f"- **{rule.statement}** _(confidence {rule.confidence:.2f})_ — {citations}")
        out.append("")
    else:
        out.append("_Not yet inferred — run with enrichment enabled._")
        out.append("")

    return "\n".join(out)
