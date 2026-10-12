//! Refresh tokens opacos: 32 bytes aleatorios en hexadecimal. En la base de datos
//! solo se guarda su SHA-256; basta un hash rápido porque el token es aleatorio
//! (no se puede adivinar por diccionario como una contraseña).

use rand::{RngCore, rngs::OsRng};
use sha2::{Digest, Sha256};

pub struct NewRefreshToken {
    /// Valor que se entrega al cliente. No se guarda.
    pub token: String,
    /// Valor que se guarda en `refresh_tokens.token_hash`.
    pub hash: String,
}

pub fn generate_refresh_token() -> NewRefreshToken {
    let mut bytes = [0u8; 32];
    OsRng.fill_bytes(&mut bytes);
    let token = to_hex(&bytes);
    let hash = hash_refresh_token(&token);
    NewRefreshToken { token, hash }
}

pub fn hash_refresh_token(token: &str) -> String {
    to_hex(&Sha256::digest(token.as_bytes()))
}

fn to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn genera_tokens_distintos_y_guarda_solo_el_hash() {
        let a = generate_refresh_token();
        let b = generate_refresh_token();
        assert_eq!(a.token.len(), 64);
        assert_ne!(a.token, b.token);
        assert_ne!(a.token, a.hash);
        assert_eq!(hash_refresh_token(&a.token), a.hash);
    }
}
