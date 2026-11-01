# `features/meals/` — registro de comidas

| Historia | Qué hace |
|---|---|
| **HU-06** | Tomar la foto con la cámara o elegirla de la galería, comprimirla, verla y subirla (`POST /meals/photos`, RF-05, CU-01 pasos 1 y 2) |
| **HU-07** | Estimar calorías, proteína y grasa de la foto subida (`POST /meals/estimate`, RF-06, CU-01 pasos 3 y 4, flujos 3a y 4a) |
| **HU-08** | Revisar y corregir los valores (o capturarlos a mano) y guardar el registro con los finales y los estimados (`POST /meals`, RF-07, CU-01 paso 5) |
| **HU-09** | Guardar desde la estimación, historial del día con cambio de fecha y eliminación con confirmación (`POST /meals`, `GET /meals?date=`, `DELETE /meals/{id}`, RF-08, RNF-09, CU-01 pasos 6 y 7) |

Secuencia: HU-06 (foto) → HU-07 (estimación) → **Guardar** o HU-08 (corrección) → HU-09 (historial del día).

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/meal_photo.dart` | `PhotoSource` (cámara/galería), `PickedPhoto` (bytes ya comprimidos), `UploadedPhoto` (`id`, `format`, `size_bytes`) y `MealPhotoUpload` (foto + su id, lo que recibe la estimación) |
| `domain/entities/meal.dart` | `MealDraft` (lo que recibe el formulario: foto y estimados opcionales), `NewMeal` (cuerpo de `POST /meals`) y `Meal` (registro guardado) |
| `domain/entities/meal_estimate.dart` | `NutritionValues` (calorías, proteína y grasa), `EstimatedFood` (nombre, gramos opcionales y valores) y `MealEstimate` (alimentos y totales) |
| `domain/entities/photo_pick_exception.dart` | `PhotoPickException` con `PhotoPickError`: permiso de cámara o de fotos negado, cámara no disponible |
| `domain/repositories/meal_photo_repository.dart` | Contrato: `pickPhoto(source)` y `uploadPhoto(photo)` |
| `domain/repositories/meals_repository.dart` | Contrato de los registros de comida: `estimate(photoId)` (HU-07), `createMeal(meal)` (HU-08), `getMeals(day)`, `deleteMeal(id)` y `getMealPhoto(photoId)` (HU-09) |
| `domain/validators/meal_photo_validator.dart` | Reglas de TEC-13: JPEG o PNG por sus primeros bytes y máximo 5 MiB (igual que `backend/src/services/photos.rs`) |
| `domain/validators/meal_values_validator.dart` | Reglas de HU-08: números no negativos, calorías hasta 10 000 y proteína y grasa hasta 1 000 g; acepta coma decimal (igual que `backend/src/services/meals.rs`) |
| `data/datasources/photo_picker_data_source.dart` | `image_picker`: abre cámara o galería, comprime y traduce los `PlatformException` de permisos |
| `data/datasources/meal_photos_remote_data_source.dart` | `POST /meals/photos` multipart, campo `photo`, dentro de `guardApiCall` |
| `data/models/uploaded_photo_model.dart` | JSON de la respuesta `201` |
| `data/datasources/meals_remote_data_source.dart` | `POST /meals/estimate` con `{ photo_id }`, `POST /meals`, `GET /meals?date=AAAA-MM-DD`, `DELETE /meals/{id}` y `GET /meals/photos/{id}` (bytes), dentro de `guardApiCall` |
| `data/models/meal_estimate_model.dart` | JSON de la estimación (`photo_id`, `foods` con `grams` nulo, `totals`) y `NutritionValuesModel` |
| `data/models/meal_model.dart` | `NewMealModel` (cuerpo de `POST /meals`: `photo_id` y `estimated` solo si los hay) y `MealModel` (registro guardado) |
| `data/repositories/meals_repository_impl.dart` | Convierte entre modelos y entidades |
| `data/repositories/meal_photo_repository_impl.dart` | Une ambas fuentes |
| `presentation/meal_photo/` | `/user/meals/photo` — "Registrar comida": vista previa, **Tomar foto**, **Elegir de la galería**, **Usar esta foto** y **Capturar sin foto** (HU-08) |
| `presentation/meal_estimate/` | `/user/meals/estimate` — "Estimación": carga, alimentos y totales con la leyenda, **Guardar** (HU-09) y **Corregir valores**; ante un error **Reintentar** y **Capturar a mano** |
| `presentation/meal_form/` | `/user/meals/form` — "Revisar valores" (precargado) o "Captura manual" (vacío): calorías, proteína y grasa y **Guardar** |
| `presentation/meal_history/` | `/user/meals` — "Mis comidas": registros del día (hora, foto o *Captura manual*, valores), total del día, cambio de día y eliminar con confirmación |
| `presentation/widgets/meal_texts.dart` | `formatAmount` (a lo más un decimal), `mealValuesText` (`413 kcal · P 42.2 g · G 4.9 g`), `mealTimeText`, `dayLabel` y `MealSaveMessages` (409/404 de la foto en español) |
| `presentation/widgets/meal_navigation.dart` | `showMealSaved`: aviso *Comida registrada* y `go` al historial del día del registro |

## Flujo (HU-06)

1. Desde la pantalla principal del usuario, el botón flotante **Registrar comida** abre `/user/meals/photo`.
2. **Tomar foto** o **Elegir de la galería**. `image_picker` pide el permiso cuando hace falta y entrega la foto ya
   comprimida: lado mayor de 1600 px y JPEG con calidad 85 (PNG si la imagen tiene transparencia). Fotos HEIC o WebP
   de la galería salen como JPEG.
3. La app valida la foto con `MealPhotoValidator` (≤ 5 MiB, JPEG o PNG). Si no cumple, muestra el motivo y conserva la
   foto anterior; nunca se sube una foto mayor de 5 MiB.
4. Se ve la vista previa; tocar **Tomar foto** o **Elegir de la galería** otra vez la cambia. Cancelar el selector no
   borra la foto elegida.
5. **Usar esta foto** la sube y abre la estimación (HU-07) con `go`: después de subirla ya no se puede cambiar (evita
   fotos huérfanas en el backend) y atrás regresa al inicio.

### Si Android cierra la app con la cámara abierta

En teléfonos con poca memoria (visto en un moto g60 con el APK debug), Android mata el proceso de MacroFit mientras la
app de cámara está al frente; al volver, la app arranca de cero y la foto no llega a `pickImage`.

- `main.dart` llama primero a `MealPhotoRepository.recoverLostPhoto()` (`retrieveLostData` de `image_picker`, solo
  Android; en otras plataformas no hace nada) y después restaura la sesión.
- Si hay foto recuperada, la ruta del inicio (`/user`) redirige a `/user/meals/photo`, que es su subruta: el inicio
  queda debajo y **atrás** regresa a él.
- `MealPhotoViewModel.restoreRecoveredPhoto()` toma la foto (una sola vez), la valida y la muestra en la vista previa.

## Flujo (HU-07)

1. La pantalla "Estimación" recibe la foto subida (`MealPhotoUpload`) y al abrirse llama a
   `POST /meals/estimate` con su `photo_id`. Mientras responde muestra la foto y *Estimando calorías, proteína y grasa…*.
2. Con la respuesta muestra cada alimento identificado (nombre, gramos si vienen y sus valores) y los totales de
   calorías, proteína y grasa, con la leyenda *Estos valores son una estimación a partir de la foto y no una
   recomendación médica* (RNF-07, RN-09). Los valores se muestran con a lo más un decimal.
3. **Guardar** (HU-09) registra lo estimado tal cual (finales = `estimated` = totales) y abre el historial del día;
   **Corregir valores** abre el formulario de valores precargado con los totales (HU-08).

### Errores de la estimación

Ningún error cierra la pantalla ni la app (RNF-11).

| Caso | Mensaje | Opciones |
|---|---|---|
| `422 FOOD_NOT_RECOGNIZED` (CU-01 flujo 4a) | "No reconocimos comida en la foto. Captura los valores a mano." | **Capturar a mano** |
| `502 FOOD_PROVIDER_ERROR` (CU-01 flujo 3a) | "El servicio de estimación no está disponible en este momento. …" | **Reintentar** o **Capturar a mano** |
| `504 FOOD_PROVIDER_TIMEOUT` (máximo 10 s en el backend, RNF-01) | "La estimación tardó demasiado. …" | **Reintentar** o **Capturar a mano** |
| Sin conexión u otro error | El mensaje de `ApiException` | **Reintentar** o **Capturar a mano** |

**Reintentar** vuelve a estimar la misma foto (no se sube otra vez). Para probar cada caso contra un backend local, levántalo
con `FOOD_SIMULATOR_MODE=not_recognized`, `error` o `timeout` (ver `backend/README.md`).

## Flujo (HU-08)

El formulario `/user/meals/form` recibe un `MealDraft` (se abre con `push`: atrás regresa a la pantalla anterior):

| Desde | Formulario | Se envía a `POST /meals` |
|---|---|---|
| **Corregir valores** (estimación correcta) | "Revisar valores", precargado con los totales | `photo_id`, finales y `estimated` |
| **Capturar a mano** (tras `422`, `502`, `504` o sin red) | "Captura manual", vacío, con la foto | `photo_id` y finales, **sin** `estimated` |
| **Capturar sin foto** (en "Registrar comida") | "Captura manual", vacío, sin foto | Solo los finales |

1. Los tres campos son editables y se llaman como la API (`calories_kcal`, `protein_g`, `fat_g`). Aceptan decimales con
   punto o coma.
2. **Guardar** valida con `MealValuesValidator` (vacío, texto, negativos y rangos) y, si pasa, manda el registro.
3. **Sin corrección** los finales son exactamente los estimados (aunque el campo los muestre redondeados a un decimal);
   **con corrección**, `estimated` conserva lo estimado y los finales llevan lo capturado.
4. Al guardar abre el historial del día del registro con el aviso *Comida registrada* (HU-09).

### Errores del guardado

| Caso | Qué muestra |
|---|---|
| `400 VALIDATION_ERROR` | Cada error junto a su campo (`FormStateMixin.applyApiError`); los de `estimated.<campo>` van en el mismo campo como *Valor estimado: …* |
| `409 PHOTO_ALREADY_USED`, `404 PHOTO_NOT_FOUND` | Un mensaje en español de la app (`MealSaveMessages`) arriba del formulario; los valores capturados se conservan (HU-09) |
| Sin conexión u otro | El mensaje de la API arriba del formulario; los valores capturados se conservan |

Un registro guardado no se vuelve a enviar aunque se toque **Guardar** otra vez.

## Flujo (HU-09)

### Guardar en 4 toques (RNF-09)

Desde la pantalla principal hasta guardar un registro por foto, sin contar las pantallas del sistema (cámara o selector
de fotos) ni las ediciones:

| # | Toque | Pantalla |
|---|---|---|
| 1 | **Registrar comida** (botón flotante) | Inicio |
| 2 | **Tomar foto** o **Elegir de la galería** | Registrar comida |
| — | *(disparar o elegir la foto en la app del sistema)* | Cámara / galería |
| 3 | **Usar esta foto** (sube y estima) | Registrar comida |
| 4 | **Guardar** | Estimación |

Lo cubre la prueba *registro por foto en 4 toques desde el inicio hasta guardar (RNF-09)* de `test/app/app_test.dart`.

### Historial del día ("Mis comidas", `/user/meals`)

1. Se abre desde **Mis comidas** en el inicio (hoy) o al guardar un registro (el día del registro, `date` de la API).
2. `GET /meals?date=AAAA-MM-DD` trae los registros del día **del más antiguo al más reciente**. El día es el de la zona
   de la app (`APP_UTC_OFFSET` del backend, México): una cena a las 21:00 queda en su día aunque en UTC ya sea el siguiente.
3. Cada registro muestra la hora local, la foto (se descarga una sola vez con `GET /meals/photos/{id}`) o *Captura manual*,
   y sus valores finales. Arriba va el total del día.
4. **‹** / **›** cambian de día (no pasa de hoy) y la fecha abre el calendario. Un día sin registros dice *No hay registros
   este día* y ofrece **Elige otra fecha**. Deslizar hacia abajo recarga.
5. El botón flotante **Registrar comida** inicia otro registro.

### Eliminar

1. El ícono de basura pide confirmación (*¿Eliminar este registro?*, con hora y valores; avisa que también se borra la foto).
2. **Eliminar** usa `DELETE /meals/{id}`, quita el registro de la lista y avisa *Registro eliminado*.
3. `404 MEAL_NOT_FOUND` (ya se había eliminado, p. ej. en otro dispositivo): recarga el día y avisa *Ese registro ya no
   existía. Actualizamos la lista.*
4. Sin conexión u otro error: la lista se conserva y el error se muestra arriba.

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

- No probado en iOS (no hay dispositivo); ahí no aplica la recuperación de la foto perdida.
