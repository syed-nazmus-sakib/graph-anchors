// Graph Anchors — Interactive Project Website Module
// Implements: theme persistence, accessible tablists with keyboard navigation,
// automatic off-tab video pausing, native <dialog closedby="any"> lightbox
// with Safari backdrop fallback, scroll-state header fallback, and BibTeX copy.

const root = document.documentElement;

/* --------------------------------------------------------------------------
   1. Light / Dark Theme Toggle
   -------------------------------------------------------------------------- */
function initTheme() {
  const saved = localStorage.getItem("ga-theme");
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  const initial = saved || (prefersDark ? "dark" : "light");
  applyTheme(initial);

  const btn = document.getElementById("theme-toggle");
  if (!btn) return;
  btn.addEventListener("click", () => {
    const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
    applyTheme(next);
    localStorage.setItem("ga-theme", next);
  });
}

function applyTheme(theme) {
  root.setAttribute("data-theme", theme);
  const sun = document.getElementById("icon-sun");
  const moon = document.getElementById("icon-moon");
  if (sun && moon) {
    sun.style.display = theme === "dark" ? "block" : "none";
    moon.style.display = theme === "dark" ? "none" : "block";
  }
}

/* --------------------------------------------------------------------------
   2. Scroll-State Sticky Header Fallback (for Firefox / Safari)
   -------------------------------------------------------------------------- */
function initHeaderFallback() {
  if (CSS.supports("container-type", "scroll-state")) return;
  const bar = document.querySelector(".top-bar");
  if (!bar) return;
  let lastY = window.scrollY;
  window.addEventListener(
    "scroll",
    () => {
      const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
      const y = Math.max(0, Math.min(window.scrollY, maxScroll));
      if (y === lastY) return;
      bar.classList.toggle("is-hidden", y > lastY && y > bar.offsetHeight);
      lastY = y;
    },
    { passive: true }
  );
}

/* --------------------------------------------------------------------------
   3. Accessible Tablists (Video Explorer & Benchmark Tables)
   -------------------------------------------------------------------------- */
function initTablists() {
  document.querySelectorAll('[role="tablist"]').forEach((tablist) => {
    const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));

    function activateTab(targetTab, moveFocus = false) {
      tabs.forEach((tab) => {
        const selected = tab === targetTab;
        tab.setAttribute("aria-selected", String(selected));
        tab.setAttribute("tabindex", selected ? "0" : "-1");
        const panelId = tab.getAttribute("aria-controls");
        const panel = panelId ? document.getElementById(panelId) : null;
        if (!panel) return;
        if (selected) {
          panel.hidden = false;
        } else {
          // Pause any playing videos when hiding a tab panel
          panel.querySelectorAll("video").forEach((v) => {
            if (!v.paused) v.pause();
          });
          panel.hidden = true;
        }
      });
      if (moveFocus) targetTab.focus();
    }

    tabs.forEach((tab, idx) => {
      tab.addEventListener("click", () => activateTab(tab, false));
      tab.addEventListener("keydown", (e) => {
        let nextIdx = null;
        if (e.key === "ArrowRight") nextIdx = (idx + 1) % tabs.length;
        else if (e.key === "ArrowLeft") nextIdx = (idx - 1 + tabs.length) % tabs.length;
        else if (e.key === "Home") nextIdx = 0;
        else if (e.key === "End") nextIdx = tabs.length - 1;
        if (nextIdx !== null) {
          e.preventDefault();
          activateTab(tabs[nextIdx], true);
        }
      });
    });
  });
}

/* --------------------------------------------------------------------------
   4. Pause Videos Automatically When Scrolled Far Off-Screen
   -------------------------------------------------------------------------- */
function initVideoVisibility() {
  if (!("IntersectionObserver" in window)) return;
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting && !entry.target.paused) {
          entry.target.pause();
        }
      });
    },
    { threshold: 0.05 }
  );
  document.querySelectorAll("video").forEach((video) => observer.observe(video));
}

/* --------------------------------------------------------------------------
   5. Native <dialog closedby="any"> Lightbox with Safari Backdrop Fallback
   -------------------------------------------------------------------------- */
function initLightbox() {
  const dialog = document.getElementById("figure-lightbox");
  if (!dialog) return;
  const imgEl = dialog.querySelector("#lightbox-img");
  const titleEl = dialog.querySelector("#lightbox-title");
  const capEl = dialog.querySelector("#lightbox-cap");

  document.querySelectorAll(".figure-trigger").forEach((btn) => {
    btn.addEventListener("click", () => {
      const fullSrc = btn.dataset.full;
      const alt = btn.dataset.alt || "";
      const title = btn.dataset.title || "Figure";
      const caption = btn.dataset.caption || "";

      imgEl.src = fullSrc;
      imgEl.alt = alt;
      titleEl.textContent = title;
      capEl.textContent = caption;
      dialog.showModal();
    });
  });

  // Fallback light-dismiss for browsers without native closedby support (Safari)
  if (!("closedBy" in HTMLDialogElement.prototype)) {
    dialog.addEventListener("click", (event) => {
      if (event.target !== dialog) return;
      const rect = dialog.getBoundingClientRect();
      const inside =
        rect.top <= event.clientY &&
        event.clientY <= rect.top + rect.height &&
        rect.left <= event.clientX &&
        event.clientX <= rect.left + rect.width;
      if (!inside) dialog.close();
    });
  }
}

/* --------------------------------------------------------------------------
   6. Copy BibTeX Button
   -------------------------------------------------------------------------- */
function initBibtexCopy() {
  const btn = document.getElementById("copy-bibtex");
  const code = document.getElementById("bibtex-content");
  if (!btn || !code) return;

  btn.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(code.textContent.trim());
      const label = btn.querySelector("span");
      const prev = label.textContent;
      btn.classList.add("is-copied");
      label.textContent = "Copied!";
      setTimeout(() => {
        btn.classList.remove("is-copied");
        label.textContent = prev;
      }, 2000);
    } catch {
      const range = document.createRange();
      range.selectNodeContents(code);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
    }
  });
}

initTheme();
initHeaderFallback();
initTablists();
initVideoVisibility();
initLightbox();
initBibtexCopy();
