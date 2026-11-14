# `postman/` — pruebas de la API

Postman no puede armar una colección a partir de varios archivos. Por eso **cada módulo del backend tiene su propia
colección**, que es la que se edita, y `build.js` las une en un archivo combinado para importar y ejecutar todo junto.

```
postman/
├── build.js                            # Une los módulos → MacroFit.postman_collection.json
├── MacroFit.postman_collection.json    # GENERADO: no editar a mano
├── MacroFit.postman_environment.json   # Entorno "MacroFit - Local": solo baseUrl, sin credenciales
├── MacroFit.deployed.postman_environment.json # Entorno "MacroFit - Desplegado": solo baseUrl del ambiente en Railway
├── core/core.postman_collection.json   # src/routes/mod.rs  → health
├── openapi/openapi.postman_collection.json # src/routes/openapi.rs → TEC-14 contrato OpenAPI
├── legal/legal.postman_collection.json # src/routes/legal.rs → TEC-07 aviso de privacidad
├── auth/auth.postman_collection.json   # src/routes/auth.rs → HU-01, HU-02, roles y cierre de sesión
├── profile/profile.postman_collection.json # src/routes/profile.rs → HU-03 perfil inicial
├── goals/goals.postman_collection.json # src/routes/goals.rs → HU-04 y HU-05 metas
├── weights/weights.postman_collection.json # src/routes/weights.rs → HU-21 registro de peso
├── routines/routines.postman_collection.json # src/routes/routines.rs → HU-18 rutinas del coach
├── summary/summary.postman_collection.json # src/routes/summary.rs → HU-10 resumen diario y HU-11 resumen semanal (cuentas y registros propios)
└── meals/meals.postman_collection.json # src/routes/meals.rs → HU-06 carga de foto, HU-07 estimación, HU-09 registros de comida, HU-08 valores corregidos, HU-25 comidas de un cliente (archivos de prueba en meals/files/)
```

Regla: **una carpeta `postman/<modulo>/` por cada archivo de `src/routes/<modulo>.rs`**, con el mismo nombre.
Dentro del módulo, una carpeta de Postman por historia (`HU-XX <Nombre>` / `TEC-XX <Nombre>`).

## Ejecutar

1. Levanta el backend (`cargo run` en `backend/`).
2. En Postman: **Import** → `MacroFit.postman_collection.json` y `MacroFit.postman_environment.json` → selecciona el entorno **MacroFit - Local**.
3. **Archivos de prueba (HU-06):** en Postman, *Settings → General → Working directory* debe apuntar a la carpeta
   `backend/` del repositorio; las peticiones de subida leen `postman/meals/files/...` relativo a ella. Newman se
   ejecuta desde `backend/`, así que no necesita nada más.
4. Clic en la colección **MacroFit** → **Run** → **Run MacroFit**. Todo debe quedar en verde.

Cada colección de módulo también se puede importar y ejecutar sola (útil mientras trabajas en una historia).

**Contra el ambiente desplegado:** usa el entorno **MacroFit - Desplegado** (`MacroFit.deployed.postman_environment.json`)
en lugar del local. Allí `APP_ENV=production`, así que las carpetas que siembran datos con `/dev/seed/*`
(HU-05 *Metas por coach* y TEC-09 *Catálogo de ejercicios*) fallan con 404: es lo esperado. Además, con
`FOOD_PROVIDER=gemini`, *HU-07 · Estimación válida* manda la foto de prueba (`comida.jpg`, una imagen mínima sin comida)
al servicio real y puede responder `422 FOOD_NOT_RECOGNIZED`: esa carpeta se valida contra el simulador. Ver
[Despliegue](../README.md#-despliegue).

Desde terminal, en `backend/` (sin instalar nada):

```bash
npx newman run postman/MacroFit.postman_collection.json -e postman/MacroFit.postman_environment.json
```

## Modificar pruebas

1. Edita **solo** `postman/<modulo>/<modulo>.postman_collection.json`. Puedes hacerlo a mano o en Postman: importas
   la colección del módulo, la editas ahí y la **exportas en v2.1 sobre el mismo archivo**.
2. Regenera el combinado y súbelo junto con el cambio:

   ```bash
   node postman/build.js
   ```

3. Antes del PR, `node postman/build.js --check` debe responder que el combinado está al día.

### Agregar un módulo nuevo

1. Crea `postman/<modulo>/<modulo>.postman_collection.json` en formato v2.1, con `info.name` = `MacroFit · <Modulo>`.
2. Agrega `<modulo>` a `MODULES` en `build.js`. El orden es el orden de ejecución: un módulo que use datos de otro
   (por ejemplo cuentas creadas en `auth`) va después. `build.js` falla si hay una carpeta de módulo sin listar.
3. Ejecuta `node postman/build.js`.

### Carpetas de cierre

Las carpetas cuyo nombre termina en `· Cierre` (por ejemplo `HU-02 Sesión · Cierre`) son de *teardown*: invalidan datos
que usan las demás historias (el cierre de sesión revoca `{{user_access_token}}`). `build.js` las mueve **al final de la
colección combinada**, después de todos los módulos. Dentro de su módulo deben ser las últimas carpetas.

`build.js` también falla si dos módulos tienen una carpeta con el mismo nombre, si una variable de colección se
repite con valores distintos, o si un módulo tiene scripts o auth a nivel de colección (esos se perderían al unir:
ponlos en la carpeta o en el request).

## Carpetas actuales

| Módulo | Carpeta | Requests |
|---|---|---|
| `core` | `Servicio` | Health check |
| `openapi` | `TEC-14 Contrato OpenAPI` | Especificación OpenAPI, Rutas /dev según el ambiente, Documentación (Swagger UI) |
| `legal` | `TEC-07 Aviso de privacidad` | Aviso de privacidad vigente |
| `auth` | `HU-01 Registro` | Usuario válido, Coach válido, Segundo coach válido, Correo duplicado, Correo duplicado con mayúsculas, Sin rol, Rol inválido, Sin aviso de privacidad, Sin aviso y con correo inválido, Correo inválido, Contraseña corta, Nombre vacío |
| `auth` | `HU-02 Sesión` | Inicio de sesión de usuario, Inicio de sesión de coach, Contraseña incorrecta, Correo inexistente, /auth/me sin token, /auth/me con token inválido, /auth/me con token válido, Inicio de sesión auxiliar para renovación, Renovación, Token anterior tras la rotación, Reuso revoca la sesión, /auth/me con sesión revocada |
| `auth` | `Auth y roles (base)` | Ruta coach con coach, Ruta coach con usuario |
| `profile` | `HU-03 Perfil` | Consulta antes de crear, Creación por coach, Consulta por coach, Campos faltantes, Valores fuera de rango, Valores no permitidos, Creación válida, Creación duplicada, Consulta, Verificación en /auth/me, Edición, Edición con valores inválidos, Edición sin campos, Consulta tras la edición |
| `goals` | `HU-24 Lista de clientes` | Sin sesión, Cuenta de usuario, Coach con clientes, Cliente sin registros (fecha null), Cliente con registro (fecha del último), Cliente con meta del coach. Crea su coach y sus clientes con el código de invitación (HU-12/HU-13), desvincula a uno (HU-14) y guarda comidas con `POST /meals` (HU-09); no necesita `APP_ENV=development` |
| `routines` | `HU-18 Rutinas del coach` | Crear rutina, Listar rutinas, Consultar rutina, Editar rutina, Consultar tras editar, Rutina sin ejercicios, Rutina sin nombre ni ejercicios, Series en 0, Repeticiones en 0 y descanso negativo, Ejercicio inexistente, Editar con datos inválidos, Rutina de otro coach (consultar / editar / eliminar), El otro coach no ve la rutina en su lista, Rutina inexistente, Id mal formado, Cuenta de usuario (crear / listar), Sin sesión, Eliminar rutina, Consultar tras eliminar, Eliminar de nuevo. Registra su coach, un segundo coach y un usuario; toma dos ejercicios de `GET /exercises` (va después de `exercises`) |
| `meals` | `HU-06 Carga de foto` | Foto JPEG válida, Foto PNG válida, Tipo no permitido (GIF), Texto con extensión .jpg, Archivo demasiado grande, Sin archivo, Sin sesión, Cuenta de coach |
| `meals` | `HU-07 Estimación nutricional` | Estimación válida, Sin photo_id, Foto inexistente, Id de foto mal formado, Foto de otro usuario, Sin sesión, Cuenta de coach. Contra el **simulador** (`FOOD_PROVIDER=simulator`) |
| `meals` | `HU-09 Registros de comida` | Crear registro con foto, Captura manual sin foto, Crear registro que se eliminará, Foto ya usada en otro registro, Foto de otro usuario, Valores inválidos, Consultar por fecha, Día sin registros, Fecha inválida, Sin fecha, Eliminar un registro ajeno, Eliminar un registro inexistente, Eliminar, Consultar tras eliminar, La foto del registro eliminado ya no existe, Eliminar de nuevo, Sin sesión, Cuenta de coach (guardar / consultar / eliminar) |
| `meals` | `HU-08 Valores corregidos` | Guardar sin corrección (finales = estimados), Guardar con corrección, Captura manual sin estimación (`estimated: null`), Valor 0 en estimados y finales, Valor negativo, Valor no numérico, `estimated` que no es objeto, Estimados sin foto, Consultar por fecha (compara lo guardado con lo enviado). Sube sus propias fotos con el usuario de `meals` |
| `meals` | `HU-25 Comidas de un cliente` | Cliente vinculado con registros, El coach ve la foto del registro, Día sin registros, Otra fecha, Coach no vinculado (coach2), Coach no vinculado no ve la foto, Cliente inexistente, Id de cliente mal formado, Fecha inválida, Sin fecha, Cuenta de usuario, Sin sesión, Solo lectura (el coach no crea ni elimina registros), El cliente sigue teniendo sus registros, El dueño ve su propia foto, Cliente desvinculado (registros y foto). Vincula al usuario de `meals` con el coach de `meals` (HU-13) y al final lo desvincula (HU-14) |
| `auth` | `HU-02 Sesión · Cierre` *(al final)* | Cierre de sesión, Renovación con token revocado, /auth/me tras cerrar sesión |

### Variables para las siguientes historias

| Variable | Origen | Uso |
|---|---|---|
| `user_id`, `user_email`, `coach_id`, `coach_email`, `coach2_id`, `coach2_email` | HU-01 | Cuentas de prueba |
| `user_access_token`, `user_refresh_token` | HU-02 · Inicio de sesión de usuario | `Authorization: Bearer {{user_access_token}}`. Válidos hasta la carpeta de cierre |
| `coach_access_token`, `coach_refresh_token` | HU-02 · Inicio de sesión de coach | Peticiones como coach. No se cierran |
| `openapi_has_dev` | TEC-14 · Especificación OpenAPI | `true` si la especificación documenta rutas `/dev`; la usa *Rutas /dev según el ambiente* |
| `profile_id`, `profile_sent`, `profile_expected` | HU-03 · Creación válida / Edición | Id del perfil y valores enviados/editados (JSON) para comparar en las consultas. El usuario de HU-01 queda **con perfil** |

| `meal_photo_id` | HU-06 · Foto JPEG válida | Id de una foto del usuario de `meals` (`meals_user_token`), para HU-07 y HU-09 |
| `meals_other_token`, `meals_other_photo_id` | HU-07 · Preparación | Segundo usuario y su foto, para probar que no se puede estimar la foto de otro |
| `meal_id`, `meal_date`, `meal_manual_id` | HU-09 · 01 y 02 | Registros del usuario de `meals` (`meals_user_token`) que **quedan guardados**: `meal_id` con la foto `meal_photo_id` y `meal_manual_id` sin foto, ambos del día `meal_date` (hora de México). Para HU-10, HU-24 y HU-25 |
| `meals_other_meal_id` | HU-09 · Preparación | Registro del otro usuario: el de `meals` no lo ve ni lo elimina |
| `hu25_invite_code`, `hu25_coach2_email`, `hu25_coach2_token`, `hu25_other_date` | HU-25 · Preparación y 01 | Código del coach de `meals`, coach sin vinculación y día anterior a `meal_date`. Al terminar HU-25 el usuario de `meals` queda **desvinculado** |

El access token dura 15 minutos: si una ejecución completa tardara más, las historias siguientes deberán renovar con
`/auth/refresh` y actualizar las variables.


## Convenciones de los tests

- **Nombres de request** en español describiendo el caso (`Correo duplicado`, `Rol inválido`).
- **Cada request tiene tests** de:
  - código de estado;
  - estructura de la respuesta (`to.have.all.keys(...)`); en errores, `{ error: { code, message, fields } }`,
    el `code` esperado y, si aplica, el campo señalado en `fields`.
- **Envuelve cada script en un bloque `{ ... }`**: newman comparte el ámbito entre scripts y dos `const` con el mismo
  nombre en requests distintos rompen la ejecución.
- **Datos únicos por ejecución**: los correos se generan en el *pre-request* con `Date.now()` y un aleatorio, dominio
  `@macrofit.test`. Nunca correos fijos que choquen en la segunda ejecución.
- **Variables**:
  - Entorno: solo configuración (`baseUrl`). Nada de tokens, contraseñas reales ni cadenas de conexión.
  - Colección del módulo: valores generados en la ejecución (`user_id`, `user_token`, `coach_email`...) y `test_password`,
    que es ficticia. Al unir, las variables de todos los módulos quedan en la colección combinada.
  - Locales (`pm.variables`) para valores de un solo request.
- Los requests que crean recursos guardan su `id` en una variable de colección para los siguientes.
- Evidencia del PR: captura del **Collection Runner** de la colección combinada con todo en verde.
