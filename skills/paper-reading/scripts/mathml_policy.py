#!/usr/bin/env python3
"""Shared allowlist for portable, inert presentation MathML."""

from __future__ import annotations

from collections.abc import Mapping

MATHML_NAMESPACE = "http://www.w3.org/1998/Math/MathML"

SAFE_MATHML_TAGS = frozenset(
    {
        "maligngroup",
        "malignmark",
        "math",
        "menclose",
        "merror",
        "mfenced",
        "mfrac",
        "mi",
        "mlabeledtr",
        "mlongdiv",
        "mmultiscripts",
        "mn",
        "mo",
        "mover",
        "mpadded",
        "mphantom",
        "mprescripts",
        "mroot",
        "mrow",
        "ms",
        "mscarries",
        "mscarry",
        "msgroup",
        "msline",
        "mspace",
        "msqrt",
        "msrow",
        "mstack",
        "mstyle",
        "msub",
        "msubsup",
        "msup",
        "mtable",
        "mtd",
        "mtext",
        "mtr",
        "munder",
        "munderover",
        "none",
    }
)

SAFE_MATHML_ATTRIBUTES = frozenset(
    {
        "accent",
        "accentunder",
        "align",
        "bevelled",
        "close",
        "columnalign",
        "columnlines",
        "columnspacing",
        "columnspan",
        "denomalign",
        "depth",
        "dir",
        "display",
        "displaystyle",
        "edge",
        "equalcolumns",
        "equalrows",
        "fence",
        "form",
        "frame",
        "framespacing",
        "height",
        "largeop",
        "length",
        "linebreak",
        "linebreakstyle",
        "linethickness",
        "location",
        "longdivstyle",
        "lspace",
        "mathvariant",
        "maxsize",
        "minlabelspacing",
        "minsize",
        "movablelimits",
        "notation",
        "numalign",
        "open",
        "position",
        "rowalign",
        "rowlines",
        "rowspacing",
        "rowspan",
        "rspace",
        "scriptlevel",
        "selection",
        "separator",
        "separators",
        "shift",
        "side",
        "stackalign",
        "stretchy",
        "subscriptshift",
        "superscriptshift",
        "symmetric",
        "voffset",
        "width",
    }
)


def _local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1].lower()


def mathml_policy_error(
    tag: str,
    attributes: Mapping[str, str | None],
    *,
    allow_annotations: bool,
) -> str | None:
    """Return why one MathML element is unsafe, or None when allowed."""
    local_tag = _local_name(tag)
    if allow_annotations and local_tag == "semantics":
        if attributes:
            return "<semantics> must not carry attributes"
        return None
    if allow_annotations and local_tag == "annotation":
        normalized = {_local_name(key): value for key, value in attributes.items()}
        if normalized != {"encoding": "application/x-tex"}:
            return "<annotation> must contain only encoding=application/x-tex"
        return None
    if local_tag not in SAFE_MATHML_TAGS:
        return f"element <{local_tag}> is not in the presentation MathML allowlist"
    for raw_name, value in attributes.items():
        name = _local_name(raw_name)
        if local_tag == "math" and name == "xmlns" and value == MATHML_NAMESPACE:
            continue
        if name not in SAFE_MATHML_ATTRIBUTES:
            return f"attribute {name!r} is not allowed on <{local_tag}>"
    return None
