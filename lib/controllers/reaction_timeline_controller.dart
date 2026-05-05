import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../models/reaction.dart';
import '../services/service.dart';

/// DESIGN PATTERN: Controller / ChangeNotifier (State Management)
/// Also demonstrates: Single Responsibility Principle, Separation of Concerns
///
/// Purpose:
/// Own all reaction-related state for the reaction modal.
/// Separate state management from UI rendering to enable:
/// - Easy testing (mock API service, verify state changes)
/// - State reusability (share with multiple UI components)
/// - Clear data flow (UI listens to controller, calls methods)
///
/// Why ChangeNotifier?
/// - Flutter native state management pattern
/// - Lightweight compared to Provider/Riverpod for this use case
/// - Clear lifecycle: listeners attach/detach automatically
/// - Works well with AnimatedBuilder and Consumer widgets
///
/// Architecture Benefits:
/// - UI (screen.dart): Thin, focuses on rendering
/// - Controller: Owns reaction state, API calls, business logic
/// - Services (ApiService): Thin HTTP wrapper
/// - Clear separation: UI doesn't make API calls directly
/// 
/// State Properties:
/// - _loading: Fetch in progress (show spinner)
/// - _loaded: Data successfully fetched (show UI)
/// - _error: Error message if fetch fails
/// - _reactionTypes: Available reaction types (FUNNY, INTERESTING, etc)
/// - _reactionSummaries: Map[noteIndex -> reaction count and user's reaction]
/// 
/// Usage Pattern:
///   final controller = ReactionTimelineController(apiService);
///   
///   // Open modal for game: reset state
///   controller.prepareForGame(game);
///   
///   // Lazily load data on first build
///   controller.ensureLoaded(game);
///   
///   // Listen to state changes in UI
///   AnimatedBuilder(
///     animation: controller,
///     builder: (context, child) {
///       if (controller.isLoading) return Spinner();
///       return ReactionWidget(summary: controller.summaryFor(0));
///     },
///   );
///
///   // User reacts to note
///   await controller.toggleReaction(gameId: 1, noteIndex: 0, reaction: type);
class ReactionTimelineController extends ChangeNotifier {
  ReactionTimelineController(this._apiService);

  final ApiService _apiService;

  /// State: Current loading/loaded/error status
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  /// State: Reaction data
  /// _reactionTypes: Catalog of available reactions from backend
  /// _reactionSummaries: Map[noteIndex -> {"FUNNY": 5, "INTERESTING": 2, myReaction: ...}]
  List<ReactionType> _reactionTypes = [];
  final Map<int, NoteReactionSummary> _reactionSummaries = {};

  // === Public Getters (read-only) ===

  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;
  List<ReactionType> get reactionTypes => List.unmodifiable(_reactionTypes);

  /// Get reaction summary for a specific note by index.
  /// Returns null if data not loaded yet or note has no reactions.
  NoteReactionSummary? summaryFor(int noteIndex) => _reactionSummaries[noteIndex];

  // === Public Methods ===

  /// Reset all state unconditionally when opening modal for a game.
  /// This ensures no stale data from previous game is shown.
  ///
  /// Call this when:
  /// - User taps a game to open the modal
  /// - User switches between games
  ///
  /// Effect: Sets loading=false, clears types and summaries, notifies listeners
  void prepareForGame(Game game) {
    _loading = false;
    _loaded = false;
    _error = null;
    _reactionTypes = [];
    _reactionSummaries.clear();
    notifyListeners();
  }

  /// Lazily load reaction types and summaries for all notes in a game.
  /// Only loads if not already loading or loaded.
  ///
  /// Call this when:
  /// - Modal UI first renders
  /// - Manual refresh (F5, pull-to-refresh)
  ///
  /// Behavior:
  /// - Skips if already loaded or currently loading
  /// - Fetches reaction types (FUNNY, INTERESTING, etc)
  /// - Fetches summary for each note in parallel
  /// - Updates state and notifies listeners
  /// - Handles errors gracefully (stores error message, stays in UI)
  Future<void> ensureLoaded(Game game) async {
    if (game.id == null || _loaded || _loading) {
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final loadedTypes = await _apiService.fetchReactionTypes();
      final loadedSummaries = await Future.wait(
        game.notes.asMap().entries.map(
          (entry) => _apiService
              .fetchNoteReactionSummary(game.id!, entry.key)
              .then((summary) => MapEntry(entry.key, summary)),
        ),
      );

      _reactionTypes = loadedTypes;
      _reactionSummaries
        ..clear()
        ..addEntries(loadedSummaries);
      _loaded = true;
    } catch (e) {
      _error = 'No se pudieron cargar las reacciones';
      debugPrint('Error al cargar reacciones: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh reaction summary for a single note.
  /// Called after user reacts/unreacts to get fresh counts.
  ///
  /// @param gameId: The game containing the note
  /// @param noteIndex: The note to refresh
  Future<void> refreshNoteReaction(int gameId, int noteIndex) async {
    final summary = await _apiService.fetchNoteReactionSummary(gameId, noteIndex);
    _reactionSummaries[noteIndex] = summary;
    notifyListeners();
  }

  /// Toggle user's reaction to a note: add if not reacted, or swap reaction type.
  ///
  /// Logic:
  /// - If user already reacted with this type: remove it
  /// - Otherwise: add/update reaction to this type
  ///
  /// @param gameId: The game containing the note
  /// @param noteIndex: The note being reacted to
  /// @param reaction: The reaction type to toggle
  Future<void> toggleReaction({
    required int gameId,
    required int noteIndex,
    required ReactionType reaction,
  }) async {
    final summary = _reactionSummaries[noteIndex];
    final selectedReactionId = summary?.myReaction?.reactionId;

    if (selectedReactionId == reaction.id) {
      await _apiService.removeNoteReaction(gameId, noteIndex);
    } else {
      await _apiService.reactToNote(
        gameId: gameId,
        noteIndex: noteIndex,
        reactionId: reaction.id,
      );
    }

    await refreshNoteReaction(gameId, noteIndex);
  }

  /// Reindex reaction summaries after a note is deleted.
  ///
  /// When a note at index N is deleted, all notes with index > N shift down by 1.
  /// This method updates our reaction summary map to reflect the new indices.
  ///
  /// Example:
  ///   Before delete: {0: summary, 1: summary, 2: summary}
  ///   Delete note 1:
  ///   After shift:   {0: summary, 1: summary (was 2)}
  ///
  /// @param deletedIndex: The index of the note that was deleted
  void shiftAfterDelete(int deletedIndex) {
    final shiftedEntries = <int, NoteReactionSummary>{};
    for (final entry in _reactionSummaries.entries) {
      if (entry.key == deletedIndex) continue;
      final newIndex = entry.key > deletedIndex ? entry.key - 1 : entry.key;
      shiftedEntries[newIndex] = entry.value.copyWith(noteIndex: newIndex);
    }

    _reactionSummaries
      ..clear()
      ..addAll(shiftedEntries);
    notifyListeners();
  }

  /// Reset all state (complete clear).
  /// Use when modal closes or app logs out.
  void reset() {
    _loading = false;
    _loaded = false;
    _error = null;
    _reactionTypes = [];
    _reactionSummaries.clear();
    notifyListeners();
  }
}
