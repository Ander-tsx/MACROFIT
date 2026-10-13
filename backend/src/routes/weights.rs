use axum::{Json, Router, extract::State, http::StatusCode, routing::get};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError};
use crate::models::weight_entry::WeightEntry;
use crate::services::weights;
use crate::state::AppState;

/// Cuerpo de `POST /users/me/weights`. El peso llega como `Value` para señalar un texto en su campo.
#[derive(Debug, Deserialize)]
pub struct WeightRequest {
    pub weight_kg: Option<Value>,
}

#[derive(Debug, Serialize)]
pub struct WeightResponse {
    pub id: String,
    pub user_id: String,
    pub weight_kg: f64,
    pub recorded_at: String,
}

impl From<WeightEntry> for WeightResponse {
    fn from(entry: WeightEntry) -> Self {
        Self {
            id: entry.id.to_hex(),
            user_id: entry.user_id.to_hex(),
            weight_kg: entry.weight_kg,
            recorded_at: entry
                .recorded_at
                .try_to_rfc3339_string()
                .unwrap_or_default(),
        }
    }
}

/// HU-21 — POST /api/v1/users/me/weights. Registra un peso con la fecha del servidor.
async fn record_weight_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
    ApiJson(body): ApiJson<WeightRequest>,
) -> Result<(StatusCode, Json<WeightResponse>), AppError> {
    let entry = weights::record_weight(&state.db, auth.user_id, body.weight_kg).await?;
    Ok((StatusCode::CREATED, Json(entry.into())))
}

/// HU-21 — GET /api/v1/users/me/weights. Historial, del más reciente al más antiguo.
async fn list_weights_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<Json<Vec<WeightResponse>>, AppError> {
    let history = weights::list_weights(&state.db, auth.user_id).await?;
    Ok(Json(
        history.into_iter().map(WeightResponse::from).collect(),
    ))
}

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/users/me/weights",
        get(list_weights_handler).post(record_weight_handler),
    )
}
