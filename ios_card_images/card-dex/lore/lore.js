const card = window.CARD;

function byId(id) { return document.getElementById(id); }

function q(s) { return encodeURIComponent(s); }

function sourceKind(src) {
  const s = (src || '').toLowerCase();
  if (s.includes('module')) return 'book';
  if (s.includes('tolkien') || s.includes('moorcock') || s.includes('le guin') || s.includes('pratchett') || s.includes('howard') || s.includes('asimov') || s.includes('burroughs')) return 'book';
  if (s.includes('film') || s.includes('movie') || s.includes('198') || s.includes('197') || s.includes('king kong') || s.includes('star wars') || s.includes('alien')) return 'movie';
  if (s.includes('stranger things') || s.includes('doctor who') || s.includes('community') || s.includes('futurama') || s.includes('he-man') || s.includes('thundercats') || s.includes('dogtanian')) return 'tv';
  return 'mixed';
}

function outboundLinks(c) {
  const query = `${c.name} ${c.source || ''}`.trim();
  const squery = `${c.source || c.name}`.trim();
  const kind = sourceKind(c.source);
  const links = [
    { label: 'Wikipedia', href: `https://en.wikipedia.org/wiki/Special:Search?search=${q(query)}` },
    { label: 'YouTube', href: `https://www.youtube.com/results?search_query=${q(query + ' trailer clip')}` },
    { label: 'Amazon', href: `https://www.amazon.com/s?k=${q(squery)}` },
    { label: 'AbeBooks', href: `https://www.abebooks.com/servlet/SearchResults?kn=${q(squery)}` },
    { label: 'World of Books', href: `https://www.worldofbooks.com/en-gb/search?q=${q(squery)}` },
  ];
  if (kind === 'movie' || kind === 'tv' || kind === 'mixed') {
    links.push({ label: 'IMDb', href: `https://www.imdb.com/find/?q=${q(query)}` });
  }
  return links;
}

async function findWikiTitle(query) {
  const url = `https://en.wikipedia.org/w/api.php?action=opensearch&search=${q(query)}&limit=1&namespace=0&format=json&origin=*`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  if (Array.isArray(data) && Array.isArray(data[1]) && data[1].length > 0) {
    return data[1][0];
  }
  return null;
}

async function fetchWikiSummary(title) {
  const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${q(title)}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  return await res.json();
}

async function loadWiki(c) {
  const queries = [
    `${c.name} ${c.source || ''}`.trim(),
    c.name,
    c.source || '',
  ].filter(Boolean);
  for (const query of queries) {
    try {
      const title = await findWikiTitle(query);
      if (!title) continue;
      const sum = await fetchWikiSummary(title);
      if (!sum || !sum.extract) continue;
      return { title, summary: sum };
    } catch (_) {}
  }
  return null;
}

function renderStatic(c) {
  byId('title').textContent = c.name;
  byId('meta').textContent = `${(c.type || '').toUpperCase()} - ${c.source || 'Reference'}`;
  byId('cardImg').src = `../../${c.image}`;
  byId('cardImg').alt = c.name;
  byId('summary').textContent = c.description || '';

  const links = outboundLinks(c);
  if (c.source_entity_page) {
    links.unshift({ label: 'Source Card', href: `../${c.source_entity_page}` });
  }
  const linksWrap = byId('links');
  for (const l of links) {
    const a = document.createElement('a');
    a.href = l.href;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.textContent = l.label;
    linksWrap.appendChild(a);
  }
}

async function renderWiki(c) {
  const wiki = await loadWiki(c);
  if (!wiki) return;

  byId('summary').textContent = wiki.summary.extract;
  if (wiki.summary.thumbnail && wiki.summary.thumbnail.source) {
    const img = byId('wikiImg');
    img.src = wiki.summary.thumbnail.source;
    img.alt = `${wiki.title} reference image`;
    img.style.display = 'block';
  }
  if (wiki.summary.content_urls && wiki.summary.content_urls.desktop && wiki.summary.content_urls.desktop.page) {
    const a = document.createElement('a');
    a.href = wiki.summary.content_urls.desktop.page;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.textContent = 'Wikipedia Article';
    byId('links').prepend(a);
  }
}

renderStatic(card);
renderWiki(card);
