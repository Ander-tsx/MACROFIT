# CLAUDE.md — Backend MacroFit

Instrucciones para Claude Code al trabajar en `backend/`. Las reglas generales de todos los agentes están en
`AGENTS.md` y se cargan aquí; este archivo agrega lo específico de Claude Code.

@AGENTS.md

---

## Resumen rápido

- API REST en **Rust 2024 + Axum 0.7 + MongoDB**, rutas bajo `/api/v1`, capas `routes → services → models` con `auth/` transversal.
- Errores siempre con `AppError` → `{ "error": { code, message, fields } }`; cuerpos con `ApiJson<T>`.
- Historias implementadas: TEC-05 (base), HU-01 (registro con rol), HU-02 (sesión con access/refresh token).
- Antes de terminar: `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`,
  `node postman/build.js --check` y newman contra una base temporal (AGENTS.md §7).

## Cómo trabajar en Claude Code

### Antes de escribir código

1. Lee `README.md` y el `README.md` de cada carpeta que vayas a tocar. Lee el archivo completo antes de editarlo.
2. Si la historia deja abierta una decisión que impacta el diseño, usa **AskUserQuestion** (máximo 4 preguntas por
   llamada, con la opción recomendada primero y marcada como *(Recommended)*). Agrupa las preguntas en una sola llamada.
   No preguntes por decisiones menores: tómalas y menciónalas al final.
3. La parte Flutter de una historia **no** entra salvo que la persona lo confirme.

### Herramientas y entorno

- El equipo trabaja en **Windows**: la herramienta Bash es Git Bash (rutas `/c/Users/...`, `//F` en `taskkill`).
  Para matar el servidor de pruebas: `taskkill //F //IM backend.exe`.
- Python puede no estar instalado; para scripts auxiliares usa **Node** (siempre disponible) y guárdalos en el
  *scratchpad* de la sesión, no en el repositorio.
- Levanta el servidor de verificación con `run_in_background` y espera a que responda
  (`curl -s localhost:3077/api/v1/health`) antes de lanzar newman. Usa `npx -y newman@6` (no está instalado globalmente).
- Para cambios mecánicos en JSON grandes (colecciones de Postman), genera o transforma con un script de Node en
  lugar de editar a mano; después ejecuta `node postman/build.js`.
- Tras `cargo fmt` los archivos cambian en disco: vuelve a leerlos antes de editarlos con `Edit`.
- Nunca uses `cat`, `Read` ni `grep` sobre `.env`. Si necesitas saber qué variables existen, `cut -d= -f1 .env`.

### Verificación

- Sigue AGENTS.md §7 al pie de la letra. Reporta los números reales (requests/aserciones de newman, tests de cargo).
- Si una prueba falla, corrige la causa; no relajes los tests de Postman ni de Rust para que pasen.
- Si algo no se pudo verificar, dilo explícitamente en el resumen.

### Git

- No hagas commit, push ni PR sin que la persona lo pida.
- Si lo pide: Conventional Commits en español (`feat(auth): ...`), rama `feature/HU-XX-descripcion` desde `develop`,
  PR hacia `develop` con la plantilla `.github/pull_request_template.md`. Recuerda que el PR necesita la captura del
  Collection Runner, que debe tomar la persona.

### Resumen final

Breve y en español: qué cambió (con enlaces a archivos), decisiones menores tomadas, resultados de verificación y
pendientes que requieren a la persona (capturas, limpieza de datos, partes de la app).
