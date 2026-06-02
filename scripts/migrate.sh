#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

for f in env/postgres.env env/flyway.env; do
  if [ ! -f "$f" ]; then
    echo "Missing: $f"
    echo "  Copy ${f}.example → ${f} and fill in secrets."
    exit 1
  fi
done

docker compose run --rm flyway
