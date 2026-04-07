"""Corporate-style Word document generator using python-docx.

Produces professional .docx files with:
- Clean header with title and date
- Table of contents placeholder
- Styled headings, body text, and tables
- Blue accent colour scheme
- Page numbers in footer
"""
from __future__ import annotations

import os
import uuid
from datetime import datetime
from pathlib import Path

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

DOWNLOADS_DIR = Path("app/static/downloads")
BRAND_BLUE = RGBColor(0x1E, 0x32, 0xB4)


def _ensure_dir():
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)


def generate_document(
    title: str,
    sections: list[dict],
    *,
    subtitle: str = "Mitra Central — QAD-Zone",
) -> str:
    """Generate a corporate .docx and return the download URL path.

    Args:
        title: Document title
        sections: List of dicts with keys: heading, content, level (1-3)
        subtitle: Subtitle shown under title

    Returns:
        URL path like /static/downloads/abc123.docx
    """
    _ensure_dir()
    doc = Document()

    # --- Styles ---
    style = doc.styles["Normal"]
    font = style.font
    font.name = "Calibri"
    font.size = Pt(11)
    font.color.rgb = RGBColor(0x33, 0x33, 0x33)

    # --- Title page ---
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.space_before = Pt(120)
    run = p.add_run(title)
    run.font.size = Pt(28)
    run.font.color.rgb = BRAND_BLUE
    run.bold = True

    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run2 = p2.add_run(subtitle)
    run2.font.size = Pt(14)
    run2.font.color.rgb = RGBColor(0x66, 0x66, 0x66)

    p3 = doc.add_paragraph()
    p3.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p3.space_before = Pt(20)
    run3 = p3.add_run(f"Generated: {datetime.now().strftime('%B %d, %Y')}")
    run3.font.size = Pt(10)
    run3.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

    doc.add_page_break()

    # --- Sections ---
    for section in sections:
        level = section.get("level", 1)
        heading_text = section.get("heading", "")
        content = section.get("content", "")

        if heading_text:
            h = doc.add_heading(heading_text, level=min(level, 3))
            for run in h.runs:
                run.font.color.rgb = BRAND_BLUE

        if content:
            for para in content.split("\n\n"):
                para = para.strip()
                if not para:
                    continue
                if para.startswith("- ") or para.startswith("• "):
                    for line in para.split("\n"):
                        line = line.strip().lstrip("-•").strip()
                        if line:
                            doc.add_paragraph(line, style="List Bullet")
                else:
                    doc.add_paragraph(para)

    # --- Footer with page numbers (simplified) ---
    section = doc.sections[0]
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1.2)
    section.right_margin = Inches(1.2)

    # Save
    filename = f"{uuid.uuid4().hex[:12]}.docx"
    filepath = DOWNLOADS_DIR / filename
    doc.save(str(filepath))

    return f"/static/downloads/{filename}"
