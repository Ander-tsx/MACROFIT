use mongodb::{
    Database,
    bson::{DateTime, Document, doc, oid::ObjectId, to_bson},
};
use serde_json::Value;

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::goal::{GOALS_COLLECTION, GoalSource, NutritionalGoal};
use crate::models::profile::{Gender, Objective, PROFILES_COLLECTION, UserProfile};
use crate::services::coach_links;
use crate::validation::{check, date_to_bson, parse_date};

const MS_PER_DAY: i64 = 86_400_000;

const CALORIES_MAX: i32 = 10_000;
const MACRO_MAX_G: i32 = 1_000;

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

// ───────────────────────── Validación de la meta del coach ─────────────────────────

/// Cuerpo de la meta del coach tal como llega: los números como `Value` para señalar
/// en su campo un texto o un decimal en lugar de rechazar todo el JSON.
#[derive(Debug, Default)]
pub struct CoachGoalInput {
    pub calories: Option<Value>,
    pub protein_g: Option<Value>,
    pub fat_g: Option<Value>,
    /// `YYYY-MM-DD`.
    pub effective_from: Option<String>,
}

#[derive(Debug, PartialEq)]
pub struct ValidCoachGoal {
    pub calories: i32,
    pub protein_g: i32,
    pub fat_g: i32,
    pub effective_from: DateTime,
}

fn parse_positive_int(value: Value, label: &str, max: i32) -> Result<i32, String> {
    let number = value
        .as_f64()
        .filter(|number| number.fract() == 0.0)
        .ok_or_else(|| format!("{label} debe ser un número entero"))?;
    if (1.0..=f64::from(max)).contains(&number) {
        Ok(number as i32)
    } else {
        Err(format!("{label} debe estar entre 1 y {max}"))
    }
}

fn parse_effective_from(value: String) -> Result<DateTime, String> {
    parse_date(value.trim()).map(date_to_bson).ok_or_else(|| {
        "La fecha de vigencia debe ser una fecha válida con formato AAAA-MM-DD".into()
    })
}

/// Valida todos los campos de la meta y los señala a la vez.
pub fn validate_coach_goal(input: CoachGoalInput) -> Result<ValidCoachGoal, AppError> {
    let mut errors = FieldErrors::new();

    let calories = check(
        &mut errors,
        "calories",
        input.calories,
        true,
        "Las calorías son obligatorias",
        |value| parse_positive_int(value, "Las calorías", CALORIES_MAX),
    );
    let protein_g = check(
        &mut errors,
        "protein_g",
        input.protein_g,
        true,
        "La proteína es obligatoria",
        |value| parse_positive_int(value, "La proteína", MACRO_MAX_G),
    );
    let fat_g = check(
        &mut errors,
        "fat_g",
        input.fat_g,
        true,
        "La grasa es obligatoria",
        |value| parse_positive_int(value, "La grasa", MACRO_MAX_G),
    );
    let effective_from = check(
        &mut errors,
        "effective_from",
        input.effective_from,
        true,
        "La fecha de vigencia es obligatoria",
        parse_effective_from,
    );

    match (calories, protein_g, fat_g, effective_from) {
        (Some(calories), Some(protein_g), Some(fat_g), Some(effective_from)) => {
            Ok(ValidCoachGoal {
                calories,
                protein_g,
                fat_g,
                effective_from,
            })
        }
        _ => Err(AppError::Validation(errors)),
    }
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn goals(db: &Database) -> mongodb::Collection<NutritionalGoal> {
    db.collection(GOALS_COLLECTION)
}

async fn find_profile(db: &Database, user_id: ObjectId) -> Result<Option<UserProfile>, AppError> {
    db.collection::<UserProfile>(PROFILES_COLLECTION)
        .find_one(doc! { "user_id": user_id })
        .await
        .map_err(AppError::internal)
}

async fn find_latest(db: &Database, filter: Document) -> Result<Option<NutritionalGoal>, AppError> {
    goals(db)
        .find_one(filter)
        .sort(doc! { "effective_from": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)
}

/// Meta vigente a la fecha `now`: ignora las de fecha futura y la más reciente de un coach
/// tiene prioridad sobre las calculadas por el sistema.
async fn find_current_goal(
    db: &Database,
    user_id: ObjectId,
    now: DateTime,
) -> Result<Option<NutritionalGoal>, AppError> {
    let coach = to_bson(&GoalSource::Coach).map_err(AppError::internal)?;
    let started = doc! { "user_id": user_id, "effective_from": { "$lte": now } };

    let mut from_coach = started.clone();
    from_coach.insert("source", coach);
    match find_latest(db, from_coach).await? {
        Some(goal) => Ok(Some(goal)),
        None => find_latest(db, started).await,
    }
}

async fn list_goals(db: &Database, user_id: ObjectId) -> Result<Vec<NutritionalGoal>, AppError> {
    let cursor = goals(db)
        .find(doc! { "user_id": user_id })
        .sort(doc! { "effective_from": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

async fn insert_goal(db: &Database, goal: &NutritionalGoal) -> Result<(), AppError> {
    goals(db)
        .insert_one(goal)
        .await
        .map_err(AppError::internal)?;
    Ok(())
}

/// Meta vigente. Si no hay ninguna, se genera la inicial (`system`) a partir del perfil;
/// sin perfil → `ProfileNotFound`.
pub async fn get_current_goal(
    db: &Database,
    user_id: ObjectId,
) -> Result<NutritionalGoal, AppError> {
    let now = DateTime::now();
    if let Some(goal) = find_current_goal(db, user_id, now).await? {
        return Ok(goal);
    }

    let profile = find_profile(db, user_id)
        .await?
        .ok_or(AppError::ProfileNotFound)?;
    let goal = build_system_goal(&profile, now);
    insert_goal(db, &goal).await?;
    Ok(goal)
}

/// Historial de metas, de la más reciente a la más antigua (`effective_from` DESC).
/// Sin metas ni perfil → `ProfileNotFound`.
pub async fn get_goals_history(
    db: &Database,
    user_id: ObjectId,
) -> Result<Vec<NutritionalGoal>, AppError> {
    let history = list_goals(db, user_id).await?;
    if history.is_empty() {
        find_profile(db, user_id)
            .await?
            .ok_or(AppError::ProfileNotFound)?;
    }
    Ok(history)
}

/// HU-05 — el coach fija una meta para un cliente vinculado. Se agrega al historial;
/// las anteriores no se modifican.
pub async fn set_client_goal(
    db: &Database,
    coach_id: ObjectId,
    client_id: &str,
    input: CoachGoalInput,
) -> Result<NutritionalGoal, AppError> {
    let client_id = coach_links::require_active_link(db, coach_id, client_id).await?;
    let valid = validate_coach_goal(input)?;

    let goal = NutritionalGoal {
        id: ObjectId::new(),
        user_id: client_id,
        calories: valid.calories,
        protein_g: valid.protein_g,
        fat_g: valid.fat_g,
        source: GoalSource::Coach,
        set_by: Some(coach_id),
        effective_from: valid.effective_from,
        created_at: DateTime::now(),
    };
    insert_goal(db, &goal).await?;
    Ok(goal)
}

/// HU-05 — historial de metas de un cliente vinculado.
pub async fn get_client_goals(
    db: &Database,
    coach_id: ObjectId,
    client_id: &str,
) -> Result<Vec<NutritionalGoal>, AppError> {
    let client_id = coach_links::require_active_link(db, coach_id, client_id).await?;
    list_goals(db, client_id).await
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
    let now = DateTime::now();
    let current = find_current_goal(db, profile.user_id, now).await?;
    if !allows_recalculation(current.map(|goal| goal.source)) {
        return Ok(None);
    }

    let goal = build_system_goal(profile, now);
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

    fn coach_input() -> CoachGoalInput {
        CoachGoalInput {
            calories: Some(Value::from(2200)),
            protein_g: Some(Value::from(160)),
            fat_g: Some(Value::from(70)),
            effective_from: Some("2026-10-09".into()),
        }
    }

    fn invalid_fields(input: CoachGoalInput) -> Vec<String> {
        match validate_coach_goal(input) {
            Err(AppError::Validation(fields)) => fields.into_keys().collect(),
            other => panic!("se esperaban errores de validación, llegó {other:?}"),
        }
    }

    #[test]
    fn meta_de_coach_valida_se_acepta() {
        let goal = validate_coach_goal(coach_input()).unwrap();
        assert_eq!(
            goal,
            ValidCoachGoal {
                calories: 2200,
                protein_g: 160,
                fat_g: 70,
                effective_from: date("2026-10-09T00:00:00Z"),
            }
        );
    }

    #[test]
    fn cuerpo_vacio_senala_los_cuatro_campos() {
        assert_eq!(
            invalid_fields(CoachGoalInput::default()),
            ["calories", "effective_from", "fat_g", "protein_g"]
        );
    }

    #[test]
    fn valores_no_numericos_negativos_o_en_cero_se_senalan() {
        let fields = invalid_fields(CoachGoalInput {
            calories: Some(Value::from("mucho")),
            protein_g: Some(Value::from(-5)),
            fat_g: Some(Value::from(0)),
            effective_from: Some("2026-10-09".into()),
        });
        assert_eq!(fields, ["calories", "fat_g", "protein_g"]);
    }

    #[test]
    fn decimales_y_valores_sobre_el_maximo_se_senalan() {
        let fields = invalid_fields(CoachGoalInput {
            calories: Some(Value::from(2200.5)),
            protein_g: Some(Value::from(MACRO_MAX_G + 1)),
            fat_g: Some(Value::from(MACRO_MAX_G)),
            effective_from: Some("2026-10-09".into()),
        });
        assert_eq!(fields, ["calories", "protein_g"]);
    }

    #[test]
    fn fecha_de_vigencia_invalida_se_senala() {
        for value in ["2026-02-30", "09/10/2026", "mañana", ""] {
            let input = CoachGoalInput {
                effective_from: Some(value.into()),
                ..coach_input()
            };
            assert_eq!(invalid_fields(input), ["effective_from"], "{value}");
        }
    }
}
