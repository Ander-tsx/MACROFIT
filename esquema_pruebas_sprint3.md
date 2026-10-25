## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| HU-24 | La app interpreta `GET /coach/clients`, incluidos `goal` y `last_meal_at` nulos. | Unitaria | Cada cliente se convierte con su meta (calorías, proteína y grasa redondeadas) y su origen, y con la fecha del último registro; los `null` llegan como "sin meta" y "sin registros"; los errores de la API salen como `ApiException`. | [**4**](#caso-01) (mobile 4 · backend 0) |
| HU-24 | La lista muestra nombre, meta vigente con su origen y último registro de cada cliente (RF-19). | Interfaz | Se ve `2200 kcal · P 160 g · G 70 g` con *Meta del coach* o *Meta calculada* y *Último registro: hoy, 14:30*, *ayer, 09:05* o *17/10/2026* (hora local); sin meta o sin registros lo indica. | [**7**](#caso-02) (mobile 7 · backend 0) |
| HU-24 | Búsqueda de clientes por nombre. | Unitaria | La búsqueda no distingue mayúsculas ni acentos (`jose` encuentra a *José*), ignora los espacios al inicio y al final, conserva el orden y no hace otra petición a la API. | [**7**](#caso-03) (mobile 7 · backend 0) |
| HU-24 | Lista vacía. | Interfaz | Un coach sin clientes vinculados ve un mensaje que lo invita a compartir su código de invitación, sin buscador ni error. | [**3**](#caso-04) (mobile 3 · backend 0) |
| HU-24 | Errores al cargar la lista. | Unitaria | Un error sin lista muestra el mensaje y **Reintentar**; un error al recargar conserva la lista y la búsqueda. | [**3**](#caso-05) (mobile 3 · backend 0) |
| HU-24 | Detalle del cliente con acceso a sus metas (HU-05) y a sus comidas (HU-25). | Interfaz | Al elegir un cliente se abre su detalle (solo para el rol `coach`); **Metas** abre el formulario de HU-05 y al regresar el resumen se actualiza; si el cliente ya no está vinculado lo indica; **Comidas** queda deshabilitado hasta HU-25-APP. | [**7**](#caso-06) (mobile 7 · backend 0) |
| HU-24 | La lista reemplaza la pantalla mínima de clientes de HU-05 sin romper sus flujos. | Interfaz | El coach llega al formulario de metas desde el detalle del cliente; guardar una meta y validar el formulario vacío siguen funcionando. | [**3**](#caso-07) (mobile 3 · backend 0) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. el flujo de la lista al formulario de metas cuenta en el detalle y en el reemplazo de la pantalla de HU-05).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar HU-24-APP: **146** pruebas mobile (`flutter test`). Al cerrar el Sprint 2 eran 119; HU-24-APP agrega 30 y retira 3 que probaban la pantalla mínima de clientes de HU-05, que se eliminó (las 2 del `CoachClientsViewModel` y *lista los clientes vinculados* de `CoachGoalsRepositoryImpl`; ahora las cubren los casos 01, 02 y 05). Sin cambios en el backend.

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

El acceso a las comidas queda deshabilitado hasta HU-25-APP; la prueba comprueba que se muestra y no se puede abrir.

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
