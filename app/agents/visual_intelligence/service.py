"""Visual Intelligence — KPI & chart generation from aggregation SQL.

Key difference from Mitra: the LLM is prompted to generate ONLY aggregation
queries (COUNT, SUM, AVG, TOP N, GROUP BY). Never raw SELECT *.
The response includes a chart spec rendered by Chart.js on the frontend.
"""
from __future__ import annotations

import logging

from fastapi import WebSocket

from app.core.config import settings
from app.core.llm import groq_chat, openai_stream, parse_json_response
from app.core.session import append_turn, get_user_settings, load_history
from app.core.ws import send_done, send_error, send_frame, send_status, send_token
from app.db.odbc import run_select
from app.agents.mitra.table_catalog import TABLE_CATALOG
from app.agents.mitra.table_schemas import get_schemas_for_tables
import json

logger = logging.getLogger(__name__)

AGENT_KEY = "visual"

VISUAL_SYSTEM_PROMPT = """You are a QAD ERP analytics & KPI assistant. You generate AGGREGATION queries for dashboards and charts.

SCHEMAS:
{schemas}

CRITICAL RULES:
1. ONLY generate aggregation queries: COUNT, SUM, AVG, MIN, MAX, TOP N, GROUP BY, date-wise breakdowns.
2. NEVER return SELECT * or raw row dumps. Always aggregate.
3. Result should be small (max 50 rows) — suitable for charts.
4. Filter by domain: WHERE table.domain_field = '{domain}'
5. Use user-friendly column aliases.
6. Include a chart specification in your response.

CHART TYPES: bar, line, pie, doughnut, kpi
- Use "kpi" when the user wants summary numbers (totals, counts)
- Use "bar" for comparisons across categories
- Use "line" for trends over time
- Use "pie"/"doughnut" for proportions

OUTPUT FORMAT — respond with ONLY this JSON (no markdown):
{{
  "query": "SELECT ...",
  "explanation": {{
    "basis": "What the user asked and logic used.",
    "benefit": "How this helps the user."
  }},
  "chart": {{
    "type": "bar|line|pie|doughnut|kpi",
    "title": "Chart Title",
    "x": "column_name_for_labels",
    "y": ["column_name_for_values"],
    "kpis": [
      {{"label": "Total Orders", "column": "order_count", "format": "number"}},
      {{"label": "Total Value", "column": "total_value", "format": "currency"}}
    ]
  }},
  "followup_questions": ["question 1"]
}}

NOTE: "kpis" is only needed when chart.type is "kpi". For other types use "x" and "y".
"""


async def _identify_tables(question: str) -> list[str]:
    raw = await groq_chat(
        "You are a QAD ERP expert. Return ONLY a JSON array of table names.",
        f"{TABLE_CATALOG}\n\nUser question: {question}\n\nJSON array:",
        temperature=0, max_tokens=100,
    )
    try:
        cleaned = raw.strip()
        if not cleaned.startswith("["):
            start = cleaned.find("[")
            end = cleaned.rfind("]") + 1
            cleaned = cleaned[start:end]
        return [t.strip().lower() for t in json.loads(cleaned)]
    except Exception:
        return ["pt_mstr", "in_mstr"]


async def handle_visual_ws(ws: WebSocket, session_id: str, user: dict) -> None:
    try:
        while True:
            data = await ws.receive_json()
            question = (data.get("question") or "").strip()
            if not question:
                await send_error(ws, "Question is required")
                continue

            user_settings = get_user_settings(session_id)
            row_limit = min(user_settings.get("row_limit", 50), 100)

            await send_status(ws, "Identifying relevant tables...")
            tables = await _identify_tables(question)
            schemas_text = get_schemas_for_tables(tables)

            history = load_history(session_id, AGENT_KEY)
            history_text = "\n".join(
                f"User: {h.get('q', '')}" for h in history[-4:]
            ) or "No previous conversation."

            system = VISUAL_SYSTEM_PROMPT.format(
                schemas=schemas_text,
                domain=settings.qad_domain,
            )

            await send_status(ws, "Generating analytics query...")

            full_response = []
            try:
                async for token in openai_stream(system, question):
                    full_response.append(token)
                    await send_token(ws, token)
            except Exception as exc:
                logger.exception("OpenAI stream failed")
                await send_error(ws, f"LLM error: {exc}")
                await send_done(ws)
                continue

            raw_text = "".join(full_response)
            sql_to_execute = None
            chart_spec = None
            followups = []

            try:
                parsed = parse_json_response(raw_text)
                sql_to_execute = parsed.get("query")
                chart_spec = parsed.get("chart")
                followups = parsed.get("followup_questions", [])
            except Exception:
                logger.warning("Could not parse Visual LLM response")

            if sql_to_execute:
                await send_frame(ws, "sql", sql_to_execute)
                await send_status(ws, "Executing analytics query...")
                try:
                    result = await run_select(sql_to_execute, limit=row_limit)
                    if chart_spec:
                        await send_frame(ws, "chart", {
                            "spec": chart_spec,
                            "columns": result["columns"],
                            "rows": result["rows"],
                            "row_count": result["row_count"],
                        })
                    else:
                        await send_frame(ws, "table", result)
                except Exception as exc:
                    logger.exception("ODBC query failed")
                    await send_error(ws, f"SQL execution failed: {exc}")
            else:
                await send_error(ws, "Could not generate analytics query. Please rephrase.")

            if followups:
                await send_frame(ws, "followup", followups[:3])

            append_turn(session_id, AGENT_KEY, {
                "q": question, "sql": sql_to_execute, "role": "user",
            })
            await send_done(ws)

    except Exception as exc:
        logger.exception("Visual WS error: %s", exc)
        try:
            await send_error(ws, str(exc))
            await send_done(ws)
        except Exception:
            pass
