use mongodb::{
    Database,
    bson::{DateTime, doc, oid::ObjectId},
};

use crate::error::AppError;
use crate::models::goal::{GOALS_COLLECTION, GoalSource, NutritionalGoal};
use crate::models::profile::{Gender, Objective, PROFILES_COLLECTION, UserProfile};

const MS_PER_DAY: i64 = 86_400_000;

// ───────────────────────── Cálculo (funciones puras) ─────────────────────────

/// Datos de entrada de la fórmula Mifflin-St Jeor.
#[derive(Debug, Clone)]
pub struct GoalInput {
    pub weight_kg: f64,
    pub height_cm: f64,
    pub age_years: i32,
    pub gender: Gender,
    pub training_days: i32,
    pub objective: Objective,
}

/// Macros calculados, ya redondeados a enteros.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Macros {
    pub calories: i32,
    pub protein_g: i32,
    pub fat_g: i32,
}

fn activity_factor(training_days: i32) -> f64 {
    match training_days {
        ..=1 => 1.2,
        2..=3 => 1.375,
        4..=5 => 1.55,
        _ => 1.725,
    }
}

fn objective_adjustment(objective: Objective) -> f64 {
    match objective {
        Objective::LoseFat => 0.80,
        Objective::Maintain => 1.00,
        Objective::GainMuscle => 1.10,
    }
}

fn protein_per_kg(objective: Objective) -> f64 {
    match objective {
        Objective::LoseFat => 2.0,
        Objective::Maintain => 1.6,
        Objective::GainMuscle => 1.8,
    }
}

/// Calcula calorías, proteína y grasa con Mifflin-St Jeor.
/// Grasa = 25 % de las calorías totales entre 9 kcal/g.
pub fn calculate_macros(input: &GoalInput) -> Macros {
    let base = 10.0 * input.weight_kg + 6.25 * input.height_cm - 5.0 * f64::from(input.age_years);
    let bmr = match input.gender {
        Gender::Male => base + 5.0,
        Gender::Female => base - 161.0,
    };

    let calories =
        bmr * activity_factor(input.training_days) * objective_adjustment(input.objective);
    let protein = input.weight_kg * protein_per_kg(input.objective);
    let fat = calories * 0.25 / 9.0;

    Macros {
        calories: calories.round() as i32,
        protein_g: protein.round() as i32,
        fat_g: fat.round() as i32,
    }
}

/// Convierte días desde 1970-01-01 a (año, mes, día). Algoritmo de H. Hinnant.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let year = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let month = (if mp < 10 { mp + 3 } else { mp - 9 }) as u32;
    (if month <= 2 { year + 1 } else { year }, month, day)
}

/// Edad en años cumplidos a la fecha `today`.
pub fn age_on(birth_date: DateTime, today: DateTime) -> i32 {
    let (by, bm, bd) = civil_from_days(birth_date.timestamp_millis().div_euclid(MS_PER_DAY));
    let (ty, tm, td) = civil_from_days(today.timestamp_millis().div_euclid(MS_PER_DAY));
    let mut age = (ty - by) as i32;
    if (tm, td) < (bm, bd) {
        age -= 1;
    }
    age
}

/// Una meta de coach nunca se reemplaza; cualquier otro caso se puede recalcular.
pub fn allows_recalculation(current_source: Option<GoalSource>) -> bool {
    current_source != Some(GoalSource::Coach)
}

/// ¿Cambió algún dato que afecte la meta (peso, objetivo o días de entrenamiento)?
/// La usa la edición del perfil (HU-03) para decidir si recalcula.
pub fn goal_inputs_changed(old: &UserProfile, new: &UserProfile) -> bool {
    old.weight_kg != new.weight_kg
        || old.objective != new.objective
        || old.training_days != new.training_days
}

fn build_system_goal(profile: &UserProfile, now: DateTime) -> NutritionalGoal {
    let macros = calculate_macros(&GoalInput {
        weight_kg: profile.weight_kg,
        height_cm: profile.height_cm,
        age_years: age_on(profile.birth_date, now),
        gender: profile.gender,
        training_days: profile.training_days,
        objective: profile.objective,
    });

    NutritionalGoal {
        id: ObjectId::new(),
        user_id: profile.user_id,
        calories: macros.calories,
        protein_g: macros.protein_g,
        fat_g: macros.fat_g,
        source: GoalSource::System,
        set_by: None,
        effective_from: now,
        created_at: now,
    }
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

async fn find_profile(db: &Database, user_id: ObjectId) -> Result<Option<UserProfile>, AppError> {
    db.collection::<UserProfile>(PROFILES_COLLECTION)
        .find_one(doc! { "user_id": user_id })
        .await
        .map_err(AppError::internal)
}

async fn find_latest_goal(
    db: &Database,
    user_id: ObjectId,
) -> Result<Option<NutritionalGoal>, AppError> {
    db.collection::<NutritionalGoal>(GOALS_COLLECTION)
        .find_one(doc! { "user_id": user_id })
        .sort(doc! { "effective_from": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)
}

async fn insert_goal(db: &Database, goal: &NutritionalGoal) -> Result<(), AppError> {
    db.collection::<NutritionalGoal>(GOALS_COLLECTION)
        .insert_one(goal)
        .await
        .map_err(AppError::internal)?;
    Ok(())
}

/// Meta vigente. Sin perfil → `ProfileNotFound`.
/// Si hay perfil pero todavía no hay ninguna meta, se genera la inicial (`system`).
pub async fn get_current_goal(
    db: &Database,
    user_id: ObjectId,
) -> Result<NutritionalGoal, AppError> {
    let profile = find_profile(db, user_id)
        .await?
        .ok_or(AppError::ProfileNotFound)?;

    if let Some(goal) = find_latest_goal(db, user_id).await? {
        return Ok(goal);
    }

    let goal = build_system_goal(&profile, DateTime::now());
    insert_goal(db, &goal).await?;
    Ok(goal)
}

/// Historial de metas, de la más reciente a la más antigua (`effective_from` DESC).
pub async fn get_goals_history(
    db: &Database,
    user_id: ObjectId,
) -> Result<Vec<NutritionalGoal>, AppError> {
    find_profile(db, user_id)
        .await?
        .ok_or(AppError::ProfileNotFound)?;

    let mut cursor = db
        .collection::<NutritionalGoal>(GOALS_COLLECTION)
        .find(doc! { "user_id": user_id })
        .sort(doc! { "effective_from": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)?;

    let mut history = Vec::new();
    while cursor.advance().await.map_err(AppError::internal)? {
        history.push(cursor.deserialize_current().map_err(AppError::internal)?);
    }
    Ok(history)
}

/// Lógica al crear o editar el perfil.
/// - Meta vigente de `coach`: no se toca y devuelve `None`.
/// - Sin meta o de `system`: se inserta una meta nueva (la anterior queda en el
///   historial) y se devuelve.
///
/// `services::profile` la llama al crear el perfil (meta inicial) y, al editarlo,
/// solo si `goal_inputs_changed` es true.
pub async fn recalculate_on_profile_change(
    db: &Database,
    profile: &UserProfile,
) -> Result<Option<NutritionalGoal>, AppError> {
    let current = find_latest_goal(db, profile.user_id).await?;
    if !allows_recalculation(current.map(|goal| goal.source)) {
        return Ok(None);
    }

    let goal = build_system_goal(profile, DateTime::now());
    insert_goal(db, &goal).await?;
    Ok(Some(goal))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn input(
        weight_kg: f64,
        height_cm: f64,
        age_years: i32,
        gender: Gender,
        training_days: i32,
        objective: Objective,
    ) -> GoalInput {
        GoalInput {
            weight_kg,
            height_cm,
            age_years,
            gender,
            training_days,
            objective,
        }
    }

    fn date(rfc3339: &str) -> DateTime {
        DateTime::parse_rfc3339_str(rfc3339).unwrap()
    }

    #[test]
    fn hombre_bajar_grasa_coincide_con_calculo_manual() {
        // TMB = 800 + 1125 - 125 + 5 = 1805; × 1.55 = 2797.75; × 0.8 = 2238.2
        let m = calculate_macros(&input(80.0, 180.0, 25, Gender::Male, 4, Objective::LoseFat));
        assert_eq!(
            m,
            Macros {
                calories: 2238,
                protein_g: 160,
                fat_g: 62
            }
        );
    }

    #[test]
    fn mujer_ganar_musculo_coincide_con_calculo_manual() {
        // TMB = 600 + 1031.25 - 110 - 161 = 1360.25; × 1.55 × 1.1 = 2319.23
        let m = calculate_macros(&input(
            60.0,
            165.0,
            22,
            Gender::Female,
            5,
            Objective::GainMuscle,
        ));
        assert_eq!(
            m,
            Macros {
                calories: 2319,
                protein_g: 108,
                fat_g: 64
            }
        );
    }

    #[test]
    fn hombre_mantener_coincide_con_calculo_manual() {
        // TMB = 700 + 1093.75 - 150 + 5 = 1648.75; × 1.375 = 2267.03
        let m = calculate_macros(&input(
            70.0,
            175.0,
            30,
            Gender::Male,
            3,
            Objective::Maintain,
        ));
        assert_eq!(
            m,
            Macros {
                calories: 2267,
                protein_g: 112,
                fat_g: 63
            }
        );
    }

    #[test]
    fn factor_de_actividad_respeta_los_limites_de_cada_rango() {
        assert_eq!(activity_factor(1), 1.2);
        assert_eq!(activity_factor(2), 1.375);
        assert_eq!(activity_factor(3), 1.375);
        assert_eq!(activity_factor(4), 1.55);
        assert_eq!(activity_factor(5), 1.55);
        assert_eq!(activity_factor(6), 1.725);
        assert_eq!(activity_factor(7), 1.725);
    }

    #[test]
    fn edad_se_cumple_el_dia_del_cumpleanos() {
        let birth = date("2000-06-15T00:00:00Z");
        assert_eq!(age_on(birth, date("2026-06-14T12:00:00Z")), 25);
        assert_eq!(age_on(birth, date("2026-06-15T00:00:00Z")), 26);
    }

    #[test]
    fn fecha_civil_del_epoch_y_de_anio_bisiesto() {
        assert_eq!(civil_from_days(0), (1970, 1, 1));
        assert_eq!(civil_from_days(11_016), (2000, 2, 29));
    }

    #[test]
    fn meta_de_coach_no_se_recalcula() {
        assert!(!allows_recalculation(Some(GoalSource::Coach)));
        assert!(allows_recalculation(Some(GoalSource::System)));
        assert!(allows_recalculation(None));
    }
}
