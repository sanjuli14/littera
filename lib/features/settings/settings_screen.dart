import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_info.dart';
import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/widgets/soft_card.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';
import '../backup/backup_screen.dart';
import '../backup/backup_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Apariencia',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final option in _themeOptions) ...[
                  if (option != _themeOptions.first) const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeTile(
                      option: option,
                      selected: settings.themePreference == option.value,
                      onTap: () => ref
                          .read(settingsProvider.notifier)
                          .setThemePreference(option.value),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SoftCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('Estadísticas y metas'),
                    subtitle: const Text(
                      'Minutos leídos, libros terminados y palabras escritas',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.stats),
                  ),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Copia de seguridad'),
                    subtitle: Text(
                      lastBackupLabel(ref.watch(lastBackupProvider)),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.backup),
                  ),
                  const AboutListTile(
                    icon: Icon(Icons.info_outline),
                    applicationName: AppInfo.name,
                    applicationVersion: AppInfo.appVersion,
                    applicationLegalese: 'Tipografías Montserrat y Lora — SIL Open Font License 1.1',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption(this.value, this.label, this.background, this.foreground);

  final AppThemePreference value;
  final String label;
  final Color background;
  final Color foreground;
}

const _themeOptions = [
  _ThemeOption(
    AppThemePreference.system,
    'Sistema',
    LitteraColors.pergaminoClaro,
    LitteraColors.tinta,
  ),
  _ThemeOption(
    AppThemePreference.light,
    'Claro',
    Colors.white,
    LitteraColors.tinta,
  ),
  _ThemeOption(
    AppThemePreference.sepia,
    'Sepia',
    LitteraColors.pergamino,
    LitteraColors.tinta,
  ),
  _ThemeOption(
    AppThemePreference.dark,
    'Oscuro',
    LitteraColors.tinta,
    LitteraColors.pergamino,
  ),
];

/// Tarjeta con una muestra del tema: "Aa" sobre su color de fondo.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = option.value == AppThemePreference.system;

    return Semantics(
      selected: selected,
      button: true,
      label: 'Tema ${option.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? LitteraColors.oro
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
                // "Sistema" muestra mitad claro, mitad oscuro.
                gradient: isSystem
                    ? const LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white,
                          LitteraColors.tinta,
                          LitteraColors.tinta,
                        ],
                        stops: [0, 0.5, 0.5, 1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSystem ? null : option.background,
              ),
              alignment: Alignment.center,
              child: isSystem
                  ? const Icon(Icons.brightness_auto, color: LitteraColors.oro)
                  : Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: option.foreground,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
