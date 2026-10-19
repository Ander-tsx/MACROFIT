//! HU-09 — registros de comida (RF-08): guardar, consultar por día y eliminar.
//!
//! - El día de un registro (`date`) se calcula al guardar con la zona horaria fija de la app (`APP_UTC_OFFSET`,
//!   México por defecto), así el usuario y su coach (HU-25) ven el mismo día. `?date=` filtra por ese campo.
//! - La foto es opcional (captura manual). Si viene, debe ser propia (`PHOTO_NOT_FOUND`) y no estar en otro registro
//!   (`PHOTO_ALREADY_USED`, garantizado por el índice único parcial `photo_id_unique`).
//! - Solo el dueño ve y elimina sus registros; para cualquier otra cuenta el registro "no existe" (`MEAL_NOT_FOUND`).
//!   Eliminar un registro borra también su foto (TEC-13).
//! - HU-25: el coach consulta los registros de un día de un cliente con vinculación activa (`list_client_meals`),
//!   solo lectura. Un cliente sin vinculación activa, inexistente o con id mal formado → `CLIENT_NOT_LINKED`.

use std::collections::HashMap;

use chrono::{FixedOffset, NaiveDate, Utc};
use mongodb::{
    Collection, Database,
    bson::{DateTime, Document, doc, oid::ObjectId},
};
use serde_json::Value;

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::meal::{MEALS_COLLECTION, Meal};
use crate::services::auth::is_duplicate_key;
use crate::services::{coach_links, photos};
use crate::validation::{DATE_FORMAT, check, parse_date};

/// Límites superiores razonables de un solo registro (los mismos órdenes que la meta del coach, HU-05).
pub const CALORIES_MAX: f64 = 10_000.0;
pub const MACRO_MAX_G: f64 = 1_000.0;

// ───────────────────────── Validación (funciones puras) ─────────────────────────

/// Cuerpo de `POST /meals` tal como llega. Los valores llegan como `Value` para señalar un texto en su campo.
#[derive(Debug, Default, Clone)]
pub struct MealInput {
    pub photo_id: Option<Value>,
    pub calories_kcal: Option<Value>,
    pub protein_g: Option<Value>,
    pub fat_g: Option<Value>,
}

/// Registro que ya pasó la validación.
#[derive(Debug, Clone, PartialEq)]
pub struct ValidMeal {
    /// Id de la foto tal como llegó (sin espacios); su existencia y dueño se revisan contra la base.
    pub photo_id: Option<String>,
    pub calories_kcal: f64,
    pub protein_g: f64,
    pub fat_g: f64,
}

/// Número `>= 0` y `<= max`; el 0 se acepta (RF-07: no negativos).
fn parse_amount(value: Value, max: f64) -> Result<f64, String> {
    let amount = value
        .as_f64()
        .ok_or_else(|| "Debe ser un número".to_string())?;
    if amount < 0.0 {
        return Err("No puede ser negativo".to_string());
    }
    if amount > max {
        return Err(format!("No puede ser mayor a {max}"));
    }
    Ok(amount)
}

/// HU-09 — valida el cuerpo de `POST /meals` y señala todos los campos inválidos a la vez.
pub fn validate_new_meal(input: MealInput) -> Result<ValidMeal, AppError> {
    let mut errors = FieldErrors::new();
    let present = |value: Option<Value>| value.filter(|v| !v.is_null());

    let photo_id = check(
        &mut errors,
        "photo_id",
        present(input.photo_id),
        false,
        "",
        |value| match value.as_str().map(str::trim) {
            Some(id) if !id.is_empty() => Ok(id.to_string()),
            Some(_) => Err("Indica la foto o no envíes el campo".to_string()),
            None => Err("El id de la foto debe ser texto".to_string()),
        },
    );
    let calories_kcal = check(
        &mut errors,
        "calories_kcal",
        present(input.calories_kcal),
        true,
        "Las calorías son obligatorias",
        |value| parse_amount(value, CALORIES_MAX),
    );
    let protein_g = check(
        &mut errors,
        "protein_g",
        present(input.protein_g),
        true,
        "La proteína es obligatoria",
        |value| parse_amount(value, MACRO_MAX_G),
    );
    let fat_g = check(
        &mut errors,
        "fat_g",
        present(input.fat_g),
        true,
        "La grasa es obligatoria",
        |value| parse_amount(value, MACRO_MAX_G),
    );

    match (calories_kcal, protein_g, fat_g) {
        (Some(calories_kcal), Some(protein_g), Some(fat_g)) if errors.is_empty() => Ok(ValidMeal {
            photo_id,
            calories_kcal,
            protein_g,
            fat_g,
        }),
        _ => Err(AppError::Validation(errors)),
    }
}

/// HU-09 — valida `?date=`: obligatorio y con formato `YYYY-MM-DD`.
pub fn validate_date(date: Option<String>) -> Result<NaiveDate, AppError> {
    let error = |message: &str| {
        AppError::Validation(FieldErrors::from([(
            "date".to_string(),
            message.to_string(),
        )]))
    };
    match date.as_deref().map(str::trim) {
        None | Some("") => Err(error("Indica la fecha a consultar (YYYY-MM-DD)")),
        Some(value) => {
            parse_date(value).ok_or_else(|| error("La fecha debe tener el formato YYYY-MM-DD"))
        }
    }
}

/// Día `YYYY-MM-DD` de un instante en la zona horaria de la app.
pub fn local_date(at: chrono::DateTime<Utc>, offset: FixedOffset) -> String {
    at.with_timezone(&offset)
        .date_naive()
        .format(DATE_FORMAT)
        .to_string()
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn meals(db: &Database) -> Collection<Meal> {
    db.collection(MEALS_COLLECTION)
}

/// HU-09 — guarda un registro con la fecha y hora del servidor.
pub async fn create_meal(
    db: &Database,
    user_id: ObjectId,
    offset: FixedOffset,
    input: MealInput,
) -> Result<Meal, AppError> {
    let valid = validate_new_meal(input)?;
    let photo_id = match valid.photo_id {
        Some(id) => Some(photos::ensure_own_photo(db, user_id, &id).await?),
        None => None,
    };

    let now = Utc::now();
    let meal = Meal {
        id: ObjectId::new(),
        user_id,
        photo_id,
        eaten_at: DateTime::from_millis(now.timestamp_millis()),
        date: local_date(now, offset),
        calories_kcal: valid.calories_kcal,
        protein_g: valid.protein_g,
        fat_g: valid.fat_g,
    };
    match meals(db).insert_one(&meal).await {
        Ok(_) => Ok(meal),
        Err(err) if is_duplicate_key(&err) => Err(AppError::PhotoAlreadyUsed),
        Err(err) => Err(AppError::internal(err)),
    }
}

/// Registros de `user_id` en el día `date`, del más antiguo al más reciente. La reutiliza HU-25 para el coach.
pub async fn find_meals_by_date(
    db: &Database,
    user_id: ObjectId,
    date: NaiveDate,
) -> Result<Vec<Meal>, AppError> {
    let cursor = meals(db)
        .find(doc! { "user_id": user_id, "date": date.format(DATE_FORMAT).to_string() })
        .sort(doc! { "eaten_at": 1, "_id": 1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

/// HU-11 — registros de `user_id` entre `from` y `to` (ambos incluidos) con una sola consulta, del más antiguo al más
/// reciente. `date` es `YYYY-MM-DD`, así que el rango de texto coincide con el rango de días.
pub async fn find_meals_between(
    db: &Database,
    user_id: ObjectId,
    from: NaiveDate,
    to: NaiveDate,
) -> Result<Vec<Meal>, AppError> {
    let cursor = meals(db)
        .find(doc! {
            "user_id": user_id,
            "date": {
                "$gte": from.format(DATE_FORMAT).to_string(),
                "$lte": to.format(DATE_FORMAT).to_string(),
            },
        })
        .sort(doc! { "eaten_at": 1, "_id": 1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

/// HU-24 — agregación que da, por cada usuario de `user_ids`, la fecha y hora de su registro más reciente
/// (`{ _id: user_id, last_meal_at }`). Un usuario sin registros no aparece.
pub fn last_meal_pipeline(user_ids: &[ObjectId]) -> Vec<Document> {
    vec![
        doc! { "$match": { "user_id": { "$in": user_ids.to_vec() } } },
        doc! { "$group": { "_id": "$user_id", "last_meal_at": { "$max": "$eaten_at" } } },
    ]
}

/// Lee el resultado de `last_meal_pipeline` como mapa usuario → fecha y hora del último registro.
pub fn parse_last_meals(rows: Vec<Document>) -> HashMap<ObjectId, DateTime> {
    rows.into_iter()
        .filter_map(|row| {
            let user_id = row.get_object_id("_id").ok()?;
            let last_meal_at = *row.get_datetime("last_meal_at").ok()?;
            Some((user_id, last_meal_at))
        })
        .collect()
}

/// HU-24 — fecha y hora del último registro de varios usuarios con una sola agregación.
pub async fn last_meal_at_for(
    db: &Database,
    user_ids: &[ObjectId],
) -> Result<HashMap<ObjectId, DateTime>, AppError> {
    if user_ids.is_empty() {
        return Ok(HashMap::new());
    }
    let cursor = meals(db)
        .aggregate(last_meal_pipeline(user_ids))
        .await
        .map_err(AppError::internal)?;
    Ok(parse_last_meals(collect_cursor(cursor).await?))
}

/// HU-09 — `GET /meals?date=`: valida la fecha y devuelve los registros del usuario de ese día.
pub async fn list_meals(
    db: &Database,
    user_id: ObjectId,
    date: Option<String>,
) -> Result<Vec<Meal>, AppError> {
    let date = validate_date(date)?;
    find_meals_by_date(db, user_id, date).await
}

/// HU-25 — `GET /coach/clients/{clientId}/meals?date=`: registros del cliente en ese día, solo si el coach tiene una
/// vinculación activa con él. La vinculación se comprueba antes que la fecha, igual que en HU-05: un coach sin
/// vinculación recibe `CLIENT_NOT_LINKED` con cualquier fecha.
pub async fn list_client_meals(
    db: &Database,
    coach_id: ObjectId,
    client_id: &str,
    date: Option<String>,
) -> Result<Vec<Meal>, AppError> {
    let client_id = coach_links::require_active_link(db, coach_id, client_id).await?;
    let date = validate_date(date)?;
    find_meals_by_date(db, client_id, date).await
}

/// HU-09 — elimina un registro propio y su foto. Un id mal formado, inexistente o de otra cuenta → `MEAL_NOT_FOUND`.
///
/// La foto se borra antes que el registro: si falla, el registro sigue ahí y se puede reintentar
/// (una foto que ya no existe no impide eliminar el registro).
pub async fn delete_meal(db: &Database, user_id: ObjectId, meal_id: &str) -> Result<(), AppError> {
    let meal_id = ObjectId::parse_str(meal_id).map_err(|_| AppError::MealNotFound)?;
    let filter = doc! { "_id": meal_id, "user_id": user_id };
    let meal = meals(db)
        .find_one(filter.clone())
        .await
        .map_err(AppError::internal)?
        .ok_or(AppError::MealNotFound)?;

    if let Some(photo_id) = meal.photo_id {
        match photos::delete_photo(db, user_id, photo_id).await {
            Ok(()) | Err(AppError::PhotoNotFound) => {}
            Err(err) => return Err(err),
        }
    }

    let result = meals(db)
        .delete_one(filter)
        .await
        .map_err(AppError::internal)?;
    if result.deleted_count == 0 {
        // Otra petición lo eliminó mientras tanto.
        return Err(AppError::MealNotFound);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;
    use serde_json::json;

    fn input(photo_id: Option<Value>, calories: Value, protein: Value, fat: Value) -> MealInput {
        MealInput {
            photo_id,
            calories_kcal: Some(calories),
            protein_g: Some(protein),
            fat_g: Some(fat),
        }
    }

    fn fields(result: Result<ValidMeal, AppError>) -> FieldErrors {
        match result {
            Err(AppError::Validation(fields)) => fields,
            other => panic!("se esperaba VALIDATION_ERROR, llegó {other:?}"),
        }
    }

    fn mexico() -> FixedOffset {
        crate::config::default_utc_offset()
    }

    #[test]
    fn registro_valido_con_foto_se_acepta() {
        let valid = validate_new_meal(input(
            Some(json!(" 6acd4140ac968514f27322cd ")),
            json!(413),
            json!(42.2),
            json!(4.9),
        ))
        .unwrap();
        assert_eq!(
            valid,
            ValidMeal {
                photo_id: Some("6acd4140ac968514f27322cd".to_string()),
                calories_kcal: 413.0,
                protein_g: 42.2,
                fat_g: 4.9,
            }
        );
    }

    #[test]
    fn captura_manual_sin_foto_se_acepta() {
        for photo_id in [None, Some(Value::Null)] {
            let valid =
                validate_new_meal(input(photo_id, json!(250), json!(10), json!(8))).unwrap();
            assert_eq!(valid.photo_id, None);
        }
    }

    #[test]
    fn el_cero_se_acepta() {
        let valid = validate_new_meal(input(None, json!(0), json!(0), json!(0.0))).unwrap();
        assert_eq!(
            (valid.calories_kcal, valid.protein_g, valid.fat_g),
            (0.0, 0.0, 0.0)
        );
    }

    #[test]
    fn valores_ausentes_se_senalan_todos() {
        let errors = fields(validate_new_meal(MealInput::default()));
        assert_eq!(
            errors.keys().collect::<Vec<_>>(),
            ["calories_kcal", "fat_g", "protein_g"]
        );
        let errors = fields(validate_new_meal(input(
            None,
            Value::Null,
            Value::Null,
            Value::Null,
        )));
        assert_eq!(errors.len(), 3);
    }

    #[test]
    fn valores_negativos_se_rechazan() {
        let errors = fields(validate_new_meal(input(
            None,
            json!(-1),
            json!(-0.5),
            json!(-10),
        )));
        for field in ["calories_kcal", "protein_g", "fat_g"] {
            assert_eq!(errors[field], "No puede ser negativo");
        }
    }

    #[test]
    fn valores_no_numericos_se_rechazan() {
        for value in [json!("400"), json!(true), json!([1]), json!({})] {
            let errors = fields(validate_new_meal(input(
                None,
                value.clone(),
                json!(1),
                json!(1),
            )));
            assert_eq!(
                errors["calories_kcal"], "Debe ser un número",
                "valor {value}"
            );
            assert_eq!(errors.len(), 1);
        }
    }

    #[test]
    fn valores_por_encima_del_maximo_se_rechazan() {
        let errors = fields(validate_new_meal(input(
            None,
            json!(CALORIES_MAX + 1.0),
            json!(MACRO_MAX_G + 1.0),
            json!(MACRO_MAX_G),
        )));
        assert_eq!(
            errors.keys().collect::<Vec<_>>(),
            ["calories_kcal", "protein_g"]
        );
    }

    #[test]
    fn photo_id_invalido_se_senala_junto_a_los_demas() {
        let errors = fields(validate_new_meal(input(
            Some(json!(123)),
            json!(-1),
            json!(1),
            json!(1),
        )));
        assert_eq!(errors["photo_id"], "El id de la foto debe ser texto");
        assert!(errors.contains_key("calories_kcal"));

        let errors = fields(validate_new_meal(input(
            Some(json!("  ")),
            json!(1),
            json!(1),
            json!(1),
        )));
        assert_eq!(errors.keys().collect::<Vec<_>>(), ["photo_id"]);
    }

    #[test]
    fn fecha_valida_se_acepta() {
        assert_eq!(
            validate_date(Some("2026-10-16".to_string())).unwrap(),
            NaiveDate::from_ymd_opt(2026, 10, 16).unwrap()
        );
    }

    #[test]
    fn fecha_ausente_o_invalida_senala_el_campo_date() {
        for date in [
            None,
            Some(String::new()),
            Some("  ".to_string()),
            Some("16/10/2026".to_string()),
            Some("2026-02-30".to_string()),
            Some("2026-1-5".to_string()),
            Some("hoy".to_string()),
        ] {
            match validate_date(date.clone()) {
                Err(AppError::Validation(fields)) => {
                    assert_eq!(fields.keys().collect::<Vec<_>>(), ["date"], "{date:?}")
                }
                other => panic!("{date:?}: se esperaba VALIDATION_ERROR, llegó {other:?}"),
            }
        }
    }

    #[test]
    fn el_dia_se_define_con_la_hora_de_mexico() {
        // 19:30 en México del 16 = 01:30 UTC del 17: el registro es del 16.
        let at = Utc.with_ymd_and_hms(2026, 10, 17, 1, 30, 0).unwrap();
        assert_eq!(local_date(at, mexico()), "2026-10-16");
        // 06:00 UTC = medianoche en México: ya es el día siguiente.
        let at = Utc.with_ymd_and_hms(2026, 10, 17, 6, 0, 0).unwrap();
        assert_eq!(local_date(at, mexico()), "2026-10-17");
        let at = Utc.with_ymd_and_hms(2026, 10, 17, 5, 59, 59).unwrap();
        assert_eq!(local_date(at, mexico()), "2026-10-16");
    }

    /// Pruebas contra MongoDB real. Se ejecutan con `cargo test -- --ignored` y una instancia sin autenticación
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink, LinkStatus};
        use crate::models::meal_photo::MEAL_PHOTOS_FILES_COLLECTION;
        use crate::services::photos::{save_photo, validate_photo};
        use mongodb::bson::Document;

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn photo(db: &Database, owner: ObjectId) -> ObjectId {
            let bytes = vec![0xFF, 0xD8, 0xFF, 0xE0, 0, 0];
            save_photo(db, owner, validate_photo(bytes).unwrap())
                .await
                .unwrap()
        }

        async fn photo_exists(db: &Database, id: ObjectId) -> bool {
            db.collection::<Document>(MEAL_PHOTOS_FILES_COLLECTION)
                .find_one(doc! { "_id": id })
                .await
                .unwrap()
                .is_some()
        }

        fn body(photo_id: Option<ObjectId>) -> MealInput {
            input(
                photo_id.map(|id| json!(id.to_hex())),
                json!(413),
                json!(42.2),
                json!(4.9),
            )
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn guardar_consultar_y_eliminar_con_foto() {
            let db = test_db().await;
            let user = ObjectId::new();
            let photo_id = photo(&db, user).await;

            let meal = create_meal(&db, user, mexico(), body(Some(photo_id)))
                .await
                .unwrap();
            assert_eq!(meal.photo_id, Some(photo_id));
            let date = parse_date(&meal.date).unwrap();

            let list = find_meals_by_date(&db, user, date).await.unwrap();
            assert_eq!(list.len(), 1);
            assert_eq!(list[0].id, meal.id);
            // Otro usuario no ve el registro.
            assert!(
                find_meals_by_date(&db, ObjectId::new(), date)
                    .await
                    .unwrap()
                    .is_empty()
            );

            delete_meal(&db, user, &meal.id.to_hex()).await.unwrap();
            assert!(
                find_meals_by_date(&db, user, date)
                    .await
                    .unwrap()
                    .is_empty()
            );
            assert!(!photo_exists(&db, photo_id).await, "la foto debía borrarse");
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn registros_del_dia_ordenados_por_hora() {
            let db = test_db().await;
            let user = ObjectId::new();
            let first = create_meal(&db, user, mexico(), body(None)).await.unwrap();
            let second = create_meal(&db, user, mexico(), body(None)).await.unwrap();
            let list = find_meals_by_date(&db, user, parse_date(&first.date).unwrap())
                .await
                .unwrap();
            let ids: Vec<_> = list.iter().map(|m| m.id).collect();
            assert_eq!(ids, [first.id, second.id]);
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn foto_ajena_o_inexistente_es_photo_not_found() {
            let db = test_db().await;
            let user = ObjectId::new();
            let other_photo = photo(&db, ObjectId::new()).await;
            for id in [other_photo, ObjectId::new()] {
                let result = create_meal(&db, user, mexico(), body(Some(id))).await;
                assert!(matches!(result, Err(AppError::PhotoNotFound)));
            }
            let result = create_meal(
                &db,
                user,
                mexico(),
                input(Some(json!("no-es-un-id")), json!(1), json!(1), json!(1)),
            )
            .await;
            assert!(matches!(result, Err(AppError::PhotoNotFound)));
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn la_misma_foto_no_entra_en_dos_registros() {
            let db = test_db().await;
            let user = ObjectId::new();
            let photo_id = photo(&db, user).await;
            create_meal(&db, user, mexico(), body(Some(photo_id)))
                .await
                .unwrap();
            let result = create_meal(&db, user, mexico(), body(Some(photo_id))).await;
            assert!(matches!(result, Err(AppError::PhotoAlreadyUsed)));
            // Varios registros sin foto sí se permiten (el índice único es parcial).
            create_meal(&db, user, mexico(), body(None)).await.unwrap();
            create_meal(&db, user, mexico(), body(None)).await.unwrap();
            db.drop().await.unwrap();
        }

        async fn link(db: &Database, coach_id: ObjectId, user_id: ObjectId, status: LinkStatus) {
            db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
                .insert_one(CoachLink {
                    id: ObjectId::new(),
                    coach_id,
                    user_id,
                    status,
                    created_at: DateTime::now(),
                })
                .await
                .unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn coach_vinculado_ve_los_registros_del_dia_de_su_cliente() {
            let db = test_db().await;
            let (coach, client) = (ObjectId::new(), ObjectId::new());
            link(&db, coach, client, LinkStatus::Active).await;
            let photo_id = photo(&db, client).await;
            let meal = create_meal(&db, client, mexico(), body(Some(photo_id)))
                .await
                .unwrap();
            // Un registro de otro usuario el mismo día no aparece.
            create_meal(&db, ObjectId::new(), mexico(), body(None))
                .await
                .unwrap();

            let list = list_client_meals(&db, coach, &client.to_hex(), Some(meal.date.clone()))
                .await
                .unwrap();
            assert_eq!(list.len(), 1);
            assert_eq!(list[0].id, meal.id);
            assert_eq!(list[0].photo_id, Some(photo_id));
            // Otra fecha sin registros: lista vacía.
            let empty = list_client_meals(&db, coach, &client.to_hex(), Some("2000-01-01".into()))
                .await
                .unwrap();
            assert!(empty.is_empty());
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn sin_vinculacion_activa_es_client_not_linked_aunque_la_fecha_sea_invalida() {
            let db = test_db().await;
            let (coach, other_coach, client) = (ObjectId::new(), ObjectId::new(), ObjectId::new());
            link(&db, coach, client, LinkStatus::Unlinked).await;
            link(&db, other_coach, client, LinkStatus::Active).await;
            let meal = create_meal(&db, client, mexico(), body(None))
                .await
                .unwrap();

            for (client_id, date) in [
                (client.to_hex(), Some(meal.date.clone())),
                (client.to_hex(), Some("no-es-fecha".to_string())),
                (ObjectId::new().to_hex(), Some(meal.date.clone())),
                ("abc".to_string(), None),
            ] {
                let result = list_client_meals(&db, coach, &client_id, date).await;
                assert!(
                    matches!(result, Err(AppError::ClientNotLinked)),
                    "{client_id}"
                );
            }
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn coach_vinculado_con_fecha_invalida_o_ausente_es_validation_error() {
            let db = test_db().await;
            let (coach, client) = (ObjectId::new(), ObjectId::new());
            link(&db, coach, client, LinkStatus::Active).await;
            for date in [None, Some("16-10-2026".to_string())] {
                match list_client_meals(&db, coach, &client.to_hex(), date).await {
                    Err(AppError::Validation(fields)) => assert!(fields.contains_key("date")),
                    other => panic!("se esperaba VALIDATION_ERROR, llegó {other:?}"),
                }
            }
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn registro_ajeno_inexistente_o_mal_formado_es_meal_not_found() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let photo_id = photo(&db, owner).await;
            let meal = create_meal(&db, owner, mexico(), body(Some(photo_id)))
                .await
                .unwrap();

            for (user, id) in [
                (ObjectId::new(), meal.id.to_hex()),
                (owner, ObjectId::new().to_hex()),
                (owner, "abc".to_string()),
            ] {
                let result = delete_meal(&db, user, &id).await;
                assert!(matches!(result, Err(AppError::MealNotFound)), "{id}");
            }
            // El intento ajeno no tocó ni el registro ni la foto.
            let date = parse_date(&meal.date).unwrap();
            assert_eq!(find_meals_by_date(&db, owner, date).await.unwrap().len(), 1);
            assert!(photo_exists(&db, photo_id).await);
            db.drop().await.unwrap();
        }
    }

    #[test]
    fn ultimo_registro_se_agrupa_por_usuario_en_una_sola_agregacion() {
        let ana = ObjectId::new();
        let bruno = ObjectId::new();
        assert_eq!(
            last_meal_pipeline(&[ana, bruno]),
            vec![
                doc! { "$match": { "user_id": { "$in": [ana, bruno] } } },
                doc! { "$group": { "_id": "$user_id", "last_meal_at": { "$max": "$eaten_at" } } },
            ]
        );
    }

    #[test]
    fn ultimo_registro_se_lee_por_usuario_e_ignora_filas_incompletas() {
        let ana = ObjectId::new();
        let at = DateTime::parse_rfc3339_str("2026-10-17T01:30:00Z").unwrap();
        let rows = vec![
            doc! { "_id": ana, "last_meal_at": at },
            doc! { "_id": ObjectId::new() },
            doc! { "_id": "no-es-un-id", "last_meal_at": at },
        ];
        let last = parse_last_meals(rows);
        assert_eq!(last.len(), 1);
        assert_eq!(last[&ana], at);
    }
}
