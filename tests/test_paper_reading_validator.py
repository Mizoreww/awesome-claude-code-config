import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest
from paper_reading_helpers import SCRIPTS_DIR, load_script, write_valid_report

CONTRACT_CORRUPTIONS = (
    ("<!doctype html>", ""),
    ('<meta charset="utf-8">', ""),
    ('<meta name="viewport" content="width=device-width, initial-scale=1">', ""),
    ("<title>测试论文精读</title>", ""),
    (
        "<style>",
        '<link rel="stylesheet" href="remote.css"><style>@import "https://example.test/x.css";',
    ),
    ("<script>", '<script src="https://example.test/app.js"></script><script>'),
    ('data-level="compact"', 'data-level="wide"'),
    ('data-paper-type="empirical"', 'data-paper-type="unknown"'),
    ('class="report-hero"', 'class="plain"'),
    ('aria-label="阅读导航"', ""),
    ('class="title-focus"', 'class="plain-title"'),
    (
        '<nav class="reader-nav"',
        '<nav aria-label="重复导航"></nav><nav class="reader-nav"',
    ),
    ('id="report-content"', 'id="C1"'),
    ("data-evidence-index", "data-missing-evidence-index"),
    ('id="lightbox"', 'id="other-dialog"'),
    ('src="assets/figure.png"', 'src="https://example.test/figure.png"'),
    ('alt="主结果图"', 'alt=""'),
    ('data-coordinate="C2"', 'data-coordinate="bad"'),
    ('data-kind="limitation"', 'data-kind="claim"'),
    ("</main>", '<figure><svg viewBox="0 0 10 10"></svg></figure></main>'),
)
EXPECTED_CONTRACT_ERRORS = (
    "doctype",
    "charset",
    "viewport",
    "<title>",
    "link elements",
    "network dependency",
    "external script",
    "data-level",
    "data-paper-type",
    "report-hero",
    "navigation requires",
    "title focus",
    "exactly one navigation",
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


def _blocked_report(tmp_path: Path, name: str) -> tuple[Any, Path, Path]:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / name, level="deep")
    reproduction = report.parent / "reproduction"
    reproduction.mkdir()
    (reproduction / "audit.log").write_text(
        "audited official sources\n", encoding="utf-8"
    )
    return validator, report, reproduction


@pytest.mark.unit
def test_validator_accepts_a_complete_compact_report(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    assert validator.validate_report(report) == []


@pytest.mark.unit
def test_validator_requires_static_mathml_in_math_blocks(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8").replace(
        "</main>",
        '<div class="equation-card"><code>\\mathcal{L}(\\theta)=0</code></div></main>',
    )
    report.write_text(html, encoding="utf-8")
    assert any("math-like code" in error for error in validator.validate_report(report))
    mathml = (
        '<div class="math-display"><math display="block"><semantics><mi>L</mi>'
        '<annotation encoding="application/x-tex">\\mathcal{L}=0</annotation>'
        "</semantics></math></div>"
    )
    report.write_text(
        html.replace(
            '<div class="equation-card"><code>\\mathcal{L}(\\theta)=0</code></div>',
            mathml,
        ),
        encoding="utf-8",
    )
    assert validator.validate_report(report) == []


@pytest.mark.unit
@pytest.mark.parametrize(
    "replacement",
    (
        '<em class="title-focus"></em>',
        '</h1><em class="title-focus">精读</em><h1>',
    ),
)
def test_validator_requires_nonempty_title_focus_inside_h1(
    tmp_path: Path, replacement: str
) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8").replace(
        '<em class="title-focus">精读</em>', replacement
    )
    report.write_text(html, encoding="utf-8")
    assert any("title focus" in error for error in validator.validate_report(report))


@pytest.mark.unit
def test_validator_rejects_legacy_inline_math_markup(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8").replace(
        "</main>", "<p><em>q=f#p<sub>ε</sub></em> and <code>φ</code></p></main>"
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    assert any("legacy inline math" in error for error in errors)
    assert any("math-like code" in error for error in errors)


@pytest.mark.unit
def test_validator_rejects_unsafe_mathml_markup(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    unsafe_math = (
        '<span class="math-inline"><math xmlns="http://www.w3.org/1998/Math/MathML" '
        'display="inline"><semantics><mrow style="position:fixed"><mtext '
        'href="javascript:alert(1)">x</mtext></mrow><annotation '
        'encoding="application/x-tex">x</annotation></semantics></math></span>'
    )
    html = report.read_text(encoding="utf-8").replace(
        "</main>", f"{unsafe_math}</main>"
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    assert any("unsafe MathML" in error for error in errors)


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
def test_validator_rejects_unwrapped_visuals(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8").replace(
        "</main>",
        '<img src="assets/figure.png" alt="standalone">'
        '<svg viewBox="0 0 10 10" role="img" aria-label="standalone SVG"></svg>'
        "</main>",
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    assert sum("inside a lightbox figure" in error for error in errors) == 2


@pytest.mark.unit
def test_validator_rejects_network_srcset_and_svg_image_assets(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8")
    html = html.replace(
        'src="assets/figure.png"',
        'src="assets/figure.png" srcset="https://example.test/large.png 2x"',
    ).replace(
        "</main>",
        """<figure data-lightbox tabindex="0" role="button" aria-label="SVG, enlarge">
          <svg viewBox="0 0 10 10" role="img" aria-label="SVG image test">
            <image href="https://example.test/inside-svg.png" width="10" height="10"></image>
            <use href="https://example.test/remote-symbol.svg#mark"></use>
            <filter><feImage xlink:href="https://example.test/filter.png"></feImage></filter>
          </svg><figcaption>network test</figcaption>
        </figure></main>""",
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    assert any("large.png" in error for error in errors)
    assert any("inside-svg.png" in error for error in errors)
    assert any("remote-symbol.svg" in error for error in errors)
    assert any("filter.png" in error for error in errors)


@pytest.mark.unit
def test_validator_accepts_and_checks_fragment_svg_use(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    local_use = """<figure data-lightbox tabindex="0" role="button" aria-label="SVG use">
      <svg viewBox="0 0 10 10" role="img" aria-label="Local SVG use">
        <defs><path id="local-shape" d="M0 0h5v5z"></path></defs>
        <use href="#local-shape"></use>
      </svg><figcaption>local reference</figcaption>
    </figure>"""
    report.write_text(
        report.read_text(encoding="utf-8").replace("</main>", f"{local_use}</main>"),
        encoding="utf-8",
    )
    assert validator.validate_report(report) == []
    report.write_text(
        report.read_text(encoding="utf-8").replace("#local-shape", "#missing-shape"),
        encoding="utf-8",
    )
    assert any("#missing-shape" in error for error in validator.validate_report(report))


@pytest.mark.unit
def test_validator_checks_local_srcset_candidates(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8").replace(
        'src="assets/figure.png"',
        'src="assets/figure.png" srcset="assets/figure.png 1x, assets/missing-2x.png 2x"',
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    assert any("assets/missing-2x.png" in error for error in errors)


@pytest.mark.unit
def test_validator_checks_local_hyperlinks_and_unsafe_schemes(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8").replace(
        "</main>",
        '<a href="reproduction/missing.json">missing</a>'
        '<a href="../escape.txt">escape</a>'
        '<a href="javascript:alert(1)">unsafe</a>'
        '<a href="https://example.test/allowed">external</a>'
        "</main>",
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    assert any("reproduction/missing.json" in error for error in errors)
    assert any("../escape.txt" in error for error in errors)
    assert any("javascript" in error for error in errors)
    assert not any("example.test/allowed" in error for error in errors)


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

    manifest = json.loads(
        (reproduction_dir / "manifest.json").read_text(encoding="utf-8")
    )
    manifest["artifacts"] = []
    (reproduction_dir / "manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    assert any("artifacts" in error for error in validator.validate_report(report))

    manifest["artifacts"] = ["run.log"]
    manifest["repository"] = "javascript:alert(1)"
    (reproduction_dir / "manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    assert any("repository" in error for error in validator.validate_report(report))


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
def test_validator_accepts_brief_contract(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    brief = write_valid_report(tmp_path / "brief", level="brief")
    brief.write_text(
        brief.read_text(encoding="utf-8").replace(
            "experimental-results", "headline-evidence"
        ),
        encoding="utf-8",
    )
    assert validator.validate_report(brief) == []


@pytest.mark.unit
def test_validator_accepts_blocked_repository_contract(tmp_path: Path) -> None:
    validator, deep, reproduction = _blocked_report(tmp_path, "blocked-repository")
    (reproduction / "manifest.json").write_text(
        json.dumps(
            {
                "status": "blocked",
                "repository": "https://github.com/example/project",
                "commit": "0123456789abcdef0123456789abcdef01234567",
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
def test_validator_accepts_blocked_no_code_contract(tmp_path: Path) -> None:
    validator, deep, reproduction = _blocked_report(tmp_path, "blocked-no-code")
    (reproduction / "manifest.json").write_text(
        json.dumps(
            {
                "status": "blocked",
                "code_status": "not-found",
                "claim": "C1",
                "environment": "Python 3.12, CPU",
                "artifacts": ["audit.log"],
                "blocker": "No authoritative implementation was released or linked.",
                "audited_sources": ["https://example.test/official"],
            }
        ),
        encoding="utf-8",
    )
    assert validator.validate_report(deep) == []
    manifest = json.loads((reproduction / "manifest.json").read_text(encoding="utf-8"))
    manifest["commit"] = "abcdef0"
    (reproduction / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    assert any("must omit" in error for error in validator.validate_report(deep))


@pytest.mark.unit
def test_validator_rejects_active_embeds_and_fetch_surfaces(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "active-content")
    html = report.read_text(encoding="utf-8")
    html = html.replace(
        "</head>",
        '<link rel="preload" href="https://example.test/preload.js">'
        '<meta http-equiv="refresh" content="0;url=https://example.test/refresh">'
        "</head>",
    ).replace(
        "</main>",
        '<iframe src="https://example.test/frame.html"></iframe>'
        '<embed src="https://example.test/embed.bin">'
        '<track src="https://example.test/captions.vtt">'
        '<input type="image" src="https://example.test/button.png">'
        '<figure data-lightbox tabindex="0" role="button" aria-label="active SVG">'
        '<svg viewBox="0 0 10 10" role="img" aria-label="active SVG">'
        '<script href="https://example.test/svg-script.js"></script>'
        "</svg><figcaption>active content</figcaption></figure>"
        "<p onclick=\"fetch('https://example.test/event')\">event</p>"
        "</main>",
    )
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    for fragment in (
        "link elements",
        "meta refresh",
        "frame.html",
        "embed.bin",
        "captions.vtt",
        "button.png",
        "svg-script.js",
        "input type=image",
        "inline event handlers",
    ):
        assert any(fragment in error for error in errors), fragment


@pytest.mark.unit
def test_validator_surfaces_independent_contract_violations(tmp_path: Path) -> None:
    validator = load_script("validate_report")
    report = write_valid_report(tmp_path / "report")
    html = report.read_text(encoding="utf-8")
    for old, new in CONTRACT_CORRUPTIONS:
        html = html.replace(old, new)
    html = html.replace('href="#E1"', 'href="#missing"', 1)
    html = html.replace('data-supports="E1"', 'data-supports="E404"', 1)
    report.write_text(html, encoding="utf-8")
    errors = validator.validate_report(report)
    for fragment in EXPECTED_CONTRACT_ERRORS:
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
            {
                "status": "blocked",
                "claim": "E1",
                "environment": "",
                "artifacts": [],
                "audited_sources": [None],
            }
        ),
        encoding="utf-8",
    )
    errors = validator.validate_report(report)
    assert any("status" not in error and "claim" in error for error in errors)
    assert any("repository" in error and "code_status" in error for error in errors)
    assert any("artifacts" in error for error in errors)
    assert any("blocker" in error for error in errors)
    assert any("audited_sources" in error for error in errors)


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
