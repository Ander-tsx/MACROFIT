# `test/` — pruebas de la app

La estructura replica `lib/`:

```
test/
├── helpers/fakes.dart        # Fakes compartidos (repositorios, almacenamiento, adaptador HTTP)
├── app/
│   ├── router_test.dart      # resolveRedirect: guard de sesión y redirección por rol
│   └── app_test.dart         # Flujos de widgets: carga inicial, login por rol, registro, aviso, logout + atrás, perfil (HU-03), metas por coach (HU-05), foto de la comida (HU-06), estimación nutricional (HU-07), formulario de valores (HU-08), lista de clientes (HU-24), comidas de un cliente (HU-25), código de invitación (HU-12)
├── features/meals/           # MealPhotoValidator, MealPhotoRepositoryImpl (Dio e image_picker simulados) y MealPhotoViewModel; MealsRepositoryImpl (Dio simulado) y MealEstimateViewModel (HU-07); MealValuesValidator y MealFormViewModel (HU-08)
├── features/profile/         # Validadores, ProfileRepositoryImpl (Dio simulado) y ProfileFormViewModel
├── features/goals/           # Cálculo de la meta, validadores, CoachGoalsRepositoryImpl y CoachGoalFormViewModel
├── features/invite_code/     # InviteCodeRepositoryImpl (Dio simulado) e InviteCodeViewModel (HU-12)
├── features/clients/         # Búsqueda por nombre, ClientsRepositoryImpl (JSON con nulos), textos del resumen y ViewModels de lista y detalle (HU-24); comidas y fotos con Dio simulado, textos y ViewModel de comidas (HU-25)
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
  - `FakeAuthRepository`, `FakeLegalRepository`, `FakeProfileRepository`, `FakeGoalsRepository` (meta vigente, HU-26; `withoutGoal()` responde `404 PROFILE_NOT_FOUND`), `FakeCoachGoalsRepository`, `FakeMealPhotoRepository`, `FakeMealsRepository`, `FakeClientsRepository` para ViewModels y widgets.
  - Fotos (HU-06): `testPhoto` (PNG real de 1×1, se puede dibujar), `jpegBytes(n)` (firma JPEG de `n` bytes) y `testUploadedPhoto`.
  - Estimación (HU-07): `testPhotoUpload` (foto + id), `testEstimate` (un alimento con porción y otro sin ella) y
    `FakeMealsRepository` (`estimateError`, `estimateGate` para ver la carga, registra `estimates`).
  - Guardado (HU-08): `FakeMealsRepository` registra cada `NewMeal` en `created`; `createError` simula un error de la API.
  - Cuentas: `testUser` (con perfil), `testNewUser` (sin perfil, va al formulario de HU-03) y `testCoach`.
  - Clientes del coach (HU-24): `testClientSummary` (meta del coach y un registro, mismo id que `testClient`) y
    `testClientWithoutData` (`goal` y `last_meal_at` nulos).
  - Comidas de un cliente (HU-25): `testMealWithPhoto()` y `testManualMeal()` (con `eatenAt` opcional), `testPhotoBytes`
    (PNG de 1×1) y `dayOf(fecha)`. `FakeClientsRepository(meals: {día: [...]})` responde por día y registra
    `mealRequests` y `photoRequests`.
  - Código de invitación (HU-12): `FakeInviteCodeRepository` (`testInviteCode`; cada regeneración entrega el siguiente
    de `nextCodes`, `regenerateGate` para ver el estado intermedio) y `FakeShareService` (registra `copied` y `shared`).
  - `FakeSessionLocalDataSource` en lugar de `flutter_secure_storage`.
  - `FakeHttpAdapter` + `jsonResponse` / `errorResponse` para simular el backend en Dio.
- Nombres de pruebas en español que describan el comportamiento (`'sin red conserva la sesión guardada'`).
- Una prueba por criterio de aceptación relevante; los criterios de HU-01/HU-02 tienen al menos una cada uno.
- Widgets: encontrar elementos por `Key` (`Key('login_submit')`) o texto visible. Si la pantalla tiene animaciones
  infinitas (carga inicial), usar `pump()` en lugar de `pumpAndSettle()`.
- Si una prueba falla, corrige la causa; no relajes la prueba.
