## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación |
|---|---|---|---|
| HU-01 | Validación del formato de correo y de la longitud mínima de la contraseña. | Unitaria | Correos con formato inválido y contraseñas de menos de 8 caracteres son rechazados; los valores válidos son aceptados. |
| HU-01 | Selección obligatoria de rol. | Interfaz | No es posible enviar el registro sin elegir rol; se muestra un mensaje indicándolo. |
| HU-01 | Aceptación obligatoria del aviso de privacidad. | Interfaz | No es posible completar el registro sin aceptar el aviso; el enlace abre el aviso completo. |
| HU-01 | Creación de la cuenta en el backend con el rol elegido. | Integración | Tras el registro, la cuenta existe en el servicio de autenticación y su registro en la base de datos tiene el rol seleccionado. |
| HU-01 | Registro con un correo ya existente. | Integración | Se muestra un mensaje de error y no se crea una segunda cuenta. |
| HU-01 | Almacenamiento seguro de la contraseña. | Integración | La contraseña no aparece en texto plano en la base de datos. |
| HU-02 | Redirección según el rol de la cuenta. | Unitaria | La lógica de navegación devuelve la pantalla de usuario para el rol usuario y la de coach para el rol coach. |
| HU-02 | Inicio de sesión con credenciales válidas. | Integración | El usuario accede a la pantalla principal correspondiente a su rol. |
| HU-02 | Inicio de sesión con credenciales inválidas. | Interfaz | Se muestra un mensaje de error genérico y la app permanece en la pantalla de inicio de sesión. |
| HU-02 | Persistencia de la sesión. | Integración | Al cerrar y volver a abrir la app, la sesión sigue activa sin pedir credenciales. |
| HU-02 | Cierre de sesión. | Interfaz | La app regresa a la pantalla de inicio de sesión y el botón de retroceso no permite volver a pantallas protegidas. |
| HU-03 | Validación de campos obligatorios y rangos (peso, estatura, edad). | Unitaria | Campos vacíos o fuera de rango son rechazados con un mensaje; los valores válidos son aceptados. |
| HU-03 | Solicitud del perfil después del registro. | Interfaz | Un usuario nuevo es dirigido al formulario de perfil y no accede a la pantalla principal hasta completarlo. |
| HU-03 | Exclusión del rol coach. | Interfaz | Una cuenta con rol coach no es dirigida al formulario de perfil de usuario. |
| HU-03 | Guardado y lectura del perfil. | Integración | Los datos guardados se recuperan idénticos al cerrar y volver a abrir la app. |
| HU-03 | Edición del perfil. | Integración | Los cambios se guardan en el backend y se muestran al volver a abrir el perfil. |
| HU-04 | Cálculo de calorías diarias. | Unitaria | Para al menos 3 perfiles de referencia, el resultado coincide con el cálculo manual de la fórmula elegida. |
| HU-04 | Distribución de proteína y grasa según el objetivo. | Unitaria | Para cada objetivo (bajar grasa, mantener, ganar músculo), los gramos coinciden con las reglas definidas. |
| HU-04 | Recálculo al cambiar el perfil sin meta de coach. | Integración | Al editar el peso, la meta vigente se actualiza con los nuevos valores. |
| HU-04 | Conservación de la meta del coach al cambiar el perfil. | Integración | Si existe una meta definida por el coach, editar el perfil no la modifica. |
| HU-05 | Validación de los valores de la meta. | Unitaria | Valores no numéricos, negativos o fechas de vigencia inválidas son rechazados. |
| HU-05 | Guardado de la meta definida por el coach. | Integración | La meta se guarda con origen coach y fecha de vigencia, y pasa a ser la meta vigente del cliente. |
| HU-05 | Conservación del historial de metas. | Integración | La meta anterior permanece registrada después de guardar una nueva. |
| HU-05 | Restricción de acceso a clientes no vinculados. | Integración | Un coach no vinculado no puede leer ni modificar las metas del usuario; la operación es rechazada por las reglas del backend. |
| HU-05 | Flujo de ajuste de meta desde la app. | Interfaz | El coach llega desde su pantalla principal al formulario de meta de un cliente en 3 pantallas o menos. |
| HU-05 | Restricción de los endpoints de coach por rol. | Integración | Una cuenta de usuario recibe 403 `FORBIDDEN_ROLE` al consultar o modificar metas de un cliente. |
| HU-05 | Prioridad de la meta del coach y vigencia por fecha. | Integración | Una meta de coach es la vigente aunque exista una calculada del mismo día; una meta con fecha futura se guarda pero no es la vigente hasta que llega su fecha. |
| HU-05 | Cliente sin perfil con meta del coach. | Integración | El cliente que aún no captura su perfil recibe la meta del coach como vigente; al registrar y editar su perfil no se genera una meta calculada que la reemplace. |
| HU-05 | Disponibilidad del endpoint de datos de prueba. | Integración | `POST /dev/seed/coach-links` vincula a un coach con un usuario con `APP_ENV=development` y responde 404 en cualquier otro ambiente. |
| HU-05 | Lista de clientes vinculados del coach. | Integración | `GET /coach/clients` devuelve solo los clientes con vinculación activa del coach de la sesión. |
| HU-05 | Errores del backend en el formulario de meta. | Interfaz | Un error de validación se muestra junto a su campo, un `CLIENT_NOT_LINKED` como mensaje general, y el formulario vacío no se envía. |