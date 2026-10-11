# `scripts/` — atajos para verificar y probar

Scripts de Bash (funcionan en macOS, Linux y Git Bash). Se ejecutan desde cualquier carpeta.

| Script | Para qué |
|---|---|
| `check.sh [backend\|app\|all]` | Formato, análisis y pruebas unitarias antes de subir un PR |
| `api-test.sh` | Levanta el backend con una base temporal, corre Newman (dos veces) y limpia al terminar |
| `dev.sh backend` | Levanta el backend en el puerto 3000 con la base temporal `macrofit_dev` |
| `dev.sh link` | Vincula al primer coach con el primer usuario (HU-05, solo desarrollo) |
| `dev.sh clean` | Borra la base `macrofit_dev` |

Necesitan MongoDB en `localhost:27017`; si no hay `mongosh`, usan el contenedor `macrofit-mongo` de Docker.
Solo borran las bases que ellos mismos crean (`macrofit_check` y `macrofit_dev`).

## Probar la app contra el backend

```bash
scripts/dev.sh backend          # terminal 1
cd macrofit_app && flutter run  # terminal 2: elige el simulador o emulador
scripts/dev.sh link             # tras registrar un coach y un usuario desde la app
scripts/dev.sh clean            # al terminar
```
