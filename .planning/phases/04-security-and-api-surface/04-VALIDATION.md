---
phase: 4
slug: security-and-api-surface
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — test project deferred to Phase 6 (TEST-01..07) |
| **Config file** | none — Wave 0 uses build verification only |
| **Quick run command** | `dotnet build` |
| **Full suite command** | `dotnet build && dotnet run` (manual endpoint smoke) |
| **Estimated runtime** | ~15 seconds (build only) |

---

## Sampling Rate

- **After every task commit:** Run `dotnet build`
- **After every plan wave:** Run `dotnet build` + manual endpoint verification via curl/Scalar
- **Before `/gsd:verify-work`:** Full build clean + manual E2E endpoint verification
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-xx | 01 | 1 | AUTH-01 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-01-xx | 01 | 1 | AUTH-02 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-01-xx | 01 | 1 | AUTH-04 | unit | `dotnet build` | ✅ build | ⬜ pending |
| 04-01-xx | 01 | 1 | AUTH-08 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-02-xx | 02 | 1 | AUTH-03 | manual-only | Manual: Google OAuth browser redirect | N/A | ⬜ pending |
| 04-xx-xx | xx | 2 | AUTH-05 | smoke | Build with Identity project removed | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 2 | AUTH-06 | smoke | Build with Google project removed | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 2 | AUTH-07 | smoke | Build with JWT project removed | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | CORS-01 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-xx-xx | xx | 1 | CORS-02 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-xx-xx | xx | 1 | CORS-03 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-xx-xx | xx | 1 | DOCS-01 | integration | `curl /openapi/v1.json` | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | DOCS-02 | integration | `curl /scalar` → 200 | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | DOCS-03 | manual-only | Manual: verify authorize button in browser | N/A | ⬜ pending |
| 04-xx-xx | xx | 1 | DOCS-04 | integration | Check OpenAPI JSON for description fields | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | VERS-01 | integration | `dotnet build` | ✅ build | ⬜ pending |
| 04-xx-xx | xx | 1 | VERS-02 | integration | `curl /api/v1/todos` → 200 | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | VERS-03 | integration | `curl /api/v1/todos && curl /api/v2/todos` | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | VALD-01 | unit | `dotnet build` | ✅ build | ⬜ pending |
| 04-xx-xx | xx | 1 | VALD-02 | integration | `curl -X POST invalid payload` → 400 ProblemDetails | ❌ W0 | ⬜ pending |
| 04-xx-xx | xx | 1 | VALD-03 | unit | `dotnet build` | ✅ build | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] No test project exists — `tests/` contains only `.gitkeep`
- [ ] Testing infrastructure deferred to Phase 6 (TEST-01..07)
- [ ] Phase 4 verification relies on: build compilation + manual endpoint testing (curl/Scalar UI)
- [ ] Smoke tests for auth removability (AUTH-05, AUTH-06, AUTH-07) are manual build-and-verify

*Existing infrastructure covers build verification. Automated test coverage deferred to Phase 6.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Google OAuth login flow | AUTH-03 | Requires Google OAuth credentials and browser redirect | 1. Configure Google client ID/secret in User Secrets 2. Navigate to /api/auth/google 3. Complete Google login 4. Verify JWT returned |
| Scalar JWT authorize button | DOCS-03 | Requires browser interaction with Scalar UI | 1. Open /scalar in browser 2. Click Authorize button 3. Enter valid JWT 4. Execute protected endpoint 5. Verify 200 response |
| Identity layer removal | AUTH-05 | Requires project removal and rebuild | 1. Remove Starter.Auth.Identity project reference 2. Remove AddAppIdentity() call 3. dotnet build 4. Verify no build errors |
| Google OAuth layer removal | AUTH-06 | Requires project removal and rebuild | 1. Remove Starter.Auth.Google project reference 2. Remove AddAppGoogleOAuth() call 3. dotnet build 4. Verify no build errors |
| JWT layer removal | AUTH-07 | Requires project removal and rebuild | 1. Remove Starter.Auth.Jwt project reference 2. Remove AddAppJwtBearer() call 3. dotnet build 4. Verify no build errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
