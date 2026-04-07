"""HTTP + WebSocket routes for QAD-Zone."""
from __future__ import annotations

from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from itsdangerous import URLSafeTimedSerializer

from app.agents.qad_zone.service import handle_qadzone_ws
from app.agents.registry import sidebar_agents
from app.core.config import settings

router = APIRouter(prefix="/agents/qadzone", tags=["qadzone"])
templates = Jinja2Templates(directory="app/templates")


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
async def qadzone_page(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    if not user.get("roles"):
        return RedirectResponse("/roles", status_code=303)
    return templates.TemplateResponse("agents/qadzone.html", {
        "request": request,
        "user": user,
        "agents": sidebar_agents(),
        "active": "qadzone",
        "agent": {"key": "qadzone", "name": "QAD-Zone", "icon": "wrench",
                  "description": "Custom code knowledge base, documentation & modernisation.",
                  "route_prefix": "/agents/qadzone"},
    })


@router.websocket("/ws")
async def qadzone_ws(ws: WebSocket):
    user = _parse_ws_user(ws)
    if not user:
        await ws.accept()
        await ws.close(code=4001, reason="unauthenticated")
        return
    await ws.accept()
    try:
        await handle_qadzone_ws(ws, user["session_id"], user)
    except WebSocketDisconnect:
        pass
