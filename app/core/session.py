"""Per-agent conversation session helpers built on top of Redis.

Each (user_session_id, agent_key) pair gets its own history list in Redis so
that follow-up questions maintain context per-agent.
"""
from __future__ import annotations

from app.core.config import settings
from app.core.redis_client import get_history, get_json, push_history, set_json


def _history_key(session_id: str, agent_key: str) -> str:
    return f"mitra:hist:{agent_key}:{session_id}"


def _context_key(session_id: str, agent_key: str) -> str:
    return f"mitra:ctx:{agent_key}:{session_id}"


async def append_turn(session_id: str, agent_key: str, turn: dict) -> None:
    await push_history(
        _history_key(session_id, agent_key),
        turn,
        max_len=30,
        ttl=settings.session_ttl_seconds,
    )


async def load_history(session_id: str, agent_key: str) -> list[dict]:
    return await get_history(_history_key(session_id, agent_key))


async def set_context(session_id: str, agent_key: str, ctx: dict) -> None:
    await set_json(_context_key(session_id, agent_key), ctx, ttl=settings.session_ttl_seconds)


async def get_context(session_id: str, agent_key: str) -> dict | None:
    return await get_json(_context_key(session_id, agent_key))
