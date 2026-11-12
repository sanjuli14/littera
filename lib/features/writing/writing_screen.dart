import 'package:flutter/material.dart';

import '../../app/theme/littera_colors.dart';
import '../../core/widgets/empty_state.dart';

class WritingScreen extends StatelessWidget {
  const WritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escribir')),
      body: EmptyState(
        icon: const Icon(Icons.edit_note, size: 96, color: LitteraColors.oro),
        title: 'Aún no tienes manuscritos',
        message: 'Crea tu primera obra y organízala por capítulos.',
        action: FilledButton.icon(
          // Se implementa en la Fase 5.
          onPressed: null,
          icon: const Icon(Icons.add),
          label: const Text('Nuevo manuscrito'),
        ),
      ),
    );
  }
}
