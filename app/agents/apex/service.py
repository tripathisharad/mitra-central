"""Apex — floating RAG chatbot trained on QAD user guides.

Pipeline:
1. Embed question via OpenAI text-embedding-3-large
2. Search Qdrant collection ``apex-normal`` with module metadata filter
3. Build prompt with top-10 chunks + conversation history
4. Stream answer via OpenAI through WebSocket
"""
from __future__ import annotations

import logging

from fastapi import WebSocket

from app.core.config import settings
from app.core.llm import openai_stream
from app.core.session import append_turn, get_context, load_history, set_context
from app.core.ws import send_done, send_error, send_frame, send_status, send_token
from app.vector.qdrant import search_chunks

logger = logging.getLogger(__name__)

AGENT_KEY = "apex"

SYSTEM_PROMPT = """You are Apex, a helpful QAD ERP assistant that answers questions based on official user guide documentation.

RULES:
- Answer ONLY based on the provided documentation chunks. If the answer isn't in the chunks, say "I don't have information about that in the user guides."
- Be concise but thorough. Use bullet points for steps.
- If the user asks a follow-up, use conversation history for context.
- At the end of your answer, suggest 1-2 relevant follow-up questions the user might want to ask.
- Format follow-up questions on separate lines starting with ">>>" like:
  >>> How do I approve a purchase order?
  >>> What are the PO status codes?

DOCUMENTATION CHUNKS:
{chunks}
"""


async def handle_apex_ws(ws: WebSocket, session_id: str, user: dict) -> None:
    """Main WebSocket handler for Apex. Reads messages and streams answers."""
    try:
        while True:
            data = await ws.receive_json()
            question = (data.get("question") or "").strip()
            if not question:
                await send_error(ws, "Question is required")
                continue

            domains = data.get("domains") or []
            # Store domains on first interaction
            if domains:
                ctx = get_context(session_id, AGENT_KEY) or {}
                if not ctx.get("domains"):
                    set_context(session_id, AGENT_KEY, {"domains": domains})
            else:
                ctx = get_context(session_id, AGENT_KEY) or {}
                domains = ctx.get("domains", [])

            await send_status(ws, "Searching documentation...")

            try:
                chunks = await search_chunks(
                    question,
                    collection=settings.qdrant_collection_apex,
                    modules=domains if domains else None,
                    top_k=10,
                )
            except Exception as exc:
                logger.exception("Qdrant search failed")
                await send_error(ws, f"Search failed: {exc}")
                await send_done(ws)
                continue

            chunks_text = "\n\n---\n\n".join(
                f"[Source: {c['metadata'].get('module', 'unknown')} | "
                f"{c['metadata'].get('filename', 'unknown')}]\n{c['text']}"
                for c in chunks
            )

            sources = [
                {
                    "module": c["metadata"].get("module", ""),
                    "filename": c["metadata"].get("filename", ""),
                    "score": round(c["score"], 3),
                }
                for c in chunks[:5]
            ]

            history = load_history(session_id, AGENT_KEY)
            chat_history = []
            for h in history[-10:]:
                chat_history.append({"role": "user", "content": h.get("q", "")})
                if h.get("a"):
                    chat_history.append({"role": "assistant", "content": h["a"]})

            system = SYSTEM_PROMPT.format(chunks=chunks_text or "No relevant documentation found.")

            await send_status(ws, "Generating answer...")

            full_answer = []
            followups = []
            try:
                async for token in openai_stream(system, question, history=chat_history):
                    full_answer.append(token)
                    await send_token(ws, token)
            except Exception as exc:
                logger.exception("OpenAI stream failed")
                await send_error(ws, f"LLM error: {exc}")
                await send_done(ws)
                continue

            answer_text = "".join(full_answer)

            # Extract follow-up questions (lines starting with >>>)
            for line in answer_text.split("\n"):
                stripped = line.strip()
                if stripped.startswith(">>>"):
                    followups.append(stripped[3:].strip())

            await send_frame(ws, "sources", sources)
            if followups:
                await send_frame(ws, "followup", followups)

            append_turn(session_id, AGENT_KEY, {"q": question, "a": answer_text})
            await send_done(ws)

    except Exception as exc:
        logger.exception("Apex WS error: %s", exc)
        try:
            await send_error(ws, str(exc))
            await send_done(ws)
        except Exception:
            pass
