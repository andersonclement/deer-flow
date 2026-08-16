"""Tests for the MCP server.

Protocol conformance is tested as carefully as the tool output: a server that
answers a notification, or that crashes the transport on a bad argument, breaks
the agent session in ways that are hard to diagnose from the client side.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from worldmodel.mcp import handle_message, serve, tool_impact, tool_locate, tool_overview  # noqa: E402

MODEL = {
    "repo": "demo",
    "commit": "abc123def456",
    "stack": {"languages": {"python": 10}, "frameworks": ["FastAPI"]},
    "components": [
        {"id": "backend.api", "role": "router", "language": "python", "files": 3, "loc": 120, "path": "backend/api"},
        {"id": "backend.core", "role": "service", "language": "python", "files": 5, "loc": 300, "path": "backend/core"},
    ],
    "surfaces": [
        {
            "kind": "http",
            "method": "GET",
            "path": "/api/users",
            "handler": "list_users",
            "component": "backend.api",
            "evidence": {"path": "backend/api/users.py", "line": 12},
        }
    ],
    "edges": [{"src": "backend.api", "dst": "backend.core", "weight": 4}],
    "hotspots": [{"component": "backend.core", "fan_in": 1, "fan_out": 0, "blast_radius": 1}],
    "cycles": [],
    "entities": [
        {
            "name": "User",
            "description": "A person using the system.",
            "evidence": [{"path": "backend/api/users.py", "line": None}],
            "confidence": 0.9,
        }
    ],
    "rules": [],
    "file_hashes": {},
}


@pytest.fixture
def model_path(tmp_path: Path) -> Path:
    path = tmp_path / "world-model.json"
    path.write_text(json.dumps(MODEL), encoding="utf-8")
    return path


def test_initialize_reports_tools_capability(model_path: Path) -> None:
    response = handle_message({"jsonrpc": "2.0", "id": 1, "method": "initialize"}, model_path)

    assert response is not None
    assert response["result"]["capabilities"] == {"tools": {}}
    assert response["result"]["serverInfo"]["name"] == "world-model"


def test_notifications_get_no_response(model_path: Path) -> None:
    # A notification has no id. Replying to one violates JSON-RPC and some
    # clients treat the stray response as a fatal protocol error.
    assert handle_message({"jsonrpc": "2.0", "method": "notifications/initialized"}, model_path) is None


def test_tools_list_exposes_three_tools(model_path: Path) -> None:
    response = handle_message({"jsonrpc": "2.0", "id": 2, "method": "tools/list"}, model_path)

    names = {tool["name"] for tool in response["result"]["tools"]}
    assert names == {"overview", "impact", "locate"}


def test_unknown_method_returns_error(model_path: Path) -> None:
    response = handle_message({"jsonrpc": "2.0", "id": 3, "method": "nope"}, model_path)
    assert response["error"]["code"] == -32601


def test_tool_call_returns_text_content(model_path: Path) -> None:
    response = handle_message(
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {"name": "impact", "arguments": {"component": "backend.core"}},
        },
        model_path,
    )

    text = response["result"]["content"][0]["text"]
    assert "Blast radius: 1" in text
    assert "backend.api" in text


def test_missing_argument_is_a_tool_error_not_a_crash(model_path: Path) -> None:
    response = handle_message(
        {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "impact", "arguments": {}}},
        model_path,
    )

    assert response["result"]["isError"] is True
    assert "component" in response["result"]["content"][0]["text"]


def test_missing_model_reports_actionable_error(tmp_path: Path) -> None:
    response = handle_message(
        {"jsonrpc": "2.0", "id": 6, "method": "tools/call", "params": {"name": "overview", "arguments": {}}},
        tmp_path / "absent.json",
    )

    assert response["result"]["isError"] is True
    assert "worldmodel build" in response["result"]["content"][0]["text"]


def test_unknown_component_suggests_alternatives() -> None:
    assert "backend.core" in tool_impact(MODEL, "core")


def test_high_blast_radius_is_flagged_as_risky() -> None:
    model = {
        **MODEL,
        "hotspots": [{"component": "backend.core", "fan_in": 12, "fan_out": 0, "blast_radius": 30}],
    }
    assert "HIGH RISK" in tool_impact(model, "backend.core")


def test_locate_matches_components_surfaces_and_entities() -> None:
    result = tool_locate(MODEL, "users")

    assert "/api/users" in result
    assert "backend/api/users.py:12" in result
    assert "User" in result


def test_locate_reports_no_match_clearly() -> None:
    assert "No component" in tool_locate(MODEL, "nonexistent-thing")


def test_overview_includes_map_sections() -> None:
    overview = tool_overview(MODEL)

    assert "backend.api | router" in overview
    assert "GET /api/users" in overview
    assert "blast radius 1" in overview


def test_serve_handles_a_stream_and_skips_blank_lines(model_path: Path) -> None:
    stdin = io.StringIO('{"jsonrpc":"2.0","id":1,"method":"initialize"}\n\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n')
    stdout = io.StringIO()

    serve(model_path, stdin=stdin, stdout=stdout)

    responses = [json.loads(line) for line in stdout.getvalue().splitlines() if line.strip()]
    assert [item["id"] for item in responses] == [1, 2]


def test_malformed_json_returns_parse_error(model_path: Path) -> None:
    stdout = io.StringIO()
    serve(model_path, stdin=io.StringIO("not json\n"), stdout=stdout)

    assert json.loads(stdout.getvalue())["error"]["code"] == -32700
