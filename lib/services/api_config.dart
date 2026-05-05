class ApiConfig {
  // Estrategia de entorno: por defecto apuntamos a localhost para desarrollo,
  // y dejamos Render comentado como fallback de producción para volver a activarlo luego.
  // static const String _defaultUrl = 'http://localhost:8080';
  // URL de Render para producción:
  static const String _defaultUrl = 'https://game-tracker-back.onrender.com';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    return fromEnv.isNotEmpty ? fromEnv : _defaultUrl;
  }

  static String get apiBaseUrl => '$baseUrl/api';
  static String get authBaseUrl => '$apiBaseUrl/auth';
  static String get gamesBaseUrl => '$apiBaseUrl/juegos';
}