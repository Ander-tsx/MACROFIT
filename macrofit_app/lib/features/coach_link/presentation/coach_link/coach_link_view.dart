import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import 'coach_link_view_model.dart';

/// HU-13 / HU-14 — pantalla para vincularse y desvincularse de un coach.
class CoachLinkView extends StatelessWidget {
  const CoachLinkView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CoachLinkViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vincular con coach')),
      body: SafeArea(
        child: viewModel.isLoading && viewModel.linkedCoach == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Ingresa el código de invitación que te proporcionó tu coach para recibir seguimiento.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (viewModel.linkedCoach case final coach?) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text('¡Vinculado con éxito!', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('Coach: ${coach.coachName}', style: theme.textTheme.bodyLarge),
                            Text('Correo: ${coach.coachEmail}', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              key: const Key('unlink_coach_button'),
                              onPressed: viewModel.isLoading
                                  ? null
                                  : () => _confirmUnlink(context, viewModel),
                              icon: const Icon(Icons.link_off),
                              label: const Text('Desvincularme'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      key: const Key('invite_code_input'),
                      decoration: const InputDecoration(
                        labelText: 'Código de invitación',
                        hintText: 'Ej. K7P2QX',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: viewModel.updateInviteCode,
                      enabled: !viewModel.isLoading,
                    ),
                    const SizedBox(height: 16),
                    if (viewModel.errorMessage case final message?) ...[
                      ErrorBanner(message: message),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      key: const Key('submit_coach_link'),
                      onPressed: viewModel.isLoading ? null : () => _submit(context, viewModel),
                      child: viewModel.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Vincular coach'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, CoachLinkViewModel viewModel) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await viewModel.linkCoach();
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('¡Vinculación exitosa con el coach!')),
      );
    }
  }

  Future<void> _confirmUnlink(BuildContext context, CoachLinkViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincularme'),
        content: const Text('¿Estás seguro de que deseas desvincularte de tu coach? El coach dejará de ver tus datos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desvincularme'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await viewModel.unlinkCoach();
      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Te has desvinculado del coach.')),
        );
      }
    }
  }
}
