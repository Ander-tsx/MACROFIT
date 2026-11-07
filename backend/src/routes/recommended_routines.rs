//! HU-15 — rutina recomendada del usuario (`/users/me/routines/recommended`, solo rol user).

use axum::{Json, Router, extract::State, http::StatusCode, routing::post};
use serde::Serialize;
use utoipa::ToSchema;

use crate::auth::middleware::UserOnly;
use crate::error::{AppError, ErrorResponse};
use crate::models::profile::{Level, Objective};
use crate::models::recommended_routine::{
    RecommendedExercise, RecommendedRoutine, RecommendedSession, RoutineOrigin,
};
use crate::services::recommended_routines;
use crate::state::AppState;

#[derive(Debug, Serialize, ToSchema)]
pub struct RecommendedExerciseResponse {
    /// Id del ejercicio en el catálogo (TEC-09).
    #[schema(example = "6acd4140ac968514f27322cd")]
    pub exercise_id: String,
    #[schema(example = "Flexiones de pecho")]
    pub name: String,
    /// Grupo muscular: `chest`, `back`, `legs`, `shoulders`, `arms` o `core`.
    #[schema(example = "chest")]
    pub muscle_group: String,
    /// Equipo requerido (p. ej. `bodyweight`, `dumbbell`, `barbell`).
    #[schema(example = "bodyweight")]
    pub equipment: String,
    /// Nivel del ejercicio: `beginner`, `intermediate` o `advanced` (igual o inferior al del usuario).
    #[schema(example = "beginner")]
    pub level: String,
    /// 2 principiante, 3 intermedio, 4 avanzado.
    #[schema(example = 2)]
    pub sets: i32,
    /// 10 `gain_muscle`, 12 `maintain`, 15 `lose_fat`.
    #[schema(example = 15)]
    pub reps: i32,
    /// Segundos de descanso entre series: 90 `gain_muscle`, 60 `maintain`, 45 `lose_fat`.
    #[schema(example = 45)]
    pub rest_seconds: i32,
}

impl From<RecommendedExercise> for RecommendedExerciseResponse {
    fn from(e: RecommendedExercise) -> Self {
        Self {
            exercise_id: e.exercise_id.to_hex(),
            name: e.name,
            muscle_group: e.muscle_group.as_str().to_string(),
            equipment: e.equipment,
            level: e.level.as_str().to_string(),
            sets: e.sets,
            reps: e.reps,
            rest_seconds: e.rest_seconds,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct RecommendedSessionResponse {
    /// Número de la sesión, desde 1. No se ata a un día de la semana.
    #[schema(example = 1)]
    pub number: i32,
    #[schema(example = "Día 1 · Empuje")]
    pub name: String,
    /// Foco: `full_body`, `upper`, `push`, `pull` o `legs`.
    #[schema(example = "push")]
    pub focus: String,
    pub exercises: Vec<RecommendedExerciseResponse>,
}

impl From<RecommendedSession> for RecommendedSessionResponse {
    fn from(s: RecommendedSession) -> Self {
        Self {
            number: s.number,
            name: s.name,
            focus: s.focus,
            exercises: s.exercises.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct RecommendedRoutineResponse {
    /// Id de la rutina recomendada; cambia cada vez que se genera otra.
    #[schema(example = "6b2a42d1ac968514f2732401")]
    pub id: String,
    /// Siempre `system` (RN-08).
    pub origin: RoutineOrigin,
    #[schema(example = "Rutina recomendada · Perder grasa · 3 días")]
    pub name: String,
    pub objective: Objective,
    pub level: Level,
    /// Días de entrenamiento del perfil; es igual al número de sesiones (RF-14).
    #[schema(example = 3)]
    pub training_days: i32,
    pub sessions: Vec<RecommendedSessionResponse>,
    /// Fecha y hora (RFC 3339, UTC) en que se generó.
    #[schema(format = DateTime, example = "2026-11-05T18:00:00Z")]
    pub created_at: String,
}

impl From<RecommendedRoutine> for RecommendedRoutineResponse {
    fn from(r: RecommendedRoutine) -> Self {
        Self {
            id: r.id.to_hex(),
            origin: r.origin,
            name: r.name,
            objective: r.objective,
            level: r.level,
            training_days: r.training_days,
            sessions: r.sessions.into_iter().map(Into::into).collect(),
            created_at: r.created_at.try_to_rfc3339_string().unwrap_or_default(),
        }
    }
}

/// HU-15 — POST /api/v1/users/me/routines/recommended. Genera y guarda la rutina recomendada.
#[utoipa::path(
    post,
    path = "/users/me/routines/recommended",
    tag = "Rutinas",
    summary = "Genera la rutina recomendada (HU-15)",
    description = "Sin cuerpo. Genera la rutina con el motor de reglas (TEC-10) a partir del objetivo, el nivel y los días de entrenamiento del perfil, con ejercicios del catálogo (TEC-09) del nivel del usuario o inferiores, y la guarda con origen `system`. Tiene una sesión por día de entrenamiento, nunca más (RF-14). Pedirla de nuevo la reemplaza: la anterior deja de estar vigente pero no se borra, igual que sus sesiones completadas.",
    security(("bearer_auth" = ["user"])),
    responses(
        (status = 201, description = "Rutina generada y vigente", body = RecommendedRoutineResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PROFILE_NOT_FOUND` (el usuario aún no captura su perfil)", body = ErrorResponse),
        (status = 503, description = "`EXERCISE_CATALOG_INCOMPLETE` (el catálogo no tiene ejercicios de algún grupo para el nivel del usuario; la rutina vigente no cambia)", body = ErrorResponse),
    )
)]
pub async fn generate_recommended_routine_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<(StatusCode, Json<RecommendedRoutineResponse>), AppError> {
    let routine =
        recommended_routines::generate_recommended_routine(&state.db, auth.user_id).await?;
    Ok((StatusCode::CREATED, Json(routine.into())))
}

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/users/me/routines/recommended",
        post(generate_recommended_routine_handler),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::{ExerciseLevel, MuscleGroup};
    use crate::models::recommended_routine::RecommendedStatus;
    use mongodb::bson::{DateTime, oid::ObjectId};

    #[test]
    fn la_respuesta_trae_origen_system_y_sesiones_sin_exponer_datos_internos() {
        let now = DateTime::now();
        let exercise_id = ObjectId::new();
        let routine = RecommendedRoutine {
            id: ObjectId::new(),
            user_id: ObjectId::new(),
            origin: RoutineOrigin::System,
            name: "Rutina recomendada · Perder grasa · 1 día".into(),
            objective: Objective::LoseFat,
            level: Level::Beginner,
            training_days: 1,
            sessions: vec![RecommendedSession {
                number: 1,
                name: "Día 1 · Cuerpo completo".into(),
                focus: "full_body".into(),
                exercises: vec![RecommendedExercise {
                    exercise_id,
                    name: "Flexiones de pecho".into(),
                    muscle_group: MuscleGroup::Chest,
                    equipment: "bodyweight".into(),
                    level: ExerciseLevel::Beginner,
                    sets: 2,
                    reps: 15,
                    rest_seconds: 45,
                }],
            }],
            status: RecommendedStatus::Active,
            created_at: now,
            replaced_at: None,
        };
        let json = serde_json::to_value(RecommendedRoutineResponse::from(routine.clone())).unwrap();
        assert_eq!(
            json,
            serde_json::json!({
                "id": routine.id.to_hex(),
                "origin": "system",
                "name": "Rutina recomendada · Perder grasa · 1 día",
                "objective": "lose_fat",
                "level": "beginner",
                "training_days": 1,
                "sessions": [{
                    "number": 1,
                    "name": "Día 1 · Cuerpo completo",
                    "focus": "full_body",
                    "exercises": [{
                        "exercise_id": exercise_id.to_hex(),
                        "name": "Flexiones de pecho",
                        "muscle_group": "chest",
                        "equipment": "bodyweight",
                        "level": "beginner",
                        "sets": 2,
                        "reps": 15,
                        "rest_seconds": 45,
                    }],
                }],
                "created_at": now.try_to_rfc3339_string().unwrap(),
            })
        );
    }
}
