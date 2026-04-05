"""Visual Intelligence — KPI & chart generation.

n8n returns an aggregation SQL plus a chart spec. Python runs the SQL against
QAD via ODBC and ships both the raw rows and the chart spec to the browser,
where Chart.js renders it.

Expected n8n response shape::

    {
      "sql": "SELECT ...",
      "reasoning": "...",
      "chart": {
        "type": "bar" | "line" | "pie" | "doughnut" | "kpi",
        "title": "Purchase value by month",
        "x": "month",                 # column name for x-axis / labels
        "y": ["total_value"],         # one or more column names for series
        "kpis": [                      # optional, when type == "kpi"
          {"label": "Total POs", "column": "po_count", "format": "number"}
        ]
      },
      "followup_questions": ["..."]
    }
"""
from __future__ import annotations

import logging
from typing import Any

from app.agents.base import AgentMeta, BaseAgent
from app.core.config import settings
from app.db.odbc import run_select

logger = logging.getLogger(__name__)


VISUAL_META = AgentMeta(
    key="visual",
    name="Visual Intelligence",
    icon="bar-chart-3",
    description="Aggregations, KPIs and charts from live QAD data.",
    webhook_url=settings.n8n_webhook_visual,
    route_prefix="/agents/visual",
    layout="main",
    sample_questions={
        "sales": [
            "Show last month sales KPIs",
            "Monthly revenue trend for the last 12 months",
            "Top 5 customers by revenue as a pie chart",
        ],
        "purchase": [
            "Purchase value by supplier last quarter",
            "Monthly PO count trend for this year",
            "Top 10 items by purchase spend",
        ],
        "manufacturing": [
            "Daily production output last 30 days",
            "WIP by work center",
            "Scrap rate trend",
        ],
    },
)


class VisualIntelligenceAgent(BaseAgent):
    def __init__(self) -> None:
        super().__init__(VISUAL_META)

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
            logger.exception("Visual n8n call failed")
            return {
                "question": question,
                "sql": None,
                "chart": None,
                "reasoning": None,
                "columns": [],
                "rows": [],
                "row_count": 0,
                "followup_questions": [],
                "error": f"n8n request failed: {exc}",
            }

        sql = n8n.get("sql")
        chart = n8n.get("chart")
        reasoning = n8n.get("reasoning")
        followups = n8n.get("followup_questions") or []

        columns: list[str] = []
        rows: list[dict] = []
        row_count = 0
        error: str | None = None

        if sql:
            try:
                result = await run_select(sql, limit=5000)
                columns = result["columns"]
                rows = result["rows"]
                row_count = result["row_count"]
            except Exception as exc:
                logger.exception("Visual ODBC query failed")
                error = f"SQL execution failed: {exc}"

        await self.remember_turn(
            session_id,
            {"q": question, "sql": sql, "row_count": row_count, "error": error},
        )

        return {
            "question": question,
            "sql": sql,
            "chart": chart,
            "reasoning": reasoning,
            "columns": columns,
            "rows": rows,
            "row_count": row_count,
            "followup_questions": followups,
            "error": error,
        }
