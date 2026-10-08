# MacroFit

App móvil para **registrar la alimentación con una foto** —el sistema estima calorías,
proteína y grasa— y **seguir rutinas de entrenamiento**, con dos roles: usuario y coach.
El coach vincula clientes, ajusta sus metas y les asigna rutinas.

## Documentación

| Documento | Contenido |
|---|---|
| [product_backlog_macrofit.md](product_backlog_macrofit.md) | Historias técnicas (TEC) y de usuario (HU), prioridad y story points |
| [esquema_pruebas_sprint1.md](esquema_pruebas_sprint1.md) | Casos de prueba del sprint 1 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Estrategia de ramas, commits y pull requests |
| [docs/legal/aviso-de-privacidad.md](docs/legal/aviso-de-privacidad.md) | Aviso de privacidad integral (TEC-07) |

## Estructura

```
.
├── .github/          # CI, plantilla de PR y de issues
├── backend/          # API en Rust (Axum, MongoDB, JWT) bajo /api/v1 -> Ver backend/README.md
│   ├── src/          # Cada subcarpeta tiene un README.md con sus reglas
│   └── postman/      # Pruebas de Postman: una colección por módulo + combinado generado
├── docs/legal/       # Aviso de privacidad (lo sirve el backend en /legal/privacy)
├── macrofit_app/     # App Flutter: MVVM en 3 capas por feature -> Ver macrofit_app/README.md
│   ├── lib/
│   │   ├── app/      # Dependencias, router con guard de sesión, tema
│   │   ├── core/     # Config, errores, red, base de ViewModel, widgets comunes
│   │   └── features/ # auth, legal, home… cada una con domain/ data/ presentation/
│   └── test/
└── *.md              # Backlog y esquema de pruebas
```

Arquitectura de la app (TEC-04): **MVVM en 3 capas** (presentación, dominio, datos) organizada por feature, con
`provider` + `ChangeNotifier`, `go_router` y `dio`; detalles en [macrofit_app/README.md](macrofit_app/README.md).
El backend (TEC-03, TEC-05) se documenta en [backend/README.md](backend/README.md), incluidas las pruebas en Postman.

## Requisitos

- Flutter **3.47** (stable) — Dart 3.13
- Android Studio (SDK de Android) y/o Xcode para iOS

## Arranque

```bash
cd macrofit_app
flutter pub get
flutter run
```

## Comprobaciones

Las mismas que corre la CI en cada PR:

```bash
cd macrofit_app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Identificadores

| Plataforma | ID |
|---|---|
| Android (`applicationId`) | `com.macrofit.app` |
| iOS / macOS (bundle id) | `com.macrofit.app` |

## Licencia

[MIT](LICENSE)
