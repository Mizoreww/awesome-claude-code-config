from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[1]
SKILL_DIR = ROOT / "skills" / "paper-reading"
SCRIPTS_DIR = SKILL_DIR / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))


def load_script(name: str) -> ModuleType:
    path = SCRIPTS_DIR / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"paper_reading_{name}", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


PNG_FIXTURE = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
    "890000000d49444154789c6360606060000000050001a5f64540000000004945"
    "4e44ae426082"
)
DEEP_SECTION = """
        <section id="R1" data-section="reproduction" data-kind="reproduction"
                 data-coordinate="R1">
          <h2>最小复现</h2><p>复现记录见本地 manifest。</p>
        </section>
        """
REPORT_TEMPLATE = """<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>测试论文精读</title>
  <style>
    dialog[open] {{ display: block; }}
  </style>
</head>
<body>
  <article data-paper-report data-level="{level}" data-paper-type="{paper_type}">
    <header class="report-hero">
      <h1>测试论文<em class="title-focus">精读</em></h1>
      <p class="hero-thesis">一条可核查的核心判断。</p>
    </header>
    <div class="proof-layout">
    <nav class="reader-nav" data-reader-navigation aria-label="阅读导航">
      <div class="outline-links">
        <a href="#C1">研究问题</a><a href="#E1">实验结果</a><a href="#L1">批判分析</a>
      </div>
    </nav>
    <main id="report-content">
      <section data-section="basic-information">
        <h2>基本信息</h2>
        <ul class="paper-facts" data-paper-facts>
          <li data-paper-field="title"><strong>标题:</strong> 测试论文</li>
          <li data-paper-field="authors"><strong>作者:</strong>
            <a data-author-homepage href="https://example.test/author">测试作者</a>
          </li>
          <li data-paper-field="contact"><strong>通讯作者 / 论文联系人:</strong>
            <a data-contact-homepage href="https://example.test/contact">测试联系人</a>
          </li>
          <li data-paper-field="affiliation"><strong>机构 / 实验室:</strong>
            <a data-lab-homepage href="https://example.test/lab">测试实验室（测试大学）</a>
          </li>
          <li data-paper-field="published"><strong>发表信息:</strong> 2026</li>
          <li data-paper-field="link"><strong>链接:</strong>
            <a href="https://example.test/paper">论文主页</a>
          </li>
          <li data-paper-field="paper-type"><strong>论文类型:</strong> Empirical</li>
          <li data-paper-field="one-line-summary"><strong>一句话总结:</strong> 一条可核查的判断。</li>
        </ul>
      </section>
      <section id="C1" data-section="research-problem" data-kind="claim"
               data-coordinate="C1" data-supports="E1">
        <h2>研究问题</h2><p>问题定义。</p>
      </section>
      <section id="C2" data-section="key-insight" data-kind="claim"
               data-coordinate="C2" data-supports="E1">
        <h2>关键洞见</h2><p>机制解释。</p>
      </section>
      <section id="C3" data-section="technical-method" data-kind="claim"
               data-coordinate="C3" data-supports="E1">
        <h2>技术方法</h2><p>训练目标。</p>
      </section>
      <section id="E1" data-section="experimental-results" data-kind="evidence"
               data-coordinate="E1">
        <h2>实验结果</h2>
        <figure data-lightbox tabindex="0" role="button" aria-label="主结果图，点击放大">
          <img src="assets/figure.png" alt="主结果图">
          <figcaption>E1 · Figure 1：这是一段刻意较长的图注，用来验证手机窄屏打开图片时，说明文字仍完整留在查看器内，并且不会被底部边界裁掉。</figcaption>
        </figure>
      </section>
      <section id="L1" data-section="critical-analysis" data-kind="limitation"
               data-coordinate="L1" data-supports="E1">
        <h2>批判分析</h2><p>一项有边界的限制。</p>
      </section>
      {deep_section}
      <section data-section="summary"><h2>总结与评价</h2><p>结论。</p></section>
    </main>
    </div>
  </article>
  <dialog id="lightbox" aria-label="大图查看器">
    <button type="button" data-lightbox-close aria-label="关闭大图">关闭</button>
    <div class="lightbox-controls" aria-label="图像缩放">
      <button type="button" data-zoom-out aria-label="缩小">−</button>
      <button type="button" data-zoom-reset aria-label="重置缩放">100%</button>
      <button type="button" data-zoom-in aria-label="放大">+</button>
    </div>
    <div class="lightbox-stage" data-zoom="1"></div><p class="lightbox-caption"></p>
  </dialog>
  <script data-report-script>{script}</script>
</body>
</html>
"""


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
    (assets_dir / "figure.png").write_bytes(PNG_FIXTURE)
    html = REPORT_TEMPLATE.format(
        level=level,
        paper_type=paper_type,
        deep_section=DEEP_SECTION if level == "deep" else "",
        script=script,
    )
    path = output_dir / "summary.html"
    path.write_text(html, encoding="utf-8")
    return path
