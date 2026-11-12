import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/soft_card.dart';
import 'app_release.dart';
import 'update_service.dart';
import 'updates_provider.dart';

/// Notas de versión en Markdown sencillo: `#` títulos, `-`/`*` viñetas,
/// `**negrita**` y párrafos.
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({super.key, required this.notes});

  final String notes;

  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  List<InlineSpan> _inline(String text) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _bold.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    final lines = notes.split('\n');
    if (notes.trim().isEmpty) {
      return Text('Mejoras y correcciones.', style: body);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in lines)
          if (raw.trim().isEmpty)
            const SizedBox(height: 6)
          else if (raw.trimLeft().startsWith('#'))
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                raw.replaceFirst(RegExp(r'^\s*#+\s*'), ''),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (RegExp(r'^\s*[-*]\s+').hasMatch(raw))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: LitteraColors.oro,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _inline(
                          raw.replaceFirst(RegExp(r'^\s*[-*]\s+'), ''),
                        ),
                      ),
                      style: body,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(children: _inline(raw.trim())),
                style: body,
              ),
            ),
      ],
    );
  }
}

/// Hoja con las novedades de una versión y el botón para instalarla.
Future<void> showUpdateSheet(BuildContext context, AppRelease release) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpdateSheet(release: release),
    );

class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet({required this.release});
  final AppRelease release;

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  double? _progress;
  String? _error;

  Future<void> _install() async {
    final service = ref.read(updateServiceProvider);
    if (service == null) return;
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final apk = await service.download(
        widget.release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await service.install(apk);
      if (mounted) setState(() => _progress = null);
    } on UpdateException catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.release;
    final downloading = _progress != null;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              'NUEVA VERSIÓN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: LitteraColors.oroOscuro,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(r.name, style: theme.textTheme.headlineSmall),
            Text(
              '${formatDate(r.publishedAt)}'
              '${r.apkSize > 0 ? ' · ${formatFileSize(r.apkSize)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ReleaseNotes(notes: r.notes),
            const SizedBox(height: 24),
            if (downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 8,
                  color: LitteraColors.oro,
                  backgroundColor: theme.colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Descargando… ${((_progress ?? 0) * 100).round()} %',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ] else
              FilledButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.system_update_rounded),
                label: const Text('Descargar e instalar'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Android te pedirá confirmar la instalación. Tus libros, notas y '
              'obras se conservan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta en Inicio cuando hay una versión nueva.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updatesProvider);
    final update = state.available;
    if (!state.showBanner || update == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SoftCard(
        color: dark
            ? LitteraColors.nocheAlta
            : LitteraColors.oro.withValues(alpha: 0.18),
        child: InkWell(
          onTap: () => showUpdateSheet(context, update),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: LitteraColors.oro,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Littera ${update.version} ya está aquí',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Toca para ver las novedades',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Ahora no',
                  onPressed: ref.read(updatesProvider.notifier).dismissBanner,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ajustes → Novedades: versión instalada, actualización y historial.
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(updatesProvider);
    final current = ref.watch(currentVersionProvider);
    final supported = ref.watch(updateServiceProvider) != null;
    final notifier = ref.read(updatesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Novedades')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            'Tienes la versión $current',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Littera solo consulta si hay versiones nuevas; no envía ningún '
            'dato tuyo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (state.available != null) ...[
            FilledButton.icon(
              onPressed: () => showUpdateSheet(context, state.available!),
              icon: const Icon(Icons.system_update_rounded),
              label: Text('Actualizar a ${state.available!.version}'),
            ),
            const SizedBox(height: 8),
          ],
          if (supported)
            OutlinedButton.icon(
              onPressed: state.checking ? null : notifier.refresh,
              icon: state.checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                state.checking ? 'Buscando…' : 'Buscar actualizaciones',
              ),
            ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ] else if (supported &&
              !state.checking &&
              state.available == null &&
              state.releases.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Estás al día ✨',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          if (state.releases.isEmpty)
            Text(
              supported
                  ? 'Conéctate a internet y pulsa "Buscar actualizaciones" '
                        'para ver el historial de versiones.'
                  : 'Las actualizaciones están disponibles en la app para '
                        'Android.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final r in state.releases) ...[
              SoftCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (compareVersions(r.version, current) == 0)
                            const _Tag('Instalada')
                          else if (r == state.available)
                            const _Tag('Nueva', highlight: true),
                        ],
                      ),
                      Text(
                        formatDate(r.publishedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ReleaseNotes(notes: r.notes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? LitteraColors.oro
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: highlight ? LitteraColors.tinta : null,
        ),
      ),
    );
  }
}

/// Abre la pantalla de novedades.
void openWhatsNew(BuildContext context) => context.push(Routes.whatsNew);
