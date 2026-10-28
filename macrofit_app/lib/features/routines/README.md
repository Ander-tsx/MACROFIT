# `features/routines/` — constructor de rutinas del coach (HU-18)

**HU-18-APP:** "Como coach, quiero crear rutinas personalizadas para adaptarlas a cada cliente." (RF-22, CU-04 pasos
1 a 4, flujos alternos 4a y 5a). El coach ve sus rutinas, crea una nueva con ejercicios del catálogo (TEC-09), captura
series, repeticiones y descanso de cada uno, los quita o reordena, y edita o elimina sus rutinas. Asignarlas a un cliente
es HU-19.

## Endpoints

Contrato en [backend/README.md](../../../../backend/README.md#rutinas-del-coach--coachroutines-hu-18) y
[catálogo de ejercicios](../../../../backend/README.md#catálogo-de-ejercicios--exercises-tec-09). Cliente HTTP **con
sesión**; las rutas de `/coach/routines` son solo para el rol `coach`.

| Endpoint | Uso |
|---|---|
| `GET /exercises?muscle_group=&level=` | Catálogo del selector; los filtros los aplica el servidor (`null` = sin filtro) |
| `GET /coach/routines` | Lista del coach, la editada más recientemente primero |
| `POST /coach/routines` | Crear (`201`) |
| `PUT /coach/routines/{id}` | Editar: reemplaza nombre y ejercicios (`200`) |
| `DELETE /coach/routines/{id}` | Eliminar (`204`) |

Cuerpo de `POST` y `PUT`: `{ name, exercises: [{ exercise_id, sets, reps, rest_seconds }] }`. La respuesta trae `name` y
`muscle_group` de cada ejercicio (copia del catálogo), así que la lista no cruza con `/exercises`.

## Reglas (iguales a `backend/src/services/routines.rs`)

`RoutineValidator` (puro, `domain/validators/`) usa los mismos límites y mensajes que la API. Si cambias una regla,
cambia ambas.

| Campo | Regla |
|---|---|
| `name` | Obligatorio; se recorta; 1 a 80 caracteres |
| `exercises` | De 1 a 20 |
| `exercises[i].sets` | Entero de 1 a 10 |
| `exercises[i].reps` | Entero de 1 a 100 |
| `exercises[i].rest_seconds` | Entero de 0 a 600 (segundos) |

Que el `exercise_id` exista en el catálogo solo lo puede comprobar el servidor (CU-04 5a): su `400` se muestra en el
ejercicio.

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/exercise.dart` | `Exercise` (valores de la API tal cual) y enums de filtros `MuscleGroup` y `ExerciseLevel` |
| `domain/entities/routine.dart` | `Routine`, `RoutineExercise` (guardadas) y `RoutineDraft`, `RoutineExerciseDraft` (lo que se envía) |
| `domain/repositories/routines_repository.dart` | Contrato `RoutinesRepository` (catálogo + CRUD de rutinas) |
| `domain/validators/routine_validator.dart` | `RoutineValidator`: reglas, nombres de campo de la API y `validate` con todos los errores |
| `data/models/exercise_model.dart`, `data/models/routine_model.dart` | JSON de ejercicio, rutina y cuerpo (`RoutineDraftModel.toJson`) |
| `data/datasources/routines_remote_data_source.dart` | Los 5 endpoints con `guardApiCall` |
| `data/repositories/routines_repository_impl.dart` | Implementación del contrato |
| `presentation/routines_list/` | `/coach/routines` «Mis rutinas»: lista, vacío, error con «Reintentar», «Nueva rutina», menú Editar / Eliminar |
| `presentation/routine_builder/` | `/coach/routines/new` y `/coach/routines/:routineId/edit`: nombre, ejercicios, Guardar, confirmación al salir |
| `presentation/exercise_picker/` | `/coach/routines/exercises` «Agregar ejercicios»: filtros y selección múltiple |
| `presentation/widgets/routine_texts.dart` | Etiquetas en español (grupo muscular, nivel, equipo) y resumen de la rutina |

## Flujo

1. **Panel de coach** → **Mis rutinas** (botón del cuerpo o icono de la barra, CU-04 paso 1). La lista muestra nombre y
   resumen (`2 ejercicios · Pecho, Espalda`). Sin rutinas lo indica; sin red, `ErrorBanner` + «Reintentar» (RNF-11).
2. **Nueva rutina** abre el constructor vacío (CU-04 paso 2). **Agregar ejercicios** abre el selector: chips de grupo
   muscular y de nivel (cada cambio consulta `GET /exercises`), se marcan varios y **Agregar (n)** regresa con ellos en
   el orden en que se marcaron (CU-04 paso 3).
3. Cada ejercicio llega con **3 series × 10 repeticiones y 60 s** de descanso, editables. Se quita con el bote y se
   reordena arrastrando el asa.
4. **Guardar** valida localmente (CU-04 4a). Si pasa, `POST` (o `PUT` al editar); un `400` marca cada campo, incluido
   `exercises[i].exercise_id` cuando el ejercicio ya no está en el catálogo (5a). Al guardar regresa a la lista, que se
   recarga.
5. Tocar una rutina (o **Editar** en su menú) abre el constructor precargado. **Eliminar** pide confirmación, llama al
   `DELETE` y recarga la lista.
6. **Atrás** con cambios sin guardar pregunta «¿Descartar cambios?».

## Decisiones

- Acordadas con el equipo: selector en pantalla completa con **selección múltiple**; valores precargados 3 × 10 y 60 s;
  reordenar **arrastrando** (`ReorderableListView` con `onReorderItem`, que ya entrega el índice final para
  `move(from, to)`); confirmar antes de descartar cambios.
- Un solo repositorio para rutinas y catálogo: hoy solo este feature usa `GET /exercises`.
- Las entidades guardan `muscle_group`, `equipment` y `level` como texto de la API: un valor nuevo del catálogo se
  muestra tal cual en lugar de romper la app.
- Editar usa la rutina de la lista (`extra`), sin `GET /coach/routines/{id}`; sin `extra` (p. ej. al restaurar la ruta)
  vuelve a la lista.
- Los errores por ejercicio dependen de su posición: al agregar, quitar o reordenar se limpian porque ya no
  corresponden. Editar un campo limpia solo el suyo.
- Eliminar recibe la confirmación inyectada (`delete(routine, confirm)`, como `regenerate(confirm)` de HU-12) para
  probar la cancelación en el ViewModel. Un `404 ROUTINE_NOT_FOUND` al eliminar se trata como eliminada (se quita de la
  lista); al editar se muestra el mensaje.
- Los campos numéricos solo aceptan dígitos (`FilteringTextInputFormatter.digitsOnly`); el validador además rechaza
  decimales y texto con los mensajes de la API.
- Se permite repetir un ejercicio (la API lo acepta). Con 20 ejercicios se deshabilita **Agregar ejercicios**.
- En el selector se descarta la respuesta de un filtro anterior si el coach cambia de filtro antes de que llegue.

## Pruebas

- `test/features/routines/domain/routine_validator_test.dart`: límites de cada campo y `validate` con todos los errores.
- `test/features/routines/data/routines_repository_impl_test.dart`: rutas, métodos, parámetros y cuerpo; `400` por
  campo, `ROUTINE_NOT_FOUND` y sin red.
- `test/features/routines/presentation/`: ViewModels de la lista (carga, vacío, errores, eliminar), del constructor
  (crear, editar, quitar, reordenar, validación, errores de la API) y del selector (filtros, selección, errores).
- `test/app/app_test.dart` › rutinas del coach (HU-18) y `test/app/router_test.dart` › rutinas del coach (HU-18).

## Pendiente

- Prueba manual en un teléfono físico contra la API desplegada con el catálogo cargado (`seed_exercises`) y capturas
  para el PR.
- `TODO(HU-19)`: asignar rutinas a clientes.
