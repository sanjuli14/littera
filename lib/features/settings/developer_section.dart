import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_info.dart';
import '../../app/theme/littera_colors.dart';
import '../../core/widgets/soft_card.dart';

/// Quién hizo la app y cómo contactarle para contrataciones.
class DeveloperSection extends StatelessWidget {
  const DeveloperSection({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(
        AppInfo.developerWhatsApp,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir WhatsApp. Escribe al ${AppInfo.developerPhone}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SoftCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: dark
                        ? LitteraColors.oro
                        : LitteraColors.tinta,
                    foregroundColor: dark
                        ? LitteraColors.tinta
                        : LitteraColors.pergamino,
                    child: const Icon(Icons.code_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Desarrollado por',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          AppInfo.developer,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '¿Quieres una app como esta para tu negocio o proyecto? '
                'Estoy disponible para contrataciones: escríbeme y '
                'lo hablamos.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openWhatsApp(context),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Escribir por WhatsApp'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: SelectableText(
                  AppInfo.developerPhone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
