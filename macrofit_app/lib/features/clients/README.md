# `features/clients/` — clientes del coach

## Historias

- **HU-24**: "Como coach, quiero ver la lista de mis clientes para acceder a su información." (RF-19, RN-03, CU-03
  pasos 1 y 2). Reemplaza la lista mínima de clientes que dejó HU-05 en `features/goals`.
- **HU-25**: "Como coach, quiero consultar el registro diario de comidas de un cliente para revisar su alimentación."
  (RF-20, RN-04, RN-07, RNF-05, CU-03 paso 3). Solo lectura.
- **HU-23**: "Como coach, quiero ver el progreso histórico de mi cliente." (RF-25, RN-04, RNF-11). Solo lectura.

## Archivos

| Capa | Archivo | Contenido |
|---|---|---|
| Dominio | `entities/client_summary.dart` | `ClientSummary` (extiende `CoachClient` de `goals`) con `goal` (`ClientGoalSummary`) y `lastMealAt`, ambos opcionales |
| | `entities/client_meal.dart` | `ClientMeal`: hora, valores finales y `photoUrl` (`null` en una captura manual) |
| | `repositories/clients_repository.dart` | `getClients()`, `getClientMeals(clientId, date)` y `getMealPhoto(photoUrl)` |
| | `usecases/filter_clients_by_name.dart` | Búsqueda por nombre sin distinguir mayúsculas ni acentos (`normalizeForSearch`) |
| Datos | `datasources/clients_remote_data_source.dart` | `GET /coach/clients`, `GET /coach/clients/{id}/meals?date=` y la foto de `photo_url`, con el cliente **con sesión** |
| | `models/client_summary_model.dart` | JSON de la lista; `goal` y `last_meal_at` pueden ser `null` |
| | `models/client_meal_model.dart` | JSON de un registro; `photo_url` puede ser `null` |
| | `repositories/clients_repository_impl.dart` | `ClientsRepositoryImpl` |
| Presentación | `clients_list/` | Lista con búsqueda, lista vacía, error con reintento y recarga al deslizar |
| | `client_detail/` | Resumen del cliente y acceso a **Metas** (HU-05), **Comidas** (HU-25) y **Progreso** (HU-23) |
| | `client_progress/` | Progreso del cliente: `ClientProgressViewModel` (extiende `ProgressChartsViewModel`) y `ClientProgressView` (usa `ProgressCharts`) |
| | `client_meals/` | Comidas del día con hora, foto y valores, total del día, cambio de día y cliente desvinculado |
| | `widgets/client_summary_texts.dart` | Textos del resumen: meta, origen y último registro |
| | `widgets/client_meal_texts.dart` | Textos de las comidas: cantidades, hora local y nombre del día |

## Flujo del coach

1. En `/coach`, el botón **Mis clientes** abre `/coach/clients` (`GET /coach/clients`, una sola petición).
2. Cada cliente muestra su nombre, la meta vigente (`2200 kcal · P 160 g · G 70 g`) con su origen (*Meta del coach* o
   *Meta calculada*) y el último registro (*hoy, 14:30*, *ayer, 09:05* o *17/10/2026*, en hora local). Sin meta o sin
   registros lo indica.
3. La búsqueda filtra en memoria la lista ya cargada (no hace otra petición). Si nada coincide lo indica.
4. Al elegir un cliente se abre `/coach/clients/:clientId` con el `ClientSummary` como `extra` (sin él, la ruta vuelve
   a la lista). Desde ahí, **Metas** abre `/coach/clients/:clientId/goals` (HU-05) y **Comidas** abre
   `/coach/clients/:clientId/meals` (HU-25): ambas quedan a 3 pantallas de la principal (RF-20).
5. Al regresar de metas o comidas, el detalle vuelve a pedir la lista para actualizar el resumen; si el cliente ya no
   aparece (se desvinculó, HU-14) lo indica y deshabilita sus accesos. Al regresar a la lista, esta también se recarga.
6. Sin clientes vinculados, la lista vacía invita a compartir el código y el botón **Ver mi código de invitación** abre
   `/coach/invite-code` (HU-12, CU-02 paso 1) con `AppRoutes.coachInviteCode`. Atrás regresa a la lista vacía.

## Comidas de un cliente (HU-25)

- Empieza en el día de hoy (fecha local del teléfono) y pide `GET /coach/clients/{id}/meals?date=AAAA-MM-DD`. Las
  flechas cambian al día anterior o siguiente (nunca después de hoy) y el botón de la fecha abre un calendario.
- Cada registro muestra la hora local, la foto (o *Captura manual*) y calorías, proteína y grasa finales; arriba va el
  total del día. Un día sin registros lo indica y ofrece **Elige otra fecha** (CU-03 3a).
- **Fotos:** `photo_url` es una ruta absoluta del servidor (`/api/v1/meals/photos/{id}`). Se resuelve contra el host de
  `API_BASE_URL` y se descarga como bytes con el mismo `Dio` con sesión, así el `AuthInterceptor` agrega la cabecera
  `Authorization` del coach (y renueva el token si hace falta). La app nunca maneja el token. Cada foto se descarga
  una sola vez mientras la pantalla está abierta.
- **Solo lectura (RN-07):** no hay botones para crear, editar ni eliminar registros.
- `403 CLIENT_NOT_LINKED` (RN-04) muestra *Este cliente ya no está vinculado contigo.* y **Volver a mis clientes**,
  que cierra las comidas y el detalle y regresa a la lista (que se recarga y ya no lo muestra). Sin conexión muestra el
  error con **Reintentar**.
- Si el coach cambia de día antes de que llegue la respuesta del día anterior, esa respuesta se descarta.

## Progreso de un cliente (HU-23)

- **Progreso** en el detalle abre `/coach/clients/:clientId/progress` con el cliente como `extra` (sin él, vuelve a la
  lista). Pide `GET /coach/clients/{id}/progress?from=&to=` con el cliente con sesión, a través de
  `ProgressRepository.getClientProgress` (dominio de `progress`: el contrato es el mismo de HU-22).
- Mismo contenido que "Mi progreso" (HU-22): **Semana / Mes**, periodo anterior y siguiente (nunca futuro), y las
  tarjetas **Peso**, **Consumo por día** (calorías, proteína o grasa contra la meta de cada día) y **Entrenamiento**.
  Los textos de los estados vacíos hablan del cliente (`ProgressCopy.client`) y las claves de prueba empiezan con
  `client_progress_`.
- **Solo lectura**: la tarjeta de peso no tiene **Registrar** ni hay otros botones de edición.
- `403 CLIENT_NOT_LINKED` (RN-04) muestra *Este cliente ya no está vinculado contigo.* y **Volver a mis clientes**,
  que cierra el progreso y el detalle (igual que en las comidas). Sin conexión (RNF-11) muestra el error con
  **Reintentar**; si ya había un reporte, lo conserva y avisa con un banner.
- **Reutilización**: `client_progress/` importa `features/progress/presentation/shared/` (el ViewModel base y
  `ProgressCharts`). Es una excepción documentada a AGENTS.md §3, aprobada para no duplicar las gráficas de HU-22.

## Decisiones

- La búsqueda trata `ñ` como `n` y `ç` como `c`, además de quitar acentos y diéresis.
- Sin clientes vinculados, la pantalla invita a compartir el código de invitación y enlaza a su pantalla
  (`/coach/invite-code`, HU-12). La feature solo usa la constante de `AppRoutes`; no importa nada de `invite_code`.
- Al regresar de la pantalla del código la lista **no** se recarga sola: el cliente se vincula desde su propio teléfono
  y puede tardar; el coach usa **Actualizar** o desliza para recargar.
- El orden de la lista es el de la API (por nombre). La app no lo reordena.
- El día de las comidas usa la fecha local del teléfono. El backend calcula el día con `APP_UTC_OFFSET` (UTC−6), así
  que coinciden si el teléfono está en esa zona.
- El calendario permite fechas desde 2020 hasta hoy.
