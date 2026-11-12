import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../data/repositories/library_repository.dart';
import 'backup_service.dart';

/// Días sin copia a partir de los cuales se recuerda hacer una.
const backupReminderDays = 14;

/// Libros mínimos para empezar a recordar (no molestar al principio).
const backupReminderMinBooks = 3;

/// Cerrado por el usuario durante esta sesión.
class _DismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final _dismissedProvider = NotifierProvider<_DismissedNotifier, bool>(
  _DismissedNotifier.new,
);

final shouldRemindBackupProvider = Provider<bool>((ref) {
  if (ref.watch(_dismissedProvider)) return false;
  final books = ref.watch(booksProvider).value ?? const [];
  if (books.length < backupReminderMinBooks) return false;
  final last = ref.watch(lastBackupProvider);
  return last == null ||
      DateTime.now().difference(last).inDays >= backupReminderDays;
});

/// Aviso discreto en la biblioteca para hacer una copia.
class BackupReminder extends ConsumerWidget {
  const BackupReminder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(shouldRemindBackupProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final last = ref.watch(lastBackupProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: LitteraColors.oro.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: LitteraColors.oro),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  last == null
                      ? 'Haz una copia para no perder tu biblioteca'
                      : 'Hace ${DateTime.now().difference(last).inDays} días '
                            'de tu última copia',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go(Routes.backup),
                child: const Text('Hacer copia'),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Ahora no',
                onPressed: ref.read(_dismissedProvider.notifier).dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
