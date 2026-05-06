import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_tracker/services/service.dart';
import 'package:game_tracker/services/auth_service.dart';
import 'package:game_tracker/models/game.dart';
import 'package:game_tracker/models/reaction.dart';
import 'package:game_tracker/models/user.dart';
import 'package:game_tracker/controllers/reaction_timeline_controller.dart';
import 'package:game_tracker/screens/game_form_screen.dart';
import 'login_screen.dart';

// Fuentes usadas (sin cambios respecto al original):
//  · Orbitron      → "MY GAMES" (título principal, tech/geométrica)
//  · Rajdhani bold → nombres de juegos en cards
//  · Nunito        → todo lo demás: labels, valores, diálogos, botones

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key});

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  static const String _deletedPlaceholder =
      'El contenido de este comentario se ha eliminado.';

  final ApiService apiService = ApiService();
  final AuthService _authService = AuthService();
  late final ReactionTimelineController _reactionController;

  Future<List<Game>>? _gamesFuture;
  final TextEditingController _searchController = TextEditingController();

  // Usuario en sesión — null si no hay sesión (nunca debería pasar gracias
  // al AuthGate, pero se mantiene como guardia defensiva)
  User? _currentUser;

  // ── Colores del diseño original — sin tocar ──────────────────────────────
  final Color aquaColor = const Color(0xFF40E0D0);
  final Color stateGreenColor = const Color(0xFF88F2C4);

  // ─────────────────────────────────────────────
  //  INIT
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _reactionController = ReactionTimelineController(apiService);
    _initSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    await _authService.init();
    if (!mounted) return;
    setState(() {
      _currentUser = _authService.getUser();
    });
    _refresh();
  }

  void _refresh() {
    setState(() {
      _gamesFuture = apiService.fetchGames();
    });
  }

  // ─────────────────────────────────────────────
  //  LÓGICA DE PERMISOS
  // ─────────────────────────────────────────────

  /// ¿El usuario actual es admin?
  bool get _isAdmin => _currentUser?.isAdmin ?? false;

  bool get _isModerator => _currentUser?.isModerator ?? false;

  /// ¿Puede el usuario actual editar o borrar UN JUEGO?
  /// Solo admins pueden tocar el catálogo.
  bool get _canEditCatalog => _isAdmin;

  /// ¿Puede el usuario actual editar una opinión?
  /// El usuario puede editar sus propias notas; el admin puede editar cualquiera.
  bool _isDeletedNote(GameNote note) {
    return note.deleted || note.content.trim() == _deletedPlaceholder;
  }

  bool _canEditNote(GameNote note) {
    if (_currentUser == null) return false;
    if (_isDeletedNote(note)) return false;
    if (_isAdmin) return true;
    // Si la nota guarda el autor, comparar. Si no (notas legacy sin autor),
    // solo el admin puede tocarlas.
    if (note.authorUsername == null) return false;
    return note.authorUsername == _currentUser!.username;
  }

  /// ¿Puede el usuario actual borrar una opinión?
  /// Admin y moderador pueden borrar cualquiera; usuario solo la suya.
  bool _canDeleteNote(GameNote note) {
    if (_currentUser == null) return false;
    if (_isDeletedNote(note)) return false;
    if (_isAdmin || _isModerator) return true;
    if (note.authorUsername == null) return false;
    return note.authorUsername == _currentUser!.username;
  }

  /// ¿Puede publicar notas? Cualquier usuario autenticado.
  bool get _canPostNote => _currentUser != null;

  // ─────────────────────────────────────────────
  //  LOGOUT
  // ─────────────────────────────────────────────

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Maneja errores 401: cierra sesión y redirige al login.
  Future<void> _handleAuthError() async {
    await _authService.logout();
    if (!mounted) return;
    _showSoftMessage('Sesión expirada. Vuelve a iniciar sesión.');
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  bool _is401(Object e) => e.toString().contains('401');

  // ─────────────────────────────────────────────
  //  HELPERS DE UI (sin cambios de estilo)
  // ─────────────────────────────────────────────

  void _showSoftMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: aquaColor.withValues(alpha: 0.18), width: 1),
        ),
        backgroundColor: const Color(0xFF222222),
        elevation: 0,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPermissionDenied() {
    _showSoftMessage('No tienes permiso para hacer eso.');
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color valueColor = Colors.white,
    IconData? valueIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              if (valueIcon != null) ...[
                Icon(valueIcon, color: valueColor, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: GoogleFonts.nunito(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<MapEntry<int, GameNote>> _childNotesFor(Game game, int? parentIndex) {
    return game.notes.asMap().entries
        .where((entry) => entry.value.parentIndex == parentIndex)
        .toList();
  }

  List<Widget> _buildThreadedNotes(
    Game game,
    StateSetter setModalState,
    List<ReactionType> reactionTypes,
  ) {
    final widgets = <Widget>[];

    final roots = _childNotesFor(game, null).reversed.toList();

    for (final root in roots) {
      widgets.addAll(
        _buildNoteBranch(
          game: game,
          setModalState: setModalState,
          reactionTypes: reactionTypes,
          noteIndex: root.key,
          depth: 0,
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildNoteBranch({
    required Game game,
    required StateSetter setModalState,
    required List<ReactionType> reactionTypes,
    required int noteIndex,
    required int depth,
  }) {
    final note = game.notes[noteIndex];
    final branch = <Widget>[
      _buildTimelineNote(
        note,
        game,
        setModalState,
        noteIndex,
        depth,
        reactionTypes,
        _reactionController.summaryFor(noteIndex),
        (reaction) async {
          if (game.id == null) return;

          try {
            await _reactionController.toggleReaction(
              gameId: game.id!,
              noteIndex: noteIndex,
              reaction: reaction,
            );
          } catch (e) {
            debugPrint('Error al reaccionar: $e');
            _showSoftMessage('No se pudo actualizar la reacción');
          }
        },
      ),
    ];

    for (final child in _childNotesFor(game, noteIndex)) {
      branch.addAll(
        _buildNoteBranch(
          game: game,
          setModalState: setModalState,
          reactionTypes: reactionTypes,
          noteIndex: child.key,
          depth: depth + 1,
        ),
      );
    }

    return branch;
  }

  // ─────────────────────────────────────────────
  //  TIMELINE DE NOTAS con permisos condicionales
  // ─────────────────────────────────────────────

  Widget _buildTimelineNote(
    GameNote note,
    Game game,
    StateSetter setModalState,
    int noteIndex,
    int depth,
    List<ReactionType> reactionTypes,
    NoteReactionSummary? reactionSummary,
    Future<void> Function(ReactionType reaction) onReactionTap,
  ) {
    final String dateStr =
        "${note.date.day}/${note.date.month}/${note.date.year} "
        "${note.date.hour}:${note.date.minute.toString().padLeft(2, '0')}";

    final bool isDeleted = _isDeletedNote(note);
    final bool showEdit = _canEditNote(note);
    final bool showDelete = _canDeleteNote(note);

    final leftOffset = (depth * 18).toDouble();
    final isReply = depth > 0;
    final String? parentAuthor = isReply && note.parentIndex != null && note.parentIndex! >= 0 && note.parentIndex! < game.notes.length
      ? game.notes[note.parentIndex!].authorUsername
      : null;

    return Padding(
      padding: EdgeInsets.only(bottom: 14, left: leftOffset),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isReply ? 0.025 : 0.035),
          borderRadius: BorderRadius.circular(18),
          border: isReply
              ? Border(
                  left: BorderSide(
                    color: aquaColor.withValues(alpha: 0.35),
                    width: 2,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(Icons.chat_bubble_rounded, color: aquaColor, size: 14),
                Container(
                  width: 1,
                  height: 30,
                  color: aquaColor.withValues(alpha: 0.15),
                  margin: const EdgeInsets.only(top: 4),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '@${note.authorUsername ?? 'desconocido'}',
                        style: GoogleFonts.nunito(
                          color: aquaColor.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: GoogleFonts.nunito(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                  if (isReply) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Respondiendo a @${parentAuthor ?? 'desconocido'}',
                      style: GoogleFonts.nunito(
                        color: aquaColor.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    isDeleted
                        ? _deletedPlaceholder
                        : note.content,
                    style: GoogleFonts.nunito(
                      color: isDeleted ? Colors.white38 : Colors.white60,
                      fontSize: 13,
                      fontWeight: isDeleted ? FontWeight.w500 : FontWeight.w400,
                      height: 1.4,
                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  if (!isDeleted) ...[
                    const SizedBox(height: 10),
                    if (reactionTypes.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reactionTypes
                            .map(
                              (reaction) => _buildReactionChip(
                                reaction: reaction,
                                count: reactionSummary?.countFor(reaction.description) ?? 0,
                                selectedReactionId:
                                    reactionSummary?.myReaction?.reactionId,
                                onTap: () => onReactionTap(reaction),
                              ),
                            )
                            .toList(),
                      )
                    else
                      Text(
                        'Cargando reacciones...',
                        style: GoogleFonts.nunito(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  if (_canPostNote)
                    TextButton(
                      onPressed: () async {
                        final TextEditingController replyCtrl = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(
                              'Responder',
                              style: GoogleFonts.nunito(
                                color: aquaColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: TextField(
                              controller: replyCtrl,
                              maxLines: 3,
                              style: GoogleFonts.nunito(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Escribe tu respuesta...',
                                hintStyle: GoogleFonts.nunito(color: Colors.white24),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: aquaColor,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () async {
                                  final content = replyCtrl.text.trim();
                                  if (content.isEmpty) return;
                                  final reply = GameNote(
                                    content: content,
                                    date: DateTime.now(),
                                    parentIndex: noteIndex,
                                  );
                                  try {
                                    await apiService.addGameNote(game.id!, reply);
                                    setModalState(() => game.notes.add(reply));
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _refresh();
                                    _showSoftMessage('Respuesta añadida');
                                  } catch (e) {
                                    debugPrint('Error al crear respuesta: $e');
                                    if (_is401(e)) {
                                      await _handleAuthError();
                                    } else {
                                      _showSoftMessage('No se pudo publicar la respuesta');
                                    }
                                  }
                                },
                                child: Text('Responder', style: GoogleFonts.nunito(fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('Responder', style: GoogleFonts.nunito(color: aquaColor, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                ],
              ),
            ),
            if (!isDeleted && showDelete)
              GestureDetector(
                onTap: () => _confirmDeleteNote(game, noteIndex, note, setModalState),
                child: _noteIconBtn(icon: Icons.close_rounded),
              ),
            if (!isDeleted && showEdit)
              GestureDetector(
                onTap: () => _editNote(game, noteIndex, note, setModalState),
                child: _noteIconBtn(icon: Icons.edit_rounded),
              ),
          ],
        ),
      ),
    );
  }

  void _editNote(
    Game game,
    int noteIndex,
    GameNote note,
    StateSetter setModalState,
  ) async {
    final TextEditingController editController = TextEditingController(
      text: note.content,
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Editar opinión",
          style: GoogleFonts.nunito(
            color: aquaColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Corrige tu opinión...",
            hintStyle: GoogleFonts.nunito(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: GoogleFonts.nunito(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: aquaColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final content = editController.text.trim();
              if (content.isEmpty) return;
              final updatedNote = GameNote(
                content: content,
                date: note.date,
                authorUsername: note.authorUsername,
              );
              try {
                await apiService.updateGameNote(
                  game.id!,
                  noteIndex,
                  updatedNote,
                );
                setModalState(() => game.notes[noteIndex] = updatedNote);
                if (ctx.mounted) Navigator.pop(ctx);
                _refresh();
                _showSoftMessage("Opinión actualizada");
              } catch (e) {
                debugPrint("Error al editar nota: $e");
              }
            },
            child: Text(
              "Guardar",
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  MODAL DE DETALLES
  // ─────────────────────────────────────────────

  void _showGameDetails(Game game) {
    _reactionController.prepareForGame(game);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reactionController.ensureLoaded(game);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AnimatedBuilder(
          animation: _reactionController,
          builder: (context, _) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        game.coverUrl,
                        height: 200,
                        width: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Container(
                          height: 200,
                          width: 150,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: Text(
                      game.name,
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < game.rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: aquaColor,
                          size: 22,
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    "Franquicia",
                    game.franchise.isEmpty ? "No definida" : game.franchise,
                  ),
                  _buildInfoRow("Categoría", game.category),
                  _buildInfoRow(
                    "Estado",
                    game.played ? "Jugado" : "Pendiente",
                    valueColor: game.played ? stateGreenColor : Colors.white54,
                    valueIcon: game.played
                        ? Icons.task_alt_rounded
                        : Icons.radio_button_unchecked,
                  ),
                  const SizedBox(height: 24),
                  if (game.notes.isNotEmpty) ...[
                    if (_reactionController.error != null) ...[
                      Text(
                        _reactionController.error!,
                        style: GoogleFonts.nunito(
                          color: Colors.white24,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Icon(Icons.timeline, color: aquaColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Timeline · ${game.notes.length} anotaciones",
                          style: GoogleFonts.nunito(
                            color: aquaColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ..._buildThreadedNotes(
                      game,
                      setModalState,
                      _reactionController.reactionTypes,
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "Sin anotaciones aún",
                          style: GoogleFonts.nunito(
                            color: aquaColor.withValues(alpha: 0.35),
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionChip({
    required ReactionType reaction,
    required int count,
    required int? selectedReactionId,
    required VoidCallback onTap,
  }) {
    final bool isSelected = selectedReactionId == reaction.id;
    final Color accentColor = _reactionColor(reaction.description);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.45)
                  : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _reactionIcon(reaction.description),
                size: 14,
                color: isSelected ? accentColor : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: GoogleFonts.nunito(
                  color: isSelected ? accentColor : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _reactionIcon(String description) {
    switch (description) {
      case 'REACTION_LIKE':
        return Icons.thumb_up_alt_rounded;
      case 'REACTION_LOVE':
        return Icons.favorite_rounded;
      case 'REACTION_HATE':
        return Icons.thumb_down_alt_rounded;
      case 'REACTION_SAD':
        return Icons.sentiment_dissatisfied_rounded;
      case 'REACTION_ANGRY':
        return Icons.mood_bad_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _reactionColor(String description) {
    switch (description) {
      case 'REACTION_LIKE':
        return aquaColor;
      case 'REACTION_LOVE':
        return Colors.pinkAccent;
      case 'REACTION_HATE':
        return Colors.redAccent;
      case 'REACTION_SAD':
        return Colors.amberAccent;
      case 'REACTION_ANGRY':
        return const Color(0xFFFF8A65);
      default:
        return Colors.white70;
    }
  }

  // ─────────────────────────────────────────────
  //  BORRAR JUEGO (solo admin)
  // ─────────────────────────────────────────────

  void _confirmDelete(Game game) {
    if (!_canEditCatalog) {
      _showPermissionDenied();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          '¿Borrar juego?',
          style: GoogleFonts.nunito(
            color: aquaColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${game.name}"?',
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No', style: GoogleFonts.nunito(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await apiService.deleteGame(game.id!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _refresh();
            },
            child: Text(
              'Sí, borrar',
              style: GoogleFonts.nunito(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirm note deletion with strategy selection dialog.
  /// Two strategies: SOFT_DELETE (content-only) and CASCADE_DELETE (admin-only).
  /// Moderators perform hard-delete (permanent removal, content disappears).
  /// Admins can choose between soft-delete or cascade-delete.
  void _confirmDeleteNote(Game game, int noteIndex, GameNote note, Function setModalState) {
    if (!_canDeleteNote(note)) {
      _showPermissionDenied();
      return;
    }

    // Determine available strategies based on user role
    final bool canCascadeDelete = _isAdmin;
    final String messageStart = 'Opciones para eliminar la opinión';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          messageStart,
          style: GoogleFonts.nunito(
            color: aquaColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          canCascadeDelete
              ? '¿Deseas borrar solo el contenido o la opinión completa con todas las respuestas?'
              : '¿Deseas borrar esta opinión de forma permanente?',
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.nunito(color: Colors.white54)),
          ),
          // Soft-delete button (for all users)
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(ctx);
                final previousNoteCount = game.notes.length;
                final updatedGame = await apiService.deleteGameNote(
                  game.id!,
                  noteIndex,
                  strategy: 'SOFT_DELETE',
                );
                if (mounted) {
                  setModalState(() {
                    game.notes
                      ..clear()
                      ..addAll(updatedGame.notes);
                  });
                  if (updatedGame.notes.length < previousNoteCount) {
                    _reactionController.shiftAfterDelete(noteIndex);
                  }
                  _refresh();
                  _showSoftMessage("Contenido de la opinión eliminado");
                }
              } catch (e) {
                debugPrint("Error al borrar nota: $e");
                if (mounted) {
                  _showSoftMessage('Error al eliminar la opinión');
                }
              }
            },
            child: Text(
              'Borrar contenido',
              style: GoogleFonts.nunito(color: Colors.orange),
            ),
          ),
          // Cascade-delete button (admin-only)
          if (canCascadeDelete)
            TextButton(
              onPressed: () async {
                try {
                  Navigator.pop(ctx);
                  final previousNoteCount = game.notes.length;
                  final updatedGame = await apiService.deleteGameNote(
                    game.id!,
                    noteIndex,
                    strategy: 'CASCADE_DELETE',
                  );
                  if (mounted) {
                    setModalState(() {
                      game.notes
                        ..clear()
                        ..addAll(updatedGame.notes);
                    });
                    if (updatedGame.notes.length < previousNoteCount) {
                      _reactionController.shiftAfterDelete(noteIndex);
                    }
                    _refresh();
                    _showSoftMessage("Opinión y respuestas eliminadas completamente");
                  }
                } catch (e) {
                  debugPrint("Error al borrar nota en cascada: $e");
                  if (mounted) {
                    _showSoftMessage('Error al eliminar la opinión');
                  }
                }
              },
              child: Text(
                'Borrar para siempre',
                style: GoogleFonts.nunito(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PUBLICAR NOTA (cualquier usuario autenticado)
  // ─────────────────────────────────────────────

  void _quickAddNote(Game game) async {
    if (!_canPostNote) {
      _showPermissionDenied();
      return;
    }

    final TextEditingController quickNoteController = TextEditingController();
    bool saved = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Nueva opinión para ${game.name}",
            style: GoogleFonts.nunito(
              color: aquaColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quickNoteController,
                maxLines: 3,
                style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Escribe algo...",
                  hintStyle: GoogleFonts.nunito(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (saved) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: aquaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: aquaColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.task_alt_rounded, color: aquaColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "Tu opinión se ha guardado.",
                        style: GoogleFonts.nunito(
                          color: aquaColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                saved ? 'Cerrar' : 'Cancelar',
                style: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (!saved)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: aquaColor,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  if (quickNoteController.text.isNotEmpty) {
                    final note = GameNote(
                      content: quickNoteController.text.trim(),
                      date: DateTime.now(),
                    );
                    try {
                      await apiService.addGameNote(game.id!, note);
                      setDialogState(() {
                        saved = true;
                        game.notes.add(note);
                      });
                      _refresh();
                    } catch (e) {
                      debugPrint("Error al guardar: $e");
                      if (_is401(e)) {
                        await _handleAuthError();
                      } else {
                        _showSoftMessage('No se pudo guardar la opinión');
                      }
                    }
                  }
                },
                child: Text(
                  "Guardar",
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD PRINCIPAL
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'MY GAMES',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 3,
          ),
        ),
        actions: [
          // Badge de usuario + rol
          if (_currentUser != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    Text(
                      '@${_currentUser!.username}',
                      style: GoogleFonts.nunito(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: aquaColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: aquaColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'ADMIN',
                          style: GoogleFonts.nunito(
                            color: aquaColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ] else if (_isModerator) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'MOD',
                          style: GoogleFonts.nunito(
                            color: Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_isAdmin)
            IconButton(
              icon: Icon(Icons.manage_accounts, color: aquaColor),
              tooltip: 'Gestionar usuarios',
              onPressed: _showAdminUserManager,
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: aquaColor),
            onPressed: _refresh,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white38),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.nunito(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar juego...",
                hintStyle: GoogleFonts.nunito(color: Colors.white24),
                prefixIcon: Icon(Icons.search, color: aquaColor),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Game>>(
              future: _gamesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: aquaColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.nunito(color: Colors.red),
                    ),
                  );
                }
                final games = snapshot.data ?? [];
                final filteredGames = games
                    .where(
                      (g) => g.name.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filteredGames.isEmpty) {
                  return Center(
                    child: Text(
                      "No hay juegos",
                      style: GoogleFonts.nunito(color: Colors.white24),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredGames.length,
                  itemBuilder: (context, index) =>
                      _buildGameCard(filteredGames[index]),
                );
              },
            ),
          ),
        ],
      ),
      // FAB solo para admins
      floatingActionButton: _canEditCatalog
          ? FloatingActionButton(
              backgroundColor: aquaColor,
              child: const Icon(Icons.add, color: Colors.black),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameFormScreen(),
                  ),
                );
                if (result == true) _refresh();
              },
            )
          : null,
    );
  }

  // ─────────────────────────────────────────────
  //  CARD con botones condicionales por rol
  // ─────────────────────────────────────────────

  Widget _buildGameCard(Game game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showGameDetails(game),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  game.coverUrl,
                  width: 56,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) => Container(
                    width: 56,
                    height: 72,
                    color: Colors.white10,
                    child: const Icon(Icons.gamepad, color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.category,
                      style: GoogleFonts.nunito(
                        color: aquaColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (game.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${game.notes.length} opinión${game.notes.length == 1 ? '' : 'es'}",
                          style: GoogleFonts.nunito(
                            color: Colors.white24,
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Añadir nota — cualquier usuario autenticado
                  if (_canPostNote)
                    _cardIconBtn(
                      icon: Icons.add_comment_outlined,
                      onTap: () => _quickAddNote(game),
                    ),
                  const SizedBox(width: 4),
                  // Editar juego — solo admin
                  if (_canEditCatalog)
                    _cardIconBtn(
                      icon: Icons.edit_outlined,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameFormScreen(game: game),
                          ),
                        );
                        if (result == true) _refresh();
                      },
                    ),
                  if (_canEditCatalog) const SizedBox(width: 4),
                  // Borrar juego — solo admin
                  if (_canEditCatalog)
                    _cardIconBtn(
                      icon: Icons.delete_outline,
                      onTap: () => _confirmDelete(game),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardIconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white38, size: 18),
      ),
    );
  }

  Widget _noteIconBtn({required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(left: 6, top: 2),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white38, size: 14),
    );
  }

  void _showAdminUserManager() async {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'user';
    List<Map<String, dynamic>> users = [];
    bool isLoading = true;
    bool isSaving = false;
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> loadUsers() async {
            try {
              final data = await apiService.fetchUsersForAdmin();
              if (!ctx.mounted) return;
              setDialogState(() {
                users = data;
                isLoading = false;
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() {
                error = 'No se pudieron cargar usuarios';
                isLoading = false;
              });
            }
          }

          if (isLoading && users.isEmpty && error == null) {
            loadUsers();
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Gestionar usuarios',
              style: GoogleFonts.nunito(
                color: aquaColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _adminInput(
                      controller: usernameController,
                      hint: 'Username',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 10),
                    _adminInput(
                      controller: emailController,
                      hint: 'Email',
                      icon: Icons.email,
                    ),
                    const SizedBox(height: 10),
                    _adminInput(
                      controller: passwordController,
                      hint: 'Password (min 6)',
                      icon: Icons.lock,
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: aquaColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          dropdownColor: const Color(0xFF1E222B),
                          style: GoogleFonts.nunito(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('ROLE_USER'),
                            ),
                            DropdownMenuItem(
                              value: 'mod',
                              child: Text('ROLE_MODERATOR'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('ROLE_ADMIN'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() => selectedRole = value);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: aquaColor,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final username = usernameController.text.trim();
                              final email = emailController.text.trim();
                              final password = passwordController.text.trim();

                              if (username.isEmpty ||
                                  email.isEmpty ||
                                  password.length < 6) {
                                setDialogState(() {
                                  error =
                                      'Completa los campos y usa una contraseña de al menos 6 caracteres';
                                });
                                return;
                              }

                              setDialogState(() {
                                isSaving = true;
                                error = null;
                              });

                              try {
                                await apiService.createUserByAdmin(
                                  username: username,
                                  email: email,
                                  password: password,
                                  role: selectedRole,
                                );

                                final refreshed = await apiService
                                    .fetchUsersForAdmin();
                                if (!ctx.mounted) return;
                                setDialogState(() {
                                  users = refreshed;
                                  isSaving = false;
                                  usernameController.clear();
                                  emailController.clear();
                                  passwordController.clear();
                                });
                                _showSoftMessage('Usuario creado');
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setDialogState(() {
                                  isSaving = false;
                                  error = 'Error al crear usuario';
                                });
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        isSaving ? 'Creando...' : 'Crear usuario',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: GoogleFonts.nunito(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Usuarios registrados',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ...users
                          .take(12)
                          .map(
                            (u) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '@${u['username']}  ·  ${(u['roles'] as List).join(', ')}',
                                      style: GoogleFonts.nunito(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (u['id'] == _currentUser?.id)
                                    Text(
                                      'Tú',
                                      style: GoogleFonts.nunito(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    )
                                  else
                                    IconButton(
                                      tooltip: 'Eliminar usuario',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        final userId = u['id'];
                                        if (userId is! int) {
                                          setDialogState(() {
                                            error =
                                                'No se pudo identificar el usuario';
                                          });
                                          return;
                                        }

                                        final confirmed = await showDialog<bool>(
                                          context: ctx,
                                          builder: (confirmCtx) => AlertDialog(
                                            backgroundColor: const Color(
                                              0xFF1A1A1A,
                                            ),
                                            title: Text(
                                              'Eliminar usuario',
                                              style: GoogleFonts.nunito(
                                                color: aquaColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: Text(
                                              '¿Deseas eliminar a @${u['username']}?',
                                              style: GoogleFonts.nunito(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  confirmCtx,
                                                  false,
                                                ),
                                                child: Text(
                                                  'Cancelar',
                                                  style: GoogleFonts.nunito(
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  confirmCtx,
                                                  true,
                                                ),
                                                child: Text(
                                                  'Eliminar',
                                                  style: GoogleFonts.nunito(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true) return;

                                        try {
                                          await apiService.deleteUserByAdmin(
                                            userId,
                                          );
                                          final refreshed = await apiService
                                              .fetchUsersForAdmin();
                                          if (!ctx.mounted) return;
                                          setDialogState(() {
                                            users = refreshed;
                                            error = null;
                                          });
                                          _showSoftMessage('Usuario eliminado');
                                        } catch (e) {
                                          if (!ctx.mounted) return;
                                          setDialogState(() {
                                            error =
                                                'No se pudo eliminar el usuario';
                                          });
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cerrar',
                  style: GoogleFonts.nunito(color: Colors.white54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _adminInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.nunito(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: aquaColor.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}