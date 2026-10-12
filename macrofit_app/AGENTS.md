# AGENTS.md — App MacroFit (Flutter)

Instrucciones para cualquier agente de IA (Claude Code, Codex, Copilot, Cursor, etc.) que modifique `macrofit_app/`.
Son obligatorias. Si algo aquí contradice a otro documento, avisa a la persona en lugar de elegir por tu cuenta.

Documentación de referencia (léela antes de tocar una carpeta):

| Documento | Contenido |
|---|---|
| [README.md](README.md) | Cómo ejecutar, arquitectura, reglas generales, cómo agregar una historia |
| [lib/app/README.md](lib/app/README.md) | Dependencias, router y guard de sesión |
| [lib/core/README.md](lib/core/README.md) | Config, `ApiException`, red, `ViewModel`, widgets comunes |
| [lib/features/README.md](lib/features/README.md) | Plantilla de feature y convenciones de capas |
| `lib/features/<feature>/README.md` | Historias, flujos y reglas de cada feature |
| [test/README.md](test/README.md) | Estructura de pruebas y *fakes* |
| [../backend/README.md](../backend/README.md) | Contrato de la API (endpoints, respuestas, códigos de error) |
| [../product_backlog_macrofit.md](../product_backlog_macrofit.md) | Historias (`HU-XX`) y tareas técnicas (`TEC-XX`) |
| [../esquema_pruebas_sprint1.md](../esquema_pruebas_sprint1.md) | Casos de prueba esperados por historia |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Ramas, commits y pull requests |

---

## 1. Reglas de colaboración

1. **No asumas decisiones de lógica que no estén declaradas.** Si la historia, el código o estos documentos no definen
   algo que impacta el comportamiento (flujo de navegación, qué pasa ante un error o sin red, qué se guarda en el
   dispositivo, reglas de validación, librerías nuevas, alcance), **pregunta antes de implementar** y ofrece una opción
   recomendada. Las decisiones pequeñas (textos, iconos, espaciados, nombres internos) tómalas tú y menciónalas al final.
2. **Alcance**: haz lo que pide la historia. Si el backend no tiene el endpoint que necesitas, dilo; no lo inventes en la app.
   Cambios al backend siguen `../backend/AGENTS.md`.
3. **Lo que no se puede probar en este entorno** (dispositivo físico, iOS, capturas para el PR, rendimiento real) se
   reporta como pendiente; nunca se da por hecho.
4. **No hagas commit, push ni PR** salvo que la persona lo pida. Si lo pide, sigue `../CONTRIBUTING.md`.
5. **Idioma**: textos de la UI, comentarios, README y nombres de pruebas en **español**; identificadores en inglés.

## 2. Stack

- Flutter **3.47** (stable), Dart **3.13** (se usan *sealed classes*, *patterns* y parámetros nombrados privados `this._x`).
- `provider` + `ChangeNotifier` (MVVM), `go_router` (rutas y guard), `dio` (HTTP), `flutter_secure_storage` (sesión),
  `flutter_markdown_plus` (aviso de privacidad).
- No agregues paquetes sin preguntar; si se aprueba, documéntalo en la tabla de paquetes de `README.md`.

## 3. Arquitectura

**MVVM en 3 capas, organizada por feature** (`lib/features/<feature>/{domain,data,presentation}`), más `lib/app`
(composición) y `lib/core` (transversal).

```
View ──watch──▶ ViewModel ──▶ Repository (contrato, dominio) ◀── RepositoryImpl (datos) ──▶ DataSource ──▶ API / almacenamiento
```

| Capa | Hace | Nunca |
|---|---|---|
| `presentation/` | Vistas (`StatelessWidget`) y ViewModels (`extends ViewModel`) | Importar Dio, `data/`, JSON o almacenamiento |
| `domain/` | Entidades, contratos `XRepository`, validadores puros | Importar Flutter widgets, Dio o paquetes de datos |
| `data/` | `XModel` (JSON), `XRemoteDataSource`/`XLocalDataSource`, `XRepositoryImpl` | Ser usada por la presentación directamente |
| `app/` | `dependencies.dart` (único lugar que instancia implementaciones), router, tema | Contener lógica de una historia |
| `core/` | Config, `ApiException`, `createDio`/`guardApiCall`, `ViewModel`, widgets comunes | Contener lógica de una historia |

Una feature solo usa el **dominio** de otra feature, nunca su capa de datos o presentación.

## 4. Reglas de código (no negociables)

1. **Un ViewModel por pantalla**, creado en el `GoRoute` con `ChangeNotifierProvider(create: ...)`, recibiendo sus
   repositorios por constructor. Hereda de `core/presentation/ViewModel` (no notifica tras `dispose`).
2. **Las vistas no tienen lógica**: `context.watch<XViewModel>()`, muestran estado y llaman métodos.
3. **Navegación por sesión solo vía el router**: login/logout/expiración cambian `AuthRepository.state` y
   `resolveRedirect` decide la pantalla. Nunca `context.go(home)` después de un login.
4. **Rutas** solo con `AppRoutes`. Rutas públicas en `AppRoutes.public`; reglas por rol en `resolveRedirect` (con prueba).
5. **Errores**: toda llamada remota va dentro de `guardApiCall`; solo `ApiException` sale de la capa de datos. Compara
   códigos con `ApiErrorCode`. Formularios: `FormStateMixin.applyApiError(error, knownFields: {...})`.
6. **Nombres de campos** de formularios = nombres de la API (`name`, `email`, `privacy_accepted`...).
7. **Validación local** antes de enviar, con las mismas reglas que el backend (`auth_validators.dart` ↔
   `backend/src/validation.rs`). Si cambias una regla, cambia ambas.
8. **Modelos JSON** (`XModel`) en `data/models/` con `fromJson`/`toJson`/`toEntity`; las entidades del dominio no conocen JSON.
9. **Dependencias** solo en `app/dependencies.dart`; nada de singletons globales ni `GetIt`.
10. **Claves de prueba** (`Key('feature_campo')`) en campos y botones principales.
11. Sin `print` (lint `avoid_print`); `unawaited(...)` explícito para futuros que no se esperan.
12. Pendientes de otra historia: `// TODO(ID-BACKLOG): qué falta`.

## 5. Seguridad (no negociable)

- Tokens y usuario de la sesión **solo** en `SessionLocalDataSource` (`flutter_secure_storage`). Nunca en
  SharedPreferences, archivos, logs ni mensajes de error.
- Nunca guardes ni registres contraseñas.
- No cambies el modelo de sesión de HU-02 (renovación automática, cierre local aunque falle el servidor, entrada con
  usuario guardado sin red) sin aprobación.
- HTTP sin TLS solo en debug (`android/app/src/debug/AndroidManifest.xml`, `NSAllowsLocalNetworking` en iOS).
  No habilites *cleartext* en `src/main`.
- No apuntes la app a la base de datos compartida (Atlas) para pruebas sin permiso; usa un backend local con base temporal.

## 6. Comandos

Desde `macrofit_app/`:

| Comando | Para qué |
|---|---|
| `flutter pub get` | Dependencias |
| `flutter run` | Ejecutar (backend local por defecto) |
| `flutter run --dart-define=API_BASE_URL=http://<IP>:3000/api/v1` | Ejecutar contra otro backend (teléfono físico) |
| `dart format lib test` / `dart format --output=none --set-exit-if-changed lib test` | Formato / verificación |
| `flutter analyze` | Análisis estático (un aviso rompe la CI) |
| `flutter test` | Pruebas unitarias y de widgets |

## 7. Verificación obligatoria antes de dar una tarea por terminada

1. `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze` sin avisos y `flutter test` sin fallos.
2. Pruebas nuevas para cada criterio de aceptación de la historia (ver `test/README.md`).
3. **Prueba de punta a punta** de los flujos nuevos contra el backend real con base temporal, cuando el entorno lo
   permita (en un emulador/dispositivo, o en web si no hay uno):
   - Backend: `MONGO_URI=mongodb://localhost:27017 DB_NAME=macrofit_check PORT=3077 ./target/debug/backend`
     (ver `../backend/AGENTS.md` §7).
   - App: `--dart-define=API_BASE_URL=http://<host>:3077/api/v1`.
   - Al terminar, detén los servidores y borra la base temporal que creaste.
4. Documentación actualizada (sección 8).
5. Resumen final: qué se hizo, decisiones menores, resultados de verificación y pendientes reales (p. ej. "no probado en iOS").

## 8. Al agregar o cambiar funcionalidad

1. Lee el contrato del endpoint en `../backend/README.md`.
2. Crea/amplía `lib/features/<feature>/` siguiendo la plantilla de `lib/features/README.md`.
3. Registra repositorios en `app/dependencies.dart` y en el `MultiProvider` de `app/app.dart`.
4. Rutas en `app/routes.dart` + `app/router.dart`; si cambia quién puede verlas, `resolveRedirect` y `test/app/router_test.dart`.
5. Si el backend agrega códigos de error, añádelos a `ApiErrorCode`.
6. Documentación: README de la feature (archivos, flujo, decisiones), tabla de features en `lib/features/README.md`
   y lista de historias en `README.md`.

## 9. Trampas conocidas

- **`pumpAndSettle` y animaciones infinitas**: la pantalla de carga (`SplashView`) gira sin fin; en pruebas usa `pump()`.
- **ViewModel después de `dispose`**: el login exitoso navega y destruye la pantalla antes de que termine el `finally`;
  por eso todo ViewModel hereda de `ViewModel`, que ignora notificaciones tras `dispose`.
- **Interceptor de sesión**: es un `QueuedInterceptor`; el reintento usa el cliente **público** (`retryClient`). Reintentar
  con el mismo cliente bloquea la cola.
- **Refresh token reutilizado revoca la sesión** en el backend: nunca renueves dos veces con el mismo refresh token.
- **`10.0.2.2`** es el `localhost` de la computadora desde el emulador de Android. Un teléfono físico no lo resuelve:
  usa `adb reverse tcp:3000 tcp:3000` + `API_BASE_URL=http://localhost:3000/api/v1` (cable USB) o la IP de la
  computadora en la misma red (ver "Teléfono Android físico" en `README.md`).
- **`flutter_markdown` está descontinuado**: se usa `flutter_markdown_plus`.
- **Finales de línea**: el repositorio usa `core.autocrlf=true`; los archivos de trabajo pueden tener CRLF.
- **Rendimiento en el emulador**: el modo debug (JIT, sin optimizar) en un emulador es mucho más lento que en un
  teléfono. No juzgues el rendimiento de la app ahí; mídelo en un dispositivo con `flutter run --profile`.
