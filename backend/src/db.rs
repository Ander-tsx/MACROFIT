use mongodb::{Client, Database, IndexModel, bson::doc, options::IndexOptions};

use std::time::Duration;

use crate::models::goal::{GOALS_COLLECTION, NutritionalGoal};
use crate::models::profile::{PROFILES_COLLECTION, UserProfile};
use crate::models::refresh_token::{REFRESH_TOKENS_COLLECTION, RefreshToken};
use crate::models::user::{USERS_COLLECTION, User};

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

    // Un solo perfil por usuario.
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
        .expect("No se pudo crear el índice único de profiles.user_id");
}
