//! Script independiente para cargar el catálogo inicial de ejercicios en MongoDB.
//! Uso:
//!   cargo run --bin seed_exercises

use dotenvy::dotenv;
use std::env;

#[tokio::main]
async fn main() {
    dotenv().ok();

    let mongo_uri =
        env::var("MONGO_URI").unwrap_or_else(|_| "mongodb://localhost:27017".to_string());
    let db_name = env::var("DB_NAME").unwrap_or_else(|_| "macrofit_db".to_string());

    println!("Iniciando carga del catálogo inicial de ejercicios...");
    println!("Conectando a base de datos '{db_name}' en '{mongo_uri}'...");

    let db = backend::db::connect(&mongo_uri, &db_name).await;

    match backend::services::exercises::seed_exercises(&db).await {
        Ok(count) => {
            println!(
                "¡Éxito! Se cargaron/actualizaron {count} ejercicios en la colección 'exercises'."
            );
        }
        Err(err) => {
            eprintln!("Error al sembrar el catálogo de ejercicios: {err}");
            std::process::exit(1);
        }
    }
}
