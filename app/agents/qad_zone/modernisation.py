"""QAD modernisation analysis module.

Flow:
1. Receive current_version + target_version directly (no chat parsing)
2. Load inventory of all custom programs across all modules
3. Load full code of each module for deep analysis
4. Search the web for target version features and upgrade guides
5. LLM analyses: carry forward / drop / adapt for each customisation
6. Generate a corporate Word doc with the full migration plan
"""
from __future__ import annotations

import logging

from app.core.llm import openai_chat
from app.agents.qad_zone.programs import load_all_code_summary, list_modules, load_module_code
from app.agents.qad_zone.doc_generator import generate_document

logger = logging.getLogger(__name__)

# Try DuckDuckGo (free, no key required)
try:
    from duckduckgo_search import DDGS
    _ddg_available = True
except ImportError:
    _ddg_available = False
    logger.warning("duckduckgo-search not installed; web search disabled for modernisation")


def _web_search(query: str, max_results: int = 6) -> str:
    """Search the web via DuckDuckGo. Returns formatted results or fallback message."""
    if not _ddg_available:
        return "Web search not available (install duckduckgo-search)."
    try:
        results = []
        with DDGS() as ddgs:
            for r in ddgs.text(query, max_results=max_results):
                title = r.get("title", "")
                body = r.get("body", "")
                href = r.get("href", "")
                results.append(f"• {title}\n  {body}\n  Source: {href}")
        return "\n\n".join(results) if results else "No results found."
    except Exception as exc:
        logger.warning("DuckDuckGo search failed: %s", exc)
        return f"Web search failed: {exc}"


def _load_all_module_code(max_chars_per_module: int = 40_000) -> str:
    """Load code from all modules, each capped to keep total context reasonable."""
    modules = list_modules()
    if not modules:
        return "No custom program modules found."

    parts = []
    for mod in modules:
        code = load_module_code(mod, max_chars=max_chars_per_module)
        parts.append(f"\n{'#'*70}\n# MODULE: {mod.upper()}\n{'#'*70}\n{code}")
    return "\n".join(parts)


async def analyse_modernisation(
    current_version: str,
    target_version: str,
) -> dict:
    """Run full modernisation analysis. Returns dict with summary, sections, doc_url."""

    # ── Step 1: Inventory + code ─────────────────────────────────────────────
    programs_summary = load_all_code_summary()
    all_code = _load_all_module_code()

    # ── Step 2: Web research ─────────────────────────────────────────────────
    searches = [
        f"QAD {target_version} new features changelog what's new",
        f"QAD {current_version} to {target_version} upgrade migration guide",
        f"QAD {target_version} customisation standard functionality replaced",
        f"QAD ERP {target_version} Progress 4GL OpenEdge compatibility",
    ]

    web_parts = []
    for q in searches:
        logger.info("Searching: %s", q)
        result = _web_search(q, max_results=5)
        web_parts.append(f"SEARCH: {q}\n{result}")

    web_context = "\n\n".join(web_parts)

    # ── Step 3: LLM deep analysis ─────────────────────────────────────────────
    prompt = f"""You are a senior QAD ERP modernisation consultant.
Analyse the custom QAD programs below and produce a comprehensive, actionable migration plan.

CURRENT VERSION: {current_version}
TARGET VERSION: {target_version}

━━━ CUSTOM PROGRAMS INVENTORY ━━━
{programs_summary}

━━━ FULL CUSTOM CODE ━━━
{all_code}

━━━ WEB RESEARCH — TARGET VERSION & MIGRATION ━━━
{web_context}

━━━ INSTRUCTIONS ━━━
Produce a detailed migration plan with exactly these sections:

1. Executive Summary
   - Scope of migration, number of customisations, high-level recommendation

2. Version Comparison: {current_version} vs {target_version}
   - Key architectural changes, new standard features, deprecated capabilities

3. Customisations to CARRY FORWARD
   - For each: module name, what it does, why it must be kept, migration effort (Low/Med/High)

4. Customisations to DROP (now standard in {target_version})
   - For each: module name, what it does, which standard feature replaces it

5. Customisations Requiring ADAPTATION
   - For each: module name, what changes, technical approach, effort estimate

6. Implementation Roadmap
   - Ordered phases with clear milestones and dependencies

7. Risk Assessment
   - Top risks with likelihood, impact, and mitigation strategies

8. Effort Summary
   - Table-style breakdown: module | action | effort | priority

Return ONLY a JSON object (no markdown fences), exactly:
{{
  "summary": "One clear paragraph executive summary",
  "sections": [
    {{"heading": "Section Title", "content": "Detailed content...", "level": 1}},
    {{"heading": "Sub-section", "content": "...", "level": 2}},
    ...
  ]
}}

Be specific. Reference actual program file names from the code. Do not be vague.
"""

    raw = await openai_chat(
        "You are a senior QAD ERP modernisation consultant. Return only valid JSON.",
        prompt,
        max_tokens=4096,
        temperature=0.1,
    )

    from app.core.llm import parse_json_response
    try:
        parsed = parse_json_response(raw)
        sections = parsed.get("sections", [])
        summary = parsed.get("summary", "Migration analysis complete.")
    except Exception:
        logger.warning("Failed to parse JSON from modernisation LLM, using raw text")
        sections = [{"heading": "Migration Analysis", "content": raw, "level": 1}]
        summary = "Migration analysis generated. See document for full details."

    # ── Step 4: Generate Word document ───────────────────────────────────────
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