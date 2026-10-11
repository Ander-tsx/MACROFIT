import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_view_model.dart';

/// Estructura común de las pantallas principales: barra con cierre de sesión.
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget body;

  /// Acciones de la barra antes del botón de cerrar sesión.
  final List<Widget> actions;

  Future<void> _confirmLogout(BuildContext context) async {
    final viewModel = context.read<HomeViewModel>();
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
    final viewModel = context.watch<HomeViewModel>();

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
    );
  }
}
