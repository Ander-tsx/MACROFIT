# `features/legal/` — aviso de privacidad (TEC-07)

El texto del aviso **no vive en la app**: la única fuente es `docs/legal/aviso-de-privacidad.md`, que el backend
embebe al compilar y sirve en `GET /api/v1/legal/privacy` como `{ version, content }` (Markdown).

| Capa | Archivo | Contenido |
|---|---|---|
| Dominio | `entities/privacy_notice.dart` | `PrivacyNotice { version, content }` |
| | `repositories/legal_repository.dart` | Contrato `getPrivacyNotice()` |
| Datos | `datasources/legal_remote_data_source.dart` | `GET /legal/privacy` (cliente público) |
| | `repositories/legal_repository_impl.dart` | Guarda el aviso en memoria tras la primera carga |
| Presentación | `privacy_notice/` | `PrivacyNoticeView` (Markdown con `flutter_markdown_plus`) + `PrivacyNoticeViewModel` (carga, error y reintento) |

- Ruta pública `/privacy`; se abre desde el registro y también está disponible con sesión.
- Para cambiar el aviso se edita `docs/legal/aviso-de-privacidad.md` (y su `**Versión:**`) y se recompila el backend;
  la app no necesita cambios.
