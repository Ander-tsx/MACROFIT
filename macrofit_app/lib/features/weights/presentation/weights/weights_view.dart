import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import 'weights_view_model.dart';

/// HU-21 — formulario de registro e historial de peso.
class WeightsView extends StatelessWidget {
  const WeightsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WeightsViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Registro de peso')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Registrar nuevo peso', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (viewModel.generalError case final message?) ...[
              ErrorBanner(message: message),
              const SizedBox(height: 16),
            ],
            TextField(
              key: const Key('weight_input'),
              decoration: InputDecoration(
                labelText: 'Peso (kg)',
                hintText: 'Ej. 75.5',
                border: const OutlineInputBorder(),
                errorText: viewModel.fieldError('weight_kg'),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: viewModel.setWeightInput,
              enabled: !viewModel.isSubmitting,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('submit_weight'),
              onPressed: viewModel.isSubmitting
                  ? null
                  : () => _submit(context, viewModel),
              child: viewModel.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Registrar peso'),
            ),
            const SizedBox(height: 32),
            Text('Historial de peso', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (viewModel.isLoading && viewModel.weights.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (viewModel.loadError case final message?)
              Column(
                children: [
                  ErrorBanner(message: message),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('weights_retry'),
                    onPressed: viewModel.load,
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            else if (viewModel.weights.isEmpty)
              const Text('Aún no tienes registros de peso.')
            else
              ...viewModel.weights.map(
                (entry) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.monitor_weight),
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(
                      _formatDate(entry.recordedAt.toLocal()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WeightsViewModel viewModel) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await viewModel.registerWeight();
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Peso registrado correctamente')),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
