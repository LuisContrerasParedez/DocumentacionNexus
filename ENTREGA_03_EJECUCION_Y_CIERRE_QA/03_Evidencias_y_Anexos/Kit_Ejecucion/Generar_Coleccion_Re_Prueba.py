"""Genera la colección v2 de re-prueba (cierre E3) a partir de Postman_Collection_QA_Nexus.json sin alterar el original.

Cambios respecto de la colección E2/E3 (todos documentados en el Documento Final, sección 8):
  1. TC-REQ03-002: se automatiza la fila adicional P7-ACH (GET /api/ach/bancos sin token -> 401) que en el ciclo 1
     se verificaba a mano y que hacía fallar el caso por BUG-NEX-01.
  2. TC-REQ16-001: el oráculo deja de buscar solo el texto "4000" y compara cada total con REP01_Totales_Esperados.json.
     En el ciclo 1 esa aserción débil pasaba aunque el reporte omitía la ACH entrante (BUG-NEX-02).
  3. Carpeta nueva "RT · Re-prueba de defectos": confirmación de la corrección de BUG-NEX-01 en las 7 acciones de
     AchBancosController y en AchTransferenciasController, más controles positivos (no regresión de permisos).

Uso: python3 Generar_Coleccion_Re_Prueba.py <coleccion_original.json> <coleccion_v2.json>
"""
import copy
import json
import sys

BANCO_FIXTURE = "e20000000000000000000001"
BANCO_DUPLICATE = "e20000000000000000000005"


def test_script(lines):
    return [{"listen": "test", "script": {"type": "text/javascript", "exec": ["let j={}; try { j=pm.response.json(); } catch(e) { j={}; }", *lines]}}]


def request(name, method, path, token=None, body=None, codes=(401,), extra_tests=(), description=""):
    req = {
        "method": method,
        "url": "{{baseInterna}}" + path,
        "header": [{"key": "Content-Type", "value": "application/json"}] if body is not None else [],
        "auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{" + token + "}}", "type": "string"}]} if token else {"type": "noauth"},
        "description": description,
    }
    if body is not None:
        req["body"] = {"mode": "raw", "raw": json.dumps(body, ensure_ascii=False, indent=2), "options": {"raw": {"language": "json"}}}
    codigos = ", ".join(str(c) for c in codes)
    etiqueta = "/".join(str(c) for c in codes)
    tests = [f'pm.test("{name.split(":")[0]}: HTTP {etiqueta}", ()=>pm.expect(pm.response.code).to.be.oneOf([{codigos}]));', *extra_tests]
    return {"name": name, "request": req, "event": test_script(tests)}


def find(items, prefix):
    for it in items:
        if it["name"].startswith(prefix):
            return it
        if "item" in it:
            r = find(it["item"], prefix)
            if r:
                return r
    return None


def main(origen, destino):
    col = json.load(open(origen, encoding="utf-8"))
    v2 = copy.deepcopy(col)
    v2["info"]["name"] = col["info"]["name"] + " · v2 re-prueba cierre E3"

    # 1. TC-REQ03-002: fila P7-ACH automatizada
    tc0302 = find(v2["item"], "TC-REQ03-002")
    tc0302["item"].append(request(
        "TC-REQ03-002 P7-ACH: sin token → GET /api/ach/bancos",
        "GET", "/api/ach/bancos", codes=(401,),
        extra_tests=['pm.test("TC-REQ03-002 P7-ACH: no expone configuración ACH", ()=>pm.expect(pm.response.text()).to.not.include("apiBaseUrl"));'],
        description="Fila adicional P7 del Pairwise (ciclo 1: HTTP 200 por BUG-NEX-01). Automatizada en la re-prueba."))

    # 2. TC-REQ16-001: oráculo completo contra REP01_Totales_Esperados.json
    tc1601 = find(v2["item"], "TC-REQ16-001")
    resumen = next(i for i in tc1601["item"] if "resumen" in i["request"]["url"])
    esperados = [
        ("totalClientes", 2), ("clientesActivos", 1), ("clientesEnRevision", 1),
        ("totalCuentas", 3), ("cuentasActivas", 2), ("saldoTotal", 4000),
        ("totalTransferenciasInternas", 1), ("montoTransferenciasInternas", 200),
        ("totalAch", 1), ("achAprobadas", 1), ("montoAch", 25),
    ]
    resumen["event"] = test_script(
        ['pm.test("TC-REQ16-001: HTTP 200", ()=>pm.expect(pm.response.code).to.be.oneOf([200]));']
        + [f'pm.test("TC-REQ16-001: {k} = {v}", ()=>pm.expect(Number(j.{k})).to.eql({v}));' for k, v in esperados])

    # 3. Carpeta RT de re-prueba de defectos
    sin_token = [
        request("RT-01-01: sin token → GET /api/ach/bancos", "GET", "/api/ach/bancos"),
        request("RT-01-02: sin token → GET /api/ach/bancos/activos", "GET", "/api/ach/bancos/activos"),
        request("RT-01-03: sin token → GET /api/ach/bancos/{id}", "GET", f"/api/ach/bancos/{BANCO_FIXTURE}"),
        request("RT-01-04: sin token → POST /api/ach/bancos", "POST", "/api/ach/bancos",
                body={"nombre": "Banco anonimo", "codigo": "RT_ANONIMO", "apiBaseUrl": "http://mock-bank:8081", "apiEndpoint": "/success/transferencias"}),
        request("RT-01-05: sin token → PUT /api/ach/bancos/{id}", "PUT", f"/api/ach/bancos/{BANCO_FIXTURE}",
                body={"nombre": "Alterado sin token", "codigo": "E2_QA_SUCCESS"}),
        request("RT-01-06: sin token → PATCH /api/ach/bancos/{id}/estado", "PATCH", f"/api/ach/bancos/{BANCO_FIXTURE}/estado", body={"activo": False}),
        request("RT-01-07: sin token → DELETE /api/ach/bancos/{id}", "DELETE", f"/api/ach/bancos/{BANCO_DUPLICATE}"),
        request("RT-01-08: sin token → GET /api/ach/transferencias", "GET", "/api/ach/transferencias"),
        request("RT-01-09: sin token → POST /api/ach/transferencias/enviar", "POST", "/api/ach/transferencias/enviar",
                body={"bancoAchId": BANCO_FIXTURE, "cuentaOrigenId": "60e12f09-f1be-5506-b494-5381502e3e75", "numeroCuentaDestino": "EXT-QA-0001", "monto": 1, "descripcion": "RT sin token"}),
    ]
    sin_permiso = [
        request("RT-01-10: CLIENTE → GET /api/ach/bancos", "GET", "/api/ach/bancos", token="token_ana", codes=(403,)),
        request("RT-01-11: CAJERO → POST /api/ach/bancos", "POST", "/api/ach/bancos", token="token_cajero", codes=(403,),
                body={"nombre": "Banco cajero", "codigo": "RT_CAJERO", "apiBaseUrl": "http://mock-bank:8081", "apiEndpoint": "/success/transferencias"}),
        request("RT-01-12: CAJERO → DELETE /api/ach/bancos/{id}", "DELETE", f"/api/ach/bancos/{BANCO_DUPLICATE}", token="token_cajero", codes=(403,)),
        request("RT-01-13: CLIENTE → PATCH /api/ach/bancos/{id}/estado", "PATCH", f"/api/ach/bancos/{BANCO_FIXTURE}/estado", token="token_ana", codes=(403,), body={"activo": False}),
        request("RT-01-14: BANCO_EXTERNO (JWT público) → GET /api/ach/bancos", "GET", "/api/ach/bancos", token="token_externo", codes=(401, 403)),
    ]
    positivos = [
        request("RT-01-15: ADMIN → GET /api/ach/bancos", "GET", "/api/ach/bancos", token="token_admin", codes=(200,),
                extra_tests=['pm.test("RT-01-15: lista los 5 bancos simulados", ()=>pm.expect(j.filter(b=>String(b.codigo).startsWith("E2_QA_")).length).to.eql(5));']),
        request("RT-01-16: CAJERO → GET /api/ach/bancos/activos", "GET", "/api/ach/bancos/activos", token="token_cajero", codes=(200,)),
        request("RT-01-17: CLIENTE (portal) → GET /api/ach/bancos/activos", "GET", "/api/ach/bancos/activos", token="token_ana", codes=(200,)),
        request("RT-01-18: CLIENTE (portal) → GET /api/ach/transferencias", "GET", "/api/ach/transferencias", token="token_ana", codes=(200,)),
    ]
    rt = {
        "name": "RT · Re-prueba de defectos (cierre E3)",
        "description": "Confirmación de la corrección de BUG-NEX-01 (9 accesos sin token, 5 con rol sin permiso, 4 controles positivos). "
                       "BUG-NEX-02 se re-prueba con TC-REQ16-001 (oráculo completo) sobre bancoerp_e2_qa_rep01.",
        "item": [
            {"name": "RT-BUG-NEX-01 · Sin token → 401", "item": sin_token},
            {"name": "RT-BUG-NEX-01 · Rol sin permiso → 403", "item": sin_permiso},
            {"name": "RT-BUG-NEX-01 · Controles positivos (no regresión)", "item": positivos},
        ],
    }
    v2["item"].append(rt)
    json.dump(v2, open(destino, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"Colección v2 escrita en {destino}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
