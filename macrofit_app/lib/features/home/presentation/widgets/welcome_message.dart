import 'package:flutter/material.dart';

/// Contenido provisional de las pantallas principales.
class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({
    required this.name,
    required this.roleLabel,
    required this.icon,
    required this.description,
    super.key,
  });

  final String name;
  final String roleLabel;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Hola, $name',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Chip(label: Text(roleLabel)),
            const SizedBox(height: 16),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
