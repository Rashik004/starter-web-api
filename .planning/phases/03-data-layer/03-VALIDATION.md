---
phase: 3
slug: data-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None yet — Testing is Phase 6 |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `dotnet build Starter.WebApi.slnx` |
| **Full suite command** | N/A until Phase 6 |
| **Estimated runtime** | ~15 seconds (build only) |

---

## Sampling Rate

- **After every task commit:** Run `dotnet build Starter.WebApi.slnx`
- **After every plan wave:** Run application and verify SQLite DB creation + CRUD via TodoController
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | DATA-01 | smoke | `dotnet run --project src/Starter.WebApi` + verify DB file created | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | DATA-02 | manual-only | Requires SQL Server instance to validate | ❌ Phase 6 | ⬜ pending |
| 03-01-03 | 01 | 1 | DATA-03 | manual-only | Requires PostgreSQL instance to validate | ❌ Phase 6 | ⬜ pending |
| 03-01-04 | 01 | 1 | DATA-04 | unit | `dotnet ef migrations list --startup-project src/Starter.WebApi --project src/Starter.Data.Migrations.Sqlite -- --provider Sqlite` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | DATA-05 | smoke | `./scripts/add-migration.sh Sqlite TestMigration` (then revert) | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | DATA-06 | smoke | `curl` to TodoController CRUD endpoints after app start | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] No test project exists yet — Testing is Phase 6
- [ ] Verification is currently manual: run app, check SQLite file, exercise CRUD endpoints
- [ ] Framework install deferred to Phase 6: `dotnet new xunit -n Starter.Tests.Integration`

*Formal automated testing infrastructure is Phase 6. Phase 3 validation is compilation + manual smoke testing.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SQL Server provider works | DATA-02 | Requires SQL Server instance | Change `Database:Provider` to `SqlServer`, set connection string, run app, verify tables created |
| PostgreSQL provider works | DATA-03 | Requires PostgreSQL instance | Change `Database:Provider` to `PostgreSql`, set connection string, run app, verify tables created |
| Todo CRUD end-to-end | DATA-06 | No test harness yet (Phase 6) | Run app, curl POST/GET/PUT/DELETE to `/api/todos`, verify responses |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
