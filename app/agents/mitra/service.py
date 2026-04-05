"""Mitra — text-to-SQL agent on live QAD Progress DB via ODBC."""
from __future__ import annotations

import logging
from typing import Any

from app.agents.base import AgentMeta, BaseAgent
from app.core.config import settings
from app.db.odbc import run_select

logger = logging.getLogger(__name__)


MITRA_META = AgentMeta(
    key="mitra",
    name="Mitra",
    icon="message-square",
    description="Ask your QAD data in natural language.",
    webhook_url=settings.n8n_webhook_mitra,
    route_prefix="/agents/mitra",
    layout="main",
    sample_questions={
        "sales": [
            "Show top 10 customers by revenue this month",
            "Which items had the most sales orders last week?",
            "List open sales orders older than 30 days",
        ],
        "purchase": [
            "Show open purchase orders by supplier",
            "Total purchase value for last month by category",
            "List late deliveries in the last 15 days",
        ],
        "manufacturing": [
            "Show WIP by work center",
            "Production orders finished yesterday",
            "Items below safety stock",
        ],
    },
)


class MitraAgent(BaseAgent):
    def __init__(self) -> None:
        super().__init__(MITRA_META)

    async def ask(
        self,
        *,
        session_id: str,
        question: str,
        user: dict,
        extras: dict | None = None,
    ) -> dict[str, Any]:
        history = await self.history(session_id)
        payload = {
            "session_id": session_id,
            "agent": self.meta.key,
            "question": question,
            "user": {"username": user.get("username"), "roles": user.get("roles", [])},
            "history": history[-10:],
        }

        try:
            n8n = await self.call_webhook(payload)
        except Exception as exc:
            logger.exception("n8n call failed")
            return {
                "question": question,
                "sql": None,
                "reasoning": None,
                "followup_questions": [],
                "answer": None,
                "columns": [],
                "rows": [],
                "row_count": 0,
                "error": f"n8n request failed: {exc}",
            }

        sql = n8n.get("sql")
        reasoning = n8n.get("reasoning")
        followups = n8n.get("followup_questions") or n8n.get("follow_up_questions") or []
        answer = n8n.get("answer")
        chart_hint = n8n.get("chart_hint")

        columns: list[str] = []
        rows: list[dict] = []
        row_count = 0
        error: str | None = None

        execute = (extras or {}).get("execute", True)
        if sql and execute:
            try:
                result = await run_select(sql, limit=1000)
                columns = result["columns"]
                rows = result["rows"]
                row_count = result["row_count"]
            except Exception as exc:
                logger.exception("ODBC query failed")
                error = f"SQL execution failed: {exc}"

        turn = {
            "q": question,
            "sql": sql,
            "row_count": row_count,
            "error": error,
        }
        await self.remember_turn(session_id, turn)

        return {
            "question": question,
            "sql": sql,
            "reasoning": reasoning,
            "followup_questions": followups,
            "answer": answer,
            "chart_hint": chart_hint,
            "columns": columns,
            "rows": rows,
            "row_count": row_count,
            "error": error,
        }
