import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';
import '../shared/progress_charts.dart';
import 'progress_view_model.dart';

/// HU-22 — "Mi progreso": gráficas de peso, consumo por día contra la meta y
/// cumplimiento de entrenamiento, por semana o por mes (RF-18). El contenido es
/// [ProgressCharts], compartido con el progreso del cliente (HU-23).
class ProgressView extends StatelessWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProgressViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Mi progreso'),
      body: SafeArea(
        child: CardEdgeClip(
          child: ProgressCharts(
            viewModel: viewModel,
            copy: ProgressCopy.self,
            onRegisterWeight: () => context.push(AppRoutes.weights),
          ),
        ),
      ),
    );
  }
}
