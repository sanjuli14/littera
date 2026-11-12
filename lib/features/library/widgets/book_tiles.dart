import 'package:flutter/material.dart';

import '../../../app/theme/littera_colors.dart';
import '../../../data/models/book.dart';
import 'book_cover.dart';

/// Libro en la cuadrícula: carátula, título, autor y progreso.
class BookGridTile extends StatelessWidget {
  const BookGridTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  /// Alto de una tarjeta para el ancho disponible de la cuadrícula.
  static double extentFor(BuildContext context, double gridWidth) {
    const maxExtent = 160.0, spacing = 8.0;
    final columns = (gridWidth / (maxExtent + spacing)).ceil().clamp(1, 99);
    final tileWidth = (gridWidth - spacing * (columns - 1)) / columns;
    final coverHeight = (tileWidth - 8) * 1.5;
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? s, double height) =>
        scaler.scale(s?.fontSize ?? 14) * height;
    final text =
        line(theme.bodyMedium, 1.25) * 2 + // título (2 líneas)
        line(theme.bodySmall, 1.45) + // autor
        9; // progreso
    return 8 + coverHeight + 8 + text + 8;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: bookSemanticsLabel(book),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'cover-${book.id}',
                child: BookCover(book: book),
              ),
              const SizedBox(height: 8),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
              if (book.status == ReadingStatus.reading) ...[
                const SizedBox(height: 6),
                ReadingProgressBar(progress: book.progress),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que lee un lector de pantalla al llegar a un libro.
String bookSemanticsLabel(Book book) {
  final parts = [
    book.title,
    if (book.author.isNotEmpty) 'de ${book.author}',
    book.status.label,
    if (book.status == ReadingStatus.reading && book.progress > 0)
      '${(book.progress * 100).round()} % leído',
    if (book.isOwnWork) 'obra propia',
  ];
  return parts.join(', ');
}

/// Libro en la vista de lista.
class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: bookSemanticsLabel(book),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Hero(
                  tag: 'cover-${book.id}',
                  child: BookCover(book: book, compact: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.author.isNotEmpty)
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FormatBadge(format: book.format),
                        Text(
                          book.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (book.status == ReadingStatus.reading)
                          SizedBox(
                            width: 96,
                            child: ReadingProgressBar(progress: book.progress),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progreso ${(progress * 100).round()} %',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 3,
          color: LitteraColors.oro,
          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class FormatBadge extends StatelessWidget {
  const FormatBadge({super.key, required this.format});

  final BookFormat format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: LitteraColors.oro),
      ),
      child: Text(
        format.label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
