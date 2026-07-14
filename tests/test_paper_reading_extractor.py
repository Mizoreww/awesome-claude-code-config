import json
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from paper_reading_helpers import SCRIPTS_DIR, load_script


@pytest.mark.unit
def test_extractor_keeps_page_anchors_and_raw_assets(tmp_path: Path) -> None:
    extractor = load_script("extract_paper")
    pdf_path = tmp_path / "paper.pdf"
    pdf_path.write_bytes(b"%PDF-1.4\n% test fixture\n")

    def fake_converter(pdf: str, **kwargs: object) -> list[dict[str, object]]:
        image_path = Path(str(kwargs["image_path"]))
        image_path.mkdir(parents=True, exist_ok=True)
        (image_path / "paper-p1-fig1.png").write_bytes(
            bytes.fromhex(
                "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
                "890000000d49444154789c6360606060000000050001a5f64540000000004945"
                "4e44ae426082"
            )
        )
        return [
            {
                "metadata": {"page": 0},
                "text": "# Abstract\nA grounded extraction.",
                "images": [{"path": "paper-p1-fig1.png", "bbox": [1, 2, 3, 4]}],
                "graphics": [{"bbox": [5, 6, 7, 8]}],
            }
        ]

    result = extractor.extract_paper(
        pdf_path, tmp_path / "extracted", converter=fake_converter
    )
    markdown = (tmp_path / "extracted" / "meta" / "paper.md").read_text(
        encoding="utf-8"
    )
    manifest = json.loads(
        (tmp_path / "extracted" / "meta" / "figures.json").read_text(encoding="utf-8")
    )
    pages = json.loads(
        (tmp_path / "extracted" / "meta" / "pages.json").read_text(encoding="utf-8")
    )
    source = json.loads(
        (tmp_path / "extracted" / "meta" / "source.json").read_text(encoding="utf-8")
    )
    assert "<!-- page: 1 -->" in markdown
    assert result["page_count"] == 1
    assert pages[0]["page"] == 1
    assert pages[0]["images"][0]["path"] == "assets/raw/paper-p1-fig1.png"
    assert source["extractor"] == "pymupdf4llm==1.28.0"
    assert manifest["raw_assets"][0]["path"] == "assets/raw/paper-p1-fig1.png"
    assert manifest["pages"][0]["graphics"] == [{"bbox": [5, 6, 7, 8]}]
    assert (tmp_path / "extracted" / "assets" / "raw" / "paper-p1-fig1.png").exists()


@pytest.mark.unit
def test_extractor_recovers_page_asset_links_from_markdown(tmp_path: Path) -> None:
    extractor = load_script("extract_paper")
    pdf_path = tmp_path / "paper.pdf"
    pdf_path.write_bytes(b"%PDF-1.4\n")

    def converter(pdf: str, **kwargs: object) -> list[dict[str, object]]:
        image_path = Path(str(kwargs["image_path"]))
        image_path.mkdir(parents=True, exist_ok=True)
        asset = image_path / "real-output.png"
        asset.write_bytes(
            bytes.fromhex(
                "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
                "890000000d49444154789c6360606060000000050001a5f64540000000004945"
                "4e44ae426082"
            )
        )
        return [
            {
                "metadata": {"page_number": 1},
                "text": f"A figure follows.\n\n![]({asset})",
                # Current pymupdf4llm releases may write the file while leaving
                # page-chunk images empty; the Markdown path is still authoritative.
                "images": [],
                "graphics": [],
            }
        ]

    output = tmp_path / "extracted"
    extractor.extract_paper(pdf_path, output, converter=converter)
    manifest = json.loads(
        (output / "meta" / "figures.json").read_text(encoding="utf-8")
    )
    assert manifest["pages"][0]["images"] == [{"path": "assets/raw/real-output.png"}]


@pytest.mark.unit
def test_extractor_validates_inputs_and_converter_contract(tmp_path: Path) -> None:
    extractor = load_script("extract_paper")
    with pytest.raises(FileNotFoundError):
        extractor.extract_paper(tmp_path / "missing.pdf", tmp_path / "out")

    pdf = tmp_path / "paper.pdf"
    pdf.write_bytes(b"%PDF-1.4\n")
    with pytest.raises(ValueError, match="dpi"):
        extractor.extract_paper(
            pdf, tmp_path / "dpi", converter=lambda *args, **kwargs: [], dpi=20
        )

    occupied = tmp_path / "occupied"
    occupied.mkdir()
    (occupied / "keep").write_text("x", encoding="utf-8")
    with pytest.raises(FileExistsError, match="preserve raw extraction"):
        extractor.extract_paper(pdf, occupied, converter=lambda *args, **kwargs: [])

    with pytest.raises(RuntimeError, match="page chunks"):
        extractor.extract_paper(
            pdf, tmp_path / "wrong-return", converter=lambda *args, **kwargs: "text"
        )
    with pytest.raises(RuntimeError, match="not an object"):
        extractor.extract_paper(
            pdf, tmp_path / "wrong-chunk", converter=lambda *args, **kwargs: ["page"]
        )
    with pytest.raises(RuntimeError, match="no page chunks"):
        extractor.extract_paper(
            pdf, tmp_path / "empty-chunks", converter=lambda *args, **kwargs: []
        )


@pytest.mark.unit
def test_extractor_helpers_cover_portable_metadata_and_jpeg_dimensions(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    extractor = load_script("extract_paper")
    assert extractor._json_safe(Path("a/b")) == "a/b"
    assert extractor._json_safe((1, 2)) == [1, 2]
    assert isinstance(extractor._json_safe(object()), str)

    output = tmp_path / "out"
    output.mkdir()
    inside = output / "asset.png"
    portable = extractor._portable_paths({"path": str(inside), "bbox": (1, 2)}, output)
    assert portable == {"path": "asset.png", "bbox": [1, 2]}

    # Minimal JPEG stream with a baseline SOF0 marker declaring 3×2 pixels.
    jpeg = tmp_path / "tiny.jpg"
    jpeg.write_bytes(b"\xff\xd8\xff\xe0\x00\x04xx\xff\xc0\x00\x08\x08\x00\x02\x00\x03x")
    assert extractor._image_dimensions(jpeg) == (3, 2)
    unknown = tmp_path / "unknown.bin"
    unknown.write_bytes(b"not an image")
    assert extractor._image_dimensions(unknown) is None

    monkeypatch.setitem(
        sys.modules,
        "pymupdf4llm",
        SimpleNamespace(to_markdown="converter", __version__="1.28.0"),
    )
    assert extractor._load_converter() == "converter"
    monkeypatch.setitem(
        sys.modules,
        "pymupdf4llm",
        SimpleNamespace(to_markdown="converter", __version__="0.0.1"),
    )
    with pytest.raises(RuntimeError, match="requires pymupdf4llm==1.28.0"):
        extractor._load_converter()


@pytest.mark.unit
def test_extractor_main_reports_success_dependency_and_input_errors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    extractor = load_script("extract_paper")
    text = tmp_path / "plain.txt"
    text.write_text("no", encoding="utf-8")
    assert extractor.main([str(text), str(tmp_path / "bad")]) == 2
    assert "valid PDF" in capsys.readouterr().err

    pdf = tmp_path / "paper.pdf"
    pdf.write_bytes(b"%PDF-1.4\n")
    monkeypatch.setattr(
        extractor, "extract_paper", lambda *args, **kwargs: {"page_count": 1}
    )
    assert extractor.main([str(pdf), str(tmp_path / "good")]) == 0
    assert '"page_count": 1' in capsys.readouterr().out


@pytest.mark.integration
def test_extractor_cli_rejects_non_pdf_without_loading_optional_dependency(
    tmp_path: Path,
) -> None:
    source = tmp_path / "not-a-paper.txt"
    source.write_text("plain text", encoding="utf-8")
    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPTS_DIR / "extract_paper.py"),
            str(source),
            str(tmp_path / "out"),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 2
    assert "valid PDF" in completed.stderr
    assert "pymupdf" not in completed.stderr.lower()
