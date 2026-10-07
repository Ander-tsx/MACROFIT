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

## Estructura

```
.
├── .github/          # CI, plantilla de PR y de issues
├── backend/          # API en Rust (Axum, MongoDB, JWT) bajo /api/v1 -> Ver backend/README.md
│   ├── src/          # Cada subcarpeta tiene un README.md con sus reglas
│   └── postman/      # Pruebas de Postman: una colección por módulo + combinado generado
├── macrofit_app/     # Aplicación Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   └── app/      # Raíz de la app y tema
│   └── test/
└── *.md              # Backlog y esquema de pruebas
```

La arquitectura por capas y la gestión de estado se definen en **TEC-04**; el backend, en **TEC-03** y **TEC-05**. Consulta [backend/README.md](backend/README.md) para detalles de ejecución del servidor y pruebas en Postman.

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
