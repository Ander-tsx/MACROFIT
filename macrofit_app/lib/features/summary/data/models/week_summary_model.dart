import '../../domain/entities/week_summary.dart';
import 'day_summary_model.dart';

class WeekSummaryModel extends WeekSummary {
  const WeekSummaryModel({
    required super.start,
    required super.end,
    required super.days,
    required super.average,
    required super.goalMetDays,
  });

  factory WeekSummaryModel.fromJson(Map<String, dynamic> json) {
    return WeekSummaryModel(
      start: json['start'] as String,
      end: json['end'] as String,
      days: [
        for (final day in json['days'] as List<dynamic>)
          DaySummaryModel.fromJson(day as Map<String, dynamic>),
      ],
      average: macroValuesFromJson(json['average'] as Map<String, dynamic>),
      goalMetDays: (json['goal_met_days'] as num).toInt(),
    );
  }
}
