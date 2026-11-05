import 'package:flutter/material.dart';

import 'status_banner.dart';

/// Mensaje de error general de un formulario o de una sección (no asociado a un
/// campo). Es un [StatusBanner] con tono de error.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) =>
      StatusBanner(message: message, tone: StatusTone.error);
}
