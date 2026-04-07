"""HTTP + WebSocket routes for the Apex floating RAG widget."""
from __future__ import annotations

from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from app.agents.apex.service import handle_apex_ws
from app.core.session import get_context

router = APIRouter(prefix="/agents/apex", tags=["apex"])


@router.websocket("/ws")
async def apex_ws(ws: WebSocket):
    cookie = ws.cookies.get("mitra_session")
    if not cookie:
        await ws.close(code=4001, reason="unauthenticated")
        return
    # Session data is in the signed cookie — parse via Starlette
    from starlette.middleware.sessions import SessionMiddleware
    from itsdangerous import URLSafeTimedSerializer
    from app.core.config import settings

    try:
        s = URLSafeTimedSerializer(settings.app_secret_key)
        session_data = s.loads(cookie, max_age=settings.session_ttl_seconds)
        user = session_data.get("user")
        if not user:
            await ws.close(code=4001, reason="unauthenticated")
            return
    except Exception:
        await ws.close(code=4001, reason="invalid session")
        return

    try:
        await handle_apex_ws(ws, user["session_id"], user)
    except WebSocketDisconnect:
        pass


@router.get("/context")
async def apex_context(request: Request):
    user = request.session.get("user")
    if not user:
        return JSONResponse({"error": "unauthenticated"}, status_code=401)
    ctx = get_context(user["session_id"], "apex") or {}
    return JSONResponse({"domains": ctx.get("domains", [])})
