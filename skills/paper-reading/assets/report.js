(() => {
  "use strict";

  document.documentElement.dataset.enhanced = "true";

  const lightbox = document.querySelector("#lightbox");
  const stage = lightbox?.querySelector(".lightbox-stage");
  const caption = lightbox?.querySelector(".lightbox-caption");
  let previousFocus = null;
  let svgCloneSerial = 0;

  function cloneSvgForLightbox(svg) {
    const expanded = svg.cloneNode(true);
    const serial = ++svgCloneSerial;
    const idMap = new Map();
    const identified = [expanded, ...expanded.querySelectorAll("[id]")]
      .filter((element) => element.id);

    identified.forEach((element, index) => {
      const oldId = element.id;
      const newId = `lightbox-svg-${serial}-${index}`;
      idMap.set(oldId, newId);
      element.id = newId;
    });

    [expanded, ...expanded.querySelectorAll("*")].forEach((element) => {
      element.getAttributeNames().forEach((name) => {
        const value = element.getAttribute(name);
        if (!value) return;
        let rewritten = value.replace(/url\((['"]?)#([^)'"]+)\1\)/g, (match, quote, id) => {
          const replacement = idMap.get(id);
          return replacement ? `url(${quote}#${replacement}${quote})` : match;
        });
        if (rewritten.startsWith("#") && idMap.has(rewritten.slice(1))) {
          rewritten = `#${idMap.get(rewritten.slice(1))}`;
        }
        if (name === "aria-labelledby" || name === "aria-describedby") {
          rewritten = rewritten
            .split(/\s+/)
            .map((id) => idMap.get(id) || id)
            .join(" ");
        }
        if (rewritten !== value) element.setAttribute(name, rewritten);
      });
    });

    expanded.querySelectorAll("style").forEach((style) => {
      let css = style.textContent || "";
      idMap.forEach((newId, oldId) => {
        css = css.replaceAll(`url(#${oldId})`, `url(#${newId})`);
      });
      style.textContent = css;
    });
    return expanded;
  }

  function openLightbox(figure) {
    if (!lightbox || !stage || !caption) return;
    const visual = figure.querySelector("img, svg");
    if (!visual) return;

    previousFocus = document.activeElement;
    stage.replaceChildren();
    if (visual instanceof HTMLImageElement) {
      const expanded = new Image();
      expanded.src = visual.currentSrc || visual.src;
      expanded.alt = visual.alt;
      stage.append(expanded);
    } else {
      stage.append(cloneSvgForLightbox(visual));
    }
    caption.textContent = figure.querySelector("figcaption")?.textContent?.trim()
      || visual.getAttribute("aria-label")
      || visual.getAttribute("alt")
      || "";

    if (typeof lightbox.showModal === "function") lightbox.showModal();
    else lightbox.setAttribute("open", "");
  }

  function closeLightbox() {
    if (!lightbox) return;
    if (typeof lightbox.close === "function" && lightbox.open) lightbox.close();
    else lightbox.removeAttribute("open");
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
  lightbox?.addEventListener("click", (event) => {
    if (event.target === lightbox) closeLightbox();
  });
  lightbox?.addEventListener("close", () => {
    if (previousFocus instanceof HTMLElement) previousFocus.focus();
  });

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

  const outlineLinks = [...document.querySelectorAll(".outline a[href^='#']")];
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
