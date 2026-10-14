// TEC-02 — descarga un subconjunto de Nutrition5k (Google Research, CC BY 4.0) para el banco de pruebas.
//
// Cada platillo trae calorías, proteína y grasa medidas en laboratorio (los valores reales contra los que se mide
// el error). Guarda las fotos cenitales en bench/photos/n5k_<dish>.png y escribe bench/manifest.nutrition5k.csv.
//
//   node bench/download_nutrition5k.mjs            # 20 platillos (por defecto)
//   node bench/download_nutrition5k.mjs 30         # otra cantidad
//
// Solo usa Node (fetch nativo, Node 18+). Se ejecuta desde backend/.
import { mkdir, writeFile, access } from "node:fs/promises";
import path from "node:path";

const BASE = "https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset";
const METADATA = [`${BASE}/metadata/dish_metadata_cafe1.csv`, `${BASE}/metadata/dish_metadata_cafe2.csv`];
const WANTED = Number(process.argv[2] ?? 20);
const PHOTOS = path.join("bench", "photos");
const MANIFEST = path.join("bench", "manifest.nutrition5k.csv");

// Generador pseudoaleatorio con semilla fija: la misma selección en cada equipo.
let seed = 20261014;
const random = () => ((seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);

async function text(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} en ${url}`);
  return res.text();
}

// Fila: dish_id, total_calories, total_mass, total_fat, total_carb, total_protein, y por ingrediente
// (id, nombre, gramos, calorías, grasa, carbohidratos, proteína).
function parseDishes(csv) {
  return csv
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => line.split(","))
    .map((c) => ({
      id: c[0],
      kcal: Number(c[1]),
      mass: Number(c[2]),
      fat: Number(c[3]),
      protein: Number(c[5]),
      ingredients: [],
      raw: c,
    }))
    .map((d) => {
      for (let i = 6; i + 6 < d.raw.length; i += 7) d.ingredients.push(d.raw[i + 1].trim());
      delete d.raw;
      return d;
    });
}

const exists = (file) => access(file).then(() => true, () => false);

await mkdir(PHOTOS, { recursive: true });
const dishes = (await Promise.all(METADATA.map(text))).flatMap(parseDishes);
// Platos "de comida completa": al menos 2 ingredientes, 150 kcal y 150 g; sin duplicados.
const candidates = [...new Map(dishes.map((d) => [d.id, d])).values()]
  .filter((d) => d.ingredients.length >= 2 && d.kcal >= 150 && d.mass >= 150 && d.protein > 0 && d.fat > 0)
  .map((d) => ({ d, k: random() }))
  .sort((a, b) => a.k - b.k)
  .map(({ d }) => d);

console.log(`${candidates.length} platillos candidatos; buscando ${WANTED} con foto cenital...`);
const rows = [];
for (const dish of candidates) {
  if (rows.length >= WANTED) break;
  const file = `n5k_${dish.id.replace("dish_", "")}.png`;
  const target = path.join(PHOTOS, file);
  if (!(await exists(target))) {
    const res = await fetch(`${BASE}/imagery/realsense_overhead/${dish.id}/rgb.png`);
    if (!res.ok) continue; // No todos los platillos tienen foto cenital.
    await writeFile(target, Buffer.from(await res.arrayBuffer()));
  }
  const notes = dish.ingredients.join("; ").replace(/,/g, " ");
  rows.push(
    [file, "nutrition5k", dish.kcal.toFixed(1), dish.protein.toFixed(1), dish.fat.toFixed(1), "true", notes].join(","),
  );
  console.log(`  ${rows.length}/${WANTED} ${file} (${dish.kcal.toFixed(0)} kcal) ${notes}`);
}

await writeFile(
  MANIFEST,
  ["file,source,ref_kcal,ref_protein_g,ref_fat_g,expects_food,notes", ...rows].join("\n") + "\n",
);
console.log(`Listo: ${rows.length} fotos en ${PHOTOS} y ${MANIFEST}`);
