// Mockup self-check: every canvas must fit its frame and every component must
// match the metrics table. Run in the page; returns a list of violations.
(() => {
  const S = 0.62;                       // display scale
  const pt = px => Math.round(px / S);  // back to logical points
  const bad = [];
  const label = el => {
    const b = el.closest('.board');
    return b?.querySelector('.cap .id')?.textContent?.trim() || '(no id)';
  };

  // 1. frames must not overflow (phone 874, mac 630)
  document.querySelectorAll('.ph, .mac').forEach(f => {
    const limit = f.classList.contains('ph') ? 874 : 630;
    const over = f.scrollHeight - limit;
    if (over > 2) bad.push(`${label(f)}: content overflows frame by ${over}pt`);
    const wide = f.scrollWidth - (f.classList.contains('ph') ? 402 : 700);
    if (wide > 2) bad.push(`${label(f)}: content wider than frame by ${wide}pt`);
  });

  // 2. inputs and selects: 56pt tall, select must be a row
  document.querySelectorAll('.inp').forEach(i => {
    const h = pt(i.getBoundingClientRect().height);
    const multiline = i.querySelector('.vl.multi');
    if (!multiline && (h < 54 || h > 62)) bad.push(`${label(i)}: input ${h}pt, expected 56`);
    if (i.classList.contains('sel') && getComputedStyle(i).flexDirection !== 'row') {
      bad.push(`${label(i)}: select is a column — chevron must sit on the right`);
    }
  });

  // 3. list rows: 56 (one line) or 72 (two lines); rule rows 64
  document.querySelectorAll('.row').forEach(r => {
    const h = pt(r.getBoundingClientRect().height);
    const two = !!r.querySelector('.s');
    const wraps = !!r.querySelector('.s.wrap');
    const want = two ? 72 : 56;
    if (!wraps && Math.abs(h - want) > 8) bad.push(`${label(r)}: row ${h}pt, expected ${want}`);
    if (wraps && h > 110) bad.push(`${label(r)}: wrapped row ${h}pt — too tall`);
  });
  document.querySelectorAll('.rule').forEach(r => {
    const h = pt(r.getBoundingClientRect().height);
    if (Math.abs(h - 64) > 8) bad.push(`${label(r)}: rule row ${h}pt, expected 64`);
  });

  // 4. every button is 48pt — filled, tonal and outlined alike, so a stack of
  // them never looks ragged
  document.querySelectorAll('.btn').forEach(b => {
    const h = pt(b.getBoundingClientRect().height);
    if (Math.abs(h - 48) > 3) bad.push(`${label(b)}: button ${h}pt, expected 48`);
  });
  // 4b. buttons stacked in the same container must share a height
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

  // 5. segmented: 40pt and full width of its container
  document.querySelectorAll('.segm').forEach(s => {
    const h = pt(s.getBoundingClientRect().height);
    if (Math.abs(h - 40) > 3) bad.push(`${label(s)}: segmented ${h}pt, expected 40`);
    const own = s.getBoundingClientRect().width;
    const parent = s.parentElement.getBoundingClientRect().width;
    const padding = 32 * S; // 16 each side
    if (own < parent - padding - 2) bad.push(`${label(s)}: segmented not full width`);
  });

  // 6. app bars 56, section headers 12pt caps, ring 180, fab 56, switch 52x32
  document.querySelectorAll('.ab').forEach(a => {
    const h = pt(a.getBoundingClientRect().height);
    if (Math.abs(h - 56) > 3) bad.push(`${label(a)}: app bar ${h}pt, expected 56`);
    // Leading and trailing icons must be inset equally (28pt to their centre),
    // otherwise "+" and the gear look off-balance.
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
  // ".demo" marks a component shown at a reduced size purely to illustrate a
  // state — exempt from the size rules.
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

  // 7. nothing may stick out of the frame horizontally
  document.querySelectorAll('.ph, .mac').forEach(f => {
    const fr = f.getBoundingClientRect();
    f.querySelectorAll('.card, .btn, .inp, .dlg, .sheet').forEach(el => {
      const r = el.getBoundingClientRect();
      if (r.right > fr.right + 1 || r.left < fr.left - 1) {
        bad.push(`${label(f)}: ${el.className.split(' ')[0]} sticks out horizontally`);
      }
    });
  });

  // 8. class-name collisions: a class used inside a canvas must not also be a
  // page-chrome class (".wrap" as a text modifier once inherited the page
  // container's 36/28/80 padding; ".ph" as a placeholder inherited the phone's
  // 874pt height). Page chrome = anything outside .ph/.mac.
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
