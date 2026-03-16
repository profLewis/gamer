const inlineCard = window.CARD;

function byId(id) { return document.getElementById(id); }
function q(s) { return encodeURIComponent(s); }
function norm(s) { return (s || '').trim().toLowerCase(); }

const WIKI_OVERRIDES = {
  "player-066": "https://en.wikipedia.org/wiki/List_of_Blake%27s_7_characters#Kerr_Avon",
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

async function searchWiki(query) {
  const res = await fetch(`https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${q(query)}&srlimit=6&format=json&origin=*`);
  if (!res.ok) return [];
  const data = await res.json();
  return data?.query?.search || [];
}

async function loadWikiBest(card) {
  if (WIKI_OVERRIDES[card.id]) {
    return { url: WIKI_OVERRIDES[card.id], summary: null, title: null };
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
    const entityUrl = new URL(`../${card.source_entity_page}`, window.location.href);
    const res = await fetch(entityUrl.href);
    if (!res.ok) return null;
    const html = await res.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');

    const img = doc.querySelector('.wiki-img');
    const summaries = Array.from(doc.querySelectorAll('.summary')).map((x) => (x.textContent || '').trim()).filter(Boolean);
    const links = Array.from(doc.querySelectorAll('.links a[href]')).map((a) => ({
      label: (a.textContent || '').trim() || 'Reference',
      href: new URL(a.getAttribute('href'), entityUrl.href).href,
    })).filter((l) => Boolean(l.href));

    return {
      image: img ? new URL(img.getAttribute('src'), entityUrl.href).href : null,
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

function renderBase(card) {
  byId('title').textContent = card.name;
  byId('meta').textContent = `${(card.type || '').toUpperCase()} - ${card.source || 'Reference'}`;
  byId('cardImg').src = `../../${card.image}`;
  byId('cardImg').alt = card.name;
  byId('summary').textContent = (card.description || '').trim() || `Reference notes for ${card.name}.`;
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
  const linksWrap = byId('links');
  linksWrap.innerHTML = '';

  // Always include local deep links first.
  if (card.source_entity_page) linksWrap.appendChild(makeLink('Source Card', `../${card.source_entity_page}`));
  linksWrap.appendChild(makeLink('Open in DnDex', `../index.html?card=${q(card.name)}&search=${q(card.source || '')}`));

  const entity = await loadEntityData(card);
  const wiki = await loadWikiBest(card);

  const img = byId('wikiImg');
  if (entity?.image) {
    img.src = entity.image;
    img.alt = `${card.source || card.name} reference image`;
    img.style.display = 'block';
  }
  if (wiki?.summary?.thumbnail?.source) {
    img.src = wiki.summary.thumbnail.source;
    img.alt = `${wiki.title || card.name} reference image`;
    img.style.display = 'block';
  }

  if (entity?.summary && (card.description || '').trim()) {
    byId('summary').textContent = `${card.description.trim()} ${entity.summary}`;
  } else if (entity?.summary) {
    byId('summary').textContent = entity.summary;
  }

  const added = new Set();
  const addUnique = (label, href) => {
    if (!href || added.has(href)) return;
    added.add(href);
    linksWrap.appendChild(makeLink(label, href));
  };

  if (wiki?.url) addUnique('Wikipedia', wiki.url);

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

  renderRelatedCards(card, allCards);
}

(async function init() {
  const allCards = await loadAllCards();
  const card = allCards.find((c) => c.id === inlineCard.id) || inlineCard;
  await render(card, allCards);
})();
