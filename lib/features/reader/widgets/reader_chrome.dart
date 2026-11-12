import 'package:flutter/material.dart';

import '../../../app/theme/littera_colors.dart';
import '../reader_palette.dart';

/// Barras superior (título, índice, ajustes) e inferior (progreso)
/// que aparecen y desaparecen sobre el contenido.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.visible,
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.onSeek,
    required this.onSettings,
    required this.child,
    this.onSeekPreview,
    this.onToc,
    this.onNotes,
  });

  final bool visible;
  final ReaderPalette palette;
  final String title;
  final String? subtitle;
  final double progress;
  final String progressLabel;
  final ValueChanged<double> onSeek;
  final ValueChanged<double>? onSeekPreview;
  final VoidCallback onSettings;
  final VoidCallback? onToc;
  final VoidCallback? onNotes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    final textStyle = TextStyle(color: palette.text);

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              duration: duration,
              offset: visible ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: duration,
                opacity: visible ? 1 : 0,
                child: Material(
                  color: palette.chrome,
                  elevation: 2,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: palette.text,
                            tooltip: 'Volver',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (subtitle != null)
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.secondary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (onNotes != null)
                            IconButton(
                              icon: const Icon(Icons.bookmarks_outlined),
                              color: palette.text,
                              tooltip: 'Notas',
                              onPressed: onNotes,
                            ),
                          if (onToc != null)
                            IconButton(
                              icon: const Icon(Icons.toc),
                              color: palette.text,
                              tooltip: 'Índice',
                              onPressed: onToc,
                            ),
                          IconButton(
                            icon: const Icon(Icons.text_fields),
                            color: palette.text,
                            tooltip: 'Ajustes de lectura',
                            onPressed: onSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              duration: duration,
              offset: visible ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: duration,
                opacity: visible ? 1 : 0,
                child: Material(
                  color: palette.chrome,
                  elevation: 2,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            progressLabel,
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 12,
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: LitteraColors.oro,
                              thumbColor: LitteraColors.oro,
                              inactiveTrackColor: palette.secondary.withValues(
                                alpha: 0.3,
                              ),
                              overlayColor: LitteraColors.oro.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            child: Slider(
                              value: progress.clamp(0, 1),
                              onChanged: onSeekPreview ?? (_) {},
                              onChangeEnd: onSeek,
                              semanticFormatterCallback: (v) =>
                                  '${(v * 100).round()} %',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
