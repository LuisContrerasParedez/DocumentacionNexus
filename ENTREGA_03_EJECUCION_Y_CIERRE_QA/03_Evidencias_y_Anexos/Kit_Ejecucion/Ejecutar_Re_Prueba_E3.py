"""Ejecutar_Re_Prueba_E3.py — Ciclo 2 de la Entrega 3 (re-prueba de BUG-NEX-01/02 y regresión completa).

Ejecuta, sobre el entorno QA aislado y la build corregida:
  0. Smoke de servicios.
  1. Re-prueba (confirmation testing) de BUG-NEX-01: carpeta RT + TC-REQ03-002, con instantánea de Mongo antes/después.
  2. Regresión completa de los 46 casos (incluye los 30 P1) en el orden de la guía E3, con los pasos manuales
     de la sección 3 de Guia_Ejecucion_E3.md automatizados y verificación SQL ANTES/DESPUÉS de cada caso.
  3. Re-prueba de BUG-NEX-02: TC-REQ16-001 con oráculo completo sobre la BD aislada bancoerp_e2_qa_rep01.
  4. Control cruzado del reporte contra SQL en la BD principal.

Requisitos: Docker, Node.js + newman 6.2.3, Python 3, mongosh. Entorno levantado con:
  docker compose -p bancoerp-e3-retest -f docker-compose.qa.yml up -d   (carpeta 03_Evidencias_y_MockData de la E2)
Uso: python3 -I Ejecutar_Re_Prueba_E3.py <carpeta_03_Evidencias_y_Anexos> <carpeta_compose_E2>
"""
import datetime as dt
import json
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

EVID = Path(sys.argv[1]).resolve()
COMPOSE_DIR = Path(sys.argv[2]).resolve()
PROYECTO = "bancoerp-e3-retest"
PG = f"{PROYECTO}-postgres-1"
RP = EVID / "Re_Prueba_Cierre_E3"
DATOS = EVID / "Readiness_y_MockData_E2"
COLECCION = json.load(open(RP / "Postman_Collection_QA_Nexus_v2_Re_Prueba.json", encoding="utf-8"))
TRABAJO = Path("/private/tmp") / "e3-reprueba-trabajo"
TRABAJO.mkdir(parents=True, exist_ok=True)
LOG = RP / "Re_Prueba_y_Regresion_pasos.txt"
TZ_GT = dt.timezone(dt.timedelta(hours=-6), "CST")
JWT = re.compile(r"eyJ[\w-]+\.[\w-]+\.[\w-]+")
REFRESH = re.compile(r'("refresh[Tt]oken"\s*:\s*")[^"]+(")')
resultados = []  # (fase, tag, requests, assertions, fallidas)


def ahora():
    return dt.datetime.now(TZ_GT).strftime("%Y-%m-%d %H:%M:%S %Z")


def log(texto):
    linea = f"== {ahora()} {texto}" if not texto.startswith("   ") else texto
    print(linea, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(linea + "\n")


def redactar(texto):
    return REFRESH.sub(r"\1<refresh-redactado>\2", JWT.sub("<JWT-redactado>", texto))


def psql(sql, db="bancoerp_e2_qa", tuples=False):
    args = ["docker", "exec", "-i", PG, "psql", "-U", "e2qa", "-d", db, "-v", "ON_ERROR_STOP=1"]
    if tuples:
        args += ["-tA"]
    r = subprocess.run(args, input=sql, text=True, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"psql falló: {r.stderr}")
    return r.stdout.strip()


def mongo(js):
    r = subprocess.run(["mongosh", "mongodb://127.0.0.1:17017/bancoerp_e2_qa", "--quiet", "--eval", js], text=True, capture_output=True)
    return (r.stdout or r.stderr).strip()


def seccion_fixture(desde, hasta):
    lineas = (DATOS / "MockData_Fixtures_Nexus.sql").read_text(encoding="utf-8").splitlines()
    i = next(n for n, l in enumerate(lineas) if l.startswith(desde))
    j = next(n for n, l in enumerate(lineas) if l.startswith(hasta) and n > i)
    return "\n".join(lineas[i:j])


SECCION_4_5 = "BEGIN;\n" + seccion_fixture("-- 4.", "COMMIT;") + "\nCOMMIT;"
SECCION_5 = "BEGIN;\n" + seccion_fixture("-- 5.", "COMMIT;") + "\nCOMMIT;"
RESET_BLOQUEO = "UPDATE seguridad.usuarios SET estado=true, bloqueado=false, bloqueado_hasta=NULL, intentos_fallidos=0 WHERE username='qa_bloqueo';"
RETIRAR_PERMISOS_EXT = """CREATE TABLE IF NOT EXISTS public.qa_respaldo_roles_permisos AS SELECT rp.* FROM seguridad.roles_permisos rp JOIN seguridad.roles r ON r.id=rp.rol_id JOIN seguridad.permisos p ON p.id=rp.permiso_id
  WHERE r.codigo='BANCO_EXTERNO' AND p.codigo IN ('ach.public.cuentas.consultar','ach.public.transferencias.crear');
SELECT count(*) AS respaldados FROM public.qa_respaldo_roles_permisos;
DELETE FROM seguridad.roles_permisos rp USING public.qa_respaldo_roles_permisos b WHERE rp.rol_id=b.rol_id AND rp.permiso_id=b.permiso_id;"""
RESTAURAR_PERMISOS_EXT = "INSERT INTO seguridad.roles_permisos SELECT * FROM public.qa_respaldo_roles_permisos; DROP TABLE public.qa_respaldo_roles_permisos;"

SQL_ESTADO = """\\pset footer on
SELECT numero_cuenta, estado, saldo, saldo_disponible, saldo_minimo, limite_retiro_diario, monto_retirado_hoy
FROM cuentas.cuentas WHERE numero_cuenta ~ '^(AH|MO)26100200(01|02)' ORDER BY numero_cuenta;
SELECT u.username, s.fecha, s.estado, s.fondo_inicial, s.total_depositos, s.total_retiros,
       s.fondo_inicial + s.total_depositos - s.total_retiros AS efectivo_esperado, s.efectivo_contado, s.diferencia,
       to_char(s.hora_apertura,'HH24:MI:SS') AS abre, to_char(s.hora_cierre,'HH24:MI:SS') AS cierra
FROM cajas.sesiones_caja s JOIN seguridad.usuarios u ON u.id=s.usuario_id
WHERE u.username IN ('qa_cajero','qa_cajero2') ORDER BY s.hora_apertura DESC LIMIT 4;
"""
SQL_VENTANA = """\\pset footer on
\\echo '-- Movimientos generados durante el caso'
SELECT c.numero_cuenta, m.tipo, m.monto, m.saldo_anterior, m.saldo_posterior, m.estado, m.referencia, m.canal, to_char(m.created_at,'HH24:MI:SS') AS hora
FROM transacciones.movimientos m JOIN cuentas.cuentas c ON c.id=m.cuenta_id WHERE m.created_at >= '{d}' ORDER BY m.created_at;
\\echo '-- Auditoría de operaciones durante el caso'
SELECT modulo, accion, entidad_tipo, resultado, left(datos_antes::text,90) AS antes, left(datos_despues::text,110) AS despues, to_char(created_at,'HH24:MI:SS') AS hora
FROM auditoria.log_operaciones WHERE created_at >= '{d}' ORDER BY created_at;
\\echo '-- Eventos de seguridad durante el caso'
SELECT username_intentado, evento, exitoso, left(descripcion,80) AS descripcion, to_char(created_at,'HH24:MI:SS') AS hora
FROM seguridad.eventos_seguridad WHERE created_at >= '{d}' ORDER BY created_at;
\\echo '-- Clientes creados o modificados durante el caso'
SELECT dpi, nombre_completo, estado, fecha_nacimiento FROM crm.clientes WHERE updated_at >= '{d}' OR created_at >= '{d}' ORDER BY created_at;
\\echo '-- ACH saliente / entrante durante el caso'
SELECT 'SALIENTE' AS sentido, banco_codigo AS banco, monto, estado, codigo_confirmacion, to_char(fecha_creacion,'HH24:MI:SS') AS hora FROM ach.transferencias WHERE fecha_creacion >= '{d}'
UNION ALL
SELECT 'ENTRANTE', banco_externo, monto, estado, codigo_confirmacion, to_char(created_at,'HH24:MI:SS') FROM ach.transferencias_entrantes WHERE created_at >= '{d}';
"""
MONGO_BANCOS = "JSON.stringify(db.ach_banks_configurations.find({},{_id:1,codigo:1,nombre:1,activo:1,fecha_actualizacion:1}).sort({codigo:1}).toArray())"


def subcoleccion(prefijo, indices=None, nombre=None):
    def buscar(items):
        for it in items:
            if it["name"].startswith(prefijo):
                return it
            if "item" in it:
                r = buscar(it["item"])
                if r:
                    return r
    carpeta = json.loads(json.dumps(buscar(COLECCION["item"])))
    if indices is not None:
        carpeta["item"] = [carpeta["item"][i] for i in indices]
    info = dict(COLECCION["info"])
    info["name"] = f"{COLECCION['info']['name']} · {nombre or prefijo} (subconjunto)"
    return {"info": info, "event": COLECCION.get("event", []), "item": [carpeta]}


def ajustar_fechas_req04(col):
    hoy_utc = dt.datetime.now(dt.timezone.utc).date()
    frontera = hoy_utc.replace(year=hoy_utc.year - 18)
    menor = frontera + dt.timedelta(days=1)
    texto = json.dumps(col, ensure_ascii=False).replace("2008-10-02", frontera.isoformat()).replace("2008-10-03", menor.isoformat())
    log(f"TC-REQ04-001: fechas ajustadas a la fecha UTC del servidor ({hoy_utc}): 18 años exactos={frontera}, menor por 1 día={menor}")
    return json.loads(texto)


def newman(tag, col, env_in, env_out, carpeta, guardar_coleccion=False):
    carpeta.mkdir(parents=True, exist_ok=True)
    ruta_col = TRABAJO / f"{tag}_col.json"
    json.dump(col, open(ruta_col, "w", encoding="utf-8"), ensure_ascii=False)
    if guardar_coleccion:
        (carpeta / f"{tag}_coleccion_ejecutada.json").write_text(json.dumps(col, ensure_ascii=False, indent=2), encoding="utf-8")
    ruta_json = TRABAJO / f"{tag}.json"
    r = subprocess.run(["newman", "run", str(ruta_col), "-e", str(env_in), "--export-environment", str(env_out),
                        "--reporters", "cli,json,junit", "--reporter-json-export", str(ruta_json),
                        "--reporter-junit-export", str(carpeta / f"{tag}.xml"),
                        "--delay-request", "150", "--timeout-request", "30000", "--color", "off"],
                       text=True, capture_output=True)
    (carpeta / f"{tag}_cli.txt").write_text(redactar(r.stdout + r.stderr), encoding="utf-8")
    (carpeta / f"{tag}.xml").write_text(redactar((carpeta / f"{tag}.xml").read_text(encoding="utf-8")), encoding="utf-8")
    reporte = json.load(open(ruta_json, encoding="utf-8"))
    (carpeta / f"{tag}.json").write_text(redactar(json.dumps(reporte, ensure_ascii=False)), encoding="utf-8")
    stats = reporte["run"]["stats"]
    lineas = [f"{ahora()}  {tag}"]
    for ex in reporte["run"]["executions"]:
        req, resp = ex["request"], ex.get("response", {})
        url = req["url"]
        url = url if isinstance(url, str) else ("http://" + ":".join([".".join(url.get("host", [])), str(url.get("port", ""))]) + "/" + "/".join(url.get("path", [])) + ("?" + "&".join(f"{q['key']}={q.get('value', '')}" for q in url.get("query", [])) if url.get("query") else ""))
        cuerpo = bytes(resp.get("stream", {}).get("data", [])).decode("utf-8", "replace") if resp else ""
        aserciones = ex.get("assertions", [])
        fallan = [a["assertion"] for a in aserciones if a.get("error")]
        lineas.append(f"- {ex['item']['name']}")
        lineas.append(f"    {req['method']} {url}")
        lineas.append(f"    HTTP {resp.get('code')} ({resp.get('responseTime')} ms) | ok={len(aserciones) - len(fallan)} fail={len(fallan)}" + (f" FALLAN: {'; '.join(fallan)}" if fallan else ""))
        lineas.append(f"    body: {redactar(cuerpo)[:1200]}")
    (carpeta / f"{tag}_resumen.txt").write_text("\n".join(lineas) + "\n", encoding="utf-8")
    fila = (tag, stats["requests"]["total"], stats["assertions"]["total"], stats["assertions"]["failed"])
    log(f"{tag}: requests={fila[1]} assertions={fila[2]} fallidas={fila[3]}")
    return fila


def verificar_sql(tc, momento, desde, carpeta, db="bancoerp_e2_qa"):
    carpeta.mkdir(parents=True, exist_ok=True)
    salida = psql(SQL_ESTADO + (SQL_VENTANA.format(d=desde) if momento == "DESPUES" else ""), db=db)
    with open(carpeta / f"{tc}.txt", "a", encoding="utf-8") as f:
        f.write(f"================ {tc} — {momento} — {ahora()} ================\n{salida}\n\n")


def esperar(url, etiqueta, intentos=100):
    for _ in range(intentos):
        try:
            if urllib.request.urlopen(url, timeout=5).status == 200:
                log(f"   {etiqueta}: GET {url} -> HTTP 200")
                return
        except Exception:
            pass
        time.sleep(3)
    log(f"   {etiqueta}: GET {url} SIN RESPUESTA tras {intentos * 3}s — se detiene la ejecución")
    sys.exit(1)


def smoke(destino):
    lineas = [f"=== Smoke {ahora()} ==="]
    ok = True
    for url in ["http://localhost:13000/login", "http://localhost:15141/api/Ping", "http://localhost:15254/api/Home",
                "http://localhost:15141/swagger/v1/swagger.json", "http://localhost:15254/swagger/v1/swagger.json"]:
        try:
            codigo = urllib.request.urlopen(url, timeout=20).status
        except Exception as e:
            codigo, ok = f"ERROR {e}", False
        lineas.append(f"   GET {url} -> HTTP {codigo}")
    for l in lineas[1:]:
        log(l)
    destino.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    return ok


def env_inicial(nombre, interna="http://localhost:15141", publica="http://localhost:15254"):
    env = json.load(open(DATOS / "Postman_Environment_QA_Nexus.json", encoding="utf-8"))
    for v in env["values"]:
        if v["key"] == "baseInterna":
            v["value"] = interna
        if v["key"] == "basePublica":
            v["value"] = publica
    ruta = TRABAJO / f"env_{nombre}.json"
    json.dump(env, open(ruta, "w", encoding="utf-8"))
    return ruta


# ------------------------------------------------------------------ plan de la regresión (orden de la guía E3)
def caso(tc, especialista, indices=None, parte=None):
    return ("caso", tc, especialista, indices, parte)


def precond_caja(para, especialista):
    return ("caso", "TC-REQ09-001", especialista, [0], f"precondicion_caja_para_{para}")


PLAN = [
    ("prep", "Walter"),
    caso("TC-REQ04-001", "Walter"), caso("TC-REQ04-002", "Walter"), caso("TC-REQ04-003", "Walter"),
    caso("TC-REQ05-001", "Walter"), caso("TC-REQ05-002", "Walter"), caso("TC-REQ06-001", "Walter"), caso("TC-REQ06-002", "Walter"),
    caso("TC-REQ07-001", "Walter"), caso("TC-REQ07-002", "Walter"), caso("TC-REQ07-003", "Walter"),
    caso("TC-REQ12-001", "Walter"), caso("TC-REQ12-002", "Walter"),
    caso("TC-REQ12-003", "Walter", [0], "parte1_Q100.00"), ("sql", "Reinicio secciones 4 y 5", SECCION_4_5),
    caso("TC-REQ12-003", "Walter", [1], "parte2_Q100.01"),
    ("prep", "Sergio"),
    ("sql", "PRE TC-REQ08-001: sección 5 (cerrar cajas)", SECCION_5),
    caso("TC-REQ08-001", "Sergio"), caso("TC-REQ08-002", "Sergio"), caso("TC-REQ08-003", "Sergio"),
    caso("TC-REQ09-001", "Sergio"), caso("TC-REQ09-002", "Sergio"), caso("TC-REQ09-003", "Sergio"),
    caso("TC-REQ10-001", "Sergio"), caso("TC-REQ10-002", "Sergio"),
    caso("TC-REQ10-003", "Sergio", [0], "parte1_Q5000.00"), ("sql", "Reinicio secciones 4 y 5", SECCION_4_5),
    precond_caja("TC-REQ10-003", "Sergio"), caso("TC-REQ10-003", "Sergio", [1], "parte2_Q5000.01"),
    caso("TC-REQ11-001", "Sergio"), caso("TC-REQ11-002", "Sergio"), caso("TC-REQ11-003", "Sergio"),
    caso("TC-REQ18-001", "Sergio"),
    caso("TC-REQ18-002", "Sergio", [0, 1], "parte1_plan_completo"),
    ("sql", "PRE TC-REQ18-002 parte 2: cuenta contable 1101 inactiva", "UPDATE contabilidad.plan_cuentas SET activo=false WHERE codigo='1101';"),
    caso("TC-REQ18-002", "Sergio", [2], "parte2_1101_inactiva"),
    ("sql", "POST TC-REQ18-002: restaurar cuenta contable 1101", "UPDATE contabilidad.plan_cuentas SET activo=true WHERE codigo='1101';"),
    ("prep", "Anderson"),
    caso("TC-REQ01-001", "Anderson"),
    ("sql", "PRE TC-REQ01-002: reset qa_bloqueo", RESET_BLOQUEO), caso("TC-REQ01-002", "Anderson"),
    caso("TC-REQ01-003", "Anderson"), caso("TC-REQ02-001", "Anderson"), caso("TC-REQ02-002", "Anderson"),
    caso("TC-REQ03-001", "Anderson"), caso("TC-REQ03-002", "Anderson"),
    caso("TC-REQ13-001", "Anderson"), caso("TC-REQ13-002", "Anderson"),
    precond_caja("TC-REQ14-001", "Anderson"),
    caso("TC-REQ14-001", "Anderson"), caso("TC-REQ14-002", "Anderson"),
    caso("TC-REQ14-003", "Anderson", [0], "parte1_Q10.00"), ("sql", "Reinicio secciones 4 y 5", SECCION_4_5),
    precond_caja("TC-REQ14-003", "Anderson"), caso("TC-REQ14-003", "Anderson", [1], "parte2_Q10.01"),
    caso("TC-REQ17-001", "Anderson"),
    ("sql", "PRE TC-REQ17-002: retirar permisos públicos de BANCO_EXTERNO", RETIRAR_PERMISOS_EXT),
    caso("TC-REQ17-002", "Anderson"),
    ("sql", "POST TC-REQ17-002: restaurar permisos", RESTAURAR_PERMISOS_EXT),
    caso("TC-REQ17-003", "Anderson"),
    ("prep", "Luis"),
    ("sql", "PRE TC-REQ15-001: reset qa_bloqueo", RESET_BLOQUEO), caso("TC-REQ15-001", "Luis"),
    caso("TC-REQ15-002", "Luis"), caso("TC-REQ16-002", "Luis"),
]


def fase_rep01():
    # 3. Re-prueba BUG-NEX-02 en BD aislada REP-01
    d_rep = RP / "03_Re_Prueba_Defectos" / "BUG-NEX-02"
    d_rep.mkdir(parents=True, exist_ok=True)
    log("REP-01: BD aislada bancoerp_e2_qa_rep01 (esquema scripts/schema + MockData_Fixture_REP01.sql + 009)")
    psql("DROP DATABASE IF EXISTS bancoerp_e2_qa_rep01;", db="postgres")
    psql("CREATE DATABASE bancoerp_e2_qa_rep01;", db="postgres")
    # Solo el esquema (scripts/schema, igual que init_qa.sh): init_all.sql incluye además la carga sintética, que exige bancoerp_e2_qa.
    subprocess.run(["docker", "exec", PG, "sh", "-c",
                    "for f in /qa/scripts/schema/*.sql; do psql -U e2qa -d bancoerp_e2_qa_rep01 -q -1 -v ON_ERROR_STOP=1 -f \"$f\" || exit 1; done"],
                   check=True, capture_output=True)
    psql((DATOS / "MockData_Fixture_REP01.sql").read_text(encoding="utf-8"), db="bancoerp_e2_qa_rep01")
    psql((COMPOSE_DIR.parents[1] / "Backend/database/deploy/production/009_ach_seed.sql").read_text(encoding="utf-8"), db="bancoerp_e2_qa_rep01")
    log("   REP-01: esquema + fixture REP01 + 009_ach_seed.sql aplicados")
    # La colección solo permite los puertos oficiales del entorno QA (guarda prerequest), así que, igual que en el ciclo 1,
    # las APIs de 15141/15254 se apuntan temporalmente a bancoerp_e2_qa_rep01 y al final se restauran.
    conexion = "Host=postgres;Port=5432;Database=bancoerp_e2_qa_rep01;Username=e2qa;Password=E2SoloQALocal2026"
    compose = ["docker", "compose", "-p", PROYECTO, "-f", str(COMPOSE_DIR / "docker-compose.qa.yml")]
    subprocess.run(compose + ["stop", "internal-api", "public-api"], check=True, capture_output=True)
    log("   REP-01: internal-api y public-api principales detenidas; se levantan apuntando a bancoerp_e2_qa_rep01 (secuencial)")
    for servicio, puerto, url in [("internal-api", 15141, "http://localhost:15141/api/Ping"), ("public-api", 15254, "http://localhost:15254/api/Home")]:
        subprocess.run(["docker", "rm", "-f", f"{PROYECTO}-rep01-{servicio}"], capture_output=True)
        subprocess.run(compose + ["run", "-d", "--no-deps", "--name", f"{PROYECTO}-rep01-{servicio}", "-p", f"127.0.0.1:{puerto}:8080",
                                  "-e", f"ConnectionStrings__DefaultConnection={conexion}", servicio], check=True, capture_output=True)
        esperar(url, f"REP-01 {servicio}")
    env_rep = env_inicial("rep01")
    resultados.append(("Re-prueba",) + newman("00_Preparacion_REP01", subcoleccion("00 · Preparación", [0, 1, 6], "00_Preparacion_REP01"), env_rep, env_rep, d_rep, guardar_coleccion=True))
    resultados.append(("Re-prueba",) + newman("TC-REQ09-001_precondicion_caja_REP01", subcoleccion("TC-REQ09-001", [0], "precondicion_caja_REP01"), env_rep, env_rep, d_rep))
    desde = psql("SELECT now();", tuples=True)
    verificar_sql("TC-REQ16-001_REP01", "ANTES", desde, d_rep, db="bancoerp_e2_qa_rep01")
    resultados.append(("Re-prueba",) + newman("TC-REQ16-001", subcoleccion("TC-REQ16-001"), env_rep, env_rep, d_rep, guardar_coleccion=True))
    verificar_sql("TC-REQ16-001_REP01", "DESPUES", desde, d_rep, db="bancoerp_e2_qa_rep01")
    control = psql("""\\pset footer on
\\echo '-- Consultas SQL de control REP-01 (lo que el reporte debe devolver)'
SELECT (SELECT count(*) FROM crm.clientes) AS total_clientes,
       (SELECT count(*) FROM crm.clientes WHERE estado='ACTIVO') AS clientes_activos,
       (SELECT count(*) FROM crm.clientes WHERE estado='EN_REVISION') AS clientes_en_revision,
       (SELECT count(*) FROM cuentas.cuentas) AS total_cuentas,
       (SELECT count(*) FROM cuentas.cuentas WHERE estado='ACTIVA') AS cuentas_activas,
       (SELECT sum(saldo) FROM cuentas.cuentas WHERE estado<>'CERRADA') AS saldo_total;
SELECT count(*) AS transferencias_internas, coalesce(sum(monto),0) AS monto_internas FROM transacciones.transferencias;
SELECT 'ach.transferencias (salientes)' AS tabla, count(*) AS total, count(*) FILTER (WHERE estado IN ('ENVIADA','APROBADA')) AS aprobadas, coalesce(sum(monto),0) AS monto FROM ach.transferencias
UNION ALL
SELECT 'ach.transferencias_entrantes', count(*), count(*) FILTER (WHERE estado IN ('ENVIADA','APROBADA')), coalesce(sum(monto),0) FROM ach.transferencias_entrantes;
""", db="bancoerp_e2_qa_rep01")
    (d_rep / "Control_SQL_REP01.txt").write_text(f"=== {ahora()} BD bancoerp_e2_qa_rep01 ===\n{control}\n", encoding="utf-8")
    for servicio in ["internal-api", "public-api"]:
        logs = subprocess.run(["docker", "logs", f"{PROYECTO}-rep01-{servicio}"], text=True, capture_output=True)
        (d_rep / f"REP01_{servicio}.log").write_text(redactar((logs.stdout + logs.stderr)[-20000:]), encoding="utf-8")
        subprocess.run(["docker", "rm", "-f", f"{PROYECTO}-rep01-{servicio}"], capture_output=True)
    subprocess.run(compose + ["start", "internal-api", "public-api"], check=True, capture_output=True)
    esperar("http://localhost:15141/api/Ping", "internal-api principal restaurada")
    esperar("http://localhost:15254/api/Home", "public-api principal restaurada")



def main():
    LOG.write_text("", encoding="utf-8")
    log(f"Inicio del ciclo 2 (re-prueba y regresión) · proyecto Docker {PROYECTO} · colección v2")
    commit = subprocess.run(["git", "-C", str(COMPOSE_DIR), "rev-parse", "--short", "HEAD"], text=True, capture_output=True).stdout.strip()
    log(f"Build bajo prueba: baseline {commit} + corrección BUG-NEX-01/02 (working tree montado en /src)")

    # 0. Smoke
    log("Smoke")
    if not smoke(RP / "01_Entorno" / "Smoke_Re_Prueba.txt"):
        log("SMOKE FALLIDO: se detiene la ejecución")
        sys.exit(1)

    # 1. Re-prueba BUG-NEX-01
    d_rt = RP / "03_Re_Prueba_Defectos" / "BUG-NEX-01"
    d_rt.mkdir(parents=True, exist_ok=True)
    env = env_inicial("principal")
    resultados.append(("Re-prueba",) + newman("00_Preparacion", subcoleccion("00 · Preparación"), env, env, d_rt))
    antes = mongo(MONGO_BANCOS)
    resultados.append(("Re-prueba",) + newman("RT-BUG-NEX-01", subcoleccion("RT · Re-prueba"), env, env, d_rt, guardar_coleccion=True))
    resultados.append(("Re-prueba",) + newman("TC-REQ03-002_con_P7-ACH", subcoleccion("TC-REQ03-002"), env, env, d_rt))
    despues = mongo(MONGO_BANCOS)
    iguales = antes == despues
    (d_rt / "Mongo_bancos_antes_despues.txt").write_text(
        f"Configuración ACH en Mongo antes y después de los 14 intentos denegados (RT-01-01..14)\nANTES   {ahora()}\n{antes}\n\nDESPUES {ahora()}\n{despues}\n\nSin cambios: {iguales}\n", encoding="utf-8")
    log(f"Mongo ach_banks_configurations sin cambios tras intentos denegados: {iguales}")

    # 2. Regresión completa
    d_reg = RP / "04_Regresion_Completa"
    d_sql = RP / "05_Verificaciones_SQL"
    for paso in PLAN:
        tipo = paso[0]
        if tipo == "prep":
            resultados.append(("Regresión",) + newman("00_Preparacion", subcoleccion("00 · Preparación"), env, env, d_reg / paso[1]))
            continue
        if tipo == "sql":
            log(paso[1])
            salida = psql(paso[2])
            for l in salida.splitlines()[-3:]:
                log("   " + l)
            continue
        _, tc, especialista, indices, parte = paso
        tag = tc + (f"_{parte}" if parte else "")
        col = subcoleccion(tc, indices, tag)
        if tc == "TC-REQ04-001":
            col = ajustar_fechas_req04(col)
        desde = psql("SELECT now();", tuples=True)
        verificar_sql(tc, "ANTES" + (f" ({parte})" if parte else ""), desde, d_sql)
        time.sleep(0.2)
        fila = newman(tag, col, env, env, d_reg / especialista, guardar_coleccion=bool(indices) or tc == "TC-REQ04-001")
        resultados.append(("Regresión",) + fila)
        verificar_sql(tc, "DESPUES" + (f" ({parte})" if parte else ""), desde, d_sql)

    fase_rep01()

    # 4. Control cruzado del reporte contra SQL en la BD principal (tras la regresión, con ACH salientes y entrantes reales)
    variables = {v["key"]: v["value"] for v in json.load(open(env, encoding="utf-8"))["values"]}
    req = urllib.request.Request("http://localhost:15141/api/reportes/resumen", headers={"Authorization": f"Bearer {variables['token_admin']}"})
    api = json.load(urllib.request.urlopen(req, timeout=20))
    sql = psql("""SELECT json_build_object(
  'totalAch', (SELECT count(*) FROM ach.transferencias) + (SELECT count(*) FROM ach.transferencias_entrantes),
  'achAprobadas', (SELECT count(*) FROM ach.transferencias WHERE upper(estado) IN ('ENVIADA','APROBADA')) + (SELECT count(*) FROM ach.transferencias_entrantes WHERE upper(estado) IN ('ENVIADA','APROBADA')),
  'montoAch', (SELECT coalesce(sum(monto),0) FROM ach.transferencias) + (SELECT coalesce(sum(monto),0) FROM ach.transferencias_entrantes),
  'salientes', (SELECT count(*) FROM ach.transferencias), 'entrantes', (SELECT count(*) FROM ach.transferencias_entrantes));""", tuples=True)
    sql = json.loads(sql)
    filas = [f"{k:14} API={api[k]!s:>10}  SQL={sql[k]!s:>10}  {'OK' if float(api[k]) == float(sql[k]) else 'DIFERENTE'}" for k in ("totalAch", "achAprobadas", "montoAch")]
    coincide = all(l.endswith("OK") for l in filas)
    (d_rep / "Control_cruzado_reporte_BD_principal.txt").write_text(
        f"=== {ahora()} GET /api/reportes/resumen (qa_admin) vs SQL directo · BD bancoerp_e2_qa tras la regresión ===\n"
        f"ACH en BD: {sql['salientes']} salientes + {sql['entrantes']} entrantes\n" + "\n".join(filas) + f"\nResultado: {'COINCIDE' if coincide else 'NO COINCIDE'}\n", encoding="utf-8")
    log(f"Control cruzado reporte vs SQL (BD principal): {'COINCIDE' if coincide else 'NO COINCIDE'}")

    guardar_resumen()


def guardar_resumen(previos=()):
    filas = list(previos) + [dict(zip(["fase", "tag", "requests", "assertions", "fallidas"], r)) for r in resultados]
    json.dump(filas, open(RP / "Resumen_Ejecucion_Ciclo2.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    log(f"Fin del ciclo 2: ejecuciones={len(filas)} requests={sum(f['requests'] for f in filas)} "
        f"assertions={sum(f['assertions'] for f in filas)} fallidas={sum(f['fallidas'] for f in filas)}")


def solo_rep01():
    """Repite solo la fase REP-01 (BD aislada, independiente de la regresión) y actualiza el resumen del ciclo."""
    log("Repetición de la fase REP-01 (--solo-rep01): el intento anterior no envió peticiones (guarda de URLs de la colección)")
    previos = [f for f in json.load(open(RP / "Resumen_Ejecucion_Ciclo2.json", encoding="utf-8")) if "REP01" not in f["tag"] and f["tag"] != "TC-REQ16-001"]
    fase_rep01()
    guardar_resumen(previos)


if __name__ == "__main__":
    solo_rep01() if "--solo-rep01" in sys.argv else main()
