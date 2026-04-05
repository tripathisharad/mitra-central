"""FastAPI entry point for Mitra Central."""
from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware

from app.agents.mitra.routes import router as mitra_router
from app.agents.apex.routes import router as apex_router
from app.agents.visual_intelligence.routes import router as visual_router
from app.agents.qad_zone.routes import router as qadzone_router
from app.agents.registry import sidebar_agents, floating_agents
from app.auth.routes import router as auth_router
from app.core.config import settings

logging.basicConfig(
    level=logging.DEBUG if settings.app_debug else logging.INFO,
    format="%(asctime)s %(levelname)-7s %(name)s - %(message)s",
)

app = FastAPI(title=settings.app_name)

app.add_middleware(
    SessionMiddleware,
    secret_key=settings.app_secret_key,
    session_cookie=settings.session_cookie_name,
    max_age=settings.session_ttl_seconds,
    same_site="lax",
    https_only=False,
)

app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")


# ---- auth + agents ----
app.include_router(auth_router)
app.include_router(mitra_router)
app.include_router(apex_router)
app.include_router(visual_router)
app.include_router(qadzone_router)


@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    if not user.get("roles"):
        return RedirectResponse("/roles", status_code=303)
    # Home sends user straight to the Mitra agent by default.
    return RedirectResponse("/agents/mitra", status_code=303)


@app.get("/healthz")
async def healthz():
    return {"ok": True, "app": settings.app_name}


# Make agent lists available globally to templates (sidebar + floating widget).
@app.middleware("http")
async def inject_agents_ctx(request: Request, call_next):
    request.state.sidebar = [a.meta for a in sidebar_agents()]
    request.state.floating = [a.meta for a in floating_agents()]
    return await call_next(request)
