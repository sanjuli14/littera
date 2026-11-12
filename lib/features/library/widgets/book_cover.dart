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
  Widget build(BuildContext context, WidgetRef ref) => CoverImage(
    coverRef: book.coverRef,
    title: book.title,
    author: book.author,
    label: book.format.label,
    compact: compact,
    semanticLabel: 'Carátula de ${book.title}',
  );
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
    this.semanticLabel,
  });

  final String? coverRef;
  final String title;
  final String author;
  final String label;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = coverRef;
    final provider = cover == null
        ? null
        : ref.watch(fileStoreProvider).image(cover);
    final generated = GeneratedCover(
      title: title,
      author: author,
      label: label,
      compact: compact,
    );
    final radius = BorderRadius.circular(compact ? 4 : 8);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        // En oscuro, las carátulas color tinta se confunden con el fondo:
        // un borde claro y fino las separa.
        foregroundDecoration: dark
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              )
            : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: compact ? 3 : 8,
                offset: Offset(0, compact ? 1 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: provider == null
                ? generated
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Se decodifica al tamaño en pantalla, no a 600×900:
                      // con muchos libros ahorra mucha memoria.
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      final width = constraints.maxWidth.isFinite
                          ? (constraints.maxWidth * dpr).ceil()
                          : null;
                      return Image(
                        image: ResizeImage.resizeIfNeeded(
                          width,
                          null,
                          provider,
                        ),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        semanticLabel: semanticLabel,
                        errorBuilder: (_, _, _) => generated,
                      );
                    },
                  ),
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
    // Es un dibujo: su texto se escala con el ancho, no con el tamaño de
    // letra del sistema (si no, no cabría en la carátula).
    return MediaQuery.withNoTextScaling(child: _build(context));
  }

  Widget _build(BuildContext context) {
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
