/// Configuración leída de variables de entorno (ver `.env.example`).
#[derive(Debug, Clone)]
pub struct Config {
    pub mongo_uri: String,
    pub db_name: String,
    pub port: u16,
    /// `APP_ENV=development`: habilita las rutas de datos de prueba (`/dev`).
    pub dev_mode: bool,
    pub tokens: TokenConfig,
    /// Proveedor de reconocimiento de alimentos (HU-07; elegido en TEC-02).
    pub food: FoodConfig,
    /// Zona horaria fija con la que se define el día de un registro de comida (HU-09). Por defecto `-06:00` (México).
    pub utc_offset: chrono::FixedOffset,
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
            dev_mode: optional("APP_ENV", String::new()) == "development",
            tokens: TokenConfig {
                jwt_secret: required("JWT_SECRET"),
                access_ttl: chrono::Duration::minutes(optional("ACCESS_TOKEN_MINUTES", 15)),
                refresh_ttl: chrono::Duration::days(optional("REFRESH_TOKEN_DAYS", 30)),
            },
            food: FoodConfig::from_env().unwrap_or_else(|err| panic!("{err}")),
            utc_offset: match std::env::var("APP_UTC_OFFSET") {
                Ok(value) => parse_utc_offset(&value).unwrap_or_else(|| {
                    panic!("APP_UTC_OFFSET tiene un valor inválido: {value} (formato ±HH:MM, p. ej. -06:00)")
                }),
                Err(_) => default_utc_offset(),
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

// ───────────────────────── Zona horaria de los registros (HU-09) ─────────────────────────

/// Desfase por defecto: hora del centro de México (UTC−6, sin horario de verano desde 2022).
pub const DEFAULT_UTC_OFFSET_SECS: i32 = -6 * 3600;

pub fn default_utc_offset() -> chrono::FixedOffset {
    chrono::FixedOffset::east_opt(DEFAULT_UTC_OFFSET_SECS).expect("desfase por defecto válido")
}

/// Lee un desfase `±HH:MM` (de `-12:00` a `+14:00`). `None` si el formato o el valor no son válidos.
pub fn parse_utc_offset(value: &str) -> Option<chrono::FixedOffset> {
    let value = value.trim();
    let (sign, rest) = match value.as_bytes().first()? {
        b'+' => (1, &value[1..]),
        b'-' => (-1, &value[1..]),
        _ => return None,
    };
    let (hours, minutes) = rest.split_once(':')?;
    if hours.len() != 2 || minutes.len() != 2 {
        return None;
    }
    let hours: i32 = hours.parse().ok()?;
    let minutes: i32 = minutes.parse().ok()?;
    if minutes >= 60 {
        return None;
    }
    let secs = sign * (hours * 3600 + minutes * 60);
    if !(-12 * 3600..=14 * 3600).contains(&secs) {
        return None;
    }
    chrono::FixedOffset::east_opt(secs)
}

// ───────────────────────── Reconocimiento de alimentos (HU-07, TEC-02) ─────────────────────────

/// Tiempo de espera máximo permitido con el proveedor (RNF-01: la estimación no tarda más de 10 s).
pub const MAX_FOOD_TIMEOUT_SECS: u64 = 10;

/// Texto secreto (llave o token). Su `Debug` no muestra el valor, así no aparece en logs ni en `{config:?}`.
#[derive(Clone, PartialEq, Eq)]
pub struct Secret(String);

impl Secret {
    pub fn expose(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Debug for Secret {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Secret(***)")
    }
}

/// Proveedor de reconocimiento de alimentos (`FOOD_PROVIDER`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FoodProviderKind {
    /// Respuestas fijas, sin red. Es el valor por defecto (desarrollo, pruebas y Postman).
    Simulator,
    LogMeal,
    Gemini,
    /// Gemini identifica los alimentos y sus gramos; FatSecret pone los valores nutricionales.
    GeminiFatSecret,
}

impl FoodProviderKind {
    pub fn parse(value: &str) -> Option<Self> {
        match value.trim() {
            "simulator" => Some(Self::Simulator),
            "logmeal" => Some(Self::LogMeal),
            "gemini" => Some(Self::Gemini),
            "gemini_fatsecret" => Some(Self::GeminiFatSecret),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Simulator => "simulator",
            Self::LogMeal => "logmeal",
            Self::Gemini => "gemini",
            Self::GeminiFatSecret => "gemini_fatsecret",
        }
    }
}

/// Respuesta que da el simulador (`FOOD_SIMULATOR_MODE`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SimulatorMode {
    Ok,
    NotRecognized,
    Error,
    Timeout,
}

impl SimulatorMode {
    pub fn parse(value: &str) -> Option<Self> {
        match value.trim() {
            "ok" => Some(Self::Ok),
            "not_recognized" => Some(Self::NotRecognized),
            "error" => Some(Self::Error),
            "timeout" => Some(Self::Timeout),
            _ => None,
        }
    }
}

/// Modelo de Gemini por defecto (`GEMINI_MODEL`).
pub const DEFAULT_GEMINI_MODEL: &str = "gemini-2.5-flash";

/// Configuración del proveedor de reconocimiento de alimentos. Solo se exigen las credenciales del proveedor elegido.
#[derive(Debug, Clone)]
pub struct FoodConfig {
    pub provider: FoodProviderKind,
    pub timeout: std::time::Duration,
    pub simulator_mode: SimulatorMode,
    pub logmeal_token: Option<Secret>,
    pub gemini_api_key: Option<Secret>,
    pub gemini_model: String,
    pub fatsecret_client_id: Option<Secret>,
    pub fatsecret_client_secret: Option<Secret>,
}

impl FoodConfig {
    /// Lee `FOOD_*`, `LOGMEAL_*`, `GEMINI_*` y `FATSECRET_*` del entorno.
    pub fn from_env() -> Result<Self, String> {
        Self::from_vars(|key| std::env::var(key).ok())
    }

    /// Igual que [`Self::from_env`] pero forzando el proveedor (lo usa el banco de pruebas de TEC-02).
    pub fn from_env_with_provider(provider: FoodProviderKind) -> Result<Self, String> {
        Self::from_vars(|key| {
            if key == "FOOD_PROVIDER" {
                Some(provider.as_str().to_string())
            } else {
                std::env::var(key).ok()
            }
        })
    }

    /// Construye la configuración a partir de una función de búsqueda (probada sin tocar el entorno real).
    pub fn from_vars(get: impl Fn(&str) -> Option<String>) -> Result<Self, String> {
        let value = |key: &str| {
            get(key)
                .map(|v| v.trim().to_string())
                .filter(|v| !v.is_empty())
        };
        let secret = |key: &str| value(key).map(Secret);

        let provider = match value("FOOD_PROVIDER") {
            None => FoodProviderKind::Simulator,
            Some(v) => FoodProviderKind::parse(&v).ok_or_else(|| {
                format!(
                    "FOOD_PROVIDER tiene un valor inválido: {v} (simulator, logmeal, gemini o gemini_fatsecret)"
                )
            })?,
        };
        let timeout_secs = match value("FOOD_PROVIDER_TIMEOUT_SECS") {
            None => MAX_FOOD_TIMEOUT_SECS,
            Some(v) => v
                .parse::<u64>()
                .ok()
                .filter(|secs| (1..=MAX_FOOD_TIMEOUT_SECS).contains(secs))
                .ok_or_else(|| {
                    format!(
                        "FOOD_PROVIDER_TIMEOUT_SECS debe ser un entero de 1 a {MAX_FOOD_TIMEOUT_SECS}: {v}"
                    )
                })?,
        };
        let simulator_mode = match value("FOOD_SIMULATOR_MODE") {
            None => SimulatorMode::Ok,
            Some(v) => SimulatorMode::parse(&v).ok_or_else(|| {
                format!(
                    "FOOD_SIMULATOR_MODE tiene un valor inválido: {v} (ok, not_recognized, error o timeout)"
                )
            })?,
        };

        let config = Self {
            provider,
            timeout: std::time::Duration::from_secs(timeout_secs),
            simulator_mode,
            logmeal_token: secret("LOGMEAL_API_TOKEN"),
            gemini_api_key: secret("GEMINI_API_KEY"),
            gemini_model: value("GEMINI_MODEL").unwrap_or_else(|| DEFAULT_GEMINI_MODEL.to_string()),
            fatsecret_client_id: secret("FATSECRET_CLIENT_ID"),
            fatsecret_client_secret: secret("FATSECRET_CLIENT_SECRET"),
        };

        let required: &[(&str, bool)] = match provider {
            FoodProviderKind::Simulator => &[],
            FoodProviderKind::LogMeal => &[("LOGMEAL_API_TOKEN", config.logmeal_token.is_some())],
            FoodProviderKind::Gemini => &[("GEMINI_API_KEY", config.gemini_api_key.is_some())],
            FoodProviderKind::GeminiFatSecret => &[
                ("GEMINI_API_KEY", config.gemini_api_key.is_some()),
                ("FATSECRET_CLIENT_ID", config.fatsecret_client_id.is_some()),
                (
                    "FATSECRET_CLIENT_SECRET",
                    config.fatsecret_client_secret.is_some(),
                ),
            ],
        };
        let missing: Vec<&str> = required
            .iter()
            .filter(|(_, present)| !present)
            .map(|(key, _)| *key)
            .collect();
        if !missing.is_empty() {
            return Err(format!(
                "FOOD_PROVIDER={} requiere {} en el entorno (.env)",
                provider.as_str(),
                missing.join(", ")
            ));
        }
        Ok(config)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn food(vars: &[(&str, &str)]) -> Result<FoodConfig, String> {
        let map: HashMap<String, String> = vars
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect();
        FoodConfig::from_vars(|key| map.get(key).cloned())
    }

    #[test]
    fn desfase_utc_valido_se_acepta() {
        assert_eq!(
            parse_utc_offset("-06:00").unwrap().local_minus_utc(),
            -6 * 3600
        );
        assert_eq!(
            parse_utc_offset(" +05:30 ").unwrap().local_minus_utc(),
            5 * 3600 + 1800
        );
        assert_eq!(parse_utc_offset("+00:00").unwrap().local_minus_utc(), 0);
        assert_eq!(
            default_utc_offset().local_minus_utc(),
            DEFAULT_UTC_OFFSET_SECS
        );
    }

    #[test]
    fn desfase_utc_invalido_se_rechaza() {
        for value in [
            "", "06:00", "-6:00", "-06", "-06:60", "+15:00", "-13:00", "UTC", "-0a:00",
        ] {
            assert!(
                parse_utc_offset(value).is_none(),
                "{value} debería ser inválido"
            );
        }
    }

    #[test]
    fn sin_variables_usa_el_simulador_con_10_segundos() {
        let config = food(&[]).unwrap();
        assert_eq!(config.provider, FoodProviderKind::Simulator);
        assert_eq!(config.timeout.as_secs(), 10);
        assert_eq!(config.simulator_mode, SimulatorMode::Ok);
        assert_eq!(config.gemini_model, DEFAULT_GEMINI_MODEL);
    }

    #[test]
    fn proveedor_invalido_se_rechaza() {
        assert!(food(&[("FOOD_PROVIDER", "clarifai")]).is_err());
    }

    #[test]
    fn el_tiempo_de_espera_no_pasa_de_10_segundos() {
        assert!(food(&[("FOOD_PROVIDER_TIMEOUT_SECS", "11")]).is_err());
        assert!(food(&[("FOOD_PROVIDER_TIMEOUT_SECS", "0")]).is_err());
        assert!(food(&[("FOOD_PROVIDER_TIMEOUT_SECS", "abc")]).is_err());
        let config = food(&[("FOOD_PROVIDER_TIMEOUT_SECS", "8")]).unwrap();
        assert_eq!(config.timeout.as_secs(), 8);
    }

    #[test]
    fn cada_proveedor_exige_solo_sus_credenciales() {
        let err = food(&[("FOOD_PROVIDER", "logmeal")]).unwrap_err();
        assert!(err.contains("LOGMEAL_API_TOKEN"));
        assert!(food(&[("FOOD_PROVIDER", "logmeal"), ("LOGMEAL_API_TOKEN", "t")]).is_ok());

        let err = food(&[
            ("FOOD_PROVIDER", "gemini_fatsecret"),
            ("GEMINI_API_KEY", "k"),
        ])
        .unwrap_err();
        assert!(err.contains("FATSECRET_CLIENT_ID") && err.contains("FATSECRET_CLIENT_SECRET"));
        assert!(!err.contains("GEMINI_API_KEY"));
    }

    #[test]
    fn variables_vacias_cuentan_como_ausentes() {
        assert!(food(&[("FOOD_PROVIDER", "gemini"), ("GEMINI_API_KEY", "  ")]).is_err());
    }

    #[test]
    fn los_secretos_no_aparecen_en_debug() {
        let config = food(&[
            ("FOOD_PROVIDER", "gemini"),
            ("GEMINI_API_KEY", "llave-super-secreta"),
        ])
        .unwrap();
        let debug = format!("{config:?}");
        assert!(!debug.contains("llave-super-secreta"));
        assert_eq!(
            config.gemini_api_key.unwrap().expose(),
            "llave-super-secreta"
        );
    }
}
