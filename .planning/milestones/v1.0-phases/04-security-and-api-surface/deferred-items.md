# Deferred Items - Phase 04

## Pre-existing Build Issues

### Starter.OpenApi Build Failure (discovered during 04-03)
- **Location:** `src/Starter.OpenApi/Transformers/BearerSecuritySchemeTransformer.cs`
- **Errors:** CS0234 (Microsoft.OpenApi.Models namespace not found), CS0246 (OpenApiDocument type not found), CS0535 (interface not implemented)
- **Impact:** Full solution build (`dotnet build Starter.WebApi.slnx`) fails. Individual project builds succeed.
- **Root cause:** Likely from plan 04-02 -- OpenApi project references may need package version alignment or missing NuGet package.
- **Not fixed:** Out of scope for plan 04-03 (auth layer modules).
