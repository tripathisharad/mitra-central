"""HTTP routes for the Apex floating RAG widget."""
from __future__ import annotations

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.agents.registry import apex_agent

router = APIRouter(prefix="/agents/apex", tags=["apex"])


@router.post("/ask")
async def apex_ask(request: Request):
    user = request.session.get("user")
    if not user:
        return JSONResponse({"error": "unauthenticated"}, status_code=401)
    body = await request.json()
    question = (body.get("question") or "").strip()
    if not question:
        return JSONResponse({"error": "question is required"}, status_code=400)
    result = await apex_agent.ask(
        session_id=user["session_id"],
        question=question,
        user=user,
        extras={"domains": body.get("domains") or []},
    )
    return JSONResponse(result)


@router.get("/context")
async def apex_context(request: Request):
    """Returns whether the user has already picked Apex domains this session."""
    user = request.session.get("user")
    if not user:
        return JSONResponse({"error": "unauthenticated"}, status_code=401)
    ctx = await apex_agent.load_ctx(user["session_id"]) or {}
    return JSONResponse({"domains": ctx.get("domains", [])})
