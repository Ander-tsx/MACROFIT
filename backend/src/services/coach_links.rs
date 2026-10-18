//! HU-05 — vinculaciones coach-cliente. El alta real llega con HU-13; mientras tanto
//! `seed_link` crea vinculaciones de prueba (solo en desarrollo).
//! HU-24: `list_clients` agrega a cada cliente su meta vigente y la fecha de su último registro de comida.

use std::collections::HashMap;

use mongodb::{
    Collection, Database,
    bson::{DateTime, Document, doc, oid::ObjectId},
    options::ReturnDocument,
};

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::coach_invite_code::{COACH_INVITE_CODES_COLLECTION, CoachInviteCode};
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::goal::NutritionalGoal;
use crate::models::user::{Role, USERS_COLLECTION, User};
use crate::services::auth::find_user_by_id;
use crate::services::coach_invite_codes::is_duplicate_key;
use crate::services::{goals, meals};

fn links(db: &Database) -> Collection<CoachLink> {
    db.collection(COACH_LINKS_COLLECTION)
}

/// Id del cliente si el coach tiene una vinculación activa con él.
/// Un id mal formado se trata igual que un cliente no vinculado.
pub async fn require_active_link(
    db: &Database,
    coach_id: ObjectId,
    client_id: &str,
) -> Result<ObjectId, AppError> {
    let client_id = ObjectId::parse_str(client_id).map_err(|_| AppError::ClientNotLinked)?;
    links(db)
        .find_one(doc! { "coach_id": coach_id, "user_id": client_id, "status": "active" })
        .await
        .map_err(AppError::internal)?
        .map(|link| link.user_id)
        .ok_or(AppError::ClientNotLinked)
}

/// `true` si existe una vinculación activa entre el coach y el usuario (TEC-13: acceso a las fotos).
pub async fn has_active_link(
    db: &Database,
    coach_id: ObjectId,
    user_id: ObjectId,
) -> Result<bool, AppError> {
    let link = links(db)
        .find_one(doc! { "coach_id": coach_id, "user_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?;
    Ok(link.is_some())
}

/// HU-24 — un cliente de la lista del coach con su meta vigente y su último registro de comida.
#[derive(Debug, Clone)]
pub struct ClientSummary {
    pub user: User,
    /// `None` si el cliente aún no tiene metas (sin perfil ni meta del coach).
    pub goal: Option<NutritionalGoal>,
    /// `None` si el cliente no tiene registros de comida.
    pub last_meal_at: Option<DateTime>,
}

/// Une cada cliente con su meta y su último registro, conservando el orden de `users`.
pub fn build_client_summaries(
    users: Vec<User>,
    mut goals: HashMap<ObjectId, NutritionalGoal>,
    last_meals: HashMap<ObjectId, DateTime>,
) -> Vec<ClientSummary> {
    users
        .into_iter()
        .map(|user| {
            let goal = user.id.and_then(|id| goals.remove(&id));
            let last_meal_at = user.id.and_then(|id| last_meals.get(&id).copied());
            ClientSummary {
                user,
                goal,
                last_meal_at,
            }
        })
        .collect()
}

/// Clientes con vinculación activa, ordenados por nombre, con su meta vigente y su último registro.
/// Son cuatro consultas en total, sin importar cuántos clientes tenga el coach (ninguna por cliente).
pub async fn list_clients(
    db: &Database,
    coach_id: ObjectId,
) -> Result<Vec<ClientSummary>, AppError> {
    let cursor = links(db)
        .find(doc! { "coach_id": coach_id, "status": "active" })
        .await
        .map_err(AppError::internal)?;
    let client_ids: Vec<ObjectId> = collect_cursor(cursor)
        .await?
        .into_iter()
        .map(|link| link.user_id)
        .collect();

    let cursor = db
        .collection::<User>(USERS_COLLECTION)
        .find(doc! { "_id": { "$in": client_ids.clone() } })
        .sort(doc! { "name": 1 })
        .await
        .map_err(AppError::internal)?;
    let users = collect_cursor(cursor).await?;

    let goals = goals::current_goals_for(db, &client_ids, DateTime::now()).await?;
    let last_meals = meals::last_meal_at_for(db, &client_ids).await?;
    Ok(build_client_summaries(users, goals, last_meals))
}

#[derive(Debug, Default)]
pub struct SeedLinkInput {
    pub coach_id: Option<String>,
    pub user_id: Option<String>,
}

/// Cuenta existente con el rol esperado, o un error en el campo.
async fn resolve_account(
    db: &Database,
    raw_id: Option<String>,
    role: Role,
    field: &str,
    errors: &mut FieldErrors,
) -> Result<Option<ObjectId>, AppError> {
    let message = match raw_id.as_deref().map(str::trim) {
        None | Some("") => format!("{field} es obligatorio"),
        Some(raw) => match ObjectId::parse_str(raw) {
            Err(_) => format!("{field} no es un id válido"),
            Ok(id) => match find_user_by_id(db, id).await? {
                Some(user) if user.role == role => return Ok(Some(id)),
                _ => format!("{field} no corresponde a una cuenta con ese rol"),
            },
        },
    };
    errors.insert(field.into(), message);
    Ok(None)
}

/// Crea (o reactiva) la vinculación activa entre un coach y un usuario existentes.
pub async fn seed_link(db: &Database, input: SeedLinkInput) -> Result<CoachLink, AppError> {
    let mut errors = FieldErrors::new();
    let coach_id =
        resolve_account(db, input.coach_id, Role::Coach, "coach_id", &mut errors).await?;
    let user_id = resolve_account(db, input.user_id, Role::User, "user_id", &mut errors).await?;
    let (Some(coach_id), Some(user_id)) = (coach_id, user_id) else {
        return Err(AppError::Validation(errors));
    };

    links(db)
        .find_one_and_update(
            doc! { "coach_id": coach_id, "user_id": user_id },
            doc! {
                "$set": { "status": "active" },
                "$setOnInsert": { "_id": ObjectId::new(), "created_at": DateTime::now() },
            },
        )
        .upsert(true)
        .return_document(ReturnDocument::After)
        .await
        .map_err(AppError::internal)?
        .ok_or_else(|| AppError::internal("la vinculación no se pudo crear"))
}

#[derive(Debug, Default)]
pub struct LinkCoachInput {
    pub invite_code: Option<String>,
}

/// Código obligatorio, sin espacios alrededor y en mayúsculas.
fn normalize_invite_code(raw: Option<String>) -> Result<String, AppError> {
    match raw.as_deref().map(str::trim) {
        None | Some("") => Err(AppError::Validation(FieldErrors::from([(
            "invite_code".to_string(),
            "invite_code es obligatorio".to_string(),
        )]))),
        Some(code) => Ok(code.to_uppercase()),
    }
}

/// Update que activa la vinculación: si ya existía (desvinculada) la reactiva y conserva
/// `created_at`; si no existe, la inserta con `_id` y `created_at`.
fn activation_update(now: DateTime) -> Document {
    doc! {
        "$set": { "status": "active", "updated_at": now },
        "$setOnInsert": { "_id": ObjectId::new(), "created_at": now },
    }
}

/// HU-13 — vincula al usuario con el coach dueño del código de invitación.
pub async fn link_with_invite_code(
    db: &Database,
    user_id: ObjectId,
    input: LinkCoachInput,
) -> Result<(CoachLink, User), AppError> {
    let code = normalize_invite_code(input.invite_code)?;

    let invite = db
        .collection::<CoachInviteCode>(COACH_INVITE_CODES_COLLECTION)
        .find_one(doc! { "code": &code })
        .await
        .map_err(AppError::internal)?
        .ok_or(AppError::InviteCodeNotFound)?;

    let coach = match find_user_by_id(db, invite.coach_id).await? {
        Some(user) if user.role == Role::Coach => user,
        _ => return Err(AppError::InviteCodeNotFound),
    };

    let already_linked = links(db)
        .find_one(doc! { "user_id": user_id, "status": "active" })
        .await
        .map_err(AppError::internal)?
        .is_some();
    if already_linked {
        return Err(AppError::UserAlreadyLinked);
    }

    let result = links(db)
        .find_one_and_update(
            doc! { "coach_id": coach.id, "user_id": user_id },
            activation_update(DateTime::now()),
        )
        .upsert(true)
        .return_document(ReturnDocument::After)
        .await;

    let link = match result {
        Ok(Some(link)) => link,
        Ok(None) => return Err(AppError::internal("la vinculación no se pudo crear")),
        // Otra petición vinculó a este usuario entre la verificación y el upsert.
        Err(e) if is_duplicate_key(&e) => return Err(AppError::UserAlreadyLinked),
        Err(e) => return Err(AppError::internal(e)),
    };

    Ok((link, coach))
}

/// HU-14 — desvincula al usuario de su coach activo.
pub async fn unlink_coach(db: &Database, user_id: ObjectId) -> Result<(), AppError> {
    let now = DateTime::now();
    let result = links(db)
        .find_one_and_update(
            doc! { "user_id": user_id, "status": "active" },
            doc! {
                "$set": { "status": "unlinked", "updated_at": now }
            },
        )
        .await
        .map_err(AppError::internal)?;

    if result.is_none() {
        return Err(AppError::UserNotLinked);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_missing_or_blank_invite_code() {
        for raw in [None, Some(String::new()), Some("   ".to_string())] {
            match normalize_invite_code(raw) {
                Err(AppError::Validation(fields)) => assert!(fields.contains_key("invite_code")),
                other => panic!("se esperaba Validation, se obtuvo {other:?}"),
            }
        }
    }

    #[test]
    fn trims_and_uppercases_invite_code() {
        assert_eq!(
            normalize_invite_code(Some("  ab3k9z ".to_string())).unwrap(),
            "AB3K9Z"
        );
    }

    #[test]
    fn reactivation_keeps_created_at_and_sets_status() {
        let update = activation_update(DateTime::now());
        let set = update.get_document("$set").unwrap();
        assert_eq!(set.get_str("status").unwrap(), "active");
        assert!(set.contains_key("updated_at"));
        assert!(!set.contains_key("created_at"));
    }

    #[test]
    fn creation_fields_are_only_set_on_insert() {
        let update = activation_update(DateTime::now());
        let on_insert = update.get_document("$setOnInsert").unwrap();
        assert!(on_insert.contains_key("_id"));
        assert!(on_insert.contains_key("created_at"));
        assert!(!on_insert.contains_key("status"));
        assert!(!on_insert.contains_key("updated_at"));
    }

    fn user(name: &str) -> User {
        User {
            id: Some(ObjectId::new()),
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

    fn goal_for(user_id: ObjectId) -> NutritionalGoal {
        NutritionalGoal {
            id: ObjectId::new(),
            user_id,
            calories: 2200,
            protein_g: 160,
            fat_g: 70,
            source: crate::models::goal::GoalSource::Coach,
            set_by: Some(ObjectId::new()),
            effective_from: DateTime::now(),
            created_at: DateTime::now(),
        }
    }

    #[test]
    fn la_lista_une_meta_y_ultimo_registro_de_cada_cliente() {
        let ana = user("Ana");
        let bruno = user("Bruno");
        let (ana_id, bruno_id) = (ana.id.unwrap(), bruno.id.unwrap());
        let at = DateTime::parse_rfc3339_str("2026-10-17T01:30:00Z").unwrap();

        let summaries = build_client_summaries(
            vec![ana, bruno],
            HashMap::from([(bruno_id, goal_for(bruno_id))]),
            HashMap::from([(ana_id, at)]),
        );

        assert_eq!(summaries.len(), 2);
        assert_eq!(summaries[0].user.id, Some(ana_id));
        assert!(summaries[0].goal.is_none());
        assert_eq!(summaries[0].last_meal_at, Some(at));
        assert_eq!(summaries[1].user.id, Some(bruno_id));
        assert_eq!(
            summaries[1].goal.as_ref().map(|goal| goal.user_id),
            Some(bruno_id)
        );
        assert_eq!(summaries[1].last_meal_at, None);
    }

    #[test]
    fn la_lista_conserva_el_orden_por_nombre_y_no_mezcla_datos_ajenos() {
        let names = ["Ana", "Bruno", "Carla"];
        let users: Vec<User> = names.iter().map(|name| user(name)).collect();
        let ajeno = ObjectId::new();

        let summaries = build_client_summaries(
            users,
            HashMap::from([(ajeno, goal_for(ajeno))]),
            HashMap::from([(ajeno, DateTime::now())]),
        );

        let order: Vec<&str> = summaries.iter().map(|s| s.user.name.as_str()).collect();
        assert_eq!(order, names);
        assert!(
            summaries
                .iter()
                .all(|s| s.goal.is_none() && s.last_meal_at.is_none())
        );
    }
}
