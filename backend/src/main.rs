use std::net::SocketAddr;

use tower_http::cors::CorsLayer;

use backend::config::Config;
use backend::db;
use backend::routes;
use backend::services;
use backend::services::food_recognition::FoodService;
use backend::state::AppState;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let config = Config::from_env();
    // Falla al arrancar (y no en la primera petición) si el aviso no declara su versión.
    println!(
        "Aviso de privacidad vigente: versión {}",
        *services::legal::PRIVACY_VERSION
    );

    let food = FoodService::from_config(&config.food);
    println!(
        "Reconocimiento de alimentos: {} (tiempo de espera {} s)",
        food.provider_name(),
        config.food.timeout.as_secs()
    );

    let db = db::connect(&config.mongo_uri, &config.db_name).await;
    let state = AppState {
        db,
        tokens: config.tokens,
        food,
    };

    let app = routes::api_router(config.dev_mode)
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
