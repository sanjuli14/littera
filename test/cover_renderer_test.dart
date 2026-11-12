import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:littera/features/export/cover_renderer.dart';

void main() {
  testWidgets('dibuja una carátula PNG de 600×900 con fondo tinta', (
    tester,
  ) async {
    final png = (await tester.runAsync(
      () => renderGeneratedCover(
        'Un título largo, con tildes y eñes: ¿Quién cantó?',
        'Ana Ruiz',
      ),
    ))!;
    final image = img.decodePng(png)!;
    expect(image.width, 600);
    expect(image.height, 900);
    final corner = image.getPixel(5, 5);
    expect([corner.r, corner.g, corner.b], [0x1C, 0x25, 0x40]);
  });

  testWidgets('sin autor ni título no falla', (tester) async {
    final png = await tester.runAsync(() => renderGeneratedCover('', ''));
    expect(img.decodePng(png!)!.width, 600);
  });
}
