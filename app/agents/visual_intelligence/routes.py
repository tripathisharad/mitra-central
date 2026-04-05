"""HTTP routes for Visual Intelligence."""
from __future__ import annotations

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from app.agents.registry import sidebar_agents, visual_agent

router = APIRouter(prefix="/agents/visual", tags=["visual"])
templates = Jinja2Templates(directory="app/templates")


@router.get("", response_class=HTMLResponse)
async def visual_page(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    if not user.get("roles"):
        return RedirectResponse("/roles", status_code=303)
    return templates.TemplateResponse(
        "agents/visual.html",
        {
            "request": request,
            "user": user,
            "agent": visual_agent.meta,
            "agents": [a.meta for a in sidebar_agents()],
            "active": visual_agent.meta.key,
            "suggestions": visual_agent.suggestions_for(user.get("roles", [])),
        },
    )


@router.post("/ask")
async def visual_ask(request: Request):
    user = request.session.get("user")
    if not user:
        return JSONResponse({"error": "unauthenticated"}, status_code=401)
    body = await request.json()
    question = (body.get("question") or "").strip()
    if not question:
        return JSONResponse({"error": "question is required"}, status_code=400)
    result = await visual_agent.ask(
        session_id=user["session_id"],
        question=question,
        user=user,
    )
    return JSONResponse(result)
