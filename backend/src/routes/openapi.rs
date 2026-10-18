//! TEC-14 — contrato de la API en OpenAPI, generado desde el código con `utoipa`.
//!
//! - `GET /api/v1/openapi.json`: especificación OpenAPI 3.1.
//! - `GET /api/v1/docs`: Swagger UI sobre esa especificación.
//!
//! Se montan en todos los ambientes; las rutas `/dev` solo se documentan con `APP_ENV=development`.
//! Cómo documentar un endpoint nuevo: `src/routes/README.md`.

use axum::Router;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::{Modify, OpenApi};
use utoipa_swagger_ui::SwaggerUi;

use super::{auth, coach_invite_codes, coach_links, dev, goals, legal, meals, profile};

/// Ruta de la especificación en JSON.
pub const SPEC_PATH: &str = "/api/v1/openapi.json";
/// Ruta de Swagger UI.
pub const DOCS_PATH: &str = "/api/v1/docs";
/// Nombre del esquema de seguridad. En cada ruta protegida, su lista indica el rol requerido:
/// `[]` cualquier sesión, `["user"]` solo usuario, `["coach"]` solo coach.
pub const BEARER_AUTH: &str = "bearer_auth";

const API_DESCRIPTION: &str = "API REST de MacroFit. Todas las rutas cuelgan de `/api/v1`.

**Autenticación:** `Authorization: Bearer <access_token>` (obtenido en `/auth/login`). En cada ruta \
protegida, la lista de `bearer_auth` indica el rol requerido: vacía = cualquier sesión, `user` o `coach`. \
Un rol distinto responde `403 FORBIDDEN_ROLE`.

**Errores:** todas las respuestas de error tienen la forma `ErrorResponse` \
(`{ \"error\": { code, message, fields } }`); `fields` siempre es un objeto. Cualquier ruta puede \
responder `500 INTERNAL_ERROR` ante un error inesperado.";

/// Contrato de la API. Cada endpoint nuevo se agrega a `paths(...)` (ver `src/routes/README.md`).
#[derive(OpenApi)]
#[openapi(
    info(title = "MacroFit API", description = API_DESCRIPTION),
    servers((url = "/api/v1", description = "Servidor actual")),
    paths(
        super::health_handler,
        legal::privacy_handler,
        auth::register_handler,
        auth::login_handler,
        auth::refresh_handler,
        auth::logout_handler,
        auth::me_handler,
        profile::create_profile_handler,
        profile::get_profile_handler,
        profile::update_profile_handler,
        goals::get_current_goal_handler,
        goals::get_goals_history_handler,
        goals::list_clients_handler,
        goals::get_client_goals_handler,
        goals::set_client_goal_handler,
        coach_invite_codes::get_invite_code_handler,
        coach_invite_codes::regenerate_invite_code_handler,
        coach_links::link_coach_handler,
        coach_links::unlink_coach_handler,
        meals::upload_photo_handler,
        meals::estimate_meal_handler,
        meals::create_meal_handler,
        meals::list_meals_handler,
        meals::delete_meal_handler,
        auth::coach_only_handler,
    ),
    modifiers(&BearerAuth),
    tags(
        (name = "Servicio", description = "Estado del servidor"),
        (name = "Aviso de privacidad", description = "TEC-07"),
        (name = "Autenticación", description = "Registro (HU-01) y sesión (HU-02)"),
        (name = "Perfil", description = "Perfil inicial del usuario (HU-03)"),
        (name = "Metas", description = "Meta nutricional del usuario (HU-04)"),
        (name = "Coach", description = "Clientes, metas por coach (HU-05) y código de invitación (HU-12)"),
        (name = "Comidas", description = "Foto de la comida (HU-06), estimación nutricional (HU-07) y registros de comida (HU-09)"),
    )
)]
struct ApiDoc;

/// Rutas de datos de prueba: solo se documentan con `APP_ENV=development`, igual que se montan.
#[derive(OpenApi)]
#[openapi(
    paths(dev::seed_coach_link_handler),
    tags((name = "Desarrollo", description = "Datos de prueba; solo con `APP_ENV=development`")),
)]
struct DevApiDoc;

/// Declara el esquema `bearer_auth` (JWT) que usan las rutas protegidas.
struct BearerAuth;

impl Modify for BearerAuth {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.get_or_insert_with(Default::default);
        components.add_security_scheme(
            BEARER_AUTH,
            SecurityScheme::Http(
                HttpBuilder::new()
                    .scheme(HttpAuthScheme::Bearer)
                    .bearer_format("JWT")
                    .description(Some(
                        "Access token de `/auth/login` o `/auth/refresh` (15 min).",
                    ))
                    .build(),
            ),
        );
    }
}

/// Especificación completa. Con `dev_mode` incluye las rutas de datos de prueba (`/dev`).
pub fn spec(dev_mode: bool) -> utoipa::openapi::OpenApi {
    let mut doc = ApiDoc::openapi();
    if dev_mode {
        doc.merge(DevApiDoc::openapi());
    }
    doc
}

/// Swagger UI y la especificación. Se une al router raíz (fuera de `/api/v1`), porque la
/// interfaz pide la especificación por su ruta absoluta.
pub fn router<S: Clone + Send + Sync + 'static>(dev_mode: bool) -> Router<S> {
    SwaggerUi::new(DOCS_PATH)
        .url(SPEC_PATH, spec(dev_mode))
        .into()
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeSet;

    use axum::body::Body;
    use axum::http::{Method, Request, StatusCode};
    use serde_json::Value;
    use tower::ServiceExt;

    use super::*;
    use crate::config::TokenConfig;
    use crate::state::AppState;

    /// Autenticación que exige cada endpoint.
    #[derive(Debug, Clone, Copy, PartialEq)]
    enum Auth {
        Public,
        /// Cualquier sesión (`AuthenticatedUser`).
        Session,
        /// Solo rol `user` (`UserOnly`).
        User,
        /// Solo rol `coach` (`CoachOnly`).
        Coach,
    }

    use Auth::*;

    /// Catálogo de endpoints del README (`backend/README.md`): método, ruta bajo `/api/v1`,
    /// autenticación y códigos de estado que el contrato documenta.
    const CATALOG: &[(&str, &str, Auth, &[u16])] = &[
        ("get", "/health", Public, &[200]),
        ("get", "/legal/privacy", Public, &[200]),
        ("post", "/auth/register", Public, &[201, 400, 409]),
        ("post", "/auth/login", Public, &[200, 400, 401]),
        ("post", "/auth/refresh", Public, &[200, 400, 401]),
        ("post", "/auth/logout", Session, &[204, 400, 401]),
        ("get", "/auth/me", Session, &[200, 401]),
        (
            "post",
            "/users/me/profile",
            User,
            &[201, 400, 401, 403, 409],
        ),
        ("get", "/users/me/profile", User, &[200, 401, 403, 404]),
        (
            "patch",
            "/users/me/profile",
            User,
            &[200, 400, 401, 403, 404],
        ),
        (
            "get",
            "/users/me/goals/current",
            User,
            &[200, 401, 403, 404],
        ),
        ("get", "/users/me/goals", User, &[200, 401, 403, 404]),
        ("get", "/coach/clients", Coach, &[200, 401, 403]),
        (
            "get",
            "/coach/clients/{clientId}/goals",
            Coach,
            &[200, 401, 403],
        ),
        (
            "post",
            "/coach/clients/{clientId}/goals",
            Coach,
            &[201, 400, 401, 403],
        ),
        ("get", "/coach/invite-code", Coach, &[200, 401, 403]),
        (
            "post",
            "/coach/invite-code/regenerate",
            Coach,
            &[200, 401, 403],
        ),
        ("get", "/coach/test", Coach, &[200, 401, 403]),
        (
            "post",
            "/users/me/coach-link",
            User,
            &[201, 400, 401, 403, 404, 409],
        ),
        (
            "delete",
            "/users/me/coach-link",
            User,
            &[204, 401, 403, 404],
        ),
        (
            "post",
            "/meals/photos",
            User,
            &[201, 400, 401, 403, 413, 415],
        ),
        (
            "post",
            "/meals/estimate",
            User,
            &[200, 400, 401, 403, 404, 422, 502, 504],
        ),
        ("post", "/meals", User, &[201, 400, 401, 403, 404, 409]),
        ("get", "/meals", User, &[200, 400, 401, 403]),
        ("delete", "/meals/{id}", User, &[204, 401, 403, 404]),
    ];

    /// Rutas que solo existen con `APP_ENV=development`.
    const DEV_CATALOG: &[(&str, &str, Auth, &[u16])] =
        &[("post", "/dev/seed/coach-links", Public, &[201, 400])];

    fn spec_json(dev_mode: bool) -> Value {
        serde_json::to_value(spec(dev_mode)).expect("la especificación se serializa")
    }

    /// `(método, ruta)` de cada operación documentada.
    fn operations(spec: &Value) -> BTreeSet<(String, String)> {
        let mut ops = BTreeSet::new();
        if let Some(paths) = spec["paths"].as_object() {
            for (path, item) in paths {
                for method in ["get", "post", "put", "patch", "delete"] {
                    if item.get(method).is_some() {
                        ops.insert((method.to_string(), path.clone()));
                    }
                }
            }
        }
        ops
    }

    fn catalog_operations(catalog: &[(&str, &str, Auth, &[u16])]) -> BTreeSet<(String, String)> {
        catalog
            .iter()
            .map(|(method, path, _, _)| (method.to_string(), path.to_string()))
            .collect()
    }

    fn operation<'a>(spec: &'a Value, method: &str, path: &str) -> &'a Value {
        &spec["paths"][path][method]
    }

    #[test]
    fn la_especificacion_incluye_todos_los_endpoints_del_catalogo() {
        let spec = spec_json(false);
        assert_eq!(operations(&spec), catalog_operations(CATALOG));
        assert!(
            spec["openapi"]
                .as_str()
                .unwrap_or_default()
                .starts_with("3."),
            "versión de OpenAPI: {}",
            spec["openapi"]
        );
        assert_eq!(spec["servers"][0]["url"], crate::routes::API_PREFIX);
    }

    #[test]
    fn rutas_dev_solo_en_desarrollo() {
        let produccion = operations(&spec_json(false));
        assert!(produccion.iter().all(|(_, path)| !path.starts_with("/dev")));

        let desarrollo = operations(&spec_json(true));
        let mut esperado = catalog_operations(CATALOG);
        esperado.extend(catalog_operations(DEV_CATALOG));
        assert_eq!(desarrollo, esperado);
    }

    #[test]
    fn cada_operacion_documenta_sus_codigos_de_estado() {
        let spec = spec_json(true);
        for (method, path, _, statuses) in CATALOG.iter().chain(DEV_CATALOG) {
            let documented: BTreeSet<u16> = operation(&spec, method, path)["responses"]
                .as_object()
                .map(|responses| responses.keys().filter_map(|s| s.parse().ok()).collect())
                .unwrap_or_default();
            let expected: BTreeSet<u16> = statuses.iter().copied().collect();
            assert_eq!(documented, expected, "{method} {path}");
        }
    }

    #[test]
    fn cada_respuesta_exitosa_documenta_su_cuerpo() {
        let spec = spec_json(true);
        for (method, path, _, statuses) in CATALOG.iter().chain(DEV_CATALOG) {
            for status in statuses.iter().filter(|s| **s < 300 && **s != 204) {
                let response = &operation(&spec, method, path)["responses"][status.to_string()];
                let content = response["content"].as_object();
                assert!(
                    content.is_some_and(|c| !c.is_empty()),
                    "{method} {path} {status} sin cuerpo documentado"
                );
            }
        }
    }

    #[test]
    fn las_operaciones_con_cuerpo_documentan_la_peticion() {
        let spec = spec_json(true);
        let with_body = [
            ("post", "/auth/register"),
            ("post", "/auth/login"),
            ("post", "/auth/refresh"),
            ("post", "/auth/logout"),
            ("post", "/users/me/profile"),
            ("patch", "/users/me/profile"),
            ("post", "/users/me/coach-link"),
            ("post", "/coach/clients/{clientId}/goals"),
            ("post", "/dev/seed/coach-links"),
            ("post", "/meals/estimate"),
            ("post", "/meals"),
        ];
        let with_multipart = [("post", "/meals/photos")];
        for (method, path) in operations(&spec) {
            let body = &operation(&spec, &method, &path)["requestBody"];
            let key = (method.as_str(), path.as_str());
            if with_body.contains(&key) {
                let schema = &body["content"]["application/json"]["schema"];
                assert!(schema.is_object(), "{method} {path} sin cuerpo de petición");
            } else if with_multipart.contains(&key) {
                let schema = &body["content"]["multipart/form-data"]["schema"];
                assert!(
                    schema.is_object(),
                    "{method} {path} sin formulario multipart"
                );
            } else {
                assert!(body.is_null(), "{method} {path} no recibe cuerpo");
            }
        }
    }

    #[test]
    fn todas_las_respuestas_de_error_usan_el_esquema_comun() {
        let spec = spec_json(true);
        let error_ref = "#/components/schemas/ErrorResponse";
        for (method, path) in operations(&spec) {
            let responses = operation(&spec, &method, &path)["responses"]
                .as_object()
                .cloned()
                .unwrap_or_default();
            for (status, response) in responses {
                if status.parse::<u16>().unwrap_or_default() < 400 {
                    continue;
                }
                assert_eq!(
                    response["content"]["application/json"]["schema"]["$ref"], error_ref,
                    "{method} {path} {status}"
                );
                let description = response["description"].as_str().unwrap_or_default();
                assert!(
                    description.contains('`'),
                    "{method} {path} {status}: la descripción debe nombrar los códigos de error"
                );
            }
        }

        let error = &spec["components"]["schemas"]["ErrorResponse"];
        assert_eq!(error["required"], serde_json::json!(["error"]));
        let body = &spec["components"]["schemas"]["ErrorBody"];
        assert_eq!(
            body["required"],
            serde_json::json!(["code", "message", "fields"])
        );
        assert_eq!(body["properties"]["fields"]["type"], "object");
        assert_eq!(
            body["properties"]["fields"]["additionalProperties"]["type"],
            "string"
        );
    }

    #[test]
    fn rutas_protegidas_declaran_bearer_y_rol() {
        let spec = spec_json(true);
        let scheme = &spec["components"]["securitySchemes"]["bearer_auth"];
        assert_eq!(scheme["type"], "http");
        assert_eq!(scheme["scheme"], "bearer");
        assert_eq!(scheme["bearerFormat"], "JWT");

        for (method, path, auth, _) in CATALOG.iter().chain(DEV_CATALOG) {
            let security = &operation(&spec, method, path)["security"];
            let expected = match auth {
                Public => Value::Null,
                Session => serde_json::json!([{ "bearer_auth": [] }]),
                User => serde_json::json!([{ "bearer_auth": ["user"] }]),
                Coach => serde_json::json!([{ "bearer_auth": ["coach"] }]),
            };
            assert_eq!(security, &expected, "{method} {path}");
        }
    }

    // ---------- Contra el router real ----------

    /// Estado de prueba: el cliente de Mongo no se conecta hasta la primera consulta y,
    /// si alguna petición llegara a la base, falla rápido en lugar de esperar 30 s.
    async fn test_state() -> AppState {
        let client = mongodb::Client::with_uri_str(
            "mongodb://127.0.0.1:1/?serverSelectionTimeoutMS=200&connectTimeoutMS=200",
        )
        .await
        .expect("el cliente se crea sin conectarse");
        AppState {
            db: client.database("macrofit_openapi_test"),
            tokens: TokenConfig {
                jwt_secret: "secreto-de-prueba".to_string(),
                access_ttl: chrono::Duration::minutes(15),
                refresh_ttl: chrono::Duration::days(30),
            },
            food: crate::services::food_recognition::FoodService::simulator(
                crate::config::SimulatorMode::Ok,
                std::time::Duration::from_secs(10),
            ),
            utc_offset: crate::config::default_utc_offset(),
        }
    }

    async fn call(dev_mode: bool, method: &str, uri: &str) -> (StatusCode, String, String) {
        let app = crate::routes::api_router(dev_mode).with_state(test_state().await);
        let request = Request::builder()
            .method(Method::from_bytes(method.to_uppercase().as_bytes()).expect("método"))
            .uri(uri)
            .header("content-type", "application/json")
            .body(Body::from("{}"))
            .expect("petición");
        let response = app.oneshot(request).await.expect("respuesta");
        let status = response.status();
        let content_type = response
            .headers()
            .get("content-type")
            .and_then(|v| v.to_str().ok())
            .unwrap_or_default()
            .to_string();
        let bytes = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("cuerpo");
        (
            status,
            content_type,
            String::from_utf8_lossy(&bytes).into_owned(),
        )
    }

    /// Sustituye `{param}` por un ObjectId válido.
    fn concrete(path: &str) -> String {
        path.split('/')
            .map(|segment| {
                if segment.starts_with('{') {
                    "000000000000000000000000"
                } else {
                    segment
                }
            })
            .collect::<Vec<_>>()
            .join("/")
    }

    #[tokio::test]
    async fn cada_operacion_documentada_existe_en_el_router() {
        for (method, path) in operations(&spec_json(true)) {
            let uri = format!("/api/v1{}", concrete(&path));
            let (status, _, _) = call(true, &method, &uri).await;
            assert!(
                status != StatusCode::NOT_FOUND && status != StatusCode::METHOD_NOT_ALLOWED,
                "{method} {path} no existe en el router ({status})"
            );
        }
    }

    #[tokio::test]
    async fn ruta_dev_no_existe_fuera_de_desarrollo() {
        let (status, _, _) = call(false, "post", "/api/v1/dev/seed/coach-links").await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        let (status, _, _) = call(true, "post", "/api/v1/dev/seed/coach-links").await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn la_documentacion_se_sirve_en_docs() {
        let (status, content_type, body) = call(false, "get", SPEC_PATH).await;
        assert_eq!(status, StatusCode::OK);
        assert!(content_type.starts_with("application/json"));
        let served: Value = serde_json::from_str(&body).expect("JSON");
        assert_eq!(served, spec_json(false));

        let (status, content_type, body) = call(false, "get", &format!("{DOCS_PATH}/")).await;
        assert_eq!(status, StatusCode::OK);
        assert!(content_type.starts_with("text/html"));
        assert!(body.contains("swagger"), "Swagger UI no se sirvió");
    }

    #[test]
    fn lista_de_clientes_documenta_meta_y_ultimo_registro() {
        let spec = spec_json(false);
        let items = &operation(&spec, "get", "/coach/clients")["responses"]["200"]["content"]["application/json"]
            ["schema"]["items"]["$ref"];
        assert_eq!(items, "#/components/schemas/ClientResponse");

        let client = &spec["components"]["schemas"]["ClientResponse"];
        let required: BTreeSet<&str> = client["required"]
            .as_array()
            .map(|fields| fields.iter().filter_map(Value::as_str).collect())
            .unwrap_or_default();
        assert_eq!(
            required,
            BTreeSet::from(["id", "name", "email", "goal", "last_meal_at"])
        );

        let properties = &client["properties"];
        assert_eq!(
            properties["last_meal_at"]["type"],
            serde_json::json!(["string", "null"])
        );
        assert_eq!(properties["last_meal_at"]["format"], "date-time");
        let goal_variants = properties["goal"]["oneOf"]
            .as_array()
            .cloned()
            .unwrap_or_default();
        assert!(goal_variants.contains(&serde_json::json!({ "type": "null" })));
        assert!(
            goal_variants
                .iter()
                .any(|variant| variant["$ref"] == "#/components/schemas/ClientGoalSummary"),
            "goal debe referenciar ClientGoalSummary: {}",
            properties["goal"]
        );

        let goal = &spec["components"]["schemas"]["ClientGoalSummary"];
        let goal_required: BTreeSet<&str> = goal["required"]
            .as_array()
            .map(|fields| fields.iter().filter_map(Value::as_str).collect())
            .unwrap_or_default();
        assert_eq!(
            goal_required,
            BTreeSet::from(["calories", "protein_g", "fat_g", "source"])
        );
    }
}
