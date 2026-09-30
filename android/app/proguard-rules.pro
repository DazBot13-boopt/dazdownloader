# youtubedl-android 0.18.1 does not publish these as consumer rules.
# Mirror the upstream common module's rules in the consuming application:
# https://github.com/yausername/youtubedl-android/pull/346
-keep class com.yausername.** { *; }

# ExtraFieldUtils registers ZIP fields with Class.newInstance(). R8 otherwise
# removes their no-arg constructors and initialization throws an uncaught
# ExceptionInInitializerError while unpacking the Python/FFmpeg runtimes.
-keep class org.apache.commons.compress.archivers.zip.** { *; }
