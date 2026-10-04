import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme.dart';

/// Raíz de la aplicación.
///
/// La navegación por rol y la gestión de estado se definen en TEC-04 y TEC-08;
/// mientras tanto, la app arranca en una pantalla de bienvenida.
class MacroFitApp extends StatelessWidget {
  const MacroFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const WelcomeScreen(),
    );
  }
}

/// Pantalla provisional hasta que exista el flujo de autenticación (HU-01, HU-02).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('MacroFit', style: textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Tu nutrición y tu entrenamiento, en un solo lugar.',
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
