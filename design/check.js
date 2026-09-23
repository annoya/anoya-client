// Run in the mockup page; returns the list of violations.
(() => {
  const S = 0.62;                       // display scale
  const pt = px => Math.round(px / S);  // back to logical points
  const bad = [];
  const label = el => {
    const b = el.closest('.board');
    return b?.querySelector('.cap .id')?.textContent?.trim() || '(no id)';
  };

  // macOS 738 = default content area plus a 38pt title bar.
  document.querySelectorAll('.ph, .mac').forEach(f => {
    const limit = f.classList.contains('ph') ? 852 : 738;
    const over = f.scrollHeight - limit;
    if (over > 2) bad.push(`${label(f)}: content overflows frame by ${over}pt`);
    const wide = f.scrollWidth - (f.classList.contains('ph') ? 393 : 400);
    if (wide > 2) bad.push(`${label(f)}: content wider than frame by ${wide}pt`);
  });

  document.querySelectorAll('.inp').forEach(i => {
    const h = pt(i.getBoundingClientRect().height);
    const multiline = i.querySelector('.vl.multi');
    if (!multiline && (h < 54 || h > 62)) bad.push(`${label(i)}: input ${h}pt, expected 56`);
    if (i.classList.contains('sel') && getComputedStyle(i).flexDirection !== 'row') {
      bad.push(`${label(i)}: select is a column — chevron must sit on the right`);
    }
  });

  document.querySelectorAll('.row').forEach(r => {
    const h = pt(r.getBoundingClientRect().height);
    const two = !!r.querySelector('.s');
    const wraps = !!r.querySelector('.s.multi');
    const want = two ? 72 : 56;
    if (!wraps && Math.abs(h - want) > 8) bad.push(`${label(r)}: row ${h}pt, expected ${want}`);
    if (wraps && h > 110) bad.push(`${label(r)}: wrapped row ${h}pt — too tall`);
  });
  document.querySelectorAll('.rule').forEach(r => {
    const h = pt(r.getBoundingClientRect().height);
    if (Math.abs(h - 64) > 8) bad.push(`${label(r)}: rule row ${h}pt, expected 64`);
  });

  document.querySelectorAll('.btn').forEach(b => {
    const h = pt(b.getBoundingClientRect().height);
    if (Math.abs(h - 48) > 3) bad.push(`${label(b)}: button ${h}pt, expected 48`);
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
    if (Math.abs(h - 40) > 3) bad.push(`${label(s)}: segmented ${h}pt, expected 40`);
    const own = s.getBoundingClientRect().width;
    const parent = s.parentElement.getBoundingClientRect().width;
    const padding = 32 * S; // 16 each side
    if (own < parent - padding - 2) bad.push(`${label(s)}: segmented not full width`);
  });

  document.querySelectorAll('.ab').forEach(a => {
    const h = pt(a.getBoundingClientRect().height);
    if (Math.abs(h - 56) > 3) bad.push(`${label(a)}: app bar ${h}pt, expected 56`);
    const ics = [...a.querySelectorAll('.ic')];
    if (ics.length >= 2) {
      const ab = a.getBoundingClientRect();
      const first = ics[0].getBoundingClientRect();
      const last = ics[ics.length - 1].getBoundingClientRect();
      const left = pt(first.left + first.width / 2 - ab.left);
      const right = pt(ab.right - (last.left + last.width / 2));
      if (Math.abs(left - right) > 2) {
        bad.push(`${label(a)}: app-bar icons inset ${left}pt left vs ${right}pt right`);
      }
    }
  });
  // .demo is a deliberately shrunk illustration, exempt from size rules.
  document.querySelectorAll('.ring:not(.demo)').forEach(r => {
    const b = r.getBoundingClientRect();
    if (Math.abs(pt(b.width) - 180) > 3) bad.push(`${label(r)}: ring ${pt(b.width)}pt, expected 180`);
  });
  document.querySelectorAll('.fab').forEach(f => {
    const b = f.getBoundingClientRect();
    if (Math.abs(pt(b.width) - 56) > 3) bad.push(`${label(f)}: fab ${pt(b.width)}pt, expected 56`);
  });
  document.querySelectorAll('.sw').forEach(s => {
    const b = s.getBoundingClientRect();
    if (Math.abs(pt(b.width) - 52) > 3 || Math.abs(pt(b.height) - 32) > 3) {
      bad.push(`${label(s)}: switch ${pt(b.width)}×${pt(b.height)}pt, expected 52×32`);
    }
  });

  document.querySelectorAll('.ph, .mac').forEach(f => {
    const fr = f.getBoundingClientRect();
    f.querySelectorAll('.card, .btn, .inp, .dlg, .sheet').forEach(el => {
      const r = el.getBoundingClientRect();
      if (r.right > fr.right + 1 || r.left < fr.left - 1) {
        bad.push(`${label(f)}: ${el.className.split(' ')[0]} sticks out horizontally`);
      }
    });
  });

  const inside = new Set();
  document.querySelectorAll('.ph *, .mac *').forEach(el => {
    (el.classList || []).forEach(c => inside.add(c));
  });
  const outside = new Set();
  document.querySelectorAll('.wrap > *, .wrap > * > *').forEach(el => {
    if (el.closest('.ph') || el.closest('.mac')) return;
    (el.classList || []).forEach(c => outside.add(c));
  });
  [...inside].filter(c => outside.has(c)).forEach(c =>
    bad.push(`class collision: ".${c}" is used both inside canvases and as page chrome`));

  const uniq = [...new Set(bad)];
  return JSON.stringify({violations: uniq.length, list: uniq.slice(0, 40)});
})()
