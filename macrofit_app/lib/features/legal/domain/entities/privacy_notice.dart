/// Aviso de privacidad vigente (TEC-07).
class PrivacyNotice {
  const PrivacyNotice({required this.version, required this.content});

  final String version;

  /// Texto completo en Markdown.
  final String content;
}
