#!/usr/bin/env python3
"""Render a UTF-8 LaTeX source file as portable static MathML."""

from __future__ import annotations

import argparse
import html
import importlib
import importlib.metadata
import re
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Protocol, cast

CONVERTER_PACKAGE = "latex2mathml"
CONVERTER_VERSION = "3.78.1"
XML_PACKAGE = "defusedxml"
XML_VERSION = "0.7.1"
MATHML_NAMESPACE = "http://www.w3.org/1998/Math/MathML"
Converter = Callable[..., str]


class XmlElement(Protocol):
    tag: str


XmlParser = Callable[[str], XmlElement]


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
    except Exception as exc:
        raise ValueError(f"converter returned invalid MathML: {exc}") from exc
    if root.tag != f"{{{MATHML_NAMESPACE}}}math":
        raise ValueError("converter output must have a MathML <math> root")
    closing = "</math>"
    opening_end = source.find(">")
    if (
        not source.startswith("<math")
        or opening_end < 0
        or not source.endswith(closing)
    ):
        raise ValueError("converter output must use an unprefixed MathML <math> root")
    opening = source[: opening_end + 1]
    display_attribute = re.compile(r"\sdisplay=(['\"]).*?\1")
    if display_attribute.search(opening):
        opening = display_attribute.sub(f' display="{display}"', opening, count=1)
    else:
        opening = f'{opening[:-1]} display="{display}">'
    body = source[opening_end + 1 : -len(closing)]
    annotation = (
        '<annotation encoding="application/x-tex">'
        f"{html.escape(latex, quote=False)}</annotation>"
    )
    return f"{opening}<semantics>{body}{annotation}</semantics>{closing}"


def render_math(
    latex: str, *, display: str = "block", converter: Converter | None = None
) -> str:
    """Return an offline HTML fragment containing MathML and its LaTeX source."""
    latex = latex.strip()
    if not latex:
        raise ValueError("LaTeX source cannot be empty")
    if display not in {"block", "inline"}:
        raise ValueError("display must be block or inline")
    convert = converter or _load_converter()
    mathml = _annotate_mathml(convert(latex, display=display), latex, display)
    tag, class_name = (
        ("div", "math-display") if display == "block" else ("span", "math-inline")
    )
    return f'<{tag} class="{class_name}">{mathml}</{tag}>'


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "source", type=Path, help="UTF-8 file containing one TeX formula"
    )
    parser.add_argument("--display", choices=("block", "inline"), default="block")
    parser.add_argument(
        "--output", type=Path, help="Write the HTML fragment to this file"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        latex = args.source.read_text(encoding="utf-8")
        fragment = render_math(latex, display=args.display)
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
