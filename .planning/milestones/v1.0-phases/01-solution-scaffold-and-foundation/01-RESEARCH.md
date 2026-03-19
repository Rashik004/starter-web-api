# Phase 1: Solution Scaffold and Foundation - Research

**Researched:** 2026-03-18
**Domain:** .NET 10 solution scaffolding, extension method composition, IOptions validation, IExceptionHandler + ProblemDetails
**Confidence:** HIGH

## Summary

Phase 1 creates the foundational .NET 10 solution structure from scratch: a new SLNX solution with Host (Starter.WebApi) and Shared (Starter.Shared) projects, plus a single module class library (Starter.ExceptionHandling) that serves as both the global exception handler and the proof-of-concept for the removable module pattern. The existing TemplateWebApi project and solution in the repo root will be replaced entirely.

The three technical pillars of this phase are: (1) the extension method composition pattern where each module exposes `AddApp*`/`UseApp*` methods on `IServiceCollection`/`WebApplication`, (2) the IOptions<T> + ValidateDataAnnotations + ValidateOnStart pattern that fails fast on misconfiguration, and (3) the IExceptionHandler-based global exception handling that returns RFC 7807 ProblemDetails with typed exception mapping. All three are built-in ASP.NET Core 10 features requiring zero external packages.

**Primary recommendation:** Scaffold the solution using `dotnet new sln` (SLNX default in .NET 10) with `dotnet sln add --solution-folder` for Visual Studio organization. Use `FrameworkReference` to `Microsoft.AspNetCore.App` in module class libraries that need ASP.NET Core types. Keep the ExceptionHandling module as the sole sample module -- it simultaneously demonstrates the removability pattern and fulfills EXCP-01 through EXCP-05.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Minimal scaffold: Host + Shared + ExceptionHandling module only -- other module projects created in their respective phases
- Exception handling module (Starter.ExceptionHandling) is the sample module that proves the removability pattern -- no throwaway demo code
- Solution uses solution folders in the .sln to group projects (e.g., /Modules, /Tests, /Host) for Visual Studio Solution Explorer organization
- Program.cs has grouped-by-concern layout with comment sections: Observability, Security, Data, API
- Extension method prefix: `AddApp*` / `UseApp*` (e.g., `builder.Services.AddAppExceptionHandling()`, `app.UseAppExceptionHandling()`)
- Host project: `Starter.WebApi`
- Shared contracts project: `Starter.Shared`
- Module class libraries: `Starter.{Module}` (e.g., `Starter.ExceptionHandling`, `Starter.Auth`, `Starter.Logging`)
- Solution name: `Starter.WebApi.sln` (note: will be `Starter.WebApi.slnx` due to .NET 10 default)
- Extended ProblemDetails shape: standard RFC 7807 fields + `traceId` + `errors` object for consistency with validation errors
- Typed exception mapping: specific exception types map to HTTP status codes (NotFoundException -> 404, ValidationException -> 422, UnauthorizedException -> 401, etc.)
- Custom exception types live in Starter.Shared so all modules can throw them and the exception handler catches them
- Uses built-in IExceptionHandler (not custom middleware)
- Stack traces included in Development, hidden in Production

### Claude's Discretion
- Exact solution folder grouping names and structure
- Which specific exception types to include initially
- IOptions ValidateOnStart wiring pattern details
- appsettings.json section naming conventions
- Whether to include a sample controller in the Host project for Phase 1 testing

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | Solution contains a Shared class library with only contracts (response envelope, config constants, cross-module interfaces) | Starter.Shared project structure with custom exception types, config section name constants. Class library using `Microsoft.NET.Sdk` with no ASP.NET Core dependency beyond `Microsoft.Extensions.Options`. |
| FOUND-02 | Solution contains a Host Web API project that references only the modules it needs | Starter.WebApi using `Microsoft.NET.Sdk.Web`, referencing Starter.Shared and Starter.ExceptionHandling. Program.cs as composition root. |
| FOUND-03 | Each module is a separate class library exposing AddStarter{Module} on IServiceCollection and optionally UseStarter{Module} on WebApplication | Per context decision: prefix is `AddApp*`/`UseApp*`. Starter.ExceptionHandling exposes `AddAppExceptionHandling()` and `UseAppExceptionHandling()`. Module uses `FrameworkReference` to access ASP.NET Core types. |
| FOUND-04 | Program.cs uses grouped-by-concern layout (Observability, Security, Data, API sections) with one extension method call per module | Grouped comment sections pattern with placeholder comments for future phases. Exception handling call in API section. |
| FOUND-05 | Removing a module requires only deleting the extension method call(s) in Program.cs and the project reference -- no other changes | Verified by architecture: custom exception types in Shared (not in module), IExceptionHandler registered via DI, no compile-time dependency from Host to module internals beyond extension methods. |
| FOUND-06 | No module references another module directly -- all cross-module communication flows through interfaces in Shared resolved via DI | Starter.ExceptionHandling references only Starter.Shared. Starter.Shared references nothing in the solution. |
| FOUND-07 | All class library projects use `internal` visibility by default; only extension methods and contracts are public | Module types (handler implementation) are `internal`. Only the static extension method class is `public`. Shared types (exceptions, contracts) are `public` by design. |
| CONF-01 | Each module owns a strongly-typed config section in appsettings.json via IOptions<T> | ExceptionHandling module demonstrates the pattern with `ExceptionHandlingOptions` bound to its own section. |
| CONF-02 | All IOptions<T> registrations use ValidateDataAnnotations and ValidateOnStart to catch misconfiguration at startup | Research confirms `OptionsBuilder<T>.BindConfiguration().ValidateDataAnnotations().ValidateOnStart()` chain. Throws `OptionsValidationException` at startup on failure. |
| CONF-03 | Guidance for User Secrets (development), Environment Variables, and Azure Key Vault (production) is documented | Documentation in appsettings.json comments and a configuration guidance section. Built-in ASP.NET Core configuration provider hierarchy handles this. |
| EXCP-01 | Global exception handling catches all unhandled exceptions | IExceptionHandler registered via `AddExceptionHandler<T>()`, activated by `UseExceptionHandler()`. Must be first middleware. |
| EXCP-02 | All error responses use RFC 7807 Problem Details format | `AddProblemDetails()` with `CustomizeProblemDetails` callback adds traceId and errors extensions. |
| EXCP-03 | Stack traces are included in Development, hidden in Production | IExceptionHandler checks `IHostEnvironment.IsDevelopment()` to conditionally include stack trace in ProblemDetails extensions. |
| EXCP-04 | Exceptions are logged through the structured logging pipeline | IExceptionHandler injects `ILogger<T>` and logs the full exception before writing ProblemDetails response. In Phase 1 this uses built-in logging; Phase 2 replaces with Serilog. |
| EXCP-05 | Uses built-in IExceptionHandler (not custom middleware) | Confirmed: `IExceptionHandler` (since .NET 8) is the modern pattern. Register with `AddExceptionHandler<T>()`, activate with `UseExceptionHandler()`. |

</phase_requirements>

## Standard Stack

### Core (Phase 1 Only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| .NET 10 SDK | 10.0.101 | Runtime and SDK | Verified installed locally. LTS release. |
| ASP.NET Core 10 | 10.0 | Web API framework | Ships with SDK. Built-in IExceptionHandler, ProblemDetails, IOptions validation. |
| Microsoft.Extensions.Options | Ships with framework | Options pattern | Built-in. No NuGet needed. Provides `OptionsBuilder<T>`, `ValidateDataAnnotations()`, `ValidateOnStart()`. |
| Microsoft.AspNetCore.Diagnostics | Ships with framework | IExceptionHandler | Built-in. No NuGet needed. Provides `IExceptionHandler`, `AddExceptionHandler<T>()`. |

### Phase 1 NuGet Packages

**None.** Phase 1 uses only built-in framework features. No external NuGet packages are required for the scaffold, IOptions validation, or IExceptionHandler/ProblemDetails.

### Supporting (Referenced from Project Research for Future Phases)

See `.planning/research/STACK.md` for the complete stack. Phase 1 establishes the structure; subsequent phases add packages.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| IExceptionHandler | Custom exception middleware | IExceptionHandler is the official .NET 8+ pattern, integrates with ProblemDetails natively. Custom middleware is the pre-.NET 8 approach. |
| ValidateDataAnnotations | IValidateOptions<T> manual implementation | DataAnnotations are simpler for straightforward required/range validation. IValidateOptions is available for complex cross-property validation in future modules. |
| ValidateDataAnnotations | [OptionsValidator] source generator | Source generator eliminates reflection but requires a partial class per options type. DataAnnotations is simpler for Phase 1; source generator can be adopted later if needed. |

**Installation:** No packages to install. All Phase 1 features are built into the framework.

## Architecture Patterns

### Recommended Project Structure (Phase 1)

```
Starter.WebApi.slnx                            # .NET 10 SLNX format solution
|
+-- src/
|   +-- Starter.WebApi/                         # Host (composition root)
|   |   +-- Properties/
|   |   |   +-- launchSettings.json
|   |   +-- Program.cs                          # Composition root with grouped sections
|   |   +-- appsettings.json                    # All module config sections
|   |   +-- appsettings.Development.json
|   |   +-- Starter.WebApi.csproj               # Microsoft.NET.Sdk.Web
|   |
|   +-- Starter.Shared/                         # Shared contracts
|   |   +-- Exceptions/                         # Custom exception types
|   |   |   +-- AppException.cs                 # Base exception
|   |   |   +-- NotFoundException.cs
|   |   |   +-- ValidationException.cs
|   |   |   +-- ConflictException.cs
|   |   |   +-- UnauthorizedException.cs
|   |   |   +-- ForbiddenException.cs
|   |   +-- Starter.Shared.csproj               # Microsoft.NET.Sdk (plain class library)
|   |
|   +-- Starter.ExceptionHandling/              # Exception handling module
|       +-- Handlers/
|       |   +-- GlobalExceptionHandler.cs       # internal IExceptionHandler implementation
|       +-- Options/
|       |   +-- ExceptionHandlingOptions.cs     # Strongly-typed config
|       +-- ExceptionHandlingExtensions.cs      # public AddApp*/UseApp* methods
|       +-- Starter.ExceptionHandling.csproj    # Microsoft.NET.Sdk with FrameworkReference
|
+-- tests/                                      # Empty for Phase 1 (Phase 6 creates test projects)
```

### Solution Folder Organization (Visual Studio)

```
Solution 'Starter.WebApi' (SLNX)
|
+-- Host/                                       # Solution folder
|   +-- Starter.WebApi
|
+-- Libraries/                                  # Solution folder
|   +-- Starter.Shared
|
+-- Modules/                                    # Solution folder
|   +-- Starter.ExceptionHandling
|
+-- Tests/                                      # Solution folder (empty in Phase 1)
```

### Pattern 1: Extension Method Composition (Core Pattern)

**What:** Each module class library exposes `AddApp{Module}(this IServiceCollection)` for service registration and optionally `UseApp{Module}(this WebApplication)` for middleware pipeline configuration. The Host's Program.cs calls these in a clear grouped order.

**When to use:** Every module. This is the foundational pattern.

**Example:**

```csharp
// In Starter.ExceptionHandling/ExceptionHandlingExtensions.cs
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace Starter.ExceptionHandling;

public static class ExceptionHandlingExtensions
{
    public static IServiceCollection AddAppExceptionHandling(
        this IServiceCollection services)
    {
        services.AddProblemDetails(options =>
        {
            options.CustomizeProblemDetails = context =>
            {
                context.ProblemDetails.Extensions["traceId"] =
                    context.HttpContext.TraceIdentifier;
            };
        });

        services.AddExceptionHandler<GlobalExceptionHandler>();

        return services;
    }

    public static WebApplication UseAppExceptionHandling(
        this WebApplication app)
    {
        app.UseExceptionHandler();
        return app;
    }
}
```

Source: [Handle errors in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-10.0)

### Pattern 2: IExceptionHandler with Typed Exception Mapping

**What:** A single `IExceptionHandler` implementation maps custom exception types to HTTP status codes and writes RFC 7807 ProblemDetails responses. Stack traces are conditionally included based on environment.

**When to use:** Global exception handling for the entire application.

**Example:**

```csharp
// In Starter.ExceptionHandling/Handlers/GlobalExceptionHandler.cs
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Starter.Shared.Exceptions;

namespace Starter.ExceptionHandling.Handlers;

internal sealed class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger,
    IHostEnvironment environment) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        logger.LogError(exception, "Unhandled exception: {Message}", exception.Message);

        var (statusCode, title) = MapException(exception);

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = exception.Message,
            Instance = $"{httpContext.Request.Method} {httpContext.Request.Path}",
            Type = $"https://httpstatuses.io/{statusCode}"
        };

        problemDetails.Extensions["traceId"] = httpContext.TraceIdentifier;

        if (environment.IsDevelopment())
        {
            problemDetails.Extensions["stackTrace"] = exception.StackTrace;
        }

        if (exception is AppValidationException validationException
            && validationException.Errors.Count > 0)
        {
            problemDetails.Extensions["errors"] = validationException.Errors;
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

        return true;
    }

    private static (int StatusCode, string Title) MapException(Exception exception) =>
        exception switch
        {
            NotFoundException => (StatusCodes.Status404NotFound, "Not Found"),
            AppValidationException => (StatusCodes.Status422UnprocessableEntity, "Validation Failed"),
            ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
            UnauthorizedException => (StatusCodes.Status401Unauthorized, "Unauthorized"),
            ForbiddenException => (StatusCodes.Status403Forbidden, "Forbidden"),
            _ => (StatusCodes.Status500InternalServerError, "Internal Server Error")
        };
}
```

Source: [Global Error Handling in ASP.NET Core - Milan Jovanovic](https://www.milanjovanovic.tech/blog/global-error-handling-in-aspnetcore-8), [Handle errors in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-10.0)

### Pattern 3: IOptions<T> with ValidateOnStart

**What:** Each module defines a strongly-typed options class decorated with `DataAnnotations` attributes. The module's extension method uses `OptionsBuilder<T>` to bind, validate, and force startup validation.

**When to use:** Every module that has configurable behavior.

**Example:**

```csharp
// In module Options/ folder
using System.ComponentModel.DataAnnotations;

namespace Starter.ExceptionHandling.Options;

public sealed class ExceptionHandlingOptions
{
    public const string SectionName = "ExceptionHandling";

    public bool IncludeStackTraceInDevelopment { get; set; } = true;
}

// In module extension method
services.AddOptions<ExceptionHandlingOptions>()
    .BindConfiguration(ExceptionHandlingOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

**Critical chain:** `AddOptions<T>()` -> `.BindConfiguration(sectionName)` -> `.ValidateDataAnnotations()` -> `.ValidateOnStart()`

- `BindConfiguration` binds to a named section in appsettings.json (equivalent to `Bind(configuration.GetSection(name))` but does not require IConfiguration injection)
- `ValidateDataAnnotations` runs `[Required]`, `[Range]`, `[StringLength]`, etc.
- `ValidateOnStart` runs validation eagerly at startup, throwing `OptionsValidationException` if invalid

Source: [Options pattern in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/options?view=aspnetcore-10.0)

### Pattern 4: Grouped-by-Concern Program.cs

**What:** Program.cs is organized into named comment sections that group related service registrations and middleware calls.

**When to use:** Always. This is the composition root layout.

**Example:**

```csharp
// Program.cs - Composition Root
var builder = WebApplication.CreateBuilder(args);

// --- Observability ---
// (Phase 2: Serilog structured logging)

// --- Security ---
// (Phase 4: Identity + Google OAuth + JWT Bearer)

// --- Data ---
// (Phase 3: EF Core + SQLite)

// --- API ---
builder.Services.AddControllers();
builder.Services.AddAppExceptionHandling();

var app = builder.Build();

// --- Middleware Pipeline ---
app.UseAppExceptionHandling();   // Must be first
app.UseHttpsRedirection();

// (Phase 2: app.UseSerilogRequestLogging())
// (Phase 4: app.UseAuthentication(), app.UseAuthorization())

app.MapControllers();

app.Run();
```

### Pattern 5: Class Library with ASP.NET Core FrameworkReference

**What:** Module class libraries that need ASP.NET Core types (IExceptionHandler, IApplicationBuilder, WebApplication, etc.) use `<FrameworkReference Include="Microsoft.AspNetCore.App" />` instead of individual NuGet packages.

**When to use:** Any module class library that references ASP.NET Core types.

**Example .csproj:**

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Starter.Shared\Starter.Shared.csproj" />
  </ItemGroup>

</Project>
```

**Why not `Microsoft.NET.Sdk.Web`?** Module class libraries are NOT web applications. They should use `Microsoft.NET.Sdk` (plain class library SDK) and add a `FrameworkReference` to `Microsoft.AspNetCore.App` to access ASP.NET Core types without pulling in the web host.

### Anti-Patterns to Avoid

- **Shared project as dumping ground:** Starter.Shared must contain ONLY contracts (exceptions, interfaces, constants). No services, utilities, or business logic.
- **Module-to-module references:** Starter.ExceptionHandling must reference ONLY Starter.Shared. Never reference another module.
- **Hiding middleware in AddApp*:** Extension methods on `IServiceCollection` register services only. Middleware insertion (`app.Use*()`) must be a separate `UseApp*` extension method on `WebApplication`. Never hide middleware inside service registration.
- **Public types by default:** Module internal types (handlers, services) must be `internal`. Only extension method classes and contracts (in Shared) are `public`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global exception handling | Custom middleware with try/catch | `IExceptionHandler` + `AddExceptionHandler<T>()` + `UseExceptionHandler()` | Built-in since .NET 8. Integrates with ProblemDetails natively. Supports multiple handlers in chain. |
| RFC 7807 Problem Details | Custom error response shape | `AddProblemDetails()` + `ProblemDetails` class | Built-in. `CustomizeProblemDetails` callback adds extensions (traceId). Standard response format. |
| Configuration validation | Custom startup checks | `ValidateDataAnnotations()` + `ValidateOnStart()` on `OptionsBuilder<T>` | Built-in. Throws `OptionsValidationException` with clear message at startup. |
| Solution file | Manual XML editing | `dotnet new sln` + `dotnet sln add` CLI | .NET 10 generates SLNX format by default. CLI handles solution folders correctly. |
| Project references | Manual .csproj editing | `dotnet add reference` CLI | Cleaner, less error-prone. |

**Key insight:** Phase 1 requires ZERO external NuGet packages. Everything (IExceptionHandler, ProblemDetails, IOptions validation, project scaffolding) is built into .NET 10 / ASP.NET Core 10.

## Common Pitfalls

### Pitfall 1: UseExceptionHandler() Not First in Pipeline

**What goes wrong:** If exception handler middleware is not the first middleware, exceptions thrown by earlier middleware are not caught. The app crashes or returns non-ProblemDetails error responses.
**Why it happens:** Developers add middleware in logical order rather than exception-safety order.
**How to avoid:** `app.UseAppExceptionHandling()` (which calls `app.UseExceptionHandler()`) MUST be the first middleware call after `app.Build()`.
**Warning signs:** Non-JSON error responses, 500 errors without ProblemDetails shape, unlogged exceptions.

### Pitfall 2: IOptions Without ValidateOnStart Silently Binds Defaults

**What goes wrong:** Missing or misnamed appsettings.json sections cause all option properties to have default/null values. No error at startup. Failure occurs at runtime when code accesses a null property.
**Why it happens:** `IOptions<T>` is lazy by default. Configuration binding is case-insensitive for property names but section names must match exactly.
**How to avoid:** ALWAYS chain `.ValidateDataAnnotations().ValidateOnStart()`. Add `[Required]` to properties that must have values. Test by intentionally removing config sections.
**Warning signs:** Properties are null/default at runtime. Tests pass with in-memory configuration but production fails.

### Pitfall 3: Module Class Library Using Wrong SDK

**What goes wrong:** Using `Microsoft.NET.Sdk.Web` for a class library creates a project that tries to be a web application. Using `Microsoft.NET.Sdk` without `FrameworkReference` means ASP.NET Core types like `IExceptionHandler`, `WebApplication`, etc. are unavailable.
**Why it happens:** Developers are used to web projects and copy the SDK attribute.
**How to avoid:** Module class libraries use `Microsoft.NET.Sdk` + `<FrameworkReference Include="Microsoft.AspNetCore.App" />`. Only the Host project uses `Microsoft.NET.Sdk.Web`.
**Warning signs:** Build errors about missing types, or class library producing an executable.

### Pitfall 4: Custom Exceptions in Module Instead of Shared

**What goes wrong:** If `NotFoundException` lives in Starter.ExceptionHandling, other modules cannot throw it without referencing the ExceptionHandling module, creating module-to-module coupling.
**Why it happens:** Developers co-locate exception types with the handler.
**How to avoid:** Custom exception types MUST live in Starter.Shared. The handler in Starter.ExceptionHandling catches exceptions defined in Starter.Shared.
**Warning signs:** Module A referencing Module B just for an exception type.

### Pitfall 5: .NET 10 SLNX vs SLN Confusion

**What goes wrong:** `dotnet new sln` in .NET 10 creates `.slnx` (XML format), not `.sln` (legacy format). Existing tooling or scripts expecting `.sln` break.
**Why it happens:** Breaking change in .NET 10 SDK. Default format switched.
**How to avoid:** Use `.slnx` (the new default). It is fully supported by Visual Studio 2022 17.13+, Rider 2024.3+, and VS Code C# Dev Kit. The CONTEXT.md says "Starter.WebApi.sln" but the actual file will be `Starter.WebApi.slnx`.
**Warning signs:** `dotnet sln` commands failing because they look for `.sln` when `.slnx` exists.

### Pitfall 6: .NET 10 SuppressDiagnosticsCallback Default Change

**What goes wrong:** In .NET 10, diagnostics (logs, metrics) are suppressed by default when an IExceptionHandler returns `true`. This means handled exceptions might not appear in logs.
**Why it happens:** New default behavior in .NET 10 -- differs from .NET 8/9 which always emitted diagnostics.
**How to avoid:** Log explicitly inside the IExceptionHandler's TryHandleAsync BEFORE returning true. The handler's own `logger.LogError()` call fires before the suppression takes effect. Alternatively, configure `SuppressDiagnosticsCallback` to `false` on `ExceptionHandlerOptions`.
**Warning signs:** Handled exceptions not appearing in log output.

## Code Examples

### Custom Exception Type Hierarchy (Starter.Shared)

```csharp
// Starter.Shared/Exceptions/AppException.cs
namespace Starter.Shared.Exceptions;

/// <summary>
/// Base exception for all application-specific exceptions.
/// Provides a consistent base for typed exception mapping in the global handler.
/// </summary>
public abstract class AppException(string message, Exception? innerException = null)
    : Exception(message, innerException);

// Starter.Shared/Exceptions/NotFoundException.cs
namespace Starter.Shared.Exceptions;

public sealed class NotFoundException(string message)
    : AppException(message);

// Starter.Shared/Exceptions/AppValidationException.cs
namespace Starter.Shared.Exceptions;

public sealed class AppValidationException : AppException
{
    public IDictionary<string, string[]> Errors { get; }

    public AppValidationException(IDictionary<string, string[]> errors)
        : base("One or more validation errors occurred.")
    {
        Errors = errors;
    }
}

// Starter.Shared/Exceptions/ConflictException.cs
namespace Starter.Shared.Exceptions;

public sealed class ConflictException(string message)
    : AppException(message);

// Starter.Shared/Exceptions/UnauthorizedException.cs
namespace Starter.Shared.Exceptions;

public sealed class UnauthorizedException(string message = "Authentication is required.")
    : AppException(message);

// Starter.Shared/Exceptions/ForbiddenException.cs
namespace Starter.Shared.Exceptions;

public sealed class ForbiddenException(string message = "You do not have permission to perform this action.")
    : AppException(message);
```

**Rationale for exception selection:** These five cover the most common API error scenarios (not found, validation failure, conflict/duplicate, unauthenticated, unauthorized). Additional types can be added to Starter.Shared as needed in future phases.

### Starter.Shared .csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

</Project>
```

**Note:** Starter.Shared intentionally has NO package references and NO project references. It depends on nothing. For Phase 1, it only contains exception types. Future phases add interfaces and constants as needed. The `Microsoft.Extensions.Options` package (for option base types) is already included via the .NET SDK implicit references.

### Starter.ExceptionHandling .csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Starter.Shared\Starter.Shared.csproj" />
  </ItemGroup>

</Project>
```

### ProblemDetails Response Shape

The extended ProblemDetails shape for this project (per user decision):

```json
{
  "type": "https://httpstatuses.io/404",
  "title": "Not Found",
  "status": 404,
  "detail": "Entity with ID 42 was not found.",
  "instance": "GET /api/v1/items/42",
  "traceId": "00-abc123def456-789-00",
  "errors": null
}
```

For validation errors:

```json
{
  "type": "https://httpstatuses.io/422",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more validation errors occurred.",
  "instance": "POST /api/v1/items",
  "traceId": "00-abc123def456-789-00",
  "errors": {
    "Name": ["Name is required."],
    "Price": ["Price must be greater than zero."]
  }
}
```

For unhandled exceptions in Development:

```json
{
  "type": "https://httpstatuses.io/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "Object reference not set to an instance of an object.",
  "instance": "GET /api/v1/items",
  "traceId": "00-abc123def456-789-00",
  "stackTrace": "   at Starter.WebApi.Controllers.ItemsController.Get() in ..."
}
```

### Solution Scaffolding CLI Commands

```bash
# Create solution (SLNX format is default in .NET 10)
dotnet new sln --name Starter.WebApi --output src

# Create Host project
dotnet new webapi --name Starter.WebApi --output src/Starter.WebApi --no-openapi

# Create Shared class library
dotnet new classlib --name Starter.Shared --output src/Starter.Shared

# Create ExceptionHandling module class library
dotnet new classlib --name Starter.ExceptionHandling --output src/Starter.ExceptionHandling

# Add projects to solution with solution folders
dotnet sln src/Starter.WebApi.slnx add src/Starter.WebApi/Starter.WebApi.csproj --solution-folder Host
dotnet sln src/Starter.WebApi.slnx add src/Starter.Shared/Starter.Shared.csproj --solution-folder Libraries
dotnet sln src/Starter.WebApi.slnx add src/Starter.ExceptionHandling/Starter.ExceptionHandling.csproj --solution-folder Modules

# Add project references
dotnet add src/Starter.WebApi/Starter.WebApi.csproj reference src/Starter.Shared/Starter.Shared.csproj
dotnet add src/Starter.WebApi/Starter.WebApi.csproj reference src/Starter.ExceptionHandling/Starter.ExceptionHandling.csproj
dotnet add src/Starter.ExceptionHandling/Starter.ExceptionHandling.csproj reference src/Starter.Shared/Starter.Shared.csproj
```

**Important:** The `dotnet new webapi` template in .NET 10 generates a minimal API project by default (no Controllers folder). Since the project uses controllers, the generated Program.cs will need modification to add `builder.Services.AddControllers()` and `app.MapControllers()`. Alternatively, use `--use-controllers` flag if available.

### appsettings.json Structure (Phase 1)

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",

  "ExceptionHandling": {
    "IncludeStackTraceInDevelopment": true
  }
}
```

**Section naming convention:** Top-level keys matching the module name. Nested keys for sub-concerns (e.g., `"Auth": { "Jwt": {...}, "Google": {...} }` in future phases).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom exception middleware | `IExceptionHandler` interface | .NET 8 (Nov 2023) | Built-in, chainable, integrates with ProblemDetails |
| `app.UseExceptionHandler("/Error")` with error page | `app.UseExceptionHandler()` with IExceptionHandler | .NET 8 | No error endpoint needed; handler writes response directly |
| `services.Configure<T>(config.GetSection("X"))` | `services.AddOptions<T>().BindConfiguration("X").ValidateDataAnnotations().ValidateOnStart()` | .NET 6 (Nov 2021) | Eager validation, compile-time safety with source generators |
| `.sln` solution format | `.slnx` solution format | .NET 10 SDK (Nov 2025) | XML-based, simpler, all major IDEs support it |
| Diagnostics always emitted for handled exceptions | Diagnostics suppressed by default for handled exceptions | .NET 10 | Must log explicitly in handler before returning true |

**Deprecated/outdated:**
- `UseExceptionHandler("/Error")` with a controller action: replaced by IExceptionHandler pipeline
- `services.Configure<T>()` without ValidateOnStart: still works but should never be used (silent failures)
- `.sln` format: still supported but `.slnx` is the new default

## Open Questions

1. **Sample controller for Phase 1 testing (Claude's Discretion)**
   - What we know: Phase 1 needs a way to verify the exception handling works. A minimal controller that throws test exceptions would prove the pipeline.
   - What's unclear: Whether to include a permanent test/sample controller or rely on integration tests in Phase 6.
   - Recommendation: Include a minimal `DiagnosticsController` (or similar) in the Host project that exposes endpoints to trigger each exception type. Mark it as Development-only or remove it in Phase 6. This gives immediate feedback during development without waiting for the test phase.

2. **Solution file location**
   - What we know: The existing repo has `TemplateWebApi/TemplateWebApi.slnx` in a subdirectory. The project research references `src/` layout.
   - What's unclear: Whether the `.slnx` should be at repo root or inside `src/`.
   - Recommendation: Place `Starter.WebApi.slnx` at the repository root (standard convention). Projects live under `src/` and `tests/` subdirectories.

3. **Existing TemplateWebApi cleanup**
   - What we know: The repo contains a TemplateWebApi directory with a default .NET 10 webapi template.
   - What's unclear: Whether to delete it outright or migrate it.
   - Recommendation: Delete the TemplateWebApi directory entirely. Phase 1 creates the correct structure from scratch.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | xunit.v3 3.2.2 (per stack research) |
| Config file | none -- Wave 0 in Phase 6 |
| Quick run command | `dotnet test --filter "Category=Phase1"` |
| Full suite command | `dotnet test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | Shared project contains only contracts | architectural | `dotnet build src/Starter.Shared/Starter.Shared.csproj` (compile check) | N/A -- structural |
| FOUND-02 | Host references only needed modules | architectural | Inspect .csproj references | N/A -- structural |
| FOUND-03 | Module exposes AddApp*/UseApp* extension methods | unit | Verify extension method exists and registers services | Phase 6 |
| FOUND-04 | Program.cs has grouped-by-concern layout | manual-only | Visual inspection of Program.cs | N/A |
| FOUND-05 | Removing module causes no build errors | smoke | Remove reference + calls, `dotnet build` | Phase 6 |
| FOUND-06 | No module-to-module references | architectural | NetArchTest or .csproj inspection | Phase 6 |
| FOUND-07 | Internal visibility by default | architectural | NetArchTest check for public types | Phase 6 |
| CONF-01 | Module owns config section via IOptions<T> | integration | Start app, verify options bound | Phase 6 |
| CONF-02 | ValidateOnStart catches misconfiguration | integration | Remove config section, verify startup failure | Phase 6 |
| CONF-03 | Config guidance documented | manual-only | Review appsettings comments | N/A |
| EXCP-01 | Global exception handling catches all unhandled | integration | Throw exception, verify ProblemDetails response | Phase 6 |
| EXCP-02 | Error responses use RFC 7807 | integration | Check response Content-Type and shape | Phase 6 |
| EXCP-03 | Stack traces in Dev, hidden in Prod | integration | Check response in both environments | Phase 6 |
| EXCP-04 | Exceptions logged | integration | Check log output contains exception | Phase 6 |
| EXCP-05 | Uses IExceptionHandler | architectural | Verify no custom middleware, DI registration present | N/A -- structural |

### Sampling Rate
- **Per task commit:** `dotnet build` + `dotnet run` (verify compilation and startup)
- **Per wave merge:** `dotnet build` + manual smoke test (hit endpoints, verify ProblemDetails)
- **Phase gate:** Build succeeds, app starts, exception endpoints return correct ProblemDetails shapes

### Wave 0 Gaps
- Test projects are not created until Phase 6
- Phase 1 validation is primarily build-success + manual verification via sample controller
- The sample/diagnostics controller serves as a manual testing tool until automated tests exist

## Sources

### Primary (HIGH confidence)
- [Handle errors in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-10.0) - IExceptionHandler, ProblemDetails, UseExceptionHandler, .NET 10 SuppressDiagnosticsCallback
- [Handle errors in ASP.NET Core APIs - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0) - API-specific error handling
- [Options pattern in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/options?view=aspnetcore-10.0) - OptionsBuilder, ValidateDataAnnotations, ValidateOnStart
- [dotnet sln command - .NET CLI - Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-sln) - Solution management, --solution-folder, SLNX support
- [Breaking change: dotnet new sln defaults to SLNX - Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/compatibility/sdk/10.0/dotnet-new-sln-slnx-default) - .NET 10 SLNX default
- [Compile-time options validation source generation - Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-validation-generator) - OptionsValidator attribute

### Secondary (MEDIUM confidence)
- [Global Error Handling in ASP.NET Core 8 - Milan Jovanovic](https://www.milanjovanovic.tech/blog/global-error-handling-in-aspnetcore-8) - Typed exception handler implementation pattern
- [Problem Details for ASP.NET Core APIs - Milan Jovanovic](https://www.milanjovanovic.tech/blog/problem-details-for-aspnetcore-apis) - ProblemDetails customization patterns
- [Adding Validation To The Options Pattern - Milan Jovanovic](https://www.milanjovanovic.tech/blog/adding-validation-to-the-options-pattern-in-asp-net-core) - Options validation patterns
- [Global Exception Handling - codewithmukesh](https://codewithmukesh.com/blog/global-exception-handling-in-aspnet-core/) - IExceptionHandler patterns for .NET 10
- [Options Pattern in ASP.NET Core .NET 10 - codewithmukesh](https://codewithmukesh.com/blog/options-pattern-in-aspnet-core/) - .NET 10 options pattern guide

### Tertiary (LOW confidence)
- None -- all findings verified against primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in framework features, verified against Microsoft Learn docs
- Architecture: HIGH - Extension method composition pattern verified via multiple sources, SLNX format verified
- Pitfalls: HIGH - IOptions ValidateOnStart, middleware ordering, FrameworkReference all verified via official docs
- Code examples: HIGH - Derived from official documentation patterns, adapted to project conventions

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (stable -- all patterns are built-in .NET 10 features unlikely to change)
