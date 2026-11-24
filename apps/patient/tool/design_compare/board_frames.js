// Deterministic frames of the design board: pause every CSS animation and seek it to t.
const { chromium } = require('playwright');
const path = require('path'); const fs = require('fs');
const [S, page_, outDir, fps, t0, t1, w, h] = [process.argv[2], process.argv[3], process.argv[4], +process.argv[5], +process.argv[6], +process.argv[7], +(process.argv[8]||390), +(process.argv[9]||844)];
(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(S, 'board', page_));
  await page.evaluate(async () => { await document.fonts.ready; for (const a of document.getAnimations()) a.pause(); });
  const n = Math.round((t1 - t0) * fps);
  for (let i = 0; i <= n; i++) {
    const t = t0 + i / fps;
    await page.evaluate((t) => { for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; } }, t);
    await page.screenshot({ path: path.join(outDir, `f_${String(i).padStart(4, '0')}.png`) });
  }
  await browser.close();
  console.log('frames', n + 1);
})();
