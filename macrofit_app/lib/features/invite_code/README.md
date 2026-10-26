# `features/invite_code/` — código de invitación del coach (HU-12)

**HU-12-APP:** "Como coach, quiero tener un código de invitación para que mis clientes se vinculen conmigo." (RF-11,
CU-02 paso 1). El coach ve su código, lo copia, lo comparte fuera de la app y puede regenerarlo. El cliente lo usará
para vincularse (HU-13).

## Endpoints

Contrato en [backend/README.md](../../../../backend/README.md#código-de-invitación--coachinvite-code-hu-12).
Solo rol `coach`; cliente HTTP **con sesión**.

| Endpoint | Uso |
|---|---|
| `GET /coach/invite-code` | `{ "code": "K7P2QX" }` (6 caracteres `A-Z0-9`). El servidor lo crea si el coach no tiene uno |
| `POST /coach/invite-code/regenerate` | Código nuevo, siempre distinto; el anterior deja de ser válido. Las vinculaciones existentes no cambian |

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/repositories/invite_code_repository.dart` | Contrato `InviteCodeRepository` (`getInviteCode`, `regenerateInviteCode`) |
| `domain/invite_share_message.dart` | `inviteShareMessage(code)` y `inviteShareSubject`: texto que se comparte |
| `data/models/invite_code_model.dart` | `InviteCodeModel` (`{ code }`) |
| `data/datasources/invite_code_remote_data_source.dart` | GET y POST con `guardApiCall` |
| `data/repositories/invite_code_repository_impl.dart` | Implementación del contrato |
| `presentation/invite_code/invite_code_view_model.dart` | Carga, regeneración con confirmación, copiar y compartir |
| `presentation/invite_code/invite_code_view.dart` | Pantalla `/coach/invite-code` («Mi código de invitación») |

## Flujo

1. El coach entra desde el **Panel de coach** (botón «Mi código de invitación» o el icono de la barra) o desde la
   **lista vacía de clientes** (HU-24, «Ver mi código de invitación»).
2. La pantalla carga el código (`GET`). Sin red: `ErrorBanner` + «Reintentar» (RNF-11).
3. **Copiar** pone solo el código en el portapapeles y avisa con un `SnackBar`.
4. **Compartir** abre la hoja del sistema (`share_plus`) con
   «Vincúlate conmigo en MacroFit con mi código de invitación: K7P2QX» (asunto «Mi código de invitación de MacroFit»).
5. **Regenerar código** pide confirmación (el actual deja de funcionar). Al confirmar llama al `POST` y muestra el código
   nuevo con un aviso; al cancelar no se llama a la API.

## Decisiones

- Pantalla propia en lugar de mostrar el código en el panel (acordado con el equipo).
- Copiar y compartir pasan por `ShareService` (`core/platform/`) para probar el ViewModel sin plugins.
- La confirmación se inyecta en `regenerate(confirm)`: la vista abre el diálogo y el ViewModel decide si llama a la API,
  así cancelar se prueba en el ViewModel.
- Si regenerar falla, el código anterior sigue visible (y vigente) y se muestra el error; volver a tocar «Regenerar
  código» es el reintento.
- Copiar, compartir y regenerar se deshabilitan mientras no hay código o se está regenerando.
- «Compartir» manda el área del botón como `sharePositionOrigin` (popover en iPad).

## Pruebas

- `test/features/invite_code/presentation/invite_code_view_model_test.dart`: carga, error de red y reintento,
  regeneración (confirmada, cancelada, con error, estado intermedio), copiar y compartir.
- `test/features/invite_code/data/invite_code_repository_impl_test.dart`: rutas y métodos HTTP, `FORBIDDEN_ROLE`, sin red.
- `test/app/app_test.dart` › código de invitación (HU-12) y lista de clientes (HU-24) › lista vacía.
- `test/app/router_test.dart` › código de invitación (HU-12).
