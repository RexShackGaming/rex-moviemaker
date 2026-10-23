const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rex-moviemaker';
const $ = (id) => document.getElementById(id);
const post = (name, data = {}) =>
  fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
    .then((r) => r.json()).catch(() => null);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let keyframes = [], easings = [], fx = {}, minFov = 5, maxFov = 120, L = {};

/* ---------- locales (from locales/*.json via client) ---------- */
const t = (key, ...args) => { let i = 0; return (L[key] ?? key).replace(/%s/g, () => args[i++] ?? ''); };
function applyLocales() {
  document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
  document.querySelectorAll('[data-lp]').forEach((el) => { el.placeholder = t(el.dataset.lp); });
  document.querySelectorAll('[data-lt]').forEach((el) => { el.title = t(el.dataset.lt); });
}

/* ---------- custom dropdown (never native <select>/<datalist> in RedM NUI) ---------- */
function closeAllDd(except) { document.querySelectorAll('.dd.open').forEach((d) => { if (d !== except) d.classList.remove('open'); }); }
document.addEventListener('mousedown', (e) => { if (!e.target.closest('.dd')) closeAllDd(); });

// opts: [{value,label}], onChange(value)
function setupDd(dd, opts, value, onChange) {
  const menu = dd.querySelector('.dd-menu');
  const input = dd.querySelector('input');
  const disp = dd.querySelector('.dd-value');
  const labelOf = (v) => (opts.find((o) => o.value === v) || {}).label ?? v;
  dd._set = (v) => { dd.dataset.value = v; if (disp) disp.textContent = labelOf(v) || '—'; if (input) input.value = v; };
  dd._set(value ?? '');
  menu.innerHTML = opts.map((o) => `<div class="dd-opt" data-v="${esc(o.value)}">${esc(o.label)}${o.value && o.value !== o.label ? `<em>${esc(o.value)}</em>` : ''}</div>`).join('');
  dd.onmousedown = (e) => {
    if (e.target.closest('.dd-opt')) return;
    if (input && e.target === input && dd.classList.contains('open')) return;
    closeAllDd(dd); dd.classList.toggle('open');
    menu.querySelectorAll('.dd-opt').forEach((o) => o.classList.toggle('sel', o.dataset.v === dd.dataset.value));
  };
  menu.onmousedown = (e) => {
    const o = e.target.closest('.dd-opt'); if (!o) return;
    e.preventDefault(); dd._set(o.dataset.v); dd.classList.remove('open'); onChange(o.dataset.v);
  };
  if (input) input.oninput = () => { dd.dataset.value = input.value; };
}

/* ---------- keyframes ---------- */
function fmtTime(ms) {
  const s = ms / 1000;
  return s >= 60 ? `${Math.floor(s / 60)}m ${Math.round(s % 60)}s` : `${s.toFixed(1)}s`;
}

function renderTotal() {
  const ms = keyframes.reduce((sum, k, i) => sum + (k.hold || 0) + (i < keyframes.length - 1 ? k.duration || 0 : 0), 0);
  $('keyTotal').textContent = keyframes.length ? t('ui_total', keyframes.length, fmtTime(ms)) : '';
}

function renderKeys() {
  const list = $('keyList');
  renderTotal();
  if (!keyframes.length) { list.innerHTML = `<div class="empty">${esc(t('ui_no_keys'))}</div>`; return; }
  list.innerHTML = keyframes.map((k, i) => {
    const n = i + 1, last = i === keyframes.length - 1;
    return `<div class="row" data-i="${n}">
      <div class="row-head">
        <div class="badge">${n}</div>
        <div class="row-title">${esc(t('ui_shot', n))}<em>${k.x.toFixed(1)}, ${k.y.toFixed(1)}, ${k.z.toFixed(1)}</em></div>
        <div class="row-btns">
          <button class="mini" data-act="preview" title="${esc(t('ui_view'))}">&#9673;</button>
          <button class="mini" data-act="replace" title="${esc(t('ui_replace'))}">&#8635;</button>
          ${!last ? `<button class="mini" data-act="playfrom" title="${esc(t('ui_play_from'))}">&#9654;</button>` : ''}
          ${i > 0 ? `<button class="mini" data-act="up" title="${esc(t('ui_move_up'))}">&#9650;</button>` : ''}
          ${!last ? `<button class="mini" data-act="down" title="${esc(t('ui_move_down'))}">&#9660;</button>` : ''}
          <button class="mini" data-act="del" title="${esc(t('ui_delete'))}">&#10005;</button>
        </div>
      </div>
      <div class="grid">
        <div><label>${esc(t('ui_travel'))}</label><input type="number" data-f="duration" value="${k.duration}" min="0" step="250" ${last ? 'disabled' : ''}></div>
        <div><label>${esc(t('ui_hold'))}</label><input type="number" data-f="hold" value="${k.hold}" min="0" step="250"></div>
        <div><label>${esc(t('ui_fov'))}</label><input type="number" data-f="fov" value="${k.fov.toFixed(1)}" min="${minFov}" max="${maxFov}" step="1"></div>
        <div><label>${esc(t('ui_roll'))}</label><input type="number" data-f="ry" value="${k.ry.toFixed(1)}" step="1"></div>
      </div>
      <div class="grid" style="grid-template-columns:2fr 2fr">
        <div><label>${esc(t('ui_easing'))}</label><div class="dd ease-dd" data-ease="${esc(k.ease)}"><div class="dd-value"></div><span class="dd-arrow">&#9662;</span><div class="dd-menu"></div></div></div>
        <label class="focuschk"><input type="checkbox" data-f="focus" ${k.focus ? 'checked' : ''}> ${esc(t('ui_track_focus'))}</label>
      </div>
    </div>`;
  }).join('');
  list.querySelectorAll('.ease-dd').forEach((dd) => {
    const i = +dd.closest('.row').dataset.i;
    setupDd(dd, easings.map((e) => ({ value: e, label: e })), dd.dataset.ease, (v) => {
      keyframes[i - 1].ease = v; post('updateKeyframe', { index: i, field: 'ease', value: v });
    });
  });
}

$('keyList').addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-act]'); if (!btn) return;
  const i = +btn.closest('.row').dataset.i;
  const act = btn.dataset.act;
  if (act === 'preview') post('previewKeyframe', { index: i });
  else if (act === 'replace') post('replaceKeyframe', { index: i });
  else if (act === 'playfrom') post('play', { from: i });
  else if (act === 'up') post('moveKeyframe', { index: i, dir: -1 });
  else if (act === 'down') post('moveKeyframe', { index: i, dir: 1 });
  else if (act === 'del') post('deleteKeyframe', { index: i });
});

$('keyList').addEventListener('change', (e) => {
  const f = e.target.dataset.f; if (!f) return;
  const i = +e.target.closest('.row').dataset.i;
  let value = e.target.type === 'checkbox' ? e.target.checked : Number(e.target.value);
  keyframes[i - 1][f] = value;
  post('updateKeyframe', { index: i, field: f, value });
  if (f === 'ry' || f === 'fov') post('previewKeyframe', { index: i });
  if (f === 'duration' || f === 'hold') renderTotal();
});

// two-step confirm so one misclick can't wipe the timeline
let clearTimer = null;
$('btnClear').onclick = () => {
  const b = $('btnClear');
  if (!clearTimer) {
    b.textContent = t('ui_confirm'); b.classList.add('confirm');
    clearTimer = setTimeout(resetClear, 2500);
    return;
  }
  resetClear();
  post('clearKeyframes');
};
function resetClear() {
  clearTimeout(clearTimer); clearTimer = null;
  $('btnClear').textContent = t('ui_clear'); $('btnClear').classList.remove('confirm');
}

$('btnAdd').onclick = () => post('addHere');
$('btnPlay').onclick = () => post('play', { from: 1 });
$('btnFly').onclick = () => post('fly');
$('btnClose').onclick = () => post('close');

const pushSettings = () => post('setSettings', { loop: $('setLoop').checked, hidePlayer: $('setHide').checked });
$('setLoop').onchange = pushSettings;
$('setHide').onchange = pushSettings;

/* ---------- tabs ---------- */
document.querySelectorAll('.tab').forEach((tab) => tab.onclick = () => {
  document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('active', x === tab));
  document.querySelectorAll('.tabpage').forEach((p) => p.classList.toggle('hidden', p.id !== 'tab-' + tab.dataset.tab));
  closeAllDd();
  if (tab.dataset.tab === 'scenes') post('getScenes').then(renderScenes);
});

/* ---------- effects ---------- */
function labels() {
  $('tcVal').textContent = Number($('fxTcS').value).toFixed(2);
  $('shVal').textContent = Number($('fxShakeA').value).toFixed(1);
  $('lbVal').textContent = $('fxLb').value + '%';
}
function fillFx() {
  $('ddTc')._set(fx.timecycle || ''); $('ddPfx')._set(fx.postfx || ''); $('ddShake')._set(fx.shake || '');
  $('fxTcS').value = fx.tcStrength ?? 1; $('fxShakeA').value = fx.shakeAmp || 0; $('fxLb').value = fx.letterbox || 0;
  $('fxFi').value = fx.fadeIn || 0; $('fxFo').value = fx.fadeOut || 0;
  labels();
}
function readFx() {
  fx = {
    timecycle: $('fxTc').value.trim(), tcStrength: +$('fxTcS').value, postfx: $('fxPfx').value.trim(),
    shake: $('ddShake').dataset.value || '', shakeAmp: +$('fxShakeA').value, letterbox: +$('fxLb').value,
    fadeIn: +$('fxFi').value || 0, fadeOut: +$('fxFo').value || 0,
  };
  labels();
  post('setFx', fx);
}
['fxTc', 'fxTcS', 'fxPfx', 'fxShakeA', 'fxLb', 'fxFi', 'fxFo'].forEach((id) => $(id).addEventListener('change', readFx));
['fxTcS', 'fxShakeA', 'fxLb'].forEach((id) => $(id).addEventListener('input', labels));
$('btnFxPrev').onclick = () => { readFx(); post('previewFx'); };
$('btnFxClear').onclick = () => post('clearFx');

function setLetterbox(pct) {
  $('letterbox').classList.toggle('hidden', !pct);
  document.querySelectorAll('#letterbox .bar').forEach((b) => { b.style.height = (pct || 0) + 'vh'; });
}

/* ---------- focus ---------- */
function setFocus(d) {
  const s = $('focusStatus');
  s.classList.toggle('on', !!d.has);
  s.textContent = t(d.has ? (d.self ? 'ui_focus_self' : 'ui_focus_entity') : 'ui_focus_none');
}
$('btnFocusSelf').onclick = () => post('focusSelf');
$('btnFocusClear').onclick = () => post('clearFocus');

/* ---------- scenes ---------- */
function renderScenes(list) {
  if (!Array.isArray(list)) return; // rate limited / failed: keep current list
  const el = $('sceneList');
  if (!list.length) { el.innerHTML = `<div class="empty">${esc(t('ui_no_scenes'))}</div>`; return; }
  el.innerHTML = list.map((s) => `<div class="row" data-id="${s.id}"><div class="row-head">
    <div class="badge">&#9673;</div><div class="row-title">${esc(s.name)}</div>
    <div class="row-btns"><button class="wood sm" data-act="load">${esc(t('ui_load'))}</button><button class="mini" data-act="del" title="${esc(t('ui_delete'))}">&#10005;</button></div>
  </div></div>`).join('');
}
$('sceneList').addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-act]'); if (!btn) return;
  const row = btn.closest('.row'); const id = +row.dataset.id;
  if (btn.dataset.act === 'load') {
    const res = await post('loadScene', { id });
    if (!res) return;
    keyframes = res.keyframes || []; fx = res.fx || {};
    $('sceneName').value = row.querySelector('.row-title').textContent;
    $('setLoop').checked = !!res.settings?.loop; $('setHide').checked = !!res.settings?.hidePlayer;
    fillFx(); renderKeys();
  } else {
    renderScenes(await post('deleteScene', { id }));
  }
});
const saveScene = async () => {
  const name = $('sceneName').value.trim(); if (!name) return;
  renderScenes(await post('saveScene', { name }));
};
$('btnSave').onclick = saveScene;
$('sceneName').addEventListener('keydown', (e) => { if (e.key === 'Enter') saveScene(); });

/* ---------- messages from client ---------- */
const show = (app, hud) => { $('app').classList.toggle('hidden', !app); $('flyhud').classList.toggle('hidden', !hud); };

window.addEventListener('message', ({ data: msg }) => {
  const d = msg.data;
  switch (msg.action) {
    case 'open':
      L = d.ui || {}; applyLocales();
      keyframes = d.keyframes || []; fx = d.fx || {}; easings = d.easings || [];
      minFov = d.minFov; maxFov = d.maxFov;
      setupDd($('ddTc'), d.timecycles, fx.timecycle, readFx);
      setupDd($('ddPfx'), d.postfx, fx.postfx, readFx);
      setupDd($('ddShake'), [{ value: '', label: t('ui_none') }, ...d.shakes], fx.shake, readFx);
      $('setLoop').checked = !!d.settings?.loop; $('setHide').checked = !!d.settings?.hidePlayer;
      setFocus({ has: !!d.settings?.focusSelf, self: !!d.settings?.focusSelf });
      fillFx(); renderKeys();
      break;
    case 'editor': closeAllDd(); resetClear(); show(true, false); setLetterbox(0); break;
    case 'fly': show(false, true); $('flyFov').textContent = Math.round(d.fov); break;
    case 'flyFov': $('flyFov').textContent = Math.round(d); break;
    case 'play': show(false, false); break;
    case 'keyframes': keyframes = d || []; renderKeys(); break;
    case 'letterbox': setLetterbox(d); break;
    case 'focus': setFocus(d); break;
    case 'close': closeAllDd(); show(false, false); setLetterbox(0); break;
  }
});

document.addEventListener('keyup', (e) => {
  if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
  if (document.querySelector('.dd.open')) return closeAllDd();
  post('close');
});
