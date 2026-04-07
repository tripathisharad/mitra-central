"""HTTP + WebSocket routes for the Mitra text-to-SQL agent."""
from __future__ import annotations

from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from itsdangerous import URLSafeTimedSerializer

from app.agents.mitra.service import handle_mitra_ws
from app.agents.registry import sidebar_agents
from app.core.config import settings

router = APIRouter(prefix="/agents/mitra", tags=["mitra"])
templates = Jinja2Templates(directory="app/templates")

SAMPLE_QUESTIONS = {
    "sales": [
        "Show top 10 customers by order count",
        "What is the current sales backlog?",
        "Open sales orders due this week",
    ],
    "purchase": [
        "Show open purchase orders by supplier",
        "Total purchase value for last month",
        "List late deliveries in the last 15 days",
    ],
    "manufacturing": [
        "Show work in progress by work center",
        "Component shortages on open work orders",
        "Production completed yesterday",
    ],
    "inventory": [
        "What items have low inventory?",
        "Show items below reorder point",
        "What should I order?",
    ],
}


def _get_suggestions(roles: list[str]) -> list[str]:
    out = []
    for r in roles:
        out.extend(SAMPLE_QUESTIONS.get(r, []))
    if not out:
        for qs in SAMPLE_QUESTIONS.values():
            out.extend(qs)
    seen = set()
    return [q for q in out if not (q in seen or seen.add(q))][:8]


def _parse_ws_user(ws: WebSocket) -> dict | None:
    cookie = ws.cookies.get(settings.session_cookie_name)
    if not cookie:
        return None
    try:
        s = URLSafeTimedSerializer(settings.app_secret_key)
        session_data = s.loads(cookie, max_age=settings.session_ttl_seconds)
        return session_data.get("user")
    except Exception:
        return None


@router.get("", response_class=HTMLResponse)
async def mitra_page(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    if not user.get("roles"):
        return RedirectResponse("/roles", status_code=303)
    return templates.TemplateResponse("agents/mitra.html", {
        "request": request,
        "user": user,
        "agents": sidebar_agents(),
        "active": "mitra",
        "agent": {"key": "mitra", "name": "Mitra", "icon": "message-square",
                  "description": "Ask your QAD data in natural language.",
                  "route_prefix": "/agents/mitra"},
        "suggestions": _get_suggestions(user.get("roles", [])),
    })


@router.websocket("/ws")
async def mitra_ws(ws: WebSocket):
    user = _parse_ws_user(ws)
    if not user:
        await ws.accept()
        await ws.close(code=4001, reason="unauthenticated")
        return
    await ws.accept()
    try:
        await handle_mitra_ws(ws, user["session_id"], user)
    except WebSocketDisconnect:
        pass
