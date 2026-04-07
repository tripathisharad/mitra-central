"""QAD modernisation analysis module.

Flow:
1. List all custom programs the user has
2. User specifies current version and target version
3. Search the web for target version features (DuckDuckGo — free)
4. LLM analyses: carry forward / drop / adapt for each customisation
5. Generate a corporate Word doc with the migration plan
"""
from __future__ import annotations

import logging

from app.core.llm import openai_chat
from app.agents.qad_zone.programs import load_all_code_summary
from app.agents.qad_zone.doc_generator import generate_document

logger = logging.getLogger(__name__)

try:
    from duckduckgo_search import DDGS
    _ddg_available = True
except ImportError:
    _ddg_available = False
    logger.warning("duckduckgo-search not installed; web search disabled for modernisation")


def _web_search(query: str, max_results: int = 5) -> str:
    """Free web search via DuckDuckGo."""
    if not _ddg_available:
        return "Web search not available (duckduckgo-search package not installed)."
    try:
        results = []
        with DDGS() as ddgs:
            for r in ddgs.text(query, max_results=max_results):
                results.append(f"- {r['title']}: {r['body']}")
        return "\n".join(results) if results else "No web results found."
    except Exception as exc:
        logger.warning("DuckDuckGo search failed: %s", exc)
        return f"Web search failed: {exc}"


async def analyse_modernisation(
    current_version: str,
    target_version: str,
) -> dict:
    """Run full modernisation analysis. Returns {analysis_text, doc_url}."""

    # Step 1: Inventory of custom programs
    programs_summary = load_all_code_summary()

    # Step 2: Web search for target version features
    search_query = f"QAD {target_version} new features vs {current_version} customisation migration"
    web_results = _web_search(search_query, max_results=8)

    upgrade_query = f"QAD {target_version} upgrade guide from {current_version} best practices"
    upgrade_results = _web_search(upgrade_query, max_results=5)

    # Step 3: LLM analysis
    prompt = f"""You are a QAD ERP modernisation expert. Analyse the custom programs below and create a detailed migration plan.

CURRENT VERSION: {current_version}
TARGET VERSION: {target_version}

CUSTOM PROGRAMS INVENTORY:
{programs_summary}

WEB RESEARCH — TARGET VERSION FEATURES:
{web_results}

WEB RESEARCH — UPGRADE GUIDE:
{upgrade_results}

Create a comprehensive migration analysis with these sections:

1. EXECUTIVE SUMMARY — brief overview of the migration scope
2. CUSTOMISATIONS TO CARRY FORWARD — features not available natively in the target version; explain what needs to be migrated and how
3. CUSTOMISATIONS TO DROP — features that are now native in the target version; no need to carry these
4. CUSTOMISATIONS REQUIRING ADAPTATION — partially available in new version; explain what changes are needed
5. IMPLEMENTATION STEPS — ordered list of steps for the migration
6. RISK ASSESSMENT — potential risks and mitigations
7. ESTIMATED EFFORT — rough categorisation (low/medium/high) per customisation area

Format each section with a clear heading and detailed content.
Return your analysis as a JSON object:
{{
  "sections": [
    {{"heading": "Section Title", "content": "Detailed content...", "level": 1}},
    ...
  ],
  "summary": "One paragraph executive summary"
}}
"""

    raw = await openai_chat(
        "You are a QAD ERP modernisation expert.", prompt, max_tokens=4096
    )

    from app.core.llm import parse_json_response
    try:
        parsed = parse_json_response(raw)
        sections = parsed.get("sections", [])
        summary = parsed.get("summary", "Migration analysis complete.")
    except Exception:
        # Fallback: treat entire response as one section
        sections = [{"heading": "Migration Analysis", "content": raw, "level": 1}]
        summary = "Migration analysis generated."

    # Step 4: Generate Word document
    doc_url = generate_document(
        title=f"QAD Migration Plan: {current_version} → {target_version}",
        sections=sections,
        subtitle="Mitra Central — QAD-Zone Modernisation Report",
    )

    return {
        "summary": summary,
        "sections": sections,
        "doc_url": doc_url,
    }
