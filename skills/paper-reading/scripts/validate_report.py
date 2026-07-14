#!/usr/bin/env python3
"""Validate a portable paper-reading HTML report."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


COORDINATE_RE = re.compile(r"^[CELR][1-9][0-9]*$")
COMMIT_RE = re.compile(r"^[0-9a-fA-F]{7,64}$")
REMOTE_ASSET_RE = re.compile(r"^(?:https?:)?//", re.IGNORECASE)
PLACEHOLDER_RE = re.compile(
    r"\{\{[A-Z0-9_]+\}\}|\[请用有证据锚点的高密度内容替换本段。\]"
)
KIND_PREFIX = {"claim": "C", "evidence": "E", "limitation": "L", "reproduction": "R"}
COMMON_SECTIONS = {
    "basic-information",
    "research-problem",
    "key-insight",
    "critical-analysis",
    "summary",
}
TYPE_SECTIONS = {
    "empirical": {"technical-method", "experimental-results"},
    "theoretical": {"theoretical-framework", "theoretical-analysis"},
    "survey": {"taxonomy", "open-problems"},
    "systems": {"system-design", "performance-evaluation"},
}


@dataclass
class ElementRecord:
    tag: str
    attrs: dict[str, str | None]
    line: int


@dataclass
class VisualRecord:
    attrs: dict[str, str | None]
    line: int
    contains_visual: bool = False


@dataclass
class ReportDocument:
    ids: dict[str, list[int]] = field(default_factory=dict)
    anchors: list[tuple[str, int]] = field(default_factory=list)
    assets: list[tuple[str, str, int]] = field(default_factory=list)
    sections: list[ElementRecord] = field(default_factory=list)
    coordinates: list[ElementRecord] = field(default_factory=list)
    figures: list[VisualRecord] = field(default_factory=list)
    images: list[ElementRecord] = field(default_factory=list)
    svgs: list[ElementRecord] = field(default_factory=list)
    articles: list[ElementRecord] = field(default_factory=list)
    headers: list[ElementRecord] = field(default_factory=list)
    navs: list[ElementRecord] = field(default_factory=list)
    mains: list[ElementRecord] = field(default_factory=list)
    asides: list[ElementRecord] = field(default_factory=list)
    dialogs: list[ElementRecord] = field(default_factory=list)
    metas: list[ElementRecord] = field(default_factory=list)
    links: list[ElementRecord] = field(default_factory=list)
    scripts: list[ElementRecord] = field(default_factory=list)
    styles: list[ElementRecord] = field(default_factory=list)
    title_count: int = 0


class ReportParser(HTMLParser):
    """Collect only the DOM facts needed by the report contract."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.document = ReportDocument()
        self._figure_stack: list[int] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        line = self.getpos()[0]
        record = ElementRecord(tag=tag, attrs=attributes, line=line)
        identifier = attributes.get("id")
        if identifier:
            self.document.ids.setdefault(identifier, []).append(line)

        if tag == "article":
            self.document.articles.append(record)
        elif tag == "header":
            self.document.headers.append(record)
        elif tag == "nav":
            self.document.navs.append(record)
        elif tag == "main":
            self.document.mains.append(record)
        elif tag == "aside":
            self.document.asides.append(record)
        elif tag == "dialog":
            self.document.dialogs.append(record)
        elif tag == "meta":
            self.document.metas.append(record)
        elif tag == "link":
            self.document.links.append(record)
        elif tag == "script":
            self.document.scripts.append(record)
        elif tag == "style":
            self.document.styles.append(record)
        elif tag == "title":
            self.document.title_count += 1
        elif tag == "section":
            self.document.sections.append(record)

        coordinate = attributes.get("data-coordinate")
        if coordinate:
            self.document.coordinates.append(record)

        if tag == "a":
            href = attributes.get("href") or ""
            if href.startswith("#") and len(href) > 1:
                self.document.anchors.append((href[1:], line))

        if tag == "figure":
            self.document.figures.append(VisualRecord(attrs=attributes, line=line))
            self._figure_stack.append(len(self.document.figures) - 1)
        elif tag in {"img", "svg"}:
            if self._figure_stack:
                self.document.figures[self._figure_stack[-1]].contains_visual = True
            if tag == "img":
                self.document.images.append(record)
            else:
                self.document.svgs.append(record)

        asset_attribute = {
            "img": "src",
            "source": "src",
            "video": "src",
            "audio": "src",
            "object": "data",
        }.get(tag)
        if asset_attribute and attributes.get(asset_attribute):
            self.document.assets.append((attributes[asset_attribute] or "", tag, line))
        if tag == "video" and attributes.get("poster"):
            self.document.assets.append(
                (attributes["poster"] or "", "video poster", line)
            )

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag == "figure" and self._figure_stack:
            self._figure_stack.pop()

    def handle_endtag(self, tag: str) -> None:
        if tag == "figure" and self._figure_stack:
            self._figure_stack.pop()


def _classes(record: ElementRecord) -> set[str]:
    return set((record.attrs.get("class") or "").split())


def _has_landmark(records: list[ElementRecord], **attributes: str) -> bool:
    return any(
        all(record.attrs.get(key) == value for key, value in attributes.items())
        for record in records
    )


def _inside_report(path: Path, report_root: Path) -> bool:
    try:
        path.relative_to(report_root)
    except ValueError:
        return False
    return True


def _validate_manifest(report_path: Path, known_coordinates: set[str]) -> list[str]:
    errors: list[str] = []
    manifest_path = report_path.parent / "reproduction" / "manifest.json"
    if not manifest_path.is_file():
        return ["deep report requires reproduction/manifest.json"]
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"reproduction/manifest.json is not valid JSON: {exc}"]
    if not isinstance(manifest, dict):
        return ["reproduction/manifest.json must contain a JSON object"]

    status = manifest.get("status")
    if status not in {"passed", "partial", "blocked"}:
        errors.append(
            "reproduction manifest status must be passed, partial, or blocked"
        )
    claim = manifest.get("claim")
    if (
        not isinstance(claim, str)
        or claim not in known_coordinates
        or not claim.startswith("C")
    ):
        errors.append(
            "reproduction manifest claim must reference a report C-coordinate"
        )
    if (
        not isinstance(manifest.get("environment"), str)
        or not manifest["environment"].strip()
    ):
        errors.append("reproduction manifest requires a non-empty environment")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or not all(
        isinstance(item, str) and item for item in artifacts
    ):
        errors.append("reproduction manifest artifacts must be a list of local paths")
    else:
        reproduction_root = manifest_path.parent.resolve()
        for item in artifacts:
            artifact = (manifest_path.parent / item).resolve()
            if (
                not _inside_report(artifact, reproduction_root)
                or not artifact.is_file()
            ):
                errors.append(
                    f"reproduction artifact is missing or escapes its directory: {item}"
                )

    if status in {"passed", "partial"}:
        for field_name in ("repository", "command", "result"):
            value = manifest.get(field_name)
            if not isinstance(value, str) or not value.strip():
                errors.append(
                    f"reproduction manifest requires a non-empty {field_name}"
                )
        commit = manifest.get("commit")
        if not isinstance(commit, str) or not COMMIT_RE.fullmatch(commit):
            errors.append(
                "reproduction manifest commit must be a 7-64 digit hexadecimal revision"
            )
    elif status == "blocked":
        if (
            not isinstance(manifest.get("blocker"), str)
            or not manifest["blocker"].strip()
        ):
            errors.append("blocked reproduction manifest requires a concrete blocker")
        audited = manifest.get("audited_sources")
        if not isinstance(audited, list) or not audited:
            errors.append("blocked reproduction manifest requires audited_sources")
    return errors


def validate_report(report_path: Path) -> list[str]:
    """Return contract violations for one summary.html file."""
    report_path = Path(report_path)
    if not report_path.is_file():
        return [f"report does not exist: {report_path}"]
    try:
        source = report_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return [f"report is not readable UTF-8: {exc}"]

    parser = ReportParser()
    try:
        parser.feed(source)
        parser.close()
    except Exception as exc:  # HTMLParser can surface malformed entity errors.
        return [f"report HTML could not be parsed: {exc}"]
    document = parser.document
    errors: list[str] = []

    if not source.lstrip().lower().startswith("<!doctype html>"):
        errors.append("report must begin with <!doctype html>")
    if PLACEHOLDER_RE.search(source):
        errors.append("report still contains scaffold placeholders")
    if not document.title_count:
        errors.append("report requires a <title>")
    if not any(
        (record.attrs.get("charset") or "").lower() == "utf-8"
        for record in document.metas
    ):
        errors.append('report requires <meta charset="utf-8">')
    if not any(
        (record.attrs.get("name") or "").lower() == "viewport"
        for record in document.metas
    ):
        errors.append("report requires a viewport meta tag")
    if not document.styles:
        errors.append("report requires inline CSS")
    if not document.scripts:
        errors.append("report requires inline progressive-enhancement JavaScript")
    for script in document.scripts:
        if script.attrs.get("src"):
            errors.append(
                f"line {script.line}: external script dependencies are not portable"
            )
    for link in document.links:
        if "stylesheet" in (link.attrs.get("rel") or "").lower().split():
            errors.append(f"line {link.line}: stylesheet must be inlined")
    if re.search(r"@import\s|url\(\s*['\"]?(?:https?:)?//", source, re.IGNORECASE):
        errors.append("CSS contains a network dependency")

    report_articles = [
        record for record in document.articles if "data-paper-report" in record.attrs
    ]
    if len(report_articles) != 1:
        errors.append("report requires exactly one <article data-paper-report>")
        article = None
        level = ""
        paper_type = ""
    else:
        article = report_articles[0]
        level = article.attrs.get("data-level") or ""
        paper_type = article.attrs.get("data-paper-type") or ""
        if level not in {"brief", "compact", "deep"}:
            errors.append("data-level must be brief, compact, or deep")
        if paper_type not in TYPE_SECTIONS:
            errors.append(
                "data-paper-type must be empirical, theoretical, survey, or systems"
            )

    if not any("report-hero" in _classes(record) for record in document.headers):
        errors.append("report requires a header.report-hero")
    if not document.navs:
        errors.append("report requires a navigation landmark")
    elif not any(record.attrs.get("aria-label") for record in document.navs):
        errors.append("report navigation requires an aria-label")
    if not _has_landmark(document.mains, id="report-content"):
        errors.append('report requires <main id="report-content">')
    if not any(record.attrs.get("aria-label") for record in document.asides):
        errors.append("report requires an aria-labelled evidence index")
    if not _has_landmark(document.dialogs, id="lightbox"):
        errors.append('report requires <dialog id="lightbox">')

    for identifier, lines in sorted(document.ids.items()):
        if len(lines) > 1:
            errors.append(
                f"duplicate id {identifier!r} on lines {', '.join(map(str, lines))}"
            )
    for target, line in document.anchors:
        if target not in document.ids:
            errors.append(f"line {line}: local anchor target does not exist: #{target}")

    report_root = report_path.parent.resolve()
    for asset_value, tag, line in document.assets:
        if asset_value.startswith("data:"):
            continue
        if REMOTE_ASSET_RE.match(asset_value):
            errors.append(f"line {line}: {tag} uses a network asset: {asset_value}")
            continue
        asset_path = unquote(urlsplit(asset_value).path)
        resolved = (report_path.parent / asset_path).resolve()
        if not _inside_report(resolved, report_root):
            errors.append(
                f"line {line}: asset escapes the report directory: {asset_value}"
            )
        elif not resolved.is_file():
            errors.append(f"line {line}: local asset does not exist: {asset_value}")

    for image in document.images:
        if not (image.attrs.get("alt") or "").strip():
            errors.append(f"line {image.line}: image requires non-empty alt text")
    for svg in document.svgs:
        if (
            svg.attrs.get("role") != "img"
            or not (svg.attrs.get("aria-label") or "").strip()
        ):
            errors.append(
                f'line {svg.line}: inline SVG requires role="img" and an aria-label'
            )
    for figure in document.figures:
        if not figure.contains_visual:
            continue
        if "data-lightbox" not in figure.attrs:
            errors.append(
                f"line {figure.line}: every visual figure requires data-lightbox"
            )
        if figure.attrs.get("tabindex") != "0":
            errors.append(f'line {figure.line}: lightbox trigger requires tabindex="0"')
        if figure.attrs.get("role") != "button":
            errors.append(
                f'line {figure.line}: lightbox trigger requires role="button"'
            )
        if not (figure.attrs.get("aria-label") or "").strip():
            errors.append(
                f"line {figure.line}: lightbox trigger requires an aria-label"
            )

    known_coordinates: set[str] = set()
    for record in document.coordinates:
        coordinate = record.attrs.get("data-coordinate") or ""
        if not COORDINATE_RE.fullmatch(coordinate):
            errors.append(
                f"line {record.line}: malformed evidence coordinate: {coordinate!r}"
            )
            continue
        if coordinate in known_coordinates:
            errors.append(f"duplicate evidence coordinate: {coordinate}")
        known_coordinates.add(coordinate)
        if record.attrs.get("id") != coordinate:
            errors.append(
                f"line {record.line}: coordinate {coordinate} must also be the element id"
            )
        kind = record.attrs.get("data-kind") or ""
        if kind not in KIND_PREFIX or not coordinate.startswith(
            KIND_PREFIX.get(kind, "?")
        ):
            errors.append(
                f"line {record.line}: {coordinate} does not match data-kind={kind!r}"
            )
        supports = (record.attrs.get("data-supports") or "").split()
        if kind in {"claim", "limitation"} and not supports:
            errors.append(
                f"line {record.line}: {coordinate} requires data-supports evidence links"
            )

    for record in document.coordinates:
        for support in (record.attrs.get("data-supports") or "").split():
            if support not in known_coordinates:
                errors.append(
                    f"line {record.line}: data-supports target does not exist: {support}"
                )

    required_prefixes = {"C", "E", "L"}
    present_prefixes = {coordinate[0] for coordinate in known_coordinates if coordinate}
    for prefix in sorted(required_prefixes - present_prefixes):
        errors.append(f"report requires at least one {prefix}-coordinate")

    section_names = {record.attrs.get("data-section") for record in document.sections}
    for section_name in sorted(COMMON_SECTIONS - section_names):
        errors.append(f"report is missing required section: {section_name}")
    if level == "brief" and "headline-evidence" not in section_names:
        errors.append("brief report requires a headline-evidence section")
    if level in {"compact", "deep"} and paper_type in TYPE_SECTIONS:
        for section_name in sorted(TYPE_SECTIONS[paper_type] - section_names):
            errors.append(
                f"{paper_type} {level} report is missing section: {section_name}"
            )
    if level == "deep":
        if "reproduction" not in section_names or "R" not in present_prefixes:
            errors.append(
                "deep report requires a reproduction section with an R-coordinate"
            )
        errors.extend(_validate_manifest(report_path, known_coordinates))

    return errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="Path to summary.html")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if not args.report.is_file():
        print(f"error: report does not exist: {args.report}", file=sys.stderr)
        return 2
    errors = validate_report(args.report)
    if errors:
        print(f"FAIL {args.report} ({len(errors)} issue(s))")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"PASS {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
