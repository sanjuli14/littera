import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/soft_card.dart';

import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/manuscript.dart';
import '../../data/repositories/writing_repository.dart';
import '../library/widgets/book_cover.dart';

/// Pestaña "Escribir": lista de manuscritos.
class WritingScreen extends ConsumerWidget {
  const WritingScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final title = await showTextInputDialog(
      context,
      title: 'Nueva obra',
      label: 'Título',
      confirmLabel: 'Crear',
    );
    if (title == null || !context.mounted) return;
    final m = await ref.read(writingRepositoryProvider).createManuscript(title);
    if (context.mounted) context.push(Routes.manuscript(m.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manuscripts = ref.watch(manuscriptsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Escribir')),
      floatingActionButton: manuscripts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nueva obra'),
            ),
      body: manuscripts.isEmpty
          ? EmptyState(
              icon: const Icon(
                Icons.edit_note,
                size: 96,
                color: LitteraColors.oro,
              ),
              title: 'Aún no tienes manuscritos',
              message:
                  'Crea tu primera obra y organízala por capítulos. '
                  'Se guarda sola mientras escribes.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nueva obra'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: manuscripts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _ManuscriptCard(manuscript: manuscripts[i]),
            ),
    );
  }
}

class _ManuscriptCard extends ConsumerWidget {
  const _ManuscriptCard({required this.manuscript});

  final Manuscript manuscript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chapters = ref.watch(chaptersOfProvider(manuscript.id));
    final words = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);

    return SoftCard(
      child: InkWell(
        onTap: () => context.push(Routes.manuscript(manuscript.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: CoverImage(
                  coverRef: manuscript.coverRef,
                  title: manuscript.title,
                  author: manuscript.author,
                  compact: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manuscript.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${chapters.length} '
                      '${chapters.length == 1 ? 'capítulo' : 'capítulos'} · '
                      '${formatWordCount(words)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Editado el ${formatDate(manuscript.updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// `1 palabra`, `12.345 palabras`.
String formatWordCount(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$buffer ${n == 1 ? 'palabra' : 'palabras'}';
}
