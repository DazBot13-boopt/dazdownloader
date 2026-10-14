#!/usr/bin/env bash
set -Eeuo pipefail
exec "$(dirname "$0")/publish-persistent-analysis-pr.sh" "$@"
