"""QAD-Zone — 3-mode agent for custom QAD code management.

Modes:
1. documentation — Generate corporate Word docs from custom code
2. query — RAG Q&A over custom programs (full module code stuffing)
3. modernisation — Migration analysis with web research + doc generation

The AI decides which module the question relates to (e-invoice, doa, etc.)
based on the question content — NOT based on user login roles.
"""
from __future__ import annotations

import logging

from fastapi import WebSocket

from app.core.llm import groq_chat, openai_stream, openai_chat, parse_json_response
from app.core.session import append_turn, get_context, load_history, set_context
from app.core.ws import send_done, send_error, send_frame, send_status, send_token
from app.agents.qad_zone.programs import list_modules, load_module_code, load_all_code_summary
from app.agents.qad_zone.doc_generator import generate_document
from app.agents.qad_zone.modernisation import analyse_modernisation

logger = logging.getLogger(__name__)

AGENT_KEY = "qadzone"


async def _detect_module(question: str, available_modules: list[str]) -> str | None:
    """Use Groq (free) to decide which module folder is relevant."""
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


async def _handle_documentation(ws: WebSocket, question: str, session_id: str) -> None:
    """Mode 1: Generate corporate Word document from custom code."""
    modules = list_modules()
    module = await _detect_module(question, modules)

    await send_status(ws, f"Loading code from module: {module or 'all'}...")
    code = load_module_code(module) if module else load_all_code_summary()

    await send_status(ws, "Generating document content...")

    prompt = f"""Based on the following QAD custom program code, create a professional technical document.

USER REQUEST: {question}

CODE:
{code}

Create a well-structured document with:
1. Overview / Introduction
2. Purpose and Scope
3. Technical Details (key logic, tables used, business rules)
4. Process Flow
5. Configuration / Setup Notes
6. Dependencies and Related Programs

Return as JSON:
{{
  "title": "Document Title",
  "sections": [
    {{"heading": "Section", "content": "Content...", "level": 1}},
    ...
  ]
}}
"""
    raw = await openai_chat("You are a QAD ERP technical writer.", prompt, max_tokens=4096)

    try:
        parsed = parse_json_response(raw)
        title = parsed.get("title", "QAD Custom Code Documentation")
        sections = parsed.get("sections", [])
    except Exception:
        title = "QAD Custom Code Documentation"
        sections = [{"heading": "Documentation", "content": raw, "level": 1}]

    doc_url = generate_document(title=title, sections=sections)

    # Stream a summary
    summary = f"Document generated: **{title}**\n\nSections covered:\n"
    for s in sections:
        summary += f"- {s.get('heading', 'Section')}\n"

    for chunk in [summary[i:i+20] for i in range(0, len(summary), 20)]:
        await send_token(ws, chunk)

    await send_frame(ws, "doc", {"url": doc_url, "title": title})


async def _handle_query(ws: WebSocket, question: str, session_id: str) -> None:
    """Mode 2: RAG Q&A over custom programs — full module code stuffing."""
    modules = list_modules()
    module = await _detect_module(question, modules)

    await send_status(ws, f"Loading code from module: {module or 'all'}...")
    code = load_module_code(module) if module else load_module_code("shared")

    history = load_history(session_id, AGENT_KEY)
    chat_history = []
    for h in history[-6:]:
        chat_history.append({"role": "user", "content": h.get("q", "")})
        if h.get("a"):
            chat_history.append({"role": "assistant", "content": h["a"]})

    system = f"""You are a QAD ERP expert who answers questions about custom Progress 4GL code.

CUSTOM CODE:
{code}

RULES:
- Answer based on the provided code. Reference specific program files and line logic.
- If the code doesn't contain the answer, say so clearly.
- For code modifications, show the specific changes needed with before/after.
- Suggest follow-up questions starting with ">>>" on separate lines.
"""

    await send_status(ws, "Analysing code...")
    full_answer = []
    async for token in openai_stream(system, question, history=chat_history):
        full_answer.append(token)
        await send_token(ws, token)

    answer_text = "".join(full_answer)
    followups = []
    for line in answer_text.split("\n"):
        if line.strip().startswith(">>>"):
            followups.append(line.strip()[3:].strip())
    if followups:
        await send_frame(ws, "followup", followups)

    append_turn(session_id, AGENT_KEY, {"q": question, "a": answer_text})


async def _handle_modernisation(ws: WebSocket, question: str, session_id: str) -> None:
    """Mode 3: Migration analysis with web research."""
    ctx = get_context(session_id, AGENT_KEY) or {}
    current_ver = ctx.get("current_version")
    target_ver = ctx.get("target_version")

    if not current_ver or not target_ver:
        # Try to extract from question
        prompt = (
            f"Extract QAD versions from this text: '{question}'\n"
            "Return JSON: {\"current\": \"version\", \"target\": \"version\"}\n"
            "If not found, return {\"current\": null, \"target\": null}"
        )
        raw = await groq_chat("Extract version info.", prompt, temperature=0, max_tokens=100)
        try:
            parsed = parse_json_response(raw)
            current_ver = parsed.get("current") or current_ver
            target_ver = parsed.get("target") or target_ver
        except Exception:
            pass

    if not current_ver or not target_ver:
        await send_token(ws, "Please specify your **current QAD version** and the **target version** you want to upgrade to.\n\nExample: *\"Upgrade from QAD EE 2.0 to QAD Adaptive ERP\"*")
        await send_done(ws)
        return

    # Save versions to context
    set_context(session_id, AGENT_KEY, {
        "current_version": current_ver,
        "target_version": target_ver,
        "mode": "modernisation",
    })

    await send_status(ws, f"Analysing migration: {current_ver} → {target_ver}...")
    await send_status(ws, "Searching web for version differences...")

    try:
        result = await analyse_modernisation(current_ver, target_ver)
    except Exception as exc:
        logger.exception("Modernisation analysis failed")
        await send_error(ws, f"Analysis failed: {exc}")
        await send_done(ws)
        return

    # Stream the summary
    summary = result.get("summary", "Analysis complete.")
    for chunk in [summary[i:i+20] for i in range(0, len(summary), 20)]:
        await send_token(ws, chunk)

    await send_frame(ws, "doc", {
        "url": result["doc_url"],
        "title": f"Migration Plan: {current_ver} → {target_ver}",
    })

    append_turn(session_id, AGENT_KEY, {
        "q": question,
        "a": summary,
        "mode": "modernisation",
    })


async def handle_qadzone_ws(ws: WebSocket, session_id: str, user: dict) -> None:
    """Main WebSocket handler for QAD-Zone (3 modes)."""
    try:
        while True:
            data = await ws.receive_json()
            question = (data.get("question") or "").strip()
            mode = (data.get("mode") or "query").strip().lower()

            if not question:
                await send_error(ws, "Question is required")
                continue

            try:
                if mode == "documentation":
                    await _handle_documentation(ws, question, session_id)
                elif mode == "modernisation":
                    await _handle_modernisation(ws, question, session_id)
                else:
                    await _handle_query(ws, question, session_id)
            except Exception as exc:
                logger.exception("QAD-Zone handler error")
                await send_error(ws, f"Error: {exc}")

            await send_done(ws)

    except Exception as exc:
        logger.debug("QAD-Zone WS closed: %s", exc)
