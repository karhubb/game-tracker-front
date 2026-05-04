import 'package:flutter/foundation.dart';

class ApiConfig {
  // URL local para desarrollo
  static const String _defaultUrl = 'http://localhost:8080';
  // URL de Render para producción:
  // static const String _defaultUrl = 'https://game-tracker-backend-a6ec.onrender.com';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    return fromEnv.isNotEmpty ? fromEnv : _defaultUrl;
  }

  static String get apiBaseUrl => '$baseUrl/api';
  static String get authBaseUrl => '$apiBaseUrl/auth';
  static String get gamesBaseUrl => '$apiBaseUrl/juegos';
}