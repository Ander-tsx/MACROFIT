# `features/home/` — pantallas principales por rol

Pantallas a las que el router lleva tras iniciar sesión (HU-02). Hoy son provisionales: saludan y permiten cerrar sesión.

| Archivo | Contenido |
|---|---|
| `presentation/user_home_view.dart` | `/user` — rol `user`. Se llenará con HU-03 (perfil), HU-10 (resumen diario), etc. |
| `presentation/coach_home_view.dart` | `/coach` — rol `coach`. Se llenará con HU-12 (código de invitación), HU-24 (clientes), etc. |
| `presentation/home_view_model.dart` | Usuario actual y `logout()` (usa el `AuthRepository` del dominio de `auth`) |
| `presentation/widgets/home_scaffold.dart` | Barra con el botón **Cerrar sesión** (con confirmación) común a ambas |
| `presentation/widgets/welcome_message.dart` | Contenido provisional |

- No tiene capas de datos ni dominio propias todavía; cuando una historia necesite datos de inicio, se agregan aquí
  siguiendo la plantilla de `lib/features/README.md`.
- HU-03 pedirá que un usuario con `profileCompleted == false` vaya primero al formulario de perfil: esa regla irá en
  `resolveRedirect` (`lib/app/router.dart`), no en estas vistas.
