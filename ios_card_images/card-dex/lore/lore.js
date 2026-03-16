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
    '<button id="loreDiceBtn" class="btn" type="button">Dice</button>',
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

function renderAceCoverGallery(entity) {
  if (!entity?.images || entity.images.length < 2) return;
  const existing = document.querySelector('.ace-cover-gallery');
  if (existing) existing.remove();

  const images = entity.images.slice(0, 4);
  const panel = document.createElement('div');
  panel.className = 'ace-cover-gallery';
  panel.innerHTML = [
    '<div class="small" style="margin-top:10px">Ace Cover Gallery</div>',
    `<div class="ace-cover-grid">${images.map((im, i) => (
      `<a href="${im.href || im.src}" target="_blank" rel="noopener noreferrer">` +
      `<img src="${im.src}" alt="Ace cover ${i + 1}" loading="lazy" />` +
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
  const m = t.match(/.+?[.!?](?:\s|$)/);
  return (m ? m[0] : t).trim();
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
  const parts = t.match(/[^.!?]+[.!?]/g) || [t];
  return parts.slice(0, 2).map((s) => s.trim()).join(' ');
}

function sourceInsight(card, wiki, entitySummary, relatedCards) {
  const w = firstTwoSentences(wiki?.summary?.extract || '');
  const e = firstTwoSentences(entitySummary || '');
  const desc = (card.description || '').trim();
  const src = card.source || 'the source material';
  const names = (relatedCards || []).slice(0, 4).map((c) => c.name);

  if (w && overlapRatio(desc, w) < 0.65) return w;
  if (e && overlapRatio(desc, e) < 0.65) return e;
  if (names.length) {
    return `Within ${src}, this card sits alongside ${names.join(', ')}. Use those linked cards to explore adjacent character and place threads from the same story world.`;
  }
  return `This entry is anchored to ${src}; use the references below for deeper plot, author, and character context beyond the in-game card summary.`;
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

  // Prefer source-specific prose that differs from card text.
  if (e && overlapRatio(desc, e) < 0.6) return e;
  if (w && overlapRatio(desc, w) < 0.6) return w;

  const rel = (relatedCards || []).slice(0, 3).map((c) => c.name);
  const relText = rel.length ? ` Related cards from this same source include ${rel.join(', ')}.` : '';
  return `${publicationHint(card, wiki?.summary?.extract || '')}${relText}`;
}

function sourceHistory(card, entitySummary, wikiExtract) {
  const e = (entitySummary || '').trim();
  const w = (wikiExtract || '').trim();
  if (e && w && overlapRatio(e, w) < 0.6) {
    return `${e} ${firstSentence(w)}`;
  }
  if (w) return firstSentence(w);
  if (e) return firstSentence(e);
  return `${card.name} has stable source references linked below for deeper reading.`;
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
  if (isAceSource(card.source)) {
    renderAceCoverGallery(entity);
  }

  const added = new Set();
  const addUnique = (label, href) => {
    if (!href || added.has(href)) return;
    added.add(href);
    linksWrap.appendChild(makeLink(label, href));
  };

  if (wiki?.url) addUnique('Wikipedia', wiki.url);

  const supplemental = isAceSource(card.source) ? [] : await buildSupplementalLinks(wiki);
  for (const l of supplemental) addUnique(l.label, l.href);

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
  const strongRefs = added.size >= 3 && ((wiki?.summary?.extract || '').length > 140 || (entity?.summary || '').length > 140);
  const history = strongRefs ? sourceHistory(card, entity?.summary || '', wiki?.summary?.extract || '') : '';
  byId('summary').innerHTML = [
    `<strong>Story Notes:</strong> ${storyNotes}`,
    `<strong>Reference Focus:</strong> ${sourceContext}`,
    `<strong>Gameplay Note:</strong> ${playNote}`,
    history ? `<strong>Source History:</strong> ${history}` : '',
  ].filter(Boolean).join('<br><br>');

  renderRelatedCards(card, allCards);
}

(async function init() {
  const allCards = await loadAllCards();
  const card = allCards.find((c) => c.id === inlineCard.id) || inlineCard;
  await render(card, allCards);
})();
