# `src/` — código del backend

Arquitectura por capas. Cada capa solo conoce a las de abajo:

```
main.rs ─▶ routes/ ─▶ services/ ─▶ models/
              │            │
              └──▶ auth/ ◀─┘        error.rs, validation.rs, state.rs: transversales
```

| Archivo / carpeta | Responsabilidad | No debe |
|---|---|---|
| `main.rs` | Cargar config, conectar a Mongo, montar el router | Tener lógica de negocio ni rutas sueltas |
| `config.rs` | Leer variables de entorno; `panic` si falta una obligatoria | Leer variables en otros módulos (`std::env::var` solo aquí) |
| `state.rs` | `AppState` que reciben los handlers | Guardar estado mutable sin sincronización |
| `db.rs` | Conexión y **todos los índices** (`ensure_indexes`) | Crear índices en otro lugar |
| `error.rs` | `AppError`, su conversión al formato `{ error: { code, message, fields } }` y el extractor `ApiJson` | — |
| `validation.rs` | Reglas puras reutilizables (correo, longitudes) | Acceder a la base de datos |
| `routes/` | HTTP: rutas, DTOs de entrada/salida, handlers delgados | Acceder a Mongo directamente |
| `services/` | Reglas de negocio, validación del caso de uso, consultas a Mongo | Conocer tipos HTTP (`StatusCode`, `Json`) |
| `models/` | Structs que se guardan en Mongo y constantes de colección | Serializarse hacia el cliente |
| `auth/` | JWT, hash de contraseñas, extractores `AuthenticatedUser` / `CoachOnly` | Lógica de un dominio concreto |

## Convenciones

- Módulos y archivos en `snake_case`, un archivo por dominio (`auth.rs`, `profile.rs`, `meals.rs`...).
- Los errores se propagan con `?` y siempre terminan en `AppError`. Para errores inesperados: `AppError::internal(err)`.
- Pruebas unitarias en el mismo archivo (`#[cfg(test)] mod tests`), con nombres en español que describan el caso
  (`contrasena_corta_senala_password`).
- `cargo fmt` y `cargo clippy --all-targets -- -D warnings` sin avisos antes de subir.
