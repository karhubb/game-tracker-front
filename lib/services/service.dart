import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import '../models/reaction.dart';
import 'auth_service.dart';
import 'api_config.dart';
import 'reaction_api_service.dart';

class ApiService {
  static String get baseUrl => ApiConfig.gamesBaseUrl;
  static String get adminUsersUrl => '${ApiConfig.apiBaseUrl}/admin/users';

  final AuthService _authService = AuthService();
  late final ReactionApiService _reactionApi = ReactionApiService(_authService);

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

  Future<http.Response> _sendAuthorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool withBody = false,
  }) async {
    await _authService.init();
    return request(_getHeaders(withBody: withBody));
  }

  void _ensureSuccess(
    http.Response response,
    Set<int> acceptedStatusCodes,
    String errorMessage,
  ) {
    if (!acceptedStatusCodes.contains(response.statusCode)) {
      throw Exception('$errorMessage (${response.statusCode})');
    }
  }

  // ── GET: Obtener todos ───────────────────────────────────────────────────
  Future<List<Game>> fetchGames() async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.get(Uri.parse(baseUrl), headers: headers),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((j) => Game.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Error al cargar juegos (${response.statusCode})');
  }

  // ── POST: Crear nuevo ────────────────────────────────────────────────────
  Future<void> createGame(Game game) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(game.toJson()),
      ),
      withBody: true,
    );
    _ensureSuccess(response, {200, 201}, 'Error al crear el juego');
  }

  // ── PUT: Actualizar juego ────────────────────────────────────────────────
  Future<void> updateGame(int id, Game game) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.put(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
        body: json.encode(game.toJson()),
      ),
      withBody: true,
    );
    _ensureSuccess(response, {200, 201, 204}, 'Error al actualizar el juego');
  }

  // ── PUT: Editar nota ─────────────────────────────────────────────────────
  Future<void> updateGameNote(int gameId, int noteIndex, GameNote note) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.put(
        Uri.parse('$baseUrl/$gameId/notes/$noteIndex'),
        headers: headers,
        body: json.encode(note.toJson()),
      ),
      withBody: true,
    );
    _ensureSuccess(response, {200, 201, 204}, 'Error al editar la nota');
  }

  // ── POST: Agregar nota ────────────────────────────────────────────────────
  Future<void> addGameNote(int gameId, GameNote note) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.post(
        Uri.parse('$baseUrl/$gameId/notes'),
        headers: headers,
        body: json.encode(note.toJson()),
      ),
      withBody: true,
    );
    _ensureSuccess(response, {200, 201}, 'Error al crear la nota');
  }

  // ── DELETE: Borrar nota ──────────────────────────────────────────────────
  /// Delete a game note with specified strategy.
  /// [strategy] can be 'SOFT_DELETE', 'HARD_DELETE', or 'CASCADE_DELETE' (admin-only)
  Future<Game> deleteGameNote(int gameId, int noteIndex, {String strategy = 'SOFT_DELETE'}) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.delete(
        Uri.parse('$baseUrl/$gameId/notes/$noteIndex?strategy=$strategy'),
        headers: headers,
      ),
    );
    _ensureSuccess(response, {200, 204}, 'Error al borrar la nota');
    if (response.body.isEmpty) {
      throw Exception('Error al borrar la nota: respuesta vacía');
    }

    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  // ── DELETE: Borrar juego ─────────────────────────────────────────────────
  Future<void> deleteGame(int id) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      ),
    );
    _ensureSuccess(response, {200, 204}, 'Error al eliminar el juego');
  }

  Future<List<ReactionType>> fetchReactionTypes() async {
    return _reactionApi.fetchReactionTypes();
  }

  Future<NoteReactionSummary> fetchNoteReactionSummary(
    int gameId,
    int noteIndex,
  ) async {
    return _reactionApi.fetchNoteReactionSummary(gameId, noteIndex);
  }

  Future<void> reactToNote({
    required int gameId,
    required int noteIndex,
    required int reactionId,
  }) async {
    await _reactionApi.reactToNote(
      gameId: gameId,
      noteIndex: noteIndex,
      reactionId: reactionId,
    );
  }

  Future<void> removeNoteReaction(int gameId, int noteIndex) async {
    await _reactionApi.removeNoteReaction(gameId, noteIndex);
  }

  // ── ADMIN: Crear usuario con rol ────────────────────────────────────────
  Future<void> createUserByAdmin({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.post(
        Uri.parse(adminUsersUrl),
        headers: headers,
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'roles': [role],
        }),
      ),
      withBody: true,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al crear usuario (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ── ADMIN: Listar usuarios ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchUsersForAdmin() async {
    final response = await _sendAuthorizedRequest(
      (headers) => http.get(Uri.parse(adminUsersUrl), headers: headers),
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
    final response = await _sendAuthorizedRequest(
      (headers) => http.delete(
        Uri.parse('$adminUsersUrl/$userId'),
        headers: headers,
      ),
    );
    _ensureSuccess(response, {200, 204}, 'Error al eliminar usuario');
  }
}
