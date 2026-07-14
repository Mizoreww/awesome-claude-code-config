(() => {
  "use strict";

  document.documentElement.dataset.enhanced = "true";

  const lightbox = document.querySelector("#lightbox");
  const stage = lightbox?.querySelector(".lightbox-stage");
  const caption = lightbox?.querySelector(".lightbox-caption");
  const resetControl = lightbox?.querySelector("[data-zoom-reset]");
  const pointers = new Map();
  const view = { scale: 1, x: 0, y: 0 };
  let pinch = null;
  let previousFocus = null;
  let activeVisual = null;
  let movedSvg = null;
  let svgPlaceholder = null;

  const clamp = (value, minimum, maximum) => Math.min(maximum, Math.max(minimum, value));

  function restoreMovedSvg() {
    activeVisual?.style.removeProperty("transform");
    if (movedSvg && svgPlaceholder?.isConnected) svgPlaceholder.replaceWith(movedSvg);
    activeVisual = null;
    movedSvg = null;
    svgPlaceholder = null;
  }

  function clampPan() {
    if (!stage || !activeVisual || view.scale <= 1) {
      view.x = 0;
      view.y = 0;
      return;
    }
    const visualBox = activeVisual.getBoundingClientRect();
    const maxX = Math.max(0, (visualBox.width / view.scale * view.scale - stage.clientWidth) / 2);
    const maxY = Math.max(0, (visualBox.height / view.scale * view.scale - stage.clientHeight) / 2);
    view.x = clamp(view.x, -maxX, maxX);
    view.y = clamp(view.y, -maxY, maxY);
  }

  function renderView() {
    if (!stage || !activeVisual) return;
    activeVisual.style.transform = `translate3d(${view.x}px, ${view.y}px, 0) scale(${view.scale})`;
    stage.dataset.zoom = view.scale.toFixed(2);
    stage.classList.toggle("is-zoomed", view.scale > 1.01);
    if (resetControl) resetControl.textContent = `${Math.round(view.scale * 100)}%`;
  }

  function resetView() {
    view.scale = 1;
    view.x = 0;
    view.y = 0;
    pointers.clear();
    pinch = null;
    stage?.classList.remove("is-dragging", "is-zoomed");
    renderView();
  }

  function setZoom(nextScale, clientX, clientY) {
    if (!stage || !activeVisual) return;
    const next = clamp(nextScale, 1, 5);
    const bounds = stage.getBoundingClientRect();
    const anchorX = clientX - bounds.left - bounds.width / 2;
    const anchorY = clientY - bounds.top - bounds.height / 2;
    const ratio = next / view.scale;
    view.x = anchorX - (anchorX - view.x) * ratio;
    view.y = anchorY - (anchorY - view.y) * ratio;
    view.scale = next;
    clampPan();
    renderView();
  }

  function zoomFromCenter(factor) {
    if (!stage) return;
    const bounds = stage.getBoundingClientRect();
    setZoom(view.scale * factor, bounds.left + bounds.width / 2, bounds.top + bounds.height / 2);
  }

  function finishClose() {
    resetView();
    restoreMovedSvg();
    if (previousFocus instanceof HTMLElement) previousFocus.focus();
    previousFocus = null;
  }

  function openLightbox(figure) {
    if (!lightbox || !stage || !caption) return;
    const visual = figure.querySelector("img, svg");
    if (!visual) return;
    previousFocus = document.activeElement;
    restoreMovedSvg();
    stage.replaceChildren();
    if (visual instanceof HTMLImageElement) {
      const expanded = new Image();
      expanded.src = visual.currentSrc || visual.src;
      expanded.alt = visual.alt;
      stage.append(expanded);
      activeVisual = expanded;
    } else {
      svgPlaceholder = document.createComment("paper-report-svg-placeholder");
      visual.replaceWith(svgPlaceholder);
      stage.append(visual);
      movedSvg = visual;
      activeVisual = visual;
    }
    caption.textContent = figure.querySelector("figcaption")?.textContent?.trim()
      || visual.getAttribute("aria-label") || visual.getAttribute("alt") || "";
    if (typeof lightbox.showModal === "function") lightbox.showModal();
    else lightbox.setAttribute("open", "");
    resetView();
  }

  function closeLightbox() {
    if (!lightbox) return;
    if (typeof lightbox.close === "function" && lightbox.open) lightbox.close();
    else {
      lightbox.removeAttribute("open");
      finishClose();
    }
  }

  function pointerDistance(first, second) {
    return Math.hypot(second.x - first.x, second.y - first.y);
  }

  function pointerCenter(first, second) {
    return { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 };
  }

  function startPointer(event) {
    if (!stage || (event.pointerType === "mouse" && event.button !== 0)) return;
    const point = { x: event.clientX, y: event.clientY };
    pointers.set(event.pointerId, point);
    if (pointers.size === 2) {
      const [first, second] = [...pointers.values()];
      pinch = { distance: pointerDistance(first, second), scale: view.scale };
    } else if (view.scale > 1) stage.classList.add("is-dragging");
    try { stage.setPointerCapture(event.pointerId); } catch { /* synthetic test event */ }
    event.preventDefault();
  }

  function movePointer(event) {
    if (!stage || !pointers.has(event.pointerId)) return;
    const previous = pointers.get(event.pointerId);
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (pointers.size >= 2) {
      const [first, second] = [...pointers.values()];
      if (!pinch) pinch = { distance: pointerDistance(first, second), scale: view.scale };
      const center = pointerCenter(first, second);
      setZoom(pinch.scale * pointerDistance(first, second) / pinch.distance, center.x, center.y);
    } else if (previous && view.scale > 1) {
      view.x += event.clientX - previous.x;
      view.y += event.clientY - previous.y;
      clampPan();
      renderView();
    }
    event.preventDefault();
  }

  function endPointer(event) {
    pointers.delete(event.pointerId);
    if (pointers.size < 2) pinch = null;
    if (!pointers.size) stage?.classList.remove("is-dragging");
  }

  document.querySelectorAll("figure[data-lightbox]").forEach((figure) => {
    figure.addEventListener("click", () => openLightbox(figure));
    figure.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      openLightbox(figure);
    });
  });

  lightbox?.querySelector("[data-lightbox-close]")?.addEventListener("click", closeLightbox);
  lightbox?.querySelector("[data-zoom-out]")?.addEventListener("click", () => zoomFromCenter(1 / 1.25));
  lightbox?.querySelector("[data-zoom-in]")?.addEventListener("click", () => zoomFromCenter(1.25));
  resetControl?.addEventListener("click", resetView);
  lightbox?.addEventListener("click", (event) => {
    if (event.target === lightbox) closeLightbox();
  });
  lightbox?.addEventListener("close", finishClose);
  stage?.addEventListener("wheel", (event) => {
    event.preventDefault();
    setZoom(view.scale * Math.exp(-event.deltaY * .0015), event.clientX, event.clientY);
  }, { passive: false });
  stage?.addEventListener("pointerdown", startPointer);
  stage?.addEventListener("pointermove", movePointer);
  stage?.addEventListener("pointerup", endPointer);
  stage?.addEventListener("pointercancel", endPointer);

  const readerNav = document.querySelector(".reader-nav");
  const navToggle = readerNav?.querySelector(".reader-nav-toggle");
  const mobileNavigation = window.matchMedia("(max-width: 720px)");
  if (readerNav && navToggle) {
    const expanded = !mobileNavigation.matches;
    readerNav.classList.toggle("is-open", expanded);
    navToggle.setAttribute("aria-expanded", String(expanded));
    navToggle.addEventListener("click", () => {
      const open = readerNav.classList.toggle("is-open");
      navToggle.setAttribute("aria-expanded", String(open));
    });
  }

  const lensButtons = document.querySelectorAll("[data-lens]");
  const lensBlocks = document.querySelectorAll("[data-lenses]");
  lensButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const lens = button.dataset.lens || "all";
      lensButtons.forEach((candidate) => candidate.classList.toggle("active", candidate === button));
      lensBlocks.forEach((block) => {
        const lenses = (block.dataset.lenses || "").split(/\s+/).filter(Boolean);
        block.classList.toggle("is-dimmed", lens !== "all" && !lenses.includes(lens));
      });
    });
  });

  const outlineLinks = [...document.querySelectorAll(".outline-links a[href^='#']")];
  const observedSections = outlineLinks
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter(Boolean);
  if ("IntersectionObserver" in window && observedSections.length) {
    const observer = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!visible) return;
      outlineLinks.forEach((link) => {
        link.classList.toggle("active", link.getAttribute("href") === `#${visible.target.id}`);
      });
    }, { rootMargin: "-16% 0px -68%", threshold: [0, .2, .6] });
    observedSections.forEach((section) => observer.observe(section));
  }

  function traceCoordinate(coordinate) {
    const blocks = [...document.querySelectorAll("[data-coordinate]")];
    blocks.forEach((block) => block.classList.remove("trace-active", "trace-origin"));
    document.querySelectorAll("[data-trace]").forEach((control) => {
      control.classList.toggle("trace-active", control.dataset.trace === coordinate);
    });
    const origin = blocks.find((block) => block.dataset.coordinate === coordinate);
    if (!origin) return;
    origin.classList.add("trace-active", "trace-origin");
    const related = new Set((origin.dataset.supports || "").split(/\s+/).filter(Boolean));
    blocks.forEach((block) => {
      const supports = (block.dataset.supports || "").split(/\s+/).filter(Boolean);
      if (supports.includes(coordinate)) related.add(block.dataset.coordinate);
    });
    blocks.forEach((block) => {
      if (related.has(block.dataset.coordinate)) block.classList.add("trace-active");
    });
  }

  document.querySelectorAll("[data-trace]").forEach((control) => {
    control.addEventListener("click", () => traceCoordinate(control.dataset.trace));
  });
})();
