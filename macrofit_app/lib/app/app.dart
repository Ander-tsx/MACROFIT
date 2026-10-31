import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/platform/share_service.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/clients/domain/repositories/clients_repository.dart';
import '../features/goals/domain/repositories/coach_goals_repository.dart';
import '../features/goals/domain/repositories/goals_repository.dart';
import '../features/invite_code/domain/repositories/invite_code_repository.dart';
import '../features/legal/domain/repositories/legal_repository.dart';
import '../features/meals/domain/repositories/meal_photo_repository.dart';
import '../features/meals/domain/repositories/meals_repository.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/summary/domain/repositories/summary_repository.dart';
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
    mealPhotos: widget.dependencies.mealPhotoRepository,
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
        Provider<ProfileRepository>.value(
          value: dependencies.profileRepository,
        ),
        Provider<GoalsRepository>.value(value: dependencies.goalsRepository),
        Provider<CoachGoalsRepository>.value(
          value: dependencies.coachGoalsRepository,
        ),
        Provider<MealPhotoRepository>.value(
          value: dependencies.mealPhotoRepository,
        ),
        Provider<MealsRepository>.value(value: dependencies.mealsRepository),
        Provider<ClientsRepository>.value(
          value: dependencies.clientsRepository,
        ),
        Provider<InviteCodeRepository>.value(
          value: dependencies.inviteCodeRepository,
        ),
        Provider<SummaryRepository>.value(
          value: dependencies.summaryRepository,
        ),
        Provider<ShareService>.value(value: dependencies.shareService),
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
