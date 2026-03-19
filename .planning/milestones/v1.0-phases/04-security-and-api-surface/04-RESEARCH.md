# Phase 4: Security and API Surface - Research

**Researched:** 2026-03-18
**Domain:** ASP.NET Core Authentication, API Versioning, OpenAPI/Scalar, FluentValidation, CORS
**Confidence:** HIGH

## Summary

Phase 4 is the largest and most complex phase in this project, adding 8 new class library projects (Starter.Auth.Shared, Starter.Auth.Identity, Starter.Auth.Jwt, Starter.Auth.Google, Starter.Cors, Starter.Validation, Starter.Versioning, Starter.OpenApi) and significantly modifying the existing data layer (AppDbContext base class change to IdentityDbContext, TodoItem entity expansion). The phase touches authentication, API versioning, documentation, validation, and CORS -- each a non-trivial domain.

The core technical challenge is the **independently removable auth layers** pattern using ASP.NET Core's PolicyScheme with ForwardDefaultSelector. This requires careful separation of Identity, JWT, and Google OAuth into distinct projects while sharing the AppUser entity and PolicyScheme routing logic through a Starter.Auth.Shared project. The second major challenge is integrating API versioning (Asp.Versioning.Mvc) with the OpenAPI document-per-version pattern (Microsoft.AspNetCore.OpenApi) and Scalar UI's multi-document support.

All packages are verified current on NuGet for .NET 10 (net10.0 / TFM 10.0). The project uses .NET SDK 10.0.101. The established module patterns (AddApp*/UseApp* extension methods, IOptions with ValidateOnStart, internal visibility) are well-understood and will be followed consistently across all 8 new projects.

**Primary recommendation:** Implement in waves -- auth foundation first (Shared + Identity + JWT + Google), then versioning + OpenAPI/Scalar, then CORS + validation. Auth is the riskiest and most interdependent; versioning/OpenAPI have a known .NET 10 pitfall (Bearer scheme must be declared via document transformer for Scalar to work).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Three separate class library projects: `Starter.Auth.Identity`, `Starter.Auth.Jwt`, `Starter.Auth.Google`
- `Starter.Auth.Shared` project holds cross-auth concerns: PolicyScheme configuration, ForwardDefaultSelector logic, auth constants, and the `AppUser` entity
- `AppUser : IdentityUser` lives in `Starter.Auth.Shared/` -- both `Starter.Data` (for DbContext) and auth projects reference it
- `AppDbContext` inherits from `IdentityDbContext<AppUser>` (standard ASP.NET Identity approach)
- `Starter.Data` permanently references `Starter.Auth.Shared` + `Microsoft.AspNetCore.Identity.EntityFrameworkCore` -- removing auth means removing the 3 auth projects + extension calls, but Data keeps its Auth.Shared reference and Identity table schema (harmless)
- Removing an auth layer = delete that project + its extension method call in Program.cs + its project reference
- `Starter.Cors` -- separate class library with `AddAppCors()` extension method
- `Starter.Validation` -- separate class library with `AddAppValidation()` for FluentValidation
- `Starter.Versioning` -- separate class library with `AddAppVersioning()` for API versioning
- `Starter.OpenApi` -- separate class library with `AddAppOpenApi()` / `UseAppOpenApi()` for OpenAPI + Scalar
- Dedicated `AuthController` in the Host project (`Starter.WebApi/Controllers/AuthController.cs`)
- `POST /api/auth/register` returns 201 with `{ userId, email, accessToken, expiresIn }` (auto-login on registration)
- `POST /api/auth/login` returns 200 with `{ accessToken, expiresIn }`
- `GET /api/auth/google` returns 302 redirect to Google, callback returns `{ accessToken, expiresIn }`
- JWT token lifetime: 60 minutes by default, configurable via `Jwt:ExpirationMinutes` in appsettings.json
- JWT SecretKey managed via User Secrets in development (appsettings.json has empty placeholder with comment)
- Authorization: plain `[Authorize]` attribute on protected endpoints -- no roles or policies in the starter
- TodoController moves from `/api/todos` to `/api/v1/todos` (URL segment versioning)
- V2 sample: `TodoV2Controller` at `/api/v2/todos` with expanded DTO adding `priority` (enum), `dueDate` (DateTime?), and `tags` (string?) fields
- V2 expanded fields are added to the `TodoItem` entity in the database (new migration required) -- V1 DTO simply doesn't expose them
- Both v1 and v2 endpoints work simultaneously against the same entity
- Scalar UI visibility is config-driven via `OpenApi:EnableScalar` appsettings flag (not environment check)
- Endpoints grouped by version + controller in Scalar UI (v1 > Todos, v2 > Todos, Auth)
- XML documentation comments demonstrated on sample controllers -- no build-level enforcement
- JWT Bearer auth integrated in Scalar UI (authorize button)

### Claude's Discretion
- Whether auth endpoints (`/api/auth/*`) are versioned or unversioned -- pick what's cleanest
- PolicyScheme behavior when only one auth layer remains (always register PolicyScheme vs simplify to single scheme)
- CORS policy configuration details (which headers, methods, specific origin patterns)
- FluentValidation wiring details (how validators are discovered and registered)
- Exact OpenAPI document configuration (title, description, contact info)
- Middleware ordering for new middleware (CORS, auth, versioning in the pipeline)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-01 | ASP.NET Identity provides user/role/claim store backed by EF Core | IdentityDbContext pattern, AppUser entity in Auth.Shared, Identity service registration |
| AUTH-02 | JWT Bearer tokens can be issued and validated for API access | JwtBearer configuration, SecurityTokenDescriptor for token generation, TokenValidationParameters |
| AUTH-03 | Google OAuth is available as an external authentication provider | Microsoft.AspNetCore.Authentication.Google package, callback-to-JWT flow |
| AUTH-04 | PolicyScheme with ForwardDefaultSelector correctly routes JWT vs cookie authentication | PolicyScheme pattern with ForwardDefaultSelector checking Authorization header |
| AUTH-05 | Identity store is independently removable (API can work with JWT-only) | Auth.Shared holds PolicyScheme; removing Auth.Identity project + extension call works |
| AUTH-06 | Google OAuth is independently removable | Auth.Google is isolated; removing project + extension call works |
| AUTH-07 | JWT Bearer is independently removable (for server-rendered scenarios) | Auth.Jwt is isolated; removing project + extension call falls back to cookie auth |
| AUTH-08 | All three auth layers are enabled by default to demonstrate composition | Default Program.cs calls all three AddAppAuth* extension methods |
| CORS-01 | CORS policies are configurable via appsettings.json | CorsOptions bound from config section with origin/method/header arrays |
| CORS-02 | Development profile is permissive (allow all origins) | appsettings.Development.json overrides with AllowAnyOrigin pattern |
| CORS-03 | Production profile is restrictive (explicit allowed origins) | Base appsettings.json with explicit origins array |
| DOCS-01 | OpenAPI 3.1 document generated via Microsoft.AspNetCore.OpenApi | AddOpenApi with named documents per version |
| DOCS-02 | Scalar provides the interactive API documentation UI | Scalar.AspNetCore MapScalarApiReference with multi-document support |
| DOCS-03 | JWT Bearer auth integrated (authorize button in Scalar UI) | Document transformer adding Bearer SecurityScheme (critical .NET 10 requirement) |
| DOCS-04 | XML comment documentation wired up and visible in API docs | GenerateDocumentationFile in csproj, OpenAPI reads XML comments automatically |
| VERS-01 | API versioning configured using Asp.Versioning.Http/Mvc | AddApiVersioning + AddMvc + AddApiExplorer with GroupNameFormat |
| VERS-02 | URL segment versioning is the default strategy (/api/v1/) | UrlSegmentApiVersionReader, route template `api/v{version:apiVersion}/[controller]` |
| VERS-03 | Sample v1 and v2 controllers demonstrate the versioning pattern | TodoController (v1) and TodoV2Controller (v2) with expanded DTO |
| VALD-01 | FluentValidation 12 integrated using manual IValidator<T> injection | FluentValidation.DependencyInjectionExtensions, AddValidatorsFromAssemblyContaining |
| VALD-02 | Validation failures return RFC 7807 Problem Details | FluentValidation results mapped to AppValidationException -> GlobalExceptionHandler |
| VALD-03 | Sample validators for request DTOs are included | CreateTodoRequestValidator, UpdateTodoRequestValidator examples |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | 10.0.5 | Identity user/role store backed by EF Core | Official Microsoft package for Identity + EF Core integration |
| Microsoft.AspNetCore.Authentication.JwtBearer | 10.0.5 | JWT Bearer token validation middleware | Official Microsoft package, part of ASP.NET Core auth stack |
| Microsoft.AspNetCore.Authentication.Google | 10.0.5 | Google OAuth external authentication | Official Microsoft OAuth provider package |
| Microsoft.AspNetCore.OpenApi | 10.0.5 | OpenAPI 3.1 document generation | Built-in .NET 10 OpenAPI support, replaces Swashbuckle |
| Scalar.AspNetCore | 2.13.11 | Interactive API documentation UI | Recommended Swagger UI replacement for .NET 9+/10 |
| Asp.Versioning.Mvc | 8.1.1 | API versioning for MVC controllers | Official dotnet-foundation API versioning library |
| Asp.Versioning.Mvc.ApiExplorer | 8.1.1 | API explorer integration for versioned endpoints | Bridges versioning with OpenAPI document generation |
| FluentValidation.DependencyInjectionExtensions | 12.1.1 | DI registration for FluentValidation validators | Standard FV package for ASP.NET Core DI integration |
| System.IdentityModel.Tokens.Jwt | (framework) | JWT token creation and signing | Part of .NET runtime, used for SecurityTokenDescriptor |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | 10.0.5 | On Starter.Data project | Needed for IdentityDbContext<AppUser> base class |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Scalar.AspNetCore | Swashbuckle | Swashbuckle is deprecated/unmaintained for .NET 9+; Scalar is the modern replacement |
| Manual IValidator<T> injection | FluentValidation.AspNetCore auto-pipeline | Auto-pipeline is deprecated in FV 12; manual injection is the only supported approach |
| PolicyScheme ForwardDefaultSelector | Multiple [Authorize(Schemes=...)] attributes | PolicyScheme is transparent to controllers; scheme attributes couples controllers to auth config |
| Asp.Versioning.Mvc | Manual route-based versioning | Asp.Versioning provides ApiExplorer integration, deprecation headers, version negotiation |

**Installation (per project):**

Starter.Auth.Shared:
```bash
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore --version 10.0.5
```

Starter.Auth.Jwt:
```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer --version 10.0.5
```

Starter.Auth.Google:
```bash
dotnet add package Microsoft.AspNetCore.Authentication.Google --version 10.0.5
```

Starter.OpenApi:
```bash
dotnet add package Microsoft.AspNetCore.OpenApi --version 10.0.5
dotnet add package Scalar.AspNetCore --version 2.13.11
```

Starter.Versioning:
```bash
dotnet add package Asp.Versioning.Mvc --version 8.1.1
dotnet add package Asp.Versioning.Mvc.ApiExplorer --version 8.1.1
```

Starter.Validation:
```bash
dotnet add package FluentValidation.DependencyInjectionExtensions --version 12.1.1
```

Starter.Data (additional):
```bash
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore --version 10.0.5
```

**Version verification:** All versions confirmed via `dotnet package search` on 2026-03-18 against nuget.org.

## Architecture Patterns

### Recommended Project Structure
```
src/
  Starter.Auth.Shared/         # AppUser entity, auth constants, PolicyScheme config, ForwardDefaultSelector
    Entities/
      AppUser.cs               # AppUser : IdentityUser
    Constants/
      AuthConstants.cs         # Scheme names, policy names
    Options/
      JwtOptions.cs            # JWT configuration (SecretKey, Issuer, Audience, ExpirationMinutes)
    AuthSharedExtensions.cs    # AddAppAuthShared() - registers PolicyScheme + ForwardDefaultSelector
  Starter.Auth.Identity/       # ASP.NET Identity registration
    IdentityExtensions.cs      # AddAppIdentity() - registers Identity<AppUser> with stores
  Starter.Auth.Jwt/            # JWT Bearer validation + token generation
    Services/
      JwtTokenService.cs       # Generates JWT tokens (internal, injected into AuthController)
    JwtExtensions.cs           # AddAppJwt() - registers JwtBearer handler + JwtTokenService
  Starter.Auth.Google/         # Google OAuth external provider
    GoogleExtensions.cs        # AddAppGoogle() - registers Google OAuth handler
  Starter.Cors/                # CORS configuration
    Options/
      CorsOptions.cs           # AllowedOrigins, AllowedMethods, AllowedHeaders arrays
    CorsExtensions.cs          # AddAppCors() - registers CORS from config
  Starter.Validation/          # FluentValidation integration
    ValidationExtensions.cs    # AddAppValidation() - registers validators from assemblies
  Starter.Versioning/          # API versioning
    VersioningExtensions.cs    # AddAppVersioning() - registers Asp.Versioning
  Starter.OpenApi/             # OpenAPI + Scalar
    Transformers/
      BearerSecuritySchemeTransformer.cs  # Adds JWT Bearer scheme to OpenAPI doc
    Options/
      OpenApiOptions.cs        # EnableScalar flag, document title/description
    OpenApiExtensions.cs       # AddAppOpenApi() / UseAppOpenApi()
  Starter.WebApi/
    Controllers/
      AuthController.cs        # Login, Register, Google auth endpoints
      TodoController.cs        # V1 - updated route to /api/v{version:apiVersion}/todos
      TodoV2Controller.cs      # V2 - expanded DTO with priority, dueDate, tags
```

### Pattern 1: PolicyScheme with ForwardDefaultSelector
**What:** A meta-scheme that inspects each request and forwards to the correct underlying auth handler (JWT Bearer vs Identity cookies).
**When to use:** When multiple authentication mechanisms coexist and you want `[Authorize]` to work transparently without specifying schemes on every controller.
**Example:**
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/security/authentication/policyschemes
public static class AuthSharedExtensions
{
    public static WebApplicationBuilder AddAppAuthShared(this WebApplicationBuilder builder)
    {
        builder.Services.AddAuthentication(options =>
        {
            options.DefaultScheme = AuthConstants.PolicyScheme;
            options.DefaultChallengeScheme = AuthConstants.PolicyScheme;
        })
        .AddPolicyScheme(AuthConstants.PolicyScheme, displayName: null, options =>
        {
            options.ForwardDefaultSelector = context =>
            {
                string? authorization = context.Request.Headers.Authorization;
                if (!string.IsNullOrEmpty(authorization) &&
                    authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                {
                    return JwtBearerDefaults.AuthenticationScheme;
                }
                return IdentityConstants.ApplicationScheme;
            };
        });

        return builder;
    }
}
```

### Pattern 2: OpenAPI Document Transformer for Bearer Security Scheme
**What:** A document transformer that adds the JWT Bearer security scheme declaration to the OpenAPI document so Scalar can display the authorize button.
**When to use:** Always in .NET 10 -- without this, Scalar ignores Bearer tokens because the OpenAPI spec has no security scheme declared.
**Example:**
```csharp
// Source: https://startdebugging.net/2026/01/scalar-in-asp-net-core-why-your-bearer-token-is-ignored-net-10/
options.AddDocumentTransformer((document, context, ct) =>
{
    document.Components ??= new OpenApiComponents();
    document.Components.SecuritySchemes ??= new Dictionary<string, OpenApiSecurityScheme>();

    document.Components.SecuritySchemes["Bearer"] = new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    };

    document.SecurityRequirements ??= new List<OpenApiSecurityRequirement>();
    document.SecurityRequirements.Add(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme { Reference = new OpenApiReference
            { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }] = Array.Empty<string>()
    });

    return ValueTask.CompletedTask;
});
```

### Pattern 3: URL Segment Versioning with Asp.Versioning
**What:** Controllers declare their API version via `[ApiVersion]` attribute and use `{version:apiVersion}` in route templates.
**When to use:** All versioned controllers.
**Example:**
```csharp
// Source: https://github.com/dotnet/aspnet-api-versioning/wiki/Versioning-via-the-URL-Path
[ApiVersion(1.0)]
[ApiController]
[Route("api/v{version:apiVersion}/todos")]
public class TodoController : ControllerBase { }

[ApiVersion(2.0)]
[ApiController]
[Route("api/v{version:apiVersion}/todos")]
public class TodoV2Controller : ControllerBase { }
```

### Pattern 4: FluentValidation Manual Injection
**What:** Validators registered via DI, injected as IValidator<T>, invoked manually in controllers/services.
**When to use:** All request validation in Phase 4 (FluentValidation.AspNetCore auto-pipeline is deprecated in v12).
**Example:**
```csharp
// Source: https://docs.fluentvalidation.net/en/latest/aspnet.html
public class TodoController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create(
        CreateTodoRequest request,
        [FromServices] IValidator<CreateTodoRequest> validator,
        CancellationToken ct)
    {
        var result = await validator.ValidateAsync(request, ct);
        if (!result.IsValid)
        {
            var errors = result.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
            throw new AppValidationException(errors);
        }
        // proceed with service call
    }
}
```

### Pattern 5: Multi-Version OpenAPI with Scalar
**What:** Register separate OpenAPI documents per API version, configure Scalar to show a version dropdown.
**When to use:** When API versioning is combined with Scalar documentation.
**Example:**
```csharp
// Source: https://dotnetmastery.com/Blog/Details?slug=scalar-api-documentation-multi-version-dotnet10
builder.Services.AddOpenApi("v1", options => { /* transformers */ });
builder.Services.AddOpenApi("v2", options => { /* transformers */ });

// In middleware:
app.MapOpenApi();
app.MapScalarApiReference(options =>
{
    options.Title = "Starter API";
    options
        .AddDocument("v1", "API v1", "/openapi/v1.json", isDefault: true)
        .AddDocument("v2", "API v2", "/openapi/v2.json");
});
```

### Anti-Patterns to Avoid
- **Hardcoding auth scheme names in controllers:** Use `[Authorize]` without scheme specification; let PolicyScheme route to the correct handler. Hardcoding couples controllers to auth configuration.
- **Using FluentValidation.AspNetCore auto-pipeline:** Deprecated in v12. Use manual `IValidator<T>` injection instead.
- **Relying on environment checks for Scalar visibility:** Use config-driven `OpenApi:EnableScalar` flag per CONTEXT.md decision.
- **Putting JWT secret in appsettings.json:** Use User Secrets in development. The appsettings placeholder should be empty with a comment pointing to User Secrets docs.
- **Building separate token generation logic per auth provider:** Google OAuth callback should use the same JwtTokenService as login/register to generate the JWT response token.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT token validation | Custom middleware parsing Authorization header | `AddJwtBearer()` with TokenValidationParameters | Handles signature verification, expiry, audience, issuer, clock skew |
| User/password storage | Custom hashing, salt, user tables | `AddIdentity<AppUser>()` with IdentityDbContext | Password hashing (PBKDF2), lockout, email confirmation, secure by default |
| OAuth state management | Custom state parameter, CSRF protection | `AddGoogle()` authentication handler | Handles OAuth2 state parameter, code exchange, CSRF protection |
| API version routing | Custom route constraints or middleware | `AddApiVersioning()` with UrlSegmentApiVersionReader | Handles version negotiation, deprecation headers, ApiExplorer integration |
| OpenAPI document generation | Custom JSON/YAML document builders | `AddOpenApi()` with document transformers | Schema inference from types, XML doc integration, .NET 10 native support |
| CORS preflight handling | Custom OPTIONS endpoint handling | `AddCors()` / `UseCors()` middleware | Handles preflight, vary headers, credential negotiation per spec |
| Validation pipeline | Custom action filters with reflection | FluentValidation `IValidator<T>` + manual invocation | Type-safe rules, async validation, test-friendly, well-documented |

**Key insight:** Each of these domains has subtle edge cases (JWT clock skew, CORS preflight caching, Identity password hashing iterations) that standard libraries handle correctly and custom code invariably gets wrong.

## Common Pitfalls

### Pitfall 1: Scalar Bearer Token Ignored in .NET 10
**What goes wrong:** Scalar UI shows an authorize button but never sends the Bearer token with requests, or doesn't show the authorize button at all.
**Why it happens:** In .NET 10, `Microsoft.AspNetCore.OpenApi` does not automatically add security scheme declarations to the generated OpenAPI document. Scalar relies on the OpenAPI spec (not middleware) to determine how to send auth tokens.
**How to avoid:** Add a document transformer that declares the Bearer security scheme in the OpenAPI document's `components.securitySchemes` and adds it to `securityRequirements`. This must be done for every `AddOpenApi()` call (both v1 and v2 documents).
**Warning signs:** OpenAPI JSON at `/openapi/v1.json` lacks a `securitySchemes` section.

### Pitfall 2: ForwardDefaultSelector Null Return
**What goes wrong:** When no auth header is present and Identity is removed (JWT-only mode), ForwardDefaultSelector returns a scheme name that doesn't exist, causing a runtime exception.
**Why it happens:** The selector always returns `IdentityConstants.ApplicationScheme` as fallback, but that scheme isn't registered when Identity is removed.
**How to avoid:** The ForwardDefaultSelector should check which schemes are actually registered. When only JWT is available, default to JwtBearerDefaults.AuthenticationScheme. The simplest approach: always return JwtBearerDefaults.AuthenticationScheme when no Authorization header is present AND Identity scheme is not registered. Use `IAuthenticationSchemeProvider` to check registered schemes at startup, or configure the fallback via options.
**Warning signs:** `InvalidOperationException: No authentication handler is registered for the scheme 'Identity.Application'`.

### Pitfall 3: IdentityDbContext Migration Breaking Existing Schema
**What goes wrong:** Changing AppDbContext base class from `DbContext` to `IdentityDbContext<AppUser>` generates a migration that tries to recreate existing tables or fails on migration ordering.
**Why it happens:** EF Core sees the base class change and the new Identity tables as a massive schema diff.
**How to avoid:** Create a clean migration specifically for the Identity tables. The migration should only ADD the Identity tables (AspNetUsers, AspNetRoles, AspNetUserClaims, etc.) and the new TodoItem columns. Keep the migration in the existing migration assembly pattern.
**Warning signs:** Migration diff shows `DropTable` for existing tables.

### Pitfall 4: API Versioning GroupName Mismatch with OpenAPI Document Names
**What goes wrong:** Versioned controllers don't appear in the correct OpenAPI document, or endpoints appear in all documents.
**Why it happens:** The `GroupNameFormat` in Asp.Versioning's ApiExplorer doesn't match the document names passed to `AddOpenApi()`. For example, GroupNameFormat `"'v'VVV"` produces `"v1"` but `AddOpenApi("V1")` expects `"V1"`.
**How to avoid:** Ensure exact string match between GroupNameFormat output and AddOpenApi document names. Use `"'v'VVV"` format producing `"v1"`, `"v2"` and register `AddOpenApi("v1")`, `AddOpenApi("v2")`.
**Warning signs:** `/openapi/v1.json` shows all endpoints or no endpoints.

### Pitfall 5: Middleware Ordering with CORS and Auth
**What goes wrong:** CORS preflight requests fail, or auth middleware runs before CORS, causing 401s on OPTIONS requests.
**Why it happens:** CORS must run after routing but before authentication/authorization to handle preflight requests before auth checks.
**How to avoid:** Follow the canonical ordering: ExceptionHandler -> HttpsRedirection -> RequestLogging -> CORS -> Authentication -> Authorization -> MapControllers. In .NET 10, UseRouting is implicit with MapControllers.
**Warning signs:** Browser console shows CORS errors on preflight (OPTIONS) requests to protected endpoints.

### Pitfall 6: FluentValidation Duplicate Validation with DataAnnotations
**What goes wrong:** Validation runs twice -- once via DataAnnotations (model binding) and once via FluentValidation, producing duplicate or inconsistent error messages.
**Why it happens:** ASP.NET Core MVC validates DataAnnotations automatically during model binding. The existing `CreateTodoRequest` and `UpdateTodoRequest` use `[Required]` and `[StringLength]` attributes.
**How to avoid:** When adding FluentValidation validators, either (a) remove DataAnnotations from the request models and rely solely on FluentValidation, or (b) disable automatic model validation via `services.Configure<ApiBehaviorOptions>(o => o.SuppressModelStateInvalidFilter = true)` and handle all validation through FluentValidation.
**Warning signs:** Error responses contain both DataAnnotation and FluentValidation error messages for the same field.

### Pitfall 7: XML Documentation Build Warnings
**What goes wrong:** Enabling `<GenerateDocumentationFile>true</GenerateDocumentationFile>` produces CS1591 warnings for every public member without XML comments.
**Why it happens:** The compiler generates warnings for undocumented public APIs when XML doc generation is enabled.
**How to avoid:** Per CONTEXT.md decision, XML docs are demonstrated but not enforced. Add `<NoWarn>$(NoWarn);1591</NoWarn>` to the property group alongside `<GenerateDocumentationFile>true</GenerateDocumentationFile>` in projects that enable it.
**Warning signs:** Hundreds of CS1591 warnings in build output.

## Code Examples

### JWT Token Generation Service
```csharp
// Verified pattern from Microsoft docs + community best practices
internal sealed class JwtTokenService(IOptions<JwtOptions> jwtOptions)
{
    public (string Token, int ExpiresIn) GenerateToken(AppUser user)
    {
        var options = jwtOptions.Value;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.SecretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expiresMinutes = options.ExpirationMinutes;

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id),
            new Claim(JwtRegisteredClaimNames.Email, user.Email!),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: options.Issuer,
            audience: options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiresMinutes),
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresMinutes * 60);
    }
}
```

### AuthController Login Endpoint
```csharp
// Source: Verified pattern from Microsoft Identity + JWT docs
[ApiController]
[Route("api/auth")]
public class AuthController(
    UserManager<AppUser> userManager,
    SignInManager<AppUser> signInManager,
    JwtTokenService tokenService) : ControllerBase
{
    /// <summary>
    /// Authenticates a user and returns a JWT access token.
    /// </summary>
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(request.Email);
        if (user is null)
            return Unauthorized(new ProblemDetails { Title = "Invalid credentials" });

        var result = await signInManager.CheckPasswordSignInAsync(user, request.Password, lockoutOnFailure: true);
        if (!result.Succeeded)
            return Unauthorized(new ProblemDetails { Title = "Invalid credentials" });

        var (token, expiresIn) = tokenService.GenerateToken(user);
        return Ok(new { accessToken = token, expiresIn });
    }
}
```

### CORS Configuration from appsettings.json
```csharp
// Verified pattern from Microsoft CORS docs
internal sealed class CorsOptions
{
    public const string SectionName = "Cors";
    public string[] AllowedOrigins { get; set; } = [];
    public string[] AllowedMethods { get; set; } = ["GET", "POST", "PUT", "DELETE", "OPTIONS"];
    public string[] AllowedHeaders { get; set; } = ["Content-Type", "Authorization"];
    public bool AllowCredentials { get; set; }
}

public static class CorsExtensions
{
    public static WebApplicationBuilder AddAppCors(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<CorsOptions>()
            .BindConfiguration(CorsOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var corsOptions = builder.Configuration
            .GetSection(CorsOptions.SectionName)
            .Get<CorsOptions>()!;

        builder.Services.AddCors(options =>
        {
            options.AddDefaultPolicy(policy =>
            {
                if (corsOptions.AllowedOrigins.Contains("*"))
                    policy.AllowAnyOrigin();
                else
                    policy.WithOrigins(corsOptions.AllowedOrigins);

                policy.WithMethods(corsOptions.AllowedMethods);
                policy.WithHeaders(corsOptions.AllowedHeaders);

                if (corsOptions.AllowCredentials && !corsOptions.AllowedOrigins.Contains("*"))
                    policy.AllowCredentials();
            });
        });

        return builder;
    }
}
```

### Versioning Registration
```csharp
// Source: https://github.com/dotnet/aspnet-api-versioning
public static class VersioningExtensions
{
    public static IServiceCollection AddAppVersioning(this IServiceCollection services)
    {
        services.AddApiVersioning(options =>
        {
            options.DefaultApiVersion = new ApiVersion(1, 0);
            options.AssumeDefaultVersionWhenUnspecified = false;
            options.ReportApiVersions = true;
            options.ApiVersionReader = new UrlSegmentApiVersionReader();
        })
        .AddMvc()
        .AddApiExplorer(options =>
        {
            options.GroupNameFormat = "'v'VVV";
            options.SubstituteApiVersionInUrl = true;
        });

        return services;
    }
}
```

### FluentValidation Integration
```csharp
// Source: https://docs.fluentvalidation.net/en/latest/di.html
public static class ValidationExtensions
{
    public static IServiceCollection AddAppValidation(this IServiceCollection services)
    {
        // Scan host assembly for validators (controllers/models live there)
        services.AddValidatorsFromAssemblyContaining<Program>(ServiceLifetime.Scoped);

        // Suppress MVC auto-validation so FluentValidation is the single source
        services.Configure<ApiBehaviorOptions>(options =>
            options.SuppressModelStateInvalidFilter = true);

        return services;
    }
}
```

### Updated Program.cs Middleware Order
```csharp
// Canonical middleware ordering for Phase 4
var app = builder.Build();

app.UseAppExceptionHandling();    // Must be first
app.UseHttpsRedirection();
app.UseAppRequestLogging();       // After exception handler and HTTPS redirect
app.UseAppData();                 // Auto-migrate if configured

app.UseCors();                    // After routing (implicit), before auth
app.UseAuthentication();
app.UseAuthorization();

app.UseAppOpenApi();              // MapOpenApi + MapScalarApiReference

app.MapControllers();

app.Run();
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Swashbuckle.AspNetCore | Microsoft.AspNetCore.OpenApi + Scalar.AspNetCore | .NET 9 (2024) | Swashbuckle unmaintained; built-in OpenAPI is standard |
| FluentValidation.AspNetCore auto-pipeline | Manual IValidator<T> injection | FluentValidation 12 (2024) | Auto-pipeline deprecated; manual is only supported path |
| Microsoft.AspNetCore.Mvc.Versioning | Asp.Versioning.Mvc (8.x) | 2023 | Old package is deprecated; Asp.Versioning is the successor |
| AddEndpointsApiExplorer() | AddOpenApi() | .NET 9 (2024) | AddEndpointsApiExplorer no longer needed with built-in OpenAPI |
| OpenAPI 3.0 | OpenAPI 3.1 | .NET 10 (2025) | Default version in Microsoft.AspNetCore.OpenApi 10.x |

**Deprecated/outdated:**
- `Swashbuckle.AspNetCore`: Unmaintained since late 2023, removed from .NET 9+ templates
- `FluentValidation.AspNetCore` (auto-pipeline): Deprecated in v11, removed in v12
- `Microsoft.AspNetCore.Mvc.Versioning`: Deprecated, replaced by `Asp.Versioning.Mvc`
- `AddEndpointsApiExplorer()`: No longer needed with built-in `AddOpenApi()` in .NET 9+

## Open Questions

1. **Asp.Versioning.Mvc OpenAPI Integration in .NET 10**
   - What we know: Asp.Versioning 8.1.1 provides `.AddApiExplorer()` with GroupNameFormat that sets GroupName on ApiDescriptions. Microsoft.AspNetCore.OpenApi uses GroupName to route endpoints to named documents.
   - What's unclear: Whether the `.AddOpenApi()` extension from Asp.Versioning integrates seamlessly with Microsoft.AspNetCore.OpenApi in .NET 10, or if manual `AddOpenApi("v1")` / `AddOpenApi("v2")` registration is required.
   - Recommendation: Use the manual approach (explicit `AddOpenApi("v1")` and `AddOpenApi("v2")` calls) which is verified to work. The GroupName-based routing is well-documented in official Microsoft docs.

2. **ForwardDefaultSelector Resilience When Schemes Are Missing**
   - What we know: PolicyScheme's ForwardDefaultSelector must return a valid scheme name. When Identity is removed, `IdentityConstants.ApplicationScheme` won't be registered.
   - What's unclear: Whether the selector is invoked for every request or only when auth is triggered by `[Authorize]`. If it's only on auth trigger, returning a missing scheme name for unauthenticated requests would never cause an error.
   - Recommendation: Build the selector defensively -- detect available schemes at service registration time and configure the fallback accordingly. Keep it simple: if `Authorization: Bearer` header exists, forward to JWT; otherwise forward to Identity if registered, or JWT as fallback.

3. **Auth Endpoint Versioning**
   - What we know: CONTEXT.md gives Claude discretion on whether auth endpoints are versioned.
   - Recommendation: Auth endpoints should be **unversioned** at `/api/auth/*`. Auth is infrastructure, not a business API -- it doesn't evolve with the same versioning cadence as domain controllers. The AuthController should use `[ApiVersionNeutral]` attribute to exclude it from versioning constraints.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None currently configured (tests/ directory exists with .gitkeep only) |
| Config file | none -- see Wave 0 |
| Quick run command | `dotnet test --filter "Category=Unit"` (once configured) |
| Full suite command | `dotnet test` (once configured) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Identity user store backed by EF Core | integration | `dotnet test --filter "FullyQualifiedName~Auth.Identity"` | No -- Wave 0 |
| AUTH-02 | JWT Bearer token issuance and validation | integration | `dotnet test --filter "FullyQualifiedName~Auth.Jwt"` | No -- Wave 0 |
| AUTH-03 | Google OAuth availability | manual-only | Manual: requires Google OAuth credentials and browser redirect | N/A |
| AUTH-04 | PolicyScheme ForwardDefaultSelector routing | unit | `dotnet test --filter "FullyQualifiedName~Auth.PolicyScheme"` | No -- Wave 0 |
| AUTH-05 | Identity independently removable | smoke | Build with Identity project removed | No -- Wave 0 |
| AUTH-06 | Google OAuth independently removable | smoke | Build with Google project removed | No -- Wave 0 |
| AUTH-07 | JWT Bearer independently removable | smoke | Build with JWT project removed | No -- Wave 0 |
| AUTH-08 | All three auth layers enabled by default | integration | Run app with default config, verify all schemes registered | No -- Wave 0 |
| CORS-01 | CORS configurable via appsettings | integration | `dotnet test --filter "FullyQualifiedName~Cors"` | No -- Wave 0 |
| CORS-02 | Dev profile permissive | integration | Verify AllowAnyOrigin in Development config | No -- Wave 0 |
| CORS-03 | Production profile restrictive | integration | Verify explicit origins in Production config | No -- Wave 0 |
| DOCS-01 | OpenAPI 3.1 document generation | integration | GET /openapi/v1.json returns valid OpenAPI 3.1 | No -- Wave 0 |
| DOCS-02 | Scalar UI available | integration | GET /scalar returns 200 | No -- Wave 0 |
| DOCS-03 | JWT Bearer auth in Scalar | manual-only | Manual: verify authorize button in browser | N/A |
| DOCS-04 | XML comments visible in API docs | integration | Check OpenAPI JSON for description fields | No -- Wave 0 |
| VERS-01 | API versioning configured | integration | `dotnet test --filter "FullyQualifiedName~Versioning"` | No -- Wave 0 |
| VERS-02 | URL segment versioning | integration | GET /api/v1/todos returns 200 | No -- Wave 0 |
| VERS-03 | V1 and V2 controllers working | integration | Both /api/v1/todos and /api/v2/todos return 200 | No -- Wave 0 |
| VALD-01 | FluentValidation integrated | unit | `dotnet test --filter "FullyQualifiedName~Validation"` | No -- Wave 0 |
| VALD-02 | Validation returns ProblemDetails | integration | POST invalid payload, verify RFC 7807 response | No -- Wave 0 |
| VALD-03 | Sample validators included | unit | Validator tests with valid/invalid inputs | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `dotnet build` (build verification -- no test project yet)
- **Per wave merge:** `dotnet build && dotnet run` (manual smoke test)
- **Phase gate:** Full build clean + manual endpoint verification before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] No test project exists -- `tests/` contains only `.gitkeep`
- [ ] Test infrastructure deferred to Phase 6 (TEST-01 through TEST-07)
- [ ] Phase 4 verification will rely on build success + manual endpoint testing (curl/Scalar UI)
- [ ] Framework install: `dotnet new xunit -n Starter.Tests.Integration -o tests/Starter.Tests.Integration` -- Phase 6

*(Testing infrastructure is explicitly deferred to Phase 6 per roadmap. Phase 4 verification uses build compilation + manual E2E endpoint verification.)*

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn - Policy schemes in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/policyschemes?view=aspnetcore-10.0) - ForwardDefaultSelector pattern, PolicyScheme configuration
- [Microsoft Learn - Configure JWT Bearer authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication?view=aspnetcore-10.0) - JWT Bearer setup, TokenValidationParameters, best practices
- [Microsoft Learn - Generate OpenAPI documents](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/aspnetcore-openapi?view=aspnetcore-10.0) - AddOpenApi, document transformers, multiple documents, .NET 10 OpenAPI 3.1
- [Microsoft Learn - Enable CORS in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/cors?view=aspnetcore-10.0) - CORS middleware ordering, policy configuration
- [FluentValidation docs - ASP.NET Core](https://docs.fluentvalidation.net/en/latest/aspnet.html) - Manual validation approach, deprecation of auto-pipeline
- [FluentValidation docs - Dependency Injection](https://docs.fluentvalidation.net/en/latest/di.html) - AddValidatorsFromAssemblyContaining, ServiceLifetime options
- [Asp.Versioning Wiki - URL Path Versioning](https://github.com/dotnet/aspnet-api-versioning/wiki/Versioning-via-the-URL-Path) - Route templates, ApiVersion attribute, version constraint
- [Asp.Versioning Wiki - API Explorer Options](https://github.com/dotnet/aspnet-api-versioning/wiki/API-Explorer-Options) - GroupNameFormat, SubstituteApiVersionInUrl
- NuGet package search (2026-03-18) - All package versions verified against nuget.org registry

### Secondary (MEDIUM confidence)
- [Start Debugging - Scalar Bearer Token Issue in .NET 10](https://startdebugging.net/2026/01/scalar-in-asp-net-core-why-your-bearer-token-is-ignored-net-10/) - Bearer SecurityScheme document transformer fix
- [DotnetMastery - Scalar Multi-Version Support in .NET 10](https://dotnetmastery.com/Blog/Details?slug=scalar-api-documentation-multi-version-dotnet10) - MapScalarApiReference with AddDocument for multiple versions
- [GitHub Discussion #57780 - AddOpenApi with API versioning](https://github.com/dotnet/aspnetcore/discussions/57780) - Manual AddOpenApi per version approach
- [Microsoft Learn - ASP.NET Core Middleware ordering](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-10.0) - Canonical middleware pipeline order

### Tertiary (LOW confidence)
- None -- all findings verified with primary or secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages verified on nuget.org, versions confirmed for .NET 10 compatibility
- Architecture: HIGH - Patterns derived from official Microsoft docs and established project conventions
- Auth (PolicyScheme/ForwardDefaultSelector): HIGH - Verified against Microsoft Learn docs for ASP.NET Core 10.0
- OpenAPI/Scalar: MEDIUM-HIGH - Bearer transformer pattern verified via blog + official docs, multi-version pattern from community source
- Versioning: HIGH - Asp.Versioning wiki provides definitive guidance
- FluentValidation: HIGH - Official docs explicitly document manual injection as the supported approach
- Pitfalls: HIGH - Each pitfall verified against docs or reported issues
- Middleware ordering: HIGH - Microsoft Learn canonical ordering docs

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (30 days -- stable ecosystem, all packages at production releases)
