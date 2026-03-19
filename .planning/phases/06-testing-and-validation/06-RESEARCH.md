# Phase 6: Testing and Validation - Research

**Researched:** 2026-03-19
**Domain:** .NET 10 testing (xUnit, WebApplicationFactory, Moq, FluentAssertions, NetArchTest, module removal)
**Confidence:** HIGH

## Summary

Phase 6 adds three test projects that validate the modular architecture's core value proposition: any module can be removed without breaking the build. The test stack is xUnit v2 (stable, class-library model), FluentAssertions 7.2.0 (Apache 2.0 free license -- NOT v8 which requires commercial license), Moq 4.20.72, and NetArchTest.Rules 1.3.2. Integration tests use `WebApplicationFactory<Program>` with SQLite in-memory databases (one unique connection per test class for isolation) and a fake authentication handler for most tests, with a real JWT round-trip for auth flow tests (TEST-03).

The module removal smoke tests are the most architecturally significant tests. They must programmatically verify that commenting out each `AddApp*`/`UseApp*` call and its corresponding project reference results in a successful `dotnet build`. Since modifying Program.cs and csproj files at test time is fragile, the recommended approach is a shell script (or PowerShell) that iterates through module definitions, patches the files, runs `dotnet build`, and restores -- invoked from a test or CI step.

**Primary recommendation:** Use xUnit v2 (2.9.3) for stability with the class-library test project model required by `Microsoft.AspNetCore.Mvc.Testing`. Use FluentAssertions 7.2.0 (NOT 8.x) to avoid commercial licensing. Implement module removal smoke tests as a script-based approach invoked from an xUnit test.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Three separate test projects: `Starter.WebApi.Tests.Integration`, `Starter.WebApi.Tests.Unit`, `Starter.WebApi.Tests.Architecture`
- Test projects live in `tests/` directory (parallel to `src/`)
- All three projects grouped under a `/Tests` solution folder in the .slnx
- Integration tests use a shared `CustomWebApplicationFactory` base class that configures SQLite in-memory, disables external services, and seeds test data
- Fresh SQLite in-memory database per test class (unique connection string per fixture) -- full test isolation, no ordering dependencies
- Fake authentication handler for most integration tests -- auto-authenticates with configurable claims, tests focus on endpoint behavior not auth plumbing
- Auth flow tests (TEST-03) use full round-trip: register user -> login -> get JWT -> call protected endpoint with real token -> verify access (proves the auth pipeline end-to-end against real in-memory Identity store)
- Google OAuth is NOT tested in integration tests -- external redirect not feasible in WebApplicationFactory
- Identity + JWT auth flows cover the testable auth pipeline
- **Test runner:** xUnit -- standard .NET test framework with IClassFixture support
- **Assertions:** FluentAssertions -- `.Should().Be()` style for readable test assertions
- **Mocking:** Moq -- `mock.Setup(x => x.Method()).ReturnsAsync(value)` for unit test dependencies (user preference over NSubstitute despite roadmap mention)
- **Architecture:** NetArchTest -- for enforcing no module-to-module references
- **Test naming:** `MethodName_Scenario_ExpectedResult` convention (e.g., `GetByIdAsync_WhenItemExists_ReturnsDto`)

### Claude's Discretion
- Module removal smoke test approach (script-based, MSBuild, or programmatic)
- Which specific modules to include in removal smoke tests (all 20 or a representative subset)
- CustomWebApplicationFactory implementation details (service overrides, test data seeding)
- Exact fake auth handler implementation
- Test data fixtures and helper utilities
- Whether to include test configuration files (appsettings.Testing.json)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TEST-01 | Integration test project uses WebApplicationFactory\<Program\> | `Microsoft.AspNetCore.Mvc.Testing` 10.0.4 provides WebApplicationFactory. Test project uses `Microsoft.NET.Sdk.Web` SDK. CustomWebApplicationFactory overrides ConfigureWebHost to replace DB with SQLite in-memory and add fake auth handler. |
| TEST-02 | Sample tests cover health check endpoints | Health endpoints at `/health`, `/health/ready`, `/health/live` are unauthenticated. Tests use HttpClient from factory, assert 200 OK and JSON response body with `status` field. Must handle that HealthChecks module has `AddDbContextCheck<AppDbContext>` which needs the SQLite in-memory DB. |
| TEST-03 | Sample tests cover auth flows | Full round-trip: POST `/api/auth/register` -> POST `/api/auth/login` -> GET `/api/v1/todos` with Bearer token. Uses real Identity store (in-memory SQLite) and real JWT pipeline. No fake auth for these tests. Requires valid JWT config in test appsettings. |
| TEST-04 | Sample tests cover a CRUD operation | TodoController CRUD tests against `/api/v1/todos` using fake auth. POST (create), GET (list/by-id), PUT (update), DELETE. Validates status codes and response bodies. |
| TEST-05 | Unit test project includes sample service-layer tests | TodoService unit tests with Moq for `IRepository<TodoItem>`. Tests: GetByIdAsync (exists/not-found), CreateAsync, UpdateAsync (exists/throws NotFoundException), DeleteAsync. Demonstrates the Moq pattern users will copy. |
| TEST-06 | Architectural tests (NetArchTest) enforce no module-to-module references | NetArchTest.Rules scans each module assembly, asserts `ShouldNot().HaveDependencyOn()` for every other module namespace. Exception: all modules may depend on `Starter.Shared`. |
| TEST-07 | Module removal smoke tests prove removing any module doesn't break the build | Script-based approach: for each removable module, comment out AddApp*/UseApp* calls in Program.cs, remove ProjectReference from csproj, run `dotnet build`, verify exit code 0, restore files. Test all 19 removable project references (Starter.Shared is not removable). |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| xunit | 2.9.3 | Test framework | Industry standard for .NET; IClassFixture for WebApplicationFactory; class-library project model compatible with Mvc.Testing |
| xunit.runner.visualstudio | 2.8.2 | Test runner for VS/dotnet test | Required for `dotnet test` discovery and execution |
| FluentAssertions | 7.2.0 | Readable assertion library | `.Should().Be()` syntax; v7 is Apache 2.0 (free); v8+ requires commercial license ($130/dev/year) |
| Moq | 4.20.72 | Mocking framework | User preference; `mock.Setup().ReturnsAsync()` pattern for service-layer isolation |
| NetArchTest.Rules | 1.3.2 | Architecture enforcement | `ShouldNot().HaveDependencyOn()` fluent API for module isolation validation |
| Microsoft.AspNetCore.Mvc.Testing | 10.0.4 | WebApplicationFactory integration tests | Provides in-process TestServer; matches project's .NET 10 target |
| Microsoft.EntityFrameworkCore.Sqlite | 10.0.5 | SQLite in-memory for test DB | Already used by the project; in-memory mode via `DataSource=:memory:` for test isolation |
| Microsoft.NET.Test.Sdk | 17.13.0 | Test platform SDK | Required by `dotnet test` command infrastructure |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FluentAssertions 7.2.0 | FluentAssertions 8.9.0 | v8 requires $130/dev/year commercial license; v7 stays Apache 2.0 free forever |
| FluentAssertions 7.2.0 | AwesomeAssertions 7.2.0 | Community fork of FA under original Apache license; less community traction, same API |
| xUnit 2.9.3 | xUnit.v3 3.2.2 | v3 requires OutputType=Exe (standalone executable); may conflict with Mvc.Testing expectations; v3 is future but v2 is proven stable for integration tests |
| NetArchTest.Rules 1.3.2 | NetArchTest.eNhancedEdition 1.4.5 | Enhanced fork with extra rules; original is sufficient for dependency checks |
| Moq 4.20.72 | NSubstitute 5.x | Roadmap originally mentioned NSubstitute; user explicitly chose Moq |

**Installation (per project):**

Integration test project:
```bash
dotnet new xunit -n Starter.WebApi.Tests.Integration -o tests/Starter.WebApi.Tests.Integration
dotnet add tests/Starter.WebApi.Tests.Integration package Microsoft.AspNetCore.Mvc.Testing --version 10.0.4
dotnet add tests/Starter.WebApi.Tests.Integration package FluentAssertions --version 7.2.0
dotnet add tests/Starter.WebApi.Tests.Integration package Microsoft.EntityFrameworkCore.Sqlite --version 10.0.5
```

Unit test project:
```bash
dotnet new xunit -n Starter.WebApi.Tests.Unit -o tests/Starter.WebApi.Tests.Unit
dotnet add tests/Starter.WebApi.Tests.Unit package FluentAssertions --version 7.2.0
dotnet add tests/Starter.WebApi.Tests.Unit package Moq --version 4.20.72
```

Architecture test project:
```bash
dotnet new xunit -n Starter.WebApi.Tests.Architecture -o tests/Starter.WebApi.Tests.Architecture
dotnet add tests/Starter.WebApi.Tests.Architecture package FluentAssertions --version 7.2.0
dotnet add tests/Starter.WebApi.Tests.Architecture package NetArchTest.Rules --version 1.3.2
```

**Version note:** The `dotnet new xunit` template creates projects with xUnit v2 packages by default. Verify the generated csproj uses `xunit` 2.9.x and `xunit.runner.visualstudio` 2.8.x. Pin FluentAssertions to 7.2.0 to avoid accidental upgrade to v8 commercial license.

## Architecture Patterns

### Recommended Project Structure
```
tests/
  Starter.WebApi.Tests.Integration/
    Starter.WebApi.Tests.Integration.csproj
    CustomWebApplicationFactory.cs
    Helpers/
      FakeAuthHandler.cs
      TestConstants.cs
    HealthChecks/
      HealthEndpointTests.cs
    Auth/
      AuthFlowTests.cs
    Todos/
      TodoCrudTests.cs
    appsettings.Testing.json
  Starter.WebApi.Tests.Unit/
    Starter.WebApi.Tests.Unit.csproj
    Services/
      TodoServiceTests.cs
  Starter.WebApi.Tests.Architecture/
    Starter.WebApi.Tests.Architecture.csproj
    ModuleIsolationTests.cs
    ModuleRemovalTests.cs
    Scripts/
      test-module-removal.ps1
```

### Pattern 1: CustomWebApplicationFactory with SQLite In-Memory
**What:** A shared test fixture that boots the full app pipeline with an isolated SQLite in-memory database per test class.
**When to use:** All integration tests (TEST-01 through TEST-04).
**Example:**
```csharp
// Source: Microsoft Learn integration-tests docs + project-specific adaptation
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((context, config) =>
        {
            // Load test-specific config that overrides JWT secrets, DB, etc.
            config.AddJsonFile("appsettings.Testing.json", optional: true);
        });

        builder.ConfigureTestServices(services =>
        {
            // Remove production DB registrations
            var dbDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (dbDescriptor != null) services.Remove(dbDescriptor);

            // Also remove the IDbContextOptionsConfiguration<AppDbContext>
            var configDescriptors = services
                .Where(d => d.ServiceType.IsGenericType &&
                       d.ServiceType.GetGenericTypeDefinition() ==
                           typeof(IDbContextOptionsConfiguration<>))
                .ToList();
            foreach (var d in configDescriptors) services.Remove(d);

            // Create unique SQLite in-memory connection per factory instance
            var connection = new SqliteConnection("DataSource=:memory:");
            connection.Open(); // Must stay open for the lifetime of the factory

            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseSqlite(connection);
            });

            // Build a temporary SP to create/seed the database
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();

            // Add fake auth for most tests
            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = "TestScheme";
                options.DefaultChallengeScheme = "TestScheme";
            })
            .AddScheme<AuthenticationSchemeOptions, FakeAuthHandler>(
                "TestScheme", options => { });
        });

        builder.UseEnvironment("Development");
    }
}
```

### Pattern 2: Fake Authentication Handler
**What:** A custom `AuthenticationHandler` that auto-succeeds with configurable claims.
**When to use:** All integration tests EXCEPT auth flow tests (TEST-03).
**Example:**
```csharp
// Source: Microsoft Learn integration-tests docs
public class FakeAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public FakeAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, "test-user-id"),
            new Claim(ClaimTypes.Email, "test@example.com"),
            new Claim(ClaimTypes.Name, "Test User"),
        };
        var identity = new ClaimsIdentity(claims, "TestScheme");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "TestScheme");

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

### Pattern 3: Auth Flow Tests Without Fake Auth
**What:** Tests that exercise the real auth pipeline (Identity + JWT) end-to-end.
**When to use:** TEST-03 auth flow tests only.
**Example:**
```csharp
// Auth flow tests need a DIFFERENT factory that does NOT register fake auth
// Instead, they use the real auth pipeline with a known JWT secret
public class AuthFlowTests : IClassFixture<AuthWebApplicationFactory>
{
    // AuthWebApplicationFactory overrides only DB (SQLite in-memory)
    // and config (provides test JWT secret), but keeps real auth handlers

    [Fact]
    public async Task Register_Login_AccessProtected_FullRoundTrip()
    {
        // 1. Register new user
        var registerResponse = await _client.PostAsJsonAsync("/api/auth/register",
            new { Email = "test@example.com", Password = "Test1234!", ConfirmPassword = "Test1234!" });
        registerResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        var registerBody = await registerResponse.Content.ReadFromJsonAsync<JsonElement>();
        var token = registerBody.GetProperty("accessToken").GetString();
        token.Should().NotBeNullOrEmpty();

        // 2. Use token to access protected endpoint
        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);
        var todosResponse = await _client.GetAsync("/api/v1/todos");
        todosResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

### Pattern 4: NetArchTest Module Isolation
**What:** Architectural tests that scan assemblies and verify no module-to-module coupling.
**When to use:** TEST-06.
**Example:**
```csharp
// Source: NetArchTest GitHub README + adaptation for this project
[Fact]
public void Modules_ShouldNot_DependOnOtherModules()
{
    // Get all module assemblies (exclude Shared, Host, Migrations)
    var moduleAssemblies = new[]
    {
        typeof(Starter.ExceptionHandling.ExceptionHandlingExtensions).Assembly,
        typeof(Starter.Logging.LoggingExtensions).Assembly,
        typeof(Starter.Data.DataExtensions).Assembly,
        // ... all module assemblies
    };

    var moduleNamespaces = moduleAssemblies
        .Select(a => a.GetName().Name!)
        .ToArray();

    foreach (var assembly in moduleAssemblies)
    {
        var assemblyName = assembly.GetName().Name!;
        var otherModules = moduleNamespaces
            .Where(n => n != assemblyName && n != "Starter.Shared" && n != "Starter.Auth.Shared")
            .ToArray();

        var result = Types.InAssembly(assembly)
            .ShouldNot()
            .HaveDependencyOnAny(otherModules)
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"{assemblyName} should not depend on other modules but depends on: " +
            string.Join(", ", result.FailingTypeNames ?? Array.Empty<string>()));
    }
}
```

### Pattern 5: Module Removal Smoke Tests (Script-Based)
**What:** A script that iterates through each removable module, patches Program.cs and the Host .csproj, runs `dotnet build`, and asserts success.
**When to use:** TEST-07.
**Recommended approach:** PowerShell script (Windows project) invoked by an xUnit `[Fact]` test via `Process.Start`. The script:
1. Copies Program.cs and Starter.WebApi.csproj to temp backups
2. For each module: comments out its `AddApp*`/`UseApp*` lines + using statement, removes its `<ProjectReference>`, runs `dotnet build --no-restore` (restore once at start), checks exit code
3. Restores originals after each iteration
4. Returns exit code 0 if all passed

**Which modules to test:** All 19 removable project references in the Host csproj. Starter.Shared is NOT removable (it is the contract library). The 19 references map to these removable units:

| Module | Extension Calls to Remove | Using to Remove |
|--------|--------------------------|-----------------|
| Starter.ExceptionHandling | `AddAppExceptionHandling()`, `UseAppExceptionHandling()` | `Starter.ExceptionHandling` |
| Starter.Logging | `AddAppLogging()`, `UseAppRequestLogging()` | `Starter.Logging` |
| Starter.Auth.Shared | `AddAppAuthShared()` | `Starter.Auth.Shared` |
| Starter.Auth.Identity | `AddAppIdentity()` | `Starter.Auth.Identity` |
| Starter.Auth.Jwt | `AddAppJwt()` | `Starter.Auth.Jwt` |
| Starter.Auth.Google | `AddAppGoogle()` | `Starter.Auth.Google` |
| Starter.Data | `AddAppData()`, `UseAppData()` | `Starter.Data` |
| Starter.Data.Migrations.Sqlite | (no extension call, just project ref) | (none) |
| Starter.Data.Migrations.SqlServer | (no extension call, just project ref) | (none) |
| Starter.Data.Migrations.PostgreSql | (no extension call, just project ref) | (none) |
| Starter.Cors | `AddAppCors()` | `Starter.Cors` |
| Starter.Versioning | `AddAppVersioning()` | `Starter.Versioning` |
| Starter.Validation | `AddAppValidation()` | `Starter.Validation` |
| Starter.OpenApi | `AddAppOpenApi()`, `UseAppOpenApi()` | `Starter.OpenApi` |
| Starter.RateLimiting | `AddAppRateLimiting(...)`, `UseAppRateLimiting()` | `Starter.RateLimiting` |
| Starter.Caching | `AddAppCaching(...)` | `Starter.Caching` |
| Starter.Compression | (commented out already, just project ref) | `Starter.Compression` |
| Starter.Responses | `AddAppResponses()` | `Starter.Responses` |
| Starter.HealthChecks | `AddAppHealthChecks()`, `UseAppHealthChecks()` | `Starter.HealthChecks` |

**Important caveat for removal tests:** Some modules have dependencies that require coordinated removal. For example, `AuthController` in the Host depends on `JwtTokenService` (from `Starter.Auth.Jwt`), `UserManager<AppUser>` (from `Starter.Auth.Identity`), and `SignInManager<AppUser>` (from `Starter.Auth.Identity`). Removing `Starter.Auth.Identity` alone will cause build failures because `AuthController` references these types. This is expected -- the starter repo's promise is that removing a module's extension call + project reference is clean IF you also remove any Host controllers that depend on that module's types. The smoke test script should account for this by also removing the corresponding controller files when testing certain modules. Alternatively, scope the test to verify that the module *class library projects themselves* have no cross-module dependencies (which TEST-06 already covers via NetArchTest), and that removing modules that are purely infrastructure (no controller dependency) builds cleanly.

**Recommended subset for pure removal tests (no controller dependency):**
- Starter.ExceptionHandling
- Starter.Logging
- Starter.Cors
- Starter.OpenApi
- Starter.RateLimiting
- Starter.Caching
- Starter.Compression
- Starter.Responses
- Starter.HealthChecks
- Starter.Versioning
- Starter.Validation
- Starter.Auth.Google
- Starter.Data.Migrations.Sqlite
- Starter.Data.Migrations.SqlServer
- Starter.Data.Migrations.PostgreSql

For modules with controller dependencies (Auth.Shared, Auth.Identity, Auth.Jwt, Data), the test should also remove corresponding controllers (AuthController, TodoController, TodoV2Controller, CacheDemoController) to demonstrate the full removal pattern.

### Anti-Patterns to Avoid
- **Using EF Core InMemory provider instead of SQLite:** EF Core InMemory is not a relational database and will not enforce constraints, foreign keys, or cascade deletes. SQLite in-memory mode is a real relational database and catches more bugs.
- **Sharing database state between test classes:** Each test class must get its own SQLite in-memory connection. Sharing causes test ordering dependencies and flaky tests.
- **Testing Google OAuth in integration tests:** WebApplicationFactory cannot handle external redirects. Skip Google OAuth testing; it is an external provider concern.
- **Using FluentAssertions 8.x without a license:** v8+ changed to a commercial license ($130/dev/year). Pin to v7.2.0 to stay on Apache 2.0.
- **Modifying Program.cs/csproj in-process for removal tests:** File manipulation from within an xUnit test is fragile. Use an external script that can be tested independently.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| In-process test server | Custom Kestrel/HttpListener setup | `WebApplicationFactory<Program>` | Handles full DI, middleware pipeline, TestServer lifecycle |
| Test authentication bypass | Manual token generation per test | `FakeAuthHandler` + `AddScheme` | Standard pattern; configurable claims; no crypto overhead |
| Architecture dependency checks | Reflection-based assembly scanning | `NetArchTest.Rules` | Fluent API, handles transitive dependencies, battle-tested |
| Database isolation per test | Manual connection management | SQLite `:memory:` + unique connection per fixture | Automatic cleanup when connection closes; EnsureCreated for schema |
| Module removal verification | Manual one-by-one testing | PowerShell script iterating module definitions | Repeatable, CI-friendly, covers all 19 modules systematically |

**Key insight:** The most dangerous custom solution would be hand-rolling module removal verification -- it is tedious, error-prone, and will be skipped if not automated. A script that systematically tests each module is the only way to maintain the core value proposition as the codebase evolves.

## Common Pitfalls

### Pitfall 1: AppDbContext is internal -- test projects cannot reference it directly
**What goes wrong:** `Starter.Data.AppDbContext` is `internal class`. Test projects that try to use `typeof(AppDbContext)` or register it in DI will get compilation errors.
**Why it happens:** The project follows FOUND-07 (internal by default). Only extension methods are public.
**How to avoid:** Add `<InternalsVisibleTo Include="Starter.WebApi.Tests.Integration" />` to `Starter.Data.csproj`. The csproj already has InternalsVisibleTo for migration assemblies and other modules, so the pattern is established.
**Warning signs:** CS0122 accessibility errors during compilation.

### Pitfall 2: SQLite in-memory connection closes = database disappears
**What goes wrong:** If the SQLite connection is created and not held open, the in-memory database is destroyed when the connection closes. Tests find empty tables.
**Why it happens:** SQLite in-memory databases exist only while their connection is open.
**How to avoid:** Store the `SqliteConnection` as a field in `CustomWebApplicationFactory`, call `connection.Open()` immediately, and only close it in `Dispose()`.
**Warning signs:** Tests intermittently find no data; "no such table" errors.

### Pitfall 3: ValidateOnStart kills the test host at startup
**What goes wrong:** Many modules use `ValidateDataAnnotations().ValidateOnStart()` on their options. If the test appsettings don't provide required config sections (Jwt:SecretKey, Database:Provider, etc.), the host fails to start.
**Why it happens:** `ValidateOnStart` runs during `IHost.StartAsync`, before any test code executes.
**How to avoid:** Provide an `appsettings.Testing.json` in the integration test project that satisfies all required configuration. Key sections: `Jwt` (with a test SecretKey), `Database` (Provider=Sqlite, AutoMigrate=false), `HealthChecks` (ExternalServiceUri can be empty), `RateLimiting`, `Caching`, `Compression`, `Cors`, `ExceptionHandling`, `Serilog`.
**Warning signs:** `OptionsValidationException` during test host startup.

### Pitfall 4: Fake auth handler does not override PolicyScheme ForwardDefaultSelector
**What goes wrong:** The app configures `AuthConstants.PolicyScheme` as the default scheme with a ForwardDefaultSelector that routes to JWT. If the test just adds a new scheme without overriding `DefaultAuthenticateScheme` and `DefaultChallengeScheme`, the test requests still go through the real JWT handler and fail with 401.
**Why it happens:** The PolicyScheme in `AddAppAuthShared()` sets `ForwardDefaultSelector = _ => AuthConstants.JwtScheme`. This takes priority unless the default schemes are overridden.
**How to avoid:** In `ConfigureTestServices`, explicitly set `options.DefaultAuthenticateScheme = "TestScheme"` and `options.DefaultChallengeScheme = "TestScheme"`. This overrides the PolicyScheme routing.
**Warning signs:** 401 Unauthorized responses even though FakeAuthHandler is registered.

### Pitfall 5: Health check tests fail because ExternalServiceHealthCheck needs HttpClient
**What goes wrong:** The `ExternalServiceHealthCheck` uses `IHttpClientFactory` to call an external URI. In tests, this URI is empty or unreachable, causing the health check to fail.
**Why it happens:** The HealthChecks module registers `AddHttpClient()` and the external check tries to call the configured URI.
**How to avoid:** In the test factory, override the `HealthCheckModuleOptions.ExternalServiceUri` to point to a test endpoint, or register a mock/stub for the external health check. Alternatively, set the URI to empty string and accept that the external check will report Degraded/Unhealthy (test that the aggregate endpoint still returns 200 with a Degraded status).
**Warning signs:** Health check tests timeout or return 503.

### Pitfall 6: Module removal test restoring files on failure
**What goes wrong:** If the `dotnet build` hangs or the script crashes mid-execution, the original Program.cs and csproj remain modified, breaking subsequent builds.
**Why it happens:** File patching without robust cleanup.
**How to avoid:** Use `try/finally` in the script, or better: work on copies of the files in a temp directory. Copy the entire `src/` tree to a temp location, modify there, build there, and discard.
**Warning signs:** Git shows unexpected changes after test failure.

### Pitfall 7: TodoService is internal sealed -- unit tests cannot instantiate it
**What goes wrong:** `TodoService` in `Starter.Data.Services` is `internal sealed class`. The unit test project cannot create instances for testing.
**Why it happens:** FOUND-07 internal visibility default.
**How to avoid:** Add `<InternalsVisibleTo Include="Starter.WebApi.Tests.Unit" />` to `Starter.Data.csproj`.
**Warning signs:** CS0122 accessibility errors in unit test project.

## Code Examples

### appsettings.Testing.json (Integration Tests)
```json
{
  "Jwt": {
    "SecretKey": "TestOnlySecretKey-ForIntegrationTests-Min32Chars!!",
    "Issuer": "TestIssuer",
    "Audience": "TestAudience",
    "ExpirationMinutes": 60
  },
  "Database": {
    "Provider": "Sqlite",
    "AutoMigrate": false,
    "CommandTimeout": 30,
    "EnableSensitiveDataLogging": false,
    "MaxRetryCount": 0
  },
  "ConnectionStrings": {
    "Sqlite": "DataSource=:memory:"
  },
  "HealthChecks": {
    "ExternalServiceUri": "",
    "TimeoutSeconds": 5
  },
  "RateLimiting": {
    "Enabled": false,
    "GlobalPermitLimit": 10000,
    "GlobalWindowSeconds": 1
  },
  "Caching": {
    "DefaultExpirationSeconds": 60,
    "SlidingExpirationSeconds": 30,
    "RedisConnectionString": "",
    "RedisInstanceName": "test:"
  },
  "Compression": {
    "EnableForHttps": false,
    "BrotliLevel": "Fastest",
    "GzipLevel": "Fastest"
  },
  "Cors": {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    "AllowedHeaders": ["*"],
    "AllowCredentials": false
  },
  "ExceptionHandling": {
    "IncludeStackTraceInDevelopment": true
  },
  "OpenApi": {
    "EnableScalar": false,
    "Title": "Test API",
    "Description": "Test"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Warning"
    },
    "Sinks": {
      "Console": { "Enabled": false },
      "File": { "Enabled": false },
      "Seq": { "Enabled": false },
      "OpenTelemetry": { "Enabled": false }
    }
  }
}
```

### Integration Test: Health Check Endpoints (TEST-02)
```csharp
public class HealthEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public HealthEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Theory]
    [InlineData("/health")]
    [InlineData("/health/ready")]
    [InlineData("/health/live")]
    public async Task HealthEndpoint_ReturnsSuccess(string url)
    {
        var response = await _client.GetAsync(url);

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadAsStringAsync();
        content.Should().Contain("\"status\":");
    }

    [Fact]
    public async Task HealthEndpoint_ReturnsJsonWithStatusField()
    {
        var response = await _client.GetAsync("/health");
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();

        json.GetProperty("status").GetString().Should().NotBeNullOrEmpty();
        json.TryGetProperty("results", out _).Should().BeTrue();
    }
}
```

### Unit Test: TodoService with Moq (TEST-05)
```csharp
public class TodoServiceTests
{
    private readonly Mock<IRepository<TodoItem>> _repositoryMock;
    private readonly TodoService _sut;

    public TodoServiceTests()
    {
        _repositoryMock = new Mock<IRepository<TodoItem>>();
        _sut = new TodoService(_repositoryMock.Object);
    }

    [Fact]
    public async Task GetByIdAsync_WhenItemExists_ReturnsDto()
    {
        // Arrange
        var item = new TodoItem { Id = 1, Title = "Test", IsComplete = false, CreatedAt = DateTime.UtcNow };
        _repositoryMock.Setup(r => r.GetByIdAsync(1, It.IsAny<CancellationToken>()))
            .ReturnsAsync(item);

        // Act
        var result = await _sut.GetByIdAsync(1);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(1);
        result.Title.Should().Be("Test");
    }

    [Fact]
    public async Task GetByIdAsync_WhenItemNotFound_ReturnsNull()
    {
        _repositoryMock.Setup(r => r.GetByIdAsync(99, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TodoItem?)null);

        var result = await _sut.GetByIdAsync(99);

        result.Should().BeNull();
    }

    [Fact]
    public async Task UpdateAsync_WhenItemNotFound_ThrowsNotFoundException()
    {
        _repositoryMock.Setup(r => r.GetByIdAsync(99, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TodoItem?)null);

        var act = () => _sut.UpdateAsync(99, "Updated", true);

        await act.Should().ThrowAsync<NotFoundException>();
    }
}
```

### Integration Test Project .csproj Structure
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.4" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="10.0.5" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.13.0" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageReference Include="FluentAssertions" Version="7.2.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\Starter.WebApi\Starter.WebApi.csproj" />
  </ItemGroup>

  <ItemGroup>
    <Content Include="appsettings.Testing.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>

</Project>
```

**Note on SDK:** The integration test project MUST use `Microsoft.NET.Sdk.Web` (not `Microsoft.NET.Sdk`) because `Microsoft.AspNetCore.Mvc.Testing` requires it for proper assembly discovery and TestServer configuration.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| EF Core InMemory provider | SQLite in-memory mode | ~2022 (EF Core docs updated) | SQLite catches relational bugs InMemory misses |
| xUnit v2 class library tests | xUnit v3 standalone executables | 2025 (v3.0 release) | Better isolation, faster execution; v2 still fully supported |
| FluentAssertions free (Apache) | FluentAssertions v8 commercial license | Jan 2025 | Pin to v7.2.0 for free use; AwesomeAssertions as fork alternative |
| Custom auth bypass middleware | `AddScheme<FakeAuthHandler>` | ~2020 (ASP.NET Core 3.1+) | Standard pattern, works with authorization policies |
| NetArchTest.Rules only | NetArchTest.eNhancedEdition fork | 2023 | Enhanced fork adds more rules; original sufficient for this use case |

**Deprecated/outdated:**
- `EF Core InMemory provider` for integration tests: Microsoft docs now explicitly discourage this; use SQLite in-memory instead
- `FluentAssertions 8.x` without paid license: Not legal for commercial projects since Jan 2025
- `xunit.runner.console` as primary runner: Replaced by `xunit.runner.visualstudio` for `dotnet test` integration

## Open Questions

1. **Module removal test strategy -- full copy or in-place patching?**
   - What we know: In-place patching risks leaving dirty state on failure. Full directory copy is safer but slower.
   - What's unclear: Whether `dotnet build` on a copied directory will work without a full restore (NuGet cache should help).
   - Recommendation: Use in-place patching with git-based restore (`git checkout -- <files>`) as cleanup. This is fast, reliable (git is always available), and leaves no residue. The test should run `git checkout` in a `finally` block.

2. **Auth flow tests need a separate factory without fake auth**
   - What we know: TEST-03 needs the real auth pipeline but still needs SQLite in-memory DB.
   - What's unclear: Whether to create a completely separate factory class or use `WithWebHostBuilder` per-test to selectively not register fake auth.
   - Recommendation: Create a separate `AuthWebApplicationFactory` that only overrides DB (SQLite in-memory) and config (test JWT secret) but keeps real auth handlers. This is cleaner than trying to undo fake auth per-test.

3. **NetArchTest and Auth.Shared cross-module dependency**
   - What we know: `Starter.Auth.Identity` depends on `Starter.Auth.Shared` (for `AppUser`, `AuthConstants`). `Starter.Data` depends on `Starter.Auth.Shared` (for `AppUser` in `IdentityDbContext`). These are intentional shared-infrastructure dependencies.
   - What's unclear: How to express the "allowed dependency" rule in NetArchTest.
   - Recommendation: Treat `Starter.Auth.Shared` as a shared library (like `Starter.Shared`) that any module may depend on. The NetArchTest rule should exclude both `Starter.Shared` and `Starter.Auth.Shared` from the "no dependency" list. The rule is: *no module should depend on another module, except through Shared and Auth.Shared*.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | xUnit 2.9.3 |
| Config file | None -- created in this phase (Wave 0 gap) |
| Quick run command | `dotnet test tests/ --filter "Category!=Slow" --no-build` |
| Full suite command | `dotnet test tests/` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | WebApplicationFactory boots and serves requests | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "HealthEndpointTests" -x` | Wave 0 |
| TEST-02 | Health check endpoints return success | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "HealthEndpointTests" -x` | Wave 0 |
| TEST-03 | Auth flows (register/login/access) work end-to-end | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "AuthFlowTests" -x` | Wave 0 |
| TEST-04 | CRUD operations on todos work | integration | `dotnet test tests/Starter.WebApi.Tests.Integration --filter "TodoCrudTests" -x` | Wave 0 |
| TEST-05 | Service-layer unit tests pass | unit | `dotnet test tests/Starter.WebApi.Tests.Unit -x` | Wave 0 |
| TEST-06 | No module-to-module references | architecture | `dotnet test tests/Starter.WebApi.Tests.Architecture --filter "ModuleIsolationTests" -x` | Wave 0 |
| TEST-07 | Module removal builds succeed | architecture/smoke | `dotnet test tests/Starter.WebApi.Tests.Architecture --filter "ModuleRemovalTests" -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `dotnet test tests/ --no-build`
- **Per wave merge:** `dotnet test tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/Starter.WebApi.Tests.Integration/` -- entire project (csproj, CustomWebApplicationFactory, appsettings.Testing.json, FakeAuthHandler)
- [ ] `tests/Starter.WebApi.Tests.Unit/` -- entire project (csproj, TodoServiceTests)
- [ ] `tests/Starter.WebApi.Tests.Architecture/` -- entire project (csproj, ModuleIsolationTests, ModuleRemovalTests, removal script)
- [ ] `Starter.Data.csproj` -- needs `InternalsVisibleTo` for both test projects
- [ ] `Starter.WebApi.slnx` -- needs `/Tests` folder with 3 test project entries

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn - Integration tests in ASP.NET Core (.NET 10)](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-10.0) - WebApplicationFactory patterns, fake auth handler, service overrides
- [Microsoft Learn - Testing without production database (EF Core)](https://learn.microsoft.com/en-us/ef/core/testing/testing-without-the-database) - SQLite in-memory recommendation over InMemory provider
- [NuGet Gallery - Microsoft.AspNetCore.Mvc.Testing 10.0.4](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing) - Package version verification
- [NuGet Gallery - FluentAssertions 7.2.0](https://www.nuget.org/packages/FluentAssertions/7.2.0) - Apache 2.0 license, xUnit v3 support
- [NuGet Gallery - Moq 4.20.72](https://www.nuget.org/packages/Moq) - Latest stable version
- [NuGet Gallery - NetArchTest.Rules 1.3.2](https://www.nuget.org/packages/NetArchTest.Rules/) - Architecture testing library
- [NuGet Gallery - xunit 2.9.3](https://www.nuget.org/packages/xunit) - Latest v2 stable

### Secondary (MEDIUM confidence)
- [FluentAssertions v8 license change (InfoQ)](https://www.infoq.com/news/2025/01/fluent-assertions-v8-license/) - Commercial license details for v8+
- [NetArchTest GitHub](https://github.com/BenMorris/NetArchTest) - API examples, HaveDependencyOn usage
- [xUnit.net v3 What's New](https://xunit.net/docs/getting-started/v3/whats-new) - v3 changes, OutputType=Exe requirement

### Tertiary (LOW confidence)
- Module removal test approach is a recommended pattern based on the project's specific architecture; no canonical reference exists for this exact pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all packages verified on NuGet with current versions; license status confirmed
- Architecture: HIGH - patterns are well-documented by Microsoft and community; adapted to project-specific codebase
- Pitfalls: HIGH - based on direct inspection of codebase (`internal` classes, ValidateOnStart, PolicyScheme routing) cross-referenced with official docs
- Module removal tests: MEDIUM - approach is sound but implementation details (script vs in-process, which modules need controller removal) require judgment calls during planning

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable ecosystem; xUnit/FluentAssertions/Moq are mature)
