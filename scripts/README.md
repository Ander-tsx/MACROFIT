# `scripts/` — atajos para verificar y probar

Scripts de Bash (funcionan en macOS, Linux y Git Bash). Se ejecutan desde cualquier carpeta.

| Script | Para qué |
|---|---|
| `check.sh [backend\|app\|all]` | Formato, análisis y pruebas unitarias antes de subir un PR |
| `api-test.sh` | Levanta el backend con una base temporal, corre Newman (dos veces) y limpia al terminar |
| `dev.sh backend` | Levanta el backend en el puerto 3000 con la base temporal `macrofit_dev` |
| `dev.sh link` | Vincula al primer coach con el primer usuario (HU-05, solo desarrollo) |
| `dev.sh seed-exercises` | Carga el catálogo inicial de ejercicios en `macrofit_dev` (TEC-09, reproducible) |
| `dev.sh clean` | Borra la base `macrofit_dev` |

Necesitan MongoDB en `localhost:27017`; si no hay `mongosh`, usan el contenedor `macrofit-mongo` de Docker.
Solo borran las bases que ellos mismos crean (`macrofit_check` y `macrofit_dev`).

## Carga del catálogo inicial de ejercicios (TEC-09)

Catálogo base de ejercicios que usan las rutinas del coach (HU-18) y el motor de reglas (TEC-10 / RF-14).
Sebastián lo trabaja en paralelo con la vinculación. Fecha límite: día 7 (20/10); es la tercera en salir si en la revisión del día 5 la ruta crítica va atrasada.

- **Cantidad mínima acordada en el Sprint Planning:** **18 ejercicios**.
- **Campos:** Cada ejercicio tiene nombre (`name`), grupo muscular (`muscle_group`), equipo (`equipment`) y nivel (`level`), con los mismos valores de nivel que el perfil de usuario (`beginner`, `intermediate`, `advanced`).
- **Cobertura exhaustiva:** Hay al menos un ejercicio por cada combinación de los 6 grupos musculares (`chest`, `back`, `legs`, `shoulders`, `arms`, `core`) y los 3 niveles, garantizando que el motor de reglas (TEC-10 / RF-14) genere siempre una rutina válida.
- **Reproducibilidad e idempotencia:** La carga usa `find_one_and_update` con `upsert: true` sobre el índice único `name` en MongoDB (`exercise_name_unique`). Ejecutar el script dos o más veces actualiza la información sin duplicar ejercicios ni arrojar errores de clave duplicada.

### 1. Ejecución Local

Con atajo Bash:
```bash
scripts/dev.sh seed-exercises
```

O directamente con Cargo desde `backend/` (usa variables de `.env` o las pasadas en la línea de comandos):
```bash
cd backend
cargo run --bin seed_exercises
```

Para sembrar en una base local específica:
```bash
MONGO_URI="mongodb://localhost:27017" DB_NAME="macrofit_db" cargo run --bin seed_exercises
```

### 2. Ejecución en Ambiente Desplegado

- **Vía API REST (en ambientes con `APP_ENV=development`):**
  ```http
  POST /api/v1/dev/seed/exercises
  ```
  Respuesta: `201 Created` con `{ "message": "Catálogo de ejercicios cargado correctamente", "count": 18 }`.

- **Vía CLI o tarea de despliegue (CI/CD o contenedor):**
  Ejecutar el binario compilado configurando las variables de entorno del cluster desplegado:
  ```bash
  MONGO_URI="<atlas_connection_string>" DB_NAME="<db_name>" ./seed_exercises
  ```

## Probar la app contra el backend

```bash
scripts/dev.sh backend          # terminal 1
scripts/dev.sh seed-exercises   # poblar el catálogo de ejercicios
cd macrofit_app && flutter run  # terminal 2: elige el simulador o emulador
scripts/dev.sh link             # tras registrar un coach y un usuario desde la app
scripts/dev.sh clean            # al terminar
```
