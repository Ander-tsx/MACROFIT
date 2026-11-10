# `features/routines/` — rutinas del coach (HU-18), su asignación a clientes (HU-19) y su edición o retiro (HU-20)

**HU-18-APP:** "Como coach, quiero crear rutinas personalizadas para adaptarlas a cada cliente." (RF-22, CU-04 pasos
1 a 4, flujos alternos 4a y 5a). El coach ve sus rutinas, crea una nueva con ejercicios del catálogo (TEC-09), captura
series, repeticiones y descanso de cada uno, los quita o reordena, y edita o elimina sus rutinas. Asignarlas a un cliente
es HU-19.

**HU-19-APP:** "Como coach, quiero asignar una rutina a uno o varios clientes para que la sigan." (RF-23, RN-04, RNF-11,
CU-04 pasos 5 y 6, alterno 5a). Desde el menú de una rutina, **Asignar** abre la selección múltiple de los clientes
vinculados; los que ya la tienen aparecen marcados y bloqueados; se confirma un resumen y se regresa con el aviso de éxito.

**HU-20-APP:** "Como coach, quiero modificar o retirar una rutina asignada para ajustarla al avance del cliente."
(RF-24, RNF-11). Desde el menú de una rutina, **Clientes asignados** muestra quién la tiene y permite **retirarla** de
cada uno con confirmación. Editar o eliminar una rutina asignada avisa antes a cuántos clientes afecta.

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
| `GET /coach/clients` | HU-19: clientes con vinculación activa (dominio de `clients`, `ClientsRepository.getClients`) |
| `GET /coach/routines/{id}/assignments` | HU-19: asignaciones activas de clientes vinculados (se marcan como «Ya asignada») |
| `POST /coach/routines/{id}/assignments` | HU-19: `{ client_ids }` (1 a 50), todo o nada; `403 CLIENT_NOT_LINKED` con `fields["client_ids[i]"]` |
| `DELETE /coach/routines/{id}/assignments/{clientId}` | HU-20: retira la rutina del cliente (`204`). **Contrato propuesto para HU-20-API** (abajo) |

### Contrato que usa la app (HU-20-API)

HU-20-API se acopla a esta forma:

- `DELETE /coach/routines/{id}/assignments/{clientId}` → `204` sin cuerpo. La asignación activa pasa a `removed`
  (`removed_at`); **no** se borran las sesiones completadas del cliente (`routine_sessions`, RF-24). Después, el
  cliente deja de ver la rutina (HU-16) y de poder registrar sesiones (HU-17 responde `404`).
- `404 ASSIGNMENT_NOT_FOUND` (código nuevo): el cliente no tiene la rutina asignada (ya se retiró o nunca la tuvo). La
  app lo trata como retirada: lo quita de la lista y avisa «La rutina ya se había retirado de…».
- `404 ROUTINE_NOT_FOUND`: la rutina no existe, el id está mal formado o es de otro coach.
- `401` / `403 FORBIDDEN_ROLE` (cuenta `user`).
- `PUT` y `DELETE /coach/routines/{id}` no cambian: editar ya se refleja en los clientes y eliminar ya retira las
  asignaciones (HU-19).

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
| `domain/entities/routine_assignment.dart` | `RoutineAssignment` (HU-19): `routineId`, `clientId`, `clientName`, `assignedAt` |
| `domain/entities/routine.dart` | `Routine`, `RoutineExercise` (guardadas) y `RoutineDraft`, `RoutineExerciseDraft` (lo que se envía) |
| `domain/repositories/routines_repository.dart` | Contrato `RoutinesRepository` (catálogo + CRUD de rutinas + `getAssignments` / `assignRoutine`) |
| `domain/validators/routine_validator.dart` | `RoutineValidator`: reglas, nombres de campo de la API y `validate` con todos los errores |
| `data/models/exercise_model.dart`, `data/models/routine_model.dart` | JSON de ejercicio, rutina y cuerpo (`RoutineDraftModel.toJson`) |
| `data/models/routine_assignment_model.dart` | JSON de la asignación y cuerpo `{ client_ids }` |
| `data/datasources/routines_remote_data_source.dart` | Los 7 endpoints con `guardApiCall` |
| `data/repositories/routines_repository_impl.dart` | Implementación del contrato |
| `presentation/routines_list/` | `/coach/routines` «Mis rutinas»: lista, vacío, error con «Reintentar», «Nueva rutina», menú Editar / Asignar / Eliminar |
| `presentation/routine_assignments/` | `/coach/routines/:routineId/clients` «Clientes asignados» (HU-20): lista de clientes con la rutina, **Retirar** con confirmación, vacío, sin conexión |
| `presentation/assign_routine/` | `/coach/routines/:routineId/assign` «Asignar rutina» (HU-19): búsqueda, selección múltiple, ya asignados, confirmación |
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

### Editar y retirar (HU-20)

1. En «Mis rutinas», menú de la rutina → **Clientes asignados** abre `/coach/routines/:routineId/clients` con la rutina
   en `extra` (sin ella vuelve a la lista). Carga `GET /coach/routines/{id}/assignments`.
2. Cada cliente muestra su nombre y la fecha de asignación, con el ícono **Retirar**. Al tocarlo pide confirmación
   («¿Retirar «Torso A» de Ana? Dejará de verla en su app; sus sesiones completadas se conservan.»); al confirmar,
   `DELETE` y lo quita de la lista con el aviso «Rutina retirada de Ana».
3. `404 ASSIGNMENT_NOT_FOUND`: se quita igual y avisa que ya se había retirado. Sin red: `ErrorBanner` en la pantalla y
   el cliente se queda en la lista (RNF-11). Sin clientes: estado vacío.
4. **Editar** una rutina asignada: al tocar **Guardar** (después de la validación local) se consulta cuántos clientes la
   tienen; si son 1 o más, pregunta «Esta rutina está asignada a 2 clientes. Los cambios se verán en su app…» antes del
   `PUT`. Si la consulta falla, guarda sin preguntar.
5. **Eliminar** una rutina: antes del diálogo se consulta cuántos clientes la tienen; el mensaje agrega «Está asignada
   a 2 clientes: se les retirará; sus sesiones completadas se conservan.» (si la consulta falla, un aviso general).

### Asignar (HU-19)

1. En «Mis rutinas», menú de la rutina → **Asignar** abre `/coach/routines/:routineId/assign` con la rutina en `extra`
   (sin ella vuelve a la lista). Carga `GET /coach/clients` y `GET /coach/routines/{id}/assignments`.
2. Arriba, la rutina y su resumen; debajo, el buscador (filtra en memoria por nombre, sin acentos) y los clientes con
   casilla. Los que ya tienen la rutina se ven marcados, con «Ya asignada», y no se pueden tocar (no se envían otra vez).
   Si todos ya la tienen se indica.
3. **Asignar (n)** muestra el resumen («Torso A» se asignará a 2 clientes: • Ana • Bruno). Al confirmar, `POST`; con éxito
   aviso «Torso A» se asignó a 2 clientes. y regresa a la lista (CU-04 paso 6).
4. **Atrás** sin asignar regresa a la lista: la rutina ya estaba guardada (CU-04 5a).
5. Sin clientes vinculados: estado vacío que explica que primero debe vincularlos, con **Ver mi código de invitación**
   y **Actualizar**. Sin red: `ErrorState` + «Reintentar» al cargar, o `ErrorBanner` al asignar conservando la
   selección (RNF-11).
6. `403 CLIENT_NOT_LINKED` (no se asigna a nadie): «Bruno ya no tiene vinculación contigo. Actualizamos la lista…»; se
   recargan clientes y asignaciones, se quita solo al desvinculado de la selección y se puede volver a confirmar.

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
- HU-19 (acordadas con Erick): **Asignar** solo desde el menú de la rutina; ya asignados **marcados y bloqueados** (la
  API no tiene endpoint para quitar una asignación); con éxito, aviso y **regresa** a la lista; con `CLIENT_NOT_LINKED`
  se **conserva el resto** de la selección.
- HU-19: `AssignRoutineViewModel` usa el **dominio** de `clients` (`ClientsRepository`, `filterClientsByName`), no su
  capa de datos. Clientes y asignaciones se piden uno tras otro (si una falla, error con «Reintentar»). La confirmación
  se inyecta (`assign(confirm)`) para probar la cancelación. La pantalla nueva usa la guía visual de TEC-17
  (`LucideIcons`, `AppHeader`, `SurfaceCard`, `EmptyState`…); la lista y el constructor de HU-18 siguen con Material Icons.

## Pruebas

- `test/features/routines/domain/routine_validator_test.dart`: límites de cada campo y `validate` con todos los errores.
- `test/features/routines/data/routines_repository_impl_test.dart`: rutas, métodos, parámetros y cuerpo; `400` por
  campo, `ROUTINE_NOT_FOUND` y sin red.
- `test/features/routines/presentation/`: ViewModels de la lista (carga, vacío, errores, eliminar), del constructor
  (crear, editar, quitar, reordenar, validación, errores de la API) y del selector (filtros, selección, errores).
- `test/features/routines/presentation/assign_routine_view_model_test.dart` (HU-19): carga, sin clientes, sin conexión,
  ya asignados (marcados, no se envían), selección y búsqueda, confirmar/cancelar, éxito y `CLIENT_NOT_LINKED`.
- `test/features/routines/data/routines_repository_impl_test.dart` › asignaciones (HU-19): rutas, cuerpo, respuesta,
  `403` con su campo, `404` y sin red.
- `test/features/routines/presentation/routine_assignments_view_model_test.dart` (HU-20): clientes asignados, retirar,
  cancelar, ya retirada, sin conexión, aviso al editar (confirmar, cancelar, sin clientes, al crear, sin red) y al
  eliminar; `routines_repository_impl_test.dart` › retirar una asignación.
- `test/app/app_test.dart` › rutinas del coach (HU-18), asignar rutina a clientes (HU-19) y editar y retirar (HU-20); `test/app/router_test.dart`
  › rutinas del coach (incluye `/coach/routines/:id/assign`).

## Pendiente

- Prueba manual en un teléfono físico contra la API desplegada con el catálogo cargado (`seed_exercises`) y capturas
  para el PR.
- HU-19: prueba en un teléfono físico contra la API desplegada con dos cuentas (coach y cliente vinculado): la rutina
  asignada debe aparecer para el cliente en menos de 1 minuto (RF-23) en `GET /users/me/routines` o en la lista de
  HU-16-APP; capturas para el PR.
