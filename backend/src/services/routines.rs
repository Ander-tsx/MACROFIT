//! HU-18 — rutinas personalizadas del coach (RF-22, CU-04): validación y CRUD por coach.
//!
//! Cada rutina pertenece a un coach (`coach_id`); todas las consultas filtran por él, así que una rutina ajena se
//! comporta igual que una inexistente (`ROUTINE_NOT_FOUND`). Los ejercicios salen del catálogo de TEC-09.

use std::collections::HashMap;

use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
    options::ReturnDocument,
};
use serde_json::Value;

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::exercise::{EXERCISES_COLLECTION, Exercise};
use crate::models::routine::{ROUTINES_COLLECTION, Routine, RoutineExercise};

/// Largo máximo del nombre de la rutina (sin espacios alrededor).
pub const NAME_MAX_CHARS: usize = 80;
/// Ejercicios por rutina.
pub const MIN_EXERCISES: usize = 1;
pub const MAX_EXERCISES: usize = 20;
/// Series por ejercicio.
pub const MIN_SETS: i64 = 1;
pub const MAX_SETS: i64 = 10;
/// Repeticiones por serie.
pub const MIN_REPS: i64 = 1;
pub const MAX_REPS: i64 = 100;
/// Descanso entre series, en segundos.
pub const MIN_REST_SECONDS: i64 = 0;
pub const MAX_REST_SECONDS: i64 = 600;

/// Rutina tal como llega (crear y editar usan el mismo cuerpo). Los valores llegan como `Value` para señalar
/// un tipo incorrecto en su campo en lugar de rechazar todo el cuerpo.
#[derive(Debug, Clone, Default)]
pub struct RoutineInput {
    pub name: Option<Value>,
    pub exercises: Option<Value>,
}

/// Rutina validada y cruzada con el catálogo, lista para guardarse.
#[derive(Debug, Clone, PartialEq)]
pub struct ValidRoutine {
    pub name: String,
    pub exercises: Vec<RoutineExercise>,
}

// ───────────────────────── Validación (funciones puras) ─────────────────────────

const EXERCISE_NOT_IN_CATALOG: &str = "El ejercicio no existe en el catálogo";

fn present(value: Option<&Value>) -> Option<&Value> {
    value.filter(|value| !value.is_null())
}

/// Lista de ejercicios del cuerpo, si `exercises` es una lista.
fn exercise_items(input: &RoutineInput) -> Option<&Vec<Value>> {
    present(input.exercises.as_ref()).and_then(Value::as_array)
}

/// `exercise_id` bien formado (ObjectId en hex) o `None`.
fn parse_exercise_id(item: &Value) -> Option<ObjectId> {
    item.get("exercise_id")
        .and_then(Value::as_str)
        .and_then(|id| ObjectId::parse_str(id.trim()).ok())
}

/// Ids bien formados que trae el cuerpo, sin repetir: son los que hay que buscar en el catálogo.
pub fn requested_exercise_ids(input: &RoutineInput) -> Vec<ObjectId> {
    let mut ids = Vec::new();
    for id in exercise_items(input)
        .into_iter()
        .flatten()
        .filter_map(parse_exercise_id)
    {
        if !ids.contains(&id) {
            ids.push(id);
        }
    }
    ids
}

/// Entero en `[min, max]`. Acepta `3` y `3.0`; rechaza texto, decimales y booleanos.
fn parse_int(
    value: Option<&Value>,
    min: i64,
    max: i64,
    missing: &str,
    not_integer: &str,
    out_of_range: &str,
) -> Result<i32, String> {
    let value = present(value).ok_or_else(|| missing.to_string())?;
    let number = value
        .as_i64()
        .or_else(|| {
            value
                .as_f64()
                .filter(|n| n.fract() == 0.0 && n.abs() < 1e15)
                .map(|n| n as i64)
        })
        .ok_or_else(|| not_integer.to_string())?;
    if (min..=max).contains(&number) {
        // El rango cabe en i32.
        Ok(number as i32)
    } else {
        Err(out_of_range.to_string())
    }
}

fn validate_name(errors: &mut FieldErrors, name: Option<&Value>) -> Option<String> {
    let result = match present(name) {
        None => Err("El nombre es obligatorio".to_string()),
        Some(value) => match value.as_str().map(str::trim) {
            None => Err("El nombre debe ser texto".to_string()),
            Some("") => Err("El nombre es obligatorio".to_string()),
            Some(name) if name.chars().count() > NAME_MAX_CHARS => Err(format!(
                "El nombre debe tener máximo {NAME_MAX_CHARS} caracteres"
            )),
            Some(name) => Ok(name.to_string()),
        },
    };
    result
        .map_err(|message| errors.insert("name".into(), message))
        .ok()
}

/// Valor válido o `None` con su error acumulado en `field`.
fn take<T>(errors: &mut FieldErrors, field: String, result: Result<T, String>) -> Option<T> {
    result.map_err(|message| errors.insert(field, message)).ok()
}

fn validate_exercise(
    errors: &mut FieldErrors,
    index: usize,
    item: &Value,
    catalog: &HashMap<ObjectId, &Exercise>,
) -> Option<RoutineExercise> {
    let field = |name: &str| format!("exercises[{index}].{name}");
    if !item.is_object() {
        errors.insert(
            format!("exercises[{index}]"),
            "Cada ejercicio debe ser un objeto con exercise_id, sets, reps y rest_seconds".into(),
        );
        return None;
    }

    let exercise = match present(item.get("exercise_id")) {
        None => Err("El ejercicio es obligatorio".to_string()),
        Some(_) => parse_exercise_id(item)
            .and_then(|id| catalog.get(&id).copied())
            .ok_or_else(|| EXERCISE_NOT_IN_CATALOG.to_string()),
    };
    let sets = parse_int(
        item.get("sets"),
        MIN_SETS,
        MAX_SETS,
        "Las series son obligatorias",
        "Las series deben ser un número entero",
        &format!("Las series deben estar entre {MIN_SETS} y {MAX_SETS}"),
    );
    let reps = parse_int(
        item.get("reps"),
        MIN_REPS,
        MAX_REPS,
        "Las repeticiones son obligatorias",
        "Las repeticiones deben ser un número entero",
        &format!("Las repeticiones deben estar entre {MIN_REPS} y {MAX_REPS}"),
    );
    let rest_seconds = parse_int(
        item.get("rest_seconds"),
        MIN_REST_SECONDS,
        MAX_REST_SECONDS,
        "El descanso es obligatorio",
        "El descanso debe ser un número entero de segundos",
        &format!("El descanso debe estar entre {MIN_REST_SECONDS} y {MAX_REST_SECONDS} segundos"),
    );

    let exercise = take(errors, field("exercise_id"), exercise);
    let sets = take(errors, field("sets"), sets);
    let reps = take(errors, field("reps"), reps);
    let rest_seconds = take(errors, field("rest_seconds"), rest_seconds);

    Some(RoutineExercise {
        exercise_id: exercise?.id,
        name: exercise?.name.clone(),
        muscle_group: exercise?.muscle_group,
        sets: sets?,
        reps: reps?,
        rest_seconds: rest_seconds?,
    })
}

/// Valida la rutina completa contra el catálogo (los ejercicios de `requested_exercise_ids` que sí existen).
/// Acumula todos los errores: `name`, `exercises` y `exercises[i].<campo>` (RF-22, CU-04 4a y 5a).
pub fn validate_routine(
    input: &RoutineInput,
    catalog: &[Exercise],
) -> Result<ValidRoutine, AppError> {
    let mut errors = FieldErrors::new();
    let name = validate_name(&mut errors, input.name.as_ref());

    let catalog: HashMap<ObjectId, &Exercise> = catalog.iter().map(|e| (e.id, e)).collect();
    let exercises = match present(input.exercises.as_ref()) {
        None => {
            errors.insert(
                "exercises".into(),
                "La rutina debe tener al menos un ejercicio".into(),
            );
            None
        }
        Some(value) => match value.as_array() {
            None => {
                errors.insert(
                    "exercises".into(),
                    "Los ejercicios deben ser una lista".into(),
                );
                None
            }
            Some(items) if items.len() < MIN_EXERCISES => {
                errors.insert(
                    "exercises".into(),
                    "La rutina debe tener al menos un ejercicio".into(),
                );
                None
            }
            Some(items) if items.len() > MAX_EXERCISES => {
                errors.insert(
                    "exercises".into(),
                    format!("La rutina puede tener máximo {MAX_EXERCISES} ejercicios"),
                );
                None
            }
            Some(items) => items
                .iter()
                .enumerate()
                .map(|(index, item)| validate_exercise(&mut errors, index, item, &catalog))
                .collect::<Vec<_>>()
                .into_iter()
                .collect::<Option<Vec<_>>>(),
        },
    };

    match (name, exercises) {
        (Some(name), Some(exercises)) if errors.is_empty() => Ok(ValidRoutine { name, exercises }),
        _ => Err(AppError::Validation(errors)),
    }
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn routines(db: &Database) -> Collection<Routine> {
    db.collection(ROUTINES_COLLECTION)
}

/// Ejercicios del catálogo con esos ids (una consulta con `$in`).
async fn find_catalog_exercises(
    db: &Database,
    ids: Vec<ObjectId>,
) -> Result<Vec<Exercise>, AppError> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    let cursor = db
        .collection::<Exercise>(EXERCISES_COLLECTION)
        .find(doc! { "_id": { "$in": ids } })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

/// Valida el cuerpo y lo cruza con el catálogo de TEC-09.
async fn validate_with_catalog(
    db: &Database,
    input: &RoutineInput,
) -> Result<ValidRoutine, AppError> {
    let catalog = find_catalog_exercises(db, requested_exercise_ids(input)).await?;
    validate_routine(input, &catalog)
}

/// Id de una rutina; mal formado se trata como inexistente.
fn parse_routine_id(id: &str) -> Result<ObjectId, AppError> {
    ObjectId::parse_str(id).map_err(|_| AppError::RoutineNotFound)
}

/// HU-18 — crea una rutina del coach.
pub async fn create_routine(
    db: &Database,
    coach_id: ObjectId,
    input: RoutineInput,
) -> Result<Routine, AppError> {
    let valid = validate_with_catalog(db, &input).await?;
    let now = DateTime::now();
    let routine = Routine {
        id: ObjectId::new(),
        coach_id,
        name: valid.name,
        exercises: valid.exercises,
        created_at: now,
        updated_at: now,
    };
    routines(db)
        .insert_one(&routine)
        .await
        .map_err(AppError::internal)?;
    Ok(routine)
}

/// HU-18 — rutinas del coach, de la editada más recientemente a la más antigua.
pub async fn list_routines(db: &Database, coach_id: ObjectId) -> Result<Vec<Routine>, AppError> {
    let cursor = routines(db)
        .find(doc! { "coach_id": coach_id })
        .sort(doc! { "updated_at": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

/// HU-18 — una rutina del coach. Ajena, inexistente o con id mal formado → `ROUTINE_NOT_FOUND`.
pub async fn get_routine(
    db: &Database,
    coach_id: ObjectId,
    routine_id: &str,
) -> Result<Routine, AppError> {
    let routine_id = parse_routine_id(routine_id)?;
    routines(db)
        .find_one(doc! { "_id": routine_id, "coach_id": coach_id })
        .await
        .map_err(AppError::internal)?
        .ok_or(AppError::RoutineNotFound)
}

/// HU-18 — reemplaza el nombre y los ejercicios de una rutina del coach. Primero se comprueba que la rutina
/// sea suya (una ajena responde 404 aunque el cuerpo sea inválido) y después se valida el cuerpo.
pub async fn update_routine(
    db: &Database,
    coach_id: ObjectId,
    routine_id: &str,
    input: RoutineInput,
) -> Result<Routine, AppError> {
    let current = get_routine(db, coach_id, routine_id).await?;
    let valid = validate_with_catalog(db, &input).await?;
    let exercises = mongodb::bson::to_bson(&valid.exercises).map_err(AppError::internal)?;
    routines(db)
        .find_one_and_update(
            doc! { "_id": current.id, "coach_id": coach_id },
            doc! { "$set": {
                "name": valid.name,
                "exercises": exercises,
                "updated_at": DateTime::now(),
            } },
        )
        .return_document(ReturnDocument::After)
        .await
        .map_err(AppError::internal)?
        // Se borró entre la consulta y la edición.
        .ok_or(AppError::RoutineNotFound)
}

/// HU-18 — elimina una rutina del coach.
// TODO(HU-19): cuando existan asignaciones a clientes, decidir qué pasa con ellas al eliminar la rutina.
pub async fn delete_routine(
    db: &Database,
    coach_id: ObjectId,
    routine_id: &str,
) -> Result<(), AppError> {
    let routine_id = parse_routine_id(routine_id)?;
    let result = routines(db)
        .delete_one(doc! { "_id": routine_id, "coach_id": coach_id })
        .await
        .map_err(AppError::internal)?;
    if result.deleted_count == 0 {
        return Err(AppError::RoutineNotFound);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::exercise::{ExerciseLevel, MuscleGroup};
    use serde_json::json;

    fn exercise(name: &str, muscle_group: MuscleGroup) -> Exercise {
        Exercise {
            id: ObjectId::new(),
            name: name.into(),
            muscle_group,
            equipment: "dumbbell".into(),
            level: ExerciseLevel::Beginner,
            created_at: DateTime::now(),
        }
    }

    fn catalog() -> Vec<Exercise> {
        vec![
            exercise("Press de banca con mancuernas", MuscleGroup::Chest),
            exercise("Sentadilla trasera con barra", MuscleGroup::Legs),
        ]
    }

    fn item(id: &ObjectId, sets: Value, reps: Value, rest: Value) -> Value {
        json!({ "exercise_id": id.to_hex(), "sets": sets, "reps": reps, "rest_seconds": rest })
    }

    fn input(name: Value, exercises: Value) -> RoutineInput {
        RoutineInput {
            name: Some(name),
            exercises: Some(exercises),
        }
    }

    fn fields(result: Result<ValidRoutine, AppError>) -> FieldErrors {
        match result {
            Err(AppError::Validation(fields)) => fields,
            other => panic!("se esperaba error de validación, llegó {other:?}"),
        }
    }

    #[test]
    fn rutina_valida_se_acepta_con_nombre_y_grupo_del_catalogo() {
        let catalog = catalog();
        let body = input(
            json!("  Torso A  "),
            json!([
                item(&catalog[0].id, json!(4), json!(10), json!(90)),
                item(&catalog[1].id, json!(3), json!(12), json!(0)),
            ]),
        );
        let valid = validate_routine(&body, &catalog).unwrap();
        assert_eq!(valid.name, "Torso A");
        assert_eq!(
            valid.exercises[0],
            RoutineExercise {
                exercise_id: catalog[0].id,
                name: "Press de banca con mancuernas".into(),
                muscle_group: MuscleGroup::Chest,
                sets: 4,
                reps: 10,
                rest_seconds: 90,
            }
        );
        assert_eq!(valid.exercises[1].muscle_group, MuscleGroup::Legs);
        assert_eq!(valid.exercises[1].rest_seconds, 0);
    }

    #[test]
    fn limites_de_los_rangos_se_aceptan() {
        let catalog = catalog();
        let id = &catalog[0].id;
        for (sets, reps, rest) in [(1, 1, 0), (10, 100, 600)] {
            let body = input(
                json!("x".repeat(NAME_MAX_CHARS)),
                json!([item(id, json!(sets), json!(reps), json!(rest))]),
            );
            assert!(
                validate_routine(&body, &catalog).is_ok(),
                "{sets} {reps} {rest}"
            );
        }
        let body = input(
            json!("Pierna"),
            json!(vec![
                item(id, json!(3), json!(10), json!(60));
                MAX_EXERCISES
            ]),
        );
        assert_eq!(
            validate_routine(&body, &catalog).unwrap().exercises.len(),
            MAX_EXERCISES
        );
    }

    #[test]
    fn enteros_escritos_como_decimal_exacto_se_aceptan() {
        let catalog = catalog();
        let body = input(
            json!("Pierna"),
            json!([item(&catalog[0].id, json!(3.0), json!(10.0), json!(60.0))]),
        );
        let valid = validate_routine(&body, &catalog).unwrap();
        assert_eq!((valid.exercises[0].sets, valid.exercises[0].reps), (3, 10));
    }

    #[test]
    fn sin_nombre_y_sin_ejercicios_se_senalan_ambos() {
        let empty = fields(validate_routine(&RoutineInput::default(), &catalog()));
        assert_eq!(empty.keys().collect::<Vec<_>>(), ["exercises", "name"]);
        assert_eq!(empty["name"], "El nombre es obligatorio");
        assert_eq!(
            empty["exercises"],
            "La rutina debe tener al menos un ejercicio"
        );

        let blank = fields(validate_routine(
            &input(json!("   "), json!([])),
            &catalog(),
        ));
        assert_eq!(blank["name"], "El nombre es obligatorio");
        assert_eq!(
            blank["exercises"],
            "La rutina debe tener al menos un ejercicio"
        );

        let nulls = fields(validate_routine(
            &input(Value::Null, Value::Null),
            &catalog(),
        ));
        assert_eq!(nulls.len(), 2);
    }

    #[test]
    fn nombre_largo_o_que_no_es_texto_se_senala() {
        let catalog = catalog();
        let exercises = json!([item(&catalog[0].id, json!(3), json!(10), json!(60))]);
        let long = fields(validate_routine(
            &input(json!("x".repeat(NAME_MAX_CHARS + 1)), exercises.clone()),
            &catalog,
        ));
        assert_eq!(long["name"], "El nombre debe tener máximo 80 caracteres");
        let number = fields(validate_routine(&input(json!(5), exercises), &catalog));
        assert_eq!(number["name"], "El nombre debe ser texto");
    }

    #[test]
    fn ejercicios_que_no_son_lista_o_exceden_el_maximo_se_senalan() {
        let catalog = catalog();
        let not_list = fields(validate_routine(
            &input(json!("A"), json!({ "exercise_id": "x" })),
            &catalog,
        ));
        assert_eq!(not_list["exercises"], "Los ejercicios deben ser una lista");

        let too_many = fields(validate_routine(
            &input(
                json!("A"),
                json!(vec![
                    item(&catalog[0].id, json!(3), json!(10), json!(60));
                    MAX_EXERCISES + 1
                ]),
            ),
            &catalog,
        ));
        assert_eq!(
            too_many["exercises"],
            "La rutina puede tener máximo 20 ejercicios"
        );

        let not_object = fields(validate_routine(&input(json!("A"), json!([7])), &catalog));
        assert!(not_object.contains_key("exercises[0]"));
    }

    #[test]
    fn series_o_repeticiones_menores_a_uno_y_descanso_negativo_se_senalan_por_campo() {
        let catalog = catalog();
        let id = &catalog[0].id;
        let errors = fields(validate_routine(
            &input(
                json!("Torso"),
                json!([
                    item(id, json!(0), json!(10), json!(60)),
                    item(id, json!(3), json!(0), json!(-1)),
                ]),
            ),
            &catalog,
        ));
        assert_eq!(
            errors.keys().collect::<Vec<_>>(),
            [
                "exercises[0].sets",
                "exercises[1].reps",
                "exercises[1].rest_seconds"
            ]
        );
        assert_eq!(
            errors["exercises[0].sets"],
            "Las series deben estar entre 1 y 10"
        );
        assert_eq!(
            errors["exercises[1].reps"],
            "Las repeticiones deben estar entre 1 y 100"
        );
        assert_eq!(
            errors["exercises[1].rest_seconds"],
            "El descanso debe estar entre 0 y 600 segundos"
        );
    }

    #[test]
    fn valores_por_encima_del_maximo_se_senalan() {
        let catalog = catalog();
        let errors = fields(validate_routine(
            &input(
                json!("Torso"),
                json!([item(&catalog[0].id, json!(11), json!(101), json!(601))]),
            ),
            &catalog,
        ));
        assert_eq!(errors.len(), 3);
    }

    #[test]
    fn valores_ausentes_o_no_enteros_se_senalan() {
        let catalog = catalog();
        let errors = fields(validate_routine(
            &input(
                json!("Torso"),
                json!([
                    { "exercise_id": catalog[0].id.to_hex() },
                    item(&catalog[0].id, json!("3"), json!(10.5), json!(true)),
                ]),
            ),
            &catalog,
        ));
        assert_eq!(errors["exercises[0].sets"], "Las series son obligatorias");
        assert_eq!(
            errors["exercises[0].reps"],
            "Las repeticiones son obligatorias"
        );
        assert_eq!(
            errors["exercises[0].rest_seconds"],
            "El descanso es obligatorio"
        );
        assert_eq!(
            errors["exercises[1].sets"],
            "Las series deben ser un número entero"
        );
        assert_eq!(
            errors["exercises[1].reps"],
            "Las repeticiones deben ser un número entero"
        );
        assert_eq!(
            errors["exercises[1].rest_seconds"],
            "El descanso debe ser un número entero de segundos"
        );
    }

    #[test]
    fn ejercicio_inexistente_mal_formado_o_ausente_se_senala() {
        let catalog = catalog();
        let errors = fields(validate_routine(
            &input(
                json!("Torso"),
                json!([
                    item(&ObjectId::new(), json!(3), json!(10), json!(60)),
                    { "exercise_id": "no-es-un-id", "sets": 3, "reps": 10, "rest_seconds": 60 },
                    { "exercise_id": 12, "sets": 3, "reps": 10, "rest_seconds": 60 },
                    { "sets": 3, "reps": 10, "rest_seconds": 60 },
                    item(&catalog[1].id, json!(3), json!(10), json!(60)),
                ]),
            ),
            &catalog,
        ));
        assert_eq!(errors.len(), 4);
        for index in 0..3 {
            assert_eq!(
                errors[&format!("exercises[{index}].exercise_id")],
                EXERCISE_NOT_IN_CATALOG
            );
        }
        assert_eq!(
            errors["exercises[3].exercise_id"],
            "El ejercicio es obligatorio"
        );
    }

    #[test]
    fn errores_de_nombre_catalogo_y_volumen_se_reportan_juntos() {
        let catalog = catalog();
        let errors = fields(validate_routine(
            &input(
                json!(""),
                json!([item(&ObjectId::new(), json!(0), json!(10), json!(60))]),
            ),
            &catalog,
        ));
        assert_eq!(
            errors.keys().collect::<Vec<_>>(),
            ["exercises[0].exercise_id", "exercises[0].sets", "name"]
        );
    }

    #[test]
    fn ids_a_buscar_son_los_bien_formados_sin_repetir() {
        let a = ObjectId::new();
        let b = ObjectId::new();
        let body = input(
            json!("A"),
            json!([
                { "exercise_id": a.to_hex() },
                { "exercise_id": "mal" },
                { "exercise_id": format!(" {} ", b.to_hex()) },
                { "exercise_id": a.to_hex() },
                5,
            ]),
        );
        assert_eq!(requested_exercise_ids(&body), vec![a, b]);
        assert!(requested_exercise_ids(&RoutineInput::default()).is_empty());
    }

    /// Pruebas contra MongoDB real: `cargo test -- --ignored` con un servidor local
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::services::exercises::seed_exercises;

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn body(db: &Database, name: &str) -> RoutineInput {
            seed_exercises(db).await.unwrap();
            let catalog = crate::services::exercises::list_exercises(db, None, None)
                .await
                .unwrap();
            input(
                json!(name),
                json!([item(&catalog[0].id, json!(3), json!(10), json!(60))]),
            )
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn crear_listar_consultar_editar_y_eliminar() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let created = create_routine(&db, coach, body(&db, "Torso A").await)
                .await
                .unwrap();
            assert_eq!(created.exercises.len(), 1);

            let list = list_routines(&db, coach).await.unwrap();
            assert_eq!(list.len(), 1);
            let found = get_routine(&db, coach, &created.id.to_hex()).await.unwrap();
            assert_eq!(found.name, "Torso A");

            let updated =
                update_routine(&db, coach, &created.id.to_hex(), body(&db, "Torso B").await)
                    .await
                    .unwrap();
            assert_eq!(updated.name, "Torso B");
            assert_eq!(updated.created_at, created.created_at);

            delete_routine(&db, coach, &created.id.to_hex())
                .await
                .unwrap();
            assert!(list_routines(&db, coach).await.unwrap().is_empty());
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn rutina_ajena_inexistente_o_mal_formada_es_routine_not_found() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let other = ObjectId::new();
            let routine = create_routine(&db, owner, body(&db, "Mía").await)
                .await
                .unwrap();
            assert!(list_routines(&db, other).await.unwrap().is_empty());

            for (coach, id) in [
                (other, routine.id.to_hex()),
                (owner, ObjectId::new().to_hex()),
                (owner, "abc".to_string()),
            ] {
                let get = get_routine(&db, coach, &id).await;
                assert!(matches!(get, Err(AppError::RoutineNotFound)), "{id}");
                // La rutina ajena responde 404 aunque el cuerpo sea inválido.
                let update = update_routine(&db, coach, &id, RoutineInput::default()).await;
                assert!(matches!(update, Err(AppError::RoutineNotFound)), "{id}");
                let delete = delete_routine(&db, coach, &id).await;
                assert!(matches!(delete, Err(AppError::RoutineNotFound)), "{id}");
            }
            // Los intentos ajenos no la tocaron.
            let still = get_routine(&db, owner, &routine.id.to_hex()).await.unwrap();
            assert_eq!(still.name, "Mía");
            db.drop().await.unwrap();
        }
    }
}
