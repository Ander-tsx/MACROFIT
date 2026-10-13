use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
    error::{ErrorKind, WriteFailure},
    options::ReturnDocument,
};
use rand::Rng;

use crate::error::AppError;
use crate::models::coach_invite_code::{COACH_INVITE_CODES_COLLECTION, CoachInviteCode};

const CODE_LENGTH: usize = 6;
const MAX_ATTEMPTS: usize = 5;
const MONGO_DUPLICATE_KEY: i32 = 11000;
const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

fn codes(db: &Database) -> Collection<CoachInviteCode> {
    db.collection(COACH_INVITE_CODES_COLLECTION)
}

/// Código aleatorio de 6 caracteres alfanuméricos en mayúsculas (A-Z0-9).
pub fn generate_code() -> String {
    let mut rng = rand::thread_rng();
    (0..CODE_LENGTH)
        .map(|_| CHARSET[rng.gen_range(0..CHARSET.len())] as char)
        .collect()
}

/// `true` si el error es de clave duplicada (11000), venga de un write o de un command.
fn is_duplicate_key(e: &mongodb::error::Error) -> bool {
    match &*e.kind {
        ErrorKind::Write(WriteFailure::WriteError(we)) => we.code == MONGO_DUPLICATE_KEY,
        ErrorKind::Command(ce) => ce.code == MONGO_DUPLICATE_KEY,
        _ => false,
    }
}

async fn find_by_coach(
    db: &Database,
    coach_id: ObjectId,
) -> Result<Option<CoachInviteCode>, AppError> {
    codes(db)
        .find_one(doc! { "coach_id": coach_id })
        .await
        .map_err(AppError::internal)
}

/// Código de invitación del coach; lo crea si no existe.
/// Reintenta hasta 5 veces ante colisión de `code_unique`.
pub async fn get_or_create_invite_code(
    db: &Database,
    coach_id: ObjectId,
) -> Result<CoachInviteCode, AppError> {
    if let Some(existing) = find_by_coach(db, coach_id).await? {
        return Ok(existing);
    }

    for _ in 0..MAX_ATTEMPTS {
        let now = DateTime::now();
        let new_code = CoachInviteCode {
            id: ObjectId::new(),
            coach_id,
            code: generate_code(),
            created_at: now,
            updated_at: now,
        };

        match codes(db).insert_one(&new_code).await {
            Ok(_) => return Ok(new_code),
            Err(e) if is_duplicate_key(&e) => {
                // Carrera por coach_id (otro request ya lo creó) o colisión de código.
                if let Some(existing) = find_by_coach(db, coach_id).await? {
                    return Ok(existing);
                }
            }
            Err(e) => return Err(AppError::internal(e)),
        }
    }

    Err(AppError::internal(
        "no se pudo generar un código de invitación único",
    ))
}

/// Genera un código distinto al actual y hace upsert del documento del coach.
/// Reintenta si choca con el código de otro coach.
pub async fn regenerate_invite_code(
    db: &Database,
    coach_id: ObjectId,
) -> Result<CoachInviteCode, AppError> {
    let current = find_by_coach(db, coach_id).await?.map(|c| c.code);

    for _ in 0..MAX_ATTEMPTS {
        let new_code = generate_code();
        if current.as_deref() == Some(new_code.as_str()) {
            continue;
        }

        let now = DateTime::now();
        let result = codes(db)
            .find_one_and_update(
                doc! { "coach_id": coach_id },
                doc! {
                    "$set": { "code": &new_code, "updated_at": now },
                    "$setOnInsert": { "_id": ObjectId::new(), "created_at": now },
                },
            )
            .upsert(true)
            .return_document(ReturnDocument::After)
            .await;

        match result {
            Ok(Some(updated)) => return Ok(updated),
            Ok(None) => {}
            Err(e) if is_duplicate_key(&e) => {} // colisión de code_unique: reintentar
            Err(e) => return Err(AppError::internal(e)),
        }
    }

    Err(AppError::internal(
        "no se pudo regenerar el código de invitación",
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn generate_code_has_six_uppercase_alphanumeric_chars() {
        for _ in 0..1000 {
            let code = generate_code();
            assert_eq!(code.len(), 6);
            assert!(
                code.chars()
                    .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit())
            );
        }
    }

    #[test]
    fn generate_code_is_random() {
        let codes: HashSet<String> = (0..100).map(|_| generate_code()).collect();
        // Con 36^6 combinaciones, 100 códigos deben ser prácticamente todos distintos.
        assert!(codes.len() >= 95);
    }
}
