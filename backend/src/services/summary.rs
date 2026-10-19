//! HU-10 — resumen diario contra la meta (RF-09).
//!
//! - El día se define como en HU-09: con la zona horaria fija de la app (`APP_UTC_OFFSET`), filtrando por el
//!   campo `date` de cada registro.
//! - La meta es la vigente al final de ese día (`goals::get_goal_at`, la misma regla que `GET /users/me/goals/current`).
//! - `remaining` = meta − consumido. Si el consumo supera la meta es **negativo** (por ejemplo `-150` = se pasó por 150).
//! - Los valores se redondean a 1 decimal para que la suma de decimales binarios no deje ruido (`0.1 + 0.2`).
//!
//! HU-11 — resumen semanal (RF-10), sobre el mismo cálculo diario:
//!
//! - `start` es cualquier día; la semana son los 7 días desde ahí. Cada día usa su propia meta vigente (RF-21).
//! - Un día **cumple la meta** si consumió calorías y estas quedan entre el 90 % y el 110 % de la meta de ese día.
//! - El promedio es el total de los 7 días entre 7: un día sin registros cuenta como 0.

use chrono::{Days, FixedOffset, NaiveDate, NaiveTime};
use mongodb::{
    Database,
    bson::{DateTime, oid::ObjectId},
};
use std::collections::HashMap;

use crate::error::{AppError, FieldErrors};
use crate::models::goal::{GoalSource, NutritionalGoal};
use crate::models::meal::Meal;
use crate::services::{goals, meals};
use crate::validation::{DATE_FORMAT, parse_date};

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
        date: date.format(DATE_FORMAT).to_string(),
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

// ───────────────────────────── HU-11 · Resumen semanal ─────────────────────────────

/// Días de una semana de resumen.
pub const WEEK_DAYS: usize = 7;

/// Un día de la semana: su resumen diario y si cumplió la meta.
#[derive(Debug, Clone, PartialEq)]
pub struct WeekDay {
    pub summary: DailySummary,
    pub goal_met: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct WeeklySummary {
    /// Primer día, `YYYY-MM-DD`.
    pub start: String,
    /// Último día (el sexto después de `start`), `YYYY-MM-DD`.
    pub end: String,
    pub days: Vec<WeekDay>,
    /// Total de los 7 días entre 7; los días sin registros cuentan como 0.
    pub average: Totals,
    /// Cuántos de los 7 días cumplieron la meta.
    pub goal_met_days: usize,
}

/// Un día cumple la meta si consumió calorías y estas están entre el 90 % y el 110 % de la meta (límites incluidos).
/// Se compara en enteros (×10) para que 1800 y 2200 con una meta de 2000 queden dentro sin error de punto flotante.
pub fn goal_met(goal_kcal: f64, consumed_kcal: f64) -> bool {
    consumed_kcal > 0.0
        && consumed_kcal * 10.0 >= goal_kcal * 9.0
        && consumed_kcal * 10.0 <= goal_kcal * 11.0
}

/// Los 7 días que empiezan en `start`; `None` si se sale del calendario.
pub fn week_dates(start: NaiveDate) -> Option<[NaiveDate; WEEK_DAYS]> {
    let mut dates = [start; WEEK_DAYS];
    for (offset, date) in dates.iter_mut().enumerate() {
        *date = start.checked_add_days(Days::new(offset as u64))?;
    }
    Some(dates)
}

/// Arma la semana a partir de la meta vigente de cada día y de los registros de toda la semana. Función pura.
pub fn build_weekly_summary(
    days: &[(NaiveDate, NutritionalGoal); WEEK_DAYS],
    week_meals: &[Meal],
) -> WeeklySummary {
    let mut by_date: HashMap<&str, Vec<Meal>> = HashMap::new();
    for meal in week_meals {
        by_date
            .entry(meal.date.as_str())
            .or_default()
            .push(meal.clone());
    }

    let week_days: Vec<WeekDay> = days
        .iter()
        .map(|(date, goal)| {
            let key = date.format(DATE_FORMAT).to_string();
            let day_meals = by_date.get(key.as_str()).map_or(&[][..], Vec::as_slice);
            let summary = build_daily_summary(*date, goal, day_meals);
            let goal_met = goal_met(
                summary.goal.totals.calories_kcal,
                summary.consumed.calories_kcal,
            );
            WeekDay { summary, goal_met }
        })
        .collect();

    let total = |value: fn(&Totals) -> f64| {
        round1(
            week_days
                .iter()
                .map(|day| value(&day.summary.consumed))
                .sum::<f64>()
                / WEEK_DAYS as f64,
        )
    };
    WeeklySummary {
        start: days[0].0.format(DATE_FORMAT).to_string(),
        end: days[WEEK_DAYS - 1].0.format(DATE_FORMAT).to_string(),
        average: Totals {
            calories_kcal: total(|t| t.calories_kcal),
            protein_g: total(|t| t.protein_g),
            fat_g: total(|t| t.fat_g),
        },
        goal_met_days: week_days.iter().filter(|day| day.goal_met).count(),
        days: week_days,
    }
}

/// HU-11 — valida `?start=`: obligatorio y con formato `YYYY-MM-DD`; el error señala el campo `start`.
pub fn validate_start(start: Option<String>) -> Result<NaiveDate, AppError> {
    let error = |message: &str| {
        AppError::Validation(FieldErrors::from([(
            "start".to_string(),
            message.to_string(),
        )]))
    };
    match start.as_deref().map(str::trim) {
        None | Some("") => Err(error("Indica el primer día de la semana (YYYY-MM-DD)")),
        Some(value) => parse_date(value)
            .filter(|date| week_dates(*date).is_some())
            .ok_or_else(|| error("La fecha debe tener el formato YYYY-MM-DD")),
    }
}

/// HU-11 — `GET /users/me/summary/weekly?start=`. Una consulta para las metas y otra para los registros de la semana.
pub async fn get_weekly_summary(
    db: &Database,
    user_id: ObjectId,
    offset: FixedOffset,
    start: Option<String>,
) -> Result<WeeklySummary, AppError> {
    let start = validate_start(start)?;
    let dates =
        week_dates(start).ok_or_else(|| AppError::internal("la semana se sale del calendario"))?;
    let ends = dates.map(|date| end_of_day(date, offset));
    let day_goals = goals::get_goals_at(db, user_id, &ends).await?;
    let week_meals = meals::find_meals_between(db, user_id, dates[0], dates[WEEK_DAYS - 1]).await?;

    let days: Vec<(NaiveDate, NutritionalGoal)> = dates.into_iter().zip(day_goals).collect();
    let days: [(NaiveDate, NutritionalGoal); WEEK_DAYS] = days
        .try_into()
        .map_err(|_| AppError::internal("faltan metas para la semana"))?;
    Ok(build_weekly_summary(&days, &week_meals))
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
            estimated: None,
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
    // ───────────── HU-11 ─────────────

    fn week_goals(calories: i32) -> [(NaiveDate, NutritionalGoal); WEEK_DAYS] {
        let dates = week_dates(day()).unwrap();
        dates.map(|date| {
            let mut g = goal(GoalSource::System);
            g.calories = calories;
            (date, g)
        })
    }

    fn meal_on(date: &str, calories_kcal: f64, protein_g: f64, fat_g: f64) -> Meal {
        let mut m = meal(calories_kcal, protein_g, fat_g);
        m.date = date.to_string();
        m
    }

    #[test]
    fn la_semana_son_siete_dias_seguidos_aunque_cambie_el_mes() {
        let dates = week_dates(NaiveDate::from_ymd_opt(2026, 10, 29).unwrap()).unwrap();
        let text: Vec<String> = dates
            .iter()
            .map(|d| d.format(DATE_FORMAT).to_string())
            .collect();
        assert_eq!(
            text,
            [
                "2026-10-29",
                "2026-10-30",
                "2026-10-31",
                "2026-11-01",
                "2026-11-02",
                "2026-11-03",
                "2026-11-04"
            ]
        );
    }

    #[test]
    fn una_semana_que_se_sale_del_calendario_se_rechaza() {
        assert!(week_dates(NaiveDate::MAX).is_none());
        assert!(validate_start(Some(NaiveDate::MAX.format(DATE_FORMAT).to_string())).is_err());
    }

    #[test]
    fn la_meta_se_cumple_entre_el_90_y_el_110_por_ciento_con_limites_incluidos() {
        assert!(goal_met(2000.0, 1800.0));
        assert!(goal_met(2000.0, 2000.0));
        assert!(goal_met(2000.0, 2200.0));
        assert!(!goal_met(2000.0, 1799.9));
        assert!(!goal_met(2000.0, 2200.1));
    }

    #[test]
    fn sin_consumo_la_meta_nunca_se_cumple() {
        assert!(!goal_met(2000.0, 0.0));
        assert!(!goal_met(0.0, 0.0));
    }

    #[test]
    fn el_promedio_cuenta_los_dias_sin_registros_como_cero() {
        let meals = [meal_on("2026-10-16", 700.0, 70.0, 7.0)];
        let week = build_weekly_summary(&week_goals(2000), &meals);
        assert_eq!(week.days.len(), 7);
        assert_eq!(
            week.average,
            Totals {
                calories_kcal: 100.0,
                protein_g: 10.0,
                fat_g: 1.0
            }
        );
        assert_eq!(week.days[1].summary.consumed.calories_kcal, 0.0);
    }

    #[test]
    fn cuenta_los_dias_que_cumplen_la_meta_y_marca_cada_uno() {
        let meals = [
            meal_on("2026-10-16", 2000.0, 100.0, 50.0),
            meal_on("2026-10-17", 1000.0, 50.0, 25.0),
            meal_on("2026-10-18", 1000.0, 50.0, 25.0),
            meal_on("2026-10-18", 1000.0, 50.0, 25.0),
            meal_on("2026-10-19", 2500.0, 50.0, 25.0),
        ];
        let week = build_weekly_summary(&week_goals(2000), &meals);
        let met: Vec<bool> = week.days.iter().map(|d| d.goal_met).collect();
        assert_eq!(met, [true, false, true, false, false, false, false]);
        assert_eq!(week.goal_met_days, 2);
        assert_eq!(week.days[2].summary.consumed.calories_kcal, 2000.0);
    }

    #[test]
    fn cada_dia_se_compara_con_la_meta_vigente_ese_dia() {
        let mut days = week_goals(2000);
        for (_, g) in days.iter_mut().skip(3) {
            g.calories = 1000;
            g.source = GoalSource::Coach;
        }
        let meals = [
            meal_on("2026-10-17", 2000.0, 1.0, 1.0),
            meal_on("2026-10-20", 2000.0, 1.0, 1.0),
        ];
        let week = build_weekly_summary(&days, &meals);
        assert_eq!(week.days[1].summary.goal.source, GoalSource::System);
        assert!(week.days[1].goal_met);
        assert_eq!(week.days[4].summary.goal.source, GoalSource::Coach);
        assert!(!week.days[4].goal_met);
        assert_eq!(week.days[4].summary.remaining.calories_kcal, -1000.0);
    }

    #[test]
    fn una_semana_vacia_no_devuelve_ceros_negativos() {
        let week = build_weekly_summary(&week_goals(2000), &[]);
        assert_eq!(week.goal_met_days, 0);
        assert!(week.average.calories_kcal.is_sign_positive());
        assert!(week.days.iter().all(|d| !d.goal_met));
    }

    #[test]
    fn start_ausente_o_con_formato_invalido_senala_el_campo_start() {
        for value in [
            None,
            Some(String::new()),
            Some("2026-13-45".to_string()),
            Some("hoy".to_string()),
        ] {
            match validate_start(value) {
                Err(AppError::Validation(fields)) => assert!(fields.contains_key("start")),
                other => panic!("se esperaba VALIDATION_ERROR en start, llegó {other:?}"),
            }
        }
        assert_eq!(
            validate_start(Some(" 2026-10-16 ".to_string())).unwrap(),
            day()
        );
    }
}
