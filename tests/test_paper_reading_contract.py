import re
from pathlib import Path

import pytest
from paper_reading_helpers import SKILL_DIR, load_script


@pytest.mark.unit
def test_scaffold_uses_one_reading_depth_and_exposes_module_anatomy(
    tmp_path: Path,
) -> None:
    scaffold = load_script("scaffold_report")
    output_dir = tmp_path / "report"
    path = scaffold.scaffold_report(
        output_dir=output_dir,
        title="A Modular Paper",
        title_focus="Modular",
        authors="Ada",
        paper_type="empirical",
        thesis="A verified technical thesis.",
    )
    html = path.read_text(encoding="utf-8")

    assert "data-level=" not in html
    assert "--level" not in scaffold.build_parser().format_help()
    assert not (output_dir / "reproduction").exists()
    assert "data-module-anatomy" in html
    assert 'data-module="replace-with-module-name"' in html
    assert "data-module-visual" in html
    assert '<svg class="module-diagram" viewBox="0 0 960 240" role="img"' in html
    assert html.count('class="diagram-node diagram-input"') == 2
    assert html.count('class="diagram-node diagram-output"') == 2
    assert html.count('class="module-io-list"') == 2
    assert html.count('class="math-inline"') >= 4
    for field in (
        "purpose",
        "inputs",
        "outputs",
        "architecture",
        "training-data",
        "training-method",
        "inference-role",
        "interfaces",
        "code-evidence",
    ):
        assert f'data-module-field="{field}"' in html


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
    assert "uv run --isolated --no-project" in text
    assert "references/levels.md" not in text
    assert "references/evidence.md" in text
    assert "references/code-audit.md" in text
    assert "references/html-report.md" in text
    assert "references/visuals.md" in text
    assert "references/reproduction.md" not in text
    for paper_type in ("empirical", "theoretical", "survey", "systems"):
        assert f"references/{paper_type}.md" in text
    assert "scripts/extract_paper.py" in text
    assert "scripts/render_math.py" in text
    assert "scripts/scaffold_report.py" in text
    assert "scripts/validate_report.py" in text

    html_guidance = (SKILL_DIR / "references" / "html-report.md").read_text(
        encoding="utf-8"
    )
    assert "\npython <skill-dir>" not in html_guidance
    assert "PYTHON_EXE" in html_guidance
    assert "latex2mathml==3.78.1" in html_guidance
    assert "defusedxml==0.7.1" in html_guidance
    assert "--explanation" in html_guidance
    assert "data-paper-facts" in html_guidance
    assert "data-author-homepage" in html_guidance
    assert "data-contact-homepage" in html_guidance
    assert "data-lab-homepage" in html_guidance
    assert "data-affiliation-fallback" in html_guidance
    code_guidance = (SKILL_DIR / "references" / "code-audit.md").read_text(
        encoding="utf-8"
    )
    assert "shallow clone" in code_guidance
    assert "Do not install, import, execute" in code_guidance
    assert not (SKILL_DIR / "references" / "levels.md").exists()
    assert not (SKILL_DIR / "references" / "reproduction.md").exists()

    script = (SKILL_DIR / "assets" / "report.js").read_text(encoding="utf-8")
    assert not re.search(r"\bview\.(?:x|y|scale)\s*=", script)
    assert "pointers.set(" not in script
    assert 'lightbox.setAttribute("open"' not in script
    assert 'lightbox.removeAttribute("open"' not in script
    assert "data-lens" not in script
    assert "data-trace" not in script
    style = (SKILL_DIR / "assets" / "report.css").read_text(encoding="utf-8")
    module_card_rule = re.search(r"\.module-card\s*\{(?P<body>[^}]*)\}", style)
    assert module_card_rule is not None
    assert "grid-template-columns: minmax(0, 1fr)" in module_card_rule.group("body")
    module_visual_rule = re.search(
        r"\.module-card figure\.module-visual\s*\{(?P<body>[^}]*)\}", style
    )
    assert module_visual_rule is not None
    assert "grid-column: 1 / -1" in module_visual_rule.group("body")
    assert "grid-row: auto" in module_visual_rule.group("body")
    inline_rule = re.search(r"(?m)^\.math-inline\s*\{(?P<body>[^}]*)\}", style)
    assert inline_rule is not None
    assert "display: inline-block" in inline_rule.group("body")
    assert "overflow: visible" in inline_rule.group("body")
    assert ".equation-explanation::before" not in style
    policy = SKILL_DIR / "scripts" / "mathml_policy.py"
    assert policy.is_file()
    for consumer in ("render_math.py", "validate_report.py"):
        assert "from mathml_policy import" in (
            SKILL_DIR / "scripts" / consumer
        ).read_text(encoding="utf-8")


@pytest.mark.unit
def test_scaffold_escapes_metadata_and_creates_single_report_directory(
    tmp_path: Path,
) -> None:
    scaffold = load_script("scaffold_report")
    output_dir = tmp_path / "report"
    summary_path = scaffold.scaffold_report(
        output_dir=output_dir,
        title="A <B> & C",
        authors="Ada & Lin",
        paper_type="empirical",
        thesis="A claim grounded in the paper.",
        title_focus="<B>",
        language="zh-CN",
        source="https://example.test/paper",
    )
    html = summary_path.read_text(encoding="utf-8")
    assert "A &lt;B&gt; &amp; C" in html
    assert '<em class="title-focus">&lt;B&gt;</em>' in html
    assert html.count("<nav ") == 1
    assert "data-reader-navigation" in html
    assert "paper-fingerprint" not in html
    assert "evidence-rail" not in html
    assert "reading-lenses" not in html
    assert "data-evidence-index" not in html
    assert "data-lens=" not in html
    assert "data-trace=" not in html
    assert "data-paper-facts" in html
    assert 'data-paper-field="title"' in html
    assert "<table" not in html
    assert "Ada &amp; Lin" in html
    assert "data-level=" not in html
    assert "<style data-report-style>" in html
    assert "<script data-report-script>" in html
    assert not (output_dir / "report.css").exists()
    assert (output_dir / "assets").is_dir()
    assert not (output_dir / "reproduction").exists()


@pytest.mark.unit
def test_scaffold_requires_a_title_focus_from_the_title(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    with pytest.raises(ValueError, match="title focus"):
        scaffold.scaffold_report(
            output_dir=tmp_path / "report",
            title="Paper",
            authors="Author",
            paper_type="empirical",
            thesis="Thesis",
            title_focus="Missing",
        )


@pytest.mark.unit
def test_scaffold_rejects_an_unsafe_source_link(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    with pytest.raises(ValueError, match="source URL"):
        scaffold.scaffold_report(
            output_dir=tmp_path / "report",
            title="Paper",
            authors="Author",
            paper_type="empirical",
            thesis="Thesis",
            title_focus="Paper",
            source="javascript:alert(1)",
        )


@pytest.mark.unit
def test_scaffold_does_not_expand_tokens_inside_user_metadata(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    path = scaffold.scaffold_report(
        output_dir=tmp_path / "report",
        title="<img src=x onerror=alert(1)>{{SOURCE_LINK}}",
        authors="Author",
        paper_type="empirical",
        thesis="Thesis",
        title_focus="{{SOURCE_LINK}}",
        source="https://example.test/paper",
    )
    html = path.read_text(encoding="utf-8")
    assert "&lt;img src=x onerror=alert(1)&gt;{{SOURCE_LINK}}" in html
    assert html.count('<a class="nav-source" href="https://example.test/paper">') == 1


@pytest.mark.unit
def test_scaffold_localizes_visible_ui_and_accessible_names(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    path = scaffold.scaffold_report(
        output_dir=tmp_path / "report-en",
        title="Paper",
        authors="Author",
        paper_type="empirical",
        thesis="Specific thesis.",
        title_focus="Paper",
        language="en-US",
        source="https://example.test/paper",
    )
    html = path.read_text(encoding="utf-8")
    for expected in (
        '<html lang="en-US">',
        "Skip to report",
        'aria-label="Reading navigation"',
        'aria-label="Enlarged visual viewer"',
        'aria-label="Close enlarged visual"',
        'aria-label="Image zoom"',
        'aria-label="Zoom in"',
        "View source",
        "Basic information",
        "Corresponding author / paper contact",
        "One-line summary",
        "Research problem",
        "Critical analysis",
    ):
        assert expected in html
    for removed_control in (
        "Reading lenses",
        "Evidence index",
        "data-lens=",
        "data-trace=",
    ):
        assert removed_control not in html
    for chinese_ui in ("跳到正文", "阅读视角", "文章目录", "关闭大图", "查看原文"):
        assert chinese_ui not in html


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
        thesis="Specific thesis.",
        title_focus="Paper",
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
        ({"language": "fr-FR"}, "language"),
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
        "thesis": "Thesis",
        "title_focus": "Paper",
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
            thesis="Thesis",
            title_focus="Paper",
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
        "--thesis",
        "Thesis",
        "--title-focus",
        "Paper",
    ]
    assert scaffold.main(argv) == 0
    assert "summary.html" in capsys.readouterr().out
    assert scaffold.main(argv) == 2
    assert "not empty" in capsys.readouterr().err
