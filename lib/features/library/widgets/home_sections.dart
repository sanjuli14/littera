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
import '../../../data/repositories/highlights_repository.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/stats_repository.dart';
import '../daily_quote.dart';
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
          color: LitteraColors.tinta,
          child: InkWell(
            onTap: read,
            child: Stack(
              children: [
                // Fondo: la carátula difuminada o un degradado de la paleta.
                Positioned.fill(
                  child: image == null
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                LitteraColors.tinta,
                                LitteraColors.tintaMedia,
                              ],
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
                          LitteraColors.tinta.withValues(alpha: 0.55),
                          LitteraColors.tinta.withValues(alpha: 0.9),
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

/// Cabecera de Inicio: saludo, invitación a leer, racha y meta del día,
/// sobre manchas suaves de la paleta.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(readingLogProvider);
    final stats = ref.read(statsRepositoryProvider);
    final now = DateTime.now();
    final streak = stats.readingStreak(now);
    final minutes = stats.readingSecondsOn(now) ~/ 60;
    final goal = ref.watch(
      settingsProvider.select((s) => s.dailyReadingMinutes),
    );
    final dark = theme.brightness == Brightness.dark;

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
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: LitteraColors.oro,
                  text: streak == 0
                      ? 'Empieza tu racha hoy'
                      : streak == 1
                      ? '1 día leyendo'
                      : '$streak días seguidos',
                  dark: dark,
                ),
                if (goal > 0)
                  _InfoPill(
                    leading: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: (minutes / goal).clamp(0, 1),
                        strokeWidth: 3,
                        color: LitteraColors.oro,
                        backgroundColor: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    text: minutes >= goal
                        ? '¡Meta de hoy cumplida!'
                        : '$minutes de $goal min hoy',
                    dark: dark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.text,
    required this.dark,
    this.icon,
    this.iconColor,
    this.leading,
  });

  final String text;
  final bool dark;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? LitteraColors.tintaClara : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: LitteraColors.tinta.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?leading,
          if (icon != null) Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cita del día en serif sobre pergamino, con comillas grandes en oro.
class QuoteOfTheDayCard extends ConsumerWidget {
  const QuoteOfTheDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highlights = ref.watch(allHighlightsProvider).value ?? const [];
    final books = {
      for (final b in ref.watch(booksProvider).value ?? const <Book>[]) b.id: b,
    };
    final quote = quoteOfTheDay(
      highlights,
      (id) => books[id]?.title ?? 'Tus citas',
    );
    final h = quote.highlight;
    final canOpen = h != null && books.containsKey(h.bookId);
    void open() =>
        context.push(Routes.reader(h!.bookId, target: h.blockIndex ?? h.page));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        container: true,
        label: 'Cita del día: ${quote.text}. ${quote.source}',
        button: canOpen,
        onTap: canOpen ? open : null,
        excludeSemantics: true,
        child: SoftCard(
          radius: LitteraTheme.radiusHero,
          color: dark ? LitteraColors.tintaClara : LitteraColors.pergamino,
          child: InkWell(
            onTap: canOpen ? open : null,
            child: Stack(
              children: [
                Positioned(
                  right: 14,
                  top: -18,
                  child: Text(
                    '”',
                    style: TextStyle(
                      fontFamily: LitteraTheme.serif,
                      fontSize: 120,
                      height: 1,
                      color: LitteraColors.oro.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h == null ? 'CITA DEL DÍA' : 'DE TUS SUBRAYADOS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: dark
                              ? LitteraColors.oro
                              : LitteraColors.oroOscuro,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        quote.text,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: LitteraTheme.serif,
                          fontStyle: FontStyle.italic,
                          fontSize: 19,
                          height: 1.45,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '— ${quote.source}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
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
