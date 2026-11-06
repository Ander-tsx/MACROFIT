//! HU-18 — rutas de las rutinas personalizadas del coach (`/coach/routines`, solo rol coach).
//! HU-19 — asignación de una rutina a clientes (`/coach/routines/{id}/assignments`).

use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::get,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;

use crate::auth::middleware::CoachOnly;
use crate::error::{ApiJson, AppError, ErrorResponse};
use crate::models::routine::{Routine, RoutineExercise};
use crate::services::routine_assignments::{self, AssignmentView};
use crate::services::routines::{self, RoutineInput};
use crate::state::AppState;

/// Ejercicio de la rutina tal como lo envía la app. Solo describe el contrato en OpenAPI: el cuerpo se lee como
/// `RoutineRequest` y cada valor se valida en el servicio.
#[allow(dead_code)]
#[derive(Debug, ToSchema)]
pub struct RoutineExerciseRequest {
    /// Id de un ejercicio del catálogo (`GET /exercises`, TEC-09).
    #[schema(example = "6acd4140ac968514f27322cd")]
    pub exercise_id: String,
    /// Series, de 1 a 10.
    #[schema(example = 4, minimum = 1, maximum = 10)]
    pub sets: i32,
    /// Repeticiones por serie, de 1 a 100.
    #[schema(example = 10, minimum = 1, maximum = 100)]
    pub reps: i32,
    /// Descanso entre series en segundos, de 0 a 600.
    #[schema(example = 90, minimum = 0, maximum = 600)]
    pub rest_seconds: i32,
}

#[derive(Debug, Deserialize, ToSchema)]
#[schema(
    description = "Rutina a crear o a guardar (la edición reemplaza la rutina completa). Los errores de cada ejercicio se señalan como `exercises[i].<campo>`."
)]
pub struct RoutineRequest {
    /// Nombre de la rutina, de 1 a 80 caracteres (sin espacios alrededor).
    #[schema(value_type = String, required = true, example = "Torso A")]
    pub name: Option<Value>,
    /// De 1 a 20 ejercicios del catálogo, en el orden en que se hacen.
    #[schema(value_type = Vec<RoutineExerciseRequest>, required = true)]
    pub exercises: Option<Value>,
}

impl From<RoutineRequest> for RoutineInput {
    fn from(body: RoutineRequest) -> Self {
        Self {
            name: body.name,
            exercises: body.exercises,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct RoutineExerciseResponse {
    /// Id del ejercicio en el catálogo (TEC-09).
    #[schema(example = "6acd4140ac968514f27322cd")]
    pub exercise_id: String,
    /// Nombre del ejercicio en el catálogo.
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

impl From<RoutineExercise> for RoutineExerciseResponse {
    fn from(e: RoutineExercise) -> Self {
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
pub struct RoutineResponse {
    #[schema(example = "6b0142d1ac968514f27322ff")]
    pub id: String,
    #[schema(example = "Torso A")]
    pub name: String,
    pub exercises: Vec<RoutineExerciseResponse>,
    #[schema(format = DateTime, example = "2026-10-26T18:00:00Z")]
    pub created_at: String,
    /// Cambia en cada edición.
    #[schema(format = DateTime, example = "2026-10-26T18:00:00Z")]
    pub updated_at: String,
}

impl From<Routine> for RoutineResponse {
    fn from(r: Routine) -> Self {
        Self {
            id: r.id.to_hex(),
            name: r.name,
            exercises: r.exercises.into_iter().map(Into::into).collect(),
            created_at: r.created_at.try_to_rfc3339_string().unwrap_or_default(),
            updated_at: r.updated_at.try_to_rfc3339_string().unwrap_or_default(),
        }
    }
}

/// HU-18 — POST /api/v1/coach/routines. Crea una rutina del coach.
#[utoipa::path(
    post,
    path = "/coach/routines",
    tag = "Rutinas",
    summary = "Crea una rutina personalizada (HU-18)",
    description = "Requiere nombre y al menos un ejercicio del catálogo (TEC-09) con series, repeticiones y descanso. El nombre y el grupo muscular de cada ejercicio se toman del catálogo.",
    security(("bearer_auth" = ["coach"])),
    request_body = RoutineRequest,
    responses(
        (status = 201, description = "Rutina creada", body = RoutineResponse),
        (status = 400, description = "`VALIDATION_ERROR` (`name`, `exercises`, `exercises[i].<campo>`; un `exercise_id` que no está en el catálogo) o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
    )
)]
pub async fn create_routine_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
    ApiJson(body): ApiJson<RoutineRequest>,
) -> Result<(StatusCode, Json<RoutineResponse>), AppError> {
    let routine = routines::create_routine(&state.db, auth.user_id, body.into()).await?;
    Ok((StatusCode::CREATED, Json(routine.into())))
}

/// HU-18 — GET /api/v1/coach/routines. Rutinas del coach de la sesión.
#[utoipa::path(
    get,
    path = "/coach/routines",
    tag = "Rutinas",
    summary = "Rutinas del coach (HU-18)",
    description = "Solo las rutinas del coach de la sesión, de la editada más recientemente a la más antigua. Sin rutinas devuelve una lista vacía.",
    security(("bearer_auth" = ["coach"])),
    responses(
        (status = 200, description = "Rutinas del coach", body = [RoutineResponse]),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
    )
)]
pub async fn list_routines_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
) -> Result<Json<Vec<RoutineResponse>>, AppError> {
    let list = routines::list_routines(&state.db, auth.user_id).await?;
    Ok(Json(list.into_iter().map(RoutineResponse::from).collect()))
}

/// HU-18 — GET /api/v1/coach/routines/{id}. Detalle de una rutina propia.
#[utoipa::path(
    get,
    path = "/coach/routines/{id}",
    tag = "Rutinas",
    summary = "Detalle de una rutina (HU-18)",
    security(("bearer_auth" = ["coach"])),
    params(("id" = String, Path, description = "Id de la rutina")),
    responses(
        (status = 200, description = "Rutina", body = RoutineResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
        (status = 404, description = "`ROUTINE_NOT_FOUND` (no existe, id mal formado o es de otro coach)", body = ErrorResponse),
    )
)]
pub async fn get_routine_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
    Path(id): Path<String>,
) -> Result<Json<RoutineResponse>, AppError> {
    let routine = routines::get_routine(&state.db, auth.user_id, &id).await?;
    Ok(Json(routine.into()))
}

/// HU-18 — PUT /api/v1/coach/routines/{id}. Reemplaza el nombre y los ejercicios de una rutina propia.
#[utoipa::path(
    put,
    path = "/coach/routines/{id}",
    tag = "Rutinas",
    summary = "Edita una rutina (HU-18)",
    description = "Reemplazo completo: mismo cuerpo y mismas reglas que al crear. Una rutina ajena responde 404 antes de validar el cuerpo.",
    security(("bearer_auth" = ["coach"])),
    params(("id" = String, Path, description = "Id de la rutina")),
    request_body = RoutineRequest,
    responses(
        (status = 200, description = "Rutina actualizada", body = RoutineResponse),
        (status = 400, description = "`VALIDATION_ERROR` (mismos campos que al crear) o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
        (status = 404, description = "`ROUTINE_NOT_FOUND` (no existe, id mal formado o es de otro coach)", body = ErrorResponse),
    )
)]
pub async fn update_routine_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
    Path(id): Path<String>,
    ApiJson(body): ApiJson<RoutineRequest>,
) -> Result<Json<RoutineResponse>, AppError> {
    let routine = routines::update_routine(&state.db, auth.user_id, &id, body.into()).await?;
    Ok(Json(routine.into()))
}

/// HU-18 — DELETE /api/v1/coach/routines/{id}. Elimina una rutina propia.
#[utoipa::path(
    delete,
    path = "/coach/routines/{id}",
    tag = "Rutinas",
    summary = "Elimina una rutina (HU-18)",
    security(("bearer_auth" = ["coach"])),
    params(("id" = String, Path, description = "Id de la rutina")),
    responses(
        (status = 204, description = "Rutina eliminada"),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
        (status = 404, description = "`ROUTINE_NOT_FOUND` (no existe, id mal formado o es de otro coach)", body = ErrorResponse),
    )
)]
pub async fn delete_routine_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    routines::delete_routine(&state.db, auth.user_id, &id).await?;
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Debug, Deserialize, ToSchema)]
#[schema(
    description = "Clientes a los que se asigna la rutina. Todos deben tener vinculación activa con el coach; si alguno no la tiene no se asigna a ninguno."
)]
pub struct AssignRoutineRequest {
    /// De 1 a 50 ids de clientes vinculados (`GET /coach/clients`). Los repetidos se toman una vez.
    #[schema(value_type = Vec<String>, required = true, example = json!(["6ad0a1b2c3d4e5f6a7b8c9d0", "6ad0a1b2c3d4e5f6a7b8c9d1"]))]
    pub client_ids: Option<Value>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct RoutineAssignmentResponse {
    /// Id de la asignación.
    #[schema(example = "6b1042d1ac968514f2732301")]
    pub id: String,
    #[schema(example = "6b0142d1ac968514f27322ff")]
    pub routine_id: String,
    #[schema(example = "6ad0a1b2c3d4e5f6a7b8c9d0")]
    pub client_id: String,
    /// Nombre del cliente.
    #[schema(example = "Ana")]
    pub client_name: String,
    /// Fecha y hora (RFC 3339, UTC) en que se asignó. Asignar de nuevo no la cambia.
    #[schema(format = DateTime, example = "2026-11-05T18:00:00Z")]
    pub assigned_at: String,
}

impl From<AssignmentView> for RoutineAssignmentResponse {
    fn from(view: AssignmentView) -> Self {
        let a = view.assignment;
        Self {
            id: a.id.to_hex(),
            routine_id: a.routine_id.to_hex(),
            client_id: a.client_id.to_hex(),
            client_name: view.client_name,
            assigned_at: a.assigned_at.try_to_rfc3339_string().unwrap_or_default(),
        }
    }
}

/// HU-19 — POST /api/v1/coach/routines/{id}/assignments. Asigna una rutina propia a uno o varios clientes.
#[utoipa::path(
    post,
    path = "/coach/routines/{id}/assignments",
    tag = "Rutinas",
    summary = "Asigna una rutina a uno o varios clientes (HU-19)",
    description = "Todo o nada: si algún cliente no tiene vinculación activa con el coach (RN-04) no se asigna a ninguno. Un cliente que ya tiene la rutina asignada no se duplica: aparece con su fecha de asignación original. Devuelve la asignación de cada cliente pedido, en el orden de `client_ids`. Una rutina ajena responde 404 antes de validar el cuerpo.",
    security(("bearer_auth" = ["coach"])),
    params(("id" = String, Path, description = "Id de la rutina")),
    request_body = AssignRoutineRequest,
    responses(
        (status = 201, description = "Asignaciones activas de los clientes pedidos", body = [RoutineAssignmentResponse]),
        (status = 400, description = "`VALIDATION_ERROR` (`client_ids` ausente, vacío, no es lista o tiene más de 50; `client_ids[i]` mal formado) o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`) o `CLIENT_NOT_LINKED` (`fields` señala cada `client_ids[i]` sin vinculación activa; no se asigna a ninguno)", body = ErrorResponse),
        (status = 404, description = "`ROUTINE_NOT_FOUND` (no existe, id mal formado o es de otro coach)", body = ErrorResponse),
    )
)]
pub async fn assign_routine_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
    Path(id): Path<String>,
    ApiJson(body): ApiJson<AssignRoutineRequest>,
) -> Result<(StatusCode, Json<Vec<RoutineAssignmentResponse>>), AppError> {
    let views =
        routine_assignments::assign_routine(&state.db, auth.user_id, &id, body.client_ids).await?;
    Ok((
        StatusCode::CREATED,
        Json(views.into_iter().map(Into::into).collect()),
    ))
}

/// HU-19 — GET /api/v1/coach/routines/{id}/assignments. Clientes con la rutina asignada.
#[utoipa::path(
    get,
    path = "/coach/routines/{id}/assignments",
    tag = "Rutinas",
    summary = "Clientes con la rutina asignada (HU-19)",
    description = "Solo asignaciones activas de clientes que siguen vinculados (RN-04), la más reciente primero. Sin asignaciones devuelve una lista vacía.",
    security(("bearer_auth" = ["coach"])),
    params(("id" = String, Path, description = "Id de la rutina")),
    responses(
        (status = 200, description = "Asignaciones activas", body = [RoutineAssignmentResponse]),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
        (status = 404, description = "`ROUTINE_NOT_FOUND` (no existe, id mal formado o es de otro coach)", body = ErrorResponse),
    )
)]
pub async fn list_assignments_handler(
    State(state): State<AppState>,
    CoachOnly(auth): CoachOnly,
    Path(id): Path<String>,
) -> Result<Json<Vec<RoutineAssignmentResponse>>, AppError> {
    let views = routine_assignments::list_assignments(&state.db, auth.user_id, &id).await?;
    Ok(Json(views.into_iter().map(Into::into).collect()))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/coach/routines",
            get(list_routines_handler).post(create_routine_handler),
        )
        .route(
            "/coach/routines/:id",
            get(get_routine_handler)
                .put(update_routine_handler)
                .delete(delete_routine_handler),
        )
        .route(
            "/coach/routines/:id/assignments",
            get(list_assignments_handler).post(assign_routine_handler),
        )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::MuscleGroup;
    use mongodb::bson::{DateTime, oid::ObjectId};

    #[test]
    fn routine_response_serializa_ejercicios_y_fechas() {
        let now = DateTime::now();
        let exercise_id = ObjectId::new();
        let routine = Routine {
            id: ObjectId::new(),
            coach_id: ObjectId::new(),
            name: "Torso A".into(),
            exercises: vec![RoutineExercise {
                exercise_id,
                name: "Press de banca con mancuernas".into(),
                muscle_group: MuscleGroup::Chest,
                sets: 4,
                reps: 10,
                rest_seconds: 90,
            }],
            created_at: now,
            updated_at: now,
        };
        let json = serde_json::to_value(RoutineResponse::from(routine.clone())).unwrap();
        assert_eq!(json["id"], routine.id.to_hex());
        assert!(json.get("coach_id").is_none(), "no expone el coach");
        assert_eq!(
            json["exercises"][0],
            serde_json::json!({
                "exercise_id": exercise_id.to_hex(),
                "name": "Press de banca con mancuernas",
                "muscle_group": "chest",
                "sets": 4,
                "reps": 10,
                "rest_seconds": 90,
            })
        );
        assert_eq!(json["created_at"], now.try_to_rfc3339_string().unwrap());
    }

    #[test]
    fn assignment_response_trae_cliente_y_fecha_sin_exponer_al_coach() {
        use crate::models::routine_assignment::{AssignmentStatus, RoutineAssignment};
        let now = DateTime::now();
        let assignment = RoutineAssignment {
            id: ObjectId::new(),
            routine_id: ObjectId::new(),
            coach_id: ObjectId::new(),
            client_id: ObjectId::new(),
            status: AssignmentStatus::Active,
            assigned_at: now,
            updated_at: now,
            removed_at: None,
        };
        let json = serde_json::to_value(RoutineAssignmentResponse::from(AssignmentView {
            assignment: assignment.clone(),
            client_name: "Ana".into(),
        }))
        .unwrap();
        assert_eq!(
            json,
            serde_json::json!({
                "id": assignment.id.to_hex(),
                "routine_id": assignment.routine_id.to_hex(),
                "client_id": assignment.client_id.to_hex(),
                "client_name": "Ana",
                "assigned_at": now.try_to_rfc3339_string().unwrap(),
            })
        );
    }
}
