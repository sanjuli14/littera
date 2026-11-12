import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/littera_colors.dart';
import '../../../app/theme/littera_theme.dart';
import '../../../core/storage/file_store.dart';
import '../../../core/widgets/soft_blobs.dart';
import '../../../core/widgets/soft_card.dart';
import '../greeting.dart';
import '../../../data/models/book.dart';
import 'book_cover.dart';
import 'book_tiles.dart';

/// Título de sección con "Ver todo" opcional a la derecha.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('Ver todo')),
        ],
      ),
    );
  }
}

/// Tarjeta destacada: el último libro que estabas leyendo.
class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cover = book.coverRef;
    final image = cover == null
        ? null
        : ref.watch(fileStoreProvider).image(cover);
    final percent = (book.progress * 100).round();
    void read() => context.push(Routes.reader(book.id));
    // En oscuro, la tarjeta es carbón cálido (no azul).
    final dark = theme.brightness == Brightness.dark;
    final base = dark ? LitteraColors.nocheAlta : LitteraColors.tinta;
    final base2 = dark ? LitteraColors.nocheBorde : LitteraColors.tintaMedia;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Semantics(
        button: true,
        label:
            'Continúa leyendo ${book.title}'
            '${book.author.isEmpty ? '' : ', de ${book.author}'}, '
            '$percent % leído',
        onTap: read,
        excludeSemantics: true,
        child: SoftCard(
          radius: LitteraTheme.radiusHero,
          color: base,
          child: InkWell(
            onTap: read,
            child: Stack(
              children: [
                // Fondo: la carátula difuminada o un degradado de la paleta.
                Positioned.fill(
                  child: image == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [base, base2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        )
                      : ImageFiltered(
                          // clamp: sin halo claro en los bordes del desenfoque.
                          imageFilter: ImageFilter.blur(
                            sigmaX: 18,
                            sigmaY: 18,
                            tileMode: TileMode.clamp,
                          ),
                          child: Image(
                            image: ResizeImage.resizeIfNeeded(200, null, image),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          base.withValues(alpha: 0.55),
                          base.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 92, child: BookCover(book: book)),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIGUE LEYENDO',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: LitteraColors.oro,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            if (book.author.isNotEmpty)
                              Text(
                                book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: LitteraColors.pergamino.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: book.progress.clamp(0, 1),
                                      minHeight: 5,
                                      color: LitteraColors.oro,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$percent %',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: read,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: LitteraColors.tinta,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Seguir leyendo',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_right, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carrusel horizontal de carátulas grandes con título y autor.
class BookCarousel extends StatelessWidget {
  const BookCarousel({super.key, required this.books});

  final List<Book> books;

  static const _coverWidth = 116.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // Alto: carátula + título (2 líneas) + autor, según el tamaño de letra.
    final height =
        _coverWidth * 1.5 +
        10 +
        scaler.scale(theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.25 * 2 +
        scaler.scale(theme.textTheme.bodySmall?.fontSize ?? 12) * 1.45 +
        8;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final book = books[i];
          return Semantics(
            button: true,
            label: bookSemanticsLabel(book),
            onTap: () => context.push(Routes.book(book.id)),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => context.push(Routes.book(book.id)),
              child: SizedBox(
                width: _coverWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookCover(book: book),
                    const SizedBox(height: 10),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (book.author.isNotEmpty)
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cabecera de Inicio: saludo e invitación a leer, sobre manchas suaves
/// de la paleta.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SoftBlobs(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting(now),
              style: theme.textTheme.headlineMedium?.copyWith(height: 1.1),
            ),
            const SizedBox(height: 4),
            Text(
              invitation(now),
              style: TextStyle(
                fontFamily: LitteraTheme.serif,
                fontStyle: FontStyle.italic,
                fontSize: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
