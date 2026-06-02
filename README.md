# Signalix Infrastructure

Docker Compose local development setup for Signalix v0.1. This is the primary entry point for running the full stack locally.

## Services

| Service    | Source                        | Local port |
|------------|-------------------------------|------------|
| `postgres` | `postgres:16`                 | 5432       |
| `flyway`   | `flyway/flyway:10`            | —          |
| `api`      | built from `Signalix-api/`    | 4000       |
| `realtime` | built from `Signalix-realtime/` | 5000     |
| `frontend` | built from `Signalix-frontend/` | 3000     |

Startup order: `postgres` (healthy) → `flyway` (migrations complete) → `api` → `realtime`, `frontend`

## Prerequisites

- Docker 24+ with the Compose plugin (`docker compose version`)
- All repos cloned into the same parent directory (`proyect/`):
  ```
  proyect/
    Signalix-contracts/
    Signalix-api/
    Signalix-realtime/
    Signalix-frontend/
    Signalix-infra/      ← you are here
  ```

## Quick start

```bash
cd Signalix-infra

# 1. Copy env examples and fill in secrets
cp env/postgres.env.example  env/postgres.env
cp env/flyway.env.example    env/flyway.env
cp env/api.env.example       env/api.env
cp env/realtime.env.example  env/realtime.env
cp env/frontend.env.example  env/frontend.env

# 2. Edit env files — at minimum change JWT_SECRET in api.env and realtime.env
#    (must be the same value in both)

# 3. Start everything
./scripts/up.sh
```

After startup:
- Frontend → http://localhost:3000
- API → http://localhost:4000/api/v1
- Realtime WebSocket → ws://localhost:5000
- Postgres → localhost:5432

## Environment files

All secrets live in `env/*.env` (git-ignored). The `*.env.example` files document every variable.

### `env/postgres.env`

| Variable            | Description                          |
|---------------------|--------------------------------------|
| `POSTGRES_USER`     | Database superuser name              |
| `POSTGRES_PASSWORD` | Database superuser password          |
| `POSTGRES_DB`       | Database name                        |

### `env/flyway.env`

| Variable             | Description                                      |
|----------------------|--------------------------------------------------|
| `FLYWAY_URL`         | JDBC connection string (uses `postgres` hostname) |
| `FLYWAY_USER`        | Must match `POSTGRES_USER`                       |
| `FLYWAY_PASSWORD`    | Must match `POSTGRES_PASSWORD`                   |
| `FLYWAY_LOCATIONS`   | Always `filesystem:/flyway/sql`                  |

### `env/api.env`

| Variable                 | Description                           |
|--------------------------|---------------------------------------|
| `NODE_ENV`               | `development` or `production`         |
| `PORT`                   | API listen port (default `4000`)      |
| `DATABASE_URL`           | Postgres connection string            |
| `JWT_SECRET`             | **Must match** `realtime.env`         |
| `JWT_ACCESS_EXPIRES_IN`  | Access token TTL (e.g. `1h`)         |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token TTL (e.g. `30d`)       |

### `env/realtime.env`

| Variable       | Description                              |
|----------------|------------------------------------------|
| `NODE_ENV`     | `development` or `production`            |
| `PORT`         | WebSocket listen port (default `5000`)   |
| `JWT_SECRET`   | **Must match** `api.env`                 |
| `API_BASE_URL` | API address reachable by realtime container — use `http://api:4000` |

### `env/frontend.env`

Runtime-only variables for the Next.js standalone server. The `NEXT_PUBLIC_*` URLs are baked into the JS bundle at build time via `build.args` in `docker-compose.yml`.

| Variable   | Description                       |
|------------|-----------------------------------|
| `NODE_ENV` | `production`                      |
| `PORT`     | HTTP listen port (default `3000`) |
| `HOSTNAME` | Bind address (default `0.0.0.0`)  |

## Scripts

```bash
./scripts/up.sh        # Build and start all services (detached)
./scripts/down.sh      # Stop and remove containers
./scripts/logs.sh      # Tail all logs (pass a service name to filter, e.g. logs.sh api)
./scripts/migrate.sh   # Run Flyway migrations only (postgres must be running)
```

## Resetting state

```bash
./scripts/down.sh
docker volume rm signalix-infra_postgres_data   # drops the database
./scripts/up.sh
```

## Known v0.1 limitations

- **Single instance only.** Realtime uses in-memory routing; horizontal scaling requires Redis Pub/Sub (v0.2).
- **No nginx / TLS.** Services are exposed directly on localhost ports. Do not expose to the internet without a reverse proxy.
- **Frontend `NEXT_PUBLIC_*` URLs are build-time constants.** They point to `http://localhost:4000` and `ws://localhost:5000`. Changing them requires rebuilding the `frontend` image.
- **No health check on `api` or `realtime`.** `frontend` and `realtime` depend on `service_started`, not `service_healthy`. Brief startup races are handled by the services' own retry logic.
