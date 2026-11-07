//! HU-15-API — rutina recomendada del usuario (RF-14, RN-05, RN-08).
//!
//! Lee objetivo, nivel y días del perfil (HU-03) y el catálogo de TEC-09, genera la rutina con el motor de TEC-10
//! (`routine_engine::generate_routine`) y la guarda con origen `system` en `recommended_routines`. Pedirla de nuevo
//! deja la anterior como `replaced`: solo hay una vigente por usuario y las anteriores se conservan para las sesiones
//! completadas (HU-17).

use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
};

use crate::error::AppError;
use crate::models::profile::UserProfile;
use crate::models::recommended_routine::{
    RECOMMENDED_ROUTINES_COLLECTION, RecommendedExercise, RecommendedRoutine, RecommendedSession,
    RecommendedStatus, RoutineOrigin,
};
use crate::services::auth::is_duplicate_key;
use crate::services::exercises::list_exercises;
use crate::services::profile::get_profile;
use crate::services::routine_engine::{
    GeneratedRoutine, RoutineEngineError, RoutineProfile, generate_routine,
};

fn recommended_routines(db: &Database) -> Collection<RecommendedRoutine> {
    db.collection(RECOMMENDED_ROUTINES_COLLECTION)
}

// ───────────────────────── Funciones puras ─────────────────────────

/// Datos del perfil que usa el motor.
pub fn routine_profile(profile: &UserProfile) -> RoutineProfile {
    RoutineProfile {
        objective: profile.objective,
        level: profile.level,
        training_days: profile.training_days,
    }
}

/// Traduce el error del motor a la API.
///
/// - `MissingExercises` → `EXERCISE_CATALOG_INCOMPLETE` (503): faltan datos en el catálogo, no es culpa del usuario.
/// - `InvalidTrainingDays` → `INTERNAL_ERROR`: el perfil ya valida 1 a 7 días (HU-03), así que es un dato corrupto.
pub fn map_engine_error(error: RoutineEngineError) -> AppError {
    match error {
        RoutineEngineError::MissingExercises { .. } => {
            eprintln!("[rutina recomendada] {error}");
            AppError::ExerciseCatalogIncomplete
        }
        RoutineEngineError::InvalidTrainingDays(_) => AppError::internal(error),
    }
}

/// Documento a guardar a partir de la rutina que generó el motor.
pub fn build_recommended_routine(
    user_id: ObjectId,
    generated: GeneratedRoutine,
    now: DateTime,
) -> RecommendedRoutine {
    // Los valores del motor son pequeños (días ≤ 7, series ≤ 4, reps ≤ 15, descanso ≤ 90 s): caben en i32.
    let sessions = generated
        .sessions
        .into_iter()
        .map(|session| RecommendedSession {
            number: session.number as i32,
            name: session.name,
            focus: session.focus.as_str().to_string(),
            exercises: session
                .exercises
                .into_iter()
                .map(|e| RecommendedExercise {
                    exercise_id: e.exercise_id,
                    name: e.name,
                    muscle_group: e.muscle_group,
                    equipment: e.equipment,
                    level: e.level,
                    sets: e.sets as i32,
                    reps: e.reps as i32,
                    rest_seconds: e.rest_seconds as i32,
                })
                .collect(),
        })
        .collect();
    RecommendedRoutine {
        id: ObjectId::new(),
        user_id,
        origin: RoutineOrigin::System,
        name: generated.name,
        objective: generated.objective,
        level: generated.level,
        training_days: generated.training_days as i32,
        sessions,
        status: RecommendedStatus::Active,
        created_at: now,
        replaced_at: None,
    }
}

// ───────────────────────── Persistencia ─────────────────────────

/// Intentos de guardar si otra petición del mismo usuario guardó su rutina al mismo tiempo.
const SAVE_ATTEMPTS: usize = 3;

/// HU-15 — genera y guarda la rutina recomendada del usuario; la anterior vigente queda como `replaced`.
///
/// Sin perfil → `PROFILE_NOT_FOUND`; catálogo sin ejercicios elegibles → `EXERCISE_CATALOG_INCOMPLETE`. Si la
/// generación falla, la rutina vigente no se toca. Las sesiones completadas (HU-17) no se borran nunca: viven en su
/// propia colección y la rutina anterior se conserva como `replaced`.
pub async fn generate_recommended_routine(
    db: &Database,
    user_id: ObjectId,
) -> Result<RecommendedRoutine, AppError> {
    let profile = get_profile(db, user_id).await?;
    let catalog = list_exercises(db, None, None).await?;
    let generated =
        generate_routine(routine_profile(&profile), &catalog).map_err(map_engine_error)?;
    let routine = build_recommended_routine(user_id, generated, DateTime::now());
    replace_active(db, routine).await
}

/// Deja como `replaced` la vigente del usuario y guarda la nueva. El índice único parcial
/// `user_id_active_unique` impide dos vigentes: si otra petición guardó la suya entre los dos pasos, se reintenta.
async fn replace_active(
    db: &Database,
    mut routine: RecommendedRoutine,
) -> Result<RecommendedRoutine, AppError> {
    let collection = recommended_routines(db);
    for attempt in 1..=SAVE_ATTEMPTS {
        let now = DateTime::now();
        collection
            .update_many(
                doc! { "user_id": routine.user_id, "status": "active" },
                doc! { "$set": { "status": "replaced", "replaced_at": now } },
            )
            .await
            .map_err(AppError::internal)?;
        match collection.insert_one(&routine).await {
            Ok(_) => return Ok(routine),
            Err(error) if is_duplicate_key(&error) && attempt < SAVE_ATTEMPTS => {
                routine.id = ObjectId::new();
            }
            Err(error) => return Err(AppError::internal(error)),
        }
    }
    unreachable!("el último intento siempre devuelve")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::{Exercise, ExerciseLevel, MuscleGroup};
    use crate::models::profile::{Gender, Level, Objective};
    use crate::services::exercises::initial_catalog;
    use crate::services::routine_engine::SessionFocus;

    fn profile(objective: Objective, level: Level, training_days: i32) -> UserProfile {
        let now = DateTime::now();
        UserProfile {
            id: ObjectId::new(),
            user_id: ObjectId::new(),
            objective,
            level,
            training_days,
            weight_kg: 72.5,
            height_cm: 170.0,
            gender: Gender::Female,
            birth_date: DateTime::from_millis(0),
            created_at: now,
            updated_at: now,
        }
    }

    /// Catálogo inicial de TEC-09 con ids nuevos.
    fn catalog() -> Vec<Exercise> {
        initial_catalog()
            .into_iter()
            .map(|item| Exercise {
                id: ObjectId::new(),
                name: item.name.to_string(),
                muscle_group: item.muscle_group,
                equipment: item.equipment.to_string(),
                level: item.level,
                created_at: DateTime::from_millis(0),
            })
            .collect()
    }

    fn recommend(p: &UserProfile, catalog: &[Exercise]) -> RecommendedRoutine {
        let generated = generate_routine(routine_profile(p), catalog).unwrap();
        build_recommended_routine(p.user_id, generated, DateTime::from_millis(1_000))
    }

    #[test]
    fn routine_profile_toma_objetivo_nivel_y_dias() {
        let p = profile(Objective::GainMuscle, Level::Advanced, 6);
        assert_eq!(
            routine_profile(&p),
            RoutineProfile {
                objective: Objective::GainMuscle,
                level: Level::Advanced,
                training_days: 6,
            }
        );
    }

    #[test]
    fn la_rutina_guardada_conserva_sesiones_y_volumen() {
        let p = profile(Objective::Maintain, Level::Beginner, 3);
        let catalog = catalog();
        let generated = generate_routine(routine_profile(&p), &catalog).unwrap();
        let now = DateTime::from_millis(1_000);
        let routine = build_recommended_routine(p.user_id, generated.clone(), now);

        assert_eq!(routine.user_id, p.user_id);
        assert_eq!(routine.origin, RoutineOrigin::System);
        assert_eq!(routine.status, RecommendedStatus::Active);
        assert_eq!(routine.replaced_at, None);
        assert_eq!(routine.created_at, now);
        assert_eq!(routine.name, "Rutina recomendada · Mantener · 3 días");
        assert_eq!(
            (routine.objective, routine.level, routine.training_days),
            (Objective::Maintain, Level::Beginner, 3)
        );
        assert_eq!(routine.sessions.len(), generated.sessions.len());
        for (saved, session) in routine.sessions.iter().zip(&generated.sessions) {
            assert_eq!(saved.number, session.number as i32);
            assert_eq!(saved.name, session.name);
            assert_eq!(saved.focus, session.focus.as_str());
            assert_eq!(saved.exercises.len(), session.exercises.len());
            for (e, g) in saved.exercises.iter().zip(&session.exercises) {
                assert_eq!(
                    e,
                    &RecommendedExercise {
                        exercise_id: g.exercise_id,
                        name: g.name.clone(),
                        muscle_group: g.muscle_group,
                        equipment: g.equipment.clone(),
                        level: g.level,
                        sets: 2,
                        reps: 12,
                        rest_seconds: 60,
                    }
                );
            }
        }
        assert_eq!(routine.sessions[0].name, "Día 1 · Cuerpo completo");
    }

    #[test]
    fn divisiones_y_niveles_con_el_catalogo_de_tec09() {
        let catalog = catalog();
        let cases = [
            (Level::Beginner, 3, SessionFocus::FullBody, 2),
            (Level::Intermediate, 4, SessionFocus::Upper, 3),
            (Level::Advanced, 6, SessionFocus::Push, 4),
        ];
        for (level, days, first_focus, sets) in cases {
            let p = profile(Objective::LoseFat, level, days);
            let routine = recommend(&p, &catalog);
            assert_eq!(routine.sessions.len() as i32, days, "{level:?}");
            assert_eq!(routine.training_days, days);
            assert_eq!(routine.sessions[0].focus, first_focus.as_str(), "{level:?}");
            let numbers: Vec<i32> = routine.sessions.iter().map(|s| s.number).collect();
            assert_eq!(numbers, (1..=days).collect::<Vec<_>>());
            for e in routine.sessions.iter().flat_map(|s| &s.exercises) {
                assert_eq!((e.sets, e.reps, e.rest_seconds), (sets, 15, 45));
            }
        }
    }

    #[test]
    fn catalogo_incompleto_responde_exercise_catalog_incomplete() {
        let error = map_engine_error(RoutineEngineError::MissingExercises {
            muscle_group: MuscleGroup::Core,
            level: Level::Beginner,
        });
        assert!(
            matches!(error, AppError::ExerciseCatalogIncomplete),
            "{error:?}"
        );

        // Con el catálogo sin core, el motor falla y se traduce igual.
        let without_core: Vec<_> = catalog()
            .into_iter()
            .filter(|e| e.muscle_group != MuscleGroup::Core)
            .collect();
        let p = profile(Objective::Maintain, Level::Beginner, 2);
        let error = generate_routine(routine_profile(&p), &without_core)
            .map_err(map_engine_error)
            .unwrap_err();
        assert!(matches!(error, AppError::ExerciseCatalogIncomplete));
    }

    #[test]
    fn dias_invalidos_del_motor_son_error_interno() {
        // El perfil ya valida 1 a 7 días (HU-03): si llega otro valor es un dato corrupto, no un error del usuario.
        let error = map_engine_error(RoutineEngineError::InvalidTrainingDays(9));
        assert!(matches!(error, AppError::Internal(_)), "{error:?}");
    }

    #[test]
    fn solo_usa_ejercicios_del_nivel_o_inferiores() {
        let catalog = catalog();
        let routine = recommend(&profile(Objective::Maintain, Level::Beginner, 5), &catalog);
        assert!(
            routine
                .sessions
                .iter()
                .flat_map(|s| &s.exercises)
                .all(|e| e.level == ExerciseLevel::Beginner)
        );
    }

    /// Pruebas contra MongoDB real: `cargo test -- --ignored` con un servidor local
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::models::profile::PROFILES_COLLECTION;
        use crate::services::exercises::seed_exercises;

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn user_with_profile(db: &Database, level: Level, days: i32) -> ObjectId {
            let p = profile(Objective::GainMuscle, level, days);
            db.collection::<UserProfile>(PROFILES_COLLECTION)
                .insert_one(&p)
                .await
                .unwrap();
            p.user_id
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn generar_y_regenerar_deja_una_sola_vigente() {
            let db = test_db().await;
            seed_exercises(&db).await.unwrap();
            let user = user_with_profile(&db, Level::Intermediate, 4).await;
            let other = user_with_profile(&db, Level::Beginner, 3).await;

            let first = generate_recommended_routine(&db, user).await.unwrap();
            assert_eq!(first.sessions.len(), 4);
            assert_eq!(first.origin, RoutineOrigin::System);
            let saved = recommended_routines(&db)
                .find_one(doc! { "_id": first.id })
                .await
                .unwrap()
                .expect("guardada");
            assert_eq!(saved, first);
            let others = generate_recommended_routine(&db, other).await.unwrap();

            let second = generate_recommended_routine(&db, user).await.unwrap();
            assert_ne!(second.id, first.id);
            assert_eq!(second.status, RecommendedStatus::Active);

            let previous = recommended_routines(&db)
                .find_one(doc! { "_id": first.id })
                .await
                .unwrap()
                .expect("la anterior se conserva");
            assert_eq!(previous.status, RecommendedStatus::Replaced);
            assert!(previous.replaced_at.is_some());
            assert_eq!(previous.sessions, first.sessions);

            let active = recommended_routines(&db)
                .count_documents(doc! { "user_id": user, "status": "active" })
                .await
                .unwrap();
            assert_eq!(active, 1, "una sola vigente");
            let untouched = recommended_routines(&db)
                .find_one(doc! { "_id": others.id })
                .await
                .unwrap()
                .unwrap();
            assert_eq!(
                untouched.status,
                RecommendedStatus::Active,
                "no toca a otros usuarios"
            );
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn sin_perfil_responde_profile_not_found() {
            let db = test_db().await;
            seed_exercises(&db).await.unwrap();
            let result = generate_recommended_routine(&db, ObjectId::new()).await;
            assert!(
                matches!(result, Err(AppError::ProfileNotFound)),
                "{result:?}"
            );
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn catalogo_vacio_responde_exercise_catalog_incomplete_sin_reemplazar() {
            let db = test_db().await;
            seed_exercises(&db).await.unwrap();
            let user = user_with_profile(&db, Level::Advanced, 6).await;
            let first = generate_recommended_routine(&db, user).await.unwrap();

            db.collection::<Exercise>(crate::models::exercise::EXERCISES_COLLECTION)
                .delete_many(doc! {})
                .await
                .unwrap();
            let result = generate_recommended_routine(&db, user).await;
            assert!(
                matches!(result, Err(AppError::ExerciseCatalogIncomplete)),
                "{result:?}"
            );
            let still = recommended_routines(&db)
                .find_one(doc! { "_id": first.id })
                .await
                .unwrap()
                .unwrap();
            assert_eq!(
                still.status,
                RecommendedStatus::Active,
                "si falla, la vigente no se pierde"
            );
            db.drop().await.unwrap();
        }
    }
}
