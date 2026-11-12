import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../library/import/book_importer.dart';
import 'export_service.dart';

class ExportOptions {
  const ExportOptions(
    this.format, {
    required this.save,
    required this.addToLibrary,
  });
  final ExportFormat format;
  final bool save;
  final bool addToLibrary;
}

/// Pregunta formato y destino, exporta y muestra el resultado.
Future<void> exportManuscript(
  BuildContext context,
  WidgetRef ref,
  String manuscriptId,
) async {
  final options = await showModalBottomSheet<ExportOptions>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ExportSheet(),
  );
  if (options == null || !context.mounted) return;

  final service = ref.read(exportServiceProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text('Generando ${options.format.label}…')),
          ],
        ),
      ),
    ),
  );

  ExportedFile? file;
  String? bookId;
  String? error;
  try {
    file = await service.export(manuscriptId, options.format);
    if (options.addToLibrary) {
      bookId = (await service.addToLibrary(manuscriptId, file)).id;
    }
  } on ExportException catch (e) {
    error = e.message;
  } on ImportException catch (e) {
    error = e.message;
  } catch (e) {
    error = 'No se pudo exportar: $e';
  } finally {
    navigator.pop();
    await dialog;
  }
  if (!context.mounted) return;
  if (error != null || file == null) {
    showMessage(context, error ?? 'No se pudo exportar');
    return;
  }

  var saved = false;
  if (options.save) {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar ${file.format.label}',
        fileName: file.fileName,
        bytes: file.bytes,
        mimeType: file.mimeType,
      );
      saved = uri != null || kIsWeb;
    } catch (e) {
      if (context.mounted) showMessage(context, 'No se pudo guardar: $e');
      return;
    }
  }
  if (!context.mounted) return;

  final parts = [
    if (saved) 'Archivo guardado (${formatFileSize(file.bytes.length)})',
    if (bookId != null) 'añadida a tu biblioteca',
  ];
  if (parts.isEmpty) return; // canceló el guardado
  final text = parts.join(' y ');
  final id = bookId;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${text[0].toUpperCase()}${text.substring(1)}'),
        action: id == null
            ? null
            : SnackBarAction(
                label: 'Ver',
                onPressed: () => context.go(Routes.book(id)),
              ),
      ),
    );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  ExportFormat _format = ExportFormat.epub;
  bool _save = true;
  bool _addToLibrary = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Exportar obra', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<ExportFormat>(
              segments: const [
                ButtonSegment(
                  value: ExportFormat.epub,
                  icon: Icon(Icons.menu_book),
                  label: Text('EPUB'),
                ),
                ButtonSegment(
                  value: ExportFormat.pdf,
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: Text('PDF'),
                ),
              ],
              selected: {_format},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _format == ExportFormat.epub
                  ? 'Para lectores electrónicos y móviles: el texto se adapta '
                        'a la pantalla.'
                  : 'Para imprimir o compartir: páginas A5 fijas, con índice y '
                        'números de página.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _addToLibrary,
              activeThumbColor: LitteraColors.oro,
              onChanged: (v) => setState(() => _addToLibrary = v),
              title: const Text('Añadir a mi biblioteca'),
              subtitle: const Text(
                'Para leerla y subrayarla como un libro más. Si ya la '
                'exportaste antes, se actualiza.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _save,
              activeThumbColor: LitteraColors.oro,
              onChanged: (v) => setState(() => _save = v),
              title: const Text('Guardar el archivo'),
              subtitle: const Text('Elige dónde: Drive, Descargas, correo…'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save || _addToLibrary
                  ? () => Navigator.pop(
                      context,
                      ExportOptions(
                        _format,
                        save: _save,
                        addToLibrary: _addToLibrary,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.ios_share),
              label: Text('Exportar ${_format.label}'),
            ),
          ],
        ),
      ),
    );
  }
}
