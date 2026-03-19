---
phase: 01
slug: solution-scaffold-and-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xunit.v3 3.2.2 (not installed until Phase 6) |
| **Config file** | none — Phase 6 creates test projects |
| **Quick run command** | `dotnet build` |
| **Full suite command** | `dotnet build && dotnet run --project src/Starter.WebApi -- --urls http://localhost:5100` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dotnet build`
- **After every plan wave:** Run `dotnet build` + manual smoke test (start app, hit endpoints)
- **Before `/gsd:verify-work`:** Build succeeds, app starts, exception endpoints return correct ProblemDetails shapes
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | FOUND-01 | architectural | `dotnet build src/Starter.Shared/Starter.Shared.csproj` | N/A structural | ⬜ pending |
| 01-01-02 | 01 | 1 | FOUND-02 | architectural | `dotnet build src/Starter.WebApi/Starter.WebApi.csproj` | N/A structural | ⬜ pending |
| 01-01-03 | 01 | 1 | FOUND-03 | smoke | `dotnet build src/Starter.ExceptionHandling/Starter.ExceptionHandling.csproj` | N/A structural | ⬜ pending |
| 01-01-04 | 01 | 1 | FOUND-04 | manual-only | Visual inspection of Program.cs | N/A | ⬜ pending |
| 01-01-05 | 01 | 1 | FOUND-05 | smoke | Remove reference + calls, `dotnet build` | Phase 6 | ⬜ pending |
| 01-01-06 | 01 | 1 | FOUND-06 | architectural | .csproj inspection — no module-to-module refs | N/A structural | ⬜ pending |
| 01-01-07 | 01 | 1 | FOUND-07 | architectural | Verify only extension classes + contracts are public | N/A structural | ⬜ pending |
| 01-02-01 | 02 | 1 | CONF-01 | smoke | `dotnet build` + app starts with config section | N/A | ⬜ pending |
| 01-02-02 | 02 | 1 | CONF-02 | smoke | Remove config section, verify startup failure | N/A | ⬜ pending |
| 01-02-03 | 02 | 1 | CONF-03 | manual-only | Review appsettings comments | N/A | ⬜ pending |
| 01-03-01 | 03 | 2 | EXCP-01 | smoke | Start app, throw exception via endpoint, verify ProblemDetails | Phase 6 | ⬜ pending |
| 01-03-02 | 03 | 2 | EXCP-02 | smoke | Check response Content-Type: application/problem+json | Phase 6 | ⬜ pending |
| 01-03-03 | 03 | 2 | EXCP-03 | smoke | Check response in Dev (has stackTrace) vs Prod (no stackTrace) | Phase 6 | ⬜ pending |
| 01-03-04 | 03 | 2 | EXCP-04 | smoke | Check log output contains exception message | Phase 6 | ⬜ pending |
| 01-03-05 | 03 | 2 | EXCP-05 | architectural | Verify IExceptionHandler DI registration, no custom middleware | N/A structural | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Phase 1 has no test projects. Validation is build-success + manual verification via diagnostics controller.

*"Existing infrastructure covers all phase requirements."* — Test projects created in Phase 6.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Program.cs grouped-by-concern layout | FOUND-04 | Layout/comments are structural, not behavioral | Open Program.cs, verify Observability/Security/Data/API comment sections exist |
| Configuration guidance documented | CONF-03 | Documentation review | Check appsettings.json has comments describing User Secrets, env vars, Azure Key Vault |
| ProblemDetails response shape | EXCP-01, EXCP-02 | No test framework in Phase 1 | `curl` diagnostics endpoint, verify JSON has type/title/status/detail/instance/traceId fields |
| Stack trace visibility per environment | EXCP-03 | Requires running in both environments | Start in Development: verify stackTrace field present. Set ASPNETCORE_ENVIRONMENT=Production: verify stackTrace absent |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
