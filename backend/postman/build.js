#!/usr/bin/env node
// Une las colecciones de cada módulo en MacroFit.postman_collection.json.
//
//   node postman/build.js           regenera el archivo combinado
//   node postman/build.js --check   falla si el combinado no está al día (para CI / antes del PR)
//
// Sin dependencias: solo Node. Ver postman/README.md.

const fs = require('fs');
const path = require('path');

// Orden de ejecución en el Runner. Un módulo que usa datos de otro va después.
const MODULES = ['core', 'auth','g'];

// Carpetas de cierre: las que terminan así van al final de la colección combinada,
// después de todos los módulos (p. ej. el cierre de sesión, que invalida tokens que
// usan las demás historias). Dentro de su propio módulo deben ser la última carpeta.
const TEARDOWN_SUFFIX = ' · Cierre';
const isTeardown = (folder) => folder.name.endsWith(TEARDOWN_SUFFIX);

const ROOT = __dirname;
const OUTPUT = path.join(ROOT, 'MacroFit.postman_collection.json');
const SCHEMA = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json';

function fail(message) {
  console.error(`✗ ${message}`);
  process.exit(1);
}

function readModule(name) {
  const file = path.join(ROOT, name, `${name}.postman_collection.json`);
  if (!fs.existsSync(file)) fail(`Falta ${path.relative(ROOT, file)} (módulo "${name}" listado en MODULES).`);
  const collection = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (collection.info?.schema !== SCHEMA) fail(`${name}: la colección debe usar el formato v2.1.`);
  if (collection.event?.length || collection.auth) {
    fail(`${name}: no uses scripts ni auth a nivel de colección; ponlos en la carpeta o el request.`);
  }
  const firstTeardown = collection.item.findIndex(isTeardown);
  if (firstTeardown !== -1 && collection.item.slice(firstTeardown).some((f) => !isTeardown(f))) {
    fail(`${name}: las carpetas "...${TEARDOWN_SUFFIX}" deben ir al final del módulo.`);
  }
  return collection;
}

function checkAllModulesListed() {
  const dirs = fs
    .readdirSync(ROOT, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(ROOT, d.name, `${d.name}.postman_collection.json`)))
    .map((d) => d.name);
  const missing = dirs.filter((d) => !MODULES.includes(d));
  if (missing.length) fail(`Módulos sin agregar a MODULES en build.js: ${missing.join(', ')}`);
}

function mergeVariables(modules) {
  const merged = new Map();
  for (const { name, collection } of modules) {
    for (const variable of collection.variable ?? []) {
      const previous = merged.get(variable.key);
      if (previous && previous.variable.value !== variable.value) {
        fail(`La variable "${variable.key}" tiene valores distintos en "${previous.module}" y "${name}".`);
      }
      if (!previous) merged.set(variable.key, { module: name, variable });
    }
  }
  return [...merged.values()].map((v) => v.variable);
}

function build() {
  checkAllModulesListed();
  const modules = MODULES.map((name) => ({ name, collection: readModule(name) }));

  const folderNames = new Set();
  for (const { name, collection } of modules) {
    for (const item of collection.item) {
      if (folderNames.has(item.name)) fail(`Carpeta "${item.name}" repetida (módulo "${name}").`);
      folderNames.add(item.name);
    }
  }

  const combined = {
    info: {
      _postman_id: 'b3e0d869-7c85-4871-9d22-4f6a1c2e0001',
      name: 'MacroFit',
      description:
        'ARCHIVO GENERADO por postman/build.js: no lo edites, modifica postman/<modulo>/ y regenera.\n\n' +
        'API del backend de MacroFit (/api/v1). Una carpeta por historia del backlog (HU-XX / TEC-XX). ' +
        'Requiere el entorno "MacroFit - Local" (postman/MacroFit.postman_environment.json).\n\n' +
        `Módulos (en orden): ${MODULES.join(', ')}. Las carpetas "...${TEARDOWN_SUFFIX}" van al final.`,
      schema: SCHEMA,
    },
    item: [
      ...modules.flatMap(({ collection }) => collection.item.filter((f) => !isTeardown(f))),
      ...modules.flatMap(({ collection }) => collection.item.filter(isTeardown)),
    ],
    variable: mergeVariables(modules),
  };

  return JSON.stringify(combined, null, 2) + '\n';
}

const output = build();
const normalize = (text) => text.replace(/\r\n/g, '\n');

if (process.argv.includes('--check')) {
  const current = fs.existsSync(OUTPUT) ? fs.readFileSync(OUTPUT, 'utf8') : '';
  if (normalize(current) !== output) fail('MacroFit.postman_collection.json no está al día. Ejecuta: node postman/build.js');
  console.log('✓ MacroFit.postman_collection.json está al día.');
} else {
  fs.writeFileSync(OUTPUT, output);
  console.log(`✓ Generado MacroFit.postman_collection.json (${MODULES.join(' → ')}).`);
}
