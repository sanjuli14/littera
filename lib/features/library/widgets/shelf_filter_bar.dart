import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../data/repositories/library_repository.dart';
import '../library_actions.dart';
import '../library_providers.dart';

/// Chips horizontales: Todos · Leyendo · Por leer · Terminados · estantes · +.
class ShelfFilterBar extends ConsumerWidget {
  const ShelfFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(libraryFilterProvider);
    final counts = ref.watch(filterCountsProvider);
    final shelves = ref.watch(shelvesProvider).value ?? const [];
    final notifier = ref.read(libraryFilterProvider.notifier);

    Widget chip(LibraryFilter filter, String label, {VoidCallback? onLong}) {
      final count = counts[filter] ?? 0;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onLongPress: onLong,
          child: ChoiceChip(
            label: Text('$label  $count'),
            selected: selected == filter,
            showCheckmark: false,
            onSelected: (_) => notifier.select(filter),
          ),
        ),
      );
    }

    // Sin altura fija: con texto grande los chips crecen y no se cortan.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          chip(const AllBooks(), 'Todos'),
          for (final status in [
            ReadingStatus.reading,
            ReadingStatus.toRead,
            ReadingStatus.finished,
          ])
            chip(ByStatus(status), status.shelfLabel),
          if ((counts[const OwnWorks()] ?? 0) > 0)
            chip(const OwnWorks(), 'Mis obras'),
          for (final shelf in shelves)
            chip(
              ByShelf(shelf.id),
              shelf.name,
              onLong: () => showShelfOptions(context, ref, shelf),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Estante'),
            tooltip: 'Crear estante',
            onPressed: () async {
              final shelf = await createShelf(context, ref);
              if (shelf != null) notifier.select(ByShelf(shelf.id));
            },
          ),
        ],
      ),
    );
  }
}
