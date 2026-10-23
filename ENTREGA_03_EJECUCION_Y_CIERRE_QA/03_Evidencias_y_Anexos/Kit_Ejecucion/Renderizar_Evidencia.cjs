// Renderizar_Evidencia.cjs — Convierte una salida real de consola (.txt) en una captura .png legible (mismo estilo que Capturas_Bugs).
// Uso: PLAYWRIGHT_MODULE=<ruta a playwright-core> node Renderizar_Evidencia.cjs <entrada.txt> <salida.png> "<título>"
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
const fs = require('fs');
const [entrada, salida, titulo] = process.argv.slice(2);
const esc = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const colorear = linea => {
  const e = esc(linea);
  if (/^HTTP\/1\.1 (2\d\d)|^HTTP 2\d\d/.test(linea)) return `<span class="ok">${e}</span>`;
  if (/^HTTP\/1\.1 (40[13])|^HTTP 40[13]/.test(linea)) return `<span class="deny">${e}</span>`;
  if (/^HTTP|FALLA|DIFERENTE|NO COINCIDE/.test(linea)) return `<span class="bad">${e}</span>`;
  if (/^\$ |^Petición|^--- /.test(linea)) return `<span class="cmd">${e}</span>`;
  if (/OK$|COINCIDE|sin cambios: True|Sin cambios: True/.test(linea)) return `<span class="ok">${e}</span>`;
  return e;
};
const cuerpo = fs.readFileSync(entrada, 'utf8').split('\n').map(colorear).join('\n');
const html = `<!doctype html><html lang="es"><meta charset="utf-8"><style>
body{margin:0;background:#fafafa;font:13px/1.45 Menlo,Consolas,monospace;color:#222}
h1{margin:0;padding:14px 18px;background:#24292f;color:#fff;font:bold 15px Menlo,monospace}
pre{margin:0;padding:16px 18px;white-space:pre-wrap;word-break:break-all}
.cmd{color:#0b5cad}.ok{color:#1a7f37}.deny{color:#1a7f37;font-weight:bold}.bad{color:#c62828;font-weight:bold}
footer{padding:10px 18px 16px;color:#777}</style>
<div id="evidencia"><h1>${esc(titulo)}</h1><pre>${cuerpo}</pre><footer>Render de la salida real de consola (${esc(require('path').basename(entrada))}) — BancoERP Nexus QA E3 · ciclo 2</footer></div></html>`;
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await (await browser.newContext({ viewport: { width: 1500, height: 900 }, deviceScaleFactor: 1 })).newPage();
  await page.setContent(html);
  await page.locator('#evidencia').screenshot({ path: salida });
  await browser.close();
  console.log('Captura guardada en', salida);
})().catch(e => { console.error(e); process.exit(1); });
