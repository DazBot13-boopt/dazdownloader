// The web build has no dart:ffi; it never offers an APK anyway.
export 'device_abi_stub.dart' if (dart.library.ffi) 'device_abi_ffi.dart';
