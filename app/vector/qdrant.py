"""Qdrant vector search client for Apex RAG.

Embeds the query via OpenAI text-embedding-3-large, then searches the given
Qdrant collection with optional metadata filters.
"""
from __future__ import annotations

import logging
from typing import Any

from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchAny

from app.core.config import settings
from app.core.llm import openai_embed

logger = logging.getLogger(__name__)

_client: QdrantClient | None = None


def get_qdrant() -> QdrantClient:
    global _client
    if _client is None:
        _client = QdrantClient(
            url=settings.qdrant_url,
            api_key=settings.qdrant_api_key,
        )
    return _client


async def search_chunks(
    query: str,
    *,
    collection: str | None = None,
    modules: list[str] | None = None,
    top_k: int = 10,
) -> list[dict[str, Any]]:
    """Embed query and search Qdrant. Returns list of {text, metadata, score}."""
    coll = collection or settings.qdrant_collection_apex
    vector = await openai_embed(query)

    query_filter = None
    if modules:
        query_filter = Filter(
            must=[
                FieldCondition(
                    key="module",
                    match=MatchAny(any=modules),
                )
            ]
        )

    client = get_qdrant()
    results = client.search(
        collection_name=coll,
        query_vector=vector,
        query_filter=query_filter,
        limit=top_k,
        with_payload=True,
    )

    chunks = []
    for r in results:
        payload = r.payload or {}
        chunks.append({
            "text": payload.get("text", payload.get("content", "")),
            "metadata": {k: v for k, v in payload.items() if k not in ("text", "content")},
            "score": r.score,
        })
    return chunks
