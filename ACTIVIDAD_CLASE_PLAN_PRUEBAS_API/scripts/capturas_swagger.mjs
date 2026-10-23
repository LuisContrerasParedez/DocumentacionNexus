#!/usr/bin/env node
// Toma capturas de Swagger UI ejecutando los casos principales desde el navegador.
// Requiere playwright-core (npm i playwright-core) y Google Chrome instalado.
// Variables: BASE_URL, BANCO_EXTERNO_PASSWORD (obligatoria), PLAYWRIGHT_MODULE (ruta opcional a playwright-core).
// La contrasena y el JWT se enmascaran en pantalla antes de cada captura.

import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE ?? 'playwright-core');

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:5254';
const EMAIL = process.env.BANCO_EXTERNO_EMAIL ?? 'bancoexterno@nexus.com';
const PASSWORD = process.env.BANCO_EXTERNO_PASSWORD;
if (!PASSWORD) {
  console.error('Falta BANCO_EXTERNO_PASSWORD.');
  process.exit(2);
}

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'evidencias', 'swagger');
mkdirSync(outDir, { recursive: true });

const RUN = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const CUENTA_ACTIVA = 'MO260812213864';
const CUENTA_BLOQUEADA = 'AH260901838371';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const context = await browser.newContext({ viewport: { width: 1360, height: 900 }, deviceScaleFactor: 1.5 });
const page = await context.newPage();

async function maskSecrets() {
  await page.evaluate((password) => {
    const jwt = /eyJ[\w-]+\.[\w-]+\.[\w-]+/g;
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      let text = node.nodeValue;
      if (text.includes(password)) text = text.split(password).join('******');
      text = text.replace(jwt, (t) => `${t.slice(0, 20)}...[JWT enmascarado]`);
      if (text !== node.nodeValue) node.nodeValue = text;
    }
    for (const el of document.querySelectorAll('textarea, input')) {
      if (el.value?.includes(password)) el.value = el.value.split(password).join('******');
      if (jwt.test(el.value ?? '')) el.value = el.value.replace(jwt, (t) => `${t.slice(0, 20)}...[JWT enmascarado]`);
    }
  }, PASSWORD);
}

async function shot(name, locator) {
  await maskSecrets();
  const path = join(outDir, name);
  const live = locator?.locator('.live-responses-table');
  if (live && (await live.count())) {
    await locator.evaluate((block) => {
      block.querySelectorAll('.opblock-description-wrapper').forEach((el) => {
        if (!el.closest('.opblock-section-request-body')) el.style.display = 'none';
      });
      block.querySelectorAll('textarea.body-param__text').forEach((el) => { el.style.height = `${Math.max(el.scrollHeight, 60)}px`; });
    });
    // Recorta desde el encabezado de la operacion hasta la respuesta del servidor (omite ejemplos de esquema).
    const clip = await locator.evaluate((block) => {
      const top = block.getBoundingClientRect().top + window.scrollY;
      const left = block.getBoundingClientRect().left + window.scrollX;
      const bottom = block.querySelector('.live-responses-table').getBoundingClientRect().bottom + window.scrollY;
      return { x: left, y: top, width: block.getBoundingClientRect().width, height: bottom - top + 12 };
    });
    await page.screenshot({ path, clip, fullPage: true });
    await locator.evaluate((block) => {
      block.querySelectorAll('.opblock-description-wrapper, textarea.body-param__text').forEach((el) => { el.style.display = ''; el.style.height = ''; });
    });
  } else if (locator) {
    await locator.screenshot({ path });
  } else {
    await page.screenshot({ path, fullPage: true });
  }
  console.log(`captura ${name}`);
}

function opblock(method, path) {
  return page.locator(`.opblock.opblock-${method}`).filter({ has: page.locator(`.opblock-summary-path[data-path="${path}"]`) });
}

async function expand(block) {
  if (!(await block.locator('.opblock-body').count())) {
    await block.locator('.opblock-summary').first().click();
  }
  await block.locator('.opblock-body').waitFor();
  const tryOut = block.locator('button.try-out__btn');
  if ((await tryOut.textContent())?.trim() === 'Try it out') await tryOut.click();
}

async function execute(block) {
  const clear = block.locator('button.btn-clear');
  if (await clear.count()) await clear.click();
  await block.locator('button.execute').click();
  await block.locator('.live-responses-table .response-col_status').first().waitFor();
  await page.waitForTimeout(400);
}

async function setBody(block, body) {
  const textarea = block.locator('textarea.body-param__text');
  await textarea.fill(JSON.stringify(body, null, 2));
}

async function setParam(block, value) {
  const input = block.locator('tr[data-param-name="numeroCuenta"] input');
  await input.fill(value);
}

// 1. Vista general
await page.goto(`${BASE_URL}/swagger/index.html`);
await page.locator('.opblock').first().waitFor();
await page.waitForTimeout(500);
await shot('01_swagger_vista_general.png');

// 2. Esquemas
const models = page.locator('section.models');
for (const name of ['ExternalBankLoginRequest', 'ExternalBankLoginResponse', 'ExternalAchTransferCreateRequest', 'ExternalAchCuentaResponse']) {
  const model = models.locator('.model-container').filter({ hasText: name }).first();
  if (await model.count()) {
    await model.locator('button.model-box-control').first().click().catch(() => {});
  }
}
await page.waitForTimeout(400);
await shot('02_swagger_esquemas.png', models);

// 3. Login 200
const login = opblock('post', '/api/external/auth/login');
await expand(login);
await setBody(login, { email: EMAIL, password: PASSWORD });
await execute(login);
const token = await (async () => {
  const response = await fetch(`${BASE_URL}/api/external/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: EMAIL, password: PASSWORD }) });
  return (await response.json()).accessToken;
})();
await shot('03_login_200.png', login);

// 4. Login 401
await setBody(login, { email: EMAIL, password: 'Incorrecta#2026' });
await execute(login);
await shot('04_login_401.png', login);
// restablece intentos fallidos del usuario tecnico con un login correcto
await fetch(`${BASE_URL}/api/external/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: EMAIL, password: PASSWORD }) });
await login.locator('.opblock-summary').first().click();

// 5. Consulta sin token -> 401
const cuenta = opblock('get', '/api/external/ach/cuentas/search/{numeroCuenta}');
await expand(cuenta);
await setParam(cuenta, CUENTA_ACTIVA);
await execute(cuenta);
await shot('05_cuenta_sin_token_401.png', cuenta);

// 6. Authorize
await page.locator('.auth-wrapper button.authorize').click();
const modal = page.locator('.modal-ux');
await modal.locator('input').first().fill(token);
await shot('06_authorize_bearer.png', modal);
await modal.locator('.auth-btn-wrapper button.authorize').click();
await modal.locator('button.btn-done').click();

// 7-9. Consulta de cuenta
await setParam(cuenta, CUENTA_ACTIVA);
await execute(cuenta);
await shot('07_cuenta_200.png', cuenta);
await setParam(cuenta, 'MO-2026-99999');
await execute(cuenta);
await shot('08_cuenta_404.png', cuenta);
await setParam(cuenta, CUENTA_BLOQUEADA);
await execute(cuenta);
await shot('09_cuenta_bloqueada_422.png', cuenta);
await cuenta.locator('.opblock-summary').first().click();

// 10-13. Transferencias
const transfer = opblock('post', '/api/external/ach/transferencias');
await expand(transfer);
const body = {
  codigo_confirmacion: `TRX-SWAGGER-${RUN}-0001`,
  banco_externo: 'DERBANCKS',
  cuenta_externa: '1234567890',
  numeroCuentaDestino: CUENTA_ACTIVA,
  monto: 500.0,
  moneda: 'Q',
  referencia: 'Transferencia ACH entrante',
  tipo: 'entrante'
};
await setBody(transfer, body);
await execute(transfer);
await shot('10_transferencia_201.png', transfer);
await execute(transfer);
await shot('11_transferencia_duplicada_409.png', transfer);
await setBody(transfer, {});
await execute(transfer);
await shot('12_transferencia_invalida_400.png', transfer);
await setBody(transfer, { ...body, codigo_confirmacion: `TRX-SWAGGER-${RUN}-0002`, numeroCuentaDestino: CUENTA_BLOQUEADA });
await execute(transfer);
await shot('13_transferencia_cuenta_bloqueada_422.png', transfer);

await browser.close();
