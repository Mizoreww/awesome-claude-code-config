#!/usr/bin/env python3
"""Create a portable paper-reading HTML report shell."""

from __future__ import annotations

import argparse
import re
import sys
from html import escape
from pathlib import Path
from urllib.parse import urlsplit

PAPER_TYPES = {"empirical", "theoretical", "survey", "systems"}
MODULE_PAPER_TYPES = {"empirical", "systems"}
TYPE_SECTIONS = {
    "empirical": (
        ("technical-method", "C3"),
        ("experimental-results", "E1"),
    ),
    "theoretical": (
        ("theoretical-framework", "C3"),
        ("theoretical-analysis", "E1"),
    ),
    "survey": (
        ("taxonomy", "C3"),
        ("open-problems", "E1"),
    ),
    "systems": (
        ("system-design", "C3"),
        ("performance-evaluation", "E1"),
    ),
}
SECTION_HEADINGS = {
    "zh": {
        "basic-information": "基本信息",
        "research-problem": "研究问题",
        "key-insight": "关键洞见",
        "technical-method": "技术方法",
        "experimental-results": "实验结果",
        "theoretical-framework": "理论框架",
        "theoretical-analysis": "定理与论证",
        "taxonomy": "分类框架",
        "open-problems": "开放问题与趋势",
        "system-design": "系统设计",
        "performance-evaluation": "性能评估",
        "critical-analysis": "批判分析",
        "summary": "总结与评价",
    },
    "en": {
        "basic-information": "Basic information",
        "research-problem": "Research problem",
        "key-insight": "Key insight",
        "technical-method": "Technical method",
        "experimental-results": "Experimental results",
        "theoretical-framework": "Theoretical framework",
        "theoretical-analysis": "Theorems and argument",
        "taxonomy": "Taxonomy",
        "open-problems": "Open problems and trends",
        "system-design": "System design",
        "performance-evaluation": "Performance evaluation",
        "critical-analysis": "Critical analysis",
        "summary": "Summary and assessment",
    },
}
UI_COPY = {
    "zh": {
        "skip_link": "跳到正文",
        "reader_navigation_label": "阅读导航",
        "outline_label": "文章目录",
        "lightbox_label": "大图查看器",
        "close_lightbox_label": "关闭大图",
        "zoom_controls_label": "图像缩放",
        "zoom_out_label": "缩小",
        "zoom_reset_label": "重置缩放",
        "zoom_in_label": "放大",
        "view_source_label": "查看原文 ↗",
        "placeholder": "[请用有证据锚点的高密度内容替换本段。]",
    },
    "en": {
        "skip_link": "Skip to report",
        "reader_navigation_label": "Reading navigation",
        "outline_label": "Report outline",
        "lightbox_label": "Enlarged visual viewer",
        "close_lightbox_label": "Close enlarged visual",
        "zoom_controls_label": "Image zoom",
        "zoom_out_label": "Zoom out",
        "zoom_reset_label": "Reset zoom",
        "zoom_in_label": "Zoom in",
        "view_source_label": "View source ↗",
        "placeholder": "[Replace this paragraph with dense, evidence-anchored content.]",
    },
}
BASIC_FACT_LABELS = {
    "zh": {
        "title": "标题",
        "authors": "作者",
        "contact": "通讯作者 / 论文联系人",
        "affiliation": "机构",
        "published": "发表信息",
        "link": "链接",
        "paper-type": "论文类型",
        "one-line-summary": "一句话总结",
    },
    "en": {
        "title": "Title",
        "authors": "Authors",
        "contact": "Corresponding author / paper contact",
        "affiliation": "Affiliation",
        "published": "Published",
        "link": "Link",
        "paper-type": "Paper Type",
        "one-line-summary": "One-line summary",
    },
}
MODULE_FIELD_LABELS = {
    "zh": {
        "module": "模块名称",
        "purpose": "职责",
        "inputs": "具体输入",
        "outputs": "具体输出",
        "architecture": "架构与关键参数",
        "training-data": "训练数据与监督",
        "training-method": "训练方法、目标与优化",
        "inference-role": "推理时角色",
        "interfaces": "与前后模块的接口",
        "code-evidence": "代码核查",
    },
    "en": {
        "module": "Module name",
        "purpose": "Purpose",
        "inputs": "Exact inputs",
        "outputs": "Exact outputs",
        "architecture": "Architecture and key parameters",
        "training-data": "Training data and supervision",
        "training-method": "Training method, objectives, and optimization",
        "inference-role": "Inference-time role",
        "interfaces": "Interfaces to adjacent modules",
        "code-evidence": "Code evidence",
    },
}
MODULE_DIAGRAM_COPY = {
    "zh": {
        "figure_label": "模块输入、变换与输出示意图，点击放大",
        "input_a": "输入 x₁",
        "input_b": "输入 x₂",
        "module": "核心变换",
        "output_a": "输出 y₁",
        "output_b": "输出 y₂",
        "caption": "请用论文与代码核实后的模块数据流替换此图。",
    },
    "en": {
        "figure_label": "Module inputs, transformation, and outputs; click to enlarge",
        "input_a": "Input x₁",
        "input_b": "Input x₂",
        "module": "Core transform",
        "output_a": "Output y₁",
        "output_b": "Output y₂",
        "caption": "Replace with the module flow verified from the paper and code.",
    },
}
TOKEN_RE = re.compile(r"\{\{[A-Z0-9_]+\}\}")


def _language_family(language: str) -> str:
    normalized = language.lower()
    if normalized.startswith("zh"):
        return "zh"
    if normalized.startswith("en"):
        return "en"
    raise ValueError("language must use a zh* or en* language tag")


def _validate_source_link(source: str) -> None:
    if not source:
        return
    parsed = urlsplit(source)
    if parsed.scheme.lower() not in {"", "http", "https"} or (
        parsed.netloc and not parsed.scheme
    ):
        raise ValueError("source URL must use http(s) or a relative local path")


def _section(
    *,
    number: str,
    section_name: str,
    heading: str,
    placeholder: str,
    coordinate: str | None = None,
    kind: str | None = None,
    supports: str = "",
    body_html: str | None = None,
) -> str:
    html_id = coordinate or section_name
    attributes = [
        f'id="{escape(html_id)}"',
        f'data-section="{escape(section_name)}"',
    ]
    if coordinate:
        attributes.append(f'data-coordinate="{escape(coordinate)}"')
    if kind:
        attributes.append(f'data-kind="{escape(kind)}"')
    if supports:
        attributes.append(f'data-supports="{escape(supports)}"')
    marker = coordinate or number
    body = body_html or f"<p>{escape(placeholder)}</p>"
    return f"""
        <section {" ".join(attributes)} class="argument-block">
          <div class="section-mark"><span>{escape(marker)}</span><small>{escape(section_name)}</small></div>
          <h2>{escape(heading)}</h2>
          {body}
        </section>"""


def _module_anatomy(locale: str, placeholder: str) -> str:
    labels = MODULE_FIELD_LABELS[locale]
    diagram = MODULE_DIAGRAM_COPY[locale]
    fields = (
        "purpose",
        "inputs",
        "outputs",
        "architecture",
        "training-data",
        "training-method",
        "inference-role",
        "interfaces",
        "code-evidence",
    )
    field_fragments: list[str] = []
    for field in fields:
        if field in {"inputs", "outputs"}:
            symbol = "x" if field == "inputs" else "y"
            content = f'''<ul class="module-io-list">
                  <li><span class="math-inline"><math xmlns="http://www.w3.org/1998/Math/MathML" display="inline"><semantics><msub><mi>{symbol}</mi><mn>1</mn></msub><annotation encoding="application/x-tex">{symbol}_1</annotation></semantics></math></span> {escape(placeholder)}</li>
                  <li><span class="math-inline"><math xmlns="http://www.w3.org/1998/Math/MathML" display="inline"><semantics><msub><mi>{symbol}</mi><mn>2</mn></msub><annotation encoding="application/x-tex">{symbol}_2</annotation></semantics></math></span> {escape(placeholder)}</li>
                </ul>'''
        else:
            content = f"<p>{escape(placeholder)}</p>"
        field_fragments.append(
            f'''              <div class="module-field" data-module-field="{field}">
                <h4>{escape(labels[field])}</h4>
                {content}
              </div>'''
        )
    field_html = "\n".join(field_fragments)
    return f'''<p>{escape(placeholder)}</p>
          <div class="module-anatomy" data-module-anatomy>
            <article class="module-card" data-module="replace-with-module-name">
              <h3>{escape(labels["module"])}</h3>
              <figure class="module-visual" data-module-visual data-lightbox tabindex="0" role="button" aria-label="{escape(diagram["figure_label"])}">
                <svg class="module-diagram" viewBox="0 0 960 240" role="img" aria-label="{escape(diagram["figure_label"])}">
                  <rect class="diagram-node diagram-input" x="24" y="32" width="180" height="64" rx="10"></rect>
                  <rect class="diagram-node diagram-input" x="24" y="144" width="180" height="64" rx="10"></rect>
                  <path class="diagram-arrow" d="M204 64 H302 V120 H370"></path>
                  <path class="diagram-arrow" d="M204 176 H302 V120"></path>
                  <path class="diagram-arrowhead" d="M370 120 l-11 -7 v14 z"></path>
                  <rect class="diagram-node diagram-core" x="370" y="70" width="220" height="100" rx="12"></rect>
                  <path class="diagram-arrow" d="M590 120 H674 V64 H756"></path>
                  <path class="diagram-arrow" d="M674 120 V176 H756"></path>
                  <path class="diagram-arrowhead" d="M756 64 l-11 -7 v14 z"></path>
                  <path class="diagram-arrowhead" d="M756 176 l-11 -7 v14 z"></path>
                  <rect class="diagram-node diagram-output" x="756" y="32" width="180" height="64" rx="10"></rect>
                  <rect class="diagram-node diagram-output" x="756" y="144" width="180" height="64" rx="10"></rect>
                  <text x="114" y="64">{escape(diagram["input_a"])}</text>
                  <text x="114" y="176">{escape(diagram["input_b"])}</text>
                  <text x="480" y="120">{escape(diagram["module"])}</text>
                  <text x="846" y="64">{escape(diagram["output_a"])}</text>
                  <text x="846" y="176">{escape(diagram["output_b"])}</text>
                </svg>
                <figcaption>{escape(diagram["caption"])}</figcaption>
              </figure>
{field_html}
            </article>
          </div>'''


def _basic_information_section(
    *,
    number: str,
    heading: str,
    locale: str,
    title: str,
    authors: str,
    paper_type: str,
    thesis: str,
    source: str,
    placeholder: str,
) -> str:
    labels = BASIC_FACT_LABELS[locale]
    source_value = (
        f'<a href="{escape(source, quote=True)}">{escape(source)}</a>'
        if source
        else escape(placeholder)
    )
    facts = (
        ("title", escape(title)),
        ("authors", escape(authors)),
        ("contact", escape(placeholder)),
        ("affiliation", escape(placeholder)),
        ("published", escape(placeholder)),
        ("link", source_value),
        ("paper-type", escape(paper_type)),
        ("one-line-summary", escape(thesis)),
    )
    items = "\n".join(
        f'            <li data-paper-field="{field}"><strong>{escape(labels[field])}:</strong> {value}</li>'
        for field, value in facts
    )
    return f"""
        <section id="basic-information" data-section="basic-information" class="argument-block">
          <div class="section-mark"><span>{escape(number)}</span><small>basic-information</small></div>
          <h2>{escape(heading)}</h2>
          <ul class="paper-facts" data-paper-facts>
{items}
          </ul>
        </section>"""


SectionSpec = tuple[str, str, str | None, str | None]


def _core_sections(headings: dict[str, str]) -> list[SectionSpec]:
    return [
        ("basic-information", headings["basic-information"], None, None),
        (
            "research-problem",
            headings["research-problem"],
            "C1",
            "claim",
        ),
        ("key-insight", headings["key-insight"], "C2", "claim"),
    ]


def _type_sections(paper_type: str, headings: dict[str, str]) -> list[SectionSpec]:
    return [
        (
            section_name,
            headings[section_name],
            coordinate,
            "evidence" if coordinate.startswith("E") else "claim",
        )
        for section_name, coordinate in TYPE_SECTIONS[paper_type]
    ]


def _report_sections(paper_type: str, headings: dict[str, str]) -> list[SectionSpec]:
    sections = _core_sections(headings)
    sections.extend(_type_sections(paper_type, headings))
    sections.append(
        (
            "critical-analysis",
            headings["critical-analysis"],
            "L1",
            "limitation",
        )
    )
    sections.append(("summary", headings["summary"], None, None))
    return sections


def _render_sections(
    *,
    paper_type: str,
    locale: str,
    title: str,
    authors: str,
    thesis: str,
    source: str,
) -> tuple[str, str]:
    section_html: list[str] = []
    outline_html: list[str] = []
    copy = UI_COPY[locale]
    for index, spec in enumerate(
        _report_sections(paper_type, SECTION_HEADINGS[locale]), start=1
    ):
        section_name, heading, coordinate, kind = spec
        section_id = coordinate or section_name
        supports = "E1" if kind in {"claim", "limitation"} else ""
        if section_name == "basic-information":
            section_html.append(
                _basic_information_section(
                    number=f"{index:02d}",
                    heading=heading,
                    locale=locale,
                    title=title,
                    authors=authors,
                    paper_type=paper_type,
                    thesis=thesis,
                    source=source,
                    placeholder=copy["placeholder"],
                )
            )
        else:
            section_html.append(
                _section(
                    number=f"{index:02d}",
                    section_name=section_name,
                    heading=heading,
                    placeholder=copy["placeholder"],
                    coordinate=coordinate,
                    kind=kind,
                    supports=supports,
                    body_html=(
                        _module_anatomy(locale, copy["placeholder"])
                        if paper_type in MODULE_PAPER_TYPES
                        and section_name in {"technical-method", "system-design"}
                        else None
                    ),
                )
            )
        outline_html.append(f'<a href="#{escape(section_id)}">{escape(heading)}</a>')
    return (
        "\n".join(section_html),
        "\n        ".join(outline_html),
    )


def _validate_inputs(
    *,
    paper_type: str,
    language: str,
    title: str,
    title_focus: str,
    authors: str,
    thesis: str,
    source: str,
) -> tuple[str, str, str]:
    if paper_type not in PAPER_TYPES:
        raise ValueError(f"unknown paper type: {paper_type}")
    if not language.strip():
        raise ValueError("language cannot be empty")
    _language_family(language)
    _validate_source_link(source)
    for field_name, value in (
        ("title", title),
        ("title focus", title_focus),
        ("authors", authors),
        ("thesis", thesis),
    ):
        if not value.strip():
            raise ValueError(f"{field_name} cannot be empty")
    if title.count(title_focus) != 1:
        raise ValueError("title focus must occur exactly once in the title")
    before, after = title.split(title_focus, maxsplit=1)
    return before, title_focus, after


def _template_replacements(
    *,
    language: str,
    locale: str,
    title: str,
    title_parts: tuple[str, str, str],
    authors: str,
    thesis: str,
    paper_type: str,
    source: str,
    sections: tuple[str, str],
    style: str,
    script: str,
) -> dict[str, str]:
    copy = UI_COPY[locale]
    report_sections, outline = sections
    title_before, title_focus, title_after = title_parts
    replacements = {
        f"{{{{{key.upper()}}}}}": escape(value)
        for key, value in copy.items()
        if key != "placeholder"
    }
    replacements.update(
        {
            "{{LANGUAGE}}": escape(language),
            "{{TITLE}}": escape(title),
            "{{TITLE_BEFORE}}": escape(title_before),
            "{{TITLE_FOCUS}}": escape(title_focus),
            "{{TITLE_AFTER}}": escape(title_after),
            "{{AUTHORS}}": escape(authors),
            "{{THESIS}}": escape(thesis),
            "{{PAPER_TYPE}}": escape(paper_type),
            "{{OUTLINE}}": outline,
            "{{REPORT_SECTIONS}}": report_sections,
            "{{REPORT_STYLE}}": style,
            "{{REPORT_SCRIPT}}": script,
        }
    )
    replacements.update(_optional_replacements(copy, source))
    return replacements


def _optional_replacements(copy: dict[str, str], source: str) -> dict[str, str]:
    return {
        "{{SOURCE_LINK}}": (
            f'<a class="nav-source" href="{escape(source, quote=True)}">'
            f"{escape(copy['view_source_label'])}</a>"
            if source
            else ""
        ),
    }


def _load_report_assets() -> tuple[str, str, str]:
    assets = Path(__file__).resolve().parent.parent / "assets"
    template = (assets / "report-template.html").read_text(encoding="utf-8")
    style = (assets / "report.css").read_text(encoding="utf-8")
    script = (assets / "report.js").read_text(encoding="utf-8")
    return template, style, script


def _write_report(output_dir: Path, html: str) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "assets").mkdir()
    summary_path = output_dir / "summary.html"
    summary_path.write_text(html, encoding="utf-8")
    return summary_path


def _apply_replacements(template: str, replacements: dict[str, str]) -> str:
    return TOKEN_RE.sub(
        lambda match: replacements.get(match.group(0), match.group(0)), template
    )


def scaffold_report(
    *,
    output_dir: Path,
    title: str,
    title_focus: str,
    authors: str,
    paper_type: str,
    thesis: str,
    language: str = "zh-CN",
    source: str = "",
) -> Path:
    """Write a report shell and return its summary path."""
    output_dir = Path(output_dir)
    title_parts = _validate_inputs(
        paper_type=paper_type,
        language=language,
        title=title,
        title_focus=title_focus,
        authors=authors,
        thesis=thesis,
        source=source,
    )
    if output_dir.exists() and any(output_dir.iterdir()):
        raise FileExistsError(f"output directory is not empty: {output_dir}")
    template, style, script = _load_report_assets()
    locale = _language_family(language)
    sections = _render_sections(
        paper_type=paper_type,
        locale=locale,
        title=title,
        authors=authors,
        thesis=thesis,
        source=source,
    )
    replacements = _template_replacements(
        language=language,
        locale=locale,
        title=title,
        title_parts=title_parts,
        authors=authors,
        thesis=thesis,
        paper_type=paper_type,
        source=source,
        sections=sections,
        style=style,
        script=script,
    )
    html = _apply_replacements(template, replacements)
    return _write_report(output_dir, html)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--title", required=True)
    parser.add_argument("--title-focus", required=True)
    parser.add_argument("--authors", required=True)
    parser.add_argument(
        "--paper-type", required=True, choices=tuple(sorted(PAPER_TYPES))
    )
    parser.add_argument("--thesis", required=True)
    parser.add_argument("--language", default="zh-CN")
    parser.add_argument("--source", default="")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        summary_path = scaffold_report(
            output_dir=args.output_dir,
            title=args.title,
            title_focus=args.title_focus,
            authors=args.authors,
            paper_type=args.paper_type,
            thesis=args.thesis,
            language=args.language,
            source=args.source,
        )
    except (FileExistsError, OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    print(summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
