//! TEC-09 — Catálogo inicial de ejercicios y script de carga reproducible.

use mongodb::{
    Database,
    bson::{DateTime, doc, oid::ObjectId},
    options::FindOptions,
};

use crate::db::collect_cursor;
use crate::error::AppError;
use crate::models::exercise::{EXERCISES_COLLECTION, Exercise, ExerciseLevel, MuscleGroup};

#[derive(Debug, Clone)]
pub struct ExerciseSeedItem {
    pub name: &'static str,
    pub muscle_group: MuscleGroup,
    pub equipment: &'static str,
    pub level: ExerciseLevel,
}

/// Catálogo base de ejercicios acordado para el inicio de MacroFit.
/// Garantiza al menos un ejercicio por cada combinación de grupo muscular y nivel.
pub fn initial_catalog() -> Vec<ExerciseSeedItem> {
    vec![
        // --- CHEST (Pecho) ---
        ExerciseSeedItem {
            name: "Flexiones de pecho",
            muscle_group: MuscleGroup::Chest,
            equipment: "bodyweight",
            level: ExerciseLevel::Beginner,
        },
        ExerciseSeedItem {
            name: "Press de banca con mancuernas",
            muscle_group: MuscleGroup::Chest,
            equipment: "dumbbell",
            level: ExerciseLevel::Intermediate,
        },
        ExerciseSeedItem {
            name: "Press de banca inclinado con barra",
            muscle_group: MuscleGroup::Chest,
            equipment: "barbell",
            level: ExerciseLevel::Advanced,
        },
        // --- BACK (Espalda) ---
        ExerciseSeedItem {
            name: "Remo con banda elástica",
            muscle_group: MuscleGroup::Back,
            equipment: "band",
            level: ExerciseLevel::Beginner,
        },
        ExerciseSeedItem {
            name: "Jalón al pecho en polea",
            muscle_group: MuscleGroup::Back,
            equipment: "cable",
            level: ExerciseLevel::Intermediate,
        },
        ExerciseSeedItem {
            name: "Dominadas pronadas",
            muscle_group: MuscleGroup::Back,
            equipment: "bodyweight",
            level: ExerciseLevel::Advanced,
        },
        // --- LEGS (Piernas) ---
        ExerciseSeedItem {
            name: "Sentadilla libre con peso corporal",
            muscle_group: MuscleGroup::Legs,
            equipment: "bodyweight",
            level: ExerciseLevel::Beginner,
        },
        ExerciseSeedItem {
            name: "Prensa de piernas",
            muscle_group: MuscleGroup::Legs,
            equipment: "machine",
            level: ExerciseLevel::Intermediate,
        },
        ExerciseSeedItem {
            name: "Sentadilla trasera con barra",
            muscle_group: MuscleGroup::Legs,
            equipment: "barbell",
            level: ExerciseLevel::Advanced,
        },
        // --- SHOULDERS (Hombros) ---
        ExerciseSeedItem {
            name: "Elevaciones laterales con mancuernas",
            muscle_group: MuscleGroup::Shoulders,
            equipment: "dumbbell",
            level: ExerciseLevel::Beginner,
        },
        ExerciseSeedItem {
            name: "Press militar con mancuernas",
            muscle_group: MuscleGroup::Shoulders,
            equipment: "dumbbell",
            level: ExerciseLevel::Intermediate,
        },
        ExerciseSeedItem {
            name: "Press militar de pie con barra",
            muscle_group: MuscleGroup::Shoulders,
            equipment: "barbell",
            level: ExerciseLevel::Advanced,
        },
        // --- ARMS (Brazos) ---
        ExerciseSeedItem {
            name: "Curl de bíceps con mancuernas",
            muscle_group: MuscleGroup::Arms,
            equipment: "dumbbell",
            level: ExerciseLevel::Beginner,
        },
        ExerciseSeedItem {
            name: "Extensión de tríceps en polea alta",
            muscle_group: MuscleGroup::Arms,
            equipment: "cable",
            level: ExerciseLevel::Intermediate,
        },
        ExerciseSeedItem {
            name: "Fondos en barras paralelas",
            muscle_group: MuscleGroup::Arms,
            equipment: "bodyweight",
            level: ExerciseLevel::Advanced,
        },
        // --- CORE (Abdomen / Core) ---
        ExerciseSeedItem {
            name: "Plancha abdominal estática",
            muscle_group: MuscleGroup::Core,
            equipment: "bodyweight",
            level: ExerciseLevel::Beginner,
        },
        ExerciseSeedItem {
            name: "Crunch en polea alta",
            muscle_group: MuscleGroup::Core,
            equipment: "cable",
            level: ExerciseLevel::Intermediate,
        },
        ExerciseSeedItem {
            name: "Elevación de piernas colgado",
            muscle_group: MuscleGroup::Core,
            equipment: "bodyweight",
            level: ExerciseLevel::Advanced,
        },
    ]
}

/// Carga el catálogo inicial de ejercicios en la base de datos de forma reproducible e idempotente.
/// Ejecutarlo dos o más veces actualiza los valores sin duplicar ejercicios.
pub async fn seed_exercises(db: &Database) -> Result<usize, AppError> {
    let collection = db.collection::<Exercise>(EXERCISES_COLLECTION);
    let catalog = initial_catalog();
    let count = catalog.len();
    let now = DateTime::now();

    for item in catalog {
        collection
            .find_one_and_update(
                doc! { "name": item.name },
                doc! {
                    "$set": {
                        "muscle_group": item.muscle_group.as_str(),
                        "equipment": item.equipment,
                        "level": item.level.as_str(),
                    },
                    "$setOnInsert": {
                        "_id": ObjectId::new(),
                        "created_at": now,
                    }
                },
            )
            .upsert(true)
            .await
            .map_err(AppError::internal)?;
    }

    Ok(count)
}

/// Consulta la lista de ejercicios registrados, con filtros opcionales por grupo muscular y nivel.
pub async fn list_exercises(
    db: &Database,
    muscle_group: Option<MuscleGroup>,
    level: Option<ExerciseLevel>,
) -> Result<Vec<Exercise>, AppError> {
    let mut filter = doc! {};

    if let Some(mg) = muscle_group {
        filter.insert("muscle_group", mg.as_str());
    }

    if let Some(lvl) = level {
        filter.insert("level", lvl.as_str());
    }

    let options = FindOptions::builder().sort(doc! { "name": 1 }).build();
    let cursor = db
        .collection::<Exercise>(EXERCISES_COLLECTION)
        .find(filter)
        .with_options(options)
        .await
        .map_err(AppError::internal)?;

    collect_cursor(cursor).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::profile::Level;
    use std::collections::HashSet;

    #[test]
    fn el_catalogo_contiene_ejercicios_para_todas_las_combinaciones() {
        let catalog = initial_catalog();

        for mg in MuscleGroup::all() {
            for lvl in ExerciseLevel::all() {
                let matches = catalog
                    .iter()
                    .any(|e| e.muscle_group == *mg && e.level == *lvl);

                assert!(
                    matches,
                    "Falta un ejercicio para la combinación grupo muscular: {:?}, nivel: {:?}",
                    mg, lvl
                );
            }
        }
    }

    #[test]
    fn cantidad_minima_de_ejercicios_cumple_acuerdo_sprint_planning() {
        let catalog = initial_catalog();
        // Acuerdo de Sprint Planning: al menos 18 ejercicios (6 grupos musculares x 3 niveles de dificultad).
        assert!(
            catalog.len() >= 18,
            "El catálogo debe tener al menos 18 ejercicios, se encontraron {}",
            catalog.len()
        );
    }

    #[test]
    fn todos_los_nombres_del_catalogo_son_unicos_y_no_vacios() {
        let catalog = initial_catalog();
        let mut names = HashSet::new();

        for item in catalog {
            assert!(
                !item.name.trim().is_empty(),
                "El nombre no puede estar vacío"
            );
            assert!(
                !item.equipment.trim().is_empty(),
                "El equipo no puede estar vacío"
            );
            assert!(
                names.insert(item.name),
                "Nombre duplicado en el catálogo inicial: {}",
                item.name
            );
        }
    }

    #[test]
    fn niveles_de_ejercicios_coinciden_con_los_niveles_del_perfil() {
        let profile_levels = [Level::Beginner, Level::Intermediate, Level::Advanced];
        let exercise_levels = ExerciseLevel::all();

        assert_eq!(exercise_levels.len(), profile_levels.len());
        for el in exercise_levels {
            let matches_profile = profile_levels.iter().any(|pl| {
                let pl_str = match pl {
                    Level::Beginner => "beginner",
                    Level::Intermediate => "intermediate",
                    Level::Advanced => "advanced",
                };
                pl_str == el.as_str()
            });
            assert!(
                matches_profile,
                "El nivel de ejercicio {:?} no coincide con ningún nivel del perfil",
                el
            );
        }
    }

    #[test]
    fn grupos_musculares_son_los_seis_esperados() {
        let expected = ["chest", "back", "legs", "shoulders", "arms", "core"];
        let groups = MuscleGroup::all();
        assert_eq!(groups.len(), expected.len());
        for g in groups {
            assert!(expected.contains(&g.as_str()));
        }
    }

    #[tokio::test]
    #[ignore = "requiere MongoDB"]
    async fn seed_exercises_es_reproducible_e_idempotente() {
        let uri =
            std::env::var("TEST_MONGO_URI").unwrap_or_else(|_| "mongodb://localhost:27017".into());
        let db = crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await;

        let count_first = seed_exercises(&db).await.expect("Primera siembra falló");
        assert_eq!(count_first, 18);

        let total_first = db
            .collection::<Exercise>(EXERCISES_COLLECTION)
            .count_documents(doc! {})
            .await
            .expect("Error al contar documentos");
        assert_eq!(total_first, 18);

        // Segunda ejecución no duplica documentos
        let count_second = seed_exercises(&db).await.expect("Segunda siembra falló");
        assert_eq!(count_second, 18);

        let total_second = db
            .collection::<Exercise>(EXERCISES_COLLECTION)
            .count_documents(doc! {})
            .await
            .expect("Error al contar documentos");
        assert_eq!(total_second, 18);

        let chest_beginner =
            list_exercises(&db, Some(MuscleGroup::Chest), Some(ExerciseLevel::Beginner))
                .await
                .expect("Error al consultar ejercicios");
        assert_eq!(chest_beginner.len(), 1);
        assert_eq!(chest_beginner[0].name, "Flexiones de pecho");

        db.drop().await.unwrap();
    }
}
