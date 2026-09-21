(function () {
  function wrapImageWithSourceLink(img, href) {
    if (!img || !href) return;
    const parent = img.parentElement;
    if (parent && parent.tagName.toLowerCase() === "a") {
      parent.href = href;
      parent.target = "_blank";
      parent.rel = "noopener noreferrer";
      return;
    }
    if (!parent) return;
    const a = document.createElement("a");
    a.href = href;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    parent.insertBefore(a, img);
    a.appendChild(img);
  }

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

  // Make visible reference images clickable to their source page.
  const wikiImgs = Array.from(document.querySelectorAll(".wiki-img"));
  const primarySourceHref = links[0] ? links[0].href : null;
  wikiImgs.forEach((img) => {
    wrapImageWithSourceLink(img, primarySourceHref);
  });

  sourcePanel.appendChild(profile);

  const cardLink = (name) =>
    `<a class="inline-link" href="../index.html?search=${encodeURIComponent(name)}" target="_blank" rel="noopener noreferrer">${name}</a>`;
  const extLink = (label, href) =>
    `<a class="inline-link" href="${href}" target="_blank" rel="noopener noreferrer">${label}</a>`;

  const pageSlug = (() => {
    const file = window.location.pathname.split("/").pop() || "";
    return file.replace(/\.html$/i, "");
  })();
  const placeholderText = "contributes atmosphere, archetypes, and pacing cues";
  const placeholderSummary = Array.from(document.querySelectorAll(".summary")).find((el) =>
    (el.textContent || "").includes(placeholderText)
  );

  const richSynopsis = {
    "alien-1979": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A commercial towing ship, the Nostromo, is redirected after receiving a distress signal from a desolate moon. The crew investigates and unknowingly brings back a lethal organism whose life cycle turns the ship into a locked-room survival scenario.",
      roles: [
        `${cardLink("Ripley")} starts as a protocol-focused officer and gradually becomes the practical center of resistance.`,
        "Dallas is the ship captain who tries to keep order as information and options collapse.",
        "Ash, the science officer, represents corporate secrecy and conflicting priorities aboard the ship.",
        "Parker and Lambert highlight working-crew realism: fear, anger, and hard constraints under pressure.",
      ],
      vibe:
        "The film's tone mixes industrial realism with escalating biological horror. In DnD terms it is a high-dread dungeon crawl where map control, quarantine decisions, and timing matter more than brute force.",
      spoiler:
        "Spoilers: The crew's internal trust problem becomes as dangerous as the creature itself, and the final act isolates Ripley into a one-person survival endgame.",
      refs: [
        extLink("Alien (1979) - Wikipedia", "https://en.wikipedia.org/wiki/Alien_(film)"),
        extLink("Ripley card in DnDex", "../index.html?search=Ripley"),
      ],
    },
    "forbidden-planet-1956": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A rescue mission arrives at Altair IV to check on a missing expedition and finds Dr. Morbius living with advanced alien technology from the extinct Krell civilization. What appears to be scientific wonder quickly becomes a psychological threat story.",
      roles: [
        "Commander Adams leads the mission and tries to balance military caution with scientific curiosity.",
        "Dr. Morbius is brilliant, proud, and increasingly isolated by what he thinks he controls.",
        "Altaira, Morbius's daughter, represents innocence raised outside normal society.",
        "Robby the Robot is both comic relief and a key symbol of tool-use without moral insight.",
      ],
      vibe:
        "The film blends planetary exploration with a warning about unchecked subconscious power. It maps well to ancient-ruin dungeon design where the dead civilization left systems still running.",
      spoiler:
        "Spoilers: The main threat is tied to the human mind amplified by Krell machinery, not an ordinary external monster.",
      refs: [extLink("Forbidden Planet - Wikipedia", "https://en.wikipedia.org/wiki/Forbidden_Planet")],
    },
    "dragonslayer-1981": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A kingdom pays periodic sacrifices to a dragon, and a young apprentice named Galen inherits a dangerous anti-dragon quest after his master dies. The journey follows fear, fraud, faith, and political compromise under a monster's shadow.",
      roles: [
        `${cardLink("Valerian")} (Galen) is inexperienced but determined, learning leadership while improvising under pressure.`,
        "Princess Elspeth embodies the political and moral cost of the sacrifice system.",
        "King Casiodorus favors stability over justice, making the dragon problem partly a governance failure.",
        "Vermithrax is portrayed as an apex predator rather than a chatty villain, which gives the threat unusual weight.",
      ],
      vibe:
        "The movie favors gritty, low-magic peril over heroic certainty. It is excellent source material for dragon arcs where logistics and courage matter as much as spell power.",
      spoiler:
        "Spoilers: The climax forces the hero to win through timing and sacrifice rather than clean one-on-one dominance.",
      refs: [extLink("Dragonslayer - Wikipedia", "https://en.wikipedia.org/wiki/Dragonslayer_(1981_film)")],
    },
    "king-kong-1933": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A film crew travels to Skull Island searching for spectacle and discovers a giant ape worshipped by local inhabitants. The expedition shifts from adventure to catastrophe when the creature is captured and transported to New York.",
      roles: [
        "Ann Darrow is framed as both victim and emotional center in a story about exploitation.",
        "Carl Denham represents ambition without restraint: he turns danger into product.",
        "Jack Driscoll functions as the romantic and protective lead within the expedition.",
        "Kong is portrayed with menace and pathos, making him more tragic than purely monstrous.",
      ],
      vibe:
        "Its strongest modern reading is colonial spectacle, industrial hubris, and creature tragedy. In game adaptation, Skull Island works as a layered biome dungeon with moral stakes attached to every trophy choice.",
      spoiler:
        "Spoilers: The ending is iconic and tragic, framing Kong as destroyed by human spectacle rather than by primal evil.",
      refs: [extLink("King Kong (1933) - Wikipedia", "https://en.wikipedia.org/wiki/King_Kong_(1933_film)")],
    },
    "honour-among-thieves": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A thief-turned-bard assembles a party to recover his daughter and undo past mistakes after a heist collapses into betrayal. The story combines jailbreak energy, faction politics, and artifact-driven stakes in a Forgotten Realms setting.",
      roles: [
        `${cardLink("Edgin")} leads through planning and persuasion rather than raw magic.`,
        `${cardLink("Holga")} is the party's frontline force and emotional anchor.`,
        `${cardLink("Xenk")} acts as a strict moral counterweight to the crew's improvisational ethics.`,
        "Simon and Doric carry arcane and druidic problem-solving roles that expand party tactics.",
      ],
      vibe:
        "The film models tabletop rhythm: planning, bad rolls, recovery, and creative teamwork. It is a practical template for cinematic DnD pacing.",
      spoiler:
        "Spoilers: The final objective reframes what success means for Edgin's family arc, not just the heist payout.",
      refs: [extLink("Dungeons & Dragons: Honor Among Thieves", "https://en.wikipedia.org/wiki/Dungeons_%26_Dragons:_Honor_Among_Thieves")],
    },
    "labyrinth-1986": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "Teenager Sarah wishes her baby brother away, then must solve a shifting labyrinth within a strict time limit to get him back. The journey passes through trick environments, comic danger, and manipulative bargains from the Goblin King.",
      roles: [
        "Sarah is a protagonist defined by growth: from theatrical self-focus to accountable courage.",
        `${cardLink("Jareth")} uses charm, temptation, and illusion rather than direct violence.`,
        "Hoggle, Ludo, and Sir Didymus build a classic found-party structure around trust and loyalty.",
      ],
      vibe:
        "The film feels like a fairy-tale puzzle campaign with emotional checkpoints. Room logic, language tricks, and social choices are as important as combat.",
      spoiler:
        "Spoilers: The resolution depends on Sarah rejecting control through words and self-possession, not by defeating Jareth in a duel.",
      refs: [extLink("Labyrinth (1986) - Wikipedia", "https://en.wikipedia.org/wiki/Labyrinth_(1986_film)")],
    },
    "legend-1985": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A dark fantasy quest begins when Princess Lili's actions contribute to a cosmic imbalance and the Lord of Darkness moves to extinguish daylight. Jack must gather uneasy allies and enter Darkness's domain to restore the world.",
      roles: [
        "Jack is a woodland hero whose strengths are empathy, speed, and persistence.",
        "Lili shifts from naive curiosity to moral reckoning, becoming central to the story's stakes.",
        `${cardLink("Darkness")} is theatrical, seductive, and ideological: he wants dominion over light itself.`,
      ],
      vibe:
        "Legend is atmosphere-first fantasy with symbolic imagery and strong fairy-myth framing. In DnD adaptation it suits high-magic wilderness arcs with moral temptation themes.",
      spoiler:
        "Spoilers: The ending turns on light, reflection, and psychological resistance more than brute weapon skill.",
      refs: [extLink("Legend (1985) - Wikipedia", "https://en.wikipedia.org/wiki/Legend_(1985_film)")],
    },
    "highlander-1986": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "Connor MacLeod discovers he is one of a hidden population of immortals who duel across centuries under strict rules. The film alternates between modern New York and historical flashbacks to build his identity and losses over time.",
      roles: [
        `${cardLink("Connor MacLeod")} is both swordsman and survivor, defined by accumulated grief and discipline.`,
        "Ramirez is the mentor figure who explains the Game and trains Connor's combat worldview.",
        "The Kurgan is the central antagonist: brutal, charismatic, and committed to domination.",
      ],
      vibe:
        "Highlander blends urban fantasy, sword drama, and personal history. It is strong source material for long-lived-character campaigns where memory and era shifts change party dynamics.",
      spoiler:
        "Spoilers: The final confrontation resolves the Game but emphasizes the emotional cost of immortality rather than pure triumph.",
      refs: [extLink("Highlander (film) - Wikipedia", "https://en.wikipedia.org/wiki/Highlander_(film)")],
    },
    "the-neverending-story-1984": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "Bastian, a lonely reader, finds a book and is drawn into Fantasia as the realm is consumed by the Nothing. The in-world quest is carried by Atreyu, who must find a cure for the Childlike Empress while crossing increasingly dangerous landscapes.",
      roles: [
        `${cardLink("Atreyu")} is the active quest hero facing direct trials and losses.`,
        "Bastian is the framing protagonist whose imagination and self-belief become plot-critical.",
        "The Childlike Empress represents continuity of Fantasia itself.",
        "Gmork embodies nihilistic force, tying the Nothing to human despair.",
      ],
      vibe:
        "The film combines coming-of-age emotion with mythic quest structure. For DnD campaigns it is ideal for stories where belief, naming, and narrative choices carry mechanical weight.",
      spoiler:
        "Spoilers: Resolution depends on Bastian's participation and naming act, not simply Atreyu defeating a final boss.",
      refs: [extLink("The NeverEnding Story - Wikipedia", "https://en.wikipedia.org/wiki/The_NeverEnding_Story_(film)")],
    },
    "star-wars-1977": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "A farm boy is pulled into galactic conflict after obtaining stolen military plans tied to a superweapon. The film follows escape, mentorship, rebellion logistics, and a high-risk assault mission.",
      roles: [
        "Luke begins as untested and grows through discipline, loss, and belief.",
        "Leia is a strategist and resistance leader, not just a rescue target.",
        "Han shifts from self-interest to commitment under pressure.",
        "Obi-Wan provides mythic framing and practical training.",
        "Vader represents imperial fear and personal menace at once.",
      ],
      vibe:
        "Its structure is close to a classic campaign arc: inciting incident, party formation, dungeon infiltration, and boss-faction confrontation.",
      spoiler:
        "Spoilers: The final attack succeeds through teamwork, trust, and a late shift from pure instrument reading to intuition.",
      refs: [extLink("Star Wars (1977) - Wikipedia", "https://en.wikipedia.org/wiki/Star_Wars_(film)")],
    },
    "willow-1988": {
      heading: "Plot and Characters (Spoiler-Lite)",
      overview:
        "Willow Ufgood, a farmer and aspiring sorcerer, is drawn into a prophecy-centered mission to protect a baby marked by an evil queen. The journey blends comedy, peril, and mentorless magical growth.",
      roles: [
        `${cardLink("Willow")} carries the film through reluctant courage and practical learning.`,
        `${cardLink("Madmartigan")} supplies blade skill, chaos, and eventual loyalty.`,
        "Sorsha starts aligned with power and becomes a critical moral pivot.",
        "Queen Bavmorda is a regime-level antagonist whose threat is political and arcane.",
      ],
      vibe:
        "Willow models party chemistry in motion: mismatched goals, gradual trust, and high-pressure rescues. It translates cleanly into tabletop encounter chains.",
      spoiler:
        "Spoilers: The finale rewards intelligence and illusion play as much as direct magical force.",
      refs: [extLink("Willow (film) - Wikipedia", "https://en.wikipedia.org/wiki/Willow_(film)")],
    },
  };

  const authorDossiers = {
    "terry-pratchett": {
      intro: "Terry Pratchett turned comic fantasy into a precise social lens: funny on the surface, rigorous underneath.",
      works: "Core works for this game set include Discworld novels connected to Rincewind, Granny Weatherwax, and DEATH.",
      links: [
        ["Discworld series", "https://en.wikipedia.org/wiki/Discworld"],
        ["Official books site", "https://www.terrypratchettbooks.com/"],
      ],
    },
    "j-r-r-tolkien": {
      intro: "Tolkien established the modern epic-fantasy template: deep history, travel arcs, and mythic-scale stakes.",
      works: "This card family draws from The Hobbit and The Lord of the Rings, especially for leadership, evil-power, and location tone.",
      links: [
        ["LOTR films", "https://en.wikipedia.org/wiki/The_Lord_of_the_Rings_(film_series)"],
        ["Tolkien Estate", "https://www.tolkienestate.com/"],
      ],
    },
    "michael-moorcock": {
      intro: "Moorcock's Eternal Champion cycle introduced morally ambiguous heroes and multiverse-scale fantasy logic.",
      works: "Elric and Corum links in this game reflect cursed-power play and anti-hero strategy over pure heroic certainty.",
      links: [["Elric of Melnibone", "https://en.wikipedia.org/wiki/Elric_of_Melnibon%C3%A9"]],
    },
    "ursula-k-le-guin": {
      intro: "Le Guin's fantasy and SF foreground language, culture, and ethical balance over spectacle-first conflict.",
      works: "Ged and Tenar links come from Earthsea, where naming, restraint, and consequence are central mechanics.",
      links: [["Earthsea", "https://en.wikipedia.org/wiki/Earthsea"]],
    },
    "isaac-asimov": {
      intro: "Asimov's work defines systems-driven SF: institutions, logic constraints, and long-horizon strategy.",
      works: "Robot and Foundation-adjacent references support high-Cunning, investigation-heavy play styles in this set.",
      links: [
        ["Foundation (TV)", "https://en.wikipedia.org/wiki/Foundation_(TV_series)"],
        ["ISFDB Asimov", "https://www.isfdb.org/cgi-bin/ea.cgi?Isaac_Asimov"],
      ],
    },
    "robert-e-howard": {
      intro: "Howard's Conan fiction is a cornerstone of sword-and-sorcery pacing: fast action, hard survival, and brutal momentum.",
      works: "Conan-linked cards here use that style for high-Power archetypes and direct-violence quest framing.",
      links: [["Conan the Barbarian", "https://en.wikipedia.org/wiki/Conan_the_Barbarian"]],
    },
    "edgar-rice-burroughs": {
      intro: "Burroughs pioneered serialized planetary adventure with strong duel culture and exploration momentum.",
      works: "John Carter and related source flavor feed high-adventure campaign rhythm in this card set.",
      links: [["Barsoom", "https://en.wikipedia.org/wiki/Barsoom"]],
    },
  };

  function injectAuthorDossier() {
    const isAuthor = (kind || "").toUpperCase() === "AUTHOR";
    const data = authorDossiers[pageSlug];
    if (!isAuthor && !data) return;
    const d = data || {
      intro: `${pageTitle} is treated as a major literary influence for default DnDex naming and campaign style.`,
      works: "Linked cards show which characters and locations in this game draw directly from this author stream.",
      links: [],
    };
    const linksHtml = d.links.map((x) => `<a class="inline-link" href="${x[1]}" target="_blank" rel="noopener noreferrer">${x[0]}</a>`).join(" | ");
    const panel = document.createElement("section");
    panel.className = "panel";
    panel.style.marginTop = "14px";
    panel.innerHTML = [
      "<h2>Author Dossier</h2>",
      `<p class="summary">${d.intro}</p>`,
      `<p class="summary">${d.works}</p>`,
      `<p class="summary"><a class="inline-link" href="../index.html?search=${encodeURIComponent(pageTitle)}" target="_blank" rel="noopener noreferrer">Open related cards in DnDex</a>${linksHtml ? ` | ${linksHtml}` : ""}</p>`,
    ].join("");
    const ext = Array.from(document.querySelectorAll("section.panel")).find((p) => {
      const h2 = p.querySelector("h2");
      return h2 && h2.textContent.trim() === "External Links";
    });
    if (ext && ext.parentElement) ext.parentElement.insertBefore(panel, ext);
  }

  if (placeholderSummary) {
    const rich = richSynopsis[pageSlug];
    if (rich) {
      const html = [
        `<h2>${rich.heading}</h2>`,
        `<p class="summary">${rich.overview}</p>`,
        `<h3 class="subhead">Key Characters</h3>`,
        `<ul class="summary-list">${rich.roles.map((r) => `<li>${r}</li>`).join("")}</ul>`,
        `<p class="summary">${rich.vibe}</p>`,
        `<details class="spoiler-box"><summary>Spoilers (click to reveal)</summary><p class="summary">${rich.spoiler}</p></details>`,
        `<p class="summary"><strong>References:</strong> ${rich.refs.join(" | ")}</p>`,
      ].join("");
      const panel = placeholderSummary.closest(".panel");
      if (panel) {
        panel.innerHTML = html;
      }
    }
  }
  const authorPlaceholder = Array.from(document.querySelectorAll(".summary")).find((el) =>
    (el.textContent || "").includes("This author page frames")
  );
  if (authorPlaceholder && ((kind || "").toUpperCase() === "AUTHOR" || authorDossiers[pageSlug])) {
    authorPlaceholder.textContent =
      `${pageTitle} is a core literary influence in this game set. Use the dossier and linked cards below to explore specific characters, places, and cross-media adaptations tied to this source.`;
  }
  injectAuthorDossier();

  const norm = (s) => (s || "").toLowerCase().replace(/\s+/g, " ").trim();
  const sourceMatch = norm(pageTitle);
  const connectPanel = document.createElement("section");
  connectPanel.className = "panel connect-panel";
  connectPanel.innerHTML = [
    "<h2>Connected DnDex Cards</h2>",
    "<p class=\"summary\">Loading linked cards from the main DnDex set...</p>",
  ].join("");

  const insertAfterLayout = document.querySelector(".layout");
  if (insertAfterLayout && insertAfterLayout.parentElement) {
    insertAfterLayout.parentElement.insertBefore(connectPanel, insertAfterLayout.nextSibling);
  }

  const bookFocusMap = {
    "dragonlance": "Dragonlance begins with the Chronicles arc, where old companions reunite in a war-torn world shaped by gods, dragons, and lost magic. The setting combines quest momentum with faction politics and mythic artifacts, which is why it feeds both hero and location naming in this game.",
    "david-eddings": "The Belgariad sequence follows Belgarion from rural obscurity into prophecy, court intrigue, and continent-scale conflict. The appeal for gameplay is clear class identity, party-role contrast, and a quest structure that escalates naturally from local to world-level stakes.",
    "fritz-leiber": "Leiber's sword-and-sorcery work, especially Fafhrd and the Gray Mouser stories, blends urban danger with fast improvisational adventure. These books are useful for campaigns that need city-crawl texture, thief-guild tension, and morally mixed protagonists.",
    "r-a-salvatore": "Salvatore's Forgotten Realms novels, particularly the Drizzt line, are central to modern DnD-flavored character fantasy. They emphasize movement tactics, faction conflict, and identity themes, which map directly to party play and long-run campaign arcs.",
    "roger-zelazny": "The Chronicles of Amber uses dynastic conflict, multidimensional travel, and unstable alliances as core engines. It is strong source material for campaigns built on political maneuvering and shifting realities rather than single-map dungeon progression.",
    "stephen-donaldson": "The Thomas Covenant books push epic fantasy toward moral ambiguity and psychological consequence. For gameplay inspiration, they support darker campaign tone, contested heroism, and worlds where victory does not erase damage.",
    "mervyn-peake": "Peake's Gormenghast novels are architecture-heavy gothic fantasy where institutions and ritual shape every decision. The connection to game design is atmospheric location play: space, hierarchy, and social pressure function like encounter mechanics.",
  };

  function injectBookFocus(linkedCards) {
    if ((kind || "").toUpperCase() !== "BOOK") return;
    const chars = linkedCards.filter((c) => c.type === "player").map((c) => c.name);
    const places = linkedCards.filter((c) => c.type === "location").map((c) => c.name);
    const monsters = linkedCards.filter((c) => c.type === "monster").map((c) => c.name);
    const pick = (arr, n) => arr.slice(0, n).join(", ");

    const base = bookFocusMap[pageSlug] ||
      "This book source contributes setting tone and character archetypes to the default DnDex roster. It is used as a reference anchor for naming, style, and campaign flavor in this project.";

    const lines = [base];
    if (chars.length) lines.push(`Characters used in this game from this source include: ${pick(chars, 8)}.`);
    if (places.length) lines.push(`Places used in this game include: ${pick(places, 8)}.`);
    if (monsters.length) lines.push(`Creature links from this source include: ${pick(monsters, 6)}.`);
    if (!chars.length && !places.length && !monsters.length) {
      lines.push("No direct card links were detected on this page yet, but this source remains part of the reference set.");
    }

    const bookPanel = document.createElement("section");
    bookPanel.className = "panel";
    bookPanel.style.marginTop = "14px";
    bookPanel.innerHTML = [
      "<h2>Book Focus</h2>",
      ...lines.map((line) => `<p class=\"summary\">${line}</p>`),
      `<p class=\"summary\"><a class=\"inline-link\" href=\"../index.html?search=${encodeURIComponent(pageTitle)}\" target=\"_blank\" rel=\"noopener noreferrer\">Open matching cards in DnDex</a></p>`,
    ].join("");

    const ext = Array.from(document.querySelectorAll("section.panel")).find((panel) => {
      const h2 = panel.querySelector("h2");
      return h2 && h2.textContent.trim() === "External Links";
    });
    if (ext && ext.parentElement) {
      ext.parentElement.insertBefore(bookPanel, ext);
    }
  }

  fetch("../../cards.json")
    .then((res) => (res.ok ? res.json() : null))
    .then((data) => {
      if (!data) throw new Error("cards data unavailable");
      const cards = [...(data.players || []), ...(data.monsters || []), ...(data.locations || [])];
      const linked = cards.filter((c) => norm(c.source) === sourceMatch);
      injectBookFocus(linked);
      if (!linked.length) {
        connectPanel.innerHTML = [
          "<h2>Connected DnDex Cards</h2>",
          `<p class="summary">No direct source match was found for <strong>${pageTitle}</strong> in cards.json. You can still browse the full dex and search manually.</p>`,
          `<p class="summary"><a class="inline-link" href="../index.html?search=${encodeURIComponent(pageTitle)}">Search this source in DnDex</a></p>`,
        ].join("");
        return;
      }

      const typeLabel = (t) => (t === "player" ? "Player" : t === "monster" ? "Monster" : "Location");
      const cardsHtml = linked
        .map((c) => {
          const cardHref = `../index.html?card=${encodeURIComponent(c.name)}&search=${encodeURIComponent(c.source || "")}`;
          const img = `../../${c.image}`;
          return [
            `<a class="connect-card" href="${cardHref}" target="_blank" rel="noopener noreferrer">`,
            `  <img src="${img}" alt="${c.name} card image" loading="lazy" />`,
            `  <div class="connect-name">${c.name}</div>`,
            `  <div class="connect-meta">${typeLabel(c.type)}</div>`,
            "</a>",
          ].join("");
        })
        .join("");

      const openFiltered = `../index.html?search=${encodeURIComponent(linked[0].source || pageTitle)}`;
      connectPanel.innerHTML = [
        "<h2>Connected DnDex Cards</h2>",
        `<p class="summary"><strong>${linked.length}</strong> linked cards use <strong>${pageTitle}</strong> as their source. Open any card below, or jump into the filtered dex view.</p>`,
        `<p class="summary"><a class="btn subtle" href="${openFiltered}" target="_blank" rel="noopener noreferrer">Open Filtered DnDex View</a></p>`,
        `<div class="connect-grid">${cardsHtml}</div>`,
      ].join("");
    })
    .catch(() => {
      connectPanel.innerHTML = [
        "<h2>Connected DnDex Cards</h2>",
        `<p class="summary">Could not load card connections automatically. Use this direct search link instead: <a class="inline-link" href="../index.html?search=${encodeURIComponent(pageTitle)}">Search in DnDex</a>.</p>`,
      ].join("");
    });

  const aceMatch = pageTitle.match(/^Ace Double (D-\d{3}) \((\d{4})\)$/);
  if (!aceMatch) return;

  const aceCode = aceMatch[1];

  const aceOrigins = {
    "D-031": {
      books: "The World of Null-A / The Universe Maker",
      authors: "A. E. van Vogt (both sides)",
      story:
        `Ace's first SF double put van Vogt back to back with himself. The A-side tracks ${cardLink("Gosseyn")} through the annual Games of the Machine, a society that sorts and rules people by formal testing in non-Aristotelian logic. ` +
        `Its engine is identity uncertainty: Gosseyn's memories are planted, ${cardLink("Patricia Hardie")} is not the dead wife he remembers but the President's daughter, and each time he is killed he wakes in a spare body. ` +
        `The setting around ${cardLink("Null-A City")} and the ${cardLink("Games Machine")} reads like a puzzle-dungeon in social form, not just a battlefield. ` +
        `The reverse title, <em>The Universe Maker</em>, throws Morton Cargill thousands of years forward to be executed by a descendant of the woman he killed, and instead drops him between the Floaters, Tweeners and Shadows, so the full pair links mind-level and universe-level stakes. ` +
        `For deeper background see ${extLink("The World of Null-A", "https://en.wikipedia.org/wiki/The_World_of_Null-A")} and ${extLink("The Universe Maker", "https://en.wikipedia.org/wiki/The_Universe_Maker")}.`,
    },
    "D-053": {
      books: "Gateway to Elsewhere / The Weapon Shops of Isher",
      authors: "Murray Leinster and A. E. van Vogt",
      story:
        `This double combines portal fantasy and constitutional conflict. Leinster's side sends an ordinary American through a coin from Barkut &mdash; a country on no map &mdash; into a fourth-dimensional world where the djinn are a practical problem; ${cardLink("Gateway")} is threshold fiction, where the assumptions of modern science stop being reliable. ` +
        `Van Vogt's side is set in the year 4784: ${cardLink("Innelda Isher")} rules an empire from ${cardLink("Isher")}, and against her stand the Weapon Shops, storefronts that appear where they are needed and sell guns that cannot be fired in aggression, founded and quietly steered by the immortal ${cardLink("Robert Hedrock")}. ` +
        `Together they create a clean origin thread for the game: rights, force, and legitimacy at home; unknown rules and survival abroad. ` +
        `Reference overviews: ${extLink("The Weapon Shops of Isher", "https://en.wikipedia.org/wiki/The_Weapon_Shops_of_Isher")} and ${extLink("Murray Leinster", "https://en.wikipedia.org/wiki/Murray_Leinster")}.`,
    },
    "D-096": {
      books: "The Last Planet / A Man Obsessed",
      authors: "Andre Norton and Alan E. Nourse",
      story:
        `<em>The Last Planet</em> is Ace's retitling of Norton's <em>Star Rangers</em>. It opens with patrol collapse and forced adaptation: the Stellar Patrol ship Starfire is wrecked far from a failing Central Control, and ${cardLink("Kartr Rhyn")} and ${cardLink("Dosvard Rhyn")} move from formal command into frontier statecraft around the ${cardLink("Patrol Crash Site")} and the ${cardLink("Astra Ruins")}. ` +
        `That progression from military drill to settlement-building gives the card set a strong campaign arc origin. ` +
        `Nourse's companion novel, later expanded as <em>The Mercy Men</em>, is a five-year revenge hunt that ends inside sealed medical-research wards where the desperate sell themselves as experimental subjects &mdash; a much tighter, nastier kind of pressure. ` +
        `Author context: ${extLink("Andre Norton", "https://en.wikipedia.org/wiki/Andre_Norton")} and ${extLink("Alan E. Nourse", "https://en.wikipedia.org/wiki/Alan_E._Nourse")}.`,
    },
    "D-103": {
      books: "Solar Lottery / The Big Jump",
      authors: "Philip K. Dick and Leigh Brackett",
      story:
        `Dick's first published novel imagines leadership assigned by a randomising bottle and maintained by legal assassination. ${cardLink("Ted Benteley")}, ${cardLink("Leon Cartwright")}, and ${cardLink("Reese Verrick")} map onto competing responses to that system: oath-bound idealist, accidental incumbent, and displaced operator. ` +
        `Place cards like ${cardLink("Lottery Hall")} and ${cardLink("Telepath Court")} turn the novel's central institutions into playable spaces for intrigue encounters. ` +
        `Brackett's paired title contributes outward-movement adventure energy: one man forces his way to the last survivor of humanity's first interstellar flight and then makes the jump himself, balancing Dick's claustrophobic paranoia with expedition tempo. ` +
        `Useful references: ${extLink("Solar Lottery", "https://en.wikipedia.org/wiki/Solar_Lottery")} and ${extLink("The Big Jump", "https://en.wikipedia.org/wiki/The_Big_Jump")}.`,
    },
    "D-150": {
      books: "The World Jones Made / Agent of the Unknown",
      authors: "Philip K. Dick and Margaret St. Clair",
      story:
        `${cardLink("Floyd Jones")} is built around prediction as social force: he sees exactly one year ahead and must live everything twice, and that certainty makes him a demagogue against the enforced post-war doctrine of Relativism. Seeing ahead does not remove conflict, it intensifies it. ` +
        `Counterpoints such as ${cardLink("Cussick")}, a Fedgov security agent, keep the narrative grounded in ordinary political resistance instead of prophecy myth. ` +
        `St. Clair's side moves to the pleasure planetoid Fyon, where a drifter inherits a small weeping doll whose maker's secret attracts forces far beyond him. ` +
        `Locations including ${cardLink("Jonesville")} and ${cardLink("Vega Port")} translate the double's core pressures into campaign geography: cult charisma, surveillance, and frontier maneuvering. ` +
        `References: ${extLink("The World Jones Made", "https://en.wikipedia.org/wiki/The_World_Jones_Made")} and ${extLink("Margaret St. Clair", "https://en.wikipedia.org/wiki/Margaret_St._Clair")}.`,
    },
    "D-249": {
      books: "The Cosmic Puppets / Sargasso of Space",
      authors: "Philip K. Dick and Andre Norton (as Andrew North)",
      story:
        `This Ace pairing starts local and becomes metaphysical. ${cardLink("Ted Barton")} and ${cardLink("Mary Barton")} return to a familiar town, then watch that familiarity break as memory and environment diverge around ${cardLink("Millgate")} and routes like ${cardLink("Blinding Alley")} &mdash; the records say Ted Barton died of scarlet fever aged nine, and two ancient powers are using the valley as a board. ` +
        `The reverse novel is the first Solar Queen book: a free-trader crew wins sole rights to Limbo, a world burned bare in a Forerunner war where surviving alien machinery still drags ships down out of orbit. ` +
        `As an origin set, it supports campaigns where players first detect subtle wrongness before confronting open systemic threat. ` +
        `See ${extLink("The Cosmic Puppets", "https://en.wikipedia.org/wiki/The_Cosmic_Puppets")} and ${extLink("Sargasso of Space", "https://en.wikipedia.org/wiki/Sargasso_of_Space")}.`,
    },
    "D-295": {
      books: "Big Planet / Slaves of the Klau",
      authors: "Jack Vance (both sides)",
      story:
        `Vance's ${cardLink("Big Planet")} is a scale experiment: a world huge in diameter but poor in heavy metals, so technology never takes hold and culture changes every few days of travel. ` +
        `${cardLink("Claude Glystra")} leads an Earth commission brought down tens of thousands of miles from the only Earth enclave, and the book is the walk back; regions such as ${cardLink("Glinster Marsh")} demonstrate how geography itself becomes a social challenge. ` +
        `The reverse side, also Vance, follows Roy Barch from Klau forced labour into a runaway band kept alive only as quarry for hunting parties, so survival stakes stay high on both halves. ` +
        `The card ${cardLink("Woudiver")} borrows a Vance name from elsewhere in his work rather than from this volume: Aila Woudiver belongs to the later Planet of Adventure books. ` +
        `The combined origin story is exploration-first: movement, negotiation, and adaptation drive progression more than static dungeon-clearing. ` +
        `Reference links: ${extLink("Big Planet", "https://en.wikipedia.org/wiki/Big_Planet")} and ${extLink("Slaves of the Klau", "https://en.wikipedia.org/wiki/Slaves_of_the_Klau")}.`,
    },
    "D-413": {
      books: "The Man with Nine Lives / A Touch of Infinity",
      authors: "Harlan Ellison (both sides)",
      story:
        `An early Ellison double, novel on one side and collection on the other. <em>The Man with Nine Lives</em> is a revenge story driven across a string of worlds; Ellison disliked the Ace title and reissued a revised text in 2011 as <em>The Sound of a Scythe</em>. ` +
        `Card spaces such as ${cardLink("Nine Lives Safehouse")} capture the pressure of repeated pursuit and strategic concealment, and the ${cardLink("Nine Lives")} card takes its name straight from the title. ` +
        `<em>A Touch of Infinity</em> gathers Ellison's early magazine short fiction from the same period, which is where the set's shorter, sharper set-pieces come from. ` +
        `Some cards grouped under D-413, including ${cardLink("Krantz")} and ${cardLink("Destiny Branchpoint")}, are game inventions rather than characters or places traceable to either half of this volume. ` +
        `References: ${extLink("The Man with Nine Lives", "https://en.wikipedia.org/wiki/The_Man_with_Nine_Lives")} and ${extLink("Harlan Ellison", "https://en.wikipedia.org/wiki/Harlan_Ellison")}.`,
    },
    "D-421": {
      books: "Dr. Futurity / Slavers of Space",
      authors: "Philip K. Dick and John Brunner",
      story:
        `${cardLink("Dr Parsons")} gives this double a direct ethical core: a twentieth-century physician is displaced into a society built around youth and a cult of death, where the reflex to save a life is a crime. ` +
        `Locations like ${cardLink("Future Ward")} and ${cardLink("Exile Quarter")} convert those abstract tensions into practical gameplay zones involving law, triage, and political tradeoffs. ` +
        `Brunner's paired novel sends Derry Horn out from a comfortable, android-served Earth to investigate one android's murder, and ends on the discovery that there is no such thing as an android &mdash; making belonging and personhood themselves strategic questions. ` +
        `As origin material, D-421 supports campaigns that center moral negotiation and social engineering, not only combat outcomes. ` +
        `References: ${extLink("Dr. Futurity", "https://en.wikipedia.org/wiki/Dr._Futurity")} and ${extLink("Into the Slave Nebula", "https://en.wikipedia.org/wiki/Into_the_Slave_Nebula")}.`,
    },
    "D-449": {
      books: "The Genetic General / Time to Teleport",
      authors: "Gordon R. Dickson (both sides)",
      story:
        `<em>The Genetic General</em> is Ace's cut text of <em>Dorsai!</em>, the first Childe Cycle novel. ${cardLink("Donal Graeme")} sits inside a future of specialized splinter worlds, contract militaries, and doctrine-level conflict, and rises from junior officer to something no longer quite human. ` +
        `${cardLink("Dorsai")} and the ${cardLink("Friendly Worlds Council")} represent two ends of that system: field capability and strategic coordination. ` +
        `The reverse side, also Dickson, is set on an Earth carved into economic Groups, with one Group manoeuvring to absorb the rest and a secret society popularly loathed as "the Inhumans" in the middle of it. ` +
        `${cardLink("Cletus Grahame")} is Donal's ancestor in the same Childe Cycle, but he belongs to <em>Tactics of Mistake</em> (1971) and does not appear in this volume. ` +
        `The overall origin thread is organized power: who plans, who fights, and who writes legitimacy after the fight. ` +
        `Further reading: ${extLink("Dorsai!", "https://en.wikipedia.org/wiki/Dorsai!")} and ${extLink("Tactics of Mistake", "https://en.wikipedia.org/wiki/Tactics_of_Mistake")}.`,
    },
    "D-491": {
      books: "The Big Time / The Mind Spider and Other Stories",
      authors: "Fritz Leiber (both sides)",
      story:
        `${cardLink("Greta Forzane")} narrates a conflict staged away from ordinary chronology, where agents snatched from many eras gather in ${cardLink("The Big Time")} and facilities like ${cardLink("Change War Station")}, and the whole Hugo-winning novel plays out in one sealed room that turns into a locked-room problem when an atomic device goes missing. ` +
        `Characters such as ${cardLink("Bruce Marchant")}, an RAF pilot arguing that the war should simply be abandoned, ground that large temporal conflict in individual loyalties, fatigue, and moral compromise. ` +
        `The paired short-fiction side gathers further Change War stories while keeping attention on perception, pressure, and tactical framing. ` +
        `For gameplay origin, this double is ideal for missions where chronology itself is unstable and strategic certainty never lasts. ` +
        `References: ${extLink("The Big Time", "https://en.wikipedia.org/wiki/The_Big_Time_(novel)")} and ${extLink("List of Ace SF double titles", "https://en.wikipedia.org/wiki/List_of_Ace_SF_double_titles")}.`,
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
