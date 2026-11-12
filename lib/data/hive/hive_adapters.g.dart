// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class AppThemePreferenceAdapter extends TypeAdapter<AppThemePreference> {
  @override
  final typeId = 0;

  @override
  AppThemePreference read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AppThemePreference.system;
      case 1:
        return AppThemePreference.light;
      case 2:
        return AppThemePreference.sepia;
      case 3:
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  @override
  void write(BinaryWriter writer, AppThemePreference obj) {
    switch (obj) {
      case AppThemePreference.system:
        writer.writeByte(0);
      case AppThemePreference.light:
        writer.writeByte(1);
      case AppThemePreference.sepia:
        writer.writeByte(2);
      case AppThemePreference.dark:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemePreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      themePreference: fields[0] == null
          ? AppThemePreference.system
          : fields[0] as AppThemePreference,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.themePreference);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
