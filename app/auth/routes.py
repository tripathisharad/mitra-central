"""Authentication routes — login, role selection, logout.

Phase 1: credentials are hardcoded in settings. Role is stored in the signed
session cookie and used to personalise suggested questions per agent.
"""
from __future__ import annotations

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from app.core.security import new_session_id, verify_credentials

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

VALID_ROLES = {"sales", "purchase", "manufacturing"}


@router.get("/login", response_class=HTMLResponse)
async def login_get(request: Request):
    if request.session.get("user"):
        return RedirectResponse("/", status_code=303)
    return templates.TemplateResponse("auth/login.html", {"request": request, "error": None})


@router.post("/login", response_class=HTMLResponse)
async def login_post(request: Request, username: str = Form(...), password: str = Form(...)):
    if not verify_credentials(username, password):
        return templates.TemplateResponse(
            "auth/login.html",
            {"request": request, "error": "Invalid credentials"},
            status_code=401,
        )
    request.session["user"] = {
        "username": username,
        "session_id": new_session_id(),
        "roles": [],
    }
    return RedirectResponse("/roles", status_code=303)


@router.get("/roles", response_class=HTMLResponse)
async def roles_get(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    return templates.TemplateResponse("auth/roles.html", {"request": request, "user": user})


@router.post("/roles", response_class=HTMLResponse)
async def roles_post(request: Request):
    user = request.session.get("user")
    if not user:
        return RedirectResponse("/login", status_code=303)
    form = await request.form()
    selected = [r for r in form.getlist("roles") if r in VALID_ROLES]
    if not selected:
        return templates.TemplateResponse(
            "auth/roles.html",
            {"request": request, "user": user, "error": "Please select at least one role"},
            status_code=400,
        )
    user["roles"] = selected
    request.session["user"] = user
    return RedirectResponse("/", status_code=303)


@router.post("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/login", status_code=303)
