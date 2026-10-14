//! HU-21 — registro de peso: validación, alta e historial.

use mongodb::{
    Database,
    bson::{DateTime, doc, oid::ObjectId},
};
use serde_json::Value;

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::weight_entry::{WEIGHTS_COLLECTION, WeightEntry};
use crate::services::profile::{self, ProfileInput, parse_weight_kg};
use crate::validation::check;

// ───────────────────────── Validación (función pura) ─────────────────────────

/// Valida `weight_kg` tal como llega (como `Value` para señalar un texto en su campo)
/// con el rango del perfil de TEC-12.
pub fn validate_weight(weight_kg: Option<Value>) -> Result<f64, AppError> {
    let mut errors = FieldErrors::new();
    let weight_kg = check(
        &mut errors,
        "weight_kg",
        weight_kg.filter(|value| !value.is_null()),
        true,
        "El peso es obligatorio",
        |value| {
            value
                .as_f64()
                .ok_or_else(|| "El peso debe ser un número".to_string())
                .and_then(parse_weight_kg)
        },
    );
    weight_kg.ok_or(AppError::Validation(errors))
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn weights(db: &Database) -> mongodb::Collection<WeightEntry> {
    db.collection(WEIGHTS_COLLECTION)
}

/// HU-21 — registra un peso con la fecha del servidor. Si el usuario ya tiene perfil, ese peso
/// pasa a ser su `weight_kg` y la meta calculada se actualiza (HU-04; una meta de coach no se toca).
pub async fn record_weight(
    db: &Database,
    user_id: ObjectId,
    weight_kg: Option<Value>,
) -> Result<WeightEntry, AppError> {
    let weight_kg = validate_weight(weight_kg)?;
    let entry = WeightEntry {
        id: ObjectId::new(),
        user_id,
        weight_kg,
        recorded_at: DateTime::now(),
    };
    weights(db)
        .insert_one(&entry)
        .await
        .map_err(AppError::internal)?;

    let changes = ProfileInput {
        weight_kg: Some(weight_kg),
        ..ProfileInput::default()
    };
    match profile::update_profile(db, user_id, changes).await {
        Ok(_) | Err(AppError::ProfileNotFound) => Ok(entry),
        Err(err) => Err(err),
    }
}

/// HU-21 — historial de peso del usuario, del más reciente al más antiguo.
pub async fn list_weights(db: &Database, user_id: ObjectId) -> Result<Vec<WeightEntry>, AppError> {
    let cursor = weights(db)
        .find(doc! { "user_id": user_id })
        .sort(doc! { "recorded_at": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn weight_error(weight_kg: Option<Value>) -> String {
        match validate_weight(weight_kg) {
            Err(AppError::Validation(fields)) => {
                assert_eq!(fields.keys().collect::<Vec<_>>(), ["weight_kg"]);
                fields["weight_kg"].clone()
            }
            other => panic!("se esperaba error de validación, llegó {other:?}"),
        }
    }

    #[test]
    fn peso_valido_se_acepta() {
        assert_eq!(validate_weight(Some(json!(72.5))).unwrap(), 72.5);
        assert_eq!(validate_weight(Some(json!(80))).unwrap(), 80.0);
    }

    #[test]
    fn peso_ausente_o_nulo_es_obligatorio() {
        assert_eq!(weight_error(None), "El peso es obligatorio");
        assert_eq!(weight_error(Some(Value::Null)), "El peso es obligatorio");
    }

    #[test]
    fn peso_no_numerico_se_senala() {
        for value in [
            json!("80"),
            json!("ochenta"),
            json!(true),
            json!([80]),
            json!({}),
        ] {
            assert_eq!(
                weight_error(Some(value.clone())),
                "El peso debe ser un número",
                "valor {value}"
            );
        }
    }

    #[test]
    fn peso_fuera_de_rango_usa_el_rango_del_perfil() {
        for weight in [34.9, 250.1, 0.0, -70.0] {
            assert_eq!(
                weight_error(Some(json!(weight))),
                parse_weight_kg(weight).unwrap_err(),
                "peso {weight}"
            );
        }
    }

    #[test]
    fn limites_del_rango_se_aceptan() {
        use crate::services::profile::{WEIGHT_MAX_KG, WEIGHT_MIN_KG};
        for weight in [WEIGHT_MIN_KG, WEIGHT_MAX_KG] {
            assert_eq!(validate_weight(Some(json!(weight))).unwrap(), weight);
        }
    }
}
