import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../app/theme/littera_theme.dart';
import '../../core/widgets/littera_logo.dart';
import '../../core/widgets/soft_blobs.dart';
import '../../data/repositories/settings_repository.dart';
import '../library/library_actions.dart';

/// Bienvenida (solo la primera vez).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (context.mounted) context.go(Routes.library);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _LogoComposition(),
                      const SizedBox(height: 40),
                      Text(
                        'Empieza tu viaje\ncon los libros',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lee, subraya y escribe tus propias historias. '
                        'Todo se queda en este dispositivo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: LitteraTheme.serif,
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                          height: 1.45,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await ref
                                .read(settingsProvider.notifier)
                                .completeOnboarding();
                            if (!context.mounted) return;
                            context.go(Routes.library);
                            await importBooks(context, ref);
                          },
                          child: const Text('Importar mi primer libro'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _finish(context, ref),
                        child: const Text('Más tarde'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El logo sobre un círculo pergamino, con lomos de libros y puntos en la
/// paleta alrededor.
class _LogoComposition extends StatelessWidget {
  const _LogoComposition();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget dot(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    Widget spine(double h, Color c) => Container(
      width: 22,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(5),
      ),
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: 300,
        height: 260,
        child: SoftBlobs(
          variant: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: dark
                      ? LitteraColors.nocheMedia
                      : LitteraColors.pergamino,
                  shape: BoxShape.circle,
                ),
              ),
              Positioned(
                bottom: 22,
                left: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    spine(70, LitteraColors.oro),
                    spine(92, LitteraColors.tintaMedia),
                    spine(58, LitteraColors.pergaminoOscuro),
                  ],
                ),
              ),
              const LitteraLogo(size: 120),
              Positioned(top: 18, right: 40, child: dot(14, LitteraColors.oro)),
              Positioned(top: 52, left: 26, child: dot(9, LitteraColors.tinta)),
              Positioned(
                bottom: 40,
                right: 26,
                child: dot(18, LitteraColors.oro.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
