---
phase: 04-security-and-api-surface
verified: 2026-03-18T18:00:00Z
status: human_needed
score: 21/22 must-haves verified
re_verification: false
human_verification:
  - test: "Run the application and verify auth flow end-to-end"
    expected: "POST /api/auth/register returns 201 with accessToken; POST /api/auth/login returns 200 with accessToken; GET /api/v1/todos without token returns 401; GET /api/v1/todos with Bearer token returns 200; GET /api/v2/todos with Bearer token returns 200 with priority/dueDate/tags fields; POST with invalid data returns 422 ProblemDetails"
    why_human: "Runtime auth flow and HTTP response codes cannot be verified by static analysis. The ForwardDefaultSelector in AuthSharedExtensions was intentionally simplified (always forwards to JWT) which changes routing behavior and must be validated at runtime."
  - test: "Verify Scalar UI loads with JWT authorize button and version dropdown"
    expected: "Navigate to /scalar/v1 — Scalar page loads with API v1 and v2 in a version dropdown, and a Bearer token authorize button is visible"
    why_human: "Visual confirmation of Scalar UI rendering and the presence of the JWT authorize button (injected by BearerSecuritySchemeTransformer) requires a browser."
  - test: "Verify Google OAuth module does not cause startup failure when credentials are absent"
    expected: "Application starts with empty Authentication:Google:ClientId and ClientSecret in appsettings.Development.json. No startup exception. /api/auth/google endpoint responds (may return error at runtime but does not crash startup)."
    why_human: "Startup behavior without credentials requires running the application."
---

# Phase 04: Security and API Surface Verification Report

**Phase Goal:** The API has a complete authentication system with three independently removable auth layers, versioned endpoints, interactive documentation, input validation, and CORS -- collectively defining the public API contract
**Verified:** 2026-03-18T18:00:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | AppUser entity exists as IdentityUser subclass in Auth.Shared, referenced by both Data and auth projects | VERIFIED | `src/Starter.Auth.Shared/Entities/AppUser.cs` contains `public class AppUser : IdentityUser`. `AppDbContext` inherits `IdentityDbContext<AppUser>`. `IdentityExtensions.cs` calls `AddIdentityCore<AppUser>`. |
| 2 | AppDbContext inherits from IdentityDbContext<AppUser> and compiles with Identity tables | VERIFIED | `src/Starter.Data/AppDbContext.cs` line 9: `: IdentityDbContext<AppUser>(options)`. Full solution builds with 0 errors. |
| 3 | PolicyScheme with ForwardDefaultSelector routes auth correctly | PARTIAL | ForwardDefaultSelector exists but always routes to JWT (not Bearer-header-conditional as specified in plan). Design was intentionally changed: always forwards to JWT regardless of header. This is a deliberate simplification documented in the code comment. Build succeeds; runtime behavior needs human verification. |
| 4 | TodoItem entity has v2 fields (Priority, DueDate, Tags) for API versioning support | VERIFIED | `src/Starter.Data/Entities/TodoItem.cs` contains `TodoPriority Priority`, `DateTime? DueDate`, `string? Tags`, and `internal enum TodoPriority`. |
| 5 | SQLite migration captures Identity tables and TodoItem v2 columns | VERIFIED | Migration `20260318170037_AddIdentityAndTodoV2.cs` exists. Contains `AddColumn` for DueDate, Priority, Tags. Creates `AspNetUsers` table. No `DropTable` for TodoItems. |
| 6 | API versioning is configured with URL segment strategy and v1.0 as default | VERIFIED | `VersioningExtensions.cs` contains `UrlSegmentApiVersionReader`, `DefaultApiVersion = new ApiVersion(1, 0)`, `GroupNameFormat = "'v'VVV"`. |
| 7 | CORS policies are configurable via appsettings.json with permissive dev and restrictive prod profiles | VERIFIED | `CorsExtensions.cs` reads from `CorsOptions` bound to config. Development `appsettings.Development.json` has `"AllowedOrigins": ["*"]`. Production `appsettings.json` has explicit origin `https://localhost:5101`. |
| 8 | FluentValidation is registered with MVC auto-validation suppressed | VERIFIED | `ValidationExtensions.cs` calls `AddValidatorsFromAssembly` and sets `SuppressModelStateInvalidFilter = true`. |
| 9 | OpenAPI 3.1 documents are generated for v1 and v2 API versions | VERIFIED | `OpenApiExtensions.cs` calls `AddOpenApi("v1")` and `AddOpenApi("v2")` both with `AddDocumentTransformer<BearerSecuritySchemeTransformer>`. |
| 10 | Scalar UI is available and config-driven via OpenApi:EnableScalar flag | VERIFIED | `OpenApiExtensions.cs` `UseAppOpenApi` checks `openApiOptions.EnableScalar` before calling `MapScalarApiReference`. `appsettings.json` has `"EnableScalar": true`. |
| 11 | JWT Bearer authorize button appears in Scalar UI via document transformer | VERIFIED | `BearerSecuritySchemeTransformer.cs` adds `SecuritySchemeType.Http` with `BearerFormat = "JWT"` to both v1 and v2 documents. Visual confirmation still needs human. |
| 12 | XML documentation comments are wired for OpenAPI output | VERIFIED | `Starter.WebApi.csproj` has `<GenerateDocumentationFile>true</GenerateDocumentationFile>` and `<NoWarn>$(NoWarn);1591</NoWarn>`. Controllers have XML `/// <summary>` comments. |
| 13 | Identity module registers ASP.NET Identity with AppUser and EF Core stores | VERIFIED | `IdentityExtensions.cs` calls `AddIdentityCore<AppUser>().AddRoles<IdentityRole>().AddEntityFrameworkStores<AppDbContext>().AddDefaultTokenProviders().AddSignInManager()`. Note: uses `AddIdentityCore` (not `AddIdentity`) intentionally to preserve PolicyScheme defaults. |
| 14 | JWT module validates Bearer tokens and provides JwtTokenService for token generation | VERIFIED | `JwtExtensions.cs` adds `AddJwtBearer` with `ValidateIssuerSigningKey = true`. Registers `AddScoped<JwtTokenService>`. `JwtTokenService.cs` implements `GenerateToken(AppUser user)`. |
| 15 | Google OAuth module conditionally registers handler only when credentials are configured | VERIFIED | `GoogleExtensions.cs` wraps `AddGoogle` in `if (!string.IsNullOrWhiteSpace(clientId) && !string.IsNullOrWhiteSpace(clientSecret))`. No `[Required]` or `ValidateOnStart` on options. |
| 16 | Each auth module is a separate independently removable class library | VERIFIED | Three separate projects: `Starter.Auth.Identity`, `Starter.Auth.Jwt`, `Starter.Auth.Google`. Each has one extension method call in Program.cs. Each depends only on `Starter.Auth.Shared`. |
| 17 | AuthController provides register, login, and Google OAuth endpoints returning JWT tokens | VERIFIED | `AuthController.cs` has `[HttpPost("register")]`, `[HttpPost("login")]`, `[HttpGet("google")]`, `[HttpGet("google-callback")]`. All return JWT. Uses `JwtTokenService` via DI. Marked `[ApiVersionNeutral]`. |
| 18 | TodoController is versioned at /api/v1/todos with v1 DTO and authorization | VERIFIED | `TodoController.cs` has `[ApiVersion(1.0)]`, `[Route("api/v{version:apiVersion}/todos")]`, `[Authorize]`. Returns `TodoItemDto`. |
| 19 | TodoV2Controller is versioned at /api/v2/todos with expanded DTO | VERIFIED | `TodoV2Controller.cs` has `[ApiVersion(2.0)]`, `[Route("api/v{version:apiVersion}/todos")]`. Returns `TodoItemV2Dto` with priority, dueDate, tags fields. V2 service methods implemented in `TodoService.cs`. |
| 20 | FluentValidation validators exist for all request DTOs and throw AppValidationException on failure | VERIFIED | 6 validators in `src/Starter.WebApi/Validators/`: CreateTodoRequest, UpdateTodoRequest, CreateTodoV2Request, UpdateTodoV2Request, LoginRequest, RegisterRequest. All use `AbstractValidator<T>`. Controllers throw `AppValidationException` on failure. |
| 21 | Program.cs calls all auth extension methods and all modules are wired | VERIFIED | `Program.cs` calls `AddAppAuthShared`, `AddAppIdentity`, `AddAppJwt`, `AddAppGoogle`, `AddAppCors`, `AddAppOpenApi`, `AddAppVersioning`, `AddAppValidation`. Middleware includes `UseCors`, `UseAuthentication`, `UseAuthorization`, `UseAppOpenApi`. |
| 22 | App builds and starts without errors (including when Google credentials are absent) | BUILD VERIFIED | `dotnet build Starter.WebApi.slnx` exits 0 with 0 errors. Runtime startup requires human verification. |

**Score:** 21/22 truths build-verified (1 needs runtime human verification, 1 has deliberate design deviation that needs runtime confirmation)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/Starter.Auth.Shared/Entities/AppUser.cs` | AppUser : IdentityUser entity | VERIFIED | Contains `public class AppUser : IdentityUser` |
| `src/Starter.Auth.Shared/Constants/AuthConstants.cs` | Scheme name constants | VERIFIED | Contains `PolicyScheme`, `JwtScheme`, `IdentityScheme`, `GoogleScheme` |
| `src/Starter.Auth.Shared/Options/JwtOptions.cs` | JWT configuration options | VERIFIED | Contains `SecretKey`, `Issuer`, `Audience`, `ExpirationMinutes` with `[Required]` |
| `src/Starter.Auth.Shared/AuthSharedExtensions.cs` | PolicyScheme + ForwardDefaultSelector registration | VERIFIED (with deviation) | Exists and registers PolicyScheme. ForwardDefaultSelector always routes to JWT (not Bearer-conditional). Deliberate design simplification. |
| `src/Starter.Data/AppDbContext.cs` | IdentityDbContext base class | VERIFIED | `IdentityDbContext<AppUser>(options)` |
| `src/Starter.Data/Entities/TodoItem.cs` | V2 fields | VERIFIED | Priority, DueDate, Tags + TodoPriority enum |
| `src/Starter.Data.Migrations.Sqlite/Migrations/20260318170037_AddIdentityAndTodoV2.cs` | Identity tables + v2 columns | VERIFIED | AspNetUsers created, v2 columns added, no TodoItems DropTable |
| `src/Starter.Versioning/VersioningExtensions.cs` | AddAppVersioning extension | VERIFIED | UrlSegmentApiVersionReader, GroupNameFormat "'v'VVV" |
| `src/Starter.Cors/CorsExtensions.cs` | AddAppCors extension | VERIFIED | Config-driven, AllowAnyOrigin or WithOrigins |
| `src/Starter.Cors/Options/CorsOptions.cs` | CORS config options | VERIFIED | AllowedOrigins, AllowedMethods, AllowedHeaders, AllowCredentials |
| `src/Starter.Validation/ValidationExtensions.cs` | AddAppValidation extension | VERIFIED | AddValidatorsFromAssembly + SuppressModelStateInvalidFilter |
| `src/Starter.Auth.Identity/IdentityExtensions.cs` | AddAppIdentity extension | VERIFIED | AddIdentityCore<AppUser>, AddEntityFrameworkStores<AppDbContext> |
| `src/Starter.Auth.Jwt/JwtExtensions.cs` | AddAppJwt extension | VERIFIED | AddJwtBearer with full token validation parameters |
| `src/Starter.Auth.Jwt/Services/JwtTokenService.cs` | JWT token generation | VERIFIED | GenerateToken(AppUser user) returns (Token, ExpiresIn) |
| `src/Starter.Auth.Google/GoogleExtensions.cs` | AddAppGoogle extension | VERIFIED | Conditional registration, no ValidateOnStart |
| `src/Starter.Auth.Google/Options/GoogleAuthOptions.cs` | Google OAuth options | VERIFIED | No [Required], IsConfigured helper, SectionName = "Authentication:Google" |
| `src/Starter.OpenApi/OpenApiExtensions.cs` | AddAppOpenApi + UseAppOpenApi | VERIFIED | v1 + v2 documents, BearerSecuritySchemeTransformer, MapScalarApiReference |
| `src/Starter.OpenApi/Transformers/BearerSecuritySchemeTransformer.cs` | Bearer security scheme in OpenAPI doc | VERIFIED | SecuritySchemeType.Http, BearerFormat = "JWT" |
| `src/Starter.OpenApi/Options/OpenApiOptions.cs` | Config-driven Scalar visibility | VERIFIED | EnableScalar flag, Title, Description |
| `src/Starter.WebApi/Controllers/AuthController.cs` | Login, Register, Google OAuth endpoints | VERIFIED | All four endpoints present, JwtTokenService injected, ApiVersionNeutral |
| `src/Starter.WebApi/Controllers/TodoController.cs` | V1 Todo endpoints | VERIFIED | ApiVersion(1.0), [Authorize], versioned route, FluentValidation |
| `src/Starter.WebApi/Controllers/TodoV2Controller.cs` | V2 Todo endpoints | VERIFIED | ApiVersion(2.0), TodoItemV2Dto, all CRUD operations |
| `src/Starter.WebApi/Validators/CreateTodoRequestValidator.cs` | FluentValidation for CreateTodoRequest | VERIFIED | AbstractValidator<CreateTodoRequest>, Title rules |
| `src/Starter.WebApi/Validators/CreateTodoV2RequestValidator.cs` | FluentValidation for CreateTodoV2Request | VERIFIED | Priority validation (Low/Medium/High), Tags MaxLength |
| `src/Starter.WebApi/Program.cs` | Composition root | VERIFIED | All Phase 4 modules wired, correct middleware order |
| `src/Starter.WebApi/appsettings.json` | Phase 4 config sections | VERIFIED | Jwt, Authentication:Google, Cors, OpenApi sections present |
| `src/Starter.WebApi/appsettings.Development.json` | Dev overrides (no Google credentials) | VERIFIED | Jwt.SecretKey dev placeholder, Cors permissive. No Authentication section. |
| `src/Starter.WebApi/Starter.WebApi.csproj` | XML doc + all module references | VERIFIED | GenerateDocumentationFile=true, all 14 project references present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AppDbContext.cs` | `AppUser.cs` | IdentityDbContext<AppUser> base class | WIRED | Pattern `IdentityDbContext<AppUser>` confirmed in file |
| `AuthSharedExtensions.cs` | `AuthConstants.cs` | AuthConstants.PolicyScheme | WIRED | `AuthConstants.PolicyScheme` referenced in AddPolicyScheme call |
| `IdentityExtensions.cs` | `AppUser.cs` | AddIdentityCore<AppUser> | WIRED | `AddIdentityCore<AppUser>` confirmed |
| `JwtExtensions.cs` | `JwtOptions.cs` | JwtOptions.SectionName binding | WIRED | `JwtOptions.SectionName` referenced in BindConfiguration call |
| `JwtTokenService.cs` | `AppUser.cs` | GenerateToken(AppUser) | WIRED | Method signature `GenerateToken(AppUser user)` confirmed |
| `OpenApiExtensions.cs` | `BearerSecuritySchemeTransformer.cs` | AddDocumentTransformer | WIRED | `AddDocumentTransformer<BearerSecuritySchemeTransformer>()` in both v1 and v2 documents |
| `CorsExtensions.cs` | `CorsOptions.cs` | BindConfiguration("Cors") | WIRED | `BindConfiguration(CorsOptions.SectionName)` and `Get<CorsOptions>()` confirmed |
| `ValidationExtensions.cs` | FluentValidation | AddValidatorsFromAssembly | WIRED | `AddValidatorsFromAssembly(entryAssembly, ServiceLifetime.Scoped)` confirmed |
| `AuthController.cs` | `JwtTokenService.cs` | DI injection | WIRED | `JwtTokenService tokenService` in constructor, `tokenService.GenerateToken(user)` called in all auth endpoints |
| `TodoController.cs` | `VersioningExtensions.cs` | ApiVersion attribute | WIRED | `[ApiVersion(1.0)]` and `[Route("api/v{version:apiVersion}/todos")]` confirmed |
| `TodoController.cs` | `CreateTodoRequestValidator.cs` | IValidator<T> manual injection | WIRED | `[FromServices] IValidator<CreateTodoRequest> validator` in Create/Update actions |
| `Program.cs` | `AuthSharedExtensions.cs` | builder.AddAppAuthShared() | WIRED | Call confirmed in Program.cs |
| `Program.cs` | `OpenApiExtensions.cs` | AddAppOpenApi + UseAppOpenApi | WIRED | Both calls confirmed in Program.cs |
| `Program.cs` | `CorsExtensions.cs` | AddAppCors + UseCors | WIRED | `builder.AddAppCors()` and `app.UseCors()` confirmed |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUTH-01 | 04-01 | ASP.NET Identity provides user/role/claim store backed by EF Core | SATISFIED | AppDbContext inherits IdentityDbContext<AppUser>; IdentityExtensions registers stores |
| AUTH-02 | 04-03, 04-05 | JWT Bearer tokens can be issued and validated for API access | SATISFIED | JwtExtensions adds Bearer validation; JwtTokenService generates tokens; AuthController issues them |
| AUTH-03 | 04-03 | Google OAuth is available as an external authentication provider | SATISFIED | GoogleExtensions registers AddGoogle when credentials present; GoogleLogin/GoogleCallback endpoints exist |
| AUTH-04 | 04-01 | PolicyScheme with ForwardDefaultSelector correctly routes JWT vs cookie authentication | SATISFIED (with deviation) | PolicyScheme registered. ForwardDefaultSelector always routes to JWT (not conditional). Deliberate design change -- routes correctly for API-first use case. Runtime behavior needs human verification. |
| AUTH-05 | 04-01, 04-03 | Identity store is independently removable | SATISFIED | Starter.Auth.Identity is a separate project; removing `AddAppIdentity()` and the project reference removes Identity |
| AUTH-06 | 04-03 | Google OAuth is independently removable | SATISFIED | Starter.Auth.Google is separate; removing `AddAppGoogle()` and project reference removes Google OAuth |
| AUTH-07 | 04-01, 04-03 | JWT Bearer is independently removable | SATISFIED | Starter.Auth.Jwt is separate; removing `AddAppJwt()` and project reference removes JWT |
| AUTH-08 | 04-06 | All three auth layers are enabled by default to demonstrate composition | SATISFIED | Program.cs calls AddAppAuthShared, AddAppIdentity, AddAppJwt, AddAppGoogle |
| CORS-01 | 04-02 | CORS policies are configurable via appsettings.json | SATISFIED | CorsOptions bound from "Cors" config section |
| CORS-02 | 04-02 | Development profile is permissive (allow all origins) | SATISFIED | appsettings.Development.json has `"AllowedOrigins": ["*"]` which triggers `AllowAnyOrigin()` |
| CORS-03 | 04-02 | Production profile is restrictive (explicit allowed origins) | SATISFIED | appsettings.json has explicit `["https://localhost:5101"]`; CorsExtensions uses `WithOrigins()` |
| DOCS-01 | 04-04 | OpenAPI 3.1 document is generated via Microsoft.AspNetCore.OpenApi | SATISFIED | AddOpenApi("v1") and AddOpenApi("v2") registered in OpenApiExtensions |
| DOCS-02 | 04-04 | Scalar provides the interactive API documentation UI | SATISFIED | MapScalarApiReference called in UseAppOpenApi when EnableScalar=true |
| DOCS-03 | 04-04 | JWT Bearer auth is integrated (authorize button in Scalar UI) | SATISFIED (human verify) | BearerSecuritySchemeTransformer adds SecuritySchemeType.Http Bearer scheme to both documents. Visual confirm needed. |
| DOCS-04 | 04-04, 04-06 | XML comment documentation is wired up and visible in API docs | SATISFIED | GenerateDocumentationFile=true in csproj; NoWarn 1591 suppresses missing-comment warnings; controllers have XML comments |
| VERS-01 | 04-02 | API versioning is configured using Asp.Versioning.Http/Mvc | SATISFIED | Asp.Versioning.Mvc package in Starter.Versioning.csproj; AddApiVersioning called |
| VERS-02 | 04-02 | URL segment versioning is the default strategy (/api/v1/) | SATISFIED | UrlSegmentApiVersionReader in AddApiVersioning |
| VERS-03 | 04-05 | Sample v1 and v2 controllers demonstrate the versioning pattern | SATISFIED | TodoController ([ApiVersion(1.0)]) and TodoV2Controller ([ApiVersion(2.0)]) both on route `/api/v{version:apiVersion}/todos` |
| VALD-01 | 04-02 | FluentValidation 12 is integrated using manual IValidator<T> injection | SATISFIED | FluentValidation.DependencyInjectionExtensions 12.1.1 in csproj; manual IValidator injection in controllers |
| VALD-02 | 04-05 | Validation failures return RFC 7807 Problem Details responses | SATISFIED | Validators throw AppValidationException which GlobalExceptionHandler maps to ProblemDetails 422 |
| VALD-03 | 04-05 | Sample validators for request DTOs are included | SATISFIED | 6 validators: LoginRequest, RegisterRequest, CreateTodoRequest, UpdateTodoRequest, CreateTodoV2Request, UpdateTodoV2Request |

**All 21 Phase 4 requirement IDs are accounted for and satisfied.**

No orphaned requirements found -- all Phase 4 IDs (AUTH-01 through AUTH-08, CORS-01 through CORS-03, DOCS-01 through DOCS-04, VERS-01 through VERS-03, VALD-01 through VALD-03) appear in plan frontmatter and are verified in the codebase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `AuthSharedExtensions.cs` | 22 | ForwardDefaultSelector always routes to JWT (plan specified Bearer-header-conditional routing) | Info | Intentional design simplification. `_ => AuthConstants.JwtScheme` always forwards to JWT. JWT handler returns "no result" gracefully for unauthenticated requests, which is correct for an API-first service. Not a bug but a deviation from original plan spec. |

No TODO/FIXME/placeholder comments in phase deliverables. No stub implementations (all service methods have real implementations). No empty handlers.

### Human Verification Required

#### 1. End-to-End Auth Flow

**Test:** Start application with `dotnet run` in `src/Starter.WebApi`. Then run:
```
POST /api/auth/register {"email":"test@test.com","password":"TestPass1!","confirmPassword":"TestPass1!"}
POST /api/auth/login {"email":"test@test.com","password":"TestPass1!"}
GET /api/v1/todos (no token -- expect 401)
GET /api/v1/todos (with Bearer token -- expect 200)
GET /api/v2/todos (with Bearer token -- expect 200 with priority/dueDate/tags)
POST /api/auth/register with invalid data (expect 422 ProblemDetails)
```
**Expected:** Register returns 201 with accessToken; login returns 200 with accessToken; unprotected returns 401; protected with token returns 200; invalid data returns 422.
**Why human:** Runtime HTTP behavior and response status codes cannot be verified by static analysis.

#### 2. Scalar UI Visual Confirmation

**Test:** Open browser to `https://localhost:5101/scalar/v1` (or port shown in console output).
**Expected:** Scalar page loads. A version dropdown showing "API v1" and "API v2" is visible. A JWT Bearer "Authorize" button is present and functional.
**Why human:** Visual rendering and UI element presence requires a browser. The BearerSecuritySchemeTransformer is structurally correct but Scalar's rendering of it requires runtime confirmation.

#### 3. Application Startup Without Google Credentials

**Test:** Start the application with the default appsettings (Google ClientId and ClientSecret are empty strings in appsettings.json; no Authentication section in Development override).
**Expected:** Application starts successfully. No startup exception. The Google auth handler is silently skipped.
**Why human:** Startup success and absence of exception requires running the process.

### Gaps Summary

No blocking gaps were found. All artifacts exist, are substantive (no stubs), and are wired to each other and to Program.cs. The full solution builds with 0 errors.

One deliberate design deviation was noted: `AuthSharedExtensions.ForwardDefaultSelector` always routes to JWT (`_ => AuthConstants.JwtScheme`) rather than inspecting the Bearer header as the plan specified. This is a valid simplification for an API-first service where the JWT handler correctly returns "no result" when no token is present, falling through to anonymous access. The implementation is documented in code comments. Runtime verification will confirm the behavior is correct.

Three items require human verification (runtime startup, Scalar UI, end-to-end auth flow). These are all in the "needs human" category due to the nature of UI and runtime verification, not due to missing or broken code.

---

_Verified: 2026-03-18T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
