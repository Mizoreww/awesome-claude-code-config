#!/usr/bin/env python3
"""Extract page-anchored Markdown and raw visual assets from a paper PDF."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from typing import Any, Callable, cast
from urllib.parse import unquote

MarkdownConverter = Callable[..., Any]
MARKDOWN_IMAGE_RE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")
PYMUPDF4LLM_VERSION = "1.28.0"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _json_safe(value: Any) -> Any:
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    try:
        return [_json_safe(item) for item in value]
    except TypeError:
        return str(value)


def _portable_paths(
    value: Any, output_dir: Path, *, relative_base: Path | None = None
) -> Any:
    safe = _json_safe(value)
    if isinstance(safe, dict):
        portable: dict[str, Any] = {}
        for key, item in safe.items():
            if key == "path" and isinstance(item, str):
                try:
                    candidate = Path(item)
                    if not candidate.is_absolute() and relative_base is not None:
                        output_candidate = output_dir / candidate
                        candidate = (
                            output_candidate
                            if output_candidate.exists()
                            else relative_base / candidate
                        )
                    portable[key] = (
                        candidate.resolve().relative_to(output_dir.resolve()).as_posix()
                    )
                except (OSError, ValueError):
                    portable[key] = item
            else:
                portable[key] = _portable_paths(
                    item, output_dir, relative_base=relative_base
                )
        return portable
    if isinstance(safe, list):
        return [
            _portable_paths(item, output_dir, relative_base=relative_base)
            for item in safe
        ]
    return safe


def _image_dimensions(path: Path) -> tuple[int, int] | None:
    """Read common image dimensions without adding Pillow as a dependency."""
    try:
        with path.open("rb") as source:
            header = source.read(32)
            if header.startswith(b"\x89PNG\r\n\x1a\n") and len(header) >= 24:
                return struct.unpack(">II", header[16:24])
            if header[:2] != b"\xff\xd8":
                return None
            source.seek(2)
            while True:
                marker_start = source.read(1)
                if not marker_start:
                    return None
                if marker_start != b"\xff":
                    continue
                marker = source.read(1)
                while marker == b"\xff":
                    marker = source.read(1)
                if marker in {bytes([code]) for code in range(0xC0, 0xC4)} | {
                    bytes([code]) for code in range(0xC5, 0xC8)
                } | {bytes([code]) for code in range(0xC9, 0xCC)} | {
                    bytes([code]) for code in range(0xCD, 0xD0)
                }:
                    length_bytes = source.read(2)
                    if len(length_bytes) != 2:
                        return None
                    payload = source.read(struct.unpack(">H", length_bytes)[0] - 2)
                    if len(payload) < 5:
                        return None
                    height, width = struct.unpack(">HH", payload[1:5])
                    return width, height
                length_bytes = source.read(2)
                if len(length_bytes) != 2:
                    return None
                source.seek(max(struct.unpack(">H", length_bytes)[0] - 2, 0), 1)
    except OSError:
        return None


def _load_converter() -> MarkdownConverter:
    try:
        import pymupdf4llm  # type: ignore[import-not-found]
    except ImportError as exc:
        raise RuntimeError(
            "pymupdf4llm is unavailable. Run this script in an isolated environment, for example: "
            f"uv run --isolated --no-project --with pymupdf4llm=={PYMUPDF4LLM_VERSION} "
            "python extract_paper.py PAPER.pdf OUTPUT_DIR; "
            "or create a standard venv and install the dependency there."
        ) from exc
    installed_version = getattr(pymupdf4llm, "__version__", None)
    if installed_version != PYMUPDF4LLM_VERSION:
        raise RuntimeError(
            f"extractor requires pymupdf4llm=={PYMUPDF4LLM_VERSION}; "
            f"found {installed_version or 'an unknown version'}"
        )
    return cast(MarkdownConverter, pymupdf4llm.to_markdown)


def _markdown_image_records(
    text: str, output_dir: Path, raw_assets_dir: Path
) -> list[dict[str, str]]:
    """Recover page-to-image links when page chunks omit their images array."""
    records: list[dict[str, str]] = []
    seen: set[str] = set()
    for match in MARKDOWN_IMAGE_RE.finditer(text):
        target = unquote(match.group(1).strip().strip("<>"))
        # Drop an optional Markdown title while preserving ordinary paths.
        if ' "' in target:
            target = target.split(' "', 1)[0]
        if target.startswith(("http://", "https://", "data:")):
            continue
        candidate = Path(target)
        if not candidate.is_absolute():
            if target.startswith("../"):
                candidate = output_dir / "meta" / candidate
            elif target.startswith("assets/"):
                candidate = output_dir / candidate
            else:
                candidate = raw_assets_dir / candidate.name
        try:
            relative = candidate.resolve().relative_to(output_dir.resolve()).as_posix()
        except (OSError, ValueError):
            continue
        if relative in seen or not candidate.is_file():
            continue
        seen.add(relative)
        records.append({"path": relative})
    return records


def _validate_pdf(pdf_path: Path) -> None:
    if not pdf_path.is_file():
        raise FileNotFoundError(f"input PDF does not exist: {pdf_path}")
    with pdf_path.open("rb") as source:
        if source.read(5) != b"%PDF-":
            raise ValueError(
                f"input is not a valid PDF (missing %PDF header): {pdf_path}"
            )


def _prepare_output(pdf_path: Path, output_dir: Path, dpi: int) -> tuple[Path, Path]:
    _validate_pdf(pdf_path)
    if dpi < 72 or dpi > 600:
        raise ValueError("dpi must be between 72 and 600")
    if output_dir.exists() and any(output_dir.iterdir()):
        raise FileExistsError(
            f"output directory is not empty: {output_dir}; "
            "choose a new directory to preserve raw extraction"
        )
    meta_dir = output_dir / "meta"
    raw_assets_dir = output_dir / "assets" / "raw"
    meta_dir.mkdir(parents=True, exist_ok=True)
    raw_assets_dir.mkdir(parents=True, exist_ok=True)
    return meta_dir, raw_assets_dir


def _convert_pages(
    pdf_path: Path,
    raw_assets_dir: Path,
    converter: MarkdownConverter,
    dpi: int,
) -> list[dict[str, Any]]:
    chunks = converter(
        str(pdf_path),
        page_chunks=True,
        write_images=True,
        image_path=str(raw_assets_dir),
        image_format="png",
        dpi=dpi,
    )
    if not isinstance(chunks, list):
        raise RuntimeError(
            "pymupdf4llm did not return page chunks; "
            "use a version that supports page_chunks=True"
        )
    if not chunks:
        raise RuntimeError("pymupdf4llm returned no page chunks")
    for index, chunk in enumerate(chunks, start=1):
        if not isinstance(chunk, dict):
            raise RuntimeError(f"page chunk {index} is not an object")
    return chunks


def _page_record(
    index: int, chunk: dict[str, Any], output_dir: Path, raw_assets_dir: Path
) -> tuple[dict[str, Any], str]:
    raw_metadata = chunk.get("metadata")
    metadata = raw_metadata if isinstance(raw_metadata, dict) else {}
    raw_page = metadata.get("page")
    reported_page = metadata.get("page_number")
    page_number = (
        raw_page + 1
        if isinstance(raw_page, int)
        else reported_page
        if isinstance(reported_page, int)
        else index + 1
    )
    raw_text = chunk.get("text")
    text = raw_text if isinstance(raw_text, str) else ""
    page_images = _portable_paths(
        chunk.get("images", []), output_dir, relative_base=raw_assets_dir
    )
    if not isinstance(page_images, list) or not page_images:
        page_images = _markdown_image_records(text, output_dir, raw_assets_dir)
    record = {
        "page": page_number,
        "metadata": _portable_paths(metadata, output_dir),
        "images": page_images,
        "graphics": _portable_paths(
            chunk.get("graphics", []), output_dir, relative_base=raw_assets_dir
        ),
    }
    portable_text = text.replace(str(raw_assets_dir), "../assets/raw")
    markdown = (
        f"<!-- page: {page_number} -->\n\n## Page {page_number}\n\n"
        f"{portable_text.strip()}\n"
    )
    return record, markdown


def _raw_asset_records(raw_assets_dir: Path, output_dir: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for asset in sorted(path for path in raw_assets_dir.rglob("*") if path.is_file()):
        entry: dict[str, Any] = {
            "path": asset.relative_to(output_dir).as_posix(),
            "bytes": asset.stat().st_size,
            "sha256": _sha256(asset),
        }
        dimensions = _image_dimensions(asset)
        if dimensions:
            entry["width"], entry["height"] = dimensions
        records.append(entry)
    return records


def _write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def _write_metadata(
    *,
    meta_dir: Path,
    pdf_path: Path,
    dpi: int,
    markdown_pages: list[str],
    page_records: list[dict[str, Any]],
    raw_assets: list[dict[str, Any]],
) -> str:
    source_sha256 = _sha256(pdf_path)
    source_record = {
        "input_path": str(pdf_path),
        "bytes": pdf_path.stat().st_size,
        "sha256": source_sha256,
        "page_count": len(page_records),
        "extractor": f"pymupdf4llm=={PYMUPDF4LLM_VERSION}",
        "dpi": dpi,
    }
    figures_record = {
        "source_sha256": source_sha256,
        "policy": "Raw extraction is immutable. Copy selected visuals elsewhere; never delete these files.",
        "raw_assets": raw_assets,
        "pages": [
            {
                "page": page["page"],
                "images": page["images"],
                "graphics": page["graphics"],
            }
            for page in page_records
        ],
    }
    (meta_dir / "paper.md").write_text("\n".join(markdown_pages), encoding="utf-8")
    _write_json(meta_dir / "pages.json", page_records)
    _write_json(meta_dir / "figures.json", figures_record)
    _write_json(meta_dir / "source.json", source_record)
    return source_sha256


def extract_paper(
    pdf_path: Path,
    output_dir: Path,
    *,
    converter: MarkdownConverter | None = None,
    dpi: int = 200,
) -> dict[str, Any]:
    """Extract one immutable raw-paper package and return a short result summary."""
    pdf_path = Path(pdf_path).resolve()
    output_dir = Path(output_dir).resolve()
    meta_dir, raw_assets_dir = _prepare_output(pdf_path, output_dir, dpi)
    chunks = _convert_pages(
        pdf_path, raw_assets_dir, converter or _load_converter(), dpi
    )
    pages = [
        _page_record(index, chunk, output_dir, raw_assets_dir)
        for index, chunk in enumerate(chunks)
    ]
    page_records = [record for record, _ in pages]
    markdown_pages = [markdown for _, markdown in pages]
    raw_assets = _raw_asset_records(raw_assets_dir, output_dir)
    source_sha256 = _write_metadata(
        meta_dir=meta_dir,
        pdf_path=pdf_path,
        dpi=dpi,
        markdown_pages=markdown_pages,
        page_records=page_records,
        raw_assets=raw_assets,
    )
    return {
        "output_dir": str(output_dir),
        "page_count": len(page_records),
        "asset_count": len(raw_assets),
        "source_sha256": source_sha256,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--dpi", type=int, default=200)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = extract_paper(args.pdf, args.output_dir, dpi=args.dpi)
    except (
        FileExistsError,
        FileNotFoundError,
        OSError,
        RuntimeError,
        ValueError,
    ) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
