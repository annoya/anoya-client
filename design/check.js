(() => {
  const S = 0.62;
  const pt = px => Math.round(px / S);
  const bad = [];
  const label = el => {
    const b = el.closest('.board');
    return b?.querySelector('.cap .id')?.textContent?.trim() || '(no id)';
  };

  document.querySelectorAll('.ph, .mac').forEach(f => {
    const phone = f.classList.contains('ph');
    const limit = phone ? (f.classList.contains('tall') ? Infinity : 844) : 700;
    const over = f.scrollHeight - limit;
    if (over > 2) bad.push(`${label(f)}: content overflows frame by ${over}pt`);
    const wide = f.scrollWidth - (phone ? 390 : 400);
    if (wide > 2) bad.push(`${label(f)}: content wider than frame by ${wide}pt`);
  });

  document.querySelectorAll('.inp').forEach(i => {
    const h = pt(i.getBoundingClientRect().height);
    const multiline = i.querySelector('.vl.multi');
    if (!multiline && (h < 54 || h > 58)) bad.push(`${label(i)}: text field ${h}pt, expected 56`);
    if (i.classList.contains('sel') && getComputedStyle(i).flexDirection !== 'row') {
      bad.push(`${label(i)}: field with an action is a column — the action must sit on the right`);
    }
  });
  document.querySelectorAll('.search').forEach(i => {
    const h = pt(i.getBoundingClientRect().height);
    if (Math.abs(h - 44) > 2) bad.push(`${label(i)}: search field ${h}pt, expected 44`);
  });

  document.querySelectorAll('.row').forEach(r => {
    const h = pt(r.getBoundingClientRect().height);
    const wraps = !!r.querySelector('.s.multi, .t.multi');
    const want = r.querySelector('.s') ? 72 : 56;
    if (!wraps && h < want - 2) bad.push(`${label(r)}: row ${h}pt, expected at least ${want}`);
    if (!wraps && h > want + 2 && !r.querySelector('.badge, .x04-rb, .x04-tb')) bad.push(`${label(r)}: row ${h}pt, expected ${want}`);
    if (wraps && (h < 70 || h > 120)) bad.push(`${label(r)}: wrapped row ${h}pt — expected 72…120`);
  });
  document.querySelectorAll('.rule').forEach(r => {
    const h = pt(r.getBoundingClientRect().height);
    if (Math.abs(h - 72) > 2) bad.push(`${label(r)}: rule row ${h}pt, expected 72`);
  });

  document.querySelectorAll('.btn').forEach(b => {
    const h = pt(b.getBoundingClientRect().height);
    if (Math.abs(h - 48) > 2) bad.push(`${label(b)}: button ${h}pt, expected 48`);
  });
  document.querySelectorAll('.ph, .mac').forEach(f => {
    const groups = new Map();
    f.querySelectorAll('.btn').forEach(b => {
      const key = b.parentElement;
      groups.set(key, [...(groups.get(key) || []), pt(b.getBoundingClientRect().height)]);
    });
    groups.forEach(hs => {
      if (new Set(hs).size > 1) bad.push(`${label(f)}: stacked buttons differ in height (${hs.join('/')})`);
    });
  });

  document.querySelectorAll('.segm').forEach(s => {
    const h = pt(s.getBoundingClientRect().height);
    if (Math.abs(h - 48) > 2) bad.push(`${label(s)}: segmented ${h}pt, expected 48`);
    const own = s.getBoundingClientRect().width;
    const parent = s.parentElement.getBoundingClientRect();
    const cs = getComputedStyle(s.parentElement);
    const inner = parent.width - (parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight)) * S;
    if (own < inner - 2) bad.push(`${label(s)}: segmented not full width`);
  });

  document.querySelectorAll('.pill, .chip').forEach(c => {
    const h = pt(c.getBoundingClientRect().height);
    if (Math.abs(h - 34) > 2) bad.push(`${label(c)}: chip ${h}pt, expected 34`);
  });

  document.querySelectorAll('.ab').forEach(a => {
    const h = pt(a.getBoundingClientRect().height);
    if (Math.abs(h - 48) > 2) bad.push(`${label(a)}: nav row ${h}pt, expected 48`);
  });
  document.querySelectorAll('.sb').forEach(a => {
    const h = pt(a.getBoundingClientRect().height);
    if (Math.abs(h - 47) > 2) bad.push(`${label(a)}: status bar ${h}pt, expected 47`);
  });
  document.querySelectorAll('.lt .h').forEach(t => {
    const fs = parseFloat(getComputedStyle(t).fontSize);
    if (fs !== 30 && !t.closest('.lt.sm')) bad.push(`${label(t)}: large title ${fs}pt, expected 30`);
  });

  document.querySelectorAll('.stage').forEach(r => {
    const b = r.getBoundingClientRect();
    if (Math.abs(pt(b.width) - 240) > 2 || Math.abs(pt(b.height) - 200) > 2) {
      bad.push(`${label(r)}: cat stage ${pt(b.width)}×${pt(b.height)}pt, expected 240×200`);
    }
  });
  document.querySelectorAll('.fab').forEach(f => {
    const b = f.getBoundingClientRect();
    if (Math.abs(pt(b.width) - 56) > 2) bad.push(`${label(f)}: fab ${pt(b.width)}pt, expected 56`);
  });
  document.querySelectorAll('.sw').forEach(s => {
    const b = s.getBoundingClientRect();
    if (Math.abs(pt(b.width) - 50) > 2 || Math.abs(pt(b.height) - 30) > 2) {
      bad.push(`${label(s)}: toggle ${pt(b.width)}×${pt(b.height)}pt, expected 50×30`);
    }
  });

  document.querySelectorAll('.ph, .mac').forEach(f => {
    const fr = f.getBoundingClientRect();
    f.querySelectorAll('.card, .btn, .inp, .dlg, .sheet, .search, .segm').forEach(el => {
      const r = el.getBoundingClientRect();
      if (r.right > fr.right + 1 || r.left < fr.left - 1) {
        bad.push(`${label(f)}: ${el.className.split(' ')[0]} sticks out horizontally`);
      }
    });
  });

  const inside = new Set();
  document.querySelectorAll('.ph *, .mac *, .tray *').forEach(el => {
    (el.classList || []).forEach(c => inside.add(c));
  });
  const outside = new Set();
  document.querySelectorAll('.wrap > *, .wrap > * > *').forEach(el => {
    if (el.closest('.ph') || el.closest('.mac') || el.closest('.tray')) return;
    (el.classList || []).forEach(c => outside.add(c));
  });
  [...inside].filter(c => outside.has(c)).forEach(c =>
    bad.push(`class collision: ".${c}" is used both inside canvases and as page chrome`));

  const uniq = [...new Set(bad)];
  return JSON.stringify({violations: uniq.length, list: uniq.slice(0, 60)});
})()
