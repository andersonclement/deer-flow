"""Data model for the Software World Model.

The model separates two kinds of knowledge, and never mixes them:

* **Facts** are extracted deterministically from source (imports, routes,
  file counts). They carry an :class:`Evidence` pointer and are reproducible.
* **Inferences** are produced by a language model (domain entities, business
  rules). They are always tagged with ``confidence`` and must cite evidence,
  so a reader can verify any claim against the source.

Keeping the two apart is what makes the model safe to act on: an agent can
trust the fact layer absolutely and treat the inference layer as a hypothesis.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal

SCHEMA_VERSION = "1.0"

Role = Literal[
    "entrypoint",
    "router",
    "service",
    "model",
    "config",
    "test",
    "ui",
    "infra",
    "docs",
    "unknown",
]

SurfaceKind = Literal["http", "cli", "job", "event"]


@dataclass(frozen=True)
class Evidence:
    """A pointer back to the source that justifies a claim."""

    path: str
    line: int | None = None

    def __str__(self) -> str:
        return f"{self.path}:{self.line}" if self.line else self.path


@dataclass
class Component:
    """A cohesive unit of the system — roughly a package or module directory."""

    id: str
    path: str
    role: Role
    language: str
    files: int
    loc: int


@dataclass
class Surface:
    """An externally reachable entry point: an HTTP route, CLI command, or job.

    Surfaces matter more than files: they are the contract the outside world
    depends on, so changing one has consequences a file rename does not.
    """

    kind: SurfaceKind
    path: str
    handler: str
    component: str
    evidence: Evidence
    method: str | None = None


@dataclass
class Edge:
    """A directed dependency between two components, weighted by import count."""

    src: str
    dst: str
    weight: int


@dataclass
class Hotspot:
    """A component ranked by how much of the system depends on it.

    ``blast_radius`` is the number of components that transitively import this
    one. It answers "if I break this, what else breaks?" — the question that
    lets an agent push back on a change instead of blindly applying it.
    """

    component: str
    fan_in: int
    fan_out: int
    blast_radius: int


@dataclass
class Entity:
    """An inferred domain concept (e.g. "Skill", "Thread", "Agent")."""

    name: str
    description: str
    evidence: list[Evidence] = field(default_factory=list)
    confidence: float = 0.0


@dataclass
class Rule:
    """An inferred business or architectural rule the system appears to enforce."""

    statement: str
    evidence: list[Evidence] = field(default_factory=list)
    confidence: float = 0.0


@dataclass
class Stack:
    """Detected languages, frameworks and package managers."""

    languages: dict[str, int] = field(default_factory=dict)
    frameworks: list[str] = field(default_factory=list)
    package_managers: list[str] = field(default_factory=list)


@dataclass
class WorldModel:
    """The full structured picture of a codebase."""

    repo: str
    commit: str | None
    generated_at: str
    schema_version: str = SCHEMA_VERSION
    stack: Stack = field(default_factory=Stack)
    components: list[Component] = field(default_factory=list)
    surfaces: list[Surface] = field(default_factory=list)
    edges: list[Edge] = field(default_factory=list)
    hotspots: list[Hotspot] = field(default_factory=list)
    cycles: list[list[str]] = field(default_factory=list)
    entities: list[Entity] = field(default_factory=list)
    rules: list[Rule] = field(default_factory=list)
    file_hashes: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
