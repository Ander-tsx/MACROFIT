## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| HU-24 | La app interpreta `GET /coach/clients`, incluidos `goal` y `last_meal_at` nulos. | Unitaria | Cada cliente se convierte con su meta (calorías, proteína y grasa redondeadas) y su origen, y con la fecha del último registro; los `null` llegan como "sin meta" y "sin registros"; los errores de la API salen como `ApiException`. | [**4**](#caso-01) (mobile 4 · backend 0) |
| HU-24 | La lista muestra nombre, meta vigente con su origen y último registro de cada cliente (RF-19). | Interfaz | Se ve `2200 kcal · P 160 g · G 70 g` con *Meta del coach* o *Meta calculada* y *Último registro: hoy, 14:30*, *ayer, 09:05* o *17/10/2026* (hora local); sin meta o sin registros lo indica. | [**7**](#caso-02) (mobile 7 · backend 0) |
| HU-24 | Búsqueda de clientes por nombre. | Unitaria | La búsqueda no distingue mayúsculas ni acentos (`jose` encuentra a *José*), ignora los espacios al inicio y al final, conserva el orden y no hace otra petición a la API. | [**7**](#caso-03) (mobile 7 · backend 0) |
| HU-24 | Lista vacía. | Interfaz | Un coach sin clientes vinculados ve un mensaje que lo invita a compartir su código de invitación, sin buscador ni error. | [**3**](#caso-04) (mobile 3 · backend 0) |
| HU-24 | Errores al cargar la lista. | Unitaria | Un error sin lista muestra el mensaje y **Reintentar**; un error al recargar conserva la lista y la búsqueda. | [**3**](#caso-05) (mobile 3 · backend 0) |
| HU-24 | Detalle del cliente con acceso a sus metas (HU-05) y a sus comidas (HU-25). | Interfaz | Al elegir un cliente se abre su detalle (solo para el rol `coach`); **Metas** abre el formulario de HU-05 y al regresar el resumen se actualiza; si el cliente ya no está vinculado lo indica; **Comidas** abre el registro diario de HU-25. | [**7**](#caso-06) (mobile 7 · backend 0) |
| HU-24 | La lista reemplaza la pantalla mínima de clientes de HU-05 sin romper sus flujos. | Interfaz | El coach llega al formulario de metas desde el detalle del cliente; guardar una meta y validar el formulario vacío siguen funcionando. | [**3**](#caso-07) (mobile 3 · backend 0) |
| HU-25 | La app interpreta `GET /coach/clients/{clientId}/meals` para el día pedido. | Unitaria | Pide `?date=AAAA-MM-DD` sin la hora; cada registro trae hora, valores finales y `photo_url`, que es `null` en una captura manual; un día sin registros es una lista vacía; `CLIENT_NOT_LINKED` sale como `ApiException`. | [**4**](#caso-08) (mobile 4 · backend 0) |
| HU-25 | Las fotos se descargan de `photo_url` con la sesión del coach. | Unitaria | `photo_url` se resuelve contra el host de la API y se pide con el mismo cliente HTTP con sesión (cabecera `Authorization`); cada foto se descarga una sola vez; una captura manual no pide foto; un error de descarga sale como `ApiException`. | [**4**](#caso-09) (mobile 4 · backend 0) |
| HU-25 | Desde el detalle se abren las comidas del día con hora, foto y valores, a 3 pantallas o menos de la principal (RF-20). | Interfaz | Lista → detalle → comidas; cada registro muestra la hora local, la foto o *Captura manual* y `413 kcal · P 42.2 g · G 4.9 g`, con el total del día; solo el rol `coach` abre la ruta. | [**8**](#caso-10) (mobile 8 · backend 0) |
| HU-25 | Cambio de día y día sin registros (CU-03 3a). | Unitaria | El coach cambia al día anterior o siguiente sin pasar de hoy, o elige una fecha (se ignora la hora y una fecha futura se lleva a hoy); un día sin registros lo indica y abre el calendario para elegir otra fecha. | [**7**](#caso-11) (mobile 7 · backend 0) |
| HU-25 | La pantalla es de solo lectura (RN-07). | Interfaz | No hay botón flotante ni opciones para agregar, editar o eliminar registros. | [**1**](#caso-12) (mobile 1 · backend 0) |
| HU-25 | Cliente desvinculado (RN-04) y sin conexión. | Unitaria | `403 CLIENT_NOT_LINKED` muestra que el cliente ya no está vinculado, sin tratarlo como error, y **Volver a mis clientes** regresa a la lista; sin conexión muestra el error y **Reintentar** vuelve a cargar el día. | [**5**](#caso-13) (mobile 5 · backend 0) |
| TEC-10 | Las 63 combinaciones de objetivo (3), nivel (3) y días por semana (1 a 7) generan una rutina válida (RF-14). | Unitaria | Con el catálogo de TEC-09, cada combinación devuelve una rutina con al menos un ejercicio por sesión, un ejercicio de cada grupo del foco de la sesión, sin ejercicios repetidos en una sesión y solo con ejercicios del catálogo. | [**1**](#caso-14) (mobile 0 · backend 1) |
| TEC-10 | La cantidad de sesiones no excede la disponibilidad (RF-14). | Unitaria | Se genera una sesión por día de entrenamiento (1 a 7); `training_days` fuera de 1 a 7 responde `InvalidTrainingDays`. | [**2**](#caso-15) (mobile 0 · backend 2) |
| TEC-10 | División por grupo muscular según los días. | Unitaria | 1–3 días: *Cuerpo completo*; 4 días: *Torso* / *Pierna* alternados; 5–7 días: *Empuje* / *Tirón* / *Pierna* en rotación; las sesiones se llaman `Día N · <foco>`; 1 ejercicio por grupo en cuerpo completo y 1 / 2 / 2–3 en las divisiones según el nivel. | [**5**](#caso-16) (mobile 0 · backend 5) |
| TEC-10 | Solo ejercicios del nivel del usuario o inferiores. | Unitaria | Ningún ejercicio supera el nivel del perfil y, a igual grupo, se eligen primero los del nivel del usuario. | [**2**](#caso-17) (mobile 0 · backend 2) |
| TEC-10 | Series, repeticiones y descanso por nivel y objetivo. | Unitaria | Series 2 / 3 / 4 (principiante / intermedio / avanzado); 10 reps y 90 s (`gain_muscle`), 12 reps y 60 s (`maintain`), 15 reps y 45 s (`lose_fat`); series y repeticiones mayores a cero (mismas reglas que HU-18-API). | [**1**](#caso-18) (mobile 0 · backend 1) |
| TEC-10 | Resultado determinista y catálogo incompleto. | Unitaria | El mismo perfil y catálogo dan la misma rutina aunque el catálogo llegue en otro orden; un grupo sin ejercicios elegibles (falta el grupo o solo hay ejercicios de nivel superior) responde `MissingExercises` con el grupo y el nivel, sin fallar. | [**4**](#caso-19) (mobile 0 · backend 4) |
| HU-06 | Acceso «Registrar comida» desde la pantalla principal (RF-05). | Interfaz | El botón flotante **Registrar comida** del inicio abre la pantalla de la foto con **Tomar foto** y **Elegir de la galería**; solo la abre un usuario con perfil (un coach, un usuario sin perfil o sin sesión son redirigidos) y el coach no ve el botón. | [**4**](#caso-20) (mobile 4 · backend 0) |
| HU-06 | Tomar o elegir la foto, comprimirla y verla (RF-05, CU-01 pasos 1 y 2). | Unitaria | Se pide la foto al origen elegido con lado mayor de 1600 px y calidad menor a 100; queda en la vista previa; cancelar el selector conserva la foto anterior y elegir otra la reemplaza. | [**6**](#caso-21) (mobile 6 · backend 0) |
| HU-06 | Permisos de cámara y galería negados (CU-01 flujo 2a). | Unitaria | `camera_access_denied`/`restricted`, `photo_access_denied` y `no_available_camera` se traducen a su error; el permiso de cámara negado explica cómo habilitarlo en Ajustes y ofrece la galería, el de fotos muestra un mensaje explicativo y sin cámara se ofrece la galería. | [**9**](#caso-22) (mobile 9 · backend 0) |
| HU-06 | Reglas de TEC-13 antes de subir: JPEG o PNG y máximo 5 MiB. | Unitaria | Se aceptan JPEG y PNG por sus primeros bytes y una foto de exactamente 5 MiB; se rechaza una de más de 5 MiB (antes de revisar el tipo), otro formato (GIF, HEIC) o una vacía; una foto rechazada no se sube ni reemplaza a la anterior. | [**7**](#caso-23) (mobile 7 · backend 0) |
| HU-06 | Subida a `POST /meals/photos` y el id para HU-07. | Unitaria | La foto va en el campo `photo` de un `multipart/form-data`; la respuesta `{ id, format, size_bytes }` se convierte a la entidad y el ViewModel conserva el `id`; sin foto no se llama a la API y una foto subida no se vuelve a subir ni se cambia. | [**5**](#caso-24) (mobile 5 · backend 0) |
| HU-06 | Errores de la subida (RNF-11). | Unitaria | `413 PHOTO_TOO_LARGE`, `415 UNSUPPORTED_PHOTO_TYPE` y la falta de conexión salen como `ApiException` y muestran un mensaje en español; la foto se conserva y **Usar esta foto** vuelve a intentarlo. | [**6**](#caso-25) (mobile 6 · backend 0) |
| HU-06 | Foto recuperada si Android cierra la app con la cámara abierta. | Unitaria | Al arrancar se recupera una sola vez la foto pendiente (`retrieveLostData`); sin foto, en iOS o si la captura terminó en error no hay foto; con foto, el inicio abre **Registrar comida** con la vista previa y **atrás** regresa al inicio. | [**8**](#caso-26) (mobile 8 · backend 0) |
| HU-26 | Meta vigente en la pantalla principal con su origen (RF-04, RF-21, RN-06). | Interfaz | Al entrar al inicio se consulta `GET /users/me/goals/current` y se muestran calorías, proteína y grasa (`1831 kcal`, `145 g`, `51 g`) con *Calculada* para `source: system` o *Definida por tu coach* para `source: coach`. | [**4**](#caso-27) (mobile 4 · backend 0) |
| HU-26 | Usuario sin meta (`404 PROFILE_NOT_FOUND`). | Unitaria | Sin perfil ni meta del coach se muestra un mensaje que invita a completar el perfil o pedir una meta al coach, sin tratarlo como error ni ofrecer **Reintentar**; antes de la primera consulta no se considera que falte la meta. | [**3**](#caso-28) (mobile 3 · backend 0) |
| HU-26 | Sin conexión al consultar la meta (RNF-11). | Unitaria | La falta de conexión muestra el mensaje en español con **Reintentar**, que vuelve a consultar; si falla una recarga se conserva la última meta; no se lanza una segunda consulta mientras otra está en curso. | [**4**](#caso-29) (mobile 4 · backend 0) |
| HU-26 | La meta se actualiza al regresar de editar el perfil (recálculo de HU-04). | Interfaz | Al volver de **Mi perfil** (y al deslizar para actualizar) se consulta de nuevo y se ve la meta recalculada. | [**2**](#caso-30) (mobile 2 · backend 0) |
| HU-07 | La app llama a `POST /meals/estimate` con el `photo_id` e interpreta la respuesta. | Unitaria | Se manda `{ photo_id }` de la foto subida en HU-06; `foods` (nombre, `grams` que puede ser `null` y valores) y `totals` se convierten a la entidad; el modelo lee y escribe los nombres de la API. | [**4**](#caso-31) (mobile 4 · backend 0) |
| HU-07 | Estado de carga y resultado de la estimación (RF-06, CU-01 pasos 3 y 4). | Interfaz | **Usar esta foto** abre la estimación, que muestra la carga hasta recibir respuesta y después cada alimento (nombre, gramos si vienen, valores) y los totales `413 kcal`, `42.2 g`, `4.9 g`; con la estimación lista no se vuelve a pedir. | [**4**](#caso-32) (mobile 4 · backend 0) |
| HU-07 | Leyenda de estimación (RNF-07, RN-09). | Interfaz | El resultado muestra *Estos valores son una estimación a partir de la foto y no una recomendación médica*. | [**1**](#caso-33) (mobile 1 · backend 0) |
| HU-07 | Comida no reconocida (CU-01 flujo 4a). | Unitaria | `422 FOOD_NOT_RECOGNIZED` muestra el mensaje y ofrece solo **Capturar a mano** (sin **Reintentar**). | [**2**](#caso-34) (mobile 2 · backend 0) |
| HU-07 | Fallo del proveedor o sin conexión (CU-01 flujo 3a, RNF-11). | Unitaria | `502`, `504`, `404` y la falta de conexión salen como `ApiException`; `502`, `504`, sin conexión y otros errores muestran un mensaje en español y ofrecen **Reintentar** o **Capturar a mano** sin cerrar la pantalla; **Reintentar** vuelve a estimar la misma foto. | [**10**](#caso-35) (mobile 10 · backend 0) |
| HU-07 | Ruta de la estimación. | Unitaria | Solo un usuario con perfil abre `/user/meals/estimate` (un coach, un usuario sin perfil o sin sesión son redirigidos); atrás regresa al inicio y no a la foto ya subida. | [**3**](#caso-36) (mobile 3 · backend 0) |
| HU-08 | Formulario precargado y editable (RF-07, CU-01 paso 5). | Interfaz | **Continuar** abre *Revisar valores* con `413`, `42.2` y `4.9` en calorías, proteína y grasa, los tres editables. | [**2**](#caso-37) (mobile 2 · backend 0) |
| HU-08 | Validación local con los rangos de la API. | Unitaria | Solo números no negativos (con punto o coma decimal); calorías de 0 a 10 000 y proteína y grasa de 0 a 1 000 g, con el 0 y los límites aceptados; vacío, texto, negativos o fuera de rango marcan su campo, no llaman a la API, y editar el campo limpia su error. | [**9**](#caso-38) (mobile 9 · backend 0) |
| HU-08 | Valores finales y estimados (`estimated`). | Unitaria | Sin corrección se mandan los mismos valores como finales y en `estimated` (el estimado exacto, aunque el campo lo muestre redondeado); con corrección `estimated` conserva lo estimado y los finales llevan lo corregido. | [**4**](#caso-39) (mobile 4 · backend 0) |
| HU-08 | Captura manual (CU-01 flujos 3a y 4a). | Unitaria | **Capturar a mano** (tras un fallo de la estimación) y **Capturar sin foto** abren el mismo formulario vacío; se guarda sin `estimated`, con `photo_id` solo si hay foto. | [**5**](#caso-40) (mobile 5 · backend 0) |
| HU-08 | Errores del guardado. | Unitaria | `400 VALIDATION_ERROR` marca cada campo con `applyApiError`, incluidos `estimated.<campo>` (*Valor estimado: …*); `409`, `404` y la falta de conexión muestran el mensaje sin perder los valores; un registro guardado no se vuelve a enviar. | [**6**](#caso-41) (mobile 6 · backend 0) |
| HU-08 | Ruta del formulario. | Unitaria | Solo un usuario con perfil abre `/user/meals/form` (un coach, un usuario sin perfil o sin sesión son redirigidos). | [**2**](#caso-42) (mobile 2 · backend 0) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. el flujo de la lista al formulario de metas cuenta en el detalle y en el reemplazo de la pantalla de HU-05).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar HU-24-APP: **146** pruebas mobile (`flutter test`). Al cerrar el Sprint 2 eran 119; HU-24-APP agrega 30 y retira 3 que probaban la pantalla mínima de clientes de HU-05, que se eliminó (las 2 del `CoachClientsViewModel` y *lista los clientes vinculados* de `CoachGoalsRepositoryImpl`; ahora las cubren los casos 01, 02 y 05). Sin cambios en el backend.
Inventario al cerrar HU-25-APP: **173** pruebas mobile (`flutter test`). HU-25-APP agrega 27 (6 de datos, 4 de textos, 9 del ViewModel, 2 de rutas y 6 de widgets) y cambia *el detalle da acceso a las metas y a las comidas* (caso 06) para comprobar que **Comidas** está habilitado. Sin cambios en el backend.
Inventario al cerrar TEC-10: **235** pruebas de Rust (`cargo test`: 217 se ejecutan y 18 requieren MongoDB y se ejecutan con `--ignored`). TEC-10 agrega 15 pruebas de Rust en `backend/src/services/routine_engine.rs`. No tiene endpoint (lo expone HU-15-API), así que la colección de Postman y la app no cambian.
Inventario al cerrar HU-06-APP: **243** pruebas mobile (`flutter test`; 198 en `develop` con HU-12-APP). HU-06-APP agrega 45 (5 del validador, 15 de datos, 17 del ViewModel, 2 de rutas y 5 de widgets). Sin cambios en el backend. Además se probó a mano en un teléfono Android contra la API desplegada (no se cuenta).
Inventario al cerrar HU-26-APP: **256** pruebas mobile (`flutter test`; 243 en `develop` con HU-06-APP). HU-26-APP agrega 13 (8 del ViewModel y 5 de widgets). Sin cambios en el backend. Además se probó de punta a punta en el simulador de iPhone 16 contra el backend local con base temporal (no se cuenta).
Inventario al cerrar HU-07-APP: **279** pruebas mobile (`flutter test`; 256 en `develop` con HU-26-APP). HU-07-APP agrega 23 (8 de datos, 8 de ViewModels, 2 de rutas y 5 de widgets) y cambia *elige de la galería, muestra la vista previa y la sube* (HU-06) para comprobar que la foto subida abre la estimación. Sin cambios en el backend. Además se probó a mano en un teléfono Android (moto g60) contra el backend de `develop` en local con `FOOD_SIMULATOR_MODE` `ok`, `not_recognized`, `error` y `timeout`, y sin conexión (no se cuenta); la API desplegada aún no tiene `POST /meals/estimate`.
Inventario al cerrar HU-08-APP: **307** pruebas mobile (`flutter test`; 279 en `develop` con HU-07-APP). HU-08-APP agrega 28 (6 del validador, 3 de datos, 13 del ViewModel, 2 de rutas y 4 de widgets). Sin cambios en el backend. Además se probó a mano en un teléfono Android (moto g60) contra el backend de `develop` en local: guardado sin y con corrección, captura manual con foto (tras `422`) y sin foto, revisando en MongoDB los finales y `estimated` (no se cuenta).

## Detalle de las pruebas por caso

### <a id="caso-01"></a>Caso 01 · HU-24 — Modelo JSON de la lista de clientes

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/data/clients_repository_impl_test.dart` › lista los clientes con su meta vigente y su último registro
- `macrofit_app/test/features/clients/data/clients_repository_impl_test.dart` › un cliente sin metas ni registros llega con goal y last_meal_at nulos
- `macrofit_app/test/features/clients/data/clients_repository_impl_test.dart` › una meta calculada conserva su origen y redondea los valores
- `macrofit_app/test/features/clients/data/clients_repository_impl_test.dart` › una cuenta que no es coach recibe FORBIDDEN_ROLE

### <a id="caso-02"></a>Caso 02 · HU-24 — Nombre, meta vigente con su origen y último registro

Mobile: 7 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/presentation/client_summary_texts_test.dart` › resume la meta con calorías, proteína y grasa
- `macrofit_app/test/features/clients/presentation/client_summary_texts_test.dart` › indica el origen de la meta
- `macrofit_app/test/features/clients/presentation/client_summary_texts_test.dart` › sin meta lo indica
- `macrofit_app/test/features/clients/presentation/client_summary_texts_test.dart` › el último registro de hoy o de ayer muestra la hora local
- `macrofit_app/test/features/clients/presentation/client_summary_texts_test.dart` › sin registros lo indica
- `macrofit_app/test/features/clients/presentation/clients_list_view_model_test.dart` › load trae los clientes vinculados con su resumen
- `macrofit_app/test/app/app_test.dart` › lista de clientes (HU-24) › muestra nombre, meta y último registro de cada cliente

### <a id="caso-03"></a>Caso 03 · HU-24 — Búsqueda por nombre

Mobile: 7 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/domain/filter_clients_by_name_test.dart` › sin texto de búsqueda devuelve a todos en el mismo orden
- `macrofit_app/test/features/clients/domain/filter_clients_by_name_test.dart` › no distingue mayúsculas de minúsculas
- `macrofit_app/test/features/clients/domain/filter_clients_by_name_test.dart` › no distingue acentos en el nombre ni en la búsqueda
- `macrofit_app/test/features/clients/domain/filter_clients_by_name_test.dart` › ignora los espacios al inicio y al final
- `macrofit_app/test/features/clients/domain/filter_clients_by_name_test.dart` › sin coincidencias devuelve una lista vacía
- `macrofit_app/test/features/clients/presentation/clients_list_view_model_test.dart` › la búsqueda filtra por nombre sin hacer otra petición
- `macrofit_app/test/app/app_test.dart` › lista de clientes (HU-24) › la búsqueda filtra por nombre sin otra petición

### <a id="caso-04"></a>Caso 04 · HU-24 — Lista vacía

Mobile: 3 · Backend: 0

Con HU-12-INT, *sin clientes invita a compartir el código de invitación* además toca **Ver mi código de invitación**, comprueba que se abre la pantalla del código (HU-12) con el código del coach y que atrás regresa a la lista vacía sin volver a pedirla.

**Mobile**

- `macrofit_app/test/features/clients/presentation/clients_list_view_model_test.dart` › un coach sin clientes ve la lista vacía y no un error
- `macrofit_app/test/features/clients/presentation/clients_list_view_model_test.dart` › antes de cargar no se considera una lista vacía
- `macrofit_app/test/app/app_test.dart` › lista de clientes (HU-24) › sin clientes invita a compartir el código de invitación

### <a id="caso-05"></a>Caso 05 · HU-24 — Errores al cargar la lista

Mobile: 3 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/presentation/clients_list_view_model_test.dart` › load muestra el error y permite reintentar
- `macrofit_app/test/features/clients/presentation/clients_list_view_model_test.dart` › un error al recargar conserva la lista y la búsqueda
- `macrofit_app/test/app/app_test.dart` › lista de clientes (HU-24) › un error al cargar permite reintentar

### <a id="caso-06"></a>Caso 06 · HU-24 — Detalle del cliente con acceso a metas y comidas

Mobile: 7 · Backend: 0

Con HU-25-APP, *el detalle da acceso a las metas y a las comidas* comprueba que **Comidas** está habilitado; antes comprobaba que estaba deshabilitado. La pantalla de comidas se prueba en los casos 08 a 13.

**Mobile**

- `macrofit_app/test/features/clients/presentation/client_detail_view_model_test.dart` › refresh actualiza el resumen del cliente
- `macrofit_app/test/features/clients/presentation/client_detail_view_model_test.dart` › si el cliente ya no aparece en la lista, indica que se desvinculó
- `macrofit_app/test/features/clients/presentation/client_detail_view_model_test.dart` › un error al recargar conserva los datos y lo informa
- `macrofit_app/test/app/router_test.dart` › clientes del coach (HU-24) › un coach abre el detalle de un cliente
- `macrofit_app/test/app/router_test.dart` › clientes del coach (HU-24) › un usuario no accede al detalle de un cliente
- `macrofit_app/test/app/app_test.dart` › lista de clientes (HU-24) › el detalle da acceso a las metas y a las comidas
- `macrofit_app/test/app/app_test.dart` › metas por coach (HU-05) › el coach llega al formulario de un cliente desde su detalle

### <a id="caso-07"></a>Caso 07 · HU-24 — Reemplazo de la pantalla mínima de clientes de HU-05

Mobile: 3 · Backend: 0

Las pruebas de HU-05 ahora pasan por el detalle del cliente antes de abrir el formulario; sus verificaciones no cambian.

**Mobile**

- `macrofit_app/test/app/app_test.dart` › metas por coach (HU-05) › el coach llega al formulario de un cliente desde su detalle
- `macrofit_app/test/app/app_test.dart` › metas por coach (HU-05) › guarda la meta y la muestra en el historial
- `macrofit_app/test/app/app_test.dart` › metas por coach (HU-05) › un formulario vacío no se envía y señala los campos

### <a id="caso-08"></a>Caso 08 · HU-25 — Comidas del cliente desde la API

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › pide las comidas del cliente para el día en formato AAAA-MM-DD
- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › una captura manual llega sin foto
- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › un día sin registros devuelve una lista vacía
- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › un cliente desvinculado responde CLIENT_NOT_LINKED

### <a id="caso-09"></a>Caso 09 · HU-25 — Fotos con la sesión del coach

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › descarga la foto de photo_url con el cliente HTTP con sesión
- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › una foto que no se puede descargar lanza ApiException
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › cada foto se descarga una sola vez
- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › desde el detalle se abren las comidas del día con hora, foto y valores

### <a id="caso-10"></a>Caso 10 · HU-25 — Comidas del día con hora, foto y valores (RF-20)

Mobile: 8 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/presentation/client_meal_texts_test.dart` › las cantidades llevan a lo más un decimal
- `macrofit_app/test/features/clients/presentation/client_meal_texts_test.dart` › resume calorías, proteína y grasa del registro
- `macrofit_app/test/features/clients/presentation/client_meal_texts_test.dart` › la hora del registro se muestra en hora local
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › empieza en el día de hoy y trae sus registros
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › suma los valores del día
- `macrofit_app/test/app/router_test.dart` › comidas de un cliente (HU-25) › un coach abre las comidas de un cliente
- `macrofit_app/test/app/router_test.dart` › comidas de un cliente (HU-25) › un usuario no accede a las comidas de un cliente
- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › desde el detalle se abren las comidas del día con hora, foto y valores

### <a id="caso-11"></a>Caso 11 · HU-25 — Cambio de día y día sin registros (CU-03 3a)

Mobile: 7 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/presentation/client_meal_texts_test.dart` › el día elegido se nombra hoy, ayer o con su fecha
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › un día sin registros lo indica
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › antes de cargar no se considera un día vacío
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › cambia al día anterior y vuelve, sin pasar de hoy
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › elegir una fecha carga ese día e ignora la hora y el futuro
- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › un día sin registros lo indica y permite elegir otra fecha
- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › el coach cambia al día anterior

### <a id="caso-12"></a>Caso 12 · HU-25 — Solo lectura (RN-07)

Mobile: 1 · Backend: 0

**Mobile**

- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › es de solo lectura

### <a id="caso-13"></a>Caso 13 · HU-25 — Cliente desvinculado (RN-04) y sin conexión

Mobile: 5 · Backend: 0

**Mobile**

- `macrofit_app/test/features/clients/data/client_meals_repository_test.dart` › un cliente desvinculado responde CLIENT_NOT_LINKED
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › un cliente desvinculado se indica y no queda como error
- `macrofit_app/test/features/clients/presentation/client_meals_view_model_test.dart` › sin conexión muestra el error y permite reintentar
- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › un cliente desvinculado lo indica y regresa a la lista
- `macrofit_app/test/app/app_test.dart` › comidas de un cliente (HU-25) › sin conexión muestra el error y permite reintentar

### <a id="caso-14"></a>Caso 14 · TEC-10 — Las 63 combinaciones generan una rutina válida (RF-14)

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `las_63_combinaciones_generan_una_rutina_valida`

### <a id="caso-15"></a>Caso 15 · TEC-10 — Sesiones según la disponibilidad (RF-14)

Mobile: 0 · Backend: 2

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `el_numero_de_sesiones_es_igual_a_los_dias_de_entrenamiento`
- `backend/src/services/routine_engine.rs` › `dias_fuera_de_1_a_7_responden_error`

### <a id="caso-16"></a>Caso 16 · TEC-10 — División por grupo muscular

Mobile: 0 · Backend: 5

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `de_1_a_3_dias_es_cuerpo_completo`
- `backend/src/services/routine_engine.rs` › `con_4_dias_alterna_torso_y_pierna`
- `backend/src/services/routine_engine.rs` › `de_5_a_7_dias_rota_empuje_tiron_y_pierna`
- `backend/src/services/routine_engine.rs` › `las_sesiones_se_numeran_con_su_foco`
- `backend/src/services/routine_engine.rs` › `ejercicios_por_grupo_segun_nivel_y_sesion`

### <a id="caso-17"></a>Caso 17 · TEC-10 — Ejercicios del nivel del usuario o inferiores

Mobile: 0 · Backend: 2

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `solo_elige_ejercicios_del_nivel_del_usuario_o_inferiores`
- `backend/src/services/routine_engine.rs` › `prefiere_los_ejercicios_del_nivel_del_usuario`

### <a id="caso-18"></a>Caso 18 · TEC-10 — Series, repeticiones y descanso

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `series_por_nivel_y_repeticiones_y_descanso_por_objetivo`

### <a id="caso-19"></a>Caso 19 · TEC-10 — Determinismo y catálogo incompleto

Mobile: 0 · Backend: 4

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `mismo_perfil_y_catalogo_dan_la_misma_rutina`
- `backend/src/services/routine_engine.rs` › `el_orden_del_catalogo_no_cambia_la_rutina`
- `backend/src/services/routine_engine.rs` › `catalogo_sin_un_grupo_responde_error_propio`
- `backend/src/services/routine_engine.rs` › `catalogo_sin_ejercicios_del_nivel_responde_error_propio`
### <a id="caso-20"></a>Caso 20 · HU-06 — Acceso «Registrar comida»

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/app/router_test.dart` › foto de la comida (HU-06) › un usuario con perfil abre "Registrar comida"
- `macrofit_app/test/app/router_test.dart` › foto de la comida (HU-06) › un coach, un usuario sin perfil o sin sesión no la abren
- `macrofit_app/test/app/app_test.dart` › foto de la comida (HU-06) › "Registrar comida" abre la pantalla de la foto
- `macrofit_app/test/app/app_test.dart` › foto de la comida (HU-06) › un coach no ve el acceso a registrar comida

### <a id="caso-21"></a>Caso 21 · HU-06 — Tomar o elegir la foto, comprimirla y verla

Mobile: 6 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › pide la foto comprimida al origen elegido
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › cancelar devuelve null
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › con permiso, la foto de la cámara queda en la vista previa
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › cancelar conserva la foto anterior
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › cambiar la foto reemplaza la vista previa
- `macrofit_app/test/app/app_test.dart` › foto de la comida (HU-06) › elige de la galería, muestra la vista previa y la sube

### <a id="caso-22"></a>Caso 22 · HU-06 — Permisos de cámara y galería negados

Mobile: 9 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › el error camera_access_denied se traduce a PhotoPickError.cameraDenied
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › el error camera_access_restricted se traduce a PhotoPickError.cameraDenied
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › el error photo_access_denied se traduce a PhotoPickError.galleryDenied
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › el error no_available_camera se traduce a PhotoPickError.cameraUnavailable
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › cámara y galería › un fallo desconocido de la galería se trata como sin acceso
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › permiso de cámara negado: explica cómo habilitarlo y ofrece la galería
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › permiso de galería negado muestra un mensaje explicativo
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › sin cámara disponible ofrece la galería
- `macrofit_app/test/app/app_test.dart` › foto de la comida (HU-06) › con el permiso de cámara negado explica y ofrece la galería

### <a id="caso-23"></a>Caso 23 · HU-06 — Reglas de TEC-13 antes de subir

Mobile: 7 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/domain/meal_photo_validator_test.dart` › acepta JPEG y PNG por su contenido
- `macrofit_app/test/features/meals/domain/meal_photo_validator_test.dart` › acepta una foto de exactamente 5 MiB
- `macrofit_app/test/features/meals/domain/meal_photo_validator_test.dart` › rechaza una foto de más de 5 MiB antes de revisar el tipo
- `macrofit_app/test/features/meals/domain/meal_photo_validator_test.dart` › rechaza lo que no es JPEG ni PNG (p. ej. GIF o HEIC)
- `macrofit_app/test/features/meals/domain/meal_photo_validator_test.dart` › rechaza una foto vacía
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › una foto de más de 5 MiB no se acepta ni se sube
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › elegir la foto › una foto que no es JPEG ni PNG no reemplaza a la anterior

### <a id="caso-24"></a>Caso 24 · HU-06 — Subida a `POST /meals/photos` y el id para HU-07

Mobile: 5 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › subida (POST /meals/photos) › manda la foto en el campo photo como multipart
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › el modelo lee y escribe los nombres de la API
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › sin foto no hace nada
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › subida correcta conserva el id para HU-07
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › después de subirla no se vuelve a subir ni se cambia

### <a id="caso-25"></a>Caso 25 · HU-06 — Errores de la subida

Mobile: 6 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › subida (POST /meals/photos) › 413 se traduce a ApiException PHOTO_TOO_LARGE
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › subida (POST /meals/photos) › 415 se traduce a ApiException UNSUPPORTED_PHOTO_TYPE
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › subida (POST /meals/photos) › sin conexión lanza NETWORK_ERROR
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › 413 PHOTO_TOO_LARGE muestra un mensaje en español
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › 415 UNSUPPORTED_PHOTO_TYPE muestra un mensaje en español
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › sin conexión muestra el error y permite reintentar

### <a id="caso-26"></a>Caso 26 · HU-06 — Foto recuperada si Android cierra la app con la cámara abierta

Mobile: 8 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › foto perdida (Android cerró la app con la cámara abierta) › se recupera una vez y después ya no está
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › foto perdida (Android cerró la app con la cámara abierta) › sin foto pendiente no hay nada que recuperar
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › foto perdida (Android cerró la app con la cámara abierta) › en plataformas sin soporte (iOS) no falla
- `macrofit_app/test/features/meals/data/meal_photo_repository_impl_test.dart` › foto perdida (Android cerró la app con la cámara abierta) › si la captura perdida terminó en error no hay foto
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › foto recuperada › se muestra en la vista previa y se puede subir
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › foto recuperada › sin foto recuperada la pantalla empieza vacía
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › foto recuperada › una foto recuperada que no cumple TEC-13 muestra el motivo
- `macrofit_app/test/app/app_test.dart` › foto de la comida (HU-06) › si Android cerró la app con la cámara abierta vuelve a la vista previa

### <a id="caso-27"></a>Caso 27 · HU-26 — Meta vigente con su origen

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › loadGoal trae la meta calculada por el sistema
- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › loadGoal trae la meta definida por el coach
- `macrofit_app/test/app/app_test.dart` › meta vigente en la pantalla principal (HU-26) › muestra la meta calculada con su origen
- `macrofit_app/test/app/app_test.dart` › meta vigente en la pantalla principal (HU-26) › indica cuando la meta la definió el coach

### <a id="caso-28"></a>Caso 28 · HU-26 — Usuario sin meta

Mobile: 3 · Backend: 0

**Mobile**

- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › sin meta (404 PROFILE_NOT_FOUND) no se considera un error
- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › antes de cargar no se considera que no haya meta
- `macrofit_app/test/app/app_test.dart` › meta vigente en la pantalla principal (HU-26) › sin meta muestra un mensaje y no un error

### <a id="caso-29"></a>Caso 29 · HU-26 — Sin conexión y reintento

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › sin conexión muestra el error y permite reintentar
- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › un error al recargar conserva la última meta
- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › no lanza una segunda consulta mientras otra está en curso
- `macrofit_app/test/app/app_test.dart` › meta vigente en la pantalla principal (HU-26) › sin conexión muestra el error y reintenta

### <a id="caso-30"></a>Caso 30 · HU-26 — Meta recalculada al regresar del perfil

Mobile: 2 · Backend: 0

**Mobile**

- `macrofit_app/test/features/home/presentation/user_home_view_model_test.dart` › al recargar refleja la meta recalculada (HU-04)
- `macrofit_app/test/app/app_test.dart` › meta vigente en la pantalla principal (HU-26) › al regresar de Mi perfil se vuelve a consultar la meta

### <a id="caso-31"></a>Caso 31 · HU-07 — Llamada a `POST /meals/estimate` y modelo de la estimación

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › manda el photo_id y convierte alimentos y totales a la entidad
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › grams nulo llega como porción desconocida
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › el modelo lee y escribe los nombres de la API
- `macrofit_app/test/features/meals/presentation/meal_photo_view_model_test.dart` › subir la foto › el resultado une la foto y su id para la estimación

### <a id="caso-32"></a>Caso 32 · HU-07 — Estado de carga y resultado de la estimación

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › muestra la carga mientras estima y después los alimentos y totales
- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › con la estimación lista no vuelve a pedirla
- `macrofit_app/test/app/app_test.dart` › estimación nutricional (HU-07) › al usar la foto estima con su id, muestra la carga y después el resultado
- `macrofit_app/test/app/app_test.dart` › foto de la comida (HU-06) › elige de la galería, muestra la vista previa y la sube

### <a id="caso-33"></a>Caso 33 · HU-07 — Leyenda de estimación

Mobile: 1 · Backend: 0

**Mobile**

- `macrofit_app/test/app/app_test.dart` › estimación nutricional (HU-07) › el resultado muestra la leyenda de estimación (RNF-07)

### <a id="caso-34"></a>Caso 34 · HU-07 — Comida no reconocida

Mobile: 2 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › 422 FOOD_NOT_RECOGNIZED ofrece solo la captura manual
- `macrofit_app/test/app/app_test.dart` › estimación nutricional (HU-07) › comida no reconocida ofrece solo capturar a mano

### <a id="caso-35"></a>Caso 35 · HU-07 — Fallo del proveedor o sin conexión

Mobile: 10 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › 422 se traduce a ApiException FOOD_NOT_RECOGNIZED
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › 502 se traduce a ApiException FOOD_PROVIDER_ERROR
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › 504 se traduce a ApiException FOOD_PROVIDER_TIMEOUT
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › 404 se traduce a ApiException PHOTO_NOT_FOUND
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › estimación (POST /meals/estimate) › sin conexión lanza NETWORK_ERROR
- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › 502 FOOD_PROVIDER_ERROR ofrece reintentar o capturar a mano
- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › 504 FOOD_PROVIDER_TIMEOUT ofrece reintentar o capturar a mano
- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › sin conexión ofrece reintentar y el reintento estima
- `macrofit_app/test/features/meals/presentation/meal_estimate_view_model_test.dart` › otro error muestra el mensaje del servidor y permite reintentar
- `macrofit_app/test/app/app_test.dart` › estimación nutricional (HU-07) › sin conexión ofrece reintentar sin cerrar la pantalla

### <a id="caso-36"></a>Caso 36 · HU-07 — Ruta de la estimación

Mobile: 3 · Backend: 0

**Mobile**

- `macrofit_app/test/app/router_test.dart` › estimación nutricional (HU-07) › un usuario con perfil abre la estimación
- `macrofit_app/test/app/router_test.dart` › estimación nutricional (HU-07) › un coach, un usuario sin perfil o sin sesión no la abren
- `macrofit_app/test/app/app_test.dart` › estimación nutricional (HU-07) › atrás regresa al inicio, no a la foto ya subida

### <a id="caso-37"></a>Caso 37 · HU-08 — Formulario precargado y editable

Mobile: 2 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › con estimación › se precarga con las calorías, proteína y grasa estimadas
- `macrofit_app/test/app/app_test.dart` › formulario de valores (HU-08) › Continuar abre el formulario precargado y Guardar registra lo corregido

### <a id="caso-38"></a>Caso 38 · HU-08 — Validación local con los rangos de la API

Mobile: 9 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/domain/meal_values_validator_test.dart` › el 0 y los límites exactos son válidos
- `macrofit_app/test/features/meals/domain/meal_values_validator_test.dart` › acepta decimales con punto o coma y espacios alrededor
- `macrofit_app/test/features/meals/domain/meal_values_validator_test.dart` › un valor vacío es obligatorio
- `macrofit_app/test/features/meals/domain/meal_values_validator_test.dart` › un texto que no es número se rechaza
- `macrofit_app/test/features/meals/domain/meal_values_validator_test.dart` › los negativos se rechazan
- `macrofit_app/test/features/meals/domain/meal_values_validator_test.dart` › por encima del rango de la API se rechaza
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › la validación local marca cada campo y no llama a la API
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › editar un campo limpia su error
- `macrofit_app/test/app/app_test.dart` › formulario de valores (HU-08) › la validación local muestra el error junto a cada campo

### <a id="caso-39"></a>Caso 39 · HU-08 — Valores finales y estimados

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › con estimación › sin corrección manda los mismos valores como finales y en estimated
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › con estimación › sin corrección conserva el estimado exacto aunque se muestre redondeado
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › con estimación › con corrección, estimated conserva lo estimado y los finales lo corregido
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › registro (POST /meals) › con estimación manda photo_id, los finales planos y estimated

### <a id="caso-40"></a>Caso 40 · HU-08 — Captura manual

Mobile: 5 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › captura manual › tras un fallo de la estimación empieza vacía y se manda con la foto y sin estimated
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › captura manual › sin foto se manda sin photo_id ni estimated
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › registro (POST /meals) › una captura manual sin foto no manda photo_id ni estimated
- `macrofit_app/test/app/app_test.dart` › formulario de valores (HU-08) › comida no reconocida: Capturar a mano abre el formulario vacío y guarda sin estimated
- `macrofit_app/test/app/app_test.dart` › formulario de valores (HU-08) › Capturar sin foto abre el formulario vacío y guarda sin foto

### <a id="caso-41"></a>Caso 41 · HU-08 — Errores del guardado

Mobile: 6 · Backend: 0

**Mobile**

- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › 400 VALIDATION_ERROR marca cada campo, incluidos los de estimated
- `macrofit_app/test/features/meals/data/meals_repository_impl_test.dart` › registro (POST /meals) › 400 VALIDATION_ERROR trae los campos de estimated
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › 409 PHOTO_ALREADY_USED muestra el mensaje sin perder los valores
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › 404 PHOTO_NOT_FOUND muestra el mensaje sin perder los valores
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › sin conexión muestra el error y permite reintentar
- `macrofit_app/test/features/meals/presentation/meal_form_view_model_test.dart` › errores › un registro guardado no se vuelve a enviar

### <a id="caso-42"></a>Caso 42 · HU-08 — Ruta del formulario

Mobile: 2 · Backend: 0

**Mobile**

- `macrofit_app/test/app/router_test.dart` › formulario de valores (HU-08) › un usuario con perfil abre el formulario
- `macrofit_app/test/app/router_test.dart` › formulario de valores (HU-08) › un coach, un usuario sin perfil o sin sesión no lo abren
