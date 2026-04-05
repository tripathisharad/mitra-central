"""QAD-Zone — RAG on custom QAD code and document generation.

Two modes, both routed through the same n8n webhook (n8n decides based on
``mode`` in the payload):

* ``answer`` — Q&A over existing custom code & documents.
* ``generate`` — create a new document or code snippet grounded in the
  existing knowledge base (e.g. "generate an e-invoice document like the
  existing one but for X").
"""
from __future__ import annotations

import logging
from typing import Any

from app.agents.base import AgentMeta, BaseAgent
from app.core.config import settings

logger = logging.getLogger(__name__)


QADZONE_META = AgentMeta(
    key="qadzone",
    name="QAD-Zone",
    icon="wrench",
    description="Custom QAD code knowledge base + document & code generation.",
    webhook_url=settings.n8n_webhook_qadzone,
    route_prefix="/agents/qadzone",
    layout="main",
    sample_questions={
        "sales": [
            "How is the custom sales quote approval flow implemented?",
            "Generate an e-invoice template based on the existing one",
        ],
        "purchase": [
            "Explain the custom vendor onboarding procedure",
            "Generate a GRN custom report based on the existing one",
        ],
        "manufacturing": [
            "Show me the custom routing explosion logic",
            "Generate a BOM change request document",
        ],
    },
)


class QadZoneAgent(BaseAgent):
    def __init__(self) -> None:
        super().__init__(QADZONE_META)

    async def ask(
        self,
        *,
        session_id: str,
        question: str,
        user: dict,
        extras: dict | None = None,
    ) -> dict[str, Any]:
        history = await self.history(session_id)
        mode = (extras or {}).get("mode", "answer")  # "answer" | "generate"
        payload = {
            "session_id": session_id,
            "agent": self.meta.key,
            "mode": mode,
            "question": question,
            "user": {"username": user.get("username"), "roles": user.get("roles", [])},
            "history": history[-10:],
        }

        try:
            n8n = await self.call_webhook(payload)
        except Exception as exc:
            logger.exception("QAD-Zone n8n call failed")
            return {
                "question": question,
                "answer": None,
                "document": None,
                "sources": [],
                "followup_questions": [],
                "error": f"n8n request failed: {exc}",
            }

        answer = n8n.get("answer") or n8n.get("text")
        document = n8n.get("document")  # generated artifact: {title, content, format}
        sources = n8n.get("sources") or []
        followups = n8n.get("followup_questions") or []

        await self.remember_turn(session_id, {"q": question, "mode": mode})

        return {
            "question": question,
            "mode": mode,
            "answer": answer,
            "document": document,
            "sources": sources,
            "followup_questions": followups,
            "error": None,
        }
