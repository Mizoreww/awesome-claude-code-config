#!/usr/bin/env python3
"""Validate a portable paper-reading HTML report."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

COORDINATE_RE = re.compile(r"^[CELR][1-9][0-9]*$")
COMMIT_RE = re.compile(r"^[0-9a-fA-F]{7,64}$")
REMOTE_ASSET_RE = re.compile(r"^(?:https?:)?//", re.IGNORECASE)
REMOTE_REFERENCE_RE = re.compile(r"(?:https?:)?//", re.IGNORECASE)
PLACEHOLDER_RE = re.compile(
    r"\{\{[A-Z0-9_]+\}\}|"
    r"\[请用有证据锚点的高密度内容替换本段。\]|"
    r"\[Replace this paragraph with dense, evidence-anchored content\.\]"
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
    hyperlinks: list[tuple[str, int]] = field(default_factory=list)
    assets: list[tuple[str, str, int]] = field(default_factory=list)
    srcsets: list[tuple[str, str, int]] = field(default_factory=list)
    unwrapped_visuals: list[ElementRecord] = field(default_factory=list)
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

    def _record_structure(self, record: ElementRecord) -> None:
        collection = {
            "article": self.document.articles,
            "header": self.document.headers,
            "nav": self.document.navs,
            "main": self.document.mains,
            "aside": self.document.asides,
            "dialog": self.document.dialogs,
            "meta": self.document.metas,
            "link": self.document.links,
            "script": self.document.scripts,
            "style": self.document.styles,
            "section": self.document.sections,
        }.get(record.tag)
        if collection is not None:
            collection.append(record)
        elif record.tag == "title":
            self.document.title_count += 1

    def _record_visual(self, record: ElementRecord) -> None:
        if record.tag == "figure":
            self.document.figures.append(VisualRecord(record.attrs, record.line))
            self._figure_stack.append(len(self.document.figures) - 1)
            return
        if record.tag not in {"img", "svg"}:
            return
        if self._figure_stack:
            self.document.figures[self._figure_stack[-1]].contains_visual = True
        else:
            self.document.unwrapped_visuals.append(record)
        target = self.document.images if record.tag == "img" else self.document.svgs
        target.append(record)

    def _record_assets(self, record: ElementRecord) -> None:
        attributes = record.attrs
        asset_attribute = {
            "img": "src",
            "source": "src",
            "video": "src",
            "audio": "src",
            "object": "data",
        }.get(record.tag)
        if asset_attribute and attributes.get(asset_attribute):
            self.document.assets.append(
                (attributes[asset_attribute] or "", record.tag, record.line)
            )
        if record.tag in {"img", "source"} and attributes.get("srcset"):
            self.document.srcsets.append(
                (attributes["srcset"] or "", record.tag, record.line)
            )
        if record.tag == "video" and attributes.get("poster"):
            self.document.assets.append(
                (attributes["poster"] or "", "video poster", record.line)
            )
        if record.tag in {"image", "use", "feimage"}:
            href = attributes.get("href") or attributes.get("xlink:href")
            if href:
                self.document.assets.append((href, f"SVG {record.tag}", record.line))

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        record = ElementRecord(tag=tag, attrs=dict(attrs), line=self.getpos()[0])
        identifier = record.attrs.get("id")
        if identifier:
            self.document.ids.setdefault(identifier, []).append(record.line)
        self._record_structure(record)
        coordinate = record.attrs.get("data-coordinate")
        if coordinate:
            self.document.coordinates.append(record)
        if tag == "a":
            href = record.attrs.get("href") or ""
            if href:
                self.document.hyperlinks.append((href, record.line))
            if href.startswith("#") and len(href) > 1:
                self.document.anchors.append((href[1:], record.line))
        self._record_visual(record)
        self._record_assets(record)

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


def _nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _valid_repository(value: object) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    parsed = urlsplit(value)
    return parsed.scheme.lower() in {"http", "https"} and bool(parsed.netloc)


def _validate_artifacts(manifest: dict[str, object], manifest_path: Path) -> list[str]:
    artifacts = manifest.get("artifacts")
    if (
        not isinstance(artifacts, list)
        or not artifacts
        or not all(_nonempty_string(item) for item in artifacts)
    ):
        return [
            "reproduction manifest artifacts must be a non-empty list of local paths"
        ]
    errors: list[str] = []
    reproduction_root = manifest_path.parent.resolve()
    for item in artifacts:
        if not isinstance(item, str):
            continue
        artifact = (manifest_path.parent / item).resolve()
        if not _inside_report(artifact, reproduction_root) or not artifact.is_file():
            errors.append(
                f"reproduction artifact is missing or escapes its directory: {item}"
            )
    return errors


def _validate_manifest(report_path: Path, known_coordinates: set[str]) -> list[str]:
    manifest_path = report_path.parent / "reproduction" / "manifest.json"
    if not manifest_path.is_file():
        return ["deep report requires reproduction/manifest.json"]
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"reproduction/manifest.json is not valid JSON: {exc}"]
    if not isinstance(manifest, dict):
        return ["reproduction/manifest.json must contain a JSON object"]
    errors = _validate_manifest_fields(manifest, known_coordinates)
    errors.extend(_validate_artifacts(manifest, manifest_path))
    return errors


def _validate_manifest_identity(
    manifest: dict[str, object], known_coordinates: set[str]
) -> list[str]:
    errors: list[str] = []
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
    if not _nonempty_string(manifest.get("environment")):
        errors.append("reproduction manifest requires a non-empty environment")
    errors.extend(_validate_manifest_provenance(manifest))
    return errors


def _validate_manifest_provenance(manifest: dict[str, object]) -> list[str]:
    repository = manifest.get("repository")
    commit = manifest.get("commit")
    no_code = (
        manifest.get("status") == "blocked"
        and manifest.get("code_status") == "not-found"
    )
    if not _nonempty_string(repository):
        if no_code:
            return []
        return [
            "reproduction manifest requires repository+commit or blocked "
            "code_status=not-found"
        ]
    errors: list[str] = []
    if not _valid_repository(repository):
        errors.append(
            "reproduction manifest repository must be a canonical http(s) URL"
        )
    if not isinstance(commit, str) or not COMMIT_RE.fullmatch(commit):
        errors.append(
            "reproduction manifest commit must be a 7-64 digit hexadecimal revision"
        )
    if no_code:
        errors.append("code_status=not-found cannot be combined with a repository")
    return errors


def _validate_manifest_status(manifest: dict[str, object]) -> list[str]:
    errors: list[str] = []
    status = manifest.get("status")
    if status in {"passed", "partial"}:
        for field_name in ("command", "result"):
            if not _nonempty_string(manifest.get(field_name)):
                errors.append(
                    f"reproduction manifest requires a non-empty {field_name}"
                )
    elif status == "blocked":
        if not _nonempty_string(manifest.get("blocker")):
            errors.append("blocked reproduction manifest requires a concrete blocker")
        audited = manifest.get("audited_sources")
        if (
            not isinstance(audited, list)
            or not audited
            or not all(_nonempty_string(item) for item in audited)
        ):
            errors.append(
                "blocked reproduction manifest requires non-empty audited_sources"
            )
    return errors


def _validate_manifest_fields(
    manifest: dict[str, object], known_coordinates: set[str]
) -> list[str]:
    errors = _validate_manifest_identity(manifest, known_coordinates)
    errors.extend(_validate_manifest_status(manifest))
    return errors


def _validate_shell(source: str, document: ReportDocument) -> list[str]:
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
    return errors


def _report_identity(document: ReportDocument) -> tuple[list[str], str, str]:
    errors: list[str] = []
    articles = [
        record for record in document.articles if "data-paper-report" in record.attrs
    ]
    if len(articles) != 1:
        return ["report requires exactly one <article data-paper-report>"], "", ""
    level = articles[0].attrs.get("data-level") or ""
    paper_type = articles[0].attrs.get("data-paper-type") or ""
    if level not in {"brief", "compact", "deep"}:
        errors.append("data-level must be brief, compact, or deep")
    if paper_type not in TYPE_SECTIONS:
        errors.append(
            "data-paper-type must be empirical, theoretical, survey, or systems"
        )
    return errors, level, paper_type


def _validate_landmarks(document: ReportDocument) -> list[str]:
    errors: list[str] = []
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
    return errors


def _validate_hyperlinks(document: ReportDocument, report_path: Path) -> list[str]:
    errors: list[str] = []
    for identifier, lines in sorted(document.ids.items()):
        if len(lines) > 1:
            errors.append(
                f"duplicate id {identifier!r} on lines {', '.join(map(str, lines))}"
            )
    for target, line in document.anchors:
        if target not in document.ids:
            errors.append(f"line {line}: local anchor target does not exist: #{target}")
    report_root = report_path.parent.resolve()
    for href, line in document.hyperlinks:
        errors.extend(_validate_hyperlink(href, line, report_path, report_root))
    return errors


def _validate_hyperlink(
    href: str, line: int, report_path: Path, report_root: Path
) -> list[str]:
    if href.startswith("#"):
        return []
    parsed = urlsplit(href)
    scheme = parsed.scheme.lower()
    if scheme in {"http", "https", "mailto"} or href.startswith("//"):
        return []
    if scheme:
        return [f"line {line}: hyperlink uses an unsafe scheme: {href}"]
    link_path = unquote(parsed.path)
    if not link_path:
        return []
    resolved = (report_path.parent / link_path).resolve()
    if not _inside_report(resolved, report_root):
        return [f"line {line}: hyperlink escapes the report directory: {href}"]
    if not resolved.is_file():
        return [f"line {line}: local hyperlink does not exist: {href}"]
    return []


def _srcset_candidates(srcset: str) -> list[str]:
    return [part.strip().split()[0] for part in srcset.split(",") if part.strip()]


def _validate_asset(
    value: str, tag: str, line: int, report_path: Path, report_root: Path
) -> list[str]:
    if value.startswith("data:"):
        return []
    if REMOTE_ASSET_RE.match(value):
        return [f"line {line}: {tag} uses a network asset: {value}"]
    parsed = urlsplit(value)
    if parsed.scheme:
        return [f"line {line}: {tag} uses an unsafe asset scheme: {value}"]
    resolved = (report_path.parent / unquote(parsed.path)).resolve()
    if not _inside_report(resolved, report_root):
        return [f"line {line}: asset escapes the report directory: {value}"]
    if not resolved.is_file():
        return [f"line {line}: local asset does not exist: {value}"]
    return []


def _validate_assets(document: ReportDocument, report_path: Path) -> list[str]:
    errors: list[str] = []
    report_root = report_path.parent.resolve()
    for value, tag, line in document.assets:
        errors.extend(_validate_asset(value, tag, line, report_path, report_root))
    for srcset, tag, line in document.srcsets:
        if REMOTE_REFERENCE_RE.search(srcset):
            errors.append(f"line {line}: {tag} srcset uses a network asset: {srcset}")
            continue
        for candidate in _srcset_candidates(srcset):
            errors.extend(
                _validate_asset(
                    candidate, f"{tag} srcset", line, report_path, report_root
                )
            )
    return errors


def _validate_visuals(document: ReportDocument) -> list[str]:
    errors: list[str] = []
    for visual in document.unwrapped_visuals:
        errors.append(
            f"line {visual.line}: every img/svg visual must be inside a lightbox figure"
        )
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
        if figure.contains_visual:
            errors.extend(_validate_lightbox_figure(figure))
    return errors


def _validate_lightbox_figure(figure: VisualRecord) -> list[str]:
    errors: list[str] = []
    if "data-lightbox" not in figure.attrs:
        errors.append(f"line {figure.line}: every visual figure requires data-lightbox")
    if figure.attrs.get("tabindex") != "0":
        errors.append(f'line {figure.line}: lightbox trigger requires tabindex="0"')
    if figure.attrs.get("role") != "button":
        errors.append(f'line {figure.line}: lightbox trigger requires role="button"')
    if not (figure.attrs.get("aria-label") or "").strip():
        errors.append(f"line {figure.line}: lightbox trigger requires an aria-label")
    return errors


def _validate_coordinates(document: ReportDocument) -> tuple[list[str], set[str]]:
    errors: list[str] = []
    known: set[str] = set()
    for record in document.coordinates:
        coordinate = record.attrs.get("data-coordinate") or ""
        if not COORDINATE_RE.fullmatch(coordinate):
            errors.append(
                f"line {record.line}: malformed evidence coordinate: {coordinate!r}"
            )
            continue
        if coordinate in known:
            errors.append(f"duplicate evidence coordinate: {coordinate}")
        known.add(coordinate)
        errors.extend(_validate_coordinate_record(record, coordinate))
    for record in document.coordinates:
        for support in (record.attrs.get("data-supports") or "").split():
            if support not in known:
                errors.append(
                    f"line {record.line}: data-supports target does not exist: {support}"
                )
    present = {coordinate[0] for coordinate in known}
    for prefix in sorted({"C", "E", "L"} - present):
        errors.append(f"report requires at least one {prefix}-coordinate")
    return errors, known


def _validate_coordinate_record(record: ElementRecord, coordinate: str) -> list[str]:
    errors: list[str] = []
    if record.attrs.get("id") != coordinate:
        errors.append(
            f"line {record.line}: coordinate {coordinate} must also be the element id"
        )
    kind = record.attrs.get("data-kind") or ""
    if kind not in KIND_PREFIX or not coordinate.startswith(KIND_PREFIX.get(kind, "?")):
        errors.append(
            f"line {record.line}: {coordinate} does not match data-kind={kind!r}"
        )
    if (
        kind in {"claim", "limitation"}
        and not (record.attrs.get("data-supports") or "").split()
    ):
        errors.append(
            f"line {record.line}: {coordinate} requires data-supports evidence links"
        )
    return errors


def _validate_sections(
    document: ReportDocument,
    level: str,
    paper_type: str,
    known: set[str],
    report_path: Path,
) -> list[str]:
    errors: list[str] = []
    names = {record.attrs.get("data-section") for record in document.sections}
    for section_name in sorted(COMMON_SECTIONS - names):
        errors.append(f"report is missing required section: {section_name}")
    if level == "brief" and "headline-evidence" not in names:
        errors.append("brief report requires a headline-evidence section")
    if level in {"compact", "deep"} and paper_type in TYPE_SECTIONS:
        for section_name in sorted(TYPE_SECTIONS[paper_type] - names):
            errors.append(
                f"{paper_type} {level} report is missing section: {section_name}"
            )
    if level == "deep":
        if "reproduction" not in names or not any(
            item.startswith("R") for item in known
        ):
            errors.append(
                "deep report requires a reproduction section with an R-coordinate"
            )
        errors.extend(_validate_manifest(report_path, known))
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
    except Exception as exc:
        return [f"report HTML could not be parsed: {exc}"]
    document = parser.document
    errors = _validate_shell(source, document)
    identity_errors, level, paper_type = _report_identity(document)
    errors.extend(identity_errors)
    errors.extend(_validate_landmarks(document))
    errors.extend(_validate_hyperlinks(document, report_path))
    errors.extend(_validate_assets(document, report_path))
    errors.extend(_validate_visuals(document))
    coordinate_errors, known = _validate_coordinates(document)
    errors.extend(coordinate_errors)
    errors.extend(_validate_sections(document, level, paper_type, known, report_path))
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
