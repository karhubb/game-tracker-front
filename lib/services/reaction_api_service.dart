import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/reaction.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// DESIGN PATTERN: Adapter/Facade Pattern (Structural)
///
/// Purpose:
/// Isolate all HTTP details for reaction endpoints into one service.
/// Provides a clean interface to UI/controllers without exposing network complexity.
///
/// Why This Pattern?
/// - Reaction HTTP requests scattered across multiple UI files = code duplication
/// - Each UI component would need to know: URL structure, headers, error handling
/// - Token management repeated: auth.init(), header building, token retrieval
/// - Backend URL changes require updates everywhere (not DRY)
///
/// Benefits:
/// - Adapter: Converts HTTP responses to domain models (Dart classes)
/// - Facade: Hides endpoint structure behind simple methods
/// - Single point of maintenance: Change reaction endpoints here
/// - Easy to mock for testing: Replace ReactionApiService with test double
/// - Clear contract: Type signatures show exactly what each method does
///
/// Usage Example (UI code):
///   final service = ReactionApiService(authService);
///   final types = await service.fetchReactionTypes();
///   await service.reactToNote(
///     gameId: 1,
///     noteIndex: 0,
///     reactionId: types.first.id,
///   );
///   // UI doesn't know about URLs, headers, or error codes
class ReactionApiService {
  ReactionApiService(this._authService);

  final AuthService _authService;

  String get _reactionTypesUrl => '${ApiConfig.apiBaseUrl}/reactions';
  String get _noteReactionsUrl => '${ApiConfig.apiBaseUrl}/notes/reactions';

  /// Private helper: Build HTTP headers with authentication.
  ///
  /// Centralizes how we attach JWT tokens to every request.
  /// Ensures consistency: all reaction endpoints use the same auth mechanism.
  Map<String, String> _getHeaders({bool withBody = false}) {
    final headers = <String, String>{};
    if (withBody) headers['Content-Type'] = 'application/json';

    final token = _authService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Fetch all available reaction types from the backend.
  ///
  /// Returns the reaction catalog (e.g., FUNNY, INTERESTING, USELESS)
  /// that clients can apply to notes.
  Future<List<ReactionType>> fetchReactionTypes() async {
    await _authService.init();
    final response = await http.get(
      Uri.parse(_reactionTypesUrl),
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

  /// Fetch the reaction summary for a specific note.
  ///
  /// Shows: {reactionType: count} map for how users have reacted to this note.
  /// Example: {"FUNNY": 5, "INTERESTING": 2}
  Future<NoteReactionSummary> fetchNoteReactionSummary(
    int gameId,
    int noteIndex,
  ) async {
    await _authService.init();
    final response = await http.get(
      Uri.parse('$_noteReactionsUrl/games/$gameId/notes/$noteIndex'),
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

  /// Add a reaction from the current user to a note.
  ///
  /// If the user already has a reaction to this note, updates it to the new type.
  /// If the user has not reacted yet, creates a new reaction record.
  Future<void> reactToNote({
    required int gameId,
    required int noteIndex,
    required int reactionId,
  }) async {
    await _authService.init();
    final response = await http.post(
      Uri.parse('$_noteReactionsUrl/games/$gameId/notes/$noteIndex'),
      headers: _getHeaders(withBody: true),
      body: json.encode({'reactionId': reactionId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al reaccionar a la opinion (${response.statusCode})',
      );
    }
  }

  /// Remove the current user's reaction from a note.
  ///
  /// Idempotent: If the user has not reacted to this note, does nothing.
  Future<void> removeNoteReaction(int gameId, int noteIndex) async {
    await _authService.init();
    final response = await http.delete(
      Uri.parse('$_noteReactionsUrl/games/$gameId/notes/$noteIndex'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al quitar la reaccion (${response.statusCode})');
    }
  }
}
