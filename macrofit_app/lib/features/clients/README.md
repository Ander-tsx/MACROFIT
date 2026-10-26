# `features/clients/` — clientes del coach

## Historias

- **HU-24**: "Como coach, quiero ver la lista de mis clientes para acceder a su información." (RF-19, RN-03, CU-03
  pasos 1 y 2). Reemplaza la lista mínima de clientes que dejó HU-05 en `features/goals`.
- **HU-25**: "Como coach, quiero consultar el registro diario de comidas de un cliente para revisar su alimentación."
  (RF-20, RN-04, RN-07, RNF-05, CU-03 paso 3). Solo lectura.

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
| | `client_detail/` | Resumen del cliente y acceso a **Metas** (HU-05) y **Comidas** (HU-25) |
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

## Decisiones

- La búsqueda trata `ñ` como `n` y `ç` como `c`, además de quitar acentos y diéresis.
- Sin clientes vinculados, la pantalla invita a compartir el código de invitación y enlaza a su pantalla
  (`/coach/invite-code`, HU-12).
- El orden de la lista es el de la API (por nombre). La app no lo reordena.
- El día de las comidas usa la fecha local del teléfono. El backend calcula el día con `APP_UTC_OFFSET` (UTC−6), así
  que coinciden si el teléfono está en esa zona.
- El calendario permite fechas desde 2020 hasta hoy.
