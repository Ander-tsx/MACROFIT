import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import 'privacy_notice_view_model.dart';

/// Aviso de privacidad completo (se abre desde el registro).
class PrivacyNoticeView extends StatelessWidget {
  const PrivacyNoticeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PrivacyNoticeViewModel>();
    final notice = viewModel.notice;

    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de privacidad')),
      body: SafeArea(
        child: switch ((viewModel.isLoading, notice, viewModel.error)) {
          (true, _, _) => const Center(child: CircularProgressIndicator()),
          (_, final notice?, _) => Markdown(
            key: const Key('privacy_notice_content'),
            data: notice.content,
            padding: const EdgeInsets.all(16),
          ),
          (_, _, final error?) => _LoadError(
            message: error,
            onRetry: viewModel.load,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
