# `lib/features/` — una carpeta por funcionalidad

Cada feature agrupa sus tres capas. Las features no importan la capa de **datos** ni la **presentación** de otra
feature; si necesitan algo de otra, usan su **dominio** (p. ej. `home` usa `auth/domain/repositories/auth_repository.dart`).

| Feature | Historias | README |
|---|---|---|
| `auth/` | HU-01 registro, HU-02 inicio/cierre/persistencia de sesión | [auth/README.md](auth/README.md) |
| `legal/` | TEC-07 aviso de privacidad | [legal/README.md](legal/README.md) |
| `profile/` | HU-03 perfil inicial (alta obligatoria) y edición | [profile/README.md](profile/README.md) |
| `home/` | Pantallas principales de usuario y coach | [home/README.md](home/README.md) |

## Plantilla

```
features/<feature>/
├── domain/
│   ├── entities/            # Clases inmutables del negocio (sin JSON)
│   ├── repositories/        # Contratos: abstract class / abstract interface class XRepository
│   └── validators/          # Reglas puras (si la feature tiene formularios)
├── data/
│   ├── models/              # XModel con fromJson/toJson/toEntity (nombres de la API en snake_case)
│   ├── datasources/         # XRemoteDataSource (Dio + guardApiCall), XLocalDataSource
│   └── repositories/        # XRepositoryImpl implements XRepository
├── presentation/
│   └── <pantalla>/
│       ├── <pantalla>_view.dart        # StatelessWidget; context.watch<XViewModel>()
│       └── <pantalla>_view_model.dart  # extends ViewModel
└── README.md                # Historias, flujo, endpoints usados, decisiones
```

Una feature puede omitir capas que aún no necesita (hoy `home` solo tiene presentación), pero no mezclar capas.

## Convenciones

- Archivos en `snake_case`, un tipo público principal por archivo.
- Entidades del dominio con `==`/`hashCode` si se comparan en pruebas.
- Los repositorios que representan **estado de la app** (como la sesión) extienden `ChangeNotifier`; el resto es
  `abstract interface class`.
- Los ViewModels reciben sus repositorios por constructor (los inyecta la ruta), nunca los buscan solos.
- Las vistas no contienen lógica: validan, llaman y deciden en el ViewModel.
- Claves (`Key('feature_campo')`) en campos y botones principales para las pruebas de widgets.
