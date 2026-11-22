# `features/coach_link/` — vinculación con el coach (HU-13, HU-14)

**HU-13:** el usuario se vincula con un coach con su código de invitación (RF-12, CU-02 pasos 2 a 6).
**HU-14:** el usuario se desvincula de su coach (RF-13). Un usuario tiene como máximo un coach activo (RN-02) y, al
desvincularse, el coach pierde el acceso a sus datos (RN-04).

## Endpoints

Contrato en [backend/README.md](../../../../backend/README.md). Solo rol `user`; cliente HTTP **con sesión**.

| Endpoint | Uso |
|---|---|
| `GET /users/me/coach-link/preview?invite_code=` | `{ "coach_name" }` del dueño del código, sin vincular (CU-02 paso 4) |
| `POST /users/me/coach-link` | Crea o reactiva la vinculación; `404 INVITE_CODE_NOT_FOUND`, `409 USER_ALREADY_LINKED` |
| `GET /users/me/coach-link` | Coach vinculado; `404 USER_NOT_LINKED` si no tiene |
| `DELETE /users/me/coach-link` | Desvincula; `404 USER_NOT_LINKED` se trata como éxito |

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/coach_link.dart` | `CoachLink` (id, coach, nombre, correo, estado) |
| `domain/repositories/coach_link_repository.dart` | Contrato `CoachLinkRepository` (`getLinkedCoach`, `previewCoach`, `linkCoach`, `unlinkCoach`) |
| `data/models/coach_link_model.dart` | `CoachLinkModel` (JSON de la vinculación) |
| `data/datasources/coach_link_remote_data_source.dart` | Los cuatro endpoints con `guardApiCall` |
| `data/repositories/coach_link_repository_impl.dart` | Guarda la última vinculación en `flutter_secure_storage` para mostrarla sin conexión |
| `presentation/coach_link/coach_link_view_model.dart` | Código normalizado, vista previa, alta y desvinculación con sus mensajes |
| `presentation/coach_link/coach_link_view.dart` | Pantalla **Vincular con coach** |

## Flujo

1. Sin coach, el usuario escribe el código (se recorta y pasa a mayúsculas) y toca **Vincular coach**.
2. La app pide la vista previa y muestra *¿Quieres vincularte con <coach>?*. Solo al confirmar se vincula; cancelar
   no vincula y conserva el código escrito.
3. Errores (sin confirmación y sin borrar el código): vacío → *El código de invitación es obligatorio.*; inexistente →
   *Código inválido*; con un coach activo → *Primero debes desvincularte* (CU-02 4a y 4b); sin conexión, el mensaje
   de la API.
4. Con coach, la pantalla no pide código: muestra su nombre y correo, avisa *Para vincularte con otro coach, primero
   desvincúlate.* (CU-02 4b) y ofrece **Desvincularme**, que pide confirmación (RF-13).
