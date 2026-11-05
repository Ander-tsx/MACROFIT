import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import 'privacy_notice_view_model.dart';

/// Aviso de privacidad completo (se abre desde el registro).
class PrivacyNoticeView extends StatelessWidget {
  const PrivacyNoticeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PrivacyNoticeViewModel>();
    final notice = viewModel.notice;

    return Scaffold(
      appBar: const AppHeader(title: 'Aviso de privacidad'),
      body: SafeArea(
        child: switch ((viewModel.isLoading, notice, viewModel.error)) {
          (true, _, _) => const LoadingState(
            message: 'Cargando el aviso de privacidad…',
          ),
          (_, final notice?, _) => Markdown(
            key: const Key('privacy_notice_content'),
            data: notice.content,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.huge,
            ),
            styleSheet: _styleSheet(context),
          ),
          (_, _, final error?) => ErrorState(
            message: error,
            onRetry: viewModel.load,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  /// Markdown con la tipografía y los colores de la guía visual.
  static MarkdownStyleSheet _styleSheet(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return MarkdownStyleSheet.fromTheme(context.theme).copyWith(
      h1: text.headlineSmall,
      h2: text.titleLarge,
      h3: text.titleMedium,
      p: text.bodyMedium,
      listBullet: text.bodyMedium,
      strong: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      h1Padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      h2Padding: const EdgeInsets.only(top: AppSpacing.lg),
      blockSpacing: AppSpacing.md,
      a: text.bodyMedium?.copyWith(
        color: colors.secondary,
        decoration: TextDecoration.underline,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppRadius.mdAll,
      ),
      blockquotePadding: AppSpacing.cardPadding,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      tableBorder: TableBorder.all(color: colors.outlineVariant),
      tableHead: text.titleSmall,
      tableBody: text.bodySmall?.copyWith(color: colors.onSurface),
      tableCellsPadding: const EdgeInsets.all(AppSpacing.sm),
    );
  }
}
