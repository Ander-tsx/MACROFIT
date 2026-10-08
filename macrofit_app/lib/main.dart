import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencies.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies.create(AppConfig.fromEnvironment());
  // Lee la sesión guardada; mientras tanto el router muestra la carga inicial.
  unawaited(dependencies.authRepository.restoreSession());

  runApp(MacroFitApp(dependencies: dependencies));
}
