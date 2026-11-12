# Littera — Plan de trabajo

App **100 % local** para leer y escribir libros. Flutter (Android primero, Web después).

## Identidad

| Token | Color | Uso |
|---|---|---|
| `tinta` | `#1C2540` | Fondo modo oscuro, AppBar, texto en modo claro |
| `pergamino` | `#F2E8D2` | Fondo modo claro / sepia, texto en modo oscuro |
| `oro` | `#C9A45C` | Acentos: botones, progreso, selección, subrayados |

- Fuentes: **Montserrat** en la interfaz y **Lora** (serif) para leer y citar, empaquetadas en `assets/fonts/` para que funcionen sin conexión.
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
| Backup | `archive` + `file_picker` | Exportar/importar un `.littera` (ZIP) |
| Editor | `flutter_quill` 11 | Texto enriquecido para escritura (contenido guardado como Delta JSON) |

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
    stats/        # estadísticas
```

## Modelo de datos (Hive)

- **Book**: id, título, autor, formato (`epub|pdf|docx`), ruta del archivo, ruta de carátula, estantes, progreso (posición + %), fecha de añadido, última lectura, `isOwnWork`.
- **Shelf**: id, nombre, orden, `isSystem` (Leyendo / Por leer / Terminados).
- **Highlight**: id, bookId, posición, texto, nota, color, fecha.
- **Manuscript**: id, título, autor, sinopsis, carátula, fechas.
- **Chapter**: id, manuscriptId, orden, título, contenido (Delta de Quill), conteo de palabras, actualizado.
- **ChapterVersion**: id, chapterId, contenido, fecha (instantáneas).
- **Entity** (ficha): id, manuscriptId, tipo (`personaje|lugar|objeto`), nombre, descripción, imagen.
- **ReadingSession**: bookId, fecha, páginas/minutos (para estadísticas).
- **Settings**: tema, vista y orden de la biblioteca, ajustes del lector (tema, letra, tamaño, interlineado, justificado).

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

### Fase 1 — Biblioteca ✅
- [x] Importar EPUB, PDF y DOCX (varios a la vez); `.doc` rechazado con mensaje para convertir a `.docx`
- [x] Validación de formato por firma de archivo y detección de duplicados (SHA-1)
- [x] Metadatos automáticos: título/autor/carátula de EPUB 2 y 3, título/autor de DOCX, primera página de PDF como carátula (`pdfrx`)
- [x] **Carátula personalizada** desde archivos/galería (recorte automático 2:3, JPEG 600×900); volver a carátula generada
- [x] Carátula generada con la paleta cuando no hay imagen
- [x] Editar título y autor
- [x] Estados (Leyendo / Por leer / Terminados) + estantes propios (crear, renombrar, eliminar con pulsación larga)
- [x] Cuadrícula y lista, búsqueda sin tildes, orden (añadidos, leídos, título, autor) — preferencias guardadas
- [x] Eliminar libro (borra archivo y carátula)
- [x] Almacenamiento: disco en Android, IndexedDB (Hive) en Web; referencias relativas para el backup
- [ ] Pendiente menor: recorte manual de carátula (hoy es automático al centro)

### Fase 2 — Lector ✅
- [x] Lector EPUB y DOCX propio: el archivo se convierte en bloques (títulos, párrafos, citas, listas, imágenes, separadores) en un isolate
- [x] Lector PDF (`pdfrx`) con índice del PDF si lo trae
- [x] Índice: nav (EPUB 3), toc.ncx (EPUB 2), títulos de Word (DOCX) o títulos del texto como respaldo
- [x] Posición exacta guardada (bloque o página) con retardo, al salir y al pasar la app a segundo plano; se restaura al abrir
- [x] Ajustes: tema Auto/Claro/Sepia/Oscuro, tamaño de letra, interlineado, justificar — guardados
- [x] Barras que se ocultan al leer (toque para mostrarlas), modo inmersivo, barra de progreso para saltar
- [x] "Por leer" → "Leyendo" al abrir; al llegar al final, ofrece marcar como terminado
- [ ] Pendiente menor: probar el visor PDF en un dispositivo real (no se compiló la app en esta fase)

### Fase 3 — Backup y restauración ✅
- [x] Archivo `.littera` (ZIP): `manifest.json`, `data/*.json` (JSON legible, no binario de Hive), `files/books/` y `files/covers/`
- [x] Copia completa o "solo datos" (sin archivos de libros; incluye carátulas)
- [x] Guardar donde el usuario elija (Drive, Descargas…) con el diálogo del sistema; en Web se descarga
- [x] Restaurar con vista previa (fecha, conteos) y modo **Fusionar** (no borra nada; progreso más reciente gana; estantes se unen por nombre) o **Reemplazar** (con confirmación; solo con copia completa)
- [x] Validación: rechaza archivos ajenos, dañados o de versiones más nuevas; ignora rutas peligrosas y registros inválidos
- [x] Seguridad al reemplazar: primero se escriben los archivos nuevos, luego se cambian los datos, al final se borran huérfanos
- [x] Fecha de última copia en Ajustes y aviso en la biblioteca (3+ libros y 14+ días sin copia)
- [x] Prueba de ida y vuelta automatizada: exportar → app vacía → restaurar → todo idéntico
- [ ] Mejora futura: generar el ZIP por streaming para bibliotecas muy grandes (hoy se arma en memoria)

### Fase 4 — Subrayados y notas ✅
- [x] EPUB/DOCX: mantener pulsado → "Subrayar", "Nota", "Editar", "Quitar", "Copiar"; 4 colores; notas con subrayado punteado y botón "Nota" al pie del párrafo
- [x] Subrayados solapados se fusionan (conservan la nota)
- [x] PDF: "Guardar cita" en el menú de selección (texto + página) y "Nota en esta página"
- [x] Panel "Notas y subrayados" del libro en el lector, con salto a cada uno
- [x] Pestaña **Citas**: todas las citas agrupadas por libro, búsqueda (sin tildes), filtro por color, abrir el libro justo en la cita
- [x] Exportar citas a Markdown o copiarlas al portapapeles
- [x] Incluidos en la copia de seguridad (se reasignan al libro local al fusionar); se borran con su libro
- [ ] Limitaciones: un subrayado no puede abarcar varios párrafos; en PDF la cita no se pinta sobre la página

### Fase 5 — Escritura ✅
- [x] Obras (manuscritos) con título, autor/seudónimo, sinopsis y carátula
- [x] Capítulos: crear, renombrar, reordenar arrastrando, eliminar
- [x] Editor de texto enriquecido (`flutter_quill`): negrita, cursiva, títulos, citas, listas, deshacer/rehacer
- [x] Modo sin distracciones (oculta barras y la interfaz del sistema)
- [x] Guardado automático (1,5 s tras dejar de escribir), al salir y al pasar a segundo plano; indicador Guardado / Sin guardar
- [x] Contador de palabras del capítulo y de la obra
- [x] Versiones: automática al empezar cada sesión (estado previo), manuales con nombre; vista previa y restaurar (guarda antes lo actual); máx. 30 automáticas por capítulo
- [x] Fichas de personajes, lugares, objetos y apuntes; accesibles desde el editor
- [x] Incluido en la copia de seguridad (completa y "solo datos"); al fusionar gana lo editado más recientemente y lo local se guarda como versión

### Fase 6 — Exportar obra ✅
- [x] El texto del editor (Delta de Quill) se convierte al modelo de bloques del lector: títulos, negrita, cursiva, citas, listas (con viñetas y numeradas), centrado
- [x] **EPUB 3** generado a mano (con toc.ncx para lectores antiguos): carátula, portada, un archivo por capítulo, índice, metadatos (título, autor, idioma, sinopsis)
- [x] **PDF** A5 (`pdf`) con fuente Inter (tildes y ñ correctas): carátula, portada, cada capítulo en página nueva, marcadores por capítulo y número de página
- [x] Carátula: la de la obra o una generada con la paleta (`dart:ui`)
- [x] Guardar el archivo donde se elija y/o **añadir a la biblioteca** como "Obra propia" (filtro "Mis obras")
- [x] Reexportar actualiza el mismo libro (conserva estado, estantes y carátula propia; reinicia la posición porque el texto cambió)
- [x] Los capítulos sin texto se omiten
- [ ] DOCX: descartado por ahora (EPUB y PDF cubren leer, compartir e imprimir)

### Fase 7 — Estadísticas ✅
- [x] Tiempo de lectura real: cuenta mientras el lector está visible; se detiene tras 5 min sin actividad y en segundo plano; se anota cada minuto
- [x] Fecha de terminado en cada libro (se borra si se vuelve a leer)
- [x] Pantalla de estadísticas (desde Biblioteca y Ajustes): minutos de hoy y de la semana, gráfica de 14 días, libros terminados del año con carátulas, horas del año
- [x] Escritura: palabras de hoy y de la semana, gráfica de 14 días, palabras del año
- [x] Gráficas con color validado (contraste ≥ 3:1) en claro, sepia y oscuro; resumen accesible para lectores de pantalla
- [x] Registro de lectura en la copia de seguridad (al fusionar no se duplican minutos)
- [x] Corrige: reexportar una obra sin cambios ya no reinicia la posición (EPUB determinista y versión de la obra guardada en el libro)

### Fase 8 — Pulido y Web ✅
- [x] Compilación Web y pruebas de punta a punta en Chrome (Playwright): importar EPUB/PDF/DOCX/.doc, leer los tres formatos, tema y letra, índice, recargar y conservar datos, crear y escribir una obra, exportar EPUB (descarga válida), estadísticas, copia completa y restauración en un navegador vacío — sin errores de consola
- [x] Barrido de accesibilidad: todas las pantallas a 360 px con texto al 150 % y 200 % sin desbordamientos (corregidos aviso de copia, barra de estantes, tarjetas, carátulas, hojas y diálogos)
- [x] Lector de pantalla: libros anunciados como un botón con título, autor, estado y progreso; párrafos leídos como texto y títulos como encabezados; acciones "Subrayar párrafo" y "Añadir nota al párrafo"; las barras del lector no se ocultan con navegación accesible
- [x] Rendimiento: carátulas decodificadas al tamaño en pantalla (no a 600×900)
- [x] Corrige: condición de carrera al escuchar Hive (una obra nueva aparecía sin su capítulo hasta recargar)
- [x] Corrige: al saltar desde el índice el título quedaba tapado por la barra; carátulas tinta invisibles en modo oscuro; plurales; fecha de última copia tras restaurar
- [ ] Limitación conocida: en **Web con lector de pantalla** no se consigue escribir en el editor (flutter_quill no conecta con el campo accesible del navegador); con ratón/teclado en Web y en el móvil funciona
- [ ] Pendiente: probar en un Android real (no se compiló el APK en estas fases)

### Rediseño visual (a partir de la captura de referencia) ✅
- [x] Tema: fondo blanco, tarjetas con sombra difusa y radios grandes (16/24), botones y pestañas píldora, títulos en negrita; tinta para lo activo y oro para progreso y estrellas (oscuro: oro activo)
- [x] Barra inferior de solo iconos con sombra suave (los nombres quedan como tooltip y etiqueta accesible)
- [x] Bienvenida la primera vez con el logo: "Empieza tu viaje con los libros", "Importar mi primer libro" / "Más tarde"
- [x] Biblioteca como Inicio: buscador píldora con sombra, pestañas píldora, tarjeta "Continúa leyendo" con la carátula difuminada, carruseles "Leyendo ahora", "Añadidos recientemente" y "Mis obras" con "Ver todo", y la colección completa
- [x] Lista estilo "recientes": carátula con sombra, título en negrita, autor, estrellas y progreso con %
- [x] Valoración personal de 1 a 5 estrellas (ficha editable, listas, accesible, en la copia de seguridad)
- [x] Ficha, Estadísticas, Escribir, Ajustes y Copia de seguridad con tarjetas suaves y píldoras
- [x] Corrige: las etiquetas de los chips perdían la fuente Inter

### Rediseño 2: cálido, "esponjoso" y literario ✅
- [x] Tipografías: **Montserrat** (la de la referencia) en la interfaz y **Lora** (serif) para leer, citas y títulos de libro; el PDF exportado usa Lora
- [x] Saludo según la hora con una frase en Lora que cambia cada día
- [x] Carátulas con lomo (esquinas asimétricas, sombra del lomo y brillo) y sombra cálida
- [x] Barra inferior flotante en píldora con burbuja pergamino en el icono activo
- [x] Manchas orgánicas suaves de la paleta en Inicio, ficha, bienvenida y estados vacíos
- [x] Pestañas sin elegir en tono pergamino; esquinas 22/28; iconos redondeados; secciones con títulos cálidos ("Sigue donde lo dejaste", "Recién llegados", "Tus obras")
- [x] Lector: letra "Clásica" (Lora, por defecto) o "Moderna" (Montserrat)
- [x] Importar pasa a un botón "+" en la barra superior (sin botón flotante que tape los carruseles)

### Recordatorios y actualizaciones ✅
- [x] Recordatorio diario a la hora elegida, con mención del libro en curso; aviso "¡Ey, ya casi!" de libros a medias (notificaciones locales, sin Firebase)
- [x] Al tocar una notificación se abre el libro (o las novedades)
- [x] Actualizaciones desde GitHub Releases: comprobación al abrir (máx. una al día), tarjeta en Inicio, notificación una vez por versión
- [x] Descarga del APK con progreso e instalador de Android; pantalla Ajustes → Novedades con el historial (también sin conexión, desde la copia guardada)
- [x] Permisos: internet e instalar paquetes; eliminados los de fotos/vídeo/audio que añadía open_filex
- [ ] Pendiente: crear una clave de firma propia antes de repartir la app (hoy firma con la clave de depuración)

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

> Ajustes a petición (2026-11-12): sin rachas, sin metas (diaria de lectura, anual de libros y de palabras por obra) y sin cita del día en Inicio — sin presión, solo el placer de leer. Modo oscuro en carbón cálido (`noche`), no azul.
