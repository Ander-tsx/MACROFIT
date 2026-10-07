use axum::{
    routing::{get, post},
    Router,
};
use mongodb::{Client, Database};
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;

pub mod auth;
pub mod models;
pub mod routes;

use routes::auth::{coach_only_handler, login_handler, me_handler, register_handler};

#[derive(Clone)]
pub struct AppState {
    pub db: Database,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let mongo_uri = std::env::var("MONGO_URI").expect("MONGO_URI no configurada");
    let db_name = std::env::var("DB_NAME").expect("DB_NAME no configurada");
    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse()
        .unwrap_or(3000);

    // Conexión a MongoDB
    let client = Client::with_uri_str(&mongo_uri)
        .await
        .expect("Error al inicializar cliente de MongoDB");

    println!("Conectando y verificando cluster de MongoDB...");
    client
        .database("admin")
        .run_command(mongodb::bson::doc! { "ping": 1 })
        .await
        .expect("Error al conectar con el cluster de MongoDB Atlas. Revisa tu contraseña y que tu IP esté permitida en Network Access en MongoDB Atlas (0.0.0.0/0).");
    println!("¡Ping exitoso! Conexión establecida correctamente con MongoDB.");

    let db = client.database(&db_name);

    let state = AppState { db };

    // Configuración de rutas
    let app = Router::new()
        // Rutas de verificación
        .route("/health", get(|| async { "API MacroFit OK" }))
        // Rutas de autenticación
        .route("/auth/register", post(register_handler))
        .route("/auth/login", post(login_handler))
        .route("/auth/me", get(me_handler))
        // Reglas de acceso por rol (solo Coaches)
        .route("/coach/test", get(coach_only_handler))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("Servidor MacroFit corriendo en http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .unwrap_or_else(|e| panic!("Error al vincular el puerto {}: {}", port, e));
    axum::serve(listener, app).await.unwrap();
}