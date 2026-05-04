import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import '../models/reaction.dart';
import 'auth_service.dart';
import 'api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.gamesBaseUrl;
  static String get adminUsersUrl => '${ApiConfig.apiBaseUrl}/admin/users';
  static String get reactionTypesUrl => '${ApiConfig.apiBaseUrl}/reactions';
  static String get noteReactionsUrl => '${ApiConfig.apiBaseUrl}/notes/reactions';

  final AuthService _authService = AuthService();

  /// Construye los headers con el Bearer token si hay sesión activa.
  /// Mismo patrón que _getHeaders() en TweetService de Tweeter.
  Map<String, String> _getHeaders({bool withBody = false}) {
    final headers = <String, String>{};
    if (withBody) headers['Content-Type'] = 'application/json';

    final token = _authService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── GET: Obtener todos ───────────────────────────────────────────────────
  Future<List<Game>> fetchGames() async {
    await _authService.init();
    final response = await http.get(Uri.parse(baseUrl), headers: _getHeaders());
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((j) => Game.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Error al cargar juegos (${response.statusCode})');
  }

  // ── POST: Crear nuevo ────────────────────────────────────────────────────
  Future<void> createGame(Game game) async {
    await _authService.init();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: _getHeaders(withBody: true),
      body: json.encode(game.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al crear el juego (${response.statusCode})');
    }
  }

  // ── PUT: Actualizar juego ────────────────────────────────────────────────
  Future<void> updateGame(int id, Game game) async {
    await _authService.init();
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: _getHeaders(withBody: true),
      body: json.encode(game.toJson()),
    );
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception('Error al actualizar el juego (${response.statusCode})');
    }
  }

  // ── PUT: Editar nota ─────────────────────────────────────────────────────
  Future<void> updateGameNote(int gameId, int noteIndex, GameNote note) async {
    await _authService.init();
    final response = await http.put(
      Uri.parse('$baseUrl/$gameId/notes/$noteIndex'),
      headers: _getHeaders(withBody: true),
      body: json.encode(note.toJson()),
    );
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception('Error al editar la nota (${response.statusCode})');
    }
  }

  // ── POST: Agregar nota ────────────────────────────────────────────────────
  Future<void> addGameNote(int gameId, GameNote note) async {
    await _authService.init();
    final response = await http.post(
      Uri.parse('$baseUrl/$gameId/notes'),
      headers: _getHeaders(withBody: true),
      body: json.encode(note.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al crear la nota (${response.statusCode})');
    }
  }

  // ── DELETE: Borrar nota ──────────────────────────────────────────────────
  Future<void> deleteGameNote(int gameId, int noteIndex) async {
    await _authService.init();
    final response = await http.delete(
      Uri.parse('$baseUrl/$gameId/notes/$noteIndex'),
      headers: _getHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al borrar la nota (${response.statusCode})');
    }
  }

  // ── DELETE: Borrar juego ─────────────────────────────────────────────────
  Future<void> deleteGame(int id) async {
    await _authService.init();
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: _getHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al eliminar el juego (${response.statusCode})');
    }
  }

  Future<List<ReactionType>> fetchReactionTypes() async {
    await _authService.init();
    final response = await http.get(
      Uri.parse(reactionTypesUrl),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(ReactionType.fromJson)
          .toList();
    }

    throw Exception('Error al cargar reacciones (${response.statusCode})');
  }

  Future<NoteReactionSummary> fetchNoteReactionSummary(
    int gameId,
    int noteIndex,
  ) async {
    await _authService.init();
    final response = await http.get(
      Uri.parse('$noteReactionsUrl/games/$gameId/notes/$noteIndex'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return NoteReactionSummary.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(
      'Error al cargar el resumen de reacciones (${response.statusCode})',
    );
  }

  Future<void> reactToNote({
    required int gameId,
    required int noteIndex,
    required int reactionId,
  }) async {
    await _authService.init();
    final response = await http.post(
      Uri.parse('$noteReactionsUrl/games/$gameId/notes/$noteIndex'),
      headers: _getHeaders(withBody: true),
      body: json.encode({'reactionId': reactionId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al reaccionar a la opinión (${response.statusCode})',
      );
    }
  }

  Future<void> removeNoteReaction(int gameId, int noteIndex) async {
    await _authService.init();
    final response = await http.delete(
      Uri.parse('$noteReactionsUrl/games/$gameId/notes/$noteIndex'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al quitar la reacción (${response.statusCode})');
    }
  }

  // ── ADMIN: Crear usuario con rol ────────────────────────────────────────
  Future<void> createUserByAdmin({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    await _authService.init();
    final response = await http.post(
      Uri.parse(adminUsersUrl),
      headers: _getHeaders(withBody: true),
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        'roles': [role],
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al crear usuario (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ── ADMIN: Listar usuarios ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchUsersForAdmin() async {
    await _authService.init();
    final response = await http.get(
      Uri.parse(adminUsersUrl),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(
            (user) => {
              'id': user['id'],
              'username': user['username'],
              'email': user['email'],
              'roles': user['roles'] ?? [],
            },
          )
          .toList();
    }

    throw Exception('Error al listar usuarios (${response.statusCode})');
  }

  // ── ADMIN: Eliminar usuario ─────────────────────────────────────────────
  Future<void> deleteUserByAdmin(int userId) async {
    await _authService.init();
    final response = await http.delete(
      Uri.parse('$adminUsersUrl/$userId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al eliminar usuario (${response.statusCode})');
    }
  }
}
