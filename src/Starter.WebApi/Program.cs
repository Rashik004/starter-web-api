using Serilog;
using Starter.Auth.Google;
using Starter.Auth.Identity;
using Starter.Auth.Jwt;
using Starter.Auth.Shared;
using Starter.Cors;
using Starter.Data;
using Starter.ExceptionHandling;
using Starter.Logging;
using Starter.OpenApi;
using Starter.Validation;
using Starter.Versioning;

// --- Bootstrap Logger ---
// Lightweight logger for startup and crash capture.
// Replaced by the full Serilog pipeline once AddAppLogging() runs.
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Log.Information("Starting application");

    var builder = WebApplication.CreateBuilder(args);

    // --- Observability ---
    builder.AddAppLogging();

    // --- Security ---
    builder.AddAppAuthShared();    // PolicyScheme + ForwardDefaultSelector
    builder.AddAppIdentity();      // ASP.NET Identity with EF Core stores
    builder.AddAppJwt();           // JWT Bearer validation + token service
    builder.AddAppGoogle();        // Google OAuth (no-op when credentials absent)

    // --- Data ---
    builder.AddAppData();

    // --- API ---
    builder.AddAppCors();          // CORS policies from config
    builder.AddAppOpenApi();       // OpenAPI 3.1 documents + Scalar UI
    builder.Services.AddAppVersioning();  // API versioning (URL segment)
    builder.Services.AddAppValidation();  // FluentValidation
    builder.Services.AddControllers();
    builder.Services.AddAppExceptionHandling();

    var app = builder.Build();

    // --- Middleware Pipeline ---
    app.UseAppExceptionHandling(); // Must be first
    app.UseHttpsRedirection();
    app.UseAppRequestLogging();    // After exception handler and HTTPS redirect
    app.UseAppData();              // Auto-migrate if configured

    app.UseCors();                 // After routing (implicit), before auth
    app.UseAuthentication();
    app.UseAuthorization();

    app.UseAppOpenApi();           // MapOpenApi + MapScalarApiReference

    app.MapControllers();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
