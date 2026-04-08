"""Corporate-style Word document generator using python-docx.

Produces professional .docx files with:
- Clean title page with branding
- Auto-generated Table of Contents (field-based, updates on open)
- Styled headings, body text, and bullet lists
- Blue accent colour scheme (brand: #1E32B4)
- Page numbers in footer
- Proper margins
"""
from __future__ import annotations

import uuid
from datetime import datetime
from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

DOWNLOADS_DIR = Path("app/static/downloads")
BRAND_BLUE = RGBColor(0x1E, 0x32, 0xB4)
BRAND_DARK = RGBColor(0x0F, 0x1E, 0x7A)
TEXT_DARK = RGBColor(0x1A, 0x1A, 0x2E)
TEXT_MID = RGBColor(0x55, 0x55, 0x77)


def _ensure_dir():
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)


def _add_toc(doc: Document) -> None:
    """Insert a Word field-based Table of Contents that updates on open."""
    paragraph = doc.add_paragraph()
    run = paragraph.add_run()
    fldChar_begin = OxmlElement("w:fldChar")
    fldChar_begin.set(qn("w:fldCharType"), "begin")

    instrText = OxmlElement("w:instrText")
    instrText.set(qn("xml:space"), "preserve")
    instrText.text = 'TOC \\o "1-3" \\h \\z \\u'

    fldChar_separate = OxmlElement("w:fldChar")
    fldChar_separate.set(qn("w:fldCharType"), "separate")

    fldChar_end = OxmlElement("w:fldChar")
    fldChar_end.set(qn("w:fldCharType"), "end")

    run._r.append(fldChar_begin)
    run._r.append(instrText)
    run._r.append(fldChar_separate)
    run._r.append(fldChar_end)

    # Placeholder text so users know to update
    note = doc.add_paragraph()
    note_run = note.add_run("[ Right-click → Update Field to refresh the Table of Contents ]")
    note_run.font.size = Pt(9)
    note_run.font.color.rgb = RGBColor(0xAA, 0xAA, 0xCC)
    note_run.italic = True


def _add_page_numbers(doc: Document) -> None:
    """Add 'Page X of Y' to the footer of every section."""
    for section in doc.sections:
        footer = section.footer
        footer.is_linked_to_previous = False
        para = footer.paragraphs[0] if footer.paragraphs else footer.add_paragraph()
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        para.clear()

        run = para.add_run("Page ")
        run.font.size = Pt(9)
        run.font.color.rgb = TEXT_MID

        # Current page field
        fldChar1 = OxmlElement("w:fldChar")
        fldChar1.set(qn("w:fldCharType"), "begin")
        instr1 = OxmlElement("w:instrText")
        instr1.text = "PAGE"
        fldChar1e = OxmlElement("w:fldChar")
        fldChar1e.set(qn("w:fldCharType"), "end")
        page_run = OxmlElement("w:r")
        page_run.append(fldChar1)
        page_run.append(instr1)
        page_run.append(fldChar1e)
        para._p.append(page_run)

        run2 = para.add_run(" of ")
        run2.font.size = Pt(9)
        run2.font.color.rgb = TEXT_MID

        # Total pages field
        fldChar2 = OxmlElement("w:fldChar")
        fldChar2.set(qn("w:fldCharType"), "begin")
        instr2 = OxmlElement("w:instrText")
        instr2.text = "NUMPAGES"
        fldChar2e = OxmlElement("w:fldChar")
        fldChar2e.set(qn("w:fldCharType"), "end")
        numpages_run = OxmlElement("w:r")
        numpages_run.append(fldChar2)
        numpages_run.append(instr2)
        numpages_run.append(fldChar2e)
        para._p.append(numpages_run)


def _set_heading_color(heading, color: RGBColor = BRAND_BLUE) -> None:
    """Force heading run colour (Word styles can override, so we set directly)."""
    for run in heading.runs:
        run.font.color.rgb = color


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

    # ── Global font ──────────────────────────────────────────────────────────
    style = doc.styles["Normal"]
    font = style.font
    font.name = "Calibri"
    font.size = Pt(11)
    font.color.rgb = TEXT_DARK

    # ── Page margins ─────────────────────────────────────────────────────────
    for sec in doc.sections:
        sec.top_margin = Inches(1.0)
        sec.bottom_margin = Inches(1.0)
        sec.left_margin = Inches(1.25)
        sec.right_margin = Inches(1.25)

    # ── Title page ───────────────────────────────────────────────────────────
    # Decorative top bar via a paragraph border (approximated with shading)
    bar = doc.add_paragraph()
    bar.paragraph_format.space_before = Pt(0)
    bar.paragraph_format.space_after = Pt(0)
    bar_pPr = bar._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), "1E32B4")
    bar_pPr.append(shd)
    bar_run = bar.add_run(" " * 100)
    bar_run.font.size = Pt(4)

    # Spacer
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_before = Pt(80)

    # Title
    title_para = doc.add_paragraph()
    title_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    title_run = title_para.add_run(title)
    title_run.font.size = Pt(26)
    title_run.font.color.rgb = BRAND_DARK
    title_run.bold = True
    title_para.paragraph_format.space_after = Pt(6)

    # Subtitle
    sub_para = doc.add_paragraph()
    sub_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    sub_run = sub_para.add_run(subtitle)
    sub_run.font.size = Pt(13)
    sub_run.font.color.rgb = BRAND_BLUE
    sub_para.paragraph_format.space_after = Pt(4)

    # Date
    date_para = doc.add_paragraph()
    date_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    date_run = date_para.add_run(f"Generated: {datetime.now().strftime('%B %d, %Y')}")
    date_run.font.size = Pt(10)
    date_run.font.color.rgb = TEXT_MID
    date_run.italic = True
    date_para.paragraph_format.space_after = Pt(0)

    # Bottom bar
    doc.add_paragraph()
    bot_bar = doc.add_paragraph()
    bot_bar.paragraph_format.space_before = Pt(0)
    bot_bar.paragraph_format.space_after = Pt(0)
    bot_pPr = bot_bar._p.get_or_add_pPr()
    bot_shd = OxmlElement("w:shd")
    bot_shd.set(qn("w:val"), "clear")
    bot_shd.set(qn("w:color"), "auto")
    bot_shd.set(qn("w:fill"), "1E32B4")
    bot_pPr.append(bot_shd)
    bot_run = bot_bar.add_run(" " * 100)
    bot_run.font.size = Pt(4)

    doc.add_page_break()

    # ── Table of Contents ────────────────────────────────────────────────────
    toc_heading = doc.add_heading("Table of Contents", level=1)
    _set_heading_color(toc_heading, BRAND_BLUE)
    toc_heading.paragraph_format.space_after = Pt(6)
    _add_toc(doc)
    doc.add_page_break()

    # ── Sections ─────────────────────────────────────────────────────────────
    for section in sections:
        level = min(int(section.get("level", 1)), 3)
        heading_text = (section.get("heading") or "").strip()
        content = (section.get("content") or "").strip()

        if heading_text:
            h = doc.add_heading(heading_text, level=level)
            _set_heading_color(h, BRAND_BLUE if level == 1 else BRAND_DARK)
            h.paragraph_format.space_before = Pt(14 if level == 1 else 10)
            h.paragraph_format.space_after = Pt(4)

        if content:
            for block in content.split("\n\n"):
                block = block.strip()
                if not block:
                    continue

                # Detect bullet lists
                lines = block.split("\n")
                if all(ln.strip().startswith(("-", "•", "*")) for ln in lines if ln.strip()):
                    for line in lines:
                        line = line.strip().lstrip("-•* ").strip()
                        if line:
                            bp = doc.add_paragraph(line, style="List Bullet")
                            bp.paragraph_format.space_after = Pt(2)
                # Detect numbered lists
                elif lines[0].strip() and lines[0].strip()[0].isdigit() and ". " in lines[0]:
                    for line in lines:
                        line = line.strip()
                        if line:
                            # Strip leading "1. " style numbering — Word re-numbers
                            if len(line) > 2 and line[0].isdigit() and line[1] in ".):":
                                line = line[2:].strip()
                            elif len(line) > 3 and line[:2].isdigit() and line[2] in ".):":
                                line = line[3:].strip()
                            np = doc.add_paragraph(line, style="List Number")
                            np.paragraph_format.space_after = Pt(2)
                else:
                    p = doc.add_paragraph(block)
                    p.paragraph_format.space_after = Pt(6)
                    for run in p.runs:
                        run.font.color.rgb = TEXT_DARK

    # ── Page numbers in footer ───────────────────────────────────────────────
    _add_page_numbers(doc)

    # ── Save ─────────────────────────────────────────────────────────────────
    filename = f"{uuid.uuid4().hex[:12]}.docx"
    filepath = DOWNLOADS_DIR / filename
    doc.save(str(filepath))

    return f"/static/downloads/{filename}"