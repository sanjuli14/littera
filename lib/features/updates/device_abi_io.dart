import 'dart:ffi';

/// Arquitectura del móvil con el nombre que lleva el APK
/// (`littera-1.2.0-arm64-v8a.apk`); `null` fuera de Android.
String? deviceAbi() => switch (Abi.current()) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  _ => null,
};
