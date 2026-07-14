(() => {
  "use strict";

  document.documentElement.dataset.enhanced = "true";

  const lightbox = document.querySelector("#lightbox");
  const stage = lightbox?.querySelector(".lightbox-stage");
  const caption = lightbox?.querySelector(".lightbox-caption");
  let previousFocus = null;

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
      const expanded = visual.cloneNode(true);
      expanded.removeAttribute("id");
      stage.append(expanded);
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

  document.querySelectorAll("[data-trace]").forEach((control) => {
    control.addEventListener("click", () => {
      const coordinate = control.dataset.trace;
      document.querySelectorAll(".trace-active").forEach((item) => item.classList.remove("trace-active"));
      document.querySelector(`[data-coordinate='${CSS.escape(coordinate)}']`)?.classList.add("trace-active");
    });
  });
})();
