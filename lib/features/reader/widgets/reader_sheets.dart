import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/littera_colors.dart';
import '../../../app/theme/littera_theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../reader_palette.dart';

/// Hoja de ajustes de lectura. En PDF solo se muestra el tema.
Future<void> showReaderSettings(
  BuildContext context, {
  required ReaderPalette palette,
  bool textOptions = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.chrome,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ReaderSettingsSheet(textOptions: textOptions),
  );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet({required this.textOptions});

  final bool textOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final palette = ReaderPalette.resolve(
      settings.readerTheme,
      Theme.of(context),
    );
    final label = TextStyle(color: palette.secondary, fontSize: 13);
    final value = TextStyle(color: palette.text, fontWeight: FontWeight.w600);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema', style: label),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final theme in ReaderTheme.values) ...[
                  Expanded(
                    child: _ThemeSwatch(
                      theme: theme,
                      selected: settings.readerTheme == theme,
                      textColor: palette.text,
                      onTap: () => notifier.setReaderTheme(theme),
                    ),
                  ),
                  if (theme != ReaderTheme.values.last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
            if (textOptions) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Tamaño de letra', style: label)),
                  IconButton.outlined(
                    tooltip: 'Letra más pequeña',
                    color: palette.text,
                    icon: const Icon(Icons.text_decrease),
                    onPressed:
                        settings.readerFontSize > ReaderLimits.minFontSize
                        ? () => notifier.setReaderFontSize(
                            settings.readerFontSize - 1,
                          )
                        : null,
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      settings.readerFontSize.round().toString(),
                      textAlign: TextAlign.center,
                      style: value,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Letra más grande',
                    color: palette.text,
                    icon: const Icon(Icons.text_increase),
                    onPressed:
                        settings.readerFontSize < ReaderLimits.maxFontSize
                        ? () => notifier.setReaderFontSize(
                            settings.readerFontSize + 1,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Interlineado', style: label),
              Slider(
                value: settings.readerLineHeight,
                min: ReaderLimits.minLineHeight,
                max: ReaderLimits.maxLineHeight,
                divisions: 10,
                activeColor: LitteraColors.oro,
                inactiveColor: palette.secondary.withValues(alpha: 0.3),
                label: settings.readerLineHeight.toStringAsFixed(1),
                onChanged: notifier.setReaderLineHeight,
              ),
              const SizedBox(height: 8),
              Text('Letra', style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text(
                      'Clásica',
                      style: TextStyle(fontFamily: LitteraTheme.serif),
                    ),
                    selected: settings.readerSerif,
                    onSelected: (_) => notifier.setReaderSerif(true),
                  ),
                  ChoiceChip(
                    label: const Text('Moderna'),
                    selected: !settings.readerSerif,
                    onSelected: (_) => notifier.setReaderSerif(false),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Justificar texto',
                  style: TextStyle(color: palette.text),
                ),
                value: settings.readerJustify,
                activeThumbColor: LitteraColors.oro,
                onChanged: notifier.setReaderJustify,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.textColor,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool selected;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.forTheme(theme);
    final isAuto = theme == ReaderTheme.auto;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${theme.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isAuto ? null : palette.background,
                gradient: isAuto
                    ? const LinearGradient(
                        colors: [
                          LitteraColors.pergaminoClaro,
                          LitteraColors.pergaminoClaro,
                          LitteraColors.noche,
                          LitteraColors.noche,
                        ],
                        stops: [0, 0.5, 0.5, 1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? LitteraColors.oro
                      : textColor.withValues(alpha: 0.2),
                  width: selected ? 3 : 1,
                ),
              ),
              child: isAuto
                  ? const Icon(Icons.brightness_auto, color: LitteraColors.oro)
                  : Text(
                      'Aa',
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              theme.label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada genérica del índice para EPUB/DOCX y PDF.
class TocItem {
  const TocItem(this.title, this.target, {this.level = 1});
  final String title;

  /// Índice de bloque o número de página.
  final int target;
  final int level;
}

/// Muestra el índice y devuelve el destino elegido.
Future<int?> showTocSheet(
  BuildContext context, {
  required ReaderPalette palette,
  required List<TocItem> items,
  int? currentIndex,
}) {
  return showModalBottomSheet<int>(
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Índice',
              style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Este libro no tiene índice',
                      style: TextStyle(color: palette.secondary),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final current = i == currentIndex;
                      return ListTile(
                        contentPadding: EdgeInsets.only(
                          left: 24.0 * item.level,
                          right: 24,
                        ),
                        selected: current,
                        selectedTileColor: LitteraColors.oro.withValues(
                          alpha: 0.15,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: current
                                ? FontWeight.w700
                                : item.level == 1
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, item.target),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
