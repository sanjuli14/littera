import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/littera_colors.dart';
import '../../../core/storage/file_store.dart';
import '../../../data/models/book.dart';

/// Carátula del libro en proporción 2:3. Si no tiene imagen, dibuja una.
class BookCover extends ConsumerWidget {
  const BookCover({super.key, required this.book, this.compact = false});

  final Book book;

  /// Versión pequeña (listas): menos texto en la carátula generada.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverRef = book.coverRef;
    final image = coverRef == null
        ? null
        : ref.watch(fileStoreProvider).image(coverRef);

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 4 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: compact ? 3 : 8,
              offset: Offset(0, compact ? 1 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 4 : 8),
          child: image == null
              ? GeneratedCover.forBook(book, compact: compact)
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: 'Carátula de ${book.title}',
                  errorBuilder: (_, _, _) =>
                      GeneratedCover.forBook(book, compact: compact),
                ),
        ),
      ),
    );
  }
}

/// Carátula genérica 2:3: imagen guardada o, si no hay, una generada.
class CoverImage extends ConsumerWidget {
  const CoverImage({
    super.key,
    required this.coverRef,
    required this.title,
    this.author = '',
    this.label = '',
    this.compact = false,
  });

  final String? coverRef;
  final String title;
  final String author;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = coverRef;
    final image = cover == null
        ? null
        : ref.watch(fileStoreProvider).image(cover);
    final generated = GeneratedCover(
      title: title,
      author: author,
      label: label,
      compact: compact,
    );
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 4 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: compact ? 3 : 8,
              offset: Offset(0, compact ? 1 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 4 : 8),
          child: image == null
              ? generated
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => generated,
                ),
        ),
      ),
    );
  }
}

/// Carátula dibujada con la paleta de Littera: tinta, marco oro y título.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({
    super.key,
    required this.title,
    this.author = '',
    this.label = '',
    this.compact = false,
  });

  GeneratedCover.forBook(Book book, {super.key, this.compact = false})
    : title = book.title,
      author = book.author,
      label = book.format.label;

  final String title;
  final String author;

  /// Texto pequeño arriba (formato del libro, "MANUSCRITO"…).
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final inset = w * 0.06;
        return Container(
          color: LitteraColors.tinta,
          padding: EdgeInsets.all(inset),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: LitteraColors.oro.withValues(alpha: 0.8),
                width: compact ? 0.8 : 1.4,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.07,
              vertical: w * 0.1,
            ),
            child: compact
                ? Center(
                    child: Text(
                      (title.isEmpty ? '?' : title.characters.first)
                          .toUpperCase(),
                      style: TextStyle(
                        color: LitteraColors.pergamino,
                        fontSize: w * 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: LitteraColors.oro,
                          fontSize: w * 0.065,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LitteraColors.pergamino,
                          fontSize: w * 0.105,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: w * 0.05),
                      Container(
                        width: w * 0.2,
                        height: 1.5,
                        color: LitteraColors.oro,
                      ),
                      SizedBox(height: w * 0.05),
                      if (author.isNotEmpty)
                        Text(
                          author,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: LitteraColors.oro,
                            fontSize: w * 0.075,
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
