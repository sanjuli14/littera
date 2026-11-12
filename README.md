# Littera

Biblioteca y taller de escritura **100 % local**. Lee EPUB, PDF y DOCX, subraya y toma notas, escribe tus propias obras por capítulos y expórtalas a EPUB o PDF. Nada sale de tu dispositivo salvo las copias de seguridad que tú guardes.

## Qué hace

- **Biblioteca**: importar EPUB, PDF y DOCX (con carátula y metadatos automáticos), carátulas personalizadas, estados (Leyendo / Por leer / Terminados), estantes propios, búsqueda y orden.
- **Lector**: lector propio para EPUB/DOCX (tema claro, sepia u oscuro, tamaño de letra, interlineado) y visor PDF; recuerda la posición exacta.
- **Subrayados y notas**: cuatro colores, notas, panel por libro y pestaña "Mis citas" con exportación a Markdown.
- **Escritura**: obras por capítulos, editor enriquecido sin distracciones, guardado automático, versiones, fichas de personajes y lugares, meta diaria.
- **Exportar obra** a EPUB 3 o PDF A5 y añadirla a la biblioteca.
- **Estadísticas**: tiempo de lectura real, rachas, meta anual de libros y palabras escritas.
- **Copia de seguridad** en un archivo `.littera` (ZIP con JSON legible) para restaurar en otro dispositivo.

## Tecnología

Flutter (Android y Web) · Hive CE para el almacenamiento local · Riverpod · go_router · pdfrx · flutter_quill · pdf.

Paleta: tinta `#1C2540`, pergamino `#F2E8D2`, oro `#C9A45C`. Tipografía: Inter (incluida, funciona sin conexión).

## Desarrollo

```bash
flutter pub get
dart run build_runner build -d   # tras cambiar modelos de Hive
flutter analyze
flutter test
flutter run
```

`lib/data/hive/hive_adapters.g.yaml` fija los identificadores de Hive: se versiona y no se edita a mano.

El plan de trabajo y el estado de cada fase están en [PLAN.md](PLAN.md).
