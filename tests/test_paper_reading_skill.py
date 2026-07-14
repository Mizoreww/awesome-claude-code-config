from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
from types import ModuleType
from types import SimpleNamespace

import pytest


ROOT = Path(__file__).resolve().parents[1]
SKILL_DIR = ROOT / "skills" / "paper-reading"
SCRIPTS_DIR = SKILL_DIR / "scripts"


def load_script(name: str) -> ModuleType:
    path = SCRIPTS_DIR / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"paper_reading_{name}", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_valid_report(
    output_dir: Path,
    *,
    level: str = "compact",
    paper_type: str = "empirical",
    script: str = "document.documentElement.dataset.enhanced = 'true';",
) -> Path:
    output_dir.mkdir(parents=True)
    assets_dir = output_dir / "assets"
    assets_dir.mkdir()
    # A complete 1×1 transparent PNG. The validator only needs a real local asset;
    # the browser test also needs Chrome to decode it successfully.
    (assets_dir / "figure.png").write_bytes(
        bytes.fromhex(
            "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
            "890000000d49444154789c6360606060000000050001a5f64540000000004945"
            "4e44ae426082"
        )
    )

    deep_section = ""
    if level == "deep":
        deep_section = """
        <section id="R1" data-section="reproduction" data-kind="reproduction"
                 data-coordinate="R1" data-lenses="reproduction">
          <h2>最小复现</h2><p>复现记录见本地 manifest。</p>
        </section>
        """

    html = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>测试论文精读</title>
  <style>
    .is-dimmed {{ opacity: .25; }}
    dialog[open] {{ display: block; }}
  </style>
</head>
<body>
  <article data-paper-report data-level="{level}" data-paper-type="{paper_type}">
    <header class="report-hero">
      <p class="eyebrow">Compact close-reading</p>
      <h1>测试论文精读</h1>
      <p class="hero-thesis">一条可核查的核心判断。</p>
    </header>
    <nav aria-label="文章目录">
      <a href="#C1">研究问题</a><a href="#E1">实验结果</a><a href="#L1">批判分析</a>
    </nav>
    <div class="reading-lenses" aria-label="阅读视角">
      <button type="button" data-lens="all" class="active">全部</button>
      <button type="button" data-lens="evidence">证据</button>
    </div>
    <main id="report-content">
      <section data-section="basic-information"><h2>基本信息</h2><p>作者与出处。</p></section>
      <section id="C1" data-section="research-problem" data-kind="claim"
               data-coordinate="C1" data-supports="E1" data-lenses="method">
        <h2>研究问题</h2><p>问题定义。</p>
      </section>
      <section id="C2" data-section="key-insight" data-kind="claim"
               data-coordinate="C2" data-supports="E1" data-lenses="method">
        <h2>关键洞见</h2><p>机制解释。</p>
      </section>
      <section id="C3" data-section="technical-method" data-kind="claim"
               data-coordinate="C3" data-supports="E1" data-lenses="method">
        <h2>技术方法</h2><p>训练目标。</p>
      </section>
      <section id="E1" data-section="experimental-results" data-kind="evidence"
               data-coordinate="E1" data-lenses="evidence">
        <h2>实验结果</h2>
        <figure data-lightbox tabindex="0" role="button" aria-label="主结果图，点击放大">
          <img src="assets/figure.png" alt="主结果图">
          <figcaption>E1 · Figure 1</figcaption>
        </figure>
      </section>
      <section id="L1" data-section="critical-analysis" data-kind="limitation"
               data-coordinate="L1" data-supports="E1" data-lenses="critique">
        <h2>批判分析</h2><p>一项有边界的限制。</p>
      </section>
      {deep_section}
      <section data-section="summary"><h2>总结与评价</h2><p>结论。</p></section>
    </main>
    <aside aria-label="证据索引"><a href="#E1">E1 · Figure 1</a></aside>
  </article>
  <dialog id="lightbox" aria-label="大图查看器">
    <button type="button" data-lightbox-close aria-label="关闭大图">关闭</button>
    <div class="lightbox-stage"></div><p class="lightbox-caption"></p>
  </dialog>
  <script>{script}</script>
</body>
</html>
"""
    path = output_dir / "summary.html"
    path.write_text(html, encoding="utf-8")
    return path


@pytest.mark.unit
def test_skill_is_layered_portable_and_points_to_every_reference() -> None:
    skill_path = SKILL_DIR / "SKILL.md"
    text = skill_path.read_text(encoding="utf-8")
    assert len(text.splitlines()) < 260
    assert "Claude" not in text
    assert "Read tool" not in text
    assert "conda activate" not in text
    assert "pip install" not in text
    assert "\npython <skill-dir>" not in text
    assert "PYTHON_EXE" in text
    assert "references/levels.md" in text
    assert "references/evidence.md" in text
    assert "references/html-report.md" in text
    assert "references/visuals.md" in text
    assert "references/reproduction.md" in text
    for paper_type in ("empirical", "theoretical", "survey", "systems"):
        assert f"references/{paper_type}.md" in text
    assert "scripts/extract_paper.py" in text
    assert "scripts/scaffold_report.py" in text
    assert "scripts/validate_report.py" in text

    html_guidance = (SKILL_DIR / "references" / "html-report.md").read_text(
        encoding="utf-8"
    )
    assert "\npython <skill-dir>" not in html_guidance
    assert "PYTHON_EXE" in html_guidance
    level_guidance = (SKILL_DIR / "references" / "levels.md").read_text(
        encoding="utf-8"
    )
    assert "shallow clone" in level_guidance


@pytest.mark.unit
def test_scaffold_escapes_metadata_and_creates_level_directories(
    tmp_path: Path,
) -> None:
    scaffold = load_script("scaffold_report")
    output_dir = tmp_path / "report"
    summary_path = scaffold.scaffold_report(
        output_dir=output_dir,
        title="A <B> & C",
        authors="Ada & Lin",
        paper_type="empirical",
        level="deep",
        thesis="A claim grounded in the paper.",
        fingerprints=["q₀", "q₁", "p<data>"],
        language="zh-CN",
        source="https://example.test/paper",
    )
    html = summary_path.read_text(encoding="utf-8")
    assert "A &lt;B&gt; &amp; C" in html
    assert "Ada &amp; Lin" in html
    assert 'data-level="deep"' in html
    assert "<style data-report-style>" in html
    assert "<script data-report-script>" in html
    assert not (output_dir / "report.css").exists()
    assert (output_dir / "assets").is_dir()
    assert (output_dir / "reproduction").is_dir()


@pytest.mark.unit
def test_scaffold_requires_a_content_derived_fingerprint(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    with pytest.raises(ValueError, match="fingerprint"):
        scaffold.scaffold_report(
            output_dir=tmp_path / "report",
            title="Paper",
            authors="Author",
            paper_type="empirical",
            level="brief",
            thesis="Thesis",
            fingerprints=["only-one"],
        )


@pytest.mark.unit
@pytest.mark.parametrize(
    ("paper_type", "required_sections"),
    [
        ("empirical", ("technical-method", "experimental-results")),
        ("theoretical", ("theoretical-framework", "theoretical-analysis")),
        ("survey", ("taxonomy", "open-problems")),
        ("systems", ("system-design", "performance-evaluation")),
    ],
)
def test_scaffold_selects_the_paper_type_outline(
    tmp_path: Path, paper_type: str, required_sections: tuple[str, str]
) -> None:
    scaffold = load_script("scaffold_report")
    path = scaffold.scaffold_report(
        output_dir=tmp_path / paper_type,
        title="Paper",
        authors="Author",
        paper_type=paper_type,
        level="compact",
        thesis="Specific thesis.",
        fingerprints=["concept-a", "concept-b"],
    )
    html = path.read_text(encoding="utf-8")
    for section, coordinate in zip(required_sections, ("C3", "E1"), strict=True):
        assert f'data-section="{section}"' in html
        assert f'href="#{coordinate}"' in html
        assert f'id="{coordinate}"' in html


@pytest.mark.unit
@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"paper_type": "unknown"}, "paper type"),
        ({"paper_type": "hybrid"}, "paper type"),
        ({"level": "unknown"}, "reading level"),
        ({"title": ""}, "title"),
        ({"authors": "  "}, "authors"),
        ({"thesis": ""}, "thesis"),
    ],
)
def test_scaffold_rejects_invalid_metadata(
    tmp_path: Path, overrides: dict[str, str], message: str
) -> None:
    scaffold = load_script("scaffold_report")
    arguments = {
        "output_dir": tmp_path / message.replace(" ", "-"),
        "title": "Paper",
        "authors": "Author",
        "paper_type": "empirical",
        "level": "brief",
        "thesis": "Thesis",
        "fingerprints": ["one", "two"],
    }
    arguments.update(overrides)
    with pytest.raises(ValueError, match=message):
        scaffold.scaffold_report(**arguments)


@pytest.mark.unit
def test_scaffold_refuses_to_mix_with_existing_output(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    output_dir = tmp_path / "report"
    output_dir.mkdir()
    (output_dir / "owned.txt").write_text("preserve me", encoding="utf-8")
    with pytest.raises(FileExistsError, match="not empty"):
        scaffold.scaffold_report(
            output_dir=output_dir,
            title="Paper",
            authors="Author",
            paper_type="empirical",
            level="brief",
            thesis="Thesis",
            fingerprints=["one", "two"],
        )


@pytest.mark.unit
def test_scaffold_main_reports_success_and_user_errors(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    scaffold = load_script("scaffold_report")
    argv = [
        str(tmp_path / "report"),
        "--title",
        "Paper",
        "--authors",
        "Author",
        "--paper-type",
        "empirical",
        "--level",
        "brief",
        "--thesis",
        "Thesis",
        "--fingerprint",
        "one",
        "--fingerprint",
        "two",
    ]
    assert scaffold.main(argv) == 0
    assert "summary.html" in capsys.readouterr().out
    assert scaffold.main(argv) == 2
    assert "not empty" in capsys.readouterr().err


@pytest.mark.unit
def test_validator_accepts_a_complete_compact_report(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    assert validator.validate_report(report) == []


@pytest.mark.unit
def test_validator_reports_broken_assets_and_inaccessible_visuals(
    tmp_path: Path,
) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    text = report.read_text(encoding="utf-8")
    text = text.replace('src="assets/figure.png"', 'src="assets/missing.png"')
    text = text.replace('data-lightbox tabindex="0" role="button"', "data-lightbox")
    report.write_text(text, encoding="utf-8")
    errors = validator.validate_report(report)
    assert any("assets/missing.png" in error for error in errors)
    assert any("tabindex" in error for error in errors)
    assert any('role="button"' in error for error in errors)


@pytest.mark.unit
def test_validator_requires_a_complete_deep_reproduction_manifest(
    tmp_path: Path,
) -> None:
    validator = load_script("validate_report")
    output_dir = tmp_path / "report"
    report = write_valid_report(output_dir, level="deep")
    errors = validator.validate_report(report)
    assert any("reproduction/manifest.json" in error for error in errors)

    reproduction_dir = output_dir / "reproduction"
    reproduction_dir.mkdir()
    (reproduction_dir / "run.log").write_text(
        "representative check: passed\n", encoding="utf-8"
    )
    (reproduction_dir / "manifest.json").write_text(
        json.dumps(
            {
                "status": "passed",
                "repository": "https://github.com/example/project",
                "commit": "0123456789abcdef0123456789abcdef01234567",
                "claim": "C1",
                "command": "uv run reproduce.py",
                "environment": "Python 3.12, CPU",
                "result": "The representative check passed.",
                "artifacts": ["run.log"],
            }
        ),
        encoding="utf-8",
    )
    assert validator.validate_report(report) == []


@pytest.mark.unit
@pytest.mark.parametrize(
    ("paper_type", "first_section", "second_section"),
    [
        ("theoretical", "theoretical-framework", "theoretical-analysis"),
        ("survey", "taxonomy", "open-problems"),
        ("systems", "system-design", "performance-evaluation"),
    ],
)
def test_validator_accepts_each_compact_paper_type(
    tmp_path: Path, paper_type: str, first_section: str, second_section: str
) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / paper_type, paper_type=paper_type)
    html = report.read_text(encoding="utf-8")
    html = html.replace("technical-method", first_section).replace(
        "experimental-results", second_section
    )
    report.write_text(html, encoding="utf-8")
    assert validator.validate_report(report) == []


@pytest.mark.unit
def test_validator_rejects_generic_hybrid_paper_type(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "hybrid", paper_type="hybrid")
    errors = validator.validate_report(report)
    assert any("data-paper-type" in error for error in errors)


@pytest.mark.unit
def test_validator_accepts_brief_and_blocked_deep_contracts(tmp_path: Path) -> None:
    validator = load_script("validate_report")

    brief = write_valid_report(tmp_path / "brief", level="brief")
    brief.write_text(
        brief.read_text(encoding="utf-8").replace(
            "experimental-results", "headline-evidence"
        ),
        encoding="utf-8",
    )
    assert validator.validate_report(brief) == []

    deep_dir = tmp_path / "blocked"
    deep = write_valid_report(deep_dir, level="deep")
    reproduction = deep_dir / "reproduction"
    reproduction.mkdir()
    (reproduction / "audit.log").write_text(
        "audited official sources\n", encoding="utf-8"
    )
    (reproduction / "manifest.json").write_text(
        json.dumps(
            {
                "status": "blocked",
                "claim": "C1",
                "environment": "Python 3.12, CPU",
                "artifacts": ["audit.log"],
                "blocker": "Official checkpoint requires unavailable gated data.",
                "audited_sources": ["https://example.test/official"],
            }
        ),
        encoding="utf-8",
    )
    assert validator.validate_report(deep) == []


@pytest.mark.unit
def test_validator_surfaces_independent_contract_violations(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8")
    html = html.replace("<!doctype html>", "")
    html = html.replace('<meta charset="utf-8">', "")
    html = html.replace(
        '<meta name="viewport" content="width=device-width, initial-scale=1">', ""
    )
    html = html.replace("<title>测试论文精读</title>", "")
    html = html.replace(
        "<style>",
        '<link rel="stylesheet" href="remote.css"><style>@import "https://example.test/x.css";',
    )
    html = html.replace(
        "<script>", '<script src="https://example.test/app.js"></script><script>'
    )
    html = html.replace('data-level="compact"', 'data-level="wide"')
    html = html.replace('data-paper-type="empirical"', 'data-paper-type="unknown"')
    html = html.replace('class="report-hero"', 'class="plain"')
    html = html.replace('aria-label="文章目录"', "")
    html = html.replace('id="report-content"', 'id="C1"')
    html = html.replace('aria-label="证据索引"', "")
    html = html.replace('id="lightbox"', 'id="other-dialog"')
    html = html.replace('href="#E1"', 'href="#missing"', 1)
    html = html.replace(
        'src="assets/figure.png"', 'src="https://example.test/figure.png"'
    )
    html = html.replace('alt="主结果图"', 'alt=""')
    html = html.replace('data-coordinate="C2"', 'data-coordinate="bad"')
    html = html.replace('data-supports="E1"', 'data-supports="E404"', 1)
    html = html.replace('data-kind="limitation"', 'data-kind="claim"')
    html = html.replace(
        "</main>",
        '<figure><svg viewBox="0 0 10 10"></svg></figure></main>',
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    expected_fragments = (
        "doctype",
        "charset",
        "viewport",
        "<title>",
        "stylesheet",
        "network dependency",
        "external script",
        "data-level",
        "data-paper-type",
        "report-hero",
        "navigation requires",
        "report-content",
        "evidence index",
        "lightbox",
        "duplicate id",
        "#missing",
        "network asset",
        "alt text",
        "inline SVG",
        "data-lightbox",
        "malformed evidence coordinate",
        "E404",
        "does not match data-kind",
    )
    for fragment in expected_fragments:
        assert any(fragment in error for error in errors), fragment


@pytest.mark.unit
def test_validator_handles_missing_and_malformed_reproduction_files(
    tmp_path: Path,
) -> None:
    validator = load_script("validate_report")
    assert validator.validate_report(tmp_path / "missing.html") == [
        f"report does not exist: {tmp_path / 'missing.html'}"
    ]

    output_dir = tmp_path / "deep"
    report = write_valid_report(output_dir, level="deep")
    reproduction = output_dir / "reproduction"
    reproduction.mkdir()
    (reproduction / "manifest.json").write_text("not json", encoding="utf-8")
    assert any("not valid JSON" in error for error in validator.validate_report(report))
    (reproduction / "manifest.json").write_text("[]", encoding="utf-8")
    assert any("JSON object" in error for error in validator.validate_report(report))
    (reproduction / "manifest.json").write_text(
        json.dumps(
            {"status": "blocked", "claim": "E1", "environment": "", "artifacts": []}
        ),
        encoding="utf-8",
    )
    errors = validator.validate_report(report)
    assert any("status" not in error and "claim" in error for error in errors)
    assert any("blocker" in error for error in errors)
    assert any("audited_sources" in error for error in errors)


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
    assert "<!-- page: 1 -->" in markdown
    assert result["page_count"] == 1
    assert pages[0]["page"] == 1
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
        sys.modules, "pymupdf4llm", SimpleNamespace(to_markdown="converter")
    )
    assert extractor._load_converter() == "converter"


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


@pytest.mark.integration
def test_validator_cli_uses_a_nonzero_exit_for_contract_failures(
    tmp_path: Path,
) -> None:
    report = write_valid_report(tmp_path / "report")
    report.write_text(
        report.read_text(encoding="utf-8").replace(
            "assets/figure.png", "assets/gone.png"
        ),
        encoding="utf-8",
    )
    completed = subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / "validate_report.py"), str(report)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 1
    assert "assets/gone.png" in completed.stdout


@pytest.mark.e2e
def test_html_interactions_work_in_a_real_browser(tmp_path: Path) -> None:
    pytest.importorskip("playwright.sync_api")
    chrome = shutil.which("google-chrome") or shutil.which("chromium")
    if chrome is None:
        pytest.skip("Chrome/Chromium is not installed")

    report_script = (SKILL_DIR / "assets" / "report.js").read_text(encoding="utf-8")
    report = write_valid_report(tmp_path / "report", script=report_script)

    from playwright.sync_api import sync_playwright

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, executable_path=chrome)
        page = browser.new_page(viewport={"width": 1200, "height": 900})
        page.goto(report.as_uri())
        assert page.locator("html").get_attribute("data-enhanced") == "true"

        page.locator("figure[data-lightbox]").click()
        assert page.locator("#lightbox").evaluate("node => node.open") is True
        page.keyboard.press("Escape")
        assert page.locator("#lightbox").evaluate("node => node.open") is False

        page.locator('[data-lens="evidence"]').click()
        assert (
            page.locator('[data-lenses="method"]').first.evaluate(
                "node => node.classList.contains('is-dimmed')"
            )
            is True
        )
        assert (
            page.locator('[data-lenses="evidence"]').evaluate(
                "node => node.classList.contains('is-dimmed')"
            )
            is False
        )
        browser.close()
