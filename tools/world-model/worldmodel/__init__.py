"""Software World Model — a structured, persistent picture of a codebase.

Instead of re-reading a repository from scratch every session, an agent reads
this model: components, the surfaces they expose, how they depend on each
other, and what breaks if one changes.
"""

from .schema import SCHEMA_VERSION, WorldModel

__all__ = ["SCHEMA_VERSION", "WorldModel"]
