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
| `coach_links.rs` | HU-05: `require_active_link` (guarda de acceso a un cliente), `list_clients`, `seed_link` (solo desarrollo). TEC-13: `has_active_link` |
| `goals.rs` | HU-04: cálculo Mifflin-St Jeor (puro), `get_current_goal`, `get_goals_history`, `recalculate_on_profile_change`. HU-05: `validate_coach_goal` (pura), `set_client_goal`, `get_client_goals`; `find_current_goal` decide la meta vigente |
| `photos.rs` | TEC-13: `validate_photo` / `detect_format` (puras), `save_photo`, HU-06: `validate_upload` (pura) y `upload_photo`, `read_photo` (dueño o coach vinculado), `delete_photo` (solo el dueño); almacenamiento en GridFS |
| `profile.rs` | HU-03: `validate_new_profile` / `validate_profile_changes` (puras), `create_profile` (marca `profile_completed`), `get_profile`, `update_profile`; rangos provisionales (TEC-12) |

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
- **Subida (HU-06):** `upload_photo` valida con `validate_upload` (sin archivo o vacío → `400 VALIDATION_ERROR` en
  `photo`; después tamaño y tipo) y guarda con `save_photo`. La ruta `POST /meals/photos` sube el límite de cuerpo de
  Axum (2 MB por defecto) a `MAX_PHOTO_BYTES` + 1 MiB y guarda como máximo `MAX_PHOTO_BYTES + 1` bytes del archivo,
  suficiente para que el servicio responda 413 sin tener el archivo completo en memoria.
- **Pruebas:** las puras corren con `cargo test`; las de MongoDB real (guardar, leer, permisos, borrado de trozos, índices)
  con `cargo test -- --ignored` contra un Mongo sin autenticación (`TEST_MONGO_URI`, por defecto `mongodb://localhost:27017`).
  Cada prueba crea y borra su propia base `macrofit_test_<id>`.
