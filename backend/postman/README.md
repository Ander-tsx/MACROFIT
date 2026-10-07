# `postman/` — pruebas de la API

Postman no puede armar una colección a partir de varios archivos. Por eso **cada módulo del backend tiene su propia
colección**, que es la que se edita, y `build.js` las une en un archivo combinado para importar y ejecutar todo junto.

```
postman/
├── build.js                            # Une los módulos → MacroFit.postman_collection.json
├── MacroFit.postman_collection.json    # GENERADO: no editar a mano
├── MacroFit.postman_environment.json   # Entorno "MacroFit - Local": solo baseUrl, sin credenciales
├── core/core.postman_collection.json   # src/routes/mod.rs  → health
└── auth/auth.postman_collection.json   # src/routes/auth.rs → HU-01, HU-02, roles y cierre de sesión
```

Regla: **una carpeta `postman/<modulo>/` por cada archivo de `src/routes/<modulo>.rs`**, con el mismo nombre.
Dentro del módulo, una carpeta de Postman por historia (`HU-XX <Nombre>` / `TEC-XX <Nombre>`).

## Ejecutar

1. Levanta el backend (`cargo run` en `backend/`).
2. En Postman: **Import** → `MacroFit.postman_collection.json` y `MacroFit.postman_environment.json` → selecciona el entorno **MacroFit - Local**.
3. Clic en la colección **MacroFit** → **Run** → **Run MacroFit**. Todo debe quedar en verde.

Cada colección de módulo también se puede importar y ejecutar sola (útil mientras trabajas en una historia).

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
| `auth` | `HU-01 Registro` | Usuario válido, Coach válido, Segundo coach válido, Correo duplicado, Correo duplicado con mayúsculas, Sin rol, Rol inválido, Sin aviso de privacidad*, Correo inválido, Contraseña corta, Nombre vacío |
| `auth` | `HU-02 Sesión` | Inicio de sesión de usuario, Inicio de sesión de coach, Contraseña incorrecta, Correo inexistente, /auth/me sin token, /auth/me con token inválido, /auth/me con token válido, Inicio de sesión auxiliar para renovación, Renovación, Token anterior tras la rotación, Reuso revoca la sesión, /auth/me con sesión revocada |
| `auth` | `Auth y roles (base)` | Ruta coach con coach, Ruta coach con usuario |
| `auth` | `HU-02 Sesión · Cierre` *(al final)* | Cierre de sesión, Renovación con token revocado, /auth/me tras cerrar sesión |

### Variables para las siguientes historias

| Variable | Origen | Uso |
|---|---|---|
| `user_id`, `user_email`, `coach_id`, `coach_email`, `coach2_id`, `coach2_email` | HU-01 | Cuentas de prueba |
| `user_access_token`, `user_refresh_token` | HU-02 · Inicio de sesión de usuario | `Authorization: Bearer {{user_access_token}}`. Válidos hasta la carpeta de cierre |
| `coach_access_token`, `coach_refresh_token` | HU-02 · Inicio de sesión de coach | Peticiones como coach. No se cierran |

El access token dura 15 minutos: si una ejecución completa tardara más, las historias siguientes deberán renovar con
`/auth/refresh` y actualizar las variables.

\* *Sin aviso de privacidad* espera `201` hasta que se implemente TEC-07; entonces debe esperar `400 PRIVACY_NOT_ACCEPTED`
(instrucciones en el comentario `TODO(TEC-07)` del propio test).

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
