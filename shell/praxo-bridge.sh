#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "${PRAXO_BRIDGE_BIN:-}" ]]; then
  exec "$PRAXO_BRIDGE_BIN" "$@"
fi

exec go run "$ROOT/cmd/praxo-bridge" "$@"
