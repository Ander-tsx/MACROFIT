//! HU-22 — series de progreso del usuario (peso, macros diarios vs meta y cumplimiento).
//! HU-23 — progreso histórico de un cliente para el coach (reutiliza este servicio).

use chrono::{Days, FixedOffset, NaiveDate};
use mongodb::{
    Database,
    bson::{DateTime, Document, doc, oid::ObjectId},
};
use serde::Serialize;
use std::collections::HashMap;

use crate::error::{AppError, FieldErrors};
use crate::models::routine_session::ROUTINE_SESSIONS_COLLECTION;
use crate::models::weight_entry::WeightEntry;
use crate::services::{
    goals, meals, profile,
    summary::{self, DailySummary},
};
use crate::validation::{DATE_FORMAT, parse_date, start_of_day};

/// Rango máximo permitido de días (93 días = aprox. 3 meses).
pub const MAX_PROGRESS_DAYS: i64 = 93;

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
pub struct WeightProgressItem {
    pub id: String,
    pub user_id: String,
    pub weight_kg: f64,
    pub recorded_at: String,
}

impl From<WeightEntry> for WeightProgressItem {
    fn from(entry: WeightEntry) -> Self {
        Self {
            id: entry.id.to_hex(),
            user_id: entry.user_id.to_hex(),
            weight_kg: entry.weight_kg,
            recorded_at: entry
                .recorded_at
                .try_to_rfc3339_string()
                .unwrap_or_default(),
        }
    }
}

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
pub struct WeeklyCompliance {
    pub start: String,
    pub end: String,
    pub training_days: i32,
    pub completed_sessions: i32,
}

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
pub struct ProgressResponse {
    pub weights: Vec<WeightProgressItem>,
    pub daily: Vec<DailySummary>,
    pub compliance: Vec<WeeklyCompliance>,
}

/// Valida el rango de fechas `from` y `to` (`YYYY-MM-DD`).
pub fn validate_range(
    from: Option<String>,
    to: Option<String>,
) -> Result<(NaiveDate, NaiveDate), AppError> {
    let error = |field: &str, msg: &str| {
        AppError::Validation(FieldErrors::from([(field.to_string(), msg.to_string())]))
    };

    let from_date = match from.as_deref().map(str::trim) {
        None | Some("") => return Err(error("from", "Indica la fecha de inicio (YYYY-MM-DD)")),
        Some(v) => {
            parse_date(v).ok_or_else(|| error("from", "La fecha debe tener el formato YYYY-MM-DD"))
        }
    }?;

    let to_date = match to.as_deref().map(str::trim) {
        None | Some("") => return Err(error("to", "Indica la fecha de fin (YYYY-MM-DD)")),
        Some(v) => {
            parse_date(v).ok_or_else(|| error("to", "La fecha debe tener el formato YYYY-MM-DD"))
        }
    }?;

    if from_date > to_date {
        return Err(error(
            "from",
            "La fecha de inicio no puede ser posterior a la de fin",
        ));
    }

    let diff = to_date.signed_duration_since(from_date).num_days();
    if diff > MAX_PROGRESS_DAYS {
        return Err(error("to", "El rango no puede superar los 93 días"));
    }

    Ok((from_date, to_date))
}

/// Obtiene el progreso completo del usuario en el rango indicado.
pub async fn get_progress(
    db: &Database,
    user_id: ObjectId,
    offset: FixedOffset,
    from: Option<String>,
    to: Option<String>,
) -> Result<ProgressResponse, AppError> {
    let (from_date, to_date) = validate_range(from, to)?;

    // Desde las 00:00 de México del primer día hasta el último instante del último (`APP_UTC_OFFSET`).
    let start_dt = start_of_day(from_date, offset);
    let end_dt = summary::end_of_day(to_date, offset);

    let weights_cursor = db
        .collection::<WeightEntry>(crate::models::weight_entry::WEIGHTS_COLLECTION)
        .find(doc! {
            "user_id": user_id,
            "recorded_at": { "$gte": start_dt, "$lte": end_dt }
        })
        .sort(doc! { "recorded_at": 1, "_id": 1 })
        .await
        .map_err(AppError::internal)?;
    let weights = crate::db::collect_cursor(weights_cursor).await?;
    let weights_resp = weights.into_iter().map(WeightProgressItem::from).collect();

    let mut current = from_date;
    let mut dates = Vec::new();
    while current <= to_date {
        dates.push(current);
        current = current.checked_add_days(Days::new(1)).unwrap_or(current);
    }

    let ends: Vec<DateTime> = dates
        .iter()
        .map(|d| summary::end_of_day(*d, offset))
        .collect();
    let day_goals = goals::get_goals_at(db, user_id, &ends).await?;
    let week_meals = meals::find_meals_between(db, user_id, from_date, to_date).await?;

    let mut by_date: HashMap<String, Vec<crate::models::meal::Meal>> = HashMap::new();
    for meal in week_meals {
        by_date.entry(meal.date.clone()).or_default().push(meal);
    }

    let mut daily = Vec::new();
    for (date, goal) in dates.iter().zip(day_goals) {
        let key = date.format(DATE_FORMAT).to_string();
        let day_meals = by_date.get(&key).map_or(&[][..], Vec::as_slice);
        let daily_summary = summary::build_daily_summary(*date, &goal, day_meals);
        daily.push(daily_summary);
    }

    let profile = profile::get_profile(db, user_id).await.ok();
    let training_days = profile.map_or(3, |p| p.training_days);

    let session_dates = completed_session_dates(db, user_id, from_date, to_date).await?;
    let compliance = build_compliance(from_date, to_date, training_days, &session_dates);

    Ok(ProgressResponse {
        weights: weights_resp,
        daily,
        compliance,
    })
}

/// Días (`date`, hora de México) de las sesiones de rutina que el usuario completó entre `from` y `to` (HU-17).
///
/// `routine_sessions.date` es `YYYY-MM-DD`, así que comparar textos equivale a comparar fechas y usa el índice
/// `user_id_date`. Cuentan las de la recomendada y las de las asignadas, aunque la rutina ya no sea accesible
/// (regenerada, retirada o de un coach desvinculado): RF-24 las conserva para el cumplimiento.
async fn completed_session_dates(
    db: &Database,
    user_id: ObjectId,
    from: NaiveDate,
    to: NaiveDate,
) -> Result<Vec<NaiveDate>, AppError> {
    let cursor = db
        .collection::<Document>(ROUTINE_SESSIONS_COLLECTION)
        .find(doc! {
            "user_id": user_id,
            "date": {
                "$gte": from.format(DATE_FORMAT).to_string(),
                "$lte": to.format(DATE_FORMAT).to_string(),
            },
        })
        .projection(doc! { "_id": 0, "date": 1 })
        .await
        .map_err(AppError::internal)?;
    let docs = crate::db::collect_cursor(cursor).await?;
    Ok(docs
        .iter()
        .filter_map(|d| d.get_str("date").ok().and_then(parse_date))
        .collect())
}

/// Cumplimiento por bloques de 7 días desde `from` (el último puede ser más corto): cuántas sesiones completadas
/// caen en cada bloque, contra los días de entrenamiento del perfil (HU-22, RF-16).
pub fn build_compliance(
    from: NaiveDate,
    to: NaiveDate,
    training_days: i32,
    session_dates: &[NaiveDate],
) -> Vec<WeeklyCompliance> {
    let mut compliance = Vec::new();
    let mut week_start = from;
    while week_start <= to {
        let week_end = week_start
            .checked_add_days(Days::new(6))
            .map_or(to, |end| end.min(to));
        let completed = session_dates
            .iter()
            .filter(|d| (week_start..=week_end).contains(d))
            .count();

        compliance.push(WeeklyCompliance {
            start: week_start.format(DATE_FORMAT).to_string(),
            end: week_end.format(DATE_FORMAT).to_string(),
            training_days,
            completed_sessions: i32::try_from(completed).unwrap_or(i32::MAX),
        });
        match week_end.checked_add_days(Days::new(1)) {
            Some(next) => week_start = next,
            None => break,
        }
    }
    compliance
}

#[cfg(test)]
mod tests {
    use super::*;

    fn day(value: &str) -> NaiveDate {
        parse_date(value).unwrap()
    }

    fn counts(compliance: &[WeeklyCompliance]) -> Vec<(&str, &str, i32)> {
        compliance
            .iter()
            .map(|w| (w.start.as_str(), w.end.as_str(), w.completed_sessions))
            .collect()
    }

    #[test]
    fn el_cumplimiento_cuenta_las_sesiones_completadas_de_cada_semana() {
        let sessions = [
            day("2026-11-11"),
            day("2026-11-13"),
            day("2026-11-13"), // dos rutinas distintas el mismo día cuentan dos veces
            day("2026-11-17"),
            day("2026-11-18"),
        ];
        let compliance = build_compliance(day("2026-11-11"), day("2026-11-24"), 4, &sessions);
        assert_eq!(
            counts(&compliance),
            vec![
                ("2026-11-11", "2026-11-17", 4),
                ("2026-11-18", "2026-11-24", 1)
            ]
        );
        assert!(compliance.iter().all(|w| w.training_days == 4));
    }

    #[test]
    fn la_ultima_semana_parcial_tambien_cuenta_y_las_fechas_fuera_del_rango_no() {
        let sessions = [
            day("2026-11-10"), // antes de `from`
            day("2026-11-19"),
            day("2026-11-20"),
            day("2026-11-21"), // después de `to`
        ];
        let compliance = build_compliance(day("2026-11-11"), day("2026-11-20"), 3, &sessions);
        assert_eq!(
            counts(&compliance),
            vec![
                ("2026-11-11", "2026-11-17", 0),
                ("2026-11-18", "2026-11-20", 2)
            ]
        );
    }

    #[test]
    fn sin_sesiones_completadas_el_cumplimiento_es_cero() {
        let compliance = build_compliance(day("2026-11-17"), day("2026-11-17"), 5, &[]);
        assert_eq!(counts(&compliance), vec![("2026-11-17", "2026-11-17", 0)]);
        assert_eq!(compliance[0].training_days, 5);
    }

    /// Campo y mensaje del error de `validate_range`.
    fn range_error(from: Option<&str>, to: Option<&str>) -> (String, String) {
        match validate_range(from.map(String::from), to.map(String::from)) {
            Err(AppError::Validation(fields)) => {
                assert_eq!(fields.len(), 1, "un solo campo señalado: {fields:?}");
                fields.into_iter().next().unwrap()
            }
            other => panic!("se esperaba VALIDATION_ERROR, llegó {other:?}"),
        }
    }

    #[test]
    fn el_rango_valido_devuelve_las_dos_fechas() {
        assert_eq!(
            validate_range(Some("2026-11-01".into()), Some(" 2026-11-30 ".into())).unwrap(),
            (day("2026-11-01"), day("2026-11-30"))
        );
        assert_eq!(
            validate_range(Some("2026-11-17".into()), Some("2026-11-17".into())).unwrap(),
            (day("2026-11-17"), day("2026-11-17"))
        );
    }

    #[test]
    fn las_fechas_ausentes_o_vacias_se_senalan() {
        assert_eq!(range_error(None, Some("2026-11-30")).0, "from");
        assert_eq!(range_error(Some("  "), Some("2026-11-30")).0, "from");
        assert_eq!(range_error(Some("2026-11-01"), None).0, "to");
        assert_eq!(range_error(Some("2026-11-01"), Some("")).0, "to");
    }

    #[test]
    fn las_fechas_con_formato_invalido_se_senalan() {
        for value in ["17/11/2026", "2026-13-01", "2026-02-30", "hoy"] {
            assert_eq!(
                range_error(Some(value), Some("2026-11-30")),
                (
                    "from".to_string(),
                    "La fecha debe tener el formato YYYY-MM-DD".to_string()
                )
            );
            assert_eq!(range_error(Some("2026-11-01"), Some(value)).0, "to");
        }
    }

    #[test]
    fn el_inicio_posterior_al_fin_se_rechaza() {
        assert_eq!(
            range_error(Some("2026-11-18"), Some("2026-11-17")),
            (
                "from".to_string(),
                "La fecha de inicio no puede ser posterior a la de fin".to_string()
            )
        );
    }

    #[test]
    fn el_rango_admite_93_dias_y_no_mas() {
        // 2026-08-01 + 93 días = 2026-11-02.
        assert!(validate_range(Some("2026-08-01".into()), Some("2026-11-02".into())).is_ok());
        assert_eq!(
            range_error(Some("2026-08-01"), Some("2026-11-03")),
            (
                "to".to_string(),
                "El rango no puede superar los 93 días".to_string()
            )
        );
    }

    /// Pruebas contra MongoDB real: `cargo test -- --ignored` con un servidor local
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::models::profile::{Gender, Level, Objective, PROFILES_COLLECTION, UserProfile};
        use crate::models::routine_session::{RoutineOrigin, RoutineSession};

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn with_profile(db: &Database, user_id: ObjectId, training_days: i32) {
            let now = DateTime::now();
            db.collection::<UserProfile>(PROFILES_COLLECTION)
                .insert_one(UserProfile {
                    id: ObjectId::new(),
                    user_id,
                    objective: Objective::Maintain,
                    level: Level::Intermediate,
                    training_days,
                    weight_kg: 70.0,
                    height_cm: 170.0,
                    gender: Gender::Female,
                    birth_date: DateTime::from_millis(0),
                    created_at: now,
                    updated_at: now,
                })
                .await
                .unwrap();
        }

        async fn session(db: &Database, user_id: ObjectId, origin: RoutineOrigin, date: &str) {
            db.collection::<RoutineSession>(ROUTINE_SESSIONS_COLLECTION)
                .insert_one(RoutineSession {
                    id: ObjectId::new(),
                    user_id,
                    routine_id: ObjectId::new(),
                    origin,
                    coach_id: None,
                    assignment_id: None,
                    routine_name: "Rutina".into(),
                    session_number: 1,
                    session_name: "Día 1".into(),
                    date: date.into(),
                    completed_at: DateTime::now(),
                })
                .await
                .unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn el_progreso_cuenta_las_sesiones_completadas_del_usuario_en_el_rango() {
            let db = test_db().await;
            let ana = ObjectId::new();
            let otro = ObjectId::new();
            with_profile(&db, ana, 4).await;
            session(&db, ana, RoutineOrigin::System, "2026-11-16").await;
            session(&db, ana, RoutineOrigin::Coach, "2026-11-17").await;
            session(&db, ana, RoutineOrigin::Coach, "2026-11-18").await; // semana siguiente
            session(&db, ana, RoutineOrigin::System, "2026-11-01").await; // fuera del rango
            session(&db, otro, RoutineOrigin::System, "2026-11-17").await; // de otro usuario

            let offset = FixedOffset::west_opt(6 * 3600).unwrap();
            let progress = get_progress(
                &db,
                ana,
                offset,
                Some("2026-11-11".into()),
                Some("2026-11-20".into()),
            )
            .await
            .unwrap();
            assert_eq!(
                counts(&progress.compliance),
                vec![
                    ("2026-11-11", "2026-11-17", 2),
                    ("2026-11-18", "2026-11-20", 1)
                ]
            );
            assert!(progress.compliance.iter().all(|w| w.training_days == 4));
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn los_pesos_del_primer_y_ultimo_dia_del_rango_se_incluyen() {
            let db = test_db().await;
            let ana = ObjectId::new();
            with_profile(&db, ana, 4).await;
            let offset = FixedOffset::west_opt(6 * 3600).unwrap();
            let at = |utc: &str| {
                DateTime::from_millis(
                    chrono::DateTime::parse_from_rfc3339(utc)
                        .unwrap()
                        .timestamp_millis(),
                )
            };
            // Hora de México (−06:00): 06:00Z es la medianoche local.
            let pesos = [
                ("2026-11-11T05:59:59Z", 70.0), // 10/11 a las 23:59 locales: antes del rango
                ("2026-11-11T06:00:00Z", 71.0), // 11/11 a las 00:00 locales: primer día
                ("2026-11-11T18:00:00Z", 72.0), // 11/11 a mediodía: primer día
                ("2026-11-21T05:59:59Z", 73.0), // 20/11 a las 23:59 locales: último día
                ("2026-11-21T06:00:00Z", 74.0), // 21/11 a las 00:00 locales: después del rango
            ];
            db.collection::<WeightEntry>(crate::models::weight_entry::WEIGHTS_COLLECTION)
                .insert_many(pesos.iter().map(|(utc, weight_kg)| WeightEntry {
                    id: ObjectId::new(),
                    user_id: ana,
                    weight_kg: *weight_kg,
                    recorded_at: at(utc),
                }))
                .await
                .unwrap();

            let progress = get_progress(
                &db,
                ana,
                offset,
                Some("2026-11-11".into()),
                Some("2026-11-20".into()),
            )
            .await
            .unwrap();
            let weights: Vec<f64> = progress.weights.iter().map(|w| w.weight_kg).collect();
            assert_eq!(weights, vec![71.0, 72.0, 73.0]);
            db.drop().await.unwrap();
        }
    }
}
