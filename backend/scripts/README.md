# `scripts/` — Scripts de mantenimiento y carga de datos

## Carga del Catálogo Inicial de Ejercicios (TEC-09)

Catálogo base de ejercicios que usan las rutinas del coach (HU-18) y el motor de reglas (TEC-10 / RF-14).
Sebastián lo trabaja en paralelo con la vinculación. Es la tercera en salir del sprint si en la revisión del día 5 la ruta crítica va atrasada; fecha límite: día 7 (20/10).

La carga del catálogo de ejercicios es reproducible e idempotente (utiliza `find_one_and_update` con `upsert: true`
sobre el índice único `name`): ejecutar el script múltiples veces no duplicará registros.

Cantidad mínima acordada en el Sprint Planning: **18 ejercicios** (cubriendo al menos un ejercicio por cada una de las 18 combinaciones de los 6 grupos musculares y los 3 niveles de dificultad del perfil: `beginner`, `intermediate`, `advanced`). Cada ejercicio contiene nombre, grupo muscular, equipo y nivel.

### 1. Ejecución Local (CLI)

En la carpeta `backend/`:

```bash
cargo run --bin seed_exercises
```

O usando el script de conveniencia desde la raíz:
```bash
scripts/dev.sh seed-exercises
```

El script leerá las variables de entorno (`MONGO_URI` y `DB_NAME`), creará los índices en MongoDB (`exercise_name_unique` y `exercise_muscle_group_level`) y cargará el catálogo asegurando la disponibilidad de ejercicios para el motor de reglas (TEC-10 / RF-14).

### 2. Ejecución mediante API (Ambiente Desplegado / CI)

Si el servidor backend está corriendo con `APP_ENV=development`:

```http
POST /api/v1/dev/seed/exercises
```

**Respuesta (`201 Created`):**

```json
{
  "message": "Catálogo de ejercicios cargado correctamente",
  "count": 18
}
```
