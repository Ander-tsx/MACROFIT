use mongodb::{
    Client, Cursor, Database, IndexModel,
    bson::{Document, doc},
    options::IndexOptions,
};
use serde::de::DeserializeOwned;

use std::time::Duration;

use crate::error::AppError;
use crate::models::coach_invite_code::{COACH_INVITE_CODES_COLLECTION, CoachInviteCode};
use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink};
use crate::models::goal::{GOALS_COLLECTION, NutritionalGoal};
use crate::models::meal_photo::{MEAL_PHOTOS_CHUNKS_COLLECTION, MEAL_PHOTOS_FILES_COLLECTION};
use crate::models::profile::{PROFILES_COLLECTION, UserProfile};
use crate::models::refresh_token::{REFRESH_TOKENS_COLLECTION, RefreshToken};
use crate::models::user::{USERS_COLLECTION, User};
use crate::models::weight_entry::{WEIGHTS_COLLECTION, WeightEntry};

/// Conecta con MongoDB, verifica la conexión con un `ping` y crea los índices.
pub async fn connect(mongo_uri: &str, db_name: &str) -> Database {
    let client = Client::with_uri_str(mongo_uri)
        .await
        .expect("Error al inicializar cliente de MongoDB");

    println!("Conectando y verificando cluster de MongoDB...");
    client
        .database("admin")
        .run_command(doc! { "ping": 1 })
        .await
        .expect("Error al conectar con MongoDB. Revisa MONGO_URI y que tu IP esté permitida en Network Access de Atlas.");
    println!("¡Ping exitoso! Conexión establecida correctamente con MongoDB.");

    let db = client.database(db_name);
    ensure_indexes(&db).await;
    db
}

/// Lee un cursor completo en un `Vec`.
pub async fn collect_cursor<T: DeserializeOwned>(
    mut cursor: Cursor<T>,
) -> Result<Vec<T>, AppError> {
    let mut items = Vec::new();
    while cursor.advance().await.map_err(AppError::internal)? {
        items.push(cursor.deserialize_current().map_err(AppError::internal)?);
    }
    Ok(items)
}

/// Crea los índices de todas las colecciones. `create_index` es idempotente.
async fn ensure_indexes(db: &Database) {
    let email_unique = IndexModel::builder()
        .keys(doc! { "email": 1 })
        .options(
            IndexOptions::builder()
                .unique(true)
                .name("email_unique".to_string())
                .build(),
        )
        .build();

    db.collection::<User>(USERS_COLLECTION)
        .create_index(email_unique)
        .await
        .expect("No se pudo crear el índice único de users.email (¿hay correos duplicados en la colección?)");

    let refresh_tokens = db.collection::<RefreshToken>(REFRESH_TOKENS_COLLECTION);
    let refresh_indexes = [
        IndexModel::builder()
            .keys(doc! { "token_hash": 1 })
            .options(
                IndexOptions::builder()
                    .unique(true)
                    .name("token_hash_unique".to_string())
                    .build(),
            )
            .build(),
        IndexModel::builder()
            .keys(doc! { "session_id": 1 })
            .options(
                IndexOptions::builder()
                    .name("session_id".to_string())
                    .build(),
            )
            .build(),
        // TTL: Mongo elimina los refresh tokens cuando pasa su expires_at.
        IndexModel::builder()
            .keys(doc! { "expires_at": 1 })
            .options(
                IndexOptions::builder()
                    .expire_after(Duration::ZERO)
                    .name("expires_at_ttl".to_string())
                    .build(),
            )
            .build(),
    ];
    refresh_tokens
        .create_indexes(refresh_indexes)
        .await
        .expect("No se pudieron crear los índices de refresh_tokens");

    // Historial de metas: la más reciente primero por usuario.
    let goals_by_user = IndexModel::builder()
        .keys(doc! { "user_id": 1, "effective_from": -1 })
        .options(
            IndexOptions::builder()
                .name("user_id_effective_from".to_string())
                .build(),
        )
        .build();
    db.collection::<NutritionalGoal>(GOALS_COLLECTION)
        .create_index(goals_by_user)
        .await
        .expect("No se pudo crear el índice de goals");

    // HU-03: un solo perfil por usuario.
    let profile_user_unique = IndexModel::builder()
        .keys(doc! { "user_id": 1 })
        .options(
            IndexOptions::builder()
                .unique(true)
                .name("user_id_unique".to_string())
                .build(),
        )
        .build();
    db.collection::<UserProfile>(PROFILES_COLLECTION)
        .create_index(profile_user_unique)
        .await
        .expect("No se pudo crear el índice único de profiles.user_id (¿hay perfiles duplicados?)");

    // HU-05: una sola vinculación por par coach-cliente.
    let link_pair_unique = IndexModel::builder()
        .keys(doc! { "coach_id": 1, "user_id": 1 })
        .options(
            IndexOptions::builder()
                .unique(true)
                .name("coach_id_user_id_unique".to_string())
                .build(),
        )
        .build();
    db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
        .create_index(link_pair_unique)
        .await
        .expect("No se pudo crear el índice único de coach_links");

    // TEC-13: bucket de GridFS de las fotos de comidas. Los dos primeros son los índices estándar de GridFS
    // (mismas claves y nombre automático que crearía el driver en la primera subida, así que no chocan);
    // el de `chunks` es único como pide la especificación de GridFS.
    let photo_files = db.collection::<Document>(MEAL_PHOTOS_FILES_COLLECTION);
    let photo_files_indexes = [
        IndexModel::builder()
            .keys(doc! { "filename": 1, "uploadDate": 1 })
            .build(),
        // Fotos de un usuario (p. ej. para borrar todas las de una cuenta).
        IndexModel::builder()
            .keys(doc! { "metadata.owner_id": 1 })
            .options(
                IndexOptions::builder()
                    .name("metadata_owner_id".to_string())
                    .build(),
            )
            .build(),
    ];
    photo_files
        .create_indexes(photo_files_indexes)
        .await
        .expect("No se pudieron crear los índices de meal_photos.files");

    let photo_chunks_unique = IndexModel::builder()
        .keys(doc! { "files_id": 1, "n": 1 })
        .options(IndexOptions::builder().unique(true).build())
        .build();
    db.collection::<Document>(MEAL_PHOTOS_CHUNKS_COLLECTION)
        .create_index(photo_chunks_unique)
        .await
        .expect("No se pudo crear el índice único de meal_photos.chunks");

    let invite_codes = db.collection::<CoachInviteCode>(COACH_INVITE_CODES_COLLECTION);
    let invite_code_indexes = [
        IndexModel::builder()
            .keys(doc! { "coach_id": 1 })
            .options(
                IndexOptions::builder()
                    .unique(true)
                    .name("coach_id_unique".to_string())
                    .build(),
            )
            .build(),
        IndexModel::builder()
            .keys(doc! { "code": 1 })
            .options(
                IndexOptions::builder()
                    .unique(true)
                    .name("code_unique".to_string())
                    .build(),
            )
            .build(),
    ];
    invite_codes
        .create_indexes(invite_code_indexes)
        .await
        .expect("No se pudieron crear los índices de coach_invite_codes");

    // HU-21: historial de peso por usuario, el más reciente primero.
    let weights_by_user = IndexModel::builder()
        .keys(doc! { "user_id": 1, "recorded_at": -1 })
        .options(
            IndexOptions::builder()
                .name("user_id_recorded_at".to_string())
                .build(),
        )
        .build();
    db.collection::<WeightEntry>(WEIGHTS_COLLECTION)
        .create_index(weights_by_user)
        .await
        .expect("No se pudo crear el índice de weights");
}
