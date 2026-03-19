---
phase: 6
slug: testing-and-validation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xUnit 2.9.3 |
| **Config file** | None — Wave 0 creates test projects and config |
| **Quick run command** | `dotnet test tests/ --filter "Category!=Slow" --no-build` |
| **Full suite command** | `dotnet test tests/` |
| **Estimated runtime** | ~30 seconds (integration + unit + arch tests) |

---

## Sampling Rate

- **After every task commit:** Run `dotnet test tests/ --filter "Category!=Slow" --no-build`
- **After every plan wave:** Run `dotnet test tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | TEST-01 | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "HealthEndpointTests"` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | TEST-02 | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "HealthEndpointTests"` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | TEST-03 | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "AuthFlowTests"` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | TEST-04 | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "TodoCrudTests"` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 1 | TEST-05 | unit | `dotnet test tests/Starter.WebApi.Tests.Unit` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 1 | TEST-06 | architecture | `dotnet test tests/Starter.WebApi.Tests.Architecture --filter "ModuleIsolationTests"` | ❌ W0 | ⬜ pending |
| 06-03-02 | 03 | 1 | TEST-07 | architecture/smoke | `dotnet test tests/Starter.WebApi.Tests.Architecture --filter "ModuleRemovalTests"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Starter.WebApi.Tests.Integration/Starter.WebApi.Tests.Integration.csproj` — integration test project with WebApplicationFactory, SQLite, FluentAssertions 7.2.0
- [ ] `tests/Starter.WebApi.Tests.Integration/CustomWebApplicationFactory.cs` — shared fixture with SQLite in-memory + FakeAuthHandler
- [ ] `tests/Starter.WebApi.Tests.Integration/Helpers/FakeAuthHandler.cs` — auto-authenticate handler with configurable claims
- [ ] `tests/Starter.WebApi.Tests.Integration/appsettings.Testing.json` — config satisfying ValidateOnStart requirements
- [ ] `tests/Starter.WebApi.Tests.Unit/Starter.WebApi.Tests.Unit.csproj` — unit test project with Moq 4.20.72, FluentAssertions 7.2.0
- [ ] `tests/Starter.WebApi.Tests.Architecture/Starter.WebApi.Tests.Architecture.csproj` — architecture test project with NetArchTest.Rules 1.3.2
- [ ] `src/Starter.Data/Starter.Data.csproj` — InternalsVisibleTo for both Integration and Unit test projects
- [ ] `Starter.WebApi.slnx` — /Tests solution folder with 3 test project entries

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Google OAuth redirect flow | TEST-03 (partial) | External redirect not feasible in WebApplicationFactory | Verify Google OAuth is excluded from integration tests per CONTEXT.md decision |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
