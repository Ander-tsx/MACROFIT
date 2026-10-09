//! HU-03 — perfil inicial del usuario: validación, alta, consulta y edición.

use chrono::{NaiveDate, Utc};
use mongodb::{
    Database,
    bson::{DateTime, Document, doc, oid::ObjectId, to_bson},
    options::ReturnDocument,
};

use crate::error::{AppError, FieldErrors};
use crate::models::profile::{Gender, Level, Objective, PROFILES_COLLECTION, UserProfile};
use crate::models::user::{USERS_COLLECTION, User};
use crate::services::auth::is_duplicate_key;

// TODO(TEC-12): rangos provisionales; ajustarlos cuando TEC-12 defina los definitivos
// (y también en `macrofit_app/lib/features/profile/domain/validators/profile_validators.dart`).
pub const WEIGHT_MIN_KG: f64 = 30.0;
pub const WEIGHT_MAX_KG: f64 = 300.0;
pub const HEIGHT_MIN_CM: f64 = 100.0;
pub const HEIGHT_MAX_CM: f64 = 250.0;
pub const AGE_MIN_YEARS: u32 = 18;
pub const AGE_MAX_YEARS: u32 = 100;
pub const TRAINING_DAYS_MIN: i32 = 1;
pub const TRAINING_DAYS_MAX: i32 = 7;

/// Formato de `birth_date` en la API.
pub const BIRTH_DATE_FORMAT: &str = "%Y-%m-%d";

/// Datos del perfil tal como llegan del cliente. En el alta todos son obligatorios;
/// en la edición, `None` significa "no cambiar".
#[derive(Debug, Default, Clone)]
pub struct ProfileInput {
    pub objective: Option<String>,
    pub level: Option<String>,
    /// Se recibe como número para poder señalar un valor no entero como error del campo.
    pub training_days: Option<f64>,
    pub weight_kg: Option<f64>,
    pub height_cm: Option<f64>,
    pub gender: Option<String>,
    pub birth_date: Option<String>,
}

/// Perfil completo ya validado (alta).
#[derive(Debug, Clone, PartialEq)]
pub struct ValidProfile {
    pub objective: Objective,
    pub level: Level,
    pub training_days: i32,
    pub weight_kg: f64,
    pub height_cm: f64,
    pub gender: Gender,
    pub birth_date: NaiveDate,
}

/// Cambios ya validados (edición). Solo los campos `Some` se actualizan.
#[derive(Debug, Default, Clone, PartialEq)]
pub struct ProfileChanges {
    pub objective: Option<Objective>,
    pub level: Option<Level>,
    pub training_days: Option<i32>,
    pub weight_kg: Option<f64>,
    pub height_cm: Option<f64>,
    pub gender: Option<Gender>,
    pub birth_date: Option<NaiveDate>,
}

impl ProfileChanges {
    fn is_empty(&self) -> bool {
        *self == Self::default()
    }
}

// ───────────────────────── Validación (funciones puras) ─────────────────────────

/// Valida un campo según si es obligatorio (alta) u opcional (edición) y acumula su error.
fn check<R, T>(
    errors: &mut FieldErrors,
    field: &str,
    value: Option<R>,
    required: bool,
    missing: &str,
    rule: impl FnOnce(R) -> Result<T, String>,
) -> Option<T> {
    match value {
        None if required => {
            errors.insert(field.into(), missing.into());
            None
        }
        None => None,
        Some(raw) => match rule(raw) {
            Ok(value) => Some(value),
            Err(message) => {
                errors.insert(field.into(), message);
                None
            }
        },
    }
}

fn parse_enum<T>(
    value: String,
    parse: fn(&str) -> Option<T>,
    missing: &str,
    invalid: &str,
) -> Result<T, String> {
    let value = value.trim();
    if value.is_empty() {
        return Err(missing.into());
    }
    parse(value).ok_or_else(|| invalid.into())
}

fn parse_training_days(value: f64) -> Result<i32, String> {
    if !value.is_finite() || value.fract() != 0.0 {
        return Err("Los días de entrenamiento deben ser un número entero".into());
    }
    if value < f64::from(TRAINING_DAYS_MIN) || value > f64::from(TRAINING_DAYS_MAX) {
        return Err(format!(
            "Los días de entrenamiento deben estar entre {TRAINING_DAYS_MIN} y {TRAINING_DAYS_MAX}"
        ));
    }
    Ok(value as i32)
}

fn parse_in_range(value: f64, min: f64, max: f64, message: String) -> Result<f64, String> {
    if value.is_finite() && (min..=max).contains(&value) {
        Ok(value)
    } else {
        Err(message)
    }
}

/// Edad en años cumplidos a la fecha `today` (`None` si la fecha es futura).
pub fn age_on(birth_date: NaiveDate, today: NaiveDate) -> Option<u32> {
    today.years_since(birth_date)
}

fn parse_birth_date(value: String, today: NaiveDate) -> Result<NaiveDate, String> {
    let value = value.trim();
    if value.is_empty() {
        return Err("La fecha de nacimiento es obligatoria".into());
    }
    let date = (value.len() == 10)
        .then(|| NaiveDate::parse_from_str(value, BIRTH_DATE_FORMAT).ok())
        .flatten()
        .ok_or("La fecha de nacimiento debe ser una fecha válida con formato AAAA-MM-DD")?;
    match age_on(date, today) {
        None => Err("La fecha de nacimiento no puede ser futura".into()),
        Some(age) if (AGE_MIN_YEARS..=AGE_MAX_YEARS).contains(&age) => Ok(date),
        Some(_) => Err(format!(
            "Debes tener entre {AGE_MIN_YEARS} y {AGE_MAX_YEARS} años"
        )),
    }
}

/// Valida todos los campos y devuelve los cambios. Si `required`, falta = error.
fn validate_fields(
    input: ProfileInput,
    today: NaiveDate,
    required: bool,
) -> Result<ProfileChanges, FieldErrors> {
    let mut errors = FieldErrors::new();

    let objective = check(
        &mut errors,
        "objective",
        input.objective,
        required,
        "El objetivo es obligatorio",
        |v| {
            parse_enum(
                v,
                Objective::parse,
                "El objetivo es obligatorio",
                "El objetivo debe ser 'lose_fat', 'maintain' o 'gain_muscle'",
            )
        },
    );
    let level = check(
        &mut errors,
        "level",
        input.level,
        required,
        "El nivel es obligatorio",
        |v| {
            parse_enum(
                v,
                Level::parse,
                "El nivel es obligatorio",
                "El nivel debe ser 'beginner', 'intermediate' o 'advanced'",
            )
        },
    );
    let training_days = check(
        &mut errors,
        "training_days",
        input.training_days,
        required,
        "Los días de entrenamiento son obligatorios",
        parse_training_days,
    );
    let weight_kg = check(
        &mut errors,
        "weight_kg",
        input.weight_kg,
        required,
        "El peso es obligatorio",
        |v| {
            parse_in_range(
                v,
                WEIGHT_MIN_KG,
                WEIGHT_MAX_KG,
                format!("El peso debe estar entre {WEIGHT_MIN_KG} y {WEIGHT_MAX_KG} kg"),
            )
        },
    );
    let height_cm = check(
        &mut errors,
        "height_cm",
        input.height_cm,
        required,
        "La estatura es obligatoria",
        |v| {
            parse_in_range(
                v,
                HEIGHT_MIN_CM,
                HEIGHT_MAX_CM,
                format!("La estatura debe estar entre {HEIGHT_MIN_CM} y {HEIGHT_MAX_CM} cm"),
            )
        },
    );
    let gender = check(
        &mut errors,
        "gender",
        input.gender,
        required,
        "El sexo es obligatorio",
        |v| {
            parse_enum(
                v,
                Gender::parse,
                "El sexo es obligatorio",
                "El sexo debe ser 'male' o 'female'",
            )
        },
    );
    let birth_date = check(
        &mut errors,
        "birth_date",
        input.birth_date,
        required,
        "La fecha de nacimiento es obligatoria",
        |v| parse_birth_date(v, today),
    );

    if errors.is_empty() {
        Ok(ProfileChanges {
            objective,
            level,
            training_days,
            weight_kg,
            height_cm,
            gender,
            birth_date,
        })
    } else {
        Err(errors)
    }
}

/// Alta: todos los campos son obligatorios. Reporta todos los inválidos a la vez.
pub fn validate_new_profile(
    input: ProfileInput,
    today: NaiveDate,
) -> Result<ValidProfile, AppError> {
    let changes = validate_fields(input, today, true).map_err(AppError::Validation)?;
    match changes {
        ProfileChanges {
            objective: Some(objective),
            level: Some(level),
            training_days: Some(training_days),
            weight_kg: Some(weight_kg),
            height_cm: Some(height_cm),
            gender: Some(gender),
            birth_date: Some(birth_date),
        } => Ok(ValidProfile {
            objective,
            level,
            training_days,
            weight_kg,
            height_cm,
            gender,
            birth_date,
        }),
        _ => Err(AppError::internal(
            "validate_fields devolvió un perfil incompleto sin errores",
        )),
    }
}

/// Edición: solo se validan los campos enviados; debe llegar al menos uno.
pub fn validate_profile_changes(
    input: ProfileInput,
    today: NaiveDate,
) -> Result<ProfileChanges, AppError> {
    let changes = validate_fields(input, today, false).map_err(AppError::Validation)?;
    if changes.is_empty() {
        return Err(AppError::InvalidBody(
            "envía al menos un campo del perfil para actualizar".into(),
        ));
    }
    Ok(changes)
}

/// Fecha de nacimiento → `DateTime` de BSON a medianoche UTC.
pub fn birth_date_to_bson(date: NaiveDate) -> DateTime {
    DateTime::from_millis(
        date.and_time(chrono::NaiveTime::MIN)
            .and_utc()
            .timestamp_millis(),
    )
}

/// `DateTime` de BSON → texto `YYYY-MM-DD` (fecha UTC).
pub fn birth_date_to_string(date: DateTime) -> String {
    chrono::DateTime::from_timestamp_millis(date.timestamp_millis())
        .map(|value| value.date_naive().format(BIRTH_DATE_FORMAT).to_string())
        .unwrap_or_default()
}

fn today_utc() -> NaiveDate {
    Utc::now().date_naive()
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn profiles(db: &Database) -> mongodb::Collection<UserProfile> {
    db.collection::<UserProfile>(PROFILES_COLLECTION)
}

/// Marca `users.profile_completed = true`. Es idempotente.
async fn mark_profile_completed(db: &Database, user_id: ObjectId) -> Result<(), AppError> {
    db.collection::<User>(USERS_COLLECTION)
        .update_one(
            doc! { "_id": user_id },
            doc! { "$set": { "profile_completed": true } },
        )
        .await
        .map_err(AppError::internal)?;
    Ok(())
}

/// HU-03 — crea el perfil del usuario y marca su cuenta con `profile_completed: true`.
pub async fn create_profile(
    db: &Database,
    user_id: ObjectId,
    input: ProfileInput,
) -> Result<UserProfile, AppError> {
    let data = validate_new_profile(input, today_utc())?;
    let collection = profiles(db);

    // Comprobación previa para responder rápido; el índice único es la garantía real.
    // Si el perfil ya existe, se asegura también la marca en `users` (por si una
    // petición anterior guardó el perfil pero falló al marcar la cuenta).
    if collection
        .find_one(doc! { "user_id": user_id })
        .await
        .map_err(AppError::internal)?
        .is_some()
    {
        mark_profile_completed(db, user_id).await?;
        return Err(AppError::ProfileAlreadyExists);
    }

    let now = DateTime::now();
    let profile = UserProfile {
        id: ObjectId::new(),
        user_id,
        objective: data.objective,
        level: data.level,
        training_days: data.training_days,
        weight_kg: data.weight_kg,
        height_cm: data.height_cm,
        gender: data.gender,
        birth_date: birth_date_to_bson(data.birth_date),
        created_at: now,
        updated_at: now,
    };

    if let Err(err) = collection.insert_one(&profile).await {
        if is_duplicate_key(&err) {
            mark_profile_completed(db, user_id).await?;
            return Err(AppError::ProfileAlreadyExists);
        }
        return Err(AppError::internal(err));
    }

    mark_profile_completed(db, user_id).await?;
    Ok(profile)
}

/// HU-03 — perfil del usuario, o `PROFILE_NOT_FOUND` si aún no lo captura.
pub async fn get_profile(db: &Database, user_id: ObjectId) -> Result<UserProfile, AppError> {
    profiles(db)
        .find_one(doc! { "user_id": user_id })
        .await
        .map_err(AppError::internal)?
        .ok_or(AppError::ProfileNotFound)
}

fn enum_bson<T: serde::Serialize>(value: &T) -> Result<mongodb::bson::Bson, AppError> {
    to_bson(value).map_err(AppError::internal)
}

/// Documento `$set` con los campos que cambian y `updated_at`.
fn changes_to_set(changes: &ProfileChanges, now: DateTime) -> Result<Document, AppError> {
    let mut set = doc! { "updated_at": now };
    if let Some(objective) = &changes.objective {
        set.insert("objective", enum_bson(objective)?);
    }
    if let Some(level) = &changes.level {
        set.insert("level", enum_bson(level)?);
    }
    if let Some(training_days) = changes.training_days {
        set.insert("training_days", training_days);
    }
    if let Some(weight_kg) = changes.weight_kg {
        set.insert("weight_kg", weight_kg);
    }
    if let Some(height_cm) = changes.height_cm {
        set.insert("height_cm", height_cm);
    }
    if let Some(gender) = &changes.gender {
        set.insert("gender", enum_bson(gender)?);
    }
    if let Some(birth_date) = changes.birth_date {
        set.insert("birth_date", birth_date_to_bson(birth_date));
    }
    Ok(set)
}

/// HU-03 — edita solo los campos enviados y devuelve el perfil actualizado.
pub async fn update_profile(
    db: &Database,
    user_id: ObjectId,
    input: ProfileInput,
) -> Result<UserProfile, AppError> {
    let changes = validate_profile_changes(input, today_utc())?;
    let set = changes_to_set(&changes, DateTime::now())?;

    // TODO(HU-04): si cambian peso, objetivo o días de entrenamiento, recalcular la meta
    // vigente (`goal_inputs_changed`) salvo que la haya fijado un coach.
    profiles(db)
        .find_one_and_update(doc! { "user_id": user_id }, doc! { "$set": set })
        .return_document(ReturnDocument::After)
        .await
        .map_err(AppError::internal)?
        .ok_or(AppError::ProfileNotFound)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn today() -> NaiveDate {
        NaiveDate::from_ymd_opt(2026, 10, 8).unwrap()
    }

    fn valid_input() -> ProfileInput {
        ProfileInput {
            objective: Some("lose_fat".into()),
            level: Some("beginner".into()),
            training_days: Some(4.0),
            weight_kg: Some(72.5),
            height_cm: Some(170.0),
            gender: Some("female".into()),
            birth_date: Some("1996-05-20".into()),
        }
    }

    fn field_errors(result: Result<impl std::fmt::Debug, AppError>) -> Vec<String> {
        match result {
            Err(AppError::Validation(fields)) => fields.into_keys().collect(),
            other => panic!("se esperaba error de validación, llegó {other:?}"),
        }
    }

    #[test]
    fn perfil_valido_se_acepta_con_sus_valores() {
        let profile = validate_new_profile(valid_input(), today()).unwrap();
        assert_eq!(
            profile,
            ValidProfile {
                objective: Objective::LoseFat,
                level: Level::Beginner,
                training_days: 4,
                weight_kg: 72.5,
                height_cm: 170.0,
                gender: Gender::Female,
                birth_date: NaiveDate::from_ymd_opt(1996, 5, 20).unwrap(),
            }
        );
    }

    #[test]
    fn cuerpo_vacio_senala_todos_los_campos() {
        let fields = field_errors(validate_new_profile(ProfileInput::default(), today()));
        assert_eq!(
            fields,
            [
                "birth_date",
                "gender",
                "height_cm",
                "level",
                "objective",
                "training_days",
                "weight_kg"
            ]
        );
    }

    #[test]
    fn valores_fuera_de_rango_se_senalan_todos() {
        let fields = field_errors(validate_new_profile(
            ProfileInput {
                training_days: Some(8.0),
                weight_kg: Some(29.9),
                height_cm: Some(250.1),
                birth_date: Some("2010-01-01".into()),
                ..valid_input()
            },
            today(),
        ));
        assert_eq!(
            fields,
            ["birth_date", "height_cm", "training_days", "weight_kg"]
        );
    }

    #[test]
    fn valores_no_permitidos_se_senalan_todos() {
        let fields = field_errors(validate_new_profile(
            ProfileInput {
                objective: Some("volar".into()),
                level: Some("Experto".into()),
                gender: Some("otro".into()),
                training_days: Some(3.5),
                birth_date: Some("1996-02-30".into()),
                ..valid_input()
            },
            today(),
        ));
        assert_eq!(
            fields,
            [
                "birth_date",
                "gender",
                "level",
                "objective",
                "training_days"
            ]
        );
    }

    #[test]
    fn enumerados_exigen_minusculas_exactas() {
        for objective in ["LOSE_FAT", "Lose_fat", "bajar_grasa"] {
            let fields = field_errors(validate_new_profile(
                ProfileInput {
                    objective: Some(objective.into()),
                    ..valid_input()
                },
                today(),
            ));
            assert_eq!(fields, ["objective"], "objetivo {objective}");
        }
    }

    #[test]
    fn limites_de_peso_estatura_y_dias_son_inclusivos() {
        for (weight, height, days) in [(30.0, 100.0, 1.0), (300.0, 250.0, 7.0)] {
            let input = ProfileInput {
                weight_kg: Some(weight),
                height_cm: Some(height),
                training_days: Some(days),
                ..valid_input()
            };
            assert!(validate_new_profile(input, today()).is_ok());
        }
    }

    #[test]
    fn edad_de_18_y_100_anios_es_valida_y_fuera_no() {
        for (date, ok) in [
            ("2008-10-08", true),  // cumple 18 hoy
            ("2008-10-09", false), // cumple 18 mañana
            ("1926-10-09", true),  // tiene 99
            ("1925-10-09", true),  // tiene 100
            ("1925-10-08", false), // cumple 101 hoy
            ("2030-01-01", false), // futura
        ] {
            let input = ProfileInput {
                birth_date: Some(date.into()),
                ..valid_input()
            };
            assert_eq!(
                validate_new_profile(input, today()).is_ok(),
                ok,
                "fecha {date}"
            );
        }
    }

    #[test]
    fn fecha_con_formato_incorrecto_se_rechaza() {
        for date in ["20/05/1996", "1996-5-20", "1996-05-20T00:00:00Z", "ayer"] {
            let fields = field_errors(validate_new_profile(
                ProfileInput {
                    birth_date: Some(date.into()),
                    ..valid_input()
                },
                today(),
            ));
            assert_eq!(fields, ["birth_date"], "fecha {date}");
        }
    }

    #[test]
    fn textos_en_blanco_cuentan_como_faltantes() {
        let fields = field_errors(validate_new_profile(
            ProfileInput {
                objective: Some("  ".into()),
                ..valid_input()
            },
            today(),
        ));
        assert_eq!(fields, ["objective"]);
    }

    #[test]
    fn edicion_acepta_un_solo_campo() {
        let changes = validate_profile_changes(
            ProfileInput {
                weight_kg: Some(80.0),
                ..ProfileInput::default()
            },
            today(),
        )
        .unwrap();
        assert_eq!(
            changes,
            ProfileChanges {
                weight_kg: Some(80.0),
                ..ProfileChanges::default()
            }
        );
    }

    #[test]
    fn edicion_sin_campos_es_cuerpo_invalido() {
        assert!(matches!(
            validate_profile_changes(ProfileInput::default(), today()),
            Err(AppError::InvalidBody(_))
        ));
    }

    #[test]
    fn edicion_valida_los_campos_enviados() {
        let fields = field_errors(validate_profile_changes(
            ProfileInput {
                weight_kg: Some(500.0),
                level: Some("pro".into()),
                ..ProfileInput::default()
            },
            today(),
        ));
        assert_eq!(fields, ["level", "weight_kg"]);
    }

    #[test]
    fn fecha_de_nacimiento_ida_y_vuelta_en_bson() {
        let date = NaiveDate::from_ymd_opt(1996, 5, 20).unwrap();
        assert_eq!(birth_date_to_string(birth_date_to_bson(date)), "1996-05-20");
    }

    #[test]
    fn set_de_edicion_incluye_solo_lo_enviado_y_updated_at() {
        let now = DateTime::from_millis(0);
        let set = changes_to_set(
            &ProfileChanges {
                objective: Some(Objective::GainMuscle),
                training_days: Some(5),
                ..ProfileChanges::default()
            },
            now,
        )
        .unwrap();
        assert_eq!(
            set,
            doc! { "updated_at": now, "objective": "gain_muscle", "training_days": 5 }
        );
    }
}
