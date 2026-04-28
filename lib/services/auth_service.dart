import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_config.dart';

/// Singleton service para autenticación.
/// Mismo patrón que en Tweeter: gestiona login, logout,
/// almacenamiento de token y datos del usuario.
class AuthService {
  static final AuthService _instance = AuthService._internal();

  String get _authBaseUrl => ApiConfig.authBaseUrl;

  late http.Client _httpClient;
  SharedPreferences? _prefs;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  // Constructor privado — patrón Singleton
  AuthService._internal() {
    _httpClient = http.Client();
  }

  factory AuthService() => _instance;
  static AuthService getInstance() => _instance;

  /// Inicializa SharedPreferences (llamar en main o AuthGate)
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─────────────────────────────────────────────
  //  LOGIN
  // ─────────────────────────────────────────────

  /// Envía credenciales a /api/auth/signin.
  /// Devuelve el [User] con sus roles si tiene éxito.
  Future<User> login(String username, String password) async {
    await _ensureInit();

    final response = await _httpClient.post(
      Uri.parse('$_authBaseUrl/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final token = json['accessToken']?.toString() ?? '';
      if (token.isEmpty) {
        throw Exception('No se recibió token del servidor');
      }

      // El JwtResponse del backend envía: accessToken, id, username, email, roles
      final user = User.fromJson({
        'id': json['id'],
        'username': json['username'],
        'email': json['email'],
        'roles': json['roles'] ?? [],
      });

      await _prefs!.setString(_tokenKey, token);
      await _prefs!.setString(_userKey, jsonEncode(user.toJson()));

      return user;
    }

    throw Exception(
      'Error al iniciar sesión (${response.statusCode}): ${response.body}',
    );
  }

  // ─────────────────────────────────────────────
  //  REGISTRO
  // ─────────────────────────────────────────────

  /// Registra un nuevo usuario en /api/auth/signup.
  /// No inicia sesión automáticamente — el usuario debe loguearse después.
  Future<void> register(String username, String email, String password) async {
    await _ensureInit();

    final response = await _httpClient.post(
      Uri.parse('$_authBaseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      // El backend devuelve {"message": "Error: Username is already taken!"} en 400
      String detail = '';
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        detail = json['message'] ?? response.body;
      } catch (_) {
        detail = response.body;
      }
      throw Exception(detail.isNotEmpty ? detail : 'Error al registrarse');
    }
  }

  // ─────────────────────────────────────────────
  //  TOKEN y SESIÓN
  // ─────────────────────────────────────────────

  /// Devuelve el token guardado (null si no hay sesión).
  String? getToken() => _prefs?.getString(_tokenKey);

  /// Devuelve el [User] guardado en SharedPreferences.
  User? getUser() {
    final raw = _prefs?.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// True si hay token guardado y no está vacío.
  bool isAuthenticated() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  /// Cierra la sesión borrando token y datos del usuario.
  Future<void> logout() async {
    await _ensureInit();
    await _prefs!.remove(_tokenKey);
    await _prefs!.remove(_userKey);
  }

  void dispose() => _httpClient.close();
}
