import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/legal/domain/repositories/legal_repository.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

/// Raíz de la aplicación: inyecta los repositorios y monta el router.
class MacroFitApp extends StatefulWidget {
  const MacroFitApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<MacroFitApp> createState() => _MacroFitAppState();
}

class _MacroFitAppState extends State<MacroFitApp> {
  late final GoRouter _router = createRouter(
    widget.dependencies.authRepository,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthRepository>.value(
          value: dependencies.authRepository,
        ),
        Provider<LegalRepository>.value(value: dependencies.legalRepository),
      ],
      child: MaterialApp.router(
        title: 'MacroFit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      ),
    );
  }
}
