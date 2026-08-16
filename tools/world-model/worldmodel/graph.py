"""Dependency graph between components, and the blast radius it implies.

The graph answers the question a senior engineer asks before touching anything:
*if I change this, what else can break?* ``blast_radius`` makes that concrete by
counting transitive dependents, which is the signal an agent needs to argue
against a change rather than blindly applying it.

Edges are only recorded when an import resolves unambiguously to exactly one
file. An ambiguous import is dropped rather than guessed — a missing edge is a
known gap, while an invented one silently corrupts every decision downstream.
"""

from __future__ import annotations

import ast
import re
from collections import defaultdict, deque
from pathlib import Path

from .scan import component_id_for
from .schema import Edge, Hotspot

TS_IMPORT_RE = re.compile(
    r"""(?:^|\n)\s*(?:import|export)\s+(?:[^'"]*?\sfrom\s+)?['"](?P<target>[^'"]+)['"]""",
)


def _module_keys(rel_path: Path) -> list[str]:
    """Every dotted suffix a Python file could be imported as, longest first."""
    parts = list(rel_path.with_suffix("").parts)
    if parts and parts[-1] == "__init__":
        parts.pop()
    if not parts:
        return []
    return [".".join(parts[index:]) for index in range(len(parts))]


def build_python_index(root: Path, files: list[Path]) -> dict[str, list[Path]]:
    """Index Python files by the dotted module paths that can address them."""
    index: dict[str, list[Path]] = defaultdict(list)
    for path in files:
        if path.suffix != ".py":
            continue
        for key in _module_keys(path.relative_to(root)):
            index[key].append(path)
    return index


def _resolve(index: dict[str, list[Path]], module: str) -> Path | None:
    """Resolve a dotted module name to a single file, or ``None`` if unclear."""
    while module:
        matches = index.get(module)
        if matches and len(matches) == 1:
            return matches[0]
        if matches and len(matches) > 1:
            return None
        module = module.rpartition(".")[0]
    return None


def _python_imports(path: Path) -> list[str]:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8", errors="ignore"))
    except (OSError, SyntaxError):
        return []

    modules: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            # Relative imports are resolved by the caller against the file's own
            # package, so only absolute ones are returned here.
            if node.level == 0 and node.module:
                modules.append(node.module)
    return modules


def _relative_targets(path: Path, root: Path) -> list[Path]:
    """Resolve TypeScript relative imports to files on disk."""
    try:
        source = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []

    resolved: list[Path] = []
    for match in TS_IMPORT_RE.finditer(source):
        target = match.group("target")
        if not target.startswith("."):
            continue
        base = (path.parent / target).resolve()
        for candidate in (
            base,
            *(base.with_suffix(suffix) for suffix in (".ts", ".tsx", ".js", ".jsx")),
            *(base / f"index{suffix}" for suffix in (".ts", ".tsx", ".js", ".jsx")),
        ):
            if candidate.is_file() and root in candidate.parents:
                resolved.append(candidate)
                break
    return resolved


def build_edges(root: Path, files: list[Path]) -> list[Edge]:
    """Build the weighted component dependency graph."""
    index = build_python_index(root, files)
    weights: dict[tuple[str, str], int] = defaultdict(int)

    for path in files:
        rel = path.relative_to(root)
        src = component_id_for(rel)

        targets: list[Path] = []
        if path.suffix == ".py":
            for module in _python_imports(path):
                target = _resolve(index, module)
                if target is not None:
                    targets.append(target)
        elif path.suffix in {".ts", ".tsx", ".js", ".jsx"}:
            targets.extend(_relative_targets(path, root))

        for target in targets:
            dst = component_id_for(target.relative_to(root))
            if dst != src:
                weights[(src, dst)] += 1

    edges = [Edge(src=src, dst=dst, weight=weight) for (src, dst), weight in weights.items()]
    edges.sort(key=lambda edge: (-edge.weight, edge.src, edge.dst))
    return edges


def compute_hotspots(edges: list[Edge], limit: int = 20) -> list[Hotspot]:
    """Rank components by how much of the system transitively depends on them."""
    dependents: dict[str, set[str]] = defaultdict(set)
    fan_in: dict[str, int] = defaultdict(int)
    fan_out: dict[str, int] = defaultdict(int)

    for edge in edges:
        dependents[edge.dst].add(edge.src)
        fan_in[edge.dst] += 1
        fan_out[edge.src] += 1

    hotspots: list[Hotspot] = []
    for component in set(fan_in) | set(fan_out):
        # Breadth-first walk over "who depends on me", counting each component
        # once however many paths reach it.
        seen: set[str] = set()
        queue = deque(dependents.get(component, ()))
        while queue:
            current = queue.popleft()
            if current in seen or current == component:
                continue
            seen.add(current)
            queue.extend(dependents.get(current, ()))

        hotspots.append(
            Hotspot(
                component=component,
                fan_in=fan_in.get(component, 0),
                fan_out=fan_out.get(component, 0),
                blast_radius=len(seen),
            )
        )

    hotspots.sort(key=lambda hotspot: (-hotspot.blast_radius, -hotspot.fan_in, hotspot.component))
    return hotspots[:limit]


def find_cycles(edges: list[Edge], limit: int = 10) -> list[list[str]]:
    """Find dependency cycles between components.

    Cycles are reported because they are the structural reason a "small" change
    propagates somewhere unrelated — exactly the surprise an agent should warn
    about before editing.
    """
    adjacency: dict[str, set[str]] = defaultdict(set)
    for edge in edges:
        adjacency[edge.src].add(edge.dst)

    cycles: list[list[str]] = []
    seen_signatures: set[frozenset[str]] = set()
    visiting: set[str] = set()
    done: set[str] = set()

    def walk(node: str, stack: list[str]) -> None:
        if len(cycles) >= limit:
            return
        visiting.add(node)
        stack.append(node)
        for neighbour in sorted(adjacency.get(node, ())):
            if neighbour in visiting:
                cycle = stack[stack.index(neighbour) :]
                signature = frozenset(cycle)
                if len(cycle) > 1 and signature not in seen_signatures:
                    seen_signatures.add(signature)
                    cycles.append([*cycle, neighbour])
            elif neighbour not in done:
                walk(neighbour, stack)
        stack.pop()
        visiting.discard(node)
        done.add(node)

    for node in sorted(adjacency):
        if node not in done:
            walk(node, [])
    return cycles[:limit]
