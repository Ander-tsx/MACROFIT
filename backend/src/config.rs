/// Configuración leída de variables de entorno (ver `.env.example`).
#[derive(Debug, Clone)]
pub struct Config {
    pub mongo_uri: String,
    pub db_name: String,
    pub port: u16,
    pub tokens: TokenConfig,
}

/// Parámetros de los tokens de sesión.
#[derive(Debug, Clone)]
pub struct TokenConfig {
    pub jwt_secret: String,
    /// Duración del access token (JWT). Por defecto 15 minutos.
    pub access_ttl: chrono::Duration,
    /// Duración del refresh token; se renueva con cada rotación. Por defecto 30 días.
    pub refresh_ttl: chrono::Duration,
}

impl Config {
    /// Carga la configuración y detiene el arranque si falta una variable obligatoria.
    pub fn from_env() -> Self {
        Self {
            mongo_uri: required("MONGO_URI"),
            db_name: required("DB_NAME"),
            port: optional("PORT", 3000),
            tokens: TokenConfig {
                jwt_secret: required("JWT_SECRET"),
                access_ttl: chrono::Duration::minutes(optional("ACCESS_TOKEN_MINUTES", 15)),
                refresh_ttl: chrono::Duration::days(optional("REFRESH_TOKEN_DAYS", 30)),
            },
        }
    }
}

fn required(key: &str) -> String {
    std::env::var(key).unwrap_or_else(|_| panic!("{key} no configurada"))
}

fn optional<T: std::str::FromStr>(key: &str, default: T) -> T {
    match std::env::var(key) {
        Ok(value) => value
            .parse()
            .unwrap_or_else(|_| panic!("{key} tiene un valor inválido: {value}")),
        Err(_) => default,
    }
}
