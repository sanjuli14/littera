/// Obra que el usuario escribe en Littera.
class Manuscript {
  const Manuscript({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.synopsis = '',
    this.coverRef,
    this.dailyWordGoal = 500,
    this.author = '',
  });

  final String id;
  final String title;
  final String synopsis;

  /// Nombre con el que firmará la obra al exportarla.
  final String author;
  final String? coverRef;

  /// Meta diaria de palabras (0 = sin meta).
  final int dailyWordGoal;
  final DateTime createdAt;
  final DateTime updatedAt;

  Manuscript copyWith({
    String? title,
    String? synopsis,
    String? author,
    String? coverRef,
    bool clearCover = false,
    int? dailyWordGoal,
    DateTime? updatedAt,
  }) => Manuscript(
    id: id,
    title: title ?? this.title,
    synopsis: synopsis ?? this.synopsis,
    author: author ?? this.author,
    coverRef: clearCover ? null : (coverRef ?? this.coverRef),
    dailyWordGoal: dailyWordGoal ?? this.dailyWordGoal,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

/// Capítulo. [content] es el documento del editor (Delta de Quill en JSON).
class Chapter {
  const Chapter({
    required this.id,
    required this.manuscriptId,
    required this.title,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.content = '',
    this.wordCount = 0,
  });

  final String id;
  final String manuscriptId;
  final String title;
  final int order;
  final String content;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chapter copyWith({
    String? title,
    int? order,
    String? content,
    int? wordCount,
    DateTime? updatedAt,
  }) => Chapter(
    id: id,
    manuscriptId: manuscriptId,
    title: title ?? this.title,
    order: order ?? this.order,
    content: content ?? this.content,
    wordCount: wordCount ?? this.wordCount,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Copia de un capítulo en un momento dado, para recuperar borradores.
class ChapterVersion {
  const ChapterVersion({
    required this.id,
    required this.chapterId,
    required this.manuscriptId,
    required this.content,
    required this.wordCount,
    required this.createdAt,
    this.manual = false,
    this.label,
  });

  final String id;
  final String chapterId;
  final String manuscriptId;
  final String content;
  final int wordCount;
  final DateTime createdAt;

  /// `true` si la guardó el usuario (no se borra al limpiar automáticas).
  final bool manual;
  final String? label;
}

enum EntityKind {
  character,
  place,
  object,
  note;

  String get label => switch (this) {
    EntityKind.character => 'Personaje',
    EntityKind.place => 'Lugar',
    EntityKind.object => 'Objeto',
    EntityKind.note => 'Apunte',
  };

  String get pluralLabel => switch (this) {
    EntityKind.character => 'Personajes',
    EntityKind.place => 'Lugares',
    EntityKind.object => 'Objetos',
    EntityKind.note => 'Apuntes',
  };
}

/// Ficha de personaje, lugar, objeto o apunte.
class StoryEntity {
  const StoryEntity({
    required this.id,
    required this.manuscriptId,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
  });

  final String id;
  final String manuscriptId;
  final EntityKind kind;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoryEntity copyWith({String? name, String? description, EntityKind? kind}) =>
      StoryEntity(
        id: id,
        manuscriptId: manuscriptId,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
