#!/usr/bin/env bash
set -Eeuo pipefail
exec "$(dirname "$0")/start-persistent-analysis.sh" "$@"
