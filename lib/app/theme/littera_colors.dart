import 'package:flutter/material.dart';

/// Paleta de marca de Littera.
abstract final class LitteraColors {
  /// Azul tinta: fondo en modo oscuro, texto y AppBar en modo claro.
  static const tinta = Color(0xFF1C2540);

  /// Pergamino: fondo en modo claro/sepia, texto en modo oscuro.
  static const pergamino = Color(0xFFF2E8D2);

  /// Oro: acentos (botones, progreso, selección, subrayados).
  static const oro = Color(0xFFC9A45C);

  // Derivados para superficies y estados.
  static const tintaClara = Color(0xFF243052);
  static const tintaMedia = Color(0xFF2C3962);
  static const tintaAlta = Color(0xFF364573);
  static const pergaminoClaro = Color(0xFFFBF8F1);
  static const pergaminoMedio = Color(0xFFEADFC4);
  static const pergaminoOscuro = Color(0xFFDDCFAE);
  static const oroOscuro = Color(0xFF8A6A2C);
  static const error = Color(0xFFB3261E);
  static const errorClaro = Color(0xFFF2B8B5);
}
