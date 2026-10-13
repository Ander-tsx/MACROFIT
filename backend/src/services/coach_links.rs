//! HU-05 — vinculaciones coach-cliente. El alta real llega con HU-13; mientras tanto
//! `seed_link` crea vinculaciones de prueba (solo en desarrollo).

use mongodb::{
    Collection, Database,
    bson::{DateTime, Document, doc, oid::ObjectId},
    options::ReturnDocument,
};

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::coach_invite_code::{COACH_INVITE_CODES_COLLECTION, CoachInviteCode};
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::user::{Role, USERS_COLLECTION, User};
use crate::services::auth::find_user_by_id;
use crate::services::coach_invite_codes::is_duplicate_key;

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

/// Clientes con vinculación activa, ordenados por nombre.
pub async fn list_clients(db: &Database, coach_id: ObjectId) -> Result<Vec<User>, AppError> {
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
        .find(doc! { "_id": { "$in": client_ids } })
        .sort(doc! { "name": 1 })
        .await
        .map_err(AppError::internal)?;
    collect_cursor(cursor).await
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
}
