"""HTTP + WebSocket routes for the Apex floating RAG widget."""
from __future__ import annotations

from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from app.agents.apex.service import handle_apex_ws
from app.core.session import get_context
from app.core.config import settings

router = APIRouter(prefix="/agents/apex", tags=["apex"])


def _parse_ws_user(ws: WebSocket) -> dict | None:
    """Extract user from signed session cookie on WebSocket.

    Starlette's SessionMiddleware encodes sessions as:
        TimestampSigner.sign(base64(json_bytes))
    so we must use TimestampSigner (not URLSafeTimedSerializer) to unsign,
    then base64-decode and JSON-parse the payload.
    """
    import base64
    import json
    from itsdangerous import TimestampSigner, BadSignature, SignatureExpired

    cookie = ws.cookies.get(settings.session_cookie_name)
    if not cookie:
        return None
    try:
        signer = TimestampSigner(settings.app_secret_key)
        data = signer.unsign(cookie, max_age=settings.session_ttl_seconds, return_timestamp=False)
        session_data = json.loads(base64.b64decode(data))
        return session_data.get("user")
    except (BadSignature, SignatureExpired):
        return None
    except Exception:
        return None


@router.websocket("/ws")
async def apex_ws(ws: WebSocket):
    user = _parse_ws_user(ws)
    if not user:
        await ws.accept()
        await ws.close(code=4001, reason="unauthenticated")
        return
    await ws.accept()
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