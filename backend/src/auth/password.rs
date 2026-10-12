use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};

use crate::error::AppError;

/// Genera el hash Argon2id (formato PHC, incluye la sal) de una contraseña.
///
/// Es una operación costosa a propósito: llámala con `spawn_blocking` desde
/// código async (ver `services::auth`).
pub fn hash_password(password: &str) -> Result<String, AppError> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(AppError::internal)
}

/// Comprueba una contraseña contra un hash guardado.
pub fn verify_password(password: &str, hash: &str) -> Result<bool, AppError> {
    let parsed = PasswordHash::new(hash).map_err(AppError::internal)?;
    Ok(Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .is_ok())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn el_hash_no_contiene_la_contrasena_y_se_verifica() {
        let hash = hash_password("Secreta123").unwrap();
        assert!(hash.starts_with("$argon2id$"));
        assert!(!hash.contains("Secreta123"));
        assert!(verify_password("Secreta123", &hash).unwrap());
        assert!(!verify_password("otra-clave", &hash).unwrap());
    }
}
