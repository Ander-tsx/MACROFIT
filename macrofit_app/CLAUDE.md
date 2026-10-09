# CLAUDE.md — App MacroFit (Flutter)

Instrucciones para Claude Code al trabajar en `macrofit_app/`. Las reglas generales de todos los agentes están en
`AGENTS.md` y se cargan aquí; este archivo agrega lo específico de Claude Code.

@AGENTS.md

---

## Resumen rápido

- Flutter 3.47 / Dart 3.13. **MVVM en 3 capas por feature** (`domain`, `data`, `presentation`) + `app/` + `core/`.
- `provider` + `ChangeNotifier`, `go_router` con guard de sesión (`resolveRedirect`), `dio` con `AuthInterceptor`,
  `flutter_secure_storage`.
- Historias implementadas: HU-01 (registro con rol + aviso de privacidad), HU-02 (inicio, persistencia y cierre de sesión),
  HU-03 (perfil inicial y edición).
- Antes de terminar: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`
  y prueba de punta a punta contra el backend con base temporal (AGENTS.md §7).

## Cómo trabajar en Claude Code

### Antes de escribir código

1. Lee `README.md`, el README de cada carpeta que vayas a tocar y el contrato del endpoint en `../backend/README.md`.
   Lee el archivo completo antes de editarlo.
2. Si la historia deja abierta una decisión de lógica, usa **AskUserQuestion** (máximo 4 preguntas por llamada, opción
   recomendada primero y marcada *(Recommended)*). Agrupa las preguntas; si son más de 4, haz dos llamadas seguidas antes
   de empezar. No preguntes por decisiones menores: tómalas y menciónalas al final.
3. Si la historia también requiere cambios en el backend, sigue `../backend/CLAUDE.md` para esa parte.

### Herramientas y entorno

- Windows con Git Bash (rutas `/c/Users/...`). Python puede no estar instalado: scripts auxiliares en **Node**, guardados
  en el *scratchpad* de la sesión, nunca en el repositorio.
- Los archivos pueden tener **CRLF** (`core.autocrlf=true`): si haces reemplazos con un script, normaliza a `\n` para
  buscar y conserva el final de línea original al escribir. Con la herramienta `Edit` no hace falta.
- `dart format` cambia archivos en disco: vuelve a leerlos antes de editarlos con `Edit`.
- Agrega paquetes con `flutter pub add <paquete>` (solo si la persona lo aprobó).
- Hay **MongoDB local** en `localhost:27017` y Chrome/Edge como dispositivos de Flutter; normalmente no hay emulador
  de Android corriendo.

### Prueba de punta a punta (sin emulador)

1. Backend en segundo plano (`run_in_background`), desde `../backend`:
   `cargo build -q && MONGO_URI=mongodb://localhost:27017 DB_NAME=macrofit_check PORT=3077 ./target/debug/backend.exe`
2. App web: `flutter build web --dart-define=API_BASE_URL=http://localhost:3077/api/v1` y servirla en segundo plano con
   `npx -y http-server build/web -p 5077 -c-1 --silent`.
3. Espera a que ambos respondan (`curl -s localhost:3077/api/v1/health`, `curl -s localhost:5077`).
4. Ábrela con el navegador integrado (`preview_start` con `url: http://localhost:5077`) y usa `resize_window` con
   preset `mobile`. Flutter web dibuja en un canvas: `read_page`/`find` no ven los widgets, así que interactúa por
   coordenadas a partir de capturas y usa **el marco de coordenadas que informa cada captura**. Tras un clic espera
   1–3 s antes de capturar; la captura puede tomarse antes de que la pantalla se redibuje.
5. Comprueba en MongoDB con `mongosh` lo que la historia guarde (sin mostrar hashes ni tokens completos en el resumen).
6. Para probar expiración de tokens reinicia el backend con `ACCESS_TOKEN_MINUTES=1` y espera más de 2 minutos
   (1 min + 60 s de tolerancia del JWT).
7. Al terminar: `resize_window` preset `desktop`, `taskkill //F //IM backend.exe`, detén el servidor web (proceso que
   escucha en 5077) y `mongosh mongodb://localhost:27017/macrofit_check --eval 'db.dropDatabase()'`.

`build/` está en `.gitignore`; no subas compilaciones.

### Verificación

- Reporta números reales (pruebas de `flutter test`, resultado de `flutter analyze`).
- Si una prueba falla, corrige la causa; no relajes la prueba.
- Si algo no se pudo verificar (Android/iOS real, rendimiento), dilo explícitamente.

### Git

- No hagas commit, push ni PR sin que la persona lo pida.
- Si lo pide: Conventional Commits en español (`feat(auth): ...`), rama `feature/HU-XX-descripcion` desde `develop`,
  PR hacia `develop` con `.github/pull_request_template.md` (marca `dart format`, `flutter analyze` y `flutter test`;
  "Probado en Android/iOS" solo si la persona lo confirmó).

### Resumen final

Breve y en español: qué cambió (con enlaces a archivos), decisiones menores tomadas, resultados de verificación y
pendientes que requieren a la persona (pruebas en dispositivo, capturas, datos).
