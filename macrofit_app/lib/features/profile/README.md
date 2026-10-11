# `features/profile/` — perfil inicial del usuario (HU-03)

## Historia

- **HU-03**: "Como usuario, quiero capturar mi perfil inicial para recibir metas y rutinas acordes a mí."

## Archivos

| Capa | Archivo | Contenido |
|---|---|---|
| Dominio | `entities/profile.dart` | `Profile` + enums `Objective`, `ExperienceLevel`, `Gender` (`apiValue` = valor de la API, `label` = texto) |
| | `repositories/profile_repository.dart` | Contrato `getProfile` / `createProfile` / `updateProfile` |
| | `validators/profile_validators.dart` | Mismas reglas que `backend/src/services/profile.rs` (rangos provisionales, TEC-12) |
| Datos | `models/profile_model.dart` | JSON de `ProfileResponse`; `birth_date` como `YYYY-MM-DD` |
| | `datasources/profile_remote_data_source.dart` | `GET`/`POST`/`PATCH /users/me/profile` con el cliente **con sesión** |
| | `repositories/profile_repository_impl.dart` | Implementación del contrato |
| Presentación | `profile_form/profile_form_view.dart` | Formulario (objetivo, nivel, días, peso, estatura, sexo, fecha de nacimiento) |
| | `profile_form/profile_form_view_model.dart` | `ProfileFormViewModel` con modo `setup` (alta) o `edit` (Mi perfil) |

## Flujo

**Alta (`/profile/setup`, modo `setup`)**

1. Tras iniciar sesión (o registrarse), si la cuenta es `user` y `profileCompleted == false`, `resolveRedirect` solo
   permite `/profile/setup` (y el aviso de privacidad). El botón atrás no lleva al inicio.
2. La app valida todo antes de enviar; los errores del backend con `fields` se muestran en su campo.
3. `POST /users/me/profile`. Si responde `409 PROFILE_ALREADY_EXISTS` (p. ej. se capturó en otro dispositivo) se
   trata como perfil ya guardado.
4. `AuthRepository.markProfileCompleted()` actualiza el usuario en memoria y en el almacenamiento seguro → el router
   abre `/user`. Al volver a abrir la app ya entra directo (y `/auth/me` confirma `profile_completed: true`).
5. La barra tiene **Cerrar sesión** para cambiar de cuenta sin capturar el perfil.

**Edición (`/user/profile`, modo `edit`)**

1. Se abre con el botón **Mi perfil** de la pantalla principal (`push`).
2. Siempre consulta `GET /users/me/profile` al abrir: muestra lo último guardado en el backend. Si falla, ofrece
   **Reintentar**.
3. `PATCH /users/me/profile` con todos los campos; al guardar muestra "Perfil actualizado" y regresa.

Un coach nunca ve estas pantallas (el router lo manda a `/coach`); si llamara al endpoint recibiría
`403 FORBIDDEN_ROLE`.

## Decisiones

- Nombres de campos del formulario = nombres de la API (`objective`, `level`, `training_days`, `weight_kg`,
  `height_cm`, `gender`, `birth_date`).
- Peso y estatura aceptan coma o punto decimal.
- La fecha se elige con el selector de fecha (`showDatePicker`, locale `es_MX`); se guarda solo año-mes-día.
- `TODO(HU-04)`: tras editar el perfil, la meta nutricional se recalcula en el backend.
