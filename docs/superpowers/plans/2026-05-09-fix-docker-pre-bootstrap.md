# Fix Docker Pre-Bootstrap Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `docker compose -f docker/compose.sqlite.yaml up -d` (and the postgres/sqlserver variants) actually work on a fresh-template clone, with HTTP 200 from `/health/live`.

**Architecture:** Three independent defects break the documented pre-bootstrap docker flow before the container starts: (1) `context: .` in the compose files resolves to `docker/` instead of repo root, (2) `${JWT_SECRET_KEY}` interpolation can't see `.env` at repo root when compose is loaded via `-f docker/...`, (3) `Dockerfile` `groupadd -g 1000` collides with `mcr.microsoft.com/dotnet/aspnet:10.0`'s pre-existing `ubuntu` user. Fix Dockerfile to reuse the base image's pre-baked `app` user (UID 1654), change compose `context: .` → `context: ..`, and update README invocations to pass `--project-directory .` so compose discovers `.env` at repo root with a single flag.

**Tech Stack:** Docker 28+, Docker Compose v2, .NET 10 ASP.NET runtime image, bash + PowerShell scripts.

**Reference:** See `DOCKER-INVESTIGATION.md` for the diagnostic that produced this plan.

**Out of scope:**
- Restructuring init-project.{sh,ps1} to write `.env` into `docker/` instead of root.
- Adding a CI smoke test that builds the image (worth doing later — no test currently catches these defects).
- Provider-specific runtime issues for postgres/sqlserver (only build + container start are in scope here; full migration runs are a follow-up).

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `Dockerfile` | Multi-stage build, runtime image | Drop manual `groupadd`/`useradd`; reuse base image's `app` user |
| `docker/compose.sqlite.yaml` | SQLite dev compose | `context: .` → `context: ..` |
| `docker/compose.postgres.yaml` | Postgres compose | `context: .` → `context: ..` |
| `docker/compose.sqlserver.yaml` | SQL Server compose | `context: .` → `context: ..` |
| `README.md` | User-facing docs | Add `--project-directory .` flag to all `docker compose` invocations; correct "non-root UID 1000" wording |
| `DOCKER-INVESTIGATION.md` | Diagnostic notes | Delete after fixes verified (replaced by passing flow) |

No new files. No test files (the existing test projects use `WebApplicationFactory` and never touch the container — adding a docker smoke-test script is a separate plan).

---

## Verification Strategy

There is no automated test that exercises the docker flow today. Verification = "build, run, curl `/health/live` returns 200, container shuts down clean." Each task that touches a compose file or Dockerfile re-runs the same end-to-end check on the SQLite path. Postgres + SqlServer get build-only checks (full DB startup is slow and noisy; defer full verification until a smoke-test script exists).

The "failing test" for each fix is the existing repro from `DOCKER-INVESTIGATION.md`; the "passing test" is the same command succeeding.

---

### Task 1: Fix Dockerfile UID collision

**Files:**
- Modify: `Dockerfile:23-27`

**Why:** `mcr.microsoft.com/dotnet/aspnet:10.0` already has `ubuntu` at UID/GID 1000 (verified) and a pre-baked non-root `app` user at UID 1654. `groupadd -g 1000 appuser` fails with `groupadd: GID '1000' already exists`. Microsoft's documented pattern for .NET 8+ is to reuse the `app` user.

- [ ] **Step 1: Reproduce the failure (capture baseline)**

Run from repo root:

```bash
cp .env.example .env
# edit .env: set JWT_SECRET_KEY to any 32+ byte base64
docker compose --project-directory . -f docker/compose.sqlite.yaml build api 2>&1 | tail -20
```

Expected: build fails with `groupadd: GID '1000' already exists` at the `RUN groupadd ...` step. (Also confirms Task 2's `context: ..` fix is not yet applied — without `--project-directory .`, the `Dockerfile not found` error from defect 1 fires first and masks this one. `--project-directory .` reassigns project dir to repo root so `context: .` in the unfixed compose file resolves to root, exposing the Dockerfile error.)

- [ ] **Step 2: Edit Dockerfile to reuse base image's `app` user**

Replace lines 23-27:

```dockerfile
RUN groupadd -g 1000 appuser && useradd -u 1000 -g appuser -m appuser

RUN mkdir -p /data && chown -R appuser:appuser /app /data

USER appuser
```

with:

```dockerfile
RUN mkdir -p /data && chown -R app:app /app /data

USER app
```

The `app` user (UID 1654) is provisioned by the Microsoft base image. No `groupadd`/`useradd` needed. `/app` is the `WORKDIR`; `/data` is mounted by compose.

- [ ] **Step 3: Verify the build now reaches the next defect (or succeeds, depending on Task 2 ordering)**

Run:

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml build api 2>&1 | tail -10
```

Expected: build completes (`exporting layers ... DONE`, `naming to docker.io/library/...`). The `groupadd` error must be gone. If you see `failed to read dockerfile`, that is defect 1 — proceed to Task 2.

- [ ] **Step 4: Commit**

```bash
git add Dockerfile
git commit -m "fix(docker): reuse base image's pre-baked app user

The mcr.microsoft.com/dotnet/aspnet:10.0 image ships a non-root
'app' user at UID 1654 and 'ubuntu' at UID 1000. The previous
groupadd -g 1000 collided with 'ubuntu' and broke every build.
Drop the manual user creation and adopt Microsoft's documented
pattern of reusing the pre-baked app user."
```

---

### Task 2: Fix compose build-context paths

**Files:**
- Modify: `docker/compose.sqlite.yaml:3-5`
- Modify: `docker/compose.postgres.yaml:18-21`
- Modify: `docker/compose.sqlserver.yaml:19-22`

**Why:** `docker compose -f docker/compose.<x>.yaml ...` sets project dir to `docker/` by default. `context: .` resolves there, but `Dockerfile` lives at repo root → `failed to read dockerfile: open Dockerfile: no such file or directory`. Changing to `context: ..` makes the build context = repo root regardless of project dir, which keeps the README invocation flag-free for users who don't need `.env` interpolation tweaks.

- [ ] **Step 1: Reproduce the failure (without `--project-directory`)**

Run:

```bash
docker compose -f docker/compose.sqlite.yaml build api 2>&1 | tail -5
```

Expected: `failed to solve: failed to read dockerfile: open Dockerfile: no such file or directory`.

- [ ] **Step 2: Edit `docker/compose.sqlite.yaml`**

Replace:

```yaml
    build:
      context: .
      dockerfile: Dockerfile
```

with:

```yaml
    build:
      context: ..
      dockerfile: Dockerfile
```

- [ ] **Step 3: Edit `docker/compose.postgres.yaml`**

Same change at the `api` service `build:` block:

```yaml
  api:
    build:
      context: ..
      dockerfile: Dockerfile
```

- [ ] **Step 4: Edit `docker/compose.sqlserver.yaml`**

Same change at the `api` service `build:` block:

```yaml
  api:
    build:
      context: ..
      dockerfile: Dockerfile
```

- [ ] **Step 5: Verify build now succeeds without `--project-directory`**

```bash
docker compose -f docker/compose.sqlite.yaml build api 2>&1 | tail -5
```

Expected: `naming to docker.io/library/docker-api ... DONE` (or similar success line). No `failed to read dockerfile`.

- [ ] **Step 6: Verify the postgres + sqlserver compose files build (they share the Dockerfile)**

```bash
docker compose -f docker/compose.postgres.yaml build api 2>&1 | tail -3
docker compose -f docker/compose.sqlserver.yaml build api 2>&1 | tail -3
```

Expected: both succeed. (Postgres/SqlServer service images are pre-built upstream; only `api` builds locally.)

- [ ] **Step 7: Commit**

```bash
git add docker/compose.sqlite.yaml docker/compose.postgres.yaml docker/compose.sqlserver.yaml
git commit -m "fix(docker): set compose build context to repo root

context: . resolves relative to the compose file location
(docker/), but Dockerfile lives at repo root, so every build
failed with 'failed to read dockerfile'. Use context: .. so
the README invocation 'docker compose -f docker/compose.X.yaml
up -d' works without extra flags."
```

---

### Task 3: Update README to document `.env` discovery

**Files:**
- Modify: `README.md:60-81` (Docker → Pre-bootstrap and Post-bootstrap sections)
- Modify: `README.md:95` (Production notes — UID claim)

**Why:** Even with Tasks 1+2 applied, `${JWT_SECRET_KEY}` interpolation looks for `.env` next to the compose file (`docker/.env`), not at repo root where `init-project` writes it. Pass `--project-directory .` to set project dir to repo root → compose finds `./.env` automatically. Also fix the false "non-root UID 1000" claim — the container runs as `app` (UID 1654).

- [ ] **Step 1: Reproduce the silent .env discovery failure**

```bash
cp .env.example .env  # if not already present
docker compose -f docker/compose.sqlite.yaml config 2>&1 | grep -E "(WARNING|JWT_SECRET_KEY|warning)"
```

Expected: `warning msg="The \"JWT_SECRET_KEY\" variable is not set. Defaulting to a blank string."`

- [ ] **Step 2: Confirm `--project-directory .` resolves the warning**

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml config 2>&1 | grep -E "(WARNING|warning|Jwt__SecretKey)"
```

Expected: no warning. The `Jwt__SecretKey: <value>` line shows the actual JWT, not blank.

- [ ] **Step 3: Edit README pre-bootstrap section**

In `README.md` (lines ~60-64), replace:

```bash
docker compose -f docker/compose.sqlite.yaml     up -d   # SQLite (default)
docker compose -f docker/compose.postgres.yaml   up -d   # PostgreSQL
docker compose -f docker/compose.sqlserver.yaml  up -d   # SQL Server
```

with:

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml     up -d   # SQLite (default)
docker compose --project-directory . -f docker/compose.postgres.yaml   up -d   # PostgreSQL
docker compose --project-directory . -f docker/compose.sqlserver.yaml  up -d   # SQL Server
```

Add this note immediately after the code block (before "The compose files read..."):

```markdown
The `--project-directory .` flag tells compose to read `.env` from the repo root (where `.env.example` lives). Without it, compose looks for `docker/.env` and silently sets `JWT_SECRET_KEY` to blank, which fails IOptions validation at startup.
```

- [ ] **Step 4: Edit README post-bootstrap section**

In `README.md` (lines ~75-79), replace:

```bash
docker compose up -d
```

with:

```bash
docker compose --project-directory . -f docker/compose.yaml up -d
```

(After `init-project` runs `select-db-provider`, the kept compose file is renamed to `docker/compose.yaml`. `docker compose up -d` from repo root finds nothing because there is no top-level compose file.)

- [ ] **Step 5: Edit README production notes (UID wording)**

In `README.md:95`, replace:

```markdown
- **Image**: framework-dependent, runs as non-root UID 1000, healthcheck hits `/health/live`.
```

with:

```markdown
- **Image**: framework-dependent, runs as the base image's pre-baked non-root `app` user, healthcheck hits `/health/live`.
```

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs(docker): document --project-directory flag for .env discovery

Compose looks for .env next to the compose file by default. With
.env at repo root and compose files under docker/, --project-directory .
is required for \${JWT_SECRET_KEY} interpolation. Also correct the
'non-root UID 1000' claim — the runtime user is whatever UID the
base image's app user has (currently 1654)."
```

---

### Task 4: End-to-end SQLite verification

**Files:**
- No file changes. This is a manual verification gate before declaring the fix complete.

**Why:** Tasks 1-3 each had a narrow "did the failure mode go away" check. This task confirms the whole flow works as documented.

- [ ] **Step 1: Clean any stale containers/images from prior attempts**

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml down -v 2>&1 | tail -3
docker image rm docker-api 2>/dev/null || true
```

Expected: no error (or "No such image").

- [ ] **Step 2: Confirm `.env` is set up**

```bash
test -f .env && grep -E "^JWT_SECRET_KEY=." .env && echo "env OK"
```

Expected: `env OK`. If missing, `cp .env.example .env` and set `JWT_SECRET_KEY` to `$(openssl rand -base64 48)`.

- [ ] **Step 3: Bring the stack up exactly as the README documents**

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml up -d --build 2>&1 | tail -10
```

Expected: `Container <name>-api-1  Started`. No warnings about unset variables.

- [ ] **Step 4: Wait for healthy + hit `/health/live`**

```bash
until [ "$(docker inspect -f '{{.State.Health.Status}}' $(docker compose --project-directory . -f docker/compose.sqlite.yaml ps -q api) 2>/dev/null)" = "healthy" ]; do sleep 2; done
curl -fsS http://localhost:8080/health/live
```

Expected: `Healthy` (or HTTP 200 with body indicating live state).

- [ ] **Step 5: Hit `/health/ready` (DB connectivity)**

```bash
curl -fsS http://localhost:8080/health/ready
```

Expected: HTTP 200, indicating the SQLite migration ran and the DB is reachable.

- [ ] **Step 6: Hit `/scalar/v1` (API docs)**

```bash
curl -fsS -o /dev/null -w "%{http_code}\n" http://localhost:8080/scalar/v1
```

Expected: `200`.

- [ ] **Step 7: Smoke-test the auth + todos flow inside the container**

```bash
TOKEN=$(curl -sS -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke@example.com","password":"P@ssw0rd!"}' | jq -r .accessToken)
echo "TOKEN length: ${#TOKEN}"
curl -fsS -X POST http://localhost:8080/api/v1/todos \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"docker smoke"}' | jq .
curl -fsS http://localhost:8080/api/v1/todos -H "Authorization: Bearer $TOKEN" | jq .
```

Expected: token length > 100, POST returns the created todo with an id, GET returns a list containing it.

- [ ] **Step 8: Confirm container is running as non-root**

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml exec -T api id
```

Expected: `uid=1654(app) gid=1654(app) groups=1654(app)`. Confirms the Task 1 fix actually applied at runtime, not just at build time.

- [ ] **Step 9: Tear down**

```bash
docker compose --project-directory . -f docker/compose.sqlite.yaml down -v 2>&1 | tail -3
```

Expected: containers + volume removed.

- [ ] **Step 10: Delete `DOCKER-INVESTIGATION.md` (replaced by passing flow)**

```bash
rm DOCKER-INVESTIGATION.md
git add -u DOCKER-INVESTIGATION.md
git commit -m "docs: remove docker investigation report

Defects documented in DOCKER-INVESTIGATION.md are fixed in
the prior commits on this branch. The README now reflects the
working invocation."
```

---

### Task 5: Postgres + SqlServer build-only smoke checks

**Files:**
- No file changes. Verification gate to ensure the multi-provider compose files at least build.

**Why:** Full migration verification for postgres/sqlserver is heavy (long pulls, password setup) and is a separate plan. Confirm at least the build path works for both.

- [ ] **Step 1: Confirm postgres compose builds**

```bash
docker compose --project-directory . -f docker/compose.postgres.yaml build api 2>&1 | tail -3
```

Expected: build succeeds (image is reused from Task 4 layer cache; no errors).

- [ ] **Step 2: Confirm sqlserver compose builds**

```bash
docker compose --project-directory . -f docker/compose.sqlserver.yaml build api 2>&1 | tail -3
```

Expected: build succeeds.

- [ ] **Step 3: Document the gap**

Add a single line to README's "Production notes" or near the compose file list:

```markdown
> Postgres and SqlServer compose paths build successfully but full container-startup verification with migrations is left for a follow-up smoke-test script. SQLite is the verified-working path.
```

(If this feels noisy, skip and just open a follow-up issue. Document either way.)

- [ ] **Step 4: Commit if README touched**

```bash
git add README.md
git commit -m "docs(docker): note SqlServer/Postgres verification gap"
```

---

## Self-Review

**Spec coverage:**
- Defect 1 (UID collision) → Task 1. ✓
- Defect 2 (compose context) → Task 2. ✓
- Defect 3 (.env discovery) → Task 3. ✓
- README "non-root UID 1000" wording → Task 3 Step 5. ✓
- Post-bootstrap path likely also broken → Task 3 Step 4. ✓
- End-to-end verification → Task 4. ✓
- Multi-provider sanity → Task 5. ✓

**Placeholder scan:** No "TBD", "later", "similar to". All code blocks present. All file paths absolute or anchored to repo root.

**Type/path consistency:** `app` user used consistently in Task 1 + verified in Task 4 Step 8. `--project-directory .` flag consistent across all README invocations and verification commands.

**Known risks:**
- Task 4 Step 4's `until` loop has no timeout. If the container never goes healthy (e.g., DB migration hangs), the loop runs forever. Add `timeout 60 bash -c 'until ...'` if running unattended.
- Task 4 Step 7 assumes `jq` is installed. Acceptable — README's "Try It" section already requires it.
- If `docker compose down -v` removed an important volume in Task 4 Step 1, the only data loss is the SQLite file in `starter-data` volume — disposable for verification.

---

## Plan Correction (post-Task 3)

Task 4 verification surfaced that Tasks 2 and 3 as originally written were incompatible. Task 2 changed `context: .` → `context: ..` so the build would work without `--project-directory`, while Task 3 added `--project-directory .` to all README invocations for `.env` discovery. With `--project-directory .` set to the repo root, compose resolves `context: ..` to the repo-root's *parent* (no Dockerfile there) and the build fails. Task 2's `context: ..` change has been reverted: compose files now keep the original `context: .`, and the correct working invocation is `docker compose --project-directory . -f docker/compose.<x>.yaml ...` — `--project-directory .` makes `context: .` resolve to the repo root, which has the Dockerfile and the `.env` file. Both interpolation and build work.
