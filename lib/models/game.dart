class GameNote {
  final String content;
  final DateTime date;
  // Autor de la opinión — se guarda al crear y se usa para
  // mostrar quién publicó y condicionar los botones editar/borrar.
  final String? authorUsername;
  // Índice de la nota padre en la lista del juego. Null si es nota raíz.
  final int? parentIndex;
  final bool deleted;

  GameNote({
    required this.content,
    required this.date,
    this.authorUsername,
    this.parentIndex,
    this.deleted = false,
  });

  factory GameNote.fromJson(Map<String, dynamic> json) => GameNote(
        content: json['content'] ?? '',
        date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
        authorUsername: json['authorUsername'] as String?,
        parentIndex: json['parentIndex'] is int ? json['parentIndex'] as int : (json['parentIndex'] is num ? (json['parentIndex'] as num).toInt() : null),
        deleted: json['deleted'] == true,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        // Truncamos a segundos para máxima compatibilidad con el backend.
        'date': DateTime(date.year, date.month, date.day,
                date.hour, date.minute, date.second)
            .toIso8601String(),
        'authorUsername': authorUsername,
        if (parentIndex != null) 'parentIndex': parentIndex,
        'deleted': deleted,
      };
}

class Game {
  final int? id;
  final String name;
  final String coverUrl;
  final String franchise;
  final String category;
  final int rating;
  final List<GameNote> notes;
  final bool played;

  Game({
    this.id,
    required this.name,
    required this.coverUrl,
    required this.franchise,
    required this.category,
    required this.rating,
    required this.notes,
    required this.played,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    final notesRaw = json['notes'] as List? ?? [];
    final notesList =
        notesRaw.map((i) => GameNote.fromJson(i as Map<String, dynamic>)).toList();

    return Game(
      id: json['id'],
      name: json['name'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      franchise: json['franchise'] ?? '',
      category: json['category'] ?? '',
      rating: json['rating'] ?? 0,
      notes: notesList,
      played: json['played'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coverUrl': coverUrl,
        'franchise': franchise,
        'category': category,
        'rating': rating,
        'notes': notes.map((n) => n.toJson()).toList(),
        'played': played,
      };

  Game copyWith({
    int? id,
    String? name,
    String? coverUrl,
    String? franchise,
    String? category,
    int? rating,
    List<GameNote>? notes,
    bool? played,
  }) =>
      Game(
        id: id ?? this.id,
        name: name ?? this.name,
        coverUrl: coverUrl ?? this.coverUrl,
        franchise: franchise ?? this.franchise,
        category: category ?? this.category,
        rating: rating ?? this.rating,
        notes: notes ?? List.from(this.notes),
        played: played ?? this.played,
      );
}