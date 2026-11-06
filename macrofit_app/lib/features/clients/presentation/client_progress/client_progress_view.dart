import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
// Excepción documentada a la regla de capas (README de `clients`): HU-23 reutiliza
// las gráficas de HU-22 en lugar de duplicarlas.
import '../../../progress/presentation/shared/progress_charts.dart';
import 'client_progress_view_model.dart';

/// HU-23 — progreso histórico de un cliente: peso, consumo por día contra la meta
/// y cumplimiento de entrenamiento, por semana o por mes (RF-25). Solo lectura:
/// no hay botones para registrar ni editar datos.
///
/// Si el cliente ya no está vinculado, **Volver a mis clientes** cierra esta
/// pantalla con `true` y el detalle también se cierra para regresar a la lista.
class ClientProgressView extends StatelessWidget {
  const ClientProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientProgressViewModel>();

    return Scaffold(
      appBar: AppHeader(title: 'Progreso de ${viewModel.client.name}'),
      body: SafeArea(
        child: viewModel.isUnlinked
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ErrorBanner(
                        key: Key('client_progress_unlinked'),
                        message: 'Este cliente ya no está vinculado contigo.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        key: const Key('client_progress_back'),
                        label: 'Volver a mis clientes',
                        icon: LucideIcons.arrowLeft,
                        onPressed: () => context.pop(true),
                      ),
                    ],
                  ),
                ),
              )
            : CardEdgeClip(
                child: ProgressCharts(
                  viewModel: viewModel,
                  copy: ProgressCopy.client,
                  keyPrefix: 'client_progress',
                ),
              ),
      ),
    );
  }
}
