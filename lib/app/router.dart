import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/writing/writing_screen.dart';
import 'home_shell.dart';

abstract final class Routes {
  static const library = '/biblioteca';
  static const writing = '/escribir';
  static const settings = '/ajustes';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.library,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.writing,
                builder: (context, state) => const WritingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
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
