-keep class ZipRuntimeSmoke { public static void main(java.lang.String[]); }
# Optional XZ codecs in commons-compress are unused by this ZIP-only probe.
-dontwarn org.tukaani.xz.**
