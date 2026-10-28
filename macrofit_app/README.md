# macrofit_app — App móvil de MacroFit (Flutter)

App de MacroFit para los roles **usuario** y **coach**. Consume la API del backend (`../backend`, ver
[backend/README.md](../backend/README.md)). Ramas, commits y PR en [CONTRIBUTING.md](../CONTRIBUTING.md).

Historias implementadas: **HU-01** (registro con rol y aviso de privacidad), **HU-02** (inicio, persistencia y
cierre de sesión) y **HU-03** (perfil inicial del usuario y su edición) y **HU-05** (el coach fija las metas de sus clientes).

> **Si eres una persona o una sesión de IA que va a modificar la app, lee este archivo y el `README.md` de cada
> carpeta que vayas a tocar** (`lib/app`, `lib/core`, `lib/features`, `lib/features/<feature>`, `test`).
> Toda decisión de lógica que una historia no defina se consulta con el equipo antes de implementarla.
> Los agentes de IA siguen además [AGENTS.md](AGENTS.md) (todos) y [CLAUDE.md](CLAUDE.md) (Claude Code).

---

## Requisitos

- Flutter **3.47** (stable) — Dart 3.13.
- Android Studio (SDK de Android) y/o Xcode.
- El backend corriendo (`cd ../backend && cargo run`).

## Ejecutar

```bash
cd macrofit_app
flutter pub get
flutter run
```

La URL del backend se define con `--dart-define`. Sin él se usa el backend local en el puerto 3000:

| Dónde corre la app | URL por defecto |
|---|---|
| Emulador de Android | `http://10.0.2.2:3000/api/v1` (`10.0.2.2` es el `localhost` de tu computadora) |
| Simulador de iOS, web, escritorio | `http://localhost:3000/api/v1` |
| Teléfono físico | Obligatorio indicarla (ver abajo) |

### Teléfono Android físico

**Por cable USB (recomendado):** `adb reverse` hace que `localhost:3000` en el teléfono apunte al puerto 3000 de tu
computadora. No depende de la red Wi-Fi ni del firewall.

```bash
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

- El túnel se pierde al desconectar el cable o reiniciar `adb`: vuelve a ejecutar `adb reverse`.
- Comprueba que llega al backend: `adb shell curl -s http://127.0.0.1:3000/api/v1/health` → `API MacroFit OK`.
- Si `adb` no está en el PATH: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
- En Android Studio: *Run → Edit Configurations… → main.dart → Additional run args*:
  `--dart-define=API_BASE_URL=http://localhost:3000/api/v1` (puedes duplicar la configuración para emulador y teléfono).

**Por Wi-Fi (misma red):** usa la IP de la computadora (`ipconfig` → "Dirección IPv4"):
`flutter run --dart-define=API_BASE_URL=http://<IP-de-tu-PC>:3000/api/v1`. El Firewall de Windows debe permitir el
puerto 3000 en redes privadas; las redes institucionales suelen bloquear la conexión entre dispositivos.

HTTP sin TLS solo está permitido en **debug** (Android: `src/debug/AndroidManifest.xml`; iOS: `NSAllowsLocalNetworking`).
En producción la API debe ser HTTPS.

### Rendimiento en el emulador

`flutter run` compila en modo **debug** (JIT, sin optimizar, con verificaciones extra). En un emulador eso se nota
mucho más que en un teléfono; **no es un problema de la app**. Para medir rendimiento real usa un teléfono con
`flutter run --profile` (el modo profile no funciona en emuladores). Para que el emulador vaya más fluido:

- En *Device Manager → Edit → Show Advanced Settings*: **Graphics: Hardware**, **RAM: 4096 MB** o más.
- Usa una imagen de sistema estándar (x86_64, *Google APIs* o *Google Play*), no la de *16 KB page size*.
- En Windows, *Configuración → Pantalla → Gráficos*: asigna "Alto rendimiento" a
  `qemu-system-x86_64.exe` si el equipo tiene GPU dedicada.
- Ejecuta la app desde la terminal (`flutter run`) y cierra herramientas de inspección de Android Studio que no uses.

## Comprobaciones (las mismas de la CI)

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

---

## Arquitectura

**MVVM en 3 capas, organizada por feature.**

```
lib/
├── main.dart              # Arranque: crea dependencias, restaura sesión, runApp
├── app/                   # Composición: dependencias, router, tema → lib/app/README.md
├── core/                  # Transversal: config, errores, red, base de ViewModel, widgets → lib/core/README.md
└── features/              # Una carpeta por funcionalidad → lib/features/README.md
    ├── auth/              # HU-01 registro, HU-02 sesión
    │   ├── domain/        # Entidades, contrato del repositorio, validadores (Dart puro)
    │   ├── data/          # Modelos JSON, fuentes de datos (API, almacenamiento seguro), repositorio
    │   └── presentation/  # Vistas (widgets) + ViewModels (ChangeNotifier)
    ├── legal/             # TEC-07 aviso de privacidad
    ├── profile/           # HU-03 perfil inicial y edición
    ├── goals/             # HU-04 dominio de la meta, HU-05 metas por coach
    └── home/              # Pantallas principales por rol (solo presentación por ahora)
```

| Capa | Contiene | Depende de | Nunca |
|---|---|---|---|
| **Presentación** | `*_view.dart` (widgets) y `*_view_model.dart` (`ViewModel`) | Dominio | Llamar a Dio, leer almacenamiento, conocer JSON |
| **Dominio** | Entidades, contratos `*Repository`, validadores | Nada (solo `foundation` para `ChangeNotifier`) | Importar Dio, widgets o paquetes de datos |
| **Datos** | `*Model` (JSON), `*DataSource`, `*RepositoryImpl` | Dominio y `core` | Ser usada directamente por la presentación |

Flujo: `View → ViewModel → Repository (contrato del dominio) → RepositoryImpl → DataSource → API / almacenamiento`.

**Paquetes:**

| Paquete | Uso |
|---|---|
| `provider` | Inyección de repositorios y de un ViewModel por pantalla (`ChangeNotifierProvider`) |
| `go_router` | Rutas y *guard* de sesión (`redirect` global) |
| `dio` | HTTP; interceptor de sesión con renovación automática |
| `flutter_secure_storage` | Tokens y usuario de la sesión (Keychain / Keystore) |
| `flutter_markdown_plus` | Renderizar el aviso de privacidad (sustituye a `flutter_markdown`, descontinuado) |

## Reglas generales

1. **Un ViewModel por pantalla**, creado en la ruta con `ChangeNotifierProvider` y heredando de `core/presentation/ViewModel`.
   La vista usa `context.watch<XViewModel>()` y solo llama métodos del ViewModel.
2. **La navegación por sesión no se hace a mano**: login, logout y sesión expirada cambian el estado del
   `AuthRepository` y el router redirige solo. Las vistas solo navegan entre pantallas públicas o abren detalles (`push`).
3. **Rutas** solo con las constantes de `app/routes.dart`.
4. **Errores**: las fuentes de datos convierten todo `DioException` en `ApiException` (`guardApiCall`).
   Los ViewModels muestran `fields` junto a su campo y el resto como error general (`FormStateMixin.applyApiError`).
5. **Validación local** antes de llamar al backend, con las **mismas reglas** que el backend (`auth_validators.dart`
   ↔ `backend/src/validation.rs`). Si cambia una, cambia la otra.
6. **Nombres de campos** de formulario = nombres de la API (`name`, `email`, `privacy_accepted`...) para mapear errores del backend.
7. **Nada sensible fuera del almacenamiento seguro**: tokens y usuario solo en `SessionLocalDataSource`.
8. **Textos de la UI en español**; código en inglés; comentarios en español.
9. **Dependencias**: se crean solo en `app/dependencies.dart`. Nada de singletons globales.
10. Cada historia nueva agrega pruebas (ver [test/README.md](test/README.md)).

## Cómo agregar una historia

1. Lee el contrato del endpoint en [backend/README.md](../backend/README.md).
2. Crea o amplía `lib/features/<feature>/` con sus tres capas (plantilla en [lib/features/README.md](lib/features/README.md)).
3. Registra el repositorio en `app/dependencies.dart` y en el `MultiProvider` de `app/app.dart`.
4. Agrega la ruta en `app/routes.dart` y `app/router.dart`; si es pública o exclusiva de un rol, actualiza `resolveRedirect`.
5. Pruebas: validadores/ViewModels (unitarias), repositorio con *fakes*, y un flujo en `test/app/app_test.dart` si cambia la navegación.
6. Actualiza el README de la feature y la lista de historias de este archivo.
