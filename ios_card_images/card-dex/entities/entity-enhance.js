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

  fetch("../../cards.json")
    .then((res) => (res.ok ? res.json() : null))
    .then((data) => {
      if (!data) throw new Error("cards data unavailable");
      const cards = [...(data.players || []), ...(data.monsters || []), ...(data.locations || [])];
      const linked = cards.filter((c) => norm(c.source) === sourceMatch);
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
      authors: "A. E. van Vogt",
      story:
        `The A-side tracks ${cardLink("Gosseyn")} through a society that uses formal testing to classify people and hide political control. ` +
        `Much of the tension comes from identity uncertainty, since memory, status, and even bodily continuity are repeatedly challenged. ` +
        `The setting around ${cardLink("Null-A City")} and the ${cardLink("Games Machine")} reads like a puzzle-dungeon in social form, not just a battlefield. ` +
        `The reverse title shifts from personal conspiracy toward large-scale cosmological engineering, so the full pair links mind-level and universe-level stakes. ` +
        `For deeper background see ${extLink("van Vogt bibliography context", "https://en.wikipedia.org/wiki/A._E._van_Vogt")}.`,
    },
    "D-053": {
      books: "The Weapon Shops of Isher / Gateway to Elsewhere",
      authors: "A. E. van Vogt and Murray Leinster",
      story:
        `This double combines constitutional conflict and portal fantasy. On one side, ${cardLink("Robert Hedrock")} and ${cardLink("Innelda Isher")} sit inside a power struggle between imperial command and the quasi-underground institutions in ${cardLink("Isher")}. ` +
        `On the other side, ${cardLink("Gateway")} represents threshold fiction: crossing into a realm where assumptions from modern science stop being reliable. ` +
        `Together they create a clean origin thread for the game: rights, force, and legitimacy at home; unknown rules and survival abroad. ` +
        `Reference overviews: ${extLink("Weapon Shops of Isher", "https://en.wikipedia.org/wiki/The_Weapon_Shops_of_Isher")} and ${extLink("Murray Leinster", "https://en.wikipedia.org/wiki/Murray_Leinster")}.`,
    },
    "D-096": {
      books: "The Last Planet / Maza of the Moon",
      authors: "Andre Norton and Otis Adelbert Kline",
      story:
        `The Norton side opens with patrol collapse and forced adaptation: ${cardLink("Kartr Rhyn")} and ${cardLink("Dosvard Rhyn")} move from formal command into frontier statecraft after landing near the ${cardLink("Patrol Crash Site")} and ${cardLink("Astra Ruins")}. ` +
        `That progression from military drill to settlement-building gives the card set a strong campaign arc origin. ` +
        `Kline's companion novel keeps planetary-adventure momentum, emphasizing exploration pressure and local conflict economies. ` +
        `Author context: ${extLink("Andre Norton", "https://en.wikipedia.org/wiki/Andre_Norton")} and ${extLink("Otis Adelbert Kline", "https://en.wikipedia.org/wiki/Otis_Adelbert_Kline")}.`,
    },
    "D-103": {
      books: "Solar Lottery / The Big Jump",
      authors: "Philip K. Dick and Leigh Brackett",
      story:
        `Dick's early political SF imagines leadership selected by mechanism and maintained by violence. ${cardLink("Ted Benteley")}, ${cardLink("Leon Cartwright")}, and ${cardLink("Reese Verrick")} map onto competing responses to that system: witness, participant, and operator. ` +
        `Place cards like ${cardLink("Lottery Hall")} and ${cardLink("Telepath Court")} turn the novel's central institutions into playable spaces for intrigue encounters. ` +
        `Brackett's paired title contributes outward-movement adventure energy, balancing Dick's claustrophobic paranoia with expedition tempo. ` +
        `Useful references: ${extLink("Solar Lottery", "https://en.wikipedia.org/wiki/Solar_Lottery")} and ${extLink("Leigh Brackett", "https://en.wikipedia.org/wiki/Leigh_Brackett")}.`,
    },
    "D-150": {
      books: "The World Jones Made / Agent of Vega",
      authors: "Philip K. Dick and James H. Schmitz",
      story:
        `${cardLink("Floyd Jones")} is built around prediction as social force: seeing ahead does not remove conflict, it intensifies it. ` +
        `Counterpoints such as ${cardLink("Cussick")} keep the narrative grounded in ordinary political resistance instead of prophecy myth. ` +
        `Locations including ${cardLink("Jonesville")} and ${cardLink("Vega Port")} translate the double's core pressures into campaign geography: cult charisma, surveillance, and frontier maneuvering. ` +
        `Schmitz's side supports fast-moving interstellar operations, so this pair works as origin material for both psychological and mission-based play. ` +
        `References: ${extLink("The World Jones Made", "https://en.wikipedia.org/wiki/The_World_Jones_Made")} and ${extLink("James H. Schmitz", "https://en.wikipedia.org/wiki/James_H._Schmitz")}.`,
    },
    "D-249": {
      books: "The Cosmic Puppets / The Last Enemy",
      authors: "Philip K. Dick and H. Beam Piper",
      story:
        `This Ace pairing starts local and becomes metaphysical. ${cardLink("Ted Barton")} and ${cardLink("Mary Barton")} return to a familiar town, then watch that familiarity break as memory and environment diverge around ${cardLink("Millgate")} and routes like ${cardLink("Blinding Alley")}. ` +
        `The reverse novel raises scale toward military and species-level conflict, giving the double both intimate and strategic angles. ` +
        `As an origin set, it supports campaigns where players first detect subtle wrongness before confronting open systemic threat. ` +
        `See ${extLink("The Cosmic Puppets", "https://en.wikipedia.org/wiki/The_Cosmic_Puppets")} and ${extLink("H. Beam Piper", "https://en.wikipedia.org/wiki/H._Beam_Piper")}.`,
    },
    "D-295": {
      books: "Big Planet / The Last Spaceship",
      authors: "Jack Vance and Murray Leinster",
      story:
        `Vance's ${cardLink("Big Planet")} is a scale experiment: technology limits, sparse resources, and culture change every few days of travel. ` +
        `${cardLink("Claude Glystra")} and ${cardLink("Woudiver")} anchor the human conflict side while regions such as ${cardLink("Glinster Marsh")} demonstrate how geography itself becomes a social challenge. ` +
        `Leinster's partner novel keeps survival stakes high with transport fragility and mission urgency. ` +
        `The combined origin story is exploration-first: movement, negotiation, and adaptation drive progression more than static dungeon-clearing. ` +
        `Reference links: ${extLink("Big Planet", "https://en.wikipedia.org/wiki/Big_Planet")} and ${extLink("The Last Spaceship", "https://www.isfdb.org/cgi-bin/title.cgi?5861")}.`,
    },
    "D-413": {
      books: "The Man with Nine Lives / Destiny Times Three",
      authors: "Harlan Ellison and Fritz Leiber",
      story:
        `The Ellison side frames identity as unstable evidence: people recur, personalities shift, and investigators like ${cardLink("Krantz")} must decide what continuity even means. ` +
        `Card spaces such as ${cardLink("Nine Lives Safehouse")} capture the pressure of repeated pursuit and strategic concealment. ` +
        `Leiber's companion novella adds branching-future logic, represented in locations like ${cardLink("Destiny Branchpoint")}, where alternate outcomes feel immediate and tactical. ` +
        `This gives the D-413 origin block a strong mystery-plus-timeline flavor rather than pure action. ` +
        `References: ${extLink("Harlan Ellison", "https://en.wikipedia.org/wiki/Harlan_Ellison")} and ${extLink("Fritz Leiber", "https://en.wikipedia.org/wiki/Fritz_Leiber")}.`,
    },
    "D-421": {
      books: "Dr. Futurity / No World of Their Own",
      authors: "Philip K. Dick and Clifford D. Simak",
      story:
        `${cardLink("Dr Parsons")} gives this double a direct ethical core: a healer is displaced into a social order where healing may violate local norms. ` +
        `Locations like ${cardLink("Future Ward")} and ${cardLink("Exile Quarter")} convert those abstract tensions into practical gameplay zones involving law, triage, and political tradeoffs. ` +
        `Simak's paired novel reinforces outsider perspective and community boundary themes, making belonging itself a strategic question. ` +
        `As origin material, D-421 supports campaigns that center moral negotiation and social engineering, not only combat outcomes. ` +
        `References: ${extLink("Dr. Futurity", "https://en.wikipedia.org/wiki/Dr._Futurity")} and ${extLink("Clifford D. Simak", "https://en.wikipedia.org/wiki/Clifford_D._Simak")}.`,
    },
    "D-449": {
      books: "The Genetic General / Time Crime",
      authors: "Gordon R. Dickson and H. Beam Piper",
      story:
        `${cardLink("Donal Graeme")} and ${cardLink("Cletus Grahame")} sit inside a future of specialized worlds, contract militaries, and doctrine-level conflict. ` +
        `${cardLink("Dorsai")} and the ${cardLink("Friendly Worlds Council")} represent two ends of that system: field capability and strategic coordination. ` +
        `Piper's companion title adds temporal law and intervention themes, so command decisions can ripple beyond one battlefield or era. ` +
        `The overall origin thread is organized power: who plans, who fights, and who writes legitimacy after the fight. ` +
        `Further reading: ${extLink("Dorsai!", "https://en.wikipedia.org/wiki/Dorsai!")} and ${extLink("Time Crime", "https://www.isfdb.org/cgi-bin/title.cgi?5022")}.`,
    },
    "D-491": {
      books: "The Big Time / The Mind-Spider and Other Stories",
      authors: "Fritz Leiber",
      story:
        `${cardLink("Greta Forzane")} narrates a conflict staged away from ordinary chronology, where agents from many eras gather in ${cardLink("The Big Time")} and facilities like ${cardLink("Change War Station")}. ` +
        `Characters such as ${cardLink("Bruce Marchant")} ground that large temporal conflict in individual loyalties, fatigue, and moral compromise. ` +
        `The paired short-fiction side broadens Leiber's speculative toolkit while keeping attention on perception, pressure, and tactical framing. ` +
        `For gameplay origin, this double is ideal for missions where chronology itself is unstable and strategic certainty never lasts. ` +
        `References: ${extLink("The Big Time", "https://en.wikipedia.org/wiki/The_Big_Time_(novel)")} and ${extLink("List of Ace doubles", "https://en.wikipedia.org/wiki/List_of_Ace_double_titles")}.`,
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
