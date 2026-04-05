"""HTTP routes for QAD-Zone."""
from __future__ import annotations

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from app.agents.registry import qadzone_agent, sidebar_agents

router = APIRouter(prefix="/agents/qadzone", tags=["qadzone"])
templates = Jinja2Templates(directory="app/templates")


@router.get("", response_class=HTMLResponse)
async def qadzone_page(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    if not user.get("roles"):
        return RedirectResponse("/roles", status_code=303)
    return templates.TemplateResponse(
        "agents/qadzone.html",
        {
            "request": request,
            "user": user,
            "agent": qadzone_agent.meta,
            "agents": [a.meta for a in sidebar_agents()],
            "active": qadzone_agent.meta.key,
            "suggestions": qadzone_agent.suggestions_for(user.get("roles", [])),
        },
    )


@router.post("/ask")
async def qadzone_ask(request: Request):
    user = request.session.get("user")
    if not user:
        return JSONResponse({"error": "unauthenticated"}, status_code=401)
    body = await request.json()
    question = (body.get("question") or "").strip()
    if not question:
        return JSONResponse({"error": "question is required"}, status_code=400)
    result = await qadzone_agent.ask(
        session_id=user["session_id"],
        question=question,
        user=user,
        extras={"mode": body.get("mode", "answer")},
    )
    return JSONResponse(result)
