"""Base agent abstractions.

Every agent plugs into the app by subclassing :class:`BaseAgent` and
registering itself in :mod:`app.agents.registry`. The base class gives you:

* a webhook client (to n8n)
* conversation history via Redis
* a standard ``ask()`` contract

Concrete agents override :meth:`ask` to shape the payload they send and the
response they return. Everything else — routes, templates, sidebar entry — is
driven from the registry metadata so adding a new agent never touches other
files.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

import httpx

from app.core.config import settings
from app.core.session import append_turn, get_context, load_history, set_context

logger = logging.getLogger(__name__)


@dataclass
class AgentMeta:
    key: str                      # short stable identifier, used in URLs and Redis keys
    name: str                     # display name
    icon: str                     # lucide icon name (rendered in sidebar)
    description: str
    webhook_url: str
    route_prefix: str             # e.g. "/agents/mitra"
    layout: str = "main"          # "main" | "side" (Apex floats as "side")
    sample_questions: dict[str, list[str]] = field(default_factory=dict)  # role -> questions


class BaseAgent:
    meta: AgentMeta

    def __init__(self, meta: AgentMeta):
        self.meta = meta

    # ---- n8n client ----
    async def call_webhook(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not self.meta.webhook_url:
            raise RuntimeError(f"Webhook URL is not configured for agent '{self.meta.key}'")
        timeout = httpx.Timeout(settings.n8n_timeout_seconds)
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(self.meta.webhook_url, json=payload)
            resp.raise_for_status()
            try:
                return resp.json()
            except Exception:
                return {"raw": resp.text}

    # ---- session helpers ----
    async def history(self, session_id: str) -> list[dict]:
        return await load_history(session_id, self.meta.key)

    async def remember_turn(self, session_id: str, turn: dict) -> None:
        await append_turn(session_id, self.meta.key, turn)

    async def load_ctx(self, session_id: str) -> dict | None:
        return await get_context(session_id, self.meta.key)

    async def save_ctx(self, session_id: str, ctx: dict) -> None:
        await set_context(session_id, self.meta.key, ctx)

    # ---- contract ----
    async def ask(self, *, session_id: str, question: str, user: dict, extras: dict | None = None) -> dict[str, Any]:
        """Override in subclasses. Should return a dict to be JSON-serialised to the UI."""
        raise NotImplementedError

    def suggestions_for(self, roles: list[str]) -> list[str]:
        out: list[str] = []
        for r in roles:
            out.extend(self.meta.sample_questions.get(r, []))
        # de-dupe while preserving order
        seen = set()
        result = []
        for q in out:
            if q not in seen:
                seen.add(q)
                result.append(q)
        return result[:6]
