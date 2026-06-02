#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# Pass an optional service name: ./scripts/logs.sh api
docker compose logs -f "$@"
