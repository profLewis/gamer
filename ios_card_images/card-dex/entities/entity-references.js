(function () {
  const wrap = document.querySelector(".wrap");
  const linksSection = Array.from(document.querySelectorAll(".panel")).find((p) => {
    const h2 = p.querySelector("h2");
    return h2 && h2.textContent.trim().toLowerCase() === "external links";
  });
  if (!wrap || !linksSection) return;

  const links = Array.from(linksSection.querySelectorAll(".links a[href]"));
  if (!links.length) return;

  const listItems = links.map((a) => {
    let host = "";
    try {
      host = new URL(a.href, window.location.href).hostname.replace(/^www\./, "");
    } catch (_) {}
    const li = document.createElement("li");
    const link = document.createElement("a");
    link.href = a.href;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = (a.textContent || "Reference").trim();
    li.appendChild(link);
    if (host) {
      const span = document.createElement("span");
      span.className = "ref-host";
      span.textContent = ` (${host})`;
      li.appendChild(span);
    }
    return li;
  });

  const refPanel = document.createElement("section");
  refPanel.className = "panel references-panel";
  const h2 = document.createElement("h2");
  h2.textContent = "References";
  const list = document.createElement("ol");
  list.className = "references-list";
  listItems.forEach((li) => list.appendChild(li));
  const note = document.createElement("p");
  note.className = "small";
  note.textContent = "References are listed from the external links above and open in a new tab.";
  refPanel.appendChild(h2);
  refPanel.appendChild(list);
  refPanel.appendChild(note);

  wrap.appendChild(refPanel);
})();
