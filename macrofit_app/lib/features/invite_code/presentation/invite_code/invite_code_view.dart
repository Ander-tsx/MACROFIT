import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import 'invite_code_view_model.dart';

/// HU-12 — código de invitación del coach con copiar, compartir y regenerar.
class InviteCodeView extends StatelessWidget {
  const InviteCodeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InviteCodeViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi código de invitación')),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, InviteCodeViewModel viewModel) {
    final code = viewModel.code;
    if (code == null) {
      if (viewModel.loadError case final message?) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorBanner(message: message),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('invite_code_retry'),
                  onPressed: viewModel.isLoading ? null : viewModel.load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Comparte este código con tus clientes para que se vinculen contigo '
          'desde su app.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Text('Tu código', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SelectableText(
                  code,
                  key: const Key('invite_code_value'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (viewModel.isRegenerating) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (viewModel.regenerateError case final message?) ...[
          ErrorBanner(message: message),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('invite_code_copy'),
                onPressed: viewModel.canUseCode
                    ? () => _copy(context, viewModel)
                    : null,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              // Builder: el contexto del botón da el área donde anclar la hoja en iPad.
              child: Builder(
                builder: (buttonContext) => FilledButton.icon(
                  key: const Key('invite_code_share'),
                  onPressed: viewModel.canUseCode
                      ? () => viewModel.share(origin: _originOf(buttonContext))
                      : null,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Si regeneras el código, el anterior deja de funcionar. Tus clientes '
          'ya vinculados no se ven afectados.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            key: const Key('invite_code_regenerate'),
            onPressed: viewModel.canUseCode
                ? () => _regenerate(context, viewModel)
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerar código'),
          ),
        ),
      ],
    );
  }

  Future<void> _copy(
    BuildContext context,
    InviteCodeViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await viewModel.copy()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Código copiado al portapapeles')),
        );
    }
  }

  Future<void> _regenerate(
    BuildContext context,
    InviteCodeViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await viewModel.regenerate(
      () => _confirmRegenerate(context, viewModel.code!),
    );
    if (changed) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Código nuevo generado. El anterior ya no funciona.'),
          ),
        );
    }
  }

  Future<bool> _confirmRegenerate(BuildContext context, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerar código'),
        content: Text(
          'Se generará un código nuevo y el actual ($code) dejará de funcionar. '
          'Quien aún no se haya vinculado necesitará el código nuevo.',
        ),
        actions: [
          TextButton(
            key: const Key('invite_code_regenerate_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('invite_code_regenerate_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Área del botón en coordenadas globales.
  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
