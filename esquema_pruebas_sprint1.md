## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| HU-01 | Validación del formato de correo y de la longitud mínima de la contraseña. | Unitaria | Correos con formato inválido y contraseñas de menos de 8 caracteres son rechazados; los valores válidos son aceptados. | [**11**](#caso-01) (mobile 4 · backend 7) |
| HU-01 | Selección obligatoria de rol. | Interfaz | No es posible enviar el registro sin elegir rol; se muestra un mensaje indicándolo. | [**9**](#caso-02) (mobile 4 · backend 5) |
| HU-01 | Aceptación obligatoria del aviso de privacidad. | Interfaz | No es posible completar el registro sin aceptar el aviso; el enlace abre el aviso completo. | [**14**](#caso-03) (mobile 7 · backend 7) |
| HU-01 | Creación de la cuenta en el backend con el rol elegido. | Integración | Tras el registro, la cuenta existe en el servicio de autenticación y su registro en la base de datos tiene el rol seleccionado. | [**5**](#caso-04) (mobile 1 · backend 4) |
| HU-01 | Registro con un correo ya existente. | Integración | Se muestra un mensaje de error y no se crea una segunda cuenta. | [**4**](#caso-05) (mobile 1 · backend 3) |
| HU-01 | Almacenamiento seguro de la contraseña. | Integración | La contraseña no aparece en texto plano en la base de datos. | [**1**](#caso-06) (mobile 0 · backend 1) |
| HU-02 | Redirección según el rol de la cuenta. | Unitaria | La lógica de navegación devuelve la pantalla de usuario para el rol usuario y la de coach para el rol coach. | [**3**](#caso-07) (mobile 3 · backend 0) |
| HU-02 | Inicio de sesión con credenciales válidas. | Integración | El usuario accede a la pantalla principal correspondiente a su rol. | [**7**](#caso-08) (mobile 3 · backend 4) |
| HU-02 | Inicio de sesión con credenciales inválidas. | Interfaz | Se muestra un mensaje de error genérico y la app permanece en la pantalla de inicio de sesión. | [**5**](#caso-09) (mobile 3 · backend 2) |
| HU-02 | Persistencia de la sesión. | Integración | Al cerrar y volver a abrir la app, la sesión sigue activa sin pedir credenciales. | [**17**](#caso-10) (mobile 11 · backend 6) |
| HU-02 | Cierre de sesión. | Interfaz | La app regresa a la pantalla de inicio de sesión y el botón de retroceso no permite volver a pantallas protegidas. | [**9**](#caso-11) (mobile 6 · backend 3) |
| HU-03 | Validación de campos obligatorios y rangos (peso, estatura, edad). | Unitaria | Campos vacíos o fuera de rango son rechazados con un mensaje; los valores válidos son aceptados. | [**29**](#caso-12) (mobile 14 · backend 15) |
| HU-03 | Solicitud del perfil después del registro. | Interfaz | Un usuario nuevo es dirigido al formulario de perfil y no accede a la pantalla principal hasta completarlo. | [**13**](#caso-13) (mobile 10 · backend 3) |
| HU-03 | Exclusión del rol coach. | Interfaz | Una cuenta con rol coach no es dirigida al formulario de perfil de usuario. | [**4**](#caso-14) (mobile 2 · backend 2) |
| HU-03 | Guardado y lectura del perfil. | Integración | Los datos guardados se recuperan idénticos al cerrar y volver a abrir la app. | [**8**](#caso-15) (mobile 5 · backend 3) |
| HU-03 | Edición del perfil. | Integración | Los cambios se guardan en el backend y se muestran al volver a abrir el perfil. | [**10**](#caso-16) (mobile 4 · backend 6) |
| HU-04 | Cálculo de calorías diarias. | Unitaria | Para al menos 3 perfiles de referencia, el resultado coincide con el cálculo manual de la fórmula elegida. | [**13**](#caso-17) (mobile 5 · backend 8) |
| HU-04 | Distribución de proteína y grasa según el objetivo. | Unitaria | Para cada objetivo (bajar grasa, mantener, ganar músculo), los gramos coinciden con las reglas definidas. | [**7**](#caso-18) (mobile 3 · backend 4) |
| HU-04 | Recálculo al cambiar el perfil sin meta de coach. | Integración | Al editar el peso, la meta vigente se actualiza con los nuevos valores. | [**9**](#caso-19) (mobile 5 · backend 4) |
| HU-04 | Conservación de la meta del coach al cambiar el perfil. | Integración | Si existe una meta definida por el coach, editar el perfil no la modifica. | [**6**](#caso-20) (mobile 2 · backend 4) |
| HU-05 | Validación de los valores de la meta. | Unitaria | Valores no numéricos, negativos o fechas de vigencia inválidas son rechazados. | [**12**](#caso-21) (mobile 5 · backend 7) |
| HU-05 | Guardado de la meta definida por el coach. | Integración | La meta se guarda con origen coach y fecha de vigencia, y pasa a ser la meta vigente del cliente. | [**6**](#caso-22) (mobile 4 · backend 2) |
| HU-05 | Conservación del historial de metas. | Integración | La meta anterior permanece registrada después de guardar una nueva. | [**4**](#caso-23) (mobile 2 · backend 2) |
| HU-05 | Restricción de acceso a clientes no vinculados. | Integración | Un coach no vinculado no puede leer ni modificar las metas del usuario; la operación es rechazada por las reglas del backend. | [**3**](#caso-24) (mobile 1 · backend 2) |
| HU-05 | Flujo de ajuste de meta desde la app. | Interfaz | El coach llega desde su pantalla principal al formulario de meta de un cliente en 3 pantallas o menos. | [**2**](#caso-25) (mobile 2 · backend 0) |
| HU-05 | Restricción de los endpoints de coach por rol. | Integración | Una cuenta de usuario recibe 403 `FORBIDDEN_ROLE` al consultar o modificar metas de un cliente. | [**5**](#caso-26) (mobile 4 · backend 1) |
| HU-05 | Prioridad de la meta del coach y vigencia por fecha. | Integración | Una meta de coach es la vigente aunque exista una calculada del mismo día; una meta con fecha futura se guarda pero no es la vigente hasta que llega su fecha. | [**2**](#caso-27) (mobile 0 · backend 2) |
| HU-05 | Cliente sin perfil con meta del coach. | Integración | El cliente que aún no captura su perfil recibe la meta del coach como vigente; al registrar y editar su perfil no se genera una meta calculada que la reemplace. | [**5**](#caso-28) (mobile 0 · backend 5) |
| HU-05 | Disponibilidad del endpoint de datos de prueba. | Integración | `POST /dev/seed/coach-links` vincula a un coach con un usuario con `APP_ENV=development` y responde 404 en cualquier otro ambiente. | [**1**](#caso-29) (mobile 0 · backend 1) |
| HU-05 | Lista de clientes vinculados del coach. | Integración | `GET /coach/clients` devuelve solo los clientes con vinculación activa del coach de la sesión. | [**4**](#caso-30) (mobile 3 · backend 1) |
| HU-05 | Errores del backend en el formulario de meta. | Interfaz | Un error de validación se muestra junto a su campo, un `CLIENT_NOT_LINKED` como mensaje general, y el formulario vacío no se envía. | [**8**](#caso-31) (mobile 5 · backend 3) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. el cálculo de un perfil de referencia comprueba calorías y macros).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cierre del sprint 1: **119** pruebas mobile, **46** pruebas unitarias de Rust y **69** requests de Postman (sin contar los de preparación).

## Detalle de las pruebas por caso

### <a id="caso-01"></a>Caso 01 · HU-01 — Validación del formato de correo y de la longitud mínima de la contraseña

Mobile: 4 · Backend: 7

**Mobile**

- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › acepta correos válidos
- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › rechaza correos inválidos (mismos casos que el backend)
- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › vacío pide el correo
- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › menos de 8 caracteres es inválida y 8 es válida

**Backend (Rust)**

- `backend/src/validation.rs` › `acepta_correos_validos`
- `backend/src/validation.rs` › `rechaza_correos_invalidos`
- `backend/src/services/auth.rs` › `correo_invalido_senala_email`
- `backend/src/services/auth.rs` › `contrasena_corta_senala_password`
- `backend/src/services/auth.rs` › `contrasena_de_8_caracteres_es_valida`

**Backend (Postman)**

- Postman › HU-01 Registro › Correo inválido
- Postman › HU-01 Registro › Contraseña corta

### <a id="caso-02"></a>Caso 02 · HU-01 — Selección obligatoria de rol

Mobile: 4 · Backend: 5

**Mobile**

- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › rol y aviso de privacidad son obligatorios
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › formulario vacío: no envía y señala cada problema
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › sin rol o sin aviso no permiten enviar
- `macrofit_app/test/app/app_test.dart` › registro vacío no se envía y muestra qué falta

**Backend (Rust)**

- `backend/src/services/auth.rs` › `sin_rol_senala_role`
- `backend/src/services/auth.rs` › `rol_invalido_senala_role`
- `backend/src/services/auth.rs` › `cuerpo_vacio_senala_todos_los_campos`

**Backend (Postman)**

- Postman › HU-01 Registro › Sin rol
- Postman › HU-01 Registro › Rol inválido

### <a id="caso-03"></a>Caso 03 · HU-01 — Aceptación obligatoria del aviso de privacidad

Mobile: 7 · Backend: 7

**Mobile**

- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › rol y aviso de privacidad son obligatorios
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › formulario vacío: no envía y señala cada problema
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › sin rol o sin aviso no permiten enviar
- `macrofit_app/test/app/app_test.dart` › registro vacío no se envía y muestra qué falta
- `macrofit_app/test/app/app_test.dart` › el enlace del registro abre el aviso completo
- `macrofit_app/test/app/router_test.dart` › permite login, registro y aviso de privacidad
- `macrofit_app/test/app/router_test.dart` › el aviso de privacidad sigue disponible

**Backend (Rust)**

- `backend/src/services/auth.rs` › `sin_aviso_de_privacidad_responde_privacy_not_accepted`
- `backend/src/services/auth.rs` › `sin_aviso_y_con_campos_invalidos_lo_reporta_como_campo`
- `backend/src/services/legal.rs` › `el_aviso_embebido_declara_su_version`
- `backend/src/services/legal.rs` › `lee_la_version_de_la_cabecera`

**Backend (Postman)**

- Postman › HU-01 Registro › Sin aviso de privacidad
- Postman › HU-01 Registro › Sin aviso y con correo inválido
- Postman › TEC-07 Aviso de privacidad › Aviso de privacidad vigente

### <a id="caso-04"></a>Caso 04 · HU-01 — Creación de la cuenta en el backend con el rol elegido

Mobile: 1 · Backend: 4

**Mobile**

- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › registro válido crea la cuenta e inicia sesión automáticamente

**Backend (Rust)**

- `backend/src/services/auth.rs` › `registro_valido_normaliza_el_correo`

**Backend (Postman)**

- Postman › HU-01 Registro › Usuario válido
- Postman › HU-01 Registro › Coach válido
- Postman › HU-01 Registro › Segundo coach válido

### <a id="caso-05"></a>Caso 05 · HU-01 — Registro con un correo ya existente

Mobile: 1 · Backend: 3

**Mobile**

- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › correo ya registrado se muestra en el campo de correo

**Backend (Rust)**

- `backend/src/validation.rs` › `normaliza_mayusculas_y_espacios`

**Backend (Postman)**

- Postman › HU-01 Registro › Correo duplicado
- Postman › HU-01 Registro › Correo duplicado con mayúsculas

### <a id="caso-06"></a>Caso 06 · HU-01 — Almacenamiento seguro de la contraseña

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/auth/password.rs` › `el_hash_no_contiene_la_contrasena_y_se_verifica`

> La lectura directa de la base de datos (`password_hash` solo como `$argon2id$...` y sin campo `password`) se verificó manualmente con `mongosh` y quedó como captura en el PR de HU-01; no es una prueba automatizada.

### <a id="caso-07"></a>Caso 07 · HU-02 — Redirección según el rol de la cuenta

Mobile: 3 · Backend: 0

**Mobile**

- `macrofit_app/test/app/router_test.dart` › un usuario va a la pantalla principal de usuario
- `macrofit_app/test/app/router_test.dart` › un coach va a la pantalla principal de coach
- `macrofit_app/test/app/router_test.dart` › ningún rol accede a la pantalla del otro

> Solo aplica a la app: la navegación por rol no existe en el backend.

### <a id="caso-08"></a>Caso 08 · HU-02 — Inicio de sesión con credenciales válidas

Mobile: 3 · Backend: 4

**Mobile**

- `macrofit_app/test/app/app_test.dart` › el login de un coach lleva a la pantalla de coach
- `macrofit_app/test/features/auth/presentation/login_view_model_test.dart` › credenciales válidas inician sesión con el correo sin espacios
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › login guarda los tokens y queda autenticado con su rol

**Backend (Rust)**

- `backend/src/auth/jwt.rs` › `el_token_conserva_usuario_rol_y_sesion`

**Backend (Postman)**

- Postman › HU-02 Sesión › Inicio de sesión de usuario
- Postman › HU-02 Sesión › Inicio de sesión de coach
- Postman › HU-02 Sesión › /auth/me con token válido

### <a id="caso-09"></a>Caso 09 · HU-02 — Inicio de sesión con credenciales inválidas

Mobile: 3 · Backend: 2

**Mobile**

- `macrofit_app/test/features/auth/presentation/login_view_model_test.dart` › INVALID_CREDENTIALS se muestra como error general
- `macrofit_app/test/features/auth/presentation/login_view_model_test.dart` › sin datos no llama al backend y señala ambos campos
- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › en el login solo se exige que no esté vacía

**Backend (Postman)**

- Postman › HU-02 Sesión › Contraseña incorrecta
- Postman › HU-02 Sesión › Correo inexistente

### <a id="caso-10"></a>Caso 10 · HU-02 — Persistencia de la sesión

Mobile: 11 · Backend: 6

**Mobile**

- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › sin sesión guardada queda sin sesión
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › con sesión guardada entra de inmediato y actualiza el usuario con /auth/me
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › sin red conserva la sesión guardada
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › si el backend rechaza la sesión (401) se cierra
- `macrofit_app/test/features/auth/data/auth_interceptor_test.dart` › access token expirado: renueva una vez, guarda los tokens y reintenta
- `macrofit_app/test/features/auth/data/auth_interceptor_test.dart` › varias peticiones expiradas a la vez renuevan una sola vez
- `macrofit_app/test/features/auth/data/auth_interceptor_test.dart` › renovación rechazada: borra la sesión y avisa que expiró
- `macrofit_app/test/features/auth/data/auth_interceptor_test.dart` › sin red durante la renovación conserva la sesión
- `macrofit_app/test/app/app_test.dart` › mientras se lee la sesión muestra la carga inicial
- `macrofit_app/test/app/app_test.dart` › sin sesión abre el inicio de sesión
- `macrofit_app/test/app/router_test.dart` › mientras se lee la sesión se muestra la carga inicial

**Backend (Rust)**

- `backend/src/auth/refresh.rs` › `genera_tokens_distintos_y_guarda_solo_el_hash`

**Backend (Postman)**

- Postman › HU-02 Sesión › Inicio de sesión auxiliar para renovación
- Postman › HU-02 Sesión › Renovación
- Postman › HU-02 Sesión › Token anterior tras la rotación
- Postman › HU-02 Sesión › Reuso revoca la sesión
- Postman › HU-02 Sesión › /auth/me con sesión revocada

### <a id="caso-11"></a>Caso 11 · HU-02 — Cierre de sesión

Mobile: 6 · Backend: 3

**Mobile**

- `macrofit_app/test/app/app_test.dart` › cerrar sesión vuelve al login y atrás no regresa
- `macrofit_app/test/app/router_test.dart` › las pantallas protegidas mandan a login (atrás tras cerrar sesión)
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › revoca en el backend con el refresh token y borra lo local
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › borra la sesión local aunque el servidor no responda
- `macrofit_app/test/features/auth/data/auth_interceptor_test.dart` › TOKEN_REVOKED en una petición: borra la sesión sin intentar renovar
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › cerrar sesión desde el formulario

**Backend (Postman)**

- Postman › HU-02 Sesión · Cierre › Cierre de sesión
- Postman › HU-02 Sesión · Cierre › Renovación con token revocado
- Postman › HU-02 Sesión · Cierre › /auth/me tras cerrar sesión

### <a id="caso-12"></a>Caso 12 · HU-03 — Validación de campos obligatorios y rangos (peso, estatura, edad)

Mobile: 14 · Backend: 15

**Mobile**

- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › sin objetivo, nivel o sexo se rechazan
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › con una opción elegida se aceptan
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › días de entrenamiento de 1 a 7
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › vacío o no numérico se rechaza
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › fuera de rango se rechaza y los límites se aceptan
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › acepta coma decimal
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › estatura de 100 a 250 cm
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › obligatoria y no futura
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › 18 años cumplidos hoy es válido; un día antes no
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › 100 años es válido; 101 no
- `macrofit_app/test/features/profile/domain/profile_validators_test.dart` › calcula los años cumplidos
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › formulario vacío: no envía y señala cada campo
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › valores fuera de rango se señalan sin enviar
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › errores por campo del backend se muestran en su campo

**Backend (Rust)**

- `backend/src/services/profile.rs` › `perfil_valido_se_acepta_con_sus_valores`
- `backend/src/services/profile.rs` › `cuerpo_vacio_senala_todos_los_campos`
- `backend/src/services/profile.rs` › `valores_fuera_de_rango_se_senalan_todos`
- `backend/src/services/profile.rs` › `valores_no_permitidos_se_senalan_todos`
- `backend/src/services/profile.rs` › `enumerados_exigen_minusculas_exactas`
- `backend/src/services/profile.rs` › `limites_de_peso_estatura_y_dias_son_inclusivos`
- `backend/src/services/profile.rs` › `edad_de_18_y_100_anios_es_valida_y_fuera_no`
- `backend/src/services/profile.rs` › `fecha_con_formato_incorrecto_se_rechaza`
- `backend/src/services/profile.rs` › `textos_en_blanco_cuentan_como_faltantes`
- `backend/src/services/profile.rs` › `edicion_valida_los_campos_enviados`
- `backend/src/validation.rs` › `fecha_exige_formato_estricto`

**Backend (Postman)**

- Postman › HU-03 Perfil › Campos faltantes
- Postman › HU-03 Perfil › Valores fuera de rango
- Postman › HU-03 Perfil › Valores no permitidos
- Postman › HU-03 Perfil › Edición con valores inválidos

### <a id="caso-13"></a>Caso 13 · HU-03 — Solicitud del perfil después del registro

Mobile: 10 · Backend: 3

**Mobile**

- `macrofit_app/test/app/app_test.dart` › un usuario sin perfil va al formulario tras iniciar sesión
- `macrofit_app/test/app/app_test.dart` › sin completar el perfil no se puede llegar al inicio
- `macrofit_app/test/app/app_test.dart` › al guardar un perfil válido entra a la pantalla principal
- `macrofit_app/test/app/router_test.dart` › un usuario sin perfil solo puede abrir el formulario de perfil
- `macrofit_app/test/app/router_test.dart` › con perfil ya no ve el formulario y puede abrir Mi perfil
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › perfil válido: lo crea y marca el perfil completo
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › si el perfil ya existía (409) también continúa
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › sin red muestra un error general y no marca el perfil
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › marca la sesión y el usuario guardado con perfil
- `macrofit_app/test/features/auth/data/auth_repository_impl_test.dart` › sin sesión no hace nada

**Backend (Postman)**

- Postman › HU-03 Perfil › Consulta antes de crear
- Postman › HU-03 Perfil › Creación duplicada
- Postman › HU-03 Perfil › Verificación en /auth/me

### <a id="caso-14"></a>Caso 14 · HU-03 — Exclusión del rol coach

Mobile: 2 · Backend: 2

**Mobile**

- `macrofit_app/test/app/app_test.dart` › un coach entra a su pantalla sin ver el formulario
- `macrofit_app/test/app/router_test.dart` › un coach nunca ve el formulario ni la edición del perfil

**Backend (Postman)**

- Postman › HU-03 Perfil › Creación por coach
- Postman › HU-03 Perfil › Consulta por coach

### <a id="caso-15"></a>Caso 15 · HU-03 — Guardado y lectura del perfil

Mobile: 5 · Backend: 3

**Mobile**

- `macrofit_app/test/features/profile/data/profile_repository_impl_test.dart` › consulta el perfil y lo convierte a la entidad
- `macrofit_app/test/features/profile/data/profile_repository_impl_test.dart` › crea el perfil con los nombres y valores de la API
- `macrofit_app/test/features/profile/data/profile_repository_impl_test.dart` › sin perfil llega ApiException PROFILE_NOT_FOUND
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › carga el perfil guardado en el formulario
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › si no puede cargar, muestra el error para reintentar

**Backend (Rust)**

- `backend/src/validation.rs` › `fecha_va_y_vuelve_de_bson`

**Backend (Postman)**

- Postman › HU-03 Perfil › Creación válida
- Postman › HU-03 Perfil › Consulta

### <a id="caso-16"></a>Caso 16 · HU-03 — Edición del perfil

Mobile: 4 · Backend: 6

**Mobile**

- `macrofit_app/test/features/profile/data/profile_repository_impl_test.dart` › edita el perfil con PATCH
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › guarda los cambios con PATCH y no toca la sesión
- `macrofit_app/test/features/profile/presentation/profile_form_view_model_test.dart` › editar un campo limpia su error
- `macrofit_app/test/app/app_test.dart` › Mi perfil carga los datos guardados y guarda los cambios

**Backend (Rust)**

- `backend/src/services/profile.rs` › `edicion_acepta_un_solo_campo`
- `backend/src/services/profile.rs` › `edicion_sin_campos_es_cuerpo_invalido`
- `backend/src/services/profile.rs` › `set_de_edicion_incluye_solo_lo_enviado_y_updated_at`

**Backend (Postman)**

- Postman › HU-03 Perfil › Edición
- Postman › HU-03 Perfil › Edición sin campos
- Postman › HU-03 Perfil › Consulta tras la edición

### <a id="caso-17"></a>Caso 17 · HU-04 — Cálculo de calorías diarias

Mobile: 5 · Backend: 8

**Mobile**

- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › hombre bajar grasa coincide con el cálculo manual
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › mujer ganar músculo coincide con el cálculo manual
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › hombre mantener coincide con el cálculo manual
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › los resultados salen redondeados a enteros
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › el factor de actividad cambia en los límites de cada rango

**Backend (Rust)**

- `backend/src/services/goals.rs` › `hombre_bajar_grasa_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `mujer_ganar_musculo_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `hombre_mantener_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `factor_de_actividad_respeta_los_limites_de_cada_rango`
- `backend/src/services/goals.rs` › `edad_se_cumple_el_dia_del_cumpleanos`
- `backend/src/services/goals.rs` › `fecha_civil_del_epoch_y_de_anio_bisiesto`

**Backend (Postman)**

- Postman › HU-04 Meta calculada › 02 - Meta inicial (registrar perfil)
- Postman › HU-04 Meta calculada › 02 - Meta inicial (consultar meta)

### <a id="caso-18"></a>Caso 18 · HU-04 — Distribución de proteína y grasa según el objetivo

Mobile: 3 · Backend: 4

**Mobile**

- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › hombre bajar grasa coincide con el cálculo manual
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › mujer ganar músculo coincide con el cálculo manual
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › hombre mantener coincide con el cálculo manual

**Backend (Rust)**

- `backend/src/services/goals.rs` › `hombre_bajar_grasa_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `mujer_ganar_musculo_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `hombre_mantener_coincide_con_calculo_manual`

**Backend (Postman)**

- Postman › HU-04 Meta calculada › 02 - Meta inicial (consultar meta)

### <a id="caso-19"></a>Caso 19 · HU-04 — Recálculo al cambiar el perfil sin meta de coach

Mobile: 5 · Backend: 4

**Mobile**

- `macrofit_app/test/features/goals/domain/update_goal_on_profile_change_test.dart` › si la meta vigente es del sistema genera una meta nueva
- `macrofit_app/test/features/goals/domain/update_goal_on_profile_change_test.dart` › la meta nueva usa los datos del perfil editado
- `macrofit_app/test/features/goals/domain/update_goal_on_profile_change_test.dart` › sin meta previa genera la meta inicial del sistema
- `macrofit_app/test/features/goals/domain/update_goal_on_profile_change_test.dart` › la meta previa se conserva en el historial al agregar la nueva
- `macrofit_app/test/features/goals/domain/calculate_nutritional_goal_test.dart` › la meta calculada es del sistema, del usuario y vigente desde ahora

**Backend (Rust)**

- `backend/src/services/goals.rs` › `meta_de_coach_no_se_recalcula`

**Backend (Postman)**

- Postman › HU-04 Meta calculada › 03 - Edición del perfil
- Postman › HU-04 Meta calculada › 04 - Meta recalculada
- Postman › HU-04 Meta calculada › 05 - Historial

### <a id="caso-20"></a>Caso 20 · HU-04 — Conservación de la meta del coach al cambiar el perfil

Mobile: 2 · Backend: 4

**Mobile**

- `macrofit_app/test/features/goals/domain/update_goal_on_profile_change_test.dart` › si la meta vigente es de un coach no se reemplaza
- `macrofit_app/test/features/goals/domain/update_goal_on_profile_change_test.dart` › con una meta de coach el historial no cambia

**Backend (Rust)**

- `backend/src/services/goals.rs` › `meta_de_coach_no_se_recalcula`

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 14 - El cliente edita su perfil
- Postman › HU-05 Metas por coach › 15 - Meta vigente tras editar el perfil
- Postman › HU-05 Metas por coach › 16 - Historial del cliente sin metas calculadas

### <a id="caso-21"></a>Caso 21 · HU-05 — Validación de los valores de la meta

Mobile: 5 · Backend: 7

**Mobile**

- `macrofit_app/test/features/goals/domain/coach_goal_validators_test.dart` › acepta enteros dentro del rango
- `macrofit_app/test/features/goals/domain/coach_goal_validators_test.dart` › rechaza vacío, texto, decimales, cero, negativos y excesos
- `macrofit_app/test/features/goals/domain/coach_goal_validators_test.dart` › proteína y grasa comparten el rango de macros
- `macrofit_app/test/features/goals/domain/coach_goal_validators_test.dart` › parse convierte texto a entero
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › campos vacíos o inválidos no se envían y se señalan

**Backend (Rust)**

- `backend/src/services/goals.rs` › `meta_de_coach_valida_se_acepta`
- `backend/src/services/goals.rs` › `cuerpo_vacio_senala_los_cuatro_campos`
- `backend/src/services/goals.rs` › `valores_no_numericos_negativos_o_en_cero_se_senalan`
- `backend/src/services/goals.rs` › `decimales_y_valores_sobre_el_maximo_se_senalan`
- `backend/src/services/goals.rs` › `fecha_de_vigencia_invalida_se_senala`

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 04 - Valores inválidos
- Postman › HU-05 Metas por coach › 05 - Fecha inválida

### <a id="caso-22"></a>Caso 22 · HU-05 — Guardado de la meta definida por el coach

Mobile: 4 · Backend: 2

**Mobile**

- `macrofit_app/test/features/goals/data/coach_goals_repository_impl_test.dart` › fija una meta enviando la fecha como AAAA-MM-DD
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › la fecha de vigencia empieza en hoy
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › meta válida: se guarda con la fecha elegida y recarga el historial
- `macrofit_app/test/app/app_test.dart` › guarda la meta y la muestra en el historial

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 07 - Primera meta
- Postman › HU-05 Metas por coach › 08 - Meta vigente del cliente

### <a id="caso-23"></a>Caso 23 · HU-05 — Conservación del historial de metas

Mobile: 2 · Backend: 2

**Mobile**

- `macrofit_app/test/features/goals/data/coach_goals_repository_impl_test.dart` › consulta el historial de metas de un cliente
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › load trae el historial del cliente

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 09 - Segunda meta
- Postman › HU-05 Metas por coach › 10 - Historial del cliente (coach)

### <a id="caso-24"></a>Caso 24 · HU-05 — Restricción de acceso a clientes no vinculados

Mobile: 1 · Backend: 2

**Mobile**

- `macrofit_app/test/features/goals/data/coach_goals_repository_impl_test.dart` › un coach no vinculado recibe CLIENT_NOT_LINKED

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 03 - Consulta por un coach no vinculado
- Postman › HU-05 Metas por coach › 03 - Modificación por un coach no vinculado

### <a id="caso-25"></a>Caso 25 · HU-05 — Flujo de ajuste de meta desde la app

Mobile: 2 · Backend: 0

**Mobile**

- `macrofit_app/test/app/app_test.dart` › el coach llega al formulario de un cliente en dos pantallas
- `macrofit_app/test/app/router_test.dart` › un coach abre sus pantallas de clientes y metas

> Solo aplica a la app (flujo de pantallas).

### <a id="caso-26"></a>Caso 26 · HU-05 — Restricción de los endpoints de coach por rol

Mobile: 4 · Backend: 1

**Mobile**

- `macrofit_app/test/app/app_test.dart` › un usuario no ve el acceso a clientes
- `macrofit_app/test/app/router_test.dart` › un usuario no accede a las pantallas del coach
- `macrofit_app/test/app/router_test.dart` › sin sesión las pantallas del coach mandan a login
- `macrofit_app/test/app/router_test.dart` › una ruta parecida a la del coach no cuenta como suya

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 02 - Intento con cuenta de usuario

> Postman cubre la **modificación** (`POST`); la **consulta** (`GET`) con cuenta de usuario no tiene un request propio.

### <a id="caso-27"></a>Caso 27 · HU-05 — Prioridad de la meta del coach y vigencia por fecha

Mobile: 0 · Backend: 2

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 11 - Meta con vigencia futura
- Postman › HU-05 Metas por coach › 12 - La meta vigente ignora la futura

> Cubre la vigencia por fecha. El caso "meta de coach frente a una calculada del mismo día" no tiene una prueba específica (los casos 20 y 28 cubren que una meta de coach no se reemplaza al editar el perfil).

### <a id="caso-28"></a>Caso 28 · HU-05 — Cliente sin perfil con meta del coach

Mobile: 0 · Backend: 5

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 08 - Meta vigente del cliente
- Postman › HU-05 Metas por coach › 13 - El cliente registra su perfil
- Postman › HU-05 Metas por coach › 14 - El cliente edita su perfil
- Postman › HU-05 Metas por coach › 15 - Meta vigente tras editar el perfil
- Postman › HU-05 Metas por coach › 16 - Historial del cliente sin metas calculadas

### <a id="caso-29"></a>Caso 29 · HU-05 — Disponibilidad del endpoint de datos de prueba

Mobile: 0 · Backend: 1

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 01 - Vinculación de prueba

> Cubre la vinculación con `APP_ENV=development`. La respuesta `404` en otros ambientes no tiene una prueba automatizada (la colección se ejecuta siempre en modo desarrollo).

### <a id="caso-30"></a>Caso 30 · HU-05 — Lista de clientes vinculados del coach

Mobile: 3 · Backend: 1

**Mobile**

- `macrofit_app/test/features/goals/data/coach_goals_repository_impl_test.dart` › lista los clientes vinculados
- `macrofit_app/test/features/goals/presentation/coach_clients_view_model_test.dart` › load trae los clientes vinculados
- `macrofit_app/test/features/goals/presentation/coach_clients_view_model_test.dart` › load muestra el error y permite reintentar

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 06 - Lista de clientes del coach

> El request verifica que el cliente vinculado aparece; no hay un caso con un cliente desvinculado que confirme que se excluye.

### <a id="caso-31"></a>Caso 31 · HU-05 — Errores del backend en el formulario de meta

Mobile: 5 · Backend: 3

**Mobile**

- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › errores por campo del backend se muestran en su campo
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › un cliente desvinculado se muestra como error general
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › load muestra el error si falla
- `macrofit_app/test/features/goals/presentation/coach_goal_form_view_model_test.dart` › editar un campo limpia su error
- `macrofit_app/test/app/app_test.dart` › un formulario vacío no se envía y señala los campos

**Backend (Postman)**

- Postman › HU-05 Metas por coach › 04 - Valores inválidos
- Postman › HU-05 Metas por coach › 05 - Fecha inválida
- Postman › HU-05 Metas por coach › 03 - Modificación por un coach no vinculado

## Otras pruebas no asociadas a un caso del esquema

Verifican reglas que no tienen un caso propio en esta tabla: nombre obligatorio y confirmación de contraseña (criterios de la historia HU-01), rechazo de tokens ausentes o alterados (HU-02), errores de red en el registro, la regla base de acceso por rol y la salud del servicio (TEC-05), y respuestas de HU-04 sin perfil o con el rol equivocado.

**Mobile**

- `macrofit_app/test/features/auth/data/auth_interceptor_test.dart` › agrega el Bearer guardado a cada petición
- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › las contraseñas deben coincidir
- `macrofit_app/test/features/auth/domain/auth_validators_test.dart` › nombre vacío o en blanco es inválido
- `macrofit_app/test/features/auth/presentation/login_view_model_test.dart` › editar un campo limpia su error y el error general
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › contraseñas distintas no permiten enviar
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › error sin campos (sin red) se muestra como error general
- `macrofit_app/test/features/auth/presentation/register_view_model_test.dart` › si el login automático falla, avisa que la cuenta sí se creó

**Backend (Rust)**

- `backend/src/auth/jwt.rs` › `rechaza_token_firmado_con_otro_secreto_o_alterado`
- `backend/src/services/auth.rs` › `nombre_vacio_o_en_blanco_senala_name`

**Backend (Postman)**

- Postman › Servicio › Health check
- Postman › HU-01 Registro › Nombre vacío
- Postman › HU-02 Sesión › /auth/me sin token
- Postman › HU-02 Sesión › /auth/me con token inválido
- Postman › Auth y roles (base) › Ruta coach con coach
- Postman › Auth y roles (base) › Ruta coach con usuario
- Postman › HU-04 Meta calculada › 01 - Consulta sin perfil
- Postman › HU-04 Meta calculada › 06 - Consulta por un coach
