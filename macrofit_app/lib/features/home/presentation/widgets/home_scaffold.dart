import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_view_model.dart';

/// Estructura común de las pantallas principales: barra con cierre de sesión.
///
/// [T] es el ViewModel que la ruta inyecta (`HomeViewModel` o una subclase, como
/// `UserHomeViewModel`); si no se indica, es `HomeViewModel`.
class HomeScaffold<T extends HomeViewModel> extends StatelessWidget {
  const HomeScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final Widget body;

  /// Acciones de la barra antes del botón de cerrar sesión.
  final List<Widget> actions;

  /// Acción principal de la pantalla (p. ej. "Registrar comida", HU-06).
  final Widget? floatingActionButton;

  Future<void> _confirmLogout(BuildContext context) async {
    final viewModel = context.read<T>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres cerrar tu sesión en este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('logout_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await viewModel.logout();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<T>();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          IconButton(
            key: const Key('logout_button'),
            tooltip: 'Cerrar sesión',
            icon: viewModel.isLoggingOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            onPressed: viewModel.isLoggingOut
                ? null
                : () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
