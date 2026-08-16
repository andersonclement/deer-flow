"""Tests for the world model generator.

The most important test here is :func:`test_fabricated_evidence_is_dropped`:
the model's safety rests on the claim that an invented file path cannot reach
the output, so that claim is tested directly rather than assumed.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from worldmodel.enrich import _parse_json, _verified_evidence  # noqa: E402
from worldmodel.graph import build_edges, compute_hotspots, find_cycles  # noqa: E402
from worldmodel.scan import build_components, component_id_for  # noqa: E402
from worldmodel.schema import Edge  # noqa: E402
from worldmodel.surfaces import extract_surfaces  # noqa: E402


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A miniature repository exercising routes, imports and a cycle."""
    (tmp_path / "backend/app/gateway/routers").mkdir(parents=True)
    (tmp_path / "backend/app/services").mkdir(parents=True)
    (tmp_path / "backend/tests").mkdir(parents=True)

    (tmp_path / "backend/app/gateway/routers/users.py").write_text(
        "from fastapi import APIRouter\n"
        "from app.services.store import load\n"
        "\n"
        'router = APIRouter(prefix="/api", tags=["users"])\n'
        "\n"
        "\n"
        '@router.get("/users")\n'
        "async def list_users():\n"
        "    return load()\n"
        "\n"
        "\n"
        '@router.post("/users/{user_id}/ban")\n'
        "async def ban_user(user_id: str):\n"
        "    return user_id\n",
        encoding="utf-8",
    )
    (tmp_path / "backend/app/services/store.py").write_text("def load():\n    return []\n", encoding="utf-8")
    (tmp_path / "backend/tests/test_api.py").write_text(
        'from fastapi import FastAPI\n\ndef test_probe():\n    app = FastAPI()\n\n    @app.get("/fixture-only")\n    async def probe():\n        return 1\n',
        encoding="utf-8",
    )
    return tmp_path


def _files(root: Path) -> list[Path]:
    return [path for path in root.rglob("*") if path.is_file()]


def test_routes_are_extracted_with_prefix_and_line(repo: Path) -> None:
    surfaces = extract_surfaces(repo, _files(repo))
    by_path = {surface.path: surface for surface in surfaces}

    assert "/api/users" in by_path
    assert by_path["/api/users"].method == "GET"
    assert by_path["/api/users"].handler == "list_users"
    assert by_path["/api/users"].evidence.line == 8

    assert by_path["/api/users/{user_id}/ban"].method == "POST"


def test_test_fixture_routes_are_excluded(repo: Path) -> None:
    paths = {surface.path for surface in extract_surfaces(repo, _files(repo))}
    assert "/fixture-only" not in paths


def test_imports_become_component_edges(repo: Path) -> None:
    edges = build_edges(repo, _files(repo))
    pairs = {(edge.src, edge.dst) for edge in edges}
    assert ("backend.app.gateway.routers", "backend.app.services") in pairs


def test_components_are_grouped_and_counted(repo: Path) -> None:
    components, hashes = build_components(repo, _files(repo))
    ids = {component.id for component in components}

    assert "backend.app.gateway.routers" in ids
    assert "backend/app/services/store.py" in hashes
    assert all(len(digest) == 16 for digest in hashes.values())


def test_component_id_skips_generic_containers() -> None:
    # "packages" and "src" organise code without naming a concept, so they must
    # not consume depth that would otherwise reach the meaningful segment.
    deep = Path("backend/packages/harness/deerflow/skills/storage.py")
    assert component_id_for(deep) == "backend.packages.harness.deerflow.skills"


def test_blast_radius_counts_transitive_dependents() -> None:
    edges = [Edge("a", "b", 1), Edge("b", "c", 1), Edge("d", "a", 1)]
    radius = {hotspot.component: hotspot.blast_radius for hotspot in compute_hotspots(edges)}

    # c is imported by b, which a imports, which d imports: three dependents.
    assert radius["c"] == 3
    assert radius["b"] == 2
    assert radius["a"] == 1


def test_cycles_are_detected() -> None:
    cycles = find_cycles([Edge("a", "b", 1), Edge("b", "a", 1)])
    assert cycles
    assert set(cycles[0]) == {"a", "b"}


def test_fabricated_evidence_is_dropped(tmp_path: Path) -> None:
    """A citation to a file that does not exist must never survive."""
    real = tmp_path / "real.py"
    real.write_text("x = 1\n", encoding="utf-8")
    known = {"real.py"}

    verified = _verified_evidence(
        ["real.py", "totally/made/up.py", "./real.py"],
        known,
        tmp_path,
    )

    assert [evidence.path for evidence in verified] == ["real.py", "real.py"]


def test_evidence_accepts_line_suffix_and_rejects_non_strings(tmp_path: Path) -> None:
    (tmp_path / "real.py").write_text("x = 1\n", encoding="utf-8")

    verified = _verified_evidence(["real.py:42", 17, None], {"real.py"}, tmp_path)

    assert [evidence.path for evidence in verified] == ["real.py"]


@pytest.mark.parametrize(
    "raw",
    [
        '{"entities": [], "rules": []}',
        '```json\n{"entities": [], "rules": []}\n```',
        'Here is the result:\n{"entities": [], "rules": []}\nHope that helps.',
    ],
)
def test_model_reply_parsing_tolerates_wrapping(raw: str) -> None:
    assert _parse_json(raw) == {"entities": [], "rules": []}


def test_unparseable_reply_returns_empty() -> None:
    assert _parse_json("no json at all") == {}
