//! Reglas de validación reutilizables. Funciones puras: sin base de datos ni HTTP.

use chrono::{NaiveDate, NaiveTime};
use mongodb::bson::DateTime;

use crate::error::FieldErrors;

pub const PASSWORD_MIN_CHARS: usize = 8;
pub const PASSWORD_MAX_CHARS: usize = 128;
pub const NAME_MAX_CHARS: usize = 100;
pub const EMAIL_MAX_CHARS: usize = 254;

/// Normaliza un correo para guardarlo y compararlo: sin espacios alrededor y en minúsculas.
pub fn normalize_email(email: &str) -> String {
    email.trim().to_lowercase()
}

/// Validación de formato práctica (no RFC 5322 completa): `local@dominio.tld`,
/// sin espacios, con un solo `@` y un dominio con al menos un punto.
pub fn is_valid_email(email: &str) -> bool {
    if email.is_empty() || email.chars().count() > EMAIL_MAX_CHARS {
        return false;
    }
    if email.chars().any(char::is_whitespace) {
        return false;
    }
    let mut parts = email.split('@');
    let (Some(local), Some(domain), None) = (parts.next(), parts.next(), parts.next()) else {
        return false;
    };
    if local.is_empty() || domain.starts_with('-') || domain.ends_with('-') {
        return false;
    }
    let labels: Vec<&str> = domain.split('.').collect();
    labels.len() >= 2 && labels.iter().all(|label| !label.is_empty())
}

/// Formato de las fechas de la API: `YYYY-MM-DD`.
pub const DATE_FORMAT: &str = "%Y-%m-%d";

/// Fecha `YYYY-MM-DD` estricta (con ceros a la izquierda).
pub fn parse_date(value: &str) -> Option<NaiveDate> {
    (value.len() == 10)
        .then(|| NaiveDate::parse_from_str(value, DATE_FORMAT).ok())
        .flatten()
}

/// Fecha → `DateTime` de BSON a medianoche UTC.
pub fn date_to_bson(date: NaiveDate) -> DateTime {
    DateTime::from_millis(date.and_time(NaiveTime::MIN).and_utc().timestamp_millis())
}

/// `DateTime` de BSON → texto `YYYY-MM-DD` (fecha UTC).
pub fn date_to_string(date: DateTime) -> String {
    chrono::DateTime::from_timestamp_millis(date.timestamp_millis())
        .map(|value| value.date_naive().format(DATE_FORMAT).to_string())
        .unwrap_or_default()
}

/// Valida un campo según si es obligatorio (alta) u opcional (edición) y acumula su error.
pub fn check<R, T>(
    errors: &mut FieldErrors,
    field: &str,
    value: Option<R>,
    required: bool,
    missing: &str,
    rule: impl FnOnce(R) -> Result<T, String>,
) -> Option<T> {
    match value {
        None if required => {
            errors.insert(field.into(), missing.into());
            None
        }
        None => None,
        Some(raw) => match rule(raw) {
            Ok(value) => Some(value),
            Err(message) => {
                errors.insert(field.into(), message);
                None
            }
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn acepta_correos_validos() {
        for email in ["ana@macrofit.com", "a.b+c@sub.dominio.mx", "x@y.io"] {
            assert!(is_valid_email(email), "{email} debería ser válido");
        }
    }

    #[test]
    fn rechaza_correos_invalidos() {
        for email in [
            "",
            "sin-arroba.com",
            "@macrofit.com",
            "ana@",
            "ana@macrofit",
            "ana@@macrofit.com",
            "ana @macrofit.com",
            "ana@macrofit..com",
            "ana@.macrofit.com",
        ] {
            assert!(!is_valid_email(email), "{email} debería ser inválido");
        }
    }

    #[test]
    fn normaliza_mayusculas_y_espacios() {
        assert_eq!(normalize_email("  Ana@MacroFit.COM "), "ana@macrofit.com");
    }

    #[test]
    fn fecha_exige_formato_estricto() {
        assert!(parse_date("2026-10-09").is_some());
        for value in ["2026-1-9", "09/10/2026", "2026-13-01", "2026-02-30", ""] {
            assert!(parse_date(value).is_none(), "{value} debería ser inválida");
        }
    }

    #[test]
    fn fecha_va_y_vuelve_de_bson() {
        let date = NaiveDate::from_ymd_opt(1996, 5, 20).unwrap();
        assert_eq!(date_to_string(date_to_bson(date)), "1996-05-20");
    }
}
