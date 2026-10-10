#!/usr/bin/env bash
# Verificaciones previas al PR (formato, análisis y pruebas unitarias).
#   scripts/check.sh            backend y app
#   scripts/check.sh backend    solo backend
#   scripts/check.sh app        solo app
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

check_backend() {
  echo "▶ Backend"
  cd "$ROOT/backend"
  cargo fmt --check
  cargo clippy --all-targets -- -D warnings
  cargo test
  node postman/build.js --check
}

check_app() {
  echo "▶ App"
  cd "$ROOT/macrofit_app"
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze
  flutter test
}

case "${1:-all}" in
  backend) check_backend ;;
  app) check_app ;;
  all) check_backend; check_app ;;
  *) echo "Uso: scripts/check.sh [backend|app|all]" >&2; exit 1 ;;
esac
echo "✓ Todo en orden"
