# `lib/app/` — composición de la aplicación

| Archivo | Contenido |
|---|---|
| `app.dart` | `MacroFitApp`: `MultiProvider` con los repositorios + `MaterialApp.router` (tema, locale `es_MX`) |
| `dependencies.dart` | `AppDependencies.create`: **raíz de composición**. Único lugar que instancia implementaciones de datos |
| `router.dart` | `createRouter` (rutas y ViewModel por ruta) y `resolveRedirect` (guard de sesión, función pura) |
| `routes.dart` | Constantes de rutas (`AppRoutes`) y conjunto de rutas públicas |
| `theme.dart` | Tema claro/oscuro (color semilla provisional) |

## Dependencias (`dependencies.dart`)

```
publicDio ── AuthRemoteDataSource (register, login, refresh)
          └─ LegalRemoteDataSource (aviso de privacidad)
sessionDio + AuthInterceptor ── SessionRemoteDataSource (me, logout)
                             └─ ProfileRemoteDataSource (perfil, HU-03)
SessionLocalDataSource (flutter_secure_storage)
        ↓
AuthRepositoryImpl  ←── interceptor.onSessionExpired
LegalRepositoryImpl
ProfileRepositoryImpl
```

- Hay **dos clientes Dio**: uno público y otro con `AuthInterceptor`. Las rutas públicas y la renovación de tokens van
  por el público para evitar bucles.
- Para pruebas, `AppDependencies` se construye directamente con repositorios *fake* (ver `test/app/app_test.dart`).

## Navegación y sesión (`router.dart`)

`GoRouter` escucha al `AuthRepository` (`refreshListenable`). Ante cualquier cambio de sesión evalúa `resolveRedirect`:

| Estado | Rutas permitidas | Cualquier otra ruta |
|---|---|---|
| `AuthUnknown` (leyendo sesión) | `/` (carga) | → `/` |
| `Unauthenticated` | `/login`, `/register`, `/privacy` | → `/login` |
| `Authenticated(user)`, rol `user` **sin perfil** | `/profile/setup` y `/privacy` | → `/profile/setup` |
| `Authenticated(user)`, rol `user` con perfil | `/user`, `/user/profile` y `/privacy` | → `/user` |
| `Authenticated(user)`, rol `coach` | `/coach` y `/privacy` | → `/coach` |

Consecuencias:

- Tras login o registro la app entra a la pantalla de su rol sin que la vista navegue.
- Tras cerrar sesión (o si la sesión expira/es revocada) se va a `/login` y la pila se reemplaza: el botón atrás no
  regresa a pantallas protegidas.
- Un rol nunca puede abrir la pantalla del otro.
- HU-03: un usuario sin perfil no llega a `/user` hasta guardar el formulario; al guardarlo,
  `AuthRepository.markProfileCompleted()` cambia la sesión y el router lo lleva a `/user`. Un coach nunca ve el formulario.

### Agregar una ruta

1. Constante en `AppRoutes`.
2. `GoRoute` en `createRouter` con su `ChangeNotifierProvider(create: (context) => XViewModel(context.read<Repo>()))`.
3. Si es pública, agrégala a `AppRoutes.public`. Si cuelga de un rol, ajusta `resolveRedirect` y su prueba en
   `test/app/router_test.dart`.
