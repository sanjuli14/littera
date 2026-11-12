import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/littera_colors.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/manuscript.dart';
import '../../data/repositories/writing_repository.dart';

IconData entityIcon(EntityKind kind) => switch (kind) {
  EntityKind.character => Icons.person_outline,
  EntityKind.place => Icons.place_outlined,
  EntityKind.object => Icons.category_outlined,
  EntityKind.note => Icons.lightbulb_outline,
};

/// Crea o edita una ficha. Devuelve `true` si se guardó o borró.
Future<bool> showEntityEditor(
  BuildContext context,
  WidgetRef ref, {
  required String manuscriptId,
  StoryEntity? existing,
  EntityKind initialKind = EntityKind.character,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _EntityEditor(
        manuscriptId: manuscriptId,
        existing: existing,
        initialKind: initialKind,
      ),
    ),
  );
  return result ?? false;
}

class _EntityEditor extends ConsumerStatefulWidget {
  const _EntityEditor({
    required this.manuscriptId,
    required this.existing,
    required this.initialKind,
  });

  final String manuscriptId;
  final StoryEntity? existing;
  final EntityKind initialKind;

  @override
  ConsumerState<_EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends ConsumerState<_EntityEditor> {
  late EntityKind _kind = widget.existing?.kind ?? widget.initialKind;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(writingRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.addEntity(
        widget.manuscriptId,
        kind: _kind,
        name: _name.text,
        description: _description.text,
      );
    } else {
      await repo.updateEntity(
        existing.copyWith(
          kind: _kind,
          name: _name.text.trim().isEmpty ? existing.name : _name.text.trim(),
          description: _description.text.trim(),
        ),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final ok = await showConfirmDialog(
      context,
      title: '¿Eliminar "${existing.name}"?',
      message: 'Se borrará esta ficha. No afecta al texto.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(writingRepositoryProvider).deleteEntity(existing.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Nueva ficha' : 'Editar ficha',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in EntityKind.values)
                  ChoiceChip(
                    avatar: Icon(entityIcon(k), size: 18),
                    label: Text(k.label),
                    selected: _kind == k,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Rasgos, historia, detalles que no quieres olvidar…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Guardar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de fichas agrupadas por tipo.
class EntityList extends ConsumerWidget {
  const EntityList({
    super.key,
    required this.manuscriptId,
    this.scrollController,
    this.bottomPadding = 96,
  });

  final String manuscriptId;
  final ScrollController? scrollController;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entities = ref.watch(entitiesOfProvider(manuscriptId));
    if (entities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline,
                size: 56,
                color: LitteraColors.oro,
              ),
              const SizedBox(height: 12),
              Text('Sin fichas todavía', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Apunta personajes, lugares y objetos para tenerlos a mano '
                'mientras escribes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    showEntityEditor(context, ref, manuscriptId: manuscriptId),
                icon: const Icon(Icons.add),
                label: const Text('Nueva ficha'),
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];
    EntityKind? current;
    for (final e in entities) {
      if (e.kind != current) {
        current = e.kind;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              e.kind.pluralLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        );
      }
      children.add(
        ListTile(
          leading: CircleAvatar(
            backgroundColor: LitteraColors.oro.withValues(alpha: 0.2),
            child: Icon(entityIcon(e.kind), color: theme.colorScheme.onSurface),
          ),
          title: Text(e.name),
          subtitle: e.description.isEmpty
              ? null
              : Text(
                  e.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => showEntityEditor(
            context,
            ref,
            manuscriptId: manuscriptId,
            existing: e,
          ),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: children,
    );
  }
}
