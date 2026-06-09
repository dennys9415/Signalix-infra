# Signalix Infrastructure

**Version: v0.16.0**

> v0.10.0 adds **one new Flyway migration** (`V15__group_message_recipients.sql`) for the group E2EE beta. No new services, no new env vars, no new build-args. Same containers + ports as v0.9.x. Rebuild + redeploy the api, realtime, and frontend images after Flyway applies V15.

Docker Compose local development setup for Signalix. This is the primary entry point for running the full stack locally.

## Services

| Service | Source | Local port |
|---|---|---|
| `postgres` | `postgres:16` | 5432 |
| `flyway` | `flyway/flyway:10` | — |
| `minio` | `minio/minio:latest` | 9000 (S3 API) / 9001 (console) |
| `minio-init` | `minio/mc:latest` | — |
| `api` | built from `Signalix-api/` | 4000 |
| `realtime` | built from `Signalix-realtime/` | 5000 |
| `frontend` | built from `Signalix-frontend/` | 3000 |

Startup order: `postgres` (healthy) + `minio` (healthy) → `flyway` (migrations complete) + `minio-init` (buckets created) → `api` (started) → `realtime`, `frontend`

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
| MinIO S3 API | http://localhost:9000 |
| MinIO console | http://localhost:9001 |

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
| `MINIO_ENDPOINT` | **yes** | Internal S3 endpoint reachable by the API container — use `http://minio:9000` |
| `MINIO_PUBLIC_URL` | **yes** | Externally reachable URL used inside stored URLs (browser-facing) — e.g. `http://localhost:9000` |
| `MINIO_REGION` | no | Default `us-east-1` |
| `MINIO_ACCESS_KEY` | **yes** | Must match `MINIO_ROOT_USER` in `postgres.env` / minio service |
| `MINIO_SECRET_KEY` | **yes** | Must match `MINIO_ROOT_PASSWORD` |
| `MINIO_BUCKET_AVATARS` | no | Default `signalix-avatars` (auto-created by `minio-init`) |
| `MINIO_BUCKET_MEDIA` | no | Default `signalix-media` (image messages) |
| `MINIO_BUCKET_FILES` | no | Default `signalix-files` (file attachments) |
| `VAPID_PUBLIC_KEY` | Push | Generated once via `npx web-push generate-vapid-keys`. Empty disables push. |
| `VAPID_PRIVATE_KEY` | Push | Pair to the public key — keep secret. |
| `VAPID_SUBJECT` | no | `mailto:` or HTTPS URL. Default `mailto:admin@signalix.local` |

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
docker volume rm signalix-infra_minio_data      # drops all avatars / media / files
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
| `V7__chat_deletions.sql` | Per-user chat visibility cutoff for delete-chat-for-me |
| `V8__message_reactions.sql` | Emoji reactions |
| `V9__message_reply_forward.sql` | `reply_to_message_id` + `is_forwarded` on `messages` |
| `V10__link_preview.sql` | `link_preview` JSONB column on `messages` |
| `V11__read_state.sql` | `chat_read_state` for persistent unread counts |
| `V12__push_subscriptions.sql` | `push_subscriptions` — Web Push device subscriptions (one row per user × endpoint) |
| `V13__chats_avatar_description.sql` | `chats.avatar_url` + `chats.description` — group avatar URL and editable description (v0.7.0) |
| `V14__crypto_foundation.sql` | `device_identity_keys`, `signed_pre_keys`, `pre_keys` + 5 envelope columns on `messages` — scaffolding for future E2EE (v0.8.0). Does not perform encryption. |

## v0.16.0 changelog — Mobile foundation MVP (infra no-op)

### Not changed
- v0.16.0 introduces the new `Signalix-mobile` repository. The mobile app talks to the existing `api` + `realtime` services and is not part of the Docker Compose stack — no new services, no env var changes, no migrations. For local development, the Android emulator reaches the host stack via `http://10.0.2.2:4000` / `ws://10.0.2.2:5000` (configured in `Signalix-mobile/app.json`).

## v0.15.0 changelog — Key backup & device recovery (infra no-op)

### Not changed
- No new services, no new env vars, no migrations. Only the frontend image needs a rebuild to pick up the `/settings/security` page and the new `bip39` + `backup` modules.

## v0.14.0 changelog — Read receipts (infra no-op)

### Not changed
- No new services, no new env vars, no migrations. Rebuild + redeploy `api`, `realtime`, and `frontend` images to pick up v0.14.0.

## v0.13.0 changelog — Message search (infra no-op)

### Not changed
- No new services, no new env vars, no migrations. Rebuild + redeploy `api` and `frontend` images to pick up v0.13.0.

## v0.12.0 changelog — Safety number / device verification UI (infra no-op)

### Not changed
- No new services, no new env vars, no new build-args, no new migrations. Only the frontend image needs a rebuild to pick up `qrcode` + the new `ContactProfileModal` code; the other images move in lockstep for tag alignment but have no functional changes.

## v0.11.0 changelog — Media / file / voice E2EE beta (infra no-op)

### Not changed
- No new services, no new env vars, no new build-args, no new migrations.
- Encrypted attachments add a new object key prefix `encrypted/{userId}/{uuid}.bin` under the existing MinIO media bucket. No bucket-level policy change required.
- Rebuild + redeploy `api` and `frontend` images. `contracts` is build-time only; `realtime` and `infra` are no-ops for this release.

## v0.10.1 changelog — Hardening + chat-created broadcast (infra no-op)

### Not changed
- No new services, no new env vars, no new build-args, no new migrations. Same Docker Compose topology, same containers, same ports as v0.10.0.
- Rebuild + redeploy the `api`, `realtime`, and `frontend` images. `contracts` is build-time only.
- Deploy order matters: `api` BEFORE `frontend` so the server-side stale-key wipe is in place when each browser triggers its forced cleanup.

## v0.10.0 changelog — Group E2EE beta

### Added
- **Flyway migration `V15__group_message_recipients.sql`** — picked up automatically by the `flyway` container on the next `up` of the stack. New table, no destructive changes; safe to apply to an existing v0.9.x deployment.

### Not changed
- Same services, env files, ports, Docker Compose topology as v0.9.x.
- No new env vars, no new build-args.
- The realtime, api, and frontend images all need a rebuild to pick up the v0.10.0 code; infra-side wiring is identical.

## v0.9.1 changelog — E2EE hardening

### Not changed
- No services added, removed, or rewired. Same Docker Compose topology, same env files, same Flyway migrations as v0.9.0.
- No new env vars, no new build-args. `NEXT_PUBLIC_E2EE_DEV_FALLBACK` from v0.9.0 remains.
- No infra-side work to deploy v0.9.1 beyond rebuilding the `api` and `frontend` images.

## v0.9.0 changelog — Signal Protocol Beta

### Added
- New frontend build-arg / env var: **`NEXT_PUBLIC_E2EE_DEV_FALLBACK`** (default `false`). When `true` the frontend falls back to the v0.8.0 plaintext-passthrough mock instead of running the v0.9.0 Signal service. Wired into `docker-compose.yml`'s `frontend.build.args` and `Signalix-frontend/Dockerfile` as an `ARG`/`ENV` pair.

### Not changed
- No new services, buckets, migrations, or other env vars. v0.9.0 reuses the v0.8.0 schema (V14) and the v0.8.0 crypto endpoints — only the frontend behaviour changes.

## v0.8.0 changelog

### Added
- Migration **V14** (`device_identity_keys`, `signed_pre_keys`, `pre_keys`, and 5 new columns on `messages`) applied automatically on startup. **Scaffolding only** — v0.8.0 does not perform encryption.

### Not changed
- No new services, buckets, or env vars. The crypto endpoints run inside the existing `api` container.

## v0.7.1 changelog

### Not changed
- Message search (global + in-chat) is REST-only and reuses the existing API container — no new service, bucket, env var, or migration.

## v0.7.0 changelog

### Added
- Migration **V13** (`chats.avatar_url` + `chats.description`) applied automatically on startup.

### Not changed
- No new buckets, env vars, or services. Group avatars reuse the existing `signalix-avatars` bucket under the `chats/{chatId}/` key prefix.

## v0.6.1 changelog

### Not changed
- No infra-level changes for voice messages. Voice notes reuse the existing `signalix-media` bucket under a `voice/{userId}/` key prefix — no new bucket, no new env var, no new service, no migration.

## v0.6.0 changelog

### Added
- Migration **V12** (`push_subscriptions`) applied automatically on startup
- `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` / `VAPID_SUBJECT` env vars in `env/api.env.example`. Leaving the keys empty disables push without erroring the API.

### Generating VAPID keys

```bash
npx web-push generate-vapid-keys
# Copy "Public Key" → VAPID_PUBLIC_KEY in env/api.env
# Copy "Private Key" → VAPID_PRIVATE_KEY in env/api.env
```

The frontend fetches the public key at runtime via `GET /api/v1/push/public-key`, so no build-arg or rebuild is required to enable/disable push.

## v0.5.0 changelog

### Added since v0.2.0
- **MinIO** S3-compatible object storage service + `minio-init` job that creates the three buckets (`signalix-avatars`, `signalix-media`, `signalix-files`) and applies public-read policies for avatars and media
- `MINIO_*` env vars in `env/api.env.example`
- Migrations V7–V11 applied automatically on startup

### v0.5.0 stabilization
- No infra-level fixes; v0.5.0 stabilization happened in the application services.

## Known limitations

- **Single instance only.** The realtime service uses in-memory routing. Horizontal scaling requires Redis Pub/Sub (planned).
- **No nginx / TLS.** Services are exposed directly on localhost ports. Do not expose to the internet without a reverse proxy and TLS termination.
- **Frontend `NEXT_PUBLIC_*` URLs are build-time constants.** They point to `http://localhost:4000` and `ws://localhost:5000` by default. Changing them requires updating `build.args` in `docker-compose.yml` and rebuilding the `frontend` image.
- **MinIO `MINIO_PUBLIC_URL`** is baked into stored avatar / media URLs at upload time. Changing it after data has been written invalidates the existing URLs.
- **Apple OAuth requires HTTPS.** The `APPLE_CALLBACK_URL` must use `https://`. Use a tunnel (e.g. ngrok) for local development.
- **No health check on `api` or `realtime`.** `frontend` and `realtime` depend on `service_started`, not `service_healthy`. Brief startup races are handled by the services' own retry logic.

## Planned

- Redis service for horizontal realtime scaling
- nginx reverse proxy with TLS
- Health check endpoints and proper `service_healthy` dependencies for `api` and `realtime`
