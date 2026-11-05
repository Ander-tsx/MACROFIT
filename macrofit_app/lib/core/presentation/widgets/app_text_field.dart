import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Campo de texto de la guía visual: relleno, esquinas de 18 px, ícono a la
/// izquierda y mensajes de ayuda o error debajo.
///
/// La clave del widget identifica al campo en las pruebas (`Key('login_email')`).
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.onChanged,
    this.initialValue,
    this.hint,
    this.icon,
    this.suffixText,
    this.suffixIcon,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.obscureText = false,
    this.enabled = true,
    this.inputFormatters,
    this.style,
    super.key,
  });

  final String label;
  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final String? hint;
  final IconData? icon;

  /// Unidad a la derecha (`kg`, `kcal`).
  final String? suffixText;
  final Widget? suffixIcon;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool obscureText;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  /// Estilo del texto escrito (p. ej. el código de invitación).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      obscureText: obscureText,
      enabled: enabled,
      inputFormatters: inputFormatters,
      style: style ?? context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.lg,
                  end: AppSpacing.sm,
                ),
                child: Icon(icon, size: AppSizes.iconMd),
              ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.control,
          minHeight: AppSizes.control,
        ),
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperMaxLines: 2,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}
