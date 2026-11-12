import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor con la navegación inferior principal.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: 'Biblioteca',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: 'Escribir',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
