//! TEC-10 — Motor de reglas de rutinas recomendadas (RF-14).
//!
//! Función pura: recibe el perfil y el catálogo de ejercicios (TEC-09) y devuelve la rutina, sin tocar la base de
//! datos. Las reglas las acordó el PO y están en `services/README.md` (sección *Motor de rutinas*).

use std::fmt;

use mongodb::bson::oid::ObjectId;

use crate::models::exercise::{Exercise, ExerciseLevel, MuscleGroup};
use crate::models::profile::{Level, Objective};

/// Días de entrenamiento por semana aceptados (mismo rango que el perfil, HU-03).
pub const MIN_TRAINING_DAYS: i32 = 1;
pub const MAX_TRAINING_DAYS: i32 = 7;

/// Datos del perfil que usa el motor.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RoutineProfile {
    pub objective: Objective,
    pub level: Level,
    pub training_days: i32,
}

/// Foco de una sesión: qué grupos musculares trabaja.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionFocus {
    FullBody,
    Upper,
    Push,
    Pull,
    Legs,
}

impl SessionFocus {
    pub fn as_str(&self) -> &'static str {
        match self {
            SessionFocus::FullBody => "full_body",
            SessionFocus::Upper => "upper",
            SessionFocus::Push => "push",
            SessionFocus::Pull => "pull",
            SessionFocus::Legs => "legs",
        }
    }

    /// Nombre que ve el usuario después de "Día N · ".
    pub fn label(&self) -> &'static str {
        match self {
            SessionFocus::FullBody => "Cuerpo completo",
            SessionFocus::Upper => "Torso",
            SessionFocus::Push => "Empuje",
            SessionFocus::Pull => "Tirón",
            SessionFocus::Legs => "Pierna",
        }
    }

    /// Grupos musculares de la sesión, en el orden en que aparecen sus ejercicios.
    pub fn muscle_groups(&self) -> &'static [MuscleGroup] {
        match self {
            SessionFocus::FullBody => MuscleGroup::all(),
            SessionFocus::Upper => &[
                MuscleGroup::Chest,
                MuscleGroup::Back,
                MuscleGroup::Shoulders,
                MuscleGroup::Arms,
            ],
            SessionFocus::Push => &[MuscleGroup::Chest, MuscleGroup::Shoulders],
            SessionFocus::Pull => &[MuscleGroup::Back, MuscleGroup::Arms],
            SessionFocus::Legs => &[MuscleGroup::Legs, MuscleGroup::Core],
        }
    }
}

/// Un ejercicio del catálogo dentro de una sesión, con su volumen.
#[derive(Debug, Clone, PartialEq)]
pub struct RoutineExercise {
    pub exercise_id: ObjectId,
    pub name: String,
    pub muscle_group: MuscleGroup,
    pub equipment: String,
    pub level: ExerciseLevel,
    pub sets: u32,
    pub reps: u32,
    pub rest_seconds: u32,
}

/// Sesión numerada ("Día 1 · Empuje"); no se ata a un día de la semana.
#[derive(Debug, Clone, PartialEq)]
pub struct RoutineSession {
    pub number: u32,
    pub name: String,
    pub focus: SessionFocus,
    pub exercises: Vec<RoutineExercise>,
}

/// Rutina recomendada por el sistema (origen `system`, RN-08).
#[derive(Debug, Clone, PartialEq)]
pub struct GeneratedRoutine {
    pub name: String,
    pub objective: Objective,
    pub level: Level,
    pub training_days: u32,
    pub sessions: Vec<RoutineSession>,
}

/// Errores propios del motor.
// TODO(HU-15-API): traducir a `AppError` al exponer la rutina (código nuevo + fila en README.md).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RoutineEngineError {
    /// `training_days` fuera de 1 a 7.
    InvalidTrainingDays(i32),
    /// El catálogo no tiene ningún ejercicio del grupo con nivel igual o inferior al del usuario.
    MissingExercises {
        muscle_group: MuscleGroup,
        level: Level,
    },
}

impl fmt::Display for RoutineEngineError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RoutineEngineError::InvalidTrainingDays(days) => write!(
                f,
                "Los días de entrenamiento deben estar entre {MIN_TRAINING_DAYS} y {MAX_TRAINING_DAYS} (se recibió {days})."
            ),
            RoutineEngineError::MissingExercises {
                muscle_group,
                level,
            } => write!(
                f,
                "El catálogo no tiene ejercicios de {} para el nivel {} o inferior.",
                muscle_group.as_str(),
                level_name(*level)
            ),
        }
    }
}

impl std::error::Error for RoutineEngineError {}

/// Genera la rutina recomendada para el perfil con los ejercicios del catálogo.
///
/// Determinista: el mismo perfil con el mismo catálogo (en cualquier orden) da la misma rutina.
pub fn generate_routine(
    profile: RoutineProfile,
    catalog: &[Exercise],
) -> Result<GeneratedRoutine, RoutineEngineError> {
    if !(MIN_TRAINING_DAYS..=MAX_TRAINING_DAYS).contains(&profile.training_days) {
        return Err(RoutineEngineError::InvalidTrainingDays(
            profile.training_days,
        ));
    }
    let days = profile.training_days as u32;
    let sets = sets_for(profile.level);
    let (reps, rest_seconds) = reps_and_rest_for(profile.objective);
    let eligible = eligible_exercises(catalog, profile.level);

    let sessions = session_plan(days)
        .into_iter()
        .enumerate()
        .map(|(index, focus)| {
            let per_group = exercises_per_group(focus, profile.level);
            let mut exercises = Vec::new();
            for group in focus.muscle_groups() {
                let picked: Vec<&Exercise> = eligible
                    .iter()
                    .filter(|e| e.muscle_group == *group)
                    .take(per_group)
                    .copied()
                    .collect();
                if picked.is_empty() {
                    return Err(RoutineEngineError::MissingExercises {
                        muscle_group: *group,
                        level: profile.level,
                    });
                }
                exercises.extend(picked.into_iter().map(|e| RoutineExercise {
                    exercise_id: e.id,
                    name: e.name.clone(),
                    muscle_group: e.muscle_group,
                    equipment: e.equipment.clone(),
                    level: e.level,
                    sets,
                    reps,
                    rest_seconds,
                }));
            }
            let number = index as u32 + 1;
            Ok(RoutineSession {
                number,
                name: format!("Día {number} · {}", focus.label()),
                focus,
                exercises,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(GeneratedRoutine {
        name: routine_name(profile.objective, days),
        objective: profile.objective,
        level: profile.level,
        training_days: days,
        sessions,
    })
}

/// Una sesión por día: 1–3 días cuerpo completo, 4 días Torso/Pierna alternados y 5–7 días Empuje/Tirón/Pierna en
/// rotación.
pub fn session_plan(days: u32) -> Vec<SessionFocus> {
    let rotation: &[SessionFocus] = match days {
        0..=3 => &[SessionFocus::FullBody],
        4 => &[SessionFocus::Upper, SessionFocus::Legs],
        _ => &[SessionFocus::Push, SessionFocus::Pull, SessionFocus::Legs],
    };
    (0..days as usize)
        .map(|i| rotation[i % rotation.len()])
        .collect()
}

/// Ejercicios por grupo: 1 en cuerpo completo; en las divisiones 1 (principiante), 2 (intermedio) o, para avanzado,
/// 3 en sesiones de dos grupos y 2 en Torso. Si el catálogo tiene menos, se usan los que haya.
pub fn exercises_per_group(focus: SessionFocus, level: Level) -> usize {
    if focus == SessionFocus::FullBody {
        return 1;
    }
    match level {
        Level::Beginner => 1,
        Level::Intermediate => 2,
        Level::Advanced if focus.muscle_groups().len() <= 2 => 3,
        Level::Advanced => 2,
    }
}

/// Series por nivel: 2 principiante, 3 intermedio, 4 avanzado.
pub fn sets_for(level: Level) -> u32 {
    match level {
        Level::Beginner => 2,
        Level::Intermediate => 3,
        Level::Advanced => 4,
    }
}

/// Repeticiones y descanso (segundos) por objetivo.
pub fn reps_and_rest_for(objective: Objective) -> (u32, u32) {
    match objective {
        Objective::GainMuscle => (10, 90),
        Objective::Maintain => (12, 60),
        Objective::LoseFat => (15, 45),
    }
}

/// Ejercicios del nivel del usuario o inferiores, del más cercano a su nivel al más básico y, a igual nivel, por
/// nombre (y por id si se repite el nombre), para que el orden del catálogo no cambie el resultado.
fn eligible_exercises(catalog: &[Exercise], level: Level) -> Vec<&Exercise> {
    let max_rank = level_rank(level);
    let mut eligible: Vec<&Exercise> = catalog
        .iter()
        .filter(|e| exercise_level_rank(e.level) <= max_rank)
        .collect();
    eligible.sort_by(|a, b| {
        exercise_level_rank(b.level)
            .cmp(&exercise_level_rank(a.level))
            .then_with(|| a.name.cmp(&b.name))
            .then_with(|| a.id.bytes().cmp(&b.id.bytes()))
    });
    eligible
}

fn level_rank(level: Level) -> u8 {
    match level {
        Level::Beginner => 0,
        Level::Intermediate => 1,
        Level::Advanced => 2,
    }
}

fn exercise_level_rank(level: ExerciseLevel) -> u8 {
    match level {
        ExerciseLevel::Beginner => 0,
        ExerciseLevel::Intermediate => 1,
        ExerciseLevel::Advanced => 2,
    }
}

fn level_name(level: Level) -> &'static str {
    match level {
        Level::Beginner => "beginner",
        Level::Intermediate => "intermediate",
        Level::Advanced => "advanced",
    }
}

fn routine_name(objective: Objective, days: u32) -> String {
    let goal = match objective {
        Objective::LoseFat => "Perder grasa",
        Objective::Maintain => "Mantener",
        Objective::GainMuscle => "Ganar músculo",
    };
    let unit = if days == 1 { "día" } else { "días" };
    format!("Rutina recomendada · {goal} · {days} {unit}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::exercises::initial_catalog;
    use mongodb::bson::DateTime;
    use std::collections::HashSet;

    const OBJECTIVES: [Objective; 3] = [
        Objective::LoseFat,
        Objective::Maintain,
        Objective::GainMuscle,
    ];
    const LEVELS: [Level; 3] = [Level::Beginner, Level::Intermediate, Level::Advanced];

    /// Catálogo inicial de TEC-09 con ids fijos.
    fn catalog() -> Vec<Exercise> {
        initial_catalog()
            .into_iter()
            .enumerate()
            .map(|(i, item)| exercise(i as u8, item.name, item.muscle_group, item.level))
            .collect()
    }

    fn exercise(id: u8, name: &str, muscle_group: MuscleGroup, level: ExerciseLevel) -> Exercise {
        Exercise {
            id: ObjectId::from_bytes([id; 12]),
            name: name.to_string(),
            muscle_group,
            equipment: "bodyweight".to_string(),
            level,
            created_at: DateTime::from_millis(0),
        }
    }

    fn profile(objective: Objective, level: Level, training_days: i32) -> RoutineProfile {
        RoutineProfile {
            objective,
            level,
            training_days,
        }
    }

    fn all_profiles() -> Vec<RoutineProfile> {
        let mut profiles = Vec::new();
        for objective in OBJECTIVES {
            for level in LEVELS {
                for days in MIN_TRAINING_DAYS..=MAX_TRAINING_DAYS {
                    profiles.push(profile(objective, level, days));
                }
            }
        }
        profiles
    }

    fn focuses(routine: &GeneratedRoutine) -> Vec<SessionFocus> {
        routine.sessions.iter().map(|s| s.focus).collect()
    }

    #[test]
    fn las_63_combinaciones_generan_una_rutina_valida() {
        let catalog = catalog();
        let profiles = all_profiles();
        assert_eq!(profiles.len(), 63);

        for p in profiles {
            let routine = generate_routine(p, &catalog)
                .unwrap_or_else(|e| panic!("{p:?} no generó rutina: {e}"));
            assert!(!routine.sessions.is_empty(), "{p:?} sin sesiones");
            for session in &routine.sessions {
                assert!(
                    !session.exercises.is_empty(),
                    "{p:?}: {} sin ejercicios",
                    session.name
                );
                let groups: HashSet<_> = session.exercises.iter().map(|e| e.muscle_group).collect();
                for group in session.focus.muscle_groups() {
                    assert!(
                        groups.contains(group),
                        "{p:?}: {} sin ejercicios de {group:?}",
                        session.name
                    );
                }
                let ids: HashSet<_> = session.exercises.iter().map(|e| e.exercise_id).collect();
                assert_eq!(
                    ids.len(),
                    session.exercises.len(),
                    "{p:?}: {} repite un ejercicio",
                    session.name
                );
                let known: HashSet<_> = catalog.iter().map(|e| e.id).collect();
                assert!(
                    session
                        .exercises
                        .iter()
                        .all(|e| known.contains(&e.exercise_id)),
                    "{p:?}: ejercicio fuera del catálogo"
                );
            }
        }
    }

    #[test]
    fn el_numero_de_sesiones_es_igual_a_los_dias_de_entrenamiento() {
        let catalog = catalog();
        for p in all_profiles() {
            let routine = generate_routine(p, &catalog).unwrap();
            assert_eq!(routine.sessions.len() as i32, p.training_days, "{p:?}");
            assert_eq!(routine.training_days as i32, p.training_days, "{p:?}");
        }
    }

    #[test]
    fn dias_fuera_de_1_a_7_responden_error() {
        let catalog = catalog();
        for days in [-1, 0, 8, 30] {
            assert_eq!(
                generate_routine(
                    profile(Objective::Maintain, Level::Beginner, days),
                    &catalog
                ),
                Err(RoutineEngineError::InvalidTrainingDays(days))
            );
        }
    }

    #[test]
    fn solo_elige_ejercicios_del_nivel_del_usuario_o_inferiores() {
        let catalog = catalog();
        for p in all_profiles() {
            let routine = generate_routine(p, &catalog).unwrap();
            for session in &routine.sessions {
                for e in &session.exercises {
                    assert!(
                        exercise_level_rank(e.level) <= level_rank(p.level),
                        "{p:?}: {} es {:?}",
                        e.name,
                        e.level
                    );
                }
            }
        }
    }

    #[test]
    fn prefiere_los_ejercicios_del_nivel_del_usuario() {
        let catalog = catalog();
        let routine =
            generate_routine(profile(Objective::Maintain, Level::Advanced, 1), &catalog).unwrap();
        // Cuerpo completo usa 1 ejercicio por grupo: el avanzado de cada grupo.
        assert!(
            routine.sessions[0]
                .exercises
                .iter()
                .all(|e| e.level == ExerciseLevel::Advanced)
        );

        let routine = generate_routine(
            profile(Objective::Maintain, Level::Intermediate, 5),
            &catalog,
        )
        .unwrap();
        let push = &routine.sessions[0];
        let chest: Vec<_> = push
            .exercises
            .iter()
            .filter(|e| e.muscle_group == MuscleGroup::Chest)
            .map(|e| e.level)
            .collect();
        assert_eq!(
            chest,
            vec![ExerciseLevel::Intermediate, ExerciseLevel::Beginner]
        );
    }

    #[test]
    fn series_por_nivel_y_repeticiones_y_descanso_por_objetivo() {
        let catalog = catalog();
        for p in all_profiles() {
            let routine = generate_routine(p, &catalog).unwrap();
            let expected_sets = match p.level {
                Level::Beginner => 2,
                Level::Intermediate => 3,
                Level::Advanced => 4,
            };
            let (expected_reps, expected_rest) = match p.objective {
                Objective::GainMuscle => (10, 90),
                Objective::Maintain => (12, 60),
                Objective::LoseFat => (15, 45),
            };
            for e in routine.sessions.iter().flat_map(|s| &s.exercises) {
                assert!(e.sets > 0 && e.reps > 0, "{p:?}: {e:?}");
                assert_eq!(
                    (e.sets, e.reps, e.rest_seconds),
                    (expected_sets, expected_reps, expected_rest),
                    "{p:?}"
                );
            }
        }
    }

    #[test]
    fn de_1_a_3_dias_es_cuerpo_completo() {
        let catalog = catalog();
        for days in 1..=3 {
            let routine = generate_routine(
                profile(Objective::LoseFat, Level::Intermediate, days),
                &catalog,
            )
            .unwrap();
            assert!(
                focuses(&routine)
                    .iter()
                    .all(|f| *f == SessionFocus::FullBody)
            );
            for session in &routine.sessions {
                assert_eq!(session.exercises.len(), MuscleGroup::all().len());
            }
        }
    }

    #[test]
    fn con_4_dias_alterna_torso_y_pierna() {
        let routine = generate_routine(
            profile(Objective::GainMuscle, Level::Beginner, 4),
            &catalog(),
        )
        .unwrap();
        use SessionFocus::*;
        assert_eq!(focuses(&routine), vec![Upper, Legs, Upper, Legs]);
    }

    #[test]
    fn de_5_a_7_dias_rota_empuje_tiron_y_pierna() {
        use SessionFocus::*;
        let catalog = catalog();
        let expected = [
            (5, vec![Push, Pull, Legs, Push, Pull]),
            (6, vec![Push, Pull, Legs, Push, Pull, Legs]),
            (7, vec![Push, Pull, Legs, Push, Pull, Legs, Push]),
        ];
        for (days, plan) in expected {
            let routine = generate_routine(
                profile(Objective::Maintain, Level::Advanced, days),
                &catalog,
            )
            .unwrap();
            assert_eq!(focuses(&routine), plan, "{days} días");
        }
    }

    #[test]
    fn las_sesiones_se_numeran_con_su_foco() {
        let routine = generate_routine(
            profile(Objective::GainMuscle, Level::Advanced, 5),
            &catalog(),
        )
        .unwrap();
        let names: Vec<_> = routine.sessions.iter().map(|s| s.name.as_str()).collect();
        assert_eq!(
            names,
            vec![
                "Día 1 · Empuje",
                "Día 2 · Tirón",
                "Día 3 · Pierna",
                "Día 4 · Empuje",
                "Día 5 · Tirón"
            ]
        );
        let numbers: Vec<_> = routine.sessions.iter().map(|s| s.number).collect();
        assert_eq!(numbers, vec![1, 2, 3, 4, 5]);
        assert_eq!(routine.name, "Rutina recomendada · Ganar músculo · 5 días");

        let one_day =
            generate_routine(profile(Objective::LoseFat, Level::Beginner, 1), &catalog()).unwrap();
        assert_eq!(one_day.sessions[0].name, "Día 1 · Cuerpo completo");
        assert_eq!(one_day.name, "Rutina recomendada · Perder grasa · 1 día");
    }

    #[test]
    fn ejercicios_por_grupo_segun_nivel_y_sesion() {
        use SessionFocus::*;
        for level in LEVELS {
            assert_eq!(exercises_per_group(FullBody, level), 1);
        }
        assert_eq!(exercises_per_group(Push, Level::Beginner), 1);
        assert_eq!(exercises_per_group(Upper, Level::Intermediate), 2);
        assert_eq!(exercises_per_group(Pull, Level::Intermediate), 2);
        assert_eq!(exercises_per_group(Legs, Level::Advanced), 3);
        assert_eq!(exercises_per_group(Upper, Level::Advanced), 2);

        // Con el catálogo de TEC-09 (1 ejercicio por grupo y nivel) el número real queda limitado por lo disponible.
        let catalog = catalog();
        let count = |level, days| {
            generate_routine(profile(Objective::Maintain, level, days), &catalog)
                .unwrap()
                .sessions[0]
                .exercises
                .len()
        };
        assert_eq!(count(Level::Beginner, 5), 2); // Empuje: pecho y hombros, 1 cada uno
        assert_eq!(count(Level::Intermediate, 5), 4); // 2 por grupo
        assert_eq!(count(Level::Advanced, 5), 6); // 3 por grupo
        assert_eq!(count(Level::Advanced, 4), 8); // Torso: 4 grupos x 2
    }

    #[test]
    fn mismo_perfil_y_catalogo_dan_la_misma_rutina() {
        let catalog = catalog();
        for p in all_profiles() {
            assert_eq!(
                generate_routine(p, &catalog),
                generate_routine(p, &catalog),
                "{p:?}"
            );
        }
    }

    #[test]
    fn el_orden_del_catalogo_no_cambia_la_rutina() {
        let catalog = catalog();
        let mut reversed = catalog.clone();
        reversed.reverse();
        let mut rotated = catalog.clone();
        rotated.rotate_left(7);
        for p in all_profiles() {
            let expected = generate_routine(p, &catalog);
            assert_eq!(generate_routine(p, &reversed), expected, "{p:?}");
            assert_eq!(generate_routine(p, &rotated), expected, "{p:?}");
        }
    }

    #[test]
    fn catalogo_sin_un_grupo_responde_error_propio() {
        let without_core: Vec<_> = catalog()
            .into_iter()
            .filter(|e| e.muscle_group != MuscleGroup::Core)
            .collect();
        for days in MIN_TRAINING_DAYS..=MAX_TRAINING_DAYS {
            assert_eq!(
                generate_routine(
                    profile(Objective::Maintain, Level::Advanced, days),
                    &without_core
                ),
                Err(RoutineEngineError::MissingExercises {
                    muscle_group: MuscleGroup::Core,
                    level: Level::Advanced,
                }),
                "{days} días"
            );
        }
        assert!(matches!(
            generate_routine(profile(Objective::Maintain, Level::Beginner, 3), &[]),
            Err(RoutineEngineError::MissingExercises { .. })
        ));
    }

    #[test]
    fn catalogo_sin_ejercicios_del_nivel_responde_error_propio() {
        // Solo hay pecho avanzado: un principiante no puede usarlo.
        let catalog: Vec<_> = catalog()
            .into_iter()
            .filter(|e| e.muscle_group != MuscleGroup::Chest || e.level == ExerciseLevel::Advanced)
            .collect();
        let error = generate_routine(profile(Objective::LoseFat, Level::Beginner, 2), &catalog)
            .unwrap_err();
        assert_eq!(
            error,
            RoutineEngineError::MissingExercises {
                muscle_group: MuscleGroup::Chest,
                level: Level::Beginner,
            }
        );
        assert_eq!(
            error.to_string(),
            "El catálogo no tiene ejercicios de chest para el nivel beginner o inferior."
        );
        assert!(
            generate_routine(profile(Objective::LoseFat, Level::Advanced, 2), &catalog).is_ok()
        );
    }
}
