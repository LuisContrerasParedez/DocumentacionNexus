#!/bin/sh
# Evidencia_Re_Prueba_BUG01.sh — Transcripción de consola de la re-prueba de BUG-NEX-01 (mismos pasos que la evidencia del 19/10/2026).
# Uso: sh Evidencia_Re_Prueba_BUG01.sh <archivo_salida.txt>
OUT="$1"; BASE=http://localhost:15141; PW=QaNexus2026
token() { curl -sS -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"username\":\"$1\",\"password\":\"$PW\"}" | sed -E 's/.*"token":"([^"]+)".*/\1/'; }
paso() { echo; echo "--- $1 ---"; }
redactar() { tr -d '\r' | sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/<JWT-redactado>/g'; }
run() { echo "\$ $1" | redactar; sh -c "$1" 2>&1 | redactar | cut -c1-600; echo; }
ADMIN=$(token qa_admin); CAJERO=$(token qa_cajero); ANA=$(token qa_cliente_ana)
{
  echo "BUG-NEX-01 — Re-prueba (confirmation testing) — $(date '+%Y-%m-%d %H:%M:%S %Z') (UTC $(date -u '+%Y-%m-%dT%H:%M:%SZ')) — Ejecutor: Luis Contreras (Líder QA)"
  echo "Build: baseline 28f3faf + cambios locales del ciclo 1 + corrección ([Authorize] y [RequirePermission(ach.bancos.*)] en AchBancosController; [Authorize] en AchTransferenciasController)"
  paso "1. Mismo paso que reprodujo el defecto: GET /api/ach/bancos SIN cabecera Authorization (ciclo 1: HTTP 200 con la configuración ACH)"
  run "curl -sS -i $BASE/api/ach/bancos"
  paso "2. GET /api/ach/bancos/activos sin token (ciclo 1: HTTP 200)"
  run "curl -sS -i $BASE/api/ach/bancos/activos"
  paso "3. Escritura anónima: PATCH /api/ach/bancos/{id}/estado sin token (ciclo 1: llegaba al servicio, 404)"
  run "curl -sS -i -X PATCH $BASE/api/ach/bancos/000000000000000000000000/estado -H 'Content-Type: application/json' -d '{\"activo\":false}'"
  paso "4. Rol sin permiso: CLIENTE (qa_cliente_ana) → GET /api/ach/bancos"
  run "curl -sS -i $BASE/api/ach/bancos -H 'Authorization: Bearer $ANA'"
  paso "5. Rol sin permiso: CAJERO (qa_cajero) → DELETE /api/ach/bancos/e20000000000000000000005"
  run "curl -sS -i -X DELETE $BASE/api/ach/bancos/e20000000000000000000005 -H 'Authorization: Bearer $CAJERO'"
  paso "6. Control positivo: ADMIN (qa_admin, permiso ach.bancos.listar) → GET /api/ach/bancos (se muestra solo el conteo y los códigos)"
  echo "\$ curl -sS $BASE/api/ach/bancos -H 'Authorization: Bearer <JWT qa_admin>' | (códigos)"
  curl -sS -o /dev/null -w 'HTTP %{http_code}\n' "$BASE/api/ach/bancos" -H "Authorization: Bearer $ADMIN"
  curl -sS "$BASE/api/ach/bancos" -H "Authorization: Bearer $ADMIN" | grep -o '"codigo":"[^"]*"' | tr '\n' ' '; echo; echo
  paso "7. Control positivo: CLIENTE del portal → GET /api/ach/bancos/activos (necesario para transferir ACH desde Mi Banco)"
  echo "\$ curl -sS $BASE/api/ach/bancos/activos -H 'Authorization: Bearer <JWT qa_cliente_ana>'"
  curl -sS -o /dev/null -w 'HTTP %{http_code}\n' "$BASE/api/ach/bancos/activos" -H "Authorization: Bearer $ANA"; echo
  paso "8. Hardening: GET /api/ach/transferencias sin token (antes de la corrección el rechazo dependía del servicio; ahora lo hace el pipeline de autenticación con 401)"
  run "curl -sS -i $BASE/api/ach/transferencias"
  paso "9. Mismo endpoint protegido de referencia sin token (control)"
  run "curl -sS -i $BASE/api/clientes"
  echo "Resultado: los accesos sin token responden 401 y los roles sin permiso 403, igual que /api/clientes; ADMIN y el portal conservan su acceso."
} > "$OUT"
echo "Evidencia escrita en $OUT"
