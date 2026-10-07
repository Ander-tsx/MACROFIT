use std::net::SocketAddr;

use tower_http::cors::CorsLayer;

mod auth;
mod config;
mod db;
mod error;
mod models;
mod routes;
mod services;
mod state;
mod validation;

use config::Config;
use state::AppState;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let config = Config::from_env();

    let db = db::connect(&config.mongo_uri, &config.db_name).await;
    let state = AppState {
        db,
        tokens: config.tokens,
    };

    let app = routes::api_router()
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    println!(
        "Servidor MacroFit corriendo en http://{addr}{}",
        routes::API_PREFIX
    );

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .unwrap_or_else(|e| panic!("Error al vincular el puerto {}: {e}", config.port));
    axum::serve(listener, app).await.unwrap();
}
