import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/littera_logo.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            LitteraLogo(size: 32),
            SizedBox(width: 12),
            Text('Biblioteca'),
          ],
        ),
      ),
      body: EmptyState(
        icon: const LitteraLogo(size: 96),
        title: 'Tu biblioteca está vacía',
        message: 'Importa libros EPUB, PDF o DOCX para empezar a leer.',
        action: FilledButton.icon(
          // Se implementa en la Fase 1.
          onPressed: null,
          icon: const Icon(Icons.add),
          label: const Text('Importar libro'),
        ),
      ),
    );
  }
}
