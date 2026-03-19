---
phase: 5
slug: production-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None detected -- Phase 6 scope |
| **Config file** | None -- Phase 6 will create test infrastructure |
| **Quick run command** | `dotnet build` |
| **Full suite command** | `dotnet build` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dotnet build`
- **After every plan wave:** Run `dotnet build` + manual endpoint verification
- **Before `/gsd:verify-work`:** Full build must succeed; all endpoints manually verified
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | RATE-01 | build | `dotnet build` | N/A | ⬜ pending |
| 05-01-02 | 01 | 1 | RATE-02 | build | `dotnet build` | N/A | ⬜ pending |
| 05-01-03 | 01 | 1 | RATE-03 | build | `dotnet build` | N/A | ⬜ pending |
| 05-01-04 | 01 | 1 | RATE-04 | manual | Visual inspection of controller attributes | N/A | ⬜ pending |
| 05-02-01 | 02 | 1 | CACH-01 | build | `dotnet build` | N/A | ⬜ pending |
| 05-02-02 | 02 | 1 | CACH-02 | manual | Run endpoint twice, observe timing | N/A | ⬜ pending |
| 05-02-03 | 02 | 1 | CACH-03 | manual | Config change verification | N/A | ⬜ pending |
| 05-03-01 | 03 | 1 | COMP-01 | build | `dotnet build` | N/A | ⬜ pending |
| 05-03-02 | 03 | 1 | COMP-02 | manual | Verify Program.cs does not call UseAppCompression | N/A | ⬜ pending |
| 05-03-03 | 03 | 1 | COMP-03 | manual | Review code comments | N/A | ⬜ pending |
| 05-04-01 | 04 | 1 | RESP-01 | build | `dotnet build` | N/A | ⬜ pending |
| 05-04-02 | 04 | 1 | RESP-02 | build | `dotnet build` | N/A | ⬜ pending |
| 05-04-03 | 04 | 1 | RESP-03 | smoke | Remove module, verify build | N/A | ⬜ pending |
| 05-05-01 | 05 | 2 | HLTH-01 | build | `dotnet build` | N/A | ⬜ pending |
| 05-05-02 | 05 | 2 | HLTH-02 | build | `dotnet build` | N/A | ⬜ pending |
| 05-05-03 | 05 | 2 | HLTH-03 | build | `dotnet build` | N/A | ⬜ pending |
| 05-05-04 | 05 | 2 | HLTH-04 | build | `dotnet build` | N/A | ⬜ pending |
| 05-05-05 | 05 | 2 | HLTH-05 | build | `dotnet build` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- No test infrastructure exists (Phase 6 scope)
- Validation for this phase is build success + manual HTTP verification
- All integration test coverage deferred to Phase 6 (TEST-01 through TEST-07)

*Existing build infrastructure covers all phase requirements for automated validation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rate limit 429 response | RATE-04 | No test framework yet | `curl` endpoint exceeding limit, verify 429 status |
| Cache-aside timing | CACH-02 | Requires timed requests | Hit endpoint twice, observe second is faster |
| Redis config swap | CACH-03 | Requires Redis instance | Change appsettings, verify IDistributedCache resolves |
| Compression disabled | COMP-02 | Code inspection | Verify UseAppCompression is commented out in Program.cs |
| HTTPS risks documented | COMP-03 | Documentation review | Verify comments in CompressionExtensions.cs |
| Envelope removability | RESP-03 | Smoke test | Remove Starter.Responses reference, verify build |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
