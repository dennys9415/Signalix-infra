#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

for f in env/postgres.env env/flyway.env env/api.env env/realtime.env env/frontend.env; do
  if [ ! -f "$f" ]; then
    echo "Missing: $f"
    echo "  Copy ${f}.example → ${f} and fill in secrets."
    exit 1
  fi
done

docker compose up --build -d
echo ""
echo "Signalix is up."
echo "  API      → http://localhost:4000"
echo "  Realtime → ws://localhost:5000"
echo "  Frontend → http://localhost:3000"
echo "  Postgres → localhost:5432"
