#!/bin/sh
set -eu
for file in /qa/scripts/schema/*.sql; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q -1 -f "$file"
done
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q -f /qa/MockData_Sintetica.sql
