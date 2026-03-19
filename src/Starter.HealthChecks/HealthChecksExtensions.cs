using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Starter.HealthChecks.Options;

namespace Starter.HealthChecks;

public static class HealthChecksExtensions
{
    /// <summary>
    /// Registers health checks including database connectivity and external service probes.
    /// </summary>
    public static WebApplicationBuilder AddAppHealthChecks(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<HealthCheckModuleOptions>()
            .BindConfiguration(HealthCheckModuleOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        builder.Services.AddHttpClient();

        builder.Services.AddHealthChecks()
            .AddDbContextCheck<Starter.Data.AppDbContext>(
                name: "database",
                tags: new[] { "ready" })
            .AddCheck<Checks.ExternalServiceHealthCheck>(
                name: "external-service",
                tags: new[] { "ready" });

        return builder;
    }

    /// <summary>
    /// Maps health check endpoints: /health (aggregate), /health/ready (readiness), /health/live (liveness).
    /// </summary>
    public static WebApplication UseAppHealthChecks(this WebApplication app)
    {
        app.MapHealthChecks("/health", new HealthCheckOptions
        {
            ResponseWriter = WriteResponse
        });

        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = check => check.Tags.Contains("ready"),
            ResponseWriter = WriteResponse
        });

        app.MapHealthChecks("/health/live", new HealthCheckOptions
        {
            Predicate = _ => false,
            ResponseWriter = WriteResponse
        });

        return app;
    }

    private static Task WriteResponse(HttpContext context, HealthReport report)
    {
        context.Response.ContentType = "application/json; charset=utf-8";

        var options = new JsonWriterOptions { Indented = true };

        using var memoryStream = new MemoryStream();
        using (var jsonWriter = new Utf8JsonWriter(memoryStream, options))
        {
            jsonWriter.WriteStartObject();
            jsonWriter.WriteString("status", report.Status.ToString());
            jsonWriter.WriteString("totalDuration", report.TotalDuration.ToString());
            jsonWriter.WriteStartObject("results");

            foreach (var entry in report.Entries)
            {
                jsonWriter.WriteStartObject(entry.Key);
                jsonWriter.WriteString("status", entry.Value.Status.ToString());
                jsonWriter.WriteString("description", entry.Value.Description);
                jsonWriter.WriteString("duration", entry.Value.Duration.ToString());

                if (entry.Value.Exception is not null)
                {
                    jsonWriter.WriteString("exception", entry.Value.Exception.Message);
                }

                jsonWriter.WriteEndObject();
            }

            jsonWriter.WriteEndObject();
            jsonWriter.WriteEndObject();
        }

        return context.Response.WriteAsync(
            Encoding.UTF8.GetString(memoryStream.ToArray()));
    }
}
