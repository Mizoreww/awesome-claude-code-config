#!/usr/bin/env python3
"""Create a portable paper-reading HTML report shell."""

from __future__ import annotations

import argparse
from html import escape
from pathlib import Path
import sys


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
        ("technical-method", "技术方法", "C3", "method"),
        ("experimental-results", "实验结果", "E1", "evidence"),
    ),
    "theoretical": (
        ("theoretical-framework", "理论框架", "C3", "method"),
        ("theoretical-analysis", "定理与论证", "E1", "evidence"),
    ),
    "survey": (
        ("taxonomy", "分类框架", "C3", "method"),
        ("open-problems", "开放问题与趋势", "E1", "evidence"),
    ),
    "systems": (
        ("system-design", "系统设计", "C3", "method"),
        ("performance-evaluation", "性能评估", "E1", "evidence"),
    ),
}


def _section(
    *,
    number: str,
    section_name: str,
    heading: str,
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
          <p>[请用有证据锚点的高密度内容替换本段。]</p>
        </section>"""


def _report_sections(
    paper_type: str, level: str
) -> list[tuple[str, str, str | None, str | None, str]]:
    sections: list[tuple[str, str, str | None, str | None, str]] = [
        ("basic-information", "基本信息", None, None, "method evidence"),
        ("research-problem", "研究问题", "C1", "claim", "method critique"),
        ("key-insight", "关键洞见", "C2", "claim", "method"),
    ]
    if level == "brief":
        sections.append(
            ("headline-evidence", "决定性证据", "E1", "evidence", "evidence")
        )
    else:
        for section_name, heading, coordinate, lens in TYPE_SECTIONS[paper_type]:
            kind = "evidence" if coordinate.startswith("E") else "claim"
            sections.append((section_name, heading, coordinate, kind, lens))
    sections.append(("critical-analysis", "批判分析", "L1", "limitation", "critique"))
    if level == "deep":
        sections.append(
            ("reproduction", "最小复现", "R1", "reproduction", "reproduction")
        )
    sections.append(("summary", "总结与评价", None, None, "method evidence critique"))
    return sections


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
    if paper_type not in PAPER_TYPE_LABELS:
        raise ValueError(f"unknown paper type: {paper_type}")
    if level not in LEVEL_LABELS:
        raise ValueError(f"unknown reading level: {level}")
    cleaned_fingerprints = [item.strip() for item in fingerprints if item.strip()]
    if len(cleaned_fingerprints) < 2:
        raise ValueError("fingerprint needs at least two verified paper concepts")
    for field_name, value in (
        ("title", title),
        ("authors", authors),
        ("thesis", thesis),
    ):
        if not value.strip():
            raise ValueError(f"{field_name} cannot be empty")
    if output_dir.exists() and any(output_dir.iterdir()):
        raise FileExistsError(f"output directory is not empty: {output_dir}")

    assets_source = Path(__file__).resolve().parent.parent / "assets"
    template = (assets_source / "report-template.html").read_text(encoding="utf-8")
    style = (assets_source / "report.css").read_text(encoding="utf-8")
    script = (assets_source / "report.js").read_text(encoding="utf-8")

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "assets").mkdir()
    if level == "deep":
        (output_dir / "reproduction").mkdir()

    section_specs = _report_sections(paper_type, level)
    section_html: list[str] = []
    outline_html: list[str] = []
    evidence_html: list[str] = []
    for index, (section_name, heading, coordinate, kind, lenses) in enumerate(
        section_specs, start=1
    ):
        section_id = coordinate or section_name
        supports = "E1" if kind in {"claim", "limitation"} else ""
        section_html.append(
            _section(
                number=f"{index:02d}",
                section_name=section_name,
                heading=heading,
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

    replacements = {
        "{{LANGUAGE}}": escape(language),
        "{{TITLE}}": escape(title),
        "{{AUTHORS}}": escape(authors),
        "{{THESIS}}": escape(thesis),
        "{{LEVEL}}": escape(level),
        "{{LEVEL_LABEL}}": LEVEL_LABELS[level],
        "{{PAPER_TYPE}}": escape(paper_type),
        "{{PAPER_TYPE_LABEL}}": PAPER_TYPE_LABELS[paper_type],
        "{{SOURCE_LINK}}": f'<a href="{escape(source, quote=True)}">查看原文 ↗</a>'
        if source
        else "",
        "{{FINGERPRINTS}}": "".join(
            f"<span>{escape(item)}</span>" for item in cleaned_fingerprints[:5]
        ),
        "{{REPRODUCTION_LENS}}": '<button type="button" data-lens="reproduction">复现</button>'
        if level == "deep"
        else "",
        "{{REPRODUCTION_KEY}}": '<span><i class="reproduction-dot"></i>复现 R</span>'
        if level == "deep"
        else "",
        "{{OUTLINE}}": "\n        ".join(outline_html),
        "{{REPORT_SECTIONS}}": "\n".join(section_html),
        "{{EVIDENCE_RAIL}}": "\n        ".join(evidence_html),
        "{{REPORT_STYLE}}": style,
        "{{REPORT_SCRIPT}}": script,
    }
    html = template
    for token, value in replacements.items():
        html = html.replace(token, value)

    summary_path = output_dir / "summary.html"
    summary_path.write_text(html, encoding="utf-8")
    return summary_path


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
