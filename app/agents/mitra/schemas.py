"""Schemas for the Mitra text-to-SQL agent.

The n8n workflow is expected to return a JSON payload matching
:class:`MitraN8nResponse`. If the shape changes in n8n, only this file needs
updating.
"""
from __future__ import annotations

from pydantic import BaseModel, Field


class MitraAskRequest(BaseModel):
    question: str
    execute: bool = True  # if False, return the SQL without executing it


class MitraN8nResponse(BaseModel):
    sql: str | None = None
    reasoning: str | None = None
    followup_questions: list[str] = Field(default_factory=list)
    answer: str | None = None
    chart_hint: str | None = None  # optional hint: "table" | "bar" | "line" | "pie"


class MitraAskResponse(BaseModel):
    question: str
    sql: str | None
    reasoning: str | None
    followup_questions: list[str]
    answer: str | None
    columns: list[str] = Field(default_factory=list)
    rows: list[dict] = Field(default_factory=list)
    row_count: int = 0
    error: str | None = None
