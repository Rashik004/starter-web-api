# Technology Stack

**Project:** Starter.WebApi -- Modular .NET 10 Web API Starter Repository
**Researched:** 2026-03-18
**Overall Confidence:** HIGH

---

## Recommended Stack

### Runtime & Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| .NET 10 | 10.0 (LTS) | Runtime and SDK | LTS release (Nov 2025 -- Nov 2028). Three years of support. All first-party packages target net10.0. Latest servicing: 10.0.5 SDK (Mar 2026). | HIGH |
| ASP.NET Core 10 | 10.0 | Web API framework | Ships with .NET 10. Built-in OpenAPI 3.1 generation, built-in rate limiting, built-in validation for Minimal APIs, Server-Sent Events support, passkey auth. | HIGH |

### Authentication & Authorization

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | 10.0.4 | Identity store (users, roles, claims) | First-party. EF Core-backed user store with password hashing, lockout, two-factor. Ships with .NET 10. New passkey/WebAuthn support in v10. | HIGH |
| Microsoft.AspNetCore.Authentication.Google | 10.0.3 | Google OAuth 2.0 external login | First-party middleware. Zero-config OAuth 2.0 flow. Drop-in with Identity. | HIGH |
| Microsoft.AspNetCore.Authentication.JwtBearer | 10.0.5 | JWT Bearer token validation | First-party. Validates JWT tokens for API authentication. Pairs with Identity for token issuance. | HIGH |

### Logging & Observability

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Serilog.AspNetCore | 10.0.0 | Structured logging pipeline | Industry standard. Version tracks .NET major version. Replaces built-in logging with structured events, request logging middleware, enrichers. | HIGH |
| Serilog | 4.3.1 | Core logging library | Foundation for all Serilog sinks and enrichers. | HIGH |
| Serilog.Settings.Configuration | 10.0.0 | appsettings.json-driven log config | Reads Serilog config from `IConfiguration` sources. Required for the IOptions pattern -- all sink config lives in appsettings.json. | HIGH |
| Serilog.Sinks.Console | 6.1.1 | Console output | Dev-time visibility. Colored, structured output. | HIGH |
| Serilog.Sinks.File | 7.0.0 | File output with rolling | Production file logging with size/time-based rolling. Zero-infrastructure fallback. | HIGH |
| Serilog.Sinks.Seq | 9.0.0 | Seq structured log server | Best-in-class structured log viewer. Free single-user license. Superior to App Insights for local dev. | HIGH |
| Serilog.Sinks.OpenTelemetry | latest | OpenTelemetry export (incl. App Insights) | Forward path for Azure Monitor / App Insights. The classic `Serilog.Sinks.ApplicationInsights` depends on the deprecated Application Insights SDK. Use `Serilog.Sinks.OpenTelemetry` for Azure Monitor via OTLP instead. | MEDIUM |

**Note on App Insights sink:** `Serilog.Sinks.ApplicationInsights` (v5.0.0) still works but depends on the legacy Application Insights SDK. Microsoft is migrating to Azure Monitor OpenTelemetry. For new projects, prefer `Serilog.Sinks.OpenTelemetry` which exports via OTLP and can target App Insights, Seq, Jaeger, or any OTLP-compatible backend. Include the classic sink only as an optional backward-compatibility path.

### Database & ORM

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Microsoft.EntityFrameworkCore | 10.0.5 | ORM / data access | First-party. LTS aligned with .NET 10. New in EF 10: LeftJoin/RightJoin LINQ, improved bulk updates, named query filters, vector type support. | HIGH |
| Microsoft.EntityFrameworkCore.Sqlite | 10.0.5 | SQLite provider (dev default) | Zero-config local development. No server install. File-based DB ships with the project. | HIGH |
| Microsoft.EntityFrameworkCore.SqlServer | 10.0.3 | SQL Server provider (prod option) | First-party. Swap target for production Azure SQL / SQL Server deployments. | HIGH |
| Npgsql.EntityFrameworkCore.PostgreSQL | 10.0.1 | PostgreSQL provider (prod option) | Mature, well-maintained community provider. Swap target for PostgreSQL deployments. EF 10 JSON complex type mapping support. | HIGH |
| Microsoft.EntityFrameworkCore.Design | 10.0.3 | Design-time EF tooling | Required for `dotnet ef migrations` CLI commands. | HIGH |
| Microsoft.EntityFrameworkCore.Tools | 10.0.5 | VS Package Manager Console tooling | PowerShell commands for migrations in Visual Studio PMC. | HIGH |

### API Documentation (OpenAPI)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Microsoft.AspNetCore.OpenApi | 10.0.5 | OpenAPI document generation | First-party. Generates OpenAPI 3.1 documents natively. Supports both controllers and Minimal APIs. Transformer APIs for customization. AOT compatible. Replaces Swashbuckle as the document generator. | HIGH |
| Scalar.AspNetCore | 1.2.5 | Interactive API documentation UI | Microsoft-recommended replacement for Swagger UI. Modern UI, better DX, full-text search, auto-generated examples, faster rendering. Default in .NET 9+ templates. Maps to `/scalar/v1` endpoint. | HIGH |

**Why not Swashbuckle?** Swashbuckle.AspNetCore (10.1.5) still works, but Microsoft removed it from templates in .NET 9 and recommends the native `Microsoft.AspNetCore.OpenApi` + Scalar pattern instead. The native approach generates OpenAPI 3.1, integrates with ASP.NET Core's type system directly, and supports AOT. Swashbuckle is a valid fallback if you need Swagger UI specifically, but Scalar is the forward path.

### API Versioning

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Asp.Versioning.Mvc | 8.1.1 | Controller-based API versioning | Official `dotnet/aspnet-api-versioning` library. Supports URL segment, header, and query string versioning for controllers. Stable release, .NET 10 compatible. | HIGH |
| Asp.Versioning.Mvc.ApiExplorer | 8.1.1 | Version-aware OpenAPI integration | Bridges API versioning with OpenAPI document generation. Required to show versioned endpoints in Scalar/Swagger. | HIGH |

**Note:** A 10.0.0-preview.1 exists but is not yet stable. Use 8.1.1 for production. It targets .NET Standard 2.0+ and works on .NET 10.

### Validation

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| FluentValidation | 12.1.1 | Complex request validation | Expressive fluent rule syntax, testable validators, separation of concerns. Supports async rules, cross-field validation, conditional logic. | HIGH |
| FluentValidation.DependencyInjectionExtensions | 12.1.1 | DI auto-registration of validators | Assembly-scanning validator registration via `AddValidatorsFromAssembly()`. Required since `FluentValidation.AspNetCore` is deprecated in v12. | HIGH |

**Critical migration note:** `FluentValidation.AspNetCore` (v11.3.x) is **deprecated** and removed in v12. The auto-validation MVC pipeline no longer exists. Two approaches for .NET 10:

1. **Manual validation (recommended for controllers):** Inject `IValidator<T>` and call `ValidateAsync()` explicitly. Return `ValidationProblem()` on failure for RFC 7807 Problem Details.
2. **Endpoint filter (for Minimal APIs):** Create a reusable `IEndpointFilter` that auto-validates before the handler runs.

This project uses controllers, so manual validation with a shared base controller method or action filter is the cleanest pattern.

**What about ASP.NET Core 10 built-in validation?** .NET 10 added `builder.Services.AddValidation()` with source-generated DataAnnotations validation for Minimal APIs. It is limited to simple attribute-based rules and does not replace FluentValidation for complex scenarios. The two can coexist: use DataAnnotations for trivial constraints and FluentValidation for business rules.

### Rate Limiting

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Built-in `Microsoft.AspNetCore.RateLimiting` | Ships with ASP.NET Core 10 | Rate limiting middleware | First-party. No NuGet needed. Supports Fixed Window, Sliding Window, Token Bucket, and Concurrency limiters. Configurable per-endpoint or globally. Returns 429 Too Many Requests. | HIGH |

**Why not `AspNetCoreRateLimit`?** The third-party `AspNetCoreRateLimit` package was the standard before .NET 7. Since .NET 7+, the built-in middleware is superior: first-party support, tighter integration, no external dependency. Use `AddRateLimiter()` + `UseRateLimiter()` with named policies driven by `IOptions<T>` from appsettings.

### Caching

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Built-in `IMemoryCache` | Ships with ASP.NET Core 10 | In-memory caching | First-party. `AddMemoryCache()` registers `IMemoryCache`. Zero-config for single-server scenarios. | HIGH |
| Built-in `IDistributedCache` | Ships with ASP.NET Core 10 | Distributed cache abstraction | First-party interface. Default implementation is in-memory. Swap to Redis/SQL Server for multi-server. | HIGH |

No external packages needed. The built-in abstractions are sufficient. For Redis in production, add `Microsoft.Extensions.Caching.StackExchangeRedis` when needed.

### Health Checks

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Built-in `Microsoft.Extensions.Diagnostics.HealthChecks` | 10.0.2 (ships with framework) | Health check infrastructure | First-party. `AddHealthChecks()` + `MapHealthChecks()`. Supports liveness, readiness, and custom checks. | HIGH |
| AspNetCore.HealthChecks.UI.Client | 9.0.0 | JSON health check response writer | Provides `UIResponseWriter.WriteHealthCheckUIResponse` for detailed JSON output at `/health` endpoints. From the Xabaril ecosystem. | MEDIUM |

**Note:** The Xabaril `AspNetCore.HealthChecks.*` packages are at 9.0.0 (not yet 10.0.0). They run fine on .NET 10 since they target compatible TFMs. For database-specific checks (`AspNetCore.HealthChecks.SqlServer`, `AspNetCore.HealthChecks.Sqlite`, `AspNetCore.HealthChecks.NpgSql`), add as needed per provider.

### Response Compression

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Built-in `Microsoft.AspNetCore.ResponseCompression` | Ships with ASP.NET Core 10 | Gzip/Brotli response compression | First-party. `AddResponseCompression()` + `UseResponseCompression()`. Supports Gzip and Brotli providers with configurable compression levels. | HIGH |

No external packages needed.

### CORS

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Built-in ASP.NET Core CORS middleware | Ships with ASP.NET Core 10 | Cross-Origin Resource Sharing | First-party. `AddCors()` + `UseCors()`. Named policies driven by appsettings.json. | HIGH |

No external packages needed.

### Global Exception Handling

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Built-in `IExceptionHandler` | Ships with ASP.NET Core 10 | Global exception handling | First-party. `AddProblemDetails()` + `UseExceptionHandler()` + custom `IExceptionHandler` implementation. Returns RFC 7807 Problem Details. Available since .NET 8. | HIGH |

No external packages needed. The `IExceptionHandler` interface (introduced in .NET 8) is the modern replacement for custom exception middleware. It integrates with `ProblemDetails` natively.

### Testing

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| xunit.v3 | 3.2.2 | Test framework | Latest generation of xUnit. Supports .NET 10 SDK. Significant improvements over v2 in parallelism, output, and extensibility. | HIGH |
| xunit.runner.visualstudio | 3.1.5 | VS Test Explorer integration | Required for running xUnit tests in Visual Studio Test Explorer. Supports .NET 8+. | HIGH |
| Microsoft.AspNetCore.Mvc.Testing | 10.0.4 | Integration testing with WebApplicationFactory | First-party. In-memory test server for integration tests. Supports service replacement, auth overrides, configuration overrides. | HIGH |
| NSubstitute | 5.3.0 | Mocking library | Cleaner syntax than Moq (`Returns()` directly on calls vs. `Setup().Returns()`). No SponsorLink controversy. Growing community adoption for new projects. | HIGH |
| NSubstitute.Analyzers.CSharp | 1.0.17 | Static analysis for NSubstitute | Catches common NSubstitute misuse at compile time. Essential safety net. | HIGH |
| AwesomeAssertions | 9.4.0 | Fluent assertion library | Community fork of FluentAssertions under Apache 2.0. Same API as FluentAssertions 7.x but actively maintained and evolved (now at 9.4.0). No commercial license required. Drop-in replacement for FluentAssertions. | HIGH |

**Why NSubstitute over Moq?** Moq's SponsorLink controversy (2023) eroded trust. NSubstitute has cleaner, more readable syntax and is the growing default for new .NET projects. For a personal starter repo, the simpler API reduces ceremony.

**Why AwesomeAssertions over FluentAssertions?** FluentAssertions 8+ requires a $129.95/dev/year commercial license (Xceed partnership, Jan 2025). AwesomeAssertions is the community-maintained Apache 2.0 fork that preserves the same fluent API. It is actively developed (v9.4.0 as of early 2026) and has no licensing risk. For a personal starter template that might be used commercially, this avoids a licensing landmine.

**Why not Shouldly?** Shouldly is fine but lacks `BeEquivalentTo()` for deep object comparison, which is heavily used in API integration tests. AwesomeAssertions preserves that capability.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Logging | Serilog | NLog | Serilog has better structured logging, richer sink ecosystem, and `Serilog.AspNetCore` tracks .NET major versions. NLog is solid but Serilog is the .NET community default. |
| Logging | Serilog | Built-in ILogger only | Built-in logging lacks structured enrichment, sink routing, and the appsettings-driven pipeline that Serilog provides. |
| OpenAPI UI | Scalar | Swagger UI (Swashbuckle) | Swashbuckle is no longer in default templates. Scalar is Microsoft-recommended, faster, modern UI. Swashbuckle still works but is the legacy path. |
| OpenAPI Generation | Microsoft.AspNetCore.OpenApi | Swashbuckle doc gen | First-party is better integrated, supports OpenAPI 3.1, AOT-compatible. Swashbuckle adds a third-party dependency for something now built-in. |
| Validation | FluentValidation 12 | DataAnnotations only | DataAnnotations are limited to simple attribute rules. FluentValidation enables testable, composable, complex business validation. |
| Validation | FluentValidation 12 | ASP.NET Core 10 AddValidation() | Built-in validation is DataAnnotations-only and Minimal API-focused. Does not support the expressive rule builder or cross-field validation that FluentValidation provides. |
| Rate Limiting | Built-in middleware | AspNetCoreRateLimit | Third-party package is legacy. Built-in (since .NET 7) is first-party, better integrated, actively maintained by Microsoft. |
| Mocking | NSubstitute | Moq | SponsorLink trust erosion. NSubstitute has simpler API. Both are capable, but NSubstitute is the safer community default for new projects. |
| Mocking | NSubstitute | FakeItEasy | FakeItEasy is solid but smaller community. NSubstitute has broader adoption and better analyzer tooling. |
| Assertions | AwesomeAssertions | FluentAssertions 8+ | Commercial license ($130/dev/year). Unnecessary cost for a personal starter template. |
| Assertions | AwesomeAssertions | Shouldly | Lacks `BeEquivalentTo()` for deep comparison. Less expressive for complex object assertions. |
| Assertions | AwesomeAssertions | FluentAssertions 7.x (pinned) | Stuck on old version. AwesomeAssertions actively evolves the same API under Apache 2.0. |
| Test Framework | xUnit v3 | NUnit | xUnit is the .NET community default. v3 is a significant upgrade. NUnit is solid but xUnit has broader adoption in ASP.NET Core projects. |
| DB Provider (dev) | SQLite | LocalDB / SQL Server Express | SQLite requires zero install. LocalDB requires SQL Server components. For a starter template, zero-friction matters. |
| App Insights Sink | Serilog.Sinks.OpenTelemetry | Serilog.Sinks.ApplicationInsights | Classic sink depends on deprecated Application Insights SDK. OpenTelemetry is the Microsoft-endorsed forward path. |
| Exception Handling | IExceptionHandler | Custom middleware | `IExceptionHandler` (since .NET 8) is the first-party pattern. Integrates with ProblemDetails natively. Custom middleware is the pre-.NET 8 approach. |

---

## Full Package List by Module

### Starter.WebApi (Host)

```xml
<PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.0.5" />
<PackageReference Include="Scalar.AspNetCore" Version="1.2.5" />
```

### Starter.WebApi.Auth

```xml
<PackageReference Include="Microsoft.AspNetCore.Identity.EntityFrameworkCore" Version="10.0.4" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.Google" Version="10.0.3" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.5" />
```

### Starter.WebApi.Logging

```xml
<PackageReference Include="Serilog.AspNetCore" Version="10.0.0" />
<PackageReference Include="Serilog.Settings.Configuration" Version="10.0.0" />
<PackageReference Include="Serilog.Sinks.Console" Version="6.1.1" />
<PackageReference Include="Serilog.Sinks.File" Version="7.0.0" />
<PackageReference Include="Serilog.Sinks.Seq" Version="9.0.0" />
<!-- Optional: For Azure Monitor / App Insights via OTLP -->
<!-- <PackageReference Include="Serilog.Sinks.OpenTelemetry" Version="latest" /> -->
```

### Starter.WebApi.RateLimiting

```xml
<!-- No external packages. Uses built-in Microsoft.AspNetCore.RateLimiting -->
```

### Starter.WebApi.Caching

```xml
<!-- No external packages. Uses built-in IMemoryCache / IDistributedCache -->
```

### Starter.WebApi.Data

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore" Version="10.0.5" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="10.0.5" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.3" />
<!-- Swap-in providers (add as needed): -->
<!-- <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.3" /> -->
<!-- <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="10.0.1" /> -->
```

### Starter.WebApi.HealthChecks

```xml
<!-- Core health checks are built-in. Add provider-specific checks as needed: -->
<PackageReference Include="AspNetCore.HealthChecks.UI.Client" Version="9.0.0" />
<!-- <PackageReference Include="AspNetCore.HealthChecks.Sqlite" Version="9.0.0" /> -->
<!-- <PackageReference Include="AspNetCore.HealthChecks.SqlServer" Version="9.0.0" /> -->
<!-- <PackageReference Include="AspNetCore.HealthChecks.NpgSql" Version="9.0.0" /> -->
```

### Starter.WebApi.Cors

```xml
<!-- No external packages. Uses built-in CORS middleware -->
```

### Starter.WebApi.Versioning

```xml
<PackageReference Include="Asp.Versioning.Mvc" Version="8.1.1" />
<PackageReference Include="Asp.Versioning.Mvc.ApiExplorer" Version="8.1.1" />
```

### Starter.WebApi.Validation

```xml
<PackageReference Include="FluentValidation" Version="12.1.1" />
<PackageReference Include="FluentValidation.DependencyInjectionExtensions" Version="12.1.1" />
```

### Starter.WebApi.Compression

```xml
<!-- No external packages. Uses built-in ResponseCompression middleware -->
```

### Starter.WebApi.Tests.Unit

```xml
<PackageReference Include="xunit.v3" Version="3.2.2" />
<PackageReference Include="xunit.runner.visualstudio" Version="3.1.5" />
<PackageReference Include="NSubstitute" Version="5.3.0" />
<PackageReference Include="NSubstitute.Analyzers.CSharp" Version="1.0.17" />
<PackageReference Include="AwesomeAssertions" Version="9.4.0" />
```

### Starter.WebApi.Tests.Integration

```xml
<PackageReference Include="xunit.v3" Version="3.2.2" />
<PackageReference Include="xunit.runner.visualstudio" Version="3.1.5" />
<PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.4" />
<PackageReference Include="NSubstitute" Version="5.3.0" />
<PackageReference Include="AwesomeAssertions" Version="9.4.0" />
```

---

## Installation Commands

```bash
# Host project
dotnet add package Microsoft.AspNetCore.OpenApi --version 10.0.5
dotnet add package Scalar.AspNetCore --version 1.2.5

# Auth module
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore --version 10.0.4
dotnet add package Microsoft.AspNetCore.Authentication.Google --version 10.0.3
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer --version 10.0.5

# Logging module
dotnet add package Serilog.AspNetCore --version 10.0.0
dotnet add package Serilog.Settings.Configuration --version 10.0.0
dotnet add package Serilog.Sinks.Console --version 6.1.1
dotnet add package Serilog.Sinks.File --version 7.0.0
dotnet add package Serilog.Sinks.Seq --version 9.0.0

# Data module
dotnet add package Microsoft.EntityFrameworkCore --version 10.0.5
dotnet add package Microsoft.EntityFrameworkCore.Sqlite --version 10.0.5
dotnet add package Microsoft.EntityFrameworkCore.Design --version 10.0.3

# Health checks
dotnet add package AspNetCore.HealthChecks.UI.Client --version 9.0.0

# Versioning
dotnet add package Asp.Versioning.Mvc --version 8.1.1
dotnet add package Asp.Versioning.Mvc.ApiExplorer --version 8.1.1

# Validation
dotnet add package FluentValidation --version 12.1.1
dotnet add package FluentValidation.DependencyInjectionExtensions --version 12.1.1

# EF Core CLI tools (global)
dotnet tool install --global dotnet-ef

# Unit test project
dotnet add package xunit.v3 --version 3.2.2
dotnet add package xunit.runner.visualstudio --version 3.1.5
dotnet add package NSubstitute --version 5.3.0
dotnet add package NSubstitute.Analyzers.CSharp --version 1.0.17
dotnet add package AwesomeAssertions --version 9.4.0

# Integration test project
dotnet add package Microsoft.AspNetCore.Mvc.Testing --version 10.0.4
```

---

## Key Stack Decisions Summary

1. **.NET 10 LTS** -- Latest, three-year support window, all first-party packages aligned.
2. **Scalar over Swagger UI** -- Microsoft-endorsed, modern UI, OpenAPI 3.1 native.
3. **FluentValidation 12 (manual validation)** -- The `FluentValidation.AspNetCore` auto-pipeline is dead. Manual `IValidator<T>` injection is the forward path.
4. **AwesomeAssertions over FluentAssertions** -- Same API, Apache 2.0, no commercial license risk.
5. **NSubstitute over Moq** -- Cleaner API, no trust concerns, growing adoption.
6. **xUnit v3 over v2** -- Major generation upgrade, better parallelism and output.
7. **Built-in rate limiting over AspNetCoreRateLimit** -- First-party since .NET 7, no external dependency.
8. **Serilog.Sinks.OpenTelemetry over Serilog.Sinks.ApplicationInsights** -- Forward path for Azure Monitor. Classic sink depends on deprecated SDK.
9. **IExceptionHandler over custom middleware** -- First-party pattern since .NET 8, integrates with ProblemDetails.

---

## Sources

### Official Documentation
- [What's new in ASP.NET Core 10](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0?view=aspnetcore-10.0)
- [What's new in .NET 10](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview)
- [What's new in EF Core 10](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-10.0/whatsnew)
- [ASP.NET Core Rate Limiting Middleware](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit?view=aspnetcore-10.0)
- [ASP.NET Core OpenAPI Overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/overview?view=aspnetcore-10.0)
- [ASP.NET Core Health Checks](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0)
- [FluentValidation ASP.NET Core docs](https://docs.fluentvalidation.net/en/latest/aspnet.html)
- [Announcing .NET 10](https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/)
- [Google OAuth setup in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/social/google-logins?view=aspnetcore-10.0)
- [JWT Bearer auth in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication?view=aspnetcore-10.0)
- [Azure Monitor OpenTelemetry migration](https://learn.microsoft.com/en-us/azure/azure-monitor/app/migrate-to-opentelemetry)

### NuGet Packages (verified versions)
- [Serilog.AspNetCore 10.0.0](https://www.nuget.org/packages/Serilog.AspNetCore)
- [Serilog 4.3.1](https://www.nuget.org/packages/serilog/)
- [Serilog.Settings.Configuration 10.0.0](https://www.nuget.org/packages/serilog.settings.configuration/)
- [Serilog.Sinks.Console 6.1.1](https://www.nuget.org/packages/serilog.sinks.console/)
- [Serilog.Sinks.File 7.0.0](https://www.nuget.org/packages/serilog.sinks.file/)
- [Serilog.Sinks.Seq 9.0.0](https://www.nuget.org/packages/serilog.sinks.seq)
- [Microsoft.AspNetCore.OpenApi 10.0.5](https://www.nuget.org/packages/Microsoft.AspNetCore.OpenApi)
- [Scalar.AspNetCore 1.2.5](https://www.nuget.org/packages/Scalar.AspNetCore/1.2.5)
- [Asp.Versioning.Mvc 8.1.1](https://www.nuget.org/packages/Asp.Versioning.Mvc)
- [Asp.Versioning.Mvc.ApiExplorer 8.1.1](https://www.nuget.org/packages/Asp.Versioning.Mvc.ApiExplorer)
- [FluentValidation 12.1.1](https://www.nuget.org/packages/fluentvalidation/)
- [FluentValidation.DependencyInjectionExtensions 12.1.1](https://www.nuget.org/packages/fluentvalidation.dependencyinjectionextensions/)
- [Microsoft.AspNetCore.Identity.EntityFrameworkCore 10.0.4](https://www.nuget.org/packages/Microsoft.AspNetCore.Identity.EntityFrameworkCore)
- [Microsoft.AspNetCore.Authentication.Google 10.0.3](https://www.nuget.org/packages/Microsoft.AspNetCore.Authentication.Google)
- [Microsoft.AspNetCore.Authentication.JwtBearer 10.0.5](https://www.nuget.org/packages/Microsoft.AspNetCore.Authentication.JwtBearer)
- [Microsoft.EntityFrameworkCore.Sqlite 10.0.5](https://www.nuget.org/packages/microsoft.entityframeworkcore.sqlite)
- [Microsoft.EntityFrameworkCore.SqlServer 10.0.3](https://www.nuget.org/packages/Microsoft.EntityFrameworkCore.sqlserver/)
- [Npgsql.EntityFrameworkCore.PostgreSQL 10.0.1](https://www.nuget.org/packages/npgsql.entityframeworkcore.postgresql)
- [Microsoft.EntityFrameworkCore.Design 10.0.3](https://www.nuget.org/packages/microsoft.entityframeworkcore.design/)
- [Microsoft.EntityFrameworkCore.Tools 10.0.5](https://www.nuget.org/packages/Microsoft.EntityFrameworkCore.Tools)
- [AspNetCore.HealthChecks.UI.Client 9.0.0](https://www.nuget.org/packages/AspNetCore.HealthChecks.UI.Client)
- [xunit.v3 3.2.2](https://www.nuget.org/packages/xunit.v3)
- [xunit.runner.visualstudio 3.1.5](https://www.nuget.org/packages/xunit.runner.visualstudio)
- [Microsoft.AspNetCore.Mvc.Testing 10.0.4](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing)
- [NSubstitute 5.3.0](https://www.nuget.org/packages/nsubstitute/)
- [NSubstitute.Analyzers.CSharp 1.0.17](https://www.nuget.org/packages/NSubstitute.Analyzers.CSharp)
- [AwesomeAssertions 9.4.0](https://www.nuget.org/packages/AwesomeAssertions)

### Community & Analysis
- [dotnet/aspnet-api-versioning GitHub](https://github.com/dotnet/aspnet-api-versioning)
- [Xabaril/AspNetCore.Diagnostics.HealthChecks GitHub](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks)
- [AwesomeAssertions GitHub](https://github.com/AwesomeAssertions/AwesomeAssertions)
- [FluentValidation in ASP.NET Core .NET 10 -- codewithmukesh](https://codewithmukesh.com/blog/fluentvalidation-in-aspnet-core/)
- [Scalar for ASP.NET Core](https://scalar.com/scalar/scalar-api-references/integrations/net-aspnet-core/integration)
- [ASP.NET Core Dropped Swagger -- codewithmukesh](https://codewithmukesh.com/blog/dotnet-swagger-alternatives-openapi/)
- [FluentAssertions becoming commercial discussion](https://github.com/dotnet/runtime/discussions/111495)
- [Serilog.Sinks.OpenTelemetry for App Insights](https://github.com/serilog/serilog-sinks-opentelemetry/issues/80)
