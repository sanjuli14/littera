import 'package:flutter/material.dart';

import '../../../app/theme/littera_colors.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/highlight.dart';
import '../reader_palette.dart';

/// Resultado del editor.
sealed class HighlightEdit {
  const HighlightEdit();
}

class SaveHighlight extends HighlightEdit {
  const SaveHighlight(this.color, this.note);
  final HighlightColor color;

  /// `null` o vacío = sin nota.
  final String? note;
}

class DeleteHighlight extends HighlightEdit {
  const DeleteHighlight();
}

/// Editor de color y nota. [existing] = editar; si no, se está creando.
Future<HighlightEdit?> showHighlightEditor(
  BuildContext context, {
  required ReaderPalette palette,
  required String quote,
  Highlight? existing,
  String? location,
}) {
  return showModalBottomSheet<HighlightEdit>(
    context: context,
    backgroundColor: palette.chrome,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _HighlightEditor(
        palette: palette,
        quote: quote,
        existing: existing,
        location: location,
      ),
    ),
  );
}

class _HighlightEditor extends StatefulWidget {
  const _HighlightEditor({
    required this.palette,
    required this.quote,
    required this.existing,
    required this.location,
  });

  final ReaderPalette palette;
  final String quote;
  final Highlight? existing;
  final String? location;

  @override
  State<_HighlightEditor> createState() => _HighlightEditorState();
}

class _HighlightEditorState extends State<_HighlightEditor> {
  late HighlightColor _color = widget.existing?.color ?? HighlightColor.oro;
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.location != null)
              Text(
                widget.location!,
                style: TextStyle(color: p.secondary, fontSize: 12),
              ),
            if (widget.quote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: _color.color, width: 3),
                  ),
                ),
                child: Text(
                  widget.quote,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final c in HighlightColor.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Semantics(
                        button: true,
                        selected: c == _color,
                        label: 'Color ${c.label}',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c == _color
                                    ? p.text
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: c == _color
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              autofocus: widget.quote.isEmpty || widget.existing == null,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                labelText: 'Nota',
                hintText: 'Escribe lo que te sugiere…',
                labelStyle: TextStyle(color: p.secondary),
                hintStyle: TextStyle(color: p.secondary.withValues(alpha: 0.7)),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: LitteraColors.oro, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, const DeleteHighlight()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: p.text)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final note = _note.text.trim();
                    Navigator.pop(
                      context,
                      SaveHighlight(_color, note.isEmpty ? null : note),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel con los subrayados y notas del libro.
/// Devuelve el subrayado elegido para saltar a él.
Future<Highlight?> showBookNotesSheet(
  BuildContext context, {
  required ReaderPalette palette,
  required List<Highlight> highlights,
  required String Function(Highlight) locationOf,
  required void Function(Highlight) onEdit,
  VoidCallback? onAddPageNote,
}) {
  return showModalBottomSheet<Highlight>(
    context: context,
    backgroundColor: palette.chrome,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notas y subrayados',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onAddPageNote != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onAddPageNote();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nota en esta página'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: highlights.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Mantén pulsado un texto para subrayarlo o añadir una nota.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.secondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: highlights.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 24,
                      endIndent: 24,
                      color: palette.secondary.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, i) => HighlightTile(
                      highlight: highlights[i],
                      location: locationOf(highlights[i]),
                      textColor: palette.text,
                      secondaryColor: palette.secondary,
                      onTap: () => Navigator.pop(context, highlights[i]),
                      onEdit: () => onEdit(highlights[i]),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Fila de un subrayado: color, cita, nota y ubicación.
class HighlightTile extends StatelessWidget {
  const HighlightTile({
    super.key,
    required this.highlight,
    required this.location,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
    this.onEdit,
    this.title,
  });

  final Highlight highlight;
  final String location;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  /// Título opcional encima (p. ej. el libro, en "Mis citas").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              margin: const EdgeInsets.only(top: 2, right: 14),
              decoration: BoxDecoration(
                color: h.color.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  if (!h.isPageNote)
                    Text(
                      '“${h.text}”',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  if (h.hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 16,
                            color: LitteraColors.oro,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              h.note!,
                              style: TextStyle(color: textColor, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    location.isEmpty
                        ? formatDate(h.createdAt)
                        : '$location · ${formatDate(h.createdAt)}',
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: secondaryColor,
                tooltip: 'Editar',
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}
