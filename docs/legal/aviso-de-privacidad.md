# Aviso de privacidad integral de MacroFit

**Última actualización:** 7 de octubre de 2026
**Versión:** 1.0

Este aviso explica qué datos personales recaba la aplicación móvil MacroFit, para qué los usa, con quién los comparte y cómo puedes ejercer tus derechos sobre ellos. Se emite conforme a la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP) y demás normativa aplicable en México.

## 1. Responsable

**Equipo MacroFit**, responsable del tratamiento de tus datos personales.

Contacto para cualquier asunto relacionado con tus datos: **20233tn107@utez.edu.mx**

MacroFit es un proyecto académico desarrollado en la Universidad Tecnológica Emiliano Zapata del Estado de Morelos (UTEZ).

## 2. Datos personales que tratamos

### 2.1 Datos de identificación y de cuenta

- Nombre.
- Correo electrónico.
- Contraseña, que se guarda únicamente como hash irreversible; nadie del equipo puede conocerla.
- Rol en la aplicación (usuario o coach).
- Fecha y hora en que aceptaste este aviso.
- Datos técnicos de sesión: tokens de acceso y de renovación, con su fecha de expiración y revocación.

### 2.2 Datos sensibles: salud, alimentación y actividad física

Si usas MacroFit con el rol de **usuario**, tratamos datos que la ley considera **sensibles** porque se relacionan con tu estado de salud:

- Peso, estatura, sexo y fecha de nacimiento.
- Objetivo físico (bajar grasa, mantener o ganar músculo), nivel de entrenamiento y días de entrenamiento por semana.
- Metas nutricionales (calorías, proteína y grasa), tanto las calculadas por el sistema como las que defina tu coach.
- Registros de comidas con sus valores estimados o corregidos de calorías, proteína y grasa.
- Historial de peso.
- Rutinas recomendadas o asignadas y las sesiones que marcas como completadas.

### 2.3 Fotografías

- Fotografías de comida que tomas con la cámara o seleccionas de la galería para registrar lo que comes.

Te pedimos que las fotos muestren **solo la comida**. Evita que aparezcan rostros, otras personas, documentos o cualquier otro elemento que permita identificarte a ti o a terceros.

### 2.4 Datos de vinculación con un coach

- El coach con el que te vinculas, la fecha de vinculación y su estado (activa o terminada).
- Si eres coach: tu código de invitación y la lista de clientes vinculados contigo.

### 2.5 Datos que no recabamos

MacroFit **no** recaba tu ubicación, tus contactos, datos financieros ni datos biométricos con fines de identificación.

## 3. Finalidades del tratamiento

### 3.1 Finalidades primarias (necesarias para el servicio)

1. Crear y administrar tu cuenta, y permitirte iniciar y cerrar sesión de forma segura.
2. Darte acceso a las funciones que corresponden a tu rol.
3. Calcular tu meta nutricional diaria a partir de tu perfil.
4. Estimar las calorías, proteína y grasa de tus comidas a partir de las fotografías que registras.
5. Guardar tu historial de comidas, peso y entrenamiento, y mostrarte resúmenes y gráficas de tu progreso.
6. Generar rutinas recomendadas según tu objetivo, nivel y disponibilidad.
7. Si te vinculas con un coach: permitirle consultar tu información y ajustar tus metas y rutinas.
8. Mantener la seguridad de la aplicación: prevenir accesos no autorizados y atender incidentes.

### 3.2 Finalidades secundarias

Con tus datos **disociados** (sin que puedan asociarse a ti), el equipo puede elaborar estadísticas generales de uso para evaluar y mejorar el proyecto académico.

Si no quieres que tus datos se usen para esta finalidad, escríbenos al correo de contacto. Tu negativa no afecta tu acceso a la aplicación.

MacroFit **no** usa tus datos para publicidad, mercadotecnia ni para venderlos a terceros.

## 4. Consentimiento

Al crear tu cuenta, la aplicación te pide aceptar este aviso de manera **expresa** marcando la casilla correspondiente. Sin esa aceptación no es posible completar el registro.

Como tratamos datos sensibles, esa aceptación constituye tu **consentimiento expreso** para tratarlos con las finalidades descritas. Guardamos la fecha y hora en que lo otorgaste.

MacroFit está dirigido a **personas mayores de 18 años**. No recabamos intencionalmente datos de menores de edad.

## 5. Con quién compartimos tus datos

### 5.1 Tu coach

Solo si **tú decides vincularte** con un coach mediante su código de invitación, ese coach podrá consultar tu perfil, metas, registros de comida, rutinas y progreso, y podrá ajustar tus metas y rutinas.

El coach es otro usuario de la aplicación. Al vincularte, consientes esta transferencia. Puedes desvincularte en cualquier momento desde la aplicación; a partir de entonces el coach deja de tener acceso a tu información.

### 5.2 Proveedores que nos prestan servicios (encargados)

Para operar la aplicación usamos proveedores que tratan datos **únicamente por nuestra cuenta**, siguiendo nuestras instrucciones y sin poder usarlos para fines propios:

| Proveedor | Para qué | Datos involucrados |
|---|---|---|
| Servicio de alojamiento en la nube del servidor y de la base de datos (MongoDB) | Almacenar y procesar la información de la aplicación | Todos los descritos en la sección 2 |
| Servicio de almacenamiento de archivos | Guardar las fotografías de comida | Fotografías |
| Servicio externo de inteligencia artificial para reconocimiento de alimentos | Analizar la fotografía y devolver una estimación de calorías, proteína y grasa | Únicamente la fotografía de la comida, sin tu nombre ni tu correo |

Algunos de estos proveedores pueden tener servidores fuera de México. En ese caso, exigimos que protejan tus datos con medidas equivalentes a las de este aviso.

Cuando se definan los proveedores concretos, actualizaremos esta sección con su nombre y te lo informaremos conforme a la sección 10.

### 5.3 Autoridades

Podemos comunicar tus datos a autoridades competentes cuando la ley nos obligue a hacerlo.

Fuera de los casos anteriores, **no transferimos** tus datos a terceros sin tu consentimiento.

## 6. Medidas de seguridad

Aplicamos medidas administrativas, técnicas y físicas para proteger tus datos contra daño, pérdida, alteración, destrucción, uso, acceso o tratamiento no autorizado, entre ellas:

- Las contraseñas se guardan solo como hash con un algoritmo diseñado para ello (Argon2id).
- La comunicación entre la aplicación y el servidor viaja cifrada por HTTPS.
- Las sesiones usan tokens de acceso de corta duración; los tokens de renovación se guardan solo como hash y se revocan al cerrar sesión.
- En tu dispositivo, la sesión se guarda en el almacenamiento seguro del sistema operativo.
- Cada cuenta accede solo a la información que le corresponde según su rol; un coach solo ve a los clientes vinculados con él.
- Las credenciales del servidor se manejan como variables de entorno y no se incluyen en el código fuente.

La aplicación puede guardar una copia de tus datos en tu dispositivo para funcionar sin conexión y sincronizarlos después. Protege tu dispositivo con bloqueo de pantalla.

Si ocurre una vulneración de seguridad que afecte de forma significativa tus derechos, te lo informaremos sin demora para que puedas tomar medidas.

## 7. Conservación de tus datos

Conservamos tus datos mientras tengas una cuenta activa en MacroFit.

Si eliminas tu cuenta o solicitas la cancelación de tus datos, los bloquearemos y después los suprimiremos de forma definitiva, salvo los que la ley nos obligue a conservar.

Los registros de comida que eliminas desde la aplicación se borran junto con su fotografía.

## 8. Derechos ARCO

Tienes derecho a:

- **Acceso:** conocer qué datos tenemos de ti y cómo los usamos.
- **Rectificación:** corregir tus datos si son inexactos o están incompletos.
- **Cancelación:** pedir que eliminemos tus datos.
- **Oposición:** oponerte a que usemos tus datos para fines específicos.

Puedes consultar y corregir directamente en la aplicación buena parte de tus datos: tu perfil, tus registros de comida y tu peso.

### Cómo presentar una solicitud

Envía un correo a **20233tn107@utez.edu.mx** con el asunto "Solicitud ARCO" e incluye:

1. Tu nombre y el correo con el que te registraste. La solicitud debe enviarse desde ese correo, o de lo contrario te pediremos otra forma de acreditar tu identidad.
2. El derecho que quieres ejercer y una descripción clara de los datos involucrados.
3. Si pides una rectificación, el dato correcto.

Te responderemos en un plazo máximo de **20 días hábiles** contados desde que recibamos tu solicitud. Si es procedente, la haremos efectiva dentro de los **15 días hábiles** siguientes a nuestra respuesta.

## 9. Revocación del consentimiento y límites al uso

Puedes revocar en cualquier momento el consentimiento que nos diste, enviando un correo al contacto indicado con el asunto "Revocación de consentimiento".

Ten en cuenta que, como los datos de salud son indispensables para el servicio, revocar el consentimiento implica que no podremos seguir prestándote las funciones de MacroFit y procederemos a cancelar tu cuenta.

Para dejar de compartir tus datos con tu coach no necesitas revocar tu consentimiento: basta con desvincularte desde la aplicación.

## 10. Cambios a este aviso

Podemos modificar este aviso por cambios legales, en las funciones de la aplicación o en los proveedores que usamos.

Te informaremos de cualquier cambio dentro de la aplicación y mostraremos la fecha de la última actualización al inicio de este documento. Si un cambio implica nuevas finalidades o nuevas transferencias que requieran tu consentimiento, te lo pediremos de nuevo.

## 11. Autoridad

Si consideras que tu derecho a la protección de datos personales ha sido vulnerado, puedes acudir ante la autoridad garante en la materia. Actualmente, esta función corresponde a la Secretaría Anticorrupción y Buen Gobierno.
