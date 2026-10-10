#!/usr/bin/env bash
# Funciones comunes de los scripts. Se carga con `source`, no se ejecuta.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
MONGO_CONTAINER="${MONGO_CONTAINER:-macrofit-mongo}"

# Binario del backend (en Windows lleva .exe).
backend_bin() {
  local bin="$ROOT/backend/target/debug/backend"
  [ -f "$bin.exe" ] && bin="$bin.exe"
  echo "$bin"
}

# Ejecuta JavaScript de mongosh sobre una base: usa mongosh local o el contenedor de Docker.
mongo_eval() {
  local db="$1" script="$2"
  if command -v mongosh >/dev/null 2>&1; then
    mongosh --quiet "$MONGO_URI/$db" --eval "$script"
  else
    docker exec "$MONGO_CONTAINER" mongosh --quiet "$db" --eval "$script"
  fi
}

# Borra una base de datos. Solo se llama con bases que creó el propio script.
drop_db() {
  mongo_eval "$1" 'db.dropDatabase()' >/dev/null
}

# Espera hasta 30 s a que la API responda.
wait_for_api() {
  local port="$1"
  for _ in $(seq 1 30); do
    curl -sf "http://localhost:$port/api/v1/health" >/dev/null && return 0
    sleep 1
  done
  echo "La API no respondió en el puerto $port" >&2
  return 1
}
