# Docker Support — Implementation Plan

## Goal

Add first-class Docker support to `Starter.WebApi` that:

1. **Mirrors the module-removability ethos.** Just as each .NET module can be deleted by removing one extension call + project reference, each Docker artifact must be optional and trim-aware.
2. **Survives `init-project.ps1` cleanly.** After the user picks a single DB provider, only the matching compose file remains. No orphan services, no dead env vars, no `docker compose --profile` gymnastics.
3. **Provider-agnostic Dockerfile.** Single `Dockerfile` that builds whatever the host project references. After provider trim, the published image automatically shrinks.
4. **Production-ready defaults.** Multi-stage build, non-root user, healthcheck, `.dockerignore`, `latest`-pinned tags only for base images.
5. **Onboarding parity.** `docker compose up` replaces "install .NET 10 SDK + LocalDB/Postgres + Redis + Seq". Matches the starter-repo intent.
6. **Bash + PowerShell parity.** Every script change ships in both `.ps1` and `.sh` form (existing convention in `scripts/`).
7. **No code changes to modules.** All container-specific config goes via env vars (`Database__Provider`, `ConnectionStrings__*`, `Jwt__SecretKey`, etc.) — already supported by `IOptions<T>` binding.

## Things the Orchestrator Should Keep in Mind

- **Do not break module-removability.** No global middleware, no Docker-only code paths inside modules. Docker is purely a packaging/deploy concern.
- **Do not commit secrets.** `.env` files and JWT keys must be `.gitignore`d. Compose files reference env vars; values come from `.env`.
- **`select-db-provider.ps1` and `init-project.ps1` are the single source of truth for trim logic.** Any new artifact that varies per provider must be trimmed by `select-db-provider`. Any new bootstrap step belongs in `init-project`.
- **Sqlite needs a volume mount.** Connection string in container must point to the mounted path (`/data/starter.db`), not the host project root.
- **`AutoMigrate=true` already exists in `appsettings.json`.** Compose must wait for DB readiness via `depends_on: condition: service_healthy` so first-boot migration succeeds.
- **Kestrel HTTPS dev cert does not work in containers.** Container runs HTTP-only on port 8080. TLS is the reverse-proxy's job in production.
- **`appsettings.json` Cors entry `https://localhost:5101` will be wrong inside container.** Override via env in compose.
- **Bootstrap scripts are skipped by `rename-project.ps1` by default.** Docker artifacts are NOT bootstrap scripts — they ARE renamed/trimmed normally.
- **Test on Linux containers only.** `mcr.microsoft.com/dotnet/aspnet:10.0` Linux. No Windows containers.
- **Verify after each subtask.** Each subtask has a success criterion. Do not advance until the criterion passes.

---

## Subtasks

### Task 1 — Create `.dockerignore`

**What:** Add `.dockerignore` at repo root. Excludes build artifacts, IDE state, secrets, local DB files, and the planning doc itself.

**Contents (minimum):**
```
**/bin/
**/obj/
**/.vs/
**/Logs/
**/*.db
**/*.db-shm
**/*.db-wal
**/*.user
.git/
.gitignore
.dockerignore
.env
.env.*
DOCKER-PLAN.md
README.md
LICENSE
data/
scripts/
```

**Success criteria:**
- File exists at `F:\Personal\bootstrapper-apps\web-api\.dockerignore`.
- `docker build` (Task 2) produces an image with no `bin/`, `obj/`, `.git/`, or `*.db` entries inside `/app`.
- Image build context size < 5 MB (verify with `docker build --progress=plain` output).

---

### Task 2 — Create universal `Dockerfile`

**What:** Multi-stage Dockerfile at repo root. Stage 1 restores + publishes via SDK image. Stage 2 copies publish output into the slim ASP.NET runtime image. Runs as non-root, exposes 8080, defines `HEALTHCHECK` against `/health`.

**Required sections:**
- `FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build` — copies `.slnx`, all `*.csproj`, restores, then copies the rest and publishes the host project to `/publish` with `-c Release --no-restore`.
- Layer-cache the restore: copy csproj files first, run `dotnet restore`, then copy source.
- `FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime` — `WORKDIR /app`, `COPY --from=build /publish .`.
- Reuse the base image's pre-baked non-root `app` user (UID 1654 in current `mcr.microsoft.com/dotnet/aspnet:10.0`), `chown` `/app` and `/data` to `app:app`, `USER app`. (Manual `groupadd -g 1000` collides with the base image's `ubuntu` user at UID 1000.)
- `ENV ASPNETCORE_URLS=http://+:8080 ASPNETCORE_ENVIRONMENT=Production DOTNET_RUNNING_IN_CONTAINER=true`.
- `EXPOSE 8080`.
- `HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD wget -qO- http://localhost:8080/health/live || exit 1`.
- `ENTRYPOINT ["dotnet", "Starter.WebApi.dll"]` — note: project rename will rewrite `Starter` → new prefix automatically since the file goes through `rename-project.ps1`.

**Success criteria:**
- `docker build -t starter-webapi:dev .` completes without error.
- `docker images starter-webapi:dev` reports image size < 350 MB.
- `docker run --rm -p 8080:8080 -e Jwt__SecretKey=$(openssl rand -base64 48) starter-webapi:dev` starts cleanly; `curl http://localhost:8080/health/live` returns 200.
- Container process runs as the base image's pre-baked non-root `app` user (currently UID 1654; verify: `docker exec <id> id`).

---

### Task 3 — Create `docker/compose.sqlite.yaml`

**What:** Compose file for the Sqlite-only stack. Single `api` service. Named volume `starter-data` mounted at `/data`. Connection string overrides Sqlite path to `/data/starter.db`.

**Required services & config:**
- `api` service:
  - `build: { context: ., dockerfile: Dockerfile }`
  - `ports: ["8080:8080"]`
  - `environment:`
    - `Database__Provider=Sqlite`
    - `ConnectionStrings__Sqlite=Data Source=/data/starter.db`
    - `Jwt__SecretKey=${JWT_SECRET_KEY}`
    - `Cors__AllowedOrigins__0=${CORS_ORIGIN:-http://localhost:8080}`
  - `volumes: ["starter-data:/data"]`
  - `restart: unless-stopped`
- `volumes: { starter-data: {} }`

**Success criteria:**
- `docker compose -f docker/compose.sqlite.yaml config` validates without warnings.
- `docker compose -f docker/compose.sqlite.yaml up -d` starts the api container; healthcheck transitions to `healthy` within 60 s.
- `curl http://localhost:8080/health/ready` returns 200.
- Restart container: `docker compose ... restart api` — Sqlite data persists (verify by inserting a row, restarting, querying).

---

### Task 4 — Create `docker/compose.postgres.yaml`

**What:** Compose file for the Postgres stack. Adds `postgres` service with healthcheck. `api` waits on `service_healthy`.

**Required services & config:**
- `postgres` service:
  - `image: postgres:16-alpine`
  - `environment: { POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB }` from `.env`
  - `volumes: ["postgres-data:/var/lib/postgresql/data"]`
  - `healthcheck: { test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"], interval: 10s, timeout: 3s, retries: 5 }`
- `api` service:
  - Same as Sqlite except:
    - `Database__Provider=PostgreSql`
    - `ConnectionStrings__PostgreSql=Host=postgres;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}`
  - `depends_on: { postgres: { condition: service_healthy } }`
- `volumes: { postgres-data: {} }`

**Success criteria:**
- `docker compose -f docker/compose.postgres.yaml config` validates.
- `docker compose -f docker/compose.postgres.yaml up -d` starts both services; api becomes healthy AFTER postgres reports healthy.
- EF migrations apply on first boot (check api logs for `Applied migration` lines).
- `curl http://localhost:8080/health/ready` returns 200.

---

### Task 5 — Create `docker/compose.sqlserver.yaml`

**What:** Compose file for the SqlServer stack. Adds `mssql` service with healthcheck. `api` waits on `service_healthy`.

**Required services & config:**
- `mssql` service:
  - `image: mcr.microsoft.com/mssql/server:2022-latest`
  - `environment: { ACCEPT_EULA=Y, MSSQL_SA_PASSWORD=${MSSQL_SA_PASSWORD}, MSSQL_PID=Developer }`
  - `volumes: ["mssql-data:/var/opt/mssql"]`
  - `healthcheck: { test: ["CMD-SHELL", "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"$$MSSQL_SA_PASSWORD\" -No -Q 'SELECT 1' || exit 1"], interval: 10s, timeout: 5s, retries: 10, start_period: 30s }`
- `api` service:
  - `Database__Provider=SqlServer`
  - `ConnectionStrings__SqlServer=Server=mssql;Database=StarterDb;User Id=sa;Password=${MSSQL_SA_PASSWORD};TrustServerCertificate=True`
  - `depends_on: { mssql: { condition: service_healthy } }`
- `volumes: { mssql-data: {} }`

**Success criteria:**
- `docker compose -f docker/compose.sqlserver.yaml config` validates.
- `docker compose -f docker/compose.sqlserver.yaml up -d` starts both services; api becomes healthy after mssql.
- EF migrations apply on first boot.
- `curl http://localhost:8080/health/ready` returns 200.

---

### Task 6 — Add `.env.example` template

**What:** Create `.env.example` at repo root listing every env var any compose file consumes. Documented with comments. Real `.env` is gitignored (Task 7) and generated by `init-project` (Task 9).

**Required keys:**
```
# JWT signing key — auto-generated by init-project.ps1
JWT_SECRET_KEY=

# CORS allowed origin (default: http://localhost:8080)
CORS_ORIGIN=http://localhost:8080

# Postgres (only used by compose.postgres.yaml)
POSTGRES_USER=starter
POSTGRES_PASSWORD=
POSTGRES_DB=starterdb

# SqlServer (only used by compose.sqlserver.yaml)
MSSQL_SA_PASSWORD=
```

**Success criteria:**
- File exists at repo root, committed.
- Every variable referenced via `${VAR}` in any compose file appears here with a default or comment.
- `docker compose -f docker/compose.<provider>.yaml --env-file .env.example config` validates for all 3 providers (with placeholder passwords).

---

### Task 7 — Update `.gitignore`

**What:** Append entries for env files and Docker-managed local data.

**Append:**
```
# Docker / env
.env
.env.local
.env.*.local
data/
```

**Success criteria:**
- `git status` after creating a `.env` file shows nothing (file is ignored).
- `.env.example` is NOT ignored (still tracked).

---

### Task 8 — Extend `select-db-provider.ps1` and `select-db-provider.sh` to trim compose files

**What:** Add a phase (after the existing migration-project trim) that deletes the 2 unused compose files and renames the chosen one to `docker/compose.yaml`. Use `git rm` and `git mv` so the changes are staged.

**Algorithm (PowerShell pseudocode):**
```powershell
$composeDir = Join-Path $rootDir 'docker'
$keepFile   = Join-Path $composeDir "compose.$($Provider.ToLower()).yaml"
$finalFile  = Join-Path $composeDir 'compose.yaml'

if (Test-Path $keepFile) {
    Get-ChildItem $composeDir -Filter 'compose.*.yaml' |
        Where-Object { $_.FullName -ne (Resolve-Path $keepFile).Path } |
        ForEach-Object { git -C $rootDir rm $_.FullName | Out-Null }

    git -C $rootDir mv $keepFile $finalFile | Out-Null
}
```

**Mirror in `select-db-provider.sh`** using `git rm` / `git mv` and bash provider lowercasing.

**Also:** Strip provider-specific env keys from `.env.example` to keep the trimmed template clean (e.g., delete `MSSQL_*` lines if Postgres chosen). Optional — can defer.

**Success criteria:**
- Run `./scripts/select-db-provider.ps1 -Provider Sqlite -Force` on a fresh clone: `docker/compose.yaml` exists with Sqlite content; `compose.sqlite.yaml`, `compose.postgres.yaml`, `compose.sqlserver.yaml` are gone.
- `git status` shows the rename + deletes as staged.
- Repeat for `-Provider Postgres` and `-Provider SqlServer` (separate test runs) — same behavior, correct file kept.
- Bash version produces identical result on WSL/Linux.

---

### Task 9 — Extend `init-project.ps1` and `init-project.sh` to generate `.env`

**What:** After the JWT-secret phase (Phase 6 in current `init-project.ps1`), add a phase that writes `.env` with the generated JWT key and provider-specific defaults. Skip if `-NoEnvFile` flag passed.

**Algorithm:**
1. After JWT secret generated, base64-encode it (already done) and write to `.env`:
   - `JWT_SECRET_KEY=<value>`
   - `CORS_ORIGIN=http://localhost:8080`
   - If `Provider == 'PostgreSql'`: add `POSTGRES_USER=starter`, `POSTGRES_PASSWORD=<random 24-byte base64>`, `POSTGRES_DB=starterdb`.
   - If `Provider == 'SqlServer'`: add `MSSQL_SA_PASSWORD=<random 24-byte base64 — must satisfy SQL Server complexity rules; prepend `Aa1!` if needed>`.
   - If `Provider == 'Sqlite'`: no extra keys.
2. File mode: 600 on Linux (`chmod 600`); on Windows skip.
3. Print: "Wrote .env (gitignored). Run: docker compose up"

**Add CLI flag:** `[switch]$NoEnvFile` — forwarded from `init-project` to skip Phase 7.

**Update plan summary block** in `init-project.ps1` to mention the new Step 4/4.

**Mirror in `init-project.sh`.**

**Success criteria:**
- Run `./scripts/init-project.ps1 -NewPrefix Acme -Provider Sqlite -Force`: `.env` exists, contains `JWT_SECRET_KEY=<48-byte base64>`, no Postgres/SqlServer keys.
- Run with `-Provider PostgreSql`: `.env` contains JWT + Postgres trio.
- Run with `-Provider SqlServer`: `.env` contains JWT + `MSSQL_SA_PASSWORD` (verified 16+ chars, mixed case, digit, symbol).
- Run with `-NoEnvFile`: no `.env` file produced.
- `git status` confirms `.env` is ignored, `.env.example` stays tracked.

---

### Task 10 — Update `rename-project.ps1` and `rename-project.sh` to handle Docker files

**What:** Verify that the existing rename logic (which walks file content + filenames) correctly rewrites:
- `Dockerfile` `ENTRYPOINT` line: `Starter.WebApi.dll` → `Acme.WebApi.dll`.
- All compose files: image names, container names if hardcoded, env var prefixes that contain `Starter`.
- `.env.example` if it contains `Starter`.

**No new code expected** — rename script already does generic find/replace. This task is verification + adding test coverage.

**Success criteria:**
- After `./scripts/rename-project.ps1 -NewPrefix Acme -Force` on a fresh clone, grep the `docker/` directory and `Dockerfile` for `Starter` — must return zero hits.
- `docker build` still succeeds after rename.

---

### Task 11 — Add architecture/smoke test for Docker artifacts

**What:** In `src/tests/Starter.WebApi.Tests.Architecture`, add a test that asserts:
- `Dockerfile` exists at repo root.
- Exactly one `compose.*.yaml` matches the selected provider OR exactly one `compose.yaml` exists post-trim (the test should accept either pre-trim or post-trim state).
- `.dockerignore` exists.
- `.env.example` exists.

Use `Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "..")` or walk up to find repo root by locating `.slnx`.

**Success criteria:**
- Test passes on a fresh clone (pre-trim, all 3 compose files present).
- Test passes after `select-db-provider.ps1` runs (post-trim, single `compose.yaml`).
- Test fails if any of the required files is deleted.

---

### Task 12 — Update `README.md` with Docker section

**What:** Add a top-level "## Docker" section after the existing quick-start. Cover:
- Pre-bootstrap (3 compose files): `docker compose -f docker/compose.<provider>.yaml up`
- Post-bootstrap (single file): `docker compose up`
- `.env` generation: produced by `init-project.ps1` automatically; manual users copy `.env.example` to `.env` and fill in.
- Endpoint: `http://localhost:8080`, `/health`, `/scalar/v1`.
- Production notes: TLS at reverse proxy, set `Database__AutoMigrate=false` for multi-replica.

**Success criteria:**
- `README.md` renders correctly on GitHub.
- A new user can go from `git clone` → working API in container by following only the Docker section.

---

### Task 13 — End-to-end verification matrix

**What:** Manual verification run after Tasks 1–12 land. Not committed code — checklist run before merging.

**Matrix (9 cells):**

| Provider × State | Pre-trim (3 compose files) | Post-trim (1 compose file) | After rename |
|---|---|---|---|
| Sqlite | ✓ build, up, /health 200 | ✓ build, up, /health 200 | ✓ build, up, /health 200 |
| PostgreSql | ✓ build, up, migrate, /health 200 | ✓ same | ✓ same |
| SqlServer | ✓ build, up, migrate, /health 200 | ✓ same | ✓ same |

**Success criteria:**
- All 9 cells pass.
- `dotnet test` still passes (architecture tests in particular).
- `docker images` shows < 350 MB final image for all providers.
- No `Starter` strings in renamed-project Docker artifacts.

---

## Out of Scope (Defer to Future Iteration)

- Multi-arch builds (`buildx` for arm64).
- Production-grade compose with reverse proxy (Caddy/Traefik) + TLS.
- Kubernetes manifests / Helm chart.
- Optional infra modules: Redis service, Seq service, OTLP collector. (Mentioned in initial analysis; add as a follow-up `compose.observability.yaml` overlay.)
- AOT / trimmed publish. Current image is framework-dependent.
- CI workflow for `docker build` + push to registry. Belongs in a separate `.github/workflows/` task.

## Execution Order

Tasks have light dependencies. Recommended order: **1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13**.

Tasks 3, 4, 5 can run in parallel (independent compose files).
Tasks 8 and 9 can run in parallel (different scripts, different concerns).
Task 13 is the gate before merge.
