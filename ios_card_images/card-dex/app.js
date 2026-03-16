const state = {
  cards: [],
  filtered: [],
  selectedId: null,
  musicOn: false,
  pendingSource: null,
  pendingCard: null,
  lastRandomAt: 0,
};

const els = {
  category: document.getElementById('categorySelect'),
  search: document.getElementById('searchInput'),
  sort: document.getElementById('sortSelect'),
  panelWidthSlider: document.getElementById('panelWidthSlider'),
  count: document.getElementById('countLabel'),
  layout: document.querySelector('.layout'),
  panelResizer: document.getElementById('panelResizer'),
  grid: document.getElementById('cardGrid'),
  title: document.getElementById('detailTitle'),
  meta: document.getElementById('detailMeta'),
  prevCardBtn: document.getElementById('prevCardBtn'),
  randomCardBtn: document.getElementById('randomCardBtn'),
  nextCardBtn: document.getElementById('nextCardBtn'),
  cardPosLabel: document.getElementById('cardPosLabel'),
  image: document.getElementById('detailImage'),
  sourceBtn: document.getElementById('sourceBtn'),
  loreBtn: document.getElementById('loreBtn'),
  shareBtn: document.getElementById('shareBtn'),
  downloadBtn: document.getElementById('downloadBtn'),
  stats: document.getElementById('detailStats'),
  statHelp: document.getElementById('statHelp'),
  desc: document.getElementById('detailDesc'),
  musicToggle: document.getElementById('musicToggle'),
  musicMode: document.getElementById('musicMode'),
  volumeWrap: document.getElementById('volumeWrap'),
  volume: document.getElementById('volumeSlider'),
  bgm: document.getElementById('bgm'),
};

const swipeState = {
  startX: null,
};

const STAT_INFO = {
  Power: { map: 'STR', low: 'Low combat force.', mid: 'Solid frontline strength.', high: 'Exceptional physical dominance.' },
  Cunning: { map: 'DEX/INT', low: 'Direct approach, little trickery.', mid: 'Good tactics and problem solving.', high: 'Master-level tactics and deception.' },
  Magic: { map: 'INT/WIS/CHA (spell power)', low: 'Little or no arcane influence.', mid: 'Reliable magical capability.', high: 'Legendary magical potential.' },
  Fame: { map: 'Reputation', low: 'Niche recognition.', mid: 'Well known in genre circles.', high: 'Icon-level recognition.' },
  Charm: { map: 'CHA', low: 'Blunt or difficult social style.', mid: 'Persuasive and likable.', high: 'Outstanding charisma and influence.' },
  Danger: { map: 'Dungeon threat', low: 'Safer than average location.', mid: 'Significant risk profile.', high: 'Extremely lethal environment.' },
  Puzzle: { map: 'Complexity', low: 'Mostly straightforward encounters.', mid: 'Meaningful puzzle/trap challenge.', high: 'Dense puzzle-heavy design.' },
  Dread: { map: 'Atmosphere', low: 'Light tension.', mid: 'Strong ominous tone.', high: 'Severe fear/doom atmosphere.' },
  HP: { map: 'Hit Points', low: 'Fragile enemy.', mid: 'Moderate durability.', high: 'Tank-level endurance.' },
  AC: { map: 'Armour Class', low: 'Easy to hit.', mid: 'Average defense.', high: 'Hard target to land attacks on.' },
  ATK: { map: 'Attack Bonus', low: 'Low hit chance.', mid: 'Reliable strike chance.', high: 'Very accurate attacker.' },
  DMG: { map: 'Damage Dice', low: 'Light damage output.', mid: 'Steady threat.', high: 'High burst potential.' },
  CR: { map: 'Challenge Rating', low: 'Entry-level threat.', mid: 'Skilled-party challenge.', high: 'Boss-tier challenge.' },
  XP: { map: 'Reward Value', low: 'Small reward.', mid: 'Meaningful progression reward.', high: 'Major progression reward.' },
};

const SOURCE_CONTEXT = {
  'terry pratchett': 'Discworld entries are useful for urban satire campaigns where guild politics, civic institutions, and oddball NPC logic matter as much as combat.',
  'j.r.r. tolkien': 'Tolkien-linked cards fit long-journey campaigns with faction pressure, artifact stakes, and leadership decisions under moral strain.',
  'j-r-r-tolkien': 'Tolkien-linked cards fit long-journey campaigns with faction pressure, artifact stakes, and leadership decisions under moral strain.',
  'dragonlance': 'Dragonlance-linked cards support party-bond storytelling: old allies, prophecy pressure, and war-scale escalation.',
  'ursula k. le guin': 'Earthsea-linked cards suit campaigns where naming, balance, and consequence are central mechanics rather than background lore.',
  'fritz leiber': 'Leiber-linked cards are strong for city-crawl play: thieves, rival crews, and fast tactical pivots in tight environments.',
  'ace double d-096 (1955)': 'This Ace Double stream works well for frontier-survival scenarios and command decisions after a crash-landing or regime collapse.',
};

function scoreBand(v) {
  const n = Number(v);
  if (Number.isNaN(n)) return 'Context specific rating.';
  if (n <= 3) return 'This is a low value.';
  if (n <= 7) return 'This is a medium value.';
  return 'This is a high value.';
}

function statHelpText(label, value) {
  const info = STAT_INFO[label];
  const band = scoreBand(value);
  if (!info) return `${label}: ${value}. ${band}`;
  const n = Number(value);
  let detail = info.mid;
  if (!Number.isNaN(n)) {
    detail = n <= 3 ? info.low : (n <= 7 ? info.mid : info.high);
  }
  return `${label}: ${value}. Maps to ${info.map}. ${band} ${detail}`;
}

function applyPanelSplit(pctRaw) {
  const pct = Math.max(35, Math.min(75, Number(pctRaw) || 62));
  const cards = 100 - pct;
  document.documentElement.style.setProperty('--detail-fr', `${pct}fr`);
  document.documentElement.style.setProperty('--cards-fr', `${cards}fr`);
  els.panelWidthSlider.value = String(pct);
  try {
    localStorage.setItem('dndex_panel_split', String(pct));
  } catch (_) {}
}

const TRACKS = {
  exploration: '../../music/music_exploration.wav',
  combat: '../../music/music_combat.wav',
  menu: '../../music/music_menu.wav',
};

function humanType(t) {
  if (t === 'player') return 'Player';
  if (t === 'monster') return 'Monster';
  if (t === 'location') return 'Location';
  return t;
}

function statPairs(card) {
  return Object.entries(card.stats || {}).filter(([, v]) => typeof v === 'number');
}

function topStats(card, n = 2) {
  const pairs = statPairs(card).sort((a, b) => b[1] - a[1]).slice(0, n);
  return pairs.map(([k, v]) => `${k} ${v}`);
}

function dndContext(card) {
  const src = (card.source || '').trim();
  const srcKey = src.toLowerCase();
  const sourceNote = SOURCE_CONTEXT[srcKey] || 'This source can be used as campaign inspiration rather than just name flavor.';
  const related = state.cards.filter((c) => c.id !== card.id && (c.source || '').trim().toLowerCase() === srcKey).slice(0, 4);
  const relatedNames = related.map((c) => c.name);
  const peaks = topStats(card, 2);
  let roleLine = '';

  if (card.type === 'player') {
    roleLine = peaks.length
      ? `${card.name} plays best as a specialist hero leaning on ${peaks.join(' and ')}.`
      : `${card.name} is best treated as a specialist hero with situational strengths.`;
  } else if (card.type === 'location') {
    roleLine = peaks.length
      ? `${card.name} works as a scenario anchor with emphasis on ${peaks.join(' and ')}.`
      : `${card.name} works as a scenario anchor for exploration, traps, or social complications.`;
  } else {
    roleLine = peaks.length
      ? `${card.name} is most threatening when encounters stress ${peaks.join(' and ')}.`
      : `${card.name} should be staged with layered pressure rather than as a simple damage race.`;
  }

  const relatedLine = relatedNames.length
    ? `From the same source stream: ${relatedNames.join(', ')}.`
    : 'No other cards currently share this exact source tag.';

  return `DnD Context: ${roleLine} ${sourceNote} ${relatedLine}`;
}

async function loadCards() {
  let data = null;
  try {
    const res = await fetch('../cards.json');
    if (res.ok) {
      data = await res.json();
    }
  } catch (_) {}
  if (!data && window.CARD_DATA) {
    data = window.CARD_DATA;
  }
  if (!data) {
    els.count.textContent = 'Failed to load cards data';
    return;
  }
  state.cards = [...data.players, ...data.monsters, ...data.locations];
  try {
    const params = new URLSearchParams(window.location.search);
    const source = (params.get('source') || '').trim().toLowerCase();
    if (source) state.pendingSource = source;
    const card = (params.get('card') || '').trim().toLowerCase();
    if (card) state.pendingCard = card;
    const search = (params.get('search') || '').trim();
    if (search) {
      els.search.value = search;
    }
  } catch (_) {}
  applyFilters();
}

function applyFilters() {
  const cat = els.category.value;
  const q = els.search.value.trim().toLowerCase();
  const sortMode = els.sort.value;

  let arr = state.cards.filter((c) => (cat === 'all' ? true : c.type === cat));

  if (q) {
    arr = arr.filter((c) => {
      const hay = `${c.name} ${c.source || ''} ${c.description || ''}`.toLowerCase();
      return hay.includes(q);
    });
  }

  arr.sort((a, b) => {
    if (sortMode === 'type') {
      return `${a.type}:${a.name}`.localeCompare(`${b.type}:${b.name}`);
    }
    return a.name.localeCompare(b.name);
  });

  state.filtered = arr;
  els.count.textContent = `${arr.length} shown`;

  if (state.pendingSource) {
    const bySource = arr.find((c) => (c.source || '').trim().toLowerCase() === state.pendingSource);
    if (bySource) {
      state.selectedId = bySource.id;
      state.pendingSource = null;
    }
  }
  if (state.pendingCard) {
    const byCard =
      arr.find((c) => c.name.trim().toLowerCase() === state.pendingCard) ||
      arr.find((c) => c.name.trim().toLowerCase().includes(state.pendingCard));
    if (byCard) {
      state.selectedId = byCard.id;
      state.pendingCard = null;
    }
  }

  if (!arr.find((c) => c.id === state.selectedId)) {
    state.selectedId = arr[0]?.id || null;
  }

  renderGrid();
  renderDetail();
  syncMusicTrack();
}

function renderGrid() {
  els.grid.innerHTML = '';
  let activeEl = null;
  for (const card of state.filtered) {
    const item = document.createElement('button');
    item.className = `card-item${card.id === state.selectedId ? ' active' : ''}`;
    item.dataset.cardId = card.id;
    item.innerHTML = `
      <img class="thumb" src="../${card.image}" alt="${card.name}" loading="lazy" />
      <div class="card-name">${card.name}</div>
      <div class="card-type">${humanType(card.type)}</div>
    `;
    item.addEventListener('click', () => {
      state.selectedId = card.id;
      renderGrid();
      renderDetail();
    });
    els.grid.appendChild(item);
    if (card.id === state.selectedId) {
      activeEl = item;
    }
  }
  if (activeEl) {
    activeEl.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }
}

function renderDetail() {
  const idx = state.filtered.findIndex((c) => c.id === state.selectedId);
  const card = idx >= 0 ? state.filtered[idx] : null;
  if (!card) {
    els.title.textContent = 'No cards in this filter';
    els.meta.textContent = '';
    els.image.removeAttribute('src');
    els.cardPosLabel.textContent = '0/0';
    els.sourceBtn.href = '#';
    els.sourceBtn.style.display = 'none';
    els.loreBtn.href = '#';
    els.loreBtn.style.display = 'none';
    els.downloadBtn.href = '#';
    els.downloadBtn.download = '';
    els.shareBtn.disabled = true;
    els.stats.innerHTML = '';
    els.statHelp.textContent = 'Tap a stat to see what it means.';
    els.desc.textContent = '';
    return;
  }

  els.title.textContent = card.name;
  const typeLabel = humanType(card.type);
  const sourceLabel = (card.source || '').trim();
  const typePart = `<button type="button" class="meta-chip" data-meta-filter="${card.type}">${typeLabel}</button>`;
  const sourcePart = sourceLabel
    ? (card.source_entity_page
      ? `<a class="meta-link" href="../${card.source_entity_page}" target="_blank" rel="noopener noreferrer">${sourceLabel}</a>`
      : `<span class="meta-text">${sourceLabel}</span>`)
    : '';
  els.meta.innerHTML = sourcePart ? `${typePart} <span class="meta-sep">-</span> ${sourcePart}` : typePart;
  const metaFilterBtn = els.meta.querySelector('[data-meta-filter]');
  if (metaFilterBtn) {
    metaFilterBtn.addEventListener('click', () => {
      els.category.value = card.type;
      applyFilters();
    });
  }
  els.image.removeAttribute('src');
  els.image.src = `../${card.image}`;
  els.image.alt = card.name;
  els.cardPosLabel.textContent = `${idx + 1}/${state.filtered.length}`;
  if (card.source_entity_page) {
    els.sourceBtn.href = `../${card.source_entity_page}`;
    els.sourceBtn.style.display = 'inline-flex';
  } else {
    els.sourceBtn.href = '#';
    els.sourceBtn.style.display = 'none';
  }
  if (card.lore_page) {
    els.loreBtn.href = `../${card.lore_page}`;
    els.loreBtn.style.display = 'inline-flex';
  } else {
    els.loreBtn.href = '#';
    els.loreBtn.style.display = 'none';
  }
  els.downloadBtn.href = `../${card.image}`;
  els.downloadBtn.download = `${card.name.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}.png`;
  els.shareBtn.disabled = false;

  els.stats.innerHTML = '';
  for (const [k, v] of Object.entries(card.stats || {})) {
    const p = document.createElement('button');
    p.type = 'button';
    p.className = 'stat-pill';
    p.textContent = `${k}: ${v}`;
    p.addEventListener('click', () => {
      for (const el of els.stats.querySelectorAll('.stat-pill')) {
        el.classList.remove('active');
      }
      p.classList.add('active');
      els.statHelp.textContent = statHelpText(k, v);
    });
    els.stats.appendChild(p);
  }
  els.statHelp.textContent = 'Tap a stat to see what it means.';

  els.desc.textContent = dndContext(card);
}

function selectByOffset(offset) {
  if (!state.filtered.length) return;
  const current = state.filtered.findIndex((c) => c.id === state.selectedId);
  const base = current >= 0 ? current : 0;
  const next = (base + offset + state.filtered.length) % state.filtered.length;
  state.selectedId = state.filtered[next].id;
  renderGrid();
  renderDetail();
}

function visibleGridColumns() {
  const first = els.grid.querySelector('.card-item');
  if (!first) return 1;
  const itemWidth = first.getBoundingClientRect().width || 1;
  const styles = window.getComputedStyle(els.grid);
  const gap = parseFloat(styles.columnGap || styles.gap || '0') || 0;
  const usable = els.grid.clientWidth || itemWidth;
  const cols = Math.floor((usable + gap) / (itemWidth + gap));
  return Math.max(1, cols || 1);
}

function selectByGridStep(step) {
  if (!state.filtered.length) return;
  const current = state.filtered.findIndex((c) => c.id === state.selectedId);
  const base = current >= 0 ? current : 0;
  const next = (base + step + state.filtered.length) % state.filtered.length;
  state.selectedId = state.filtered[next].id;
  renderGrid();
  renderDetail();
}

function selectRandomCard() {
  if (!state.filtered.length) return;
  const now = Date.now();
  if (now - state.lastRandomAt < 120) return;
  state.lastRandomAt = now;
  if (state.filtered.length === 1) {
    state.selectedId = state.filtered[0].id;
    renderGrid();
    renderDetail();
    return;
  }
  const current = state.filtered.findIndex((c) => c.id === state.selectedId);
  let next = current;
  while (next === current) {
    next = Math.floor(Math.random() * state.filtered.length);
  }
  state.selectedId = state.filtered[next].id;
  renderGrid();
  renderDetail();
}

function openDeepInfo() {
  const card = state.filtered.find((c) => c.id === state.selectedId);
  if (!card) return;
  if (card.lore_page) {
    window.location.href = `../${card.lore_page}`;
    return;
  }
  if (card.source_entity_page) {
    window.location.href = `../${card.source_entity_page}`;
  }
}

async function shareCurrentCard() {
  const card = state.filtered.find((c) => c.id === state.selectedId);
  if (!card) return;
  const imageUrl = `../${card.image}`;

  try {
    if (navigator.share) {
      if (navigator.canShare && window.File) {
        const resp = await fetch(imageUrl);
        if (resp.ok) {
          const blob = await resp.blob();
          const fileName = `${card.name.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}.png`;
          const file = new File([blob], fileName, { type: blob.type || 'image/png' });
          if (navigator.canShare({ files: [file] })) {
            await navigator.share({
              title: card.name,
              text: `${card.name} (${humanType(card.type)})`,
              files: [file],
            });
            return;
          }
        }
      }
      await navigator.share({
        title: card.name,
        text: `${card.name} (${humanType(card.type)})`,
        url: new URL(imageUrl, window.location.href).href,
      });
      return;
    }
  } catch (_) {}

  // Fallback: trigger download
  els.downloadBtn.click();
}

function targetTrack() {
  const mode = els.musicMode.value;
  if (mode !== 'auto') return mode;

  const cat = els.category.value;
  if (cat === 'monster') return 'combat';
  if (cat === 'player' || cat === 'location') return 'exploration';

  const selected = state.filtered.find((c) => c.id === state.selectedId);
  return selected?.type === 'monster' ? 'combat' : 'exploration';
}

function syncMusicTrack() {
  const t = targetTrack();
  if (!t) {
    els.bgm.pause();
    updateMusicUI();
    return;
  }
  const src = TRACKS[t];
  if (els.bgm.dataset.track !== t) {
    const wasPlaying = !els.bgm.paused;
    els.bgm.src = src;
    els.bgm.dataset.track = t;
    if (state.musicOn || wasPlaying) {
      els.bgm.play().catch(() => {});
    }
  }
  updateMusicUI();
}

function updateMusicUI() {
  const playing = state.musicOn && !els.bgm.paused;
  els.volumeWrap.classList.toggle('hidden', !playing);
  els.musicToggle.textContent = playing ? 'Pause Music' : 'Play Music';
}

function bindEvents() {
  els.category.addEventListener('change', applyFilters);
  els.search.addEventListener('input', applyFilters);
  els.sort.addEventListener('change', applyFilters);
  els.panelWidthSlider.addEventListener('input', () => {
    applyPanelSplit(els.panelWidthSlider.value);
  });

  els.volume.addEventListener('input', () => {
    els.bgm.volume = Number(els.volume.value);
  });
  els.bgm.volume = Number(els.volume.value);

  els.musicMode.addEventListener('change', () => {
    syncMusicTrack();
  });

  els.musicToggle.addEventListener('click', async () => {
    if (state.musicOn) {
      state.musicOn = false;
      els.bgm.pause();
      updateMusicUI();
      return;
    }

    state.musicOn = true;
    syncMusicTrack();
    try {
      await els.bgm.play();
      updateMusicUI();
    } catch (_) {
      state.musicOn = false;
      updateMusicUI();
    }
  });

  els.shareBtn.addEventListener('click', async () => {
    await shareCurrentCard();
  });

  els.prevCardBtn.addEventListener('click', () => {
    selectByOffset(-1);
  });

  els.nextCardBtn.addEventListener('click', () => {
    selectByOffset(1);
  });

  els.randomCardBtn.addEventListener('click', () => {
    selectRandomCard();
  });

  els.image.addEventListener('dblclick', () => {
    openDeepInfo();
  });

  els.image.addEventListener('touchstart', (ev) => {
    if (!ev.touches || !ev.touches.length) return;
    swipeState.startX = ev.touches[0].clientX;
  }, { passive: true });

  els.image.addEventListener('touchend', (ev) => {
    if (swipeState.startX === null || !ev.changedTouches || !ev.changedTouches.length) {
      swipeState.startX = null;
      return;
    }
    const endX = ev.changedTouches[0].clientX;
    const dx = endX - swipeState.startX;
    swipeState.startX = null;
    if (Math.abs(dx) < 30) return;
    if (dx < 0) {
      selectByOffset(1);
    } else {
      selectByOffset(-1);
    }
  }, { passive: true });

  window.addEventListener('keydown', (ev) => {
    const target = ev.target;
    const tag = target && target.tagName ? target.tagName.toLowerCase() : '';
    const isEditable = Boolean(
      target && (target.isContentEditable || tag === 'input' || tag === 'textarea' || tag === 'select')
    );
    if (isEditable) return;

    if (ev.key === 'ArrowLeft') {
      ev.preventDefault();
      selectByGridStep(-1);
      return;
    }
    if (ev.key === 'ArrowRight') {
      ev.preventDefault();
      selectByGridStep(1);
      return;
    }
    if (ev.key === 'ArrowUp') {
      ev.preventDefault();
      selectByGridStep(-visibleGridColumns());
      return;
    }
    if (ev.key === 'ArrowDown') {
      ev.preventDefault();
      selectByGridStep(visibleGridColumns());
    }
  });

  // Drag divider for panel sizing (landscape)
  els.panelResizer.addEventListener('pointerdown', (ev) => {
    if (!els.layout) return;
    ev.preventDefault();
    const rect = els.layout.getBoundingClientRect();
    const onMove = (mv) => {
      const x = mv.clientX - rect.left;
      const pct = (x / rect.width) * 100;
      applyPanelSplit(pct);
    };
    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
  });
}

bindEvents();
updateMusicUI();
try {
  const saved = localStorage.getItem('dndex_panel_split');
  applyPanelSplit(saved || 62);
} catch (_) {
  applyPanelSplit(62);
}
loadCards();
