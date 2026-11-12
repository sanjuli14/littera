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

La app busca versiones en las [Releases de GitHub](https://github.com/sanjuli14/littera/releases) al abrirse (una vez al día, con conexión), avisa con una tarjeta en Inicio y una notificación, y descarga e instala el APK desde Ajustes → Novedades. Las Releases las crea la CI.

1. Añade las novedades en `CHANGELOG.md` bajo `## [1.1.0] - AAAA-MM-DD` (`### títulos`, `- viñetas`, `**negrita**`): es el texto que verá el usuario.
2. Sube la versión en `pubspec.yaml`, por ejemplo de `1.0.0+1` a `1.1.0+2`. El número tras el `+` tiene que **aumentar siempre**.
3. Haz commit y crea la etiqueta:
   ```bash
   git commit -am "Versión 1.1.0"
   git push
   git tag v1.1.0 && git push origin v1.1.0
   ```
4. El flujo **Release** comprueba que la etiqueta coincide con `pubspec.yaml`, pasa los tests, compila el APK firmado y publica la Release con esas novedades.

### CI/CD

- **CI** (`.github/workflows/ci.yml`): en cada push a `main` y pull request, análisis, tests y APK de prueba (descargable como artefacto 7 días).
- **Release** (`.github/workflows/release.yml`): al subir una etiqueta `v*`.

### Clave de firma

Android solo instala una actualización si está firmada con la **misma clave** que la versión instalada.

- La clave está en `android/keystore/littera-release.jks` y sus contraseñas en `android/key.properties`. **Ninguno de los dos se sube a git.** Haz una copia de ambos en un lugar seguro: si se pierden, no se podrá actualizar la app y habrá que reinstalarla.
- Para que la CI pueda firmar, sube la clave como secretos del repositorio una sola vez: `tool/upload_signing_secrets.sh` (usa `gh`).
- Sin `key.properties` (otro ordenador), la compilación local firma con la clave de depuración.

El plan de trabajo y el estado de cada fase están en [PLAN.md](PLAN.md).
