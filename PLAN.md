# Littera — Plan de trabajo

App **100 % local** para leer y escribir libros. Flutter (Android primero, Web después).

## Identidad

| Token | Color | Uso |
|---|---|---|
| `tinta` | `#1C2540` | Fondo modo oscuro, AppBar, texto en modo claro |
| `pergamino` | `#F2E8D2` | Fondo modo claro / sepia, texto en modo oscuro |
| `oro` | `#C9A45C` | Acentos: botones, progreso, selección, subrayados |

- Fuente: Sans-Serif → **Inter** (empaquetada en `assets/fonts/`, sin descargar en tiempo de ejecución, para que funcione offline).
- Logo: `assets/littera-icono-tinta.svg` → splash, icono de la app y cabecera.

## Decisiones técnicas

| Tema | Elección | Motivo |
|---|---|---|
| Base de datos | **`hive_ce`** + `hive_ce_flutter` | Continuación mantenida de Hive (el `hive` original está abandonado); misma API |
| Estado | `flutter_riverpod` | Simple, testeable |
| Navegación | `go_router` | Rutas declarativas |
| Archivos | `file_picker`, `path_provider` | Importar libros y carátulas |
| Carátulas | `image_picker` + `image` (redimensionar) | Guardar miniatura ligera |
| EPUB | `epub_view` / `epubx` | Lectura y extracción de carátula |
| PDF | `pdfrx` | Rápido, funciona en Android y Web |
| DOCX | `archive` + `xml` (parser propio a texto/párrafos) | No hay lector maduro; `.docx` es un ZIP con XML |
| Backup | `archive` + `share_plus` | Exportar/importar un `.littera` (ZIP) |
| Editor | `flutter_quill` | Texto enriquecido para escritura |

> **Nota sobre `.doc`:** el formato antiguo de Word (binario, anterior a 2007) no tiene soporte fiable en Dart.
> Se soportará **`.docx`**; para `.doc` se mostrará un aviso pidiendo convertirlo. Se puede revisar más adelante.

> **Nota sobre Web:** en navegador no hay sistema de archivos; los libros se guardarán como bytes en Hive (IndexedDB).
> Por eso Android va primero y Web se valida al final de cada fase.

## Comandos útiles

```bash
dart run build_runner build -d      # regenerar adapters de Hive tras cambiar modelos
dart run flutter_launcher_icons     # regenerar iconos
dart run flutter_native_splash:create
flutter test
```

> `lib/data/hive/hive_adapters.g.yaml` fija los typeId de Hive: **versionarlo y no editarlo a mano**.

## Estructura de carpetas

```
lib/
  main.dart
  app/            # MaterialApp, router, tema (colores, tipografía)
  core/           # utilidades, constantes, almacenamiento de archivos
  data/
    models/       # Book, Shelf, Highlight, Manuscript, Chapter, ReadingSession...
    hive/         # adapters, registro de boxes, migraciones
    repositories/
  features/
    library/      # estanterías, grid de libros, importar, carátulas
    reader/       # lectores EPUB / PDF / DOCX, progreso, ajustes
    notes/        # subrayados y notas
    writing/      # manuscritos, capítulos, fichas
    backup/       # exportar / restaurar
    stats/        # estadísticas y metas
```

## Modelo de datos (Hive)

- **Book**: id, título, autor, formato (`epub|pdf|docx`), ruta del archivo, ruta de carátula, estantes, progreso (posición + %), fecha de añadido, última lectura, `isOwnWork`.
- **Shelf**: id, nombre, orden, `isSystem` (Leyendo / Por leer / Terminados).
- **Highlight**: id, bookId, posición, texto, nota, color, fecha.
- **Manuscript**: id, título, sinopsis, carátula, meta de palabras, fecha.
- **Chapter**: id, manuscriptId, orden, título, contenido (Delta de Quill), conteo de palabras, actualizado.
- **ChapterVersion**: id, chapterId, contenido, fecha (instantáneas).
- **Entity** (ficha): id, manuscriptId, tipo (`personaje|lugar|objeto`), nombre, descripción, imagen.
- **ReadingSession**: bookId, fecha, páginas/minutos (para estadísticas).
- **Settings**: tema, tamaño de letra, interlineado, meta anual, meta diaria de palabras.

Todos los modelos llevan `schemaVersion` desde el día 1 para poder migrar sin perder datos.

---

## Fases

Cada fase termina con algo usable. Marca `[x]` al completar.

### Fase 0 — Cimientos ✅
- [x] Añadir dependencias base (`hive_ce`, `flutter_riverpod`, `go_router`, `path_provider`, `flutter_svg`)
- [x] Tema Littera: `ColorScheme` claro/sepia/oscuro con la paleta, tipografía Inter empaquetada
- [x] Logo en `assets/images/`; icono de app (`flutter_launcher_icons`) y splash (`flutter_native_splash`)
- [x] Inicializar Hive (adapters generados con `@GenerateAdapters`), `schemaVersion` y migraciones; carpetas internas `books/` y `covers/`
- [x] Navegación inferior: Biblioteca · Escribir · Ajustes (`StatefulShellRoute`)
- [x] Selector de tema persistente en Ajustes; app en español (`flutter_localizations`)
- [x] Limpiar `main.dart` y tests del ejemplo; tests de navegación, tema y persistencia

### Fase 1 — Biblioteca
- [ ] Importar EPUB, PDF y DOCX (copiar a almacenamiento interno de la app)
- [ ] Extraer metadatos automáticamente (título/autor/carátula de EPUB; primera página de PDF como carátula)
- [ ] **Carátula personalizada**: elegir imagen de galería/archivos, recortar y guardar miniatura
- [ ] Editar título y autor
- [ ] Estantes del sistema (Leyendo / Por leer / Terminados) + estantes propios
- [ ] Vista en cuadrícula y lista, búsqueda y orden (reciente, título, autor)
- [ ] Eliminar libro (borra archivo, carátula y notas asociadas)

### Fase 2 — Lector
- [ ] Lector EPUB
- [ ] Lector PDF
- [ ] Lector DOCX (convertir a párrafos con estilos básicos: títulos, negrita, cursiva)
- [ ] Recordar posición exacta al salir y reabrir
- [ ] Ajustes: modo claro / sepia / oscuro, tamaño de letra, interlineado
- [ ] Mover automáticamente a "Leyendo" al abrir y ofrecer "Terminado" al llegar al final

### Fase 3 — Backup y restauración (prioritaria: protege los datos)
- [ ] Exportar todo a un archivo `littera-backup-AAAA-MM-DD.littera` (ZIP con):
  - `manifest.json` (versión de app, versión de esquema, fecha, conteos)
  - `data/*.json` (cada box de Hive serializada a JSON, no binario, para que sea legible y migrable)
  - `books/` (archivos originales) y `covers/`
- [ ] Guardar en Descargas o compartir (Drive, correo, Telegram…) con `share_plus`
- [ ] Opción de exportar **solo datos** (sin archivos de libros) para backups ligeros
- [ ] Restaurar: elegir `.littera`, validar manifest, previsualizar contenido, y elegir **reemplazar** o **fusionar** (sin duplicar por id)
- [ ] Recordatorio opcional: "Hace X días que no haces copia"
- [ ] Prueba de ida y vuelta: exportar → borrar app → reinstalar → restaurar → todo idéntico

### Fase 4 — Subrayados y notas
- [ ] Seleccionar texto → subrayar (colores) y añadir nota
- [ ] Panel de notas por libro con salto a la posición
- [ ] Vista global "Mis citas" con búsqueda
- [ ] Exportar citas a texto / Markdown

### Fase 5 — Escritura
- [ ] Crear manuscrito con carátula, sinopsis y meta
- [ ] Capítulos: crear, renombrar, reordenar (arrastrar), eliminar
- [ ] Editor sin distracciones (modo pantalla completa)
- [ ] Autoguardado (debounce ~2 s) + indicador "Guardado"
- [ ] Contador de palabras por capítulo y total; meta diaria
- [ ] Versiones: instantánea automática por sesión + manual; ver y restaurar
- [ ] Fichas de personajes y lugares en panel lateral
- [ ] Incluido en el backup de la Fase 3

### Fase 6 — Exportar obra
- [ ] Exportar manuscrito a **EPUB** (generado con `archive` + plantillas XHTML)
- [ ] Exportar a **PDF** (`pdf` package) con carátula
- [ ] Exportar a **DOCX** (opcional)
- [ ] "Añadir a mi biblioteca": la obra exportada aparece como libro con `isOwnWork`

### Fase 7 — Estadísticas
- [ ] Registrar sesiones de lectura automáticamente
- [ ] Páginas/minutos por día, racha, meta anual de libros
- [ ] Palabras escritas por día y racha de escritura

### Fase 8 — Pulido y Web
- [ ] Validar todo en Web (almacenamiento en IndexedDB, límites de tamaño)
- [ ] Animaciones, estados vacíos con ilustración, accesibilidad (contraste, tamaños)
- [ ] Rendimiento con bibliotecas grandes (lazy loading de carátulas)
- [ ] Tests de repositorios y del backup

### Más adelante (fuera del alcance local)
- Asistente de IA opcional (títulos, ortografía, resúmenes) — requeriría conexión y consentimiento explícito
- Social ligero (publicar, comentar, seguir autores) — requiere servidor

---

## Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Pérdida de datos al desinstalar | Backup en Fase 3 (temprano), recordatorios, formato JSON abierto |
| Cambios de modelo rompen datos | `schemaVersion` + migraciones; backup antes de migrar |
| `.doc` antiguo no soportado | Aviso claro + recomendar convertir a `.docx` |
| Libros pesados en Web | Avisar límite; Web como plataforma secundaria |
| Hive corrupto | `compactionStrategy`, manejo de errores al abrir box, restaurar desde backup |
| Paquetes de lectura con bugs | Aislar cada lector detrás de una interfaz `BookReader` para poder cambiarlo |

## Orden recomendado

**0 → 1 → 2 → 3** = MVP (biblioteca + lector + backup). Después 4, 5, 6, 7, 8.
