# Backend MacroFit (Rust + Axum + MongoDB)

Servicio backend de MacroFit encargado de la **autenticación**, **persistencia en MongoDB** y **reglas de acceso base por rol** (*User* y *Coach*), correspondiente a la historia técnica **TEC-05**.

---

## 🛠️ Tecnologías y Dependencias

- **Lenguaje:** Rust (Edición 2024 / 2021)
- **Framework Web:** [Axum](https://github.com/tokio-rs/axum) (v0.7) sobre [Tokio](https://tokio.rs/)
- **Base de Datos:** [MongoDB](https://www.mongodb.com/) (Connector oficial v3.1 con soporte para MongoDB Atlas y TLS)
- **Seguridad y Criptografía:**
  - `bcrypt`: Hasheo unidireccional y seguro de contraseñas.
  - `jsonwebtoken` (`JWT`): Generación y validación de tokens de sesión con expiración de 24 horas.
- **Configuración:** `dotenvy` para carga de variables de entorno desde archivo `.env`.

---

## 📋 Requisitos Previos

1. **Rust y Cargo:** Instálalo desde [rustup.rs](https://rustup.rs/) si aún no lo tienes.
2. **Cluster de MongoDB Atlas** (o una instancia local de MongoDB en ejecución):
   - **Database Access:** Usuario con permisos de lectura y escritura (`readWriteAnyDatabase`).
   - **Network Access:** IP permitida (usa `0.0.0.0/0` para permitir conexiones de desarrollo).
3. **Postman** (opcional, para ejecutar las pruebas automáticas).

---

## ⚙️ Configuración del Entorno (`.env`)

Crea un archivo llamado `.env` dentro de la carpeta `backend/` (puedes guiarte de `.env.example`):

```env
# Cadena de conexión hacia tu cluster de Atlas o Mongo local
MONGO_URI=mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority&appName=MacroFit

# Nombre de la base de datos
DB_NAME=macrofit_db

# Clave secreta para firmar los tokens JWT
JWT_SECRET=super_secreto_macrofit_2026

# Puerto en el que escuchará el servidor
PORT=3000
```

> ⚠️ **Importante sobre MongoDB Atlas:** Si tu contraseña contiene caracteres especiales como `@`, `:`, `/`, asegúrate de codificarlos en formato URL (URL-encoding) o usar una contraseña alfanumérica.

---

## 🚀 Cómo Ejecutar el Servidor

1. Abre una terminal y navega hasta la carpeta `backend`:
   ```bash
   cd backend
   ```

2. *(Opcional)* Verifica que todo compile correctamente:
   ```bash
   cargo check
   ```

3. Arranca el servidor:
   ```bash
   cargo run
   ```

4. **Salida esperada en consola:**
   ```text
   Conectando y verificando cluster de MongoDB...
   ¡Ping exitoso! Conexión establecida correctamente con MongoDB.
   Servidor MacroFit corriendo en http://0.0.0.0:3000
   ```

---

## 🧪 Pruebas con Postman (Colección Lista)

Se incluye la colección preconfigurada en el archivo **`MacroFit_Postman_Collection.json`**.

### 1. Importar en Postman
1. Abre Postman.
2. Haz clic en el botón **Import** (esquina superior izquierda).
3. Arrastra o selecciona el archivo `backend/MacroFit_Postman_Collection.json`.
4. Aparecerá la colección **MacroFit Backend API**.

### 2. Correr todas las peticiones juntas (Collection Runner)
Todas las peticiones están ordenadas secuencialmente en la raíz y cuentan con scripts automáticos que generan correos únicos y capturan los tokens:

1. Haz clic derecho o en los tres puntos `...` de la colección **MacroFit Backend API**.
2. Selecciona **Run collection**.
3. Haz clic en **Run MacroFit Backend API**.
4. Verás todas las pruebas ejecutarse en secuencia y marcarse en verde (**Passed**).

---

## 📖 Catálogo de Endpoints Básicos

La URL base es `http://localhost:3000`.

### 1. Health Check
- **Ruta:** `GET /health`
- **Cabeceras:** Ninguna requerida.
- **Respuesta (200 OK):**
  ```text
  API MacroFit OK
  ```

---

### 2. Registro de Usuarios y Roles
- **Ruta:** `POST /auth/register`
- **Cabeceras:** `Content-Type: application/json`
- **Body JSON:**
  ```json
  {
    "name": "Erick",
    "email": "erick@macrofit.com",
    "password": "PasswordSeguro123",
    "role": "User"
  }
  ```
  *(Para registrar un entrenador, usa `"role": "Coach"`).*
- **Respuesta (201 Created):**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user_id": "67035ab2...",
    "email": "erick@macrofit.com",
    "name": "Erick",
    "role": "User"
  }
  ```

---

### 3. Inicio de Sesión
- **Ruta:** `POST /auth/login`
- **Cabeceras:** `Content-Type: application/json`
- **Body JSON:**
  ```json
  {
    "email": "erick@macrofit.com",
    "password": "PasswordSeguro123"
  }
  ```
- **Respuesta (200 OK):**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user_id": "67035ab2...",
    "email": "erick@macrofit.com",
    "name": "Erick",
    "role": "User"
  }
  ```

---

### 4. Ruta Protegida (Prueba de JWT Extractor)
- **Ruta:** `GET /auth/me`
- **Cabeceras:**
  - `Authorization: Bearer <TU_TOKEN_JWT>`
- **Respuesta (200 OK):**
  ```json
  {
    "message": "Usuario autenticado con éxito",
    "role": "User",
    "user_id": "67035ab2..."
  }
  ```
- **Si falta o expira el token:** Responde `401 Unauthorized`.

---

### 5. Regla de Acceso por Rol (Solo Coaches)
- **Ruta:** `GET /coach/test`
- **Cabeceras:**
  - `Authorization: Bearer <TU_TOKEN_JWT>`
- **Comportamiento:**
  - **Con token de un `Coach`:** Responde `200 OK` (`"Acceso permitido: eres Coach"`).
  - **Con token de un `User`:** Responde `403 Forbidden` (`"Acceso denegado: se requiere rol de Coach"`).

---

## 💻 Pruebas Rápidas por Terminal (cURL / PowerShell)

Si prefieres no usar Postman:

#### Probar Health:
```powershell
Invoke-RestMethod -Uri http://localhost:3000/health
```

#### Login y guardar Token en variable:
```powershell
$res = Invoke-RestMethod -Uri http://localhost:3000/auth/login -Method Post -ContentType "application/json" -Body '{"email":"erick@macrofit.com","password":"PasswordSeguro123"}'
$token = $res.token
```

#### Consumir endpoint protegido:
```powershell
Invoke-RestMethod -Uri http://localhost:3000/auth/me -Headers @{ Authorization = "Bearer $token" }
```
