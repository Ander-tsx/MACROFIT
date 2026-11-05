import '../../../summary/domain/entities/macro_values.dart';
import '../../domain/entities/progress_report.dart';

/// HU-22 — respuesta de `GET /users/me/progress` (contrato en el README de la
/// feature).
class ProgressModel {
  const ProgressModel(this._json);

  factory ProgressModel.fromJson(Map<String, dynamic> json) =>
      ProgressModel(json);

  final Map<String, dynamic> _json;

  ProgressReport toEntity() => ProgressReport(
    from: _json['from'] as String,
    to: _json['to'] as String,
    weights: [
      for (final item in _list('weights'))
        WeightPoint(
          recordedAt: DateTime.parse(item['recorded_at'] as String),
          weightKg: (item['weight_kg'] as num).toDouble(),
        ),
    ],
    days: [
      for (final item in _list('days'))
        ProgressDay(
          date: item['date'] as String,
          goal: switch (item['goal']) {
            final Map<String, dynamic> goal => _macros(goal),
            _ => null,
          },
          consumed: _macros(item['consumed'] as Map<String, dynamic>),
          goalMet: item['goal_met'] as bool? ?? false,
        ),
    ],
    compliance: [
      for (final item in _list('compliance'))
        WeeklyCompliance(
          weekStart: item['week_start'] as String,
          weekEnd: item['week_end'] as String,
          completedSessions: (item['completed_sessions'] as num).toInt(),
          plannedSessions: (item['planned_sessions'] as num).toInt(),
        ),
    ],
  );

  List<Map<String, dynamic>> _list(String key) => [
    for (final item in (_json[key] as List<dynamic>? ?? const []))
      item as Map<String, dynamic>,
  ];

  static MacroValues _macros(Map<String, dynamic> json) => MacroValues(
    caloriesKcal: (json['calories_kcal'] as num).toDouble(),
    proteinG: (json['protein_g'] as num).toDouble(),
    fatG: (json['fat_g'] as num).toDouble(),
  );
}
