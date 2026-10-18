//! HU-10 — resumen diario contra la meta (RF-09).
//!
//! - El día se define como en HU-09: con la zona horaria fija de la app (`APP_UTC_OFFSET`), filtrando por el
//!   campo `date` de cada registro.
//! - La meta es la vigente al final de ese día (`goals::get_goal_at`, la misma regla que `GET /users/me/goals/current`).
//! - `remaining` = meta − consumido. Si el consumo supera la meta es **negativo** (por ejemplo `-150` = se pasó por 150).
//! - Los valores se redondean a 1 decimal para que la suma de decimales binarios no deje ruido (`0.1 + 0.2`).

use chrono::{Days, FixedOffset, NaiveDate, NaiveTime};
use mongodb::{
    Database,
    bson::{DateTime, oid::ObjectId},
};

use crate::error::AppError;
use crate::models::goal::{GoalSource, NutritionalGoal};
use crate::models::meal::Meal;
use crate::services::{goals, meals};

/// Calorías y macros que muestra el resumen (RF-09).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Totals {
    pub calories_kcal: f64,
    pub protein_g: f64,
    pub fat_g: f64,
}

/// Meta vigente del día con su origen.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DayGoal {
    pub source: GoalSource,
    pub totals: Totals,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DailySummary {
    /// Día consultado, `YYYY-MM-DD`.
    pub date: String,
    pub goal: DayGoal,
    pub consumed: Totals,
    pub remaining: Totals,
}

/// Redondea a 1 decimal. El `+ 0.0` convierte `-0.0` en `0.0`: la suma de un iterador vacío de `f64` da `-0.0`
/// y el cliente vería `-0` en un día sin registros.
fn round1(value: f64) -> f64 {
    (value * 10.0).round() / 10.0 + 0.0
}

/// Suma los registros del día. Sin registros → todo en 0.
pub fn sum_meals(meals: &[Meal]) -> Totals {
    let total = |value: fn(&Meal) -> f64| round1(meals.iter().map(value).sum());
    Totals {
        calories_kcal: total(|meal| meal.calories_kcal),
        protein_g: total(|meal| meal.protein_g),
        fat_g: total(|meal| meal.fat_g),
    }
}

/// Meta − consumido. Negativo cuando el consumo supera la meta.
pub fn remaining(goal: Totals, consumed: Totals) -> Totals {
    Totals {
        calories_kcal: round1(goal.calories_kcal - consumed.calories_kcal),
        protein_g: round1(goal.protein_g - consumed.protein_g),
        fat_g: round1(goal.fat_g - consumed.fat_g),
    }
}

impl From<&NutritionalGoal> for DayGoal {
    fn from(goal: &NutritionalGoal) -> Self {
        Self {
            source: goal.source,
            totals: Totals {
                calories_kcal: f64::from(goal.calories),
                protein_g: f64::from(goal.protein_g),
                fat_g: f64::from(goal.fat_g),
            },
        }
    }
}

/// Arma el resumen de un día a partir de su meta y sus registros. Función pura.
pub fn build_daily_summary(
    date: NaiveDate,
    goal: &NutritionalGoal,
    day_meals: &[Meal],
) -> DailySummary {
    let goal = DayGoal::from(goal);
    let consumed = sum_meals(day_meals);
    DailySummary {
        date: date.format(crate::validation::DATE_FORMAT).to_string(),
        remaining: remaining(goal.totals, consumed),
        goal,
        consumed,
    }
}

/// Último milisegundo del día `date` en la zona `offset`.
pub fn end_of_day(date: NaiveDate, offset: FixedOffset) -> DateTime {
    let next_day = date.checked_add_days(Days::new(1)).unwrap_or(date);
    let millis = next_day
        .and_time(NaiveTime::MIN)
        .and_local_timezone(offset)
        .earliest()
        .map_or(i64::MAX, |start| start.timestamp_millis() - 1);
    DateTime::from_millis(millis)
}

/// HU-10 — `GET /users/me/summary/daily?date=`. Valida la fecha, toma la meta vigente ese día y suma los registros.
pub async fn get_daily_summary(
    db: &Database,
    user_id: ObjectId,
    offset: FixedOffset,
    date: Option<String>,
) -> Result<DailySummary, AppError> {
    let date = meals::validate_date(date)?;
    let goal = goals::get_goal_at(db, user_id, end_of_day(date, offset)).await?;
    let day_meals = meals::find_meals_by_date(db, user_id, date).await?;
    Ok(build_daily_summary(date, &goal, &day_meals))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn day() -> NaiveDate {
        NaiveDate::from_ymd_opt(2026, 10, 16).unwrap()
    }

    fn meal(calories_kcal: f64, protein_g: f64, fat_g: f64) -> Meal {
        Meal {
            id: ObjectId::new(),
            user_id: ObjectId::new(),
            photo_id: None,
            eaten_at: DateTime::now(),
            date: "2026-10-16".to_string(),
            calories_kcal,
            protein_g,
            fat_g,
        }
    }

    fn goal(source: GoalSource) -> NutritionalGoal {
        NutritionalGoal {
            id: ObjectId::new(),
            user_id: ObjectId::new(),
            calories: 2200,
            protein_g: 160,
            fat_g: 70,
            source,
            set_by: None,
            effective_from: DateTime::now(),
            created_at: DateTime::now(),
        }
    }

    #[test]
    fn un_dia_sin_registros_consume_cero_y_el_restante_es_la_meta() {
        let summary = build_daily_summary(day(), &goal(GoalSource::System), &[]);
        assert_eq!(summary.date, "2026-10-16");
        assert_eq!(
            summary.consumed,
            Totals {
                calories_kcal: 0.0,
                protein_g: 0.0,
                fat_g: 0.0
            }
        );
        assert_eq!(summary.remaining, summary.goal.totals);
    }

    #[test]
    fn un_dia_sin_registros_no_devuelve_cero_negativo() {
        let consumed = sum_meals(&[]);
        for value in [consumed.calories_kcal, consumed.protein_g, consumed.fat_g] {
            assert!(value.is_sign_positive(), "se esperaba 0 y llegó -0");
        }
        let exact = remaining(consumed, consumed);
        assert!(exact.calories_kcal.is_sign_positive());
    }

    #[test]
    fn suma_los_registros_y_resta_de_la_meta() {
        let meals = [meal(600.0, 40.0, 20.0), meal(450.5, 30.0, 15.5)];
        let summary = build_daily_summary(day(), &goal(GoalSource::System), &meals);
        assert_eq!(
            summary.consumed,
            Totals {
                calories_kcal: 1050.5,
                protein_g: 70.0,
                fat_g: 35.5
            }
        );
        assert_eq!(
            summary.remaining,
            Totals {
                calories_kcal: 1149.5,
                protein_g: 90.0,
                fat_g: 34.5
            }
        );
    }

    #[test]
    fn el_restante_es_negativo_cuando_el_consumo_supera_la_meta() {
        let meals = [meal(2350.0, 150.0, 80.0)];
        let summary = build_daily_summary(day(), &goal(GoalSource::System), &meals);
        assert_eq!(
            summary.remaining,
            Totals {
                calories_kcal: -150.0,
                protein_g: 10.0,
                fat_g: -10.0
            }
        );
    }

    #[test]
    fn redondea_a_un_decimal_sin_ruido_de_punto_flotante() {
        let meals = [meal(0.1, 0.2, 0.7), meal(0.2, 0.1, 0.1)];
        let consumed = sum_meals(&meals);
        assert_eq!(
            consumed,
            Totals {
                calories_kcal: 0.3,
                protein_g: 0.3,
                fat_g: 0.8
            }
        );
    }

    #[test]
    fn el_origen_de_la_meta_se_conserva() {
        let from_coach = build_daily_summary(day(), &goal(GoalSource::Coach), &[]);
        assert_eq!(from_coach.goal.source, GoalSource::Coach);
        let calculated = build_daily_summary(day(), &goal(GoalSource::System), &[]);
        assert_eq!(calculated.goal.source, GoalSource::System);
    }

    #[test]
    fn el_dia_termina_un_milisegundo_antes_de_la_medianoche_local() {
        let mexico = FixedOffset::west_opt(6 * 3600).unwrap();
        // 2026-10-16 23:59:59.999 (UTC-6) = 2026-10-17 05:59:59.999 UTC
        let expected = chrono::DateTime::parse_from_rfc3339("2026-10-17T05:59:59.999Z")
            .unwrap()
            .timestamp_millis();
        assert_eq!(end_of_day(day(), mexico).timestamp_millis(), expected);

        let utc = FixedOffset::east_opt(0).unwrap();
        let expected = chrono::DateTime::parse_from_rfc3339("2026-10-16T23:59:59.999Z")
            .unwrap()
            .timestamp_millis();
        assert_eq!(end_of_day(day(), utc).timestamp_millis(), expected);
    }
}
