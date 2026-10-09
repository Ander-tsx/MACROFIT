use mongodb::{
    Database,
    bson::{DateTime, doc, oid::ObjectId},
};

use crate::error::{AppError, FieldErrors};
use crate::models::profile::{Gender, Objective, PROFILES_COLLECTION, UserProfile};
use crate::models::user::USERS_COLLECTION;
use crate::services::goals;

#[derive(Debug, Default)]
pub struct ProfileInput {
    pub weight_kg: Option<f64>,
    pub height_cm: Option<f64>,
    pub birth_date: Option<String>,
    pub gender: Option<String>,
    pub training_days: Option<i32>,
    pub objective: Option<String>,
}

fn parse_birth_date(s: &str) -> Option<DateTime> {
    if let Ok(dt) = DateTime::parse_rfc3339_str(s) {
        return Some(dt);
    }
    if s.len() == 10 {
        let full = format!("{s}T00:00:00Z");
        if let Ok(dt) = DateTime::parse_rfc3339_str(&full) {
            return Some(dt);
        }
    }
    None
}

fn parse_gender(s: &str) -> Option<Gender> {
    match s {
        "male" => Some(Gender::Male),
        "female" => Some(Gender::Female),
        _ => None,
    }
}

fn parse_objective(s: &str) -> Option<Objective> {
    match s {
        "lose_fat" => Some(Objective::LoseFat),
        "maintain" => Some(Objective::Maintain),
        "gain_muscle" => Some(Objective::GainMuscle),
        _ => None,
    }
}

pub struct ValidProfileInput {
    pub weight_kg: f64,
    pub height_cm: f64,
    pub birth_date: DateTime,
    pub gender: Gender,
    pub training_days: i32,
    pub objective: Objective,
}

pub fn validate_profile_input(input: &ProfileInput) -> Result<ValidProfileInput, AppError> {
    let mut fields = FieldErrors::new();

    let weight_kg = match input.weight_kg {
        Some(w) if (20.0..=300.0).contains(&w) => Some(w),
        Some(_) => {
            fields.insert("weight_kg".to_string(), "Peso fuera de rango".to_string());
            None
        }
        None => {
            fields.insert("weight_kg".to_string(), "El peso es obligatorio".to_string());
            None
        }
    };

    let height_cm = match input.height_cm {
        Some(h) if (50.0..=250.0).contains(&h) => Some(h),
        Some(_) => {
            fields.insert("height_cm".to_string(), "Estatura fuera de rango".to_string());
            None
        }
        None => {
            fields.insert("height_cm".to_string(), "La estatura es obligatoria".to_string());
            None
        }
    };

    let birth_date = match input.birth_date.as_deref() {
        Some(b) => match parse_birth_date(b) {
            Some(dt) => Some(dt),
            None => {
                fields.insert(
                    "birth_date".to_string(),
                    "Fecha de nacimiento inválida".to_string(),
                );
                None
            }
        },
        None => {
            fields.insert(
                "birth_date".to_string(),
                "La fecha de nacimiento es obligatoria".to_string(),
            );
            None
        }
    };

    let gender = match input.gender.as_deref() {
        Some(g) => match parse_gender(g) {
            Some(g_val) => Some(g_val),
            None => {
                fields.insert("gender".to_string(), "Género inválido".to_string());
                None
            }
        },
        None => {
            fields.insert("gender".to_string(), "El género es obligatorio".to_string());
            None
        }
    };

    let training_days = match input.training_days {
        Some(d) if (1..=7).contains(&d) => Some(d),
        Some(_) => {
            fields.insert(
                "training_days".to_string(),
                "Días de entrenamiento deben estar entre 1 y 7".to_string(),
            );
            None
        }
        None => {
            fields.insert(
                "training_days".to_string(),
                "Los días de entrenamiento son obligatorios".to_string(),
            );
            None
        }
    };

    let objective = match input.objective.as_deref() {
        Some(o) => match parse_objective(o) {
            Some(obj) => Some(obj),
            None => {
                fields.insert("objective".to_string(), "Objetivo inválido".to_string());
                None
            }
        },
        None => {
            fields.insert("objective".to_string(), "El objetivo es obligatorio".to_string());
            None
        }
    };

    if !fields.is_empty() {
        return Err(AppError::Validation(fields));
    }

    Ok(ValidProfileInput {
        weight_kg: weight_kg.unwrap(),
        height_cm: height_cm.unwrap(),
        birth_date: birth_date.unwrap(),
        gender: gender.unwrap(),
        training_days: training_days.unwrap(),
        objective: objective.unwrap(),
    })
}

pub async fn get_profile(db: &Database, user_id: ObjectId) -> Result<UserProfile, AppError> {
    db.collection::<UserProfile>(PROFILES_COLLECTION)
        .find_one(doc! { "user_id": user_id })
        .await
        .map_err(AppError::internal)?
        .ok_or(AppError::ProfileNotFound)
}

pub async fn save_or_update_profile(
    db: &Database,
    user_id: ObjectId,
    input: ProfileInput,
) -> Result<UserProfile, AppError> {
    let valid = validate_profile_input(&input)?;
    let now = DateTime::now();

    let existing = db
        .collection::<UserProfile>(PROFILES_COLLECTION)
        .find_one(doc! { "user_id": user_id })
        .await
        .map_err(AppError::internal)?;

    let profile = match existing {
        Some(mut prof) => {
            prof.weight_kg = valid.weight_kg;
            prof.height_cm = valid.height_cm;
            prof.birth_date = valid.birth_date;
            prof.gender = valid.gender;
            prof.training_days = valid.training_days;
            prof.objective = valid.objective;
            prof.updated_at = now;

            db.collection::<UserProfile>(PROFILES_COLLECTION)
                .replace_one(doc! { "_id": prof.id }, &prof)
                .await
                .map_err(AppError::internal)?;

            prof
        }
        None => {
            let prof = UserProfile {
                id: ObjectId::new(),
                user_id,
                weight_kg: valid.weight_kg,
                height_cm: valid.height_cm,
                birth_date: valid.birth_date,
                gender: valid.gender,
                training_days: valid.training_days,
                objective: valid.objective,
                created_at: now,
                updated_at: now,
            };

            db.collection::<UserProfile>(PROFILES_COLLECTION)
                .insert_one(&prof)
                .await
                .map_err(AppError::internal)?;

            // Actualizar profile_completed en el usuario
            db.collection::<mongodb::bson::Document>(USERS_COLLECTION)
                .update_one(
                    doc! { "_id": user_id },
                    doc! { "$set": { "profile_completed": true } },
                )
                .await
                .map_err(AppError::internal)?;

            prof
        }
    };

    // Recalcular meta si corresponde
    goals::recalculate_on_profile_change(db, &profile).await?;

    Ok(profile)
}
