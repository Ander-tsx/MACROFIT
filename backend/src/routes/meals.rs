use axum::{
    Json, Router,
    extract::{
        DefaultBodyLimit, State,
        multipart::{Multipart, MultipartError, MultipartRejection},
    },
    http::StatusCode,
    routing::post,
};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError, ErrorResponse};
use crate::models::meal_photo::PhotoFormat;
use crate::services::food_recognition::{IdentifiedFood, Nutrients};
use crate::services::meal_estimates::{self, MealEstimate};
use crate::services::photos::{self, MAX_PHOTO_BYTES, UploadedPhoto};
use crate::state::AppState;

/// Campo del formulario multipart que lleva la foto.
const PHOTO_FIELD: &str = "photo";

/// Límite del cuerpo de POST /meals/photos: la foto más 1 MiB de margen para lo que agrega el multipart
/// (separadores, cabeceras de cada campo y campos extra). Axum limita a 2 MB por defecto.
const PHOTO_UPLOAD_BODY_LIMIT: usize = MAX_PHOTO_BYTES + 1024 * 1024;

/// Solo documenta el formulario en OpenAPI: el handler lee el multipart a mano (`read_photo_field`).
#[derive(utoipa::ToSchema)]
#[schema(
    description = "Formulario `multipart/form-data` con la foto. Los demás campos se ignoran."
)]
#[allow(dead_code)]
pub struct PhotoUploadForm {
    /// Archivo JPEG o PNG de hasta 5 MiB. El tipo se detecta por el contenido, no por la extensión.
    #[schema(value_type = String, format = Binary)]
    photo: Vec<u8>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[schema(description = "Foto guardada a nombre del usuario de la sesión.")]
pub struct PhotoUploadResponse {
    /// Id de la foto; lo usan la estimación (HU-07) y el registro de comida (HU-09).
    #[schema(example = "6acd4140ac968514f27322cd")]
    pub id: String,
    pub format: PhotoFormat,
    /// Tamaño del archivo en bytes.
    #[schema(example = 134)]
    pub size_bytes: usize,
}

impl From<UploadedPhoto> for PhotoUploadResponse {
    fn from(photo: UploadedPhoto) -> Self {
        Self {
            id: photo.id.to_hex(),
            format: photo.format,
            size_bytes: photo.size_bytes,
        }
    }
}

/// HU-06 — POST /api/v1/meals/photos. Sube la foto de una comida (multipart, campo `photo`) a nombre del usuario.
#[utoipa::path(
    post,
    path = "/meals/photos",
    tag = "Comidas",
    summary = "Sube la foto de una comida (HU-06)",
    description = "Guarda la foto en GridFS a nombre del usuario de la sesión y devuelve su id. Solo JPEG o PNG (se revisa el contenido) y como máximo 5 MiB; el tamaño se revisa antes que el tipo. Si hay varios campos `photo`, se toma el primero.",
    security(("bearer_auth" = ["user"])),
    request_body(content = PhotoUploadForm, content_type = "multipart/form-data"),
    responses(
        (status = 201, description = "Foto guardada", body = PhotoUploadResponse),
        (status = 400, description = "`VALIDATION_ERROR` (falta `photo` o está vacío) o `INVALID_BODY` (no es `multipart/form-data`)", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 413, description = "`PHOTO_TOO_LARGE` (más de 5 MiB)", body = ErrorResponse),
        (status = 415, description = "`UNSUPPORTED_PHOTO_TYPE` (no es JPEG ni PNG)", body = ErrorResponse),
    )
)]
pub async fn upload_photo_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
    multipart: Result<Multipart, MultipartRejection>,
) -> Result<(StatusCode, Json<PhotoUploadResponse>), AppError> {
    let multipart = multipart.map_err(|rejection| AppError::InvalidBody(rejection.body_text()))?;
    let bytes = read_photo_field(multipart).await?;
    let photo = photos::upload_photo(&state.db, auth.user_id, bytes).await?;
    Ok((StatusCode::CREATED, Json(photo.into())))
}

/// Contenido del primer campo `photo`, o `None` si no viene. Guarda como máximo `MAX_PHOTO_BYTES + 1` bytes: basta
/// para que el servicio responda `PHOTO_TOO_LARGE` sin tener en memoria un archivo enorme. El resto del cuerpo se lee
/// y se descarta (está acotado por `PHOTO_UPLOAD_BODY_LIMIT`), así el cliente recibe la respuesta completa en lugar
/// de un corte de conexión.
async fn read_photo_field(mut multipart: Multipart) -> Result<Option<Vec<u8>>, AppError> {
    let mut photo = None;
    while let Some(mut field) = multipart.next_field().await.map_err(multipart_error)? {
        let keep = photo.is_none() && field.name() == Some(PHOTO_FIELD);
        let mut bytes = Vec::new();
        while let Some(chunk) = field.chunk().await.map_err(multipart_error)? {
            if keep && bytes.len() <= MAX_PHOTO_BYTES {
                let room = MAX_PHOTO_BYTES + 1 - bytes.len();
                bytes.extend_from_slice(&chunk[..chunk.len().min(room)]);
            }
        }
        if keep {
            photo = Some(bytes);
        }
    }
    Ok(photo)
}

// ───────────────────────── HU-07 — estimación nutricional ─────────────────────────

#[derive(Debug, Deserialize, utoipa::ToSchema)]
#[schema(description = "Foto a estimar.")]
pub struct EstimateRequest {
    /// Id de una foto propia subida con `POST /meals/photos` (HU-06).
    #[schema(value_type = String, required = true, example = "6acd4140ac968514f27322cd")]
    pub photo_id: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, utoipa::ToSchema)]
#[schema(description = "Calorías, proteína y grasa, redondeadas a un decimal.")]
pub struct NutrientsResponse {
    #[schema(example = 413.0)]
    pub calories_kcal: f64,
    #[schema(example = 42.2)]
    pub protein_g: f64,
    #[schema(example = 4.9)]
    pub fat_g: f64,
}

impl From<Nutrients> for NutrientsResponse {
    fn from(n: Nutrients) -> Self {
        Self {
            calories_kcal: n.calories_kcal,
            protein_g: n.protein_g,
            fat_g: n.fat_g,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, utoipa::ToSchema)]
#[schema(description = "Alimento identificado en la foto (RF-06).")]
pub struct EstimatedFoodResponse {
    #[schema(example = "Arroz blanco cocido")]
    pub name: String,
    /// Peso estimado de la porción; `null` si el servicio no lo da.
    #[schema(example = 150.0)]
    pub grams: Option<f64>,
    #[schema(example = 195.0)]
    pub calories_kcal: f64,
    #[schema(example = 4.0)]
    pub protein_g: f64,
    #[schema(example = 0.4)]
    pub fat_g: f64,
}

impl From<IdentifiedFood> for EstimatedFoodResponse {
    fn from(food: IdentifiedFood) -> Self {
        Self {
            name: food.name,
            grams: food.grams,
            calories_kcal: food.nutrients.calories_kcal,
            protein_g: food.nutrients.protein_g,
            fat_g: food.nutrients.fat_g,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, utoipa::ToSchema)]
#[schema(
    description = "Estimación de la foto. Es una sugerencia: el usuario la revisa y corrige antes de guardar (HU-08)."
)]
pub struct EstimateResponse {
    #[schema(example = "6acd4140ac968514f27322cd")]
    pub photo_id: String,
    /// Alimentos identificados. Nunca está vacía: sin alimentos se responde `422 FOOD_NOT_RECOGNIZED`.
    pub foods: Vec<EstimatedFoodResponse>,
    /// Suma de los alimentos.
    pub totals: NutrientsResponse,
}

impl From<MealEstimate> for EstimateResponse {
    fn from(meal: MealEstimate) -> Self {
        Self {
            photo_id: meal.photo_id,
            foods: meal
                .estimate
                .foods
                .into_iter()
                .map(EstimatedFoodResponse::from)
                .collect(),
            totals: meal.estimate.totals.into(),
        }
    }
}

/// HU-07 — POST /api/v1/meals/estimate. Estima calorías, proteína y grasa de una foto propia (RF-06).
#[utoipa::path(
    post,
    path = "/meals/estimate",
    tag = "Comidas",
    summary = "Estima los valores nutricionales de una foto (HU-07)",
    description = "Envía la foto al servicio de reconocimiento de alimentos configurado (`FOOD_PROVIDER`; el simulador en desarrollo) y devuelve los alimentos identificados con sus calorías, proteína y grasa. No guarda nada. El servicio externo tiene un tiempo de espera de 10 s como máximo.",
    security(("bearer_auth" = ["user"])),
    request_body = EstimateRequest,
    responses(
        (status = 200, description = "Alimentos identificados y totales", body = EstimateResponse),
        (status = 400, description = "`VALIDATION_ERROR` (falta `photo_id`) o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PHOTO_NOT_FOUND` (no existe, id mal formado o es de otro usuario)", body = ErrorResponse),
        (status = 422, description = "`FOOD_NOT_RECOGNIZED`: no se reconoció comida; la app ofrece la captura manual", body = ErrorResponse),
        (status = 502, description = "`FOOD_PROVIDER_ERROR`: el servicio de reconocimiento falló", body = ErrorResponse),
        (status = 504, description = "`FOOD_PROVIDER_TIMEOUT`: el servicio de reconocimiento no respondió a tiempo", body = ErrorResponse),
    )
)]
pub async fn estimate_meal_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
    ApiJson(body): ApiJson<EstimateRequest>,
) -> Result<Json<EstimateResponse>, AppError> {
    let meal =
        meal_estimates::estimate_meal(&state.db, &state.food, auth.user_id, body.photo_id).await?;
    Ok(Json(meal.into()))
}

/// Un cuerpo que pasa el límite de la ruta es una foto demasiado grande; cualquier otro error, un multipart mal formado.
fn multipart_error(err: MultipartError) -> AppError {
    if err.status() == StatusCode::PAYLOAD_TOO_LARGE {
        AppError::PhotoTooLarge
    } else {
        AppError::InvalidBody(err.body_text())
    }
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/meals/photos",
            post(upload_photo_handler).layer(DefaultBodyLimit::max(PHOTO_UPLOAD_BODY_LIMIT)),
        )
        .route("/meals/estimate", post(estimate_meal_handler))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{body::Body, http::Request, response::IntoResponse};
    use tower::ServiceExt;

    const BOUNDARY: &str = "macrofit-prueba";

    /// Lee la foto como el handler real (mismo límite de cuerpo), sin sesión ni base de datos.
    /// Responde 200 con el tamaño leído, 204 si no vino el campo, o el error de la API.
    fn reader_app() -> Router {
        async fn handler(
            multipart: Result<Multipart, MultipartRejection>,
        ) -> axum::response::Response {
            let multipart = match multipart {
                Ok(multipart) => multipart,
                Err(rejection) => {
                    return AppError::InvalidBody(rejection.body_text()).into_response();
                }
            };
            match read_photo_field(multipart).await {
                Ok(Some(bytes)) => bytes.len().to_string().into_response(),
                Ok(None) => StatusCode::NO_CONTENT.into_response(),
                Err(err) => err.into_response(),
            }
        }
        Router::new().route(
            "/",
            post(handler).layer(DefaultBodyLimit::max(PHOTO_UPLOAD_BODY_LIMIT)),
        )
    }

    fn part(name: &str, content: &[u8]) -> Vec<u8> {
        let mut part = format!(
            "--{BOUNDARY}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"comida.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"
        )
        .into_bytes();
        part.extend_from_slice(content);
        part.extend_from_slice(b"\r\n");
        part
    }

    fn multipart_body(parts: &[(&str, &[u8])]) -> Vec<u8> {
        let mut body: Vec<u8> = parts
            .iter()
            .flat_map(|(name, content)| part(name, content))
            .collect();
        body.extend_from_slice(format!("--{BOUNDARY}--\r\n").as_bytes());
        body
    }

    async fn send(content_type: &str, body: Vec<u8>) -> (StatusCode, String) {
        let request = Request::post("/")
            .header("content-type", content_type)
            .body(Body::from(body))
            .unwrap();
        let response = reader_app().oneshot(request).await.unwrap();
        let status = response.status();
        let bytes = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        (status, String::from_utf8_lossy(&bytes).into_owned())
    }

    async fn send_multipart(parts: &[(&str, &[u8])]) -> (StatusCode, String) {
        let content_type = format!("multipart/form-data; boundary={BOUNDARY}");
        send(&content_type, multipart_body(parts)).await
    }

    #[tokio::test]
    async fn lee_el_campo_photo_completo() {
        let (status, body) = send_multipart(&[("photo", &[7; 1000])]).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body, "1000");
    }

    #[tokio::test]
    async fn ignora_otros_campos_y_toma_el_primer_photo() {
        let (status, body) =
            send_multipart(&[("nota", b"hola"), ("photo", &[1; 10]), ("photo", &[2; 20])]).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body, "10");
    }

    #[tokio::test]
    async fn sin_campo_photo_no_hay_foto() {
        let (status, _) = send_multipart(&[("archivo", &[1; 10])]).await;
        assert_eq!(status, StatusCode::NO_CONTENT);
    }

    #[tokio::test]
    async fn foto_mayor_al_maximo_se_corta_en_un_byte_extra() {
        // Pasa el límite del servicio pero no el de la ruta: se leen MAX + 1 bytes para que el servicio responda 413.
        let (status, body) = send_multipart(&[("photo", &vec![0; MAX_PHOTO_BYTES + 10])]).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body, (MAX_PHOTO_BYTES + 1).to_string());
    }

    #[tokio::test]
    async fn cuerpo_mayor_al_limite_de_la_ruta_es_photo_too_large() {
        let (status, body) =
            send_multipart(&[("photo", &vec![0; PHOTO_UPLOAD_BODY_LIMIT + 1])]).await;
        assert_eq!(status, StatusCode::PAYLOAD_TOO_LARGE);
        assert!(body.contains("PHOTO_TOO_LARGE"));
    }

    #[tokio::test]
    async fn cuerpo_que_no_es_multipart_es_invalid_body() {
        let (status, body) = send("application/json", b"{\"photo\":\"x\"}".to_vec()).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert!(body.contains("INVALID_BODY"));
    }
}
