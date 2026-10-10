#!/usr/bin/env bash
# Prueba la API con Newman contra una base temporal: levanta el backend, corre la colección
# y al terminar lo apaga y borra la base. Requiere MongoDB local (o el contenedor de Docker).
#   scripts/api-test.sh        dos corridas seguidas (lo que pide backend/AGENTS.md)
#   RUNS=1 scripts/api-test.sh una sola
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PORT="${PORT:-3077}"
DB_NAME="macrofit_check"
RUNS="${RUNS:-2}"
SERVER_PID=""

cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  drop_db "$DB_NAME"
}
trap cleanup EXIT

cd "$ROOT/backend"
cargo build -q
MONGO_URI="$MONGO_URI" DB_NAME="$DB_NAME" PORT="$PORT" APP_ENV=development "$(backend_bin)" >/dev/null &
SERVER_PID=$!
wait_for_api "$PORT"

for run in $(seq 1 "$RUNS"); do
  echo "▶ Newman, corrida $run de $RUNS"
  npx -y newman@6 run postman/MacroFit.postman_collection.json \
    -e postman/MacroFit.postman_environment.json \
    --env-var "baseUrl=http://localhost:$PORT"
done
