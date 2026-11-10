//! HU-16 — rutinas del usuario con su origen: `GET /users/me/routines` y `GET /routines/{id}` (solo rol user).

use axum::{
    Json, Router,
    extract::{Path, State},
    routing::get,
};
use serde::Serialize;
use utoipa::ToSchema;

use crate::auth::middleware::UserOnly;
use crate::error::{AppError, ErrorResponse};
use crate::models::recommended_routine::RoutineOrigin;
use crate::services::user_routines::{
    self, DetailExercise, DetailSession, RoutineDetail, RoutineSummary,
};
use crate::state::AppState;

#[derive(Debug, Serialize, ToSchema)]
pub struct UserRoutineSummaryResponse {
    #[schema(example = "6b2a42d1ac968514f2732401")]
    pub id: String,
    /// `system` (recomendada, HU-15) o `coach` (asignada, HU-19) (RN-08).
    pub origin: RoutineOrigin,
    #[schema(example = "Rutina recomendada · Mantener · 3 días")]
    pub name: String,
    /// Nombre del coach que la asignó; `null` en la recomendada.
    #[schema(example = json!(null))]
    pub coach_name: Option<String>,
    /// Sesiones de la rutina: los días de la recomendada; 1 en una rutina del coach.
    #[schema(example = 3)]
    pub session_count: usize,
}

impl From<RoutineSummary> for UserRoutineSummaryResponse {
    fn from(r: RoutineSummary) -> Self {
        Self {
            id: r.id.to_hex(),
            origin: r.origin,
            name: r.name,
            coach_name: r.coach_name,
            session_count: r.session_count,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct UserRoutineExerciseResponse {
    /// Id del ejercicio en el catálogo (TEC-09).
    #[schema(example = "6acd4140ac968514f27322cd")]
    pub exercise_id: String,
    #[schema(example = "Press de banca con mancuernas")]
    pub name: String,
    /// Grupo muscular: `chest`, `back`, `legs`, `shoulders`, `arms` o `core`.
    #[schema(example = "chest")]
    pub muscle_group: String,
    #[schema(example = 4)]
    pub sets: i32,
    #[schema(example = 10)]
    pub reps: i32,
    /// Segundos de descanso entre series.
    #[schema(example = 90)]
    pub rest_seconds: i32,
}

impl From<DetailExercise> for UserRoutineExerciseResponse {
    fn from(e: DetailExercise) -> Self {
        Self {
            exercise_id: e.exercise_id.to_hex(),
            name: e.name,
            muscle_group: e.muscle_group.as_str().to_string(),
            sets: e.sets,
            reps: e.reps,
            rest_seconds: e.rest_seconds,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct UserRoutineSessionResponse {
    /// Número de la sesión, desde 1 (siempre 1 en una rutina del coach).
    #[schema(example = 1)]
    pub number: i32,
    /// `Día 1 · Empuje` en la recomendada; el nombre de la rutina en una del coach.
    #[schema(example = "Día 1 · Empuje")]
    pub name: String,
    pub exercises: Vec<UserRoutineExerciseResponse>,
}

impl From<DetailSession> for UserRoutineSessionResponse {
    fn from(s: DetailSession) -> Self {
        Self {
            number: s.number,
            name: s.name,
            exercises: s.exercises.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct UserRoutineDetailResponse {
    #[schema(example = "6b0142d1ac968514f27322ff")]
    pub id: String,
    pub origin: RoutineOrigin,
    #[schema(example = "Torso A")]
    pub name: String,
    /// Nombre del coach que la asignó; `null` en la recomendada.
    #[schema(example = "Carlos")]
    pub coach_name: Option<String>,
    pub sessions: Vec<UserRoutineSessionResponse>,
}

impl From<RoutineDetail> for UserRoutineDetailResponse {
    fn from(r: RoutineDetail) -> Self {
        Self {
            id: r.id.to_hex(),
            origin: r.origin,
            name: r.name,
            coach_name: r.coach_name,
            sessions: r.sessions.into_iter().map(Into::into).collect(),
        }
    }
}

/// HU-16 — GET /api/v1/users/me/routines. Rutinas del usuario con su origen.
#[utoipa::path(
    get,
    path = "/users/me/routines",
    tag = "Rutinas",
    summary = "Rutinas del usuario con su origen (HU-16)",
    description = "Primero la rutina recomendada vigente (origen `system`) y después las asignadas activas de su coach vinculado (origen `coach`, la asignada más recientemente primero). Se consulta sin caché: una asignación nueva aparece en la siguiente consulta y una retirada deja de aparecer (RF-23). Sin rutinas devuelve una lista vacía.",
    security(("bearer_auth" = ["user"])),
    responses(
        (status = 200, description = "Rutinas del usuario", body = [UserRoutineSummaryResponse]),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
    )
)]
pub async fn list_user_routines_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<Json<Vec<UserRoutineSummaryResponse>>, AppError> {
    let list = user_routines::list_user_routines(&state.db, auth.user_id).await?;
    Ok(Json(list.into_iter().map(Into::into).collect()))
}

/// HU-16 — GET /api/v1/routines/{id}. Detalle de una rutina del usuario.
#[utoipa::path(
    get,
    path = "/routines/{id}",
    tag = "Rutinas",
    summary = "Detalle de una rutina del usuario (HU-16)",
    description = "Misma forma para los dos orígenes: sesiones numeradas con sus ejercicios, series, repeticiones y descanso (RF-15). La recomendada trae una sesión por día de entrenamiento; una rutina del coach es una sola sesión, la 1, con el nombre de la rutina.",
    security(("bearer_auth" = ["user"])),
    params(("id" = String, Path, description = "Id de la rutina (de `GET /users/me/routines`)")),
    responses(
        (status = 200, description = "Rutina", body = UserRoutineDetailResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`ROUTINE_NOT_FOUND` (de otro usuario, retirada, reemplazada, de un coach desvinculado, inexistente o id mal formado)", body = ErrorResponse),
    )
)]
pub async fn get_user_routine_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
    Path(id): Path<String>,
) -> Result<Json<UserRoutineDetailResponse>, AppError> {
    let detail = user_routines::get_user_routine(&state.db, auth.user_id, &id).await?;
    Ok(Json(detail.into()))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/routines", get(list_user_routines_handler))
        .route("/routines/:id", get(get_user_routine_handler))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::MuscleGroup;
    use mongodb::bson::oid::ObjectId;

    #[test]
    fn la_lista_trae_origen_y_coach_name_nulo_en_la_recomendada() {
        let system = RoutineSummary {
            id: ObjectId::new(),
            origin: RoutineOrigin::System,
            name: "Rutina recomendada · Mantener · 3 días".into(),
            coach_name: None,
            session_count: 3,
        };
        let coach = RoutineSummary {
            id: ObjectId::new(),
            origin: RoutineOrigin::Coach,
            name: "Torso A".into(),
            coach_name: Some("Carlos".into()),
            session_count: 1,
        };
        let json = serde_json::to_value(
            [system.clone(), coach.clone()]
                .into_iter()
                .map(UserRoutineSummaryResponse::from)
                .collect::<Vec<_>>(),
        )
        .unwrap();
        assert_eq!(
            json,
            serde_json::json!([
                {
                    "id": system.id.to_hex(),
                    "origin": "system",
                    "name": "Rutina recomendada · Mantener · 3 días",
                    "coach_name": null,
                    "session_count": 3,
                },
                {
                    "id": coach.id.to_hex(),
                    "origin": "coach",
                    "name": "Torso A",
                    "coach_name": "Carlos",
                    "session_count": 1,
                },
            ])
        );
    }

    #[test]
    fn el_detalle_tiene_la_forma_comun_de_los_dos_origenes() {
        let exercise_id = ObjectId::new();
        let detail = RoutineDetail {
            id: ObjectId::new(),
            origin: RoutineOrigin::Coach,
            name: "Torso A".into(),
            coach_name: Some("Carlos".into()),
            sessions: vec![DetailSession {
                number: 1,
                name: "Torso A".into(),
                exercises: vec![DetailExercise {
                    exercise_id,
                    name: "Press de banca".into(),
                    muscle_group: MuscleGroup::Chest,
                    sets: 4,
                    reps: 10,
                    rest_seconds: 90,
                }],
            }],
        };
        let json = serde_json::to_value(UserRoutineDetailResponse::from(detail.clone())).unwrap();
        assert_eq!(
            json,
            serde_json::json!({
                "id": detail.id.to_hex(),
                "origin": "coach",
                "name": "Torso A",
                "coach_name": "Carlos",
                "sessions": [{
                    "number": 1,
                    "name": "Torso A",
                    "exercises": [{
                        "exercise_id": exercise_id.to_hex(),
                        "name": "Press de banca",
                        "muscle_group": "chest",
                        "sets": 4,
                        "reps": 10,
                        "rest_seconds": 90,
                    }],
                }],
            })
        );
    }
}
