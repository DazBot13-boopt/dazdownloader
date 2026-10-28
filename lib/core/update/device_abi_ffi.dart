import 'dart:ffi' show Abi;

/// APK architecture of the running app, or null when unknown. A 32-bit APK
/// installed on a 64-bit phone reports arm, so the update keeps the same APK.
String? currentApkAbi() => switch (Abi.current()) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  _ => null,
};
