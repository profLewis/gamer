const inlineCard = window.CARD;

function byId(id) { return document.getElementById(id); }
function q(s) { return encodeURIComponent(s); }
function norm(s) { return (s || '').trim().toLowerCase(); }
function isAceSource(source) { return /^Ace Double D-\d{3} \(\d{4}\)$/.test((source || '').trim()); }

function loreRelativeEntityPath(sourceEntityPage) {
  const raw = (sourceEntityPage || '').trim();
  if (!raw) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  const stripped = raw.startsWith('card-dex/') ? raw.slice('card-dex/'.length) : raw;
  return `../${stripped}`;
}

const WIKI_OVERRIDES = {
  "player-008": "https://en.wikipedia.org/wiki/Eleven_(Stranger_Things)",
  "player-010": "https://en.wikipedia.org/wiki/Jim_Hopper_(Stranger_Things)",
  "player-011": "https://en.wikipedia.org/wiki/Steve_Harrington",
  "player-019": "https://en.wikipedia.org/wiki/Ellen_Ripley",
  "player-020": "https://en.wikipedia.org/wiki/Rick_Deckard",
  "player-021": "https://en.wikipedia.org/wiki/Paul_Atreides",
  "player-023": "https://en.wikipedia.org/wiki/R._Daneel_Olivaw",
  "player-024": "https://en.wikipedia.org/wiki/Marvin_the_Paranoid_Android",
  "player-025": "https://en.wikipedia.org/wiki/K9_(Doctor_Who)",
  "player-026": "https://en.wikipedia.org/wiki/Roy_Batty",
  "player-028": "https://en.wikipedia.org/wiki/Willow_Ufgood",
  "player-030": "https://en.wikipedia.org/wiki/Conan_the_Barbarian",
  "player-031": "https://en.wikipedia.org/wiki/Connor_MacLeod",
  "player-032": "https://en.wikipedia.org/wiki/Jareth",
  "player-033": "https://en.wikipedia.org/wiki/Lord_of_Darkness_(Legend)",
  "player-039": "https://en.wikipedia.org/wiki/Elric_of_Melnibon%C3%A9",
  "player-041": "https://en.wikipedia.org/wiki/Drizzt_Do%27Urden",
  "player-042": "https://en.wikipedia.org/wiki/Raistlin_Majere",
  "player-043": "https://en.wikipedia.org/wiki/Tasslehoff_Burrfoot",
  "player-044": "https://en.wikipedia.org/wiki/Rincewind",
  "player-045": "https://en.wikipedia.org/wiki/Granny_Weatherwax",
  "player-046": "https://en.wikipedia.org/wiki/Belgarion",
  "player-048": "https://en.wikipedia.org/wiki/Gray_Mouser",
  "player-049": "https://en.wikipedia.org/wiki/Thomas_Covenant",
  "player-050": "https://en.wikipedia.org/wiki/Tenar",
  "player-054": "https://en.wikipedia.org/wiki/Death_(Discworld)",
  "player-055": "https://en.wikipedia.org/wiki/The_Chronicles_of_Amber#Corwin",
  "player-056": "https://en.wikipedia.org/wiki/Corum_Jhaelen_Irsei",
  "player-058": "https://en.wikipedia.org/wiki/Skeletor",
  "player-060": "https://en.wikipedia.org/wiki/He-Man",
  "player-061": "https://en.wikipedia.org/wiki/Lion-O",
  "player-062": "https://en.wikipedia.org/wiki/Noggin_the_Nog",
  "player-064": "https://en.wikipedia.org/wiki/Doctor_Who_(character)",
  "player-065": "https://en.wikipedia.org/wiki/Davros",
  "player-066": "https://en.wikipedia.org/wiki/List_of_Blake%27s_7_characters#Kerr_Avon",
  "player-067": "https://en.wikipedia.org/wiki/Ulysses_31",
  "player-068": "https://en.wikipedia.org/wiki/The_Mysterious_Cities_of_Gold",
  "player-070": "https://en.wikipedia.org/wiki/Dogtanian_and_the_Three_Muskehounds",
  "player-071": "https://en.wikipedia.org/wiki/Top_Cat",
  "player-073": "https://en.wikipedia.org/wiki/Top_Cat",
  "player-074": "https://en.wikipedia.org/wiki/Top_Cat",
  "player-075": "https://en.wikipedia.org/wiki/Dick_Dastardly",
  "player-076": "https://en.wikipedia.org/wiki/Muttley",
  "player-077": "https://en.wikipedia.org/wiki/Penelope_Pitstop",
  "player-079": "https://en.wikipedia.org/wiki/Road_Runner",
  "player-080": "https://en.wikipedia.org/wiki/Danger_Mouse_(1981_TV_series)",
  "player-081": "https://en.wikipedia.org/wiki/Danger_Mouse_(1981_TV_series)",
  "player-082": "https://en.wikipedia.org/wiki/Pinky_and_the_Brain#Characters",
  "player-083": "https://en.wikipedia.org/wiki/Pinky_and_the_Brain#Characters",
  "player-084": "https://en.wikipedia.org/wiki/Wacky_Races#Original_series",
  "player-086": "https://en.wikipedia.org/wiki/The_World_of_Null-A",
  "player-087": "https://en.wikipedia.org/wiki/Solar_Lottery",
  "player-088": "https://en.wikipedia.org/wiki/The_World_Jones_Made",
  "player-089": "https://en.wikipedia.org/wiki/Dr._Futurity",
  "player-090": "https://en.wikipedia.org/wiki/Harlan_Ellison_bibliography",
  "player-091": "https://en.wikipedia.org/wiki/Dorsai!",
  "player-092": "https://en.wikipedia.org/wiki/Andre_Norton_bibliography",
};

async function loadAllCards() {
  try {
    const res = await fetch('../../cards.json');
    if (!res.ok) return [];
    const data = await res.json();
    return [...(data.players || []), ...(data.monsters || []), ...(data.locations || [])];
  } catch (_) {
    return [];
  }
}

async function fetchWikiSummaryByTitle(title) {
  const res = await fetch(`https://en.wikipedia.org/api/rest_v1/page/summary/${q(title)}`);
  if (!res.ok) return null;
  return await res.json();
}

async function fetchWikidataEntity(itemId) {
  try {
    const res = await fetch(`https://www.wikidata.org/wiki/Special:EntityData/${q(itemId)}.json`);
    if (!res.ok) return null;
    const data = await res.json();
    return data?.entities?.[itemId] || null;
  } catch (_) {
    return null;
  }
}

function firstClaimValue(entity, pid) {
  const claim = entity?.claims?.[pid]?.[0];
  const val = claim?.mainsnak?.datavalue?.value;
  if (val == null) return null;
  if (typeof val === 'string') return val;
  if (typeof val === 'object') {
    if (typeof val.id === 'string') return val.id;
    if (typeof val.numeric-id === 'number') return `Q${val['numeric-id']}`;
    if (typeof val.amount === 'string') return val.amount;
  }
  return null;
}

async function searchWiki(query) {
  const res = await fetch(`https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${q(query)}&srlimit=6&format=json&origin=*`);
  if (!res.ok) return [];
  const data = await res.json();
  return data?.query?.search || [];
}

async function loadWikiBest(card) {
  // Ace-derived cards should use curated source-card references/covers, not open-ended search.
  if (isAceSource(card.source)) return null;

  if (WIKI_OVERRIDES[card.id]) {
    const url = WIKI_OVERRIDES[card.id];
    try {
      const u = new URL(url);
      const m = u.pathname.match(/^\/wiki\/([^#?]+)/);
      if (m) {
        const title = decodeURIComponent(m[1]).replace(/_/g, ' ');
        const sum = await fetchWikiSummaryByTitle(title);
        if (sum && sum.type !== 'disambiguation') {
          return { url, summary: sum, title };
        }
      }
    } catch (_) {}
    return { url, summary: null, title: null };
  }
  const srcNoYear = (card.source || '').replace(/\(\d{4}\)/g, '').trim();
  const queries = [
    `${card.name} ${card.source || ''}`.trim(),
    `${card.name} ${srcNoYear}`.trim(),
    card.name,
  ].filter(Boolean);
  for (const query of queries) {
    try {
      const matches = await searchWiki(query);
      for (const m of matches) {
        const sum = await fetchWikiSummaryByTitle(m.title);
        if (!sum || !sum.extract) continue;
        if (sum.type === 'disambiguation') continue;
        const qTokens = query.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((t) => t.length > 3);
        const hay = `${m.title} ${sum.extract}`.toLowerCase();
        const overlap = qTokens.filter((t) => hay.includes(t)).length;
        if (qTokens.length >= 2 && overlap < 2) continue;
        const url = sum?.content_urls?.desktop?.page;
        if (!url) continue;
        return { url, summary: sum, title: m.title };
      }
    } catch (_) {}
  }
  return null;
}

async function loadEntityData(card) {
  if (!card.source_entity_page) return null;
  try {
    const rel = loreRelativeEntityPath(card.source_entity_page);
    if (!rel) return null;
    const entityUrl = new URL(rel, window.location.href);
    const res = await fetch(entityUrl.href);
    if (!res.ok) return null;
    const html = await res.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');

    const img = doc.querySelector('.wiki-img');
    const images = Array.from(doc.querySelectorAll('.wiki-img')).map((im) => {
      const src = im.getAttribute('src');
      const anchor = im.closest('a[href]');
      const href = anchor ? anchor.getAttribute('href') : null;
      return {
        src: src ? new URL(src, entityUrl.href).href : null,
        href: href ? new URL(href, entityUrl.href).href : null,
      };
    }).filter((x) => Boolean(x.src));
    const summaries = Array.from(doc.querySelectorAll('.summary')).map((x) => (x.textContent || '').trim()).filter(Boolean);
    const links = Array.from(doc.querySelectorAll('.links a[href]')).map((a) => ({
      label: (a.textContent || '').trim() || 'Reference',
      href: new URL(a.getAttribute('href'), entityUrl.href).href,
    })).filter((l) => Boolean(l.href));

    return {
      image: img ? new URL(img.getAttribute('src'), entityUrl.href).href : null,
      images,
      summary: summaries[0] || '',
      links,
    };
  } catch (_) {
    return null;
  }
}

function isLikelySearchLink(url) {
  const u = url.toLowerCase();
  return u.includes('/search') || u.includes('search?') || u.includes('query=');
}

async function isDisambiguationWikiUrl(url) {
  try {
    const u = new URL(url);
    if (!u.hostname.includes('wikipedia.org')) return false;
    const m = u.pathname.match(/^\/wiki\/([^#?]+)/);
    if (!m) return false;
    const title = decodeURIComponent(m[1]).replace(/_/g, ' ');
    const sum = await fetchWikiSummaryByTitle(title);
    return sum?.type === 'disambiguation';
  } catch (_) {
    return false;
  }
}

function makeLink(label, href) {
  const a = document.createElement('a');
  a.href = href;
  a.target = '_blank';
  a.rel = 'noopener noreferrer';
  a.textContent = label;
  return a;
}

function lorePageHref(c) {
  if (!c || !c.lore_page) return null;
  const file = c.lore_page.split('/').pop();
  return file ? `./${file}` : null;
}

function renderLoreNav(card, allCards) {
  const pool = allCards.filter((c) => c.type === card.type && c.lore_page);
  if (!pool.length) return;
  const idx = pool.findIndex((c) => c.id === card.id);
  if (idx < 0) return;

  const topbar = document.querySelector('.topbar');
  if (!topbar || !topbar.parentElement) return;

  const nav = document.createElement('nav');
  nav.className = 'lore-nav';
  nav.setAttribute('aria-label', 'Card navigation');
  nav.innerHTML = [
    '<button id="lorePrevBtn" class="btn" type="button">Prev</button>',
    '<button id="loreDiceBtn" class="btn" type="button">d20</button>',
    '<button id="loreNextBtn" class="btn" type="button">Next</button>',
    `<span class="lore-pos">${idx + 1}/${pool.length}</span>`,
  ].join('');
  topbar.parentElement.insertBefore(nav, topbar.nextSibling);

  const go = (target) => {
    const href = lorePageHref(target);
    if (!href) return;
    window.location.href = href;
  };
  const prev = () => go(pool[(idx - 1 + pool.length) % pool.length]);
  const next = () => go(pool[(idx + 1) % pool.length]);
  const dice = () => {
    if (pool.length < 2) return;
    let r = idx;
    while (r === idx) r = Math.floor(Math.random() * pool.length);
    go(pool[r]);
  };

  nav.querySelector('#lorePrevBtn')?.addEventListener('click', prev);
  nav.querySelector('#loreNextBtn')?.addEventListener('click', next);
  nav.querySelector('#loreDiceBtn')?.addEventListener('click', dice);
}

function ensureImageSourceLink(imgEl, href) {
  if (!imgEl || !href) return;
  const currentParent = imgEl.parentElement;
  if (currentParent && currentParent.tagName.toLowerCase() === 'a') {
    currentParent.href = href;
    currentParent.target = '_blank';
    currentParent.rel = 'noopener noreferrer';
    return;
  }
  const a = document.createElement('a');
  a.href = href;
  a.target = '_blank';
  a.rel = 'noopener noreferrer';
  imgEl.parentElement.insertBefore(a, imgEl);
  a.appendChild(imgEl);
}

function renderImageGallery(entity, titleText, className) {
  if (!entity?.images || entity.images.length < 2) return;
  const existing = document.querySelector(`.${className}`);
  if (existing) existing.remove();

  const images = entity.images.slice(0, 4);
  const panel = document.createElement('div');
  panel.className = className;
  panel.innerHTML = [
    `<div class="small" style="margin-top:10px">${titleText}</div>`,
    `<div class="ace-cover-grid">${images.map((im, i) => (
      `<a href="${im.href || im.src}" target="_blank" rel="noopener noreferrer">` +
      `<img src="${im.src}" alt="${titleText} image ${i + 1}" loading="lazy" />` +
      '</a>'
    )).join('')}</div>`,
  ].join('');
  const refPanel = byId('summary')?.closest('.panel');
  if (refPanel) refPanel.appendChild(panel);
}

async function buildSupplementalLinks(wiki) {
  const out = [];
  const qid = wiki?.summary?.wikibase_item;
  if (!qid) return out;
  out.push({ label: 'Wikidata', href: `https://www.wikidata.org/wiki/${qid}` });

  const entity = await fetchWikidataEntity(qid);
  if (!entity) return out;

  const imdb = firstClaimValue(entity, 'P345');
  if (imdb) {
    const id = imdb.startsWith('tt') ? imdb : `tt${imdb}`;
    out.push({ label: 'IMDb', href: `https://www.imdb.com/title/${id}/` });
  }

  const isbn13 = firstClaimValue(entity, 'P212');
  if (isbn13) out.push({ label: 'OpenLibrary ISBN', href: `https://openlibrary.org/isbn/${encodeURIComponent(isbn13)}` });
  const isbn10 = firstClaimValue(entity, 'P957');
  if (isbn10) out.push({ label: 'OpenLibrary ISBN-10', href: `https://openlibrary.org/isbn/${encodeURIComponent(isbn10)}` });

  const ia = firstClaimValue(entity, 'P724');
  if (ia) out.push({ label: 'Internet Archive', href: `https://archive.org/details/${encodeURIComponent(ia)}` });

  const viaf = firstClaimValue(entity, 'P214');
  if (viaf) out.push({ label: 'VIAF', href: `https://viaf.org/viaf/${encodeURIComponent(viaf)}` });

  const official = firstClaimValue(entity, 'P856');
  if (official && /^https?:\/\//i.test(official)) out.push({ label: 'Official Site', href: official });

  return out;
}

function renderBase(card) {
  byId('title').textContent = card.name;
  byId('meta').textContent = `${(card.type || '').toUpperCase()} - ${card.source || 'Reference'}`;
  byId('cardImg').src = `../../${card.image}`;
  byId('cardImg').alt = card.name;
  byId('summary').textContent = `Reference notes for ${card.name}.`;
}

function firstSentence(text) {
  const t = (text || '').trim();
  if (!t) return '';
  const protectedText = t.replace(/\b(?:[A-Za-z]\.\s*){2,}/g, (m) => m.replace(/\./g, ''));
  const m = protectedText.match(/.+?[.!?](?:\s|$)/);
  const out = (m ? m[0] : protectedText).trim();
  return out;
}

function wordSet(text) {
  return new Set(
    (text || '')
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 3)
  );
}

function overlapRatio(a, b) {
  const aa = wordSet(a);
  const bb = wordSet(b);
  if (!aa.size || !bb.size) return 0;
  let common = 0;
  for (const w of aa) if (bb.has(w)) common += 1;
  return common / Math.min(aa.size, bb.size);
}

function gameplayFocus(card) {
  const stats = card.stats || {};
  const pairs = Object.entries(stats).filter(([, v]) => typeof v === 'number');
  if (!pairs.length) return `${card.name} is included as part of the default DnDex roster.`;
  pairs.sort((a, b) => b[1] - a[1]);
  const top = pairs.slice(0, 2).map(([k, v]) => `${k} ${v}`);
  return `${card.name} is tuned as a ${card.type} card with emphasis on ${top.join(' and ')}.`;
}

function firstTwoSentences(text) {
  const t = (text || '').trim();
  if (!t) return '';
  const protectedText = t.replace(/\b(?:[A-Za-z]\.\s*){2,}/g, (m) => m.replace(/\./g, ''));
  const parts = protectedText.match(/[^.!?]+[.!?]/g) || [protectedText];
  const out = parts.slice(0, 2).map((s) => s.trim()).join(' ').trim();
  if (/(?:\b[A-Za-z]\.\s*){1,3}$/.test(out)) return protectedText;
  return out;
}

const SOURCE_CONTEXT = {
  'terry pratchett': 'Discworld source material emphasizes civic satire, institutional absurdity, and character ethics beneath the humor.',
  'j.r.r. tolkien': 'Tolkien source material emphasizes deep-history worldbuilding, travel arcs, and faction conflict at mythic scale.',
  'j-r-r-tolkien': 'Tolkien source material emphasizes deep-history worldbuilding, travel arcs, and faction conflict at mythic scale.',
  'ursula k. le guin': 'Earthsea-linked source material emphasizes naming, balance, restraint, and responsibility over spectacle-first magic.',
  'dragonlance': 'Dragonlance source material emphasizes party chemistry, dragon-war escalation, and prophecy-driven campaign momentum.',
  'fritz leiber': 'Leiber source material emphasizes urban sword-and-sorcery texture, rogue improvisation, and high-pressure city encounters.',
  'michael moorcock': 'Moorcock source material emphasizes anti-hero framing, cursed power, and multiversal stakes with moral ambiguity.',
  'isaac asimov': 'Asimov-linked source material emphasizes systems-level conflict, logic constraints, and institution-driven plot progression.',
  'classic sci-fi': 'Classic sci-fi references in this set emphasize first-contact anxiety, frontier survival, and technology-as-social-pressure.',
  'famous robots': 'Robot-focused material in this set emphasizes identity, agency, and duty-versus-programming conflict.',
  'alien (1979)': 'Alien-derived material emphasizes industrial-space realism, creature-horror pacing, and survival decisions under uncertainty.',
  "blake's 7 (1978)": 'Blake\'s 7 source material emphasizes anti-authoritarian cells, moral ambiguity, and tactical improvisation against larger state power.',
  'doctor who (1963)': 'Doctor Who material emphasizes exploration, problem-solving under time pressure, and non-linear campaign hooks.',
  'forbidden planet (1956)': 'Forbidden Planet source material emphasizes ancient technology risk, subconscious threat projection, and isolated outpost tension.',
};

const SOURCE_DOSSIER = {
  'terry pratchett': {
    plot: 'Ankh-Morpork-centered stories blend crime, guild politics, and absurd bureaucracy, then resolve through sharp social observation rather than simple hero-villain binaries.',
    people: 'Key figures in this set include Rincewind, Granny Weatherwax, and DEATH, each representing a different Discworld mode: survival comedy, moral authority, and metaphysical satire.',
    dnd: 'Use this source for urban campaigns where law, religion, and commerce are all active encounter systems, not just background flavor.',
  },
  'dragonlance': {
    plot: 'Dragonlance arcs often start with old companions reuniting, then escalate into war-scale conflicts involving gods, dragons, and world-shaping artifacts.',
    people: 'Raistlin and Tasslehoff are useful contrasts: ruthless long-game wizard ambition versus curiosity-driven chaos and loyalty.',
    dnd: 'Excellent for party-bond campaigns where interpersonal trust is as important as stat optimization.',
  },
  'ursula k. le guin': {
    plot: 'Earthsea stories focus on naming, responsibility, and balance; conflicts are frequently resolved through understanding and restraint, not maximum-force spellcasting.',
    people: 'Ged and Tenar in this set model growth-through-accountability rather than power fantasy.',
    dnd: 'Best used in campaigns where magic has ethical cost and social consequences.',
  },
  'fritz leiber': {
    plot: 'Leiber city stories run on theft, rivalry, and sudden reversals, with danger shifting block by block.',
    people: 'Fafhrd and the Gray Mouser define the mismatched duo pattern that still shapes rogue-fighter party dynamics.',
    dnd: 'Strong fit for city-crawl sessions with heists, guild pressure, and improvisational combat.',
  },
  'j.r.r. tolkien': {
    plot: 'Tolkien plots combine long travel routes, faction conflict, and artifact-driven stakes where tactical success still depends on moral decisions.',
    people: 'Aragorn and Sauron in this set represent opposite command models: restorative leadership versus total domination.',
    dnd: 'Use for high-commitment campaigns with map progression, alliance management, and legacy consequences.',
  },
  'j-r-r-tolkien': {
    plot: 'Tolkien plots combine long travel routes, faction conflict, and artifact-driven stakes where tactical success still depends on moral decisions.',
    people: 'Aragorn and Sauron in this set represent opposite command models: restorative leadership versus total domination.',
    dnd: 'Use for high-commitment campaigns with map progression, alliance management, and legacy consequences.',
  },
  'stranger things': {
    plot: 'The source mixes coming-of-age group dynamics with escalating dimension-horror stakes and government secrecy.',
    people: 'Will, Eleven, Hopper, and Eddie map cleanly onto wizard, psion, guardian, and bard-style campaign roles.',
    dnd: 'Useful for campaigns that alternate between social downtime and high-threat planar incursions.',
  },
  'honour among thieves': {
    plot: 'The story is structured like a tabletop campaign: botched plans, role-based recoveries, and a heist objective that keeps mutating.',
    people: 'Edgin, Holga, and Xenk provide strong contrasts in persuasion, frontline force, and rigid moral code.',
    dnd: 'Great source for party banter and encounter chains where creativity outperforms brute-force sequencing.',
  },
  'wacky races (1968)': {
    plot: 'Episodes are race-framework comedies driven by sabotage loops, personality clashes, and repeated tactical gimmicks.',
    people: 'Penelope, Dastardly, Muttley, and Professor Pat Pending map to charm build, trickster antagonist, wildcard ally, and gadget specialist.',
    dnd: 'Useful inspiration for light, fast, objective-based sessions where positioning and improvisation matter.',
  },
  'ace double d-096 (1955)': {
    plot: 'The Last Planet thread is a stranded-command survival story: patrol collapse, unknown terrain, and reorganization under pressure.',
    people: 'Kartr Rhyn and Dosvard Rhyn support commander and field-officer archetypes in resource-limited campaigns.',
    dnd: 'Use for crash-site openings and frontier governance scenarios where logistics and diplomacy decide survival.',
  },
  'ace double d-053 (1954)': {
    plot: 'This pairing combines political liberty conflict (Weapon Shops/Isher) with portal transition into an unfamiliar rule set.',
    people: 'Robert Hedrock and Innelda Isher anchor the power-versus-freedom axis used in several linked cards.',
    dnd: 'Works well for campaigns that pivot between court intrigue and unknown-world exploration.',
  },
  'ace double d-491 (1961)': {
    plot: 'The Big Time strand frames conflict as timeline warfare, with characters operating from a neutral station outside standard chronology.',
    people: 'Greta Forzane and Bruce Marchant provide observer and frontline perspectives on paradox-era operations.',
    dnd: 'Strong base for time-fracture campaigns where mission order and causal stability are part of encounter design.',
  },
  'classic sci-fi': {
    plot: 'These entries draw from mid-century and late-20th-century SF where threat design is tied to setting logic: closed ships, hostile planets, unstable institutions, and technology with side effects.',
    people: 'The character mix usually pairs specialists (pilot, analyst, scientist, enforcer) with conflicting priorities, creating encounter hooks that feel strategic rather than purely heroic.',
    dnd: 'Use this source stream when you want dungeon loops to feel like mission-planning loops, with reconnaissance, risk tolerance, and extraction choices.',
  },
  'famous robots': {
    plot: 'Robot-centered stories in this roster frequently pivot on command hierarchy, ethics protocols, and the gap between literal instruction and contextual judgment.',
    people: 'Cards linked to this source map onto protector constructs, bureaucratic machine minds, and emergent-personality companions, each with different negotiation profiles.',
    dnd: 'Ideal for campaigns where constructs are not only enemies but also allies, witnesses, and moral stress-tests for party decisions.',
  },
  'isaac asimov': {
    plot: 'Asimov-adjacent entries in this game lean on institutional science fiction: detective structures, systems analysis, and long-range political engineering.',
    people: 'Recurring archetypes include the rational investigator, the protocol-bound robot, and the planner whose strategy is measured in decades rather than scenes.',
    dnd: 'Strong fit for campaigns where clues, governance, and prediction matter as much as direct combat throughput.',
  },
  'alien (1979)': {
    plot: 'The core scenario is a commercial crew diverted to a hostile signal, then trapped in a shrinking-safe-space loop as an unknown organism matures aboard ship.',
    people: 'Ripley functions as the practical chain-of-command survivor, Ash as a concealed corporate vector, and Dallas/Lambert/Parker/Brett as role-specialists under escalating stress.',
    dnd: 'Use this source for survival-horror modules where map control, resource scarcity, and trust fractures are primary mechanics.',
  },
  "blake's 7 (1978)": {
    plot: 'Story structure favors asymmetric resistance operations, with small-team raids and intelligence moves against a much larger authoritarian system.',
    people: 'Blake and Avon frame the campaign polarity between idealist rebellion and hard-edged pragmatism, while Vila, Cally, and Jenna support infiltration, discipline, and mobility roles.',
    dnd: 'Excellent for party play where objective success and moral cost are intentionally in tension.',
  },
  'doctor who (1963)': {
    plot: 'Episodes repeatedly open with a place-time anomaly, then progress through investigation, social decoding, and escalating choice pressure before resolution.',
    people: 'The Doctor archetype is a high-intellect, low-ego-force problem solver; companions anchor human stakes and provide alternate social access in hostile settings.',
    dnd: 'Useful when campaigns need varied locations and puzzle-heavy pacing without relying on a single static faction map.',
  },
  'forbidden planet (1956)': {
    plot: 'The narrative begins as a rescue and status check mission, then transitions into a confrontation with hidden legacy technology that externalizes buried psychological threat.',
    people: 'Commander Adams, Dr Morbius, and Altaira provide command, knowledge-keeper, and social-bridge roles, while Robby models service-intelligence with explicit operational limits.',
    dnd: 'Strong inspiration for ruin-exploration campaigns where lore, restraint, and epistemic risk are as dangerous as monsters.',
  },
};

const SCI_FI_REFERENCE_LINKS = {
  'classic sci-fi': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Science Fiction (Encyclopedia Britannica)', 'https://www.britannica.com/art/science-fiction'],
    ['Science Fiction (Wikipedia)', 'https://en.wikipedia.org/wiki/Science_fiction'],
    ['Science Fiction Foundation', 'https://www.sf-foundation.org/'],
  ],
  'famous robots': [
    ['List of Fictional Robots (Wikipedia)', 'https://en.wikipedia.org/wiki/List_of_fictional_robots_and_androids'],
    ['Robotics in Fiction (Wikipedia)', 'https://en.wikipedia.org/wiki/Robotics_in_fiction'],
    ['RUR and Robot Origin (Wikipedia)', 'https://en.wikipedia.org/wiki/R.U.R.'],
  ],
  'isaac asimov': [
    ['Isaac Asimov (Encyclopedia Britannica)', 'https://www.britannica.com/biography/Isaac-Asimov'],
    ['Isaac Asimov (Wikipedia)', 'https://en.wikipedia.org/wiki/Isaac_Asimov'],
    ['Foundation Series (Wikipedia)', 'https://en.wikipedia.org/wiki/Foundation_series'],
  ],
  'alien (1979)': [
    ['Alien (1979 film) (Wikipedia)', 'https://en.wikipedia.org/wiki/Alien_(film)'],
    ['Alien (1979) (IMDb)', 'https://www.imdb.com/title/tt0078748/'],
    ['Alien Franchise (Wikipedia)', 'https://en.wikipedia.org/wiki/Alien_(franchise)'],
  ],
  "blake's 7 (1978)": [
    ['Blake\'s 7 (Wikipedia)', 'https://en.wikipedia.org/wiki/Blake%27s_7'],
    ['List of Blake\'s 7 Characters (Wikipedia)', 'https://en.wikipedia.org/wiki/List_of_Blake%27s_7_characters'],
    ['Blake\'s 7 (IMDb)', 'https://www.imdb.com/title/tt0076987/'],
  ],
  'doctor who (1963)': [
    ['Doctor Who (Wikipedia)', 'https://en.wikipedia.org/wiki/Doctor_Who'],
    ['Doctor Who (1963) (IMDb)', 'https://www.imdb.com/title/tt0056751/'],
    ['BBC Doctor Who', 'https://www.bbc.co.uk/doctorwho'],
  ],
  'forbidden planet (1956)': [
    ['Forbidden Planet (Wikipedia)', 'https://en.wikipedia.org/wiki/Forbidden_Planet'],
    ['Forbidden Planet (IMDb)', 'https://www.imdb.com/title/tt0049223/'],
    ['Robby the Robot (Wikipedia)', 'https://en.wikipedia.org/wiki/Robby_the_Robot'],
  ],
  'ace double d-031 (1953)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-053 (1954)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-096 (1955)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-103 (1955)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-150 (1956)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-249 (1957)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-295 (1958)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-413 (1959)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-421 (1960)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-449 (1960)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
  'ace double d-491 (1961)': [
    ['The Encyclopedia of Science Fiction', 'https://sf-encyclopedia.com/'],
    ['ISFDB (Internet Speculative Fiction Database)', 'https://www.isfdb.org/'],
    ['Ace Doubles (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Double'],
    ['Ace Books (Wikipedia)', 'https://en.wikipedia.org/wiki/Ace_Books'],
    ['Ace Double D-Series Guide', 'https://people.uncw.edu/smithms/D-series.html'],
  ],
};

function mediaLabel(source) {
  const s = (source || '').toLowerCase();
  if (isAceSource(source)) return 'book double';
  if (/\(\d{4}\)/.test(source || '')) return 'screen/book source';
  if (s.includes('module')) return 'adventure module';
  if (s.includes('author') || SOURCE_CONTEXT[s]) return 'author source';
  return 'reference source';
}

function sourceInsight(card, wiki, entitySummary, relatedCards) {
  const src = card.source || 'the source material';
  const srcNorm = norm(src);
  const related = (relatedCards || []).slice(0, 5).map((c) => c.name);
  const srcBase = srcNorm.replace(/\s*\(\d{4}\)\s*$/, '');
  const sourceContext = SOURCE_CONTEXT[srcNorm] || SOURCE_CONTEXT[srcBase];
  const dossier = SOURCE_DOSSIER[srcNorm] || SOURCE_DOSSIER[srcBase];
  const cardKind = card.type === 'location'
    ? 'location anchor'
    : (card.type === 'monster' ? 'threat profile' : 'character profile');
  const desc = (card.description || '').trim();
  const e = firstTwoSentences(entitySummary || '');
  const w = firstTwoSentences(wiki?.summary?.extract || '');

  const parts = [];
  if (sourceContext) parts.push(sourceContext);
  else parts.push(`This ${cardKind} is mapped from a ${mediaLabel(src)} used in the default DnDex lore set.`);

  if (dossier?.plot) parts.push(dossier.plot);
  if (dossier?.people) parts.push(dossier.people);
  if (related.length) parts.push(`In this game set, it connects with ${related.join(', ')} from the same source stream.`);
  if (dossier?.dnd) parts.push(dossier.dnd);
  if (e && overlapRatio(desc, e) < 0.55) parts.push(e);
  else if (w && overlapRatio(desc, w) < 0.55) parts.push(w);

  return parts.join(' ');
}

function publicationHint(card, wikiExtract) {
  const src = card.source || '';
  const yearMatch = src.match(/\((\d{4})\)/);
  const yearPart = yearMatch ? ` around ${yearMatch[1]}` : '';
  const sourceType = card.type === 'location' ? 'setting material' : (card.type === 'monster' ? 'creature lore' : 'character material');
  if (!src) return `This card is tied to ${sourceType} in the default game reference set.`;
  const brief = firstSentence(wikiExtract || '');
  if (brief) {
    return `Source context: ${src}${yearPart}. ${brief}`;
  }
  return `Source context: ${src}${yearPart}. This entry is linked to ${sourceType} used in the default game set.`;
}

function referenceFocus(card, entitySummary, wiki, relatedCards) {
  const desc = (card.description || '').trim();
  const e = firstTwoSentences(entitySummary || '');
  const w = firstTwoSentences(wiki?.summary?.extract || '');
  const src = card.source || '';
  const srcNorm = norm(src);
  const srcBase = srcNorm.replace(/\s*\(\d{4}\)\s*$/, '');
  const dossier = SOURCE_DOSSIER[srcNorm] || SOURCE_DOSSIER[srcBase];
  const year = (src.match(/\((\d{4})\)/) || [])[1];

  // Prefer source-specific prose that differs from card text.
  if (e && overlapRatio(desc, e) < 0.6) return e;
  if (w && overlapRatio(desc, w) < 0.6) return w;

  const rel = (relatedCards || []).slice(0, 3).map((c) => c.name);
  const relText = rel.length ? ` Linked cards: ${rel.join(', ')}.` : '';
  const pubText = year
    ? `Reference baseline: ${src} (${year}) with cross-links to source documentation and adaptation records.`
    : `Reference baseline: ${src || 'default source'} with cross-links to source documentation and adaptation records.`;
  const add = dossier?.dnd ? ` ${dossier.dnd}` : '';
  return `${pubText}${relText}${add}`;
}

const SOURCE_TRIVIA_BANK = {
  'alien (1979)': [
    'The production design style of worn industrial hardware became a template for later space-horror worldbuilding.',
    'The ship and crew setup popularized the blue-collar-in-space tone now common in sci-fi RPG campaigns.',
    'Its tension arc is built on shrinking safe zones, a pattern that maps directly to dungeon pressure design.',
  ],
  "blake's 7 (1978)": [
    'The show often stages missions as asymmetric raids, with intelligence and timing more important than raw firepower.',
    'Its small-cell team structure is close to stealth-heavy DnD parties running against a dominant regime faction.',
    'Moral ambiguity is central: outcomes can be successful and still costly, which fits consequence-driven campaign play.',
  ],
  'doctor who (1963)': [
    'Many episodes begin with an unexplained anomaly, then resolve through investigation rather than direct combat.',
    'The companion model mirrors tabletop pacing by rotating viewpoint characters through unfamiliar settings.',
    'It is a strong source for puzzle-first encounters where social decoding matters as much as stats.',
  ],
  'dragonlance': [
    'Dragonlance began as a direct DnD setting line, so many card archetypes already map cleanly to party roles.',
    'Its dramatic beats emphasize party bonds, betrayals, and prophecy pressure over isolated duel-style scenes.',
    'This source is useful for campaigns that want epic stakes without losing character-level relationships.',
  ],
  'famous robots': [
    'Robot lore often turns on command wording and edge cases, making language itself an encounter mechanic.',
    'Construct-centered stories are useful for ethical puzzles where the party must decide personhood and duty.',
    'These references support non-obvious NPC design: machine allies can be lawful, conflicted, or quietly rebellious.',
  ],
  'isaac asimov': [
    'Asimov stories are frequently structured like logic mysteries, which translates well into clue-chain adventures.',
    'His robot-law framing is a practical model for designing high-intelligence NPC constraints in game systems.',
    'Institutional-scale plotting in this source is useful for long campaigns with political and scientific factions.',
  ],
  'j.r.r. tolkien': [
    'Early DnD borrowed heavily from Tolkien-era fantasy vocabulary, then evolved those ideas into game-first systems.',
    'Tolkien travel arcs are useful templates for map-based campaigns where terrain and alliances matter every session.',
    'The long-history approach can enrich lore drops by tying current quests to older world events.',
  ],
  'j-r-r-tolkien': [
    'Early DnD borrowed heavily from Tolkien-era fantasy vocabulary, then evolved those ideas into game-first systems.',
    'Tolkien travel arcs are useful templates for map-based campaigns where terrain and alliances matter every session.',
    'The long-history approach can enrich lore drops by tying current quests to older world events.',
  ],
  'fritz leiber': [
    'Fafhrd and the Gray Mouser helped define the rogue duo pattern still common in city-crawl campaign design.',
    'Leiber urban stories are good references for faction-dense neighborhoods and rapid tactical reversals.',
    'This source supports encounter writing where improvisation outruns strict plan execution.',
  ],
  'michael moorcock': [
    'Moorcock anti-hero framing influenced many dark-fantasy campaign tones, especially cursed-power tradeoffs.',
    'Law-versus-Chaos themes in this source echo alignment-era worldbuilding ideas in tabletop fantasy.',
    'This material helps build campaigns where power has narrative cost and identity strain.',
  ],
};

const SOURCE_DND_LINKS = {
  'alien (1979)': 'Hidden DnD link: the film\'s hunt-through-tight-corridors structure maps well to horror dungeon design and initiative pressure.',
  "blake's 7 (1978)": 'Hidden DnD link: this source is a strong blueprint for rebellion campaigns where objectives matter more than body count.',
  'doctor who (1963)': 'Hidden DnD link: anomaly-driven episodes are useful models for one-shot hooks, planar oddities, and puzzle-led arcs.',
  'dragonlance': 'Hidden DnD link: Dragonlance is itself an official DnD setting lineage, so party role mapping is unusually direct.',
  'famous robots': 'Hidden DnD link: robot-law and protocol conflicts are practical templates for construct NPC behavior trees.',
  'isaac asimov': 'Hidden DnD link: constrained-intelligence design from robot fiction helps balance powerful helper NPCs.',
  'j.r.r. tolkien': 'Hidden DnD link: race tropes, quest patterns, and map-led fellowship travel all fed early tabletop fantasy play.',
  'j-r-r-tolkien': 'Hidden DnD link: race tropes, quest patterns, and map-led fellowship travel all fed early tabletop fantasy play.',
  'fritz leiber': 'Hidden DnD link: Leiber\'s city sword-and-sorcery texture aligns with thief-guild campaigns and urban faction play.',
  'michael moorcock': 'Hidden DnD link: Law-versus-Chaos framing influenced many tabletop cosmology and alignment discussions.',
  'honour among thieves': 'Hidden DnD link: this source is literally a DnD story scaffold, useful for heist-plus-party-banters pacing.',
  'ace double': 'Hidden DnD link: Ace pulp pairings are excellent seeds for two-thread adventures that cross over mid-campaign.',
};

function stablePick(list, seedText) {
  if (!list || !list.length) return '';
  let h = 0;
  const s = seedText || '';
  for (let i = 0; i < s.length; i += 1) h = ((h << 5) - h + s.charCodeAt(i)) | 0;
  const idx = Math.abs(h) % list.length;
  return list[idx];
}

function sourceLineage(card, relatedCards) {
  const src = card.source || 'default source';
  const srcNorm = norm(src);
  const srcBase = srcNorm.replace(/\s*\(\d{4}\)\s*$/, '');
  const year = (src.match(/\((\d{4})\)/) || [])[1];
  if (isAceSource(src)) {
    return `Source lineage: ${src} comes from the Ace Double format, where two short novels were published back-to-back in a single volume. This card draws from that paired-story pulp tradition.`;
  }
  if (srcNorm.includes('module')) {
    return `Source lineage: ${src} is from tabletop module-era material, so this card inherits encounter-first design assumptions rather than purely cinematic pacing.`;
  }
  if (year) {
    const rel = (relatedCards || []).slice(0, 3).map((c) => c.name);
    const relText = rel.length ? ` Nearby cards from the same source include ${rel.join(', ')}.` : '';
    return `Source lineage: ${src} (${year}) is part of the external canon feeding this DnDex set.${relText}`;
  }
  return `Source lineage: ${src} is used as a recurring inspiration stream for default DnDex entities and naming motifs.`;
}

function sourceTrivia(card, wikiExtract, relatedCards) {
  const srcNorm = norm(card.source || '');
  const srcBase = srcNorm.replace(/\s*\(\d{4}\)\s*$/, '');
  const key = isAceSource(card.source) ? 'ace double' : (srcNorm || srcBase);
  const trivia = SOURCE_TRIVIA_BANK[srcNorm] || SOURCE_TRIVIA_BANK[srcBase];
  if (trivia?.length) return stablePick(trivia, `${card.id}:${card.name}:${card.source}`);

  const rel = (relatedCards || []).slice(0, 2).map((c) => c.name);
  if (rel.length) {
    return `Trivia: this source has multiple linked DnDex entries; ${card.name} is one node in a shared reference cluster with ${rel.join(' and ')}.`;
  }
  const w = firstSentence(wikiExtract || '');
  if (w) return `Trivia: ${w}`;
  if (card.type === 'monster') return 'Trivia: monster cards in this source stream are tuned to be narrative pressure tools, not only damage outputs.';
  if (card.type === 'location') return 'Trivia: location cards from this source are intended as campaign anchors that can reshape encounter style across sessions.';
  return `Trivia: ${card.name} is used here as a gameplay-facing interpretation of its source lineage, with references linked below for deep reading.`;
}

function dndConnectionNote(card) {
  const src = card.source || '';
  const srcNorm = norm(src);
  const srcBase = srcNorm.replace(/\s*\(\d{4}\)\s*$/, '');
  if (isAceSource(src)) return SOURCE_DND_LINKS['ace double'];
  return SOURCE_DND_LINKS[srcNorm] || SOURCE_DND_LINKS[srcBase] || 'Hidden DnD link: this entry can be read as a class-archetype or encounter-archetype seed when building custom campaigns.';
}

function sourceHistory(card, wikiExtract, relatedCards) {
  const lineage = sourceLineage(card, relatedCards);
  const trivia = sourceTrivia(card, wikiExtract, relatedCards);
  const dndLink = dndConnectionNote(card);
  return `${lineage} ${trivia} ${dndLink}`;
}

function renderRelatedCards(card, allCards) {
  const linksWrap = byId('links');
  const related = allCards.filter((c) => c.id !== card.id && norm(c.source) === norm(card.source)).slice(0, 8);
  if (!related.length) return;

  const hdr = document.createElement('div');
  hdr.className = 'small';
  hdr.style.width = '100%';
  hdr.textContent = 'Related Cards';
  linksWrap.appendChild(hdr);

  for (const r of related) {
    linksWrap.appendChild(makeLink(`${r.name} (${r.type})`, `./${r.lore_page ? r.lore_page.split('/').pop() : ''}`));
  }
}

async function render(card, allCards) {
  renderBase(card);
  renderLoreNav(card, allCards);
  const linksWrap = byId('links');
  linksWrap.innerHTML = '';

  // Always include local deep links first.
  const sourceCardHref = loreRelativeEntityPath(card.source_entity_page);
  if (sourceCardHref) linksWrap.appendChild(makeLink('Source Card', sourceCardHref));
  linksWrap.appendChild(makeLink('Open in DnDex', `../index.html?card=${q(card.name)}&search=${q(card.source || '')}`));

  const entity = await loadEntityData(card);
  const wiki = await loadWikiBest(card);
  const relatedCards = allCards.filter((c) => c.id !== card.id && norm(c.source) === norm(card.source));

  const img = byId('wikiImg');
  let imageSourceHref = null;
  if (entity?.image) {
    img.src = entity.image;
    img.alt = `${card.source || card.name} reference image`;
    img.style.display = 'block';
    imageSourceHref = entity?.links?.[0]?.href || sourceCardHref;
  }
  if (!isAceSource(card.source) && wiki?.summary?.thumbnail?.source) {
    img.src = wiki.summary.thumbnail.source;
    img.alt = `${wiki.title || card.name} reference image`;
    img.style.display = 'block';
    imageSourceHref = wiki?.url || imageSourceHref;
  }
  if (img.style.display === 'block' && imageSourceHref) {
    ensureImageSourceLink(img, imageSourceHref);
  }
  if (isAceSource(card.source)) renderImageGallery(entity, 'Ace Cover Gallery', 'ace-cover-gallery');
  else renderImageGallery(entity, 'Reference Gallery', 'ref-image-gallery');

  const added = new Set();
  const addUnique = (label, href) => {
    if (!href || added.has(href)) return;
    added.add(href);
    linksWrap.appendChild(makeLink(label, href));
  };

  if (wiki?.url) addUnique('Wikipedia', wiki.url);

  const supplemental = isAceSource(card.source) ? [] : await buildSupplementalLinks(wiki);
  for (const l of supplemental) addUnique(l.label, l.href);
  const srcNorm = norm(card.source || '');
  const srcBase = srcNorm.replace(/\s*\(\d{4}\)\s*$/, '');
  const sciFiRefs = SCI_FI_REFERENCE_LINKS[srcNorm] || SCI_FI_REFERENCE_LINKS[srcBase] || [];
  for (const [label, href] of sciFiRefs) addUnique(label, href);

  if (entity?.links?.length) {
    for (const l of entity.links) {
      if (isLikelySearchLink(l.href)) continue;
      if (await isDisambiguationWikiUrl(l.href)) continue;
      addUnique(l.label || 'Reference', l.href);
    }
  }

  if (!added.size) {
    const fallback = `https://en.wikipedia.org/wiki/${q((card.source || card.name).replace(/\s+/g, '_'))}`;
    addUnique('Wikipedia', fallback);
  }

  const storyNotes = sourceInsight(card, wiki, entity?.summary || '', relatedCards);
  const sourceContext = referenceFocus(card, entity?.summary || '', wiki, relatedCards);
  const playNote = gameplayFocus(card);
  const history = sourceHistory(card, wiki?.summary?.extract || '', relatedCards);
  byId('summary').innerHTML = [
    `<strong>Story Notes:</strong> ${storyNotes}`,
    `<strong>Reference Focus:</strong> ${sourceContext}`,
    `<strong>Gameplay Note:</strong> ${playNote}`,
    `<strong>Source Lineage and Trivia:</strong> ${history}`,
  ].filter(Boolean).join('<br><br>');

  renderRelatedCards(card, allCards);
}

(async function init() {
  const allCards = await loadAllCards();
  const card = allCards.find((c) => c.id === inlineCard.id) || inlineCard;
  await render(card, allCards);
})();
