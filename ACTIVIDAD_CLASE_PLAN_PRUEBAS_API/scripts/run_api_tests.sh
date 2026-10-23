#!/bin/sh
# Prepara datos QA y ejecuta la bateria de pruebas de la Public API.
# Lee la credencial del usuario tecnico desde .env.local sin imprimirla.
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
PG_CONTAINER=${PG_CONTAINER:-bancoerp-dev-postgres-1}

if [ -z "$BANCO_EXTERNO_PASSWORD" ]; then
    BANCO_EXTERNO_PASSWORD=$(grep '^AchExternalAuth__Password=' "$ROOT_DIR/.env.local" | cut -d= -f2- | tr -d '"')
fi
: "${QA_PASSWORD:?Defina QA_PASSWORD con la contrasena de los usuarios QA}"

docker exec -i "$PG_CONTAINER" psql -q -U bancoerp -d bancoerp < "$SCRIPT_DIR/01_preparar_datos_qa.sql" > /dev/null

BANCO_EXTERNO_PASSWORD="$BANCO_EXTERNO_PASSWORD" QA_PASSWORD="$QA_PASSWORD" PG_CONTAINER="$PG_CONTAINER" \
    node "$SCRIPT_DIR/run_api_tests.mjs"
