//! HU-22 — series de progreso del usuario (peso, macros diarios vs meta y cumplimiento).
//! HU-23 — progreso histórico de un cliente para el coach (reutiliza este servicio).

use chrono::{Days, FixedOffset, NaiveDate};
use mongodb::{
    Database,
    bson::{DateTime, doc, oid::ObjectId},
};
use serde::Serialize;
use std::collections::HashMap;

use crate::error::{AppError, FieldErrors};
use crate::models::weight_entry::WeightEntry;
use crate::services::{
    goals, meals, profile,
    summary::{self, DailySummary},
};
use crate::validation::parse_date;

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

    let start_dt = summary::end_of_day(from_date, offset);
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
        let key = date.format(crate::validation::DATE_FORMAT).to_string();
        let day_meals = by_date.get(&key).map_or(&[][..], Vec::as_slice);
        let daily_summary = summary::build_daily_summary(*date, &goal, day_meals);
        daily.push(daily_summary);
    }

    let profile = profile::get_profile(db, user_id).await.ok();
    let training_days = profile.map_or(3, |p| p.training_days);

    let mut compliance = Vec::new();
    let mut week_start = from_date;
    while week_start <= to_date {
        let week_end = week_start.checked_add_days(Days::new(6)).unwrap_or(to_date);
        let effective_end = if week_end > to_date {
            to_date
        } else {
            week_end
        };

        compliance.push(WeeklyCompliance {
            start: week_start
                .format(crate::validation::DATE_FORMAT)
                .to_string(),
            end: effective_end
                .format(crate::validation::DATE_FORMAT)
                .to_string(),
            training_days,
            completed_sessions: 0,
        });
        week_start = week_start
            .checked_add_days(Days::new(7))
            .unwrap_or(week_start);
    }

    Ok(ProgressResponse {
        weights: weights_resp,
        daily,
        compliance,
    })
}
