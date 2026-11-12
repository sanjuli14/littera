import 'package:flutter/material.dart';

import '../../../app/theme/littera_colors.dart';
import '../../../data/models/book.dart';
import 'book_cover.dart';

/// Libro en la cuadrícula: carátula, título, autor y progreso.
class BookGridTile extends StatelessWidget {
  const BookGridTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
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
    );
  }
}

/// Libro en la vista de lista.
class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
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
                  Row(
                    children: [
                      FormatBadge(format: book.format),
                      const SizedBox(width: 8),
                      Text(
                        book.status.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (book.status == ReadingStatus.reading) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ReadingProgressBar(progress: book.progress),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
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
