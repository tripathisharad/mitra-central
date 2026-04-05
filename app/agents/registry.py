"""Central agent registry.

Adding a new agent:

1. Create ``app/agents/<name>/`` with ``routes.py`` exposing ``router`` and
   ``service.py`` exposing a subclass of :class:`BaseAgent`.
2. Import and instantiate it below, then append it to ``AGENTS``.

That's it. The sidebar, routing and template resolution are all driven from
this list.
"""
from __future__ import annotations

from app.agents.apex.service import ApexAgent
from app.agents.base import BaseAgent
from app.agents.mitra.service import MitraAgent
from app.agents.qad_zone.service import QadZoneAgent
from app.agents.visual_intelligence.service import VisualIntelligenceAgent

mitra_agent = MitraAgent()
apex_agent = ApexAgent()
visual_agent = VisualIntelligenceAgent()
qadzone_agent = QadZoneAgent()

AGENTS: list[BaseAgent] = [mitra_agent, visual_agent, qadzone_agent, apex_agent]

BY_KEY: dict[str, BaseAgent] = {a.meta.key: a for a in AGENTS}


def get_agent(key: str) -> BaseAgent:
    if key not in BY_KEY:
        raise KeyError(f"Unknown agent: {key}")
    return BY_KEY[key]


def sidebar_agents() -> list[BaseAgent]:
    """Agents that appear in the left sidebar (everything except the floating widget)."""
    return [a for a in AGENTS if a.meta.layout == "main"]


def floating_agents() -> list[BaseAgent]:
    return [a for a in AGENTS if a.meta.layout == "side"]
