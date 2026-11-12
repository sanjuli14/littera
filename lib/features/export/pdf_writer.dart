import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../reader/document/reader_document.dart';
import 'manuscript_compiler.dart';

/// Fuentes TTF para el PDF (las estándar de PDF no traen bien tildes y ñ).
class PdfFontData {
  const PdfFontData({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  final ByteData regular;
  final ByteData bold;
  final ByteData italic;
  final ByteData boldItalic;
}

/// Datos de entrada (enviables a un isolate).
class PdfJob {
  const PdfJob(this.book, this.fonts, this.coverJpeg);
  final CompiledBook book;
  final PdfFontData fonts;
  final Uint8List? coverJpeg;
}

const _pageFormat = PdfPageFormat.a5;
const _fontSize = 11.0;

/// Genera el PDF: carátula, portada y un capítulo por página nueva, con
/// marcadores (índice) por capítulo y número de página al pie.
Future<Uint8List> buildPdf(PdfJob job) async {
  final book = job.book;
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(job.fonts.regular),
    bold: pw.Font.ttf(job.fonts.bold),
    italic: pw.Font.ttf(job.fonts.italic),
    boldItalic: pw.Font.ttf(job.fonts.boldItalic),
  );
  final doc = pw.Document(
    theme: theme,
    title: book.title,
    author: book.author.isEmpty ? null : book.author,
    creator: 'Littera',
  );

  if (job.coverJpeg != null) {
    doc.addPage(
      pw.Page(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox.expand(
          child: pw.Image(pw.MemoryImage(job.coverJpeg!), fit: pw.BoxFit.cover),
        ),
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: _pageFormat,
      build: (_) => pw.Center(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              book.title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            if (book.author.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(book.author, style: const pw.TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    ),
  );

  for (final chapter in book.chapters) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(44, 48, 44, 40),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.Header(
            level: 0,
            text: chapter.title,
            decoration: const pw.BoxDecoration(),
            margin: const pw.EdgeInsets.only(top: 40, bottom: 28),
            textStyle: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          ...chapter.blocks.expand(_blockWidgets),
        ],
      ),
    );
  }

  return doc.save();
}

pw.TextSpan _spans(List<TextRun> runs) => pw.TextSpan(
  children: [
    for (final r in runs)
      pw.TextSpan(
        text: r.text,
        style: pw.TextStyle(
          fontWeight: r.bold ? pw.FontWeight.bold : null,
          fontStyle: r.italic ? pw.FontStyle.italic : null,
        ),
      ),
  ],
);

pw.Widget _rich(pw.TextSpan text, pw.TextStyle style, pw.TextAlign align) =>
    pw.RichText(
      text: pw.TextSpan(style: style, children: [text]),
      textAlign: align,
    );

/// Cada bloque se dibuja con widgets que se pueden partir entre páginas
/// (RichText), separados por espacios.
Iterable<pw.Widget> _blockWidgets(DocBlock block) sync* {
  switch (block) {
    case HeadingBlock(:final level, :final runs):
      yield pw.SizedBox(height: 10);
      yield _rich(
        _spans(runs),
        pw.TextStyle(
          fontSize: level <= 2 ? 14 : 12,
          fontWeight: pw.FontWeight.bold,
        ),
        pw.TextAlign.left,
      );
      yield pw.SizedBox(height: 6);
    case ParagraphBlock(:final kind, :final runs):
      yield _rich(
        kind == ParagraphKind.listItem
            ? pw.TextSpan(
                children: [
                  const pw.TextSpan(text: '•  '),
                  _spans(runs),
                ],
              )
            : _spans(runs),
        pw.TextStyle(
          fontSize: _fontSize,
          lineSpacing: 3,
          fontStyle: kind == ParagraphKind.quote ? pw.FontStyle.italic : null,
        ),
        switch (kind) {
          ParagraphKind.center => pw.TextAlign.center,
          ParagraphKind.listItem ||
          ParagraphKind.preformatted => pw.TextAlign.left,
          _ => pw.TextAlign.justify,
        },
      );
      yield pw.SizedBox(height: 5);
    case SeparatorBlock():
      yield pw.Center(child: pw.Text('*  *  *'));
      yield pw.SizedBox(height: 8);
    case ImageBlock():
      break;
  }
}
