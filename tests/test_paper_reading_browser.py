import os
import shutil
from pathlib import Path
from typing import Any

import pytest
from paper_reading_helpers import SKILL_DIR, write_valid_report


def _playwright_entry() -> Any:
    try:
        from playwright.sync_api import sync_playwright
    except ModuleNotFoundError:
        if os.environ.get("PAPER_READING_REQUIRE_BROWSER") == "1":
            pytest.fail(
                "PAPER_READING_REQUIRE_BROWSER=1 but playwright is unavailable",
                pytrace=False,
            )
        pytest.skip(
            "playwright is optional for ordinary unit runs; set "
            "PAPER_READING_REQUIRE_BROWSER=1 in the browser verification gate"
        )
    return sync_playwright


def _browser_report(output_dir: Path) -> Path:
    script = (SKILL_DIR / "assets" / "report.js").read_text(encoding="utf-8")
    style = (SKILL_DIR / "assets" / "report.css").read_text(encoding="utf-8")
    report = write_valid_report(output_dir, script=script)
    svg = """<figure data-lightbox tabindex="0" role="button"
                   aria-label="SVG diagram, click to enlarge">
      <svg viewBox="0 0 20 20" role="img" aria-label="Test diagram">
        <style>#diagram-shape { clip-path: url("#diagram-clip"); fill: rgb(12, 34, 56); }</style>
        <defs><clipPath id="diagram-clip"><rect width="10" height="10"></rect></clipPath></defs>
        <g id="diagram-shape"><circle cx="5" cy="5" r="5"></circle></g>
      </svg><figcaption>SVG test</figcaption>
    </figure>"""
    html = report.read_text(encoding="utf-8").replace("</main>", f"{svg}</main>")
    style_start = html.index("<style>") + len("<style>")
    style_end = html.index("</style>", style_start)
    html = f"{html[:style_start]}{style}{html[style_end:]}"
    report.write_text(html, encoding="utf-8")
    return report


def _assert_lightboxes(page: Any) -> None:
    page.locator("figure[data-lightbox]").first.click()
    assert page.locator("#lightbox").evaluate("node => node.open") is True
    page.keyboard.press("Escape")
    assert page.locator("#lightbox").evaluate("node => node.open") is False
    svg_figure = page.locator("figure[data-lightbox]").nth(1)
    svg_figure.click()
    assert page.locator("#diagram-clip").count() == 1
    assert page.locator("#lightbox #diagram-clip").count() == 1
    assert (
        page.locator("#lightbox #diagram-shape").evaluate(
            "node => getComputedStyle(node).fill"
        )
        == "rgb(12, 34, 56)"
    )
    assert "diagram-clip" in page.locator("#lightbox #diagram-shape").evaluate(
        "node => getComputedStyle(node).clipPath"
    )
    page.keyboard.press("Escape")
    page.wait_for_function(
        "document.querySelectorAll('figure[data-lightbox] #diagram-clip').length === 1"
    )
    assert svg_figure.locator("#diagram-clip").count() == 1


def _assert_lenses_and_trace(page: Any) -> None:
    page.locator('[data-lens="evidence"]').click()
    assert page.locator('[data-lenses="method"]').first.evaluate(
        "node => node.classList.contains('is-dimmed')"
    )
    assert not page.locator('[data-lenses="evidence"]').evaluate(
        "node => node.classList.contains('is-dimmed')"
    )
    page.locator('[data-trace="C1"]').click()
    assert page.locator("#C1").evaluate(
        "node => node.classList.contains('trace-origin')"
    )
    assert page.locator("#E1").evaluate(
        "node => node.classList.contains('trace-active')"
    )
    page.locator('[data-trace="E1"]').click()
    assert page.locator("#C1").evaluate(
        "node => node.classList.contains('trace-active')"
    )


def _assert_reading_surface(page: Any) -> None:
    assert page.locator("nav").count() == 1
    assert page.locator("nav.reader-nav[data-reader-navigation]").count() == 1
    assert (
        page.locator(".report-hero .paper-fingerprint, .report-hero .eyebrow").count()
        == 0
    )
    assert page.locator("h1 .title-focus").count() == 1
    sizes = page.evaluate(
        """() => ({
          body: parseFloat(getComputedStyle(document.body).fontSize),
          title: parseFloat(getComputedStyle(document.querySelector('h1')).fontSize)
        })"""
    )
    assert sizes["title"] / sizes["body"] <= 2.6


def _assert_wheel_zoom(page: Any) -> None:
    page.locator("figure[data-lightbox]").first.click()
    stage = page.locator("#lightbox .lightbox-stage")
    visual = stage.locator("img, svg").first
    box = visual.bounding_box()
    assert box is not None
    viewport = page.viewport_size
    assert viewport is not None
    assert box["width"] <= viewport["width"] * 0.86
    assert box["height"] <= viewport["height"] * 0.78
    stage_box = stage.bounding_box()
    assert stage_box is not None
    page.mouse.move(
        stage_box["x"] + stage_box["width"] / 2,
        stage_box["y"] + stage_box["height"] / 2,
    )
    before = float(stage.get_attribute("data-zoom") or "1")
    scroll_before = page.evaluate(
        "() => ({page: window.scrollY, stage: document.querySelector('.lightbox-stage').scrollTop})"
    )
    page.mouse.wheel(0, -260)
    page.wait_for_timeout(50)
    assert float(stage.get_attribute("data-zoom") or "1") > before
    assert (
        page.evaluate(
            "() => ({page: window.scrollY, stage: document.querySelector('.lightbox-stage').scrollTop})"
        )
        == scroll_before
    )
    page.keyboard.press("Escape")


def _assert_pinch_zoom(page: Any, report: Path) -> None:
    page.goto(report.as_uri())
    page.locator("figure[data-lightbox]").first.click()
    dialog_box = page.locator("#lightbox").bounding_box()
    caption_box = page.locator("#lightbox .lightbox-caption").bounding_box()
    assert dialog_box is not None
    assert caption_box is not None
    assert (
        caption_box["y"] + caption_box["height"]
        <= dialog_box["y"] + dialog_box["height"]
    )
    stage = page.locator("#lightbox .lightbox-stage")
    before = float(stage.get_attribute("data-zoom") or "1")
    for event, payload in (
        ("pointerdown", {"pointerId": 1, "clientX": 120, "clientY": 300}),
        ("pointerdown", {"pointerId": 2, "clientX": 220, "clientY": 300}),
        ("pointermove", {"pointerId": 2, "clientX": 290, "clientY": 300}),
        ("pointerup", {"pointerId": 1, "clientX": 120, "clientY": 300}),
        ("pointerup", {"pointerId": 2, "clientX": 290, "clientY": 300}),
    ):
        stage.dispatch_event(event, {**payload, "pointerType": "touch"})
    assert float(stage.get_attribute("data-zoom") or "1") > before


@pytest.mark.e2e
def test_html_interactions_work_in_a_real_browser(tmp_path: Path) -> None:
    sync_playwright = _playwright_entry()
    chrome = shutil.which("google-chrome") or shutil.which("chromium")
    with sync_playwright() as playwright:
        options: dict[str, Any] = {"headless": True}
        if chrome:
            options["executable_path"] = chrome
        browser = playwright.chromium.launch(**options)
        page = browser.new_page(viewport={"width": 1200, "height": 900})
        report = _browser_report(tmp_path / "report")
        page.goto(report.as_uri())
        assert page.locator("html").get_attribute("data-enhanced") == "true"
        _assert_reading_surface(page)
        _assert_lightboxes(page)
        _assert_lenses_and_trace(page)
        _assert_wheel_zoom(page)
        mobile = browser.new_page(
            viewport={"width": 390, "height": 844}, has_touch=True
        )
        _assert_pinch_zoom(mobile, report)
        browser.close()
