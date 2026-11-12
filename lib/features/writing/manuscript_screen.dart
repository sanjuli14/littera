import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/manuscript.dart';
import '../../data/repositories/writing_repository.dart';
import '../library/widgets/book_cover.dart';
import 'entity_widgets.dart';
import 'writing_screen.dart';

/// Ficha de una obra: datos, meta diaria, capítulos y fichas.
class ManuscriptScreen extends ConsumerWidget {
  const ManuscriptScreen({super.key, required this.manuscriptId});

  final String manuscriptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(manuscriptProvider(manuscriptId));
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Esta obra ya no existe')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return Scaffold(
            appBar: AppBar(
              title: Text(m.title, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar datos',
                  onPressed: () => _editDetails(context, ref, m),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  onSelected: (v) => switch (v) {
                    'cover' => _pickCover(context, ref, m),
                    'remove-cover' =>
                      ref.read(writingRepositoryProvider).removeCover(m),
                    'delete' => _delete(context, ref, m),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'cover',
                      child: ListTile(
                        leading: Icon(Icons.image_outlined),
                        title: Text('Cambiar carátula'),
                      ),
                    ),
                    if (m.coverRef != null)
                      const PopupMenuItem(
                        value: 'remove-cover',
                        child: ListTile(
                          leading: Icon(Icons.hide_image_outlined),
                          title: Text('Usar carátula generada'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Eliminar obra'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            floatingActionButton: ListenableBuilder(
              listenable: tabs,
              builder: (context, _) => tabs.index == 0
                  ? FloatingActionButton.extended(
                      heroTag: 'add-chapter',
                      onPressed: () async {
                        final c = await ref
                            .read(writingRepositoryProvider)
                            .addChapter(m.id);
                        if (context.mounted) {
                          context.push(Routes.chapterEditor(c.id));
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Capítulo'),
                    )
                  : FloatingActionButton.extended(
                      heroTag: 'add-entity',
                      onPressed: () =>
                          showEntityEditor(context, ref, manuscriptId: m.id),
                      icon: const Icon(Icons.add),
                      label: const Text('Ficha'),
                    ),
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(child: _Header(manuscript: m)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      tabs: const [
                        Tab(text: 'Capítulos'),
                        Tab(text: 'Fichas'),
                      ],
                      indicatorColor: LitteraColors.oro,
                      labelColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    Theme.of(context).colorScheme.surface,
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _ChapterList(manuscriptId: m.id),
                  EntityList(manuscriptId: m.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCover(
    BuildContext context,
    WidgetRef ref,
    Manuscript m,
  ) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Elegir carátula',
      type: FileType.image,
    );
    if (file == null) return;
    final ok = await ref
        .read(writingRepositoryProvider)
        .setCover(m, await file.readAsBytes());
    if (context.mounted && !ok) {
      showMessage(context, 'La imagen no es válida o está dañada');
    }
  }

  Future<void> _editDetails(
    BuildContext context,
    WidgetRef ref,
    Manuscript m,
  ) async {
    final updated = await showDialog<Manuscript>(
      context: context,
      builder: (_) => _EditManuscriptDialog(manuscript: m),
    );
    if (updated != null) {
      await ref.read(writingRepositoryProvider).updateManuscript(updated);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Manuscript m,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: '¿Eliminar "${m.title}"?',
      message:
          'Se borrarán todos sus capítulos, versiones y fichas. '
          'No se puede deshacer. Si quieres conservarla, haz antes una copia '
          'de seguridad.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    context.pop();
    await ref.read(writingRepositoryProvider).deleteManuscript(m);
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.manuscript});

  final Manuscript manuscript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final m = manuscript;
    final chapters = ref.watch(chaptersOfProvider(m.id));
    final words = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);
    final today = ref.watch(wordsTodayProvider(m.id));
    final goal = m.dailyWordGoal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: CoverImage(
              coverRef: m.coverRef,
              title: m.title,
              author: m.author,
              label: 'MANUSCRITO',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.author.isNotEmpty)
                  Text(m.author, style: theme.textTheme.titleSmall),
                Text(
                  formatWordCount(words),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${chapters.length} '
                  '${chapters.length == 1 ? 'capítulo' : 'capítulos'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (goal > 0) ...[
                  Text(
                    today >= goal
                        ? '¡Meta de hoy cumplida! $today / $goal'
                        : 'Hoy: $today / $goal palabras',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (today / goal).clamp(0, 1),
                      minHeight: 6,
                      color: LitteraColors.oro,
                      backgroundColor: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ] else
                  Text(
                    'Hoy: ${formatWordCount(today)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                if (m.synopsis.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    m.synopsis,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterList extends ConsumerWidget {
  const _ChapterList({required this.manuscriptId});

  final String manuscriptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chapters = ref.watch(chaptersOfProvider(manuscriptId));
    final repo = ref.read(writingRepositoryProvider);

    if (chapters.isEmpty) {
      return Center(
        child: Text(
          'Sin capítulos. Pulsa "Capítulo" para empezar.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: chapters.length,
      buildDefaultDragHandles: false,
      onReorderItem: (oldIndex, newIndex) {
        final ids = chapters.map((c) => c.id).toList();
        ids.insert(newIndex, ids.removeAt(oldIndex));
        repo.reorderChapters(manuscriptId, ids);
      },
      itemBuilder: (context, i) {
        final c = chapters[i];
        return ListTile(
          key: ValueKey(c.id),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: LitteraColors.oro.withValues(alpha: 0.2),
            child: Text(
              '${i + 1}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(c.title),
          subtitle: Text(
            '${formatWordCount(c.wordCount)} · ${formatDate(c.updatedAt)}',
          ),
          onTap: () => context.push(Routes.chapterEditor(c.id)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Opciones del capítulo',
                onSelected: (v) async {
                  if (v == 'rename') {
                    final title = await showTextInputDialog(
                      context,
                      title: 'Renombrar capítulo',
                      initialValue: c.title,
                      label: 'Título',
                    );
                    if (title != null) await repo.renameChapter(c, title);
                  } else if (v == 'delete') {
                    final ok = await showConfirmDialog(
                      context,
                      title: '¿Eliminar "${c.title}"?',
                      message:
                          'Se borrarán su texto y sus versiones. '
                          'No se puede deshacer.',
                      confirmLabel: 'Eliminar',
                      destructive: true,
                    );
                    if (ok) await repo.deleteChapter(c);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, semanticLabel: 'Mover'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}

class _EditManuscriptDialog extends StatefulWidget {
  const _EditManuscriptDialog({required this.manuscript});
  final Manuscript manuscript;

  @override
  State<_EditManuscriptDialog> createState() => _EditManuscriptDialogState();
}

class _EditManuscriptDialogState extends State<_EditManuscriptDialog> {
  late final _title = TextEditingController(text: widget.manuscript.title);
  late final _author = TextEditingController(text: widget.manuscript.author);
  late final _synopsis = TextEditingController(
    text: widget.manuscript.synopsis,
  );
  late final _goal = TextEditingController(
    text: widget.manuscript.dailyWordGoal.toString(),
  );

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _synopsis.dispose();
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Datos de la obra'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _author,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Autor o seudónimo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _synopsis,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Sinopsis'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Meta diaria de palabras',
                helperText: '0 = sin meta',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final m = widget.manuscript;
            final goal = int.tryParse(_goal.text.trim());
            Navigator.pop(
              context,
              m.copyWith(
                title: _title.text.trim().isEmpty
                    ? m.title
                    : _title.text.trim(),
                author: _author.text.trim(),
                synopsis: _synopsis.text.trim(),
                dailyWordGoal: goal == null || goal < 0
                    ? m.dailyWordGoal
                    : goal,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
