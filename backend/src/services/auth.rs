use std::sync::LazyLock;

use mongodb::{
    Database,
    bson::{DateTime, doc, oid::ObjectId},
    error::{ErrorKind, WriteFailure},
};

use crate::auth::password::{hash_password, verify_password};
use crate::error::{AppError, FieldErrors};
use crate::models::user::{Role, USERS_COLLECTION, User};
use crate::services::legal::PRIVACY_VERSION;
use crate::validation::{
    NAME_MAX_CHARS, PASSWORD_MAX_CHARS, PASSWORD_MIN_CHARS, is_valid_email, normalize_email,
};

/// Código de MongoDB para violación de índice único.
const DUPLICATE_KEY: i32 = 11000;

/// Datos de registro tal como llegan del cliente (todo opcional para poder
/// señalar campo por campo lo que falta).
#[derive(Debug, Default)]
pub struct RegisterInput {
    pub name: Option<String>,
    pub email: Option<String>,
    pub password: Option<String>,
    pub role: Option<String>,
    pub privacy_accepted: Option<bool>,
}

/// Datos de registro ya validados y normalizados.
#[derive(Debug, PartialEq)]
pub struct ValidRegistration {
    pub name: String,
    pub email: String,
    pub password: String,
    pub role: Role,
}

/// Valida los datos de registro y devuelve todos los campos inválidos a la vez.
///
/// Aviso de privacidad (TEC-07): si hay otros campos inválidos se reporta como un campo
/// más (`fields.privacy_accepted`) dentro de `VALIDATION_ERROR`; si es lo único que
/// falta, responde `PRIVACY_NOT_ACCEPTED`.
pub fn validate_registration(input: RegisterInput) -> Result<ValidRegistration, AppError> {
    let mut errors = FieldErrors::new();

    let name = input.name.unwrap_or_default().trim().to_string();
    if name.is_empty() {
        errors.insert("name".into(), "El nombre es obligatorio".into());
    } else if name.chars().count() > NAME_MAX_CHARS {
        errors.insert(
            "name".into(),
            format!("El nombre no puede superar {NAME_MAX_CHARS} caracteres"),
        );
    }

    let email = normalize_email(&input.email.unwrap_or_default());
    if email.is_empty() {
        errors.insert("email".into(), "El correo es obligatorio".into());
    } else if !is_valid_email(&email) {
        errors.insert(
            "email".into(),
            "El correo no tiene un formato válido".into(),
        );
    }

    let password = input.password.unwrap_or_default();
    let password_chars = password.chars().count();
    if password.is_empty() {
        errors.insert("password".into(), "La contraseña es obligatoria".into());
    } else if password_chars < PASSWORD_MIN_CHARS {
        errors.insert(
            "password".into(),
            format!("La contraseña debe tener al menos {PASSWORD_MIN_CHARS} caracteres"),
        );
    } else if password_chars > PASSWORD_MAX_CHARS {
        errors.insert(
            "password".into(),
            format!("La contraseña no puede superar {PASSWORD_MAX_CHARS} caracteres"),
        );
    }

    let role = match input.role.as_deref().map(str::trim) {
        None | Some("") => {
            errors.insert("role".into(), "Debes elegir un rol".into());
            None
        }
        Some(value) => {
            let role = Role::parse(value);
            if role.is_none() {
                errors.insert("role".into(), "El rol debe ser 'user' o 'coach'".into());
            }
            role
        }
    };

    let privacy_accepted = input.privacy_accepted.unwrap_or(false);

    match role {
        Some(role) if errors.is_empty() => {
            if privacy_accepted {
                Ok(ValidRegistration {
                    name,
                    email,
                    password,
                    role,
                })
            } else {
                Err(AppError::PrivacyNotAccepted)
            }
        }
        _ => {
            if !privacy_accepted {
                errors.insert(
                    "privacy_accepted".into(),
                    "Debes aceptar el aviso de privacidad".into(),
                );
            }
            Err(AppError::Validation(errors))
        }
    }
}

/// HU-01: crea una cuenta con el rol elegido. La contraseña solo se guarda como hash.
pub async fn register(db: &Database, input: RegisterInput) -> Result<User, AppError> {
    let data = validate_registration(input)?;
    let users = db.collection::<User>(USERS_COLLECTION);

    // Comprobación previa para no gastar un hash en un correo repetido.
    // El índice único sigue siendo la garantía real ante peticiones simultáneas.
    if users
        .find_one(doc! { "email": &data.email })
        .await
        .map_err(AppError::internal)?
        .is_some()
    {
        return Err(AppError::EmailAlreadyExists);
    }

    let password = data.password;
    let password_hash = tokio::task::spawn_blocking(move || hash_password(&password))
        .await
        .map_err(AppError::internal)??;

    let now = DateTime::now();
    let mut user = User {
        id: None,
        name: data.name,
        email: data.email,
        password_hash,
        role: data.role,
        privacy_accepted_at: Some(now),
        privacy_version: Some(PRIVACY_VERSION.clone()),
        profile_completed: false,
        created_at: now,
    };

    let result = users.insert_one(&user).await.map_err(|err| {
        if is_duplicate_key(&err) {
            AppError::EmailAlreadyExists
        } else {
            AppError::internal(err)
        }
    })?;
    user.id = result.inserted_id.as_object_id();

    Ok(user)
}

/// Busca la cuenta por correo y comprueba la contraseña.
/// Responde el mismo error si el correo no existe o la contraseña es incorrecta.
pub async fn login(
    db: &Database,
    email: Option<String>,
    password: Option<String>,
) -> Result<User, AppError> {
    let email = normalize_email(&email.unwrap_or_default());
    let password = password.unwrap_or_default();

    let mut errors = FieldErrors::new();
    if email.is_empty() {
        errors.insert("email".into(), "El correo es obligatorio".into());
    }
    if password.is_empty() {
        errors.insert("password".into(), "La contraseña es obligatoria".into());
    }
    if !errors.is_empty() {
        return Err(AppError::Validation(errors));
    }

    let user = db
        .collection::<User>(USERS_COLLECTION)
        .find_one(doc! { "email": &email })
        .await
        .map_err(AppError::internal)?;

    // Si el correo no existe se verifica contra un hash ficticio: así la respuesta
    // tarda lo mismo y no revela qué correos están registrados.
    let hash = match &user {
        Some(user) => user.password_hash.clone(),
        None => DUMMY_HASH.clone(),
    };
    let is_valid = tokio::task::spawn_blocking(move || verify_password(&password, &hash))
        .await
        .map_err(AppError::internal)??;

    match user {
        Some(user) if is_valid => Ok(user),
        _ => Err(AppError::InvalidCredentials),
    }
}

static DUMMY_HASH: LazyLock<String> = LazyLock::new(|| {
    hash_password("contrasena-ficticia-para-igualar-tiempos").expect("hash ficticio")
});

pub async fn find_user_by_id(db: &Database, id: ObjectId) -> Result<Option<User>, AppError> {
    db.collection::<User>(USERS_COLLECTION)
        .find_one(doc! { "_id": id })
        .await
        .map_err(AppError::internal)
}

fn is_duplicate_key(err: &mongodb::error::Error) -> bool {
    matches!(
        err.kind.as_ref(),
        ErrorKind::Write(WriteFailure::WriteError(write_error)) if write_error.code == DUPLICATE_KEY
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_input() -> RegisterInput {
        RegisterInput {
            name: Some("Ana".into()),
            email: Some("Ana@MacroFit.com".into()),
            password: Some("Segura123".into()),
            role: Some("coach".into()),
            privacy_accepted: Some(true),
        }
    }

    fn field_errors(input: RegisterInput) -> FieldErrors {
        match validate_registration(input) {
            Err(AppError::Validation(fields)) => fields,
            other => panic!("se esperaba error de validación, llegó {other:?}"),
        }
    }

    #[test]
    fn registro_valido_normaliza_el_correo() {
        let data = validate_registration(valid_input()).unwrap();
        assert_eq!(data.email, "ana@macrofit.com");
        assert_eq!(data.role, Role::Coach);
    }

    #[test]
    fn sin_aviso_de_privacidad_responde_privacy_not_accepted() {
        for privacy_accepted in [None, Some(false)] {
            let input = RegisterInput {
                privacy_accepted,
                ..valid_input()
            };
            assert!(matches!(
                validate_registration(input),
                Err(AppError::PrivacyNotAccepted)
            ));
        }
    }

    #[test]
    fn sin_aviso_y_con_campos_invalidos_lo_reporta_como_campo() {
        let fields = field_errors(RegisterInput {
            email: Some("no-es-correo".into()),
            privacy_accepted: Some(false),
            ..valid_input()
        });
        assert_eq!(
            fields.keys().collect::<Vec<_>>(),
            ["email", "privacy_accepted"]
        );
    }

    #[test]
    fn sin_rol_senala_role() {
        let fields = field_errors(RegisterInput {
            role: None,
            ..valid_input()
        });
        assert!(fields.contains_key("role"));
    }

    #[test]
    fn rol_invalido_senala_role() {
        for role in ["admin", "User", "COACH"] {
            let fields = field_errors(RegisterInput {
                role: Some(role.into()),
                ..valid_input()
            });
            assert_eq!(fields.keys().collect::<Vec<_>>(), ["role"], "rol {role}");
        }
    }

    #[test]
    fn correo_invalido_senala_email() {
        let fields = field_errors(RegisterInput {
            email: Some("no-es-correo".into()),
            ..valid_input()
        });
        assert_eq!(fields.keys().collect::<Vec<_>>(), ["email"]);
    }

    #[test]
    fn contrasena_corta_senala_password() {
        let fields = field_errors(RegisterInput {
            password: Some("1234567".into()),
            ..valid_input()
        });
        assert_eq!(fields.keys().collect::<Vec<_>>(), ["password"]);
    }

    #[test]
    fn contrasena_de_8_caracteres_es_valida() {
        let input = RegisterInput {
            password: Some("12345678".into()),
            ..valid_input()
        };
        assert!(validate_registration(input).is_ok());
    }

    #[test]
    fn nombre_vacio_o_en_blanco_senala_name() {
        for name in ["", "   "] {
            let fields = field_errors(RegisterInput {
                name: Some(name.into()),
                ..valid_input()
            });
            assert_eq!(fields.keys().collect::<Vec<_>>(), ["name"]);
        }
    }

    #[test]
    fn cuerpo_vacio_senala_todos_los_campos() {
        let fields = field_errors(RegisterInput::default());
        assert_eq!(
            fields.keys().collect::<Vec<_>>(),
            ["email", "name", "password", "privacy_accepted", "role"]
        );
    }
}
