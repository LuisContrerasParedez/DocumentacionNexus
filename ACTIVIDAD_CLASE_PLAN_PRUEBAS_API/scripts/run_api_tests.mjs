#!/usr/bin/env node
// Runner automatizado del Plan de Pruebas - Banco ERP Public API (ACH entrante).
// Requiere Node 18+ (fetch nativo) y el contenedor postgres de docker compose para las verificaciones en BD.
//
// Variables de entorno (no se escriben secretos en el codigo ni en la evidencia):
//   BASE_URL                 default http://localhost:5254
//   BANCO_EXTERNO_EMAIL      default bancoexterno@nexus.com
//   BANCO_EXTERNO_PASSWORD   obligatorio (credencial del usuario tecnico)
//   QA_PASSWORD              obligatorio (credencial de los usuarios QA creados por 01_preparar_datos_qa.sql)
//   PG_CONTAINER             default bancoerp-dev-postgres-1
//
// Uso: ./run_api_tests.sh   (carga credenciales desde .env.local)  o  node run_api_tests.mjs

import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:5254';
const EXT_EMAIL = process.env.BANCO_EXTERNO_EMAIL ?? 'bancoexterno@nexus.com';
const EXT_PASSWORD = required('BANCO_EXTERNO_PASSWORD');
const QA_PASSWORD = required('QA_PASSWORD');
const PG_CONTAINER = process.env.PG_CONTAINER ?? 'bancoerp-dev-postgres-1';

const CUENTA_ACTIVA = 'MO260803936604';
const CUENTA_ACTIVA_2 = 'AH260730742944';
const CUENTA_BLOQUEADA = 'AH260901838371';
const CUENTA_INEXISTENTE = 'MO-2026-99999';

const RUN_ID = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'evidencias', 'resultados');
mkdirSync(outDir, { recursive: true });

const results = [];
const logLines = [];
let token = null;

function required(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Falta la variable de entorno ${name}.`);
    process.exit(2);
  }
  return value;
}

function log(line) {
  logLines.push(line);
  console.log(line);
}

function mask(value) {
  if (typeof value !== 'string') return value;
  return value.replace(/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, (jwt) => `${jwt.slice(0, 16)}...(JWT ${jwt.length} chars)`);
}

function sanitizeBody(body) {
  if (body && typeof body === 'object' && 'password' in body) {
    return { ...body, password: body.password ? '******' : body.password };
  }
  return body;
}

function sql(query) {
  return execFileSync('docker', ['exec', PG_CONTAINER, 'psql', '-U', 'bancoerp', '-d', 'bancoerp', '-At', '-F', '|', '-c', query], {
    encoding: 'utf8'
  }).trim();
}

function saldo(numeroCuenta) {
  return Number(sql(`SELECT saldo FROM cuentas.cuentas WHERE numero_cuenta = '${numeroCuenta}'`));
}

function codigo(suffix) {
  return `TRX-QA-${RUN_ID}-${suffix}`;
}

async function call({ method, path, body, rawBody, headers = {}, auth = true, authToken }) {
  const finalHeaders = { Accept: 'application/json', ...headers };
  const bearer = authToken ?? (auth ? token : null);
  if (bearer) finalHeaders.Authorization = `Bearer ${bearer}`;
  let payload;
  if (rawBody !== undefined) {
    payload = rawBody;
  } else if (body !== undefined) {
    payload = JSON.stringify(body);
    finalHeaders['Content-Type'] ??= 'application/json';
  }

  const started = performance.now();
  const response = await fetch(`${BASE_URL}${path}`, { method, headers: finalHeaders, body: payload });
  const elapsedMs = Math.round(performance.now() - started);
  const text = await response.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* respuesta no JSON */ }
  return { status: response.status, json, text, elapsedMs, contentType: response.headers.get('content-type') };
}

async function test(meta, fn) {
  const record = { ...meta, checks: [], result: 'Pass', observaciones: '' };
  try {
    const ctx = {
      check(description, condition, detail) {
        record.checks.push({ description, ok: Boolean(condition), detail: detail === undefined ? undefined : mask(String(detail)) });
        if (!condition) record.result = 'Fail';
      },
      note(text) { record.observaciones = record.observaciones ? `${record.observaciones} ${text}` : text; },
      exchange(request, response) {
        record.request = {
          method: request.method,
          url: `${BASE_URL}${request.path}`,
          auth: request.authToken ? 'Bearer (token de prueba)' : request.auth === false ? 'sin token' : 'Bearer {token}',
          body: request.rawBody !== undefined ? request.rawBody : sanitizeBody(request.body)
        };
        record.response = { status: response.status, elapsedMs: response.elapsedMs, body: response.json ?? response.text };
        record.actualStatus = response.status;
        record.elapsedMs = response.elapsedMs;
      },
      async send(request) {
        const response = await call(request);
        ctx.exchange(request, response);
        return response;
      }
    };
    await fn(ctx);
  } catch (error) {
    record.result = 'Blocked';
    record.observaciones = `Bloqueado: ${error.message}`;
  }
  const marker = record.result === 'Pass' ? 'PASS' : record.result === 'Fail' ? 'FAIL' : 'BLOCKED';
  log(`[${marker}] ${record.id} ${record.titulo} -> HTTP ${record.actualStatus ?? '-'} (${record.elapsedMs ?? '-'} ms)`);
  for (const c of record.checks.filter((c) => !c.ok)) log(`        x ${c.description}${c.detail ? ` | ${c.detail}` : ''}`);
  if (record.observaciones) log(`        obs: ${record.observaciones}`);
  results.push(record);
}

const isJwt = (value) => typeof value === 'string' && value.split('.').length === 3;

// ------------------------------------------------------------------ casos
async function run() {
  log(`Ejecucion ${RUN_ID} contra ${BASE_URL} - ${new Date().toISOString()}`);

  await test({ id: 'TC-01', titulo: 'Disponibilidad /api/Home', endpoint: 'GET /api/Home', tipo: 'Funcional', esperado: 200 }, async (t) => {
    const r = await t.send({ method: 'GET', path: '/api/Home', auth: false });
    t.check('HTTP 200', r.status === 200, r.status);
    t.check('estado = Conectado', r.json?.estado === 'Conectado', r.json?.estado);
    t.check('incluye fecha', Boolean(r.json?.fecha));
  });

  await test({ id: 'TC-02', titulo: 'Login con usuario tecnico valido', endpoint: 'POST /api/external/auth/login', tipo: 'Funcional', esperado: 200 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: EXT_EMAIL, password: EXT_PASSWORD } });
    t.check('HTTP 200', r.status === 200, r.status);
    t.check('accessToken es JWT', isJwt(r.json?.accessToken));
    t.check('tokenType = Bearer', r.json?.tokenType === 'Bearer', r.json?.tokenType);
    const minutes = (new Date(r.json?.expiresAt) - Date.now()) / 60000;
    t.check('expiresAt en el futuro (<= 60 min)', minutes > 0 && minutes <= 61, `${minutes.toFixed(1)} min`);
    token = r.json?.accessToken ?? null;
  });

  await test({ id: 'TC-03', titulo: 'Login con contrasena incorrecta', endpoint: 'POST /api/external/auth/login', tipo: 'Negativa / Seguridad', esperado: 401 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: 'qa.externo.bloqueo@test.com', password: 'Incorrecta#1' } });
    t.check('HTTP 401', r.status === 401, r.status);
    t.check('status = false', r.json?.status === false);
    t.check('mensaje indica intento 1 de 5', /Intento 1 de 5/.test(r.json?.message ?? ''), r.json?.message);
    t.check('no devuelve token', !r.json?.accessToken);
  });

  await test({ id: 'TC-04', titulo: 'Login con usuario inexistente', endpoint: 'POST /api/external/auth/login', tipo: 'Negativa / Seguridad', esperado: 401 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: 'noexiste@banco.com', password: 'Cualquier#1' } });
    t.check('HTTP 401', r.status === 401, r.status);
    t.check('mensaje generico (no revela si el usuario existe)', r.json?.message === 'Credenciales incorrectas.', r.json?.message);
  });

  await test({ id: 'TC-05', titulo: 'Login con campos vacios', endpoint: 'POST /api/external/auth/login', tipo: 'Negativa / Validacion', esperado: 400 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: '', password: '' } });
    t.check('HTTP 400', r.status === 400, r.status);
    t.check('mensaje de campos requeridos', /requeridos/i.test(r.json?.message ?? ''), r.json?.message);
  });

  await test({ id: 'TC-06', titulo: 'Login con JSON malformado', endpoint: 'POST /api/external/auth/login', tipo: 'Manejo de errores', esperado: 400 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, rawBody: '{"email": "bancoexterno@nexus.com", "password": ', headers: { 'Content-Type': 'application/json' } });
    t.check('HTTP 400', r.status === 400, r.status);
    t.check('respuesta no expone stack trace', !/at BancoERP|Exception/.test(r.text), r.text.slice(0, 120));
    if (r.json && !('status' in r.json && 'message' in r.json)) {
      t.note('Responde con ProblemDetails de ASP.NET (title/errors) en lugar del contrato {status,message,errors}.');
    }
  });

  await test({ id: 'TC-07', titulo: 'Login de usuario inactivo', endpoint: 'POST /api/external/auth/login', tipo: 'Seguridad (autorizacion)', esperado: 403 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: 'qa.externo.inactivo@test.com', password: QA_PASSWORD } });
    t.check('HTTP 403', r.status === 403, r.status);
    t.check('mensaje usuario inactivo', /inactivo/i.test(r.json?.message ?? ''), r.json?.message);
  });

  await test({ id: 'TC-08', titulo: 'Login de usuario sin rol BANCO_EXTERNO', endpoint: 'POST /api/external/auth/login', tipo: 'Seguridad (autorizacion)', esperado: 403 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: 'qa.sin.rol@test.com', password: QA_PASSWORD } });
    t.check('HTTP 403', r.status === 403, r.status);
    t.check('mensaje no autorizado', /no esta autorizado/i.test(r.json?.message ?? ''), r.json?.message);
    t.check('no devuelve token', !r.json?.accessToken);
  });

  await test({ id: 'TC-09', titulo: 'Bloqueo tras 5 intentos fallidos', endpoint: 'POST /api/external/auth/login', tipo: 'Seguridad', esperado: 423 }, async (t) => {
    const statuses = [];
    for (let i = 2; i <= 5; i++) {
      const r = await call({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: 'qa.externo.bloqueo@test.com', password: 'Incorrecta#1' } });
      statuses.push(r.status);
      if (i === 5) t.check('5to intento informa bloqueo', /bloqueado/i.test(r.json?.message ?? ''), r.json?.message);
    }
    t.check('intentos 2-5 devuelven 401', statuses.every((s) => s === 401), statuses.join(','));
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: 'qa.externo.bloqueo@test.com', password: QA_PASSWORD } });
    t.check('login con contrasena correcta devuelve 423', r.status === 423, r.status);
    t.check('mensaje usuario bloqueado', /bloqueado/i.test(r.json?.message ?? ''), r.json?.message);
    const bloqueadoHasta = sql(`SELECT bloqueado || '|' || COALESCE(bloqueado_hasta::text, '') FROM seguridad.usuarios WHERE email = 'qa.externo.bloqueo@test.com'`);
    t.check('BD: usuario marcado como bloqueado con bloqueado_hasta', bloqueadoHasta.startsWith('true|2'), bloqueadoHasta);
  });

  await test({ id: 'TC-10', titulo: 'Login con intento de inyeccion SQL', endpoint: 'POST /api/external/auth/login', tipo: 'Seguridad', esperado: 401 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: "' OR '1'='1' --", password: "' OR '1'='1" } });
    t.check('HTTP 401', r.status === 401, r.status);
    t.check('no devuelve token', !r.json?.accessToken);
  });

  // --------------------------------------------------------------- cuentas
  await test({ id: 'TC-11', titulo: 'Consulta de cuenta destino activa', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Funcional', esperado: 200 }, async (t) => {
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA}` });
    t.check('HTTP 200', r.status === 200, r.status);
    t.check('status = true y mensaje "Cuenta encontrada."', r.json?.status === true && r.json?.message === 'Cuenta encontrada.', r.json?.message);
    const d = r.json?.data ?? {};
    t.check('esquema data completo', ['numeroCuenta', 'nombreTitular', 'moneda', 'estado', 'puedeRecibirTransferencias'].every((k) => k in d), Object.keys(d).join(','));
    t.check('estado ACTIVA, moneda Q, puedeRecibirTransferencias = true', d.estado === 'ACTIVA' && d.moneda === 'Q' && d.puedeRecibirTransferencias === true, JSON.stringify(d));
  });

  await test({ id: 'TC-12', titulo: 'Consulta de cuenta en minusculas (normalizacion)', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Funcional', esperado: 200 }, async (t) => {
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA.toLowerCase()}` });
    t.check('HTTP 200', r.status === 200, r.status);
    t.check('devuelve numero normalizado en mayusculas', r.json?.data?.numeroCuenta === CUENTA_ACTIVA, r.json?.data?.numeroCuenta);
  });

  await test({ id: 'TC-13', titulo: 'Consulta de cuenta inexistente', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Negativa', esperado: 404 }, async (t) => {
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_INEXISTENTE}` });
    t.check('HTTP 404', r.status === 404, r.status);
    t.check('mensaje "Cuenta no encontrada."', r.json?.message === 'Cuenta no encontrada.', r.json?.message);
  });

  await test({ id: 'TC-14', titulo: 'Consulta de cuenta BLOQUEADA', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Negativa / Regla de negocio', esperado: 422 }, async (t) => {
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_BLOQUEADA}` });
    t.check('HTTP 422', r.status === 422, r.status);
    t.check('mensaje cuenta no apta', /no puede recibir/i.test(r.json?.message ?? ''), r.json?.message);
    t.check('no expone datos del titular', !r.json?.data);
  });

  await test({ id: 'TC-15', titulo: 'Consulta de cuenta sin token', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Seguridad (autenticacion)', esperado: 401 }, async (t) => {
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA}`, auth: false });
    t.check('HTTP 401', r.status === 401, r.status);
    t.check('no expone datos de la cuenta', !r.text.includes(CUENTA_ACTIVA));
  });

  await test({ id: 'TC-16', titulo: 'Consulta de cuenta con token alterado', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Seguridad (autenticacion)', esperado: 401 }, async (t) => {
    const [h, p, s] = token.split('.');
    const forged = `${h}.${p}.${s.slice(0, -4)}${s.slice(-4) === 'AAAA' ? 'BBBB' : 'AAAA'}`;
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA}`, authToken: forged });
    t.check('HTTP 401', r.status === 401, r.status);
  });

  await test({ id: 'TC-17', titulo: 'Consulta con token de sesion revocada', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Seguridad (autenticacion)', esperado: 401 }, async (t) => {
    const login = await call({ method: 'POST', path: '/api/external/auth/login', auth: false, body: { email: EXT_EMAIL, password: EXT_PASSWORD } });
    const tempToken = login.json.accessToken;
    const sid = JSON.parse(Buffer.from(tempToken.split('.')[1], 'base64url').toString()).sid;
    sql(`UPDATE seguridad.sesiones SET estado = FALSE, fecha_cierre = NOW() WHERE id = '${sid}'`);
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA}`, authToken: tempToken });
    t.check('HTTP 401 con sesion revocada', r.status === 401, r.status);
  });

  await test({ id: 'TC-18', titulo: 'Consulta con intento de inyeccion SQL', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Seguridad', esperado: 404 }, async (t) => {
    const r = await t.send({ method: 'GET', path: `/api/external/ach/cuentas/search/${encodeURIComponent("X' OR '1'='1")}` });
    t.check('HTTP 404', r.status === 404, r.status);
    t.check('no devuelve datos de otra cuenta', !r.json?.data);
  });

  // --------------------------------------------------------- transferencias
  await test({ id: 'TC-19', titulo: 'Transferencia ACH entrante valida', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Funcional', esperado: 201 }, async (t) => {
    const code = codigo('0001');
    const before = saldo(CUENTA_ACTIVA);
    const body = { codigo_confirmacion: code, banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: 500.0, moneda: 'Q', referencia: 'Transferencia ACH entrante', tipo: 'entrante' };
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body });
    t.check('HTTP 201', r.status === 201, r.status);
    const d = r.json?.data ?? {};
    t.check('estado APROBADA', d.estado === 'APROBADA', d.estado);
    t.check('codigoConfirmacion y monto coinciden', d.codigoConfirmacion === code && Number(d.monto) === 500, JSON.stringify(d));
    t.check('moneda en formato de la guia (Q)', d.moneda === 'Q', d.moneda);
    const after = saldo(CUENTA_ACTIVA);
    t.check('BD: saldo acreditado +500.00', Math.abs(after - before - 500) < 0.001, `${before} -> ${after}`);
    const mov = sql(`SELECT m.tipo || '|' || m.monto || '|' || (SELECT count(*) FROM contabilidad.asientos a WHERE a.movimiento_id = m.id) FROM ach.transferencias_entrantes te JOIN transacciones.movimientos m ON m.id = te.movimiento_id WHERE te.codigo_confirmacion = '${code}'`);
    const [tipoMov, montoMov, asientos] = mov.split('|');
    t.check('BD: movimiento ACH_IN registrado', tipoMov === 'ACH_IN' && Number(montoMov) === 500, mov);
    t.check('BD: asiento contable de partida doble (>= 2 lineas)', Number(asientos) >= 2, `${asientos} lineas`);
    const evento = sql(`SELECT count(*) FROM seguridad.eventos_seguridad WHERE descripcion LIKE '%${code}%' AND exitoso`);
    t.check('BD: evento de auditoria exitoso', Number(evento) >= 1, evento);
    t.note(`Saldo ${CUENTA_ACTIVA}: ${before.toFixed(2)} -> ${after.toFixed(2)}.`);
  });

  await test({ id: 'TC-20', titulo: 'Transferencia duplicada (idempotencia)', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Regla de negocio', esperado: 409 }, async (t) => {
    const code = codigo('0001');
    const before = saldo(CUENTA_ACTIVA);
    const body = { codigo_confirmacion: code, banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: 500.0, moneda: 'Q', tipo: 'entrante' };
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body });
    t.check('HTTP 409', r.status === 409, r.status);
    t.check('errors.codigo_confirmacion presente', Array.isArray(r.json?.errors?.codigo_confirmacion), JSON.stringify(r.json?.errors));
    t.check('BD: saldo sin cambios', saldo(CUENTA_ACTIVA) === before);
  });

  await test({ id: 'TC-21', titulo: 'Transferencia con body vacio', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Validacion', esperado: 400 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: {} });
    t.check('HTTP 400', r.status === 400, r.status);
    const keys = Object.keys(r.json?.errors ?? {});
    const expected = ['codigo_confirmacion', 'banco_externo', 'cuenta_externa', 'numeroCuentaDestino', 'monto', 'moneda'];
    t.check('errors lista los 6 campos obligatorios', expected.every((k) => keys.includes(k)), keys.join(','));
  });

  await test({ id: 'TC-22', titulo: 'Transferencia con monto 0', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Validacion', esperado: 400 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0022'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: 0, moneda: 'Q' } });
    t.check('HTTP 400', r.status === 400, r.status);
    t.check('errors.monto presente', Boolean(r.json?.errors?.monto), JSON.stringify(r.json?.errors));
  });

  await test({ id: 'TC-23', titulo: 'Transferencia con monto negativo', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Validacion', esperado: 400 }, async (t) => {
    const before = saldo(CUENTA_ACTIVA);
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0023'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: -100, moneda: 'Q' } });
    t.check('HTTP 400', r.status === 400, r.status);
    t.check('BD: saldo sin cambios', saldo(CUENTA_ACTIVA) === before);
  });

  await test({ id: 'TC-24', titulo: 'Transferencia con moneda no soportada (USD)', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Regla de negocio', esperado: 422 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0024'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: 100, moneda: 'USD' } });
    t.check('HTTP 422 (guia seccion 8: moneda invalida)', r.status === 422, r.status);
    t.check('errors.moneda presente', Boolean(r.json?.errors?.moneda), JSON.stringify(r.json?.errors));
  });

  await test({ id: 'TC-25', titulo: 'Transferencia con tipo distinto de entrante', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Validacion', esperado: 400 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0025'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: 100, moneda: 'Q', tipo: 'saliente' } });
    t.check('HTTP 400', r.status === 400, r.status);
    t.check('errors.tipo presente', Boolean(r.json?.errors?.tipo), JSON.stringify(r.json?.errors));
  });

  await test({ id: 'TC-26', titulo: 'Transferencia a cuenta inexistente', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa', esperado: 404 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0026'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_INEXISTENTE, monto: 100, moneda: 'Q' } });
    t.check('HTTP 404', r.status === 404, r.status);
  });

  await test({ id: 'TC-27', titulo: 'Transferencia a cuenta BLOQUEADA', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Regla de negocio', esperado: 422 }, async (t) => {
    const before = saldo(CUENTA_BLOQUEADA);
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0027'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_BLOQUEADA, monto: 100, moneda: 'Q' } });
    t.check('HTTP 422', r.status === 422, r.status);
    t.check('BD: saldo de la cuenta bloqueada sin cambios', saldo(CUENTA_BLOQUEADA) === before);
  });

  await test({ id: 'TC-28', titulo: 'Transferencia sin token', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Seguridad (autenticacion)', esperado: 401 }, async (t) => {
    const before = saldo(CUENTA_ACTIVA);
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', auth: false, body: { codigo_confirmacion: codigo('0028'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA, monto: 100, moneda: 'Q' } });
    t.check('HTTP 401', r.status === 401, r.status);
    t.check('BD: saldo sin cambios', saldo(CUENTA_ACTIVA) === before);
  });

  await test({ id: 'TC-29', titulo: 'Transferencia con monto como texto y moneda GTQ', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Funcional', esperado: 201 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0029'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA_2, monto: '150.75', moneda: 'GTQ' } });
    t.check('HTTP 201', r.status === 201, r.status);
    t.check('monto 150.75 y moneda normalizada a Q', Number(r.json?.data?.monto) === 150.75 && r.json?.data?.moneda === 'Q', JSON.stringify(r.json?.data));
  });

  await test({ id: 'TC-30', titulo: 'Transferencia con monto de 3 decimales', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Negativa / Validacion', esperado: 400 }, async (t) => {
    const before = saldo(CUENTA_ACTIVA_2);
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0030'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA_2, monto: 10.555, moneda: 'Q' } });
    t.check('HTTP 400 (monto monetario con mas de 2 decimales)', r.status === 400, r.status);
    const delta = +(saldo(CUENTA_ACTIVA_2) - before).toFixed(3);
    t.check('BD: no se acredita un monto distinto al enviado', delta === 0 || delta === 10.555, `delta=${delta}`);
  });

  await test({ id: 'TC-31', titulo: 'Transferencia con monto fuera de rango numerico', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Manejo de errores', esperado: 400 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', body: { codigo_confirmacion: codigo('0031'), banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA_2, monto: 100000000000000000, moneda: 'Q' } });
    t.check('HTTP 400 controlado', r.status === 400, r.status);
    t.check('no expone mensajes internos de base de datos', !/numeric|overflow|precision|postgres/i.test(r.text), r.text.slice(0, 160));
  });

  await test({ id: 'TC-32', titulo: 'Envio concurrente del mismo codigo (5 solicitudes)', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Regla de negocio / Concurrencia', esperado: '1x201 + 4x409' }, async (t) => {
    const code = codigo('0032');
    const before = saldo(CUENTA_ACTIVA_2);
    const body = { codigo_confirmacion: code, banco_externo: 'DERBANCKS', cuenta_externa: '1234567890', numeroCuentaDestino: CUENTA_ACTIVA_2, monto: 25, moneda: 'Q' };
    const responses = await Promise.all(Array.from({ length: 5 }, () => call({ method: 'POST', path: '/api/external/ach/transferencias', body })));
    const statuses = responses.map((r) => r.status).sort();
    t.exchange({ method: 'POST', path: '/api/external/ach/transferencias', body }, { status: statuses.join(','), elapsedMs: Math.max(...responses.map((r) => r.elapsedMs)), json: { statuses } });
    t.check('exactamente una 201', statuses.filter((s) => s === 201).length === 1, statuses.join(','));
    t.check('las demas 409', statuses.filter((s) => s === 409).length === 4, statuses.join(','));
    const delta = +(saldo(CUENTA_ACTIVA_2) - before).toFixed(2);
    t.check('BD: saldo acreditado una sola vez (+25.00)', delta === 25, `delta=${delta}`);
  });

  // ---------------------------------------------------- manejo de errores
  await test({ id: 'TC-33', titulo: 'Metodo HTTP no soportado', endpoint: 'DELETE /api/external/ach/transferencias', tipo: 'Manejo de errores', esperado: 405 }, async (t) => {
    const r = await t.send({ method: 'DELETE', path: '/api/external/ach/transferencias' });
    t.check('HTTP 405', r.status === 405, r.status);
  });

  await test({ id: 'TC-34', titulo: 'Content-Type no soportado', endpoint: 'POST /api/external/ach/transferencias', tipo: 'Manejo de errores', esperado: 415 }, async (t) => {
    const r = await t.send({ method: 'POST', path: '/api/external/ach/transferencias', rawBody: 'monto=100', headers: { 'Content-Type': 'text/plain' } });
    t.check('HTTP 415', r.status === 415, r.status);
  });

  await test({ id: 'TC-35', titulo: 'Tiempo de respuesta de consulta de cuenta (20 llamadas)', endpoint: 'GET /api/external/ach/cuentas/search/{numeroCuenta}', tipo: 'Rendimiento basico', esperado: 'p95 < 500 ms' }, async (t) => {
    const times = [];
    for (let i = 0; i < 20; i++) {
      const r = await call({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA}` });
      if (r.status !== 200) throw new Error(`respuesta ${r.status}`);
      times.push(r.elapsedMs);
    }
    times.sort((a, b) => a - b);
    const p95 = times[Math.ceil(0.95 * times.length) - 1];
    const avg = Math.round(times.reduce((a, b) => a + b, 0) / times.length);
    t.exchange({ method: 'GET', path: `/api/external/ach/cuentas/search/${CUENTA_ACTIVA}` }, { status: 200, elapsedMs: p95, json: { muestras: times.length, promedioMs: avg, p95Ms: p95, maxMs: times.at(-1) } });
    t.check('p95 < 500 ms', p95 < 500, `p95=${p95} ms, promedio=${avg} ms`);
    t.note(`Promedio ${avg} ms, p95 ${p95} ms, max ${times.at(-1)} ms.`);
  });

  // ---------------------------------------------------------------- salida
  const summary = {
    runId: RUN_ID,
    baseUrl: BASE_URL,
    fecha: new Date().toISOString(),
    total: results.length,
    pass: results.filter((r) => r.result === 'Pass').length,
    fail: results.filter((r) => r.result === 'Fail').length,
    blocked: results.filter((r) => r.result === 'Blocked').length
  };
  log(`\nResumen: ${summary.total} ejecutados | ${summary.pass} Pass | ${summary.fail} Fail | ${summary.blocked} Blocked`);

  writeFileSync(join(outDir, 'resultados_ejecucion.json'), JSON.stringify({ summary, results }, (k, v) => (typeof v === 'string' ? mask(v) : v), 2));
  writeFileSync(join(outDir, 'ejecucion.log'), logLines.join('\n') + '\n');
  process.exitCode = summary.fail || summary.blocked ? 1 : 0;
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
