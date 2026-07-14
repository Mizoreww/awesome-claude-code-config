#!/usr/bin/env python3
"""Render a UTF-8 LaTeX source file as portable static MathML."""

from __future__ import annotations

import argparse
import html
import importlib
import importlib.metadata
import re
import sys

# Used only to build and serialize a tree parsed by defusedxml.
import xml.etree.ElementTree as ET  # nosec B405
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import cast

from mathml_policy import MATHML_NAMESPACE, mathml_policy_error

CONVERTER_PACKAGE = "latex2mathml"
CONVERTER_VERSION = "3.78.1"
XML_PACKAGE = "defusedxml"
XML_VERSION = "0.7.1"
CANNED_EXPLANATION_PREFIX_RE = re.compile(
    r"^(?:直观解释|公式解释|intuition|explanation)\s*[·:：—-]",
    re.IGNORECASE,
)
Converter = Callable[..., str]


XmlParser = Callable[[str], ET.Element]


def _mathml_nodes(root: ET.Element) -> Iterator[ET.Element]:
    yield root
    for child in root:
        yield from _mathml_nodes(child)


def _load_converter() -> Converter:
    try:
        version = importlib.metadata.version(CONVERTER_PACKAGE)
        module = importlib.import_module("latex2mathml.converter")
    except (ImportError, importlib.metadata.PackageNotFoundError) as exc:
        raise RuntimeError(
            f"install {CONVERTER_PACKAGE}=={CONVERTER_VERSION} in an isolated environment"
        ) from exc
    if version != CONVERTER_VERSION:
        raise RuntimeError(
            f"expected {CONVERTER_PACKAGE}=={CONVERTER_VERSION}, found {version}"
        )
    return cast(Converter, module.convert)


def _load_xml_parser() -> XmlParser:
    try:
        version = importlib.metadata.version(XML_PACKAGE)
        module = importlib.import_module("defusedxml.ElementTree")
    except (ImportError, importlib.metadata.PackageNotFoundError) as exc:
        raise RuntimeError(
            f"install {XML_PACKAGE}=={XML_VERSION} in an isolated environment"
        ) from exc
    if version != XML_VERSION:
        raise RuntimeError(f"expected {XML_PACKAGE}=={XML_VERSION}, found {version}")
    return cast(XmlParser, module.fromstring)


def _annotate_mathml(
    mathml: str,
    latex: str,
    display: str,
    parser: XmlParser | None = None,
) -> str:
    source = mathml.strip()
    try:
        root = (parser or _load_xml_parser())(source)
    except (ET.ParseError, ValueError) as exc:
        raise ValueError(f"converter returned invalid MathML: {exc}") from exc
    if root.tag != f"{{{MATHML_NAMESPACE}}}math":
        raise ValueError("converter output must have a MathML <math> root")
    for node in _mathml_nodes(root):
        policy_error = mathml_policy_error(
            node.tag, node.attrib, allow_annotations=False
        )
        if policy_error:
            raise ValueError(f"unsafe MathML: {policy_error}")
    # Never splice the converter's source back into HTML. XML and HTML disagree
    # about constructs such as CDATA; serializing the checked tree makes those
    # constructs ordinary escaped text before a browser sees them.
    children = list(root)
    semantics = ET.Element(f"{{{MATHML_NAMESPACE}}}semantics")
    semantics.text = root.text
    root.text = None
    for child in children:
        root.remove(child)
        semantics.append(child)
    annotation = ET.SubElement(
        semantics,
        f"{{{MATHML_NAMESPACE}}}annotation",
        {"encoding": "application/x-tex"},
    )
    annotation.text = latex
    root.append(semantics)
    root.set("display", display)
    ET.register_namespace("", MATHML_NAMESPACE)
    return ET.tostring(root, encoding="unicode", short_empty_elements=True)


def render_math(
    latex: str,
    *,
    display: str = "block",
    explanation: str | None = None,
    converter: Converter | None = None,
) -> str:
    """Return an offline HTML fragment containing MathML and its LaTeX source."""
    latex = latex.strip()
    if not latex:
        raise ValueError("LaTeX source cannot be empty")
    if display not in {"block", "inline"}:
        raise ValueError("display must be block or inline")
    normalized_explanation = " ".join((explanation or "").split())
    if display == "block" and not normalized_explanation:
        raise ValueError("block mathematics requires a plain-language explanation")
    if display == "block" and len(normalized_explanation) < 10:
        raise ValueError("block mathematics explanation is too short to be useful")
    if display == "block" and CANNED_EXPLANATION_PREFIX_RE.search(
        normalized_explanation
    ):
        raise ValueError(
            "block mathematics explanation must start as natural prose, not a canned label"
        )
    if display == "inline" and explanation is not None:
        raise ValueError("inline mathematics does not accept a block explanation")
    convert = converter or _load_converter()
    mathml = _annotate_mathml(convert(latex, display=display), latex, display)
    if display == "inline":
        return f'<span class="math-inline">{mathml}</span>'
    explanation_html = html.escape(normalized_explanation, quote=False)
    return (
        '<div class="equation-block">'
        f'<div class="math-display">{mathml}</div>'
        f'<p class="equation-explanation">{explanation_html}</p>'
        "</div>"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "source", type=Path, help="UTF-8 file containing one TeX formula"
    )
    parser.add_argument("--display", choices=("block", "inline"), default="block")
    parser.add_argument(
        "--explanation",
        help="Plain-language explanation required directly below block mathematics",
    )
    parser.add_argument(
        "--output", type=Path, help="Write the HTML fragment to this file"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        latex = args.source.read_text(encoding="utf-8")
        fragment = render_math(
            latex, display=args.display, explanation=args.explanation
        )
        if args.output:
            args.output.write_text(f"{fragment}\n", encoding="utf-8")
        else:
            print(fragment)
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
