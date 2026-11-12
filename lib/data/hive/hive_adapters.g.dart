// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class AppThemePreferenceAdapter extends TypeAdapter<AppThemePreference> {
  @override
  final typeId = 0;

  @override
  AppThemePreference read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AppThemePreference.system;
      case 1:
        return AppThemePreference.light;
      case 2:
        return AppThemePreference.sepia;
      case 3:
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  @override
  void write(BinaryWriter writer, AppThemePreference obj) {
    switch (obj) {
      case AppThemePreference.system:
        writer.writeByte(0);
      case AppThemePreference.light:
        writer.writeByte(1);
      case AppThemePreference.sepia:
        writer.writeByte(2);
      case AppThemePreference.dark:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemePreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      themePreference: fields[0] == null
          ? AppThemePreference.system
          : fields[0] as AppThemePreference,
      libraryGridView: fields[1] == null ? true : fields[1] as bool,
      librarySort: fields[2] == null
          ? LibrarySort.recentlyAdded
          : fields[2] as LibrarySort,
      readerTheme: fields[3] == null
          ? ReaderTheme.auto
          : fields[3] as ReaderTheme,
      readerFontSize: fields[4] == null ? 18 : (fields[4] as num).toDouble(),
      readerLineHeight: fields[5] == null ? 1.6 : (fields[5] as num).toDouble(),
      readerJustify: fields[6] == null ? true : fields[6] as bool,
      annualBookGoal: fields[7] == null ? 12 : (fields[7] as num).toInt(),
      dailyReadingMinutes: fields[8] == null ? 20 : (fields[8] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.themePreference)
      ..writeByte(1)
      ..write(obj.libraryGridView)
      ..writeByte(2)
      ..write(obj.librarySort)
      ..writeByte(3)
      ..write(obj.readerTheme)
      ..writeByte(4)
      ..write(obj.readerFontSize)
      ..writeByte(5)
      ..write(obj.readerLineHeight)
      ..writeByte(6)
      ..write(obj.readerJustify)
      ..writeByte(7)
      ..write(obj.annualBookGoal)
      ..writeByte(8)
      ..write(obj.dailyReadingMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LibrarySortAdapter extends TypeAdapter<LibrarySort> {
  @override
  final typeId = 2;

  @override
  LibrarySort read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LibrarySort.recentlyAdded;
      case 1:
        return LibrarySort.recentlyOpened;
      case 2:
        return LibrarySort.title;
      case 3:
        return LibrarySort.author;
      default:
        return LibrarySort.recentlyAdded;
    }
  }

  @override
  void write(BinaryWriter writer, LibrarySort obj) {
    switch (obj) {
      case LibrarySort.recentlyAdded:
        writer.writeByte(0);
      case LibrarySort.recentlyOpened:
        writer.writeByte(1);
      case LibrarySort.title:
        writer.writeByte(2);
      case LibrarySort.author:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibrarySortAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookFormatAdapter extends TypeAdapter<BookFormat> {
  @override
  final typeId = 3;

  @override
  BookFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BookFormat.epub;
      case 1:
        return BookFormat.pdf;
      case 2:
        return BookFormat.docx;
      default:
        return BookFormat.epub;
    }
  }

  @override
  void write(BinaryWriter writer, BookFormat obj) {
    switch (obj) {
      case BookFormat.epub:
        writer.writeByte(0);
      case BookFormat.pdf:
        writer.writeByte(1);
      case BookFormat.docx:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadingStatusAdapter extends TypeAdapter<ReadingStatus> {
  @override
  final typeId = 4;

  @override
  ReadingStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReadingStatus.toRead;
      case 1:
        return ReadingStatus.reading;
      case 2:
        return ReadingStatus.finished;
      default:
        return ReadingStatus.toRead;
    }
  }

  @override
  void write(BinaryWriter writer, ReadingStatus obj) {
    switch (obj) {
      case ReadingStatus.toRead:
        writer.writeByte(0);
      case ReadingStatus.reading:
        writer.writeByte(1);
      case ReadingStatus.finished:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookAdapter extends TypeAdapter<Book> {
  @override
  final typeId = 5;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Book(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      format: fields[3] as BookFormat,
      fileRef: fields[4] as String,
      originalFileName: fields[5] as String,
      fileSize: (fields[6] as num).toInt(),
      contentHash: fields[7] as String,
      addedAt: fields[8] as DateTime,
      coverRef: fields[9] as String?,
      hasCustomCover: fields[10] == null ? false : fields[10] as bool,
      status: fields[11] == null
          ? ReadingStatus.toRead
          : fields[11] as ReadingStatus,
      shelfIds: fields[12] == null
          ? const []
          : (fields[12] as List).cast<String>(),
      progress: fields[13] == null ? 0 : (fields[13] as num).toDouble(),
      position: fields[14] as String?,
      lastOpenedAt: fields[15] as DateTime?,
      isOwnWork: fields[16] == null ? false : fields[16] as bool,
      sourceManuscriptId: fields[17] as String?,
      finishedAt: fields[18] as DateTime?,
      sourceVersion: fields[19] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.format)
      ..writeByte(4)
      ..write(obj.fileRef)
      ..writeByte(5)
      ..write(obj.originalFileName)
      ..writeByte(6)
      ..write(obj.fileSize)
      ..writeByte(7)
      ..write(obj.contentHash)
      ..writeByte(8)
      ..write(obj.addedAt)
      ..writeByte(9)
      ..write(obj.coverRef)
      ..writeByte(10)
      ..write(obj.hasCustomCover)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.shelfIds)
      ..writeByte(13)
      ..write(obj.progress)
      ..writeByte(14)
      ..write(obj.position)
      ..writeByte(15)
      ..write(obj.lastOpenedAt)
      ..writeByte(16)
      ..write(obj.isOwnWork)
      ..writeByte(17)
      ..write(obj.sourceManuscriptId)
      ..writeByte(18)
      ..write(obj.finishedAt)
      ..writeByte(19)
      ..write(obj.sourceVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShelfAdapter extends TypeAdapter<Shelf> {
  @override
  final typeId = 6;

  @override
  Shelf read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shelf(
      id: fields[0] as String,
      name: fields[1] as String,
      order: (fields[2] as num).toInt(),
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Shelf obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelfAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReaderThemeAdapter extends TypeAdapter<ReaderTheme> {
  @override
  final typeId = 7;

  @override
  ReaderTheme read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReaderTheme.auto;
      case 1:
        return ReaderTheme.light;
      case 2:
        return ReaderTheme.sepia;
      case 3:
        return ReaderTheme.dark;
      default:
        return ReaderTheme.auto;
    }
  }

  @override
  void write(BinaryWriter writer, ReaderTheme obj) {
    switch (obj) {
      case ReaderTheme.auto:
        writer.writeByte(0);
      case ReaderTheme.light:
        writer.writeByte(1);
      case ReaderTheme.sepia:
        writer.writeByte(2);
      case ReaderTheme.dark:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderThemeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HighlightColorAdapter extends TypeAdapter<HighlightColor> {
  @override
  final typeId = 8;

  @override
  HighlightColor read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HighlightColor.oro;
      case 1:
        return HighlightColor.verde;
      case 2:
        return HighlightColor.azul;
      case 3:
        return HighlightColor.rosa;
      default:
        return HighlightColor.oro;
    }
  }

  @override
  void write(BinaryWriter writer, HighlightColor obj) {
    switch (obj) {
      case HighlightColor.oro:
        writer.writeByte(0);
      case HighlightColor.verde:
        writer.writeByte(1);
      case HighlightColor.azul:
        writer.writeByte(2);
      case HighlightColor.rosa:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightColorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HighlightAdapter extends TypeAdapter<Highlight> {
  @override
  final typeId = 9;

  @override
  Highlight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Highlight(
      id: fields[0] as String,
      bookId: fields[1] as String,
      text: fields[2] as String,
      createdAt: fields[9] as DateTime,
      blockIndex: (fields[3] as num?)?.toInt(),
      start: (fields[4] as num?)?.toInt(),
      end: (fields[5] as num?)?.toInt(),
      page: (fields[6] as num?)?.toInt(),
      note: fields[7] as String?,
      color: fields[8] == null
          ? HighlightColor.oro
          : fields[8] as HighlightColor,
      updatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Highlight obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.blockIndex)
      ..writeByte(4)
      ..write(obj.start)
      ..writeByte(5)
      ..write(obj.end)
      ..writeByte(6)
      ..write(obj.page)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.color)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ManuscriptAdapter extends TypeAdapter<Manuscript> {
  @override
  final typeId = 10;

  @override
  Manuscript read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Manuscript(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
      synopsis: fields[2] == null ? '' : fields[2] as String,
      coverRef: fields[4] as String?,
      dailyWordGoal: fields[5] == null ? 500 : (fields[5] as num).toInt(),
      author: fields[3] == null ? '' : fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Manuscript obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.synopsis)
      ..writeByte(3)
      ..write(obj.author)
      ..writeByte(4)
      ..write(obj.coverRef)
      ..writeByte(5)
      ..write(obj.dailyWordGoal)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManuscriptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final typeId = 11;

  @override
  Chapter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chapter(
      id: fields[0] as String,
      manuscriptId: fields[1] as String,
      title: fields[2] as String,
      order: (fields[3] as num).toInt(),
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
      content: fields[4] == null ? '' : fields[4] as String,
      wordCount: fields[5] == null ? 0 : (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.manuscriptId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.order)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.wordCount)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterVersionAdapter extends TypeAdapter<ChapterVersion> {
  @override
  final typeId = 12;

  @override
  ChapterVersion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterVersion(
      id: fields[0] as String,
      chapterId: fields[1] as String,
      manuscriptId: fields[2] as String,
      content: fields[3] as String,
      wordCount: (fields[4] as num).toInt(),
      createdAt: fields[5] as DateTime,
      manual: fields[6] == null ? false : fields[6] as bool,
      label: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChapterVersion obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chapterId)
      ..writeByte(2)
      ..write(obj.manuscriptId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.wordCount)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.manual)
      ..writeByte(7)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterVersionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EntityKindAdapter extends TypeAdapter<EntityKind> {
  @override
  final typeId = 13;

  @override
  EntityKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EntityKind.character;
      case 1:
        return EntityKind.place;
      case 2:
        return EntityKind.object;
      case 3:
        return EntityKind.note;
      default:
        return EntityKind.character;
    }
  }

  @override
  void write(BinaryWriter writer, EntityKind obj) {
    switch (obj) {
      case EntityKind.character:
        writer.writeByte(0);
      case EntityKind.place:
        writer.writeByte(1);
      case EntityKind.object:
        writer.writeByte(2);
      case EntityKind.note:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StoryEntityAdapter extends TypeAdapter<StoryEntity> {
  @override
  final typeId = 14;

  @override
  StoryEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StoryEntity(
      id: fields[0] as String,
      manuscriptId: fields[1] as String,
      kind: fields[2] as EntityKind,
      name: fields[3] as String,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      description: fields[4] == null ? '' : fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StoryEntity obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.manuscriptId)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
