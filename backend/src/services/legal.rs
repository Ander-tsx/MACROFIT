//! TEC-07: aviso de privacidad. El texto se embebe al compilar desde
//! `docs/legal/aviso-de-privacidad.md` (única fuente de verdad); la versión vigente
//! se lee de su línea `**Versión:** x.y`.

use std::sync::LazyLock;

/// Markdown completo del aviso de privacidad.
pub const PRIVACY_NOTICE: &str = include_str!("../../../docs/legal/aviso-de-privacidad.md");

/// Versión vigente del aviso. Se guarda en `users.privacy_version` al registrarse.
pub static PRIVACY_VERSION: LazyLock<String> = LazyLock::new(|| {
    parse_version(PRIVACY_NOTICE).expect("el aviso de privacidad no declara su versión")
});

/// Busca la línea `**Versión:** x.y` y devuelve `x.y`.
fn parse_version(markdown: &str) -> Option<String> {
    markdown.lines().find_map(|line| {
        line.trim()
            .strip_prefix("**Versión:**")
            .map(|rest| rest.trim().to_string())
            .filter(|version| !version.is_empty())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn el_aviso_embebido_declara_su_version() {
        assert!(!PRIVACY_VERSION.is_empty());
        assert!(PRIVACY_NOTICE.contains(&format!("**Versión:** {}", *PRIVACY_VERSION)));
    }

    #[test]
    fn lee_la_version_de_la_cabecera() {
        let md = "# Aviso\n\n**Última actualización:** hoy\n**Versión:** 2.3\n\nTexto";
        assert_eq!(parse_version(md).as_deref(), Some("2.3"));
        assert_eq!(parse_version("# Sin versión"), None);
    }
}
