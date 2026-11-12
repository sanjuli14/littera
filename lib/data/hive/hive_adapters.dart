import 'package:hive_ce/hive_ce.dart';

import '../models/app_settings.dart';
import '../models/book.dart';
import '../models/highlight.dart';
import '../models/manuscript.dart';
import '../models/shelf.dart';

part 'hive_adapters.g.dart';

/// Registro de adapters generados.
///
/// Al añadir un modelo nuevo: agregarlo aquí y ejecutar
/// `dart run build_runner build`. Los typeId quedan fijados en
/// `hive_adapters.g.yaml`; ese archivo debe versionarse y nunca editarse a mano.
@GenerateAdapters([
  AdapterSpec<AppThemePreference>(),
  AdapterSpec<AppSettings>(),
  AdapterSpec<LibrarySort>(),
  AdapterSpec<BookFormat>(),
  AdapterSpec<ReadingStatus>(),
  AdapterSpec<Book>(),
  AdapterSpec<Shelf>(),
  AdapterSpec<ReaderTheme>(),
  AdapterSpec<HighlightColor>(),
  AdapterSpec<Highlight>(),
  AdapterSpec<Manuscript>(),
  AdapterSpec<Chapter>(),
  AdapterSpec<ChapterVersion>(),
  AdapterSpec<EntityKind>(),
  AdapterSpec<StoryEntity>(),
])
// ignore: unused_element
void _() {}
