# `lib/features/weights/` — Registro e Historial de Peso (HU-21-APP)

## Estructura

- `domain/`:
  - `entities/weight_entry.dart`: Entidad de dominio `WeightEntry`.
  - `repositories/weights_repository.dart`: Contrato del repositorio de pesos.
- `data/`:
  - `models/weight_model.dart`: Modelo JSON con `fromJson` y conversión a entidad `toEntity()`.
  - `datasources/weights_remote_data_source.dart`: DataSource remoto para `GET` y `POST /users/me/weights`.
  - `repositories/weights_repository_impl.dart`: Implementación concreta del repositorio.
- `presentation/weights/`:
  - `weights_view.dart`: Pantalla de formulario de registro de peso e historial ordenado del más reciente al más antiguo.
  - `weights_view_model.dart`: ViewModel con `FormStateMixin` para validación local (35 a 250 kg usando `ProfileValidators`), manejo de errores de campo y generales, y recarga de meta al volver.

## Flujo

1. El usuario llega a "Registro e historial de peso" desde la pantalla principal.
2. Ingresa su peso (con validación local de 35 a 250 kg).
3. Al registrarse exitosamente mediante `POST /users/me/weights`, el nuevo registro aparece al inicio del historial.
4. Al regresar a la pantalla principal, la meta vigente se actualiza automáticamente.
