import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/writing_repository.dart';
import 'backup_service.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final books = ref.watch(booksProvider).value ?? const [];
    final shelves = ref.watch(shelvesProvider).value ?? const [];
    final lastBackup = ref.watch(lastBackupProvider);
    final totalSize = books.fold<int>(0, (sum, b) => sum + b.fileSize);
    final manuscripts = ref.watch(manuscriptsProvider).value ?? const [];
    final hasBooks = books.isNotEmpty || manuscripts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: LitteraColors.oro,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lastBackupLabel(lastBackup),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu biblioteca se guarda solo en este dispositivo. Si '
                    'borras la app o cambias de teléfono, la perderás. Exporta '
                    'una copia y guárdala en Drive, tu correo o tu computadora.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${books.length} ${books.length == 1 ? 'libro' : 'libros'}'
                    ' · ${shelves.length} '
                    '${shelves.length == 1 ? 'estante' : 'estantes'}'
                    ' · ${manuscripts.length} '
                    '${manuscripts.length == 1 ? 'obra' : 'obras'}'
                    ' · ${formatFileSize(totalSize)}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Exportar'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: hasBooks
                ? () => _export(context, ref, includeBookFiles: true)
                : null,
            icon: const Icon(Icons.download),
            label: const Text('Exportar copia completa'),
          ),
          const _Hint(
            'Libros, carátulas, progreso, estantes, citas, tus obras y '
            'ajustes. '
            'Con esto puedes recuperarlo todo.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: hasBooks
                ? () => _export(context, ref, includeBookFiles: false)
                : null,
            icon: const Icon(Icons.data_object),
            label: const Text('Exportar solo datos'),
          ),
          const _Hint(
            'Todo menos los archivos de los libros: progreso, estantes, '
            'citas, tus obras y ajustes. Muy ligera; sirve para guardar tus '
            'obras o pasar tu progreso a otro dispositivo que ya tenga los '
            'libros.',
          ),
          const SizedBox(height: 28),
          _SectionTitle('Restaurar'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _restore(context, ref),
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar desde un archivo .littera'),
          ),
          const _Hint(
            'Podrás elegir entre añadir lo que falta o reemplazar tu '
            'biblioteca actual.',
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool includeBookFiles,
  }) async {
    final service = ref.read(backupServiceProvider);
    final bytes = await _withProgress(
      context,
      'Preparando copia…',
      () => service.create(includeBookFiles: includeBookFiles),
    );
    if (bytes == null || !context.mounted) return;

    final Uri? saved;
    try {
      saved = await FilePicker.saveFile(
        dialogTitle: 'Guardar copia de Littera',
        fileName: BackupService.suggestedFileName(
          includeBookFiles: includeBookFiles,
        ),
        bytes: bytes,
      );
    } catch (e) {
      if (context.mounted) showMessage(context, 'No se pudo guardar: $e');
      return;
    }
    // En Web la descarga no devuelve ruta.
    if (saved == null && !kIsWeb) return;
    await ref.read(lastBackupProvider.notifier).mark();
    if (context.mounted) {
      showMessage(context, 'Copia guardada (${formatFileSize(bytes.length)})');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Elegir copia de Littera',
    );
    if (file == null || !context.mounted) return;

    final service = ref.read(backupServiceProvider);
    BackupContents contents;
    try {
      final bytes = await file.readAsBytes();
      contents = service.read(bytes);
    } on BackupException catch (e) {
      if (context.mounted) {
        await _showError(context, e.message);
      }
      return;
    } catch (_) {
      if (context.mounted) {
        await _showError(context, 'No se pudo leer el archivo.');
      }
      return;
    }
    if (!context.mounted) return;

    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (_) => _RestoreDialog(contents: contents),
    );
    if (mode == null || !context.mounted) return;

    if (mode == RestoreMode.replace) {
      final confirmed = await showConfirmDialog(
        context,
        title: '¿Reemplazar tu biblioteca?',
        message:
            'Se borrarán los libros, estantes y ajustes actuales y se '
            'sustituirán por los de la copia. No se puede deshacer.',
        confirmLabel: 'Reemplazar',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    RestoreResult? result;
    try {
      result = await _withProgress(
        context,
        'Restaurando…',
        () => service.restore(contents, mode),
      );
    } on BackupException catch (e) {
      if (context.mounted) await _showError(context, e.message);
      return;
    }
    if (result == null || !context.mounted) return;
    await ref
        .read(lastBackupProvider.notifier)
        .markAtLeast(contents.manifest.createdAt);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: LitteraColors.oro),
        title: const Text('Restauración completada'),
        content: Text(restoreSummary(result!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _showError(BuildContext context, String message) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se pudo restaurar'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );

  /// Ejecuta [task] con un diálogo de espera. Devuelve `null` si falla con
  /// un error inesperado (y lo muestra).
  Future<T?> _withProgress<T>(
    BuildContext context,
    String label,
    Future<T> Function() task,
  ) async {
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
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      return await task();
    } on BackupException {
      rethrow;
    } catch (e) {
      if (context.mounted) showMessage(context, 'Algo salió mal: $e');
      return null;
    } finally {
      navigator.pop();
      await dialog;
    }
  }
}

/// `1 obra`, `3 obras`.
String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// "Última copia: 12 nov 2026 (hace 3 días)".
String lastBackupLabel(DateTime? last, {DateTime? now}) {
  if (last == null) return 'Aún no has hecho ninguna copia';
  final days = (now ?? DateTime.now()).difference(last).inDays;
  final ago = switch (days) {
    0 => 'hoy',
    1 => 'ayer',
    _ => 'hace $days días',
  };
  return 'Última copia: ${formatDate(last)} ($ago)';
}

String restoreSummary(RestoreResult r) {
  final parts = <String>[
    if (r.added > 0)
      '${r.added} ${r.added == 1 ? 'libro añadido' : 'libros añadidos'}',
    if (r.updated > 0)
      '${r.updated} ${r.updated == 1 ? 'libro actualizado' : 'libros actualizados'}',
    if (r.manuscriptsAdded > 0)
      '${r.manuscriptsAdded} ${r.manuscriptsAdded == 1 ? 'obra añadida' : 'obras añadidas'}',
    if (r.manuscriptsUpdated > 0)
      '${r.manuscriptsUpdated} ${r.manuscriptsUpdated == 1 ? 'obra actualizada' : 'obras actualizadas'}',
    if (r.highlightsAdded > 0)
      '${r.highlightsAdded} ${r.highlightsAdded == 1 ? 'subrayado' : 'subrayados'}',
    if (r.shelvesAdded > 0)
      '${r.shelvesAdded} ${r.shelvesAdded == 1 ? 'estante nuevo' : 'estantes nuevos'}',
  ];
  var text = parts.isEmpty
      ? 'Tu biblioteca ya estaba al día.'
      : '${parts.join(', ')}.';
  if (r.skipped > 0) {
    text +=
        '\n\n${r.skipped} ${r.skipped == 1 ? 'libro no se restauró' : 'libros no se restauraron'} '
        'porque la copia no incluía su archivo. Para recuperarlos, usa una '
        'copia completa.';
  }
  return text;
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.contents});
  final BackupContents contents;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  RestoreMode _mode = RestoreMode.merge;

  @override
  Widget build(BuildContext context) {
    final m = widget.contents.manifest;
    final theme = Theme.of(context);
    final canReplace = m.includesBookFiles;

    return AlertDialog(
      title: const Text('Restaurar copia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copia del ${formatDate(m.createdAt)}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${plural(m.bookCount, 'libro', 'libros')} · '
              '${plural(m.shelfCount, 'estante', 'estantes')} · '
              '${plural(m.manuscriptCount, 'obra', 'obras')}'
              '${m.includesBookFiles ? '' : ' · solo datos'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            RadioGroup<RestoreMode>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v ?? _mode),
              child: Column(
                children: [
                  const RadioListTile(
                    contentPadding: EdgeInsets.zero,
                    value: RestoreMode.merge,
                    title: Text('Fusionar (recomendado)'),
                    subtitle: Text(
                      'Añade lo que falta y actualiza el progreso. '
                      'No borra nada.',
                    ),
                  ),
                  RadioListTile(
                    contentPadding: EdgeInsets.zero,
                    value: RestoreMode.replace,
                    enabled: canReplace,
                    title: const Text('Reemplazar todo'),
                    subtitle: Text(
                      canReplace
                          ? 'Deja tu biblioteca exactamente como en la copia.'
                          : 'No disponible: esta copia no trae los libros.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _mode),
          child: const Text('Restaurar'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.secondary,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
