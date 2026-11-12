import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/backup_screen.dart';
import '../features/library/book_detail_screen.dart';
import '../features/library/library_screen.dart';
import '../features/quotes/quotes_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/writing/chapter_editor_screen.dart';
import '../features/writing/manuscript_screen.dart';
import '../features/writing/writing_screen.dart';
import 'home_shell.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.library,
    routes: [
      // Lector a pantalla completa, sin barra de navegación inferior.
      GoRoute(
        path: '/leer/:id',
        builder: (context, state) => ReaderScreen(
          bookId: state.pathParameters['id']!,
          target: int.tryParse(state.uri.queryParameters['en'] ?? ''),
        ),
      ),
      GoRoute(
        path: Routes.stats,
        builder: (context, state) => const StatsScreen(),
      ),
      // Editor de capítulo a pantalla completa.
      GoRoute(
        path: '/editor/:chapterId',
        builder: (context, state) =>
            ChapterEditorScreen(chapterId: state.pathParameters['chapterId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'libro/:id',
                    builder: (context, state) =>
                        BookDetailScreen(bookId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.quotes,
                builder: (context, state) => const QuotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.writing,
                builder: (context, state) => const WritingScreen(),
                routes: [
                  GoRoute(
                    path: 'obra/:id',
                    builder: (context, state) => ManuscriptScreen(
                      manuscriptId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'copia',
                    builder: (context, state) => const BackupScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
