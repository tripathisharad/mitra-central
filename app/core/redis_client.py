"""Async Redis client. Used for session data and per-agent context caching."""
from __future__ import annotations

import json
from typing import Any, Optional

import redis.asyncio as redis

from app.core.config import settings

_client: Optional[redis.Redis] = None


def get_redis() -> redis.Redis:
    global _client
    if _client is None:
        _client = redis.from_url(settings.redis_url, decode_responses=True)
    return _client


async def set_json(key: str, value: Any, ttl: int | None = None) -> None:
    r = get_redis()
    await r.set(key, json.dumps(value, default=str), ex=ttl)


async def get_json(key: str) -> Any | None:
    r = get_redis()
    raw = await r.get(key)
    return json.loads(raw) if raw else None


async def delete_key(key: str) -> None:
    await get_redis().delete(key)


async def push_history(key: str, item: dict, max_len: int = 20, ttl: int | None = None) -> None:
    """Append to a rolling per-session conversation history list."""
    r = get_redis()
    await r.rpush(key, json.dumps(item, default=str))
    await r.ltrim(key, -max_len, -1)
    if ttl:
        await r.expire(key, ttl)


async def get_history(key: str) -> list[dict]:
    r = get_redis()
    items = await r.lrange(key, 0, -1)
    return [json.loads(i) for i in items]
