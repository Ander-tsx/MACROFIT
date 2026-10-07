# Cómo contribuir a MacroFit

## Estrategia de ramas

Usamos un **Git Flow simplificado** con dos ramas permanentes:

| Rama | Para qué | Quién escribe |
|---|---|---|
| `main` | Lo que se entrega. Cada merge es una versión estable y lleva tag (`v0.1.0`). | Solo por PR desde `release/*` o `hotfix/*` |
| `develop` | Integración del sprint. Siempre compila y pasa la CI. | Solo por PR desde ramas de trabajo |

Y ramas de vida corta, que se borran al hacer merge:

| Prefijo | Sale de | Vuelve a | Ejemplo |
|---|---|---|---|
| `feature/` | `develop` | `develop` | `feature/HU-01-registro-con-rol` |
| `fix/` | `develop` | `develop` | `fix/HU-09-borrar-registro` |
| `chore/`, `docs/`, `test/` | `develop` | `develop` | `chore/TEC-01-configuracion-base` |
| `release/` | `develop` | `main` **y** `develop` | `release/0.1.0` |
| `hotfix/` | `main` | `main` **y** `develop` | `hotfix/login-crash` |

El nombre lleva el **ID del backlog** (`HU-XX` o `TEC-XX`) y una descripción corta en kebab-case.

### Flujo de una historia

```bash
git switch develop && git pull
git switch -c feature/HU-01-registro-con-rol
# ...commits...
git push -u origin feature/HU-01-registro-con-rol
# abrir PR hacia develop
```

### Fin de sprint

1. `release/x.y.z` desde `develop`; solo correcciones dentro.
2. Subir `version:` en `macrofit_app/pubspec.yaml`.
3. PR a `main`, merge, tag `vx.y.z` y merge de vuelta a `develop`.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/es/), en español:

```
<tipo>(<ámbito opcional>): <descripción en imperativo>
```

| Tipo | Uso |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un error |
| `refactor` | Cambio interno sin efecto visible |
| `test` | Pruebas |
| `docs` | Documentación |
| `style` | Formato, sin cambios de lógica |
| `chore` | Configuración, dependencias, tareas de mantenimiento |
| `ci` | Pipeline de integración continua |

Ejemplos: `feat(auth): registro con selección de rol`, `fix(nutricion): redondeo de macros`.

## Pull requests

- Se usa la plantilla (`.github/pull_request_template.md`); el título sigue Conventional Commits.
- **Al menos una aprobación** de otra persona del equipo antes del merge.
- La CI (formato, análisis y pruebas) tiene que pasar.
- Merge con **squash** hacia `develop`; merge commit normal en `release/*` → `main`.
- Quien abre el PR lo mergea y borra la rama.

## Antes de subir

```bash
cd macrofit_app
dart format lib test
flutter analyze
flutter test
```

Si tocaste el backend (ver [backend/README.md](backend/README.md#-forma-de-trabajo)):

```bash
cd backend
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

y, si cambiaste pruebas de Postman, `node postman/build.js` para regenerar la colección combinada; esa colección debe pasar sin fallos en el Collection Runner.

## Configuración recomendada del repositorio en GitHub

En *Settings → Branches*, reglas para `main` y `develop`:

- Require a pull request before merging (1 aprobación).
- Require status checks to pass: **Formato, análisis y pruebas**.
- Block force pushes y deletions.
