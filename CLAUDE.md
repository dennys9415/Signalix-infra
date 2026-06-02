# Claude Instructions — Signalix Infrastructure

This is `Signalix-infra`, the Docker Compose local development setup for Signalix v0.1.

## Absolute Rules

1. Never commit real `.env` files. Only `*.env.example` files go in `env/`.
2. The `api` build context is always the workspace root (`..`), not `../Signalix-api`, because
   the Dockerfile requires both `Signalix-contracts` and `Signalix-api` to be in scope.
3. Flyway mounts `../Signalix-api/migrations` read-only. Never copy migrations into this repo.
4. Do not add services that are out of scope for the active version (see below).
5. Do not edit a Flyway migration that has already been applied. Add a new file instead.

## v0.1 Services

| Service  | Image / Source              | Port  |
|----------|-----------------------------|-------|
| postgres | postgres:16                 | 5432  |
| flyway   | flyway/flyway:10            | —     |
| api      | built from workspace root   | 4000  |
| realtime | built from workspace root   | 5000  |
| frontend | built from workspace root   | 3000  |

### frontend build args

`NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_WS_URL` are baked into the JS bundle at build time by
Next.js. They are passed as `build.args` in `docker-compose.yml`, not at runtime via `env_file`.
`env/frontend.env` covers runtime-only vars (`NODE_ENV`, `PORT`, `HOSTNAME`).

## Not in v0.1

- redis
- nginx
- pgadmin
- minio
- monitoring

## Startup Order

```
postgres (healthy) → flyway (completed) → api (started) → realtime, frontend
```

## Local Setup

1. Copy `env/*.env.example` → `env/*.env` for each service and fill in secrets.
2. Run `./scripts/up.sh`.

## Migration Naming (lives in Signalix-api)

```
V1__init.sql
V2__auth.sql
V3__chat.sql
V4__<name>.sql    ← next (increment only, never edit existing)
```
