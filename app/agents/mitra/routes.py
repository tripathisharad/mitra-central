"""HTTP routes for the Mitra text-to-SQL agent."""
from __future__ import annotations

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from app.agents.registry import mitra_agent, sidebar_agents

router = APIRouter(prefix="/agents/mitra", tags=["mitra"])
templates = Jinja2Templates(directory="app/templates")


@router.get("", response_class=HTMLResponse)
async def mitra_page(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    if not user.get("roles"):
        return RedirectResponse("/roles", status_code=303)
    return templates.TemplateResponse(
        "agents/mitra.html",
        {
            "request": request,
            "user": user,
            "agent": mitra_agent.meta,
            "agents": [a.meta for a in sidebar_agents()],
            "active": mitra_agent.meta.key,
            "suggestions": mitra_agent.suggestions_for(user.get("roles", [])),
        },
    )


@router.post("/ask")
async def mitra_ask(request: Request):
    user = request.session.get("user")
    if not user:
        return JSONResponse({"error": "unauthenticated"}, status_code=401)
    body = await request.json()
    question = (body.get("question") or "").strip()
    if not question:
        return JSONResponse({"error": "question is required"}, status_code=400)
    result = await mitra_agent.ask(
        session_id=user["session_id"],
        question=question,
        user=user,
        extras={"execute": body.get("execute", True)},
    )
    return JSONResponse(result)
