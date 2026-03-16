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

  const aceMatch = pageTitle.match(/^Ace Double (D-\d{3}) \((\d{4})\)$/);
  if (!aceMatch) return;

  const aceCode = aceMatch[1];
  const aceOrigins = {
    "D-031": {
      books: "The World of Null-A / The Universe Maker",
      authors: "A. E. van Vogt",
      story: "This pairing blends identity puzzles with cosmic engineering. Null-A follows Gilbert Gosseyn through a staged society built around logic training and hidden power structures. The reverse title broadens scope into universe-scale creation themes common in van Vogt's high-concept SF.",
    },
    "D-053": {
      books: "The Weapon Shops of Isher / Gateway to Elsewhere",
      authors: "A. E. van Vogt and Murray Leinster",
      story: "One half is political SF about civil liberty versus empire, centered on the Weapon Shops and Robert Hedrock. The other half is portal adventure: a threshold from modern assumptions into a sword-and-sorcery world where social rules and risk models reset immediately.",
    },
    "D-096": {
      books: "The Last Planet / Maza of the Moon",
      authors: "Andre Norton and Otis Adelbert Kline",
      story: "Norton's side starts with a stranded patrol forced to survive on a dangerous frontier world and rebuild order. Kline's side keeps the planetary adventure tone, pairing exploration with conflict over local power and scarce resources.",
    },
    "D-103": {
      books: "Solar Lottery / The Big Jump",
      authors: "Philip K. Dick and Leigh Brackett",
      story: "Dick's early novel imagines government as a lethal lottery system where randomness masks control. Brackett's novel adds expeditionary pulp momentum. Together they frame mid-century anxiety about authority, chance, and who gets to set the rules.",
    },
    "D-150": {
      books: "The World Jones Made / Agent of Vega",
      authors: "Philip K. Dick and James H. Schmitz",
      story: "Jones Made studies prediction, charisma, and social drift through a man who can see one year ahead. Agent of Vega shifts to interstellar intrigue and fieldcraft. The pair connects prophetic pressure with practical action under uncertainty.",
    },
    "D-249": {
      books: "The Cosmic Puppets / The Last Enemy",
      authors: "Philip K. Dick and H. Beam Piper",
      story: "The Cosmic Puppets turns a familiar town into contested reality, where memory and environment no longer agree. The companion title expands conflict scale with military and political stakes, giving this double both psychological and strategic dimensions.",
    },
    "D-295": {
      books: "Big Planet / The Last Spaceship",
      authors: "Jack Vance and Murray Leinster",
      story: "Vance builds a giant world made of fragmented micro-cultures where travelers must decode local customs to survive. Leinster contributes a high-pressure transport and survival frame. The result is exploration-first SF with strong journey structure.",
    },
    "D-413": {
      books: "The Man with Nine Lives / Destiny Times Three",
      authors: "Harlan Ellison and Fritz Leiber",
      story: "Ellison brings noir tension around identity, recurrence, and manipulation. Leiber adds alternate-futures pressure through branching outcomes and timeline rivalry. Together they read as investigations into personality under repeated historical stress.",
    },
    "D-421": {
      books: "Dr. Futurity / No World of Their Own",
      authors: "Philip K. Dick and Clifford D. Simak",
      story: "Dr. Futurity drops a physician into a culture where medicine and ethics have been inverted by time shift. Simak's side adds outsider perspective on belonging and social boundaries. This double is about moral dislocation as much as technology.",
    },
    "D-449": {
      books: "The Genetic General / Time Crime",
      authors: "Gordon R. Dickson and H. Beam Piper",
      story: "Dickson's military-future strand follows Donal Graeme and the Dorsai model of specialist societies. Piper's title introduces temporal lawbreaking and enforcement. The shared core is strategy: how power is organized, projected, and resisted across systems.",
    },
    "D-491": {
      books: "The Big Time / The Mind-Spider and Other Stories",
      authors: "Fritz Leiber",
      story: "The Big Time stages the Change War from a rest station outside normal chronology, with entertainers and veterans trapped in escalating timeline conflict. The companion stories extend Leiber's speculative range while keeping focus on perception, conflict framing, and human reactions under strange constraints.",
    },
  };

  const origin = aceOrigins[aceCode];
  if (!origin) return;

  const originPanel = document.createElement("section");
  originPanel.className = "panel origin-panel";
  originPanel.innerHTML = [
    "<h2>Origin Story</h2>",
    `<p class="summary"><strong>Books:</strong> ${origin.books}</p>`,
    `<p class="summary"><strong>Author(s):</strong> ${origin.authors}</p>`,
    `<p class="summary"><strong>Story Origin:</strong> ${origin.story}</p>`,
  ].join("");

  const wrap = document.querySelector(".wrap");
  const externalLinksPanel = Array.from(document.querySelectorAll("section.panel")).find((panel) => {
    const h2 = panel.querySelector("h2");
    return h2 && h2.textContent.trim() === "External Links";
  });

  if (externalLinksPanel && externalLinksPanel.parentElement) {
    externalLinksPanel.parentElement.insertBefore(originPanel, externalLinksPanel);
    return;
  }

  if (wrap) wrap.appendChild(originPanel);
})();
