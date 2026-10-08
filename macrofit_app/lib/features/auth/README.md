# `features/auth/` — registro y sesión (HU-01, HU-02)

## Historias

- **HU-01**: "Como persona nueva, quiero crear una cuenta eligiendo mi rol para acceder a las funciones de coach o de usuario."
- **HU-02**: "Como usuario o coach, quiero iniciar y cerrar sesión para proteger mi información."

## Archivos

| Capa | Archivo | Contenido |
|---|---|---|
| Dominio | `entities/role.dart` | `Role.user` / `Role.coach` (`apiValue` = valor de la API, `label` = texto) |
| | `entities/user.dart` | Cuenta autenticada (sin contraseña ni tokens) |
| | `entities/auth_state.dart` | `AuthUnknown`, `Authenticated(user)`, `Unauthenticated` (sealed) |
| | `entities/registration.dart` | Datos de registro validados |
| | `repositories/auth_repository.dart` | Contrato y **fuente de verdad de la sesión** (`ChangeNotifier`) |
| | `validators/auth_validators.dart` | Reglas de nombre, correo, contraseña, confirmación, rol y aviso |
| Datos | `models/user_model.dart`, `models/session_model.dart` | JSON de `UserResponse` y `TokenResponse` |
| | `datasources/auth_remote_data_source.dart` | `POST /auth/register`, `/auth/login`, `/auth/refresh` (cliente público) |
| | `datasources/session_remote_data_source.dart` | `GET /auth/me`, `POST /auth/logout` (cliente con sesión) |
| | `datasources/session_local_data_source.dart` | Tokens y usuario en `flutter_secure_storage` |
| | `network/auth_interceptor.dart` | Bearer, renovación automática y expiración de sesión |
| | `repositories/auth_repository_impl.dart` | Implementación del contrato |
| Presentación | `login/` | `LoginView` + `LoginViewModel` |
| | `register/` | `RegisterView` + `RegisterViewModel` |
| | `splash/splash_view.dart` | Carga inicial mientras se lee la sesión |

## Registro (HU-01)

1. La app valida **todo** antes de enviar: nombre, correo, contraseña (mín. 8), confirmación igual, rol elegido y
   aviso aceptado. Si algo falla, no envía y muestra el mensaje bajo cada campo.
2. El enlace "Leer el aviso de privacidad" abre `/privacy` (feature `legal`) con `push`: al volver, el formulario
   conserva lo capturado.
3. `POST /auth/register`. Errores del backend: los que traen `fields` (`VALIDATION_ERROR`, `EMAIL_ALREADY_EXISTS`,
   `PRIVACY_NOT_ACCEPTED`) se muestran en su campo; el resto (p. ej. sin red) como error general.
4. Si se creó la cuenta, **inicia sesión automáticamente** con los mismos datos y el router lleva a la pantalla de su rol.
   Si ese login fallara, avisa que la cuenta sí se creó y manda a `/login`.

## Sesión (HU-02)

**Login**: `POST /auth/login` → se guardan `access_token`, `refresh_token` y el usuario en almacenamiento seguro →
`Authenticated(user)` → el router abre `/user` o `/coach`. `INVALID_CREDENTIALS` se muestra como error general
(mismo mensaje para correo inexistente y contraseña incorrecta).

**Al abrir la app** (`restoreSession`):

1. Sin sesión guardada → `Unauthenticated` → `/login`.
2. Con sesión guardada → entra **de inmediato** con el usuario guardado (funciona sin red) y valida en segundo plano
   con `GET /auth/me`.
3. Si el access token expiró, el interceptor lo renueva (`POST /auth/refresh`) y reintenta. Si la renovación es
   rechazada o la sesión fue revocada (`401`), se borra la sesión local y el router manda a `/login`.
4. Sin red se conserva la sesión hasta poder validarla.

**Interceptor** (`AuthInterceptor`, sobre el cliente con sesión):

| Respuesta | Acción |
|---|---|
| `401 UNAUTHORIZED` | Renueva una vez con el refresh token, guarda los tokens nuevos y reintenta la petición |
| `401 TOKEN_REVOKED` | Borra la sesión local y avisa a `AuthRepositoryImpl.handleSessionExpired` → `/login` |
| Renovación rechazada (`401`) | Igual que `TOKEN_REVOKED` |
| Sin red al renovar | Conserva la sesión; el error sube a quien llamó |

Es un `QueuedInterceptor`: si varias peticiones expiran a la vez, solo una renueva (el backend revocaría la sesión si
se reutilizara un refresh token ya rotado).

**Cerrar sesión**: botón en la barra de ambas pantallas principales (con confirmación) → `POST /auth/logout` con el
refresh token → se borra la sesión local **aunque el servidor no responda** → `Unauthenticated` → `/login` con la
pila reemplazada (atrás no regresa).

## Reglas de esta feature

- Las reglas de `auth_validators.dart` deben coincidir con el backend (`backend/src/validation.rs`, `services/auth.rs`).
- Nunca guardes tokens fuera de `SessionLocalDataSource`, ni los registres en logs.
- No navegues tras login/logout desde las vistas: cambia el estado del repositorio y deja que el router redirija.
- No cambies el comportamiento sin red ni la renovación sin acordarlo: son decisiones de la HU-02.
