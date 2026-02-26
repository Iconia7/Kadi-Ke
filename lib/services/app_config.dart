class AppConfig {
  static const bool useProd = true; // Switch this to false for local development

  static const String prodHttpUrl = 'http://5.189.178.132:8080';
  static const String prodWsUrl = 'ws://5.189.178.132:8080';

  static const String devHttpUrl = 'http://localhost:8080';
  static const String devWsUrl = 'ws://localhost:8080';

  static String get baseUrl => useProd ? prodHttpUrl : devHttpUrl;
  static String get wsUrl => useProd ? prodWsUrl : devWsUrl;

  // Game Settings
  static const String appTitle = 'Kadi Ke';
  static const String version = '13.1.0+43';

  /// Resolves an avatar path to a full URL.
  /// Handles both relative paths (/uploads/...) and already-full URLs.
  static String? resolveAvatarUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }
}
