---
phase: 02
slug: observability
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xunit.v3 3.2.2 (not yet installed — Phase 6) |
| **Config file** | none — test projects not yet created |
| **Quick run command** | `dotnet build` |
| **Full suite command** | `dotnet build` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dotnet build` (verify compilation)
- **After every plan wave:** Run `dotnet build` (no test project yet)
- **Before `/gsd:verify-work`:** Manual verification of logging output; test infrastructure deferred to Phase 6
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | LOG-01 | manual (integration) | `dotnet build` | N/A | ⬜ pending |
| 02-01-02 | 01 | 1 | LOG-02 | manual (config) | `dotnet build` | N/A | ⬜ pending |
| 02-01-03 | 01 | 1 | LOG-03 | manual (config) | `dotnet build` | N/A | ⬜ pending |
| 02-01-04 | 01 | 1 | LOG-04 | manual (config) | `dotnet build` | N/A | ⬜ pending |
| 02-01-05 | 01 | 1 | LOG-05 | manual (config) | `dotnet build` | N/A | ⬜ pending |
| 02-01-06 | 01 | 1 | LOG-06 | manual (integration) | `dotnet build` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers compilation verification. Test projects do not yet exist (created in Phase 6).

- [ ] Smoke test: run the app, verify console structured log output appears
- [ ] Smoke test: enable File sink in appsettings, verify log file created
- [ ] Smoke test: remove `AddAppLogging()` + project reference, verify clean build (removability)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bootstrap logger captures startup logs | LOG-01 | Test projects not yet created | Run app, verify startup log entries appear before full pipeline swap marker |
| Console sink outputs structured JSON in Development | LOG-02 | Visual verification needed | Run app in Development, verify structured log format in console |
| File sink enables via appsettings | LOG-03 | No test infrastructure | Set `Serilog:Sinks:File:Enabled` to `true`, run app, verify log file created |
| OpenTelemetry sink configurable | LOG-04 | No OTLP endpoint in dev | Verify config section exists and parses without error |
| Seq sink enables via appsettings | LOG-05 | No Seq instance in dev | Verify config section exists and parses without error |
| Zero code changes for sink toggle | LOG-06 | Integration behavior | Toggle sink Enabled flags, rebuild, verify no code changes needed |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
