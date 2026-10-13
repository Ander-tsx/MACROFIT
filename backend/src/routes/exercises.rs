//! TEC-09 — Rutas para consultar y sembrar el catálogo de ejercicios.

use std::collections::BTreeMap;

use axum::{
    Json, Router,
    extract::{Query, State},
    http::StatusCode,
    routing::get,
};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::AuthenticatedUser;
use crate::error::AppError;
use crate::models::exercise::{Exercise, ExerciseLevel, MuscleGroup};
use crate::services::exercises;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct ExerciseQuery {
    pub muscle_group: Option<String>,
    pub level: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ExerciseResponse {
    pub id: String,
    pub name: String,
    pub muscle_group: String,
    pub equipment: String,
    pub level: String,
    pub created_at: String,
}

impl From<Exercise> for ExerciseResponse {
    fn from(e: Exercise) -> Self {
        Self {
            id: e.id.to_hex(),
            name: e.name,
            muscle_group: e.muscle_group.as_str().to_string(),
            equipment: e.equipment,
            level: e.level.as_str().to_string(),
            created_at: e.created_at.try_to_rfc3339_string().unwrap_or_default(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct SeedExercisesResponse {
    pub message: String,
    pub count: usize,
}

/// TEC-09 — `GET /api/v1/exercises`. Consulta del catálogo de ejercicios con filtros opcionales.
pub async fn list_exercises_handler(
    _auth: AuthenticatedUser,
    State(state): State<AppState>,
    Query(query): Query<ExerciseQuery>,
) -> Result<Json<Vec<ExerciseResponse>>, AppError> {
    let mut field_errors = BTreeMap::new();

    let mg = match query.muscle_group.as_deref() {
        Some(s) if !s.trim().is_empty() => match MuscleGroup::parse(s) {
            Some(val) => Some(val),
            None => {
                field_errors.insert(
                    "muscle_group".to_string(),
                    "El grupo muscular debe ser 'chest', 'back', 'legs', 'shoulders', 'arms' o 'core'".to_string(),
                );
                None
            }
        },
        _ => None,
    };

    let lvl = match query.level.as_deref() {
        Some(s) if !s.trim().is_empty() => match ExerciseLevel::parse(s) {
            Some(val) => Some(val),
            None => {
                field_errors.insert(
                    "level".to_string(),
                    "El nivel debe ser 'beginner', 'intermediate' o 'advanced'".to_string(),
                );
                None
            }
        },
        _ => None,
    };

    if !field_errors.is_empty() {
        return Err(AppError::Validation(field_errors));
    }

    let items = exercises::list_exercises(&state.db, mg, lvl).await?;
    let response = items.into_iter().map(ExerciseResponse::from).collect();
    Ok(Json(response))
}

/// TEC-09 — `POST /api/v1/dev/seed/exercises`. Carga de semilla del catálogo inicial (idempotente).
/// Montada únicamente en desarrollo a través de `routes::dev::router()`.
pub async fn seed_exercises_handler(
    State(state): State<AppState>,
) -> Result<(StatusCode, Json<SeedExercisesResponse>), AppError> {
    let count = exercises::seed_exercises(&state.db).await?;
    Ok((
        StatusCode::CREATED,
        Json(SeedExercisesResponse {
            message: "Catálogo de ejercicios cargado correctamente".to_string(),
            count,
        }),
    ))
}

pub fn router() -> Router<AppState> {
    Router::new().route("/exercises", get(list_exercises_handler))
}

#[cfg(test)]
mod tests {
    use super::*;
    use mongodb::bson::{DateTime, oid::ObjectId};

    #[test]
    fn exercise_response_serializa_todos_los_campos() {
        let oid = ObjectId::new();
        let now = DateTime::now();
        let ex = Exercise {
            id: oid,
            name: "Flexiones de pecho".to_string(),
            muscle_group: MuscleGroup::Chest,
            equipment: "bodyweight".to_string(),
            level: ExerciseLevel::Beginner,
            created_at: now,
        };
        let resp = ExerciseResponse::from(ex);
        assert_eq!(resp.id, oid.to_hex());
        assert_eq!(resp.name, "Flexiones de pecho");
        assert_eq!(resp.muscle_group, "chest");
        assert_eq!(resp.equipment, "bodyweight");
        assert_eq!(resp.level, "beginner");
        assert_eq!(resp.created_at, now.try_to_rfc3339_string().unwrap());
    }
}
