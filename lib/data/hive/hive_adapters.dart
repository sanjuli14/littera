import 'package:hive_ce/hive_ce.dart';

import '../models/app_settings.dart';

part 'hive_adapters.g.dart';

/// Registro de adapters generados.
///
/// Al añadir un modelo nuevo: agregarlo aquí y ejecutar
/// `dart run build_runner build`. Los typeId quedan fijados en
/// `hive_adapters.g.yaml`; ese archivo debe versionarse y nunca editarse a mano.
@GenerateAdapters([
  AdapterSpec<AppThemePreference>(),
  AdapterSpec<AppSettings>(),
])
// ignore: unused_element
void _() {}
