"""Apex — floating RAG chatbot trained on user guides.

The domain (sales/purchase/manufacturing) selected by the user on first open
is forwarded to n8n as a metadata filter so the vector search only retrieves
chunks tagged with the matching domain.
"""
from __future__ import annotations

import logging
from typing import Any

from app.agents.base import AgentMeta, BaseAgent
from app.core.config import settings

logger = logging.getLogger(__name__)


APEX_META = AgentMeta(
    key="apex",
    name="Apex",
    icon="sparkles",
    description="Guide-aware assistant. Answers from the official user documentation.",
    webhook_url=settings.n8n_webhook_apex,
    route_prefix="/agents/apex",
    layout="side",  # floating widget
)


class ApexAgent(BaseAgent):
    def __init__(self) -> None:
        super().__init__(APEX_META)

    async def ask(
        self,
        *,
        session_id: str,
        question: str,
        user: dict,
        extras: dict | None = None,
    ) -> dict[str, Any]:
        ctx = await self.load_ctx(session_id) or {}
        # Per-session domain filter — asked once when the widget is first opened.
        domains = (extras or {}).get("domains") or ctx.get("domains") or []
        if domains and not ctx.get("domains"):
            await self.save_ctx(session_id, {"domains": domains})

        history = await self.history(session_id)
        payload = {
            "session_id": session_id,
            "agent": self.meta.key,
            "question": question,
            "metadata_filter": {"domain": domains},
            "user": {"username": user.get("username"), "roles": user.get("roles", [])},
            "history": history[-10:],
        }

        try:
            n8n = await self.call_webhook(payload)
        except Exception as exc:
            logger.exception("Apex n8n call failed")
            return {
                "question": question,
                "answer": None,
                "sources": [],
                "followup_questions": [],
                "error": f"n8n request failed: {exc}",
            }

        answer = n8n.get("answer") or n8n.get("text")
        sources = n8n.get("sources") or []
        followups = n8n.get("followup_questions") or []

        await self.remember_turn(session_id, {"q": question, "a": answer})
        return {
            "question": question,
            "answer": answer,
            "sources": sources,
            "followup_questions": followups,
            "error": None,
        }
