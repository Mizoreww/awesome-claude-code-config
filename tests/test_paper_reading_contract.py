from pathlib import Path

import pytest
from paper_reading_helpers import SKILL_DIR, load_script


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
def test_scaffold_rejects_an_unsafe_source_link(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    with pytest.raises(ValueError, match="source URL"):
        scaffold.scaffold_report(
            output_dir=tmp_path / "report",
            title="Paper",
            authors="Author",
            paper_type="empirical",
            level="brief",
            thesis="Thesis",
            fingerprints=["one", "two"],
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
        level="brief",
        thesis="Thesis",
        fingerprints=["one", "two"],
        source="https://example.test/paper",
    )
    html = path.read_text(encoding="utf-8")
    assert "&lt;img src=x onerror=alert(1)&gt;{{SOURCE_LINK}}" in html
    assert html.count('<a href="https://example.test/paper">') == 1


@pytest.mark.unit
def test_scaffold_localizes_visible_ui_and_accessible_names(tmp_path: Path) -> None:
    scaffold = load_script("scaffold_report")
    path = scaffold.scaffold_report(
        output_dir=tmp_path / "report-en",
        title="Paper",
        authors="Author",
        paper_type="empirical",
        level="compact",
        thesis="Specific thesis.",
        fingerprints=["concept-a", "concept-b"],
        language="en-US",
        source="https://example.test/paper",
    )
    html = path.read_text(encoding="utf-8")
    for expected in (
        '<html lang="en-US">',
        "Skip to report",
        'aria-label="Reading lenses"',
        "Argument map",
        "Claim C",
        "Evidence E",
        "Limitation L",
        'aria-label="Evidence index"',
        'aria-label="Enlarged visual viewer"',
        'aria-label="Close enlarged visual"',
        "View source",
        "Basic information",
        "Research problem",
        "Critical analysis",
    ):
        assert expected in html
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
