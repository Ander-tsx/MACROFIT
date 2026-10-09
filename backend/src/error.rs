use std::collections::BTreeMap;

use axum::{
    Json,
    extract::rejection::JsonRejection,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde_json::json;

/// Errores por campo: nombre del campo → mensaje para mostrar.
pub type FieldErrors = BTreeMap<String, String>;

/// Todos los errores que puede devolver la API.
///
/// Se serializan siempre como `{ "error": { "code", "message", "fields" } }`.
/// Al agregar una variante, documenta su código en `backend/README.md`.
#[derive(Debug)]
pub enum AppError {
    /// 400 — uno o más campos no pasaron la validación.
    Validation(FieldErrors),
    /// 400 — el cuerpo no es JSON válido o un campo tiene un tipo incorrecto.
    InvalidBody(String),
    /// 400 — no se aceptó el aviso de privacidad (y el resto de campos es válido).
    PrivacyNotAccepted,
    /// 409 — ya existe una cuenta con ese correo.
    EmailAlreadyExists,
    /// 401 — correo o contraseña incorrectos.
    InvalidCredentials,
    /// 401 — falta el token o no es válido.
    Unauthorized(&'static str),
    /// 401 — refresh token desconocido o expirado.
    InvalidRefreshToken,
    /// 401 — el token pertenece a una sesión cerrada o revocada.
    TokenRevoked,
    /// 403 — el rol no tiene acceso al recurso.
    Forbidden(&'static str),
    /// 500 — error inesperado; el detalle solo va al log.
    Internal(String),
    /// 404 — el usuario aún no tiene perfil registrado.
    ProfileNotFound,
}

impl AppError {
    pub fn internal(err: impl std::fmt::Display) -> Self {
        Self::Internal(err.to_string())
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message, fields) = match self {
            Self::Validation(fields) => (
                StatusCode::BAD_REQUEST,
                "VALIDATION_ERROR",
                "Hay campos inválidos".to_string(),
                fields,
            ),
            Self::InvalidBody(detail) => (
                StatusCode::BAD_REQUEST,
                "INVALID_BODY",
                format!("El cuerpo de la petición no es válido: {detail}"),
                FieldErrors::new(),
            ),
            Self::PrivacyNotAccepted => (
                StatusCode::BAD_REQUEST,
                "PRIVACY_NOT_ACCEPTED",
                "Debes aceptar el aviso de privacidad".to_string(),
                FieldErrors::from([(
                    "privacy_accepted".to_string(),
                    "Debes aceptar el aviso de privacidad".to_string(),
                )]),
            ),
            Self::EmailAlreadyExists => (
                StatusCode::CONFLICT,
                "EMAIL_ALREADY_EXISTS",
                "Ya existe una cuenta con ese correo".to_string(),
                FieldErrors::from([(
                    "email".to_string(),
                    "Este correo ya está registrado".to_string(),
                )]),
            ),
            Self::InvalidCredentials => (
                StatusCode::UNAUTHORIZED,
                "INVALID_CREDENTIALS",
                "Correo o contraseña incorrectos".to_string(),
                FieldErrors::new(),
            ),
            Self::Unauthorized(message) => (
                StatusCode::UNAUTHORIZED,
                "UNAUTHORIZED",
                message.to_string(),
                FieldErrors::new(),
            ),
            Self::InvalidRefreshToken => (
                StatusCode::UNAUTHORIZED,
                "INVALID_REFRESH_TOKEN",
                "El token de actualización no es válido o expiró".to_string(),
                FieldErrors::new(),
            ),
            Self::TokenRevoked => (
                StatusCode::UNAUTHORIZED,
                "TOKEN_REVOKED",
                "La sesión fue cerrada; inicia sesión de nuevo".to_string(),
                FieldErrors::new(),
            ),
            Self::Forbidden(message) => (
                StatusCode::FORBIDDEN,
                "FORBIDDEN",
                message.to_string(),
                FieldErrors::new(),
            ),
            Self::Internal(detail) => {
                eprintln!("[error interno] {detail}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "INTERNAL_ERROR",
                    "Ocurrió un error inesperado".to_string(),
                    FieldErrors::new(),
                )
            }
            Self::ProfileNotFound => (
                StatusCode::NOT_FOUND,
                "PROFILE_NOT_FOUND",
                "Perfil de usuario no encontrado".to_string(),
                FieldErrors::new(),
            ),
        };

        let body = json!({
            "error": {
                "code": code,
                "message": message,
                "fields": fields,
            }
        });
        (status, Json(body)).into_response()
    }
}

impl From<JsonRejection> for AppError {
    fn from(rejection: JsonRejection) -> Self {
        Self::InvalidBody(rejection.body_text())
    }
}

/// Extractor JSON que, si falla, responde con el formato de error de la API
/// en lugar del texto plano de Axum. Úsalo en vez de `axum::Json` para leer cuerpos.
#[derive(axum::extract::FromRequest)]
#[from_request(via(axum::Json), rejection(AppError))]
pub struct ApiJson<T>(pub T);
