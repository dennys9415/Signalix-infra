# Signalix Infrastructure

**Version: v0.2.0**

Docker Compose local development setup for Signalix. This is the primary entry point for running the full stack locally.

## Services

| Service | Source | Local port |
|---|---|---|
| `postgres` | `postgres:16` | 5432 |
| `flyway` | `flyway/flyway:10` | — |
| `api` | built from `Signalix-api/` | 4000 |
| `realtime` | built from `Signalix-realtime/` | 5000 |
| `frontend` | built from `Signalix-frontend/` | 3000 |

Startup order: `postgres` (healthy) → `flyway` (migrations complete) → `api` (started) → `realtime`, `frontend`

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

# 1. Copy env examples
cp env/postgres.env.example  env/postgres.env
cp env/flyway.env.example    env/flyway.env
cp env/api.env.example       env/api.env
cp env/realtime.env.example  env/realtime.env
cp env/frontend.env.example  env/frontend.env

# 2. Edit env files:
#    - Set a strong JWT_SECRET in api.env and realtime.env (must be identical)
#    - Fill in OAuth credentials if you want to test Google/GitHub/Apple login
#    - Optionally set RESEND_API_KEY for real email delivery

# 3. Start everything
./scripts/up.sh
```

After startup:

| Service | URL |
|---|---|
| Frontend | http://localhost:3000 |
| API | http://localhost:4000/api/v1 |
| Realtime WebSocket | ws://localhost:5000 |
| Postgres | localhost:5432 |

## Environment files

All secrets live in `env/*.env` (git-ignored). The `*.env.example` files document every variable.

### `env/postgres.env`

| Variable | Description |
|---|---|
| `POSTGRES_USER` | Database superuser name |
| `POSTGRES_PASSWORD` | Database superuser password |
| `POSTGRES_DB` | Database name |

### `env/flyway.env`

| Variable | Description |
|---|---|
| `FLYWAY_URL` | JDBC connection string (uses `postgres` hostname) |
| `FLYWAY_USER` | Must match `POSTGRES_USER` |
| `FLYWAY_PASSWORD` | Must match `POSTGRES_PASSWORD` |
| `FLYWAY_LOCATIONS` | Always `filesystem:/flyway/sql` |

### `env/api.env`

| Variable | Required | Description |
|---|---|---|
| `NODE_ENV` | no | `development` or `production` |
| `PORT` | no | API listen port (default `4000`) |
| `DATABASE_URL` | **yes** | Postgres connection string |
| `JWT_SECRET` | **yes** | Must match `realtime.env` — use a strong random value |
| `JWT_ACCESS_EXPIRES_IN` | no | Access token TTL (default `1h`) |
| `JWT_REFRESH_EXPIRES_IN` | no | Refresh token TTL (default `30d`) |
| `FRONTEND_URL` | **yes** | Origin for OAuth redirects and email links (e.g. `http://localhost:3000`) |
| `GOOGLE_CLIENT_ID` | OAuth | Google OAuth app client ID |
| `GOOGLE_CLIENT_SECRET` | OAuth | Google OAuth app client secret |
| `GOOGLE_CALLBACK_URL` | OAuth | Must be registered in Google Console |
| `GITHUB_CLIENT_ID` | OAuth | GitHub OAuth app client ID |
| `GITHUB_CLIENT_SECRET` | OAuth | GitHub OAuth app client secret |
| `GITHUB_CALLBACK_URL` | OAuth | Must be registered in GitHub OAuth app |
| `APPLE_CLIENT_ID` | OAuth | Apple Service ID |
| `APPLE_TEAM_ID` | OAuth | 10-character Apple Team ID |
| `APPLE_KEY_ID` | OAuth | Key ID from `.p8` file |
| `APPLE_PRIVATE_KEY` | OAuth | Full `.p8` contents with `\n` replacing real newlines |
| `APPLE_CALLBACK_URL` | OAuth | **Must be HTTPS** — Apple rejects `http://` |
| `RESEND_API_KEY` | Email | Leave empty to log email links to the API console instead |
| `EMAIL_FROM` | no | Sender name/address (default `Signalix <onboarding@resend.dev>`) |

### `env/realtime.env`

| Variable | Required | Description |
|---|---|---|
| `NODE_ENV` | no | `development` or `production` |
| `PORT` | no | WebSocket listen port (default `5000`) |
| `JWT_SECRET` | **yes** | Must match `api.env` |
| `API_BASE_URL` | **yes** | API address reachable by the realtime container — use `http://api:4000` |

### `env/frontend.env`

Runtime-only variables for the Next.js standalone server. The `NEXT_PUBLIC_*` URLs are baked into the JS bundle at build time via `build.args` in `docker-compose.yml`.

| Variable | Description |
|---|---|
| `NODE_ENV` | `production` |
| `PORT` | HTTP listen port (default `3000`) |
| `HOSTNAME` | Bind address (default `0.0.0.0`) |

> **Note:** To change `NEXT_PUBLIC_API_URL` or `NEXT_PUBLIC_WS_URL`, update the `build.args` in `docker-compose.yml` and rebuild the `frontend` service.

## Scripts

```bash
./scripts/up.sh              # Build and start all services (detached)
./scripts/down.sh            # Stop and remove containers
./scripts/logs.sh            # Tail all logs
./scripts/logs.sh api        # Tail logs for a specific service
./scripts/migrate.sh         # Run Flyway migrations only (postgres must be running)
```

## Resetting state

```bash
./scripts/down.sh
docker volume rm signalix-infra_postgres_data   # drops the entire database
./scripts/up.sh
```

## Migrations

Migrations are managed by Flyway and live in `Signalix-api/migrations/`. Never edit a deployed migration file — always add a new one.

| Migration | Contents |
|---|---|
| `V1__init.sql` | `pgcrypto` extension + `users` table |
| `V2__auth.sql` | `auth_providers`, `devices`, `device_sessions` |
| `V3__chat.sql` | `chats`, `chat_participants`, `messages`, `message_status`, `presence` |
| `V4__message_deletions.sql` | Per-user soft delete for messages |
| `V5__password_reset.sql` | Password reset tokens |
| `V6__email_verification.sql` | Email verification tokens |

## v0.2.0 changelog

### Added
- `FRONTEND_URL`, `GOOGLE_*`, `GITHUB_*`, `APPLE_*`, `RESEND_API_KEY`, `EMAIL_FROM` variables in `env/api.env.example`
- Migrations V4–V6 applied automatically on startup

## Known limitations

- **Single instance only.** The realtime service uses in-memory routing. Horizontal scaling requires Redis Pub/Sub (planned).
- **No nginx / TLS.** Services are exposed directly on localhost ports. Do not expose to the internet without a reverse proxy and TLS termination.
- **Frontend `NEXT_PUBLIC_*` URLs are build-time constants.** They point to `http://localhost:4000` and `ws://localhost:5000` by default. Changing them requires updating `build.args` in `docker-compose.yml` and rebuilding the `frontend` image.
- **Apple OAuth requires HTTPS.** The `APPLE_CALLBACK_URL` must use `https://`. Use a tunnel (e.g. ngrok) for local development.
- **No health check on `api` or `realtime`.** `frontend` and `realtime` depend on `service_started`, not `service_healthy`. Brief startup races are handled by the services' own retry logic.

## Planned

- Redis service for horizontal realtime scaling
- nginx reverse proxy with TLS
- Health check endpoints and proper `service_healthy` dependencies
