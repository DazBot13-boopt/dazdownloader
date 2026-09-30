#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  printf 'Usage: bash tooling/check_release_zip.sh <JDK-17-home> <r8-or-d8.jar> <commons-compress-1.12.jar>\n' >&2
  exit 2
fi
smoke_jdk="$1"
smoke_r8="$2"
smoke_compress="$3"
smoke_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
smoke_output="$(mktemp -d /tmp/daz-release-zip.XXXXXX)"

"$smoke_jdk/bin/javac" --release 8 -cp "$smoke_compress" -d "$smoke_output" \
  "$smoke_root/tooling/release_zip_smoke/ZipRuntimeSmoke.java"

smoke_compile() {
  "$smoke_jdk/bin/java" -cp "$smoke_r8" com.android.tools.r8.R8 \
    --classfile --release --lib "$smoke_jdk" \
    --pg-conf "$smoke_root/tooling/release_zip_smoke/probe.pro" \
    --output "$smoke_output/$1.jar" "$smoke_output/ZipRuntimeSmoke.class" \
    "$smoke_compress" "${@:2}"
}

# Negative control: reproduce the crash with the original missing keep rules.
smoke_compile broken
if smoke_error="$("$smoke_jdk/bin/java" -cp "$smoke_output/broken.jar" ZipRuntimeSmoke 2>&1)"; then
  printf 'The negative control no longer reproduces the original R8 failure.\n' >&2
  exit 1
fi
if [[ "$smoke_error" != *ExceptionInInitializerError* ]]; then
  printf '%s\n' "$smoke_error" >&2
  exit 1
fi
printf 'Original missing-rule crash reproduced (ExceptionInInitializerError).\n'

# Positive control uses the very same rules consumed by the Android release.
smoke_compile fixed --pg-conf "$smoke_root/android/app/proguard-rules.pro"
"$smoke_jdk/bin/java" -cp "$smoke_output/fixed.jar" ZipRuntimeSmoke
printf 'Probe artifacts: %s\n' "$smoke_output"
