#!/bin/sh
# Preparar_Entorno_Re_Prueba.sh — Entorno QA limpio para el ciclo 2 de la E3 (re-prueba + regresión).
# Uso: sh Preparar_Entorno_Re_Prueba.sh <carpeta_03_Evidencias_y_MockData_E2> <carpeta_03_Evidencias_y_Anexos_E3> <carpeta_Backend>
# Usa un proyecto Docker propio (bancoerp-e3-retest) con volúmenes nuevos: no toca los datos del ciclo 1 (bancoerp-e2-qa).
set -eu
E2="$1"; EVID="$2"; BACKEND="$3"
P=bancoerp-e3-retest; PG="$P-postgres-1"
OUT="$EVID/Re_Prueba_Cierre_E3/01_Entorno"; DATOS="$EVID/Readiness_y_MockData_E2"
mkdir -p "$OUT"
sello() { date '+%Y-%m-%d %H:%M:%S %Z'; }
psqlf() { docker exec -i "$PG" psql -U e2qa -d bancoerp_e2_qa -v ON_ERROR_STOP=1 "$@"; }

docker compose -p "$P" -f "$E2/docker-compose.qa.yml" up -d
until docker compose -p "$P" -f "$E2/docker-compose.qa.yml" logs postgres 2>&1 | grep -q "init process complete"; do sleep 3; done
until docker exec "$PG" pg_isready -U e2qa -d bancoerp_e2_qa >/dev/null 2>&1; do sleep 2; done

{
  echo "=== $(sello) Proyecto $P: esquema init_all.sql aplicado por docker-entrypoint (BD nueva) ==="
  echo "=== $(sello) Carga base MockData_Sintetica.sql ==="
  psqlf -q -f - < "$E2/MockData_Sintetica.sql"
  echo "=== $(sello) Capa Nexus MockData_Fixtures_Nexus.sql ==="
  psqlf -f - < "$DATOS/MockData_Fixtures_Nexus.sql" | grep -v -E "^INSERT 0 1$"
  echo "=== $(sello) Seed de permisos ACH 009_ach_seed.sql (script de despliegue a producción omitido en el esquema QA; OBS-RT-01) ==="
  psqlf -f - < "$BACKEND/database/deploy/production/009_ach_seed.sql"
  echo "=== $(sello) Mongo: seed_banco_mock.js (5 bancos simulados E2_QA_*) ==="
  mongosh "mongodb://127.0.0.1:17017/bancoerp_e2_qa" --quiet "$E2/scripts/seed_banco_mock.js"
  echo
  echo "=== $(sello) Permisos ACH por rol tras 009 ==="
  psqlf -c "SELECT p.codigo, string_agg(r.codigo, ',' ORDER BY r.codigo) AS roles FROM seguridad.permisos p JOIN seguridad.roles_permisos rp ON rp.permiso_id=p.id JOIN seguridad.roles r ON r.id=rp.rol_id WHERE p.codigo LIKE 'ach.%' OR p.codigo LIKE 'portal.ach%' GROUP BY 1 ORDER BY 1;"
} 2>&1 | tee "$OUT/Carga_Datos_Re_Prueba.txt"

psqlf -f - < "$DATOS/QA_Readiness_Check_Nexus.sql" > "$OUT/Checklist_DB_Nexus_Re_Prueba.txt" 2>&1
echo "Checklist RD-16: $(grep -c '^== C-' "$OUT/Checklist_DB_Nexus_Re_Prueba.txt") consultas, filas ok=f: $(grep -cE '\| f\s*$' "$OUT/Checklist_DB_Nexus_Re_Prueba.txt" || true)"

until [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:15141/api/Ping)" = 200 ] && [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:15254/api/Home)" = 200 ]; do sleep 5; done
{
  echo "=== Verificación del entorno de re-prueba — $(sello) ==="
  echo "Compose: $E2/docker-compose.qa.yml (proyecto $P)"; echo
  docker compose -p "$P" -f "$E2/docker-compose.qa.yml" ps
  echo; echo "=== Versiones ==="
  docker exec "$PG" psql -U e2qa -d bancoerp_e2_qa -tAc "select version()"
  docker exec "$P-mongo-1" mongod --version | head -1
  echo "newman $(newman --version)"; echo "dotnet SDK host $(dotnet --version)"
  echo; echo "=== Build montada (/src) ==="
  git -C "$BACKEND" log -1 --format='baseline %h %s (%ci)'
  git -C "$BACKEND" status --short -- . | sed 's/^/  /'
} > "$OUT/Verificacion_Entorno_Re_Prueba.txt" 2>&1
echo "Entorno listo."
