# `test/` — pruebas de la app

La estructura replica `lib/`:

```
test/
├── helpers/fakes.dart        # Fakes compartidos (repositorios, almacenamiento, adaptador HTTP)
├── app/
│   ├── router_test.dart      # resolveRedirect: guard de sesión y redirección por rol
│   └── app_test.dart         # Flujos de widgets: carga inicial, login por rol, registro, aviso, logout + atrás
└── features/auth/
    ├── domain/               # Validadores
    ├── data/                 # AuthRepositoryImpl (restaurar, login, logout) y AuthInterceptor (renovación)
    └── presentation/         # LoginViewModel, RegisterViewModel
```

```bash
flutter test
```

## Convenciones

- **Sin red ni plugins reales.** Se usan *fakes* escritos a mano (no hay librería de mocks):
  - `FakeAuthRepository`, `FakeLegalRepository` para ViewModels y widgets.
  - `FakeSessionLocalDataSource` en lugar de `flutter_secure_storage`.
  - `FakeHttpAdapter` + `jsonResponse` / `errorResponse` para simular el backend en Dio.
- Nombres de pruebas en español que describan el comportamiento (`'sin red conserva la sesión guardada'`).
- Una prueba por criterio de aceptación relevante; los criterios de HU-01/HU-02 tienen al menos una cada uno.
- Widgets: encontrar elementos por `Key` (`Key('login_submit')`) o texto visible. Si la pantalla tiene animaciones
  infinitas (carga inicial), usar `pump()` en lugar de `pumpAndSettle()`.
- Si una prueba falla, corrige la causa; no relajes la prueba.
