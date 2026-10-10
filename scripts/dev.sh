#!/usr/bin/env bash
# Entorno local para probar la app contra el backend (simulador, emulador o web).
#   scripts/dev.sh backend   levanta la API en el puerto 3000 con una base temporal (macrofit_dev)
#   scripts/dev.sh link      vincula al primer coach con el primer usuario registrado (HU-05)
#   scripts/dev.sh clean     borra la base temporal
# La app usa localhost:3000 por defecto, así que basta `flutter run` en macrofit_app/.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PORT="${PORT:-3000}"
DB_NAME="macrofit_dev"

case "${1:-}" in
  backend)
    cd "$ROOT/backend"
    cargo build -q
    MONGO_URI="$MONGO_URI" DB_NAME="$DB_NAME" PORT="$PORT" APP_ENV=development exec "$(backend_bin)"
    ;;
  link)
    ids=$(mongo_eval "$DB_NAME" '
      const coach = db.users.findOne({ role: "coach" });
      const user = db.users.findOne({ role: "user" });
      print(coach && user
        ? JSON.stringify({ coach_id: coach._id.toString(), user_id: user._id.toString() })
        : "FALTA");')
    if [ "$ids" = "FALTA" ]; then
      echo "En la base $DB_NAME no hay un coach y un usuario. Regístralos desde la app con el backend de 'scripts/dev.sh backend' abierto." >&2
      exit 1
    fi
    curl -sf -X POST "http://localhost:$PORT/api/v1/dev/seed/coach-links" \
      -H 'Content-Type: application/json' -d "$ids"
    echo
    ;;
  clean)
    drop_db "$DB_NAME"
    echo "Base $DB_NAME borrada"
    ;;
  *)
    echo "Uso: scripts/dev.sh [backend|link|clean]" >&2
    exit 1
    ;;
esac
