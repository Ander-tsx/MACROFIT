import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencies.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies.create(AppConfig.fromEnvironment());
  // Mientras tanto el router muestra la carga inicial.
  unawaited(() async {
    // HU-06: primero la foto que se perdió si Android cerró la app con la
    // cámara abierta, para que el router ya la vea al decidir la pantalla.
    await dependencies.mealPhotoRepository.recoverLostPhoto();
    // Lee la sesión guardada.
    await dependencies.authRepository.restoreSession();
  }());

  runApp(MacroFitApp(dependencies: dependencies));
}
