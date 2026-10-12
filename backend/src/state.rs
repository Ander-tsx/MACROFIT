use mongodb::Database;

use crate::config::TokenConfig;

/// Estado compartido por todos los handlers.
#[derive(Clone)]
pub struct AppState {
    pub db: Database,
    pub tokens: TokenConfig,
}
