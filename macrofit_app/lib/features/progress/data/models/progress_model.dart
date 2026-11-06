import '../../../summary/domain/entities/macro_values.dart';
import '../../domain/entities/progress_report.dart';
import '../../domain/usecases/goal_rules.dart';

/// HU-22 / HU-23 — respuesta `ProgressResponse` de `GET /users/me/progress` y de
/// `GET /coach/clients/{clientId}/progress` (contrato en el README de la feature).
///
/// El backend responde `weights`, `daily` (un `DailySummary` por día, con la meta en
/// `goal.totals`) y `compliance` (`start`, `end`, `training_days`,
/// `completed_sessions`). No incluye `from`/`to` ni `goal_met`: el periodo es el
/// pedido y el cumplimiento de calorías se calcula con la misma regla que HU-11.
///
/// También acepta las claves del contrato provisional de HU-22 (`days`,
/// `week_start`, `planned_sessions`, `goal_met`, meta plana o `null`).
class ProgressModel {
  const ProgressModel(this._json);

  factory ProgressModel.fromJson(Map<String, dynamic> json) =>
      ProgressModel(json);

  final Map<String, dynamic> _json;

  /// [from] y [to] son el periodo pedido; se usan si la respuesta no los trae.
  ProgressReport toEntity({required String from, required String to}) =>
      ProgressReport(
        from: _json['from'] as String? ?? from,
        to: _json['to'] as String? ?? to,
        weights: [
          for (final item in _list('weights'))
            WeightPoint(
              recordedAt: DateTime.parse(item['recorded_at'] as String),
              weightKg: (item['weight_kg'] as num).toDouble(),
            ),
        ],
        days: [for (final item in _list('daily', 'days')) _day(item)],
        compliance: [
          for (final item in _list('compliance'))
            WeeklyCompliance(
              weekStart: (item['start'] ?? item['week_start']) as String,
              weekEnd: (item['end'] ?? item['week_end']) as String,
              completedSessions: (item['completed_sessions'] as num).toInt(),
              plannedSessions:
                  ((item['training_days'] ?? item['planned_sessions']) as num)
                      .toInt(),
            ),
        ],
      );

  static ProgressDay _day(Map<String, dynamic> item) {
    final goal = switch (item['goal']) {
      // Contrato real: `{ "source": ..., "totals": { ... } }`.
      {'totals': final Map<String, dynamic> totals} => _macros(totals),
      // Contrato provisional: meta plana.
      final Map<String, dynamic> flat => _macros(flat),
      _ => null,
    };
    final consumed = _macros(item['consumed'] as Map<String, dynamic>);
    return ProgressDay(
      date: item['date'] as String,
      goal: goal,
      consumed: consumed,
      goalMet:
          item['goal_met'] as bool? ??
          withinGoal(consumed.caloriesKcal, goal?.caloriesKcal),
    );
  }

  /// Lista de la primera clave presente; ausente = vacía.
  List<Map<String, dynamic>> _list(String key, [String? fallback]) => [
    for (final item
        in (_json[key] ?? _json[fallback]) as List<dynamic>? ?? const [])
      item as Map<String, dynamic>,
  ];

  static MacroValues _macros(Map<String, dynamic> json) => MacroValues(
    caloriesKcal: (json['calories_kcal'] as num).toDouble(),
    proteinG: (json['protein_g'] as num).toDouble(),
    fatG: (json['fat_g'] as num).toDouble(),
  );
}
