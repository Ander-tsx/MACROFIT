# `features/clients/` — clientes del coach

## Historias

- **HU-24**: "Como coach, quiero ver la lista de mis clientes para acceder a su información." (RF-19, RN-03, CU-03
  pasos 1 y 2). Reemplaza la lista mínima de clientes que dejó HU-05 en `features/goals`.
- **HU-25** (pendiente, HU-25-APP): el registro diario de comidas del cliente se abrirá desde el detalle.

## Archivos

| Capa | Archivo | Contenido |
|---|---|---|
| Dominio | `entities/client_summary.dart` | `ClientSummary` (extiende `CoachClient` de `goals`) con `goal` (`ClientGoalSummary`) y `lastMealAt`, ambos opcionales |
| | `repositories/clients_repository.dart` | `getClients()` |
| | `usecases/filter_clients_by_name.dart` | Búsqueda por nombre sin distinguir mayúsculas ni acentos (`normalizeForSearch`) |
| Datos | `datasources/clients_remote_data_source.dart` | `GET /coach/clients` con el cliente **con sesión** |
| | `models/client_summary_model.dart` | JSON de la API; `goal` y `last_meal_at` pueden ser `null` |
| | `repositories/clients_repository_impl.dart` | `ClientsRepositoryImpl` |
| Presentación | `clients_list/` | Lista con búsqueda, lista vacía, error con reintento y recarga al deslizar |
| | `client_detail/` | Resumen del cliente y acceso a **Metas** (HU-05) y **Comidas** (HU-25, deshabilitado) |
| | `widgets/client_summary_texts.dart` | Textos del resumen: meta, origen y último registro |

## Flujo del coach

1. En `/coach`, el botón **Mis clientes** abre `/coach/clients` (`GET /coach/clients`, una sola petición).
2. Cada cliente muestra su nombre, la meta vigente (`2200 kcal · P 160 g · G 70 g`) con su origen (*Meta del coach* o
   *Meta calculada*) y el último registro (*hoy, 14:30*, *ayer, 09:05* o *17/10/2026*, en hora local). Sin meta o sin
   registros lo indica.
3. La búsqueda filtra en memoria la lista ya cargada (no hace otra petición). Si nada coincide lo indica.
4. Al elegir un cliente se abre `/coach/clients/:clientId` con el `ClientSummary` como `extra` (sin él, la ruta vuelve
   a la lista). Desde ahí, **Metas** abre `/coach/clients/:clientId/goals` (HU-05): son 3 pantallas desde la principal.
5. Al regresar del formulario de metas, el detalle vuelve a pedir la lista para actualizar el resumen; si el cliente ya
   no aparece (se desvinculó, HU-14) lo indica y deshabilita **Metas**. Al regresar a la lista, esta también se recarga.

## Decisiones

- La búsqueda trata `ñ` como `n` y `ç` como `c`, además de quitar acentos y diéresis.
- Sin clientes vinculados, la pantalla invita a compartir el código de invitación.
  `TODO(HU-12)`: enlazar a la pantalla del código cuando exista (HU-12-APP).
- `TODO(HU-25)`: **Comidas** queda deshabilitado (*Disponible próximamente*) hasta HU-25-APP.
- El orden de la lista es el de la API (por nombre). La app no lo reordena.
