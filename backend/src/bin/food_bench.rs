//! TEC-02 — banco de pruebas de los servicios de reconocimiento de alimentos.
//!
//! Recorre uno o más manifiestos (`bench/*.csv`), manda cada foto a cada proveedor **con el mismo adaptador que usará
//! la API** (`services::food_recognition`) y escribe en `bench/results/<fecha>/`:
//! - `resultados.csv`: una fila por proveedor y foto (latencia, alimentos, valores, error % contra la referencia).
//! - `resumen.md`: la tabla comparativa (precisión vs. 20 % de RNF-03, latencia vs. 10 s de RNF-01, RF-06 y
//!   detección de fotos sin comida).
//!
//! Las credenciales se leen de `.env` / variables de entorno (igual que el servidor); nunca se imprimen.
//!
//! ```bash
//! cargo run --release --bin food_bench -- --providers logmeal,gemini,gemini_fatsecret
//! cargo run --release --bin food_bench -- --providers gemini --limit 3   # prueba rápida
//! ```

use std::fmt::Write as _;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use backend::config::{FoodConfig, FoodProviderKind};
use backend::services::food_recognition::{
    FoodEstimate, FoodService, RecognitionError, build_recognizer, preprocess,
};

const USAGE: &str = "Uso: food_bench [--providers logmeal,gemini,gemini_fatsecret] \
[--manifest bench/manifest.nutrition5k.csv --manifest bench/manifest.local.csv] [--photos bench/photos] \
[--out bench/results] [--delay-ms 4000] [--timeout-secs 30] [--limit N]";

/// Umbral de precisión de RNF-03 (error promedio) y de latencia de RNF-01.
const MAX_ERROR_PCT: f64 = 20.0;
const MAX_LATENCY_MS: u128 = 10_000;

struct Args {
    providers: Vec<FoodProviderKind>,
    manifests: Vec<PathBuf>,
    photos: PathBuf,
    out: PathBuf,
    delay: Duration,
    timeout: Duration,
    limit: Option<usize>,
}

fn parse_args() -> Result<Args, String> {
    let mut args = Args {
        providers: vec![
            FoodProviderKind::LogMeal,
            FoodProviderKind::Gemini,
            FoodProviderKind::GeminiFatSecret,
        ],
        manifests: Vec::new(),
        photos: PathBuf::from("bench/photos"),
        out: PathBuf::from("bench/results"),
        delay: Duration::from_millis(4000),
        timeout: Duration::from_secs(30),
        limit: None,
    };
    let mut iter = std::env::args().skip(1);
    while let Some(flag) = iter.next() {
        let mut value = || {
            iter.next()
                .ok_or_else(|| format!("falta el valor de {flag}"))
        };
        match flag.as_str() {
            "--providers" => {
                args.providers = value()?
                    .split(',')
                    .map(|p| {
                        FoodProviderKind::parse(p)
                            .ok_or_else(|| format!("proveedor desconocido: {p}"))
                    })
                    .collect::<Result<_, _>>()?
            }
            "--manifest" => args.manifests.push(PathBuf::from(value()?)),
            "--photos" => args.photos = PathBuf::from(value()?),
            "--out" => args.out = PathBuf::from(value()?),
            "--delay-ms" => {
                args.delay =
                    Duration::from_millis(value()?.parse().map_err(|_| "--delay-ms inválido")?)
            }
            "--timeout-secs" => {
                args.timeout =
                    Duration::from_secs(value()?.parse().map_err(|_| "--timeout-secs inválido")?)
            }
            "--limit" => args.limit = Some(value()?.parse().map_err(|_| "--limit inválido")?),
            "-h" | "--help" => return Err(USAGE.to_string()),
            other => return Err(format!("argumento desconocido: {other}\n{USAGE}")),
        }
    }
    if args.manifests.is_empty() {
        for default in ["bench/manifest.nutrition5k.csv", "bench/manifest.local.csv"] {
            if Path::new(default).exists() {
                args.manifests.push(PathBuf::from(default));
            }
        }
    }
    if args.manifests.is_empty() {
        return Err(format!("no hay manifiestos en bench/\n{USAGE}"));
    }
    Ok(args)
}

/// Fila del manifiesto: `file,source,ref_kcal,ref_protein_g,ref_fat_g,expects_food,notes`.
#[derive(Debug, Clone)]
struct Photo {
    file: String,
    source: String,
    reference: Option<(f64, f64, f64)>,
    expects_food: bool,
}

fn read_manifest(path: &Path) -> Result<Vec<Photo>, String> {
    let text = std::fs::read_to_string(path)
        .map_err(|err| format!("no se pudo leer {}: {err}", path.display()))?;
    let mut photos = Vec::new();
    for (index, line) in text.lines().enumerate().skip(1) {
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }
        let cols: Vec<&str> = line.split(',').map(str::trim).collect();
        if cols.len() < 6 {
            return Err(format!(
                "{}:{}: se esperaban al menos 6 columnas",
                path.display(),
                index + 1
            ));
        }
        let number = |s: &str| s.parse::<f64>().ok();
        let reference = match (number(cols[2]), number(cols[3]), number(cols[4])) {
            (Some(k), Some(p), Some(f)) => Some((k, p, f)),
            _ => None,
        };
        photos.push(Photo {
            file: cols[0].to_string(),
            source: cols[1].to_string(),
            reference,
            expects_food: !matches!(cols[5], "false" | "0" | "no"),
        });
    }
    Ok(photos)
}

/// Resultado de una llamada.
struct Run {
    provider: &'static str,
    photo: Photo,
    latency_ms: u128,
    outcome: Result<FoodEstimate, RecognitionError>,
}

impl Run {
    fn status(&self) -> &'static str {
        match &self.outcome {
            Ok(_) => "ok",
            Err(RecognitionError::NotRecognized) => "not_recognized",
            Err(RecognitionError::Provider(_)) => "provider_error",
            Err(RecognitionError::Timeout) => "timeout",
        }
    }

    /// Error % de calorías, proteína y grasa contra la referencia (si hay referencia y estimación).
    fn errors(&self) -> Option<[Option<f64>; 3]> {
        let (k, p, f) = self.photo.reference?;
        let totals = self.outcome.as_ref().ok()?.totals;
        let pct = |est: f64, real: f64| (real > 0.0).then(|| (est - real).abs() / real * 100.0);
        Some([
            pct(totals.calories_kcal, k),
            pct(totals.protein_g, p),
            pct(totals.fat_g, f),
        ])
    }
}

fn csv_field(text: &str) -> String {
    let clean = text.replace(['\n', '\r'], " ");
    if clean.contains([',', '"']) {
        format!("\"{}\"", clean.replace('"', "\"\""))
    } else {
        clean
    }
}

fn fmt_opt(value: Option<f64>) -> String {
    value.map(|v| format!("{v:.1}")).unwrap_or_default()
}

fn write_csv(runs: &[Run]) -> String {
    let mut out = String::from(
        "provider,file,source,expects_food,status,latency_ms,foods,kcal,protein_g,fat_g,\
ref_kcal,ref_protein_g,ref_fat_g,err_kcal_pct,err_protein_pct,err_fat_pct,detail\n",
    );
    for run in runs {
        let (foods, totals) = match &run.outcome {
            Ok(estimate) => (
                estimate
                    .foods
                    .iter()
                    .map(|f| match f.grams {
                        Some(g) => format!("{} ({g} g)", f.name),
                        None => f.name.clone(),
                    })
                    .collect::<Vec<_>>()
                    .join(" | "),
                Some(estimate.totals),
            ),
            Err(_) => (String::new(), None),
        };
        let reference = run.photo.reference;
        let errors = run.errors().unwrap_or([None, None, None]);
        let detail = match &run.outcome {
            Err(RecognitionError::Provider(detail)) => detail.clone(),
            _ => String::new(),
        };
        let _ = writeln!(
            out,
            "{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}",
            run.provider,
            csv_field(&run.photo.file),
            csv_field(&run.photo.source),
            run.photo.expects_food,
            run.status(),
            run.latency_ms,
            csv_field(&foods),
            fmt_opt(totals.map(|t| t.calories_kcal)),
            fmt_opt(totals.map(|t| t.protein_g)),
            fmt_opt(totals.map(|t| t.fat_g)),
            fmt_opt(reference.map(|r| r.0)),
            fmt_opt(reference.map(|r| r.1)),
            fmt_opt(reference.map(|r| r.2)),
            fmt_opt(errors[0]),
            fmt_opt(errors[1]),
            fmt_opt(errors[2]),
            csv_field(&detail),
        );
    }
    out
}

fn mean(values: &[f64]) -> Option<f64> {
    (!values.is_empty()).then(|| values.iter().sum::<f64>() / values.len() as f64)
}

fn percentile(sorted: &[u128], pct: f64) -> Option<u128> {
    if sorted.is_empty() {
        return None;
    }
    let rank = ((pct / 100.0) * sorted.len() as f64).ceil() as usize;
    Some(sorted[rank.clamp(1, sorted.len()) - 1])
}

fn summary(runs: &[Run], providers: &[&'static str]) -> String {
    let mut out = String::from("# Resultados del banco de pruebas (TEC-02)\n\n");
    let _ = writeln!(
        out,
        "Fecha: {} · Fotos por proveedor: {}\n",
        chrono::Local::now().format("%Y-%m-%d %H:%M"),
        runs.iter().filter(|r| r.provider == providers[0]).count()
    );
    out.push_str(
        "| Proveedor | Error kcal | Error proteína | Error grasa | Error promedio | Fotos ≤ 20 % (kcal) | \
Latencia p50 | Latencia p90 | Fotos ≤ 10 s | Comida no reconocida (falsos negativos) | Sin comida detectada | Fallas | Cumple |\n",
    );
    out.push_str("|---|---|---|---|---|---|---|---|---|---|---|---|---|\n");
    for provider in providers {
        let mine: Vec<&Run> = runs.iter().filter(|r| r.provider == *provider).collect();
        let errors: Vec<[Option<f64>; 3]> = mine.iter().filter_map(|r| r.errors()).collect();
        let column = |i: usize| errors.iter().filter_map(|e| e[i]).collect::<Vec<f64>>();
        let (kcal, protein, fat) = (column(0), column(1), column(2));
        let per_photo: Vec<f64> = errors
            .iter()
            .filter_map(|e| {
                let vals: Vec<f64> = e.iter().flatten().copied().collect();
                mean(&vals)
            })
            .collect();
        let average = mean(&per_photo);
        let with_reference = mine.iter().filter(|r| r.photo.reference.is_some()).count();
        let within = kcal.iter().filter(|e| **e <= MAX_ERROR_PCT).count();

        let mut latencies: Vec<u128> = mine.iter().map(|r| r.latency_ms).collect();
        latencies.sort_unstable();
        let p90 = percentile(&latencies, 90.0);
        let fast = latencies.iter().filter(|l| **l <= MAX_LATENCY_MS).count();

        let food = mine.iter().filter(|r| r.photo.expects_food).count();
        let missed = mine
            .iter()
            .filter(|r| r.photo.expects_food && r.status() == "not_recognized")
            .count();
        let non_food = mine.iter().filter(|r| !r.photo.expects_food).count();
        let detected = mine
            .iter()
            .filter(|r| !r.photo.expects_food && r.status() == "not_recognized")
            .count();
        let failures = mine
            .iter()
            .filter(|r| matches!(r.status(), "provider_error" | "timeout"))
            .count();
        let complies =
            average.is_some_and(|a| a <= MAX_ERROR_PCT) && p90.is_some_and(|p| p <= MAX_LATENCY_MS);

        let pct = |v: Option<f64>| v.map(|v| format!("{v:.1} %")).unwrap_or("—".into());
        let ms = |v: Option<u128>| {
            v.map(|v| format!("{:.1} s", v as f64 / 1000.0))
                .unwrap_or("—".into())
        };
        let _ = writeln!(
            out,
            "| {provider} | {} | {} | {} | **{}** | {within}/{with_reference} | {} | **{}** | {fast}/{} | {missed}/{food} | {detected}/{non_food} | {failures} | {} |",
            pct(mean(&kcal)),
            pct(mean(&protein)),
            pct(mean(&fat)),
            pct(average),
            ms(percentile(&latencies, 50.0)),
            ms(p90),
            latencies.len(),
            if complies { "✅" } else { "❌" },
        );
    }
    out.push_str(
        "\n- **Error** = |estimado − real| / real, promedio de las fotos con referencia. *Error promedio* = media de los \
tres macros por foto; RNF-03 pide ≤ 20 %.\n- **Latencia** de extremo a extremo (preparar la foto + proveedor); RNF-01 pide \
que el 90 % de las fotos tarde ≤ 10 s (p90 ≤ 10 s).\n- **Cumple** = error promedio ≤ 20 % y p90 ≤ 10 s.\n",
    );
    out
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let args = match parse_args() {
        Ok(args) => args,
        Err(message) => {
            eprintln!("{message}");
            std::process::exit(2);
        }
    };

    let mut photos = Vec::new();
    for manifest in &args.manifests {
        match read_manifest(manifest) {
            Ok(mut list) => photos.append(&mut list),
            Err(message) => {
                eprintln!("{message}");
                std::process::exit(2);
            }
        }
    }
    if let Some(limit) = args.limit {
        photos.truncate(limit);
    }

    // Se valida todo antes de gastar cuota: credenciales de cada proveedor y que existan las fotos.
    let mut services = Vec::new();
    for provider in &args.providers {
        match FoodConfig::from_env_with_provider(*provider) {
            Ok(config) => services.push(FoodService::new(build_recognizer(&config), args.timeout)),
            Err(message) => {
                eprintln!("{message}");
                std::process::exit(2);
            }
        }
    }
    let missing: Vec<&str> = photos
        .iter()
        .filter(|p| !args.photos.join(&p.file).exists())
        .map(|p| p.file.as_str())
        .collect();
    if !missing.is_empty() {
        eprintln!(
            "Faltan {} fotos en {}: {}",
            missing.len(),
            args.photos.display(),
            missing.join(", ")
        );
        std::process::exit(2);
    }

    println!(
        "{} fotos × {} proveedores (pausa de {} ms entre llamadas)",
        photos.len(),
        services.len(),
        args.delay.as_millis()
    );
    let mut runs = Vec::new();
    for service in &services {
        for (index, photo) in photos.iter().enumerate() {
            let bytes = match std::fs::read(args.photos.join(&photo.file)) {
                Ok(bytes) => bytes,
                Err(err) => {
                    eprintln!("no se pudo leer {}: {err}", photo.file);
                    std::process::exit(2);
                }
            };
            let started = Instant::now();
            let image = tokio::task::spawn_blocking(move || preprocess::prepare(bytes))
                .await
                .expect("la preparación de la imagen no entra en pánico");
            let outcome = service.estimate(&image).await;
            let latency_ms = started.elapsed().as_millis();
            let run = Run {
                provider: service.provider_name(),
                photo: photo.clone(),
                latency_ms,
                outcome,
            };
            println!(
                "[{}] {}/{} {} → {} en {} ms",
                run.provider,
                index + 1,
                photos.len(),
                photo.file,
                run.status(),
                latency_ms
            );
            if let Err(RecognitionError::Provider(detail)) = &run.outcome {
                eprintln!("    {detail}");
            }
            runs.push(run);
            tokio::time::sleep(args.delay).await;
        }
    }

    let dir = args
        .out
        .join(chrono::Local::now().format("%Y%m%d-%H%M%S").to_string());
    if let Err(err) = std::fs::create_dir_all(&dir) {
        eprintln!("no se pudo crear {}: {err}", dir.display());
        std::process::exit(1);
    }
    let names: Vec<&'static str> = services.iter().map(|s| s.provider_name()).collect();
    let report = summary(&runs, &names);
    for (file, content) in [
        ("resultados.csv", write_csv(&runs)),
        ("resumen.md", report.clone()),
    ] {
        if let Err(err) = std::fs::write(dir.join(file), content) {
            eprintln!("no se pudo escribir {file}: {err}");
            std::process::exit(1);
        }
    }
    println!("\n{report}\nResultados en {}", dir.display());
}
