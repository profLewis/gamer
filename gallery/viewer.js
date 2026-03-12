const GALLERY = {
  classes: [
    'barbarian', 'cleric', 'fighter', 'ranger', 'rogue', 'wizard',
  ],
  races: [
    'dragonborn', 'half-elf', 'half-orc', 'high-elf', 'hill-dwarf', 'human',
    'lightfoot-halfling', 'mountain-dwarf', 'rock-gnome', 'stout-halfling',
    'tiefling', 'wood-elf',
  ],
  rooms: [
    'armoury', 'boss-chamber', 'chamber', 'corridor', 'empty-room', 'entrance',
    'library', 'prison', 'shop', 'shrine', 'trap-room', 'treasure-room',
  ],
  monsters: [
    'basilisk', 'beholder', 'bugbear', 'crawling-claw', 'demogorgon',
    'displacer-beast', 'gargoyle', 'gelatinous-cube', 'giant-bat', 'giant-rat',
    'giant-spider', 'gnoll', 'goblin', 'hobgoblin', 'kobold', 'mimic',
    'mind-flayer', 'minotaur', 'ogre', 'orc', 'owlbear', 'rust-monster',
    'skeleton', 'stirge', 'troll', 'vecna', 'wolf', 'wraith', 'young-dragon',
    'zombie',
  ],
  npcs: [
    'dwarven-smith', 'elf-scout', 'gatekeeper', 'ghostly-scholar',
    'goblin-defector', 'hermit', 'mad-alchemist', 'mysterious-stranger',
    'old-priestess', 'prisoner', 'rat-catcher', 'wandering-trader',
    'wounded-knight',
  ],
  spells: ['README'],
};

const els = {
  category: document.getElementById('categorySelect'),
  page: document.getElementById('pageSelect'),
  voice: document.getElementById('voiceSelect'),
  doc: document.getElementById('doc'),
  toast: document.getElementById('toast'),
  sampleButtons: Array.from(document.querySelectorAll('[data-sample]')),
};

let voices = [];

function titleize(slug) {
  return slug.replace(/-/g, ' ').replace(/\b\w/g, (m) => m.toUpperCase());
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function showToast(msg) {
  els.toast.textContent = msg;
  els.toast.classList.add('show');
  window.clearTimeout(showToast.tid);
  showToast.tid = window.setTimeout(() => {
    els.toast.classList.remove('show');
  }, 1300);
}

function selectedVoice() {
  const id = els.voice.value;
  return voices.find((v) => v.voiceURI === id) || null;
}

function speak(text) {
  const synth = window.speechSynthesis;
  if (!synth || !window.SpeechSynthesisUtterance) {
    showToast('Speech not supported in this browser.');
    return;
  }
  synth.cancel();
  const u = new SpeechSynthesisUtterance(text);
  const voice = selectedVoice();
  if (voice) u.voice = voice;
  u.rate = 1.0;
  u.pitch = 1.0;
  synth.speak(u);
}

function populateVoices() {
  const synth = window.speechSynthesis;
  if (!synth) {
    els.voice.innerHTML = '<option>Speech not supported</option>';
    return;
  }
  voices = synth.getVoices().filter((v) => (v.lang || '').toLowerCase().startsWith('en'));
  if (!voices.length) voices = synth.getVoices();
  voices.sort((a, b) => `${a.lang} ${a.name}`.localeCompare(`${b.lang} ${b.name}`));

  els.voice.innerHTML = '';
  for (const v of voices) {
    const opt = document.createElement('option');
    opt.value = v.voiceURI;
    opt.textContent = `${v.name} (${v.lang})`;
    els.voice.appendChild(opt);
  }
}

function populateCategories() {
  els.category.innerHTML = '';
  for (const k of Object.keys(GALLERY)) {
    const opt = document.createElement('option');
    opt.value = k;
    opt.textContent = titleize(k);
    els.category.appendChild(opt);
  }
}

function populatePages() {
  const cat = els.category.value;
  const pages = GALLERY[cat] || [];
  els.page.innerHTML = '';
  for (const p of pages) {
    const opt = document.createElement('option');
    opt.value = p;
    opt.textContent = titleize(p);
    els.page.appendChild(opt);
  }
}

function renderMarkdown(md) {
  const lines = md.replace(/\r/g, '').split('\n');
  const out = [];
  let i = 0;
  let inCode = false;
  let codeLines = [];
  let currentSection = '';

  function flushCode() {
    if (!codeLines.length) return;
    out.push(`<pre><code>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
    codeLines = [];
  }

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      if (!inCode) {
        inCode = true;
        codeLines = [];
      } else {
        flushCode();
        inCode = false;
      }
      i += 1;
      continue;
    }

    if (inCode) {
      codeLines.push(line);
      i += 1;
      continue;
    }

    const head = trimmed.match(/^(#{1,6})\s+(.+)$/);
    if (head) {
      currentSection = head[2].trim().toLowerCase();
      const level = head[1].length;
      out.push(`<h${level}>${escapeHtml(head[2].trim())}</h${level}>`);
      i += 1;
      continue;
    }

    if (trimmed.includes('|') && i + 1 < lines.length && lines[i + 1].includes('|---')) {
      const rows = [];
      rows.push(line);
      i += 2;
      while (i < lines.length && lines[i].includes('|')) {
        rows.push(lines[i]);
        i += 1;
      }
      const headers = rows[0].split('|').map((s) => s.trim()).filter(Boolean);
      out.push('<table><thead><tr>');
      for (const h of headers) out.push(`<th>${escapeHtml(h)}</th>`);
      out.push('</tr></thead><tbody>');
      for (let r = 1; r < rows.length; r += 1) {
        const cols = rows[r].split('|').map((s) => s.trim()).filter(Boolean);
        out.push('<tr>');
        for (const c of cols) out.push(`<td>${escapeHtml(c)}</td>`);
        out.push('</tr>');
      }
      out.push('</tbody></table>');
      continue;
    }

    if (trimmed.startsWith('- ')) {
      const items = [];
      while (i < lines.length && lines[i].trim().startsWith('- ')) {
        items.push(lines[i].trim().slice(2));
        i += 1;
      }
      out.push('<ul>');
      for (const li of items) out.push(`<li>${escapeHtml(li)}</li>`);
      out.push('</ul>');
      continue;
    }

    if (trimmed.startsWith('>')) {
      const quotes = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quotes.push(lines[i].trim().replace(/^>\s?/, ''));
        i += 1;
      }
      const classes = ['quote'];
      if (currentSection === 'greeting') classes.push('greeting-line');
      const content = escapeHtml(quotes.join(' '));
      out.push(`<blockquote class="${classes.join(' ')}">${content}</blockquote>`);
      continue;
    }

    if (!trimmed) {
      i += 1;
      continue;
    }

    out.push(`<p>${escapeHtml(trimmed)}</p>`);
    i += 1;
  }

  if (inCode) flushCode();
  return out.join('');
}

async function loadDoc() {
  const cat = els.category.value;
  const page = els.page.value;
  const path = page === 'README' ? `${cat}/README.md` : `${cat}/${page}.md`;
  try {
    const res = await fetch(path, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`Failed to load ${path}`);
    const md = await res.text();
    els.doc.innerHTML = renderMarkdown(md);
    bindGreetingSpeech();
  } catch (err) {
    els.doc.innerHTML = `<p>Unable to load <code>${escapeHtml(path)}</code>.</p>`;
  }
}

function bindGreetingSpeech() {
  const greetings = Array.from(document.querySelectorAll('.greeting-line'));
  for (const node of greetings) {
    node.title = 'Click to hear greeting';
    node.addEventListener('click', () => {
      speak(node.textContent || '');
    });
  }
}

function bindEvents() {
  els.category.addEventListener('change', async () => {
    populatePages();
    await loadDoc();
  });

  els.page.addEventListener('change', async () => {
    await loadDoc();
  });

  for (const b of els.sampleButtons) {
    b.addEventListener('click', () => {
      speak(b.dataset.sample || '');
    });
  }
}

function init() {
  populateCategories();
  populatePages();
  populateVoices();
  bindEvents();
  loadDoc();

  if (window.speechSynthesis) {
    window.speechSynthesis.onvoiceschanged = () => {
      const current = els.voice.value;
      populateVoices();
      if (current) els.voice.value = current;
    };
  }
}

init();
