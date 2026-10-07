//! Reglas de validación reutilizables. Funciones puras: sin base de datos ni HTTP.

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
}
