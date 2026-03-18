using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Serilog;
using Starter.Logging.Configuration;

namespace Starter.Logging;

/// <summary>
/// Extension methods for registering Serilog structured logging and request logging middleware.
/// </summary>
public static class LoggingExtensions
{
    /// <summary>
    /// Registers Serilog as the logging provider with configurable sinks.
    /// Uses hybrid configuration: <c>ReadFrom.Configuration</c> for MinimumLevel, Enrichers,
    /// and Properties; custom <see cref="SinkRegistrar"/> for sink registration with Enabled flags.
    /// </summary>
    /// <param name="builder">The web application builder.</param>
    /// <returns>The builder for fluent chaining.</returns>
    public static WebApplicationBuilder AddAppLogging(
        this WebApplicationBuilder builder)
    {
        builder.Services.AddSerilog((services, loggerConfig) =>
        {
            loggerConfig
                .ReadFrom.Configuration(builder.Configuration) // MinimumLevel, Enrichers, Properties
                .ReadFrom.Services(services)                    // DI-aware enrichers
                .ConfigureSinks(builder.Configuration);         // Custom Enabled-flag sinks

            Log.Information("Switching from bootstrap to full Serilog pipeline");
        });

        return builder;
    }

    /// <summary>
    /// Adds Serilog request logging middleware with health check exclusion,
    /// dynamic log levels by HTTP status code, and configurable per-request enrichment.
    /// </summary>
    /// <param name="app">The web application.</param>
    /// <returns>The application for fluent chaining.</returns>
    public static WebApplication UseAppRequestLogging(this WebApplication app)
    {
        // Stub -- full implementation in Task 3
        return app;
    }
}
