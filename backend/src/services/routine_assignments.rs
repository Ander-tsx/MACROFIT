//! HU-19 — asignación de rutinas del coach a sus clientes (RF-23, CU-04 pasos 5 y 6, alterno 5a).
//!
//! - Solo se asignan rutinas propias (`routines::get_routine`: ajena o inexistente → `ROUTINE_NOT_FOUND`).
//! - Solo a clientes con vinculación activa (RN-04). Si alguno no lo está, no se asigna a ninguno (todo o nada) y
//!   `CLIENT_NOT_LINKED` señala cuáles en `client_ids[i]`.
//! - Una sola asignación `active` por rutina y cliente (índice único parcial en `db.rs`): repetir no duplica.
//! - La colección `routine_assignments` se comparte con HU-16-API y HU-17-API (`models/routine_assignment.rs`).
//!
//! HU-20 — retiro de una rutina asignada (RF-24): la asignación activa pasa a `removed` (con `removed_at`); nunca se
//! borran las sesiones completadas (`routine_sessions`). Editar la rutina (PUT de HU-18) no toca las asignaciones: el
//! cliente lee la rutina en cada consulta y ve la versión nueva.

use std::collections::{HashMap, HashSet};

use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
};
use serde_json::Value;

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::routine_assignment::{
    AssignmentStatus, ROUTINE_ASSIGNMENTS_COLLECTION, RoutineAssignment,
};
use crate::models::user::{USERS_COLLECTION, User};
use crate::services::coach_invite_codes::is_duplicate_key;
use crate::services::routines;

/// Clientes por petición.
pub const MAX_CLIENTS_PER_REQUEST: usize = 50;

const CLIENT_IDS_REQUIRED: &str = "Elige al menos un cliente";
const CLIENT_ID_INVALID: &str = "El id del cliente no es válido";
const CLIENT_NOT_LINKED: &str = "El cliente no está vinculado contigo";

/// Cliente pedido: su id y la posición en la que llegó (para señalar `client_ids[i]`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RequestedClient {
    pub index: usize,
    pub id: ObjectId,
}

/// Asignación con el nombre del cliente, lista para la respuesta.
#[derive(Debug, Clone)]
pub struct AssignmentView {
    pub assignment: RoutineAssignment,
    pub client_name: String,
}

// ───────────────────────── Funciones puras ─────────────────────────

/// Valida `client_ids`: lista de 1 a `MAX_CLIENTS_PER_REQUEST` ids (ObjectId en hex). Señala todos los ids
/// inválidos a la vez (`client_ids[i]`). Los repetidos se toman una vez, en el orden en que llegaron.
pub fn validate_client_ids(raw: Option<&Value>) -> Result<Vec<RequestedClient>, AppError> {
    let invalid = |message: String| {
        AppError::Validation(FieldErrors::from([("client_ids".to_string(), message)]))
    };
    let items = match raw.filter(|value| !value.is_null()) {
        None => return Err(invalid(CLIENT_IDS_REQUIRED.into())),
        Some(value) => value
            .as_array()
            .ok_or_else(|| invalid("Los clientes deben ser una lista de ids".into()))?,
    };
    if items.is_empty() {
        return Err(invalid(CLIENT_IDS_REQUIRED.into()));
    }
    if items.len() > MAX_CLIENTS_PER_REQUEST {
        return Err(invalid(format!(
            "Puedes asignar máximo {MAX_CLIENTS_PER_REQUEST} clientes a la vez"
        )));
    }

    let mut errors = FieldErrors::new();
    let mut requested: Vec<RequestedClient> = Vec::new();
    for (index, item) in items.iter().enumerate() {
        match item
            .as_str()
            .and_then(|id| ObjectId::parse_str(id.trim()).ok())
        {
            None => {
                errors.insert(format!("client_ids[{index}]"), CLIENT_ID_INVALID.into());
            }
            Some(id) if requested.iter().any(|client| client.id == id) => {}
            Some(id) => requested.push(RequestedClient { index, id }),
        }
    }
    if errors.is_empty() {
        Ok(requested)
    } else {
        Err(AppError::Validation(errors))
    }
}

/// `client_ids[i]` de cada cliente pedido que no está en `linked` (vinculaciones activas del coach).
pub fn unlinked_client_errors(
    requested: &[RequestedClient],
    linked: &HashSet<ObjectId>,
) -> FieldErrors {
    requested
        .iter()
        .filter(|client| !linked.contains(&client.id))
        .map(|client| {
            (
                format!("client_ids[{}]", client.index),
                CLIENT_NOT_LINKED.to_string(),
            )
        })
        .collect()
}

/// Une cada asignación con el nombre de su cliente y deja fuera las de clientes sin vinculación activa
/// (o cuya cuenta ya no existe). Conserva el orden de `assignments`.
pub fn build_assignment_views(
    assignments: Vec<RoutineAssignment>,
    users: Vec<User>,
    linked: &HashSet<ObjectId>,
) -> Vec<AssignmentView> {
    let names: HashMap<ObjectId, String> = users
        .into_iter()
        .filter_map(|user| user.id.map(|id| (id, user.name)))
        .collect();
    assignments
        .into_iter()
        .filter(|assignment| linked.contains(&assignment.client_id))
        .filter_map(|assignment| {
            let client_name = names.get(&assignment.client_id)?.clone();
            Some(AssignmentView {
                assignment,
                client_name,
            })
        })
        .collect()
}

/// HU-20 — id del cliente de la ruta. Uno mal formado no puede tener asignación: `ASSIGNMENT_NOT_FOUND`.
pub fn parse_client_id(client_id: &str) -> Result<ObjectId, AppError> {
    ObjectId::parse_str(client_id.trim()).map_err(|_| AppError::AssignmentNotFound)
}

/// Ordena las asignaciones en el orden en que se pidieron los clientes.
pub fn order_by_request(
    mut assignments: Vec<RoutineAssignment>,
    requested: &[RequestedClient],
) -> Vec<RoutineAssignment> {
    let position: HashMap<ObjectId, usize> = requested
        .iter()
        .enumerate()
        .map(|(position, client)| (client.id, position))
        .collect();
    assignments.sort_by_key(|a| position.get(&a.client_id).copied().unwrap_or(usize::MAX));
    assignments
}

// ───────────────────────────── Acceso a Mongo ─────────────────────────────

fn assignments(db: &Database) -> Collection<RoutineAssignment> {
    db.collection(ROUTINE_ASSIGNMENTS_COLLECTION)
}

/// Clientes de `client_ids` con vinculación activa con el coach (una consulta con `$in`).
async fn linked_clients(
    db: &Database,
    coach_id: ObjectId,
    client_ids: Vec<ObjectId>,
) -> Result<HashSet<ObjectId>, AppError> {
    let cursor = db
        .collection::<CoachLink>(COACH_LINKS_COLLECTION)
        .find(doc! { "coach_id": coach_id, "user_id": { "$in": client_ids }, "status": "active" })
        .await
        .map_err(AppError::internal)?;
    Ok(collect_cursor(cursor)
        .await?
        .into_iter()
        .map(|link| link.user_id)
        .collect())
}

async fn find_users(db: &Database, ids: Vec<ObjectId>) -> Result<Vec<User>, AppError> {
    let cursor = db
        .collection::<User>(USERS_COLLECTION)
        .find(doc! { "_id": { "$in": ids } })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
}

/// HU-19 — asigna una rutina propia a los clientes de `client_ids` y devuelve la asignación activa de cada uno
/// (las nuevas y las que ya existían, en el orden pedido).
///
/// Orden de las comprobaciones: rutina propia (404) → cuerpo (400) → vinculaciones (403). Nada se escribe hasta que
/// todos los clientes pasan.
pub async fn assign_routine(
    db: &Database,
    coach_id: ObjectId,
    routine_id: &str,
    client_ids: Option<Value>,
) -> Result<Vec<AssignmentView>, AppError> {
    let routine = routines::get_routine(db, coach_id, routine_id).await?;
    let requested = validate_client_ids(client_ids.as_ref())?;
    let ids: Vec<ObjectId> = requested.iter().map(|client| client.id).collect();

    let linked = linked_clients(db, coach_id, ids.clone()).await?;
    let unlinked = unlinked_client_errors(&requested, &linked);
    if !unlinked.is_empty() {
        return Err(AppError::ClientsNotLinked(unlinked));
    }

    let now = DateTime::now();
    for client_id in &ids {
        // El filtro incluye `status: active`: si ya hay una activa no se toca; si no, se inserta con los campos
        // del filtro más los de `$setOnInsert`.
        let result = assignments(db)
            .update_one(
                doc! { "routine_id": routine.id, "client_id": client_id, "status": "active" },
                doc! { "$setOnInsert": {
                    "_id": ObjectId::new(),
                    "coach_id": coach_id,
                    "assigned_at": now,
                    "updated_at": now,
                } },
            )
            .upsert(true)
            .await;
        match result {
            Ok(_) => {}
            // Otra petición la creó entre la búsqueda y la inserción: ya existe, que es lo que se pidió.
            Err(e) if is_duplicate_key(&e) => {}
            Err(e) => return Err(AppError::internal(e)),
        }
    }

    let cursor = assignments(db)
        .find(doc! {
            "routine_id": routine.id,
            "client_id": { "$in": ids.clone() },
            "status": "active",
        })
        .await
        .map_err(AppError::internal)?;
    let active = order_by_request(collect_cursor(cursor).await?, &requested);
    let users = find_users(db, ids).await?;
    Ok(build_assignment_views(active, users, &linked))
}

/// HU-19 — clientes con la rutina propia asignada (activa) y vinculación activa, la asignación más reciente primero.
/// Tres consultas en total, sin importar cuántos clientes tenga.
pub async fn list_assignments(
    db: &Database,
    coach_id: ObjectId,
    routine_id: &str,
) -> Result<Vec<AssignmentView>, AppError> {
    let routine = routines::get_routine(db, coach_id, routine_id).await?;
    let cursor = assignments(db)
        .find(doc! { "routine_id": routine.id, "status": "active" })
        .sort(doc! { "assigned_at": -1, "_id": -1 })
        .await
        .map_err(AppError::internal)?;
    let active = collect_cursor(cursor).await?;
    if active.is_empty() {
        return Ok(Vec::new());
    }
    let client_ids: Vec<ObjectId> = active.iter().map(|a| a.client_id).collect();
    let linked = linked_clients(db, coach_id, client_ids.clone()).await?;
    let users = find_users(db, linked.iter().copied().collect()).await?;
    Ok(build_assignment_views(active, users, &linked))
}

/// HU-20 — retira una rutina propia de un cliente: su asignación activa pasa a `removed` (se conserva como historial,
/// igual que `retire_routine_assignments`). Las sesiones completadas del cliente no se tocan (RF-24).
///
/// Orden de las comprobaciones: rutina propia (`ROUTINE_NOT_FOUND`) → asignación activa (`ASSIGNMENT_NOT_FOUND`: ya se
/// retiró, nunca la tuvo o el id del cliente no existe o está mal formado). No exige vinculación activa: una asignación
/// que quedó activa tras una desvinculación también se puede retirar.
pub async fn remove_assignment(
    db: &Database,
    coach_id: ObjectId,
    routine_id: &str,
    client_id: &str,
) -> Result<(), AppError> {
    let routine = routines::get_routine(db, coach_id, routine_id).await?;
    let client_id = parse_client_id(client_id)?;
    let now = DateTime::now();
    let result = assignments(db)
        .update_one(
            doc! { "routine_id": routine.id, "client_id": client_id, "status": "active" },
            doc! { "$set": {
                "status": AssignmentStatus::Removed.as_str(),
                "removed_at": now,
                "updated_at": now,
            } },
        )
        .await
        .map_err(AppError::internal)?;
    if result.matched_count == 0 {
        return Err(AppError::AssignmentNotFound);
    }
    Ok(())
}

/// HU-19 — al eliminar una rutina (HU-18), sus asignaciones activas pasan a `removed` (se conservan como historial).
/// HU-20: `delete_routine` lo llama **antes** de borrar la rutina.
pub async fn retire_routine_assignments(
    db: &Database,
    routine_id: ObjectId,
) -> Result<u64, AppError> {
    let now = DateTime::now();
    let result = assignments(db)
        .update_many(
            doc! { "routine_id": routine_id, "status": "active" },
            doc! { "$set": {
                "status": AssignmentStatus::Removed.as_str(),
                "removed_at": now,
                "updated_at": now,
            } },
        )
        .await
        .map_err(AppError::internal)?;
    Ok(result.modified_count)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::user::Role;
    use serde_json::json;

    fn fields(result: Result<Vec<RequestedClient>, AppError>) -> FieldErrors {
        match result {
            Err(AppError::Validation(fields)) => fields,
            other => panic!("se esperaba error de validación, llegó {other:?}"),
        }
    }

    fn user(id: ObjectId, name: &str) -> User {
        User {
            id: Some(id),
            name: name.into(),
            email: format!("{}@macrofit.test", name.to_lowercase()),
            password_hash: "hash".into(),
            role: Role::User,
            privacy_accepted_at: None,
            privacy_version: None,
            profile_completed: false,
            created_at: DateTime::now(),
        }
    }

    fn assignment(client_id: ObjectId) -> RoutineAssignment {
        RoutineAssignment {
            id: ObjectId::new(),
            routine_id: ObjectId::new(),
            coach_id: ObjectId::new(),
            client_id,
            status: AssignmentStatus::Active,
            assigned_at: DateTime::now(),
            updated_at: DateTime::now(),
            removed_at: None,
        }
    }

    #[test]
    fn uno_o_varios_ids_validos_se_aceptan_en_orden() {
        let (a, b) = (ObjectId::new(), ObjectId::new());
        let one = validate_client_ids(Some(&json!([a.to_hex()]))).unwrap();
        assert_eq!(one, vec![RequestedClient { index: 0, id: a }]);

        let many =
            validate_client_ids(Some(&json!([b.to_hex(), format!(" {} ", a.to_hex())]))).unwrap();
        assert_eq!(
            many,
            vec![
                RequestedClient { index: 0, id: b },
                RequestedClient { index: 1, id: a }
            ]
        );
    }

    #[test]
    fn ids_repetidos_se_toman_una_vez() {
        let (a, b) = (ObjectId::new(), ObjectId::new());
        let requested =
            validate_client_ids(Some(&json!([a.to_hex(), b.to_hex(), a.to_hex()]))).unwrap();
        assert_eq!(
            requested.iter().map(|c| c.id).collect::<Vec<_>>(),
            vec![a, b]
        );
    }

    #[test]
    fn lista_ausente_nula_o_vacia_es_error_en_client_ids() {
        for raw in [None, Some(Value::Null), Some(json!([]))] {
            let errors = fields(validate_client_ids(raw.as_ref()));
            assert_eq!(errors.len(), 1);
            assert_eq!(errors["client_ids"], CLIENT_IDS_REQUIRED);
        }
    }

    #[test]
    fn client_ids_que_no_es_lista_se_senala() {
        for raw in [
            json!("6ad0a1b2c3d4e5f6a7b8c9d0"),
            json!({ "id": 1 }),
            json!(5),
        ] {
            let errors = fields(validate_client_ids(Some(&raw)));
            assert_eq!(
                errors["client_ids"],
                "Los clientes deben ser una lista de ids"
            );
        }
    }

    #[test]
    fn mas_del_maximo_de_clientes_se_senala() {
        let ids: Vec<String> = (0..=MAX_CLIENTS_PER_REQUEST)
            .map(|_| ObjectId::new().to_hex())
            .collect();
        let errors = fields(validate_client_ids(Some(&json!(ids))));
        assert_eq!(
            errors["client_ids"],
            "Puedes asignar máximo 50 clientes a la vez"
        );

        let ids: Vec<String> = (0..MAX_CLIENTS_PER_REQUEST)
            .map(|_| ObjectId::new().to_hex())
            .collect();
        assert_eq!(
            validate_client_ids(Some(&json!(ids))).unwrap().len(),
            MAX_CLIENTS_PER_REQUEST
        );
    }

    #[test]
    fn ids_mal_formados_se_senalan_todos_por_posicion() {
        let errors = fields(validate_client_ids(Some(&json!([
            ObjectId::new().to_hex(),
            "abc",
            12,
            null,
            "",
            ObjectId::new().to_hex(),
        ]))));
        assert_eq!(
            errors.keys().collect::<Vec<_>>(),
            [
                "client_ids[1]",
                "client_ids[2]",
                "client_ids[3]",
                "client_ids[4]"
            ]
        );
        assert!(errors.values().all(|m| m == CLIENT_ID_INVALID));
    }

    #[test]
    fn clientes_no_vinculados_se_senalan_con_su_posicion_original() {
        let (a, b, c) = (ObjectId::new(), ObjectId::new(), ObjectId::new());
        // `a` repetido: `c` llegó en la posición 3.
        let requested = validate_client_ids(Some(&json!([
            a.to_hex(),
            b.to_hex(),
            a.to_hex(),
            c.to_hex()
        ])))
        .unwrap();
        let linked = HashSet::from([a]);
        let errors = unlinked_client_errors(&requested, &linked);
        assert_eq!(
            errors.keys().collect::<Vec<_>>(),
            ["client_ids[1]", "client_ids[3]"]
        );
        assert_eq!(errors["client_ids[1]"], CLIENT_NOT_LINKED);

        let all_linked = HashSet::from([a, b, c]);
        assert!(unlinked_client_errors(&requested, &all_linked).is_empty());
    }

    #[test]
    fn la_vista_une_nombres_y_deja_fuera_a_los_no_vinculados() {
        let (ana, bruno, carla) = (ObjectId::new(), ObjectId::new(), ObjectId::new());
        let views = build_assignment_views(
            vec![assignment(bruno), assignment(ana), assignment(carla)],
            vec![user(ana, "Ana"), user(bruno, "Bruno"), user(carla, "Carla")],
            &HashSet::from([ana, bruno]),
        );
        let names: Vec<&str> = views.iter().map(|v| v.client_name.as_str()).collect();
        assert_eq!(names, ["Bruno", "Ana"]);
    }

    #[test]
    fn la_vista_omite_asignaciones_de_cuentas_que_ya_no_existen() {
        let ana = ObjectId::new();
        let views = build_assignment_views(vec![assignment(ana)], vec![], &HashSet::from([ana]));
        assert!(views.is_empty());
    }

    #[test]
    fn las_asignaciones_se_ordenan_como_se_pidieron() {
        let (a, b, c) = (ObjectId::new(), ObjectId::new(), ObjectId::new());
        let requested = [
            RequestedClient { index: 0, id: c },
            RequestedClient { index: 1, id: a },
            RequestedClient { index: 2, id: b },
        ];
        let ordered = order_by_request(
            vec![assignment(a), assignment(b), assignment(c)],
            &requested,
        );
        assert_eq!(
            ordered.iter().map(|x| x.client_id).collect::<Vec<_>>(),
            vec![c, a, b]
        );
    }

    #[test]
    fn id_de_cliente_valido_se_acepta_y_uno_mal_formado_es_asignacion_inexistente() {
        let id = ObjectId::new();
        assert_eq!(parse_client_id(&id.to_hex()).unwrap(), id);
        assert_eq!(parse_client_id(&format!(" {} ", id.to_hex())).unwrap(), id);
        for raw in [
            "",
            "abc",
            "6ad0a1b2c3d4e5f6a7b8c9dz",
            "6ad0a1b2c3d4e5f6a7b8c9d00",
        ] {
            assert!(
                matches!(parse_client_id(raw), Err(AppError::AssignmentNotFound)),
                "{raw}"
            );
        }
    }

    #[test]
    fn el_estado_se_guarda_en_minusculas() {
        let doc = mongodb::bson::to_document(&assignment(ObjectId::new())).unwrap();
        assert_eq!(doc.get_str("status").unwrap(), "active");
        assert!(!doc.contains_key("removed_at"), "solo en las retiradas");
        assert_eq!(AssignmentStatus::Removed.as_str(), "removed");
    }

    /// Pruebas contra MongoDB real: `cargo test -- --ignored` con un servidor local
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::models::coach_link::LinkStatus;
        use crate::models::routine_session::{ROUTINE_SESSIONS_COLLECTION, RoutineSession};
        use crate::services::exercises::{list_exercises, seed_exercises};
        use crate::services::routine_sessions::{complete_session, list_sessions};
        use crate::services::routines::{
            RoutineInput, create_routine, delete_routine, update_routine,
        };
        use crate::services::user_routines::get_user_routine;

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn routine(db: &Database, coach: ObjectId) -> String {
            seed_exercises(db).await.unwrap();
            let catalog = list_exercises(db, None, None).await.unwrap();
            let input = RoutineInput {
                name: Some(json!("Torso A")),
                exercises: Some(json!([{
                    "exercise_id": catalog[0].id.to_hex(), "sets": 3, "reps": 10, "rest_seconds": 60
                }])),
            };
            create_routine(db, coach, input).await.unwrap().id.to_hex()
        }

        /// Cliente con cuenta y, si `status` no es `None`, vinculación con el coach.
        async fn client(
            db: &Database,
            coach: ObjectId,
            name: &str,
            status: Option<LinkStatus>,
        ) -> ObjectId {
            let id = ObjectId::new();
            db.collection::<User>(USERS_COLLECTION)
                .insert_one(user(id, name))
                .await
                .unwrap();
            if let Some(status) = status {
                db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
                    .insert_one(CoachLink {
                        id: ObjectId::new(),
                        coach_id: coach,
                        user_id: id,
                        status,
                        created_at: DateTime::now(),
                    })
                    .await
                    .unwrap();
            }
            id
        }

        fn ids(clients: &[ObjectId]) -> Option<Value> {
            Some(json!(
                clients.iter().map(|c| c.to_hex()).collect::<Vec<_>>()
            ))
        }

        async fn count(db: &Database, filter: mongodb::bson::Document) -> u64 {
            assignments(db).count_documents(filter).await.unwrap()
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn asignar_a_varios_sin_duplicar_y_listar() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let routine_id = routine(&db, coach).await;
            let ana = client(&db, coach, "Ana", Some(LinkStatus::Active)).await;
            let bruno = client(&db, coach, "Bruno", Some(LinkStatus::Active)).await;

            let first = assign_routine(&db, coach, &routine_id, ids(&[ana]))
                .await
                .unwrap();
            assert_eq!(first.len(), 1);
            assert_eq!(first[0].client_name, "Ana");

            // Repetir a Ana y agregar a Bruno: Ana conserva su asignación.
            let second = assign_routine(&db, coach, &routine_id, ids(&[bruno, ana, bruno]))
                .await
                .unwrap();
            let names: Vec<&str> = second.iter().map(|v| v.client_name.as_str()).collect();
            assert_eq!(names, ["Bruno", "Ana"]);
            assert_eq!(second[1].assignment.id, first[0].assignment.id);
            assert_eq!(
                second[1].assignment.assigned_at,
                first[0].assignment.assigned_at
            );
            assert_eq!(count(&db, doc! {}).await, 2);

            let list = list_assignments(&db, coach, &routine_id).await.unwrap();
            assert_eq!(list.len(), 2);
            assert!(list.iter().all(|v| v.assignment.coach_id == coach));
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn un_cliente_no_vinculado_impide_asignar_a_todos() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let other_coach = ObjectId::new();
            let routine_id = routine(&db, coach).await;
            let ana = client(&db, coach, "Ana", Some(LinkStatus::Active)).await;
            let gone = client(&db, coach, "Bruno", Some(LinkStatus::Unlinked)).await;
            let foreign = client(&db, other_coach, "Carla", Some(LinkStatus::Active)).await;
            let missing = ObjectId::new();

            let result =
                assign_routine(&db, coach, &routine_id, ids(&[ana, gone, foreign, missing])).await;
            match result {
                Err(AppError::ClientsNotLinked(fields)) => assert_eq!(
                    fields.keys().collect::<Vec<_>>(),
                    ["client_ids[1]", "client_ids[2]", "client_ids[3]"]
                ),
                other => panic!("se esperaba ClientsNotLinked, llegó {other:?}"),
            }
            assert_eq!(count(&db, doc! {}).await, 0, "todo o nada");
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn rutina_ajena_responde_404_antes_de_validar() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let other = ObjectId::new();
            let routine_id = routine(&db, owner).await;
            for (coach, id) in [
                (other, routine_id.clone()),
                (owner, ObjectId::new().to_hex()),
                (owner, "abc".to_string()),
            ] {
                let assign = assign_routine(&db, coach, &id, None).await;
                assert!(matches!(assign, Err(AppError::RoutineNotFound)), "{id}");
                let list = list_assignments(&db, coach, &id).await;
                assert!(matches!(list, Err(AppError::RoutineNotFound)), "{id}");
            }
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn desvinculado_sale_de_la_lista_y_eliminar_la_rutina_retira_las_asignaciones() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let routine_id = routine(&db, coach).await;
            let ana = client(&db, coach, "Ana", Some(LinkStatus::Active)).await;
            let bruno = client(&db, coach, "Bruno", Some(LinkStatus::Active)).await;
            assign_routine(&db, coach, &routine_id, ids(&[ana, bruno]))
                .await
                .unwrap();

            db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
                .update_one(
                    doc! { "user_id": bruno },
                    doc! { "$set": { "status": "unlinked" } },
                )
                .await
                .unwrap();
            let list = list_assignments(&db, coach, &routine_id).await.unwrap();
            assert_eq!(list.len(), 1);
            assert_eq!(list[0].assignment.client_id, ana);

            delete_routine(&db, coach, &routine_id).await.unwrap();
            assert_eq!(count(&db, doc! { "status": "active" }).await, 0);
            assert_eq!(
                count(
                    &db,
                    doc! { "status": "removed", "removed_at": { "$type": "date" } }
                )
                .await,
                2
            );
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn el_indice_impide_dos_asignaciones_activas_iguales() {
            let db = test_db().await;
            let mut a = assignment(ObjectId::new());
            assignments(&db).insert_one(&a).await.unwrap();
            a.id = ObjectId::new();
            let err = assignments(&db).insert_one(&a).await.unwrap_err();
            assert!(is_duplicate_key(&err));
            // Una retirada no choca con la activa.
            a.id = ObjectId::new();
            a.status = AssignmentStatus::Removed;
            a.removed_at = Some(DateTime::now());
            assignments(&db).insert_one(&a).await.unwrap();
            db.drop().await.unwrap();
        }

        /// El cliente marca como completada la sesión 1 de la rutina hoy (HU-17).
        async fn complete(db: &Database, client: ObjectId, routine_id: &str) {
            let offset = chrono::FixedOffset::west_opt(6 * 3600).unwrap();
            complete_session(db, client, offset, routine_id, Some(json!(1)), None)
                .await
                .unwrap();
        }

        async fn sessions_of(db: &Database, client: ObjectId) -> u64 {
            db.collection::<RoutineSession>(ROUTINE_SESSIONS_COLLECTION)
                .count_documents(doc! { "user_id": client })
                .await
                .unwrap()
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn retirar_de_un_cliente_conserva_sus_sesiones_y_el_repetido_es_404() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let routine_id = routine(&db, coach).await;
            let ana = client(&db, coach, "Ana", Some(LinkStatus::Active)).await;
            let bruno = client(&db, coach, "Bruno", Some(LinkStatus::Active)).await;
            assign_routine(&db, coach, &routine_id, ids(&[ana, bruno]))
                .await
                .unwrap();
            complete(&db, ana, &routine_id).await;

            remove_assignment(&db, coach, &routine_id, &ana.to_hex())
                .await
                .unwrap();

            // Solo la de Ana pasa a `removed`, con fecha; la de Bruno sigue activa.
            let removed =
                doc! { "client_id": ana, "status": "removed", "removed_at": { "$type": "date" } };
            assert_eq!(count(&db, removed).await, 1);
            assert_eq!(
                count(&db, doc! { "client_id": bruno, "status": "active" }).await,
                1
            );
            let list = list_assignments(&db, coach, &routine_id).await.unwrap();
            assert_eq!(
                list.iter()
                    .map(|v| v.assignment.client_id)
                    .collect::<Vec<_>>(),
                vec![bruno]
            );
            // Ana deja de ver la rutina y su sesión completada se conserva (RF-24).
            assert!(matches!(
                get_user_routine(&db, ana, &routine_id).await,
                Err(AppError::RoutineNotFound)
            ));
            assert_eq!(sessions_of(&db, ana).await, 1);

            // Retiro repetido, cliente sin la rutina e id mal formado.
            for client_id in [ana.to_hex(), ObjectId::new().to_hex(), "abc".to_string()] {
                let result = remove_assignment(&db, coach, &routine_id, &client_id).await;
                assert!(
                    matches!(result, Err(AppError::AssignmentNotFound)),
                    "{client_id}"
                );
            }

            // Si se le vuelve a asignar, recupera su historial.
            assign_routine(&db, coach, &routine_id, ids(&[ana]))
                .await
                .unwrap();
            let history = list_sessions(&db, ana, &routine_id).await.unwrap();
            assert_eq!(history.len(), 1);
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn retirar_de_una_rutina_ajena_o_inexistente_es_404_y_no_retira_nada() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let other = ObjectId::new();
            let routine_id = routine(&db, owner).await;
            let ana = client(&db, owner, "Ana", Some(LinkStatus::Active)).await;
            assign_routine(&db, owner, &routine_id, ids(&[ana]))
                .await
                .unwrap();
            for (coach, id) in [
                (other, routine_id.clone()),
                (owner, ObjectId::new().to_hex()),
                (owner, "abc".to_string()),
            ] {
                let result = remove_assignment(&db, coach, &id, &ana.to_hex()).await;
                assert!(matches!(result, Err(AppError::RoutineNotFound)), "{id}");
            }
            assert_eq!(count(&db, doc! { "status": "active" }).await, 1);
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn editar_una_rutina_asignada_se_refleja_en_el_cliente() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let routine_id = routine(&db, coach).await;
            let ana = client(&db, coach, "Ana", Some(LinkStatus::Active)).await;
            assign_routine(&db, coach, &routine_id, ids(&[ana]))
                .await
                .unwrap();
            complete(&db, ana, &routine_id).await;

            let catalog = list_exercises(&db, None, None).await.unwrap();
            let input = RoutineInput {
                name: Some(json!("Torso A v2")),
                exercises: Some(json!([{
                    "exercise_id": catalog[1].id.to_hex(), "sets": 5, "reps": 8, "rest_seconds": 120
                }])),
            };
            update_routine(&db, coach, &routine_id, input)
                .await
                .unwrap();

            let detail = get_user_routine(&db, ana, &routine_id).await.unwrap();
            assert_eq!(detail.name, "Torso A v2");
            let exercise = &detail.sessions[0].exercises[0];
            assert_eq!(exercise.exercise_id, catalog[1].id);
            assert_eq!(
                (exercise.sets, exercise.reps, exercise.rest_seconds),
                (5, 8, 120)
            );
            // La asignación sigue igual y la sesión ya registrada conserva el nombre de entonces.
            assert_eq!(
                count(&db, doc! { "client_id": ana, "status": "active" }).await,
                1
            );
            let history = list_sessions(&db, ana, &routine_id).await.unwrap();
            assert_eq!(history[0].routine_name, "Torso A");
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn eliminar_una_rutina_asignada_retira_todo_y_conserva_las_sesiones() {
            let db = test_db().await;
            let coach = ObjectId::new();
            let routine_id = routine(&db, coach).await;
            let ana = client(&db, coach, "Ana", Some(LinkStatus::Active)).await;
            let bruno = client(&db, coach, "Bruno", Some(LinkStatus::Active)).await;
            assign_routine(&db, coach, &routine_id, ids(&[ana, bruno]))
                .await
                .unwrap();
            complete(&db, ana, &routine_id).await;
            complete(&db, bruno, &routine_id).await;

            delete_routine(&db, coach, &routine_id).await.unwrap();

            assert_eq!(count(&db, doc! { "status": "active" }).await, 0);
            assert_eq!(count(&db, doc! { "status": "removed" }).await, 2);
            assert!(matches!(
                routines::get_routine(&db, coach, &routine_id).await,
                Err(AppError::RoutineNotFound)
            ));
            for client_id in [ana, bruno] {
                assert!(matches!(
                    get_user_routine(&db, client_id, &routine_id).await,
                    Err(AppError::RoutineNotFound)
                ));
                assert_eq!(sessions_of(&db, client_id).await, 1, "RF-24");
            }
            db.drop().await.unwrap();
        }
    }
}
