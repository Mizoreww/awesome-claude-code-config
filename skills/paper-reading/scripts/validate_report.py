#!/usr/bin/env python3
"""Validate a portable paper-reading HTML report."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field, replace
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

from mathml_policy import mathml_policy_error

COORDINATE_RE = re.compile(r"^[CELR][1-9][0-9]*$")
COMMIT_RE = re.compile(r"^[0-9a-fA-F]{7,64}$")
REMOTE_ASSET_RE = re.compile(r"^(?:https?:)?//", re.IGNORECASE)
REMOTE_REFERENCE_RE = re.compile(r"(?:https?:)?//", re.IGNORECASE)
PLACEHOLDER_RE = re.compile(
    r"\{\{[A-Z0-9_]+\}\}|"
    r"\[请用有证据锚点的高密度内容替换本段。\]|"
    r"\[Replace this paragraph with dense, evidence-anchored content\.\]"
)
MATH_BLOCK_RE = re.compile(
    r'<(?P<tag>div|span)\b(?=[^>]*class\s*=\s*["\'][^"\']*\bmath-(?:display|inline)\b)'
    r"[^>]*>(?P<body>.*?)</(?P=tag)>",
    re.IGNORECASE | re.DOTALL,
)
LEGACY_EQUATION_RE = re.compile(
    r'<(?:div|span)\b(?=[^>]*class\s*=\s*["\'][^"\']*\bequation-card\b)',
    re.IGNORECASE,
)
MATH_LIKE_TEXT_RE = re.compile(
    r"\\(?:frac|mathcal|mathbf|mathbb|ell|sum|int|lVert|rVert)|"
    r"[φθτσεℒ‖⇒≈≠→∼]"
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
FORBIDDEN_ELEMENTS = {
    "base",
    "embed",
    "foreignobject",
    "frame",
    "iframe",
    "object",
    "portal",
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


@dataclass(frozen=True)
class TextRecord:
    tag: str
    line: int
    inside_h1: bool = False
    text: str = ""


@dataclass
class ReportDocument:
    elements: list[ElementRecord] = field(default_factory=list)
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
    title_focuses: list[TextRecord] = field(default_factory=list)
    evidence_indexes: list[ElementRecord] = field(default_factory=list)
    math_elements: list[ElementRecord] = field(default_factory=list)
    legacy_inline_math: list[ElementRecord] = field(default_factory=list)
    code_fragments: list[TextRecord] = field(default_factory=list)


class ReportParser(HTMLParser):
    """Collect only the DOM facts needed by the report contract."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.document = ReportDocument()
        self._figure_stack: list[int] = []
        self._math_depth = 0
        self._h1_depth = 0
        self._title_focus_stack: list[tuple[str, int]] = []
        self._code_stack: list[tuple[str, int]] = []

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
        for attribute in ("src", "poster", "data", "background"):
            if not attributes.get(attribute):
                continue
            self.document.assets.append(
                (attributes[attribute] or "", f"{record.tag} {attribute}", record.line)
            )
        if attributes.get("srcset"):
            self.document.srcsets.append(
                (attributes["srcset"] or "", record.tag, record.line)
            )
        if record.tag in {"image", "use", "feimage"}:
            href = attributes.get("href") or attributes.get("xlink:href")
            if href and href.startswith("#") and len(href) > 1:
                self.document.anchors.append((href[1:], record.line))
            elif href:
                self.document.assets.append((href, f"SVG {record.tag}", record.line))

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        record = ElementRecord(tag=tag, attrs=dict(attrs), line=self.getpos()[0])
        self.document.elements.append(record)
        if tag == "h1":
            self._h1_depth += 1
        if tag == "math":
            self._math_depth += 1
        if self._math_depth:
            self.document.math_elements.append(record)
        elif tag in {"sub", "sup"}:
            self.document.legacy_inline_math.append(record)
        classes = set((record.attrs.get("class") or "").split())
        if "title-focus" in classes:
            focus = TextRecord(tag=tag, line=record.line, inside_h1=self._h1_depth > 0)
            self.document.title_focuses.append(focus)
            self._title_focus_stack.append((tag, len(self.document.title_focuses) - 1))
        if tag == "code" and not self._math_depth:
            code = TextRecord(tag=tag, line=record.line)
            self.document.code_fragments.append(code)
            self._code_stack.append((tag, len(self.document.code_fragments) - 1))
        if "data-evidence-index" in record.attrs:
            self.document.evidence_indexes.append(record)
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
        self.handle_endtag(tag)

    def handle_data(self, data: str) -> None:
        for _, index in self._title_focus_stack:
            current = self.document.title_focuses[index]
            self.document.title_focuses[index] = replace(
                current, text=f"{current.text}{data}"
            )
        for _, index in self._code_stack:
            current = self.document.code_fragments[index]
            self.document.code_fragments[index] = replace(
                current, text=f"{current.text}{data}"
            )

    def handle_endtag(self, tag: str) -> None:
        if tag == "figure" and self._figure_stack:
            self._figure_stack.pop()
        if self._title_focus_stack and self._title_focus_stack[-1][0] == tag:
            self._title_focus_stack.pop()
        if self._code_stack and self._code_stack[-1][0] == tag:
            self._code_stack.pop()
        if tag == "math" and self._math_depth:
            self._math_depth -= 1
        if tag == "h1" and self._h1_depth:
            self._h1_depth -= 1


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
            if commit is not None:
                return ["code_status=not-found must omit repository and commit"]
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


def _validate_active_content(document: ReportDocument) -> list[str]:
    errors: list[str] = []
    for script in document.scripts:
        dependency = next(
            (
                script.attrs[name]
                for name in ("src", "href", "xlink:href")
                if script.attrs.get(name)
            ),
            None,
        )
        if dependency:
            errors.append(
                f"line {script.line}: external script dependency is not portable: "
                f"{dependency}"
            )
    for link in document.links:
        errors.append(
            f"line {link.line}: link elements are not portable; inline the resource"
        )
    for record in document.elements:
        if record.tag in FORBIDDEN_ELEMENTS:
            errors.append(
                f"line {record.line}: <{record.tag}> is not allowed in a portable report"
            )
        if (
            record.tag == "input"
            and (record.attrs.get("type") or "").lower() == "image"
        ):
            errors.append(f"line {record.line}: input type=image is not allowed")
        if any(name.lower().startswith("on") for name in record.attrs):
            errors.append(f"line {record.line}: inline event handlers are not allowed")
        if (
            record.tag == "meta"
            and (record.attrs.get("http-equiv") or "").lower() == "refresh"
        ):
            errors.append(f"line {record.line}: meta refresh is not allowed")
    return errors


def _validate_shell(source: str, document: ReportDocument) -> list[str]:
    errors = _validate_active_content(document)
    if not source.lstrip().lower().startswith("<!doctype html>"):
        errors.append("report must begin with <!doctype html>")
    if PLACEHOLDER_RE.search(source):
        errors.append("report still contains scaffold placeholders")
    if not document.title_count:
        errors.append("report requires a <title>")
    if (
        len(document.title_focuses) != 1
        or document.title_focuses[0].tag != "em"
        or not document.title_focuses[0].inside_h1
        or not document.title_focuses[0].text.strip()
    ):
        errors.append("report title requires exactly one emphasized title focus")
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
    if re.search(r"@import\s|url\(\s*['\"]?(?:https?:)?//", source, re.IGNORECASE):
        errors.append("CSS contains a network dependency")
    return errors


def _validate_math(source: str, document: ReportDocument) -> list[str]:
    errors: list[str] = []
    if LEGACY_EQUATION_RE.search(source):
        errors.append("math-like code must use a static MathML math-display block")
    for legacy in document.legacy_inline_math:
        errors.append(
            f"line {legacy.line}: legacy inline math <{legacy.tag}> must use static MathML"
        )
    for code_fragment in document.code_fragments:
        if MATH_LIKE_TEXT_RE.search(code_fragment.text):
            errors.append(
                f"line {code_fragment.line}: math-like code must use static inline MathML"
            )
    for math_element in document.math_elements:
        policy_error = mathml_policy_error(
            math_element.tag, math_element.attrs, allow_annotations=True
        )
        if policy_error:
            errors.append(f"line {math_element.line}: unsafe MathML: {policy_error}")
    for match in MATH_BLOCK_RE.finditer(source):
        body = match.group("body")
        if not re.search(r"<math\b", body, re.IGNORECASE):
            errors.append("math display/inline block requires rendered MathML")
        if re.search(r"<(?:pre|code)\b", body, re.IGNORECASE):
            errors.append("math-like code is not allowed inside a MathML block")
        if "application/x-tex" not in body:
            errors.append("MathML block requires an application/x-tex annotation")
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
    if len(document.navs) != 1:
        errors.append("report requires exactly one navigation landmark")
    if not any(
        record.attrs.get("aria-label") and "data-reader-navigation" in record.attrs
        for record in document.navs
    ):
        errors.append("report navigation requires an aria-label and reader marker")
    if not _has_landmark(document.mains, id="report-content"):
        errors.append('report requires <main id="report-content">')
    if len(document.evidence_indexes) != 1 or not document.evidence_indexes[
        0
    ].attrs.get("aria-label"):
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
    errors.extend(_validate_math(source, document))
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
