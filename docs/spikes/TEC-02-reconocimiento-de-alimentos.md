# TEC-02 — Spike: servicio de reconocimiento de alimentos

| Campo | Valor |
|---|---|
| Objetivo | Elegir el servicio que usará el adaptador de HU-07-API (`POST /meals/estimate`) |
| Fecha límite | 14/10/2026 (día 3) |
| Requisitos | RF-06 (calorías, proteína, grasa y alimentos identificados), RNF-01 (90 % de las fotos ≤ 10 s), RNF-03 (error ≤ 20 %), RNF-13 (proveedor detrás de un adaptador) |
| Riesgos | S-05 (preferir planes gratuitos o de estudiante) |
| Estado | ✅ **Completado** el 14/10/2026. Proveedor elegido: **Gemini** (sección 5), aprobado por el líder del proyecto |

## 1. Contendientes

| | LogMeal | Gemini | Gemini + FatSecret |
|---|---|---|---|
| Tipo | API especializada en comida | Modelo multimodal general con salida JSON forzada | Híbrido: Gemini identifica alimentos y gramos, FatSecret da los valores por 100 g |
| Plan usado | **Free**: 0 €, 200 imágenes/mes, 5 usuarios activos, sin soporte | **Gratuito** de Google AI Studio, sin tarjeta | Gemini gratuito + FatSecret **Basic** (gratis, 5 000 llamadas/día) |
| Costo fuera del plan | Planes de pago por cotización/volumen | Pago por tokens: una foto ≈ 560–1 100 tokens de entrada (centésimas de centavo de dólar por foto con un modelo Flash) | Gemini de pago + FatSecret Premier (por cotización; Premier Free para estudiantes requiere solicitud) |
| Límites | 200 imágenes en total en la prueba gratuita y **20 peticiones al día por APIUser** (respuesta `429`, código 114). Se pueden crear más APIUsers, pero el plan permite 5 | Por minuto y por día según AI Studio (cambian; revisar la cuota del proyecto) | Los de Gemini + 5 000 llamadas/día de FatSecret (1 llamada por alimento) |
| Alimentos identificados (RF-06) | Sí: nombre del platillo por región (`recognition_results`) y porción en gramos (`serving_size`) | Sí: `foods[].name` y `grams` (lo pide el esquema) | Sí (los de Gemini) |
| Cómo indica "no hay comida" | `segmentation_results` vacío o `hasNutritionalInfo=false`, según su documentación. **No se pudo comprobar**: se agotó la cuota diaria antes de las fotos sin comida | `recognized=false` en el esquema | Igual que Gemini |
| Datos del alimento | Base propia, 35+ nutrientes | Estimación del modelo | Base de FatSecret (EE. UU. en el plan Basic) |
| Privacidad | Procesa la foto para dar el servicio | **El plan gratuito permite que Google use lo enviado para mejorar sus modelos y que personas lo revisen** | Igual que Gemini |
| Otras condiciones | Token de APIUser | Llave en cabecera | Atribución obligatoria "Powered by fatsecret" y registro de la IP pública del servidor |

FatSecret **no** entra como reconocedor de imágenes porque el plan Basic no incluye esa función (es un complemento de
Premier). Por eso compite como híbrido.

## 2. Método

- **Mismo adaptador que la API:** el banco de pruebas (`backend/src/bin/food_bench.rs`) usa la capa
  `services/food_recognition/` (RNF-13) con cada proveedor. Lo que se mide es lo que recibirá HU-07.
- **Mismo conjunto de fotos para los tres** (`backend/bench/`):
  - ~20 platillos de [Nutrition5k](https://github.com/google-research-datasets/Nutrition5k) (Google Research,
    CC BY 4.0) con calorías, proteína y grasa **medidas en laboratorio**: son la referencia de precisión.
  - 5–8 fotos propias de comida mexicana: revisan RF-06 (qué alimentos identifica) y, si se pesaron, la precisión.
  - 3 fotos sin comida: revisan cómo indica cada servicio que no reconoció comida.
- **Preparación común:** cada foto se reduce a JPEG ≤ 1000 px (lo que pide LogMeal y lo que hará la API).
- **Precisión:** error = |estimado − real| / real por macro; *error promedio* = media de los tres por foto, promediada
  en las fotos con referencia. Cumple RNF-03 si es ≤ 20 %.
- **Latencia:** de extremo a extremo (preparar + proveedor) desde la red de desarrollo. Cumple RNF-01 si el p90 ≤ 10 s.
- **Credenciales:** solo en `backend/.env` del equipo que corre el banco; el banco no las imprime y los resultados no
  las contienen.

## 3. Contrato del adaptador (acordado con HU-07-API)

El simulador y los tres proveedores implementan la misma interfaz (`src/services/food_recognition/mod.rs`):

```rust
#[async_trait]
pub trait FoodRecognizer: Send + Sync {
    fn name(&self) -> &'static str;
    async fn recognize(&self, image: &FoodImage) -> Result<FoodEstimate, RecognitionError>;
}
// Entrada: FoodImage { bytes, mime }            (JPEG ≤ 1000 px, ya preparado)
// Salida:  FoodEstimate { foods: [IdentifiedFood { name, grams?, nutrients }], totals }
//          Nutrients { calories_kcal, protein_g, fat_g }   (1 decimal; totals = suma de foods)
// Errores: NotRecognized | Provider(detalle solo para el log) | Timeout
```

| Error del adaptador | Respuesta de `POST /meals/estimate` (HU-07) |
|---|---|
| `NotRecognized` | `422 FOOD_NOT_RECOGNIZED` → la app ofrece la captura manual (CU-01 flujo 4a) |
| `Provider` | `502 FOOD_PROVIDER_ERROR` |
| `Timeout` (`FOOD_PROVIDER_TIMEOUT_SECS`, máx. 10 s) | `504 FOOD_PROVIDER_TIMEOUT` |

El proveedor se elige con `FOOD_PROVIDER` (`simulator` por defecto); cambiarlo no toca handlers ni rutas.

## 4. Resultados

Corrida del 14/10/2026 desde la red de desarrollo (Windows, `cargo run --release --bin food_bench`). 20 fotos de
Nutrition5k con referencia de laboratorio, 6 fotos propias de comida mexicana y 3 sin comida. Datos por foto:
[`TEC-02/resultados.csv`](TEC-02/resultados.csv).

LogMeal solo procesó 18 de las 29 fotos: las 11 restantes recibieron `429` por el límite de 20 peticiones diarias del
APIUser y se excluyen. Por eso **no hay datos de LogMeal sobre las fotos propias ni sobre las fotos sin comida**.

### Precisión (fotos de Nutrition5k con referencia)

| Proveedor | Fotos | Error kcal (media / mediana) | Error proteína (media / mediana) | Error grasa (media / mediana) | **Error promedio** (media / mediana) | Fotos ≤ 20 % en kcal | Sesgo kcal (mediana) |
|---|---|---|---|---|---|---|---|
| LogMeal | 18 | 129.5 % / 77.8 % | 120.3 % / 70.5 % | 226.6 % / 126.2 % | **158.8 % / 93.9 %** | 2/18 | +77.8 % (sobreestima 14 de 18) |
| Gemini | 20 | 59.8 % / 47.5 % | 59.3 % / 47.1 % | 119.6 % / 51.7 % | **79.6 % / 48.8 %** | 3/20 | +25.8 % |
| Gemini + FatSecret | 20 | 90.6 % / 43.2 % | 85.4 % / 50.2 % | 180.6 % / 60.0 % | **118.9 % / 62.7 %** | 5/20 | +43.3 % |

RNF-03 pide un error ≤ 20 %: **ninguno cumple**, ni con la mediana, que no castiga los valores atípicos.

### Latencia, RF-06 y fotos sin comida

| Proveedor | Latencia p50 | **Latencia p90** (≤ 10 s) | Fotos ≤ 10 s | Alimentos identificados (RF-06) | Fotos sin comida detectadas | Comida marcada como "no reconocida" |
|---|---|---|---|---|---|---|
| LogMeal | 7.2 s | **10.9 s** ❌ | 16/18 | Sí, con porción en gramos | — (sin cuota) | 0/18 |
| Gemini | 6.7 s | **9.6 s** ✅ | 28/29 | Sí, con porción en gramos | **3/3** | 0/26 |
| Gemini + FatSecret | 7.4 s | **9.9 s** ✅ (al límite) | 27/29 | Sí (los de Gemini) | **3/3** | 0/26 |

En la corrida anterior, Gemini tuvo una foto que superó los 30 s. En la API, ese caso respondería `504`.

### Observaciones

- **LogMeal** nombra los platillos con cocina de España ("menestra de verduras", "guiso de chucrut", "patatas bravas"),
  repite alimentos (tres veces "pavo a la plancha" en la misma foto) y usa porciones estándar (835 g de chucrut). Por eso
  sobreestima casi siempre. Es el peor en precisión, no cumple la latencia y su cuota (20 al día) no alcanza para un piloto.
- **Gemini** identifica bien los alimentos visibles en los platos de Nutrition5k. El error viene sobre todo de **la
  porción**: calcula mal los gramos, y la grasa es lo que más falla porque no ve el aceite ni los aderezos. En el total
  de las 20 fotos, sus calorías quedan solo +7.5 % sobre la referencia: falla por foto, no de forma sistemática.
- **Gemini + FatSecret** no mejora a Gemini. La búsqueda por nombre toma a veces un alimento distinto (el tofu dio
  782 kcal contra 158 kcal de referencia), agrega una llamada por alimento y deja la latencia al límite.
- **Comida mexicana (RF-06, sin referencia):**
  - Gemini reconoce arepas, tacos de birria y la hamburguesa con papas y nachos.
  - En el acorazado ve "chicharrón prensado" en lugar de milanesa.
  - En los tacos de pastor confunde la piña con mango (el híbrido sí dice "Tacos al Pastor").
  - El antojito de media noche lo describe como base de pizza con frijoles y huevo.
- **Fotos sin comida:** Gemini y el híbrido responden `recognized=false` en las 3, en unos 2 s.

### Limitaciones del método

- Son 20 fotos con referencia: alcanzan para descartar el cumplimiento de RNF-03 (los errores están lejos del 20 %),
  pero no para estimar el error con precisión.
- Nutrition5k son platos de cafetería de EE. UU. fotografiados desde arriba. Las fotos de la app (comida mexicana,
  ángulo libre) no tienen referencia, así que su precisión no se midió.

## 5. Decisión

- **Proveedor elegido para HU-07: Gemini** (`FOOD_PROVIDER=gemini`). Lo aprobó el líder del proyecto el 14/10/2026.
- **Motivos:**
  - tiene el menor error de los tres (mediana 48.8 %) y en el total de las fotos queda cerca de la referencia (+7.5 %);
  - cumple RNF-01 (p90 9.6 s);
  - devuelve los alimentos identificados con sus gramos (RF-06) y detectó 3 de 3 fotos sin comida (`422 FOOD_NOT_RECOGNIZED`);
  - es gratis sin tarjeta (S-05) y no tiene el tope de 20 peticiones al día de LogMeal.
- **Precisión:** el error medido está por encima del 20 % de RNF-03. El equipo acepta usar Gemini y mejorar la
  precisión cambiando a un modelo más avanzado con `GEMINI_MODEL`. Cambiar de modelo no toca código y se puede volver a
  medir con el mismo banco (`food_bench --providers gemini`). Además, el usuario revisa y corrige los valores antes de
  guardar (HU-08).
- **Descartados:** LogMeal (peor precisión, p90 > 10 s, 20 peticiones al día) y Gemini + FatSecret (más error y más
  latencia que Gemini solo, además de la atribución y el registro de IP).
- **Configuración:** `FOOD_PROVIDER=gemini`, `GEMINI_API_KEY` y `GEMINI_MODEL` como variables de entorno del despliegue.
  El simulador sigue siendo el valor por defecto en desarrollo y en Postman.

## 6. Pendientes

- **Privacidad:** en el plan gratuito, Google puede usar las fotos enviadas para mejorar sus modelos y personas pueden
  revisarlas. Antes de usar fotos de usuarios reales hay que reflejarlo en el aviso de privacidad (TEC-07) o pasar al
  plan de pago, que no entrena con los datos.
- **Latencia:** el p90 de Gemini (9.6 s) está cerca del límite. HU-07 corta a los 10 s con `504 FOOD_PROVIDER_TIMEOUT`,
  y la app debe ofrecer la captura manual en ese caso.
- Las llaves que se usaron en la corrida deben quedar solo en `.env` (rotadas tras compartirse en un chat el 14/10).
