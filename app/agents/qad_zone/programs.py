"""QAD custom program file loader.

Loads Progress 4GL source files (.p, .i, .xml) from data/qad_programs/
organised by module folders (e.g., e-invoice/, doa/, shared/).

The AI decides which module is relevant based on the user question — NOT
based on the user's login role selection.
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

PROGRAMS_DIR = Path("data/qad_programs")
SUPPORTED_EXTENSIONS = {".p", ".i", ".xml", ".cls", ".w"}


def list_modules() -> list[str]:
    """Return list of available module folders."""
    if not PROGRAMS_DIR.exists():
        return []
    return sorted(
        d.name for d in PROGRAMS_DIR.iterdir()
        if d.is_dir() and not d.name.startswith(".")
    )


def list_programs(module: str | None = None) -> list[dict]:
    """List all programs, optionally filtered by module.

    Returns list of {module, filename, path, size_bytes}.
    """
    programs = []
    base = PROGRAMS_DIR / module if module else PROGRAMS_DIR
    if not base.exists():
        return programs

    for root, _, files in os.walk(base):
        for f in files:
            fp = Path(root) / f
            if fp.suffix.lower() in SUPPORTED_EXTENSIONS:
                rel = fp.relative_to(PROGRAMS_DIR)
                parts = rel.parts
                mod = parts[0] if len(parts) > 1 else "shared"
                programs.append({
                    "module": mod,
                    "filename": f,
                    "path": str(fp),
                    "size_bytes": fp.stat().st_size,
                })
    return programs


def load_module_code(module: str, max_chars: int = 120_000) -> str:
    """Load all source code from a module folder, concatenated.

    Truncates to max_chars to fit LLM context windows.
    """
    programs = list_programs(module)
    if not programs:
        # Also check shared
        programs = list_programs("shared")

    parts = []
    total = 0
    for p in programs:
        try:
            content = Path(p["path"]).read_text(encoding="utf-8", errors="replace")
            header = f"\n{'='*60}\n// FILE: {p['module']}/{p['filename']}\n{'='*60}\n"
            chunk = header + content
            if total + len(chunk) > max_chars:
                remaining = max_chars - total
                if remaining > 200:
                    parts.append(chunk[:remaining] + "\n// ... TRUNCATED ...")
                break
            parts.append(chunk)
            total += len(chunk)
        except Exception as exc:
            logger.warning("Failed to read %s: %s", p["path"], exc)

    return "\n".join(parts) if parts else "No custom program files found for this module."


def load_all_code_summary() -> str:
    """Load a brief summary of ALL custom programs across all modules."""
    modules = list_modules()
    lines = ["CUSTOM QAD PROGRAMS INVENTORY:\n"]
    for mod in modules:
        programs = list_programs(mod)
        lines.append(f"\nModule: {mod} ({len(programs)} files)")
        for p in programs:
            size_kb = p["size_bytes"] / 1024
            lines.append(f"  - {p['filename']} ({size_kb:.1f} KB)")
    return "\n".join(lines) if len(lines) > 1 else "No custom programs found."
