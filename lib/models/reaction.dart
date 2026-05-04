class ReactionType {
  final int id;
  final String description;

  ReactionType({required this.id, required this.description});

  factory ReactionType.fromJson(Map<String, dynamic> json) => ReactionType(
        id: (json['id'] as num).toInt(),
        description: json['description'] as String? ?? '',
      );
}

class NoteReactionUser {
  final int? id;
  final String? username;
  final String? email;

  NoteReactionUser({this.id, this.username, this.email});

  factory NoteReactionUser.fromJson(Map<String, dynamic> json) =>
      NoteReactionUser(
        id: (json['id'] as num?)?.toInt(),
        username: json['username'] as String?,
        email: json['email'] as String?,
      );
}

class NoteReactionResponse {
  final int? id;
  final int gameId;
  final int noteIndex;
  final int reactionId;
  final String reaction;
  final NoteReactionUser? user;

  NoteReactionResponse({
    this.id,
    required this.gameId,
    required this.noteIndex,
    required this.reactionId,
    required this.reaction,
    this.user,
  });

  factory NoteReactionResponse.fromJson(Map<String, dynamic> json) =>
      NoteReactionResponse(
        id: (json['id'] as num?)?.toInt(),
        gameId: (json['gameId'] as num).toInt(),
        noteIndex: (json['noteIndex'] as num).toInt(),
        reactionId: (json['reactionId'] as num).toInt(),
        reaction: json['reaction'] as String? ?? '',
        user: json['user'] is Map<String, dynamic>
            ? NoteReactionUser.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );
}

class NoteReactionSummary {
  final int gameId;
  final int noteIndex;
  final int total;
  final Map<String, int> counts;
  final NoteReactionResponse? myReaction;

  NoteReactionSummary({
    required this.gameId,
    required this.noteIndex,
    required this.total,
    required this.counts,
    this.myReaction,
  });

  factory NoteReactionSummary.fromJson(Map<String, dynamic> json) {
    final countsJson = json['counts'] as Map? ?? const {};

    return NoteReactionSummary(
      gameId: (json['gameId'] as num).toInt(),
      noteIndex: (json['noteIndex'] as num).toInt(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      counts: countsJson.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      myReaction: json['myReaction'] is Map<String, dynamic>
          ? NoteReactionResponse.fromJson(
              json['myReaction'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  NoteReactionSummary copyWith({
    int? gameId,
    int? noteIndex,
    int? total,
    Map<String, int>? counts,
    NoteReactionResponse? myReaction,
  }) {
    return NoteReactionSummary(
      gameId: gameId ?? this.gameId,
      noteIndex: noteIndex ?? this.noteIndex,
      total: total ?? this.total,
      counts: counts ?? Map<String, int>.from(this.counts),
      myReaction: myReaction ?? this.myReaction,
    );
  }

  int countFor(String reactionKey) => counts[reactionKey] ?? 0;
}