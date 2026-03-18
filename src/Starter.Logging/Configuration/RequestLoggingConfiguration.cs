using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;
using Serilog.Events;

namespace Starter.Logging.Configuration;

/// <summary>
/// Provides request logging configuration for Serilog's <c>UseSerilogRequestLogging</c> middleware,
/// including health check exclusion, dynamic log levels by HTTP status code,
/// and individually toggleable per-request enrichment.
/// </summary>
internal static class RequestLoggingConfiguration
{
    /// <summary>
    /// Custom message template for HTTP request logging.
    /// </summary>
    internal const string MessageTemplate =
        "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000}ms";

    /// <summary>
    /// Determines the log event level based on the HTTP context, elapsed time, and exception.
    /// Health check paths are set to Verbose (effectively excluded at typical minimum levels).
    /// Status codes 500+ are Error, 400+ are Warning, everything else is Information.
    /// </summary>
    internal static LogEventLevel GetLevel(HttpContext httpContext, double elapsed, Exception? ex)
    {
        if (ex is not null) return LogEventLevel.Error;

        var path = httpContext.Request.Path.Value;
        if (path is not null && path.StartsWith("/health", StringComparison.OrdinalIgnoreCase))
            return LogEventLevel.Verbose; // Effectively excluded at typical minimum levels

        return httpContext.Response.StatusCode switch
        {
            >= 500 => LogEventLevel.Error,
            >= 400 => LogEventLevel.Warning,
            _ => LogEventLevel.Information
        };
    }

    /// <summary>
    /// Enriches the Serilog diagnostic context with per-request properties.
    /// Each property (ClientIp, UserAgent, ContentType) is individually toggleable
    /// via the <c>Serilog:RequestLogging</c> configuration section.
    /// </summary>
    internal static void EnrichDiagnosticContext(
        IDiagnosticContext diagnosticContext,
        HttpContext httpContext)
    {
        var configuration = httpContext.RequestServices.GetService<IConfiguration>();
        var section = configuration?.GetSection("Serilog:RequestLogging");

        if (section?.GetValue<bool?>("EnableClientIp") ?? true)
        {
            diagnosticContext.Set("ClientIp",
                httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown");
        }

        if (section?.GetValue<bool?>("EnableUserAgent") ?? true)
        {
            diagnosticContext.Set("UserAgent",
                httpContext.Request.Headers.UserAgent.ToString());
        }

        if (section?.GetValue<bool?>("EnableContentType") ?? true)
        {
            diagnosticContext.Set("RequestContentType",
                httpContext.Request.ContentType ?? "none");
            diagnosticContext.Set("ResponseContentType",
                httpContext.Response.ContentType ?? "none");
        }
    }
}
