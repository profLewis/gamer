(function () {
  const nav = document.getElementById("entityNav");
  if (!nav) return;

  const prevBtn = document.getElementById("entityPrevBtn");
  const nextBtn = document.getElementById("entityNextBtn");
  const diceBtn = document.getElementById("entityDiceBtn");
  const backBtn = document.getElementById("entityBackBtn");
  let goPrev = null;
  let goNext = null;
  let goRandom = null;
  let goBack = null;

  function go(path) {
    if (!path) return;
    window.location.href = path;
  }

  function parseEntityHrefs(html) {
    const doc = new DOMParser().parseFromString(html, "text/html");
    const anchors = Array.from(doc.querySelectorAll("a.entity-card[href]"));
    const hrefs = anchors
      .map((a) => (a.getAttribute("href") || "").trim())
      .filter((href) => href.endsWith(".html") && href !== "./index.html");
    return hrefs;
  }

  function normalize(href) {
    const u = new URL(href, window.location.href);
    return u.pathname;
  }

  function setDisabled(btn, disabled) {
    if (!btn) return;
    btn.disabled = disabled;
    if (disabled) {
      btn.setAttribute("aria-disabled", "true");
    } else {
      btn.removeAttribute("aria-disabled");
    }
  }

  async function initNav() {
    let hrefs = [];
    try {
      const res = await fetch("./index.html", { cache: "no-store" });
      if (!res.ok) throw new Error("index fetch failed");
      const html = await res.text();
      hrefs = parseEntityHrefs(html);
    } catch (_) {
      setDisabled(prevBtn, true);
      setDisabled(nextBtn, true);
      setDisabled(diceBtn, true);
      return;
    }

    const currentPath = window.location.pathname;
    const order = hrefs.map((href) => normalize(href));
    const idx = order.indexOf(currentPath);
    if (idx < 0 || order.length < 2) {
      setDisabled(prevBtn, true);
      setDisabled(nextBtn, true);
      if (order.length < 1) setDisabled(diceBtn, true);
      return;
    }

    goPrev = () => {
      const i = (idx - 1 + order.length) % order.length;
      go(order[i]);
    };
    goNext = () => {
      const i = (idx + 1) % order.length;
      go(order[i]);
    };
    goRandom = () => {
      let i = idx;
      while (i === idx && order.length > 1) {
        i = Math.floor(Math.random() * order.length);
      }
      go(order[i]);
    };

    prevBtn?.addEventListener("click", goPrev);
    nextBtn?.addEventListener("click", goNext);
    diceBtn?.addEventListener("click", goRandom);
  }

  goBack = () => {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }
    go("../index.html");
  };
  backBtn?.addEventListener("click", goBack);

  window.addEventListener("keydown", (ev) => {
    const t = ev.target;
    const tag = t && t.tagName ? t.tagName.toLowerCase() : "";
    const isEditable = Boolean(t && (t.isContentEditable || tag === "input" || tag === "textarea" || tag === "select"));
    if (isEditable) return;

    if (ev.key === "ArrowLeft") {
      if (goPrev) {
        ev.preventDefault();
        goPrev();
      }
      return;
    }
    if (ev.key === "ArrowRight") {
      if (goNext) {
        ev.preventDefault();
        goNext();
      }
      return;
    }
    if (ev.key === "r" || ev.key === "R") {
      if (goRandom) {
        ev.preventDefault();
        goRandom();
      }
      return;
    }
    if (ev.key === "Backspace") {
      if (goBack) {
        ev.preventDefault();
        goBack();
      }
    }
  });

  initNav();
})();
