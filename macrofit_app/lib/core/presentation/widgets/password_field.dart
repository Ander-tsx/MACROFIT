import 'package:flutter/material.dart';

import 'app_text_field.dart';
import '../theme/lucide_icons.dart';

/// Campo de contraseña con botón para mostrar u ocultar el texto.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.label,
    required this.onChanged,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    super.key,
  });

  final String label;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      icon: LucideIcons.lock,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      errorText: widget.errorText,
      suffixIcon: IconButton(
        tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}
