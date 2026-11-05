import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'press_scale.dart';
import '../theme/lucide_icons.dart';

/// Campo de fecha: se ve como un campo de texto y abre el selector al tocarlo.
/// La clave del widget identifica al campo en las pruebas.
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
    super.key,
  });

  final String label;

  /// Fecha ya formateada (`dd/mm/aaaa`); `null` si no se ha elegido.
  final String? value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return PressScale(
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: withHaptic(onTap, selection: true),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Padding(
              padding: EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                end: AppSpacing.sm,
              ),
              child: Icon(LucideIcons.calendar, size: AppSizes.iconMd),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: AppSizes.control,
              minHeight: AppSizes.control,
            ),
            suffixIcon: const Icon(LucideIcons.chevronDown),
            errorText: errorText,
            errorMaxLines: 2,
          ),
          child: Text(value ?? '', style: context.text.bodyLarge),
        ),
      ),
    );
  }
}
