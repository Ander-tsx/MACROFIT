//! HU-05 — vinculaciones coach-cliente. El alta real llega con HU-13; mientras tanto
//! `seed_link` crea vinculaciones de prueba (solo en desarrollo).

use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
    options::ReturnDocument,
};

use crate::db::collect_cursor;
use crate::error::{AppError, FieldErrors};
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::user::{Role, USERS_COLLECTION, User};
use crate::services::auth::find_user_by_id;

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
