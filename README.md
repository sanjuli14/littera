# Littera

Biblioteca y taller de escritura **100 % local**. Lee EPUB, PDF y DOCX, subraya y toma notas, escribe tus propias obras por capítulos y expórtalas a EPUB o PDF. Nada sale de tu dispositivo salvo las copias de seguridad que tú guardes.

## Qué hace

- **Biblioteca**: importar EPUB, PDF y DOCX (con carátula y metadatos automáticos), carátulas personalizadas, estados (Leyendo / Por leer / Terminados), estantes propios, búsqueda y orden.
- **Lector**: lector propio para EPUB/DOCX (tema claro, sepia u oscuro, tamaño de letra, interlineado) y visor PDF; recuerda la posición exacta.
- **Subrayados y notas**: cuatro colores, notas, panel por libro y pestaña "Mis citas" con exportación a Markdown.
- **Escritura**: obras por capítulos, editor enriquecido sin distracciones, guardado automático, versiones, fichas de personajes y lugares.
- **Exportar obra** a EPUB 3 o PDF A5 y añadirla a la biblioteca.
- **Estadísticas**: tiempo de lectura, libros terminados y palabras escritas.
- **Copia de seguridad** en un archivo `.littera` (ZIP con JSON legible) para restaurar en otro dispositivo.
- **Recordatorios** de lectura (notificaciones locales) y **actualizaciones** desde la propia app con su historial de novedades.

## Tecnología

Flutter (Android y Web) · Hive CE para el almacenamiento local · Riverpod · go_router · pdfrx · flutter_quill · pdf.

Paleta: tinta `#1C2540`, pergamino `#F2E8D2`, oro `#C9A45C`. Tipografías: Montserrat (interfaz) y Lora (lectura y citas), incluidas y sin conexión.

## Desarrollo

```bash
flutter pub get
dart run build_runner build -d   # tras cambiar modelos de Hive
flutter analyze
flutter test
flutter run
```

`lib/data/hive/hive_adapters.g.yaml` fija los identificadores de Hive: se versiona y no se edita a mano.

## Publicar una versión nueva

La app busca versiones en las [Releases de GitHub](https://github.com/sanjuli14/littera/releases) al abrirse (una vez al día, con conexión), avisa con una tarjeta en Inicio y una notificación, y descarga e instala el APK desde Ajustes → Novedades.

1. Sube la versión en `pubspec.yaml`, por ejemplo de `1.0.0+1` a `1.1.0+2`. El número tras el `+` tiene que **aumentar siempre**: Android no instala una versión con un número menor o igual.
2. Compila el APK: `flutter build apk --release` (queda en `build/app/outputs/flutter-apk/app-release.apk`).
3. En GitHub, crea una Release con la etiqueta `v1.1.0` (la misma versión, con "v"). Escribe las novedades en la descripción en Markdown sencillo (`# títulos`, `- viñetas`, `**negrita**`) y adjunta el APK.
4. No marques la Release como *pre-release* ni la dejes como borrador: esas se ignoran.

> **Firma:** Android solo instala una actualización si el APK está firmado con la misma clave que la versión instalada. Ahora mismo el modo *release* usa la clave de depuración de tu ordenador. Compila siempre en el mismo equipo, o crea una clave de firma propia antes de repartir la app.

El plan de trabajo y el estado de cada fase están en [PLAN.md](PLAN.md).
