from pathlib import Path

import pytest
from paper_reading_helpers import load_script


def _fake_converter(latex: str, *, display: str) -> str:
    return (
        f'<math xmlns="http://www.w3.org/1998/Math/MathML" display="{display}">'
        f"<mrow><mi>{latex[0]}</mi><mo>=</mo><mn>1</mn></mrow></math>"
    )


@pytest.mark.unit
def test_math_renderer_emits_static_mathml_and_tex_annotation() -> None:
    renderer = load_script("render_math")
    fragment = renderer.render_math(
        r"x_1 = 1 & y", display="block", converter=_fake_converter
    )
    assert fragment.startswith('<div class="math-display"')
    assert (
        '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">' in fragment
    )
    assert (
        '<annotation encoding="application/x-tex">x_1 = 1 &amp; y</annotation>'
        in fragment
    )
    assert "<code" not in fragment
    assert "<pre" not in fragment


@pytest.mark.unit
def test_math_renderer_supports_inline_math_and_rejects_empty_input() -> None:
    renderer = load_script("render_math")
    fragment = renderer.render_math("x=1", display="inline", converter=_fake_converter)
    assert fragment.startswith('<span class="math-inline"')
    with pytest.raises(ValueError, match="empty"):
        renderer.render_math("  ", display="block", converter=_fake_converter)


@pytest.mark.unit
def test_math_renderer_rejects_xml_entities() -> None:
    renderer = load_script("render_math")

    def unsafe_converter(latex: str, *, display: str) -> str:
        del latex, display
        return (
            '<!DOCTYPE math [<!ENTITY external SYSTEM "file:///etc/passwd">]>'
            '<math xmlns="http://www.w3.org/1998/Math/MathML">'
            "<mi>&external;</mi></math>"
        )

    with pytest.raises(ValueError, match="invalid MathML"):
        renderer.render_math("x", converter=unsafe_converter)


@pytest.mark.integration
def test_math_renderer_cli_reads_a_tex_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    renderer = load_script("render_math")
    source = tmp_path / "equation.tex"
    source.write_text(r"\mathcal{L}(\theta)=0", encoding="utf-8")
    monkeypatch.setattr(renderer, "_load_converter", lambda: _fake_converter)
    assert renderer.main([str(source), "--display", "block"]) == 0
    assert 'class="math-display"' in capsys.readouterr().out
