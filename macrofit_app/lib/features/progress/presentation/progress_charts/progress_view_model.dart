import '../../domain/entities/progress_report.dart';
import '../../domain/repositories/progress_repository.dart';
import '../shared/progress_charts_view_model.dart';

/// HU-22 — progreso del usuario: gráficas de peso, macros y cumplimiento en una
/// semana o un mes (RF-18). El periodo, la carga y los errores están en
/// [ProgressChartsViewModel].
class ProgressViewModel extends ProgressChartsViewModel {
  ProgressViewModel({required this._repository, super.clock});

  final ProgressRepository _repository;

  @override
  Future<ProgressReport> fetch({required String from, required String to}) =>
      _repository.getProgress(from: from, to: to);
}
