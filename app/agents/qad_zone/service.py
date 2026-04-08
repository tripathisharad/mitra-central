"""QAD-Zone — 3-mode agent for custom QAD code management.

Modes:
1. query        — RAG Q&A over custom programs (full module code stuffing) with chat history
2. documentation — Generate corporate Word docs from custom code, with chat history
3. modernisation — Takes current_version + target_version directly from WS payload,
                   runs web research + LLM analysis, generates Word migration plan.
                   No back-and-forth chat — one-shot triggered by the frontend form.

The AI decides which module the question relates to (e-invoice, doa, etc.)
based on the question content — NOT based on user login roles.
"""
from __future__ import annotations

import logging

from fastapi import WebSocket

from app.core.llm import groq_chat, openai_stream, openai_chat, parse_json_response
from app.core.session import append_turn, load_history, set_context, get_context
from app.core.ws import send_done, send_error, send_frame, send_status, send_token
from app.agents.qad_zone.programs import list_modules, load_module_code, load_all_code_summary
from app.agents.qad_zone.doc_generator import generate_document
from app.agents.qad_zone.modernisation import analyse_modernisation

logger = logging.getLogger(__name__)

AGENT_KEY = "qadzone"


async def _detect_module(question: str, available_modules: list[str]) -> str | None:
    """Use Groq (free/fast) to decide which module folder is relevant."""
    if not available_modules:
        return None
    prompt = (
        f"Available QAD custom code modules: {available_modules}\n\n"
        f"User question: {question}\n\n"
        "Which module is most relevant? Return ONLY the module name as a single word. "
        "If none match, return 'none'."
    )
    raw = await groq_chat(
        "You classify QAD questions to code modules. Return only the module name.",
        prompt, temperature=0, max_tokens=20,
    )
    result = raw.strip().lower().strip('"\'')
    return result if result in available_modules else None


# ── Mode 1: Query ─────────────────────────────────────────────────────────────

async def _handle_query(ws: WebSocket, question: str, session_id: str) -> None:
    """Q&A over custom programs — Groq routes to module, GPT-4o streams answer."""
    modules = list_modules()
    module = await _detect_module(question, modules)

    await send_status(ws, f"Loading code from module: {module or 'all'}...")
    code = load_module_code(module) if module else load_all_code_summary()

    history = load_history(session_id, AGENT_KEY)
    # Build OpenAI-format history from saved turns (query mode only)
    chat_history = []
    for h in history[-6:]:
        if h.get("mode", "query") != "query":
            continue
        if h.get("q"):
            chat_history.append({"role": "user", "content": h["q"]})
        if h.get("a"):
            chat_history.append({"role": "assistant", "content": h["a"]})

    system = f"""You are a QAD ERP expert who answers questions about custom Progress 4GL code.

CUSTOM CODE:
{code}

RULES:
- Answer based on the provided code. Reference specific program files and logic.
- If the code doesn't contain the answer, say so clearly.
- For code modifications, show specific changes with before/after examples.
- Suggest 2-3 follow-up questions starting with ">>>" on separate lines at the end.
"""

    await send_status(ws, "Analysing code...")
    full_answer: list[str] = []
    async for token in openai_stream(system, question, history=chat_history):
        full_answer.append(token)
        await send_token(ws, token)

    answer_text = "".join(full_answer)

    # Extract follow-up suggestions
    followups = []
    for line in answer_text.split("\n"):
        if line.strip().startswith(">>>"):
            followups.append(line.strip()[3:].strip())
    if followups:
        await send_frame(ws, "followup", followups)

    append_turn(session_id, AGENT_KEY, {"q": question, "a": answer_text, "mode": "query"})


# ── Mode 2: Documentation ─────────────────────────────────────────────────────

async def _handle_documentation(ws: WebSocket, question: str, session_id: str) -> None:
    """Generate corporate Word doc from custom code — with chat history support."""
    modules = list_modules()
    module = await _detect_module(question, modules)

    await send_status(ws, f"Loading code from module: {module or 'all'}...")
    code = load_module_code(module) if module else load_all_code_summary()

    history = load_history(session_id, AGENT_KEY)
    chat_history = []
    for h in history[-4:]:
        if h.get("mode", "documentation") != "documentation":
            continue
        if h.get("q"):
            chat_history.append({"role": "user", "content": h["q"]})
        if h.get("a"):
            chat_history.append({"role": "assistant", "content": h["a"]})

    await send_status(ws, "Generating document structure...")

    system = """You are a QAD ERP technical writer producing corporate-quality documentation.
Always return valid JSON only — no markdown fences, no preamble."""

    prompt = f"""Based on the following QAD custom program code, create a professional technical document.

USER REQUEST: {question}

CODE:
{code}

Create a well-structured corporate document. Include all relevant sections such as:
- Overview / Introduction
- Purpose and Scope
- Technical Architecture (key programs, includes, data structures)
- Business Logic and Process Flow
- Database Tables and Fields Used (.df schema if present)
- Configuration and Setup
- Dependencies and Related Programs
- Known Limitations or Considerations

Return ONLY valid JSON:
{{
  "title": "Document Title",
  "sections": [
    {{"heading": "Section Title", "content": "Full content here...", "level": 1}},
    {{"heading": "Sub-section", "content": "...", "level": 2}},
    ...
  ]
}}
"""

    raw = await openai_chat(system, prompt, history=chat_history, max_tokens=4096)

    try:
        parsed = parse_json_response(raw)
        title = parsed.get("title", "QAD Custom Code Documentation")
        sections = parsed.get("sections", [])
    except Exception:
        title = "QAD Custom Code Documentation"
        sections = [{"heading": "Documentation", "content": raw, "level": 1}]

    await send_status(ws, "Building Word document...")
    doc_url = generate_document(title=title, sections=sections)

    # Stream a summary of what was produced
    module_label = module.upper() if module else "all modules"
    summary = f"**{title}**\n\nDocumentation generated for **{module_label}** covering {len(sections)} sections:\n"
    for s in sections:
        indent = "  " * (s.get("level", 1) - 1)
        summary += f"{indent}- {s.get('heading', 'Section')}\n"

    for chunk in [summary[i:i + 30] for i in range(0, len(summary), 30)]:
        await send_token(ws, chunk)

    await send_frame(ws, "doc", {"url": doc_url, "title": title})

    append_turn(session_id, AGENT_KEY, {
        "q": question,
        "a": summary,
        "mode": "documentation",
        "doc_url": doc_url,
    })


# ── Mode 3: Modernisation ─────────────────────────────────────────────────────

async def _handle_modernisation(
    ws: WebSocket,
    session_id: str,
    current_version: str,
    target_version: str,
) -> None:
    """One-shot migration analysis — versions come directly from WS payload."""
    current_version = (current_version or "").strip()
    target_version = (target_version or "").strip()

    if not current_version or not target_version:
        await send_error(ws, "Both current_version and target_version are required.")
        return

    # Save to session context for reference
    set_context(session_id, AGENT_KEY, {
        "current_version": current_version,
        "target_version": target_version,
        "mode": "modernisation",
    })

    await send_status(ws, f"Starting migration analysis: {current_version} → {target_version}...")
    await send_status(ws, "Loading all custom module code...")
    await send_status(ws, "Searching web for version differences and upgrade guides...")

    try:
        result = await analyse_modernisation(current_version, target_version)
    except Exception as exc:
        logger.exception("Modernisation analysis failed")
        await send_error(ws, f"Analysis failed: {exc}")
        return

    summary = result.get("summary", "Migration analysis complete.")
    for chunk in [summary[i:i + 30] for i in range(0, len(summary), 30)]:
        await send_token(ws, chunk)

    await send_frame(ws, "doc", {
        "url": result["doc_url"],
        "title": f"Migration Plan: {current_version} → {target_version}",
    })

    append_turn(session_id, AGENT_KEY, {
        "q": f"Migration: {current_version} → {target_version}",
        "a": summary,
        "mode": "modernisation",
    })


# ── Main WebSocket Handler ────────────────────────────────────────────────────

async def handle_qadzone_ws(ws: WebSocket, session_id: str, user: dict) -> None:
    """Main WebSocket handler for QAD-Zone (3 modes).

    Expected WS payload schemas:
      Query:         {mode: "query", question: "..."}
      Documentation: {mode: "documentation", question: "..."}
      Modernisation: {mode: "modernisation", current_version: "...", target_version: "..."}
    """
    try:
        while True:
            data = await ws.receive_json()
            mode = (data.get("mode") or "query").strip().lower()

            try:
                if mode == "modernisation":
                    current_version = (data.get("current_version") or "").strip()
                    target_version = (data.get("target_version") or "").strip()
                    await _handle_modernisation(
                        ws, session_id, current_version, target_version
                    )

                elif mode == "documentation":
                    question = (data.get("question") or "").strip()
                    if not question:
                        await send_error(ws, "Question is required for documentation mode.")
                    else:
                        await _handle_documentation(ws, question, session_id)

                else:  # default: query
                    question = (data.get("question") or "").strip()
                    if not question:
                        await send_error(ws, "Question is required.")
                    else:
                        await _handle_query(ws, question, session_id)

            except Exception as exc:
                logger.exception("QAD-Zone handler error (mode=%s)", mode)
                await send_error(ws, f"Error: {exc}")

            await send_done(ws)

    except Exception as exc:
        logger.exception("QAD-Zone WS error: %s", exc)
        try:
            await send_error(ws, str(exc))
            await send_done(ws)
        except Exception:
            pass