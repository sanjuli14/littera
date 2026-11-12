import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo de Littera (icono con fondo tinta).
class LitteraLogo extends StatelessWidget {
  const LitteraLogo({super.key, this.size = 40});

  static const asset = 'assets/images/littera-icono-tinta.svg';

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    semanticsLabel: 'Littera',
  );
}
