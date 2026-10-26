# `features/meals/` — registro de comidas

| Historia | Qué hace |
|---|---|
| **HU-06** | Tomar la foto con la cámara o elegirla de la galería, comprimirla, verla y subirla (`POST /meals/photos`, RF-05, CU-01 pasos 1 y 2) |

Sigue la secuencia HU-06-APP → HU-07-APP (estimación) → HU-08-APP (corrección) → HU-09-APP (guardar).

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/meal_photo.dart` | `PhotoSource` (cámara/galería), `PickedPhoto` (bytes ya comprimidos) y `UploadedPhoto` (`id`, `format`, `size_bytes`) |
| `domain/entities/photo_pick_exception.dart` | `PhotoPickException` con `PhotoPickError`: permiso de cámara o de fotos negado, cámara no disponible |
| `domain/repositories/meal_photo_repository.dart` | Contrato: `pickPhoto(source)` y `uploadPhoto(photo)` |
| `domain/validators/meal_photo_validator.dart` | Reglas de TEC-13: JPEG o PNG por sus primeros bytes y máximo 5 MiB (igual que `backend/src/services/photos.rs`) |
| `data/datasources/photo_picker_data_source.dart` | `image_picker`: abre cámara o galería, comprime y traduce los `PlatformException` de permisos |
| `data/datasources/meal_photos_remote_data_source.dart` | `POST /meals/photos` multipart, campo `photo`, dentro de `guardApiCall` |
| `data/models/uploaded_photo_model.dart` | JSON de la respuesta `201` |
| `data/repositories/meal_photo_repository_impl.dart` | Une ambas fuentes |
| `presentation/meal_photo/` | `/user/meals/photo` — "Registrar comida": vista previa, **Tomar foto**, **Elegir de la galería**, **Usar esta foto** |

## Flujo (HU-06)

1. Desde la pantalla principal del usuario, el botón flotante **Registrar comida** abre `/user/meals/photo`.
2. **Tomar foto** o **Elegir de la galería**. `image_picker` pide el permiso cuando hace falta y entrega la foto ya
   comprimida: lado mayor de 1600 px y JPEG con calidad 85 (PNG si la imagen tiene transparencia). Fotos HEIC o WebP
   de la galería salen como JPEG.
3. La app valida la foto con `MealPhotoValidator` (≤ 5 MiB, JPEG o PNG). Si no cumple, muestra el motivo y conserva la
   foto anterior; nunca se sube una foto mayor de 5 MiB.
4. Se ve la vista previa; tocar **Tomar foto** o **Elegir de la galería** otra vez la cambia. Cancelar el selector no
   borra la foto elegida.
5. **Usar esta foto** la sube. El ViewModel conserva `uploaded.id` para la estimación de HU-07-APP; después de subirla
   ya no se puede cambiar (evita fotos huérfanas en el backend).

### Si Android cierra la app con la cámara abierta

En teléfonos con poca memoria (visto en un moto g60 con el APK debug), Android mata el proceso de MacroFit mientras la
app de cámara está al frente; al volver, la app arranca de cero y la foto no llega a `pickImage`.

- `main.dart` llama primero a `MealPhotoRepository.recoverLostPhoto()` (`retrieveLostData` de `image_picker`, solo
  Android; en otras plataformas no hace nada) y después restaura la sesión.
- Si hay foto recuperada, la ruta del inicio (`/user`) redirige a `/user/meals/photo`, que es su subruta: el inicio
  queda debajo y **atrás** regresa a él.
- `MealPhotoViewModel.restoreRecoveredPhoto()` toma la foto (una sola vez), la valida y la muestra en la vista previa.

## Permisos

| Plataforma | Cámara | Galería |
|---|---|---|
| Android | `CAMERA` en `AndroidManifest.xml` (`image_picker` lo pide al abrir la cámara); `android.hardware.camera` no es obligatoria | Selector de fotos del sistema: no necesita permiso |
| iOS | `NSCameraUsageDescription` en `Info.plist` | `NSPhotoLibraryUsageDescription` en `Info.plist` |

- **Permiso de cámara negado** (CU-01 flujo 2a): se explica cómo habilitarlo en los Ajustes del teléfono y la galería
  sigue disponible.
- **Permiso de fotos negado**: mensaje explicativo; la cámara sigue disponible.
- **Sin cámara** (p. ej. simulador): se ofrece la galería.

## Errores de la subida

| Caso | Mensaje |
|---|---|
| `413 PHOTO_TOO_LARGE` | "La foto pesa más de 5 MB. Elige otra o vuelve a tomarla." |
| `415 UNSUPPORTED_PHOTO_TYPE` | "La foto debe ser JPEG o PNG. Elige otra o vuelve a tomarla." |
| Sin conexión (`NETWORK_ERROR`) | El mensaje de `ApiException`; la foto se conserva para reintentar |
| Otros | El mensaje del backend |

La subida usa un tiempo de espera de 60 s (envío y respuesta), mayor que el general, por si la red móvil es lenta.

## Pendientes

- `// TODO(HU-07-APP)`: al subir la foto, pasar su `id` a la pantalla de estimación.
- No probado en iOS (no hay dispositivo); ahí no aplica la recuperación de la foto perdida.
