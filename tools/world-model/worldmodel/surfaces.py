"""Extraction of externally reachable surfaces: HTTP routes and CLI commands.

Python is parsed with :mod:`ast` so the results are exact. TypeScript has no
parser in the standard library, so Next.js routes are derived from the file
system convention instead — which is itself exact, because the framework
resolves routes from those same paths.
"""

from __future__ import annotations

import ast
from pathlib import Path

from .scan import classify_role, component_id_for, detect_language
from .schema import Evidence, Surface

HTTP_METHODS = frozenset({"get", "post", "put", "patch", "delete", "head", "options"})


def _decorator_route(node: ast.expr) -> tuple[str, str] | None:
    """Return ``(method, path)`` if ``node`` is an HTTP route decorator."""
    if not isinstance(node, ast.Call):
        return None
    func = node.func
    if not isinstance(func, ast.Attribute) or func.attr.lower() not in HTTP_METHODS:
        return None
    # The decorated object must look like a router/app, not an arbitrary call.
    if not isinstance(func.value, (ast.Name, ast.Attribute)):
        return None
    if not node.args:
        return None
    first = node.args[0]
    if isinstance(first, ast.Constant) and isinstance(first.value, str):
        return func.attr.upper(), first.value
    return None


def _router_prefixes(tree: ast.Module) -> dict[str, str]:
    """Map router variable names to their ``prefix=`` argument.

    FastAPI splits a route between the router's prefix and the decorator path,
    so both halves are needed to reconstruct the URL a client actually calls.
    """
    prefixes: dict[str, str] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign) or not isinstance(node.value, ast.Call):
            continue
        call = node.value
        func_name = call.func.id if isinstance(call.func, ast.Name) else call.func.attr if isinstance(call.func, ast.Attribute) else ""
        if func_name not in {"APIRouter", "FastAPI"}:
            continue
        prefix = ""
        for keyword in call.keywords:
            if keyword.arg == "prefix" and isinstance(keyword.value, ast.Constant):
                prefix = str(keyword.value.value)
        for target in node.targets:
            if isinstance(target, ast.Name):
                prefixes[target.id] = prefix
    return prefixes


def extract_python_surfaces(root: Path, path: Path) -> list[Surface]:
    """Parse a Python file and return every HTTP route it declares."""
    try:
        source = path.read_text(encoding="utf-8", errors="ignore")
        tree = ast.parse(source)
    except (OSError, SyntaxError):
        return []

    rel = path.relative_to(root)
    prefixes = _router_prefixes(tree)
    surfaces: list[Surface] = []

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        for decorator in node.decorator_list:
            route = _decorator_route(decorator)
            if route is None:
                continue
            method, route_path = route
            owner = decorator.func.value  # type: ignore[union-attr]
            prefix = prefixes.get(owner.id, "") if isinstance(owner, ast.Name) else ""
            surfaces.append(
                Surface(
                    kind="http",
                    method=method,
                    path=f"{prefix}{route_path}" or "/",
                    handler=node.name,
                    component=component_id_for(rel),
                    evidence=Evidence(path=str(rel), line=node.lineno),
                )
            )
    return surfaces


def extract_nextjs_surfaces(root: Path, path: Path) -> list[Surface]:
    """Derive a Next.js App Router surface from a ``route``/``page`` file path."""
    rel = path.relative_to(root)
    parts = rel.parts
    if "app" not in parts or path.stem not in {"route", "page"}:
        return []

    segments = parts[parts.index("app") + 1 : -1]
    # Route groups like "(auth)" organise files without appearing in the URL.
    visible = [segment for segment in segments if not segment.startswith("(")]
    url = "/" + "/".join(visible)

    return [
        Surface(
            kind="http",
            method="GET" if path.stem == "page" else None,
            path=url,
            handler=path.stem,
            component=component_id_for(rel),
            evidence=Evidence(path=str(rel), line=1),
        )
    ]


def extract_surfaces(root: Path, files: list[Path]) -> list[Surface]:
    """Collect every surface across the repository, deduplicated and sorted.

    Test files are skipped: a fixture that spins up a throwaway FastAPI app
    declares routes, but nothing outside the test depends on them, so counting
    them would overstate the system's real contract.
    """
    surfaces: list[Surface] = []
    for path in files:
        rel = path.relative_to(root)
        language = detect_language(path)
        if language is None or classify_role(rel, language) == "test":
            continue
        if path.suffix == ".py":
            surfaces.extend(extract_python_surfaces(root, path))
        elif path.suffix in {".ts", ".tsx"}:
            surfaces.extend(extract_nextjs_surfaces(root, path))

    seen: set[tuple[str | None, str, str]] = set()
    unique: list[Surface] = []
    for surface in surfaces:
        key = (surface.method, surface.path, str(surface.evidence))
        if key not in seen:
            seen.add(key)
            unique.append(surface)

    unique.sort(key=lambda surface: (surface.path, surface.method or ""))
    return unique
