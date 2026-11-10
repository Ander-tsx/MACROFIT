import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/user_routine.dart';
import 'my_routine_texts.dart';

/// Sesión de una rutina con sus ejercicios, series, repeticiones y descanso
/// (RF-15). [footer] va debajo de los ejercicios (HU-17: marcar completada).
class SessionPlanCard extends StatelessWidget {
  const SessionPlanCard({required this.session, this.footer, super.key});

  final RoutineSessionPlan session;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final footer = this.footer;
    return SectionCard(
      key: Key('routine_session_${session.number}'),
      title: session.name,
      subtitle: session.exercises.length == 1
          ? '1 ejercicio'
          : '${session.exercises.length} ejercicios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, exercise) in session.exercises.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.xxl),
            Text(exercise.name, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${muscleGroupText(exercise.muscleGroup)} · '
              '${exerciseVolumeText(exercise)}',
              style: text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.xl),
            footer,
          ],
        ],
      ),
    );
  }
}
