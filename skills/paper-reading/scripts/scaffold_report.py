#!/usr/bin/env python3
"""Create a portable paper-reading HTML report shell."""

from __future__ import annotations

import argparse
import sys
from html import escape
from pathlib import Path
from urllib.parse import urlsplit

LEVEL_LABELS = {
    "brief": "Brief",
    "compact": "Compact close-reading",
    "deep": "Deep reproduction",
}
PAPER_TYPE_LABELS = {
    "empirical": "Empirical paper",
    "theoretical": "Theoretical paper",
    "survey": "Survey paper",
    "systems": "Systems paper",
}
TYPE_SECTIONS = {
    "empirical": (
        ("technical-method", "C3", "method"),
        ("experimental-results", "E1", "evidence"),
    ),
    "theoretical": (
        ("theoretical-framework", "C3", "method"),
        ("theoretical-analysis", "E1", "evidence"),
    ),
    "survey": (
        ("taxonomy", "C3", "method"),
        ("open-problems", "E1", "evidence"),
    ),
    "systems": (
        ("system-design", "C3", "method"),
        ("performance-evaluation", "E1", "evidence"),
    ),
}
SECTION_HEADINGS = {
    "zh": {
        "basic-information": "基本信息",
        "research-problem": "研究问题",
        "key-insight": "关键洞见",
        "headline-evidence": "决定性证据",
        "technical-method": "技术方法",
        "experimental-results": "实验结果",
        "theoretical-framework": "理论框架",
        "theoretical-analysis": "定理与论证",
        "taxonomy": "分类框架",
        "open-problems": "开放问题与趋势",
        "system-design": "系统设计",
        "performance-evaluation": "性能评估",
        "critical-analysis": "批判分析",
        "reproduction": "最小复现",
        "summary": "总结与评价",
    },
    "en": {
        "basic-information": "Basic information",
        "research-problem": "Research problem",
        "key-insight": "Key insight",
        "headline-evidence": "Decisive evidence",
        "technical-method": "Technical method",
        "experimental-results": "Experimental results",
        "theoretical-framework": "Theoretical framework",
        "theoretical-analysis": "Theorems and argument",
        "taxonomy": "Taxonomy",
        "open-problems": "Open problems and trends",
        "system-design": "System design",
        "performance-evaluation": "Performance evaluation",
        "critical-analysis": "Critical analysis",
        "reproduction": "Minimal reproduction",
        "summary": "Summary and assessment",
    },
}
UI_COPY = {
    "zh": {
        "skip_link": "跳到正文",
        "fingerprint_label": "本文概念指纹",
        "reading_lenses_label": "阅读视角",
        "all_label": "全部",
        "method_label": "方法",
        "evidence_label": "证据",
        "critique_label": "批判",
        "reproduction_label": "复现",
        "outline_label": "文章目录",
        "argument_map_label": "论证地图",
        "coordinate_key_label": "坐标图例",
        "claim_key": "主张 C",
        "evidence_key": "证据 E",
        "limitation_key": "限制 L",
        "reproduction_key": "复现 R",
        "evidence_index_label": "证据索引",
        "evidence_rail_label": "证据",
        "lightbox_label": "大图查看器",
        "close_lightbox_label": "关闭大图",
        "view_source_label": "查看原文 ↗",
        "placeholder": "[请用有证据锚点的高密度内容替换本段。]",
    },
    "en": {
        "skip_link": "Skip to report",
        "fingerprint_label": "Paper concept fingerprint",
        "reading_lenses_label": "Reading lenses",
        "all_label": "All",
        "method_label": "Method",
        "evidence_label": "Evidence",
        "critique_label": "Critique",
        "reproduction_label": "Reproduction",
        "outline_label": "Report outline",
        "argument_map_label": "Argument map",
        "coordinate_key_label": "Coordinate key",
        "claim_key": "Claim C",
        "evidence_key": "Evidence E",
        "limitation_key": "Limitation L",
        "reproduction_key": "Reproduction R",
        "evidence_index_label": "Evidence index",
        "evidence_rail_label": "Evidence",
        "lightbox_label": "Enlarged visual viewer",
        "close_lightbox_label": "Close enlarged visual",
        "view_source_label": "View source ↗",
        "placeholder": "[Replace this paragraph with dense, evidence-anchored content.]",
    },
}


def _language_family(language: str) -> str:
    return "zh" if language.lower().startswith("zh") else "en"


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
    lenses: str = "",
    supports: str = "",
) -> str:
    html_id = coordinate or section_name
    attributes = [
        f'id="{escape(html_id)}"',
        f'data-section="{escape(section_name)}"',
        f'data-lenses="{escape(lenses)}"',
    ]
    if coordinate:
        attributes.append(f'data-coordinate="{escape(coordinate)}"')
    if kind:
        attributes.append(f'data-kind="{escape(kind)}"')
    if supports:
        attributes.append(f'data-supports="{escape(supports)}"')
    marker = coordinate or number
    return f"""
        <section {" ".join(attributes)} class="argument-block">
          <div class="section-mark"><span>{escape(marker)}</span><small>{escape(section_name)}</small></div>
          <h2>{escape(heading)}</h2>
          <p>{escape(placeholder)}</p>
        </section>"""


SectionSpec = tuple[str, str, str | None, str | None, str]


def _core_sections(headings: dict[str, str]) -> list[SectionSpec]:
    return [
        (
            "basic-information",
            headings["basic-information"],
            None,
            None,
            "method evidence",
        ),
        (
            "research-problem",
            headings["research-problem"],
            "C1",
            "claim",
            "method critique",
        ),
        ("key-insight", headings["key-insight"], "C2", "claim", "method"),
    ]


def _evidence_sections(
    paper_type: str, level: str, headings: dict[str, str]
) -> list[SectionSpec]:
    if level == "brief":
        return [
            (
                "headline-evidence",
                headings["headline-evidence"],
                "E1",
                "evidence",
                "evidence",
            )
        ]
    return [
        (
            section_name,
            headings[section_name],
            coordinate,
            "evidence" if coordinate.startswith("E") else "claim",
            lens,
        )
        for section_name, coordinate, lens in TYPE_SECTIONS[paper_type]
    ]


def _report_sections(
    paper_type: str, level: str, headings: dict[str, str]
) -> list[SectionSpec]:
    sections = _core_sections(headings)
    sections.extend(_evidence_sections(paper_type, level, headings))
    sections.append(
        (
            "critical-analysis",
            headings["critical-analysis"],
            "L1",
            "limitation",
            "critique",
        )
    )
    if level == "deep":
        sections.append(
            (
                "reproduction",
                headings["reproduction"],
                "R1",
                "reproduction",
                "reproduction",
            )
        )
    sections.append(
        ("summary", headings["summary"], None, None, "method evidence critique")
    )
    return sections


def _render_sections(paper_type: str, level: str, locale: str) -> tuple[str, str, str]:
    section_html: list[str] = []
    outline_html: list[str] = []
    evidence_html: list[str] = []
    copy = UI_COPY[locale]
    for index, spec in enumerate(
        _report_sections(paper_type, level, SECTION_HEADINGS[locale]), start=1
    ):
        section_name, heading, coordinate, kind, lenses = spec
        section_id = coordinate or section_name
        supports = "E1" if kind in {"claim", "limitation"} else ""
        section_html.append(
            _section(
                number=f"{index:02d}",
                section_name=section_name,
                heading=heading,
                placeholder=copy["placeholder"],
                coordinate=coordinate,
                kind=kind,
                lenses=lenses,
                supports=supports,
            )
        )
        outline_html.append(f'<a href="#{escape(section_id)}">{escape(heading)}</a>')
        if coordinate and kind:
            evidence_html.append(
                f'<a class="rail-item" data-kind="{escape(kind)}" data-trace="{escape(coordinate)}" '
                f'href="#{escape(coordinate)}"><b>{escape(coordinate)}</b><span>{escape(heading)}</span></a>'
            )
    return (
        "\n".join(section_html),
        "\n        ".join(outline_html),
        "\n        ".join(evidence_html),
    )


def _validate_inputs(
    *,
    paper_type: str,
    level: str,
    language: str,
    title: str,
    authors: str,
    thesis: str,
    fingerprints: list[str],
    source: str,
) -> list[str]:
    if paper_type not in PAPER_TYPE_LABELS:
        raise ValueError(f"unknown paper type: {paper_type}")
    if level not in LEVEL_LABELS:
        raise ValueError(f"unknown reading level: {level}")
    if not language.strip():
        raise ValueError("language cannot be empty")
    _validate_source_link(source)
    cleaned = [item.strip() for item in fingerprints if item.strip()]
    if len(cleaned) < 2:
        raise ValueError("fingerprint needs at least two verified paper concepts")
    for field_name, value in (
        ("title", title),
        ("authors", authors),
        ("thesis", thesis),
    ):
        if not value.strip():
            raise ValueError(f"{field_name} cannot be empty")
    return cleaned


def _template_replacements(
    *,
    language: str,
    locale: str,
    title: str,
    authors: str,
    thesis: str,
    paper_type: str,
    level: str,
    source: str,
    fingerprints: list[str],
    sections: tuple[str, str, str],
    style: str,
    script: str,
) -> dict[str, str]:
    copy = UI_COPY[locale]
    report_sections, outline, evidence_rail = sections
    replacements = {
        f"{{{{{key.upper()}}}}}": escape(value)
        for key, value in copy.items()
        if key != "placeholder"
    }
    replacements.update(
        {
            "{{LANGUAGE}}": escape(language),
            "{{TITLE}}": escape(title),
            "{{AUTHORS}}": escape(authors),
            "{{THESIS}}": escape(thesis),
            "{{LEVEL}}": escape(level),
            "{{LEVEL_LABEL}}": LEVEL_LABELS[level],
            "{{PAPER_TYPE}}": escape(paper_type),
            "{{PAPER_TYPE_LABEL}}": PAPER_TYPE_LABELS[paper_type],
            "{{OUTLINE}}": outline,
            "{{REPORT_SECTIONS}}": report_sections,
            "{{EVIDENCE_RAIL}}": evidence_rail,
            "{{REPORT_STYLE}}": style,
            "{{REPORT_SCRIPT}}": script,
        }
    )
    replacements.update(_optional_replacements(copy, level, source, fingerprints))
    return replacements


def _optional_replacements(
    copy: dict[str, str], level: str, source: str, fingerprints: list[str]
) -> dict[str, str]:
    deep = level == "deep"
    return {
        "{{SOURCE_LINK}}": (
            f'<a href="{escape(source, quote=True)}">{escape(copy["view_source_label"])}</a>'
            if source
            else ""
        ),
        "{{FINGERPRINTS}}": "".join(
            f"<span>{escape(item)}</span>" for item in fingerprints[:5]
        ),
        "{{REPRODUCTION_LENS}}": (
            f'<button type="button" data-lens="reproduction">{escape(copy["reproduction_label"])}</button>'
            if deep
            else ""
        ),
        "{{REPRODUCTION_KEY}}": (
            f'<span><i class="reproduction-dot"></i>{escape(copy["reproduction_key"])}</span>'
            if deep
            else ""
        ),
    }


def _load_report_assets() -> tuple[str, str, str]:
    assets = Path(__file__).resolve().parent.parent / "assets"
    template = (assets / "report-template.html").read_text(encoding="utf-8")
    style = (assets / "report.css").read_text(encoding="utf-8")
    script = (assets / "report.js").read_text(encoding="utf-8")
    return template, style, script


def _write_report(output_dir: Path, level: str, html: str) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "assets").mkdir()
    if level == "deep":
        (output_dir / "reproduction").mkdir()
    summary_path = output_dir / "summary.html"
    summary_path.write_text(html, encoding="utf-8")
    return summary_path


def scaffold_report(
    *,
    output_dir: Path,
    title: str,
    authors: str,
    paper_type: str,
    level: str,
    thesis: str,
    fingerprints: list[str],
    language: str = "zh-CN",
    source: str = "",
) -> Path:
    """Write a report shell and return its summary path."""
    output_dir = Path(output_dir)
    cleaned = _validate_inputs(
        paper_type=paper_type,
        level=level,
        language=language,
        title=title,
        authors=authors,
        thesis=thesis,
        fingerprints=fingerprints,
        source=source,
    )
    if output_dir.exists() and any(output_dir.iterdir()):
        raise FileExistsError(f"output directory is not empty: {output_dir}")
    template, style, script = _load_report_assets()
    locale = _language_family(language)
    sections = _render_sections(paper_type, level, locale)
    replacements = _template_replacements(
        language=language,
        locale=locale,
        title=title,
        authors=authors,
        thesis=thesis,
        paper_type=paper_type,
        level=level,
        source=source,
        fingerprints=cleaned,
        sections=sections,
        style=style,
        script=script,
    )
    for token, value in replacements.items():
        template = template.replace(token, value)
    return _write_report(output_dir, level, template)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--title", required=True)
    parser.add_argument("--authors", required=True)
    parser.add_argument("--paper-type", required=True, choices=tuple(PAPER_TYPE_LABELS))
    parser.add_argument("--level", required=True, choices=tuple(LEVEL_LABELS))
    parser.add_argument("--thesis", required=True)
    parser.add_argument(
        "--fingerprint", action="append", required=True, dest="fingerprints"
    )
    parser.add_argument("--language", default="zh-CN")
    parser.add_argument("--source", default="")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        summary_path = scaffold_report(
            output_dir=args.output_dir,
            title=args.title,
            authors=args.authors,
            paper_type=args.paper_type,
            level=args.level,
            thesis=args.thesis,
            fingerprints=args.fingerprints,
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
