// Renders the native-splash "a" (scale 1 in dp, bounds centred) as transparent PNGs.
const { chromium } = require('playwright');
const [outDir] = process.argv.slice(2);
const A = (s) => `<g transform="scale(${s}) translate(-9.5 -1)"><circle r="45" fill="none" stroke="#C8302B" stroke-width="16"/><path d="M45 -44 V26 Q45 46 64 46" fill="none" stroke="#C8302B" stroke-width="16" stroke-linecap="round"/><g fill="#1A1410"><circle cx="-16" cy="-6" r="8"/><circle cx="16" cy="-6" r="8"/></g></g>`;
(async () => {
  const browser = await chromium.launch();
  for (const [name, px, s] of [['splash_a.png', 640, 4], ['splash_a_android12.png', 1152, 4]]) {
    const page = await browser.newPage({ viewport: { width: px, height: px }, deviceScaleFactor: 1 });
    await page.setContent(`<html><body style="margin:0;background:transparent"><svg width="${px}" height="${px}" viewBox="${-px/2} ${-px/2} ${px} ${px}">${A(s)}</svg></body></html>`);
    await page.screenshot({ path: `${outDir}/${name}`, omitBackground: true });
    await page.close();
  }
  await browser.close();
})();
