# `lib/app/` — composición de la aplicación

| Archivo | Contenido |
|---|---|
| `app.dart` | `MacroFitApp`: `MultiProvider` con los repositorios + `MaterialApp.router` (tema, locale `es_MX`) |
| `dependencies.dart` | `AppDependencies.create`: **raíz de composición**. Único lugar que instancia implementaciones de datos |
| `router.dart` | `createRouter` (rutas y ViewModel por ruta) y `resolveRedirect` (guard de sesión, función pura) |
| `routes.dart` | Constantes de rutas (`AppRoutes`) y conjunto de rutas públicas |
| `navigation/` | Barra inferior persistente (`AppShell` + `AppDock`), transición lateral entre pestañas (`TabTransitions`, `tabPage`) y `PopupRouteObserver` |
| `theme.dart` | `AppTheme.light` / `AppTheme.dark`: `ColorScheme` propio, `TextTheme` (Inter) y temas de componentes. Ver **Guía visual** abajo |

## Dependencias (`dependencies.dart`)

```
publicDio ── AuthRemoteDataSource (register, login, refresh)
          └─ LegalRemoteDataSource (aviso de privacidad)
sessionDio + AuthInterceptor ── SessionRemoteDataSource (me, logout)
                             ├─ ProfileRemoteDataSource (perfil, HU-03)
                             ├─ GoalsRemoteDataSource (metas, HU-05)
                             ├─ MealPhotosRemoteDataSource (foto de comida, HU-06)
                             ├─ MealsRemoteDataSource (estimación HU-07, guardar HU-08, historial, eliminar y fotos HU-09)
                             └─ ClientsRemoteDataSource (lista de clientes HU-24, comidas y fotos HU-25)
SessionLocalDataSource (flutter_secure_storage)
PhotoPickerDataSource (image_picker: cámara y galería, HU-06)
        ↓
AuthRepositoryImpl  ←── interceptor.onSessionExpired
LegalRepositoryImpl
ProfileRepositoryImpl
CoachGoalsRepositoryImpl
MealPhotoRepositoryImpl
MealsRepositoryImpl
ClientsRepositoryImpl
```

- Hay **dos clientes Dio**: uno público y otro con `AuthInterceptor`. Las rutas públicas y la renovación de tokens van
  por el público para evitar bucles.
- Para pruebas, `AppDependencies` se construye directamente con repositorios *fake* (ver `test/app/app_test.dart`).

## Navegación y sesión (`router.dart`)

`GoRouter` escucha al `AuthRepository` (`refreshListenable`). Ante cualquier cambio de sesión evalúa `resolveRedirect`:

| Estado | Rutas permitidas | Cualquier otra ruta |
|---|---|---|
| `AuthUnknown` (leyendo sesión) | `/` (carga) | → `/` |
| `Unauthenticated` | `/login`, `/register`, `/privacy` | → `/login` |
| `Authenticated(user)`, rol `user` **sin perfil** | `/profile/setup` y `/privacy` | → `/profile/setup` |
| `Authenticated(user)`, rol `user` con perfil | `/user`, `/user/progress`, `/user/weights`, `/user/profile`, `/user/meals/photo`, `/user/meals/estimate`, `/user/meals/form`, `/user/meals` y `/privacy` | → `/user` |
| `Authenticated(user)`, rol `coach` | `/coach` y `/privacy` | → `/coach` |

Consecuencias:

- Tras login o registro la app entra a la pantalla de su rol sin que la vista navegue.
- Tras cerrar sesión (o si la sesión expira/es revocada) se va a `/login` y la pila se reemplaza: el botón atrás no
  regresa a pantallas protegidas.
- Un rol nunca puede abrir la pantalla del otro. Las pantallas del coach cuelgan de `/coach` (`AppRoutes.isCoachRoute`).
- HU-03: un usuario sin perfil no llega a `/user` hasta guardar el formulario; al guardarlo,
  `AuthRepository.markProfileCompleted()` cambia la sesión y el router lo lleva a `/user`. Un coach nunca ve el formulario.
- HU-06: `/user/meals/photo` es subruta de `/user`. Si al arrancar hay una foto recuperada (Android cerró la app con la
  cámara abierta), la ruta `/user` redirige a ella; por eso `createRouter` recibe el `MealPhotoRepository`.
- HU-07: `/user/meals/estimate` también es subruta de `/user` y recibe la foto subida en `extra` (`MealPhotoUpload`);
  sin ella (p. ej. al restaurar la ruta) vuelve a `/user`. La pantalla de la foto la abre con `go`, así que atrás
  regresa al inicio y no a la foto ya subida.
- HU-08: `/user/meals/form` es subruta de `/user` y recibe un `MealDraft` en `extra` (sin él vuelve a `/user`). Se abre con
  `push` desde la estimación o desde "Registrar comida".
- HU-09: `/user/meals` ("Mis comidas") es subruta de `/user` y puede recibir el día en `extra` (`DateTime`). Al guardar un
  registro (desde la estimación o el formulario) se abre con `go`: el inicio queda debajo y atrás regresa a él.

### Barra inferior y pestañas (TEC-17)

- `MaterialApp.router(builder:)` envuelve el navegador con `AppShell`, que dibuja **una sola** `AppDock` encima de
  todas las pantallas: no se mueve al cambiar de pantalla.
- Pestañas del usuario: Inicio (`/user`), Comidas (`/user/meals`), Semana (`/user/summary`) y Progreso (`/user/progress`,
  HU-22; desde ahí se registra el peso en `/user/weights`);
  acción principal: escanear (`/user/meals/photo`). Del coach: Inicio (`/coach`), Clientes (`/coach/clients`) y
  Rutinas (`/coach/routines`); acción principal: código de invitación.
- Las pestañas son **subrutas del inicio de su rol** (mismos URL de siempre): la barra las abre con `go`, el inicio queda
  debajo y atrás regresa a él (igual que antes con "Mis comidas", HU-09). La acción principal usa `push`.
- Al cambiar de pestaña desde la barra, la pantalla nueva entra desde la derecha o la izquierda según el orden de las
  pestañas y la anterior sale hacia el otro lado (`tabPage` + `TabTransitions`).
- La barra se oculta en la captura de comida (foto, estimación, formulario), en el constructor de rutinas y el selector
  de ejercicios, mientras hay un diálogo u hoja abierta (`PopupRouteObserver`) y con el teclado visible. Mientras la
  ruta la muestra, `AppShell` suma su alto al margen inferior seguro (`MediaQuery.padding`) para que el contenido y los
  avisos queden por encima.

### Agregar una ruta

1. Constante en `AppRoutes`.
2. `GoRoute` en `createRouter` con su `ChangeNotifierProvider(create: (context) => XViewModel(context.read<Repo>()))`.
3. Si es pública, agrégala a `AppRoutes.public`. Si cuelga de un rol, ajusta `resolveRedirect` y su prueba en
   `test/app/router_test.dart`.

## Guía visual (TEC-17)

Sistema de diseño de la app. Toda pantalla nueva (Sprint 4 en adelante) se construye **solo** con estos tokens, el
tema y los widgets de `core/presentation/widgets`; no se escriben colores, tamaños de letra ni espaciados a mano.

**Dirección:** inspirada en One UI (Samsung Health) con identidad propia. Superficies muy redondeadas sobre negro puro
(oscuro) o gris claro (claro), tipografía protagonista con cifras grandes, tres colores vivos solo para los
macronutrientes, y una barra inferior de vidrio líquido. Pocas líneas y pocos íconos decorativos: la jerarquía la dan
el tamaño del texto, el color de los macros y el espacio.

### Dónde vive cada cosa

| Archivo | Contenido |
|---|---|
| `core/presentation/theme/app_colors.dart` | `AppPalette` (único lugar con valores de color), `AppColors` (extensión del tema: macros, estados, tarjetas destacadas, vidrio) y `AppShadows` |
| `core/presentation/theme/app_tokens.dart` | **Único archivo de medidas**: `AppSpacing`, `AppRadius`, `AppSizes`, `AppGlass`, `AppDurations`, `AppElevation`, `AppMotion`, `AppOpacity` |
| `core/presentation/theme/macro_style.dart` | `Macro` (calorías, proteína, grasa): nombre, ícono y color de cada macro |
| `core/presentation/theme/app_text.dart` | `AppText.numeric` (cifras tabulares) |
| `core/presentation/theme/lucide_icons.dart` | `LucideIcons`: íconos de la app |
| `core/presentation/theme/app_images.dart` | `AppImages`: fondos de las tarjetas destacadas |
| `core/presentation/theme/theme_context.dart` | Atajos `context.colors`, `context.text`, `context.appColors` |
| `app/theme.dart` | `AppTheme`: `ColorScheme` claro y oscuro, `TextTheme` y temas de botones, campos, tarjetas, `AppBar`, `NavigationBar`, diálogos, `SnackBar`, selector de fecha, transiciones… |

### Paleta

| Rol | Claro | Oscuro | Uso |
|---|---|---|---|
| Fondo | `#F2F2F5` | `#000000` | `scaffoldBackgroundColor` |
| Superficie (tarjetas) | `#FFFFFF` | `#17171B` | `colors.surface`, `SurfaceCard` |
| Contenedor | `#EBEBF0` | `#222327` | rellenos, píldora «Hoy», etiquetas |
| Texto | `#111114` | `#F4F4F6` | `onSurface` |
| Texto secundario | `#66666E` | `#9C9CA3` | `onSurfaceVariant` |
| Acción principal | `#111114` (texto blanco) | `#F4F4F6` (texto negro) | `primary`: botones rellenos |
| **Calorías** | `#2F750B` | `#8BD448` | `appColors.calories` (+ `caloriesTrack`) |
| **Proteína** | `#0A7FAA` | `#2CC6EE` | `appColors.protein` (+ `proteinTrack`) |
| **Grasa** | `#8338D6` | `#B76CFF` | `appColors.fat` (+ `fatTrack`) |
| Error | `#D3303B` | `#FF6B6B` | `colors.error` / `errorContainer` |
| Advertencia (exceso de la meta) | `#9A5F00` | `#FFC24D` | `appColors.warning` |
| Acento de marca | `#8BD448` | `#8BD448` | resaltados puntuales (no en la barra inferior) |
| Tarjetas destacadas | verde `#0E6B52→#13795E`, azul `#145DB8→#1A6FC8` | igual | `HighlightCard` (texto blanco) |

Contraste: el texto normal sobre su fondo cumple WCAG AA (≥ 4.5:1) en ambos temas; los colores claros de los macros se
usan para anillos, barras y etiquetas grandes en oscuro, y sus versiones oscuras para texto en claro. Ningún dato
depende solo del color: el resumen semanal marca ✓/✗ y lo repite en texto.

### Tipografía

Inter (SIL OFL, `assets/fonts/inter`), pesos 400/500/600/700. Cifras con `AppText.numeric` (ancho fijo).

| Estilo | Tamaño / peso | Uso |
|---|---|---|
| `displayMedium` / `displaySmall` | 52 / 40, 700 | cifra protagonista (peso, código de invitación) |
| `headlineMedium` / `headlineSmall` | 28 / 24, 700 | saludo, títulos de pantalla, cifras de progreso |
| `titleLarge` / `titleMedium` / `titleSmall` | 20 / 17 / 14 | títulos de tarjeta y de fila |
| `bodyLarge` / `bodyMedium` / `bodySmall` | 16 / 14 / 12.5 | texto, descripciones, ayudas |
| `labelLarge` / `labelMedium` / `labelSmall` | 15 / 13 / 11 | botones, etiquetas, ejes |

### Espaciado, radios y elevación

- Escala de 4: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48`.
- Margen de pantalla `12` y separación entre tarjetas `12` (las tarjetas casi tocan el borde, como One UI);
  relleno interior de tarjeta `20–24`.
- Radios: tarjetas `30`, píldoras (botones, selector de día, barra inferior) totalmente redondas, campos `22`,
  mosaicos `22`, fotos `30`.
- Sin bordes en tarjetas: en claro una sombra suave (`AppShadows.soft`); en oscuro se distinguen por su color.
- Controles de 56 px de alto (mínimo táctil 48).

### Iconografía

[Lucide](https://lucide.dev) (licencia ISC) desde la fuente local `assets/fonts/lucide/lucide.ttf` (paquete
`lucide-static` 1.68.0), con las constantes de `core/presentation/theme/lucide_icons.dart` (`LucideIcons.scan`, …).
Trazo uniforme de 2 px; el acceso activo se distingue por color y por la lente de la barra, no por un ícono relleno.
Cada macro tiene siempre su ícono (`Macro.icon`): `flame` calorías, `egg` proteína, `droplet` grasa. Registrar comida
usa `scan`. Para agregar uno, toma su nombre de `codepoints.json` de `lucide-static` y suma la constante. Las rutinas
(HU-18, en curso) siguen con Material Icons hasta su ajuste.

MacroFit no tiene logotipo: la marca es el nombre en Inter y, como ilustración, los anillos de los tres macros.

### Avatares e imágenes

- **Avatar**: [Blobatar](https://pub.dev/packages/blobatar) generado a partir del **correo** de la persona
  (`AppAvatar(email: …)`), sin fondo: la figura flota sobre la superficie. El mismo correo da siempre el mismo avatar,
  sin subir fotos ni guardar nada.
- **Tarjetas destacadas** (`HighlightCard`): color de marca sobre una foto muy tenue (`AppImages`, `assets/images/`):
  comida en «¿Qué comiste?», entrenamiento en «Mis rutinas», coach con cliente en «Tu coach» y el código de invitación.

### Movimiento y retroalimentación

| Qué | Cómo |
|---|---|
| Presionar | Todo lo tocable se encoge a 0.97 (`PressScale`) y vibra ligeramente (`withHaptic`) |
| Entrar a una pantalla | Las tarjetas aparecen y suben 18 px, escalonadas 60 ms (`FadeSlideIn`) |
| Cambiar de estado | Carga → datos / vacío / error con fundido y ajuste de alto (`StateSwitcher`) |
| Datos | Anillos y barras se llenan desde 0; las cifras cuentan hasta su valor (`CountUp`) |
| Navegación | Transición *fade forwards* en Android y la nativa en iOS; entre pestañas, deslizamiento lateral |
| Bordes al desplazar | El contenido que pasa bajo el encabezado se recorta con la curva de las tarjetas (`CardEdgeClip`) |
| Barra inferior | Vidrio gris casi opaco (`GlassSurface`, también el botón circular de escanear): desenfoque 22 + saturación 1.7, brillo especular y contorno de luz. La lente se desliza con rebote hacia el acceso que se presiona |

Todas las animaciones son finitas (sin temporizadores), así que `pumpAndSettle` funciona en las pruebas.

### Estados

| Estado | Widget | Regla |
|---|---|---|
| Carga | `LoadingState` (indicador + qué se está haciendo) | Con datos previos no se reemplazan: se muestran y se actualizan |
| Vacío | `EmptyState` (ilustración, título, explicación y acción) | Dice por qué está vacío y cómo llenarlo |
| Error | `ErrorState` (pantalla o tarjeta) / `ErrorBanner` | Mensaje en español y **Reintentar**; nunca cierra la app (RNF-11) |
| Éxito | `showAppSnackBar` (aviso con ícono) / `StatusBanner` | Confirma la acción y lleva al siguiente paso |

### Componentes compartidos

Ver la tabla de `lib/core/README.md`. Los principales: `PrimaryButton` (botón principal y sus variantes),
`AppHeader` (encabezado), `SectionCard`/`SurfaceCard` (tarjetas), `EmptyState`, `LoadingState`, `ErrorState`,
`AppTextField`, `ChoicePills`, `PeriodNavigator`, `StatTile`, `MacroRings`, `HighlightCard`, `GlassSurface`.
