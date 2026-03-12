const state = {
  cards: [],
  filtered: [],
  selectedId: null,
  musicOn: false,
};

const els = {
  category: document.getElementById('categorySelect'),
  search: document.getElementById('searchInput'),
  sort: document.getElementById('sortSelect'),
  count: document.getElementById('countLabel'),
  grid: document.getElementById('cardGrid'),
  title: document.getElementById('detailTitle'),
  meta: document.getElementById('detailMeta'),
  image: document.getElementById('detailImage'),
  stats: document.getElementById('detailStats'),
  desc: document.getElementById('detailDesc'),
  musicToggle: document.getElementById('musicToggle'),
  musicMode: document.getElementById('musicMode'),
  volume: document.getElementById('volumeSlider'),
  bgm: document.getElementById('bgm'),
};

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

  if (!arr.find((c) => c.id === state.selectedId)) {
    state.selectedId = arr[0]?.id || null;
  }

  renderGrid();
  renderDetail();
  syncMusicTrack();
}

function renderGrid() {
  els.grid.innerHTML = '';
  for (const card of state.filtered) {
    const item = document.createElement('button');
    item.className = `card-item${card.id === state.selectedId ? ' active' : ''}`;
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
  }
}

function renderDetail() {
  const card = state.filtered.find((c) => c.id === state.selectedId);
  if (!card) {
    els.title.textContent = 'No cards in this filter';
    els.meta.textContent = '';
    els.image.removeAttribute('src');
    els.stats.innerHTML = '';
    els.desc.textContent = '';
    return;
  }

  els.title.textContent = card.name;
  els.meta.textContent = `${humanType(card.type)}${card.source ? ` • ${card.source}` : ''}`;
  els.image.src = `../${card.image}`;
  els.image.alt = card.name;

  els.stats.innerHTML = '';
  for (const [k, v] of Object.entries(card.stats || {})) {
    const p = document.createElement('span');
    p.className = 'stat-pill';
    p.textContent = `${k}: ${v}`;
    els.stats.appendChild(p);
  }

  els.desc.textContent = card.description || '';
}

function targetTrack() {
  const mode = els.musicMode.value;
  if (mode === 'off') return null;
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
}

function bindEvents() {
  els.category.addEventListener('change', applyFilters);
  els.search.addEventListener('input', applyFilters);
  els.sort.addEventListener('change', applyFilters);

  els.volume.addEventListener('input', () => {
    els.bgm.volume = Number(els.volume.value);
  });
  els.bgm.volume = Number(els.volume.value);

  els.musicMode.addEventListener('change', () => {
    syncMusicTrack();
    if (els.musicMode.value === 'off') {
      state.musicOn = false;
      els.musicToggle.textContent = 'Play Music';
      els.bgm.pause();
    }
  });

  els.musicToggle.addEventListener('click', async () => {
    if (state.musicOn) {
      state.musicOn = false;
      els.musicToggle.textContent = 'Play Music';
      els.bgm.pause();
      return;
    }

    state.musicOn = true;
    els.musicToggle.textContent = 'Pause Music';
    syncMusicTrack();
    try {
      await els.bgm.play();
    } catch (_) {
      state.musicOn = false;
      els.musicToggle.textContent = 'Play Music';
    }
  });
}

bindEvents();
loadCards();
