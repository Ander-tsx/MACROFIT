# `src/services/` — lógica de negocio

Un archivo por dominio (`auth.rs`, y después `profile.rs`, `goals.rs`, ...). Aquí vive lo que hace cada historia.

## Reglas

- Las funciones reciben `&Database` y datos de entrada propios del servicio (p. ej. `RegisterInput`),
  **no** DTOs ni tipos de Axum. Devuelven `Result<Modelo, AppError>`.
- **Validación separada de la persistencia**: una función pura `validate_xxx(input) -> Result<ValidXxx, AppError>`
  que acumula todos los errores en un `FieldErrors` y una función async que la llama y luego toca Mongo.
  Así la validación se prueba sin base de datos.
- **Unicidad**: el índice único de Mongo es la garantía. Se puede hacer una consulta previa para responder rápido,
  pero el error de clave duplicada (código `11000`) también debe traducirse al `AppError` correspondiente.
- **CPU pesada** (hash/verificación de contraseñas) dentro de `tokio::task::spawn_blocking`.
- Mensajes de error al usuario en español, en `FieldErrors` por campo.
- Pendientes de otra historia: `// TODO(ID): qué falta y qué hay que cambiar` .

## Archivos

| Archivo | Contenido |
|---|---|
| `auth.rs` | `validate_registration`, `register` (HU-01), `login` (HU-02, con hash ficticio para igualar tiempos), `find_user_by_id` |
| `legal.rs` | TEC-07: `PRIVACY_NOTICE` (Markdown embebido desde `docs/legal/`) y `PRIVACY_VERSION` (leída de su cabecera) |
| `session.rs` | HU-02: `start` (login), `refresh` (rotación atómica + detección de reuso), `logout`, `is_active` |
| `coach_links.rs` | HU-05: `require_active_link` (guarda de acceso a un cliente), `seed_link` (solo desarrollo). HU-24: `list_clients` (clientes activos con meta vigente y último registro, sin consultas por cliente) y `build_client_summaries` (pura). HU-13: `link_with_invite_code` (vinculación real mediante código). TEC-13: `has_active_link` |
| `goals.rs` | HU-04 y TEC-12: cálculo Mifflin-St Jeor con mínimo de calorías (puro), `get_current_goal`, `get_goals_history`, `recalculate_on_profile_change`. HU-05: `validate_coach_goal` (pura), `set_client_goal`, `get_client_goals`; `find_current_goal` decide la meta vigente. HU-24: `pick_current_goals` (pura, misma regla en lote) y `current_goals_for`. HU-10: `get_goal_at` (meta vigente al final de un día). HU-11: `pick_goal_at` (pura) y `get_goals_at` (meta de cada día de la semana con una consulta) |
| `photos.rs` | TEC-13: `validate_photo` / `detect_format` (puras), `save_photo`, HU-06: `validate_upload` (pura) y `upload_photo`, `read_photo` (dueño o coach vinculado), HU-07: `read_own_photo` (solo el dueño), `delete_photo` (solo el dueño); almacenamiento en GridFS |
| `meal_estimates.rs` | HU-07: `validate_estimate_request` (pura), `estimate_meal` (lee la foto propia, la prepara y llama a `FoodService`), `map_recognition_error` (adaptador → `FOOD_NOT_RECOGNIZED` / `FOOD_PROVIDER_ERROR` / `FOOD_PROVIDER_TIMEOUT`) |
| `meals.rs` | HU-09/HU-08: `validate_new_meal` (también valida `estimated`) / `validate_date` / `local_date` (puras), `create_meal`, `list_meals`, `find_meals_by_date` (reutilizable en HU-10 y HU-25), `delete_meal` (borra también la foto). HU-24: `last_meal_pipeline` / `parse_last_meals` (puras) y `last_meal_at_for` (último registro de varios usuarios en una agregación). HU-11: `find_meals_between` (registros de un rango de días con una consulta). HU-25: `list_client_meals` (vinculación con `coach_links::require_active_link`, después `validate_date` y `find_meals_by_date`) |
| `profile.rs` | HU-03: `validate_new_profile` / `validate_profile_changes` (puras), `create_profile` (marca `profile_completed`), `get_profile`, `update_profile`; rangos válidos de TEC-12 y `parse_weight_kg` (reutilizable en HU-21) |
| `coach_invite_codes.rs` | HU-12: `generate_code` (puro), `get_or_create_invite_code`, `regenerate_invite_code` |
| `summary.rs` | HU-10: `sum_meals`, `remaining`, `build_daily_summary` y `end_of_day` (puras), `get_daily_summary` (valida la fecha, toma la meta con `goals::get_goal_at` y suma los registros con `meals::find_meals_by_date`). HU-11: `goal_met`, `week_dates`, `validate_start` y `build_weekly_summary` (puras, reutilizan el cálculo diario), `get_weekly_summary` (metas con `goals::get_goals_at` y registros con `meals::find_meals_between`, una consulta cada uno) |
| `weights.rs` | HU-21: `validate_weight` (pura, con `profile::parse_weight_kg`), `record_weight` (guarda y actualiza el perfil), `list_weights` |
| `food_recognition/` | TEC-02 (RNF-13): trait `FoodRecognizer` y `FoodService` (tiempo de espera); proveedores `simulator`, `logmeal`, `gemini` y `gemini_fatsecret`; `preprocess::prepare` (JPEG ≤ 1000 px). Sección abajo |

### Registro de peso (HU-21)

- La fecha (`recorded_at`) la pone el servidor; el cliente solo envía `weight_kg`.
- `record_weight` inserta el registro y, si el usuario tiene perfil, llama a `profile::update_profile` con el nuevo
  `weight_kg`. Así se reutilizan la validación y el recálculo de la meta (HU-04, que respeta la meta de un coach).
  Sin perfil (`PROFILE_NOT_FOUND`), el peso se guarda igual y no se toca nada más.

### Registros de comida (HU-09)

- **Día del registro:** `create_meal` guarda `eaten_at` (hora del servidor, UTC) y `date` = día de ese instante en la
  zona fija `APP_UTC_OFFSET` (`state.utc_offset`, `-06:00` por defecto). La consulta filtra por `date`, así que no hay
  que convertir rangos de horas al consultar y el usuario y su coach ven el mismo día. Si algún día se necesita otra zona
  por usuario, solo cambia el cálculo de `date` al guardar.
- **Foto opcional:** sin `photo_id` es una captura manual. Con `photo_id` se revisa con `photos::ensure_own_photo`
  (sin descargarla): mal formado, inexistente o ajena → `PHOTO_NOT_FOUND`. Una foto en dos registros la impide el índice
  único parcial `photo_id_unique` (`PHOTO_ALREADY_USED`); así eliminar un registro nunca deja a otro sin foto.
- **Eliminar:** busca el registro por `_id` **y** `user_id` (uno ajeno responde igual que uno inexistente,
  `MEAL_NOT_FOUND`), borra la foto con `photos::delete_photo` y después el registro. Si borrar la foto falla, el registro
  sigue y se puede reintentar; una foto que ya no existe no impide eliminarlo.
- **Valores estimados (HU-08):** `MealInput.estimated` llega como `Value`; `validate_new_meal` lo valida (objeto con
  los tres valores, mismas reglas que los finales con `parse_amount`, errores en `estimated.<campo>`; si viene sin
  `photo_id` → un solo error en `estimated`) y `create_meal` lo guarda en `meals.estimated`. El servidor no copia valores
  entre estimados y finales: si el usuario no corrige, la app manda los mismos en los dos.
- **Coach (HU-25):** `list_client_meals` comprueba primero la vinculación activa (`CLIENT_NOT_LINKED` para no vinculado,
  desvinculado, inexistente o id mal formado, con cualquier fecha) y después reutiliza `validate_date` y
  `find_meals_by_date` con el id del cliente. Solo lectura: no hay funciones de coach que escriban registros.
- **Pruebas:** las puras con `cargo test`; las de MongoDB real (guardar, consultar, orden, foto ajena, foto repetida,
  eliminación con la foto, consulta del coach vinculado / no vinculado) con `cargo test -- --ignored`, igual que las de fotos.

### Aviso de privacidad en el registro

`validate_registration` exige `privacy_accepted: true`. Si es lo único que falla responde `PRIVACY_NOT_ACCEPTED`; si hay
otros campos inválidos lo agrega a `FieldErrors` dentro de `VALIDATION_ERROR`. `register` guarda `privacy_accepted_at`
y `privacy_version`.

### Perfil (HU-03)

- `create_profile` valida, inserta y pone `users.profile_completed = true`. Si el perfil ya existía (consulta previa o
  error `11000`) responde `PROFILE_ALREADY_EXISTS` y **también** asegura la marca en `users`, por si una petición
  anterior guardó el perfil pero no alcanzó a marcar la cuenta.
- `update_profile` solo toca los campos enviados (`$set` + `updated_at`) con `find_one_and_update`.
  Si cambian peso, objetivo o días (`goals::goal_inputs_changed`) llama a `goals::recalculate_on_profile_change`,
  que respeta la meta de un coach. `create_profile` también la llama para generar la meta inicial (HU-04).

### Meta nutricional (HU-04 y TEC-12)

Reglas confirmadas por el PO en **TEC-12** (12/10/2026). Sustituyen los supuestos provisionales del Sprint 1; la única
regla nueva es el mínimo de calorías. `calculate_macros` (pura) las aplica en este orden y redondea cada valor a entero:

| Paso | Regla | Fuente |
|---|---|---|
| 1. Metabolismo basal | Mifflin-St Jeor: `10·peso + 6.25·estatura − 5·edad`, `+5` hombre / `−161` mujer | Mifflin et al. (1990), *Am J Clin Nutr* 51(2):241–247. Es la ecuación más precisa en adultos sanos según la revisión sistemática de Frankenfield et al. (2005), *J Am Diet Assoc* 105(5):775–789 |
| 2. Actividad | × 1.2 (1 día) · 1.375 (2–3) · 1.55 (4–5) · 1.725 (6–7) | Multiplicadores de actividad estándar (sedentario a muy activo) |
| 3. Objetivo | × 0.80 `lose_fat` · 1.00 `maintain` · 1.10 `gain_muscle` | Déficit de 20 % y superávit de 10 %: proporcionales al tamaño de la persona |
| 4. Mínimo de calorías | No menos de **1 200 kcal** (mujer) / **1 500 kcal** (hombre) | Extremo superior de las dietas bajas en calorías sin supervisión médica de NHLBI (1998), *Clinical Guidelines on the Identification, Evaluation, and Treatment of Overweight and Obesity in Adults* |
| 5. Proteína | `peso × g/kg`: **2.0** `lose_fat` · **1.6** `maintain` · **1.8** `gain_muscle` | Jäger et al. (2017), ISSN, *J Int Soc Sports Nutr* 14:20 (1.4–2.0 g/kg); Morton et al. (2018), *Br J Sports Med* 52(6):376–384 |
| 6. Grasa | **25 %** de las calorías del paso 4 ÷ 9 kcal/g, igual para los tres objetivos (`FAT_SHARE`) | Dentro del 20–35 % recomendado (AMDR) por el Institute of Medicine (2005), *Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat…* |

Los carbohidratos no se registran: quedan implícitos como el resto de las calorías.

**Rangos válidos del perfil** (`services::profile`):

| Campo | Rango | Motivo |
|---|---|---|
| Edad | 18 a 80 años | Mifflin-St Jeor se validó en adultos de 19 a 78 años; los menores quedan fuera también por el aviso de privacidad (TEC-07) |
| Peso | 35 a 250 kg | Cubre adultos reales y evita metas sin sentido en los extremos. También lo usa el registro de peso (HU-21, `parse_weight_kg`) |
| Estatura | 130 a 230 cm | Igual que el peso |

En todas las combinaciones de estos límites la meta queda entre el mínimo y `CALORIES_MAX`
(prueba `esquinas_del_perfil_dan_metas_validas`).

Las metas que ya están guardadas no se recalculan con estas reglas: una meta `system` se actualiza en la siguiente
edición del perfil que cambie peso, objetivo o días, y el historial anterior queda intacto.

### Fotos de comidas (TEC-13)

**Decisión: GridFS de MongoDB** (bucket `meal_photos`), frente a un servicio de almacenamiento de objetos (S3, R2, Cloudinary).

| Criterio | GridFS | Almacenamiento de objetos |
|---|---|---|
| Costo | Sin costo extra: usa la misma base | Cuenta y facturación aparte (aunque tenga capa gratuita) |
| Límites del plan | Comparte el espacio de Atlas (M0: 512 MB ≈ 1 000 fotos de 500 KB). Suficiente para el piloto; vigilarlo | Más espacio y URLs directas (CDN) |
| Despliegue (TEC-15) | Nada nuevo que configurar: basta `MONGO_URI` | Credenciales nuevas, CORS y reglas del bucket |
| Acceso (RN-04, RNF-05) | El backend lee y entrega cada foto, así que la regla de dueño/coach vive en un solo lugar | Hay que firmar URLs temporales para no exponer las fotos |
| Borrado con el registro (RF-08) | `delete_photo` en la misma base | Llamada a otro servicio que puede fallar por separado |

Si el volumen crece, se puede migrar a almacenamiento de objetos cambiando solo este archivo: el resto del backend
usa `save_photo` / `read_photo` / `delete_photo` y el id de la foto.

**Reglas:**

- **Tipos permitidos:** JPEG y PNG (SRS). Se detectan por los primeros bytes del archivo (`FF D8 FF` y
  `89 50 4E 47 0D 0A 1A 0A`); la extensión y el `Content-Type` del cliente se ignoran. Otro tipo → `415 UNSUPPORTED_PHOTO_TYPE`.
- **Tamaño máximo:** `MAX_PHOTO_BYTES` = 5 MiB (5 242 880 bytes). Se revisa antes que el tipo. Más grande →
  `413 PHOTO_TOO_LARGE`. La app debe comprimir la foto antes de subirla.
- **Lectura:** el dueño o un coach con vinculación `active` con el dueño (`coach_links::has_active_link`). Cualquier otra
  cuenta, un id inexistente o mal formado reciben lo mismo, `404 PHOTO_NOT_FOUND`, para no revelar que la foto existe.
- **Eliminación:** solo el dueño; borra el documento de `meal_photos.files` y todos sus trozos. Un coach vinculado no puede.
  HU-09 la usa al eliminar un registro de comida.
- **Descarga (HU-25):** `read_photo` aplica la regla de lectura; la ruta `GET /meals/photos/{id}` la usa para que el
  coach vea la foto de cada registro de su cliente (y el dueño la suya).
- **Subida (HU-06):** `upload_photo` valida con `validate_upload` (sin archivo o vacío → `400 VALIDATION_ERROR` en
  `photo`; después tamaño y tipo) y guarda con `save_photo`. La ruta `POST /meals/photos` sube el límite de cuerpo de
  Axum (2 MB por defecto) a `MAX_PHOTO_BYTES` + 1 MiB y guarda como máximo `MAX_PHOTO_BYTES + 1` bytes del archivo,
  suficiente para que el servicio responda 413 sin tener el archivo completo en memoria.
- **Pruebas:** las puras corren con `cargo test`; las de MongoDB real (guardar, leer, permisos, borrado de trozos, índices)
  con `cargo test -- --ignored` contra un Mongo sin autenticación (`TEST_MONGO_URI`, por defecto `mongodb://localhost:27017`).
  Cada prueba crea y borra su propia base `macrofit_test_<id>`.


## Reconocimiento de alimentos — `food_recognition/` (TEC-02)

Capa del adaptador (RNF-13). Quien estima una foto solo conoce `FoodService` y el trait `FoodRecognizer`;
el proveedor se elige con `FOOD_PROVIDER` y cambiarlo no toca handlers ni rutas. La comparación de proveedores y la
decisión están en [`docs/spikes/TEC-02-reconocimiento-de-alimentos.md`](../../../docs/spikes/TEC-02-reconocimiento-de-alimentos.md).

**Contrato:**

| | |
|---|---|
| Entrada | `FoodImage { bytes, mime }`: la foto ya pasada por `preprocess::prepare` (orientación EXIF aplicada, lado mayor ≤ 1000 px, JPEG calidad 85). Usa CPU: dentro de `spawn_blocking` |
| Salida | `FoodEstimate { foods: [IdentifiedFood { name, grams?, nutrients }], totals }` con `Nutrients { calories_kcal, protein_g, fat_g }`, redondeados a 1 decimal; `totals` es la suma de `foods` |
| Errores | `RecognitionError::NotRecognized` (sin comida; lista vacía nunca es éxito), `Provider(detalle)` (HTTP ≠ 2xx, JSON inesperado, cuota; el detalle es solo para el log) y `Timeout` |
| Tiempo de espera | Lo aplica `FoodService::estimate` a cualquier proveedor (`FOOD_PROVIDER_TIMEOUT_SECS`, máximo 10 s) |

| Archivo | Proveedor |
|---|---|
| `mod.rs` | Trait, tipos, `FoodService`, `build_recognizer` (según `FoodConfig`) |
| `simulator.rs` | Sin red. `FOOD_SIMULATOR_MODE`: `ok` (plato fijo de 3 alimentos), `not_recognized`, `error`, `timeout` |
| `logmeal.rs` | `segmentation/complete` + `nutrition/recipe/nutritionalInfo` (token APIUser) |
| `gemini.rs` | `generateContent` con `responseSchema` (`recognized`, `foods[]`) |
| `fatsecret.rs` | Híbrido: Gemini identifica alimentos y gramos; `foods.search` de FatSecret da los valores por 100 g |
| `preprocess.rs` | Preparación de la foto común a todos |
| `fixtures/` | Respuestas de ejemplo de cada proveedor para las pruebas (sin red) |

**Reglas:** las credenciales llegan como `config::Secret` (su `Debug` no las muestra) y van siempre en cabeceras, nunca
en la URL; los errores de `reqwest` se registran `without_url()`. Las pruebas de cada proveedor usan los *fixtures*,
no la red; el comportamiento real se mide con el banco de pruebas (`backend/bench/`).
