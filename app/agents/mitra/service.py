"""Mitra — text-to-SQL agent on live QAD Progress DB via ODBC.

Full pipeline (all in Python, no n8n):
1. Identify relevant tables (Groq — fast & free)
2. Look up schemas for those tables
3. Check business rules for pre-built SQL
4. Generate SQL via OpenAI (or use pre-built)
5. Execute via ODBC
6. Stream explanation + send data via WebSocket
"""
from __future__ import annotations

import json
import logging

from fastapi import WebSocket

from app.core.config import settings
from app.core.llm import groq_chat, openai_stream, parse_json_response
from app.core.session import append_turn, get_user_settings, load_history
from app.core.ws import send_done, send_error, send_frame, send_status, send_token
from app.db.odbc import run_select
from app.agents.mitra.table_catalog import TABLE_CATALOG
from app.agents.mitra.table_schemas import get_schemas_for_tables
from app.agents.mitra.rules import find_matching_rule

logger = logging.getLogger(__name__)

AGENT_KEY = "mitra"

SQL_SYSTEM_PROMPT = """You are an expert QAD ERP SQL assistant. Generate a query based on the user's question using ONLY the provided table schemas.

SCHEMAS:
{schemas}

RULES:
1. Use proper SQL syntax compatible with Progress OpenEdge via ODBC. Prefer Progress-specific constructs where appropriate.
2. Always prefix table names with the schema `PUB.` (e.g. PUB.pt_mstr).
3. Always filter by domain: WHERE table.domain_field = '{domain}'
4. Always include `TOP {limit}` (Progress uses `TOP` instead of `LIMIT`). Place it immediately after `SELECT` when appropriate.
5. Use user-friendly column aliases (AS "Descriptive Name") for all columns.
6. Only use tables and columns from the provided schemas. Never guess.
7. For date comparisons use standard SQL date functions supported by Progress/OpenEdge.

{business_hint}

CONVERSATION CONTEXT (previous exchanges):
{history_text}

OUTPUT FORMAT — respond with ONLY this JSON (no markdown fences):
{{
  "query": "SELECT ...",
  "explanation": {{
    "basis": "What the user asked and the logic/criteria used to filter results.",
    "benefit": "How this data helps the user make decisions."
  }},
  "followup_questions": ["question 1", "question 2"]
}}
"""

SQL_WITH_RULE_PROMPT = """You are an expert QAD ERP SQL assistant. A pre-built query is provided. Your job is ONLY to explain it and suggest follow-ups.

PRE-BUILT QUERY:
{sql}

RULES:
- Use the EXACT query above in your response. Do NOT modify it.
- Explain what the query does and how it helps the user.

NOTES:
- The environment uses Progress OpenEdge via ODBC. When explaining, assume `PUB.` schema prefixes and Progress `TOP` pagination where applicable.

OUTPUT FORMAT — respond with ONLY this JSON (no markdown fences):
{{
  "query": "{sql_escaped}",
  "explanation": {{
    "basis": "What the user asked and the logic/criteria used.",
    "benefit": "How this data helps the user."
  }},
  "followup_questions": ["{followup}", "What other analysis would be helpful?"]
}}
"""


async def _identify_tables(question: str) -> list[str]:
    """Use Groq (free/fast) to identify which QAD tables are relevant."""
    prompt = f"{TABLE_CATALOG}\n\nUser question: {question}\n\nJSON array of relevant tables:"
    raw = await groq_chat(
        "You are a QAD ERP expert. Return ONLY a JSON array of table names.",
        prompt,
        temperature=0,
        max_tokens=100,
    )
    try:
        cleaned = raw.strip()
        if not cleaned.startswith("["):
            start = cleaned.find("[")
            end = cleaned.rfind("]") + 1
            cleaned = cleaned[start:end]
        tables = json.loads(cleaned)
        return [t.strip().lower() for t in tables if isinstance(t, str)]
    except Exception:
        logger.warning("Failed to parse table list: %s", raw)
        return ["pt_mstr", "in_mstr"]


def _build_history_text(history: list[dict]) -> str:
    lines = []
    for h in history[-6:]:
        lines.append(f"User: {h.get('q', '')}")
        if h.get("sql"):
            lines.append(f"SQL: {h['sql']}")
        if h.get("row_count") is not None:
            lines.append(f"Result: {h['row_count']} rows")
    return "\n".join(lines) if lines else "No previous conversation."


async def handle_mitra_ws(ws: WebSocket, session_id: str, user: dict) -> None:
    """Main WebSocket handler for Mitra text-to-SQL agent."""
    try:
        while True:
            data = await ws.receive_json()
            question = (data.get("question") or "").strip()
            if not question:
                await send_error(ws, "Question is required")
                continue

            user_settings = get_user_settings(session_id)
            row_limit = user_settings.get("row_limit", settings.default_row_limit)
            roles = user.get("roles", [])

            # Step 1: Identify tables
            await send_status(ws, "Identifying relevant tables...")
            tables = await _identify_tables(question)

            # Step 2: Get schemas
            schemas_text = get_schemas_for_tables(tables)

            # Step 3: Check business rules
            rule = find_matching_rule(question, roles)

            history = load_history(session_id, AGENT_KEY)
            history_text = _build_history_text(history)

            sql_to_execute = None
            followup = None

            if rule and rule.get("sql"):
                # Pre-built SQL — format with domain and limit
                sql_to_execute = rule["sql"].format(
                    domain=settings.qad_domain,
                    limit=row_limit,
                )
                followup = rule.get("followup", "")

                await send_status(ws, "Using optimised business rule query...")

                # Stream explanation from LLM
                explain_prompt = SQL_WITH_RULE_PROMPT.format(
                    sql=sql_to_execute,
                    sql_escaped=sql_to_execute.replace('"', '\\"'),
                    followup=followup,
                )
                full_response = []
                try:
                    async for token in openai_stream(
                        "You are a QAD ERP expert. Explain the query.", explain_prompt
                    ):
                        full_response.append(token)
                        await send_token(ws, token)
                except Exception as exc:
                    logger.exception("OpenAI stream failed")
                    await send_error(ws, f"LLM error: {exc}")
                    await send_done(ws)
                    continue

            else:
                # LLM generates SQL
                business_hint = ""
                if rule and rule.get("logic"):
                    business_hint = f"BUSINESS LOGIC HINT: {rule['logic']}"
                    followup = rule.get("followup")

                await send_status(ws, "Generating SQL query...")

                system = SQL_SYSTEM_PROMPT.format(
                    schemas=schemas_text,
                    domain=settings.qad_domain,
                    limit=row_limit,
                    business_hint=business_hint,
                    history_text=history_text,
                )

                full_response = []
                try:
                    async for token in openai_stream(system, question, history=[
                        {"role": h.get("role", "user"), "content": h.get("q", "")}
                        for h in history[-6:]
                    ]):
                        full_response.append(token)
                        await send_token(ws, token)
                except Exception as exc:
                    logger.exception("OpenAI stream failed")
                    await send_error(ws, f"LLM error: {exc}")
                    await send_done(ws)
                    continue

                # Parse the LLM response
                raw_text = "".join(full_response)
                try:
                    parsed = parse_json_response(raw_text)
                    sql_to_execute = parsed.get("query")
                    if not followup:
                        fups = parsed.get("followup_questions") or []
                        followup = fups[0] if fups else None
                except Exception:
                    logger.warning("Could not parse LLM response as JSON, extracting SQL")
                    # Try to extract SQL directly
                    for line in raw_text.split("\n"):
                        stripped = line.strip()
                        if stripped.upper().startswith(("SELECT", "WITH")):
                            sql_to_execute = stripped
                            break

            # Step 5: Execute SQL
            if sql_to_execute:
                await send_frame(ws, "sql", sql_to_execute)
                await send_status(ws, "Executing query on QAD...")
                try:
                    result = await run_select(sql_to_execute, limit=row_limit)
                    await send_frame(ws, "table", {
                        "columns": result["columns"],
                        "rows": result["rows"],
                        "row_count": result["row_count"],
                    })
                except Exception as exc:
                    logger.exception("ODBC query failed")
                    await send_error(ws, f"SQL execution failed: {exc}")
                    result = {"columns": [], "rows": [], "row_count": 0}
            else:
                await send_error(ws, "Could not generate a valid SQL query. Please rephrase your question.")
                result = {"columns": [], "rows": [], "row_count": 0}

            # Follow-up suggestions
            followups = []
            if followup:
                followups.append(followup)
            try:
                parsed_resp = parse_json_response("".join(full_response))
                extra_fups = parsed_resp.get("followup_questions", [])
                for f in extra_fups:
                    if f not in followups:
                        followups.append(f)
            except Exception:
                pass
            if followups:
                await send_frame(ws, "followup", followups[:3])

            # Save to session history
            append_turn(session_id, AGENT_KEY, {
                "q": question,
                "sql": sql_to_execute,
                "row_count": result.get("row_count", 0),
                "role": "user",
            })

            await send_done(ws)

    except Exception as exc:
        logger.exception("Mitra WS error: %s", exc)
        try:
            await send_error(ws, str(exc))
            await send_done(ws)
        except Exception:
            pass
