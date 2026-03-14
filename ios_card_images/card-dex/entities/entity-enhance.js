(function () {
  const layout = document.querySelector(".layout");
  if (!layout) return;

  const panels = Array.from(layout.querySelectorAll(".panel"));
  if (!panels.length) return;

  const sourcePanel = panels[0];
  const cardImg = sourcePanel.querySelector(".card-img");
  if (!cardImg) return;

  sourcePanel.classList.add("source-panel");

  if (!cardImg.parentElement.classList.contains("card-stage")) {
    const stage = document.createElement("div");
    stage.className = "card-stage";
    cardImg.parentElement.insertBefore(stage, cardImg);
    stage.appendChild(cardImg);
  }

  const pageTitle = (document.querySelector("h1")?.textContent || "").trim();
  const metaText = (document.querySelector(".meta")?.textContent || "").trim();
  const kind = (metaText.split(" source card")[0] || "").trim();
  const yearMatch = pageTitle.match(/\((\d{4})\)/);
  const era = yearMatch ? yearMatch[1] : "Unknown era";

  const links = Array.from(document.querySelectorAll(".links a[href]")).slice(0, 3);

  const profile = document.createElement("div");
  profile.className = "source-profile";
  profile.innerHTML = [
    '<div class="label">Inspiration</div>',
    `<div class="value">${pageTitle || "Unknown Source"}</div>`,
    '<div class="profile-chips"></div>',
    '<div class="source-links"></div>',
  ].join("");

  const chips = profile.querySelector(".profile-chips");
  [
    `Type: ${kind || "SOURCE"}`,
    `Era: ${era}`,
    "Use: Default game lore",
  ].forEach((txt) => {
    const chip = document.createElement("span");
    chip.className = "profile-chip";
    chip.textContent = txt;
    chips.appendChild(chip);
  });

  const sourceLinks = profile.querySelector(".source-links");
  links.forEach((a) => {
    const link = document.createElement("a");
    link.href = a.href;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = a.textContent || "Reference";
    sourceLinks.appendChild(link);
  });

  sourcePanel.appendChild(profile);
})();
