use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
};
use mongodb::bson::doc;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::AppState;
use crate::auth::jwt::generate_jwt;
use crate::auth::middleware::{AuthenticatedUser, CoachOnly};
use crate::models::user::{hash_password, verify_password, Role, User};

fn default_role() -> Role {
    Role::User
}

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub name: String,
    #[serde(default = "default_role")]
    pub role: Role,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user_id: String,
    pub email: String,
    pub name: String,
    pub role: Role,
}

pub async fn register_handler(
    State(state): State<AppState>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), (StatusCode, Json<Value>)> {
    let collection = state.db.collection::<User>("users");

    // Verificar si el correo ya existe
    let existing = collection
        .find_one(doc! { "email": &payload.email })
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    if existing.is_some() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({ "error": "El correo electrónico ya está registrado" })),
        ));
    }

    // Hashear contraseña con bcrypt
    let password_hash = hash_password(&payload.password)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    let new_user = User {
        id: None,
        email: payload.email.clone(),
        password_hash,
        name: payload.name.clone(),
        role: payload.role.clone(),
    };

    let insert_result = collection
        .insert_one(&new_user)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    let user_id = insert_result
        .inserted_id
        .as_object_id()
        .map(|oid| oid.to_hex())
        .unwrap_or_default();

    let role_str = match &payload.role {
        Role::User => "User",
        Role::Coach => "Coach",
    };

    let token = generate_jwt(&user_id, role_str)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    Ok((
        StatusCode::CREATED,
        Json(AuthResponse {
            token,
            user_id,
            email: payload.email,
            name: payload.name,
            role: payload.role,
        }),
    ))
}

pub async fn login_handler(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), (StatusCode, Json<Value>)> {
    let collection = state.db.collection::<User>("users");

    let user = collection
        .find_one(doc! { "email": &payload.email })
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    let user = match user {
        Some(u) => u,
        None => {
            return Err((
                StatusCode::UNAUTHORIZED,
                Json(json!({ "error": "Credenciales inválidas" })),
            ));
        }
    };

    let is_valid = verify_password(&payload.password, &user.password_hash)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    if !is_valid {
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(json!({ "error": "Credenciales inválidas" })),
        ));
    }

    let user_id = user.id.map(|oid| oid.to_hex()).unwrap_or_default();
    let role_str = match &user.role {
        Role::User => "User",
        Role::Coach => "Coach",
    };

    let token = generate_jwt(&user_id, role_str)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({ "error": e.to_string() }))))?;

    Ok((
        StatusCode::OK,
        Json(AuthResponse {
            token,
            user_id,
            email: user.email,
            name: user.name,
            role: user.role,
        }),
    ))
}

pub async fn me_handler(auth_user: AuthenticatedUser) -> Json<Value> {
    Json(json!({
        "user_id": auth_user.user_id,
        "role": auth_user.role,
        "message": "Usuario autenticado con éxito"
    }))
}

pub async fn coach_only_handler(CoachOnly(auth_user): CoachOnly) -> Json<Value> {
    Json(json!({
        "user_id": auth_user.user_id,
        "role": auth_user.role,
        "message": "Acceso permitido: eres Coach"
    }))
}

