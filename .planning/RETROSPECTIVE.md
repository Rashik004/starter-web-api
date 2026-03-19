# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-19
**Phases:** 6 | **Plans:** 20 | **Sessions:** ~6

### What Was Built
- Modular .NET 10 Web API starter with 19 independently removable feature modules
- Extension method composition pattern: each module is a class library with AddApp*/UseApp* methods
- Full auth stack (Identity + JWT + Google OAuth), EF Core with multi-provider migrations, structured logging
- Production hardening (rate limiting, caching, compression, health checks, response envelope)
- Test suite: 8 unit tests, 19 integration tests, architecture tests, and 19-module removal smoke tests

### What Worked
- Dependency-ordered phase sequencing (scaffold -> observability -> data -> auth -> hardening -> tests) prevented rework
- Wave-based parallel plan execution in phases 5 and 6 saved time on independent modules
- Yolo mode with quality profile gave fast iteration without sacrificing architectural consistency
- Two-stage bootstrap pattern (Serilog) and PolicyScheme (auth) decisions made early paid off through all later phases
- Module isolation enforcement via NetArchTest caught the exact cross-module patterns we needed to verify

### What Was Inefficient
- ROADMAP.md checkboxes for phases 5-6 weren't updated despite completion — caused confusion at milestone close
- Phase 6 plans took 3x longer than average (~17min vs ~5min) due to WebApplicationFactory infrastructure complexity (Serilog freeze, FluentValidation discovery, xUnit parallelism)
- Some summaries lacked one-liner fields, making automated accomplishment extraction fail

### Patterns Established
- `AddApp{Module}(IServiceCollection)` / `UseApp{Module}(WebApplication)` as the universal module API
- Internal by default with InternalsVisibleTo only for tests and known cross-module dependencies
- appsettings.json owns all runtime behavior; code changes are never needed to toggle features
- Module removal test: delete extension call + project reference, build must succeed

### Key Lessons
1. Start with InternalsVisibleTo in test projects from day one — adding it retroactively causes friction
2. WebApplicationFactory test infrastructure needs its own plan; it's not trivial with Serilog + Identity + FluentValidation
3. AddIdentityCore (not AddIdentity) is critical when using PolicyScheme — Identity overrides ForwardDefaultSelector otherwise
4. Parallel executors may pre-commit files that overlap with other plans — verify before assuming work is needed

### Cost Observations
- Model mix: ~80% sonnet (executors), ~20% opus (planning, verification)
- Sessions: ~6 across 2 days
- Notable: 20 plans in ~1.5 hours of execution time; research + planning overhead roughly equal

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~6 | 6 | First milestone — established module pattern and test strategy |

### Cumulative Quality

| Milestone | Tests | Coverage | Removable Modules |
|-----------|-------|----------|-------------------|
| v1.0 | 27 | Core paths | 19 |

### Top Lessons (Verified Across Milestones)

1. Module isolation must be enforced by tests, not just convention — NetArchTest + smoke tests are essential
2. Infrastructure complexity (auth, logging, test host) accounts for most plan overruns; budget accordingly
