"""Deterministic repository scan: inventory, classification and hashing.

Nothing in this module guesses. Every value it produces can be recomputed from
the source tree and compared byte-for-byte, which is what lets the rest of the
system treat these results as ground truth.
"""

from __future__ import annotations

import hashlib
import subprocess
from collections import Counter
from pathlib import Path

from .schema import Component, Role, Stack

EXCLUDED_DIRS = frozenset(
    {
        ".git",
        ".venv",
        "venv",
        "node_modules",
        "__pycache__",
        ".next",
        ".turbo",
        "dist",
        "build",
        ".pytest_cache",
        ".ruff_cache",
        ".mypy_cache",
        "coverage",
        ".idea",
        ".vscode",
    }
)

LANGUAGE_BY_SUFFIX = {
    ".py": "python",
    ".ts": "typescript",
    ".tsx": "typescript",
    ".js": "javascript",
    ".jsx": "javascript",
    ".go": "go",
    ".rs": "rust",
    ".java": "java",
    ".rb": "ruby",
    ".sh": "shell",
    ".sql": "sql",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".toml": "toml",
    ".md": "markdown",
}

# Only these carry structural meaning; docs and config are counted but do not
# drive the component graph.
CODE_LANGUAGES = frozenset({"python", "typescript", "javascript", "go", "rust", "java", "ruby"})

FRAMEWORK_MARKERS = {
    "fastapi": "FastAPI",
    "flask": "Flask",
    "django": "Django",
    "langgraph": "LangGraph",
    "langchain": "LangChain",
    "next": "Next.js",
    "react": "React",
    "vue": "Vue",
    "express": "Express",
    "pydantic": "Pydantic",
    "sqlalchemy": "SQLAlchemy",
    "pytest": "pytest",
    "vitest": "Vitest",
}

PACKAGE_MANIFESTS = {
    "pyproject.toml": "uv/pip",
    "requirements.txt": "pip",
    "package.json": "npm/pnpm",
    "pnpm-lock.yaml": "pnpm",
    "Cargo.toml": "cargo",
    "go.mod": "go modules",
}


def iter_source_files(root: Path) -> list[Path]:
    """Walk ``root`` and return every file outside the excluded directories."""
    found: list[Path] = []
    stack = [root]
    while stack:
        current = stack.pop()
        try:
            entries = list(current.iterdir())
        except (PermissionError, OSError):
            continue
        for entry in entries:
            if entry.is_symlink():
                continue
            if entry.is_dir():
                if entry.name not in EXCLUDED_DIRS:
                    stack.append(entry)
            elif entry.is_file():
                found.append(entry)
    return found


def detect_language(path: Path) -> str | None:
    return LANGUAGE_BY_SUFFIX.get(path.suffix.lower())


def hash_file(path: Path) -> str:
    """Content hash used to decide whether a file needs re-analysis."""
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(65536), b""):
                digest.update(chunk)
    except OSError:
        return ""
    return digest.hexdigest()[:16]


def count_lines(path: Path) -> int:
    try:
        with path.open("rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def classify_role(rel_path: Path, language: str) -> Role:
    """Infer a component's role from conventional path naming.

    These conventions (``routers/``, ``tests/``, ``models.py``) are near
    universal, so pattern matching here is reliable enough to stay in the fact
    layer rather than being handed to a model.
    """
    parts = [part.lower() for part in rel_path.parts]
    name = rel_path.name.lower()

    if any(part in {"tests", "test", "__tests__", "e2e"} for part in parts):
        return "test"
    if any(part in {"docs", "doc"} for part in parts) or language == "markdown":
        return "docs"
    if any(part in {"docker", "deploy", ".github", "infra", "scripts"} for part in parts):
        return "infra"
    if any(part in {"routers", "routes", "api", "endpoints", "gateway"} for part in parts):
        return "router"
    if any(part in {"models", "schema", "schemas", "entities"} for part in parts):
        return "model"
    if name in {"models.py", "schema.py", "schemas.py", "types.py"}:
        return "model"
    if any(part in {"config", "settings", "conf"} for part in parts):
        return "config"
    if name in {"main.py", "app.py", "__main__.py", "server.py", "cli.py"}:
        return "entrypoint"
    if any(part in {"components", "pages", "ui", "views", "app"} for part in parts) and language in {
        "typescript",
        "javascript",
    }:
        return "ui"
    if any(part in {"services", "service", "core", "lib", "agents", "tools"} for part in parts):
        return "service"
    return "unknown"


# Directories that organise code without naming a concept. They are kept in the
# component id but do not consume depth budget, so "backend/packages/harness/
# deerflow/skills" resolves to the meaningful "skills" rather than stopping at
# the "packages" scaffolding.
GENERIC_SEGMENTS = frozenset({"src", "packages", "app", "lib"})


def component_id_for(rel_path: Path, depth: int = 4) -> str:
    """Group a file into a component by truncating its path to ``depth``.

    Files at the repository root have no meaningful grouping, so they land in a
    synthetic ``<root>`` component rather than each becoming their own.
    """
    parts = rel_path.parts[:-1]
    if not parts:
        return "<root>"

    selected: list[str] = []
    budget = depth
    for part in parts:
        selected.append(part)
        if part not in GENERIC_SEGMENTS:
            budget -= 1
        if budget == 0:
            break
    return ".".join(selected)


def build_components(root: Path, files: list[Path]) -> tuple[list[Component], dict[str, str]]:
    """Group source files into components and hash every file.

    Returns the component list and a ``relative path -> content hash`` map used
    for incremental re-scans.
    """
    grouped: dict[str, dict] = {}
    hashes: dict[str, str] = {}

    for path in files:
        rel = path.relative_to(root)
        language = detect_language(path)
        if language is None:
            continue

        hashes[str(rel)] = hash_file(path)

        if language not in CODE_LANGUAGES:
            continue

        cid = component_id_for(rel)
        bucket = grouped.setdefault(
            cid,
            {"languages": Counter(), "roles": Counter(), "files": 0, "loc": 0, "path": cid.replace(".", "/")},
        )
        bucket["languages"][language] += 1
        bucket["roles"][classify_role(rel, language)] += 1
        bucket["files"] += 1
        bucket["loc"] += count_lines(path)

    components = [
        Component(
            id=cid,
            path=data["path"],
            # The dominant role wins; mixed directories are common and the
            # majority signal is more useful than an "unknown" fallback.
            role=data["roles"].most_common(1)[0][0],
            language=data["languages"].most_common(1)[0][0],
            files=data["files"],
            loc=data["loc"],
        )
        for cid, data in grouped.items()
    ]
    components.sort(key=lambda component: component.id)
    return components, hashes


def detect_stack(root: Path, files: list[Path]) -> Stack:
    """Detect languages by file count, plus frameworks named in manifests."""
    languages: Counter[str] = Counter()
    for path in files:
        language = detect_language(path)
        if language in CODE_LANGUAGES:
            languages[language] += 1

    frameworks: set[str] = set()
    package_managers: list[str] = []

    for manifest, manager in PACKAGE_MANIFESTS.items():
        for candidate in root.rglob(manifest):
            if any(part in EXCLUDED_DIRS for part in candidate.parts):
                continue
            if manager not in package_managers:
                package_managers.append(manager)
            try:
                text = candidate.read_text(encoding="utf-8", errors="ignore").lower()
            except OSError:
                continue
            for marker, label in FRAMEWORK_MARKERS.items():
                if marker in text:
                    frameworks.add(label)

    return Stack(
        languages=dict(languages.most_common()),
        frameworks=sorted(frameworks),
        package_managers=package_managers,
    )


def current_commit(root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() or None if result.returncode == 0 else None
