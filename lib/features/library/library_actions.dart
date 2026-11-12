import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/dialogs.dart';
import '../../data/models/book.dart';
import '../../data/models/shelf.dart';
import '../../data/repositories/library_repository.dart';
import 'import/book_importer.dart';

/// Abre el selector, importa los archivos elegidos y muestra el resultado.
Future<void> importBooks(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.pickFiles(
    dialogTitle: 'Importar libros',
    type: FileType.custom,
    allowedExtensions: importableExtensions,
  );
  if (picked.isEmpty || !context.mounted) return;

  final importer = ref.read(bookImporterProvider);
  final progress = ValueNotifier<(int, String)>((1, picked.first.name));
  final errors = <(String, String)>[];
  var imported = 0;

  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ImportProgressDialog(progress: progress, total: picked.length),
  );

  for (var i = 0; i < picked.length; i++) {
    final file = picked[i];
    progress.value = (i + 1, file.name);
    try {
      final bytes = await file.readAsBytes();
      await importer.importBytes(file.name, bytes);
      imported++;
    } on ImportException catch (e) {
      errors.add((file.name, e.message));
    } catch (e) {
      errors.add((file.name, 'No se pudo leer el archivo.'));
      debugPrint('Error importando ${file.name}: $e');
    }
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  await dialog;
  progress.dispose();
  if (!context.mounted) return;

  if (errors.isEmpty) {
    showMessage(
      context,
      imported == 1 ? 'Libro importado' : '$imported libros importados',
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        imported == 0
            ? 'No se importó ningún libro'
            : '$imported importados, ${errors.length} con problemas',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (name, message) in errors) ...[
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Text(message),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.progress, required this.total});

  final ValueNotifier<(int, String)> progress;
  final int total;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) {
            final (current, name) = value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 1 ? 'Importando…' : 'Importando $current de $total…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: total == 1 ? null : current / total,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Elige una imagen y la pone como carátula.
Future<void> pickCustomCover(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Elegir carátula',
    type: FileType.image,
  );
  if (file == null) return;
  final ok = await ref
      .read(libraryRepositoryProvider)
      .setCover(book, await file.readAsBytes());
  if (!context.mounted) return;
  showMessage(
    context,
    ok ? 'Carátula actualizada' : 'La imagen no es válida o está dañada',
  );
}

/// Diálogo para crear un estante. Devuelve el estante creado.
Future<Shelf?> createShelf(BuildContext context, WidgetRef ref) async {
  final name = await showTextInputDialog(
    context,
    title: 'Nuevo estante',
    label: 'Nombre',
    confirmLabel: 'Crear',
  );
  if (name == null || name.isEmpty) return null;
  final shelf = await ref.read(libraryRepositoryProvider).createShelf(name);
  if (shelf == null && context.mounted) {
    showMessage(context, 'Ya existe un estante llamado "$name"');
  }
  return shelf;
}

/// Hoja con opciones de un estante: renombrar o eliminar.
Future<void> showShelfOptions(
  BuildContext context,
  WidgetRef ref,
  Shelf shelf,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              shelf.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Renombrar'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Eliminar estante'),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  final repo = ref.read(libraryRepositoryProvider);

  if (action == 'rename') {
    final name = await showTextInputDialog(
      context,
      title: 'Renombrar estante',
      initialValue: shelf.name,
      label: 'Nombre',
    );
    if (name == null || name.isEmpty || name == shelf.name) return;
    final ok = await repo.renameShelf(shelf, name);
    if (!ok && context.mounted) {
      showMessage(context, 'Ya existe un estante llamado "$name"');
    }
  } else if (action == 'delete') {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar "${shelf.name}"?',
      message: 'Los libros no se borran, solo se quitan de este estante.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed) await repo.deleteShelf(shelf);
  }
}
