# `bench/` — banco de pruebas de reconocimiento de alimentos (TEC-02)

Compara los proveedores con **el mismo conjunto de fotos** y **el mismo adaptador** que usará la API
(`src/services/food_recognition/`). El resultado y la decisión se registran en
[`docs/spikes/TEC-02-reconocimiento-de-alimentos.md`](../../docs/spikes/TEC-02-reconocimiento-de-alimentos.md).

```
bench/
├── download_nutrition5k.mjs     # Baja ~20 platillos de Nutrition5k con valores medidos en laboratorio
├── manifest.nutrition5k.csv     # GENERADO por el script anterior
├── manifest.local.csv           # Fotos propias (comida mexicana y fotos sin comida)
├── photos/                      # Fotos (no se versionan)
└── results/<fecha>/             # resultados.csv y resumen.md de cada corrida (no se versionan)
```

## 1. Credenciales (solo en tu equipo)

En `backend/.env` (nunca en el repositorio, en Postman ni en un chat):

| Variable | Proveedor | Dónde se obtiene |
|---|---|---|
| `LOGMEAL_API_TOKEN` | `logmeal` | Token de un **APIUser**. El token *APICompany* del panel solo sirve para crear usuarios: crea uno en el panel (*API User*) o con `POST /v2/users/signUp` usando el token APICompany |
| `GEMINI_API_KEY` (`GEMINI_MODEL` opcional) | `gemini`, `gemini_fatsecret` | Google AI Studio → *API keys* |
| `FATSECRET_CLIENT_ID`, `FATSECRET_CLIENT_SECRET` | `gemini_fatsecret` | platform.fatsecret.com → *My Account*. Registra tu IP pública en *IP Restrictions* o responderá `Invalid IP address` |

`food_bench` revisa que existan las credenciales de cada proveedor antes de gastar cuota y nunca las imprime.

## 2. Fotos

```bash
cd backend
node bench/download_nutrition5k.mjs        # 20 fotos con calorías, proteína y grasa reales
```

Después copia tus fotos a `bench/photos/` y descomenta o agrega sus filas en `manifest.local.csv`:
`file,source,ref_kcal,ref_protein_g,ref_fat_g,expects_food,notes`. Los valores de referencia son opcionales (sin ellos
solo se revisa qué alimentos identifica); las fotos sin comida llevan `expects_food=false`. No uses comas en `notes`.

## 3. Ejecutar

```bash
cd backend
# Prueba rápida (1 foto, sin gastar casi cuota)
cargo run --release --bin food_bench -- --providers gemini --limit 1
# Corrida completa de los tres proveedores
cargo run --release --bin food_bench -- --providers logmeal,gemini,gemini_fatsecret
```

| Opción | Por defecto | Para qué |
|---|---|---|
| `--providers` | `logmeal,gemini,gemini_fatsecret` | Proveedores a comparar (también `simulator`) |
| `--manifest` | los dos de `bench/` | Se puede repetir |
| `--delay-ms` | 4000 | Pausa entre llamadas para no pasar los límites por minuto del plan gratuito |
| `--timeout-secs` | 30 | Tiempo de espera del banco. Es mayor que los 10 s de la API para medir la latencia real |
| `--limit` | — | Solo las primeras N fotos |

**Cuota:** cada foto gasta 1 imagen de LogMeal (prueba gratuita: 200 en total y **20 peticiones al día por APIUser**;
al pasarlas responde `429`) y 1 petición de Gemini por proveedor (2 por foto si corres `gemini` y
`gemini_fatsecret`). Una corrida completa con ~30 fotos no cabe en un día de LogMeal: usa `--limit` o reparte la corrida.

Al terminar se imprime la tabla y quedan `results/<fecha>/resultados.csv` (una fila por proveedor y foto) y
`resumen.md`. Ninguno de los dos contiene credenciales: se pueden compartir para armar el documento del spike.

## Métricas

- **Error** por foto y macro = |estimado − real| / real. *Error promedio* = media de calorías, proteína y grasa por
  foto, promediada en las fotos con referencia. RNF-03: ≤ 20 %.
- **Latencia** de extremo a extremo: preparar la foto (JPEG ≤ 1000 px) + proveedor. RNF-01: el 90 % de las fotos en
  ≤ 10 s (p90).
- **RF-06**: columna `foods` de `resultados.csv` (nombre y gramos de cada alimento).
- **Fotos sin comida**: cuántas responde el proveedor como `not_recognized`; y falsos negativos (comida marcada como no
  reconocida).
