# Docker setup investigation — pre-bootstrap path

**Date:** 2026-05-09
**Branch:** `AddDockerSupport`
**Scope:** Followed `README.md` → "Docker → Pre-bootstrap" instructions on a fresh template (no `init-project` run). End-to-end startup fails. Three independent defects.

## Reproduction

Steps from README, executed verbatim:

```bash
cp .env.example .env
# Edit .env: JWT_SECRET_KEY set to a 48-byte base64
docker compose -f docker/compose.sqlite.yaml up -d
```

Outcome: build fails before container starts.

## Defects

### 1. Build context resolves to `docker/`, Dockerfile lives at repo root

`docker/compose.sqlite.yaml:3-5`:

```yaml
build:
  context: .
  dockerfile: Dockerfile
```

`docker compose -f docker/compose.sqlite.yaml ...` sets the project directory to the compose file's directory (`docker/`). `context: .` therefore resolves to `docker/`, which contains no `Dockerfile`.

Error:

```
failed to solve: failed to read dockerfile: open Dockerfile: no such file or directory
```

All three compose files (`compose.sqlite.yaml`, `compose.postgres.yaml`, `compose.sqlserver.yaml`) have the same `context: .`. All three break the same way.

**Fix options:**
- Change to `context: ..` in each compose file (cleanest — keeps the README invocation working as documented).
- Or document `--project-directory .` in the README, e.g. `docker compose --project-directory . -f docker/compose.sqlite.yaml up -d`.

### 2. `.env` at repo root is not auto-discovered

Compose searches for `.env` next to the compose file (`docker/.env`). The repo's `.env` sits at root, so `${JWT_SECRET_KEY}` interpolates to empty:

```
warning msg="The \"JWT_SECRET_KEY\" variable is not set. Defaulting to a blank string."
```

The app would start with a blank JWT signing key — `IOptions` validation would then fail at startup (silent until you read the container logs).

**Fix options:**
- Move `.env.example`/`.env` next to compose files (`docker/.env`).
- Or document `--env-file .env` flag in the README.
- Or set `--project-directory .` (which also fixes defect 1).

### 3. Dockerfile creates UID/GID 1000 — collides with base image

`Dockerfile:23`:

```dockerfile
RUN groupadd -g 1000 appuser && useradd -u 1000 -g appuser -m appuser
```

Error during `docker build`:

```
groupadd: GID '1000' already exists
process "/bin/sh -c groupadd -g 1000 appuser && useradd -u 1000 -g appuser -m appuser"
  did not complete successfully: exit code: 4
```

`mcr.microsoft.com/dotnet/aspnet:10.0` ships a pre-baked non-root user. Verified:

```
$ docker run --rm --entrypoint sh mcr.microsoft.com/dotnet/aspnet:10.0 \
    -c "id app; getent group 1000; id 1000"
uid=1654(app) gid=1654(app) groups=1654(app)
ubuntu:x:1000:
uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),...
```

Two collisions:
- The `ubuntu` user occupies UID/GID 1000.
- An `app` user is already present at UID 1654 — explicitly intended for non-root runtime.

The README claim "runs as non-root UID 1000" is wrong regardless of which fix is taken.

**Fix (recommended) — reuse the pre-baked `app` user:**

```dockerfile
# Replace lines 23-27 with:
RUN mkdir -p /data && chown -R app:app /app /data
USER app
```

Drop the manual `groupadd`/`useradd` entirely. Microsoft's base image already provides the non-root user and is the documented pattern for .NET 8+ images.

Also update `README.md:95`: change "non-root UID 1000" → "non-root `app` user" (UID is implementation detail; future base images may renumber it again).

## What I did NOT verify

Once the build fails at step 3, nothing downstream runs. The following remain untested:
- Container startup, `Database__AutoMigrate`, SQLite file creation in `/data`.
- `/health/live`, `/health/ready`, `/health` responses.
- `/scalar/v1` doc endpoint.
- The `compose.postgres.yaml` and `compose.sqlserver.yaml` paths beyond build (they share Dockerfile + compose patterns, so defects 1–3 apply equally; provider-specific issues unknown).
- Post-bootstrap path (`init-project` → single `docker/compose.yaml`).

## Suggested patch order

1. **Dockerfile** — drop manual user creation, use base image's `app` user. Without this, no compose file builds.
2. **compose.{sqlite,postgres,sqlserver}.yaml** — `context: .` → `context: ..` in all three.
3. **README.md** — fix the "non-root UID 1000" wording.
4. **Re-run** `docker compose -f docker/compose.sqlite.yaml up -d` from a clean repo with `.env.example` copied. Confirm `/health/live` returns 200 and `/scalar/v1` renders.

## Environment

- Windows 11, Docker Desktop 28.3.2, Compose v2.38.2-desktop.1
- Docker Desktop was not running at session start; needed manual launch (not a project bug, but worth noting if README ever moves to a "first run" checklist).
