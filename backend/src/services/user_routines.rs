//! HU-16 — rutinas del usuario con su origen (RF-15, RF-23, RN-08): lista y detalle.
//!
//! - La lista une la rutina recomendada vigente (HU-15, origen `system`) y las asignadas activas (HU-19, origen
//!   `coach`) de un coach con el que el usuario sigue vinculado (RN-04). Se consulta sin caché: una asignación nueva
//!   aparece en la siguiente consulta y una retirada deja de aparecer (RF-23).
//! - El detalle usa la misma comprobación de acceso que HU-17 (`routine_sessions::find_user_routine`) y después lee la
//!   rutina completa. Una rutina del coach se presenta como una sola sesión, la 1, con el nombre de la rutina.

use std::collections::HashMap;

use mongodb::{
    Database,
    bson::{doc, oid::ObjectId},
};

use crate::db::collect_cursor;
use crate::error::AppError;
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::exercise::MuscleGroup;
use crate::models::recommended_routine::{
    RECOMMENDED_ROUTINES_COLLECTION, RecommendedRoutine, RoutineOrigin,
};
use crate::models::routine::{ROUTINES_COLLECTION, Routine};
use crate::models::routine_assignment::{ROUTINE_ASSIGNMENTS_COLLECTION, RoutineAssignment};
use crate::models::user::{USERS_COLLECTION, User};
use crate::services::routine_sessions::{ASSIGNED_SESSION_NUMBER, find_user_routine};

/// Elemento de la lista de rutinas del usuario.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RoutineSummary {
    pub id: ObjectId,
    pub origin: RoutineOrigin,
    pub name: String,
    /// Solo con origen `coach`.
    pub coach_name: Option<String>,
    pub session_count: usize,
}

/// Ejercicio del detalle, igual para los dos orígenes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DetailExercise {
    pub exercise_id: ObjectId,
    pub name: String,
    pub muscle_group: MuscleGroup,
    pub sets: i32,
    pub reps: i32,
    pub rest_seconds: i32,
}

/// Sesión numerada del detalle.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DetailSession {
    pub number: i32,
    pub name: String,
    pub exercises: Vec<DetailExercise>,
}

/// Detalle de una rutina del usuario con la forma común de los dos orígenes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RoutineDetail {
    pub id: ObjectId,
    pub origin: RoutineOrigin,
    pub name: String,
    /// Solo con origen `coach`.
    pub coach_name: Option<String>,
    pub sessions: Vec<DetailSession>,
}

// ───────────────────────── Funciones puras ─────────────────────────

/// Lista del usuario: primero la recomendada vigente y después las asignadas activas, la asignada más recientemente
/// primero. Una asignación solo aparece si su coach es `linked_coach` (vinculación activa, RN-04) y su rutina existe.
pub fn build_routine_list(
    recommended: Option<&RecommendedRoutine>,
    assignments: &[RoutineAssignment],
    linked_coach: Option<ObjectId>,
    routines: &[Routine],
    coach_names: &HashMap<ObjectId, String>,
) -> Vec<RoutineSummary> {
    let mut list: Vec<RoutineSummary> = recommended
        .map(|r| RoutineSummary {
            id: r.id,
            origin: RoutineOrigin::System,
            name: r.name.clone(),
            coach_name: None,
            session_count: r.sessions.len(),
        })
        .into_iter()
        .collect();

    let mut assigned: Vec<&RoutineAssignment> = assignments
        .iter()
        .filter(|a| Some(a.coach_id) == linked_coach)
        .collect();
    assigned.sort_by(|a, b| {
        b.assigned_at
            .cmp(&a.assigned_at)
            .then_with(|| b.id.cmp(&a.id))
    });
    list.extend(assigned.into_iter().filter_map(|a| {
        let routine = routines
            .iter()
            .find(|r| r.id == a.routine_id && r.coach_id == a.coach_id)?;
        Some(RoutineSummary {
            id: routine.id,
            origin: RoutineOrigin::Coach,
            name: routine.name.clone(),
            coach_name: coach_names.get(&a.coach_id).cloned(),
            session_count: 1,
        })
    }));
    list
}

/// Detalle de la rutina recomendada (HU-15): sus sesiones numeradas tal como se guardaron.
pub fn detail_from_recommended(routine: &RecommendedRoutine) -> RoutineDetail {
    RoutineDetail {
        id: routine.id,
        origin: RoutineOrigin::System,
        name: routine.name.clone(),
        coach_name: None,
        sessions: routine
            .sessions
            .iter()
            .map(|session| DetailSession {
                number: session.number,
                name: session.name.clone(),
                exercises: session
                    .exercises
                    .iter()
                    .map(|e| DetailExercise {
                        exercise_id: e.exercise_id,
                        name: e.name.clone(),
                        muscle_group: e.muscle_group,
                        sets: e.sets,
                        reps: e.reps,
                        rest_seconds: e.rest_seconds,
                    })
                    .collect(),
            })
            .collect(),
    }
}

/// Detalle de una rutina del coach: una sola sesión, la 1, con el nombre de la rutina y todos sus ejercicios.
pub fn detail_from_assigned(routine: &Routine, coach_name: Option<String>) -> RoutineDetail {
    RoutineDetail {
        id: routine.id,
        origin: RoutineOrigin::Coach,
        name: routine.name.clone(),
        coach_name,
        sessions: vec![DetailSession {
            number: ASSIGNED_SESSION_NUMBER,
            name: routine.name.clone(),
            exercises: routine
                .exercises
                .iter()
                .map(|e| DetailExercise {
                    exercise_id: e.exercise_id,
                    name: e.name.clone(),
                    muscle_group: e.muscle_group,
                    sets: e.sets,
                    reps: e.reps,
                    rest_seconds: e.rest_seconds,
                })
                .collect(),
        }],
    }
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

/// HU-16 — `GET /users/me/routines`: rutinas del usuario con su origen; sin rutinas, lista vacía.
pub async fn list_user_routines(
    db: &Database,
    user_id: ObjectId,
) -> Result<Vec<RoutineSummary>, AppError> {
    let recommended = db
        .collection::<RecommendedRoutine>(RECOMMENDED_ROUTINES_COLLECTION)
        .find_one(doc! { "user_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?;

    // Un usuario tiene como máximo una vinculación activa (HU-13): solo cuentan las asignaciones de ese coach.
    let linked_coach = db
        .collection::<CoachLink>(COACH_LINKS_COLLECTION)
        .find_one(doc! { "user_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?
        .map(|link| link.coach_id);

    let (assignments, routines, coach_names) = match linked_coach {
        None => (Vec::new(), Vec::new(), HashMap::new()),
        Some(coach_id) => {
            let cursor = db
                .collection::<RoutineAssignment>(ROUTINE_ASSIGNMENTS_COLLECTION)
                .find(doc! { "client_id": user_id, "coach_id": coach_id, "status": "active" })
                .await
                .map_err(AppError::internal)?;
            let assignments: Vec<RoutineAssignment> = collect_cursor(cursor).await?;
            let ids: Vec<ObjectId> = assignments.iter().map(|a| a.routine_id).collect();
            let routines = if ids.is_empty() {
                Vec::new()
            } else {
                let cursor = db
                    .collection::<Routine>(ROUTINES_COLLECTION)
                    .find(doc! { "_id": { "$in": ids }, "coach_id": coach_id })
                    .await
                    .map_err(AppError::internal)?;
                collect_cursor(cursor).await?
            };
            let names = coach_name(db, coach_id)
                .await?
                .map(|name| HashMap::from([(coach_id, name)]))
                .unwrap_or_default();
            (assignments, routines, names)
        }
    };

    Ok(build_routine_list(
        recommended.as_ref(),
        &assignments,
        linked_coach,
        &routines,
        &coach_names,
    ))
}

async fn coach_name(db: &Database, coach_id: ObjectId) -> Result<Option<String>, AppError> {
    Ok(db
        .collection::<User>(USERS_COLLECTION)
        .find_one(doc! { "_id": coach_id })
        .await
        .map_err(AppError::internal)?
        .map(|user| user.name))
}

/// HU-16 — `GET /routines/{id}`: detalle de una rutina accesible para el usuario.
/// Ajena, retirada, reemplazada, inexistente o con id mal formado → `ROUTINE_NOT_FOUND`.
pub async fn get_user_routine(
    db: &Database,
    user_id: ObjectId,
    routine_id: &str,
) -> Result<RoutineDetail, AppError> {
    // Misma comprobación de acceso que HU-17: recomendada vigente o asignada activa con coach vinculado.
    let access = find_user_routine(db, user_id, routine_id).await?;
    match access.origin {
        RoutineOrigin::System => db
            .collection::<RecommendedRoutine>(RECOMMENDED_ROUTINES_COLLECTION)
            .find_one(doc! { "_id": access.id, "user_id": user_id, "status": "active" })
            .await
            .map_err(AppError::internal)?
            .map(|routine| detail_from_recommended(&routine))
            .ok_or(AppError::RoutineNotFound),
        RoutineOrigin::Coach => {
            let coach_id = access.coach_id.ok_or(AppError::RoutineNotFound)?;
            let routine = db
                .collection::<Routine>(ROUTINES_COLLECTION)
                .find_one(doc! { "_id": access.id, "coach_id": coach_id })
                .await
                .map_err(AppError::internal)?
                .ok_or(AppError::RoutineNotFound)?;
            Ok(detail_from_assigned(
                &routine,
                coach_name(db, coach_id).await?,
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::ExerciseLevel;
    use crate::models::profile::{Level, Objective};
    use crate::models::recommended_routine::{
        RecommendedExercise, RecommendedSession, RecommendedStatus,
    };
    use crate::models::routine::RoutineExercise;
    use crate::models::routine_assignment::AssignmentStatus;
    use mongodb::bson::DateTime;

    fn recommended(user_id: ObjectId, days: i32) -> RecommendedRoutine {
        RecommendedRoutine {
            id: ObjectId::new(),
            user_id,
            origin: RoutineOrigin::System,
            name: format!("Rutina recomendada · Mantener · {days} días"),
            objective: Objective::Maintain,
            level: Level::Beginner,
            training_days: days,
            sessions: (1..=days)
                .map(|number| RecommendedSession {
                    number,
                    name: format!("Día {number} · Cuerpo completo"),
                    focus: "full_body".into(),
                    exercises: vec![RecommendedExercise {
                        exercise_id: ObjectId::new(),
                        name: "Sentadilla".into(),
                        muscle_group: MuscleGroup::Legs,
                        equipment: "bodyweight".into(),
                        level: ExerciseLevel::Beginner,
                        sets: 2,
                        reps: 12,
                        rest_seconds: 60,
                    }],
                })
                .collect(),
            status: RecommendedStatus::Active,
            created_at: DateTime::from_millis(0),
            replaced_at: None,
        }
    }

    fn routine(coach_id: ObjectId, name: &str, exercises: usize) -> Routine {
        Routine {
            id: ObjectId::new(),
            coach_id,
            name: name.into(),
            exercises: (0..exercises)
                .map(|i| RoutineExercise {
                    exercise_id: ObjectId::new(),
                    name: format!("Ejercicio {i}"),
                    muscle_group: MuscleGroup::Chest,
                    sets: 4,
                    reps: 10,
                    rest_seconds: 90,
                })
                .collect(),
            created_at: DateTime::from_millis(0),
            updated_at: DateTime::from_millis(0),
        }
    }

    fn assignment(routine: &Routine, client_id: ObjectId, assigned_ms: i64) -> RoutineAssignment {
        RoutineAssignment {
            id: ObjectId::new(),
            routine_id: routine.id,
            coach_id: routine.coach_id,
            client_id,
            status: AssignmentStatus::Active,
            assigned_at: DateTime::from_millis(assigned_ms),
            updated_at: DateTime::from_millis(assigned_ms),
            removed_at: None,
        }
    }

    #[test]
    fn lista_la_recomendada_primero_y_despues_las_asignadas_mas_recientes() {
        let user = ObjectId::new();
        let coach = ObjectId::new();
        let rec = recommended(user, 3);
        let torso = routine(coach, "Torso A", 2);
        let pierna = routine(coach, "Pierna B", 1);
        let assignments = [
            assignment(&torso, user, 1_000),
            assignment(&pierna, user, 2_000),
        ];
        let names = HashMap::from([(coach, "Carlos".to_string())]);

        let list = build_routine_list(
            Some(&rec),
            &assignments,
            Some(coach),
            &[torso.clone(), pierna.clone()],
            &names,
        );
        assert_eq!(
            list,
            vec![
                RoutineSummary {
                    id: rec.id,
                    origin: RoutineOrigin::System,
                    name: rec.name.clone(),
                    coach_name: None,
                    session_count: 3,
                },
                RoutineSummary {
                    id: pierna.id,
                    origin: RoutineOrigin::Coach,
                    name: "Pierna B".into(),
                    coach_name: Some("Carlos".into()),
                    session_count: 1,
                },
                RoutineSummary {
                    id: torso.id,
                    origin: RoutineOrigin::Coach,
                    name: "Torso A".into(),
                    coach_name: Some("Carlos".into()),
                    session_count: 1,
                },
            ]
        );
    }

    #[test]
    fn sin_rutinas_la_lista_esta_vacia_y_solo_con_recomendada_tiene_una() {
        assert!(build_routine_list(None, &[], None, &[], &HashMap::new()).is_empty());
        let rec = recommended(ObjectId::new(), 5);
        let list = build_routine_list(Some(&rec), &[], None, &[], &HashMap::new());
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].origin, RoutineOrigin::System);
        assert_eq!(list[0].session_count, 5);
    }

    #[test]
    fn omite_asignaciones_de_un_coach_no_vinculado_o_de_rutinas_que_ya_no_existen() {
        let user = ObjectId::new();
        let coach = ObjectId::new();
        let old_coach = ObjectId::new();
        let mine = routine(coach, "Torso A", 1);
        let from_old = routine(old_coach, "Rutina vieja", 1);
        let deleted = routine(coach, "Eliminada", 1);
        let assignments = [
            assignment(&mine, user, 1),
            assignment(&from_old, user, 2),
            assignment(&deleted, user, 3),
        ];
        let names = HashMap::from([(coach, "Carlos".to_string())]);

        let list = build_routine_list(
            None,
            &assignments,
            Some(coach),
            &[mine.clone(), from_old.clone()],
            &names,
        );
        let ids: Vec<_> = list.iter().map(|r| r.id).collect();
        assert_eq!(ids, vec![mine.id]);

        // Sin vinculación activa no aparece ninguna asignada (RN-04).
        let list = build_routine_list(None, &assignments, None, &[mine, from_old], &names);
        assert!(list.is_empty());
    }

    #[test]
    fn detalle_de_la_recomendada_conserva_sus_sesiones_numeradas() {
        let rec = recommended(ObjectId::new(), 3);
        let detail = detail_from_recommended(&rec);
        assert_eq!(detail.id, rec.id);
        assert_eq!(detail.origin, RoutineOrigin::System);
        assert_eq!(detail.coach_name, None);
        assert_eq!(detail.sessions.len(), 3);
        for (session, saved) in detail.sessions.iter().zip(&rec.sessions) {
            assert_eq!(session.number, saved.number);
            assert_eq!(session.name, saved.name);
            let e = &saved.exercises[0];
            assert_eq!(
                session.exercises,
                vec![DetailExercise {
                    exercise_id: e.exercise_id,
                    name: e.name.clone(),
                    muscle_group: e.muscle_group,
                    sets: e.sets,
                    reps: e.reps,
                    rest_seconds: e.rest_seconds,
                }]
            );
        }
    }

    #[test]
    fn detalle_del_coach_es_una_sola_sesion_con_todos_sus_ejercicios() {
        let torso = routine(ObjectId::new(), "Torso A", 3);
        let detail = detail_from_assigned(&torso, Some("Carlos".into()));
        assert_eq!(detail.id, torso.id);
        assert_eq!(detail.origin, RoutineOrigin::Coach);
        assert_eq!(detail.name, "Torso A");
        assert_eq!(detail.coach_name.as_deref(), Some("Carlos"));
        assert_eq!(detail.sessions.len(), 1);
        let session = &detail.sessions[0];
        assert_eq!(session.number, ASSIGNED_SESSION_NUMBER);
        assert_eq!(session.name, "Torso A");
        assert_eq!(session.exercises.len(), 3);
        assert_eq!(
            session.exercises[2],
            DetailExercise {
                exercise_id: torso.exercises[2].exercise_id,
                name: "Ejercicio 2".into(),
                muscle_group: MuscleGroup::Chest,
                sets: 4,
                reps: 10,
                rest_seconds: 90,
            }
        );
    }

    /// Pruebas contra MongoDB real: `cargo test -- --ignored` con un servidor local
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::models::coach_link::LinkStatus;
        use crate::models::profile::Gender;
        use crate::models::profile::{PROFILES_COLLECTION, UserProfile};
        use crate::models::user::Role;
        use crate::services::exercises::seed_exercises;
        use crate::services::recommended_routines::generate_recommended_routine;
        use crate::services::routine_assignments::assign_routine;
        use crate::services::routines::{RoutineInput, create_routine, delete_routine};
        use serde_json::json;

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn account(db: &Database, name: &str, role: Role) -> ObjectId {
            let id = ObjectId::new();
            db.collection::<User>(USERS_COLLECTION)
                .insert_one(User {
                    id: Some(id),
                    name: name.into(),
                    email: format!("{}.{id}@macrofit.test", name.to_lowercase()),
                    password_hash: "hash".into(),
                    role,
                    privacy_accepted_at: None,
                    privacy_version: None,
                    profile_completed: true,
                    created_at: DateTime::now(),
                })
                .await
                .unwrap();
            id
        }

        async fn with_profile(db: &Database, user_id: ObjectId) {
            let now = DateTime::now();
            db.collection::<UserProfile>(PROFILES_COLLECTION)
                .insert_one(UserProfile {
                    id: ObjectId::new(),
                    user_id,
                    objective: Objective::Maintain,
                    level: Level::Beginner,
                    training_days: 3,
                    weight_kg: 70.0,
                    height_cm: 170.0,
                    gender: Gender::Male,
                    birth_date: DateTime::from_millis(0),
                    created_at: now,
                    updated_at: now,
                })
                .await
                .unwrap();
        }

        async fn link(db: &Database, coach: ObjectId, user: ObjectId, status: LinkStatus) {
            db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
                .insert_one(CoachLink {
                    id: ObjectId::new(),
                    coach_id: coach,
                    user_id: user,
                    status,
                    created_at: DateTime::now(),
                })
                .await
                .unwrap();
        }

        async fn coach_routine(db: &Database, coach: ObjectId, name: &str) -> ObjectId {
            let catalog = crate::services::exercises::list_exercises(db, None, None)
                .await
                .unwrap();
            let input = RoutineInput {
                name: Some(json!(name)),
                exercises: Some(json!([{
                    "exercise_id": catalog[0].id.to_hex(), "sets": 3, "reps": 10, "rest_seconds": 60
                }])),
            };
            create_routine(db, coach, input).await.unwrap().id
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn lista_y_detalle_de_recomendada_y_asignada() {
            let db = test_db().await;
            seed_exercises(&db).await.unwrap();
            let coach = account(&db, "Carlos", Role::Coach).await;
            let user = account(&db, "Ana", Role::User).await;
            with_profile(&db, user).await;
            link(&db, coach, user, LinkStatus::Active).await;

            assert!(list_user_routines(&db, user).await.unwrap().is_empty());

            let rec = generate_recommended_routine(&db, user).await.unwrap();
            let list = list_user_routines(&db, user).await.unwrap();
            assert_eq!(list.len(), 1);
            assert_eq!(list[0].id, rec.id);

            let torso = coach_routine(&db, coach, "Torso A").await;
            assign_routine(&db, coach, &torso.to_hex(), Some(json!([user.to_hex()])))
                .await
                .unwrap();
            let list = list_user_routines(&db, user).await.unwrap();
            assert_eq!(
                list.iter()
                    .map(|r| (r.origin, r.coach_name.as_deref()))
                    .collect::<Vec<_>>(),
                vec![
                    (RoutineOrigin::System, None),
                    (RoutineOrigin::Coach, Some("Carlos"))
                ]
            );

            let detail = get_user_routine(&db, user, &rec.id.to_hex()).await.unwrap();
            assert_eq!(detail.sessions.len(), 3);
            let detail = get_user_routine(&db, user, &torso.to_hex()).await.unwrap();
            assert_eq!(detail.coach_name.as_deref(), Some("Carlos"));
            assert_eq!(detail.sessions.len(), 1);
            assert_eq!(detail.sessions[0].exercises[0].sets, 3);
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn rutinas_ajenas_retiradas_reemplazadas_o_mal_formadas_responden_404() {
            let db = test_db().await;
            seed_exercises(&db).await.unwrap();
            let coach = account(&db, "Carlos", Role::Coach).await;
            let user = account(&db, "Ana", Role::User).await;
            let other = account(&db, "Bruno", Role::User).await;
            with_profile(&db, user).await;
            link(&db, coach, user, LinkStatus::Active).await;

            let first = generate_recommended_routine(&db, user).await.unwrap();
            let torso = coach_routine(&db, coach, "Torso A").await;
            assign_routine(&db, coach, &torso.to_hex(), Some(json!([user.to_hex()])))
                .await
                .unwrap();

            let not_found = |r: Result<RoutineDetail, AppError>| {
                assert!(matches!(r, Err(AppError::RoutineNotFound)), "{r:?}")
            };
            // Ajena: otro usuario no ve la recomendada ni la asignada de Ana.
            not_found(get_user_routine(&db, other, &first.id.to_hex()).await);
            not_found(get_user_routine(&db, other, &torso.to_hex()).await);
            assert!(list_user_routines(&db, other).await.unwrap().is_empty());
            // Id mal formado o inexistente.
            not_found(get_user_routine(&db, user, "no-es-un-id").await);
            not_found(get_user_routine(&db, user, &ObjectId::new().to_hex()).await);
            // Reemplazada al regenerar.
            let second = generate_recommended_routine(&db, user).await.unwrap();
            not_found(get_user_routine(&db, user, &first.id.to_hex()).await);
            // Retirada (eliminar la rutina retira sus asignaciones, HU-18/HU-19).
            delete_routine(&db, coach, &torso.to_hex()).await.unwrap();
            not_found(get_user_routine(&db, user, &torso.to_hex()).await);
            let list = list_user_routines(&db, user).await.unwrap();
            assert_eq!(
                list.iter().map(|r| r.id).collect::<Vec<_>>(),
                vec![second.id]
            );
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn al_desvincularse_las_asignadas_dejan_de_aparecer() {
            let db = test_db().await;
            seed_exercises(&db).await.unwrap();
            let coach = account(&db, "Carlos", Role::Coach).await;
            let user = account(&db, "Ana", Role::User).await;
            link(&db, coach, user, LinkStatus::Active).await;
            let torso = coach_routine(&db, coach, "Torso A").await;
            assign_routine(&db, coach, &torso.to_hex(), Some(json!([user.to_hex()])))
                .await
                .unwrap();
            assert_eq!(list_user_routines(&db, user).await.unwrap().len(), 1);

            db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
                .update_many(
                    doc! { "user_id": user },
                    doc! { "$set": { "status": "unlinked" } },
                )
                .await
                .unwrap();
            assert!(list_user_routines(&db, user).await.unwrap().is_empty());
            assert!(matches!(
                get_user_routine(&db, user, &torso.to_hex()).await,
                Err(AppError::RoutineNotFound)
            ));
            db.drop().await.unwrap();
        }
    }
}
