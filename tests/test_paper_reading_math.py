import xml.etree.ElementTree as ET
from pathlib import Path
from types import ModuleType

import pytest
from paper_reading_helpers import load_script


def _fake_converter(latex: str, *, display: str) -> str:
    return (
        f'<math xmlns="http://www.w3.org/1998/Math/MathML" display="{display}">'
        f"<mrow><mi>{latex[0]}</mi><mo>=</mo><mn>1</mn></mrow></math>"
    )


def _use_test_parser(renderer: ModuleType, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(renderer, "_load_xml_parser", lambda: ET.fromstring)


@pytest.mark.unit
def test_math_renderer_emits_static_mathml_and_tex_annotation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    renderer = load_script("render_math")
    _use_test_parser(renderer, monkeypatch)
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
def test_math_renderer_supports_inline_math_and_rejects_empty_input(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    renderer = load_script("render_math")
    _use_test_parser(renderer, monkeypatch)
    fragment = renderer.render_math("x=1", display="inline", converter=_fake_converter)
    assert fragment.startswith('<span class="math-inline"')
    with pytest.raises(ValueError, match="empty"):
        renderer.render_math("  ", display="block", converter=_fake_converter)


@pytest.mark.unit
def test_math_renderer_rejects_xml_entities() -> None:
    pytest.importorskip("defusedxml")
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


@pytest.mark.unit
@pytest.mark.parametrize(
    "body",
    (
        '<mi xmlns="https://example.test/not-mathml">x</mi>',
        '<mi xmlns:foreign="https://example.test/attrs" foreign:width="10">x</mi>',
    ),
)
def test_math_renderer_rejects_foreign_xml_namespaces(
    body: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    renderer = load_script("render_math")
    _use_test_parser(renderer, monkeypatch)

    def namespaced_converter(latex: str, *, display: str) -> str:
        del latex, display
        return f'<math xmlns="http://www.w3.org/1998/Math/MathML">{body}</math>'

    with pytest.raises(ValueError, match="unsafe MathML"):
        renderer.render_math("x", converter=namespaced_converter)


@pytest.mark.integration
@pytest.mark.parametrize(
    "latex",
    (
        r"\style{position:fixed;inset:0;z-index:9999}{x}",
        r"\href{javascript:alert(1)}{x}",
    ),
)
def test_math_renderer_rejects_unsafe_real_converter_output(latex: str) -> None:
    pytest.importorskip("latex2mathml")
    pytest.importorskip("defusedxml")
    renderer = load_script("render_math")
    with pytest.raises(ValueError, match="unsafe MathML"):
        renderer.render_math(latex)


@pytest.mark.integration
def test_math_renderer_reserializes_converter_text_before_html_embedding() -> None:
    pytest.importorskip("latex2mathml")
    pytest.importorskip("defusedxml")
    renderer = load_script("render_math")
    latex = (
        r"\text{<![CDATA[</mtext></math><script>"
        r"globalThis.__unexpectedMathScript=1</script><math><mtext>]]>}"
    )
    fragment = renderer.render_math(latex, display="inline")
    assert "<![CDATA[" not in fragment
    assert "<script>" not in fragment
    assert "&lt;script&gt;" in fragment


@pytest.mark.integration
@pytest.mark.parametrize(
    "latex",
    (
        r"\frac{\sum_{i=1}^{n}x_i}{\sqrt{n}}",
        r"\begin{bmatrix}a & b \\ c & d\end{bmatrix}",
        r"\operatorname{sg}[f_\theta(\varepsilon)]",
    ),
)
def test_math_renderer_accepts_safe_real_converter_output(latex: str) -> None:
    pytest.importorskip("latex2mathml")
    pytest.importorskip("defusedxml")
    renderer = load_script("render_math")
    assert "<math" in renderer.render_math(latex)


@pytest.mark.integration
def test_math_renderer_cli_reads_a_tex_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    renderer = load_script("render_math")
    source = tmp_path / "equation.tex"
    source.write_text(r"\mathcal{L}(\theta)=0", encoding="utf-8")
    monkeypatch.setattr(renderer, "_load_converter", lambda: _fake_converter)
    _use_test_parser(renderer, monkeypatch)
    assert renderer.main([str(source), "--display", "block"]) == 0
    assert 'class="math-display"' in capsys.readouterr().out
