const { chromium } = require('playwright');
const path = require('path');
const S = process.argv[2];
(async () => {
  const browser = await chromium.launch();
  const out = {};
  const sels = ['.bar','.brandmark','.pro','.hero','svg.arch','.glow','.copy','.h1','.lede','.online','.online .dot','.online b','.actions','.btn.primary','.link'];
  async function boxes(page, t) {
    await page.evaluate(async (t) => {
      await document.fonts.ready;
      for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; }
    }, t);
    return await page.evaluate((sels) => {
      const r = {};
      for (const s of sels) { const e = document.querySelector(s); if (!e) continue; const b = e.getBoundingClientRect(); r[s] = [b.x, b.y, b.width, b.height].map(v => Math.round(v * 100) / 100); }
      // lede line count
      const l = document.querySelector('.lede'); if (l) { r.ledeLines = Math.round(l.getBoundingClientRect().height / parseFloat(getComputedStyle(l).lineHeight)); r.ledeLH = getComputedStyle(l).lineHeight; }
      const lk = document.querySelector('.link'); if (lk) r.linkLH = getComputedStyle(lk).lineHeight;
      return r;
    }, sels);
  }
  for (const [name, w, h, t] of [['welcome_390x844', 390, 844, 30], ['welcome_360x640', 360, 640, 30], ['splash', 390, 844, 14]]) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    await page.goto('file://' + path.join(S, 'board', name + '.html'));
    await page.waitForTimeout(500);
    out[name] = await boxes(page, t);
    await page.screenshot({ path: path.join(S, 'board', name + '.png') });
    await page.close();
  }
  console.log(JSON.stringify(out, null, 1));
  await browser.close();
})();
