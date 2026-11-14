//! HU-17 — registro y consulta de las sesiones completadas de una rutina del usuario (RF-16, RF-24).
//!
//! - Solo de una rutina accesible para el usuario (`find_user_routine`): la recomendada vigente (HU-15) o una
//!   asignada activa de un coach con el que sigue vinculado (HU-19, RN-04). Ajena, retirada, inexistente o con id
//!   mal formado → `ROUTINE_NOT_FOUND`.
//! - `session_number` debe existir en la rutina; `date` es opcional (hoy en `APP_UTC_OFFSET`) y no puede ser futura.
//! - Una sola por usuario, rutina, sesión y día (índice único en `db.rs`) → `SESSION_ALREADY_COMPLETED`.
//! - La sesión guarda copia de los nombres y nunca se borra con la rutina (RF-24). HU-22-API la lee por `user_id`
//!   y `date` para el cumplimiento semanal (`models/routine_session.rs`).

use chrono::{FixedOffset, NaiveDate, Utc};
use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
};
use serde_json::Value;

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::recommended_routine::{RECOMMENDED_ROUTINES_COLLECTION, RecommendedRoutine};
use crate::models::routine::{ROUTINES_COLLECTION, Routine};
use crate::models::routine_assignment::{ROUTINE_ASSIGNMENTS_COLLECTION, RoutineAssignment};
use crate::models::routine_session::{ROUTINE_SESSIONS_COLLECTION, RoutineOrigin, RoutineSession};
use crate::services::auth::is_duplicate_key;
use crate::validation::{DATE_FORMAT, parse_date};

/// Número de la única sesión de una rutina asignada por un coach.
pub const ASSIGNED_SESSION_NUMBER: i32 = 1;

const SESSION_NUMBER_REQUIRED: &str = "Indica el número de la sesión";
const SESSION_NUMBER_INVALID: &str = "El número de sesión debe ser un entero";
const SESSION_NUMBER_NOT_IN_ROUTINE: &str = "La rutina no tiene esa sesión";
const DATE_INVALID: &str = "La fecha debe tener el formato YYYY-MM-DD";
const DATE_IN_FUTURE: &str = "La fecha no puede ser futura";

/// Sesión de una rutina: su número y su nombre.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionRef {
    pub number: i32,
    pub name: String,
}

/// Rutina accesible para el usuario, con lo que HU-17 necesita para registrar una sesión.
///
/// Es el punto de acople con HU-15-API (recomendada) y HU-16-API (`GET /routines/{id}` usa la misma comprobación de
/// acceso): cada origen arma esta vista con sus datos.
#[derive(Debug, Clone, PartialEq)]
pub struct UserRoutine {
    pub id: ObjectId,
    pub origin: RoutineOrigin,
    pub name: String,
    /// Solo con origen `coach`.
    pub coach_id: Option<ObjectId>,
    /// Solo con origen `coach`.
    pub assignment_id: Option<ObjectId>,
    /// Sesiones numeradas de la rutina (una sola, la 1, en las asignadas).
    pub sessions: Vec<SessionRef>,
}

impl UserRoutine {
    /// Vista de una rutina del coach asignada al usuario: una sola sesión, la 1, con el nombre de la rutina.
    pub fn from_assigned(routine: &Routine, assignment: &RoutineAssignment) -> Self {
        Self {
            id: routine.id,
            origin: RoutineOrigin::Coach,
            name: routine.name.clone(),
            coach_id: Some(routine.coach_id),
            assignment_id: Some(assignment.id),
            sessions: vec![SessionRef {
                number: ASSIGNED_SESSION_NUMBER,
                name: routine.name.clone(),
            }],
        }
    }

    /// Vista de un documento de `recommended_routines` (HU-15): sus sesiones numeradas con su nombre.
    pub fn from_recommended_routine(routine: &RecommendedRoutine) -> Self {
        Self::from_recommended(
            routine.id,
            routine.name.clone(),
            routine.sessions.iter().map(|session| SessionRef {
                number: session.number,
                name: session.name.clone(),
            }),
        )
    }

    /// Vista de la rutina recomendada (origen `system`): sus sesiones numeradas tal como las guardó HU-15-API.
    pub fn from_recommended(
        id: ObjectId,
        name: impl Into<String>,
        sessions: impl IntoIterator<Item = SessionRef>,
    ) -> Self {
        Self {
            id,
            origin: RoutineOrigin::System,
            name: name.into(),
            coach_id: None,
            assignment_id: None,
            sessions: sessions.into_iter().collect(),
        }
    }
}

/// Sesión a registrar ya validada.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidSession {
    pub session: SessionRef,
    pub date: NaiveDate,
}

// ───────────────────────── Funciones puras ─────────────────────────

/// Valida el cuerpo de `POST /users/me/routines/{id}/sessions` contra la rutina, todos los campos a la vez.
///
/// - `session_number`: obligatorio, entero y una de las sesiones de la rutina.
/// - `date`: opcional (`null` o ausente = `today`), `YYYY-MM-DD` y no posterior a `today`.
pub fn validate_session_input(
    session_number: Option<&Value>,
    date: Option<&Value>,
    routine: &UserRoutine,
    today: NaiveDate,
) -> Result<ValidSession, AppError> {
    let mut errors = FieldErrors::new();

    let session = match session_number.filter(|value| !value.is_null()) {
        None => {
            errors.insert("session_number".into(), SESSION_NUMBER_REQUIRED.into());
            None
        }
        Some(value) => match value.as_i64() {
            None => {
                errors.insert("session_number".into(), SESSION_NUMBER_INVALID.into());
                None
            }
            Some(number) => {
                let found = routine
                    .sessions
                    .iter()
                    .find(|session| i64::from(session.number) == number);
                if found.is_none() {
                    errors.insert(
                        "session_number".into(),
                        SESSION_NUMBER_NOT_IN_ROUTINE.into(),
                    );
                }
                found.cloned()
            }
        },
    };

    let date = match date.filter(|value| !value.is_null()) {
        None => Some(today),
        Some(value) => match value.as_str().map(str::trim).and_then(parse_date) {
            None => {
                errors.insert("date".into(), DATE_INVALID.into());
                None
            }
            Some(date) if date > today => {
                errors.insert("date".into(), DATE_IN_FUTURE.into());
                None
            }
            Some(date) => Some(date),
        },
    };

    match (session, date) {
        (Some(session), Some(date)) if errors.is_empty() => Ok(ValidSession { session, date }),
        _ => Err(AppError::Validation(errors)),
    }
}

/// Día de hoy en la zona horaria de la app.
pub fn today_in(offset: FixedOffset) -> NaiveDate {
    Utc::now().with_timezone(&offset).date_naive()
}

/// Documento a guardar para la sesión validada de la rutina.
pub fn build_session(
    user_id: ObjectId,
    routine: &UserRoutine,
    valid: ValidSession,
    completed_at: DateTime,
) -> RoutineSession {
    RoutineSession {
        id: ObjectId::new(),
        user_id,
        routine_id: routine.id,
        origin: routine.origin,
        coach_id: routine.coach_id,
        assignment_id: routine.assignment_id,
        routine_name: routine.name.clone(),
        session_number: valid.session.number,
        session_name: valid.session.name,
        date: valid.date.format(DATE_FORMAT).to_string(),
        completed_at,
    }
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn sessions(db: &Database) -> Collection<RoutineSession> {
    db.collection(ROUTINE_SESSIONS_COLLECTION)
}

/// Rutina asignada activa del usuario, si su coach sigue vinculado con él (RN-04).
async fn find_assigned_routine(
    db: &Database,
    user_id: ObjectId,
    routine_id: ObjectId,
) -> Result<Option<UserRoutine>, AppError> {
    let Some(assignment) = db
        .collection::<RoutineAssignment>(ROUTINE_ASSIGNMENTS_COLLECTION)
        .find_one(doc! { "routine_id": routine_id, "client_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?
    else {
        return Ok(None);
    };
    let linked = db
        .collection::<CoachLink>(COACH_LINKS_COLLECTION)
        .find_one(doc! { "coach_id": assignment.coach_id, "user_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?
        .is_some();
    if !linked {
        return Ok(None);
    }
    let routine = db
        .collection::<Routine>(ROUTINES_COLLECTION)
        .find_one(doc! { "_id": routine_id, "coach_id": assignment.coach_id })
        .await
        .map_err(AppError::internal)?;
    Ok(routine.map(|routine| UserRoutine::from_assigned(&routine, &assignment)))
}

/// Rutina recomendada vigente del usuario con ese id (origen `system`, HU-15).
/// Una recomendada reemplazada (`replaced`, al regenerar) ya no es accesible: responde 404, pero sus sesiones
/// completadas se conservan.
async fn find_recommended_routine(
    db: &Database,
    user_id: ObjectId,
    routine_id: ObjectId,
) -> Result<Option<UserRoutine>, AppError> {
    let routine = db
        .collection::<RecommendedRoutine>(RECOMMENDED_ROUTINES_COLLECTION)
        .find_one(doc! { "_id": routine_id, "user_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?;
    Ok(routine.as_ref().map(UserRoutine::from_recommended_routine))
}

/// Rutina accesible para el usuario: la recomendada vigente o una asignada activa (HU-17; misma comprobación que
/// `GET /routines/{id}` de HU-16-API). Ajena, retirada, inexistente o con id mal formado → `ROUTINE_NOT_FOUND`.
pub async fn find_user_routine(
    db: &Database,
    user_id: ObjectId,
    routine_id: &str,
) -> Result<UserRoutine, AppError> {
    let routine_id = ObjectId::parse_str(routine_id).map_err(|_| AppError::RoutineNotFound)?;
    if let Some(routine) = find_assigned_routine(db, user_id, routine_id).await? {
        return Ok(routine);
    }
    find_recommended_routine(db, user_id, routine_id)
        .await?
        .ok_or(AppError::RoutineNotFound)
}

/// HU-17 — registra como completada una sesión de una rutina del usuario.
///
/// Orden de las comprobaciones: rutina accesible (404) → cuerpo (400) → sesión repetida ese día (409).
pub async fn complete_session(
    db: &Database,
    user_id: ObjectId,
    offset: FixedOffset,
    routine_id: &str,
    session_number: Option<Value>,
    date: Option<Value>,
) -> Result<RoutineSession, AppError> {
    let routine = find_user_routine(db, user_id, routine_id).await?;
    let valid = validate_session_input(
        session_number.as_ref(),
        date.as_ref(),
        &routine,
        today_in(offset),
    )?;
    let session = build_session(user_id, &routine, valid, DateTime::now());
    match sessions(db).insert_one(&session).await {
        Ok(_) => Ok(session),
        Err(e) if is_duplicate_key(&e) => Err(AppError::SessionAlreadyCompleted),
        Err(e) => Err(AppError::internal(e)),
    }
}

/// HU-17 — sesiones completadas de una rutina del usuario, la más reciente primero.
pub async fn list_sessions(
    db: &Database,
    user_id: ObjectId,
    routine_id: &str,
) -> Result<Vec<RoutineSession>, AppError> {
    let routine = find_user_routine(db, user_id, routine_id).await?;
    let cursor = sessions(db)
        .find(doc! { "user_id": user_id, "routine_id": routine.id })
        .sort(doc! { "date": -1, "completed_at": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::MuscleGroup;
    use crate::models::routine::RoutineExercise;
    use crate::models::routine_assignment::AssignmentStatus;
    use serde_json::json;

    fn day(value: &str) -> NaiveDate {
        parse_date(value).unwrap()
    }

    fn recommended() -> UserRoutine {
        UserRoutine::from_recommended(
            ObjectId::new(),
            "Rutina recomendada · Hipertrofia · 3 días",
            [
                SessionRef {
                    number: 1,
                    name: "Día 1 · Cuerpo completo".into(),
                },
                SessionRef {
                    number: 2,
                    name: "Día 2 · Cuerpo completo".into(),
                },
                SessionRef {
                    number: 3,
                    name: "Día 3 · Cuerpo completo".into(),
                },
            ],
        )
    }

    fn assigned() -> (Routine, RoutineAssignment, UserRoutine) {
        let now = DateTime::now();
        let routine = Routine {
            id: ObjectId::new(),
            coach_id: ObjectId::new(),
            name: "Torso A".into(),
            exercises: vec![RoutineExercise {
                exercise_id: ObjectId::new(),
                name: "Press de banca".into(),
                muscle_group: MuscleGroup::Chest,
                sets: 3,
                reps: 10,
                rest_seconds: 60,
            }],
            created_at: now,
            updated_at: now,
        };
        let assignment = RoutineAssignment {
            id: ObjectId::new(),
            routine_id: routine.id,
            coach_id: routine.coach_id,
            client_id: ObjectId::new(),
            status: AssignmentStatus::Active,
            assigned_at: now,
            updated_at: now,
            removed_at: None,
        };
        let view = UserRoutine::from_assigned(&routine, &assignment);
        (routine, assignment, view)
    }

    fn fields(result: Result<ValidSession, AppError>) -> FieldErrors {
        match result {
            Err(AppError::Validation(fields)) => fields,
            other => panic!("se esperaba error de validación, llegó {other:?}"),
        }
    }

    #[test]
    fn rutina_recomendada_de_hu15_expone_sus_sesiones_numeradas() {
        use crate::models::exercise::ExerciseLevel;
        use crate::models::profile::{Level, Objective};
        use crate::models::recommended_routine::{
            RecommendedExercise, RecommendedSession, RecommendedStatus,
        };
        let session = |number: i32, name: &str| RecommendedSession {
            number,
            name: name.into(),
            focus: "upper".into(),
            exercises: vec![RecommendedExercise {
                exercise_id: ObjectId::new(),
                name: "Remo".into(),
                muscle_group: MuscleGroup::Back,
                equipment: "dumbbell".into(),
                level: ExerciseLevel::Beginner,
                sets: 3,
                reps: 12,
                rest_seconds: 60,
            }],
        };
        let routine = RecommendedRoutine {
            id: ObjectId::new(),
            user_id: ObjectId::new(),
            origin: RoutineOrigin::System,
            name: "Rutina recomendada · Mantener · 2 días".into(),
            objective: Objective::Maintain,
            level: Level::Beginner,
            training_days: 2,
            sessions: vec![session(1, "Día 1 · Torso"), session(2, "Día 2 · Pierna")],
            status: RecommendedStatus::Active,
            created_at: DateTime::now(),
            replaced_at: None,
        };
        let view = UserRoutine::from_recommended_routine(&routine);
        assert_eq!(view.id, routine.id);
        assert_eq!(view.origin, RoutineOrigin::System);
        assert_eq!(view.name, routine.name);
        assert_eq!(view.coach_id, None);
        assert_eq!(view.assignment_id, None);
        assert_eq!(
            view.sessions,
            vec![
                SessionRef {
                    number: 1,
                    name: "Día 1 · Torso".into()
                },
                SessionRef {
                    number: 2,
                    name: "Día 2 · Pierna".into()
                },
            ]
        );
    }

    #[test]
    fn rutina_asignada_tiene_una_sola_sesion_con_el_nombre_de_la_rutina() {
        let (routine, assignment, view) = assigned();
        assert_eq!(view.origin, RoutineOrigin::Coach);
        assert_eq!(view.coach_id, Some(routine.coach_id));
        assert_eq!(view.assignment_id, Some(assignment.id));
        assert_eq!(
            view.sessions,
            vec![SessionRef {
                number: 1,
                name: "Torso A".into()
            }]
        );
    }

    #[test]
    fn sin_fecha_se_registra_hoy() {
        let today = day("2026-11-06");
        let valid = validate_session_input(Some(&json!(2)), None, &recommended(), today).unwrap();
        assert_eq!(valid.session.number, 2);
        assert_eq!(valid.session.name, "Día 2 · Cuerpo completo");
        assert_eq!(valid.date, today);

        let null_date =
            validate_session_input(Some(&json!(1)), Some(&json!(null)), &recommended(), today)
                .unwrap();
        assert_eq!(null_date.date, today);
    }

    #[test]
    fn acepta_hoy_y_fechas_pasadas() {
        let today = day("2026-11-06");
        for value in ["2026-11-06", "2026-11-01", " 2025-12-31 "] {
            let valid =
                validate_session_input(Some(&json!(1)), Some(&json!(value)), &recommended(), today)
                    .unwrap();
            assert_eq!(valid.date, day(value.trim()));
        }
    }

    #[test]
    fn fecha_futura_se_rechaza() {
        let errors = fields(validate_session_input(
            Some(&json!(1)),
            Some(&json!("2026-11-07")),
            &recommended(),
            day("2026-11-06"),
        ));
        assert_eq!(errors.get("date").map(String::as_str), Some(DATE_IN_FUTURE));
        assert!(!errors.contains_key("session_number"));
    }

    #[test]
    fn fecha_con_formato_invalido_se_rechaza() {
        for value in [
            json!("06/11/2026"),
            json!("2026-13-01"),
            json!(20261106),
            json!(""),
        ] {
            let errors = fields(validate_session_input(
                Some(&json!(1)),
                Some(&value),
                &recommended(),
                day("2026-11-06"),
            ));
            assert_eq!(
                errors.get("date").map(String::as_str),
                Some(DATE_INVALID),
                "{value}"
            );
        }
    }

    #[test]
    fn numero_de_sesion_que_no_existe_en_la_rutina_se_rechaza() {
        let today = day("2026-11-06");
        for number in [0, 4, -1] {
            let errors = fields(validate_session_input(
                Some(&json!(number)),
                None,
                &recommended(),
                today,
            ));
            assert_eq!(
                errors.get("session_number").map(String::as_str),
                Some(SESSION_NUMBER_NOT_IN_ROUTINE)
            );
        }
        let (_, _, view) = assigned();
        let errors = fields(validate_session_input(Some(&json!(2)), None, &view, today));
        assert_eq!(
            errors.get("session_number").map(String::as_str),
            Some(SESSION_NUMBER_NOT_IN_ROUTINE),
            "la asignada solo tiene la sesión 1"
        );
    }

    #[test]
    fn numero_de_sesion_ausente_o_no_entero_se_rechaza() {
        let today = day("2026-11-06");
        let errors = fields(validate_session_input(None, None, &recommended(), today));
        assert_eq!(
            errors.get("session_number").map(String::as_str),
            Some(SESSION_NUMBER_REQUIRED)
        );
        for value in [json!("1"), json!(1.5), json!(true)] {
            let errors = fields(validate_session_input(
                Some(&value),
                None,
                &recommended(),
                today,
            ));
            assert_eq!(
                errors.get("session_number").map(String::as_str),
                Some(SESSION_NUMBER_INVALID),
                "{value}"
            );
        }
    }

    #[test]
    fn senala_todos_los_campos_invalidos_a_la_vez() {
        let errors = fields(validate_session_input(
            Some(&json!(9)),
            Some(&json!("2030-01-01")),
            &recommended(),
            day("2026-11-06"),
        ));
        assert_eq!(errors.len(), 2);
        assert!(errors.contains_key("session_number"));
        assert!(errors.contains_key("date"));
    }

    #[test]
    fn la_sesion_guarda_copia_de_los_nombres_y_el_origen() {
        let (routine, assignment, view) = assigned();
        let user_id = assignment.client_id;
        let valid =
            validate_session_input(Some(&json!(1)), None, &view, day("2026-11-06")).unwrap();
        let session = build_session(user_id, &view, valid, DateTime::now());
        assert_eq!(session.user_id, user_id);
        assert_eq!(session.routine_id, routine.id);
        assert_eq!(session.origin, RoutineOrigin::Coach);
        assert_eq!(session.coach_id, Some(routine.coach_id));
        assert_eq!(session.assignment_id, Some(assignment.id));
        assert_eq!(session.routine_name, "Torso A");
        assert_eq!(session.session_name, "Torso A");
        assert_eq!(session.session_number, 1);
        assert_eq!(session.date, "2026-11-06");

        let system = recommended();
        let valid =
            validate_session_input(Some(&json!(3)), None, &system, day("2026-11-06")).unwrap();
        let session = build_session(user_id, &system, valid, DateTime::now());
        assert_eq!(session.origin, RoutineOrigin::System);
        assert_eq!(session.coach_id, None);
        assert_eq!(session.assignment_id, None);
        assert_eq!(session.session_name, "Día 3 · Cuerpo completo");
    }

    #[test]
    fn el_dia_de_hoy_se_toma_en_la_zona_de_la_app() {
        let mexico = FixedOffset::east_opt(-6 * 3600).unwrap();
        let utc = FixedOffset::east_opt(0).unwrap();
        let diff = (today_in(utc) - today_in(mexico)).num_days();
        assert!((0..=1).contains(&diff));
    }
}
