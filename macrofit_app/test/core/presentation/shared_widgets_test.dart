import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/theme.dart';
import 'package:macrofit_app/core/presentation/theme/app_colors.dart';
import 'package:macrofit_app/core/presentation/widgets/app_avatar.dart';
import 'package:macrofit_app/core/presentation/widgets/app_header.dart';
import 'package:macrofit_app/core/presentation/widgets/app_snack_bar.dart';
import 'package:macrofit_app/core/presentation/widgets/choice_pills.dart';
import 'package:macrofit_app/core/presentation/widgets/confirm_dialog.dart';
import 'package:macrofit_app/core/presentation/widgets/count_up_text.dart';
import 'package:macrofit_app/core/presentation/widgets/empty_state.dart';
import 'package:macrofit_app/core/presentation/widgets/error_banner.dart';
import 'package:macrofit_app/core/presentation/widgets/error_state.dart';
import 'package:macrofit_app/core/presentation/widgets/glass_surface.dart';
import 'package:macrofit_app/core/presentation/widgets/loading_state.dart';
import 'package:macrofit_app/core/presentation/widgets/macro_rings.dart';
import 'package:macrofit_app/core/presentation/widgets/period_navigator.dart';
import 'package:macrofit_app/core/presentation/widgets/primary_button.dart';
import 'package:macrofit_app/core/presentation/widgets/section_card.dart';
import 'package:macrofit_app/core/presentation/widgets/stat_tile.dart';

/// Monta [child] con el tema de la app (claro por defecto).
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

void main() {
  group('AppTheme', () {
    test(
      'claro y oscuro usan el ColorScheme propio y los colores de MacroFit',
      () {
        expect(AppTheme.light.colorScheme.brightness, Brightness.light);
        expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
        expect(AppTheme.light.colorScheme.primary, AppPalette.ink);
        expect(AppTheme.dark.scaffoldBackgroundColor, AppPalette.black);
        expect(AppTheme.light.extension<AppColors>(), AppColors.light);
        expect(AppTheme.dark.extension<AppColors>(), AppColors.dark);
        expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Inter');
      },
    );
  });

  group('PrimaryButton (botón principal)', () {
    testWidgets('muestra el texto y llama a la acción al tocarlo', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PrimaryButton(label: 'Guardar', onPressed: () => taps++),
      );

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('mientras carga muestra un indicador y no se puede tocar', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PrimaryButton(
          label: 'Guardar',
          isLoading: true,
          onPressed: () => taps++,
        ),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Guardar'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('sin acción queda deshabilitado', (tester) async {
      await pumpThemed(
        tester,
        const PrimaryButton(label: 'Guardar', onPressed: null),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('cada variante se dibuja en ambos temas', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await pumpThemed(
          tester,
          Column(
            children: [
              for (final variant in AppButtonVariant.values)
                PrimaryButton(
                  label: variant.name,
                  variant: variant,
                  onPressed: () {},
                ),
            ],
          ),
          theme: theme,
        );
        for (final variant in AppButtonVariant.values) {
          expect(find.text(variant.name), findsOneWidget);
        }
      }
    });
  });

  group('Estados', () {
    testWidgets('EmptyState muestra título, mensaje y acciones', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        EmptyState(
          icon: Icons.no_meals_outlined,
          title: 'Sin registros',
          message: 'Registra tu primera comida.',
          actions: [PrimaryButton(label: 'Registrar', onPressed: () {})],
        ),
      );

      expect(find.text('Sin registros'), findsOneWidget);
      expect(find.text('Registra tu primera comida.'), findsOneWidget);
      expect(find.text('Registrar'), findsOneWidget);
    });

    testWidgets('EmptyState compacto también muestra su texto', (tester) async {
      await pumpThemed(
        tester,
        const EmptyState(
          compact: true,
          icon: Icons.flag_outlined,
          title: 'Sin meta',
          message: 'Completa tu perfil.',
        ),
      );
      expect(find.text('Sin meta'), findsOneWidget);
      expect(find.text('Completa tu perfil.'), findsOneWidget);
    });

    testWidgets('LoadingState muestra el indicador y el mensaje', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const LoadingState(message: 'Cargando tus comidas…'),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cargando tus comidas…'), findsOneWidget);
    });

    testWidgets('ErrorState muestra el mensaje y reintenta', (tester) async {
      var retries = 0;
      await pumpThemed(
        tester,
        ErrorState(
          message: 'Sin conexión',
          retryKey: const Key('retry'),
          onRetry: () => retries++,
        ),
      );

      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry')));
      expect(retries, 1);
    });

    testWidgets('ErrorState compacto deja el reintento a la vista', (
      tester,
    ) async {
      var retries = 0;
      await pumpThemed(
        tester,
        SizedBox(
          width: 360,
          child: ErrorState(
            compact: true,
            message: 'Sin conexión',
            retryKey: const Key('retry'),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('retry')));
      expect(retries, 1);
    });

    testWidgets('ErrorBanner muestra el mensaje', (tester) async {
      await pumpThemed(tester, const ErrorBanner(message: 'Algo falló'));
      expect(find.text('Algo falló'), findsOneWidget);
    });
  });

  group('SectionCard (tarjeta de sección)', () {
    testWidgets('muestra título, acción a la derecha y contenido', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        SectionCard(
          title: 'Tu meta diaria',
          trailing: const Text('Calculada'),
          onTap: () => taps++,
          child: const Text('2200 kcal'),
        ),
      );

      expect(find.text('Tu meta diaria'), findsOneWidget);
      expect(find.text('Calculada'), findsOneWidget);
      await tester.tap(find.text('2200 kcal'));
      expect(taps, 1);
    });
  });

  group('AppHeader (encabezado)', () {
    testWidgets('muestra el título y el botón atrás en una pantalla apilada', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('Inicio')),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(appBar: AppHeader(title: 'Mis comidas')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis comidas'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);
    });
  });

  group('Datos', () {
    testWidgets('StatTile une la cifra y la unidad en un solo texto', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 120,
          child: StatTile(
            label: 'Calorías',
            value: '2200',
            unit: 'kcal',
            footer: 'al día',
          ),
        ),
      );
      expect(find.text('2200 kcal'), findsOneWidget);
      expect(find.text('al día'), findsOneWidget);
    });

    testWidgets('AppAvatar dibuja el blobatar del correo en ambos temas', (
      tester,
    ) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await pumpThemed(
          tester,
          const AppAvatar(email: 'ana@macrofit.test'),
          theme: theme,
        );
        expect(find.byType(AppAvatar), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('CountUp termina exactamente en el valor', (tester) async {
      await pumpThemed(
        tester,
        CountUp(
          value: 1050.5,
          builder: (context, value) => Text(value.toStringAsFixed(1)),
        ),
      );
      expect(find.text('1050.5'), findsOneWidget);
    });

    testWidgets('MacroRings se dibuja en ambos temas', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await pumpThemed(
          tester,
          const MacroRings(
            calories: 0.5,
            protein: 1.4,
            fat: 0,
            semanticLabel: 'Anillos',
          ),
          theme: theme,
        );
        expect(find.bySemanticsLabel('Anillos'), findsOneWidget);
      }
    });
  });

  group('Controles', () {
    testWidgets('ChoicePills elige una opción y la deselecciona', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ChoicePills<String>(
                options: const ['Bajar grasa', 'Mantener'],
                selected: selected,
                labelOf: (option) => option,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mantener'));
      await tester.pumpAndSettle();
      expect(selected, 'Mantener');

      await tester.tap(find.text('Mantener'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });

    testWidgets(
      'PeriodNavigator deshabilita "siguiente" sin periodos futuros',
      (tester) async {
        var previous = 0;
        await pumpThemed(
          tester,
          PeriodNavigator(
            label: 'Hoy',
            previousKey: const Key('prev'),
            nextKey: const Key('next'),
            previousTooltip: 'Día anterior',
            nextTooltip: 'Día siguiente',
            onPrevious: () => previous++,
            onNext: null,
          ),
        );

        expect(find.text('Hoy'), findsOneWidget);
        expect(
          tester.widget<IconButton>(find.byKey(const Key('next'))).onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const Key('prev')));
        expect(previous, 1);
      },
    );

    testWidgets('GlassSurface muestra su contenido', (tester) async {
      await pumpThemed(
        tester,
        const GlassSurface(child: Text('Inicio')),
        theme: AppTheme.dark,
      );
      expect(find.text('Inicio'), findsOneWidget);
    });
  });

  group('Diálogo y avisos', () {
    testWidgets(
      'showConfirmDialog devuelve true al confirmar y false al cancelar',
      (tester) async {
        final results = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => results.add(
                    await showConfirmDialog(
                      context: context,
                      title: '¿Eliminar?',
                      message: 'No se puede deshacer.',
                      confirmLabel: 'Eliminar',
                      destructive: true,
                      confirmKey: const Key('confirm'),
                      cancelKey: const Key('cancel'),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(find.text('¿Eliminar?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cancel')));
        await tester.pumpAndSettle();

        expect(results, [true, false]);
      },
    );

    testWidgets('showAppSnackBar muestra el aviso', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSnackBar(
                  ScaffoldMessenger.of(context),
                  'Comida registrada',
                ),
                child: const Text('guardar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Comida registrada'), findsOneWidget);
    });
  });
}
