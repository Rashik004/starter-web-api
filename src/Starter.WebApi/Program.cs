using Serilog;
using Starter.ExceptionHandling;
using Starter.Logging;

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
    // (Phase 4: Identity + Google OAuth + JWT Bearer)

    // --- Data ---
    // (Phase 3: EF Core + SQLite)

    // --- API ---
    builder.Services.AddControllers();
    builder.Services.AddAppExceptionHandling();

    var app = builder.Build();

    // --- Middleware Pipeline ---
    app.UseAppExceptionHandling(); // Must be first
    app.UseHttpsRedirection();
    app.UseAppRequestLogging();    // After exception handler and HTTPS redirect

    // (Phase 4: app.UseAuthentication(), app.UseAuthorization())

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
